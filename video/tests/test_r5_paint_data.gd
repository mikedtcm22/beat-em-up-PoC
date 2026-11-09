extends GutTest
## R5-PAINT's checks (round 5: Gemini plates own the background): the plate camera's projection and depth coding are the shader's; the plate piece and its quad are
## inert on a shot with no plate and build from one that has plates; the capture hides what it must and keeps the haze; the blockout mode is a switch of the paint, off by
## default. The pixels are windowed: tools/video/plate_capture.sh renders the capture and tools/video/shoot.sh the projection.

const LOCATIONS: Array[StringName] = [&"street_night", &"roofs_dusk", &"boss_fire"]
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const SHADERS: Array[String] = [
	"res://video/shaders/plate_project.gdshader",
	"res://video/shaders/plate_depth.gdshader",
	"res://video/shaders/blockout_line.gdshader",
]
const BODY_PATH := "res://video/shaders/flat_paint_env_body.gdshaderinc"
const PAINT_SHADERS: Array[String] = [
	"res://video/shaders/flat_paint_env.gdshader",
	"res://video/shaders/flat_paint_env_scissor.gdshader",
	"res://video/shaders/flat_paint_prop.gdshader",
]


func after_each() -> void:
	VideoWorldLook.restore_game_materials()
	Tuning.reset_to_default()


func _ticks(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _build_level() -> LevelRoot:
	var root := (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	root.with_presentation = false
	root.waves_enabled_on_start = false
	add_child_autofree(root)
	await _ticks(4)
	return root


func test_every_location_has_a_plate_piece_and_the_director_applies_it_after_the_ink() -> void:
	for location in LOCATIONS:
		var path := "res://video/look/%s/plate.tres" % location
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		assert_true(load(path) is VideoPlateLook, "%s is a VideoPlateLook" % path)
		var paths := CineDirector.piece_paths(location)
		assert_eq(paths[paths.size() - 1].get_file(), "plate.tres", "%s: the plate piece is last" % location)
		assert_eq(paths[paths.size() - 2].get_file(), "ink.tres", "%s: the ink piece is just before it" % location)


func test_the_plate_shaders_compile_and_never_read_the_clock() -> void:
	var regex := RegEx.new()
	regex.compile("\\bTIME\\b")
	for path in SHADERS:
		var shader := load(path) as Shader
		assert_not_null(shader, "%s compiles" % path.get_file())
		assert_null(regex.search(FileAccess.get_file_as_string(path)), "%s never reads TIME" % path.get_file())


func test_the_plate_quad_sorts_after_the_brush_quad_and_before_everything_else() -> void:
	var quad := CinePlateQuad.new()
	autofree(quad)
	assert_lt(CinePlateQuad.SORT_DISTANCE, 3000.0, "nearer down the view than the brush quad (3000 m), so it draws after it")
	assert_gt(CinePlateQuad.SORT_DISTANCE, 1000.0, "far enough that every haze plane, steam card and flame draws after it")
	assert_eq(quad.material().render_priority, Material.RENDER_PRIORITY_MIN, "the brush quad's priority")
	var brush := CineBrushQuad.new()
	autofree(brush)
	assert_eq(brush.material().render_priority, quad.material().render_priority, "the same priority as the brush quad: the sort decides")


func test_the_depth_coding_round_trips_and_the_sky_is_65535() -> void:
	for z in [0.05, 1.0, 12.5, 31.85, 199.9]:
		var back := VideoPlateCamera.decode_depth(VideoPlateCamera.encode_depth(z, 200.0), 200.0)
		assert_almost_eq(back, z, 200.0 / 65534.0, "%.2f m codes to 16 bits and back within a step" % z)
	assert_eq(VideoPlateCamera.encode_depth(500.0, 200.0), 65534, "beyond the span clamps below the sky code")
	assert_eq(VideoPlateCamera.decode_depth(65535, 200.0), INF, "65535 is the sky")


func test_the_camera_json_round_trips() -> void:
	var xform := Transform3D(Basis.looking_at(Vector3(0.3, -0.2, -1.0), Vector3.UP), Vector3(-0.5, 7.0, 2.0))
	var camera := VideoPlateCamera.from_pose(xform, 83.0, Vector2i(2560, 1440), 0.05, 4000.0, 200.0)
	var back := VideoPlateCamera.from_json(camera.to_json({"shot": "street_wide"}))
	assert_not_null(back)
	assert_true(back.origin.is_equal_approx(camera.origin))
	assert_true(back.basis.x.is_equal_approx(camera.basis.x) and back.basis.y.is_equal_approx(camera.basis.y) and back.basis.z.is_equal_approx(camera.basis.z))
	assert_almost_eq(back.fov_deg, 83.0, 0.0001)
	assert_eq(back.size, Vector2i(2560, 1440))
	assert_null(VideoPlateCamera.from_json("{\"origin\": [0, 0, 0]}"), "a camera file without a basis does not load")


func test_the_projection_maps_the_plate_cameras_axis_to_the_centre_and_the_frame_one_to_one() -> void:
	var camera := VideoPlateCamera.from_pose(Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0)), 90.0, Vector2i(1600, 900))
	var centre := camera.project(Vector3(1.0, 2.0, -7.0))
	assert_almost_eq(centre.x, 0.5, 0.0001)
	assert_almost_eq(centre.y, 0.5, 0.0001)
	assert_almost_eq(centre.z, 10.0, 0.0001, "the z is the depth along the axis")
	var right := camera.project(Vector3(11.0, 2.0, -7.0))
	assert_almost_eq(right.x, 1.0, 0.0001, "at 90 degrees, a point as far right as it is deep sits on the right edge")
	var up := camera.project(Vector3(1.0, 2.0 + 10.0 * 0.5625, -7.0))
	assert_almost_eq(up.y, 0.0, 0.0001, "and the top edge at 16:9's half height")
	assert_eq(camera.project(Vector3(1.0, 2.0, 8.0)), Vector3.ZERO, "a point behind the camera has no projection")
	# A wider plate keeps the pixel size of a narrower frame at the same centre of projection: a frame's centre pixel is the plate's centre pixel.
	var frame := VideoPlateCamera.from_pose(Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0)), 75.0, Vector2i(2560, 1440))
	var wide := VideoPlateCamera.from_pose(Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0)), 83.0, Vector2i(2560, 1440))
	var point := Vector3(2.0, 3.0, -9.0)
	var a := frame.project(point)
	var b := wide.project(point)
	assert_gt(absf(a.x - 0.5), absf(b.x - 0.5), "a wider FOV puts the same point nearer the centre of the picture")
	assert_almost_eq((a.x - 0.5) * tan(deg_to_rad(75.0) * 0.5), (b.x - 0.5) * tan(deg_to_rad(83.0) * 0.5), 0.0001, "and the two agree on the ray")


