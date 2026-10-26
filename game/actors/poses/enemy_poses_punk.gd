class_name EnemyPosesPunk
extends RefCounted
## The Street Punk's move recipes (punk_jab, punk_cross, punk_shove), authored on the boxer
## guard like every enemy move. The jab and the shove are the telegraphs: a big wind-up cocked
## by 50% of the startup and held (PlaceholderEnemyPoses.held()) until 80%, then the strike
## drives in over the last fifth. The cross is the jab's follow-up and has only a small cock.
##
## Strikes are the player's: the jab is jab_2's straight right, the cross jab_1's lead left and
## the shove the shove's two-handed push, so they reach the same spots (the reach tests measure
## it). Only the wind-ups are new, and they are authored for the defender's first-person lens
## (tests/test_enemy_moves_punk.gd): the head stays in view, the cocked hand shows beside it,
## no joint is past the ragdoll's limit (a stagger starts a partial ragdoll from the pose on
## screen). Numbers here are art data.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = [&"punk_jab", &"punk_cross", &"punk_shove"]


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	match id:
		&"punk_jab":
			return _jab(g)
		&"punk_cross":
			return _cross(g)
		&"punk_shove":
			return _shove(g)
	return null


## A right straight with a big, held wind-up: the right fist cocked high beside the ear, the
## elbow out, the shoulders and hips turned away and the weight on the rear foot, the lead glove
## guarding its side of the chin so the face stays in view. Seen from the defender's lens the
## fist draws back beside the head on the defender's left and hangs there before it comes
## straight in.
static func _jab(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var m := PlaceholderPoses._dummy_jab(g)
	m.windup = PlaceholderPoses.merge(g, {
		&"Hips": Vector3(0.0, -26.0, 0.0),
		&"Spine": Vector3(5.0, -12.0, 0.0),
		&"Chest": Vector3(3.0, -10.0, 0.0),
		&"Neck": Vector3(3.0, 22.0, 0.0),
		&"Head": Vector3(0.0, 22.0, 0.0),
		&"LeftUpperArm": Vector3(23.0, 32.5, -22.5),
		&"LeftLowerArm": Vector3(147.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, -14.0, 16.0),
		&"RightUpperArm": Vector3(30.0, -34.0, 82.0),
		&"RightLowerArm": Vector3(126.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, -12.0, -4.0),
		&"LeftLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(2.0, -12.0, 5.0),
		&"RightLowerLeg": Vector3(-32.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -5.0),
	})
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())


## The lead left that follows the jab: no telegraph of its own (it only comes if the jab landed
## or was blocked), so the cock is short, the left fist drawn back beside the chin.
static func _cross(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var m := PlaceholderPoses._jab_1(g)
	m.windup = PlaceholderPoses.merge(g, {
		&"Hips": Vector3(0.0, 6.0, 0.0),
		&"Spine": Vector3(1.0, 4.0, 0.0),
		&"LeftShoulder": Vector3(0.0, 8.0, -6.0),
		&"LeftUpperArm": Vector3(34.0, 6.0, -34.0),
		&"LeftLowerArm": Vector3(104.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(38.0, 26.0, 22.0),
	})
	m.windup_at = PlaceholderEnemyPoses.WINDUP_AT
	return m


## A two-handed shove: both hands drawn in to the chest, the elbows out wide and the palms turned
## forward, the torso rocked back on the rear foot (the chin stays up, the face in view), held,
## then both hands drive out at chest height. It reads as a push (hands, no cocked fist), so it
## is told apart from the punch from across the room.
static func _shove(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var m := PlaceholderPoses._shove(g)
	m.windup = PlaceholderPoses.merge(g, {
		&"Spine": Vector3(9.0, 0.0, 0.0),
		&"Chest": Vector3(5.0, 0.0, 0.0),
		&"Neck": Vector3(0.0, 0.0, 0.0),
		&"Head": Vector3(-2.0, 0.0, 0.0),
		&"LeftShoulder": Vector3(0.0, 6.0, -4.0),
		&"LeftUpperArm": Vector3(22.0, 0.0, -48.0),
		&"LeftLowerArm": Vector3(118.0, 0.0, 0.0),
		&"LeftHand": Vector3(64.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, -6.0, 4.0),
		&"RightUpperArm": Vector3(22.0, 0.0, 48.0),
		&"RightLowerArm": Vector3(118.0, 0.0, 0.0),
		&"RightHand": Vector3(64.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(8.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-14.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-22.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -5.0),
	})
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())
