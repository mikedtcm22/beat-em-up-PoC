extends GutTest
## Motion on the same frame data (F-motion, M4-plan Part A A20): the polish makes the idles, walks,
## flinches and get-ups breathe, ease, plant their feet and overlap, and never touches a move. This file holds
## the proof:
## - every move clip is compared, key for key, with the hash table written before the polish landed
##   (tests/fixtures/motion/move_clip_hashes.json, made by clip_hash.gd), as is every named clip the polish
##   may not touch, and with the polish off (Tuning's Debug look_motion_polish) every named clip is the M3 clip;
## - the key poses stay keys: a rig that plays any move is in the same pose at its first and last active
##   frame, hurtboxes and rig points identical, whatever idle it came out of;
## - the idle moves no hurtbox a centimeter (A20), the walks plant the art's soles (slide at most 2 cm a
##   step, M4-plan row A4), no looped clip pops at its seam, and the deformation of the art is printed
##   beside the M3 clips'.
## The numbers it prints are `MOTION ...` lines.

const ClipHash := preload("res://tests/fixtures/motion/clip_hash.gd")
const MotionProbe := preload("res://tests/fixtures/motion/motion_probe.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")
const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookMotionActs := preload("res://tests/bot/acts/look_motion_acts.gd")

const PUNK_MOVES: Array[String] = ["punk_jab", "punk_cross", "punk_shove"]
## The Kicker's, Thug's, Bruiser's and boss's moves (their files in game/combat/moves).
const ENEMY_MOVES: Array[String] = ["kicker_jump_kick", "kicker_sweep", "thug_pipe_1", "thug_pipe_2", "thug_pipe_3",
		"bruiser_smash", "bruiser_grab", "bruiser_headbutt", "boss_slam", "boss_charge", "boss_pound", "boss_grab"]
const PUNK_ART := "res://game/actors/art/punk_art.tres"
const M3_DEFORMATION_PATH := "res://tests/fixtures/motion/m3_deformation.json"
const FRAME := 1.0 / 60.0
## The rig sizes of the roster (the Punk, the Bruiser, the boss), as height / 1.8.
const SCALES: Array[float] = [1.0, 1.139, 1.278]
## A20: an idle hurtbox moves less than this (m).
const IDLE_HURTBOX_M := 0.01
## M4-plan row A4: the art's planted soles slide at most this far (m) in a planted step, and are never
## lower than this.
const SLIDE_M := 0.02
const FLOOR_M := -0.015
## The walks, with the way the rig travels in them.
const WALKS: Dictionary[StringName, Vector3] = {
	&"walk_forward": Vector3(0.0, 0.0, -1.0), &"walk_back": Vector3(0.0, 0.0, 1.0),
	&"walk_right": Vector3(1.0, 0.0, 0.0), &"walk_left": Vector3(-1.0, 0.0, 0.0),
}
const LOOPED: Array[StringName] = [
	&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right", &"run_forward", &"downed_back", &"downed_front",
]
const FLINCHES: Array[StringName] = [
	&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut", &"flinch_legs",
]
const STANCES: Array[StringName] = [PlaceholderPoses.STANCE_BOXER, PlaceholderPoses.STANCE_RELAXED]

var _table: Dictionary = {}


func before_all() -> void:
	var file := FileAccess.open(ClipHash.TABLE_PATH, FileAccess.READ)
	if file != null:
		_table = JSON.parse_string(file.get_as_text())


func before_each() -> void:
	Tuning.apply(TuningData.new())
	HumanoidRig._named_libraries.clear()
	SkinnedArt.clear_cache()
	SkinnedView.clear_cache()


func after_each() -> void:
	Tuning.apply(TuningData.new())
	HumanoidRig._named_libraries.clear()


# --- Harness ------------------------------------------------------------------------------------


## A rig of `scale` x 1.8 m in `stance`, with the Punk's art or hurtboxes.
func _rig(stance: StringName = PlaceholderPoses.STANCE_BOXER, scale: float = 1.0, art: bool = false,
		hurtboxes: bool = false) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = 1.8 * scale
	rig.stance = stance
	rig.build_hurtboxes = hurtboxes
	if art:
		rig.art = load(PUNK_ART) as CharacterArt
	add_child_autofree(rig)
	rig.build()
	return rig


## A named clip built with the default Motion tunables (or the polish off).
func _clip(id: StringName, stance: StringName = PlaceholderPoses.STANCE_BOXER, scale: float = 1.0,
		polished: bool = true) -> Animation:
	return PlaceholderAnims.build_named(id, scale, stance,
			PlaceholderAnims.Life.new() if polished else PlaceholderAnims.Life.off())


func _move(file: String) -> MoveData:
	return ResourceLoader.load("res://game/combat/moves/%s.tres" % file, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveData


## The angle (radians) between two rotations, exact near zero (Quaternion.angle_to() is only good to 4e-4).
func _angle(a: Quaternion, b: Quaternion) -> float:
	var d := a.inverse() * b
	return 2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w))


## The largest angle (radians) any bone turns between `anim` at `a` and at `b`.
func _turn(anim: Animation, a: float, b: float) -> float:
	var worst := 0.0
	for track: int in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		worst = maxf(worst, _angle(anim.rotation_track_interpolate(track, a), anim.rotation_track_interpolate(track, b)))
	return worst


## The rotation of `bone` in `anim` at `t`.
func _rotation(anim: Animation, bone: StringName, t: float) -> Quaternion:
	return anim.rotation_track_interpolate(anim.find_track(NodePath("Skeleton3D:%s" % bone), Animation.TYPE_ROTATION_3D), t)


func _hips(anim: Animation, t: float) -> Vector3:
	return anim.position_track_interpolate(anim.find_track(^"Skeleton3D:Hips", Animation.TYPE_POSITION_3D), t)


# --- A20: the move clips never change -----------------------------------------------------------


func test_the_hash_table_covers_every_move_file_and_every_move_id() -> void:
	assert_false(_table.is_empty(), "the hash table is committed")
	var paths := ClipHash.move_paths()
	assert_gte(paths.size(), 41, "every move resource is hashed")
	var stems := {}
	for path: String in paths:
		stems[path.get_file().get_basename()] = true
		for stance: StringName in ClipHash.STANCES:
			for scale: float in ClipHash.SCALES:
				assert_true(_table.moves.has("%s|%s|%s" % [path.get_file().get_basename(), stance, scale]),
						"%s (%s, %s) is in the table" % [path.get_file(), stance, scale])
	for id: String in PUNK_MOVES + ENEMY_MOVES:
		assert_true(stems.has(id), "the enemy move %s is hashed" % id)
	# Every id PlaceholderAnims.MOVE_IDS names is the anim of some hashed move.
	var anims := {}
	for path: String in paths:
		anims[_move(path.get_file().get_basename()).get_anim()] = true
	for id: StringName in PlaceholderAnims.MOVE_IDS:
		assert_true(anims.has(id), "MOVE_IDS %s has a hashed move" % id)


