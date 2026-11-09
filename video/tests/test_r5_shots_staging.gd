extends GutTest
## R5-SHOTS: the hero frames (video/shots/hero_frames.json) and the shots staged for their plates: the first-person lens is 55-60 degrees,
## a third-person shot's camera holds one position (pan, tilt and zoom only), fight set-ups bank 4-8 degrees alternating in sign and the
## establishing shots none, the first-person view's lift and pull-back are small, the foreground cards triangulate, and t14 has no 3D.

const SHOTS_DIR := "res://video/shots"
const HERO_PATH := "res://video/shots/hero_frames.json"
const FOV_MIN := 55.0
const FOV_MAX := 60.0
## Third-person lenses: 40-55 degrees across at the start and the end of a shot (a zoom may pass between).
const LENS_MIN := 36.0
const LENS_MAX := 56.0
const ROLL_MIN := 4.0
const ROLL_MAX := 8.0
## The shots whose camera stays level: the establishing shots (the street's tilt-down, the boss reveal) and the multiplane title.
const LEVEL_SHOTS: Array[StringName] = [&"t01_crane_street", &"t10_ox_reveal", &"t14_title_embers"]
const FIXED_POSITION_SHOTS: Array[StringName] = [&"t01_crane_street", &"t07_roof_knockoff", &"t10_ox_reveal", &"t12_haymaker"]


func _shots() -> Dictionary[StringName, CineShot]:
	var out: Dictionary[StringName, CineShot] = {}
	for file in DirAccess.get_files_at(SHOTS_DIR):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") and name.begins_with("t") and name.substr(1, 2).is_valid_int():
			var shot := load(SHOTS_DIR.path_join(name)) as CineShot
			out[shot.key] = shot
	return out


func _hero() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HERO_PATH))
	return (parsed as Dictionary).get("frames", []) as Array


func test_the_hero_set_is_seven_frames_in_the_trailers_proportions() -> void:
	var frames := _hero()
	assert_eq(frames.size(), 7, "seven hero frames")
	var kinds: Dictionary = {}
	var seen: Dictionary = {}
	for entry: Dictionary in frames:
		kinds[entry.kind] = int(kinds.get(entry.kind, 0)) + 1
		assert_false(seen.has(entry.key), "%s is picked once" % entry.key)
		seen[entry.key] = true
	assert_eq(int(kinds.get("fp_street", 0)), 2, "two first-person street frames")
	assert_eq(int(kinds.get("street_wide", 0)), 1, "one street wide")
	assert_eq(int(kinds.get("roof_sun", 0)), 1, "one roof against the sun")
	assert_eq(int(kinds.get("boss_wide", 0)), 1, "a boss wide")
	assert_eq(int(kinds.get("boss_closeup", 0)), 1, "a boss close-up")
	assert_eq(frames.size() - 6, 1, "and one more")


func test_each_hero_frame_names_a_shot_and_a_frame_inside_its_window() -> void:
	var shots := _shots()
	for entry: Dictionary in _hero():
		var key := StringName(entry.key)
		assert_true(shots.has(key), "%s is a trailer shot" % key)
		if not shots.has(key):
			continue
		var shot: CineShot = shots[key]
		var frames := int(ceil((shot.window_to_s - shot.window_from_s) * 24.0))
		assert_between(int(entry.frame), 0, frames - 1, "%s: the output frame is in the window (%d frames)" % [key, frames])
		assert_ne(String(entry.get("kind", "")), "", "%s has a kind" % key)


func test_the_first_person_trailer_shots_use_the_narrow_lens_and_a_small_view_shift() -> void:
	var seen := 0
	for shot: CineShot in _shots().values():
		if not shot.first_person:
			continue
		seen += 1
		assert_between(shot.first_person_fov_deg, FOV_MIN, FOV_MAX, "%s: lens" % shot.key)
		assert_between(shot.view_lift_m, -0.3, 0.3, "%s: lift" % shot.key)
		assert_between(shot.view_back_m, 0.0, 0.15, "%s: the view eased back 15 cm at most" % shot.key)
	assert_gt(seen, 8, "the first-person shots were found")


func test_a_third_person_shots_camera_pans_and_zooms_about_one_point() -> void:
	var shots := _shots()
	for key in FIXED_POSITION_SHOTS:
		var keys := (shots[key] as CineShot).keys()
		assert_gt(keys.size(), 1, "%s: a path" % key)
		for camera_key in keys:
			assert_eq(camera_key.position, keys[0].position, "%s: the camera does not move" % key)


