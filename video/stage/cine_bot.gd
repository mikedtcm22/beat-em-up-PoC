extends "res://video/stage/still_bot.gd"
## The cine stage's bot (P1.md, LD-STAGE): the still bot's harness (the level, the scripted player, the staging) running ONE shot, the
## one its scene names, through the cine stage: the CineDirector applies the location's look pieces (art, world, ink), hides the HUD
## and seeds the rngs; a free-camera shot gets a CineCamera; the frame writer (CineFrameWriter) keeps the 24 fps picks of
## the shot's window as a 2560x1440 mezzanine plus the character mask. A VideoStillShot plays as a one-frame shot.
## A shot scene (`res://video/shots/<key>.tscn`) is a bare Node with this script and its shot. Run one with tools/video/shoot.sh,
## or by hand:
##   godot --path . --fixed-fps 60 --resolution 480x270 res://video/shots/<key>.tscn -- --level=res://game/level/mission1/mission1.tscn \
##     --still-out=<abs dir>
## Arguments after `--`, besides the level bot's and the still bot's: `--shot-skip=<piece file>[,...]` leaves pieces out (ink.tres, world.tres,
## art.tres: an A/B), `--shot-set=ink.tres.post_enabled=false;...` sets piece properties for the run (GDScript literals),
## `--shot-to=<seconds>` ends the window early (a quick look), `--shot-from=<seconds>` starts it later,
## `--shot-repeat=N` captures a still N more times,
## `--shot-mask=0` writes no mask, `--shot-store=png` stores PNGs (not a raw chunk) for the encode, `--shot-window=0` stops the main window drawing, `--shot-tag=<text>` appends to the output name.

const DEFAULT_LEVEL_PATH := "res://game/level/mission1/mission1.tscn"

## The shot this scene plays (a VideoStillShot of video/stills/, or a CineShot of video/shots/).
@export var shot: VideoStillShot

var cine: CineDirector
var writer: CineFrameWriter
## Pieces left out (`--shot-skip=`).
var skip_pieces: PackedStringArray = PackedStringArray()
## Piece properties set for the run (`--shot-set=`).
var set_pieces: Dictionary = {}
var _to_override: float = -1.0
var _from_override: float = -1.0
var _mask: bool = true
## `--shot-repeat=N`: a still is captured N more times without the game moving (a determinism probe of the renderer).
var _repeat: int = 0
var _store_png: bool = false
var _window: bool = true
var _tag: String = ""
var _beat_ticks: Array[int] = []
var _beats: Array[CineBeat] = []
var _next_beat: int = 0
var _turn: Dictionary = {}
var _pitch: Dictionary = {}


func _ready() -> void:
	level_path = DEFAULT_LEVEL_PATH
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-skip="):
			skip_pieces = PackedStringArray(arg.trim_prefix("--shot-skip=").split(",", false))
		elif arg.begins_with("--shot-set="):
			# "ink.tres.post_enabled=false;world.tres.paint_x=0.5": GDScript literals, ';' between.
			for pair in arg.trim_prefix("--shot-set=").split(";", false):
				var parts := pair.split("=", true, 1)
				if parts.size() == 2:
					set_pieces[parts[0]] = str_to_var(parts[1])
		elif arg.begins_with("--shot-repeat="):
			_repeat = int(arg.trim_prefix("--shot-repeat="))
		elif arg.begins_with("--shot-to="):
			_to_override = float(arg.trim_prefix("--shot-to="))
		elif arg.begins_with("--shot-from="):
			_from_override = float(arg.trim_prefix("--shot-from="))
		elif arg == "--shot-store=png":
			_store_png = true
		elif arg == "--shot-mask=0":
			_mask = false
		elif arg == "--shot-window=0":
			_window = false
		elif arg.begins_with("--shot-tag="):
			_tag = arg.trim_prefix("--shot-tag=")
	super._ready()


func _run() -> void:
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after the room's _ready()
	player = room.get(&"player")
	player.input.scripted = true
	spawner = room.get(&"spawner")
	director = get_tree().get_first_node_in_group(&"camera_director")
	AudioServer.set_bus_mute(0, true)
	cine = CineDirector.new()
	cine.name = "CineDirector"
	add_child(cine)
	writer = CineFrameWriter.new()
	writer.name = "CineFrameWriter"
	writer.write_mask = _mask
	writer.store_png = _store_png
	writer.show_window = _window
	add_child(writer)
	grab = writer
	if shot == null:
		push_error("cine_bot: the scene names no shot")
		await _quit()
		return
	await _reset(&"first_person" if shot.first_person else &"free_fly")
	cine.direct(level, shot, skip_pieces, set_pieces)
	stage_lamps = not cine.has_world_piece()
	var run_name := "%s%s" % [shot.key, _tag]
	print("=== Shot %s  location %s  pieces %s  (f%d)" % [shot.key, cine.location, _piece_names(), Engine.get_physics_frames()])
	writer.warm_up(true)
	await stage(shot)
	var moving := shot is CineShot and ((shot as CineShot).window_to_s > (shot as CineShot).window_from_s or _to_override >= 0.0)
	writer.begin(out_dir, run_name, not moving and _repeat == 0)
	cine.start_clock()
	_hook_ink_rig()
	if moving:
		await _play(shot as CineShot)
	else:
		await writer.capture_frame(writer.settle_frames)
		for _i in _repeat:
			await writer.capture_frame()
	var stats := writer.finish()
	log_line("SHOT %s frames=%d s/frame=%.2f raw_mb/frame=%.2f mezz_mb/frame=%.3f problems=%d" % [run_name, stats.frames,
			stats.seconds_per_frame, stats.png_mb_per_frame, stats.mezzanine_mb_per_frame, stats.problems.size()])
	Engine.time_scale = 1.0
	cine.restore()
	await _quit()


