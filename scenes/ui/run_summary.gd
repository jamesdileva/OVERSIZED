extends Control

## Run Summary, shown after death: what you did, what you earned (Hero XP +
## Glory — applied to MetaProgression by the run before this screen opens),
## then on to the hub.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var run: Dictionary = GameManager.last_run
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := Label.new()
	title.text = "RUN SUMMARY"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	vb.add_child(_row("Waves reached", str(run.get("waves", 0))))
	vb.add_child(_row("Kills", str(run.get("kills", 0))))
	vb.add_child(_row("Character Level", str(run.get("level", 1))))
	var t: float = run.get("time", 0.0)
	vb.add_child(_row("Time survived", "%d:%02d" % [int(t) / 60, int(t) % 60]))
	vb.add_child(_spacer(10))
	vb.add_child(_row("+Hero XP", str(int(run.get("hero_xp", 0.0)))))
	vb.add_child(_row("+Glory", str(run.get("glory", 0))))
	vb.add_child(_row("Hero Level", str(MetaProgression.hero_level)))
	vb.add_child(_spacer(18))
	var cont := Button.new()
	cont.text = "Continue"
	cont.custom_minimum_size = Vector2(260, 48)
	cont.add_theme_font_size_override("font_size", 22)
	cont.pressed.connect(func() -> void: GameManager.goto(GameManager.State.HUB))
	vb.add_child(cont)
	cont.grab_focus()


func _row(label: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(220, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = Color(1, 1, 1, 0.7)
	hb.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 20)
	hb.add_child(v)
	return hb


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
