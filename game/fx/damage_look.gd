class_name DamageLook
extends RefCounted
## Damage you can see (Spec §6): an enemy's materials step from clean to bruised to
## bloodied as its health falls (Tuning.vfx_bruised_at, vfx_bloodied_at: 66% and 33%).
## Applied by HumanoidRig.set_damage_look() (through RigPaint) to the rig's toon materials, as a
## damage texture (the toon shader's `damage_tex`) mixed over the flat color and mapped triplanar
## in each part's own space (the art's: its rest-pose position and normal, in CUSTOM0/1), so the
## marks ride the body. No red before the blood (Spec §10 keeps red for blood):
##   bruised    the skin darkens and takes big comic bruises (damage_bruised.png); the
##              clothes, cap and shoes take dirt, scuffs and tears (damage_scuffed.png);
##   bloodied   the same with blood splats over both (damage_bloodied.png on the skin,
##              damage_blood.png on the clothes). Shades, belts and soles stay.
## The art is one material, but its palette atlas says where the skin is (the alpha class of the
## skin swatches, tools/pipeline/gen_palette.py): the clothes take `damage_tex` (scuffs, then
## blood), the skin takes `damage_skin_tex` (the bruises, then the blood), the primitives' tiles.
## Per swatch (M6 D6): the atlas also says which clothes take no blood ("blood": false in the palette JSON, alpha
## class 230: the Punk's cap, laces and strap). Those show the scuffs at both looks (`damage_scuff_tex`), and the
## blood everywhere else is cut hard at `vfx_blood_edge_cut` (`blood_edge`), so no soft red-over-yellow orange.
## `look_marks_per_swatch` off gives M4's look back (the blood tile on every clothes swatch, soft).
## Materials only: no mesh, pose or hurtbox changes. The hit flash (the contact flash's
## overlay pass, the parry's emission) still covers the marks.
## A look is a swap of the `damage_tex` uniform (and the art's `damage_skin_tex`) and `damage_scale`
## only: the shader, and every other uniform, stays. (On the StandardMaterial3Ds this replaced,
## switching the detail layer on changed the shader variant and cost 3-12 ms on the first bruise;
## that is why the texture slot is filled from the start, with a fully transparent texture
## (VfxArt.clear_detail()) standing for clean, which mixes in nothing.)

enum Level { CLEAN, BRUISED, BLOODIED }

## TuningData properties that change how a look is drawn or chosen.
const TUNABLES: Array[StringName] = [&"vfx_bruised_at", &"vfx_bloodied_at", &"vfx_damage_tile_m",
		&"vfx_blood_edge_cut", &"look_marks_per_swatch"]


## The look for a health share (health / max health, 0..1).
static func level_for(health_share: float) -> int:
	if health_share <= Tuning.data.vfx_bloodied_at:
		return Level.BLOODIED
	if health_share <= Tuning.data.vfx_bruised_at:
		return Level.BRUISED
	return Level.CLEAN


## The detail texture a part painted `paint` (PlaceholderBody.Paint) shows at `level`, or
## null for none.
static func texture_for(paint: int, level: int) -> Texture2D:
	if level <= Level.CLEAN:
		return null
	match paint:
		PlaceholderBody.Paint.SKIN:
			return VfxArt.texture(&"damage_bruised" if level == Level.BRUISED else &"damage_bloodied")
		PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT:
			return VfxArt.texture(&"damage_blood" if level >= Level.BLOODIED else &"damage_scuffed")
	return null


## True for the paints that take marks: the skin and the clothes (body, pants, accent). The
## dark paint (shades, belts, soles) never shows a look.
static func bruisable(paint: int) -> bool:
	return paint == PlaceholderBody.Paint.SKIN or paint == PlaceholderBody.Paint.BODY \
			or paint == PlaceholderBody.Paint.PANTS or paint == PlaceholderBody.Paint.ACCENT


## Set up `material` (a toon material), a part painted `paint`, to show nothing: a clean look.
## Called once when a rig builds its materials. Paints that take no marks keep `marks` at 0.
static func prepare(material: ShaderMaterial, paint: int) -> void:
	if not bruisable(paint):
		return
	material.set_shader_parameter(&"marks", 1.0)
	material.set_shader_parameter(&"damage_tex", VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_skin_tex", VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", _scale())


## Show `level` on `material`, a part painted `paint`. Swaps the damage texture and the tile
## scale only; clean is the transparent texture.
static func apply(material: ShaderMaterial, paint: int, level: int) -> void:
	if not bruisable(paint):
		return
	var tex := texture_for(paint, level)
	material.set_shader_parameter(&"damage_tex", tex if tex else VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", _scale())


## Show `level` on the skinned art's `material`: the clothes' tiles in `damage_tex`, the skin's
## in `damage_skin_tex` and the scuffs a no-blood swatch keeps in `damage_scuff_tex`; the shader picks
## one by the swatch's alpha class (toon.gdshader). Clean is the transparent texture in all three.
## The blood's hard edge is on with the bloodied look only.
static func apply_art(material: ShaderMaterial, level: int) -> void:
	var clothes := texture_for(PlaceholderBody.Paint.BODY, level)
	var skin := texture_for(PlaceholderBody.Paint.SKIN, level)
	var per_swatch := Tuning.data.look_marks_per_swatch
	var scuffs := texture_for(PlaceholderBody.Paint.BODY, mini(level, Level.BRUISED)) if per_swatch else clothes
	material.set_shader_parameter(&"damage_tex", clothes if clothes else VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_skin_tex", skin if skin else VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scuff_tex", scuffs if scuffs else VfxArt.clear_detail())
	material.set_shader_parameter(&"blood_edge", Tuning.data.vfx_blood_edge_cut if per_swatch and level >= Level.BLOODIED else 0.0)
	material.set_shader_parameter(&"damage_scale", _scale())


## The tile the skinned art shows at `level` on a swatch whose atlas alpha is `alpha`, as toon.gdshader
## chooses it (a CPU mirror of the shader's class branch, which the tests read the real atlas through):
## null for a swatch that takes no marks (alpha under 0.75) or a clean look, the skin's tile (0.75 up to
## 0.85), the clothes' scuffs for a swatch that takes no blood (0.85 up to 0.95: `"blood": false`, the
## Punk's cap) and the clothes' (the scuffs, then the blood) from 0.95.
static func art_tile_for_alpha(alpha: float, level: int) -> Texture2D:
	if alpha < 0.75:
		return null
	if alpha < 0.85:
		return texture_for(PlaceholderBody.Paint.SKIN, level)
	if alpha < 0.95 and Tuning.data.look_marks_per_swatch:
		return texture_for(PlaceholderBody.Paint.BODY, mini(level, Level.BRUISED))
	return texture_for(PlaceholderBody.Paint.BODY, level)


## The shader's `damage_scale`: tiles per metre.
static func _scale() -> float:
	return 1.0 / maxf(Tuning.data.vfx_damage_tile_m, 0.01)
