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

# economy pass #1 (Sprint 2.5): named so tuning is a one-place edit.
# Glory intentionally rewards depth (waves/bosses) over grind (kills).
const REWARD_XP_PER_WAVE := 8.0
const REWARD_XP_PER_KILL := 0.3
const REWARD_XP_PER_BOSS := 25.0
const REWARD_GLORY_BASE := 10
const REWARD_GLORY_PER_WAVE := 3
const REWARD_GLORY_PER_KILL := 0.05
const REWARD_GLORY_PER_BOSS := 15

var save_path := "user://meta_save.json"
var ability_lookup: Callable = Callable()   # id -> UniversalAbilityDef (tests inject; default resolves via ContentLoader)
var cosmetic_lookup: Callable = Callable()  # id -> CosmeticItemDef (tests inject; default resolves via ContentLoader)
var curve: ProgressionCurve = null          # set from ContentLoader at ready

var hero_xp := 0.0
var hero_level := 1
var glory := 0
var best_wave := 0
var total_kills := 0
var total_runs := 0
var loadouts: Array = []            # [{name: String, ability_ids: Array[StringName]}]
var last_loadout_index := 0
var owned_cosmetics: Array = []             # StringName ids
var equipped_cosmetics: Dictionary = {}     # slot -> StringName id


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
## Applies a finished run's rewards and stat tracking, saves, and returns the
## earned amounts for the Run Summary screen. (Bot/automation runs skip this.)
func record_run(waves_reached: int, kills: int, boss_kills: int) -> Dictionary:
	var earned_xp := waves_reached * REWARD_XP_PER_WAVE + kills * REWARD_XP_PER_KILL + boss_kills * REWARD_XP_PER_BOSS
	var earned_glory := REWARD_GLORY_BASE + int(waves_reached * REWARD_GLORY_PER_WAVE + kills * REWARD_GLORY_PER_KILL + boss_kills * REWARD_GLORY_PER_BOSS)
	add_hero_xp(earned_xp)
	glory += earned_glory
	best_wave = maxi(best_wave, waves_reached)
	total_kills += kills
	total_runs += 1
	save()
	return {"hero_xp": earned_xp, "glory": earned_glory}


# --- cosmetics -----------------------------------------------------------------

## HARD RULE context: cosmetics carry zero stats (cosmetic_item_def.gd has no
## stat fields by construction) — these methods only track ownership and
## which visual is equipped per slot.
func owns_cosmetic(id: StringName) -> bool:
	return owned_cosmetics.has(id)


func _cosmetic_def_of(id: StringName):
	if cosmetic_lookup.is_valid():
		return cosmetic_lookup.call(id)
	return ContentLoader.cosmetic_by_id(id)


## Returns "" on success or the reason the purchase was refused.
func buy_cosmetic(def) -> String:
	if def == null:
		return "unknown cosmetic"
	if owns_cosmetic(def.id):
		return "already owned"
	if glory < def.glory_cost:
		return "not enough Glory (%d/%d)" % [glory, def.glory_cost]
	glory -= def.glory_cost
	owned_cosmetics.append(def.id)
	save()
	return ""


func equip_cosmetic(id: StringName) -> String:
	var def = _cosmetic_def_of(id)
	if def == null:
		return "unknown cosmetic"
	if not owns_cosmetic(id):
		return "not owned yet"
	equipped_cosmetics[def.slot] = id
	save()
	return ""


func unequip_slot(slot: String) -> void:
	equipped_cosmetics.erase(slot)
	save()


## Resolves the equipped cosmetics to defs: {slot: CosmeticItemDef}.
func equipped_cosmetic_defs() -> Dictionary:
	var out := {}
	for slot in equipped_cosmetics:
		var def = _cosmetic_def_of(equipped_cosmetics[slot])
		if def != null:
			out[slot] = def
	return out


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
		"owned_cosmetics": owned_cosmetics,
		"equipped_cosmetics": equipped_cosmetics,
	}
	# atomic write (Sprint 2.5 hardening): land a temp file first, keep the
	# previous save as .bak, then swap — a crash mid-write can't corrupt the
	# live profile.
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("meta save failed: %s" % tmp)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		push_warning("meta save swap failed (%s) — keeping previous file" % error_string(err))


## Always starts from defaults, then overwrites from disk — so a corrupt or
## missing file cleanly yields a fresh profile instead of stale half-state.
## Falls back to the .bak backup when the live save is unreadable.
## Schema 1 saves (no loadouts/cosmetics) load with defaults for new fields.
func load_save() -> void:
	hero_xp = 0.0
	hero_level = 1
	glory = 0
	best_wave = 0
	total_kills = 0
	total_runs = 0
	loadouts = []
	last_loadout_index = 0
	owned_cosmetics = []
	equipped_cosmetics = {}
	var data := _read_save_file(save_path)
	if data.is_empty() and FileAccess.file_exists(save_path + ".bak"):
		push_warning("meta save unreadable — trying backup")
		data = _read_save_file(save_path + ".bak")
	if data.is_empty():
		return
	hero_xp = float(data.get("hero_xp", 0.0))
	hero_level = maxi(int(data.get("hero_level", 1)), 1)
	glory = int(data.get("glory", 0))
	best_wave = int(data.get("best_wave", 0))
	total_kills = int(data.get("total_kills", 0))
	total_runs = int(data.get("total_runs", 0))
	var raw_loadouts = data.get("loadouts", [])
	if typeof(raw_loadouts) == TYPE_ARRAY:
		for entry in raw_loadouts:
			if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("ability_ids", [])) == TYPE_ARRAY:
				loadouts.append({"name": str(entry.get("name", "Loadout")), "ability_ids": entry["ability_ids"]})
	last_loadout_index = clampi(int(data.get("last_loadout_index", 0)), 0, maxi(loadouts.size() - 1, 0))
	var raw_owned = data.get("owned_cosmetics", [])
	if typeof(raw_owned) == TYPE_ARRAY:
		for id in raw_owned:
			owned_cosmetics.append(StringName(str(id)))
	var raw_equipped = data.get("equipped_cosmetics", {})
	if typeof(raw_equipped) == TYPE_DICTIONARY:
		for slot in raw_equipped:
			equipped_cosmetics[str(slot)] = StringName(str(raw_equipped[slot]))


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("meta save unreadable: %s" % path)
		return {}
	var schema: int = int(parsed.get("schema_version", 0))
	if schema > SCHEMA_VERSION:
		push_warning("meta save from a newer build — ignoring: %s" % path)
		return {}
	return parsed
