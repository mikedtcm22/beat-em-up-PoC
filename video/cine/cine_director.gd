class_name CineDirector
extends Node
## The cine stage's director (P1.md, LD-STAGE; PLAN.md §6's LD-RENDER without the look): it applies a shot's look pieces to the level
## in the order art, world, ink, hides the HUD and the debug overlays, seeds the effect and audio rngs, sets the few presentation
## tunables a shot needs (the FOV, the shake) at run time through `Tuning.set_value`, and builds and drives the free camera
## of a non-first-person shot from the shot clock. The look values live in `res://video/look/<location>/*.tres` (data of the
## pieces); nothing here is a feel number and nothing is written to `game/`, `tuning/` or a preset.
## The shot clock is the physics-frame count since `start_clock()`: the same on every run, never `TIME`.

## Where the pieces of a location are, and the file names: `art*.tres` (any number, by name), then `world.tres`, then `ink.tres`, then `plate.tres` (round 5).
const LOOK_DIR := "res://video/look"
const WORLD_FILE := "world.tres"
const INK_FILE := "ink.tres"
const PLATE_FILE := "plate.tres"
const ART_PREFIX := "art"

## The game's floor glint of a weapon (a four-point sparkle above it, WeaponGlint) is hidden: against a sun it reads as a camera's lens flare, and
## neither reference has one. The weapon itself stays. Set it false for the game's own pickup cue.
@export var hide_pickup_glint: bool = true

var shot: VideoStillShot
var level: Node
var location: StringName = &"street_night"
## The pieces applied, in order.
var pieces: Array[VideoLookPiece] = []
## The free camera of a non-first-person shot (null in first person).
var camera: CineCamera
## The tunables written at run time, and the values to put back in `restore()`.
var _saved: Dictionary[StringName, Variant] = {}
var _clock_start: int = 0
var _origin: Vector3 = Vector3.ZERO
var _actors: Array[Node3D] = []
var _head_point: StringName = &"Head"
## The video's frame rate (the frame writer's).
var out_fps: int = 24


func _init() -> void:
	# After the game's cameras (50), so a free camera's pose is this frame's.
	process_priority = 60


func _process(_delta: float) -> void:
	if camera != null and is_instance_valid(camera):
		_track_actors()
		camera.set_time(camera_time_s())


# --- the pieces --------------------------------------------------------------------------


## The paths of `location_name`'s pieces that exist, in the order they apply: art, world, ink.
static func piece_paths(location_name: StringName) -> PackedStringArray:
	var dir_path := LOOK_DIR.path_join(String(location_name))
	var out := PackedStringArray()
	var art := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		var file_name := file.trim_suffix(".remap")
		if file_name.begins_with(ART_PREFIX) and file_name.ends_with(".tres"):
			art.append(dir_path.path_join(file_name))
	art.sort()
	out.append_array(art)
	for file in [WORLD_FILE, INK_FILE, PLATE_FILE]:
		var path := dir_path.path_join(file)
		if ResourceLoader.exists(path):
			out.append(path)
	return out


## The pieces of `location_name` loaded, in order. A file that is not a VideoLookPiece is skipped with a warning.
static func load_pieces(location_name: StringName) -> Array[VideoLookPiece]:
	var out: Array[VideoLookPiece] = []
	for path in piece_paths(location_name):
		var piece := load(path) as VideoLookPiece
		if piece == null:
			push_warning("CineDirector: %s is not a VideoLookPiece" % path)
			continue
		out.append(piece)
	return out


## Set the shot and its level up: the pieces of the shot's location applied in order, the overlays hidden, the rngs seeded and
## the presentation tunables set. `skip` names piece file names (e.g. &"ink.tres") a run leaves out (an A/B).
## `overrides` set properties of a piece for the run (an A/B or a sweep): "<piece file>.<property>" -> value, e.g.
## {"ink.tres.post_enabled": false}; the piece is duplicated first, so the .tres is never changed.
func direct(p_level: Node, p_shot: VideoStillShot, skip: PackedStringArray = PackedStringArray(),
		overrides: Dictionary = {}) -> void:
	level = p_level
	shot = p_shot
	location = shot_location(shot)
	pieces.clear()
	for path in piece_paths(location):
		if skip.has(path.get_file()):
			continue
		var piece := load(path) as VideoLookPiece
		if piece != null:
			piece = override_piece(piece, path.get_file(), overrides)
			pieces.append(piece)
			piece.apply(level)
	remember_overlays()
	hide_overlays(level)
	if hide_pickup_glint:
		_hide_glints(level)
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
	seed_rngs(level, shot.rng_seed if shot is CineShot else 1)
	apply_presentation()


## A copy of `piece` with the overrides of `file` ("<file>.<property>" keys) set, or `piece` itself when there are none. A property the
## piece has not warns.
static func override_piece(piece: VideoLookPiece, file: String, overrides: Dictionary) -> VideoLookPiece:
	var prefix := "%s." % file
	var copy: VideoLookPiece = null
	for key: Variant in overrides:
		var text := String(key)
		if not text.begins_with(prefix):
			continue
		if copy == null:
			copy = piece.duplicate() as VideoLookPiece
		var property := text.trim_prefix(prefix)
		if property in copy:
			copy.set(property, overrides[key])
		else:
			push_warning("CineDirector: %s has no property %s" % [file, property])
	return copy if copy != null else piece


