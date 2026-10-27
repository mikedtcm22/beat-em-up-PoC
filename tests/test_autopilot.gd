extends GutTest
## The autopilot (tests/bot/autopilot.gd, Milestone 3): the scripted player of the crowd bot's fight
## acts. Each behaviour is run against stub enemies (tests/fixtures/stub_enemy.tscn) in a small
## code-built arena with a real player: it faces the nearest enemy and fights, blocks a wind-up
## that is about to land in front, dodges when two land at once, turns (and quick-turns) to a
## wind-up behind it, and mashes when held.

const Autopilot := preload("res://tests/bot/autopilot.gd")
const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const GRAB_TEST := preload("res://tests/fixtures/grab_test_enemy.tscn")

var _scene: Node3D
var _player: PlayerCharacter
var _pilot: Autopilot
var _hits: Array[HitInfo] = []
var _decisions: Array[StringName] = []


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	PlaceholderAnims.warn_on_fallback = false
	_hits.clear()
	_decisions.clear()
	CombatEvents.hit_landed.connect(_on_hit)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	_scene.add_child(floor_body)
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_pilot = Autopilot.new()
	_pilot.decided.connect(func(what: StringName) -> void: _decisions.append(what))
	autofree(_pilot)


func after_each() -> void:
	if CombatEvents.hit_landed.is_connected(_on_hit):
		CombatEvents.hit_landed.disconnect(_on_hit)
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	TimeController.clear()


func _on_hit(hit: HitInfo) -> void:
	_hits.append(hit)


# --- Harness ----------------------------------------------------------------------------


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The pilot, in the tree and in charge of the player. Everything off but what a test names.
func _engage(defend: bool = true, attack: bool = true, approach: bool = true) -> void:
	_pilot.defend = defend
	_pilot.attack = attack
	_pilot.approach = approach
	_scene.add_child(_pilot)
	_pilot.attach(null, _player)


## A stub `dist` m from the player, `bearing` degrees from its look (positive left), by hand:
## the look at yaw 0 faces -Z, and left is -X.
func _stub(bearing: float, dist: float) -> EnemyActor:
	var stub := STUB_ENEMY.instantiate() as EnemyActor
	var yaw := _player.look_yaw
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var left := Vector3(-cos(yaw), 0.0, sin(yaw))
	stub.position = _player.global_position + (ahead * cos(deg_to_rad(bearing)) + left * sin(deg_to_rad(bearing))) * dist
	# Facing the player, as the fight's own enemies do, so its strike is aimed at it.
	var to_player := _player.global_position - stub.position
	stub.rotation.y = atan2(-to_player.x, -to_player.z)
	_scene.add_child(stub)
	return stub


func _bearing_to(stub: Node3D) -> float:
	return _player.look_bearing_deg(stub.global_position)


## The smallest angle (degrees, either side) between the look and `stub` over the next `ticks` frames.
func _closest_look(stub: Node3D, ticks: int) -> float:
	var best := 180.0
	for i in ticks:
		await get_tree().physics_frame
		best = minf(best, absf(_bearing_to(stub)))
	return best


func _on_player(hits: Array[HitInfo]) -> Array[HitInfo]:
	var out: Array[HitInfo] = []
	for hit in hits:
		if hit.victim == _player:
			out.append(hit)
	return out


# --- Offence --------------------------------------------------------------------------------------


func test_it_turns_to_the_nearest_enemy_then_walks_up_and_punches_it() -> void:
	var stub := _stub(90.0, 3.5)
	_engage()
	await _ticks(2)
	assert_gt(absf(_bearing_to(stub)), 60.0, "it starts looking away")
	await _ticks(30)
	assert_lt(absf(_bearing_to(stub)), 20.0, "turned to it")
	await _ticks(200)
	var r := _pilot.result()
	assert_gt(r.approach_ticks, 0, "it walked up")
	assert_gt(r.punches, 0, "and threw punches")
	assert_lt(stub.health, stub.max_health, "that landed")
	assert_true(_decisions.has(&"attack"))
	assert_true(_on_player(_hits).is_empty(), "a standing enemy hit nobody")


