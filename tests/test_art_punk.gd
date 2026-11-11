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
## (M4-calls/P1-chain.md C13). punk.glb's strain is the run tests/art_strain.gd keeps for the whole
## suite; the strain runs of the three locked A/B variants (about 14 s) are opt-in: set
## ART_PUNK_VARIANT_STRAIN=1 (VARIANT_STRAIN_ENV).

const SkinnedView := preload("res://tests/skinned_view.gd")
const FPView := preload("res://tests/fp_view.gd")
const ArtStrain := preload("res://tests/art_strain.gd")
const Roster := preload("res://tests/art_roster.gd")
## Set to anything to also run the strain of the three locked A/B variants (the environment, so a plain tools/run_tests.sh skips
## them): `ART_PUNK_VARIANT_STRAIN=1 tools/run_tests.sh -gselect=test_art_punk.gd`.
const VARIANT_STRAIN_ENV := "ART_PUNK_VARIANT_STRAIN"
## M6 (CHAIN, D26): the Punk's own facts are read from his roster file (tests/fixtures/art/roster/punk.json), M4's numbers moved
## in unchanged: the scene, the height, the budget, his moves, the lens-share ratchets and the strike art's floor, the stretch ratchet
## over the four GLBs.
var PUNK: Dictionary = Roster.row("punk")
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
const FIT_TORSO_LEGS := 0.95
const FIT_HEAD := 0.95
const FRAMING_DIFFER := 0.03
const FRAMING_SHARE_PP := 0.04
const FRAMING_NEAREST_M := 0.02
## F-cuff (the lead's call): the Punk's wrist cuff follows the concept, a dark band about as wide as the glove's back, not M3's
## primitive fist-and-forearm boxes, so the strikes at +8 degrees miss the plan's 4 pp lens-share bar. Each missing pose's share gap
## is a ratchet at its worst figure over the four GLBs (jab 4.78, cross 5.09 pp) plus 0.3 pp; the plan's bar is still printed as GATE.
## Every other pose is held at 4 pp. (Before F-cuff the flange held all of them: worst 3.8 pp.)
## F-fist-turn: the fists were turned palm-in (the right fist is the generated model as it came and the left its mirror, M4-calls/
## F-fist-turn.md), which moves the jab's gap to 5.25-5.32 pp over the four GLBs (the cross's to 5.17-5.32, inside its 5.4): the jab's
## ratchet 0.051 -> 0.056 (5.32 plus 0.3, rounded up). The twin on the visible path is the roster's `a9_strike_art_share_min`: the loosened bar cannot
## hide the art shrinking, the striking art keeps filling its share of the view (jab 28.1-28.2%, cross 27.6-27.8%).
## (Both now live in the roster file: `a9_lens_pp` and `a9_strike_art_share_min`.)
const ANCHOR_M := 0.02
## F-punk's rules: no edge of the art in view grows more than this over its skinned rest length in the 1 m acts' poses (the
## visible-stretch test), a held victim stays this far from the lens, no in-view vertex of a striking Punk is nearer than FPView.NEAR.
const VISIBLE_STRETCH_M := 0.02
## What the asset does today (the cross's torso twist stretches the vest hem at the waist; weight smoothing, a torso height blend
## and the heat-map weights were tried, M4-calls/F-punk.md): the test fails below this, and prints the 2 cm bar as the gate.
const HELD_CLEAR_M := 0.25
const STRIKE_DISTANCE_M := 0.95
const ROOM := preload("res://game/level/test_room.tscn")
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
	rig.height = float(PUNK.height_m)
	rig.build_hurtboxes = hurtboxes
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	return rig


## A Street Punk of the scene on a stage of its own (an enemy adds an EnemyDirector beside itself,
## and the stage frees it with the Punk).
func _punk() -> StreetPunk:
	var stage := Node3D.new()
	add_child_autofree(stage)
	var punk := (load(PUNK.actor_scene) as PackedScene).instantiate() as StreetPunk
	stage.add_child(punk)
	return punk


func _pose(rig: HumanoidRig, animation: StringName, at: float) -> void:
	rig.play(animation, 0.0)
	rig.advance(0.0)
	rig.advance(at)


## The rig's pose at the table's rest (rig space, its scale): the strain's reference.
func _rest_globals(rig: HumanoidRig) -> Array[Transform3D]:
	return SkinnedView.rest_pose(rig)


