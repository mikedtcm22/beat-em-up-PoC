class_name RigPaint
extends RefCounted
## Everything that paints a HumanoidRig (Milestone 4): the per-paint toon materials of the
## primitive body, the skinned art's material, the hulls (the ink outline of every part and
## of the art), the whole-body parry flash, the contact flash's overlay pass, the damage look
## and the load-time warm-up. S0 moved it out of HumanoidRig; P1-toon made the materials
## ShaderMaterials of the one toon shader (game/fx/toon.gdshader, made by ToonMaterials), so a
## look, a flash or a damage mark is a uniform and never a new shader variant
## (docs/ARCHITECTURE.md "Toon shader, hull, flash and damage on toon"). The rig keeps the
## flash's aim and anchor (flash_at(), follow_flash()) and calls in here for the materials; its
## `_materials` is this object's `materials`.

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
var materials: Dictionary[int, ShaderMaterial] = {}

var _rig: HumanoidRig
## The skinned art's material, made on first use (art_material()).
var _art_material: ShaderMaterial


func _init(rig: HumanoidRig) -> void:
	_rig = rig


## Make the rig's per-paint materials (was HumanoidRig._build_materials()) and color them: the
## toon shader with a flat color per paint. The damage look's texture slot is filled from the
## start (clear), on the paints that take marks, and the whole-body flash is a uniform, so
## neither ever switches the shader variant.
func build() -> void:
	for paint: int in PlaceholderBody.Paint.values():
		var mat := ToonMaterials.character(Color.WHITE, DamageLook.bruisable(paint), paint == PlaceholderBody.Paint.DARK)
		DamageLook.prepare(mat, paint)
		materials[paint] = mat
	apply_colors()


## The primitive body's material for `paint` (PlaceholderBody.Paint).
func material(paint: int) -> Material:
	return materials[paint]


## The skinned art's toon material: the palette atlas (and the detail mask), one per rig, or
## null on a rig without art. Like the primitives', its flash is a uniform.
func art_material() -> Material:
	var art := _rig.art
	if art == null:
		return null
	if _art_material == null:
		_art_material = ToonMaterials.art(art.palette, art.detail_mask)
	return _art_material


## The inverted-hull outline for the skinned art's `material_overlay` (ToonMaterials.outline():
## shared, always on).
func outline_material() -> Material:
	return ToonMaterials.outline()


## The outline for the primitive `part`'s `material_overlay`: the hull of its shape, thinner on
## the player's own body, or null when placeholders get no hull (`look_hull_on_placeholders`).
func outline_material_for(part: PlaceholderBody.Part) -> Material:
	return ToonMaterials.outline_for_part(part.shape, _rig.first_person_body)


## Color the primitives' materials from the rig's body, accent, skin and pants colors (was
## HumanoidRig._apply_colors()). Nothing until build() has made them.
func apply_colors() -> void:
	if materials.is_empty():
		return
	materials[PlaceholderBody.Paint.BODY].set_shader_parameter(&"albedo", _rig.body_color)
	materials[PlaceholderBody.Paint.PANTS].set_shader_parameter(&"albedo",
			_rig.body_color.darkened(PANTS_DARKEN) if _rig.pants_color.a <= 0.0 else _rig.pants_color)
	materials[PlaceholderBody.Paint.ACCENT].set_shader_parameter(&"albedo", _rig.accent_color)
	materials[PlaceholderBody.Paint.SKIN].set_shader_parameter(&"albedo", _rig.skin_color)
	materials[PlaceholderBody.Paint.DARK].set_shader_parameter(&"albedo", DARK_COLOR)


## The color `paint`'s material shows: what tests read instead of the material's albedo.
func color_of(paint: int) -> Color:
	return materials[paint].get_shader_parameter(&"albedo")


## Whole-body flash, 0..1, as the toon shader's flash color times share, added over the lit
## and marked surface on every base material: the cyan parry flash (was HumanoidRig.set_flash()'s
## loop; the rig ends the contact flash first).
func set_flash(amount: float, color: Color = Color.WHITE) -> void:
	var share := clampf(amount, 0.0, 1.0)
	for base: Material in base_materials():
		var mat := base as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter(&"flash_color", color)
		mat.set_shader_parameter(&"flash_amount", share)


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
	if _art_material != null:
		DamageLook.apply_art(_art_material, level)


## Every material the body's surfaces draw with: the primitives' per paint, then the art's if
## the rig has art and it has been asked for.
func base_materials() -> Array[Material]:
	var out: Array[Material] = []
	for mat: ShaderMaterial in materials.values():
		out.append(mat)
	if _art_material != null:
		out.append(_art_material)
	return out


## Once per run, the first rig built in a window draws the overlay shader at zero strength
## (every pixel discarded) on a box at its feet under `parent` until the first contact flash,
## so the renderer compiles its pipelines at load instead of on the first hit's frame
## (measured: 4-12 ms more on it), and the toon shader with every hull for two frames
## (ToonMaterials.warm_up()). A separate mesh, so the rig's own materials carry no pass while
## idle. (Was HumanoidRig._warm_flash().)
func warm_up(parent: Node3D) -> void:
	if _flash_warmed or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_flash_warmed = true
	ToonMaterials.warm_up(parent)
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
