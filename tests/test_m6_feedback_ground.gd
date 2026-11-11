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


func _holes_and_steps(scene: String) -> Array[Dictionary]:
	var holder := Node.new()
	add_child_autofree(holder)
	var root := Snapshot.instantiate(scene, holder)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var found: Array[Dictionary] = []
	found.append_array(Scan.holes(root))
	found.append_array(Scan.steps(root))
	for item in found:
		gut.p(String(item.text))
	return found


func test_no_block_of_the_level_leaves_a_hole_or_a_step() -> void:
	var found: Array[Dictionary] = await _holes_and_steps(Snapshot.LEVEL)
	assert_eq(found.size(), 0, "no rectangle a block takes out of its face is left undrawn, and no face stands a few centimetres in front of another it only partly covers (a step the edge pass inks)")


func test_no_box_of_the_crowd_street_leaves_a_hole_or_a_step() -> void:
	var found: Array[Dictionary] = await _holes_and_steps(Snapshot.CROWD)
	assert_eq(found.size(), 0, "no hole and no step in the crowd street")


func test_the_rooms_boxes_yield_their_overlaps_and_collide_as_they_did() -> void:
	## The room's coplanar slivers (17 in the crowd street, 2 in the training room at 0.02 m2 before) are taken out of the smaller box's
	## face, so some boxes carry what they do not draw; the colliders are tests/test_m6_colliders.gd's.
	for scene: String in [Snapshot.CROWD, Snapshot.TRAINING]:
		var holder := Node.new()
		add_child_autofree(holder)
		var root := Snapshot.instantiate(scene, holder)
		await get_tree().physics_frame
		var clipped := 0
		for item in Scan.drawn_boxes(root):
			if (item.owner as Node).has_meta(RoomKit.CLIPPED_META):
				clipped += 1
		assert_gt(clipped, 0, "%s: some box yields an overlap" % scene)


func test_no_box_of_the_training_room_leaves_a_hole_or_a_step() -> void:
	var found: Array[Dictionary] = await _holes_and_steps(Snapshot.TRAINING)
	assert_eq(found.size(), 0, "no hole and no step in the training room")


func test_no_two_drawn_faces_of_the_crowd_street_share_a_plane_over_an_area() -> void:
	var found: Array[Dictionary] = await _scan(Snapshot.CROWD, Scan.MIN_AREA_M2)
	assert_eq(found.size(), 0, "no two drawn faces of the crowd street share a plane")


func test_no_two_drawn_faces_of_the_training_room_share_a_plane_over_an_area() -> void:
	var found: Array[Dictionary] = await _scan(Snapshot.TRAINING, Scan.MIN_AREA_M2)
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


## Two kit walls that end in one plane over part of it: a tall 4 x 6 x 1 m wall A (x -2 to 2, y 0 to 6, z -0.5 to `a_front`) and
## a short 1.5 x 3 m wall B (x 0 to 1.5, y 0 to 3, z up to 0.5) beside it, on a floor, so their + z faces overlap over x 0 to 1.5, y 0 to 3 when
## `a_front` is 0.5. Returns [A (an InsetBlock, yielding to B when `a_yields`), B].
func _two_walls(holder: Node3D, a_yields: bool, a_front: float = 0.5) -> Array[LevelBlock]:
	var ground := LevelBlock.new()
	ground.size = Vector3(20.0, 1.0, 20.0)
	ground.position = Vector3(0.0, -0.5, 0.0)
	ground.look = &"floor"
	holder.add_child(ground)
	var wall_a := InsetBlock.new()
	wall_a.size = Vector3(4.0, 6.0, a_front + 0.5)
	wall_a.position = Vector3(0.0, 3.0, (a_front - 0.5) * 0.5)
	holder.add_child(wall_a)
	var wall_b := LevelBlock.new()
	wall_b.size = Vector3(1.5, 3.0, 2.0)
	wall_b.position = Vector3(0.75, 1.5, -0.5)
	holder.add_child(wall_b)
	if a_yields:
		wall_a.yields_to = [wall_a.get_path_to(wall_b)] as Array[NodePath]
	return [wall_a, wall_b]


