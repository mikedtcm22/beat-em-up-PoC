extends RefCounted
## R4-WORLD's stills (round 4: light and atmosphere drawn as shapes, the darks as masses): the six Phase 0 shots with the round 4 world look of their location over the
## game's toon characters, through the stills stage. "R4World: <key>" applies `res://video/look/<location>/world.tres`, then shoots the shot with the stage's own lamp posts
## left out (the look places its own from data). The finished frames of the round come from tools/video/shoot.sh and tools/video/r4w_shoot.sh (the cine stage, with the art and
## ink pieces on); this act file is the quick look at the world piece alone. "R4WorldMotion: <key>" writes 12 consecutive frames while the camera moves (the swimming check).

const StillsActs := preload("res://video/acts/stills_acts.gd")
const World2Acts := preload("res://video/acts/ld_world2_acts.gd")


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in StillsActs.shots():
		out.append({
			title = "R4World: %s" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await World2Acts._shoot(bot, shot),
		})
	for shot in StillsActs.shots():
		if not shot.first_person:
			out.append({
				title = "R4WorldMotion: %s" % shot.key,
				cam = &"free_fly",
				fn = func() -> void: await World2Acts._motion(bot, shot),
			})
	return out
