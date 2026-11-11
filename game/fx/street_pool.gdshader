shader_type spatial;
// The burn barrel's glow on the ground (M7 T16a): two flat orange rings, painted-pool style, that breathe on twos (`slot`, written by StreetFx).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 outer_color : source_color = vec3(0.95, 0.42, 0.1);
uniform vec3 inner_color : source_color = vec3(1.0, 0.68, 0.22);
uniform float alpha = 0.5;
uniform float slot = 0.0;

float hash11(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float breath = 1.0 + 0.07 * (hash11(slot) - 0.5);
	float outer = 1.0 - step(0.95 * breath, r);
	float inner = 1.0 - step(0.5 * breath, r);
	ALBEDO = mix(outer_color, inner_color, inner);
	ALPHA = outer * alpha * mix(0.55, 1.0, inner);
}
