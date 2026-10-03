extends Node

## Scans and caches all .tres content at boot (implementation-guide.md §3).
## New content = new .tres files in the watched directories; nothing else
## changes. Autoloaded as ContentLoader.

var sword_upgrades: Array = []
var universal_abilities: Array = []
var enemies: Array = []
var waves: Array = []
var progression_curve: ProgressionCurve = null

var _ability_index: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	sword_upgrades = _scan_dir("res://resources/sword_upgrades")
	universal_abilities = _scan_dir("res://resources/universal_abilities")
	enemies = _scan_dir("res://resources/enemies")
	waves = _scan_dir("res://resources/waves")
	waves.sort_custom(func(a, b): return a.number < b.number)
	var curves := _scan_dir("res://resources/progression")
	if curves.size() > 0:
		progression_curve = curves[0]
	_ability_index.clear()
	for def in universal_abilities:
		_ability_index[def.id] = def


func ability_by_id(id: StringName) -> UniversalAbilityDef:
	return _ability_index.get(id)


func _scan_dir(path: String) -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(path):
		push_warning("content dir missing: " + path)
		return out
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".tres"):
			out.append(load(path + "/" + f))
	return out
