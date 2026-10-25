class_name ImpactFrame
extends ColorRect
## The finisher impact frame (Spec §6): for 1-2 frames the whole screen, HUD included (it
## draws above it), turns into a high-contrast inverted ink print (impact_frame.gdshader).
## Hidden unless flashing. VfxDirector flashes it only with Tuning.impact_frame_enabled,
## the photosensitivity toggle. Driven by advance() with real time: the length is
## Tuning.vfx_impact_frame_frames of 60 Hz, and at least one rendered frame.

const SHADER := preload("res://game/fx/impact_frame.gdshader")

## Real seconds of flash left after the first rendered frame.
var time_left: float = 0.0
## advance() calls since the flash started (each is one rendered frame).
var frames_shown: int = 0

## The one-pixel warm-up is on screen (warm()). It is no flash.
var _warming: bool = false


func _init() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Draw the ink material once, on a single pixel in the screen's corner, for one rendered
## frame (the next advance() ends it): the renderer builds the material's canvas pipeline and
## its screen-texture copy at load, not on the first finisher's frame (measured: 1-3 ms
## more on it). Not a flash: is_flashing() stays false, and the screen stays as it is but
## for that pixel. VfxDirector calls it once, and only while the photosensitivity toggle
## (Tuning.impact_frame_enabled) is on. Does nothing while a flash is showing.
func warm() -> void:
	if visible:
		return
	_warming = true
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ONE
	visible = true


## Flash for `seconds` of real time (at least one frame).
func flash(seconds: float) -> void:
	_end_warm()
	time_left = maxf(seconds, 0.0)
	frames_shown = 0
	var mat := material as ShaderMaterial
	mat.set_shader_parameter(&"threshold", Tuning.data.vfx_impact_frame_threshold)
	mat.set_shader_parameter(&"local_mix", Tuning.data.vfx_impact_frame_local_mix)
	mat.set_shader_parameter(&"blur_lod", Tuning.data.vfx_impact_frame_blur_mip)
	visible = true


func is_flashing() -> bool:
	return visible and not _warming


## Step `real_dt` real seconds. The frame the flash starts in is always shown whole.
func advance(real_dt: float) -> void:
	if not visible:
		return
	if _warming:
		_end_warm()
		return
	if frames_shown > 0:
		time_left -= real_dt
		if time_left <= 0.0001:
			visible = false
			return
	frames_shown += 1


## Hide the warm-up's pixel and give the rect back its whole screen.
func _end_warm() -> void:
	if not _warming:
		return
	_warming = false
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
