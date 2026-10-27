extends RefCounted
## Shared checks for the enemy move tests (not a test script; preload it). Each archetype's
## tests/test_enemy_moves_<archetype>.gd runs these on its moves (M3-plan 2.4, A2.13):
##   check_clip         the clip's length and key timing: a wind-up key in 40-60% of the
##                      startup, the held key at the recipe's windup_hold_at, the strike key at
##                      the startup, a return to the guard
##   check_joint_limits a key pose against the ragdoll's joint limits (PlaceholderBody.
##                      ragdoll_specs(): the upper-arm cone is about 140 degrees of forward
##                      raise, knees -130..0, elbows 0..150): a stagger starts a partial
##                      ragdoll from the pose on screen and the joints snap what is past them
##   measure_reach, check_reach
##                      the flat distance at which the strike touches a standing 1.8 m body,
##                      against the move's reach_m (tolerance REACH_TOLERANCE_M)
##   check_fp_telegraph the wind-up seen through the defender's first-person lens at a
##                      distance: the head shows, the striking hand or foot is in view
## Each check is a pure function returning the problems it found (clip_problems(),
## joint_problems(), reach_problem(), fp_telegraph_problems(): empty = fine), and a check_*()
## wrapper that fails the test with them, so a test of the helper itself can see them fail.
## Enemies are boxer rigs; the target is the player's size. Frames are 1/60 s.

const FPView := preload("res://tests/fp_view.gd")

const FRAME := 1.0 / 60.0
## The standing body a strike is measured against: the player's height, and where the
## attacker's origin is (the origin, facing -Z).
const TARGET_HEIGHT := 1.8
## How far the measured reach may differ from a move's reach_m.
const REACH_TOLERANCE_M := 0.15
## Reach scan: from this far (m) in steps of REACH_STEP_M down to REACH_MIN_M.
const REACH_SCAN_FAR_M := 4.5
const REACH_STEP_M := 0.01
const REACH_MIN_M := 0.2
## Slack on a joint limit (degrees): pose numbers are authored to a degree.
const LIMIT_SLACK_DEG := 1.0
## Mesh names of an enemy's head (cap, hair, face parts): the first-person telegraph keeps
## them visible.
const HEAD_PARTS: Array[String] = ["Head", "Cap", "Hair", "CapBrim", "Shades", "ShadesFront"]
## Mesh part names (after "Left" or "Right") of an arm the lens can see: the elbow end of the
## upper arm, the forearm, the glove, the shoulder cap.
const ARM_PARTS: Array[String] = ["Forearm", "Wrap", "Fist", "Fingers", "Strap", "Hand", "KnuckleWrap",
		"WristWrap", "GloveBack", "Elbow", "UpperArm", "Delt"]


# --- Clips ------------------------------------------------------------------------------


## The clip a boxer `rig` plays for `move`: its length is the move's total frames, it keys the
## strike pose at the startup and the end of the active frames, has a wind-up key at 40-60% of
## the startup (when there is one to speak of), a held key at the recipe's windup_hold_at
## (`require_hold`: it must have one) and ends back in the guard (unless the recipe has its own
## finish pose, a spin).
static func check_clip(t: GutTest, rig: HumanoidRig, move: MoveData, require_hold: bool = true) -> void:
	var problems := clip_problems(rig, move, require_hold)
	t.assert_true(problems.is_empty(), "%s: the clip is sound%s" % [move.get_anim(), _list(problems)])