func test_every_move_clip_is_identical_to_the_hash_table() -> void:
	var now := ClipHash.compute()
	var changed := PackedStringArray()
	for key: String in _table.moves:
		if now.moves.get(key, "") != _table.moves[key]:
			changed.append(key)
	assert_eq(now.moves.size(), _table.moves.size(), "the same set of move clips")
	assert_true(changed.is_empty(), "no move clip changed key for key (A20); changed: %s" % [changed])


func test_with_the_polish_off_every_named_clip_is_the_m3_clip() -> void:
	# The Debug tunable builds the M3 clips (the A/B of the captures), and so does Life.off().
	Tuning.data.look_motion_polish = false
	var changed := PackedStringArray()
	for id: StringName in PlaceholderAnims.ANIM_IDS:
		for stance: StringName in ClipHash.STANCES:
			for scale: float in ClipHash.SCALES:
				var key := "%s|%s|%s" % [id, stance, scale]
				var by_tunable := ClipHash.sha(ClipHash.clip_text(PlaceholderAnims.build_named(id, scale, stance)))
				var by_life := ClipHash.sha(ClipHash.clip_text(ClipHash.named_clip(id, scale, stance)))
				if by_tunable != _table.named[key] or by_life != _table.named[key]:
					changed.append(key)
	assert_true(changed.is_empty(), "every named clip is the M3 clip with the polish off; changed: %s" % [changed])


func test_with_the_polish_on_only_the_named_list_changes() -> void:
	# A20: idles, walks, run, taunt, brace, flinches, get-ups and downed. Nothing else on ANIM_IDS moves a key,
	# and every one of those does change (cubic keys at least).
	var moved := PackedStringArray()
	var kept := PackedStringArray()
	for id: StringName in PlaceholderAnims.ANIM_IDS:
		for stance: StringName in ClipHash.STANCES:
			for scale: float in ClipHash.SCALES:
				var key := "%s|%s|%s" % [id, stance, scale]
				var now := ClipHash.sha(ClipHash.clip_text(PlaceholderAnims.build_named(id, scale, stance)))
				var same: bool = now == _table.named[key]
				if PlaceholderAnims.POLISHED_IDS.has(id):
					if same:
						kept.append(key)
				elif not same:
					moved.append(key)
	assert_true(moved.is_empty(), "no clip off the list changed: %s" % [moved])
	assert_true(kept.is_empty(), "every clip on the list is polished: %s" % [kept])
	assert_eq(PlaceholderAnims.POLISHED_IDS.size(), 17, "A20's list: idle, 4 walks, run, taunt, brace, 5 flinches, 2 get-ups, 2 downed")
	for id: StringName in PlaceholderAnims.POLISHED_IDS:
		assert_false(PlaceholderAnims.MOVE_IDS.has(id), "%s is no move" % id)
		assert_true(PlaceholderAnims.ANIM_IDS.has(id), "%s is a named animation" % id)


func test_a_rig_is_in_the_same_pose_at_every_active_frame_of_every_move_with_the_polish_on_and_off() -> void:
	# The key poses stay the keys: from whatever the idle was doing (it differs now), a move's strike is
	# reached unblended, so the rig points and the hurtboxes at the first and last active frames and in
	# between are those of the M3 library's rig.
	var points: Array[StringName] = [&"LeftFistPoint", &"RightFistPoint", &"LeftFootPoint", &"RightFootPoint",
			&"EyePoint", &"ChestPoint", &"LeftKneePoint", &"RightKneePoint", &"LeftElbowPoint", &"RightElbowPoint",
			&"HeadTopPoint", &"WeaponTip"]
	var checked := 0
	var worst := 0.0
	var problems := PackedStringArray()
	for stance: StringName in STANCES:
		Tuning.data.look_motion_polish = false
		HumanoidRig._named_libraries.clear()
		var before := _rig(stance, 1.0, false, true)
		Tuning.data.look_motion_polish = true
		HumanoidRig._named_libraries.clear()
		var after := _rig(stance, 1.0, false, true)
		assert_ne(before.anim_player.get_animation(&"idle").length, after.anim_player.get_animation(&"idle").length,
				"the two rigs hold different libraries")
		for path: String in ClipHash.move_paths():
			var move := _move(path.get_file().get_basename())
			if move.startup < 1:
				continue
			for rig: HumanoidRig in [before, after]:
				rig.play(&"idle", 0.0)
				rig.advance(0.0)
				rig.advance(1.3)
				rig.play_move(move)
			var frames: Array[int] = [move.startup, move.startup + move.active / 2, move.startup + move.active]
			var done := 0
			for frame: int in frames:
				while done < frame:
					before.advance(FRAME)
					after.advance(FRAME)
					done += 1
				for point: StringName in points:
					var d := before.get_point_position(point).distance_to(after.get_point_position(point))
					worst = maxf(worst, d)
					if d > 1e-4:
						problems.append("%s %s frame %d %s: %.4f m" % [stance, move.id, frame, point, d])
				var hb := before.get_hurtboxes()
				var ha := after.get_hurtboxes()
				for i: int in hb.size():
					var d := hb[i].global_transform.origin.distance_to(ha[i].global_transform.origin)
					worst = maxf(worst, d)
					if d > 1e-4:
						problems.append("%s %s frame %d %s hurtbox: %.4f m" % [stance, move.id, frame, hb[i].name, d])
				checked += 1
	print("MOTION active frames: %d poses compared across the moves, the polish on against off, worst %.6f m" % [checked, worst])
	assert_gt(checked, 150, "every move, both stances, three frames each")
	assert_true(problems.is_empty(), "no point or hurtbox differs at an active frame: %s" % [problems.slice(0, 8)])


# --- The named-library cache -------------------------------------------------------------------


func test_the_named_library_cache_key_keeps_its_shape() -> void:
	_rig(PlaceholderPoses.STANCE_BOXER, 1.0)
	_rig(PlaceholderPoses.STANCE_RELAXED, 1.0)
	_rig(PlaceholderPoses.STANCE_BOXER, 1.278)
	var keys: Array = HumanoidRig._named_libraries.keys()
	keys.sort()
	assert_eq(keys, ["boxer@10000", "boxer@12780", "relaxed@10000"], "stance@scale, as in M3")
	var rig_a := _rig(PlaceholderPoses.STANCE_BOXER, 1.0)
	assert_same(rig_a.anim_player.get_animation_library(&""), HumanoidRig._named_libraries["boxer@10000"],
			"one library serves every rig of a size and stance")


