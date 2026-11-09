extends GutTest
## LD-INK2's data and shader contracts (headless): the line hierarchy's values sit where the brief puts them (heavier hull, a heavier first-person
## line, the environment's ink lighter, a separation band), each location's grade has its hue (navy, maroon-violet, violet) and the roofs' ink
## piece makes the Kicker a silhouette, the delivery pass is a switch, the shaders declare what the rig writes, the delivery's grain is seeded
## from the output frame, the pickup glint is hidden, and the rear warning's burst is read from the HUD's state. The pixels are windowed.

const LOCATIONS: Array[String] = ["street_night", "roofs_dusk", "boss_fire"]
const OUTLINE_PATH := "res://video/shaders/cine_outline.gdshader"
const INK_SCREEN_PATH := "res://video/shaders/ink_screen.gdshader"
const CUE_PATH := "res://video/shaders/cine_cue_screen.gdshader"
const POST_PATH := "res://video/shaders/post_finish.glsl"
## The Gate 2 (round 1) hull width at 1080p, which the round 3 line must beat.
const OLD_HULL_PX := 3.2


class FrameSource extends RefCounted:
	var frame: int = 0


	func get_frame() -> int:
		return frame


## A stand-in for the HUD's RearWarning: `size` and `corner_state()` as the cue pass reads them.
class FakeWarning extends RefCounted:
	var size: Vector2 = Vector2(480.0, 270.0)
	var states: Dictionary = {}


	func corner_state(side: StringName) -> Dictionary:
		return states.get(side, {active = false})


func _look(location: String) -> VideoInkLook:
	return load("res://video/look/%s/ink.tres" % location) as VideoInkLook


func test_the_line_is_heavier_and_the_first_person_arm_the_heaviest() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_gt(look.hull_px, OLD_HULL_PX, "%s: the hull is wider than round 1's" % location)
		assert_gt(look.heavy_mult, look.thin_mult * 4.0, "%s: heavy against thin is a real range" % location)
		assert_gte(look.fp_weight, look.char_weight, "%s: the first-person arm's line is at least as heavy as any figure's" % location)
		assert_gt(look.fp_weight, 1.2, "%s: the arm's line is heavier than the default" % location)
		assert_gt(look.taper_amount, 0.0, "%s: the line tapers" % location)
		assert_gt(look.break_amount, 0.0, "%s: the line lifts on the lit side" % location)


func test_the_environment_is_inked_lighter_than_the_figures() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_lt(look.ink_env_weight, 1.0, "%s: the world draws its own lines, so the screen ink's are lighter on it" % location)
		assert_lt(look.ink_inner_weight, 1.0, "%s: a character's inner lines are lighter than its silhouette" % location)
		assert_gt(look.term_line, 0.0, "%s: the terminator line is on" % location)
	assert_gt(_look("street_night").sep_alpha, 0.0, "the street separates a figure from the ground behind it")
	assert_gt(_look("boss_fire").sep_alpha, 0.0, "and so does the boss roof")
	assert_eq(_look("roofs_dusk").sep_alpha, 0.0, "the roof's silhouette needs no band: it stands against the sun")


func test_each_locations_grade_has_its_hue() -> void:
	var street := _look("street_night")
	assert_gt(street.grade_dark_tint.b, street.grade_dark_tint.r * 2.0, "night darks are navy and indigo: blue far over red")
	assert_gt(street.grade_dark_amount, 0.0, "and the grade is on")
	var boss := _look("boss_fire")
	assert_gt(boss.grade_dark_tint.r, boss.grade_dark_tint.g * 2.0, "the boss roof's darks are maroon-violet: red over green")
	assert_gt(boss.grade_dark_tint.b, boss.grade_dark_tint.g, "with blue over green")
	var roofs := _look("roofs_dusk")
	assert_gt(roofs.grade_dark_tint.b, roofs.grade_dark_tint.g, "the roofs' darks are violet: blue over green")
	assert_gt(roofs.grade_dark_tint.r, roofs.grade_dark_tint.g, "and red over green")
	assert_gt(roofs.grade_high_tint.r, roofs.grade_high_tint.b, "the roofs' highlights are gold")
	assert_gt(boss.grade_high_tint.r, boss.grade_high_tint.b, "and the boss roof's are amber")


func test_the_roofs_ink_makes_the_kicker_a_silhouette() -> void:
	var roofs := _look("roofs_dusk")
	assert_lte(roofs.shadow_level, 0.1, "the shadow band is near black")
	assert_eq(roofs.fill, 0.0, "no camera-fixed fill")
	assert_lte(roofs.dir_floor, 0.1, "the sun lights the figure at no more than a tenth: a backlit shape")
	assert_false(roofs.rim_lights, "no rim lights follow him")
	assert_lt(roofs.rim_strength, _look("boss_fire").rim_strength, "and the rim is lower than the boss roof's")


func test_the_roofs_art_look_lowers_the_faces_fill() -> void:
	var art := load("res://video/look/roofs_dusk/art.tres") as VideoArtLook
	assert_not_null(art, "the roofs' art piece loads")
	assert_lt(art.face_fill, 0.2, "the face is not lit from inside against the sun")
	assert_lt(art.catch_strength, 0.5, "and the catchlights are low")


