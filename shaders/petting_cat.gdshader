shader_type canvas_item;

uniform sampler2D idle_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D relaxed_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D next_pose_texture : source_color, filter_linear, repeat_disable;
uniform float frame_blend = 0.0;
uniform float petting_amount = 0.0;
// Reduce the generated keyframe's tilt to a gentle movement.
uniform float pose_strength = 0.45;
varying vec4 tint;

vec4 alpha_blend(vec4 a, vec4 b, float weight) {
	float alpha = mix(a.a, b.a, weight);
	vec3 premultiplied = mix(a.rgb * a.a, b.rgb * b.a, weight);
	return vec4(premultiplied / max(alpha, 0.00001), alpha);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 idle = texture(idle_texture, UV);
	vec4 relaxed = texture(relaxed_texture, UV);
	vec4 pose = alpha_blend(texture(TEXTURE, UV), texture(next_pose_texture, UV), frame_blend);
	vec4 petting = alpha_blend(relaxed, pose, pose_strength);
	// Keep the original body and paw pixels throughout the head animation.
	float head = 1.0 - smoothstep(0.59, 0.65, UV.y);
	COLOR = alpha_blend(idle, petting, head * petting_amount) * tint;
}
