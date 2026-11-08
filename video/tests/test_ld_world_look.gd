extends GutTest
## LD-WORLD's checks: the three locations' world looks load and say what the brief says (one motivated key, an accent of the opposite
## temperature, one shadow caster, the practicals placed from data), every value a look sets names a uniform of the shader it is sent
## to, the paint shaders keep the trim's uniform names, the mattes are small, the sprites are made by code and repeat, and applying a
## look to a real level leaves the rig, the sun, the sky and the materials as designed (and applying another replaces it). The pixels
## are windowed: tools/video/shoot_still.sh "World:" renders them.

const LOOKS: Dictionary = {&"street_night": 0, &"roofs_dusk": 1, &"boss_fire": 2}
const LOOK_PATH := "res://video/look/%s/world.tres"
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const PAINT_SHADERS: Array[String] = [
	"res://video/shaders/flat_paint_env.gdshader",
	"res://video/shaders/flat_paint_env_scissor.gdshader",
	"res://video/shaders/flat_paint_prop.gdshader",
]
const BODY_PATH := "res://video/shaders/flat_paint_env_body.gdshaderinc"
const SKY_PATH := "res://video/shaders/sky_painted.gdshader"
const HAZE_PATH := "res://video/shaders/haze_band.gdshader"
const TRIM_BODY_PATH := "res://game/fx/trim_body.gdshaderinc"
const TRIM_PATH := "res://game/fx/trim.gdshader"
const MATTE_DIR := "res://assets/video/mattes"


func after_each() -> void:
	VideoWorldLook.restore_game_materials()
	Tuning.reset_to_default()


func _look(location: StringName) -> VideoWorldLook:
	return load(LOOK_PATH % location) as VideoWorldLook


func _uniform_names(code: String) -> Array[String]:
	var names: Array[String] = []
	var regex := RegEx.new()
	regex.compile("(?m)^\\s*uniform\\s+[a-z0-9_]+\\s+([A-Za-z0-9_]+)")
	for match in regex.search_all(code):
		names.append(match.get_string(1))
	return names


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


func test_each_location_has_a_world_look() -> void:
	for location: StringName in LOOKS:
		var look := _look(location)
		assert_not_null(look, "%s: world.tres loads as a VideoWorldLook" % location)
		assert_eq(look.location, location, "%s: names its location" % location)
		assert_eq(look.section, LOOKS[location], "%s: is for its section" % location)
		assert_false(look.sky.is_empty(), "%s: has a sky" % location)
		assert_false(look.haze.is_empty(), "%s: has flat haze bands" % location)
		assert_false(look.paint.is_empty(), "%s: has paint values" % location)


func test_every_shader_value_names_a_uniform() -> void:
	var paint_names := _uniform_names(FileAccess.get_file_as_string(BODY_PATH))
	var sky_names := _uniform_names(FileAccess.get_file_as_string(SKY_PATH))
	var haze_names := _uniform_names(FileAccess.get_file_as_string(HAZE_PATH))
	for location: StringName in LOOKS:
		var look := _look(location)
		for key: Variant in look.paint:
			assert_true(paint_names.has(String(key)), "%s: paint '%s' is a uniform of the flat paint" % [location, key])
		for key: Variant in look.sky:
			assert_true(sky_names.has(String(key)), "%s: sky '%s' is a uniform of the sky shader" % [location, key])
		for key: Variant in look.haze:
			assert_true(haze_names.has(String(key)), "%s: haze '%s' is a uniform of the haze shader" % [location, key])


func test_the_paint_shaders_keep_the_trim_uniform_names() -> void:
	var trim_names := _uniform_names(FileAccess.get_file_as_string(TRIM_BODY_PATH))
	trim_names.append_array(_uniform_names(FileAccess.get_file_as_string(TRIM_PATH)))
	var body := FileAccess.get_file_as_string(BODY_PATH)
	for path in PAINT_SHADERS:
		var names := _uniform_names(FileAccess.get_file_as_string(path) + body)
		for uniform_name in trim_names:
			assert_true(names.has(uniform_name), "%s keeps the trim uniform '%s'" % [path.get_file(), uniform_name])
		assert_not_null(load(path) as Shader, "%s loads" % path.get_file())
	# The chain-link's variant is the one that writes the alpha scissor; the opaque one must not (it would lose the depth prepass).
	assert_false(FileAccess.get_file_as_string(PAINT_SHADERS[0]).contains("ALPHA_SCISSOR"), "the opaque paint shader has no scissor")
	assert_true(body.contains("#ifdef FLAT_PAINT_SCISSOR"), "the scissor lives under its own define")