## A free camera shot's camera: the director's, from the shot's keys, following the staged actors.
func _place_free_camera(p_shot: VideoStillShot, base: Vector3, _viewer: Vector3) -> void:
	var actors: Array[Node3D] = []
	for actor in _stage_actors:
		actors.append(actor as Node3D)
	cine.shot = p_shot
	cine.build_camera(base, actors)


## Play a moving shot: the beats on the shot clock, the camera along its path, a frame written on each pick of the window.
func _play(moving: CineShot) -> void:
	var sim := Engine.physics_ticks_per_second
	var from_s := _from_override if _from_override >= 0.0 else moving.window_from_s
	var to_s := _to_override if _to_override >= 0.0 else moving.window_to_s
	var first := int(roundf(from_s * float(sim)))
	# The window is [from, to): 5 s is 120 picks, not 121.
	var last := maxi(int(roundf(to_s * float(sim))) - 1, first)
	_beats = moving.beats.duplicate()
	_beats.sort_custom(func(a: CineBeat, b: CineBeat) -> bool: return a.at_s < b.at_s)
	_beat_ticks.clear()
	for beat in _beats:
		_beat_ticks.append(int(roundf(beat.at_s * float(sim))))
	_next_beat = 0
	var picked := 0
	for tick in range(0, last + 1):
		if tick > 0:
			await _ticks(1)
		_run_beats(tick)
		_step_turns()
		if CineFrameWriter.is_pick(tick, first, sim, writer.out_fps):
			await writer.capture_frame()
			picked += 1
	log_line("SHOT window ticks %d..%d, %d frames" % [first, last, picked])


func _run_beats(tick: int) -> void:
	while _next_beat < _beats.size() and _beat_ticks[_next_beat] <= tick:
		var beat := _beats[_next_beat]
		_next_beat += 1
		match beat.kind:
			CineBeat.Kind.PRESS:
				player.input.push_press(beat.button, beat.hold_ticks)
			CineBeat.Kind.DOWN:
				player.input.push_down(beat.button)
			CineBeat.Kind.UP:
				player.input.push_up(beat.button)
			CineBeat.Kind.MOVE:
				player.input.scripted_move = beat.stick
			CineBeat.Kind.TURN:
				_turn = {from = player.look_yaw, by = deg_to_rad(beat.degrees), start = tick,
						ticks = maxi(int(roundf(beat.seconds * float(Engine.physics_ticks_per_second))), 1)}
			CineBeat.Kind.PITCH:
				_pitch = {from = player.look_pitch, to = deg_to_rad(beat.degrees), start = tick,
						ticks = maxi(int(roundf(beat.seconds * float(Engine.physics_ticks_per_second))), 1)}
			CineBeat.Kind.SLOWMO:
				TimeController.slowmo(beat.time_scale, beat.seconds)


## Advance a running turn or tilt of the view by one tick (evenly, like the bots' _turn_by()).
func _step_turns() -> void:
	var now := cine.clock_ticks()
	if not _turn.is_empty():
		var u := clampf(float(now - int(_turn.start)) / float(_turn.ticks), 0.0, 1.0)
		var yaw := wrapf(float(_turn.from) + float(_turn.by) * u, -PI, PI)
		player.look_yaw = yaw
		if u >= 1.0:
			_turn = {}
	if not _pitch.is_empty():
		var u := clampf(float(now - int(_pitch.start)) / float(_pitch.ticks), 0.0, 1.0)
		player.look_pitch = lerpf(float(_pitch.from), float(_pitch.to), u)
		if u >= 1.0:
			_pitch = {}


## The ink rig's frame counter is the shot clock's output frame, so the on-twos holds and the line boil match the writer's picks.
func _hook_ink_rig() -> void:
	var rig := level.get_node_or_null(^"CineInkRig") as CineInkRig
	if rig != null:
		rig.frame_source = func() -> int: return writer.current_output_index(cine.clock_ticks())


func _piece_names() -> String:
	var names := PackedStringArray()
	for piece in cine.pieces:
		names.append(piece.get_script().get_global_name())
	return ",".join(names)
