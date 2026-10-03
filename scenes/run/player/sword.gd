class_name Sword
extends Node2D

## The oversized sword, pivoted on the hero. Always mid-swing via the
## SwordSwing state machine (no cooldown gate — implementation-guide.md §5.1).
## Hit detection runs against the horde group's per-type spatial hashes:
## circle candidates around the hero, then exact reach + sweep-window tests
## (§5.2's hash-based approach). One hit per enemy per swing, tracked by
## per-sim flags. The blade is placeholder custom drawing until real art.

signal combo_burst(center: Vector2)

const AIM_RANGE := 620.0
const BASE_MASK := Tags.SLASH_BIT   # the sword is inherently Slash; infusions add more

var reach := 155.0
var damage := 12.0
var swing := SwordSwing.new()
var combo := ComboCounter.new()
var hit_tag_mask := 0               # elemental infusions add their tags here

var _group: HordeGroup
var _on_hit: Callable
var boss_getter: Callable          # run provides () -> Boss (or null)
var _boss_hit_this_swing := false
var _hits_this_swing := 0


func setup(group: HordeGroup, on_hit: Callable) -> void:
	_group = group
	_on_hit = on_hit
	group.setup_flags()
	swing.start(0.0)


func _physics_process(dt: float) -> void:
	if _group == null:
		return
	if swing.swing_just_started:
		_group.begin_swing()
		_hits_this_swing = 0
		_boss_hit_this_swing = false
		swing.base_angle = _aim_angle()
	var prev_phase := swing.phase
	swing.advance(dt)
	if prev_phase == SwordSwing.Phase.ACTIVE and swing.phase == SwordSwing.Phase.RECOVERY:
		combo.register_swing(_hits_this_swing)
	if swing.phase == SwordSwing.Phase.ACTIVE:
		_sweep_hits()
	queue_redraw()


func _aim_angle() -> float:
	var p := global_position
	var best_dist := -1.0
	var best_angle := 0.0
	for h in _group.hordes:
		var s: HordeSim = h["sim"]
		for i in s.grid.circle_candidates(p, AIM_RANGE):
			if i >= s.active_count:
				continue
			var to: Vector2 = s.positions[i] - p
			var d := to.length()
			if best_dist < 0.0 or d < best_dist:
				best_dist = d
				best_angle = to.angle()
	return best_angle


func _sweep_hits() -> void:
	var p := global_position
	var reach_sq := (reach + 14.0) * (reach + 14.0)
	var mask := BASE_MASK | hit_tag_mask
	for h_idx in _group.hordes.size():
		var s: HordeSim = _group.hordes[h_idx]["sim"]
		for i in s.grid.circle_candidates(p, reach):
			if _group.flag_get(h_idx, i) == 1 or i >= s.active_count:
				continue
			var to: Vector2 = s.positions[i] - p
			if to.length_squared() > reach_sq:
				continue
			if not swing.in_hit_window(to.angle()):
				continue
			_group.flag_set(h_idx, i)
			# capture the victim's slot position before damage — a kill swap-removes
			# the slot and the index would point at a different enemy afterwards
			var hit_pos: Vector2 = s.positions[i]
			var died := s.damage(i, damage, to.normalized(), mask)
			_hits_this_swing += 1
			if combo.register_hits(1):
				combo_burst.emit(p)
			_on_hit.call(hit_pos, damage, died)
	_sweep_boss(p)


## The boss is a single entity outside the pooled sims, so the sweep tests it
## separately with the same reach + window rules, once per swing — applying
## the group's damage math itself (modified by tag mask) for parity.
func _sweep_boss(p: Vector2) -> void:
	if _boss_hit_this_swing or not boss_getter.is_valid():
		return
	var b = boss_getter.call()
	if b == null:
		return
	var to: Vector2 = b.global_position - p
	if to.length() > reach + b.body_radius:
		return
	if not swing.in_hit_window(to.angle()):
		return
	_boss_hit_this_swing = true
	var mask := BASE_MASK | hit_tag_mask
	var hit_pos: Vector2 = b.global_position - to.normalized() * b.body_radius
	b.take_damage(_group.modified(damage, mask))
	_on_hit.call(hit_pos, damage, false)


func _draw() -> void:
	var a := swing.blade_angle()
	var dir := Vector2.from_angle(a)
	var perp := dir.orthogonal()
	var col := Color(0.85, 0.88, 0.95)
	if swing.phase == SwordSwing.Phase.ACTIVE:
		col = Color(1.0, 0.97, 0.9)
	# blade slab
	draw_line(dir * 16.0, dir * reach, col, 12.0)
	draw_line(dir * (reach - 22.0), dir * reach, col, 20.0)
	# hilt crossbar behind the hero
	draw_line(-dir * 14.0 + perp * 9.0, -dir * 14.0 - perp * 9.0, Color(0.5, 0.4, 0.3), 6.0)
	# sweep smear while active
	if swing.phase == SwordSwing.Phase.ACTIVE:
		var arc_start := swing.base_angle - swing.current_arc_half() * swing.sweep_dir
		var swept := 2.0 * swing.current_arc_half() * swing.sweep_progress()
		draw_arc(
			Vector2.ZERO, reach * 0.92,
			minf(arc_start, arc_start + swing.sweep_dir * swept),
			maxf(arc_start, arc_start + swing.sweep_dir * swept),
			24, Color(1.0, 0.9, 0.7, 0.28), 22.0)
