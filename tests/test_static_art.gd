extends GutTest
## Milestone 6, PROPS: the static-prop path (docs/ARCHITECTURE.md "Static props and weapon art"). StaticArt draws a rigid GLB
## from tools/pipeline/run.py --kind prop on the shared atlas; every shipped prop and weapon art obeys its contract: check() is
## empty, the weapons' art sits in the pinned frame (centred, long axis +Y, within 2 cm of the weapon's length, the grip 0.12 m
## from the -Y end), the bike chain has Lock, Grip and Link, a prop's footprint matches its fallback box, and no prop takes
## the box hull. The Blender-scripted _fixture crate proves the path without a Tripo model.

const ATLAS := preload("res://assets/export/palette/palette_atlas.png")
const FIXTURE := preload("res://assets/export/props/_fixture/_fixture.glb")
const PROPS_DIR := "res://game/level/props"
const WEAPON_ART_DIR := "res://game/weapons/art"
const PROP_GLB_DIR := "res://assets/export/props"
## SPEC section 10: 3k triangles for a prop or a weapon; the frame test's tolerance (m).
const BUDGET := 3000
const FRAME_TOLERANCE_M := 0.02
## The pipe's own length (weapon.gd), and the grip's distance from the -Y end the weapon frame pins (weapon.gd _attach_deferred).
const GRIP_FROM_END_M := 0.12
## The fallback boxes of SPEC-pinned props (plan section 2: length x height x depth in metres), and how far a model's footprint may
## differ from them (a car is not a box).
const FALLBACK_BOXES := {
	&"car": Vector3(4.2, 1.4, 1.9),
	&"dumpster": Vector3(2.0, 1.3, 1.0),
	&"ac_unit": Vector3(1.0, 0.8, 0.7),
	&"water_tank": Vector3(2.0, 2.6, 2.0),
}
const FOOTPRINT_TOLERANCE := 0.12


func _fixture_art() -> StaticArt:
	var art := StaticArt.new()
	art.scene = FIXTURE
	art.palette = ATLAS
	art.hull = true
	return art


func test_the_fixture_crate_passes_its_check() -> void:
	var art := _fixture_art()
	assert_eq(art.check(), PackedStringArray(), "the Blender-scripted crate meets the contract")
	assert_eq(art.mesh_names(), PackedStringArray(["Crate"]))
	assert_lte(art.triangles(), BUDGET)
	art.free()


func test_the_fixture_draws_one_mesh_with_the_art_prop_material_and_the_baked_hull() -> void:
	var art := _fixture_art()
	add_child_autofree(art)
	var instances := art.instances()
	assert_eq(instances.size(), 1, "one MeshInstance3D per GLB mesh")
	var mesh := instances[0]
	var mat := mesh.material_override as ShaderMaterial
	assert_not_null(mat)
	assert_eq(mat.shader, ToonMaterials.TOON_SHADER)
	assert_same(mat.get_shader_parameter(&"albedo_tex"), ATLAS, "it reads the shared atlas")
	assert_true(mat.get_shader_parameter(&"use_albedo_tex"))
	assert_false(mat.get_shader_parameter(&"use_rest_custom"), "no skin, so no rest marks")
	assert_eq(mat.get_meta(&"toon_kind"), ToonMaterials.Kind.ART_PROP)
	var overlay := mesh.material_overlay as ShaderMaterial
	assert_not_null(overlay, "hull on: the baked-smooth-normal hull")
	assert_same(overlay, ToonMaterials.outline(), "the one shared art hull (mode 4), never the box hull")
	assert_eq(overlay.get_shader_parameter(&"mode"), ToonMaterials.Hull.ART)
	assert_eq(mat.get_shader_parameter(&"edge_tag"), 0.0, "with a hull the screen edge pass leaves it alone")


func test_hull_off_has_no_overlay_and_leaves_the_edge_pass_on() -> void:
	var art := _fixture_art()
	art.hull = false
	add_child_autofree(art)
	var mesh := art.instances()[0]
	assert_null(mesh.material_overlay)
	assert_eq((mesh.material_override as ShaderMaterial).get_shader_parameter(&"edge_tag"), 1.0)


