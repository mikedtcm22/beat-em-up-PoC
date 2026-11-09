extends GutTest
## LD-STAGE's shots and director: every shot scene exists and plays its shot (the six Gate 1 stills and the moving shots), the shot data is
## well formed, the director finds a location's pieces in the order art, world, ink, overrides a piece's value on a copy, hides the overlays,
## seeds the rngs and puts back the tunables it wrote. The pixels are windowed: tools/video/shoot.sh renders them.

const SHOTS_DIR := "res://video/shots"
const STILLS_DIR := "res://video/stills"
const LOCATIONS: Array[StringName] = [&"street_night", &"roofs_dusk", &"boss_fire"]
const MOVING: Array[StringName] = [&"moving_punk", &"crane_street"]
const BOT_SCRIPT := "res://video/stage/cine_bot.gd"


func after_each() -> void:
	Tuning.reset_to_default()


func _scene_names() -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(SHOTS_DIR):
		if file.ends_with(".tscn"):
			out.append(file.get_basename())
	out.sort()
	return out


func _shot_of(scene_name: String) -> VideoStillShot:
	var packed := load(SHOTS_DIR.path_join("%s.tscn" % scene_name)) as PackedScene
	var node := packed.instantiate()
	var shot := node.get(&"shot") as VideoStillShot
	node.free()
	return shot


func test_each_gate_one_still_and_each_moving_shot_has_a_scene() -> void:
	var names := _scene_names()
	for file in DirAccess.get_files_at(STILLS_DIR):
		if file.ends_with(".tres"):
			assert_true(names.has(file.get_basename()), "a shot scene for the still %s" % file.get_basename())
	for key in MOVING:
		assert_true(names.has(String(key)), "a shot scene for %s" % key)


func test_a_shot_scene_is_a_cine_bot_with_its_shot() -> void:
	for scene_name in _scene_names():
		var packed := load(SHOTS_DIR.path_join("%s.tscn" % scene_name)) as PackedScene
		assert_not_null(packed, "%s loads" % scene_name)
		var node := packed.instantiate()
		assert_eq((node.get_script() as Script).resource_path, BOT_SCRIPT, "%s runs the cine bot" % scene_name)
		var shot := node.get(&"shot") as VideoStillShot
		assert_not_null(shot, "%s names a shot" % scene_name)
		assert_eq(String(shot.key), scene_name, "the scene is named after its shot")
		node.free()


func test_every_shot_is_well_formed() -> void:
	for scene_name in _scene_names():
		var shot := _shot_of(scene_name)
		assert_true(not shot.actors.is_empty() or (shot is CineShot and not shot.first_person), "%s: has an actor (only a free-camera shot may be empty)" % scene_name)
		for spec in shot.actors:
			assert_not_null(EnemyCatalog.scene(spec.id), "%s: catalog id %s" % [scene_name, spec.id])
		assert_true(shot.section >= 0 and shot.section <= 2, "%s: a section" % scene_name)
		if shot is CineShot:
			var moving := shot as CineShot
			assert_gt(moving.window_to_s, moving.window_from_s, "%s: a window" % scene_name)
			assert_gt(moving.window_ticks(60), 0)
			for beat in moving.beats:
				assert_lte(beat.at_s, moving.window_to_s, "%s: every beat falls inside the window" % scene_name)
			if not moving.first_person:
				assert_gte(moving.camera_keys.size(), 2, "%s: a path" % scene_name)
				var last := -1.0
				for key in moving.camera_keys:
					assert_gte(key.time_s, last, "%s: camera keys in time order" % scene_name)
					last = key.time_s
				assert_lte(moving.camera_keys[0].time_s, moving.window_from_s, "%s: the path starts with the window" % scene_name)


func test_the_moving_shot_is_first_person_punches_that_end_with_the_action() -> void:
	var shot := load("res://video/shots/moving_punk.tres") as CineShot
	assert_true(shot.first_person)
	# SHOTS (Gate 2's finding 10): the shot was 5 s (300 ticks) with a static tail; it ends 1.1 s after the last punch (the launch and the fall).
	assert_eq(shot.window_to_s - shot.window_from_s, 3.4, "3.4 s")
	assert_eq(shot.window_ticks(60), 204)
	var last_punch := 0.0
	var tilts := 0
	for beat in shot.beats:
		if beat.kind == CineBeat.Kind.PRESS and beat.button == &"P":
			last_punch = maxf(last_punch, beat.at_s)
		if beat.kind == CineBeat.Kind.PITCH and beat.degrees > 0.0:
			tilts += 1
	assert_lte(shot.window_to_s - last_punch, 1.3, "the window ends soon after the last punch: no static tail")
	assert_gte(tilts, 1, "the view tilts up as the player closes in, so the Punk's head stays in frame")
	var punches := 0
	for beat in shot.beats:
		if beat.kind == CineBeat.Kind.PRESS and beat.button == &"P":
			punches += 1
	assert_eq(punches, 4, "P P P P")
	assert_eq(shot.location_name(), &"street_night")
	assert_true(shot.actors[0].live, "the Punk is a live enemy: the hits land on him and he is launched")


