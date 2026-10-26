class_name EnemyPosesThug
extends RefCounted
## The Pipe Thug's move recipes (thug_pipe_1..3), authored on the boxer guard `g` like every
## enemy move: the Thug stands, walks and starts and ends every swing in the rig's boxer stance
## (its pipe rests back over the right shoulder there), so a swing never pops from a stance it
## was not in. The strikes and follow-throughs are the player's pipe swings' (PlaceholderPoses.
## _pipe_swing_1/2/3), which only ever override the right arm and the body's turn, so the
## WeaponTip reaches the same spots (the reach tests measure it). Only the wind-ups are new:
##   thug_pipe_1  the telegraph. The pipe is cocked high behind the right shoulder, the torso
##                coiled away and the weight on the rear foot, held from 80% of the startup
##                (PlaceholderEnemyPoses.held()) before the swing comes across.
##   thug_pipe_2  a chain link (only if the first landed): no telegraph of its own, the backhand
##                is cocked across the body at the left.
##   thug_pipe_3  a chain link: the pipe raised straight up beside the head for the overhead smash.
## The wind-ups are authored for the defender's first-person lens (tests/test_enemy_moves_thug.gd):
## the head stays in view, the pipe's tip is in the view at the held key, no joint is past the
## ragdoll's limit (a stagger starts a partial ragdoll from the pose on screen). Numbers here are
## art data.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"]


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg` is not used: every
## swing overrides the whole right arm), or null.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	match id:
		&"thug_pipe_1":
			return _swing_1(g)
		&"thug_pipe_2":
			return _swing_2(g)
		&"thug_pipe_3":
			return _swing_3(g)
	return null


## The forehand, right to left, with a big held wind-up: the torso coiled to the right and the
## weight back, the right arm out and back with the pipe cocked up behind the shoulder (its tip
## about 0.3 m above the head, beside it), the left fist guarding the chin and the head turned
## back to the target. Seen from the defender's lens the pipe rises on the left of the view beside
## the face and hangs there before it comes across.
static func _swing_1(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var m := PlaceholderPoses._pipe_swing_1(g)
	m.windup = PlaceholderPoses.merge(g, {
		&"Hips": Vector3(0.0, -22.0, 0.0),
		&"Spine": Vector3(6.0, -12.0, 0.0),
		&"Chest": Vector3(2.0, -10.0, 0.0),
		&"Neck": Vector3(3.0, 18.0, 0.0),
		&"Head": Vector3(0.0, 16.0, 0.0),
		&"RightShoulder": Vector3(0.0, -14.0, 12.0),
		&"RightUpperArm": Vector3(60.0, 4.0, 90.0),
		&"RightLowerArm": Vector3(68.0, 0.0, 0.0),
		&"RightHand": Vector3(-59.0, 6.0, 39.0),
		&"LeftUpperArm": Vector3(23.0, 32.5, -22.5),
		&"LeftLowerArm": Vector3(147.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, -12.0, -4.0),
		&"LeftLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(2.0, -12.0, 5.0),
		&"RightLowerLeg": Vector3(-32.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -5.0),
	})
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())


## The backhand, left to right, that follows the first swing: the torso turned to the left and the
## pipe cocked out wide at the left and low, level, so it never points at the defender's face and
## the arm does not cross it on its way there; the swing brings the pipe round across the front. A chain link, so no hold: the cock is as short as the link's
## startup.
static func _swing_2(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var m := PlaceholderPoses._pipe_swing_2(g)
	m.windup = PlaceholderPoses.merge(g, {
		&"Hips": Vector3(0.0, 28.0, 0.0),
		&"Chest": Vector3(-3.0, 16.0, 0.0),
		&"Neck": Vector3(4.0, -20.0, 0.0),
		&"Head": Vector3(2.0, -18.0, 0.0),
		&"RightUpperArm": Vector3(52.0, 65.0, -14.0),
		&"RightLowerArm": Vector3(36.0, 0.0, 0.0),
		&"RightHand": Vector3(-23.0, -58.0, -19.0),
		&"LeftUpperArm": Vector3(23.0, 32.5, -22.5),
		&"LeftLowerArm": Vector3(147.0, 0.0, 0.0),
	})
	m.windup_at = PlaceholderEnemyPoses.WINDUP_AT
	return m


## The overhead smash that ends the combo: the pipe straight up above the right shoulder (tip about
## 0.35 m over the head) and the body leaning back, then the chop down past the head onto the
## shoulder. A chain link: no hold.
static func _swing_3(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var m := PlaceholderPoses._pipe_swing_3(g)
	m.windup = PlaceholderPoses.merge(g, {
		&"Spine": Vector3(8.0, 0.0, 0.0),
		&"Chest": Vector3(6.0, 0.0, 0.0),
		&"Neck": Vector3(-3.0, 0.0, 0.0),
		&"Head": Vector3(-4.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, -6.0, 8.0),
		&"RightUpperArm": Vector3(80.0, -2.0, 18.0),
		&"RightLowerArm": Vector3(68.0, 0.0, 0.0),
		&"RightHand": Vector3(-54.0, -18.0, -4.0),
		&"LeftUpperArm": Vector3(23.0, 32.5, -22.5),
		&"LeftLowerArm": Vector3(147.0, 0.0, 0.0),
	})
	# The player's smash strikes with the arm straight up (a 180 degree raise, past what a ragdoll
	# joint holds): this one reaches the same spot from 142 degrees, the wrist bent back.
	m.strike = PlaceholderPoses.merge(m.strike, {
		&"RightUpperArm": Vector3(142.0, -1.0, 8.0),
		&"RightLowerArm": Vector3(108.0, 0.0, 0.0),
		&"RightHand": Vector3(123.0, -10.0, 17.0),
	})
	m.windup_at = PlaceholderEnemyPoses.WINDUP_AT
	return m
