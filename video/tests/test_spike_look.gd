extends GutTest
## The Phase 0 spike's headless checks (P0-SPIKE): its numbers load and sit where the brief puts them, the
## flat-paint shader keeps every uniform name of the game's trim shader (it is swapped onto that material), the
## ink shader compiles with the uniforms the look script feeds it, and a LUT strip loads into a cube. The pixels
## are windowed: video/spike/make_strip.sh renders them.

const DATA_PATH := "res://video/spike/spike_look.tres"
const PAINT_PATH := "res://video/shaders/flat_paint_env.gdshader"
const INK_PATH := "res://video/shaders/ink_screen.gdshader"
const TRIM_INC_PATH := "res://game/fx/trim_body.gdshaderinc"
const TRIM_PATH := "res://game/fx/trim.gdshader"
## The ink uniforms spike_look.gd writes.
const INK_UNIFORMS: Array[String] = ["ink", "alpha_max", "debug_view", "width_thin_px", "width_heavy_px", "lit_lost",
		"lit_full", "lit_floor", "depth_threshold", "normal_threshold", "env_major_m", "fade_start_m", "fade_end_m",
		"key_view", "rim_view", "moon_dir_view"]
## The paint uniforms spike_look.gd writes.
const PAINT_UNIFORMS: Array[String] = ["paint_lod", "paint_bands", "paint_band_soft", "paint_shadow_tint",
		"paint_shadow_level", "paint_mid_level", "paint_ink_keep", "paint_grain", "paint_grain_scale", "paint_break",
		"paint_break_scale", "paint_sat", "paint_value_gain"]


func _uniform_names(code: String) -> Array[String]:
	var names: Array[String] = []
	var regex := RegEx.new()
	regex.compile("(?m)^\\s*uniform\\s+[a-z0-9_]+\\s+([A-Za-z0-9_]+)")
	for match in regex.search_all(code):
		names.append(match.get_string(1))
	return names


func test_data_loads_and_matches_the_brief() -> void:
	var data := load(DATA_PATH) as CineSpikeLookData
	assert_not_null(data, "spike_look.tres loads as CineSpikeLookData")
	assert_eq(data.capture_size, Vector2i(2560, 1440), "the still is 2560x1440")
	# The sodium lamp: hue near #ff9a3c (about 28 degrees), saturated.
	assert_between(data.lamp_color.h * 360.0, 15.0, 45.0, "the lamp is sodium orange")
	assert_gt(data.lamp_color.s, 0.6, "the lamp colour is saturated")
	# The moon is the cool fill: bluer than red, and darker than the lamp (a night, not a dusk).
	assert_gt(data.moon_color.b, data.moon_color.r, "the moon is cool")
	assert_lt(data.moon_energy, data.lamp_energy, "the moon is the fill, the lamp the key")
	# The toon light() caps a light at 1 per channel: a lamp above it loses its hue.
	assert_lte(data.lamp_energy, 1.0, "the lamp stays under the toon light cap")
	assert_lt(data.hull_px, 3.75, "the hull is thinner than the game's")
	var guard := data.punk_rel.length()
	assert_between(guard, 1.8, 2.3, "the Punk stands at about 2 m")


func test_paint_shader_keeps_the_trim_uniform_names() -> void:
	var trim_names := _uniform_names(FileAccess.get_file_as_string(TRIM_INC_PATH))
	trim_names.append_array(_uniform_names(FileAccess.get_file_as_string(TRIM_PATH)))
	var paint_names := _uniform_names(FileAccess.get_file_as_string(PAINT_PATH))
	assert_gt(trim_names.size(), 10, "the trim uniforms were read")
	for uniform_name in trim_names:
		assert_true(paint_names.has(uniform_name), "flat_paint_env keeps the trim uniform '%s'" % uniform_name)
	for uniform_name in PAINT_UNIFORMS:
		assert_true(paint_names.has(uniform_name), "flat_paint_env declares '%s'" % uniform_name)


func test_ink_shader_declares_what_the_look_feeds_it() -> void:
	var ink_names := _uniform_names(FileAccess.get_file_as_string(INK_PATH))
	for uniform_name in INK_UNIFORMS:
		assert_true(ink_names.has(uniform_name), "ink_screen declares '%s'" % uniform_name)
	var shader := load(INK_PATH) as Shader
	assert_not_null(shader, "the ink shader loads")
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)
	var uniforms := shader.get_shader_uniform_list()
	var found := 0
	for entry in uniforms:
		if INK_UNIFORMS.has(String(entry.name)):
			found += 1
	assert_eq(found, INK_UNIFORMS.size(), "the compiled ink shader lists every uniform")


func test_paint_shader_compiles_with_trim_params() -> void:
	var shader := load(PAINT_PATH) as Shader
	assert_not_null(shader)
	var listed := PackedStringArray()
	for entry in shader.get_shader_uniform_list():
		listed.append(String(entry.name))
	assert_true(listed.has("trim_tex") and listed.has("strips") and listed.has("ground_tex"), "the sheet and the ground are there")


func test_lut_strip_loads_into_a_cube() -> void:
	var n := 32
	var strip := Image.create(n * n, n, false, Image.FORMAT_RGB8)
	for b in n:
		for y in n:
			for x in n:
				strip.set_pixel(b * n + x, y, Color(float(x) / (n - 1), float(y) / (n - 1), float(b) / (n - 1)))
	var path := "user://spike_test_strip.png"
	assert_eq(strip.save_png(path), OK)
	var texture := CineSpikeLook.load_lut(ProjectSettings.globalize_path(path))
	assert_not_null(texture, "a strip of N slices of N x N loads")
	if texture != null:
		assert_eq(texture.get_width(), n)
		assert_eq(texture.get_depth(), n)
	assert_null(CineSpikeLook.load_lut("user://does_not_exist.png"), "a missing strip is null, not an error")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
