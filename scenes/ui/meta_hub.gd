extends Control

## Meta Hub: the between-runs screen. Shows Hero Level progress and Glory,
## Start Run, and the loadout stub (the full AP loadout screen is Sprint 2.2;
## the roadmap explicitly allows a stub here). Power and looks stay visually
## separate — Glory spending itself arrives with the cosmetics system (2.5).


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := Label.new()
	title.text = "THE HUB"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	# hero level + progress
	var lvl := Label.new()
	lvl.text = "Hero Level %d  —  %d / %d XP to next" % [
		MetaProgression.hero_level,
		int(MetaProgression.hero_xp),
		MetaProgression.hero_xp_needed(MetaProgression.hero_level)]
	lvl.add_theme_font_size_override("font_size", 20)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lvl)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.custom_minimum_size = Vector2(340, 14)
	var bar := ColorRect.new()
	bar.color = Color(0.45, 0.85, 0.5)
	bar.position = Vector2(2, 2)
	var frac := MetaProgression.hero_xp / float(MetaProgression.hero_xp_needed(MetaProgression.hero_level))
	bar.size = Vector2(336.0 * clampf(frac, 0.0, 1.0), 10)
	bar_bg.add_child(bar)
	vb.add_child(bar_bg)
	var glory := Label.new()
	glory.text = "Glory: %d   |   Best wave: %d   |   Runs: %d   |   Total kills: %d" % [
		MetaProgression.glory, MetaProgression.best_wave,
		MetaProgression.total_runs, MetaProgression.total_kills]
	glory.add_theme_font_size_override("font_size", 18)
	glory.modulate = Color(1, 1, 1, 0.8)
	glory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(glory)
	vb.add_child(_spacer(16))
	var start := Button.new()
	start.text = "Start Run"
	start.custom_minimum_size = Vector2(280, 48)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(func() -> void: GameManager.goto(GameManager.State.RUN))
	vb.add_child(start)
	var loadout := Button.new()
	loadout.text = "Loadout"
	loadout.custom_minimum_size = Vector2(280, 48)
	loadout.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn"))
	vb.add_child(loadout)
	var back := Button.new()
	back.text = "Back to Menu"
	back.custom_minimum_size = Vector2(280, 48)
	back.pressed.connect(func() -> void: GameManager.goto(GameManager.State.MENU))
	vb.add_child(back)
	start.grab_focus()
	DebugConsole.register_handler(self, {
		"hero_level": {"args": ["n"], "desc": "simulate Hero Level n (debug, reloads hub)"},
		"give_glory": {"args": ["n"], "desc": "grant n Glory (debug)"},
	})


func console_hero_level(n: String) -> String:
	MetaProgression.set_hero_level(maxi(int(n), 1))
	get_tree().reload_current_scene()
	return "Hero Level set to %d — %d abilities owned, %d AP budget" % [
		MetaProgression.hero_level,
		MetaProgression.owned_abilities().size(),
		MetaProgression.ap_budget()]


func console_give_glory(n: String) -> String:
	MetaProgression.glory += maxi(int(n), 0)
	MetaProgression.save()
	return "Glory: %d" % MetaProgression.glory


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
