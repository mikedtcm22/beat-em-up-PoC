@tool
class_name LevelStairs
extends Node3D
## A flight of stairs (Milestone 5, D7: the reference's ladders are stairs in the graybox): a row of
## solid steps climbing toward local -Z from the node's origin, which is the middle of the foot's
## front edge on the lower floor. `rise_m` is the whole climb, `run_m` the whole depth, `width_m` the
## width across X; the step count is the smallest that keeps every step at or under
## `max_step_rise_m`, so the navmesh agent's climb (0.2 m) and the player's capsule take them. Each
## step is a box from the floor up, so nothing is hollow. The nav bake keeps the polygons inside
## `footprint()` (NavBaker). Every number is an export.

@export_range(0.5, 12.0, 0.05) var rise_m: float = 4.5:
	set(value):
		rise_m = value
		_rebuild()
@export_range(0.5, 20.0, 0.05) var run_m: float = 7.5:
	set(value):
		run_m = value
		_rebuild()
@export_range(0.5, 8.0, 0.05) var width_m: float = 3.0:
	set(value):
		width_m = value
		_rebuild()
## No step is higher than this (m); the nav agent's climb is 0.2.
@export_range(0.05, 0.2, 0.01) var max_step_rise_m: float = 0.18:
	set(value):
		max_step_rise_m = value
		_rebuild()
## The look of the steps (a LevelBlock look).
@export var look: StringName = &"accent":
	set(value):
		look = value
		_rebuild()

var _steps: Node3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(&"level_stairs")
	_rebuild()


## How many steps the flight has.
func step_count() -> int:
	return maxi(ceili(rise_m / max_step_rise_m - 0.0001), 1)


## The height of one step (m).
func step_rise_m() -> float:
	return rise_m / float(step_count())


## The flight's footprint in world space, as the nav bake wants it: x and z of the steps, y from the
## foot to the top (a little above, so the polygons on the treads count).
func footprint() -> AABB:
	var local := AABB(Vector3(-width_m * 0.5, 0.0, -run_m), Vector3(width_m, rise_m + step_rise_m(), run_m))
	return global_transform * local


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _steps != null:
		_steps.queue_free()
	_steps = Node3D.new()
	_steps.name = "Steps"
	add_child(_steps)
	var count := step_count()
	var rise := rise_m / float(count)
	var depth := run_m / float(count)
	for i in count:
		var block := LevelBlock.new()
		block.name = "Step%d" % (i + 1)
		var top := rise * float(i + 1)
		block.size = Vector3(width_m, top, depth)
		block.look = look
		block.position = Vector3(0.0, top * 0.5, -depth * (float(i) + 0.5))
		_steps.add_child(block)
