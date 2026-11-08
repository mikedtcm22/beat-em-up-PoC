// The video's flat-paint environment, version 2 (LD-WORLD; docs/video/P1.md, PLAN.md section 4 part 7).
// The body that flat_paint_env.gdshader (the opaque material, every face but the chain-link's) and
// flat_paint_env_scissor.gdshader (the chain-link, with FLAT_PAINT_SCISSOR defined) share. A copy of
// game/fx/trim_body.gdshaderinc with the SAME uniform names, swapped onto the game's shared trim materials at
// runtime (ToonMaterials.trim().shader = ...), so the kit changes look without a game/ edit.
//
// What it does (every number is a uniform; the world look's .tres sets them):
//  - COARSE sheet and POSTERISED value (paint_lod, paint_bands): big shapes stay, brick and grime go.
//  - It BREAKS THE REGULARITY, in world space, so it never swims: the sheet's coordinates are domain-warped by a low
//    frequency noise (window rows and brick courses wobble); the facade's windows are blanked or lit by a world hash
//    (rows stop repeating); the brick shows only as a few painted dashes near the light's edges; the chain-link is
//    a simplified wobbling pattern with holes that fills in with distance.
//  - Its own light(): hard terminators broken by a brush noise, 2 or 3 bands, a shadow value of its own, and NOTHING
//    from a point or spot light outside its band: a lamp's pool is a hard, slightly broken graphic shape.
//  - A fine BRUSH GRAIN anchored in the face's metres and the world, never in the screen.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D trim_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 4.0;
uniform vec4 strips[16];
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ground_m = 8.0;
uniform bool ground_on = true;
uniform vec3 ink_soft = vec3(2.0, 0.12, 0.45);
uniform vec2 ink_fade = vec2(16.0, 64.0);
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float ink_cut : hint_range(0.05, 0.95) = 0.5;
uniform float lod_cap : hint_range(1.0, 7.0) = 4.0;
uniform float scissor_cut : hint_range(0.05, 0.95) = 0.35;
uniform float edge_tag : hint_range(0.0, 1.0) = 1.0;
uniform int debug_view : hint_range(0, 4) = 0;

// The toon uniforms the game writes (apply_look): kept so the names exist and a Tuning change does not complain.
uniform float band_1 : hint_range(0.0, 1.0) = 0.25;
uniform float band_2 : hint_range(0.0, 1.0) = 0.62;
uniform float band_soft : hint_range(0.0, 8.0) = 1.2;
uniform float mid_level : hint_range(0.0, 1.0) = 0.72;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.42;
uniform vec3 shadow_tint : source_color = vec3(0.36, 0.32, 0.55);
uniform float shadow_tint_amount : hint_range(0.0, 1.0) = 0.45;
uniform float spec_cut : hint_range(0.5, 1.0) = 0.99;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.5;
uniform float spec_gloss : hint_range(1.0, 8.0) = 1.0;
uniform float fill_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec3 fill_dir = vec3(-0.45, 0.55, 0.70);
uniform float rim_cut : hint_range(0.0, 1.0) = 0.7;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.0;
uniform float halftone_cell_px : hint_range(2.0, 24.0) = 6.0;

// The paint's own (the game never writes these).
uniform float paint_lod : hint_range(1.0, 7.0) = 3.2;
uniform float paint_bands : hint_range(2.0, 4.0) = 3.0;
uniform float paint_band_soft : hint_range(0.0, 1.0) = 0.05;
uniform vec3 paint_shadow_tint : source_color = vec3(0.2, 0.22, 0.48);
uniform float paint_shadow_level : hint_range(0.0, 1.0) = 0.5;
uniform float paint_mid_level : hint_range(0.0, 1.0) = 0.78;
uniform float paint_ink_keep : hint_range(0.0, 1.0) = 0.0;
uniform float paint_grain : hint_range(0.0, 0.6) = 0.16;
uniform vec2 paint_grain_scale = vec2(22.0, 5.0);
uniform float paint_break : hint_range(0.0, 0.5) = 0.18;
uniform vec2 paint_break_scale = vec2(5.0, 2.0);
uniform float paint_sat : hint_range(0.0, 1.0) = 1.0;
uniform float paint_value_gain : hint_range(0.5, 3.0) = 1.0;

