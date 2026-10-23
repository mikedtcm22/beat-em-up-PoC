extends GutTest
## ComboParser (game/combat/combo_parser.gd): the Spec §4 cadence rules, driven frame by
## frame in the documented per-frame call order. Fixtures mirror the move tree, move sets
## and frame data in docs/ARCHITECTURE.md and are built in code (no .tres loads), so the
## suite does not depend on the move-data module.
##
## Frame convention used by the expectations below: a move started on sim frame s plays its
## frame 0 on s, its first recovery frame on s + startup + active, and its last recovery
## frame on s + total - 1. "f = k" means the press lands on the k-th FREE frame after that
## (0-based), i.e. parser.frames_since_recovery == k when select() runs.

const P := CombatTypes.IN_PUNCH
const K := CombatTypes.IN_KICK
const P_HOLD := CombatTypes.IN_PUNCH_HOLD
const RB := CombatTypes.IN_BACK
const JUMP := &"JUMP"
const DODGE := &"DODGE"
const GRAB := &"GRAB"
const NORMAL := CombatTypes.BranchTiming.NORMAL
const PAUSE := CombatTypes.BranchTiming.PAUSE
const DOWNED := CombatTypes.COND_DOWNED_TARGET_NEAR
const APEX := CombatTypes.COND_AT_APEX
const LIGHT := CombatTypes.HitTier.LIGHT
const HEAVY := CombatTypes.HitTier.HEAVY
const FINISHER := CombatTypes.HitTier.FINISHER
## One minute of sim frames at 60 Hz (Spec §1 goal 3).
const ONE_MINUTE_FRAMES := 60 * 60
## Seeds for the randomized mashing tests (fixed, so failures reproduce).
const MASH_SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597]


## One move the simulated owner started.
class Started:
	extends RefCounted
	var id: StringName
	var timing: StringName
	var chain_step: int
	var input: StringName
	## Sim frame on which the move's frame 0 played.
	var frame: int
	## parser.frames_since_recovery when the move was chosen (-1 from recovery or auto).
	var f: int
	var finisher: bool


## Stand-in for the player controller. Runs one move at a time through its startup, active
## and recovery frames and calls the parser in the documented per-frame order:
## tick, release/press, select (FREE or cancellable recovery), notify_started, and after
## the last recovery frame notify_recovery_ended + take_auto_next.
class OwnerSim:
	extends RefCounted
	var parser: ComboParser
	## Passed to every select() call.
	var conditions: Dictionary = {}
	## Running move (null when FREE) and the 0-based frame it plays on the next step().
	var move: MoveData
	var move_frame: int = 0
	## Sim frame the next step() runs (frozen hitstop frames do not count).
	var frame: int = 0
	## Sim frame on which the last finished move played its final recovery frame.
	var last_end_frame: int = -1
	var started: Array[Started] = []

	func _init(p_parser: ComboParser) -> void:
		parser = p_parser

	## One sim frame. `presses` and `releases` are Arrays of input ids.
	func step(presses: Array = [], releases: Array = []) -> void:
		parser.tick()
		for input: StringName in presses:
			parser.press(input)
		for input: StringName in releases:
			parser.release(input)
		if move == null:
			_try_select(false)
		elif move.is_recovery(move_frame) and move.can_cancel(move_frame):
			_try_select(true)
		if move != null:
			var was_last_frame := move_frame >= move.total_frames() - 1
			move_frame += 1
			if was_last_frame:
				last_end_frame = frame
				move = null
				parser.notify_recovery_ended()
				var next := parser.take_auto_next()
				if next != null:
					_start(next, frame + 1)
		frame += 1

	## Runs `count` steps. `presses` / `releases` map a step offset (0 = the next step) to
	## an Array of inputs.
	func run(presses: Dictionary, count: int, releases: Dictionary = {}) -> void:
		for i: int in count:
			step(presses.get(i, []), releases.get(i, []))

	## Hitstop: input edges still arrive, but no sim frame runs (no tick, no select, the
	## move does not advance). `presses` maps a frozen-frame offset to inputs.
	func freeze(count: int, presses: Dictionary = {}) -> void:
		for i: int in count:
			for input: StringName in presses.get(i, []):
				parser.press(input)

	func idle(count: int) -> void:
		for i: int in count:
			step()

	## Steps without input until no move is running (auto_next moves included).
	func run_until_free(limit: int = 600) -> void:
		var count := 0
		while move != null and count < limit:
			step()
			count += 1

	func ids() -> Array[StringName]:
		var out: Array[StringName] = []
		for record: Started in started:
			out.append(record.id)
		return out

	func timings() -> Array[StringName]:
		var out: Array[StringName] = []
		for record: Started in started:
			out.append(record.timing)
		return out

	func steps() -> Array[int]:
		var out: Array[int] = []
		for record: Started in started:
			out.append(record.chain_step)
		return out

	func frames() -> Array[int]:
		var out: Array[int] = []
		for record: Started in started:
			out.append(record.frame)
		return out

	func last() -> Started:
		if started.is_empty():
			return null
		return started[started.size() - 1]

	func _try_select(in_recovery: bool) -> void:
		var selection := parser.select(in_recovery, conditions)
		if selection != null:
			_start(selection, frame)

	func _start(selection: ComboParser.Selection, first_frame: int) -> void:
		var record := Started.new()
		record.id = selection.move.id
		record.timing = selection.timing
		record.chain_step = selection.chain_step
		record.input = selection.input
		record.frame = first_frame
		record.f = parser.frames_since_recovery
		record.finisher = selection.move.is_finisher()
		started.append(record)
		parser.notify_started(selection)
		move = selection.move
		move_frame = 0


var _moves: Dictionary[StringName, MoveData] = {}
var _ground: MoveSet
var _air: MoveSet
var _hold: MoveSet
var _weapon: MoveSet
var _parser: ComboParser
var _sim: OwnerSim


func before_each() -> void:
	_build_fixtures()
	_parser = _new_parser(_ground)
	_sim = OwnerSim.new(_parser)


# --- Fixtures (docs/ARCHITECTURE.md "Moves", "Move sets", "Branches") -----------------

