class_name ComboCounter
extends RefCounted

## Consecutive-landed-hits counter (architecture.md §5.1 combo archetype).
## The sword feeds landed hits per frame; a full swing that hits nothing
## resets the count, so keeping the blade in meat is what builds it.
## register_hits returns true exactly when the threshold releases a burst.
## threshold 0 = no combo effects owned.

var threshold := 0
var hits := 0


func register_hits(n: int) -> bool:
	if threshold <= 0:
		return false
	hits += n
	if hits >= threshold:
		hits = 0
		return true
	return false


func register_swing(hits_landed: int) -> void:
	if hits_landed == 0:
		hits = 0
