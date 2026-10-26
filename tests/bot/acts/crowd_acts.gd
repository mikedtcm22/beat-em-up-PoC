extends RefCounted
## The whole-fight acts of Milestone 3 (P4-int) for the crowd bot (tests/bot/crowd_bot.gd): every
## archetype together, in first person, with the readability probe on (every act has
## `probe = true`, so each prints a READABILITY summary, the warning oracle's WARN-CHECK lines and a
## LOCK line, and writes its readability.json beside the recording). Record one with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Mixed six, observed" 6
## and check its log with `tools/check_m3_log.py captures/<key>/bot.log`.
##
## "Mixed six, observed": the six archetypes' mix (Punk, Kicker, Thug, Bruiser, Punk, Kicker) walk
## in, god mode, the player turns slowly through 360 degrees and then stands still: the crowd as
## the player sees it. "Mixed six, fight": the same six, the autopilot fights for 30 s. "Waves to
## the boss": the waves on, `boss_wave_every` 2 for the act, the autopilot fights until the boss
## has taken half its health and called in its Punks. "Rear warning, every archetype": the AI
## frozen, each archetype winds up behind-left, behind-right and directly behind, at its own strike
## range, so the corner is judged for a Punk's jab and a boss's pound alike (the heavies' bursts
## are larger). "Perf, six with ragdolls": six enemies fight a player who knocks them down, and
## windowed frame times are logged (record it WINDOWED, not with Movie Maker: the probe's R15 only
## measures a window that is not being recorded).
##
## The mixed make-up is the order of MIXED_SIX at the crowd bot's SURROUND_POINTS: ahead, left,
## right, behind, behind left, behind right.

const SliceActs := preload("res://tests/bot/acts/slice_acts.gd")

## The six enemies of the mixed acts, in the order they walk in (the plan's make-up).
const MIXED_SIX: Array[StringName] = [&"punk", &"kicker", &"thug", &"bruiser", &"punk", &"kicker"]
## Frames between two of the six walking in (the slice's gap).
const SPAWN_GAP_FRAMES := 24
## How long the autopilot fights in "Mixed six, fight" (ticks, 30 s).
const FIGHT_TICKS := 1800
## "Waves to the boss": `boss_wave_every` for the act, the longest it may take (ticks, 120 s) and
## how long it goes on once the adds are in (ticks, 6 s), so they are seen walking in.
const BOSS_EVERY := 2
const BOSS_MAX_TICKS := 7200
const ADDS_WATCH_TICKS := 360
## Each archetype's attack for the warning act, as [id, force_attack index, distance m]: the
## distance is where the archetype stands when it winds up for real (its attack's reach less the
## engage margin), so every wind-up ends in a hit and the warning is judged to the contact.
const WARN_ATTACKS: Array = [
	[&"punk", 0, 1.0],
	[&"kicker", 0, 2.6],
	[&"thug", 0, 1.15],
	[&"bruiser", 0, 1.25],
	[&"boss", 1, 2.55],
]
## The bearings of the warning act (degrees, positive to the left): behind-left, behind-right,
## directly behind.
const WARN_BEARINGS: Array[float] = [135.0, -135.0, 180.0]
## The perf act: the fight's length (ticks), the frames of one logged window, and how long after an
## enemy goes down the worst frame is looked for (s).
const PERF_TICKS := 1800
const PERF_WINDOW_FRAMES := 120
const PERF_AFTER_S := 0.5
## Enemy states that are a body going down (a partial or a full ragdoll), for the perf act's marks.
const DOWN_STATES: Array[int] = [
	CombatTypes.ActorState.STAGGER, CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.DOWNED,
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Mixed six, observed", cam = &"first_person", probe = true, fn = func() -> void: await _observed(bot)},
		{title = "Mixed six, fight", cam = &"first_person", probe = true, fn = func() -> void: await _fight(bot)},
		{title = "Waves to the boss", cam = &"first_person", probe = true, fn = func() -> void: await _waves_to_boss(bot)},
		{title = "Rear warning, every archetype", cam = &"first_person", probe = true,
				fn = func() -> void: await _warn_every_archetype(bot)},
		{title = "Perf, six with ragdolls", cam = &"first_person", probe = true, fn = func() -> void: await _perf(bot)},
	]


