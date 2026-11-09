class_name AbilityCaster
extends Node2D

## Owns the run's Universal Abilities: bring_online / rank_up per def,
## cooldown ticking for actives, the persistent Orbiting Blades hazard, and
## passive stat recompute (recomputed from scratch on every change — no
## delta bookkeeping to get wrong). Fire logic reads rank at cast time;
## visuals are delegated to the run scene via effect_visual, so the caster
## stays testable headless. Damage goes through the HordeGroup (all types);
## boss damage is delegated via a callback because the boss is deliberately
## not part of the pooled sims.
##
## Deliberately Node2D (not Node): persistent hazards and projectiles are
## child nodes, and a plain Node in the parent chain would cut them off from
## the player's transform — they'd sit at world origin instead of following.

signal effect_visual(id: StringName, pos: Vector2, radius: float)
signal evolved(old_id: StringName, new_id: StringName)

var _group: HordeGroup
var _player: Player
var _run                       # run scene: holds xp_magnet_radius / xp_mult for passives
var _boss_damage_at: Callable  # (pos, radius, amount, mask) — run applies it to the boss
var _entries := {}             # id -> {"def": def, "rank": int, "cd": float}
var _aliases := {}             # evolved base id -> result id (rank_of follows the chain)
var _orbit: OrbitBlades = null
var resonances := {}           # tag bit -> true when 3+ equipped abilities share it


func _physics_process(dt: float) -> void:
	tick(dt)


func setup(group: HordeGroup, player: Player, run, boss_damage_at: Callable) -> void:
	_group = group
	_player = player
	_run = run
	_boss_damage_at = boss_damage_at


func bring_online(def: UniversalAbilityDef) -> void:
	var rid := _resolve(def.id)
	if _entries.has(rid):
		return
	_entries[rid] = {"def": def, "rank": 1, "cd": def.cooldown * 0.5}
	_refresh(def)


func rank_up(id: StringName) -> bool:
	var rid := _resolve(id)
	if not _entries.has(rid):
		return false
	var e: Dictionary = _entries[rid]
	var def: UniversalAbilityDef = e["def"]
	if int(e["rank"]) >= def.max_rank:
		return false
	e["rank"] = int(e["rank"]) + 1
	_refresh(def)
	return true


## Resolves evolution aliases: after Orbiting Blades evolves into Solar
## Halo, every query for "orbit_blades" (offers, ranks, bring_online)
## resolves to "solar_halo" — the base ability can never be re-picked to
## reset the evolved form.
func _resolve(id: StringName) -> StringName:
	while _aliases.has(id):
		id = _aliases[id]
	return id


func rank_of(id: StringName) -> int:
	var rid := _resolve(id)
	return int(_entries[rid]["rank"]) if _entries.has(rid) else 0


func taken_ranks() -> Dictionary:
	var out := {}
	for id in _entries:
		out[id] = int(_entries[id]["rank"])
	for old in _aliases:
		out[old] = rank_of(_aliases[old])   # aliased bases report their result's rank, so the offer roller caps them
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


## Evolve an equipped ability that hit the conditions (EvolutionDef):
## the entry is replaced by the result def, carrying its rank over.
func evolve(old_id: StringName, result: UniversalAbilityDef) -> bool:
	var rid := _resolve(old_id)
	if not _entries.has(rid) or _entries.has(_resolve(result.id)):
		return false
	var rank := int(_entries[rid]["rank"])
	_entries.erase(rid)
	_entries[result.id] = {"def": result, "rank": rank, "cd": 0.0}
	_aliases[rid] = result.id
	_refresh(result)
	evolved.emit(old_id, result.id)
	return true


func _refresh(def: UniversalAbilityDef) -> void:
	var rid := _resolve(def.id)
	if def.kind == "passive":
		_refresh_passives()
	elif def.effect_id == &"orbit_blades":
		_ensure_orbit(rid, def)