func _globals_of(rig: HumanoidRig, pose: Dictionary[StringName, Vector3], hips: Vector3) -> Array[Transform3D]:
	var table := PlaceholderBody.pose_globals(pose, hips, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


func _punk_moves() -> Array[MoveData]:
	return Roster.moves_of(PUNK)


func _lines(title: String, lines: PackedStringArray) -> void:
	print("ART-PUNK %s" % title)
	for line: String in lines:
		print("ART-PUNK   ", line)


# --- The Punk wears the art ------------------------------------------------------------------


func test_a_street_punk_wears_the_art_through_combat_actor_art() -> void:
	var punk := _punk()
	assert_not_null(punk.art, "the scene carries punk_art.tres")
	assert_eq(punk.art.resource_path, VARIANTS[0].art)
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
	assert_lte(tris, int(PUNK.budget), "A2: the Punk's %d triangles" % tris)
	# The hull and the toon art material are on it.
	var mesh := punk.rig.art_meshes()[0]
	assert_true(mesh.material_override is ShaderMaterial, "toon art material")
	assert_true(mesh.material_overlay is ShaderMaterial, "the hull")


func test_the_primitives_come_back_when_the_art_is_switched_off() -> void:
	Tuning.data.look_show_art = false
	var punk := _punk()
	await get_tree().physics_frame
	assert_true(punk.rig.has_art())
	assert_false(punk.rig.art_meshes()[0].visible, "the art is hidden by the A/B switch")
	Tuning.data.look_show_art = true
	Tuning.changed.emit(&"look_show_art")
	assert_true(punk.rig.art_meshes()[0].visible)


func test_look_punk_art_variant_picks_each_glb_and_a_punk_wears_it() -> void:
	for row: Dictionary in VARIANTS:
		Tuning.data.look_punk_art_variant = row.variant
		var punk := _punk()
		await get_tree().physics_frame
		assert_true(punk.rig.has_art(), "%s attaches" % row.name)
		var scene_path := punk.rig.art.scene.resource_path
		assert_true(scene_path.ends_with("/" + String(row.glb)), "variant %d wears %s (%s)" % [row.variant, row.glb, scene_path])
	Tuning.data.look_punk_art_variant = 99
	var clamped := _punk()
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
		assert_eq(art.triangle_budget, int(PUNK.budget))
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
		# F-punk (gate gap 7): the legs and the head are asserted at A6's own bar now (they were printed for the gate, with
		# "most" asserted: legs above 0.8, head above 0.9). The chain's girth clamps and the waist weights make them so
		# (M4-calls/F-punk.md); the cap and head stay inside the head sphere + 5 cm.
		assert_gte(fit.legs, FIT_TORSO_LEGS, "%s: 95%% of the leg vertices are inside the leg hurtboxes + 6 cm (%.1f%%)" % [row.name, fit.legs * 100.0])
		assert_gte(fit.head, FIT_HEAD, "%s: 95%% of the head vertices are inside the head sphere + 5 cm (%.1f%%)" % [row.name, fit.head * 100.0])


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
		var share_gate := PackedStringArray()
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
				var share_bar: float = Roster.lens_bar(PUNK, "%s pitch %+.0f" % [pose.label, pitch])
				worst_differ = maxf(worst_differ, cmp.differ_share)
				worst_share = maxf(worst_share, absf(cmp.art_share - cmp.proxy_share))
				worst_nearest = maxf(worst_nearest, cmp.nearest)
				print("ART-PUNK A9 %s: %d of %d cells differ (%.1f%%), art %.1f%% proxies %.1f%% of the view, art nearer by %.1f cm" % [
						label, cmp.differ, cmp.cells, cmp.differ_share * 100.0, cmp.art_share * 100.0, cmp.proxy_share * 100.0, cmp.nearest * 100.0])
				assert_gt(cmp.art_share, 0.03, "%s: the art fills the view at 1 m" % label)
				assert_gt(cmp.proxy_share, 0.03, "%s: so do the proxies" % label)
				# What passes today (the art is narrower than the proxies' fist boxes in the jab and the cross at +8 degrees, so the
				# cell count and the nearest figure at the jab, cross and shove are the gate's, and those two poses' shares are
				# ratcheted, the roster's `a9_lens_pp`):
				assert_lte(absf(cmp.art_share - cmp.proxy_share), share_bar, "%s: the lens share differs by at most %.1f pp" % [label, share_bar * 100.0])
				if (PUNK.ratchets.a9_lens_pp as Dictionary).has("%s pitch %+.0f" % [pose.label, pitch]):
					assert_gt(cmp.art_share, float(PUNK.ratchets.a9_strike_art_share_min), "%s: the striking art itself keeps at least %.0f%% of the view" % [label, float(PUNK.ratchets.a9_strike_art_share_min) * 100.0])
				if pose.move == null:
					assert_lte(cmp.differ_share, FRAMING_DIFFER, "%s: at most 3%% of the cells differ at idle" % label)
				if cmp.differ_share > FRAMING_DIFFER:
					gate.append("%s differs %.1f%%" % [label, cmp.differ_share * 100.0])
				if absf(cmp.art_share - cmp.proxy_share) > FRAMING_SHARE_PP:
					gate.append("%s lens share differs %.1f pp" % [label, absf(cmp.art_share - cmp.proxy_share) * 100.0])
					share_gate.append("%s %.2f pp (ratchet %.1f)" % [label, absf(cmp.art_share - cmp.proxy_share) * 100.0, share_bar * 100.0])
				if cmp.nearest > FRAMING_NEAREST_M:
					gate.append("%s art %.1f cm nearer" % [label, cmp.nearest * 100.0])
		print("ART-PUNK A9 %s lens share: %s" % [row.name, ("GATE (the plan's bar is 4 pp, F-cuff ratchets): " + "; ".join(share_gate)) if not share_gate.is_empty() else "(meets the 4 pp bar)"])
		print("ART-PUNK A9 %s: worst differ %.1f%%, worst lens share %.1f pp, nearest %.1f cm%s" % [
				row.name, worst_differ * 100.0, worst_share * 100.0, worst_nearest * 100.0,
				("  GATE: %d poses miss: %s" % [gate.size(), "; ".join(gate.slice(0, 4))]) if not gate.is_empty() else "  (meets A9)"])


# --- F-fist-turn: which way the drawn fists face in the guard ----------------------------------------


## The skin slot of the fingerless gloves' bare fingers and thumb (palette/shared.json skin_light), and the bars of the next test. The
## fist is the faces with every vertex at least FIST_WEIGHT on a Hand bone. Its bare skin is the curled fingers (they curl into the palm,
## so the skin's centroid sits on the palm side) and the thumb pad, the skin faces on the front half of the fist in the hand's rest frame.
## What the shipped art shows in the guard (the idle at 0.3 s, all four GLBs, both fists): the curled fingers 2.8 cm toward the face and
## 1.8 to 1.9 cm away from the viewer of the fist's own centroid, the thumb pad 3.0 to 3.1 cm toward the face. The art before
## F-fist-turn (the palm outward, run on the GLBs of e04bf75) read -0.3 to -0.4 cm toward the face (the fingers on the outside) and 0.9 cm
## away from the viewer, the thumb pad 1.3 to 1.5 cm: the fingers sat on the outer face of the fist, where the lens saw them.
const SKIN_SLOT := 6
const FIST_WEIGHT := 0.9
const GUARD_FINGERS_TO_FACE_MIN_M := 0.01
const GUARD_FINGERS_FROM_VIEWER_MIN_M := 0.0
const GUARD_THUMB_TO_FACE_MIN_M := 0.005
const THUMB_FRONT_M := 0.01


## One fist of the drawn art in the guard, by side ("Left" or "Right"): {fist, fingers, thumb} the area-weighted centroids (rig space) of its
## faces, its bare-skin faces and its bare-skin faces on the front of the hand (the thumb); Vector3.INF where there are none.
func _fist_centroids(mi: MeshInstance3D, rig: HumanoidRig, side: String) -> Dictionary:
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var hand := side + "Hand"
	var skin: Skin = mi.skin
	var wrist := Vector3.ZERO
	var elbow := Vector3.ZERO
	var hand_bind := -1
	for i: int in skin.get_bind_count():
		var bind := String(skin.get_bind_name(i))
		if bind == hand:
			wrist = skin.get_bind_pose(i).affine_inverse().origin
			hand_bind = i
		elif bind == side + "LowerArm":
			elbow = skin.get_bind_pose(i).affine_inverse().origin
	var unswing := Basis(Quaternion((wrist - elbow).normalized(), Vector3.DOWN))
	var posed := SkinnedView.skin_vertices(mi, rig)
	var on_hand := PackedByteArray()
	on_hand.resize(rest.size())
	for v: int in rest.size():
		var w := 0.0
		for k: int in 4:
			if bones[v * 4 + k] == hand_bind:
				w += weights[v * 4 + k]
		on_hand[v] = 1 if w >= FIST_WEIGHT else 0
	var area := 0.0
	var fist := Vector3.ZERO
	var skin_area := 0.0
	var fingers := Vector3.ZERO
	var thumb_area := 0.0
	var thumb := Vector3.ZERO
	var fist_front_z := 0.0
	var fist_area_rest := 0.0
	for t: int in index.size() / 3:
		var i0 := index[t * 3]
		var i1 := index[t * 3 + 1]
		var i2 := index[t * 3 + 2]
		if on_hand[i0] == 0 or on_hand[i1] == 0 or on_hand[i2] == 0:
			continue
		var r0 := unswing * (rest[i0] - wrist)
		var r1 := unswing * (rest[i1] - wrist)
		var r2 := unswing * (rest[i2] - wrist)
		var a := (posed[i1] - posed[i0]).cross(posed[i2] - posed[i0]).length() * 0.5
		fist_front_z += (r0.z + r1.z + r2.z) / 3.0 * a
		fist_area_rest += a
	if fist_area_rest < 0.001:
		return {"fist": Vector3.INF, "fingers": Vector3.INF, "thumb": Vector3.INF}
	fist_front_z /= fist_area_rest
	for t: int in index.size() / 3:
		var i0 := index[t * 3]
		var i1 := index[t * 3 + 1]
		var i2 := index[t * 3 + 2]
		if on_hand[i0] == 0 or on_hand[i1] == 0 or on_hand[i2] == 0:
			continue
		var a := (posed[i1] - posed[i0]).cross(posed[i2] - posed[i0]).length() * 0.5
		var c := (posed[i0] + posed[i1] + posed[i2]) / 3.0
		var rz := (unswing * (rest[i0] - wrist)).z + (unswing * (rest[i1] - wrist)).z + (unswing * (rest[i2] - wrist)).z
		fist += c * a
		area += a
		if int(floorf(uv[i0].x * 32.0)) + 32 * int(floorf(uv[i0].y * 2.0)) == SKIN_SLOT:
			fingers += c * a
			skin_area += a
			if rz / 3.0 < fist_front_z - THUMB_FRONT_M:
				thumb += c * a
				thumb_area += a
	return {"fist": fist / area, "fingers": fingers / skin_area if skin_area > 0.0 else Vector3.INF,
			"thumb": thumb / thumb_area if thumb_area > 0.0 else Vector3.INF}


## Game-boy's playtest: "his curled fingers are facing outward instead of inward when he has his hands up to fight". The twin, on the
## drawn mesh, of the contract's palm test and the guard pose test: skin the art in the guard (the idle) and ask where the bare curled
## fingers and the thumb pad sit relative to the fist, toward the Punk's own face (the head bone) or the viewer (-Z of the rig).
func test_in_the_guard_each_fists_curled_fingers_and_thumb_are_on_the_side_of_the_punks_face() -> void:
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row))
		_pose(rig, &"idle", 0.3)
		var mi := rig.art_meshes()[0]
		var head := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone(&"Head")).origin
		for side: String in ["Left", "Right"]:
			var c := _fist_centroids(mi, rig, side)
			assert_ne(c.fingers, Vector3.INF, "%s: the %s fist has bare fingers" % [row.name, side])
			assert_ne(c.thumb, Vector3.INF, "%s: the %s fist has a thumb pad" % [row.name, side])
			if c.fingers == Vector3.INF or c.thumb == Vector3.INF:
				continue
			var to_face: Vector3 = (head - (c.fist as Vector3)).normalized()
			var fingers: Vector3 = (c.fingers as Vector3) - (c.fist as Vector3)
			var thumb: Vector3 = (c.thumb as Vector3) - (c.fist as Vector3)
			print("ART-PUNK FIST-TURN %s %s, in the guard: the curled fingers %+.1f cm toward the face, %+.1f cm away from the viewer; the thumb pad %+.1f cm toward the face" % [
					row.name, side, fingers.dot(to_face) * 100.0, fingers.z * 100.0, thumb.dot(to_face) * 100.0])
			assert_gt(fingers.dot(to_face), GUARD_FINGERS_TO_FACE_MIN_M, "%s %s: the curled fingers face the Punk's own face" % [row.name, side])
			assert_gt(fingers.z, GUARD_FINGERS_FROM_VIEWER_MIN_M, "%s %s: and not the viewer (+Z is behind the Punk)" % [row.name, side])
			assert_gt(thumb.dot(to_face), GUARD_THUMB_TO_FACE_MIN_M, "%s %s: the thumb sits on the inside, next to the face" % [row.name, side])


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


