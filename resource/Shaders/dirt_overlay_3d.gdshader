shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D dirt_mask : filter_linear;
uniform float dirt_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec4 dirt_tint : source_color = vec4(0.4, 0.3, 0.2, 1.0);

void vertex() {
	// Push vertices slightly outward along normals to render on top
	VERTEX += NORMAL * 0.001;
}

void fragment() {
	// Sample the cleaning mask using UV2 (proper unwrap for painting)
	// UV2 should be a standard unwrap covering the whole surface
	float mask_value = texture(dirt_mask, UV2).r;

	// Calculate dirt visibility
	float dirt_amount = mask_value * dirt_strength;

	// Output dirt color with alpha for blending
	ALBEDO = dirt_tint.rgb;
	ALPHA = dirt_amount;

	// Make it look like dirt
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
