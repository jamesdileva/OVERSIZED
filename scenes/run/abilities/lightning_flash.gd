class_name LightningFlash
extends Node2D

## One-shot lightning visual: a bolt from off-screen top plus a ground flash,
## fading fast. Damage is applied by the caster before this spawns.

var life := 0.26

var _t := 0.0


func _process(dt: float) -> void:
	_t += dt
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	draw_line(Vector2(0.0, -560.0), Vector2.ZERO, Color(1.0, 1.0, 0.6, 1.0 - k), 10.0 * (1.0 - k) + 3.0)
	draw_circle(Vector2.ZERO, 34.0 * (1.0 - k) + 8.0, Color(1.0, 1.0, 0.75, 0.9 * (1.0 - k)))
