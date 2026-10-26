class_name GrabPoses
extends RefCounted
## The enemy grab poses (Milestone 3, P2-grab): the recipes of bruiser_grab, bruiser_headbutt,
## boss_grab and boss_slam, and the named holds `hold_collar` (the holder upright over its victim,
## both fists on the victim's collar), `held_collar` (the victim upright, leaning a little toward the
## holder, hands on the holder's wrists: a struggle loop) and `held_lift` (held_collar with the hips
## raised: the slam's wind-up).
##
## Why a grab has two moves: the grab (a telegraph, then a reach whose strike frame connects by code
## or whiffs) and a follow-up that starts the moment it connects, in the hold pose. Its startup is
## the mash window: the holder keeps its grip while the head (headbutt) or the arms (slam) wind up,
## and at its strike frame the victim is let go and hit by code (EnemyHold).
##
## The holds are authored for the defender's first-person lens (tests/test_player_grabbed.gd): the
## player stands upright, pinned grabbed_pin_distance_m (plus the holder's extra radius) from the
## holder, leaning back a little, with his lens at throat height, so a fist on his collar would sit
## in the lens. The holder's fists are on his arms instead, 0.32 m either side and a hand below
## the lens, the arms nearly straight and the body leaning over its planted feet (a lunge): at the
## arm's length of the grab's own reach the holder's chest is half a metre off and its face
## (looked up to: PlayerCharacter.get_grabbed_view_pitch_deg()) a metre away, its forearms come in
## from the lower corners of the view. The arm angles were solved numerically against the rig (fists
## on the player's upper-arm points at the Bruiser's 2.05 m and the boss's 2.3 m); the numbers are art data.
## Every key pose stays inside the ragdoll's joint limits (a stagger starts a partial ragdoll from
## the pose on screen): the upper arms raise at most about 115 degrees.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = [&"bruiser_grab", &"bruiser_headbutt", &"boss_grab", &"boss_slam"]

## How far (m at the reference height) the slam's wind-up lifts the victim's hips, and the same
## height of the holder's fists above the hold's.
const LIFT_M := 0.35
## The grab's strike leans the whole upper body this far forward over the planted feet (m at the
## reference height: HIPS_NUDGE), the reach that makes up the arm's length; the holds lean over by
## HOLD_LEAN_M, the same lunge held.
const REACH_LEAN_M := 0.15
const HOLD_LEAN_M := 0.10
## The loop lengths (s) of the named holds.
const HOLD_LOOP_S := 1.0
const HELD_LOOP_S := 0.7


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	match id:
		&"bruiser_grab":
			return _grab(g, false)
		&"boss_grab":
			return _grab(g, true)
		&"bruiser_headbutt":
			return _headbutt(g)
		&"boss_slam":
			return _slam(g)
	return null


