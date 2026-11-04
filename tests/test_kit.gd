extends GutTest
## The environment kit (Milestone 6, KIT; plan D1, D2, D9-D13): the modules (`KitMesh`), their one
## shared trim material, the trim sheet's pixels against the look bible, `LevelBlock`'s module and
## `draw_box`, the dressing and the prop spots, the barrier panels and the stair flight, the
## graybox switch, and `section_entered`. The colliders are held to M5 in test_m6_colliders.gd.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const STREET_PATH := "res://game/level/mission1/street.tscn"

## The sizes (m) each kind is built at in the level, from the census (docs/milestones/M6-codemap/
## level-env.md §1): the longest walls and slabs, the skyline and the ground planes, the flights.
const CENSUS := {
	&"wall": [Vector3(17.5, 12.0, 2.0), Vector3(1.0, 12.0, 2.0), Vector3(2.0, 12.0, 3.6)],
	&"floor": [Vector3(12.0, 1.0, 56.0), Vector3(74.7, 0.5, 75.0), Vector3(2.5, 1.0, 2.5)],
	&"slab": [Vector3(3.0, 7.6, 2.9), Vector3(6.0, 4.5, 4.5), Vector3(10.0, 0.5, 14.0)],
	&"slab_dark": [Vector3(3.0, 4.4, 0.2), Vector3(0.4, 9.0, 3.8)],
	&"deck": [Vector3(14.0, 0.5, 24.0), Vector3(10.0, 0.5, 20.0)],
	&"curb": [Vector3(0.3, 0.25, 14.0)],
	&"crate": [Vector3(1.6, 1.4, 2.6), Vector3(3.0, 2.3, 1.8), Vector3(1.0, 1.0, 1.0)],
	&"skyline": [Vector3(20.0, 25.0, 54.0), Vector3(74.7, 0.5, 75.0), Vector3(24.0, 14.0, 1.0)],
	&"rail": [Vector3(0.1, 0.1, 8.75), Vector3(0.1, 0.1, 1.8)],
	&"post": [Vector3(0.12, 1.0, 0.12)],
	&"housing": [Vector3(6.4, 0.5, 0.6)],
	&"shutter": [Vector3(6.0, 3.5, 0.18), Vector3(3.0, 3.5, 0.18)],
	&"chainlink": [Vector3(6.0, 3.5, 0.2), Vector3(9.0, 4.0, 0.2)],
	&"gate": [Vector3(6.0, 3.5, 0.3), Vector3(4.0, 3.5, 0.3)],
	&"door_frame": [Vector3(2.86, 3.66, 0.2), Vector3(6.6, 5.6, 0.2)],
	&"window": [Vector3(1.3, 1.9, 0.3), Vector3(3.0, 2.4, 0.3)],
	&"cornice": [Vector3(20.5, 0.6, 0.45), Vector3(3.0, 0.6, 0.45)],
	&"stair_flight": [Vector3(3.0, 4.5, 7.5), Vector3(3.0, 3.5, 7.0), Vector3(3.0, 1.0, 2.0)],
}


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"kit_draw_graybox", false)
	TimeController.clear()


func after_each() -> void:
	Tuning.set_value(&"kit_draw_graybox", false)
	Tuning.reset_to_default()


# --- The modules --------------------------------------------------------------------------------


func test_every_kind_is_in_the_census_and_the_plan_has_its_kinds() -> void:
	for kind: StringName in KitMesh.KINDS:
		assert_true(CENSUS.has(kind), "%s has census sizes" % kind)
	for kind: StringName in [&"wall", &"floor", &"slab", &"deck", &"curb", &"door_frame", &"window", &"shutter",
			&"rail", &"post", &"stair_flight", &"cornice", &"chainlink", &"gate", &"crate", &"skyline"]:
		assert_true(KitMesh.KINDS.has(kind), "the plan's kind %s" % kind)


func test_every_kind_is_within_5000_triangles_at_the_census_sizes() -> void:
	for kind: StringName in CENSUS:
		for size: Vector3 in CENSUS[kind]:
			var mesh := KitMesh.build(kind, size)
			assert_not_null(mesh, "%s at %s builds" % [kind, size])
			assert_gt(KitMesh.triangle_count(mesh), 0, "%s at %s has triangles" % [kind, size])
			assert_lte(KitMesh.triangle_count(mesh), KitMesh.MAX_TRIANGLES, "%s at %s is within the module budget" % [kind, size])
			assert_eq(mesh.get_surface_count(), 1, "%s is one surface" % kind)


