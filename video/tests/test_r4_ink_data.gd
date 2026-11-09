extends GutTest
## R4-INK's data and shader contracts (headless): the brush pass (a screen quad whose shader the look's Brush group writes, never the clock, placed so the
## haze draws over it), the delivery's re-scale (a switch that the grade does not share), and the line hierarchy's values (near heavy, overlap wide, inner
## thin, the environment's lines lighter). The pixels are windowed: see the sheets in docs/video/calls/r4-ink.md.

const LOCATIONS: Array[String] = ["street_night", "roofs_dusk", "boss_fire"]
const BRUSH_PATH := "res://video/shaders/brush_screen.gdshader"
const OUTLINE_PATH := "res://video/shaders/cine_outline.gdshader"
const INK_SCREEN_PATH := "res://video/shaders/ink_screen.gdshader"
const POST_PATH := "res://video/shaders/post_finish.glsl"
const BRUSH_UNIFORMS: Array[String] = ["r_near", "r_far", "depth_near_m", "depth_far_m", "focus_gain", "edge_gain", "edge_start", "r_max", "focus_m",
		"aniso_alpha", "sharpness", "tap_half", "tensor_lod", "wobble_px", "wobble_cell_m", "depth_reject", "post_step", "post_soft", "post_mix",
		"post_noise", "post_cell_m", "fill_amount", "fill_near_px", "fill_far_px", "fill_gate", "debug_view"]


func _look(location: String) -> VideoInkLook:
	return load("res://video/look/%s/ink.tres" % location) as VideoInkLook


func test_every_location_has_the_brush_on_with_sane_radii() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_not_null(look, "%s: the ink piece loads" % location)
		assert_true(look.brush_on, "%s: the brush pass is on" % location)
		assert_gte(look.brush_r_far, look.brush_r_near, "%s: the radius grows with depth" % location)
		assert_gte(look.brush_r_max, look.brush_r_far, "%s: and the cap is not under it" % location)
		assert_gt(look.brush_depth_far_m, look.brush_depth_near_m, "%s: the depth ramp has a width" % location)
		assert_gt(look.brush_post_step, 0.0, "%s: the world is posterized" % location)
		assert_gt(look.brush_wobble_px, 0.0, "%s: and wobbled by hand" % location)
		assert_gt(look.brush_fill, 0.0, "%s: thin repeated lines are filled" % location)


func test_the_brush_shader_declares_what_the_quad_writes() -> void:
	var shader_text := FileAccess.get_file_as_string(BRUSH_PATH)
	var quad_text := FileAccess.get_file_as_string("res://video/ink/brush_quad.gd")
	for name_text in BRUSH_UNIFORMS:
		assert_true(shader_text.contains(" %s" % name_text) and shader_text.contains("uniform"), "the brush shader declares %s" % name_text)
		assert_true(quad_text.contains("&\"%s\"" % name_text), "and the quad writes %s" % name_text)


func test_nothing_the_brush_or_the_delivery_does_reads_the_clock() -> void:
	for path in [BRUSH_PATH, POST_PATH, OUTLINE_PATH, INK_SCREEN_PATH]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("TIME"), "%s never reads the clock: the wobble and the strokes are anchored in the world" % path)


func test_the_brush_quad_carries_the_looks_values_and_sorts_first() -> void:
	var look := _look("street_night").duplicate() as VideoInkLook
	look.brush_r_far = 8.5
	look.brush_post_step = 0.9
	var quad := CineBrushQuad.new()
	add_child_autofree(quad)
	quad.apply_look(look)
	var material := quad.material()
	assert_eq(material.get_shader_parameter(&"r_far"), 8.5, "the radius reaches the shader")
	assert_eq(material.get_shader_parameter(&"post_step"), 0.9, "and the posterize's band")
	assert_eq(material.render_priority, Material.RENDER_PRIORITY_MIN, "it draws in the haze's priority, before the ink's lines")
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(2.0, 3.0, 4.0)
	quad.update(camera, 6.0)
	assert_eq(material.get_shader_parameter(&"focus_m"), 6.0, "the focus distance is written every frame")
	var behind := quad.global_position - camera.global_position
	assert_gt(behind.length(), 1000.0, "the quad sits far down the view axis so it sorts before the haze planes of its priority")
	assert_gt(behind.dot(-camera.global_basis.z), 0.0, "in front of the camera, not behind it")


