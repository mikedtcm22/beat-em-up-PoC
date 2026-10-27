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


## The foot slide of a walk cycle: the clip plays over `cycles` cycles while its rig moves along
## `travel` (a unit vector in rig space) at `world_speed` meters per second of CLIP time (what
## HumanoidRig.play_locomotion() does: it plays at v / move_speed, so the rig moves move_speed
## meters per clip second). Each sole vertex's planted runs (under PLANT_M) are followed in
## world space; a run's slide is how far the vertex strays from where it came down, and only runs
## that begin in the middle cycle count (so none is cut by the ends). Returns `{slide (the worst
## run, m), runs, planted_frames, lowest (the lowest vertex seen, m), worst_vertex_frame}`.
static func walk_slide(mi: MeshInstance3D, rig: HumanoidRig, anim: Animation, sole: PackedInt32Array,
		travel: Vector3, world_speed: float, step_s: float = 1.0 / 120.0) -> Dictionary:
	var length := anim.length
	var frames := int(ceil(3.0 * length / step_s))
	var start := Array([], TYPE_VECTOR3, "", null)
	var run_start := {}  # vertex -> Vector3 where it came down
	var run_begun := {}  # vertex -> bool counted
	var slide := 0.0
	var runs := 0
	var planted_frames := 0
	var lowest := INF
	var worst_t := 0.0
	var worst_vertex := -1
	for f: int in frames + 1:
		var tau := f * step_s
		var t := fposmod(tau, length)
		var posed := SkinnedView.skin_vertices(mi, rig, clip_globals(rig, anim, t))
		var origin := travel * world_speed * tau
		for v: int in sole:
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