func test_one_shadow_caster_and_a_key_and_an_accent() -> void:
	for location: StringName in LOOKS:
		var look := _look(location)
		var casters := 0
		for spec in look.lights:
			if spec.shadow:
				casters += 1
		if look.sun_shadow and casters == 0:
			casters = 1
		assert_eq(casters, 1, "%s: one shadow caster a shot" % location)
		for spec in look.lights:
			assert_lte(spec.energy, 1.0, "%s: a light stays under the toon light's cap of 1 a channel" % location)
	var street := _look(&"street_night")
	var lamp: VideoWorldLight = street.lights[0]
	assert_between(lamp.color.h * 360.0, 15.0, 45.0, "the street's key is sodium orange")
	assert_gt(street.sun_color.b, street.sun_color.r, "the street's accent, the moon, is cool")
	assert_gt(street.lights.filter(func(l: VideoWorldLight) -> bool: return l.prop == VideoWorldLight.Prop.LAMP_POST).size(), 2, "lamp posts along the street")
	assert_gt(street.lights.filter(func(l: VideoWorldLight) -> bool: return l.prop == VideoWorldLight.Prop.FIRE_BARREL).size(), 0, "a fire barrel")
	var roofs := _look(&"roofs_dusk")
	assert_gt(roofs.sun_color.r, roofs.sun_color.b, "the roofs' key, the low sun, is warm")
	assert_lt(roofs.sun_elevation_deg, 25.0, "the sun is low (long shadows)")
	var boss := _look(&"boss_fire")
	var fire: VideoWorldLight = boss.lights[0]
	assert_eq(fire.prop, VideoWorldLight.Prop.BARE, "the boss roof's fire is a bare light")
	assert_lt(fire.position.y, 2.0, "the fire is low, so it lights from below")
	assert_gt(fire.color.r, fire.color.b, "the fire is warm")


func test_the_matte_pictures_are_small_and_painted() -> void:
	var seen := 0
	for location: StringName in LOOKS:
		for card in _look(location).mattes:
			assert_not_null(card.texture, "%s: a matte has its picture" % location)
			if card.texture == null:
				continue
			seen += 1
			assert_lte(card.texture.get_width(), 2048, "%s: a matte is 2048 px or under" % card.texture.resource_path)
			assert_lte(card.texture.get_height(), 2048, "%s: a matte is 2048 px or under" % card.texture.resource_path)
	assert_gt(seen, 2, "the looks hang mattes")
	assert_true(FileAccess.file_exists("res://tools/video/paint_mattes.py"), "the mattes' painter is in the repo")
	for file in DirAccess.get_files_at(MATTE_DIR):
		if file.ends_with(".png"):
			assert_true(file.begins_with("matte_"), "%s is named for what it is" % file)


func test_the_sprites_are_made_by_code_and_repeat() -> void:
	var a := VideoWorldSprites.puff(3).get_image().get_data()
	var b := VideoWorldSprites.puff(3).get_image().get_data()
	assert_eq(a, b, "a puff repeats byte for byte")
	assert_ne(a, VideoWorldSprites.puff(4).get_image().get_data(), "another seed is another puff")
	assert_eq(VideoWorldSprites.ember().get_width(), VideoWorldSprites.EMBER_PX)
	assert_eq(VideoWorldSprites.mote().get_width(), VideoWorldSprites.MOTE_PX)
	var puff := VideoWorldSprites.puff().get_image()
	var values := {}
	for y in range(0, puff.get_height(), 3):
		for x in range(0, puff.get_width(), 3):
			var c := puff.get_pixel(x, y)
			if c.a > 0.5:
				values[snappedf(c.r, 0.05)] = true
	assert_lte(values.size(), 3, "a puff is two or three flat values, not a gradient")


