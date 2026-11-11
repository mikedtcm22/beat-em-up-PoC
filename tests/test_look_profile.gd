extends GutTest
## Milestone 7, T05a: the look profile switch. The default is M6's; the trailer profile differs by its marker
## (a sky, horizon and fog colour set held in game/fx/look_profiles/trailer.tres) and nothing else yet; a flip
## (Tuning `look_profile`, F7) re-applies the light, sky, fog, post and materials live, and flipping back
## restores every M6 value exactly, on the Mission 1 street section and on the crowd street; and no simulation
## code reads the profile.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const SETTLE_FRAMES := 4
## The folders whose code is the simulation (combat, actors, enemies, the player, the director): none reads the profile.
const SIMULATION_DIRS: Array[String] = [
	"res://game/combat", "res://game/actors", "res://game/enemies", "res://game/player",
]


func before_each() -> void:
	Tuning.reset_to_default()
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
	await _ticks(SETTLE_FRAMES)
	return root


## Every value the profile could touch under `room`: the Environment and its sky, the sun, LookPost's edge
## material and every ShaderMaterial the room's meshes draw with (all uniforms), keyed by the material's id.
func _snapshot(room: Node) -> Dictionary:
	var out := {}
	var env := (room.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	out.environment = {
		tonemap = env.tonemap_mode, fog_color = env.fog_light_color, fog_density = env.fog_density,
		fog_sky_affect = env.fog_sky_affect, ambient = env.ambient_light_energy, glow = env.glow_enabled,
		adjustment = env.adjustment_enabled, lut = env.adjustment_color_correction,
		sky_top = sky.sky_top_color, sky_horizon = sky.sky_horizon_color,
		ground_horizon = sky.ground_horizon_color, ground_bottom = sky.ground_bottom_color,
	}
	var sun := room.get_node("Sun") as DirectionalLight3D
	out.sun = {
		rotation = sun.rotation_degrees, color = sun.light_color, energy = sun.light_energy, blur = sun.shadow_blur,
	}
	var post := room.get_node("LookPost") as LookPost
	out.edge = _uniforms(post.edge_material())
	var materials: Dictionary = {}
	for node: Node in room.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var found: Array[Material] = [mesh_node.material_override, mesh_node.material_overlay]
		if mesh_node.mesh != null:
			for surface in mesh_node.mesh.get_surface_count():
				found.append(mesh_node.get_active_material(surface))
		for material: Material in found:
			var shader_material := material as ShaderMaterial
			if shader_material != null:
				materials[shader_material.get_instance_id()] = _uniforms(shader_material)
	out.materials = materials
	return out


func _uniforms(material: ShaderMaterial) -> Dictionary:
	var values := {}
	if material.shader == null:
		return values
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		values[uniform.name] = material.get_shader_parameter(uniform.name)
	return values


func test_the_default_profile_is_m6() -> void:
	assert_eq(TuningData.new().look_profile, 0, "the shipped default")
	assert_eq(Tuning.data.look_profile, 0)
	assert_eq(LookProfile.current(), LookProfile.Id.M6)
	assert_eq(LookProfile.profile_name(), &"m6")
	var m6 := LookProfile.data()
	assert_true(m6.light_overrides.is_empty(), "M6 overrides no light")
	assert_eq(m6.grade_lut_path, LookPost.LUT_PATH, "M6's grade")
	assert_false(m6.bloom_allowed)
	assert_eq(m6.ink_width_scale, 1.0)
	assert_eq(m6.vfx_art_dir, VfxArt.DIR)
	var light := {sun_color = Color.RED}
	assert_same(LookProfile.resolve_light(light), light, "M6 hands a light back untouched")


func test_the_tunable_sits_in_its_own_group_before_audio() -> void:
	var group := ""
	var found := false
	var groups: Array[String] = []
	for info: Dictionary in TuningData.new().get_property_list():
		if int(info.usage) & PROPERTY_USAGE_GROUP:
			group = String(info.name)
			groups.append(group)
		elif info.name == "look_profile":
			found = true
			assert_eq(group, "Look profile")
	assert_true(found, "look_profile is a tunable")
	assert_eq(groups.count("Look profile"), 1)
	assert_lt(groups.find("Look profile"), groups.find("Audio"))


func test_the_trailer_profile_holds_its_marker_as_data() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(LookProfile.profile_name(), &"trailer")
	var overrides := LookProfile.data().light_overrides
	for key: StringName in [&"sky_top", &"sky_horizon", &"fog_color"]:
		assert_true(overrides.has(key), "the marker overrides %s" % key)
		assert_ne(overrides[key], RoomKit.default_room_light()[key], "%s differs from M6's" % key)
	var base := RoomKit.default_room_light()
	var light := LookProfile.resolve_light(base)
	assert_eq(light.sky_top, overrides[&"sky_top"])
	assert_eq(light.fog_density, base.fog_density, "what it does not name keeps its value")
	assert_eq(base.sky_top, RoomKit.DEFAULT_SKY_TOP, "the input is not changed")
	assert_eq(LookProfile.data().grade_lut_path, LookPost.LUT_PATH, "the same grade for now")
	Tuning.set_value(&"look_profile", 99)
	assert_eq(LookProfile.current(), LookProfile.Id.TRAILER, "out of range clamps")


func test_the_trailer_flip_changes_only_the_marker_on_the_street_and_back_restores_m6_exactly() -> void:
	var level := await _build(LEVEL_PATH)
	assert_not_null(level.get_node_or_null("LookPost"), "the level has its post pass")
	var m6 := _snapshot(level)
	assert_eq((m6.materials as Dictionary).size() > 5, true, "the street draws with shader materials")
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(2)
	var trailer := _snapshot(level)
	var overrides := LookProfile.data().light_overrides
	assert_eq(trailer.environment.sky_top, overrides[&"sky_top"], "the sky took the marker at once")
	assert_eq(trailer.environment.sky_horizon, overrides[&"sky_horizon"])
	assert_eq(trailer.environment.fog_color, overrides[&"fog_color"])
	assert_ne(trailer.environment.sky_top, m6.environment.sky_top)
	# Nothing else moved: the marker is the three colours.
	var expected := m6.duplicate(true)
	expected.environment.sky_top = overrides[&"sky_top"]
	expected.environment.sky_horizon = overrides[&"sky_horizon"]
	expected.environment.fog_color = overrides[&"fog_color"]
	assert_eq(trailer.environment, expected.environment, "the environment differs by the marker alone")
	assert_eq(trailer.sun, m6.sun, "the sun")
	assert_eq(trailer.edge, m6.edge, "the edge pass")
	assert_eq(trailer.materials, m6.materials, "every material's uniforms")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(2)
	var back := _snapshot(level)
	assert_eq(back.environment, m6.environment, "the environment is M6's again")
	assert_eq(back.sun, m6.sun, "the sun is M6's again")
	assert_eq(back.edge, m6.edge, "the edge pass is M6's again")
	assert_eq(back.materials, m6.materials, "every material's uniforms are M6's again")


func test_the_flip_follows_a_section_with_its_own_light() -> void:
	var level := await _build(LEVEL_PATH) as LevelRoot
	var street := level.sections[0].light()
	assert_eq(level.current_light().sky_top, street.sky_top, "M6: the street's own sky")
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(level.section_light_progress(), 1.0, "the flip is not a blend")
	var overrides := LookProfile.data().light_overrides
	assert_eq(level.current_light().sky_top, overrides[&"sky_top"])
	assert_eq(level.current_light().sun_color, street.sun_color, "the street's sun stays")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(level.current_light().sky_top, street.sky_top, "and back to the street's own sky")
	assert_eq(level.current_light(), LookProfile.resolve_light(street))


func test_a_room_without_sections_flips_too() -> void:
	var room := await _build(CROWD_PATH)
	var m6 := _snapshot(room)
	assert_eq(m6.environment.sky_top, RoomKit.DEFAULT_SKY_TOP)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var trailer := _snapshot(room)
	assert_eq(trailer.environment.sky_top, LookProfile.data().light_overrides[&"sky_top"])
	assert_eq(trailer.environment.fog_color, LookProfile.data().light_overrides[&"fog_color"])
	assert_eq(trailer.sun, m6.sun)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(_snapshot(room), m6, "the crowd street is M6's again, whole")


func test_f7_flips_the_profile_without_errors() -> void:
	assert_true(InputMap.has_action(&"look_profile"), "registered")
	assert_eq(GameInput.BINDINGS[&"look_profile"], [KEY_F7])
	var level := await _build(LEVEL_PATH)
	var press := InputEventAction.new()
	press.action = &"look_profile"
	press.pressed = true
	GameInput._unhandled_input(press)
	assert_eq(LookProfile.current(), LookProfile.Id.TRAILER, "F7 flips to the trailer")
	await _ticks(2)
	GameInput._unhandled_input(press)
	assert_eq(LookProfile.current(), LookProfile.Id.M6, "and back")
	await _ticks(2)
	assert_not_null(level)
	var printed := get_errors()
	for error: GutTrackedError in printed:
		gut.p("printed during the flip: %s %s" % [error.code, error.rationale])
	assert_eq(printed.size(), 0, "no error or warning is printed")


func test_the_profile_scales_the_ink() -> void:
	var room := Node3D.new()
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = Environment.new()
	room.add_child(world_env)
	var post := LookPost.new()
	room.add_child(post)
	add_child_autofree(room)
	var hull := ToonMaterials.outline()
	assert_eq(hull.get_shader_parameter(&"width_px"), Tuning.data.look_outline_px, "M6: Tuning's hull width")
	assert_eq(post.edge_material().get_shader_parameter(&"width_px"), Tuning.data.look_edge_px, "M6: Tuning's line")
	var trailer := LookProfile.data(LookProfile.Id.TRAILER)
	var before := trailer.ink_width_scale
	trailer.ink_width_scale = 2.0
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_almost_eq(float(hull.get_shader_parameter(&"width_px")), Tuning.data.look_outline_px * 2.0, 0.0001)
	assert_almost_eq(float(post.edge_material().get_shader_parameter(&"width_px")), Tuning.data.look_edge_px * 2.0, 0.0001)
	trailer.ink_width_scale = before
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(hull.get_shader_parameter(&"width_px"), Tuning.data.look_outline_px, "back to Tuning's width")
	assert_eq(post.edge_material().get_shader_parameter(&"width_px"), Tuning.data.look_edge_px)


func test_no_simulation_code_reads_the_profile() -> void:
	var scanned := 0
	for dir: String in SIMULATION_DIRS:
		for path: String in _scripts_under(dir):
			scanned += 1
			var text := FileAccess.get_file_as_string(path)
			assert_false(text.contains("LookProfile") or text.contains("look_profile"), "%s does not read the look profile" % path)
	assert_gt(scanned, 30, "the scan found the simulation's scripts")


func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(sub)))
	return out
