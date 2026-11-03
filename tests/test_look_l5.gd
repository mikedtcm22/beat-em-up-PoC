extends GutTest
## The L5 sampler (P3-early, slice-gate gap 1): R4 and R8 measured with the art drawn beside the proxies'
## figures (tests/bot/look_l5.gd), on small scenes with known answers: a Punk ahead, two Punks in a line, a
## Punk in the open, a Punk flying in a ragdoll, and the Kicker, whose primitives stand in front of no art.
## The act that plays two crowd fights through it is windowed work (a drawn-art sample costs 10 to 15 ms and
## a fight is 30 s), so the suite checks the instrument, not the fights.

const L5 := preload("res://tests/bot/look_l5.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const KICKER_SCENE := preload("res://game/enemies/kicker/kicker.tscn")
## The art and its proxies cover the view alike to within these (M4-plan A9: 3% of the cells, 4 points of share).
const CELLS_DIFFER_MAX := 0.03
const SHARE_DELTA_MAX := 0.04

var _scene: Node3D
var _player: PlayerCharacter


func before_each() -> void:
	# apply(), not reset_to_default(): the Debug group (look_show_art) is the part a reset leaves alone.
	Tuning.apply(TuningData.new())
	Tuning.set_value(&"ai_frozen", true)
	TimeController.clear()
	TimeController.debug_scale = 1.0
	PlaceholderAnims.warn_on_fallback = false
	SkinnedView.clear_cache()
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


func after_each() -> void:
	PlaceholderAnims.warn_on_fallback = true
	Tuning.apply(TuningData.new())
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## An enemy of `scene` `dist` m from the player at `bearing` degrees (0 ahead, positive to the left),
## facing him.
func _enemy(scene: PackedScene, bearing: float, dist: float) -> EnemyActor:
	var enemy := scene.instantiate() as EnemyActor
	var b := deg_to_rad(bearing)
	enemy.position = _player.global_position + Vector3(-sin(b), 0.0, -cos(b)) * dist
	var to_player := _player.global_position - enemy.position
	enemy.rotation.y = atan2(-to_player.x, -to_player.z)
	_scene.add_child(enemy)
	return enemy


func _sampler(label: String = "test") -> RefCounted:
	var sampler: RefCounted = L5.new(_scene, _player, label)
	sampler.occlusion_every = 2
	sampler.lens_every = 2
	return sampler


func _run(sampler: RefCounted, ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame
		sampler.tick()
	sampler.finish()


# --- R8 -----------------------------------------------------------------------------------------------


func test_a_punk_ahead_covers_the_view_alike_drawn_and_by_its_proxies() -> void:
	var punk := _enemy(PUNK_SCENE, 0.0, 1.6)
	await _ticks(4)
	assert_true(punk.rig.has_art(), "the Punk wears the art")
	assert_true(punk.rig.art_meshes()[0].is_visible_in_tree(), "and it shows (so the drawn measure is not the proxies' by default)")
	var sampler := _sampler()
	await _run(sampler, 20)
	var m: Dictionary = sampler.summary()
	print("L5 TEST one Punk at 1.6 m: proxies p50 %.3f, art p50 %.3f, cells that differ %.4f" % [m.r8_proxies_p50, m.r8_art_p50, m.cells_disagree])
	assert_gt(m.samples, 5, "the lens was sampled")
	assert_gt(m.r8_proxies_p50, 0.05, "the Punk covers part of the view")
	assert_gt(m.r8_art_p50, 0.05, "and the art does")
	assert_lt(absf(m.r8_art_p50 - m.r8_proxies_p50), SHARE_DELTA_MAX, "within 4 points")
	assert_lt(m.cells_disagree_max, CELLS_DIFFER_MAX + 0.02, "and on the same cells")
	assert_eq(sampler.lines().size(), 2, "one line for R8 and one for R4")
	assert_true(sampler.lines()[0].begins_with("LOOK-L5 test R8 "))
	assert_true(sampler.lines()[1].begins_with("LOOK-L5 test R4 "))


func test_with_the_art_off_the_two_are_the_same_measure() -> void:
	# The A/B off: the primitives show, the art does not, and the drawn measure is the proxies'.
	Tuning.set_value(&"look_show_art", false)
	_enemy(PUNK_SCENE, 0.0, 1.6)
	_enemy(PUNK_SCENE, 25.0, 2.4)
	await _ticks(4)
	var sampler := _sampler()
	await _run(sampler, 12)
	var m: Dictionary = sampler.summary()
	assert_gt(m.r8_proxies_p50, 0.05)
	assert_eq(m.r8_art_p50, m.r8_proxies_p50, "the same share")
	assert_eq(m.cells_disagree_max, 0.0, "on every cell")


func test_an_enemy_without_art_is_counted_as_it_was() -> void:
	# The Kicker has no art: both ways see its primitives, so the two agree on it.
	var kicker := _enemy(KICKER_SCENE, 0.0, 1.6)
	await _ticks(4)
	assert_false(kicker.rig.has_art())
	var sampler := _sampler()
	await _run(sampler, 12)
	var m: Dictionary = sampler.summary()
	assert_gt(m.r8_proxies_p50, 0.05)
	assert_eq(m.r8_art_p50, m.r8_proxies_p50)
	assert_eq(m.cells_disagree_max, 0.0)


func test_a_flying_punk_is_measured_in_the_pose_the_ragdoll_draws() -> void:
	# A Punk launched past the lens: while its ragdoll runs the proxies follow the ragdoll's pose (the bone
	# followers) and the drawn art is skinned in the same one (SkinnedView.drawn_pose()), so the two
	# stay together through the flight.
	var punk := _enemy(PUNK_SCENE, 0.0, 1.5)
	await _ticks(4)
	assert_true(punk.rig.art_meshes()[0].is_visible_in_tree(), "the art shows")
	var hit := HitInfo.new()
	hit.attacker = _player
	hit.victim = punk
	hit.damage = 1.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.LAUNCH
	hit.region = CombatTypes.Region.TORSO
	hit.direction = Vector3(0.6, 0.0, -0.8)
	hit.knockback = Vector3(2.4, 3.0, -3.2)
	hit.contact_point = punk.rig.get_point_position(&"ChestPoint") - hit.direction * 0.15
	hit.physics_frame = Engine.get_physics_frames()
	assert_true(punk.receive_hit(hit))
	var sampler := _sampler()
	var ragdolling := 0
	var worst_cells := 0.0
	for i in 40:
		await get_tree().physics_frame
		sampler.tick()
		ragdolling += int(punk.rig.is_ragdolling())
	var m: Dictionary = sampler.summary()
	worst_cells = m.cells_disagree_max
	print("L5 TEST a launched Punk: %d ticks of ragdoll, cells that differ: mean %.4f worst %.4f" % [ragdolling, m.cells_disagree, worst_cells])
	assert_gt(ragdolling, 10, "the ragdoll ran for a while")
	assert_gt(m.r8_art_max, 0.01, "the flying body was in the lens")
	assert_lt(m.cells_disagree, CELLS_DIFFER_MAX, "the art and the proxies agree through the flight")


# --- R4 -----------------------------------------------------------------------------------------------


func test_a_windup_in_the_open_is_not_hidden_either_way() -> void:
	var attacker := _enemy(PUNK_SCENE, 0.0, 2.4)
	await _ticks(3)
	attacker.force_attack()
	var sampler := _sampler()
	await _run(sampler, 60)
	var m: Dictionary = sampler.summary()
	assert_eq(m.windups_in_view, 1, "the wind-up was in the lens")
	assert_eq(m.r4_proxies, 0)
	assert_eq(m.r4_art, 0)


func test_a_windup_behind_an_art_punk_is_hidden_drawn_and_by_the_proxies() -> void:
	# Two Punks in a line: the rear one winds up behind the one in front. The proxies' answer is the
	# probe's (slice-g1-01); the drawn one is by native triangle rays at the art's pose.
	var blocker := _enemy(PUNK_SCENE, 0.0, 1.1)
	var attacker := _enemy(PUNK_SCENE, 0.0, 2.6)
	await _ticks(3)
	assert_true(blocker.rig.has_art(), "the blocker wears the art")
	assert_true(blocker.rig.art_meshes()[0].is_visible_in_tree(), "and it shows (visible %s, rig visible %s)" % [blocker.rig.art_meshes()[0].visible, blocker.rig.visible])
	attacker.force_attack()
	var sampler := _sampler()
	await _run(sampler, 60)
	var m: Dictionary = sampler.summary()
	assert_eq(m.windups_in_view, 1, "the rear Punk's wind-up is in the lens")
	assert_eq(m.r4_proxies, 1, "hidden by the Punk in front, by its proxies")
	assert_eq(m.r4_art, 1, "and as drawn")


func test_a_windup_behind_an_enemy_without_art_is_hidden_by_its_primitives() -> void:
	var blocker := _enemy(KICKER_SCENE, 0.0, 1.1)
	var attacker := _enemy(PUNK_SCENE, 0.0, 2.6)
	await _ticks(3)
	assert_false(blocker.rig.has_art())
	attacker.force_attack()
	var sampler := _sampler()
	await _run(sampler, 60)
	var m: Dictionary = sampler.summary()
	assert_eq(m.windups_in_view, 1)
	assert_eq(m.r4_proxies, 1)
	assert_eq(m.r4_art, 1)


func test_a_windup_beside_the_blocker_is_not_hidden() -> void:
	var blocker := _enemy(PUNK_SCENE, 0.0, 1.1)
	var attacker := _enemy(PUNK_SCENE, 30.0, 2.6)
	await _ticks(3)
	assert_not_null(blocker)
	attacker.force_attack()
	var sampler := _sampler()
	await _run(sampler, 60)
	var m: Dictionary = sampler.summary()
	assert_eq(m.windups_in_view, 1)
	assert_eq(m.r4_proxies, 0)
	assert_eq(m.r4_art, 0, "drawn: the Punk in front is not in the way")


func test_a_windup_behind_the_player_is_not_in_the_lens() -> void:
	var attacker := _enemy(PUNK_SCENE, 180.0, 2.0)
	await _ticks(3)
	attacker.force_attack()
	var sampler := _sampler()
	await _run(sampler, 60)
	var m: Dictionary = sampler.summary()
	assert_eq(m.windups, 1)
	assert_eq(m.windups_in_view, 0)


func test_the_sampler_follows_the_probes_cadence() -> void:
	_enemy(PUNK_SCENE, 0.0, 1.6)
	await _ticks(3)
	var sampler := _sampler()
	sampler.lens_every = 10
	await _run(sampler, 50)
	assert_eq(sampler.summary().samples, 5, "one R8 sample every 10 ticks, counted from the first tick")
