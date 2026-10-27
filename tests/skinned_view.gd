extends RefCounted
## What a rig's skinned art looks like to the tests (Milestone 4, not a test script): the
## art's vertices skinned on the CPU with the rig's own Skin, the triangle soup of them, native
## TriangleMesh rays through the first-person grid (the art counterpart of fp_view.gd, whose
## hits() keep measuring the primitives that stand in for it), and the deformation strain of
## every edge. Shared by tests/test_skinned_art.gd and the art tests of F-punk and F-player.
##
## Everything works in rig space (the Skeleton3D's space) unless it says world: a skinned mesh
## is a child of the skeleton with an identity transform, so world = mesh.global_transform *
## rig space. The pose is the rig's animation pose (FK) after the latest advance(); pass
## `globals` (one Transform3D per skeleton bone, rig space) to skin another one: a ragdoll's
## visual pose, a pose made of PlaceholderBody.pose_globals(), a rest pose.

const FPView := preload("res://tests/fp_view.gd")

## Rays are walked past a back face this many times (a lens inside a limb sees the far side
## of it culled, and what lies beyond).
const MAX_BACK_FACES := 4
## The ray restarts this far (m) past a back face it skipped.
const BACK_FACE_STEP := 0.0001
## Strain percentiles (the plan's p99.9, and its mirror for the compressed end).
const STRAIN_HIGH_Q := 0.999
const STRAIN_LOW_Q := 0.001
## A vertex with one influence this strong is rigid on that bind.
const RIGID_WEIGHT := 0.9999

## One mesh's arrays and the structures built from them, made once (keyed by the ArrayMesh,
## which every rig of the same art shares).
class MeshData:
	extends RefCounted
	var vertices: PackedVector3Array
	var normals: PackedVector3Array
	var indices: PackedInt32Array
	var bones: PackedInt32Array
	var weights: PackedFloat32Array
	## One entry per non-zero influence: vertex, bind index, weight.
	var entry_vertex: PackedInt32Array = PackedInt32Array()
	var entry_bind: PackedInt32Array = PackedInt32Array()
	var entry_weight: PackedFloat32Array = PackedFloat32Array()
	## The bind that holds a vertex alone (weight >= RIGID_WEIGHT), or -1 for a blended one.
	var rigid_bind: PackedInt32Array = PackedInt32Array()
	## Strain data, built on first use: the edges whose two vertices are not rigid on the same
	## bind (the others keep their length exactly), their rest lengths, the count of all edges,
	## and the same for triangles (a triangle with a blended vertex, or one across two binds).
	var edge_a: PackedInt32Array = PackedInt32Array()
	var edge_b: PackedInt32Array = PackedInt32Array()
	var edge_rest: PackedFloat32Array = PackedFloat32Array()
	var edge_count: int = 0
	var mixed_triangles: PackedInt32Array = PackedInt32Array()
	var mixed_rest_area: PackedFloat32Array = PackedFloat32Array()
	var strain_ready: bool = false

## The native triangle mesh of one art mesh at one pose, and what built it.
class Soup:
	extends RefCounted
	var frame: int = -1
	var pose_key: int = 0
	var triangles: TriangleMesh
	var data: MeshData
	var skin: Skin

static var _data: Dictionary[int, MeshData] = {}
static var _soups: Dictionary[int, Soup] = {}


## Forget every cached mesh and triangle mesh.
static func clear_cache() -> void:
	_data.clear()
	_soups.clear()


## The skinned vertices of `mi` (an art mesh of `rig`), rig space: CPU linear-blend skinning
## with the rig's Skin, bind by bind with one native Transform3D * PackedVector3Array each and
## the weights accumulated per influence. `globals` is the pose (see the file's docs).
static func skin_vertices(mi: MeshInstance3D, rig: HumanoidRig, globals: Array[Transform3D] = []) -> PackedVector3Array:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	var matrices := _skin_matrices(mi.skin, rig, globals)
	var transformed: Array[PackedVector3Array] = []
	for matrix: Transform3D in matrices:
		transformed.append(matrix * data.vertices)
	var out := PackedVector3Array()
	out.resize(data.vertices.size())
	for e: int in data.entry_vertex.size():
		var v := data.entry_vertex[e]
		out[v] += transformed[data.entry_bind[e]][v] * data.entry_weight[e]
	return out


