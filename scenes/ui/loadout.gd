extends Control

## Loadout screen (architecture.md §5.2): equip owned abilities within the
## AP budget and the 12-slot cap. Equip/unequip is free and instant — trying
## on builds, not committing. Three preset slots save/restore kits. Reached
## from the hub; returns to it.

var _owned_box: VBoxContainer
var _equipped_box: VBoxContainer
var _ap_label: Label
var _slots_label: Label
var _error: Label
var _preset_row: HBoxContainer


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
	title.text = "LOADOUT — Hero Level %d" % MetaProgression.hero_level
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_ap_label = Label.new()
	_ap_label.add_theme_font_size_override("font_size", 20)
	_ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_ap_label)
	_slots_label = Label.new()
	_slots_label.add_theme_font_size_override("font_size", 16)
	_slots_label.modulate = Color(1, 1, 1, 0.65)
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_slots_label)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	vb.add_child(columns)
	var owned_col := VBoxContainer.new()
	owned_col.add_theme_constant_override("separation", 6)
	columns.add_child(owned_col)
	var owned_head := Label.new()
	owned_head.text = "Owned — click to equip"
	owned_head.modulate = Color(1, 1, 1, 0.7)
	owned_col.add_child(owned_head)
	_owned_box = VBoxContainer.new()
	_owned_box.add_theme_constant_override("separation", 6)
	owned_col.add_child(_owned_box)
	var equipped_col := VBoxContainer.new()
	equipped_col.add_theme_constant_override("separation", 6)
	columns.add_child(equipped_col)
	var equipped_head := Label.new()
	equipped_head.text = "Equipped — click to unequip"
	equipped_head.modulate = Color(1, 1, 1, 0.7)
	equipped_col.add_child(equipped_head)
	_equipped_box = VBoxContainer.new()
	_equipped_box.add_theme_constant_override("separation", 6)
	equipped_col.add_child(_equipped_box)
	_error = Label.new()
	_error.add_theme_font_size_override("font_size", 16)
	_error.modulate = Color(1.0, 0.45, 0.4)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_error)
	_preset_row = HBoxContainer.new()
	_preset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_preset_row.add_theme_constant_override("separation", 10)
	vb.add_child(_preset_row)
	var back := Button.new()
	back.text = "Back to Hub"
	back.custom_minimum_size = Vector2(240, 44)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/meta_hub.tscn"))
	vb.add_child(back)
	_refresh()


func _refresh() -> void:
	for c in _owned_box.get_children():
		_owned_box.remove_child(c)
		c.free()
	for c in _equipped_box.get_children():
		_equipped_box.remove_child(c)
		c.free()
	for c in _preset_row.get_children():
		_preset_row.remove_child(c)
		c.free()
	var equipped: Array = MetaProgression.equipped_ids()
	var used := 0
	for id in equipped:
		used += MetaProgression._cost_of(id)
	_ap_label.text = "AP %d / %d" % [used, MetaProgression.ap_budget()]
	_slots_label.text = "slots %d / %d  —  swapping is free, changes save instantly" % [
		equipped.size(), MetaProgression.slot_cap()]
	for id in MetaProgression.owned_abilities():
		var def = ContentLoader.ability_by_id(id)
		if def == null or equipped.has(id):
			continue
		var b := Button.new()
		b.text = "%s  (%d AP, %s)" % [def.display_name, def.ap_cost, def.kind]
		b.pressed.connect(func() -> void:
			_error.text = MetaProgression.equip(def.id)
			_refresh.call_deferred())
		_owned_box.add_child(b)
	for id in equipped:
		var def = ContentLoader.ability_by_id(id)
		var b := Button.new()
		b.text = (def.display_name if def != null else str(id)) + "  —  unequip"
		b.pressed.connect(func() -> void:
			MetaProgression.unequip(id)
			_error.text = ""
			_refresh.call_deferred())
		_equipped_box.add_child(b)
	for k in 3:
		var slot_i := k
		var load_btn := Button.new()
		load_btn.text = "Preset %d: %s" % [k + 1, _slot_summary(k)]
		load_btn.pressed.connect(func() -> void:
			MetaProgression.select_slot(slot_i)
			_error.text = ""
			_refresh.call_deferred())
		_preset_row.add_child(load_btn)
		var save_btn := Button.new()
		save_btn.text = "Save"
		save_btn.pressed.connect(func() -> void:
			MetaProgression.save_slot_as(slot_i)
			_error.text = ""
			_refresh.call_deferred())
		_preset_row.add_child(save_btn)


func _slot_summary(i: int) -> String:
	if i >= MetaProgression.loadouts.size():
		return "(empty)"
	var ids: Array = MetaProgression.loadouts[i]["ability_ids"]
	return "%d abilities" % ids.size()
