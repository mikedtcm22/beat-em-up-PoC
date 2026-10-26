extends GutTest
## The readability probe (tests/bot/readability_probe.gd, Milestone 3 metrics R1 to R15): each metric
## is checked on a scripted fixture whose answer is known by hand, in a small code-built arena with
## a real player and stub enemies (tests/fixtures/stub_enemy.tscn): wind-ups forced a known number
## of frames apart, enemies placed at known bearings and distances, hits and KOs emitted on the
## bus. The thresholds are checked in verdict() against hand-made metrics. Metrics that need the
## real AI (R9 in a crowd, R13's waves) are only exercised on fixtures here; the crowd acts of
## P1-int run the probe over real fights.

const Probe := preload("res://tests/bot/readability_probe.gd")
const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")


## A stub that reports itself heading for a slot and goes nowhere (or walks at `walk` m a frame).
class ApproachStub:
	extends "res://tests/fixtures/stub_enemy.gd"
	var walk: float = 0.0

	func _tick_control() -> void:
		super()
		ai_state = AiState.APPROACH
		global_position.x += walk


## A widget that lights the left corner from every wind-up to its hit or whiff: all this probe test
## needs of RearWarning (the oracle has its own, fuller double).
class LeftWidget:
	extends Node
	var lit: bool = false

	func _ready() -> void:
		CombatEvents.windup_started.connect(func(_a: Node3D, _m: MoveData) -> void: lit = true)
		CombatEvents.attack_whiffed.connect(func(_a: Node3D, _m: MoveData) -> void: lit = false)
		CombatEvents.hit_landed.connect(func(_h: HitInfo) -> void: lit = false)

	func corner_state(side: StringName) -> Dictionary:
		var on := lit and side == &"left"
		return {"active": on, "count": 1 if on else 0, "heavy": false, "alpha": 1.0, "size_px": 100.0}


## An audio director that keeps the instance id of the attacker each voice is sounding.
class FakeAudio:
	extends Node
	var _windup_of: Array[int] = [0, 0, 0, 0]
	var _voices: Array[FakeVoice] = []
	var windup_voices_stolen: int = -1

	func _init() -> void:
		for i in 4:
			_voices.append(FakeVoice.new())

	func _ready() -> void:
		add_to_group(&"audio_director")

	## Voice `i` now sounds the wind-up of `owner_id` (0: something else) and is `playing` or not.
	func sound(i: int, owner_id: int, playing: bool) -> void:
		_windup_of[i] = owner_id
		_voices[i].playing = playing


class FakeVoice:
	extends RefCounted
	var playing: bool = false


var _scene: Node3D
var _player: PlayerCharacter
var _probe: Probe


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	PlaceholderAnims.warn_on_fallback = false
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	_scene.add_child(floor_body)
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	_probe = Probe.new()
	_probe.print_summary = false
	_probe.print_oracle_lines = false
	_probe.lens_every = 0
	_probe.occlusion_every = 0
	_scene.add_child(_probe)
	_probe.attach(_scene, _player)


func after_each() -> void:
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	TimeController.clear()


# --- Harness ----------------------------------------------------------------------------


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A stub `dist` m from the player at `bearing` degrees from the look (positive left; the look
## along -Z, left is -X), by hand, facing the player.
func _stub(bearing: float, dist: float, scene: PackedScene = STUB_ENEMY) -> EnemyActor:
	var stub := scene.instantiate() as EnemyActor
	_place(stub, bearing, dist)
	_scene.add_child(stub)
	return stub


func _place(stub: EnemyActor, bearing: float, dist: float) -> void:
	var b := deg_to_rad(bearing)
	stub.position = _player.global_position + Vector3(-sin(b), 0.0, -cos(b)) * dist
	var to_player := _player.global_position - stub.position
	stub.rotation.y = atan2(-to_player.x, -to_player.z)


func _approach_stub(walk: float, slot: Vector3, at: Vector3) -> ApproachStub:
	var stub := ApproachStub.new()
	stub.position = at
	stub.walk = walk
	stub.posture_slot = slot
	_scene.add_child(stub)
	return stub


func _metrics() -> Dictionary:
	return _probe.end_act().metrics


func _move(id: StringName, startup: int = 24) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup = startup
	move.reach_m = 1.05
	return move


func _hit(attacker: Node3D, damage: float = 6.0, reaction: CombatTypes.Reaction = CombatTypes.Reaction.FLINCH,
		move: MoveData = null) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = _player
	hit.damage = damage
	hit.reaction = reaction
	hit.move = move
	return hit


## What the bus carries for one enemy attack: attack_started, windup_started, `windup` frames later
## windup_ended(false), then the hit (null = a whiff). Emitted by hand so the wind-up's length is exact.
func _attack_on_the_bus(attacker: EnemyActor, windup: int, hit: HitInfo, chain_hit: HitInfo = null) -> void:
	var move := _move(&"fab_move", windup)
	CombatEvents.attack_started.emit(attacker, move, 1, &"root")
	CombatEvents.windup_started.emit(attacker, move)
	await _ticks(windup)
	CombatEvents.windup_ended.emit(attacker, false)
	if hit:
		hit.move = move
		CombatEvents.hit_landed.emit(hit)
	if chain_hit:
		CombatEvents.attack_started.emit(attacker, _move(&"fab_link", 8), 2, &"chain")
		chain_hit.move = _move(&"fab_link", 8)
		CombatEvents.hit_landed.emit(chain_hit)


func _status(rows: Array[Dictionary], id: String) -> String:
	for row in rows:
		if row.id == id:
			return row.status
	return "missing"


# --- R1: attackers at once -----------------------------------------------------------------------


func test_r1_counts_enemies_in_a_windup_and_the_frames_over_the_cap() -> void:
	Tuning.data.attacker_cap = 3
	var stubs: Array[EnemyActor] = []
	for bearing in [0.0, 90.0, 180.0, -90.0]:
		stubs.append(_stub(bearing, 3.0))
	await _ticks(3)
	for stub in stubs:
		stub.force_attack()
	await _ticks(70)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.max_concurrent_attackers, 4)
	assert_gt(summary.metrics.attacker_cap_violation_frames, 20, "over the cap for the length of the attack")
	assert_eq(_status(summary.verdict, "R1"), "FAIL", "hard")


