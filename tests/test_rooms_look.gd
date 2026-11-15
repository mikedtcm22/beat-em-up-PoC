extends GutTest
## Milestone 7 (e-rooms): the crowd room and the training room under the trailer look. One calm key light (the night look's, followed
## by the room's sun), stepped lamp pools that fall inside the lane, no painted wall glow (soft gradient), the training dummy's trailer
## art (flat fills, a drawn face and bullseye, placed bruises on its head), and none of it under m6.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TEST_ROOM_PATH := "res://game/level/test_room.tscn"
const DUMMY_ART := "res://game/actors/art/dummy_art.tres"
const DUMMY_PAINT := "res://assets/export/characters/dummy/trailer/dummy_paint.png"
const DUMMY_MARKS := "res://assets/export/characters/dummy/trailer/dummy_marks.png"
const DUMMY_FEATURES := "res://assets/source/trailer_art/dummy/features.svg"


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	Tuning.set_value(&"waves_enabled", false)


func after_each() -> void:
	Tuning.reset_to_default()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _build(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	if "waves_enabled_on_start" in root:
		root.set(&"waves_enabled_on_start", false)
	add_child_autofree(root)
	await _ticks(4)
	return root


func test_tunables_are_in_the_rooms_group() -> void:
	var data := Tuning.data
	assert_false(data.rooms_key_follow_look, "off by default: test_look_profile pins the sun as Tuning's")
	assert_eq(data.rooms_key_energy, 1.0)
	var source := FileAccess.get_file_as_string("res://game/autoload/tuning_data.gd")
	var group := source.find('@export_group("Rooms (M7)")')
	assert_gt(group, 0, "the group exists")
	assert_gt(source.find("rooms_key_follow_look", group), group)


func test_the_room_look_has_pools_inside_the_lane_and_no_wall_glow() -> void:
	var look: NightLook = TrailerLook.ROOM_LOOK
	assert_gte(look.lamps.size(), 6, "enough lamps to pool the lane")
	for lamp: NightLamp in look.lamps:
		assert_gt(lamp.pool_m, 0.0, "every lamp pools the ground")
		assert_eq(lamp.wall_glow_m, 0.0, "no soft wall glow")
		# The crowd room's lane is 12 m wide (z +-6), the training room's 14 m: the pole stands in the lane so the pool covers it.
		assert_lte(absf(lamp.position.z), 5.0, "the pole stands in the lane")
		assert_gte(absf(lamp.position.z), 3.0, "not in the middle of it")


func test_the_rooms_sun_is_the_night_looks_key_when_asked_and_under_trailer_only() -> void:
	Tuning.set_value(&"rooms_key_follow_look", true)
	for path in [CROWD_PATH, TEST_ROOM_PATH]:
		var room := await _build(path)
		var sun := room.get_node("Sun") as DirectionalLight3D
		var m6_rotation := sun.rotation_degrees
		var m6_energy := sun.light_energy
		Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
		await _ticks(3)
		var look: NightLook = TrailerLook.ROOM_LOOK
		assert_almost_eq(sun.rotation_degrees.x, -look.sun_elevation_deg, 0.01, "%s: the key's height" % path)
		assert_almost_eq(sun.rotation_degrees.y, look.sun_yaw_deg, 0.01, "the key's direction")
		assert_almost_eq(sun.light_energy, look.sun_energy, 0.001, "the key's energy")
		Tuning.set_value(&"rooms_key_energy", 0.5)
		await _ticks(2)
		assert_almost_eq(sun.light_energy, look.sun_energy * 0.5, 0.001, "the room's key multiplier is live")
		Tuning.set_value(&"rooms_key_energy", 1.0)
		Tuning.set_value(&"look_profile", LookProfile.Id.M6)
		await _ticks(3)
		assert_true(sun.rotation_degrees.is_equal_approx(m6_rotation), "m6: the sun's own direction again")
		assert_true(is_equal_approx(sun.light_energy, m6_energy), "m6: the sun's own energy again")
		room.queue_free()
		await _ticks(2)


func test_the_key_is_left_to_the_toon_sun_by_default() -> void:
	var room := await _build(CROWD_PATH)
	var sun := room.get_node("Sun") as DirectionalLight3D
	var before := sun.rotation_degrees
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	assert_true(sun.rotation_degrees.is_equal_approx(before), "off: the dusk's sun direction stays")


func test_the_dummy_wears_flat_painted_trailer_art() -> void:
	var art := load(DUMMY_ART) as CharacterArt
	var trailer := art.trailer_art()
	assert_not_null(trailer, "dummy_art.tres carries a trailer variant")
	assert_true(ToonMaterials.is_painted(trailer), "it is painted")
	assert_eq(art.variant(&"m6"), art, "m6 keeps the old art")
	assert_not_null(trailer.get_meta(&"marks_tex"), "placed bruises")
	var paint := (load(DUMMY_PAINT) as Texture2D).get_image()
	var marks := (load(DUMMY_MARKS) as Texture2D).get_image()
	assert_eq(paint.get_width(), 2048)
	assert_eq(marks.get_width(), 1024)
	var svg := FileAccess.get_file_as_string(DUMMY_FEATURES)
	for part in ["brow_l", "eye_l1", "mouth", "ring0", "seam"]:
		assert_true(svg.contains('id="%s"' % part), "the drawing has %s" % part)


func test_dummies_in_the_training_room_wear_the_trailer_art_and_flip_back() -> void:
	var room := await _build(TEST_ROOM_PATH)
	var dummy := room.get("dummies")[0] as TrainingDummy
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var art := load(DUMMY_ART) as CharacterArt
	assert_true(ToonMaterials.is_painted(art.variant(&"trailer")))
	assert_not_null(dummy, "the room has its dummies")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(3)
	assert_eq(art.variant(&"m6"), art)
