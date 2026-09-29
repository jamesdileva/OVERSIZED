class_name CameraRig
extends Camera2D

## Player-follow camera with decaying trauma-based shake. Offset is scaled by
## trauma^2 so small hits barely move the frame and big kills slam it.

var trauma := 0.0

var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	_noise.frequency = 2.0
	make_current()


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(dt: float) -> void:
	trauma = maxf(0.0, trauma - 2.2 * dt)
	_t += dt * 60.0
	var s := trauma * trauma
	offset = Vector2(_noise.get_noise_2d(_t, 0.0), _noise.get_noise_2d(0.0, _t)) * 34.0 * s