func test_building_a_library_costs_a_few_milliseconds() -> void:
	var started := Time.get_ticks_usec()
	var lib := PlaceholderAnims.build_library(1.0, PlaceholderPoses.STANCE_BOXER)
	var polished_ms := (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	PlaceholderAnims.build_library(1.0, PlaceholderPoses.STANCE_BOXER, PlaceholderAnims.Life.off())
	var m3_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("MOTION library build: %.1f ms polished, %.1f ms as in M3 (a library is built once per size and stance)" % [polished_ms, m3_ms])
	assert_eq(lib.get_animation_list().size(), PlaceholderAnims.ANIM_IDS.size(), "every id is built")
	assert_lt(polished_ms, 150.0, "a first rig of a size does not hitch for long (%.1f ms)" % polished_ms)


# --- Life: the idle -----------------------------------------------------------------------------


func test_the_idle_starts_in_the_stance_so_a_clip_that_ends_there_flows_into_it() -> void:
	for stance: StringName in STANCES:
		var rig := _rig(stance)
		var anim := _clip(&"idle", stance)
		var g := PlaceholderPoses.stance_pose(stance)
		var expected := PlaceholderBody.pose_globals(g, PlaceholderAnims.resolve_hips(g), 1.0)
		var got := MotionProbe.clip_globals(rig, anim, 0.0)
		for i: int in got.size():
			var bone := rig.skeleton.get_bone_name(i)
			assert_almost_eq(got[i].origin, (expected[bone] as Transform3D).origin, Vector3.ONE * 0.0005, "%s %s: in place at t = 0" % [stance, bone])
			assert_lt(got[i].basis.get_rotation_quaternion().angle_to((expected[bone] as Transform3D).basis.get_rotation_quaternion()),
					deg_to_rad(0.1), "%s %s: turned as in the stance at t = 0" % [stance, bone])


func test_the_idle_breathes_about_once_every_four_seconds_and_bounces_inside_it() -> void:
	var anim := _clip(&"idle")
	assert_almost_eq(anim.length, 1.0 / Tuning.data.look_motion_breath_hz, 1e-4, "one breath is the loop")
	assert_almost_eq(anim.length, 4.0, 0.01, "about 0.25 Hz")
	assert_eq(anim.loop_mode, Animation.LOOP_LINEAR)
	# The chest rocks by the breathing amplitude (Chest +1.5 degrees at the top of a breath; the upper
	# chest gives way, so the head's volume stays), the shoulders rise.
	var chest_x := 0.0
	var shoulder_z := 0.0
	var steps := 240
	for i: int in steps:
		var t := anim.length * float(i) / steps
		var q := _rotation(anim, &"Chest", t)
		chest_x = maxf(chest_x, absf(rad_to_deg(q.get_euler(EULER_ORDER_YXZ).x)))
		shoulder_z = maxf(shoulder_z, absf(rad_to_deg(_rotation(anim, &"RightShoulder", t).get_euler(EULER_ORDER_YXZ).z)))
	var g := PlaceholderPoses.guard()
	assert_between(chest_x, absf(g[&"Chest"].x) - 0.5, absf(g[&"Chest"].x) + 2.5, "the chest rocks 1-2 degrees (%.2f)" % chest_x)
	assert_gt(shoulder_z, 0.5, "the shoulders rise (%.2f degrees)" % shoulder_z)
	# The bounce: the hips dip and come up more than once a breath.
	var peaks := 0
	var last := _hips(anim, 0.0).y
	var rising := false
	var turns := 0
	for i: int in steps + 1:
		var y := _hips(anim, anim.length * float(i) / steps).y
		if y > last + 1e-6 and not rising:
			rising = true
			turns += 1
		elif y < last - 1e-6:
			rising = false
		last = y
	peaks = turns
	assert_gte(peaks, 4, "the hips bounce several times a breath (%d)" % peaks)


func test_no_idle_hurtbox_moves_a_centimeter_on_any_body() -> void:
	# A20: idle hurtboxes move less than 1 cm (peak to peak, every key point of every hurtbox), the
	# Punk's size and the roster's, the boxer's idle and the player's calmer one. M3's own idle moved
	# them 12.6 mm.
	for stance: StringName in STANCES:
		for scale: float in SCALES:
			var rig := _rig(stance, scale)
			var extent := MotionProbe.hurt_extent(rig, _clip(&"idle", stance, scale))
			var worst := 0.0
			for e: float in extent:
				worst = maxf(worst, e)
			var m3 := 0.0
			for e: float in MotionProbe.hurt_extent(rig, _clip(&"idle", stance, scale, false)):
				m3 = maxf(m3, e)
			print("MOTION idle hurtbox motion %s x%.3f: %.1f mm (M3 %.1f mm)" % [stance, scale, worst * 1000.0, m3 * 1000.0])
			assert_lt(worst, IDLE_HURTBOX_M, "%s x%.3f: no hurtbox moves 1 cm (%.1f mm)" % [stance, scale, worst * 1000.0])
	var boxer := MotionProbe.hurt_extent(_rig(PlaceholderPoses.STANCE_BOXER), _clip(&"idle"))
	var player := MotionProbe.hurt_extent(_rig(PlaceholderPoses.STANCE_RELAXED), _clip(&"idle", PlaceholderPoses.STANCE_RELAXED))
	for k: int in boxer.size():
		assert_lt(player[k], boxer[k] + 1e-6, "the player's idle is calmer than the boxer's at point %d" % k)


func test_the_idle_keeps_the_soles_where_the_stance_has_them() -> void:
	# The hips dip and roll and the knees compensate: no sole point moves, and none goes under the floor.
	for stance: StringName in STANCES:
		var rig := _rig(stance, 1.0, true)
		var mi := rig.art_meshes()[0]
		var sole := MotionProbe.sole_vertices(mi, rig)
		var result := MotionProbe.walk_slide(mi, rig, _clip(&"idle", stance), sole, Vector3.FORWARD, 0.0)
		print("MOTION idle soles %s: slide %.2f cm, lowest %.1f mm" % [stance, result.slide * 100.0, result.lowest * 1000.0])
		assert_lt(result.slide, 0.005, "%s: the planted soles hold still through the idle (%.2f cm)" % [stance, result.slide * 100.0])
		assert_gt(result.lowest, FLOOR_M, "%s: no sole vertex under the floor (%.1f mm)" % [stance, result.lowest * 1000.0])


func test_the_player_idles_with_a_share_of_the_boxers_life() -> void:
	var boxer := _clip(&"idle")
	var player := _clip(&"idle", PlaceholderPoses.STANCE_RELAXED)
	var life := PlaceholderAnims.Life.new()
	var chest_boxer := 0.0
	var chest_player := 0.0
	var gb := PlaceholderPoses.guard()
	var gp := PlaceholderPoses.relaxed()
	for i: int in 120:
		var t := 4.0 * float(i) / 120.0
		chest_boxer = maxf(chest_boxer, _rotation(boxer, &"Chest", t).angle_to(PlaceholderBody.euler_basis(gb[&"Chest"]).get_rotation_quaternion()))
		chest_player = maxf(chest_player, _rotation(player, &"Chest", t).angle_to(PlaceholderBody.euler_basis(gp[&"Chest"]).get_rotation_quaternion()))
	assert_gt(chest_player, 0.0, "the player breathes")
	assert_lt(chest_player, chest_boxer * (life.player_calm + 0.15), "a share of the boxer's: %.3f against %.3f" % [chest_player, chest_boxer])


func test_the_motion_tunables_drive_the_clips() -> void:
	var base := ClipHash.sha(ClipHash.clip_text(_clip(&"idle")))
	Tuning.data.look_motion_breath_deg = 0.0
	Tuning.data.look_motion_bounce_m = 0.0
	Tuning.data.look_motion_shift_deg = 0.0
	Tuning.data.look_motion_guard_sway_deg = 0.0
	Tuning.data.look_motion_head_deg = 0.0
	var still := PlaceholderAnims.build_named(&"idle", 1.0, PlaceholderPoses.STANCE_BOXER)
	assert_ne(ClipHash.sha(ClipHash.clip_text(still)), base, "the amplitudes are read when the clip is built")
	var rig := _rig(PlaceholderPoses.STANCE_BOXER)
	for e: float in MotionProbe.hurt_extent(rig, still):
		assert_lt(e, 1e-4, "no life, no motion (%.5f)" % e)
	Tuning.apply(TuningData.new())
	Tuning.data.look_motion_breath_hz = 0.5
	assert_almost_eq(PlaceholderAnims.build_named(&"idle", 1.0).length, 2.0, 0.01, "the breath rate sets the loop")
	Tuning.apply(TuningData.new())
	Tuning.data.look_motion_stride_m = 0.4
	var short := PlaceholderAnims.build_named(&"walk_forward", 1.0)
	Tuning.apply(TuningData.new())
	assert_lt(short.length, PlaceholderAnims.build_named(&"walk_forward", 1.0).length, "a shorter stride is a shorter cycle")


func test_a_default_life_is_the_default_tunables_and_there_is_no_second_copy_of_them() -> void:
	# The tests build their clips from Life.new() and the game from Life.from_tuning(): the two must be one set of numbers
	# (CLAUDE.md: feel numbers are never script constants), or a re-tuned default leaves the tests measuring a walk nobody sees.
	var fresh := PlaceholderAnims.Life.new()
	var live := PlaceholderAnims.Life.from_tuning()
	var names := PackedStringArray()
	for info: Dictionary in fresh.get_property_list():
		if int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(String(info.name))
			assert_eq(fresh.get(info.name), live.get(info.name), "Life.new() and Life.from_tuning() on a fresh TuningData agree on %s" % info.name)
	assert_eq(names.size(), 15, "the 14 Motion tunables and move_speed are all in Life (%s)" % [names])
	# The twin: Life.new() reads TuningData's own defaults, not numbers of its own...
	var shipped := TuningData.new()
	assert_eq(fresh.stride_m, shipped.look_motion_stride_m, "the stride is the tunable's default")
	assert_eq(fresh.move_speed, shipped.move_speed, "the speed is the tunable's default")
	assert_eq(fresh.enabled, shipped.look_motion_polish, "the polish is the Debug switch's default")
	# ...and a Life made from another set of tunables has that set's values, so a re-tuned default is followed.
	shipped.look_motion_stride_m = 0.7
	shipped.look_motion_hip_roll_deg = 8.0
	shipped.move_speed = 4.0
	var tuned := PlaceholderAnims.Life.new(shipped)
	assert_eq(tuned.stride_m, 0.7, "a Life takes the stride of the tunables it is given")
	assert_eq(tuned.hip_roll_deg, 8.0, "and the hip roll")
	assert_eq(tuned.move_speed, 4.0, "and the speed")
	Tuning.data.look_motion_stride_m = 0.7
	assert_ne(PlaceholderAnims.Life.from_tuning().stride_m, PlaceholderAnims.Life.new().stride_m, "the live tunables are not the fresh ones once re-tuned")
	# Structurally: class Life declares no number of its own.
	var source := FileAccess.get_file_as_string("res://game/actors/placeholder_anims.gd")
	var block := source.substr(source.find("class Life:"), source.find("## One key: a pose") - source.find("class Life:"))
	var literals := PackedStringArray()
	for line: String in block.split("\n"):
		if line.begins_with("\tvar ") and line.contains(": float = "):
			literals.append(line.strip_edges())
	assert_eq(literals, PackedStringArray(), "class Life holds no float default (it reads TuningData)")


func test_a_clip_built_from_a_default_life_is_the_clip_the_game_plays() -> void:
	# The walks of A4 and of the slide tests are built from Life.new(): they are the clips HumanoidRig builds from the live
	# tunables, key for key, in both stances, for every polished id.
	for stance: StringName in STANCES:
		for id: StringName in PlaceholderAnims.POLISHED_IDS:
			var by_test := ClipHash.sha(ClipHash.clip_text(PlaceholderAnims.build_named(id, 1.0, stance, PlaceholderAnims.Life.new())))
			var by_game := ClipHash.sha(ClipHash.clip_text(PlaceholderAnims.build_named(id, 1.0, stance)))
			assert_eq(by_test, by_game, "%s (%s): Life.new() builds the clip the game plays" % [id, stance])


func test_the_subset_skin_is_the_whole_skin_at_those_vertices() -> void:
	# SkinnedView.skin_subset() skins only the vertices it is given (the walks' sole points), with the same matrices and
	# weights: each point is the one skin_vertices() gives, in a pose with every bone turned.
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	var mi := rig.art_meshes()[0]
	var sole := MotionProbe.sole_vertices(mi, rig)
	var picks := PackedInt32Array()
	for v: int in range(0, mi.mesh.surface_get_array_len(0), 37):
		picks.append(v)
	picks.append_array(sole)
	for case: Array in [[&"walk_forward", 0.13], [&"idle", 0.9], [&"stagger_back", 0.3]]:
		var globals := MotionProbe.clip_globals(rig, _clip(case[0]), case[1])
		var whole := SkinnedView.skin_vertices(mi, rig, globals)
		var part := SkinnedView.skin_subset(mi, rig, picks, globals)
		assert_eq(part.size(), picks.size(), "one point per index")
		var worst := 0.0
		for k: int in picks.size():
			worst = maxf(worst, part[k].distance_to(whole[picks[k]]))
		assert_lt(worst, 1e-6, "%s: the subset is the whole skin at those vertices (%.8f m)" % [case[0], worst])


func test_the_motion_tunables_are_in_the_look_group_and_the_switch_is_a_debug_value() -> void:
	var motion: Array[StringName] = []
	for info: Dictionary in Tuning.tuning_properties():
		if info.group == "Look" and info.subgroup == "Motion":
			motion.append(StringName(info.name))
			assert_eq(int(info.hint), PROPERTY_HINT_RANGE, "%s is a slider" % info.name)
			assert_true(Tuning.is_preset_property(StringName(info.name)), "a preset saves %s" % info.name)
			assert_false(String(info.name).begins_with("vfx_"), "no vfx_ name in Motion (A9)")
	for name: StringName in [&"look_motion_breath_deg", &"look_motion_breath_hz", &"look_motion_bounce_m", &"look_motion_bounce_hz",
			&"look_motion_shift_deg", &"look_motion_guard_sway_deg", &"look_motion_head_deg", &"look_motion_player_calm",
			&"look_motion_stride_m", &"look_motion_hip_roll_deg", &"look_motion_counter_swing_deg", &"look_motion_overlap_s",
			&"look_motion_overshoot"]:
		assert_has(motion, name)
	var docs := TuningPanel.doc_comments(TuningData)
	for name: StringName in motion:
		assert_ne(docs.get(name, ""), "", "%s is documented" % name)
	var info := Tuning._property_info(Tuning.tuning_properties(), &"look_motion_polish")
	assert_eq(info.group, "Debug", "the A/B is a Debug value (A9)")
	assert_false(Tuning.is_preset_property(&"look_motion_polish"), "presets skip it")
	assert_true(TuningData.new().look_motion_polish, "the polish is on by default")
	# The shipped defaults hold the values.
	var shipped := FileAccess.get_file_as_string("res://tuning/default.json")
	assert_true(shipped.contains("look_motion_breath_deg"), "tuning/default.json holds the Motion values")
	assert_false(shipped.contains("look_motion_polish"), "and not the Debug switch")


# --- Walks --------------------------------------------------------------------------------------


func test_a_boxers_walk_is_as_long_as_its_stride_takes_at_move_speed() -> void:
	# HumanoidRig plays a walk at v / move_speed, so the body goes move_speed meters per clip second.
	var forward := _clip(&"walk_forward")
	assert_almost_eq(forward.length, Tuning.data.look_motion_stride_m / (Tuning.data.move_speed * MotionClips.STANCE_SHARE), 1e-4,
			"the cycle is the stride over the speed the feet must keep")
	assert_almost_eq(_clip(&"walk_back").length, forward.length, 1e-6, "back is the same cycle run backward")
	for scale: float in SCALES:
		assert_almost_eq(_clip(&"walk_forward", PlaceholderPoses.STANCE_BOXER, scale).length, forward.length, 1e-6,
				"the cycle does not depend on the size of the body: the stride is in meters")
	Tuning.data.move_speed = 4.0
	assert_almost_eq(PlaceholderAnims.build_named(&"walk_forward", 1.0).length, Tuning.data.look_motion_stride_m / (4.0 * MotionClips.STANCE_SHARE), 1e-4,
			"a slower game's walk is a longer cycle")
	for id: StringName in WALKS:
		assert_eq(_clip(id).loop_mode, Animation.LOOP_LINEAR, "%s loops" % id)
	# The player's keeps the M3 cadence: his feet are seen only looking down, and the cycle is his speed's feel.
	for id: StringName in WALKS:
		assert_almost_eq(_clip(id, PlaceholderPoses.STANCE_RELAXED).length, 0.6, 1e-6, "%s (relaxed) keeps its 0.6 s" % id)


func test_the_punks_soles_stay_planted_through_every_walk() -> void:
	# M4-plan row A4: the art's soles (the skinned foot and toe vertices that start under 2 cm), a run of
	# planted frames (under 1 cm) never strays more than 2 cm in the world while the body travels at
	# move_speed per clip second. M3's walks slid 1.2 m (forward) and 2.5 m (side steps) a step.
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	var mi := rig.art_meshes()[0]
	var sole := MotionProbe.sole_vertices(mi, rig)
	assert_gt(sole.size(), 40, "the art has a sole (%d vertices)" % sole.size())
	for id: StringName in WALKS:
		var result := MotionProbe.walk_slide(mi, rig, _clip(id), sole, WALKS[id], Tuning.data.move_speed)
		var m3 := MotionProbe.walk_slide(mi, rig, _clip(id, PlaceholderPoses.STANCE_BOXER, 1.0, false), sole, WALKS[id], Tuning.data.move_speed)
		print("MOTION walk slide %s: %.2f cm over %d runs, lowest %.1f mm (M3: %.1f cm, lowest %.1f mm)" % [
				id, result.slide * 100.0, result.runs, result.lowest * 1000.0, m3.slide * 100.0, m3.lowest * 1000.0])
		assert_gt(result.runs, 20, "%s: there are planted steps to measure" % id)
		assert_lt(result.slide, SLIDE_M, "%s: at most 2 cm a step (%.2f cm)" % [id, result.slide * 100.0])
		assert_gt(result.lowest, FLOOR_M, "%s: no sole vertex under the floor in a planted frame (%.1f mm)" % [id, result.lowest * 1000.0])


func test_every_size_of_body_plants_its_feet_too() -> void:
	# The Bruiser's and the boss's rigs (no art: the placeholder's own sole points): the stride is in meters, so the
	# angles are those of a longer leg.
	for scale: float in SCALES:
		var rig := _rig(PlaceholderPoses.STANCE_BOXER, scale)
		for id: StringName in WALKS:
			var result := MotionProbe.primitive_slide(rig, _clip(id, PlaceholderPoses.STANCE_BOXER, scale), WALKS[id], Tuning.data.move_speed)
			print("MOTION walk slide x%.3f %s: %.2f cm, lowest %.1f mm" % [scale, id, result.slide * 100.0, result.lowest * 1000.0])
			assert_lt(result.slide, SLIDE_M, "x%.3f %s: at most 2 cm (%.2f cm)" % [scale, id, result.slide * 100.0])
			assert_gt(result.lowest, FLOOR_M, "x%.3f %s: not under the floor (%.1f mm)" % [scale, id, result.lowest * 1000.0])


func test_a_slower_game_still_plants_the_feet() -> void:
	# The clip's length comes from move_speed when it is built, so the stride holds for any speed the game sets.
	Tuning.data.move_speed = 4.0
	HumanoidRig._named_libraries.clear()
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	var mi := rig.art_meshes()[0]
	var sole := MotionProbe.sole_vertices(mi, rig)
	for id: StringName in [&"walk_forward", &"walk_right"]:
		var result := MotionProbe.walk_slide(mi, rig, rig.anim_player.get_animation(id), sole, WALKS[id], 4.0)
		assert_lt(result.slide, SLIDE_M, "%s at move_speed 4: %.2f cm" % [id, result.slide * 100.0])


func test_a_punk_walking_through_the_rigs_own_playback_plants_its_feet() -> void:
	# The same bound through HumanoidRig.play_locomotion() and the AnimationPlayer, the way EnemyActor drives
	# them: the rig moves at the speed, and plays at speed / move_speed. The enemies' speeds: circling,
	# approaching, engaging, and a side step at the circling pace.
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	var mi := rig.art_meshes()[0]
	var sole := MotionProbe.sole_vertices(mi, rig)
	var cases := [
		[Vector2(0.0, 1.0), Tuning.data.posture_circle_speed_mps], [Vector2(0.0, 1.0), Tuning.data.approach_speed_mps],
		[Vector2(0.0, 1.0), Tuning.data.engage_speed_mps], [Vector2(0.0, -1.0), Tuning.data.posture_circle_speed_mps],
		[Vector2(1.0, 0.0), Tuning.data.posture_circle_speed_mps], [Vector2(-1.0, 0.0), Tuning.data.posture_circle_speed_mps],
	]
	for row: Array in cases:
		var local: Vector2 = row[0]
		var speed: float = row[1]
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var travel := Vector3(local.x, 0.0, -local.y)
		rig.play_locomotion(local, speed / Tuning.data.move_speed)
		var ticks := 150
		var run_start := {}
		var run_begun := {}
		var slide := 0.0
		var origin := Vector3.ZERO
		var runs := 0
		for i: int in ticks:
			origin += travel * speed * FRAME
			rig.advance(FRAME)
			if i < 40:
				continue  # the cross-fade from the idle
			var globals: Array[Transform3D] = []
			for b: int in rig.skeleton.get_bone_count():
				globals.append(rig.animation_pose(b))
			var posed := SkinnedView.skin_subset(mi, rig, sole, globals)
			for v: int in sole.size():
				var p := posed[v]
				var world := Vector3(p.x + origin.x, 0.0, p.z + origin.z)
				if p.y < MotionProbe.PLANT_M:
					if not run_start.has(v):
						run_start[v] = world
						run_begun[v] = i > 60
						if run_begun[v]:
							runs += 1
					elif run_begun[v]:
						slide = maxf(slide, world.distance_to(run_start[v]))
				else:
					run_start.erase(v)
					run_begun.erase(v)
		print("MOTION walking %s at %.2f m/s through play_locomotion: slide %.2f cm over %d runs" % [local, speed, slide * 100.0, runs])
		assert_gt(runs, 10, "%s at %.2f m/s: steps to measure" % [local, speed])
		assert_lt(slide, SLIDE_M, "%s at %.2f m/s: at most 2 cm (%.2f cm)" % [local, speed, slide * 100.0])


# --- No pops --------------------------------------------------------------------------------------


func test_no_looped_clip_pops_at_its_seam() -> void:
	# The first and last keys of every looped clip the polish touched agree (rotations and Hips), and the step
	# across the seam is no bigger than the biggest step anywhere else in the clip.
	var h := 1.0 / 240.0
	for stance: StringName in STANCES:
		for scale: float in [1.0, 1.278]:
			for id: StringName in LOOPED:
				var anim := _clip(id, stance, scale)
				for track: int in anim.get_track_count():
					var count := anim.track_get_key_count(track)
					var first: Variant = anim.track_get_key_value(track, 0)
					var last: Variant = anim.track_get_key_value(track, count - 1)
					if first is Quaternion:
						assert_lt(_angle(first as Quaternion, last as Quaternion), 1e-4, "%s %s x%.3f %s: the first and last keys agree" % [stance, id, scale, anim.track_get_path(track)])
					else:
						assert_lt((first as Vector3).distance_to(last), 1e-5, "%s %s x%.3f: the Hips' first and last keys agree" % [stance, id, scale])
				var seam := _turn(anim, anim.length - h, anim.length)
				var inside := 0.0
				var t := 0.0
				while t + h < anim.length - h:
					inside = maxf(inside, _turn(anim, t, t + h))
					t += h * 3.0
				assert_lte(seam, inside * 1.25 + 1e-4, "%s %s x%.3f: no pop at the loop seam (%.5f, elsewhere at most %.5f rad)" % [stance, id, scale, seam, inside])


## The key times the clip `id` is authored with (PlaceholderAnims.build_named() puts more keys in a clip whose
## angles jump, evenly spaced: those are not poses).
func _authored_times(id: StringName, stance: StringName) -> Array[float]:
	var g := PlaceholderPoses.stance_pose(stance)
	var named := {}
	match id:
		&"taunt":
			named = EnemyNamedPoses.named(id, g)
		&"brace":
			named = EnemyPosesBruiser.named(id, g)
		&"run_forward":
			named = EnemyPosesBoss.named(id, g)
	var out: Array[float] = []
	if not named.is_empty():
		for key: PlaceholderAnims.PoseKey in named.keys:
			out.append(key.time)
		return out
	match id:
		&"getup_back":
			out.assign([0.0, 0.18, 0.34, 0.5])
		&"getup_front":
			out.assign([0.0, 0.2, 0.36, 0.5])
		_:
			out.assign([0.0, 1.0, 2.0])
	return out


func test_the_eased_clips_have_the_m3_pose_at_every_authored_key() -> void:
	# Key poses stay the keys: at every authored key time the eased clip has the M3 pose (rotations and Hips), so a
	# get-up, the taunt and the brace still reach each of their poses when they did, and the lying breath still
	# peaks when it did.
	for id: StringName in [&"taunt", &"brace", &"getup_back", &"getup_front", &"run_forward", &"downed_back", &"downed_front"]:
		for stance: StringName in STANCES:
			var old := _clip(id, stance, 1.0, false)
			var now := _clip(id, stance)
			assert_almost_eq(now.length, old.length, 1e-6, "%s: the same length" % id)
			for t: float in _authored_times(id, stance):
				for track: int in old.get_track_count():
					var path := old.track_get_path(track)
					var other := now.find_track(path, old.track_get_type(track))
					if old.track_get_type(track) == Animation.TYPE_ROTATION_3D:
						assert_lt(_angle(old.rotation_track_interpolate(track, t), now.rotation_track_interpolate(other, t)), 2e-3,
								"%s %s %s at %.3f s: the key pose is the key" % [stance, id, path, t])
					else:
						assert_almost_eq(now.position_track_interpolate(other, t), old.position_track_interpolate(track, t),
								Vector3.ONE * 2e-4, "%s %s Hips at %.3f s" % [stance, id, t])


func test_the_player_idle_and_the_polished_clips_have_no_overshoot_past_their_key_poses() -> void:
	# The monotone cubic never passes the poses it moves between: every bone of every eased clip stays within the
	# span of its M3 key values (per Euler axis, plus a degree for the interpolation of quaternions).
	for id: StringName in [&"taunt", &"brace", &"getup_back", &"getup_front"]:
		var old := _clip(id, PlaceholderPoses.STANCE_BOXER, 1.0, false)
		var now := _clip(id)
		for track: int in old.get_track_count():
			if old.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			var low := Vector3.INF
			var high := -Vector3.INF
			for k: int in old.track_get_key_count(track):
				var v: Vector3 = old.track_get_key_value(track, k)
				low = low.min(v)
				high = high.max(v)
			var other := now.find_track(old.track_get_path(track), Animation.TYPE_POSITION_3D)
			for i: int in 50:
				var v := now.position_track_interpolate(other, now.length * float(i) / 49.0)
				assert_true(v.x >= low.x - 1e-3 and v.y >= low.y - 1e-3 and v.z >= low.z - 1e-3
						and v.x <= high.x + 1e-3 and v.y <= high.y + 1e-3 and v.z <= high.z + 1e-3, "%s: the Hips stay inside their keys (%s)" % [id, v])


# --- Flinches -------------------------------------------------------------------------------------


func test_a_flinch_keeps_the_m3_length_and_ends_in_the_stance_it_ended_in() -> void:
	for stance: StringName in STANCES:
		for id: StringName in FLINCHES:
			var old := _clip(id, stance, 1.0, false)
			var now := _clip(id, stance)
			assert_almost_eq(now.length, old.length, 1e-6, "%s: 0.25 s still" % id)
			assert_eq(now.loop_mode, Animation.LOOP_NONE)
			assert_lt(_turn(old, old.length, old.length) + _turn(now, now.length, 0.0) * 0.0, 1.0)
			var end_turn := 0.0
			for track: int in old.get_track_count():
				if old.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					var other := now.find_track(old.track_get_path(track), Animation.TYPE_ROTATION_3D)
					end_turn = maxf(end_turn, (old.track_get_key_value(track, old.track_get_key_count(track) - 1) as Quaternion).angle_to(now.rotation_track_interpolate(other, now.length)))
			assert_lt(end_turn, 1e-3, "%s %s: ends where M3's ended (%.5f rad)" % [stance, id, end_turn])
			assert_almost_eq(_hips(now, now.length), _hips(old, old.length), Vector3.ONE * 1e-4, "%s %s: the hips end where they did" % [stance, id])


func test_a_flinch_overlaps_the_head_lags_and_overshoots_and_the_shoulders_lead() -> void:
	# The key poses (0.06 s, 0.1 s) are the body's as before; the head peaks later than the chest and a little
	# past the hit pose, the shoulders are there earlier.
	var g := PlaceholderPoses.guard()
	var f := PlaceholderPoses.flinch_head_front(g)
	var old := _clip(&"flinch_head_front", PlaceholderPoses.STANCE_BOXER, 1.0, false)
	var now := _clip(&"flinch_head_front")
	for bone: StringName in [&"Spine", &"Chest", &"LeftUpperLeg", &"RightLowerLeg"]:
		for t: float in [0.06, 0.1]:
			assert_lt(_rotation(now, bone, t).angle_to(_rotation(old, bone, t)), 2e-3, "%s at %.2f s: the key pose is the key" % [bone, t])
	var rest_head := PlaceholderBody.euler_basis(g[&"Head"]).get_rotation_quaternion()
	var rest_chest := PlaceholderBody.euler_basis(g[&"Chest"]).get_rotation_quaternion()
	var peak_head := 0.0
	var peak_head_t := 0.0
	var peak_chest_t := 0.0
	var peak_chest := 0.0
	var arm_first := 1.0
	for i: int in 100:
		var t := now.length * float(i) / 99.0
		var head := _rotation(now, &"Head", t).angle_to(rest_head)
		var chest := _rotation(now, &"Chest", t).angle_to(rest_chest)
		if head > peak_head + 1e-6:
			peak_head = head
			peak_head_t = t
		if chest > peak_chest + 1e-6:
			peak_chest = chest
			peak_chest_t = t
	var hit_head := PlaceholderBody.euler_basis(f[&"Head"]).get_rotation_quaternion().angle_to(rest_head)
	assert_gt(peak_head_t, peak_chest_t + 0.01, "the head peaks after the chest (%.3f s, %.3f s)" % [peak_head_t, peak_chest_t])
	assert_gt(peak_head, hit_head, "and a little past the hit pose (%.2f against %.2f degrees)" % [rad_to_deg(peak_head), rad_to_deg(hit_head)])
	assert_lt(peak_head, hit_head * 1.4, "but only a little")
	var arm_hit := PlaceholderBody.euler_basis(f[&"LeftUpperArm"]).get_rotation_quaternion().angle_to(PlaceholderBody.euler_basis(g[&"LeftUpperArm"]).get_rotation_quaternion())
	for i: int in 60:
		var t := 0.06 * float(i) / 59.0
		if _rotation(now, &"LeftUpperArm", t).angle_to(PlaceholderBody.euler_basis(g[&"LeftUpperArm"]).get_rotation_quaternion()) > arm_hit * 0.99:
			arm_first = t
			break
	assert_lt(arm_first, 0.06 - 0.01, "the arm has reached its pose before the body (%.3f s)" % arm_first)


func test_the_polished_flinches_start_and_end_like_the_old_ones_and_ease_out_of_the_hold() -> void:
	# No pop: the first frame is the stance and the recovery arrives slowly (the last step of the clip is smaller than
	# M3's linear one).
	for id: StringName in FLINCHES:
		var old := _clip(id, PlaceholderPoses.STANCE_BOXER, 1.0, false)
		var now := _clip(id)
		assert_lt(_turn(now, 0.0, 0.0), 1e-6)
		assert_lt(_turn(now, 0.0, 1e-5), 1e-3, "%s starts at rest" % id)
		var last_new := _turn(now, now.length - 1.0 / 60.0, now.length)
		var last_old := _turn(old, old.length - 1.0 / 60.0, old.length)
		assert_lt(last_new, last_old, "%s arrives slower than M3's linear recovery (%.4f against %.4f rad)" % [id, last_new, last_old])


# --- Deformation ------------------------------------------------------------------------------------


## The frozen deformation of the M3 clips on the Punk's art (tests/fixtures/motion/m3_deformation.json, made by
## gen_m3_deformation.tscn): `{"<stance>|<id>": {high, low, max, min}}`, or an empty Dictionary when the file is missing or was
## made for other vertices or weights than `mi`'s (the caller then measures the M3 clips live: slower, never wrong).
func _frozen_m3(mi: MeshInstance3D) -> Dictionary:
	var file := FileAccess.open(M3_DEFORMATION_PATH, FileAccess.READ)
	if file == null:
		return {}
	var table: Dictionary = JSON.parse_string(file.get_as_text())
	if table.get("art", "") != MotionProbe.art_hash(mi):
		return {}
	return table.figures


func test_the_deformation_of_the_changed_clips_is_printed_beside_the_m3_figures_and_does_not_get_worse() -> void:
	# A19's measure (the strain of the art against the skinned rest pose, p99.9, p0.1, and the extreme edges) at 17
	# phases of each clip the polish changed, the M3 clip beside it. The clips whose poses are the M3 poses (everything
	# but the boxer's walks, which plant their feet and so move the legs further) are no worse (the bar is one tenth of a
	# strain unit on p99.9 and p0.1, ten per cent on the worst edge); the walks are within what a planted stride costs
	# (0.6 on p99.9, twice the worst edge: the worst edge is the foot's seam in both, and the strafes' M3 steps were
	# nearly still). The M3 side is frozen (the M3 clips never change, A20; the file is read for this art, see _frozen_m3),
	# so only the polished clips are skinned here.
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	var mi := rig.art_meshes()[0]
	var rest := SkinnedView.skin_vertices(mi, rig, MotionProbe.rest_globals(rig))
	var frozen := _frozen_m3(mi)
	if frozen.is_empty():
		print("MOTION the M3 deformation fixture is missing or stale for this art: the M3 clips are measured live (regenerate it: tests/fixtures/motion/gen_m3_deformation.tscn)")
	var worse := PackedStringArray()
	for stance: StringName in STANCES:
		for id: StringName in PlaceholderAnims.POLISHED_IDS:
			var m3: Dictionary = frozen.get("%s|%s" % [stance, id], {})
			if m3.is_empty():
				m3 = MotionProbe.clip_strain(mi, rig, rest, _clip(id, stance, 1.0, false))
			var now := MotionProbe.clip_strain(mi, rig, rest, _clip(id, stance))
			print("MOTION A19 %s %-18s M3: p99.9 %.2f p0.1 %.2f max %.1f min %.2f | now: p99.9 %.2f p0.1 %.2f max %.1f min %.2f" % [
					stance, id, m3.high, m3.low, m3.max, m3.min, now.high, now.low, now.max, now.min])
			var walk := String(id).begins_with("walk") and stance == PlaceholderPoses.STANCE_BOXER
			var slack := 0.6 if walk else 0.1
			if now.high > m3.high + slack:
				worse.append("%s %s p99.9 %.2f against %.2f" % [stance, id, now.high, m3.high])
			if now.low < m3.low - slack * 0.5:
				worse.append("%s %s p0.1 %.2f against %.2f" % [stance, id, now.low, m3.low])
			if now.max > m3.max * (2.0 if walk else 1.1) + 0.5:
				worse.append("%s %s max %.1f against %.1f" % [stance, id, now.max, m3.max])
	assert_true(worse.is_empty(), "no clip's deformation got worse: %s" % [worse])


func test_the_frozen_m3_deformation_is_the_m3_clips_on_this_art() -> void:
	# The fixture is a frozen measurement, so it is checked: it covers every polished clip in both stances, it was made for
	# this art's vertices and weights (else regenerate it: tests/fixtures/motion/gen_m3_deformation.tscn), and two of its
	# clips, measured live now, are the figures it holds (a change of the rig or of the measure shows here).
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	var mi := rig.art_meshes()[0]
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(M3_DEFORMATION_PATH))
	assert_eq(table.art, MotionProbe.art_hash(mi), "the fixture was made for punk.glb's vertices and weights as they are (regenerate: gen_m3_deformation.tscn)")
	for stance: StringName in STANCES:
		for id: StringName in PlaceholderAnims.POLISHED_IDS:
			assert_true(table.figures.has("%s|%s" % [stance, id]), "%s %s is frozen" % [stance, id])
	assert_eq(table.figures.size(), STANCES.size() * PlaceholderAnims.POLISHED_IDS.size(), "and nothing else")
	var rest := SkinnedView.skin_vertices(mi, rig, MotionProbe.rest_globals(rig))
	for key: String in ["boxer|walk_forward", "relaxed|downed_front"]:
		var parts := key.split("|")
		var live := MotionProbe.clip_strain(mi, rig, rest, _clip(StringName(parts[1]), StringName(parts[0]), 1.0, false))
		var frozen: Dictionary = table.figures[key]
		for field: String in ["high", "low", "max", "min"]:
			assert_almost_eq(float(live[field]), float(frozen[field]), 1e-4, "%s %s: live %.4f, frozen %.4f" % [key, field, live[field], frozen[field]])


