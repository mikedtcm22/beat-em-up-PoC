extends Node3D
## Milestone 7, G2: a recording stage for the trailer Punk's painted maps (not a test): close heads from the front and three-quarters, the fight distance,
## the full-body turn and the torso. `godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 res://tests/fixtures/m7/g2_look_stage.tscn`
## Each shot holds SHOT_HOLD frames; the script prints `STAGE shot <i> frame <f>` at the start of each, the still is the frame 6 later.
const ART := "res://game/actors/art/punk_art.tres"
const VETERAN := "res://game/enemies/variants/punk_veteran.tres"
const FACE_YAW := 180.0
const SHOT_HOLD := 12
## yaw offset from the front, camera from, camera at, veteran recolour
const SHOTS := [
	[0.0, Vector3(0.0, 1.66, 0.85), Vector3(0.0, 1.62, 0.0), false],
	[45.0, Vector3(0.0, 1.66, 0.85), Vector3(0.0, 1.62, 0.0), false],
	[-45.0, Vector3(0.0, 1.66, 0.85), Vector3(0.0, 1.62, 0.0), false],
	[0.0, Vector3(0.0, 1.45, 3.0), Vector3(0.0, 1.1, 0.0), false],
	[45.0, Vector3(0.0, 1.05, 3.4), Vector3(0.0, 0.95, 0.0), false],
	[0.0, Vector3(0.0, 1.3, 1.9), Vector3(0.0, 1.25, 0.0), false],
	[0.0, Vector3(0.0, 1.05, 3.4), Vector3(0.0, 0.95, 0.0), true],
	[135.0, Vector3(0.0, 1.05, 3.4), Vector3(0.0, 0.95, 0.0), false],
]

var _frame := 0
var _hero: HumanoidRig
var _camera: Camera3D
var _veteran_tex: Texture2D


func _ready() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
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
	var art := load(ART) as CharacterArt
	_hero = HumanoidRig.new()
	_hero.build_hurtboxes = false
	_hero.art = art
	add_child(_hero)
	_hero.build()
	_hero.play(&"idle", 0.0)
	_veteran_tex = (load(VETERAN) as EnemyVariant).trailer_paint()
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true


func _physics_process(delta: float) -> void:
	var f := _frame
	_frame += 1
	_hero.advance(delta)
	var shot := f / SHOT_HOLD
	if shot >= SHOTS.size():
		print("STAGE done")
		get_tree().quit()
		return
	if f % SHOT_HOLD == 0:
		var s: Array = SHOTS[shot]
		_hero.rotation_degrees.y = FACE_YAW + float(s[0])
		_camera.position = s[1]
		_camera.look_at(s[2])
		if s[3]:
			(_hero.paint.art_material() as ShaderMaterial).set_shader_parameter(&"paint_tex", _veteran_tex)
		print("STAGE shot %d frame %d" % [shot, f])
