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

## The blocks (or pieces) whose faces win a shared plane against this block's, as paths from this node. A path across sections
## (it climbs out of this block's section) that is not in the tree (a section built alone, one built later) is skipped; any other
## that does not resolve is a renamed or deleted node, which brings the z-fight back, and warns.
@export var yields_to: Array[NodePath] = []:
	set(value):
		yields_to = value
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
	for rect in _clips().get(MeshClip.key(axis, side), []):
		out.append(Rect2(rect.position + Vector2(offset[u], offset[v]), rect.size))
	return out


## The drawn box: the kit's module with the overlaps taken out of it. A flat box (the editor, the graybox switch) is not clipped.
func _make_mesh(material: Material) -> MeshInstance3D:
	var art := _art()
	var mesh := RoomKit.box_mesh(size, material, _overlay(art), art)
	if not RoomKit.kit_art(art) or not (mesh.mesh is ArrayMesh):
		return mesh
	for path: NodePath in unresolved_yields():
		push_warning("InsetBlock '%s': yields_to '%s' is not a node, so the faces it shares with that block fight again" % [get_path(), path])
	var clips := _clips()
	if clips.is_empty():
		return mesh
	mesh.mesh = MeshClip.clip_box(mesh.mesh, size, clips, Tuning.data.kit_clip_standoff_m, Tuning.data.kit_coplanar_m)
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
	for path: NodePath in yields_to:
		var partner := get_node_or_null(path) as Node3D
		if partner == null:
			continue
		_ensure_built(partner)
		var found := MeshClip.overlaps(mine, _box_of(partner, inverse), Tuning.data.kit_coplanar_m)
		for face_key: String in found:
			var rects: Array[Rect2] = [found[face_key]]
			var piece := partner as MeshInstance3D
			if piece != null and piece.mesh != null:
				rects = _covered_by(piece, inverse, face_key, found[face_key], mine)
			if not out.has(face_key):
				out[face_key] = [] as Array[Rect2]
			(out[face_key] as Array[Rect2]).append_array(rects)
	return out


## The `yields_to` paths that do not resolve and do not cross sections: a renamed or deleted partner (tests/test_m6_feedback_ground.gd
## lists them for the whole level).
func unresolved_yields() -> Array[NodePath]:
	var out: Array[NodePath] = []
	if not is_inside_tree():
		return out
	for path: NodePath in yields_to:
		if get_node_or_null(path) == null and not _crosses_sections(path):
			out.append(path)
	return out


## Whether `path` climbs out of this block's section (more ".." than the steps up to the `LevelSection`), so that a section built
## alone cannot resolve it.
func _crosses_sections(path: NodePath) -> bool:
	var climbs := 0
	for i in path.get_name_count():
		if path.get_name(i) != &"..":
			break
		climbs += 1
	var depth := 0
	var up: Node = self
	while up.get_parent() != null and not up is LevelSection:
		up = up.get_parent()
		depth += 1
	return climbs > depth


## A kit piece builds its mesh on demand, so the cut does not depend on whether its `_ready` has run yet.
func _ensure_built(partner: Node) -> void:
	var piece := partner as KitPiece
	if piece != null:
		piece.ensure_mesh()


## The parts of `overlap` (this block's `face_key` plane) that a kit piece's own faces cover: a piece is not a box (a cornice is
## three boards, each standing out further than the one below), so its bounds' face is only partly there, and a block that gave
## the whole rectangle up would leave a hole where the piece has none.
func _covered_by(piece: MeshInstance3D, inverse: Transform3D, face_key: String, overlap: Rect2, mine: AABB) -> Array[Rect2]:
	var axis := int(face_key.substr(0, 1))
	var side := int(face_key.substr(2, 1))
	var plane: float = mine.end[axis] if side == 1 else mine.position[axis]
	var out: Array[Rect2] = []
	for face in MeshClip.face_rects(piece.mesh, inverse * piece.global_transform, axis, side, plane, Tuning.data.kit_coplanar_m):
		if face.intersects(overlap):
			out.append(face.intersection(overlap))
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

