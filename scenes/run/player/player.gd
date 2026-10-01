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
const DASH_TIME := 0.13
const DASH_SPEED := 1150.0   # ~150px fixed-distance burst

var max_hp := 100.0
var hp := 100.0
var move_speed := 300.0
var accel := 2200.0
var friction := 2600.0
var contact_invuln := 0.6

var velocity := Vector2.ZERO

var bot := false               # smoke-test mode: movement comes from bot_dir
var bot_dir := Vector2.ZERO
var invulnerable := false      # bot sessions: exercise progression, not dying
var armor := 0.0               # Plating: fraction of incoming damage removed
var regen_ps := 0.0            # Regeneration: HP/s while alive

var _invuln_left := 0.0
var _dash_left := 0.0
var _dash_dir := Vector2.RIGHT
var _last_move_dir := Vector2.RIGHT
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
	if _dash_left > 0.0:
		# dash overrides steering entirely — short, fixed, uninterrupted
		_dash_left -= dt
		velocity = _dash_dir * DASH_SPEED
	else:
		var dir := bot_dir if bot else Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir != Vector2.ZERO:
			_last_move_dir = dir
			velocity = velocity.move_toward(dir * move_speed, accel * dt)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * dt)
	position += velocity * dt
	position = position.clamp(
		Vector2(-ARENA_HALF, -ARENA_HALF), Vector2(ARENA_HALF, ARENA_HALF))
	if regen_ps > 0.0 and hp > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen_ps * dt)
		hp_changed.emit(hp, max_hp)
	# no cooldown: the only gate is the dash itself finishing (ninja rules).
	# The sword is a separate node with its own _physics_process, so dashing
	# cannot interrupt the swing.
	if Input.is_action_just_pressed("dash") and _dash_left <= 0.0 and hp > 0.0:
		_dash_dir = _last_move_dir
		_dash_left = DASH_TIME
		_invuln_left = maxf(_invuln_left, DASH_TIME + 0.05)


func hurt(amount: float, push_dir: Vector2) -> void:
	if _invuln_left > 0.0 or hp <= 0.0 or invulnerable:
		return
	hp = maxf(0.0, hp - amount * (1.0 - clampf(armor, 0.0, 0.6)))
	_invuln_left = contact_invuln
	velocity += push_dir * 220.0
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


## Used by passive ability recompute (Vitality). Raising the cap also raises
## current HP by the same delta so rank-ups never waste the gain.
func set_max_hp(v: float) -> void:
	if v > max_hp:
		hp += v - max_hp
	max_hp = v
	hp_changed.emit(hp, max_hp)
