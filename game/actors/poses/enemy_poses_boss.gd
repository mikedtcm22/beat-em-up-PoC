class_name EnemyPosesBoss
extends RefCounted
## The boss's move recipes (boss_charge, boss_pound) and its named `run_forward` loop (a run
## cycle), authored on the boxer guard like every enemy move; its grab and slam are GrabPoses'.
## Both moves are held telegraphs (PlaceholderEnemyPoses.held()): the wind-up pose is cocked by
## 50% of the startup and held to 80%, then the strike drives in over the last fifth.
##
## The charge is a bull's: the body sinks into a crouch with the torso pitched far over the lead
## knee, the head up and on the target, the arms drawn back and low (so nothing of them covers the
## face from the defender's lens), the right shoulder turned in; held, it sinks a little more.
## The strike is a mid-stride lunge held through the 24 active frames, the torso pitched over the
## lead leg with the arms swept back and low (a fist in front of the chest would be a hand's breadth
## from the defender's lens when it lands) and the right shoulder leading; the legs
## swap from one stride to the other over the dash, and the recovery pulls up out of a braking
## crouch. The hitbox is an arc in front of the shoulder (MoveData), not the pose, so the drawn
## shoulder only has to read as "head down, shoulder first".
##
## The pound rears up: the body goes tall on straight legs, both arms raised overhead and a little
## wide (so the head stays in the view between them), the back arched; held, the fists climb. The
## strike drops the whole body: both fists driven down to the floor in front, the knees deep, the
## torso folded over them. The hitbox is a ring round the boss (MoveData).
##
## Authored for the defender's lens (tests/test_enemy_moves_boss.gd): the head stays in the view
## through the telegraphs, and no joint is past the ragdoll's limit (a stagger starts a partial
## ragdoll from the pose on screen: the upper arms raise at most about 140 degrees). Numbers here
## are art data.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = [&"boss_charge", &"boss_pound"]

## The run loop's length (s): two strides.
const RUN_LOOP_S := 0.5


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	match id:
		&"boss_charge":
			return _charge(g)
		&"boss_pound":
			return _pound(g)
	return null


## The named animation `id` (run_forward) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	if id == &"run_forward":
		return _run(g)
	return PlaceholderEnemyPoses.stance_named(g, RUN_LOOP_S)


# --- The charge -------------------------------------------------------------------------------


## The legs of a stride: `lead` is the leg out in front ("Left" or "Right"), the other trails.
static func _stride(lead: StringName, trail_lift: float) -> Dictionary[StringName, Vector3]:
	var left_lead: Dictionary[StringName, Vector3] = {
		&"LeftUpperLeg": Vector3(62.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-44.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-6.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-34.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-50.0 - trail_lift, 0.0, 0.0),
		&"RightFoot": Vector3(46.0, 0.0, -5.0),
		&"RightToes": Vector3(24.0, 0.0, 0.0),
	}
	return left_lead if lead == &"Left" else PlaceholderPoses.mirror(left_lead)


## A bull's charge: crouch and pitch over the lead knee, arms drawn back and low, head up (held,
## sinking); the strike is a stride held through the dash with the right shoulder leading, then
## the other stride; the recovery brakes in a crouch.
static func _charge(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var windup := PlaceholderPoses.merge(g, {
		&"Spine": Vector3(-26.0, 12.0, 0.0),
		&"Chest": Vector3(-10.0, 6.0, 0.0),
		&"UpperChest": Vector3(-4.0, 0.0, 0.0),
		&"Neck": Vector3(28.0, -10.0, 0.0),
		&"Head": Vector3(12.0, -6.0, 0.0),
		&"LeftUpperLeg": Vector3(60.0, 0.0, -10.0),
		&"LeftLowerLeg": Vector3(-86.0, 0.0, 0.0),
		&"LeftFoot": Vector3(30.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(-24.0, 0.0, 8.0),
		&"RightLowerLeg": Vector3(-58.0, 0.0, 0.0),
		&"RightFoot": Vector3(40.0, 0.0, -6.0),
		&"RightToes": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-26.0, -8.0, -16.0),
		&"LeftLowerArm": Vector3(36.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-34.0, 8.0, 18.0),
		&"RightLowerArm": Vector3(40.0, 0.0, 0.0),
	})
	var strike := PlaceholderPoses.merge(PlaceholderPoses.merge(g, _stride(&"Left", 0.0)), {
		&"Spine": Vector3(-34.0, 16.0, 0.0),
		&"Chest": Vector3(-14.0, 8.0, 0.0),
		&"UpperChest": Vector3(-8.0, 6.0, 0.0),
		&"Neck": Vector3(34.0, -14.0, 0.0),
		&"Head": Vector3(14.0, -8.0, 0.0),
		&"LeftUpperArm": Vector3(-38.0, -8.0, -14.0),
		&"LeftLowerArm": Vector3(52.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-44.0, 10.0, 18.0),
		&"RightLowerArm": Vector3(58.0, 0.0, 0.0),
	})
	var strike_end := PlaceholderPoses.merge(strike, _stride(&"Right", 8.0))
	var m := PlaceholderPoses._mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = PlaceholderPoses.merge(PlaceholderPoses.crouch(g), {
		&"Spine": Vector3(-22.0, 0.0, 0.0),
		&"Neck": Vector3(20.0, 0.0, 0.0),
	})
	m.follow_at = 0.35
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			_charge_hold())