func test_the_idle_stays_off_the_shoulders_worst_range() -> void:
	# The breathing and the bounce are small: at no phase of the idle does any bone go further from the
	# stance than the amplitudes say, and the shoulder, whose worst range is the arm raise, moves a few degrees.
	var anim := _clip(&"idle")
	var g := PlaceholderPoses.guard()
	for bone: StringName in [&"LeftShoulder", &"RightShoulder", &"LeftUpperArm", &"RightUpperArm"]:
		var rest := PlaceholderBody.euler_basis(g.get(bone, Vector3.ZERO)).get_rotation_quaternion()
		var worst := 0.0
		for i: int in 120:
			worst = maxf(worst, _rotation(anim, bone, anim.length * float(i) / 120.0).angle_to(rest))
		assert_lt(rad_to_deg(worst), 5.0, "%s stays within 5 degrees of the guard in the idle (%.2f)" % [bone, rad_to_deg(worst)])


# --- The acts -------------------------------------------------------------------------------------


func test_the_motion_acts_are_named_and_no_title_is_inside_another() -> void:
	var node := Node.new()
	add_child_autofree(node)
	var acts: Array[Dictionary] = LookMotionActs.acts(node)
	var slugs: Array[StringName] = []
	for act: Dictionary in acts:
		slugs.append(act.slug)
		assert_true(String(act.title).begins_with("Look: "), "%s starts with Look:" % act.title)
		assert_true((act.fn as Callable).is_valid(), "%s has an act" % act.title)
	assert_eq(slugs, [&"c12", &"m1", &"m2", &"m3", &"m4"] as Array[StringName])
	var all: Array[Dictionary] = []
	all.append_array(acts)
	all.append_array(LookActs.acts(node))
	for act: Dictionary in acts:
		var matches := 0
		for other: Dictionary in all:
			if String(other.title).to_lower().contains(String(act.title).to_lower()) or String(act.title).to_lower().contains(String(other.title).to_lower()):
				matches += 1
		assert_eq(matches, 1, "'%s' picks one act" % act.title)


func test_the_extremes_are_the_strain_tests_flexes_and_the_lying_poses() -> void:
	var labels: Array[String] = []
	for row: Dictionary in LookMotionActs.extremes():
		labels.append(row.label)
	for want: String in ["guard", "elbow_150", "arm_raise_140", "knee_130", "spine_twist", "deep_knee_bend", "hold_knee",
			"ko_back", "ko_front", "downed_back", "downed_front"]:
		assert_has(labels, want)
	var rig := _rig(PlaceholderPoses.STANCE_BOXER, 1.0, true)
	for row: Dictionary in LookMotionActs.extremes():
		LookMotionActs.hold(rig, row.pose)
		var hips := PlaceholderAnims.resolve_hips(row.pose)
		var expected := PlaceholderBody.pose_globals(row.pose, hips, 1.0)
		var bone := rig.skeleton.find_bone(&"RightHand")
		var got := rig.skeleton.get_bone_global_pose(bone)
		assert_almost_eq(got.origin, (expected[&"RightHand"] as Transform3D).origin, Vector3.ONE * 0.002, "%s: the rig shows the pose" % row.label)
