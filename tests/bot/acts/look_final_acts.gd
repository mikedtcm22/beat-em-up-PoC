extends RefCounted
## The final look probe of Milestone 4 (P3-int): Part B's windowed rows L1, L2, L3 and L5 on the shipped art in ONE window, into one
## look.json the lead can paste. It adds no measurement of its own: it plays, in one process and in this order, the acts that
## already measure the rows, and then reads what they recorded (tests/bot/look_probe.gd final_rows()):
##
## | Row | Measured by | Act |
## | L1, hull width at 1, 2.5, 5 and 10 m | F-look's T3 | Look: tune hull widths |
## | L1, the player's own body (x fp scale) | F-look's T8 | Look: tune own hull |
## | L2, the jacket's bands at 1 m | F-look's T1 | Look: tune bands at 1 m |
## | L3, the white share of the view on a jab at 1 m | F-look's T5 | Look: tune jab flash |
## | L5, R4 and R8 with the art drawn beside the proxies | P3-early's L5 | Look: readability with the art drawn |
##
## Record it once, windowed (Movie Maker), and read look.json beside the recording:
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/final "Look: final probe" 6
## The rows are in look.json under "final" (each a state, a text line and the numbers), beside the acts' own slugs (t1, t3, t5, t8),
## and in the log as `LOOK-FINAL <row> <MET|MISSED|NOT MEASURED> ...`. Headless the acts draw nothing, so nothing is measured and the
## rows read "not measured" (tests/test_look_acts.gd plays it that way).
##
## L4 (perf) is the lead's `tools/perf_compare.sh` run, not this probe's.

const LookProbe := preload("res://tests/bot/look_probe.gd")

## The acts that measure the rows, by title, in the order they are played. The crowd bot's own act list is read at run time (an
## act file is found by its name, tests/bot/crowd_bot.gd), so a renamed act is a missing one: it is logged and its row reads
## "not measured".
const SOURCES: Array[String] = [
	"Look: tune hull widths",
	"Look: tune own hull",
	"Look: tune bands at 1 m",
	"Look: tune jab flash",
	"Look: readability with the art drawn",
]
## Ticks of the bot's own idle tail after each act, as the crowd bot leaves between acts.
const TAIL_TICKS := 45


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: final probe", cam = &"first_person", slug = &"fp", fn = func() -> void: await _final(bot)},
	]


## Play the source acts in one window, then record the rows.
static func _final(bot: Node) -> void:
	bot.caption.visible = true
	var by_title := {}
	for act: Dictionary in bot._collect_acts():
		by_title[act.title] = act
	var played := 0
	for title: String in SOURCES:
		var act: Dictionary = by_title.get(title, {})
		if act.is_empty():
			bot.log_line("LOOK-FINAL missing act '%s'" % title)
			continue
		await bot._reset(act.cam)
		bot.caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await bot._wait_idle()
		await bot._ticks(TAIL_TICKS)
		played += 1
	bot.caption.text = "Look: final probe"
	var tint := Tuning.data.look_shadow_tint
	var l5_lines := PackedStringArray()
	for line: String in bot.log_lines:
		if line.begins_with("LOOK-L5 "):
			l5_lines.append(line)
	var rows := LookProbe.final_rows(LookProbe.read(), l5_lines, Tuning.data.look_outline_px, Tuning.data.look_outline_fp_scale, tint.h * 360.0)
	rows["acts_played"] = played
	rows["outline_px"] = Tuning.data.look_outline_px
	rows["outline_fp_scale"] = Tuning.data.look_outline_fp_scale
	rows["punk_art_variant"] = Tuning.data.look_punk_art_variant
	for line: String in LookProbe.final_lines(rows):
		bot.log_line(line)
	LookProbe.record(LookProbe.FINAL_KEY, rows)
