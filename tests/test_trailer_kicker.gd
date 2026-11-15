extends GutTest
## Milestone 7, e-kicker: the trailer Kicker (the M6 Kicker mesh and local colours, muted to the night palette, painted by tools/pipeline/make_trailer_art.sh kicker). kicker_art.tres carries it as
## `metadata/trailer`: its own GLB (the same mesh and rig, a fresh UV2), a 2048 paint map, ink map and mark map to the painted material's contract
## (docs/ARCHITECTURE.md "The painted material (M7)"); the m6 Kicker is untouched. The generic checks live in test_trailer_art.gd.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const KICKER_ART := "res://game/actors/art/kicker_art.tres"
const M6_GLB := "res://assets/export/characters/kicker/kicker.glb"
const PAINT := "res://assets/export/characters/kicker/trailer/kicker_paint.png"
const INK := "res://assets/export/characters/kicker/trailer/kicker_ink.png"
const MARKS := "res://assets/export/characters/kicker/trailer/kicker_marks.png"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	_art = load(KICKER_ART) as CharacterArt


func after_each() -> void:
	Tuning.reset_to_default()


func _trailer() -> CharacterArt:
	return _art.trailer_art()


func _first_mesh(art: CharacterArt) -> ArrayMesh:
	var holder := art.scene.instantiate()
	var found: ArrayMesh = null
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		found = (node as MeshInstance3D).mesh as ArrayMesh
		break
	holder.free()
	return found



func _pixels(path: String) -> Image:
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image


func test_the_kicker_carries_a_painted_trailer_variant_with_marks() -> void:
	assert_not_null(_trailer(), "kicker_art.tres has metadata/trailer")
	assert_true(ToonMaterials.is_painted(_trailer()), "the variant has a paint map and an ink map")
	assert_ne(_trailer().scene.resource_path, _art.scene.resource_path, "its own GLB (a new UV2)")
	assert_eq(_art.variant(&"m6"), _art)
	assert_eq(_art.variant(&"trailer"), _trailer())
	assert_eq((_trailer().get_meta(ToonMaterials.PAINT_META) as Texture2D).resource_path, PAINT)
	assert_eq((_trailer().get_meta(ToonMaterials.INK_META) as Texture2D).resource_path, INK)
	assert_not_null(_trailer().get_meta(ToonMaterials.MARKS_META), "a mark map: placed bruises and blood")
	assert_true(SkinnedArt.check(_trailer()).is_empty(), "it keeps the art contract: %s" % ", ".join(SkinnedArt.check(_trailer())))


func test_the_m6_kicker_is_untouched() -> void:
	assert_eq(_art.scene.resource_path, M6_GLB, "the m6 art still wears the m6 mesh")
	assert_false(_art.has_meta(ToonMaterials.PAINT_META), "no paint map on the m6 art")


func test_a_rig_wears_the_trailer_kicker_only_under_the_trailer_profile() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = _art
	add_child_autofree(rig)
	rig.build()
	assert_eq(rig.worn_art(), _art, "m6 by default: unchanged")
	var m6_mesh := rig.art_meshes()[0].mesh
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(rig.worn_art(), _trailer())
	assert_not_null((rig.paint.art_material() as ShaderMaterial).get_shader_parameter(&"paint_tex"), "the painted material")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(rig.worn_art(), _art)
	assert_eq(rig.art_meshes()[0].mesh, m6_mesh, "flipping back restores the m6 mesh")


func test_damage_marks_show_on_the_trailer_kicker() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = _art
	add_child_autofree(rig)
	rig.build()
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	var painted := rig.paint.art_material() as ShaderMaterial
	assert_gt(float(painted.get_shader_parameter(&"marks")), 0.0, "the marks switch is on")
	assert_not_null(painted.get_shader_parameter(&"damage_tex"), "the damage texture is set")


func test_the_mark_map_holds_a_bruise_a_second_bruise_and_blood() -> void:
	var marks := _pixels(MARKS)
	var seen := [false, false, false]
	for y in range(0, marks.get_height(), 2):
		for x in range(0, marks.get_width(), 2):
			var c := marks.get_pixel(x, y)
			seen[0] = seen[0] or c.r > 0.5
			seen[1] = seen[1] or c.g > 0.5
			seen[2] = seen[2] or c.b > 0.5
	assert_true(seen[0], "R: the bruise of the bruised look")
	assert_true(seen[1], "G: the bruise of the bloodied look")
	assert_true(seen[2], "B: the blood shape of the bloodied look")