## The skinned vertex normals of `mi`, unit length, rig space (the bind rotations carry the
## rig's uniform scale, which the normalizing drops).
static func skin_normals(mi: MeshInstance3D, rig: HumanoidRig, globals: Array[Transform3D] = []) -> PackedVector3Array:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	var matrices := _skin_matrices(mi.skin, rig, globals)
	var out := PackedVector3Array()
	out.resize(data.normals.size())
	for e: int in data.entry_vertex.size():
		var v := data.entry_vertex[e]
		out[v] += matrices[data.entry_bind[e]].basis * data.normals[v] * data.entry_weight[e]
	for v: int in out.size():
		out[v] = out[v].normalized()
	return out


## The triangle soup of `mi` at the pose (3 vertices per triangle, the mesh's winding), world
## space.
static func faces(mi: MeshInstance3D, rig: HumanoidRig, globals: Array[Transform3D] = []) -> PackedVector3Array:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	var world := mi.global_transform * skin_vertices(mi, rig, globals)
	var soup := PackedVector3Array()
	soup.resize(data.indices.size())
	for i: int in data.indices.size():
		soup[i] = world[data.indices[i]]
	return soup


## What the first-person camera `cam` sees of the art under `root`: for each cell of the same
## `cols` x rows(cols) grid as FPView.hits(), in the same order, a Dictionary `{mesh, bone,
## depth}` of the nearest art surface along the cell's ray (the mesh, the bone holding most
## of the hit face's weight, the depth along the view axis), or `{}`. Only the art the camera
## draws counts (visible, not on CombatTypes.VIS_FP_HIDDEN); a surface nearer than
## FPView.NEAR, or a back face, does not. Each mesh's TriangleMesh is made once per physics
## frame and pose.
static func hits(root: Node, cam: Transform3D, cols: int = FPView.COLS) -> Array[Dictionary]:
	var meshes: Array[MeshInstance3D] = []
	var soups: Array[Soup] = []
	var rigs: Array[HumanoidRig] = []
	for mesh: MeshInstance3D in FPView.meshes_under(root):
		if not mesh.is_in_group(HumanoidRig.ART_GROUP) or not mesh.is_visible_in_tree():
			continue
		if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN):
			continue
		var rig := _rig_of(mesh)
		if rig == null:
			continue
		meshes.append(mesh)
		soups.append(_soup(mesh, rig))
		rigs.append(rig)
	var rows := FPView.rows(cols)
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var forward := -cam.basis.z
	var out: Array[Dictionary] = []
	for row: int in rows:
		for col: int in cols:
			var ray := Vector3(((col + 0.5) / cols * 2.0 - 1.0) * tan_h, (1.0 - (row + 0.5) / rows * 2.0) * tan_v, -1.0)
			var dir := (cam.basis * ray).normalized()
			var best: Dictionary = {}
			var best_depth := INF
			for i: int in meshes.size():
				var hit := _ray(soups[i], cam.origin, dir, forward)
				if hit.is_empty() or hit.depth >= best_depth:
					continue
				best_depth = hit.depth
				best = {mesh = meshes[i], bone = _face_bone(soups[i], hit.face), depth = hit.depth}
			out.append(best)
	return out


## The skinned vertices of `mi` that sit mostly (half the weight or more) on the binds of the
## bones named in `bones`, rig space.
static func bone_vertices(mi: MeshInstance3D, rig: HumanoidRig, bones: Array[StringName],
		globals: Array[Transform3D] = []) -> PackedVector3Array:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	var posed := skin_vertices(mi, rig, globals)
	var share := PackedFloat32Array()
	share.resize(posed.size())
	for e: int in data.entry_vertex.size():
		if bones.has(StringName(mi.skin.get_bind_name(data.entry_bind[e]))):
			share[data.entry_vertex[e]] += data.entry_weight[e]
	var out := PackedVector3Array()
	for v: int in posed.size():
		if share[v] >= 0.5:
			out.append(posed[v])
	return out


