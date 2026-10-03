class_name Boss
extends Node2D

## Wave-10 boss: a telegraphed attack-pattern state machine driven by
## BossBrain (HP phases + enrage). Two patterns alternate — a locked-direction
## charge and a locked-position slam — both telegraphed in the hostile hue
## (implementation-guide.md §16.3) before they execute. Placeholder visuals;
## not part of the pooled sim (single entity), takes damage via take_damage.

signal died(pos: Vector2)
signal slammed(pos: Vector2, radius: float)

enum State { SEEK, TELEGRAPH, CHARGE, RECOVER }

var def: BossDef
var brain: BossBrain
var body_radius := 42.0

var _player: Player
var _state: int = State.SEEK
var _pattern := 0                    # 0 = charge, 1 = slam; alternates
var _telegraph_left := 0.0
var _charge_dir := Vector2.RIGHT
var _charge_left := 0.0
var _slam_pos := Vector2.ZERO
var _attack_cd := 1.4                # first attack shortly after spawn
var _hit_player_this_charge := false
var _champ_speed := 1.0              # champion_modifier_slots bonus


func setup(p_def: BossDef, player: Player) -> void:
	def = p_def
	# champion modifiers (architecture.md §9): each slot = +20% HP, +8%
	# speed, 10% faster enrage. Wired in Sprint 2.3; the wave-30 boss wears
	# 2 slots as the live proof.
	var slots := p_def.champion_modifier_slots
	brain = BossBrain.new(p_def.max_health * (1.0 + 0.2 * slots), p_def.enrage_time / (1.0 + 0.1 * slots))
	_champ_speed = 1.0 + 0.08 * slots
	_player = player


func take_damage(amount: float) -> void:
	if brain == null:
		return
	brain.damage(amount)
	if brain.health <= 0.0:
		died.emit(global_position)
		queue_free()


func _physics_process(dt: float) -> void:
	if brain == null or _player == null:
		return
	brain.tick(dt)
	var mult := brain.speed_mult() * _champ_speed
	match _state:
		State.SEEK:
			var to := _player.global_position - global_position
			if to.length() > body_radius * 0.8:
				position += to.normalized() * def.move_speed * mult * dt
			else:
				_player.hurt(def.contact_damage, to.normalized())
			_attack_cd -= dt
			if _attack_cd <= 0.0:
				_pattern = (_pattern + 1) % 2
				_state = State.TELEGRAPH
				_telegraph_left = def.telegraph_time / mult
				if _pattern == 0:
					_charge_dir = (_player.global_position - global_position).normalized()
				else:
					_slam_pos = _player.global_position
		State.TELEGRAPH:
			_telegraph_left -= dt
			if _telegraph_left <= 0.0:
				if _pattern == 0:
					_state = State.CHARGE
					_charge_left = 0.55
					_hit_player_this_charge = false
				else:
					_do_slam()
					_state = State.RECOVER
					_attack_cd = def.attack_interval / mult
		State.CHARGE:
			_charge_left -= dt
			position += _charge_dir * def.charge_speed * mult * dt
			if not _hit_player_this_charge \
					and _player.global_position.distance_to(global_position) < body_radius + 16.0:
				_hit_player_this_charge = true
				_player.hurt(def.charge_damage, _charge_dir)
			if _charge_left <= 0.0:
				_state = State.RECOVER
				_attack_cd = def.attack_interval / mult
		State.RECOVER:
			_attack_cd -= dt
			if _attack_cd <= 0.0:
				_state = State.SEEK
	queue_redraw()


func _do_slam() -> void:
	if _player.global_position.distance_to(_slam_pos) < def.slam_radius:
		_player.hurt(def.slam_damage, (_player.global_position - _slam_pos).normalized())
	slammed.emit(_slam_pos, def.slam_radius)


func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, Color(0.72, 0.18, 0.24))
	draw_circle(Vector2.ZERO, body_radius - 8.0, Color(0.45, 0.1, 0.16))
	draw_circle(Vector2.ZERO, body_radius - 20.0, Color(0.85, 0.3, 0.3, 0.8))
	if _state == State.TELEGRAPH:
		# hostile hue: red-magenta, never used by player effects
		var a := 0.3 + 0.25 * absf(sin(Time.get_ticks_msec() * 0.02))
		if _pattern == 0:
			draw_line(Vector2.ZERO, _charge_dir * 640.0, Color(1.0, 0.2, 0.55, a), 46.0)
		else:
			var local := _slam_pos - global_position
			draw_circle(local, def.slam_radius, Color(1.0, 0.2, 0.55, a * 0.45))
			draw_arc(local, def.slam_radius, 0.0, TAU, 40, Color(1.0, 0.2, 0.55, a), 4.0)
