extends GutTest
## R4-ART's cast (docs/video/P1.md, round 4), headless: the shade maps exist and carry a shadow hint and form-following hatch strokes, the toon
## shader has no noise terminator and no triplanar crosshatch (round 3's tell 4), the rig sets the shade uniforms, the gloves of Ox differ and the
## first-person arm is a darker foreground form than the subject.

const ART_DIR := "res://assets/video/characters"
const IDS: Array[StringName] = [&"punk", &"boss", &"player"]


func _image(path: String) -> Image:
	return (load(path) as Texture2D).get_image()


func test_every_character_has_a_shade_map_with_a_hint() -> void:
	for id in IDS:
		var path := "%s/%s/%s_shade.png" % [ART_DIR, id, id]
		assert_true(ResourceLoader.exists(path), "%s has a shade map" % id)
		var image := _image(path)
		var hint := 0
		var covered := 0
		for y in range(0, image.get_height(), 8):
			for x in range(0, image.get_width(), 8):
				covered += 1
				if image.get_pixel(x, y).r > 0.3:
					hint += 1
		assert_gt(float(hint) / covered, 0.02, "%s: part of the surface carries the designed shadow hint" % id)
		assert_lt(float(hint) / covered, 0.7, "%s: the hint is a shape, not the whole surface" % id)


func test_the_hatch_strokes_are_baked_for_the_close_up_characters() -> void:
	for id: StringName in [&"boss", &"player"]:
		var image := _image("%s/%s/%s_shade.png" % [ART_DIR, id, id])
		var strokes := 0
		var thresholds := {}
		for y in range(0, image.get_height(), 4):
			for x in range(0, image.get_width(), 4):
				var c := image.get_pixel(x, y)
				if c.g > 0.6:
					strokes += 1
					thresholds[int(c.b * 8.0)] = true
		assert_gt(strokes, 200, "%s has hatch strokes in its shade map" % id)
		assert_gt(thresholds.size(), 3, "%s: the strokes have different depth thresholds (they come in as the shadow deepens)" % id)


func test_the_shader_has_a_clean_terminator_and_no_triplanar_crosshatch() -> void:
	var shader := load(CineArtRig.TOON_SHADER_PATH) as Shader
	assert_false(shader.code.contains("paint_noise"), "no brush noise on the light term")
	assert_false(shader.code.contains("hatch_levels"), "no triplanar tonal-art-map crosshatch")
	assert_false(shader.code.contains("(paint_noise - 0.5)"), "the terminator is not moved by a noise")
	assert_true(shader.code.contains("shade_hint_gain * shade_hint"), "the designed shadow hint pulls the light term")
	var names: Array[String] = []
	for u: Dictionary in shader.get_shader_uniform_list():
		names.append(String(u.name))
	for want in ["shade_tex", "use_shade_tex", "shade_hint_gain", "hatch_gain", "hatch_floor", "hatch_dist", "art_rim_gain"]:
		assert_true(names.has(want), "cine_toon has %s" % want)


func _spawn_punk(look: VideoArtLook) -> HumanoidRig:
	var level := Node3D.new()
	add_child_autofree(level)
	var punk := (load("res://game/enemies/punk/street_punk.tscn") as PackedScene).instantiate() as Node3D
	level.add_child(punk)
	await wait_process_frames(2)
	var rig := punk.get(&"rig") as HumanoidRig
	look.apply(level)
	await wait_process_frames(3)
	return rig


func test_the_rig_sets_the_shade_map_and_its_gains() -> void:
	var look := load("res://video/look/street_night/art.tres") as VideoArtLook
	var rig := await _spawn_punk(look)
	var material := rig.art_meshes()[0].material_override as ShaderMaterial
	assert_true(material.get_shader_parameter(&"use_shade_tex"), "the shade map is on")
	assert_not_null(material.get_shader_parameter(&"shade_tex"), "the shade map is set")
	assert_almost_eq(float(material.get_shader_parameter(&"shade_hint_gain")), look.hint_gain_of(&"punk"), 0.0001, "the hint's gain is the look's")
	assert_almost_eq(float(material.get_shader_parameter(&"hatch_gain")), look.hatch_gain, 0.0001, "the hatching's gain is the look's")


func test_the_switch_turns_the_shade_map_off() -> void:
	var look := (load("res://video/look/street_night/art.tres") as VideoArtLook).duplicate() as VideoArtLook
	look.shade_map = false
	var rig := await _spawn_punk(look)
	var material := rig.art_meshes()[0].material_override as ShaderMaterial
	assert_false(material.get_shader_parameter(&"use_shade_tex"), "shade_map = false leaves the shade map off")


func test_the_arm_is_a_foreground_form_darker_than_the_subject() -> void:
	for location in ["street_night", "roofs_dusk", "boss_fire"]:
		var look := load("res://video/look/%s/art.tres" % location) as VideoArtLook
		assert_lt(float(look.value_by_id.get("player", 1.0)), 0.9, "%s: the first-person arm's albedo is darkened" % location)
		assert_gt(float(look.hatch_floor_by_id.get("player", 0.0)), 0.5, "%s: the arm's hatching does not wait for a nearby figure" % location)


func test_ox_gloves_are_not_mirrored_copies() -> void:
	var paint := _image("%s/boss/boss_paint.png" % ART_DIR)
	var ink := _image("%s/boss/boss_ink.png" % ART_DIR)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/video_art/boss/paint.json"))
	var kinds := {}
	for mark: Dictionary in meta.get("marks", []):
		kinds["%s:%s" % [mark.bone, mark.type]] = true
	assert_true(kinds.has("RightHand:tape") and kinds.has("LeftHand:patch"), "the two gloves carry different marks (a tape wrap, a patch)")
	assert_eq(paint.get_width(), ink.get_width(), "the maps of the paint and the ink are the same layout")
