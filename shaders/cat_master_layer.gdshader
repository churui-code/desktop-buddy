shader_type canvas_item;

// A binary partition of the one master atlas. Complementary masks preserve
// its pixels at rest and never depend on AI-generated pose proportions.
uniform int layer = 0; // 0 body, 1 head (including ears), 2 tail
uniform vec4 head_cut = vec4(627.0, 250.0, 746.0, 18.0);
uniform vec4 tail_cut = vec4(810.0, 335.0, 850.0, 0.25);
uniform vec4 left_region = vec4(0.315, 0.335, 0.450, 0.480);
uniform vec4 right_region = vec4(0.545, 0.335, 0.675, 0.480);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float cut_y = head_cut.z + head_cut.w * clamp(1.0 - abs((pixel.x - head_cut.x) / head_cut.y), 0.0, 1.0);
	bool head = pixel.y < cut_y;
	float cut_x = tail_cut.y - tail_cut.w * clamp(pixel.y - tail_cut.z, 0.0, 225.0);
	bool tail = !head && pixel.y >= tail_cut.x && pixel.x < cut_x;
	bool keep = (layer == 1 && head) || (layer == 2 && tail) || (layer == 0 && !head && !tail);
	bool left_eye = all(greaterThanEqual(UV, left_region.xy)) && all(lessThan(UV, left_region.zw));
	bool right_eye = all(greaterThanEqual(UV, right_region.xy)) && all(lessThan(UV, right_region.zw));
	if (layer == 1 && (left_eye || right_eye)) {
		keep = false;
	}
	if (!keep) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * tint;
}
