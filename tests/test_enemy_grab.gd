extends GutTest
## An enemy's grab on the player (Milestone 3, P2-grab), proved with the test grabber
## (tests/fixtures/grab_test_enemy.gd: its only attack is the grab and its follow-up, the Bruiser's
## headbutt or, as the boss, the slam): the wind-up that a dodge, a jump or a heavy hit on an
## armored grabber gets out of, a connect only when the player can be grabbed, the held player
## mashing free before the follow-up's strike frame (and not with one press fewer), the unbroken hit
## landing, the holder letting go when it is hit or killed, the warning ending on the grab, and the
## director holding its tokens back while the player is held. The tests run on a flat floor with the
## real player and a stub director; the same grabber is spawned in the crowd room and the training
## room at the end. One sim tick is one physics frame (the runner uses --fixed-fps 60).

const GRABBER_SCENE := preload("res://tests/fixtures/grab_test_enemy.tscn")
const BOSS_SCENE := preload("res://tests/fixtures/grab_test_boss.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const MOVES_DIR := "res://game/combat/moves/"
const LONG_TICKS := 900

var _scene: Node3D
var _player: PlayerCharacter
var _director: Object
var _hits: Array[HitInfo] = []
var _whiffs: Array[MoveData] = []
var _ended: Array[Dictionary] = []


func before_each() -> void:
	Tuning.reset_to_default()
	# The grabber stands where it is put and faces the player: force_attack() still starts its attack.
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	_hits.clear()
	_whiffs.clear()
	_ended.clear()
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_whiffed.connect(_on_whiffed)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	_director = StubDirector.new()
	_scene.add_child(_director)


func after_each() -> void:
	for pair: Array in [[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.attack_whiffed, _on_whiffed],
			[CombatEvents.windup_ended, _on_windup_ended]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


func _on_whiffed(_attacker: Node3D, move: MoveData) -> void:
	_whiffs.append(move)


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	_ended.append({attacker = attacker, interrupted = interrupted})


# --- Harness ----------------------------------------------------------------------------------


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_scene.add_child(body)
	return body


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(condition: Callable, max_ticks: int = LONG_TICKS) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## The test grabber `ahead_m` in front of the player (who looks along -Z), facing him. `boss`: the
## boss-sized one with the slam.
func _grabber(ahead_m: float = 1.05, boss: bool = false, configure: Callable = Callable()) -> EnemyActor:
	var scene := BOSS_SCENE if boss else GRABBER_SCENE
	var enemy := scene.instantiate() as EnemyActor
	enemy.name = "Grabber1"
	enemy.position = Vector3(0.0, 0.0, -ahead_m)
	enemy.rotation.y = PI
	if configure.is_valid():
		configure.call(enemy)
	_scene.add_child(enemy)
	return enemy


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


## Wait until the grab has connected (the player is GRABBED) or `ticks` have passed.
func _until_held(ticks: int = 120) -> bool:
	return await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBED, ticks)


## Press P `n` times a tick apart (a mash), starting now.
func _mash(n: int, gap_ticks: int = 2) -> void:
	for i in n:
		_player.input.push_press(&"P", 1)
		await _ticks(gap_ticks)


# --- The connect ------------------------------------------------------------------------------


func test_a_grab_in_range_connects_and_holds_the_player() -> void:
	var grabber := _grabber()
	await _ticks(4)
	watch_signals(CombatEvents)
	grabber.force_attack()
	assert_true(await _until_held(), "the player is grabbed")
	assert_eq(_player.holder, grabber, "by the grabber")
	assert_true(grabber.is_holding(_player), "it holds him")
	assert_eq(grabber.current_move.id, &"bruiser_headbutt", "the headbutt's wind-up runs while he is held")
	assert_eq(grabber.state, CombatTypes.ActorState.WINDUP)
	assert_signal_emitted(CombatEvents, "grabbed")
	assert_eq(_whiffs.size(), 0, "no whiff")


func test_unbroken_the_headbutt_lands_for_15_and_knocks_him_down() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	var held_at := Engine.get_physics_frames()
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 200), "the headbutt hit lands")
	var hit := _hits[0]
	assert_eq(hit.move.id, &"bruiser_headbutt")
	assert_eq(hit.victim, _player)
	assert_eq(hit.damage, 15.0, "15 damage")
	assert_eq(hit.reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_eq(_player.health, 85.0, "the player lost 15 health")
	assert_gte(Engine.get_physics_frames() - held_at, _move(&"bruiser_headbutt").startup, "after the whole mash window")
	await _ticks(2)
	assert_true(_player.state in [CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.DOWNED], "knocked down")
	assert_null(_player.holder, "let go first")
