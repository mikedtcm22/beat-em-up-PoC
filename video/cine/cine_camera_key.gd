class_name CineCameraKey
extends Resource
## One key of a CineCamera's path (docs/video/PLAN.md §6, the cine stage). Positions are in the space of the shot's level
## section, like the stills'. The camera passes through the keys' positions and look-at points on a spline, and
## blends the FOV, the focus and the roll between them.

enum Ease {
	## An even speed through the segment that starts at this key.
	LINEAR,
	## A smoothstep: slow out of this key and slow into the next.
	SMOOTH,
}

## The shot clock, in seconds since the staging ended (the first key's time is where the path starts).
@export_range(0.0, 120.0) var time_s: float = 0.0
## The camera's position (section space).
@export var position: Vector3 = Vector3.ZERO
## The point it looks at (section space), or with `target_actor` an offset from that actor's head.
@export var look_at: Vector3 = Vector3(0.0, 0.0, -10.0)
## The index into the shot's actors to follow with the look-at, or -1 for a fixed point.
@export_range(-1, 16) var target_actor: int = -1
## The horizontal field of view in degrees (the game's first-person lens is horizontal too).
@export_range(10.0, 120.0) var fov_deg: float = 60.0
## The focus distance (m) and the half-depth of the sharp band around it. A focus of 0 leaves the depth of field off.
@export_range(0.0, 200.0) var focus_m: float = 0.0
@export_range(0.1, 100.0) var focus_range_m: float = 3.0
## A roll about the view axis, in degrees.
@export_range(-45.0, 45.0) var roll_deg: float = 0.0
## How the segment starting at this key is timed.
@export var ease: Ease = Ease.SMOOTH