func test_the_delivery_pass_is_a_switch() -> void:
	var look := _look("street_night").duplicate() as VideoInkLook
	assert_true(look.delivery_on, "the delivery is on by default")
	var on := CinePostEffect.make_compositor(look).compositor_effects[0] as CinePostEffect
	assert_gt(on.soften, 0.0, "on: the frame is softened a little")
	assert_lt(on.soften, 0.7, "but not to mush: a one-pixel line keeps most of its weight")
	assert_gt(on.fine_grain, 0.0, "and grained")
	look.delivery_on = false
	var off := CinePostEffect.make_compositor(look).compositor_effects[0] as CinePostEffect
	assert_eq(off.soften, 0.0, "off: no soften")
	assert_eq(off.fine_grain, 0.0, "no fine grain")
	assert_eq(off.dark_tint.a, on.dark_tint.a, "the grade stays: the switch is the delivery's alone")
	assert_eq(off.grain, on.grain, "and the paper grain")


func test_the_shaders_declare_what_the_rig_writes() -> void:
	var rig_text := FileAccess.get_file_as_string("res://video/ink/ink_rig.gd")
	var outline := FileAccess.get_file_as_string(OUTLINE_PATH)
	for name_text in ["taper_amount", "taper_scale", "break_amount", "weight_mult"]:
		assert_true(outline.contains("uniform float %s" % name_text), "the hull declares %s" % name_text)
		assert_true(rig_text.contains("&\"%s\"" % name_text), "and the rig writes it")
	var ink := FileAccess.get_file_as_string(INK_SCREEN_PATH)
	for name_text in ["env_weight", "inner_weight", "sep_alpha", "sep_px", "sep_min_m", "term_line", "term_px", "term_lod", "debug_view"]:
		assert_true(ink.contains(" %s" % name_text) and ink.contains("uniform"), "the screen ink declares %s" % name_text)
		assert_true(rig_text.contains("&\"%s\"" % name_text), "and the rig writes %s" % name_text)
	var cue := FileAccess.get_file_as_string(CUE_PATH)
	for name_text in ["warn_left", "warn_right"]:
		assert_true(cue.contains("uniform vec4 %s" % name_text), "the cue shader declares %s" % name_text)
	var post := FileAccess.get_file_as_string(POST_PATH)
	for name_text in ["soften", "fine_grain", "fine_seed", "dark_tint", "dark_grade", "high_tint"]:
		assert_true(post.contains(name_text), "the finish pass has %s" % name_text)


func test_the_delivery_grain_is_seeded_from_the_output_frame() -> void:
	var look := _look("street_night").duplicate() as VideoInkLook
	look.screen_ink = false
	var level := Node3D.new()
	add_child_autofree(level)
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.make_current()
	look.apply(level)
	var rig := level.get_node(^"CineInkRig") as CineInkRig
	var source := FrameSource.new()
	rig.frame_source = source.get_frame
	assert_not_null(rig.compositor, "the rig has a compositor")
	var effect := rig.compositor.compositor_effects[0] as CinePostEffect
	var seeds: Dictionary[int, float] = {}
	for frame in [4, 5, 6, 7]:
		source.frame = frame
		await wait_process_frames(2)
		seeds[frame] = effect.fine_seed
	assert_eq(seeds[4], seeds[5], "frames 4 and 5 share a grain (a hold of two)")
	assert_ne(seeds[5], seeds[6], "frame 6 has a new one")
	assert_eq(seeds[6], seeds[7], "frames 6 and 7 share it")


func test_the_pickup_glint_is_hidden_but_the_weapon_is_not() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var glint := WeaponGlint.new()
	level.add_child(glint)
	await wait_process_frames(1)
	var sparkle := glint.get_node_or_null(^"Sparkle") as MeshInstance3D
	assert_not_null(sparkle, "the glint has its sparkle quad")
	assert_true(sparkle.visible, "which the game shows")
	CineDirector._hide_glints(level)
	assert_false(sparkle.visible, "the cine stage hides it: a four-point star against a sun reads as a lens flare")
	var late := MeshInstance3D.new()
	glint.add_child(late)
	var director := CineDirector.new()
	add_child_autofree(director)
	director._on_node_added(late)
	assert_false(late.visible, "and one that appears mid-shot")


func test_the_rear_warning_is_read_from_the_huds_state() -> void:
	var look := _look("street_night").duplicate() as VideoInkLook
	var cues := CineCues.new()
	cues.look = look
	var source := FakeWarning.new()
	cues.warning_source = source
	assert_eq(cues._warning(&"left"), Vector4.ZERO, "a dark corner draws nothing")
	source.states[&"left"] = {active = true, alpha = 0.8, rect = Rect2(Vector2(20.0, 10.0), Vector2(40.0, 40.0))}
	var burst: Vector4 = cues._warning(&"left")
	assert_almost_eq(burst.x, 40.0 / 480.0, 0.001, "the burst's centre is the HUD rectangle's, in screen uv (x)")
	assert_almost_eq(burst.y, 30.0 / 270.0, 0.001, "and y")
	assert_gt(burst.z, 0.0, "it has a size")
	assert_almost_eq(burst.w, 0.8, 0.001, "and the state's alpha (the pulse's beat)")
	assert_eq(cues._warning(&"right"), Vector4.ZERO, "the other corner is dark")
	look.rear_warning = false
	assert_eq(cues._warning(&"left"), Vector4.ZERO, "switched off, nothing")
	cues.free()
