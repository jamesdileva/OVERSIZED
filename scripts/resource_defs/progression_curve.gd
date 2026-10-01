class_name ProgressionCurve
extends Resource

## The entire Hero Level progression feel in one data file
## (architecture.md §5.2): XP per level, AP budget per level, the equipment
## slot cap, and which abilities unlock at which level. Retuning progression
## is a spreadsheet edit here — never code (implementation-guide.md §3).
##
## xp_required[level - 1] = XP to go from `level` to `level + 1`.
## ap_budget[level - 1]   = AP budget at `level`.
## roster_unlocks         = level (int) -> Array[StringName] ability ids.

@export var xp_required: Array[int] = []
@export var ap_budget: Array[int] = []
@export var slot_cap: int = 12
@export var roster_unlocks: Dictionary = {}


func ap_for(level: int) -> int:
	return ap_budget[clampi(level - 1, 0, ap_budget.size() - 1)]


func xp_needed(level: int) -> int:
	return xp_required[clampi(level - 1, 0, xp_required.size() - 1)]


func unlocks_at(level: int) -> Array:
	return roster_unlocks.get(level, [])


## Every ability id unlocked at or below `level`, in unlock order.
func owned_through(level: int) -> Array:
	var out := []
	for l in range(1, level + 1):
		out.append_array(unlocks_at(l))
	return out