func test_a_shot_with_no_plate_gets_no_quad_and_nothing_hidden() -> void:
	assert_eq(VideoPlateLook.plates_of(&"no_such_shot").size(), 0)
	var level := await _build_level()
	var look := load("res://video/look/street_night/plate.tres") as VideoPlateLook
	look.apply(level)
	assert_null(look.quad, "no director, no shot, no quad")
	assert_null(level.get_node_or_null(NodePath(String(VideoPlateLook.QUAD_NAME))), "nothing was added to the level")


func test_the_capture_hides_the_actors_the_effects_and_the_lamp_shafts_but_not_the_haze() -> void:
	var level := await _build_level()
	var world := load("res://video/look/street_night/world.tres") as VideoWorldLook
	world.apply(level)
	await _ticks(2)
	var look := load("res://video/look/street_night/plate.tres") as VideoPlateLook
	var hidden := look.capture_hidden(level)
	assert_gt(hidden.size(), 0, "there is something to hide")
	var has_actor := false
	var has_shaft := false
	for node in hidden:
		has_actor = has_actor or node is CombatActor
		has_shaft = has_shaft or String(node.name).begins_with("Shaft")
		assert_false(String(node.name).begins_with("HazeQuad"), "the haze quad stays in the capture: the plate carries the aerial perspective")
	assert_true(has_actor, "the player is hidden (and every CombatActor)")
	assert_true(has_shaft, "the lamp shafts are hidden: the prompt paints no light cones")
	var live := VideoPlateLook.hide_by_prefix(level, look.live_hide_prefixes)
	assert_gt(live, 0, "a plated shot hides the haze quad and the lamp shafts live")
	assert_false((level.find_child("HazeQuad", true, false) as Node3D).visible, "the haze quad is hidden live")


func test_the_blockout_is_a_switch_of_the_paint_and_off_by_default() -> void:
	for location in LOCATIONS:
		var world := load("res://video/look/%s/world.tres" % location) as VideoWorldLook
		assert_false(world.blockout, "%s: a shot's look is never in the blockout" % location)
		assert_false(world.paint_values().has(&"blockout"), "%s: no blockout uniform is written by default" % location)
		var blocked := world.duplicate() as VideoWorldLook
		blocked.blockout = true
		assert_eq(blocked.paint_values()[&"blockout"], 1.0, "%s: the blockout sets the paint's switch" % location)
		assert_eq(blocked.paint.size(), world.paint.size(), "%s: the look's own paint is not changed by the switch" % location)
	for path in PAINT_SHADERS:
		var names := {}
		for uniform: Dictionary in (load(path) as Shader).get_shader_uniform_list():
			names[String(uniform.name)] = true
		assert_true(names.has("blockout"), "%s has the blockout uniform" % path.get_file())
	var body := FileAccess.get_file_as_string(BODY_PATH)
	assert_true(body.contains("uniform float blockout"), "the body declares it with its default (0)")


