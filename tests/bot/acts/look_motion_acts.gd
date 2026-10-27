extends RefCounted
## The motion acts of Milestone 4 (F-motion, M4-plan Part A A12 and A20) for the crowd bot
## (tests/bot/crowd_bot.gd): the Street Punk in motion at 1 m as the lens sees it, so the polish of the
## placeholder clips (the idle's breathing and bounce, the planted walks, the overlapping flinches, the
## get-ups) is judged at 12 fps from the same frames before and after:
##   CAPTURE_ARGS="--tune=look_motion_polish=0" tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/m1_before "Look: motion idle" 12
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/m1 "Look: motion idle" 12
## (Tuning's Debug value look_motion_polish builds the Milestone 3 clips). Record one act per process.
## Every act uses look_acts.gd's steps (the caption off, the AI frozen, god mode, the effects seeded) and
## prints its marks and rectangles through look_rect.gd. All motion is scripted: the Punk is taken off the
## physics tick and its rig is played by hand, with the speeds the game plays it at (a walk plays at
## speed / move_speed, as EnemyActor does).
##
## | Act | Title | Shows |
## | C12 | Look: extremes | the poses the skin is pushed to, each held and turned once round at 1 m: the guard, the elbow at 150 degrees, the arm raised 140, a knee at -130, the spine twisted, a deep knee bend, the hold's knee, the KO and the downed lying poses |
## | M1 | Look: motion idle | the Punk's idle at 1 m, 8 s (two breaths: the chest, the bounce, the weight shift, the head) at the default look, then 4 s of the face |
## | M2 | Look: motion walks | the Punk walks away from the lens and back, then round it to the right and back to the left, at the circling pace, then one quick step in at the approach pace |
## | M3 | Look: motion flinches | the five flinches in turn (head front, left, right, gut, legs), each from the idle |
## | M4 | Look: motion get-ups | the Punk knocked down backward and forward, lying through two breaths and getting up, then the taunt |
##
## C12's slug is c12 (L0-bench's plan: C1 to C11 and C13 are look_acts.gd's); the motion acts' are m1 to m4.

const LookRect := preload("res://tests/bot/look_rect.gd")
const LookActs := preload("res://tests/bot/acts/look_acts.gd")

## The distance the Punk stands at (m ahead), and the pitch of the view (degrees, negative looks down)
## for a standing body, a face, and a body lying on the floor.
const CLOSE_M := 1.0
const BODY_PITCH_DEG := -6.0
const FACE_PITCH_DEG := 8.0
const LYING_PITCH_DEG := -40.0
## The look down at a bent leg (the knees are half a metre up, a metre ahead of an eye at 1.65 m).
const LEGS_PITCH_DEG := -30.0
## The walks' look: down enough that the feet come into the view at 1.5 m and more.
const WALK_PITCH_DEG := -25.0
const PITCH_TICKS := 10
const SETTLE_TICKS := 30
## C12: how long a pose is held before it turns, and how long the turn is (a full circle).
const HOLD_TICKS := 40
const TURN_MARKS := 4
const QUARTER_TICKS := 60
## The idle act: the body and the face are held this long (ticks); a mark every second.
const IDLE_BODY_TICKS := 480
const IDLE_FACE_TICKS := 240
const MARK_GAP_TICKS := 60
## The walks: the distances (m ahead of the player) of the radial walk, the arc (degrees) of the
## strafes, the pause between them (ticks), and the approach's start (m).
const WALK_NEAR_M := 1.0
const WALK_FAR_M := 1.9
const STRAFE_DEG := 40.0
const WALK_PAUSE_TICKS := 40
const APPROACH_FROM_M := 2.0
## The flinches: the clips (a Punk stands still between them) and the rest after each (ticks).
const FLINCHES: Array[StringName] = [
	&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut", &"flinch_legs",
]
const FLINCH_REST_TICKS := 90
const FLINCH_BLEND_S := 0.05
## The get-ups: the falls, how long each body lies (ticks: two breaths of the downed loop, 4 s each),
## and how long the taunt and the stand after it are watched.
const FALLS: Array[Dictionary] = [
	{fall = &"knockdown_back", getup = &"getup_back", lying = &"downed_back"},
	{fall = &"knockdown_forward", getup = &"getup_front", lying = &"downed_front"},
]
const LYING_TICKS := 480
const FALL_TICKS := 60
const STAND_TICKS := 60
const GETUP_BLEND_S := 0.05


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: extremes", cam = &"first_person", slug = &"c12", fn = func() -> void: await _extremes(bot)},
		{title = "Look: motion idle", cam = &"first_person", slug = &"m1", fn = func() -> void: await _idle(bot)},
		{title = "Look: motion walks", cam = &"first_person", slug = &"m2", fn = func() -> void: await _walks(bot)},
		{title = "Look: motion flinches", cam = &"first_person", slug = &"m3", fn = func() -> void: await _flinches(bot)},
		{title = "Look: motion get-ups", cam = &"first_person", slug = &"m4", fn = func() -> void: await _getups(bot)},
	]


