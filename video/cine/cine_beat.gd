class_name CineBeat
extends Resource
## One timed action of a cine shot's script: a button press, a held button, a stick push, a turn of the view or a
## slow-motion span. The cine bot runs them on the shot clock (a physics tick count since the staging ended).

enum Kind {
	## Press `button` (held `hold_ticks`), as a tap.
	PRESS,
	## Hold `button` down until an UP beat.
	DOWN,
	UP,
	## Push the stick: `stick` (x right, y forward) until the next MOVE beat.
	MOVE,
	## Turn the view `degrees` (positive left) evenly over `seconds`.
	TURN,
	## Tilt the view to `degrees` pitch (negative looks down) evenly over `seconds`.
	PITCH,
	## Slow the game's time to `time_scale` for `seconds` (the game's own slow-motion).
	SLOWMO,
}

## When it happens, in seconds on the shot clock.
@export_range(0.0, 120.0) var at_s: float = 0.0
@export var kind: Kind = Kind.PRESS
## PRESS, DOWN and UP: the input button (&"P" punch, &"K" kick, &"DODGE" block, &"GRAB", &"JUMP", &"RB" back attack).
@export var button: StringName = &"P"
@export_range(1, 30) var hold_ticks: int = 2
@export var stick: Vector2 = Vector2.ZERO
@export_range(-360.0, 360.0) var degrees: float = 0.0
@export_range(0.0, 20.0) var seconds: float = 0.0
@export_range(0.05, 1.0) var time_scale: float = 0.3
