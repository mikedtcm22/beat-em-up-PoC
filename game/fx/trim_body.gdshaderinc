// The trim material's uniforms, vertex and fragment (see trim.gdshader and trim_scissor.gdshader, which include
// this): the opaque variant, or with TRIM_SCISSOR defined the chain-link's alpha scissor.

// A flat tint over everything (white: none). ToonMaterials keeps it a Color so a test can read it.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D trim_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The metres one width of the sheet covers (Tuning's kit_trim_m_per_tile).
uniform float tile_m = 4.0;
// Per strip: x = the row's top in the sheet (0-1), y = its height, z = its period in metres,
// w = flags (1 scissor, 2 ink only).
uniform vec4 strips[16];
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float ink_cut : hint_range(0.05, 0.95) = 0.5;
uniform float lod_cap : hint_range(1.0, 7.0) = 4.0;
uniform float scissor_cut : hint_range(0.05, 0.95) = 0.35;
// The edge pass's tag, written as ROUGHNESS: 1 on the world, so its lines draw on a module.
uniform float edge_tag : hint_range(0.0, 1.0) = 1.0;

varying vec2 face_m;
varying vec3 tint;
varying float strip_id;

void vertex() {
	face_m = UV;
	tint = COLOR.rgb;
	strip_id = COLOR.a * 255.0;
}

void fragment() {
	vec4 row = strips[clamp(int(strip_id + 0.5), 0, 15)];
	// Repeats of the strip: U across the sheet, V up the strip (the image's y runs down).
	vec2 t = vec2(face_m.x / tile_m, face_m.y / max(row.z, 0.01));
	vec2 uv = vec2(t.x, row.x + (1.0 - fract(t.y)) * row.y);
	vec2 gx = dFdx(t) * vec2(1.0, -row.y);
	vec2 gy = dFdy(t) * vec2(1.0, -row.y);
	// Texels one pixel covers; past 2^lod_cap the gradients are scaled back so the level stops there.
	float texels = max(length(gx), length(gy)) * float(textureSize(trim_tex, 0).x);
	float keep = min(1.0, exp2(lod_cap) / max(texels, 0.0001));
	vec4 c = textureGrad(trim_tex, uv, gx * keep, gy * keep);
	vec3 color = c.rgb;
#ifdef TRIM_SCISSOR
	if (row.w > 0.5 && row.w < 1.5) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = scissor_cut;
	} else {
		float edge = max(0.5 * fwidth(c.a), 0.0001);
		float mask = smoothstep(ink_cut - edge, ink_cut + edge, c.a);
		color = mix(color, ink, mask);
		ALPHA = 1.0;
	}
#else
	float edge = max(0.5 * fwidth(c.a), 0.0001);
	float mask = smoothstep(ink_cut - edge, ink_cut + edge, c.a);
	color = mix(color, ink, mask);
#endif
	ALBEDO = color * albedo.rgb * tint;
	ROUGHNESS = edge_tag;
}
