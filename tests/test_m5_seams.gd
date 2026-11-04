extends GutTest
## The seams of the assembled Mission 1, walked as the player would (no teleport): the level bot's
## route walk from one cleared arena, through its open ahead barrier and up the stair, into the next
## arena's lock volume. The two seams between sections:
##   A3 (street's last arena, stair 1 and the seam shutter at z -53, landing on the terrace) -> A4
##   A6 (the top roof, stair 3 and the gate) -> A7 (the boss roof)
## plus the stair 2 walk A4 -> A5, so every ahead barrier of the roofs is walked through once. Each
## walk asserts: the ahead barrier was open (the clear opened it), the next arena locked, it locked on
## a player who walked in (not a teleport), no BLOCKED or STALL line, and its behind barrier closed
## behind him. No fights (waves off): the done-when plays those, with each ahead barrier asserted shut.
## A later edit to a section's Exit/Entry, route points, nav links or a barrier's start state fails here.

const MISSION_1 := "res://game/level/mission1/mission1.tscn"
## The most ticks one seam walk may take.
const WALK_BUDGET_TICKS := 1800
## The most a walk may jump between two ticks (m): a teleport is far more.
const STEP_MAX_M := 1.0


## The level bot that stops instead of quitting the test run's tree.
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


func _make_bot() -> void:
	_bot = QuietBot.new()
	_bot.act_filter = "no act has this title"
	_bot.presentation = false
	_bot.level_path = MISSION_1
	add_child_autofree(_bot)
	for i in 600:
		await get_tree().physics_frame
		if _bot.finished:
			break
	assert_true(_bot.finished, "the bot set itself up")
	assert_eq(_bot.level.sections.size(), 3, "the whole level: street, roofs, boss roof")
	assert_eq(_bot.level.arenas().size(), 7, "seven arenas")
	Tuning.set_value(&"god_mode", true)


## Cleared arena `from` (the player at its first route point, locked and then cleared by hand: no
## fight), then the bot walks the route to arena `from + 1`, which must lock on him.
func _walk_seam(from: int) -> void:
	var level := _bot.level
	var arenas := level.arenas()
	var here := arenas[from]
	var next := arenas[from + 1]
	level.start_at_arena(from)
	_bot._route_start(from)
	_bot.set_waves(false)
	for i in 10:
		await get_tree().physics_frame
	var tag := "%s -> %s" % [here.arena_id, next.arena_id]
	assert_eq(here.state, Arena.State.LOCKED, "%s: %s locked on the player standing at its first route point" % [tag, here.arena_id])
	assert_not_null(here.ahead, "%s has an ahead barrier" % here.arena_id)
	assert_true(here.ahead.is_closed(), "%s: its ahead barrier is shut while it is locked" % tag)
	here.clear()
	assert_false(here.ahead.is_closed(), "%s: the clear opens its ahead barrier" % tag)
	assert_eq(next.state, Arena.State.WAITING, "%s: the next arena waits" % tag)
	assert_true(next.armed, "%s: the clear armed the next arena" % tag)
	var locks: Array[StringName] = []
	var on_lock := func(arena: Node3D) -> void:
		locks.append((arena as Arena).arena_id)
	CombatEvents.arena_locked.connect(on_lock)
	# Walk, sampling each tick for a jump (a teleport) and the deepest the player got.
	var state := {done = false, ok = false, jump = 0.0, last = _bot.player.global_position}
	var runner := func() -> void:
		state.ok = await _bot.walk_route(from + 1)
		state.done = true
	runner.call()
	var ticks := 0
	while not state.done and ticks < WALK_BUDGET_TICKS:
		await get_tree().physics_frame
		ticks += 1
		var at: Vector3 = _bot.player.global_position
		state.jump = maxf(state.jump, at.distance_to(state.last))
		state.last = at
	CombatEvents.arena_locked.disconnect(on_lock)
	assert_true(state.done, "%s: the walk ended inside %d ticks (took %d)" % [tag, WALK_BUDGET_TICKS, ticks])
	assert_true(state.ok, "%s: the walk reached the lock" % tag)
	assert_eq(next.state, Arena.State.LOCKED, "%s: %s locked" % [tag, next.arena_id])
	assert_eq(locks, [next.arena_id] as Array[StringName], "%s: exactly the next arena locked" % tag)
	assert_lt(float(state.jump), STEP_MAX_M, "%s: he walked the whole way (largest step %.2f m)" % [tag, state.jump])
	assert_true(next.contains(_bot.player.global_position), "%s: he stands inside %s's volume" % [tag, next.arena_id])
	assert_true(next.past_inset(_bot.player.global_position), "%s: and past its behind barrier's inset" % tag)
	if next.behind:
		assert_true(next.behind.is_closed(), "%s: the barrier behind him closed" % tag)
	for line in _bot.log_lines:
		assert_false(line.begins_with("BLOCKED") or line.begins_with("STALL"), "%s: no walk gave up: %s" % [tag, line])


func test_a3_to_a4_the_street_roofs_seam_stair_one_and_the_shutter() -> void:
	await _make_bot()
	await _walk_seam(2)


func test_a4_to_a5_stair_two() -> void:
	await _make_bot()
	await _walk_seam(3)


func test_a6_to_a7_the_roofs_boss_roof_gate() -> void:
	await _make_bot()
	await _walk_seam(5)
