shader_type spatial;
// The burn barrel's glow on the ground (M7 T16a, softened in F3): a painted pool, two orange tones whose edges are bitten by noise
// (never a ring) and fade out softly, breathing on twos (`slot`, written by StreetFx).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 outer_color : source_color = vec3(0.95, 0.42, 0.1);
uniform vec3 inner_color : source_color = vec3(1.0, 0.68, 0.22);
uniform float alpha = 0.5;
uniform float slot = 0.0;
uniform float seed = 1.0;
// How soft the edges are, as a share of the card's half-size, and how far the noise bends them.
uniform float soft : hint_range(0.0, 0.6) = 0.25;
uniform float broken : hint_range(0.0, 0.6) = 0.2;

float hash11(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float breath = 1.0 + 0.07 * (hash11(slot) - 0.5);
	float n = 0.7 * vnoise(vec2(ang * 2.2 + seed * 5.1, seed)) + 0.3 * vnoise(vec2(ang * 6.4 + seed * 2.3, 3.0 + seed)) - 0.5;
	float rr = (r + n * broken * 2.0) / breath;
	float aa = max(fwidth(r) * 1.3, 0.004);
	float outer = 1.0 - smoothstep(0.95 - max(aa, soft) * 1.6, 0.95, rr);
	float inner = 1.0 - smoothstep(0.5 - max(aa, soft * 0.6), 0.5 + max(aa, soft * 0.6) * 0.4, rr + 0.08 * n);
	ALBEDO = mix(outer_color, inner_color, inner);
	ALPHA = outer * alpha * mix(0.55, 1.0, inner);
}
