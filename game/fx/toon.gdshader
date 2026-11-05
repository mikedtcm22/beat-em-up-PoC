shader_type spatial;
// The one toon shader (Milestone 4, docs/ARCHITECTURE.md "Toon shader, hull, flash and damage
// on toon"): the placeholder characters' flat paints, the skinned art's palette atlas, the
// pipe and the room's boxes. One shader for all of them, so a switch of look, flash or damage
// never changes the shader variant (a switch would compile one mid-fight): they are uniforms.
// The lighting is toon_light.gdshaderinc's; the hull outline is toon_outline.gdshader's (on
// the mesh's material_overlay); the contact flash is hit_flash.gdshader's (next_pass).
render_mode ambient_light_disabled;

// The art's palette atlas decides, per swatch, whether the hard highlight shows (swatch_spec and
// swatch_glint below), and its detail mask's G where on that swatch the glint may show (glint_gate):
// the lighting include declares and reads those varyings, and the glint's uniforms, only for a shader
// that asks for them with this define (the floor's grid does not).
#define TOON_SWATCH_SPEC
#include "res://game/fx/toon_light.gdshaderinc"

// The flat color (a placeholder paint, a prop, a wall), tinting the atlas when one is used.
uniform vec4 albedo : source_color = vec4(1.0);
// The art's palette atlas (256x16, each face's UV on its swatch's centre; the alpha is the
// swatch's damage class: 1.0 takes the clothes' marks, 0.8 the skin's (damage_skin_tex), 0.5 none;
// a glossy swatch (the shades' lens) is one 8-bit step lower in its class: 254, 203, 127).
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform bool use_albedo_tex = false;
// The art's optional detail mask on UV2: R = ink lines (seams, wraps, stitching), never shading; G = the
// glint gate, the authored streaks on a glossy swatch (the Punk's lens, 0.5 on a streak's edge); B = the texel's palette
// slot + 1 (M6 DETAIL-2, tools/pipeline/pipe_detail.py texel_labels; 0 = none: the face's swatch). The Punk's and the hero's
// masks have B = 0 everywhere, so they take the face's swatch as before; an art whose mask carries codes takes each texel's
// swatch (the colour, the damage class and the gloss), so a colour border follows the texture, not the 2 cm faces.
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_disable;
uniform bool use_detail_tex = false;
// The A/B of the texel swatches (Tuning's look_texel_swatch; off = every face takes its own swatch, M6's look), and the texels per
// pixel over which they give way to the face's swatch: a border at texel resolution is exact up close, but a nearest-sampled
// border farther away crawls (a texel is smaller than a pixel), so from texel_swatch_fade.x to .y texels per pixel the
// colour fades to the face's, which the hull's multisampling holds steady.
uniform bool use_texel_swatch = true;
uniform vec2 texel_swatch_fade = vec2(1.0, 3.0);
// The atlas's layout (tools/pipeline/gen_palette.py COLUMNS, ROWS): a slot's swatch centre.
const vec2 ATLAS_GRID = vec2(32.0, 2.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
// Sharp ink (both characters' masks; ToonMaterials sets it per material from the art's
// metadata/detail_sharp, off for an art that does not ask): the mask is cut at detail_cut with an
// edge one pixel wide (its own screen-space gradient), so a line one texel wide stays a crisp line
// when it is magnified, where the linear mix (the default) makes it a grey smear 3 to 9 pixels wide
// beside the hull's hard line.
uniform bool detail_sharp = false;
uniform float detail_cut : hint_range(0.0, 1.0) = 0.15;
// The ink (HudStyle.INK): the hull's, the detail lines'.
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
// The whole-body parry flash: this color times this share, added after the lighting.
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
// The damage look: a triplanar of damage_tex (one tile every 1/damage_scale m) over the
// rest-pose position and normal of the art (CUSTOM0/1, so the marks stick to the moving body),
// or the part's own vertex space for a rigid primitive; times marks (0 = takes none) and the
// atlas's alpha. A look is a different damage_tex, never a different shader. The art is one
// material, so its skin swatches take damage_skin_tex (the bruises, then the blood) where its
// clothes take damage_tex (the scuffs, then the blood); a primitive's paint is one class, so
// it never reads damage_skin_tex. Unset, damage_skin_tex is fully transparent (a clean skin).
uniform sampler2D damage_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_skin_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
// The clothes' scuffs for a swatch that takes no blood (the atlas alpha class 230: the Punk's cap, laces and strap;
// gen_palette.py "blood": false): the scuffed tile at the bruised look and the bloodied one, where damage_tex is
// the blood. Unset it is transparent: such a swatch shows nothing.
uniform sampler2D damage_scuff_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
// The blood's hard edge (M6 D6): above 0 the blood look's alpha is cut at this value with an edge one pixel wide,
// so a blob is the red and the ink and nothing between (a soft alpha over a yellow cap read orange). 0 = off
// (the look sets it with the bloodied look only: DamageLook.apply_art, vfx_blood_edge_cut).
uniform float blood_edge : hint_range(0.0, 1.0) = 0.0;
uniform float damage_scale : hint_range(0.1, 20.0) = 2.5;
uniform float marks : hint_range(0.0, 1.0) = 0.0;
uniform bool use_rest_custom = false;
// The edge pass's tag, written as ROUGHNESS: 0 on a surface that has its own hull (the pass
// skips its silhouette), 1 elsewhere.
uniform float edge_tag : hint_range(0.0, 1.0) = 1.0;

varying vec3 mark_pos;
varying vec3 mark_normal;

// The one swatch-gloss decode (ToonMaterials.swatch_glossy() mirrors it): the atlas alpha's class
// (255 clothes, 230 clothes without blood, 204 skin, 128 none: read by the 0.95, 0.85 and 0.75 thresholds)
// minus exactly one step is glossy (any other alpha, a transparent texel, say, is matte).
float swatch_gloss(float alpha) {
	float a8 = floor(alpha * 255.0 + 0.5);
	float class_a8 = alpha > 0.95 ? 255.0 : (alpha > 0.85 ? 230.0 : (alpha > 0.75 ? 204.0 : 128.0));
	return 1.0 - step(0.5, abs(class_a8 - a8 - 1.0));
}

// The triplanar of `tex` at p (the three planes' coordinates, each with its own screen derivatives, which the
// caller took outside the class branch so the mip level stays right) blended by the normal's weights w.
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
	// The share of the hard highlight this surface takes (toon_light.gdshaderinc multiplies it in) and
	// whether it also takes the camera-fixed glint: a flat-painted surface takes the material's own
	// highlight (spec_gloss: 1 matte, more glossy) and no glint; the art's swatches take both only
	// where the atlas says glossy, so the vest, denim, cap and skin stay matte and the lens glints.
	swatch_spec = 1.0;
	swatch_glint = 0.0;
	glint_gate = 1.0;
	if (use_albedo_tex) {
		vec4 swatch = texture(albedo_tex, UV);
		if (use_detail_tex && use_texel_swatch) {
			vec2 texels = UV2 * vec2(textureSize(detail_tex, 0));
			// the derivatives come before the branch (they are undefined in a non-uniform one)
			float texels_per_pixel = max(length(dFdx(texels)), length(dFdy(texels)));
			float code = texelFetch(detail_tex, clamp(ivec2(texels), ivec2(0), textureSize(detail_tex, 0) - 1), 0).b;
			if (code > 0.0) {
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
	if (use_detail_tex) {
		float ink_mask = texture(detail_tex, UV2).r;
		if (detail_sharp) {
			float edge = max(0.5 * fwidth(ink_mask), 0.0001);
			ink_mask = smoothstep(detail_cut - edge, detail_cut + edge, ink_mask);
		}
		color = mix(color, ink, ink_mask * detail_strength);
		// The glint gate: an art with a mask lets its glossy swatch glint only on the streaks the mask's G
		// authors, cut at 0.5 with the same one-pixel edge (the field is a distance ramp, so the cut is sharp).
		// Without a mask the glint is the whole glossy swatch's.
		float streak = texture(detail_tex, UV2).g;
		float streak_edge = max(0.5 * fwidth(streak), 0.0001);
		glint_gate = smoothstep(0.5 - streak_edge, 0.5 + streak_edge, streak);
	}
	if (takes_marks > 0.0) {
		vec3 w = abs(normalize(mark_normal));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 p = mark_pos * damage_scale;
		vec3 dpdx = dFdx(p);
		vec3 dpdy = dFdy(p);
		// One class per swatch (the atlas is sampled nearest), so one triplanar: the skin's tile, the clothes'
		// scuffs where a swatch takes no blood, or the clothes' (the scuffs, then the blood).
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