## The distance (m) from world `point` to the nearest skinned triangle of `mi` at the pose: the
## closest point of every triangle, brute force (for a handful of points, not a frame).
static func surface_gap(mi: MeshInstance3D, rig: HumanoidRig, point: Vector3, globals: Array[Transform3D] = []) -> float:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	var world := mi.global_transform * skin_vertices(mi, rig, globals)
	var best := INF
	for t: int in data.indices.size() / 3:
		var a := world[data.indices[t * 3]]
		var b := world[data.indices[t * 3 + 1]]
		var c := world[data.indices[t * 3 + 2]]
		best = minf(best, point.distance_to(_closest_on_triangle(point, a, b, c)))
	return best


## Art against its view proxies at camera `cam`: the same grid cast both ways. Returns
## `{cells, differ (cells one covers and the other does not), art_share, proxy_share (the
## shares of the view each covers), nearest (the most meters the art is nearer the lens than
## the proxies where both are hit; 0 when never), both}`. The proxies are the rig's own
## primitives, found by FPView.hits() (they are hidden while the art shows, but count: A4).
static func compare_with_proxies(rig: HumanoidRig, cam: Transform3D, cols: int = FPView.COLS) -> Dictionary:
	var proxy_cells := FPView.hits(rig, cam, cols)
	var proxy_depths := FPView.depths(rig, cam, cols)
	var covered: Array[bool] = []
	for mesh: MeshInstance3D in proxy_cells:
		covered.append(mesh != null)
	return _compare(hits(rig, cam, cols), covered, proxy_depths)


## The same against the proxies' own meshes, ray-cast exactly (a TriangleMesh of their
## triangles, as the art's): FPView's rays model a capsule by its closest approach to its axis
## and a dome as a flat ellipsoid, which a ray along a limb or across the cap sees a few
## centimeters off the primitives as they are drawn.
static func compare_with_exact_proxies(rig: HumanoidRig, cam: Transform3D, cols: int = FPView.COLS) -> Dictionary:
	var soup := Soup.new()
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in FPView.meshes_under(rig):
		if not mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP) or not FPView.is_drawn(mesh):
			continue
		if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN):
			continue
		faces.append_array(mesh.global_transform * mesh.mesh.get_faces())
	soup.triangles = TriangleMesh.new()
	soup.triangles.create_from_faces(faces)
	var rows := FPView.rows(cols)
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var forward := -cam.basis.z
	var covered: Array[bool] = []
	var depths := PackedFloat32Array()
	for row: int in rows:
		for col: int in cols:
			var ray := Vector3(((col + 0.5) / cols * 2.0 - 1.0) * tan_h, (1.0 - (row + 0.5) / rows * 2.0) * tan_v, -1.0)
			var hit := _ray(soup, cam.origin, (cam.basis * ray).normalized(), forward)
			covered.append(not hit.is_empty())
			depths.append(float(hit.depth) if not hit.is_empty() else INF)
	return _compare(hits(rig, cam, cols), covered, depths)


## What is wrong with the art's framing against its proxies at `cam` (row A9: at most 3% of the
## cells differ, the share of the view the art covers is within 4 points of the proxies', the
## art is nowhere `nearest_limit` meters (2 cm) or more nearer the lens than the proxies), as
## text lines headed by `label`; empty when it holds. `proxies` is compare_with_proxies() or
## compare_with_exact_proxies()'s result.
static func framing_problems(cmp: Dictionary, label: String, nearest_limit: float = 0.02) -> PackedStringArray:
	var out := PackedStringArray()
	if cmp.differ_share > 0.03:
		out.append("%s: %.1f%% of the cells differ" % [label, cmp.differ_share * 100.0])
	if absf(cmp.art_share - cmp.proxy_share) > 0.04:
		out.append("%s: the art covers %.1f%% of the view, the proxies %.1f%%" % [label, cmp.art_share * 100.0, cmp.proxy_share * 100.0])
	if cmp.nearest >= nearest_limit:
		out.append("%s: the art is %.1f cm nearer the lens than its proxies" % [label, cmp.nearest * 100.0])
	return out