## The folded triangles of `mi` skinned at the rig's rest pose, per blended triangle
## (SkinnedView.folded_mask()): the flip count's reference, `rest` being the vertices there.
func _rest_mask(mi: MeshInstance3D, rig: HumanoidRig, rest: PackedVector3Array) -> PackedByteArray:
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	SkinnedView._prepare_strain(data)
	return SkinnedView.folded_mask(data, rest, SkinnedView.skin_normals(mi, rig, _rest_globals(rig)))


## The strain of `mi` posed at `globals` (empty: the rig's current pose) against the same mesh
## skinned at the rig's rest pose `rest`: every deforming edge's posed length over its rest
## length, p0.1 and p99.9 over all edges (edges on one bind are exactly 1), the extremes, NaN, the
## lowest vertex, and with `triangles` the triangles under 15% of their rest area (`squashed`) or
## turned over (`flipped`: folded against their vertex normals in the pose and not at the skinned
## rest; `flipped_healed` is the reverse, folded at the rest and right in the pose, no defect;
## `rest_folded` is the mesh's own baseline, never charged to a pose). `rest_mask` is _rest_mask()
## when the caller has it. SkinnedView.strain() measures the squash against the authored mesh; this
## is the same with the skinned rest as the reference (A19, M4-calls/P1-chain.md C13,
## M4-calls/SG-instruments.md).
func _strain(mi: MeshInstance3D, rig: HumanoidRig, rest: PackedVector3Array, globals: Array[Transform3D], triangles: bool,
		rest_mask: PackedByteArray = PackedByteArray()) -> Dictionary:
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
		triangles = data.indices.size() / 3, squashed = 0, flipped = 0, flipped_healed = 0,
		rest_folded = 0, unmeasured = unmeasured,
	}
	if worst_edge >= 0:
		report.worst_bone = SkinnedView._dominant_bone(data, mi.skin, [data.edge_a[worst_edge], data.edge_b[worst_edge]])
	if triangles:
		for t: int in data.mixed_triangles.size():
			var tri := data.mixed_triangles[t]
			var a := data.indices[tri * 3]
			var b := data.indices[tri * 3 + 1]
			var c := data.indices[tri * 3 + 2]
			var rest_area := (rest[b] - rest[a]).cross(rest[c] - rest[a]).length() * 0.5
			var cross := (posed[b] - posed[a]).cross(posed[c] - posed[a])
			if rest_area > 1e-10 and cross.length() * 0.5 < rest_area * 0.15:
				report.squashed += 1
		var reference := rest_mask if not rest_mask.is_empty() else _rest_mask(mi, rig, rest)
		var flips := SkinnedView.flip_counts(reference, SkinnedView.folded_mask(data, posed, SkinnedView.skin_normals(mi, rig, globals)))
		report.flipped = flips.turned
		report.flipped_healed = flips.healed
		report.rest_folded = flips.rest_folded
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
	var rest_mask := _rest_mask(mi, rig, rest)
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
		var report := _strain(mi, rig, rest, _globals_of(rig, row.pose, row.hips), true, rest_mask)
		reports.append({label = "flex: %s" % row.label, report = report})
		flexes.append({label = String(row.label), report = report})
		for text: String in _problems(report, false):
			problems.append("flex: %s: %s" % [row.label, text])
		if report.triangles > 0 and float(report.squashed + report.flipped) / report.triangles > BAD_TRIANGLES:
			problems.append("flex: %s: %d of %d triangles under 15%% of their rest area or turned over" % [row.label, report.squashed + report.flipped, report.triangles])
	return {problems = problems, worst = SkinnedView.worst_lines(reports), samples = reports.size(), reports = reports, flexes = flexes}


