extends GutTest
## LD-WORLD2's checks (round 2: drawn detail, no glare): the paint shaders declare the drawn-detail uniforms and never read the clock, every
## look draws (draw_on) and sets only uniforms the shaders have, the haze, halos and fire matte are cut back so nothing washes the walls, the
## game's props are found by name and painted (with the hull they carried), the boss roof's fire band is moved into world space, and the
## round 2 act file shoots the six stills. The pixels are windowed: tools/video/shoot_still.sh "World2:" renders them.

const LOOKS: Dictionary = {&"street_night": 0, &"roofs_dusk": 1, &"boss_fire": 2}
const LOOK_PATH := "res://video/look/%s/world.tres"
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const BODY_PATH := "res://video/shaders/flat_paint_env_body.gdshaderinc"
const PAINT_SHADERS: Array[String] = [
	"res://video/shaders/flat_paint_env.gdshader",
	"res://video/shaders/flat_paint_env_scissor.gdshader",
	"res://video/shaders/flat_paint_prop.gdshader",
]
## The drawn-detail uniforms of round 2 (every one is a number of the look, never a script constant).
const DRAWN_UNIFORMS: Array[String] = [
	"draw_on", "draw_ink_mul", "draw_line_w", "draw_wobble_m", "draw_fade_lo", "draw_fade_hi", "draw_sheet_ink",
	"brick_course_m", "brick_len_m", "brick_keep", "brick_var", "base_h_m", "base_dark", "crack_p", "crack_w", "pipe_p",
	"win_frame_m", "win_lintel_m", "win_sill_m", "win_refl_p", "win_cross", "slab_m", "slab_keep", "slab_var", "puddle_p",
	"puddle_scale", "puddle_color", "ground_gain", "plank_m", "pool_norm_wall", "pool_hue_norm", "pool_cancel",
	"prop_pattern", "prop_rib_m", "fire_top_m", "fire_color", "fire_gain", "fire_mix",
]
const PROP_NAMES: Array[String] = ["AcUnit", "Car", "Dumpster", "WaterTank"]
## The most alpha a haze band may have (a wash over walls and ground is what Game-boy saw at Gate 1).
const HAZE_ALPHA_MAX := 0.15
const HALO_MAX_M := 0.9


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


func test_the_body_declares_the_drawn_detail_uniforms_and_never_reads_the_clock() -> void:
	var code := FileAccess.get_file_as_string(BODY_PATH)
	for name in DRAWN_UNIFORMS:
		assert_true(code.contains(" %s" % name), "the body declares %s" % name)
	var regex := RegEx.new()
	regex.compile("\\bTIME\\b")
	assert_null(regex.search(code), "the body never reads TIME (every line is anchored in the world or the face)")
	for path in PAINT_SHADERS:
		var shader := load(path) as Shader
		var names := {}
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names[String(uniform.name)] = true
		for name in DRAWN_UNIFORMS:
			assert_true(names.has(name), "%s has uniform %s" % [path.get_file(), name])


func test_every_look_draws_and_names_only_real_uniforms() -> void:
	var shader := load(PAINT_SHADERS[0]) as Shader
	var names := {}
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names[StringName(uniform.name)] = true
	for location: StringName in LOOKS:
		var look := _look(location)
		assert_eq(float(look.paint.get(&"draw_on", 0.0)), 1.0, "%s: the drawn detail is on" % location)
		assert_eq(float(look.paint.get(&"window_blank_p", 0.0)), 0.0, "%s: no window is blanked to a mosaic any more" % location)
		for key: Variant in look.paint:
			assert_true(names.has(StringName(key)), "%s: paint key %s is a uniform" % [location, key])


func test_no_wash_the_haze_and_the_halos_are_cut_back() -> void:
	for location: StringName in LOOKS:
		var look := _look(location)
		for key in [&"band_color_1", &"band_color_2", &"band_color_3"]:
			if look.haze.has(key):
				var color: Color = look.haze[key]
				assert_lte(color.a, HAZE_ALPHA_MAX, "%s: haze %s is thin (it was 0.12 to 0.36)" % [location, key])
		if look.haze.has(&"mist_color"):
			assert_lte((look.haze[&"mist_color"] as Color).a, 0.1, "%s: the ground mist is thin" % location)
		for spec in look.lights:
			if spec.halo:
				assert_lte(spec.halo_m, HALO_MAX_M, "%s: a halo card is a small contained source" % location)


