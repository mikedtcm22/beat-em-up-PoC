extends RefCounted
## The enemy-grab acts of Milestone 3 (P2-grab) for the crowd bot (tests/bot/crowd_bot.gd), in
## first person, with the readability probe on: the test grabber (tests/fixtures/grab_test_enemy,
## the Bruiser's grab and headbutt; grab_test_boss, the boss's grab and slam) stands still, its
## attack forced, so the held view can be judged from the lens: the grab's wind-up, the player
## pulled in and turned to face the grabber, the MASH prompt, and then a way out of it or the hit.
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/grab "Grab:" 12

const GRABBER := preload("res://tests/fixtures/grab_test_enemy.tscn")
const GRAB_BOSS := preload("res://tests/fixtures/grab_test_boss.tscn")
const SliceActs := preload("res://tests/bot/acts/slice_acts.gd")
## Where the grabber stands to grab: ahead of the player, within its reach.
const CLOSE := Vector2(0.0, 1.1)
## Frames between the presses of the bot's mash (about 12 presses a second).
const MASH_GAP := 3


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Grab: dodge out", cam = &"first_person", probe = true, fn = func() -> void: await _dodge_out(bot)},
		{title = "Grab: held, mash free", cam = &"first_person", probe = true, fn = func() -> void: await _mash_free(bot)},
		{title = "Grab: held, headbutt lands", cam = &"first_person", probe = true, fn = func() -> void: await _headbutt(bot)},
		{title = "Grab: slam", cam = &"first_person", probe = true, fn = func() -> void: await _slam(bot)},
		{title = "Grab: from behind", cam = &"first_person", probe = true, fn = func() -> void: await _from_behind(bot)},
	]


## The grabber (the boss-sized one when `boss`) at `rel` from the player (x right, y ahead), facing
## him, standing still: the AI is frozen, so only force_attack() starts its grab.
static func _grabber(bot: Node, rel: Vector2, boss: bool = false) -> EnemyActor:
	var id := &"grab_boss" if boss else &"grab_test"
	bot.spawner.scene_override[id] = GRAB_BOSS if boss else GRABBER
	bot.freeze_ai(true)
	var grabber: EnemyActor = bot.spawn(id, rel)
	await bot._ticks(24)
	return grabber


static func _until_held(bot: Node) -> void:
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.GRABBED, 120)


## He sees the grab coming (the arms spread wide at the edges of the view) and steps back out of it.
static func _dodge_out(bot: Node) -> void:
	var grabber := await _grabber(bot, CLOSE)
	grabber.force_attack()
	await bot._wait_until(func() -> bool: return grabber.current_move != null and grabber.move_frame >= 24, 60)
	bot.player.input.scripted_move = Vector2(0.0, -1.0)
	await bot._press(&"DODGE", 2)
	bot.player.input.scripted_move = Vector2.ZERO
	await bot._ticks(110)


## Grabbed, pulled in and turned to the grabber, a moment of the MASH prompt, then eight presses
## break free: the grabber is shoved back, the player stands where he was.
static func _mash_free(bot: Node) -> void:
	var grabber := await _grabber(bot, CLOSE)
	grabber.force_attack()
	await _until_held(bot)
	await bot._ticks(14)
	for i in Tuning.data.grab_break_presses:
		await bot._press(&"P", 1, MASH_GAP)
	await bot._ticks(110)


## Held and not mashing: the headbutt lands, knocks him down, he gets up.
static func _headbutt(bot: Node) -> void:
	var grabber := await _grabber(bot, CLOSE)
	grabber.force_attack()
	await _until_held(bot)
	await bot._wait_until(func() -> bool: return bot.player.state != CombatTypes.ActorState.GRABBED, 180)
	await bot._ticks(150)


## The boss-sized grabber lifts him and slams him: thrown for 25.
static func _slam(bot: Node) -> void:
	var grabber := await _grabber(bot, Vector2(0.0, 1.3), true)
	grabber.force_attack()
	await _until_held(bot)
	await bot._wait_until(func() -> bool: return bot.player.state != CombatTypes.ActorState.GRABBED, 180)
	await bot._ticks(170)


## The grab from behind-left: the rear warning lights the top-left corner for the wind-up and goes
## out when it connects, and the view swings round to the grabber. Then he mashes free.
static func _from_behind(bot: Node) -> void:
	bot.player.look_yaw = deg_to_rad(-90.0)
	var grabber := await _grabber(bot, SliceActs.rel_at(135.0, 1.1))
	grabber.force_attack()
	await _until_held(bot)
	await bot._ticks(20)
	for i in Tuning.data.grab_break_presses:
		await bot._press(&"K", 1, MASH_GAP)
	await bot._ticks(90)
