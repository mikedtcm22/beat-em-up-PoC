extends GutTest
## LD-WORLD3's checks (round 3: drawn, not tiled): the paint shader declares the round 3 uniforms, never reads the clock and has the focus, the far
## flattening, the clusters and the window kinds; every look turns round 3 on and names only real uniforms; a wall under a lamp no longer takes
## the ground's corrections; the new atmosphere shaders (contact shadow, lamp shaft, painted flame) are clock-free; the painted sprites are
## deterministic with anti-aliased edges; the contact shadows are placed from the characters' positions in world space; the animation counts from
## the shot, not from the process; the sun's shadow blur floor survives; the Gemini backdrops are cut and in place. The pixels are windowed:
## tools/video/shoot.sh <shot> renders them.

const LOOKS: Dictionary = {&"street_night": 0, &"roofs_dusk": 1, &"boss_fire": 2}
const LOOK_PATH := "res://video/look/%s/world.tres"
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const BODY_PATH := "res://video/shaders/flat_paint_env_body.gdshaderinc"
const PAINT_SHADERS: Array[String] = [
	"res://video/shaders/flat_paint_env.gdshader",
	"res://video/shaders/flat_paint_env_scissor.gdshader",
	"res://video/shaders/flat_paint_prop.gdshader",
]
const CLOCK_FREE: Array[String] = [
	"res://video/shaders/contact_shadow.gdshader",
	"res://video/shaders/light_shaft.gdshader",
	"res://video/shaders/flame_painted.gdshader",
	"res://video/shaders/haze_matte.gdshader",
]
const V3_UNIFORMS: Array[String] = [
	"v3_on", "focus", "focus_on", "focus_floor", "far_m", "mass_far_m", "mass_far_mul", "mass_focus_mul", "cluster_scale",
	"cluster_cover", "cluster_base", "brick_weight", "face_vary", "sheet_gate_lo", "win_kinds", "chain_panel_m", "chain_sag_m",
	"chain_far_m", "pool_wobble", "pool_wobble_freq", "pool_wall_gain", "pool_wall_hue", "pool_wall_damp",
]


func after_each() -> void:
	VideoWorldLook.restore_game_materials()
	Tuning.reset_to_default()


func _look(location: StringName) -> VideoWorldLook:
	return load(LOOK_PATH % location) as VideoWorldLook


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


func test_the_body_declares_the_round3_uniforms_and_never_reads_the_clock() -> void:
	var code := FileAccess.get_file_as_string(BODY_PATH)
	var regex := RegEx.new()
	regex.compile("\\bTIME\\b")
	assert_null(regex.search(code), "the body never reads TIME")
	for path in PAINT_SHADERS:
		var shader := load(path) as Shader
		var names := {}
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names[String(uniform.name)] = true
		for name in V3_UNIFORMS:
			assert_true(names.has(name), "%s has uniform %s" % [path.get_file(), name])


func test_the_new_atmosphere_shaders_never_read_the_clock() -> void:
	var regex := RegEx.new()
	regex.compile("\\bTIME\\b")
	for path in CLOCK_FREE:
		var code := FileAccess.get_file_as_string(path)
		assert_false(code.is_empty(), "%s loads" % path.get_file())
		assert_null(regex.search(code), "%s never reads TIME (frames come from the shot)" % path.get_file())
		assert_not_null(load(path) as Shader, "%s compiles to a shader" % path.get_file())


func test_every_look_turns_round3_on_with_sane_ranges() -> void:
	var shader := load(PAINT_SHADERS[0]) as Shader
	var names := {}
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names[StringName(uniform.name)] = true
	for location: StringName in LOOKS:
		var look := _look(location)
		assert_eq(float(look.paint.get(&"v3_on", 0.0)), 1.0, "%s: round 3 is on" % location)
		assert_eq(float(look.paint.get(&"focus_on", 0.0)), 1.0, "%s: the focus cuts the detail away from the subject" % location)
		for key: Variant in look.paint:
			assert_true(names.has(StringName(key)), "%s: paint key %s is a uniform" % [location, key])
		var far: Vector2 = look.paint.get(&"far_m", Vector2(14, 34))
		assert_lt(far.x, far.y, "%s: detail thins before it is gone" % location)
		assert_gte(far.y, 30.0, "%s: past about 30 m the wall is a flat plane (the P1 bar)" % location)
		assert_lte(float(look.paint.get(&"brick_weight", 1.0)), 1.0, "%s: a brick line is not heavier than a structure line" % location)
		assert_gt(look.focus_radius_m, 1.0, "%s: the focus has a radius" % location)


