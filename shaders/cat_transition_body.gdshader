shader_type canvas_item;

uniform float neck_cut = 730.0;

void fragment() {
	// An overlap beneath the original head keeps the collar connected.
	COLOR.a *= smoothstep(neck_cut - 2.0, neck_cut + 2.0, UV.y / TEXTURE_PIXEL_SIZE.y);
}
