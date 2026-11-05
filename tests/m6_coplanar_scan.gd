extends RefCounted
## Milestone 6 playtest feedback, FIX-WORLD: the scan for two drawn faces that share a plane (a z-fight).
##
## Two box faces that look the same way, lie in one plane (within COPLANAR_M) and overlap in an area fight for every pixel of it:
## which one wins swings with the camera's millimetres, and that is the flashing Game-boy saw on the street and again on the
## boss roof. The scan takes every box the level, the crowd street or the training room draws (a `LevelBlock`'s mesh, or the mesh
## of a world-layer body a room builds), as an axis-aligned box in world space, and compares each pair on the six planes.
##
## What counts, so the scan reports what a player can see and nothing that is buried:
##  - a face that looks down is never seen (the eye is above every floor), so it is not compared;
##  - the overlap loses every part of it that a third drawn box covers just outside the plane (a wall face behind a bigger wall);
##  - the overlap loses every part that has no world collider below a point 0.4 m off the face (the far side of a building,
##    which looks into nothing the player or the camera is ever in);
##  - what is left must be at least MIN_AREA_M2;
##  - two faces that draw the same picture cannot fight (the rooms' flat colours and the floor grid are lit by position, not by
##    the box), so a pair on one flat colour or on the grid is not reported. The kit's trim material is the opposite: each box
##    lays its own strip's UVs from its own corner, so two trim faces in one plane always differ.
## A box that is rotated is skipped (the street's one ramp); every other drawn box is axis-aligned.

## Two faces closer than this (metres) lie in one plane.
const COPLANAR_M := 0.004
## A shared area under this (square metres) is a sliver of a corner, not a z-fight.
const MIN_AREA_M2 := 0.02
## How far off the face (metres) the "is anything in front of it" and "is there floor below" probes are taken.
const PROBE_OFF_M := 0.01
const SUPPORT_OFF_M := 0.4
const SUPPORT_DROP_M := 40.0


