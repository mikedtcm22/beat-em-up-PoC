extends GutTest
## Milestone 2 phase 3: KO bodies blink off (Game-boy's departure from Spec §6; the
## CombatActor class docs). A KO'd dummy lies limp for Tuning.ko_linger_s, blinks for
## ko_blink_s (faster toward the end) and is gone: hidden, its ragdoll stopped, no
## hurtboxes, no collision, and nothing that looks for bodies finds it. A training dummy
## then comes back at its post after dummy_revive_s, blinking in, at full health with a clean
## damage look, or beside it when someone is there (standing, lying, held, or another dummy
## coming back on the same tick), never past a wall or off the floor; a ghost that nothing
## aims at until its blink-in is over. When the player stands on its post it comes back
## clear of him and in his view, and stays there (no walking in place against him) until
## the post is free. The player never blinks off.

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


## How far from its post a comeback may be: two rings of a body width plus the clearance
## (Tuning.dummy_respawn_gap_m), give or take a centimetre.
func _two_body_widths(dummy: CombatActor) -> float:
	return (dummy.body_radius * 2.0 + Tuning.data.dummy_respawn_gap_m) * 2.0 + 0.01


## The flat distance between two bodies' axes.
func _flat_gap(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## How much `spot` lies in front of the player (1 straight ahead, 0 beside him, negative behind).
func _ahead_of_player(spot: Vector3) -> float:
	var to_spot := spot - player.global_position
	to_spot.y = 0.0
	return to_spot.normalized().dot(player.get_forward())


## Put the player on `at`, facing `yaw_deg` (0 faces -Z, -90 faces +X).
func _stand_on(at: Vector3, yaw_deg: float) -> void:
	player.global_position = at
	player.look_yaw = deg_to_rad(yaw_deg)
	player.rotation.y = player.look_yaw
	player.sim_velocity = Vector3.ZERO


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


func test_a_kod_dummys_health_bar_fades_out_before_it_blinks() -> void:
	# The bar shows the killing hit's chunk drain away, then fades: an empty bar over a lying
	# body adds nothing, and it would hang, steady, over a body blinking off (review ragdoll-04).
	await _setup([Vector3(0, 0, -1.6)], true)
	var hud: GameHud = room.find_children("*", "GameHud", false, false)[0]
	hud.enemy_bars.show_seconds = 30.0
	var dummy := dummies[0]
	var hit := _kill(dummy)
	CombatEvents.hit_landed.emit(hit)
	await _ticks(2)
	assert_true(hud.enemy_bars.has_bar(dummy), "the KO hit shows its bar")
	var drawn_hidden := 0
	var bar_until := -1
	var first_off := -1
	for i in 400:
		await get_tree().physics_frame
		if hud.enemy_bars.has_bar(dummy):
			bar_until = i
			if not dummy.rig.visible and hud.enemy_bars.get_bar_screen_position(dummy) != Vector2(-1.0, -1.0):
				drawn_hidden += 1
		if first_off < 0 and dummy.is_ko() and not dummy.rig.visible:
			first_off = i
		if dummy.is_gone():
			break
	gut.p("bar until tick %d, the body's first blink-off at tick %d" % [bar_until, first_off])
	assert_gt(first_off, 0, "the body blinks")
	assert_lt(bar_until, first_off, "the bar is gone before the body blinks off")
	assert_eq(drawn_hidden, 0, "and never drawn over a hidden body")
	await _ticks(1)
	assert_false(hud.enemy_bars.has_bar(dummy), "no bar once it is gone")


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


func test_the_blink_duty_sets_how_long_the_body_is_shown() -> void:
	assert_eq(Tuning.data.ko_blink_duty, 0.5, "even on and off by default")
	var steps := 1200
	for duty: float in [0.25, 0.5, 0.75]:
		var shown := 0
		var shown_by_tuning := 0
		Tuning.data.ko_blink_duty = duty
		for i in steps:
			var t := 2.0 * i / float(steps)  # a steady 5 Hz blink: ten whole cycles
			shown += 1 if CombatActor.blink_shown(t, 2.0, 5.0, 5.0, duty) else 0
			shown_by_tuning += 1 if CombatActor.blink_shown(t, 2.0, 5.0, 5.0) else 0
		assert_almost_eq(shown / float(steps), duty, 0.01, "shown %.2f of a cycle when asked" % duty)
		assert_eq(shown_by_tuning, shown, "and the same by Tuning.ko_blink_duty")
	assert_false(CombatActor.blink_shown(0.0, 1.0, 5.0, 5.0, 0.75), "each cycle still starts off")


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
	assert_gte(_ahead_of_player(dummy.global_position), 0.0, "in front of the player or beside him, not behind")
	assert_lt(dummy.global_position.distance_to(home), _two_body_widths(dummy), "beside its post")
	assert_almost_eq(dummy.get(&"_home"), home, Vector3.ONE * 1e-4, "which stays its post")


# --- Who is on the post, and the blink-in (review code-02, code-04) -----------------------


## A knockdown from the player on `victim` with a short push along `push` (flat m/s): it
## falls about where it stands and lies there.
func _knock_down(victim: CombatActor, push: Vector3 = Vector3.ZERO) -> void:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = victim
	hit.damage = 1.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.KNOCKDOWN
	hit.region = CombatTypes.Region.TORSO
	hit.direction = push.normalized() if push.length_squared() > 1e-6 else (victim.global_position - player.global_position).normalized()
	hit.knockback = push
	hit.contact_point = victim.get_chest_position() - hit.direction * 0.15
	hit.physics_frame = Engine.get_physics_frames()
	assert_true(victim.receive_hit(hit), "the knockdown lands")


## The nearest bone `other` is drawn with to `d`'s upright axis, along the floor:
## {gap, bone}.
func _drawn_gap(d: CombatActor, other: CombatActor) -> Dictionary:
	var nearest := {"gap": INF, "bone": &""}
	for bone: StringName in [&"Head", &"Chest", &"Hips", &"LeftUpperLeg", &"RightUpperLeg",
			&"LeftLowerLeg", &"RightLowerLeg", &"LeftFoot", &"RightFoot", &"LeftUpperArm",
			&"RightUpperArm", &"LeftLowerArm", &"RightLowerArm", &"LeftHand", &"RightHand"]:
		var p := other.rig.get_visual_point_transform(bone).origin
		var gap := Vector2(p.x - d.global_position.x, p.z - d.global_position.z).length()
		if gap < nearest.gap:
			nearest = {"gap": gap, "bone": bone}
	return nearest


## KO `dummy` and wait until it has blinked off.
func _ko_until_gone(dummy: TrainingDummy) -> void:
	_kill(dummy)
	assert_true(await _wait_until(func() -> bool: return dummy.is_gone(), 400), "gone")


func _comes_back(dummy: TrainingDummy) -> bool:
	return await _wait_until(func() -> bool: return not dummy.is_ko(), _ticks_of(Tuning.data.dummy_revive_s) + 30)


func test_a_dummy_comes_back_beside_a_body_lying_on_its_post() -> void:
	await _setup([Vector3(0, 0, -1.6), Vector3(1.6, 0, -1.6)])
	var dummy := dummies[0]
	var other := dummies[1]
	var home := dummy.global_position
	Tuning.data.downed_frames = 900  # it keeps lying
	await _ko_until_gone(dummy)
	other.set_post(home, other.rotation.y, true)
	await _ticks(3)
	_knock_down(other, Vector3(0.0, 0.0, 0.3))
	assert_true(await _wait_until(func() -> bool: return other.is_downed(), 120), "the other lies on the post")
	assert_true(await _comes_back(dummy), "comes back on time")
	assert_true(other.is_downed(), "the other still lies there")
	var nearest := _drawn_gap(dummy, other)
	gut.p("came back %.2f m from its post; the nearest drawn bone of the body lying there (%s) is %.2f m from its axis" % [
		Vector2(dummy.global_position.x - home.x, dummy.global_position.z - home.z).length(), nearest.bone, nearest.gap])
	assert_gt(nearest.gap, dummy.body_radius, "not inside the body lying on its post")
	assert_lt(dummy.global_position.distance_to(home), _two_body_widths(dummy), "beside its post")


func test_a_dummy_comes_back_beside_a_body_held_over_its_post() -> void:
	await _setup([Vector3(0, 0, -1.6), Vector3(0, 0, -0.9)])
	var dummy := dummies[0]
	var other := dummies[1]
	var home := dummy.global_position
	await _ko_until_gone(dummy)
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(func() -> bool: return other.holder == player, 30), "the player holds the other")
	await _ticks(20)
	# Step in so the held body is over the post, a little short of it: the holder stands clear
	# of the post, the held body (a ghost) is on it.
	var away := other.global_position - player.global_position
	away.y = 0.0
	var reach := away.length()
	player.global_position += home - away.normalized() * (dummy.body_radius + player.body_radius + 0.03 - reach) - other.global_position
	await _ticks(2)
	assert_lt(Vector2(other.global_position.x - home.x, other.global_position.z - home.z).length(), 0.3, "held over the post")
	assert_gt(Vector2(player.global_position.x - home.x, player.global_position.z - home.z).length(),
			dummy.body_radius + player.body_radius, "the holder clear of it")
	assert_true(await _comes_back(dummy), "comes back on time")
	assert_eq(other.holder, player, "still held")
	for body: CombatActor in [other, player]:
		var gap := Vector2(dummy.global_position.x - body.global_position.x, dummy.global_position.z - body.global_position.z).length()
		assert_gte(gap, dummy.body_radius + body.body_radius - 0.01, "not inside %s (%.2f m)" % [body.name, gap])


