class_name Player
extends Node2D

## Feel-prototype hero: 8-direction movement with accel/friction, HP, and
## contact i-frames. Movement is the only real input (abilities auto-cast
## once they exist — implementation-guide.md §1). Placeholder circle visual;
## the sword is a child node. Manual position updates — no physics body, so
## the scene keeps zero physics bodies end to end.

signal hp_changed(hp: float, max_hp: float)
signal died

const ARENA_HALF := 1350.0

var max_hp := 100.0
var hp := 100.0
var move_speed := 300.0
var accel := 2200.0
var friction := 2600.0
var contact_invuln := 0.6

var velocity := Vector2.ZERO

var _invuln_left := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PlaceholderTex.circle(24, Color(0.95, 0.9, 0.8))
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if _invuln_left > 0.0:
		_invuln_left -= dt
		_sprite.modulate.a = 0.55 + 0.45 * absf(sin(_invuln_left * 25.0))
		if _invuln_left <= 0.0:
			_sprite.modulate.a = 1.0
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * move_speed, accel * dt)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * dt)
	position += velocity * dt
	position = position.clamp(
		Vector2(-ARENA_HALF, -ARENA_HALF), Vector2(ARENA_HALF, ARENA_HALF))


func hurt(amount: float, push_dir: Vector2) -> void:
	if _invuln_left > 0.0 or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_invuln_left = contact_invuln
	velocity += push_dir * 220.0
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
