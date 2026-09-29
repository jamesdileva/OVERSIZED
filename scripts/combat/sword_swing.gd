class_name SwordSwing
extends RefCounted

## Sword swing state machine (implementation-guide.md §5.1):
## Windup -> Active -> Recovery -> Windup … forever, with no cooldown gate —
## the sword is always mid-cycle. Attack-pace stats shorten Windup/Recovery;
## nothing ever inserts a cooldown. Pure logic, no nodes, so it is
## unit-testable: the scene calls advance(dt) each physics tick and renders
## whatever phase/angle it reports.

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

var windup_time := 0.13
var active_time := 0.09
var recovery_time := 0.17
var arc_half_angle := deg_to_rad(65.0)    # sweep covers base_angle ± this
var hit_window_width := deg_to_rad(42.0)  # trailing band of the sweep that deals damage
var windup_pull := 0.4                    # radians of visual backswing during windup

var phase: int = Phase.IDLE
var phase_left := 0.0
var base_angle := 0.0        # center of the current arc, locked at swing start
var sweep_dir := 1.0         # alternates every swing
var swing_index := 0
var swing_just_started := false
var active_just_started := false
var spin_every := 0          # 0 = off; every Nth swing sweeps a full 360°
var _spin_active := false


func is_spin_swing() -> bool:
	return _spin_active


## Arc half-width for the CURRENT swing — a spin swing covers all angles.
func current_arc_half() -> float:
	return PI if _spin_active else arc_half_angle


func start(angle: float) -> void:
	base_angle = angle
	sweep_dir = 1.0
	swing_index += 1
	_enter(Phase.WINDUP)


func advance(dt: float) -> void:
	swing_just_started = false
	active_just_started = false
	if phase == Phase.IDLE:
		return
	phase_left -= dt
	if phase_left > 0.0:
		return
	var leftover := phase_left  # ≤ 0: sub-frame remainder, carried so the
	match phase:                # cycle rate stays exactly 1/(w+a+r) over time
		Phase.WINDUP:
			_enter(Phase.ACTIVE, leftover)
		Phase.ACTIVE:
			_enter(Phase.RECOVERY, leftover)
		Phase.RECOVERY:
			sweep_dir = -sweep_dir
			swing_index += 1
			_enter(Phase.WINDUP, leftover)


func _enter(p: int, leftover := 0.0) -> void:
	phase = p
	swing_just_started = p == Phase.WINDUP
	active_just_started = p == Phase.ACTIVE
	if p == Phase.WINDUP:
		_spin_active = spin_every > 0 and swing_index % spin_every == 0
	match p:
		Phase.WINDUP:
			phase_left = windup_time + leftover
		Phase.ACTIVE:
			phase_left = active_time + leftover
		Phase.RECOVERY:
			phase_left = recovery_time + leftover
		Phase.IDLE:
			phase_left = 0.0


## 0..1 progress through the ACTIVE sweep.
func sweep_progress() -> float:
	if phase != Phase.ACTIVE:
		return 0.0
	return 1.0 - clampf(phase_left / active_time, 0.0, 1.0)


## Angle of the blade edge right now — windup pulls back past the arc start,
## active sweeps arc start to arc end, recovery rests at the arc end.
func blade_angle() -> float:
	var arc_start := base_angle - current_arc_half() * sweep_dir
	match phase:
		Phase.WINDUP:
			var t := 1.0 - clampf(phase_left / windup_time, 0.0, 1.0)
			return arc_start - sweep_dir * windup_pull * (1.0 - t)
		Phase.ACTIVE:
			return arc_start + sweep_dir * 2.0 * current_arc_half() * sweep_progress()
		Phase.RECOVERY:
			return arc_start + sweep_dir * 2.0 * current_arc_half()
		_:
			return arc_start


## True when enemy_angle is inside the trailing band of the current sweep —
## the blade has passed through it and the window behind the edge is still
## open. Callers guard with phase == ACTIVE and apply their own reach test.
func in_hit_window(enemy_angle: float) -> bool:
	var d := wrapf(enemy_angle - blade_angle(), -PI, PI)
	if sweep_dir > 0.0:
		return d <= 0.0 and d >= -hit_window_width
	return d >= 0.0 and d <= hit_window_width