func test_r1_holds_at_the_cap() -> void:
	Tuning.data.attacker_cap = 3
	var stubs: Array[EnemyActor] = []
	for bearing in [0.0, 90.0, -90.0]:
		stubs.append(_stub(bearing, 3.0))
	await _ticks(3)
	for stub in stubs:
		stub.force_attack()
	await _ticks(70)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.max_concurrent_attackers, 3)
	assert_eq(summary.metrics.attacker_cap_violation_frames, 0)
	assert_eq(_status(summary.verdict, "R1"), "ok")


func test_r1_the_cap_is_the_directors_when_there_is_one() -> void:
	Tuning.data.attacker_cap = 6
	var director := StubDirector.new()
	director.cap = 2
	_scene.add_child(director)
	var stubs: Array[EnemyActor] = []
	for bearing in [0.0, 90.0, -90.0]:
		stubs.append(_stub(bearing, 3.0))
	await _ticks(3)
	for stub in stubs:
		stub.force_attack()
	await _ticks(40)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.attacker_cap, 2, "the director's, not the tunable's")
	assert_gt(summary.metrics.attacker_cap_violation_frames, 0)
	assert_eq(_status(summary.verdict, "R1"), "FAIL")


func test_r1_cap_zero_is_unlimited() -> void:
	Tuning.data.attacker_cap = 0
	var stubs: Array[EnemyActor] = []
	for bearing in [0.0, 60.0, 120.0, 180.0, -120.0, -60.0]:
		stubs.append(_stub(bearing, 3.0))
	await _ticks(3)
	for stub in stubs:
		stub.force_attack()
	await _ticks(30)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.max_concurrent_attackers, 6)
	assert_eq(_status(summary.verdict, "R1"), "ok")


# --- R2: the gap between wind-up starts ---------------------------------------------------------------


func test_r2_measures_the_gap_between_two_enemies_windups() -> void:
	var a := _stub(0.0, 3.0)
	var b := _stub(120.0, 3.0)
	await _ticks(3)
	a.force_attack()
	await _ticks(5)
	b.force_attack()
	await _ticks(40)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.min_windup_start_gap_frames, 5, "five frames apart")
	assert_eq(_status(summary.verdict, "R2"), "FAIL", "less than director_min_windup_gap_s (0.35 s = 21 frames)")


func test_r2_passes_when_the_starts_are_far_enough_apart_and_ignores_one_enemy_twice() -> void:
	var a := _stub(0.0, 3.0)
	var b := _stub(120.0, 3.0)
	await _ticks(3)
	a.force_attack()
	await _ticks(60)
	a.force_attack()
	await _ticks(30)
	b.force_attack()
	await _ticks(30)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.windups, 3)
	assert_gte(summary.metrics.min_windup_start_gap_frames, 21, "a's two starts are not a pair; a to b is far enough")
	assert_eq(_status(summary.verdict, "R2"), "ok")


func test_r2_is_not_applicable_with_a_single_windup() -> void:
	var a := _stub(0.0, 3.0)
	await _ticks(3)
	a.force_attack()
	await _ticks(40)
	var summary := _probe.end_act()
	assert_null(summary.metrics.min_windup_start_gap_frames)
	assert_eq(_status(summary.verdict, "R2"), "n/a")


# --- R3: unwarned hits -----------------------------------------------------------------------------


