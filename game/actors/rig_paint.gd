class_name RigPaint
extends RefCounted
## Everything that paints a HumanoidRig (Milestone 4): the per-paint materials of the
## primitive body, the skinned art's material and outline, the whole-body parry flash, the
## contact flash's overlay pass, the damage look and the load-time warm-up. Moved out of
## HumanoidRig by S0 with no change in behaviour, so P1-toon can swap the StandardMaterial3Ds
## for toon shader materials without touching the rig (docs/ARCHITECTURE.md "Art pipeline and
## look (Milestone 4)"). The rig keeps the flash's aim and anchor (flash_at(), follow_flash())
## and calls in here for the materials; its `_materials` is this object's `materials`.

## Shades, belt, soles and hair.
const DARK_COLOR := Color(0.07, 0.07, 0.08)
## Trousers without a pants_color of their own are body_color darkened by this much.
const PANTS_DARKEN := 0.45
## The contact flash's overlay shader (HumanoidRig.flash_at() makes the material).
const FLASH_SHADER := preload("res://game/fx/hit_flash.gdshader")

## The contact flash has been warmed up this run, and the box warming it until the first
## contact flash (warm_up(), end_warm_up()).
static var _flash_warmed: bool = false
static var _flash_warm_box: MeshInstance3D

## Paint (PlaceholderBody.Paint) -> material, one set per rig so flashes stay per actor.
## HumanoidRig._materials is this same dictionary.
var materials: Dictionary[int, StandardMaterial3D] = {}

var _rig: HumanoidRig
## The skinned art's material, made on first use (art_material()).
var _art_material: StandardMaterial3D


func _init(rig: HumanoidRig) -> void:
	_rig = rig


## Make the rig's per-paint materials (was HumanoidRig._build_materials()) and color them.
func build() -> void:
	for paint: int in PlaceholderBody.Paint.values():
		var mat := StandardMaterial3D.new()
		mat.roughness = 1.0
		mat.metallic_specular = 0.2
		# Emission stays enabled (black-energy) so set_flash() never switches shader variants.
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0
		# Likewise the damage look's detail layer (transparent while clean), on the paints that
		# take marks, so a look change swaps a texture and never the shader variant.
		DamageLook.prepare(mat, paint)
		materials[paint] = mat
	apply_colors()


## The primitive body's material for `paint` (PlaceholderBody.Paint).
func material(paint: int) -> Material:
	return materials[paint]


## The skinned art's material: the palette atlas (and the detail mask), one per rig, or null
## on a rig without art. A plain textured material until P1-toon makes the toon one; like the
## primitives', its emission is on at zero energy so the parry flash never switches variants.
func art_material() -> Material:
	var art := _rig.art
	if art == null:
		return null
	if _art_material == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = art.palette
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 1.0
		mat.metallic_specular = 0.2
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0
		_art_material = mat
	return _art_material


## The inverted-hull outline for the skinned art's `material_overlay`, or null for none. The
## stub has none.
func outline_material() -> Material:
	return null


## The outline for the primitive `part`'s `material_overlay`, or null for none. The stub has
## none.
func outline_material_for(_part: PlaceholderBody.Part) -> Material:
	return null


## Color the primitives' materials from the rig's body, accent, skin and pants colors (was
## HumanoidRig._apply_colors()). Nothing until build() has made them.
func apply_colors() -> void:
	if materials.is_empty():
		return
	materials[PlaceholderBody.Paint.BODY].albedo_color = _rig.body_color
	materials[PlaceholderBody.Paint.PANTS].albedo_color = \
			_rig.body_color.darkened(PANTS_DARKEN) if _rig.pants_color.a <= 0.0 else _rig.pants_color
	materials[PlaceholderBody.Paint.ACCENT].albedo_color = _rig.accent_color
	materials[PlaceholderBody.Paint.SKIN].albedo_color = _rig.skin_color
	materials[PlaceholderBody.Paint.DARK].albedo_color = DARK_COLOR


## The color `paint`'s material shows: what tests read instead of the material's albedo.
func color_of(paint: int) -> Color:
	return materials[paint].albedo_color


## Whole-body flash, 0..1, as emission on every base material: the cyan parry flash (was
## HumanoidRig.set_flash()'s loop; the rig ends the contact flash first).
func set_flash(amount: float, color: Color = Color.WHITE) -> void:
	var energy := clampf(amount, 0.0, 1.0)
	for base: Material in base_materials():
		var mat := base as StandardMaterial3D
		if mat == null:
			continue
		mat.emission = color
		mat.emission_energy_multiplier = energy


## Put the contact flash's `overlay` pass on every base material (the art's too) as its
## next_pass, or take it off (was HumanoidRig._show_flash_overlay()'s loop). The outline is
## never on next_pass: it goes on material_overlay.
func show_flash_overlay(on: bool, overlay: Material) -> void:
	for base: Material in base_materials():
		base.next_pass = overlay if on else null


## The damage look `level` (DamageLook.Level) on the primitives (was
## HumanoidRig.set_damage_look()'s loop): marks as a swap of the detail texture.
func set_damage_look(level: int) -> void:
	for paint: int in materials:
		DamageLook.apply(materials[paint], paint, level)


## Every material the body's surfaces draw with: the primitives' per paint, then the art's if
## the rig has art and it has been asked for.
func base_materials() -> Array[Material]:
	var out: Array[Material] = []
	for mat: StandardMaterial3D in materials.values():
		out.append(mat)
	if _art_material != null:
		out.append(_art_material)
	return out


## Once per run, the first rig built in a window draws the overlay shader at zero strength
## (every pixel discarded) on a box at its feet under `parent` until the first contact flash,
## so the renderer compiles its pipelines at load instead of on the first hit's frame
## (measured: 4-12 ms more on it). A separate mesh, so the rig's own materials carry no pass
## while idle. (Was HumanoidRig._warm_flash().)
func warm_up(parent: Node3D) -> void:
	if _flash_warmed or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_flash_warmed = true
	var warm := MeshInstance3D.new()
	warm.name = "FlashWarmUp"
	warm.mesh = BoxMesh.new()
	warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	warm.material_override = mat
	parent.add_child(warm)
	_flash_warm_box = warm


## The first contact flash of the run has its own pipeline built: drop the warm-up box.
static func end_warm_up() -> void:
	if is_instance_valid(_flash_warm_box):
		_flash_warm_box.queue_free()
	_flash_warm_box = null
