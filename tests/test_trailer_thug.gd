extends GutTest
## Milestone 7 (e-thug): the trailer Thug (the Thug's M6 silhouette and local colours, muted to the night palette, a bold face drawn by Gemini). thug_art.tres carries it as
## `metadata/trailer`: its own GLB (the same mesh and rig, a fresh UV2), a 2048 paint map and ink map to the painted material's contract
## (docs/ARCHITECTURE.md "The painted material (M7)"), the m6 Thug is untouched.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const THUG_ART := "res://game/actors/art/thug_art.tres"
const M6_GLB := "res://assets/export/characters/thug/thug.glb"
const PAINT := "res://assets/export/characters/thug/trailer/thug_paint.png"
const INK := "res://assets/export/characters/thug/trailer/thug_ink.png"
const SHEETS := "res://assets/source/trailer_art/thug/sheets.json"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	_art = load(THUG_ART) as CharacterArt


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


func test_the_thug_carries_a_painted_trailer_variant() -> void:
	assert_not_null(_trailer(), "thug_art.tres has metadata/trailer")
	assert_true(ToonMaterials.is_painted(_trailer()), "the variant has a paint map and an ink map")
	assert_ne(_trailer().scene.resource_path, _art.scene.resource_path, "its own GLB (a new UV2)")
	assert_eq(_art.variant(&"m6"), _art)
	assert_eq(_art.variant(&"trailer"), _trailer())
	assert_true(SkinnedArt.check(_trailer()).is_empty(), "it keeps the art contract: %s" % ", ".join(SkinnedArt.check(_trailer())))


func test_the_maps_are_2048_and_the_ink_map_is_data() -> void:
	var paint := _trailer().get_meta(ToonMaterials.PAINT_META) as Texture2D
	var ink := _trailer().get_meta(ToonMaterials.INK_META) as Texture2D
	assert_eq(paint.resource_path, PAINT)
	assert_eq(ink.resource_path, INK)
	assert_eq(paint.get_width(), MAP_SIZE)
	assert_eq(ink.get_width(), MAP_SIZE)
	var conf := ConfigFile.new()
	assert_eq(conf.load(INK + ".import"), OK)
	assert_eq(int(conf.get_value("params", "compress/mode")), 0, "lossless")
	assert_true(bool(conf.get_value("params", "mipmaps/generate")), "mipmaps on")
	assert_false(bool(conf.get_value("params", "process/fix_alpha_border")), "no colour bleed in the ink map")
	assert_eq(int(conf.get_value("params", "detect_3d/compress_to")), 0)


