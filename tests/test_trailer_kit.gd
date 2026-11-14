extends GutTest
## Milestone 7, T15: the trailer look profile's kit. A second trim sheet and ground tile (tools/gen_trailer_kit.py) the profile
## selects through TrimSheet, with the same 16 strips as M6's; per-block variants (a stable hash of the block's position
## moves every face on the sheet) so no two walls or windows repeat; M6's sheet, meshes and colliders unchanged under the
## "m6" profile, and the colliders unchanged under "trailer".

const Snapshot := preload("res://tests/m6_collider_snapshot.gd")
const FIXTURE := "res://tests/fixtures/m6/m5_colliders.json"
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const SIZES := {&"wall": Vector3(11.5, 12.0, 2.0), &"window": Vector3(1.3, 1.9, 0.3), &"skyline": Vector3(20.0, 25.0, 54.0)}


func before_each() -> void:
	Tuning.reset_to_default()
	KitMesh.clear_cache()


func after_each() -> void:
	Tuning.reset_to_default()
	KitMesh.clear_cache()


func _trailer() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)


func _uvs(mesh: ArrayMesh) -> PackedVector2Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]


func test_the_two_tables_name_the_same_sixteen_strips() -> void:
	var m6 := TrimSheet.table()
	_trailer()
	var trailer := TrimSheet.table()
	assert_eq((trailer.strips as Array).size(), TrimSheet.ROWS)
	for i in TrimSheet.ROWS:
		var a: Dictionary = m6.strips[i]
		var b: Dictionary = trailer.strips[i]
		assert_eq(b.name, a.name, "row %d is the same strip" % i)
		assert_eq(b.index, a.index)
		assert_eq(b.scissor, a.scissor, "%s keeps its scissor flag" % a.name)
		assert_eq(b.ground, a.ground, "%s keeps its ground flag" % a.name)


func test_the_trailer_strips_fill_the_sheet_without_gaps_or_overlap() -> void:
	_trailer()
	var at := 0.0
	for entry: Dictionary in TrimSheet.table().strips:
		assert_almost_eq(float(entry.v0), at, 0.00001, "%s starts where the last one ended" % entry.name)
		at += float(entry.vh)
		assert_gt(float(entry.u_m), 0.0)
		assert_gt(float(entry.period_m), 0.0)
	assert_almost_eq(at, 1.0, 0.00001, "the strips fill the 2048 px")


func test_the_profile_selects_the_sheets_and_flipping_back_restores_the_m6_ones() -> void:
	var trim := ToonMaterials.trim()
	var wire := ToonMaterials.trim_scissor()
	KitMesh.build(&"slab", Vector3.ONE)
	var m6_tex: Texture2D = trim.get_shader_parameter(&"trim_tex")
	var m6_ground: Texture2D = trim.get_shader_parameter(&"ground_tex")
	var m6_rows: PackedVector4Array = trim.get_shader_parameter(&"strips")
	assert_eq(m6_tex.resource_path, TrimSheet.SHEET_PATH)
	_trailer()
	for material: ShaderMaterial in [trim, wire]:
		assert_eq((material.get_shader_parameter(&"trim_tex") as Texture2D).resource_path, TrimSheet.TRAILER_SHEET_PATH)
		assert_eq((material.get_shader_parameter(&"ground_tex") as Texture2D).resource_path, TrimSheet.TRAILER_GROUND_PATH)
	assert_ne(trim.get_shader_parameter(&"strips"), m6_rows, "the strip rows are the trailer's")
	assert_eq(TrimSheet.texture().get_width(), 2048)
	assert_eq(TrimSheet.ground_texture().get_width(), 2048)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_same(trim.get_shader_parameter(&"trim_tex"), m6_tex)
	assert_same(trim.get_shader_parameter(&"ground_tex"), m6_ground)
	assert_eq(trim.get_shader_parameter(&"strips"), m6_rows)


func test_m6_meshes_ignore_the_variant_and_stay_the_same_object() -> void:
	var plain := KitMesh.build(&"wall", Vector3(4.0, 5.0, 2.0))
	assert_same(KitMesh.build(&"wall", Vector3(4.0, 5.0, 2.0), 5), plain, "no variation under M6")
	assert_eq(TrimSheet.variant_for(Vector3(1.0, 2.0, 3.0)), -1)
	var uv := _uvs(plain)
	assert_eq(uv[0], Vector2.ZERO, "M6's UVs start at the corner, in metres")


