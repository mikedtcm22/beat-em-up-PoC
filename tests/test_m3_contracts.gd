extends GutTest
## The Milestone 3 contract scaffold (M3-plan Part C §2, as amended by Part A): every hook,
## signal, field, tunable and skeleton that S0 landed, tested on its own before any package
## builds on it. The enemy AI itself is not here; this file pins what the others rely on.

const ROOM_PATH := "res://game/level/test_room.tscn"
const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")

const ABSORB_HIT_DAMAGE := 6.0


## A fighter whose armor absorbs every hit it is asked about (a test subclass of the hooks).
class ArmoredActor:
	extends CombatActor
	var absorbs: bool = true
	var absorbed: Array[HitInfo] = []
	var holds_victim: CombatActor
	var broke_by: Array[CombatActor] = []
	var parry_staggers: bool = true
	var held_clip: StringName = &"held"
	var grabbed_by: CombatActor
	var starts_move: MoveData
	var _started: bool = false

	func _apply_armor(hit: HitInfo) -> void:
		if absorbs:
			hit.armor_absorbed = true
			hit.reaction = CombatTypes.Reaction.NONE
			hit.knockback = Vector3.ZERO

	func _on_armor_absorbed(hit: HitInfo) -> void:
		absorbed.append(hit)

	func _on_hold_broken(victim: CombatActor) -> void:
		broke_by.append(victim)

	func is_holding(victim: CombatActor) -> bool:
		return victim == holds_victim

	func _parry_staggers() -> bool:
		return parry_staggers

	func _held_anim() -> StringName:
		return held_clip

	func _on_grabbed(by: CombatActor) -> void:
		grabbed_by = by

	func _tick_control() -> void:
		if starts_move and not _started and state == CombatTypes.ActorState.FREE:
			_started = true
			start_move(starts_move, 1, &"root", true)


var _scene: Node3D
var _windups_ended: Array[bool] = []
var _landed: Array[HitInfo] = []
var _released_events: Array = []


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	_windups_ended.clear()
	_landed.clear()
	_released_events.clear()
	PlaceholderAnims.warn_on_fallback = false
	CombatEvents.windup_ended.connect(_on_windup_ended)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_floor()


func after_each() -> void:
	if CombatEvents.windup_ended.is_connected(_on_windup_ended):
		CombatEvents.windup_ended.disconnect(_on_windup_ended)
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)
	if CombatEvents.released.is_connected(_on_released_typed):
		CombatEvents.released.disconnect(_on_released_typed)
	if CombatEvents.grab_escaped.is_connected(_on_escaped_typed):
		CombatEvents.grab_escaped.disconnect(_on_escaped_typed)
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	TimeController.clear()


func _on_windup_ended(_attacker: Node3D, interrupted: bool) -> void:
	_windups_ended.append(interrupted)


func _on_hit_landed(hit: HitInfo) -> void:
	_landed.append(hit)


# --- Harness ----------------------------------------------------------------------------


## A wide floor whose top is y = 0 on the world layer.
func _floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	_scene.add_child(body)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _armored(at: Vector3 = Vector3.ZERO, team: int = 1) -> ArmoredActor:
	var actor := ArmoredActor.new()
	actor.team = team
	actor.position = at
	_scene.add_child(actor)
	return actor


func _plain_actor(at: Vector3 = Vector3.ZERO) -> CombatActor:
	var actor := CombatActor.new()
	actor.position = at
	_scene.add_child(actor)
	return actor


