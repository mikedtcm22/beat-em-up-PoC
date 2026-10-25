class_name ViewGeometry
extends RefCounted
## Where a point is, seen from the player's look (Milestone 3, M3-plan A2.1): the one helper
## the enemy director's blind spot, the rear warning and the bots' warning oracle all call, so
## they cannot disagree. Static, pure and simulation-safe: it takes the look's yaw (the
## player's look_yaw, never a camera, so a spin, the KO view or a camera mode cannot flip a
## corner), and measures flat (XZ) from the player's origin.
##
## Bearings are signed degrees: 0 dead ahead, positive to the left, +-180 directly behind.
## The look faces -Z at yaw 0 and turns left (counter-clockwise from above) as the yaw rises,
## the way PlayerCharacter's look_yaw does.


## The flat unit vector the look faces (yaw only): (-sin(yaw), 0, -cos(yaw)).
static func forward(look_yaw: float) -> Vector3:
	return Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))


## Signed flat angle in degrees from the look to `point`, seen from `from`: 0 ahead, positive
## left, +-180 behind. A point straight above or below `from` (no flat offset) is 0.
static func bearing_deg(look_yaw: float, from: Vector3, point: Vector3) -> float:
	var flat := Vector2(point.x - from.x, point.z - from.z)
	if flat.length_squared() < 1e-10:
		return 0.0
	var ahead := Vector2(-sin(look_yaw), -cos(look_yaw))
	var left := Vector2(-cos(look_yaw), sin(look_yaw))
	return rad_to_deg(atan2(flat.dot(left), flat.dot(ahead)))


## True when `point` is more than `half_angle_deg` (flat) off the look.
static func is_outside_view(look_yaw: float, from: Vector3, point: Vector3, half_angle_deg: float) -> bool:
	return absf(bearing_deg(look_yaw, from, point)) > half_angle_deg


## The rear warning's rule (SPEC §8, M3-plan Part B §B1) for an attack winding up at flat
## `bearing` degrees and `distance_m` from the player (see bearing_deg()): which top corner
## lights. &"" (none), &"left" (the attacker is behind-left, bearing positive), &"right" or
## &"both" (within behind_deg of directly behind).
## It fires when the attacker is more than `angle_deg` off the look and within
## `reach_m` + `margin_m` (inclusive). The side is decided here and kept by the caller.
static func warning_corner(bearing: float, distance_m: float, reach_m: float, angle_deg: float,
		behind_deg: float, margin_m: float) -> StringName:
	if absf(bearing) <= angle_deg:
		return &""
	if distance_m > reach_m + margin_m:
		return &""
	if absf(bearing) >= 180.0 - behind_deg:
		return &"both"
	return &"left" if bearing > 0.0 else &"right"
