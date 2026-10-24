extends GutTest
## Milestone 2 phase 3: KO bodies blink off (Game-boy's departure from Spec §6; the
## CombatActor class docs). A KO'd dummy lies limp for Tuning.ko_linger_s, blinks for
## ko_blink_s (faster toward the end) and is gone: hidden, its ragdoll stopped, no
## hurtboxes, no collision, and nothing that looks for bodies finds it. A training dummy
## then comes back at its post after dummy_revive_s, blinking in, at full health with a clean
## damage look. The player never blinks off.

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)
const JAB_PATH := "res://game/combat/moves/jab_1.tres"

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())


func after_each() -> void:
	TimeController.clear()


# --- Harness ------------------------------------------------------------------------


## Build the room (with the HUD and VFX when `presentation`); `posts` are dummy positions
## relative to the player (x right, -z ahead).
func _setup(posts: Array[Vector3], presentation: bool = false) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	room = ROOM.instantiate()
	room.set(&"with_presentation", presentation)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


## A killing hit from the player on `victim` (a stagger, which a kill turns into a
## knockdown): it flies, lands and is KO'd.
func _kill(victim: CombatActor) -> HitInfo:
	victim.health = 1.0
	var hit := HitInfo.new()
	hit.attacker = player if victim != player else dummies[0]
	hit.victim = victim
	hit.damage = 10.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.STAGGER
	hit.region = CombatTypes.Region.HEAD
	hit.direction = (victim.global_position - hit.attacker.global_position).normalized()
	hit.knockback = hit.direction * 2.0
	hit.contact_point = victim.rig.get_point_position(&"Head") - hit.direction * 0.12
	hit.physics_frame = Engine.get_physics_frames()
	assert_true(victim.receive_hit(hit), "the hit lands")
	assert_true(hit.killed, "and kills")
	return hit


func _ticks_of(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


# --- Tests --------------------------------------------------------------------------


func test_a_kod_dummy_lies_blinks_faster_and_faster_and_is_gone() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	_kill(dummy)
	assert_true(await _wait_until(func() -> bool: return dummy.is_ko(), 150), "KO'd on landing")
	assert_eq(dummy.rig.get_ragdoll().phase, Ragdoll.Phase.LIMP, "limp")
	var tuning := Tuning.data
	var linger := _ticks_of(tuning.ko_linger_s)
	var blink := _ticks_of(tuning.ko_blink_s)
	# Shown frame by frame from the KO until a little past the blink-off.
	var shown: Array[bool] = []
	var gone_at := -1
	for i in linger + blink + 10:
		await get_tree().physics_frame
		shown.append(dummy.rig.visible)
		if gone_at < 0 and dummy.is_gone():
			gone_at = i
	assert_false(shown.slice(0, linger - 2).has(false), "lies there, shown, for ko_linger_s")
	assert_almost_eq(gone_at, linger + blink, 2, "gone ko_linger_s + ko_blink_s after the KO")
	# The blink: the off runs, in order; they shorten toward the end.
	var runs: Array[int] = []
	var run := 0
	for i in range(linger - 2, gone_at):
		if not shown[i]:
			run += 1
		elif run > 0:
			runs.append(run)
			run = 0
	gut.p("blink-off: off runs %s (frames), gone %d frames after the KO" % [str(runs), gone_at])
	assert_gte(runs.size(), 5, "blinks a few times")
	assert_gt(runs.front(), runs.back(), "faster toward the end")
	# Gone: hidden, no ragdoll, no hurtboxes, no collision, still KO'd.
	assert_false(dummy.rig.visible, "hidden")
	assert_false(dummy.rig.is_ragdolling(), "its ragdoll stopped")
	for hurtbox: Hurtbox in dummy.rig.get_hurtboxes():
		assert_false(hurtbox.monitorable, "no hurtbox %s" % hurtbox.name)
	assert_eq(dummy.collision_layer, 0, "on no collision layer")
	assert_eq(dummy.collision_mask, 0, "and colliding with nothing")
	assert_true(dummy.is_ko(), "still KO'd")
	var at := dummy.global_position
	await _ticks(30)
	assert_almost_eq(dummy.global_position, at, Vector3.ONE * 1e-4, "and it does not move (or fall)")
	assert_false(dummy.rig.visible, "stays hidden")


func test_nothing_finds_a_body_that_blinked_off() -> void:
	await _setup([Vector3(0, 0, -1.6), Vector3(1.5, 0, -1.6)])
	var dummy := dummies[0]
	_kill(dummy)
	assert_true(await _wait_until(func() -> bool: return dummy.is_gone(), 400), "gone")
	# Put it right in front of the player, where a body would be grabbed and aimed at.
	dummy.global_position = player.global_position + player.get_forward() * 0.9
	await _ticks(2)
	var jab := load(JAB_PATH) as MoveData
	assert_false(dummy.can_be_grabbed(), "not grabbable")
	assert_false(dummy.can_be_hit_by(player, jab), "not hittable")
	assert_null(player._find_grab_target(), "the grab finds nothing")
	assert_ne(player._find_magnet_target(jab), dummy, "magnetism passes it over")
	player.input.push_press(&"GRAB", 2)
	await _ticks(12)
	assert_null(dummy.holder, "and pressing grab holds nothing")
	# No body query sees it (the get-up's room checks and pile-ups, flying-body impacts).
	var shape := CapsuleShape3D.new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 0xFFFFFFFF
	query.transform = Transform3D(Basis.IDENTITY, dummy.global_position + Vector3.UP * 0.9)
	for result: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query, 32):
		assert_ne(result.get("collider"), dummy, "a shape query finds its body")