## The six walk in from the surround points, one every SPAWN_GAP_FRAMES.
static func _mixed_six(bot: Node, gap: int = SPAWN_GAP_FRAMES) -> void:
	for i in MIXED_SIX.size():
		bot.spawn_at_point(MIXED_SIX[i], bot.SURROUND_POINTS[i])
		if gap > 0:
			await bot._ticks(gap)


# --- The mixed six ----------------------------------------------------------------------------


## God mode, the six walk in, the bot turns once through 360 degrees slowly (10 s), then stands
## still facing +X (10 s). Nothing it does shows: this is the crowd as the player sees it.
static func _observed(bot: Node) -> void:
	bot.god()
	await _mixed_six(bot)
	await bot._turn_by(360.0, 600)
	await bot._ticks(600)


## God mode, the six walk in and the autopilot fights for 30 s (the held-back style, so the crowd
## gets to attack instead of falling to the first combo); a Punk walks in whenever one falls.
static func _fight(bot: Node) -> void:
	bot.god()
	await _mixed_six(bot)
	bot.keep_alive(6)
	await bot.fight(FIGHT_TICKS)


## The waves on, god mode, `boss_wave_every` 2: the autopilot fights wave after wave until the
## boss comes, takes half its health (phase 2) and its Punks walk in; then a few seconds more.
static func _waves_to_boss(bot: Node) -> void:
	bot.god()
	bot.tune(&"boss_wave_every", BOSS_EVERY)
	bot.set_waves(true)
	bot.pilot.enabled = true
	await bot._wait_until(func() -> bool: return _adds_called(bot), BOSS_MAX_TICKS)
	var boss := _boss(bot)
	bot.log_line("BOSS f%d phase %d, %d adds, %d AI enemies alive, health %.0f of %.0f" % [Engine.get_physics_frames(),
			boss.phase if boss else 0, boss.adds.size() if boss else 0, bot.spawner.alive_count(),
			boss.health if boss else 0.0, boss.max_health if boss else 0.0])
	await bot._ticks(ADDS_WATCH_TICKS)


## The live boss, or null.
static func _boss(bot: Node) -> Boss:
	for node: Node in bot.get_tree().get_nodes_in_group(&"boss"):
		var boss := node as Boss
		if boss != null and boss.health > 0.0:
			return boss
	return null


## True once the boss is in phase 2 and its adds are all in the street.
static func _adds_called(bot: Node) -> bool:
	var boss := _boss(bot)
	return boss != null and boss.phase >= 2 and boss.adds.size() >= int(Tuning.data.boss_adds_count)


# --- The rear warning, every archetype --------------------------------------------------------


## The AI frozen, the player's look fixed down the street, god mode: each archetype is placed at
## its strike range, behind-left, behind-right and directly behind, and winds up (force_attack) in
## turn. The warning's corner is judged from the first frame of each wind-up to its contact:
## WARN-CHECK per wind-up, the heavies' (Bruiser, boss) larger burst, `W+`/`W-` lines.
static func _warn_every_archetype(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	await bot._look_to(0.0, 6)
	for attack: Array in WARN_ATTACKS:
		for bearing: float in WARN_BEARINGS:
			var enemy: EnemyActor = bot.spawn(attack[0], SliceActs.rel_at(bearing, attack[2]))
			await bot._ticks(24)
			enemy.force_attack(attack[1])
			await bot._wait_until(func() -> bool: return enemy.state == CombatTypes.ActorState.WINDUP, 30)
			await bot._wait_until(func() -> bool: return enemy.current_move == null, 300)
			await bot._ticks(30)
			bot.clear_enemies()
			# The next one starts when he is on his feet again (a knockdown takes a second or two).
			await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.FREE, 240)
			await bot._ticks(20)


# --- Perf -------------------------------------------------------------------------------------


