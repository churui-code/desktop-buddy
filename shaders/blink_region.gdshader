shader_type canvas_item;

// Keep the master character pixels outside the two eye regions unchanged.
// The driver bypasses this material while playing full-head petting frames.
uniform sampler2D idle_texture : source_color, filter_linear, repeat_disable;
uniform vec4 left_eye_region = vec4(0.315, 0.335, 0.450, 0.480);
uniform vec4 right_eye_region = vec4(0.545, 0.335, 0.675, 0.480);
uniform float feather = 0.01;

varying vec4 tint;

float region_mask(vec2 uv, vec4 region) {
	vec2 enter = smoothstep(region.xy, region.xy + vec2(feather), uv);
	vec2 leave = vec2(1.0) - smoothstep(region.zw - vec2(feather), region.zw, uv);
	return enter.x * enter.y * leave.x * leave.y;
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	float mask = max(region_mask(UV, left_eye_region), region_mask(UV, right_eye_region));
	COLOR = mix(texture(idle_texture, UV), texture(TEXTURE, UV), mask) * tint;
}