func test_variants_are_stable_and_spread_over_the_street() -> void:
	_trailer()
	var seen := {}
	for z in 60:
		var pos := Vector3(7.0, 5.0, -1.0 - float(z) * 1.7)
		var v := TrimSheet.variant_for(pos)
		assert_eq(TrimSheet.variant_for(pos), v, "the same position, the same variant")
		assert_true(v >= 0 and v < Tuning.data.trailer_kit_variants)
		seen[v] = true
	assert_gte(seen.size(), 6, "sixty blocks take at least six of the variants")


func test_a_variant_moves_the_faces_on_the_sheet() -> void:
	_trailer()
	var wall := SIZES[&"wall"] as Vector3
	var a := KitMesh.build(&"wall", wall, 0)
	var b := KitMesh.build(&"wall", wall, 1)
	assert_ne(a, b, "each variant is its own mesh")
	assert_same(KitMesh.build(&"wall", wall, 0), a, "cached per variant")
	assert_ne(_uvs(a), _uvs(b), "another variant, other UVs")
	assert_eq(KitMesh.triangle_count(a), KitMesh.triangle_count(b))
	assert_eq(a.get_aabb(), b.get_aabb(), "the shape is the same")
	# brick covers its own u_m of U on the trailer sheet (12 m since G3): a metre of face is that much less than M6's 4 m tile gave
	var plain := KitMesh.build(&"wall", wall)
	var uv := _uvs(plain)
	var spread := absf(uv[1].x - uv[0].x)
	var u_m := float(TrimSheet.strip(&"brick").u_m)
	assert_almost_eq(spread, wall.x * Tuning.data.kit_trim_m_per_tile / u_m, 0.01, "a face's U runs at 4 / u_m of the metres: one repeat is u_m metres")


func test_window_panes_land_on_whole_cells_of_the_glass_strip() -> void:
	_trailer()
	var cells := {}
	for variant in 12:
		for face in 4:
			var moved := TrimSheet.variation(&"glass", variant, face)
			var u := float(moved.u)
			assert_almost_eq(u, roundf(u), 0.0001, "a pane starts on a cell edge")
			assert_false(bool(moved.flip), "a pane is never mirrored")
			assert_eq(float(moved.v), 0.0)
			cells[roundi(u)] = true
	assert_gte(cells.size(), 4, "lit and dark panes both come up across the variants")


func test_variation_is_deterministic_and_keeps_the_chainlink_lattice() -> void:
	_trailer()
	assert_eq(TrimSheet.variation(&"brick", 3, 2), TrimSheet.variation(&"brick", 3, 2))
	assert_ne(TrimSheet.variation(&"brick", 3, 2), TrimSheet.variation(&"brick", 4, 2))
	var wire := TrimSheet.variation(&"chainlink", 7, 1)
	assert_false(bool(wire.flip))
	assert_eq(wire.tint, Color.WHITE)
	var none := TrimSheet.variation(&"brick", -1, 0)
	assert_eq(float(none.u), 0.0)
	assert_eq(none.tint, Color.WHITE)


func test_the_tint_stays_near_white() -> void:
	_trailer()
	var jitter := Tuning.data.trailer_kit_tint_jitter
	for variant in 12:
		var tint: Color = TrimSheet.variation(&"brick", variant, 0).tint
		for channel in [tint.r, tint.g, tint.b]:
			assert_almost_eq(float(channel), 1.0, jitter * 2.0 + 0.001)