func test_the_tint_multiplies_the_swatches() -> void:
	var art := _fixture_art()
	add_child_autofree(art)
	art.set_tint(Color(0.9, 0.5, 0.1))
	assert_eq(art.material.get_shader_parameter(&"albedo"), Color(0.9, 0.5, 0.1))
	art.set_tint(Color.WHITE)
	assert_eq(art.material.get_shader_parameter(&"albedo"), Color.WHITE)


func test_the_fixture_surface_carries_uv1_on_swatch_centres_the_hull_normal_and_no_skin() -> void:
	var root := FIXTURE.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1)
	var instance := meshes[0] as MeshInstance3D
	assert_null(instance.skin, "a static prop has no skin")
	var arrays := (instance.mesh as ArrayMesh).surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 0)
	var off_centre := 0
	for uv: Vector2 in uvs:
		var col := uv.x * 32.0 - 0.5
		var row := uv.y * 2.0 - 0.5
		if absf(col - roundf(col)) > 0.01 or absf(row - roundf(row)) > 0.01:
			off_centre += 1
	assert_eq(off_centre, 0, "every UV is a swatch centre")
	assert_not_null(arrays[Mesh.ARRAY_COLOR], "the smooth hull normal rides in COLOR")
	root.free()


func test_a_scene_with_no_palette_or_over_budget_is_refused() -> void:
	var art := _fixture_art()
	art.triangle_budget = 10
	assert_true(art.check().size() > 0, "108 triangles are over a budget of 10")
	art.triangle_budget = BUDGET
	art.palette = null
	assert_true(art.check().size() > 0, "no atlas")
	art.free()
	var bare := StaticArt.new()
	assert_true(bare.check().size() > 0, "no scene")
	bare.free()


func test_the_art_prop_kind_takes_the_look_tuning_and_no_rim() -> void:
	var mat := ToonMaterials.art_prop(ATLAS, Color.WHITE)
	assert_eq(mat.get_shader_parameter(&"rim_strength"), 0.0, "the rim is the characters' alone")
	assert_eq(mat.get_shader_parameter(&"fill_strength"), 0.0)
	assert_eq(mat.get_shader_parameter(&"glint_strength"), Tuning.data.look_glint_strength)
	assert_eq(mat.get_shader_parameter(&"spec_strength"), Tuning.data.look_spec_strength, "the hard highlight lands on glossy swatches only (toon.gdshader)")


# --- the shipped art ------------------------------------------------------------------------------


func _prop_art(id: StringName) -> StaticArt:
	return (load("%s/%s.tscn" % [PROPS_DIR, id]) as PackedScene).instantiate() as StaticArt


func _weapon_art(id: StringName) -> StaticArt:
	return (load("%s/%s.tscn" % [WEAPON_ART_DIR, id]) as PackedScene).instantiate() as StaticArt


func test_every_prop_scene_passes_its_check_within_budget_on_the_shared_atlas() -> void:
	for id: StringName in FALLBACK_BOXES:
		var art := _prop_art(id)
		assert_not_null(art, "%s: game/level/props/%s.tscn is a StaticArt" % [id, id])
		if art == null:
			continue
		assert_eq(art.check(), PackedStringArray(), "%s meets the contract" % id)
		assert_lte(art.triangles(), BUDGET, "%s: SPEC section 10's 3k triangles" % id)
		assert_same(art.palette, ATLAS, "%s draws the shared atlas" % id)
		art.free()


func test_a_props_footprint_and_height_match_its_fallback_box_and_it_stands_on_the_floor() -> void:
	for id: StringName in FALLBACK_BOXES:
		var art := _prop_art(id)
		var box: Vector3 = FALLBACK_BOXES[id]
		var bounds := art.bounds()
		assert_almost_eq(bounds.size.x, box.x, box.x * FOOTPRINT_TOLERANCE, "%s: length %.2f of %.2f" % [id, bounds.size.x, box.x])
		assert_almost_eq(bounds.size.z, box.z, box.z * FOOTPRINT_TOLERANCE, "%s: depth %.2f of %.2f" % [id, bounds.size.z, box.z])
		assert_almost_eq(bounds.size.y, box.y, box.y * 0.2, "%s: height %.2f of %.2f (the AC unit is flatter than its box, the car a hand taller)" % [id, bounds.size.y, box.y])
		assert_almost_eq(bounds.position.y, 0.0, 0.01, "%s stands on y 0 (its origin is the base centre)" % id)
		assert_almost_eq(bounds.get_center().x, 0.0, box.x * 0.06, "%s is centred in x" % id)
		assert_almost_eq(bounds.get_center().z, 0.0, box.z * 0.06, "%s is centred in z" % id)
		art.free()


