class_name CinePostEffect
extends CompositorEffect
## The video's finish pass as a CompositorEffect (PLAN.md Plan A part 5; docs/video/P1.md LD-INK 4 and, in round 3, LD-INK2 2 and 3): the
## grade (the darks toned, the highlights warmed), the delivery (a re-scale down and back up like a stream's upscaled master, a sub-pixel soften
## and a fine grain that changes on twos), a static paper grain, a vignette and a little chromatic aberration, in a few compute dispatches
## (video/shaders/post_finish.glsl). It runs after the transparent pass, on the resolved colour. (The brush pass is not a compositor effect:
## with MSAA a pre-transparent effect's writes are lost, so it is a screen quad, video/ink/brush_quad.gd.) Make a
## Compositor with `CinePostEffect.make_compositor(look)` and assign it to the WorldEnvironment and to every
## camera that renders the shot (the frame writer's SubViewport camera as well: a camera's own compositor
## wins over the world's). Needs a RenderingDevice (the Forward+ renderer); in a headless run it does nothing.

const SHADER_PATH := "res://video/shaders/post_finish.glsl"
const CONTEXT := &"cine_post"
const COPY_NAME := &"color_copy"
const SMALL_NAME := &"deliver_small"
const GLOW_A_NAME := &"glow_a"
const GLOW_B_NAME := &"glow_b"
## The buffers the actors pass reads: the normal-roughness buffer (the character tag) and the depth, in the renderer's own scope.
const BUFFER_SCOPE := &"forward_clustered"
const NORMAL_NAME := &"normal_roughness"
## The passes of post_finish.glsl, in the order they run (the delivery's 0 and 1 only with the re-scale on).
const PASS_DOWN := 0
const PASS_UP := 1
const PASS_FINISH := 2
const PASS_COPY := 3
const PASS_ACTORS := 4
const PASS_GLOW_BRIGHT := 5
const PASS_GLOW_DOWN := 6
const PASS_GLOW_BLUR_FIRST := 7
const PASS_GLOW_BLUR_LAST := 10
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
## The delivery's re-scale: the share of the render size the picture is filtered down to and bicubic-scaled back from (1 = off).
var deliver_scale: float = 1.0
## Round 5, the actors on the painting (a character's pixels only): the light wrap's strength (0 = off), its reach from the silhouette and the nearest and
## farthest pixel of the colour it reads (px at 1080p); the actor fog's most (0 = off), the metres it starts and is full at, and the radius of the colour it
## fogs toward (px at 1080p).
var wrap_strength: float = 0.0
var wrap_reach_px: float = 6.0
var wrap_near_px: float = 14.0
var wrap_far_px: float = 36.0
var fog_amount: float = 0.0
var fog_start_m: float = 6.0
var fog_end_m: float = 30.0
var fog_blur_px: float = 60.0
## The glow: the narrow and wide shares screened on (0 and 0 = off), their radii as shares of the width, and the bright pass's threshold and knee (linear luminance).
var glow_narrow: float = 0.0
var glow_wide: float = 0.0
var glow_narrow_radius: float = 0.005
var glow_wide_radius: float = 0.03
var glow_threshold: float = 0.6
var glow_knee: float = 0.35
## A debug view of the actors pass (0 = none; 1 = the distance and the fog; 2 = the wrap's reach).
var actors_debug: int = 0

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID
var _extra: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	needs_motion_vectors = false
	RenderingServer.call_on_render_thread(_initialize_compute)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _rd != null:
			if _extra.is_valid():
				_rd.free_rid(_extra)
			if _sampler.is_valid():
				_rd.free_rid(_sampler)
			if _shader.is_valid():
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
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_sampler = _rd.sampler_create(sampler_state)


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
	# The delivery's re-scale: the picture box-filtered down to `deliver_scale` and bicubic-scaled back up (passes 0 and 1).
	var rescale := deliver_scale < 0.999
	var small_size := Vector2i(maxi(int(round(size.x * deliver_scale)), 2), maxi(int(round(size.y * deliver_scale)), 2)) if rescale else Vector2i(2, 2)
	var small := buffers.create_texture(CONTEXT, SMALL_NAME, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, RenderingDevice.TEXTURE_SAMPLES_1, small_size, 1, 1, false, false)
	# The glow's images: a quarter-size bright pass, and a block of the same width under which the 1/16-size blurs sit.
	var quarter := Vector2i((size.x + 3) / 4, (size.y + 3) / 4)
	var sixteenth := Vector2i((quarter.x + 3) / 4, (quarter.y + 3) / 4)
	var glow_on := glow_narrow > 0.0 or glow_wide > 0.0
	var actors_on := (wrap_strength > 0.0 or fog_amount > 0.0) and buffers.has_texture(BUFFER_SCOPE, NORMAL_NAME)
	var glow_a_size := quarter if glow_on else Vector2i(2, 2)
	var glow_b_size := Vector2i(quarter.x, quarter.y + sixteenth.y) if glow_on else Vector2i(2, 2)
	var glow_a := buffers.create_texture(CONTEXT, GLOW_A_NAME, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, RenderingDevice.TEXTURE_SAMPLES_1, glow_a_size, 1, 1, false, false)
	var glow_b := buffers.create_texture(CONTEXT, GLOW_B_NAME, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, RenderingDevice.TEXTURE_SAMPLES_1, glow_b_size, 1, 1, false, false)
	var projection := render_data.get_render_scene_data().get_cam_projection()
	var extra := PackedFloat32Array([
			wrap_strength, wrap_reach_px, wrap_near_px, wrap_far_px,
			fog_amount, fog_start_m, fog_end_m, fog_blur_px,
			glow_narrow, glow_wide, glow_threshold, glow_knee,
			float(quarter.x), float(quarter.y), float(sixteenth.x), float(sixteenth.y),
			glow_narrow_radius * float(size.x) * 0.5 / 4.0, glow_wide_radius * float(size.x) * 0.5 / 16.0, float(actors_debug), 0.0,
			projection.z.z, projection.w.z, 1.0 if actors_on else 0.0, 1.0 if glow_on else 0.0])
	var extra_bytes := extra.to_byte_array()
	if not _extra.is_valid():
		_extra = _rd.uniform_buffer_create(extra_bytes.size(), extra_bytes)
	else:
		_rd.buffer_update(_extra, 0, extra_bytes.size(), extra_bytes)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var set_rid := UniformSetCacheRD.get_cache(_shader, 0, [
				_image_uniform(0, color), _image_uniform(1, temp), _image_uniform(2, small),
				_image_uniform(3, glow_a), _image_uniform(4, glow_b),
				_sampler_uniform(5, buffers.get_texture_slice(BUFFER_SCOPE, NORMAL_NAME, view, 0, 1, 1) if actors_on else buffers.get_depth_layer(view)),
				_sampler_uniform(6, buffers.get_depth_layer(view)),
				_buffer_uniform(7, _extra)])
		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		_rd.compute_list_bind_uniform_set(list, set_rid, 0)
		var passes: Array[int] = []
		if actors_on:
			passes.append_array([PASS_ACTORS, PASS_COPY])
		if glow_on:
			passes.append_array([PASS_GLOW_BRIGHT, PASS_GLOW_DOWN, 7, 8, 9, 10])
		if rescale:
			passes.append_array([PASS_DOWN, PASS_UP])
		passes.append_array([PASS_FINISH, PASS_COPY])
		for pass_id in passes:
			var push := PackedFloat32Array([float(size.x), float(size.y), grain, vignette, vignette_start, aberration,
					maxf(grain_cell_px * scale, 1.0), paper_seed, float(pass_id), soften, fine_grain, fine_seed,
					dark_tint.r, dark_tint.g, dark_tint.b, dark_tint.a, dark_desat, dark_range.x, dark_range.y, high_share,
					high_tint.r, high_tint.g, high_tint.b, 0.0,
					float(small_size.x), float(small_size.y), 0.0, 0.0])
			_rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
			var pass_groups := groups
			if pass_id >= PASS_GLOW_BRIGHT and pass_id <= PASS_GLOW_BLUR_LAST:
				var area := sixteenth if (pass_id == PASS_GLOW_DOWN or pass_id >= 9) else quarter
				pass_groups = Vector3i((area.x + GROUP_X - 1) / GROUP_X, (area.y + GROUP_X - 1) / GROUP_X, 1)
			_rd.compute_list_dispatch(list, pass_groups.x, pass_groups.y, 1)
			_rd.compute_list_add_barrier(list)
		_rd.compute_list_end()


func _image_uniform(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform


func _sampler_uniform(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(_sampler)
	uniform.add_id(texture)
	return uniform


func _buffer_uniform(binding: int, buffer: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform


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
	if look.delivery_on:
		effect.deliver_scale = look.deliver_scale
	effect.wrap_strength = look.wrap_strength
	effect.wrap_reach_px = look.wrap_reach_px
	effect.wrap_near_px = look.wrap_near_px
	effect.wrap_far_px = look.wrap_far_px
	effect.fog_amount = look.fog_amount
	effect.fog_start_m = look.fog_start_m
	effect.fog_end_m = look.fog_end_m
	effect.fog_blur_px = look.fog_blur_px
	effect.glow_narrow = look.glow_narrow
	effect.glow_wide = look.glow_wide
	effect.glow_narrow_radius = look.glow_narrow_radius
	effect.glow_wide_radius = look.glow_wide_radius
	effect.glow_threshold = look.glow_threshold
	effect.glow_knee = look.glow_knee
	effect.actors_debug = look.actors_debug
	var compositor := Compositor.new()
	var effects: Array[CompositorEffect] = [effect]
	compositor.compositor_effects = effects
	return compositor

