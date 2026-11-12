shader_type spatial;
// A painted wash over a far facade (M7 G4): the kit's skyline blocks carry a regular window pattern, so a card laid a hand's breadth in
// front of each face paints part of it out: irregular flat patches in two stepped tones (a lighter wash and a darker shadow shape inside
// it), their edges brushed by a streak noise and anti-aliased to a few pixels, never a gradient. The patches' size is in metres of the
// face (`card_m`, `patch_m`), so a wall keeps its patches whatever its size, and they are denser toward the ground (the haze of the
// street). Mixed over the picture, unshaded, never written to the depth buffer. Presentation only (the trailer profile).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 wash_color : source_color = vec4(0.2, 0.18, 0.42, 0.7);
uniform vec2 card_m = vec2(20.0, 20.0);
uniform float patch_m : hint_range(1.0, 20.0) = 5.0;
// The share of the face the lighter wash covers (the darker tone covers a part of that).
uniform float cover : hint_range(0.0, 1.0) = 0.42;
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
	vec2 m = vec2(UV.x, 1.0 - UV.y) * card_m;
	vec2 s = vec2(seed * 7.7, seed * 3.1);
	// Big patches (stretched wide, so a patch is a band, as a roller leaves it), small paint-outs, and the brush on every edge. Three
	// noises in all: the wash covers a good part of the picture, so it stays cheap.
	float lump = vnoise(m / (patch_m * vec2(0.8, 1.0)) + s);
	float small = vnoise(m / (patch_m * vec2(0.22, 0.17)) + s * 2.3 + 8.0);
	float bristle = vnoise(vec2(m.x * 0.7, m.y * 5.0) + s) - 0.5;
	float v = lump + bristle * 0.16;
	// Denser toward the ground: the share grows a little toward the bottom of the face.
	float near_ground = (1.0 - UV.y) * 0.5 + 0.75;
	float edge_a = cover * near_ground;
	float aa = max(fwidth(v) * 1.3, 0.004);
	float light_wash = smoothstep(1.0 - edge_a - aa, 1.0 - edge_a + aa, v);
	float dark_wash = smoothstep(1.0 - edge_a * 0.45 - aa, 1.0 - edge_a * 0.45 + aa, v + 0.04);
	// Paint-outs: small, opaque patches (a few windows each) that cover the lit panes the kit's facade shows, so the rows are broken where
	// the patches fall and nowhere else.
	float out_cover = cover * 0.7 * near_ground;
	float aa2 = max(fwidth(small) * 1.3, 0.004);
	float paint_out = smoothstep(1.0 - out_cover - aa2, 1.0 - out_cover + aa2, small + bristle * 0.2);
	float a = wash_color.a * (light_wash * 0.55 + dark_wash * 0.3);
	a = max(a, paint_out * min(wash_color.a * 1.35, 0.95));
	ALBEDO = wash_color.rgb * (1.0 - dark_wash * 0.22 * (1.0 - paint_out));
	ALPHA = clamp(a, 0.0, 1.0);
}