func _build_fixtures() -> void:
	_moves.clear()
	var jab_1 := _move(&"jab_1", 4, 3, 10, LIGHT)
	var jab_2 := _move(&"jab_2", 4, 3, 10, LIGHT)
	var hook := _move(&"hook", 6, 3, 14, HEAVY)
	var uppercut := _move(&"uppercut", 8, 3, 22, FINISHER)
	var body_flurry := _move(&"body_flurry", 2, 2, 6, LIGHT)
	var shove := _move(&"shove", 6, 3, 18, FINISHER)
	var spinning_backfist := _move(&"spinning_backfist", 12, 3, 20, FINISHER)
	var front_kick := _move(&"front_kick", 7, 3, 14, LIGHT)
	var roundhouse := _move(&"roundhouse", 9, 3, 16, HEAVY)
	var spinning_heel := _move(&"spinning_heel", 12, 5, 24, FINISHER)
	var stomp_kick := _move(&"stomp_kick", 10, 3, 22, FINISHER)
	var push_kick := _move(&"push_kick", 8, 3, 20, FINISHER)
	var haymaker := _move(&"haymaker", 14, 3, 26, FINISHER)
	var flying_kick := _move(&"flying_kick", 5, 8, 14, HEAVY)
	var spin_kick := _move(&"spin_kick", 6, 10, 16, HEAVY)
	var back_elbow := _move(&"back_elbow", 5, 3, 18, HEAVY)
	var knee := _move(&"knee", 5, 3, 12, LIGHT)
	var throw := _move(&"throw", 8, 2, 20, HEAVY)
	var stomp := _move(&"stomp", 8, 3, 14, LIGHT)
	var pipe_swing_1 := _move(&"pipe_swing_1", 7, 3, 12, LIGHT)
	var pipe_swing_2 := _move(&"pipe_swing_2", 7, 3, 12, HEAVY)
	var pipe_swing_3 := _move(&"pipe_swing_3", 9, 4, 20, FINISHER)

	jab_1.branches.append(_branch(P, jab_2))
	jab_1.branches.append(_branch(P, body_flurry, PAUSE))
	jab_2.branches.append(_branch(P, hook))
	jab_2.branches.append(_branch(K, push_kick))
	jab_2.branches.append(_branch(P, spinning_backfist, PAUSE))
	hook.branches.append(_branch(P, uppercut))
	body_flurry.repeat_input = P
	body_flurry.repeat_max = 6
	body_flurry.auto_next = shove
	front_kick.branches.append(_branch(K, roundhouse))
	front_kick.branches.append(_branch(K, stomp_kick, PAUSE))
	roundhouse.branches.append(_branch(K, spinning_heel))
	pipe_swing_1.branches.append(_branch(P, pipe_swing_2))
	pipe_swing_2.branches.append(_branch(P, pipe_swing_3))

	_ground = MoveSet.new()
	_ground.id = &"ground"
	_ground.root_branches.append(_branch(K, stomp, NORMAL, DOWNED))
	_ground.root_branches.append(_branch(K, front_kick))
	_ground.root_branches.append(_branch(P, jab_1))
	_ground.root_branches.append(_branch(P_HOLD, haymaker))
	_ground.root_branches.append(_branch(RB, back_elbow))
	_ground.interrupt_branches.append(_branch(RB, back_elbow))

	_air = MoveSet.new()
	_air.id = &"air"
	_air.root_branches.append(_branch(K, spin_kick, NORMAL, APEX))
	_air.root_branches.append(_branch(K, flying_kick))

	_hold = MoveSet.new()
	_hold.id = &"hold"
	_hold.root_branches.append(_branch(P, knee))
	_hold.root_branches.append(_branch(K, throw))

	_weapon = MoveSet.new()
	_weapon.id = &"weapon"
	_weapon.root_branches.append(_branch(P, pipe_swing_1))
	_weapon.root_branches.append(_branch(K, stomp, NORMAL, DOWNED))
	_weapon.root_branches.append(_branch(K, front_kick))
	_weapon.root_branches.append(_branch(RB, back_elbow))
	_weapon.interrupt_branches.append(_branch(RB, back_elbow))


func _move(id: StringName, startup: int, active: int, recovery: int,
		tier: CombatTypes.HitTier) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.display_name = String(id)
	move.startup = startup
	move.active = active
	move.recovery = recovery
	move.tier = tier
	_moves[id] = move
	return move


func _branch(input: StringName, move: MoveData,
		timing: CombatTypes.BranchTiming = NORMAL, require: StringName = &"") -> ComboBranch:
	var branch := ComboBranch.new()
	branch.input = input
	branch.move = move
	branch.timing = timing
	branch.require = require
	return branch


func _m(id: StringName) -> MoveData:
	return _moves[id]


## A parser configured the way the owner does it: windows copied from TuningData.
func _new_parser(move_set: MoveSet) -> ComboParser:
	var tuning := TuningData.new()
	var parser := ComboParser.new()
	parser.buffer_frames = tuning.input_buffer_frames
	parser.pause_min_frames = tuning.pause_min_frames
	parser.pause_max_frames = tuning.pause_max_frames
	parser.hold_frames = tuning.hold_frames
	parser.move_set = move_set
	return parser


## A hand-made Selection, for driving the parser API directly.
static func _selection(move: MoveData, timing: StringName = &"root",
		step: int = 1) -> ComboParser.Selection:
	var selection := ComboParser.Selection.new()
	selection.move = move
	selection.timing = timing
	selection.chain_step = step
	return selection


## {offset: [input]}: a press at offset 0, then one after each gap.
static func _taps(input: StringName, gaps: Array[int]) -> Dictionary:
	var taps := {0: [input]}
	var at := 0
	for gap: int in gaps:
		at += gap
		taps[at] = [input]
	return taps


## {offset: [input]} for `count` presses starting at `first`, `gap` frames apart.
static func _every(input: StringName, first: int, gap: int, count: int) -> Dictionary:
	var taps := {}
	for i: int in count:
		taps[first + i * gap] = [input]
	return taps


