extends "res://tests/bot/combo_bot.gd"
## Ragdoll acts (Milestone 2 WP4, Spec §6 "Hit reactions") for review captures, built on
## the combo bot's harness: staggers that give way (partial ragdoll), bodies knocked off
## their feet flying and landing (full ragdoll), a flying body knocking a second one down,
## the throw, a KO going limp and staying, and the get-ups, each in first person and side
## view. Record it with Movie Maker:
##   godot --path . --write-movie captures/ragdoll/ragdoll.avi --fixed-fps 60 \
##     --resolution 1280x720 res://tests/bot/ragdoll_bot.tscn [-- --act=<title text>]
## Every act waits for its bodies to get up (or, the KO, to lie still and revive).
## `-- --no-ragdoll` records the same acts with Tuning.ragdoll_enabled off (the animated
## reactions of Milestone 1), for comparison.

## Seconds a body is watched after the last hit of an act: long enough to land, lie, sleep
## and get up (Tuning.downed_frames + getup_frames, about 1.8 s).
const WATCH_S := 2.6


func _run() -> void:
	if OS.get_cmdline_user_args().has("--no-ragdoll"):
		Tuning.data.ragdoll_enabled = false
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
		{title = "Ragdoll: KO on a low-health dummy", cam = &"first_person", fn = _act_ko},
		{title = "Ragdoll: KO on a low-health dummy (side view)", cam = &"side_view", fn = _act_ko},
		{title = "Ragdoll: guard-break stagger", cam = &"first_person", fn = _act_guard_break_dummy},
		{title = "Ragdoll: guard-break stagger (side view)", cam = &"side_view", fn = _act_guard_break_dummy},
		{title = "Ragdoll: parried jab, the arm knocked back", cam = &"first_person", fn = _act_perfect_block},
		{title = "Ragdoll: parried jab (side view)", cam = &"side_view", fn = _act_perfect_block},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not title.to_lower().contains(act_filter.to_lower()):
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


## A dummy on its last few points: the uppercut KOs it; it goes limp, settles and stays,
## then revives (Tuning.dummy_revive_s) and gets up where it lies.
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
	# In first person, look down at the body lying limp, and back up before it revives.
	await _wait_until(func() -> bool: return dummy.is_ko(), 60)
	await _look_to(-38.0, 14)
	await _watch(Tuning.data.dummy_revive_s - 0.4)
	await _look_to(-6.0, 14)
	await _watch(1.6)


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


## Wait `seconds` (sim time at 60 Hz ticks).
func _watch(seconds: float) -> void:
	await _ticks(roundi(seconds * Engine.physics_ticks_per_second))
