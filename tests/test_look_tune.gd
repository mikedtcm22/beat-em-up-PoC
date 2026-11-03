extends GutTest
## The look-tuning acts (F-look, M4-plan A11 and the slice gate's gaps 2, 6 and 11): the act file lists
## its acts with titles a capture filter can pick one by, no other act file's title is inside one of
## them (or they inside another's), both bots (the crowd room's and the training room's) run the
## band act headless, turning the sun front-lit and back-lit, and the probe's functions the acts use
## are checked on synthetic frames in tests/test_look_post.gd.

const TuneActs := preload("res://tests/bot/acts/look_tune_acts.gd")
const TuneBotScript := preload("res://tests/bot/look_tune_bot.gd")
const SLUGS: Array[StringName] = [&"t1", &"t2", &"t3", &"t4", &"t5", &"t6", &"t7", &"t8"]
const BANDS_ACT := "Look: tune bands at 1 m"
const MAX_TICKS := 900


## The crowd bot that stops instead of quitting the test run's tree when its acts are done.
class QuietCrowdBot extends "res://tests/bot/crowd_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		clear_enemies()
		finished = true


## The training room's look-tuning bot, stopped the same way.
class QuietTuneBot extends "res://tests/bot/look_tune_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		clear_enemies()
		finished = true


func after_all() -> void:
	OS.delay_msec(250)


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _bare_node() -> Node:
	var node := Node.new()
	autofree(node)
	return node


func _run_bot(bot: Variant) -> void:
	for i in MAX_TICKS:
		await get_tree().physics_frame
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished within %d ticks" % MAX_TICKS)


func _lines(bot: Variant, kind: String) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var seen := {}
	for line: String in bot.log_lines:
		if line.begins_with(kind + " ") and not seen.has(line):
			seen[line] = true
			out.append(line.split(" "))
	return out


func test_the_act_file_lists_the_tuning_acts_with_picking_titles() -> void:
	var acts := TuneActs.acts(_bare_node())
	var slugs: Array[StringName] = []
	for act in acts:
		slugs.append(act.slug)
		assert_true(String(act.title).begins_with("Look: tune "), "%s starts with Look: tune" % act.title)
		assert_eq(act.cam, &"first_person")
		assert_true((act.fn as Callable).is_valid(), "%s has an act" % act.title)
	assert_eq(slugs, SLUGS, "T1 to T8")
	for act in acts:
		var matches := 0
		for other in acts:
			if String(other.title).to_lower().contains(String(act.title).to_lower()):
				matches += 1
		assert_eq(matches, 1, "'%s' picks one act" % act.title)


func test_no_other_acts_title_is_inside_a_tuning_acts_or_the_other_way_round() -> void:
	# The crowd bot collects every acts file: a filter that is a substring of two titles would record
	# both (the before pack's rule).
	var bot := QuietCrowdBot.new()
	autofree(bot)
	var mine := TuneActs.acts(bot)
	var all := bot._collect_acts()
	var mine_titles: Array[String] = []
	for act in mine:
		mine_titles.append(String(act.title).to_lower())
	var seen := 0
	for act in all:
		var title := String(act.title).to_lower()
		if mine_titles.has(title):
			seen += 1
			continue
		for own: String in mine_titles:
			assert_false(title.contains(own), "'%s' is inside '%s'" % [own, title])
			assert_false(own.contains(title), "'%s' is inside '%s'" % [title, own])
	assert_eq(seen, mine.size(), "the crowd bot loads every tuning act by name")


func test_the_crowd_room_runs_the_band_act_front_lit_then_back_lit() -> void:
	var bot := QuietCrowdBot.new()
	bot.act_filter = BANDS_ACT
	add_child_autofree(bot)
	await _run_bot(bot)
	var started := _lines(bot, "LOOK-TUNE")
	assert_gt(started.size(), 0, "the act says which room and look it ran in")
	assert_eq(started[0][1], "CrowdRoom")
	var labels: Array[String] = []
	for mark in _lines(bot, "LOOK-MARK"):
		assert_eq(mark[1], "t1")
		labels.append(mark[3])
	assert_eq(labels, ["start", "front_lit", "back_lit", "end"] as Array[String])
	# Each lit mark has its rectangles (the Punk's head, hands and body), and the bot's tunables are
	# put back by the next act's reset.
	assert_gt(_lines(bot, "LOOK-RECT").size(), 3)


func test_the_training_room_runs_the_same_act_with_its_own_bot() -> void:
	var bot := QuietTuneBot.new()
	bot.act_filter = BANDS_ACT
	add_child_autofree(bot)
	await _run_bot(bot)
	var started := _lines(bot, "LOOK-TUNE")
	assert_gt(started.size(), 0)
	assert_eq(started[0][1], "TestRoom", "the training room")
	var labels: Array[String] = []
	for mark in _lines(bot, "LOOK-MARK"):
		labels.append(mark[3])
	assert_eq(labels, ["start", "front_lit", "back_lit", "end"] as Array[String])
	assert_true(bot.caption.visible, "the caption is back when the acts are over")


func test_back_lit_turns_the_sun_half_a_circle() -> void:
	var bot := QuietTuneBot.new()
	bot.act_filter = "Look: tune lineup"
	add_child_autofree(bot)
	var base_yaw := Tuning.data.look_sun_yaw_deg
	var yaws: Array[float] = []
	for i in MAX_TICKS:
		await get_tree().physics_frame
		var sun := bot.room.get_node_or_null("Sun") as DirectionalLight3D if bot.room != null else null
		if sun != null and (yaws.is_empty() or not is_equal_approx(yaws[yaws.size() - 1], sun.rotation_degrees.y)):
			yaws.append(sun.rotation_degrees.y)
		if bot.finished:
			break
	assert_true(bot.finished)
	assert_true(yaws.any(func(y: float) -> bool: return is_equal_approx(y, base_yaw)), "front-lit is the room's own sun")
	assert_true(yaws.any(func(y: float) -> bool: return is_equal_approx(absf(wrapf(y - base_yaw, -180.0, 180.0)), 180.0)),
			"back-lit is the sun turned half a circle")


func test_the_lineup_act_runs_in_the_training_room_and_marks_its_punk() -> void:
	var bot := QuietTuneBot.new()
	bot.act_filter = "Look: tune lineup"
	add_child_autofree(bot)
	await _run_bot(bot)
	var rects := _lines(bot, "LOOK-RECT")
	assert_gt(rects.size(), 0, "the Punk of the lineup has its rectangles")
