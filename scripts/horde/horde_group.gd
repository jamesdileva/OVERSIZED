class_name HordeGroup
extends RefCounted

## Owns one HordeSim per enemy archetype (implementation-guide §6.4: one
## MultiMesh per type) and exposes the single-sim API the rest of the game
## was written against: weighted composition spawning, stepping, swing
## flags, and circle damage across every type. Spawn composition data lives
## on the EnemyDefs themselves (min_wave + spawn_weight).

signal enemy_killed(at: Vector2, xp_value: float, status: int)

const PER_TYPE_CAPACITY := 2000

var hordes: Array = []              # {"sim": HordeSim, "def": EnemyDef or null}
var _flags: Array[PackedByteArray] = []   # per-swing per-sim hit flags


func add_type(def: EnemyDef) -> void:
	_add(def)


func add_default() -> void:
	_add(null)   # baseline chaser dot (bench/spike compatibility)


func _add(def: EnemyDef) -> void:
	var s := HordeSim.new(PER_TYPE_CAPACITY)
	s.def = def
	var xp := def.xp_value if def != null else 1.0
	s.enemy_killed.connect(func(at: Vector2, status: int) -> void: enemy_killed.emit(at, xp, status))
	hordes.append({"sim": s, "def": def})
	var flags := PackedByteArray()
	flags.resize(s.capacity)
	_flags.append(flags)


func setup_flags() -> void:
	for k in _flags.size():
		_flags[k].fill(0)


func begin_swing() -> void:
	for flags in _flags:
		flags.fill(0)


func flag_get(h: int, i: int) -> int:
	return _flags[h][i]


func flag_set(h: int, i: int) -> void:
	_flags[h][i] = 1


## Weighted spawn among types whose min_wave has arrived.
func spawn_weighted(pos: Vector2, wave_number: int) -> int:
	var pool: Array = []
	var total := 0.0
	for h in hordes:
		var d: EnemyDef = h["def"]
		if d == null or d.min_wave <= wave_number:
			var w: float = d.spawn_weight if d != null else 1.0
			pool.append(h)
			total += w
	var pick := randf() * total
	for h in pool:
		var d: EnemyDef = h["def"]
		pick -= d.spawn_weight if d != null else 1.0
		if pick <= 0.0:
			return h["sim"].spawn(pos)
	return pool[pool.size() - 1]["sim"].spawn(pos)


func step_all(dt: float, target: Vector2) -> void:
	for h in hordes:
		h["sim"].step(dt, target)


func total_active() -> int:
	var n := 0
	for h in hordes:
		n += h["sim"].active_count
	return n


## Circle damage across every type (AoEs). Returns hits applied.
## proc_depth flows through so reactions can chain exactly once (§5.4).
func circle_damage(center: Vector2, radius: float, amount: float, mask: int, knock_scale: float, proc_depth: int = 0) -> int:
	var hits := 0
	var radius_sq := radius * radius
	for h in hordes:
		var s: HordeSim = h["sim"]
		for i in s.grid.circle_candidates(center, radius):
			if i >= s.active_count:
				continue
			var away: Vector2 = s.positions[i] - center
			if away.length_squared() > radius_sq:
				continue
			var push := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
			s.damage(i, amount, push * knock_scale, mask, proc_depth)
			hits += 1
	return hits


## Boss-parity damage math for any single entity outside the sims.
func modified(amount: float, mask: int) -> float:
	return hordes[0]["sim"].modified(amount, mask) if not hordes.is_empty() else amount


## The damage-mod pool is shared by every type — apply to all sims.
func clear_damage_mods() -> void:
	for h in hordes:
		h["sim"].clear_damage_mods()


func add_increased(tag_bit: int, amount: float) -> void:
	for h in hordes:
		h["sim"].add_increased(tag_bit, amount)


func scale_knockback(mult: float) -> void:
	for h in hordes:
		h["sim"].knockback_impulse *= mult