func test_r3_a_real_telegraphed_jab_is_a_warned_hit() -> void:
	var stub := _stub(0.0, 0.8)
	await _ticks(3)
	stub.force_attack()
	await _ticks(60)
	var summary := _probe.end_act()
	assert_gt(summary.metrics.hits_on_player, 0, "the jab did land on the player")
	assert_eq(summary.metrics.unwarned_hits, 0, "after the sparring jab's 24-frame wind-up")
	assert_eq(_status(summary.verdict, "R3"), "ok")


func test_r3_a_hit_after_a_wind_up_shorter_than_the_floor_is_unwarned() -> void:
	var stub := _stub(0.0, 3.0)
	await _attack_on_the_bus(stub, Tuning.data.windup_min_frames_grunt - 5, _hit(stub))
	var summary := _probe.end_act()
	assert_eq(summary.metrics.unwarned_hits, 1)
	assert_eq(_status(summary.verdict, "R3"), "FAIL", "hard")


func test_r3_the_floor_is_the_heavy_one_for_a_heavy_attacker() -> void:
	var grunt := _stub(0.0, 3.0)
	var heavy := _stub(120.0, 3.0)
	heavy.heavy = true
	var between := Tuning.data.windup_min_frames_grunt + 2
	assert_lt(between, Tuning.data.windup_min_frames_heavy, "a length that is long for a grunt and short for a heavy")
	await _attack_on_the_bus(grunt, between, _hit(grunt))
	assert_eq(_probe.current_metrics().unwarned_hits, 0, "a grunt's floor is met")
	await _attack_on_the_bus(heavy, between, _hit(heavy))
	assert_eq(_probe.current_metrics().unwarned_hits, 1, "a heavy's is not")


func test_r3_a_chain_link_belongs_to_the_attack_that_was_warned() -> void:
	var stub := _stub(0.0, 3.0)
	await _attack_on_the_bus(stub, Tuning.data.windup_min_frames_grunt, _hit(stub), _hit(stub))
	var summary := _probe.end_act()
	assert_eq(summary.metrics.hits_on_player, 2, "the opener and its second link")
	assert_eq(summary.metrics.unwarned_hits, 0, "one telegraph per attack")


func test_r3_an_interrupted_windup_leaves_no_warning_behind_for_a_stray_hit() -> void:
	var stub := _stub(0.0, 3.0)
	var move := _move(&"fab_move", 24)
	CombatEvents.attack_started.emit(stub, move, 1, &"root")
	CombatEvents.windup_started.emit(stub, move)
	await _ticks(4)
	CombatEvents.windup_ended.emit(stub, true)
	CombatEvents.hit_landed.emit(_hit(stub, 6.0, CombatTypes.Reaction.FLINCH, move))
	assert_eq(_probe.current_metrics().unwarned_hits, 1, "the attack ended with its wind-up: a later hit has no telegraph")


func test_r3_the_final_hit_of_a_hold_and_a_body_impact_are_exempt() -> void:
	var stub := _stub(0.0, 3.0)
	var move := _move(&"fab_grab", 24)
	CombatEvents.attack_started.emit(stub, move, 1, &"root")
	CombatEvents.windup_started.emit(stub, move)
	await _ticks(Tuning.data.windup_min_frames_grunt)
	CombatEvents.windup_ended.emit(stub, false)
	CombatEvents.grabbed.emit(stub, _player)
	var headbutt := _hit(stub, 15.0, CombatTypes.Reaction.KNOCKDOWN)
	CombatEvents.hit_landed.emit(headbutt)
	assert_eq(_probe.current_metrics().unwarned_hits, 0, "the hold was the telegraph")
	var flying := _hit(stub)
	flying.is_body_impact = true
	CombatEvents.hit_landed.emit(flying)
	assert_eq(_probe.current_metrics().unwarned_hits, 0, "a flying body is not an attack")
	var stranger := _stub(120.0, 3.0)
	CombatEvents.hit_landed.emit(_hit(stranger))
	assert_eq(_probe.current_metrics().unwarned_hits, 1, "an attacker that never wound up has no telegraph at all")


# --- R11: knockdown damage ----------------------------------------------------------------------------


func test_r11_the_most_a_non_boss_hit_that_knocked_the_player_down_cost() -> void:
	var stub := _stub(0.0, 3.0)
	CombatEvents.hit_landed.emit(_hit(stub, 12.0, CombatTypes.Reaction.KNOCKDOWN))
	CombatEvents.hit_landed.emit(_hit(stub, 18.0, CombatTypes.Reaction.STAGGER))
	var summary := _probe.end_act()
	assert_eq(summary.metrics.max_knockdown_hit_damage_non_boss, 12.0, "a stagger is not a knockdown")
	assert_eq(_status(summary.verdict, "R11"), "ok")


