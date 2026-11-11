shader_type spatial;
// A painted light pool on the ground (M7 T10): the lit patch under a lamp or a fire as the trailer draws it, two flat tones
// (a brighter core inside a broader rim), the edge of each bitten by a noise of its own so no pool is an ellipse. A horizontal
// plane (PlaneMesh, UV 0..1) a hair above the floor; mixed over the picture, never written to the depth buffer, so a figure
// standing in it covers it. Anti-aliased with fwidth. Presentation only (the trailer look profile).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 rim_color : source_color = vec3(0.9, 0.38, 0.08);
uniform vec3 core_color : source_color = vec3(1.0, 0.62, 0.2);
// The rim's and the core's alpha, scaled together by `opacity`.
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float core_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
// Radii as a share of the card's half-size, and how far the noise bends their edges (and how many bites round the rim).
uniform float rim_r : hint_range(0.2, 1.0) = 0.95;
uniform float core_r : hint_range(0.1, 0.9) = 0.5;
uniform float broken : hint_range(0.0, 0.6) = 0.22;
uniform float bite_freq : hint_range(0.5, 8.0) = 2.4;
// The ground direction the pool is pushed along (away from the lamp's pole) and by how much (share of the half-size).
uniform vec2 push = vec2(0.0, 0.0);
uniform float seed = 1.0;

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
	vec2 p = (UV * 2.0 - 1.0) - push;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float n = 0.6 * vnoise(vec2(ang * bite_freq + seed * 7.3, seed * 1.7)) + 0.4 * vnoise(vec2(ang * bite_freq * 2.9 + seed * 3.1, 2.0 + seed)) - 0.5;
	float rr = r + n * broken * 2.0;
	float aa = max(fwidth(r) * 1.3, 0.004);
	float rim = 1.0 - smoothstep(rim_r - aa, rim_r + aa, rr);
	float core = 1.0 - smoothstep(core_r - aa, core_r + aa, rr + 0.08 * n);
	vec3 col = mix(rim_color, core_color, core);
	ALBEDO = col;
	ALPHA = clamp(mix(rim * rim_alpha, core_alpha, core) * opacity, 0.0, 1.0);
}