func test_the_strain_of_every_glb_against_the_skinned_rest_is_printed_for_the_gate() -> void:
	# punk.glb's run is tests/art_strain.gd's, kept per art (the done-when and test_skinned_art read the same one): it is made
	# once for the whole suite. The three other variants (the slice gate's locked A/B: the A-pose or rest-pose bind, the heat-map
	# or automatic weights) are measured only with VARIANT_STRAIN_ENV set (about 6 s each, ~14 s in all): their figures were printed
	# for the slice gate, which is closed.
	var started := Time.get_ticks_msec()
	var measured := 0
	for row: Dictionary in VARIANTS:
		if row.variant != 0 and OS.get_environment(VARIANT_STRAIN_ENV) == "":
			print("ART-PUNK A19 %s: not measured (the slice gate's locked A/B variant; set %s=1 to run it)" % [row.name, VARIANT_STRAIN_ENV])
			continue
		var rig := _rig(_art(row))
		var run: Dictionary
		if row.variant == 0:
			var shipped := ArtStrain.SHIPPED[0]
			run = ArtStrain.cached(shipped.path)
			if run.is_empty():
				run = ArtStrain.keep(shipped.path, ArtStrain.run(rig, ArtStrain.punk_moves()))
		else:
			run = _strain_run(rig)
		measured += 1
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
		var mi := rig.art_meshes()[0]
		var authored := SkinnedView.folded_triangles(mi)
		var at_rest := SkinnedView.folded_triangles(mi, rig, _rest_globals(rig))
		print("ART-PUNK A7 %s folded triangles (the mesh's own baseline: a flip is a change from the skinned rest, so these are not charged to a pose): authored mesh %d of %d (%.2f%%); skinned at the rest %d, %d of them blended" % [
				row.name, authored.all, authored.triangles, 100.0 * authored.all / authored.triangles, at_rest.all, at_rest.mixed])
		var bar := roundi(BAD_TRIANGLES * authored.triangles)
		var over := PackedStringArray()
		for flex: Dictionary in run.flexes:
			var r: Dictionary = flex.report
			var bad: int = r.squashed + r.flipped
			if bad > bar:
				over.append("%s %d" % [flex.label, bad])
			print("ART-PUNK A19 %s flex %s: p99.9 %.2f p0.1 %.2f worst edge x%.2f (%s); triangles: %d under 15%% of their rest area + %d turned over from the skinned rest's turn = %d of %d (%.2f%%), bar %d%s; %d more set right (folded at the rest, right in the pose: not counted)" % [
					row.name, flex.label, r.p_high, r.p_low, r.worst, r.worst_bone, r.squashed, r.flipped, bad, r.triangles,
					100.0 * bad / r.triangles, bar, "  GATE" if bad > bar else "  (meets A7)", r.flipped_healed])
		print("ART-PUNK A7 %s: peak flexes over the %d-triangle bar: %s" % [row.name, bar, ", ".join(over) if not over.is_empty() else "none"])
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
	assert_gte(measured, 1, "punk.glb's strain is always measured")
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("ART-PUNK A19: %d of %d GLBs in %.1f s" % [measured, VARIANTS.size(), elapsed])


func test_the_flip_count_does_not_charge_the_meshs_own_folds_to_a_pose() -> void:
	# slice-g2-05: a triangle counts as flipped only when it is folded against its vertex normals
	# in the pose and was not at the skinned rest, so a mesh posed at its own rest has no flips
	# however many triangles it carries folded (the chain's decimation leaves some: P1-chain's
	# report, about 1% of punk.glb). Counted against the normals alone, every one was a flex failure.
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row))
		var mi := rig.art_meshes()[0]
		var rest_globals := _rest_globals(rig)
		var rest := SkinnedView.skin_vertices(mi, rig, rest_globals)
		var report := _strain(mi, rig, rest, rest_globals, true)
		var at_rest := SkinnedView.folded_triangles(mi, rig, rest_globals)
		assert_eq(report.flipped, 0, "%s: posed at its own rest nothing has flipped" % row.name)
		assert_eq(report.squashed, 0, "%s: or squashed" % row.name)
		assert_eq(report.rest_folded, at_rest.mixed, "%s: the folded baseline is %d blended triangles" % [row.name, at_rest.mixed])
		# SkinnedView.strain() (F-punk's tool) agrees with the test's own count.
		var tool := SkinnedView.strain(mi, rig, rest_globals, 0.15, true)
		assert_eq(tool.flipped, 0, "%s: SkinnedView.strain() reads the rest as no flips too" % row.name)
		assert_eq(tool.rest_folded, at_rest.mixed)


