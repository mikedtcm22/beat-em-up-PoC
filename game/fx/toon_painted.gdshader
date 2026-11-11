shader_type spatial;
// The painted character material (Milestone 7, T11; docs/ARCHITECTURE.md "The painted material (M7)"): the trailer profile's
// surface language for a character whose art ships its own paint. Ported from the video session's cine_toon.gdshader
// (video/cinematic-trailer: its paint_tex / ink_tex path and its designed terminator), cut down to what the game needs:
//  - paint_tex (RGB, UV2) is the surface: the flat local colour with the shadow shapes drawn in. No palette atlas.
//  - ink_tex (UV2): R = line (cut at paint_line_cut with a one-pixel edge, so it stays crisp), G = the damage class and
//    B = the gloss, both read at texel precision (class bytes 255 clothes, 230 clothes without blood, 204 skin, 128 none,
//    as the palette atlas's alpha has them; B at or above 0.5 is glossy, and its value is the glint gate), A = the hull's
//    line weight hint (toon_outline_painted.gdshader reads it).
//  - Two flat tones: the paint, and a shadow tone (the paint darkened and pulled toward the AREA's hue, never black),
//    cut at paint_cut with a clean edge at least term_soft pixels wide.
//  - A lamp (a point or spot light) adds only what rises above the shadow tone: nothing inside the shadow band, so a night
//    street's lamps do not flood the figures (the video's P1: the toon light() floods a night scene). A directional
//    light carries the shadow tone itself, at no less than dir_floor of a full light, in its hue.
//  - A one-sided rim, in the area's warm colour, on the side the directional (key) light comes from, its width narrowed
//    where the surface curves fast (screen-space change of the normal) and widened where the key faces it: no noise.
//  - A little grain on flat fills, in the rest-pose position, so it sticks to the body and never touches a drawn line.
// Every uniform the game writes to the art's toon material by name (the flash, the damage look, the edge tag, the ink, the
// fill and the hard highlight's) keeps its name and type, so RigPaint, DamageLook and ToonMaterials.apply_look need no
// second path; everything else here is a uniform too, so a flip of profile, an area or a damage look never compiles a
// shader variant mid-fight.
render_mode ambient_light_disabled;

#include "res://game/fx/paint_grain.gdshaderinc"

// --- the paint and the ink ---
uniform sampler2D paint_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D ink_tex : filter_linear_mipmap, repeat_disable;
// A flat tint over the paint (white: none). A palette swap (the veteran's vest) is this.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float paint_line_cut : hint_range(0.05, 0.95) = 0.3;
uniform float paint_line_strength : hint_range(0.0, 1.0) = 1.0;
uniform float paint_grain : hint_range(0.0, 0.3) = 0.07;
uniform float paint_grain_cells : hint_range(10.0, 400.0) = 140.0;

// --- the tones and the lights ---
uniform float paint_cut : hint_range(0.05, 0.95) = 0.42;
uniform float paint_shadow_level : hint_range(0.1, 1.0) = 0.58;
uniform vec3 paint_shadow_hue : source_color = vec3(0.24, 0.24, 0.55);
uniform float paint_shadow_hue_amount : hint_range(0.0, 1.0) = 0.75;
uniform float term_soft : hint_range(0.0, 12.0) = 3.0;
uniform float dir_floor : hint_range(0.0, 1.0) = 0.5;
uniform float point_gain : hint_range(0.5, 6.0) = 2.2;
uniform float fill_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec3 fill_dir = vec3(-0.45, 0.55, 0.70);

// --- the rim ---
uniform vec3 paint_rim_color : source_color = vec3(1.0, 0.56, 0.22);
uniform float paint_rim_strength : hint_range(0.0, 2.0) = 0.9;
uniform float paint_rim_cut : hint_range(0.3, 1.0) = 0.72;
uniform float paint_rim_key : hint_range(0.0, 1.0) = 0.42;
uniform float paint_rim_curve : hint_range(0.0, 4.0) = 1.2;

