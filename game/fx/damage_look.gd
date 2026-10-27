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
## The art is one material with one damage texture, so it shows the clothes' tiles at both
## levels (scuffs, then blood): there is no skin mask in the palette to tell it where the skin is.
## Materials only: no mesh, pose or hurtbox changes. The hit flash (the contact flash's
## overlay pass, the parry's emission) still covers the marks.
## A look is a swap of the `damage_tex` uniform and `damage_scale` only: the shader, and every
## other uniform, stays. (On the StandardMaterial3Ds this replaced, switching the detail layer
## on changed the shader variant and cost 3-12 ms on the first bruise; that is why the texture
## slot is filled from the start, with a fully transparent texture (VfxArt.clear_detail())
## standing for clean, which mixes in nothing.)

enum Level { CLEAN, BRUISED, BLOODIED }

## TuningData properties that change how a look is drawn or chosen.
const TUNABLES: Array[StringName] = [&"vfx_bruised_at", &"vfx_bloodied_at", &"vfx_damage_tile_m"]


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
	material.set_shader_parameter(&"damage_scale", _scale())


## Show `level` on `material`, a part painted `paint`. Swaps the damage texture and the tile
## scale only; clean is the transparent texture.
static func apply(material: ShaderMaterial, paint: int, level: int) -> void:
	if not bruisable(paint):
		return
	var tex := texture_for(paint, level)
	material.set_shader_parameter(&"damage_tex", tex if tex else VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", _scale())


## Show `level` on the skinned art's `material` (one texture for the whole body: the clothes').
static func apply_art(material: ShaderMaterial, level: int) -> void:
	var tex := texture_for(PlaceholderBody.Paint.BODY, level)
	material.set_shader_parameter(&"damage_tex", tex if tex else VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", _scale())


## The shader's `damage_scale`: tiles per metre.
static func _scale() -> float:
	return 1.0 / maxf(Tuning.data.vfx_damage_tile_m, 0.01)
