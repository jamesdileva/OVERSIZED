class_name HordeSim
extends RefCounted

## Horde simulation core (implementation-guide §6): flat-array enemy pool with
## manual position updates — no physics bodies, no per-enemy nodes. Active
## enemies occupy slots [0, active_count); despawn swap-removes the last active
## slot into the hole, so iteration and hash rebuilds stay contiguous.
##
## Step order per frame: rebuild spatial hash -> per enemy: steer toward target,
## accumulate bounded separation from hash neighbors, integrate, clamp to arena.
## All damage/movement data lives in PackedArrays sized once to `capacity`.

const DEFAULT_CAPACITY := 10000
const ARENA_HALF_EXTENT := 1400.0
const ARENA_MIN := Vector2(-ARENA_HALF_EXTENT, -ARENA_HALF_EXTENT)
const ARENA_MAX := Vector2(ARENA_HALF_EXTENT, ARENA_HALF_EXTENT)

var capacity: int
var active_count := 0
var ai_enabled := true

var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var speeds := PackedFloat32Array()

var grid: SpatialHash

var max_speed := 150.0
var steer_rate := 5.0            # rad/s-ish turn-in toward desired velocity
var separation_radius := 24.0
var separation_accel := 500.0    # px/s^2 applied per unit of separation push
var max_neighbor_checks := 8     # per-enemy cap so worst-case clump cost is bounded


func _init(p_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	velocities.resize(capacity)
	speeds.resize(capacity)
	grid = SpatialHash.new(separation_radius * 2.0)


## Returns the assigned slot, or -1 if the pool is exhausted.
func spawn(pos: Vector2) -> int:
	if active_count >= capacity:
		return -1
	var i := active_count
	active_count += 1
	positions[i] = pos
	velocities[i] = Vector2.ZERO
	speeds[i] = max_speed * randf_range(0.7, 1.3)
	return i


func despawn(i: int) -> void:
	if i < 0 or i >= active_count:
		return
	var last := active_count - 1
	if i != last:
		positions[i] = positions[last]
		velocities[i] = velocities[last]
		speeds[i] = speeds[last]
	active_count = last


func clear_all() -> void:
	active_count = 0


func step(dt: float, target: Vector2) -> void:
	if not ai_enabled:
		return
	grid.rebuild(positions, active_count)
	var sep_radius_sq := separation_radius * separation_radius
	var steer := clampf(steer_rate * dt, 0.0, 1.0)
	var sep_delta := separation_accel * dt
	for i in active_count:
		var pos: Vector2 = positions[i]
		var desired: Vector2 = (target - pos).normalized() * speeds[i]
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