static func _random_gaps(seed_value: int, count: int, low: int, high: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var gaps: Array[int] = []
	for i: int in count:
		gaps.append(rng.randi_range(low, high))
	return gaps


## Runs `prefix` (then lets every move finish), waits `wait` FREE frames and presses
## `input` (so f == wait). Returns what that press started, or null.
func _press_after_chain(prefix: Dictionary, prefix_frames: int, wait: int,
		input: StringName) -> Started:
	var sim := OwnerSim.new(_new_parser(_ground))
	sim.run(prefix, prefix_frames)
	sim.run_until_free()
	sim.idle(wait)
	var before := sim.started.size()
	sim.step([input])
	if sim.started.size() == before:
		return null
	return sim.started[before]


# --- Defaults and bookkeeping --------------------------------------------------------

func test_default_windows_match_tuning_defaults() -> void:
	var parser := ComboParser.new()
	var tuning := TuningData.new()
	assert_eq(parser.buffer_frames, tuning.input_buffer_frames)
	assert_eq(parser.pause_min_frames, tuning.pause_min_frames)
	assert_eq(parser.pause_max_frames, tuning.pause_max_frames)
	assert_eq(parser.hold_frames, tuning.hold_frames)


func test_fresh_parser_has_no_chain_and_selects_nothing() -> void:
	var parser := ComboParser.new()
	assert_null(parser.current)
	assert_eq(parser.chain_step, 0)
	assert_eq(parser.frames_since_recovery, -1)
	assert_eq(parser.repeat_count, 0)
	assert_null(parser.select(false))
	assert_null(parser.select(true))
	assert_null(parser.take_auto_next())
	parser.press(P)
	assert_null(parser.select(false), "no move set: nothing to start")
	assert_true(parser.has_buffered(P), "unmatched press stays buffered")


func test_selection_defaults() -> void:
	var selection := ComboParser.Selection.new()
	assert_null(selection.move)
	assert_eq(selection.input, &"")
	assert_eq(selection.timing, &"root")
	assert_eq(selection.chain_step, 1)


func test_frames_since_recovery_counts_from_the_tick_after_recovery() -> void:
	_parser.press(P)
	var selection := _parser.select(false)
	assert_eq(selection.move, _m(&"jab_1"))
	assert_eq(selection.input, P)
	_parser.notify_started(selection)
	assert_eq(_parser.current, _m(&"jab_1"))
	assert_eq(_parser.chain_step, 1)
	assert_eq(_parser.frames_since_recovery, -1)
	_parser.tick()
	_parser.tick()
	assert_eq(_parser.frames_since_recovery, -1, "still -1 while the move runs")
	_parser.notify_recovery_ended()
	assert_eq(_parser.frames_since_recovery, -1, "starts at 0 on the next tick")
	_parser.tick()
	assert_eq(_parser.frames_since_recovery, 0)
	_parser.tick()
	assert_eq(_parser.frames_since_recovery, 1)


func test_chain_resets_in_tick_once_f_passes_pause_max() -> void:
	_sim.run({0: [P]}, 1)
	_sim.run_until_free()
	_sim.idle(_parser.pause_max_frames + 1)
	assert_eq(_parser.frames_since_recovery, _parser.pause_max_frames)
	assert_eq(_parser.current, _m(&"jab_1"), "f == pause_max keeps the chain")
	assert_eq(_parser.chain_step, 1)
	_sim.idle(1)
	assert_null(_parser.current, "f > pause_max resets the chain")
	assert_eq(_parser.chain_step, 0)
	assert_eq(_parser.frames_since_recovery, -1)


func test_free_select_on_the_recovery_end_frame_is_grace() -> void:
	# An owner that ends the move before selecting on the same frame (f still -1).
	_parser.notify_started(_selection(_m(&"jab_1")))
	_parser.notify_recovery_ended()
	_parser.press(P)
	var selection := _parser.select(false)
	assert_eq(selection.move, _m(&"jab_2"))
	assert_eq(selection.timing, &"chain")


func test_free_select_while_move_still_running_ignores_the_chain() -> void:
	# The owner cut jab_1 short (hit, dodge) without notify_recovery_ended/reset_chain.
	_parser.notify_started(_selection(_m(&"jab_1")))
	_parser.tick()
	_parser.press(P)
	var selection := _parser.select(false)
	assert_eq(selection.move, _m(&"jab_1"))
	assert_eq(selection.timing, &"root")
	assert_eq(selection.chain_step, 1)


func test_notify_started_ignores_null() -> void:
	_parser.notify_started(null)
	_parser.notify_started(ComboParser.Selection.new())
	assert_null(_parser.current)
	assert_eq(_parser.chain_step, 0)


func test_take_auto_next_only_after_recovery_ended() -> void:
	_parser.notify_started(_selection(_m(&"body_flurry"), &"pause", 3))
	assert_null(_parser.take_auto_next(), "move still running")
	_parser.notify_recovery_ended()
	var next := _parser.take_auto_next()
	assert_not_null(next)
	assert_eq(next.move, _m(&"shove"))
	assert_eq(next.timing, &"auto")
	assert_eq(next.input, &"")
	assert_eq(next.chain_step, 4)
	_parser.notify_started(next)
	_parser.notify_recovery_ended()
	assert_null(_parser.take_auto_next(), "shove has no auto_next")


# --- Spec §4: mashing one button always produces a full combo ------------------------

func test_mash_p_every_9_frames_runs_the_punch_chain_then_restarts() -> void:
	_sim.run(_every(P, 0, 9, 11), 100)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook", &"uppercut",
			&"jab_1", &"jab_2", &"hook", &"uppercut"])
	assert_eq(_sim.timings(), [&"root", &"chain", &"chain", &"chain",
			&"root", &"chain", &"chain", &"chain"])
	assert_eq(_sim.steps(), [1, 2, 3, 4, 1, 2, 3, 4])
	# Presses in recovery cancel at once; presses in startup/active fire when recovery
	# opens; uppercut has no branches, so the next chain waits for it to end (frame 60).
	assert_eq(_sim.frames(), [0, 9, 18, 27, 60, 67, 74, 83])
	assert_true(_sim.started[3].finisher, "uppercut ends the chain as a finisher")


func test_mash_p_with_irregular_gaps_runs_the_punch_chain() -> void:
	_sim.run(_taps(P, [4, 10, 5, 7, 4, 9, 6, 10, 4, 8, 5, 10, 7, 4, 6, 9, 5]), 140)
	assert_gte(_sim.started.size(), 5)
	assert_eq(_sim.ids().slice(0, 5), [&"jab_1", &"jab_2", &"hook", &"uppercut", &"jab_1"])
	assert_eq(_sim.timings().slice(0, 5), [&"root", &"chain", &"chain", &"chain", &"root"])
	assert_eq(_sim.steps().slice(0, 5), [1, 2, 3, 4, 1])
	# jab_2 fires when jab_1's recovery opens (the press at 4 was buffered); the press at
	# 14 lands in jab_2's recovery and cancels immediately.
	assert_eq(_sim.frames().slice(0, 3), [0, 7, 14])


func test_mash_p_random_gaps_4_to_10_always_runs_the_full_chain_twice() -> void:
	for seed_value: int in MASH_SEEDS:
		var sim := OwnerSim.new(_new_parser(_ground))
		sim.run(_taps(P, _random_gaps(seed_value, 40, 4, 10)), 220)
		assert_gte(sim.started.size(), 8, "seed %d" % seed_value)
		assert_eq(sim.ids().slice(0, 8), [&"jab_1", &"jab_2", &"hook", &"uppercut",
				&"jab_1", &"jab_2", &"hook", &"uppercut"], "seed %d" % seed_value)
		assert_eq(sim.timings().slice(0, 8), [&"root", &"chain", &"chain", &"chain",
				&"root", &"chain", &"chain", &"chain"], "seed %d" % seed_value)
		assert_eq(sim.steps().slice(0, 8), [1, 2, 3, 4, 1, 2, 3, 4], "seed %d" % seed_value)


func test_k_k_k_is_front_kick_roundhouse_spinning_heel() -> void:
	# front_kick recovery opens at 10, roundhouse (started at 10) at 22.
	_sim.run(_taps(K, [10, 12]), 80)
	assert_eq(_sim.ids(), [&"front_kick", &"roundhouse", &"spinning_heel"])
	assert_eq(_sim.timings(), [&"root", &"chain", &"chain"])
	assert_eq(_sim.steps(), [1, 2, 3])
	assert_eq(_sim.frames(), [0, 10, 22])
	assert_true(_sim.last().finisher)


func test_mash_k_reaches_spinning_heel() -> void:
	for seed_value: int in MASH_SEEDS:
		var sim := OwnerSim.new(_new_parser(_ground))
		sim.run(_taps(K, _random_gaps(seed_value, 30, 4, 10)), 160)
		assert_gte(sim.started.size(), 3, "seed %d" % seed_value)
		assert_eq(sim.ids().slice(0, 3), [&"front_kick", &"roundhouse", &"spinning_heel"],
				"seed %d" % seed_value)
		assert_eq(sim.steps().slice(0, 3), [1, 2, 3], "seed %d" % seed_value)
		assert_true(sim.started[2].finisher, "seed %d" % seed_value)


func test_p_p_k_is_push_kick() -> void:
	_sim.run({0: [P], 9: [P], 18: [K]}, 60)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"push_kick"])
	assert_eq(_sim.timings(), [&"root", &"chain", &"chain"])
	assert_eq(_sim.steps(), [1, 2, 3])
	assert_eq(_sim.frames(), [0, 9, 18])
	assert_true(_sim.last().finisher)


# --- Spec §4: pause branches (P · P, P P · P, K · K) -----------------------------------

