extends GutTest
## The player's straight punches turn the fist over (M4 call 28, Game-boy's own request on 2026-11-02: "When the player throws a
## straight punch, the fist should turn 90 degrees so that the curled fingers angle down toward the ground (rather than inward toward
## each other)"). M3's jab and cross (PlaceholderPoses jab_1, the left, and jab_2, the right) left the fist standing on its edge at
## contact, thumb up, the bare fingers curled inward at the other hand. They are now a corkscrew: over the punch the fist rolls about
## the forearm's own axis, split between the lower arm and the hand, so at contact it lands palm down, the curled fingers under it.
##
## What these tests hold (the poses are pure math, `PlaceholderBody.pose_globals()`, and the clips are the ones the rig plays):
## - the M3 poses are the twin: at their strike keys the palm faces the midline and the fingers curl inward, and every rule below
##   fails on them;
## - at the strike key each fist's palm (and so the curled fingers, measured from the hero's own fist mesh) faces the ground;
## - the wind-up is barely turned, so the fist really turns over the punch;
## - the fist point, the hitbox, is where it was at every key (1 cm, A20), and no extra key is made by the turn (the roll is slerped);
## - the hero's skinned forearm and wrist do not candy-wrap (the roll is split, and a roll all in the hand is the twin that does);
## - the Street Punk's cross and the sparring dummy's jab, which reuse these strikes, are not turned (A20).
##
## How "palm down" is bounded. The forearm is not level at contact: it rises 34 degrees in the jab and 36 in the cross (a low elbow
## and a head-high target), so a straight wrist's palm normal cannot be nearer straight down than that. Bending the wrist to get
## nearer would move the fist point by more than the centimetre the hits allow. So the palm is held to two bars: as far down as the
## forearm lets it be (ROLL_ERROR_MAX_DEG, the roll left over), and within PALM_DOWN_MAX_DEG of straight down.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")
const ArtStrain := preload("res://tests/art_strain.gd")
const MotionProbe := preload("res://tests/fixtures/motion/motion_probe.gd")

const PLAYER_ART := "res://game/actors/art/player_art.tres"
## The hero's bare skin, in the shared palette (assets/source/palette/shared.json): the fist's bare fingers are its faces, the
## glove plate on the back of the hand (charcoal, slot 35) and the wrap (cream, slot 14) are not.
const HERO_SKIN_SLOT := 7
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## A hand's faces count as the fist's when at least this much of each corner is on the Hand bind.
const FIST_WEIGHT := 0.9
## The bare fingers sit at least this far (m) off the fist's centre toward the palm side, and the palm side is the one axis they
## favour (the table's frame: toward the midline is +x for the left hand, -x for the right; the bare fingers are the palm side).
const FINGERS_OFFSET_MIN_M := 0.012

## The palm, and with it the curled fingers, is within this many degrees of straight down at the strike key (the bound the forearm's
## rise allows: see the header). M3's poses are at 87-89.
const PALM_DOWN_MAX_DEG := 40.0
## The palm is within this many degrees of the most downward normal the forearm's axis allows: the fist is rolled all the way over.
const ROLL_ERROR_MAX_DEG := 20.0
## The wind-up key's fist is turned at most this many degrees from M3's (about the forearm), and the strike key's by at least
## MIN_STRIKE_TURN_DEG and at most MAX_STRIKE_TURN_DEG: the 90 degrees Game-boy asked for.
const WINDUP_TURN_MAX_DEG := 30.0
const MIN_STRIKE_TURN_DEG := 80.0
const MAX_STRIKE_TURN_DEG := 100.0
## The fist turns over the punch: its roll from the wind-up key to the strike key (the difference of the two turns from M3's) is at
## least this many degrees.
const OVER_THE_PUNCH_MIN_DEG := 55.0
## A20: the fist point stays within this (m) of M3's at every key (the hitbox's centimetre)...
const FIST_POINT_MAX_M := 0.01
## ...and within this at every frame of the played clip between the keys, where the lower arm's roll changes (the slerp from the
## guard to the wind-up and on to the strike runs a little off M3's bend); a lower arm rolled only at contact is 3-4 cm off at the
## frame between the wind-up and the strike.
const FIST_FRAME_MAX_M := 0.02
## The roll across the hero's forearm and wrist does not pinch it: in every 3 cm band of the forearm and hand the mean distance of
## the skin from the forearm's axis, over what it is at the table's rest. At the strike frames it is at least PINCH_MIN (M3's pose,
## no roll, 0.96; the split 0.886; the whole roll in the hand, the twin, 0.78), and at every sampled frame no more than
## PINCH_LOSS_MAX under M3's at the same frame (the elbow's own bend at the wind-up pinches M3's to 0.78 already).
const PINCH_MIN := 0.87
const PINCH_LOSS_MAX := 0.1
const PINCH_TWIN_MAX := 0.85
const STRIKE_FRAMES: Array[int] = [4, 6]
const BAND_M := 0.03
## The whole mesh's strain (the A19 measures, tests/art_strain.gd) at the frames sampled is no worse than M3's at the same frames
## by more than this, a ratio on p99.9 and the longest stretch, its inverse on p0.1 and the deepest compression, plus a hair.
const STRAIN_SLACK := 1.02
const FRAMES_SAMPLED: Array[int] = [0, 2, 3, 4, 6, 9, 13, 17]
const FRAME := 1.0 / 60.0

