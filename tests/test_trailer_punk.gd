extends GutTest
## Milestone 7, T12: the trailer Punk (the canonical trailer Punk painted onto the current Punk mesh). punk_art.tres carries it as
## `metadata/trailer`: its own GLB (the same mesh and rig, a fresh UV2), a 2048 paint map and ink map to the painted material's contract
## (docs/ARCHITECTURE.md "The painted material (M7)"), the veteran's recolour of the same maps; the m6 Punk is untouched.

const PUNK_ART := "res://game/actors/art/punk_art.tres"
const M6_GLB := "res://assets/export/characters/punk/punk.glb"
const PAINT := "res://assets/export/characters/punk/trailer/punk_paint.png"
const INK := "res://assets/export/characters/punk/trailer/punk_ink.png"
const VETERAN := "res://game/enemies/variants/punk_veteran.tres"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	_art = load(PUNK_ART) as CharacterArt


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


func test_the_punk_carries_a_painted_trailer_variant() -> void:
	assert_not_null(_trailer(), "punk_art.tres has metadata/trailer")
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


func test_a_rig_wears_the_trailer_punk_only_under_the_trailer_profile() -> void:
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


func test_damage_marks_still_show_on_the_trailer_punk() -> void:
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


func test_the_veteran_wears_the_recolour_of_the_same_maps() -> void:
	var variant := load(VETERAN) as EnemyVariant
	var recolour := variant.trailer_paint()
	assert_not_null(recolour, "punk_veteran.tres names a trailer paint map")
	assert_eq(recolour.get_width(), MAP_SIZE)
	var base := (_trailer().get_meta(ToonMaterials.PAINT_META) as Texture2D)
	assert_ne(recolour.resource_path, base.resource_path)
	var a := base.get_image()
	var b := recolour.get_image()
	if a.is_compressed():
		a.decompress()
	if b.is_compressed():
		b.decompress()
	var different := 0
	var same := 0
	for y in range(0, MAP_SIZE, 16):
		for x in range(0, MAP_SIZE, 16):
			if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				same += 1
			else:
				different += 1
	assert_gt(different, 0, "a recolour")
	assert_gt(same, 0, "of the same maps (skin, sleeves and jeans stay)")


func test_a_spawned_veteran_wears_it_and_a_plain_punk_does_not() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var vet := EncounterSpawner.make_enemy(EnemyCatalog.scene(&"punk_veteran"), &"punk_veteran", {})
	var plain := EncounterSpawner.make_enemy(EnemyCatalog.scene(&"punk"), &"punk", {})
	add_child_autofree(vet)
	add_child_autofree(plain)
	await get_tree().physics_frame
	var variant := EnemyCatalog.variant(&"punk_veteran")
	var vet_mat := vet.rig.paint.art_material() as ShaderMaterial
	var plain_mat := plain.rig.paint.art_material() as ShaderMaterial
	assert_true(ToonMaterials.is_painted(vet.rig.worn_art()))
	assert_eq(vet_mat.get_shader_parameter(&"paint_tex"), variant.trailer_paint(), "the veteran's recolour")
	assert_eq(plain_mat.get_shader_parameter(&"paint_tex"), _trailer().get_meta(ToonMaterials.PAINT_META), "the plain Punk's own paint")
	# the m6 palette swap is untouched and survives a round trip of the profile
	var m6_art := vet.rig.paint.base_art_material()
	assert_eq((m6_art as ShaderMaterial).get_shader_parameter(&"albedo_tex"), variant.palette, "the m6 palette swap")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq((vet.rig.paint.art_material() as ShaderMaterial).get_shader_parameter(&"paint_tex"), variant.trailer_paint(), "after a flip back and forth")
