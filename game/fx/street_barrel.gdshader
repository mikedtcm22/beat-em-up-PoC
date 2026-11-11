shader_type spatial;
// The burn barrel's body (M7 T16a): flat, unlit, two tones with a darker band at the ribs and the top turned orange by the fire.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 body_color : source_color = vec3(0.2, 0.22, 0.3);
uniform vec3 rib_color : source_color = vec3(0.11, 0.12, 0.18);
uniform vec3 fire_color : source_color = vec3(0.88, 0.4, 0.12);
uniform float height_m = 0.95;

varying float ly;

void vertex() {
	ly = VERTEX.y / height_m + 0.5;
}

void fragment() {
	float rib = step(abs(fract(ly * 3.0 + 0.17) - 0.5), 0.07);
	vec3 c = mix(body_color, rib_color, rib);
	c = mix(c, fire_color, step(0.78, ly) * 0.85 + step(0.9, ly) * 0.15);
	ALBEDO = c;
}
