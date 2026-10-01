extends Node

## Persistent meta state + save system (implementation-guide.md §10): one
## JSON file in user://, carrying schema_version from the very first write.
## Corrupt or future-versioned files fall back to fresh defaults — boot
## never crashes on a bad save. Autoloaded as MetaProgression.
##
## Sprint 2.2: Hero Level is driven by the ProgressionCurve resource, and
## loadouts (named ability-id sets, AP/equip rules enforced in equip()) are
## saved with the profile. Saves from schema 1 load fine — they simply get
## a default loadout on first hub visit.

const SCHEMA_VERSION := 2

var save_path := "user://meta_save.json"
var ability_lookup: Callable = Callable()   # id -> UniversalAbilityDef (tests inject; default resolves via ContentLoader)
var curve: ProgressionCurve = null          # set from ContentLoader at ready

var hero_xp := 0.0
var hero_level := 1
var glory := 0
var best_wave := 0
var total_kills := 0
var total_runs := 0
var loadouts: Array = []            # [{name: String, ability_ids: Array[StringName]}]
var last_loadout_index := 0


func _ready() -> void:
	if ContentLoader.progression_curve != null:
		curve = ContentLoader.progression_curve
	load_save()


# --- progression ---------------------------------------------------------------

## Hero Level pacing (architecture.md §5.2): ~level 10 within a couple of
## hours. The curve resource owns the numbers when present; these constants
## are the fallback so the game still runs without content.
static func hero_xp_needed(level: int) -> int:
	return 100 + (level - 1) * 80


func xp_to_next() -> int:
	return curve.xp_needed(hero_level) if curve != null else hero_xp_needed(hero_level)


func ap_budget() -> int:
	return curve.ap_for(hero_level) if curve != null else 5


func slot_cap() -> int:
	return curve.slot_cap if curve != null else 12


## Ability ids unlocked at or below the current Hero Level.
func owned_abilities() -> Array:
	if curve != null:
		return curve.owned_through(hero_level)
	return []


func add_hero_xp(amount: float) -> void:
	hero_xp += amount
	while hero_xp >= float(xp_to_next()):
		hero_xp -= float(xp_to_next())
		hero_level += 1


## Debug/automation: jump straight to a Hero Level (DoD simulates L10/L20).
## Resets the default loadout so the greedy fill reflects the new roster.
func set_hero_level(n: int) -> void:
	hero_level = clampi(n, 1, 50)
	hero_xp = 0.0
	loadouts = []
	last_loadout_index = 0
	ensure_default_loadout()
	save()


# --- run rewards ---------------------------------------------------------------

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


# --- loadouts ------------------------------------------------------------------

## First visit: one "Default" loadout, filled greedily with everything owned
## that fits the AP budget (cheapest first) so a fresh hero brings a sane kit.
func ensure_default_loadout() -> void:
	if not loadouts.is_empty():
		return
	var kit := []
	var used := 0
	var owned := owned_abilities()
	var priced := []
	for id in owned:
		priced.append({"id": id, "cost": _cost_of(id)})
	priced.sort_custom(func(a, b): return a["cost"] < b["cost"])
	for p in priced:
		if kit.size() >= slot_cap():
			break
		if used + int(p["cost"]) <= ap_budget():
			kit.append(p["id"])
			used += int(p["cost"])
	loadouts.append({"name": "Default", "ability_ids": kit})


func equipped_ids() -> Array:
	ensure_default_loadout()
	return loadouts[last_loadout_index]["ability_ids"]


func _cost_of(id: StringName) -> int:
	var def = null
	if ability_lookup.is_valid():
		def = ability_lookup.call(id)
	elif ContentLoader.universal_abilities.size() > 0:
		def = ContentLoader.ability_by_id(id)
	return int(def.ap_cost) if def != null else 3


## Equip under the rules: not already equipped, slot cap, AP budget.
## Returns "" on success or the reason it was refused (UI shows it).
func equip(id: StringName) -> String:
	ensure_default_loadout()
	var ids: Array = loadouts[last_loadout_index]["ability_ids"]
	if ids.has(id):
		return "already equipped"
	if ids.size() >= slot_cap():
		return "slot cap reached (%d)" % slot_cap()
	var used := 0
	for aid in ids:
		used += _cost_of(aid)
	var cost := _cost_of(id)
	if used + cost > ap_budget():
		return "not enough AP (%d/%d used, this costs %d)" % [used, ap_budget(), cost]
	ids.append(id)
	save()
	return ""


func unequip(id: StringName) -> void:
	ensure_default_loadout()
	var ids: Array = loadouts[last_loadout_index]["ability_ids"]
	ids.erase(id)
	save()


## Presets: copy the current kit into slot i (creating it if needed) and make
## it active; loading a preset is just selecting its slot.
func save_slot_as(i: int) -> void:
	ensure_default_loadout()
	while loadouts.size() <= i:
		loadouts.append({"name": "Preset %d" % (loadouts.size() + 1), "ability_ids": []})
	loadouts[i]["ability_ids"] = (loadouts[last_loadout_index]["ability_ids"] as Array).duplicate()
	last_loadout_index = i
	save()


func select_slot(i: int) -> void:
	ensure_default_loadout()
	last_loadout_index = clampi(i, 0, loadouts.size() - 1)
	save()


# --- persistence ---------------------------------------------------------------

func save() -> void:
	var data := {
		"schema_version": SCHEMA_VERSION,
		"hero_xp": hero_xp,
		"hero_level": hero_level,
		"glory": glory,
		"best_wave": best_wave,
		"total_kills": total_kills,
		"total_runs": total_runs,
		"loadouts": loadouts,
		"last_loadout_index": last_loadout_index,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("meta save failed: %s" % save_path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Always starts from defaults, then overwrites from disk — so a corrupt or
## missing file cleanly yields a fresh profile instead of stale half-state.
## Schema 1 saves (no loadouts) load with defaults for the new fields.
func load_save() -> void:
	hero_xp = 0.0
	hero_level = 1
	glory = 0
	best_wave = 0
	total_kills = 0
	total_runs = 0
	loadouts = []
	last_loadout_index = 0
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
	var raw_loadouts = parsed.get("loadouts", [])
	if typeof(raw_loadouts) == TYPE_ARRAY:
		for entry in raw_loadouts:
			if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("ability_ids", [])) == TYPE_ARRAY:
				loadouts.append({"name": str(entry.get("name", "Loadout")), "ability_ids": entry["ability_ids"]})
	last_loadout_index = clampi(int(parsed.get("last_loadout_index", 0)), 0, maxi(loadouts.size() - 1, 0))