func test_the_street_flips_without_moving_a_collider() -> void:
	var holder := Node.new()
	add_child_autofree(holder)
	var node := Snapshot.instantiate(LEVEL_PATH, holder)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := Snapshot.snapshot(node)
	_trailer()
	await get_tree().physics_frame
	var trailer := Snapshot.snapshot(node)
	assert_eq(trailer.size(), before.size())
	var keys := {}
	for entry: Dictionary in before:
		keys[Snapshot.key(entry)] = true
	for entry: Dictionary in trailer:
		assert_true(keys.has(Snapshot.key(entry)), "a collider moved under the trailer profile: %s" % Snapshot.key(entry))
	# the blocks drew the trailer's meshes (a variant each), and flipping back draws M6's
	var blocks := node.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is LevelBlock)
	var variants := {}
	for block: LevelBlock in blocks:
		if block._mesh_node != null and block.module == &"":
			variants[block._variant()] = true
	assert_gte(variants.size(), 2, "the street's blocks take different variants")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await get_tree().physics_frame
	var back := Snapshot.snapshot(node)
	assert_eq(back.size(), before.size())


func test_the_street_stretch_has_no_two_neighbouring_walls_on_the_same_variant() -> void:
	_trailer()
	var a := TrimSheet.variant_for(Vector3(7.0, 5.0, 1.7))
	var b := TrimSheet.variant_for(Vector3(7.0, 5.0, -6.2))
	var c := TrimSheet.variant_for(Vector3(7.0, 5.0, -18.0))
	assert_true(a != b or b != c, "the right wall's first blocks are not all alike")


# --- G3: the street's surfaces ------------------------------------------------------------------------


