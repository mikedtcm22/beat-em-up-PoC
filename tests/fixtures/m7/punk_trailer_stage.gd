extends Node3D
## Milestone 7, T12: a recording stage for the trailer Punk (not a test). Run through tools/capture_bot.sh (Movie Maker, 1280x720, 60 fps):
##   tools/capture_bot.sh res://tests/fixtures/m7/punk_trailer_stage.tscn captures/m7-slice/t12/rec
## One Punk (the real punk_art.tres, which follows the look profile, so it wears its trailer variant) turns through eight yaw steps, then
## three Punks stand side by side (clean, bloodied, the veteran's recolour), then the clip: a walk and a hit reaction. The script writes
## STAGE lines with the frame each part starts on, so the stills are cut at known frames (tools/pipeline/trailer_stage_sheets.sh).
const ART := "res://game/actors/art/punk_art.tres"
const VETERAN := "res://game/enemies/variants/punk_veteran.tres"
## The rig faces -Z; the camera looks down it from +Z, so this yaw shows the front.
const FACE_YAW := 180.0
const TURN_STEPS := 8
const TURN_HOLD := 12
const LINE_HOLD := 24
const WALK_FRAMES := 60
const HIT_FRAMES := 60

var _frame := 0
var _hero: HumanoidRig
var _side: Array[HumanoidRig] = []
var _camera: Camera3D
var _key: DirectionalLight3D


func _ready() -> void:
	# `-- --profile=m6` shows the same stage under the m6 look (the A/B); the default is the trailer.
	var profile := LookProfile.Id.M6 if OS.get_cmdline_user_args().has("--profile=m6") else LookProfile.Id.TRAILER
	Tuning.set_value(&"look_profile", profile)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.3, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.4)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	_key = DirectionalLight3D.new()
	_key.light_color = Color(1.0, 0.62, 0.34)
	_key.light_energy = 1.3
	_key.shadow_enabled = true
	_key.rotation_degrees = Vector3(-30.0, 60.0, 0.0)
	add_child(_key)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	floor_mesh.material_override = ToonMaterials.environment(Color(0.5, 0.4, 0.42))
	add_child(floor_mesh)
	var art := load(ART) as CharacterArt
	_hero = _rig(art, Vector3.ZERO)
	for i in 3:
		_side.append(_rig(art, Vector3((i - 1) * 0.9, 0.0, 0.0)))
		_side[i].visible = false
	_side[1].set_damage_look(DamageLook.Level.BLOODIED)
	var veteran := load(VETERAN) as EnemyVariant
	var painted := _side[2].paint.art_material() as ShaderMaterial
	painted.set_shader_parameter(&"paint_tex", veteran.trailer_paint())
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true
	_aim(Vector3(0.0, 1.05, 3.4), Vector3(0.0, 0.95, 0.0))
	print("STAGE worn art: ", _hero.worn_art().id, " painted: ", ToonMaterials.is_painted(_hero.worn_art()))


func _rig(art: CharacterArt, at: Vector3) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = art
	add_child(rig)
	rig.build()
	rig.position = at
	rig.play(&"idle", 0.0)
	return rig


func _aim(from: Vector3, at: Vector3) -> void:
	_camera.position = from
	_camera.look_at(at)


func _physics_process(delta: float) -> void:
	var f := _frame
	_frame += 1
	_hero.advance(delta)
	for rig: HumanoidRig in _side:
		rig.advance(delta)
	var turn_end := TURN_STEPS * TURN_HOLD
	var line_end := turn_end + LINE_HOLD
	if f < turn_end:
		var step := f / TURN_HOLD
		_hero.rotation_degrees.y = FACE_YAW + 45.0 * step
		if f % TURN_HOLD == 0:
			print("STAGE turn %d yaw %d frame %d" % [step, 45 * step, f])
	elif f < line_end:
		if f == turn_end:
			print("STAGE line frame %d" % f)
			_hero.visible = false
			for rig: HumanoidRig in _side:
				rig.visible = true
				rig.rotation_degrees.y = FACE_YAW
			_aim(Vector3(0.0, 1.2, 3.6), Vector3(0.0, 0.95, 0.0))
	elif f < line_end + WALK_FRAMES:
		if f == line_end:
			print("STAGE walk frame %d" % f)
			for rig: HumanoidRig in _side:
				rig.visible = false
			_hero.visible = true
			_hero.rotation_degrees.y = FACE_YAW
			_aim(Vector3(0.0, 1.15, 3.0), Vector3(0.0, 0.95, 0.0))
			_hero.play(&"walk_forward", 0.0)
	elif f < line_end + WALK_FRAMES + HIT_FRAMES:
		if f == line_end + WALK_FRAMES:
			print("STAGE hit frame %d" % f)
			_hero.play(&"flinch_gut", 0.04)
	else:
		print("STAGE done")
		get_tree().quit()
