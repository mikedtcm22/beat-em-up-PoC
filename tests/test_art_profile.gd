extends GutTest
## Milestone 7, T05b: per-profile character art. A CharacterArt may carry a `trailer` variant (its own GLB,
## palette and material); a rig swaps between the two live when the look profile flips, keeping its pose,
## damage look, flash and outline; flipping back restores the m6 mesh and material exactly; a rig built after
## a flip wears the running profile's art; a character with no variant keeps its m6 art; the load-time
## warm-up draws both profiles' art. The fixture (tests/fixtures/m7) is the Dummy's GLB twice, the variant
## with an inverted palette, so there is no new art.

const BASE_PATH := "res://tests/fixtures/m7/dummy_with_trailer_art.tres"
const PUNK_ART := "res://game/actors/art/punk_art.tres"
const INVERTED := "res://tests/fixtures/m7/inverted_palette.png"
const ATLAS := "res://assets/export/palette/palette_atlas.png"
const DUMMY_SCENE := "res://game/enemies/dummy/training_dummy.tscn"

var _base: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	_base = load(BASE_PATH) as CharacterArt


func after_each() -> void:
	Tuning.reset_to_default()


func _rig(art: CharacterArt) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	return rig


func _flip(profile: int) -> void:
	Tuning.set_value(&"look_profile", profile)


func _palette_of(rig: HumanoidRig) -> Texture2D:
	return (rig.art_meshes()[0].material_override as ShaderMaterial).get_shader_parameter(&"albedo_tex")


func test_the_fixture_is_the_dummy_with_another_palette() -> void:
	assert_not_null(_base.trailer_art(), "the fixture's art carries a trailer variant")
	assert_eq(_base.variant(&"m6"), _base)
	assert_eq(_base.variant(&"trailer"), _base.trailer_art())
	assert_eq(_base.trailer_art().scene, _base.scene, "the same GLB")
	assert_eq(_base.palette.resource_path, ATLAS)
	assert_eq(_base.trailer_art().palette.resource_path, INVERTED)
	assert_ne(_base.palette.get_image().get_pixel(0, 0), _base.trailer_art().palette.get_image().get_pixel(0, 0), "visibly another palette")
	assert_true(SkinnedArt.check(_base.trailer_art()).is_empty(), "the variant keeps the art contract")


func test_a_spawned_actor_swaps_on_flip() -> void:
	var dummy := (load(DUMMY_SCENE) as PackedScene).instantiate() as TrainingDummy
	dummy.art = _base
	add_child_autofree(dummy)
	await get_tree().physics_frame
	var rig := dummy.rig
	assert_eq(rig.worn_art(), _base)
	var old_mesh := rig.art_meshes()[0]
	var old_mesh_res := old_mesh.mesh
	var old_mat := old_mesh.material_override as ShaderMaterial
	assert_eq(old_mat.get_shader_parameter(&"albedo_tex").resource_path, ATLAS)
	_flip(LookProfile.Id.TRAILER)
	assert_eq(rig.worn_art(), _base.trailer_art(), "the actor wears the variant")
	assert_eq(rig.art, _base, "its own art is still the m6 one")
	assert_false(is_instance_valid(old_mesh), "the old mesh instance is gone")
	assert_eq(rig.art_meshes().size(), 1)
	var mesh := rig.art_meshes()[0]
	assert_ne(mesh.mesh, old_mesh_res, "its own mesh resource")
	assert_ne(mesh.material_override, old_mat, "its own material")
	assert_eq((mesh.material_override as ShaderMaterial).get_shader_parameter(&"albedo_tex").resource_path, INVERTED, "its own palette")
	assert_true(mesh.is_in_group(HumanoidRig.ART_GROUP))
	assert_eq(mesh.get_parent(), rig.skeleton, "on the same skeleton")
	assert_true(mesh.visible, "shown, like the art it replaced")
	assert_eq(rig.get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP).filter(func(n: Node) -> bool: return rig.is_ancestor_of(n)).size(), 1, "one art mesh on the rig, not two")


