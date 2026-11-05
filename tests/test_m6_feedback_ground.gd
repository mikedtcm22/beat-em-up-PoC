extends GutTest
## M6 playtest feedback, FB-GROUND: the street floor held still and read as a drawn comic street.
##
## The flashing was two coplanar planes: the street's Floor (top at y 0) and the boss roof's 200 m `Ground`, which in world space
## also had its top at y 0 and covered the whole street, so the two fought for every pixel (a z-fight that swung with the
## camera's millimetres). What this holds true: no two floor-like blocks of the level share a top plane over any area, the ground
## tile's ink is never thinner than the mips can carry, the tile is seamless and inside the look bible's band, the trim material
## samples it in world metres with its mips unlimited (the strips keep the capped mip and fade their ink), and the Debug switch
## gives the sheet's own asphalt back. The colliders are unchanged (tests/test_m6_colliders.gd).

const Snapshot := preload("res://tests/m6_collider_snapshot.gd")
const Scan := preload("res://tests/m6_coplanar_scan.gd")
## Ink pixels thinner than this (the shorter of the pixel's two straight runs) are tips and rounding only.
const MIN_RUN := 4
const RUN_CAP := 12


func after_each() -> void:
	Tuning.apply(TuningData.new())


func _ground() -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TrimSheet.GROUND_PATH))
	assert_not_null(image, "the ground tile is on disk")
	image.convert(Image.FORMAT_RGBA8)
	return image


## The share of the ink pixels in the rectangle (x0, y0, w, h) of `image` whose narrower straight run is under MIN_RUN px.
func _thin_share(image: Image, x0: int, y0: int, w: int, h: int) -> Dictionary:
	var data := image.get_data()
	var width := image.get_width()
	var ink := 0
	var thin := 0
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if data[(y * width + x) * 4 + 3] < 128:
				continue
			ink += 1
			var run_x := 1
			var k := 1
			while k < RUN_CAP and x - k >= x0 and data[(y * width + x - k) * 4 + 3] >= 128:
				run_x += 1
				k += 1
			k = 1
			while k < RUN_CAP and x + k < x0 + w and data[(y * width + x + k) * 4 + 3] >= 128:
				run_x += 1
				k += 1
			var run_y := 1
			k = 1
			while k < RUN_CAP and y - k >= y0 and data[((y - k) * width + x) * 4 + 3] >= 128:
				run_y += 1
				k += 1
			k = 1
			while k < RUN_CAP and y + k < y0 + h and data[((y + k) * width + x) * 4 + 3] >= 128:
				run_y += 1
				k += 1
			if mini(run_x, run_y) < MIN_RUN:
				thin += 1
	return {ink = ink, thin = thin}


func test_the_ground_tile_has_ink_and_its_ink_is_never_thin() -> void:
	var image := _ground()
	assert_eq(image.get_width(), 2048)
	assert_eq(image.get_height(), 2048)
	var result := _thin_share(image, 0, 0, 2048, 2048)
	assert_gt(int(result.ink), 20000, "the tile carries ink (cracks, squares, a manhole, grates)")
	assert_lt(float(result.thin) / float(result.ink), 0.04, "at most 4%% of the ink pixels are narrower than %d px (%d of %d)" % [MIN_RUN, result.thin, result.ink])


func test_the_ground_strips_ink_is_never_thin() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TrimSheet.SHEET_PATH))
	image.convert(Image.FORMAT_RGBA8)
	for strip_name: StringName in [&"asphalt", &"concrete", &"kerb", &"roof_tar"]:
		var row := TrimSheet.index(strip_name) * 128
		var result := _thin_share(image, 0, row, 2048, 128)
		assert_gt(int(result.ink), 1000, "%s: the strip carries ink" % strip_name)
		assert_lt(float(result.thin) / float(result.ink), 0.04, "%s: at most 4%% of its ink pixels are narrower than %d px (%d of %d)" % [strip_name, MIN_RUN, result.thin, result.ink])


