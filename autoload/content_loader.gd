extends Node

## Scans and caches all .tres content at boot (implementation-guide.md §3).
## New content = new .tres files in the watched directories; nothing else
## changes. Autoloaded as ContentLoader.

var sword_upgrades: Array = []
var waves: Array = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	sword_upgrades = _scan_dir("res://resources/sword_upgrades")
	waves = _scan_dir("res://resources/waves")
	waves.sort_custom(func(a, b): return a.number < b.number)


func _scan_dir(path: String) -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(path):
		push_warning("content dir missing: " + path)
		return out
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".tres"):
			out.append(load(path + "/" + f))
	return out