func test_box_and_unknown_kinds_are_not_modules() -> void:
	assert_null(KitMesh.build(&"box", Vector3.ONE))
	assert_null(KitMesh.build(&"", Vector3.ONE))
	assert_null(KitMesh.build(&"no_such_kind", Vector3.ONE))


func test_a_mesh_is_cached_per_kind_and_size() -> void:
	var a := KitMesh.build(&"wall", Vector3(4.0, 5.0, 2.0))
	assert_same(KitMesh.build(&"wall", Vector3(4.0, 5.0, 2.0)), a)
	assert_not_same(KitMesh.build(&"wall", Vector3(4.5, 5.0, 2.0)), a)


## The UVs are in metres: on every triangle the UV area equals the surface area, so a wall of any
## length is the strip repeated and nothing is stretched.
func test_uvs_are_in_metres_on_every_kind() -> void:
	for kind: StringName in CENSUS:
		var size: Vector3 = (CENSUS[kind] as Array)[0]
		var arrays := KitMesh.build(kind, size).surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_eq(verts.size(), uvs.size(), "%s: a UV per vertex" % kind)
		var bad := 0
		for t in indices.size() / 3:
			var a := indices[t * 3]
			var b := indices[t * 3 + 1]
			var c := indices[t * 3 + 2]
			var area := (verts[b] - verts[a]).cross(verts[c] - verts[a]).length() * 0.5
			var uv_area := absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) * 0.5
			if absf(area - uv_area) > 0.0005 * maxf(area, 1.0):
				bad += 1
		assert_eq(bad, 0, "%s: every triangle's UV area is its surface area in m2" % kind)


func test_a_longer_wall_has_longer_uvs_not_denser_ones() -> void:
	var short := _uv_extent(KitMesh.build(&"slab", Vector3(3.0, 4.0, 5.0)), Vector3.BACK)
	var long := _uv_extent(KitMesh.build(&"slab", Vector3(6.0, 4.0, 5.0)), Vector3.BACK)
	assert_eq(short, Vector2(3.0, 4.0), "the +Z face of a 3 x 4 m face spans 3 x 4 m of UV")
	assert_eq(long, Vector2(6.0, 4.0), "and doubles with the length")


## The UV extent of the faces of `mesh` whose normal is `normal`.
func _uv_extent(mesh: ArrayMesh, normal: Vector3) -> Vector2:
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in normals.size():
		if normals[i].normalized().dot(normal) > 0.99:
			low = low.min(uvs[i])
			high = high.max(uvs[i])
	return high - low


func test_every_kind_is_centred_on_its_box() -> void:
	for kind: StringName in [&"wall", &"floor", &"slab", &"deck", &"crate", &"rail", &"shutter", &"chainlink", &"window", &"door_frame"]:
		var size: Vector3 = (CENSUS[kind] as Array)[0]
		var box := KitMesh.build(kind, size).get_aabb()
		var centre := box.position + box.size * 0.5
		assert_lt(absf(centre.y), maxf(size.y * 0.1, 0.1), "%s: its box is centred up and down" % kind)
		assert_lt(absf(centre.x), maxf(size.x * 0.1, 0.1), "%s: and across" % kind)


# --- The one material ---------------------------------------------------------------------------


func test_every_module_is_on_the_one_shared_trim_material() -> void:
	var trim := ToonMaterials.trim()
	assert_same(ToonMaterials.trim(), trim, "trim() is one object")
	assert_eq(trim.shader, load(ToonMaterials.TRIM_SHADER))
	for kind: StringName in CENSUS:
		var mesh := KitMesh.build(kind, (CENSUS[kind] as Array)[0])
		assert_same(mesh.surface_get_material(0), trim, "%s draws on the shared material" % kind)
	assert_same(KitMesh.build_stairs(3.0, 4.5, 7.5, 25).surface_get_material(0), trim)


func test_the_trim_material_keeps_a_flat_albedo_tint_and_the_sheets_table() -> void:
	var trim := ToonMaterials.trim()
	assert_eq(trim.get_shader_parameter(&"albedo"), Color.WHITE, "a tint a test can read")
	var rows: PackedVector4Array = trim.get_shader_parameter(&"strips")
	assert_eq(rows.size(), TrimSheet.ROWS, "the shader's strip table")
	assert_not_null(trim.get_shader_parameter(&"trim_tex"))
	assert_eq(trim.get_shader_parameter(&"edge_tag"), 1.0, "the edge pass draws its lines on a module")