func test_the_ground_tile_is_inside_the_look_bible_and_ink_is_the_one_ink() -> void:
	var image := _ground()
	var worst_s := 0.0
	var lowest_v := 1.0
	var highest_v := 0.0
	var inked := 0
	for y in range(0, 2048, 3):
		for x in range(0, 2048, 3):
			var c := image.get_pixel(x, y)
			if c.a >= 0.5:
				inked += 1
				assert_lt(absf(c.r - HudStyle.INK.r) + absf(c.g - HudStyle.INK.g) + absf(c.b - HudStyle.INK.b), 0.03, "an ink pixel is HudStyle.INK")
				continue
			worst_s = maxf(worst_s, c.s)
			lowest_v = minf(lowest_v, c.v)
			highest_v = maxf(highest_v, c.v)
	assert_gt(inked, 1000)
	assert_lte(worst_s, 0.30 + 0.005, "saturation at most 0.30 (%.3f)" % worst_s)
	assert_gte(lowest_v, 0.25 - 0.005, "value at least 0.25 (%.3f)" % lowest_v)
	assert_lte(highest_v, 0.6 + 0.005, "value at most 0.6 (%.3f)" % highest_v)


func test_the_ground_tile_is_flat_toned_not_noise() -> void:
	# A few broad tones, not a grain: the number of distinct colours outside the ink is small.
	var image := _ground()
	var seen := {}
	for y in range(0, 2048, 4):
		for x in range(0, 2048, 4):
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				seen[Color(c.r, c.g, c.b).to_rgba32()] = true
	assert_lte(seen.size(), 16, "the ground is a handful of flat tones (%d colours)" % seen.size())
	assert_gte(seen.size(), 4, "and more than one")


func test_the_ground_tile_is_seamless() -> void:
	var image := _ground()
	var same_x := 0
	var same_y := 0
	for n in 2048:
		if (image.get_pixel(0, n).a >= 0.5) == (image.get_pixel(2047, n).a >= 0.5):
			same_x += 1
		if (image.get_pixel(n, 0).a >= 0.5) == (image.get_pixel(n, 2047).a >= 0.5):
			same_y += 1
	assert_gt(same_x, 2048 * 0.99, "the left and right edges agree on where the ink is")
	assert_gt(same_y, 2048 * 0.99, "the top and bottom edges agree on where the ink is")
	var tone_x := 0
	for n in 2048:
		if image.get_pixel(0, n).is_equal_approx(image.get_pixel(2047, n)):
			tone_x += 1
	assert_gt(tone_x, 2048 * 0.97, "and on the tone: a seam would show as a cut every tile")


func test_the_strip_table_flags_the_asphalt_as_the_ground() -> void:
	assert_true(TrimSheet.is_ground(&"asphalt"))
	for strip_name: StringName in TrimSheet.names():
		if strip_name != &"asphalt":
			assert_false(TrimSheet.is_ground(strip_name), "%s is not the ground" % strip_name)
	var rows := TrimSheet.uniform_rows()
	assert_eq(int(rows[TrimSheet.index(&"asphalt")].w) & 4, 4, "the shader's flag 4 is on the asphalt's row")
	assert_almost_eq(TrimSheet.ground_tile_m(), 8.0, 0.001)


