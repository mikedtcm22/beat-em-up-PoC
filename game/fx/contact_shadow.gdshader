shader_type spatial;
// A painted contact shadow under a character (LD-WORLD3; PLAN.md section 4 part 4 and P1.md, "Light shapes"): a dark shape on the ground at the feet,
// two flat values (a darker core inside a lighter body), its edge broken by a noise of its own so no two are alike and none is an ellipse, stretched
// along the direction away from the key. Placed by VideoWorldContact in world space from the character's position (never from a shadow map). The edge is
// anti-aliased with fwidth. The mesh is a horizontal plane of 1.6 m; `rel` is the offset from its centre in the plane's own half-extents, in world axes.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shade_color : source_color = vec3(0.01, 0.012, 0.035);
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
uniform float seed = 1.0;
// The ground direction the shadow stretches along (away from the key), its stretch, and how far its edge is broken.
uniform vec2 dir = vec2(0.0, 1.0);
uniform float stretch : hint_range(1.0, 3.0) = 1.4;
uniform float broken : hint_range(0.0, 0.6) = 0.28;
uniform float body_r : hint_range(0.2, 1.0) = 0.62;
uniform float core_r : hint_range(0.1, 0.8) = 0.34;
// 1 = one soft dark blob (a figure's: a round falloff along the stretch, no noise, no hard core; M7 C1), 0 = the drawn two-value shape above.
uniform float soft_blob : hint_range(0.0, 1.0) = 0.0;

varying vec2 rel;

void vertex() {
	rel = VERTEX.xz / 0.8;
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
	vec2 d = normalize(dir + vec2(0.0001));
	float along = dot(rel, d);
	float across = dot(rel, vec2(-d.y, d.x));
	vec2 q = vec2((along - 0.16) / stretch, across);
	float ang = atan(q.y, q.x);
	float n = 0.6 * vnoise(vec2(ang * 1.5 + seed * 7.3, seed * 1.7)) + 0.4 * vnoise(vec2(ang * 4.3 + seed * 3.1, 2.0 + seed)) - 0.5;
	float r = length(q) + n * broken * 2.0;
	float aa = max(fwidth(r) * 1.2, 0.003);
	float body = 1.0 - smoothstep(body_r - aa, body_r + aa, r);
	float core = 1.0 - smoothstep(core_r - aa, core_r + aa, r + 0.06 * n);
	// The blob: a smooth falloff from the centre to the body's edge, on the same stretched ground axes and with no noise.
	float blob = 1.0 - smoothstep(0.0, body_r, length(q));
	blob = min(blob * 1.6, 1.0);
	ALBEDO = shade_color;
	ALPHA = mix(body * 0.55 + core * 0.45, blob, soft_blob) * opacity;
}
