extends Control

## Cosmetics shop: spend Glory on visual-only cosmetics and equip them per
## slot (hero skin / sword skin / trail). HARD RULE context: nothing here
## touches stats — CosmeticItemDef has no stat fields to spend on.

var _glory_label: Label
var _rows_box: VBoxContainer
var _error: Label


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
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var title := Label.new()
	title.text = "COSMETICS — look cool, stay equally deadly"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_glory_label = Label.new()
	_glory_label.add_theme_font_size_override("font_size", 20)
	_glory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_glory_label)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	vb.add_child(_rows_box)
	_error = Label.new()
	_error.add_theme_font_size_override("font_size", 15)
	_error.modulate = Color(1.0, 0.45, 0.4)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_error)
	var back := Button.new()
	back.text = "Back to Hub"
	back.custom_minimum_size = Vector2(240, 44)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/meta_hub.tscn"))
	vb.add_child(back)
	_refresh()


func _refresh() -> void:
	for c in _rows_box.get_children():
		_rows_box.remove_child(c)
		c.free()
	_glory_label.text = "Glory: %d" % MetaProgression.glory
	var equipped: Dictionary = MetaProgression.equipped_cosmetic_defs()
	for def in ContentLoader.cosmetics:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		var slot_name: String = def.slot.replace("_", " ")
		var state := ""
		if MetaProgression.owns_cosmetic(def.id):
			state = "OWNED"
			if equipped.has(def.slot) and equipped[def.slot].id == def.id:
				state = "EQUIPPED"
		label.text = "%s  [%s]  —  %d Glory  %s" % [def.display_name, slot_name, def.glory_cost, state]
		label.add_theme_font_size_override("font_size", 17)
		if state == "EQUIPPED":
			label.modulate = Color(0.6, 1.0, 0.6)
		row.add_child(label)
		if not MetaProgression.owns_cosmetic(def.id):
			var buy := Button.new()
			buy.text = "Buy"
			buy.pressed.connect(func() -> void:
				_error.text = MetaProgression.buy_cosmetic(def)
				_refresh.call_deferred())
			row.add_child(buy)
		elif not (equipped.has(def.slot) and equipped[def.slot].id == def.id):
			var eq := Button.new()
			eq.text = "Equip"
			eq.pressed.connect(func() -> void:
				_error.text = MetaProgression.equip_cosmetic(def.id)
				_refresh.call_deferred())
			row.add_child(eq)
		elif equipped.has(def.slot) and equipped[def.slot].id == def.id:
			var un := Button.new()
			un.text = "Unequip"
			un.pressed.connect(func() -> void:
				MetaProgression.unequip_slot(def.slot)
				_refresh.call_deferred())
			row.add_child(un)
		_rows_box.add_child(row)
	var back_focus := Button.new()
	back_focus.visible = false
	_rows_box.add_child(back_focus)
	back_focus.grab_focus()