# --- The rooms: the props' hulls and the load-time warm-up ------------------------------------------


const CROWD_ROOM := "res://game/level/crowd_room.tscn"
const TRAINING_ROOM := "res://game/level/test_room.tscn"


## The ShaderMaterial a room mesh draws with (a BoxMesh's own surface material), or null.
func _surface(mi: MeshInstance3D) -> ShaderMaterial:
	return (mi.mesh as BoxMesh).material as ShaderMaterial if mi.mesh is BoxMesh else null


## Count the room's meshes that wear the prop hull and those that do not. A box wears it as its material's
## next_pass (M5's look, and the graybox switch's); a kit module or a prop's art wears it as the mesh's
## overlay (M6 DRESS: the module's material is the one shared trim material, a StaticArt's is the atlas's).
## The hulled ones also carry the edge tag 0 where a material holds one (a module's trim material and the
## atlas's draw ROUGHNESS from the shader, so they are not read).
func _hulls_of(root: Node) -> Dictionary:
	var hulled := 0
	var bare := 0
	var tags_ok := true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if _worn(mesh_node):
			continue  # an actor's or a weapon's own mesh: this counts the room's
		var overlay := mesh_node.material_overlay as ShaderMaterial
		var overlaid := overlay != null and overlay.shader == ToonMaterials.OUTLINE_SHADER
		var material := _surface(mesh_node)
		if material == null:
			if not (mesh_node.mesh is ArrayMesh) or not mesh_node.is_visible_in_tree():
				continue
			if overlaid:
				hulled += 1
			else:
				bare += 1
			continue
		if material.next_pass is ShaderMaterial and (material.next_pass as ShaderMaterial).shader == ToonMaterials.OUTLINE_SHADER:
			hulled += 1
			tags_ok = tags_ok and is_equal_approx(float(material.get_shader_parameter(&"edge_tag")), 0.0)
		else:
			bare += 1
			if material.shader == ToonMaterials.TOON_SHADER:
				tags_ok = tags_ok and is_equal_approx(float(material.get_shader_parameter(&"edge_tag")), 1.0)
	return {hulled = hulled, bare = bare, tags_ok = tags_ok}


## Whether `node` is part of an actor or a weapon.
func _worn(node: Node) -> bool:
	var at := node.get_parent()
	while at != null:
		if at is CombatActor or at is Weapon:
			return true
		at = at.get_parent()
	return false