func test_two_dummies_that_come_back_on_the_same_tick_take_different_spots() -> void:
	await _setup([Vector3(0, 0, -1.6), Vector3(1.6, 0, -1.6)])
	var home := dummies[0].global_position
	_kill(dummies[0])
	_kill(dummies[1])
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_gone() and dummies[1].is_gone(), 400), "both gone")
	# Both posted at the same spot and due back on the same tick.
	dummies[1].set(&"_home", home)
	dummies[1].set(&"_gone_frames", dummies[0].get(&"_gone_frames"))
	assert_true(await _comes_back(dummies[0]), "the first comes back")
	assert_false(dummies[1].is_ko(), "the second on the same tick")
	var apart := Vector2(dummies[0].global_position.x - dummies[1].global_position.x,
			dummies[0].global_position.z - dummies[1].global_position.z).length()
	gut.p("came back %.2f m apart" % apart)
	assert_gte(apart, dummies[0].body_radius + dummies[1].body_radius - 0.01, "not inside each other")


func test_a_comeback_spot_has_floor_and_no_wall_on_the_way() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	await _ko_until_gone(dummy)
	# A closet with thin walls just around the post, the player standing in it: every spot one
	# body width out is in a wall, and those two out are behind one.
	var post := Vector3(0.0, 0.0, 12.0)
	dummy.set(&"_home", post)
	player.global_position = post
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := StaticBody3D.new()
		wall.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 2.0, 0.1) if side.x == 0.0 else Vector3(0.1, 2.0, 1.2)
		shape.shape = box
		wall.add_child(shape)
		room.add_child(wall)
		wall.global_position = post + side * 0.45 + Vector3.UP
	await _ticks(2)
	assert_eq(dummy.call(&"_respawn_spot"), Vector3.INF, "no spot past a wall: it waits")
	# Past the end of the floor (the street's slab ends at x = 30), with the player on the post.
	post = Vector3(29.6, 0.0, 0.0)
	dummy.set(&"_home", post)
	player.global_position = post + Vector3(-0.1, 0.0, 0.0)
	await _ticks(2)
	var spot: Vector3 = dummy.call(&"_respawn_spot")
	gut.p("at the floor's edge it picks %s" % spot)
	assert_true(spot.is_finite(), "a spot")
	assert_lt(spot.x, 30.0 - dummy.body_radius * 0.5, "with floor under it")
	assert_almost_eq(spot.y, 0.0, 0.01, "on the floor")


