@tool
class_name LevelStairs
extends Node3D
## A flight of stairs (Milestone 5, D7: the reference's ladders are stairs in the graybox): a row of
## solid steps climbing toward local -Z from the node's origin, which is the middle of the foot's
## front edge on the lower floor. `rise_m` is the whole climb, `run_m` the whole depth, `width_m` the
## width across X; the step count is the smallest that keeps every step at or under
## `max_step_rise_m`, so the navmesh agent's climb (0.2 m) takes them. Each step is a box from the
## floor up, so nothing is hollow, on the world layer: a body lying on the flight (a ghost: downed,
## KO'd) rests on the steps. A capsule cannot ride up a box step, though (the edge of a 0.18 m step is a
## 60 degree wall to a 0.35 m capsule), so a hidden glide ramp, a box laid along the tips of the
## steps and a hair above them, on the guard layer (9: `CombatTypes.LAYER_EDGE_GUARD`, the player's and
## a standing enemy's mask), carries every walking body up and down; the steps are what is drawn. The
## nav bake keeps the polygons inside `footprint()` (NavBaker). Every number is an export.
##
## Art (Milestone 6, KIT; D11): the steps stay collider-only (`draw_box` false) and ONE mesh draws the
## flight, a `KitMesh.build_stairs` of exactly this many steps (named `Flight`), so 25 steps are one
## draw, not 25. Tuning's `kit_draw_graybox` and the editor draw the steps' boxes as in M5.

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

## How far the glide ramp stands above the tips of the steps (m), so a capsule never touches one.
@export_range(0.0, 0.05, 0.005) var glide_lift_m: float = 0.01
## The glide ramp's thickness (m).
@export_range(0.05, 1.0, 0.05) var glide_thickness_m: float = 0.3

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
	var kit := not Engine.is_editor_hint() and RoomKit.kit_art(&"stair_flight")
	for i in count:
		var block := LevelBlock.new()
		block.name = "Step%d" % (i + 1)
		var top := rise * float(i + 1)
		block.size = Vector3(width_m, top, depth)
		block.look = look
		block.draw_box = not kit
		block.position = Vector3(0.0, top * 0.5, -depth * (float(i) + 0.5))
		_steps.add_child(block)
	if kit:
		var flight := MeshInstance3D.new()
		flight.name = "Flight"
		flight.mesh = KitMesh.build_stairs(width_m, rise_m, run_m, count)
		flight.position = Vector3(0.0, rise_m * 0.5, -run_m * 0.5)
		_steps.add_child(flight)
	_steps.add_child(_make_glide(rise, depth, count))


## The ramp along the tips of the steps: from the floor one step's depth before the foot up to the
## last tread's start, its top a hair above the line through the tips.
func _make_glide(rise: float, depth: float, count: int) -> StaticBody3D:
	var from := Vector3(0.0, glide_lift_m, depth)
	var to := Vector3(0.0, rise * float(count) + glide_lift_m, -depth * float(count - 1))
	var along := to - from
	var angle := atan2(along.y, -along.z)
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var body := StaticBody3D.new()
	body.name = "Glide"
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD)
	body.collision_mask = 0
	body.position = (from + to) * 0.5 - normal * glide_thickness_m * 0.5
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width_m, glide_thickness_m, along.length())
	shape.shape = box
	body.add_child(shape)
	return body