func test_r11_fails_above_fifteen_but_not_for_the_boss_or_a_blocked_hit() -> void:
	var stub := _stub(0.0, 3.0)
	var boss := _stub(120.0, 3.0)
	boss.add_to_group(&"boss")
	CombatEvents.hit_landed.emit(_hit(boss, 40.0, CombatTypes.Reaction.KNOCKDOWN))
	var blocked := _hit(stub, 20.0, CombatTypes.Reaction.KNOCKDOWN)
	blocked.blocked = true
	CombatEvents.hit_landed.emit(blocked)
	assert_eq(_probe.current_metrics().max_knockdown_hit_damage_non_boss, 0.0, "the boss is exempt (SPEC §4), a blocked hit knocks nobody down")
	CombatEvents.hit_landed.emit(_hit(stub, 20.0, CombatTypes.Reaction.LAUNCH))
	var summary := _probe.end_act()
	assert_eq(summary.metrics.max_knockdown_hit_damage_non_boss, 20.0)
	assert_eq(_status(summary.verdict, "R11"), "FAIL", "hard")


# --- R12: a player who never acts -----------------------------------------------------------------------


func test_r12_worst_two_seconds_of_damage_and_time_to_ko() -> void:
	_probe.start_act("passive", {"passive": true})
	var stub := _stub(0.0, 3.0)
	for i in 4:
		var hit := _hit(stub, 10.0)
		hit.is_body_impact = true
		CombatEvents.hit_landed.emit(hit)
		await _ticks(30)
	CombatEvents.ko.emit(_player, HitInfo.new())
	await _ticks(100)
	var late := _hit(stub, 10.0)
	late.is_body_impact = true
	CombatEvents.hit_landed.emit(late)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.max_damage_2s, 40.0, "four hits inside two seconds")
	assert_almost_eq(float(summary.metrics.passive_time_to_ko_s), 2.0, 0.1, "KO two seconds in")
	assert_eq(_status(summary.verdict, "R12"), "miss", "soft: under 12 s and over 30 damage")


func test_r12_only_applies_to_a_passive_act() -> void:
	var summary := _probe.end_act()
	assert_eq(_status(summary.verdict, "R12"), "n/a")


# --- R5, R6, R7: where the enemies stand ----------------------------------------------------------------


func test_r5_and_r6_a_wall_of_enemies_in_front_is_crowded_and_off_the_ring() -> void:
	for bearing in [0.0, 15.0, -15.0, 30.0]:
		_stub(bearing, 1.8 + absf(bearing) * 0.04)
	await _ticks(30)
	var summary := _probe.end_act()
	assert_gt(summary.metrics.front_wedge_crowding, 0.8, "four posturing within 45 degrees")
	assert_lt(summary.metrics.ring_adherence.median, 2.5, "inside the ring")
	assert_eq(_status(summary.verdict, "R5"), "miss")
	assert_eq(_status(summary.verdict, "R6"), "miss")


func test_r5_and_r6_enemies_around_the_player_on_the_ring_are_fine() -> void:
	var at := [[0.0, 3.0], [60.0, 3.4], [-60.0, 3.2], [130.0, 3.6], [-130.0, 3.0], [180.0, 3.3]]
	for item in at:
		_stub(item[0], item[1])
	await _ticks(20)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.front_wedge_crowding, 0.0)
	assert_between(summary.metrics.ring_adherence.median, 2.95, 3.45)
	assert_gte(summary.metrics.ring_adherence.p10, 2.95)
	assert_eq(_status(summary.verdict, "R5"), "ok")
	assert_eq(_status(summary.verdict, "R6"), "ok")


func test_r7_counts_frames_with_two_standing_capsules_overlapping() -> void:
	var a := _stub(0.0, 3.0)
	var b := _stub(90.0, 3.0)
	await _ticks(10)
	# Held where they are put (not simulated), so physics does not part them.
	a.set_physics_process(false)
	b.set_physics_process(false)
	b.global_position = a.global_position + Vector3(0.3, 0.0, 0.0)
	await _ticks(5)
	var summary := _probe.end_act()
	assert_gt(summary.metrics.capsule_overlap_frames, 0, "0.3 m apart is inside two 0.35 m capsules")
	assert_gt(summary.metrics.capsule_overlap_share, 0.0)
	assert_lt(summary.metrics.capsule_overlap_share, 1.0, "they were apart before")


func test_r7_stays_zero_for_enemies_that_keep_apart() -> void:
	_stub(0.0, 3.0)
	_stub(90.0, 3.0)
	await _ticks(20)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.capsule_overlap_frames, 0)
	assert_eq(_status(summary.verdict, "R7"), "ok")


# --- R9: grants to the blind side ----------------------------------------------------------------------


func test_r9_a_grant_to_the_one_out_of_view_when_both_kinds_wait_is_blind() -> void:
	var front := _stub(0.0, 3.0)
	var side := _stub(20.0, 3.5)
	var behind := _stub(150.0, 3.0)
	for stub in [front, side, behind]:
		stub.want_token = true
	await _ticks(4)
	behind.grant_token(true)
	await _ticks(3)
	front.grant_token(false)
	await _ticks(3)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.grants, 2)
	assert_eq(summary.metrics.mixed_grants, 1, "the second grant had only enemies in view left waiting")
	assert_eq(summary.metrics.blind_grant_share, 1.0)
	assert_eq(_status(summary.verdict, "R9"), "ok")