func test_applying_a_look_lays_the_rig() -> void:
	var level := await _build_level()
	var look := _look(&"street_night")
	look.apply(level)
	var rig := level.get_node_or_null(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig
	assert_not_null(rig, "the rig is under the level")
	assert_false(Tuning.data.section_light_enabled, "the level's own section light is off")
	var sun := level.get_node("Sun") as DirectionalLight3D
	assert_eq(sun.light_color, look.sun_color, "the sun is the look's moon")
	assert_false(sun.shadow_enabled, "the sun does not cast: the key lamp does")
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_false(env.fog_enabled, "the exact depth fog is off (the haze bands replace it)")
	assert_false(env.glow_enabled, "Godot's glow is off (banded halo cards replace it)")
	assert_true(env.sky.sky_material is ShaderMaterial, "the sky is the painted sky shader")
	assert_eq((env.sky.sky_material as ShaderMaterial).shader.resource_path, SKY_PATH, "it is sky_painted.gdshader")
	assert_eq(ToonMaterials.trim().shader.resource_path, PAINT_SHADERS[0], "the trim material wears the flat paint")
	assert_eq(ToonMaterials.trim_scissor().shader.resource_path, PAINT_SHADERS[1], "the chain-link wears the scissor variant")
	assert_eq(rig.practicals.size(), look.lights.size(), "every practical is built")
	var shadowed := 0
	for node in level.find_children("*", "Light3D", true, false):
		if (node as Light3D).shadow_enabled:
			shadowed += 1
	assert_eq(shadowed, 1, "one light casts a shadow in the whole level")
	assert_not_null(rig.haze_material, "the haze quad is there")
	var hook: Dictionary = level.get_meta(&"video_world_hook")
	assert_eq(hook[&"color"], look.hook_color, "the key's colour is published for the rim")
	assert_eq((hook[&"heads"] as PackedVector3Array).size(), look.lights.size(), "and the lights' heads")
	assert_gt(level.find_children("*", "GPUParticles3D", true, false).size(), 0, "embers and steam are in")


func test_applying_another_look_replaces_the_first() -> void:
	var level := await _build_level()
	_look(&"street_night").apply(level)
	var roofs := _look(&"roofs_dusk")
	roofs.apply(level)
	var rigs := level.get_children().filter(func(n: Node) -> bool: return n is VideoWorldRig)
	await _ticks(2)
	var live := rigs.filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_eq(live.size(), 1, "one rig is left")
	assert_eq((live[0] as VideoWorldRig).look, roofs, "it is the second look's")
	var sun := level.get_node("Sun") as DirectionalLight3D
	assert_true(sun.shadow_enabled, "the roofs' sun casts: it is the shadow caster there")
	assert_gt(sun.light_color.r, sun.light_color.b, "and it is warm")
	# The street's paint left nothing behind: a uniform the roofs do not set is back at the shader's own value.
	var street_only := _look(&"street_night").paint.keys().filter(func(k: Variant) -> bool: return not roofs.paint.has(k))
	assert_false(street_only.is_empty(), "the street sets something the roofs do not (the premise)")
	for key: Variant in street_only:
		assert_null(ToonMaterials.trim().get_shader_parameter(StringName(key)), "%s is reset" % key)


func test_the_flicker_comes_from_the_frame_number_not_the_clock() -> void:
	var level := await _build_level()
	var look := _look(&"street_night")
	look.apply(level)
	var rig := level.get_node(NodePath(String(VideoWorldLook.ROOT_NAME))) as VideoWorldRig
	var flickering: Array[Node3D] = []
	for node in rig.practicals:
		if node.has_meta(&"flicker"):
			flickering.append(node)
	assert_false(flickering.is_empty(), "a fire barrel flickers")
	var light := flickering[0].get_meta(&"light") as Light3D
	rig._flicker()
	var first := light.light_energy
	rig._flicker()
	assert_eq(light.light_energy, first, "the same frame gives the same flame")
	assert_ne(first, flickering[0].get_meta(&"base_energy"), "and the flame is not at rest")