func test_p_pause_p_is_body_flurry_then_auto_shove() -> void:
	_sim.run({0: [P]}, 1)
	_sim.run_until_free()
	_sim.idle(_parser.pause_min_frames)
	_sim.step([P])
	assert_eq(_sim.ids(), [&"jab_1", &"body_flurry"])
	var flurry := _sim.last()
	assert_eq(flurry.timing, &"pause")
	assert_eq(flurry.chain_step, 2)
	assert_eq(flurry.f, _parser.pause_min_frames)
	assert_eq(flurry.input, P)
	# Stop pressing: shove starts automatically right after the flurry's recovery.
	_sim.run_until_free()
	assert_eq(_sim.ids(), [&"jab_1", &"body_flurry", &"shove"])
	var shove := _sim.last()
	assert_eq(shove.timing, &"auto")
	assert_eq(shove.chain_step, 3)
	assert_eq(shove.input, &"")
	assert_eq(shove.frame, flurry.frame + _m(&"body_flurry").total_frames())
	assert_true(shove.finisher)


func test_p_p_pause_p_is_spinning_backfist() -> void:
	_sim.run({0: [P], 9: [P]}, 10)
	_sim.run_until_free()
	_sim.idle(_parser.pause_min_frames)
	_sim.step([P])
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"spinning_backfist"])
	var backfist := _sim.last()
	assert_eq(backfist.timing, &"pause")
	assert_eq(backfist.chain_step, 3)
	assert_true(backfist.finisher)
	_sim.run_until_free()
	assert_eq(_sim.ids().size(), 3, "nothing follows the backfist on its own")


func test_flurry_repeats_up_to_repeat_max_then_auto_shove_then_new_chain() -> void:
	_sim.run({0: [P]}, 1)
	_sim.run_until_free()
	_sim.idle(_parser.pause_min_frames + 3)
	_sim.step([P])
	var flurry_frame := _sim.last().frame
	# Keep mashing P every 5 frames: each press lands in the flurry's recovery.
	_sim.run(_every(P, 4, 5, 15), 90)
	var repeat_max := _m(&"body_flurry").repeat_max
	var expected_ids: Array[StringName] = [&"jab_1", &"body_flurry"]
	var expected_timings: Array[StringName] = [&"root", &"pause"]
	var expected_steps: Array[int] = [1, 2]
	for i: int in repeat_max:
		expected_ids.append(&"body_flurry")
		expected_timings.append(&"repeat")
		expected_steps.append(3 + i)
	expected_ids.append_array([&"shove", &"jab_1"])
	expected_timings.append_array([&"auto", &"root"])
	expected_steps.append_array([3 + repeat_max, 1])
	assert_eq(_sim.ids().slice(0, expected_ids.size()), expected_ids)
	assert_eq(_sim.timings().slice(0, expected_ids.size()), expected_timings)
	assert_eq(_sim.steps().slice(0, expected_ids.size()), expected_steps)
	# Repeats cancel the recovery 5 frames apart; the press in the last flurry's recovery
	# finds no repeat left and does not cut it short.
	var last_repeat: Started = _sim.started[1 + repeat_max]
	assert_eq(last_repeat.frame, flurry_frame + 5 * repeat_max)
	var shove: Started = _sim.started[2 + repeat_max]
	assert_eq(shove.frame, last_repeat.frame + _m(&"body_flurry").total_frames())


func test_repeat_count_tracks_repeats_and_resets_on_other_moves() -> void:
	_sim.run({0: [P]}, 1)
	_sim.run_until_free()
	_sim.idle(_parser.pause_min_frames)
	_sim.step([P])
	assert_eq(_parser.repeat_count, 0)
	_sim.run(_every(P, 4, 5, 2), 10)
	assert_eq(_sim.last().timing, &"repeat")
	assert_eq(_parser.repeat_count, 2)
	# Stopping after two repeats still ends in the shove.
	_sim.run_until_free()
	assert_eq(_sim.last().id, &"shove")
	assert_eq(_sim.last().timing, &"auto")
	assert_eq(_sim.last().chain_step, 5)
	assert_eq(_parser.repeat_count, 0)


func test_repeat_only_from_recovery() -> void:
	var flurry := _m(&"body_flurry")
	flurry.auto_next = null
	_parser.notify_started(_selection(flurry, &"pause", 3))
	_parser.notify_recovery_ended()
	_parser.tick()
	_parser.press(P)
	var selection := _parser.select(false)
	assert_eq(selection.move, _m(&"jab_1"), "FREE after the flurry: P starts a new chain")
	assert_eq(selection.timing, &"root")


func test_k_pause_k_is_stomp_kick() -> void:
	_sim.run({0: [K]}, 1)
	_sim.run_until_free()
	_sim.idle(_parser.pause_min_frames + 5)
	_sim.step([K])
	assert_eq(_sim.ids(), [&"front_kick", &"stomp_kick"])
	assert_eq(_sim.timings(), [&"root", &"pause"])
	assert_eq(_sim.steps(), [1, 2])
	assert_true(_sim.last().finisher)


# --- Spec §4: grace frames, pause window and reset ------------------------------------

func test_grace_window_continues_normal_chain_after_recovery() -> void:
	for wait: int in _parser.pause_min_frames:
		var record := _press_after_chain({0: [P]}, 1, wait, P)
		assert_not_null(record, "f=%d" % wait)
		assert_eq(record.id, &"jab_2", "f=%d" % wait)
		assert_eq(record.timing, &"chain", "f=%d" % wait)
		assert_eq(record.chain_step, 2, "f=%d" % wait)
		assert_eq(record.f, wait)


func test_pause_window_without_pause_branch_falls_back_to_normal() -> void:
	# The hook has no PAUSE branch: P in its pause window is still the uppercut.
	for wait: int in range(_parser.pause_min_frames, _parser.pause_max_frames + 1):
		var record := _press_after_chain({0: [P], 9: [P], 18: [P]}, 19, wait, P)
		assert_eq(record.id, &"uppercut", "f=%d" % wait)
		assert_eq(record.timing, &"chain", "f=%d" % wait)
		assert_eq(record.chain_step, 4, "f=%d" % wait)


func test_waiting_past_pause_max_resets_to_root() -> void:
	for wait: int in range(_parser.pause_max_frames + 1, _parser.pause_max_frames + 4):
		var record := _press_after_chain({0: [P]}, 1, wait, P)
		assert_eq(record.id, &"jab_1", "f=%d" % wait)
		assert_eq(record.timing, &"root", "f=%d" % wait)
		assert_eq(record.chain_step, 1, "f=%d" % wait)


func test_every_wait_after_jab_2_picks_the_documented_branch() -> void:
	var min_f := _parser.pause_min_frames
	var max_f := _parser.pause_max_frames
	for wait: int in range(0, max_f + 3):
		var record := _press_after_chain({0: [P], 9: [P]}, 10, wait, P)
		if wait < min_f:
			assert_eq(record.id, &"hook", "f=%d" % wait)
			assert_eq(record.timing, &"chain", "f=%d" % wait)
			assert_eq(record.chain_step, 3, "f=%d" % wait)
		elif wait <= max_f:
			assert_eq(record.id, &"spinning_backfist", "f=%d" % wait)
			assert_eq(record.timing, &"pause", "f=%d" % wait)
			assert_eq(record.chain_step, 3, "f=%d" % wait)
		else:
			assert_eq(record.id, &"jab_1", "f=%d" % wait)
			assert_eq(record.timing, &"root", "f=%d" % wait)
			assert_eq(record.chain_step, 1, "f=%d" % wait)