func test_an_inset_block_collides_as_the_box_and_draws_the_box_less_what_its_partner_draws() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var walls := _two_walls(holder, true)
	var wall_a := walls[0] as InsetBlock
	await get_tree().physics_frame
	var shape := wall_a.body.get_child(0) as CollisionShape3D
	assert_eq((shape.shape as BoxShape3D).size, Vector3(4.0, 6.0, 1.0), "the collider is the whole box")
	var clipped := wall_a.clipped_rects(2, 1)
	assert_eq(clipped.size(), 1, "one rectangle of the + z face is not drawn")
	assert_eq(clipped[0], Rect2(0.0, 0.0, 1.5, 3.0), "it is the overlap with the partner's + z face: x 0 to 1.5, y 0 to 3 (the plane's (x, y))")
	assert_eq(wall_a.clipped_rects(2, 0).size(), 0, "the - z face has no partner in its plane")
	var mesh := wall_a.body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays := mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var front_area := 0.0
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		var normal := (c - a).cross(b - a).normalized()
		if is_equal_approx(a.z, 0.5) and is_equal_approx(b.z, 0.5) and is_equal_approx(c.z, 0.5) and normal.z > 0.9 and maxf(absf(a.x), maxf(absf(b.x), absf(c.x))) < 2.001:
			front_area += (b - a).cross(c - a).length() * 0.5
	assert_almost_eq(front_area, 4.0 * 6.0 - 1.5 * 3.0, 0.001, "the + z face is drawn everywhere but the overlap")


func test_the_clipped_face_keeps_its_strips_uv_where_it_is_cut() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var walls := _two_walls(holder, true)
	await get_tree().physics_frame
	var wall_a := walls[0] as InsetBlock
	var mesh := wall_a.body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays := mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var checked := 0
	for i in verts.size():
		if is_equal_approx(verts[i].z, 0.5) and absf(verts[i].x) < 1.999 and arrays[Mesh.ARRAY_NORMAL][i].z > 0.9:
			# The + z face's UV is metres: u from the left edge (x = -2) along it, v up from the bottom (y = -3).
			assert_almost_eq(uvs[i].x, verts[i].x + 2.0, 0.001, "u is the metres from the face's own left edge at %s" % verts[i])
			assert_almost_eq(uvs[i].y, verts[i].y + 3.0, 0.001, "v is the metres up the face at %s" % verts[i])
			checked += 1
	assert_gt(checked, 3, "cut corners were checked")


func test_the_scan_finds_a_pair_a_step_and_a_hole_and_passes_a_clean_yield() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var walls := _two_walls(holder, false)
	var wall_a := walls[0] as InsetBlock
	var wall_b := walls[1]
	await get_tree().physics_frame
	assert_eq(Scan.pairs(holder).size(), 1, "the two + z faces share a plane: a z-fight")
	# The first fix, and the regression verify-world-01 found: A's face 2 cm behind B's.
	wall_a.size = Vector3(4.0, 6.0, 0.98)
	wall_a.position = Vector3(0.0, 3.0, -0.01)
	await get_tree().physics_frame
	assert_eq(Scan.pairs(holder).size(), 0, "2 cm apart they no longer fight")
	var steps := Scan.steps(holder)
	assert_eq(steps.size(), 1, "but B's top edge makes a 2 cm step across A's face: the line the edge pass inks")
	assert_almost_eq(float(steps[0].exposed), 4.0 * 6.0 - 1.5 * 3.0, 0.01, "with the rest of A's face in view")
	# The fix: A yields the overlap to B.
	wall_a.size = Vector3(4.0, 6.0, 1.0)
	wall_a.position = Vector3(0.0, 3.0, 0.0)
	wall_a.yields_to = [wall_a.get_path_to(wall_b)] as Array[NodePath]
	await get_tree().physics_frame
	assert_eq(Scan.pairs(holder).size(), 0, "yielding the overlap leaves no two faces in one plane")
	assert_eq(Scan.holes(holder).size(), 0, "and no hole: B draws it")
	assert_eq(Scan.steps(holder).size(), 0, "and no step")
	# Two blocks that both yield leave a hole.
	var twin := InsetBlock.new()
	twin.size = wall_b.size
	twin.position = wall_b.position
	holder.add_child(twin)
	wall_b.queue_free()
	await get_tree().physics_frame
	wall_a.yields_to = [wall_a.get_path_to(twin)] as Array[NodePath]
	twin.yields_to = [twin.get_path_to(wall_a)] as Array[NodePath]
	await get_tree().physics_frame
	assert_gt(Scan.holes(holder).size(), 0, "two blocks that yield to each other leave the overlap undrawn: a hole")


