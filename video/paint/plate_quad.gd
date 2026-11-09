class_name CinePlateQuad
extends PlateScreenQuad
## The plate quad (round 5, R5-PAINT; docs/video/P1.md): the screen quad that projects a shot's Gemini plates onto the world's pixels
## (video/shaders/plate_project.gdshader). The piece (VideoPlateLook) builds it with the plates it found, and it follows the shot's camera each frame.
## It sits second in the transparent queue: after the brush quad (3000 m down the view), before everything else.

const PROJECT_SHADER := preload("res://video/shaders/plate_project.gdshader")

## The most plates one shot holds (the shader has two slots).
const SLOTS := 2
## Where the quad sits down the view: just nearer than the brush quad (3000 m), so it draws right after it.
const SORT_DISTANCE := 2990.0


func _init() -> void:
	super._init("CinePlateQuad", PROJECT_SHADER, Material.RENDER_PRIORITY_MIN, SORT_DISTANCE)


## Give slot `slot` (0 or 1) a plate: `colour` and `depth` are textures, `camera` the plate's camera data (VideoPlateCamera).
func set_plate(slot: int, colour: Texture2D, depth: Texture2D, camera: VideoPlateCamera) -> void:
	var suffix := "a" if slot == 0 else "b"
	_material.set_shader_parameter("plate_%s" % suffix, colour)
	_material.set_shader_parameter("depth_%s" % suffix, depth)
	_material.set_shader_parameter("view_%s" % suffix, camera.view_projection())
	_material.set_shader_parameter("tan_%s" % suffix, camera.tan_half())
	_material.set_shader_parameter("far_%s" % suffix, camera.depth_far_m)
	_material.set_shader_parameter("valid_%s" % suffix, 1.0)


## The tolerance, the blur and the debug view (VideoPlateLook's values).
func apply_look(look: Resource) -> void:
	_material.set_shader_parameter(&"tol_share", look.depth_tol_share)
	_material.set_shader_parameter(&"tol_m", look.depth_tol_m)
	_material.set_shader_parameter(&"blur_lod", look.blur_lod)
	_material.set_shader_parameter(&"debug_view", look.debug_view)
