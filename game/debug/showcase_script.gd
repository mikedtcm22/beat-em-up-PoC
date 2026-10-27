class_name ShowcaseScript
extends RefCounted
## The long take of Milestone 4 (P3-early): one Street Punk, scripted, in the order the final
## judgement looks at it: idle, a turntable, backs off and walks in, taunt, jab and cross, takes a
## jab, stagger, knockdown, get-up, a face-down fall and get-up, KO. It is data and nothing else: two
## things play it, in one place so they show the same Punk,
## - the look act "Look: Punk at 1 m, the long take" (tests/bot/acts/look_acts.gd), 40 s in first
##   person for the DM, and
## - the F4 cheat "Showcase Punk at 1 m" (CheatMenu), a frozen Punk 1 m ahead looping the take so
##   Game-boy can walk round it in the game,
## both through ShowcaseRunner, which plays each step on the Punk's rig by hand (HumanoidRig.play,
## play_locomotion and play_move: AI-driven motion at 1 m sits in RECOVER, and Freeze AI alone shows
## only an idle). Nothing here names the Street Punk's art or its look: the Punk that stands in the
## game is the one shown, so when F-punk's real Punk replaces the smoke one in place the take plays
## it unchanged.
##
## The seconds below are the take's own pacing, authoring data like the pose files' numbers and the
## act files' tick counts, not feel: a clip step lasts its clip, a move step its move, a walk step the
## distance at a pace read from Tuning. The sum is about TAKE_SECONDS (a test holds it).
##
## One step is a Dictionary:
## - `name`      the label of the step (a LOOK-MARK, the F4 status line)
## - `kind`      `stand` (the idle for `seconds`, turning `turn_deg` about its own vertical, positive
##               to its left, over the step: the turntable), `walk` (`move_m` m along its facing,
##               negative backing off, at the Tuning pace `pace`, its feet playing the walk), `clip`
##               (`anim`, a named animation, for its own length plus `hold`, or `seconds`), `move`
##               (`move`, the id of a move in game/combat/moves, for its own length; `windup` says the
##               move is the opener of an attack, which the AI winds up: EnemyActor.windup_move())
## - `slide_m`   a clip or a move that carries the body: meters along the Punk's facing over the step,
##               negative backwards (a stagger, a knockdown: the body goes where a hit sends it, and
##               a lying body is a metre long each way of where it falls, so it lies where the lens sees it)
## - `hit_point` a clip that is a reaction to a hit: the rig point the contact flash is aimed at
## - `damage`    the DamageLook.Level the Punk wears from this step on
## - `marks`     how many extra marks the act takes inside the step (a turntable's quarters)
## - `view_pitch_deg` the act only: the pitch the view turns to as the step starts (a lying body is
##               below the lens); the F4 showcase leaves the view to the player

## The take's length (s), and how far from it the sum of the steps may be.
const TAKE_SECONDS := 40.0
const TAKE_TOLERANCE_S := 1.5
## The pace a Punk circles at: what its walk-in and its backing off use.
const PACE := &"posture_circle_speed_mps"

const STEPS: Array[Dictionary] = [
	{name = &"idle", kind = &"stand", seconds = 5.0},
	{name = &"turntable", kind = &"stand", seconds = 10.0, turn_deg = 360.0, marks = 3},
	{name = &"back_off", kind = &"walk", move_m = -1.2, pace = PACE},
	{name = &"walk_in", kind = &"walk", move_m = 1.2, pace = PACE},
	{name = &"guard", kind = &"stand", seconds = 1.5},
	{name = &"taunt", kind = &"clip", anim = &"taunt", hold = 0.4},
	{name = &"jab", kind = &"move", move = &"punk_jab", windup = true},
	{name = &"cross", kind = &"move", move = &"punk_cross"},
	{name = &"guard_again", kind = &"stand", seconds = 1.5},
	{name = &"takes_jab", kind = &"clip", anim = &"flinch_head_front", hit_point = &"EyePoint", damage = 1, hold = 0.4},
	{name = &"stagger", kind = &"clip", anim = &"stagger_back", slide_m = -0.5, hold = 0.2},
	{name = &"knockdown", kind = &"clip", anim = &"knockdown_back", slide_m = -1.0, view_pitch_deg = -20.0},
	{name = &"lying", kind = &"clip", anim = &"downed_back", seconds = 2.5, damage = 2},
	{name = &"get_up", kind = &"clip", anim = &"getup_back", hold = 0.3},
	{name = &"walk_in_again", kind = &"walk", move_m = 1.5, pace = PACE, view_pitch_deg = -6.0},
	{name = &"guard_third", kind = &"stand", seconds = 1.0},
	{name = &"turn_away", kind = &"stand", seconds = 1.0, turn_deg = 180.0},
	{name = &"falls_forward", kind = &"clip", anim = &"knockdown_forward", slide_m = 1.0, view_pitch_deg = -25.0},
	{name = &"lying_face_down", kind = &"clip", anim = &"downed_front", seconds = 2.5},
	{name = &"get_up_face_down", kind = &"clip", anim = &"getup_front", hold = 0.3},
	{name = &"turn_back", kind = &"stand", seconds = 1.0, turn_deg = -180.0, view_pitch_deg = -6.0},
	{name = &"ko", kind = &"clip", anim = &"ko_back", hold = 3.0, slide_m = -0.3, view_pitch_deg = -25.0},
]


## The take's steps (a copy of STEPS: a caller may not change the table).
static func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for step: Dictionary in STEPS:
		out.append(step.duplicate())
	return out


## How long `step` lasts on `rig`'s clips, in seconds: a stand is its `seconds`, a walk its
## distance over the pace, a clip its own length plus `hold` (or `seconds` when the step gives
## them), a move the length the rig builds it to (total_frames() at the tick rate).
static func seconds_of(step: Dictionary, rig: HumanoidRig) -> float:
	match step.kind:
		&"stand":
			return float(step.seconds)
		&"walk":
			return absf(float(step.move_m)) / maxf(pace_of(step), 0.001)
		&"clip":
			if float(step.get("seconds", 0.0)) > 0.0:
				return float(step.seconds)
			return rig.anim_player.get_animation(step.anim).length + float(step.get("hold", 0.0))
		&"move":
			return float(move_of(step).total_frames()) / float(Engine.physics_ticks_per_second)
	return 0.0


## The speed (m/s) a walk step goes at: its Tuning pace.
static func pace_of(step: Dictionary) -> float:
	return float(Tuning.data.get(step.pace))


## The MoveData a move step plays, as the AI plays it: the opener of an attack with its wind-up
## scaled and floored (EnemyActor.windup_move()), a chain link as it is.
static func move_of(step: Dictionary) -> MoveData:
	var move := load("%s%s.tres" % [EnemyAttack.MOVES_DIR, step.move]) as MoveData
	return EnemyActor.windup_move(move, false) if step.get("windup", false) else move


## The seconds of every step on `rig`, in order, and their sum.
static func durations(rig: HumanoidRig) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for step: Dictionary in STEPS:
		out.append(seconds_of(step, rig))
	return out
