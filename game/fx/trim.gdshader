shader_type spatial;
// The environment kit's trim material (Milestone 6, KIT; plan D2 and D10): ONE material for every
// module, dressing piece and barrier panel (ToonMaterials.trim()), so the draw count follows the mesh
// count only. Lit by the same toon lighting as the rest (toon_light.gdshaderinc: the bands, the tinted
// shadow, the sun alone; ToonMaterials gives it the Look values and the environment's two bands and no
// highlight, like grid.gdshader).
//
// The sheet (assets/export/kit/trim_sheet.png) is 16 strips of 128 px, each seamless both ways. A face
// carries its UVs in METRES (u along the face, v up it) and its strip in the vertex colour: COLOR.rgb is
// a tint (a multiplier, white for none), COLOR.a the strip's row / 255. The strip's row, its period in
// metres and its flags come from the `strips` table (trim_strips.json through ToonMaterials), so a wall
// of any length or height is the strip repeated, never stretched. The sheet's RGB is the surface; its
// ALPHA is the ink mask (a painted seam, crack or joint), cut at `ink_cut` with an edge one pixel wide
// (the same cut as toon.gdshader's detail_cut) so a line stays crisp under the mipmaps; on the scissor
// strip (the chain-link) the alpha is the wire's coverage instead, cut by the scissor. The sheet is a
// stack of wrapped strips, so the mip level is capped (`lod_cap`): past it one strip would blend into
// its neighbour.
render_mode ambient_light_disabled;

#include "res://game/fx/toon_light.gdshaderinc"

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
	bool scissor = row.w > 0.5 && row.w < 1.5;
	if (scissor) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = scissor_cut;
	} else {
		float edge = max(0.5 * fwidth(c.a), 0.0001);
		float mask = smoothstep(ink_cut - edge, ink_cut + edge, c.a);
		color = mix(color, ink, mask);
		ALPHA = 1.0;
	}
	ALBEDO = color * albedo.rgb * tint;
	ROUGHNESS = edge_tag;
}
