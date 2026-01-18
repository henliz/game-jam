shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.05;

void vertex() {
	// Inverted hull method: push vertices outward along object-space normals
	// This produces a cleaner outline for complex meshes
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	if (outline_color.a < 1.0) {
		ALPHA = outline_color.a;
	}
}