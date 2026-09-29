extends Node2D

## Sprint 0.2 feel prototype: one hero, the oversized sword, one enemy type,
## damage numbers, shake and hit-stop. No meta, no progression screens
## (that's Phase 1). The horde runs on the pooled sim the Sprint 0.1 spike
## validated; a lightweight spawner keeps a slowly growing crowd alive so
## the sword always has something to hit.

const POOL_CAPACITY := 2000
const ARENA_HALF := 1350.0

var sim: HordeSim
var horde_view: HordeRenderer
var player: Player
var sword: Sword
var camera: CameraRig
var numbers: DamageNumbers

var kills := 0

var _elapsed := 0.0
var _spawn_accum := 0.0
var _dead := false
var _hitstop_busy := false

var _hud_hp: ColorRect
var _hud_kills: Label
var _hud_fps: Label
var _hud_accum := 0.0

var _shot_left := -1


func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.09, 0.09, 0.12))
	sim = HordeSim.new(POOL_CAPACITY)

	horde_view = HordeRenderer.new()
	add_child(horde_view)
	horde_view.setup(sim, 16.0, Color(0.9, 0.32, 0.22))

	player = Player.new()
	add_child(player)

	sword = Sword.new()
	player.add_child(sword)
	sword.setup(sim, _on_sword_hit)

	numbers = DamageNumbers.new()
	add_child(numbers)

	camera = CameraRig.new()
	player.add_child(camera)

	_build_hud()
	DebugConsole.register_handler(self, {
		"spawn": {"args": ["n"], "desc": "spawn n enemies around the player"},
		"heal": {"args": [], "desc": "restore full HP"},
		"restart": {"args": [], "desc": "restart the run"},
	})
	for k in 14:
		_spawn_one()
	# automated gameplay screenshot for CI-style verification: --shot <frames>
	var uargs := OS.get_cmdline_user_args()
	var fi := uargs.find("--shot")
	if fi != -1 and fi + 1 < uargs.size():
		_shot_left = maxi(int(uargs[fi + 1]), 1)
		# cap to 60fps so frame count ≈ wall time ≈ sim time, and seed the
		# arena close to the player so hits are happening at capture time
		Engine.max_fps = 60
		for k in 30:
			sim.spawn(player.position
					+ Vector2.from_angle(randf() * TAU) * randf_range(160.0, 340.0))


func _physics_process(dt: float) -> void:
	if _dead:
		return
	_elapsed += dt
	# spawn ring stays near the camera view edge so the crowd is visible;
	# the sword kills faster than distant enemies arrive otherwise
	var target_alive := mini(18 + int(_elapsed * 0.3), 80)
	_spawn_accum += dt
	if _spawn_accum >= 0.4:
		_spawn_accum = 0.0
		while sim.active_count < target_alive:
			_spawn_one()
	sim.step(dt, player.position)
	_contact_damage()


func _process(dt: float) -> void:
	_hud_accum += dt
	if _hud_accum >= 0.25:
		_hud_fps.text = "%d fps  |  enemies %d  |  kills %d  |  [R] restart  |  [F1] console" % [
			Engine.get_frames_per_second(), sim.active_count, kills]
		_hud_accum = 0.0
	if _shot_left > 0:
		_shot_left -= 1
		if _shot_left == 0:
			_take_shot()
		elif _shot_left % 60 == 0:
			print("shot countdown: %d frames (%d enemies, %d kills)" % [_shot_left, sim.active_count, kills])


func _contact_damage() -> void:
	var p := player.position
	for i in sim.grid.circle_candidates(p, 34.0):
		if i >= sim.active_count:
			continue
		var to: Vector2 = p - sim.positions[i]
		if to.length_squared() < 26.0 * 26.0:
			player.hurt(9.0, to.normalized())
			break


func _spawn_one() -> void:
	var pos := player.position + Vector2.from_angle(randf() * TAU) * randf_range(380.0, 560.0)
	sim.spawn(pos.clamp(
		Vector2(-ARENA_HALF, -ARENA_HALF), Vector2(ARENA_HALF, ARENA_HALF)))


func _on_sword_hit(pos: Vector2, amount: float, killed: bool) -> void:
	numbers.pop(pos, amount, killed)
	camera.add_trauma(0.06 + (0.28 if killed else 0.0))
	if killed:
		kills += 1
		_hit_stop()


func _hit_stop() -> void:
	if _hitstop_busy:
		return
	_hitstop_busy = true
	Engine.time_scale = 0.05
	# ignore_time_scale on the timer, or the pause would stretch itself
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_busy = false


func _take_shot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://sprint02_shot.png")
	get_tree().quit()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	var vb := VBoxContainer.new()
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	hp_bg.custom_minimum_size = Vector2(260, 18)
	_hud_hp = ColorRect.new()
	_hud_hp.color = Color(0.85, 0.25, 0.25)
	_hud_hp.position = Vector2(2, 2)
	_hud_hp.size = Vector2(256, 14)
	hp_bg.add_child(_hud_hp)
	_hud_kills = Label.new()
	_hud_kills.text = ""
	_hud_fps = Label.new()
	vb.add_child(hp_bg)
	vb.add_child(_hud_kills)
	vb.add_child(_hud_fps)
	margin.add_child(vb)
	layer.add_child(margin)
	player.hp_changed.connect(_on_hp_changed)
	player.died.connect(_on_player_died)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	_hud_hp.size.x = 256.0 * hp / max_hp


func _on_player_died() -> void:
	_dead = true
	player.set_physics_process(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "YOU DIED — restarting…"
	label.add_theme_font_size_override("font_size", 40)
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	await get_tree().create_timer(1.4).timeout
	get_tree().reload_current_scene()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()


# --- debug console handlers ----------------------------------------------------

func console_spawn(n: String) -> String:
	var count := maxi(int(n), 0)
	for k in count:
		_spawn_one()
	return "spawned %d (active %d)" % [count, sim.active_count]


func console_heal() -> String:
	player.hp = player.max_hp
	player.hp_changed.emit(player.hp, player.max_hp)
	return "HP restored"


func console_restart() -> String:
	get_tree().reload_current_scene()
	return "restarting"