// Version 2: the regularity breakers.
// The domain warp of the sheet's coordinates: amplitude in metres (0: none), and the noise's frequency in 1/m.
uniform float warp_m : hint_range(0.0, 1.0) = 0.0;
uniform vec2 warp_freq = vec2(0.22, 0.31);
// Each row of a strip (a floor of windows) slides sideways by a world-hashed amount up to this many metres, so the windows stop
// standing in columns. Seamless: the strip wraps in U.
uniform float row_jitter_m : hint_range(0.0, 3.0) = 0.0;
// The facade strip's windows (the strip named by facade_strip): the share blanked to wall, the share lit, and the lit colour.
uniform int facade_strip : hint_range(0, 15) = 15;
uniform float window_blank_p : hint_range(0.0, 1.0) = 0.0;
uniform float window_lit_p : hint_range(0.0, 1.0) = 0.0;
uniform vec3 window_lit_color : source_color = vec3(1.0, 0.7, 0.32);
uniform float window_lit_energy : hint_range(0.0, 4.0) = 1.0;
// The brick strip (index brick_strip) is flattened to its average colour when brick_flat is 1 (no courses, no mortar lines: they
// come back only as the painted dashes below).
uniform int brick_strip : hint_range(0, 15) = 0;
uniform float brick_flat : hint_range(0.0, 1.0) = 0.0;
// The brick strip's painted dashes: how much of the course shows (0: none), their darkness, and how near a light's edge they live.
uniform float brick_strokes : hint_range(0.0, 1.0) = 0.0;
uniform float brick_stroke_dark : hint_range(0.0, 1.0) = 0.3;
uniform float brick_edge_w : hint_range(0.01, 0.6) = 0.2;
// Point and spot lights: the pool's outer edge and core (in light units, like band_1 and band_2), and the share of the light
// the outer ring gives (the core gives all). The paint_break noise roughens both edges.
uniform float pool_edge : hint_range(0.0, 1.0) = 0.16;
uniform float pool_core : hint_range(0.0, 1.0) = 0.5;
uniform float pool_outer_level : hint_range(0.0, 1.0) = 0.55;
// The pool's gain: the lamp's light is brighter than the albedo's own value, so the lit ground reads as light, not as a tint.
// How much of paint_break roughens the pool's edges (the terminators of the sun keep all of it).
uniform float pool_break : hint_range(0.0, 1.0) = 0.35;
// The pool edge's noise is this share of paint_break_scale's frequency (big, calm shapes, not torn paper).
uniform float pool_break_freq : hint_range(0.05, 1.0) = 0.3;
// How much the pool's brightness ignores the surface's own value (0: the albedo multiplies the lamp, 1: the pool is the lamp's colour whatever
// the ground is): a dark asphalt still shows a bright sodium pool.
uniform float pool_norm : hint_range(0.0, 1.0) = 0.0;
uniform float pool_gain : hint_range(0.5, 4.0) = 1.0;
// A fine paint-in of the shadow side by the warm key: how much a directional light's lit band tints the albedo (0: none).
uniform float paint_lit_tint : hint_range(0.0, 1.0) = 0.0;
// The chain-link (the scissor variant): the cell in metres, the wire's width as a share of the cell, the share of holes.
uniform float chain_cell_m : hint_range(0.1, 1.5) = 0.45;
uniform float chain_wire : hint_range(0.02, 0.5) = 0.12;
uniform float chain_holes : hint_range(0.0, 0.8) = 0.2;

