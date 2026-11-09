class_name ChoiceScreen
extends CanvasLayer

## The shared pick UI (implementation-guide.md §9): builds one card per
## offer (dynamic count) over a dimmed, tree-paused run and emits
## chosen(index). Sprint 2.4 added reroll + banish + rarity tiers; Sprint
## 2.5.1 made the card count dynamic so the opening pick can offer every
## equipped active. Pausing the tree is the caller's job; this node runs in
## PROCESS_MODE_ALWAYS so its buttons work while frozen.

signal chosen(index: int)
signal rerolled
signal banished(index: int)

var offers: Array = []         # caller-owned objects, mapped by index
var rerolls_left := 0
var banishes_left := 0

var _title: Label
var _footer: Label
var _cards_box: HBoxContainer
var _reroll_btn: Button
var _banish_buttons: Array[Button] = []


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 12)
	dim.add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 16)
	vb.add_child(_cards_box)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	vb.add_child(controls)
	_reroll_btn = Button.new()
	_reroll_btn.add_theme_font_size_override("font_size", 16)
	_reroll_btn.pressed.connect(func() -> void: rerolled.emit())
	controls.add_child(_reroll_btn)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 14)
	_footer.modulate = Color(1, 1, 1, 0.6)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_footer)


func open(title: String, p_offers: Array, p_owned: Dictionary = {}, p_rerolls := 0, p_banishes := 0) -> void:
	offers = p_offers
	rerolls_left = p_rerolls
	banishes_left = p_banishes
	_title.text = title
	for c in _cards_box.get_children():
		_cards_box.remove_child(c)
		c.free()
	var first_button: Button = null
	for k in offers.size():
		var def = offers[k]
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 4)
		_cards_box.add_child(slot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 200)
		b.add_theme_font_size_override("font_size", 18)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_card.bind(k))
		var stacks: int = p_owned.get(def.id, 0)
		var owned := "  (owned ×%d)" % stacks if stacks > 0 else ""
		var tier: StringName = UpgradeEffects.rarity_tier(def.rarity_weight)
		b.text = "%s  [%s]\n%s\n\n%s" % [def.display_name, tier, owned, def.description]
		slot.add_child(b)
		if first_button == null:
			first_button = b
		var ban := Button.new()
		ban.text = "Banish"
		ban.add_theme_font_size_override("font_size", 13)
		ban.visible = banishes_left > 0
		ban.pressed.connect(_on_banish.bind(k))
		slot.add_child(ban)
		_banish_buttons.append(ban)
	_reroll_btn.text = "Reroll (%d left)" % rerolls_left
	_reroll_btn.visible = rerolls_left > 0
	_footer.text = "Banishes left: %d" % banishes_left
	visible = true
	if first_button != null:
		first_button.grab_focus()


func _on_card(index: int) -> void:
	visible = false
	chosen.emit(index)


func _on_banish(index: int) -> void:
	if banishes_left <= 0:
		return
	banishes_left -= 1
	visible = false
	banished.emit(index)
