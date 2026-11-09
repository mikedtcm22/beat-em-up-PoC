extends GutTest
## R5-ART (docs/video/P1.md, round 5), headless: every location's art piece turns the back-lit silhouette on for the cast and the first-person arm with a
## dark fill and a small kept share of the paint, the rig picks the light most behind a figure from the scene's lights, the cine toon has the silhouette's
## uniforms, and the gloves are no longer cylinders (the shaping is in each paint.json, and Ox's video mesh is wider at the hands than the game's).

const LOCATIONS: Array[String] = ["street_night", "roofs_dusk", "boss_fire"]
const CAST: Array[StringName] = [&"punk", &"boss", &"kicker", &"bruiser", &"thug", &"player"]
const ARM_ID := &"player"
## The silhouette body is a flat dark: the fill's value stays under this (0..1), and so does the share of the painted albedo kept in it.
const MAX_FILL_VALUE := 0.14
const MAX_KEEP := 0.2


func _look(location: String) -> VideoArtLook:
	return load("res://video/look/%s/art.tres" % location) as VideoArtLook


func test_every_location_draws_the_whole_cast_as_silhouettes() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		for id in CAST:
			assert_true(look.is_silhouette(id), "%s: %s is a silhouette" % [location, id])


func test_the_fill_is_a_flat_dark_and_keeps_little_of_the_paint() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_lt(look.sil_fill.v, MAX_FILL_VALUE, "%s: the body fill is dark" % location)
		assert_lt(look.sil_fill_top.v, MAX_FILL_VALUE, "%s: the top tone is dark too (two tones at most)" % location)
		assert_lte(look.sil_keep, MAX_KEEP, "%s: the painted albedo shows little through the fill" % location)
		assert_gt(look.sil_rim_strength, 0.0, "%s: there is a rim" % location)


func test_the_arm_is_a_dark_mass_with_a_warm_rim_on_the_facing_surface() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		var fill := look.sil_value_of(ARM_ID, &"sil_fill") as Color
		assert_lt(fill.v, 0.2, "%s: the arm's fill is near the scene's darks" % location)
		assert_eq(float(look.sil_value_of(ARM_ID, &"sil_rim_facing")), 1.0, "%s: the arm's rim is the surface that faces the light" % location)
		assert_eq(float(look.sil_value_of(ARM_ID, &"sil_close_lit")), 0.0, "%s: the arm has no lit fill band" % location)
		# A value of another art id falls back to the look's own.
		assert_eq(float(look.sil_value_of(&"punk", &"sil_rim_facing")), look.sil_rim_facing, "%s: another id reads the shared value" % location)


func test_the_night_has_a_moon_rim_and_the_others_have_none_or_a_fire() -> void:
	assert_gt(_look("street_night").sil_moon_strength, 0.0, "the street at night has the thin cool rim")
	assert_eq(_look("roofs_dusk").sil_moon_strength, 0.0, "the dusk has no moon")


func test_the_toon_shader_has_the_silhouette_uniforms_the_rig_writes() -> void:
	var code := (load(CineArtRig.TOON_SHADER_PATH) as Shader).code
	for key: StringName in CineArtRig.SIL_KEYS:
		assert_true(code.contains("uniform") and code.contains(String(key)), "cine_toon declares %s" % key)
	for key in ["sil_on", "sil_light_view", "sil_rim_color", "sil_up_view", "sil_moon_view", "sil_brim_y"]:
		assert_true(code.contains("uniform") and code.contains(key), "cine_toon declares %s" % key)


func _rig_with(lights: Array[Light3D]) -> CineArtRig:
	var level := Node3D.new()
	add_child_autofree(level)
	for light in lights:
		level.add_child(light)
	var rig := CineArtRig.new()
	rig.look = _look("street_night")
	level.add_child(rig)
	rig._level = level
	rig._scan_lights()
	return rig


func _omni(at: Vector3, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.omni_range = 30.0
	light.light_energy = energy
	return light


func test_the_rig_picks_the_lamp_behind_the_figure_not_the_one_in_front() -> void:
	# The camera looks down -Z from the origin; the figure is 8 m ahead. One lamp stands behind it, one beside the camera.
	var behind := _omni(Vector3(1, 3, -14), 1.5)
	var in_front := _omni(Vector3(1, 3, -2), 3.0)
	var rig := _rig_with([behind, in_front])
	var found := rig.light_behind(Vector3(0, 1, -8), Vector3.ZERO)
	assert_eq(found.light, behind, "the lamp behind the figure is the back light, though the other is brighter")
	assert_gt(-(found.to_light as Vector3).z, 0.5, "and it lies away from the camera")


func test_no_light_behind_gives_none() -> void:
	var rig := _rig_with([_omni(Vector3(0, 3, 2), 2.0)])
	assert_null(rig.light_behind(Vector3(0, 1, -8), Vector3.ZERO).light, "nothing lies behind the figure")


func test_a_hidden_or_dark_light_is_not_a_back_light() -> void:
	var off := _omni(Vector3(0, 3, -14), 2.0)
	off.visible = false
	var dark := _omni(Vector3(1, 3, -14), 0.0)
	var rig := _rig_with([off, dark])
	assert_null(rig.light_behind(Vector3(0, 1, -8), Vector3.ZERO).light, "a light that is off or has no energy is skipped")


func test_the_ink_rigs_own_rim_lights_are_never_scanned() -> void:
	var own := _omni(Vector3(0, 3, -14), 2.0)
	own.name = "CineInkRimLeft"
	var rig := _rig_with([own])
	assert_eq(rig._lights.size(), 0, "the ink rig's rim lights follow the key, not the scene")


func test_each_character_has_a_glove_shaping_in_its_art_data() -> void:
	for id in [&"punk", &"boss", &"player"]:
		var file := FileAccess.open("res://assets/source/video_art/%s/paint.json" % id, FileAccess.READ)
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		assert_true(data.has("gloves"), "%s has a gloves block" % id)
		var gloves: Dictionary = data.get("gloves", {})
		assert_eq((gloves.get("hands", []) as Array).size(), 2, "%s shapes both hands" % id)
		var widest := 0.0
		for point: Array in gloves.get("profile", []):
			widest = maxf(widest, float(point[1]))
		assert_gt(widest, 1.15, "%s: the padded front is wider than the wrist" % id)
		assert_true(gloves.has("thumb") and gloves.has("ridge"), "%s has a thumb lobe and a knuckle ridge" % id)


func test_ox_gloves_are_wider_than_the_games_boxing_glove_cylinders() -> void:
	var video := load("res://assets/video/characters/boss/boss_video.glb") as PackedScene
	var game := load("res://assets/export/characters/boss/boss.glb") as PackedScene
	var video_bounds := _mesh_bounds(video)
	var game_bounds := _mesh_bounds(game)
	assert_gt(video_bounds.size.x, game_bounds.size.x * 1.02, "with the pad widened and the thumb out, Ox's arms-out span grows")
	assert_lt(video_bounds.size.x, game_bounds.size.x * 1.4, "and by a glove, not a different body")


func _mesh_bounds(scene: PackedScene) -> AABB:
	var root := scene.instantiate()
	add_child_autofree(root)
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var bounds := mi.mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	return box
