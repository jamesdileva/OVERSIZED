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
var trail_color := Color(1.0, 1.0, 1.0, 0.4)   # cosmetic trail tint (bolder for visibility)
var sfx_cb: Callable = Callable()              # run wires AudioBus.play_sfx; tests leave unwired

var _invuln_left := 0.0
var _dash_queued := false      # event-driven dash request (works across choice-screen pauses)
var _dash_queue_left := 0.0
var _dash_left := 0.0
var _dash_dir := Vector2.RIGHT
var _last_move_dir := Vector2.RIGHT
var _sprite: Sprite2D
var _trail := PackedVector2Array()
var _trail_timer := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/hero.png")   # pixel sprite (white base: cosmetic tints read pure)
	_sprite.scale = Vector2(3, 3)   # 16px sprite x3 = 48px, within the size guide
	# ALWAYS so the dash input queue survives choice-screen pauses; gated inside
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return   # dash queue intentionally persists across choice-screen pauses
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
	# cosmetic motion trail: sample a position every 0.05s, draw fading dots
	_trail_timer -= dt
	if _trail_timer <= 0.0:
		_trail_timer = 0.05
		_trail.insert(0, position)
		if _trail.size() > 14:
			_trail.resize(14)
		queue_redraw()


func set_hero_tint(color: Color) -> void:
	_sprite.modulate = color


func _draw() -> void:
	for k in _trail.size():
		var a := 0.4 * (1.0 - float(k) / float(_trail.size()))
		draw_circle(_trail[k], 11.0 - float(k) * 0.35, Color(trail_color.r, trail_color.g, trail_color.b, a * trail_color.a))
	_try_consume_dash()


## Consumes a queued dash (ninja rules: no cooldown, the only gate is the
## dash itself finishing). Requests arrive via _unhandled_key_input, which
## fires even while the tree is paused — so a dash pressed during a choice
## screen fires the moment play resumes instead of being swallowed.
func _try_consume_dash() -> void:
	if _dash_queue_left > 0.0:
		_dash_queue_left -= get_physics_process_delta_time()
		if _dash_queue_left <= 0.0:
			_dash_queued = false
	if _dash_queued and _dash_left <= 0.0 and hp > 0.0:
		_dash_queued = false
		_dash_dir = _last_move_dir
		_dash_left = DASH_TIME
		_invuln_left = maxf(_invuln_left, DASH_TIME + 0.05)
		if sfx_cb.is_valid():
			sfx_cb.call(&"dash")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		_dash_queued = true
		_dash_queue_left = 0.25   # input buffer: a slightly-early press still dashes


func hurt(amount: float, push_dir: Vector2) -> void:
	if _invuln_left > 0.0 or hp <= 0.0 or invulnerable:
		return
	hp = maxf(0.0, hp - amount * (1.0 - clampf(armor, 0.0, 0.6)))
	if sfx_cb.is_valid():
		sfx_cb.call(&"player_hurt")
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
