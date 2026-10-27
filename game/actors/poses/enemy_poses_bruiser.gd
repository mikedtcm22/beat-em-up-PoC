class_name EnemyPosesBruiser
extends RefCounted
## The Bruiser's move recipe (bruiser_smash, its overhead smash) and its named `brace` clip (armor
## shrugging off a light hit while it stands posturing). Its grab and headbutt are GrabPoses'.
##
## The smash: both fists are raised over the head (the telegraph: the arms up at the sides of the
## face, the back arched, the weight on the rear foot, held from 80% of the startup), then both
## fists come down together in front of the chest as the whole body drops forward over the planted
## front foot. Authored for a 2.05 m rig that hits a 1.8 m player (tests/test_enemy_moves_bruiser.gd):
## the poses are angles, so on a rig this much taller the strike must aim down (the spine and neck
## bend forward and the fists end low, at the player's head and shoulders, not at the height an
## arm straight out of a 2.05 m chest would reach) and the wind-up's raise stays under the ragdoll
## shoulder's limit (about 140 degrees: a stagger starts a partial ragdoll from the pose on screen).
## Numbers here are art data.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = [&"bruiser_smash"]

## Where the raise ends, as a share of the startup (the dispatcher's 0.5 is for a grunt's cock; the
## raise is quicker and held longer, so it reads as a lift and then a hold).
const RAISE_AT := 0.42
## The length (s) of the brace clip.
const BRACE_S := 0.36


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg` is not used), or null.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	if id == &"bruiser_smash":
		return _smash(g)
	return null


## The named animation `id` (brace) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	if id == &"brace":
		return _brace(g)
	return PlaceholderEnemyPoses.stance_named(g, BRACE_S)


## Both arms from the left arm's angles (the right mirrors it: yaw and roll negate) and the elbow.
static func _arms(upper: Vector3, elbow: float) -> Dictionary[StringName, Vector3]:
	return {
		&"LeftUpperArm": upper,
		&"LeftLowerArm": Vector3(elbow, 0.0, 0.0),
		&"RightUpperArm": Vector3(upper.x, -upper.y, -upper.z),
		&"RightLowerArm": Vector3(elbow, 0.0, 0.0),
	}


## The torso from the spine up (forward bends are negative).
static func _torso(spine: float, chest: float, upper_chest: float, neck: float, head: float) -> Dictionary[StringName, Vector3]:
	return {
		&"Spine": Vector3(spine, 0.0, 0.0),
		&"Chest": Vector3(chest, 0.0, 0.0),
		&"UpperChest": Vector3(upper_chest, 0.0, 0.0),
		&"Neck": Vector3(neck, 0.0, 0.0),
		&"Head": Vector3(head, 0.0, 0.0),
	}


static func _with(base: Dictionary[StringName, Vector3], parts: Array[Dictionary]) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = base.duplicate()
	for part: Dictionary in parts:
		for bone: StringName in part:
			out[bone] = part[bone]
	return out


## The overhead smash: see the file's doc. A single move with its own held wind-up, no chain.
static func _smash(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var set_legs := {
		&"LeftUpperLeg": Vector3(22.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-4.0, 0.0, 8.0),
		&"RightLowerLeg": Vector3(-26.0, 0.0, 0.0),
		&"RightFoot": Vector3(22.0, 0.0, -5.0),
	}
	var shrug := {&"LeftShoulder": Vector3(0.0, 0.0, -28.0), &"RightShoulder": Vector3(0.0, 0.0, 28.0)}
	var windup := _with(g, [_torso(10.0, 8.0, 4.0, -6.0, -8.0), set_legs, shrug, _arms(Vector3(140.0, 32.0, -22.0), 8.0)])
	var lunge := {
		PlaceholderPoses.HIPS_NUDGE: Vector3(0.0, 0.0, -0.18),
		&"LeftUpperLeg": Vector3(40.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-46.0, 0.0, 0.0),
		&"LeftFoot": Vector3(6.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-18.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -5.0),
	}
	var strike := _with(g, [_torso(-14.0, -8.0, -4.0, 10.0, 6.0), lunge, _arms(Vector3(104.0, -4.0, -8.0), 12.0)])
	var follow := _with(g, [_torso(-16.0, -8.0, -4.0, 10.0, 6.0), _arms(Vector3(40.0, -14.0, -12.0), 60.0)])
	var m := PlaceholderPoses._mp(g, windup, strike)
	m.follow = follow
	m.finish = g
	return PlaceholderEnemyPoses.held(m, RAISE_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT, PlaceholderEnemyPoses.tremble())


## brace: a hit it ignores. The chest pushes out and the shoulders bunch, the chin drops and the
## fists come in, for a third of a second, then the stance again: it registers the blow and does
## not give way to it.
static func _brace(g: Dictionary[StringName, Vector3]) -> Dictionary:
	var set := PlaceholderPoses.add(g, {
		&"Spine": Vector3(5.0, 0.0, 0.0),
		&"Chest": Vector3(5.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"Head": Vector3(-4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(8.0, 0.0, -6.0),
		&"RightUpperArm": Vector3(8.0, 0.0, 6.0),
	})
	var keys: Array[PlaceholderAnims.PoseKey] = [
		PlaceholderAnims.PoseKey.new(0.0, g),
		PlaceholderAnims.PoseKey.new(BRACE_S * 0.3, set),
		PlaceholderAnims.PoseKey.new(BRACE_S * 0.65, set),
		PlaceholderAnims.PoseKey.new(BRACE_S, g),
	]
	return {length = BRACE_S, keys = keys}
