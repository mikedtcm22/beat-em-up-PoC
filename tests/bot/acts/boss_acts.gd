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
## The full fight's length (ticks): the autopilot has ninety seconds to kill the boss.
const FIGHT_TICKS := 5400
## The held-back autopilot (one jab-jab at a time, no kicks, a long rest) is slow: five minutes.
const HELD_TICKS := 18000


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
		{title = "Boss fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight(bot, false)},
		{title = "Boss held back fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight(bot, true)},
		{title = "Boss passive", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _passive(bot)},
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
## LOCK lines say how long it took and what it cost, and one BOSSMETER line says how the boss spent
## its life (`_meter()`). The act ends when the boss falls. `--seed=<n> --tune=boss_poise_s=0` is the
## measurement behind the poise (M3-calls/F-boss-poise.md).
static func _fight(bot: Node, held_back: bool) -> void:
	_seed_names(bot)
	var boss: EnemyActor = bot.spawn_at_point(&"boss", 4)
	if held_back:
		bot.hold_back()
	bot.pilot.enabled = true
	await _meter(bot, boss, HELD_TICKS if held_back else FIGHT_TICKS)


## The boss alone against a player who does nothing and takes real damage (the room revives him): how
## often it hits and how long he lasts. The meter's PILOT line is empty.
static func _passive(bot: Node) -> void:
	_seed_names(bot)
	var boss: EnemyActor = bot.spawn_at_point(&"boss", 4)
	await _meter(bot, boss, CADENCE_TICKS)


## Start the boss's numbering where `-- --seed=<n>` puts the Punk's (the crowd bot seeds only the
## Punk's), so a measurement can be repeated over several fights: each enemy's random choices
## are seeded by its name.
static func _seed_names(bot: Node) -> void:
	var serials: Dictionary = bot.spawner.get(&"_serials")
	serials["Boss"] = bot._name_offset


## Watch `boss` for up to `ticks` physics ticks (or until it falls) and print one BOSSMETER line: how
## long it lived (a kill time in seconds, or "alive"), the share of that life it spent in REACT (any
## reaction: hitstun, stagger, down, getting up) and since it first took up POSTURE, its reactions
## (staggers and knockdowns), what it wound up and how many of those the player cut, what it landed on
## the player (hits, blocked, damage, by move), the grabs that connected, the player's KOs, and what
## the player's hits did to it (absorbed or not, by move) and its poise frames when it has any. The
## numbers the poise was judged on, so the act file carries them.
static func _meter(bot: Node, boss: EnemyActor, ticks: int) -> void:
	var m := {
		wu = {}, cut = 0, hit = {}, hit_n = 0, blocked = 0, dmg = 0.0, grabs = 0, p_ko = 0,
		took = {}, absorbed = 0, reactions = 0, staggers = 0, downs = 0, react = 0, life = 0,
		since_posture = -1, react_since = 0, poised = 0, poise_hits = 0, states = {}, dist = [],
	}
	var on_hit := func(hit: HitInfo) -> void:
		if hit.victim == bot.player and hit.attacker == boss:
			var id: String = String(hit.move.id) if hit.move else "body"
			if hit.blocked:
				m.blocked += 1
			else:
				m.hit_n += 1
				m.dmg += hit.damage
				m.hit[id] = int(m.hit.get(id, 0)) + 1
		elif hit.victim == boss and hit.attacker == bot.player:
			var id: String = String(hit.move.id) if hit.move else "body"
			var key := "%s%s" % [id, "*" if hit.armor_absorbed else ""]
			m.took[key] = int(m.took.get(key, 0)) + 1
			if hit.armor_absorbed:
				m.absorbed += 1
	var on_wu := func(attacker: Node3D, move: MoveData) -> void:
		if attacker == boss:
			m.wu[String(move.id)] = int(m.wu.get(String(move.id), 0)) + 1
			m.dist.append("%s@%.1f" % [String(move.id).trim_prefix("boss_"), Vector2(boss.global_position.x - bot.player.global_position.x,
					boss.global_position.z - bot.player.global_position.z).length()])
	var on_wu_end := func(attacker: Node3D, interrupted: bool) -> void:
		if attacker == boss and interrupted:
			m.cut += 1
	var on_grab := func(holder: Node3D, victim: Node3D) -> void:
		if holder == boss and victim == bot.player:
			m.grabs += 1
	var on_ko := func(victim: Node3D, _hit: HitInfo) -> void:
		if victim == bot.player:
			m.p_ko += 1
	CombatEvents.hit_landed.connect(on_hit)
	CombatEvents.windup_started.connect(on_wu)
	CombatEvents.windup_ended.connect(on_wu_end)
	CombatEvents.grabbed.connect(on_grab)
	CombatEvents.ko.connect(on_ko)
	var last_ai := -1
	var last_state := -1
	var killed := -1
	var health := 0.0
	var phase := 1
	for tick in ticks:
		await bot._ticks(1)
		if not is_instance_valid(boss):
			break
		m.life += 1
		health = boss.health
		phase = int(boss.get(&"phase"))
		var ai := int(boss.ai_state)
		var state := int(boss.state)
		var ai_name: String = EnemyActor.AiState.keys()[ai]
		m.states[ai_name] = int(m.states.get(ai_name, 0)) + 1
		if ai == EnemyActor.AiState.REACT:
			m.react += 1
			if m.since_posture >= 0:
				m.react_since += 1
		if m.since_posture < 0 and ai == EnemyActor.AiState.POSTURE:
			m.since_posture = 0
		if m.since_posture >= 0:
			m.since_posture += 1
		if ai == EnemyActor.AiState.REACT and last_ai != EnemyActor.AiState.REACT:
			m.reactions += 1
		if state != last_state:
			if state == CombatTypes.ActorState.STAGGER:
				m.staggers += 1
			elif state in [CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.THROWN]:
				m.downs += 1
		if boss.has_method(&"is_poised") and boss.call(&"is_poised"):
			m.poised += 1
		last_ai = ai
		last_state = state
		if boss.health <= 0.0 and killed < 0:
			killed = m.life
		if killed >= 0 and m.life - killed > 30:
			break
	CombatEvents.hit_landed.disconnect(on_hit)
	CombatEvents.windup_started.disconnect(on_wu)
	CombatEvents.windup_ended.disconnect(on_wu_end)
	CombatEvents.grabbed.disconnect(on_grab)
	CombatEvents.ko.disconnect(on_ko)
	var life := maxf(float(m.life), 1.0)
	var since := maxf(float(m.since_posture), 1.0)
	var winds := 0
	for id: String in m.wu:
		winds += int(m.wu[id])
	bot.log_line("BOSSMETER seed=%d: %s, life %.1f s, REACT %.0f%% of its life and %.0f%% since it first postured, %d reactions (%d staggers, %d knockdowns), wind-ups %d %s (%d cut), it landed %d hits for %.0f (%s), %d blocked, %d grabs connected, player KOs %d, poised %.1f s, wind-up distances %s, the player's hits on it %s, states %s, phase %d" % [
			roundi(float(bot._name_offset) / 7.0), ("killed at %.1f s" % (float(killed) / 60.0)) if killed >= 0 else ("ALIVE with %.0f hp" % health),
			life / 60.0, 100.0 * float(m.react) / life, 100.0 * float(m.react_since) / since, m.reactions, m.staggers, m.downs,
			winds, JSON.stringify(m.wu), m.cut, m.hit_n, m.dmg, JSON.stringify(m.hit), m.blocked, m.grabs, m.p_ko,
			float(m.poised) / 60.0, JSON.stringify(m.dist), JSON.stringify(m.took), JSON.stringify(m.states), phase])
