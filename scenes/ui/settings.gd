extends Control

## Settings skeleton (Sprint 2.5): volume sliders wired to the AudioBus
## buses, fullscreen toggle — persisted to user://audio_settings.json.
## Reached from the menu or the hub; returns to wherever opened it.


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
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		vb.add_child(_slider_row(bus_name))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = AudioBus.fullscreen
	fs.toggled.connect(func(on: bool) -> void: AudioBus.set_fullscreen(on))
	vb.add_child(fs)
	vb.add_child(_spacer(10))
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(240, 44)
	back.pressed.connect(_go_back)
	vb.add_child(back)
	back.grab_focus()


func _slider_row(bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = bus_name
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioBus.volumes[bus_name]
	slider.custom_minimum_size = Vector2(280, 20)
	slider.value_changed.connect(func(v: float) -> void: AudioBus.set_volume(bus_name, v))
	row.add_child(slider)
	return row


## Settings opens from both the menu and the hub — return to whoever opened it.
func _go_back() -> void:
	if GameManager.settings_return == GameManager.State.MENU:
		GameManager.goto(GameManager.State.MENU)
	else:
		GameManager.goto(GameManager.State.HUB)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
