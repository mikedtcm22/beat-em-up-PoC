shader_type spatial;
// The one toon shader (Milestone 4, docs/ARCHITECTURE.md "Toon shader, hull, flash and damage
// on toon"): the placeholder characters' flat paints, the skinned art's palette atlas, the
// pipe and the room's boxes. One shader for all of them, so a switch of look, flash or damage
// never changes the shader variant (a switch would compile one mid-fight): they are uniforms.
// The lighting is toon_light.gdshaderinc's; the hull outline is toon_outline.gdshader's (on
// the mesh's material_overlay); the contact flash is hit_flash.gdshader's (next_pass).
render_mode ambient_light_disabled;

#include "res://game/fx/toon_light.gdshaderinc"

// The flat color (a placeholder paint, a prop, a wall), tinting the atlas when one is used.
uniform vec4 albedo : source_color = vec4(1.0);
// The art's palette atlas (256x16, each face's UV on its swatch's centre; the alpha is the
// swatch's damage class: 1.0 takes the clothes' marks, 0.8 the skin's (damage_skin_tex), 0.5 none).
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform bool use_albedo_tex = false;
// The art's optional detail mask on UV2: R = ink lines (seams, wraps, stitching), never shading.
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_disable;
uniform bool use_detail_tex = false;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
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
uniform float damage_scale : hint_range(0.1, 20.0) = 2.5;
uniform float marks : hint_range(0.0, 1.0) = 0.0;
uniform bool use_rest_custom = false;
// The edge pass's tag, written as ROUGHNESS: 0 on a surface that has its own hull (the pass
// skips its silhouette), 1 elsewhere.
uniform float edge_tag : hint_range(0.0, 1.0) = 1.0;

varying vec3 mark_pos;
varying vec3 mark_normal;

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
	if (use_albedo_tex) {
		vec4 swatch = texture(albedo_tex, UV);
		color *= swatch.rgb;
		takes_marks *= step(0.75, swatch.a);
		skin_marks = 1.0 - step(0.9, swatch.a);
	}
	if (use_detail_tex) {
		color = mix(color, ink, texture(detail_tex, UV2).r * detail_strength);
	}
	if (takes_marks > 0.0) {
		vec3 w = abs(normalize(mark_normal));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 p = mark_pos * damage_scale;
		vec4 d = texture(damage_tex, p.zy) * w.x + texture(damage_tex, p.xz) * w.y + texture(damage_tex, p.xy) * w.z;
		vec4 d_skin = texture(damage_skin_tex, p.zy) * w.x + texture(damage_skin_tex, p.xz) * w.y + texture(damage_skin_tex, p.xy) * w.z;
		d = mix(d, d_skin, skin_marks);
		color = mix(color, d.rgb, d.a * takes_marks);
	}
	ALBEDO = color;
	ROUGHNESS = edge_tag;
	EMISSION = flash_color * flash_amount;
}
