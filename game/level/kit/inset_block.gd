@tool
class_name InsetBlock
extends LevelBlock
## A block that does not draw a face where another block draws the same plane (Milestone 6 playtest feedback, FIX-WORLD; reworked
## in the verification round, VFIX-WORLD). The collider stays the box, so the walls, the navmesh and tests/test_m6_colliders.gd do
## not move; what changes is the drawn mesh.
##
## Why: two boxes that abut or overlap (a wall and the lintel over a door, two walls at a corner) often end in the same plane, and
## two faces in one plane fight for every pixel of it: the winner swings with the camera's millimetres, which is the flashing
## Game-boy saw. The first answer pulled the whole face back 2 to 4 cm, which hid the fight but left a step wherever the partner
## covered only part of that face, and the edge pass inks a step. This block takes the overlap out of its own face instead
## (MeshClip): over the rectangle it shares with a block in `yields_to` there is only the partner's face, in the same plane, so
## there is no fight and no step to ink; outside it the face is as it was.
##
## `yields_to` names the blocks (or kit pieces) that win a plane against this one, as paths from this node. Which of two blocks
## yields is decided once, in the scenes (tools/solve_insets.gd writes it: a piece wins over a block, the bigger face over the
## smaller); a block never yields to one that yields to it. tests/m6_coplanar_scan.gd holds the whole level to no two drawn faces
## in one plane, to no hole where a face was taken out, and to no step.

## The blocks (or pieces) whose faces win a shared plane against this block's, as paths from this node. One that is not in the
## tree (a section built alone, a path across sections to one built later) is skipped.
@export var yields_to: Array[NodePath] = []:
	set(value):
		yields_to = value
		_rebuild()
## Two faces closer than this (metres) are in one plane.
@export_range(0.0, 0.05, 0.001) var coplanar_m: float = 0.004:
	set(value):
		coplanar_m = value
		_rebuild()
## How far out of the box's face (metres) the kit's own standoffs are taken out with it (a wall's plinth board stands off its
## face by 5 cm: it is the same face for this purpose).
@export_range(0.0, 0.5, 0.005) var standoff_m: float = 0.06:
	set(value):
		standoff_m = value
		_rebuild()


## The rectangles of this block's `side` face of `axis` (1 the + face, 0 the - face) that it does not draw, in the plane's
## (u, v) = ((axis + 1) % 3, (axis + 2) % 3) coordinates, world space.
func clipped_rects(axis: int, side: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	var offset := global_position
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	for rect in _clips().get(_key(axis, side), []):
		out.append(Rect2(rect.position + Vector2(offset[u], offset[v]), rect.size))
	return out


## The drawn box: the kit's module with the overlaps taken out of it. A flat box (the editor, the graybox switch) is not clipped.
func _make_mesh(material: Material) -> MeshInstance3D:
	var art := _art()
	var mesh := RoomKit.box_mesh(size, material, _overlay(art), art)
	if not RoomKit.kit_art(art) or not (mesh.mesh is ArrayMesh):
		return mesh
	var clips := _clips()
	if clips.is_empty():
		return mesh
	var drawn := mesh.mesh as ArrayMesh
	for key: String in clips:
		var axis := int(key.substr(0, 1))
		var side := int(key.substr(2, 1))
		var plane := size[axis] * 0.5 * (1.0 if side == 1 else -1.0)
		drawn = MeshClip.clip(drawn, axis, side, plane, standoff_m, coplanar_m, clips[key])
	mesh.mesh = drawn
	return mesh


## {"axis|side": Array[Rect2] (local (u, v) coordinates)}: the overlaps with each block this one yields to, on every face that
## lies in the same plane as the partner's face looking the same way.
func _clips() -> Dictionary:
	var out := {}
	if not is_inside_tree():
		return out
	var here := global_transform
	var inverse := here.affine_inverse()
	var mine := AABB(-size * 0.5, size)
	for path in yields_to:
		var partner := get_node_or_null(path) as Node3D
		if partner == null:
			continue
		var other := _box_of(partner, inverse)
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
				if absf(mine_plane - other_plane) > coplanar_m:
					continue
				var key := _key(axis, side)
				if not out.has(key):
					out[key] = [] as Array[Rect2]
				(out[key] as Array[Rect2]).append(overlap)
	return out


## The box a partner draws, in this block's space: a block's own box, a piece's mesh bounds.
func _box_of(partner: Node3D, inverse: Transform3D) -> AABB:
	var block := partner as LevelBlock
	if block != null:
		return inverse * block.global_transform * AABB(-block.size * 0.5, block.size)
	var piece := partner as MeshInstance3D
	if piece != null and piece.mesh != null:
		return inverse * piece.global_transform * piece.mesh.get_aabb()
	return AABB()


static func _key(axis: int, side: int) -> String:
	return "%d|%d" % [axis, side]
