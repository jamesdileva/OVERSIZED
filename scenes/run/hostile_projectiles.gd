class_name HostileProjectiles
extends Node2D

## Pooled enemy projectiles, drawn in the hostile hue (red-magenta —
## implementation-guide §16.3: player effects never use it). Ranged types
## fire via HordeSim's shot signal; the run routes that here.

const POOL := 200
const HIT_RADIUS := 16.0
const LIFETIME := 6.0
const ARENA_HALF := 1500.0

signal player_hit(damage: float)

var player: Player

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _dmg := PackedFloat32Array()
var _life := PackedFloat32Array()
var _active: PackedByteArray = PackedByteArray()
var _spawn_idx := 0


func _ready() -> void:
	_pos.resize(POOL)
	_vel.resize(POOL)
	_dmg.resize(POOL)
	_life.resize(POOL)
	_active.resize(POOL)
	_active.fill(0)


func fire(pos: Vector2, dir: Vector2, damage: float, speed: float) -> void:
	var k := _spawn_idx
	_spawn_idx = (_spawn_idx + 1) % POOL
	_pos[k] = pos
	_vel[k] = dir * speed
	_dmg[k] = damage
	_life[k] = LIFETIME
	_active[k] = 1


func _physics_process(dt: float) -> void:
	if player == null:
		return
	var p := player.global_position
	for k in POOL:
		if _active[k] == 0:
			continue
		_life[k] -= dt
		_pos[k] += _vel[k] * dt
		if _life[k] <= 0.0 or absf(_pos[k].x) > ARENA_HALF or absf(_pos[k].y) > ARENA_HALF:
			_active[k] = 0
			continue
		if player.hp > 0.0 and p.distance_squared_to(_pos[k]) < (HIT_RADIUS + 12.0) * (HIT_RADIUS + 12.0):
			_active[k] = 0
			player_hit.emit(_dmg[k])
	queue_redraw()


func _draw() -> void:
	for k in POOL:
		if _active[k] == 0:
			continue
		draw_circle(_pos[k], 6.0, Color(1.0, 0.2, 0.55, 0.95))
		draw_circle(_pos[k], 2.5, Color(1.0, 0.85, 0.95, 0.95))
