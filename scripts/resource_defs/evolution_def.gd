class_name EvolutionDef
extends Resource

## The synergy payoff (architecture.md §5.4): a specific ability at max
## rank + a specific Sword Upgrade transforms into a stronger evolved form.
## Data-driven — new evolutions are .tres files here, no code.

@export var id: StringName
@export var ability_id: StringName            # base ability, must be at max rank
@export var requires_upgrade_id: StringName   # SwordUpgradeDef id, must be taken
@export var result_id: StringName             # the evolved ability def