// Round 2 (LD-WORLD2): the drawn detail. Every line is a world- or face-anchored shape (metres), wobbled by a low frequency noise,
// weighted by a hash, never thinner than a pixel and faded out where its cell falls under a few pixels, so nothing swims or moires.
// draw_on is the master (0: round 1's flat paint). draw_ink_mul darkens the paint into the line colour.
uniform float draw_on : hint_range(0.0, 1.0) = 0.0;
uniform float draw_ink_mul : hint_range(0.05, 0.9) = 0.34;
uniform float draw_line_w : hint_range(0.002, 0.08) = 0.016;
uniform float draw_wobble_m : hint_range(0.0, 0.08) = 0.02;
uniform float draw_fade_lo : hint_range(0.02, 0.4) = 0.09;
uniform float draw_fade_hi : hint_range(0.04, 0.6) = 0.22;
// The sheet's own ink mask (cracks, manholes, grates, the joints and seams), read at a middle mip, as ink.
uniform float draw_sheet_ink : hint_range(0.0, 1.0) = 0.9;
uniform float draw_sheet_lod : hint_range(0.0, 6.0) = 2.0;
uniform float draw_sheet_cut : hint_range(0.05, 0.9) = 0.3;
// Brick (the brick strip and the facade's wall): the course's height and a brick's length (m), the share of lines that stay, and the value steps.
uniform float brick_course_m : hint_range(0.05, 0.6) = 0.2;
uniform float brick_len_m : hint_range(0.1, 1.5) = 0.46;
uniform float brick_keep : hint_range(0.0, 1.0) = 0.8;
uniform float brick_var : hint_range(0.0, 0.5) = 0.16;
// The wall's base: below this height (m) the wall is darker and its lines heavier (the path reads against it).
uniform float base_h_m : hint_range(0.0, 4.0) = 1.3;
uniform float base_dark : hint_range(0.0, 0.8) = 0.3;
// Cracks: the share of the wall they cover (0: none) and their width (m).
uniform float crack_p : hint_range(0.0, 1.0) = 0.25;
uniform float crack_w : hint_range(0.002, 0.05) = 0.012;
// Drain pipes on the brick walls: a world-hashed column every `pipe_every_m`, with this share of columns having one.
uniform float pipe_p : hint_range(0.0, 1.0) = 0.0;
uniform float pipe_every_m : hint_range(2.0, 12.0) = 5.0;
// Windows: the frame and lintel's width (m), the sill's depth (m), the share of panes with a lighter reflection, the cross's bar.
uniform float win_frame_m : hint_range(0.0, 0.2) = 0.05;
uniform float win_lintel_m : hint_range(0.0, 0.5) = 0.16;
uniform float win_sill_m : hint_range(0.0, 0.5) = 0.14;
uniform float win_refl_p : hint_range(0.0, 1.0) = 0.5;
uniform float win_cross : hint_range(0.0, 1.0) = 0.7;
// The ground: flagstone size (m), how many joints stay, the value steps of the slabs, the puddles' cover and size, the pavement's contrast.
uniform vec2 slab_m = vec2(1.3, 0.8);
uniform float slab_keep : hint_range(0.0, 1.0) = 0.7;
uniform float slab_var : hint_range(0.0, 0.5) = 0.2;
uniform float puddle_p : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_scale : hint_range(0.05, 1.0) = 0.22;
uniform vec3 puddle_color : source_color = vec3(0.3, 0.4, 0.7);
uniform float puddle_level : hint_range(0.0, 3.0) = 1.4;
uniform float ground_gain : hint_range(0.3, 3.0) = 1.0;
// The other strips' patterns: plank / slat / panel width (m).
uniform float plank_m : hint_range(0.05, 0.6) = 0.22;
// pool_norm for the faces that do not face up (the walls): 0 keeps a wall's own value under a lamp, so its drawn lines stay.
uniform float pool_norm_wall : hint_range(0.0, 1.0) = 0.0;

varying vec2 face_m;
varying vec2 world_m;
varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 tint;
varying float strip_id;
varying float base_luma;

void vertex() {
	face_m = UV;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_m = wp.xz;
	world_pos = wp;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
	strip_id = COLOR.a * 255.0;
}

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Brush strokes: value noise stretched by `scale` over two octaves, in the face's own metres, mixed with the
// world position so two faces never repeat each other. 0..1.
float strokes(vec2 face, vec3 wp, vec2 scale) {
	vec2 q = face * scale + vec2(wp.x + wp.z, wp.y) * 0.37;
	return 0.65 * vnoise2(q) + 0.35 * vnoise2(q * 2.3 + 17.0);
}

float band_step(float x, float edge) {
	return smoothstep(-edge, edge, x);
}

// The low frequency world-space warp, in metres, applied to a face's coordinates.
vec2 world_warp() {
	vec3 p = world_pos * warp_freq.x;
	vec2 w = vec2(vnoise3(p), vnoise3(p + vec3(41.3, 17.1, 7.7))) - 0.5;
	vec3 q = world_pos * warp_freq.y;
	w += 0.5 * (vec2(vnoise3(q + vec3(5.2, 1.3, 9.1)), vnoise3(q + vec3(23.7, 3.3, 11.9))) - 0.5);
	return w * 2.0 * warp_m;
}


// ---- Round 2: the drawn detail ----
// A line `w` metres wide (never under ~one pixel) at distance `d` metres from its centre; `mpp` is the metres one pixel covers.
float dline(float d, float w, float mpp) {
	float ww = max(w, mpp * 0.9);
	return 1.0 - smoothstep(ww - mpp * 0.5, ww + mpp * 0.5, d);
}

// Cells of `cell_m` metres fade out as they fall under a few pixels: 1 near, 0 far.
float dfade(float cell_m, float mpp) {
	return 1.0 - smoothstep(draw_fade_lo, draw_fade_hi, mpp / cell_m);
}

float wob(vec2 p, float amount_m) {
	return (vnoise2(p) - 0.5) * 2.0 * amount_m;
}

