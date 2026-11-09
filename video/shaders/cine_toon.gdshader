shader_type spatial;
// The video's character paint (Phase 1, LD-INK; docs/video/PLAN.md section 4, Plan A part 2): the cine
// version of game/fx/toon.gdshader, swapped IN PLACE onto the characters' art materials at runtime
// (video/ink/ink_rig.gd), so the rig's shared materials, their atlas, detail mask, damage tiles and the
// uniforms the game writes (ToonMaterials.apply_look) all stay as they are. Every uniform of toon.gdshader
// and of toon_light.gdshaderinc keeps its name and type for that reason.
//
// toon_light.gdshaderinc is NOT included: it defines light(), and a shader has one. The toon_shade() idea
// is kept (bands with a tinted shadow that is never black); what this adds:
//  - A PAINTED TERMINATOR. The light term is shifted by an object-space brush noise before the bands, and
//    the band edge is at least term_soft pixels wide, so a shadow map's stair-steps turn into a wavy,
//    hand-edged shape (soften, then posterise).
//  - THE SCENE'S SHADOW HUE (cine_shadow), 2 or 3 bands (cine_bands).
//  - A POINT LIGHT ADDS NOTHING IN ITS SHADOW BAND: only the sun's (directional) light carries the shadow
//    colour; a lamp adds (shade - shadow) so its pool has a hard edge and no flood.
//  - A KEY-TINTED RIM in fragment(), a hard-edged band whose width follows the surface's curvature and an
//    object-space noise, never a constant. key_dir_view / key_color come from the rig each frame.
//  - OBJECT-SPACE BRUSH GRAIN (the rest-pose position, so it sticks to the moving body).
//  - HATCHING from a code-made tonal art map (hatch_tex) in the shadow band, switched on by hatch_on.
//  - GLINTS only where the atlas says glossy (the game's per-swatch gloss), kept as the game does it.
//  - For LD-ASSET: ink_tex (R = ink, UV2, the layout), paint_tex (painted albedo, UV2), ink_color and ink_strength.

render_mode ambient_light_disabled;

