class_name Sword
extends Node2D

## The oversized sword, pivoted on the hero. Always mid-swing via the
## SwordSwing state machine (no cooldown gate — implementation-guide.md §5.1).
## Hit detection runs against the horde sim's spatial hash: circle candidates
## around the hero, then exact reach + sweep-window tests (§5.2's hash-based
## approach). One hit per enemy per swing, tracked by pool slot. The blade is
## placeholder custom drawing until real art lands.

const REACH := 155.0
const DAMAGE := 12.0
const AIM_RANGE := 620.0

var swing := SwordSwing.new()

var _sim: HordeSim
var _on_hit: Callable
# PackedByteArray, not PackedBoolArray — PackedBoolArray does not exist in
# 4.7.2's GDScript (parse error), byte flags are the drop-in replacement
var _hit_flags: PackedByteArray = PackedByteArray()


func setup(sim: HordeSim, on_hit: Callable) -> void:
	_sim = sim
	_on_hit = on_hit
	_hit_flags.resize(sim.capacity)
	swing.start(0.0)


func _physics_process(dt: float) -> void:
	if _sim == null:
		return
	if swing.swing_just_started:
		_hit_flags.fill(0)
		swing.base_angle = _aim_angle()
	swing.advance(dt)
	if swing.phase == SwordSwing.Phase.ACTIVE:
		_sweep_hits()
	queue_redraw()


func _aim_angle() -> float:
	var p := global_position
	var best_dist := -1.0
	var best_angle := 0.0
	for i in _sim.grid.circle_candidates(p, AIM_RANGE):
		if i >= _sim.active_count:
			continue
		var to: Vector2 = _sim.positions[i] - p
		var d := to.length()
		if best_dist < 0.0 or d < best_dist:
			best_dist = d
			best_angle = to.angle()
	return best_angle


func _sweep_hits() -> void:
	var p := global_position
	var reach_sq := (REACH + 14.0) * (REACH + 14.0)
	for i in _sim.grid.circle_candidates(p, REACH):
		if _hit_flags[i] == 1 or i >= _sim.active_count:
			continue
		var to: Vector2 = _sim.positions[i] - p
		if to.length_squared() > reach_sq:
			continue
		if not swing.in_hit_window(to.angle()):
			continue
		_hit_flags[i] = 1
		# capture the victim's slot position before damage — a kill swap-removes
		# the slot and the index would point at a different enemy afterwards
		var hit_pos: Vector2 = _sim.positions[i]
		var died := _sim.damage(i, DAMAGE, to.normalized())
		_on_hit.call(hit_pos, DAMAGE, died)


func _draw() -> void:
	var a := swing.blade_angle()
	var dir := Vector2.from_angle(a)
	var perp := dir.orthogonal()
	var col := Color(0.85, 0.88, 0.95)
	if swing.phase == SwordSwing.Phase.ACTIVE:
		col = Color(1.0, 0.97, 0.9)
	# blade slab
	draw_line(dir * 16.0, dir * REACH, col, 12.0)
	draw_line(dir * (REACH - 22.0), dir * REACH, col, 20.0)
	# hilt crossbar behind the hero
	draw_line(-dir * 14.0 + perp * 9.0, -dir * 14.0 - perp * 9.0, Color(0.5, 0.4, 0.3), 6.0)
	# sweep smear while active
	if swing.phase == SwordSwing.Phase.ACTIVE:
		var arc_start := swing.base_angle - swing.arc_half_angle * swing.sweep_dir
		var swept := 2.0 * swing.arc_half_angle * swing.sweep_progress()
		draw_arc(
			Vector2.ZERO, REACH * 0.92,
			minf(arc_start, arc_start + swing.sweep_dir * swept),
			maxf(arc_start, arc_start + swing.sweep_dir * swept),
			24, Color(1.0, 0.9, 0.7, 0.28), 22.0)
