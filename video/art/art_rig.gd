class_name CineArtRig
extends Node
## The work of a VideoArtLook (video/art/video_art_look.gd): each frame, any character mesh of the art group that is new gets the
## video mesh and its skin in place of the game's (same meshes, bones and weights; a new UV2 layout, the face's normals of the Punk and Ox, and the player's
## arms relaxed, subdivided and smoothed: tools/video/blender_asset.py) and the paint and
## ink textures on its material. A character that spawns later is adopted on the next frame. The textures only show once LD-INK's
## cine_toon shader is on the material; on the game's own toon material the uniforms are unused.

const TOON_SHADER_PATH := "res://video/shaders/cine_toon.gdshader"
const META_DONE := &"video_art"

## The edited shader, kept referenced so the edit is not lost when nothing else holds the resource (the cache drops it).
static var _layout_shader: Shader

var look: VideoArtLook

## The level's lights (not the ink rig's own rim lights), rescanned every SCAN_EVERY frames: R5-ART's silhouettes pick the one behind each figure.
const SCAN_EVERY := 30
const INK_RIM_PREFIX := "CineInkRim"
var _lights: Array[Light3D] = []
var _level: Node
var _frame: int = 0
## The silhouette values last written, by art id, for the tests: {light: Light3D or null, light_view: Vector3, ...}.
var last_silhouette: Dictionary = {}

## Per art id: {art: CharacterArt (the video copy), entry: SkinnedArt.Entry, paint: Texture2D, ink: Texture2D}, or {} when the
## character has no video files or its video GLB breaks the art contract (a warning says so once).
var _kits: Dictionary[StringName, Dictionary] = {}
## How many meshes this rig has dressed, by id, for the tests and the acts' log.
var dressed: Dictionary[StringName, int] = {}


func setup(level: Node) -> void:
	_level = level
	process_priority = -10
	if look.layout_uv:
		ensure_layout_uv()
	_adopt()


func _process(_delta: float) -> void:
	_frame += 1
	_adopt()
	if not look.silhouette_ids.is_empty():
		_update_silhouettes()


## The shader reads `texture(paint_tex, UV)` and `texture(ink_tex, UV)`: UV is the palette's swatch. Read them with UV2, the layout.
## Idempotent; true when the loaded shader now samples the layout.
static func ensure_layout_uv() -> bool:
	var shader := load(TOON_SHADER_PATH) as Shader
	if shader == null:
		return false
	_layout_shader = shader
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
			# The game's budget (30,000 triangles) is for the game's frame time; the video's player arm is subdivided (about 180,000).
			video.triangle_budget = maxi(video.triangle_budget, look.triangle_budget)
			var entry := SkinnedArt.entry_of(video)
			if entry.problems.is_empty():
				kit = {art = video, entry = entry}
			else:
				push_warning("CineArtRig: the video art of %s does not attach: %s" % [id, "; ".join(entry.problems)])
		var paint_path := dir.path_join("%s_paint.png" % id)
		var ink_path := dir.path_join("%s_ink.png" % id)
		kit["paint"] = load(paint_path) as Texture2D if ResourceLoader.exists(paint_path) else null
		kit["ink"] = load(ink_path) as Texture2D if ResourceLoader.exists(ink_path) else null
		var shade_path := dir.path_join("%s_shade.png" % id)
		kit["shade"] = load(shade_path) as Texture2D if ResourceLoader.exists(shade_path) else null
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
		if look.game_detail_off and look.paint and paint_tex != null:
			material.set_shader_parameter(&"use_detail_tex", false)
		material.set_shader_parameter(&"face_fill", look.face_fill_of(id))
		material.set_shader_parameter(&"face_fill_color", look.face_fill_color)
		material.set_shader_parameter(&"catch_strength", look.catch_strength)
		material.set_shader_parameter(&"catch_color", look.catch_color)
		material.set_shader_parameter(&"spec_gain", look.plastic_spec)
		material.set_shader_parameter(&"marks_gain", look.damage_marks)
		var shade_tex: Texture2D = kit.get("shade")
		material.set_shader_parameter(&"use_shade_tex", look.shade_map and shade_tex != null)
		if shade_tex != null:
			material.set_shader_parameter(&"shade_tex", shade_tex)
		material.set_shader_parameter(&"shade_hint_gain", look.hint_gain_of(id))
		material.set_shader_parameter(&"hatch_gain", look.hatch_gain)
		material.set_shader_parameter(&"hatch_floor", float(look.hatch_floor_by_id.get(String(id), 0.0)))
		material.set_shader_parameter(&"hatch_dist", Vector2(look.hatch_near_m, look.hatch_far_m))
		var value := float(look.value_by_id.get(String(id), 1.0))
		material.set_shader_parameter(&"albedo", Color(value, value, value, 1.0))
		material.set_shader_parameter(&"art_rim_gain", float(look.rim_gain_by_id.get(String(id), 1.0)))
	dressed[id] = dressed.get(id, 0) + 1


func _rig_of(node: Node) -> HumanoidRig:
	var up := node.get_parent()
	while up != null:
		if up is HumanoidRig:
			return up as HumanoidRig
		up = up.get_parent()
	return null


# --- R5-ART: the back-lit silhouettes ----------------------------------------------------------


func _scan_lights() -> void:
	_lights.clear()
	if _level == null:
		return
	for node in _level.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light != null and not String(light.name).begins_with(INK_RIM_PREFIX):
			_lights.append(light)


