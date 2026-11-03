extends RefCounted
## First-person view helpers for the tests (not a test script): what the first-person
## camera at the real lens (EyePoint + FirstPersonCamera.lens_offset()) sees of a rig's
## primitive meshes, found by ray-casting them the way the camera renders them. Shared by
## tests/test_humanoid_rig.gd and tests/test_combat_integration.gd.
##
## A rig with skinned art (Milestone 4) hides its primitives and draws the art, but these
## helpers keep measuring the primitives, the view proxies (HumanoidRig.VIEW_PROXY_GROUP): they
## follow the same skeleton and carry the tuned shapes every first-person test was written
## against. is_drawn() is the one place that says which meshes count; the art itself is
## measured by tests/skinned_view.gd (native triangle rays), which the fidelity tests set
## beside these numbers.

## Horizontal FOV half-angle of the first-person camera and the vertical half-angle that
## gives at 16:9 with Camera3D.KEEP_WIDTH (Spec §5).
const HALF_H_DEG := 45.0
const HALF_V_DEG := 29.36
## First-person camera near plane (meters, Spec §5) and the grid hits() casts by default.
const NEAR := 0.05
const COLS := 48


## Rows of the 16:9 grid hits() casts with `cols` columns.
static func rows(cols: int = COLS) -> int:
	return roundi(cols * 9.0 / 16.0)


## The first-person camera for an eye at `eye` looking along `look` (yaw and pitch): the
## lens sits at eye + FirstPersonCamera.lens_offset(look), exactly as the camera places it.
static func camera(eye: Vector3, look: Basis) -> Transform3D:
	return Transform3D(look, eye + FirstPersonCamera.lens_offset(look))


## True when `mesh` counts as drawn for the helpers below. The skinned art is never one (its
## bind-pose bounding box and its ArrayMesh are no use to them: tests/skinned_view.gd measures
## it). A view proxy (a primitive of a rig with art) counts while its bone follower is visible,
## although it is hidden itself while the art shows, so it follows the whole rig's blink and
## nothing else. Any other mesh counts when it is visible in the tree.
static func is_drawn(mesh: MeshInstance3D) -> bool:
	if mesh.is_in_group(HumanoidRig.ART_GROUP):
		return false
	if mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP):
		var parent := mesh.get_parent() as Node3D
		return parent != null and parent.is_visible_in_tree()
	return mesh.is_visible_in_tree()


static func meshes_under(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child as MeshInstance3D)
	return out


