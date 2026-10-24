class_name DamageLook
extends RefCounted
## Damage you can see (Spec §6): an enemy's materials step from clean to bruised to
## bloodied as its health falls (Tuning.vfx_bruised_at, vfx_bloodied_at: 66% and 33%).
## Applied by HumanoidRig.set_damage_look() to the rig's per-paint materials, as a detail
## texture mixed over the flat albedo and mapped triplanar in each part's own space, so the
## marks ride the body. No red before the blood (Spec §10 keeps red for blood):
##   bruised    the skin darkens and takes big comic bruises (damage_bruised.png); the
##              clothes, cap and shoes take dirt, scuffs and tears (damage_scuffed.png);
##   bloodied   the same with blood splats over both (damage_bloodied.png on the skin,
##              damage_blood.png on the clothes). Shades, belts and soles stay.
## Materials only: no mesh, pose or hurtbox changes. The hit flash (the contact flash's
## overlay pass, the parry's emission) still covers the marks.

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


## Show `level` on `material`, a part painted `paint`. Clean switches the detail layer (and
## the triplanar mapping) off again, back to the material's original shader.
static func apply(material: StandardMaterial3D, paint: int, level: int) -> void:
	var tex := texture_for(paint, level)
	if tex == null:
		material.detail_enabled = false
		material.detail_albedo = null
		material.uv1_triplanar = false
		return
	material.detail_enabled = true
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	material.detail_albedo = tex
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / maxf(Tuning.data.vfx_damage_tile_m, 0.01)
