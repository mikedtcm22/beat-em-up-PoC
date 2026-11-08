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

varying vec2 face_m;
varying vec2 world_m;
varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 tint;
varying float strip_id;

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

void fragment() {
	vec4 row = strips[clamp(int(strip_id + 0.5), 0, 15)];
	int sid = int(strip_id + 0.5);
	bool ground = ground_on && row.w > 3.5;
	vec2 warp = world_warp();
	vec2 fm = face_m + (ground ? vec2(0.0) : warp);
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
		if (sid == facade_strip && (window_blank_p > 0.0 || window_lit_p > 0.0)) {
			// A window is the sheet's bluish dark rectangle. Each of the two windows a tile is one cell: a world hash
			// decides whether it is kept, blanked to the wall's own colour, or lit from inside.
			float glass = smoothstep(0.015, 0.045, c.b - c.r) * (1.0 - smoothstep(0.3, 0.45, dot(c.rgb, LUMA)));
			float plane = round(dot(abs(world_normal), world_pos) * 2.0);
			vec2 cell = vec2(floor(t.x * 2.0) + floor(t.y) * 5.0, plane);
			float h = hash12(cell * vec2(1.0, 0.37) + vec2(3.1, 7.7));
			vec4 wall = textureGrad(trim_tex, vec2(uv.x, row.x + row.y * 0.06), gx * keep, gy * keep);
			if (h < window_blank_p) {
				c.rgb = mix(c.rgb, wall.rgb, glass);
			} else if (h < window_blank_p + window_lit_p) {
				emit = window_lit_color * window_lit_energy * glass;
			}
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
		float norm = mix(1.0, 1.0 / max(dot(ALBEDO, LUMA), 0.08), pool_norm);
		DIFFUSE_LIGHT += level * light_color * pool_gain * norm;
	}
}
