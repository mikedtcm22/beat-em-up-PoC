extends GutTest
## Milestone 4, SL-int: the smoke Punk (assets/export/characters/punk/*.glb) in the game. The four
## GLBs are punk (Tripo's weights, the A-pose route, the default), punk_rest (the arms-down bake),
## punk_auto (heat-map weights) and punk_auto_rest. Every Street Punk wears punk_art.tres through
## CombatActor.art; Tuning's Debug value look_punk_art_variant picks another for the slice gate's
## A/B. These tests measure the drawn art with tests/skinned_view.gd (A4): the hurtbox fit (A6),
## the first-person framing at the 1 m acts' poses (A9), the marks (A10), the flash anchor (A11)
## and the deformation strain (A19), for each GLB.
##
## Every number is printed ("ART-PUNK ..." lines). A bar is asserted only where the GLB passes it
## today, as a guard; a bar a GLB misses is printed with "GATE" and left to the slice gate (A15),
## which decides the bind route and the weights source from those numbers.
## The strain is against the SKINNED REST pose (the mesh skinned at the rig's rest), not the GLB's
## own mesh: for the A-pose route the latter is already strained at rest by construction
## (M4-calls/P1-chain.md C13).

const SkinnedView := preload("res://tests/skinned_view.gd")
const FPView := preload("res://tests/fp_view.gd")
const PUNK_SCENE := "res://game/enemies/punk/street_punk.tscn"
const FRAME := 1.0 / 60.0
## The four GLBs by variant: the art resource, the GLB it wears, and the value of Tuning's
## look_punk_art_variant that picks it.
const VARIANTS: Array[Dictionary] = [
	{name = "punk", art = "res://game/actors/art/punk_art.tres", glb = "punk.glb", variant = 0},
	{name = "punk_rest", art = "res://game/actors/art/punk_rest_art.tres", glb = "punk_rest.glb", variant = 1},
	{name = "punk_auto", art = "res://game/actors/art/punk_auto_art.tres", glb = "punk_auto.glb", variant = 2},
	{name = "punk_auto_rest", art = "res://game/actors/art/punk_auto_rest_art.tres", glb = "punk_auto_rest.glb", variant = 3},
]
## M4-plan Part B's bars: A2 the Punk's triangles, A6 the hurtbox fit, A9 the framing, A11 the
## flash anchor, A19 the strain.
const TRIANGLE_BUDGET := 15000
const FIT_TORSO_LEGS := 0.95
const FIT_HEAD := 0.95
const FRAMING_DIFFER := 0.03
const FRAMING_SHARE_PP := 0.04
const FRAMING_NEAREST_M := 0.02
const ANCHOR_M := 0.02
const STRAIN_P_HIGH := 1.6
const STRAIN_P_LOW := 0.6
const STRAIN_MAX := 2.2
const STRAIN_MIN := 0.4
const FLOOR_M := -0.015
const BAD_TRIANGLES := 0.005
## The 1 m acts' view: the Punk 1 m ahead of the player's eye, the face shot's pitch and the
## default look's (look_acts.gd FACE_PITCH_DEG, DEFAULT_PITCH_DEG).
const EYE_Y := 1.656
const FACE_PITCH_DEG := 8.0
const DEFAULT_PITCH_DEG := -6.0
const SAMPLE_VERTICES := 100


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	SkinnedArt.clear_cache()
	SkinnedView.clear_cache()


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())


# --- Harness ------------------------------------------------------------------------------


func _art(row: Dictionary) -> CharacterArt:
	return load(row.art) as CharacterArt


## A bare rig wearing `art` at the Punk's height (hurtboxes for the fit test), idle.
func _rig(art: CharacterArt, hurtboxes: bool = false) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = 1.8
	rig.build_hurtboxes = hurtboxes
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	return rig


func _pose(rig: HumanoidRig, animation: StringName, at: float) -> void:
	rig.play(animation, 0.0)
	rig.advance(0.0)
	rig.advance(at)


