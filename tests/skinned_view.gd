extends RefCounted
## What a rig's skinned art looks like to the tests (Milestone 4, not a test script): the
## art's vertices skinned on the CPU with the rig's own Skin, the triangle soup of them, native
## TriangleMesh rays through the first-person grid (the art counterpart of fp_view.gd, whose
## hits() keep measuring the primitives that stand in for it), and the deformation strain of
## every edge. Shared by tests/test_skinned_art.gd and the art tests of F-punk and F-player.
##
## Everything works in rig space (the Skeleton3D's space) unless it says world: a skinned mesh
## is a child of the skeleton with an identity transform, so world = mesh.global_transform *
## rig space. The pose is the one the render server draws (drawn_pose()): the rig's animation
## pose (FK) after the latest advance(), or, while a ragdoll runs on the rig, the ragdoll's
## visual pose per bone (an art rig writes it back into its skeleton, A5), which can be tens of
## centimeters from FK in a stagger. Pass `globals` (one Transform3D per skeleton bone, rig
## space) to skin another one: fk_pose() to see the animation under a ragdoll, a pose made of
## PlaceholderBody.pose_globals(), a rest pose. The grid-ray path (hits(), the compare_*
## wrappers, hurtbox_fit()'s soups) skins the drawn pose too, so an act that measures the art
## through a stagger or a launch measures the body that is on screen.

const FPView := preload("res://tests/fp_view.gd")

## Rays are walked past a back face this many times (a lens inside a limb sees the far side
## of it culled, and what lies beyond).
const MAX_BACK_FACES := 4
## The ray restarts this far (m) past a back face it skipped.
const BACK_FACE_STEP := 0.0001
## Strain percentiles (the plan's p99.9, and its mirror for the compressed end).
const STRAIN_HIGH_Q := 0.999
const STRAIN_LOW_Q := 0.001
## An edge shorter than this at rest (a pole of a sphere, a degenerate triangle) has no strain
## to speak of: it is not measured, and counts as 1.
const MIN_EDGE_M := 0.0001
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
	## The first entry of each vertex (the entries are in vertex order), and one past the last at the end: the vertex `v`'s
	## entries are `entry_start[v]` up to `entry_start[v + 1]`.
	var entry_start: PackedInt32Array = PackedInt32Array()
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
	## The triangle soup's layout (built on first use): the triangles all three of whose corners
	## are rigid on one bind go in that bind's group, in rest pose, so a pose is one native
	## transform per group; the others (`soup_mixed`) are skinned vertex by vertex. `bind_aabb` is the rest box of every vertex with weight
	## on a bind (the bounds of a posed mesh: the union of these, each at its bind's matrix).
	var soup_ready: bool = false
	var group_corners: Array[PackedVector3Array] = []
	var group_triangles: Array[PackedInt32Array] = []
	var soup_mixed: PackedInt32Array = PackedInt32Array()
	## The three vertex indices of each mixed triangle, flat.
	var mixed_corner: PackedInt32Array = PackedInt32Array()
	var mixed_vertex_entry: PackedInt32Array = PackedInt32Array()
	var bind_aabb: Array[AABB] = []

## The native triangle mesh of one art mesh at one pose, and what built it.
class Soup:
	extends RefCounted
	var frame: int = -1
	var pose_key: int = 0
	var triangles: TriangleMesh
	var data: MeshData
	var skin: Skin
	## A box round the posed mesh (world), for skipping rays that cannot hit it.
	var bounds: AABB
	## Face of `triangles` -> triangle of the mesh.
	var face_triangle: PackedInt32Array
	## The camera the soup was made for (groups wholly outside its view are left out).
	var camera_key: int = 0
	## The triangles, 3 vertices each in the winding of the mesh. TriangleMesh.intersect_ray()
	## reports a normal that always faces the ray, so front and back faces are told from these.
	var faces: PackedVector3Array