func _fire(def: UniversalAbilityDef, rank: int) -> void:
	var p := _player.global_position
	match def.effect_id:
		&"ground_slam":
			var radius := 170.0 + 14.0 * float(rank - 1)
			var dmg := def.magnitude * (1.0 + 0.5 * float(rank - 1))
			_aoe(p, radius, dmg, 1.4, def.tags)
			effect_visual.emit(&"ground_slam", p, radius)
		&"lightning_strike":
			var victim := _random_victim(p, 520.0)
			if victim.sim == null:
				return  # nobody in range: cooldown restarts, effect skips
			var pos: Vector2 = victim.sim.positions[victim.index]
			victim.sim.damage(victim.index, def.magnitude * (1.0 + 0.4 * float(rank - 1)), Vector2.ZERO, def.tags)
			effect_visual.emit(&"lightning_strike", pos, 60.0)
		&"spirit_blade":
			var blade := SpiritBlade.new()
			blade.setup(_group, def.magnitude * (1.0 + 0.35 * float(rank - 1)), def.tags)
			add_child(blade)
			blade.global_position = p
		_:
			push_warning("unknown ability effect_id: %s" % def.effect_id)


## {sim, index} of a random living enemy within `range` across all types.
func _random_victim(p: Vector2, radius: float) -> Dictionary:
	var all := []
	for h in _group.hordes:
		var s: HordeSim = h["sim"]
		for i in s.grid.circle_candidates(p, radius):
			if i < s.active_count:
				all.append({"sim": s, "index": i})
	if all.is_empty():
		return {"sim": null, "index": -1}
	return all[randi() % all.size()]


func _aoe(center: Vector2, radius: float, amount: float, knock_scale: float, tag_mask: int) -> void:
	_group.circle_damage(center, radius, amount, tag_mask, knock_scale)
	if _boss_damage_at.is_valid():
		_boss_damage_at.call(center, radius, amount, tag_mask)


func _refresh_passives() -> void:
	var max_hp := 100.0
	var speed := 300.0
	var magnet := 90.0
	var xp_mult := 1.0
	var armor := 0.0
	var regen := 0.0
	resonances.clear()
	var tag_counts := {}   # tag bit -> number of equipped abilities carrying it
	_group.clear_damage_mods()  # recomputed from scratch with the stats
	for id in _entries:
		var e: Dictionary = _entries[id]
		var def: UniversalAbilityDef = e["def"]
		var rank := int(e["rank"])
		# resonance counting covers every equipped ability, active or passive
		for bit in [Tags.FIRE_BIT, Tags.FROST_BIT, Tags.BLOOD_BIT]:
			if (def.tags & bit) != 0:
				tag_counts[bit] = int(tag_counts.get(bit, 0)) + 1
		if def.kind != "passive":
			continue
		match def.effect_id:
			&"vitality":
				max_hp += 20.0 * float(rank)
			&"swift_boots":
				speed *= 1.0 + 0.08 * float(rank)
			&"lodestone":
				magnet += 45.0 * float(rank)
			&"scholars_wit":
				xp_mult += 0.10 * float(rank)
			&"plating":
				armor += def.magnitude * float(rank)
			&"regeneration":
				regen += def.magnitude * float(rank)
			&"tag_amplifier":
				_group.add_increased(def.tags, def.magnitude * float(rank))
	# resonance tier-1 (architecture.md §5.4): 3+ equipped sharing an element
	# grants +15% increased damage of that element
	for bit in tag_counts:
		if int(tag_counts[bit]) >= 3:
			resonances[bit] = true
			_group.add_increased(bit, 0.15)
	_player.set_max_hp(max_hp)
	_player.move_speed = speed
	_player.armor = armor
	_player.regen_ps = regen
	_run.xp_magnet_radius = magnet
	_run.xp_mult = xp_mult
	_run.gems.xp_mult = xp_mult   # gems apply the multiplier at pickup


func has_resonance(tag_bit: int) -> bool:
	return resonances.get(tag_bit, false)


func _ensure_orbit(rid: StringName, def: UniversalAbilityDef) -> void:
	if _orbit == null:
		_orbit = OrbitBlades.new()
		add_child(_orbit)
		_orbit.setup(_group, _player)
	_orbit.configure(int(_entries[rid]["rank"]), def.magnitude)
	_orbit.tag_mask = def.tags
