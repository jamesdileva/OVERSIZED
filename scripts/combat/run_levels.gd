class_name RunLevels
extends RefCounted

## In-run Character Level XP curve (pure logic, testable). Deliberately a
## function rather than a resource: it's run-scoped tuning with one knob;
## promote to a resource if it ever needs per-wave authoring.

## XP required to go from `level` to `level + 1`.
static func xp_needed(level: int) -> int:
	var n := maxi(level - 1, 0)
	return 5 + n * 6 + n * n


## Character level reached for a total XP amount (level 1 at 0 XP).
static func level_for_xp(xp: float) -> int:
	var level := 1
	var remaining := xp
	while remaining >= xp_needed(level):
		remaining -= xp_needed(level)
		level += 1
	return level
