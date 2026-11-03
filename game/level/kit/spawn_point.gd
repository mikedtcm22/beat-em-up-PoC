class_name SpawnPoint
extends Marker3D
## Where an arena's enemies walk in from (Milestone 5): a doorway, an alley, a vehicle or a
## stairwell landing. The marker stands on the floor, inside its arena between its barriers, and
## faces the lane point; its child `LanePoint` (a Marker3D) is where the enemy walks first. The node's
## name is what an arena table's `wave_points` calls it.

## `&"doorway"`, `&"alley"`, `&"vehicle"` or `&"stairwell"`; the finite spawner falls back to the
## nearest free point with the same tag.
@export var tag: StringName = &"doorway"

var _lane: Marker3D


## Where it walks first, in world space (its own place when it has no `LanePoint`).
func lane_position() -> Vector3:
	var lane := lane_point()
	return lane.global_position if lane else global_position


## The `LanePoint` child (the first Marker3D child when none is so named), or null.
func lane_point() -> Marker3D:
	if _lane == null or not is_instance_valid(_lane):
		_lane = get_node_or_null("LanePoint") as Marker3D
		if _lane == null:
			for child in get_children():
				if child is Marker3D:
					_lane = child
					break
	return _lane


## The way it faces on arrival: toward the lane point (EncounterSpawner's yaw).
func yaw() -> float:
	var facing := lane_position() - global_position
	if Vector2(facing.x, facing.z).length_squared() < 1e-6:
		return global_rotation.y
	return atan2(-facing.x, -facing.z)


## The EncounterSpawner's point: {position, yaw, tag, lane_point, name}.
func as_point() -> Dictionary:
	return {position = global_position, yaw = yaw(), tag = tag, lane_point = lane_position(), name = name}