func test_the_trim_material_follows_the_tunables() -> void:
	var trim := ToonMaterials.trim()
	Tuning.set_value(&"kit_trim_m_per_tile", 8.0)
	assert_eq(trim.get_shader_parameter(&"tile_m"), 8.0)
	Tuning.set_value(&"look_trim_ink_cut", 0.4)
	assert_eq(trim.get_shader_parameter(&"ink_cut"), 0.4)
	Tuning.set_value(&"look_trim_lod_cap", 3.0)
	assert_eq(trim.get_shader_parameter(&"lod_cap"), 3.0)
	assert_eq(trim.get_shader_parameter(&"spec_strength"), 0.0, "matte, like the room")
	assert_eq(trim.get_shader_parameter(&"mid_level"), 1.0, "two bands, like the room")
	assert_eq(trim.get_shader_parameter(&"rim_strength"), 0.0, "no rim on the world")


# --- The sheet ----------------------------------------------------------------------------------


func test_the_sheet_is_2048_with_mipmaps_and_every_strip_is_in_the_table() -> void:
	var texture := TrimSheet.texture()
	assert_not_null(texture)
	assert_eq(texture.get_width(), 2048)
	assert_eq(texture.get_height(), 2048)
	var import := FileAccess.get_file_as_string(TrimSheet.SHEET_PATH + ".import")
	assert_true(import.contains("mipmaps/generate=true"), "imported with mipmaps")
	assert_true(import.contains("fix_alpha_border=false"), "the alpha is the ink mask: not fixed")
	var table := TrimSheet.table()
	assert_eq((table.strips as Array).size(), 16)
	var seen := {}
	for entry: Dictionary in table.strips:
		assert_false(seen.has(int(entry.index)), "row %d once" % int(entry.index))
		seen[int(entry.index)] = true
		assert_gt(float(entry.period_m), 0.0)
	for strip_name: StringName in [&"brick", &"plaster", &"concrete", &"asphalt", &"kerb", &"roof_tar", &"gravel",
			&"metal", &"shutter", &"chainlink", &"crate", &"trim", &"ink"]:
		assert_false(TrimSheet.strip(strip_name).is_empty(), "the plan's strip %s" % strip_name)
	assert_true(bool(TrimSheet.strip(&"chainlink").scissor), "the chain-link is alpha scissor")


## The sheet's own pixels against the look bible (replacing the flat-albedo reading of the rooms'
## boxes: a trim material has no one colour): every painted pixel of every strip but the ink is at
## most 0.30 saturated and 0.25 to 0.6 in value, and none is in the red band. The ink (the alpha
## mask) is the one ink, and the ink strip is all of it.
func test_every_painted_pixel_of_the_sheet_is_inside_the_environment_band() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TrimSheet.SHEET_PATH))
	assert_not_null(image)
	image.convert(Image.FORMAT_RGBA8)
	var checked := 0
	var worst_s := 0.0
	var lowest_v := 1.0
	var highest_v := 0.0
	for entry: Dictionary in TrimSheet.table().strips:
		if bool(entry.ink_only):
			continue
		var scissor := bool(entry.scissor)
		var y0 := int(entry.index) * int(TrimSheet.table().row_px)
		for y in range(y0, y0 + int(TrimSheet.table().row_px), 2):
			for x in range(0, 2048, 2):
				var c := image.get_pixel(x, y)
				if not scissor and c.a > 0.5:
					continue  # ink
				checked += 1
				worst_s = maxf(worst_s, c.s)
				lowest_v = minf(lowest_v, c.v)
				highest_v = maxf(highest_v, c.v)
	assert_gt(checked, 500000, "the strips' pixels were read")
	assert_lte(worst_s, 0.30 + 0.005, "saturation at most 0.30 (the worst pixel %.3f)" % worst_s)
	assert_gte(lowest_v, 0.25 - 0.005, "value at least 0.25 (the darkest pixel %.3f)" % lowest_v)
	assert_lte(highest_v, 0.6 + 0.005, "value at most 0.6 (the brightest pixel %.3f)" % highest_v)


