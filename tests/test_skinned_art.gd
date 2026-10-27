extends GutTest
## Milestone 4, P1-skin: skinned art on the real rig (game/actors/skinned_art.gd), M4-plan
## §2.4-2.5 as amended by A3 (the bind formula, one code path for the table's rest and an
## A-pose), A4 (the view proxies stay; the art is measured with native TriangleMesh rays), A5
## (the ragdoll writes its visual pose back into the skeleton on art rigs only) and A19 (the
## deformation strain test). No GLB: tests/fixtures/skinned_probe_art.gd builds the art in
## code, authored at the table's rest and in a 45-degree A-pose, rigid and smooth weighted.
## The same checks take every committed art GLB later (F-punk, F-player-int).

const Fixture := preload("res://tests/fixtures/skinned_probe_art.gd")
const FPView := preload("res://tests/fp_view.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")
const FRAME := 1.0 / 60.0
## The probe's vertices land where the primitives' do, to float precision.
const EXACT_M := 0.0002
## The rig heights the art is bound at: the Punk, the Bruiser and the boss.
const HEIGHTS: Array[float] = [1.8, 2.05, 2.3]


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	SkinnedArt.clear_cache()
	SkinnedView.clear_cache()


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0


# --- Harness ------------------------------------------------------------------------------


## A rig wearing `art`. `player` dresses it like the player (PlayerCharacter._configure_rig():
## first-person body, relaxed stance, wrapped hands).
func _rig(art: CharacterArt, height: float = 1.8, player: bool = false, hurtboxes: bool = false) -> HumanoidRig:
	var rig := HumanoidRig.new()
	if player:
		var dresser := PlayerCharacter.new()
		dresser._configure_rig(rig)
		dresser.free()
	rig.height = height
	rig.build_hurtboxes = hurtboxes
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	return rig


## The fixture art: `authored` is Fixture.Authored.
func _art(authored: int = Fixture.Authored.REST, player: bool = false, smooth: bool = false) -> CharacterArt:
	return Fixture.make(authored, player, smooth)


func _art_meshes(rig: HumanoidRig) -> Array[MeshInstance3D]:
	return rig.art_meshes()


func _proxies(rig: HumanoidRig) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in rig.get_tree().get_nodes_in_group(HumanoidRig.VIEW_PROXY_GROUP):
		if rig.is_ancestor_of(node):
			out.append(node as MeshInstance3D)
	return out