## The M3 arms (YXZ Euler degrees) of the striking arm, wind-up and strike keys: the lower arm is a pure elbow bend and the hand is
## the stance's. The twin of the new poses: the same poses with these arms put back.
const M3_ARMS := {
	&"jab_1": {side = &"Left", windup = 112.0, strike = 33.5},
	&"jab_2": {side = &"Right", windup = 116.0, strike = 39.0},
}
## The moves that reuse the strikes without the turn (A20): the Punk's cross and jab, the sparring dummy's jab.
const UNTURNED := {&"punk_cross": &"Left", &"punk_jab": &"Right", &"dummy_jab": &"Right"}

var _hero_cache: Dictionary = {}
var _fingers_cache: Dictionary[String, Vector3] = {}


## The hero is built once and kept for the whole script: the m6 profile is held for all of it (a live flip would re-dress him).
func before_all() -> void:
	LookProfileHelper.use_m6()


func after_all() -> void:
	if _hero_cache.has("rig") and is_instance_valid(_hero_cache.rig):
		(_hero_cache.rig as HumanoidRig).free()
	_hero_cache.clear()
	LookProfileHelper.restore()


# --- Helpers ---------------------------------------------------------------------------


func _poses(id: StringName, stance: StringName = PlaceholderPoses.STANCE_RELAXED) -> PlaceholderPoses.MovePoses:
	return PlaceholderPoses.move_poses(id, stance)


## `poses` with the striking arm put back as M3 had it (no roll), on a copy.
func _m3_twin(id: StringName, poses: PlaceholderPoses.MovePoses) -> PlaceholderPoses.MovePoses:
	var arm: Dictionary = M3_ARMS[id]
	var lower := StringName(String(arm.side) + "LowerArm")
	var hand := StringName(String(arm.side) + "Hand")
	var twin := PlaceholderPoses.MovePoses.new()
	twin.guard = poses.guard
	twin.windup = poses.windup.duplicate()
	twin.windup_at = poses.windup_at
	twin.strike = poses.strike.duplicate()
	twin.strike_end = poses.strike_end
	twin.follow = poses.follow
	twin.follow_at = poses.follow_at
	twin.finish = poses.finish
	twin.windup[lower] = Vector3(arm.windup, 0.0, 0.0)
	twin.strike[lower] = Vector3(arm.strike, 0.0, 0.0)
	for pose: Dictionary[StringName, Vector3] in [twin.windup, twin.strike]:
		pose[hand] = poses.guard.get(hand, Vector3.ZERO)
	return twin


func _side(id: StringName) -> String:
	return String(M3_ARMS[id].side)


## The table's palm side of `side`'s hand in its own frame (+x toward the midline for the left hand, -x for the right).
func _palm_local(side: String) -> Vector3:
	return Vector3.RIGHT if side == "Left" else Vector3.LEFT


## What a key's hand looks like in the rig's frame: `{palm (the palm side, so the curled fingers), axis (from the wrist to the
## knuckles), basis}`, `hand_local_palm` being the palm side in the hand's own frame.
func _hand(pose: Dictionary[StringName, Vector3], side: String, hand_local_palm: Vector3) -> Dictionary:
	var globals := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)
	var basis: Basis = (globals[StringName(side + "Hand")] as Transform3D).basis
	return {palm = (basis * hand_local_palm).normalized(), axis = (basis * Vector3.DOWN).normalized(), basis = basis}