static var _data: Dictionary[int, MeshData] = {}
static var _soups: Dictionary[int, Soup] = {}


## Forget every cached mesh and triangle mesh.
static func clear_cache() -> void:
	_data.clear()
	_soups.clear()


## The pose the render server draws for `rig` now: one Transform3D per skeleton bone, rig
## space. The ragdoll's visual pose (Ragdoll.visual_pose(): what the followers show and an art
## rig's skeleton is written back to) while one runs on the rig (HumanoidRig.is_ragdolling()),
## otherwise the animation's FK pose (HumanoidRig.animation_pose()).
static func drawn_pose(rig: HumanoidRig) -> Array[Transform3D]:
	var ragdoll := rig.get_ragdoll() if rig.is_ragdolling() else null
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(ragdoll.visual_pose(i) if ragdoll != null else rig.animation_pose(i))
	return out


## The animation's FK pose of `rig`, whatever a ragdoll shows: the pose the hurtboxes follow, and
## the one to pass as `globals` to see what the animation alone would draw.
static func fk_pose(rig: HumanoidRig) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(rig.animation_pose(i))
	return out


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


## The skinned positions of only the vertices `indices` of `mi` (rig space), one per index in the same order: the same skin
## matrices and the same weights as skin_vertices(), so each point is the one skin_vertices() gives, but only the requested
## vertices are transformed (a suite that follows a few hundred sole vertices through thousands of poses does not skin the
## whole mesh each time: tests/fixtures/motion/motion_probe.gd).
static func skin_subset(mi: MeshInstance3D, rig: HumanoidRig, indices: PackedInt32Array, globals: Array[Transform3D] = []) -> PackedVector3Array:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	var matrices := _skin_matrices(mi.skin, rig, globals)
	var out := PackedVector3Array()
	out.resize(indices.size())
	for k: int in indices.size():
		var v := indices[k]
		var at := data.vertices[v]
		var point := Vector3.ZERO
		for e: int in range(data.entry_start[v], data.entry_start[v + 1]):
			point += (matrices[data.entry_bind[e]] * at) * data.entry_weight[e]
		out[k] = point
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
## FPView.NEAR, or a back face, does not. Each rig's art is skinned in the pose the render
## server draws (drawn_pose(): the ragdoll's while one runs), and each mesh's TriangleMesh is
## made once per physics frame and pose.
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
		soups.append(_soup(mesh, rig, cam))
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
				if soups[i].bounds.intersects_ray(cam.origin, dir) == null:
					continue
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
		if (b - a).cross(c - a).length_squared() < 1e-14:
			continue
		best = minf(best, point.distance_to(_closest_on_triangle(point, a, b, c)))
	return best