func test_the_ink_in_the_sheet_is_the_one_ink() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TrimSheet.SHEET_PATH))
	image.convert(Image.FORMAT_RGBA8)
	var brick := int(TrimSheet.index(&"concrete")) * 128
	var found := 0
	for y in range(brick, brick + 128):
		for x in range(0, 2048):
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				found += 1
				assert_lt(absf(c.r - HudStyle.INK.r) + absf(c.g - HudStyle.INK.g) + absf(c.b - HudStyle.INK.b), 0.03, "ink pixels are HudStyle.INK")
				return
	assert_gt(found, 0, "the concrete strip has ink joints")


## No ink within a few px of a strip's top or bottom edge or of U = 0, so the border of a face (which
## the edge pass draws) is never doubled by a painted line.
func test_no_ink_on_a_strips_border() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TrimSheet.SHEET_PATH))
	image.convert(Image.FORMAT_RGBA8)
	for entry: Dictionary in TrimSheet.table().strips:
		if bool(entry.ink_only) or bool(entry.scissor):
			continue
		var y0 := int(entry.index) * 128
		var bad := 0
		for x in 2048:
			for y in [y0, y0 + 1, y0 + 2, y0 + 125, y0 + 126, y0 + 127]:
				if image.get_pixel(x, y).a > 0.5:
					bad += 1
		for y in range(y0, y0 + 128):
			for x in [0, 1, 2]:
				if image.get_pixel(x, y).a > 0.5:
					bad += 1
		assert_eq(bad, 0, "%s: no ink on the strip's border" % entry.name)


# --- LevelBlock: module and draw_box -------------------------------------------------------------


func _block(look: StringName, size: Vector3, module: StringName = &"", draw_box: bool = true, solid: bool = true) -> LevelBlock:
	var block := LevelBlock.new()
	block.size = size
	block.look = look
	block.module = module
	block.draw_box = draw_box
	block.solid = solid
	add_child_autofree(block)
	return block


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(found as MeshInstance3D)
	return out


func test_a_block_draws_the_module_its_look_derives() -> void:
	for look: StringName in LevelBlock.LOOKS:
		assert_true(LevelBlock.MODULE_FOR_LOOK.has(look), "%s derives a module" % look)
		var block := _block(look, Vector3(2.0, 3.0, 4.0))
		var meshes := _meshes(block)
		assert_eq(meshes.size(), 1, "%s: one mesh" % look)
		assert_true(meshes[0].mesh is ArrayMesh, "%s: a kit mesh, not a box" % look)
		assert_same(meshes[0].mesh, KitMesh.build(LevelBlock.MODULE_FOR_LOOK[look], Vector3(2.0, 3.0, 4.0)))


func test_an_explicit_module_wins_and_box_is_m5s_box() -> void:
	var skyline := _block(&"wall", Vector3(20.0, 25.0, 54.0), &"skyline", true, false)
	assert_same(_meshes(skyline)[0].mesh, KitMesh.build(&"skyline", Vector3(20.0, 25.0, 54.0)))
	var plain := _block(&"wall", Vector3(2.0, 3.0, 4.0), &"box")
	assert_true(_meshes(plain)[0].mesh is BoxMesh, "&\"box\" is the plain coloured box")


func test_draw_box_hides_only_the_mesh() -> void:
	var drawn := _block(&"wall", Vector3(2.0, 3.0, 4.0))
	var hidden := _block(&"wall", Vector3(2.0, 3.0, 4.0), &"", false)
	assert_eq(_meshes(drawn).size(), 1)
	assert_eq(_meshes(hidden).size(), 0, "no mesh")
	for block: LevelBlock in [drawn, hidden]:
		assert_not_null(block.body, "the collider stays")
		assert_eq(block.body.collision_layer, CombatTypes.bit(CombatTypes.LAYER_WORLD))
		var shape := block.body.get_child(0) as CollisionShape3D
		assert_eq((shape.shape as BoxShape3D).size, Vector3(2.0, 3.0, 4.0), "the collider is the block's box")
		assert_eq(block.world_aabb(), AABB(block.global_position - block.size * 0.5, block.size))
	var paint := _block(&"wall", Vector3(2.0, 3.0, 4.0), &"", false, false)
	assert_eq(_meshes(paint).size(), 0, "a drawn-only block with draw_box off draws nothing")