func test_the_ink_map_follows_the_channel_contract() -> void:
	var image := (_trailer().get_meta(ToonMaterials.INK_META) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var classes := {}
	var lines := 0
	var weight_min := 255.0
	var step := 4
	for y in range(0, MAP_SIZE, step):
		for x in range(0, MAP_SIZE, step):
			var c := image.get_pixel(x, y)
			classes[roundi(c.g * 255.0)] = true
			if c.r > 0.5:
				lines += 1
			if c.a > 0.0:
				weight_min = minf(weight_min, c.a * 255.0)
	for key: int in classes:
		assert_true(CLASS_BYTES.has(key), "G holds only the damage class bytes, found %d" % key)
	assert_true(classes.has(255), "clothes")
	assert_true(classes.has(204), "skin (the face)")
	assert_gt(lines, 2000, "the drawing has lines (folds, seams, the face)")
	assert_gt(weight_min, 0.0, "the hull weight hint is never zero")


func test_the_trailer_mesh_is_the_current_mesh_with_a_fresh_uv2() -> void:
	var m6 := _first_mesh(_art)
	var mesh := _first_mesh(_trailer())
	assert_not_null(mesh)
	var a := m6.surface_get_arrays(0)
	var b := mesh.surface_get_arrays(0)
	assert_eq(m6.surface_get_array_len(0) > 0, true)
	var va := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var vb := b[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var box_a := AABB(va[0], Vector3.ZERO)
	for v: Vector3 in va:
		box_a = box_a.expand(v)
	var box_b := AABB(vb[0], Vector3.ZERO)
	for v: Vector3 in vb:
		box_b = box_b.expand(v)
	assert_almost_eq(box_a.position, box_b.position, Vector3.ONE * 0.002, "the same body")
	assert_almost_eq(box_a.size, box_b.size, Vector3.ONE * 0.002)
	var uv2 := b[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	assert_eq(uv2.size(), vb.size(), "it has a UV2")
	var out := 0
	for uv: Vector2 in uv2:
		if uv.x < -0.0001 or uv.x > 1.0001 or uv.y < -0.0001 or uv.y > 1.0001:
			out += 1
	assert_eq(out, 0, "every UV2 is inside the map")
	# slivers: triangles under half a texel of UV2 area have no texel to paint
	var idx := b[Mesh.ARRAY_INDEX] as PackedInt32Array
	var slivers := 0
	for t in range(0, idx.size(), 3):
		var p0 := uv2[idx[t]] * MAP_SIZE
		var p1 := uv2[idx[t + 1]] * MAP_SIZE
		var p2 := uv2[idx[t + 2]] * MAP_SIZE
		if absf((p1 - p0).cross(p2 - p0)) * 0.5 < 0.5:
			slivers += 1
	assert_lt(float(slivers) / (idx.size() / 3.0), 0.005, "no slivers to speak of (%d)" % slivers)


func test_a_rig_wears_the_trailer_thug_only_under_the_trailer_profile() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = _art
	add_child_autofree(rig)
	rig.build()
	assert_eq(rig.worn_art(), _art, "m6 by default: unchanged")
	var m6_mesh := rig.art_meshes()[0].mesh
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(rig.worn_art(), _trailer())
	var painted := rig.paint.art_material() as ShaderMaterial
	assert_not_null(painted.get_shader_parameter(&"paint_tex"), "the painted material")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(rig.worn_art(), _art)
	assert_eq(rig.art_meshes()[0].mesh, m6_mesh, "flipping back restores the m6 mesh")


func test_damage_marks_still_show_on_the_trailer_thug() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = _art
	add_child_autofree(rig)
	rig.build()
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	var painted := rig.paint.art_material() as ShaderMaterial
	assert_true(ToonMaterials.is_painted(rig.worn_art()))
	assert_gt(float(painted.get_shader_parameter(&"marks")), 0.0, "the marks switch is on")
	assert_not_null(painted.get_shader_parameter(&"damage_tex"), "the damage texture is set")
	assert_ne(rig.damage_look, DamageLook.Level.CLEAN)



func test_the_face_is_drawn_from_kept_gemini_sheets() -> void:
	var f := FileAccess.open(SHEETS, FileAccess.READ)
	assert_not_null(f, SHEETS)
	var spec := JSON.parse_string(f.get_as_text()) as Dictionary
	var names: Array = []
	for sheet: Dictionary in spec["sheets"]:
		names.append(sheet["name"])
		assert_true(FileAccess.file_exists("res://assets/source/trailer_art/thug/" + String(sheet["src"])), "missing %s" % sheet["src"])
	for want: String in ["front", "q45", "qm45"]:
		assert_true(names.has(want), "sheet %s" % want)


func test_the_thug_has_his_own_face_and_one_warm_skin_tone() -> void:
	var ink := (_trailer().get_meta(ToonMaterials.INK_META) as Texture2D).get_image()
	var paint := (_trailer().get_meta(ToonMaterials.PAINT_META) as Texture2D).get_image()
	for image: Image in [ink, paint]:
		if image.is_compressed():
			image.decompress()
	var skin := 0
	var warm := 0
	for y in range(0, MAP_SIZE, 2):
		for x in range(0, MAP_SIZE, 2):
			if roundi(ink.get_pixel(x, y).g * 255.0) != 204:
				continue
			skin += 1
			var p := paint.get_pixel(x, y)
			if p.r > p.g and p.g > p.b:
				warm += 1
	assert_gt(skin, 20000, "the skin class has texels (arms, hands, the strip across the eyes)")
	assert_gt(float(warm) / float(skin), 0.9, "red over green over blue on all the skin: one warm hue")
	# the Thug is not the Punk: his bandana is yellow and his hoodie olive (the Punk has neither)
	var yellow := 0
	var total := 0
	for y in range(0, MAP_SIZE, 4):
		for x in range(0, MAP_SIZE, 4):
			if ink.get_pixel(x, y).a <= 0.0 and roundi(ink.get_pixel(x, y).g * 255.0) == 128:
				continue
			var p := paint.get_pixel(x, y)
			total += 1
			if p.r > 0.6 and p.g > 0.5 and p.b < 0.45 and p.r - p.b > 0.25:
				yellow += 1
	assert_gt(yellow, 400, "the bandana, the wraps and the buckle are yellow (%d of %d)" % [yellow, total])


## The clean look: flat fills and a few bold lines on the Thug too.
func test_the_maps_are_flat_fills_and_a_few_bold_lines() -> void:
	var pimg := (_trailer().get_meta(ToonMaterials.PAINT_META) as Texture2D).get_image()
	var iimg := (_trailer().get_meta(ToonMaterials.INK_META) as Texture2D).get_image()
	if pimg.is_compressed():
		pimg.decompress()
	if iimg.is_compressed():
		iimg.decompress()
	var steps := 0
	var total := 0
	var lines := 0
	for y in range(0, MAP_SIZE - 2, 2):
		for x in range(0, MAP_SIZE - 2, 2):
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
