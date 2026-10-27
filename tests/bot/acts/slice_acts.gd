extends RefCounted
## The slice acts of Milestone 3 (P1-int): the Street Punk end to end in the crowd room, in
## first person, with the readability probe on (every act has `probe = true`, so each prints a
## READABILITY summary, the warning oracle's WARN-CHECK lines and a LOCK line, and writes its
## readability.json beside the recording). See tests/bot/crowd_bot.gd for the helpers.
##
## One Punk, three, six observed, six fought, the rear warning on frozen Punks, six with the
## player facing the wall, six against a passive player, the director's F3 overlay, and the
## waves. Fights are the autopilot's (tests/bot/autopilot.gd); an act that is about what the
## enemies do to a player who does nothing (observed, blind spot, passive) leaves it off.

const RoomActs := preload("res://tests/bot/acts/room_acts.gd")
## The guard goes up this many frames before the strike: early enough for an ordinary block (a
## guard raised in the last few frames is a perfect block, which staggers the attacker).
const BLOCK_LEAD_FRAMES := 26


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Punk 1v1", cam = &"first_person", probe = true, fn = func() -> void: await _one_v_one(bot)},
		{title = "Three Punks", cam = &"first_person", probe = true, fn = func() -> void: await _three(bot)},
		{title = "Six Punks, observed", cam = &"first_person", probe = true, fn = func() -> void: await _observed(bot)},
		{title = "Six Punks, fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight_six(bot)},
		{title = "Warn L/R/behind", cam = &"first_person", probe = true, fn = func() -> void: await _warn(bot)},
		{title = "Six Punks, blind spot", cam = &"first_person", probe = true, fn = func() -> void: await _blind_spot(bot)},
		{title = "Six Punks, passive", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _passive(bot)},
		{title = "Director, F3", cam = &"side_view", probe = true, fn = func() -> void: await _director(bot, false)},
		{title = "Director, F3, free fly", cam = &"free_fly", probe = true, fn = func() -> void: await _director(bot, true)},
		{title = "Waves", cam = &"first_person", probe = true, fn = func() -> void: await _waves(bot)},
	]


## The `rel` (x right, y ahead of the player, metres) of a point `distance_m` away at `bearing_deg`
## from the look (0 ahead, positive to the left, +-180 behind, as the rear warning's bearings).
static func rel_at(bearing_deg: float, distance_m: float) -> Vector2:
	var b := deg_to_rad(bearing_deg)
	return Vector2(-sin(b) * distance_m, cos(b) * distance_m)


## Turn the look to face `enemy`, at most `deg_per_s`, for as long as the caller loops it.
static func _face_step(bot: Node, enemy: Node3D, deg_per_s: float) -> void:
	var step := deg_per_s / float(Engine.physics_ticks_per_second)
	var turn := clampf(bot.player.look_bearing_deg(enemy.global_position), -step, step)
	bot.player.look_yaw = wrapf(bot.player.look_yaw + deg_to_rad(turn), -PI, PI)


# --- Punk 1v1 -------------------------------------------------------------------------------


## One Punk walks in from the east doorway (ahead and left), postures and attacks. The bot keeps
## it in view and blocks its first attack, then punches it out of its second wind-up, then
## P P P P. (The autopilot is only the facing: no defence, no offence, no walking.)
static func _one_v_one(bot: Node) -> void:
	var punk: EnemyActor = bot.spawn_at_point(&"punk", 2)
	bot.pilot.defend = false
	bot.pilot.attack = false
	bot.pilot.approach = false
	bot.pilot.turn_deg_per_s = 160.0
	bot.pilot.enabled = true
	# 1. The first wind-up: the guard goes up just before the strike and holds until it is over.
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 1500)
	await bot._wait_until(func() -> bool:
			return punk.current_move == null or punk.move_frame >= punk.current_move.startup - BLOCK_LEAD_FRAMES, 60)
	await bot._hold_block()
	await bot._wait_until(func() -> bool: return punk.current_move == null, 90)
	await bot._ticks(20)
	await bot._release_block()
	# 2. The next wind-up: a jab out of it, a few frames in.
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 900)
	await bot._wait_until(func() -> bool: return punk.move_frame >= 6 or punk.state != CombatTypes.ActorState.WINDUP, 30)
	await bot._press(&"P", 2)
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.HITSTUN, 40)
	await bot._ticks(20)
	# 3. P P P P.
	for i in 4:
		await bot._press(&"P", 2, 8)
	await bot._ticks(150)