func test_no_prop_takes_the_box_hull_and_the_baked_hull_is_the_choice() -> void:
	var ids: Array[StringName] = [&"car", &"dumpster", &"ac_unit", &"water_tank"]
	for id: StringName in ids:
		var art := _prop_art(id)
		assert_true(art.hull, "%s: D14, the baked smooth normal hull (captures/props, the hull A/B)" % id)
		add_child_autofree(art)
		for mesh: MeshInstance3D in art.instances():
			var overlay := mesh.material_overlay as ShaderMaterial
			assert_not_null(overlay, "%s %s has its hull" % [id, mesh.name])
			if overlay != null:
				assert_ne(overlay.get_shader_parameter(&"mode"), ToonMaterials.Hull.BOX, "%s: never the box hull" % id)
				assert_eq(overlay.get_shader_parameter(&"mode"), ToonMaterials.Hull.ART)


func test_the_weapon_art_sits_in_the_pinned_frame() -> void:
	var length := 0.85  # weapon.gd's `length`: the pipe's, and the bike chain's (its hit stays on the same WeaponTip)
	for id: StringName in [&"pipe", &"bike_chain"]:
		var art := _weapon_art(id)
		assert_not_null(art, "game/weapons/art/%s.tscn is a StaticArt" % id)
		if art == null:
			continue
		assert_eq(art.check(), PackedStringArray(), "%s meets the contract" % id)
		var bounds := art.bounds()
		assert_almost_eq(bounds.size.y, length, FRAME_TOLERANCE_M, "%s: its long axis is Y and as long as the weapon (%.3f)" % [id, bounds.size.y])
		assert_almost_eq(bounds.get_center().y, 0.0, FRAME_TOLERANCE_M, "%s: centred on the origin" % id)
		assert_lt(bounds.size.x, length * 0.25, "%s: thin across" % id)
		assert_lt(bounds.size.z, length * 0.25, "%s: thin across" % id)
		var grip_y := -length * 0.5 + GRIP_FROM_END_M
		assert_between(grip_y, bounds.position.y, bounds.end.y, "%s: the grip point (0.12 m from the -Y end) is inside the art" % id)
		art.free()


func test_the_bike_chain_has_a_lock_a_grip_and_a_link_in_the_frame() -> void:
	var model := load("res://assets/export/props/bike_chain/bike_chain.glb") as PackedScene
	var names := StaticArt.mesh_names_of(model)
	assert_eq(names, PackedStringArray(["Grip", "Link", "Lock"]), "the three meshes of the contract")
	var root := model.instantiate()
	var boxes: Dictionary[String, AABB] = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		boxes[String(mesh.name)] = mesh.transform * mesh.mesh.get_aabb()
	root.free()
	var length := 0.85
	assert_almost_eq(boxes["Link"].get_center().y, 0.0, 0.01, "one link at the origin, which WEAPONS's sim repeats")
	assert_almost_eq(boxes["Link"].get_center().x, 0.0, 0.01)
	assert_almost_eq(boxes["Lock"].end.y, length * 0.5, FRAME_TOLERANCE_M, "the padlock at the free (+Y) end")
	assert_almost_eq(boxes["Grip"].position.y, -length * 0.5, FRAME_TOLERANCE_M, "the wrapped handle at the -Y end")
	assert_lt(boxes["Grip"].end.y, boxes["Link"].position.y, "the handle is below the link")
	assert_gt(boxes["Lock"].position.y, boxes["Link"].end.y, "the lock is above it")


func test_the_chain_draws_repeated_links_between_the_grip_and_the_lock() -> void:
	var art := _weapon_art(&"bike_chain")
	add_child_autofree(art)
	var names: Array[String] = []
	for mesh: MeshInstance3D in art.instances():
		names.append(String(mesh.name))
	assert_true(names.has("Lock") and names.has("Grip") and names.has("Link"))
	var repeats := names.filter(func(n: String) -> bool: return n.begins_with("LinkRep"))
	assert_gt(repeats.size(), 8, "a chain, not one link")
	var bounds := art.bounds()
	for mesh: MeshInstance3D in art.instances():
		if String(mesh.name).begins_with("LinkRep"):
			assert_between(mesh.position.y, bounds.position.y, bounds.end.y, "%s lies between the ends" % mesh.name)