func test_flipping_back_restores_the_m6_mesh_and_material_exactly() -> void:
	var rig := _rig(_base)
	var first := rig.art_meshes()[0]
	var mesh := first.mesh
	var material := first.material_override
	var overlay := first.material_overlay
	var name := first.name
	var child_count := rig.skeleton.get_child_count()
	var skin_binds := first.skin.get_bind_count()
	_flip(LookProfile.Id.TRAILER)
	_flip(LookProfile.Id.M6)
	var back := rig.art_meshes()[0]
	assert_eq(rig.worn_art(), _base)
	assert_same(back.mesh, mesh, "the very same mesh")
	assert_same(back.material_override, material, "the very same material")
	assert_same(back.material_overlay, overlay, "the very same outline")
	assert_eq(back.name, name, "named as it was")
	assert_eq(rig.skeleton.get_child_count(), child_count, "no mesh left behind")
	assert_eq(back.skin.get_bind_count(), skin_binds)
	assert_eq(_palette_of(rig).resource_path, ATLAS)
	_flip(LookProfile.Id.TRAILER)
	_flip(LookProfile.Id.M6)
	assert_same(rig.art_meshes()[0].material_override, material, "and again")


func test_a_rig_mid_animation_keeps_its_pose_through_a_flip() -> void:
	var rig := _rig(_base)
	rig.play(&"flinch_gut")
	for i in 5:
		rig.advance(1.0 / 60.0)
	var anim := rig.current_anim()
	var before := _pose(rig)
	_flip(LookProfile.Id.TRAILER)
	var after := _pose(rig)
	assert_eq(after.size(), before.size())
	for i in before.size():
		assert_true(before[i].is_equal_approx(after[i]), "bone %d is where it was" % i)
	assert_eq(rig.current_anim(), anim, "and the animation plays on")
	rig.advance(1.0 / 60.0)
	var moved := _pose(rig)
	_flip(LookProfile.Id.M6)
	var back := _pose(rig)
	for i in moved.size():
		assert_true(moved[i].is_equal_approx(back[i]), "bone %d is where it was, flipping back" % i)
	var mesh := rig.art_meshes()[0]
	assert_eq(mesh.get_node(mesh.skeleton), rig.skeleton, "the mesh follows the rig's skeleton")


func _pose(rig: HumanoidRig) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(rig.skeleton.get_bone_global_pose(i))
	return out


func test_a_rig_built_after_a_flip_wears_the_running_profile() -> void:
	_flip(LookProfile.Id.TRAILER)
	var dummy := (load(DUMMY_SCENE) as PackedScene).instantiate() as TrainingDummy
	dummy.art = _base
	add_child_autofree(dummy)
	await get_tree().physics_frame
	assert_eq(dummy.rig.worn_art(), _base.trailer_art(), "spawned into the trailer look")
	assert_eq(_palette_of(dummy.rig).resource_path, INVERTED)
	assert_eq(dummy.rig.art_meshes().size(), 1)
	_flip(LookProfile.Id.M6)
	assert_eq(dummy.rig.worn_art(), _base, "and back")
	assert_eq(_palette_of(dummy.rig).resource_path, ATLAS)


func test_the_damage_look_flash_and_outline_carry_over() -> void:
	var rig := _rig(_base)
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	rig.set_flash(0.5, Color.CYAN)
	_flip(LookProfile.Id.TRAILER)
	var material := rig.art_meshes()[0].material_override as ShaderMaterial
	var other := rig.paint.base_art_material() as ShaderMaterial
	assert_ne(material, other)
	for key: StringName in [&"damage_tex", &"damage_skin_tex", &"damage_scuff_tex", &"blood_edge", &"damage_scale"]:
		assert_eq(material.get_shader_parameter(key), other.get_shader_parameter(key), "%s is the m6 material's" % key)
	assert_eq(material.get_shader_parameter(&"damage_tex"), DamageLook.texture_for(PlaceholderBody.Paint.BODY, DamageLook.Level.BLOODIED))
	assert_eq(rig.damage_look, DamageLook.Level.BLOODIED)
	assert_almost_eq(float(material.get_shader_parameter(&"flash_amount")), 0.5, 0.0001)
	assert_eq(material.get_shader_parameter(&"flash_color"), Color.CYAN)
	assert_same(rig.art_meshes()[0].material_overlay, ToonMaterials.outline(false), "the shared hull")
	assert_eq(rig.art_meshes()[0].material_overlay.get_shader_parameter(&"width_px"), Tuning.data.look_outline_px * LookProfile.ink_width_scale())
	# A change made while the variant shows reaches the art that is not shown too: back, it is current.
	rig.set_damage_look(DamageLook.Level.CLEAN)
	rig.set_flash(0.0)
	_flip(LookProfile.Id.M6)
	var back := rig.art_meshes()[0].material_override as ShaderMaterial
	assert_eq(back.get_shader_parameter(&"flash_amount"), 0.0)
	assert_eq(back.get_shader_parameter(&"damage_tex"), DamageLook.texture_for(PlaceholderBody.Paint.BODY, DamageLook.Level.CLEAN) if DamageLook.texture_for(PlaceholderBody.Paint.BODY, DamageLook.Level.CLEAN) else VfxArt.clear_detail())
	# A contact flash overlay on the variant is on the m6 material too.
	_flip(LookProfile.Id.TRAILER)
	var overlay := ShaderMaterial.new()
	rig.paint.show_flash_overlay(true, overlay)
	assert_same((rig.art_meshes()[0].material_override as ShaderMaterial).next_pass, overlay)
	assert_same(rig.paint.base_art_material().next_pass, overlay)
	rig.paint.show_flash_overlay(false, overlay)