# --- C12: the extremes -------------------------------------------------------------------------


## The poses of C12: `{label, pose (bone -> Euler degrees), hips (offset), pitch}`. The first six are the
## strain test's peak flexes (tests/test_art_punk.gd, M4-plan A19), then a deep knee bend, the hold's
## knee and the four lying poses. A pose without a hips offset is planted (PlaceholderAnims.resolve_hips()).
static func extremes() -> Array[Dictionary]:
	var guard := PlaceholderPoses.guard()
	var out: Array[Dictionary] = []
	out.append({label = "guard", pose = guard, pitch = BODY_PITCH_DEG})
	out.append({label = "elbow_150", pose = _p({&"LeftLowerArm": Vector3(150.0, 0.0, 0.0), &"RightLowerArm": Vector3(150.0, 0.0, 0.0)}),
			pitch = BODY_PITCH_DEG})
	out.append({label = "arm_raise_140", pose = _p({&"LeftUpperArm": Vector3(140.0, 0.0, 0.0), &"RightUpperArm": Vector3(140.0, 0.0, 0.0)}),
			pitch = BODY_PITCH_DEG})
	out.append({label = "knee_130", pose = _p({&"LeftLowerLeg": Vector3(-130.0, 0.0, 0.0), &"LeftUpperLeg": Vector3(40.0, 0.0, 0.0)}),
			pitch = LEGS_PITCH_DEG})
	out.append({label = "spine_twist", pose = _p({&"Spine": Vector3(0.0, 25.0, 0.0), &"Chest": Vector3(0.0, 25.0, 0.0),
			&"UpperChest": Vector3(0.0, 20.0, 0.0), &"Neck": Vector3(0.0, 20.0, 0.0), &"Head": Vector3(0.0, 30.0, 0.0)}),
			pitch = BODY_PITCH_DEG})
	out.append({label = "deep_knee_bend", pose = PlaceholderPoses.merge(guard, {
			&"Spine": Vector3(-25.0, 0.0, 0.0), &"Neck": Vector3(18.0, 0.0, 0.0),
			&"LeftUpperLeg": Vector3(75.0, 0.0, -6.0), &"LeftLowerLeg": Vector3(-130.0, 0.0, 0.0), &"LeftFoot": Vector3(55.0, 0.0, 6.0),
			&"RightUpperLeg": Vector3(70.0, 0.0, 6.0), &"RightLowerLeg": Vector3(-130.0, 0.0, 0.0), &"RightFoot": Vector3(55.0, 0.0, -6.0)}),
			pitch = LEGS_PITCH_DEG})
	var knee := PlaceholderPoses.move_poses(&"knee")
	if knee != null:
		out.append({label = "hold_knee", pose = knee.strike, pitch = LEGS_PITCH_DEG})
	out.append({label = "ko_back", pose = PlaceholderPoses.ko_back(), pitch = LYING_PITCH_DEG})
	out.append({label = "ko_front", pose = PlaceholderPoses.ko_front(), pitch = LYING_PITCH_DEG})
	out.append({label = "downed_back", pose = PlaceholderPoses.downed_back(), pitch = LYING_PITCH_DEG})
	out.append({label = "downed_front", pose = PlaceholderPoses.downed_front(), pitch = LYING_PITCH_DEG})
	return out