// --- the hard highlight (the art's own, as toon_light.gdshaderinc has it) ---
uniform float band_soft : hint_range(0.0, 8.0) = 1.2;
uniform float spec_cut : hint_range(0.5, 1.0) = 0.99;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.5;
uniform float spec_gloss : hint_range(1.0, 8.0) = 1.0;
uniform float glint_cut : hint_range(0.5, 1.0) = 0.81;
uniform float glint_strength : hint_range(0.0, 1.0) = 1.0;

// --- toon.gdshader's: the flash, the damage look, the edge tag ---
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D damage_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_skin_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_scuff_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform float blood_edge : hint_range(0.0, 1.0) = 0.0;
uniform float damage_scale : hint_range(0.1, 20.0) = 2.5;
uniform float marks : hint_range(0.0, 1.0) = 0.0;
uniform bool use_rest_custom = true;
uniform float edge_tag : hint_range(0.0, 1.0) = 0.0;

varying vec3 mark_pos;
varying vec3 mark_normal;
varying float swatch_spec;
varying float swatch_glint;
varying float glint_gate;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 damage_triplanar(sampler2D tex, vec3 p, vec3 w, vec3 dpdx, vec3 dpdy) {
	return textureGrad(tex, p.zy, dpdx.zy, dpdy.zy) * w.x + textureGrad(tex, p.xz, dpdx.xz, dpdy.xz) * w.y
			+ textureGrad(tex, p.xy, dpdx.xy, dpdy.xy) * w.z;
}

void vertex() {
	if (use_rest_custom) {
		mark_pos = CUSTOM0.xyz;
		mark_normal = CUSTOM1.xyz;
	} else {
		mark_pos = VERTEX;
		mark_normal = NORMAL;
	}
}

void fragment() {
	vec3 color = texture(paint_tex, UV2).rgb * albedo.rgb;
	// The ink map: the line (filtered, cut crisp) and the class and gloss bytes (the texel itself, never a blend of two classes).
	float line_raw = texture(ink_tex, UV2).r;
	float line_edge = max(0.5 * fwidth(line_raw), 0.0001);
	float line = smoothstep(paint_line_cut - line_edge, paint_line_cut + line_edge, line_raw) * paint_line_strength;
	ivec2 size = textureSize(ink_tex, 0);
	vec4 mask = texelFetch(ink_tex, clamp(ivec2(UV2 * vec2(size)), ivec2(0), size - 1), 0);
	float klass = mask.g;
	float takes_marks = marks * step(0.75, klass);
	float skin_marks = 1.0 - step(0.85, klass);
	float no_blood = step(0.85, klass) * (1.0 - step(0.95, klass));
	// Glossy where B is at or above one half; its value, cut with the usual one-pixel edge, gates the glint to the authored streaks.
	float gloss_edge = max(0.5 * fwidth(mask.b), 0.0001);
	swatch_spec = step(0.5, mask.b);
	swatch_glint = swatch_spec;
	glint_gate = smoothstep(0.5 - gloss_edge, 0.5 + gloss_edge, mask.b);
	// Grain on the flat fill only (not on a drawn line), gone where a cell is under a pixel.
	float cell = paint_grain_cells * length(fwidth(mark_pos));
	float grain = paint_grain_noise(mark_pos * paint_grain_cells);
	color *= 1.0 + (grain - 0.5) * 2.0 * paint_grain * (1.0 - line) * (1.0 - smoothstep(0.35, 0.9, cell));
	color = mix(color, ink, line);
	if (takes_marks > 0.0) {
		vec3 w = abs(normalize(mark_normal));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 p = mark_pos * damage_scale;
		vec3 dpdx = dFdx(p);
		vec3 dpdy = dFdy(p);
		vec4 d;
		if (skin_marks > 0.5) {
			d = damage_triplanar(damage_skin_tex, p, w, dpdx, dpdy);
		} else if (no_blood > 0.5) {
			d = damage_triplanar(damage_scuff_tex, p, w, dpdx, dpdy);
		} else {
			d = damage_triplanar(damage_tex, p, w, dpdx, dpdy);
		}
		if (blood_edge > 0.0 && no_blood < 0.5) {
			float edge = max(0.5 * fwidth(d.a), 0.0001);
			d.a = smoothstep(blood_edge - edge, blood_edge + edge, d.a);
		}
		color = mix(color, d.rgb, d.a * takes_marks);
	}
	ALBEDO = color;
	ROUGHNESS = edge_tag;
	EMISSION = flash_color * flash_amount;
}

