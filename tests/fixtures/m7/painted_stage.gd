extends Node3D
## Milestone 7, T11: a windowed still-maker for the painted fixture (not a test): three Punks in the trailer profile under a warm
## key from the left and a cool lamp, the painted fixture clean and bloodied beside the atlas art, photographed from three
## cameras into the folder given after `--out=`. Run: godot --path . res://tests/fixtures/m7/painted_stage.tscn -- --out=captures/m7-slice/t11
const BASE := "res://tests/fixtures/m7/punk_with_painted_art.tres"

var _out := "captures/m7-slice/t11"
var _camera: Camera3D
var _key_yaw := 60.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--key-yaw="):
			_key_yaw = float(arg.substr(10))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out))
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.3)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.62, 0.34)
	key.light_energy = 1.2
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-30.0, _key_yaw, 0.0)
	add_child(key)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.omni_range = 4.0
	lamp.position = Vector3(1.6, 2.2, 0.4)
	add_child(lamp)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(20, 20)
	floor_mesh.material_override = ToonMaterials.environment(Color(0.2, 0.2, 0.26))
	add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	wall.mesh = KitMesh.build(&"wall", Vector3(6.0, 3.0, 0.3))
	wall.position = Vector3(0.0, 0.0, -2.5)
	add_child(wall)
	var base := load(BASE) as CharacterArt
	var xs := [-1.2, 0.0, 1.2]
	for i in 3:
		var rig := HumanoidRig.new()
		rig.build_hurtboxes = false
		rig.art = base
		rig.art_follows_look = i != 2
		add_child(rig)
		rig.build()
		rig.position = Vector3(xs[i], 0.0, 0.0)
		rig.rotation_degrees.y = 200.0
		if i == 1:
			rig.set_damage_look(DamageLook.Level.BLOODIED)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.current = true
	var tag := "" if is_equal_approx(_key_yaw, 60.0) else "_key%d" % int(_key_yaw)
	await _shoot("wide" + tag, Vector3(0.0, 1.3, 4.2), Vector3(0.0, 1.0, 0.0))
	await _shoot("close_painted" + tag, Vector3(-0.6, 1.4, 1.6), Vector3(-1.2, 1.2, 0.0))
	await _shoot("wall" + tag, Vector3(0.0, 1.6, 0.0), Vector3(0.0, 1.4, -2.5))
	await _shoot("far" + tag, Vector3(0.0, 1.5, 9.0), Vector3(0.0, 1.0, 0.0))
	get_tree().quit()


func _shoot(label: String, from: Vector3, at: Vector3) -> void:
	_camera.position = from
	_camera.look_at(at)
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://").path_join(_out).path_join(label + ".png"))
