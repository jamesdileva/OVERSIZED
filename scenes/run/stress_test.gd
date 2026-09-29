extends Node2D

## Sprint 0.1 spike scene (sprint-roadmap.md §5.1): the horde pattern in
## isolation — dots seeking a target point with pooled spawn/despawn,
## spatial-hash separation, and MultiMesh rendering. No gameplay, art, or
## progression by design. WASD moves the target; F1 opens the debug console.

const POOL_CAPACITY := 10000
const TARGET_SPEED := 420.0
const BENCH_COUNTS := [100, 300, 500, 1000, 2000, 4000, 8000]
const BENCH_WARMUP_FRAMES := 45
const BENCH_MEASURE_FRAMES := 180

var sim: HordeSim
var renderer: HordeRenderer

var _target := Vector2.ZERO
var _bench_running := false
var _hud_fps: Label
var _hud_info: Label
var _hud_accum := 0.0
var _frame_ms_accum := 0.0
var _frame_ms_frames := 0


func _ready() -> void:
	randomize()
	sim = HordeSim.new(POOL_CAPACITY)
	renderer = HordeRenderer.new()
	add_child(renderer)
	renderer.setup(sim)
	_build_hud()
	DebugConsole.register_handler(self, {
		"stress_test": {"args": ["n"], "desc": "activate n enemies (full sim AI)"},
		"render_only": {"args": ["n"], "desc": "activate n enemies, AI off (render pipeline isolated)"},
		"clear": {"args": [], "desc": "despawn all enemies"},
		"bench": {"args": [], "desc": "run the count-sweep benchmark, print results, quit"},
	})
	# Bench runs on `--bench` or automatically when headless — a headless launch
	# is always an automated one in this project, and headless can't idle forever.
	if "--bench" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		_bench_running = true
		# Bench drives exactly one sim step per rendered frame (see _process).
		# Letting _physics_process keep stepping would trigger Godot's physics
		# catch-up (up to 8 steps/frame) once a step exceeds the frame budget,
		# and the measure window would spiral instead of settling.
		set_physics_process(false)
		_run_bench()


func _physics_process(dt: float) -> void:
	if not _bench_running and not DebugConsole.is_open:
		_target += Input.get_vector("move_left", "move_right", "move_up", "move_down") * TARGET_SPEED * dt
	sim.step(dt, _target)


func _process(dt: float) -> void:
	if _bench_running:
		sim.step(1.0 / 60.0, _target)
	_frame_ms_accum += dt * 1000.0
	_frame_ms_frames += 1
	_hud_accum += dt
	if _hud_accum >= 0.25:
		_hud_fps.text = "%d fps  |  frame %.2f ms" % [Engine.get_frames_per_second(), _frame_ms_accum / _frame_ms_frames]
		_hud_info.text = "active %d / %d  (F1 console)" % [sim.active_count, POOL_CAPACITY]
		_hud_accum = 0.0
		_frame_ms_accum = 0.0
		_frame_ms_frames = 0


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	var vb := VBoxContainer.new()
	_hud_fps = Label.new()
	_hud_info = Label.new()
	vb.add_child(_hud_fps)
	vb.add_child(_hud_info)
	margin.add_child(vb)
	layer.add_child(margin)


# --- benchmark -----------------------------------------------------------------

func _run_bench() -> void:
	await get_tree().process_frame
	var lines: Array[String] = []
	lines.append("OVERSIZED Sprint 0.1 bench — %s" % Time.get_datetime_string_from_system())
	lines.append("engine %s | display server: %s" % [Engine.get_version_info()["string"], DisplayServer.get_name()])
	print(lines[1])
	for count in BENCH_COUNTS:
		var result: Dictionary = await _measure_count(count)
		var line := "count %5d | avg %7.2f ms | max %7.2f ms | %.0f fps avg" % [count, result["avg_ms"], result["max_ms"], 1000.0 / result["avg_ms"]]
		print(line)
		lines.append(line)
		_capture_screenshot("bench_%05d" % count)
		sim.clear_all()
	var report := "\n".join(lines)
	print(report)
	var path := "user://bench_results.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(report + "\n")
		file.close()
		print("results written to %s" % ProjectSettings.globalize_path(path))
	await get_tree().process_frame
	get_tree().quit()


func _measure_count(count: int) -> Dictionary:
	_spawn_ring(count)
	for f in BENCH_WARMUP_FRAMES:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var max_ms := 0.0
	for f in BENCH_MEASURE_FRAMES:
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		max_ms = maxf(max_ms, (Time.get_ticks_usec() - f0) / 1000.0)
	var avg_ms := (Time.get_ticks_usec() - t0) / 1000.0 / BENCH_MEASURE_FRAMES
	return {"avg_ms": avg_ms, "max_ms": max_ms}


## Spawn `count` enemies in a ring around the target; returns how many were
## actually spawned (pool-capacity bound). Seek converges them into the clump
## the genre demands, which is the worst case for neighbor queries.
func _spawn_ring(count: int) -> int:
	var spawned := 0
	for k in count:
		var pos := _target + Vector2.from_angle(randf() * TAU) * randf_range(420.0, 1150.0)
		if sim.spawn(pos) == -1:
			break
		spawned += 1
	return spawned


func _capture_screenshot(base_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://%s.png" % base_name)


# --- debug console handlers (dispatched by DebugConsole autoload) --------------

func console_stress_test(n: String) -> String:
	sim.ai_enabled = true
	var spawned := _spawn_ring(maxi(int(n), 0))
	return "spawned %d (active %d)" % [spawned, sim.active_count]


func console_render_only(n: String) -> String:
	sim.ai_enabled = false
	var spawned := _spawn_ring(maxi(int(n), 0))
	return "spawned %d, AI disabled (active %d) — sim.step is a no-op while ai_enabled is false" % [spawned, sim.active_count]


func console_clear() -> String:
	sim.clear_all()
	return "cleared (active 0)"


func console_bench() -> String:
	if _bench_running:
		return "bench already running"
	_bench_running = true
	_run_bench()
	return "bench started — results print and the game quits when done"
