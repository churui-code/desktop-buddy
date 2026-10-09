shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	if (pixel.y < 580.0 || pixel.y > 1025.0) { discard; }
	COLOR = texture(TEXTURE, UV) * tint;
}
