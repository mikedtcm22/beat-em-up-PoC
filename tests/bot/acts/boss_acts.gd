extends RefCounted
## The boss's acts of Milestone 3 (P3-boss) for the crowd bot (tests/bot/crowd_bot.gd), first
## person unless the title says otherwise. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/p3-boss "Boss charge" 6
##
## The attacks are thrown with force_attack() on a frozen AI, so the wind-up is judged from the
## lens at the attack's own range: "Boss charge in front" (4.5 m, it lands), "Boss charge dodged"
## (a sidestep: it goes by), "Boss charge behind" (the rear warning at 180 and 135 degrees, the
## charge's reach in it), "Boss pound" (it lands), "Boss pound jumped" (the player jumps the ring),
## "Boss grab slam" (held, lifted, thrown), "Boss armor" (jabs absorbed, the hook staggers it out
## of its wind-up). "Boss phase 2 adds" has the real AI: the boss walks in, postures, takes half
## its health and two Punks walk in from the doorways; "Boss bar" drains the bar at the bottom
## centre. "Boss cadence" (the measurement behind boss_attack_cooldown_s and the attack mix, a
## player who stands still, god mode) and "Boss fight" (the autopilot) are for numbers, not looks.
## Acts with `probe = true` print the readability summary and the warning oracle's WARN-CHECK lines.

const SliceActs := preload("res://tests/bot/acts/slice_acts.gd")
## How many frames into the pound's wind-up the player jumps (its startup is 36): airborne and
## above the ring's 0.6 m band by the strike frame.
const JUMP_AT_FRAME := 14
## How far into the charge's wind-up (share of its startup) the player steps aside.
const DODGE_AT_SHARE := 0.55
## Measuring acts' length (ticks): a minute of the boss against a player who stands still.
const CADENCE_TICKS := 3600


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Boss charge in front", cam = &"first_person", probe = true, fn = func() -> void: await _charge_front(bot)},
		{title = "Boss charge dodged", cam = &"first_person", probe = true, fn = func() -> void: await _charge_dodged(bot)},
		{title = "Boss charge behind", cam = &"first_person", probe = true, fn = func() -> void: await _charge_behind(bot)},
		{title = "Boss pound", cam = &"first_person", probe = true, fn = func() -> void: await _pound(bot, false)},
		{title = "Boss pound jumped", cam = &"first_person", probe = true, fn = func() -> void: await _pound(bot, true)},
		{title = "Boss grab slam", cam = &"first_person", probe = true, fn = func() -> void: await _grab_slam(bot)},
		{title = "Boss armor", cam = &"first_person", probe = true, fn = func() -> void: await _armor(bot)},
		{title = "Boss phase 2 adds", cam = &"first_person", probe = true, fn = func() -> void: await _phase2(bot)},
		{title = "Boss bar", cam = &"first_person", fn = func() -> void: await _bar(bot)},
		{title = "Boss charge (side view)", cam = &"side_view", fn = func() -> void: await _charge_front(bot)},
		{title = "Boss pound (side view)", cam = &"side_view", fn = func() -> void: await _pound(bot, false)},
		{title = "Boss cadence", cam = &"first_person", probe = true, fn = func() -> void: await _cadence(bot)},
		{title = "Boss fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight(bot)},
	]


## A frozen boss at `rel` from the player (x right, y ahead), facing him, standing still: the AI is
## frozen, so only force_attack() starts its attacks.
static func _boss(bot: Node, rel: Vector2) -> EnemyActor:
	_seed_names(bot)
	bot.freeze_ai(true)
	var boss: EnemyActor = bot.spawn(&"boss", rel)
	await bot._ticks(30)
	return boss


static func _wind_up(bot: Node, boss: EnemyActor, index: int) -> void:
	boss.force_attack(index)
	await bot._wait_until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 20)


static func _finish(bot: Node, boss: EnemyActor, settle: int = 120) -> void:
	await bot._wait_until(func() -> bool: return boss.current_move == null, 300)
	await bot._ticks(settle)


## The charge from 4.5 m ahead on a player who stands still (god mode): the crouch, the dash, the hit.
static func _charge_front(bot: Node) -> void:
	bot.god()
	var boss := await _boss(bot, Vector2(0.0, 4.5))
	await _wind_up(bot, boss, 0)
	await _finish(bot, boss, 150)


## The charge from 4.0 m: a quick sidestep late in the wind-up (the boss's tracking has stopped), and
## it goes by.
static func _charge_dodged(bot: Node) -> void:
	var boss := await _boss(bot, Vector2(0.0, 4.0))
	await _wind_up(bot, boss, 0)
	var startup := boss.current_move.startup
	await bot._wait_until(func() -> bool: return boss.move_frame >= int(startup * DODGE_AT_SHARE), 60)
	bot.player.input.scripted_move = Vector2(-1.0, 0.0)
	await bot._press(&"DODGE", 2)
	bot.player.input.scripted_move = Vector2.ZERO
	await _finish(bot, boss, 100)


