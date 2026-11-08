class_name CineSpikeCapture
extends Node
## The spike's own 2560x1440 capture, private to video/spike/ (P0-STILLS builds the shared one; the lead merges
## them later). A SubViewport that shares the main viewport's World3D (own_world_3d false) with a Camera3D of its
## own that copies the main viewport's active camera every frame, after the game cameras have moved (they run at
## process priority 50, this node at 100). The HUD and the 2D effect layers are CanvasLayers of the main viewport,
## so they never reach it. Saved with the viewport texture after RenderingServer.frame_post_draw.

## The size of the frame, set by `setup()` (the CineSpikeLookData's capture_size).
var size: Vector2i = Vector2i(2560, 1440)

var _viewport: SubViewport
var _camera: Camera3D
var _source: Camera3D


func _init() -> void:
	process_priority = 100


## Build the viewport at `frame_size` and make it render nothing until `shoot()`.
func setup(frame_size: Vector2i) -> void:
	size = frame_size
	_viewport = SubViewport.new()
	_viewport.name = "SpikeViewport"
	_viewport.size = size
	_viewport.own_world_3d = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_debanding = true
	_viewport.positional_shadow_atlas_size = 4096
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_camera = Camera3D.new()
	_camera.name = "SpikeCamera"
	_viewport.add_child(_camera)
	add_child(_viewport)
	_camera.current = true


func _process(_delta: float) -> void:
	_copy_camera()


func _copy_camera() -> void:
	if _camera == null:
		return
	_source = get_tree().root.get_camera_3d()
	if _source == null or _source == _camera:
		return
	_camera.global_transform = _source.global_transform
	_camera.fov = _source.fov
	_camera.keep_aspect = _source.keep_aspect
	_camera.near = _source.near
	_camera.far = _source.far
	_camera.cull_mask = _source.cull_mask
	_camera.projection = _source.projection
	_camera.h_offset = _source.h_offset
	_camera.v_offset = _source.v_offset


## Render one frame and save it as a PNG at `path` (absolute or res://). Returns the Error of the save.
func shoot(path: String) -> Error:
	_copy_camera()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if image == null:
		return ERR_CANT_CREATE
	return image.save_png(path)


## The main window's own frame (for the once-only check that the two agree), saved at `path`.
func shoot_window(path: String) -> Error:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if image == null:
		return ERR_CANT_CREATE
	return image.save_png(path)


## The camera the viewport renders with (the copy), for the ink pass's view-space light positions.
func camera() -> Camera3D:
	return _source
