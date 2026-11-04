extends RefCounted
## The roster's look acts (Milestone 6, CHAIN): one act per roster character (tests/art_roster.gd), "Look: <label> at 1 m", the
## character 1 m ahead of the player standing in its idle, seen first the way C1 shows the Punk (the view 8 degrees up) and then
## the way C2 does (6 degrees down). The same framing for every character, so a new character is judged against the Punk's frames
## in captures/m4/dm (C1, C2) with nothing else changed. A character added to tests/fixtures/art/roster/ gets its act with no edit
## here. Record one with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Dummy at 1 m" 6
## (the filter is a substring over every act's title: "Look: Punk at 1 m" also picks the Punk's long take, C14). The slug is
## `r_<id>`; the marks are LOOK-MARK <slug> f<frame> face_t000 ... body_t120 and end, with LOOK-RECT rectangles of the subject, as
## look_acts.gd prints them.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")
const Roster := preload("res://tests/art_roster.gd")
const DUMMY_SCENE := "res://game/enemies/dummy/training_dummy.tscn"
## How long each of the two views holds the idle, in ticks (a third of C1's and C2's three seconds is enough for a still).
const IDLE_TICKS := 120


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Roster.ids():
		var label := String(Roster.row(id).label)
		out.append({title = "Look: %s at 1 m" % label, cam = &"first_person", slug = StringName("r_%s" % id),
				fn = func() -> void: await _look(bot, id)})
	return out


## A body of roster character `id` 1 m ahead of the player, facing him: an enemy through the spawner, the training dummy (which is not an
## EnemyActor, so the spawner makes none) placed by hand as toon_acts.gd does.
static func _subject(bot: Node, id: String) -> CombatActor:
	if Roster.row(id).actor_scene == DUMMY_SCENE:
		var dummy := (load(DUMMY_SCENE) as PackedScene).instantiate() as TrainingDummy
		bot.room.add_child(dummy)
		var at: Vector3 = bot.player.global_position + bot.player.global_basis * Vector3(0.0, 0.0, -LookActs.CLOSE_M)
		var to_player: Vector3 = bot.player.global_position - at
		dummy.set_post(at, atan2(-to_player.x, -to_player.z), true)
		return dummy
	return bot.spawn(StringName(id), Vector2(0.0, LookActs.CLOSE_M))


static func _look(bot: Node, id: String) -> void:
	var slug := "r_%s" % id
	LookActs._begin(bot)
	var subject := _subject(bot, id)
	await bot._look_to(LookActs.FACE_PITCH_DEG, LookActs.PITCH_TICKS)
	await bot._ticks(LookActs.SETTLE_TICKS)
	LookRect.mark(bot, slug, "start")
	await LookActs._idle_marks(bot, slug, subject, IDLE_TICKS, "face")
	await bot._look_to(LookActs.DEFAULT_PITCH_DEG, LookActs.PITCH_TICKS)
	await bot._ticks(LookActs.SETTLE_TICKS)
	await LookActs._idle_marks(bot, slug, subject, IDLE_TICKS, "body")
	LookActs._end(bot, slug)
