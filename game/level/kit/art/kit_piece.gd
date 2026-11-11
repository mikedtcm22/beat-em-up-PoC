class_name KitPiece
extends MeshInstance3D
## One piece of a section's dressing (Milestone 6, KIT; D11): a `KitMesh` kind at a size, on the shared
## trim material. Place it with a transform (the centre of the box it fills; a kind with a front
## looks along +Z) under a `Dressing`: a doorway's frame, a row of windows, a cornice, a fence, over
## blocks whose boxes are hidden (`draw_box = false`) or beside them. A piece has no collider, ever:
## what stops the player is the block it dresses. Tuning's `kit_draw_graybox` hides it.

@export var kind: StringName = &"slab":
	set(value):
		kind = value
		_rebuild()
@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value
		_rebuild()


func _ready() -> void:
	ensure_mesh()


## Builds the mesh if it is not built yet. A block that yields to this piece (InsetBlock) asks for the mesh in its own `_ready`,
## which runs before the piece's when the piece comes later in the scene, so the cut does not depend on the siblings' order.
func ensure_mesh() -> void:
	if mesh == null:
		_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var show_it := RoomKit.kit_art(kind)
	mesh = KitMesh.build(kind, size) if show_it else null
	visible = show_it
	if show_it and not KitMesh.KINDS.has(kind):
		push_warning("KitPiece '%s': no kit kind '%s'" % [name, kind])
