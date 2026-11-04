class_name Dressing
extends Node3D
## A section's non-solid dressing (Milestone 6, KIT; D11): the `KitPiece`s and `PropSpot`s that dress
## blocks whose own boxes are hidden, in one node beside the section's `Geometry` (a sibling that
## `LevelSection` does not read). It is never a solid `LevelBlock` (the solid-block tests walk those):
## nothing under it collides. Tuning's `kit_draw_graybox` hides the whole of it.

const GROUP := &"kit_dressing"


func _ready() -> void:
	add_to_group(GROUP)
	visible = not Tuning.data.kit_draw_graybox


## The pieces under this node, in tree order.
func pieces() -> Array[KitPiece]:
	var out: Array[KitPiece] = []
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var piece := node as KitPiece
		if piece != null:
			out.append(piece)
	return out


## The prop spots under this node, in tree order.
func prop_spots() -> Array[PropSpot]:
	var out: Array[PropSpot] = []
	for node: Node in find_children("*", "Node3D", true, false):
		var spot := node as PropSpot
		if spot != null:
			out.append(spot)
	return out