func test_a_block_yields_only_what_a_kit_piece_really_draws() -> void:
	## A cornice is three boards, each standing out further than the one below, so its bounds' end face is a staircase: a block
	## that gave the whole rectangle up would leave a hole where the piece has no board.
	var holder := Node3D.new()
	add_child_autofree(holder)
	var piece := KitPiece.new()
	piece.kind = &"cornice"
	piece.size = Vector3(6.0, 0.6, 0.45)
	holder.add_child(piece)
	var block := InsetBlock.new()
	block.size = Vector3(2.0, 2.0, 2.0)
	block.position = Vector3(2.0, 0.0, 0.0)
	holder.add_child(block)
	block.yields_to = [block.get_path_to(piece)] as Array[NodePath]
	await get_tree().physics_frame
	var area := 0.0
	for rect in block.clipped_rects(0, 1):
		area += rect.get_area()
	assert_almost_eq(area, 0.45 * 0.2 + 0.30 * 0.2 + 0.15 * 0.2, 0.001, "the three boards' end caps (0.18 m2), not the bounds' 0.27 m2")
	assert_eq(block.clipped_rects(0, 1).size(), 3, "one rectangle for each board's end cap")


func test_the_boss_roofs_far_ground_is_not_solid_and_lies_below_the_street() -> void:
	var holder := Node.new()
	add_child_autofree(holder)
	var level := Snapshot.instantiate(Snapshot.LEVEL, holder)
	await get_tree().physics_frame
	var ground := level.get_node("Sections/BossRoof/Geometry/Ground") as LevelBlock
	assert_false(ground.solid, "it draws only, so no collider moved")
	var street := level.get_node("Sections/Street/Geometry/Floor") as LevelBlock
	assert_lt(ground.world_aabb().end.y, street.world_aabb().end.y - 0.1, "its top lies clear below the street's")


# --- The vfinal round's fix pass (VF2-WORLD) --------------------------------------------------------


## Every InsetBlock under `root`, in tree order.
func _inset_blocks(root: Node) -> Array[InsetBlock]:
	var out: Array[InsetBlock] = []
	for found in root.find_children("*", "InsetBlock", true, false):
		out.append(found as InsetBlock)
	return out


func test_trim_wins_a_plane_against_its_wall() -> void:
	## vfinal-world-03: the smaller trim block yielded to the bigger wall, so a jamb that shares its wall's plane showed brick where
	## 82bab12 showed the jamb's face. Now the wall takes the overlap out of its own face, and no jamb or lintel yields to a wall.
	var holder := Node.new()
	add_child_autofree(holder)
	var level := Snapshot.instantiate(Snapshot.LEVEL, holder)
	await get_tree().physics_frame
	var trim_blocks := 0
	for block in level.find_children("*", "LevelBlock", true, false):
		if not (String(block.name).contains("Jamb") or String(block.name).contains("Lintel")):
			continue
		trim_blocks += 1
		var inset := block as InsetBlock
		if inset == null:
			continue
		for path in inset.yields_to:
			var partner := inset.get_node(path)
			assert_true(partner is KitPiece or String(partner.name).contains("Jamb") or String(partner.name).contains("Lintel"),
					"%s (trim) yields only to a kit piece or to other trim, not to the wall %s" % [inset.get_path(), partner.get_path()])
	assert_gt(trim_blocks, 10, "the level has jambs and lintels")
	for trim_path in ["WarehouseJambs", "WarehouseJambs2", "WarehouseLintel", "DoorJambs5", "DoorLintel3", "DoorJambs"]:
		var trim := level.get_node("Sections/Street/Geometry/%s" % trim_path) as LevelBlock
		assert_false(trim is InsetBlock and _any_clip(trim as InsetBlock), "%s draws every face: it is not clipped by its wall" % trim_path)
	var wall := level.get_node("Sections/Street/Geometry/LeftWall4") as InsetBlock
	assert_true(wall.yields_to.has(wall.get_path_to(level.get_node("Sections/Street/Geometry/WarehouseJambs"))), "the wall beside the shutter yields its overlap to the jamb")
	var door_wall := level.get_node("Sections/Street/Geometry/RightWall5") as InsetBlock
	assert_true(door_wall.yields_to.has(door_wall.get_path_to(level.get_node("Sections/Street/Geometry/DoorJambs5"))), "and the wall at the door reveal to its jamb")


