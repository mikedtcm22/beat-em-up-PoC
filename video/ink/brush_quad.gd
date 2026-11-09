class_name CineBrushQuad
extends MeshInstance3D
## The brush pass's screen quad (round 4, R4-INK; docs/video/P1.md): a full-screen quad whose material is video/shaders/brush_screen.gdshader (an
## anisotropic Kuwahara filter, a soft posterize and a world-anchored hand wobble on the world's pixels; characters and the sky are never touched).
## It sits at the head of the transparent queue (the haze planes share the lowest render priority, so the quad is placed far down the view every frame:
## transparent objects of one priority draw far to near), so the haze, steam, flames, shafts and mattes draw over it and the ink pass draws its lines
## over it. The rig (CineInkRig) adds it and calls `update()` every frame; the look's Brush group has the values.

const BRUSH_SHADER := preload("res://video/shaders/brush_screen.gdshader")
## Where the quad sits down the view axis, in metres, so it sorts before every other transparent object of its priority.
const SORT_DISTANCE := 3000.0

var _material: ShaderMaterial


func _init() -> void:
	name = "CineBrushQuad"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	self.mesh = mesh
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = BRUSH_SHADER
	_material.render_priority = Material.RENDER_PRIORITY_MIN
	material_override = _material


## Read the look's brush values (a VideoInkLook).
func apply_look(look: Resource) -> void:
	_material.set_shader_parameter(&"r_near", look.brush_r_near)
	_material.set_shader_parameter(&"r_far", look.brush_r_far)
	_material.set_shader_parameter(&"depth_near_m", look.brush_depth_near_m)
	_material.set_shader_parameter(&"depth_far_m", look.brush_depth_far_m)
	_material.set_shader_parameter(&"focus_gain", look.brush_focus_gain)
	_material.set_shader_parameter(&"edge_gain", look.brush_edge_gain)
	_material.set_shader_parameter(&"edge_start", look.brush_edge_start)
	_material.set_shader_parameter(&"r_max", look.brush_r_max)
	_material.set_shader_parameter(&"aniso_alpha", look.brush_aniso_alpha)
	_material.set_shader_parameter(&"sharpness", look.brush_sharpness)
	_material.set_shader_parameter(&"tap_half", look.brush_tap_half)
	_material.set_shader_parameter(&"tensor_lod", look.brush_tensor_lod)
	_material.set_shader_parameter(&"wobble_px", look.brush_wobble_px)
	_material.set_shader_parameter(&"wobble_cell_m", look.brush_wobble_cell_m)
	_material.set_shader_parameter(&"depth_reject", look.brush_depth_reject)
	_material.set_shader_parameter(&"post_step", look.brush_post_step)
	_material.set_shader_parameter(&"post_soft", look.brush_post_soft)
	_material.set_shader_parameter(&"post_mix", look.brush_post_mix)
	_material.set_shader_parameter(&"post_noise", look.brush_post_noise)
	_material.set_shader_parameter(&"post_cell_m", look.brush_post_cell_m)
	_material.set_shader_parameter(&"fill_amount", look.brush_fill)
	_material.set_shader_parameter(&"fill_near_px", look.brush_fill_near_px)
	_material.set_shader_parameter(&"fill_far_px", look.brush_fill_far_px)
	_material.set_shader_parameter(&"fill_gate", look.brush_fill_gate)
	_material.set_shader_parameter(&"debug_view", look.brush_debug_view)


## Every frame: sit far down the camera's view (for the sort), and tell the shader the shot's focus distance in metres.
func update(camera: Camera3D, focus_m: float) -> void:
	global_position = camera.global_position - camera.global_basis.z * SORT_DISTANCE
	_material.set_shader_parameter(&"focus_m", maxf(focus_m, 0.5))


## The material, for tests and the act's A/Bs.
func material() -> ShaderMaterial:
	return _material