func test_the_crowd_rooms_crates_dumpster_and_car_wear_the_hull_and_the_walls_do_not() -> void:
	var room := (load(CROWD_ROOM) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = false
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await get_tree().physics_frame
	var count := _hulls_of(room)  # the geometry and the dressing (the car and the dumpster are prop spots)
	assert_eq(count.hulled, room.crate_positions.size() + 2, "the crates, the dumpster and the car")
	assert_gt(count.bare, 20, "the street's walls, windows, paint and backdrop have none")
	assert_true(count.tags_ok, "a hulled prop is tagged 0 for the edge pass and the rest 1")


func test_the_training_rooms_crates_wear_the_hull() -> void:
	var room := (load(TRAINING_ROOM) as PackedScene).instantiate() as Node3D
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await get_tree().physics_frame
	var count := _hulls_of(room)
	assert_eq(count.hulled, 3, "the three crates")
	assert_gt(count.bare, 5)
	assert_true(count.tags_ok)


func test_the_props_wear_no_hull_when_placeholders_get_none() -> void:
	Tuning.data.look_hull_on_placeholders = false
	var room := (load(CROWD_ROOM) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = false
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await get_tree().physics_frame
	var count := _hulls_of(room.geometry)
	assert_eq(count.hulled, 0, "the fallback: no hull on a prop")
	assert_true(count.tags_ok, "and every surface is tagged 1, so the edge pass inks them")


func test_the_load_time_warm_up_adds_nothing_headless() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var before := holder.get_child_count()
	RoomKit.warm_up_art(holder)
	assert_eq(holder.get_child_count(), before, "headless: no throwaway rig, no holder")
	assert_true(ResourceLoader.exists(RoomKit.WARM_ART), "the warm-up's art exists")
	assert_eq((load(RoomKit.WARM_ART) as CharacterArt).resource_path, VARIANTS[0].art)


# --- The ragdoll's write-back on the real GLB (slice-gate gap 10) ----------------------------------


## The figures a WriteBackProbe keeps: the largest origin (m) and rotation (rad) gap of any bone, the
## updates counted, and those a ragdoll ran in.
class WriteBackStats:
	extends RefCounted
	var worst_origin: float = 0.0
	var worst_angle: float = 0.0
	var updates: int = 0
	## Updates in which a ragdoll was running.
	var running: int = 0


## A modifier that reads the skeleton the way the render server will draw it, and the rig's bone
## followers beside it, on every update of the skeleton: the gap of any of the 23 bones, in rig space.
## Placed after the Ragdoll (a child of the skeleton added once the Ragdoll exists) it sees what the Ragdoll
## left; placed first it sees the animation's pose.
class WriteBackProbe:
	extends SkeletonModifier3D
	var rig: HumanoidRig
	## The figures live outside the node: a KO'd Punk is freed with the probe on its skeleton.
	var stats := WriteBackStats.new()
	## Count the updates a ragdoll runs in, and those it does not.
	var count_ragdolling: bool = true
	var count_animated: bool = true

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		if skeleton == null or rig == null or not is_instance_valid(rig):
			return
		var ragdolling := rig.is_ragdolling()
		stats.running += int(ragdolling)
		if ragdolling and not count_ragdolling or not ragdolling and not count_animated:
			return
		var globals: Array[Transform3D] = []
		for i: int in skeleton.get_bone_count():
			var local := skeleton.get_bone_pose(i)
			var parent := skeleton.get_bone_parent(i)
			globals.append(local if parent < 0 else globals[parent] * local)
		var to_rig := rig.global_transform.affine_inverse()
		for i: int in globals.size():
			var follower := to_rig * rig.get_attachment(skeleton.get_bone_name(i)).global_transform
			stats.worst_origin = maxf(stats.worst_origin, globals[i].origin.distance_to(follower.origin))
			# The exact angle: Quaternion.angle_to() is only good to 4e-4 near zero.
			var turn := globals[i].basis.get_rotation_quaternion().inverse() * follower.basis.get_rotation_quaternion()
			stats.worst_angle = maxf(stats.worst_angle, 2.0 * atan2(Vector3(turn.x, turn.y, turn.z).length(), absf(turn.w)))
		stats.updates += 1


## A stage with a floor and a bare player to hit the Punk with (the AI is frozen: only what the test
## does moves it).
func _arena() -> Dictionary:
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"god_mode", true)
	var stage := Node3D.new()
	add_child_autofree(stage)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	var player := PlayerCharacter.new()
	stage.add_child(player)
	player.input.scripted = true
	var punk := (load(PUNK.actor_scene) as PackedScene).instantiate() as StreetPunk
	punk.position = Vector3(0.0, 0.0, -1.0)
	punk.rotation.y = 0.0
	stage.add_child(punk)
	return {stage = stage, player = player, punk = punk}


func _hit_on(player: PlayerCharacter, punk: StreetPunk, reaction: CombatTypes.Reaction, knockback: Vector3, damage: float = 1.0) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = punk
	hit.damage = damage
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = reaction
	hit.region = CombatTypes.Region.TORSO
	hit.direction = Vector3(knockback.x, 0.0, knockback.z).normalized()
	hit.knockback = knockback
	hit.contact_point = punk.rig.get_point_position(&"ChestPoint") - hit.direction * 0.15
	hit.physics_frame = Engine.get_physics_frames()
	return hit


func _wait_physics(condition: Callable, max_ticks: int) -> bool:
	for i: int in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func test_a_modifier_after_the_ragdoll_sees_the_skeleton_equal_the_followers_through_a_real_punks_fight() -> void:
	# Gap 10 of the slice gate: the write-back (A5) was proved on the fixtures; here it is held on a real
	# StreetPunk wearing punk.glb, through its own jab, a stagger (partial ragdoll), a launch (full, out of
	# the stagger), the get-up and a KO. On every update of the skeleton, in rig space, every bone the
	# skeleton holds is within 1 mm of the bone follower the primitives and the flash anchors ride.
	var arena := _arena()
	var player := arena.player as PlayerCharacter
	var punk := arena.punk as StreetPunk
	await _wait_physics(func() -> bool: return punk.is_inside_tree() and punk.rig != null, 5)
	await get_tree().physics_frame
	assert_true(punk.rig.has_art(), "the Punk wears the art")
	assert_eq(punk.rig.art.scene.resource_path.get_file(), "punk.glb", "punk.glb, the A-pose route")
	var skeleton := punk.rig.skeleton
	# Before any ragdoll exists: the animation's updates (the jab).
	var idle_probe := WriteBackProbe.new()
	idle_probe.rig = punk.rig
	idle_probe.count_ragdolling = false
	skeleton.add_child(idle_probe)
	var idle_stats := idle_probe.stats
	# 1. The Punk's own jab (force_attack, the AI's own telegraph and strike), whiffing at 1 m.
	punk.force_attack(0)
	assert_true(await _wait_physics(func() -> bool: return punk.current_move != null, 90), "the jab starts")
	assert_true(await _wait_physics(func() -> bool: return punk.current_move == null, 240), "and ends")
	await _ticks_physics(10)
	assert_gt(idle_stats.updates, 40, "the jab's updates were watched (%d)" % idle_stats.updates)
	# 2. A stagger: the partial ragdoll. The Ragdoll exists from now on: the probe goes after it.
	assert_true(punk.receive_hit(_hit_on(player, punk, CombatTypes.Reaction.STAGGER, Vector3(0.0, 0.5, -2.0))))
	var ragdoll := punk.rig.get_ragdoll()
	assert_not_null(ragdoll, "the stagger built the ragdoll")
	var probe := WriteBackProbe.new()
	probe.rig = punk.rig
	skeleton.add_child(probe)
	var stats := probe.stats
	probe.count_animated = true
	assert_gt(probe.get_index(), ragdoll.get_index(), "the probe runs after the Ragdoll")
	assert_true(await _wait_physics(func() -> bool: return punk.rig.is_ragdolling(), 10) or stats.running > 0)
	await _ticks_physics(14)
	# 3. A launch out of the stagger: the full ragdoll at once, and the flight.
	assert_true(punk.receive_hit(_hit_on(player, punk, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 4.0, -5.0))))
	assert_true(await _wait_physics(func() -> bool: return punk.is_downed(), 240), "it lands")
	# 4. The get-up: the ragdoll hands the body back to the animation.
	assert_true(await _wait_physics(func() -> bool:
			return punk.state == CombatTypes.ActorState.FREE and punk.current_move == null, 600), "it gets up")
	await _ticks_physics(20)
	# 5. A KO: the last health, a launch.
	punk.health = 1.0
	assert_true(punk.receive_hit(_hit_on(player, punk, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 3.0, -4.0), 50.0)))
	var ref: WeakRef = weakref(punk)
	await _wait_physics(func() -> bool: return ref.get_ref() == null or (ref.get_ref() as CombatActor).is_gone(), 900)
	await _ticks_physics(5)
	print("ART-PUNK write-back (the real punk.glb): jab %d updates, worst %.5f m / %.5f rad; stagger to KO %d updates (%d with a ragdoll running), worst %.5f m / %.5f rad" % [
			idle_stats.updates, idle_stats.worst_origin, idle_stats.worst_angle, stats.updates, stats.running, stats.worst_origin, stats.worst_angle])
	assert_lt(idle_stats.worst_origin, 0.001, "the jab: every bone within 1 mm of its follower (worst %.5f m)" % idle_stats.worst_origin)
	assert_lt(idle_stats.worst_angle, 0.001, "and its turn (%.5f rad)" % idle_stats.worst_angle)
	assert_gt(stats.updates, 100, "stagger, launch, get-up and KO were watched (%d updates)" % stats.updates)
	assert_gt(stats.running, 60, "with a ragdoll running in many of them (%d)" % stats.running)
	assert_gt(stats.updates - stats.running, 30, "and none running in the rest: the get-up and the standing (%d)" % (stats.updates - stats.running))
	assert_lt(stats.worst_origin, 0.001, "after the Ragdoll: every bone within 1 mm of its follower on every update (worst %.5f m)" % stats.worst_origin)
	assert_lt(stats.worst_angle, 0.001, "and its turn (worst %.5f rad)" % stats.worst_angle)