func test_exact_pause_window_boundaries() -> void:
	var min_f := _parser.pause_min_frames
	var max_f := _parser.pause_max_frames
	var jab_2_prefix := {0: [P], 9: [P]}
	assert_eq(_press_after_chain(jab_2_prefix, 10, min_f - 1, P).id, &"hook", "pause_min - 1")
	assert_eq(_press_after_chain(jab_2_prefix, 10, min_f, P).id, &"spinning_backfist", "pause_min")
	assert_eq(_press_after_chain(jab_2_prefix, 10, max_f, P).id, &"spinning_backfist", "pause_max")
	var jab_1_prefix := {0: [P]}
	assert_eq(_press_after_chain(jab_1_prefix, 1, min_f - 1, P).id, &"jab_2", "pause_min - 1")
	assert_eq(_press_after_chain(jab_1_prefix, 1, min_f, P).id, &"body_flurry", "pause_min")
	assert_eq(_press_after_chain(jab_1_prefix, 1, max_f, P).id, &"body_flurry", "pause_max")
	assert_eq(_press_after_chain(jab_1_prefix, 1, max_f + 1, P).id, &"jab_1", "pause_max + 1")
	assert_eq(_press_after_chain(jab_2_prefix, 10, max_f + 1, P).id, &"jab_1", "pause_max + 1")
	var kick_prefix := {0: [K]}
	assert_eq(_press_after_chain(kick_prefix, 1, min_f - 1, K).id, &"roundhouse", "pause_min - 1")
	assert_eq(_press_after_chain(kick_prefix, 1, min_f, K).id, &"stomp_kick", "pause_min")
	assert_eq(_press_after_chain(kick_prefix, 1, max_f, K).id, &"stomp_kick", "pause_max")
	assert_eq(_press_after_chain(kick_prefix, 1, max_f + 1, K).id, &"front_kick", "pause_max + 1")


func test_k_after_jab_2_is_push_kick_in_grace_and_pause_window() -> void:
	for wait: int in range(0, _parser.pause_max_frames + 2):
		var record := _press_after_chain({0: [P], 9: [P]}, 10, wait, K)
		if wait <= _parser.pause_max_frames:
			assert_eq(record.id, &"push_kick", "f=%d" % wait)
			assert_eq(record.timing, &"chain", "f=%d" % wait)
		else:
			assert_eq(record.id, &"front_kick", "f=%d" % wait)
			assert_eq(record.timing, &"root", "f=%d" % wait)


func test_pause_branch_listed_first_still_needs_the_pause_window() -> void:
	# Branch timing filters, not array order: with jab_2's PAUSE branch moved to the front,
	# P in recovery or in the grace frames is still the hook.
	var jab_2 := _m(&"jab_2")
	var pause_branch: ComboBranch = jab_2.branches[2]
	jab_2.branches.remove_at(2)
	jab_2.branches.insert(0, pause_branch)
	_sim.run({0: [P], 9: [P], 18: [P]}, 19)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook"], "P in jab_2's recovery")
	assert_eq(_press_after_chain({0: [P], 9: [P]}, 10, 0, P).id, &"hook", "grace f=0")
	assert_eq(_press_after_chain({0: [P], 9: [P]}, 10, _parser.pause_min_frames, P).id,
			&"spinning_backfist", "pause window")


func test_pause_only_branch_does_not_fire_from_recovery() -> void:
	var wait := _move(&"wait_move", 4, 3, 10, LIGHT)
	wait.branches.append(_branch(K, _m(&"stomp_kick"), PAUSE))
	_parser.notify_started(_selection(wait))
	_parser.press(K)
	assert_null(_parser.select(true), "PAUSE branches are FREE-only")
	assert_true(_parser.has_buffered(K))


func test_unrelated_press_in_grace_starts_a_new_chain() -> void:
	# hook only continues with P; K right after it falls through to the roots.
	var record := _press_after_chain({0: [P], 9: [P], 18: [P]}, 19, 3, K)
	assert_eq(record.id, &"front_kick")
	assert_eq(record.timing, &"root")
	assert_eq(record.chain_step, 1)


# --- Spec §4: input buffer -------------------------------------------------------------

func test_press_stays_usable_for_buffer_frames_ticks() -> void:
	_parser.press(P)
	for i: int in _parser.buffer_frames:
		_parser.tick()
	assert_true(_parser.has_buffered(P), "age == buffer_frames is still usable")
	_parser.tick()
	assert_false(_parser.has_buffered(P), "age == buffer_frames + 1 expired")
	assert_null(_parser.select(false))


func test_buffer_hands_back_a_fresh_press_without_holding_the_button() -> void:
	# buffer(): a press the owner held back (P during the player's block) re-enters at age
	# 0, lives buffer_frames ticks like any press, and leaves the hold timers alone (no
	# P_HOLD charge for a button already released).
	_parser.buffer(P)
	assert_false(_parser.is_held(P), "not held")
	for i: int in _parser.buffer_frames:
		_parser.tick()
	assert_true(_parser.has_buffered(P), "fresh: usable for buffer_frames ticks")
	assert_eq(_parser.select(false).move, _m(&"jab_1"))
	_parser.press(K)
	_parser.release(K)
	assert_true(_parser.consume(K), "the owner takes the press and holds it back")
	_parser.buffer(K)
	_parser.tick()
	assert_false(_parser.is_held(K), "a held-back press of a released button stays released")
	assert_true(_parser.consume(K), "handed back")
	_parser.buffer(P)
	for i: int in _parser.buffer_frames + 1:
		_parser.tick()
	assert_false(_parser.has_buffered(P), "and expires like any press")


func test_buffered_press_fires_when_cancel_window_opens() -> void:
	# roundhouse starts at 10; its recovery (and cancel window) opens at 22.
	var cancel_frame := 10 + _m(&"roundhouse").startup + _m(&"roundhouse").active
	var press_frame := cancel_frame - _parser.buffer_frames
	_sim.run({0: [K], 10: [K], press_frame: [K]}, 60)
	assert_eq(_sim.ids(), [&"front_kick", &"roundhouse", &"spinning_heel"])
	assert_eq(_sim.last().frame, cancel_frame)


func test_press_older_than_buffer_frames_is_dropped() -> void:
	var cancel_frame := 10 + _m(&"roundhouse").startup + _m(&"roundhouse").active
	var press_frame := cancel_frame - _parser.buffer_frames - 1
	_sim.run({0: [K], 10: [K], press_frame: [K]}, 80)
	assert_eq(_sim.ids(), [&"front_kick", &"roundhouse"], "the stale K never fires")
	assert_null(_sim.move)


func test_buffer_does_not_age_during_hitstop() -> void:
	_parser.press(P)
	# Frozen: input edges arrive but tick() is not called.
	for i: int in 50:
		assert_true(_parser.has_buffered(P))
	assert_eq(_parser.select(false).move, _m(&"jab_1"))


func test_press_before_a_hitstop_survives_the_freeze() -> void:
	# P at 0 starts jab_1; P at 3 (startup) is buffered; a 30-frame hitstop hits after
	# sim frame 3. jab_1's recovery opens on sim frame 7, where that press is only 4 old.
	_sim.run({0: [P], 3: [P]}, 4)
	_sim.freeze(30)
	_sim.run({}, 10)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2"])
	assert_eq(_sim.frames(), [0, 7])


