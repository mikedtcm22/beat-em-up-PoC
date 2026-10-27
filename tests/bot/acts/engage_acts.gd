extends RefCounted
## The engage acts (P1-engage): the slice's six-Punk acts again with the engage meter on, so the
## wait of a token holder at the player's nose and the lens coverage by cause are printed as a
## METER line next to the probe's summary. The acts are the slice's own (same names, seeds and
## slots; the meter only reads), so a run's R1-R15 equals the slice act's. They exist only when
## the act filter asks for them by name ("Engage"), so a run of every act does not repeat them.
##
##   godot --path . --headless res://tests/bot/crowd_bot.tscn -- --act="Engage: observed" --seed=0
##
## Acts: "Engage: observed", "Engage: passive", "Engage: fight", "Engage: waves", "Engage: blind spot".

const Slice := preload("res://tests/bot/acts/slice_acts.gd")
const Meter := preload("res://tests/bot/engage_meter.gd")


static func acts(bot: Node) -> Array[Dictionary]:
	if not bot.act_filter.to_lower().contains("engage"):
		return []
	return [
		{title = "Engage: observed", cam = &"first_person", probe = true,
				fn = func() -> void: await _metered(bot, "Engage: observed", Slice._observed)},
		{title = "Engage: passive", cam = &"first_person", probe = true, tags = {passive = true},
				fn = func() -> void: await _metered(bot, "Engage: passive", Slice._passive)},
		{title = "Engage: fight", cam = &"first_person", probe = true,
				fn = func() -> void: await _metered(bot, "Engage: fight", Slice._fight_six)},
		{title = "Engage: waves", cam = &"first_person", probe = true,
				fn = func() -> void: await _metered(bot, "Engage: waves", Slice._waves)},
		{title = "Engage: blind spot", cam = &"first_person", probe = true,
				fn = func() -> void: await _metered(bot, "Engage: blind spot", Slice._blind_spot)},
	]


## Run the slice act `act` (a static func taking the bot) with a meter attached; print its line.
static func _metered(bot: Node, title: String, act: Callable) -> void:
	var meter := Meter.new()
	meter.debug = OS.get_environment("ENGAGE_DEBUG") != ""
	meter.attach(bot, bot.player)
	await act.call(bot)
	bot.log_line(meter.report(title))
	meter.queue_free()
