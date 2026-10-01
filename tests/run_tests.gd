extends SceneTree

## Headless test runner for the horde-spike logic (no scene, no autoloads):
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 on pass, 1 on any failure. Deterministic (fixed seed).

var failures := 0


func _initialize() -> void:
	seed(20260928)
	_test_scripts_compile()
	_test_pool_basics()
	_test_pool_swap_remove_integrity()
	_test_hash_matches_bruteforce()
	_test_hash_rebuild_clears_stale()
	_test_hash_rebuild_no_accumulation()
	_test_sim_converges_on_target()
	_test_sim_survives_despawn_mid_run()
	_test_sword_swing_cycles_forever()
	_test_sword_swing_window()
	_test_hash_circle_candidates_superset()
	_test_sim_damage_and_death()
	_test_upgrade_defs_load()
	_test_roll_offers()
	_test_wave_director()
	_test_combo_counter()
	_test_spin_swing()
	_test_upgrade_effects_apply()
	_test_run_levels()
	_test_boss_brain()
	_test_ability_caster()
	_test_meta_progression()
	_test_game_manager_scenes()
	_test_tags()
	_test_statuses()
	_test_damage_mods()
	_test_tags_coverage()
	_test_progression_curve()
	_test_loadout_rules()
	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("%d TEST(S) FAILED" % failures)
		quit(1)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  " + label)
	else:
		failures += 1
		print("  FAIL  " + label)


## A script with a parse error aborts any test that touches its class
## silently — the suite would still print PASSED. So first verify every
## critical script compiles, as checks (a broken script = visible FAIL).
func _test_scripts_compile() -> void:
	print("scripts: all critical scripts compile")
	var paths := [
		"res://scripts/horde/spatial_hash.gd",
		"res://scripts/horde/horde_sim.gd",
		"res://scripts/horde/horde_renderer.gd",
		"res://scripts/combat/sword_swing.gd",
		"res://scripts/combat/combo_counter.gd",
		"res://scripts/combat/upgrade_effects.gd",
		"res://scripts/combat/ability_caster.gd",
		"res://scripts/combat/run_levels.gd",
		"res://scripts/combat/boss_brain.gd",
		"res://scripts/combat/tags.gd",
		"res://scripts/resource_defs/progression_curve.gd",
		"res://scenes/run/wave_director/wave_director.gd",
		"res://scenes/run/player/player.gd",
		"res://scenes/run/player/sword.gd",
		"res://scenes/run/run.gd",
		"res://scenes/run/camera_rig.gd",
		"res://scenes/run/damage_numbers.gd",
		"res://scenes/run/burst_ring.gd",
		"res://scenes/run/stress_test.gd",
		"res://scenes/run/xp_gems.gd",
		"res://scenes/run/boss/boss.gd",
		"res://scenes/run/abilities/orbit_blades.gd",
		"res://scenes/run/abilities/spirit_blade.gd",
		"res://scenes/run/abilities/lightning_flash.gd",
		"res://scenes/ui/choice_screen/choice_screen.gd",
		"res://scenes/ui/main_menu.gd",
		"res://scenes/ui/run_summary.gd",
		"res://scenes/ui/meta_hub.gd",
		"res://scenes/ui/loadout.gd",
		"res://autoload/content_loader.gd",
		"res://autoload/event_bus.gd",
		"res://autoload/debug_console.gd",
		"res://autoload/meta_progression.gd",
		"res://autoload/game_manager.gd",
		"res://autoload/audio_bus.gd",
	]
	for p in paths:
		var s = load(p)
		check(s != null and s.can_instantiate(), "script compiles: " + p)


func _test_pool_basics() -> void:
	print("pool: spawn/despawn basics")
	var sim := HordeSim.new(8)
	var ordered := true
	for k in 8:
		if sim.spawn(Vector2(k, 0)) != k:
			ordered = false
	check(ordered, "spawn fills slots 0..7 in order")
	check(sim.active_count == 8, "active_count == 8 after 8 spawns")
	check(sim.spawn(Vector2(99, 0)) == -1, "spawn past capacity returns -1")
	check(sim.active_count == 8, "capacity is hard-limited")
	sim.despawn(3)
	check(sim.active_count == 7, "despawn decrements active_count")
	check(sim.positions[3] == Vector2(7, 0), "swap-remove moved last slot into hole")
	sim.despawn(-1)
	sim.despawn(99)
	check(sim.active_count == 7, "out-of-range despawn is ignored")
	sim.clear_all()
	check(sim.active_count == 0, "clear_all empties the pool")
	check(sim.spawn(Vector2.ZERO) == 0, "slots reusable after clear_all")