// --- toon.gdshader's own uniforms (names and types kept) ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform bool use_albedo_tex = false;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_disable;
uniform bool use_detail_tex = false;
uniform bool use_texel_swatch = true;
uniform vec2 texel_swatch_fade = vec2(1.0, 3.0);
const vec2 ATLAS_GRID = vec2(32.0, 2.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool detail_sharp = false;
uniform float detail_cut : hint_range(0.0, 1.0) = 0.15;
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D damage_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_skin_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_scuff_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform float blood_edge : hint_range(0.0, 1.0) = 0.0;
uniform float damage_scale : hint_range(0.1, 20.0) = 2.5;
uniform float marks : hint_range(0.0, 1.0) = 0.0;
uniform bool use_rest_custom = false;
uniform float edge_tag : hint_range(0.0, 1.0) = 1.0;

// --- toon_light.gdshaderinc's uniforms (the game writes them; here they are declared and mostly unused) ---
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
uniform float glint_cut : hint_range(0.5, 1.0) = 0.81;
uniform float glint_strength : hint_range(0.0, 1.0) = 1.0;

// --- the cine paint (video/look/<location>/ink.tres; the rig writes them) ---
// The bands: the cuts on the light term, the mid band's level (1 = two bands), the shadow's level and hue.
uniform float cine_band_1 : hint_range(0.0, 1.0) = 0.30;
uniform float cine_band_2 : hint_range(0.0, 1.0) = 0.66;
uniform float cine_mid : hint_range(0.0, 1.0) = 0.70;
uniform float cine_shadow_level : hint_range(0.0, 1.0) = 0.30;
uniform vec3 cine_shadow : source_color = vec3(0.20, 0.22, 0.50);
uniform float cine_shadow_amount : hint_range(0.0, 1.0) = 0.8;
// Camera-fixed fill (a share of a full light; 0 = none, the night's choice).
uniform float cine_fill : hint_range(0.0, 1.5) = 0.0;
// A lamp's light term is multiplied by this before the bands (a point light's falloff keeps its term low).
// A directional light (the moon, the sun) lights a character at no less than this share of full, in its hue:
// a dim scene light never drops the paint to black (the toon light caps and keeps the hue the same way).
uniform float cine_dir_floor : hint_range(0.0, 1.0) = 0.5;
uniform float cine_point_gain : hint_range(0.5, 6.0) = 2.2;
// The painted terminator: the minimum band edge (pixels at 1080p) and how far the brush noise moves the light term.
uniform float term_soft : hint_range(0.0, 12.0) = 3.0;
uniform float term_wobble : hint_range(0.0, 0.6) = 0.22;
uniform vec3 term_noise_scale = vec3(7.0, 3.0, 7.0);
// Object-space brush grain: its strength (a share of the value), the cells per metre, and its stretch.
uniform float grain_amount : hint_range(0.0, 0.6) = 0.14;
uniform float grain_scale : hint_range(1.0, 200.0) = 38.0;
uniform vec3 grain_stretch = vec3(1.0, 0.4, 1.0);
// The rim: the key's direction in VIEW space (to the light) and colour, the strength, where the band starts
// (on 1 - n.v plus the key's facing), the key's pull, how much curvature narrows it, the edge noise.
uniform vec3 key_dir_view = vec3(-0.6, 0.5, -0.6);
uniform vec3 key_color : source_color = vec3(1.0, 0.6, 0.24);
uniform float cine_rim_strength : hint_range(0.0, 2.0) = 0.9;
uniform float cine_rim_cut : hint_range(0.3, 1.0) = 0.72;
uniform float cine_rim_key : hint_range(0.0, 1.0) = 0.42;
uniform float cine_rim_curve : hint_range(0.0, 4.0) = 1.2;
uniform float cine_rim_wobble : hint_range(0.0, 0.5) = 0.12;
// Hatching: 0 off, 1 full; the cells per metre, how dark a stroke is (a share of the shade), the ink hue.
uniform sampler2D hatch_tex : filter_linear_mipmap, repeat_enable;
uniform float hatch_on : hint_range(0.0, 1.0) = 0.0;
uniform float hatch_scale : hint_range(0.5, 12.0) = 3.2;
uniform float hatch_dark : hint_range(0.0, 1.0) = 0.7;
// LD-ASSET's textures (UV0): off until the art ships them.
uniform sampler2D ink_tex : filter_linear_mipmap, repeat_disable;
uniform bool use_ink_tex = false;
uniform sampler2D paint_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_paint_tex = false;
uniform vec3 ink_color : source_color = vec3(0.09, 0.055, 0.05);
uniform float ink_strength : hint_range(0.0, 1.0) = 1.0;

varying vec3 mark_pos;
varying vec3 mark_normal;
varying float swatch_spec;
varying float swatch_glint;
varying float glint_gate;
varying float paint_noise;
varying vec4 hatch_levels;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

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

float swatch_gloss(float alpha) {
	float a8 = floor(alpha * 255.0 + 0.5);
	float class_a8 = alpha > 0.95 ? 255.0 : (alpha > 0.85 ? 230.0 : (alpha > 0.75 ? 204.0 : 128.0));
	return 1.0 - step(0.5, abs(class_a8 - a8 - 1.0));
}

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
	vec3 color = albedo.rgb;
	float takes_marks = marks;
	float skin_marks = 0.0;
	float no_blood = 0.0;
	swatch_spec = 1.0;
	swatch_glint = 0.0;
	glint_gate = 1.0;
	if (use_albedo_tex) {
		vec4 swatch = texture(albedo_tex, UV);
		if (use_detail_tex && use_texel_swatch) {
			vec2 texels = UV2 * vec2(textureSize(detail_tex, 0));
			float texels_per_pixel = max(length(dFdx(texels)), length(dFdy(texels)));
			vec4 fetched = texelFetch(detail_tex, clamp(ivec2(texels), ivec2(0), textureSize(detail_tex, 0) - 1), 0);
			float code = fetched.b;
			if (fetched.a < 0.9 && code > 0.0) {
				float slot = floor(code * 255.0 + 0.5) - 1.0;
				vec4 texel_swatch = texture(albedo_tex, (vec2(mod(slot, ATLAS_GRID.x), floor(slot / ATLAS_GRID.x)) + 0.5) / ATLAS_GRID);
				float w = 1.0 - smoothstep(texel_swatch_fade.x, texel_swatch_fade.y, texels_per_pixel);
				swatch = vec4(mix(swatch.rgb, texel_swatch.rgb, w), w > 0.5 ? texel_swatch.a : swatch.a);
			}
		}
		color *= swatch.rgb;
		takes_marks *= step(0.75, swatch.a);
		skin_marks = 1.0 - step(0.85, swatch.a);
		no_blood = step(0.85, swatch.a) * (1.0 - step(0.95, swatch.a));
		swatch_spec = swatch_gloss(swatch.a);
		swatch_glint = swatch_spec;
	}
	if (use_paint_tex) {
		color = texture(paint_tex, UV2).rgb * albedo.rgb;
	}
	if (use_detail_tex) {
		float ink_mask = texture(detail_tex, UV2).r;
		if (detail_sharp) {
			float edge = max(0.5 * fwidth(ink_mask), 0.0001);
			ink_mask = smoothstep(detail_cut - edge, detail_cut + edge, ink_mask);
		}
		color = mix(color, ink_color, ink_mask * detail_strength);
		float streak = texture(detail_tex, UV2).g;
		float streak_edge = max(0.5 * fwidth(streak), 0.0001);
		glint_gate = smoothstep(0.5 - streak_edge, 0.5 + streak_edge, streak);
	}
	if (use_ink_tex) {
		color = mix(color, ink_color, texture(ink_tex, UV2).r * ink_strength);
	}
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
	// Brush grain and the terminator's noise, both in the object's rest space.
	float grain = vnoise(mark_pos * grain_scale * grain_stretch);
	color *= 1.0 + (grain - 0.5) * 2.0 * grain_amount;
	paint_noise = vnoise(mark_pos * term_noise_scale);

	// Hatching strokes (a tonal art map: four cumulative densities in R, G, B, A), triplanar in rest space.
	hatch_levels = vec4(0.0);
	if (hatch_on > 0.0) {
		vec3 w = abs(normalize(mark_normal));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 p = mark_pos * hatch_scale;
		hatch_levels = texture(hatch_tex, p.zy) * w.x + texture(hatch_tex, p.xz) * w.y + texture(hatch_tex, p.xy) * w.z;
	}

	// The key-tinted rim: a hard band on the silhouette side that faces the key, narrower where the
	// surface curves fast, with an edge that wanders in object space.
	vec3 n = normalize(NORMAL);
	float fres = 1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float facing = dot(n, normalize(key_dir_view));
	float curve = length(fwidth(n)) / max(VIEWPORT_SIZE.y / 1080.0, 0.001);
	float rim_v = fres + cine_rim_key * facing - cine_rim_curve * clamp(curve, 0.0, 0.4)
			+ (vnoise(mark_pos * 9.0 + vec3(3.1, 1.7, 5.3)) - 0.5) * 2.0 * cine_rim_wobble;
	float rim_edge = max(fwidth(rim_v), 0.002);
	float rim = smoothstep(cine_rim_cut - rim_edge, cine_rim_cut + rim_edge, rim_v) * smoothstep(-0.05, 0.25, facing);

	ALBEDO = color;
	ROUGHNESS = edge_tag;
	EMISSION = flash_color * flash_amount + key_color * rim * cine_rim_strength * color;
}