## How the art fills the hurtboxes at the rig's current pose (row A6): for each of
## PlaceholderBody.hurt_specs(), the axis points (the sphere's centre; five along a capsule's
## axis) that lie outside the art, and the share of the vertices on the region's bones that lie
## within the hurtbox's radius plus `slack_m` of its axis (the head: `head_slack_m`): the
## torso's are the Hips to UpperChest bones', the legs' the UpperLeg and LowerLeg's (the shoes
## run past the hurtbox's foot end), the head's the Head's. Vertices on one bind only count.
## Returns `{outside: Array[String], torso, legs, head: shares}`. A point is inside when a ray
## from it along an axis leaves through a back face first (the first surface it meets seen from
## inside; a point outside a closed mesh never has one).
static func hurtbox_fit(rig: HumanoidRig, slack_m: float = 0.06, head_slack_m: float = 0.05) -> Dictionary:
	var soups: Array[Soup] = []
	var meshes: Array[MeshInstance3D] = []
	# The hurtboxes follow the animation's FK pose, so the art they are fitted to is skinned in it
	# too, whatever a ragdoll on the rig is showing.
	var fk := fk_pose(rig)
	for mi: MeshInstance3D in rig.art_meshes():
		soups.append(_soup(mi, rig, null, fk))
		meshes.append(mi)
	var world := rig.global_transform
	var outside: Array[String] = []
	var share := {torso = [0, 0], legs = [0, 0], head = [0, 0]}
	var regions := {
		&"Hips": &"torso", &"Spine": &"torso", &"Chest": &"torso", &"UpperChest": &"torso",
		&"LeftUpperLeg": &"legs", &"LeftLowerLeg": &"legs", &"RightUpperLeg": &"legs", &"RightLowerLeg": &"legs",
		&"Head": &"head",
	}
	for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
		var from := world * (rig.animation_pose(rig.skeleton.find_bone(spec.bone_a)) * (spec.offset_a * rig.rig_scale()))
		var to := from
		if spec.is_capsule():
			to = world * (rig.animation_pose(rig.skeleton.find_bone(spec.bone_b)) * (spec.offset_b * rig.rig_scale()))
		for i: int in 5 if spec.is_capsule() else 1:
			var point := from.lerp(to, i / 4.0)
			var inside := false
			for soup: Soup in soups:
				inside = inside or _inside(soup, point)
			if not inside:
				outside.append("%s axis point %d" % [spec.name, i])
		# The vertices of the bones this hurtbox covers, against its axis.
		for mi: MeshInstance3D in meshes:
			var posed := mi.global_transform * skin_vertices(mi, rig, fk)
			var data := _mesh_data(mi.mesh as ArrayMesh)
			for v: int in posed.size():
				if data.rigid_bind[v] < 0:
					continue
				var bone := StringName(mi.skin.get_bind_name(data.rigid_bind[v]))
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
		outside = outside,
		torso = float(share.torso[0]) / maxi(share.torso[1], 1),
		legs = float(share.legs[0]) / maxi(share.legs[1], 1),
		head = float(share.head[0]) / maxi(share.head[1], 1),
	}


## True when `point` lies inside the posed mesh of `soup`: an axis ray from it meets a back face
## first, which is only so from inside a closed shell (overlapping shells block some rays: one
## is enough).
static func _inside(soup: Soup, point: Vector3) -> bool:
	if soup.triangles == null:
		return false
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var hit := soup.triangles.intersect_ray(point, dir)
		if not hit.is_empty() and not _is_front(soup, int(hit.face_index), dir):
			return true
	return false