func test_the_blockout_turns_the_materials_flat_and_the_chain_link_off() -> void:
	var level := await _build_level()
	var world := (load("res://video/look/street_night/world.tres") as VideoWorldLook).duplicate() as VideoWorldLook
	world.blockout = true
	world.apply(level)
	await _ticks(2)
	var trim := ToonMaterials.trim()
	assert_eq(trim.get_shader_parameter(&"blockout"), 1.0, "the kit's trim material is in the blockout")
	assert_eq(ToonMaterials.trim_scissor().get_shader_parameter(&"blockout"), 1.0, "so is the chain-link's")
	var plain := load("res://video/look/street_night/world.tres") as VideoWorldLook
	plain.apply(level)
	await _ticks(2)
	assert_ne(ToonMaterials.trim().get_shader_parameter(&"blockout"), 1.0, "applying the look again without the switch puts the paint back")


func test_the_pilot_plates_are_installed_and_their_cameras_are_the_stills_own() -> void:
	var stills: Dictionary = {&"street_wide": 75.0, &"roof_silhouette": 75.0}
	for key: StringName in stills:
		var plates := VideoPlateLook.plates_of(key)
		assert_eq(plates.size(), 1, "%s has one plate" % key)
		var camera := VideoPlateCamera.from_json(FileAccess.get_file_as_string(VideoPlateLook.plate_dir(key).path_join("plate_0.json")))
		assert_not_null(camera, "%s: the plate's camera loads" % key)
		var shot := load("res://video/stills/%s.tres" % key) as VideoStillShot
		assert_true(camera.origin.is_equal_approx(shot.cam_pos + _section_origin(shot.section)), "%s: the plate is captured at the still's camera position" % key)
		assert_gt(camera.fov_deg, shot.cam_fov_deg, "%s: the plate is wider than the frame (pans and pushes stay inside it)" % key)
		assert_eq(camera.size, Vector2i(2560, 1440), "%s: the plate is the frame's size" % key)


func _section_origin(section: int) -> Vector3:
	var level := (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	add_child_autofree(level)
	return level.sections[section].global_position


func test_a_plated_shot_gets_the_quad_and_hides_what_the_plate_carries() -> void:
	var level := await _build_level()
	var world := load("res://video/look/street_night/world.tres") as VideoWorldLook
	world.apply(level)
	await _ticks(2)
	var director := CineDirector.new()
	director.name = "CineDirector"
	director.shot = load("res://video/stills/street_wide.tres") as VideoStillShot
	add_child_autofree(director)
	var look := load("res://video/look/street_night/plate.tres") as VideoPlateLook
	look.apply(level)
	assert_not_null(look.quad, "the plated shot gets a plate quad")
	assert_eq(level.get_node_or_null(NodePath(String(VideoPlateLook.QUAD_NAME))), look.quad, "it is under the level")
	var material := look.quad.material()
	assert_eq(material.get_shader_parameter(&"valid_a"), 1.0, "slot a holds the plate")
	assert_ne(material.get_shader_parameter(&"valid_b"), 1.0, "slot b is empty: one plate")
	assert_not_null(material.get_shader_parameter(&"plate_a"), "its picture is loaded")
	assert_not_null(material.get_shader_parameter(&"depth_a"), "its depth is loaded")
	assert_false((level.find_child("HazeQuad", true, false) as Node3D).visible, "the haze the plate carries is hidden live")
	# Applying again replaces the quad, never doubles it.
	look.apply(level)
	var quads := level.get_children().filter(func(child: Node) -> bool: return child is CinePlateQuad)
	assert_eq(quads.size(), 1, "one quad after a second application")
	look.quad.queue_free()


func test_a_shot_without_plates_is_untouched_by_the_piece() -> void:
	var level := await _build_level()
	var director := CineDirector.new()
	director.name = "CineDirector"
	director.shot = load("res://video/stills/fp_punk.tres") as VideoStillShot
	add_child_autofree(director)
	var look := load("res://video/look/street_night/plate.tres") as VideoPlateLook
	look.apply(level)
	assert_null(look.quad, "fp_punk has no plate: no quad")
