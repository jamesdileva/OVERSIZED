import io

p = 'scenes/run/run.gd'
s = io.open(p, encoding='utf-8').read()

# 1. reaction handler rewrite (contagion/overload + SFX)
old = '''		&"steam_burst":
			group.circle_damage(pos, radius, amount, Tags.FIRE_BIT, 0.2, 1)
			_spawn_ring(pos, radius, Tags.color_for(Tags.Tag.BURN))
			camera.add_trauma(0.15)
		&"blood_boil":
			group.circle_damage(pos, radius, amount, Tags.FIRE_BIT, 1.0, 1)
			_spawn_ring(pos, radius, Tags.color_for(Tags.Tag.BLEED))
			camera.add_trauma(0.3)
			_hit_stop()
		&"shatter":
			numbers.pop(pos, amount, true)
			camera.add_trauma(0.12)'''
new = '''		&"steam_burst":
			group.circle_damage(pos, radius, amount, Tags.FIRE_BIT, 0.2, 1)
			_spawn_ring(pos, radius, Tags.color_for(Tags.Tag.BURN))
			camera.add_trauma(0.15)
			AudioBus.play_sfx(&"reaction_steam")
		&"blood_boil":
			group.circle_damage(pos, radius, amount, Tags.FIRE_BIT, 1.0, 1)
			_spawn_ring(pos, radius, Tags.color_for(Tags.Tag.BLEED))
			camera.add_trauma(0.3)
			AudioBus.play_sfx(&"reaction_boil")
			_hit_stop()
		&"shatter":
			numbers.pop(pos, amount, true)
			camera.add_trauma(0.12)
		&"contagion":
			# Poison spreads to nearby enemies (0-damage application)
			group.circle_damage(pos, radius, 0.0, (1 << Tags.Tag.POISON_BIT), 0.0, 1)
			_spawn_ring(pos, radius, Tags.color_for(Tags.Tag.POISON))
		&"overload":
			# chain-arc: the 2 nearest enemies to the hit take proc damage
			var struck := []
			for h2 in group.hordes:
				var s2: HordeSim = h2["sim"]
				for i2 in s2.grid.circle_candidates(pos, 300.0):
					if i2 >= s2.active_count:
						continue
					var dd: float = s2.positions[i2].distance_to(pos)
					struck.append({"sim": s2, "i": i2, "d": dd})
			struck.sort_custom(func(a, b): return a["d"] < b["d"])
			var chained := 0
			for v in struck:
				if chained >= 2:
					break
				if v["sim"].active_count > v["i"]:
					v["sim"].damage(v["i"], amount, Vector2.ZERO, (1 << Tags.Tag.SHOCK_BIT), 1)
					chained += 1
			camera.add_trauma(0.1)'''
assert old in s, 'reaction handler not found'
s = s.replace(old, new, 1)

# 2. boss music + roar in _spawn_boss + slam sfx in its lambda
old = '''	boss = Boss.new()
	boss.setup(director.current.boss, player)
	boss.died.connect(_on_boss_died)
	boss.slammed.connect(func(pos: Vector2, radius: float) -> void:
		var ring := BurstRing.new()
		ring.position = pos
		ring.radius = radius
		ring.life = 0.25
		add_child(ring)
		camera.add_trauma(0.3))
	add_child(boss)'''
new = '''	boss = Boss.new()
	boss.setup(director.current.boss, player)
	boss.died.connect(_on_boss_died)
	boss.slammed.connect(func(pos: Vector2, radius: float) -> void:
		var ring := BurstRing.new()
		ring.position = pos
		ring.radius = radius
		ring.life = 0.25
		add_child(ring)
		camera.add_trauma(0.3)
		AudioBus.play_sfx(&"boss_slam"))
	AudioBus.play_music(&"boss", "res://assets/audio/music/boss_loop.wav")
	AudioBus.play_sfx(&"boss_roar")
	add_child(boss)'''
assert old in s, 'spawn boss not found'
s = s.replace(old, new, 1)

# 3. champion scaling in _start_wave + _spawn_champion
old = '''func _start_wave() -> void:
	EventBus.wave_started.emit(director.wave_number)
	if director.current.boss != null and boss == null:
		_spawn_boss()'''
new = '''func _start_wave() -> void:
	EventBus.wave_started.emit(director.wave_number)
	if director.current.boss != null and boss == null:
		_spawn_boss()
	elif director.wave_number > 40 and director.wave_number % 10 == 0 and boss == null:
		_spawn_champion(director.wave_number)   # champion-modifier scaling beyond the roster


## Champion-modifier scaling live (architecture.md §9): every 10th wave past
## the hand-authored roster returns the wave-40 boss with stacked slots.
func _spawn_champion(w: int) -> void:
	var base: BossDef = load("res://resources/bosses/wave40_boss.tres")
	var bdef: BossDef = base.duplicate()
	bdef.champion_modifier_slots = mini(int((w - 40) / 10.0) + 1, 5)
	boss = Boss.new()
	boss.setup(bdef, player)
	boss.died.connect(_on_boss_died)
	boss.slammed.connect(func(pos: Vector2, radius: float) -> void:
		_spawn_ring(pos, radius, Color(1.0, 0.2, 0.55))
		camera.add_trauma(0.3)
		AudioBus.play_sfx(&"boss_slam"))
	AudioBus.play_music(&"boss", "res://assets/audio/music/boss_loop.wav")
	AudioBus.play_sfx(&"boss_roar")
	add_child(boss)'''
assert old in s, 'start wave not found'
s = s.replace(old, new, 1)

# 4. evolve sfx
old = '''			camera.add_trauma(0.5)
			_spawn_ring(player.position, 240.0, Tags.color_for(Tags.Tag.FIRE))'''
new = '''			camera.add_trauma(0.5)
			AudioBus.play_sfx(&"evolve")
			_spawn_ring(player.position, 240.0, Tags.color_for(Tags.Tag.FIRE))'''
assert old in s, 'evolve sfx not found'
s = s.replace(old, new, 1)

# 5. xp pickup sfx
old = '''func _on_xp_collected(amount: float) -> void:
	xp += amount'''
new = '''func _on_xp_collected(amount: float) -> void:
	if amount > 0.0:
		AudioBus.play_sfx(&"xp_pickup", 0.12)
	xp += amount'''
assert old in s, 'xp sfx not found'
s = s.replace(old, new, 1)

# 6. wave-clear sfx
old = '''	EventBus.wave_cleared.emit(director.wave_number)
	var offers := UpgradeEffects.roll_upgrade_offers('''
new = '''	EventBus.wave_cleared.emit(director.wave_number)
	AudioBus.play_sfx(&"wave_clear")
	var offers := UpgradeEffects.roll_upgrade_offers('''
assert old in s, 'clear sfx not found'
s = s.replace(old, new, 1)

# 7. level-up sfx
old = '''	if leveled:
		if choice_screen.visible:'''
new = '''	if leveled:
		AudioBus.play_sfx(&"level_up")
		if choice_screen.visible:'''
assert old in s, 'level sfx not found'
s = s.replace(old, new, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('patched run: reactions/champion/music/sfx')