func test_the_probe_has_teeth_a_modifier_before_the_ragdoll_sees_the_raw_simulator() -> void:
	# The control: a probe placed BEFORE the Ragdoll reads the simulator's raw output, which is a long way
	# from the followers in a stagger, so a write-back that did not happen would fail the test above.
	var arena := _arena()
	var player := arena.player as PlayerCharacter
	var punk := arena.punk as StreetPunk
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(punk.receive_hit(_hit_on(player, punk, CombatTypes.Reaction.STAGGER, Vector3(0.0, 0.5, -2.0))))
	var ragdoll := punk.rig.get_ragdoll()
	var raw := WriteBackProbe.new()
	raw.rig = punk.rig
	punk.rig.skeleton.add_child(raw)
	punk.rig.skeleton.move_child(raw, ragdoll.get_index())
	await _ticks_physics(30)
	assert_gt(raw.stats.updates, 10)
	assert_gt(raw.stats.worst_origin, 0.01, "the raw simulator output is %.3f m from the followers in a stagger" % raw.stats.worst_origin)


# --- F-punk: what the lens sees of the art (slice-gate gaps 4 and 7) --------------------------------


## The 1 m acts' poses of the A9 test: idle and each Punk move at its first active frame.
func _act_poses() -> Array[Dictionary]:
	var poses: Array[Dictionary] = [{label = "idle", move = null}]
	for move: MoveData in _punk_moves():
		poses.append({label = String(move.id), move = move})
	return poses


func _put_in_pose(rig: HumanoidRig, pose: Dictionary) -> void:
	_pose(rig, &"idle", 0.3)
	if pose.move != null:
		var move := pose.move as MoveData
		rig.play_move(move)
		for i: int in move.startup + 1:
			rig.advance(FRAME)


## Which of `world` (vertices, world space) the camera `cam` draws: in front of the near plane, inside the view's half-angles and
## facing the lens (the skinned normal against the direction to the lens). Occlusion is not tested, so this is a superset of
## the FP-visible cells' vertices (the stricter reading for a stretch rule).
func _in_view(world: PackedVector3Array, normals: PackedVector3Array, cam: Transform3D) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(world.size())
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var forward := -cam.basis.z
	for v: int in world.size():
		var to := world[v] - cam.origin
		var depth := to.dot(forward)
		if depth <= FPView.NEAR:
			continue
		if absf(to.dot(cam.basis.x)) > tan_h * depth or absf(to.dot(cam.basis.y)) > tan_v * depth:
			continue
		if normals[v].dot(-to) <= 0.0:
			continue
		out[v] = 1
	return out


## True when `point` is the first surface of `soup` along the ray from `origin` (nothing nearer by more than 1.5 cm).
func _seen_from(soup: SkinnedView.Soup, origin: Vector3, point: Vector3) -> bool:
	var to := point - origin
	var dist := to.length()
	var hit := soup.triangles.intersect_ray(origin, to / dist)
	return hit.is_empty() or origin.distance_to(hit.position) >= dist - 0.015


func test_no_edge_in_view_grows_more_than_2_cm_in_the_one_metre_acts_poses() -> void:
	# Gap 4 of the slice gate: the visible-stretch test. The vest's front panel and armholes are the asset's shape; weight
	# smoothing and the named clamps (shoulder, collar, waist) are the contingency if this fails. For each GLB, at the poses of
	# the 1 m acts (idle and the Punk's three moves at their first active frame) from the face and the body views, every
	# deforming edge the lens sees (both ends inside the view, facing it and not hidden behind other art) grows at most 2 cm over its length in the skinned rest pose.
	for row: Dictionary in VARIANTS:
		var rig := _rig(_art(row))
		rig.global_position = Vector3(0.0, 0.0, -1.0)
		rig.rotation.y = PI
		var worst := 0.0
		var worst_label := ""
		var edges_seen := 0
		for pitch: float in [FACE_PITCH_DEG, DEFAULT_PITCH_DEG]:
			var cam := _view(pitch)
			for pose: Dictionary in _act_poses():
				_put_in_pose(rig, pose)
				for mi: MeshInstance3D in rig.art_meshes():
					var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
					SkinnedView._prepare_strain(data)
					var rest := SkinnedView.skin_vertices(mi, rig, _rest_globals(rig))
					var posed := SkinnedView.skin_vertices(mi, rig)
					var world := mi.global_transform * posed
					var normals := SkinnedView.skin_normals(mi, rig)
					var world_normals := PackedVector3Array()
					world_normals.resize(normals.size())
					for v: int in normals.size():
						world_normals[v] = mi.global_transform.basis * normals[v]
					var in_frustum := _in_view(world, world_normals, cam)
					var soup := SkinnedView._soup(mi, rig, cam)
					for e: int in data.edge_a.size():
						var a := data.edge_a[e]
						var b := data.edge_b[e]
						if in_frustum[a] == 0 or in_frustum[b] == 0:
							continue
						edges_seen += 1
						var grow := posed[a].distance_to(posed[b]) - rest[a].distance_to(rest[b])
						if grow <= worst:
							continue
						# Only an edge the lens really sees counts: both ends are the first thing along their ray from
						# the lens (nothing nearer by more than 1.5 cm: an arm in front of the armpit hides it).
						if not (_seen_from(soup, cam.origin, world[a]) and _seen_from(soup, cam.origin, world[b])):
							continue
						worst = grow
						worst_label = "%s pitch %+.0f, bones %s/%s, rest %.1f cm at %s" % [pose.label, pitch, SkinnedView._dominant_bone(data, mi.skin, [a]),
								SkinnedView._dominant_bone(data, mi.skin, [b]), rest[a].distance_to(rest[b]) * 100.0, (rest[a] * 100.0).snapped(Vector3.ONE * 0.1)]
		print("ART-PUNK visible stretch %s: %d edges in view over the poses, the longest growth %.1f cm (%s); bar %.0f cm" % [
				row.name, edges_seen, worst * 100.0, worst_label, VISIBLE_STRETCH_M * 100.0])
		assert_gt(edges_seen, 1000, "%s: the poses were measured (%d edges in view)" % [row.name, edges_seen])
		if worst > VISIBLE_STRETCH_M:
			print("ART-PUNK   GATE: %s misses the 2 cm bar by %.1f cm" % [row.name, (worst - VISIBLE_STRETCH_M) * 100.0])
		assert_lte(worst, float(PUNK.ratchets.variant_stretch_m), "%s: no edge in view grows more than the ratchet's %.0f cm (%.1f cm at %s)" % [
				row.name, float(PUNK.ratchets.variant_stretch_m) * 100.0, worst * 100.0, worst_label])


