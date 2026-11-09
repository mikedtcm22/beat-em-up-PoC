class_name PlateScreenQuad
extends MeshInstance3D
## A full-screen quad in the transparent pass (round 5, R5-PAINT): the base of the plate quad and of the capture's depth and line quads. The vertex stage
## puts it over the whole viewport; the node sits `sort_distance` metres down the camera's view each frame, so the transparent sort places it (far
## to near within one render priority): the brush quad is at 3000 m, the plate quad just nearer, every other transparent object nearer still.

var _material: ShaderMaterial
var _sort_distance: float = 0.0


## `shader` is the screen shader, `priority` its render priority, `sort_distance` the metres down the view it sorts at.
func _init(p_name: String = "PlateScreenQuad", shader: Shader = null, priority: int = Material.RENDER_PRIORITY_MIN, sort_distance: float = 0.0) -> void:
	name = p_name
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sort_distance = sort_distance
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.render_priority = priority
	material_override = _material


## Sit down the camera's view (for the sort). The shader never reads this position.
func update(camera: Camera3D) -> void:
	if camera != null:
		global_position = camera.global_position - camera.global_basis.z * _sort_distance


## The material, for the piece and the tests.
func material() -> ShaderMaterial:
	return _material
