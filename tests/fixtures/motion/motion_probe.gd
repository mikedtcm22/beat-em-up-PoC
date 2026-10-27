extends RefCounted
## What a placeholder clip does to the skinned art (F-motion, M4; not a test script): a clip sampled
## on its own (no AnimationPlayer, so no blend and no other clip), the rig's FK for it, and the
## measurements the motion tests and acts share: the art's soles through a walk, the hurtboxes
## through an idle, the deformation strain at a phase.

const SkinnedView := preload("res://tests/skinned_view.gd")

## A sole vertex counts as planted below this height (m); the sole is the foot's skin that starts
## under SOLE_REST_M at the table's rest and is held SOLE_WEIGHT or more by the foot and toes
## binds (the ankle's blended skin is no sole: it follows the shin).
const PLANT_M := 0.01
const SOLE_REST_M := 0.02
const SOLE_WEIGHT := 0.9
const FOOT_BINDS: Array[StringName] = [&"LeftFoot", &"LeftToes", &"RightFoot", &"RightToes"]


## One Transform3D per skeleton bone (rig space) for `anim` at `t`: the rig's rest offsets, the
## clip's rotations (whatever the track's interpolation) and its Hips position, parents first.
static func clip_globals(rig: HumanoidRig, anim: Animation, t: float) -> Array[Transform3D]:
	var skeleton := rig.skeleton
	var out: Array[Transform3D] = []
	for i: int in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		var origin := skeleton.get_bone_rest(i).origin
		var pos_track := anim.find_track(NodePath("Skeleton3D:%s" % bone), Animation.TYPE_POSITION_3D)
		if pos_track >= 0:
			origin = anim.position_track_interpolate(pos_track, t)
		var rot := Quaternion.IDENTITY
		var rot_track := anim.find_track(NodePath("Skeleton3D:%s" % bone), Animation.TYPE_ROTATION_3D)
		if rot_track >= 0:
			rot = anim.rotation_track_interpolate(rot_track, t)
		var local := Transform3D(Basis(rot), origin)
		var parent := skeleton.get_bone_parent(i)
		out.append(local if parent < 0 else out[parent] * local)
	return out