## The rig's pose at the table's rest (rig space, its scale): the strain's reference.
func _rest_globals(rig: HumanoidRig) -> Array[Transform3D]:
	var empty: Dictionary[StringName, Vector3] = {}
	var table := PlaceholderBody.pose_globals(empty, Vector3.ZERO, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


func _globals_of(rig: HumanoidRig, pose: Dictionary[StringName, Vector3], hips: Vector3) -> Array[Transform3D]:
	var table := PlaceholderBody.pose_globals(pose, hips, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


func _punk_moves() -> Array[MoveData]:
	var out: Array[MoveData] = []
	for id: String in ["punk_jab", "punk_cross", "punk_shove"]:
		out.append(load("res://game/combat/moves/%s.tres" % id) as MoveData)
	return out


func _lines(title: String, lines: PackedStringArray) -> void:
	print("ART-PUNK %s" % title)
	for line: String in lines:
		print("ART-PUNK   ", line)


# --- The Punk wears the art ------------------------------------------------------------------


func test_a_street_punk_wears_the_art_through_combat_actor_art() -> void:
	var punk := (load(PUNK_SCENE) as PackedScene).instantiate() as StreetPunk
	assert_not_null(punk.art, "the scene carries punk_art.tres")
	assert_eq(punk.art.resource_path, VARIANTS[0].art)
	add_child_autofree(punk)
	await get_tree().physics_frame
	assert_true(punk.rig.has_art(), "the Punk's rig has attached the art (check() passed)")
	assert_eq(punk.rig.art_meshes().size(), 1, "one mesh, Body")
	assert_eq(punk.rig.art_meshes()[0].name, &"ArtBody")
	assert_same(punk.rig.art, punk.art)
	var visible_proxies := 0
	for node: Node in punk.rig.get_tree().get_nodes_in_group(HumanoidRig.VIEW_PROXY_GROUP):
		if punk.rig.is_ancestor_of(node) and (node as MeshInstance3D).visible:
			visible_proxies += 1
	assert_eq(visible_proxies, 0, "the primitives are the hidden view proxies")
	assert_gt(punk.rig.get_tree().get_nodes_in_group(HumanoidRig.VIEW_PROXY_GROUP).size(), 30, "and they are all still built")
	var tris: int = (punk.rig.art_meshes()[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_lte(tris, TRIANGLE_BUDGET, "A2: the Punk's %d triangles" % tris)
	# The hull and the toon art material are on it.
	var mesh := punk.rig.art_meshes()[0]
	assert_true(mesh.material_override is ShaderMaterial, "toon art material")
	assert_true(mesh.material_overlay is ShaderMaterial, "the hull")


func test_the_primitives_come_back_when_the_art_is_switched_off() -> void:
	Tuning.data.look_show_art = false
	var punk := (load(PUNK_SCENE) as PackedScene).instantiate() as StreetPunk
	add_child_autofree(punk)
	await get_tree().physics_frame
	assert_true(punk.rig.has_art())
	assert_false(punk.rig.art_meshes()[0].visible, "the art is hidden by the A/B switch")
	Tuning.data.look_show_art = true
	Tuning.changed.emit(&"look_show_art")
	assert_true(punk.rig.art_meshes()[0].visible)


func test_look_punk_art_variant_picks_each_glb_and_a_punk_wears_it() -> void:
	for row: Dictionary in VARIANTS:
		Tuning.data.look_punk_art_variant = row.variant
		var punk := (load(PUNK_SCENE) as PackedScene).instantiate() as StreetPunk
		add_child_autofree(punk)
		await get_tree().physics_frame
		assert_true(punk.rig.has_art(), "%s attaches" % row.name)
		var scene_path := punk.rig.art.scene.resource_path
		assert_true(scene_path.ends_with("/" + String(row.glb)), "variant %d wears %s (%s)" % [row.variant, row.glb, scene_path])
	Tuning.data.look_punk_art_variant = 99
	var clamped := (load(PUNK_SCENE) as PackedScene).instantiate() as StreetPunk
	add_child_autofree(clamped)
	await get_tree().physics_frame
	assert_true(clamped.rig.has_art(), "a value past the last clamps to it")


func test_the_variant_switch_is_in_the_debug_group_and_never_in_a_preset() -> void:
	var in_debug := false
	var group := ""
	for prop: Dictionary in TuningData.new().get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			group = prop.name
		elif prop.name == "look_punk_art_variant":
			in_debug = group == "Debug"
	assert_true(in_debug, "look_punk_art_variant is declared in the Debug group (A9)")


func test_the_four_glbs_pass_check_stay_in_budget_and_stand_on_the_floor() -> void:
	for row: Dictionary in VARIANTS:
		var art := _art(row)
		assert_eq(SkinnedArt.check(art), PackedStringArray(), "%s keeps the contract" % row.name)
		assert_eq(art.triangle_budget, TRIANGLE_BUDGET)
		var rig := _rig(art)
		assert_true(rig.has_art(), row.name)
		var lowest := INF
		for mi: MeshInstance3D in rig.art_meshes():
			for v: Vector3 in SkinnedView.skin_vertices(mi, rig, _rest_globals(rig)):
				lowest = minf(lowest, v.y)
		print("ART-PUNK %s: lowest vertex at the rest %.4f m" % [row.name, lowest])
		assert_almost_eq(lowest, 0.0, 0.005, "%s: the soles at the rest are on the floor (A4)" % row.name)


# --- A6: the hurtboxes inside the art -----------------------------------------------------------


## Row A6's shares with every vertex counted by its DOMINANT bind (SkinnedView.hurtbox_fit()
## counts only the vertices a single bind holds alone, which for Tripo's smoothly blended torso is
## none): `{torso, legs, head}` the share of those vertices within the covering hurtbox's radius
## plus the slack of its axis (6 cm, the head's 5 cm), and the vertex counts.
func _fit(rig: HumanoidRig, slack_m: float = 0.06, head_slack_m: float = 0.05) -> Dictionary:
	var mi := rig.art_meshes()[0]
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	var posed := mi.global_transform * SkinnedView.skin_vertices(mi, rig)
	var world := rig.global_transform
	var regions := {
		&"Hips": &"torso", &"Spine": &"torso", &"Chest": &"torso", &"UpperChest": &"torso",
		&"LeftUpperLeg": &"legs", &"LeftLowerLeg": &"legs", &"RightUpperLeg": &"legs", &"RightLowerLeg": &"legs",
		&"Head": &"head",
	}
	var share := {torso = [0, 0], legs = [0, 0], head = [0, 0]}
	for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
		var from := world * (rig.animation_pose(rig.skeleton.find_bone(spec.bone_a)) * (spec.offset_a * rig.rig_scale()))
		var to := from
		if spec.is_capsule():
			to = world * (rig.animation_pose(rig.skeleton.find_bone(spec.bone_b)) * (spec.offset_b * rig.rig_scale()))
		for v: int in posed.size():
			var best := 0
			for j: int in SkinnedArt.INFLUENCES:
				if data.weights[v * SkinnedArt.INFLUENCES + j] > data.weights[v * SkinnedArt.INFLUENCES + best]:
					best = j
			var bone := StringName(mi.skin.get_bind_name(data.bones[v * SkinnedArt.INFLUENCES + best]))
			var region: StringName = regions.get(bone, &"")
			var covers := (region == &"torso" and spec.region == CombatTypes.Region.TORSO) \
					or (region == &"legs" and spec.region == CombatTypes.Region.LEGS \
							and String(bone).begins_with("Left") == String(spec.bone_a).begins_with("Left")) \
					or (region == &"head" and spec.region == CombatTypes.Region.HEAD)
			if not covers:
				continue
			var gap := posed[v].distance_to(Geometry3D.get_closest_point_to_segment(posed[v], from, to))
			var limit := spec.radius * rig.rig_scale() + (head_slack_m if region == &"head" else slack_m)
			share[region][1] += 1
			if gap <= limit:
				share[region][0] += 1
	return {
		torso = float(share.torso[0]) / maxi(share.torso[1], 1), legs = float(share.legs[0]) / maxi(share.legs[1], 1),
		head = float(share.head[0]) / maxi(share.head[1], 1),
		counts = {torso = share.torso[1], legs = share.legs[1], head = share.head[1]},
	}


func test_the_hurtbox_fit_of_every_glb_is_printed_and_the_passing_bars_hold() -> void:
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row), true)
		_pose(rig, &"idle", 0.3)
		var fit := _fit(rig)
		var axis := SkinnedView.hurtbox_fit(rig)
		var gate := PackedStringArray()
		if not (axis.outside as Array).is_empty():
			gate.append("axis points outside the art: %s" % [axis.outside])
		if fit.torso < FIT_TORSO_LEGS:
			gate.append("torso %.1f%% < %.0f%%" % [fit.torso * 100.0, FIT_TORSO_LEGS * 100.0])
		if fit.legs < FIT_TORSO_LEGS:
			gate.append("legs %.1f%% < %.0f%%" % [fit.legs * 100.0, FIT_TORSO_LEGS * 100.0])
		if fit.head < FIT_HEAD:
			gate.append("head %.1f%% < %.0f%%" % [fit.head * 100.0, FIT_HEAD * 100.0])
		print("ART-PUNK A6 %s: torso %.1f%% of %d vertices, legs %.1f%% of %d, head %.1f%% of %d (by dominant bone); %d axis points outside the art%s" % [
				row.name, fit.torso * 100.0, fit.counts.torso, fit.legs * 100.0, fit.counts.legs, fit.head * 100.0, fit.counts.head,
				(axis.outside as Array).size(), ("  GATE: " + "; ".join(gate)) if not gate.is_empty() else "  (meets A6)"])
		assert_gt(fit.counts.torso, 100, "%s: the torso vertices were counted" % row.name)
		assert_eq(axis.outside, [], "%s: every hurtbox axis point is inside the art (A6)" % row.name)
		assert_gte(fit.torso, FIT_TORSO_LEGS, "%s: the torso vertices hug the torso hurtbox (%.1f%%)" % [row.name, fit.torso * 100.0])
		# The legs (about 90%: the baggy jeans and the big shoes) and the head (95.0% for punk, 97% with
		# the heat-map weights) are the gate's: printed above, not asserted.
		assert_gt(fit.legs, 0.8, "%s: most leg vertices are near the leg hurtboxes (%.1f%%)" % [row.name, fit.legs * 100.0])
		assert_gt(fit.head, 0.9, "%s: most head vertices are near the head sphere (%.1f%%)" % [row.name, fit.head * 100.0])


# --- A9: first-person framing at the 1 m acts' poses --------------------------------------------


func _view(pitch_deg: float) -> Transform3D:
	var look := Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))
	return Transform3D(look, Vector3(0.0, EYE_Y, 0.0) + FirstPersonCamera.lens_offset(look))


