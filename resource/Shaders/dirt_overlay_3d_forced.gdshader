shader_type spatial;
render_mode blend_mix, depth_test_disabled, cull_disabled, shadows_disabled, unshaded;

uniform sampler2D dirt_mask : filter_linear;
uniform float dirt_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec4 dirt_tint : source_color = vec4(0.4, 0.3, 0.2, 1.0);

void vertex() {
	// Push vertices slightly outward along normals to render on top
	VERTEX += NORMAL * 0.003;
}

void fragment() {
	float mask_value = texture(dirt_mask, UV).r;
	float dirt_amount = mask_value * dirt_strength;

	// Discard fully transparent pixels to avoid depth issues
	if (dirt_amount < 0.01) {
		discard;
	}

	ALBEDO = dirt_tint.rgb;
	ALPHA = dirt_amount;
}
