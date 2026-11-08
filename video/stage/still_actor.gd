class_name VideoStillActor
extends Resource
## One actor of a VideoStillShot: an enemy of the catalog, placed and held in a pose.

enum Facing {
	## Faces `yaw_deg`.
	YAW,
	## Faces the viewer: the player's eyes in a first-person still, the camera in a free one.
	VIEWER,
}

## The enemy catalog id (&"punk", &"kicker", &"boss"...).
@export var id: StringName = &"punk"
## Where he stands (section space, the feet).
@export var position: Vector3 = Vector3.ZERO
@export var facing: Facing = Facing.VIEWER
## The facing when `facing` is YAW (degrees; 0 looks along -Z).
@export_range(-180.0, 180.0) var yaw_deg: float = 0.0
## The rig animation he plays (&"idle" is his guard) and the physics tick it is held at.
@export var anim: StringName = &"idle"
@export_range(0, 600) var hold_tick: int = 0
