shader_type canvas_item;

// One mesh changes geometry; each endpoint samples its unchanged source atlas.
uniform sampler2D held_texture : filter_linear;
uniform vec2 regions[60];
uniform vec2 joints[7];
uniform vec2 seated_regions[60];
uniform float angles[6];
uniform float posture = 0.0;
uniform float idle_tail = 0.0;
uniform bool tail_only = false;
uniform vec4 head_cut = vec4(627.0, 250.0, 746.0, 18.0);
uniform vec4 tail_cut = vec4(810.0, 335.0, 850.0, 0.25);
varying vec4 tint;
varying vec2 held_uv;

float part_distance(vec2 p, int part) {
	bool inside = false;
	float nearest_distance = 100000.0;
	int previous = 11;
	for (int i = 0; i < 12; i++) {
		vec2 a = regions[part * 12 + i];
		vec2 b = regions[part * 12 + previous];
		vec2 edge = b - a;
		vec2 nearest = a + edge * clamp(dot(p - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
		nearest_distance = min(nearest_distance, length(p - nearest));
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) { inside = !inside; }
		}
		previous = i;
	}
	return inside ? nearest_distance : -nearest_distance;
}

float seated_distance(vec2 p, int part) {
	bool inside = false;
	float nearest_distance = 100000.0;
	int previous = 11;
	for (int i = 0; i < 12; i++) {
		vec2 a = seated_regions[part * 12 + i];
		vec2 b = seated_regions[part * 12 + previous];
		vec2 edge = b - a;
		vec2 nearest = a + edge * clamp(dot(p - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
		nearest_distance = min(nearest_distance, length(p - nearest));
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) { inside = !inside; }
		}
		previous = i;
	}
	return inside ? nearest_distance : -nearest_distance;
}

vec2 seated_joint(int bone) {
	if (bone == 1) { return vec2(525.0, 860.0); }
	if (bone == 2) { return vec2(735.0, 860.0); }
	if (bone == 3) { return vec2(390.0, 950.0); }
	return vec2(865.0, 950.0);
}

vec2 corresponding_bone(vec2 p, int bone) {
	vec2 target = vec2(565.0, 655.0);
	if (bone == 2) { target = vec2(760.0, 674.0); }
	if (bone == 3) { target = vec2(530.0, 942.0); }
	if (bone == 4) { target = vec2(800.0, 955.0); }
	return target + (p - seated_joint(bone)) * (bone < 3 ? vec2(0.78, 0.85) : vec2(0.65, 1.10));
}

mat2 rotation_matrix(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, s), vec2(-s, c));
}

vec2 bone_offset(vec2 p, int bone) {
	return joints[bone] + rotation_matrix(angles[bone]) * (p - joints[bone]) - p;
}

void vertex() {
	tint = COLOR;
	vec2 seated = VERTEX;
	vec2 held = vec2(627.0 + (seated.x - 627.0) * 0.74, 600.0 + (seated.y - 752.0) * 1.35);
	vec2 offset = vec2(0.0);
	if (tail_only) {
		// Keep the original seated tail intact. It has its own mesh and pivot.
		held = joints[5] + rotation_matrix(-2.8) * (seated - vec2(280.0, 1080.0));
		seated = vec2(280.0, 1080.0) + rotation_matrix(idle_tail) * (seated - vec2(280.0, 1080.0));
		offset = bone_offset(held, 5);
	} else {
		vec2 correspondence = vec2(0.0);
		float correspondence_weight = 0.0;
		for (int bone = 1; bone < 5; bone++) {
			float coverage = smoothstep(-65.0, 65.0, seated_distance(seated, bone - 1));
			float root_weight = smoothstep(-40.0, 130.0, seated.y - seated_joint(bone).y);
			float weight = coverage * root_weight;
			correspondence += (corresponding_bone(seated, bone) - held) * weight;
			correspondence_weight += weight;
		}
		held += correspondence / max(correspondence_weight, 1.0) * 0.55;
		float total = 0.0;
		for (int bone = 1; bone < 6; bone++) {
			float coverage = smoothstep(-85.0, 100.0, part_distance(held, bone - 1));
			float root_weight = bone == 5 ? smoothstep(0.0, 110.0, length(held - joints[bone])) : smoothstep(-35.0, 110.0, held.y - joints[bone].y);
			float weight = coverage * root_weight;
			offset += bone_offset(held, bone) * weight;
			total += weight;
		}
		offset /= max(total, 1.0);
		float side = smoothstep(570.0, 730.0, held.x);
		vec2 hips = mix(bone_offset(held, 3), bone_offset(held, 4), side);
		float pelvis = smoothstep(870.0, 1030.0, held.y) * (1.0 - smoothstep(0.25, 0.80, total));
		offset = mix(offset, hips, pelvis);
	}
	held_uv = held / 1254.0;
	VERTEX = mix(seated, held + offset, posture);
}

void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	float cut_y = head_cut.z + head_cut.w * clamp(1.0 - abs((p.x - head_cut.x) / head_cut.y), 0.0, 1.0);
	float cut_x = tail_cut.y - tail_cut.w * clamp(p.y - tail_cut.z, 0.0, 225.0);
	bool seated_tail = p.y >= tail_cut.x && p.x < cut_x;
	vec4 seated = texture(TEXTURE, UV);
	if (p.y < cut_y || seated_tail != tail_only) { seated = vec4(0.0); }

	vec2 h = held_uv * 1254.0;
	float tail_ownership = part_distance(h, 4);
	// The leg masks cover the root of the hanging tail.
	for (int part = 0; part < 4; part++) {
		tail_ownership = min(tail_ownership, -part_distance(h, part));
	}
	vec4 held = texture(held_texture, held_uv);
	// A subpixel overlap prevents cracks caused by two UV interpolators
	// rounding opposite ways at the shared tail root.
	bool keep_held = tail_only ? tail_ownership >= -0.05 : tail_ownership <= 0.05;
	if (h.y < 576.0 + (h.x - 450.0) * 0.052 || !keep_held
		|| any(lessThan(held_uv, vec2(0.0))) || any(greaterThan(held_uv, vec2(1.0)))) { held = vec4(0.0); }

	// Change surface colors in corresponding coordinates, with no whole-cat
	// opacity tween. Keep covered skin solid through the middle of the move.
	float alpha = mix(seated.a, held.a, posture);
	vec3 rgb = mix(seated.rgb * seated.a, held.rgb * held.a, posture) / max(alpha, 0.00001);
	float skin_coverage = smoothstep(0.0, 0.08, posture) * (1.0 - smoothstep(0.92, 1.0, posture));
	alpha = mix(alpha, smoothstep(0.0, 0.15, alpha), skin_coverage);
	COLOR = vec4(rgb, alpha) * tint;
	if (COLOR.a < 0.008) { discard; }
}