func test_press_during_a_hitstop_is_used_afterward() -> void:
	_sim.run({0: [P]}, 4)
	_sim.freeze(30, {5: [P]})
	_sim.run({}, 10)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2"])
	assert_eq(_sim.frames(), [0, 7])


func test_presses_before_a_late_cancel_frame_stay_buffered() -> void:
	var late := _move(&"late_cancel", 4, 3, 10, LIGHT)
	late.cancel_start = 5
	late.branches.append(_branch(P, _m(&"jab_2")))
	var move_set := MoveSet.new()
	move_set.root_branches.append(_branch(P, late))
	var sim := OwnerSim.new(_new_parser(move_set))
	# Recovery starts at 7, but the cancel window only opens at 7 + 5 = 12.
	sim.run({0: [P], 8: [P]}, 12)
	assert_eq(sim.ids(), [&"late_cancel"], "no cancel before cancel_start")
	assert_true(sim.parser.has_buffered(P), "the press waits in the buffer")
	sim.step()
	assert_eq(sim.ids(), [&"late_cancel", &"jab_2"])
	assert_eq(sim.last().frame, 12)
	assert_eq(sim.last().timing, &"chain")


func test_press_expires_before_a_late_cancel_frame() -> void:
	var late := _move(&"late_cancel", 4, 3, 10, LIGHT)
	late.cancel_start = 9
	late.branches.append(_branch(P, _m(&"jab_2")))
	var move_set := MoveSet.new()
	move_set.root_branches.append(_branch(P, late))
	# Cancel opens at 16. A press at 8 is exactly buffer_frames old then; one at 7 is not.
	var sim := OwnerSim.new(_new_parser(move_set))
	sim.run({0: [P], 16 - _parser.buffer_frames: [P]}, 40)
	assert_eq(sim.ids(), [&"late_cancel", &"jab_2"])
	assert_eq(sim.last().frame, 16)
	var stale := OwnerSim.new(_new_parser(move_set))
	stale.run({0: [P], 15 - _parser.buffer_frames: [P]}, 40)
	assert_eq(stale.ids(), [&"late_cancel"])


func test_two_presses_on_one_frame_feed_the_next_step() -> void:
	# Both presses age 0 on frame 0: the first starts jab_1, the second waits for
	# jab_1's recovery (frame 7, age 7).
	_sim.run({0: [P, P]}, 20)
	assert_eq(_sim.ids().slice(0, 2), [&"jab_1", &"jab_2"])
	assert_eq(_sim.frames().slice(0, 2), [0, 7])


# --- Unmatched presses wait for FREE ----------------------------------------------------

func test_p_late_in_uppercut_recovery_starts_a_new_chain_when_free() -> void:
	# uppercut starts at 27 and plays its last recovery frame on 59.
	_sim.run({0: [P], 9: [P], 18: [P], 27: [P], 56: [P]}, 58)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook", &"uppercut"])
	assert_true(_parser.has_buffered(P), "no branch in recovery: stays buffered")
	_sim.run({}, 10)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook", &"uppercut", &"jab_1"])
	assert_eq(_sim.last().frame, 60, "fires on the first FREE frame")
	assert_eq(_sim.last().timing, &"root")
	assert_eq(_sim.last().chain_step, 1)


func test_k_in_hook_recovery_becomes_front_kick_when_free() -> void:
	# hook starts at 18 and plays its last recovery frame on 40.
	_sim.run({0: [P], 9: [P], 18: [P], 38: [K]}, 50)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook", &"front_kick"])
	assert_eq(_sim.last().frame, 41)
	assert_eq(_sim.last().timing, &"root")


func test_p_early_in_uppercut_recovery_expires_before_free() -> void:
	_sim.run({0: [P], 9: [P], 18: [P], 27: [P], 38: [P]}, 120)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook", &"uppercut"])


# --- Hold P: haymaker --------------------------------------------------------------------

func test_hold_timer_counts_ticks_while_held() -> void:
	assert_false(_parser.is_held(P))
	assert_eq(_parser.held_frames(P), 0)
	_parser.press(P)
	assert_true(_parser.is_held(P))
	assert_eq(_parser.held_frames(P), 0)
	for i: int in 5:
		_parser.tick()
	assert_eq(_parser.held_frames(P), 5)
	assert_false(_parser.is_held(K))
	_parser.release(P)
	assert_false(_parser.is_held(P))
	assert_eq(_parser.held_frames(P), 0)


func test_release_after_hold_frames_buffers_p_hold() -> void:
	_parser.press(P)
	for i: int in _parser.hold_frames:
		_parser.tick()
	_parser.release(P)
	assert_true(_parser.has_buffered(P_HOLD))


func test_release_one_frame_short_does_not_buffer_p_hold() -> void:
	_parser.press(P)
	for i: int in _parser.hold_frames - 1:
		_parser.tick()
	_parser.release(P)
	assert_false(_parser.has_buffered(P_HOLD))


func test_press_and_release_on_one_frame_is_a_tap() -> void:
	_parser.press(P)
	_parser.release(P)
	assert_false(_parser.is_held(P))
	assert_true(_parser.has_buffered(P))
	assert_false(_parser.has_buffered(P_HOLD))


func test_release_without_press_and_other_inputs_never_make_p_hold() -> void:
	_parser.release(P)
	_parser.press(K)
	for i: int in _parser.hold_frames + 5:
		_parser.tick()
	_parser.release(K)
	assert_false(_parser.has_buffered(P_HOLD))


func test_hold_p_then_release_is_jab_then_haymaker() -> void:
	var hold := _parser.hold_frames
	_sim.run({0: [P]}, hold + 40, {hold: [P]})
	assert_eq(_sim.ids(), [&"jab_1", &"haymaker"])
	assert_eq(_sim.timings(), [&"root", &"root"])
	assert_eq(_sim.steps(), [1, 1])
	assert_eq(_sim.frames(), [0, hold], "haymaker starts on the release frame")
	assert_eq(_sim.last().input, P_HOLD)
	assert_true(_sim.last().finisher)


func test_hold_p_one_frame_short_is_only_a_jab() -> void:
	var hold := _parser.hold_frames
	_sim.run({0: [P]}, hold + 40, {hold - 1: [P]})
	assert_eq(_sim.ids(), [&"jab_1"])


func test_hold_release_during_recovery_waits_for_free() -> void:
	# With a short hold window the release lands in jab_1's recovery (7..16). P_HOLD has
	# no branch there, so it stays buffered and starts the haymaker on frame 17.
	_parser.hold_frames = 12
	_sim.run({0: [P]}, 40, {12: [P]})
	assert_eq(_sim.ids(), [&"jab_1", &"haymaker"])
	assert_eq(_sim.frames(), [0, 17])


func test_hold_timer_does_not_advance_during_hitstop() -> void:
	_parser.press(P)
	for i: int in 10:
		_parser.tick()
	# Frozen for a while: no ticks.
	assert_eq(_parser.held_frames(P), 10)
	_parser.release(P)
	assert_false(_parser.has_buffered(P_HOLD))


# --- Conditions --------------------------------------------------------------------------

