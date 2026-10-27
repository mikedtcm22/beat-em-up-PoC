extends RefCounted
## The Bruiser's acts (P3-bruiser), in first person in the crowd room (see tests/bot/crowd_bot.gd):
## its armor (jabs bounce off and the wind-up goes on, the hook and the uppercut stagger it, the
## haymaker knocks it down and opens it up), the overhead smash from the ring and at arm's length,
## the grab (mashed free, then left to land its headbutt), the rear warning's larger burst when it
## winds up behind, and a few measurement acts (a real one-on-one, its cadence, the Bruiser among
## Punks). Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/p3-bruiser "Bruiser" 6
## The AI is frozen where an act wants a Bruiser that stands still and attacks on command
## (force_attack(0) is the smash, force_attack(1) the grab), as the Thug's acts do.

const SliceActs := preload("res://tests/bot/acts/slice_acts.gd")
## The Bruiser's health in the acts that hit it: enough to survive what the act does.
const SURVIVING_HEALTH := 600.0
## Where it stands to be hit and to hit: within its smash, ahead of the player, and within its grab's
## connect range (1.05 m at a 1.8 m rig, times its height over 1.8: 1.2 m, so a little nearer).
const CLOSE := Vector2(0.0, 1.2)
const GRAB_CLOSE := Vector2(0.0, 1.1)
## Frames between two punches that must not chain (a second P inside the combo window is the
## jab's next link).
const SEPARATE_GAP := 70
## Frames between the presses of the bot's mash (about 12 presses a second).
const MASH_GAP := 3
## The first-person pitch that shows a body lying at the player's feet.
const LOOK_DOWN_DEG := -35.0
const LOOK_FORWARD_DEG := -6.0


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Bruiser shrugs off jabs", cam = &"first_person", probe = true, fn = func() -> void: await _shrugs(bot)},
		{title = "Hook staggers the Bruiser", cam = &"first_person", probe = true, fn = func() -> void: await _hook(bot)},
		{title = "Haymaker breaks the armor", cam = &"first_person", probe = true, fn = func() -> void: await _haymaker(bot)},
		{title = "Grab the staggered Bruiser", cam = &"first_person", fn = func() -> void: await _grab_it(bot)},
		{title = "Bruiser smash", cam = &"first_person", probe = true, fn = func() -> void: await _smash(bot)},
		{title = "Bruiser smash blocked", cam = &"first_person", probe = true, fn = func() -> void: await _smash_blocked(bot)},
		{title = "Bruiser grab: mash free", cam = &"first_person", probe = true, fn = func() -> void: await _mash_free(bot)},
		{title = "Bruiser headbutt", cam = &"first_person", probe = true, fn = func() -> void: await _headbutt(bot)},
		{title = "Bruiser winds up behind", cam = &"first_person", probe = true, fn = func() -> void: await _behind(bot)},
		{title = "Bruiser 1v1", cam = &"first_person", probe = true, fn = func() -> void: await _one_v_one(bot)},
		{title = "Bruiser cadence", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _cadence(bot)},
		{title = "Six Bruisers, observed", cam = &"first_person", probe = true, fn = func() -> void: await _six(bot)},
		{title = "Bruiser among Punks, passive", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _among_punks(bot)},
		{title = "Bruiser among Punks, fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight(bot)},
	]


## A Bruiser at `rel` from the player (x right, y ahead), facing him, its AI frozen so it stands
## where it is until force_attack(); it survives what the act does to it.
static func _stand(bot: Node, rel: Vector2 = CLOSE) -> Bruiser:
	bot.freeze_ai(true)
	var bruiser: Bruiser = bot.spawn(&"bruiser", rel)
	bruiser.max_health = SURVIVING_HEALTH
	bruiser.health = SURVIVING_HEALTH
	await bot._ticks(30)
	return bruiser


## Walk the player straight at `bruiser` until he is `distance_m` from it (or 60 ticks have passed).
static func _walk_to(bot: Node, bruiser: Bruiser, distance_m: float) -> void:
	bot.player.look_yaw = atan2(-(bruiser.global_position.x - bot.player.global_position.x),
			-(bruiser.global_position.z - bot.player.global_position.z))
	bot.player.input.scripted_move = Vector2(0.0, 1.0)
	await bot._wait_until(func() -> bool:
			var to: Vector3 = bruiser.global_position - bot.player.global_position
			return Vector2(to.x, to.z).length() <= distance_m, 90)
	bot.player.input.scripted_move = Vector2.ZERO


