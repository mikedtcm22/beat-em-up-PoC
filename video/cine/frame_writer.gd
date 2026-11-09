class_name CineFrameWriter
extends VideoStillGrab
## The frame writer of the cine stage (PLAN.md §6, LD-RENDER; P1.md, LD-STAGE). The game runs on at 60 Hz with `--fixed-fps 60`, so the
## simulation is the game's own, and this node writes only what the video keeps:
##  - the picture: a fixed 2560x1440 SubViewport (MSAA 4x) sharing the main viewport's World3D, its camera a copy of the game's
##    active camera (transform, FOV, cull mask, depth of field) after every game camera moved;
##  - the character mask: a second SubViewport on the same World3D that draws only the characters (their meshes carry the
##    extra render layer `MASK_LAYER` while a frame is captured) on a transparent background; its alpha is the mask the
##    ink, the on-twos hold and the matte passes composite with;
##  - only the 24 fps picks of the 60 fps ticks, never blended: tick t is written when floor(t*24/60) changes (the window's
##    first tick always), and only inside the shot's window; both SubViewports are disabled (`UPDATE_DISABLED`) on every
##    other tick. The main window's viewport (a small window: it only hosts the SubViewports) keeps drawing every tick, because
##    the GPU particles only simulate on frames some viewport draws them (`show_window`, on by default);
##  - the disk: the frames as raw RGB (or PNG with `store_png`) in a chunk file, encoded every `chunk_frames` frames to a part of
##    the mezzanine (ffmpeg libx264 -crf 8 -preset slow yuv444p, tagged BT.709; the mask as PNGs to lossless ffv1 gray), the chunk's
##    files deleted after each encode, the parts joined at the end (raw, because Godot's PNG save costs 0.75 s a frame);
##  - the numbers: seconds a frame and MB a frame, the SHA-256 of every frame's pixels (the determinism check compares them).
## A one-frame window (a still) keeps its PNG and encodes nothing.

## The extra render layer (layer 4) the characters carry for the mask camera.
const MASK_LAYER := 1 << 3

## The ticks and frames of the output: the simulation's rate (read at `begin`) and the video's.
@export_range(1, 120) var out_fps: int = 24
## The frames between two encodes (the PNGs of a chunk are deleted once it is encoded).
@export_range(10, 1000) var chunk_frames: int = 200
## The encode of the mezzanine.
@export_range(0, 30) var crf: int = 8
@export var preset: String = "slow"
@export var pixel_format: String = "yuv444p"
## Store the picture as PNGs (the encode reads them) instead of one raw RGB chunk file (the default: much faster, the same pixels).
@export var store_png: bool = false
## Write the character mask too.
@export var write_mask: bool = true
## Keep the main window's viewport rendering every tick (on by default: the GPU particles advance only on frames that
## some viewport draws them, so a skipped frame would slow the embers and the steam to the pick rate).
@export var show_window: bool = true
## The ffmpeg binary (the FFMPEG environment variable wins).
@export var ffmpeg: String = "ffmpeg"

var mask_viewport: SubViewport
var mask_camera: Camera3D
var out_dir: String = ""
var key: String = ""
## The frames written so far, and the SHA-256 lines of their pixels.
var frames_written: int = 0
var hashes: PackedStringArray = PackedStringArray()

var _sim_fps: int = 60
var _frames_dir: String = ""
var _parts: PackedStringArray = PackedStringArray()
var _mask_parts: PackedStringArray = PackedStringArray()
var _chunk_start: int = 0
var _png_bytes: int = 0
var _first_usec: int = 0
var _last_usec: int = 0
var _save_usec: int = 0
var _encode_usec: int = 0
var _pending: int = 0
var _single: bool = false
var _warm: bool = false
var _raw: FileAccess
var _problems: PackedStringArray = PackedStringArray()


func _ready() -> void:
	super._ready()
	mask_viewport = SubViewport.new()
	mask_viewport.size = size
	mask_viewport.own_world_3d = false
	mask_viewport.msaa_3d = msaa
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mask_viewport.transparent_bg = true
	mask_camera = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	mask_camera.environment = env
	# A camera of its own compositor: the finish pass (grain, vignette) never reaches the mask.
	mask_camera.compositor = Compositor.new()
	mask_camera.cull_mask = MASK_LAYER
	mask_viewport.add_child(mask_camera)
	add_child(mask_viewport)
	mask_camera.make_current()
	_sim_fps = Engine.physics_ticks_per_second


# --- which ticks are written ---------------------------------------------------------------


## The output frame a tick belongs to: floor(tick * out_fps / sim_fps). The shot clock's tick, not the window's.
static func output_index(tick: int, sim_fps: int, fps: int) -> int:
	return int(floorf(float(tick) * float(fps) / float(sim_fps)))


