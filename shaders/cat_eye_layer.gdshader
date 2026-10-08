shader_type canvas_item;

uniform sampler2D half_eyes : source_color, filter_linear, repeat_disable;
uniform sampler2D closed_eyes : source_color, filter_linear, repeat_disable;
uniform float closure = 0.0;
uniform vec4 left_region = vec4(0.315, 0.335, 0.450, 0.480);
uniform vec4 right_region = vec4(0.545, 0.335, 0.675, 0.480);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float patch_mask(vec2 uv, vec4 region) {
	vec2 enter = smoothstep(region.xy, region.xy + vec2(0.008), uv);
	vec2 leave = vec2(1.0) - smoothstep(region.zw - vec2(0.008), region.zw, uv);
	return enter.x * enter.y * leave.x * leave.y;
}

void fragment() {
	bool left = all(greaterThanEqual(UV, left_region.xy)) && all(lessThan(UV, left_region.zw));
	bool right = all(greaterThanEqual(UV, right_region.xy)) && all(lessThan(UV, right_region.zw));
	if (!(left || right)) {
		discard;
	}
	vec4 open = texture(TEXTURE, UV);
	vec4 half = texture(half_eyes, UV);
	vec4 closed = texture(closed_eyes, UV);
	vec4 eye = closure <= 0.5 ? mix(open, half, closure * 2.0) : mix(half, closed, (closure - 0.5) * 2.0);
	float mask = max(patch_mask(UV, left_region), patch_mask(UV, right_region));
	// The matching rectangular holes in the head make this a separate part.
	// Feather only the expression colors; preserve the master's alpha exactly.
	COLOR = vec4(mix(open.rgb, eye.rgb, mask), open.a) * tint;
}
