// The trim material's uniforms, vertex and fragment (see trim.gdshader and trim_scissor.gdshader, which include
// this): the opaque variant, or with TRIM_SCISSOR defined the chain-link's alpha scissor.

// A flat tint over everything (white: none). ToonMaterials keeps it a Color so a test can read it.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D trim_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The metres one width of the sheet covers (Tuning's kit_trim_m_per_tile).
uniform float tile_m = 4.0;
// Per strip: x = the row's top in the sheet (0-1), y = its height, z = its period in metres,
// w = flags (1 scissor, 2 ink only, 4 ground).
uniform vec4 strips[16];
// The street's ground (FB-GROUND): a strip with flag 4 samples ground_tex instead, in WORLD metres (x, -z) over `ground_m`
// metres a tile, with every mip level in reach (it is one picture, not a stack of wrapped strips, so nothing bleeds
// and the sheet's lod cap does not apply). ground_on false is the Debug switch: the strip's own paint, M6's way.
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ground_m = 8.0;
uniform bool ground_on = true;
// How the ink softens with distance. On the ground, the cut's edge widens from (x) mip levels by (y) a level up to (z), so a
// crack that shrinks under a pixel dims smoothly and never pops; on a strip, the ink fades out between (x) and (y) texels a
// pixel, where the capped mip would alias it (Tuning's Level > Ground).
uniform vec3 ink_soft = vec3(2.0, 0.12, 0.45);
uniform vec2 ink_fade = vec2(16.0, 64.0);
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float ink_cut : hint_range(0.05, 0.95) = 0.5;
uniform float lod_cap : hint_range(1.0, 7.0) = 4.0;
uniform float scissor_cut : hint_range(0.05, 0.95) = 0.35;
// The edge pass's tag, written as ROUGHNESS: 1 on the world, so its lines draw on a module.
uniform float edge_tag : hint_range(0.0, 1.0) = 1.0;

// A debug view of the sampling (FB-GROUND): 0 the picture; 1 the strip index; 2 the mip level the footprint wants (log2 of the
// texels a pixel covers, 0 to 12 as black to white); 3 the ink mask; 4 the sheet's alpha as it is sampled.
uniform int debug_view : hint_range(0, 4) = 0;

varying vec2 face_m;
varying vec2 world_m;
varying vec3 tint;
varying float strip_id;

void vertex() {
	face_m = UV;
	world_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	tint = COLOR.rgb;
	strip_id = COLOR.a * 255.0;
}

// The ink's coverage from the sheet's alpha `a`: the cut at ink_cut with an edge one pixel wide, and then the distance's
// softening (the ground) or fade (a strip), by the `texels` one pixel covers.
float ink_mask(float a, float texels, bool ground) {
	float edge = max(0.5 * fwidth(a), 0.0001);
	if (ground) {
		edge += clamp((log2(max(texels, 1.0)) - ink_soft.x) * ink_soft.y, 0.0, ink_soft.z);
	}
	float mask = smoothstep(ink_cut - edge, ink_cut + edge, a);
	if (!ground) {
		mask *= 1.0 - smoothstep(ink_fade.x, ink_fade.y, texels);
	}
	return mask;
}

void fragment() {
	vec4 row = strips[clamp(int(strip_id + 0.5), 0, 15)];
	bool ground = ground_on && row.w > 3.5;
	// Repeats of the strip: U across the sheet, V up the strip (the image's y runs down).
	vec2 t = vec2(face_m.x / tile_m, face_m.y / max(row.z, 0.01));
	vec2 uv = vec2(t.x, row.x + (1.0 - fract(t.y)) * row.y);
	vec2 gx = dFdx(t) * vec2(1.0, -row.y);
	vec2 gy = dFdy(t) * vec2(1.0, -row.y);
	// The ground's own coordinates (derivatives taken here, outside any branch).
	vec2 gt = vec2(world_m.x, -world_m.y) / ground_m;
	vec2 ggx = dFdx(gt);
	vec2 ggy = dFdy(gt);
	vec4 c;
	float texels;
	if (ground) {
		texels = max(length(ggx), length(ggy)) * float(textureSize(ground_tex, 0).x);
		c = textureGrad(ground_tex, gt, ggx, ggy);
	} else {
		// Texels one pixel covers; past 2^lod_cap the gradients are scaled back so the level stops there.
		texels = max(length(gx), length(gy)) * float(textureSize(trim_tex, 0).x);
		float keep = min(1.0, exp2(lod_cap) / max(texels, 0.0001));
		c = textureGrad(trim_tex, uv, gx * keep, gy * keep);
	}
	vec3 color = c.rgb;
#ifdef TRIM_SCISSOR
	if (row.w > 0.5 && row.w < 1.5) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = scissor_cut;
	} else {
		color = mix(color, ink, ink_mask(c.a, texels, ground));
		ALPHA = 1.0;
	}
#else
	color = mix(color, ink, ink_mask(c.a, texels, ground));
#endif
	if (debug_view == 1) {
		color = vec3(strip_id / 15.0);
	} else if (debug_view == 2) {
		color = vec3(clamp(log2(max(texels, 1.0)) / 12.0, 0.0, 1.0));
	} else if (debug_view == 4) {
		color = vec3(c.a);
	}
	ALBEDO = color * albedo.rgb * tint;
	ROUGHNESS = edge_tag;
}