func _deg_from_down(v: Vector3) -> float:
	return rad_to_deg(v.angle_to(Vector3.DOWN))


## How far (degrees) `palm` is from the most downward normal to `axis`: what is left to roll once the palm is as low as the axis
## lets it be.
func _roll_error_deg(palm: Vector3, axis: Vector3) -> float:
	var ideal := -(Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
	return rad_to_deg(palm.angle_to(ideal))


## How far (degrees) the hand of `pose` is turned from the same bone in `other`: the angle of the rotation between them.
func _turned_deg(pose: Dictionary[StringName, Vector3], other: Dictionary[StringName, Vector3], side: String) -> float:
	var a := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)[StringName(side + "Hand")] as Transform3D
	var b := PlaceholderBody.pose_globals(other, Vector3.ZERO, 1.0)[StringName(side + "Hand")] as Transform3D
	return rad_to_deg((a.basis * b.basis.inverse()).get_rotation_quaternion().get_angle())


func _fist_point(pose: Dictionary[StringName, Vector3], side: String) -> Vector3:
	var hand := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)[StringName(side + "Hand")] as Transform3D
	return hand * (PlaceholderBody.POINT_OFFSET[StringName(side + "FistPoint")] as Vector3)


func _rig() -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = 1.8
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	return rig


func _move(id: StringName) -> MoveData:
	return load("res://game/combat/moves/%s.tres" % id) as MoveData


## The hero's rig, dressed as the player and wearing his art, with the table's rest skinned once per mesh (cached).
func _hero() -> Dictionary:
	if not _hero_cache.is_empty():
		return _hero_cache
	var rig := HumanoidRig.new()
	var dresser := PlayerCharacter.new()
	dresser._configure_rig(rig)
	dresser.free()
	rig.height = 1.8
	rig.build_hurtboxes = false
	rig.art = PlayerCharacter.worn_art(load(PLAYER_ART) as CharacterArt)
	# Kept for every test of this script (add_child_autofree would free it after the first): after_all() frees it.
	add_child(rig)
	rig.build()
	var rest_globals := SkinnedView.rest_pose(rig)
	var meshes := rig.art_meshes()
	var rests: Array[PackedVector3Array] = []
	var masks: Array[PackedByteArray] = []
	var body: MeshInstance3D = null
	for mi: MeshInstance3D in meshes:
		rests.append(SkinnedView.skin_vertices(mi, rig, rest_globals))
		masks.append(ArtStrain.rest_mask(mi, rig))
		if String(mi.name) == "ArtBody":
			body = mi
	_hero_cache = {rig = rig, rest_globals = rest_globals, rests = rests, masks = masks, body = body,
			body_rest = SkinnedView.skin_vertices(body, rig, rest_globals) if body != null else PackedVector3Array()}
	return _hero_cache


## Where the hero's bare fingers sit on `side`'s fist, in the hand's frame at the table's rest: the area-weighted centroid of the
## fist's skin faces minus that of the whole fist (F-fist-turn's measure for the Punk; the hero's skin is slot HERO_SKIN_SLOT).
## Vector3.INF when the fist has none.
func _fingers_offset(side: String) -> Vector3:
	if _fingers_cache.has(side):
		return _fingers_cache[side]
	var offset := _measure_fingers_offset(side)
	_fingers_cache[side] = offset
	return offset


