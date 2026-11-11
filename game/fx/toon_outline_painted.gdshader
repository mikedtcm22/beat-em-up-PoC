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
// One material per ink map (ToonMaterials.outline_painted()), every value a uniform. Mirrored for the tests by
// ToonMaterials.painted_hull_width_m(). Like the m6 hull: no fog, the player's body thinner (fp_scale), faded near the lens, and
// no width in an orthographic pass (a shadow map).
render_mode unshaded, cull_front, fog_disabled;

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
	float width_m = width_px * fp_scale * gain * weight * under * 2.0 * clamp(dist, near_m, far_m) / (1080.0 * proj_scale) * fade;
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		width_m = 0.0;
	}
	VERTEX += dir * width_m;
}

void fragment() {
	ALBEDO = ink;
}