func _test_pool_swap_remove_integrity() -> void:
	print("pool: swap-remove integrity vs mirrored model")
	var sim := HordeSim.new(64)
	var expected: Array[Vector2] = []
	for k in 50:
		var p := Vector2(randf() * 100.0, randf() * 100.0)
		sim.spawn(p)
		expected.append(p)
	for step in 30:
		var i := randi_range(0, sim.active_count - 1)
		sim.despawn(i)
		expected[i] = expected[expected.size() - 1]
		expected.pop_back()
	var ok := sim.active_count == expected.size()
	for i in sim.active_count:
		if sim.positions[i] != expected[i]:
			ok = false
	check(ok, "active slots match mirrored model after 30 random despawns")


func _test_hash_matches_bruteforce() -> void:
	print("spatial hash: neighbor query == brute force")
	var grid := SpatialHash.new(50.0)
	var pts := PackedVector2Array()
	pts.resize(200)
	for i in 200:
		pts[i] = Vector2(randf() * 1000.0, randf() * 1000.0)
	grid.rebuild(pts, 200)
	var radius := 30.0
	var radius_sq := radius * radius
	var ok := true
	for trial in 25:
		var q := Vector2(randf() * 1000.0, randf() * 1000.0)
		var brute := {}
		for i in 200:
			if pts[i].distance_squared_to(q) <= radius_sq:
				brute[i] = true
		var found := {}
		var home := grid.key_of(q)
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				for j in grid.cell(home + Vector2i(ox, oy)):
					if pts[j].distance_squared_to(q) <= radius_sq:
						found[j] = true
		if found.size() != brute.size():
			ok = false
			break
		for j in found:
			if not brute.has(j):
				ok = false
	check(ok, "3x3-cell query equals brute force (25 random queries, r=30 <= cell=50)")


func _test_hash_rebuild_clears_stale() -> void:
	print("spatial hash: rebuild clears stale entries")
	var grid := SpatialHash.new(50.0)
	var a := PackedVector2Array([Vector2(10, 10), Vector2(20, 20)])
	grid.rebuild(a, 2)
	var b := PackedVector2Array([Vector2(500, 500)])
	grid.rebuild(b, 1)
	check(grid.cell(grid.key_of(Vector2(10, 10))).is_empty(), "old cell emptied after rebuild")
	check(grid.cell(grid.key_of(Vector2(500, 500))).size() == 1, "new position indexed")


func _test_hash_rebuild_no_accumulation() -> void:
	print("spatial hash: repeated rebuilds do not accumulate entries")
	var grid := SpatialHash.new(50.0)
	var pts := PackedVector2Array([Vector2(10, 10), Vector2(20, 20), Vector2(300, 300)])
	var stable := true
	for r in 5:
		grid.rebuild(pts, 3)
		if grid.total_entries() != 3:
			stable = false
	check(stable, "total entries stays == inserted count across 5 consecutive rebuilds")


func _test_sim_converges_on_target() -> void:
	print("horde sim: seeks target, stays finite")
	var sim := HordeSim.new(64)
	for k in 40:
		sim.spawn(Vector2(600, 0) + Vector2(randf() * 120.0 - 60.0, randf() * 120.0 - 60.0))
	var target := Vector2.ZERO
	var start_avg := _avg_dist(sim, target)
	for f in 300:
		sim.step(1.0 / 60.0, target)
	var finite := true
	for i in sim.active_count:
		if not sim.positions[i].is_finite():
			finite = false
	var end_avg := _avg_dist(sim, target)
	check(finite, "all positions finite after 300 steps")
	check(end_avg < start_avg * 0.5, "horde converged on target (avg dist %.0f -> %.0f)" % [start_avg, end_avg])


func _test_sim_survives_despawn_mid_run() -> void:
	print("horde sim: despawn mid-run keeps state consistent")
	var sim := HordeSim.new(128)
	for k in 100:
		sim.spawn(Vector2(randf() * 400.0 - 200.0, randf() * 400.0 - 200.0))
	for f in 60:
		sim.step(1.0 / 60.0, Vector2(200, 0))
		if f == 30:
			for d in 50:
				sim.despawn(randi_range(0, sim.active_count - 1))
	check(sim.active_count == 50, "count is 50 after 50 mid-run despawns")
	var finite := true
	for i in sim.active_count:
		if not sim.positions[i].is_finite():
			finite = false
	for f in 60:
		sim.step(1.0 / 60.0, Vector2(200, 0))
	for i in sim.active_count:
		if not sim.positions[i].is_finite():
			finite = false
	check(finite, "positions finite through despawn + 120 total steps")


