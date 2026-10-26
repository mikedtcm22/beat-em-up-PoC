class_name EnemyNamedPoses
extends RefCounted
## The named (non-move) animations every enemy archetype shares: `taunt`, a posture gesture of
## about 1.1 s, guard to an open-handed beckon and back. Open-handed on purpose: the arms spread
## low and wide, the palms up, the chin lifted, and one hand curls "come on" at the hip. No fist
## is ever raised above the shoulder or cocked back, so it can't be mistaken for a wind-up (the
## test in tests/test_enemy_actor.gd holds every hand below the shoulders). Numbers are art data.

## Length (s) of the taunt.
const TAUNT_LENGTH := 1.1


## The named animation `id` (taunt) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	if id == &"taunt":
		return _taunt(g)
	return PlaceholderEnemyPoses.stance_named(g, TAUNT_LENGTH)


## Guard, then the arms drop and open out to the sides (palms up, chin lifted, the torso
## rocking back a little), the lead hand beckons twice and the arms come back to the guard.
static func _taunt(g: Dictionary[StringName, Vector3]) -> Dictionary:
	var open := PlaceholderPoses.merge(g, {
		&"Spine": Vector3(5.0, 0.0, 0.0),
		&"Chest": Vector3(3.0, 0.0, 0.0),
		&"Neck": Vector3(10.0, 0.0, 0.0),
		&"Head": Vector3(10.0, 0.0, 0.0),
		&"LeftShoulder": Vector3(0.0, 4.0, -3.0),
		&"LeftUpperArm": Vector3(12.0, -6.0, -52.0),
		&"LeftLowerArm": Vector3(70.0, 0.0, 0.0),
		&"LeftHand": Vector3(-30.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, -4.0, 3.0),
		&"RightUpperArm": Vector3(12.0, 6.0, 52.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
		&"RightHand": Vector3(-30.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(14.0, 0.0, -6.0),
		&"RightUpperLeg": Vector3(-4.0, 0.0, 7.0),
	})
	var beckon_in := PlaceholderPoses.merge(open, {
		&"LeftUpperArm": Vector3(26.0, -10.0, -34.0),
		&"LeftLowerArm": Vector3(74.0, 0.0, 0.0),
		&"LeftHand": Vector3(-52.0, 0.0, 0.0),
	})
	var beckon_out := PlaceholderPoses.merge(open, {
		&"LeftUpperArm": Vector3(24.0, -10.0, -38.0),
		&"LeftLowerArm": Vector3(48.0, 0.0, 0.0),
		&"LeftHand": Vector3(-10.0, 0.0, 0.0),
	})
	var keys: Array[PlaceholderAnims.PoseKey] = [
		PlaceholderAnims.PoseKey.new(0.0, g),
		PlaceholderAnims.PoseKey.new(0.28, open),
		PlaceholderAnims.PoseKey.new(0.46, beckon_in),
		PlaceholderAnims.PoseKey.new(0.6, beckon_out),
		PlaceholderAnims.PoseKey.new(0.74, beckon_in),
		PlaceholderAnims.PoseKey.new(0.84, open),
		PlaceholderAnims.PoseKey.new(TAUNT_LENGTH, g),
	]
	return {length = TAUNT_LENGTH, keys = keys}
