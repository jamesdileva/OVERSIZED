class_name CosmeticItemDef
extends Resource

## Schema for one cosmetic (architecture.md §8, implementation-guide §11).
## HARD RULE: cosmetics carry ZERO stats — this schema intentionally has no
## health/damage/speed/magnitude fields, and everything here is purely
## visual (tints for placeholder art; real art swaps in Phase 3). If a
## field would ever affect gameplay, it does not belong on this resource.

@export var id: StringName
@export var display_name: String
@export var description: String
@export_enum("hero_skin", "sword_skin", "trail", "victory_pose") var slot: String = "sword_skin"
@export var glory_cost: int = 50
@export var tint: Color = Color.WHITE          # visual-only tint (hero body / blade / trail)
@export var smear_color: Color = Color(1.0, 0.9, 0.7, 0.28)  # sword skins: sweep smear