func _avg_dist(sim: HordeSim, target: Vector2) -> float:
	var total := 0.0
	for i in sim.active_count:
		total += sim.positions[i].distance_to(target)
	return total / float(maxi(sim.active_count, 1))


func _test_sword_swing_cycles_forever() -> void:
	print("sword swing: never stops cycling (no cooldown gate)")
	var s := SwordSwing.new()
	s.start(0.0)
	var seen_active := 0
	var ever_idle := false
	for f in 3600:  # 60 sim-seconds at 60Hz
		s.advance(1.0 / 60.0)
		if s.phase == SwordSwing.Phase.ACTIVE:
			seen_active += 1
		if s.phase == SwordSwing.Phase.IDLE:
			ever_idle = true
	var cycles := float(s.swing_index)
	check(not ever_idle, "never enters IDLE across 3600 ticks")
	check(seen_active > 60, "active windows recur (%d active ticks across %.1f cycles)" % [seen_active, cycles])
	var expected := 3600.0 / 60.0 / (0.13 + 0.09 + 0.17)
	check(absf(cycles - expected) < expected * 0.05,
			"cycle rate matches 1/(windup+active+recovery) within 5%% (%.1f vs %.1f)" % [cycles, expected])


func _test_sword_swing_window() -> void:
	print("sword swing: hit window tracks the sweep")
	var s := SwordSwing.new()
	s.start(0.0)
	var guard := 0
	while s.phase != SwordSwing.Phase.ACTIVE and guard < 1000:
		s.advance(1.0 / 240.0)
		guard += 1
	check(s.phase == SwordSwing.Phase.ACTIVE, "reached ACTIVE")
	var lead := s.blade_angle()
	var behind := wrapf(lead - 0.2 * s.sweep_dir, -PI, PI)
	var ahead := wrapf(lead + 0.2 * s.sweep_dir, -PI, PI)
	check(s.in_hit_window(behind), "angle just behind blade edge is hittable")
	check(not s.in_hit_window(ahead), "angle ahead of blade edge is not hittable")


func _test_hash_circle_candidates_superset() -> void:
	print("spatial hash: circle_candidates covers brute force (radius > cell)")
	var grid := SpatialHash.new(48.0)
	var pts := PackedVector2Array()
	pts.resize(300)
	for i in 300:
		pts[i] = Vector2(randf() * 1200.0 - 600.0, randf() * 1200.0 - 600.0)
	grid.rebuild(pts, 300)
	var ok := true
	for trial in 20:
		var c := Vector2(randf() * 1000.0 - 500.0, randf() * 1000.0 - 500.0)
		var r := randf_range(30.0, 160.0)
		var cand := grid.circle_candidates(c, r)
		var in_cand := {}
		for j in cand:
			in_cand[j] = true
		for i in 300:
			if pts[i].distance_to(c) <= r and not in_cand.has(i):
				ok = false
	check(ok, "every brute-force hit appears in candidates (20 random queries, r up to 160 > cell 48)")


func _test_sim_damage_and_death() -> void:
	print("horde sim: damage, flash, knockback, death")
	var sim := HordeSim.new(16)
	var deaths := [0]
	sim.enemy_killed.connect(func(_at: Vector2) -> void: deaths[0] += 1)
	var idx := sim.spawn(Vector2.ZERO)
	var hp0: float = sim.healths[idx]
	var alive := sim.damage(idx, 10.0, Vector2.RIGHT)
	check(not alive, "sub-lethal hit does not kill")
	check(sim.healths[idx] == hp0 - 10.0, "health reduced by damage amount")
	check(sim.hit_flash[idx] == 1.0, "hit flash set on damage")
	check(sim.velocities[idx].x > 0.0, "knockback applied along hit direction")
	alive = sim.damage(idx, sim.max_health, Vector2.LEFT)
	check(alive, "lethal damage reports a kill")
	check(deaths[0] == 1, "enemy_killed emitted once (lambdas capture arrays by reference)")
	check(sim.active_count == 0, "dead enemy despawned")
	sim.damage(-5, 1.0, Vector2.ZERO)
	sim.damage(99, 1.0, Vector2.ZERO)
	check(sim.active_count == 0, "out-of-range damage is ignored")


func _make_upgrade(id: StringName, weight := 1.0, max_stacks := 0) -> SwordUpgradeDef:
	var d := SwordUpgradeDef.new()
	d.id = id
	d.display_name = String(id)
	d.description = "test"
	d.effect_id = id
	d.rarity_weight = weight
	d.max_stacks = max_stacks
	return d