## The named hold animation `id` (hold_collar, held_collar, held_lift) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`. hold_collar is the Bruiser's grip (the
## headbutt's start and end pose); the boss's own, bent further over, is boss_slam's first key.
## held_collar and held_lift are the player's (always the 1.8 m rig, in its relaxed stance).
static func named(id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	match id:
		&"hold_collar":
			return _hold_loop(g)
		&"held_collar":
			return _held_loop(g, false)
		&"held_lift":
			return _held_loop(g, true)
	return PlaceholderEnemyPoses.stance_named(g, 1.0)


# --- The holder -------------------------------------------------------------------------------


## The legs of the Bruiser's grip: a planted boxer stance, the knees a little more bent.
static func _hold_legs() -> Dictionary[StringName, Vector3]:
	return {
		&"LeftUpperLeg": Vector3(26.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-36.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(4.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(22.0, 0.0, -5.0),
	}


## The boss's grip: bent deep at the knees to bring its shoulders down to the player's collar.
static func _boss_legs() -> Dictionary[StringName, Vector3]:
	return {
		&"LeftUpperLeg": Vector3(52.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-76.0, 0.0, 0.0),
		&"LeftFoot": Vector3(20.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-6.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-50.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
	}


## Both arms from the left arm's angles (the right mirrors it: yaw and roll negate) and the elbow.
static func _arms(upper: Vector3, elbow: float) -> Dictionary[StringName, Vector3]:
	return {
		&"LeftUpperArm": upper,
		&"LeftLowerArm": Vector3(elbow, 0.0, 0.0),
		&"RightUpperArm": Vector3(upper.x, -upper.y, -upper.z),
		&"RightLowerArm": Vector3(elbow, 0.0, 0.0),
	}


## The torso from the spine up (forward bends are negative), the head kept level over it.
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


## The Bruiser's grip on the player's upper arms: leaning over its feet with both arms out, the fists a
## hand below the player's lens and 0.32 m out either side.
static func bruiser_hold(g: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return _with(g, [_torso(-12.0, -7.0, -4.0, 12.0, 6.0), _hold_legs(), _lean(HOLD_LEAN_M),
			_arms(Vector3(83.5, -14.0, -19.5), 5.0)])


## The boss's grip: the same on a body 25% bigger, crouched deep and bent over to reach down to him.
static func boss_hold(g: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return _with(g, [_torso(-22.0, -12.0, -6.0, 16.0, 8.0), _boss_legs(), _lean(HOLD_LEAN_M),
			_arms(Vector3(66.5, -13.0, -18.0), 52.0)])


## The upper body leaned `metres` forward over planted feet (HIPS_NUDGE, at the reference height).
static func _lean(metres: float) -> Dictionary[StringName, Vector3]:
	return {PlaceholderPoses.HIPS_NUDGE: Vector3(0.0, 0.0, -metres)}


## The grab: both arms spread wide and the body crouched forward (a wrestler's "come here", the
## hands open at the edges of the defender's view, held), then both arms reach out at the chest
## and the whole upper body lunges over the planted feet. A whiff recovers to the guard. The
## connect is EnemyHold's, at the strike frame.
static func _grab(g: Dictionary[StringName, Vector3], boss: bool) -> PlaceholderPoses.MovePoses:
	var crouch := {
		&"LeftUpperLeg": Vector3(50.0, 0.0, -10.0),
		&"LeftLowerLeg": Vector3(-84.0, 0.0, 0.0),
		&"LeftFoot": Vector3(30.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(36.0, 0.0, 10.0),
		&"RightLowerLeg": Vector3(-78.0, 0.0, 0.0),
		&"RightFoot": Vector3(38.0, 0.0, -6.0),
	}
	var windup := _with(g, [_torso(-14.0, -8.0, -4.0, 16.0, 6.0), crouch, _arms(Vector3(35.5, 11.5, -65.5), 46.5)])
	var lunge := {
		PlaceholderPoses.HIPS_NUDGE: Vector3(0.0, 0.0, -REACH_LEAN_M),
		&"LeftUpperLeg": Vector3(32.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-42.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-12.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-28.0, 0.0, 0.0),
		&"RightFoot": Vector3(22.0, 0.0, -5.0),
	}
	var reach := _torso(-28.0, -15.0, -8.0, 18.0, 8.0) if boss else _torso(-20.0, -11.0, -6.0, 14.0, 6.0)
	var arms := _arms(Vector3(103.0, -9.5, -7.0), 24.5) if boss else _arms(Vector3(109.0, -5.5, -6.0), 5.0)
	var strike := _with(g, [reach, lunge, arms])
	var m := PlaceholderPoses._mp(g, windup, strike)
	m.finish = g
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())


## The headbutt: it starts in the grip (the held player is where this move's startup, the mash
## window, plays), the head and shoulders draw back and up while the fists stay on his arms
## (held, trembling: the telegraph), then the whole body drops forward and the forehead goes
## through where the player's face is. The recovery lets go and stands up.
static func _headbutt(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var grip := bruiser_hold(g)
	var windup := _with(g, [_torso(-8.0, -5.0, -3.0, -2.0, -18.0), _hold_legs(), _lean(0.08),
			_arms(Vector3(77.0, -14.5, -19.0), 5.0)])
	var strike := _with(g, [_torso(-32.0, -17.5, -9.5, 8.0, 0.0), _hold_legs(), _lean(0.12), {
		&"LeftUpperLeg": Vector3(34.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-44.0, 0.0, 0.0),
	}, _arms(Vector3(78.5, -10.0, -22.5), 81.0)])
	var follow := _with(g, [_torso(-12.0, -6.0, -2.0, 8.0, 4.0), _arms(Vector3(40.0, -18.0, -16.0), 70.0)])
	var m := PlaceholderPoses._mp(grip, windup, strike)
	m.follow = follow
	m.finish = g
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())


## The slam: from the boss's grip it lifts the player overhead (the fists rise a lift's height
## with him, held trembling at the top: the telegraph) and then throws him down and forward over
## its bent body. The recovery lets go and stands up.
static func _slam(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var grip := boss_hold(g)
	var up_legs := {
		&"LeftUpperLeg": Vector3(28.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-42.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(4.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-32.0, 0.0, 0.0),
		&"RightFoot": Vector3(22.0, 0.0, -5.0),
	}
	var windup := _with(g, [_torso(-6.0, -3.0, 0.0, -2.0, -14.0), up_legs, _lean(0.04),
			_arms(Vector3(83.0, -15.0, -17.5), 5.0)])
	var heave_legs := {
		&"LeftUpperLeg": Vector3(10.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"LeftFoot": Vector3(4.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-2.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"RightFoot": Vector3(14.0, 0.0, -5.0),
	}
	var strike := _with(g, [_torso(10.0, 8.0, 4.0, 10.0, 6.0), heave_legs, _lean(-0.06),
			_arms(Vector3(112.0, -6.0, -34.0), 14.0)])
	var follow := _with(g, [_torso(-18.0, -10.0, -4.0, 12.0, 6.0), _arms(Vector3(50.0, -14.0, -14.0), 50.0)])
	var m := PlaceholderPoses._mp(grip, windup, strike)
	m.follow = follow
	m.finish = g
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())


## hold_collar: the Bruiser's grip, breathing: the shoulders rock a little and the head dips.
static func _hold_loop(g: Dictionary[StringName, Vector3]) -> Dictionary:
	var grip := bruiser_hold(g)
	var sway := PlaceholderPoses.add(grip, {
		&"Spine": Vector3(-2.0, 1.5, 0.0),
		&"Chest": Vector3(-1.0, 1.5, 0.0),
		&"Head": Vector3(2.0, -2.0, 0.0),
	})
	var keys: Array[PlaceholderAnims.PoseKey] = [
		PlaceholderAnims.PoseKey.new(0.0, grip),
		PlaceholderAnims.PoseKey.new(HOLD_LOOP_S * 0.5, sway),
		PlaceholderAnims.PoseKey.new(HOLD_LOOP_S, grip),
	]
	return {length = HOLD_LOOP_S, keys = keys}


# --- The victim -------------------------------------------------------------------------------


## The player's own pose while held: upright and leaning back a little from the holder (the body
## stays over its feet, and the hips are not nudged, so letting go moves nothing), the hands up on
## the holder's wrists in front of the chest, the elbows in. The lens (at the head) is 0.14 m
## ahead of the origin standing; the lean draws it back about a hand's breadth, which is what
## gives the holder's chest and face room in the view. `lifted`: the whole body hangs LIFT_M
## higher, the legs dangling (the slam's wind-up).
static func held_pose(g: Dictionary[StringName, Vector3], lifted: bool = false) -> Dictionary[StringName, Vector3]:
	var pose := _with(g, [_torso(8.0, 5.0, 2.0, -2.0, -4.0), _arms(Vector3(-6.0, 5.0, -26.5), 131.0)])
	if lifted:
		pose = _with(pose, [{
			&"LeftUpperLeg": Vector3(4.0, 0.0, -4.0),
			&"LeftLowerLeg": Vector3(-10.0, 0.0, 0.0),
			&"LeftFoot": Vector3(28.0, 0.0, 4.0),
			&"RightUpperLeg": Vector3(-2.0, 0.0, 5.0),
			&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
			&"RightFoot": Vector3(32.0, 0.0, -5.0),
		}])
		pose[PlaceholderPoses.HIPS_POS] = PlaceholderAnims.resolve_hips(pose) + Vector3(0.0, LIFT_M, 0.0)
	return pose


## held_collar / held_lift: a struggle loop, the shoulders heaving against the grip.
static func _held_loop(g: Dictionary[StringName, Vector3], lifted: bool) -> Dictionary:
	var base := held_pose(g, lifted)
	var back := PlaceholderPoses.add(base, {
		&"Spine": Vector3(3.0, 1.5, 0.0),
		&"Chest": Vector3(2.0, 2.0, 0.0),
		&"Head": Vector3(-3.0, 3.0, 0.0),
	})
	var side := PlaceholderPoses.add(base, {
		&"Spine": Vector3(-1.0, -2.0, 1.5),
		&"Chest": Vector3(-1.0, -2.5, 1.0),
		&"Head": Vector3(1.0, -4.0, 0.0),
	})
	var keys: Array[PlaceholderAnims.PoseKey] = [
		PlaceholderAnims.PoseKey.new(0.0, base),
		PlaceholderAnims.PoseKey.new(HELD_LOOP_S * 0.25, back),
		PlaceholderAnims.PoseKey.new(HELD_LOOP_S * 0.5, base),
		PlaceholderAnims.PoseKey.new(HELD_LOOP_S * 0.75, side),
		PlaceholderAnims.PoseKey.new(HELD_LOOP_S, base),
	]
	return {length = HELD_LOOP_S, keys = keys}
