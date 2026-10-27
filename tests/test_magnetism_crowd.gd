extends GutTest
## Target magnetism in a crowd (Milestone 3, M3-plan A5.1): the strike's lunge finds a body by its
## heading alone (a flat cone, so a tall Bruiser is found at any pitch of the look), passes over
## a body in the get-up's invulnerability, stops further from a body wider than the player's own,
## and a K at a body on the ground with a standing enemy in the cone is a kick at the standing one,
## not a stomp. Bare actors on a flat floor, the player looking along -Z.

const StubEnemyScene := preload("res://tests/fixtures/stub_enemy.tscn")
const GRABBER_SCENE := preload("res://tests/fixtures/grab_test_enemy.tscn")

var _scene: Node3D
var _player: PlayerCharacter


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = true
	TimeController.clear()
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_scene.add_child(floor_body)
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true


func after_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## An enemy stand-in `x` right and `ahead` in front of the player, facing him.
func _enemy(x: float, ahead: float, scene: PackedScene = StubEnemyScene) -> EnemyActor:
	var enemy := scene.instantiate() as EnemyActor
	enemy.position = Vector3(x, 0.0, -ahead)
	enemy.rotation.y = PI
	_scene.add_child(enemy)
	return enemy


func test_an_enemy_in_the_cone_is_the_target_and_one_outside_it_is_not() -> void:
	var near := _enemy(0.0, 1.5)
	await _ticks(3)
	assert_eq(_player._find_magnet_target(null), near, "dead ahead")
	near.global_position = Vector3(2.0, 0.0, -1.0)
	assert_null(_player._find_magnet_target(null), "63 degrees off and 2.2 m out: nobody")


func test_the_cone_is_flat_a_tall_body_is_found_at_any_pitch_of_the_look() -> void:
	var bruiser := _enemy(0.0, 1.2, GRABBER_SCENE)
	await _ticks(3)
	for pitch_deg: float in [-70.0, -30.0, 0.0, 30.0, 70.0]:
		_player.look_pitch = deg_to_rad(pitch_deg)
		assert_eq(_player._find_magnet_target(null), bruiser, "found with the look at %.0f degrees" % pitch_deg)


func test_a_body_in_get_up_invulnerability_is_passed_over() -> void:
	var getting_up := _enemy(0.0, 1.2)
	var behind_it := _enemy(0.3, 2.0)
	await _ticks(3)
	assert_eq(_player._find_magnet_target(null), getting_up, "standing and vulnerable: the nearest to the center")
	getting_up._invuln_frames = Tuning.data.getup_invuln_frames
	assert_true(getting_up.is_invulnerable())
	assert_eq(_player._find_magnet_target(null), behind_it, "invulnerable: the next one is picked")
	behind_it._invuln_frames = 20
	assert_null(_player._find_magnet_target(null), "nobody else: no lunge at a body no hit lands on")


func test_the_lunge_stops_further_from_a_wider_body() -> void:
	var punk := _enemy(0.0, 1.5)
	var jab: MoveData = load("res://game/combat/moves/jab_1.tres")
	await _ticks(3)
	var narrow := _player._stop_distance(jab, punk)
	assert_almost_eq(narrow, Tuning.data.magnet_stop_distance, 0.0001, "a body of his own width: the tunable")
	var bruiser := _enemy(0.0, 1.5, GRABBER_SCENE)
	var boss := _enemy(0.0, 1.5, preload("res://tests/fixtures/grab_test_boss.tscn"))
	await _ticks(3)
	assert_almost_eq(_player._stop_distance(jab, bruiser), narrow + (bruiser.body_radius - _player.body_radius), 0.0001, "the Bruiser's radius over his own added")
	assert_almost_eq(_player._stop_distance(jab, boss), narrow + (boss.body_radius - _player.body_radius), 0.0001, "and the boss's")
	var stomp: MoveData = load("res://game/combat/moves/stomp.tres")
	assert_almost_eq(_player._stop_distance(stomp, boss), Tuning.data.stomp_stop_distance + (boss.body_radius - _player.body_radius), 0.0001, "a stomp too")
	assert_gt(_player._stop_distance(jab, bruiser), _player._stop_distance(jab, punk), "further from a Bruiser than from a Punk")


func test_a_jab_at_a_bruiser_closes_to_the_wider_stop_distance_not_into_its_capsule() -> void:
	var bruiser := _enemy(0.0, 1.5, GRABBER_SCENE)
	await _ticks(4)
	_player.input.push_press(&"P", 2)
	await _ticks(25)
	var gap := Vector2(bruiser.global_position.x - _player.global_position.x, bruiser.global_position.z - _player.global_position.z).length()
	var stop := Tuning.data.magnet_stop_distance + (bruiser.body_radius - _player.body_radius)
	assert_gte(gap, stop - 0.03, "the lunge stopped %.2f m from the Bruiser's origin (its stop distance %.2f)" % [gap, stop])
	assert_lt(gap, 1.5, "and it did close in")


func test_a_k_at_a_body_on_the_ground_stomps_only_when_no_standing_enemy_is_in_the_cone() -> void:
	var downed := _enemy(0.0, 1.0)
	await _ticks(3)
	downed._enter_state(CombatTypes.ActorState.DOWNED)
	assert_true(_player._conditions()[CombatTypes.COND_DOWNED_TARGET_NEAR], "a body on the ground in front: the stomp")
	var standing := _enemy(0.0, 1.8)
	await _ticks(3)
	assert_false(_player._conditions()[CombatTypes.COND_DOWNED_TARGET_NEAR], "a Punk standing in the cone behind it: no stomp")
	standing.global_position = Vector3(5.0, 0.0, -1.8)
	assert_true(_player._conditions()[CombatTypes.COND_DOWNED_TARGET_NEAR], "out of the cone: the stomp again")
	standing.global_position = Vector3(0.0, 0.0, -1.8)
	standing._invuln_frames = 30
	assert_true(_player._conditions()[CombatTypes.COND_DOWNED_TARGET_NEAR], "a Punk getting up in the cone does not count either")


func test_k_picks_the_front_kick_over_the_stomp_with_a_punk_in_front_and_the_stomp_without() -> void:
	var downed := _enemy(0.0, 1.0)
	var standing := _enemy(0.0, 1.8)
	await _ticks(3)
	downed._enter_state(CombatTypes.ActorState.DOWNED)
	_player.parser.press(CombatTypes.IN_KICK)
	var with_punk := _player.parser.select(false, _player._conditions())
	assert_not_null(with_punk)
	assert_eq(with_punk.move.id, &"front_kick", "a front kick at the standing enemy")
	standing.global_position = Vector3(6.0, 0.0, -1.8)
	_player.parser.reset_chain()
	_player.parser.clear_buffer()
	_player.parser.press(CombatTypes.IN_KICK)
	var alone := _player.parser.select(false, _player._conditions())
	assert_not_null(alone)
	assert_eq(alone.move.id, &"stomp", "the stomp with nobody standing in the cone")