func _test_upgrade_defs_load() -> void:
	print("content: .tres upgrade + wave defs load")
	var loader = load("res://autoload/content_loader.gd").new()
	loader.load_all()
	check(loader.sword_upgrades.size() >= 8, "at least 8 sword upgrade .tres files load (got %d)" % loader.sword_upgrades.size())
	check(loader.universal_abilities.size() >= 8, "at least 8 ability .tres files load (got %d)" % loader.universal_abilities.size())
	check(loader.waves.size() >= 10, "at least 10 wave .tres files load (got %d)" % loader.waves.size())
	var boss_wave: WaveDef = loader.waves[9]
	check(boss_wave.number == 10 and boss_wave.boss != null, "wave 10 references a boss")
	var boss_res = load("res://resources/bosses/wave10_boss.tres")
	check(boss_res != null and boss_res.max_health > 0.0 and boss_res.enrage_time > 0.0,
			"boss def loads with sane fields")
	var sane := true
	for w in loader.waves:
		if w.duration <= 0.0 or w.spawns_per_second <= 0.0:
			sane = false
	check(sane, "wave defs have sane duration/spawn rates")
	var sorted := true
	for k in range(1, loader.waves.size()):
		if loader.waves[k].number < loader.waves[k - 1].number:
			sorted = false
	check(sorted, "wave defs sorted by number")


func _test_roll_offers() -> void:
	print("choice offers: distinct, excludes maxed, degrades gracefully")
	var pool := [
		_make_upgrade(&"a"), _make_upgrade(&"b"), _make_upgrade(&"c"),
		_make_upgrade(&"d", 1.0, 1),
	]
	var offers := UpgradeEffects.roll_upgrade_offers(pool, {&"d": 1}, 3)
	check(offers.size() == 3, "3 offers from pool of 4 (one maxed)")
	var distinct := {}
	for o in offers:
		distinct[o.id] = true
	check(distinct.size() == offers.size(), "offers are distinct")
	var no_max := true
	for o in offers:
		if o.id == &"d":
			no_max = false
	check(no_max, "maxed upgrade never offered")
	var small := UpgradeEffects.roll_upgrade_offers([_make_upgrade(&"x"), _make_upgrade(&"y")], {}, 3)
	check(small.size() == 2, "pool smaller than count returns the whole pool")
	var ability_pool := [_make_ability(&"orb", "active", 1), _make_ability(&"slam", "active", 5)]
	var ability_offers := UpgradeEffects.roll_upgrade_offers(ability_pool, {&"orb": 1}, 3)
	var no_maxed_ability := true
	for o in ability_offers:
		if o.id == &"orb":
			no_maxed_ability = false
	check(ability_offers.size() == 1 and no_maxed_ability,
			"duck-typed roller excludes maxed abilities (max_rank field)")


func _test_wave_director() -> void:
	print("wave director: timing, clears, endless scaling")
	var w1 := WaveDef.new()
	w1.number = 1
	w1.duration = 1.0
	w1.spawns_per_second = 30.0
	w1.max_alive = 50
	var w2 := WaveDef.new()
	w2.number = 2
	w2.duration = 2.0
	w2.spawns_per_second = 5.0
	w2.max_alive = 50
	var d := WaveDirector.new()
	d.start([w1, w2])
	check(d.wave_number == 1 and d.current == w1, "starts on wave 1")
	var spawned := 0
	for f in 30:
		spawned += d.tick(1.0 / 30.0)
	check(spawned == 30, "spawn budget accumulates to rate * dt (30 spawns in 1s at 30/s)")
	for f in 5:
		d.tick(1.0 / 30.0)  # a tick or two past nominal: float64 drift means the
	check(d.is_cleared(), "wave 1 cleared when its timer elapses")  # crossing lands on the next frame
	d.advance()
	check(d.wave_number == 2 and d.current == w2, "advance moves to wave 2")
	check(not d.is_cleared(), "wave 2 not cleared immediately")
	for f in 61:
		d.tick(1.0 / 30.0)
	check(d.is_cleared(), "wave 2 clears after its own duration")
	d.advance()
	var w3: WaveDef = d.current
	check(d.wave_number == 3 and w3 != w2, "wave 3 scales beyond the authored defs")
	check(w3.spawns_per_second > w2.spawns_per_second and w3.health_scale > w2.health_scale,
			"scaled wave is denser and tougher")


