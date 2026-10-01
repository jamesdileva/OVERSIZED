class_name SwordUpgradeDef
extends Resource

## Schema for one Sword Upgrade (architecture.md §8). Each actual upgrade is
## a .tres file in res://resources/sword_upgrades/ — adding content never
## means writing scripts (implementation-guide.md §3). effect_id maps to a
## handler branch in UpgradeEffects until the Phase 2 data-driven pipeline
## replaces per-effect code.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export_enum("stat_mod", "on_hit_effect", "passive") var effect_type: String = "stat_mod"
@export var effect_id: StringName
@export var magnitude: float = 1.0
@export var rarity_weight: float = 1.0
@export var max_stacks: int = 0            # 0 = unlimited stacks
@export var tags: int = 0                  # Tags bitmask (architecture.md §5.4)
