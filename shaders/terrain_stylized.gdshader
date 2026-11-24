shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_schlick_ggx;

uniform vec4 grass_top_color : source_color = vec4(0.32, 0.87, 0.18, 1.0);
uniform vec4 grass_highlight : source_color = vec4(0.65, 0.95, 0.22, 1.0);
uniform vec4 soil_upper_color : source_color = vec4(0.80, 0.43, 0.22, 1.0);
uniform vec4 soil_deep_color : source_color = vec4(0.45, 0.21, 0.11, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.72, 1.0);

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// COLOR.r encodes surface type: 1.0 = grass crust, 0.5 = bevel lip, 0.0 = deep soil
	float crust_mask = COLOR.r;
	float depth_t = clamp(COLOR.g, 0.0, 1.0);

	float n1 = value_noise(world_pos.xy * 0.45);
	float n2 = value_noise(world_pos.xy * 1.65);

	// Diagonal candy-strata stripes inside the cross-section wall
	float stripe = sin((world_pos.x * 0.55 + world_pos.y * 0.95) * 2.2 + n1 * 1.8) * 0.5 + 0.5;
	float pebble = smoothstep(0.72, 0.80, n2);

	vec3 soil = mix(soil_upper_color.rgb, soil_deep_color.rgb, depth_t * 0.85 + stripe * 0.22);
	soil = mix(soil, soil_upper_color.rgb * 1.22, pebble * 0.35);

	vec3 grass = mix(grass_top_color.rgb, grass_highlight.rgb, smoothstep(0.35, 0.75, n1));

	vec3 final_albedo = mix(soil, grass, smoothstep(0.42, 0.68, crust_mask));

	ALBEDO = final_albedo;
	ROUGHNESS = mix(0.78, 0.48, crust_mask);
	METALLIC = 0.04;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.2);
	EMISSION = rim_color.rgb * fresnel * (0.14 + 0.22 * crust_mask);
}
