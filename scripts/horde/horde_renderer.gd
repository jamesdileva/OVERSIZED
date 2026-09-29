class_name HordeRenderer
extends Node2D

## Presentation layer for HordeSim (implementation-guide.md §6.4): a single
## MultiMeshInstance2D whose instance transforms are pushed from the sim's
## flat position array every frame. Knows nothing about enemy logic; the sim
## knows nothing about rendering. Hit flash is a per-instance color lerp
## driven by the sim's flash timers.

var _sim: HordeSim
var _multimesh: MultiMesh

var _dot_color := Color(0.9, 0.3, 0.22)
var _flash_color := Color(1.0, 0.95, 0.85)


func setup(sim: HordeSim, dot_diameter := 14.0, tint := Color(0.9, 0.3, 0.22)) -> void:
	_sim = sim
	_dot_color = tint
	var quad := QuadMesh.new()
	quad.size = Vector2(dot_diameter, dot_diameter)
	_multimesh = MultiMesh.new()
	# transform_format (and use_colors) must be set before instance_count
	# allocates the buffer.
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = sim.capacity
	_multimesh.visible_instance_count = 0
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = _multimesh
	mmi.texture = _make_dot_texture(int(dot_diameter))
	add_child(mmi)


func _process(_delta: float) -> void:
	if _sim == null or _multimesh == null:
		return
	var n := _sim.active_count
	var positions := _sim.positions
	var flashes := _sim.hit_flash
	for i in n:
		_multimesh.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
		var f := flashes[i]
		if f > 0.0:
			_multimesh.set_instance_color(i, _dot_color.lerp(_flash_color, f))
		else:
			_multimesh.set_instance_color(i, _dot_color)
	_multimesh.visible_instance_count = n


static func _make_dot_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) * 0.5
	for y in size:
		for x in size:
			var edge := size * 0.5 - Vector2(x - center, y - center).length()
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(edge / 1.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
