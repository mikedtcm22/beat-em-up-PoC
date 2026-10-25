extends "res://tests/bot/combo_bot.gd"
## Ragdoll acts (Milestone 2 WP4, Spec §6 "Hit reactions") for review captures, built on
## the combo bot's harness: staggers that give way (partial ragdoll), bodies knocked off
## their feet flying and landing (full ragdoll), a flying body knocking a second one down,
## the throw, a knee that KOs the held body, a KO going limp and staying, the get-ups, a
## guard break, the finisher shove,
## a parried jab, a body launched from behind landing face down, and a stomp on a lying body
## that then gets up under the player, each in first person and side view. The KO act shows
## the whole blink-off: the body lies, blinks, is gone, and the dummy blinks back in at its
## post. Record it with Movie Maker:
##   godot --path . --write-movie captures/ragdoll/ragdoll.avi --fixed-fps 60 \
##     --resolution 1280x720 res://tests/bot/ragdoll_bot.tscn [-- --act=<title text>]
## Every act waits for its bodies to get up (or, the KO, to come back).
## Switches after `--`, for A/B comparisons of the same acts:
##   --no-ragdoll     Tuning.ragdoll_enabled off (the animated reactions of Milestone 1);
##   --central-kick   Tuning.ragdoll_kick_at_contact off (the hit's kick central on the
##                    struck part, no twist at the contact point);
##   --set=<tunable>=<value>   any TuningData value, e.g. --set=ragdoll_partial_influence=0.6
##                    (repeatable).