static func _compare(art_cells: Array[Dictionary], proxy_covered: Array[bool], proxy_depths: PackedFloat32Array) -> Dictionary:
	var differ := 0
	var art_count := 0
	var proxy_count := 0
	var nearest := 0.0
	var both := 0
	for i: int in art_cells.size():
		var art_hit := not art_cells[i].is_empty()
		var proxy_hit := proxy_covered[i]
		art_count += int(art_hit)
		proxy_count += int(proxy_hit)
		differ += int(art_hit != proxy_hit)
		if art_hit and proxy_hit:
			both += 1
			nearest = maxf(nearest, proxy_depths[i] - float(art_cells[i].depth))
	var cells := art_cells.size()
	return {
		cells = cells, differ = differ, differ_share = float(differ) / cells,
		art_share = float(art_count) / cells, proxy_share = float(proxy_count) / cells,
		both = both, nearest = nearest,
	}


## The deformation of `mi` at the pose: every edge's posed length over its rest length (the
## authored mesh at the rig's scale), and the triangles that collapsed or turned over. Edges
## and triangles whose vertices all sit on one bind are exactly 1 and are not measured, only
## counted. Returns `{edges, mixed_edges, p_low, p_high (the strain percentiles), min, max,
## worst (the edge farthest from 1 in ratio: its strain), worst_bone, has_nan, triangles,
## mixed_triangles, squashed (posed area under `squash_below` of the rest's), flipped (face
## normal against the skinned vertex normals), lowest_y (of the posed vertices, rig space)}`.
## `with_triangles` false skips the triangle numbers.
static func strain(mi: MeshInstance3D, rig: HumanoidRig, globals: Array[Transform3D] = [],
		squash_below: float = 0.15, with_triangles: bool = false) -> Dictionary:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	_prepare_strain(data)
	var posed := skin_vertices(mi, rig, globals)
	var s := rig.rig_scale()
	var values := PackedFloat32Array()
	values.resize(data.edge_a.size())
	var has_nan := false
	var worst := 1.0
	var worst_edge := -1
	var lowest := INF
	for v: int in posed.size():
		lowest = minf(lowest, posed[v].y)
		if is_nan(posed[v].x) or is_nan(posed[v].y) or is_nan(posed[v].z):
			has_nan = true
	for e: int in data.edge_a.size():
		var ratio := posed[data.edge_a[e]].distance_to(posed[data.edge_b[e]]) / maxf(data.edge_rest[e] * s, 1e-9)
		values[e] = ratio
		if absf(log(maxf(ratio, 1e-6))) > absf(log(maxf(worst, 1e-6))):
			worst = ratio
			worst_edge = e
	var sorted := values.duplicate()
	sorted.sort()
	var report := {
		edges = data.edge_count, mixed_edges = data.edge_a.size(),
		p_low = _percentile(sorted, data.edge_count, STRAIN_LOW_Q),
		p_high = _percentile(sorted, data.edge_count, STRAIN_HIGH_Q),
		min = minf(1.0, sorted[0] if not sorted.is_empty() else 1.0),
		max = maxf(1.0, sorted[sorted.size() - 1] if not sorted.is_empty() else 1.0),
		worst = worst, worst_bone = &"", has_nan = has_nan, lowest_y = lowest,
		triangles = data.indices.size() / 3, mixed_triangles = data.mixed_triangles.size(),
		squashed = 0, flipped = 0,
	}
	if worst_edge >= 0:
		report.worst_bone = _dominant_bone(data, mi.skin, [data.edge_a[worst_edge], data.edge_b[worst_edge]])
	if with_triangles:
		var normals := skin_normals(mi, rig, globals)
		for t: int in data.mixed_triangles.size():
			var tri := data.mixed_triangles[t]
			var a := data.indices[tri * 3]
			var b := data.indices[tri * 3 + 1]
			var c := data.indices[tri * 3 + 2]
			var cross := (posed[b] - posed[a]).cross(posed[c] - posed[a])
			var area := cross.length() * 0.5
			if area < data.mixed_rest_area[t] * s * s * squash_below:
				report.squashed += 1
			# Godot's front faces wind clockwise: the geometric normal of (a, b, c) points
			# against the cross product of the edges.
			if -cross.dot(normals[a] + normals[b] + normals[c]) < 0.0:
				report.flipped += 1
	return report