## True when tick `tick` is written: the window's first tick, and each tick where the output index changes.
static func is_pick(tick: int, window_first_tick: int, sim_fps: int, fps: int) -> bool:
	if tick < window_first_tick:
		return false
	return tick == window_first_tick or output_index(tick, sim_fps, fps) != output_index(tick - 1, sim_fps, fps)


## The ticks of [first_tick, last_tick] that are written, in order.
static func picks(first_tick: int, last_tick: int, sim_fps: int, fps: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tick in range(first_tick, last_tick + 1):
		if is_pick(tick, first_tick, sim_fps, fps):
			out.append(tick)
	return out


## The output index the shot clock is at now (the ink rig's frame counter reads it: its on-twos hold and its boil).
func current_output_index(clock_ticks: int) -> int:
	return output_index(clock_ticks, _sim_fps, out_fps)


# --- running --------------------------------------------------------------------------------


## Start writing into `p_out_dir` (an absolute directory) under the name `p_key`.
## `single`: a one-frame window (a still), kept as a PNG.
func begin(p_out_dir: String, p_key: String, single: bool = false) -> void:
	_single = single
	out_dir = p_out_dir
	key = p_key
	_sim_fps = Engine.physics_ticks_per_second
	_frames_dir = out_dir.path_join("frames_%s" % key)
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	frames_written = 0
	hashes.clear()
	_parts.clear()
	_mask_parts.clear()
	_chunk_start = 0
	_png_bytes = 0
	_first_usec = 0
	_save_usec = 0
	_encode_usec = 0
	_problems.clear()
	var from_env := OS.get_environment("FFMPEG")
	if from_env != "":
		ffmpeg = from_env
	set_window_enabled(show_window)
	warm_up(false)


## The main window's viewport on or off. Off, the window draws nothing; the SubViewports still do.
func set_window_enabled(on: bool) -> void:
	var mode := RenderingServer.VIEWPORT_UPDATE_ALWAYS if on else RenderingServer.VIEWPORT_UPDATE_DISABLED
	RenderingServer.viewport_set_update_mode(get_tree().root.get_viewport_rid(), mode)


## Draw both SubViewports every frame (on) or only when asked (off). Warm them up through the staging: the first draw of a pipeline
## (a shader at a render size, with MSAA) is made with Godot's ubershader while the real one compiles in the background, and
## the two differ by a few levels, so a frame drawn before the compile ends would differ from one drawn after it.
func warm_up(on: bool) -> void:
	_warm = on
	if not on:
		idle()


func _process(delta: float) -> void:
	super._process(delta)
	if _warm:
		_mark_characters()
		_sync_mask_camera()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if write_mask else SubViewport.UPDATE_DISABLED
		return
	if _pending <= 0:
		return
	_mark_characters()
	_sync_mask_camera()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if write_mask:
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_pending -= 1


## Render the frame now on screen (the next draw), read it back and write it as frame number `frames_written`. `extra_frames` more
## draws come first, for a still whose shadow cache and edge pass need to settle. Returns the Error of the PNG's save.
func capture_frame(extra_frames: int = 0) -> Error:
	if _first_usec == 0:
		_first_usec = Time.get_ticks_usec()
	for _i in extra_frames:
		_pending = 1
		await RenderingServer.frame_post_draw
	_pending = 1
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var mask_image: Image = null
	if write_mask:
		mask_image = mask_viewport.get_texture().get_image()
	var started := Time.get_ticks_usec()
	var err: Error = OK
	var pixels := PackedByteArray()
	if _single or store_png:
		var path := frame_path(_frames_dir, frames_written)
		err = image.save_png(path)
		if err != OK:
			_problems.append("frame %d: save_png error %d" % [frames_written, err])
		_png_bytes += _file_size(path)
		pixels = image.get_data()
	else:
		if image.get_format() != Image.FORMAT_RGB8:
			image.convert(Image.FORMAT_RGB8)
		pixels = image.get_data()
		if _raw == null:
			_raw = FileAccess.open(raw_path(_frames_dir, _chunk_start), FileAccess.WRITE)
		_raw.store_buffer(pixels)
		_png_bytes += pixels.size()
	if mask_image != null:
		var mask_path := mask_frame_path(_frames_dir, frames_written)
		if mask_image.save_png(mask_path) != OK:
			_problems.append("mask %d: save_png failed" % frames_written)
		_png_bytes += _file_size(mask_path)
	_save_usec += Time.get_ticks_usec() - started
	hashes.append("%05d %s%s" % [frames_written, _sha256(pixels),
			" %s" % _sha256(mask_image.get_data()) if mask_image != null else ""])
	frames_written += 1
	_last_usec = Time.get_ticks_usec()
	if frames_written - _chunk_start >= chunk_frames:
		_flush_chunk()
	return err


## Turn the rendering off (between picks): the SubViewports update only when asked.
func idle() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The characters (the group HumanoidRig.ART_GROUP's meshes) carry MASK_LAYER while the main camera would draw them, and not
## otherwise (the player's own head is on a layer the first-person camera never draws, and must not reach the mask).
func _mark_characters() -> void:
	var seen_mask := camera.cull_mask & ~MASK_LAYER
	for node in get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var base_layers := mesh.layers & ~MASK_LAYER
		mesh.layers = base_layers | (MASK_LAYER if (base_layers & seen_mask) != 0 and mesh.is_visible_in_tree() else 0)


func _sync_mask_camera() -> void:
	mask_camera.global_transform = camera.global_transform
	mask_camera.keep_aspect = camera.keep_aspect
	mask_camera.fov = camera.fov
	mask_camera.near = camera.near
	mask_camera.far = camera.far
	mask_camera.projection = camera.projection
	mask_camera.h_offset = camera.h_offset
	mask_camera.v_offset = camera.v_offset
	mask_camera.cull_mask = MASK_LAYER


## Finish: encode the last chunk, join the parts, write the hashes and the numbers. A one-frame window keeps its PNGs.
## Returns the numbers (a Dictionary, also saved as `<key>_stats.json`).
func finish() -> Dictionary:
	idle()
	set_window_enabled(true)
	if _single:
		_keep_still()
	else:
		_flush_chunk()
		_join(_parts, out_dir.path_join("%s.mkv" % key))
		if write_mask:
			_join(_mask_parts, out_dir.path_join("%s_mask.mkv" % key))
	for file in DirAccess.get_files_at(_frames_dir):
		DirAccess.remove_absolute(_frames_dir.path_join(file))
	DirAccess.remove_absolute(_frames_dir)
	var file := FileAccess.open(out_dir.path_join("%s.sha256" % key), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(hashes) + "\n")
		file.close()
	var stats := _stats()
	var stats_file := FileAccess.open(out_dir.path_join("%s_stats.json" % key), FileAccess.WRITE)
	if stats_file != null:
		stats_file.store_string(JSON.stringify(stats, "\t"))
		stats_file.close()
	print("WRITER %s" % JSON.stringify(stats))
	return stats


func _keep_still() -> void:
	DirAccess.rename_absolute(frame_path(_frames_dir, 0), out_dir.path_join("%s.png" % key))
	if write_mask:
		DirAccess.rename_absolute(mask_frame_path(_frames_dir, 0), out_dir.path_join("%s_mask.png" % key))


func _stats() -> Dictionary:
	var count := maxi(frames_written, 1)
	var wall_s := float(_last_usec - _first_usec) / 1.0e6 if _first_usec > 0 else 0.0
	var mezzanine := _file_size(out_dir.path_join("%s.mkv" % key))
	var mask_size := _file_size(out_dir.path_join("%s_mask.mkv" % key))
	return {
		"key": key,
		"frames": frames_written,
		"size": [size.x, size.y],
		"out_fps": out_fps,
		"sim_fps": _sim_fps,
		"seconds_per_frame": wall_s / float(count),
		"wall_seconds": wall_s,
		"save_seconds_per_frame": float(_save_usec) / 1.0e6 / float(count),
		"encode_seconds": float(_encode_usec) / 1.0e6,
		"png_mb_per_frame": float(_png_bytes) / 1048576.0 / float(count),
		"mezzanine_mb": float(mezzanine) / 1048576.0,
		"mezzanine_mb_per_frame": float(mezzanine) / 1048576.0 / float(count),
		"mask_mb": float(mask_size) / 1048576.0,
		"video_memory_mb": float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0,
		"static_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		"problems": _problems,
	}


# --- the disk ---------------------------------------------------------------------------------


static func frame_path(dir: String, index: int) -> String:
	return dir.path_join("f%05d.png" % index)


static func mask_frame_path(dir: String, index: int) -> String:
	return dir.path_join("m%05d.png" % index)


static func raw_path(dir: String, first: int) -> String:
	return dir.path_join("chunk%05d.rgb" % first)


## The colour tags of the mezzanine: BT.709, limited range. The pixels are the render's own 8-bit sRGB values, converted with the
## BT.709 matrix, so a player shows them as the render looked.
const COLOR_FILTER := "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=%s"
const COLOR_TAGS: Array[String] = ["-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv"]


## The ffmpeg arguments that encode `count` PNGs `pattern` starting at number `first` into `out_path`.
static func encode_args(pattern: String, first: int, count: int, fps: int, out_path: String, p_crf: int, p_preset: String,
		pix_fmt: String) -> PackedStringArray:
	var args := PackedStringArray(["-y", "-loglevel", "error", "-framerate", str(fps), "-start_number", str(first), "-i", pattern])
	args.append_array(_encode_tail(count, fps, out_path, p_crf, p_preset, pix_fmt))
	return args


## The same for a raw RGB chunk file of `size` frames.
static func raw_encode_args(raw: String, frame_size: Vector2i, count: int, fps: int, out_path: String, p_crf: int, p_preset: String,
		pix_fmt: String) -> PackedStringArray:
	var args := PackedStringArray(["-y", "-loglevel", "error", "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size",
			"%dx%d" % [frame_size.x, frame_size.y], "-framerate", str(fps), "-i", raw])
	args.append_array(_encode_tail(count, fps, out_path, p_crf, p_preset, pix_fmt))
	return args


static func _encode_tail(count: int, fps: int, out_path: String, p_crf: int, p_preset: String, pix_fmt: String) -> PackedStringArray:
	var args := PackedStringArray(["-frames:v", str(count), "-vf", COLOR_FILTER % pix_fmt, "-c:v", "libx264", "-crf", str(p_crf),
			"-preset", p_preset, "-pix_fmt", pix_fmt])
	args.append_array(PackedStringArray(COLOR_TAGS))
	args.append_array(PackedStringArray(["-r", str(fps), out_path]))
	return args


## The same for the mask: the alpha channel as lossless gray.
static func mask_encode_args(pattern: String, first: int, count: int, fps: int, out_path: String) -> PackedStringArray:
	return PackedStringArray(["-y", "-loglevel", "error", "-framerate", str(fps), "-start_number", str(first), "-i", pattern,
			"-frames:v", str(count), "-vf", "alphaextract,format=gray", "-c:v", "ffv1", "-pix_fmt", "gray", "-r", str(fps), out_path])


## The concat list of ffmpeg's concat demuxer for `parts` (file names relative to the list).
static func concat_list(parts: PackedStringArray) -> String:
	var lines := PackedStringArray()
	for part in parts:
		lines.append("file '%s'" % part.get_file())
	return "\n".join(lines) + "\n"


func _flush_chunk() -> void:
	var count := frames_written - _chunk_start
	if count <= 0:
		return
	var started := Time.get_ticks_usec()
	var part := out_dir.path_join("%s_part%03d.mkv" % [key, _parts.size()])
	if _raw != null:
		_raw.close()
		_raw = null
	var args: PackedStringArray
	if store_png:
		args = encode_args(_frames_dir.path_join("f%05d.png"), _chunk_start, count, out_fps, part, crf, preset, pixel_format)
	else:
		args = raw_encode_args(raw_path(_frames_dir, _chunk_start), size, count, out_fps, part, crf, preset, pixel_format)
	_run_ffmpeg(args)
	_parts.append(part)
	if write_mask:
		var mask_part := out_dir.path_join("%s_mask_part%03d.mkv" % [key, _mask_parts.size()])
		_run_ffmpeg(mask_encode_args(_frames_dir.path_join("m%05d.png"), _chunk_start, count, out_fps, mask_part))
		_mask_parts.append(mask_part)
	DirAccess.remove_absolute(raw_path(_frames_dir, _chunk_start))
	for index in range(_chunk_start, frames_written):
		DirAccess.remove_absolute(frame_path(_frames_dir, index))
		if write_mask:
			DirAccess.remove_absolute(mask_frame_path(_frames_dir, index))
	_chunk_start = frames_written
	_encode_usec += Time.get_ticks_usec() - started


## Join the parts into `out_path` (stream copy) and delete them.
func _join(parts: PackedStringArray, out_path: String) -> void:
	if parts.is_empty():
		return
	var list_path := out_path.get_basename() + "_parts.txt"
	var list := FileAccess.open(list_path, FileAccess.WRITE)
	list.store_string(concat_list(parts))
	list.close()
	_run_ffmpeg(PackedStringArray(["-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy", out_path]))
	DirAccess.remove_absolute(list_path)
	for part in parts:
		DirAccess.remove_absolute(part)


func _run_ffmpeg(args: PackedStringArray) -> void:
	var output: Array = []
	var code := OS.execute(ffmpeg, args, output, true)
	if code != 0:
		_problems.append("ffmpeg exit %d: %s" % [code, String(output[0]) if not output.is_empty() else ""])
		push_error("CineFrameWriter: ffmpeg exit %d" % code)


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length := file.get_length()
	file.close()
	return length


static func _sha256(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()
