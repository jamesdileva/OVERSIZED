class_name UniversalAbilityDef
extends Resource

## Schema for one Universal Ability or passive (architecture.md §8). Each
## actual ability is a .tres file in res://resources/universal_abilities/ —
## adding content never means writing scripts (implementation-guide.md §3).
## effect_id maps to a branch in AbilityCaster; tags ride along as data
## until the synergy layer consumes them (Sprint 2.1/2.4). The AP cost and
## unlock_level are inert until the Hero Level loadout system (Sprint 2.2).

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export_enum("active", "passive") var kind: String = "active"
@export var ap_cost: int = 3               # actives 2-5, passives 1-3
@export var unlock_level: int = 1
@export var tags: int = 0                  # Tags bitmask (architecture.md §5.4)
@export var max_rank: int = 5              # actives 5, passives 3
@export var cooldown: float = 3.0          # actives only; 0 would mean persistent
@export var effect_id: StringName
@export var magnitude: float = 1.0         # primary scaling number, rank-scaled by the handler
@export var rarity_weight: float = 1.0     # offer-roll weighting (synergy bias multiplies this in 2.4)
