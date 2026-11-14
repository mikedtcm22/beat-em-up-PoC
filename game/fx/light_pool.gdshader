shader_type spatial;
// A painted light pool on the ground (M7 T10, redrawn in G4): the lit patch under a lamp or a fire as the trailer paints it (t_04), an
// irregular blob (lumpy, stretched along an axis of its own, never an ellipse and never a star) in three stepped flat tones, an outer
// wash, a mid tone and a bright core, each with its own outline. The edges are crisp (a few pixels of anti-aliasing) and brushed: a
// streak noise stretched across the edge bites it the way a loaded brush leaves it; only the outermost wash fades, over `soft`. No
// Gaussian falloff anywhere. A horizontal plane (PlaneMesh, UV 0..1) a hair above the floor (or a vertical card for a wall glow); mixed
// over the picture, never written to the depth buffer, so a figure standing in it covers it. Presentation only (the trailer profile).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 rim_color : source_color = vec3(0.9, 0.38, 0.08);
uniform vec3 core_color : source_color = vec3(1.0, 0.62, 0.2);
// The wash's and the core's alpha, scaled together by `opacity` (the mid tone sits between).
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float core_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
// Radii as a share of the card's half-size (the wash's and the core's; the mid tone is between), how far the lumps bend the outline, and
// the lumps' frequency (a few big ones, as painted, not a ring of bites).
uniform float rim_r : hint_range(0.2, 1.0) = 0.95;
uniform float core_r : hint_range(0.1, 0.9) = 0.5;
uniform float broken : hint_range(0.0, 0.6) = 0.22;
uniform float bite_freq : hint_range(0.5, 8.0) = 2.4;
// How far the outer wash fades out (a share of the card's half-size; 0 is the hard cut-out). The inner tones are always crisp.
uniform float soft : hint_range(0.0, 0.6) = 0.2;
// The ground direction the pool is pushed along (away from the lamp's pole) and by how much (share of the half-size).
uniform vec2 push = vec2(0.0, 0.0);
uniform float seed = 1.0;
// The brushed edge: how far the streak noise bites an outline (a share of the half-size).
uniform float brush : hint_range(0.0, 0.2) = 0.05;

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

// An outline's coverage: 1 inside (field < 0), anti-aliased over `w` either side.
float cover(float field, float w) {
	return 1.0 - smoothstep(-w, w, field);
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) - push;
	// The blob's own axis and stretch (a seed's), so no two pools lie the same way.
	float a0 = hash12(vec2(seed, 1.3)) * 6.2831853;
	vec2 ax = vec2(cos(a0), sin(a0));
	vec2 cr = vec2(-ax.y, ax.x);
	float along = dot(p, ax);
	float across = dot(p, cr);
	float stretch = 1.0 + 0.5 * hash12(vec2(seed, 7.7));
	vec2 q = vec2(along, across * stretch);
	// Big lumps (two octaves), and the brush: streaks running along the axis, so an edge is bitten in strokes.
	vec2 s = vec2(seed * 9.1, seed * 4.3);
	float lump = 0.65 * vnoise(q * bite_freq * 0.8 + s) + 0.35 * vnoise(q * bite_freq * 1.9 + s * 1.7 + 5.0) - 0.5;
	float bite = vnoise(vec2(along * 3.0, across * 26.0) + s) - 0.5;
	// The lumps' largest push is 2 x broken (and the brush's `brush`): shape is divided by it, so no outline ever reaches the card's edge.
	float shape = (1.0 + lump * broken * 4.0 + bite * brush * 2.0) / (1.0 + broken * 2.0 + brush);
	float r = length(q);
	float aa = max(fwidth(r) * 1.3, 0.004);
	// Each tone is its own outline: the mid tone and the core drift off-centre a little, as separately laid paint does.
	float f_wash = r - rim_r * shape;
	float f_mid = length(q - vec2(0.06, -0.04) * rim_r) - mix(core_r, rim_r, 0.55) * (shape * 0.96 + lump * 0.3);
	float f_core = length(q + vec2(0.05, 0.05) * rim_r) - core_r * (shape * 0.92 + lump * 0.5 + bite * brush);
	float wash = cover(f_wash, max(aa, soft * 0.5));
	float mid = cover(f_mid, aa);
	float core = cover(f_core, aa);
	vec3 mid_color = mix(rim_color, core_color, 0.5);
	vec3 col = mix(mix(rim_color, mid_color, mid), core_color, core);
	float a_mid = mix(rim_alpha, core_alpha, 0.5);
	float a = mix(mix(rim_alpha * wash, a_mid, mid), core_alpha, core);
	float alpha = clamp(a * opacity, 0.0, 1.0);
	// M7 D2: outside the blob nothing is written (the pool and wall cards are big quads, mostly empty).
	if (alpha <= 0.0) {
		discard;
	}
	ALBEDO = col;
	ALPHA = alpha;
}