func test_k_near_a_downed_target_is_stomp() -> void:
	_parser.press(K)
	var selection := _parser.select(false, {DOWNED: true})
	assert_eq(selection.move, _m(&"stomp"))
	assert_eq(selection.timing, &"root")
	_parser.press(K)
	assert_eq(_parser.select(false, {DOWNED: false}).move, _m(&"front_kick"))
	_parser.press(K)
	assert_eq(_parser.select(false).move, _m(&"front_kick"))


func test_condition_keys_may_be_strings() -> void:
	_parser.press(K)
	assert_eq(_parser.select(false, {"downed_target_near": true}).move, _m(&"stomp"))


func test_air_set_picks_spin_kick_at_apex_else_flying_kick() -> void:
	var air := _new_parser(_air)
	air.press(K)
	assert_eq(air.select(false, {APEX: true}).move, _m(&"spin_kick"))
	air.press(K)
	assert_eq(air.select(false, {APEX: false}).move, _m(&"flying_kick"))
	air.press(K)
	assert_eq(air.select(false, {DOWNED: true}).move, _m(&"flying_kick"))
	air.press(P)
	assert_null(air.select(false), "no punch in the air set")


func test_air_set_in_the_sim() -> void:
	var sim := OwnerSim.new(_new_parser(_air))
	sim.conditions = {APEX: true}
	sim.run({0: [K]}, 1)
	sim.run_until_free()
	sim.conditions = {APEX: false}
	sim.run({0: [K]}, 1)
	assert_eq(sim.ids(), [&"spin_kick", &"flying_kick"])


func test_chain_branch_wins_over_conditional_root_in_recovery() -> void:
	# A downed target nearby does not turn the K K chain into a stomp.
	# With no chain the conditional root wins: K is the stomp (which has no branches, so
	# a second K in its recovery waits and expires).
	_sim.conditions = {DOWNED: true}
	_sim.run({0: [K], 10: [K]}, 40)
	assert_eq(_sim.ids(), [&"stomp"])
	# Mid-chain, front_kick's own K branch is taken even with a downed target near.
	var kicks := OwnerSim.new(_new_parser(_ground))
	kicks.run({0: [K]}, 12)
	kicks.conditions = {DOWNED: true}
	kicks.step([K])
	assert_eq(kicks.ids(), [&"front_kick", &"roundhouse"])


func test_hold_and_weapon_sets() -> void:
	var hold := _new_parser(_hold)
	hold.press(P)
	assert_eq(hold.select(false).move, _m(&"knee"))
	hold.press(K)
	assert_eq(hold.select(false).move, _m(&"throw"))
	var sim := OwnerSim.new(_new_parser(_weapon))
	sim.run(_every(P, 0, 10, 3), 80)
	assert_eq(sim.ids(), [&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3"])
	assert_eq(sim.steps(), [1, 2, 3])
	assert_true(sim.last().finisher)
	var weapon := _new_parser(_weapon)
	weapon.press(K)
	assert_eq(weapon.select(false, {DOWNED: true}).move, _m(&"stomp"))


func test_changing_move_set_keeps_the_chain() -> void:
	_parser.notify_started(_selection(_m(&"jab_1")))
	_parser.move_set = _air
	_parser.press(P)
	var selection := _parser.select(true)
	assert_eq(selection.move, _m(&"jab_2"), "current's branches still apply")
	assert_eq(_parser.current, _m(&"jab_1"))


# --- Interrupt branches (RB back elbow) --------------------------------------------------

func test_rb_interrupts_every_ground_move_recovery() -> void:
	for id: StringName in [&"jab_1", &"jab_2", &"hook", &"uppercut", &"body_flurry",
			&"shove", &"front_kick", &"roundhouse", &"spinning_heel", &"stomp_kick",
			&"push_kick", &"haymaker", &"stomp", &"back_elbow"]:
		var parser := _new_parser(_ground)
		parser.notify_started(_selection(_m(id), &"chain", 2))
		parser.press(RB)
		var selection := parser.select(true)
		assert_not_null(selection, String(id))
		if selection != null:
			assert_eq(selection.move, _m(&"back_elbow"), String(id))
			assert_eq(selection.timing, &"chain", String(id))
			assert_eq(selection.chain_step, 3, String(id))
			assert_eq(selection.input, RB, String(id))


func test_rb_cancels_jab_recovery_in_the_sim() -> void:
	_sim.run({0: [P], 9: [RB]}, 40)
	assert_eq(_sim.ids(), [&"jab_1", &"back_elbow"])
	assert_eq(_sim.frames(), [0, 9])
	assert_eq(_sim.timings(), [&"root", &"chain"])


func test_rb_buffered_in_startup_fires_at_cancel() -> void:
	_sim.run({0: [P], 2: [RB]}, 40)
	assert_eq(_sim.ids(), [&"jab_1", &"back_elbow"])
	assert_eq(_sim.frames(), [0, 7])


func test_rb_when_free_is_a_root() -> void:
	_parser.press(RB)
	var selection := _parser.select(false)
	assert_eq(selection.move, _m(&"back_elbow"))
	assert_eq(selection.timing, &"root")
	assert_eq(selection.chain_step, 1)


func test_rb_in_grace_after_a_move_uses_the_interrupt() -> void:
	var record := _press_after_chain({0: [P]}, 1, 2, RB)
	assert_eq(record.id, &"back_elbow")
	assert_eq(record.timing, &"chain")
	assert_eq(record.chain_step, 2)


func test_current_move_branch_beats_interrupt() -> void:
	var feint := _move(&"feint", 3, 1, 8, LIGHT)
	var jab_1 := _m(&"jab_1")
	jab_1.branches.append(_branch(RB, feint))
	_parser.notify_started(_selection(jab_1))
	_parser.press(RB)
	assert_eq(_parser.select(true).move, feint, "current's NORMAL branch first")


func test_air_set_has_no_interrupts() -> void:
	var air := _new_parser(_air)
	air.notify_started(_selection(_m(&"flying_kick")))
	air.press(RB)
	assert_null(air.select(true))
	assert_true(air.has_buffered(RB))


# --- Non-attack inputs, consume, reset and clear ----------------------------------------

func test_select_ignores_non_attack_inputs() -> void:
	for input: StringName in [JUMP, DODGE, GRAB]:
		_parser.press(input)
	assert_null(_parser.select(false))
	assert_null(_parser.select(true))
	for input: StringName in [JUMP, DODGE, GRAB]:
		assert_true(_parser.has_buffered(input), String(input))
		assert_true(_parser.consume(input), String(input))
		assert_false(_parser.has_buffered(input), String(input))
		assert_false(_parser.consume(input), String(input))


func test_select_skips_older_non_attack_press() -> void:
	_parser.press(JUMP)
	_parser.press(P)
	assert_eq(_parser.select(false).move, _m(&"jab_1"))
	assert_true(_parser.has_buffered(JUMP))
	assert_false(_parser.has_buffered(P))


func test_consume_takes_the_oldest_press() -> void:
	_parser.press(GRAB)
	_parser.tick()
	_parser.press(GRAB)
	assert_true(_parser.consume(GRAB))
	# The young one is left: it survives buffer_frames more ticks.
	for i: int in _parser.buffer_frames:
		_parser.tick()
	assert_true(_parser.has_buffered(GRAB))
	_parser.tick()
	assert_false(_parser.has_buffered(GRAB))


func test_consume_ignores_expired_presses() -> void:
	_parser.press(DODGE)
	for i: int in _parser.buffer_frames + 1:
		_parser.tick()
	assert_false(_parser.consume(DODGE))


func test_consume_attack_input_removes_it_from_selection() -> void:
	_parser.press(P)
	assert_true(_parser.consume(P))
	assert_null(_parser.select(false))


func test_non_attack_press_during_a_move_waits_for_consume() -> void:
	_sim.run({0: [P], 3: [JUMP]}, 6)
	assert_eq(_sim.ids(), [&"jab_1"])
	assert_true(_parser.has_buffered(JUMP))
	assert_true(_parser.consume(JUMP))


func test_reset_chain_keeps_the_buffer() -> void:
	_parser.notify_started(_selection(_m(&"jab_2"), &"chain", 2))
	_parser.repeat_count = 3
	_parser.press(P)
	_parser.reset_chain()
	assert_null(_parser.current)
	assert_eq(_parser.chain_step, 0)
	assert_eq(_parser.frames_since_recovery, -1)
	assert_eq(_parser.repeat_count, 0)
	assert_true(_parser.has_buffered(P))
	var selection := _parser.select(false)
	assert_eq(selection.move, _m(&"jab_1"), "no chain: roots")
	assert_eq(selection.timing, &"root")


func test_reset_chain_stops_the_post_recovery_counter() -> void:
	_parser.notify_started(_selection(_m(&"jab_1")))
	_parser.notify_recovery_ended()
	_parser.tick()
	_parser.reset_chain()
	_parser.tick()
	assert_eq(_parser.frames_since_recovery, -1)
	assert_null(_parser.take_auto_next())


func test_clear_buffer_keeps_hold_timers() -> void:
	_parser.press(P)
	_parser.press(JUMP)
	for i: int in 5:
		_parser.tick()
	_parser.clear_buffer()
	assert_false(_parser.has_buffered(P))
	assert_false(_parser.has_buffered(JUMP))
	assert_true(_parser.is_held(P))
	assert_eq(_parser.held_frames(P), 5)
	for i: int in _parser.hold_frames - 5:
		_parser.tick()
	_parser.release(P)
	assert_true(_parser.has_buffered(P_HOLD))


# --- Ordering ---------------------------------------------------------------------------

func test_same_frame_presses_are_tried_in_press_order() -> void:
	_parser.press(K)
	_parser.press(P)
	var first := _parser.select(false)
	assert_eq(first.move, _m(&"front_kick"))
	assert_eq(first.input, K)
	assert_true(_parser.has_buffered(P))


func test_same_frame_presses_in_recovery_oldest_first() -> void:
	# jab_2 starts at 9; its recovery opens at 16.
	_sim.run({0: [P], 9: [P], 16: [K, P]}, 18)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"push_kick"])
	var other := OwnerSim.new(_new_parser(_ground))
	other.run({0: [P], 9: [P], 16: [P, K]}, 18)
	assert_eq(other.ids(), [&"jab_1", &"jab_2", &"hook"])
	assert_true(other.parser.has_buffered(K), "the later K is left in the buffer")


