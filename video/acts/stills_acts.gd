extends RefCounted
## The Gate 1 stills (Phase 0): one act per `res://video/stills/*.tres` (a VideoStillShot), in file name order.
## "Still: <key>" stages the shot and writes `<out dir>/<key>.png` at 2560x1440. The placements are data.

const SHOTS_DIR := "res://video/stills"


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		out.append({
			title = "Still: %s" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await bot.shoot(shot),
		})
	return out


## Every shot of the stills directory, in file name order.
static func shots() -> Array[VideoStillShot]:
	var out: Array[VideoStillShot] = []
	var dir := DirAccess.open(SHOTS_DIR)
	if dir == null:
		return out
	var files := PackedStringArray()
	for file in dir.get_files():
		if file.ends_with(".tres"):
			files.append(file)
	files.sort()
	for file in files:
		var shot := load(SHOTS_DIR.path_join(file)) as VideoStillShot
		if shot != null:
			out.append(shot)
	return out