## Every skinned vertex of the rig's art meshes, in the order Fixture.proxy_vertices() lists
## them (the visible mesh, then the FP-hidden one).
func _skinned(rig: HumanoidRig, player: bool, globals: Array[Transform3D] = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in rig.art_meshes():
		if mi.name == &"ArtBody":
			out.append_array(SkinnedView.skin_vertices(mi, rig, globals))
	for mi: MeshInstance3D in rig.art_meshes():
		if mi.name == &"ArtBody__fp_hidden":
			out.append_array(SkinnedView.skin_vertices(mi, rig, globals))
	return out


func _expected(rig: HumanoidRig, player: bool) -> PackedVector3Array:
	var out := Fixture.proxy_vertices(rig, player, false)
	if player:
		out.append_array(Fixture.proxy_vertices(rig, player, true))
	return out


func _worst_gap(a: PackedVector3Array, b: PackedVector3Array) -> float:
	assert_eq(a.size(), b.size(), "the same vertices")
	var worst := 0.0
	for i: int in mini(a.size(), b.size()):
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst


## The rig's pose at the table's rest (no rotations, hips at rest), rig space at its scale.
func _rest_globals(rig: HumanoidRig) -> Array[Transform3D]:
	var empty: Dictionary[StringName, Vector3] = {}
	var table := PlaceholderBody.pose_globals(empty, Vector3.ZERO, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


## `animation` (a named one) played on `rig` and held `at` seconds in.
func _pose(rig: HumanoidRig, animation: StringName, at: float) -> void:
	rig.play(animation, 0.0)
	rig.advance(0.0)
	rig.advance(at)


func _move(id: StringName, startup: int, active: int, recovery: int) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup = startup
	move.active = active
	move.recovery = recovery
	return move


# --- Attaching ----------------------------------------------------------------------------


func test_the_probe_art_passes_check_in_every_variant() -> void:
	for authored: int in [Fixture.Authored.REST, Fixture.Authored.A_POSE]:
		for player: bool in [false, true]:
			for smooth: bool in [false, true]:
				var art := _art(authored, player, smooth)
				assert_eq(SkinnedArt.check(art), PackedStringArray(), "authored %d, player %s, smooth %s" % [authored, player, smooth])


func test_attach_adds_the_art_as_skinned_meshes_on_the_rigs_skeleton() -> void:
	var art := _art()
	var rig := _rig(art)
	assert_true(rig.has_art())
	var meshes := rig.art_meshes()
	assert_eq(meshes.size(), 1, "one GLB mesh, one art mesh")
	var mi := meshes[0]
	assert_eq(mi.name, &"ArtBody")
	assert_eq(mi.get_parent(), rig.skeleton, "a child of the rig's skeleton, never the GLB's own")
	assert_eq(mi.get_node(mi.skeleton), rig.skeleton, "bound to it explicitly")
	assert_not_null(mi.skin)
	assert_true(mi.is_in_group(HumanoidRig.ART_GROUP))
	assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_same(mi.material_override, rig.paint.art_material(), "the rig's art material")
	assert_eq(mi.material_overlay, rig.paint.outline_material(), "the rig's outline (none yet)")
	assert_eq(rig.skeleton.find_children("*", "Skeleton3D", true, false).size(), 0, "the GLB's own skeleton is never under the rig")
	assert_eq(rig.find_children("Armature", "", true, false).size(), 0)
	assert_true(mi.visible)
	var proxies := _proxies(rig)
	assert_eq(proxies.size(), PlaceholderBody.parts(false).size(), "every primitive stays built, as a view proxy")
	for proxy: MeshInstance3D in proxies:
		assert_false(proxy.visible, "%s is hidden while the art shows" % proxy.name)
	assert_true(rig.paint.base_materials().has(rig.paint.art_material()), "the flash passes reach the art's material")


func test_attach_adds_nothing_without_a_scene_and_the_rig_keeps_its_primitives() -> void:
	var art := CharacterArt.new()
	art.palette = Fixture.atlas()
	art.triangle_budget = 100
	var rig := _rig(art)
	assert_false(rig.has_art())
	assert_eq(SkinnedArt.attach(rig, art).size(), 0)
	for proxy: MeshInstance3D in _proxies(rig):
		assert_true(proxy.visible, "%s stays drawn while no art attaches" % proxy.name)
	assert_eq(SkinnedArt.check(art), PackedStringArray(["the art has no scene"]))
	assert_eq(SkinnedArt.check(null), PackedStringArray(["no art"]))


func test_an_art_that_breaks_the_contract_does_not_attach_and_the_rig_keeps_its_primitives() -> void:
	var art := _art()
	art.triangle_budget = 10
	assert_false(SkinnedArt.check(art).is_empty())
	var rig := _rig(art)
	assert_false(rig.has_art(), "over budget: not attached")
	for proxy: MeshInstance3D in _proxies(rig):
		assert_true(proxy.visible)
	assert_push_warning_count(1)


func test_the_player_art_is_two_meshes_and_the_fp_hidden_one_goes_on_the_head_layer() -> void:
	var rig := _rig(_art(Fixture.Authored.REST, true), 1.8, true)
	var by_name: Dictionary[StringName, MeshInstance3D] = {}
	for mi: MeshInstance3D in rig.art_meshes():
		by_name[mi.name] = mi
	assert_eq(by_name.keys().size(), 2)
	assert_true(by_name.has(&"ArtBody") and by_name.has(&"ArtBody__fp_hidden"))
	var hidden_layer := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	var default_layer := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	assert_eq(by_name[&"ArtBody__fp_hidden"].layers, hidden_layer, "hidden from the first-person camera")
	assert_eq(by_name[&"ArtBody"].layers, default_layer)
	assert_true(by_name[&"ArtBody__fp_hidden"].is_visible_in_tree(), "still drawn (it casts the shadow)")
	assert_eq(by_name[&"ArtBody__fp_hidden"].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	rig.first_person_body = false
	assert_eq(by_name[&"ArtBody__fp_hidden"].layers, default_layer, "the first_person_body setter treats it like the primitives")
	rig.first_person_body = true
	assert_eq(by_name[&"ArtBody__fp_hidden"].layers, hidden_layer)


func test_the_hidden_mesh_holds_the_fp_hidden_parts_and_the_visible_one_the_rest() -> void:
	var art := _art(Fixture.Authored.REST, true)
	var rig := _rig(art, 1.8, true)
	var hidden_parts := 0
	for part: PlaceholderBody.Part in PlaceholderBody.parts(true):
		if PlaceholderBody.is_fp_hidden(part):
			hidden_parts += 1
	assert_gt(hidden_parts, 5)
	var hidden_proxies := 0
	for proxy: MeshInstance3D in _proxies(rig):
		if proxy.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN):
			hidden_proxies += 1
	assert_eq(hidden_proxies, hidden_parts, "the proxies and the art split the body the same way")


func test_the_skin_keeps_the_glbs_bind_order_and_binds_by_the_chained_formula() -> void:
	for authored: int in [Fixture.Authored.REST, Fixture.Authored.A_POSE]:
		var pose := Fixture.a_pose() if authored == Fixture.Authored.A_POSE else Fixture.empty_pose()
		var joints := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)
		for height: float in HEIGHTS:
			var rig := _rig(_art(authored), height)
			var s := rig.rig_scale()
			var skin := rig.art_meshes()[0].skin
			var order := Fixture.bind_order()
			assert_eq(skin.get_bind_count(), 23)
			for i: int in skin.get_bind_count():
				assert_eq(StringName(skin.get_bind_name(i)), order[i], "bind %d is the GLB's %s (not the skeleton's)" % [i, order[i]])
				# The swing is the authored pose's own rotation of the bone; bind' = Scale(s) *
				# Transform3D(Basis(R_n), p_n)^-1.
				var expected := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO) \
						* Transform3D(joints[order[i]].basis, joints[order[i]].origin).affine_inverse()
				var bind := skin.get_bind_pose(i)
				for axis: int in 3:
					assert_almost_eq(bind.basis[axis], expected.basis[axis], Vector3.ONE * 1e-5, "%s basis column %d (authored %d, %.2f m)" % [order[i], axis, authored, height])
				assert_almost_eq(bind.origin, expected.origin, Vector3.ONE * 1e-5, "%s origin (authored %d, %.2f m)" % [order[i], authored, height])