func test_a_dummy_comes_back_at_its_post_blinking_in() -> void:
	await _setup([Vector3(0.4, 0, -1.6)], true)
	var dummy := dummies[0]
	var home := dummy.global_position
	var home_yaw := dummy.rotation.y
	# Hurt enough to look bloodied.
	dummy.max_health = Tuning.data.dummy_health
	dummy.health = dummy.max_health * 0.2
	CombatEvents.health_changed.emit(dummy, dummy.health, dummy.max_health)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.BLOODIED, "bloodied")
	_kill(dummy)
	assert_true(await _wait_until(func() -> bool: return dummy.is_ko(), 150), "KO'd")
	var ko_ticks := 0
	while not dummy.is_gone() and ko_ticks < 400:
		await get_tree().physics_frame
		ko_ticks += 1
	assert_true(dummy.is_gone(), "gone")
	var gone_ticks := 0
	while dummy.is_ko() and gone_ticks < 400:
		await get_tree().physics_frame
		gone_ticks += 1
	assert_false(dummy.is_ko(), "comes back")
	assert_almost_eq(gone_ticks, _ticks_of(Tuning.data.dummy_revive_s), 2, "dummy_revive_s after it blinked off")
	assert_almost_eq(dummy.global_position, home, Vector3.ONE * 0.05, "at its post, not where it lay")
	assert_almost_eq(dummy.rotation.y, home_yaw, 0.01, "facing as it was posted")
	assert_eq(dummy.state, CombatTypes.ActorState.FREE, "standing")
	assert_eq(dummy.health, dummy.max_health, "at full health")
	assert_eq(dummy.max_health, Tuning.data.dummy_health)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.CLEAN, "its damage look clean")
	assert_false(dummy.is_gone())
	for hurtbox: Hurtbox in dummy.rig.get_hurtboxes():
		assert_true(hurtbox.monitorable, "hurtbox %s back" % hurtbox.name)
	# The blink-in: on and off, out of reach, then solid and shown.
	var jab := load(JAB_PATH) as MoveData
	var toggles := 0
	var was := dummy.rig.visible
	var blink_in := _ticks_of(Tuning.data.ko_blink_in_s)
	for i in blink_in - 1:
		assert_false(dummy.can_be_hit_by(player, jab), "out of reach while blinking in")
		assert_false(dummy.can_be_grabbed(), "not grabbable while blinking in")
		await get_tree().physics_frame
		toggles += 1 if dummy.rig.visible != was else 0
		was = dummy.rig.visible
	assert_gte(toggles, 3, "blinks in")
	await _ticks(3)
	assert_true(dummy.rig.visible, "then shown")
	assert_true(dummy.can_be_hit_by(player, jab), "and hittable")
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY), "and solid")
	var back_s := (ko_ticks + gone_ticks + blink_in) / float(Engine.physics_ticks_per_second)
	gut.p("KO to back at the post: %.2f s (lying and blinking %.2f s, gone %.2f s, blink-in %.2f s)" % [
		back_s, ko_ticks / 60.0, gone_ticks / 60.0, blink_in / 60.0])
	assert_almost_eq(back_s, 4.0, 0.3, "about 4 s from the KO to back with the defaults")