## What is wrong with the clip `rig` plays for `move` (see check_clip()); empty = nothing.
static func clip_problems(rig: HumanoidRig, move: MoveData, require_hold: bool = true) -> PackedStringArray:
	var problems := PackedStringArray()
	var id := move.get_anim()
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	rig.play_move(move, 0.0)
	var anim := rig.anim_player.get_animation(rig.anim_player.assigned_animation)
	if absf(anim.length - move.total_frames() * FRAME) > 1e-4:
		problems.append("the clip is %.4f s, the move's total frames are %.4f s" % [anim.length, move.total_frames() * FRAME])
	if anim.loop_mode != Animation.LOOP_NONE:
		problems.append("it loops (a move plays once)")
	var track := anim.find_track(^"Skeleton3D:RightUpperArm", Animation.TYPE_ROTATION_3D)
	if track < 0:
		problems.append("no right upper arm track")
		return problems
	var strike_t := move.startup * FRAME
	var end_t := (move.startup + move.active) * FRAME
	if anim.track_find_key(track, strike_t, Animation.FIND_MODE_APPROX) < 0:
		problems.append("no strike key at startup / 60 s")
	if anim.track_find_key(track, end_t, Animation.FIND_MODE_APPROX) < 0:
		problems.append("no key at the end of the active frames")
	var poses := PlaceholderPoses.move_poses(id)
	if move.startup > 1:
		var windup_t := PlaceholderAnims.windup_time(move, poses)
		if windup_t < strike_t * 0.4 - 1e-4 or windup_t > strike_t * 0.6 + 1e-4:
			problems.append("the wind-up key is at %.0f%% of the startup, not 40-60%%" % (100.0 * windup_t / strike_t))
		if anim.track_find_key(track, windup_t, Animation.FIND_MODE_APPROX) < 0:
			problems.append("no wind-up key")
		var hold_t := PlaceholderAnims.windup_hold_time(move, poses)
		if require_hold and hold_t < 0.0:
			problems.append("the recipe does not hold its wind-up (windup_hold_at after the wind-up key)")
		if hold_t >= 0.0 and anim.track_find_key(track, hold_t, Animation.FIND_MODE_APPROX) < 0:
			problems.append("no held key at windup_hold_at x startup")
	if poses.finish.is_empty():
		for bone: StringName in PlaceholderAnims.animated_bones():
			var bone_track := anim.find_track(NodePath("Skeleton3D:%s" % bone), Animation.TYPE_ROTATION_3D)
			var start := anim.rotation_track_interpolate(bone_track, 0.0)
			var finish := anim.rotation_track_interpolate(bone_track, anim.length)
			if rad_to_deg(start.angle_to(finish)) >= 0.5:
				problems.append("%s does not return to the guard" % bone)
	return problems


## `pose` (bone -> Euler degrees, as PlaceholderPoses builds it) against the ragdoll joint
## limits: every cone joint's bone axis within the cone's swing span of its center (the
## upper-arm cone is why a forward raise past about 140 degrees is out), every hinge (elbows,
## knees, ankles) within its lower and upper angle about X. `label` names the pose.
static func check_joint_limits(t: GutTest, pose: Dictionary[StringName, Vector3], label: String = "") -> void:
	var problems := joint_problems(pose)
	t.assert_true(problems.is_empty(), "%s: inside the ragdoll's joint limits%s" % [label, _list(problems)])


## The joints of `pose` that are past the ragdoll's limits (see check_joint_limits()).
static func joint_problems(pose: Dictionary[StringName, Vector3]) -> PackedStringArray:
	var problems := PackedStringArray()
	for spec: PlaceholderBody.RagdollSpec in PlaceholderBody.ragdoll_specs():
		if not pose.has(spec.bone):
			continue
		var euler: Vector3 = pose[spec.bone]
		if spec.joint == PlaceholderBody.RagdollJoint.HINGE:
			if euler.x < spec.lower_deg - LIMIT_SLACK_DEG or euler.x > spec.upper_deg + LIMIT_SLACK_DEG:
				problems.append("%s bends %.0f deg, its limits are %.0f..%.0f" % [spec.bone, euler.x, spec.lower_deg, spec.upper_deg])
		elif spec.joint == PlaceholderBody.RagdollJoint.CONE:
			var off := rad_to_deg((PlaceholderBody.euler_basis(euler) * spec.axis).angle_to(spec.center))
			if off > spec.swing_deg + LIMIT_SLACK_DEG:
				problems.append("%s swings %.0f deg off its cone's center, the limit is %.0f" % [spec.bone, off, spec.swing_deg])
	return problems


## check_joint_limits() on every key pose of `move`'s recipe: the wind-up, its held key, the
## strike, its end, the follow-through and the finish.
static func check_recipe_joint_limits(t: GutTest, move: MoveData) -> void:
	var poses := PlaceholderPoses.move_poses(move.get_anim())
	if poses == null:
		t.fail_test("%s has no recipe" % move.get_anim())
		return
	var id := String(move.get_anim())
	check_joint_limits(t, poses.windup, id + " wind-up")
	if poses.windup_hold_at >= 0.0:
		check_joint_limits(t, PlaceholderPoses.add(poses.windup, poses.windup_hold), id + " held wind-up")
	check_joint_limits(t, poses.strike, id + " strike")
	if not poses.strike_end.is_empty():
		check_joint_limits(t, poses.strike_end, id + " strike end")
	if not poses.follow.is_empty():
		check_joint_limits(t, poses.follow, id + " follow-through")
	if not poses.finish.is_empty():
		check_joint_limits(t, poses.finish, id + " finish")


# --- Reach ------------------------------------------------------------------------------