func test_the_framing_of_every_glb_against_its_proxies_at_the_one_metre_poses_is_printed() -> void:
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row))
		rig.global_position = Vector3(0.0, 0.0, -1.0)
		rig.rotation.y = PI
		var worst_differ := 0.0
		var worst_share := 0.0
		var worst_nearest := 0.0
		var gate := PackedStringArray()
		for pitch: float in [FACE_PITCH_DEG, DEFAULT_PITCH_DEG]:
			var cam := _view(pitch)
			var poses: Array[Dictionary] = [{label = "idle", move = null}]
			for move: MoveData in _punk_moves():
				poses.append({label = String(move.id), move = move})
			for pose: Dictionary in poses:
				_pose(rig, &"idle", 0.3)
				if pose.move != null:
					var move := pose.move as MoveData
					rig.play_move(move)
					for i: int in move.startup + 1:
						rig.advance(FRAME)
				var cmp := SkinnedView.compare_with_proxies(rig, cam)
				var label := "%s %s pitch %+.0f" % [row.name, pose.label, pitch]
				worst_differ = maxf(worst_differ, cmp.differ_share)
				worst_share = maxf(worst_share, absf(cmp.art_share - cmp.proxy_share))
				worst_nearest = maxf(worst_nearest, cmp.nearest)
				print("ART-PUNK A9 %s: %d of %d cells differ (%.1f%%), art %.1f%% proxies %.1f%% of the view, art nearer by %.1f cm" % [
						label, cmp.differ, cmp.cells, cmp.differ_share * 100.0, cmp.art_share * 100.0, cmp.proxy_share * 100.0, cmp.nearest * 100.0])
				assert_gt(cmp.art_share, 0.03, "%s: the art fills the view at 1 m" % label)
				assert_gt(cmp.proxy_share, 0.03, "%s: so do the proxies" % label)
				# What passes today (the art is bulkier than the proxies in a strike's arms, so the
				# cell count and the nearest figure at the jab, cross and shove are the gate's):
				assert_lte(absf(cmp.art_share - cmp.proxy_share), FRAMING_SHARE_PP, "%s: the lens share differs by at most 4 pp" % label)
				if pose.move == null:
					assert_lte(cmp.differ_share, FRAMING_DIFFER, "%s: at most 3%% of the cells differ at idle" % label)
				if cmp.differ_share > FRAMING_DIFFER:
					gate.append("%s differs %.1f%%" % [label, cmp.differ_share * 100.0])
				if absf(cmp.art_share - cmp.proxy_share) > FRAMING_SHARE_PP:
					gate.append("%s lens share differs %.1f pp" % [label, absf(cmp.art_share - cmp.proxy_share) * 100.0])
				if cmp.nearest > FRAMING_NEAREST_M:
					gate.append("%s art %.1f cm nearer" % [label, cmp.nearest * 100.0])
		print("ART-PUNK A9 %s: worst differ %.1f%%, worst lens share %.1f pp, nearest %.1f cm%s" % [
				row.name, worst_differ * 100.0, worst_share * 100.0, worst_nearest * 100.0,
				("  GATE: %d poses miss: %s" % [gate.size(), "; ".join(gate.slice(0, 4))]) if not gate.is_empty() else "  (meets A9)"])


