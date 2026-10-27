class_name LookPost
extends Node3D
## The look's post pass (Milestone 4, M4-plan A8): the edge lines, the color grade and the
## anti-aliasing mode, for whichever room builds it (RoomKit.build_presentation(), so both
## rooms and every bot that builds a presentation). Presentation only: it reads Tuning and
## draws, and never writes game state.
##
## - The edge pass: a full-screen quad (game/fx/edge_pass.gdshader) at render priority -127,
##   between the contact flash (-128) and the comic sprites (0 and up). It outputs ink as
##   ALBEDO and the line as ALPHA and never reads the screen. `look_edges_enabled` hides it,
##   and a hidden quad asks the renderer for no depth or normal buffer, so off costs nothing.
##   `look_edge_depth_only` swaps in the shader with EDGE_DEPTH_ONLY defined (no normal buffer).
## - The grade: the room's Environment gets `adjustment_color_correction`, a 3D LUT built from
##   assets/export/look/grade_lut.png (tools/gen_lut.gd). `look_grade_strength` mixes the LUT
##   with the identity, so the texture is rebuilt when the strength changes.
## - The AA mode: `look_aa_mode` sets the viewport's MSAA and FXAA (project.godot is untouched).
##
## Every number comes from Tuning (Look > Edges and Grade); it follows `Tuning.changed` live.

const EDGE_SHADER := preload("res://game/fx/edge_pass.gdshader")
## The grade LUT: a strip of N slices of N x N pixels, slice = blue, x = red, y = green
## (tools/gen_lut.gd writes it; node_value() is where each node samples).
const LUT_PATH := "res://assets/export/look/grade_lut.png"
## Prepended to the edge shader's source for the depth-only fallback.
const DEPTH_ONLY_DEFINE := "#define EDGE_DEPTH_ONLY\n"
## Just above the contact flash (Material.RENDER_PRIORITY_MIN), below every comic sprite.
const EDGE_RENDER_PRIORITY := Material.RENDER_PRIORITY_MIN + 1
## The quad is never culled: it is a screen, not a thing in the world.
const EDGE_CULL_MARGIN := 16384.0
## Bytes of a LUT texel (RGB8), and the largest value of one.
const LUT_CHANNELS := 3
const BYTE_MAX := 255.0

## The `look_aa_mode` values.
enum AaMode { MSAA_4X, FXAA, OFF }

static var _depth_only_shader: Shader

var _quad: MeshInstance3D
var _material: ShaderMaterial
var _environment: Environment
## The graded LUT's bytes (slice after slice) and the identity's, read once.
var _graded: PackedByteArray = PackedByteArray()
var _identity: PackedByteArray = PackedByteArray()
var _lut_size: int = 0
var _lut_texture: ImageTexture3D
var _lut_strength: float = -1.0
var _viewport: Viewport
var _aa_before: Dictionary = {}
var _aa_applied: Dictionary = {}


func _init() -> void:
	name = "LookPost"


func _ready() -> void:
	_build_quad()
	_environment = find_environment(get_parent())
	_read_lut()
	_viewport = get_viewport()
	_aa_before = {msaa = _viewport.msaa_3d, ssaa = _viewport.screen_space_aa}
	apply()
	Tuning.changed.connect(_on_tuning_changed)


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)
	# Give the viewport its mode back, unless something else has set one since.
	if _viewport != null and is_instance_valid(_viewport) and not _aa_applied.is_empty() \
			and _viewport.msaa_3d == _aa_applied.msaa and _viewport.screen_space_aa == _aa_applied.ssaa:
		_viewport.msaa_3d = _aa_before.msaa
		_viewport.screen_space_aa = _aa_before.ssaa


## The edge quad (hidden while `look_edges_enabled` is off).
func edge_quad() -> MeshInstance3D:
	return _quad


## The edge pass's material (its shader is the depth-only variant while `look_edge_depth_only`).
func edge_material() -> ShaderMaterial:
	return _material


## The Environment the grade goes on: the room's WorldEnvironment's, or null.
func grade_environment() -> Environment:
	return _environment


## The LUT texture the grade uses now, or null when there is none (no grade file, or no Environment).
func grade_texture() -> ImageTexture3D:
	return _lut_texture


## The WorldEnvironment's Environment among `room`'s children (RoomKit.build_environment names it),
## else the world's own; null if the room has none.
static func find_environment(room: Node) -> Environment:
	if room != null:
		for child: Node in room.get_children():
			var world_env := child as WorldEnvironment
			if world_env != null and world_env.environment != null:
				return world_env.environment
	return null


## The viewport's MSAA and FXAA settings for a `look_aa_mode`: {msaa: Viewport.MSAA, ssaa: Viewport.ScreenSpaceAA}.
static func aa_settings(mode: int) -> Dictionary:
	match mode:
		AaMode.FXAA:
			return {msaa = Viewport.MSAA_DISABLED, ssaa = Viewport.SCREEN_SPACE_AA_FXAA}
		AaMode.OFF:
			return {msaa = Viewport.MSAA_DISABLED, ssaa = Viewport.SCREEN_SPACE_AA_DISABLED}
	return {msaa = Viewport.MSAA_4X, ssaa = Viewport.SCREEN_SPACE_AA_DISABLED}


## The edge shader with EDGE_DEPTH_ONLY defined: no normal-roughness buffer, no creases, no mask.
static func depth_only_shader() -> Shader:
	if _depth_only_shader == null:
		_depth_only_shader = Shader.new()
		_depth_only_shader.code = DEPTH_ONLY_DEFINE + EDGE_SHADER.code
	return _depth_only_shader


