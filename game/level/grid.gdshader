shader_type spatial;
// Graybox floor: flat base with 1 m and 5 m grid lines in world space.

uniform vec3 base_color : source_color = vec3(0.30, 0.29, 0.33);
uniform vec3 line_color : source_color = vec3(0.42, 0.41, 0.47);
uniform vec3 major_color : source_color = vec3(0.52, 0.5, 0.58);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float minor = grid_line(world_pos.xz);
	float major = grid_line(world_pos.xz / 5.0);
	vec3 c = mix(base_color, line_color, minor * 0.7);
	ALBEDO = mix(c, major_color, major);
	ROUGHNESS = 0.92;
}