## Wait for the Bruiser's wind-up to have run `frames` frames.
static func _into_windup(bot: Node, bruiser: Bruiser, frames: int) -> void:
	await bot._wait_until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP and bruiser.move_frame >= frames, 120)


## Two jabs on the standing Bruiser (it shrugs them off, a brace), then its smash is forced and two
## more jabs land in the middle of the wind-up: damage each time, no flinch, and the smash still
## comes out and knocks the player down (god mode: the reactions play, no damage).
static func _shrugs(bot: Node) -> void:
	bot.god()
	var bruiser := await _stand(bot)
	for i in 2:
		await bot._press(&"P", 2, SEPARATE_GAP)
	bruiser.force_attack(0)
	await _into_windup(bot, bruiser, 8)
	await bot._press(&"P", 2, 6)
	await bot._press(&"P", 2, 2)
	await bot._wait_until(func() -> bool: return bruiser.current_move == null, 200)
	await bot._ticks(150)


## Forced smash again: the hook (P P P) lands in the middle of the wind-up and staggers it out of
## the move; the next P is the uppercut, a finisher, which staggers it again.
static func _hook(bot: Node) -> void:
	bot.god()
	var bruiser := await _stand(bot)
	bruiser.force_attack(0)
	await _into_windup(bot, bruiser, 6)
	for i in 3:
		await bot._press(&"P", 2, 7)
	await bot._wait_until(func() -> bool: return bruiser.state == CombatTypes.ActorState.STAGGER, 40)
	await bot._ticks(24)
	await bot._press(&"P", 2, 8)
	await bot._ticks(120)


## The haymaker (P held a little over its charge) knocks the Bruiser down; once it is up its armor is
## off for bruiser_armor_break_s and a jab flinches it, where before it only braced.
static func _haymaker(bot: Node) -> void:
	bot.god()
	var bruiser := await _stand(bot)
	await bot._press(&"P", Tuning.data.hold_frames + 10)
	await bot._wait_until(func() -> bool: return bruiser.is_downed(), 120)
	await bot._wait_until(func() -> bool: return bruiser.state == CombatTypes.ActorState.FREE, 300)
	# It lies a few metres off: walk up to it, and jab twice (the armor is off: it flinches).
	await _walk_to(bot, bruiser, 1.1)
	await bot._ticks(24)
	await bot._press(&"P", 2, SEPARATE_GAP)
	await bot._press(&"P", 2, 30)
	await bot._ticks(120)


## A hook staggers it, and a staggered Bruiser can be grabbed: LB, a knee, the throw.
static func _grab_it(bot: Node) -> void:
	bot.god()
	var bruiser := await _stand(bot, Vector2(0.0, 1.0))
	for i in 3:
		await bot._press(&"P", 2, 6)
	await bot._wait_until(func() -> bool: return bruiser.state == CombatTypes.ActorState.STAGGER, 40)
	await _walk_to(bot, bruiser, 0.9)
	await bot._wait_idle()
	await bot._press(&"GRAB", 2, 14)
	await bot._press(&"P", 2)
	await bot._wait_idle()
	await bot._ticks(4)
	await bot._press(&"K", 2)
	await bot._wait_idle()
	await bot._ticks(120)


## The smash from the ring (3 m: the wind-up as it reads from afar, nothing to hit), then at arm's
## length (it lands: a knockdown for 15, the player gets up).
static func _smash(bot: Node) -> void:
	bot.god()
	var far := await _stand(bot, Vector2(0.0, 3.0))
	far.force_attack(0)
	await _into_windup(bot, far, 1)
	await bot._wait_until(func() -> bool: return far.current_move == null, 240)
	await bot._ticks(40)
	bot.clear_enemies()
	await bot._ticks(10)
	var near := await _stand(bot)
	near.force_attack(0)
	await _into_windup(bot, near, 1)
	await bot._wait_until(func() -> bool: return near.current_move == null, 240)
	await bot._ticks(150)


## The smash into a raised guard: the guard drains, the Bruiser does not recoil.
static func _smash_blocked(bot: Node) -> void:
	var bruiser := await _stand(bot)
	await bot._hold_block()
	await bot._ticks(Tuning.data.block_raise_frames + 2)
	bruiser.force_attack(0)
	await bot._wait_until(func() -> bool: return bruiser.current_move == null and bruiser.move_frame == 0, 240)
	await bot._ticks(60)
	await bot._release_block()
	await bot._ticks(60)