func _measure_fingers_offset(side: String) -> Vector3:
	var hero := _hero()
	var mi: MeshInstance3D = hero.body
	if mi == null:
		return Vector3.INF
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	var rig: HumanoidRig = hero.rig
	var hand_inverse := (hero.rest_globals[rig.skeleton.find_bone(side + "Hand")] as Transform3D).affine_inverse()
	var rest: PackedVector3Array = hero.body_rest
	var on_hand := PackedFloat32Array()
	on_hand.resize(rest.size())
	for v: int in rest.size():
		for e: int in range(data.entry_start[v], data.entry_start[v + 1]):
			if StringName(mi.skin.get_bind_name(data.entry_bind[e])) == StringName(side + "Hand"):
				on_hand[v] += data.entry_weight[e]
	var area := 0.0
	var centroid := Vector3.ZERO
	var skin_area := 0.0
	var skin_centroid := Vector3.ZERO
	for t: int in index.size() / 3:
		var i0 := index[t * 3]
		var i1 := index[t * 3 + 1]
		var i2 := index[t * 3 + 2]
		if on_hand[i0] < FIST_WEIGHT or on_hand[i1] < FIST_WEIGHT or on_hand[i2] < FIST_WEIGHT:
			continue
		var p0 := hand_inverse * rest[i0]
		var p1 := hand_inverse * rest[i1]
		var p2 := hand_inverse * rest[i2]
		var a := (p1 - p0).cross(p2 - p0).length() * 0.5
		var c := (p0 + p1 + p2) / 3.0
		area += a
		centroid += c * a
		var slot := int(floorf(uv[i0].x * float(SWATCH_COLUMNS))) + SWATCH_COLUMNS * int(floorf(uv[i0].y * float(SWATCH_ROWS)))
		if slot == HERO_SKIN_SLOT:
			skin_area += a
			skin_centroid += c * a
	if area < 0.001 or skin_area < 0.0005:
		return Vector3.INF
	return skin_centroid / skin_area - centroid / area


# --- The poses -------------------------------------------------------------------------


func test_the_m3_poses_are_the_twin_the_fist_stands_on_its_edge_with_the_fingers_curled_inward() -> void:
	# The twin fails the rules: at the M3 strike keys the palm faces the midline, 87-89 degrees from down, and the fist is not turned.
	for id: StringName in M3_ARMS:
		for stance: StringName in [PlaceholderPoses.STANCE_RELAXED, PlaceholderPoses.STANCE_BOXER]:
			var side := _side(id)
			var twin := _m3_twin(id, _poses(id, stance))
			var hand := _hand(twin.strike, side, _palm_local(side))
			var toward_midline := (hand.palm as Vector3).x * (1.0 if side == "Left" else -1.0)
			gut.p("M3 %s %s strike: palm %.0f degrees from down, %.2f toward the midline" % [id, stance, _deg_from_down(hand.palm), toward_midline])
			assert_gt(toward_midline, 0.95, "%s %s: M3's palm faces the midline, the fingers curled inward at the other hand" % [id, stance])
			assert_gt(_deg_from_down(hand.palm), 80.0, "%s %s: M3's palm is not down" % [id, stance])
			assert_gt(_roll_error_deg(hand.palm, hand.axis), 50.0, "%s %s: M3's fist is far from rolled over" % [id, stance])


func test_the_hero_fist_curls_its_bare_fingers_to_the_palm_side_toward_the_midline() -> void:
	# What "the curled fingers" are in the art: the hero's bare fingers sit on the palm side, which is the +x side of the left hand
	# and the -x side of the right (A5's palm to the midline), so the palm's direction in the poses above is the fingers' direction.
	for side: String in ["Left", "Right"]:
		var offset := _fingers_offset(side)
		assert_ne(offset, Vector3.INF, "the %s fist has bare fingers (skin faces) on its Hand bind" % side)
		if offset == Vector3.INF:
			continue
		var toward_midline := offset.x * (1.0 if side == "Left" else -1.0)
		gut.p("hero %s fist: the bare fingers sit %+.1f mm toward the midline, %+.1f mm toward the knuckles, %+.1f mm toward the front" % [side, toward_midline * 1000.0, -offset.y * 1000.0, -offset.z * 1000.0])
		assert_gt(toward_midline, FINGERS_OFFSET_MIN_M, "%s: the fingers curl toward the palm side, the midline's, at rest" % side)
		assert_gt(toward_midline, absf(offset.z), "%s: and the palm side is the axis they favour over the front" % side)


