class_name ChoiceScreen
extends CanvasLayer

## The shared pick UI (implementation-guide.md §9): shows up to CARD_COUNT
## cards over a dimmed, tree-paused run and emits chosen(index). Deliberately
## data-agnostic — callers pass view objects + an owned-counts map, so the
## Universal Ability picks (Sprint 1.2) reuse this component unchanged.
## Pausing the tree is the caller's job; this node runs in PROCESS_MODE_ALWAYS
## so its buttons work while everything else is frozen.

signal chosen(index: int)

const CARD_COUNT := 3

var offers: Array = []         # caller-owned objects, mapped by index

var _title: Label
var _buttons: Array[Button] = []


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
	vb.add_theme_constant_override("separation", 20)
	dim.add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	vb.add_child(cards)
	for k in CARD_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 220)
		b.add_theme_font_size_override("font_size", 18)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_card.bind(k))
		cards.add_child(b)
		_buttons.append(b)


func open(wave: int, p_offers: Array, p_owned: Dictionary = {}) -> void:
	offers = p_offers
	_title.text = "WAVE %d CLEARED — CHOOSE AN UPGRADE" % wave
	for k in _buttons.size():
		var b := _buttons[k]
		if k < offers.size():
			var def: SwordUpgradeDef = offers[k]
			b.visible = true
			var stacks: int = p_owned.get(def.id, 0)
			var owned := "  (owned ×%d)" % stacks if stacks > 0 else ""
			b.text = "%s%s\n\n%s" % [def.display_name, owned, def.description]
		else:
			b.visible = false
	visible = true
	_buttons[0].grab_focus()


func _on_card(index: int) -> void:
	visible = false
	chosen.emit(index)
