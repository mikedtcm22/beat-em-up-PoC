extends Node3D
## Milestone 7 (r0): a recording stage for any character's trailer art (not a test). The generic form of punk_trailer_stage.gd: the art comes
## from the command line, so a new enemy needs no stage of its own (docs/milestones/M7-calls/recipe.md). Run it through Movie Maker:
##   godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 400 res://tests/fixtures/m7/trailer_stage.tscn -- \
##       --art=res://game/actors/art/thug_art.tres --head=1.6
## Arguments: --art=<CharacterArt .tres> (default the Punk), --head=<head height in m> (default 1.66), --profile=m6 (the same stage under the m6 look).
## The shots, each held SHOT_HOLD frames, with a STAGE line giving the frame each starts on (cut the still SHOT_HOLD / 2 frames in):
##   turn 0..7  the whole body, a 45 degree yaw step each; face_<clean|bruised|bloodied>_<front|q45>  the head fills the frame;
##   torso      the chest and vest from a three-quarter angle (the rim's width on a large dark form).
const DEFAULT_ART := "res://game/actors/art/punk_art.tres"
const DEFAULT_HEAD := 1.66
## The rig faces -Z; the camera looks down it from +Z, so this yaw shows the front.
const FACE_YAW := 180.0
const SHOT_HOLD := 10
const TURN_STEPS := 8

var _frame := 0
var _hero: HumanoidRig
var _camera: Camera3D
var _head := DEFAULT_HEAD
var _shots: Array[Dictionary] = []


func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback


func _ready() -> void:
	var profile := LookProfile.Id.M6 if OS.get_cmdline_user_args().has("--profile=m6") else LookProfile.Id.TRAILER
	Tuning.set_value(&"look_profile", profile)
	_head = float(_arg("--head", str(DEFAULT_HEAD)))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.3, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.4)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.62, 0.34)
	key.light_energy = 1.3
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-30.0, 60.0, 0.0)
	add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	floor_mesh.material_override = ToonMaterials.environment(Color(0.5, 0.4, 0.42))
	add_child(floor_mesh)
	var art := load(_arg("--art", DEFAULT_ART)) as CharacterArt
	_hero = HumanoidRig.new()
	_hero.build_hurtboxes = false
	_hero.art = art
	add_child(_hero)
	_hero.build()
	_hero.play(&"idle", 0.0)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true
	for step in TURN_STEPS:
		_shots.append({"name": "turn %d" % step, "yaw": FACE_YAW + 45.0 * step, "from": Vector3(0.0, 1.05, 3.4), "at": Vector3(0.0, 0.95, 0.0), "level": DamageLook.Level.CLEAN})
	var face_from := Vector3(0.0, _head + 0.02, 0.8)
	var face_at := Vector3(0.0, _head - 0.04, 0.0)
	for level: int in [DamageLook.Level.CLEAN, DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
		var lname: String = ["clean", "bruised", "bloodied"][level]
		_shots.append({"name": "face_%s_front" % lname, "yaw": FACE_YAW, "from": face_from, "at": face_at, "level": level})
		_shots.append({"name": "face_%s_q45" % lname, "yaw": FACE_YAW + 40.0, "from": face_from, "at": face_at, "level": level})
	_shots.append({"name": "torso", "yaw": FACE_YAW + 30.0, "from": Vector3(0.0, _head - 0.3, 1.4), "at": Vector3(0.0, _head - 0.4, 0.0), "level": DamageLook.Level.CLEAN})
	print("STAGE worn art: ", _hero.worn_art().id, " painted: ", ToonMaterials.is_painted(_hero.worn_art()))


func _physics_process(delta: float) -> void:
	var f := _frame
	_frame += 1
	_hero.advance(delta)
	var shot := f / SHOT_HOLD
	if shot >= _shots.size():
		print("STAGE done")
		get_tree().quit()
		return
	if f % SHOT_HOLD == 0:
		var s := _shots[shot]
		_hero.rotation_degrees.y = s["yaw"]
		_hero.set_damage_look(s["level"])
		_camera.position = s["from"]
		_camera.look_at(s["at"])
		print("STAGE %s frame %d" % [s["name"], f])