func test_the_lamps_and_the_wall_pools_keep_the_walls_readable() -> void:
	var street := _look(&"street_night")
	assert_lte(float(street.paint[&"pool_norm_wall"]), 0.2, "a lamp's pool does not lift a wall's value to a flat colour")
	assert_gt(float(street.paint[&"pool_hue_norm"]), 0.0, "a pool is the lamp's colour whatever the paint (no pink)")
	assert_gt(float(street.paint[&"puddle_p"]), 0.0, "the street has puddles")
	for spec in street.lights:
		assert_lt(spec.range_m, 7.0, "a lamp's pool is small")


func test_the_looks_carry_the_props_the_game_builds() -> void:
	for location: StringName in LOOKS:
		var look := _look(location)
		for name in PROP_NAMES:
			assert_true(look.props.has(name), "%s: the look paints the %s" % [location, name])
			var spec: Dictionary = look.props[name]
			assert_between(int(spec[&"pattern"]), 0, 4, "%s: %s has a pattern" % [location, name])
			assert_true(spec[&"color"] is Color, "%s: %s has a colour" % [location, name])
	var material := _look(&"street_night").prop_material(Color.RED)
	assert_eq(material.shader.resource_path, "res://video/shaders/flat_paint_prop.gdshader", "a prop is painted by the prop paint")


func test_applying_a_look_paints_the_games_props_and_keeps_their_hull() -> void:
	var level := await _build_level()
	var tanks := level.find_children("WaterTank", "MeshInstance3D", true, false)
	var dumpsters := level.find_children("Dumpster", "MeshInstance3D", true, false)
	assert_false(tanks.is_empty(), "the roofs have a water tank")
	assert_false(dumpsters.is_empty(), "the street has a dumpster")
	var hulls := {}
	for node in tanks + dumpsters:
		var mesh := node as MeshInstance3D
		var original: Material = mesh.mesh.surface_get_material(0) if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 else null
		if mesh.get_surface_override_material(0) != null:
			original = mesh.get_surface_override_material(0)
		hulls[mesh] = original.next_pass if original != null else null
	_look(&"street_night").apply(level)
	for node in tanks + dumpsters:
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as ShaderMaterial
		assert_not_null(material, "%s wears the prop paint" % mesh.name)
		if material == null:
			continue
		assert_eq(material.shader.resource_path, "res://video/shaders/flat_paint_prop.gdshader", "%s: the prop shader" % mesh.name)
		assert_gte(int(material.get_shader_parameter(&"prop_pattern")), 0, "%s: a pattern is set" % mesh.name)
		assert_eq(material.next_pass, hulls[mesh], "%s keeps the hull it carried" % mesh.name)
	var patterns := {}
	for node in tanks:
		patterns[int((node as MeshInstance3D).material_override.get_shader_parameter(&"prop_pattern"))] = true
	assert_true(patterns.has(0), "the tank is drawn with the tank's staves and hoops")
	# A second application (another location) paints again and does not stack hulls.
	_look(&"roofs_dusk").apply(level)
	for node in tanks:
		assert_eq((node as MeshInstance3D).material_override.next_pass, hulls[node], "a second look keeps the one hull")


func test_the_boss_fire_band_is_moved_into_world_space() -> void:
	var level := await _build_level()
	var boss := _look(&"boss_fire")
	boss.apply(level)
	var trim := ToonMaterials.trim()
	var rig := level.get_node(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig
	var expected: float = float(boss.paint[&"fire_top_m"]) + rig.section_origin().y
	assert_almost_eq(float(trim.get_shader_parameter(&"fire_top_m")), expected, 0.001, "the fire's height is metres above the roof's floor")
	_look(&"street_night").apply(level)
	assert_null(trim.get_shader_parameter(&"fire_top_m"), "another location leaves no fire band on the walls")


func test_the_round2_act_file_shoots_the_six_stills() -> void:
	var acts_script := load("res://video/acts/ld_world2_acts.gd")
	var acts: Array[Dictionary] = acts_script.call(&"acts", null)
	var drawn := acts.filter(func(a: Dictionary) -> bool: return String(a.title).begins_with("World2: "))
	var motion := acts.filter(func(a: Dictionary) -> bool: return String(a.title).begins_with("World2Motion: "))
	assert_eq(drawn.size(), 6, "one act for each of the six Gate 1 stills")
	assert_eq(motion.size(), 4, "a motion check for each free-camera still")
	var round1 := load("res://video/acts/ld_world_acts.gd").call(&"acts", null) as Array[Dictionary]
	for act in acts:
		for old in round1:
			assert_ne(act.title, old.title, "round 2's act titles do not collide with round 1's")
