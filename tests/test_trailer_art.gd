extends GutTest
## Milestone 7 (r0): the trailer art of every character that has a data folder, one test for all of them (docs/milestones/M7-calls/recipe.md). A character is
## discovered, not listed: assets/source/trailer_art/<name>/paint.json plus game/actors/art/<name>_art.tres. Adding a character adds its checks, and nothing here
## is edited. The Punk keeps its own file (tests/test_trailer_punk.gd: the veteran, the sheets, the face's design) and the hero hers (test_trailer_player.gd).
const SOURCE := "res://assets/source/trailer_art/"
const ART := "res://game/actors/art/"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]
## The marks map is half the paint map's size (the shapes are broad).
const MARKS_SIZE := 1024

var _names: Array[String] = []


func before_each() -> void:
	Tuning.reset_to_default()
	_names = _characters()


func after_each() -> void:
	Tuning.reset_to_default()


## Every name with a paint.json and a base art that carries a trailer variant.
func _characters() -> Array[String]:
	var out: Array[String] = []
	for dir: String in DirAccess.get_directories_at(SOURCE):
		if FileAccess.file_exists(SOURCE + dir + "/paint.json") and FileAccess.file_exists(ART + dir + "_art.tres"):
			out.append(dir)
	out.sort()
	return out


func _base(name: String) -> CharacterArt:
	return load(ART + name + "_art.tres") as CharacterArt


func _image(tex: Texture2D) -> Image:
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func test_there_are_characters_to_check() -> void:
	assert_true(_names.has("punk"), "the Punk's folder is found: %s" % ", ".join(_names))


func test_every_character_carries_a_painted_trailer_variant() -> void:
	for name: String in _names:
		var base := _base(name)
		var trailer := base.trailer_art()
		assert_not_null(trailer, "%s_art.tres has metadata/trailer (run tools/pipeline/make_trailer_art.sh %s)" % [name, name])
		if trailer == null:
			continue
		assert_true(ToonMaterials.is_painted(trailer), "%s: the variant has a paint map and an ink map" % name)
		assert_eq(trailer.id, StringName(name + "_trailer"))
		assert_eq(base.variant(&"m6"), base)
		assert_eq(base.variant(&"trailer"), trailer)
		assert_true(SkinnedArt.check(trailer).is_empty(), "%s keeps the art contract: %s" % [name, ", ".join(SkinnedArt.check(trailer))])
		assert_eq(trailer.triangle_budget, base.triangle_budget, "%s: the budget of the M6 art" % name)


func test_every_map_is_2048_and_the_data_maps_import_lossless() -> void:
	for name: String in _names:
		var trailer := _base(name).trailer_art()
		if trailer == null:
			continue
		for key: StringName in [ToonMaterials.PAINT_META, ToonMaterials.INK_META]:
			assert_eq((trailer.get_meta(key) as Texture2D).get_width(), MAP_SIZE, "%s %s" % [name, key])
		var maps: Array[Texture2D] = [trailer.get_meta(ToonMaterials.INK_META) as Texture2D]
		if trailer.has_meta(ToonMaterials.MARKS_META):
			maps.append(trailer.get_meta(ToonMaterials.MARKS_META) as Texture2D)
		for tex: Texture2D in maps:
			var conf := ConfigFile.new()
			assert_eq(conf.load(tex.resource_path + ".import"), OK, tex.resource_path)
			assert_eq(int(conf.get_value("params", "compress/mode")), 0, "%s lossless" % tex.resource_path)
			assert_true(bool(conf.get_value("params", "mipmaps/generate")), "%s mipmaps on" % tex.resource_path)
			assert_false(bool(conf.get_value("params", "process/fix_alpha_border")), "%s: no colour bleed" % tex.resource_path)


func test_every_ink_map_follows_the_channel_contract() -> void:
	for name: String in _names:
		var trailer := _base(name).trailer_art()
		if trailer == null:
			continue
		var image := _image(trailer.get_meta(ToonMaterials.INK_META) as Texture2D)
		var classes := {}
		var lines := 0
		var weight_min := 255.0
		for y in range(0, MAP_SIZE, 4):
			for x in range(0, MAP_SIZE, 4):
				var c := image.get_pixel(x, y)
				classes[roundi(c.g * 255.0)] = true
				if c.r > 0.5:
					lines += 1
				weight_min = minf(weight_min, c.a * 255.0)
		for key: int in classes:
			assert_true(CLASS_BYTES.has(key), "%s: G holds only the damage class bytes, found %d" % [name, key])
		assert_gt(lines, 1000, "%s: the drawing has lines" % name)
		assert_gt(weight_min, 0.0, "%s: the hull weight hint is never zero" % name)


