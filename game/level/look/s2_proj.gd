class_name S2Proj
extends Node
## M7 SPIKE S2 (throwaway): the camera-projected painted street. Modes via `--s2=<mode>` after `--`:
##   pose  log the active camera's world transform every physics frame to `--s2out=<file>`.
##   proj  project the painted plates (res://assets/s2/plate_<i>.png + depth_<i>.exr + vantages.json) onto the world.

static func mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--s2="):
			return arg.substr(5)
	return ""

static func arg(key: String, fallback: String = "") -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return fallback

var _file: FileAccess

const PROJ_SHADER := preload("res://game/level/look/s2_proj.gdshader")
var _material: ShaderMaterial
var _post: Array[LookPost] = []
var _level: Node3D


func _ready() -> void:
	if mode() == "pose":
		_file = FileAccess.open(arg("s2out", "/tmp/s2_pose.csv"), FileAccess.WRITE)
	elif mode() == "proj":
		_setup.call_deferred()
	set_physics_process(true)


static func _tex(path: String, mips: bool) -> ImageTexture:
	var img := Image.load_from_file(path)
	if mips:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _setup() -> void:
	var level := get_parent().get_parent() as Node3D
	var dir := arg("s2dir", "res://assets/s2")
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string("%s/vantages.json" % dir))
	_material = ShaderMaterial.new()
	_material.shader = PROJ_SHADER
	for i in meta.size():
		var m: Dictionary = meta[i]
		var cols: Array = m.vp
		var p := Projection(Vector4(cols[0][0], cols[0][1], cols[0][2], cols[0][3]), Vector4(cols[1][0], cols[1][1], cols[1][2], cols[1][3]),
			Vector4(cols[2][0], cols[2][1], cols[2][2], cols[2][3]), Vector4(cols[3][0], cols[3][1], cols[3][2], cols[3][3]))
		_material.set_shader_parameter("vp%d" % i, p)
		_material.set_shader_parameter("cam%d" % i, Vector3(m.cam[0], m.cam[1], m.cam[2]))
		_material.set_shader_parameter("plate%d" % i, _tex("%s/paint_%s.jpg" % [dir, m.name], true))
		_material.set_shader_parameter("dist%d" % i, _tex("%s/depth_%s.png" % [dir, m.name], false))
	_material.set_shader_parameter("debug_cover", float(arg("s2debug", "0")))
	_level = level
	_apply()


func _apply() -> void:
	var count := 0
	for mi in world_meshes(_level):
		if mi.material_override != _material:
			mi.material_override = _material
			count += 1
	hide_decals(_level)
	if count > 0:
		print("S2 projected on %d more meshes at f%d" % [count, Engine.get_physics_frames()])


## The night dressing's transparent decals and the haze: painted in.
static func hide_decals(root: Node) -> void:
	var keep := {}
	for mi in world_meshes(root):
		keep[mi] = true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if keep.has(mi):
			continue
		var n: Node = mi
		var is_actor := false
		while n != null:
			if n is CombatActor or n is StreetFx or n is PlayerCharacter:
				is_actor = true
			n = n.get_parent()
		if not is_actor and (mi.get_parent() is NightStreet or mi.name == &"HazeQuad" or String(mi.name).contains("Shadow")):
			mi.visible = false

func _physics_process(_d: float) -> void:
	if _material != null:
		if _level != null and Engine.get_physics_frames() % 10 == 0:
			_apply()
		if _post.is_empty():
			for node in get_tree().root.find_children("*", "LookPost", true, false):
				_post.append(node as LookPost)
		for post in _post:
			var mat := post.get(&"_material") as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter(&"world_lines", 0.0)
	if _file != null:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var t := cam.global_transform
			var q := t.basis.get_euler()
			_file.store_line("%d,%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.2f" % [Engine.get_physics_frames(), t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, cam.fov])
			_file.flush()


## The meshes of the world the painting is projected on: everything but actors, the player, the street's effects and the
## transparent decals of the night dressing (pools, halos, shafts, window glow, the wash, contact shadows).
const SKIP_SHADERS := ["halo", "shaft", "pool", "window_glow", "skyline_wash", "contact_shadow", "haze", "street_"]

static func world_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		if _is_skipped(mi):
			continue
		out.append(mi)
	return out


static func _is_skipped(mi: MeshInstance3D) -> bool:
	if String(mi.name).contains("Shadow") or String(mi.name).contains("Contact"):
		return true
	var ov := mi.material_override as ShaderMaterial
	if ov != null and ov.shader != null:
		for key: String in SKIP_SHADERS:
			if ov.shader.resource_path.contains(key):
				return true
	var n: Node = mi
	while n != null:
		if n is CombatActor or n is StreetFx or n is LookPost or n is PlayerCharacter or n is Camera3D:
			return true
		n = n.get_parent()
	return false
