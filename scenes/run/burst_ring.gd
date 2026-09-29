class_name BurstRing
extends Node2D

## One-shot expanding ring for AoE bursts (combo burst now, ability slams
## later). Frees itself; cheap enough to spawn per burst.

var radius := 200.0
var life := 0.3

var _t := 0.0


func _process(dt: float) -> void:
	_t += dt
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	draw_arc(
		Vector2.ZERO, radius * (0.25 + 0.75 * k), 0.0, TAU, 48,
		Color(1.0, 0.85, 0.5, 1.0 - k), 10.0 * (1.0 - k) + 2.0)
