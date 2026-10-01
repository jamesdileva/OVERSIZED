class_name OrbitBlades
extends Node2D

## Persistent auto-cast hazard (implementation-guide.md §7's worked example):
## N blades orbit the hero and deal contact damage on a fixed tick interval
## via the spatial hash. No cooldown — it's always on once brought online.
## Node-local origin is the hero (child of the caster, child of the player),
## which matches the damage math that queries around the hero's position.

const TICK_INTERVAL := 0.35
const SPIN := 2.6   # rad/s

var _sim: HordeSim
var _player: Player
var _blades := 3
var _radius := 90.0
var _damage := 8.0
var _angle := 0.0
var _tick_left := TICK_INTERVAL
var tag_mask := 0


func setup(sim: HordeSim, player: Player) -> void:
	_sim = sim
	_player = player


func configure(rank: int) -> void:
	_blades = 2 + rank
	_radius = 84.0 + 8.0 * float(rank)
	_damage = 8.0 * (1.0 + 0.45 * float(rank - 1))


func tick_damage(dt: float) -> void:
	if _sim == null or _player == null:
		return
	_tick_left -= dt
	if _tick_left > 0.0:
		return
	_tick_left = TICK_INTERVAL
	var p := _player.global_position
	var reach := _radius + 18.0
	for i in _sim.grid.circle_candidates(p, reach):
		if i >= _sim.active_count:
			continue
		var away: Vector2 = _sim.positions[i] - p
		if away.length_squared() > reach * reach:
			continue
		_sim.damage(i, _damage, away.normalized(), tag_mask)


func _process(dt: float) -> void:
	_angle = fmod(_angle + SPIN * dt, TAU)
	queue_redraw()


func _draw() -> void:
	if _blades <= 0:
		return
	for k in _blades:
		var a := _angle + TAU * float(k) / float(_blades)
		var pos := Vector2.from_angle(a) * _radius
		draw_circle(pos, 7.0, Color(0.75, 0.85, 1.0, 0.95))
		draw_circle(pos, 3.5, Color(1.0, 1.0, 1.0, 0.9))
