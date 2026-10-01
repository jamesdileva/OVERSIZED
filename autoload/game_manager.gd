extends Node

## Top-level state machine (architecture.md §4/§7): Menu → Run → Summary →
## Hub → (Run | Menu). Autoloaded as GameManager. Also carries the
## automation switches (--shot / --bot skip the menu), the bot smoke-test's
## elapsed-time bookkeeping (which must survive run-scene reloads), and the
## last run's results for the Summary screen.

enum State { MENU, RUN, SUMMARY, HUB }

signal state_changed(state: State)

const SCENES := {
	State.MENU: "res://scenes/ui/main_menu.tscn",
	State.RUN: "res://scenes/run/run.tscn",
	State.SUMMARY: "res://scenes/ui/run_summary.tscn",
	State.HUB: "res://scenes/ui/meta_hub.tscn",
}

var state: State = State.MENU
var last_run: Dictionary = {}

# bot smoke-test bookkeeping — autoloads survive reload_current_scene
var bot_active := false
var bot_elapsed := 0.0
var _bot_log_accum := 0.0


func _ready() -> void:
	var uargs := OS.get_cmdline_user_args()
	# automation never sits in the menu
	if uargs.has("--bot") or uargs.has("--shot"):
		goto(State.RUN)
		return
	var ui_idx := uargs.find("--ui_shot")
	if ui_idx != -1 and ui_idx + 1 < uargs.size():
		var frames := maxi(int(uargs[ui_idx + 1]), 1)
		var target := State.MENU
		var to_idx := uargs.find("--to")
		if to_idx != -1 and to_idx + 1 < uargs.size():
			match uargs[to_idx + 1]:
				"hub":
					target = State.HUB
				"summary":
					target = State.SUMMARY
		if target == State.SUMMARY and last_run.is_empty():
			last_run = {"waves": 10, "kills": 640, "level": 7, "time": 612.0, "hero_xp": 211.0, "glory": 94}
		goto(target)
		_ui_shot(frames / 60.0)


func _physics_process(dt: float) -> void:
	if not bot_active:
		return
	bot_elapsed += dt
	_bot_log_accum += dt
	if _bot_log_accum >= 60.0:
		_bot_log_accum = 0.0
		print("BOT t=%.0fs | fps %d | mem %.1f MB" % [
			bot_elapsed, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])


func goto(s: State) -> void:
	state = s
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[s])
	state_changed.emit(s)


func _ui_shot(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://ui_shot.png")
	get_tree().quit()