func test_the_module_wears_no_collider_of_its_own() -> void:
	var block := _block(&"prop", Vector3(1.6, 1.4, 2.3))
	var bodies := block.find_children("*", "CollisionObject3D", true, false)
	assert_eq(bodies.size(), 1, "the block's Body, nothing from the art")


func test_a_prop_module_wears_the_hull_and_a_wall_does_not() -> void:
	var crate := _meshes(_block(&"prop", Vector3(1.0, 1.0, 1.0)))[0]
	assert_not_null(crate.material_overlay, "a crate is inked like a prop")
	var wall := _meshes(_block(&"wall", Vector3(1.0, 1.0, 1.0)))[0]
	assert_null(wall.material_overlay)


func test_the_graybox_switch_puts_every_block_back_to_the_box() -> void:
	Tuning.set_value(&"kit_draw_graybox", true)
	var wall := _block(&"wall", Vector3(2.0, 3.0, 4.0))
	assert_true(_meshes(wall)[0].mesh is BoxMesh, "M5's box")
	var hidden := _block(&"wall", Vector3(2.0, 3.0, 4.0), &"", false)
	assert_eq(_meshes(hidden).size(), 1, "draw_box is the kit's: the graybox draws the box")
	var floor_block := _block(&"floor", Vector3(2.0, 1.0, 4.0))
	assert_eq(((_meshes(floor_block)[0].mesh as BoxMesh).material as ShaderMaterial).shader, load(ToonMaterials.GRID_SHADER), "the grid floor")


# --- RoomKit's hook (the code-built rooms) ------------------------------------------------------


