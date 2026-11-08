extends GutTest
## LD-INK's data and shader contracts (headless): the three locations' ink.tres load and sit where the style
## bible puts them, the cine shaders keep the game's uniform names (they are swapped in place onto its
## materials) and declare the ones LD-ASSET writes, the hatching's tonal art map is cumulative and irregular,
## and the finish pass's files and Compositor exist. The pixels are windowed: tools/video/shoot_still.sh renders them.

const LOCATIONS: Array[String] = ["street_night", "roofs_dusk", "boss_fire"]
const TOON_PATH := "res://game/fx/toon.gdshader"
const TOON_LIGHT_PATH := "res://game/fx/toon_light.gdshaderinc"
const OUTLINE_PATH := "res://game/fx/toon_outline.gdshader"
const CINE_TOON_PATH := "res://video/shaders/cine_toon.gdshader"
const CINE_OUTLINE_PATH := "res://video/shaders/cine_outline.gdshader"
const INK_SCREEN_PATH := "res://video/shaders/ink_screen.gdshader"
const CUE_PATH := "res://video/shaders/cine_cue_screen.gdshader"
## What LD-ASSET writes (docs/video/P1.md LD-INK 1).
const ASSET_UNIFORMS: Array[String] = ["ink_tex", "use_ink_tex", "paint_tex", "use_paint_tex", "ink_color", "ink_strength"]


func _uniform_names(code: String) -> Array[String]:
	var names: Array[String] = []
	var regex := RegEx.new()
	regex.compile("(?m)^\\s*uniform\\s+[A-Za-z0-9_]+\\s+([A-Za-z0-9_]+)")
	for match in regex.search_all(code):
		names.append(match.get_string(1))
	return names


func _look(location: String) -> VideoInkLook:
	return load("res://video/look/%s/ink.tres" % location) as VideoInkLook


func test_every_location_has_an_ink_look() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_not_null(look, "%s/ink.tres loads as VideoInkLook" % location)
		assert_true(look is VideoLookPiece, "%s is a VideoLookPiece" % location)


func test_the_ink_is_warm_and_never_pure_black() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_gt(look.ink_color.get_luminance(), 0.015, "%s: the ink is not pure black" % location)
		assert_gt(look.ink_color.r, look.ink_color.b, "%s: the ink is warm (red over blue)" % location)
		assert_lt(look.ink_color.get_luminance(), 0.15, "%s: the ink is still dark" % location)


func test_the_shadow_hue_is_the_locations() -> void:
	var street := _look("street_night")
	assert_gt(street.shadow_color.b, street.shadow_color.r, "the street's shadow is navy: blue over red")
	var boss := _look("boss_fire")
	assert_gt(boss.shadow_color.r, boss.shadow_color.g, "the boss roof's shadow is violet-maroon: red over green")
	assert_gt(boss.shadow_color.b, boss.shadow_color.g, "and blue over green")
	var roofs := _look("roofs_dusk")
	assert_gt(roofs.shadow_color.r, roofs.shadow_color.g, "the roofs' shadow is dusky violet: red over green")
	for location in LOCATIONS:
		assert_gt(_look(location).rim_color.r, _look(location).rim_color.b, "%s: the rim is warm (the key's tint)" % location)


func test_the_cues_are_switches_in_the_look() -> void:
	var look := _look("street_night")
	for property in ["on_twos", "smears", "hide_comic_fx", "flash_frames", "speed_lines", "sketch_mode", "post_enabled", "screen_ink"]:
		assert_true(property in look, "the look has the switch '%s'" % property)
		assert_eq(typeof(look.get(property)), TYPE_BOOL, "'%s' is a bool" % property)
	assert_eq(look.twos_hold, 2, "on twos holds two output frames (24 fps -> 12 drawings)")
	assert_eq(look.boil_fps, 12.0, "the line boil is 12 fps")


func test_the_cine_toon_keeps_the_games_uniform_names() -> void:
	var game_names := _uniform_names(FileAccess.get_file_as_string(TOON_PATH))
	game_names.append_array(_uniform_names(FileAccess.get_file_as_string(TOON_LIGHT_PATH)))
	var cine := _uniform_names(FileAccess.get_file_as_string(CINE_TOON_PATH))
	assert_gt(game_names.size(), 30, "the game's toon uniforms were read")
	for uniform_name in game_names:
		assert_true(cine.has(uniform_name), "cine_toon keeps the toon uniform '%s'" % uniform_name)
	for uniform_name in ASSET_UNIFORMS:
		assert_true(cine.has(uniform_name), "cine_toon declares LD-ASSET's '%s'" % uniform_name)


func test_the_cine_outline_keeps_the_hulls_uniform_names() -> void:
	var game_names := _uniform_names(FileAccess.get_file_as_string(OUTLINE_PATH))
	var cine := _uniform_names(FileAccess.get_file_as_string(CINE_OUTLINE_PATH))
	for uniform_name in game_names:
		assert_true(cine.has(uniform_name), "cine_outline keeps the hull uniform '%s'" % uniform_name)
	for uniform_name in ["key_dir_view", "heavy_mult", "thin_mult", "far_thin", "wander", "jitter_px", "boil_seed"]:
		assert_true(cine.has(uniform_name), "cine_outline declares '%s'" % uniform_name)


