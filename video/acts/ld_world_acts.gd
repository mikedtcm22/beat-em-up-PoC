extends RefCounted
## LD-WORLD's stills: the six Phase 0 shots (res://video/stills/*.tres) rendered with the world look of their location over the game's
## own toon characters. "World: <key>" applies `res://video/look/<location>/world.tres` (the shot's section picks the location), then
## shoots the shot through the stills stage with the stage's own lamp posts left out (the look places its own from data).
## Arguments after `--` (read here): `--world-edges` keeps the game's constant-width edge pass (off by default: the ink is LD-INK's, and the
## world's paint is judged without the game's ruler lines), `--world-look=<location>` forces a location's look for every shot.

## The location of each level section.
const StillsActs := preload("res://video/acts/stills_acts.gd")
const LOCATIONS: Array[StringName] = [&"street_night", &"roofs_dusk", &"boss_fire"]
const LOOK_PATH := "res://video/look/%s/world.tres"


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in StillsActs.shots():
		out.append({
			title = "World: %s" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await _shoot(bot, shot),
		})
	return out


## The look of `location`.
static func look_for(location: StringName) -> VideoWorldLook:
	return load(LOOK_PATH % location) as VideoWorldLook


static func _shoot(bot: Node, shot: VideoStillShot) -> void:
	var forced := ""
	var keep_edges := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world-look="):
			forced = arg.trim_prefix("--world-look=")
		elif arg == "--world-edges":
			keep_edges = true
	var location: StringName = StringName(forced) if forced != "" else LOCATIONS[shot.section]
	var look := look_for(location)
	var level: Node = bot.get(&"level")
	look.apply(level)
	if not keep_edges:
		for post in level.find_children("*", "LookPost", true, false):
			(post as LookPost).edge_quad().visible = false
	var own := shot.duplicate() as VideoStillShot
	own.lamp_posts = PackedVector3Array()
	await bot.shoot(own)
