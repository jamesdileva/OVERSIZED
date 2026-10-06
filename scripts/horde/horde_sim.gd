class_name HordeSim
extends RefCounted

## Horde simulation core (implementation-guide.md §6): flat-array enemy pool with
## manual position updates — no physics bodies, no per-enemy nodes. Active
## enemies occupy slots [0, active_count); despawn swap-removes the last active
## slot into the hole, so iteration and hash rebuilds stay contiguous.
##
## Step order per frame: rebuild spatial hash -> per enemy: steer toward target,
## accumulate bounded separation from hash neighbors, integrate, clamp to arena,
## decay hit flash. All state lives in PackedArrays sized once to `capacity`.

signal enemy_killed(at: Vector2, status_mask: int)
signal hit_event(pos: Vector2, amount: float, tag_mask: int, target_status: int)
signal exploded(pos: Vector2, radius: float, damage: float)
signal shot(pos: Vector2, dir: Vector2, damage: float, speed: float)
signal reaction_fired(kind: StringName, pos: Vector2, radius: float, amount: float)

const DEFAULT_CAPACITY := 10000
const ARENA_HALF_EXTENT := 1400.0
const ARENA_MIN := Vector2(-ARENA_HALF_EXTENT, -ARENA_HALF_EXTENT)
const ARENA_MAX := Vector2(ARENA_HALF_EXTENT, ARENA_HALF_EXTENT)

# statuses (architecture.md §5.4): flat arrays, no nodes. Burn/Bleed tick on
# STATUS_TICK; Chill scales seek speed. Applied from hit tag masks:
# FIRE -> Burn, FROST -> Chill, BLOOD -> Bleed.
const BURN_BIT := Tags.BURN_BIT
const CHILL_BIT := Tags.CHILL_BIT
const BLEED_BIT := Tags.BLEED_BIT
const FIRE_BIT := Tags.FIRE_BIT
const FROST_BIT := Tags.FROST_BIT
const BLOOD_BIT := Tags.BLOOD_BIT
const STATUS_DURATION := 3.0
const STATUS_TICK := 0.5
const BURN_DPS := 6.0
const BLEED_DPS := 9.0
const CHILL_SLOW := 0.35
const MORE_CAP := 4

var capacity: int
var active_count := 0
var ai_enabled := true

var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var speeds := PackedFloat32Array()
var healths := PackedFloat32Array()
var hit_flash := PackedFloat32Array()   # 1.0 on hit, decays to 0; renderer reads it
var status_mask: PackedInt32Array = PackedInt32Array()
var burn_left := PackedFloat32Array()
var chill_left := PackedFloat32Array()
var bleed_left := PackedFloat32Array()

var grid: SpatialHash

## Enemy type for this sim (one sim per archetype — implementation-guide §6.4).
## null = the baseline chaser dot (bench/spike compatibility).
var def: EnemyDef = null

# wave difficulty multipliers (WaveDef speed_scale/health_scale)
var speed_scale := 1.0
var health_scale := 1.0

# two-category damage math: final = base * (1 + sum(increased[tag])) * prod(more)
var increased := {}                # tag bit -> additive sum
var more_list: Array[float] = []

var steer_rate := 5.0            # rad/s-ish turn-in toward desired velocity
var separation_radius := 24.0
var separation_accel := 500.0    # px/s^2 applied per unit of separation push
var max_neighbor_checks := 8     # per-enemy cap so worst-case clump cost is bounded
var knockback_impulse := 240.0
var flash_decay := 7.0           # per second

var _fire_cd := PackedFloat32Array()     # ranged: per-enemy shot timer
var _windup := PackedFloat32Array()      # exploder: per-enemy windup timer
var _explode_queue: Array[int] = []