## The flat distance (m) from an attacker's origin, a boxer rig `rig_height` tall facing -Z,
## to the origin of a standing 1.8 m body facing it, out to which the move's strike touches
## that body on any active frame (a point sphere against the region hurtboxes, an arc as
## HitDetector tests it), plus the move's travel (free_lunge, applied during the strike). 0
## when it never touches. `host` is where the scratch rigs live (the root when null).
static func measure_reach(rig_height: float, move: MoveData, host: Node = null) -> float:
	var parent := host if host else (Engine.get_main_loop() as SceneTree).root
	var scene := Node3D.new()
	parent.add_child(scene)
	var attacker := _boxer(scene, rig_height)
	var target := _boxer(scene, TARGET_HEIGHT)
	target.rotation = Vector3(0.0, PI, 0.0)
	target.play(&"idle", 0.0)
	target.advance(0.0)
	attacker.play(&"idle", 0.0)
	attacker.advance(0.5)
	attacker.play_move(move, 0.0)
	for i: int in move.startup:
		attacker.advance(FRAME)
	# The strike's volumes on every active frame (the attacker never moves).
	var spheres: Array[Dictionary] = []
	for f: int in maxi(move.active, 1):
		if f > 0:
			attacker.advance(FRAME)
		for spec: HitboxSpec in move.hitboxes:
			if spec.kind == HitboxSpec.Kind.POINT_SPHERE:
				spheres.append({center = attacker.get_point_transform(spec.point) * spec.offset, radius = spec.radius})
	var reach := 0.0
	var d := REACH_SCAN_FAR_M
	while d >= REACH_MIN_M:
		target.position = Vector3(0.0, 0.0, -d)
		var touched := false
		for sphere: Dictionary in spheres:
			touched = touched or _sphere_touches(target, sphere.center, sphere.radius)
		for spec: HitboxSpec in move.hitboxes:
			if spec.kind == HitboxSpec.Kind.ARC:
				touched = touched or _arc_touches(target, attacker, spec)
		if touched:
			reach = d
			break
		d -= REACH_STEP_M
	scene.free()
	return reach + (move.free_lunge if reach > 0.0 else 0.0)


## measure_reach() agrees with the move's reach_m within REACH_TOLERANCE_M.
static func check_reach(t: GutTest, move: MoveData, rig_height: float, host: Node = null) -> void:
	var problem := reach_problem(move, rig_height, host)
	t.assert_eq(problem, "", "%s: its reach_m is the strike's reach" % move.get_anim())


## "" when the measured reach agrees with `move.reach_m` (within REACH_TOLERANCE_M), else why not.
static func reach_problem(move: MoveData, rig_height: float, host: Node = null) -> String:
	var measured := measure_reach(rig_height, move, host)
	if measured <= 0.0:
		return "the strike never touches a standing body"
	if absf(measured - move.reach_m) > REACH_TOLERANCE_M:
		return "measured reach %.2f m (travel %.2f m included) against reach_m %.2f m" % [measured, move.free_lunge, move.reach_m]
	return ""


# --- First-person telegraph ---------------------------------------------------------------


## The wind-up of `move` (a boxer `rig_height` tall) seen through the first-person lens of a
## player standing `distance_m` away and looking at it: on every frame up to the held key the
## enemy's head shows (its own raised arm does not hide the face: at least 90% of what its head would
## show with the arms taken away), and at the held key (the wind-up key without one) the
## striking hand or foot is in the view (a move with no point hitbox has none to find).
static func check_fp_telegraph(t: GutTest, move: MoveData, rig_height: float, distance_m: float) -> void:
	var problems := fp_telegraph_problems(move, rig_height, distance_m, t)
	t.assert_true(problems.is_empty(), "%s: the wind-up reads from %.1f m%s" % [move.get_anim(), distance_m, _list(problems)])


