extends Node

## Persistent meta state + save system (implementation-guide.md §10): one
## JSON file in user://, carrying schema_version from the very first write.
## Corrupt or future-versioned files fall back to fresh defaults — boot
## never crashes on a bad save. Autoloaded as MetaProgression.

const SCHEMA_VERSION := 1

var save_path := "user://meta_save.json"

var hero_xp := 0.0
var hero_level := 1
var glory := 0
var best_wave := 0
var total_kills := 0
var total_runs := 0


func _ready() -> void:
	load_save()


## Hero Level pacing target: ~level 10 within a couple of hours of runs
## (architecture.md §5.2). Replaced by the ProgressionCurve resource in
## Sprint 2.2 — until then this curve is the single tuning knob.
static func hero_xp_needed(level: int) -> int:
	return 100 + (level - 1) * 80


func add_hero_xp(amount: float) -> void:
	hero_xp += amount
	while hero_xp >= float(hero_xp_needed(hero_level)):
		hero_xp -= float(hero_xp_needed(hero_level))
		hero_level += 1


## Applies a finished run's rewards and stat tracking, saves, and returns the
## earned amounts for the Run Summary screen. (Bot/automation runs skip this.)
func record_run(waves_reached: int, kills: int, boss_kills: int) -> Dictionary:
	var earned_xp := waves_reached * 8.0 + kills * 0.3 + boss_kills * 25.0
	var earned_glory := int(waves_reached * 2 + kills / 10.0 + boss_kills * 10)
	add_hero_xp(earned_xp)
	glory += earned_glory
	best_wave = maxi(best_wave, waves_reached)
	total_kills += kills
	total_runs += 1
	save()
	return {"hero_xp": earned_xp, "glory": earned_glory}


func save() -> void:
	var data := {
		"schema_version": SCHEMA_VERSION,
		"hero_xp": hero_xp,
		"hero_level": hero_level,
		"glory": glory,
		"best_wave": best_wave,
		"total_kills": total_kills,
		"total_runs": total_runs,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("meta save failed: %s" % save_path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Always starts from defaults, then overwrites from disk — so a corrupt or
## missing file cleanly yields a fresh profile instead of stale half-state.
func load_save() -> void:
	hero_xp = 0.0
	hero_level = 1
	glory = 0
	best_wave = 0
	total_kills = 0
	total_runs = 0
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("meta save unreadable — starting fresh")
		return
	var schema: int = int(parsed.get("schema_version", 0))
	if schema > SCHEMA_VERSION:
		push_warning("meta save from a newer build — starting fresh")
		return
	hero_xp = float(parsed.get("hero_xp", 0.0))
	hero_level = maxi(int(parsed.get("hero_level", 1)), 1)
	glory = int(parsed.get("glory", 0))
	best_wave = int(parsed.get("best_wave", 0))
	total_kills = int(parsed.get("total_kills", 0))
	total_runs = int(parsed.get("total_runs", 0))
