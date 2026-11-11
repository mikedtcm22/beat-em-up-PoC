extends GutTest
## Milestone 7, T10: the trailer profile's night street. Flipping to the trailer builds the lamps, halos, pools, windows, cards and
## contact shadows on the street, swaps in the painted sky and sets the glow; flipping back to m6 frees them and puts the old
## sky object, glow, sun shadow, light and fog back exactly. The m6 profile builds none of it.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const SETTLE_FRAMES := 4


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)


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


func _look(level: LevelRoot) -> TrailerLook:
	return level.get_node("TrailerLook") as TrailerLook


func _env_state(level: LevelRoot) -> Dictionary:
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := level.get_node("Sun") as DirectionalLight3D
	return {
		sky = env.sky.sky_material, glow = env.glow_enabled, threshold = env.glow_hdr_threshold, intensity = env.glow_intensity,
		strength = env.glow_strength, bloom = env.glow_bloom, fog = env.fog_light_color, density = env.fog_density,
		sun_shadow = sun.shadow_enabled, sun_color = sun.light_color, sun_energy = sun.light_energy, sun_rot = sun.rotation_degrees,
		lights = level.find_children("*", "OmniLight3D", true, false).size(),
	}


func test_the_trailer_profile_carries_the_street_look_as_a_row() -> void:
	var row := LookProfile.data(LookProfile.Id.TRAILER).light_overrides.get(NightLook.KEY) as NightLook
	assert_not_null(row, "trailer.tres holds the night street under its own key")
	assert_eq(row.location, &"street_night")
	assert_true(row.lamps.size() >= 4, "the street has its lamps")
	assert_true(LookProfile.data(LookProfile.Id.TRAILER).bloom_allowed, "the lamps and fire may bloom")
	assert_true(LookProfile.data(LookProfile.Id.M6).light_overrides.is_empty(), "m6 has no row")


func test_the_look_row_is_not_a_light_in_the_blend() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_false(level.current_light().has(NightLook.KEY), "the row never reaches the blended light")
	var street := level.sections[0]
	assert_eq(street.look_location, &"street_night")
	var row := NightLook.for_location(street.look_location)
	assert_eq(level.current_light().sun_color, row.sun_color, "the moon is in the sun's slot")


func test_m6_builds_nothing() -> void:
	var level := await _build()
	assert_false(_look(level).is_active())
	assert_eq(_look(level).streets().size(), 0)
	assert_eq(level.find_children("*", "OmniLight3D", true, false).size(), 0, "no lamp light in m6")


func test_the_trailer_flip_builds_the_street_and_back_restores_m6_exactly() -> void:
	var level := await _build()
	var m6 := _env_state(level)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var look := _look(level)
	assert_true(look.is_active())
	assert_eq(look.streets().size(), 1, "one street")
	var row := NightLook.for_location(&"street_night")
	var street := look.streets()[0]
	assert_eq(street.lights().size(), row.lamps.size(), "a light per lamp")
	assert_not_null(look.sky_material(), "the painted sky")
	assert_true(look.haze_material() != null, "the haze")
	var night := _env_state(level)
	assert_ne(night.sky, m6.sky, "another sky object")
	assert_true(night.glow, "bloom is on")
	assert_almost_eq(night.threshold, row.glow_threshold, 0.0001)
	assert_false(night.sun_shadow, "painted contact shadows stand in for the moon's shadow map")
	assert_eq(night.sun_color, row.sun_color)
	assert_true(street.get_child_count() > row.lamps.size() * 3, "poles, halos and pools are built")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(3)
	assert_false(look.is_active())
	assert_eq(look.streets().size(), 0)
	assert_eq(_env_state(level), m6, "the sky object, glow, fog, sun and lights are M6's again, exactly")


func test_contact_shadows_follow_enemies_and_the_live_multipliers_apply() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var enemy := level.spawner.spawn_enemy(&"punk", level.player.global_position + Vector3(0.0, 0.0, -4.0), 0.0)
	await _ticks(3)
	var look := _look(level)
	assert_eq(look.actor_shadow_count(), 1, "a shadow under the Punk")
	Tuning.set_value(&"night_lamp_energy", 2.0)
	var rig := look.streets()[0].rigs()[0]
	assert_almost_eq((rig.light as OmniLight3D).light_energy, (rig.lamp as NightLamp).energy * 2.0, 0.0001)
	EncounterSpawner.remove_enemy(enemy)
	await _ticks(3)
	assert_eq(look.actor_shadow_count(), 0, "gone with the Punk")


func test_the_sky_follows_the_levels_light() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var sky := _look(level).sky_material()
	var row := NightLook.for_location(&"street_night")
	assert_eq(sky.get_shader_parameter(&"zenith_color"), row.sky_top)
	assert_eq(sky.get_shader_parameter(&"horizon_color"), row.sky_horizon)