func test_r9_a_grant_to_one_in_view_while_one_out_of_view_waits_is_not() -> void:
	var front := _stub(0.0, 3.0)
	var behind := _stub(150.0, 3.0)
	front.want_token = true
	behind.want_token = true
	await _ticks(4)
	front.grant_token(false)
	await _ticks(3)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.blind_grant_share, 0.0)
	assert_eq(_status(summary.verdict, "R9"), "miss", "soft in a crowd act")


# --- R13: stuck enemies and cleared waves ----------------------------------------------------------------


func test_r13_an_enemy_walking_in_that_goes_nowhere_for_three_seconds_is_stuck() -> void:
	_approach_stub(0.0, Vector3(8.0, 0.0, 0.0), Vector3(0.0, 0.0, -6.0))
	await _ticks(200)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.stuck_events, 1, "one episode, counted once")
	assert_eq(_status(summary.verdict, "R13"), "miss")


func test_r13_one_that_keeps_walking_is_not_stuck() -> void:
	_approach_stub(0.02, Vector3(20.0, 0.0, 0.0), Vector3(-10.0, 0.0, -6.0))
	await _ticks(200)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.stuck_events, 0)
	assert_eq(_status(summary.verdict, "R13"), "ok")


func test_r13_a_wave_is_cleared_when_the_last_enemy_falls() -> void:
	var a := _stub(0.0, 3.0)
	var b := _stub(120.0, 3.0)
	await _ticks(5)
	a.health = 0.0
	await _ticks(3)
	assert_eq(_probe.current_metrics().waves_cleared, 0, "one still stands")
	b.health = 0.0
	await _ticks(3)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.waves_cleared, 1)
	assert_eq(summary.metrics.waves_cleared_90s, 1)
	assert_eq(summary.metrics.peak_alive, 2)


# --- R14: wind-up voices ------------------------------------------------------------------------------


func test_r14_is_not_measurable_without_an_audio_director() -> void:
	var summary := _probe.end_act()
	assert_null(summary.metrics.windup_voices_stolen)
	assert_eq(_status(summary.verdict, "R14"), "n/a")


func test_r14_counts_a_voice_taken_from_a_windup_that_was_still_running() -> void:
	var audio := FakeAudio.new()
	_scene.add_child(audio)
	var stub := _stub(0.0, 3.0)
	await _ticks(3)
	_probe.start_act("voices")
	stub.force_attack()
	await _ticks(4)
	assert_eq(stub.state, CombatTypes.ActorState.WINDUP)
	var id := stub.get_instance_id()
	audio.sound(1, id, true)
	audio.sound(2, id, true)
	await _ticks(2)
	# The pool gave voice 1 to another sound while it was still playing: the cue is cut, the wind-up runs on.
	audio.sound(1, 0, true)
	await _ticks(2)
	# Voice 2 had finished by itself: reusing it is not a steal.
	audio.sound(2, id, false)
	await _ticks(2)
	audio.sound(2, 0, true)
	# And a voice whose wind-up has ended (the strike is out) is simply reused.
	audio.sound(3, id, true)
	await _ticks(30)
	assert_ne(stub.state, CombatTypes.ActorState.WINDUP)
	audio.sound(3, 0, true)
	await _ticks(2)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.windup_voices_stolen, 1)
	assert_eq(_status(summary.verdict, "R14"), "miss")


func test_r14_reads_the_audio_directors_own_counter_when_it_has_one() -> void:
	var audio := FakeAudio.new()
	audio.windup_voices_stolen = 3
	_scene.add_child(audio)
	await _ticks(2)
	_probe.start_act("counter")
	audio.windup_voices_stolen = 5
	await _ticks(2)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.windup_voices_stolen, 2, "the rise during the act")


# --- R15: frame time and the spawn hitch ----------------------------------------------------------------------


func test_r15_samples_frame_times_and_notes_a_spawn() -> void:
	await _ticks(10)
	_stub(0.0, 3.0)
	await _ticks(60)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.spawns, 1)
	assert_not_null(summary.metrics.frame_ms_p95)
	assert_not_null(summary.metrics.spawn_hitch_ms, "the frames after the spawn were timed")
	assert_gte(float(summary.metrics.spawn_hitch_ms), 0.0)
	# On this machine's headless run the numbers are not the SPEC §10 target's, so they are not judged.
	assert_eq(_status(summary.verdict, "R15"), "n/a")


# --- R4 and R8: the lens --------------------------------------------------------------------------------------


func test_r8_the_lens_coverage_of_a_lone_enemy_ahead_is_a_small_share() -> void:
	_probe.lens_every = 2
	_stub(0.0, 2.0)
	await _ticks(20)
	var summary := _probe.end_act()
	var cover: Dictionary = summary.metrics.fp_enemy_coverage
	assert_gt(cover.samples, 5)
	assert_gt(cover.p50, 0.0, "it is in the lens")
	assert_lt(cover.p95, 0.25, "but a small part of it")
	assert_eq(_status(summary.verdict, "R8"), "ok")


