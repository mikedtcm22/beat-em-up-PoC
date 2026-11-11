shader_type spatial;
// Drifting embers for the trailer street (M7 T16a): one MultiMesh of diamond quads, each climbing from the barrel's mouth on a path
// that is a pure function of `slot` (the drawing number at tfx_twos_hz, written by StreetFx) and the instance's seed (custom data x), so
// it holds on twos. Yellow at birth, red as it climbs, gone at the top.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 young_color : source_color = vec3(1.0, 0.82, 0.3);
uniform vec3 old_color : source_color = vec3(0.95, 0.25, 0.06);
uniform float slot = 0.0;
uniform float life_slots = 26.0;
uniform float rise_m = 2.6;
uniform float sway_m = 0.35;
uniform float size_m = 0.055;

varying float age;

float hash11(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	float s = INSTANCE_CUSTOM.x;
	age = fract(slot / life_slots + s);
	float id = s * 91.0;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float a = id * 6.283;
	vec3 off = vec3(
		sin(age * 6.0 + a) * sway_m * age + (hash11(id) - 0.5) * 0.3,
		age * rise_m,
		cos(age * 5.0 + a) * sway_m * age * 0.5 + (hash11(id + 4.0) - 0.5) * 0.3);
	float sz = size_m * (0.6 + 0.8 * hash11(id + 9.0)) * (1.0 - 0.6 * age);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = origin + off + right * VERTEX.x * sz + up * VERTEX.y * sz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 d = abs(UV - 0.5);
	ALPHA = step(d.x + d.y, 0.5) * (1.0 - smoothstep(0.75, 1.0, age));
	ALBEDO = mix(young_color, old_color, age);
}
