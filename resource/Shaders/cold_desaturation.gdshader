shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float saturation : hint_range(0.0, 1.0) = 0.3;
uniform vec3 cold_tint : source_color = vec3(0.7, 0.8, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;
uniform float brightness : hint_range(0.5, 1.5) = 0.9;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);

	// Calculate luminance for desaturation
	float luma = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(luma);

	// Partial desaturation
	vec3 desaturated = mix(screen_color.rgb, grayscale, 1.0 - saturation);

	// Apply cold tint
	vec3 tinted = mix(desaturated, desaturated * cold_tint, tint_strength);

	// Adjust brightness (slightly darker for that cold, dim feeling)
	tinted *= brightness;

	// Final mix based on intensity
	vec3 final_color = mix(screen_color.rgb, tinted, intensity);

	COLOR = vec4(final_color, screen_color.a);
}