func _alpha_share(path: String, rect: Rect2i) -> float:
	var image: Image = (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var count := 0
	var total := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			total += 1
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return float(count) / float(maxi(total, 1))


func test_the_trailer_walls_are_mostly_flat_with_a_few_drawn_hints() -> void:
	_trailer()
	var brick := TrimSheet.strip(&"brick")
	var rect := Rect2i(0, roundi(float(brick.v0) * 2048.0), 2048, roundi(float(brick.vh) * 2048.0))
	var share := _alpha_share(TrimSheet.TRAILER_SHEET_PATH, rect)
	assert_gt(share, 0.004, "some ink: cracks, a pipe, a few brick outlines")
	assert_lt(share, 0.06, "but the wall is not an all-over pattern of ink")
	assert_gte(float(brick.u_m), 12.0, "a long strip, so neighbouring walls differ")


func _runs(image: Image, y: int) -> Array[int]:
	## The lengths (px) of the opaque runs along row `y`.
	var out: Array[int] = []
	var length := 0
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.5:
			length += 1
		elif length > 0:
			out.append(length)
			length = 0
	if length > 0:
		out.append(length)
	return out


func test_the_fence_card_is_uneven_boards_with_gaps_not_a_lattice() -> void:
	var path := KitMesh.FENCE_CARD_PATH
	var share := _alpha_share(path, Rect2i(0, 0, 2048, 1024))
	assert_gt(share, 0.45, "boards, rails and posts are there")
	assert_lt(share, 0.85, "and there are gaps")
	# the first post straddles the wrap, so the card tiles along the fence without a cut board
	var edge := _alpha_share(path, Rect2i(0, 150, 20, 700)) + _alpha_share(path, Rect2i(2028, 150, 20, 700))
	assert_gt(edge, 1.8, "the post covers the wrap")
	# no pitch: along a row the board widths differ (a lattice or a picket fence repeats one width)
	var image: Image = (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	for y in [80, 400, 900]:
		var runs := _runs(image, y)
		assert_gte(runs.size(), 8, "a run of boards at y=%d" % y)
		var mean := 0.0
		for r in runs:
			mean += float(r)
		mean /= float(runs.size())
		var spread := 0.0
		for r in runs:
			spread += (float(r) - mean) * (float(r) - mean)
		spread = sqrt(spread / float(runs.size()))
		assert_gt(spread / mean, 0.4, "board widths are uneven at y=%d" % y)


func test_the_far_facade_has_no_even_window_row() -> void:
	_trailer()
	var strip := TrimSheet.strip(&"facade")
	var image: Image = (load(TrimSheet.TRAILER_SHEET_PATH) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var y0 := roundi(float(strip.v0) * 2048.0)
	var rows := roundi(float(strip.vh) * 2048.0)
	# the windows' ink outlines, by column: runs of columns that hold ink are windows, the runs between them are wall
	var ink_cols: Array[bool] = []
	for x in 2048:
		var has := false
		for y in range(y0, y0 + rows, 2):
			if image.get_pixel(x, y).a > 0.5:
				has = true
				break
		ink_cols.append(has)
	var widths: Array[float] = []
	var gaps: Array[float] = []
	var length := 0
	var state := ink_cols[0]
	for has in ink_cols:
		if has == state:
			length += 1
		else:
			(widths if state else gaps).append(float(length))
			state = has
			length = 1
	assert_gte(widths.size(), 10, "a good number of windows along the strip")
	for series: Array[float] in [widths, gaps]:
		var mean := 0.0
		for v in series:
			mean += v
		mean /= float(series.size())
		var spread := 0.0
		for v in series:
			spread += (v - mean) * (v - mean)
		spread = sqrt(spread / float(series.size()))
		assert_gt(spread / mean, 0.3, "windows and the wall between them are uneven: no pitch")


func test_the_fence_card_replaces_the_lattice_under_trailer_only() -> void:
	var wire := ToonMaterials.trim_scissor()
	KitMesh.build(&"chainlink", Vector3(6.0, 3.5, 0.2))
	assert_eq(float(wire.get_shader_parameter(&"fence_on")), 0.0, "M6 draws the lattice")
	_trailer()
	assert_eq(float(wire.get_shader_parameter(&"fence_on")), 1.0, "a flip to the trailer switches the card on")
	assert_not_null(wire.get_shader_parameter(&"fence_tex"))
	var card: Vector2 = wire.get_shader_parameter(&"fence_card")
	assert_eq(card.x, Tuning.data.trailer_fence_card_w_m)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(float(wire.get_shader_parameter(&"fence_on")), 0.0, "and back off again")


func test_the_fence_card_sits_on_the_top_of_the_fence() -> void:
	_trailer()
	var height := 3.5
	var mesh := KitMesh.build(&"chainlink", Vector3(6.0, height, 0.2), 3)
	var wire_surface := mesh.get_surface_count() - 1
	var uvs: PackedVector2Array = mesh.surface_get_arrays(wire_surface)[Mesh.ARRAY_TEX_UV]
	var top := -INF
	for uv in uvs:
		top = maxf(top, uv.y)
	assert_almost_eq(top, Tuning.data.trailer_fence_card_h_m, 0.01, "the face's top is the card's top")


func test_a_tall_trailer_facade_is_bands_that_do_not_repeat_a_window_row() -> void:
	var size: Vector3 = SIZES[&"skyline"]
	var m6 := KitMesh.build(&"skyline", size)
	_trailer()
	var mesh := KitMesh.build(&"skyline", size, 2)
	assert_gt(KitMesh.triangle_count(mesh), KitMesh.triangle_count(m6), "stacked bands, not one box")
	assert_lte(KitMesh.triangle_count(mesh), KitMesh.MAX_TRIANGLES)
	var period := TrimSheet.period_m(&"facade")
	var uvs := _uvs(mesh)
	# The first band's +Z side face starts at V 0 and every band's does (the strip does not vary V), but their U starts differ.
	var starts := {}
	for i in range(0, uvs.size(), 4):
		if is_zero_approx(uvs[i].y) and is_equal_approx(uvs[i + 2].y, period) and not is_equal_approx(uvs[i].x, uvs[i + 1].x):
			starts[snappedf(uvs[i].x, 0.001)] = true
	assert_gte(starts.size(), 3, "the bands' faces start at different places along the strip")


func test_the_street_props_lift_under_the_trailer_profile_only() -> void:
	var car := preload("res://game/level/props/car.tscn").instantiate() as Node3D
	add_child_autofree(car)
	await wait_physics_frames(2)
	var prop := car.get_node("TrailerProp") as TrailerProp
	var art := car as StaticArt
	assert_eq(art.material.get_shader_parameter(&"albedo"), Color.WHITE, "M6: the palette as it is")
	_trailer()
	var lifted: Color = art.material.get_shader_parameter(&"albedo")
	assert_almost_eq(lifted.r, prop.tint.r * Tuning.data.trailer_prop_lift, 0.001)
	assert_gt(lifted.g, 1.0, "a lifted fill")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(art.material.get_shader_parameter(&"albedo"), Color.WHITE, "and back to white")
