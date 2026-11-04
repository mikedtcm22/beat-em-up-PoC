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
