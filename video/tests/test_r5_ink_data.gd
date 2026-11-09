extends GutTest
## R5-INK's data contracts (headless): the environment's screen lines are off, the actors' wrap and fog and the diffusion glow are on, wide and faint,
## and the finish pass declares the passes. The pixels are windowed: see docs/video/calls/r5-ink.md.

const LOCATIONS: Array[String] = ["street_night", "roofs_dusk", "boss_fire"]
const POST_PATH := "res://video/shaders/post_finish.glsl"


func _look(location: String) -> VideoInkLook:
	return load("res://video/look/%s/ink.tres" % location) as VideoInkLook


func test_the_environment_has_no_screen_lines() -> void:
	for location in LOCATIONS:
		assert_eq(_look(location).ink_env_weight, 0.0, "%s: the plates and the brush carry the environment" % location)


func test_actors_wrap_and_fog_are_on() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_gt(look.wrap_strength, 0.0, "%s: the light wrap is on" % location)
		assert_gt(look.fog_amount, 0.0, "%s: the actor fog is on" % location)
		assert_gt(look.fog_end_m, look.fog_start_m, "%s: the fog ramp has a width" % location)


func test_the_glow_is_wide_and_faint() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_gte(look.glow_narrow, 0.10, "%s: the narrow glow is at least 10%%" % location)
		assert_lte(look.glow_wide, 0.25, "%s: the wide glow is at most 25%%" % location)
		assert_gt(look.glow_wide_radius, look.glow_narrow_radius, "%s: the wide radius is the wider" % location)


func test_the_finish_pass_has_the_glow_and_the_wrap() -> void:
	var text := FileAccess.get_file_as_string(POST_PATH)
	assert_true(text.contains("glow"), "the finish pass has a glow")
	assert_true(text.contains("wrap"), "and a wrap")
