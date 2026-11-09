class_name CineProp
extends Resource
## A weapon lying on the floor at the start of a cine shot (the player picks it up with a grab). Video staging only: the game places
## its weapons from its own pickups.

## The weapon catalog id (&"pipe", &"bike_chain").
@export var id: StringName = &"pipe"
## Where it lies (section space) and its yaw (degrees; the weapon lies on its side).
@export var position: Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0) var yaw_deg: float = 0.0