## The location a shot is in: a CineShot's, else its section's.
static func shot_location(p_shot: VideoStillShot) -> StringName:
	if p_shot is CineShot:
		return (p_shot as CineShot).location_name()
	return CineShot.section_location(p_shot.section)


## True when a world piece was applied (it places its own lamps, so the stage builds none).
func has_world_piece() -> bool:
	return pieces.any(func(piece: VideoLookPiece) -> bool: return piece is VideoWorldLook)


# --- the overlays, the seeds, the presentation --------------------------------------------


## Keep the centre dot's setting (the overlays' hiding turns it off), so `restore()` puts it back.
func remember_overlays() -> void:
	if not _saved.has(&"show_center_dot"):
		_saved[&"show_center_dot"] = Tuning.data.show_center_dot


## The HUD (every CanvasLayer of the level) and the debug draw hidden: only the world reaches a frame.
static func hide_overlays(p_level: Node) -> void:
	for child in p_level.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		if child.has_method(&"set_debug_draw_enabled"):
			child.call(&"set_debug_draw_enabled", false)
	Tuning.set_value(&"show_center_dot", false)


## Seed the effect and audio directors' rngs (they randomize at startup): a frame never depends on the wall clock.
static func seed_rngs(p_level: Node, rng_seed: int) -> int:
	var seeded := 0
	for child in p_level.get_children():
		if child is VfxDirector:
			(child as VfxDirector).rng.seed = rng_seed
			seeded += 1
		elif child is AudioDirector:
			(child as AudioDirector).rng.seed = rng_seed
			seeded += 1
	return seeded


## The presentation tunables the shot asks for, written through Tuning (video only, never to a preset), and kept for `restore()`.
func apply_presentation() -> void:
	if shot is CineShot and (shot as CineShot).shake_scale >= 0.0:
		_write(&"screen_shake_intensity", float(Tuning.data.screen_shake_intensity) * (shot as CineShot).shake_scale)
	if shot.first_person and shot.first_person_fov_deg > 0.0:
		_write(&"fov_deg", shot.first_person_fov_deg)


func _write(property: StringName, value: Variant) -> void:
	if not _saved.has(property):
		_saved[property] = Tuning.data.get(property)
	Tuning.set_value(property, value)


## Hide the floor glint's sparkle of every weapon under `p_level` now (the glint shows and hides its own node, not the sparkle mesh).
static func _hide_glints(p_level: Node) -> void:
	for glint in p_level.find_children("*", "WeaponGlint", true, false):
		for child in glint.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D and node.get_parent() is WeaponGlint:
		(node as MeshInstance3D).visible = false


## Put back the tunables this director wrote.
func restore() -> void:
	for property: StringName in _saved:
		Tuning.set_value(property, _saved[property])
	_saved.clear()
	if is_inside_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


# --- the clock and the camera --------------------------------------------------------------


## The time the camera path is sampled at: the exact time of the output frame the clock is in (n / out_fps), not of the tick. The
## frame writer keeps the first tick of each output frame, and those ticks are 3 and 2 ticks apart at 24 fps (0, 3, 5, 8, 10, 13), so a
## path sampled at the pick tick's own time steps unevenly: sampled at n / 24 it steps evenly.
func camera_time_s() -> float:
	return camera_time(clock_ticks(), Engine.physics_ticks_per_second, out_fps)


## The time of the output frame tick `tick` is in (`sim_fps` ticks a second, `fps` frames).
static func camera_time(tick: int, sim_fps: int, fps: int) -> float:
	return float(CineFrameWriter.output_index(tick, sim_fps, fps)) / float(fps)


## Zero the shot clock now: the staging is over.
func start_clock() -> void:
	_clock_start = Engine.get_physics_frames()


## Physics ticks since `start_clock()`, and the same in seconds.
func clock_ticks() -> int:
	return Engine.get_physics_frames() - _clock_start


func clock_s() -> float:
	return float(clock_ticks()) / float(Engine.physics_ticks_per_second)


## Build the free camera of a non-first-person shot (the shot's keys, in section space from `section_origin`), parented
## to the level and made current. `actors` are the nodes the keys' `target_actor` indices follow.
func build_camera(section_origin: Vector3, actors: Array[Node3D] = []) -> CineCamera:
	_origin = section_origin
	_actors = actors
	camera = CineCamera.new()
	camera.name = "CineCamera"
	var keys: Array[CineCameraKey] = []
	if shot is CineShot:
		keys = (shot as CineShot).keys()
	else:
		var key := CineCameraKey.new()
		key.position = shot.cam_pos
		key.look_at = shot.cam_look_at
		key.fov_deg = shot.cam_fov_deg
		keys = [key]
	camera.setup(keys, section_origin)
	level.add_child(camera)
	_track_actors()
	camera.set_time(0.0)
	camera.make_current()
	return camera


## Follow the actors: the camera's look-at points that target one.
func _track_actors() -> void:
	var points: Array[Vector3] = []
	for actor in _actors:
		if is_instance_valid(actor):
			var point := actor.global_position + Vector3.UP * 1.6
			if actor is CombatActor:
				var rig_point := (actor as CombatActor).rig.get_point_position(_head_point)
				if rig_point != Vector3.ZERO:
					point = rig_point
			points.append(point)
		else:
			points.append(Vector3.ZERO)
	camera.actor_points = points
