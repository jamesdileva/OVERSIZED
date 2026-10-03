shader_type canvas_item;

// Enemy animation via MultiMesh custom data (implementation-guide §16.3):
// INSTANCE_CUSTOM.x = per-slot phase (stable, set once), .y = animation
// rate. When sprites land, the same custom data drives frame selection
// instead of a bob — the pipeline is what this proves.

void vertex() {
	VERTEX.y += sin(INSTANCE_CUSTOM.x * 6.2831 + TIME * 6.0 * INSTANCE_CUSTOM.y) * 1.5 * INSTANCE_CUSTOM.y;
}
