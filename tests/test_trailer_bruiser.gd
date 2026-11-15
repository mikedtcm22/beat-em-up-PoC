extends GutTest
## Milestone 7 (e-bruiser): the trailer Bruiser, built by tools/pipeline/make_trailer_art.sh bruiser from assets/source/trailer_art/bruiser/ (docs/milestones/M7-calls/recipe.md).
## bruiser_art.tres carries it as `metadata/trailer`: its own GLB (the same mesh and rig, a fresh UV2), a 2048 paint map and ink map to the painted material's
## contract (docs/ARCHITECTURE.md "The painted material (M7)"), the M6 palette's colours muted to the night as flat fills; the m6 Bruiser is untouched.
## The generic checks are in test_trailer_art.gd; these pin the Bruiser's own.

const BRUISER_ART := "res://game/actors/art/bruiser_art.tres"
const PAINT := "res://assets/export/characters/bruiser/trailer/bruiser_paint.png"
const INK := "res://assets/export/characters/bruiser/trailer/bruiser_ink.png"
const SHEETS := "res://assets/source/trailer_art/bruiser/"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	_art = load(BRUISER_ART) as CharacterArt


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


func test_the_bruiser_carries_a_painted_trailer_variant() -> void:
	assert_not_null(_trailer(), "bruiser_art.tres has metadata/trailer")
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
	assert_gt(lines, 2000, "the drawing has lines (folds, plates, seams)")
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


func test_a_rig_wears_the_trailer_bruiser_only_under_the_trailer_profile() -> void:
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


func test_damage_marks_still_show_on_the_trailer_bruiser() -> void:
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


func test_a_spawned_bruiser_wears_the_trailer_art_only_under_the_trailer_profile() -> void:
	var bruiser := EncounterSpawner.make_enemy(EnemyCatalog.scene(&"bruiser"), &"bruiser", {})
	add_child_autofree(bruiser)
	await get_tree().physics_frame
	assert_eq(bruiser.rig.worn_art(), _art, "m6 by default")
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(bruiser.rig.worn_art(), _trailer())
	assert_eq((bruiser.rig.paint.art_material() as ShaderMaterial).get_shader_parameter(&"paint_tex"), _trailer().get_meta(ToonMaterials.PAINT_META))


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, path)
	return JSON.parse_string(f.get_as_text()) as Dictionary


func test_the_body_sheets_are_kept_and_the_paint_json_uses_them() -> void:
	# the front and back costume drawings (Gemini over the grey render; sources stay in the repo), projected by paint.json's sheets group
	var spec := _json(SHEETS + "sheets.json")
	var names: Array = []
	for sheet: Dictionary in spec["sheets"]:
		names.append(sheet["name"])
		assert_true(FileAccess.file_exists(SHEETS + String(sheet["src"])), "missing %s" % sheet["src"])
	for want: String in ["body_front", "body_back"]:
		assert_true(names.has(want), "sheet %s" % want)
	var paint_cfg := _json(SHEETS + "paint.json")
	assert_true((paint_cfg["sheets"] as Dictionary)["groups"].has("body"))


func test_the_bruiser_keeps_his_m6_colours_muted_to_the_night() -> void:
	# the flat fills are the palette's purple, grey-slate, near-black and cream, darkened: the dominant paint hues stay purple and blue-grey
	var paint := (_trailer().get_meta(ToonMaterials.PAINT_META) as Texture2D).get_image()
	if paint.is_compressed():
		paint.decompress()
	var purple := 0
	var slate := 0
	var dark := 0
	var total := 0
	for y in range(0, MAP_SIZE, 8):
		for x in range(0, MAP_SIZE, 8):
			var c := paint.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			if mx < 0.12:
				continue
			total += 1
			if mx < 0.2:
				dark += 1
			elif c.b > c.g and c.r > c.g:
				purple += 1
			elif c.b > c.r and c.g > c.r:
				slate += 1
	assert_gt(total, 5000, "painted texels")
	assert_gt(purple, total / 10, "the jacket's purple")
	assert_gt(slate, total / 10, "the armour's grey-slate")
	assert_lt(dark, total / 2, "not a black figure")


## C3 (the clean look): flat fills, a few bold lines and a face drawn once (the drawing's front view on the head's planar island, never blended with the
## three-quarter views, so no ghost eyes): a guard against the grain, hatch patches and line crackle coming back.
func test_the_maps_are_flat_fills_and_a_few_bold_lines() -> void:
	var paint := load("res://assets/export/characters/bruiser/trailer/bruiser_paint.png") as Texture2D
	var ink := load("res://assets/export/characters/bruiser/trailer/bruiser_ink.png") as Texture2D
	var pimg := paint.get_image()
	var iimg := ink.get_image()
	if pimg.is_compressed():
		pimg.decompress()
	if iimg.is_compressed():
		iimg.decompress()
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
