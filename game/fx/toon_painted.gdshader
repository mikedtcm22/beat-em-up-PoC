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
//  - A one-sided rim, in the area's warm colour, on the side the directional (key) light comes from: a hard line a set number of pixels
//    wide just inside the silhouette (M7 C1), no noise.
//  - A little grain on flat fills, in the rest-pose position, so it sticks to the body and never touches a drawn line (0 by default).
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
// The drawn line (M7 G1): the inner ink swells and tapers with an object-space noise, is heavier away from the key, breaks where it faces the
// key, and sits a little off the fill on a beat (twos), so it reads as a hand's line and not a rasterised one.
global uniform vec3 paint_key_dir;
uniform float paint_wobble_hz : hint_range(1.0, 30.0) = 12.0;
uniform float line_vary : hint_range(0.0, 0.3) = 0.12;
uniform float line_vary_cells : hint_range(1.0, 60.0) = 9.0;
uniform float line_shadow : hint_range(0.0, 0.3) = 0.06;
uniform float line_wobble_texels : hint_range(0.0, 6.0) = 1.6;
uniform float line_gap : hint_range(0.0, 1.0) = 0.3;
uniform float line_gap_cells : hint_range(2.0, 80.0) = 16.0;
// The key's shadow map on a painted surface (0: none, so no ragged self-shadow; the paint has the shadow shapes drawn in).
uniform float paint_cast_shadow : hint_range(0.0, 1.0) = 0.0;

// --- the tones and the lights ---
uniform float paint_cut : hint_range(0.05, 0.95) = 0.42;
uniform float paint_shadow_level : hint_range(0.1, 1.0) = 0.58;
uniform vec3 paint_shadow_hue : source_color = vec3(0.24, 0.24, 0.55);
uniform float paint_shadow_hue_amount : hint_range(0.0, 1.0) = 0.75;
uniform float term_soft : hint_range(0.0, 12.0) = 3.0;
uniform float dir_floor : hint_range(0.0, 1.0) = 0.5;
// How much of a light's own hue a painted surface keeps (0: the light only brightens, 1: the light's full colour). A figure keeps its local colour.
// A fully lit painted surface shows this share of its paint (the trailer's mid tone sits a little under the flat swatch).
uniform float paint_lit_level : hint_range(0.2, 1.5) = 0.72;
uniform float paint_light_tint : hint_range(0.0, 1.0) = 0.2;
uniform float point_gain : hint_range(0.5, 6.0) = 2.2;
uniform float fill_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec3 fill_dir = vec3(-0.45, 0.55, 0.70);

