class_name CineBeat
extends Resource
## One step of a cine shot's script: a button press, a held button, a stick push, a turn of the view, a slow-motion span, an
## actor's turn or a forced attack. The cine bot runs the beats of a shot in array order on the shot clock (a physics tick count
## since the staging ended): each waits for its time (`at_s`, absolute or counted from the step before) and then for its
## `trigger` (a game state, so a shot's action does not depend on a hand-timed number), and fires once. The beats of a shot
## are data; the bot logs every firing with its tick and output frame.

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
	## Slow the game's time to `time_scale` for `seconds` (TimeController's slow-motion, the only writer of time).
	SLOWMO,
	## Turn actor `actor` (an index into the shot's actors) to face the player over `seconds`.
	ACTOR_FACE,
	## Force actor `actor`'s attack number `attack_index` (the AI is frozen: it winds up now).
	ATTACK,
	## Play rig animation `label` on actor `actor` (a held actor, off the game's tick: the bot advances its rig).
	ACTOR_ANIM,
	## Note a mark in the log (a cue for the edit: the name card, the cut to black), with `label`.
	MARK,
}

## What a beat waits for after its time.
enum Trigger {
	## Nothing: it fires at its time.
	CLOCK,
	## Actor `actor` is `lead_ticks` ticks from the strike of its move (a block pressed now is a perfect block).
	ACTOR_STRIKE,
	## Actor `actor` is staggered or in hitstun (a grab or a finisher can take it).
	ACTOR_STAGGERED,
	## Actor `actor` is down or out.
	ACTOR_DOWN,
	## Actor `actor` is on its feet and not in a move.
	ACTOR_FREE,
	## The player is holding an enemy.
	PLAYER_HOLDING,
	## The player is on its feet, in no move and with nothing queued.
	PLAYER_FREE,
	## The player is in the air and at the top of the jump (the spin kick's moment).
	PLAYER_JUMP_PEAK,
	## The player is in the air.
	PLAYER_AIRBORNE,
}

## When it happens, in seconds: on the shot clock, or with `relative` after the step before fired.
@export_range(0.0, 120.0) var at_s: float = 0.0
@export var relative: bool = false
@export var kind: Kind = Kind.PRESS
## What it waits for after its time, for how long at most (a beat whose trigger never comes fires anyway, and the log says so).
@export var trigger: Trigger = Trigger.CLOCK
@export_range(0.0, 20.0) var timeout_s: float = 3.0
## The actor the trigger and ACTOR_FACE and ATTACK read (an index into the shot's actors).
@export_range(0, 16) var actor: int = 0
## ACTOR_STRIKE: ticks before the strike (a perfect block's window is 14 ticks).
@export_range(0, 60) var lead_ticks: int = 8
## PRESS, DOWN and UP: the input button (&"P" punch, &"K" kick, &"DODGE" block, &"GRAB", &"JUMP", &"RB" back attack).
@export var button: StringName = &"P"
@export_range(1, 30) var hold_ticks: int = 2
@export var stick: Vector2 = Vector2.ZERO
@export_range(-360.0, 360.0) var degrees: float = 0.0
@export_range(0.0, 20.0) var seconds: float = 0.0
@export_range(0.05, 1.0) var time_scale: float = 0.3
## ATTACK: the attack index.
@export_range(0, 8) var attack_index: int = 0
## MARK: the label.
@export var label: StringName = &""