// The shade multiplier of a surface whose light term is `lit`: the shadow (hued, never black), the mid band, the lit band.
vec3 cine_shade(float lit, float edge, out vec3 shadow) {
	vec3 tint = cine_shadow / max(dot(cine_shadow, LUMA), 0.001);
	shadow = cine_shadow_level * mix(vec3(1.0), tint, cine_shadow_amount);
	float b1 = smoothstep(cine_band_1 - edge, cine_band_1 + edge, lit);
	float b2 = smoothstep(cine_band_2 - edge, cine_band_2 + edge, lit);
	return mix(mix(shadow, vec3(cine_mid), b1), vec3(1.0), b2);
}

void light() {
	float to_pixels = VIEWPORT_SIZE.y / 1080.0;
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL && cine_fill > 0.0) {
		lit = max(lit, cine_fill * dot(NORMAL, fill_dir));
	}
	// The painted terminator: the brush noise moves the light term before the step, and the edge is never
	// narrower than term_soft pixels of the light's own gradient (a shadow map's steps are inside it).
	if (!LIGHT_IS_DIRECTIONAL) {
		lit = clamp(lit * cine_point_gain, 0.0, 1.0);
	}
	lit += (paint_noise - 0.5) * term_wobble * smoothstep(0.0, 0.2, lit + term_wobble);
	float edge = clamp(0.5 * term_soft * to_pixels * fwidth(lit), 0.002, 0.14);
	vec3 shadow;
	vec3 shade = cine_shade(lit, edge, shadow);
	// Hatching in the shadow band, from the tonal art map: deeper in shadow, denser.
	if (hatch_on > 0.0) {
		float depth = clamp(1.0 - lit / max(cine_band_1, 0.001), 0.0, 1.0);
		float t = depth * 3.0;
		float h = mix(mix(mix(0.0, hatch_levels.r, clamp(t, 0.0, 1.0)), hatch_levels.g, clamp(t - 1.0, 0.0, 1.0)),
				hatch_levels.b, clamp(t - 2.0, 0.0, 1.0));
		h = max(h, hatch_levels.a * smoothstep(0.85, 1.0, depth));
		shade *= 1.0 - hatch_on * hatch_dark * h * step(0.001, depth);
	}
	vec3 light_color = min(LIGHT_COLOR / PI, vec3(1.0));
	if (LIGHT_IS_DIRECTIONAL) {
		float peak = max(light_color.r, max(light_color.g, light_color.b));
		light_color = light_color / max(peak, 0.0001) * mix(cine_dir_floor, 1.0, peak) * step(0.0001, peak);
		DIFFUSE_LIGHT += shade * light_color;
	} else {
		// A lamp adds only what rises above the shadow: nothing in its shadow band.
		DIFFUSE_LIGHT += max(shade - shadow, vec3(0.0)) * light_color;
	}
	// One hard highlight, lit side only, on the glossy swatches.
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