// --- the rim ---
uniform vec3 paint_rim_color : source_color = vec3(1.0, 0.56, 0.22);
uniform float paint_rim_strength : hint_range(0.0, 2.0) = 0.9;
// The rim's width in pixels at 1080p, measured inward from the silhouette; the key side only: the key's facing must pass paint_rim_key.
uniform float paint_rim_px : hint_range(0.5, 12.0) = 2.5;
uniform float paint_rim_key : hint_range(0.0, 1.0) = 0.15;
uniform float paint_rim_patch_cells : hint_range(1.0, 30.0) = 4.5;
uniform float paint_rim_patch_cut : hint_range(0.0, 1.0) = 0.62;

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
varying float rim_patch;

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
	ivec2 size = textureSize(ink_tex, 0);
	// The beat: the drawn line's shapes hold for whole steps (twos), then move.
	float beat = floor(TIME * paint_wobble_hz);
	vec3 rp = mark_pos;
	// Where this surface turns from the key (-1) or to it (1), in the view space the normal is in.
	float facing = dot(normalize(NORMAL), normalize((VIEW_MATRIX * vec4(paint_key_dir, 0.0)).xyz));
	// The ink map: the line (filtered, cut crisp) and the class and gloss bytes (the texel itself, never a blend of two classes). The line is read
	// a texel or two off its place, new on each beat, so it never sits exactly on the fill; its cut swings with the noise (swell and taper) and
	// drops lower (heavier) away from the key.
	vec2 jitter = vec2(paint_grain_noise(rp * 23.0 + vec3(beat * 3.7, 0.0, 1.0)), paint_grain_noise(rp * 23.0 + vec3(0.0, beat * 5.3, 9.0))) - 0.5;
	vec2 line_uv = UV2 + jitter * 2.0 * line_wobble_texels / vec2(size);
	float line_raw = texture(ink_tex, line_uv).r;
	float swell = paint_grain_noise(rp * line_vary_cells + vec3(4.0, 7.0, 2.0)) - 0.5;
	float cut = clamp(paint_line_cut + swell * 2.0 * line_vary - line_shadow * (0.5 - 0.5 * clamp(facing * 2.0, -1.0, 1.0)), 0.1, 0.85);
	float line_edge = max(0.5 * fwidth(line_raw), 0.0001);
	float line = smoothstep(cut - line_edge, cut + line_edge, line_raw) * paint_line_strength;
	// Breaks on the lit side: whole cells of the noise drop the line, hard-edged, only where a cell is wide enough to read as a break.
	float gap_noise = paint_grain_noise(rp * line_gap_cells + vec3(13.0, 5.0, 21.0));
	float gap_cell = line_gap_cells * length(fwidth(rp));
	float broken = smoothstep(0.05, 0.4, facing) * step(1.0 - line_gap, gap_noise) * (1.0 - smoothstep(0.2, 0.5, gap_cell));
	line *= 1.0 - broken;
	// The rim's patches: a low-frequency noise cut hard, so the rim is a few shapes on a form and not a band round it.
	float patch_noise = paint_grain_noise(rp * paint_rim_patch_cells + vec3(2.0, 17.0, 5.0));
	float patch_edge = max(fwidth(patch_noise), 0.004);
	// A cut of 0 is no patches: the rim is one clean line.
	rim_patch = paint_rim_patch_cut <= 0.0 ? 1.0 : smoothstep(paint_rim_patch_cut - patch_edge, paint_rim_patch_cut + patch_edge, patch_noise);
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
	// A directional light's shadow map is mixed in by paint_cast_shadow only: at 0 a figure never shades itself with ragged map shadow.
	float lit = ndl * (LIGHT_IS_DIRECTIONAL ? mix(1.0, ATTENUATION, paint_cast_shadow) : ATTENUATION);
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
	// The light's hue is clamped: its brightness stays, its colour is pulled to neutral (paint_light_tint of it kept), so a blue moon
	// or an orange lamp never recolours the paint; the shadow tone alone carries the area's hue, and gently.
	float light_luma = max(dot(light_color, LUMA), 0.0001);
	vec3 light_tint = mix(vec3(1.0), light_color / light_luma, paint_light_tint);
	if (LIGHT_IS_DIRECTIONAL) {
		float peak = max(light_color.r, max(light_color.g, light_color.b));
		light_color = light_tint * mix(dir_floor, 1.0, peak) * paint_lit_level * step(0.0001, peak);
		DIFFUSE_LIGHT += shade * light_color;
		// The rim, from the key (the directional light) alone: a hard line paint_rim_px wide just inside the silhouette. The distance to the
		// silhouette in pixels is read from how fast the view-facing term changes (u / fwidth(u) is twice the distance for a round form), so the
		// width holds on a thin limb and a fat one alike. One side: nothing where the surface turns from the key. No noise.
		vec3 n = normalize(NORMAL);
		float u = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
		float to_edge_px = 0.5 * u / max(fwidth(u), 0.0001) / max(to_pixels, 0.001);
		float facing = dot(n, normalize(LIGHT));
		float rim = (1.0 - smoothstep(paint_rim_px - 0.5, paint_rim_px + 0.5, to_edge_px)) * smoothstep(paint_rim_key - 0.1, paint_rim_key + 0.1, facing) * rim_patch;
		SPECULAR_LIGHT += paint_rim_color * paint_rim_strength * rim;
	} else {
		// A lamp adds what rises above the shadow tone, so nothing inside the shadow band.
		DIFFUSE_LIGHT += max(shade - shadow, vec3(0.0)) * light_tint * light_luma;
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
