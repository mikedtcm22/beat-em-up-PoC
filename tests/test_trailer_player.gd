extends GutTest
## Milestone 7, T14: the hero's first-person arms and gloves in the trailer look. player_art.tres carries a trailer variant (`metadata/trailer`):
## the hero's own mesh and rig (the same four parts, the same triangles) with a fresh UV2 that has no slivers (the m6 layout's collapsed arm
## triangles were the black holes), the arms relaxed and given smoothed shading normals, and a 2048 paint map and ink map to the painted material's
## contract (grey sleeves with folds, dark leather gloves with knuckle creases, stitching and a wrist strap). FirstPersonCamera drops the meshes it
## cached when the art swaps (F7); the m6 hero is untouched.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const HERO_ART := "res://game/actors/art/player_art.tres"
const PLAYER_SCENE := "res://game/player/player.tscn"
const PAINT := "res://assets/export/characters/player/trailer/player_paint.png"
const INK := "res://assets/export/characters/player/trailer/player_ink.png"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]
const PARTS: Array[StringName] = [&"Body", &"Body__fp_hidden", &"Body__fp_torso", &"Body__fp_arm"]
## Triangles under half a texel of UV2 area, as a share of a mesh's triangles (the m6 layout's arm parts were far above it).
const SLIVER_MAX := 0.03
const ARM_SLIVER_MAX := 0.005

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	SkinnedArt.clear_cache()
	_art = load(HERO_ART) as CharacterArt


func after_each() -> void:
	Tuning.reset_to_default()


func _trailer() -> CharacterArt:
	return _art.trailer_art()


## {mesh name: surface arrays} of an art's GLB.
func _parts(scene: PackedScene) -> Dictionary:
	var out := {}
	var holder := scene.instantiate()
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		out[StringName(node.name)] = mesh.surface_get_arrays(0)
	holder.free()
	return out


func _sliver_share(arrays: Array, uv: PackedVector2Array) -> float:
	var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var slivers := 0
	for t in range(0, idx.size(), 3):
		var p0 := uv[idx[t]] * MAP_SIZE
		var p1 := uv[idx[t + 1]] * MAP_SIZE
		var p2 := uv[idx[t + 2]] * MAP_SIZE
		if absf((p1 - p0).cross(p2 - p0)) * 0.5 < 0.5:
			slivers += 1
	return float(slivers) / maxf(idx.size() / 3.0, 1.0)


func test_the_hero_carries_a_painted_trailer_variant_and_m6_is_untouched() -> void:
	assert_not_null(_trailer(), "player_art.tres has metadata/trailer")
	assert_true(ToonMaterials.is_painted(_trailer()), "a paint map and an ink map")
	assert_eq(_art.variant(&"m6"), _art)
	assert_eq(_art.variant(&"trailer"), _trailer())
	assert_eq(String(_art.get_meta(&"scene_path")), "res://assets/export/characters/player/player.glb", "the m6 hero still names its own GLB")
	assert_eq(String(_art.get_meta(&"detail_mask_path")), "res://assets/export/characters/player/player_detail.png")
	assert_true(bool(_art.get_meta(&"detail_sharp")))
	assert_eq(_art.triangle_budget, 30000)
	assert_true(SkinnedArt.check(_trailer()).is_empty(), "it keeps the art contract: %s" % ", ".join(SkinnedArt.check(_trailer())))
	assert_null(_trailer().trailer_art(), "a variant has no variant of its own")


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


