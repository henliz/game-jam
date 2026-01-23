// NOTE: Shader automatically converted from Godot Engine 4.5.1.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_toon;

group_uniforms color;
uniform vec4 basecolor : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_hue_shift : source_color, filter_linear_mipmap, repeat_enable;
uniform float hue_shift_strength : hint_range(0.0, 2.0, 0.1) = float(0.5);

group_uniforms roughness;
uniform float roughness : hint_range(0.0, 1.0) = float(0.5);
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

group_uniforms normal;
uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-2.0, 2.0) = float(1.0);

group_uniforms occlusion;
uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ao_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.01);

group_uniforms backlight;
uniform vec4 backlight_color : source_color;
uniform sampler2D texture_backlight : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 uv1_triplanar_pos;

group_uniforms mapping;
uniform float uv1_blend_sharpness : hint_range(0.0, 32.0, 0.001) = float(2.0);
varying vec3 uv1_power_normal;

uniform vec3 uv1_scale = vec3(6.0);
uniform vec3 uv1_offset;

//const float linear_middle_gray = float(0.5 / 2.2);
const float middle_gray = float(0.5);

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

float adjust_shift_contrast(float shift_value, float strength) {
	float adjusted = ((shift_value - middle_gray) * strength) + middle_gray;
	return adjusted;
}

vec3 shift_hue2(in vec3 color, in float shift) {
	float shift_angle = (shift - (1.0 - middle_gray)) * TAU;
	const vec3 k = vec3(0.57735);
	float cos_angle = cos(shift_angle);
	return vec3(color * cos_angle + cross(k, color) * sin(shift_angle) + k * dot(k, color) * (1.0 - cos_angle));
}

void fragment() {
	vec4 texture_albedo_uv = texture(texture_albedo, UV);
	//vec4 texture_albedo_triplanar = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);
	vec4 texture_hue_triplanar = triplanar_texture(texture_hue_shift, uv1_power_normal, uv1_triplanar_pos);
	vec4 albedo = basecolor * texture_albedo_uv;

	float gray = texture_hue_triplanar.r;
	float adjusted = adjust_shift_contrast(gray, hue_shift_strength);
	ALBEDO = shift_hue2(albedo.rgb, adjusted);
	//ALBEDO = vec3(adjusted);

	//SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(triplanar_texture(texture_roughness, uv1_power_normal, uv1_triplanar_pos), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;

	// Normal Map: Enabled
	NORMAL_MAP = texture(texture_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	// Ambient Occlusion: Enabled
	AO = dot(triplanar_texture(texture_ambient_occlusion, uv1_power_normal, uv1_triplanar_pos), ao_texture_channel);
	AO_LIGHT_AFFECT = ao_light_affect;

	// Backlight: Enabled
	vec3 texture_backlight_triplanar = triplanar_texture(texture_backlight, uv1_power_normal, uv1_triplanar_pos).rgb;
	vec4 texture_backlight_uv = texture(texture_backlight, UV);
	//BACKLIGHT = (backlight.rgb + backlight_tex);
	BACKLIGHT = texture_backlight_uv.rgb * backlight_color.rgb;
}