func test_the_face_is_drawn_in_bold_lines_on_one_warm_skin_tone() -> void:
	var ink := _pixels(INK)
	var paint := _pixels(PAINT)
	var skin := 0
	var skin_lines := 0
	var warm := 0
	var sat := 0.0
	for y in range(0, MAP_SIZE, 2):
		for x in range(0, MAP_SIZE, 2):
			var c := ink.get_pixel(x, y)
			if roundi(c.g * 255.0) != 204:
				continue
			skin += 1
			if c.r > 0.5:
				skin_lines += 1
			var p := paint.get_pixel(x, y)
			sat += (maxf(p.r, maxf(p.g, p.b)) - minf(p.r, minf(p.g, p.b))) / maxf(maxf(p.r, maxf(p.g, p.b)), 0.001)
			if p.r > p.g and p.g > p.b:
				warm += 1
	assert_gt(skin, 10000, "the skin class has texels")
	assert_gt(float(skin_lines) / float(skin), 0.02, "the face carries bold ink (brows, eyes, the mask's edge)")
	assert_lt(float(skin_lines) / float(skin), 0.3, "and is not a mask of black")
	assert_gt(sat / float(skin), 0.25, "skin is warm, not grey")
	assert_lt(sat / float(skin), 0.55, "and not a saturated pink")
	assert_gt(float(warm) / float(skin), 0.9, "red over green over blue: one warm hue")


func test_the_drawn_eyes_have_painted_whites() -> void:
	# features.svg paints the eye whites into the albedo (data-paint): pale pixels exist on the skin class, which no skin or shade fill is
	var ink := _pixels(INK)
	var paint := _pixels(PAINT)
	var pale := 0
	for y in range(0, MAP_SIZE, 2):
		for x in range(0, MAP_SIZE, 2):
			if roundi(ink.get_pixel(x, y).g * 255.0) == 204:
				var p := paint.get_pixel(x, y)
				if p.r > 0.85 and p.g > 0.82 and p.b > 0.7:
					pale += 1
	assert_gt(pale, 30, "the eye whites are painted (%d pale skin-class samples)" % pale)


## The Kicker's clothes: a green hoodie vest, a green mask, dark shorts over green shins, dark shoes with a light sole; the M6 colours muted, not repainted.
func test_the_paint_keeps_the_m6_local_colours_muted_to_the_night_palette() -> void:
	var cfg := JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/trailer_art/kicker/paint.json")) as Dictionary
	var regions := cfg["regions"] as Dictionary
	for key: String in ["vest", "mask", "shin"]:
		var base := regions[key]["base"] as Array
		assert_true(float(base[1]) > float(base[0]) and float(base[1]) > float(base[2]), "%s stays green" % key)
		assert_lt(float(base[1]), 160.0, "%s is muted (not the M6 lime 199)" % key)
	for key: String in ["shorts", "shoe"]:
		var base := regions[key]["base"] as Array
		assert_gt(float(base[2]), float(base[0]), "%s is dark and cool" % key)
		assert_lt(float(base[1]), 110.0, "%s is dark" % key)
	assert_gt(float((regions["sole"]["base"] as Array)[1]), float((regions["shoe"]["base"] as Array)[1]) + 30.0, "the sole is a lighter band under the shoe, not a bright slab when a kick shows its underside")
	assert_eq((cfg["folds"] as Array).size(), 5, "a few fold lines (shorts, shins, vest), no scribble")


## C3 (the clean look): flat fills and a few bold lines: a guard against the grain, hatch patches and line crackle coming back.
func test_the_maps_are_flat_fills_and_a_few_bold_lines() -> void:
	var pimg := _pixels(PAINT)
	var iimg := _pixels(INK)
	var size := pimg.get_width()
	var steps := 0
	var total := 0
	var lines := 0
	for y in range(0, size - 2, 2):
		for x in range(0, size - 2, 2):
			var c := pimg.get_pixel(x, y)
			var cx := pimg.get_pixel(x + 2, y)
			var cy := pimg.get_pixel(x, y + 2)
			if maxf(maxf(absf(c.r - cx.r), absf(c.g - cx.g)), absf(c.b - cx.b)) > 8.0 / 255.0:
				steps += 1
			if maxf(maxf(absf(c.r - cy.r), absf(c.g - cy.g)), absf(c.b - cy.b)) > 8.0 / 255.0:
				steps += 1
			total += 2
			if x % 4 == 0 and y % 4 == 0 and iimg.get_pixel(x, y).r > 0.5:
				lines += 1
	assert_lt(float(steps) / float(total), 0.075, "flat fills: no grain, hatch or scribble patches")
	assert_lt(lines, 16000, "a few bold lines, not a scribble (%d sampled line texels)" % lines)
