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
##
## Second and third rules (verification round, verify-world-01): a block that does not draw its face where another does (an
## InsetBlock's `yields_to`) must leave no hole, and no two faces of one direction may lie a few centimetres apart where one is
## only partly in front of the other. `holes()` finds a taken-out rectangle that no other box draws in the same plane (a see-through
## wall); `steps()` finds the 0.5 to 5 cm step (the first answer to the z-fight, pulling a whole face back 2 cm, left one wherever
## the partner covered only part of it: the edge pass inked it, full height or in dashes that crawl at distance).
##
## What a box is: a `LevelBlock`'s is the box it draws (its size; an InsetBlock reports what it leaves out, `clipped_rects`), not its mesh's bounds (the kit's plinth boards
## stand 5 cm off a wall and would make every tall wall look 5 cm bigger); anything else is its mesh's bounds, so a Dressing piece
## (a KitPiece on a cornice, a window row) is a box too.

## Two faces closer than this (metres) lie in one plane.
const COPLANAR_M := 0.004
## A shared area under this (square metres) is a sliver of a corner, not a z-fight.
const MIN_AREA_M2 := 0.02
## Two faces of one direction whose planes differ by STEP_MIN_M to STEP_MAX_M (metres) make a step where one stops (below it the
## faces are one plane for the eye and the depth buffer alike, above it the step is a feature of the design).
const STEP_MIN_M := 0.005
const STEP_MAX_M := 0.05
## How far off the face (metres) the "is anything in front of it" and "is there floor below" probes are taken.
const PROBE_OFF_M := 0.01
const SUPPORT_OFF_M := 0.4
const SUPPORT_DROP_M := 40.0


