class_name CinePostEffect
extends CompositorEffect
## The video's finish pass as a CompositorEffect (PLAN.md Plan A part 5; docs/video/P1.md LD-INK 4 and, in round 3, LD-INK2 2 and 3): the
## grade (the darks toned, the highlights warmed), the delivery (a sub-pixel soften and a fine grain that changes on twos), a static
## paper grain, a vignette and a little chromatic aberration, in one compute dispatch (video/shaders/post_finish.glsl). It runs after the transparent pass, on the resolved colour. Make a
## Compositor with `CinePostEffect.make_compositor(look)` and assign it to the WorldEnvironment and to every
## camera that renders the shot (the frame writer's SubViewport camera as well: a camera's own compositor
## wins over the world's). Needs a RenderingDevice (the Forward+ renderer); in a headless run it does nothing.

const SHADER_PATH := "res://video/shaders/post_finish.glsl"
const CONTEXT := &"cine_post"
const COPY_NAME := &"color_copy"
const GROUP_X := 8

## The strengths (VideoInkLook's Post group sets them): grain (a share of value), vignette (a share of the
## value at the corner) and where it starts (0..1 of the radius), aberration (a fraction of the frame at the
## corner), the grain's cell in pixels at the render height, and the paper seed.
var grain: float = 0.05
var vignette: float = 0.35
var vignette_start: float = 0.45
var aberration: float = 0.0012
var grain_cell_px: float = 1.6
var paper_seed: float = 0.0
## The delivery: the soften's blend (0 = off), the fine grain's strength and its seed (the rig sets it from the output frame over the hold).
var soften: float = 0.0
var fine_grain: float = 0.0
var fine_seed: float = 0.0
## The grade: the darks' tint (rgb, and a = its share), the darks' desaturation, the luminance where the darks end (x: fully dark, y: not
## dark any more), the highlights' multiplier (rgb) and its share.
var dark_tint: Color = Color(0.5, 0.5, 0.5, 0.0)
var dark_desat: float = 0.0
var dark_range: Vector2 = Vector2(0.01, 0.08)
var high_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
var high_share: float = 0.0

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	needs_motion_vectors = false
	RenderingServer.call_on_render_thread(_initialize_compute)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _shader.is_valid() and _rd != null:
			_rd.free_rid(_shader)


func _initialize_compute() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var file := load(SHADER_PATH) as RDShaderFile
	if file == null:
		push_warning("CinePostEffect: %s did not load" % SHADER_PATH)
		return
	var spirv := file.get_spirv()
	if spirv.compile_error_compute != "":
		push_warning("CinePostEffect: %s" % spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if _rd == null or not _pipeline.is_valid() or callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	# A temp image: the first pass reads the colour with offsets and writes it, the second copies it back.
	var temp := buffers.create_texture(CONTEXT, COPY_NAME, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, false, false)
	var scale := float(size.y) / 1080.0
	var groups := Vector3i((size.x + GROUP_X - 1) / GROUP_X, (size.y + GROUP_X - 1) / GROUP_X, 1)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var color_uniform := RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color_uniform.binding = 0
		color_uniform.add_id(color)
		var temp_uniform := RDUniform.new()
		temp_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		temp_uniform.binding = 1
		temp_uniform.add_id(temp)
		var set_rid := UniformSetCacheRD.get_cache(_shader, 0, [color_uniform, temp_uniform])
		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		_rd.compute_list_bind_uniform_set(list, set_rid, 0)
		for pass_id in 2:
			var push := PackedFloat32Array([float(size.x), float(size.y), grain, vignette, vignette_start, aberration,
					maxf(grain_cell_px * scale, 1.0), paper_seed, float(pass_id), soften, fine_grain, fine_seed,
					dark_tint.r, dark_tint.g, dark_tint.b, dark_tint.a, dark_desat, dark_range.x, dark_range.y, high_share,
					high_tint.r, high_tint.g, high_tint.b, 0.0])
			_rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
			_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
			_rd.compute_list_add_barrier(list)
		_rd.compute_list_end()


## A Compositor holding one CinePostEffect with the values of `look` (a VideoInkLook).
static func make_compositor(look: Resource) -> Compositor:
	var effect := CinePostEffect.new()
	effect.grain = look.post_grain
	effect.vignette = look.post_vignette
	effect.vignette_start = look.post_vignette_start
	effect.aberration = look.post_aberration
	effect.grain_cell_px = look.post_grain_cell_px
	effect.paper_seed = look.post_paper_seed
	if look.delivery_on:
		effect.soften = look.deliver_soften
		effect.fine_grain = look.deliver_grain
	effect.dark_tint = Color(look.grade_dark_tint.r, look.grade_dark_tint.g, look.grade_dark_tint.b, look.grade_dark_amount)
	effect.dark_desat = look.grade_dark_desat
	effect.dark_range = Vector2(look.grade_dark_lo, look.grade_dark_hi)
	effect.high_tint = look.grade_high_tint
	effect.high_share = look.grade_high_amount
	var compositor := Compositor.new()
	var effects: Array[CompositorEffect] = [effect]
	compositor.compositor_effects = effects
	return compositor
