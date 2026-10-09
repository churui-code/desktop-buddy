shader_type canvas_item;
uniform vec2 regions[60];
uniform vec2 joints[7];
uniform float angles[6];
uniform float fold = 0.0;
uniform float posture = 1.0;
uniform bool body_only = false;
uniform float idle_tail = 0.0;
varying vec4 tint;

float part_distance(vec2 p, int part) {
	bool inside = false;
	float distance_to_edge = 100000.0;
	int previous = 11;
	for (int i = 0; i < 12; i++) {
		vec2 a = regions[part * 12 + i];
		vec2 b = regions[part * 12 + previous];
		vec2 edge = b - a;
		vec2 nearest = a + edge * clamp(dot(p - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
		distance_to_edge = min(distance_to_edge, length(p - nearest));
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) { inside = !inside; }
		}
		previous = i;
	}
	return inside ? distance_to_edge : -distance_to_edge;
}

vec2 bone_offset(vec2 p, int bone) {
	vec2 q = p - joints[bone];
	if (bone < 5) { q.y *= 1.0 - fold * 0.28; }
	float c = cos(angles[bone]);
	float s = sin(angles[bone]);
	return joints[bone] + mat2(vec2(c, s), vec2(-s, c)) * q - p;
}

vec2 seated_bone(vec2 p, int bone) {
	vec2 q = p - joints[bone];
	if (bone == 1) { return vec2(470.0, 810.0) + q * vec2(0.78, 1.34); }
	if (bone == 2) { return vec2(720.0, 825.0) + q * vec2(0.78, 1.20); }
	if (bone == 3) { return vec2(440.0, 1000.0) + q * vec2(0.80, 0.72); }
	if (bone == 4) { return vec2(825.0, 1005.0) + q * vec2(0.80, 0.72); }
	float c = cos(1.55 + idle_tail);
	float s = sin(1.55 + idle_tail);
	q *= vec2(1.0, 0.72);
	return vec2(320.0, 1000.0) + mat2(vec2(c, s), vec2(-s, c)) * q;
}

void vertex() {
	tint = COLOR;
	vec2 p = VERTEX;
	vec2 offset = vec2(0.0);
	vec2 seated_torso = vec2(627.0 + (p.x - 627.0) * 1.44, 760.0 + (p.y - 610.0) * 0.73);
	vec2 seated_offset = vec2(0.0);
	float total_weight = 0.0;
	for (int bone = 1; bone < 6; bone++) {
		// Soft boundaries avoid folding triangles at a rigid cut line.
		float coverage = smoothstep(-85.0, 100.0, part_distance(p, bone - 1));
		float root_weight = bone == 5 ? smoothstep(0.0, 110.0, length(p - joints[bone])) : smoothstep(-35.0, 110.0, p.y - joints[bone].y);
		float weight = coverage * root_weight;
		offset += bone_offset(p, bone) * weight;
		seated_offset += (seated_bone(p, bone) - seated_torso) * weight;
		total_weight += weight;
	}
	offset /= max(total_weight, 1.0);
	seated_offset /= max(total_weight, 1.0);
	// Pelvic skin blends into the thighs; there is no separate lower patch.
	float side = smoothstep(570.0, 730.0, p.x);
	vec2 hips = mix(bone_offset(p, 3), bone_offset(p, 4), side);
	float pelvis_weight = smoothstep(870.0, 1030.0, p.y) * (1.0 - smoothstep(0.25, 0.80, total_weight));
	offset = mix(offset, hips, pelvis_weight);
	vec2 seated = seated_torso + seated_offset;
	// One opaque skin moves continuously between its endpoint geometries.
	VERTEX = mix(seated, p + offset, posture);
}

void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	if (body_only && p.y < 576.0 + (p.x - 450.0) * 0.052) { discard; }
	COLOR = texture(TEXTURE, UV) * tint;
	// Suppress isolated sub-byte alpha specks amplified by mesh interpolation.
	if (COLOR.a < 0.008) { discard; }
}
