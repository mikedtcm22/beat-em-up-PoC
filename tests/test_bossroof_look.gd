extends GutTest
## Milestone 7 (e-bossroof): the boss roof under the trailer look profile. The trailer profile carries a BossroofLook row for the section
## `boss_roof`; flipping to the trailer builds the fire wall (our shader, the street's flame cards in front of it), the skyline plates, a flat
## silhouette over each kit skyline block, the embers and the fire's lamps; flipping back to m6 frees all of it and shows the street's matte
## cards again. Nothing is built, and nothing is drawn, under m6. The effects hold on twos and the street's effect shaders are used unedited.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const SETTLE_FRAMES := 4


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)


func after_each() -> void:
	Tuning.reset_to_default()
	ToonMaterials.clear_area_look()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _build() -> LevelRoot:
	var root := (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	root.waves_enabled_on_start = false
	add_child_autofree(root)
	await _ticks(SETTLE_FRAMES)
	return root


func _fx(level: LevelRoot) -> BossroofFx:
	return level.sections[2].get_node("BossroofFx") as BossroofFx


func _put_player_on_roof(level: LevelRoot) -> void:
	level.player.global_position = level.sections[2].to_global(Vector3(0.0, 0.0, -2.0))


func test_the_trailer_profile_carries_the_boss_roof_as_a_row() -> void:
	var row := NightLook.for_location(&"boss_roof") as BossroofLook
	assert_null(row, "m6 has no row (the profile running now is m6)")
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	row = NightLook.for_location(&"boss_roof") as BossroofLook
	assert_not_null(row, "trailer.tres holds the boss roof's area look")
	assert_eq(row.location, &"boss_roof")
	assert_false(row.builds_street(), "the fire's lamps are built by BossroofFx")
	var kinds: Array[int] = []
	for wall in row.walls:
		kinds.append(wall.kind)
	assert_true(kinds.has(BossroofWall.Kind.FIRE), "a fire wall")
	assert_true(kinds.has(BossroofWall.Kind.PLATE), "a skyline plate")
	assert_not_null(NightLook.for_location(&"street_night"), "the street's row is still found")
	var roof := (load("res://game/level/mission1/boss_roof.tscn") as PackedScene).instantiate()
	assert_eq(roof.get(&"look_location"), &"boss_roof", "the section names the look")
	roof.free()


func test_the_row_is_not_a_light_in_the_blend() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	_put_player_on_roof(level)
	await _ticks(SETTLE_FRAMES)
	for key: Variant in level.current_light():
		assert_false(level.current_light()[key] is NightLook, "no look row reaches the blended light")
	var row := NightLook.for_location(&"boss_roof")
	assert_eq(level.light_for(level.sections[2]).sun_color, row.sun_color, "the sky-side key is in the sun's slot")
	assert_eq(level.light_for(level.sections[2]).sky_horizon, row.sky_horizon, "the fire's colour is the horizon's")


func test_m6_builds_nothing() -> void:
	var level := await _build()
	var fx := _fx(level)
	assert_false(fx.is_built())
	assert_eq(fx.get_child_count(), 0, "no node under m6")
	assert_eq(fx.materials().size(), 0)
	assert_null(fx.street())
	assert_eq(level.sections[2].find_children("*", "OmniLight3D", true, false).size(), 0, "no fire light in m6")


func test_the_trailer_flip_builds_the_dressing_and_back_frees_it() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var fx := _fx(level)
	assert_true(fx.is_built())
	var row := NightLook.for_location(&"boss_roof") as BossroofLook
	var counts := fx.counts()
	var fires := 0
	var plates := 0
	var flames := 0
	for wall in row.walls:
		if wall.kind == BossroofWall.Kind.FIRE:
			fires += 1
			flames += wall.flames
		else:
			plates += 1
	assert_eq(counts.fire, fires, "a fire cloud per fire wall")
	assert_eq(counts.flames, flames, "the street's flame cards along the foot of each")
	assert_eq(counts.plates, plates)
	assert_true(counts.faces >= 1, "the kit's skyline blocks get a flat face")
	assert_eq(counts.embers, Tuning.data.bossroof_embers)
	assert_eq(fx.street().lights().size(), row.lamps.size(), "a light per fire lamp")
	assert_eq(level.sections[2].find_children("*", "OmniLight3D", true, false).size(), row.lamps.size())
	assert_eq(_look_streets(level), 1, "TrailerLook builds the street's dressing only: the boss roof's is BossroofFx's")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(3)
	assert_false(fx.is_built())
	assert_eq(fx.get_child_count(), 0)
	assert_eq(level.sections[2].find_children("*", "OmniLight3D", true, false).size(), 0)


func _look_streets(level: LevelRoot) -> int:
	return (level.get_node("TrailerLook") as TrailerLook).streets().size()


func test_the_shaders_are_ours_and_the_streets_unedited() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var paths := {}
	for mat in _fx(level).materials():
		paths[mat.shader.resource_path] = true
	assert_true(paths.has("res://game/fx/bossroof_fire.gdshader"))
	assert_true(paths.has("res://game/fx/street_flame.gdshader"), "the street's flame card, a new material instance of it")
	assert_true(paths.has("res://game/fx/street_ember.gdshader"), "the street's embers, a new material instance of it")


func test_the_drawing_holds_on_twos() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var fx := _fx(level)
	# Step to the start of a drawing, then a little of one, then the rest.
	var guard := 0
	var start := fx.slot()
	while fx.slot() == start and guard < 10000:
		fx.advance(0.001)
		guard += 1
	var before := fx.slot()
	fx.advance(0.4 / Tuning.data.bossroof_twos_hz)
	assert_eq(fx.slot(), before, "less than a drawing later it is the same drawing")
	fx.advance(0.8 / Tuning.data.bossroof_twos_hz)
	assert_eq(fx.slot(), before + 1, "a drawing later, the next one")
	for mat in fx.materials():
		assert_eq(mat.get_shader_parameter(&"slot"), float(fx.slot()), "every material shows the drawing")


func test_a_tunable_rebuilds_the_embers_and_zero_builds_none() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var fx := _fx(level)
	Tuning.set_value(&"bossroof_embers", 10)
	assert_eq(fx.counts().embers, 10)
	Tuning.set_value(&"bossroof_embers", 0)
	assert_eq(fx.counts().embers, 0)
	assert_true(fx.is_built(), "the rest stays")


func test_the_street_mattes_are_hidden_on_the_boss_roof_only() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var mattes := level.sections[0].find_children("Matte*", "MeshInstance3D", true, false)
	assert_false(mattes.is_empty(), "the street has its matte")
	assert_true((mattes[0] as Node3D).visible, "shown in the street")
	_put_player_on_roof(level)
	await _ticks(SETTLE_FRAMES + 30)
	assert_false((mattes[0] as Node3D).visible, "hidden on the boss roof, where the street's plate would hang inside the arena")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(3)


func test_the_painted_characters_take_the_areas_rim_on_the_boss_roof() -> void:
	var level := await _build()
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var street := NightLook.for_location(&"street_night")
	var roof := NightLook.for_location(&"boss_roof")
	assert_eq(ToonMaterials._area_rim_color, street.paint_rim_color, "the street's lamps' rim while in the street")
	_put_player_on_roof(level)
	await _ticks(SETTLE_FRAMES + 4)
	assert_eq(ToonMaterials._area_rim_color, roof.paint_rim_color, "the sky's cold rim on the boss roof")
	assert_eq(ToonMaterials._area_shadow_hue, roof.paint_shadow_hue)