## Push every Look > Edges, Grade and AA tunable to the quad, the Environment and the viewport.
func apply() -> void:
	_apply_edges()
	_apply_grade()
	_apply_aa()


func _build_quad() -> void:
	_material = ShaderMaterial.new()
	_material.shader = EDGE_SHADER
	_material.render_priority = EDGE_RENDER_PRIORITY
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_quad = MeshInstance3D.new()
	_quad.name = "EdgeQuad"
	_quad.mesh = mesh
	_quad.extra_cull_margin = EDGE_CULL_MARGIN
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.material_override = _material
	add_child(_quad)


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or String(property).begins_with("look_"):
		apply()


func _apply_edges() -> void:
	var t := Tuning.data
	_quad.visible = t.look_edges_enabled
	var wanted: Shader = depth_only_shader() if t.look_edge_depth_only else EDGE_SHADER
	if _material.shader != wanted:
		_material.shader = wanted
	_material.set_shader_parameter(&"ink", HudStyle.INK)
	_material.set_shader_parameter(&"width_px", t.look_edge_px)
	_material.set_shader_parameter(&"depth_threshold", t.look_edge_depth_threshold)
	_material.set_shader_parameter(&"normal_threshold", t.look_edge_normal_threshold)
	_material.set_shader_parameter(&"fade_start_m", t.look_edge_fade_start_m)
	_material.set_shader_parameter(&"fade_end_m", t.look_edge_fade_end_m)
	_material.set_shader_parameter(&"mask_px", t.look_edge_mask_px)
	_material.set_shader_parameter(&"character_mask", t.look_edge_character_mask)
	_material.set_shader_parameter(&"debug_view", t.look_edge_debug_view)


func _apply_grade() -> void:
	if _environment == null:
		return
	var t := Tuning.data
	if not t.look_grade_enabled or _lut_size == 0:
		_environment.adjustment_enabled = false
		return
	if _lut_texture == null or not is_equal_approx(_lut_strength, t.look_grade_strength):
		_lut_texture = _build_lut_texture(t.look_grade_strength)
		_lut_strength = t.look_grade_strength
	_environment.adjustment_color_correction = _lut_texture
	_environment.adjustment_enabled = true


func _apply_aa() -> void:
	var mode := aa_settings(Tuning.data.look_aa_mode)
	_viewport.msaa_3d = mode.msaa
	_viewport.screen_space_aa = mode.ssaa
	_aa_applied = {msaa = _viewport.msaa_3d, ssaa = _viewport.screen_space_aa}


## Read the LUT strip and keep its bytes, slice after slice, with the identity beside it.
func _read_lut() -> void:
	_lut_size = 0
	if not ResourceLoader.exists(LUT_PATH):
		return
	var texture := load(LUT_PATH) as Texture2D
	if texture == null:
		return
	var strip := texture.get_image()
	if strip == null:
		return
	if strip.is_compressed():
		strip.decompress()
	strip.convert(Image.FORMAT_RGB8)
	var n := strip.get_height()
	if n < 2 or strip.get_width() != n * n:
		push_warning("LookPost: %s is not a strip of N slices of N x N" % LUT_PATH)
		return
	_graded = PackedByteArray()
	for b in n:
		_graded.append_array(strip.get_region(Rect2i(b * n, 0, n, n)).get_data())
	_identity = identity_lut_bytes(n)
	_lut_size = n


## The color value LUT node `i` of `n` stands for (tools/gen_lut.gd's node_value(): the renderer
## samples the LUT at the picture's color itself, so node i sits at (i + 0.5) / n; the first and
## last hold black and white).
static func node_value(i: int, n: int) -> float:
	if i <= 0:
		return 0.0
	if i >= n - 1:
		return 1.0
	return (float(i) + 0.5) / float(n)


## The bytes of an N x N x N identity LUT: slice b, row y, column x holds the nodes (x, y, b).
static func identity_lut_bytes(n: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(n * n * n * LUT_CHANNELS)
	var at := 0
	for b in n:
		for y in n:
			for x in n:
				bytes[at] = roundi(node_value(x, n) * BYTE_MAX)
				bytes[at + 1] = roundi(node_value(y, n) * BYTE_MAX)
				bytes[at + 2] = roundi(node_value(b, n) * BYTE_MAX)
				at += LUT_CHANNELS
	return bytes


## The LUT bytes mixed `strength` of the way from the identity to the graded (0..1).
static func mix_lut_bytes(identity: PackedByteArray, graded: PackedByteArray, strength: float) -> PackedByteArray:
	if strength >= 1.0:
		return graded
	if strength <= 0.0:
		return identity
	var out := PackedByteArray()
	out.resize(identity.size())
	for i in identity.size():
		out[i] = roundi(lerpf(float(identity[i]), float(graded[i]), strength))
	return out


func _build_lut_texture(strength: float) -> ImageTexture3D:
	var bytes := mix_lut_bytes(_identity, _graded, strength)
	var slice_bytes := _lut_size * _lut_size * LUT_CHANNELS
	var slices: Array[Image] = []
	for b in _lut_size:
		slices.append(Image.create_from_data(_lut_size, _lut_size, false, Image.FORMAT_RGB8,
				bytes.slice(b * slice_bytes, (b + 1) * slice_bytes)))
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, _lut_size, _lut_size, _lut_size, false, slices)
	return texture