func test_add_box_keeps_the_collider_and_draws_the_art() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var plain := RoomKit.add_box(parent, Vector3.ZERO, Vector3(2.0, 2.0, 2.0), RoomKit.flat_material(Color(0.4, 0.4, 0.4)))
	var kit := RoomKit.add_box(parent, Vector3(4.0, 0.0, 0.0), Vector3(2.0, 2.0, 2.0), null, null, &"wall")
	var boxed := RoomKit.add_box(parent, Vector3(8.0, 0.0, 0.0), Vector3(2.0, 2.0, 2.0), RoomKit.flat_material(Color(0.4, 0.4, 0.4)), null, &"box")
	assert_true((plain.get_child(1) as MeshInstance3D).mesh is BoxMesh)
	assert_true((kit.get_child(1) as MeshInstance3D).mesh is ArrayMesh, "a kit kind draws the module")
	assert_true((boxed.get_child(1) as MeshInstance3D).mesh is BoxMesh, "&\"box\" is M5's look")
	for body: StaticBody3D in [plain, kit, boxed]:
		assert_eq(body.collision_layer, CombatTypes.bit(CombatTypes.LAYER_WORLD))
		assert_eq(((body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size, Vector3(2.0, 2.0, 2.0), "the same collider")
	assert_eq(RoomKit.add_box(parent, Vector3.ZERO, Vector3.ONE).get_child_count(), 1, "no material and no art: collider only, as before")


func test_add_visual_box_takes_an_art_kind_too() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var mesh := RoomKit.add_visual_box(parent, Vector3.ZERO, Vector3(2.0, 2.0, 2.0), RoomKit.flat_material(Color(0.4, 0.4, 0.4)), null, &"slab")
	assert_true(mesh.mesh is ArrayMesh)
	Tuning.set_value(&"kit_draw_graybox", true)
	var gray := RoomKit.add_visual_box(parent, Vector3.ZERO, Vector3(2.0, 2.0, 2.0), RoomKit.flat_material(Color(0.4, 0.4, 0.4)), null, &"slab")
	assert_true(gray.mesh is BoxMesh)


# --- Dressing, pieces and prop spots ------------------------------------------------------------


func test_a_kit_piece_draws_its_kind_and_has_no_collider() -> void:
	var piece := KitPiece.new()
	piece.kind = &"window"
	piece.size = Vector3(1.3, 1.9, 0.3)
	add_child_autofree(piece)
	assert_same(piece.mesh, KitMesh.build(&"window", Vector3(1.3, 1.9, 0.3)))
	piece.size = Vector3(2.0, 1.9, 0.3)
	assert_same(piece.mesh, KitMesh.build(&"window", Vector3(2.0, 1.9, 0.3)), "a new size rebuilds")
	assert_eq(piece.find_children("*", "CollisionObject3D", true, false).size(), 0)


func test_the_dressing_is_non_solid_and_hides_in_the_graybox() -> void:
	var dressing := Dressing.new()
	var piece := KitPiece.new()
	piece.kind = &"cornice"
	piece.size = Vector3(4.0, 0.6, 0.45)
	dressing.add_child(piece)
	add_child_autofree(dressing)
	assert_true(dressing.visible)
	assert_eq(dressing.pieces().size(), 1)
	assert_false(is_instance_of(dressing as Node, LevelBlock), "never a solid LevelBlock (the solid-block tests walk those)")
	var gray := Dressing.new()
	Tuning.set_value(&"kit_draw_graybox", true)
	add_child_autofree(gray)
	assert_false(gray.visible, "the graybox hides the dressing")


func test_a_prop_spot_draws_its_fallback_box_until_the_scene_exists() -> void:
	for id: StringName in [&"car", &"dumpster", &"ac_unit", &"water_tank"]:
		var spot := PropSpot.new()
		spot.prop_id = id
		add_child_autofree(spot)
		var nominal := PropSpot.nominal_size(id)
		assert_gt(nominal.x, 0.0, "%s has a nominal box" % id)
		if PropSpot.scene_path(id) == "":
			assert_not_null(spot.fallback, "%s: the fallback box stands in" % id)
			assert_null(spot.art)
			assert_eq((spot.fallback.mesh as BoxMesh).size, nominal, "%s: its nominal box" % id)
			assert_eq(spot.fallback.position, Vector3(0.0, nominal.y * 0.5, 0.0), "standing on the floor")
		else:
			assert_not_null(spot.art, "%s: PROPS's scene draws" % id)
			assert_null(spot.fallback)
		assert_eq(spot.find_children("*", "CollisionObject3D", true, false).size(), 0, "visual only")
	assert_eq(PropSpot.nominal_size(&"car"), Vector3(4.2, 1.4, 1.9))
	assert_eq(PropSpot.nominal_size(&"dumpster"), Vector3(2.0, 1.3, 1.0))
	assert_eq(PropSpot.nominal_size(&"ac_unit"), Vector3(1.0, 0.8, 0.7))
	assert_eq(PropSpot.nominal_size(&"water_tank"), Vector3(2.0, 2.6, 2.0))


func test_a_prop_spot_fills_its_size_and_the_fallback_wears_the_hull() -> void:
	# An id with no scene keeps the fallback (PROPS's car, dumpster, AC unit and tank have theirs).
	var spot := PropSpot.new()
	spot.prop_id = &"_no_scene"
	spot.size = Vector3(2.75, 2.2, 1.8)
	add_child_autofree(spot)
	assert_not_null(spot.fallback, "no scene: the fallback box stands in")
	assert_eq((spot.fallback.mesh as BoxMesh).size, Vector3(2.75, 2.2, 1.8))
	var material := (spot.fallback.mesh as BoxMesh).material as ShaderMaterial
	assert_not_null(material.next_pass, "inked like a prop")
	var plain := PropSpot.new()
	plain.prop_id = &"_no_scene"
	plain.size = Vector3(2.75, 2.2, 1.8)
	plain.hull = false
	add_child_autofree(plain)
	assert_null(((plain.fallback.mesh as BoxMesh).material as ShaderMaterial).next_pass)
	var car := PropSpot.new()
	car.prop_id = &"car"
	add_child_autofree(car)
	assert_not_null(car.art, "PROPS's car scene draws")
	assert_null(car.fallback, "and no fallback box with it")


## A scene is fitted per axis to the spot's box and stands on the floor at its middle.
func test_a_prop_scene_is_fitted_to_the_spots_box() -> void:
	var spot := PropSpot.new()
	add_child_autofree(spot)
	var art := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	mesh.mesh = box
	mesh.position = Vector3(1.0, 5.0, 0.0)
	art.add_child(mesh)
	spot.add_child(art)
	spot._fit(art, Vector3(4.0, 1.0, 2.0))
	assert_eq(art.scale, Vector3(2.0, 0.5, 1.0))
	var fitted := art.transform * (mesh.transform * box.get_aabb())
	assert_almost_eq(fitted.position.y, 0.0, 0.001, "it stands on the floor")
	assert_almost_eq(fitted.size.x, 4.0, 0.001)
	assert_almost_eq(fitted.position.x + fitted.size.x * 0.5, 0.0, 0.001, "centred on the spot")


func test_a_prop_spot_is_hidden_in_the_graybox() -> void:
	Tuning.set_value(&"kit_draw_graybox", true)
	var spot := PropSpot.new()
	spot.prop_id = &"dumpster"
	add_child_autofree(spot)
	assert_false(spot.visible)


# --- Street A1 as the proof -----------------------------------------------------------------------


func _level() -> LevelRoot:
	var root := (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	root.with_presentation = false
	root.waves_enabled_on_start = false
	add_child_autofree(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return root


func test_street_a1_is_dressed_and_the_dressing_is_non_solid() -> void:
	var level := await _level()
	var street := level.sections[0]
	var dressing := street.get_node_or_null("DressingA1") as Dressing
	assert_not_null(dressing, "the street's first dressing")
	assert_gt(dressing.pieces().size(), 20, "a door frame, windows and cornices")
	var kinds := {}
	for piece in dressing.pieces():
		kinds[piece.kind] = true
	for kind: StringName in [&"door_frame", &"window", &"cornice"]:
		assert_true(kinds.has(kind), "A1 has %s" % kind)
	assert_eq(dressing.prop_spots().size(), 1, "the dumpster spot")
	assert_eq(dressing.find_children("*", "CollisionObject3D", true, false).size(), 0, "nothing under it collides")
	assert_true(street.blocks().size() > 50)
	for block in street.blocks():
		assert_false(block.get_parent() is Dressing, "never a LevelBlock in the dressing")


func test_the_dressed_blocks_keep_their_colliders() -> void:
	var level := await _level()
	var crates := level.sections[0].get_node("Geometry/Crates") as LevelBlock
	assert_false(crates.draw_box)
	assert_not_null(crates.body, "the hidden crate is still a wall")
	assert_eq(_meshes(crates).size(), 0)
	var fence := level.sections[0].get_node("Geometry/FenceAcross") as LevelBlock
	assert_not_null(fence.body)
	assert_same(_meshes(fence)[0].mesh, KitMesh.build(&"chainlink", fence.size))


func test_the_whole_level_draws_on_one_trim_material() -> void:
	var level := await _level()
	var materials := {}
	var kit_meshes := 0
	for found: Node in level.container.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh is ArrayMesh and not _in_static_art(mesh):
			var material := (mesh.mesh as ArrayMesh).surface_get_material(0)
			if material == ToonMaterials.trim():
				kit_meshes += 1
			materials[material] = true
	assert_gt(kit_meshes, 150, "the level's blocks and the dressing are kit meshes")
	assert_eq(materials.size(), 1, "and they share one material (the props and weapons are StaticArt on the atlas)")


## Whether `node` is part of a prop's or a weapon's StaticArt (PROPS: drawn on the palette atlas).
func _in_static_art(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is StaticArt:
			return true
		parent = parent.get_parent()
	return false


# --- Stairs and barriers ------------------------------------------------------------------------


func test_a_flight_of_stairs_is_one_mesh_over_collider_steps() -> void:
	var level := await _level()
	var stairs := level.sections[0].stairs()[0]
	var steps := stairs.get_node("Steps")
	assert_eq(stairs.step_count(), 25)
	var blocks := steps.find_children("Step*", "Node3D", false, false)
	assert_eq(blocks.size(), 25, "the steps stay")
	var bodies := 0
	for node in blocks:
		var block := node as LevelBlock
		assert_not_null(block.body, "every step is a collider")
		assert_eq(_meshes(block).size(), 0, "and draws nothing")
		bodies += 1
	assert_eq(bodies, 25)
	var flight := steps.get_node_or_null("Flight") as MeshInstance3D
	assert_not_null(flight, "one flight mesh draws them")
	assert_same(flight.mesh, KitMesh.build_stairs(stairs.width_m, stairs.rise_m, stairs.run_m, 25))
	var top := flight.mesh.get_aabb()
	assert_almost_eq(top.size.y, stairs.rise_m, 0.001, "its climb is the flight's")
	assert_almost_eq(top.size.z, stairs.run_m, 0.001)


func test_the_graybox_draws_the_steps_as_boxes() -> void:
	Tuning.set_value(&"kit_draw_graybox", true)
	var level := await _level()
	var stairs := level.sections[0].stairs()[0]
	assert_null(stairs.get_node("Steps").get_node_or_null("Flight"))
	assert_eq(_meshes(stairs).size(), 25)


func test_the_barriers_draw_kit_pieces_on_their_panels() -> void:
	var level := await _level()
	var section := level.sections[0]
	var cars: Barrier = section.get_node("Barriers/StartCar")
	var spots: Array[PropSpot] = []
	for child in cars.get_node("Panel").get_children():
		if child is PropSpot:
			spots.append(child)
	assert_eq(spots.size(), 2, "one car per car_length_m of the 6 m opening (3.2 m cars)")
	for spot in spots:
		assert_eq(spot.prop_id, &"car")
		assert_almost_eq(spot.size.y, cars.height_m, 0.001, "as tall as the collider")
	var gate: Barrier = section.get_node("Barriers/Gate")
	var gate_pieces := gate.get_node("Panel").find_children("*", "MeshInstance3D", true, false)
	assert_eq(gate_pieces.size(), 1, "the gate is one piece")
	assert_eq((gate_pieces[0] as KitPiece).kind, &"gate")
	var shutter: Barrier = section.get_node("ExitBarrier")
	assert_eq(shutter.get_node("Panel").find_children("*", "MeshInstance3D", true, false).size(), 1, "the slats")
	var housing := false
	for child in shutter.get_children():
		housing = housing or (child is KitPiece and (child as KitPiece).kind == &"housing")
	assert_true(housing, "the housing stays when the panel rolls up")
	for barrier: Barrier in [cars, gate, shutter]:
		var colliders := barrier.get_node("Collider").find_children("*", "MeshInstance3D", true, false)
		assert_eq(colliders.size(), 0, "the collider has no art")
		assert_eq(barrier.find_children("*", "CollisionObject3D", true, false).size(), 1, "only the Collider collides")


func test_the_graybox_builds_m5s_barrier_boxes() -> void:
	Tuning.set_value(&"kit_draw_graybox", true)
	var level := await _level()
	var gate: Barrier = level.sections[0].get_node("Barriers/Gate")
	var meshes := _meshes(gate)
	assert_gt(meshes.size(), 20, "the post, rail and wire boxes")
	for mesh in meshes:
		assert_true(mesh.mesh is BoxMesh)


# --- section_entered -----------------------------------------------------------------------------


var _entered: Array[Node3D] = []


func _on_entered(section: Node3D) -> void:
	_entered.append(section)


func test_section_entered_fires_once_at_the_start_and_once_per_crossing() -> void:
	_entered.clear()
	CombatEvents.section_entered.connect(_on_entered)
	var level := await _level()
	assert_eq(_entered.size(), 1, "once at the start")
	assert_same(_entered[0], level.sections[0])
	assert_same(level.current_section(), level.sections[0])
	for i in 30:
		await get_tree().physics_frame
	assert_eq(_entered.size(), 1, "standing still fires nothing")
	var order: Array[LevelSection] = [level.sections[1], level.sections[2], level.sections[1], level.sections[0]]
	for section in order:
		var point := section.route_points()[0]
		level.player.global_position = point
		for i in 3:
			await get_tree().physics_frame
		assert_same(_entered.back(), section)
		var before := _entered.size()
		for i in 20:
			await get_tree().physics_frame
		assert_eq(_entered.size(), before, "one emission per crossing, none while standing in it")
	assert_eq(_entered.size(), 5)
	CombatEvents.section_entered.disconnect(_on_entered)


func test_section_entered_does_not_flicker_at_a_seam() -> void:
	_entered.clear()
	CombatEvents.section_entered.connect(_on_entered)
	var level := await _level()
	var street := level.sections[0]
	var exit_point := street.route_points()[street.route_points().size() - 1]
	var roofs_first := level.sections[1].route_points()[0]
	level.player.global_position = exit_point
	for i in 3:
		await get_tree().physics_frame
	var count := _entered.size()
	# Walk back and forth across the midpoint of the seam: within the margin nothing changes hands.
	var middle := exit_point.lerp(roofs_first, 0.5)
	for n in 20:
		level.player.global_position = middle + Vector3(0.0, 0.0, 0.2 if n % 2 == 0 else -0.2)
		await get_tree().physics_frame
	assert_lte(_entered.size() - count, 1, "at most the one crossing")
	CombatEvents.section_entered.disconnect(_on_entered)
