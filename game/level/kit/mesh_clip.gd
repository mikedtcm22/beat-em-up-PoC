class_name MeshClip
extends RefCounted
## Takes a rectangle out of a mesh's faces on one axis-aligned plane (Milestone 6 playtest verification, VFIX-WORLD).
##
## `clip(mesh, axis, side, plane, depth, rects)` returns a copy of `mesh` (same surfaces and materials) in which every triangle that
## lies on the plane `plane` of `axis` (or up to `depth` out from it: a plinth board stands off a wall) and looks outward from it (`side` 1: the
## + direction, 0: the - direction) has the `rects` cut out of it, in the plane's (u, v) = ((axis + 1) % 3, (axis + 2) % 3) coordinates, mesh space.
## A triangle the rectangle cuts is re-triangulated, its UV, normal and colour interpolated, so the strip's picture continues unbroken
## on what is left. Nothing else changes: the faces of other directions and planes are copied as they are.
##
## It exists because two boxes that share a plane over an overlap fight for every pixel of it, and the only answer that leaves no
## step for the edge pass to ink is for one of them not to draw its face there (InsetBlock).

## A piece of a cut triangle smaller than this (square metres) is a rounding sliver and is dropped.
const MIN_AREA_M2 := 0.0000001

## One corner of a polygon being cut: every attribute the kit's meshes carry.
class Vertex:
	var position: Vector3
	var normal: Vector3
	var uv: Vector2
	var color: Color

	func lerped(to: Vertex, t: float) -> Vertex:
		var out := Vertex.new()
		out.position = position.lerp(to.position, t)
		out.normal = normal.lerp(to.normal, t)
		out.uv = uv.lerp(to.uv, t)
		out.color = color.lerp(to.color, t)
		return out


## The key of a face in the dictionaries below: its axis and side.
static func key(axis: int, side: int) -> String:
	return "%d|%d" % [axis, side]


## The overlaps of box `mine` with box `other` (one space, axis-aligned) on every face of `mine` that lies in one plane with
## `other`'s face looking the same way (within `coplanar` metres): {key(axis, side): Rect2 in the plane's (u, v) coordinates}.
static func overlaps(mine: AABB, other: AABB, coplanar: float) -> Dictionary:
	var out := {}
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var overlap := Rect2(
				maxf(mine.position[u], other.position[u]), maxf(mine.position[v], other.position[v]),
				minf(mine.end[u], other.end[u]) - maxf(mine.position[u], other.position[u]),
				minf(mine.end[v], other.end[v]) - maxf(mine.position[v], other.position[v]))
		if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
			continue
		for side in 2:
			var mine_plane: float = mine.end[axis] if side == 1 else mine.position[axis]
			var other_plane: float = other.end[axis] if side == 1 else other.position[axis]
			if absf(mine_plane - other_plane) <= coplanar:
				out[key(axis, side)] = overlap
	return out


## The rectangles of `mesh`'s faces that lie on the plane `plane` of `axis` and look outward from it (`side` 1: +, 0: -), in the plane's
## (u, v) coordinates of the space `to_space` takes the mesh into, deduplicated (a quad is two triangles with one bounding
## rectangle). The kit's faces are axis-aligned quads, so a triangle's bounds are its quad's.
static func face_rects(mesh: Mesh, to_space: Transform3D, axis: int, side: int, plane: float, tolerance: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var sign_out := 1.0 if side == 1 else -1.0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var normal := (to_space.basis * normals[indices[t]]).normalized()
			if normal[axis] * sign_out < 0.99:
				continue
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			var on_plane := true
			for k in 3:
				var corner := to_space * verts[indices[t + k]]
				if absf(corner[axis] - plane) > tolerance:
					on_plane = false
					break
				low = Vector2(minf(low.x, corner[u]), minf(low.y, corner[v]))
				high = Vector2(maxf(high.x, corner[u]), maxf(high.y, corner[v]))
			if not on_plane:
				continue
			var rect := Rect2(low, high - low)
			var known := false
			for other in out:
				if other.position.is_equal_approx(rect.position) and other.size.is_equal_approx(rect.size):
					known = true
					break
			if not known:
				out.append(rect)
	return out


## `mesh` (a box centred on its origin of size `size`) with every rectangle in `clips` ({key: Array[Rect2]}, the plane's (u, v)
## coordinates in the mesh's space) taken out of its face; a mesh that is not an ArrayMesh is converted first.
static func clip_box(mesh: Mesh, size: Vector3, clips: Dictionary, standoff: float, coplanar: float) -> ArrayMesh:
	var drawn := as_array_mesh(mesh)
	for face_key: String in clips:
		var axis := int(face_key.substr(0, 1))
		var side := int(face_key.substr(2, 1))
		var plane := size[axis] * 0.5 * (1.0 if side == 1 else -1.0)
		drawn = clip(drawn, axis, side, plane, standoff, coplanar, clips[face_key])
	return drawn


## `mesh` as an ArrayMesh: a primitive mesh (the plain box) is built into one, with its material on the surface.
static func as_array_mesh(mesh: Mesh) -> ArrayMesh:
	var array_mesh := mesh as ArrayMesh
	if array_mesh != null:
		return array_mesh
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface))
		out.surface_set_material(surface, mesh.surface_get_material(surface))
	return out


