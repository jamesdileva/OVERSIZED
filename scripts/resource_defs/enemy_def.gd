class_name EnemyDef
extends Resource

## Schema for one enemy type (architecture.md §8): stats + a movement
## behavior + spawn data. Each type runs in its own HordeSim instance
## (one MultiMesh archetype per type, implementation-guide.md §6.4).
## min_wave/spawn_weight ARE the spawn-composition data — an enemy joins
## the weighted pool once the wave number reaches min_wave.

@export var id: StringName
@export var display_name: String
@export var max_health: float = 30.0
@export var move_speed: float = 150.0
@export var scale: float = 1.0             # visual + contact-footprint size
@export var contact_damage: float = 9.0
@export var behavior: String = "chaser"    # chaser / swarmer / tank / ranged / exploder
@export var xp_value: float = 1.0
@export var tint: Color = Color(0.9, 0.32, 0.22)
@export var min_wave: int = 1
@export var spawn_weight: float = 1.0

# ranged behavior (attack_range > 0 enables it)
@export var attack_range: float = 0.0
@export var fire_interval: float = 2.4
@export var projectile_speed: float = 260.0
@export var projectile_damage: float = 8.0

# exploder behavior (trigger_radius > 0 enables it)
@export var trigger_radius: float = 0.0
@export var windup_time: float = 0.5
@export var blast_radius: float = 0.0
@export var blast_damage: float = 0.0
