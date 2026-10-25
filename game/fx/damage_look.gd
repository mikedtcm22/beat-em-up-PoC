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
## The detail layer never switches off: switching it changes the material's shader variant,
## and Godot drops a variant's shader once no material uses it, so the next bruise on a
## clean cast built it again (3-5 ms on the main thread plus a pipeline compile, 12 ms the
## first time in a run). prepare() turns it on when the rig's materials are built, with a
## fully transparent texture (VfxArt.clear_detail()) standing for clean, which mixes in
## nothing; apply() then swaps only that texture and the tile size, as set_flash() keeps
## emission on.

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


## Turn the always-on detail layer on for `material`, a part painted `paint` (see the top
## of this file), showing nothing: a clean look. Called once when a rig builds its
## materials, so the shader variant exists, and stays, from the start. Paints that take no
## marks keep the plain shader.
static func prepare(material: StandardMaterial3D, paint: int) -> void:
	if not bruisable(paint):
		return
	material.detail_enabled = true
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	material.uv1_triplanar = true
	material.detail_albedo = VfxArt.clear_detail()
	material.uv1_scale = Vector3.ONE / maxf(Tuning.data.vfx_damage_tile_m, 0.01)


## Show `level` on `material`, a part painted `paint`. Swaps the detail texture and the
## tile size only, never a flag that picks the shader variant; clean is the transparent
## texture. A material not prepared() yet is prepared first (once, switching its variant).
static func apply(material: StandardMaterial3D, paint: int, level: int) -> void:
	if not bruisable(paint):
		return
	if not material.detail_enabled:
		prepare(material, paint)
	var tex := texture_for(paint, level)
	material.detail_albedo = tex if tex else VfxArt.clear_detail()
	material.uv1_scale = Vector3.ONE / maxf(Tuning.data.vfx_damage_tile_m, 0.01)
