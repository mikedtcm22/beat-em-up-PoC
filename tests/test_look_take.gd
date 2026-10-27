extends GutTest
## The long take as a look act (P3-early): "Look: Punk at 1 m, the long take" plays
## game/debug/showcase_script.gd on one Punk in the real crowd room, headless, to its end: a mark for
## every step of the script (and the turntable's quarters), rectangles inside the frame, the view
## down for the lying bodies and back, nothing left standing for the next act. The script and its
## runner are tested in test_showcase.gd.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const TITLE := "Look: Punk at 1 m, the long take"
## A take is 40 s of ticks; the act runs a settle before it and a tail after it.
const MAX_TICKS := 3000
const ROOM_FRAME := Vector2(1600.0, 900.0)


## The crowd bot that stops instead of quitting the test run's tree when its acts are done.
class QuietBot extends "res://tests/bot/crowd_bot.gd":
	var finished: bool = false
	var lowest_pitch: float = 0.0

	func _quit() -> void:
		clear_enemies()
		finished = true

	func _physics_process(delta: float) -> void:
		super(delta)
		if player != null:
			lowest_pitch = minf(lowest_pitch, player.look_pitch)


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func after_all() -> void:
	OS.delay_msec(250)


func _lines(bot: Variant, kind: String) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var seen := {}
	for line: String in bot.log_lines:
		if line.begins_with(kind + " ") and not seen.has(line):
			seen[line] = true
			out.append(line.split(" "))
	return out


## The act has printed its `start` mark.
func _started(bot: Variant) -> bool:
	for line: String in bot.log_lines:
		if line.begins_with("LOOK-MARK c14") and line.ends_with(" start"):
			return true
	return false


func test_the_long_take_plays_the_script_to_its_end_and_marks_every_step() -> void:
	var bot := QuietBot.new()
	bot.act_filter = TITLE
	add_child_autofree(bot)
	for i in MAX_TICKS:
		await get_tree().physics_frame
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished within %d ticks" % MAX_TICKS)
	var marks := {}
	var frames: Array[int] = []
	for mark in _lines(bot, "LOOK-MARK"):
		assert_eq(mark[1], "c14", "the slug")
		marks[mark[3]] = int(mark[2].trim_prefix("f"))
		frames.append(int(mark[2].trim_prefix("f")))
	assert_has(marks, "start")
	assert_has(marks, "end")
	for step: Dictionary in ShowcaseScript.STEPS:
		assert_has(marks, String(step.name), "a still of %s" % step.name)
	for quarter in ["turntable_1_of_4", "turntable_2_of_4", "turntable_3_of_4"]:
		assert_has(marks, quarter, "the turntable's quarters")
	assert_gte(int(marks["end"]) - int(marks["start"]), 2300, "the act runs about 40 s (%d frames)" % (int(marks["end"]) - int(marks["start"])))
	# The marks come in the order of the script.
	var last := -1
	for step: Dictionary in ShowcaseScript.STEPS:
		var at := int(marks[String(step.name)])
		assert_gt(at, last, "%s is marked after the step before it" % step.name)
		last = at
	# Every rectangle inside the 1600x900 frame, and the three regions printed for the first mark.
	var regions := {}
	for rect in _lines(bot, "LOOK-RECT"):
		assert_eq(rect[1], "c14")
		assert_between(int(rect[4]), 0, int(ROOM_FRAME.x))
		assert_true(int(rect[4]) + int(rect[6]) <= int(ROOM_FRAME.x) and int(rect[5]) + int(rect[7]) <= int(ROOM_FRAME.y), " ".join(rect))
		regions[rect[3]] = true
	for region in ["head", "hands", "body"]:
		assert_has(regions, region, "a %s rectangle" % region)
	var take := _lines(bot, "LOOK-TAKE")
	assert_eq(take.size(), 1)
	assert_eq(take[0][2], "40.0", "the take's length")
	assert_eq(take[0][-1], "finished", "the take played to its end")
	assert_lt(bot.lowest_pitch, deg_to_rad(-20.0), "the view looked down for the lying bodies (%.0f degrees)" % rad_to_deg(bot.lowest_pitch))
	assert_true(bot.caption.visible, "the caption is back when the act is over")


func test_the_long_take_hides_the_caption_freezes_the_ai_and_clears_up() -> void:
	var bot := QuietBot.new()
	bot.act_filter = TITLE
	add_child_autofree(bot)
	var at_start := {}
	for i in MAX_TICKS:
		await get_tree().physics_frame
		if at_start.is_empty() and _started(bot):
			at_start = {caption = bot.caption.visible, frozen = Tuning.data.ai_frozen, god = Tuning.data.god_mode}
		if bot.finished:
			break
	assert_false(at_start.get("caption", true), "the caption is hidden during the act")
	assert_true(at_start.get("frozen", false), "the AI is frozen")
	assert_true(at_start.get("god", false), "god mode is on")
	assert_eq(get_tree().get_nodes_in_group(&"ai_enemy").size(), 0, "the Punk is cleared with the act's end")


func test_the_f4_showcase_act_switches_the_cheat_on_walks_round_the_punk_and_puts_the_game_back() -> void:
	var bot := QuietBot.new()
	bot.act_filter = "Look: F4 Showcase Punk"
	add_child_autofree(bot)
	for i in MAX_TICKS:
		await get_tree().physics_frame
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished")
	var states := {}
	for line: String in bot.log_lines:
		if line.begins_with("LOOK-SHOWCASE ") and not line.contains("skipped"):
			var when := line.trim_prefix("LOOK-SHOWCASE ").split(":")[0]
			states[when] = line
	assert_eq(states.keys().size(), 3, "before, on and off are logged: %s" % [states.keys()])
	assert_true(String(states.before).contains("on false"), states.before)
	assert_true(String(states.on).contains("on true"), states.on)
	assert_true(String(states.on).contains("Freeze AI true"), "Freeze AI while it shows")
	assert_true(String(states.off).contains("on false"), states.off)
	# Freeze AI and the enemy counts after are the ones before.
	var before: String = String(states.before).split(", Freeze AI")[1]
	var after: String = String(states.off).split(", Freeze AI")[1]
	assert_eq(after.replace("Freeze AI ", ""), before.replace("Freeze AI ", ""), "the game is as it was: %s / %s" % [before, after])
	var marks := {}
	for line: String in bot.log_lines:
		if line.begins_with("LOOK-MARK c15"):
			marks[line.split(" ")[3]] = true
	for label in ["start", "f4_open", "showcase_on", "round_t000", "showcase_off", "end"]:
		assert_has(marks, label, "a mark at %s" % label)
