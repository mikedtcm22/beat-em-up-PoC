extends RefCounted
## The deformation strain of M4-plan Part A's A19 (row A7), against the SKINNED REST pose, for any rig wearing art: every
## PlaceholderAnims.ANIM_IDS id and each move given, at five phases (start, 25%, the peak or the active frames, 75%, end),
## then the peak flexes (guard, elbow 150, arm raise 140, knee -130, spine twist, lying). Each edge's posed length is
## measured over the same edge skinned at the rig's rest, not over the GLB's own mesh: an art authored in the A-pose is
## already strained at rest by construction (M4-calls/P1-chain.md C13), and what the player sees is the change from the
## rest. A triangle counts as turned over only when it was not folded at the skinned rest (SkinnedView.folded_mask()).
##
## test_skinned_art.gd (the shipped GLBs, printed for the gate) and test_m4_done_when.gd (row A7) both run it, so the run
## is made once per art and kept (`cached()`/`keep()`): a run is about 6 s. A rig with two meshes (the player's visible
## body and its FP-hidden half) reports the worst of its meshes per number, and the sum of their triangles.

const SkinnedView := preload("res://tests/skinned_view.gd")
const FRAME := 1.0 / 60.0
## Part B row A7 (and A19)'s bars.
const P_HIGH := 1.6
const P_LOW := 0.6
const MAX := 2.2
const MIN := 0.4
## A vertex lower than this in a planted pose is under the floor (row A4, A19).
const FLOOR_M := -0.015
## The share of the triangles that may be under 15% of their rest area or turned over at a peak flex (row A7).
const BAD_TRIANGLES := 0.005
## A planted pose: the lowest sole point is within this of the floor.
const PLANTED_M := 0.002
## The Punk's own moves, whose clips the strain run plays as well (the file names in game/combat/moves).
const PUNK_MOVES: Array[String] = ["punk_jab", "punk_cross", "punk_shove"]

## The shipped art A19 covers (P3-int): each worn the way the game wears it (the hero dressed as the player). `problems_max` and
## `high_max` are what the art does today, with a margin, a ratchet: the weak joint is the shoulder at the guard and the arm raise
## (M4-calls/F-punk.md, F-player-art.md C15; the slice gate's contingency 4), and the hero's KO lying clips. A run may have at most
## `problems_max` problem lines (two a sample: its p99.9 and its extremes; today 503 for the Punk's 251 samples, 424 for the
## hero's 236) and a worst p99.9 of at most `high_max`. The art fixers only bring them down. The plan's bar (no problem line,
## p99.9 within [P_LOW, P_HIGH]) is printed as GATE. The peak flexes' triangles (under 15% of their rest area or turned over)
## are held to FLEX_RATCHET_SHARE of the art's triangles, where the plan's bar is BAD_TRIANGLES (today 1.56% at most).
const SHIPPED: Array[Dictionary] = [
	{name = "punk", path = "res://assets/export/characters/punk/punk.glb", player = false, budget = 15000, problems_max = 560, high_max = 4.6},
	{name = "player", path = "res://assets/export/characters/player/player.glb", player = true, budget = 30000, problems_max = 480, high_max = 9.5},
]
const FLEX_RATCHET_SHARE := 0.02

static var _runs: Dictionary[String, Dictionary] = {}


## The run kept under `key`, or an empty Dictionary.
static func cached(key: String) -> Dictionary:
	return _runs.get(key, {})


## Keep `run` under `key` for the next caller; returns it.
static func keep(key: String, run: Dictionary) -> Dictionary:
	_runs[key] = run
	return run


## The Punk's three moves.
static func punk_moves() -> Array[MoveData]:
	var out: Array[MoveData] = []
	for id: String in PUNK_MOVES:
		out.append(load("res://game/combat/moves/%s.tres" % id) as MoveData)
	return out