func test_at_the_strike_key_each_straight_punch_lands_palm_down_with_the_curled_fingers_toward_the_ground() -> void:
	for id: StringName in M3_ARMS:
		for stance: StringName in [PlaceholderPoses.STANCE_RELAXED, PlaceholderPoses.STANCE_BOXER]:
			for mirrored: bool in [false, true]:
				var poses := _poses(id, stance)
				if mirrored:
					poses = poses.mirrored(true)
				var side := _side(id)
				if mirrored:
					side = "Right" if side == "Left" else "Left"
				# The curled fingers' side, from the art (the hero's bare fingers), carried through the pose; the palm is the same side.
				var offset := _fingers_offset(side)
				assert_ne(offset, Vector3.INF, "%s fist has bare fingers" % side)
				var curl_local := _palm_local(side) if offset == Vector3.INF else Vector3(signf(offset.x), 0.0, 0.0)
				var hand := _hand(poses.strike, side, curl_local)
				var down := _deg_from_down(hand.palm)
				var error := _roll_error_deg(hand.palm, hand.axis)
				gut.p("%s %s%s strike: curled fingers %.1f degrees from straight down, %.1f from the most downward the forearm allows (the forearm rises %.0f)" % [
						id, stance, " mirrored" if mirrored else "", down, error, rad_to_deg(asin((hand.axis as Vector3).y * -1.0))])
				assert_lt(down, PALM_DOWN_MAX_DEG, "%s %s%s: the palm and the curled fingers face the ground (%.1f degrees from down)" % [id, stance, " mirrored" if mirrored else "", down])
				assert_lt(error, ROLL_ERROR_MAX_DEG, "%s %s%s: rolled all the way over (%.1f degrees left to roll)" % [id, stance, " mirrored" if mirrored else "", error])
				assert_lt((hand.palm as Vector3).y, -0.7, "%s %s%s: the curled fingers point down, not sideways" % [id, stance, " mirrored" if mirrored else ""])


func test_the_wind_up_is_barely_turned_so_the_fist_turns_over_the_punch() -> void:
	for id: StringName in M3_ARMS:
		for stance: StringName in [PlaceholderPoses.STANCE_RELAXED, PlaceholderPoses.STANCE_BOXER]:
			var side := _side(id)
			var poses := _poses(id, stance)
			var twin := _m3_twin(id, poses)
			var windup := _turned_deg(poses.windup, twin.windup, side)
			var strike := _turned_deg(poses.strike, twin.strike, side)
			var over := strike - windup
			gut.p("%s %s: the wind-up's fist is turned %.1f degrees from M3's, the strike's %.1f: it turns %.1f degrees over the punch" % [id, stance, windup, strike, over])
			assert_lt(windup, WINDUP_TURN_MAX_DEG, "%s %s: the wind-up is turned at most about 30 degrees (%.1f)" % [id, stance, windup])
			assert_between(strike, MIN_STRIKE_TURN_DEG, MAX_STRIKE_TURN_DEG, "%s %s: the strike is turned the 90 degrees asked for (%.1f)" % [id, stance, strike])
			assert_gt(over, OVER_THE_PUNCH_MIN_DEG, "%s %s: the fist turns over the punch, wind-up to contact (%.1f degrees)" % [id, stance, over])


func test_the_fist_point_is_where_it_was_at_every_key() -> void:
	# A20: the hitbox follows the fist point; the roll is about the forearm's axis, so it moves only by the 5 mm the point sits off it.
	var worst := 0.0
	for id: StringName in M3_ARMS:
		for stance: StringName in [PlaceholderPoses.STANCE_RELAXED, PlaceholderPoses.STANCE_BOXER]:
			var side := _side(id)
			var poses := _poses(id, stance)
			var twin := _m3_twin(id, poses)
			for key: String in ["guard", "windup", "strike"]:
				var moved := (_fist_point(poses.get(key), side) - _fist_point(twin.get(key), side)).length()
				worst = maxf(worst, moved)
				assert_lt(moved, FIST_POINT_MAX_M, "%s %s %s: the fist point is within a centimetre of M3's (%.1f mm)" % [id, stance, key, moved * 1000.0])
	gut.p("the fist point's worst move from M3's, at the keys: %.1f mm" % [worst * 1000.0])