## Art against its view proxies at camera `cam`: the same grid cast both ways. Returns
## `{cells, differ (cells one covers and the other does not), art_share, proxy_share (the
## shares of the view each covers), nearest (the meters the art is nearer the lens than the
## proxies where both are hit: the second largest gap over the cells, so one cell on a
## silhouette's edge is no bulge; 0 when never), both}`. The proxies are the rig's own
## primitives, found by FPView.hits() (they are hidden while the art shows, but count: A4). The
## art is the drawn pose's (hits()), and the proxies follow the same pose (the bone followers
## show the ragdoll's), so the comparison holds through a stagger or a launch.
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
	soup.faces = faces
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
	var runner_up := 0.0
	var both := 0
	for i: int in art_cells.size():
		var art_hit := not art_cells[i].is_empty()
		var proxy_hit := proxy_covered[i]
		art_count += int(art_hit)
		proxy_count += int(proxy_hit)
		differ += int(art_hit != proxy_hit)
		if art_hit and proxy_hit:
			both += 1
			# The two largest gaps: one cell grazing a silhouette edge is not a bulge.
			var gap := proxy_depths[i] - float(art_cells[i].depth)
			if gap > nearest:
				runner_up = nearest
				nearest = gap
			elif gap > runner_up:
				runner_up = gap
	nearest = runner_up
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
## mixed_triangles, squashed (posed area under `squash_below` of the rest's), flipped (turned
## over: its turn against the skinned vertex normals is right at the skinned rest and folded in
## the pose, see folded_mask()), flipped_healed (the other way round: folded at the rest, right
## in the pose; no defect, so not in `flipped`), rest_folded (folded at the rest: the mesh's own
## baseline, not deformation), lowest_y (of the posed vertices, rig space)}`.
## `with_triangles` false skips the triangle numbers. `rest` is the pose the flips are measured
## against (default rest_pose(rig): the pose every art is bound to).
static func strain(mi: MeshInstance3D, rig: HumanoidRig, globals: Array[Transform3D] = [],
		squash_below: float = 0.15, with_triangles: bool = false, rest: Array[Transform3D] = []) -> Dictionary:
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
		squashed = 0, flipped = 0, flipped_healed = 0, rest_folded = 0,
	}
	if worst_edge >= 0:
		report.worst_bone = _dominant_bone(data, mi.skin, [data.edge_a[worst_edge], data.edge_b[worst_edge]])
	if with_triangles:
		for t: int in data.mixed_triangles.size():
			var tri := data.mixed_triangles[t]
			var a := data.indices[tri * 3]
			var b := data.indices[tri * 3 + 1]
			var c := data.indices[tri * 3 + 2]
			var area := (posed[b] - posed[a]).cross(posed[c] - posed[a]).length() * 0.5
			if area < data.mixed_rest_area[t] * s * s * squash_below:
				report.squashed += 1
		var rest_pose_globals := rest_pose(rig) if rest.is_empty() else rest
		var flips := flip_counts(
				folded_mask(data, skin_vertices(mi, rig, rest_pose_globals), skin_normals(mi, rig, rest_pose_globals)),
				folded_mask(data, posed, skin_normals(mi, rig, globals)))
		report.flipped = flips.turned
		report.flipped_healed = flips.healed
		report.rest_folded = flips.rest_folded
	return report


## The rig's rest pose: PlaceholderBody's table with no rotations and the hips at rest, rig space
## at the rig's scale. Every art is bound to it, so it is the reference of strain()'s flips (A7,
## A19: M4-calls/P1-chain.md C13, measure against the skinned rest).
static func rest_pose(rig: HumanoidRig) -> Array[Transform3D]:
	var empty: Dictionary[StringName, Vector3] = {}
	var table := PlaceholderBody.pose_globals(empty, Vector3.ZERO, rig.rig_scale())
	var out: Array[Transform3D] = []
	for i: int in rig.skeleton.get_bone_count():
		out.append(table[rig.skeleton.get_bone_name(i)])
	return out


