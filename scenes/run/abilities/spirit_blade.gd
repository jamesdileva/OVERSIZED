class_name SpiritBlade
extends Node2D

## One-shot homing projectile (cooldown-fired): seeks the nearest enemy
## across all types, damages on contact, expires. A node per blade is fine
## at this scale — only a handful are ever alive; promote to pooled arrays
## if that changes.

const SPEED := 520.0
const LIFETIME := 3.0
const HIT_RADIUS := 22.0

var _group: HordeGroup
var _damage := 14.0
var _life := LIFETIME
var _dir := Vector2.RIGHT
var tag_mask := 0


func setup(group: HordeGroup, damage: float, p_tag_mask: int = 0) -> void:
	_group = group
	_damage = damage
	tag_mask = p_tag_mask


func _physics_process(dt: float) -> void:
	_life -= dt
	if _life <= 0.0 or _group == null:
		queue_free()
		return
	var p := global_position
	var best_dist := -1.0
	var target := p + _dir * 100.0
	for h in _group.hordes:
		var s: HordeSim = h["sim"]
		for i in s.grid.circle_candidates(p, 600.0):
			if i >= s.active_count:
				continue
			var d: float = s.positions[i].distance_to(p)
			if best_dist < 0.0 or d < best_dist:
				best_dist = d
				target = s.positions[i]
	_dir = _dir.slerp((target - p).normalized(), 10.0 * dt).normalized()
	position += _dir * SPEED * dt
	for h in _group.hordes:
		var s: HordeSim = h["sim"]
		for i in s.grid.circle_candidates(global_position, HIT_RADIUS):
			if i >= s.active_count:
				continue
			if s.positions[i].distance_squared_to(global_position) <= HIT_RADIUS * HIT_RADIUS:
				s.damage(i, _damage, _dir, tag_mask)
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2.ZERO, -_dir * 22.0, Color(0.7, 0.9, 1.0, 0.95), 5.0)
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 1.0, 0.95))
