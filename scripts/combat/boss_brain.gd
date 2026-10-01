class_name BossBrain
extends RefCounted

## Pure boss decision state (implementation-guide.md §8's discipline:
## telegraph-then-execute with readable phases). The Boss node owns movement
## and attacks; this owns HP phases (66%/33%), the enrage soft timer, and the
## speed/interval multipliers they produce. Testable headless.

var max_health: float
var health: float
var enrage_after: float
var elapsed := 0.0
var enraged := false


func _init(p_max_health: float, p_enrage_after: float) -> void:
	max_health = p_max_health
	health = p_max_health
	enrage_after = p_enrage_after


func tick(dt: float) -> void:
	elapsed += dt
	if not enraged and elapsed >= enrage_after:
		enraged = true


func damage(amount: float) -> void:
	health = maxf(0.0, health - amount)


func health_fraction() -> float:
	return health / max_health if max_health > 0.0 else 0.0


func phase() -> int:
	var f := health_fraction()
	if f > 0.66:
		return 1
	if f > 0.33:
		return 2
	return 3


func speed_mult() -> float:
	return (1.0 + 0.18 * float(phase() - 1)) * (1.6 if enraged else 1.0)