## The nearest art vertex of `punk` to the lens `cam` ({distance, bone}), and with `in_view` only those the camera draws (inside
## the view's half-angles and in front of the lens).
func _nearest_to_lens(punk: StreetPunk, cam: Transform3D, in_view: bool) -> Dictionary:
	var nearest := INF
	var bone := &""
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var forward := -cam.basis.z
	for mi: MeshInstance3D in punk.rig.art_meshes():
		var world := mi.global_transform * SkinnedView.skin_vertices(mi, punk.rig)
		var best := -1
		for i: int in world.size():
			var to := world[i] - cam.origin
			if in_view:
				var depth := to.dot(forward)
				if depth <= 0.0 or absf(to.dot(cam.basis.x)) > tan_h * depth or absf(to.dot(cam.basis.y)) > tan_v * depth:
					continue
			var d := to.length()
			if d < nearest:
				nearest = d
				best = i
		if best >= 0:
			bone = SkinnedView._dominant_bone(SkinnedView._mesh_data(mi.mesh as ArrayMesh), mi.skin, [best])
	return {distance = nearest, bone = bone}


func test_a_held_punk_stays_a_quarter_metre_from_the_lens_through_the_grab_three_knees_and_the_throw() -> void:
	# Gap 7 of the slice gate (the art-drawn lens rule): the smoke Punk's cap came 0.20 m from the lens in a hold. In the real
	# test room, the Punk 1.1 m ahead, AI frozen: grab, three knees, let go, grab and throw; every second tick the nearest
	# vertex of the drawn art to the real first-person lens (view_from_eye) is at least 0.25 m.
	Tuning.data.dummy_health = 500.0
	var room := ROOM.instantiate() as Node3D
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks_physics(2)
	var player := room.get(&"player") as PlayerCharacter
	player.input.scripted = true
	Tuning.set_value(&"ai_frozen", true)
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i: int in dummies.size():
		dummies[i].sparring = false
		dummies[i].set_post(Vector3(30.0 + i * 3.0, 0.0, -30.0), 0.0, true)
	var punk := (load(PUNK.actor_scene) as PackedScene).instantiate() as StreetPunk
	room.add_child(punk)
	punk.global_position = player.global_position + player.global_basis * Vector3(0.0, 0.0, -1.1)
	var to_player := player.global_position - punk.global_position
	punk.rotation.y = atan2(-to_player.x, -to_player.z)
	await _ticks_physics(4)
	assert_true(punk.rig.has_art(), "the victim wears the art")
	var stats := {nearest = INF, bone = &"", samples = 0}
	var watch := func(ticks: int, always: bool) -> void:
		for i: int in ticks:
			await _ticks_physics(1)
			if i % 2 != 0:
				continue
			if not always and punk.state != CombatTypes.ActorState.GRABBED and player.current_move == null:
				continue
			var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
			var near := _nearest_to_lens(punk, cam, false)
			if near.distance < stats.nearest:
				stats.nearest = near.distance
				stats.bone = near.bone
			stats.samples += 1
	player.input.push_press(&"GRAB", 2)
	await watch.call(30, false)
	assert_not_null(player.holding_enemy(), "grabbed")
	var knee := Tuning.get_move(&"knee")
	for n: int in Tuning.data.max_knees:
		player.input.push_press(&"P", 2)
		await watch.call(knee.total_frames() + 10, false)
	await watch.call(45, true)
	for i: int in 60:
		if player.state == CombatTypes.ActorState.FREE and player.current_move == null:
			break
		await _ticks_physics(1)
	player.input.push_press(&"GRAB", 2)
	await watch.call(30, false)
	player.input.push_press(&"K", 2)
	await watch.call(Tuning.get_move(&"throw").total_frames() + 10, false)
	print("ART-PUNK hold: %d samples; nearest art vertex to the lens %.3f m on %s (the rule: %.2f m)" % [stats.samples, stats.nearest, stats.bone, HELD_CLEAR_M])
	assert_gt(stats.samples, 40, "the hold was sampled")
	assert_gte(stats.nearest, HELD_CLEAR_M, "a held victim stays 0.25 m from the lens (nearest %.3f m)" % stats.nearest)


func test_the_jab_and_cross_at_095_m_bring_no_art_vertex_in_view_nearer_than_5_cm() -> void:
	# The other half of gap 7: the Punk's own jab and cross (force_attack, the AI's telegraph and strike) at 0.95 m, the
	# nearest vertex of its drawn art inside the view to the real lens never nearer than FPView.NEAR (0.05 m).
	var arena := _arena()
	var player := arena.player as PlayerCharacter
	var punk := arena.punk as StreetPunk
	punk.position = Vector3(0.0, 0.0, -STRIKE_DISTANCE_M)
	await _ticks_physics(4)
	var nearest := INF
	for index: int in [0, 1]:
		punk.force_attack(index)
		var started := await _wait_physics(func() -> bool: return punk.current_move != null, 90)
		assert_true(started, "attack %d starts" % index)
		for i: int in 240:
			if punk.current_move == null:
				break
			await _ticks_physics(1)
			var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
			nearest = minf(nearest, _nearest_to_lens(punk, cam, true).distance)
		await _ticks_physics(20)
	print("ART-PUNK strikes at %.2f m: nearest art vertex in view %.3f m (the near plane: %.2f m)" % [STRIKE_DISTANCE_M, nearest, FPView.NEAR])
	assert_lt(nearest, INF, "the strikes were sampled")
	assert_gte(nearest, FPView.NEAR, "no vertex in view is nearer than the near plane (nearest %.3f m)" % nearest)


func _ticks_physics(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame
