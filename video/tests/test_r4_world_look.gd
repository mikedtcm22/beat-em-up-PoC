extends GutTest
## R4-WORLD's checks (round 4: light and atmosphere drawn as shapes, darks as masses): the paint shader declares the round 4 uniforms and never reads the clock; every look turns
## them on and names only real uniforms; the steam is a few drawn plumes (cards redrawn on twos from the shot's frame), not particles; the lamp shaft is a brushed wedge; the
## lamp posts taper and lean; the paint knows where the lights are; twin props differ by a transform and a hue. The pixels are windowed: tools/video/shoot.sh <shot> renders them.

const LOOKS: Dictionary = {&"street_night": 0, &"roofs_dusk": 1, &"boss_fire": 2}
const LOOK_PATH := "res://video/look/%s/world.tres"
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const BODY_PATH := "res://video/shaders/flat_paint_env_body.gdshaderinc"
const PAINT_SHADERS: Array[String] = [
	"res://video/shaders/flat_paint_env.gdshader",
	"res://video/shaders/flat_paint_env_scissor.gdshader",
	"res://video/shaders/flat_paint_prop.gdshader",
]
const R4_UNIFORMS: Array[String] = [
	"r4_on", "lamps", "mask_edge", "mask_shape", "key_dir", "key_weight", "key_cut", "fire_lit", "dark_mass", "mass_value", "mass_color", "dark_line_k",
	"dark_detail", "mass_shade", "mass_shade_k", "mass_follow", "mass_prop_hue", "mass_prop_gain", "win_dark_blank", "moon_top_color", "moon_top_gain",
	"moon_top_min", "pool_shape_amp", "pool_bites", "pool_bite_freq", "puddle_rag", "prop_seed", "prop_base_m", "prop_patch",
]
const CLOCK_FREE: Array[String] = [
	"res://video/shaders/steam_plume.gdshader",
	"res://video/shaders/light_shaft.gdshader",
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


func _rig(level: Node) -> VideoWorldRig:
	return level.get_node(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig


func test_the_paint_shaders_declare_the_round4_uniforms_and_the_body_never_reads_the_clock() -> void:
	var regex := RegEx.new()
	regex.compile("\\bTIME\\b")
	assert_null(regex.search(FileAccess.get_file_as_string(BODY_PATH)), "the body never reads TIME")
	for path in PAINT_SHADERS:
		var shader := load(path) as Shader
		var names := {}
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names[String(uniform.name)] = true
		for name in R4_UNIFORMS:
			assert_true(names.has(name), "%s has uniform %s" % [path.get_file(), name])


func test_the_steam_and_shaft_shaders_never_read_the_clock() -> void:
	var regex := RegEx.new()
	regex.compile("\\bTIME\\b")
	for path in CLOCK_FREE:
		var code := FileAccess.get_file_as_string(path)
		assert_false(code.is_empty(), "%s loads" % path.get_file())
		assert_null(regex.search(code), "%s never reads TIME (its frames come from the shot)" % path.get_file())
		assert_not_null(load(path) as Shader, "%s compiles to a shader" % path.get_file())


func test_every_look_turns_round4_on_and_names_real_uniforms() -> void:
	var names := {}
	for uniform: Dictionary in (load(PAINT_SHADERS[0]) as Shader).get_shader_uniform_list():
		names[StringName(uniform.name)] = true
	for location: StringName in LOOKS:
		var look := _look(location)
		assert_eq(float(look.paint.get(&"r4_on", 0.0)), 1.0, "%s: round 4 is on" % location)
		for key: Variant in look.paint:
			assert_true(names.has(StringName(key)), "%s: paint key %s is a uniform" % [location, key])
		assert_lt(float(look.paint[&"dark_line_k"]), 0.6, "%s: out of the light the drawn detail keeps a faint contrast, not the full" % location)
		assert_gt(float(look.paint[&"dark_line_k"]), 0.0, "%s: and never none (the detail stays, never blank walls)" % location)
		assert_lt(look.lights.size(), VideoWorldLook.LAMP_SLOTS + 1, "%s: the paint has a slot for every light" % location)


func test_the_street_steam_is_one_or_two_drawn_plumes_a_vent_not_particles() -> void:
	var look := _look(&"street_night")
	var vents := 0
	for spec in look.emitters:
		if spec.kind == VideoWorldEmitter.Kind.STEAM:
			assert_lte(spec.amount, 2, "one or two plumes for each manhole")
			vents += spec.points.size()
	assert_gt(vents, 0, "the street has vented steam")
	var level := await _build_level()
	look.apply(level)
	var rig := _rig(level)
	assert_eq(rig.plume_materials.size() > 0, true, "the steam is plume cards")
	for node in level.find_children("*", "GPUParticles3D", true, false):
		assert_ne(node.name, &"Emitter_%d" % VideoWorldEmitter.Kind.STEAM, "no particle puffs for the steam")
	await _ticks(2)
	var first: Variant = rig.plume_materials[0].get_shader_parameter(&"slot")
	var before := float(first) if first != null else 0.0
	await _ticks(12)
	var after := float(rig.plume_materials[0].get_shader_parameter(&"slot"))
	assert_gt(after, before, "a plume is redrawn as the shot's frames go on (on twos: its slot is the shot's frame at the flicker rate)")
	assert_eq(after, float(rig.shot_frame() * look.flicker_fps / 60), "from the shot's own frame count, never the clock")


func test_a_lamp_shaft_is_a_few_brush_strokes_with_a_broken_edge() -> void:
	var code := FileAccess.get_file_as_string("res://video/shaders/light_shaft.gdshader")
	assert_true(code.contains("strokes"), "the wedge is painted in strokes")
	assert_true(code.contains("opacity"), "each stroke has its own opacity")
	assert_false(code.contains("pow(1.0 - v, 1.4)"), "no more one smooth constant-opacity fade")
	for location in [&"street_night"]:
		for spec in _look(location).lights:
			if spec.shaft:
				assert_lt(spec.shaft_energy, 0.2, "a shaft is a faint painted shape, not a veil")


func test_a_lamp_post_tapers_and_leans_and_no_two_lean_alike() -> void:
	var level := await _build_level()
	var look := _look(&"street_night")
	look.apply(level)
	var rig := _rig(level)
	var tilts := {}
	var posts := 0
	for node in rig.practicals:
		var lean := node.get_node_or_null("Lean") as Node3D
		if lean == null:
			continue
		posts += 1
		var tilt := rad_to_deg(Vector3.UP.angle_to(lean.basis.y))
		assert_gte(tilt, 0.9, "a post leans at least a degree")
		assert_lte(tilt, 3.1, "and at most about three")
		tilts[snappedf(tilt, 0.05)] = true
	assert_gt(posts, 2, "the street has lamp posts")
	assert_gte(tilts.size(), 3, "they lean by different amounts")
	for spec in look.lights:
		assert_lt(spec.pole_top_m, spec.pole_base_m * 0.6, "the pole tapers: a thin top on a stout foot")


func test_the_paint_knows_where_the_lights_are() -> void:
	var level := await _build_level()
	var look := _look(&"street_night")
	look.apply(level)
	var lamps: Variant = ToonMaterials.trim().get_shader_parameter(&"lamps")
	assert_true(lamps is PackedVector4Array, "the lights' places are on the paint material")
	var places := lamps as PackedVector4Array
	assert_eq(places.size(), VideoWorldLook.LAMP_SLOTS, "padded to the shader's slots")
	var lit := 0
	for place in places:
		if place.w > 0.0:
			lit += 1
	assert_eq(lit, look.lights.size(), "one slot for each light")
	var head := look.lights[0].head_offset()
	assert_almost_eq(places[0].y, head.y + look.lights[0].position.y + (level as LevelRoot).sections[0].global_position.y, 0.01, "at the lamp's head")


func test_twin_props_differ_by_a_transform_and_a_hue() -> void:
	var level := await _build_level()
	_look(&"roofs_dusk").apply(level)
	var tank1 := level.find_child("Tank1", true, false) as PropSpot
	var tank2 := level.find_child("Tank2", true, false) as PropSpot
	assert_not_null(tank1)
	assert_not_null(tank2)
	if tank1 == null or tank2 == null or tank1.art == null or tank2.art == null:
		return
	assert_ne(tank1.art.transform.basis, tank2.art.transform.basis, "the two tanks differ in size and tilt")
	var a := tank1.art.transform.basis.get_scale()
	var b := tank2.art.transform.basis.get_scale()
	assert_gt(absf(a.x - b.x) + absf(a.y - b.y), 0.05, "by a size the eye can see")
	var colors := {}
	for mesh in level.find_children("WaterTank", "MeshInstance3D", true, false):
		var material := (mesh as MeshInstance3D).material_override as ShaderMaterial
		if material != null:
			colors[material.get_shader_parameter(&"albedo")] = true
	assert_gte(colors.size(), 2, "and by a colour")
	_look(&"roofs_dusk").apply(level)
	assert_eq(tank1.art.transform.basis.get_scale().x, a.x, "a second application starts from the art's own transform (no compounding)")


func test_the_round4_act_file_has_its_own_titles() -> void:
	var acts: Array[Dictionary] = load("res://video/acts/r4_world_acts.gd").call(&"acts", null)
	assert_eq(acts.filter(func(a: Dictionary) -> bool: return String(a.title).begins_with("R4World: ")).size(), 6, "one act for each of the six stills")
	assert_eq(acts.filter(func(a: Dictionary) -> bool: return String(a.title).begins_with("R4WorldMotion: ")).size(), 4, "a motion check for each free-camera still")