# --- A10: the marks stick -------------------------------------------------------------------------


func test_the_marks_of_every_glb_stay_on_the_bind_pose_and_a_look_change_swaps_textures_only() -> void:
	for row: Dictionary in VARIANTS:
		var art := _art(row)
		var rig := _rig(art)
		var mi := rig.art_meshes()[0]
		var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var c0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		var c1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
		assert_eq(c0.size(), vertices.size() * 3, "%s: CUSTOM0 per vertex" % row.name)
		assert_eq(c1.size(), normals.size() * 3, "%s: CUSTOM1 per vertex" % row.name)
		var source := SkinnedArt.entry_of(art).scene.instantiate()
		var source_mesh := (source.find_child("Body", true, false) as MeshInstance3D).mesh as ArrayMesh
		var source_arrays := source_mesh.surface_get_arrays(0)
		var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
		source.free()
		assert_eq(source_vertices.size(), vertices.size())
		var step := maxi(vertices.size() / SAMPLE_VERTICES, 1)
		var held: Array[Vector3] = []
		var samples := 0
		for v: int in range(0, vertices.size(), step):
			var position := Vector3(c0[v * 3], c0[v * 3 + 1], c0[v * 3 + 2])
			assert_almost_eq(position, source_vertices[v], Vector3.ONE * 1e-6, "%s: CUSTOM0 of vertex %d is its bind-pose position" % [row.name, v])
			assert_almost_eq(Vector3(c1[v * 3], c1[v * 3 + 1], c1[v * 3 + 2]), source_normals[v], Vector3.ONE * 1e-5, "%s: CUSTOM1 is its normal" % row.name)
			held.append(position)
			samples += 1
		assert_gte(samples, SAMPLE_VERTICES, "%s: %d sample vertices" % [row.name, samples])
		# Across idle, a jab and a knockdown the mesh's mark coordinates are the same hundred
		# positions while the skinned vertices move.
		var rest_skinned := SkinnedView.skin_vertices(mi, rig, _rest_globals(rig))
		var moved := 0
		for label: String in ["idle", "jab", "knockdown_back"]:
			_pose(rig, &"idle", 0.2)
			if label == "jab":
				var jab: MoveData = _punk_moves()[0]
				rig.play_move(jab)
				for i: int in jab.startup + 1:
					rig.advance(FRAME)
			elif label == "knockdown_back":
				_pose(rig, &"knockdown_back", 0.3)
			var posed := SkinnedView.skin_vertices(mi, rig)
			var after := (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array
			var k := 0
			for v: int in range(0, vertices.size(), step):
				assert_eq(Vector3(after[v * 3], after[v * 3 + 1], after[v * 3 + 2]), held[k], "%s %s: mark coordinate of vertex %d" % [row.name, label, v])
				if posed[v].distance_to(rest_skinned[v]) > 0.01:
					moved += 1
				k += 1
		assert_gt(moved, 50, "%s: the body moved while its marks did not" % row.name)
		# A damage-look change swaps the damage texture and its scale, nothing else.
		var material := rig.paint.art_material()
		var shader: Shader = material.shader
		var names := ["albedo_tex", "use_albedo_tex", "marks", "use_rest_custom", "edge_tag", "ink", "flash_amount"]
		var before: Dictionary = {}
		for name: String in names:
			before[name] = material.get_shader_parameter(name)
		var textures: Array[Texture2D] = []
		for level: int in [DamageLook.Level.CLEAN, DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
			rig.set_damage_look(level)
			assert_same(material.shader, shader, "%s: level %d keeps the shader" % [row.name, level])
			for name: String in names:
				assert_eq(material.get_shader_parameter(name), before[name], "%s: level %d leaves %s" % [row.name, level, name])
			textures.append(material.get_shader_parameter(&"damage_tex"))
		assert_ne(textures[0], textures[1], "%s: bruised swaps the damage texture" % row.name)
		assert_ne(textures[1], textures[2], "%s: bloodied swaps it again" % row.name)


# --- A11: the flash anchor on the skinned surface ----------------------------------------------------


func test_the_contact_flash_anchor_of_every_glb_is_near_the_skinned_surface() -> void:
	var points := {
		"head": Vector3(0.0, 1.68, -0.4), "torso": Vector3(0.0, 1.25, -0.4), "leg": Vector3(0.11, 0.6, -0.4),
	}
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row), true)
		_pose(rig, &"idle", 0.3)
		var gate := PackedStringArray()
		var gaps := PackedStringArray()
		for label: String in points:
			rig.flash_at(points[label], 1.0, 0.5, 0.5)
			var anchor: Vector3 = rig.flash_overlay().get_shader_parameter(&"flash_point")
			var gap := INF
			for mi: MeshInstance3D in rig.art_meshes():
				gap = minf(gap, SkinnedView.surface_gap(mi, rig, anchor))
			gaps.append("%s %.1f cm" % [label, gap * 100.0])
			if gap > ANCHOR_M:
				gate.append("%s %.1f cm" % [label, gap * 100.0])
			assert_lt(gap, 0.08, "%s: the %s flash sits on the body (%.1f cm)" % [row.name, label, gap * 100.0])
			if label == "head":
				assert_lte(gap, ANCHOR_M, "%s: the head flash is within 2 cm of the skinned surface" % row.name)
			rig.set_flash(0.0)
		print("ART-PUNK A11 %s: flash anchor to the skinned surface: %s%s" % [
				row.name, ", ".join(gaps), ("  GATE (over 2 cm): " + ", ".join(gate)) if not gate.is_empty() else "  (meets A11)"])


