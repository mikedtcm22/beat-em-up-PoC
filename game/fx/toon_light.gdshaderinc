// The toon lighting (Milestone 4): one light() for every lit surface of the game, included by
// toon.gdshader (characters, props, the room's boxes) and game/level/grid.gdshader (the floor).
// Cel bands with a tinted shadow that is never black, one hard highlight and a stepped rim.
// Every value is a uniform, fed from Tuning's Look group by ToonMaterials, so nothing here is
// a feel number. Mirrored for the tests by ToonMaterials.band_shade().
//
// The including shader sets `render_mode ambient_light_disabled`: the ramp owns the shadow
// side, so the sky's ambient light never lifts it (and a character's ROUGHNESS = 0, the edge
// pass's tag, never shows sky radiance).
//
// Bands: a surface's light is dot(normal, light) times the light's attenuation (the shadow
// map's term is in it). Below band_1 it is in shadow (shadow_level of the lit value, tinted
// toward shadow_tint), between band_1 and band_2 it is mid (mid_level), above it is lit (1).
// A material that wants two bands (the environment) sets mid_level to 1.
//
// The fill (characters only): a second source of light fixed to the camera, in view space, so a
// character that faces away from the sun (about half of all of them, whatever its azimuth) still
// has a lit side, a mid band and a shadow side on its front instead of one flat shadow. A
// surface's light is the stronger of the sun's and the fill's; the sun's shadow map only dims
// the sun's (a cast shadow shows where the fill does not reach).

uniform float band_1 : hint_range(0.0, 1.0) = 0.25;
uniform float band_2 : hint_range(0.0, 1.0) = 0.62;
// The width of a band edge in pixels at 1080p: the transition is this many pixels wide wherever
// the light changes across a surface (nothing to soften on a flat one). The look bible allows 2 px.
uniform float band_soft : hint_range(0.0, 8.0) = 1.2;
uniform float mid_level : hint_range(0.0, 1.0) = 0.72;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.42;
uniform vec3 shadow_tint : source_color = vec3(0.36, 0.32, 0.55);
uniform float shadow_tint_amount : hint_range(0.0, 1.0) = 0.45;
// The hard highlight: the alignment of the surface with the half vector above which it shows
// (1 = a point), and how strongly; spec_gloss multiplies it for glossy materials (shades, leather, studs).
uniform float spec_cut : hint_range(0.5, 1.0) = 0.99;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.5;
uniform float spec_gloss : hint_range(1.0, 8.0) = 1.0;
// The fill: a share of a full light (0 = none, the room's materials) and its direction in view
// space (x right, y up, z toward the lens), a unit vector from the surface to the light.
uniform float fill_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec3 fill_dir = vec3(-0.45, 0.55, 0.70);
// The stepped rim (characters only: rim_strength is 0 elsewhere).
uniform float rim_cut : hint_range(0.0, 1.0) = 0.7;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;
// Halftone dots in the shadow band, in screen space (cells in pixels at 1080p): off at 0.
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.0;
uniform float halftone_cell_px : hint_range(2.0, 24.0) = 6.0;

// Per-swatch gloss (the skinned art's palette atlas; a shader that defines TOON_SWATCH_SPEC before
// including this, toon.gdshader, sets both in its fragment()): swatch_spec is the share of the hard
// highlight a surface takes (1 for a flat-painted material, whose own spec_gloss decides; on the art
// 1 on a glossy swatch and 0 on a matte one, so denim, cotton and skin never show a highlight) and
// swatch_glint is 1 on a glossy swatch of the art. The glint is a second hard highlight on those
// swatches from the camera-fixed fill direction: a flat visor never meets the sun's half vector
// from the front, so without it the lens would never glint. Its cut (1 = a point) and its share of
// the glossy highlight (0 = off, the lens then glints only where it faces the sun's half vector).
#ifdef TOON_SWATCH_SPEC
varying float swatch_spec;
varying float swatch_glint;
uniform float glint_cut : hint_range(0.5, 1.0) = 0.88;
uniform float glint_strength : hint_range(0.0, 1.0) = 1.0;
#endif

// Luminance weights (Rec. 709), so a tinted shadow keeps its brightness.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// The shade multiplier (rgb) of a surface whose light is `lit`, before the light's color.
vec3 toon_shade(float lit, float edge) {
	vec3 tint = shadow_tint / max(dot(shadow_tint, LUMA), 0.001);
	vec3 shadow = shadow_level * mix(vec3(1.0), tint, shadow_tint_amount);
	float b1 = smoothstep(band_1 - edge, band_1 + edge, lit);
	float b2 = smoothstep(band_2 - edge, band_2 + edge, lit);
	return mix(mix(shadow, vec3(mid_level), b1), vec3(1.0), b2);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL && fill_strength > 0.0) {
		lit = max(lit, fill_strength * dot(NORMAL, fill_dir));
	}
	// Half a band edge, in light units: band_soft pixels (at 1080p) of the light's own gradient
	// (capped, so a shadow map's hard edge stays hard).
	float to_pixels = VIEWPORT_SIZE.y / 1080.0;
	float edge = clamp(0.5 * band_soft * to_pixels * fwidth(lit), 0.0005, 0.08);
	vec3 shade = toon_shade(lit, edge);
	// Dots in the shadow band only: the deeper in shadow, the darker the dots.
	if (halftone_strength > 0.0) {
		vec2 cell = fract(FRAGCOORD.xy / (halftone_cell_px * to_pixels)) - 0.5;
		float dots = 1.0 - smoothstep(0.28, 0.36, length(cell));
		float in_shadow = 1.0 - smoothstep(band_1 - edge, band_1 + edge, lit);
		shade *= 1.0 - halftone_strength * dots * in_shadow;
	}
	// The rim lifts the silhouette where the light reaches the surface: the sun's, or the fill's
	// (a character that faces away from the sun is rimmed on the fill's side).
	float rim = smoothstep(rim_cut - 0.02, rim_cut + 0.02, pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power));
	rim *= smoothstep(0.0, 0.3, lit);
	shade += rim_strength * rim;
	// The lit band shows the albedo as it is, whatever the light's energy: the light's color is
	// kept (a warm sun tints), its brightness is capped at 1 (a 1.2 sun does not wash a palette).
	vec3 light_color = min(LIGHT_COLOR / PI, vec3(1.0));
	DIFFUSE_LIGHT += shade * light_color;
	// One hard highlight, lit side only.
	float aligned = dot(NORMAL, normalize(LIGHT + VIEW));
	float spec_edge = max(0.5 * band_soft * to_pixels * fwidth(aligned), 0.00001);
	float spec = smoothstep(spec_cut - spec_edge, spec_cut + spec_edge, aligned);
#ifdef TOON_SWATCH_SPEC
	float taken = swatch_spec;
#else
	float taken = 1.0;
#endif
	SPECULAR_LIGHT += spec * spec_strength * spec_gloss * taken * step(0.0, ndl) * ATTENUATION * light_color;
#ifdef TOON_SWATCH_SPEC
	if (LIGHT_IS_DIRECTIONAL && swatch_glint > 0.5 && glint_strength > 0.0) {
		float glint_aligned = dot(NORMAL, normalize(fill_dir + VIEW));
		float glint_edge = max(0.5 * band_soft * to_pixels * fwidth(glint_aligned), 0.00001);
		float glint = smoothstep(glint_cut - glint_edge, glint_cut + glint_edge, glint_aligned);
		SPECULAR_LIGHT += glint * spec_strength * spec_gloss * glint_strength * light_color;
	}
#endif
}