## The light most behind `at` as seen from `eye`: for each light, its energy and luminance (and its falloff, for a lamp) times how far it lies on the far
## side of the figure from the camera. Returns {light, to_light (world, a unit vector)}; light is null when nothing is behind the figure.
func light_behind(at: Vector3, eye: Vector3) -> Dictionary:
	var to_eye := (eye - at).normalized()
	var best := 0.0
	var best_light: Light3D
	var best_dir := Vector3.ZERO
	for light in _lights:
		if not is_instance_valid(light) or not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		var to_light: Vector3
		var falloff := 1.0
		if light is DirectionalLight3D:
			to_light = light.global_basis.z.normalized()
		else:
			var range_m := 0.0
			if light is OmniLight3D:
				range_m = (light as OmniLight3D).omni_range
			elif light is SpotLight3D:
				range_m = (light as SpotLight3D).spot_range
			var d := light.global_position.distance_to(at)
			if d >= range_m or d < 0.001:
				continue
			falloff = 1.0 - d / range_m
			to_light = (light.global_position - at) / d
		var behind := -to_light.dot(to_eye)
		if behind <= 0.05:
			continue
		var score := light.light_color.get_luminance() * minf(light.light_energy, 4.0) * falloff * behind
		if score > best:
			best = score
			best_light = light
			best_dir = to_light
	return {light = best_light, to_light = best_dir}


func _update_silhouettes() -> void:
	if _frame % SCAN_EVERY == 1:
		_scan_lights()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view := camera.global_transform.affine_inverse().basis
	var sun: DirectionalLight3D
	for light in _lights:
		if light is DirectionalLight3D and is_instance_valid(light) and light.light_energy > 0.0:
			sun = light as DirectionalLight3D
			break
	for node in get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_inside_tree():
			continue
		var material := mesh.material_override as ShaderMaterial
		var rig := _rig_of(mesh)
		if material == null or rig == null or rig.art == null:
			continue
		var id := rig.art.id
		var on := look.is_silhouette(id)
		material.set_shader_parameter(&"sil_on", 1.0 if on else 0.0)
		if not on:
			continue
		_push_silhouette(material, rig, id, camera, view, sun)


## The point a figure's back light is judged for: its own middle, and for the player's first-person arms the nearest other figure (the arm's light is the
## one that lights the subject from behind: the lamp ahead of the player), else 3 m ahead of the lens.
func _focus_of(rig: HumanoidRig, camera: Camera3D) -> Vector3:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not player.is_ancestor_of(rig):
		return rig.global_position + Vector3.UP * 1.0
	var best := INF
	var at := camera.global_position - camera.global_basis.z * 3.0
	for node in get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP):
		var other := _rig_of(node)
		if other == null or player.is_ancestor_of(other):
			continue
		var d := other.global_position.distance_to(camera.global_position)
		if d < best:
			best = d
			at = other.global_position + Vector3.UP * 1.0
	return at


func _push_silhouette(material: ShaderMaterial, rig: HumanoidRig, id: StringName, camera: Camera3D, view: Basis, sun: DirectionalLight3D) -> void:
	var centre := _focus_of(rig, camera)
	var found := light_behind(centre, camera.global_position)
	var light: Light3D = found.light
	var to_light_world: Vector3
	var color: Color
	if light != null:
		to_light_world = found.to_light
		var c := light.light_color
		var peak := maxf(c.r, maxf(c.g, c.b))
		color = Color(c.r / peak, c.g / peak, c.b / peak) if peak > 0.0 else Color.WHITE
		color *= look.sil_value_of(id, &"sil_rim_tint") as Color
	else:
		# Nothing behind the figure: the sun's or the moon's direction, else up and back, in the fallback colour.
		to_light_world = sun.global_basis.z.normalized() if sun != null else (Vector3.UP * 0.6 - (camera.global_basis * Vector3(0, 0, 1)) * 0.8).normalized()
		color = look.sil_value_of(id, &"sil_rim_fallback") as Color
	var up_view := view * Vector3.UP
	material.set_shader_parameter(&"sil_light_view", view * to_light_world)
	material.set_shader_parameter(&"sil_rim_color", Color(color.r, color.g, color.b, 1.0))
	material.set_shader_parameter(&"sil_up_view", up_view)
	# The moon's rim: the directional light's side, else the side opposite the light behind (in view space, mirrored left to right).
	var moon_view := view * sun.global_basis.z.normalized() if sun != null and sun != light else Vector3(-(view * to_light_world).x, 0.4, -0.3)
	material.set_shader_parameter(&"sil_moon_view", moon_view)
	for key: StringName in SIL_KEYS:
		material.set_shader_parameter(key, look.sil_value_of(id, key))
	var head := rig.skeleton.find_bone("Head") if rig.skeleton != null else -1
	var brim := 100.0
	if head >= 0:
		brim = (rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(head).origin).y + float(look.sil_value_of(id, &"sil_brim_dy"))
	material.set_shader_parameter(&"sil_brim_y", brim)
	last_silhouette[id] = {light = light, to_light = to_light_world, color = color, brim_y = brim}


## The VideoArtLook properties that are shader uniforms of the same name, written as they are.
const SIL_KEYS: Array[StringName] = [
	&"sil_fill", &"sil_fill_top", &"sil_keep", &"sil_value", &"sil_top_cut", &"sil_rim_strength", &"sil_rim_cut", &"sil_rim_key", &"sil_rim_top",
	&"sil_rim_wobble", &"sil_rim_facing", &"sil_rim_face_cut", &"sil_rim_face_band", &"sil_moon_strength", &"sil_moon_color", &"sil_moon_cut", &"sil_face_lit", &"sil_close_lit", &"sil_close_cut", &"sil_close_dist",
]