func test_the_fist_point_stays_near_m3s_on_every_frame_of_the_clip() -> void:
	var rig := _rig()
	var worst := 0.0
	var worst_at := ""
	for id: StringName in M3_ARMS:
		var side := _side(id)
		var move := _move(id)
		var poses := _poses(id)
		var anim := PlaceholderAnims.build_move_with(poses, move, 1.0)
		var twin := PlaceholderAnims.build_move_with(_m3_twin(id, poses), move, 1.0)
		var hand_i := rig.skeleton.find_bone(side + "Hand")
		var offset: Vector3 = PlaceholderBody.POINT_OFFSET[StringName(side + "FistPoint")]
		var worst_here := 0.0
		for f: int in move.total_frames() + 1:
			var t := minf(float(f) * FRAME, anim.length)
			var now: Transform3D = MotionProbe.clip_globals(rig, anim, t)[hand_i]
			var before: Transform3D = MotionProbe.clip_globals(rig, twin, t)[hand_i]
			var moved := (now * offset - before * offset).length()
			worst_here = maxf(worst_here, moved)
			if moved > worst:
				worst = moved
				worst_at = "%s frame %d" % [id, f]
		gut.p("%s: the fist point's worst move from M3's over every frame: %.1f mm" % [id, worst_here * 1000.0])
	gut.p("the fist point's worst move from M3's over both clips, every frame: %.1f mm (%s)" % [worst * 1000.0, worst_at])
	assert_lt(worst, FIST_FRAME_MAX_M, "the fist point is within 2 cm of M3's on every frame (%.1f mm at %s)" % [worst * 1000.0, worst_at])


func test_the_turn_makes_no_extra_keys() -> void:
	# PlaceholderAnims inserts Euler in-betweens where an angle jumps more than MAX_STEP_DEG (90) between keys, and an Euler lerp of
	# a roll that follows an elbow bend wanders (6 cm at the wrist): the keys' roll is chosen so the clip has the keys M3's had and
	# the rotation slerps.
	for id: StringName in M3_ARMS:
		var move := _move(id)
		var poses := _poses(id)
		var anim := PlaceholderAnims.build_move_with(poses, move, 1.0)
		var twin := PlaceholderAnims.build_move_with(_m3_twin(id, poses), move, 1.0)
		assert_eq(anim.get_track_count(), twin.get_track_count(), "%s: the same tracks" % id)
		for t: int in anim.get_track_count():
			assert_eq(anim.track_get_key_count(t), twin.track_get_key_count(t), "%s track %s: the turn adds no key" % [id, anim.track_get_path(t)])


func test_the_straight_punches_end_back_in_the_stance_with_no_turn_left_in_the_hand() -> void:
	# The recovery runs from the strike's roll back to the guard: the hand and lower arm of the last key are the guard's.
	for id: StringName in M3_ARMS:
		var poses := _poses(id)
		var anim := PlaceholderAnims.build_move_with(poses, _move(id), 1.0)
		for bone: String in [_side(id) + "LowerArm", _side(id) + "Hand"]:
			var track := anim.find_track(NodePath("Skeleton3D:%s" % bone), Animation.TYPE_ROTATION_3D)
			var last: Quaternion = anim.track_get_key_value(track, anim.track_get_key_count(track) - 1)
			var expected := PlaceholderBody.euler_basis(poses.guard.get(StringName(bone), Vector3.ZERO)).get_rotation_quaternion()
			assert_gt(absf(last.dot(expected)), 1.0 - 1e-6, "%s %s: the clip ends in the stance's arm" % [id, bone])


func test_the_punks_cross_and_the_dummys_jab_are_not_turned() -> void:
	# They reuse these strikes (EnemyPosesPunk._cross is jab_1's, _jab and the dummy's jab are jab_2's) and A20 freezes every enemy
	# clip: the lower arm is a pure elbow bend and the hand is the guard's, as M3 had them.
	for id: StringName in UNTURNED:
		var side := String(UNTURNED[id])
		var poses := PlaceholderPoses.move_poses(id, PlaceholderPoses.STANCE_BOXER)
		assert_not_null(poses, "%s has a recipe" % id)
		if poses == null:
			continue
		var lower: Vector3 = poses.strike.get(StringName(side + "LowerArm"), Vector3.ZERO)
		assert_almost_eq(lower.y, 0.0, 1e-6, "%s: the lower arm is not rolled (y)" % id)
		assert_almost_eq(lower.z, 0.0, 1e-6, "%s: the lower arm is not rolled (z)" % id)
		assert_eq(poses.strike.get(StringName(side + "Hand"), Vector3.ZERO), poses.guard.get(StringName(side + "Hand"), Vector3.ZERO),
				"%s: the hand is the guard's" % id)
		var hand := _hand(poses.strike, side, _palm_local(side))
		assert_gt(_deg_from_down(hand.palm), 80.0, "%s: the fist still stands on its edge (%.0f degrees from down)" % [id, _deg_from_down(hand.palm)])


