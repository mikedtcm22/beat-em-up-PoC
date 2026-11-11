shader_type spatial;
// A banded halo card on a light source (LD-WORLD; PLAN.md section 4 part 4) in place of Godot's smooth glow: a camera-facing
// quad whose rings are hard bands of uneven width, the white core, a few fainter coloured rings, each ring's edge wobbling with the
// angle round the light (a painted halo, the sun in ref 2 at 50.5 s, a lamp in the targets). Added to the picture, behind nothing but
// the depth test, so a pillar in front of a lamp hides it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 ring_color : source_color = vec3(1.0, 0.6, 0.2);
// The core's share of the card's radius, the number of rings, their strength (the nearest ring's; each is fainter) and how uneven they are.
uniform float core : hint_range(0.0, 1.0) = 0.12;
uniform float rings : hint_range(0.0, 6.0) = 3.0;
uniform float ring_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wobble : hint_range(0.0, 0.5) = 0.2;
uniform float seed = 1.0;
// How soft each ring's edge is, as a share of the ring's own width (0: the hard painted band, 1: each tone melts into the next).
// The outermost tone always fades to nothing before the card's edge, so no halo is ever a flat disc with a rim.
uniform float soft : hint_range(0.0, 1.0) = 0.6;
uniform float energy : hint_range(0.0, 4.0) = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
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
	float phi = atan(p.y, p.x);
	float n_rings = floor(rings);
	float band = (1.0 - core) / max(n_rings, 1.0);
	float edge = max(fwidth(r) * 1.3, 0.004);
	float feather = max(edge, soft * 0.5 * band);
	vec3 col = vec3(0.0);
	for (int k = 6; k >= 1; k--) {
		if (float(k) <= n_rings) {
			float fk = float(k);
			float wob = (vnoise(vec2(phi * 1.4 + fk * 5.3 + seed * 11.0, fk * 2.9 + seed)) - 0.5) * 2.0 * wobble;
			float rk = (core + (1.0 - core) * fk / n_rings) * (1.0 + wob * 0.5) * 0.8;
			float inside = 1.0 - smoothstep(rk - feather, rk + feather, r);
			col = max(col, ring_color * ring_strength * inside * (1.0 - 0.8 * (fk - 1.0) / max(n_rings, 1.0)));
		}
	}
	float rc = core * (1.0 + (vnoise(vec2(phi * 2.0 + seed, 4.1)) - 0.5) * wobble * 0.4);
	float core_feather = max(edge, soft * 0.5 * core);
	float inside_core = 1.0 - smoothstep(rc - core_feather, rc + core_feather, r);
	col = mix(col, core_color, inside_core);
	col *= 1.0 - smoothstep(0.7, 1.0, r);
	ALBEDO = col * energy;
	ALPHA = clamp(max(col.r, max(col.g, col.b)) * 4.0, 0.0, 1.0);
}