## The charge from behind: directly behind at 4.5 m (both corners; the dash is in the reach), then
## behind-left at 4.0 m (the left corner), the player looking down the street. WARN-CHECK per wind-up.
static func _charge_behind(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	await bot._look_to(0.0, 6)
	for spec: Array in [[180.0, 4.5], [135.0, 4.0]]:
		_seed_names(bot)
		var boss: EnemyActor = bot.spawn(&"boss", SliceActs.rel_at(spec[0], spec[1]))
		await bot._ticks(30)
		await _wind_up(bot, boss, 0)
		await _finish(bot, boss, 60)
		bot.clear_enemies()
		await bot._ticks(40)


## The pound from 2.3 m, ahead. `jumped`: the player jumps in its wind-up and the ring passes under him.
static func _pound(bot: Node, jumped: bool) -> void:
	bot.god()
	var boss := await _boss(bot, Vector2(0.0, 2.55))
	await _wind_up(bot, boss, 1)
	if jumped:
		await bot._wait_until(func() -> bool: return boss.move_frame >= JUMP_AT_FRAME, 40)
		await bot._press(&"JUMP", 2)
	await _finish(bot, boss, 120)


## The grab slam at arm's length: the grab, the lift, the throw (it connects: he does not mash).
static func _grab_slam(bot: Node) -> void:
	bot.god()
	var boss := await _boss(bot, Vector2(0.0, 1.3))
	await _wind_up(bot, boss, 2)
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.GRABBED, 120)
	await bot._wait_until(func() -> bool: return bot.player.state != CombatTypes.ActorState.GRABBED, 180)
	await _finish(bot, boss, 170)


## Jabs into its wind-up are absorbed (a spark of damage, no flinch, the wind-up goes on); a hook
## (the third punch of the chain, a heavy hit) staggers it and the wind-up is cut.
static func _armor(bot: Node) -> void:
	var boss := await _boss(bot, Vector2(0.0, 1.5))
	await _wind_up(bot, boss, 1)
	await bot._ticks(6)
	for i in 3:
		await bot._press(&"P", 2, 6)
	await bot._ticks(10)
	bot.log_line("ARMOR boss state %s move %s health %.0f" % [CombatTypes.state_name(boss.state),
			boss.current_move.id if boss.current_move else &"-", boss.health])
	await _finish(bot, boss, 90)


## The real AI: the boss walks in from a doorway and postures on the ring; at half health it turns
## faster, beckons and two Punks walk in from the doorways and alleys. The player watches it (the
## autopilot only keeps it in view), god mode.
static func _phase2(bot: Node) -> void:
	_seed_names(bot)
	bot.god()
	bot.pilot.defend = false
	bot.pilot.attack = false
	bot.pilot.approach = false
	bot.pilot.turn_deg_per_s = 90.0
	bot.pilot.enabled = true
	var boss: EnemyActor = bot.spawn_at_point(&"boss", 1)
	await bot._ticks(420)
	boss.health = boss.max_health * Tuning.data.boss_phase2_at
	bot.log_line("BOSS f%d health set to %.0f (phase %d)" % [Engine.get_physics_frames(), boss.health, boss.phase])
	for i in 24:
		await bot._ticks(30)
		bot.log_line("BOSS f%d phase %d %s, %d AI enemies alive" % [Engine.get_physics_frames(), boss.phase,
				boss.ai_state_name(), bot.spawner.alive_count()])


## The boss's bar at the bottom centre: it drains as the boss is hurt (set by hand: a bar's look is
## all this act is for), the player looking at the boss on the ring.
static func _bar(bot: Node) -> void:
	_seed_names(bot)
	bot.god()
	var boss: EnemyActor = await _boss(bot, Vector2(0.0, 4.0))
	await bot._ticks(60)
	for share: float in [0.8, 0.55, 0.3, 0.1]:
		boss.health = boss.max_health * share
		await bot._ticks(75)


## The boss alone round a player who stands still (god mode): how often it attacks and with what
## (count the WU+ lines by move) is what boss_attack_cooldown_s and the attack chances set; the
## figure the cooldown was chosen from (M3-calls/P3-boss.md). `--tune=boss_attack_cooldown_s=<s>`.
static func _cadence(bot: Node) -> void:
	_seed_names(bot)
	bot.god()
	bot.spawn_at_point(&"boss", 4)
	await bot._ticks(CADENCE_TICKS)


## The autopilot against the boss (not god mode, the room revives him): can he win? PILOT and
## LOCK lines say how long it took and what it cost.
static func _fight(bot: Node) -> void:
	_seed_names(bot)
	bot.spawn_at_point(&"boss", 4)
	await bot.fight(5400, false)


## Start the boss's numbering where `-- --seed=<n>` puts the Punk's (the crowd bot seeds only the
## Punk's), so a measurement can be repeated over several fights: each enemy's random choices
## are seeded by its name.
static func _seed_names(bot: Node) -> void:
	var serials: Dictionary = bot.spawner.get(&"_serials")
	serials["Boss"] = bot._name_offset
