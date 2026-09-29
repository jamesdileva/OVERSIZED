class_name WaveDef
extends Resource

## Schema for one wave (architecture.md §8): the wave runs on a timer while
## enemies keep spawning — the timer ending clears it (survivors despawn,
## Brotato-style). speed/health scales apply to spawns of that wave. Boss
## reference is reserved for Sprint 1.2's first hand-authored boss.

@export var number: int = 1
@export var duration: float = 30.0
@export var spawns_per_second: float = 2.0
@export var max_alive: int = 40
@export var speed_scale: float = 1.0
@export var health_scale: float = 1.0
@export var boss: Resource = null
