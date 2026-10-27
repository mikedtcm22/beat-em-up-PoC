extends GutTest
## The look's post pass (M4-plan P1-post): the edge quad and its tunables (A8), the grade LUT and
## its strength, the AA mode, both rooms built through RoomKit with one LookPost, and the colors of
## the rooms and the paints (A13: red is reserved). The pixels themselves (the lines, the mask)
## are windowed: tests/bot/look_probe.gd and tests/bot/acts/look_post_acts.gd.

const GenLut := preload("res://tools/gen_lut.gd")
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"
const EDGE_SHADER_PATH := "res://game/fx/edge_pass.gdshader"
## The frames the crowd room's navigation map needs after its _ready().
const SYNC_FRAMES := 5
## A13's red band: hue 345 to 15 degrees with saturation above 0.5.
const RED_HUE_FROM := 345.0 / 360.0
const RED_HUE_TO := 15.0 / 360.0
const RED_SATURATION := 0.5
## The look bible's ceiling for the street's own colors (HSV saturation), for the car.
const STREET_SATURATION_MAX := 0.30
## The hull's width bound (the look bible) in pixels at 1080p: the character mask has to reach it.
const HULL_MAX_PX := 4.5
## One step of an 8-bit channel.
const BYTE_STEP := 1.0 / 255.0


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A scratch room: a Node3D with a WorldEnvironment (its Environment returned through `out`) and a
## LookPost in it, in the tree.
func _post_in_room(out: Array = []) -> LookPost:
	var room := Node3D.new()
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = Environment.new()
	room.add_child(world_env)
	var post := LookPost.new()
	room.add_child(post)
	add_child_autofree(room)
	out.append(world_env.environment)
	return post


func _in_red_band(color: Color) -> bool:
	var in_hue := color.h >= RED_HUE_FROM or color.h <= RED_HUE_TO
	return in_hue and color.s > RED_SATURATION


# --- The edge shader and the quad -------------------------------------------------------------


func test_the_edge_shader_loads_in_both_variants() -> void:
	var shader := load(EDGE_SHADER_PATH) as Shader
	assert_not_null(shader, "edge_pass.gdshader loads")
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)
	assert_true(shader.code.contains("EDGE_DEPTH_ONLY"), "it has a depth-only variant")
	var depth_only := LookPost.depth_only_shader()
	assert_true(depth_only.code.begins_with(LookPost.DEPTH_ONLY_DEFINE), "the variant is the source with the define on top")
	assert_true(depth_only.code.ends_with(shader.code))
	assert_same(LookPost.depth_only_shader(), depth_only, "made once")


func test_the_edge_shader_never_reads_the_screen_and_outputs_ink_as_alpha() -> void:
	# A8: a screen copy is taken before the transparent pass and would erase the contact flash.
	var code := (load(EDGE_SHADER_PATH) as Shader).code
	assert_false(code.contains("hint_screen_texture"), "no screen texture")
	assert_true(code.contains("ALBEDO = color") and code.contains("ALPHA = alpha"), "ALBEDO and ALPHA are the output")
	assert_true(code.contains("depth_test_disabled") and code.contains("skip_vertex_transform"))
	assert_true(code.contains("fog_disabled"), "ink is not fogged")


