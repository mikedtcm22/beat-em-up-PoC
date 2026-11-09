extends GutTest
## SHOTS: the trailer's shot list (PLAN.md section 5) as data: fourteen shots numbered 1 to 14, each with its scene and its CineShot, in the
## right location, with a well-formed script and camera path, a varied cast, and the slow-motion shots slowed through TimeController's beat.

const SHOTS_DIR := "res://video/shots"
const COUNT := 14
const STREET: Array[int] = [1, 2, 3, 4, 5, 6]
const ROOFS: Array[int] = [7, 8, 9]
const BOSS: Array[int] = [10, 11, 12, 13, 14]
const SLOW: Array[int] = [7, 12]
## The shots that are the player's own view (the rest are cine cameras).
const FIRST_PERSON: Array[int] = [2, 3, 4, 5, 6, 8, 9, 11, 13]


func _trailer_shots() -> Array[CineShot]:
	var out: Array[CineShot] = []
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(SHOTS_DIR):
		var name := file.trim_suffix(".remap")
		if name.begins_with("t") and name.ends_with(".tres") and name.substr(1, 2).is_valid_int():
			files.append(name)
	files.sort()
	for file in files:
		out.append(load(SHOTS_DIR.path_join(file)) as CineShot)
	return out


func _shot_numbered(number: int) -> CineShot:
	for shot in _trailer_shots():
		if shot.number == number:
			return shot
	return null


func test_the_list_has_fourteen_shots_numbered_in_order() -> void:
	var shots := _trailer_shots()
	assert_eq(shots.size(), COUNT, "one CineShot per shot of the list")
	var last_start := -1.0
	for n in COUNT:
		var shot := _shot_numbered(n + 1)
		assert_not_null(shot, "shot %d exists" % (n + 1))
		if shot == null:
			continue
		assert_true(String(shot.key).begins_with("t%02d_" % (n + 1)), "shot %d is named t%02d_..." % [n + 1, n + 1])
		assert_gt(shot.edit_start_s, last_start, "shot %d starts after the one before it in the edit" % (n + 1))
		last_start = shot.edit_start_s


func test_each_shot_has_a_scene_that_runs_the_cine_bot_with_it() -> void:
	for shot in _trailer_shots():
		var packed := load(SHOTS_DIR.path_join("%s.tscn" % shot.key)) as PackedScene
		assert_not_null(packed, "%s has a scene" % shot.key)
		var node := packed.instantiate()
		assert_eq((node.get_script() as Script).resource_path, "res://video/stage/cine_bot.gd")
		assert_eq((node.get(&"shot") as CineShot).key, shot.key, "the scene names its shot")
		node.free()


func test_each_shot_is_in_its_location_and_section() -> void:
	for shot in _trailer_shots():
		var expected := &"street_night"
		var section := 0
		if shot.number in ROOFS:
			expected = &"roofs_dusk"
			section = 1
		elif shot.number in BOSS:
			expected = &"boss_fire"
			section = 2
		assert_eq(shot.location_name(), expected, "shot %d: location" % shot.number)
		assert_eq(shot.section, section, "shot %d: section" % shot.number)


func test_first_person_and_cine_shots_are_as_listed() -> void:
	for shot in _trailer_shots():
		assert_eq(shot.first_person, shot.number in FIRST_PERSON, "shot %d: first person or cine" % shot.number)
		assert_gt(shot.window_to_s, shot.window_from_s, "shot %d: a window" % shot.number)
		assert_lte(shot.window_to_s - shot.window_from_s, 7.0, "shot %d: a shot is not longer than the edit can use" % shot.number)


func test_every_enemy_type_and_the_boss_appear() -> void:
	var ids := {}
	for shot in _trailer_shots():
		for spec in shot.actors:
			assert_not_null(EnemyCatalog.scene(spec.id), "shot %d: catalog id %s" % [shot.number, spec.id])
			ids[spec.id] = true
	for id: StringName in [&"punk", &"kicker", &"thug", &"bruiser", &"boss"]:
		assert_true(ids.has(id), "%s is in the trailer" % id)


func test_no_shot_shows_two_copies_of_one_model() -> void:
	for shot in _trailer_shots():
		var seen := {}
		for spec in shot.actors:
			assert_false(seen.has(spec.id), "shot %d: %s twice (a variant or another type says they are different)" % [shot.number, spec.id])
			seen[spec.id] = true


