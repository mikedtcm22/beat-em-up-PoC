class_name HitboxSpec
extends Resource
## One striking volume of a move, live only during the move's active frames.

enum Kind {
	POINT_SPHERE,  ## Sphere centered on a rig strike point (bone or marker), plus `offset`.
	ARC,           ## Horizontal arc around the attacker (spin kicks, back elbow, wide sweeps).
}

@export var kind: Kind = Kind.POINT_SPHERE

@export_group("Point sphere")
## Rig point name: a humanoid bone or a strike marker such as &"RightFistPoint".
## See docs/ARCHITECTURE.md "Rig points".
@export var point: StringName = &"RightFistPoint"
## Offset in the point's local space (meters).
@export var offset: Vector3 = Vector3.ZERO
@export_range(0.02, 1.0, 0.01) var radius: float = 0.12

@export_group("Arc")
## Reach from the attacker's origin, measured horizontally (meters).
@export_range(0.2, 4.0, 0.05) var arc_radius: float = 1.6
## Half-angle of the arc in degrees; 180 = full circle.
@export_range(1.0, 180.0, 1.0) var arc_half_angle_deg: float = 60.0
## Arc center direction, degrees of yaw from the attacker's forward; 180 = directly behind.
@export_range(-180.0, 180.0, 1.0) var arc_center_yaw_deg: float = 0.0
## Vertical band above the attacker's origin that the arc covers (min, max) in meters.
@export var arc_height: Vector2 = Vector2(0.0, 1.9)