func test_a_wall_under_a_lamp_takes_no_fixed_moon_cancel() -> void:
	var code := FileAccess.get_file_as_string(BODY_PATH)
	var wall_at := code.find("if (v3_on > 0.0 && !on_ground)")
	assert_gt(wall_at, 0, "the pool branch has a wall case for round 3")
	var wall_block := code.substr(wall_at, code.find("} else {", wall_at) - wall_at)
	assert_false(wall_block.contains("pool_cancel"), "the wall case never subtracts the ground's fixed pool_cancel (it made navy walls crimson)")
	assert_false(wall_block.contains("pool_hue_norm"), "the wall case never applies the ground's full hue fix")
	var street := _look(&"street_night")
	assert_lte(float(street.paint[&"pool_wall_hue"]), 1.0)
	assert_lt(float(street.paint[&"pool_wall_damp"]), 1.0, "the moon a wall already took is damped inside the pool (warm, not rose)")


func test_the_street_is_navy_dark_not_royal_blue() -> void:
	var street := _look(&"street_night")
	assert_lte(street.sun_energy, 0.55, "the moon is weak (it was 0.65)")
	var tint: Color = street.paint[&"paint_shadow_tint"]
	assert_lt(tint.get_luminance(), 0.12, "the shadow band is near-black navy (it was a bright (0.18, 0.27, 0.5))")
	assert_gt(tint.b, tint.r, "and navy, not grey")
	for spec in street.lights:
		assert_lt(spec.range_m, 7.0, "a lamp's pool stays small")


func test_the_boss_roof_is_keyed_amber_not_violet() -> void:
	var boss := _look(&"boss_fire")
	assert_gt(boss.sun_color.r, boss.sun_color.b + 0.3, "the directional key is the fire's amber (it was violet)")
	assert_gt(boss.mattes.size(), 0, "the boss roof hangs a painted backdrop")
	var card: VideoMatteCard = boss.mattes[0]
	assert_eq(card.texture.resource_path, "res://assets/video/mattes/matte_boss_fire_sky.png", "the fire and smoke are the painted backdrop, not the row of spikes")
	assert_gt(card.drift, 0.0, "the painted smoke drifts")


func test_the_backdrops_are_cut_and_in_place() -> void:
	var street := _look(&"street_night").mattes[0] as VideoMatteCard
	var roof := _look(&"roofs_dusk").mattes[0] as VideoMatteCard
	for card in [street, roof]:
		var image := (card.texture as Texture2D).get_image()
		assert_eq(image.get_format(), Image.FORMAT_RGBA8, "a skyline is RGBA")
		var sky := image.get_pixel(image.get_width() / 2, 4)
		assert_lt(sky.a, 0.05, "the keyed sky is transparent (%s)" % card.texture.resource_path.get_file())
		var ground := image.get_pixel(image.get_width() / 2, image.get_height() - 4)
		assert_gt(ground.a, 0.95, "the buildings are opaque")
		assert_lt(maxf(0.0, sky.g - maxf(sky.r, sky.b)), 0.2, "no green key is left in the sky")
	var fire := ((_look(&"boss_fire").mattes[0] as VideoMatteCard).texture as Texture2D).get_image()
	assert_gt(fire.get_pixel(fire.get_width() / 2, fire.get_height() / 2).a, 0.99, "the fire painting is opaque")


func test_the_painted_sprites_are_deterministic_and_anti_aliased() -> void:
	var a := VideoWorldSprites.puff_atlas().get_image()
	var b := VideoWorldSprites.puff_atlas().get_image()
	assert_eq(a.get_data(), b.get_data(), "the steam atlas is the same every time")
	assert_eq(a.get_width(), VideoWorldSprites.PUFF_ATLAS_PX * VideoWorldSprites.ATLAS_FRAMES)
	var embers := VideoWorldSprites.ember_atlas().get_image()
	assert_eq(embers.get_width(), VideoWorldSprites.EMBER_ATLAS_PX * VideoWorldSprites.ATLAS_FRAMES)
	for image: Image in [a, embers]:
		var partial := 0
		var solid := 0
		for y in range(0, image.get_height(), 2):
			for x in range(0, image.get_width(), 2):
				var alpha := image.get_pixel(x, y).a
				if alpha > 0.98:
					solid += 1
				elif alpha > 0.03:
					partial += 1
		assert_gt(partial, 20, "the edge is smoothed (partial alpha exists), no stair-step")
		assert_gt(solid, partial, "but the shape is a hard drawn shape, not a soft cloud")
	# Each frame is its own shape: the first two frames differ.
	var frame := VideoWorldSprites.PUFF_ATLAS_PX
	var f0 := a.get_region(Rect2i(0, 0, frame, frame)).get_data()
	var f1 := a.get_region(Rect2i(frame, 0, frame, frame)).get_data()
	assert_ne(f0, f1, "the steam puffs are varied shapes")


