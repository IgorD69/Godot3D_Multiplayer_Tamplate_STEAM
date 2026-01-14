shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_mix, depth_prepass_alpha;
uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 2.0;
// Wind parameters
uniform sampler2D wind_noise : hint_default_white;  // Perlin noise pentru vânt
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_frequency : hint_range(0.1, 10.0) = 2.0;  // Cât de des se mișcă
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.3;  // Rafale de vânt
varying vec3 worldPos;
void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// --- WIND EFFECT ---
	// Sample 1: Primary wind wave (slow, large movements)
	vec2 wind_uv1 = worldPos.xz / 20.0 + normalize(wind_direction) * TIME * wind_speed * 0.5;
	float wind_sample1 = texture(wind_noise, wind_uv1).r;
	
	// Sample 2: Secondary wind (faster, smaller movements)
	vec2 wind_uv2 = worldPos.xz / 10.0 + normalize(wind_direction) * TIME * wind_speed * 1.5;
	float wind_sample2 = texture(wind_noise, wind_uv2).r;
	
	// Sample 3: Turbulence (rapid gusts)
	vec2 turb_uv = worldPos.xz / 5.0 + TIME * wind_speed * 3.0;
	float turbulence = texture(wind_noise, turb_uv).r * wind_turbulence;
	
	// Combine wind samples
	float wind_intensity = wind_sample1 * 0.6 + wind_sample2 * 0.3 + turbulence * 0.1;
	wind_intensity = (wind_intensity - 0.5) * 2.0; // Remap to -1..1
	
	// Only affect the top part of grass (based on UV.y)
	float height_factor = 1.0 - UV.y;
	height_factor = pow(height_factor, 1.5); // Non-linear for more realistic bend
	
	// Convert wind direction to vertex space
	vec2 vert_wind_dir = (inverse(MODEL_MATRIX) * vec4(wind_direction, 0.0, 0.0)).xy;
	vert_wind_dir = normalize(vert_wind_dir);
	
	// Apply wind displacement
	vec3 wind_offset = vec3(
		wind_intensity * vert_wind_dir.x,
		-abs(wind_intensity) * 0.2,  // Slight downward bend
		wind_intensity * vert_wind_dir.y
	);
	
	VERTEX += wind_offset * wind_strength * height_factor;
	
	// Add slight rotation effect for more realism
	float rotation_amount = wind_intensity * 0.1 * height_factor;
	VERTEX.x += sin(worldPos.z * 0.5 + TIME * wind_speed) * rotation_amount * wind_strength;
}
void fragment() {
	vec3 noiseLevel = texture(noise, UV).rgb;
	ALBEDO = mix(color, color2, 1.0 - UV.y) * mix(color, color2, noiseLevel.r);
	
	ALPHA = 1.0;
	
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