## For each blended triangle of `data` (in data.mixed_triangles order), 1 when it is folded at
## the skinned vertices `posed` with skinned vertex `normals`, else 0: its winding's geometric
## normal opposes the mean of its three corners' normals. Godot's front faces wind clockwise, so
## the geometric normal of (a, b, c) points against the cross product of the edges. A triangle
## that is folded in the mesh as authored is folded at the rest too: counting it as a flip in a
## pose would charge the mesh's own baseline to the deformation.
static func folded_mask(data: MeshData, posed: PackedVector3Array, normals: PackedVector3Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(data.mixed_triangles.size())
	for t: int in data.mixed_triangles.size():
		var tri := data.mixed_triangles[t]
		var a := data.indices[tri * 3]
		var b := data.indices[tri * 3 + 1]
		var c := data.indices[tri * 3 + 2]
		var cross := (posed[b] - posed[a]).cross(posed[c] - posed[a])
		out[t] = 1 if -cross.dot(normals[a] + normals[b] + normals[c]) < 0.0 else 0
	return out


## What changed between two folded_mask()s (the skinned rest's and a pose's): `{turned (right at
## the rest, folded in the pose: the flips, the deformation's fault), healed (folded at the rest,
## right in the pose: the mesh's baseline got better, no defect), rest_folded (folded at the rest)}`.
static func flip_counts(rest_mask: PackedByteArray, mask: PackedByteArray) -> Dictionary:
	var turned := 0
	var healed := 0
	var at_rest := 0
	for t: int in mini(rest_mask.size(), mask.size()):
		at_rest += rest_mask[t]
		if mask[t] != rest_mask[t]:
			if mask[t] == 1:
				turned += 1
			else:
				healed += 1
	return {turned = turned, healed = healed, rest_folded = at_rest}


## How many triangles of `mi` are folded (see folded_mask()): `{all, mixed, triangles}`, over every
## triangle and over the blended ones (the only ones a pose can turn over). The mesh as authored
## when `rig` is null (its own vertices and normals); else skinned at `globals` (the drawn pose
## when empty).
static func folded_triangles(mi: MeshInstance3D, rig: HumanoidRig = null, globals: Array[Transform3D] = []) -> Dictionary:
	var data := _mesh_data(mi.mesh as ArrayMesh)
	_prepare_strain(data)
	var posed := data.vertices if rig == null else skin_vertices(mi, rig, globals)
	var normals := data.normals if rig == null else skin_normals(mi, rig, globals)
	var all := 0
	for t: int in data.indices.size() / 3:
		var a := data.indices[t * 3]
		var b := data.indices[t * 3 + 1]
		var c := data.indices[t * 3 + 2]
		if -(posed[b] - posed[a]).cross(posed[c] - posed[a]).dot(normals[a] + normals[b] + normals[c]) < 0.0:
			all += 1
	var mixed := 0
	for flag: int in folded_mask(data, posed, normals):
		mixed += flag
	return {all = all, mixed = mixed, triangles = data.indices.size() / 3}


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


## The point of triangle abc nearest p (Ericson, Real-Time Collision Detection 5.1.5); the
## triangle must not be degenerate.
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


## Skin matrix of every bind of `skin`: the bone's pose times the bind pose, in `globals` or,
## when it is empty, the drawn pose (drawn_pose()).
static func _skin_matrices(skin: Skin, rig: HumanoidRig, globals: Array[Transform3D]) -> Array[Transform3D]:
	var poses := drawn_pose(rig) if globals.is_empty() else globals
	var out: Array[Transform3D] = []
	for k: int in skin.get_bind_count():
		out.append(poses[rig.skeleton.find_bone(skin.get_bind_name(k))] * skin.get_bind_pose(k))
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
		data.entry_start.append(data.entry_vertex.size())
		for j: int in SkinnedArt.INFLUENCES:
			var w := data.weights[v * SkinnedArt.INFLUENCES + j]
			if w <= 0.0:
				continue
			data.entry_vertex.append(v)
			data.entry_bind.append(data.bones[v * SkinnedArt.INFLUENCES + j])
			data.entry_weight.append(w)
			if w >= RIGID_WEIGHT:
				data.rigid_bind[v] = data.bones[v * SkinnedArt.INFLUENCES + j]
	data.entry_start.append(data.entry_vertex.size())
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
			var rest := data.vertices[lo].distance_to(data.vertices[hi])
			rigid_triangle = rigid_triangle and (same or rest < MIN_EDGE_M)
			if seen.has(key):
				continue
			seen[key] = true
			data.edge_count += 1
			if same or rest < MIN_EDGE_M:
				continue
			data.edge_a.append(lo)
			data.edge_b.append(hi)
			data.edge_rest.append(rest)
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
	var tri := soup.face_triangle[face]
	return _dominant_bone(data, soup.skin, [data.indices[tri * 3], data.indices[tri * 3 + 1], data.indices[tri * 3 + 2]])


## A hash of what skins `mi`: the bone transforms of the pose (`globals`, or the drawn pose when
## empty), the rig's place, the skin and the mesh.
static func _pose_key(mi: MeshInstance3D, rig: HumanoidRig, globals: Array[Transform3D] = []) -> int:
	var poses := drawn_pose(rig) if globals.is_empty() else globals
	return hash([poses, rig.global_transform, mi.skin.get_instance_id(), mi.mesh.get_instance_id()])


## The triangle mesh of `mi` at its rig's pose (`globals`, or the drawn pose when empty), made
## once per physics frame and pose.
static func _soup(mi: MeshInstance3D, rig: HumanoidRig, cam: Variant = null, globals: Array[Transform3D] = []) -> Soup:
	var id := mi.get_instance_id()
	var frame := Engine.get_physics_frames()
	var poses := drawn_pose(rig) if globals.is_empty() else globals
	var key := _pose_key(mi, rig, poses)
	var camera_key := hash(cam)
	var soup: Soup = _soups.get(id)
	if soup != null and soup.frame == frame and soup.pose_key == key and soup.camera_key == camera_key:
		return soup
	if soup == null:
		soup = Soup.new()
		_soups[id] = soup
	soup.frame = frame
	soup.pose_key = key
	soup.camera_key = camera_key
	var data := _mesh_data(mi.mesh as ArrayMesh)
	_prepare_soup(data)
	soup.data = data
	soup.skin = mi.skin
	var matrices := _skin_matrices(mi.skin, rig, poses)
	var world := mi.global_transform
	var faces := PackedVector3Array()
	var face_triangle := PackedInt32Array()
	for k: int in data.group_corners.size():
		if data.group_corners[k].is_empty():
			continue
		var group := world * matrices[k]
		if cam != null and _outside_view(group * data.bind_aabb[k], cam as Transform3D):
			continue
		faces.append_array(group * data.group_corners[k])
		face_triangle.append_array(data.group_triangles[k])
	# The mixed triangles: each used vertex skinned once, then looked up per corner.
	if not data.soup_mixed.is_empty():
		var posed := PackedVector3Array()
		posed.resize(data.vertices.size())
		for e: int in range(0, data.mixed_vertex_entry.size(), 3):
			var v := data.mixed_vertex_entry[e]
			posed[v] += (matrices[data.mixed_vertex_entry[e + 1]] * data.vertices[v]) * (data.mixed_vertex_entry[e + 2] / 65536.0)
		posed = world * posed
		var mixed := PackedVector3Array()
		mixed.resize(data.mixed_corner.size())
		for c: int in data.mixed_corner.size():
			mixed[c] = posed[data.mixed_corner[c]]
		faces.append_array(mixed)
		face_triangle.append_array(data.soup_mixed)
	soup.face_triangle = face_triangle
	soup.faces = faces
	# Nothing of it in view: no triangle mesh (create_from_faces() errors on an empty soup).
	soup.triangles = null
	if not faces.is_empty():
		soup.triangles = TriangleMesh.new()
		soup.triangles.create_from_faces(faces)
	# The bounds: every bind's rest box at its matrix, united.
	var bounds := AABB()
	var first := true
	for k: int in data.bind_aabb.size():
		if data.bind_aabb[k].size == Vector3.ZERO and data.bind_aabb[k].position == Vector3.ZERO:
			continue
		var box := (world * matrices[k]) * data.bind_aabb[k]
		bounds = box if first else bounds.merge(box)
		first = false
	soup.bounds = bounds.grow(0.01)
	return soup


## True when the world box `box` lies wholly outside the first-person view of `cam`: behind its
## lens, or past one of its four sides (the box's corners in camera space, all on the outer side
## of the same plane).
static func _outside_view(box: AABB, cam: Transform3D) -> bool:
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var inverse := cam.affine_inverse()
	var behind := true
	var right := true
	var left := true
	var above := true
	var below := true
	for i: int in 8:
		var q := inverse * (box.position + box.size * Vector3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1)))
		var depth := -q.z
		behind = behind and depth < FPView.NEAR
		right = right and q.x > tan_h * depth
		left = left and q.x < -tan_h * depth
		above = above and q.y > tan_v * depth
		below = below and q.y < -tan_v * depth
	return behind or right or left or above or below