func _any_clip(block: InsetBlock) -> bool:
	for axis in 3:
		for side in 2:
			if not block.clipped_rects(axis, side).is_empty():
				return true
	return false


func test_the_solver_ranks_a_jamb_over_a_wall_whatever_their_sizes() -> void:
	var solver := (load("res://tools/solve_insets.gd") as GDScript).new() as Node
	autofree(solver)
	var wall := LevelBlock.new()
	wall.name = &"LeftWall4"
	var jamb := LevelBlock.new()
	jamb.name = &"WarehouseJambs"
	var other := LevelBlock.new()
	other.name = &"RightWall"
	autofree(wall)
	autofree(jamb)
	autofree(other)
	var big := {owner = wall, box = AABB(Vector3.ZERO, Vector3(10.0, 10.0, 1.0))}
	var small := {owner = jamb, box = AABB(Vector3.ZERO, Vector3(0.5, 3.0, 0.5))}
	var smaller_wall := {owner = other, box = AABB(Vector3.ZERO, Vector3(1.0, 1.0, 1.0))}
	assert_true(solver._beats(small, big), "the jamb wins against the bigger wall")
	assert_false(solver._beats(big, small), "and the wall does not win against it")
	assert_true(solver._beats(big, smaller_wall), "two walls: the bigger box wins, as before")


func _wall_mesh() -> ArrayMesh:
	return KitMesh.build(&"wall", Vector3(6.0, 4.0, 0.6))


## The triangles of `mesh` with a vertex more than `tolerance` out from the + z plane at `plane`.
func _beyond(mesh: ArrayMesh, plane: float, tolerance: float) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var beyond := false
			for k in 3:
				beyond = beyond or verts[indices[t + k]].z > plane + tolerance
			if beyond:
				count += 1
	return count


func test_clipping_a_whole_face_leaves_no_hollow_plinth_ledge() -> void:
	## vfinal-code-04: the plinth board (5 cm off a tall wall's brick) has a front, a top ledge and two end caps. The clip took only the
	## front, so a hollow 5 cm ledge stood in front of the partner's face: 4 triangles over a whole-face cut.
	var mesh := _wall_mesh()
	assert_gt(_beyond(mesh, 0.3, 0.004), 0, "the uncut wall has a plinth that stands out from its + z face")
	var cut := MeshClip.clip_box(mesh, Vector3(6.0, 4.0, 0.6), {MeshClip.key(2, 1): [Rect2(-3.0, -2.0, 6.0, 4.0)] as Array[Rect2]}, 0.06, 0.004)
	assert_eq(_beyond(cut, 0.3, 0.004), 0, "nothing stands in front of the cut face: the ledge and the end caps go with the front")


