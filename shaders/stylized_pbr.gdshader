shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0, 0.62, 0.11, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.32;
uniform vec4 rim_color : source_color = vec4(0.65, 0.92, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	// Subtle vertical glossy toy-box gradient
	float top_boost = clamp(NORMAL.y * 0.14 + 0.06, -0.08, 0.18);
	ALBEDO = clamp(albedo_color.rgb + vec3(top_boost), vec3(0.0), vec3(1.0));
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// Crisp Fresnel rim light (PVZ3 / Angry Birds 2 stylized pop)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * fresnel * rim_strength;
}
