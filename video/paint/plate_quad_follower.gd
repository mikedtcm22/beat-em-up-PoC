class_name PlateQuadFollower
extends Node
## Keeps a plate quad down the active camera's view every frame (the sort), after the cameras moved. A child of the quad.

var quad: PlateScreenQuad


func _init() -> void:
	name = "PlateQuadFollower"
	process_priority = 90


func _process(_delta: float) -> void:
	if quad != null:
		quad.update(get_viewport().get_camera_3d())