void light() {
	float to_pixels = VIEWPORT_SIZE.y / 1080.0;
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		if (fill_strength > 0.0) {
			lit = max(lit, fill_strength * dot(NORMAL, fill_dir));
		}
	} else {
		lit = clamp(lit * point_gain, 0.0, 1.0);
	}
	// The designed terminator: one cut, an edge never narrower than term_soft pixels of the light's own gradient.
	float edge = clamp(0.5 * term_soft * to_pixels * fwidth(lit), 0.002, 0.14);
	vec3 hue = paint_shadow_hue / max(dot(paint_shadow_hue, LUMA), 0.001);
	vec3 shadow = paint_shadow_level * mix(vec3(1.0), hue, paint_shadow_hue_amount);
	vec3 shade = mix(shadow, vec3(1.0), smoothstep(paint_cut - edge, paint_cut + edge, lit));
	vec3 light_color = min(LIGHT_COLOR / PI, vec3(1.0));
	if (LIGHT_IS_DIRECTIONAL) {
		float peak = max(light_color.r, max(light_color.g, light_color.b));
		light_color = light_color / max(peak, 0.0001) * mix(dir_floor, 1.0, peak) * step(0.0001, peak);
		DIFFUSE_LIGHT += shade * light_color;
		// The rim, from the key (the directional light) alone: the grazing angle plus the key's facing, narrowed by the
		// curvature (how fast the normal turns across a pixel), cut hard. One side: nothing where the surface turns from the key.
		vec3 n = normalize(NORMAL);
		float fres = 1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
		float facing = dot(n, normalize(LIGHT));
		float curve = length(fwidth(n)) / max(to_pixels, 0.001);
		float rim_v = fres + paint_rim_key * facing - paint_rim_curve * clamp(curve, 0.0, 0.4);
		float rim_edge = max(fwidth(rim_v), 0.002);
		float rim = smoothstep(paint_rim_cut - rim_edge, paint_rim_cut + rim_edge, rim_v) * smoothstep(-0.05, 0.25, facing);
		SPECULAR_LIGHT += paint_rim_color * paint_rim_strength * rim;
	} else {
		// A lamp adds what rises above the shadow tone, so nothing inside the shadow band.
		DIFFUSE_LIGHT += max(shade - shadow, vec3(0.0)) * light_color;
	}
	// One hard highlight, lit side only, on the glossy texels.
	float aligned = dot(NORMAL, normalize(LIGHT + VIEW));
	float spec_edge = max(0.5 * band_soft * to_pixels * fwidth(aligned), 0.00001);
	float spec = smoothstep(spec_cut - spec_edge, spec_cut + spec_edge, aligned);
	SPECULAR_LIGHT += spec * spec_strength * spec_gloss * swatch_spec * step(0.0, ndl) * ATTENUATION * light_color;
	if (LIGHT_IS_DIRECTIONAL && swatch_glint > 0.5 && glint_strength > 0.0) {
		float glint_aligned = dot(NORMAL, normalize(fill_dir + VIEW));
		float glint_edge = max(0.5 * band_soft * to_pixels * fwidth(glint_aligned), 0.00001);
		float glint = smoothstep(glint_cut - glint_edge, glint_cut + glint_edge, glint_aligned);
		SPECULAR_LIGHT += glint * glint_gate * spec_strength * spec_gloss * glint_strength * light_color;
	}
}
