extends RefCounted
## SHOTS' acts for the still bot (video/stage/still_bot.gd): "Trailer: <key>" stages each shot of the trailer's list (PLAN.md §5, the
## `t01..t14` shots of `res://video/shots/`) at its first frame, in its location's look, and writes `<out dir>/<key>.png`: the quick look at a
## shot's staging, and the one place the list's order, durations and the shots' edit data are read together (`cut_list()`).
## The shots play for real through tools/video/shoot.sh (the cine bot, `video/stage/cine_bot.gd`): every shot's run writes its cue sheet, `<key>_events.log`
## (each hit, block, grab, throw, fall and button beat with its tick on the shot clock and the video frame it lands on, for the sound), and
## tools/video/shoot_trailer.sh runs the list.

const SHOTS_DIR := "res://video/shots"
## The blind set's seven hero frames (round 5): each entry has the shot `key`, the output `frame` (24 fps, counted from the window's start), its `kind` and a `note`.
const HERO_FRAMES_PATH := "res://video/shots/hero_frames.json"


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		out.append({
			title = "Trailer: %s" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await _stage(bot, shot),
		})
	return out


## The trailer's shots, in the list's order (by number).
static func shots() -> Array[CineShot]:
	var out: Array[CineShot] = []
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(SHOTS_DIR):
		var name := file.trim_suffix(".remap")
		if name.begins_with("t") and name.ends_with(".tres") and name.substr(1, 2).is_valid_int():
			files.append(name)
	files.sort()
	for file in files:
		var shot := load(SHOTS_DIR.path_join(file)) as CineShot
		if shot != null:
			out.append(shot)
	out.sort_custom(func(a: CineShot, b: CineShot) -> bool: return a.number < b.number)
	return out


## The hero frames (R5-SHOTS), each {key, frame, kind, note}: the frames the plates are made for and the blind check shows.
static func hero_frames() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HERO_FRAMES_PATH))
	if parsed is Dictionary:
		for entry: Variant in (parsed as Dictionary).get("frames", []):
			if entry is Dictionary:
				out.append(entry as Dictionary)
	return out


## One line a shot for the animatic's cut list: number, key, where it starts in the edit, its length in seconds, the speed it is cut at and the camera.
static func cut_list() -> PackedStringArray:
	var out := PackedStringArray()
	for shot in shots():
		out.append("%02d %s start=%.1f len=%.2f speed=%.2f %s %s" % [shot.number, shot.key, shot.edit_start_s,
				shot.window_to_s - shot.window_from_s, shot.edit_speed, shot.location_name(), "FP" if shot.first_person else "cine"])
	return out


static func _stage(bot: Node, shot: CineShot) -> void:
	var director := CineDirector.new()
	bot.add_child(director)
	director.direct(bot.get(&"level"), shot)
	var own := shot.duplicate() as CineShot
	if director.has_world_piece():
		own.lamp_posts = PackedVector3Array()
	await bot.shoot(own)
	director.restore()
	director.queue_free()
