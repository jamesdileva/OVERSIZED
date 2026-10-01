extends Node2D

## Sprint 1.2: wave loop + Sword Upgrade picks + XP/leveling + Universal
## Abilities + the wave-10 boss. Kills drop XP gems; Character Level opens
## ability cards (from the full roster — the equipped-loadout restriction
## and passives-on-from-start arrive with the loadout system in Sprint 2.2).
## Boss waves (WaveDef.boss set) end only when the boss dies.

const POOL_CAPACITY := 2000
const ARENA_HALF := 1350.0

var sim: HordeSim
var horde_view: HordeRenderer
var player: Player
var sword: Sword
var camera: CameraRig
var numbers: DamageNumbers
var caster: AbilityCaster
var gems: XpGems
var director := WaveDirector.new()
var choice_screen: ChoiceScreen
var boss: Boss = null

var kills := 0
var taken_upgrades := {}             # SwordUpgradeDef.id -> stack count
var leech_on_kill := 0.0
var xp := 0.0
var character_level := 1
var pending_level_choices := 0
var xp_magnet_radius := 90.0    # written by AbilityCaster passive recompute
var xp_mult := 1.0              # written by AbilityCaster passive recompute
var _choice_kind := ""               # "wave" | "level" — what's on screen now

var _dead := false
var _hitstop_busy := false
var _run_time := 0.0
var boss_kills := 0
var _bot := false
var _bot_target := 0.0
var _equipped_defs: Array = []
var _opening_picks_left := 0
var _shot_mode := false
var _shot_frames := 0
var _shot_boss := false
var _shot_abilities := false
var _shot_burn := false
var _hud_hp: ColorRect
var _hud_xp: ColorRect
var _hud_info: Label
var _boss_bar: ColorRect
var _boss_bar_bg: ColorRect
var _hud_accum := 0.0


func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.09, 0.09, 0.12))
	sim = HordeSim.new(POOL_CAPACITY)
	queue_redraw()  # arena border

	horde_view = HordeRenderer.new()
	add_child(horde_view)
	horde_view.setup(sim, 16.0, Color(0.9, 0.32, 0.22))

	player = Player.new()
	add_child(player)

	sword = Sword.new()
	player.add_child(sword)
	sword.setup(sim, _on_sword_hit)
	sword.combo_burst.connect(_on_combo_burst)
	sword.boss_getter = func() -> Boss: return boss

	caster = AbilityCaster.new()
	player.add_child(caster)
	caster.setup(sim, player, self, _boss_damage_at)
	caster.effect_visual.connect(_on_ability_visual)

	numbers = DamageNumbers.new()
	add_child(numbers)

	gems = XpGems.new()
	add_child(gems)
	gems.player = player
	gems.collected.connect(_on_xp_collected)

	camera = CameraRig.new()
	player.add_child(camera)

	choice_screen = ChoiceScreen.new()
	add_child(choice_screen)
	choice_screen.chosen.connect(_on_choice_made)

	_build_hud()
	DebugConsole.register_handler(self, {
		"spawn": {"args": ["n"], "desc": "spawn n enemies around the player"},
		"heal": {"args": [], "desc": "restore full HP"},
		"wave": {"args": ["n"], "desc": "jump to wave n (for testing late waves)"},
		"give_xp": {"args": ["n"], "desc": "grant n XP (triggers level-ups)"},
		"restart": {"args": [], "desc": "restart the run"},
	})

	sim.enemy_killed.connect(_on_enemy_killed)
	player.died.connect(_on_player_died)

	director.start(ContentLoader.waves)
	_apply_wave_mods()

	# automation flags first — they change how the run starts
	var uargs := OS.get_cmdline_user_args()
	var fi := uargs.find("--shot")
	if fi != -1 and fi + 1 < uargs.size():
		_shot_mode = true
		_shot_frames = maxi(int(uargs[fi + 1]), 1)
		_shot_boss = uargs.has("--boss")
		_shot_abilities = uargs.has("--abilities")
		_shot_burn = uargs.has("--burn")
	var bi := uargs.find("--bot")
	if bi != -1 and bi + 1 < uargs.size():
		_bot = true
		_bot_target = float(maxi(int(uargs[bi + 1]), 1)) * 60.0
		GameManager.bot_active = true
		Engine.time_scale = 8.0
		player.bot = true
		# invulnerable: a kamikaze bot dies every few seconds and never
		# exercises choices, abilities, or the boss — the whole point of the
		# session is sustained progression under load
		player.invulnerable = true

	# equipped loadout (architecture.md §5.2): passives are online from run
	# start at rank 1; actives arrive via the opening pick and level-up cards
	for id in MetaProgression.equipped_ids():
		var def = ContentLoader.ability_by_id(id)
		if def != null:
			_equipped_defs.append(def)
	for def in _equipped_defs:
		if def.kind == "passive":
			caster.bring_online(def)

	if _shot_mode:
		Engine.max_fps = 60
		if _shot_abilities:
			# bring every active online so screenshots show them firing
			for def in ContentLoader.universal_abilities:
				if def.kind == "active" and caster.rank_of(def.id) == 0:
					caster.bring_online(def)
		if _shot_burn:
			# guaranteed Fire Infusion: sword hits burn the horde (orange tint)
			for d in ContentLoader.sword_upgrades:
				if d.id == &"fire_infusion":
					UpgradeEffects.apply(d, _upgrade_ctx())
		if _shot_boss:
			console_wave("10")
		else:
			director.current.duration = minf(director.current.duration, 2.0)
			director.time_left = minf(director.time_left, 2.0)  # the clock copied duration at start
		for k in 30:
			_spawn_one()
		_shot_after(_shot_frames / 60.0)
		_start_wave()
		return

	# opening-ability pick: one at run start, two from Hero Level 20 (§5.2)
	_opening_picks_left = 1 + (1 if MetaProgression.hero_level >= 20 else 0)
	var active_defs := _equipped_defs.filter(func(d): return d.kind == "active")
	if _opening_picks_left > 0 and active_defs.size() > 0:
		get_tree().paused = true
		_open_opening_pick()
	else:
		_start_wave()