func test_every_trailer_mesh_is_the_current_mesh_with_a_fresh_uv2() -> void:
	for name: String in _names:
		var base := _base(name)
		var trailer := base.trailer_art()
		if trailer == null or base.scene == null:
			continue  # the hero's base art names its GLB by path, and her trailer arms are reshaped on purpose (test_trailer_player.gd)
		var a := _first_mesh(base).surface_get_arrays(0)
		var b := _first_mesh(trailer).surface_get_arrays(0)
		var va := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var vb := b[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var box_a := AABB(va[0], Vector3.ZERO)
		for v: Vector3 in va:
			box_a = box_a.expand(v)
		var box_b := AABB(vb[0], Vector3.ZERO)
		for v: Vector3 in vb:
			box_b = box_b.expand(v)
		assert_almost_eq(box_a.size, box_b.size, Vector3.ONE * 0.01, "%s: the same body" % name)
		var uv2 := b[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
		assert_eq(uv2.size(), vb.size(), "%s has a UV2" % name)
		var out := 0
		for uv: Vector2 in uv2:
			if uv.x < -0.0001 or uv.x > 1.0001 or uv.y < -0.0001 or uv.y > 1.0001:
				out += 1
		assert_eq(out, 0, "%s: every UV2 is inside the map" % name)


func _first_mesh(art: CharacterArt) -> ArrayMesh:
	var holder := art.scene.instantiate()
	var found: ArrayMesh = null
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		found = (node as MeshInstance3D).mesh as ArrayMesh
		break
	holder.free()
	return found


func test_every_paint_map_is_flat_fills() -> void:
	for name: String in _names:
		var trailer := _base(name).trailer_art()
		if trailer == null:
			continue
		var pimg := _image(trailer.get_meta(ToonMaterials.PAINT_META) as Texture2D)
		var steps := 0
		var total := 0
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
		assert_lt(float(steps) / float(total), 0.075, "%s: flat fills, no grain, hatch or scribble patches" % name)


## The mark map (paint.json "marks"): 1024, RGBA, three or fewer shapes per channel, and only on skin (the ink map's class 204).
func test_a_mark_map_sits_on_skin_and_is_a_few_shapes() -> void:
	var checked := 0
	for name: String in _names:
		var trailer := _base(name).trailer_art()
		if trailer == null or not trailer.has_meta(ToonMaterials.MARKS_META):
			continue
		checked += 1
		var marks := _image(trailer.get_meta(ToonMaterials.MARKS_META) as Texture2D)
		var ink := _image(trailer.get_meta(ToonMaterials.INK_META) as Texture2D)
		assert_eq(marks.get_width(), MARKS_SIZE, "%s: half the paint map" % name)
		var on := [0, 0, 0]
		var off_skin := 0
		var scale := MAP_SIZE / MARKS_SIZE
		for y in MARKS_SIZE:
			for x in MARKS_SIZE:
				var c := marks.get_pixel(x, y)
				for ch in 3:
					if c[ch] > 0.5:
						on[ch] += 1
						if roundi(ink.get_pixel(x * scale, y * scale).g * 255.0) != 204:
							off_skin += 1
		for ch in 3:
			assert_lt(on[ch], MARKS_SIZE * MARKS_SIZE / 40, "%s: channel %d is a few small shapes (%d texels)" % [name, ch, on[ch]])
		assert_lt(off_skin, 80, "%s: marks only on skin (%d texels off it)" % [name, off_skin])
		assert_gt(on[0] + on[1] + on[2], 300, "%s: the marks are there" % name)
	if checked == 0:
		pending("no character has a mark map yet")


## The placed marks show by level: none when clean, the R shapes from the bruised look, G and B from the bloodied one (toon_painted.gdshader's damage_level).
func test_a_character_with_a_mark_map_shows_its_level_to_the_shader() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	for name: String in _names:
		var base := _base(name)
		var trailer := base.trailer_art()
		if trailer == null or not trailer.has_meta(ToonMaterials.MARKS_META):
			continue
		var rig := HumanoidRig.new()
		rig.build_hurtboxes = false
		rig.art = base
		add_child_autofree(rig)
		rig.build()
		var painted := rig.paint.art_material() as ShaderMaterial
		assert_eq(float(painted.get_shader_parameter(&"marks_on")), 1.0, "%s: the placed marks are on" % name)
		assert_eq(painted.get_shader_parameter(&"marks_tex"), trailer.get_meta(ToonMaterials.MARKS_META))
		for level: int in [DamageLook.Level.CLEAN, DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
			rig.set_damage_look(level)
			assert_eq(int(painted.get_shader_parameter(&"damage_level")), level, "%s: the level reaches the shader" % name)


func test_a_character_without_a_mark_map_keeps_the_tile_scatter() -> void:
	var art := load("res://tests/fixtures/m7/punk_painted_art.tres") as CharacterArt
	if art == null or not ToonMaterials.is_painted(art):
		pending("no painted fixture")
		return
	var material := ToonMaterials.art_for(art)
	assert_null(material.get_shader_parameter(&"marks_tex"), "an art with no marks_tex takes no mark map")
	assert_null(material.get_shader_parameter(&"marks_on"), "and keeps the tiles' scatter (marks_on stays at its default of 0)")