func test_it_chains_four_punches_then_three_kicks() -> void:
	var stub := _stub(0.0, 1.2)
	stub.max_health = 5000.0
	stub.health = 5000.0
	_engage()
	await _ticks(260)
	var r := _pilot.result()
	assert_gt(r.punches, 3, "P P P P")
	assert_gt(r.kicks, 0, "then K K K")


func test_it_holds_still_when_there_is_nobody_to_fight() -> void:
	_engage()
	await _ticks(30)
	var r := _pilot.result()
	assert_eq(r.punches, 0)
	assert_eq(_decisions.back(), &"idle")
	assert_eq(_player.global_position, Vector3.ZERO, "and it did not walk anywhere")


# --- Defence ----------------------------------------------------------------------------------------


func test_it_blocks_a_windup_in_front_just_before_the_strike() -> void:
	var stub := _stub(0.0, 1.0)
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	await _ticks(10)
	assert_ne(_player.state, CombatTypes.ActorState.BLOCK, "not yet: the guard goes up when the strike is six frames away")
	await _ticks(16)
	assert_true(_player.state in [CombatTypes.ActorState.BLOCK, CombatTypes.ActorState.BLOCKSTUN], "guard up: %d" % _player.state)
	await _ticks(20)
	var landed := _on_player(_hits)
	assert_eq(landed.size(), 1, "the jab came out")
	assert_true(landed[0].blocked, "into the guard")
	assert_eq(_pilot.result().blocks, 1)
	await _ticks(80)
	assert_eq(_player.state, CombatTypes.ActorState.FREE, "the guard came down when the attack was over")
	assert_ne(_decisions.back(), &"block")


func test_it_does_not_block_an_attack_that_cannot_reach_it() -> void:
	var stub := _stub(0.0, 3.0)
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	await _ticks(40)
	assert_eq(_pilot.result().blocks, 0, "out of reach, nothing to block")


func test_it_dodges_sideways_when_two_windups_land_together() -> void:
	var a := _stub(10.0, 1.0)
	var b := _stub(60.0, 1.0)
	_engage(true, false, false)
	await _ticks(2)
	var start := _player.global_position
	a.force_attack()
	b.force_attack()
	await _ticks(60)
	var r := _pilot.result()
	assert_eq(r.dodges, 1, "once")
	assert_eq(r.blocks, 0, "dodging, not guarding")
	assert_gt(_player.global_position.x - start.x, 1.0, "to the right, away from the two on its left")
	assert_true(_on_player(_hits).is_empty(), "and neither hit it")


func test_it_does_not_dodge_a_single_attacker() -> void:
	var a := _stub(10.0, 1.0)
	_engage(true, false, false)
	await _ticks(2)
	a.force_attack()
	await _ticks(60)
	assert_eq(_pilot.result().dodges, 0)
	assert_eq(_pilot.result().blocks, 1)


## A standing enemy just ahead: the nearest one, so the pilot looks at it until something else
## winds up (it always faces the nearest enemy, so a wind-up it has not been watching needs one).
func _decoy() -> EnemyActor:
	return _stub(0.0, 0.9)


func test_it_quick_turns_to_a_windup_directly_behind() -> void:
	_decoy()
	var stub := _stub(180.0, 1.0)
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	var closest := await _closest_look(stub, 60)
	assert_eq(_pilot.result().quick_turns, 1, "both corners lit: turn 180 at once")
	assert_lt(closest, 25.0, "it faced the attacker")


func test_it_turns_to_a_windup_behind_and_to_one_side_without_quick_turning() -> void:
	_decoy()
	var stub := _stub(135.0, 1.0)
	# A quick pilot: it sees the wind-up in four frames and turns 135 degrees in a dozen.
	_pilot.reaction_frames = 4
	_pilot.turn_deg_per_s = 720.0
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	var closest := await _closest_look(stub, 60)
	assert_true(_decisions.has(&"turn_behind"), "it turned toward the warning")
	assert_eq(_pilot.result().quick_turns, 0, "135 degrees is one corner, not directly behind")
	assert_lt(closest, 30.0, "it faced the attacker")


