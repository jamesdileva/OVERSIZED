class_name XpGems
extends Node2D

## Pooled XP pickups (implementation-guide.md §9: physical pickups add
## routing value to a movement-only game). One node owns and draws the whole
## pool; gems magnet toward the hero inside the pickup radius and emit
## collected(value) on contact. Slots recycle ring-style, so the oldest gems
## are reused once the pool is exhausted.

const POOL := 300
const COLLECT_DIST := 18.0
const BASE_PULL := 240.0

signal collected(amount: float)

var player: Player
var magnet_radius := 90.0
var xp_mult := 1.0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _value := PackedFloat32Array()
var _active: PackedByteArray = PackedByteArray()
var _spawn_idx := 0


func _ready() -> void:
	_pos.resize(POOL)
	_vel.resize(POOL)
	_value.resize(POOL)
	_active.resize(POOL)
	_active.fill(0)


func spawn(pos: Vector2, value: float) -> void:
	var k := _spawn_idx
	_spawn_idx = (_spawn_idx + 1) % POOL
	_pos[k] = pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	_vel[k] = Vector2.ZERO
	_value[k] = value
	_active[k] = 1


func _physics_process(dt: float) -> void:
	if player == null:
		return
	var p := player.global_position
	for k in POOL:
		if _active[k] == 0:
			continue
		var to := p - _pos[k]
		var d := to.length()
		if d < magnet_radius:
			var pull := BASE_PULL * (1.8 if d < magnet_radius * 0.4 else 1.0)
			_vel[k] = _vel[k].move_toward(to.normalized() * pull, 1400.0 * dt)
		_pos[k] += _vel[k] * dt
		if d < COLLECT_DIST:
			_active[k] = 0
			collected.emit(_value[k] * xp_mult)
	queue_redraw()


func _draw() -> void:
	for k in POOL:
		if _active[k] == 0:
			continue
		var r := 5.0 if _value[k] > 1.5 else 3.5
		draw_circle(_pos[k], r, Color(0.35, 0.85, 1.0, 0.95))
		draw_circle(_pos[k], r * 0.45, Color(0.9, 1.0, 1.0, 0.95))