func test_a_still_has_a_one_frame_window_and_a_cine_shot_its_own_window() -> void:
	var still := load("res://video/stills/fp_punk.tres") as VideoStillShot
	assert_false(still is CineShot, "a still is a plain VideoStillShot")
	assert_eq(CineDirector.shot_location(still), &"street_night")
	assert_eq(CineDirector.shot_location(load("res://video/stills/ox_low.tres")), &"boss_fire")
	assert_eq(CineDirector.shot_location(load("res://video/stills/roof_silhouette.tres")), &"roofs_dusk")


func test_each_location_names_its_pieces_in_order_art_world_ink() -> void:
	for location in LOCATIONS:
		var paths := CineDirector.piece_paths(location)
		assert_gte(paths.size(), 2, "%s: at least the world and the ink pieces" % location)
		var rank := PackedInt32Array()
		for path in paths:
			var file := path.get_file()
			rank.append(0 if file.begins_with("art") else (1 if file == "world.tres" else (2 if file == "ink.tres" else 3)))
		var sorted := rank.duplicate()
		sorted.sort()
		assert_eq(rank, sorted, "%s: %s apply art, then world, then ink, then the plate" % [location, paths])
		# Round 5 (R5-PAINT): the plate piece applies after the ink piece; the ink piece is still the last of the others (the twin: test_r5_paint_data).
		var others: Array[String] = []
		for path in paths:
			if path.get_file() != "plate.tres":
				others.append(path)
		assert_eq(others[others.size() - 1].get_file(), "ink.tres", "%s: the ink piece applies last of the look's own pieces" % location)


func test_every_piece_loads_as_a_look_piece() -> void:
	for location in LOCATIONS:
		var pieces := CineDirector.load_pieces(location)
		assert_eq(pieces.size(), CineDirector.piece_paths(location).size(), "%s: every file loads" % location)
		assert_true(pieces.any(func(piece: VideoLookPiece) -> bool: return piece is VideoWorldLook))
		assert_true(pieces.any(func(piece: VideoLookPiece) -> bool: return piece is VideoInkLook))


func test_an_override_is_made_on_a_copy_and_a_bad_name_leaves_the_piece_alone() -> void:
	var piece := load("res://video/look/street_night/ink.tres") as VideoInkLook
	var before := piece.post_enabled
	var copy := CineDirector.override_piece(piece, "ink.tres", {"ink.tres.post_enabled": not before}) as VideoInkLook
	assert_ne(copy, piece, "a copy")
	assert_eq(copy.post_enabled, not before)
	assert_eq(piece.post_enabled, before, "the file's resource is untouched")
	assert_eq(CineDirector.override_piece(piece, "ink.tres", {"world.tres.x": 1}), piece, "another piece's override is not ours")
	assert_eq(CineDirector.override_piece(piece, "ink.tres", {}), piece)


func test_the_overlays_are_hidden_and_the_rngs_seeded() -> void:
	var holder := Node.new()
	var layer := CanvasLayer.new()
	var vfx := VfxDirector.new()
	holder.add_child(layer)
	holder.add_child(vfx)
	CineDirector.hide_overlays(holder)
	assert_false(layer.visible, "the HUD's layer is hidden")
	assert_eq(CineDirector.seed_rngs(holder, 7), 1, "one director seeded")
	var first := vfx.rng.randi()
	CineDirector.seed_rngs(holder, 7)
	assert_eq(vfx.rng.randi(), first, "the same seed gives the same draws")
	holder.free()


func test_the_director_writes_presentation_tunables_and_puts_them_back() -> void:
	var shot := CineShot.new()
	shot.shake_scale = 0.0
	shot.first_person_fov_deg = 100.0
	var director := CineDirector.new()
	director.shot = shot
	var shake := float(Tuning.data.screen_shake_intensity)
	var fov := float(Tuning.data.fov_deg)
	director.apply_presentation()
	assert_eq(float(Tuning.data.screen_shake_intensity), 0.0, "a calm shot")
	assert_eq(float(Tuning.data.fov_deg), 100.0)
	director.restore()
	assert_eq(float(Tuning.data.screen_shake_intensity), shake)
	assert_eq(float(Tuning.data.fov_deg), fov)
	director.free()


func test_the_shot_clock_counts_physics_ticks() -> void:
	var director := CineDirector.new()
	add_child_autofree(director)
	director.start_clock()
	await _ticks(6)
	assert_eq(director.clock_ticks(), 6)
	assert_almost_eq(director.clock_s(), 0.1, 0.0001)


func _ticks(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func test_the_director_builds_a_camera_from_a_shots_keys() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var director := CineDirector.new()
	add_child_autofree(director)
	director.level = level
	director.shot = load("res://video/shots/crane_street.tres")
	var camera := director.build_camera(Vector3(0, 0, 0))
	assert_eq(camera.keys.size(), 3)
	assert_eq(camera.get_parent(), level)
	assert_true(camera.global_position.is_equal_approx(camera.keys[0].position), "at the first key")
	var still := CineDirector.new()
	add_child_autofree(still)
	still.level = level
	still.shot = load("res://video/stills/street_wide.tres")
	assert_eq(still.build_camera(Vector3.ZERO).keys.size(), 1, "a still's camera is one key")


func test_the_shoot_script_and_the_bot_exist() -> void:
	assert_true(FileAccess.file_exists("res://tools/video/shoot.sh"))
	assert_true((load(BOT_SCRIPT) as GDScript).can_instantiate(), "the cine bot compiles")
	assert_true((load("res://video/cine/frame_writer.gd") as GDScript).can_instantiate(), "the frame writer compiles")
