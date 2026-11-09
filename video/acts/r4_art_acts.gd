extends RefCounted
## R4-ART's acts for the still stage (video/stage/still_bot.gd), round 4 (docs/video/P1.md): the cast's close shots, rendered through LD-ART2's own
## staging (video/acts/ld_art2_acts.gd), so the two files render the same way. Each act is "R4Art: <shot> art". The shots are LD-ART2's, plus the
## first-person shots at the narrower lens R4-SHOTS moves to (75 degrees across, from the game's 90): fp_punk_75 and fp_kicker_lamp_75, which are
## the stills with `first_person_fov_deg` set (not kept as files: the stills dir is the stage's and its tests count it; to render one as a shot, copy the still
## with `first_person_fov_deg = 75.0` and a new key to a scratch scene in video/shots/ for the run).
## Environment as LD-ASSET's: ART_SET "prop=value;..." overrides VideoArtLook values, INK_SET the ink look's, ART_TAG tags the PNG's name.

const BASE := preload("res://video/acts/ld_art2_acts.gd")
const FOV_75: Array[StringName] = [&"fp_punk", &"fp_kicker_lamp"]


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		out.append({
			title = "R4Art: %s art" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await BASE.BASE.shoot(bot, shot, &"art", false),
		})
	return out


static func shots() -> Array[VideoStillShot]:
	var out: Array[VideoStillShot] = []
	for shot in BASE.shots():
		out.append(shot)
		if FOV_75.has(shot.key):
			var narrow := shot.duplicate() as VideoStillShot
			narrow.key = StringName("%s_75" % shot.key)
			narrow.first_person_fov_deg = 75.0
			out.append(narrow)
	return out