## One entry per drawn box of `root`: {node: MeshInstance3D, box: AABB, owner: Node (the block or the body that owns it)}.
static func drawn_boxes(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for found: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var owner_node := _box_owner(mesh, root)
		if owner_node == null or not _axis_aligned(mesh.global_transform.basis):
			continue
		out.append({node = mesh, box = mesh.global_transform * mesh.mesh.get_aabb(), owner = owner_node})
	return out


## The block or the world body whose box `mesh` draws, or null (an actor's or a prop's mesh).
static func _box_owner(mesh: MeshInstance3D, root: Node) -> Node:
	var up := mesh.get_parent()
	while up != null and up != root.get_parent():
		if up is LevelBlock:
			return up
		if up is CharacterBody3D or up is Skeleton3D:
			return null
		if up is StaticBody3D and (up as StaticBody3D).collision_layer & CombatTypes.bit(CombatTypes.LAYER_WORLD) != 0:
			return up
		up = up.get_parent()
	if mesh.mesh is BoxMesh and mesh.get_parent() == root:
		return mesh
	if mesh.mesh is BoxMesh or mesh.mesh is ArrayMesh:
		var parent := mesh.get_parent()
		if parent != null and parent.name == &"Geometry":
			return mesh
	return null


static func _axis_aligned(basis: Basis) -> bool:
	for column in 3:
		var vector := basis[column]
		var non_zero := 0
		for axis in 3:
			if absf(vector[axis]) > 0.001:
				non_zero += 1
		if non_zero != 1:
			return false
	return true


## Every pair of drawn faces of `root` that share a plane over an area a player can see:
## {a: Dictionary, b: Dictionary (entries of drawn_boxes), axis: int, side: int (1 the + face, 0 the - face), plane: float,
## area: float, text: String}. `min_area` is the smallest shared area in view that counts (square metres).
static func pairs(root: Node, min_area: float = MIN_AREA_M2) -> Array[Dictionary]:
	var items := drawn_boxes(root)
	var space := (root as Node3D).get_world_3d().direct_space_state if root is Node3D else null
	var out: Array[Dictionary] = []
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: AABB = items[i].box
			var b: AABB = items[j].box
			for axis in 3:
				var u := (axis + 1) % 3
				var v := (axis + 2) % 3
				var overlap_u := minf(a.end[u], b.end[u]) - maxf(a.position[u], b.position[u])
				var overlap_v := minf(a.end[v], b.end[v]) - maxf(a.position[v], b.position[v])
				if overlap_u <= 0.0 or overlap_v <= 0.0:
					continue
				for side in 2:
					if axis == 1 and side == 0:
						continue
					var plane_a: float = a.end[axis] if side == 1 else a.position[axis]
					var plane_b: float = b.end[axis] if side == 1 else b.position[axis]
					if absf(plane_a - plane_b) > COPLANAR_M:
						continue
					if _same_picture(items[i].node, items[j].node):
						continue
					var area := _visible_area(items, i, j, axis, side, plane_a, a, b, space)
					if area >= min_area:
						out.append({
							a = items[i], b = items[j], axis = axis, side = side, plane = plane_a, area = area,
							text = "%s and %s: %s face at %.3f, %.2f m2 in view" % [_name(items[i]), _name(items[j]), "xyz"[axis] + ("+" if side == 1 else "-"), plane_a, area],
						})
	return out


## Whether two meshes' (first) surfaces draw one picture wherever they lie: the same shader, not the kit's trim, and the same flat colour.
static func _same_picture(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	var material_a := a.get_active_material(0) as ShaderMaterial
	var material_b := b.get_active_material(0) as ShaderMaterial
	if material_a == null or material_b == null or material_a.shader != material_b.shader:
		return false
	if material_a == ToonMaterials.trim() or material_a == ToonMaterials.trim_scissor():
		return false
	return material_a.get_shader_parameter(&"albedo") == material_b.get_shader_parameter(&"albedo")


static func _name(item: Dictionary) -> String:
	var owner_node: Node = item.owner
	var parts: PackedStringArray = []
	var up := owner_node
	while up != null and parts.size() < 3:
		parts.append(String(up.name))
		up = up.get_parent()
	parts.reverse()
	return "/".join(parts)


## The area of the faces' shared rectangle that a third box does not cover and that has floor below it.
static func _visible_area(items: Array[Dictionary], i: int, j: int, axis: int, side: int, plane: float, a: AABB, b: AABB, space: PhysicsDirectSpaceState3D) -> float:
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var sign_out := 1.0 if side == 1 else -1.0
	var front := plane + sign_out * PROBE_OFF_M
	var rects: Array[Rect2] = [Rect2(
			maxf(a.position[u], b.position[u]), maxf(a.position[v], b.position[v]),
			minf(a.end[u], b.end[u]) - maxf(a.position[u], b.position[u]),
			minf(a.end[v], b.end[v]) - maxf(a.position[v], b.position[v]))]
	for k in items.size():
		if k == i or k == j:
			continue
		var c: AABB = items[k].box
		if c.position[axis] < front and c.end[axis] > front:
			rects = _subtract(rects, Rect2(c.position[u], c.position[v], c.size[u], c.size[v]))
			if rects.is_empty():
				return 0.0
	var area := 0.0
	for rect in rects:
		if space == null or _has_floor(space, rect.get_center(), axis, u, v, plane + sign_out * SUPPORT_OFF_M):
			area += rect.get_area()
	return area


## Whether a world collider lies below the point `(u, v)` of the plane's rectangle, taken `off` out from the plane.
static func _has_floor(space: PhysicsDirectSpaceState3D, centre: Vector2, axis: int, u: int, v: int, out_plane: float) -> bool:
	var from := Vector3.ZERO
	from[axis] = out_plane
	from[u] = centre.x
	from[v] = centre.y
	from.y = maxf(from.y, 0.0) if axis != 1 else from.y
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * SUPPORT_DROP_M, CombatTypes.bit(CombatTypes.LAYER_WORLD))
	return not space.intersect_ray(query).is_empty()


## `rects` with `cut` taken out of every one.
static func _subtract(rects: Array[Rect2], cut: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in rects:
		if not rect.intersects(cut):
			out.append(rect)
			continue
		var hit := rect.intersection(cut)
		if hit.position.y > rect.position.y:
			out.append(Rect2(rect.position, Vector2(rect.size.x, hit.position.y - rect.position.y)))
		if hit.end.y < rect.end.y:
			out.append(Rect2(Vector2(rect.position.x, hit.end.y), Vector2(rect.size.x, rect.end.y - hit.end.y)))
		if hit.position.x > rect.position.x:
			out.append(Rect2(Vector2(rect.position.x, hit.position.y), Vector2(hit.position.x - rect.position.x, hit.size.y)))
		if hit.end.x < rect.end.x:
			out.append(Rect2(Vector2(hit.end.x, hit.position.y), Vector2(rect.end.x - hit.end.x, hit.size.y)))
	return out