## Seconds a body is watched after the last hit of an act: long enough to land, lie, sleep
## and get up (Tuning.downed_frames + getup_frames, about 1.8 s).
const WATCH_S := 2.6


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-ragdoll":
			Tuning.data.ragdoll_enabled = false
		elif arg == "--central-kick":
			Tuning.data.ragdoll_kick_at_contact = false
		elif arg.begins_with("--set="):
			_set_tunable(arg.trim_prefix("--set="))
	await _ticks(3)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	director = get_tree().get_first_node_in_group(&"camera_director")
	# The help overlay and the combat log would cover the bodies (the bot logs the hits).
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
		if child.has_method(&"set_combat_log_visible"):
			child.call(&"set_combat_log_visible", false)
	var acts: Array[Dictionary] = [
		{title = "Ragdoll: hook stagger", cam = &"first_person", fn = _act_hook},
		{title = "Ragdoll: hook stagger (side view)", cam = &"side_view", fn = _act_hook},
		{title = "Ragdoll: uppercut launch", cam = &"first_person", fn = _act_uppercut},
		{title = "Ragdoll: uppercut launch (side view)", cam = &"side_view", fn = _act_uppercut},
		{title = "Ragdoll: haymaker", cam = &"first_person", fn = _act_haymaker},
		{title = "Ragdoll: haymaker (side view)", cam = &"side_view", fn = _act_haymaker},
		{title = "Ragdoll: spinning heel, two dummies", cam = &"first_person", fn = _act_heel},
		{title = "Ragdoll: spinning heel, two dummies (side view)", cam = &"side_view", fn = _act_heel},
		{title = "Ragdoll: push kick into a second dummy", cam = &"first_person", fn = _act_push_kick},
		{title = "Ragdoll: push kick into a second dummy (side view)", cam = &"side_view", fn = _act_push_kick},
		{title = "Ragdoll: throw", cam = &"first_person", fn = _act_throw},
		{title = "Ragdoll: throw (side view)", cam = &"side_view", fn = _act_throw},
		{title = "Ragdoll: knee KOs the held dummy", cam = &"first_person", fn = _act_knee_ko},
		{title = "Ragdoll: knee KOs the held dummy (side view)", cam = &"side_view", fn = _act_knee_ko},
		{title = "Ragdoll: KO on a low-health dummy", cam = &"first_person", fn = _act_ko},
		{title = "Ragdoll: KO on a low-health dummy (side view)", cam = &"side_view", fn = _act_ko},
		{title = "Ragdoll: guard-break stagger", cam = &"first_person", fn = _act_guard_break_dummy},
		{title = "Ragdoll: guard-break stagger (side view)", cam = &"side_view", fn = _act_guard_break_dummy},
		{title = "Ragdoll: flurry, finisher shove", cam = &"first_person", fn = _act_shove},
		{title = "Ragdoll: flurry, finisher shove (side view)", cam = &"side_view", fn = _act_shove},
		{title = "Ragdoll: parried jab, the arm knocked back", cam = &"first_person", fn = _act_perfect_block},
		{title = "Ragdoll: parried jab (side view)", cam = &"side_view", fn = _act_perfect_block},
		{title = "Ragdoll: uppercut from behind, lands face down", cam = &"first_person", fn = _act_from_behind},
		{title = "Ragdoll: uppercut from behind, lands face down (side view)", cam = &"side_view", fn = _act_from_behind},
		{title = "Ragdoll: stomp a lying dummy, it gets up where it lies", cam = &"first_person", fn = _act_stomp_getup},
		{title = "Ragdoll: stomp a lying dummy, it gets up where it lies (side view)", cam = &"side_view", fn = _act_stomp_getup},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		caption.text = title
		# The movie time of the act's start: frame / 60 s (Movie Maker writes a frame a tick).
		print("=== %s  (movie %.2f s)" % [title, Engine.get_frames_drawn() / 60.0])
		var fn: Callable = act.fn
		await fn.call()
		await _wait_idle()
		await _ticks(30)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


## P P P: jab, jab, then the hook's stagger (the upper body gives way sideways).
func _act_hook() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 3:
		await _press(&"P", 2, 8)
	await _watch(1.2)


## P P P P: the uppercut launches the dummy (full ragdoll), it lands, lies and gets up.
func _act_uppercut() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 4:
		await _press(&"P", 2, 8)
	await _watch(WATCH_S)


func _act_haymaker() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", Tuning.data.hold_frames + 10)
	await _watch(WATCH_S)


## K K K with a second dummy inside the spinning heel's arc: both fly.
func _act_heel() -> void:
	await _stage([Vector3(-0.35, 0, -1.5), Vector3(0.9, 0, -1.2)])
	for i in 3:
		await _press(&"K", 2, 10)
	await _watch(WATCH_S)


## P P K: the push kick sends the first dummy into a second standing behind it, which goes
## down too (a flying-body knockdown).
func _act_push_kick() -> void:
	await _stage([Vector3(0, 0, -1.5), Vector3(0.15, 0, -3.6)])
	await _press(&"P", 2, 8)
	await _press(&"P", 2, 8)
	await _press(&"K", 2)
	await _watch(WATCH_S + 0.4)


## Grab an idle dummy and throw it.
func _act_throw() -> void:
	await _stage([Vector3(0, 0, -1.1)])
	await _look_to(0.0, 6)
	await _ticks(10)
	await _press(&"GRAB", 2, 12)
	await _press(&"K", 2)
	await _watch(WATCH_S)


## P P P on a dummy at the default dummy health (30), grab it, knee, knee: the second knee
## KOs the held body. It leaves the hold from where it is drawn, falls back away from the
## player (full ragdoll) and goes limp where it lands.
func _act_knee_ko() -> void:
	await _stage([Vector3(0, 0, -1.4)])
	var dummy := dummies[0]
	dummy.max_health = TuningData.new().dummy_health
	dummy.reset_state()
	CombatEvents.health_changed.emit(dummy, dummy.health, dummy.max_health)
	for i in 3:
		await _press(&"P", 2, 8)
	await _wait_idle()
	await _press(&"GRAB", 2, 10)
	for i in 2:
		await _press(&"P", 2)
		await _wait_idle()
		await _ticks(4)
	await _watch(1.5)


## A dummy on its last few points: the hook KOs it; it goes limp and lies
## (Tuning.ko_linger_s), blinks faster and faster (ko_blink_s) and is gone; after
## Tuning.dummy_revive_s it blinks back in, standing at its post, at full health. The player
## steps back meanwhile (the combo's step-ins carried it toward the post).
func _act_ko() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	dummy.max_health = 30.0
	dummy.reset_state()
	dummy.health = 14.0
	CombatEvents.health_changed.emit(dummy, dummy.health, dummy.max_health)
	for i in 4:
		await _press(&"P", 2, 8)
		if dummy.is_ko():
			break
	# In first person, look down at the body lying limp, and back up at the post before the
	# dummy comes back there.
	await _wait_until(func() -> bool: return dummy.is_ko(), 90)
	await _look_to(-24.0, 14)
	await _wait_until(func() -> bool: return dummy.is_gone(), 400)
	var post: Vector3 = dummy.get(&"_home")
	player.input.scripted_move = Vector2(0, -1)
	await _wait_until(func() -> bool: return Vector2(player.global_position.x - post.x, player.global_position.z - post.z).length() >= 1.6, 60)
	player.input.scripted_move = Vector2.ZERO
	await _look_to(-6.0, 14)
	await _wait_until(func() -> bool: return not dummy.is_ko(), 400)
	await _watch(Tuning.data.ko_blink_in_s + 1.0)


## The dummy holds a guard; jab after jab drains it until it breaks: the arms knocked
## apart, the upper body staggers back (partial ragdoll).
func _act_guard_break_dummy() -> void:
	await _stage([Vector3(0, 0, -1.4)])
	var dummy := dummies[0]
	await _look_to(-2.0, 6)
	for i in 12:
		if dummy.state == CombatTypes.ActorState.FREE:
			# Raised without a perfect-block window: the jabs drain it instead of being parried.
			dummy.start_block(false)
		await _press(&"P", 2)
		await _wait_until(func() -> bool: return player.current_move == null or dummy.state == CombatTypes.ActorState.STAGGER, 40)
		if dummy.state == CombatTypes.ActorState.STAGGER:
			break
		await _wait_idle()
		await _ticks(2)
	await _watch(1.0)
	dummy.drop_guard(0)


## P · P, then mash: the body-blow flurry ends in the finisher shove, a stagger that sends
## the body stumbling back (partial ragdoll).
func _act_shove() -> void:
	await _act_flurry()
	await _watch(1.2)


## P P P P on a dummy facing away: launched from behind, the body pitches over in the air,
## lands face down where its hurtboxes are and gets up from its front.
func _act_from_behind() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	dummy.face_player = false
	dummy.set_post(dummy.global_position, dummy.rotation.y + PI, true)
	await _ticks(10)
	for i in 4:
		await _press(&"P", 2, 8)
	await _watch(WATCH_S)
	dummy.face_player = true


## K K K knocks the dummy down; the player walks up and stomps the body lying there, then
## stands over it: it takes the stomp and gets up where it lies, not shoved aside.
func _act_stomp_getup() -> void:
	await _act_stomp()
	await _watch(WATCH_S)


## `name=value`: set that TuningData value (parsed as the property's type).
func _set_tunable(pair: String) -> void:
	var parts := pair.split("=")
	if parts.size() != 2 or Tuning.data.get(parts[0]) == null:
		push_warning("ragdoll_bot: no tunable in --set=%s" % pair)
		return
	var current: Variant = Tuning.data.get(parts[0])
	var value: Variant = parts[1]
	match typeof(current):
		TYPE_BOOL:
			value = parts[1] == "true" or parts[1] == "1"
		TYPE_INT:
			value = int(parts[1])
		TYPE_FLOAT:
			value = float(parts[1])
	Tuning.set_value(StringName(parts[0]), value)
	print("ragdoll_bot: %s = %s" % [parts[0], str(value)])


## Wait `seconds` (sim time at 60 Hz ticks).
func _watch(seconds: float) -> void:
	await _ticks(roundi(seconds * Engine.physics_ticks_per_second))
