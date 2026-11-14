extends Node
## M7 SPIKE S2: renders the vantage plates of Mission 1's street (colour, with characters and FX hidden) and a distance map for each.
## godot --path . --resolution 1600x900 --fixed-fps 60 res://tests/s2/s2_plates.tscn -- --out=assets/s2 [--dump=1]

const DEPTH_SHADER := preload("res://game/level/look/s2_depth.gdshader")
## name, position (world), yaw degrees (positive turns left), pitch degrees.
const VANTAGES := [
	{name = "w0", pos = Vector3(0.0, 1.452, 0.0), yaw = 0.0, pitch = 0.0},
	{name = "a", pos = Vector3(-1.0, 1.452, -6.0), yaw = 0.0, pitch = -4.0},
	{name = "b", pos = Vector3(3.06, 1.451, -4.0), yaw = -18.5, pitch = 0.0},
	{name = "c", pos = Vector3(2.68, 1.452, -5.79), yaw = 24.0, pitch = 0.0},
]
var _out: String = "assets/s2"
var _room: LevelRoot
var _cam: Camera3D


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"look_grade_strength", 0.0)
	if S2Proj.mode() != "proj":
		Tuning.set_value(&"look_finish_on", 0)
	_room = (load("res://game/level/mission1/mission1.tscn") as PackedScene).instantiate() as LevelRoot
	_room.waves_enabled_on_start = false
	get_tree().root.add_child(_room)
	await _wait(10)
	Tuning.set_value(&"look_profile", 1)
	await _wait(10)
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	for node: Node in get_tree().root.find_children("*", "Control", true, false):
		(node as Control).visible = false
	_room.player.visible = false
	var fx := _room.find_child("StreetFx", true, false) as Node3D
	if S2Proj.mode() == "proj":
		if S2Proj.arg("walk") != "":
			_walk()
		else:
			_stills()
		return
	if fx != null:
		fx.visible = false
	if OS.get_cmdline_user_args().has("--dump=1"):
		_dump()
		get_tree().quit()
		return
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = Tuning.data.fov_deg
	_cam.near = 0.05
	_cam.far = 400.0
	get_tree().root.add_child(_cam)
	var meta: Array = []
	for v: Dictionary in VANTAGES:
		_place(v)
		await _wait(8)
		var img := get_tree().root.get_texture().get_image()
		img.save_png("%s/plate_%s.png" % [_out, v.name])
		meta.append({name = v.name, vp = _vp(), cam = [_cam.global_position.x, _cam.global_position.y, _cam.global_position.z]})
	# Depth pass.
	var meshes := S2Proj.world_meshes(_room)
	print("S2 world meshes: ", meshes.size())
	var mat := ShaderMaterial.new()
	mat.shader = DEPTH_SHADER
	for m in meshes:
		m.material_override = mat
	S2Proj.hide_decals(_room)
	var edges := Tuning.data.look_edges_enabled
	Tuning.set_value(&"look_edges_enabled", false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 1, 1)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam.environment = env
	var haze := _room.find_child("HazeQuad", true, false) as Node3D
	if haze != null:
		haze.visible = false
	for v: Dictionary in VANTAGES:
		_place(v)
		await _wait(8)
		get_tree().root.get_texture().get_image().save_png("%s/depth_%s.png" % [_out, v.name])
	Tuning.set_value(&"look_edges_enabled", edges)
	var f := FileAccess.open("%s/vantages.json" % _out, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	get_tree().quit()


## `--stills=name:x,y,z,yaw,pitch;...` with `--s2=proj`: stills of the projected street from free cameras.
func _stills() -> void:
	await _wait(20)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = Tuning.data.fov_deg
	get_tree().root.add_child(_cam)
	for spec in S2Proj.arg("stills").split(";"):
		var parts := spec.split(":")
		var n := parts[1].split(",")
		_place({pos = Vector3(float(n[0]), float(n[1]), float(n[2])), yaw = float(n[3]), pitch = float(n[4])})
		await _wait(10)
		get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [_out, parts[0]])
	get_tree().quit()


## `--walk=1` with `--s2=proj`: a scripted 3 s walk (60 frames a second) from the start through the street, turning, for the clip.
func _walk() -> void:
	await _wait(20)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = Tuning.data.fov_deg
	get_tree().root.add_child(_cam)
	for i in 190:
		var t := clampf(float(i) / 180.0, 0.0, 1.0)
		var e := t * t * (3.0 - 2.0 * t)
		var pos := Vector3(lerpf(0.0, 2.2, e), 1.452 + 0.03 * sin(float(i) * 0.22), lerpf(0.0, -6.5, e))
		var yaw := 14.0 * sin(t * PI * 1.6) - 10.0 * t
		_place({pos = pos, yaw = yaw, pitch = -2.0})
		await get_tree().process_frame
	get_tree().quit()


func _place(v: Dictionary) -> void:
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(v.pitch), deg_to_rad(v.yaw), 0.0)), v.pos)
	_cam.current = true


func _vp() -> Array:
	var p := _cam.get_camera_projection() * Projection(_cam.global_transform.affine_inverse())
	var out: Array = []
	for col in [p.x, p.y, p.z, p.w]:
		out.append([col.x, col.y, col.z, col.w])
	return out


func _dump() -> void:
	for m in _room.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var mat := mi.material_override
		var sh := ""
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
			sh = (mat as ShaderMaterial).shader.resource_path
		var chain := ""
		var n: Node = mi.get_parent()
		for i in 3:
			if n == null or n == _room:
				break
			chain += "%s(%s)/" % [n.name, n.get_class()]
			n = n.get_parent()
		print("MESH ", mi.name, " vis=", mi.is_visible_in_tree(), " ov=", sh, " surf=", mi.mesh.get_surface_count() if mi.mesh != null else -1, " pos=", mi.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " up=", chain)