## Six enemies and a player who knocks them down (the autopilot, not held back; a Punk walks in
## whenever one falls), god mode. From before the first spawn to the end, wall-clock frame times
## (between two `process_frame`s) are logged:
##   PERF f<frame> window <n>: <frames> frames, mean <ms>, p95 <ms>, worst <ms>, process <ms>, physics <ms>, <n> bodies, <n> alive
## in windows of PERF_WINDOW_FRAMES, the whole run, one line per enemy that appeared
## (`PERF spawn <name>: ...`: its own frame and the worst frame within PERF_AFTER_S of it) and the
## worst frame within PERF_AFTER_S of a body going down (a ragdoll build). The probe's R15 is the same
## run's (frame p95 with its own cost taken out, the worst frame after a spawn). Wall-clock times, so
## it needs a window that is not recording:
##   godot --path . res://tests/bot/crowd_bot.tscn -- --act="Perf, six with ragdolls"
## "process" and "physics" are the engine's own monitors for the last frame and include the probe's
## and the bot's work (the lens sampling takes 7 ms every tenth tick); the frame lines are the
## measure.
static func _perf(bot: Node) -> void:
	bot.god()
	var run := {running = true, ms = PackedFloat32Array(), stamp = PackedFloat64Array(), spawns = [], downs = PackedFloat64Array()}
	_sample_frames(bot, run)  # a coroutine of its own: it runs beside the act until `running` is cleared
	await _mixed_six(bot)
	bot.keep_alive(6)
	bot.pilot.enabled = true
	await bot._ticks(PERF_TICKS)
	run.running = false
	await bot.get_tree().process_frame
	await bot.get_tree().process_frame
	_report_perf(bot, run)


## Collect the frame times and the moments enemies appear and go down into `run`, one entry per
## process frame, until `run.running` is false.
static func _sample_frames(bot: Node, run: Dictionary) -> void:
	var tree: SceneTree = bot.get_tree()
	var known: Dictionary = {}
	var was_down: Dictionary = {}
	var last := Time.get_ticks_usec()
	while run.running:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		run.ms.append(float(now - last) / 1000.0)
		run.stamp.append(float(now) / 1000000.0)
		last = now
		for node: Node in tree.get_nodes_in_group(&"ai_enemy"):
			var enemy := node as EnemyActor
			if enemy == null:
				continue
			var id := enemy.get_instance_id()
			if not known.has(id):
				known[id] = true
				run.spawns.append([float(now) / 1000000.0, String(enemy.name)])
			var down := enemy.state in DOWN_STATES or enemy.health <= 0.0
			if down and not was_down.get(id, false):
				run.downs.append(float(now) / 1000000.0)
			was_down[id] = down
		if run.ms.size() % PERF_WINDOW_FRAMES == 0:
			_log_window(bot, "window %d" % (run.ms.size() / PERF_WINDOW_FRAMES), run.ms.slice(run.ms.size() - PERF_WINDOW_FRAMES))


## The worst frame (ms) of `run` within PERF_AFTER_S after `stamp` (s).
static func _worst_after(run: Dictionary, stamp: float) -> float:
	var worst := 0.0
	for i in run.stamp.size():
		if run.stamp[i] >= stamp and run.stamp[i] <= stamp + PERF_AFTER_S:
			worst = maxf(worst, run.ms[i])
	return worst


static func _report_perf(bot: Node, run: Dictionary) -> void:
	_log_window(bot, "whole run", run.ms)
	var worst_spawn := 0.0
	for entry: Array in run.spawns:
		var worst := _worst_after(run, entry[0])
		worst_spawn = maxf(worst_spawn, worst)
		bot.log_line("PERF spawn %s: worst frame within %.1f s %.1f ms" % [entry[1], PERF_AFTER_S, worst])
	var worst_down := 0.0
	var first_down := -1.0
	for stamp in run.downs:
		var worst := _worst_after(run, stamp)
		worst_down = maxf(worst_down, worst)
		if first_down < 0.0:
			first_down = worst
	bot.log_line("PERF %d spawns, worst frame after one %.1f ms; %d bodies went down, worst frame within %.1f s of one %.1f ms, of the first %.1f ms" % [
			run.spawns.size(), worst_spawn, run.downs.size(), PERF_AFTER_S, worst_down, maxf(first_down, 0.0)])


## Log the frame times `ms` of one window (or the run): mean, p95 and worst, with the engine's own
## process and physics times and the active physics bodies (the ragdolls' bodies count).
static func _log_window(bot: Node, label: String, ms: PackedFloat32Array) -> void:
	var sorted := ms.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in ms:
		sum += value
	var p95 := sorted[mini(int(floor(0.95 * (sorted.size() - 1))), sorted.size() - 1)]
	bot.log_line("PERF f%d %s: %d frames, mean %.1f, p95 %.1f, worst %.1f, process %.1f, physics %.1f, %d bodies, %d alive" % [
			Engine.get_physics_frames(), label, ms.size(), sum / maxf(float(ms.size()), 1.0), p95,
			sorted[sorted.size() - 1], 1000.0 * Performance.get_monitor(Performance.TIME_PROCESS),
			1000.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), bot.spawner.alive_count()])
