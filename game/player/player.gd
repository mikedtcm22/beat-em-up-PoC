class_name PlayerCharacter
extends CombatActor
## The player. API skeleton: the implementation lands with the actor core. Cameras and
## HUD read only the members below (docs/ARCHITECTURE.md).

## Radians. Yaw 0 faces -Z; positive pitch looks up.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
## Eye height above the player's origin in the idle pose (meters).
var standing_eye_height: float = 1.68


func get_eye_transform() -> Transform3D:
	return Transform3D(Basis(), global_position + Vector3.UP * standing_eye_height)


func get_look_basis() -> Basis:
	return Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0))


## x = extra camera pitch in degrees (negative looks down), y = camera drop in meters.
func get_camera_move_offset() -> Vector2:
	return Vector2.ZERO


func is_walking() -> bool:
	return false


## {origin: Vector3, forward: Vector3, half_angle_deg: float, range: float, target: Node3D}
func get_magnetism_cone() -> Dictionary:
	return {}


func holding_weapon() -> bool:
	return false


func weapon_durability_left() -> int:
	return 0