func test_the_rig_adds_the_brush_only_when_the_look_asks() -> void:
	for on in [true, false]:
		var look := _look("street_night").duplicate() as VideoInkLook
		look.screen_ink = false
		look.brush_on = on
		var level := Node3D.new()
		add_child_autofree(level)
		var camera := Camera3D.new()
		level.add_child(camera)
		camera.make_current()
		look.apply(level)
		var rig := level.get_node(^"CineInkRig") as CineInkRig
		assert_eq(rig.get_node_or_null(^"CineBrushQuad") != null, on, "brush_on = %s: the quad is %s" % [on, "there" if on else "absent"])


func test_the_delivery_rescale_is_a_switch_the_grade_does_not_share() -> void:
	for location in LOCATIONS:
		var look := _look(location).duplicate() as VideoInkLook
		assert_between(look.deliver_scale, 0.5, 0.9, "%s: the picture is filtered down and bicubic-scaled back, not by a trifle and not to mush" % location)
		var on := CinePostEffect.make_compositor(look).compositor_effects[0] as CinePostEffect
		assert_eq(on.deliver_scale, look.deliver_scale, "%s: the finish pass gets the scale" % location)
		look.delivery_on = false
		var off := CinePostEffect.make_compositor(look).compositor_effects[0] as CinePostEffect
		assert_eq(off.deliver_scale, 1.0, "%s: switched off, the picture is not re-scaled" % location)
		assert_eq(off.dark_tint.a, on.dark_tint.a, "%s: and the grade stays" % location)
	var post := FileAccess.get_file_as_string(POST_PATH)
	assert_true(post.contains("deliver") and post.contains("small_image"), "the finish shader has the re-scale's passes")


func test_the_line_has_a_hierarchy() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_gt(look.line_near_mult, 1.2, "%s: a near figure's hull is heavier than a far one's" % location)
		assert_gt(look.ink_near_gain, 1.0, "%s: so is its screen ink" % location)
		assert_lt(look.ink_far_gain, 1.0, "%s: and a far figure's is lighter" % location)
		assert_gt(look.ink_overlap_mult, 1.0, "%s: a near form overlapping a far one draws wider" % location)
		assert_lt(look.ink_inner_px_scale, 1.0, "%s: inner lines are thinner than the silhouette" % location)
		assert_lt(look.ink_inner_weight, 0.6, "%s: and lighter than round 3's" % location)
		assert_lte(look.ink_env_weight, 0.35, "%s: the world's screen lines are sparse (the brush pass draws the rest)" % location)
		assert_gt(look.heavy_mult, look.thin_mult * 10.0, "%s: the shadow side is an order heavier than the lit side" % location)
		assert_gte(look.fp_weight, 1.5, "%s: the first-person arm keeps the heaviest line" % location)
	var outline := FileAccess.get_file_as_string(OUTLINE_PATH)
	for name_text in ["near_mult", "near_start_m", "near_end_m"]:
		assert_true(outline.contains("uniform float %s" % name_text), "the hull declares %s" % name_text)
	var ink := FileAccess.get_file_as_string(INK_SCREEN_PATH)
	for name_text in ["overlap_mult", "inner_px_scale", "near_gain", "far_gain", "dist_near_m", "dist_mid_m", "dist_far_m"]:
		assert_true(ink.contains("uniform float %s" % name_text), "the screen ink declares %s" % name_text)
		assert_true(FileAccess.get_file_as_string("res://video/ink/ink_rig.gd").contains("&\"%s\"" % name_text), "and the rig writes %s" % name_text)


func test_the_hull_material_gets_the_near_weight_but_the_arm_does_not() -> void:
	var look := _look("street_night").duplicate() as VideoInkLook
	var rig := CineInkRig.new()
	rig.look = look
	autofree(rig)
	var figure := ShaderMaterial.new()
	var arm := ShaderMaterial.new()
	arm.set_meta(&"toon_fp", true)
	rig._push_hull_values(figure, 0.0, 1.0, 0.0)
	rig._push_hull_values(arm, 0.0, 1.0, 0.0)
	assert_eq(figure.get_shader_parameter(&"near_mult"), look.line_near_mult, "a figure's hull gets the near multiplier")
	assert_eq(arm.get_shader_parameter(&"near_mult"), 1.0, "the arm is at the lens always: its weight is fp_weight's alone")
