shader_type canvas_item;

// Reveal from the top of the texture toward the bottom.
uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	// UV.y is 0 at the top and 1 at the bottom.
	if (UV.y > reveal) {
		tex_color.a = 0.0;
	}
	COLOR = tex_color;
}
