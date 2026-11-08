class_name VideoStillGrab
extends Node
## The 2560x1440 still renderer: a SubViewport that shares the main viewport's World3D (so the same level,
## environment, edge-line quad and colour grade) and has its own Camera3D, which copies the main viewport's
## active camera every frame after the game cameras moved. It renders at its own size whatever the window is,
## with MSAA 4x. The HUD and the 2D effect layers are CanvasLayers of the main viewport, so they never reach it.
## This is the seed of the frame writer of Phase 1.

## The render size and the MSAA mode (the data of the stage, not of the game).
@export var size: Vector2i = Vector2i(2560, 1440)
@export var msaa: Viewport.MSAA = Viewport.MSAA_4X
## Frames drawn after the camera is copied before the image is read (the edge pass and the shadow cache settle).
@export_range(1, 10) var settle_frames: int = 2

var viewport: SubViewport
var camera: Camera3D


func _ready() -> void:
	# After the game's cameras (process priority 50) and the bot's own camera pose (60).
	process_priority = 100
	viewport = SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = false
	viewport.msaa_3d = msaa
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = false
	camera = Camera3D.new()
	viewport.add_child(camera)
	add_child(viewport)
	camera.make_current()


func _process(_delta: float) -> void:
	sync_camera()


## Copy the main viewport's active camera onto the grab camera.
func sync_camera() -> void:
	var source := get_viewport().get_camera_3d()
	if source == null or camera == null:
		return
	camera.global_transform = source.global_transform
	camera.keep_aspect = source.keep_aspect
	camera.fov = source.fov
	camera.near = source.near
	camera.far = source.far
	camera.cull_mask = source.cull_mask
	camera.projection = source.projection
	camera.h_offset = source.h_offset
	camera.v_offset = source.v_offset


## Render the frame and write it to `path` (a PNG). Returns the Error of the save.
func capture(path: String) -> Error:
	sync_camera()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _i in settle_frames:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return image.save_png(path)