## The (animation, phase, bone) triples to print for the worst strain of a run, worst first:
## `reports` is an array of `{label, report}` where report is strain()'s.
static func worst_lines(reports: Array[Dictionary], count: int = 10) -> PackedStringArray:
	var sorted := reports.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf(log(maxf(a.report.worst, 1e-6))) > absf(log(maxf(b.report.worst, 1e-6))))
	var out := PackedStringArray()
	for i: int in mini(count, sorted.size()):
		out.append("%s  strain x%.2f  bone %s" % [sorted[i].label, sorted[i].report.worst, sorted[i].report.worst_bone])
	return out


# --- Internals ---------------------------------------------------------------------------


## The point of triangle abc nearest p (Ericson, Real-Time Collision Detection 5.1.5).
static func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


## The rig an art mesh belongs to: the node above its skeleton.
static func _rig_of(mi: MeshInstance3D) -> HumanoidRig:
	var skeleton := mi.get_parent()
	return skeleton.get_parent() as HumanoidRig if skeleton != null else null


## Skin matrix of every bind of `skin`: the bone's pose times the bind pose.
static func _skin_matrices(skin: Skin, rig: HumanoidRig, globals: Array[Transform3D]) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for k: int in skin.get_bind_count():
		var bone := rig.skeleton.find_bone(skin.get_bind_name(k))
		var pose := rig.animation_pose(bone) if globals.is_empty() else globals[bone]
		out.append(pose * skin.get_bind_pose(k))
	return out


static func _mesh_data(mesh: ArrayMesh) -> MeshData:
	var id := mesh.get_instance_id()
	if _data.has(id):
		return _data[id]
	var data := MeshData.new()
	var arrays := mesh.surface_get_arrays(0)
	data.vertices = arrays[Mesh.ARRAY_VERTEX]
	data.normals = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	data.indices = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if data.indices.is_empty():
		data.indices.resize(data.vertices.size())
		for i: int in data.indices.size():
			data.indices[i] = i
	data.bones = arrays[Mesh.ARRAY_BONES]
	data.weights = arrays[Mesh.ARRAY_WEIGHTS]
	data.rigid_bind.resize(data.vertices.size())
	data.rigid_bind.fill(-1)
	for v: int in data.vertices.size():
		for j: int in SkinnedArt.INFLUENCES:
			var w := data.weights[v * SkinnedArt.INFLUENCES + j]
			if w <= 0.0:
				continue
			data.entry_vertex.append(v)
			data.entry_bind.append(data.bones[v * SkinnedArt.INFLUENCES + j])
			data.entry_weight.append(w)
			if w >= RIGID_WEIGHT:
				data.rigid_bind[v] = data.bones[v * SkinnedArt.INFLUENCES + j]
	_data[id] = data
	return data


## The unique edges and triangles that deform (see strain()).
static func _prepare_strain(data: MeshData) -> void:
	if data.strain_ready:
		return
	data.strain_ready = true
	var seen: Dictionary[int, bool] = {}
	var count := data.vertices.size()
	var triangle_count := data.indices.size() / 3
	for t: int in triangle_count:
		var corners: Array[int] = [data.indices[t * 3], data.indices[t * 3 + 1], data.indices[t * 3 + 2]]
		var rigid_triangle := true
		for k: int in 3:
			var a := corners[k]
			var b := corners[(k + 1) % 3]
			var lo := mini(a, b)
			var hi := maxi(a, b)
			var key := lo * count + hi
			var same := data.rigid_bind[a] >= 0 and data.rigid_bind[a] == data.rigid_bind[b]
			rigid_triangle = rigid_triangle and same
			if seen.has(key):
				continue
			seen[key] = true
			data.edge_count += 1
			if same:
				continue
			data.edge_a.append(lo)
			data.edge_b.append(hi)
			data.edge_rest.append(data.vertices[lo].distance_to(data.vertices[hi]))
		if not rigid_triangle:
			data.mixed_triangles.append(t)
			data.mixed_rest_area.append((data.vertices[corners[1]] - data.vertices[corners[0]]).cross(
					data.vertices[corners[2]] - data.vertices[corners[0]]).length() * 0.5)


