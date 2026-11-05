@tool
class_name InsetBlock
extends LevelBlock
## A block whose drawn mesh is a little smaller than its box (Milestone 6 playtest feedback, FIX-WORLD). The collider stays the
## box, so the walls, the navmesh and tests/test_m6_colliders.gd do not move; what is drawn is the box with each face pulled in by
## `inset_min` (the - faces) and `inset_max` (the + faces), in metres, per axis.
##
## Why: two boxes that abut or overlap (a wall and the lintel over a door, two walls at a corner) often end in the same plane,
## and two faces in one plane fight for every pixel of it: the winner swings with the camera's millimetres, which is the flashing
## Game-boy saw. Pulling one of the two faces in by a couple of centimetres lets the other win everywhere, with a step too small
## to see. Which block gives way, and by how much (a step of INSET_STEP_M per tier, so three faces in one plane stay apart too),
## is found by tests/m6_coplanar_scan.gd, which holds the whole level to no two drawn faces in one plane.

## The tier of one pulled-in face: the difference between two faces that would share a plane (metres).
const INSET_STEP_M := 0.02

## How far each - face of the drawn box (x, y, z) is pulled in, metres.
@export var inset_min: Vector3 = Vector3.ZERO:
	set(value):
		inset_min = value
		_rebuild()
## How far each + face of the drawn box (x, y, z) is pulled in, metres.
@export var inset_max: Vector3 = Vector3.ZERO:
	set(value):
		inset_max = value
		_rebuild()


## The drawn box: smaller than `size` by the insets, and moved so each face lands where it was pulled to.
func _make_mesh(material: Material) -> MeshInstance3D:
	var art := _art()
	var drawn := (size - inset_min - inset_max).max(Vector3.ONE * 0.001)
	var mesh := RoomKit.box_mesh(drawn, material, _overlay(art), art)
	mesh.position = (inset_min - inset_max) * 0.5
	return mesh
