class_name SpatialHash
extends RefCounted

## Uniform-grid spatial hash over an externally-owned position array.
## Neighbor queries use a 3x3 cell neighborhood, which is correct as long
## as the query radius is <= cell_size (enforced by HordeSim's cell sizing).
##
## Cells store plain Arrays on purpose: Arrays are returned by reference,
## so hot loops can iterate a cell without copying. A PackedInt32Array
## value would be copied on every dictionary read.

var cell_size: float

var _cells: Dictionary = {}          # Vector2i -> Array[int] (enemy indices)
var _used_keys: Array[Vector2i] = [] # keys touched this rebuild, for cheap reset
var _empty: Array = []               # shared empty cell, so query misses allocate nothing


func _init(p_cell_size: float) -> void:
	cell_size = p_cell_size


## Rebuild all cells from the first `count` entries of `positions`.
## Cell arrays are reused across frames to avoid per-frame reallocation.
## A key is recorded in _used_keys when its cell is empty at insert time —
## i.e. once per frame per used cell — so every touched cell is cleared on
## the next rebuild and stale indices can never accumulate.
func rebuild(positions: PackedVector2Array, count: int) -> void:
	for key in _used_keys:
		_cells[key].clear()
	_used_keys.clear()
	for i in count:
		var key := key_of(positions[i])
		var cell = _cells.get(key)
		if cell == null:
			cell = []
			_cells[key] = cell
		if cell.is_empty():
			_used_keys.append(key)
		cell.append(i)


func key_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))


## Live cell contents for `key` (reference semantics — iterate, don't store;
## contents are invalid after the next rebuild).
func cell(key: Vector2i) -> Array:
	var out = _cells.get(key)
	return out if out != null else _empty


## Superset query around a circle: every index whose position is within
## `radius` of `center` is guaranteed to be included. Works for radii larger
## than cell_size (the cell range is expanded to cover it). The result may
## contain enemies outside the radius — callers apply the exact distance test.
func circle_candidates(center: Vector2, radius: float) -> PackedInt32Array:
	var rings := int(ceil(radius / cell_size))
	var home := key_of(center)
	var out := PackedInt32Array()
	for oy in range(-rings, rings + 1):
		for ox in range(-rings, rings + 1):
			var cell_arr = _cells.get(home + Vector2i(ox, oy), _empty)
			for j in cell_arr:
				out.append(j)
	return out


func clear() -> void:
	_cells.clear()
	_used_keys.clear()


## Debug/verification: total indices stored across all cells. After a rebuild
## of `count` entries this must equal `count` — anything else means stale
## entries survived (the regression bench caught in Sprint 0.1).
func total_entries() -> int:
	var total := 0
	for key in _cells:
		total += _cells[key].size()
	return total
