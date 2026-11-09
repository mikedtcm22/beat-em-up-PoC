extends RefCounted
## LD-ART2's acts for the still stage (video/stage/still_bot.gd): the cast after Gate 2 (docs/video/P1.md, round 3), in the shots where it is
## judged. Each act is "Art2: <shot> art": the art piece, then the world look, then the ink look (the order of a shot), through LD-ASSET's
## own staging (video/acts/ld_asset_acts.gd), so the two files render the same way; one variant per process.
## The shots: LD-ASSET's (the Phase 0 stills fp_punk, ox_closeup and ox_low, and punk_close, punk_2m, ox_2m, fp_jab) plus ox_1m, Ox's
## face at about 1.1 m under the boss roof's fire, for the eyes under the headband.
## Environment (as LD-ASSET's): ART_SET "prop=value;..." overrides VideoArtLook values, INK_SET the ink look's, ART_TAG tags the PNG's name.

const BASE := preload("res://video/acts/ld_asset_acts.gd")
const OX_FACE_AT := Vector3(7.0, 0.0, -10.0)


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		out.append({
			title = "Art2: %s art" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await BASE.shoot(bot, shot, &"art", false),
		})
	return out


static func shots() -> Array[VideoStillShot]:
	var out := BASE.shots()
	out.append(own_shot(&"ox_1m"))
	return out


static func own_shot(key: StringName) -> VideoStillShot:
	var shot := BASE.own_shot(&"ox_2m")
	shot.key = key
	match key:
		&"ox_1m":
			shot.note = "Ox's face at about 1.7 m: the brow, the eyes under the headband, the hood."
			shot.actors = [BASE._actor(&"boss", OX_FACE_AT)]
			shot.cam_pos = Vector3(7.0, 1.95, -8.3)
			shot.cam_look_at = Vector3(7.0, 2.0, -10.0)
			shot.cam_fov_deg = 36.0
	return shot
