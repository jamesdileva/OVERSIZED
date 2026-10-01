class_name AbilityCaster
extends Node2D

## Owns the run's Universal Abilities: bring_online / rank_up per def,
## cooldown ticking for actives, the persistent Orbiting Blades hazard, and
## passive stat recompute (recomputed from scratch on every change — no
## delta bookkeeping to get wrong). Fire logic reads rank at cast time;
## visuals are delegated to the run scene via effect_visual, so the caster
## stays testable headless. Boss damage is delegated via a callback because
## the boss is deliberately not part of the pooled sim.
##
## Deliberately Node2D (not Node): persistent hazards and projectiles are
## child nodes, and a plain Node in the parent chain would cut them off from
## the player's transform — they'd sit at world origin instead of following.

signal effect_visual(id: StringName, pos: Vector2, radius: float)

var _sim: HordeSim
var _player: Player
var _run                       # run scene: holds xp_magnet_radius / xp_mult for passives
var _boss_damage_at: Callable  # (pos, radius, amount) — run applies it to the boss
var _entries := {}             # id -> {"def": def, "rank": int, "cd": float}
var _orbit: OrbitBlades = null


func _physics_process(dt: float) -> void:
	tick(dt)


func setup(sim: HordeSim, player: Player, run, boss_damage_at: Callable) -> void:
	_sim = sim
	_player = player
	_run = run
	_boss_damage_at = boss_damage_at


func bring_online(def: UniversalAbilityDef) -> void:
	if _entries.has(def.id):
		return
	_entries[def.id] = {"def": def, "rank": 1, "cd": def.cooldown * 0.5}
	_refresh(def)


func rank_up(id: StringName) -> bool:
	if not _entries.has(id):
		return false
	var e: Dictionary = _entries[id]
	var def: UniversalAbilityDef = e["def"]
	if int(e["rank"]) >= def.max_rank:
		return false
	e["rank"] = int(e["rank"]) + 1
	_refresh(def)
	return true


func rank_of(id: StringName) -> int:
	return int(_entries[id]["rank"]) if _entries.has(id) else 0


func taken_ranks() -> Dictionary:
	var out := {}
	for id in _entries:
		out[id] = int(_entries[id]["rank"])
	return out


## Called by _physics_process in-game; tests call it directly.
func tick(dt: float) -> void:
	for id in _entries:
		var e: Dictionary = _entries[id]
		var def: UniversalAbilityDef = e["def"]
		if def.kind != "active" or def.cooldown <= 0.0:
			continue
		e["cd"] = float(e["cd"]) - dt
		if float(e["cd"]) <= 0.0:
			_fire(def, int(e["rank"]))
			e["cd"] = def.cooldown
	if _orbit != null:
		_orbit.tick_damage(dt)


func _refresh(def: UniversalAbilityDef) -> void:
	if def.kind == "passive":
		_refresh_passives()
	elif def.effect_id == &"orbit_blades":
		_ensure_orbit()


func _fire(def: UniversalAbilityDef, rank: int) -> void:
	var p := _player.global_position
	match def.effect_id:
		&"ground_slam":
			var radius := 170.0 + 14.0 * float(rank - 1)
			var dmg := def.magnitude * (1.0 + 0.5 * float(rank - 1))
			_aoe(p, radius, dmg, 1.4)
			effect_visual.emit(&"ground_slam", p, radius)
		&"lightning_strike":
			var cands := _sim.grid.circle_candidates(p, 520.0)
			if cands.is_empty():
				return  # nobody in range: cooldown restarts, effect skips
			var i: int = cands[randi() % cands.size()]
			var pos: Vector2 = _sim.positions[i]
			_sim.damage(i, def.magnitude * (1.0 + 0.4 * float(rank - 1)), Vector2.ZERO)
			effect_visual.emit(&"lightning_strike", pos, 60.0)
		&"spirit_blade":
			var blade := SpiritBlade.new()
			blade.setup(_sim, def.magnitude * (1.0 + 0.35 * float(rank - 1)))
			add_child(blade)
			blade.global_position = p
		_:
			push_warning("unknown ability effect_id: %s" % def.effect_id)


func _aoe(center: Vector2, radius: float, amount: float, knock_scale: float) -> void:
	for i in _sim.grid.circle_candidates(center, radius):
		if i >= _sim.active_count:
			continue
		var away: Vector2 = _sim.positions[i] - center
		if away.length_squared() > radius * radius:
			continue
		var push := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
		_sim.damage(i, amount, push * knock_scale)
	if _boss_damage_at.is_valid():
		_boss_damage_at.call(center, radius, amount)


func _refresh_passives() -> void:
	var max_hp := 100.0
	var speed := 300.0
	var magnet := 90.0
	var xp_mult := 1.0
	for id in _entries:
		var e: Dictionary = _entries[id]
		var def: UniversalAbilityDef = e["def"]
		if def.kind != "passive":
			continue
		var rank := int(e["rank"])
		match def.effect_id:
			&"vitality":
				max_hp += 20.0 * float(rank)
			&"swift_boots":
				speed *= 1.0 + 0.08 * float(rank)
			&"lodestone":
				magnet += 45.0 * float(rank)
			&"scholars_wit":
				xp_mult += 0.10 * float(rank)
	_player.set_max_hp(max_hp)
	_player.move_speed = speed
	_run.xp_magnet_radius = magnet
	_run.xp_mult = xp_mult


func _ensure_orbit() -> void:
	if _orbit == null:
		_orbit = OrbitBlades.new()
		add_child(_orbit)
		_orbit.setup(_sim, _player)
	_orbit.configure(int(_entries[&"orbit_blades"]["rank"]))