## What `cam` sees of the meshes under `root`, as the first-person camera renders them: for
## each cell of a `cols` x rows(cols) grid over the 16:9 view (row by row from the top),
## the nearest mesh along the ray through the cell's center, or null. Ray-casts the
## primitive meshes (boxes, capsules, flat-ended cylinders, spheres as ellipsoids) on the
## layers the first-person camera draws (not CombatTypes.VIS_FP_HIDDEN) and skips those in
## `skip`; a surface nearer than the near plane, or seen from inside, does not count (back
## faces are culled).
static func hits(root: Node, cam: Transform3D, cols: int = COLS,
		skip: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	var cast := _cast(root, cam, cols, skip)
	var out: Array[MeshInstance3D] = []
	out.assign(cast[0])
	return out


## The depth (along the camera's view axis, meters) of each cell's nearest surface in hits(),
## INF where it sees none. Same grid, same order.
static func depths(root: Node, cam: Transform3D, cols: int = COLS,
		skip: Array[MeshInstance3D] = []) -> PackedFloat32Array:
	return _cast(root, cam, cols, skip)[1]


## [the meshes of hits(), their depths].
static func _cast(root: Node, cam: Transform3D, cols: int, skip: Array[MeshInstance3D]) -> Array:
	var row_count := rows(cols)
	var tan_h := tan(deg_to_rad(HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	# Meshes whose bounding sphere reaches into the view, with that sphere in camera space.
	var meshes: Array[MeshInstance3D] = []
	var spheres: Array[Vector4] = []
	for mesh: MeshInstance3D in meshes_under(root):
		if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN) or skip.has(mesh) or not is_drawn(mesh):
			continue
		var radius := mesh.mesh.get_aabb().size.length() * 0.5
		var c := cam.affine_inverse() * mesh.global_position
		var depth := -c.z
		# Behind the near plane, or wholly outside a side plane of the view.
		if depth + radius < NEAR:
			continue
		if (absf(c.x) - depth * tan_h) / sqrt(1.0 + tan_h * tan_h) > radius:
			continue
		if (absf(c.y) - depth * tan_v) / sqrt(1.0 + tan_v * tan_v) > radius:
			continue
		meshes.append(mesh)
		spheres.append(Vector4(c.x, c.y, c.z, radius))
	var out: Array[MeshInstance3D] = []
	var out_depth := PackedFloat32Array()
	for row: int in row_count:
		for col: int in cols:
			# Camera-space ray with z = -1, so the ray parameter is the depth in front of the lens.
			var ray := Vector3(((col + 0.5) / cols * 2.0 - 1.0) * tan_h, (1.0 - (row + 0.5) / row_count * 2.0) * tan_v, -1.0)
			var best: MeshInstance3D = null
			var best_t := INF
			for i: int in meshes.size():
				var sphere := spheres[i]
				var center := Vector3(sphere.x, sphere.y, sphere.z)
				if ray.cross(center).length_squared() > sphere.w * sphere.w * ray.length_squared():
					continue
				var t := ray_hit(meshes[i], cam.origin, cam.basis * ray)
				if t < best_t:
					best_t = t
					best = meshes[i]
			out.append(best)
			out_depth.append(best_t)
	return [out, out_depth]


## Depth along `dir` (from `origin`, both world space) where the ray enters `mesh`'s front
## surface beyond the near plane, or INF.
static func ray_hit(mesh: MeshInstance3D, origin: Vector3, dir: Vector3) -> float:
	var inv := mesh.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	var t := INF
	if mesh.mesh is BoxMesh:
		var half := (mesh.mesh as BoxMesh).size * 0.5
		var t0 := -INF
		var t1 := INF
		for axis: int in 3:
			if absf(d[axis]) < 1e-9:
				if absf(o[axis]) > half[axis]:
					return INF
				continue
			var a := (-half[axis] - o[axis]) / d[axis]
			var b := (half[axis] - o[axis]) / d[axis]
			t0 = maxf(t0, minf(a, b))
			t1 = minf(t1, maxf(a, b))
		t = t0 if t0 <= t1 else INF
	elif mesh.mesh is CylinderMesh:
		# The round side between the two flat ends: where the ray is inside both the infinite
		# cylinder and the slab between the end planes.
		var radius := (mesh.mesh as CylinderMesh).top_radius
		var half_axis := (mesh.mesh as CylinderMesh).height * 0.5
		var t0 := -INF
		var t1 := INF
		var a := d.x * d.x + d.z * d.z
		var c := o.x * o.x + o.z * o.z - radius * radius
		if a < 1e-12:
			if c > 0.0:
				return INF
		else:
			var b := o.x * d.x + o.z * d.z
			var disc := b * b - a * c
			if disc < 0.0:
				return INF
			t0 = (-b - sqrt(disc)) / a
			t1 = (-b + sqrt(disc)) / a
		if absf(d.y) < 1e-12:
			if absf(o.y) > half_axis:
				return INF
		else:
			var ya := (-half_axis - o.y) / d.y
			var yb := (half_axis - o.y) / d.y
			t0 = maxf(t0, minf(ya, yb))
			t1 = minf(t1, maxf(ya, yb))
		t = t0 if t0 <= t1 else INF
	elif mesh.mesh is CapsuleMesh:
		var radius := (mesh.mesh as CapsuleMesh).radius
		var half_axis := maxf((mesh.mesh as CapsuleMesh).height * 0.5 - radius, 0.0)
		var closest := Geometry3D.get_closest_points_between_segments(o, o + d * 100.0,
				Vector3(0.0, -half_axis, 0.0), Vector3(0.0, half_axis, 0.0))
		var gap := closest[0].distance_squared_to(closest[1])
		if gap <= radius * radius:
			t = (closest[0] - o).dot(d) / d.length_squared() - sqrt(radius * radius - gap) / d.length()
	elif mesh.mesh is SphereMesh:
		var sphere := mesh.mesh as SphereMesh
		var squash := sphere.radius / maxf(sphere.height * 0.5, 1e-4)
		o.y *= squash
		d.y *= squash
		var a := d.length_squared()
		var b := 2.0 * o.dot(d)
		var disc := b * b - 4.0 * a * (o.length_squared() - sphere.radius * sphere.radius)
		if disc >= 0.0:
			t = (-b - sqrt(disc)) / (2.0 * a)
	return t if t >= NEAR else INF


## Share of the view (0..1) whose nearest mesh (from hits()) passes `keep`.
static func share(cells: Array[MeshInstance3D], keep: Callable) -> float:
	var n := 0
	for mesh: MeshInstance3D in cells:
		if mesh and keep.call(mesh):
			n += 1
	return float(n) / cells.size()


## Share of the view any mesh covers.
static func covered(cells: Array[MeshInstance3D]) -> float:
	return share(cells, func(_m: MeshInstance3D) -> bool: return true)


## Distance from world `point` to the surface of `mesh`'s primitive (0 inside it); spheres
## are treated as balls of their radius. INF for a mesh that is no primitive.
static func mesh_distance(mesh: MeshInstance3D, point: Vector3) -> float:
	var local := mesh.global_transform.affine_inverse() * point
	if mesh.mesh is BoxMesh:
		var q := local.abs() - (mesh.mesh as BoxMesh).size * 0.5
		return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
	var radius: float
	var half_axis := 0.0
	if mesh.mesh is CapsuleMesh:
		radius = (mesh.mesh as CapsuleMesh).radius
		half_axis = maxf((mesh.mesh as CapsuleMesh).height * 0.5 - radius, 0.0)
	elif mesh.mesh is CylinderMesh:
		radius = (mesh.mesh as CylinderMesh).top_radius
		half_axis = (mesh.mesh as CylinderMesh).height * 0.5
	elif mesh.mesh is SphereMesh:
		radius = (mesh.mesh as SphereMesh).radius
	else:
		# A skinned or imported mesh is no primitive: it is never near anything here.
		return INF
	var axis_point := Geometry3D.get_closest_point_to_segment(local, Vector3(0.0, -half_axis, 0.0), Vector3(0.0, half_axis, 0.0))
	return maxf(axis_point.distance_to(local) - radius, 0.0)


## Nearest distance from `point` to any drawn primitive under `root` (see hits() and
## is_drawn() for which meshes count), or INF.
static func nearest_mesh(root: Node, point: Vector3, keep: Callable = Callable()) -> float:
	var nearest := INF
	for mesh: MeshInstance3D in meshes_under(root):
		if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN) or not is_drawn(mesh):
			continue
		if keep.is_valid() and not keep.call(mesh):
			continue
		nearest = minf(nearest, mesh_distance(mesh, point))
	return nearest


## The meshes under `root` (any render layer, drawn ones only: is_drawn()) with a corner of their
## bounding box behind the lens or outside the 16:9 view of `cam` shrunk to `margin` (1 =
## the view's edge): empty when all of `root` is in frame. The boxes overestimate a rotated
## capsule or sphere a little, so a body that passes is whole in frame.
static func outside_view(root: Node, cam: Transform3D, margin: float = 1.0) -> Array[MeshInstance3D]:
	var tan_h := tan(deg_to_rad(HALF_H_DEG)) * margin
	var tan_v := tan_h * 9.0 / 16.0
	var inverse := cam.affine_inverse()
	var out: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in meshes_under(root):
		if not is_drawn(mesh):
			continue
		var box := mesh.mesh.get_aabb()
		for i: int in 8:
			var corner := box.position + box.size * Vector3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
			var q := inverse * (mesh.global_transform * corner)
			if q.z >= -NEAR or absf(q.x / -q.z) > tan_h or absf(q.y / -q.z) > tan_v:
				out.append(mesh)
				break
	return out