## The soup layout of `data` (see MeshData.soup_ready).
static func _prepare_soup(data: MeshData) -> void:
	if data.soup_ready:
		return
	data.soup_ready = true
	var binds := 0
	for b: int in data.bones:
		binds = maxi(binds, b + 1)
	data.group_corners.resize(binds)
	data.group_triangles.resize(binds)
	for t: int in data.indices.size() / 3:
		var a := data.indices[t * 3]
		var b := data.indices[t * 3 + 1]
		var c := data.indices[t * 3 + 2]
		var k := data.rigid_bind[a]
		if k >= 0 and data.rigid_bind[b] == k and data.rigid_bind[c] == k:
			data.group_corners[k].append(data.vertices[a])
			data.group_corners[k].append(data.vertices[b])
			data.group_corners[k].append(data.vertices[c])
			data.group_triangles[k].append(t)
		else:
			data.soup_mixed.append(t)
	for t: int in data.soup_mixed:
		data.mixed_corner.append(data.indices[t * 3])
		data.mixed_corner.append(data.indices[t * 3 + 1])
		data.mixed_corner.append(data.indices[t * 3 + 2])
	# Each vertex of a mixed triangle, once, with its influences (weights as 16.16 fixed point
	# so the three fields share one integer array).
	var used := PackedByteArray()
	used.resize(data.vertices.size())
	for t: int in data.soup_mixed:
		for corner: int in 3:
			used[data.indices[t * 3 + corner]] = 1
	for e: int in data.entry_vertex.size():
		if used[data.entry_vertex[e]] == 1:
			data.mixed_vertex_entry.append(data.entry_vertex[e])
			data.mixed_vertex_entry.append(data.entry_bind[e])
			data.mixed_vertex_entry.append(roundi(data.entry_weight[e] * 65536.0))
	# The boxes of the binds' vertices at rest.
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	var seen: Array[bool] = []
	low.resize(binds)
	high.resize(binds)
	seen.resize(binds)
	seen.fill(false)
	for e: int in data.entry_vertex.size():
		var k := data.entry_bind[e]
		var v := data.vertices[data.entry_vertex[e]]
		if not seen[k]:
			seen[k] = true
			low[k] = v
			high[k] = v
		else:
			low[k] = Vector3(minf(low[k].x, v.x), minf(low[k].y, v.y), minf(low[k].z, v.z))
			high[k] = Vector3(maxf(high[k].x, v.x), maxf(high[k].y, v.y), maxf(high[k].z, v.z))
	for k: int in binds:
		data.bind_aabb.append(AABB(low[k], high[k] - low[k]) if seen[k] else AABB())


## True when face `face` of `soup` faces a ray travelling along `dir` (Godot's front faces wind
## clockwise: Plane(a, b, c) then points at the viewer).
static func _is_front(soup: Soup, face: int, dir: Vector3) -> bool:
	var normal := Plane(soup.faces[face * 3], soup.faces[face * 3 + 1], soup.faces[face * 3 + 2]).normal
	return normal.dot(dir) < 0.0


## The nearest front-face hit of the ray from `origin` along unit `dir`: `{depth, face}` or {}.
static func _ray(soup: Soup, origin: Vector3, dir: Vector3, forward: Vector3) -> Dictionary:
	if soup.triangles == null:
		return {}
	var from := origin
	for step: int in MAX_BACK_FACES:
		var hit := soup.triangles.intersect_ray(from, dir)
		if hit.is_empty():
			return {}
		var position: Vector3 = hit.position
		if not _is_front(soup, int(hit.face_index), dir):
			from = position + dir * BACK_FACE_STEP
			continue
		var depth := (position - origin).dot(forward)
		if depth < FPView.NEAR:
			from = position + dir * BACK_FACE_STEP
			continue
		return {depth = depth, face = int(hit.face_index)}
	return {}
