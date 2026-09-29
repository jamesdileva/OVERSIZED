class_name DamageNumbers
extends Node2D

## Pooled floating damage numbers in world space: rise, slow, fade. One pool
## reused for every hit — no per-hit allocation.

const POOL_SIZE := 48

var _labels: Array[Label] = []
var _life := PackedFloat32Array()
var _vel := PackedVector2Array()


func _ready() -> void:
	_life.resize(POOL_SIZE)
	_vel.resize(POOL_SIZE)
	for k in POOL_SIZE:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		l.add_theme_constant_override("outline_size", 4)
		l.z_index = 50
		add_child(l)
		_labels.append(l)


func pop(pos: Vector2, amount: float, killed := false) -> void:
	for k in POOL_SIZE:
		if _life[k] > 0.0:
			continue
		var l := _labels[k]
		l.text = str(int(amount))
		l.global_position = pos + Vector2(randf_range(-8.0, 8.0), -20.0)
		l.modulate.a = 1.0
		l.scale = Vector2.ONE * (1.35 if killed else 1.0)
		_life[k] = 0.65 if killed else 0.45
		_vel[k] = Vector2(randf_range(-14.0, 14.0), -85.0)
		return


func _process(dt: float) -> void:
	for k in POOL_SIZE:
		if _life[k] <= 0.0:
			continue
		_life[k] -= dt
		var l := _labels[k]
		l.global_position += _vel[k] * dt
		_vel[k].y += 60.0 * dt
		l.modulate.a = clampf(_life[k] / 0.3, 0.0, 1.0)