func test_the_trim_material_samples_the_ground_in_world_metres_with_its_mips_free() -> void:
	var material := ToonMaterials.trim()
	assert_not_null(material.get_shader_parameter(&"ground_tex"), "the ground tile is on the material")
	assert_almost_eq(float(material.get_shader_parameter(&"ground_m")), Tuning.data.ground_m_per_tile, 0.001)
	assert_true(bool(material.get_shader_parameter(&"ground_on")))
	var code := FileAccess.get_file_as_string("res://game/fx/trim_body.gdshaderinc")
	assert_string_contains(code, "world_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz", "the ground's coordinates are the world's")
	assert_string_contains(code, "textureGrad(ground_tex, gtm, ggx, ggy)", "the ground's gradients are the surface's own: every mip level in reach")
	assert_string_contains(code, "vec2 gtm = vec2(gt.x, abs(mod(gt.y, 2.0) - 1.0))", "the tile is mirrored on every other tile down the street, so its manhole and grates repeat every two")
	assert_string_contains(code, "fade_texels = sqrt(abs(gx.x * gy.y - gx.y * gy.x)) * sheet", "a strip's ink fades by the mean side of the footprint, not the longer")
	assert_string_contains(code, "textureGrad(trim_tex, uv, gx * keep, gy * keep)", "the strips keep the capped mip")
	assert_string_contains(code, "mask *= 1.0 - smoothstep(ink_fade.x, ink_fade.y, fade_texels)", "and fade their ink where the cap would alias it (by the footprint's mean side)")


func test_the_ground_tunables_reach_the_material_live() -> void:
	var material := ToonMaterials.trim()
	Tuning.set_value(&"ground_m_per_tile", 12.0)
	assert_almost_eq(float(material.get_shader_parameter(&"ground_m")), 12.0, 0.001)
	Tuning.set_value(&"ground_ink_soft_max", 0.2)
	var soft: Vector3 = material.get_shader_parameter(&"ink_soft")
	assert_almost_eq(soft.z, 0.2, 0.001)
	Tuning.set_value(&"ground_ink_fade_start_texels", 8.0)
	var fade: Vector2 = material.get_shader_parameter(&"ink_fade")
	assert_almost_eq(fade.x, 8.0, 0.001)


func test_the_debug_switch_gives_back_the_sheets_own_asphalt() -> void:
	var material := ToonMaterials.trim()
	Tuning.set_value(&"ground_sheet_off", true)
	assert_false(bool(material.get_shader_parameter(&"ground_on")))
	Tuning.set_value(&"ground_sheet_off", false)
	assert_true(bool(material.get_shader_parameter(&"ground_on")))
	assert_false(TuningData.new().ground_sheet_off, "off by default")


func test_a_floor_face_wears_the_asphalt_strip() -> void:
	var mesh := KitMesh.build(&"floor", Vector3(12.0, 1.0, 56.0))
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var ground_faces := 0
	for i in colors.size():
		if normals[i].y > 0.9:
			assert_eq(int(round(colors[i].a * 255.0)), TrimSheet.index(&"asphalt"), "the top is asphalt")
			ground_faces += 1
	assert_eq(ground_faces, 4, "one top face")


# --- The cause: two coplanar planes ---------------------------------------------------------------


## The smallest shared area (square metres) that counts in the two code-built rooms: their boxes come from crowd_room.gd and
## test_room.gd (not the level's scenes, so not the InsetBlock's to fix), where only slivers of 0.3 m2 and less remain
## (docs/milestones/M6-calls/FIX-WORLD.md, "Requests"). Everything a player could see as a flicker is far above it.
const ROOM_MIN_AREA_M2 := 0.5


func _scan(scene: String, min_area: float) -> Array[Dictionary]:
	var holder := Node.new()
	add_child_autofree(holder)
	var root := Snapshot.instantiate(scene, holder)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var found := Scan.pairs(root, min_area)
	assert_gt(Scan.drawn_boxes(root).size(), 8, "the scene draws boxes")
	for pair in found:
		gut.p(String(pair.text))
	return found


func test_no_two_drawn_faces_of_the_level_share_a_plane_over_an_area() -> void:
	var found: Array[Dictionary] = await _scan(Snapshot.LEVEL, Scan.MIN_AREA_M2)
	assert_eq(found.size(), 0, "no two drawn faces of the level (any module, look or thickness) share a plane (a z-fight)")


