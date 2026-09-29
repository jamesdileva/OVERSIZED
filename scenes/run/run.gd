extends Node2D

## Sprint 1.1: wave loop + Sword Upgrade picks. Waves cycle on a timer
## (architecture.md §4) while enemies keep spawning; the timer ending clears
## the wave (survivors despawn, no payout until currencies exist in 1.3) and
## opens the shared choice screen. Picks apply through UpgradeEffects and
## visibly change the sword. No XP/abilities (1.2), no meta (1.3).

const POOL_CAPACITY := 2000
const ARENA_HALF := 1350.0

var sim: HordeSim
var horde_view: HordeRenderer
var player: Player
var sword: Sword
var camera: CameraRig
var numbers: DamageNumbers
var director := WaveDirector.new()
var choice_screen: ChoiceScreen

var kills := 0
var taken := {}                # SwordUpgradeDef.id -> stack count
var leech_on_kill := 0.0

var _dead := false
var _hitstop_busy := false
var _hud_hp: ColorRect
var _hud_info: Label
var _hud_accum := 0.0


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
	sword.combo_burst.connect(_on_combo_burst)

	numbers = DamageNumbers.new()
	add_child(numbers)

	camera = CameraRig.new()
	player.add_child(camera)

	choice_screen = ChoiceScreen.new()
	add_child(choice_screen)
	choice_screen.chosen.connect(_on_upgrade_chosen)

	_build_hud()
	DebugConsole.register_handler(self, {
		"spawn": {"args": ["n"], "desc": "spawn n enemies around the player"},
		"heal": {"args": [], "desc": "restore full HP"},
		"wave": {"args": ["n"], "desc": "jump to wave n (for testing late waves)"},
		"restart": {"args": [], "desc": "restart the run"},
	})

	sim.enemy_killed.connect(func(_at: Vector2) -> void: kills += 1)
	player.died.connect(_on_player_died)

	director.start(ContentLoader.waves)
	_apply_wave_mods()
	EventBus.wave_started.emit(director.wave_number)

	# automated gameplay screenshot: --shot <frames> — the countdown runs on
	# an ignore-time-scale, process-always timer so it can also capture the
	# paused choice screen; wave 1 is shortened so the choice screen appears
	var uargs := OS.get_cmdline_user_args()
	var fi := uargs.find("--shot")
	if fi != -1 and fi + 1 < uargs.size():
		var frames := maxi(int(uargs[fi + 1]), 1)
		Engine.max_fps = 60
		director.current.duration = minf(director.current.duration, 2.0)
		director.time_left = minf(director.time_left, 2.0)  # the clock copied duration at start
		for k in 30:
			_spawn_one()
		_shot_after(frames / 60.0)


func _shot_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	_take_shot()


func _physics_process(dt: float) -> void:
	if _dead:
		return
	var to_spawn := director.tick(dt)
	for k in to_spawn:
		if sim.active_count < director.current.max_alive:
			_spawn_one()
	if director.is_cleared():
		_clear_wave()
		return
	sim.step(dt, player.position)
	_contact_damage()


func _process(dt: float) -> void:
	_hud_accum += dt
	if _hud_accum >= 0.25:
		var combo_txt := ""
		if sword.combo.threshold > 0:
			combo_txt = "  |  combo %d/%d" % [sword.combo.hits, sword.combo.threshold]
		_hud_info.text = "Wave %d — %ds  |  enemies %d  |  kills %d%s  |  [Space] dash  |  [R] restart" % [
			director.wave_number, ceili(director.time_left), sim.active_count, kills, combo_txt]
		_hud_accum = 0.0


func _spawn_one() -> void:
	var pos := player.position + Vector2.from_angle(randf() * TAU) * randf_range(380.0, 560.0)
	sim.spawn(pos.clamp(
		Vector2(-ARENA_HALF, -ARENA_HALF), Vector2(ARENA_HALF, ARENA_HALF)))


func _clear_wave() -> void:
	sim.clear_all()
	EventBus.wave_cleared.emit(director.wave_number)
	var offers := UpgradeEffects.roll_upgrade_offers(ContentLoader.sword_upgrades, taken, 3)
	get_tree().paused = true
	choice_screen.open(director.wave_number, offers, taken)


func _on_upgrade_chosen(index: int) -> void:
	var def: SwordUpgradeDef = choice_screen.offers[index]
	taken[def.id] = int(taken.get(def.id, 0)) + 1
	UpgradeEffects.apply(def, _upgrade_ctx())
	EventBus.upgrade_selected.emit(def)
	get_tree().paused = false
	director.advance()
	_apply_wave_mods()
	EventBus.wave_started.emit(director.wave_number)


func _upgrade_ctx() -> Dictionary:
	return {"sword": sword, "sim": sim, "player": player, "run": self}


func _apply_wave_mods() -> void:
	var w: WaveDef = director.current
	sim.max_speed = 150.0 * w.speed_scale
	sim.max_health = 30.0 * w.health_scale


func _contact_damage() -> void:
	var p := player.position
	for i in sim.grid.circle_candidates(p, 34.0):
		if i >= sim.active_count:
			continue
		var to: Vector2 = p - sim.positions[i]
		if to.length_squared() < 26.0 * 26.0:
			player.hurt(9.0, to.normalized())
			break


func _on_sword_hit(pos: Vector2, amount: float, killed: bool) -> void:
	numbers.pop(pos, amount, killed)
	camera.add_trauma(0.06 + (0.28 if killed else 0.0))
	if killed and leech_on_kill > 0.0:
		player.heal(leech_on_kill)
	if killed:
		_hit_stop()


func _on_combo_burst(center: Vector2) -> void:
	var radius := 210.0
	var dmg := sword.damage * 2.0
	for i in sim.grid.circle_candidates(center, radius):
		if i >= sim.active_count:
			continue
		var away: Vector2 = sim.positions[i] - center
		if away.length_squared() > radius * radius:
			continue
		var push := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
		sim.damage(i, dmg, push)
	numbers.pop(center + Vector2(0, -30), dmg, true)
	camera.add_trauma(0.4)
	_hit_stop()
	var ring := BurstRing.new()
	ring.position = center
	ring.radius = radius
	add_child(ring)


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
		img.save_png("user://sprint11_shot.png")
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
	_hud_info = Label.new()
	_hud_info.text = ""
	vb.add_child(hp_bg)
	vb.add_child(_hud_info)
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


func console_wave(n: String) -> String:
	var target := maxi(int(n), 1)
	director.wave_number = target - 1
	director.advance()
	_apply_wave_mods()
	return "jumped to wave %d (%.0fs, %0.1f spawns/s)" % [
		director.wave_number, director.time_left, director.current.spawns_per_second]


func console_restart() -> String:
	get_tree().reload_current_scene()
	return "restarting"
