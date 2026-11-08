extends GutTest
## Smoke test of the still stage: every still's .tres loads as a VideoStillShot, names a distinct key, has
## actors the enemy catalog knows, and the act file and the bot compile.

const SHOTS_DIR := "res://video/stills"
const ACTS_FILE := "res://video/acts/stills_acts.gd"
const BOT_SCENE := "res://video/stage/still_bot.tscn"
## The stills Gate 1 asks for.
const EXPECTED_KEYS: Array[StringName] = [
	&"fp_kicker_lamp", &"fp_punk", &"ox_closeup", &"ox_low", &"roof_silhouette", &"street_wide",
]


func _shots() -> Array[VideoStillShot]:
	var out: Array[VideoStillShot] = []
	for shot in load(ACTS_FILE).call(&"shots"):
		out.append(shot)
	return out


func test_every_still_file_loads_as_a_shot() -> void:
	var files := 0
	for file in DirAccess.get_files_at(SHOTS_DIR):
		if file.ends_with(".tres"):
			files += 1
			assert_true(load(SHOTS_DIR.path_join(file)) is VideoStillShot, "%s is a VideoStillShot" % file)
	assert_eq(_shots().size(), files, "the acts file reads every .tres")


func test_the_six_gate_one_stills_exist() -> void:
	var keys := PackedStringArray()
	for shot in _shots():
		keys.append(String(shot.key))
	keys.sort()
	var expected := PackedStringArray()
	for key in EXPECTED_KEYS:
		expected.append(String(key))
	assert_eq(keys, expected)


func test_a_shot_is_well_formed() -> void:
	for shot in _shots():
		assert_ne(shot.key, &"", "a key")
		assert_true(shot.section >= 0, "%s: a section" % shot.key)
		assert_false(shot.actors.is_empty(), "%s: has an actor" % shot.key)
		for spec in shot.actors:
			assert_not_null(EnemyCatalog.scene(spec.id), "%s: catalog id %s" % [shot.key, spec.id])
		if not shot.first_person:
			assert_gt(shot.cam_pos.distance_to(shot.cam_look_at), 0.1, "%s: the camera looks somewhere" % shot.key)


func test_the_act_file_makes_one_act_per_shot() -> void:
	var acts: Array[Dictionary] = load(ACTS_FILE).call(&"acts", null)
	assert_eq(acts.size(), _shots().size())
	for act in acts:
		assert_true(String(act.title).begins_with("Still: "), "act title %s" % act.title)
		assert_true(act.cam in [&"first_person", &"free_fly"], "act camera %s" % act.cam)


func test_the_bot_scene_compiles() -> void:
	var scene := load(BOT_SCENE) as PackedScene
	assert_not_null(scene, "the bot scene loads")
	var script := load("res://video/stage/still_bot.gd") as GDScript
	assert_true(script.can_instantiate(), "the bot script compiles")
	assert_true((load("res://video/stage/still_grab.gd") as GDScript).can_instantiate(), "the grab script compiles")