## What hides the wind-up of `move` from the first-person lens (see check_fp_telegraph()); the
## scratch rigs live under `host` (the root when null) and are freed before it returns.
static func fp_telegraph_problems(move: MoveData, rig_height: float, distance_m: float, host: Node = null) -> PackedStringArray:
	var problems := PackedStringArray()
	var parent := host if host else (Engine.get_main_loop() as SceneTree).root
	var scene := Node3D.new()
	parent.add_child(scene)
	var player := HumanoidRig.new()
	var dresser := PlayerCharacter.new()
	dresser._configure_rig(player)
	dresser.free()
	scene.add_child(player)
	player.build()
	player.play(&"idle", 0.0)
	player.advance(0.0)
	var facing := player.global_basis.orthonormalized()
	var cam := Transform3D(facing, player.get_point_position(&"EyePoint") + FirstPersonCamera.lens_offset(facing))
	var enemy := _boxer(scene, rig_height)
	enemy.position = Vector3(0.0, 0.0, -distance_m)
	enemy.rotation = Vector3(0.0, PI, 0.0)
	enemy.play(&"idle", 0.0)
	enemy.advance(0.5)
	var poses := PlaceholderPoses.move_poses(move.get_anim())
	var look_at_t := PlaceholderAnims.windup_hold_time(move, poses)
	if look_at_t < 0.0:
		look_at_t = PlaceholderAnims.windup_time(move, poses)
	var look_at_frame := roundi(look_at_t / FRAME)
	var striker := &""
	for spec: HitboxSpec in move.hitboxes:
		if spec.kind == HitboxSpec.Kind.POINT_SPHERE:
			striker = spec.point
			break
	enemy.play_move(move, 0.0)
	# The telegraph: from the start to the held key. After it the strike drives in (at the
	# last startup frame the fist is in front of the face, as it must be).
	for f: int in clampi(look_at_frame, 1, move.startup):
		enemy.advance(FRAME)
		var seen := FPView.hits(scene, cam)
		var bare := FPView.hits(scene, cam, FPView.COLS, _arm_meshes(enemy))
		var head := _share_of(seen, enemy, HEAD_PARTS)
		var whole := _share_of(bare, enemy, HEAD_PARTS)
		if whole <= 0.0:
			problems.append("startup frame %d: the head is not in the view" % (f + 1))
		elif head < whole * 0.9:
			problems.append("startup frame %d: the raised arm hides the face (%.2f%% of the view, %.2f%% bare)" % [
					f + 1, head * 100.0, whole * 100.0])
		if f + 1 == look_at_frame and striker != &"":
			var q := cam.affine_inverse() * enemy.get_point_position(striker)
			var depth := -q.z
			var view := Vector2(rad_to_deg(atan2(q.x, depth)), rad_to_deg(atan2(q.y, depth)))
			if depth <= FPView.NEAR or absf(view.x) >= FPView.HALF_H_DEG or absf(view.y) >= FPView.HALF_V_DEG:
				problems.append("the striking %s is out of the view at the held wind-up (angles %s, depth %.2f)" % [striker, view, depth])
	scene.free()
	return problems


# --- Helpers ------------------------------------------------------------------------------


## A boxer rig (an enemy's look) `height` tall under `parent`, built.
static func _boxer(parent: Node, height: float) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = height
	parent.add_child(rig)
	rig.build()
	return rig


## Whether a sphere at world `center` with `radius` touches any of `target`'s hurtboxes.
static func _sphere_touches(target: HumanoidRig, center: Vector3, radius: float) -> bool:
	for hurtbox: Hurtbox in target.get_hurtboxes():
		var shape := (hurtbox.get_child(0) as CollisionShape3D).shape
		var xf := hurtbox.global_transform
		var dist := xf.origin.distance_to(center)
		if shape is CapsuleShape3D:
			var capsule := shape as CapsuleShape3D
			var half := capsule.height * 0.5 - capsule.radius
			var a := xf * Vector3(0.0, -half, 0.0)
			var b := xf * Vector3(0.0, half, 0.0)
			dist = Geometry3D.get_closest_point_to_segment(center, a, b).distance_to(center)
		if dist < hurtbox.radius + radius:
			return true
	return false


## Whether an ARC hitbox of `attacker` (at the origin, facing -Z) reaches any of `target`'s
## hurtboxes, with the conditions of HitDetector._query_arc().
static func _arc_touches(target: HumanoidRig, attacker: HumanoidRig, spec: HitboxSpec) -> bool:
	var origin := attacker.global_position
	var forward := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(spec.arc_center_yaw_deg))
	for hurtbox: Hurtbox in target.get_hurtboxes():
		var rel := hurtbox.global_position - origin
		var flat := Vector3(rel.x, 0.0, rel.z)
		var dist := flat.length()
		if dist > spec.arc_radius + hurtbox.radius:
			continue
		if rel.y < spec.arc_height.x - hurtbox.radius or rel.y > spec.arc_height.y + hurtbox.radius:
			continue
		if dist > 0.05:
			var angle := rad_to_deg(forward.angle_to(flat / dist))
			if angle > spec.arc_half_angle_deg + rad_to_deg(atan2(hurtbox.radius, dist)):
				continue
		return true
	return false


## Share of the first-person view (cells from FPView.hits()) whose nearest mesh is one of
## `rig`'s parts in `names`.
static func _share_of(cells: Array[MeshInstance3D], rig: HumanoidRig, names: Array[String]) -> float:
	return FPView.share(cells, func(m: MeshInstance3D) -> bool: return rig.is_ancestor_of(m) and names.has(String(m.name)))


## Every arm mesh of `rig` (the elbow end of the upper arm, the forearm and the glove), to
## take away and see what its head shows without them.
static func _arm_meshes(rig: HumanoidRig) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in FPView.meshes_under(rig):
		var part := String(mesh.name)
		for side: String in ["Left", "Right"]:
			if ARM_PARTS.has(part.trim_prefix(side)) and part.begins_with(side):
				out.append(mesh)
	return out


## " (a; b)" for a failure message, "" when there are no problems.
static func _list(problems: PackedStringArray) -> String:
	return "" if problems.is_empty() else " (%s)" % "; ".join(problems)