## The art's pose at the table's rest, for picking vertices (rig space).
static func rest_globals(rig: HumanoidRig) -> Array[Transform3D]:
	var empty: Dictionary[StringName, Vector3] = {}
	var table := PlaceholderBody.pose_globals(empty, Vector3.ZERO, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


## The indices of the art's sole vertices: held half or more by a foot or toe bind, and under
## SOLE_REST_M at the table's rest.
static func sole_vertices(mi: MeshInstance3D, rig: HumanoidRig) -> PackedInt32Array:
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	var share := PackedFloat32Array()
	share.resize(data.vertices.size())
	for e: int in data.entry_vertex.size():
		if FOOT_BINDS.has(StringName(mi.skin.get_bind_name(data.entry_bind[e]))):
			share[data.entry_vertex[e]] += data.entry_weight[e]
	var rest := SkinnedView.skin_vertices(mi, rig, rest_globals(rig))
	var out := PackedInt32Array()
	for v: int in rest.size():
		if share[v] >= SOLE_WEIGHT and rest[v].y < SOLE_REST_M:
			out.append(v)
	return out


## The foot slide of a walk cycle on the art: see walk_slide_with(); the points are the skinned `sole`
## vertices (sole_vertices()).
static func walk_slide(mi: MeshInstance3D, rig: HumanoidRig, anim: Animation, sole: PackedInt32Array,
		travel: Vector3, world_speed: float, step_s: float = 1.0 / 120.0) -> Dictionary:
	var sampler := func(globals: Array[Transform3D]) -> PackedVector3Array:
		var posed := SkinnedView.skin_vertices(mi, rig, globals)
		var out := PackedVector3Array()
		for v: int in sole:
			out.append(posed[v])
		return out
	return walk_slide_with(sampler, rig, anim, travel, world_speed, step_s)


## The foot slide of a walk cycle on the placeholder's own sole points (the heel, the ball and the tip of
## each foot, PlaceholderBody.SOLE_BONES), for rigs that wear no art (the Bruiser's and the boss's size).
static func primitive_slide(rig: HumanoidRig, anim: Animation, travel: Vector3, world_speed: float,
		step_s: float = 1.0 / 120.0) -> Dictionary:
	var scale := rig.rig_scale()
	var sampler := func(globals: Array[Transform3D]) -> PackedVector3Array:
		var out := PackedVector3Array()
		for i: int in PlaceholderBody.SOLE_BONES.size():
			out.append(globals[rig.skeleton.find_bone(PlaceholderBody.SOLE_BONES[i])] * (PlaceholderBody.SOLE_OFFSETS[i] * scale))
		return out
	return walk_slide_with(sampler, rig, anim, travel, world_speed, step_s)


## The foot slide of a walk cycle: the clip plays over three cycles while its rig moves along `travel` (a
## unit vector in rig space) at `world_speed` meters per second of CLIP time (what HumanoidRig.
## play_locomotion() does: it plays at v / move_speed, so the rig moves move_speed meters per clip second).
## `sampler` gives the sole points (rig space) for the bone transforms of a sample. Each point's planted
## runs (under PLANT_M) are followed in world space; a run's slide is how far the point strays from where
## it came down, and only runs that begin in the middle cycle count (so none is cut by the ends).
## Returns `{slide (the worst run, m), runs, planted_frames, lowest (the lowest point seen, m), worst_t,
## worst_vertex}`.
static func walk_slide_with(sampler: Callable, rig: HumanoidRig, anim: Animation, travel: Vector3,
		world_speed: float, step_s: float = 1.0 / 120.0) -> Dictionary:
	var length := anim.length
	var frames := int(ceil(3.0 * length / step_s))
	var run_start := {}  # point -> Vector3 where it came down
	var run_begun := {}  # point -> bool counted
	var slide := 0.0
	var runs := 0
	var planted_frames := 0
	var lowest := INF
	var worst_t := 0.0
	var worst_vertex := -1
	for f: int in frames + 1:
		var tau := f * step_s
		var t := fposmod(tau, length)
		var posed: PackedVector3Array = sampler.call(clip_globals(rig, anim, t))
		var origin := travel * world_speed * tau
		for v: int in posed.size():
			var p := posed[v]
			lowest = minf(lowest, p.y)
			var world := Vector3(p.x + origin.x, 0.0, p.z + origin.z)
			if p.y < PLANT_M:
				planted_frames += 1
				if not run_start.has(v):
					run_start[v] = world
					run_begun[v] = tau >= length and tau < 2.0 * length
					if run_begun[v]:
						runs += 1
				elif run_begun[v]:
					var drift := world.distance_to(run_start[v])
					if drift > slide:
						slide = drift
						worst_t = t
						worst_vertex = v
			else:
				run_start.erase(v)
				run_begun.erase(v)
	return {slide = slide, runs = runs, planted_frames = planted_frames, lowest = lowest, worst_t = worst_t,
			worst_vertex = worst_vertex}


## The key points of the hurtboxes (rig space) for bone transforms `globals`: a sphere's center and both
## ends of a capsule's axis, in PlaceholderBody.hurt_specs() order.
static func hurt_points(rig: HumanoidRig, globals: Array[Transform3D]) -> Array[Vector3]:
	var scale := rig.rig_scale()
	var out: Array[Vector3] = []
	for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
		out.append(globals[rig.skeleton.find_bone(spec.bone_a)] * (spec.offset_a * scale))
		if spec.is_capsule():
			out.append(globals[rig.skeleton.find_bone(spec.bone_b)] * (spec.offset_b * scale))
	return out


## How far each hurtbox key point moves over `anim` (the largest distance between any two of its places,
## meters), sampled every `step_s`.
static func hurt_extent(rig: HumanoidRig, anim: Animation, step_s: float = 1.0 / 30.0) -> PackedFloat32Array:
	var samples: Array = []
	var t := 0.0
	while t < anim.length - 1e-6:
		samples.append(hurt_points(rig, clip_globals(rig, anim, t)))
		t += step_s
	var out := PackedFloat32Array()
	out.resize((samples[0] as Array).size())
	for a: Array in samples:
		for b: Array in samples:
			for k: int in a.size():
				out[k] = maxf(out[k], (a[k] as Vector3).distance_to(b[k]))
	return out


## The deformation of the art at bone transforms `globals` against the same art skinned at `rest`
## (rest_globals()'s vertices): every deforming edge's posed length over its rest length. Returns `{p_low,
## p_high (the 0.1 and 99.9 percentiles), min, max, worst (the edge farthest from 1), worst_bone}`
## (tests/test_art_punk.gd's _strain without the triangles).
static func strain(mi: MeshInstance3D, rig: HumanoidRig, rest: PackedVector3Array,
		globals: Array[Transform3D]) -> Dictionary:
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	SkinnedView._prepare_strain(data)
	var posed := SkinnedView.skin_vertices(mi, rig, globals)
	var values := PackedFloat32Array()
	var worst := 1.0
	var worst_edge := -1
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
	var out := {
		p_low = SkinnedView._percentile(sorted, data.edge_count, SkinnedView.STRAIN_LOW_Q),
		p_high = SkinnedView._percentile(sorted, data.edge_count, SkinnedView.STRAIN_HIGH_Q),
		min = minf(1.0, sorted[0] if not sorted.is_empty() else 1.0),
		max = maxf(1.0, sorted[sorted.size() - 1] if not sorted.is_empty() else 1.0),
		worst = worst, worst_bone = &"",
	}
	if worst_edge >= 0:
		out.worst_bone = SkinnedView._dominant_bone(data, mi.skin, [data.edge_a[worst_edge], data.edge_b[worst_edge]])
	return out