func test_a_dummy_blinking_in_draws_no_magnetism_and_lets_a_thrown_pipe_through() -> void:
	Tuning.data.ko_blink_in_s = 1.5  # time for the throw
	await _setup([Vector3(0, 0, -2.2)])
	var dummy := dummies[0]
	var jab := load(JAB_PATH) as MoveData
	assert_eq(player._find_magnet_target(jab), dummy, "magnetism finds it standing")
	await _ko_until_gone(dummy)
	assert_true(await _comes_back(dummy), "comes back")
	await _ticks(2)
	assert_true(dummy.is_blinking_in(), "blinking in")
	assert_null(player._find_magnet_target(jab), "magnetism passes it over")
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY), "a ghost")
	# Throw the pipe at it from the player's chest.
	var pipe: Weapon = room.find_children("*", "Weapon", true, false)[0]
	var throw := load(PlayerCharacter.WEAPON_THROW_PATH) as MoveData
	var from := player.get_chest_position()
	var aim := (dummy.get_chest_position() - from).normalized()
	pipe.global_position = from + aim * 0.5
	pipe.throw_from(player, aim * Tuning.data.weapon_throw_speed, throw)
	var health := dummy.health
	var passed := false
	for i in 30:
		await get_tree().physics_frame
		if (pipe.global_position - dummy.global_position).dot(aim) > dummy.body_radius + 0.3:
			passed = true
			break
	assert_true(dummy.is_blinking_in(), "still blinking in")
	assert_true(passed, "the pipe flies on through it")
	assert_eq(dummy.health, health, "untouched")
	assert_eq(pipe.durability, Tuning.data.weapon_durability, "and the pipe is not worn")
	# Out of the blink-in: solid, and magnetism finds it again.
	assert_true(await _wait_until(func() -> bool: return not dummy.is_blinking_in(), 120))
	await _ticks(2)
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY), "then solid")
	assert_eq(player._find_magnet_target(jab), dummy, "and aimed at")