func _test_combo_counter() -> void:
	print("combo counter: threshold burst, whiff reset")
	var c := ComboCounter.new()
	c.threshold = 15
	var bursted := false
	for k in 14:
		if c.register_hits(1):
			bursted = true
	check(not bursted and c.hits == 14, "14 hits below threshold: no burst")
	bursted = c.register_hits(1)
	check(bursted and c.hits == 0, "15th hit bursts and resets the count")
	for k in 10:
		c.register_hits(1)
	c.register_swing(0)
	check(c.hits == 0, "a whiff swing resets the count")
	var off := ComboCounter.new()
	check(not off.register_hits(5), "threshold 0 never bursts (no combo upgrade owned)")


func _test_spin_swing() -> void:
	print("sword swing: spin finisher every Nth sweep")
	var s := SwordSwing.new()
	s.spin_every = 4
	s.start(0.0)
	var ok := true
	for f in 2400:
		s.advance(1.0 / 60.0)
		if s.swing_just_started:
			var expected := s.swing_index % 4 == 0
			if s.is_spin_swing() != expected:
				ok = false
			if s.is_spin_swing() and not is_equal_approx(s.current_arc_half(), PI):
				ok = false
	check(ok, "every 4th swing spins (arc_half = PI), others keep the tuned arc")


func _test_upgrade_effects_apply() -> void:
	print("upgrade effects: apply mutates sword/sim state")
	var sword := Sword.new()
	var sim := HordeSim.new(16)
	var run := {"leech_on_kill": 0.0}
	var ctx := {"sword": sword, "sim": sim, "player": null, "run": run}
	var reach := _make_upgrade(&"reach_up")
	reach.magnitude = 25.0
	UpgradeEffects.apply(reach, ctx)
	check(sword.reach == 155.0 + 25.0, "reach_up adds reach")
	var heavy := _make_upgrade(&"heavy_blade")
	heavy.magnitude = 6.0
	UpgradeEffects.apply(heavy, ctx)
	check(sword.damage == 12.0 + 6.0, "heavy_blade adds damage")
	var swift := _make_upgrade(&"swift_strikes")
	swift.magnitude = 0.12
	UpgradeEffects.apply(swift, ctx)
	check(sword.swing.windup_time < 0.13 and sword.swing.recovery_time < 0.17,
			"swift_strikes shortens windup and recovery")
	var spin := _make_upgrade(&"spin_finisher")
	spin.magnitude = 4.0
	UpgradeEffects.apply(spin, ctx)
	check(sword.swing.spin_every == 4, "spin_finisher sets the spin cadence")
	var burst := _make_upgrade(&"combo_burst")
	burst.magnitude = 15.0
	UpgradeEffects.apply(burst, ctx)
	check(sword.combo.threshold == 15, "combo_burst sets the combo threshold")
	var mom := _make_upgrade(&"momentum")
	mom.magnitude = 0.5
	UpgradeEffects.apply(mom, ctx)
	check(sim.knockback_impulse > 240.0, "momentum scales knockback")
	var leech := _make_upgrade(&"leech")
	leech.magnitude = 2.0
	UpgradeEffects.apply(leech, ctx)
	check(run["leech_on_kill"] == 2.0, "leech registers on the run context")
	sword.free()


func _test_run_levels() -> void:
	print("run levels: xp curve is monotonic and round-trips")
	check(RunLevels.xp_needed(1) == 5, "level 1 needs 5 XP")
	var monotonic := true
	for l in range(1, 40):
		if RunLevels.xp_needed(l + 1) <= RunLevels.xp_needed(l):
			monotonic = false
	check(monotonic, "xp_needed strictly increasing across levels 1-40")
	var lvl := RunLevels.level_for_xp(float(RunLevels.xp_needed(1)))
	check(lvl == 2, "exactly enough XP for level 1 -> level 2")
	var total := 0.0
	for l in range(1, 6):
		total += RunLevels.xp_needed(l)
	check(RunLevels.level_for_xp(total) == 6, "cumulative XP lands exactly on level 6")


func _test_boss_brain() -> void:
	print("boss brain: HP phases and enrage multiplier")
	var brain := BossBrain.new(900.0, 75.0)
	check(brain.phase() == 1 and not brain.enraged, "starts phase 1, not enraged")
	brain.damage(300.0)  # 600/900 = 0.667 -> still phase 1
	check(brain.phase() == 1, "66.7% health is still phase 1")
	brain.damage(100.0)  # 500/900 = 0.556 -> phase 2
	check(brain.phase() == 2, "55.6% health is phase 2")
	var mult2 := brain.speed_mult()
	brain.damage(300.0)  # 200/900 -> phase 3
	check(brain.phase() == 3 and brain.speed_mult() > mult2, "phase 3 is faster than phase 2")
	var before := brain.speed_mult()
	brain.tick(74.0)
	check(not brain.enraged, "enrage not triggered before the timer")
	brain.tick(2.0)
	check(brain.enraged and brain.speed_mult() > before, "enrage triggers at the timer and speeds up")


