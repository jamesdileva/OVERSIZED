extends Control

## Main menu: title, Start Run, Quit. Gamepad-first (first button focused;
## ui_* navigation). GameManager decides what boots here for automation.


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
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var title := Label.new()
	title.text = "OVERSIZED"
	title.add_theme_font_size_override("font_size", 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "one hero. one absurdly oversized sword. it never stops swinging."
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(_spacer(24))
	var start := Button.new()
	start.text = "Start Run"
	start.custom_minimum_size = Vector2(260, 48)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(func() -> void: GameManager.goto(GameManager.State.RUN))
	vb.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(260, 48)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)
	start.grab_focus()


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