func test_older_unmatched_press_does_not_block_a_newer_match() -> void:
	# In hook's recovery (from 27) K matches nothing, P continues to the uppercut.
	_sim.run({0: [P], 9: [P], 18: [P], 25: [K], 26: [P]}, 28)
	assert_eq(_sim.ids(), [&"jab_1", &"jab_2", &"hook", &"uppercut"])
	assert_eq(_sim.last().frame, 27)
	assert_true(_parser.has_buffered(K))


# --- Spec §4: the last hit of every chain is a finisher ---------------------------------

func test_every_spec_combo_ends_in_a_finisher() -> void:
	var cases: Array[Dictionary] = [
		{name = "P P P P", taps = {0: [P], 9: [P], 18: [P], 27: [P]}, last = &"uppercut"},
		{name = "P P K", taps = {0: [P], 9: [P], 18: [K]}, last = &"push_kick"},
		{name = "K K K", taps = {0: [K], 10: [K], 22: [K]}, last = &"spinning_heel"},
	]
	for combo: Dictionary in cases:
		var sim := OwnerSim.new(_new_parser(_ground))
		sim.run(combo["taps"], 40)
		sim.run_until_free()
		assert_eq(sim.last().id, combo["last"], combo["name"])
		assert_true(sim.last().finisher, combo["name"])
	# Pause combos and the hold.
	var flurry_sim := OwnerSim.new(_new_parser(_ground))
	flurry_sim.run({0: [P]}, 1)
	flurry_sim.run_until_free()
	flurry_sim.idle(_parser.pause_min_frames)
	flurry_sim.run(_every(P, 0, 5, 4), 20)
	flurry_sim.run_until_free()
	assert_eq(flurry_sim.last().id, &"shove", "P · P (mash)")
	assert_true(flurry_sim.last().finisher)
	var backfist := _press_after_chain({0: [P], 9: [P]}, 10, _parser.pause_min_frames, P)
	assert_eq(backfist.id, &"spinning_backfist", "P P · P")
	assert_true(backfist.finisher)
	var stomp_kick := _press_after_chain({0: [K]}, 1, _parser.pause_min_frames, K)
	assert_eq(stomp_kick.id, &"stomp_kick", "K · K")
	assert_true(stomp_kick.finisher)
	var hold_sim := OwnerSim.new(_new_parser(_ground))
	hold_sim.run({0: [P]}, _parser.hold_frames + 1, {_parser.hold_frames: [P]})
	assert_eq(hold_sim.last().id, &"haymaker", "hold P, release")
	assert_true(hold_sim.last().finisher)


# --- Spec §1 goal 3: a finisher within a minute by mashing one button --------------------

func test_mashing_only_p_reaches_a_finisher_within_a_minute() -> void:
	for seed_value: int in MASH_SEEDS:
		var record := _first_finisher_from_mashing(P, seed_value)
		assert_not_null(record, "seed %d" % seed_value)
		if record != null:
			assert_lt(record.frame, ONE_MINUTE_FRAMES, "seed %d" % seed_value)
			assert_eq(record.id, &"uppercut", "seed %d" % seed_value)


func test_mashing_only_k_reaches_a_finisher_within_a_minute() -> void:
	for seed_value: int in MASH_SEEDS:
		var record := _first_finisher_from_mashing(K, seed_value)
		assert_not_null(record, "seed %d" % seed_value)
		if record != null:
			assert_lt(record.frame, ONE_MINUTE_FRAMES, "seed %d" % seed_value)
			assert_eq(record.id, &"spinning_heel", "seed %d" % seed_value)


## Mashes `input` with random 3..14 frame gaps (each press released 2 frames later) for up
## to a minute of sim frames. Returns the first finisher started, or null.
func _first_finisher_from_mashing(input: StringName, seed_value: int) -> Started:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sim := OwnerSim.new(_new_parser(_ground))
	var next_press := rng.randi_range(0, 14)
	var release_at := -1
	var checked := 0
	while sim.frame < ONE_MINUTE_FRAMES:
		var presses: Array[StringName] = []
		var releases: Array[StringName] = []
		if sim.frame == release_at:
			releases.append(input)
		if sim.frame == next_press:
			presses.append(input)
			release_at = sim.frame + 2
			next_press += rng.randi_range(3, 14)
		sim.step(presses, releases)
		while checked < sim.started.size():
			if sim.started[checked].finisher:
				return sim.started[checked]
			checked += 1
	return null