func test_the_ink_map_follows_the_channel_contract_and_the_gloves_are_drawn() -> void:
	var image := (_trailer().get_meta(ToonMaterials.INK_META) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var classes := {}
	var lines := 0
	var weight_min := 255.0
	for y in range(0, MAP_SIZE, 4):
		for x in range(0, MAP_SIZE, 4):
			var c := image.get_pixel(x, y)
			classes[roundi(c.g * 255.0)] = true
			if c.r > 0.5:
				lines += 1
			if c.a > 0.0:
				weight_min = minf(weight_min, c.a * 255.0)
	for key: int in classes:
		assert_true(CLASS_BYTES.has(key), "G holds only the damage class bytes, found %d" % key)
	assert_true(classes.has(255), "clothes (sleeves, gloves)")
	assert_gt(lines, 4000, "the drawing has lines (folds, knuckle creases, finger lines, stitching, the strap)")
	assert_gt(weight_min, 0.0, "the hull weight hint is never zero")


func test_the_trailer_mesh_is_the_hero_mesh_with_a_fresh_uv2_and_no_slivers() -> void:
	var m6 := _parts(_art.scene if _art.scene != null else load(String(_art.get_meta(&"scene_path"))) as PackedScene)
	var tr := _parts(_trailer().scene)
	for part in PARTS:
		assert_true(tr.has(part), "the trailer GLB has %s" % part)
		assert_true(m6.has(part), "the m6 GLB has %s" % part)
		var a := m6[part] as Array
		var b := tr[part] as Array
		assert_eq((b[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), "%s: the same triangles (hit and pose are untouched)" % part)
		var uv2 := b[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
		assert_eq(uv2.size(), (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "%s has a UV2" % part)
		var out := 0
		for uv: Vector2 in uv2:
			if uv.x < -0.0001 or uv.x > 1.0001 or uv.y < -0.0001 or uv.y > 1.0001:
				out += 1
		assert_eq(out, 0, "%s: every UV2 is inside the map" % part)
		var share := _sliver_share(b, uv2)
		var old := _sliver_share(a, a[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)
		print("T14-SLIVERS %s: trailer %.3f%% m6 %.3f%%" % [part, share * 100.0, old * 100.0])
		assert_lt(share, ARM_SLIVER_MAX if part == &"Body__fp_arm" else SLIVER_MAX, "%s: no slivers to speak of" % part)
		assert_lt(share, old, "%s: fewer slivers than the m6 layout" % part)
	# the rig's bounds are the same body
	var va := (m6[&"Body"] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var vb := (tr[&"Body"] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var box_a := AABB(va[0], Vector3.ZERO)
	for v: Vector3 in va:
		box_a = box_a.expand(v)
	var box_b := AABB(vb[0], Vector3.ZERO)
	for v: Vector3 in vb:
		box_b = box_b.expand(v)
	assert_almost_eq(box_b.size, box_a.size, Vector3.ONE * 0.01, "the same body")


func test_the_trailer_arm_normals_are_smoothed() -> void:
	# the shipped normals read as facets on a near arm: on the arm part the trailer's normals of neighbouring vertices agree more than the m6's
	var m6 := (_parts(load(String(_art.get_meta(&"scene_path"))) as PackedScene)[&"Body__fp_arm"]) as Array
	var tr := (_parts(_trailer().scene)[&"Body__fp_arm"]) as Array
	assert_lt(_edge_disagreement(tr), _edge_disagreement(m6), "neighbouring normals agree more than the m6's")


## The mean angle (radians) between the normals at the two ends of every triangle edge.
func _edge_disagreement(arrays: Array) -> float:
	var n := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var total := 0.0
	var count := 0
	for t in range(0, idx.size(), 3):
		for k in 3:
			total += n[idx[t + k]].angle_to(n[idx[t + (k + 1) % 3]])
			count += 1
	return total / maxf(count, 1)


func _player() -> PlayerCharacter:
	var p := (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerCharacter
	add_child_autofree(p)
	await get_tree().physics_frame
	return p


func test_the_player_wears_the_trailer_hero_only_under_the_trailer_profile() -> void:
	var p := await _player()
	var m6_art := p.rig.worn_art()
	assert_ne(m6_art.id, &"player_trailer", "m6 by default")
	var m6_names := _art_names(p.rig)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(p.rig.worn_art().id, &"player_trailer")
	var names := _art_names(p.rig)
	for part in PARTS:
		assert_true(names.has(StringName("Art%s" % part)), "the trailer art has %s on the skeleton" % part)
	assert_eq(names.size(), m6_names.size(), "the same parts as the m6 art")
	assert_true(ToonMaterials.is_painted(p.rig.worn_art()))
	assert_not_null((p.rig.paint.art_material() as ShaderMaterial).get_shader_parameter(&"paint_tex"), "the painted material")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(p.rig.worn_art(), m6_art, "flipping back restores the m6 hero")
	assert_eq(_art_names(p.rig).size(), m6_names.size())


func _art_names(rig: HumanoidRig) -> Array[StringName]:
	var out: Array[StringName] = []
	for mesh in rig.art_meshes():
		out.append(StringName(mesh.name))
	return out


func test_the_first_person_camera_drops_its_cached_meshes_when_the_art_swaps() -> void:
	var p := await _player()
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = p
	cam._arm_meshes = cam._find_arm_meshes()
	cam._torso_meshes = cam._find_torso_meshes()
	assert_gt(cam._arm_meshes.size(), 0, "the m6 arm meshes are cached")
	var old_arm := cam._arm_meshes[0]
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_true(cam._arm_meshes.is_empty(), "the swap clears the arm cache")
	assert_true(cam._torso_meshes.is_empty(), "and the torso cache")
	await get_tree().process_frame
	assert_false(is_instance_valid(old_arm), "the old arm mesh is gone")
	var fresh := cam._find_arm_meshes()
	assert_gt(fresh.size(), 0, "the trailer art's arm meshes are found")
	for mesh in fresh:
		assert_true(is_instance_valid(mesh))
	# the near arm's lit copy works on the painted material (the bands are the toon material's; the copy is a copy either way)
	var material := fresh[0].material_override
	var copy := cam._arm_lit_copy(material)
	assert_not_null(copy)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_true(cam._arm_meshes.is_empty())
	assert_gt(cam._find_arm_meshes().size(), 0, "and back")


func test_a_player_spawned_in_the_trailer_profile_wears_it_and_the_camera_follows_a_new_player() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var p := await _player()
	assert_eq(p.rig.worn_art().id, &"player_trailer")
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = p
	var q := await _player()
	cam.player = q
	cam._arm_meshes = cam._find_arm_meshes()
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_true(cam._arm_meshes.is_empty(), "the camera listens to the player it rides now")
	assert_eq(q.rig.worn_art().id, &"player", "m6 again")


func test_the_gloves_are_drawn_from_sheets_whose_sources_are_kept() -> void:
	# G2: the gloves' knuckle creases, finger separations and strap lines are Gemini drawings (t_06 as style reference) projected onto the maps
	var f := FileAccess.open("res://assets/source/trailer_art/player/sheets.json", FileAccess.READ)
	assert_not_null(f)
	var spec := JSON.parse_string(f.get_as_text()) as Dictionary
	var count := 0
	for sheet: Dictionary in spec["sheets"]:
		assert_true(FileAccess.file_exists("res://assets/source/trailer_art/player/" + String(sheet["src"])), "missing %s" % sheet["src"])
		count += 1
	assert_eq(count, 8, "four views of each glove (the left mirrored from the right)")


## C3 (the clean look): the maps are flat fills and a few bold lines. A guard against the scribbles coming back: no grain or hatch in the fills (few steps of
## colour between neighbouring texels) and the ink map's lines are few (the sleeve's long slashes, the glove's leaf network and the strap's wedges all raised it).
func test_the_maps_are_flat_fills_and_a_few_bold_lines() -> void:
	var paint := load(PAINT) as Texture2D
	var ink := load(INK) as Texture2D
	var pimg := paint.get_image()
	var iimg := ink.get_image()
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
	assert_lt(lines, 9000, "a few bold lines, not a scribble (%d sampled line texels)" % lines)
