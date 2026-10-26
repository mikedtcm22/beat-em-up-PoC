extends RefCounted
## The Pipe Thug's acts (P2-thug), in first person in the crowd room (see tests/bot/crowd_bot.gd):
## its three-swing combo from the ring and from arm's length, a real one-on-one with the AI, the
## pipe dropping when the player knocks it down, and the player taking the pipe with LB and
## swinging it on a Punk. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/p2-thug "Thug" 6
## The AI is frozen where an act wants a Thug that stands still and swings on command
## (force_attack), as the rear warning acts do.

## The Thug's health in the acts that knock it down: enough to survive the combo that does it.
const SURVIVING_HEALTH := 400.0
## A Punk that survives three pipe swings.
const DUMMY_HEALTH := 500.0
## The pitch (degrees) that shows the street at the player's feet, and the bot's usual one.
const LOOK_DOWN_DEG := -50.0
const LOOK_FORWARD_DEG := -6.0


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Thug three swings", cam = &"first_person", fn = func() -> void: await _three_swings(bot)},
		{title = "Thug 1v1", cam = &"first_person", fn = func() -> void: await _one_v_one(bot)},
		{title = "Thug drops the pipe", cam = &"first_person", fn = func() -> void: await _drops(bot)},
		{title = "Take the Thug's pipe", cam = &"first_person", fn = func() -> void: await _takes(bot)},
		{title = "Six Thugs, observed", cam = &"first_person", probe = true, fn = func() -> void: await _observed(bot)},
		{title = "Six Thugs, passive", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _passive(bot)},
		{title = "Six Thugs, fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight(bot)},
		{title = "Thug and five Punks, passive", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _mixed_passive(bot)},
	]


## A Thug `distance_m` ahead, its AI frozen so it stands where it is until `force_attack()`.
static func _stand(bot: Node, distance_m: float) -> PipeThug:
	var thug: PipeThug = bot.spawn(&"thug", Vector2(0.0, distance_m))
	thug.max_health = SURVIVING_HEALTH
	thug.health = SURVIVING_HEALTH
	return thug


## The Thug 3 m ahead winds up and swings at nothing (the telegraph as it reads from the ring), then
## 1.2 m ahead it swings the whole combo at the player (god mode: the reactions play, no damage).
static func _three_swings(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	var far := _stand(bot, 3.0)
	await bot._ticks(30)
	far.force_attack()
	await bot._wait_until(func() -> bool: return far.state == CombatTypes.ActorState.WINDUP, 20)
	await bot._wait_until(func() -> bool: return far.current_move == null, 240)
	await bot._ticks(40)
	bot.clear_enemies()
	await bot._ticks(10)
	var near := _stand(bot, 1.2)
	await bot._ticks(30)
	near.force_attack()
	await bot._wait_until(func() -> bool: return near.state == CombatTypes.ActorState.WINDUP, 20)
	await bot._wait_until(func() -> bool: return near.current_move == null, 240)
	await bot._ticks(90)


## One Thug walks in from the east alley (ahead) and takes its turn: the commit pause, the step in,
## the held wind-up and the combo, as the AI does it. The bot keeps it in view and does nothing
## else (the autopilot is only the facing).
static func _one_v_one(bot: Node) -> void:
	bot.god()
	var thug: PipeThug = bot.spawn_at_point(&"thug", 2)
	bot.pilot.defend = false
	bot.pilot.attack = false
	bot.pilot.approach = false
	bot.pilot.turn_deg_per_s = 160.0
	bot.pilot.enabled = true
	await bot._wait_until(func() -> bool: return thug.state == CombatTypes.ActorState.WINDUP, 1500)
	await bot._wait_until(func() -> bool: return thug.ai_state == EnemyActor.AiState.RECOVER, 300)
	await bot._ticks(120)


## The player punches a Thug 1.1 m ahead, P P P P, the last a knockdown: the pipe leaves its hand
## and falls to the street in front of the player, and lies there (within LB's reach, which is below
## the first-person view at the forward pitch: the bot looks down at it, then up again).
static func _drops(bot: Node) -> void:
	bot.freeze_ai(true)
	var thug := _stand(bot, 1.1)
	await bot._ticks(40)
	await _knock_down(bot, thug)
	await bot._ticks(40)
	await bot._look_to(LOOK_DOWN_DEG, 30)
	await bot._ticks(60)
	await bot._look_to(LOOK_FORWARD_DEG, 30)
	await bot._ticks(60)


## The knockdown, then LB: the player takes the Thug's pipe, clears the Thug away and swings the
## pipe three times at a Punk.
static func _takes(bot: Node) -> void:
	bot.freeze_ai(true)
	var thug := _stand(bot, 1.1)
	await bot._ticks(40)
	await _knock_down(bot, thug)
	await bot._ticks(40)
	await bot._look_to(LOOK_DOWN_DEG, 30)
	await bot._ticks(30)
	await bot._press(&"GRAB", 2, 20)
	await bot._look_to(LOOK_FORWARD_DEG, 30)
	await bot._ticks(20)
	bot.clear_enemies()
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, 1.2))
	punk.max_health = DUMMY_HEALTH
	punk.health = DUMMY_HEALTH
	await bot._ticks(30)
	for i in 3:
		await bot._press(&"P", 2, 9)
	await bot._wait_idle()
	await bot._ticks(60)


## P P P P on `thug` until it is down (the ground chain's last punch launches).
static func _knock_down(bot: Node, thug: PipeThug) -> void:
	for i in 4:
		await bot._press(&"P", 2, 8)
	await bot._wait_until(func() -> bool: return not thug.has_pipe(), 120)


# --- Six of them (the cadence the Thug's attack cooldown is measured on) ----------------------


## Six Thugs, god mode: the bot turns once through 360 degrees slowly (10 s), then stands still.
## Nothing it does shows: this is the crowd as the player sees it.
static func _observed(bot: Node) -> void:
	bot.god()
	_reseed(bot)
	await bot.surround(6, 24, &"thug")
	await bot._turn_by(360.0, 600)
	await bot._ticks(600)


## Six Thugs against a player who does nothing and takes the damage (R12: how long he lasts and the
## worst two seconds). They all walk in at once.
static func _passive(bot: Node) -> void:
	_reseed(bot)
	await bot.surround(6, 0, &"thug")
	await bot._ticks(1500)


## Six Thugs, god mode, the autopilot fights for 25 s (the room's top-up spawns Punks, so none here:
## the fight ends when the Thugs fall).
static func _fight(bot: Node) -> void:
	bot.god()
	_reseed(bot)
	await bot.surround(6, 24, &"thug")
	await bot.fight(1500)


## One Thug among five Punks against a player who does nothing: the crowd the waves make (R12 for a
## Thug's 30-damage combo among the Punks' 12-damage ones).
static func _mixed_passive(bot: Node) -> void:
	_reseed(bot)
	for i in 6:
		await bot.surround(1, 0, &"thug" if i == 2 else &"punk")
	await bot._ticks(1500)


## The names of the Thugs follow the bot's `--seed` as the Punks' do (each enemy's random choices
## are seeded by its name), so a measurement can be repeated.
static func _reseed(bot: Node) -> void:
	var offset: int = bot._name_offset
	bot.spawner.set(&"_serials", {"Punk": offset, "Thug": offset})
