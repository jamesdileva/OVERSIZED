extends SceneTree

## Headless test runner for the horde-spike logic (no scene, no autoloads):
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 on pass, 1 on any failure. Deterministic (fixed seed).

var failures := 0


func _initialize() -> void:
	seed(20260928)
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
