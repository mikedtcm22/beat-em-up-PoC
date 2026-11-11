class_name BurnBarrel
extends Node3D
## A burn barrel (M7 T16a, the trailer's street, assets/source/trailer_ref/frames/t_05.jpg): a flat two-tone drum with an ink hull, a
## painted sprite flame over its mouth, drifting embers and an orange pool on the ground. Decoration only: no collider, no
## navigation, nothing the simulation reads. StreetFx places it under look profile "trailer" and frees it under m6. Every size is in
## Tuning's group "Trailer street FX"; the flame, embers and pool redraw on twos (`set_slot()`).

var _flame_mat: ShaderMaterial
var _ember_mat: ShaderMaterial
var _pool_mat: ShaderMaterial
var _body: Node3D
var _embers: MultiMeshInstance3D


func _ready() -> void:
	build()


## Build the drum, flame, embers and pool from Tuning (once; a second call rebuilds).
func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var t := Tuning.data
	var h := t.tfx_barrel_height_m
	var r := t.tfx_barrel_radius_m
	var body_mat := ShaderMaterial.new()
	body_mat.shader = load("res://game/fx/street_barrel.gdshader") as Shader
	body_mat.set_shader_parameter(&"height_m", h)
	_body = _mesh(_cylinder(r, h), body_mat, h * 0.5)
	_body.name = &"Drum"
	var hull_mat := StandardMaterial3D.new()
	hull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull_mat.albedo_color = Color(0.03, 0.04, 0.09)
	hull_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var hull := _mesh(_cylinder(r * 1.07, h * 1.03), hull_mat, h * 0.5)
	hull.name = &"Hull"
	# The flame, a billboard card standing on the drum's mouth.
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = load("res://game/fx/street_flame.gdshader") as Shader
	_flame_mat.set_shader_parameter(&"energy", t.tfx_flame_energy)
	_flame_mat.set_shader_parameter(&"seed", float(get_index()) + 1.0)
	var card := QuadMesh.new()
	card.size = Vector2(t.tfx_flame_card_w_m, t.tfx_flame_card_h_m)
	card.center_offset = Vector3(0.0, t.tfx_flame_card_h_m * 0.5, 0.0)
	var flame := _mesh(card, _flame_mat, h)
	flame.name = &"Flame"
	flame.extra_cull_margin = 2.0
	# The embers.
	_ember_mat = ShaderMaterial.new()
	_ember_mat.shader = load("res://game/fx/street_ember.gdshader") as Shader
	_ember_mat.set_shader_parameter(&"life_slots", t.tfx_ember_life_s * t.tfx_twos_hz)
	_ember_mat.set_shader_parameter(&"rise_m", t.tfx_ember_rise_m)
	_ember_mat.set_shader_parameter(&"sway_m", t.tfx_ember_sway_m)
	_ember_mat.set_shader_parameter(&"size_m", t.tfx_ember_size_m)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multi.mesh = quad
	multi.instance_count = maxi(t.tfx_embers_per_barrel, 0)
	for i in multi.instance_count:
		multi.set_instance_transform(i, Transform3D.IDENTITY)
		multi.set_instance_custom_data(i, Color(float(i) / float(multi.instance_count), 0.0, 0.0, 0.0))
	multi.custom_aabb = AABB(Vector3(-3.0, 0.0, -3.0), Vector3(6.0, t.tfx_ember_rise_m + 1.0, 6.0))
	_embers = MultiMeshInstance3D.new()
	_embers.name = &"Embers"
	_embers.multimesh = multi
	_embers.material_override = _ember_mat
	_embers.position = Vector3(0.0, h, 0.0)
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_embers)
	# The pool of light on the ground.
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = load("res://game/fx/street_pool.gdshader") as Shader
	_pool_mat.set_shader_parameter(&"alpha", t.tfx_pool_alpha)
	var pool_quad := QuadMesh.new()
	pool_quad.size = Vector2(t.tfx_pool_m, t.tfx_pool_m)
	pool_quad.orientation = PlaneMesh.FACE_Y
	var pool := _mesh(pool_quad, _pool_mat, 0.02)
	pool.name = &"Pool"


## Draw drawing number `slot` (the effects hold on twos: this is called when the drawing changes).
func set_slot(slot: int) -> void:
	for mat: ShaderMaterial in [_flame_mat, _ember_mat, _pool_mat]:
		if mat != null:
			mat.set_shader_parameter(&"slot", float(slot))


## The materials this barrel draws with (tests, the cost probe).
func materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for mat: ShaderMaterial in [_flame_mat, _ember_mat, _pool_mat]:
		if mat != null:
			out.append(mat)
	return out


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.92
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return mesh


func _mesh(mesh: Mesh, material: Material, y: float) -> MultiMeshInstance3D:
	var node := one_mesh(mesh, material)
	node.position = Vector3(0.0, y, 0.0)
	add_child(node)
	return node


## `mesh` drawn once with `material`, as a one-instance MultiMeshInstance3D (not a MeshInstance3D: see StreetFx), shadows off.
static func one_mesh(mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D.IDENTITY)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
