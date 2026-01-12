shader_type spatial;

uniform sampler2D dirt : repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_normal : repeat_enable, hint_normal, filter_linear_mipmap;
uniform vec3 dirt_tint : source_color;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.5;

group_uniforms dissolve;
uniform float offset : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float smoothness : hint_range(0.0, 1.0, 0.01) = 0.1;

group_uniforms triplanar;
varying vec3 uv1_triplanar_pos;
uniform float uv1_blend_sharpness : hint_range(0.0, 150.0, 0.001);
varying vec3 uv1_power_normal;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;

void vertex() {
	vec3 normal = NORMAL;

	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = normalize(TANGENT);

	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = normalize(BINORMAL);

	// UV1 Triplanar: Enabled
	uv1_power_normal = pow(abs(NORMAL), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = VERTEX * uv1_scale + uv1_offset;
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

void fragment() {
	float dirt_mask = triplanar_texture(dirt, uv1_power_normal, uv1_triplanar_pos).x - offset;
	vec3 dirt_nomal = triplanar_texture(dirt_normal, uv1_power_normal, uv1_triplanar_pos).xyz;
	ALBEDO = dirt_tint;
	NORMAL_MAP = dirt_nomal;
	ROUGHNESS = 0.8;
	float mask = smoothstep(max(0.0, edge - smoothness), min(1.0, edge + smoothness), dirt_mask);
	ALPHA = smoothstep(0.4, 0.6, mask) * mask * opacity;
}