func test_the_a_pose_binds_swing_the_arm_chains_and_nothing_else() -> void:
	var entry := SkinnedArt.entry_of(_art(Fixture.Authored.A_POSE))
	var part := entry.meshes[0]
	for i: int in part.bind_names.size():
		var bone := part.bind_names[i]
		var swung := String(bone).ends_with("UpperArm") or String(bone).ends_with("LowerArm") or String(bone).ends_with("Hand")
		if swung:
			var angle := rad_to_deg(part.bind_rotations[i].get_angle())
			assert_almost_eq(angle, Fixture.A_POSE_SWING_DEG, 0.01, "%s is swung by the pose" % bone)
		else:
			assert_almost_eq(part.bind_rotations[i].get_angle(), 0.0, 1e-4, "%s is not" % bone)
	var rest_entry := SkinnedArt.entry_of(_art(Fixture.Authored.REST))
	for i: int in rest_entry.meshes[0].bind_names.size():
		assert_almost_eq(rest_entry.meshes[0].bind_rotations[i].get_angle(), 0.0, 1e-4, "authored at the table: R is the identity")


# --- CPU skinning equals the rig's FK -------------------------------------------------------


func test_skinned_vertices_land_on_the_primitives_at_the_tables_rest_at_every_height() -> void:
	for authored: int in [Fixture.Authored.REST, Fixture.Authored.A_POSE]:
		for player: bool in [false, true]:
			for height: float in HEIGHTS:
				var rig := _rig(_art(authored, player), height, player)
				# The primitives at the rest pose: the proxies' own arrays at the rest globals.
				var empty := _rest_globals(rig)
				var expected := PackedVector3Array()
				for hidden: bool in [false, true]:
					for part: PlaceholderBody.Part in PlaceholderBody.parts(player):
						if player and PlaceholderBody.is_fp_hidden(part) != hidden:
							continue
						if not player and hidden:
							continue
						var proxy := rig.find_child(String(part.name), true, false) as MeshInstance3D
						var local := Transform3D(PlaceholderBody.euler_basis(part.rot_deg), part.offset * rig.rig_scale())
						var bone := empty[rig.skeleton.find_bone(part.bone)] as Transform3D
						expected.append_array((bone * local) * (proxy.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array))
				var gap := _worst_gap(_skinned(rig, player, empty), expected)
				assert_lt(gap, EXACT_M, "authored %d, player %s, %.2f m: the art at the rest is the primitive body (worst %.5f m)" % [authored, player, height, gap])