func _player(at: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> PlayerCharacter:
	var player := PlayerCharacter.new()
	player.position = at
	player.rotation.y = yaw
	_scene.add_child(player)
	player.input.scripted = true
	return player


## A move whose startup is `startup` frames, with a big fist sphere (hits what stands in front).
func _punch(startup: int = 20, active: int = 3, recovery: int = 12) -> MoveData:
	var move := MoveData.new()
	move.id = &"test_punch"
	move.startup = startup
	move.active = active
	move.recovery = recovery
	move.damage = ABSORB_HIT_DAMAGE
	move.tier = CombatTypes.HitTier.LIGHT
	move.reaction = CombatTypes.Reaction.FLINCH
	move.magnetism = false
	var spec := HitboxSpec.new()
	spec.point = &"RightFistPoint"
	spec.radius = 1.2
	move.hitboxes = [spec]
	return move


func _hit(attacker: CombatActor, victim: CombatActor, damage: float = ABSORB_HIT_DAMAGE,
		reaction: CombatTypes.Reaction = CombatTypes.Reaction.FLINCH) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.damage = damage
	hit.reaction = reaction
	hit.knockback = Vector3(0.0, 0.0, 1.5)
	hit.direction = Vector3.FORWARD
	hit.contact_point = victim.global_position + Vector3.UP
	return hit


# --- The look API (2.1) -------------------------------------------------------------------


func test_the_look_api_measures_from_the_look_not_the_body_or_a_camera() -> void:
	var player := _player(Vector3(3.0, 0.0, 2.0))
	await _ticks(2)
	var origin := player.global_position
	assert_almost_eq(player.get_look_forward(), Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.0001, "yaw 0 faces -Z")
	assert_almost_eq(player.look_bearing_deg(origin + Vector3(-2.0, 0.0, 2.0)), 135.0, 0.001, "behind-left is +135")
	assert_almost_eq(player.look_bearing_deg(origin + Vector3(2.0, 0.0, 2.0)), -135.0, 0.001, "behind-right is -135")
	assert_almost_eq(absf(player.look_bearing_deg(origin + Vector3(0.0, 0.0, 2.0))), 180.0, 0.001, "directly behind is +-180")
	assert_almost_eq(player.look_bearing_deg(origin + Vector3(0.0, 0.0, -2.0)), 0.0, 0.001, "ahead is 0")
	# Turned with the look: yaw +90 degrees faces -X, so a point at -X is ahead.
	player.look_yaw = PI * 0.5
	assert_almost_eq(player.get_look_forward(), Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.0001, "the look turned left")
	assert_almost_eq(player.look_bearing_deg(origin + Vector3(-2.0, 0.0, 0.0)), 0.0, 0.001, "ahead after the turn")
	# The body's own yaw is not the look: it follows look_yaw only.
	player.rotation.y = PI
	assert_almost_eq(player.look_bearing_deg(origin + Vector3(-2.0, 0.0, 0.0)), 0.0, 0.001, "the body's yaw does not count")


func test_is_outside_view_at_the_warning_angle() -> void:
	var player := _player()
	await _ticks(2)
	var at_54 := Vector3(-sin(deg_to_rad(54.0)), 0.0, -cos(deg_to_rad(54.0))) * 3.0
	var at_56 := Vector3(-sin(deg_to_rad(56.0)), 0.0, -cos(deg_to_rad(56.0))) * 3.0
	var angle := Tuning.data.rear_warning_angle_deg
	assert_false(player.is_outside_view(player.global_position + at_54, angle), "54 degrees is in view")
	assert_true(player.is_outside_view(player.global_position + at_56, angle), "56 degrees is outside it")
	assert_true(player.is_outside_view(player.global_position + Vector3(0.0, 0.0, 3.0), angle), "behind")


func test_the_player_is_the_holder_of_its_held_victim() -> void:
	var player := _player()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	var other := _armored(Vector3(3.0, 0.0, -1.0))
	await _ticks(2)
	assert_false(player.is_holding(victim), "nothing held yet")
	victim.start_grabbed(player)
	player._held = victim
	assert_true(player.is_holding(victim), "the held victim")
	assert_false(player.is_holding(other), "another body is not held")
	var bare := CombatActor.new()
	assert_false(bare.is_holding(victim), "the base holder holds nobody")
	bare.free()


# --- CombatActor hooks (2.2, as amended) -------------------------------------------------------


func test_armor_that_absorbs_a_hit_keeps_the_windup_running() -> void:
	var actor := _armored()
	actor.starts_move = _punch(20)
	await _ticks(4)
	assert_eq(actor.state, CombatTypes.ActorState.WINDUP, "winding up")
	var hit := _hit(null, actor)
	assert_true(actor.receive_hit(hit), "the hit is accepted")
	assert_true(hit.armor_absorbed)
	assert_eq(actor.health, actor.max_health - ABSORB_HIT_DAMAGE, "the damage landed")
	assert_eq(actor.state, CombatTypes.ActorState.WINDUP, "still winding up")
	assert_not_null(actor.current_move, "the move runs on")
	assert_eq(_windups_ended, [] as Array[bool], "no windup_ended: the telegraph was not interrupted")
	assert_eq(actor.absorbed.size(), 1, "_on_armor_absorbed() was called")
	await _ticks(20)
	assert_eq(_windups_ended, [false] as Array[bool], "the wind-up ended by the strike coming out, not interrupted")


func test_without_armor_a_hit_cancels_the_windup() -> void:
	var actor := _armored()
	actor.absorbs = false
	actor.starts_move = _punch(20)
	await _ticks(4)
	assert_eq(actor.state, CombatTypes.ActorState.WINDUP)
	assert_true(actor.receive_hit(_hit(null, actor)))
	assert_ne(actor.state, CombatTypes.ActorState.WINDUP, "the flinch took it out of the wind-up")
	assert_eq(_windups_ended, [true] as Array[bool], "windup_ended(interrupted)")


func test_armor_never_saves_a_killing_hit() -> void:
	Tuning.data.ragdoll_enabled = false
	var actor := _armored()
	actor.starts_move = _punch(20)
	await _ticks(4)
	var hit := _hit(null, actor, actor.max_health + 5.0)
	assert_true(actor.receive_hit(hit))
	assert_true(hit.killed)
	assert_true(actor.absorbed.is_empty(), "armor's skip does not apply to a killing hit")
	assert_true(actor.is_flying(), "the killing blow flies (the ordinary KO path)")
	assert_eq(_windups_ended, [true] as Array[bool], "and the wind-up was cut")


func test_an_armored_hit_puts_only_the_attacker_in_hitstop() -> void:
	# Armored hits don't stretch wind-ups (M3-plan A2.6): the strike still feels solid to the
	# attacker, but the armored victim never freezes. A plain victim freezes with it.
	for armored: bool in [true, false]:
		TimeController.clear()
		_landed.clear()
		var attacker := _armored(Vector3(0.0, 0.0, 0.0), 0)
		attacker.absorbs = false
		var victim := _armored(Vector3(0.0, 0.0, -0.9))
		victim.absorbs = armored
		victim.rotation.y = PI
		await _ticks(3)
		attacker.starts_move = _punch(2, 3, 6)
		var tries := 0
		while _landed.is_empty() and tries < 30:
			tries += 1
			await _ticks(1)
		assert_false(_landed.is_empty(), "the punch landed (armored %s)" % armored)
		await _ticks(1)
		assert_eq(victim.health, victim.max_health - ABSORB_HIT_DAMAGE, "damage landed (armored %s)" % armored)
		assert_true(TimeController.is_in_hitstop(attacker), "the attacker froze (armored %s)" % armored)
		assert_eq(TimeController.is_in_hitstop(victim), not armored,
				"the victim froze only if it took the hit cleanly (armored %s)" % armored)
		attacker.queue_free()
		victim.queue_free()
		await _ticks(2)


func test_an_absorbed_finisher_starts_no_slow_mo() -> void:
	# A finisher that armor absorbs (a poised boss) shows only a grey spark: its slow-mo would
	# slow down nothing. A plain victim's finisher slows the world as ever.
	for armored: bool in [true, false]:
		TimeController.clear()
		_landed.clear()
		var attacker := _armored(Vector3(0.0, 0.0, 0.0), 0)
		attacker.absorbs = false
		var victim := _armored(Vector3(0.0, 0.0, -0.9))
		victim.absorbs = armored
		victim.rotation.y = PI
		await _ticks(3)
		var finisher := _punch(2, 3, 6)
		finisher.tier = CombatTypes.HitTier.FINISHER
		attacker.starts_move = finisher
		var tries := 0
		while _landed.is_empty() and tries < 30:
			tries += 1
			await _ticks(1)
		assert_false(_landed.is_empty(), "the finisher landed (armored %s)" % armored)
		var slowed := TimeController.is_slowmo() or TimeController._slowmo_delay > 0.0
		assert_eq(slowed, not armored, "slow-mo only for a finisher the victim felt (armored %s)" % armored)
		attacker.queue_free()
		victim.queue_free()
		await _ticks(2)
	TimeController.clear()


func test_break_free_releases_the_victim_and_tells_the_holder() -> void:
	var holder := _armored(Vector3(0.0, 0.0, 0.0))
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	await _ticks(3)
	watch_signals(CombatEvents)
	victim.start_grabbed(holder)
	await _ticks(2)
	assert_eq(victim.state, CombatTypes.ActorState.GRABBED)
	victim.break_free(7)
	assert_eq(victim.state, CombatTypes.ActorState.FREE, "released on its feet")
	assert_null(victim.holder, "no holder")
	assert_eq(holder.broke_by, [victim] as Array[CombatActor], "the holder's _on_hold_broken() was called")
	assert_true(victim.is_invulnerable(), "invulnerable after breaking free")
	assert_eq(victim._invuln_frames, 7, "for the frames asked")
	assert_signal_emitted_with_parameters(CombatEvents, "grab_escaped", [victim, holder])
	assert_signal_emitted(CombatEvents, "released")
	# Not grabbed any more: nothing happens.
	holder.broke_by.clear()
	victim.break_free(7)
	assert_signal_emit_count(CombatEvents, "grab_escaped", 1)
	assert_true(holder.broke_by.is_empty())


func test_break_free_without_frames_reads_the_tunable() -> void:
	var holder := _armored()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	await _ticks(3)
	victim.start_grabbed(holder)
	victim.break_free()
	assert_eq(victim._invuln_frames, Tuning.data.grab_break_invuln_frames)


func test_the_pin_order_is_set_and_restored() -> void:
	var holder := _armored()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	holder.process_physics_priority = 5
	victim.process_physics_priority = 2
	await _ticks(3)
	# Release.
	victim.start_grabbed(holder)
	assert_eq(victim.process_physics_priority, 6, "pinned after its holder's rig advanced")
	victim.release_from_grab(Vector3.ZERO, false)
	assert_eq(victim.process_physics_priority, 2, "restored on release")
	# A launch out of the hold.
	Tuning.data.ragdoll_enabled = false
	victim.start_grabbed(holder)
	assert_eq(victim.process_physics_priority, 6)
	victim.absorbs = false
	var hit := _hit(holder, victim, 1.0, CombatTypes.Reaction.THROWN)
	hit.knockback = Vector3(0.0, 4.0, 3.0)
	victim.receive_hit(hit)
	assert_eq(victim.state, CombatTypes.ActorState.THROWN)
	assert_eq(victim.process_physics_priority, 2, "restored on launch")
	# A KO out of the hold, and a reset.
	var second := _armored(Vector3(2.0, 0.0, -1.0))
	second.process_physics_priority = 3
	await _ticks(3)
	second.start_grabbed(holder)
	assert_eq(second.process_physics_priority, 6)
	second.reset_state()
	assert_eq(second.process_physics_priority, 3, "restored by reset_state()")
	second.start_grabbed(holder)
	second.holder = null
	second._enter_ko()
	assert_eq(second.process_physics_priority, 3, "restored on KO")


func test_a_held_body_is_released_when_its_holder_is_gone() -> void:
	var holder := _armored()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	await _ticks(3)
	victim.start_grabbed(holder)
	await _ticks(2)
	assert_eq(victim.state, CombatTypes.ActorState.GRABBED)
	holder._gone = true
	await _ticks(2)
	assert_eq(victim.state, CombatTypes.ActorState.FREE, "the pin let go of a holder that blinked off")
	assert_null(victim.holder)


## What a presentation listener would write: typed, so a freed holder cannot be passed to it.
func _on_released_typed(holder: Node3D, victim: Node3D) -> void:
	_released_events.append([holder, victim])


func test_a_holder_freed_mid_hold_releases_the_victim_and_the_event_names_no_one() -> void:
	# F4's "Remove every enemy", a room switch or a bot's clear_enemies() frees a holder under a
	# hold; the victim's safety net lets go and CombatEvents.released fires with the holder gone.
	# A typed listener cannot be given a freed object (it would print an ERROR and never run), so
	# the event carries null.
	CombatEvents.released.connect(_on_released_typed)
	var holder := _armored()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	await _ticks(3)
	victim.start_grabbed(holder)
	await _ticks(2)
	assert_eq(victim.state, CombatTypes.ActorState.GRABBED)
	holder.free()
	await _ticks(2)
	assert_eq(victim.state, CombatTypes.ActorState.FREE, "the pin let go of a holder that is gone")
	assert_eq(_released_events.size(), 1, "released fired once, and the typed listener was reached")
	if _released_events.size() == 1:
		assert_null(_released_events[0][0], "with no holder")
		assert_eq(_released_events[0][1], victim, "naming the victim")
	# The player's side: _control_grabbed() sees a holder that holds nobody and lets go.
	_released_events.clear()
	var player := _player(Vector3(6.0, 0.0, 0.0))
	var second := _armored(Vector3(6.0, 0.0, 2.0))
	second.holds_victim = player
	await _ticks(3)
	player.start_grabbed(second)
	await _ticks(2)
	assert_eq(player.state, CombatTypes.ActorState.GRABBED)
	second.free()
	await _ticks(3)
	assert_ne(player.state, CombatTypes.ActorState.GRABBED, "the player is let go too")
	assert_eq(_released_events.size(), 1, "released fired for the player")
	if _released_events.size() == 1:
		assert_null(_released_events[0][0])
		assert_eq(_released_events[0][1], player)
	# A live holder is still named.
	_released_events.clear()
	var keeper := _armored(Vector3(-6.0, 0.0, 0.0))
	var held := _armored(Vector3(-6.0, 0.0, -1.0))
	await _ticks(3)
	held.start_grabbed(keeper)
	held.release_from_grab(Vector3.ZERO, false)
	assert_eq(_released_events.size(), 1)
	if _released_events.size() == 1:
		assert_eq(_released_events[0][0], keeper, "a holder that is still there is the event's")


func _on_escaped_typed(victim: Node3D, holder: Node3D) -> void:
	_released_events.append([holder, victim])


func test_breaking_free_when_the_holder_is_already_gone_names_no_one() -> void:
	CombatEvents.grab_escaped.connect(_on_escaped_typed)
	var holder := _armored()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	await _ticks(3)
	victim.start_grabbed(holder)
	holder.free()
	victim.break_free(5)  # the same frame: the pin has not noticed yet
	CombatEvents.grab_escaped.disconnect(_on_escaped_typed)
	assert_eq(victim.state, CombatTypes.ActorState.FREE, "let go")
	assert_eq(_released_events.size(), 1, "grab_escaped fired and reached a typed listener")
	if _released_events.size() == 1:
		assert_null(_released_events[0][0], "with no holder")
		assert_eq(_released_events[0][1], victim)


func test_the_held_animation_is_the_hooks() -> void:
	var holder := _armored()
	var victim := _armored(Vector3(0.0, 0.0, -1.0))
	victim.held_clip = &"flinch_gut"
	await _ticks(3)
	victim.start_grabbed(holder)
	assert_eq(victim.rig.current_anim(), &"flinch_gut", "start_grabbed() plays _held_anim()")
	assert_eq(victim.grabbed_by, holder, "_on_grabbed() was called")
	# The default is the bent-over `held`, which the player's grabs keep.
	var plain := _plain_actor(Vector3(2.0, 0.0, -1.0))
	await _ticks(3)
	assert_eq(plain._held_anim(), &"held")


func test_abort_move_cuts_a_windup_and_returns_to_neutral() -> void:
	var actor := _armored()
	actor.starts_move = _punch(20)
	await _ticks(6)
	assert_eq(actor.state, CombatTypes.ActorState.WINDUP)
	actor.abort_move()
	assert_null(actor.current_move)
	assert_eq(actor.state, CombatTypes.ActorState.FREE, "back to neutral")
	assert_eq(_windups_ended, [true] as Array[bool], "the wind-up ended interrupted")


func test_a_parry_staggers_the_attacker_unless_it_opts_out() -> void:
	Tuning.data.ragdoll_enabled = false
	for staggers: bool in [true, false]:
		var attacker := _armored(Vector3(0.0, 0.0, 0.0))
		attacker.parry_staggers = staggers
		await _ticks(3)
		var move := _punch()
		var hit := HitInfo.new()
		hit.move = move
		hit.perfect_block = true
		hit.blocked = true
		hit.direction = Vector3.FORWARD
		hit.contact_point = Vector3.UP
		attacker.react_to_block(hit)
		if staggers:
			assert_eq(attacker.state, CombatTypes.ActorState.STAGGER, "a parried attacker staggers")
		else:
			assert_eq(attacker.state, CombatTypes.ActorState.HITSTUN, "the ordinary recoil instead")
		attacker.queue_free()
		await _ticks(2)


# --- Data and events ---------------------------------------------------------------------


func test_new_events_and_hit_info() -> void:
	assert_true(CombatEvents.has_signal(&"grab_escaped"))
	assert_true(CombatEvents.has_signal(&"boss_phase_changed"))
	var hit := HitInfo.new()
	assert_false(hit.describe().ends_with("ARMOR"))
	hit.armor_absorbed = true
	assert_true(hit.describe().ends_with(" ARMOR"), "the combat log shows an absorbed hit")


func test_move_data_has_a_reach_in_the_movement_group() -> void:
	var move := MoveData.new()
	assert_eq(move.reach_m, 0.0, "0 = not an AI attack")
	var names: Array[StringName] = []
	for info: Dictionary in Tuning.move_properties():
		if info.group == "Movement":
			names.append(info.name)
	assert_has(names, &"reach_m", "F1 edits it per move and presets save it")
	for info: Dictionary in Tuning.move_properties():
		if info.name in [&"reach_m", &"lunge", &"free_lunge"]:
			var parts := String(info.hint_string).split(",")
			assert_eq(float(parts[0]), 0.0, "%s range starts at 0" % info.name)
			assert_eq(float(parts[1]), 10.0 if info.name == &"reach_m" else 8.0, "%s range" % info.name)


# --- Tunables (2.11, A2.11) --------------------------------------------------------------


## Every M3 tunable: name -> [default, subgroup ("" = the group's head)], by group. Hand-written
## from the plan, never read back from TuningData.
const TUNABLES := {
	"Enemies": {
		&"attacker_cap": [3, ""], &"blind_spot_priority": [1.0, ""], &"windup_mult": [1.0, ""],
		&"windup_min_frames_grunt": [18, "Wind-up"], &"windup_min_frames_heavy": [30, "Wind-up"],
		&"windup_track_deg_per_s": [180.0, "Wind-up"], &"windup_track_share": [0.5, "Wind-up"],
		&"posture_ring_min_m": [2.5, "Posture"], &"posture_ring_max_m": [4.0, "Posture"],
		&"posture_circle_speed_mps": [1.1, "Posture"], &"posture_strafe_switch_s": [1.6, "Posture"],
		&"posture_strafe_jitter_s": [0.6, "Posture"], &"posture_pause_s": [0.5, "Posture"],
		&"posture_taunt_chance": [0.12, "Posture"], &"approach_speed_mps": [2.6, "Posture"],
		&"engage_speed_mps": [3.0, "Posture"], &"commit_pause_frames": [12, "Posture"],
		&"engage_margin_m": [0.05, "Posture"], &"engage_timeout_s": [2.0, "Posture"],
		&"recover_hold_s": [0.35, "Posture"], &"enemy_turn_rate": [6.0, "Posture"],
		&"enemy_avoid_radius_m": [0.45, "Navigation"], &"enemy_avoid_horizon_s": [0.75, "Navigation"],
		&"enemy_avoid_neighbor_m": [6.0, "Navigation"], &"enemy_waypoint_reach_m": [0.5, "Navigation"],
		&"enemy_slot_reach_m": [0.3, "Navigation"], &"enemy_retarget_ticks": [6, "Navigation"],
		&"enemy_max_speed_mps": [6.0, "Navigation"], &"enemy_stuck_s": [1.0, "Navigation"],
		&"director_min_windup_gap_s": [0.35, "Director"], &"director_reslot_s": [1.5, "Director"],
		&"director_reslot_move_m": [1.0, "Director"], &"director_spread_jitter_deg": [12.0, "Director"],
		&"director_slot_snap_tolerance_m": [0.5, "Director"], &"director_slot_retry_deg": [15.0, "Director"],
		&"director_revive_grace_s": [1.5, "Director"], &"director_token_timeout_s": [4.0, "Director"],
		&"waves_enabled": [true, "Waves"], &"wave_max_alive": [6, "Waves"], &"wave_gap_s": [3.0, "Waves"],
		&"wave_spawn_interval_s": [0.6, "Waves"], &"wave_behind_share": [0.35, "Waves"],
		&"boss_wave_every": [4, "Waves"], &"spawn_min_player_distance_m": [4.0, "Waves"],
		&"player_avoid_radius_m": [0.5, "Waves"],
		&"punk_health": [30.0, "Street Punk"], &"punk_shove_chance": [0.3, "Street Punk"],
		&"punk_attack_cooldown_s": [5.0, "Street Punk"], &"punk_speed_mult": [1.0, "Street Punk"],
		&"kicker_health": [25.0, "Kicker"], &"kicker_circle_mult": [1.6, "Kicker"],
		&"kicker_speed_mult": [1.3, "Kicker"], &"kicker_sweep_chance": [0.4, "Kicker"],
		&"kicker_attack_cooldown_s": [1.2, "Kicker"],
		&"thug_health": [35.0, "Pipe Thug"], &"thug_attack_cooldown_s": [8.0, "Pipe Thug"],
		&"thug_speed_mult": [0.95, "Pipe Thug"], &"thug_drop_speed_mps": [0.5, "Pipe Thug"],
		&"grab_break_presses": [8, "Enemy grabs"], &"grab_break_invuln_frames": [20, "Enemy grabs"],
		&"grab_break_decay_per_s": [0.0, "Enemy grabs"], &"grab_break_push_mps": [3.0, "Enemy grabs"],
		&"grabbed_turn_frames": [8, "Enemy grabs"], &"grabbed_pin_distance_m": [0.75, "Enemy grabs"],
		&"grabbed_view_pitch_deg": [5.0, "Enemy grabs"], &"enemy_grab_range_m": [1.3, "Enemy grabs"],
		&"enemy_grab_half_angle_deg": [50.0, "Enemy grabs"],
		&"bruiser_health": [80.0, "Bruiser"], &"bruiser_armor_break_s": [2.0, "Bruiser"],
		&"bruiser_grab_chance": [0.4, "Bruiser"], &"bruiser_attack_cooldown_s": [2.2, "Bruiser"],
		&"bruiser_speed_mult": [0.8, "Bruiser"],
		&"boss_health": [300.0, "Boss"], &"boss_phase2_at": [0.5, "Boss"], &"boss_turn_rate": [2.5, "Boss"],
		&"boss_phase2_turn_mult": [1.8, "Boss"], &"boss_adds_count": [2, "Boss"], &"boss_add_ring_m": [5.0, "Boss"],
		&"boss_charge_min_m": [2.5, "Boss"], &"boss_charge_chance": [0.4, "Boss"],
		&"boss_pound_chance": [0.3, "Boss"], &"boss_grab_chance": [0.3, "Boss"],
		&"boss_attack_cooldown_s": [1.5, "Boss"], &"boss_speed_mult": [0.85, "Boss"],
		&"boss_crowd_m": [3.0, "Boss"], &"boss_crowd_count": [2, "Boss"], &"boss_parry_recoil_frames": [36, "Boss"],
		&"boss_poise_s": [4.0, "Boss"], &"boss_poise_attacks": [1, "Boss"], &"boss_poise_after_reactions": [2, "Boss"],
		&"boss_poise_window_s": [8.0, "Boss"], &"boss_read_m": [1.5, "Boss"], &"boss_back_off_s": [0.8, "Boss"],
	},
	"Rear warning": {
		&"rear_warning_angle_deg": [55.0, ""], &"rear_warning_size": [1.0, ""], &"rear_warning_opacity": [0.9, ""],
		&"rear_warning_audio": [true, ""], &"rear_warning_behind_deg": [20.0, ""],
		&"rear_warning_range_margin_m": [1.0, ""], &"rear_warning_base_px": [170.0, ""],
		&"rear_warning_inset_px": [48.0, ""], &"rear_warning_heavy_scale": [1.4, ""],
		&"rear_warning_pulses": [2, ""], &"rear_warning_pulse_s": [0.12, ""],
		&"rear_warning_min_alpha": [0.65, ""], &"rear_warning_brightness_step": [0.2, ""],
		&"rear_warning_follow_turn": [false, ""], &"rear_warning_hide_in_ko": [true, ""],
	},
	"Debug": {&"god_mode": [false, ""], &"one_hit_ko": [false, ""], &"ai_frozen": [false, ""]},
}

## The subgroups of "Enemies", in order (the F1 headings).
const ENEMY_SUBGROUPS: PackedStringArray = [
	"Wind-up", "Posture", "Navigation", "Director", "Waves", "Street Punk", "Kicker", "Pipe Thug",
	"Enemy grabs", "Bruiser", "Boss",
]


func test_every_m3_tunable_is_declared_in_its_owners_subgroup() -> void:
	var found: Dictionary = {}
	for info: Dictionary in Tuning.tuning_properties():
		var group: String = info.group
		if not TUNABLES.has(group):
			continue
		var wanted: Dictionary = TUNABLES[group]
		if not found.has(group):
			found[group] = {}
		found[group][info.name] = info.subgroup
		if not wanted.has(info.name):
			continue
		var row: Array = wanted[info.name]
		assert_eq(info.subgroup, row[1], "%s: its subgroup" % info.name)
		# Defaults are not pinned here (row[0] is the plan's starting value): each owner retunes
		# its own from captures, and a pinned copy would make this shared file a merge hot spot.
	# Every planned one is there. A package may add more inside its own subgroup (A2.11), so
	# extra ones are not an error here.
	for group: String in TUNABLES:
		for name: StringName in TUNABLES[group]:
			assert_true(found.get(group, {}).has(name), "%s is declared in group %s" % [name, group])
	# Replaced by the amendments: they must not exist.
	assert_false("director_min_attack_gap_s" in Tuning.data, "A2.10: replaced by director_min_windup_gap_s")
	assert_false("rear_warning_fallback_reach_m" in Tuning.data, "A2.8: dummy_jab has a reach of its own")


func test_the_enemy_subgroups_come_in_the_plans_order() -> void:
	var order := PackedStringArray()
	for info: Dictionary in Tuning.tuning_properties():
		if info.group == "Enemies" and info.subgroup != "" and not order.has(info.subgroup):
			order.append(info.subgroup)
	assert_eq(order, ENEMY_SUBGROUPS)


func test_the_shipped_preset_holds_the_new_tunables() -> void:
	var text := FileAccess.get_file_as_string("res://tuning/default.json")
	var data: Dictionary = JSON.parse_string(text)
	var tuning: Dictionary = data.tuning
	for name: StringName in [&"windup_min_frames_grunt", &"punk_health", &"director_min_windup_gap_s",
			&"rear_warning_behind_deg", &"rear_warning_hide_in_ko", &"grab_break_invuln_frames", &"boss_health"]:
		assert_true(tuning.has(String(name)), "default.json has %s" % name)
	assert_false(tuning.has("ai_frozen"), "the Debug group stays out of presets")


# --- Input and rooms (2.12, A2.2) ------------------------------------------------------------


func test_f6_switches_rooms_and_the_help_lists_it() -> void:
	assert_eq(GameInput.BINDINGS[&"switch_room"], [KEY_F6])
	assert_true(InputMap.has_action(&"switch_room"), "registered")
	assert_eq(GameInput.ROOM_SCENES, [
		"res://game/level/crowd_room.tscn", "res://game/level/test_room.tscn"] as Array[String])
	var listed := false
	for row: Array in HelpOverlay.DEBUG_ROWS:
		listed = listed or row[1] == &"switch_room"
	assert_true(listed, "a help row for the room switch")
	assert_eq(HelpOverlay.binding_text([&"switch_room"], false), "F6")
	# The other of the two rooms from whichever is running; none from anywhere else, and none
	# while the target scene does not exist (the crowd room, until P1-room lands: F6 then does
	# nothing in the training room).
	assert_eq(GameInput.room_after(GameInput.ROOM_SCENES[0]), GameInput.ROOM_SCENES[1], "from the crowd room to the training room")
	var crowd_exists := ResourceLoader.exists(GameInput.ROOM_SCENES[0])
	assert_eq(GameInput.room_after(GameInput.ROOM_SCENES[1]), GameInput.ROOM_SCENES[0] if crowd_exists else "", "and back, when the crowd room exists")
	assert_eq(GameInput.room_after("res://tests/bot/combo_bot.tscn"), "", "a bot or test host is neither room")
	assert_eq(GameInput.room_after(""), "")
	# Run from here (a test host, not a room) F6 does nothing.
	assert_eq(GameInput.other_room(), "")
	var scene := get_tree().current_scene
	GameInput.switch_room()
	assert_eq(get_tree().current_scene, scene, "nothing happens from a host")


func test_while_f1_or_f4_is_open_the_fight_holds() -> void:
	GameInput.menu_open = false
	var host := Node3D.new()
	add_child_autofree(host)
	var overlay := TuningOverlay.new()
	host.add_child(overlay)
	await _ticks(2)
	assert_false(GameInput.menu_open)
	overlay.set_panel_open(true)
	assert_true(GameInput.menu_open, "the tuning panel holds the fight")
	overlay.set_cheats_open(true)
	overlay.set_panel_open(false)
	assert_true(GameInput.menu_open, "still, with the cheats up")
	overlay.close_all()
	assert_false(GameInput.menu_open, "released on closing")
	overlay.set_cheats_open(true)
	assert_true(GameInput.menu_open)
	host.remove_child(overlay)
	overlay.free()
	assert_false(GameInput.menu_open, "a freed overlay can't leave the fight held")


# --- Enemies: catalog, skeletons, fixtures (2.5, 2.6, 2.8, A2.12) ------------------------------


func test_the_catalog_lists_only_scenes_that_exist() -> void:
	var ids: Array[StringName] = []
	for entry: Dictionary in EnemyCatalog.ENTRIES:
		ids.append(entry.id)
	assert_eq(ids, [&"dummy", &"punk", &"punk_veteran", &"kicker", &"thug", &"bruiser", &"boss"] as Array[StringName])
	for entry: Dictionary in EnemyCatalog.ENTRIES:
		assert_true(String(entry.scene).begins_with("res://game/enemies/"), "%s: a scene under game/enemies" % entry.id)
		assert_true(String(entry.scene).ends_with(".tscn"))
	var available := EnemyCatalog.available()
	assert_gt(available.size(), 0, "the training dummy exists")
	for entry: Dictionary in available:
		assert_true(ResourceLoader.exists(entry.scene), "%s exists" % entry.id)
		assert_not_null(EnemyCatalog.scene(entry.id), "%s loads" % entry.id)
	for entry: Dictionary in EnemyCatalog.ENTRIES:
		if not ResourceLoader.exists(entry.scene):
			assert_null(EnemyCatalog.scene(entry.id), "%s has no scene yet" % entry.id)
			assert_false(available.any(func(e: Dictionary) -> bool: return e.id == entry.id))
	assert_null(EnemyCatalog.scene(&"nobody"))


func test_the_catalog_reads_body_sizes_from_an_instance() -> void:
	var dummy := (EnemyCatalog.scene(&"dummy") as PackedScene).instantiate() as CombatActor
	assert_eq(EnemyCatalog.body_size(&"dummy"), Vector2(dummy.body_radius, dummy.body_height))
	dummy.free()
	var defaults := CombatActor.new()
	assert_eq(EnemyCatalog.body_size(&"nobody"), Vector2(defaults.body_radius, defaults.body_height), "an unknown id: the default capsule")
	defaults.free()


func test_the_enemy_base_joins_its_groups_and_keeps_the_directors_bookkeeping() -> void:
	# What any EnemyActor (the S0 skeleton and every real archetype) promises.
	var enemy := EnemyActor.new()
	enemy.position = Vector3(0.0, 0.0, -4.0)
	_scene.add_child(enemy)
	await _ticks(6)
	assert_eq(enemy.team, 1)
	for group: StringName in [&"actor", &"enemy", &"ai_enemy"]:
		assert_true(enemy.is_in_group(group), "in group %s" % group)
	assert_false(enemy.is_in_group(&"boss"))
	assert_true(EnemyActor.AiState.keys().has(String(enemy.ai_state_name())), "its state has a name")
	assert_eq(enemy.posture_slot, Vector3.INF, "no slot until the director gives one")
	assert_false(enemy.has_token)
	enemy.grant_token(true)
	assert_true(enemy.has_token and enemy.blind_priority_granted, "the director's grant")
	enemy.set_slot(Vector3(1.0, 0.0, 2.0))
	assert_eq(enemy.posture_slot, Vector3(1.0, 0.0, 2.0))
	enemy.revoke_token()
	assert_false(enemy.has_token or enemy.blind_priority_granted, "the director's revoke")
	assert_not_null(EnemyActor.windup_move(_punch(), false), "a wind-up move for any move")


func test_the_director_is_found_and_ensured_once() -> void:
	assert_null(EnemyDirector.find(get_tree()), "none yet")
	var host := Node3D.new()
	_scene.add_child(host)
	var first := EnemyDirector.ensure(host)
	assert_not_null(first)
	assert_true(first.is_in_group(&"enemy_director"))
	assert_eq(EnemyDirector.find(get_tree()), first)
	assert_eq(EnemyDirector.ensure(host), first, "idempotent")
	assert_eq(EnemyDirector.ensure(_scene), first, "from anywhere in the tree")
	# The read API answers for an enemy it does not know.
	var enemy := EnemyActor.new()
	assert_eq(first.slot_for(enemy), Vector3.INF)
	assert_eq(first.debug_slot_of(enemy), Vector3.INF)
	assert_false(first.debug_token_holders().has(enemy))
	assert_false(first.debug_waiting().has(enemy))
	assert_eq(first.attacker_cap(), Tuning.data.attacker_cap)
	assert_eq(first.debug_ring(), Vector2(Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m))
	first.release_token(enemy)
	enemy.free()


func test_the_stub_enemy_stands_still_and_force_attack_winds_up() -> void:
	var enemy := STUB_ENEMY.instantiate() as EnemyActor
	enemy.position = Vector3(0.0, 0.0, -3.0)
	_scene.add_child(enemy)
	await _ticks(6)
	assert_true(enemy.is_in_group(&"ai_enemy"))
	assert_false(enemy.wants_token(), "the test flag is off")
	enemy.set(&"want_token", true)
	assert_true(enemy.wants_token(), "the test flag drives it")
	assert_almost_eq(enemy.global_position, Vector3(0.0, 0.0, -3.0), Vector3.ONE * 0.05)
	watch_signals(CombatEvents)
	enemy.force_attack()
	await _ticks(2)
	assert_eq(enemy.state, CombatTypes.ActorState.WINDUP, "force_attack() winds up from FREE")
	assert_eq(enemy.ai_state, EnemyActor.AiState.WINDUP)
	assert_signal_emitted(CombatEvents, "windup_started")
	assert_almost_eq(enemy.attack_range_m(), 1.05, 0.0001, "its default attack is the sparring jab")
	await _ticks(60)
	assert_eq(enemy.state, CombatTypes.ActorState.FREE, "back to standing after the attack")
	assert_signal_emitted(CombatEvents, "windup_ended")


func test_the_stub_enemy_and_stub_director_run_a_token_turn() -> void:
	var director := StubDirector.new()
	_scene.add_child(director)
	var enemy := STUB_ENEMY.instantiate() as EnemyActor
	enemy.position = Vector3(0.0, 0.0, -3.0)
	_scene.add_child(enemy)
	await _ticks(4)
	enemy.set(&"attack_on_token", true)
	director.put_slot(enemy, Vector3(1.0, 0.0, -3.0))
	assert_eq(director.slot_for(enemy), Vector3(1.0, 0.0, -3.0))
	assert_eq(director.debug_slot_of(enemy), Vector3(1.0, 0.0, -3.0))
	director.windup_allowed = false
	director.give_token(enemy, true)
	assert_eq(director.debug_token_holders(), [enemy] as Array[EnemyActor])
	await _ticks(3)
	assert_eq(enemy.state, CombatTypes.ActorState.FREE, "held back by may_start_windup()")
	assert_true(director.windup_asks.has(enemy), "it asked")
	director.windup_allowed = true
	await _ticks(3)
	assert_eq(enemy.state, CombatTypes.ActorState.WINDUP, "wound up once allowed")
	await _ticks(60)
	assert_eq(director.released, [enemy] as Array[EnemyActor], "it gave the token back when the attack ended")
	assert_false(enemy.has_token)
	assert_true(director.debug_token_holders().is_empty())
	director.waiting.append(enemy)
	assert_eq(director.debug_waiting(), [enemy] as Array[EnemyActor])
	director.cap = 2
	assert_eq(director.attacker_cap(), 2)
	director.ring = Vector2(1.0, 2.0)
	assert_eq(director.debug_ring(), Vector2(1.0, 2.0))
	assert_eq(EnemyDirector.find(get_tree()), director, "found through the group")


# --- Poses and animation dispatch (2.13) ---------------------------------------------------------


func test_the_new_animations_exist_and_the_loops_loop() -> void:
	var rig := HumanoidRig.new()
	_scene.add_child(rig)
	rig.build()
	for id: StringName in [&"taunt", &"brace", &"run_forward", &"hold_collar", &"held_collar", &"held_lift"]:
		assert_true(rig.has_anim(id), "has_anim(%s)" % id)
		assert_true(rig.anim_player.has_animation(id), "the library has %s" % id)
		var looping := id in [&"run_forward", &"hold_collar", &"held_collar", &"held_lift"]
		var expected := Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
		assert_eq(rig.anim_player.get_animation(id).loop_mode, expected, "%s loop mode" % id)
	assert_false(rig.has_anim(&"moonwalk"))
	assert_false(PlaceholderEnemyPoses.has_recipe(&"moonwalk"))
	assert_null(PlaceholderEnemyPoses.recipe(&"moonwalk", PlaceholderPoses.guard(), PlaceholderPoses.weapon_guard()))
	assert_null(PlaceholderPoses.move_poses(&"moonwalk"), "an unknown id still has no recipe")
	assert_not_null(PlaceholderPoses.move_poses(&"jab_1"), "known recipes are untouched")


func test_a_held_windup_keys_a_second_pose() -> void:
	var jab := load("res://game/combat/moves/dummy_jab.tres") as MoveData
	var base := PlaceholderPoses.move_poses(&"dummy_jab")
	assert_eq(base.windup_hold_at, -1.0, "no shipped move holds its wind-up")
	assert_eq(PlaceholderAnims.windup_hold_time(jab, base), -1.0)
	var plain := PlaceholderAnims.build_move_with(base, jab, 1.0)
	# The held telegraph: wind-up at 0.5 of the startup, held (plus a delta) at 0.8.
	var delta: Dictionary[StringName, Vector3] = {&"Spine": Vector3(-6.0, 12.0, 0.0)}
	var held := PlaceholderEnemyPoses.held(PlaceholderPoses.move_poses(&"dummy_jab"), 0.5, 0.8, delta)
	assert_eq([held.windup_at, held.windup_hold_at], [0.5, 0.8])
	assert_almost_eq(PlaceholderAnims.windup_hold_time(jab, held), jab.startup * 0.8 / 60.0, 1e-5)
	var clip := PlaceholderAnims.build_move_with(held, jab, 1.0)
	assert_almost_eq(clip.length, jab.total_frames() / 60.0, 1e-4)
	var spine := clip.find_track(^"Skeleton3D:Spine", Animation.TYPE_ROTATION_3D)
	var plain_spine := plain.find_track(^"Skeleton3D:Spine", Animation.TYPE_ROTATION_3D)
	assert_gt(clip.track_get_key_count(spine), plain.track_get_key_count(plain_spine), "an extra key for the hold")
	var windup_t := jab.startup * 0.5 / 60.0
	var hold_t := jab.startup * 0.8 / 60.0
	var at_windup := clip.track_find_key(spine, windup_t, Animation.FIND_MODE_APPROX)
	var at_hold := clip.track_find_key(spine, hold_t, Animation.FIND_MODE_APPROX)
	assert_gte(at_windup, 0, "the wind-up key")
	assert_gte(at_hold, 0, "the held key")
	var cocked := clip.track_get_key_value(spine, at_windup) as Quaternion
	var holding := clip.track_get_key_value(spine, at_hold) as Quaternion
	assert_gt(rad_to_deg(cocked.angle_to(holding)), 5.0, "the hold's delta shows")
	# Held without a delta: the same pose, held between the two keys.
	var still := PlaceholderAnims.build_move_with(PlaceholderEnemyPoses.held(PlaceholderPoses.move_poses(&"dummy_jab")), jab, 1.0)
	var still_spine := still.find_track(^"Skeleton3D:Spine", Animation.TYPE_ROTATION_3D)
	var a := still.track_get_key_value(still_spine, still.track_find_key(still_spine, jab.startup * 0.5 / 60.0, Animation.FIND_MODE_APPROX)) as Quaternion
	var b := still.track_get_key_value(still_spine, still.track_find_key(still_spine, jab.startup * 0.8 / 60.0, Animation.FIND_MODE_APPROX)) as Quaternion
	assert_lt(rad_to_deg(a.angle_to(b)), 0.01, "a plain hold repeats the wind-up pose")
	# A hold that does not lie after the wind-up key is ignored, and the strike still keys.
	var early := PlaceholderEnemyPoses.held(PlaceholderPoses.move_poses(&"dummy_jab"), 0.5, 0.3)
	assert_eq(PlaceholderAnims.windup_hold_time(jab, early), -1.0)
	assert_gte(clip.track_find_key(spine, jab.startup / 60.0, Animation.FIND_MODE_APPROX), 0, "the strike key is unchanged")


func test_the_hold_survives_mirroring() -> void:
	var delta: Dictionary[StringName, Vector3] = {&"LeftUpperArm": Vector3(5.0, 10.0, 3.0)}
	var held := PlaceholderEnemyPoses.held(PlaceholderPoses.move_poses(&"dummy_jab"), 0.5, 0.8, delta)
	var mirrored := held.mirrored()
	assert_eq(mirrored.windup_hold_at, 0.8)
	assert_true(mirrored.windup_hold.has(&"RightUpperArm"), "the delta's arm swapped sides")
	assert_eq(mirrored.windup_hold[&"RightUpperArm"], Vector3(5.0, -10.0, -3.0), "yaw and roll negated")