// Distance (m) from x to the nearest multiple of `step_m`.
float rep_dist(float x, float step_m) {
	float f = fract(x / step_m);
	return min(f, 1.0 - f) * step_m;
}

// Drawn brick at (u, v) metres on a face: returns the line mask (x) and the brick's value step (y, -1..1). Courses stagger; some joints drop out.
vec2 draw_brick(vec2 uv, vec2 key, float mpp, float weight, float ch, float bl, float keep_p) {
	float v = uv.y + wob(uv * vec2(3.0, 0.0) + key, draw_wobble_m);
	float cy = floor(v / ch);
	float hc = hash12(vec2(cy, key.x * 0.37 + 3.0));
	float u = uv.x + (mod(cy, 2.0) * 0.5 + (hc - 0.5) * 0.3) * bl + wob(vec2(v * 4.0, cy), draw_wobble_m);
	float bx = floor(u / bl);
	float hb = hash12(vec2(bx, cy + key.x * 1.7));
	float seg = floor(u / (bl * 3.0));
	float h_seg = hash12(vec2(seg + key.y, cy * 1.3 + key.x));
	float keep_h = step(h_seg, keep_p + 0.12);
	float w = draw_line_w * (0.55 + 0.9 * hash12(vec2(cy, seg + 5.0))) * weight;
	float horiz = dline(rep_dist(v, ch), w, mpp) * keep_h;
	float vert = dline(rep_dist(u, bl), w * 0.8, mpp) * step(hb, keep_p + 0.05);
	float line = max(horiz, vert) * dfade(ch, mpp);
	float step_v = floor(hb * 3.0) - 1.0;
	step_v *= step(0.35, hb) ;
	return vec2(line, step_v);
}

// A ridged-noise crack: a thin wandering line, sparse.
float draw_crack(vec2 uv, vec2 key, float mpp) {
	vec2 q = uv * 0.9 + key;
	float gate = smoothstep(1.0 - crack_p * 0.6, 1.0 - crack_p * 0.6 + 0.12, vnoise2(q * 0.35 + 9.0));
	float r = abs(vnoise2(q + vec2(vnoise2(q * 1.7), 0.0) * 1.4) - 0.5);
	float w = crack_w * (0.6 + vnoise2(q * 3.0));
	return dline(r * 0.5, w, mpp) * gate * dfade(0.3, mpp);
}

float glass_at(vec2 uvp, vec2 gx, vec2 gy) {
	vec3 g = textureGrad(trim_tex, uvp, gx, gy).rgb;
	return smoothstep(0.015, 0.045, g.b - g.r) * (1.0 - smoothstep(0.3, 0.45, dot(g, LUMA)));
}