func test_an_enemys_palette_swap_stays_on_its_m6_art() -> void:
	var swap := load(INVERTED) as Texture2D
	var rig := _rig(_base)
	var m6_material := rig.paint.base_art_material() as ShaderMaterial
	m6_material.set_shader_parameter(&"albedo_tex", swap)
	_flip(LookProfile.Id.TRAILER)
	assert_eq(_palette_of(rig).resource_path, INVERTED)
	assert_same(rig.paint.art_material(), rig.art_meshes()[0].material_override)
	assert_ne(rig.paint.art_material(), m6_material)
	assert_same(rig.paint.base_art_material(), m6_material, "the m6 art's material is still the base one")


func test_a_character_without_a_variant_keeps_its_m6_art() -> void:
	var punk_art := load(PUNK_ART) as CharacterArt
	assert_null(punk_art.trailer_art(), "no shipped art has a variant yet")
	var rig := _rig(punk_art)
	var mesh := rig.art_meshes()[0]
	var material := mesh.material_override
	_flip(LookProfile.Id.TRAILER)
	assert_same(rig.art_meshes()[0], mesh, "the same mesh instance")
	assert_same(rig.art_meshes()[0].material_override, material)
	assert_eq(rig.worn_art(), punk_art)
	_flip(LookProfile.Id.M6)
	assert_same(rig.art_meshes()[0], mesh)


func test_a_variant_that_breaks_the_contract_is_not_worn() -> void:
	var art := _base.duplicate() as CharacterArt
	art.set_meta(&"trailer", CharacterArt.new())
	var rig := _rig(art)
	_flip(LookProfile.Id.TRAILER)
	assert_eq(rig.worn_art(), art, "the rig keeps its m6 art")
	assert_eq(rig.art_meshes().size(), 1)
	assert_false(rig.swap_art(art), "already worn")
	_flip(LookProfile.Id.M6)


func test_the_warm_up_draws_both_profiles_art() -> void:
	var room := Node3D.new()
	add_child_autofree(room)
	assert_eq(RoomKit.variant_arts_of([_base, null]), [_base.trailer_art()] as Array[CharacterArt])
	assert_eq(RoomKit.variant_arts_of([_base, _base.trailer_art()]).size(), 0, "a variant already in the set is not added again")
	for profile: int in [LookProfile.Id.M6, LookProfile.Id.TRAILER]:
		_flip(profile)
		var rigs := RoomKit.build_warm_rigs(room, _base)
		assert_eq(rigs.size(), 2, "the art and its variant (profile %d)" % profile)
		assert_eq(rigs[0].worn_art(), _base, "the first wears the m6 art whatever the profile")
		assert_eq(rigs[1].worn_art(), _base.trailer_art(), "the second wears the variant")
		assert_eq(_palette_of(rigs[0]).resource_path, ATLAS)
		assert_eq(_palette_of(rigs[1]).resource_path, INVERTED)
		for rig: HumanoidRig in rigs:
			assert_true(rig.has_art())
			assert_not_null(rig.skeleton)
			assert_not_null(rig.art_meshes()[0].material_overlay, "with its hull")
			rig.free()
	assert_not_null(SkinnedArt.entry_of(_base.trailer_art()), "the variant's GLB is read")
	assert_eq(RoomKit.build_warm_rigs(room).size() >= 1, true, "the Punk's warm-up rig, with a variant for each catalog art that has one")
	# Headless the draw itself is skipped; it accepts the variants all the same.
	ToonMaterials.warm_up_with(room, null, [] as Array[Node3D])
	var catalog := RoomKit.warm_catalog_arts()
	for art: CharacterArt in RoomKit.catalog_arts():
		assert_true(catalog.has(art))
		if art.trailer_art() != null:
			assert_true(catalog.has(art.trailer_art()), "a catalog art's variant is read and held too")
	RoomKit.release_catalog_arts()