func _make_ability(id: StringName, kind := "active", max_rank := 5, effect := &"") -> UniversalAbilityDef:
	var d := UniversalAbilityDef.new()
	d.id = id
	d.display_name = String(id)
	d.description = "test"
	d.kind = kind
	d.max_rank = max_rank
	d.cooldown = 3.0
	d.effect_id = effect if effect != &"" else id
	return d


func _test_ability_caster() -> void:
	print("ability caster: passives recompute, actives fire on cooldown")
	var sim := HordeSim.new(64)
	var player := Player.new()
	var run := {"xp_magnet_radius": 90.0, "xp_mult": 1.0}
	var boss_hits := []
	var caster := AbilityCaster.new()
	check(caster is Node2D, "caster is Node2D — child hazards inherit the player transform")
	caster.setup(sim, player, run, func(pos: Vector2, radius: float, amount: float, tag_mask: int) -> void:
		boss_hits.append(amount))
	var vitality := _make_ability(&"vitality", "passive", 3, &"vitality")
	caster.bring_online(vitality)
	check(player.max_hp == 120.0, "Vitality rank 1 raises max HP to 120")
	check(caster.rank_up(&"vitality"), "rank up succeeds below cap")
	check(player.max_hp == 140.0, "Vitality rank 2 raises max HP to 140")
	var boots := _make_ability(&"swift_boots", "passive", 3, &"swift_boots")
	caster.bring_online(boots)
	check(absf(player.move_speed - 324.0) < 0.01, "Swift Boots rank 1 sets 324 move speed")
	check(run["xp_mult"] == 1.0, "unrelated passive leaves xp_mult alone")
	# ground slam: spawn an enemy on top of the player, force the cooldown fire
	var slam := _make_ability(&"ground_slam", "active", 5, &"ground_slam")
	slam.cooldown = 2.0
	slam.magnitude = 18.0
	caster.bring_online(slam)
	var idx := sim.spawn(player.position + Vector2(20, 0))
	sim.step(1.0 / 60.0, Vector2(9999, 9999))  # rebuild the hash
	var hp_before: float = sim.healths[idx]
	caster.tick(1.1)  # first fire is at half cooldown (1.0s)
	check(sim.healths[idx] < hp_before, "ground slam damaged the enemy in range")
	check(caster.rank_of(&"ground_slam") == 1, "slam registered at rank 1")
	# max-rank cap respected
	var capped := _make_ability(&"capped_thing", "passive", 1, &"vitality")
	caster.bring_online(capped)
	check(not caster.rank_up(&"capped_thing"), "rank up refused at max_rank")
	player.free()


