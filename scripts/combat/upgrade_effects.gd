class_name UpgradeEffects
extends RefCounted

## effect_id -> application logic for Sword Upgrades. Phase 2 replaces
## per-effect code with the fully data-driven pipeline; until then, new
## effect MECHANISMS add a branch here while new CONTENT (.tres files
## reusing these ids) needs nothing.
##
## ctx = {"sword": Sword, "sim": HordeSim, "player": Player, "run": run scene}

static func apply(def: SwordUpgradeDef, ctx: Dictionary) -> void:
	var sword: Sword = ctx["sword"]
	var sim: HordeSim = ctx["sim"]
	var run = ctx["run"]
	match def.effect_id:
		&"reach_up":
			sword.reach += def.magnitude
		&"infuse":
			# elemental infusion: the sword's hits carry this def's tags, and
			# the pipeline turns FIRE/FROST/BLOOD into statuses — new elements
			# later are pure .tres with no code change
			sword.hit_tag_mask |= def.tags
		&"wide_arc":
			sword.swing.arc_half_angle = minf(sword.swing.arc_half_angle + def.magnitude, PI * 0.95)
		&"swift_strikes":
			var s := sword.swing
			s.windup_time = maxf(0.05, s.windup_time * (1.0 - def.magnitude))
			s.recovery_time = maxf(0.05, s.recovery_time * (1.0 - def.magnitude))
		&"heavy_blade":
			sword.damage += def.magnitude
		&"momentum":
			sim.knockback_impulse *= 1.0 + def.magnitude
		&"leech":
			run.leech_on_kill += def.magnitude
		&"spin_finisher":
			var swing := sword.swing
			swing.spin_every = int(def.magnitude) if swing.spin_every == 0 else maxi(2, swing.spin_every - 1)
		&"combo_burst":
			sword.combo.threshold = int(def.magnitude) if sword.combo.threshold == 0 else maxi(6, sword.combo.threshold - 3)
		_:
			push_warning("unknown upgrade effect_id: %s" % def.effect_id)


## Offer roller for the shared choice screen: distinct picks, weighted by
## rarity_weight, upgrades at max stacks excluded, fewer offers than requested
## when the eligible pool is small. Duck-typed on purpose: works for any def
## with id / rarity_weight / max_stacks OR max_rank (UniversalAbilityDef).
static func roll_upgrade_offers(pool: Array, taken: Dictionary, count := 3) -> Array:
	var weighted := []
	for def in pool:
		var stacks: int = taken.get(def.id, 0)
		var cap: int = def.max_stacks if "max_stacks" in def else def.max_rank
		if cap > 0 and stacks >= cap:
			continue
		var w := maxi(int(round(def.rarity_weight * 10.0)), 1)
		for k in w:
			weighted.append(def)
	var offers := []
	while offers.size() < count and weighted.size() > 0:
		var pick = weighted.pick_random()
		offers.append(pick)
		weighted = weighted.filter(func(d): return d != pick)
	return offers