# --- Three and six --------------------------------------------------------------------------


## Three Punks walk in from ahead, the left and behind. The bot turns slowly through 360 degrees
## twice (they circle and attack while it does), then fights.
static func _three(bot: Node) -> void:
	await bot.surround(3, 30)
	await bot._ticks(90)
	await bot._turn_by(360.0, 420)
	await bot._turn_by(360.0, 420)
	bot.keep_alive(3)
	await bot.fight(1200)


## Six Punks, god mode: the bot turns once through 360 degrees slowly (10 s), then stands still
## facing +X (10 s). Nothing it does shows: this is the crowd as the player sees it.
static func _observed(bot: Node) -> void:
	bot.god()
	await bot.surround(6)
	await bot._turn_by(360.0, 600)
	await bot._ticks(600)


## Six Punks, god mode, the autopilot fights for 25 s; a new Punk walks in whenever one falls,
## so six stay on the street.
static func _fight_six(bot: Node) -> void:
	bot.god()
	await bot.surround(6)
	bot.keep_alive(6)
	await bot.fight(1500)


## Six Punks, god mode, the player facing the north wall and still: every attack comes from the
## side or behind, so the warning is the only sign (the oracle checks every one).
static func _blind_spot(bot: Node) -> void:
	bot.god()
	bot.player.look_yaw = 0.0
	bot.player.rotation.y = 0.0
	await bot.surround(6)
	await bot._ticks(1200)


## Six Punks against a player who does nothing and takes the damage (R12: no KO inside 12 s, no
## 2 s window over 30 damage). They all walk in at once.
static func _passive(bot: Node) -> void:
	await bot.surround(6, 0)
	await bot._ticks(1500)


# --- The rear warning -----------------------------------------------------------------------


## The AI frozen, Punks placed at 1.5 m and thrown a wind-up each in turn (force_attack): behind
## right (-135), behind left (+135), directly behind (180); then two on the left at once (the
## second 22 ticks after the first, the wind-ups stretched so both are live together) and a
## Punk at 50 degrees, in view, as the control. WARN-CHECK lines per wind-up.
static func _warn(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	await bot._look_to(0.0, 6)
	for bearing: float in [-135.0, 135.0, 180.0]:
		var punk: EnemyActor = bot.spawn(&"punk", rel_at(bearing, 1.5))
		await bot._ticks(20)
		await _throw(bot, punk)
		bot.clear_enemies()
		await bot._ticks(20)
	bot.tune(&"windup_mult", 2.5)
	var first: EnemyActor = bot.spawn(&"punk", rel_at(100.0, 1.0))
	var second: EnemyActor = bot.spawn(&"punk", rel_at(140.0, 1.2))
	await bot._ticks(20)
	first.force_attack()
	await bot._ticks(22)
	second.force_attack()
	await bot._wait_until(func() -> bool: return first.current_move == null and second.current_move == null, 240)
	await bot._ticks(40)
	bot.clear_enemies()
	await bot._ticks(20)
	var control: EnemyActor = bot.spawn(&"punk", rel_at(50.0, 1.0))
	await bot._ticks(20)
	await _throw(bot, control)
	await bot._ticks(40)


## `punk` winds up and strikes now; wait until it has.
static func _throw(bot: Node, punk: EnemyActor) -> void:
	punk.force_attack()
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 20)
	await bot._wait_until(func() -> bool: return punk.current_move == null, 240)
	await bot._ticks(30)


# --- The director, and the waves ------------------------------------------------------------


## The six-Punk fight with the debug overlay on (F3): tokens, slots, the ring and the view
## boundary, from the side view; or from above, the free fly camera drifting over the street.
static func _director(bot: Node, fly: bool) -> void:
	bot.god()
	var hud: Node = bot._hud()
	if hud:
		hud.call(&"set_debug_draw_enabled", true)
	await bot.surround(6)
	bot.keep_alive(6)
	bot.hold_back()
	bot.pilot.enabled = true
	if fly:
		await RoomActs._fly_path(bot, Vector3(-10.0, 9.0, 12.0), Vector3(10.0, 9.0, 12.0), Vector3(0.0, 0.0, -1.0), 900)
	else:
		await bot._ticks(900)
	if hud:
		hud.call(&"set_debug_draw_enabled", false)


## The waves on from the start: the table's waves play in turn, the autopilot fights, god mode,
## 90 s (R13 asks for at least two waves cleared in that time).
static func _waves(bot: Node) -> void:
	bot.god()
	bot.set_waves(true)
	await bot.fight(5400)