func test_a_weapon_with_art_draws_the_art_and_not_the_cylinder() -> void:
	var weapon := (load("res://game/weapons/pipe.tscn") as PackedScene).instantiate() as Weapon
	add_child_autofree(weapon)
	var arts := weapon.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is StaticArt)
	assert_eq(arts.size(), 1, "pipe.tscn sets art_scene: one StaticArt")
	var cylinders := weapon.find_children("*", "MeshInstance3D", false, false).filter(func(n: Node) -> bool: return (n as MeshInstance3D).mesh is CylinderMesh)
	assert_eq(cylinders.size(), 1, "the hit-free proxy the floor look reads stays")
	assert_false((cylinders[0] as MeshInstance3D).visible, "but it does not draw")
	assert_null((cylinders[0] as MeshInstance3D).material_overlay, "nor does its hull")
	var bare := Weapon.new()
	add_child_autofree(bare)
	assert_true(((bare.find_children("*", "MeshInstance3D", false, false)[0]) as MeshInstance3D).visible, "a weapon with no art_scene keeps the cylinder")


func test_the_art_takes_the_floor_tint_lying_and_its_own_colours_otherwise() -> void:
	Tuning.reset_to_default()
	var weapon := (load("res://game/weapons/pipe.tscn") as PackedScene).instantiate() as Weapon
	add_child_autofree(weapon)
	var art := weapon.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is StaticArt)[0] as StaticArt
	var lying: Color = art.material.get_shader_parameter(&"albedo")
	assert_eq(lying, Color.WHITE.lerp(Tuning.data.weapon_floor_color, Tuning.data.weapon_art_floor_tint), "lying: the floor colour, softened by Prop art's weapon_art_floor_tint")
	assert_ne(lying, Color.WHITE)
	Tuning.data.weapon_art_floor_tint = 0.0
	weapon._refresh_look()
	assert_eq(art.material.get_shader_parameter(&"albedo"), Color.WHITE, "at 0 the art keeps its own colours")
	Tuning.reset_to_default()


func test_the_prop_pipeline_reports_name_the_glbs_they_exported() -> void:
	for id: String in ["_fixture", "pipe", "bike_chain", "car", "dumpster", "ac_unit", "water_tank"]:
		var report_path := "res://assets/source/props/%s/report/report.json" % id
		assert_true(FileAccess.file_exists(report_path), "%s: the committed report" % id)
		if not FileAccess.file_exists(report_path):
			continue
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		var glb := "res://assets/export/props/%s/%s.glb" % [id, id]
		assert_eq(FileAccess.get_sha256(glb), (report.outputs as Dictionary)["%s.glb" % id], "%s.glb is the file its report hashed (rerun run.py --asset %s --kind prop)" % [id, id])
		var export: Dictionary = (report.steps.export.variants as Dictionary).prop
		assert_lte(int(export.triangles), BUDGET, "%s: at most 3000 triangles" % id)


func test_the_props_palette_files_stay_out_of_the_red_band() -> void:
	for file: String in ["weapons", "props"]:
		var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/%s.json" % file))
		for sw: Dictionary in pal.swatches:
			var c := Color.html(sw.srgb)
			var red := (c.h >= 345.0 / 360.0 or c.h <= 15.0 / 360.0) and c.s > 0.5
			assert_false(red, "%s slot %d (%s) is in the red band" % [file, sw.slot, sw.srgb])


func test_the_props_tripo_spend_is_within_its_ceiling_and_every_task_finished() -> void:
	var created := {}
	var finished := {}
	var spent := 0.0
	for line: String in FileAccess.get_file_as_string("res://assets/source/tripo_ledger.jsonl").split("\n", false):
		var row: Variant = JSON.parse_string(line)
		if not row is Dictionary or row.get("milestone", "") != "M6" or not String(row.get("label", "")).begins_with("PR"):
			continue
		if row.event == "created":
			created[String(row.task_id)] = true
		elif row.event == "finished":
			finished[String(row.task_id)] = true
			spent += float(row.credits_consumed)
	for task: String in created:
		assert_true(finished.has(task), "task %s finished" % task)
	assert_gt(created.size(), 0, "PROPS ran Tripo tasks (labels PR<n>)")
	assert_lte(spent, 270.0, "the plan's ceiling for PROPS (%.0f)" % spent)