## The charge sinks a little more through the hold: the torso and the knees go on bending.
static func _charge_hold() -> Dictionary[StringName, Vector3]:
	return {
		&"Spine": Vector3(-5.0, 2.0, 0.0),
		&"Chest": Vector3(-2.0, 1.5, 0.0),
		&"LeftUpperLeg": Vector3(6.0, 0.0, 0.0),
		&"LeftLowerLeg": Vector3(-6.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-3.0, 0.0, 0.0),
		&"RightLowerLeg": Vector3(-4.0, 0.0, 0.0),
	}


# --- The pound --------------------------------------------------------------------------------


## A ground pound: rear up on straight legs with both arms raised overhead and a little wide, the
## back arched (held, the fists climb); then the whole body drops, both fists driven to the floor
## in front, the knees deep, the torso folded over them.
static func _pound(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var windup := PlaceholderPoses.merge(g, {
		&"Spine": Vector3(8.0, 0.0, 0.0),
		&"Chest": Vector3(6.0, 0.0, 0.0),
		&"UpperChest": Vector3(4.0, 0.0, 0.0),
		&"Neck": Vector3(-12.0, 0.0, 0.0),
		&"Head": Vector3(-6.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(132.0, -10.0, -40.0),
		&"LeftLowerArm": Vector3(16.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(132.0, 10.0, 40.0),
		&"RightLowerArm": Vector3(16.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(2.0, 0.0, -12.0),
		&"LeftLowerLeg": Vector3(-4.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-24.0, 0.0, 8.0),
		&"RightUpperLeg": Vector3(-2.0, 0.0, 12.0),
		&"RightLowerLeg": Vector3(-4.0, 0.0, 0.0),
		&"RightFoot": Vector3(-24.0, 0.0, -8.0),
	})
	var strike := PlaceholderPoses.merge(g, {
		&"Spine": Vector3(-32.0, 0.0, 0.0),
		&"Chest": Vector3(-26.0, 0.0, 0.0),
		&"UpperChest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(28.0, 0.0, 0.0),
		&"Head": Vector3(18.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(34.0, -8.0, -14.0),
		&"LeftLowerArm": Vector3(14.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(34.0, 8.0, 14.0),
		&"RightLowerArm": Vector3(14.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(74.0, 0.0, -12.0),
		&"LeftLowerLeg": Vector3(-104.0, 0.0, 0.0),
		&"LeftFoot": Vector3(30.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(60.0, 0.0, 12.0),
		&"RightLowerLeg": Vector3(-96.0, 0.0, 0.0),
		&"RightFoot": Vector3(34.0, 0.0, -6.0),
	})
	var strike_end := PlaceholderPoses.merge(strike, {
		&"Spine": Vector3(-34.0, 0.0, 0.0),
		&"Chest": Vector3(-30.0, 0.0, 0.0),
		&"Neck": Vector3(30.0, 0.0, 0.0),
	})
	var m := PlaceholderPoses._mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = PlaceholderPoses.merge(PlaceholderPoses.crouch(g), {
		&"Spine": Vector3(-30.0, 0.0, 0.0),
		&"Chest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(24.0, 0.0, 0.0),
	})
	m.follow_at = 0.3
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			_pound_hold())


## The fists climb a little and the back arches more through the hold.
static func _pound_hold() -> Dictionary[StringName, Vector3]:
	return {
		&"Spine": Vector3(4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(10.0, 0.0, -2.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 2.0),
	}


# --- The run ----------------------------------------------------------------------------------


## The charge's run: a hunched sprint, the torso pitched over the legs, the arms pumping against
## them, the knees driving high. Left foot forward at 0 and at the loop's half, the right at its
## quarters (the keys mirror each other).
static func _run(g: Dictionary[StringName, Vector3]) -> Dictionary:
	var contact := PlaceholderPoses.merge(g, {
		&"Spine": Vector3(-22.0, 0.0, 0.0),
		&"Chest": Vector3(-8.0, 0.0, 0.0),
		&"Neck": Vector3(24.0, 0.0, 0.0),
		&"Head": Vector3(8.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(50.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-4.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-30.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-70.0, 0.0, 0.0),
		&"RightFoot": Vector3(50.0, 0.0, -4.0),
		&"LeftUpperArm": Vector3(-26.0, -10.0, -10.0),
		&"LeftLowerArm": Vector3(70.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(58.0, 10.0, 12.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
	})
	var passing := PlaceholderPoses.merge(contact, {
		&"LeftUpperLeg": Vector3(8.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-24.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(64.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-104.0, 0.0, 0.0),
		&"RightFoot": Vector3(20.0, 0.0, -4.0),
		&"LeftUpperArm": Vector3(16.0, -10.0, -10.0),
		&"RightUpperArm": Vector3(22.0, 10.0, 12.0),
	})
	var contact_r := PlaceholderPoses.mirror(contact)
	var passing_r := PlaceholderPoses.mirror(passing)
	var step := RUN_LOOP_S * 0.25
	var keys: Array[PlaceholderAnims.PoseKey] = [
		PlaceholderAnims.PoseKey.new(0.0, contact),
		PlaceholderAnims.PoseKey.new(step, passing),
		PlaceholderAnims.PoseKey.new(step * 2.0, contact_r),
		PlaceholderAnims.PoseKey.new(step * 3.0, passing_r),
		PlaceholderAnims.PoseKey.new(RUN_LOOP_S, contact),
	]
	return {length = RUN_LOOP_S, keys = keys}