func _start_wave() -> void:
	EventBus.wave_started.emit(director.wave_number)
	if director.current.boss != null and boss == null:
		_spawn_boss()


func _spawn_boss() -> void:
	boss = Boss.new()
	boss.setup(director.current.boss, player)
	boss.died.connect(_on_boss_died)
	boss.slammed.connect(func(pos: Vector2, radius: float) -> void:
		var ring := BurstRing.new()
		ring.position = pos
		ring.radius = radius
		ring.life = 0.25
		add_child(ring)
		camera.add_trauma(0.3))
	add_child(boss)


func _draw() -> void:
	# arena boundary — the player clamps here, so show it (proper art in Phase 3)
	var r := Rect2(-ARENA_HALF, -ARENA_HALF, ARENA_HALF * 2.0, ARENA_HALF * 2.0)
	draw_rect(r, Color(0.4, 0.45, 0.6, 0.45), false, 4.0)
	draw_rect(r.grow(6.0), Color(0.4, 0.45, 0.6, 0.15), false, 2.0)


func _physics_process(dt: float) -> void:
	if _dead:
		return
	_run_time += dt
	if _bot:
		_bot_steer()
		if GameManager.bot_elapsed >= _bot_target:
			print("BOT DONE: %.0f sim-s | wave %d | kills %d | fps %d | mem %.1f MB" % [
				GameManager.bot_elapsed, director.wave_number, kills,
				Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
			get_tree().quit(0)
			return
	var to_spawn := director.tick(dt)
	for k in to_spawn:
		if sim.active_count < director.current.max_alive:
			_spawn_one()
	if director.current.boss == null and director.is_cleared():
		_clear_wave()
		return
	sim.step(dt, player.position)
	_contact_damage()


## Bot steering: hold "move toward the nearest enemy" (boss as fallback) —
## the long-session smoke test from implementation-guide.md §14.
func _bot_steer() -> void:
	var p := player.global_position
	var best_pos := Vector2.ZERO
	var best_d := -1.0
	for i in sim.grid.circle_candidates(p, 700.0):
		if i >= sim.active_count:
			continue
		var d: float = sim.positions[i].distance_to(p)
		if best_d < 0.0 or d < best_d:
			best_d = d
			best_pos = sim.positions[i]
	if best_d < 0.0 and boss != null:
		best_pos = boss.global_position
		best_d = p.distance_to(best_pos)
	player.bot_dir = (best_pos - p).normalized() if best_d > 0.0 else Vector2.ZERO


func _process(dt: float) -> void:
	_hud_accum += dt
	if _hud_accum >= 0.25:
		var time_txt := "BOSS" if director.current.boss != null else "%ds" % ceili(director.time_left)
		_hud_info.text = "Wave %d — %s  |  Lv %d  |  enemies %d  |  kills %d  |  [Space] dash  |  [R] restart" % [
			director.wave_number, time_txt, character_level, sim.active_count, kills]
		_hud_accum = 0.0
	if boss != null and boss.brain != null:
		_boss_bar_bg.visible = true
		_boss_bar.size.x = 416.0 * boss.brain.health_fraction()
	else:
		_boss_bar_bg.visible = false


func _spawn_one() -> void:
	var pos := player.position + Vector2.from_angle(randf() * TAU) * randf_range(380.0, 560.0)
	sim.spawn(pos.clamp(
		Vector2(-ARENA_HALF, -ARENA_HALF), Vector2(ARENA_HALF, ARENA_HALF)))


func _clear_wave() -> void:
	sim.clear_all()
	EventBus.wave_cleared.emit(director.wave_number)
	var offers := UpgradeEffects.roll_upgrade_offers(ContentLoader.sword_upgrades, taken_upgrades, 3)
	_choice_kind = "wave"
	get_tree().paused = true
	choice_screen.open("WAVE %d CLEARED — CHOOSE AN UPGRADE" % director.wave_number, offers, taken_upgrades)
	if _bot:
		_bot_auto_pick()


func _on_choice_made(index: int) -> void:
	var def = choice_screen.offers[index]
	match _choice_kind:
		"wave":
			taken_upgrades[def.id] = int(taken_upgrades.get(def.id, 0)) + 1
			UpgradeEffects.apply(def, _upgrade_ctx())
			EventBus.upgrade_selected.emit(def)
			if pending_level_choices > 0:
				pending_level_choices -= 1
				if _open_level_choice():
					return
			get_tree().paused = false
			director.advance()
			_apply_wave_mods()
			_start_wave()
		"opening":
			caster.bring_online(def)
			EventBus.upgrade_selected.emit(def)
			_opening_picks_left -= 1
			if _opening_picks_left > 0 and _open_opening_pick():
				return
			get_tree().paused = false
			_start_wave()
		"level":
			if caster.rank_of(def.id) == 0:
				caster.bring_online(def)
			else:
				caster.rank_up(def.id)
			EventBus.upgrade_selected.emit(def)
			if pending_level_choices > 0:
				pending_level_choices -= 1
				if _open_level_choice():
					return
			get_tree().paused = false


func _upgrade_ctx() -> Dictionary:
	return {"sword": sword, "sim": sim, "player": player, "run": self}


func _apply_wave_mods() -> void:
	var w: WaveDef = director.current
	sim.max_speed = 150.0 * w.speed_scale
	sim.max_health = 30.0 * w.health_scale


func _on_enemy_killed(at: Vector2) -> void:
	kills += 1
	gems.spawn(at, 1.0 + float(director.wave_number) * 0.06)


func _on_xp_collected(amount: float) -> void:
	xp += amount
	var leveled := false
	while xp >= float(RunLevels.xp_needed(character_level)):
		xp -= float(RunLevels.xp_needed(character_level))
		character_level += 1
		leveled = true
	if leveled:
		if choice_screen.visible:
			pending_level_choices += 1   # a wave-clear choice is open; queue behind it
		else:
			_open_level_choice()


## Level-up cards draw from the EQUIPPED loadout only (architecture.md §5.2).
## Returns false when the loadout has nothing left to offer (no pause).
func _open_level_choice() -> bool:
	var offers := UpgradeEffects.roll_upgrade_offers(
		_equipped_defs, caster.taken_ranks(), 3)
	if offers.is_empty():
		return false
	_choice_kind = "level"
	get_tree().paused = true
	choice_screen.open("LEVEL %d — CHOOSE AN ABILITY" % character_level, offers, caster.taken_ranks())
	if _bot:
		_bot_auto_pick()
	return true


## Opening-ability pick: 2-3 random equipped-but-inactive actives.
## Returns false when nothing eligible remains (finishes the opening).
func _open_opening_pick() -> bool:
	var pool := []
	for d in _equipped_defs:
		if d.kind == "active" and caster.rank_of(d.id) == 0:
			pool.append(d)
	if pool.is_empty():
		return false
	pool.shuffle()
	var offers := pool.slice(0, mini(3, pool.size()))
	_choice_kind = "opening"
	get_tree().paused = true
	choice_screen.open("CHOOSE YOUR OPENING ABILITY", offers, caster.taken_ranks())
	if _bot:
		_bot_auto_pick()
	return true


func _bot_auto_pick() -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	if choice_screen.visible and not _dead:
		_on_choice_made(0)


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


func _on_ability_visual(id: StringName, pos: Vector2, radius: float) -> void:
	match id:
		&"ground_slam":
			var ring := BurstRing.new()
			ring.position = pos
			ring.radius = radius
			add_child(ring)
			camera.add_trauma(0.25)
		&"lightning_strike":
			var flash := LightningFlash.new()
			flash.position = pos
			add_child(flash)
			camera.add_trauma(0.12)


func _on_combo_burst(center: Vector2) -> void:
	var radius := 210.0
	var dmg := sword.damage * 2.0
	caster_aoe(center, radius, dmg, 1.4)
	numbers.pop(center + Vector2(0, -30), dmg, true)
	camera.add_trauma(0.4)
	_hit_stop()
	var ring := BurstRing.new()
	ring.position = center
	ring.radius = radius
	add_child(ring)


## Shared AoE used by the combo burst (the caster's own _aoe covers ability
## casts); also reaches the boss.
func caster_aoe(center: Vector2, radius: float, amount: float, knock_scale: float) -> void:
	var mask := Tags.SLASH_BIT | (1 << Tags.Tag.BURST)
	for i in sim.grid.circle_candidates(center, radius):
		if i >= sim.active_count:
			continue
		var away: Vector2 = sim.positions[i] - center
		if away.length_squared() > radius * radius:
			continue
		var push := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
		sim.damage(i, amount, push * knock_scale, mask)
	_boss_damage_at(center, radius, amount, mask)


func _boss_damage_at(pos: Vector2, radius: float, amount: float, tag_mask: int = 0) -> void:
	if boss != null and boss.global_position.distance_to(pos) <= radius + boss.body_radius:
		boss.take_damage(sim.modified(amount, tag_mask))
		numbers.pop(boss.global_position, amount, false)


func _on_boss_died(_pos: Vector2) -> void:
	boss = null
	boss_kills += 1
	camera.add_trauma(0.5)
	_hit_stop()
	_clear_wave()


func _hit_stop() -> void:
	if _hitstop_busy or _bot:
		return
	_hitstop_busy = true
	Engine.time_scale = 0.05
	# ignore_time_scale on the timer, or the pause would stretch itself
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_busy = false


func _shot_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	_take_shot()


func _take_shot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://sprint12_shot.png")
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
	var xp_bg := ColorRect.new()
	xp_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	xp_bg.custom_minimum_size = Vector2(260, 10)
	_hud_xp = ColorRect.new()
	_hud_xp.color = Color(0.35, 0.85, 1.0)
	_hud_xp.position = Vector2(2, 2)
	_hud_xp.size = Vector2(256, 6)
	xp_bg.add_child(_hud_xp)
	_hud_info = Label.new()
	_hud_info.text = ""
	vb.add_child(hp_bg)
	vb.add_child(xp_bg)
	vb.add_child(_hud_info)
	margin.add_child(vb)
	layer.add_child(margin)
	player.hp_changed.connect(_on_hp_changed)
	player.died.connect(_on_player_died)
	# boss bar, top-center
	var boss_layer := CanvasLayer.new()
	boss_layer.layer = 5
	add_child(boss_layer)
	_boss_bar_bg = ColorRect.new()
	_boss_bar_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	_boss_bar_bg.custom_minimum_size = Vector2(420, 16)
	_boss_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_bar_bg.position = Vector2(-210, 14)
	_boss_bar_bg.size = Vector2(420, 16)
	_boss_bar = ColorRect.new()
	_boss_bar.color = Color(1.0, 0.2, 0.55)
	_boss_bar.position = Vector2(2, 2)
	_boss_bar.size = Vector2(416, 12)
	_boss_bar_bg.add_child(_boss_bar)
	_boss_bar_bg.visible = false
	boss_layer.add_child(_boss_bar_bg)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	_hud_hp.size.x = 256.0 * hp / max_hp


func _on_player_died() -> void:
	_dead = true
	player.set_physics_process(false)
	if _bot:
		get_tree().reload_current_scene()  # bot sessions continue across deaths
		return
	var rewards: Dictionary = MetaProgression.record_run(director.wave_number, kills, boss_kills)
	GameManager.last_run = {
		"waves": director.wave_number,
		"kills": kills,
		"level": character_level,
		"time": _run_time,
		"hero_xp": rewards["hero_xp"],
		"glory": rewards["glory"],
	}
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "YOU DIED"
	label.add_theme_font_size_override("font_size", 40)
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	await get_tree().create_timer(1.4, true, false, true).timeout
	GameManager.goto(GameManager.State.SUMMARY)


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
	_start_wave()
	var kind := "BOSS" if director.current.boss != null else "%ds" % ceili(director.time_left)
	return "jumped to wave %d (%s, %.1f spawns/s)" % [
		director.wave_number, kind, director.current.spawns_per_second]


func console_give_xp(n: String) -> String:
	_on_xp_collected(float(maxi(int(n), 1)))
	return "granted XP — level %d, %d choice(s) pending" % [character_level, pending_level_choices]


func console_restart() -> String:
	get_tree().reload_current_scene()
	return "restarting"