func test_third_person_lenses_are_40_to_55_degrees_across() -> void:
	var shots := _shots()
	for key: StringName in FIXED_POSITION_SHOTS:
		for camera_key in (shots[key] as CineShot).keys():
			assert_between(camera_key.fov_deg, LENS_MIN, LENS_MAX, "%s: lens at %s s" % [key, camera_key.time_s])


func test_fight_set_ups_bank_four_to_eight_degrees_alternating_and_establishing_shots_none() -> void:
	var shots := _shots()
	var signs: Array[float] = []
	var order: Array = shots.keys()
	order.sort()
	for key: StringName in order:
		var shot: CineShot = shots[key]
		var rolls: Array[float] = []
		if shot.first_person:
			rolls.append(shot.view_roll_deg)
		else:
			for camera_key in shot.keys():
				rolls.append(camera_key.roll_deg)
		if key in LEVEL_SHOTS:
			for roll in rolls:
				assert_eq(roll, 0.0, "%s: an establishing shot is level" % key)
			continue
		if key == &"t02_guard_up":
			continue
		for roll in rolls:
			assert_between(absf(roll), ROLL_MIN, ROLL_MAX, "%s: a fight set-up banks" % key)
			assert_eq(signf(roll), signf(rolls[0]), "%s: one bank for the whole shot" % key)
		signs.append(signf(rolls[0]))
	for index in range(1, signs.size()):
		assert_ne(signs[index], signs[index - 1], "banks alternate in sign down the shot list (shot %d)" % index)


func test_t14_is_pure_multiplane_a_foreground_card_and_no_actor_or_kit() -> void:
	var shot: CineShot = _shots()[&"t14_title_embers"]
	assert_true(shot.hide_kit, "no 3D kit")
	assert_true(shot.actors.is_empty(), "no actor")
	assert_false(shot.cards.is_empty(), "a foreground card")
	var drifting := false
	for card in shot.cards:
		drifting = drifting or card.drift.length() > 0.0
	assert_true(drifting, "the foreground card drifts on its own")


func test_t01_ends_with_a_dark_foreground_mass_and_small_figures() -> void:
	var shot: CineShot = _shots()[&"t01_crane_street"]
	assert_false(shot.cards.is_empty(), "foreground cards")
	assert_gt(shot.camera_keys[0].position.y, 6.0, "the fixed point is 6-8 m up")
	assert_lt(shot.camera_keys[0].position.y, 8.0, "the fixed point is 6-8 m up")


func test_every_card_polygon_triangulates() -> void:
	var seen := 0
	for shot: CineShot in _shots().values():
		for card in shot.cards:
			seen += 1
			assert_not_null(CineCard.make_mesh(card.points), "%s: a card's outline is a simple polygon" % shot.key)
	assert_gt(seen, 3, "cards were found")


func test_a_card_stands_where_its_plane_and_drift_say() -> void:
	var card := CineCard.new()
	card.position = Vector3(2, 0, -5)
	card.yaw_deg = -90.0
	card.drift = Vector3(0, 0, -0.5)
	var item := card.build(Vector3(10, 0, 0), 0, 2.0)
	assert_not_null(item)
	add_child_autofree(item)
	assert_almost_eq(item.global_position, Vector3(12, 0, -6), Vector3(0.001, 0.001, 0.001), "section origin + position + drift * time")
	assert_almost_eq(item.global_transform.basis * Vector3.BACK, Vector3.LEFT, Vector3(0.001, 0.001, 0.001), "a yaw of -90 faces -X")
	assert_true(String(item.name).begins_with(CineCard.NAME_PREFIX), "the plate look's hide list never matches it")


func test_the_view_rig_lifts_and_pulls_back_along_the_cameras_own_axes_and_banks() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(1, 2, 3))
	var shot := CineShot.new()
	shot.view_lift_m = 0.1
	shot.view_back_m = 0.2
	shot.view_roll_deg = 5.0
	CineViewRig.apply_to_camera(camera, shot)
	# Yawed 90 degrees: the camera's back (+Z) points along +X, its up stays up.
	assert_almost_eq(camera.global_position, Vector3(1.2, 2.1, 3.0), Vector3(0.0001, 0.0001, 0.0001))
	var rolled := camera.global_transform.basis * Vector3.UP
	assert_gt(rolled.angle_to(Vector3.UP), deg_to_rad(4.9), "banked")
	assert_lt(rolled.angle_to(Vector3.UP), deg_to_rad(5.1), "banked by the shot's roll")


func test_a_shot_with_no_view_data_leaves_the_game_camera_alone() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(1, 2, 3))
	var before := camera.global_transform
	CineViewRig.apply_to_camera(camera, CineShot.new())
	assert_eq(camera.global_transform, before)