func test_skinned_vertices_follow_the_animation_exactly_at_idle_jab_and_flinch() -> void:
	for authored: int in [Fixture.Authored.REST, Fixture.Authored.A_POSE]:
		for player: bool in [false, true]:
			var rig := _rig(_art(authored, player), 1.8, player)
			var jab := _move(&"jab_1", 4, 3, 10)
			for label: String in ["idle", "jab", "flinch_gut", "knockdown_back", "guard"]:
				match label:
					"idle":
						_pose(rig, &"idle", 0.4)
					"jab":
						rig.play(&"idle", 0.0)
						rig.advance(0.5)
						rig.play_move(jab)
						for i: int in jab.startup + 1:
							rig.advance(FRAME)
					"guard":
						_pose(rig, &"block", 0.3)
					_:
						_pose(rig, StringName(label), 0.2)
				var gap := _worst_gap(_skinned(rig, player), _expected(rig, player))
				assert_lt(gap, EXACT_M, "authored %d, player %s, %s: the skin is the FK (worst %.5f m)" % [authored, player, label, gap])


func test_skinned_vertices_follow_a_scaled_rig_at_a_pose() -> void:
	for height: float in [2.05, 2.3]:
		var rig := _rig(_art(Fixture.Authored.A_POSE), height)
		_pose(rig, &"block", 0.3)
		var gap := _worst_gap(_skinned(rig, false), _expected(rig, false))
		assert_lt(gap, EXACT_M, "%.2f m: the binds carry the scale (worst %.5f m)" % [height, gap])


# --- check() ------------------------------------------------------------------------------


## `art` with its scene changed by `mutate(root)`.
func _mutated(art: CharacterArt, mutate: Callable) -> CharacterArt:
	var root := art.scene.instantiate()
	mutate.call(root)
	var scene := PackedScene.new()
	for node: Node in root.find_children("*", "", true, false):
		node.owner = root
	scene.pack(root)
	root.free()
	var out := CharacterArt.new()
	out.id = art.id
	out.scene = scene
	out.palette = art.palette
	out.triangle_budget = art.triangle_budget
	return out


func _body(root: Node) -> MeshInstance3D:
	return root.find_child("Body", true, false) as MeshInstance3D


## The skin of `mi` rebuilt with `change(i, name, bind)` -> [name, bind] for every bind.
func _reskin(mi: MeshInstance3D, change: Callable) -> void:
	var skin := Skin.new()
	for i: int in mi.skin.get_bind_count():
		var row: Array = change.call(i, StringName(mi.skin.get_bind_name(i)), mi.skin.get_bind_pose(i))
		if row.is_empty():
			continue
		skin.add_named_bind(row[0], row[1])
	mi.skin = skin


func _problems_of(art: CharacterArt) -> String:
	return "; ".join(SkinnedArt.check(art))


func test_check_names_a_neutral_bone_and_an_unknown_bind_and_never_aliases_them() -> void:
	var neutral := _mutated(_art(), func(root: Node) -> void:
		_reskin(_body(root), func(i: int, bone: StringName, bind: Transform3D) -> Array:
			return [&"neutral_bone" if bone == &"Root" else bone, bind]))
	assert_string_contains(_problems_of(neutral), "neutral_bone")
	var unknown := _mutated(_art(), func(root: Node) -> void:
		_reskin(_body(root), func(i: int, bone: StringName, bind: Transform3D) -> Array:
			return [&"mixamorig_Hips" if bone == &"Hips" else bone, bind]))
	assert_string_contains(_problems_of(unknown), "mixamorig_Hips")
	var missing := _mutated(_art(), func(root: Node) -> void:
		_reskin(_body(root), func(i: int, bone: StringName, bind: Transform3D) -> Array:
			return [] if bone == &"LeftToes" else [bone, bind]))
	assert_string_contains(_problems_of(missing), "LeftToes")
	var rig := _rig(neutral)
	assert_false(rig.has_art(), "a neutral_bone art never attaches")
	assert_push_warning_count(1)


