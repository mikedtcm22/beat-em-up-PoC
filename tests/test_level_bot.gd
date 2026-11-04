extends GutTest
## The level-run bot (tests/bot/level_bot.gd, Milestone 5 BOT) on the two-section test strip, headless,
## in god mode: run_level(0, 1) clears both arenas inside a frame budget and the log carries every
## line (ARENA+, WAVE, ARENA-, LEVEL); the walk never goes into a closed barrier; a Punk launched at the
## strip's drop is KO'd by the hazard (HAZARD); a lone section scene is wrapped as a one-section level.

const MISSION_1 := "res://game/level/mission1/mission1.tscn"
const STRIP_A := "res://tests/fixtures/level_strip_a.tscn"
## The most ticks the whole strip run may take (both arenas, the walk between them).
const RUN_BUDGET_TICKS := 5400


## The level bot that stops instead of quitting the test run's tree. No act matches its filter, so
## it sets itself up and finishes; the tests then call its helpers.
class QuietBot extends "res://tests/bot/level_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		clear_enemies()
		finished = true


var _bot: QuietBot


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func after_all() -> void:
	OS.delay_msec(250)


func _make_bot(path: String = "") -> void:
	_bot = QuietBot.new()
	_bot.act_filter = "no act has this title"
	_bot.presentation = false
	if path != "":
		_bot.level_path = path
	add_child_autofree(_bot)
	for i in 600:
		await get_tree().physics_frame
		if _bot.finished:
			break
	assert_true(_bot.finished, "the bot set itself up")
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"wave_gap_s", 1.0)


func _count(prefix: String) -> int:
	var n := 0
	for line in _bot.log_lines:
		if line.begins_with(prefix + " "):
			n += 1
	return n


func test_run_level_clears_both_arenas_and_logs_every_line() -> void:
	await _make_bot()
	var started := Engine.get_physics_frames()
	var ok: bool = await _bot.run_level(0, 1, false, false)
	assert_true(ok, "run_level(0, 1) cleared both arenas")
	assert_lt(Engine.get_physics_frames() - started, RUN_BUDGET_TICKS, "inside the frame budget")
	for arena in _bot.level.arenas():
		assert_eq(arena.state, Arena.State.CLEARED, "%s cleared" % arena.arena_id)
	assert_eq(_count("ARENA+"), 2, "one ARENA+ per arena")
	assert_eq(_count("ARENA-"), 2, "one ARENA- per arena")
	assert_gte(_count("WAVE"), 2, "waves were logged")
	assert_eq(_count("LEVEL"), 1, "one LEVEL line")
	var level_line := ""
	for line in _bot.log_lines:
		if line.begins_with("LEVEL "):
			level_line = line
	var parts := level_line.split(" ")
	assert_eq(parts.size(), 3, "LEVEL f<frame> <seconds>")
	assert_true(parts[1].begins_with("f") and float(parts[2]) > 1.0, "with a frame and the seconds: %s" % level_line)
	for line in _bot.log_lines:
		if line.begins_with("ARENA- "):
			assert_gt(float(line.split(" ")[3]), 0.0, "an arena time: %s" % line)


func test_the_walk_never_goes_into_a_closed_barrier() -> void:
	await _make_bot()
	_bot.barrier_wait_s = 2.0
	_bot.level.start_at_arena(0)
	_bot._route_start(0)
	# Arena 0 is not cleared, so its ahead barrier (the stair head's shutter) stays shut: the walk to
	# arena 1 must stop short of it and give up.
	var arena := _bot.level.arenas()[0]
	var shutter: Barrier = arena.ahead
	var deepest := -INF
	# walk_route is a coroutine: drive it and sample the player each tick.
	await _drive(func() -> bool: return await _bot.walk_route(1), 2400, func() -> void:
		deepest = maxf(deepest, shutter.past(_bot.player.global_position)))
	assert_true(shutter.is_closed(), "the shutter stayed shut")
	assert_lt(deepest, 0.0, "the player never reached the shutter")
	assert_eq(arena.state, Arena.State.LOCKED, "the arena locked behind him on the way")
	assert_eq(_count("BLOCKED"), 1, "the wait at the shutter was logged")


## Run `body` (a coroutine returning bool) to its end, calling `sample` every tick; at most `limit` ticks.
func _drive(body: Callable, limit: int, sample: Callable) -> void:
	var state := {done = false}
	var runner := func() -> void:
		await body.call()
		state.done = true
	runner.call()
	for i in limit:
		if state.done:
			break
		await get_tree().physics_frame
		sample.call()
	assert_true(state.done, "the walk ended within %d ticks" % limit)


func test_knock_off_logs_a_hazard_ko() -> void:
	await _make_bot()
	var ok: bool = await _bot.knock_off()
	assert_true(ok, "the hazard took the launched Punk")
	assert_eq(_count("HAZARD"), 1, "one HAZARD line")
	assert_eq(_bot.hazard_kos, 1)


func test_the_knock_off_hazard_is_chosen_by_the_arena_the_act_starts_from() -> void:
	await _make_bot(MISSION_1)
	var by_from: Array[int] = []
	for from in _bot.level.arenas().size():
		var found := _bot.first_hazard(from)
		by_from.append(int(found.arena) if not found.is_empty() else -1)
	gut.p("first hazard arena by --from 0..6: %s" % [by_from])
	assert_eq(by_from[0], 3, "from the start: the terrace's drop, the first of the level")
	assert_eq(by_from[3], 3, "--from=3: the terrace's")
	assert_eq(by_from[4], 4, "--from=4: the catwalk's")
	assert_eq(by_from[5], 5, "--from=5: the top roof's")
	assert_eq(by_from[6], 6, "--from=6: the boss roof's")
	var boss := _bot.first_hazard(6)
	assert_true(boss.hazard.get_path().get_concatenated_names().contains("BossRoof"), "and it is the boss roof's own edge")
	var terrace := _bot.first_hazard(3)
	assert_eq(String(terrace.hazard.name), "DropFront", "the terrace's is DropFront, not the catwalk's drop above it (%s)" % terrace.hazard.name)
	var catwalk := _bot.first_hazard(4)
	assert_true(String(catwalk.hazard.name) == "DropCatwalk", "the catwalk's is DropCatwalk (%s)" % catwalk.hazard.name)


func test_the_knock_off_works_at_the_terrace_the_catwalk_the_top_roof_and_the_boss_roof() -> void:
	await _make_bot(MISSION_1)
	for from in [3, 4, 5, 6]:
		var before := _bot.hazard_kos
		var ok: bool = await _bot.knock_off(from)
		assert_true(ok, "--from=%d: the hazard took the launched Punk" % from)
		assert_eq(_bot.hazard_kos, before + 1, "--from=%d: one more HAZARD" % from)
		_bot.clear_enemies()


func test_a_lone_section_scene_is_wrapped_as_a_level() -> void:
	await _make_bot(STRIP_A)
	assert_not_null(_bot.level, "a level was built")
	assert_eq(_bot.level.sections.size(), 1, "one section")
	assert_eq(_bot.level.arenas().size(), 1, "its one arena")


func test_the_act_files_list_the_run_acts_and_the_seam_look() -> void:
	await _make_bot()
	var titles: Array[String] = []
	for act in _bot._collect_acts():
		titles.append(act.title)
	assert_eq(titles, ["Run: held back", "Run: knock-off", "Run: timing", "Look: seams"] as Array[String])
