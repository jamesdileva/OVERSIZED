class_name PlaceholderTex
extends RefCounted

## Generated placeholder textures so the prototype ships with zero art assets.
## Replaced wholesale when real art lands (Phase 3 juice pass).


static func circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) * 0.5
	var radius := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var edge := radius - Vector2(x - center, y - center).length()
			var a := clampf(edge / 1.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a * color.a))
	return ImageTexture.create_from_image(img)