func test_a_group_shot_varies_its_poses() -> void:
	for shot in _trailer_shots():
		if shot.actors.size() < 3:
			continue
		var poses := {}
		for spec in shot.actors:
			poses["%s|%d|%d|%d" % [spec.anim, spec.facing, roundi(spec.yaw_deg), int(spec.live)]] = true
		assert_gte(poses.size(), 3, "shot %d: three or more figures, no two in the same pose" % shot.number)


func test_the_beats_are_in_order_and_point_at_real_actors() -> void:
	for shot in _trailer_shots():
		var last_absolute := -1.0
		for beat in shot.beats:
			if not beat.relative and beat.trigger == CineBeat.Trigger.CLOCK:
				assert_gte(beat.at_s, last_absolute, "shot %d: absolute beats in time order" % shot.number)
				last_absolute = beat.at_s
			if beat.kind in [CineBeat.Kind.ATTACK, CineBeat.Kind.ACTOR_FACE, CineBeat.Kind.ACTOR_ANIM] \
					or beat.trigger in [CineBeat.Trigger.ACTOR_STRIKE, CineBeat.Trigger.ACTOR_STAGGERED, CineBeat.Trigger.ACTOR_DOWN,
					CineBeat.Trigger.ACTOR_FREE]:
				assert_lt(beat.actor, shot.actors.size(), "shot %d: beat actor %d exists" % [shot.number, beat.actor])
		# A held button is released before the shot ends.
		var held := {}
		for beat in shot.beats:
			if beat.kind == CineBeat.Kind.DOWN:
				held[beat.button] = true
			elif beat.kind == CineBeat.Kind.UP:
				held.erase(beat.button)
		assert_true(held.is_empty() or shot.number == 2, "shot %d: a held button is let go (only the guard of shot 2 stays up)" % shot.number)


func test_a_cine_camera_path_starts_with_its_window_and_is_in_time_order() -> void:
	for shot in _trailer_shots():
		if shot.first_person:
			assert_true(shot.camera_keys.is_empty(), "shot %d: first person has no free camera" % shot.number)
			continue
		assert_gte(shot.camera_keys.size(), 2, "shot %d: a path" % shot.number)
		var last := -1.0
		for key in shot.camera_keys:
			assert_gte(key.time_s, last, "shot %d: keys in time order" % shot.number)
			last = key.time_s
		assert_lte(shot.camera_keys[0].time_s, shot.window_from_s, "shot %d: the path starts with the window" % shot.number)
		assert_gte(shot.camera_keys[shot.camera_keys.size() - 1].time_s, shot.window_to_s - 0.01, "shot %d: the path runs to the end" % shot.number)


func test_the_slow_motion_shots_slow_through_timecontrollers_beat() -> void:
	for shot in _trailer_shots():
		var slowmos := 0
		for beat in shot.beats:
			if beat.kind == CineBeat.Kind.SLOWMO:
				slowmos += 1
				assert_lte(beat.time_scale, 0.3, "shot %d: a real slow-motion" % shot.number)
		if shot.number in SLOW:
			assert_gte(slowmos, 1, "shot %d is at 0.25x: a SLOWMO beat" % shot.number)
			assert_eq(shot.edit_speed, 0.25, "shot %d is cut as a 0.25x shot" % shot.number)
		else:
			assert_eq(slowmos, 0, "shot %d has no slow-motion of its own" % shot.number)


func test_the_weapons_the_shots_lay_exist() -> void:
	for shot in _trailer_shots():
		for spec in shot.props:
			assert_not_null(WeaponCatalog.get_def(spec.id), "shot %d: weapon %s" % [shot.number, spec.id])
	assert_gte(_shot_numbered(6).props.size(), 1, "shot 6 lays a pipe")
	assert_gte(_shot_numbered(8).props.size(), 1, "shot 8 lays the bike chain")


func test_every_trailer_shot_logs_its_events() -> void:
	var text := FileAccess.get_file_as_string("res://video/stage/cine_bot.gd")
	assert_true(text.contains("CineEventLog"), "the cine bot writes the cue sheet of every shot")
	assert_true(text.contains("_events.log"))