func test_a_part_cut_ledge_keeps_what_the_rectangle_does_not_cover() -> void:
	var mesh := _wall_mesh()
	var cut := MeshClip.clip_box(mesh, Vector3(6.0, 4.0, 0.6), {MeshClip.key(2, 1): [Rect2(-1.0, -2.0, 2.0, 1.0)] as Array[Rect2]}, 0.06, 0.004)
	var uncut_beyond := _beyond(mesh, 0.3, 0.004)
	assert_gt(_beyond(cut, 0.3, 0.004), 0, "the board outside the rectangle is still drawn, with its ledge and caps")
	assert_gt(uncut_beyond, 0, "the board is there to begin with")
	var inside := 0
	for surface in cut.get_surface_count():
		var arrays := cut.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var centre := (verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0
			if centre.z > 0.304 and centre.x > -0.99 and centre.x < 0.99 and centre.y > -1.99 and centre.y < -0.99:
				inside += 1
	assert_eq(inside, 0, "no board face is left inside the rectangle")


func test_no_clipped_block_of_the_level_or_the_rooms_has_an_orphan_standoff_face() -> void:
	for scene: String in [Snapshot.LEVEL, Snapshot.CROWD, Snapshot.TRAINING]:
		var holder := Node.new()
		add_child_autofree(holder)
		var root := Snapshot.instantiate(scene, holder)
		await get_tree().physics_frame
		var found := Scan.orphans(root)
		for item in found:
			gut.p(String(item.text))
		assert_eq(found.size(), 0, "%s: no clipped block leaves a hollow ledge in front of a rectangle it gave up" % scene)


func test_every_yields_to_of_the_level_resolves() -> void:
	## vfinal-code-05: a renamed block silently brought the z-fight back. Every path resolves with all sections built (the one that
	## crosses sections, the boss roof's fence to the roofs' curb, resolves there too).
	var holder := Node.new()
	add_child_autofree(holder)
	var level := Snapshot.instantiate(Snapshot.LEVEL, holder)
	await get_tree().physics_frame
	var checked := 0
	for block in _inset_blocks(level):
		for path in block.yields_to:
			assert_not_null(block.get_node_or_null(path), "%s yields to %s, which is a node" % [block.get_path(), path])
			checked += 1
		assert_eq(block.unresolved_yields().size(), 0, "%s has no dangling yield" % block.get_path())
	assert_gt(checked, 90, "the level's yields were listed")


func test_a_dangling_yield_is_found_and_a_cross_section_one_is_not() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var section := LevelSection.new()
	holder.add_child(section)
	var geometry := Node3D.new()
	geometry.name = &"Geometry"
	section.add_child(geometry)
	var block := InsetBlock.new()
	block.size = Vector3.ONE
	geometry.add_child(block)
	block.yields_to = [NodePath("../NoSuchWall"), NodePath("../../../Other/Geometry/Wall")] as Array[NodePath]
	await get_tree().physics_frame
	var dangling := block.unresolved_yields()
	assert_eq(dangling.size(), 1, "the renamed sibling is reported")
	assert_eq(String(dangling[0]), "../NoSuchWall", "and it is the sibling, not the path into another section")


func test_a_fence_in_front_of_a_wall_is_a_step_but_a_post_in_its_bar_is_not() -> void:
	## vfinal-code-06: every fence-look block and everything under a Barrier was exempt from steps(), which hid a fence that steps in
	## front of a wall. Now only a post against its bar, a curb or a barrier's panel is by design.
	var holder := Node3D.new()
	add_child_autofree(holder)
	var ground := LevelBlock.new()
	ground.size = Vector3(20.0, 1.0, 20.0)
	ground.position = Vector3(0.0, -0.5, 0.0)
	ground.look = &"floor"
	holder.add_child(ground)
	var wall := LevelBlock.new()
	wall.size = Vector3(4.0, 3.0, 1.0)
	wall.position = Vector3(0.0, 1.5, 0.0)
	holder.add_child(wall)
	var fence := LevelBlock.new()
	fence.look = &"fence"
	fence.size = Vector3(2.0, 1.0, 0.5)
	fence.position = Vector3(0.0, 0.5, 0.27)
	holder.add_child(fence)
	await get_tree().physics_frame
	var found := Scan.steps(holder)
	assert_gt(found.size(), 0, "a fence block whose face stands 20 mm in front of a wall's is a step the edge pass inks: %s" % [found])
	fence.queue_free()
	var bar := LevelBlock.new()
	bar.look = &"fence"
	bar.size = Vector3(2.0, 0.2, 0.2)
	bar.position = Vector3(6.0, 1.0, 0.0)
	holder.add_child(bar)
	var post := LevelBlock.new()
	post.look = &"fence"
	post.size = Vector3(0.2, 1.2, 0.18)
	post.position = Vector3(6.0, 0.6, 0.0)
	holder.add_child(post)
	await get_tree().physics_frame
	var posts: Array[Dictionary] = []
	for item in Scan.steps(holder):
		if String(item.text).contains("Rail") or (item.a.owner == post or item.b.owner == post):
			posts.append(item)
	assert_eq(posts.size(), 0, "a post that stands in its bar is by design")


func test_the_scan_reads_the_builds_coplanar_tolerance() -> void:
	var before := Scan._coplanar()
	assert_eq(before, Tuning.data.kit_coplanar_m, "one number for the clip and the scan")
	Tuning.data.kit_coplanar_m = before * 2.0
	assert_eq(Scan._coplanar(), before * 2.0, "tuning it moves the scan with the build")


func test_clipping_fails_loudly_on_an_array_it_does_not_carry() -> void:
	assert_eq(MeshClip.uncarried(_wall_mesh(), 0), 0, "the kit's meshes carry only what the clip carries")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	assert_ne(MeshClip.uncarried(mesh, 0) & Mesh.ARRAY_FORMAT_TEX_UV2, 0, "a UV2 is named, so clipping would push_error rather than drop it silently")


func test_a_clipped_block_keeps_the_kit_meshs_tangents() -> void:
	var mesh := _wall_mesh()
	var cut := MeshClip.clip_box(mesh, Vector3(6.0, 4.0, 0.6), {MeshClip.key(2, 1): [Rect2(-1.0, -2.0, 2.0, 1.0)] as Array[Rect2]}, 0.06, 0.004)
	var before := mesh.surface_get_arrays(0)
	var after := cut.surface_get_arrays(0)
	assert_eq((before[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() / 4, (before[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "the source has a tangent for each vertex")
	assert_eq((after[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() / 4, (after[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "so does the clipped copy")


func test_the_clip_leaves_no_zero_area_triangle() -> void:
	## vfinal-code-07: about 107 zero-area fan triangles (collinear points on a polygon's edge) came out of the level's clips.
	var holder := Node.new()
	add_child_autofree(holder)
	var level := Snapshot.instantiate(Snapshot.LEVEL, holder)
	await get_tree().physics_frame
	var degenerate := 0
	var checked := 0
	for block in _inset_blocks(level):
		if block.body == null:
			continue
		for found in block.body.find_children("*", "MeshInstance3D", true, false):
			var mesh := (found as MeshInstance3D).mesh
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for t in range(0, indices.size(), 3):
					var area := (verts[indices[t + 1]] - verts[indices[t]]).cross(verts[indices[t + 2]] - verts[indices[t]]).length() * 0.5
					checked += 1
					if area < MeshClip.MIN_AREA_M2:
						degenerate += 1
	assert_gt(checked, 1000, "the clipped meshes were read")
	assert_eq(degenerate, 0, "no triangle of the clipped blocks has no area")


func test_a_block_clips_a_piece_that_comes_later_in_the_tree() -> void:
	## vfinal-code-07: a block's `_ready` ran before a later sibling piece had built its mesh, so the clip found nothing. The piece now
	## builds on demand.
	var holder := Node3D.new()
	add_child_autofree(holder)
	var block := InsetBlock.new()
	block.size = Vector3(2.0, 2.0, 2.0)
	block.position = Vector3(2.0, 0.0, 0.0)
	holder.add_child(block)
	var dressing := Node3D.new()
	holder.add_child(dressing)
	var piece := KitPiece.new()
	piece.kind = &"cornice"
	piece.size = Vector3(6.0, 0.6, 0.45)
	dressing.add_child(piece)
	block.yields_to = [block.get_path_to(piece)] as Array[NodePath]
	await get_tree().physics_frame
	assert_eq(block.clipped_rects(0, 1).size(), 3, "the three boards' end caps are cut, though the piece is the block's later sibling")
	var early := InsetBlock.new()
	early.size = Vector3(2.0, 2.0, 2.0)
	early.position = Vector3(2.0, 0.0, 0.0)
	var late := KitPiece.new()
	late.kind = &"cornice"
	late.size = Vector3(6.0, 0.6, 0.45)
	var order := Node3D.new()
	add_child_autofree(order)
	order.add_child(early)
	early.yields_to = [NodePath("../Late")] as Array[NodePath]
	late.name = &"Late"
	order.add_child(late)
	await get_tree().physics_frame
	assert_eq(early.unresolved_yields().size(), 0, "a sibling added later is found")
	assert_eq(early.clipped_rects(0, 1).size(), 3, "and cut, whichever was built first")