# --- The hero's skin -------------------------------------------------------------------


## The mean distance of the hero's forearm and hand skin from the forearm's axis (the line from the elbow to the wrist), over what
## it is at the table's rest, in each 3 cm band along the arm: the worst band's. 1.0 is a limb that keeps its width; a wrist twisted
## between two binds pinches to cos(half the twist). `side`'s vertices more than half on its lower arm and hand binds.
func _forearm_pinch(globals: Array[Transform3D], side: String) -> float:
	var hero := _hero()
	var rig: HumanoidRig = hero.rig
	var mi: MeshInstance3D = hero.body
	var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
	var lower_i := rig.skeleton.find_bone(side + "LowerArm")
	var hand_i := rig.skeleton.find_bone(side + "Hand")
	var rest: PackedVector3Array = hero.body_rest
	var rest_globals: Array[Transform3D] = hero.rest_globals
	var posed := SkinnedView.skin_vertices(mi, rig, globals)
	var rest_axis := ((rest_globals[hand_i] as Transform3D).origin - (rest_globals[lower_i] as Transform3D).origin).normalized()
	var posed_axis := ((globals[hand_i] as Transform3D).origin - (globals[lower_i] as Transform3D).origin).normalized()
	var sum := {}
	var count := {}
	for v: int in rest.size():
		var weight := 0.0
		for e: int in range(data.entry_start[v], data.entry_start[v + 1]):
			var bind_name := StringName(mi.skin.get_bind_name(data.entry_bind[e]))
			if bind_name == StringName(side + "LowerArm") or bind_name == StringName(side + "Hand"):
				weight += data.entry_weight[e]
		if weight <= 0.5:
			continue
		var d_rest := rest[v] - (rest_globals[hand_i] as Transform3D).origin
		var r_rest := (d_rest - rest_axis * d_rest.dot(rest_axis)).length()
		if r_rest < 0.012:
			continue
		var d_posed := posed[v] - (globals[hand_i] as Transform3D).origin
		var r_posed := (d_posed - posed_axis * d_posed.dot(posed_axis)).length()
		var band := floori(d_rest.dot(rest_axis) / BAND_M)
		sum[band] = float(sum.get(band, 0.0)) + r_posed / r_rest
		count[band] = int(count.get(band, 0)) + 1
	var worst := 9.0
	for band: int in sum:
		if int(count[band]) >= 20:
			worst = minf(worst, float(sum[band]) / float(count[band]))
	return worst


## The pose of `id`'s strike with the whole roll in the hand (the twin that candy-wraps): the lower arm keeps its elbow bend.
func _hand_only_twin(id: StringName, poses: PlaceholderPoses.MovePoses) -> PlaceholderPoses.MovePoses:
	var twin := _m3_twin(id, poses)
	var side := _side(id)
	var turn := PlaceholderPoses.PUNCH_TURN_DEG * (1.0 if side == "Right" else -1.0)
	twin.strike[StringName(side + "Hand")] = Vector3(0.0, turn, 0.0)
	return twin


