shader_type spatial;
// The video's character line (Phase 1, LD-INK; docs/video/PLAN.md section 4, Plan A part 3): a copy of
// game/fx/toon_outline.gdshader's inverted hull, swapped IN PLACE onto the hull materials of the art
// (video/ink/ink_rig.gd), with the SAME uniform names and the game's pixel-at-1080p width formula, so it is
// scaled by distance and by the render height as the game's is. What it adds:
//  - THE WEIGHT FOLLOWS THE KEY. A vertex whose normal faces the key (key_dir_view, to the light, in view
//    space) gets the thin width, one that faces away gets the heavy width: heavy on the shadow side, thin or
//    gone on the rim side.
//  - IT THINS WITH DISTANCE (far_thin from thin_start_m to thin_end_m), for the mid and wide shots.
//  - IT WANDERS: a noise in the object's own space varies the width along the contour.
//  - SKETCH PASSES: a pass with jitter_px offsets the hull sideways by a smooth object-space noise that is
//    re-seeded from boil_seed (the rig sets it from the output frame at 12 fps), so several chained
//    passes read as overlapping, redrawn strokes. `width_scale` thins the extra passes.
// The ink is the scene's warm brown-black (never pure black); it is unshaded and fog-free like the game's.

render_mode unshaded, cull_front, fog_disabled;

uniform vec3 ink : source_color = vec3(0.09, 0.055, 0.05);
uniform float width_px : hint_range(0.0, 16.0) = 3.75;
uniform float near_m : hint_range(0.1, 10.0) = 1.0;
uniform float far_m : hint_range(1.0, 100.0) = 12.0;
uniform float fp_scale : hint_range(0.0, 2.0) = 1.0;
uniform float lens_fade_m : hint_range(0.0, 1.0) = 0.1;
uniform int mode : hint_range(0, 4) = 0;

// The key's direction in view space (to the light) and how the line weight follows it: the multiplier on the
// shadow side (heavy) and on the lit side (thin), and the facing range over which one turns into the other.
uniform vec3 key_dir_view = vec3(-0.6, 0.5, -0.6);
uniform float heavy_mult : hint_range(0.2, 4.0) = 1.7;
uniform float thin_mult : hint_range(0.0, 2.0) = 0.25;
uniform vec2 key_range = vec2(-0.25, 0.65);
// Distance: the width multiplier far away, from thin_start_m to thin_end_m.
uniform float far_thin : hint_range(0.0, 1.0) = 0.45;
uniform float thin_start_m : hint_range(0.0, 60.0) = 5.0;
uniform float thin_end_m : hint_range(1.0, 100.0) = 20.0;
// The wander along the contour: its strength (a share of the width) and the cells per metre.
uniform float wander : hint_range(0.0, 1.0) = 0.45;
uniform float wander_scale : hint_range(0.5, 40.0) = 7.0;
// A sketch pass: the sideways offset in pixels at 1080p, the seed (changes at 12 fps), this pass's width share.
uniform float jitter_px : hint_range(0.0, 12.0) = 0.0;
uniform float boil_seed : hint_range(0.0, 1000.0) = 0.0;
uniform float pass_id : hint_range(0.0, 8.0) = 0.0;
uniform float width_scale : hint_range(0.0, 2.0) = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec3 rotate_arc(vec3 a, vec3 b, vec3 x) {
	vec3 axis = cross(a, b);
	float c = dot(a, b);
	if (c < -0.999) {
		return -x;
	}
	return x + cross(axis, x) + cross(axis, cross(axis, x)) / (1.0 + c);
}

void vertex() {
	vec3 dir = NORMAL;
	if (mode == 1) {
		dir = vec3(VERTEX.x >= 0.0 ? 1.0 : -1.0, VERTEX.y >= 0.0 ? 1.0 : -1.0, VERTEX.z >= 0.0 ? 1.0 : -1.0);
	} else if (mode == 2) {
		float radial = length(VERTEX.xz);
		vec2 out_xz = radial > 0.00001 ? VERTEX.xz / radial : vec2(0.0);
		dir = vec3(out_xz.x, VERTEX.y >= 0.0 ? 1.0 : -1.0, out_xz.y);
	} else if (mode == 3) {
		dir = length(VERTEX) > 0.00001 ? normalize(VERTEX) : NORMAL;
	} else if (mode == 4) {
		vec3 smooth_rest = normalize(COLOR.rgb * 2.0 - 1.0);
		vec3 rest_normal = CUSTOM1.xyz;
		dir = length(rest_normal) > 0.5 ? rotate_arc(normalize(rest_normal), normalize(NORMAL), smooth_rest) : NORMAL;
	}
	float dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float proj_scale = abs(PROJECTION_MATRIX[1][1]);
	float fade = smoothstep(0.0, 1.0, (dist - lens_fade_m) / max(lens_fade_m, 0.0001));
	// The weight: the vertex's facing toward the key (view space), heavy away from it, thin toward it.
	vec3 n_view = normalize((MODELVIEW_NORMAL_MATRIX * dir));
	float facing = dot(n_view, normalize(key_dir_view));
	float weight = mix(heavy_mult, thin_mult, smoothstep(key_range.x, key_range.y, facing));
	weight *= mix(1.0, far_thin, smoothstep(thin_start_m, max(thin_end_m, thin_start_m + 0.01), dist));
	// Wander along the contour, in the object's own space (the skinned vertex, so it follows the body).
	float seed = boil_seed * 7.13 + pass_id * 19.7;
	weight *= 1.0 + wander * (vnoise(VERTEX * wander_scale + vec3(pass_id * 3.7)) - 0.5) * 2.0;
	float width_m = width_px * fp_scale * width_scale * max(weight, 0.0) * 2.0 * clamp(dist, near_m, far_m) / (1080.0 * proj_scale) * fade;
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		width_m = 0.0;
	}
	VERTEX += dir * width_m;
	if (jitter_px > 0.0 && PROJECTION_MATRIX[3][3] == 0.0) {
		// A sideways redraw: a smooth noise of the vertex's object-space position, new at every boil seed.
		vec3 q = VERTEX * 2.3 + vec3(seed);
		vec3 off = vec3(vnoise(q) - 0.5, vnoise(q + vec3(11.3, 5.1, 2.9)) - 0.5, vnoise(q + vec3(7.7, 13.1, 3.3)) - 0.5) * 2.0;
		VERTEX += off * jitter_px * 2.0 * clamp(dist, near_m, far_m) / (1080.0 * proj_scale);
	}
}

void fragment() {
	ALBEDO = ink;
}