## The value at quantile `q` of all `total` edges, given the sorted values of the measured
## ones: every unmeasured edge is exactly 1.
static func _percentile(sorted: PackedFloat32Array, total: int, q: float) -> float:
	if total <= 0:
		return 1.0
	var unmeasured := total - sorted.size()
	var rank := clampi(roundi(q * (total - 1)), 0, total - 1)
	var below := 0
	while below < sorted.size() and sorted[below] < 1.0:
		below += 1
	if rank < below:
		return sorted[rank]
	if rank < below + unmeasured:
		return 1.0
	return sorted[rank - unmeasured]


## The bind of `skin` that holds most of the summed weight of `vertices`, as a bone name.
static func _dominant_bone(data: MeshData, skin: Skin, vertices: Array) -> StringName:
	var weight: Dictionary[int, float] = {}
	for v: int in vertices:
		for j: int in SkinnedArt.INFLUENCES:
			var w := data.weights[v * SkinnedArt.INFLUENCES + j]
			if w > 0.0:
				var bind := data.bones[v * SkinnedArt.INFLUENCES + j]
				weight[bind] = weight.get(bind, 0.0) + w
	var best := -1
	var best_w := 0.0
	for bind: int in weight:
		if weight[bind] > best_w:
			best_w = weight[bind]
			best = bind
	return StringName(skin.get_bind_name(best)) if best >= 0 else &""


static func _face_bone(soup: Soup, face: int) -> StringName:
	var data := soup.data
	return _dominant_bone(data, soup.skin, [data.indices[face * 3], data.indices[face * 3 + 1], data.indices[face * 3 + 2]])


## A hash of what skins `mi`: the bone transforms, the rig's place, the skin and the mesh.
static func _pose_key(mi: MeshInstance3D, rig: HumanoidRig) -> int:
	var poses: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		poses.append(rig.animation_pose(i))
	return hash([poses, rig.global_transform, mi.skin.get_instance_id(), mi.mesh.get_instance_id()])


## The triangle mesh of `mi` at its rig's pose, made once per physics frame and pose.
static func _soup(mi: MeshInstance3D, rig: HumanoidRig) -> Soup:
	var id := mi.get_instance_id()
	var frame := Engine.get_physics_frames()
	var key := _pose_key(mi, rig)
	var soup: Soup = _soups.get(id)
	if soup != null and soup.frame == frame and soup.pose_key == key:
		return soup
	if soup == null:
		soup = Soup.new()
		_soups[id] = soup
	soup.frame = frame
	soup.pose_key = key
	soup.data = _mesh_data(mi.mesh as ArrayMesh)
	soup.skin = mi.skin
	soup.triangles = TriangleMesh.new()
	soup.triangles.create_from_faces(faces(mi, rig))
	return soup


## The nearest front-face hit of the ray from `origin` along unit `dir`: `{depth, face}` or {}.
static func _ray(soup: Soup, origin: Vector3, dir: Vector3, forward: Vector3) -> Dictionary:
	var from := origin
	for step: int in MAX_BACK_FACES:
		var hit := soup.triangles.intersect_ray(from, dir)
		if hit.is_empty():
			return {}
		var position: Vector3 = hit.position
		if (hit.normal as Vector3).dot(dir) > 0.0:
			from = position + dir * BACK_FACE_STEP
			continue
		var depth := (position - origin).dot(forward)
		if depth < FPView.NEAR:
			from = position + dir * BACK_FACE_STEP
			continue
		return {depth = depth, face = int(hit.face_index)}
	return {}
