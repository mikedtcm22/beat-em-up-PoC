shader_type spatial;
// The painted character's hull (Milestone 7, T11): toon_outline.gdshader's inverted hull for the skinned art (mode 4: the
// baked smooth normal in COLOR, carried through the skin from CUSTOM1), with the trailer's ink on it:
//  - WEIGHT from the art's ink map (A, line weight hint, on UV2, read per vertex at weight_lod): 0 is weight_min times the
//    line, 1 weight_max times it, so a limb's line tapers toward its ends where the artist painted A down. A must match on
//    both sides of a UV seam (the two vertices of a seam share a position and must share a width, or the shell cracks).
//  - Ink weighs under a form: the line is heavier where the surface faces down (under_bias), lighter on top, so the width
//    changes along any limb that bends, with no map at all.
//  - DISTANCE: heavier than the m6 line near the lens (near_gain at near_m, back to 1 at boost_to_m), and from thin_from_m
//    out to far_m thinning to far_gain; the line otherwise holds its pixel width like the m6 hull's.
//  - DRAWN (M7 G1): the width swells and tapers with an object-space noise (hull_vary), is heavier on the side away from the key
//    (hull_shadow) and lighter toward it, wobbles by a pixel or so on a beat (twos, paint_wobble_hz) and breaks in hard-edged gaps where the
//    surface faces the key (hull_gap). The noise is in the rest pose (CUSTOM0), so the line sticks to the body; two vertices of a seam share it.
// One material per ink map (ToonMaterials.outline_painted()), every value a uniform. Mirrored for the tests by
// ToonMaterials.painted_hull_width_m(). Like the m6 hull: no fog, the player's body thinner (fp_scale), faded near the lens, and
// no width in an orthographic pass (a shadow map).
render_mode unshaded, cull_front, fog_disabled;

#include "res://game/fx/paint_grain.gdshaderinc"

global uniform vec3 paint_key_dir;

uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform sampler2D ink_tex : filter_linear_mipmap, repeat_disable;
uniform float width_px : hint_range(0.0, 16.0) = 3.75;
uniform float near_m : hint_range(0.1, 10.0) = 1.0;
uniform float far_m : hint_range(1.0, 100.0) = 12.0;
uniform float fp_scale : hint_range(0.0, 2.0) = 1.0;
uniform float lens_fade_m : hint_range(0.0, 1.0) = 0.1;
uniform float near_gain : hint_range(1.0, 4.0) = 1.6;
uniform float boost_to_m : hint_range(0.5, 20.0) = 3.0;
uniform float thin_from_m : hint_range(0.5, 40.0) = 6.0;
uniform float far_gain : hint_range(0.1, 1.0) = 0.55;
uniform float weight_min : hint_range(0.05, 1.0) = 0.3;
uniform float weight_max : hint_range(0.5, 3.0) = 1.5;
uniform float weight_lod : hint_range(0.0, 6.0) = 3.0;
uniform float under_bias : hint_range(0.0, 0.9) = 0.5;
uniform float paint_wobble_hz : hint_range(1.0, 30.0) = 12.0;
uniform float hull_vary : hint_range(0.0, 0.9) = 0.45;
uniform float hull_vary_cells : hint_range(1.0, 40.0) = 6.0;
uniform float hull_shadow : hint_range(0.0, 2.0) = 0.7;
uniform float hull_wobble_px : hint_range(0.0, 4.0) = 1.1;
uniform float hull_wobble_cells : hint_range(1.0, 60.0) = 11.0;
uniform float hull_gap : hint_range(0.0, 1.0) = 0.4;
uniform float hull_gap_cells : hint_range(2.0, 80.0) = 14.0;

varying vec3 hull_rest;
varying float hull_side;

vec3 rotate_arc(vec3 a, vec3 b, vec3 x) {
	vec3 axis = cross(a, b);
	float c = dot(a, b);
	if (c < -0.999) {
		return -x;
	}
	return x + cross(axis, x) + cross(axis, cross(axis, x)) / (1.0 + c);
}

void vertex() {
	vec3 smooth_rest = normalize(COLOR.rgb * 2.0 - 1.0);
	vec3 rest_normal = CUSTOM1.xyz;
	vec3 dir = length(rest_normal) > 0.5 ? rotate_arc(normalize(rest_normal), normalize(NORMAL), smooth_rest) : NORMAL;
	float dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float proj_scale = abs(PROJECTION_MATRIX[1][1]);
	float fade = smoothstep(0.0, 1.0, (dist - lens_fade_m) / max(lens_fade_m, 0.0001));
	// The pixel weight: near and far gains, the ink map's hint, the weight under a form.
	float gain = mix(near_gain, 1.0, smoothstep(near_m, boost_to_m, dist)) * mix(1.0, far_gain, smoothstep(thin_from_m, max(far_m, thin_from_m + 0.1), dist));
	float hint = textureLod(ink_tex, UV2, weight_lod).a;
	float weight = mix(weight_min, weight_max, hint);
	float down = clamp(-(MODEL_MATRIX * vec4(dir, 0.0)).y, -1.0, 1.0);
	float under = 1.0 + under_bias * down;
	// The drawn line: where the surface turns from the key (-1) or to it (1), the noise swell, the beat's wobble.
	vec3 rest = CUSTOM0.xyz;
	float side = dot(normalize((MODEL_MATRIX * vec4(dir, 0.0)).xyz), normalize(paint_key_dir));
	float swell = mix(1.0 - hull_vary, 1.0 + hull_vary, paint_grain_noise(rest * hull_vary_cells + vec3(3.0, 1.0, 8.0)));
	float weigh = mix(1.0 + hull_shadow, 1.0 - 0.35 * min(hull_shadow, 1.0), smoothstep(-0.6, 0.6, side));
	float beat = floor(TIME * paint_wobble_hz);
	float wobble = paint_grain_noise(rest * hull_wobble_cells + vec3(beat * 1.7, beat * 0.9, beat * 2.3)) - 0.5;
	float px_m = 2.0 * clamp(dist, near_m, far_m) / (1080.0 * proj_scale);
	float width_m = (width_px * fp_scale * gain * weight * under * swell * weigh + 2.0 * hull_wobble_px * wobble) * px_m * fade;
	width_m = max(width_m, 0.0);
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		width_m = 0.0;
	}
	hull_rest = rest;
	hull_side = side;
	VERTEX += dir * width_m;
}

void fragment() {
	// A break on the lit side: a whole cell of the noise, hard-edged, and only where a cell is wide enough on screen to read as a gap.
	float gap_cell = hull_gap_cells * length(fwidth(hull_rest));
	float gap_noise = paint_grain_noise(hull_rest * hull_gap_cells + vec3(17.0, 3.0, 11.0));
	if (smoothstep(0.0, 0.5, hull_side) * step(1.0 - hull_gap, gap_noise) * (1.0 - smoothstep(0.2, 0.5, gap_cell)) > 0.5) {
		discard;
	}
	ALBEDO = ink;
}