void fragment() {
	vec4 row = strips[clamp(int(strip_id + 0.5), 0, 15)];
	int sid = int(strip_id + 0.5);
	bool ground = ground_on && row.w > 3.5;
	vec2 warp = world_warp();
	vec2 fm = face_m + (ground ? vec2(0.0) : warp);
	float mpp_face = max(length(dFdx(face_m)), length(dFdy(face_m)));
	float mpp_world = max(length(dFdx(world_m)), length(dFdy(world_m)));
	float mpp = ground ? mpp_world : mpp_face;
	float sheet_a = 0.0;
	float glass_m = 0.0;
	float win_frame = 0.0;
	float win_surround = 0.0;
	float win_sill = 0.0;
	vec2 t = vec2(fm.x / tile_m, fm.y / max(row.z, 0.01));
	if (!ground && row_jitter_m > 0.0) {
		float plane_j = round(dot(abs(world_normal), world_pos) * 2.0);
		t.x += (hash12(vec2(floor(t.y), plane_j * 1.3 + 11.0)) - 0.5) * 2.0 * row_jitter_m / tile_m;
	}
	vec2 uv = vec2(t.x, row.x + (1.0 - fract(t.y)) * row.y);
	vec2 gx = dFdx(t) * vec2(1.0, -row.y);
	vec2 gy = dFdy(t) * vec2(1.0, -row.y);
	vec2 gt = vec2(world_m.x, -world_m.y) / ground_m + (ground ? warp / ground_m : vec2(0.0));
	vec2 gtm = vec2(gt.x, abs(mod(gt.y, 2.0) - 1.0));
	vec2 fold = vec2(1.0, sign(mod(gt.y, 2.0) - 1.0));
	vec2 ggx = dFdx(gt) * fold;
	vec2 ggy = dFdy(gt) * fold;
	vec4 c;
	vec3 emit = vec3(0.0);
	if (ground) {
		float texels = max(length(ggx), length(ggy)) * float(textureSize(ground_tex, 0).x);
		float keep = max(1.0, exp2(paint_lod + 1.0) / max(texels, 0.0001));
		c = textureGrad(ground_tex, gtm, ggx * keep, ggy * keep);
		float keep_i = max(1.0, exp2(draw_sheet_lod + 1.0) / max(texels, 0.0001));
		sheet_a = textureGrad(ground_tex, gtm, ggx * keep_i, ggy * keep_i).a;
	} else {
#ifdef FLAT_PAINT_PROP
		// A prop (a lamp post, a barrel): a flat colour, painted by the same light.
		c = vec4(1.0, 1.0, 1.0, 0.0);
		vec2 gx = vec2(0.0);
		vec2 gy = vec2(0.0);
		float keep = 1.0;
#else
		float sheet = float(textureSize(trim_tex, 0).x);
		float texels = max(length(gx), length(gy)) * sheet;
		float keep = max(1.0, exp2(paint_lod) / max(texels, 0.0001));
		c = textureGrad(trim_tex, uv, gx * keep, gy * keep);
		float keep_i = max(1.0, exp2(draw_sheet_lod) / max(texels, 0.0001));
		sheet_a = textureGrad(trim_tex, uv, gx * keep_i, gy * keep_i).a;
#endif
		if (sid == brick_strip && brick_flat > 0.0) {
			vec3 avg = vec3(0.0);
			for (int i = 0; i < 4; i++) {
				for (int j = 0; j < 2; j++) {
					avg += textureLod(trim_tex, vec2(0.125 + 0.25 * float(i), row.x + row.y * (0.25 + 0.5 * float(j))), 3.5).rgb;
				}
			}
			c.rgb = mix(c.rgb, avg / 8.0, brick_flat);
		}
		if (sid == facade_strip && (window_blank_p > 0.0 || window_lit_p > 0.0 || draw_on > 0.0)) {
			// A window is the sheet's bluish dark rectangle. Each of the two windows a tile is one cell: a world hash
			// decides whether it is kept, blanked to the wall's own colour, or lit from inside.
			float glass = smoothstep(0.015, 0.045, c.b - c.r) * (1.0 - smoothstep(0.3, 0.45, dot(c.rgb, LUMA)));
			float plane = round(dot(abs(world_normal), world_pos) * 2.0);
			vec2 cell = vec2(floor(t.x * 2.0) + floor(t.y) * 5.0, plane);
			float h = hash12(cell * vec2(1.0, 0.37) + vec2(3.1, 7.7));
			vec4 wall = textureGrad(trim_tex, vec2(uv.x, row.x + row.y * 0.06), gx * keep, gy * keep);
			if (draw_on > 0.0) {
				// The window drawn: the frame (ink) round the glass, the lintel and the jambs (a lighter band), the sill below (a lighter slab).
				vec2 ou = vec2(1.0 / tile_m, row.y / max(row.z, 0.01));
				vec2 gxk = gx * keep;
				vec2 gyk = gy * keep;
				glass_m = glass;
				if (glass < 0.5) {
					float fr = win_frame_m;
					float near = 0.0;
					near = max(near, glass_at(uv + vec2(ou.x * fr, 0.0), gxk, gyk));
					near = max(near, glass_at(uv - vec2(ou.x * fr, 0.0), gxk, gyk));
					near = max(near, glass_at(uv + vec2(0.0, ou.y * fr), gxk, gyk));
					near = max(near, glass_at(uv - vec2(0.0, ou.y * fr), gxk, gyk));
					win_frame = step(0.5, near);
					float lt = win_lintel_m;
					float sur = 0.0;
					sur = max(sur, glass_at(uv + vec2(ou.x * lt, 0.0), gxk, gyk));
					sur = max(sur, glass_at(uv - vec2(ou.x * lt, 0.0), gxk, gyk));
					sur = max(sur, glass_at(uv + vec2(0.0, ou.y * lt), gxk, gyk));
					sur = max(sur, glass_at(uv + vec2(ou.x * lt * 0.7, ou.y * lt * 0.7), gxk, gyk));
					sur = max(sur, glass_at(uv + vec2(-ou.x * lt * 0.7, ou.y * lt * 0.7), gxk, gyk));
					win_surround = step(0.5, sur) * (1.0 - win_frame);
					float sl = win_sill_m;
					float sil = 0.0;
					sil = max(sil, glass_at(uv + vec2(0.0, -ou.y * sl * 0.6), gxk, gyk));
					sil = max(sil, glass_at(uv + vec2(0.0, -ou.y * sl), gxk, gyk));
					sil = max(sil, glass_at(uv + vec2(ou.x * 0.1, -ou.y * sl), gxk, gyk));
					sil = max(sil, glass_at(uv + vec2(-ou.x * 0.1, -ou.y * sl), gxk, gyk));
					win_sill = step(0.5, sil) * (1.0 - win_frame);
				}
			}
			if (h < window_blank_p) {
				c.rgb = mix(c.rgb, wall.rgb, glass);
			} else if (h < window_blank_p + window_lit_p) {
				emit = window_lit_color * window_lit_energy * glass;
			}
			// Brick behind the window's neighbours: the wall around the frame is the wall (flat), drawn below.
		}
	}
	vec3 color = c.rgb;
	color = mix(color, ink, smoothstep(ink_cut - 0.1, ink_cut + 0.1, c.a) * paint_ink_keep);

	float luma = max(dot(color, LUMA), 0.0001);
	float lv = clamp(luma * paint_value_gain, 0.0, 1.0);
	float nb = paint_bands;
	float q = lv * nb;
	float fq = floor(q);
	float soft = max(paint_band_soft, 0.0001);
	float stepped = (fq + smoothstep(0.5 - soft, 0.5 + soft, fract(q))) / nb;
	float target = (stepped * nb + 0.5) / (nb + 1.0);
	vec3 hue = color / luma;
	vec3 flat_color = hue * target;
	flat_color = mix(vec3(dot(flat_color, LUMA)), flat_color, paint_sat);
	flat_color = clamp(flat_color, 0.0, 1.5);

	float g = strokes(face_m, world_pos, paint_grain_scale);
	flat_color *= 1.0 + (g - 0.5) * 2.0 * paint_grain;

	base_luma = max(dot(flat_color, LUMA), 0.05);
	if (draw_on > 0.0) {
		vec3 ink_c = mix(flat_color * draw_ink_mul, ink, 0.25);
		vec2 key = vec2(round(dot(abs(world_normal), world_pos) * 2.0), float(sid) * 1.37);
		float lines = 0.0;
		float vstep = 0.0;
		float wall_weight = 1.0;
		if (ground) {
			vec2 wxz = vec2(world_m.x, -world_m.y) + warp * 0.6;
			vec2 sb = draw_brick(wxz, key, mpp, 1.8, slab_m.y, slab_m.x, slab_keep);
			lines = sb.x;
			vstep = sb.y * slab_var;
			// Puddles: low frequency blobs with a hard edge, a lighter bluish fill, an inked rim.
			if (puddle_p > 0.0) {
				float pn = vnoise2(wxz * puddle_scale + 3.7) * 0.7 + vnoise2(wxz * puddle_scale * 2.9 + 11.0) * 0.3;
				float thr = 1.0 - puddle_p;
				float inside = smoothstep(thr, thr + mpp * 1.5 * puddle_scale, pn);
				float rim = smoothstep(thr - mpp * 3.0 * puddle_scale, thr, pn) * (1.0 - inside);
				vec3 pud = normalize(puddle_color + 0.001) * dot(flat_color, LUMA) * puddle_level * 1.7;
				flat_color = mix(flat_color, pud, inside * dfade(0.6, mpp));
				lines = max(lines, rim * 0.9);
			}
			lines = max(lines, step(draw_sheet_cut, sheet_a) * draw_sheet_ink);
			flat_color *= ground_gain;
		} else {
			float up = world_normal.y;
			bool wall = abs(up) < 0.6;
			float base_t = wall ? 1.0 - smoothstep(base_h_m * 0.8, base_h_m * 1.15, face_m.y + wob(face_m * 2.0 + 5.0, 0.12)) : 0.0;
			wall_weight = 1.0 + 0.6 * base_t;
			flat_color *= 1.0 - base_dark * base_t;
			bool brick_like = sid == brick_strip || (sid == facade_strip && glass_m < 0.5 && win_frame < 0.5 && win_surround < 0.5 && win_sill < 0.5);
			if (brick_like) {
				vec2 br = draw_brick(fm, key, mpp, wall_weight, brick_course_m, brick_len_m, brick_keep);
				lines = br.x;
				vstep = br.y * brick_var;
				if (pipe_p > 0.0 && wall) {
					float run = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
					float cellp = floor(run / pipe_every_m);
					float hp = hash12(vec2(cellp, key.x));
					float px = (cellp + 0.15 + 0.7 * hash12(vec2(cellp, 31.0))) * pipe_every_m + wob(vec2(face_m.y * 0.5, cellp), 0.02);
					float d = abs(run - px);
					float pipe_on = step(hp, pipe_p);
					float pipe_w = 0.075;
					float pipe_line = dline(abs(d - pipe_w), draw_line_w * 0.9, mpp) * pipe_on;
					float pipe_body = (1.0 - step(pipe_w, d)) * pipe_on;
					// A clamp every 1.1 m.
					float clamp_d = rep_dist(face_m.y + hp * 3.0, 1.1);
					float clamp_on = dline(clamp_d, 0.025, mpp) * (1.0 - step(pipe_w * 1.6, d)) * pipe_on;
					flat_color = mix(flat_color, flat_color * 1.35, pipe_body);
					lines = max(lines, max(pipe_line, clamp_on) * dfade(0.3, mpp));
				}
			} else if (sid == 2 || sid == 1) {
				// Concrete and plaster: panel joints and a stain.
				vec2 pb = draw_brick(fm, key, mpp, wall_weight, sid == 2 ? 1.0 : 1.4, 1.7, 0.7);
				lines = pb.x * 0.9;
				vstep = pb.y * brick_var * 0.5;
			} else if (sid == 4) {
				float j = dline(rep_dist(fm.x, 0.9), draw_line_w, mpp) * dfade(0.9, mpp);
				lines = j;
			} else if (sid == 5 || sid == 6) {
				float seam = dline(rep_dist(fm.x + wob(fm * 2.0, 0.03), 1.2), draw_line_w, mpp);
				float speck = step(0.93, hash12(floor(fm / max(mpp * 2.5, 0.04)) + key)) * dfade(0.15, mpp);
				lines = max(seam * dfade(1.2, mpp), speck * 0.7);
			} else if (sid == 7) {
				float seam = max(dline(rep_dist(fm.x, plank_m * 2.2), draw_line_w, mpp), dline(rep_dist(fm.y, plank_m * 3.0), draw_line_w, mpp));
				vec2 rv = vec2(rep_dist(fm.x, plank_m * 2.2) - plank_m * 0.25, rep_dist(fm.y, plank_m * 3.0) - plank_m * 0.3);
				float rivet = dline(length(rv), 0.014, mpp);
				lines = max(seam * dfade(plank_m, mpp), rivet * dfade(0.2, mpp));
			} else if (sid == 8) {
				lines = dline(rep_dist(fm.y, plank_m * 0.5), draw_line_w, mpp) * dfade(plank_m * 0.5, mpp);
			} else if (sid == 10) {
				float pk = dline(rep_dist(fm.x, plank_m), draw_line_w, mpp);
				float diag = dline(abs(fract((fm.x + fm.y) / 1.0) - 0.5) * 0.7, draw_line_w * 1.4, mpp);
				lines = max(pk, diag * 0.8) * dfade(plank_m, mpp);
				vstep = (hash12(vec2(floor(fm.x / plank_m), key.x)) - 0.5) * brick_var * 2.0;
			} else if (sid == 11) {
				lines = dline(rep_dist(fm.y, 0.25), draw_line_w * 1.3, mpp) * dfade(0.25, mpp);
			}
			if (crack_p > 0.0 && sid != 13 && sid != 12 && glass_m < 0.5) {
				lines = max(lines, draw_crack(fm, key, mpp));
			}
			lines = max(lines, step(draw_sheet_cut, sheet_a) * draw_sheet_ink * dfade(0.25, mpp));
			// The window: a frame of ink, a lighter surround and sill, the glass with a streak and a cross.
			if (glass_m > 0.5) {
				flat_color *= 0.8;
				float refl_on = step(hash12(vec2(floor(face_m.x / 1.6), key.x + floor(face_m.y / 1.4))), win_refl_p);
				float sv = fm.x + fm.y * 0.7;
				float streak = (1.0 - step(0.12, abs(fract(sv * 0.9) - 0.3))) + (1.0 - step(0.04, abs(fract(sv * 0.9) - 0.5)));
				flat_color *= 1.0 + 0.55 * min(streak, 1.0) * refl_on * dfade(0.3, mpp);
				float cross_x = rep_dist(t.x * 2.0 - 0.5, 1.0) * (tile_m * 0.5);
				lines = max(lines, dline(cross_x, 0.02, mpp) * win_cross * dfade(0.6, mpp));
			}
			flat_color *= 1.0 + 0.0;
			flat_color = mix(flat_color, flat_color * 1.32, win_surround);
			flat_color = mix(flat_color, flat_color * 1.45, win_sill);
			lines = max(lines, win_frame);
		}
		flat_color *= 1.0 + vstep;
		flat_color = mix(flat_color, ink_c, clamp(lines, 0.0, 1.0) * draw_on);
	}

	if (debug_view == 1) {
		flat_color = vec3(strip_id / 15.0);
	}
	ALBEDO = flat_color * albedo.rgb * tint;
	EMISSION = emit;
	ROUGHNESS = edge_tag;
#ifdef FLAT_PAINT_SCISSOR
	// The chain-link: a wobbling diamond lattice of few, thick wires with holes; the wire's width grows with the
	// pixel's footprint, so far away it is a flat silhouette rather than a moire.
	vec2 qc = (face_m + warp * 1.6) / chain_cell_m;
	vec2 dq = abs(fract(vec2(qc.x + qc.y, qc.x - qc.y)) - 0.5);
	float foot = max(length(dFdx(qc)), length(dFdy(qc)));
	float wire = max(chain_wire, foot * 1.1);
	float on_wire = 1.0 - step(wire, min(dq.x, dq.y) * 2.0);
	float planec = round(dot(abs(world_normal), world_pos) * 2.0);
	float hole = step(chain_holes, hash12(floor(qc * 0.5) + planec * 1.7));
	float fill = smoothstep(0.5, 0.9, foot);
	float keep_px = max(on_wire * hole, fill * 0.85 * hole);
	ALPHA = keep_px;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = mix(ALBEDO, ink * 2.0, 0.6);
#endif
}

