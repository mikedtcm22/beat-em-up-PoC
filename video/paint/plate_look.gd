class_name VideoPlateLook
extends VideoLookPiece
## The plate piece (round 5, R5-PAINT; docs/video/P1.md): a shot whose key has plates in `assets/video/plates/<shot key>/` gets them projected
## over its background; a shot with none is left exactly as it was (`apply` adds nothing). The director applies it last, after the world, the
## art and the ink piece (`plate.tres` in the location's look folder). On a plated shot:
##  - a CinePlateQuad (video/paint/plate_quad.gd) is added to the level: the plates drawn onto the world's pixels, characters never;
##  - the static transparents the plate carries (the haze quad, the lamp halos and shafts) are hidden live; the moving ones (steam, embers, the
##    smoke matte, the flames) stay.
## The capture (video/paint/plate_bot.gd) reads the same values: the plate's size, the margin its FOV gets, the depth's span, the nodes it hides.
## A plate is `plate_<n>.png` (the registered painting), `depth_<n>.png` (red and green: the 16-bit view depth, plate_depth.gdshader's) and
## `plate_<n>.json` (the camera, VideoPlateCamera), n = 0 or 1.

const PLATE_DIR := "res://assets/video/plates"
const QUAD_NAME := &"CinePlateQuad"

@export_group("Capture")
## The plate's picture size. The same centre of projection maps a frame 1:1 at any FOV, so a wider plate keeps the pixel size when this is larger.
@export var capture_size: Vector2i = Vector2i(2560, 1440)
## Degrees added to the FOV that covers the shot's frames (horizontal), so a pan, a tilt or a push stays inside the plate.
@export_range(0.0, 40.0) var margin_deg: float = 8.0
## The most the plate's FOV may be (a plate wider than this loses pixels on the frame).
@export_range(40.0, 150.0) var max_fov_deg: float = 120.0
## The metres the depth picture spans (65534 steps).
@export_range(10.0, 2000.0) var depth_far_m: float = 200.0
## Nodes of the level hidden for the capture: the first-person body and every humanoid are hidden by class (CombatActor and the art group), and the
## nodes whose names START with one of these (steam plumes, embers, flames, contact shadows, lamp shafts and halos, the cues).
@export var capture_hide_prefixes: PackedStringArray = PackedStringArray(["Plume_", "Emitter_", "Flame", "Contact", "Shaft", "Halo", "CineCue", "CineTwos", "CineSmears"])
## Engine classes of node hidden for the capture, on top (every CombatActor, the player's first-person body among them, and every PickupSpot are hidden too).
@export var capture_hide_classes: PackedStringArray = PackedStringArray(["GPUParticles3D", "CPUParticles3D"])
@export_group("Live")
## Nodes of a plated shot hidden live, by name prefix: what the plate carries (the haze quad, the lamp halos and shafts).
@export var live_hide_prefixes: PackedStringArray = PackedStringArray(["HazeQuad", "Shaft", "Halo"])
@export_group("Projection")
## The depth test: the share of the pixel's depth plus metres. A pixel whose depth differs from the plate's by more is a surface the plate never saw.
@export_range(0.0, 0.3) var depth_tol_share: float = 0.03
@export_range(0.0, 2.0) var depth_tol_m: float = 0.05
## The mip level of the blurred plate shown where the depth test fails inside the plate's frame.
@export_range(0.0, 10.0) var blur_lod: float = 5.0
## The plate quad's debug view (0 the picture, 1 which plate, 2 the uv).
@export_range(0, 2) var debug_view: int = 0
@export_group("Blockout line")
## The blockout's thin line on depth edges: its colour, its width in pixels at 1080p and the relative depth step that makes an edge.
@export var line_color: Color = Color(0.07, 0.06, 0.13)
@export_range(0.5, 6.0) var line_width_px: float = 1.6
@export_range(0.01, 1.0) var line_step_share: float = 0.12

## The quad of the last application (null when the shot has no plate).
var quad: CinePlateQuad


## The folder of a shot's plates: `assets/video/plates/<key>`, or `<VIDEO_PLATE_DIR>/<key>` when that environment variable is set (the motion check
## projects an unpainted capture without installing it).
static func plate_dir(shot_key: StringName) -> String:
	var root := OS.get_environment("VIDEO_PLATE_DIR")
	return (root if root != "" else PLATE_DIR).path_join(String(shot_key))


## The plate numbers (0 or 1) a shot has, in order: those with the picture, the depth and the camera all present.
static func plates_of(shot_key: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	var dir := plate_dir(shot_key)
	for n in CinePlateQuad.SLOTS:
		if FileAccess.file_exists(dir.path_join("plate_%d.png" % n)) and FileAccess.file_exists(dir.path_join("depth_%d.png" % n)) \
				and FileAccess.file_exists(dir.path_join("plate_%d.json" % n)):
			out.append(n)
	return out


## A texture of the image file at `path` (read from the disk, so a plate needs no import), with mipmaps when asked; null when it does not load.
static func load_texture(path: String, mipmaps: bool) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGB8 and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	if mipmaps:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## The shot the director is playing (its key), or &"" when the level is not run by a director.
static func running_shot_key(level: Node) -> StringName:
	var director := level.get_tree().root.find_child("CineDirector", true, false) as CineDirector
	if director == null or director.shot == null:
		return &""
	return director.shot.key


func apply(level: Node) -> void:
	var old := level.get_node_or_null(NodePath(String(QUAD_NAME)))
	if old != null:
		level.remove_child(old)
		old.queue_free()
	quad = null
	var key := running_shot_key(level)
	if key == &"":
		return
	var plates := plates_of(key)
	if plates.is_empty():
		return
	var made := CinePlateQuad.new()
	var slot := 0
	for n in plates:
		var dir := plate_dir(key)
		var camera := VideoPlateCamera.from_json(FileAccess.get_file_as_string(dir.path_join("plate_%d.json" % n)))
		var colour := load_texture(dir.path_join("plate_%d.png" % n), true)
		var depth := load_texture(dir.path_join("depth_%d.png" % n), false)
		if camera == null or colour == null or depth == null:
			push_warning("VideoPlateLook: plate %d of %s does not load" % [n, key])
			continue
		made.set_plate(slot, colour, depth, camera)
		slot += 1
	if slot == 0:
		made.free()
		return
	made.apply_look(self)
	made.name = QUAD_NAME
	level.add_child(made)
	quad = made
	hide_by_prefix(level, live_hide_prefixes)
	var follower := PlateQuadFollower.new()
	follower.quad = made
	made.add_child(follower)


## Hide every node under `root` whose name starts with one of `prefixes`. Returns how many.
static func hide_by_prefix(root: Node, prefixes: PackedStringArray) -> int:
	var count := 0
	for node in root.find_children("*", "Node3D", true, false):
		var item := node as Node3D
		for prefix in prefixes:
			if String(item.name).begins_with(prefix):
				item.visible = false
				count += 1
				break
	return count


## The nodes the capture hides under `root` (what `hide_for_capture` would hide), as a list: the classes, then the name prefixes.
func capture_hidden(root: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in root.find_children("*", "Node3D", true, false):
		var item := node as Node3D
		var hit := false
		if item is CombatActor or item is PickupSpot:
			hit = true
		for cls in capture_hide_classes:
			if not hit and item.is_class(cls):
				hit = true
		if not hit:
			for prefix in capture_hide_prefixes:
				if String(item.name).begins_with(prefix):
					hit = true
					break
		if not hit and item is MeshInstance3D and item.is_in_group(HumanoidRig.ART_GROUP):
			hit = true
		if hit:
			out.append(item)
	return out