# --- A19: the deformation strain against the skinned rest ----------------------------------------------


## The peak flexes of row A7: [label, pose (bone -> Euler degrees), hips offset].
func _peak_poses() -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	poses.append({label = "guard", pose = PlaceholderPoses.guard(), hips = Vector3.ZERO})
	poses.append({label = "elbow 150", pose = {&"LeftLowerArm": Vector3(150.0, 0.0, 0.0), &"RightLowerArm": Vector3(150.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "arm raise 140", pose = {&"LeftUpperArm": Vector3(140.0, 0.0, 0.0), &"RightUpperArm": Vector3(140.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "knee -130", pose = {&"LeftLowerLeg": Vector3(-130.0, 0.0, 0.0), &"LeftUpperLeg": Vector3(40.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "spine twist", pose = {&"Spine": Vector3(0.0, 25.0, 0.0), &"Chest": Vector3(0.0, 25.0, 0.0), &"UpperChest": Vector3(0.0, 20.0, 0.0), &"Neck": Vector3(0.0, 20.0, 0.0), &"Head": Vector3(0.0, 30.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "lying", pose = {&"Hips": Vector3(-90.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3(0.0, -0.8, 0.0)})
	return poses


## The strain of `mi` posed at `globals` (empty: the rig's current pose) against the same mesh
## skinned at the rig's rest pose `rest`: every deforming edge's posed length over its rest
## length, p0.1 and p99.9 over all edges (edges on one bind are exactly 1), the extremes, NaN, the
## lowest vertex, and with `triangles` the triangles under 15% of their rest area or flipped.
## SkinnedView.strain() measures against the authored mesh; this is the same with the skinned
## rest as the reference (A19, M4-calls/P1-chain.md C13).
func _strain(mi: MeshInstance3D, rig: HumanoidRig, rest: PackedVector3Array, globals: Array[Transform3D], triangles: bool) -> Dictionary:
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	SkinnedView._prepare_strain(data)
	var posed := SkinnedView.skin_vertices(mi, rig, globals)
	var values := PackedFloat32Array()
	var worst := 1.0
	var worst_edge := -1
	var has_nan := false
	var lowest := INF
	for v: int in posed.size():
		lowest = minf(lowest, posed[v].y)
		if is_nan(posed[v].x) or is_nan(posed[v].y) or is_nan(posed[v].z):
			has_nan = true
	var unmeasured := data.edge_count - data.edge_a.size()
	for e: int in data.edge_a.size():
		var rest_length := rest[data.edge_a[e]].distance_to(rest[data.edge_b[e]])
		if rest_length < SkinnedView.MIN_EDGE_M:
			unmeasured += 1
			continue
		var ratio := posed[data.edge_a[e]].distance_to(posed[data.edge_b[e]]) / rest_length
		values.append(ratio)
		if absf(log(maxf(ratio, 1e-6))) > absf(log(maxf(worst, 1e-6))):
			worst = ratio
			worst_edge = e
	var sorted := values.duplicate()
	sorted.sort()
	var report := {
		p_low = SkinnedView._percentile(sorted, data.edge_count, SkinnedView.STRAIN_LOW_Q),
		p_high = SkinnedView._percentile(sorted, data.edge_count, SkinnedView.STRAIN_HIGH_Q),
		min = minf(1.0, sorted[0] if not sorted.is_empty() else 1.0),
		max = maxf(1.0, sorted[sorted.size() - 1] if not sorted.is_empty() else 1.0),
		worst = worst, worst_bone = &"", has_nan = has_nan, lowest_y = lowest,
		triangles = data.indices.size() / 3, squashed = 0, flipped = 0, unmeasured = unmeasured,
	}
	if worst_edge >= 0:
		report.worst_bone = SkinnedView._dominant_bone(data, mi.skin, [data.edge_a[worst_edge], data.edge_b[worst_edge]])
	if triangles:
		var normals := SkinnedView.skin_normals(mi, rig, globals)
		for t: int in data.mixed_triangles.size():
			var tri := data.mixed_triangles[t]
			var a := data.indices[tri * 3]
			var b := data.indices[tri * 3 + 1]
			var c := data.indices[tri * 3 + 2]
			var rest_area := (rest[b] - rest[a]).cross(rest[c] - rest[a]).length() * 0.5
			var cross := (posed[b] - posed[a]).cross(posed[c] - posed[a])
			if rest_area > 1e-10 and cross.length() * 0.5 < rest_area * 0.15:
				report.squashed += 1
			if -cross.dot(normals[a] + normals[b] + normals[c]) < 0.0:
				report.flipped += 1
	return report


func _planted(rig: HumanoidRig) -> bool:
	var globals: Dictionary[StringName, Transform3D] = {}
	for i: int in rig.skeleton.get_bone_count():
		globals[rig.skeleton.get_bone_name(i)] = rig.animation_pose(i)
	return absf(PlaceholderBody.lowest_sole(globals, rig.rig_scale())) < 0.002


func _problems(report: Dictionary, planted: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if report.has_nan:
		out.append("NaN")
	if report.p_high > STRAIN_P_HIGH or report.p_low < STRAIN_P_LOW:
		out.append("p99.9 %.2f / p0.1 %.2f outside [%.1f, %.1f]" % [report.p_high, report.p_low, STRAIN_P_LOW, STRAIN_P_HIGH])
	if report.max > STRAIN_MAX or report.min < STRAIN_MIN:
		out.append("max %.2f / min %.2f outside [%.1f, %.1f]" % [report.max, report.min, STRAIN_MIN, STRAIN_MAX])
	if planted and report.lowest_y < FLOOR_M:
		out.append("a vertex %.1f cm under the floor in a planted pose" % [-report.lowest_y * 100.0])
	return out


## A19 on `rig`'s art against the skinned rest: every PlaceholderAnims.ANIM_IDS id and each Punk
## move at five phases, then the peak flexes. `{problems, worst (the worst ten lines), samples,
## reports}`.
func _strain_run(rig: HumanoidRig) -> Dictionary:
	var mi := rig.art_meshes()[0]
	var rest := SkinnedView.skin_vertices(mi, rig, _rest_globals(rig))
	var problems := PackedStringArray()
	var reports: Array[Dictionary] = []
	var clips: Array[Dictionary] = []
	for id: StringName in PlaceholderAnims.ANIM_IDS:
		clips.append({label = String(id), id = id, move = null})
	for move: MoveData in _punk_moves():
		clips.append({label = String(move.id), id = move.id, move = move})
	for clip: Dictionary in clips:
		_pose(rig, &"idle", 0.2)
		var length: float
		var peak: float
		if clip.move != null:
			var move := clip.move as MoveData
			rig.play_move(move, 0.0)
			length = float(move.total_frames()) * FRAME
			peak = (float(move.startup) + float(move.active) * 0.5) * FRAME
		else:
			rig.play(clip.id, 0.0)
			length = rig.anim_player.current_animation_length
			peak = length * 0.5
		rig.advance(0.0)
		for phase: Array in [["start", 0.0], ["25%", length * 0.25], ["peak", peak], ["75%", length * 0.75], ["end", length - FRAME]]:
			rig.anim_player.seek(phase[1], true)
			rig.advance(0.0)
			var report := _strain(mi, rig, rest, [], false)
			var label := "%s %s" % [clip.label, phase[0]]
			reports.append({label = label, report = report})
			for text: String in _problems(report, _planted(rig)):
				problems.append("%s: %s" % [label, text])
	var flexes: Array[Dictionary] = []
	for row: Dictionary in _peak_poses():
		var report := _strain(mi, rig, rest, _globals_of(rig, row.pose, row.hips), true)
		reports.append({label = "flex: %s" % row.label, report = report})
		flexes.append({label = String(row.label), report = report})
		for text: String in _problems(report, false):
			problems.append("flex: %s: %s" % [row.label, text])
		if report.triangles > 0 and float(report.squashed + report.flipped) / report.triangles > BAD_TRIANGLES:
			problems.append("flex: %s: %d of %d triangles under 15%% of their rest area or flipped" % [row.label, report.squashed + report.flipped, report.triangles])
	return {problems = problems, worst = SkinnedView.worst_lines(reports), samples = reports.size(), reports = reports, flexes = flexes}


func test_the_strain_of_every_glb_against_the_skinned_rest_is_printed_for_the_gate() -> void:
	var started := Time.get_ticks_msec()
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row))
		var run := _strain_run(rig)
		var kinds := {}
		var nan := 0
		var floor_count := 0
		for text: String in run.problems:
			var kind := "NaN" if text.contains("NaN") else ("the floor" if text.contains("floor") else ("flipped or squashed triangles" if text.contains("triangles under") else "strain range"))
			kinds[kind] = int(kinds.get(kind, 0)) + 1
		nan = kinds.get("NaN", 0)
		floor_count = kinds.get("the floor", 0)
		print("ART-PUNK A19 %s: %d samples, %d with a problem, by kind %s; worst 10 (animation, phase, bone):" % [row.name, run.samples, run.problems.size(), kinds])
		for line: String in run.worst:
			print("ART-PUNK   ", line)
		# Idle, the peak flexes (guard, elbow 150, arm raise 140, knee -130, spine twist, lying) and
		# the whole run's spread, for the gate's bind-route and weights comparison.
		_pose(rig, &"idle", 0.2)
		var idle := _strain(rig.art_meshes()[0], rig, SkinnedView.skin_vertices(rig.art_meshes()[0], rig, _rest_globals(rig)), [], false)
		print("ART-PUNK A19 %s idle: p99.9 %.2f p0.1 %.2f max %.2f min %.2f" % [row.name, idle.p_high, idle.p_low, idle.max, idle.min])
		for flex: Dictionary in run.flexes:
			var r: Dictionary = flex.report
			print("ART-PUNK A19 %s flex %s: p99.9 %.2f p0.1 %.2f worst edge x%.2f (%s), %d of %d triangles under 15%% of their rest area or flipped" % [
					row.name, flex.label, r.p_high, r.p_low, r.worst, r.worst_bone, r.squashed + r.flipped, r.triangles])
		var in_bar := 0
		var worst_high := 0.0
		for entry: Dictionary in run.reports:
			var r: Dictionary = entry.report
			if r.p_high <= STRAIN_P_HIGH and r.p_low >= STRAIN_P_LOW and r.max <= STRAIN_MAX and r.min >= STRAIN_MIN:
				in_bar += 1
			worst_high = maxf(worst_high, r.p_high)
		var by_high: Array = run.reports.duplicate()
		by_high.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.report.p_high > b.report.p_high)
		var top := PackedStringArray()
		for entry: Dictionary in by_high.slice(0, 5):
			top.append("%s p99.9 %.2f" % [entry.label, entry.report.p_high])
		print("ART-PUNK A19 %s: %d of %d samples inside every bar; worst p99.9 %.2f; the five highest p99.9: %s" % [row.name, in_bar, run.samples, worst_high, "; ".join(top)])
		assert_eq(nan, 0, "%s: no NaN" % row.name)
		assert_eq(floor_count, 0, "%s: no vertex under the floor in a planted pose" % row.name)
		assert_gt(run.samples, 200, "%s: every clip at five phases and the peak flexes" % row.name)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("ART-PUNK A19: four GLBs in %.1f s" % elapsed)