## Grabbed, pulled in, a moment of the MASH prompt, then eight presses break free.
static func _mash_free(bot: Node) -> void:
	var bruiser := await _stand(bot, GRAB_CLOSE)
	bruiser.force_attack(1)
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.GRABBED, 120)
	await bot._ticks(14)
	for i in Tuning.data.grab_break_presses:
		await bot._press(&"P", 1, MASH_GAP)
	await bot._ticks(110)


## Grabbed and not mashing: the headbutt lands and knocks him down.
static func _headbutt(bot: Node) -> void:
	bot.god()
	var bruiser := await _stand(bot, GRAB_CLOSE)
	bruiser.force_attack(1)
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.GRABBED, 120)
	await bot._wait_until(func() -> bool: return bot.player.state != CombatTypes.ActorState.GRABBED, 180)
	await bot._ticks(150)


## A Bruiser winds up behind-left (135 degrees, 1.5 m): the top-left corner lights with the larger
## heavy burst, and the smash lands. Then a Punk does the same behind-right, for the size of the
## burst to be compared (corner crops: crop=iw*0.3:ih*0.3:0:0 and crop=iw*0.3:ih*0.3:iw*0.7:0).
static func _behind(bot: Node) -> void:
	bot.god()
	var bruiser := await _stand(bot, SliceActs.rel_at(135.0, 1.2))
	bruiser.force_attack(0)
	await bot._wait_until(func() -> bool: return bruiser.current_move == null and bruiser.ai_state == EnemyActor.AiState.RECOVER, 400)
	await bot._ticks(90)
	bot.clear_enemies()
	await bot._ticks(10)
	bot.freeze_ai(true)
	var punk: EnemyActor = bot.spawn(&"punk", SliceActs.rel_at(-135.0, 1.0))
	await bot._ticks(30)
	punk.force_attack(0)
	await bot._wait_until(func() -> bool: return punk.current_move == null and punk.ai_state == EnemyActor.AiState.RECOVER, 400)
	await bot._ticks(90)


## One Bruiser walks in from the east alley (ahead) and takes its turn: the commit pause, the step
## in, the held wind-up and its attack, as the AI does it. The bot keeps it in view and does nothing.
static func _one_v_one(bot: Node) -> void:
	bot.god()
	_reseed(bot)
	var bruiser: Bruiser = bot.spawn_at_point(&"bruiser", 2)
	bot.pilot.defend = false
	bot.pilot.attack = false
	bot.pilot.approach = false
	bot.pilot.turn_deg_per_s = 160.0
	bot.pilot.enabled = true
	await bot._wait_until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP, 1500)
	await bot._wait_until(func() -> bool: return bruiser.ai_state == EnemyActor.AiState.RECOVER, 400)
	await bot._ticks(180)


## One Bruiser against a player who does nothing and cannot die (god mode): how often it attacks.
## The cadence count is the act's WU+ lines; `--tune=bruiser_attack_cooldown_s=<s>` and `--seed=<n>`
## repeat the measurement.
static func _cadence(bot: Node) -> void:
	bot.god()
	_reseed(bot)
	await bot.surround(1, 0, &"bruiser")
	await bot._ticks(2400)


## Six Bruisers, god mode, walking in one after another while the bot turns once through 360 degrees
## slowly, then stands still: the crowd of the biggest bodies as the player sees it, and the spawn
## frames of six Bruiser rigs (record it windowed, not recording, for the probe's R15).
static func _six(bot: Node) -> void:
	bot.god()
	_reseed(bot)
	await bot.surround(6, 24, &"bruiser")
	await bot._turn_by(360.0, 600)
	await bot._ticks(300)


## One Bruiser among five Punks against a player who does nothing and takes the damage (R12).
static func _among_punks(bot: Node) -> void:
	_reseed(bot)
	for i in 6:
		await bot.surround(1, 0, &"bruiser" if i == 2 else &"punk")
	await bot._ticks(1500)


## One Bruiser among five Punks, god mode, the held-back autopilot fights for 25 s.
static func _fight(bot: Node) -> void:
	bot.god()
	_reseed(bot)
	for i in 6:
		await bot.surround(1, 24, &"bruiser" if i == 2 else &"punk")
	await bot.fight(1500)


## The names of the Bruisers follow the bot's `--seed` as the Punks' do (each enemy's random choices
## are seeded by its name), so a measurement can be repeated.
static func _reseed(bot: Node) -> void:
	var offset: int = bot._name_offset
	bot.spawner.set(&"_serials", {"Punk": offset, "Bruiser": offset})
