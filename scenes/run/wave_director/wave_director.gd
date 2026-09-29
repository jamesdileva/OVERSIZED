class_name WaveDirector
extends RefCounted

## Wave loop clock (architecture.md §4): each wave runs on a timer while
## enemies keep spawning; the timer ending clears the wave regardless of
## survivors (run.gd despawns them Brotato-style — payouts arrive with
## currencies in Sprint 1.3). Beyond the hand-authored defs, later waves
## scale the last def by curve (architecture.md §9's "endless" answer).

var waves: Array = []          # WaveDefs sorted by number
var wave_number := 0
var current: WaveDef = null
var time_left := 0.0

var _spawn_budget := 0.0


func start(p_waves: Array) -> void:
	waves = p_waves
	wave_number = 0
	_next()


func _next() -> void:
	wave_number += 1
	current = def_for(wave_number)
	time_left = current.duration
	_spawn_budget = 0.0


## Waves past the authored list scale the last def: denser, tougher, faster —
## capped so late waves stay survivable rather than instantly lethal.
func def_for(n: int) -> WaveDef:
	var base: WaveDef = waves[mini(n, waves.size()) - 1]
	if n <= waves.size():
		return base
	var over := float(n - waves.size())
	var scaled: WaveDef = base.duplicate()
	scaled.spawns_per_second = base.spawns_per_second * (1.0 + 0.12 * over)
	scaled.max_alive = mini(base.max_alive + 4 * int(over), 120)
	scaled.speed_scale = minf(base.speed_scale * (1.0 + 0.03 * over), 1.8)
	scaled.health_scale = base.health_scale * (1.0 + 0.25 * over)
	return scaled


## Accumulates spawn allowance; the caller spawns the returned count
## (respecting max_alive) and steps the sim.
func tick(dt: float) -> int:
	if current == null:
		return 0
	_spawn_budget += current.spawns_per_second * dt
	var count := int(_spawn_budget)
	_spawn_budget -= float(count)
	time_left = maxf(0.0, time_left - dt)
	return count


func is_cleared() -> bool:
	return current != null and time_left <= 0.0


func advance() -> void:
	_next()
