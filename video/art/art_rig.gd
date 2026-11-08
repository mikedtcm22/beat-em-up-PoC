class_name CineArtRig
extends Node
## The work of a VideoArtLook (video/art/video_art_look.gd): each frame, any character mesh of the art group that is new gets the
## video mesh and its skin in place of the game's (same meshes, weights and UVs: only the face's normals differ) and the paint and
## ink textures on its material. A character that spawns later is adopted on the next frame. The textures only show once LD-INK's
## cine_toon shader is on the material; on the game's own toon material the uniforms are unused.

const TOON_SHADER_PATH := "res://video/shaders/cine_toon.gdshader"
const META_DONE := &"video_art"

var look: VideoArtLook
## Per art id: {art: CharacterArt (the video copy), entry: SkinnedArt.Entry, paint: Texture2D, ink: Texture2D}, or {} when the
## character has no video files or its video GLB breaks the art contract (a warning says so once).
var _kits: Dictionary[StringName, Dictionary] = {}
## How many meshes this rig has dressed, by id, for the tests and the acts' log.
var dressed: Dictionary[StringName, int] = {}


func setup(_level: Node) -> void:
	process_priority = -10
	if look.layout_uv:
		ensure_layout_uv()
	_adopt()


func _process(_delta: float) -> void:
	_adopt()


## The shader reads `texture(paint_tex, UV)` and `texture(ink_tex, UV)`: UV is the palette's swatch. Read them with UV2, the layout.
## Idempotent; true when the loaded shader now samples the layout.
static func ensure_layout_uv() -> bool:
	var shader := load(TOON_SHADER_PATH) as Shader
	if shader == null:
		return false
	var code := shader.code
	if code.contains("texture(paint_tex, UV)") or code.contains("texture(ink_tex, UV)"):
		shader.code = code.replace("texture(paint_tex, UV)", "texture(paint_tex, UV2)").replace("texture(ink_tex, UV)", "texture(ink_tex, UV2)")
	return shader.code.contains("texture(paint_tex, UV2)") and shader.code.contains("texture(ink_tex, UV2)")


## The kit (video art, paint, ink) of an art id, made on first use from the game's own CharacterArt `base`.
func kit_of(id: StringName, base: CharacterArt) -> Dictionary:
	if _kits.has(id):
		return _kits[id]
	var kit := {}
	var dir := look.art_dir.path_join(String(id))
	if look.characters.has(String(id)):
		kit = {}
		var glb := dir.path_join("%s_video.glb" % id)
		# A character whose mesh needs no change (the player's: no face in first person) has no video GLB: textures only.
		if ResourceLoader.exists(glb):
			var video := base.duplicate() as CharacterArt
			video.scene = load(glb) as PackedScene
			var entry := SkinnedArt.entry_of(video)
			if entry.problems.is_empty():
				kit = {art = video, entry = entry}
			else:
				push_warning("CineArtRig: the video art of %s does not attach: %s" % [id, "; ".join(entry.problems)])
		var paint_path := dir.path_join("%s_paint.png" % id)
		var ink_path := dir.path_join("%s_ink.png" % id)
		kit["paint"] = load(paint_path) as Texture2D if ResourceLoader.exists(paint_path) else null
		kit["ink"] = load(ink_path) as Texture2D if ResourceLoader.exists(ink_path) else null
	_kits[id] = kit
	return kit


func _adopt() -> void:
	for node in get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_inside_tree() or mesh.has_meta(META_DONE):
			continue
		var rig := _rig_of(mesh)
		if rig == null or rig.art == null:
			continue
		mesh.set_meta(META_DONE, true)
		dress(mesh, rig)


## Put the video art on `mesh` (a skinned art mesh of `rig`).
func dress(mesh: MeshInstance3D, rig: HumanoidRig) -> void:
	var id := rig.art.id
	var kit := kit_of(id, rig.art)
	if kit.is_empty():
		return
	if look.swap_meshes and kit.has("entry"):
		var entry: SkinnedArt.Entry = kit.entry
		for part: SkinnedArt.ArtMesh in entry.meshes:
			if mesh.name == StringName("Art%s" % part.node_name):
				mesh.mesh = part.mesh
				mesh.skin = SkinnedArt.skin_of(part, rig.rig_scale())
	var material := mesh.material_override as ShaderMaterial
	if material != null:
		var paint_tex: Texture2D = kit.get("paint")
		var ink_tex: Texture2D = kit.get("ink")
		material.set_shader_parameter(&"use_paint_tex", look.paint and paint_tex != null)
		if paint_tex != null:
			material.set_shader_parameter(&"paint_tex", paint_tex)
		material.set_shader_parameter(&"use_ink_tex", look.ink and ink_tex != null)
		if ink_tex != null:
			material.set_shader_parameter(&"ink_tex", ink_tex)
		material.set_shader_parameter(&"ink_strength", look.ink_strength)
	dressed[id] = dressed.get(id, 0) + 1


func _rig_of(node: Node) -> HumanoidRig:
	var up := node.get_parent()
	while up != null:
		if up is HumanoidRig:
			return up as HumanoidRig
		up = up.get_parent()
	return null
