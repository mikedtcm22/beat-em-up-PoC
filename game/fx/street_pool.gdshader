shader_type spatial;
// The burn barrel's glow on the ground (M7 T16a, redrawn in G4): a painted pool like light_pool.gdshader's, an irregular lumpy blob in
// three stepped flat orange tones (an outer wash, a mid tone, a core) with crisp brushed edges, never a ring and never a Gaussian
// falloff, breathing on twos (`slot`, written by StreetFx): each drawing nudges the lumps, as a hand redrawing the patch.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 outer_color : source_color = vec3(0.95, 0.42, 0.1);
uniform vec3 inner_color : source_color = vec3(1.0, 0.68, 0.22);
uniform float alpha = 0.5;
uniform float slot = 0.0;
uniform float seed = 1.0;
// How far the outer wash fades out, as a share of the card's half-size, and how far the lumps bend the outline.
uniform float soft : hint_range(0.0, 0.6) = 0.25;
uniform float broken : hint_range(0.0, 0.6) = 0.2;
// The brushed edge: how far the streak noise bites an outline (a share of the half-size).
uniform float brush : hint_range(0.0, 0.2) = 0.05;

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

float cover(float field, float w) {
	return 1.0 - smoothstep(-w, w, field);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a0 = hash11(seed * 3.1) * 6.2831853;
	vec2 ax = vec2(cos(a0), sin(a0));
	vec2 cr = vec2(-ax.y, ax.x);
	float along = dot(p, ax);
	float across = dot(p, cr);
	float stretch = 1.0 + 0.45 * hash11(seed * 5.7);
	vec2 q = vec2(along, across * stretch);
	// The drawing's own nudge: the lumps slide a little each slot (held, then redrawn).
	vec2 s = vec2(seed * 5.1, seed * 2.3) + vec2(hash11(slot + seed), hash11(slot * 1.7 + seed + 4.0)) * 0.6;
	float lump = 0.65 * vnoise(q * 1.9 + s) + 0.35 * vnoise(q * 4.6 + s * 1.7 + 3.0) - 0.5;
	float bite = vnoise(vec2(along * 3.0, across * 26.0) + s) - 0.5;
	float shape = (1.0 + lump * broken * 4.0 + bite * brush * 2.0) / (1.0 + broken * 2.0 + brush);
	float r = length(q);
	float aa = max(fwidth(r) * 1.3, 0.004);
	float wash = cover(r - 0.95 * shape, max(aa, soft * 0.5));
	float mid = cover(length(q - vec2(0.06, -0.04)) - 0.72 * (shape * 0.96 + lump * 0.3), aa);
	float core = cover(length(q + vec2(0.05, 0.05)) - 0.46 * (shape * 0.92 + lump * 0.5 + bite * brush), aa);
	vec3 mid_color = mix(outer_color, inner_color, 0.5);
	float a = mix(mix(wash * 0.8, 0.94, mid), 1.0, core) * alpha;
	// M7 D2: outside the blob nothing is written (the card is a big quad, mostly empty).
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = mix(mix(outer_color, mid_color, mid), inner_color, core);
	ALPHA = a;
}