func test_check_tests_the_chained_joint_rule_not_joints_on_the_table() -> void:
	# A 5 mm move of the left elbow joint breaks the chain from the shoulder (and the next link
	# of it, which the elbow's own swing leaves the wrist 5 mm off).
	var off := _mutated(_art(Fixture.Authored.A_POSE), func(root: Node) -> void:
		_reskin(_body(root), func(i: int, bone: StringName, bind: Transform3D) -> Array:
			if bone != &"LeftLowerArm":
				return [bone, bind]
			var pose := bind.affine_inverse()
			pose.origin += Vector3(0.005, 0.0, 0.0)
			return [bone, pose.affine_inverse()]))
	assert_string_contains(_problems_of(off), "LeftLowerArm")
	assert_string_contains(_problems_of(off), "off the table chained through the swing")
	# A joint 0.5 mm off passes (within the 1 mm).
	var near := _mutated(_art(Fixture.Authored.A_POSE), func(root: Node) -> void:
		_reskin(_body(root), func(i: int, bone: StringName, bind: Transform3D) -> Array:
			if bone != &"LeftLowerArm":
				return [bone, bind]
			var pose := bind.affine_inverse()
			pose.origin += Vector3(0.0003, 0.0, 0.0)
			return [bone, pose.affine_inverse()]))
	assert_eq(SkinnedArt.check(near), PackedStringArray(), "0.3 mm off is inside the tolerance")
	# The A-pose arms are fine as they are chained; a mesh authored at the table whose arm is
	# swung without its joints following would fail: the elbow left at the table while the
	# shoulder-to-wrist direction is swung.
	var stuck := _mutated(_art(Fixture.Authored.A_POSE), func(root: Node) -> void:
		_reskin(_body(root), func(i: int, bone: StringName, bind: Transform3D) -> Array:
			if bone != &"RightHand":
				return [bone, bind]
			var rest := PlaceholderBody.pose_globals(Fixture.empty_pose(), Vector3.ZERO, 1.0)
			return [bone, Transform3D(Basis.IDENTITY, rest[&"RightHand"].origin).affine_inverse()]))
	assert_string_contains(_problems_of(stuck), "RightHand")


func test_check_names_weight_problems_and_the_budget() -> void:
	var unweighted := _mutated(_art(), func(root: Node) -> void:
		_edit_arrays(root, func(arrays: Array) -> void:
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for j: int in 4:
				weights[j] = 0.0
			arrays[Mesh.ARRAY_WEIGHTS] = weights))
	assert_string_contains(_problems_of(unweighted), "no weight")
	var on_root := _mutated(_art(), func(root: Node) -> void:
		_edit_arrays(root, func(arrays: Array) -> void:
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			bones[0] = Fixture.bind_order().find(&"Root")
			arrays[Mesh.ARRAY_BONES] = bones))
	assert_string_contains(_problems_of(on_root), "Root")
	var unnormalized := _mutated(_art(), func(root: Node) -> void:
		_edit_arrays(root, func(arrays: Array) -> void:
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			weights[0] = 0.5
			arrays[Mesh.ARRAY_WEIGHTS] = weights))
	assert_string_contains(_problems_of(unnormalized), "sum to 1")
	var over := _art()
	over.triangle_budget -= 1
	assert_string_contains(_problems_of(over), "over the budget")
	var no_palette := _art()
	no_palette.palette = null
	assert_string_contains(_problems_of(no_palette), "palette")
	var no_uv := _mutated(_art(), func(root: Node) -> void:
		_edit_arrays(root, func(arrays: Array) -> void:
			arrays[Mesh.ARRAY_TEX_UV] = null))
	assert_string_contains(_problems_of(no_uv), "UV1")
	var eight := _mutated(_art(), func(root: Node) -> void:
		_edit_arrays(root, func(arrays: Array) -> void:
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var wide_bones := PackedInt32Array()
			var wide_weights := PackedFloat32Array()
			for v: int in bones.size() / 4:
				wide_bones.append_array(bones.slice(v * 4, v * 4 + 4))
				wide_bones.append_array(PackedInt32Array([0, 0, 0, 0]))
				wide_weights.append_array(weights.slice(v * 4, v * 4 + 4))
				wide_weights.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
			arrays[Mesh.ARRAY_BONES] = wide_bones
			arrays[Mesh.ARRAY_WEIGHTS] = wide_weights, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS))
	assert_string_contains(_problems_of(eight), "8 influences")


## Rebuild the Body mesh of `root` from its arrays after `change(arrays)` (and with `flags`).
func _edit_arrays(root: Node, change: Callable, flags: int = 0) -> void:
	var mi := _body(root)
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	change.call(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mi.mesh = mesh
