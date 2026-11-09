extends GutTest
## R4-SHOTS: the video's first-person lens is narrower than the game's (the arm is less stretched), the blind set's stills have no
## symmetric stance and no two copies of one model in one pose, and Ox's stills are turned off the lens.

const STILLS_DIR := "res://video/stills"
const SHOTS_DIR := "res://video/shots"
## The video's first-person field of view band (degrees, horizontal): about 70-75 for the stills, against the game's 90. Round 5 narrows the
## trailer's first-person shots to 55-60 (test_r5_shots_staging.gd holds the twin assertion), set through the shot's data at run time.
const FOV_MIN := 70.0
const FOV_MAX := 75.0
const TRAILER_FOV_MIN := 55.0
const TRAILER_FOV_MAX := 60.0
## How far (degrees) a figure must be turned off the viewer to count as a three-quarter stance.
const TURN_MIN_DEG := 15.0


func _stills() -> Array[VideoStillShot]:
	var out: Array[VideoStillShot] = []
	for file in DirAccess.get_files_at(STILLS_DIR):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append(load(STILLS_DIR.path_join(name)) as VideoStillShot)
	return out


func _trailer_shots() -> Array[CineShot]:
	var out: Array[CineShot] = []
	for file in DirAccess.get_files_at(SHOTS_DIR):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") and name.substr(1, 2).is_valid_int() and name.begins_with("t"):
			out.append(load(SHOTS_DIR.path_join(name)) as CineShot)
	return out


func _still(key: StringName) -> VideoStillShot:
	for shot in _stills():
		if shot.key == key:
			return shot
	return null


## The yaw (degrees) at which `actor` faces the free camera of `shot`.
func _viewer_yaw_deg(shot: VideoStillShot, actor: VideoStillActor) -> float:
	var to_viewer := shot.cam_pos - actor.position
	return rad_to_deg(atan2(-to_viewer.x, -to_viewer.z))


func test_every_first_person_still_and_trailer_shot_uses_the_video_lens() -> void:
	var seen := 0
	for shot in _stills():
		if not shot.first_person:
			continue
		seen += 1
		assert_between(shot.first_person_fov_deg, FOV_MIN, FOV_MAX, "%s: first-person FOV" % shot.key)
	assert_gte(seen, 2, "the first-person stills were found")
	var trailer_seen := 0
	for shot in _trailer_shots():
		if not shot.first_person:
			continue
		trailer_seen += 1
		assert_between(shot.first_person_fov_deg, TRAILER_FOV_MIN, TRAILER_FOV_MAX, "%s: first-person FOV (round 5)" % shot.key)
	assert_gt(trailer_seen, 8, "the first-person trailer shots were found")


func test_the_video_lens_is_narrower_than_the_games() -> void:
	var game_fov := float(TuningData.new().fov_deg)
	for shot in _stills():
		if shot.first_person:
			assert_lt(shot.first_person_fov_deg, game_fov, "%s: narrower than the game's %s" % [shot.key, game_fov])


func test_no_still_shows_one_model_twice_in_one_pose() -> void:
	for shot in _stills():
		var seen := {}
		for actor in shot.actors:
			var pose := "%s|%s|%s|%d" % [actor.id, actor.anim, snappedf(actor.yaw_deg, 5.0), actor.hold_tick]
			assert_false(seen.has(pose), "%s: %s twice in one pose" % [shot.key, actor.id])
			seen[pose] = true
			# A second copy of a model also differs in yaw (or in animation), never in the tick alone.
		var same_model := {}
		for actor in shot.actors:
			var key := "%s|%s" % [actor.id, actor.anim]
			if same_model.has(key):
				assert_gt(absf(wrapf(actor.yaw_deg - float(same_model[key]), -180.0, 180.0)), TURN_MIN_DEG,
					"%s: two %s in %s differ in yaw" % [shot.key, actor.id, actor.anim])
			same_model[key] = actor.yaw_deg


func test_street_wide_has_different_stances_and_yaws() -> void:
	var shot := _still(&"street_wide")
	assert_not_null(shot)
	assert_gte(shot.actors.size(), 3, "a group")
	var stances := {}
	var yaws := {}
	for actor in shot.actors:
		assert_eq(actor.facing, VideoStillActor.Facing.YAW, "figures are placed by yaw, not turned to the lens")
		stances[actor.anim] = true
		yaws[snappedf(actor.yaw_deg, 5.0)] = true
	assert_gte(stances.size(), 3, "three stances")
	assert_eq(yaws.size(), shot.actors.size(), "every figure at its own yaw")


func test_ox_is_not_square_to_the_lens() -> void:
	for key: StringName in [&"ox_low", &"ox_closeup"]:
		var shot := _still(key)
		assert_not_null(shot, "%s exists" % key)
		for actor in shot.actors:
			assert_eq(actor.facing, VideoStillActor.Facing.YAW, "%s: Ox is turned by hand" % key)
			var off := absf(wrapf(actor.yaw_deg - _viewer_yaw_deg(shot, actor), -180.0, 180.0))
			assert_gt(off, TURN_MIN_DEG, "%s: Ox faces %.0f degrees off the lens" % [key, off])
	var low := _still(&"ox_low")
	assert_ne(low.actors[0].anim, &"idle", "ox_low is an asymmetric held pose, not the idle guard")
