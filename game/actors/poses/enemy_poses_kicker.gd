class_name EnemyPosesKicker
extends RefCounted
## The Kicker's move recipes (kicker_jump_kick, kicker_sweep), authored on the boxer guard like
## every enemy move. Both are held telegraphs (PlaceholderEnemyPoses.held()): the wind-up pose is
## cocked by 50% of the startup and held to 80%, then the strike drives in over the last fifth.
##
## The jump kick coils: a deep crouch, the torso pitched forward over the knees, both arms swung
## back and down, the head up and on the target. From the defender's lens that is a body that
## drops and hunches (the head sinks, the shoulders come forward), told from a punch or a sweep by
## the arms going back, not up. The strike leaves the floor: the hips rise (HIPS_POS, the capsule
## stays grounded, only the drawn body and its hurtboxes go up) with the right leg driven out
## level and the left tucked under, the arms thrown wide; the recovery lands in a crouch.
##
## The sweep drops the other way: down to the floor on the left leg, the body turned away
## through the hips (the head keeps its eyes on the target), held; then it spins low, the right
## leg out along the floor on the far side of the turn. The strike is an arc over the legs
## (MoveData hitbox), so the drawn leg only has to read as low and sweeping. Both are authored for
## the defender's lens (tests/test_enemy_moves_kicker.gd): the head stays in view, no joint is past
## the ragdoll's limit (a stagger starts a partial ragdoll from the pose on screen). Numbers
## here are art data.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = [&"kicker_jump_kick", &"kicker_sweep"]


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	match id:
		&"kicker_jump_kick":
			return _jump_kick(g)
		&"kicker_sweep":
			return _sweep(g)
	return null


## A jump kick: crouch and coil (held, sinking a little), leave the floor with the right leg
## driven out level at chest height and the left tucked, land in a crouch.
static func _jump_kick(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	var windup := PlaceholderPoses.merge(PlaceholderPoses.crouch(g), {
		&"Spine": Vector3(-20.0, 0.0, 0.0),
		&"Chest": Vector3(-8.0, 0.0, 0.0),
		&"Neck": Vector3(22.0, 0.0, 0.0),
		&"Head": Vector3(6.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(78.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-124.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(66.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-116.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-34.0, 0.0, -16.0),
		&"LeftLowerArm": Vector3(36.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-34.0, 0.0, 16.0),
		&"RightLowerArm": Vector3(36.0, 0.0, 0.0),
	})
	var strike := PlaceholderPoses.merge(g, {
		PlaceholderPoses.HIPS_POS: Vector3(0.0, 0.35, 0.05),
		&"Spine": Vector3(5.0, 0.0, 0.0),
		&"Chest": Vector3(0.0, 0.0, 0.0),
		&"Neck": Vector3(-5.0, 0.0, 0.0),
		&"Head": Vector3(-3.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(97.0, 1.0, 2.0),
		&"RightLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"RightFoot": Vector3(12.0, 0.0, 0.0),
		&"RightToes": Vector3(30.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(42.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-96.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-8.0, 0.0, 4.0),
		&"LeftUpperArm": Vector3(36.0, 0.0, -52.0),
		&"LeftLowerArm": Vector3(60.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(24.0, 0.0, 52.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
	})
	var strike_end := PlaceholderPoses.merge(strike, {
		PlaceholderPoses.HIPS_POS: Vector3(0.0, 0.3, 0.05),
		&"RightUpperLeg": Vector3(90.0, 1.0, 2.0),
		&"RightLowerLeg": Vector3(-16.0, 0.0, 0.0),
	})
	var m := PlaceholderPoses._mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = PlaceholderPoses.crouch(g)
	m.follow_at = 0.3
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			_coil_hold())


## The coil sinks a little more through the hold: the knees and the torso go on bending.
static func _coil_hold() -> Dictionary[StringName, Vector3]:
	return {
		&"Spine": Vector3(-4.0, 1.5, 0.0),
		&"Chest": Vector3(-2.0, 2.0, 0.0),
		&"LeftUpperLeg": Vector3(5.0, 0.0, 0.0),
		&"LeftLowerLeg": Vector3(-5.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(5.0, 0.0, 0.0),
		&"RightLowerLeg": Vector3(-5.0, 0.0, 0.0),
	}


## A low sweep: drop to the floor on the left leg, the body turned away to the right, the head on
## the target (held); then spin low with the right leg out along the floor.
static func _sweep(g: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	# Both soles on the floor in every crouched key (PlaceholderAnims plants the lowest one): the
	# support leg folded deep, the right leg straight out to the side down to the floor, the
	# angles worked out so the two feet are level (a side lunge); no explicit HIPS_POS, which
	# would sink or float a foot (codemap G9). HIPS_NUDGE leans the hips into the strike.
	var windup := PlaceholderPoses.merge(g, {
		&"Hips": Vector3(0.0, -70.0, 0.0),
		&"Spine": Vector3(-14.0, 0.0, 0.0),
		&"Chest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(12.0, 58.0, 0.0),
		&"Head": Vector3(4.0, 28.0, 0.0),
		&"LeftUpperLeg": Vector3(75.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-125.0, 0.0, 0.0),
		&"LeftFoot": Vector3(40.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(8.0, 0.0, 62.0),
		&"RightLowerLeg": Vector3(-6.0, 0.0, 0.0),
		&"RightFoot": Vector3(14.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -30.0),
		&"LeftLowerArm": Vector3(60.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-30.0, 0.0, 40.0),
		&"RightLowerArm": Vector3(40.0, 0.0, 0.0),
	})
	var strike := PlaceholderPoses.merge(windup, {
		PlaceholderPoses.HIPS_NUDGE: Vector3(0.0, 0.0, -0.1),
		&"Hips": Vector3(0.0, -270.0, 0.0),
		&"Spine": Vector3(-12.0, -14.0, 6.0),
		&"Chest": Vector3(-4.0, -14.0, 2.0),
		&"UpperChest": Vector3(0.0, -10.0, 0.0),
		&"Neck": Vector3(0.0, -20.0, -4.0),
		&"Head": Vector3(2.0, -18.0, 0.0),
		&"RightUpperLeg": Vector3(4.0, 0.0, 64.0),
		&"RightLowerLeg": Vector3(-4.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(78.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-125.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -34.0),
		&"LeftLowerArm": Vector3(50.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-26.0, 0.0, 32.0),
		&"RightLowerArm": Vector3(60.0, 0.0, 0.0),
	})
	var strike_end := PlaceholderPoses.merge(strike, {
		&"Hips": Vector3(0.0, -320.0, 0.0),
		&"Spine": Vector3(-10.0, -10.0, 6.0),
		&"Chest": Vector3(-4.0, -10.0, 2.0),
		&"Neck": Vector3(0.0, -14.0, -4.0),
		&"Head": Vector3(2.0, -12.0, 0.0),
	})
	var follow := PlaceholderPoses.merge(PlaceholderPoses.crouch(g), {
		&"Hips": Vector3(0.0, -345.0, 0.0),
	})
	var m := PlaceholderPoses._mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = follow
	m.follow_at = 0.4
	m.finish = PlaceholderPoses.merge(g, {&"Hips": Vector3(0.0, -360.0, 0.0)})
	return PlaceholderEnemyPoses.held(m, PlaceholderEnemyPoses.WINDUP_AT, PlaceholderEnemyPoses.WINDUP_HOLD_AT,
			PlaceholderEnemyPoses.tremble())