## One entry per drawn box of `root`: {node: MeshInstance3D, box: AABB, owner: Node (the block, the body or the piece that owns it)}.
static func drawn_boxes(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for found: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var owner_node := _box_owner(mesh, root)
		if owner_node == null or not _axis_aligned(mesh.global_transform.basis):
			continue
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		if owner_node is LevelBlock:
			var block := owner_node as LevelBlock
			box = block.global_transform * AABB(-block.size * 0.5, block.size)
		elif owner_node is StaticBody3D:
			box = _body_box(owner_node as StaticBody3D, box)
		out.append({node = mesh, box = box, owner = owner_node})
	return out


## The block or the world body whose box `mesh` draws, or null (an actor's or a prop's mesh).
static func _box_owner(mesh: MeshInstance3D, root: Node) -> Node:
	if mesh is KitPiece:
		return mesh
	var up := mesh.get_parent()
	while up != null and up != root.get_parent():
		if up is LevelBlock:
			return up
		if up is CharacterBody3D or up is Skeleton3D:
			return null
		if up is StaticBody3D and (up as StaticBody3D).collision_layer & CombatTypes.bit(CombatTypes.LAYER_WORLD) != 0:
			return up.get_parent() if up.get_parent() is LevelBlock else up
		up = up.get_parent()
	if mesh.mesh is BoxMesh and mesh.get_parent() == root:
		return mesh
	if mesh.mesh is BoxMesh or mesh.mesh is ArrayMesh:
		var parent := mesh.get_parent()
		if parent != null and parent.name == &"Geometry":
			return mesh
	return null


## The box a world body draws: its collider's box where the mesh is that box with the kit's standoffs (a plinth board) on it, else the mesh's
## own bounds.
static func _body_box(body: StaticBody3D, mesh_box: AABB) -> AABB:
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D:
			var size := (shape.shape as BoxShape3D).size
			if mesh_box.size.x - size.x < 0.11 and mesh_box.size.y - size.y < 0.11 and mesh_box.size.z - size.z < 0.11 \
					and mesh_box.size.x >= size.x - 0.001 and mesh_box.size.y >= size.y - 0.001 and mesh_box.size.z >= size.z - 0.001:
				return shape.global_transform * AABB(-size * 0.5, size)
	return mesh_box


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
	var start: Array[Rect2] = [Rect2(
			maxf(a.position[u], b.position[u]), maxf(a.position[v], b.position[v]),
			minf(a.end[u], b.end[u]) - maxf(a.position[u], b.position[u]),
			minf(a.end[v], b.end[v]) - maxf(a.position[v], b.position[v]))]
	for k in [i, j]:
		for clip in clips_of(items[k], axis, side):
			start = _subtract(start, clip)
	return _area(visible_rects(items, [i, j], axis, side, plane, start, space))


## The rectangles of `item`'s `side` face of `axis` that it does not draw (an InsetBlock's yielded overlaps).
static func clips_of(item: Dictionary, axis: int, side: int) -> Array[Rect2]:
	var block := item.owner as InsetBlock
	if block != null:
		return block.clipped_rects(axis, side)
	var out: Array[Rect2] = []
	if item.owner.has_meta(RoomKit.CLIPPED_META):
		out.assign((item.owner.get_meta(RoomKit.CLIPPED_META) as Dictionary).get(MeshClip.key(axis, side), []))
	return out


static func _area(rects: Array[Rect2]) -> float:
	var area := 0.0
	for rect in rects:
		area += rect.get_area()
	return area


## `start` (rectangles in the plane's (u, v) coordinates) less what a box other than `skip` covers just outside the plane and
## what has no world collider below a point 0.4 m off the face: the part of the face a player can see.
static func visible_rects(items: Array[Dictionary], skip: Array, axis: int, side: int, plane: float, start: Array[Rect2], space: PhysicsDirectSpaceState3D) -> Array[Rect2]:
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var sign_out := 1.0 if side == 1 else -1.0
	var front := plane + sign_out * PROBE_OFF_M
	var rects: Array[Rect2] = start
	for k in items.size():
		if skip.has(k):
			continue
		var c: AABB = items[k].box
		if c.position[axis] < front and c.end[axis] > front:
			rects = _subtract(rects, Rect2(c.position[u], c.position[v], c.size[u], c.size[v]))
			if rects.is_empty():
				return rects
	var out: Array[Rect2] = []
	for rect in rects:
		if space == null or _has_floor(space, rect.get_center(), axis, u, v, plane + sign_out * SUPPORT_OFF_M):
			out.append(rect)
	return out


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



## Whether a box stands in front of what it meets by design: a rail's post stands inside its curb, and a barrier's panel (a shutter,
## a gate) hangs in front of its opening. Neither is a wall face that was meant to be flush.
static func _stands_by_design(item: Dictionary) -> bool:
	var block := item.owner as LevelBlock
	if block != null and block.look == &"fence":
		return true
	var up: Node = item.owner
	while up != null:
		if up is Barrier:
			return true
		up = up.get_parent()
	return false


## Every rectangle an InsetBlock takes out of its face that no other box draws in that plane: {item, axis, side, plane, area, text}.
## `min_area` is the smallest hole in view that counts (square metres).
static func holes(root: Node, min_area: float = MIN_AREA_M2) -> Array[Dictionary]:
	var items := drawn_boxes(root)
	var space := (root as Node3D).get_world_3d().direct_space_state if root is Node3D else null
	var out: Array[Dictionary] = []
	for i in items.size():
		var box: AABB = items[i].box
		for axis in 3:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for side in 2:
				var clips := clips_of(items[i], axis, side)
				if clips.is_empty():
					continue
				var plane: float = box.end[axis] if side == 1 else box.position[axis]
				var open: Array[Rect2] = clips
				for j in items.size():
					if j == i or items[j].owner == items[i].owner:
						continue
					var other: AABB = items[j].box
					var other_plane: float = other.end[axis] if side == 1 else other.position[axis]
					if absf(other_plane - plane) > COPLANAR_M:
						continue
					var drawn: Array[Rect2] = [Rect2(other.position[u], other.position[v], other.size[u], other.size[v])]
					for clip in clips_of(items[j], axis, side):
						drawn = _subtract(drawn, clip)
					for rect in drawn:
						open = _subtract(open, rect)
				var seen := _area(visible_rects(items, [i], axis, side, plane, open, space))
				if seen >= min_area:
					out.append({
						item = items[i], axis = axis, side = side, plane = plane, area = seen,
						text = "%s: %s face at %.3f has a %.2f m2 hole in view (taken out, and no other box draws it)" % [_name(items[i]), "xyz"[axis] + ("+" if side == 1 else "-"), plane, seen],
					})
	return out


## Every pair of faces of one direction a few centimetres apart (STEP_MIN_M to STEP_MAX_M) of two boxes that overlap (two solids
## that run into each other, so the step is not a feature standing on a surface: paint, a post on a curb) where the nearer covers part of the
## farther and leaves part of it in view: a step along the nearer's edge, which the edge pass inks. {a: the nearer, b: the farther
## (entries of drawn_boxes), axis, side, covered: float, exposed: float, text}. Both areas must be at least `min_area` (square
## metres): a step over a sliver is not a line.
static func steps(root: Node, min_area: float = MIN_AREA_M2) -> Array[Dictionary]:
	var items := drawn_boxes(root)
	var space := (root as Node3D).get_world_3d().direct_space_state if root is Node3D else null
	var out: Array[Dictionary] = []
	for i in items.size():
		for j in range(i + 1, items.size()):
			if items[i].owner == items[j].owner or _stands_by_design(items[i]) or _stands_by_design(items[j]):
				continue
			var a: AABB = items[i].box
			var b: AABB = items[j].box
			if not a.intersects(b):
				continue
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
					var gap := absf(plane_a - plane_b)
					if gap < STEP_MIN_M or gap > STEP_MAX_M:
						continue
					var a_nearer := (plane_a > plane_b) == (side == 1)
					var near: int = i if a_nearer else j
					var far: int = j if a_nearer else i
					var near_box: AABB = items[near].box
					var far_box: AABB = items[far].box
					var covered_rect := Rect2(
							maxf(a.position[u], b.position[u]), maxf(a.position[v], b.position[v]), overlap_u, overlap_v)
					var near_drawn: Array[Rect2] = [Rect2(near_box.position[u], near_box.position[v], near_box.size[u], near_box.size[v])]
					for clip in clips_of(items[near], axis, side):
						near_drawn = _subtract(near_drawn, clip)
					var covered_area := 0.0
					for rect in near_drawn:
						if rect.intersects(covered_rect):
							covered_area += rect.intersection(covered_rect).get_area()
					if covered_area < min_area:
						continue
					var open: Array[Rect2] = [Rect2(far_box.position[u], far_box.position[v], far_box.size[u], far_box.size[v])]
					for clip in clips_of(items[far], axis, side):
						open = _subtract(open, clip)
					for rect in near_drawn:
						open = _subtract(open, rect)
					var far_plane: float = plane_b if a_nearer else plane_a
					var exposed := _area(visible_rects(items, [far, near], axis, side, far_plane, open, space))
					if exposed >= min_area:
						out.append({
							a = items[near], b = items[far], axis = axis, side = side, covered = covered_area, exposed = exposed,
							text = "%s stands %.0f mm in front of %s (%s faces): %.2f m2 of it covers, %.2f m2 of the farther is left in view" % [_name(items[near]), gap * 1000.0, _name(items[far]), "xyz"[axis] + ("+" if side == 1 else "-"), covered_area, exposed],
						})
	return out