## `mesh` with `rects` removed from its faces on the plane (see the class comment).
static func clip(mesh: ArrayMesh, axis: int, side: int, plane: float, depth: float, tolerance: float, rects: Array[Rect2]) -> ArrayMesh:
	var out := ArrayMesh.new()
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var sign_out := 1.0 if side == 1 else -1.0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept_verts := PackedVector3Array()
		var kept_normals := PackedVector3Array()
		var kept_uvs := PackedVector2Array()
		var kept_colors := PackedColorArray()
		var has_colors := not colors.is_empty()
		var kept_indices := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			var corners: Array[Vertex] = []
			for k in 3:
				var vertex := Vertex.new()
				var i := indices[t + k]
				vertex.position = verts[i]
				vertex.normal = normals[i]
				vertex.uv = uvs[i] if i < uvs.size() else Vector2.ZERO
				vertex.color = colors[i] if i < colors.size() else Color.WHITE
				corners.append(vertex)
			var polygons: Array = [corners]
			if _on_plane(corners, axis, sign_out, plane, depth, tolerance):
				for rect in rects:
					var next: Array = []
					for polygon: Array[Vertex] in polygons:
						next.append_array(_outside(polygon, u, v, rect))
					polygons = next
			for polygon: Array[Vertex] in polygons:
				if polygon.size() < 3 or _area(polygon) < MIN_AREA_M2:
					continue
				var base := kept_verts.size()
				for vertex in polygon:
					kept_verts.append(vertex.position)
					kept_normals.append(vertex.normal)
					kept_uvs.append(vertex.uv)
					if has_colors:
						kept_colors.append(vertex.color)
				for k in range(1, polygon.size() - 1):
					kept_indices.append_array(PackedInt32Array([base, base + k, base + k + 1]))
		if kept_verts.is_empty():
			continue
		var clipped: Array = []
		clipped.resize(Mesh.ARRAY_MAX)
		clipped[Mesh.ARRAY_VERTEX] = kept_verts
		clipped[Mesh.ARRAY_NORMAL] = kept_normals
		clipped[Mesh.ARRAY_TEX_UV] = kept_uvs
		if has_colors:
			clipped[Mesh.ARRAY_COLOR] = kept_colors
		clipped[Mesh.ARRAY_INDEX] = kept_indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clipped)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(surface))
	return out


## Whether a triangle looks outward from the plane and lies on it, or up to `depth` out from it.
static func _on_plane(corners: Array[Vertex], axis: int, sign_out: float, plane: float, depth: float, tolerance: float) -> bool:
	if corners[0].normal[axis] * sign_out < 0.99:
		return false
	for corner in corners:
		var out := (corner.position[axis] - plane) * sign_out
		if out < -tolerance or out > depth:
			return false
	return true


## The parts of the convex `polygon` that lie outside `rect` (in the (u, v) components), as convex polygons.
static func _outside(polygon: Array[Vertex], u: int, v: int, rect: Rect2) -> Array:
	var pieces: Array = []
	var rest := polygon
	var left := _half(rest, u, rect.position.x, true)
	if left.size() >= 3:
		pieces.append(left)
	rest = _half(rest, u, rect.position.x, false)
	var right := _half(rest, u, rect.end.x, false)
	if right.size() >= 3:
		pieces.append(right)
	rest = _half(rest, u, rect.end.x, true)
	var below := _half(rest, v, rect.position.y, true)
	if below.size() >= 3:
		pieces.append(below)
	rest = _half(rest, v, rect.position.y, false)
	var above := _half(rest, v, rect.end.y, false)
	if above.size() >= 3:
		pieces.append(above)
	return pieces


## The part of the convex `polygon` with component `axis` at most (`below`) or at least (not `below`) `limit`.
static func _half(polygon: Array[Vertex], axis: int, limit: float, below: bool) -> Array[Vertex]:
	var out: Array[Vertex] = []
	var count := polygon.size()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		var da := (limit - a.position[axis]) if below else (a.position[axis] - limit)
		var db := (limit - b.position[axis]) if below else (b.position[axis] - limit)
		if da >= 0.0:
			out.append(a)
		if (da > 0.0 and db < 0.0) or (da < 0.0 and db > 0.0):
			out.append(a.lerped(b, da / (da - db)))
	return out


## The polygon's area (a fan of triangles from its first corner).
static func _area(polygon: Array[Vertex]) -> float:
	var twice := Vector3.ZERO
	for i in range(1, polygon.size() - 1):
		twice += (polygon[i].position - polygon[0].position).cross(polygon[i + 1].position - polygon[0].position)
	return twice.length() * 0.5
