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

## The shipped art A19 covers (P3-int): each worn the way the game wears it (the hero dressed as the player). The plan's bar (no
## problem line, p99.9 within [P_LOW, P_HIGH], the extremes within [MIN, MAX], at most BAD_TRIANGLES of the triangles under 15% of
## their rest area or turned over at a peak flex) is printed as GATE; neither art meets it yet (the weak joint is the shoulder at
## the guard and the arm raise, M4-calls/F-punk.md, F-player-art.md C15; the slice gate's contingency 4; and the hero's KO lying
## clips), so what each does today is held as a RATCHET that can fail: a fix only brings the figures down.
##
## The ratchet is set per art from the figures of the final art (M4-calls/fix-final-done-when-ratchets-and-suite-time.md has each
## old -> new), today's figure plus a small stated margin (a count of problem lines is no ratchet: it saturates at two a sample
## plus one a peak flex, so a worse sample cannot raise it, and was dropped):
## - `in_bar_min`: the samples inside every bar are at least today's count;
## - `high_max`, `low_min`, `max_max`, `min_min`: the worst p99.9, the worst p0.1 and the extreme edge's stretch and compression
##   over the whole run (about 5% over today; the compression floor is the number that a mis-weighted vertex would take to zero);
## - `flex_share_max`: the peak flexes' triangles under 15% of their rest area or turned over, as a share of the art's triangles;
## - the per-clip table (RATCHET_TABLE_PATH, made by tests/fixtures/art/gen_strain_ratchet.tscn from today's run): every clip's own
##   p99.9, p0.1, max and min over its five phases, and every peak flex's bad triangles, held to CLIP_MARGIN over today's, so a
##   regression in a clip that is not the art's worst shows too.
## The old SHIPPED rows read "problems_max 560 / 480"; ratchet_problems() is what test_skinned_art and test_m4_done_when assert.
const SHIPPED: Array[Dictionary] = [
	{name = "punk", path = "res://assets/export/characters/punk/punk.glb", art = "res://game/actors/art/punk_art.tres", player = false, budget = 15000,
			in_bar_min = 1, high_max = 4.23, low_min = 0.153, max_max = 12.85, min_min = 0.0144, flex_share_max = 0.0173},
	{name = "player", path = "res://assets/export/characters/player/player.glb", art = "res://game/actors/art/player_art.tres", player = true, budget = 30000,
			in_bar_min = 1, high_max = 9.1, low_min = 0.14, max_max = 39.1, min_min = 0.0282, flex_share_max = 0.0066},
]
## The per-clip ratchet's margin over today's figure (a ratio on p99.9 and the stretch; its inverse on p0.1 and the compression),
## and the flex triangle count's (a ratio, and two triangles).
const CLIP_MARGIN := 0.10
const RATCHET_TABLE_PATH := "res://tests/fixtures/art/strain_ratchet.json"

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
		triangles = data.indices.size() / 3, squashed = 0, flipped = 0, flipped_healed = 0,
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
## {label, clip, report}), flexes ({label, report} of the peak flexes), worst_high (the highest p99.9 of any sample), worst_low
## (the lowest p0.1), worst_max and worst_min (the longest stretch and the deepest compression of any edge), in_bar (the samples
## inside every bar), bad_bar (the triangles a peak flex may have under 15% of their rest area or turned over: the share of the
## art's triangles)}`. `rig` is left in its last pose; the caller frees it.
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
			reports.append({label = label, clip = clip.label, report = report})
			for text: String in problems_of(report, planted(rig)):
				problems.append("%s: %s" % [label, text])
	var flexes: Array[Dictionary] = []
	var triangles := 0
	for row: Dictionary in peak_poses():
		var report := strain_at(rig, globals_of(rig, row.pose, row.hips), true, rests, masks)
		triangles = report.triangles
		reports.append({label = "flex: %s" % row.label, clip = "flex: %s" % row.label, report = report})
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
	var worst_low := INF
	var worst_max := 1.0
	var worst_min := 1.0
	for entry: Dictionary in reports:
		var r: Dictionary = entry.report
		if r.p_high <= P_HIGH and r.p_low >= P_LOW and r.max <= MAX and r.min >= MIN:
			in_bar += 1
		worst_high = maxf(worst_high, r.p_high)
		worst_low = minf(worst_low, r.p_low)
		worst_max = maxf(worst_max, r.max)
		worst_min = minf(worst_min, r.min)
	return {
		problems = problems, kinds = kinds, worst = SkinnedView.worst_lines(reports), samples = reports.size(),
		reports = reports, flexes = flexes, worst_high = worst_high, worst_low = worst_low, worst_max = worst_max,
		worst_min = worst_min, in_bar = in_bar, bad_bar = roundi(BAD_TRIANGLES * triangles),
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


## The per-clip figures of `run_result`: `{clip: {high, low, max, min, bad}}`, each over the clip's phases (`bad`: a peak flex's
## triangles under 15% of their rest area or turned over; 0 for an animation or a move).
static func clip_table(run_result: Dictionary) -> Dictionary:
	var table := {}
	for entry: Dictionary in run_result.reports:
		var r: Dictionary = entry.report
		var row: Dictionary = table.get(entry.clip, {high = 0.0, low = INF, max = 1.0, min = 1.0, bad = 0})
		row.high = maxf(row.high, r.p_high)
		row.low = minf(row.low, r.p_low)
		row.max = maxf(row.max, r.max)
		row.min = minf(row.min, r.min)
		row.bad = maxi(row.bad, r.squashed + r.flipped)
		table[entry.clip] = row
	return table


## The per-clip ratchet figures the file holds for the art `art_name` ("punk" or "player"), or an empty Dictionary.
static func load_table(art_name: String) -> Dictionary:
	var file := FileAccess.open(RATCHET_TABLE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	return (parsed as Dictionary).get(art_name, {})


## What `run_result` does against the ratchet of `shipped` (a SHIPPED row) and `table` (load_table()): the lines that break it, or
## an empty array when it holds. The whole-run figures first (in_bar, p99.9, p0.1, the extreme edges, the flex share), then every
## clip against its own figures plus CLIP_MARGIN.
static func ratchet_problems(run_result: Dictionary, shipped: Dictionary, table: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if run_result.in_bar < int(shipped.in_bar_min):
		out.append("only %d samples inside every bar, at least %d held" % [run_result.in_bar, int(shipped.in_bar_min)])
	if run_result.worst_high > float(shipped.high_max):
		out.append("worst p99.9 %.3f over the ratchet %.3f" % [run_result.worst_high, float(shipped.high_max)])
	if run_result.worst_low < float(shipped.low_min):
		out.append("worst p0.1 %.3f under the ratchet %.3f" % [run_result.worst_low, float(shipped.low_min)])
	if run_result.worst_max > float(shipped.max_max):
		out.append("longest stretch x%.2f over the ratchet x%.2f" % [run_result.worst_max, float(shipped.max_max)])
	if run_result.worst_min < float(shipped.min_min):
		out.append("deepest compression x%.4f under the ratchet x%.4f" % [run_result.worst_min, float(shipped.min_min)])
	var share := worst_flex_share(run_result)
	if share > float(shipped.flex_share_max):
		out.append("a peak flex has %.2f%% of the triangles squashed or turned over, over the ratchet %.2f%%" % [share * 100.0, float(shipped.flex_share_max) * 100.0])
	var grow := 1.0 + CLIP_MARGIN
	var shrink := 1.0 / grow
	var rows := clip_table(run_result)
	for clip: String in rows:
		var row: Dictionary = rows[clip]
		if not table.has(clip):
			out.append("%s: no per-clip ratchet figure (regenerate tests/fixtures/art/strain_ratchet.json)" % clip)
			continue
		var held: Dictionary = table[clip]
		if row.high > float(held.high) * grow + 0.005:
			out.append("%s: p99.9 %.3f over its figure %.3f + %d%%" % [clip, row.high, float(held.high), roundi(CLIP_MARGIN * 100.0)])
		if row.low < float(held.low) * shrink - 0.005:
			out.append("%s: p0.1 %.3f under its figure %.3f - %d%%" % [clip, row.low, float(held.low), roundi(CLIP_MARGIN * 100.0)])
		if row.max > float(held.max) * grow + 0.005:
			out.append("%s: stretch x%.2f over its figure x%.2f + %d%%" % [clip, row.max, float(held.max), roundi(CLIP_MARGIN * 100.0)])
		if row.min < float(held.min) * shrink - 0.0005:
			out.append("%s: compression x%.4f under its figure x%.4f - %d%%" % [clip, row.min, float(held.min), roundi(CLIP_MARGIN * 100.0)])
		if row.bad > ceili(float(held.bad) * grow) + 2:
			out.append("%s: %d triangles squashed or turned over, over its figure %d + %d%% + 2" % [clip, row.bad, int(held.bad), roundi(CLIP_MARGIN * 100.0)])
	return out


## Each whole-run ratchet beside what the run did, for the DONE-WHEN and gate lines: "worst p99.9 4.03 (ratchet 4.25, +5%)".
static func margin_text(run_result: Dictionary, shipped: Dictionary) -> String:
	var share := worst_flex_share(run_result)
	return "ratchets (today, held, margin): in-bar samples %d >= %d; worst p99.9 %.2f <= %.2f (%+.1f%%); worst p0.1 %.2f >= %.2f (%+.1f%%); longest stretch x%.1f <= x%.1f (%+.1f%%); deepest compression x%.4f >= x%.4f (%+.1f%%); peak flex share %.2f%% <= %.2f%% (%+.2f points); every clip +%d%%" % [
			run_result.in_bar, int(shipped.in_bar_min),
			run_result.worst_high, float(shipped.high_max), _percent(float(shipped.high_max), run_result.worst_high),
			run_result.worst_low, float(shipped.low_min), _percent(run_result.worst_low, float(shipped.low_min)),
			run_result.worst_max, float(shipped.max_max), _percent(float(shipped.max_max), run_result.worst_max),
			run_result.worst_min, float(shipped.min_min), _percent(run_result.worst_min, float(shipped.min_min)),
			share * 100.0, float(shipped.flex_share_max) * 100.0, (float(shipped.flex_share_max) - share) * 100.0,
			roundi(CLIP_MARGIN * 100.0)]


## How far `held` is above `today`, in per cent of `today`.
static func _percent(held: float, today: float) -> float:
	return (held - today) / maxf(today, 1e-9) * 100.0


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