## A guard-less pose from `angles`.
static func _p(angles: Dictionary) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = {}
	for bone: StringName in angles:
		out[bone] = angles[bone]
	return out


## Show `pose` on `rig` as it is: every bone's rotation and the hips' height, the skin drawn on it.
## The rig is not advanced afterwards (the animation would take the pose over again).
static func hold(rig: HumanoidRig, pose: Dictionary[StringName, Vector3]) -> void:
	var skeleton := rig.skeleton
	var hips := PlaceholderAnims.resolve_hips(pose)
	for i: int in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		skeleton.set_bone_pose_rotation(i, PlaceholderBody.euler_basis(pose.get(bone, Vector3.ZERO)).get_rotation_quaternion())
		if bone == &"Hips":
			skeleton.set_bone_pose_position(i, (PlaceholderBody.BONE_REST[&"Hips"] + hips) * rig.rig_scale())
	skeleton.advance(0.0)


## Each extreme held, then turned once round (the Punk turns, the view stays): marks at the start and
## every quarter turn, with the Punk's rectangles.
static func _extremes(bot: Node) -> void:
	LookActs._begin(bot)
	var punk := LookActs._punk(bot, Vector2(0.0, CLOSE_M))
	await bot._look_to(BODY_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c12", "start")
	LookActs._unplug(punk)
	var facing := punk.rotation.y
	var pitch := BODY_PITCH_DEG
	for row: Dictionary in extremes():
		if not is_equal_approx(float(row.pitch), pitch):
			pitch = row.pitch
			await bot._look_to(pitch, PITCH_TICKS)
		punk.rotation.y = facing
		hold(punk.rig, row.pose)
		await bot._ticks(HOLD_TICKS)
		for quarter in TURN_MARKS:
			LookRect.mark(bot, "c12", "%s_%d" % [row.label, quarter * 90], punk)
			for i in QUARTER_TICKS:
				var turned := (float(quarter) + float(i) / QUARTER_TICKS) / TURN_MARKS
				punk.rotation.y = facing + TAU * turned
				await bot._ticks(1)
	_end(bot)


# --- M1: the idle ------------------------------------------------------------------------------


static func _idle(bot: Node) -> void:
	LookActs._begin(bot)
	var punk := LookActs._punk(bot, Vector2(0.0, CLOSE_M))
	await bot._look_to(BODY_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "m1", "start")
	await LookActs._idle_marks(bot, "m1", punk, IDLE_BODY_TICKS, "body")
	await bot._look_to(FACE_PITCH_DEG, PITCH_TICKS)
	await LookActs._idle_marks(bot, "m1", punk, IDLE_FACE_TICKS, "face")
	LookRect.mark(bot, "m1", "end")
	bot.caption.visible = true


# --- M2: the walks -----------------------------------------------------------------------------


## The Punk walks away from the lens along the line to it and back (it faces the player: backing away,
## then walking in), then round the player to the right and back (a strafe each way), at the circling
## pace; the view follows it. Then one step in from APPROACH_FROM_M at the approach pace. The Punk's rig is
## played with the speed it would have: play_locomotion(local move, speed / move_speed).
static func _walks(bot: Node) -> void:
	LookActs._begin(bot)
	var heading: float = bot.player.look_yaw
	var punk := LookActs._punk(bot, Vector2(0.0, WALK_NEAR_M))
	await bot._look_to(WALK_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "m2", "start")
	LookActs._unplug(punk)
	var pace: float = Tuning.data.posture_circle_speed_mps
	# Away and back along the line.
	await _hold_still(bot, punk, LookActs._ring(bot, heading, 0.0, WALK_NEAR_M), WALK_PAUSE_TICKS)
	LookRect.mark(bot, "m2", "back_away_start", punk)
	await _walk_line(bot, "m2", "back_away", punk, heading, 0.0, WALK_NEAR_M, WALK_FAR_M, pace)
	await _hold_still(bot, punk, LookActs._ring(bot, heading, 0.0, WALK_FAR_M), WALK_PAUSE_TICKS)
	await _walk_line(bot, "m2", "walk_in", punk, heading, 0.0, WALK_FAR_M, WALK_NEAR_M, pace)
	await _hold_still(bot, punk, LookActs._ring(bot, heading, 0.0, WALK_NEAR_M), WALK_PAUSE_TICKS)
	# Round the player: to the right (negative bearing), then back.
	var arc := deg_to_rad(STRAFE_DEG)
	await _walk_arc(bot, "m2", "strafe_right", punk, heading, 0.0, -arc, WALK_NEAR_M, pace)
	await _hold_still(bot, punk, LookActs._ring(bot, heading, -arc, WALK_NEAR_M), WALK_PAUSE_TICKS)
	await _walk_arc(bot, "m2", "strafe_left", punk, heading, -arc, arc, WALK_NEAR_M, pace)
	await _hold_still(bot, punk, LookActs._ring(bot, heading, arc, WALK_NEAR_M), WALK_PAUSE_TICKS)
	await _walk_arc(bot, "m2", "strafe_back", punk, heading, arc, 0.0, WALK_NEAR_M, pace)
	await _hold_still(bot, punk, LookActs._ring(bot, heading, 0.0, WALK_NEAR_M), WALK_PAUSE_TICKS)
	# The approach pace: from APPROACH_FROM_M in to the near mark.
	await _hold_still(bot, punk, LookActs._ring(bot, heading, 0.0, APPROACH_FROM_M), WALK_PAUSE_TICKS)
	await _walk_line(bot, "m2", "approach", punk, heading, 0.0, APPROACH_FROM_M, WALK_NEAR_M, Tuning.data.approach_speed_mps)
	await _hold_still(bot, punk, LookActs._ring(bot, heading, 0.0, WALK_NEAR_M), WALK_PAUSE_TICKS)
	LookRect.mark(bot, "m2", "end")
	bot.caption.visible = true


## `ticks` of the Punk standing at `at` facing the player.
static func _hold_still(bot: Node, punk: CombatActor, at: Vector3, ticks: int) -> void:
	for i in ticks:
		LookActs._pose(punk, at, bot.player.global_position)
		await bot._ticks(1)


## A walk along the line to the player, from `from_m` to `to_m` away at `speed` m/s, the Punk facing the
## player (it backs away or walks in), with a mark at each third.
static func _walk_line(bot: Node, slug: String, label: String, punk: CombatActor, heading: float, bearing: float,
		from_m: float, to_m: float, speed: float) -> void:
	var ticks := ceili(absf(to_m - from_m) / speed * Engine.physics_ticks_per_second)
	for i in ticks + 1:
		if i % maxi(ticks / 3, 1) == 0:
			LookRect.mark(bot, slug, "%s_%d" % [label, i], punk)
		var radius := lerpf(from_m, to_m, float(i) / ticks)
		LookActs._pose(punk, LookActs._ring(bot, heading, bearing, radius), bot.player.global_position)
		await bot._ticks(1)


## A walk round the player at `radius` m from `from_bearing` to `to_bearing` (radians) at `speed` m/s
## along the circle, the view following, a mark at each third.
static func _walk_arc(bot: Node, slug: String, label: String, punk: CombatActor, heading: float,
		from_bearing: float, to_bearing: float, radius: float, speed: float) -> void:
	var length := absf(to_bearing - from_bearing) * radius
	var ticks := ceili(length / speed * Engine.physics_ticks_per_second)
	for i in ticks + 1:
		if i % maxi(ticks / 3, 1) == 0:
			LookRect.mark(bot, slug, "%s_%d" % [label, i], punk)
		var at := LookActs._ring(bot, heading, lerpf(from_bearing, to_bearing, float(i) / ticks), radius)
		LookActs._pose(punk, at, bot.player.global_position)
		LookActs._follow(bot, at, LookActs.FOLLOW_DEG_PER_S)
		await bot._ticks(1)


# --- M3: the flinches --------------------------------------------------------------------------


## Each flinch played from the idle (the way the game starts it: a blend into the clip), the Punk
## standing still between them. The marks are the strike's frame, the held pose and the recovery.
static func _flinches(bot: Node) -> void:
	LookActs._begin(bot)
	var punk := LookActs._punk(bot, Vector2(0.0, CLOSE_M))
	await bot._look_to(BODY_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "m3", "start")
	LookActs._unplug(punk)
	var dt := 1.0 / Engine.physics_ticks_per_second
	for clip: StringName in FLINCHES:
		for i in FLINCH_REST_TICKS / 2:
			punk.rig.advance(dt)
			await bot._ticks(1)
		punk.rig.play(clip, FLINCH_BLEND_S)
		var ticks := ceili(punk.rig.anim_player.get_animation(clip).length / dt) + 6
		for i in ticks:
			if i == 0 or i == 4 or i == 8 or i == 12:
				LookRect.mark(bot, "m3", "%s_f%02d" % [clip, i], punk)
			punk.rig.advance(dt)
			await bot._ticks(1)
		punk.rig.play(&"idle", FLINCH_BLEND_S)
		for i in FLINCH_REST_TICKS / 2:
			punk.rig.advance(dt)
			await bot._ticks(1)
	LookRect.mark(bot, "m3", "end")
	bot.caption.visible = true


# --- M4: the get-ups ---------------------------------------------------------------------------


## The Punk knocked down backward and forward: the fall, the body lying through two breaths (the downed
## loop), the get-up and the stand; then the taunt. The view looks down at the floor for the lying body.
static func _getups(bot: Node) -> void:
	LookActs._begin(bot)
	var punk := LookActs._punk(bot, Vector2(0.0, CLOSE_M))
	await bot._look_to(LYING_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "m4", "start")
	LookActs._unplug(punk)
	var dt := 1.0 / Engine.physics_ticks_per_second
	for row: Dictionary in FALLS:
		punk.rig.play(row.fall, 0.0)
		for i in FALL_TICKS:
			if i == 10 or i == 20:
				LookRect.mark(bot, "m4", "%s_f%02d" % [row.fall, i], punk)
			punk.rig.advance(dt)
			await bot._ticks(1)
		punk.rig.play(row.lying, FLINCH_BLEND_S)
		for i in LYING_TICKS:
			if i % MARK_GAP_TICKS == 0:
				LookRect.mark(bot, "m4", "%s_t%03d" % [row.lying, i], punk)
			punk.rig.advance(dt)
			await bot._ticks(1)
		punk.rig.play(row.getup, GETUP_BLEND_S)
		var ticks := ceili(punk.rig.anim_player.get_animation(row.getup).length / dt) + STAND_TICKS
		for i in ticks:
			if i % 8 == 0 and i < 40:
				LookRect.mark(bot, "m4", "%s_f%02d" % [row.getup, i], punk)
			punk.rig.advance(dt)
			await bot._ticks(1)
		punk.rig.play(&"idle", GETUP_BLEND_S)
		for i in STAND_TICKS:
			punk.rig.advance(dt)
			await bot._ticks(1)
	await bot._look_to(BODY_PITCH_DEG, PITCH_TICKS)
	punk.rig.play(&"taunt", GETUP_BLEND_S)
	var taunt_ticks := ceili(punk.rig.anim_player.get_animation(&"taunt").length / dt) + STAND_TICKS
	for i in taunt_ticks:
		if i % 20 == 0:
			LookRect.mark(bot, "m4", "taunt_f%03d" % i, punk)
		punk.rig.advance(dt)
		await bot._ticks(1)
	LookRect.mark(bot, "m4", "end")
	bot.caption.visible = true


static func _end(bot: Node) -> void:
	LookRect.mark(bot, "c12", "end")
	bot.caption.visible = true