func test_the_quad_is_a_full_screen_transparent_pass_between_the_flash_and_the_sprites() -> void:
	var post := _post_in_room()
	var quad := post.edge_quad()
	assert_not_null(quad)
	assert_true(quad.mesh is QuadMesh)
	assert_eq((quad.mesh as QuadMesh).size, Vector2(2.0, 2.0))
	assert_eq(quad.extra_cull_margin, LookPost.EDGE_CULL_MARGIN, "never culled")
	assert_eq(quad.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var material := quad.material_override as ShaderMaterial
	assert_same(material, post.edge_material())
	assert_eq(material.render_priority, -127, "A8: just above the flash at -128")
	assert_gt(material.render_priority, Material.RENDER_PRIORITY_MIN, "over the contact flash's slot")
	assert_lt(material.render_priority, 0, "under every comic sprite (0 and up)")


func test_edges_enabled_shows_and_hides_the_quad_live() -> void:
	var post := _post_in_room()
	assert_true(post.edge_quad().visible, "on by default")
	Tuning.set_value(&"look_edges_enabled", false)
	assert_false(post.edge_quad().visible, "off hides it (and the renderer makes no buffers)")
	Tuning.set_value(&"look_edges_enabled", true)
	assert_true(post.edge_quad().visible)


func test_every_edge_tunable_reaches_the_shader() -> void:
	var post := _post_in_room()
	var material := post.edge_material()
	var wanted := {
		&"look_edge_px": &"width_px", &"look_edge_depth_threshold": &"depth_threshold",
		&"look_edge_normal_threshold": &"normal_threshold", &"look_edge_fade_start_m": &"fade_start_m",
		&"look_edge_fade_end_m": &"fade_end_m", &"look_edge_mask_px": &"mask_px",
	}
	for property: StringName in wanted:
		assert_eq(material.get_shader_parameter(wanted[property]), Tuning.data.get(property), "%s at its default" % property)
		var changed := float(Tuning.data.get(property)) * 0.5 + 1.0
		Tuning.set_value(property, changed)
		assert_eq(material.get_shader_parameter(wanted[property]), Tuning.data.get(property), "%s follows" % property)
	Tuning.set_value(&"look_edge_character_mask", false)
	assert_false(material.get_shader_parameter(&"character_mask"), "the A8 switch")
	Tuning.set_value(&"look_edge_debug_view", 4)
	assert_eq(material.get_shader_parameter(&"debug_view"), 4)
	assert_eq(material.get_shader_parameter(&"ink"), HudStyle.INK, "one ink for the hull, the edges, the VFX and the HUD")


func test_depth_only_swaps_in_the_cheap_shader_and_back() -> void:
	var post := _post_in_room()
	var full := post.edge_material().shader
	assert_eq(full, load(EDGE_SHADER_PATH))
	Tuning.set_value(&"look_edge_depth_only", true)
	assert_same(post.edge_material().shader, LookPost.depth_only_shader(), "no normal buffer, no mask")
	Tuning.set_value(&"look_edge_depth_only", false)
	assert_eq(post.edge_material().shader, full)


func test_a_preset_load_reapplies_the_look() -> void:
	var post := _post_in_room()
	Tuning.set_value(&"look_edge_px", 3.0)
	Tuning.reset_to_default()
	assert_eq(post.edge_material().get_shader_parameter(&"width_px"), Tuning.defaults().look_edge_px, "the reset reaches it")


# --- The tunables ----------------------------------------------------------------------------


func test_the_defaults_follow_the_look_bible() -> void:
	var d := Tuning.defaults()
	assert_between(d.look_edge_px, 1.0, 1.5, "environment lines 1 to 1.5 px")
	assert_eq(d.look_edge_fade_start_m, 25.0, "fading out from 25 m")
	assert_eq(d.look_edge_fade_end_m, 60.0, "to 60 m")
	assert_gt(d.look_edge_fade_end_m, d.look_edge_fade_start_m)
	assert_gte(d.look_edge_mask_px, HULL_MAX_PX, "the mask reaches the widest hull")
	assert_eq(d.look_aa_mode, LookPost.AaMode.MSAA_4X, "MSAA 4x is the project's own")
	assert_true(d.look_edges_enabled and d.look_grade_enabled)
	assert_eq(d.look_grade_strength, 1.0)
	assert_true(d.look_edge_character_mask, "A8's mask on")
	assert_false(d.look_edge_depth_only)
	assert_eq(d.look_edge_debug_view, 0)


func test_the_edge_and_grade_tunables_sit_in_look_and_the_switches_in_debug() -> void:
	var group_of := {}
	for info: Dictionary in Tuning.tuning_properties():
		group_of[StringName(info.name)] = str(info.group)
	for property: StringName in [&"look_edges_enabled", &"look_edge_px", &"look_edge_depth_threshold",
			&"look_edge_normal_threshold", &"look_edge_fade_start_m", &"look_edge_fade_end_m",
			&"look_edge_mask_px", &"look_aa_mode", &"look_grade_enabled", &"look_grade_strength"]:
		assert_eq(group_of.get(property), "Look", "%s is in Look" % property)
		assert_true(Tuning.is_preset_property(property), "%s is saved in presets" % property)
	for property: StringName in [&"look_edge_debug_view", &"look_edge_character_mask", &"look_edge_depth_only"]:
		assert_eq(group_of.get(property), "Debug", "%s is in Debug" % property)
		assert_false(Tuning.is_preset_property(property), "%s is an A/B, never saved" % property)


# --- The grade -------------------------------------------------------------------------------


func test_the_lut_strip_is_n_slices_of_n_by_n() -> void:
	var recipe := GenLut.load_recipe()
	assert_false(recipe.is_empty(), "the recipe is in assets/source/look/grade.json")
	var strip := (load(LookPost.LUT_PATH) as Texture2D).get_image()
	var n := int(recipe.size)
	assert_eq(strip.get_height(), n)
	assert_eq(strip.get_width(), n * n)


func test_the_committed_lut_is_what_the_recipe_makes() -> void:
	var recipe := GenLut.load_recipe()
	var made := GenLut.build_strip(recipe)
	var strip := (load(LookPost.LUT_PATH) as Texture2D).get_image()
	strip.convert(Image.FORMAT_RGB8)
	assert_eq(strip.get_data(), made.get_data(), "tools/gen_lut.gd was run after the recipe changed")


func test_the_lut_nodes_sit_where_the_renderer_samples() -> void:
	var n := int(GenLut.load_recipe().size)
	assert_eq(GenLut.node_value(0, n), 0.0, "black stays")
	assert_eq(GenLut.node_value(n - 1, n), 1.0, "white stays")
	assert_almost_eq(GenLut.node_value(n / 2, n), (float(n / 2) + 0.5) / float(n), 1e-6, "centres")
	for i in n:
		assert_eq(LookPost.node_value(i, n), GenLut.node_value(i, n), "node %d agrees with the tool" % i)


func test_a_recipe_with_no_effect_makes_the_identity() -> void:
	var recipe := GenLut.load_recipe()
	recipe.shadow_amount = 0.0
	recipe.highlight_amount = 0.0
	recipe.low_chroma_saturation = 1.0
	var n := int(recipe.size)
	var strip := GenLut.build_strip(recipe)
	var identity := LookPost.identity_lut_bytes(n)
	# The strip is slice after slice of rows, the identity too (b, y, x).
	var slices := PackedByteArray()
	for b in n:
		slices.append_array(strip.get_region(Rect2i(b * n, 0, n, n)).get_data())
	assert_eq(slices.size(), identity.size())
	var worst := 0
	for i in identity.size():
		worst = maxi(worst, absi(int(slices[i]) - int(identity[i])))
	assert_lte(worst, 1, "the identity ramp the strength mixes from is the no-op grade, within a rounding")


func test_the_grade_keeps_the_enemies_and_the_blood_within_delta_e_6() -> void:
	var recipe := GenLut.load_recipe()
	var keep := float(recipe.keep_delta_e)
	assert_eq(keep, 6.0, "the look bible: within dE76 6")
	var palette: Dictionary[String, Color] = {
		"blood": Color("#d0141f"), "accent red": Color("#e8302a"), "warning red": Color("#ff4a2e"),
		"blood light": Color("#ff5a5f"), "blood dark": Color("#62070e"),
	}
	var scenes: Array[String] = []
	for entry: Dictionary in EnemyCatalog.available():
		scenes.append(entry.scene)
	scenes.append(RoomKit.PLAYER_SCENE)
	var holder := Node3D.new()
	add_child_autofree(holder)
	for path in scenes:
		var actor := (load(path) as PackedScene).instantiate() as CombatActor
		holder.add_child(actor)
		await _ticks(1)
		for paint: int in PlaceholderBody.Paint.values():
			var color := actor.rig.paint.color_of(paint)
			if color.s >= recipe.chroma_high:
				palette["%s paint %d" % [path.get_file(), paint]] = color
	assert_gt(palette.size(), 12, "the enemies' saturated paints are in the check")
	for key: String in palette:
		var moved := GenLut.delta_e76(palette[key], GenLut.grade(palette[key], recipe))
		assert_lte(moved, keep, "%s moves %.2f" % [key, moved])


func test_black_and_white_stay_and_the_street_is_graded() -> void:
	var recipe := GenLut.load_recipe()
	assert_eq(GenLut.grade(Color.BLACK, recipe), Color.BLACK)
	assert_eq(GenLut.grade(Color.WHITE, recipe), Color.WHITE, "so the hit flash stays white")
	var wall := Color(0.42, 0.4, 0.44)
	assert_gt(GenLut.delta_e76(wall, GenLut.grade(wall, recipe)), 1.0, "the street takes the grade")
	var grey := Color(0.5, 0.5, 0.5)
	var graded := GenLut.grade(grey, recipe)
	assert_lt(GenLut.grade(Color(0.15, 0.15, 0.15), recipe).r, GenLut.grade(Color(0.15, 0.15, 0.15), recipe).b, "cool shadows")
	assert_gt(GenLut.grade(Color(0.75, 0.75, 0.75), recipe).r, GenLut.grade(Color(0.75, 0.75, 0.75), recipe).b, "warm highlights")
	assert_almost_eq(graded.r, graded.g, 0.05, "the middle is nearly neutral")


func test_the_grade_goes_on_the_rooms_environment_as_a_3d_lut() -> void:
	var out: Array = []
	var post := _post_in_room(out)
	var env := out[0] as Environment
	assert_same(post.grade_environment(), env)
	assert_true(env.adjustment_enabled, "on by default")
	var texture := env.adjustment_color_correction as ImageTexture3D
	assert_not_null(texture, "a 3D LUT")
	var n := int(GenLut.load_recipe().size)
	assert_eq([texture.get_width(), texture.get_height(), texture.get_depth()], [n, n, n])
	assert_same(post.grade_texture(), texture)
	Tuning.set_value(&"look_grade_enabled", false)
	assert_false(env.adjustment_enabled, "off takes it away")
	Tuning.set_value(&"look_grade_enabled", true)
	assert_true(env.adjustment_enabled)


func test_the_strength_mixes_the_lut_with_the_identity() -> void:
	var out: Array = []
	var post := _post_in_room(out)
	var env := out[0] as Environment
	var n := int(GenLut.load_recipe().size)
	var identity := LookPost.identity_lut_bytes(n)
	var graded := PackedByteArray()
	var strip := (load(LookPost.LUT_PATH) as Texture2D).get_image()
	strip.convert(Image.FORMAT_RGB8)
	for b in n:
		graded.append_array(strip.get_region(Rect2i(b * n, 0, n, n)).get_data())
	assert_eq(LookPost.mix_lut_bytes(identity, graded, 1.0), graded)
	assert_eq(LookPost.mix_lut_bytes(identity, graded, 0.0), identity)
	var half := LookPost.mix_lut_bytes(identity, graded, 0.5)
	var checked := 0
	for i in range(0, identity.size(), 97):
		assert_almost_eq(float(half[i]), (float(identity[i]) + float(graded[i])) * 0.5, 1.0, "byte %d" % i)
		checked += 1
	assert_gt(checked, 100)
	var before := env.adjustment_color_correction
	Tuning.set_value(&"look_grade_strength", 0.5)
	assert_ne(env.adjustment_color_correction, before, "a new LUT for a new strength")
	assert_true(env.adjustment_enabled)
	var again := env.adjustment_color_correction
	Tuning.set_value(&"look_edge_px", 2.0)
	assert_same(env.adjustment_color_correction, again, "another tunable does not rebuild it")
	assert_not_null(post)


func test_no_environment_means_no_grade_and_no_error() -> void:
	var room := Node3D.new()
	var post := LookPost.new()
	room.add_child(post)
	add_child_autofree(room)
	assert_null(post.grade_environment())
	assert_null(post.grade_texture())
	Tuning.set_value(&"look_grade_strength", 0.3)
	assert_not_null(post.edge_quad(), "the edge pass needs no environment")


# --- The AA mode -----------------------------------------------------------------------------


func test_the_aa_modes_set_the_viewports_msaa_and_fxaa() -> void:
	assert_eq(LookPost.aa_settings(LookPost.AaMode.MSAA_4X), {msaa = Viewport.MSAA_4X, ssaa = Viewport.SCREEN_SPACE_AA_DISABLED})
	assert_eq(LookPost.aa_settings(LookPost.AaMode.FXAA), {msaa = Viewport.MSAA_DISABLED, ssaa = Viewport.SCREEN_SPACE_AA_FXAA})
	assert_eq(LookPost.aa_settings(LookPost.AaMode.OFF), {msaa = Viewport.MSAA_DISABLED, ssaa = Viewport.SCREEN_SPACE_AA_DISABLED})
	var viewport := get_viewport()
	var msaa_before := viewport.msaa_3d
	var ssaa_before := viewport.screen_space_aa
	var post := _post_in_room()
	assert_eq(viewport.msaa_3d, Viewport.MSAA_4X)
	Tuning.set_value(&"look_aa_mode", LookPost.AaMode.FXAA)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	Tuning.set_value(&"look_aa_mode", LookPost.AaMode.OFF)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	post.get_parent().queue_free()
	await get_tree().process_frame
	assert_eq(viewport.msaa_3d, msaa_before, "the viewport gets its own mode back when the room goes")
	assert_eq(viewport.screen_space_aa, ssaa_before)


# --- Both rooms ------------------------------------------------------------------------------


func _crowd(presentation: bool) -> CrowdRoom:
	var room := (load(CROWD_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = presentation
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(SYNC_FRAMES)
	return room


func _training(presentation: bool) -> Node3D:
	var room := (load(TRAINING_PATH) as PackedScene).instantiate() as Node3D
	room.set(&"with_presentation", presentation)
	add_child_autofree(room)
	await _ticks(1)
	return room


func _posts(room: Node) -> Array[LookPost]:
	var out: Array[LookPost] = []
	for child: Node in room.get_children():
		if child is LookPost:
			out.append(child)
	return out


func test_the_crowd_room_builds_one_look_post_on_its_environment() -> void:
	var room := await _crowd(true)
	var posts := _posts(room)
	assert_eq(posts.size(), 1)
	assert_same(posts[0].grade_environment(), (room.get_node("WorldEnvironment") as WorldEnvironment).environment)
	assert_true(posts[0].grade_environment().adjustment_enabled)


func test_the_training_room_builds_its_look_through_roomkit_too() -> void:
	var room := await _training(true)
	var posts := _posts(room)
	assert_eq(posts.size(), 1, "M4 J16: both rooms get the one pass")
	var world_env := room.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_not_null(world_env, "RoomKit.build_environment names it")
	assert_not_null(room.get_node_or_null("Sun"))
	assert_same(posts[0].grade_environment(), world_env.environment)
	assert_true(room.get_children().any(func(n: Node) -> bool: return n is VfxDirector), "and the rest of the presentation")


func test_a_room_without_presentation_has_no_post_pass() -> void:
	assert_eq(_posts(await _crowd(false)).size(), 0)
	assert_eq(_posts(await _training(false)).size(), 0)


func test_the_training_room_floor_and_boxes_use_roomkits_materials() -> void:
	var room := await _training(false)
	var kinds := {}
	for child: Node in room.get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		var mesh := body.get_child(1) as MeshInstance3D
		var material: Material = (mesh.mesh as BoxMesh).material
		kinds[material.get_class()] = true
	assert_true(kinds.has("ShaderMaterial"), "the grid floor")
	assert_gt(kinds.size(), 0)


func test_roomkit_boxes_take_an_overlay() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var overlay := ShaderMaterial.new()
	var solid := RoomKit.add_box(parent, Vector3.ZERO, Vector3.ONE, RoomKit.flat_material(Color.GRAY), overlay)
	assert_same((solid.get_child(1) as MeshInstance3D).material_overlay, overlay, "a solid box's hull")
	var visual := RoomKit.add_visual_box(parent, Vector3.ZERO, Vector3.ONE, RoomKit.flat_material(Color.GRAY), overlay)
	assert_same(visual.material_overlay, overlay)
	var plain := RoomKit.add_visual_box(parent, Vector3.ZERO, Vector3.ONE, RoomKit.flat_material(Color.GRAY))
	assert_null(plain.material_overlay, "none by default")


# --- Red is reserved (A13) -------------------------------------------------------------------


func test_the_red_band_is_what_a13_says() -> void:
	assert_true(_in_red_band(Color("#d0141f")), "blood")
	assert_true(_in_red_band(Color(0.55, 0.2, 0.2)), "the old car")
	assert_false(_in_red_band(Color(0.5, 0.15, 0.2).lerp(Color(0.5, 0.45, 0.45), 0.7)), "a washed-out red is under 0.5")
	assert_false(_in_red_band(Color(0.96, 0.5, 0.08)), "orange is outside")
	assert_false(_in_red_band(Color(0.34, 0.1, 0.5)), "purple is outside")


## The albedo a material shows: a StandardMaterial3D's, or a toon ShaderMaterial's `albedo`.
func _albedo(material: Material) -> Variant:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	if material is ShaderMaterial:
		var value: Variant = (material as ShaderMaterial).get_shader_parameter(&"albedo")
		if value is Color:
			return value
	return null


func _mesh_colors(root: Node) -> Dictionary[String, Color]:
	var out: Dictionary[String, Color] = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material: Material = mesh.material_override
		if material == null and mesh.mesh != null:
			material = mesh.mesh.surface_get_material(0) if mesh.mesh.get_surface_count() > 0 else null
			if material == null and mesh.mesh is PrimitiveMesh:
				material = (mesh.mesh as PrimitiveMesh).material
		var color: Variant = _albedo(material)
		if color is Color:
			out["%s %s" % [mesh.get_path(), color]] = color
	return out


func test_no_environment_or_prop_color_is_red_and_the_car_is_muted() -> void:
	var crowd := await _crowd(false)
	var training := await _training(false)
	var seen := {}
	for room: Node in [crowd, training]:
		var colors := _mesh_colors(room)
		for key: String in colors:
			seen[colors[key]] = true
			assert_false(_in_red_band(colors[key]), "%s is not red" % key)
	assert_gt(seen.size(), 8, "the rooms' colors were read (walls, crates, the car, the dumpster, the street)")
	assert_true(seen.has(Color(0.34, 0.38, 0.45)), "the car is the muted blue-grey")
	var car := Color(0.34, 0.38, 0.45)
	assert_lte(car.s, STREET_SATURATION_MAX, "the car is inside the look bible's street saturation")
	assert_between(car.v, 0.25, 0.6, "and its value")


func test_no_paint_of_an_enemy_the_dummies_or_the_player_is_red() -> void:
	var scenes: Array[String] = [RoomKit.PLAYER_SCENE]
	for entry: Dictionary in EnemyCatalog.available():
		scenes.append(entry.scene)
	var checked := 0
	var holder := Node3D.new()
	add_child_autofree(holder)
	for path in scenes:
		var actor := (load(path) as PackedScene).instantiate() as CombatActor
		holder.add_child(actor)
		await _ticks(1)
		for paint: int in PlaceholderBody.Paint.values():
			var color := actor.rig.paint.color_of(paint)
			assert_false(_in_red_band(color), "%s paint %d %s is not red" % [path.get_file(), paint, color])
			checked += 1
	assert_gt(checked, 30)
	var training := await _training(false)
	for dummy_color: Color in training.get(&"dummy_colors"):
		assert_false(_in_red_band(dummy_color), "the training room's dummy %s" % dummy_color)
