extends GutTest
## Milestone 7, e-roofs: the dusk of Mission 1's roofs under the trailer look profile. The profile carries a second place look (a DuskLook
## for `roofs_dusk`) beside the street's; the roofs section hooks it up; flipping to the trailer builds the roofs' dressing (three far
## skyline plates, windows, wash) and the dusk sky (cloud banks, low sun) while the player is on the roofs, and hides the street's far
## plate there; M6 builds none of it. The plates are the generator's: flat silhouettes under a transparent sky.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const ROOFS := 1
const PLATES: Array[String] = [
	"res://assets/export/kit/trailer_roofs_skyline_a.png", "res://assets/export/kit/trailer_roofs_skyline_b.png",
	"res://assets/export/kit/trailer_roofs_skyline_c.png",
]
const SETTLE_FRAMES := 4


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"section_light_blend_s", 0.0)


func after_each() -> void:
	Tuning.reset_to_default()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _build() -> LevelRoot:
	var root := (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	root.waves_enabled_on_start = false
	add_child_autofree(root)
	await _ticks(SETTLE_FRAMES)
	return root


func _go_to_roofs(level: LevelRoot) -> void:
	var roofs := level.sections[ROOFS]
	var route := roofs.get_node("Route").get_children()
	level.player.global_position = roofs.to_global((route[5] as Node3D).position)
	await _ticks(SETTLE_FRAMES)


func test_the_profile_carries_both_place_looks_and_the_roofs_hook_up_to_the_dusk() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var street := NightLook.for_location(&"street_night")
	var dusk := NightLook.for_location(&"roofs_dusk")
	assert_not_null(street, "the street's row is still found")
	assert_true(dusk is DuskLook, "the roofs' row is a DuskLook")
	assert_ne(street, dusk)
	assert_null(NightLook.for_location(&"nowhere"))
	var level := await _build()
	assert_eq(level.sections[ROOFS].look_location, &"roofs_dusk")
	assert_eq(dusk.mattes.size(), 3, "three far plates round the roofs")
	for matte in dusk.mattes:
		assert_not_null(matte.texture)
	assert_true(dusk.sun_energy <= 1.0 and dusk.sun_color.r > dusk.sun_color.b, "a warm key whose hue survives the toon cap")
	assert_true(dusk.sky_horizon.r > dusk.sky_horizon.b and dusk.sky_top.b > dusk.sky_top.r, "orange at the horizon, violet above")


func test_the_rows_are_not_lights_in_the_blend() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(2)
	for key in level.current_light():
		assert_false(level.current_light()[key] is NightLook, "no look row reaches the blended light (%s)" % key)
	assert_false(level.light_for(level.sections[ROOFS]).has(&"t51_roofs_dusk"))
	assert_eq(level.light_for(level.sections[ROOFS]).sun_color, NightLook.for_location(&"roofs_dusk").sun_color, "the dusk's key")


func test_m6_builds_no_dusk() -> void:
	var level := await _build()
	await _go_to_roofs(level)
	var look := level.get_node("TrailerLook") as TrailerLook
	assert_false(look.is_active())
	assert_eq(level.sections[ROOFS].find_children("Matte*", "MeshInstance3D", true, false).size(), 0)
	assert_eq(level.sections[ROOFS].find_children("WindowGlow*", "MeshInstance3D", true, false).size(), 0)


func test_the_trailer_builds_the_roofs_dressing_and_the_dusk_sky() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _go_to_roofs(level)
	var look := level.get_node("TrailerLook") as TrailerLook
	assert_eq(look.streets().size(), 2, "the street and the roofs")
	var roofs := level.sections[ROOFS]
	assert_eq(roofs.find_children("Matte*", "MeshInstance3D", true, false).size(), 3, "three skyline plates")
	assert_true(roofs.find_children("SkylineWash*", "MeshInstance3D", true, false).size() > 0, "the near blocks' windows are broken by wash")
	assert_eq(roofs.find_children("OmniLight3D", "", true, false).size(), 0, "no new light on the roofs")
	var sky := look.sky_material()
	var dusk := NightLook.for_location(&"roofs_dusk") as DuskLook
	assert_almost_eq(float(sky.get_shader_parameter(&"cloud_cover")), dusk.cloud_cover, 0.0001, "cloud banks")
	assert_almost_eq(float(sky.get_shader_parameter(&"disc_radius")), dusk.sky_disc_radius, 0.0001, "the low sun")
	assert_eq(sky.get_shader_parameter(&"band_count"), dusk.sky_band_count)
	assert_eq(sky.get_shader_parameter(&"star_cover"), 0.0, "no stars at dusk")
	for card: Node in level.sections[0].find_children("Matte*", "MeshInstance3D", true, false):
		assert_false((card as MeshInstance3D).visible, "the street's far plate is hidden from the roofs")


func test_the_street_keeps_its_night_sky_and_far_plate() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(SETTLE_FRAMES)
	var look := level.get_node("TrailerLook") as TrailerLook
	var sky := look.sky_material()
	assert_eq(float(sky.get_shader_parameter(&"cloud_cover")), 0.0, "no clouds on the street")
	assert_true(float(sky.get_shader_parameter(&"star_cover")) > 0.0, "the street has its stars")
	for card: Node in level.sections[0].find_children("Matte*", "MeshInstance3D", true, false):
		assert_true((card as MeshInstance3D).visible)


func test_the_dusk_tunables_apply_live() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _go_to_roofs(level)
	var look := level.get_node("TrailerLook") as TrailerLook
	var dusk := NightLook.for_location(&"roofs_dusk") as DuskLook
	Tuning.set_value(&"dusk_cloud_scale", 0.0)
	await _ticks(2)
	assert_eq(float(look.sky_material().get_shader_parameter(&"cloud_cover")), 0.0, "a clear sky at 0")
	Tuning.set_value(&"dusk_sun_disc_scale", 0.0)
	await _ticks(2)
	assert_eq(float(look.sky_material().get_shader_parameter(&"disc_radius")), 0.0, "no disc at 0")
	Tuning.set_value(&"dusk_skyline_energy", 0.5)
	var plate := level.sections[ROOFS].find_children("Matte*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_almost_eq(float((plate.material_override as ShaderMaterial).get_shader_parameter(&"energy")), dusk.mattes[0].energy * 0.5, 0.0001)
	Tuning.set_value(&"dusk_window_energy", 2.0)
	var windows := level.sections[ROOFS].find_children("WindowGlow*", "MeshInstance3D", true, false)
	if windows.size() > 0:
		var glow := (windows[0] as MeshInstance3D).material_override as ShaderMaterial
		assert_almost_eq(float(glow.get_shader_parameter(&"energy")), dusk.window_energy * 2.0, 0.0001)


func test_flipping_back_to_m6_frees_the_dusk() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _go_to_roofs(level)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(3)
	assert_eq(level.sections[ROOFS].find_children("Matte*", "MeshInstance3D", true, false).size(), 0)
	assert_eq((level.get_node("TrailerLook") as TrailerLook).streets().size(), 0)


func test_the_skyline_plates_are_flat_silhouettes_under_a_clear_sky() -> void:
	for path in PLATES:
		var image := (load(path) as Texture2D).get_image()
		assert_eq(image.get_size(), Vector2i(2048, 640), path)
		var sky := 0
		var lit := 0
		var solid := 0
		for y in range(0, 640, 4):
			for x in range(0, 2048, 4):
				var c := image.get_pixel(x, y)
				if c.a < 0.01:
					sky += 1
				elif c.a > 0.99:
					solid += 1
					if c.r > 0.85 and c.b < 0.5:
						lit += 1
		var total := float(sky + solid)
		assert_true(float(sky) / total > 0.25, "%s: the sky is alpha 0 (%.2f)" % [path, float(sky) / total])
		assert_true(float(lit) / float(solid) > 0.003 and float(lit) / float(solid) < 0.1, "%s: a few lit windows (%.3f)" % [path, float(lit) / float(solid)])
		assert_true(image.get_pixel(1024, 639).a > 0.99, "%s: solid at the foot" % path)
		assert_true(image.get_pixel(1024, 2).a < 0.01, "%s: clear at the top" % path)
