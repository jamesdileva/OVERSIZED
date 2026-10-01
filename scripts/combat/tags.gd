class_name Tags
extends RefCounted

## The shared tag vocabulary (architecture.md §5.4): one enum for elements,
## delivery, statuses, and behaviors; sets packed into a bitmask so "does
## this hit carry Fire?" is a single AND — cheap enough for every hit in a
## horde game. Sword Upgrades and Universal Abilities share this vocabulary;
## that shared language is what lets the two build tracks talk.

enum Tag {
	FIRE, FROST, SHOCK, POISON, BLOOD,
	SLASH, ORBIT, BURST, PROJECTILE, SUMMON, ZONE,
	BURN, CHILL, SHOCKED, POISONED, BLEED, STUN,
	ON_HIT, ON_KILL, PERIODIC, CRIT, LIFESTEAL, KNOCKBACK, EXECUTE,
}

const ALL_MASK := (1 << 24) - 1   # enum is contiguous bits 0..23

# element/status bits, precomputed for hot paths
const FIRE_BIT := 1 << Tag.FIRE
const FROST_BIT := 1 << Tag.FROST
const BLOOD_BIT := 1 << Tag.BLOOD
const SLASH_BIT := 1 << Tag.SLASH
const BURN_BIT := 1 << Tag.BURN
const CHILL_BIT := 1 << Tag.CHILL
const BLEED_BIT := 1 << Tag.BLEED

# tag→color language (implementation-guide.md §16.3): players learn to read
# a build from the screen. Hostile-hue (red-magenta) is reserved for enemy
# effects and never used here.
const COLORS := {
	Tag.FIRE: Color(1.0, 0.55, 0.15),
	Tag.FROST: Color(0.45, 0.85, 1.0),
	Tag.SHOCK: Color(1.0, 0.95, 0.3),
	Tag.POISON: Color(0.45, 0.9, 0.35),
	Tag.BLOOD: Color(0.7, 0.12, 0.22),
	Tag.BURN: Color(1.0, 0.45, 0.1),
	Tag.CHILL: Color(0.55, 0.9, 1.0),
	Tag.BLEED: Color(0.85, 0.15, 0.2),
}


static func mask(tags: Array) -> int:
	var m := 0
	for t in tags:
		m |= (1 << t)
	return m


static func has(m: int, t: int) -> bool:
	return (m & (1 << t)) != 0


static func color_for(tag: int) -> Color:
	return COLORS.get(tag, Color.WHITE)