## The peak flexes of row A7: [label, pose (bone -> Euler degrees), hips offset].
static func peak_poses() -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	poses.append({label = "guard", pose = PlaceholderPoses.guard(), hips = Vector3.ZERO})
	poses.append({label = "elbow 150", pose = {&"LeftLowerArm": Vector3(150.0, 0.0, 0.0), &"RightLowerArm": Vector3(150.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "arm raise 140", pose = {&"LeftUpperArm": Vector3(140.0, 0.0, 0.0), &"RightUpperArm": Vector3(140.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "knee -130", pose = {&"LeftLowerLeg": Vector3(-130.0, 0.0, 0.0), &"LeftUpperLeg": Vector3(40.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "spine twist", pose = {&"Spine": Vector3(0.0, 25.0, 0.0), &"Chest": Vector3(0.0, 25.0, 0.0), &"UpperChest": Vector3(0.0, 20.0, 0.0), &"Neck": Vector3(0.0, 20.0, 0.0), &"Head": Vector3(0.0, 30.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3.ZERO})
	poses.append({label = "lying", pose = {&"Hips": Vector3(-90.0, 0.0, 0.0)} as Dictionary[StringName, Vector3], hips = Vector3(0.0, -0.8, 0.0)})
	return poses


## The skeleton's bone globals at the table pose `pose` with the hips at `hips`, in the skeleton's bone order.
static func globals_of(rig: HumanoidRig, pose: Dictionary[StringName, Vector3], hips: Vector3) -> Array[Transform3D]:
	var table := PlaceholderBody.pose_globals(pose, hips, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


## The pose test: is the rig's lowest sole point on the floor.
static func planted(rig: HumanoidRig) -> bool:
	var globals: Dictionary[StringName, Transform3D] = {}
	for i: int in rig.skeleton.get_bone_count():
		globals[rig.skeleton.get_bone_name(i)] = rig.animation_pose(i)
	return absf(PlaceholderBody.lowest_sole(globals, rig.rig_scale())) < PLANTED_M


## The folded triangles of `mi` skinned at the rest: the flip count's reference, per blended triangle.
static func rest_mask(mi: MeshInstance3D, rig: HumanoidRig) -> PackedByteArray:
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	SkinnedView._prepare_strain(data)
	var rest := SkinnedView.rest_pose(rig)
	return SkinnedView.folded_mask(data, SkinnedView.skin_vertices(mi, rig, rest), SkinnedView.skin_normals(mi, rig, rest))


## The strain of `mi` posed at `globals` (empty: the rig's current pose) against the same mesh skinned at the rig's rest
## `rest` (its vertices): every deforming edge's posed length over its rest length, p0.1 and p99.9 over all the mesh's edges
## (an edge on one bind is exactly 1), the extremes, NaN, the lowest vertex, and with `triangles` the triangles under 15% of
## their rest area (`squashed`) or turned over (`flipped`: folded against their vertex normals in the pose and not at the
## skinned rest). `mask` is rest_mask() when the caller has it.
static func strain(mi: MeshInstance3D, rig: HumanoidRig, rest: PackedVector3Array, globals: Array[Transform3D],
		triangles: bool, mask: PackedByteArray = PackedByteArray()) -> Dictionary:
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
	for e: int in data.edge_a.size():
		var rest_length := rest[data.edge_a[e]].distance_to(rest[data.edge_b[e]])
		if rest_length < SkinnedView.MIN_EDGE_M:
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
		triangles = data.indices.size() / 3, squashed = 0, flipped = 0,
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
		var reference := mask if not mask.is_empty() else rest_mask(mi, rig)
		var flips := SkinnedView.flip_counts(reference, SkinnedView.folded_mask(data, posed, SkinnedView.skin_normals(mi, rig, globals)))
		report.flipped = flips.turned
	return report


## The merged strain of every art mesh of `rig` at `globals`: the worst of each number, the triangle counts summed. `rests`
## and `masks` are per mesh (the run makes them once).
static func strain_at(rig: HumanoidRig, globals: Array[Transform3D], triangles: bool,
		rests: Array[PackedVector3Array], masks: Array[PackedByteArray]) -> Dictionary:
	var merged := {}
	var meshes := rig.art_meshes()
	for k: int in meshes.size():
		var report := strain(meshes[k], rig, rests[k], globals, triangles, masks[k])
		if merged.is_empty():
			merged = report
			continue
		merged.p_high = maxf(merged.p_high, report.p_high)
		merged.p_low = minf(merged.p_low, report.p_low)
		merged.max = maxf(merged.max, report.max)
		merged.min = minf(merged.min, report.min)
		merged.lowest_y = minf(merged.lowest_y, report.lowest_y)
		merged.has_nan = merged.has_nan or report.has_nan
		merged.squashed += report.squashed
		merged.flipped += report.flipped
		merged.triangles += report.triangles
		if absf(log(report.worst)) > absf(log(merged.worst)):
			merged.worst = report.worst
			merged.worst_bone = report.worst_bone
	return merged


## The problems of one sample against row A7's bars (empty when it passes): NaN, p99.9 / p0.1 outside [P_LOW, P_HIGH], the
## extremes outside [MIN, MAX], and in a `planted` pose a vertex under the floor.
static func problems_of(report: Dictionary, is_planted: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if report.has_nan:
		out.append("NaN")
	if report.p_high > P_HIGH or report.p_low < P_LOW:
		out.append("p99.9 %.2f / p0.1 %.2f outside [%.1f, %.1f]" % [report.p_high, report.p_low, P_LOW, P_HIGH])
	if report.max > MAX or report.min < MIN:
		out.append("max %.2f / min %.2f outside [%.1f, %.1f]" % [report.max, report.min, MIN, MAX])
	if is_planted and report.lowest_y < FLOOR_M:
		out.append("a vertex %.1f cm under the floor in a planted pose" % [-report.lowest_y * 100.0])
	return out


## The kind of a problem line: "NaN", "the floor", "flipped or squashed triangles" or "strain range".
static func kind_of(text: String) -> String:
	if text.contains("NaN"):
		return "NaN"
	if text.contains("floor"):
		return "the floor"
	if text.contains("triangles under"):
		return "flipped or squashed triangles"
	return "strain range"


## A19 on `rig`'s art: every PlaceholderAnims.ANIM_IDS id and each of `moves` at five phases, then the peak flexes.
## `{problems (the lines), kinds (a count per kind), worst (the worst ten lines), samples, reports (every sample:
## {label, report}), flexes ({label, report} of the peak flexes), worst_high (the highest p99.9 of any sample), in_bar (the
## samples inside every bar), bad_bar (the triangles a peak flex may have under 15% of their rest area or turned over: the
## share of the art's triangles)}`. `rig` is left in its last pose; the caller frees it.
static func run(rig: HumanoidRig, moves: Array[MoveData]) -> Dictionary:
	var rests: Array[PackedVector3Array] = []
	var masks: Array[PackedByteArray] = []
	var rest_globals := SkinnedView.rest_pose(rig)
	for mi: MeshInstance3D in rig.art_meshes():
		rests.append(SkinnedView.skin_vertices(mi, rig, rest_globals))
		masks.append(rest_mask(mi, rig))
	var problems := PackedStringArray()
	var reports: Array[Dictionary] = []
	var clips: Array[Dictionary] = []
	for id: StringName in PlaceholderAnims.ANIM_IDS:
		clips.append({label = String(id), id = id, move = null})
	for move: MoveData in moves:
		clips.append({label = String(move.id), id = move.id, move = move})
	for clip: Dictionary in clips:
		_play(rig, &"idle", 0.2)
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
			var report := strain_at(rig, [], false, rests, masks)
			var label := "%s %s" % [clip.label, phase[0]]
			reports.append({label = label, report = report})
			for text: String in problems_of(report, planted(rig)):
				problems.append("%s: %s" % [label, text])
	var flexes: Array[Dictionary] = []
	var triangles := 0
	for row: Dictionary in peak_poses():
		var report := strain_at(rig, globals_of(rig, row.pose, row.hips), true, rests, masks)
		triangles = report.triangles
		reports.append({label = "flex: %s" % row.label, report = report})
		flexes.append({label = String(row.label), report = report})
		for text: String in problems_of(report, false):
			problems.append("flex: %s: %s" % [row.label, text])
		if report.triangles > 0 and float(report.squashed + report.flipped) / report.triangles > BAD_TRIANGLES:
			problems.append("flex: %s: %d of %d triangles under 15%% of their rest area or turned over" % [row.label, report.squashed + report.flipped, report.triangles])
	var kinds := {}
	for text: String in problems:
		var kind := kind_of(text)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	var in_bar := 0
	var worst_high := 0.0
	for entry: Dictionary in reports:
		var r: Dictionary = entry.report
		if r.p_high <= P_HIGH and r.p_low >= P_LOW and r.max <= MAX and r.min >= MIN:
			in_bar += 1
		worst_high = maxf(worst_high, r.p_high)
	return {
		problems = problems, kinds = kinds, worst = SkinnedView.worst_lines(reports), samples = reports.size(),
		reports = reports, flexes = flexes, worst_high = worst_high, in_bar = in_bar,
		bad_bar = roundi(BAD_TRIANGLES * triangles),
	}


## The five samples with the highest p99.9, as "label p99.9 x.xx" lines.
static func highest(run_result: Dictionary, count: int = 5) -> PackedStringArray:
	var by_high: Array = (run_result.reports as Array).duplicate()
	by_high.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.report.p_high > b.report.p_high)
	var out := PackedStringArray()
	for entry: Dictionary in by_high.slice(0, count):
		out.append("%s p99.9 %.2f" % [entry.label, entry.report.p_high])
	return out


## A peak flex's triangles under 15% of their rest area or turned over, as "<label> <count>" for those over the run's bar.
static func flexes_over_bar(run_result: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for flex: Dictionary in run_result.flexes:
		var r: Dictionary = flex.report
		var bad: int = r.squashed + r.flipped
		if bad > int(run_result.bad_bar):
			out.append("%s %d" % [flex.label, bad])
	return out


static func _play(rig: HumanoidRig, animation: StringName, at: float) -> void:
	rig.play(animation, 0.0)
	rig.advance(0.0)
	rig.advance(at)


## The highest share of the art's triangles any peak flex has under 15% of their rest area or turned over.
static func worst_flex_share(run_result: Dictionary) -> float:
	var worst := 0.0
	for flex: Dictionary in run_result.flexes:
		var r: Dictionary = flex.report
		if r.triangles > 0:
			worst = maxf(worst, float(r.squashed + r.flipped) / float(r.triangles))
	return worst