// A painted light: two or three value bands with a terminator broken by brush noise, a shadow of its own, and no
// highlight. A directional light (the moon, the sun) owns the whole surface; a point or spot light gives a pool: nothing
// outside its edge, a dimmer ring and a bright core inside, both edges roughened.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;
	float n = strokes(face_m, world_pos, paint_break_scale) - 0.5;
	float to_pixels = VIEWPORT_SIZE.y / 1080.0;
	vec3 light_color = min(LIGHT_COLOR / PI, vec3(1.0));
	if (LIGHT_IS_DIRECTIONAL) {
		lit += n * 2.0 * paint_break;
		float edge = clamp(0.5 * band_soft * to_pixels * fwidth(lit), 0.0005, 0.06);
		float b1 = band_step(lit - band_1, edge);
		float b2 = band_step(lit - band_2, edge);
		vec3 tint_n = paint_shadow_tint / max(dot(paint_shadow_tint, LUMA), 0.001);
		vec3 shadow = paint_shadow_level * mix(vec3(1.0), tint_n, 0.55);
		vec3 shade = mix(mix(shadow, vec3(paint_mid_level), b1), vec3(1.0), b2);
		DIFFUSE_LIGHT += shade * light_color;
	} else {
		float np = strokes(face_m, world_pos, paint_break_scale * pool_break_freq) - 0.5;
		lit += np * 2.0 * paint_break * pool_break;
		float edge = clamp(0.5 * band_soft * to_pixels * fwidth(lit), 0.0005, 0.05);
		float outer = band_step(lit - pool_edge, edge);
		float core = band_step(lit - pool_core, edge);
		float level = mix(pool_outer_level * outer, 1.0, core);
		// Dashes of brick, only just inside the pool's edge: where the light shows the wall's makeup, never in flat shade.
		if (brick_strokes > 0.0 && int(strip_id + 0.5) == 0) {
			vec2 cell = vec2(floor(face_m.x / 0.5), floor(face_m.y / 0.25));
			float h = hash12(cell + vec2(world_pos.y * 0.0, floor(dot(abs(world_normal), world_pos) * 2.0)));
			float dash = step(1.0 - brick_strokes, h);
			float along = fract(face_m.x / 0.5);
			float dash_mask = dash * smoothstep(0.08, 0.14, along) * (1.0 - smoothstep(0.55 + 0.35 * h, 0.7 + 0.3 * h, along));
			dash_mask *= smoothstep(0.08, 0.14, fract(face_m.y / 0.25)) * (1.0 - smoothstep(0.35, 0.5, fract(face_m.y / 0.25)));
			float near_edge = exp(-pow((lit - pool_edge) / brick_edge_w, 2.0));
			level *= 1.0 - brick_stroke_dark * dash_mask * near_edge;
		}
		float pn_amount = world_normal.y > 0.6 ? pool_norm : pool_norm_wall;
		float norm = mix(1.0, 1.0 / max(base_luma * dot(albedo.rgb * tint, LUMA), 0.08), pn_amount);
		DIFFUSE_LIGHT += level * light_color * pool_gain * norm;
	}
}