func test_r8_a_wall_in_front_of_the_lens_is_too_much() -> void:
	_probe.lens_every = 2
	var blocker := _stub(0.0, 1.0)
	_cover_the_view(blocker)
	await _ticks(20)
	var summary := _probe.end_act()
	assert_gt(summary.metrics.fp_enemy_coverage.p50, 0.3)
	assert_eq(_status(summary.verdict, "R8"), "miss")


func test_r4_a_windup_in_the_open_is_not_occluded() -> void:
	_probe.occlusion_every = 2
	var attacker := _stub(0.0, 2.4)
	await _ticks(3)
	attacker.force_attack()
	await _ticks(40)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.occlusion_windups_in_view, 1)
	assert_eq(summary.metrics.occluded_windup_share, 0.0)
	assert_eq(_status(summary.verdict, "R4"), "ok")


func test_r4_a_windup_behind_another_enemys_body_is_occluded() -> void:
	_probe.occlusion_every = 2
	var blocker := _stub(0.0, 1.0)
	_cover_the_view(blocker)
	var attacker := _stub(0.0, 2.6)
	await _ticks(3)
	attacker.force_attack()
	await _ticks(40)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.occlusion_windups_in_view, 1)
	assert_eq(summary.metrics.occluded_windup_share, 1.0)
	assert_eq(_status(summary.verdict, "R4"), "miss")


func test_r4_a_windup_behind_the_player_is_not_in_view() -> void:
	_probe.occlusion_every = 2
	var attacker := _stub(180.0, 2.0)
	await _ticks(3)
	attacker.force_attack()
	await _ticks(40)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.occlusion_windups_in_view, 0)
	assert_null(summary.metrics.occluded_windup_share)


## A wide, tall box on `enemy`'s body, the way a big enemy would fill the view.
func _cover_the_view(enemy: EnemyActor) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6, 2.4, 0.4)
	box.mesh = mesh
	box.position = Vector3(0.0, 1.2, 0.0)
	enemy.add_child(box)


# --- R10: the warning, through the oracle the probe owns ---------------------------------------------------------


func test_r10_a_widget_that_matches_the_rule_passes() -> void:
	_scene.add_child(LeftWidget.new())
	var stub := _stub(135.0, 1.5)
	await _ticks(3)
	stub.force_attack()
	await _ticks(60)
	var summary := _probe.end_act()
	assert_eq(summary.metrics.warning_windups, 1)
	assert_eq(summary.metrics.warning_oracle_agreement, 1.0)
	assert_eq(summary.metrics.warning_false_positives, 0)
	assert_eq(_status(summary.verdict, "R10"), "ok")
	assert_true(_probe.oracle.lines[0].begins_with("WARN-CHECK ok "), _probe.oracle.lines[0])


func test_r10_a_burst_for_an_attacker_in_view_fails_hard() -> void:
	_scene.add_child(LeftWidget.new())
	var stub := _stub(20.0, 1.5)
	await _ticks(3)
	stub.force_attack()
	await _ticks(60)
	var summary := _probe.end_act()
	assert_gt(summary.metrics.warning_false_positives, 0)
	assert_eq(_status(summary.verdict, "R10"), "FAIL")
	assert_false(Probe.hard_ok(summary.verdict))


func test_r10_with_no_widget_a_corner_wind_up_fails() -> void:
	var stub := _stub(135.0, 1.5)
	await _ticks(3)
	stub.force_attack()
	await _ticks(60)
	var summary := _probe.end_act()
	assert_false(summary.metrics.warning_widget_found)
	assert_eq(_status(summary.verdict, "R10"), "FAIL")


# --- Verdicts: every threshold of Part B §B2 -------------------------------------------------------------------------


func _row_for(metrics: Dictionary, id: String, summary: Dictionary = {}) -> String:
	return _status(_probe.verdict(metrics, summary), id)


## Metrics that say nothing is wrong, to be spoiled one at a time.
func _clean_metrics() -> Dictionary:
	var m := _probe.current_metrics()
	m.max_concurrent_attackers = 2
	m.attacker_cap = 3
	m.attacker_cap_violation_frames = 0
	m.min_windup_start_gap_frames = 30
	m.hits_on_player = 4
	m.unwarned_hits = 0
	m.occluded_windup_share = 0.05
	m.occlusion_windups_in_view = 10
	m.front_wedge_crowding = 0.02
	m.ring_adherence = {"median": 3.2, "p10": 2.6, "samples": 100}
	m.capsule_overlap_frames = 1
	m.capsule_overlap_share = 0.001
	m.fp_enemy_coverage = {"p50": 0.15, "p95": 0.35, "samples": 20}
	m.blind_grant_share = 0.8
	m.mixed_grants = 5
	m.warning_windups = 10
	m.warning_oracle_agreement = 1.0
	m.warning_false_positives = 0
	m.warning_latency_frames = 1
	m.warning_end_lag_frames = 1
	m.max_knockdown_hit_damage_non_boss = 15.0
	m.max_damage_2s = 20.0
	m.passive_time_to_ko_s = 14.0
	m.stuck_events = 0
	m.waves_cleared_90s = 3
	m.windup_voices_stolen = 0
	return m


