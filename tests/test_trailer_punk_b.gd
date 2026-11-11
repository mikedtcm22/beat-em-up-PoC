extends GutTest
## Milestone 7, T13: the Punk's arm B, a new Tripo mesh of the trailer design (articulated gloved fists), rigged through the project's chain and painted as
## arm A is. punk_art.tres carries it as `metadata/trailer_b`; Tuning `trailer_punk_arm` (default 0 = arm A) picks which one `trailer_art()` returns.

const PUNK_ART := "res://game/actors/art/punk_art.tres"
const B_ART := "res://game/actors/art/punk_trailer_b.tres"
const PAINT := "res://assets/export/characters/punk_b/trailer/punk_b_paint.png"
const INK := "res://assets/export/characters/punk_b/trailer/punk_b_ink.png"
const VETERAN := "res://game/enemies/variants/punk_veteran.tres"
const MAP_SIZE := 2048
const CLASS_BYTES: Array[int] = [255, 230, 204, 128]

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	_art = load(PUNK_ART) as CharacterArt


func after_each() -> void:
	Tuning.reset_to_default()


func _b() -> CharacterArt:
	return load(B_ART) as CharacterArt


func _arm_b() -> void:
	Tuning.set_value(&"trailer_punk_arm", 1)


func _first_mesh(art: CharacterArt) -> ArrayMesh:
	var holder := art.scene.instantiate()
	var found: ArrayMesh = null
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		found = (node as MeshInstance3D).mesh as ArrayMesh
		break
	holder.free()
	return found


func _image(tex: Texture2D) -> Image:
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func test_the_tunable_picks_the_arm_and_defaults_to_a() -> void:
	assert_eq(Tuning.data.trailer_punk_arm, 0, "arm A by default")
	var a := _art.trailer_art()
	assert_eq(a.id, &"punk_trailer")
	_arm_b()
	assert_eq(_art.trailer_art(), _b(), "arm B when the tunable is 1")
	assert_eq(_art.variant(&"trailer"), _b())
	assert_eq(_art.variant(&"m6"), _art, "the m6 art is never touched")
	Tuning.set_value(&"trailer_punk_arm", 0)
	assert_eq(_art.trailer_art(), a, "and back to A")


func test_arm_b_is_painted_and_keeps_the_art_contract() -> void:
	var b := _b()
	assert_true(ToonMaterials.is_painted(b), "a paint map and an ink map")
	assert_ne(b.scene.resource_path, _art.scene.resource_path, "its own GLB")
	assert_ne(b.scene.resource_path, (_art.get_meta(&"trailer") as CharacterArt).scene.resource_path, "a different mesh from arm A")
	assert_true(SkinnedArt.check(b).is_empty(), "the art contract: %s" % ", ".join(SkinnedArt.check(b)))
	assert_eq((b.get_meta(ToonMaterials.PAINT_META) as Texture2D).resource_path, PAINT)
	assert_eq((b.get_meta(ToonMaterials.INK_META) as Texture2D).resource_path, INK)


func test_the_maps_are_2048_and_the_ink_map_is_data() -> void:
	assert_eq(load(PAINT).get_width(), MAP_SIZE)
	assert_eq(load(INK).get_width(), MAP_SIZE)
	var conf := ConfigFile.new()
	assert_eq(conf.load(INK + ".import"), OK)
	assert_eq(int(conf.get_value("params", "compress/mode")), 0, "lossless")
	assert_true(bool(conf.get_value("params", "mipmaps/generate")), "mipmaps on")
	assert_false(bool(conf.get_value("params", "process/fix_alpha_border")), "no colour bleed in the ink map")


func test_the_ink_map_has_the_drawn_face() -> void:
	var image := _image(load(INK) as Texture2D)
	var classes := {}
	var lines := 0
	for y in range(0, MAP_SIZE, 4):
		for x in range(0, MAP_SIZE, 4):
			var c := image.get_pixel(x, y)
			classes[roundi(c.g * 255.0)] = true
			if c.r > 0.5:
				lines += 1
	for key: int in classes:
		assert_true(CLASS_BYTES.has(key), "G holds only the damage class bytes, found %d" % key)
	assert_true(classes.has(204), "skin (the face)")
	assert_gt(lines, 2000, "the drawing has lines (folds, seams, the face)")


func test_arm_b_is_the_rigged_tripo_mesh_in_the_game_scale() -> void:
	var mesh := _first_mesh(_b())
	assert_not_null(mesh)
	var arrays := mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var box := AABB(verts[0], Vector3.ZERO)
	for v: Vector3 in verts:
		box = box.expand(v)
	assert_almost_eq(box.size.y, 1.8, 0.05, "the Punk's 1.82 m with the cap")
	assert_almost_eq(box.position.y, 0.0, 0.01, "soles on the floor")
	assert_not_null(arrays[Mesh.ARRAY_BONES], "skinned")
	var m6_box := _first_mesh(_art).get_aabb()
	assert_gt(box.size.x * box.size.z, 0.0)
	assert_gt(m6_box.size.y, 1.7)
	var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert_lte(idx.size() / 3, 15000, "inside the enemy triangle budget")
	var uv2 := arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	assert_eq(uv2.size(), verts.size(), "it has a UV2")
	var out := 0
	for uv: Vector2 in uv2:
		if uv.x < -0.0001 or uv.x > 1.0001 or uv.y < -0.0001 or uv.y > 1.0001:
			out += 1
	assert_eq(out, 0, "every UV2 is inside the map")
	var slivers := 0
	for t in range(0, idx.size(), 3):
		var p0 := uv2[idx[t]] * MAP_SIZE
		var p1 := uv2[idx[t + 1]] * MAP_SIZE
		var p2 := uv2[idx[t + 2]] * MAP_SIZE
		if absf((p1 - p0).cross(p2 - p0)) * 0.5 < 0.5:
			slivers += 1
	assert_lt(float(slivers) / (idx.size() / 3.0), 0.005, "no slivers to speak of (%d)" % slivers)


func test_a_rig_wears_arm_b_under_the_trailer_profile_with_the_tunable() -> void:
	_arm_b()
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = _art
	add_child_autofree(rig)
	rig.build()
	assert_eq(rig.worn_art(), _art, "m6 by default")
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(rig.worn_art(), _b())
	var painted := rig.paint.art_material() as ShaderMaterial
	assert_eq(painted.get_shader_parameter(&"paint_tex"), _b().get_meta(ToonMaterials.PAINT_META), "arm B's own paint")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(rig.worn_art(), _art, "flipping back restores the m6 Punk")


func test_the_veteran_wears_the_recolour_on_arm_b_only_with_the_tunable() -> void:
	var variant := load(VETERAN) as EnemyVariant
	var a_paint := variant.trailer_paint()
	_arm_b()
	var b_paint := variant.trailer_paint()
	assert_ne(a_paint, b_paint, "the recolour follows the arm")
	assert_eq(b_paint.get_width(), MAP_SIZE)
	assert_true(b_paint.resource_path.contains("punk_b"))
	var a := _image(b_paint)
	var b := _image(load(PAINT) as Texture2D)
	var different := 0
	for y in range(0, MAP_SIZE, 16):
		for x in range(0, MAP_SIZE, 16):
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				different += 1
	assert_gt(different, 0, "a recolour of arm B's maps")