func test_the_shaders_declare_what_the_rig_writes() -> void:
	var rig_source := FileAccess.get_file_as_string("res://video/ink/ink_rig.gd")
	var regex := RegEx.new()
	regex.compile("set_shader_parameter\\(&\"([a-z0-9_]+)\"")
	var toon := _uniform_names(FileAccess.get_file_as_string(CINE_TOON_PATH))
	var outline := _uniform_names(FileAccess.get_file_as_string(CINE_OUTLINE_PATH))
	var screen := _uniform_names(FileAccess.get_file_as_string(INK_SCREEN_PATH))
	var written := 0
	for match in regex.search_all(rig_source):
		var uniform_name := match.get_string(1)
		written += 1
		assert_true(toon.has(uniform_name) or outline.has(uniform_name) or screen.has(uniform_name),
				"some cine shader declares '%s', which the rig writes" % uniform_name)
	assert_gt(written, 30, "the rig's writes were found")


func test_the_shaders_parse() -> void:
	for path in [CINE_TOON_PATH, CINE_OUTLINE_PATH, INK_SCREEN_PATH, CUE_PATH]:
		var shader := load(path) as Shader
		assert_not_null(shader, "%s loads" % path)
		assert_gt(shader.get_shader_uniform_list().size(), 5, "%s has uniforms" % path)


func test_the_hatch_tam_is_cumulative_and_irregular() -> void:
	var image := CineHatchTam.build()
	assert_eq(image.get_size(), Vector2i(CineHatchTam.SIZE, CineHatchTam.SIZE), "the map is the declared size")
	var sums := [0.0, 0.0, 0.0, 0.0]
	var broken := true
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			sums[0] += c.r
			sums[1] += c.g
			sums[2] += c.b
			sums[3] += c.a
			# Cumulative: a denser level contains the lighter one (the 8-bit rounding is one step).
			if c.g + 0.01 < c.r or c.b + 0.01 < c.g or c.a + 0.01 < c.b:
				broken = false
	assert_true(broken, "every level contains the one before it")
	var area := float(image.get_width() * image.get_height())
	assert_gt(sums[0] / area, 0.02, "the lightest level has strokes")
	assert_lt(sums[0] / area, 0.25, "and it is sparse")
	assert_gt(sums[1], sums[0] * 1.02, "level 1 is denser than level 0")
	assert_gt(sums[2], sums[1] * 1.05, "level 2 (the cross strokes) is denser than level 1")
	assert_gt(sums[3], sums[2] * 1.05, "level 3 is the densest")
	assert_lt(sums[3] / area, 0.8, "even the densest level leaves paper")


func test_the_strokes_are_not_a_ruler() -> void:
	# Along each level-0 stroke line (x + y constant) the ink has dashes and gaps, and the lines differ.
	var image := CineHatchTam.build()
	var size := image.get_width()
	var spacing: int = CineHatchTam.SPACING[0]
	var patterns := {}
	for k in size / spacing:
		var center := spacing / 2 + k * spacing
		var runs: Array[int] = []
		var run := 0
		for x in size:
			var y := ((center - x) % size + size) % size
			if image.get_pixel(x, y).r > 0.5:
				run += 1
			elif run > 0:
				runs.append(run)
				run = 0
		patterns[str(runs)] = true
	assert_gt(patterns.size(), 3, "the stroke lines differ in their dashes: no two rules alike")


func test_the_post_files_and_compositor_exist() -> void:
	assert_true(FileAccess.file_exists("res://video/shaders/post_finish.glsl"), "the finish pass's compute shader exists")
	var source := FileAccess.get_file_as_string("res://video/shaders/post_finish.glsl")
	assert_true(source.contains("#[compute]"), "it is a compute shader")
	assert_false(source.contains("TIME"), "no time in the grain: it is static")
	var look := _look("street_night")
	var compositor := CinePostEffect.make_compositor(look)
	assert_not_null(compositor, "a compositor is made from the look")
	assert_eq(compositor.compositor_effects.size(), 1, "with one effect")
	var effect := compositor.compositor_effects[0] as CinePostEffect
	assert_eq(effect.grain, look.post_grain, "carrying the look's grain")
	assert_eq(effect.vignette, look.post_vignette, "and its vignette")
	assert_eq(effect.aberration, look.post_aberration, "and its aberration")
	assert_lt(look.post_aberration, 0.003, "the aberration is little")
	assert_lt(look.post_grain, 0.12, "so is the grain")


func test_the_lut_scripts_exist() -> void:
	assert_true(FileAccess.file_exists("res://tools/video/palette_lut.py"), "palette_lut.py exists")
	assert_true(FileAccess.file_exists("res://tools/video/look_sweep.py"), "look_sweep.py exists")


func test_each_locations_lut_loads_into_a_cube() -> void:
	for location in LOCATIONS:
		var look := _look(location)
		assert_ne(look.lut_path, "", "%s names its palette LUT" % location)
		var texture := CineInkRig.load_lut(look.lut_path)
		assert_not_null(texture, "%s's LUT loads" % location)
		if texture != null:
			assert_eq(texture.get_width(), 32, "%s: a 32 cube" % location)
			assert_eq(texture.get_depth(), 32, "%s: 32 slices" % location)
