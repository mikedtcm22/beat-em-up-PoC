extends Node3D
## M7 spike S1: the trailer Punk alone, front view, walk_forward on a loop, flat backdrop (a walk-cycle source for the drawn-sprite test).
##   godot --path . --write-movie captures/s1/walk/walk.avi --fixed-fps 60 --resolution 1280x720 --quit-after 200 res://tests/fixtures/m7/s1_walk_stage.tscn
const ART := "res://game/actors/art/punk_art.tres"
const FACE_YAW := 180.0

var _hero: HumanoidRig


func _ready() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 1.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.45)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.62, 0.34)
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-30.0, 60.0, 0.0)
	add_child(key)
	_hero = HumanoidRig.new()
	_hero.build_hurtboxes = false
	_hero.art = load(ART) as CharacterArt
	add_child(_hero)
	_hero.build()
	_hero.rotation_degrees.y = FACE_YAW
	_hero.play(&"walk_forward", 0.0)
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0.0, 0.9, 3.3)
	camera.look_at(Vector3(0.0, 0.88, 0.0))


func _physics_process(delta: float) -> void:
	_hero.advance(delta)