func test_a_dummy_blinking_in_stays_a_ghost_while_the_player_stands_in_it() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	await _ko_until_gone(dummy)
	assert_true(await _comes_back(dummy), "comes back")
	assert_almost_eq(dummy.global_position, home, Vector3.ONE * 0.05, "at its post")
	# The player walks into it during its blink-in (a ghost can be walked through).
	player.global_position = home + Vector3(0.1, 0.0, 0.0)
	assert_true(await _wait_until(func() -> bool: return not dummy.is_blinking_in(), 60))
	await _ticks(3)
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY), "still a ghost, not shoving the player out")
	assert_almost_eq(dummy.global_position, home, Vector3.ONE * 0.05, "and it stays put")
	player.global_position = home + Vector3(2.0, 0.0, 0.0)
	await _ticks(3)
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY), "solid once the player stepped out")


# --- A comeback beside the post the player stands on (review gap-05) -------------------


func test_a_dummy_comes_back_clear_of_the_player_on_its_post_and_in_his_view() -> void:
	# Ring 1 was exactly two radii out, so the capsules touched, and with the player on the
	# post every spot of it was as far from him: the first one tried won, often behind him.
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	await _ko_until_gone(dummy)
	_stand_on(home, 0.0)
	var from := player.global_position
	assert_true(await _comes_back(dummy), "comes back on time")
	var gap := _flat_gap(dummy, player)
	var ahead := _ahead_of_player(dummy.global_position)
	gut.p("came back %.2f m from the player on its post, %.2f of the way ahead of him" % [gap, ahead])
	assert_gte(gap, dummy.body_radius + player.body_radius + Tuning.data.dummy_respawn_gap_m - 0.01, "clear of him, the gap tunable between the bodies")
	assert_gt(ahead, 0.9, "in front of him (round to the nearest of eight spots)")
	assert_almost_eq(dummy.get(&"_home"), home, Vector3.ONE * 1e-4, "its post stays")
	# Solid, and it neither pushes into him nor walks in place against him.
	assert_true(await _wait_until(func() -> bool: return not dummy.is_blinking_in(), 60))
	await _ticks(3)
	assert_eq(dummy.collision_layer, CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY), "solid")
	var stood := dummy.global_position
	var walked := 0
	for i in 300:
		await get_tree().physics_frame
		walked += 1 if Vector2(dummy.sim_velocity.x, dummy.sim_velocity.z).length() > 0.01 else 0
	assert_eq(walked, 0, "never walks (against him) while he is on the post")
	assert_almost_eq(dummy.global_position, stood, Vector3.ONE * 1e-3, "stays where it came back")
	assert_almost_eq(player.global_position, from, Vector3.ONE * 1e-3, "and does not push him")
	assert_gte(_flat_gap(dummy, player), dummy.body_radius + player.body_radius, "still clear of him")


