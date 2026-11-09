extends RefCounted
## R5-ART's acts for the still stage (video/stage/still_bot.gd), round 5 (docs/video/P1.md): the back-lit cast in the shots R5-ART is judged on, rendered
## through LD-ART2's own staging (video/acts/ld_art2_acts.gd), so this file and the R4-ART acts render the same way. Each act is "R5Art: <shot> art".
## Environment as LD-ASSET's: ART_SET "prop=value;..." overrides VideoArtLook values (the `sil_*` ones included), INK_SET the ink look's, ART_TAG tags the PNG's name.

const BASE := preload("res://video/acts/ld_art2_acts.gd")
const SHOTS: Array[StringName] = [&"fp_punk", &"ox_closeup", &"ox_low", &"roof_silhouette"]


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		out.append({
			title = "R5Art: %s art" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await BASE.BASE.shoot(bot, shot, &"art", false),
		})
	return out


static func shots() -> Array[VideoStillShot]:
	var out: Array[VideoStillShot] = []
	for shot in BASE.shots():
		if SHOTS.has(shot.key):
			out.append(shot)
	return out