func test_the_roll_does_not_candy_wrap_the_hero_s_forearm_or_wrist() -> void:
	var hero := _hero()
	if hero.body == null:
		fail_test("the hero's art is worn (assets/export/characters/player/player.glb)")
		return
	var rig: HumanoidRig = hero.rig
	var worst_new := 9.0
	var worst_m3 := 9.0
	var worst_hand_only := 9.0
	for id: StringName in M3_ARMS:
		var side := _side(id)
		var move := _move(id)
		var poses := _poses(id)
		var clips := {
			"new": PlaceholderAnims.build_move_with(poses, move, 1.0),
			"m3": PlaceholderAnims.build_move_with(_m3_twin(id, poses), move, 1.0),
			"hand only": PlaceholderAnims.build_move_with(_hand_only_twin(id, poses), move, 1.0),
		}
		for f: int in FRAMES_SAMPLED:
			var t := minf(float(f) * FRAME, (clips.new as Animation).length)
			var new_pinch := _forearm_pinch(MotionProbe.clip_globals(rig, clips.new, t), side)
			var m3_pinch := _forearm_pinch(MotionProbe.clip_globals(rig, clips.m3, t), side)
			var hand_pinch := _forearm_pinch(MotionProbe.clip_globals(rig, clips["hand only"], t), side)
			if STRIKE_FRAMES.has(f):
				worst_new = minf(worst_new, new_pinch)
				worst_m3 = minf(worst_m3, m3_pinch)
				worst_hand_only = minf(worst_hand_only, hand_pinch)
			assert_gt(new_pinch, m3_pinch - PINCH_LOSS_MAX, "%s frame %d: the forearm and wrist lose little of the width M3's pose kept (%.3f, M3 %.3f, all in the hand %.3f)" % [id, f, new_pinch, m3_pinch, hand_pinch])
			if STRIKE_FRAMES.has(f):
				assert_gt(new_pinch, PINCH_MIN, "%s frame %d: at contact the forearm and wrist keep their width (%.3f, M3 %.3f, all in the hand %.3f)" % [id, f, new_pinch, m3_pinch, hand_pinch])
	gut.p("the hero's forearm and wrist at contact: the narrowest 3 cm band is %.3f of its rest width in both punches (M3's pose %.3f; the whole roll in the hand %.3f)" % [worst_new, worst_m3, worst_hand_only])
	assert_lt(worst_hand_only, PINCH_TWIN_MAX, "the twin, the roll all in the hand, pinches the wrist (%.3f): the metric has teeth" % worst_hand_only)


func test_the_whole_mesh_strain_is_no_worse_than_m3s_through_both_punches() -> void:
	# The A19 measures (tests/art_strain.gd) of the hero's whole art, at the frames sampled, against the M3 clip's at the same frames.
	var hero := _hero()
	if hero.body == null:
		fail_test("the hero's art is worn")
		return
	var rig: HumanoidRig = hero.rig
	for id: StringName in M3_ARMS:
		var move := _move(id)
		var poses := _poses(id)
		var anim := PlaceholderAnims.build_move_with(poses, move, 1.0)
		var twin := PlaceholderAnims.build_move_with(_m3_twin(id, poses), move, 1.0)
		var worst := {high = 0.0, low = 9.0, max = 1.0, min = 1.0, bad = 0}
		var worst_m3 := {high = 0.0, low = 9.0, max = 1.0, min = 1.0, bad = 0}
		for f: int in FRAMES_SAMPLED:
			var t := minf(float(f) * FRAME, anim.length)
			for case: Array in [[anim, worst], [twin, worst_m3]]:
				var report := ArtStrain.strain_at(rig, MotionProbe.clip_globals(rig, case[0], t), true, hero.rests, hero.masks)
				var row: Dictionary = case[1]
				row.high = maxf(row.high, report.p_high)
				row.low = minf(row.low, report.p_low)
				row.max = maxf(row.max, report.max)
				row.min = minf(row.min, report.min)
				row.bad = maxi(row.bad, report.squashed + report.flipped)
		gut.p("hero %s strain over %d frames, new (M3): p99.9 %.3f (%.3f), p0.1 %.3f (%.3f), longest x%.2f (x%.2f), deepest x%.4f (x%.4f), squashed or turned %d (%d)" % [
				id, FRAMES_SAMPLED.size(), worst.high, worst_m3.high, worst.low, worst_m3.low, worst.max, worst_m3.max, worst.min, worst_m3.min, worst.bad, worst_m3.bad])
		assert_lt(worst.high, worst_m3.high * STRAIN_SLACK + 0.005, "%s: p99.9 is no higher than M3's" % id)
		assert_gt(worst.low, worst_m3.low / STRAIN_SLACK - 0.005, "%s: p0.1 is no lower than M3's" % id)
		assert_lt(worst.max, worst_m3.max * STRAIN_SLACK + 0.005, "%s: the longest stretch is no longer than M3's" % id)
		assert_gt(worst.min, worst_m3.min / STRAIN_SLACK - 0.0005, "%s: the deepest compression is no deeper than M3's" % id)
		assert_lt(worst.bad, ceili(float(worst_m3.bad) * STRAIN_SLACK) + 3, "%s: no more squashed or turned-over triangles than M3's" % id)