func test_no_two_drawn_faces_of_the_crowd_street_share_a_plane_over_an_area() -> void:
	var found: Array[Dictionary] = await _scan(Snapshot.CROWD, ROOM_MIN_AREA_M2)
	assert_eq(found.size(), 0, "no two drawn faces of the crowd street share a plane")


func test_no_two_drawn_faces_of_the_training_room_share_a_plane_over_an_area() -> void:
	var found: Array[Dictionary] = await _scan(Snapshot.TRAINING, ROOM_MIN_AREA_M2)
	assert_eq(found.size(), 0, "no two drawn faces of the training room share a plane")


func test_the_scan_finds_a_pair_it_is_given() -> void:
	## The guard is only worth having if it fires: two floor slabs on one top over 2 x 3 m, and a second pair that is not coplanar.
	var holder := Node3D.new()
	add_child_autofree(holder)
	var floor_a := LevelBlock.new()
	floor_a.size = Vector3(4.0, 1.0, 4.0)
	floor_a.look = &"floor"
	holder.add_child(floor_a)
	var floor_b := LevelBlock.new()
	floor_b.size = Vector3(4.0, 1.0, 4.0)
	floor_b.look = &"floor"
	floor_b.position = Vector3(2.0, 0.0, 1.0)
	holder.add_child(floor_b)
	var step := LevelBlock.new()
	step.size = Vector3(1.0, 1.0, 1.0)
	step.look = &"floor"
	step.position = Vector3(-1.5, 0.1, -1.5)
	holder.add_child(step)
	await get_tree().physics_frame
	var found := Scan.pairs(holder)
	assert_eq(found.size(), 1, "one coplanar pair: the two slabs, not the stepped one")
	assert_almost_eq(float(found[0].area), 2.0 * 3.0, 0.01, "over 2 x 3 m")
	floor_b.position = Vector3(2.0, 0.1, 1.0)
	await get_tree().physics_frame
	assert_eq(Scan.pairs(holder).size(), 0, "a tenth of a metre apart they no longer share a plane")


func test_an_inset_block_draws_smaller_and_collides_as_the_box() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var block := InsetBlock.new()
	block.size = Vector3(4.0, 2.0, 1.0)
	block.inset_min = Vector3(0.0, 0.0, 0.04)
	block.inset_max = Vector3(0.02, 0.02, 0.0)
	holder.add_child(block)
	await get_tree().physics_frame
	var shape := block.body.get_child(0) as CollisionShape3D
	assert_eq((shape.shape as BoxShape3D).size, Vector3(4.0, 2.0, 1.0), "the collider is the whole box")
	var mesh := block.body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var drawn: AABB = mesh.global_transform * mesh.mesh.get_aabb()
	assert_almost_eq(drawn.position.z, -0.5 + 0.04, 0.001, "the - z face is pulled in 4 cm")
	assert_almost_eq(drawn.end.z, 0.5, 0.001, "the + z face stays")
	assert_almost_eq(drawn.end.y, 1.0 - 0.02, 0.001, "the top is pulled in 2 cm")
	assert_almost_eq(drawn.end.x, 2.0 - 0.02, 0.001, "the + x face is pulled in 2 cm")
	assert_almost_eq(drawn.position.x, -2.0, 0.001, "the - x face stays")


func test_the_boss_roofs_far_ground_is_not_solid_and_lies_below_the_street() -> void:
	var holder := Node.new()
	add_child_autofree(holder)
	var level := Snapshot.instantiate(Snapshot.LEVEL, holder)
	await get_tree().physics_frame
	var ground := level.get_node("Sections/BossRoof/Geometry/Ground") as LevelBlock
	assert_false(ground.solid, "it draws only, so no collider moved")
	var street := level.get_node("Sections/Street/Geometry/Floor") as LevelBlock
	assert_lt(ground.world_aabb().end.y, street.world_aabb().end.y - 0.1, "its top lies clear below the street's")
