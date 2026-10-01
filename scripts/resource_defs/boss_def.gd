class_name BossDef
extends Resource

## Schema for one hand-authored boss (architecture.md §8): a telegraphed
## attack-pattern state machine with HP-phase thresholds handled by BossBrain
## and an enrage soft timer. champion_modifier_slots exists from day one
## (implementation-guide.md §8) but stays unused until Phase 2.3.

@export var id: StringName
@export var display_name: String
@export var max_health: float = 800.0
@export var move_speed: float = 95.0
@export var contact_damage: float = 16.0
@export var attack_interval: float = 2.4   # seconds between attack patterns
@export var telegraph_time: float = 0.75
@export var charge_speed: float = 720.0
@export var charge_damage: float = 22.0
@export var slam_radius: float = 190.0
@export var slam_damage: float = 26.0
@export var enrage_time: float = 75.0      # soft floor: after this the boss speeds up
@export var champion_modifier_slots: int = 0
