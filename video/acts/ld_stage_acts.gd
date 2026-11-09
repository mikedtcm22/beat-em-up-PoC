extends RefCounted
## LD-STAGE's acts for the still bot (video/stage/still_bot.gd): "Stage: <key>" stages each cine shot of `res://video/shots/*.tres` at its first frame
## (a moving shot's start: the first key of a camera path, the player at the start) with its location's look pieces applied by the CineDirector, and
## writes `<out dir>/<key>.png` through the still stage's own grab. It is the quick look at a shot's staging; tools/video/shoot.sh renders the whole shot
## (the scenes of `res://video/shots/*.tscn`, with the frame writer).

const SHOTS_DIR := "res://video/shots"


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		out.append({
			title = "Stage: %s" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await _shoot(bot, shot),
		})
	return out


## The cine shots of the shots directory, in file name order.
static func shots() -> Array[CineShot]:
	var out: Array[CineShot] = []
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(SHOTS_DIR):
		if file.ends_with(".tres"):
			files.append(file)
	files.sort()
	for file in files:
		var shot := load(SHOTS_DIR.path_join(file)) as CineShot
		if shot != null:
			out.append(shot)
	return out


static func _shoot(bot: Node, shot: CineShot) -> void:
	var director := CineDirector.new()
	bot.add_child(director)
	director.direct(bot.get(&"level"), shot)
	var own := shot.duplicate() as CineShot
	if director.has_world_piece():
		own.lamp_posts = PackedVector3Array()
	await bot.shoot(own)
	director.restore()
	director.queue_free()
