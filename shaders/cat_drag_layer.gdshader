shader_type canvas_item;

// Partition one unchanged pose into seven layers in source-pixel space.
uniform int layer = 0;
uniform vec2 regions[60]; // five polygons, twelve vertices each
varying vec4 tint;
void vertex() { tint = COLOR; }

bool inside_part(vec2 p, int part) {
	bool inside = false;
	int previous = 11;
	for (int i = 0; i < 12; i++) {
		vec2 a = regions[part * 12 + i];
		vec2 b = regions[part * 12 + previous];
		if ((a.y > p.y) != (b.y > p.y)) {
			float crossing = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
			if (p.x < crossing) { inside = !inside; }
		}
		previous = i;
	}
	return inside;
}

void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	int owner = 0;
	for (int i = 0; i < 5; i++) {
		if (inside_part(p, i)) { owner = i + 1; }
	}
	if (p.y < 576.0 + (p.x - 450.0) * 0.052) { owner = 6; }
	if (owner != layer) { discard; }
	COLOR = texture(TEXTURE, UV) * tint;
}