func test_a_vanished_dummys_health_bar_goes_with_it() -> void:
	await _setup([Vector3(0, 0, -1.6)], true)
	var hud: GameHud = room.find_children("*", "GameHud", false, false)[0]
	hud.enemy_bars.show_seconds = 30.0
	var dummy := dummies[0]
	var hit := _kill(dummy)
	CombatEvents.hit_landed.emit(hit)
	await _ticks(2)
	assert_true(hud.enemy_bars.has_bar(dummy), "the KO hit shows its bar")
	assert_true(await _wait_until(func() -> bool: return dummy.is_gone(), 400), "gone")
	await _ticks(1)
	assert_false(hud.enemy_bars.has_bar(dummy), "its bar goes with it")


func test_a_reset_during_the_blink_off_brings_the_body_back() -> void:
	# Bots, tests and the F4 menu's "reset dummies" stage dummies with set_post(..., true).
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	_kill(dummy)
	assert_true(await _wait_until(func() -> bool: return dummy.is_gone(), 400), "gone")
	dummy.set_post(home, dummy.rotation.y, true)
	await _ticks(3)
	assert_false(dummy.is_gone())
	assert_false(dummy.is_ko())
	assert_true(dummy.rig.visible, "shown")
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY), "solid")


func test_the_player_never_blinks_off() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	assert_false(Tuning.data.god_mode)
	_kill(player)
	assert_true(await _wait_until(func() -> bool: return player.is_ko(), 150), "KO'd")
	var hidden := 0
	for i in _ticks_of(Tuning.data.ko_linger_s + Tuning.data.ko_blink_s) + 30:
		await get_tree().physics_frame
		hidden += 0 if player.rig.visible else 1
		assert_false(player.is_gone(), "never gone")
	assert_eq(hidden, 0, "never hidden")
	assert_ne(player.collision_layer, 0, "keeps its body")


func test_the_blink_speeds_up() -> void:
	var tuning := Tuning.data
	assert_gt(tuning.ko_blink_end_hz, tuning.ko_blink_start_hz, "faster toward the end by default")
	var first := 0
	var last := 0
	var was := true
	var steps := 600
	for i in steps:
		var t := tuning.ko_blink_s * i / float(steps)
		var now := CombatActor.blink_shown(t, tuning.ko_blink_s, tuning.ko_blink_start_hz, tuning.ko_blink_end_hz)
		if now != was:
			if i < steps / 4:
				first += 1
			elif i >= steps * 3 / 4:
				last += 1
		was = now
	assert_false(CombatActor.blink_shown(0.0, 1.0, 4.0, 12.0), "a blink starts off")
	assert_gt(last, first, "more changes in the last quarter than the first (%d, %d)" % [last, first])


func test_a_dummy_comes_back_beside_its_post_when_someone_stands_on_it() -> void:
	# The player that knocked it out often stands on its post (the combo's step-ins).
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	_kill(dummy)
	assert_true(await _wait_until(func() -> bool: return dummy.is_gone(), 400), "gone")
	player.global_position = home + Vector3(0.2, 0.0, 0.0)
	assert_true(await _wait_until(func() -> bool: return not dummy.is_ko(), _ticks_of(Tuning.data.dummy_revive_s) + 10), "comes back on time")
	var gap := Vector2(dummy.global_position.x - player.global_position.x, dummy.global_position.z - player.global_position.z).length()
	gut.p("came back %.2f m from its post, %.2f m from the player on it" % [dummy.global_position.distance_to(home), gap])
	assert_gte(gap, dummy.body_radius + player.body_radius, "not inside the player")
	assert_lt(dummy.global_position.distance_to(home), dummy.body_radius * 4.0 + 0.01, "beside its post")
	assert_almost_eq(dummy.get(&"_home"), home, Vector3.ONE * 1e-4, "which stays its post")