func _test_meta_progression() -> void:
	print("meta progression: rewards, save/load round-trip, corrupt fallback")
	var mp = load("res://autoload/meta_progression.gd").new()
	mp.save_path = "user://test_meta_save.json"
	var rewards: Dictionary = mp.record_run(10, 640, 1)
	check(rewards["hero_xp"] > 0.0 and rewards["glory"] > 0, "record_run returns positive rewards")
	check(mp.hero_level >= 2, "a wave-10 run levels the hero at least once")
	check(mp.best_wave == 10 and mp.total_runs == 1 and mp.total_kills == 640, "run stats tracked")
	var f := FileAccess.open(mp.save_path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	check("\"schema_version\": 2" in text, "save carries the current schema_version")
	var mp2 = load("res://autoload/meta_progression.gd").new()
	mp2.save_path = mp.save_path
	mp2.load_save()
	check(absf(mp2.hero_xp - mp.hero_xp) < 0.01 and mp2.glory == mp.glory and mp2.hero_level == mp.hero_level,
			"save/load round-trips hero state")
	f = FileAccess.open(mp.save_path, FileAccess.WRITE)
	f.store_string("not json at all{{{")
	f.close()
	mp2.load_save()
	check(mp2.hero_level == 1 and mp2.total_runs == 0, "corrupt save falls back to fresh defaults")
	f = FileAccess.open(mp.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema_version": 99, "hero_level": 7, "glory": 999}))
	f.close()
	mp2.load_save()
	check(mp2.glory == 0, "newer schema_version is not loaded (fresh start)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mp.save_path))


func _test_game_manager_scenes() -> void:
	print("game manager: every state's scene exists")
	var gm = load("res://autoload/game_manager.gd").new()
	var all_exist := true
	for s in gm.SCENES.values():
		if not FileAccess.file_exists(s):
			all_exist = false
	check(all_exist, "menu/run/summary/hub scenes all exist on disk")
	gm.free()


func _test_tags() -> void:
	print("tags: mask/has round-trip, bits within the enum")
	var m := Tags.mask([Tags.Tag.FIRE, Tags.Tag.SLASH, Tags.Tag.BURN])
	check(Tags.has(m, Tags.Tag.FIRE) and Tags.has(m, Tags.Tag.SLASH) and Tags.has(m, Tags.Tag.BURN),
			"mask preserves set tags")
	check(not Tags.has(m, Tags.Tag.FROST), "unset tag not present")
	check(m & ~Tags.ALL_MASK == 0, "mask fits within the enum's bits")


func _test_statuses() -> void:
	print("statuses: applied from hit tags, DoT kills, chill slows, decay clears")
	var sim := HordeSim.new(64)
	var deaths := [0]
	sim.enemy_killed.connect(func(_at: Vector2) -> void: deaths[0] += 1)
	var idx := sim.spawn(Vector2.ZERO)
	sim.damage(idx, 25.0, Vector2.ZERO, Tags.FIRE_BIT)  # 5 HP left; Burn deals 18 over 3s
	check(sim.status_mask[idx] & Tags.BURN_BIT != 0, "FIRE-tagged hit applies Burn")
	sim.damage(idx, 1.0, Vector2.ZERO, Tags.FROST_BIT)
	check(sim.status_mask[idx] & Tags.CHILL_BIT != 0, "FROST-tagged hit applies Chill")
	# burn DoT: 6 dps ticked at 0.5s intervals — 30 hp + burn takes ~3s
	var steps := 0
	while sim.active_count > 0 and steps < 600:
		sim.step(1.0 / 60.0, Vector2(9999, 9999))
		steps += 1
	check(sim.active_count == 0 and deaths[0] == 1, "Burn's damage-over-time killed the enemy")
	# chill slows seek speed
	var sim2 := HordeSim.new(16)
	var slow := sim2.spawn(Vector2(500, 0))
	sim2.damage(slow, 0.0, Vector2.ZERO, Tags.FROST_BIT)
	sim2.step(1.0 / 60.0, Vector2.ZERO)
	var d_chilled: float = sim2.positions[slow].length()
	var sim3 := HordeSim.new(16)
	var fast := sim3.spawn(Vector2(500, 0))
	sim3.step(1.0 / 60.0, Vector2.ZERO)
	var d_normal: float = sim3.positions[fast].length()
	check(d_chilled > d_normal, "chilled enemy moved less than unchilled")
	# decay: statuses expire after STATUS_DURATION
	var sim4 := HordeSim.new(16)
	var s := sim4.spawn(Vector2.ZERO)
	sim4.damage(s, 0.0, Vector2.ZERO, Tags.FIRE_BIT)
	for f in int(3.5 * 60.0):
		sim4.step(1.0 / 60.0, Vector2(9999, 9999))
	check(sim4.status_mask[s] == 0, "statuses decay to zero after the duration")


func _test_damage_mods() -> void:
	print("damage mods: increased per-tag additive, more multiplicative, capped")
	var sim := HordeSim.new(16)
	sim.add_increased(Tags.FIRE_BIT, 0.25)
	check(absf(sim.modified(100.0, Tags.FIRE_BIT) - 125.0) < 0.01, "increased adds +25% on matching tag")
	check(absf(sim.modified(100.0, Tags.FROST_BIT) - 100.0) < 0.01, "no effect on unmatched tags")
	var both := Tags.FIRE_BIT | Tags.FROST_BIT
	sim.add_increased(Tags.FROST_BIT, 0.5)
	check(absf(sim.modified(100.0, both) - 175.0) < 0.01, "multiple matched tags sum additively")
	check(sim.add_more(1.2), "first 'more' accepted")
	check(absf(sim.modified(100.0, both) - 210.0) < 0.01, "'more' multiplies after 'increased'")
	for k in 5:
		sim.add_more(1.1)
	check(sim.more_list.size() == 4, "'more' list capped at 4 sources")


func _test_tags_coverage() -> void:
	print("content: all def tags valid; Fire/Frost/Blood producers exist")
	var loader = load("res://autoload/content_loader.gd").new()
	loader.load_all()
	var all_valid := true
	var fire := 0
	var frost := 0
	var blood := 0
	var defs := []
	defs.append_array(loader.sword_upgrades)
	defs.append_array(loader.universal_abilities)
	for def in defs:
		if def.tags & ~Tags.ALL_MASK != 0:
			all_valid = false
		if def.tags & Tags.FIRE_BIT:
			fire += 1
		if def.tags & Tags.FROST_BIT:
			frost += 1
		if def.tags & Tags.BLOOD_BIT:
			blood += 1
	check(all_valid, "every def's tags fit within the enum")
	check(fire >= 1 and frost >= 1 and blood >= 1,
			"each implemented status element has a producer (Fire %d, Frost %d, Blood %d)" % [fire, frost, blood])
	# infusion application: picking Fire Infusion puts FIRE on the sword's hits
	var sword := Sword.new()
	var ctx := {"sword": sword, "sim": HordeSim.new(8), "player": null, "run": {"leech_on_kill": 0.0}}
	var infuse: SwordUpgradeDef = loader.sword_upgrades[0]
	for d in loader.sword_upgrades:
		if d.id == &"fire_infusion":
			infuse = d
	UpgradeEffects.apply(infuse, ctx)
	check(sword.hit_tag_mask & Tags.FIRE_BIT != 0, "Fire Infusion adds FIRE to the sword's hit mask")
	sword.free()


func _test_progression_curve() -> void:
	print("progression curve: AP key rows and roster unlocks")
	var loader = load("res://autoload/content_loader.gd").new()
	loader.load_all()
	check(loader.progression_curve != null, "curve resource loads from resources/progression")
	var curve: ProgressionCurve = loader.progression_curve
	check(curve.ap_for(1) == 5, "level 1 budget is 5 AP")
	check(curve.ap_for(10) == 14, "level 10 budget is 14 AP")
	check(curve.ap_for(20) == 24, "level 20 budget is 24 AP")
	check(curve.xp_needed(1) == 100, "level 1 needs 100 hero XP")
	check(curve.unlocks_at(1).size() == 2, "level 1 unlocks two abilities")
	check(curve.owned_through(10).size() == 5, "5 abilities owned at Hero Level 10")
	check(curve.owned_through(20).size() == 10, "10 abilities owned at Hero Level 20")
	check(curve.owned_through(22).size() == 11, "11 abilities owned at Hero Level 22")


func _test_loadout_rules() -> void:
	print("loadout rules: AP budget, slot cap, presets, default greedy fill")
	var loader = load("res://autoload/content_loader.gd").new()
	loader.load_all()
	var mp = load("res://autoload/meta_progression.gd").new()
	mp.save_path = "user://test_loadout_save.json"
	mp.curve = loader.progression_curve
	mp.ability_lookup = Callable(loader, "ability_by_id")
	mp.set_hero_level(10)  # budget 14, 5 owned
	mp.ensure_default_loadout()
	var equipped: Array = mp.equipped_ids()
	check(equipped.size() == 5, "default greedy loadout equips all 5 owned at L10 (AP fits)")
	var used := 0
	for id in equipped:
		used += mp._cost_of(id)
	check(used == 14, "the full L10 kit costs exactly the 14 AP budget")
	mp.set_hero_level(20)  # budget 24, 10 owned costing 26 — crunch must bite
	var kit: Array = mp.equipped_ids()
	var used20 := 0
	for id in kit:
		used20 += mp._cost_of(id)
	check(kit.size() == 9 and used20 <= 24, "L20 crunch: greedy fills 9 of 10 within the 24 AP budget")
	var err: String = mp.equip(&"vitality")  # already in default kit
	check(err == "already equipped", "double-equip refused")
	# unequip one (cost 2) then equip something that fits
	mp.unequip(&"scholars_wit")
	err = mp.equip(&"scholars_wit")
	check(err == "", "re-equip after unequip succeeds")
	mp.unequip(&"scholars_wit")
	# presets
	var before: Array = (mp.equipped_ids() as Array).duplicate()
	mp.save_slot_as(1)
	mp.select_slot(0)
	mp.unequip(&"orbit_blades")
	mp.select_slot(1)
	check(mp.equipped_ids() == before, "preset save/load round-trips the kit")
	# audio bus skeleton: voice cap + interval + finished frees a slot
	var ab = load("res://autoload/audio_bus.gd").new()
	ab.register_sound(&"test_sound", 2, 100000)
	var a: bool = ab.can_play(&"test_sound")
	ab.finished(&"test_sound")
	var b: bool = ab.can_play(&"test_sound")  # blocked by retrigger interval
	ab._last_played[&"test_sound"] = -1000000000
	var c: bool = ab.can_play(&"test_sound")
	ab.can_play(&"test_sound")
	var d: bool = ab.can_play(&"test_sound")  # voice cap = 2
	check(a and not b and c and not d, "voice limits + retrigger interval + finished() all enforced")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mp.save_path))