func test_it_reacts_after_its_reaction_time_not_before() -> void:
	_decoy()
	var stub := _stub(135.0, 1.0)
	_pilot.reaction_frames = 20
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	await _ticks(12)
	assert_false(_decisions.has(&"turn_behind"), "still reacting")
	await _ticks(10)
	assert_true(_decisions.has(&"turn_behind"), "reacted once it had seen it long enough")


# --- Held, down, off ---------------------------------------------------------------------------------


func test_it_mashes_while_held() -> void:
	# Held for real (the player's _control_grabbed() lets go of a holder that is not holding, so a
	# stub cannot hold him): the test grabber's grab, the pilot doing nothing else.
	Tuning.data.ai_frozen = true
	var holder := GRAB_TEST.instantiate() as EnemyActor
	holder.position = _player.global_position + Vector3(0.0, 0.0, -1.05)
	holder.rotation.y = PI
	_scene.add_child(holder)
	_engage(false, false, false)
	await _ticks(4)
	holder.force_attack()
	for i in 120:
		if _player.state == CombatTypes.ActorState.GRABBED:
			break
		await _ticks(1)
	assert_eq(_player.state, CombatTypes.ActorState.GRABBED)
	await _ticks(16)
	assert_gte(_pilot.result().mashes, 5, "P and K, over and over")
	assert_true(_decisions.has(&"mash"))
	await _ticks(30)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "and it mashed free")


func test_a_ko_player_is_left_alone() -> void:
	var stub := _stub(0.0, 1.0)
	_engage()
	_player.health = 0.0
	await _ticks(2)
	stub.force_attack()
	await _ticks(30)
	var r := _pilot.result()
	assert_eq(r.punches + r.blocks + r.dodges, 0)
	assert_eq(_decisions.back(), &"down")


func test_a_player_knocked_out_behind_a_raised_guard_lets_it_go() -> void:
	var stub := _stub(0.0, 1.0)
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	await _ticks(20)
	assert_true(_player.state in [CombatTypes.ActorState.BLOCK, CombatTypes.ActorState.BLOCKSTUN], "guard up")
	stub.abort_move()
	_player.health = 0.0
	await _ticks(60)
	assert_eq(_player.state, CombatTypes.ActorState.FREE, "B was released, so the guard came down and stays down")


func test_disabled_it_does_nothing_and_stop_lets_go_of_the_guard() -> void:
	var stub := _stub(0.0, 1.0)
	_engage(true, false, false)
	await _ticks(2)
	stub.force_attack()
	await _ticks(20)
	assert_eq(_pilot.result().blocks, 1, "guard up")
	_pilot.enabled = false
	_pilot.stop()
	await _ticks(60)
	assert_ne(_player.state, CombatTypes.ActorState.BLOCK, "stop() released B")
	var ticks_before: int = _pilot.result().ticks
	await _ticks(10)
	assert_eq(_pilot.result().ticks, ticks_before, "disabled, it does not tick")


func test_two_runs_of_the_same_fight_do_the_same_thing() -> void:
	var first := await _run_dodge_scenario()
	var second := await _run_dodge_scenario()
	assert_eq(first, second, "seeded, so a recording repeats")


func _run_dodge_scenario() -> Dictionary:
	var pilot := Autopilot.new()
	var player := PlayerCharacter.new()
	_scene.add_child(player)
	player.global_position = Vector3(10.0, 0.0, 0.0)
	var stubs: Array[EnemyActor] = []
	for bearing in [10.0, 60.0]:
		var stub := STUB_ENEMY.instantiate() as EnemyActor
		stub.position = player.global_position + Vector3(-sin(deg_to_rad(bearing)), 0.0, -cos(deg_to_rad(bearing)))
		var to_player := player.global_position - stub.position
		stub.rotation.y = atan2(-to_player.x, -to_player.z)
		_scene.add_child(stub)
		stubs.append(stub)
	pilot.defend = true
	pilot.attack = false
	pilot.approach = false
	_scene.add_child(pilot)
	pilot.attach(null, player)
	await _ticks(2)
	for stub in stubs:
		stub.force_attack()
	await _ticks(60)
	var out := pilot.result()
	out.erase("ticks")
	out["x"] = snappedf(player.global_position.x - 10.0, 0.01)
	pilot.queue_free()
	player.queue_free()
	for stub in stubs:
		stub.queue_free()
	await _ticks(2)
	return out
