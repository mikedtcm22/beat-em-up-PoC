shader_type spatial;
// The video's flat-paint environment (Phase 0 spike, PLAN.md section 4, Plan A part 7): a copy of
// game/fx/trim.gdshader and trim_body.gdshaderinc with the SAME uniform names, swapped onto the
// shared trim material at runtime (ToonMaterials.trim().shader = this), so the kit's modules and the
// street's ground change look without a game/ edit.
//
// What it changes:
//  - The sheet is read at a COARSE mip (paint_lod): the big shapes (windows, doors, shutters) stay and
//    the brick and grime detail goes. The sheet's ink alpha (cracks, seams) is dropped, or kept by
//    paint_ink_keep; the screen-space ink pass carries the major lines.
//  - The value is POSTERISED into paint_bands bands per material (hue kept), the shape of a painted fill.
//  - Its own light(): a hard terminator that is slightly BROKEN like a painted edge (the light term is
//    shifted by a stroke noise before the step), 2 to 3 value bands, a navy-violet shadow of its own.
//  - A fine BRUSH GRAIN, anchored in the face's own metre coordinates (face_m) and the world position,
//    never in screen space, so it does not swim when the camera moves.
// The toon uniforms apply_look() writes (band_*, shadow_*, rim_*...) are kept as declared so a Tuning
// change does not complain; the paint_* ones are this shader's and are never rewritten by the game.

render_mode ambient_light_disabled;

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

// The toon uniforms the game writes (unused here, kept so the names exist).
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

// This shader's own (the game never writes these).
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

varying vec2 face_m;
varying vec2 world_m;
varying vec3 world_pos;
varying vec3 tint;
varying float strip_id;

void vertex() {
	face_m = UV;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_m = wp.xz;
	world_pos = wp;
	tint = COLOR.rgb;
	strip_id = COLOR.a * 255.0;
}

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
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

void fragment() {
	vec4 row = strips[clamp(int(strip_id + 0.5), 0, 15)];
	bool ground = ground_on && row.w > 3.5;
	vec2 t = vec2(face_m.x / tile_m, face_m.y / max(row.z, 0.01));
	vec2 uv = vec2(t.x, row.x + (1.0 - fract(t.y)) * row.y);
	vec2 gx = dFdx(t) * vec2(1.0, -row.y);
	vec2 gy = dFdy(t) * vec2(1.0, -row.y);
	vec2 gt = vec2(world_m.x, -world_m.y) / ground_m;
	vec2 gtm = vec2(gt.x, abs(mod(gt.y, 2.0) - 1.0));
	vec2 fold = vec2(1.0, sign(mod(gt.y, 2.0) - 1.0));
	vec2 ggx = dFdx(gt) * fold;
	vec2 ggy = dFdy(gt) * fold;
	vec4 c;
	if (ground) {
		// Coarse: force the lod by scaling the gradients up to the wanted level.
		float texels = max(length(ggx), length(ggy)) * float(textureSize(ground_tex, 0).x);
		float keep = max(1.0, exp2(paint_lod + 1.0) / max(texels, 0.0001));
		c = textureGrad(ground_tex, gtm, ggx * keep, ggy * keep);
	} else {
		float sheet = float(textureSize(trim_tex, 0).x);
		float texels = max(length(gx), length(gy)) * sheet;
		float keep = max(1.0, exp2(paint_lod) / max(texels, 0.0001));
		c = textureGrad(trim_tex, uv, gx * keep, gy * keep);
	}
	vec3 color = c.rgb;
	// The sheet's ink alpha, mostly dropped.
	color = mix(color, ink, smoothstep(ink_cut - 0.1, ink_cut + 0.1, c.a) * paint_ink_keep);

	// Posterise the value into bands, keeping the hue.
	float luma = max(dot(color, LUMA), 0.0001);
	float lv = clamp(luma * paint_value_gain, 0.0, 1.0);
	float nb = paint_bands;
	float q = lv * nb;
	float fq = floor(q);
	float soft = max(paint_band_soft, 0.0001);
	float stepped = (fq + smoothstep(0.5 - soft, 0.5 + soft, fract(q))) / nb;
	// Keep the band's centre lightness, so a flat fill is a few flat colours.
	float target = (stepped * nb + 0.5) / (nb + 1.0);
	vec3 hue = color / luma;
	vec3 flat_color = hue * target;
	flat_color = mix(vec3(dot(flat_color, LUMA)), flat_color, paint_sat);
	flat_color = clamp(flat_color, 0.0, 1.5);

	// Brush grain on the fill, anchored in the face and the world.
	float g = strokes(face_m, world_pos, paint_grain_scale);
	flat_color *= 1.0 + (g - 0.5) * 2.0 * paint_grain;

	if (debug_view == 1) {
		flat_color = vec3(strip_id / 15.0);
	}
	ALBEDO = flat_color * albedo.rgb * tint;
	ROUGHNESS = edge_tag;
}

// A painted light: two or three value bands with a terminator that is broken by brush noise, a shadow
// of its own hue, and no highlight.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;
	// The painted break: the light term is shifted by a stroke noise (anchored in face and world).
	float n = strokes(face_m, world_pos, paint_break_scale) - 0.5;
	lit += n * 2.0 * paint_break;
	float to_pixels = VIEWPORT_SIZE.y / 1080.0;
	float edge = clamp(0.5 * band_soft * to_pixels * fwidth(lit), 0.0005, 0.06);
	float b1 = band_step(lit - band_1, edge);
	float b2 = band_step(lit - band_2, edge);
	vec3 tint_n = paint_shadow_tint / max(dot(paint_shadow_tint, LUMA), 0.001);
	// A point light adds its shadow value only where it reaches (the moon, the directional light, owns the
	// shadow side): otherwise every lamp would flood its whole range with a shadow-level glow.
	vec3 shadow = LIGHT_IS_DIRECTIONAL ? paint_shadow_level * mix(vec3(1.0), tint_n, 0.55) : vec3(0.0);
	vec3 shade = mix(mix(shadow, vec3(paint_mid_level), b1), vec3(1.0), b2);
	vec3 light_color = min(LIGHT_COLOR / PI, vec3(1.0));
	DIFFUSE_LIGHT += shade * light_color;
}