func test_the_contact_shadow_is_placed_in_world_space_under_a_character() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var look := _look(&"street_night")
	var rig := VideoWorldRig.new()
	rig.look = look
	rig.level = level
	level.add_child(rig)
	var actor := Node3D.new()
	actor.add_to_group(&"actor")
	level.add_child(actor)
	actor.global_position = Vector3(2.0, 0.0, -9.0)
	var contact := VideoWorldContact.new()
	contact.look = look
	contact.rig = rig
	rig.add_child(contact)
	await _ticks(3)
	assert_eq(contact.get_child_count(), 1, "one shadow for the one character")
	var plane := contact.get_child(0) as MeshInstance3D
	assert_almost_eq(plane.global_position.x, 2.0, 0.01, "at the character's feet")
	assert_almost_eq(plane.global_position.z, -9.0, 0.01)
	assert_almost_eq(plane.global_position.y, look.contact_lift_m, 0.001, "just above the floor")
	actor.global_position = Vector3(-1.0, 0.0, -4.0)
	await _ticks(2)
	assert_almost_eq(plane.global_position.x, -1.0, 0.01, "it follows the character")
	assert_eq(plane.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a painted shape, never a shadow-map caster")


func test_the_animation_counts_from_the_shot_not_from_the_process() -> void:
	var level := await _build_level()
	var look := _look(&"street_night")
	look.apply(level)
	var rig := level.get_node(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig
	assert_eq(rig.shot_frame(), 0, "a look starts its own count at zero")
	await _ticks(7)
	assert_eq(rig.shot_frame(), 7, "and counts the frames since")
	# The lamp flicker is a function of the shot's slot and the practical's index: it never touches an instance id.
	var code := FileAccess.get_file_as_string("res://video/world/world_rig.gd")
	assert_false(code.contains("get_instance_id"), "no flicker phase from an instance id (it differed between runs)")
	assert_false(code.contains("Engine.get_physics_frames() * look"), "no flicker from the absolute physics frame")


func test_the_focus_rides_the_camera_and_reaches_the_paint() -> void:
	var level := await _build_level()
	var look := _look(&"street_night")
	look.apply(level)
	var rig := level.get_node(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig
	await _ticks(2)
	var focus: Variant = ToonMaterials.trim().get_shader_parameter(&"focus")
	assert_true(focus is Vector4, "the focus is written on the paint material")
	assert_almost_eq((focus as Vector4).w, look.focus_radius_m, 0.001, "with the look's radius")
	assert_gt(look.live_materials.size(), 1, "the rig knows every paint material to write")
	assert_not_null(rig)


func test_the_suns_shadow_blur_is_a_floor_other_pieces_may_raise() -> void:
	var level := await _build_level()
	var look := _look(&"roofs_dusk")
	look.apply(level)
	var rig := level.get_node(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig
	var sun := rig.sun
	assert_not_null(sun)
	sun.shadow_blur = look.sun_shadow_blur + 3.0
	rig.assert_sun()
	assert_almost_eq(sun.shadow_blur, look.sun_shadow_blur + 3.0, 0.001, "the world piece never lowers the ink piece's blur floor")


func test_the_round3_act_file_shoots_the_six_stills_with_its_own_titles() -> void:
	var acts: Array[Dictionary] = load("res://video/acts/ld_world3_acts.gd").call(&"acts", null)
	var drawn := acts.filter(func(a: Dictionary) -> bool: return String(a.title).begins_with("World3: "))
	var motion := acts.filter(func(a: Dictionary) -> bool: return String(a.title).begins_with("World3Motion: "))
	assert_eq(drawn.size(), 6, "one act for each of the six stills")
	assert_eq(motion.size(), 4, "a motion check for each free-camera still")
	for old_path in ["res://video/acts/ld_world_acts.gd", "res://video/acts/ld_world2_acts.gd"]:
		var old: Array[Dictionary] = load(old_path).call(&"acts", null)
		for act in acts:
			for o in old:
				assert_ne(act.title, o.title, "round 3's act titles do not collide with %s" % old_path.get_file())


func test_a_lamp_can_carry_a_shaft_and_a_barrel_a_flame() -> void:
	var look := _look(&"street_night")
	var shafts := 0
	var flames := 0
	for spec in look.lights:
		if spec.shaft:
			shafts += 1
			assert_lt(spec.shaft_energy, 0.2, "a shaft is a faint painted shape, not a veil")
		if spec.flame:
			flames += 1
			assert_eq(spec.prop, VideoWorldLight.Prop.FIRE_BARREL, "only a barrel burns")
	assert_gte(shafts, 2, "a few lamps have shafts")
	assert_eq(flames, 1, "the street's barrel has fire in it")
	var lamp_ranges := {}
	for spec in look.lights:
		if spec.prop == VideoWorldLight.Prop.LAMP_POST:
			lamp_ranges[snappedf(spec.range_m, 0.01)] = true
	assert_gte(lamp_ranges.size(), 3, "no two lamp heads are alike (the pools differ in range)")