func _init(p_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	velocities.resize(capacity)
	speeds.resize(capacity)
	healths.resize(capacity)
	hit_flash.resize(capacity)
	status_mask.resize(capacity)
	burn_left.resize(capacity)
	chill_left.resize(capacity)
	bleed_left.resize(capacity)
	_fire_cd.resize(capacity)
	_windup.resize(capacity)
	grid = SpatialHash.new(separation_radius * 2.0)


## Returns the assigned slot, or -1 if the pool is exhausted.
func spawn(pos: Vector2) -> int:
	if active_count >= capacity:
		return -1
	var i := active_count
	active_count += 1
	positions[i] = pos
	velocities[i] = Vector2.ZERO
	speeds[i] = (def.move_speed if def != null else 150.0) * speed_scale * randf_range(0.7, 1.3)
	healths[i] = (def.max_health if def != null else 30.0) * health_scale
	hit_flash[i] = 0.0
	status_mask[i] = 0
	burn_left[i] = 0.0
	chill_left[i] = 0.0
	bleed_left[i] = 0.0
	_fire_cd[i] = (def.fire_interval if def != null else 0.0) * 0.5
	_windup[i] = 0.0
	return i


func despawn(i: int) -> void:
	if i < 0 or i >= active_count:
		return
	var last := active_count - 1
	if i != last:
		positions[i] = positions[last]
		velocities[i] = velocities[last]
		speeds[i] = speeds[last]
		healths[i] = healths[last]
		hit_flash[i] = hit_flash[last]
		status_mask[i] = status_mask[last]
		burn_left[i] = burn_left[last]
		chill_left[i] = chill_left[last]
		bleed_left[i] = bleed_left[last]
	active_count = last


func clear_all() -> void:
	active_count = 0


## proc guardrails (architecture.md §5.4): reaction damage is scaled by
## PROC_COEFFICIENT when the reaction itself was triggered at depth >= 1,
## and reactions may only chain while proc_depth < 2 (once, then stop).
const PROC_COEFFICIENT := 0.5
const SHATTER_MIN_BASE := 10.0
const STEAM_RADIUS := 120.0
const STEAM_DAMAGE := 10.0
const BLOOD_BOIL_RADIUS := 130.0
const BLOOD_BOIL_DAMAGE := 14.0


## The single-pipeline damage entry: applies the two-category damage math
## (increased/more) by tag mask, applies statuses from source tags
## (FIRE -> Burn, FROST -> Chill, BLOOD -> Bleed), fires reactions when the
## target's pre-hit status combines with the hit, emits hit_event, and
## emits enemy_killed + swap-removes on death. Returns true when lethal.
func damage(i: int, amount: float, dir: Vector2, tag_mask: int = 0, proc_depth: int = 0) -> bool:
	if i < 0 or i >= active_count:
		return false
	var sm_before := status_mask[i]
	var final := modified(amount, tag_mask)
	# Shatter: a heavy direct Slash hit on a chilled enemy crits for double
	if proc_depth == 0 and (tag_mask & Tags.SLASH_BIT) != 0 \
			and (sm_before & CHILL_BIT) != 0 and amount >= SHATTER_MIN_BASE:
		final *= 2.0
		reaction_fired.emit(&"shatter", positions[i], 0.0, final)
	healths[i] -= final
	hit_flash[i] = 1.0
	velocities[i] += dir * knockback_impulse
	_apply_status_from_tags(i, tag_mask)
	hit_event.emit(positions[i], final, tag_mask, sm_before)
	# Steam Burst: a Frost hit landing on something already Burning
	if proc_depth < 2 and (tag_mask & Tags.FROST_BIT) != 0 and (sm_before & BURN_BIT) != 0:
		var coeff := 1.0 if proc_depth == 0 else PROC_COEFFICIENT
		reaction_fired.emit(&"steam_burst", positions[i], STEAM_RADIUS, STEAM_DAMAGE * coeff)
	if healths[i] <= 0.0:
		# Blood Boil: dying while bleeding AND burning detonates fire
		if proc_depth < 2 and (sm_before & BURN_BIT) != 0 and (sm_before & BLEED_BIT) != 0:
			var coeff := 1.0 if proc_depth == 0 else PROC_COEFFICIENT
			reaction_fired.emit(&"blood_boil", positions[i], BLOOD_BOIL_RADIUS, BLOOD_BOIL_DAMAGE * coeff)
		enemy_killed.emit(positions[i], status_mask[i])
		despawn(i)
		return true
	return false


## Two-category math (architecture.md §5.4): additive "increased" per matched
## tag bit, then multiplicative "more" (capped). Sword, abilities, and boss
## hits all route through here — one math, one place to tune.
func modified(amount: float, tag_mask: int) -> float:
	var out := amount
	var inc := 0.0
	for bit in increased:
		if (tag_mask & int(bit)) != 0:
			inc += increased[bit]
	out *= 1.0 + inc
	for m in more_list:
		out *= m
	return out


func add_increased(tag_bit: int, amount: float) -> void:
	increased[tag_bit] = float(increased.get(tag_bit, 0.0)) + amount


## Returns false when the "more" cap is reached — deliberate sources only.
func add_more(mult: float) -> bool:
	if more_list.size() >= MORE_CAP:
		return false
	more_list.append(mult)
	return true


func clear_damage_mods() -> void:
	increased.clear()
	more_list.clear()


func _apply_status_from_tags(i: int, tag_mask: int) -> void:
	if tag_mask & FIRE_BIT:
		status_mask[i] |= BURN_BIT
		burn_left[i] = STATUS_DURATION
	if tag_mask & FROST_BIT:
		status_mask[i] |= CHILL_BIT
		chill_left[i] = STATUS_DURATION
	if tag_mask & BLOOD_BIT:
		status_mask[i] |= BLEED_BIT
		bleed_left[i] = STATUS_DURATION


var _status_tick_left := 0.0
var _dot_kills: Array[int] = []


func step(dt: float, target: Vector2) -> void:
	if not ai_enabled:
		return
	grid.rebuild(positions, active_count)
	var sep_radius_sq := separation_radius * separation_radius
	var steer := clampf(steer_rate * dt, 0.0, 1.0)
	var sep_delta := separation_accel * dt
	var flash_delta := flash_decay * dt
	_status_tick_left -= dt
	var do_status_tick := _status_tick_left <= 0.0
	if do_status_tick:
		_status_tick_left = STATUS_TICK
	_dot_kills.clear()
	var beh := def.behavior if def != null else "chaser"
	var is_ranged := beh == "ranged"
	var is_exploder := beh == "exploder"
	var range_sq := (def.attack_range if def != null else 0.0) * (def.attack_range if def != null else 0.0)
	var trig_sq := (def.trigger_radius if def != null else 0.0) * (def.trigger_radius if def != null else 0.0)
	for i in active_count:
		var pos: Vector2 = positions[i]
		var sm := status_mask[i]
		var chill_mult := 1.0 - (CHILL_SLOW if (sm & CHILL_BIT) != 0 else 0.0)
		var to_target := target - pos
		var dist_sq_t := to_target.length_squared()
		var desired: Vector2
		if is_ranged and dist_sq_t < range_sq:
			desired = Vector2.ZERO   # in range: hold position and shoot
		else:
			desired = to_target.normalized() * speeds[i] * chill_mult
		var vel: Vector2 = velocities[i].lerp(desired, steer)
		var push := Vector2.ZERO
		var checks := 0
		var home: Vector2i = grid.key_of(pos)
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				for j in grid.cell(home + Vector2i(ox, oy)):
					if j == i:
						continue
					var away: Vector2 = pos - positions[j]
					var dist_sq: float = away.length_squared()
					if dist_sq < sep_radius_sq and dist_sq > 0.01:
						push += away / sqrt(dist_sq)
						checks += 1
						if checks >= max_neighbor_checks:
							break
				if checks >= max_neighbor_checks:
					break
			if checks >= max_neighbor_checks:
				break
		vel += push * sep_delta
		positions[i] = (pos + vel * dt).clamp(ARENA_MIN, ARENA_MAX)
		velocities[i] = vel
		hit_flash[i] = maxf(0.0, hit_flash[i] - flash_delta)
		# type behaviors (ranged fires, exploders arm) — per-sim, not per-type-in-loop
		if is_ranged:
			_fire_cd[i] -= dt
			if _fire_cd[i] <= 0.0 and dist_sq_t < range_sq * 1.2:
				_fire_cd[i] = def.fire_interval
				shot.emit(positions[i], to_target.normalized(), def.projectile_damage, def.projectile_speed)
		elif is_exploder:
			if _windup[i] > 0.0:
				_windup[i] -= dt
				hit_flash[i] = 1.0   # white-hot telegraph
				if _windup[i] <= 0.0:
					_explode_queue.append(i)
			elif dist_sq_t < trig_sq:
				_windup[i] = def.windup_time
		# status decay + damage-over-time. DoT applies health directly —
		# calling damage() here would swap-remove slots mid-iteration — and
		# kills are processed after the loop, highest index first.
		if sm != 0:
			var ns := sm
			if burn_left[i] > 0.0:
				burn_left[i] -= dt
				if burn_left[i] <= 0.0:
					ns &= ~BURN_BIT
			if chill_left[i] > 0.0:
				chill_left[i] -= dt
				if chill_left[i] <= 0.0:
					ns &= ~CHILL_BIT
			if bleed_left[i] > 0.0:
				bleed_left[i] -= dt
				if bleed_left[i] <= 0.0:
					ns &= ~BLEED_BIT
			status_mask[i] = ns
			if do_status_tick and (sm & (BURN_BIT | BLEED_BIT)) != 0:
				var dot := 0.0
				if (sm & BURN_BIT) != 0:
					dot += BURN_DPS * STATUS_TICK
				if (sm & BLEED_BIT) != 0:
					dot += BLEED_DPS * STATUS_TICK
				healths[i] -= dot
				if healths[i] <= 0.0:
					_dot_kills.append(i)
	if not _dot_kills.is_empty():
		_dot_kills.sort()
		for k in range(_dot_kills.size() - 1, -1, -1):
			var i: int = _dot_kills[k]
			if i < active_count:
				enemy_killed.emit(positions[i], status_mask[i])
				despawn(i)
	if not _explode_queue.is_empty():
		for k in range(_explode_queue.size() - 1, -1, -1):
			var i: int = _explode_queue[k]
			if i < active_count:
				exploded.emit(positions[i], def.blast_radius, def.blast_damage)
				despawn(i)