func test_verdict_passes_a_clean_run_and_names_each_threshold() -> void:
	var summary := {"seconds": 100.0, "tags": {"passive": true}}
	var rows := _probe.verdict(_clean_metrics(), summary)
	for row in rows:
		assert_true(row.status == "ok" or row.status == "n/a", "%s %s: %s" % [row.id, row.status, row.value])
	assert_true(Probe.hard_ok(rows))
	assert_eq(rows.size(), 15, "one row per metric R1 to R15")
	assert_eq(_status(rows, "R12"), "ok")
	assert_eq(_status(rows, "R13"), "ok")


func test_verdict_hard_rows_fail_and_soft_rows_miss() -> void:
	var summary := {"seconds": 100.0, "tags": {"passive": true}}
	var cases: Array[Array] = [
		["R1", "attacker_cap_violation_frames", 3, "FAIL"],
		["R2", "min_windup_start_gap_frames", 20, "FAIL"],
		["R3", "unwarned_hits", 1, "FAIL"],
		["R4", "occluded_windup_share", 0.11, "miss"],
		["R5", "front_wedge_crowding", 0.06, "miss"],
		["R7", "capsule_overlap_share", 0.006, "miss"],
		["R9", "blind_grant_share", 0.5, "miss"],
		["R10", "warning_oracle_agreement", 0.9, "FAIL"],
		["R10", "warning_false_positives", 1, "FAIL"],
		["R10", "warning_latency_frames", 2, "FAIL"],
		["R10", "warning_end_lag_frames", 2, "FAIL"],
		["R11", "max_knockdown_hit_damage_non_boss", 15.5, "FAIL"],
		["R12", "max_damage_2s", 31.0, "miss"],
		["R12", "passive_time_to_ko_s", 11.0, "miss"],
		["R13", "stuck_events", 1, "miss"],
		["R13", "waves_cleared_90s", 1, "miss"],
		["R14", "windup_voices_stolen", 1, "miss"],
	]
	for item in cases:
		var m := _clean_metrics()
		m[item[1]] = item[2]
		assert_eq(_row_for(m, item[0], summary), item[3], "%s with %s = %s" % [item[0], item[1], item[2]])
	var m := _clean_metrics()
	m.ring_adherence = {"median": 2.4, "p10": 2.6, "samples": 1}
	assert_eq(_row_for(m, "R6"), "miss", "median under 2.5 m")
	m.ring_adherence = {"median": 4.1, "p10": 3.0, "samples": 1}
	assert_eq(_row_for(m, "R6"), "miss", "median over 4.0 m")
	m.ring_adherence = {"median": 3.0, "p10": 2.1, "samples": 1}
	assert_eq(_row_for(m, "R6"), "miss", "10th percentile under 2.2 m")
	m = _clean_metrics()
	m.fp_enemy_coverage = {"p50": 0.26, "p95": 0.4, "samples": 1}
	assert_eq(_row_for(m, "R8"), "miss", "median over 25%")
	m.fp_enemy_coverage = {"p50": 0.2, "p95": 0.51, "samples": 1}
	assert_eq(_row_for(m, "R8"), "miss", "95th percentile over 50%")


func test_verdict_r2_reads_the_directors_gap_tunable() -> void:
	var m := _clean_metrics()
	m.min_windup_start_gap_frames = 15
	assert_eq(_row_for(m, "R2"), "FAIL", "the default 0.35 s is 21 frames")
	Tuning.data.director_min_windup_gap_s = 0.2
	assert_eq(_row_for(m, "R2"), "ok", "0.2 s is 12 frames")


func test_verdict_r1_with_cap_zero_never_fails_and_r13_waves_need_a_long_act() -> void:
	var m := _clean_metrics()
	m.attacker_cap = 0
	m.attacker_cap_violation_frames = 0
	m.max_concurrent_attackers = 6
	assert_eq(_row_for(m, "R1"), "ok")
	m.waves_cleared_90s = 0
	assert_eq(_row_for(m, "R13", {"seconds": 30.0, "tags": {}}), "ok", "a 30 s act is too short to ask for two waves")
	assert_eq(_row_for(m, "R13", {"seconds": 95.0, "tags": {}}), "miss")


func test_verdict_r12_a_passive_player_who_was_never_knocked_out_passes_if_the_act_was_long_enough() -> void:
	var m := _clean_metrics()
	m.passive_time_to_ko_s = null
	assert_eq(_row_for(m, "R12", {"seconds": 20.0, "tags": {"passive": true}}), "ok")
	assert_eq(_row_for(m, "R12", {"seconds": 5.0, "tags": {"passive": true}}), "miss")


