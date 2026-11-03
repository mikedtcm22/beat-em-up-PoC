extends RefCounted
## The attack-arc acts of Milestone 5 (ARC) for the crowd bot (tests/bot/crowd_bot.gd), in first person,
## each with the readability probe on (a READABILITY summary and readability.json beside the recording).
## Record them with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Arcs:" 6
## "Arcs: six Punks": god mode, six Punks walk in from all round him and he stands still: a front line of
## three squares up in front of him and three wait behind them, back from the fray. "Arcs: turn your
## back": three Punks square up, he waits out their grace, and quick-turns: the Punks are behind him now
## and their wind-ups come from there, with the rear warning. "Arcs: mixed six": a Punk, a Punk, a Thug, a
## Bruiser, a Kicker and a veteran Punk (the 140 degree variant), the held-back autopilot fights for 30 s
## (compare "Mixed six, fight" before the arcs: the Punks stand in front, only the Kicker circles
## behind). "Arcs: quick turns": three Punks, and he flips the look left and right every few frames for
## 4 s: nobody is stalled, the lines they commit to are where the look was when each engaged.

## The mixed six of the arc acts, in the order they walk in (the plan's make-up).
const MIXED_ARCS: Array[StringName] = [&"punk", &"punk", &"thug", &"bruiser", &"kicker", &"punk_veteran"]
## Frames between two enemies walking in, and how long a standing player is watched (ticks, 15 s).
const SPAWN_GAP_FRAMES := 12
const WATCH_TICKS := 900
## "Turn your back": the wait before the turn (ticks: the Punks walk in, engage, commit and take their
## seats), the turn's length (ticks) and the watch after it.
const BACK_WAIT_TICKS := 300
const BACK_TURN_TICKS := 8
const BACK_WATCH_TICKS := 420
## "Mixed six": the autopilot fights this long (ticks, 30 s).
const FIGHT_TICKS := 1800
## "Quick turns": how many Punks, the turn's swing (degrees) and the ticks between two turns, how long
## it goes on and how long he then stands still (ticks).
const QUICK_PUNKS := 3
const QUICK_SWING_DEG := 100.0
const QUICK_GAP_TICKS := 10
const QUICK_TURNS := 24
const QUICK_WATCH_TICKS := 300


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Arcs: six Punks", cam = &"first_person", probe = true, fn = func() -> void: await _six_punks(bot)},
		{title = "Arcs: turn your back", cam = &"first_person", probe = true, fn = func() -> void: await _turn_your_back(bot)},
		{title = "Arcs: mixed six", cam = &"first_person", probe = true, fn = func() -> void: await _mixed_six(bot)},
		{title = "Arcs: quick turns", cam = &"first_person", probe = true, fn = func() -> void: await _quick_turns(bot)},
	]


## God mode, six Punks walk in from all round, he stands still facing +X.
static func _six_punks(bot: Node) -> void:
	bot.god()
	await bot.surround(6, SPAWN_GAP_FRAMES)
	await bot._ticks(WATCH_TICKS)


## Three Punks walk in and square up; after their grace and a wait he quick-turns round, so they stand
## behind him and attack from there.
static func _turn_your_back(bot: Node) -> void:
	bot.god()
	await bot.surround(3, SPAWN_GAP_FRAMES)
	await bot._ticks(BACK_WAIT_TICKS)
	bot.log_line("ARC turn your back f%d" % Engine.get_physics_frames())
	await bot._turn_by(180.0, BACK_TURN_TICKS)
	await bot._ticks(BACK_WATCH_TICKS)


## The mix of the arcs, the held-back autopilot for 30 s.
static func _mixed_six(bot: Node) -> void:
	bot.god()
	for i in MIXED_ARCS.size():
		bot.spawn_at_point(MIXED_ARCS[i], bot.SURROUND_POINTS[i])
		await bot._ticks(SPAWN_GAP_FRAMES)
	bot.keep_alive(6)
	await bot.fight(FIGHT_TICKS)


## He flips the look left and right every few ticks while three Punks come in: a quick turn never
## stalls them (the line follows the look only for the half-second after each engages).
static func _quick_turns(bot: Node) -> void:
	bot.god()
	await bot.surround(QUICK_PUNKS, SPAWN_GAP_FRAMES)
	var side := 1.0
	for i in QUICK_TURNS:
		await bot._turn_by(side * QUICK_SWING_DEG, 4)
		side = -side
		await bot._ticks(QUICK_GAP_TICKS)
	await bot._ticks(QUICK_WATCH_TICKS)