func test_a_dummy_comes_back_in_the_players_view_whichever_way_he_faces() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	var gap := dummy.body_radius * 2.0 + Tuning.data.dummy_respawn_gap_m
	await _ko_until_gone(dummy)
	for yaw: float in [0.0, 45.0, 90.0, 180.0, -90.0, -135.0]:
		_stand_on(home, yaw)
		await _ticks(2)
		var spot: Vector3 = dummy.call(&"_respawn_spot")
		assert_true(spot.is_finite(), "a spot at yaw %.0f" % yaw)
		gut.p("facing %.0f: %.2f m from the post, %.2f ahead, %.2f m from him" % [yaw, spot.distance_to(home), _ahead_of_player(spot), Vector2(spot.x - player.global_position.x, spot.z - player.global_position.z).length()])
		assert_gt(_ahead_of_player(spot), 0.9, "in front of him at yaw %.0f" % yaw)
		assert_almost_eq(spot.distance_to(home), gap, 0.01, "one body width and the clearance out")
	# Something in front of him: the spot next to it, beside him, not behind him.
	_stand_on(home, 0.0)
	var other := dummies[1] if dummies.size() > 1 else null
	if other:
		other.set_post(home + Vector3(0.0, 0.0, -gap), 0.0, true)
		await _ticks(3)
		var spot: Vector3 = dummy.call(&"_respawn_spot")
		assert_true(spot.is_finite(), "another spot")
		assert_gte(_ahead_of_player(spot), 0.0, "in front of him or beside him with the front one taken (%.2f)" % _ahead_of_player(spot))
		assert_gt(Vector2(spot.x - other.global_position.x, spot.z - other.global_position.z).length(), 2.0 * dummy.body_radius - 0.01, "clear of the other")


func test_a_dummy_walks_home_once_the_post_is_free() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	await _ko_until_gone(dummy)
	_stand_on(home, 0.0)
	assert_true(await _comes_back(dummy), "comes back beside the post")
	assert_gt(_flat_gap(dummy, player), 0.5, "beside it")
	await _ticks(_ticks_of(Tuning.data.ko_blink_in_s) + 90)
	assert_gt(Vector2(dummy.global_position.x - home.x, dummy.global_position.z - home.z).length(), Tuning.data.dummy_return_slack_m, "not yet home")
	# He steps off the post: it walks back onto it after its idle time.
	_stand_on(home + player.get_forward() * 4.0, 0.0)
	assert_true(await _wait_until(func() -> bool:
		return Vector2(dummy.global_position.x - home.x, dummy.global_position.z - home.z).length() <= Tuning.data.dummy_return_slack_m,
		_ticks_of(Tuning.data.dummy_return_idle_s) + 120), "walks home")
	gut.p("home, %.2f m from its post" % Vector2(dummy.global_position.x - home.x, dummy.global_position.z - home.z).length())


func test_a_dummy_gives_up_a_walk_home_that_goes_nowhere() -> void:
	# Something in the way (the post itself is free): it strides for the stuck window, no
	# longer, and tries again after the idle time.
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var home := dummy.global_position
	var away := player.get_forward()
	var wall := StaticBody3D.new()
	wall.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 10.0) if absf(away.x) > 0.5 else Vector3(10.0, 2.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	room.add_child(wall)
	wall.global_position = home + away * 1.5 + Vector3.UP
	dummy.global_position = home + away * 3.0
	_stand_on(home - away * 6.0, 0.0)
	await _ticks(2)
	var idle := _ticks_of(Tuning.data.dummy_return_idle_s)
	var stuck := _ticks_of(Tuning.data.dummy_return_stuck_s)
	var longest_walk := 0
	var longest_stand := 0
	var walk := 0
	var stand := 0
	var walks := 0
	for i in 600:
		await get_tree().physics_frame
		if Vector2(dummy.sim_velocity.x, dummy.sim_velocity.z).length() > 0.01:
			if walk == 0:
				walks += 1
			walk += 1
			stand = 0
		else:
			walk = 0
			stand += 1
		longest_walk = maxi(longest_walk, walk)
		longest_stand = maxi(longest_stand, stand)
	gut.p("walks %d, the longest %d frames (stuck window %d), the longest stand %d (idle %d)" % [walks, longest_walk, stuck, longest_stand, idle])
	assert_gt(walks, 1, "tries again")
	# It walks up to the wall first (progress), then strides on for the stuck window.
	var to_wall := (away * 1.5).length() - dummy.body_radius - 0.1
	var approach := roundi(to_wall / Tuning.data.dummy_walk_speed * Engine.physics_ticks_per_second)
	assert_lte(longest_walk, approach + stuck + 4, "gives up the stuck window after the wall, not striding on")
	assert_gte(longest_stand, idle - 2, "and stands for the idle time")
	assert_lt(Vector2(dummy.global_position.x - home.x, dummy.global_position.z - home.z).length(), 3.0, "(and never got through)")