func test_misses_lists_what_to_look_at() -> void:
	var m := _clean_metrics()
	m.unwarned_hits = 2
	m.stuck_events = 1
	var rows := _probe.verdict(m, {"seconds": 10.0, "tags": {}})
	var bad := Probe.misses(rows)
	assert_eq(bad.size(), 2)
	assert_false(Probe.hard_ok(rows))


# --- Acts, the summary and the JSON ------------------------------------------------------------------------------------


func test_acts_are_measured_apart_and_merged_in_the_total() -> void:
	_probe.start_act("one")
	var a := _stub(0.0, 3.0)
	var b := _stub(120.0, 3.0)
	await _ticks(3)
	a.force_attack()
	await _ticks(8)
	b.force_attack()
	await _ticks(40)
	var first := _probe.end_act()
	_probe.start_act("two")
	await _ticks(3)
	a.force_attack()
	await _ticks(60)
	b.force_attack()
	await _ticks(40)
	var second := _probe.end_act()
	assert_eq(first.title, "one")
	assert_eq(first.metrics.windups, 2)
	assert_eq(first.metrics.min_windup_start_gap_frames, 8)
	assert_gt(second.metrics.min_windup_start_gap_frames, 20, "the second act did not inherit the first's gap")
	assert_eq(_probe.acts().size(), 3, "the implicit act 'run' came first, empty")
	var total := _probe.total()
	assert_eq(total.metrics.windups, 4)
	assert_eq(total.metrics.min_windup_start_gap_frames, 8, "the least over every act")
	assert_eq(total.frames, int(first.frames) + int(second.frames) + int(_probe.acts()[0].frames))


func test_the_summary_is_one_screen_and_names_every_metric() -> void:
	var summary := _probe.end_act()
	var text := _probe.summary_text(summary)
	var lines := text.split("\n")
	assert_lte(lines.size(), 20, "one screen")
	assert_true(lines[0].begins_with("READABILITY run"))
	for id in ["R1 ", "R2 ", "R3 ", "R4 ", "R5 ", "R6 ", "R7 ", "R8 ", "R9 ", "R10", "R11", "R12", "R13", "R14", "R15"]:
		assert_true(text.contains("  %s" % id), "has a row for %s" % id)
	assert_true(text.contains("(hard)"), "marks the hard rows")


func test_it_writes_readability_json_per_act_and_total() -> void:
	_probe.start_act("first")
	await _ticks(5)
	_probe.start_act("second", {"passive": true})
	await _ticks(5)
	var dir := ProjectSettings.globalize_path("user://probe_test")
	var path := _probe.finish(dir)
	assert_eq(path, dir.path_join("readability.json"))
	assert_true(FileAccess.file_exists(path))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(data is Dictionary, "valid JSON")
	var report: Dictionary = data
	assert_eq(report.acts.size(), 3, "run, first, second")
	assert_eq(report.acts[2].title, "second")
	assert_eq(report.acts[2].tags.passive, true)
	for key in ["max_concurrent_attackers", "min_windup_start_gap_frames", "unwarned_hits", "occluded_windup_share",
			"front_wedge_crowding", "ring_adherence", "capsule_overlap_frames", "fp_enemy_coverage",
			"blind_grant_share", "warning_oracle_agreement", "warning_false_positives", "warning_latency_frames",
			"warning_end_lag_frames", "max_knockdown_hit_damage_non_boss", "passive_time_to_ko_s", "max_damage_2s",
			"stuck_events", "waves_cleared_90s", "windup_voices_stolen", "frame_ms_p95", "spawn_hitch_ms"]:
		assert_true(report.total.metrics.has(key), "total.metrics.%s" % key)
	assert_true(report.total.has("verdict"))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


func test_write_on_exit_leaves_a_report_when_the_bot_just_quits() -> void:
	var path := ProjectSettings.globalize_path("user://readability.json")
	DirAccess.remove_absolute(path)
	_probe.write_on_exit = true
	_probe.start_act("quit")
	await _ticks(3)
	_probe.free()
	assert_true(FileAccess.file_exists(path), "written as the node left the tree")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(data.acts[data.acts.size() - 1].title, "quit")
	DirAccess.remove_absolute(path)


func test_it_changes_nothing_in_the_game() -> void:
	var a := _stub(0.0, 3.0)
	await _ticks(3)
	a.force_attack()
	await _ticks(20)
	var before := [a.global_position, a.state, a.move_frame, _player.global_position, _player.health]
	_probe.occlusion_every = 1
	_probe.lens_every = 1
	_probe.current_metrics()
	_probe.tick()
	assert_eq([a.global_position, a.state, a.move_frame, _player.global_position, _player.health], before,
			"measuring a frame writes no game state")
