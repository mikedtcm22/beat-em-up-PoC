class_name VideoWorldPractical
extends RefCounted
## Builds one practical of a world look (LD-WORLD): a lamp post, a fire barrel or a bare light, with its light and its banded halo card.
## The root it returns carries meta `light` (the Light3D), `base_energy`, `flicker` and `head` (the light's world position).


static func build(look: VideoWorldLook, spec: VideoWorldLight, base: Vector3, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Practical%d" % index
	var feet := base + spec.position
	root.position = feet
	var head_at := Vector3.ZERO
	match spec.prop:
		VideoWorldLight.Prop.LAMP_POST:
			head_at = _lamp_post(look, spec, root)
		VideoWorldLight.Prop.FIRE_BARREL:
			head_at = _barrel(look, spec, root)
		VideoWorldLight.Prop.BARE:
			head_at = Vector3.ZERO
	var light: Light3D = _light(spec)
	root.add_child(light)
	light.position = head_at
	if spec.spot:
		# Local space is world space here (the rig sits at the level's origin, the root has no rotation).
		var head_world := feet + head_at
		var target := head_world + Vector3.DOWN
		if spec.aim_at != Vector3.ZERO:
			target = base + spec.aim_at
		var dir := (target - head_world).normalized()
		var up := Vector3.RIGHT if absf(dir.y) > 0.95 else Vector3.UP
		light.transform = Transform3D(Basis.looking_at(dir, up), head_at)
	root.set_meta(&"light", light)
	root.set_meta(&"base_energy", spec.energy)
	root.set_meta(&"head", feet + head_at)
	if spec.flicker > 0.0:
		root.set_meta(&"flicker", spec.flicker)
	if spec.halo and spec.halo_energy > 0.0:
		root.add_child(_halo(spec, head_at))
	if spec.shaft:
		root.add_child(_shaft(spec, head_at, index))
	if spec.flame:
		for node in _flame(spec, head_at, index):
			root.add_child(node)
	return root


static func _light(spec: VideoWorldLight) -> Light3D:
	var light: Light3D
	if spec.spot:
		var spot := SpotLight3D.new()
		spot.spot_range = spec.range_m
		spot.spot_angle = spec.cone_deg * 0.5
		spot.spot_attenuation = spec.attenuation
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = spec.range_m
		omni.omni_attenuation = spec.attenuation
		light = omni
	light.name = "Light"
	light.light_color = spec.color
	light.light_energy = spec.energy
	light.light_specular = 0.0
	light.shadow_enabled = spec.shadow
	light.shadow_blur = 1.2
	light.light_volumetric_fog_energy = 0.0
	return light


static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


## A pole, a lean-over arm, a housing and a bright lens. Returns the light's place (under the lens), relative to the feet.
static func _lamp_post(look: VideoWorldLook, spec: VideoWorldLight, root: Node3D) -> Vector3:
	var h := spec.height_m
	var paint := look.prop_material(look.prop_color)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.085
	pole.height = h
	_mesh(root, pole, Vector3(0.0, h * 0.5, 0.0), paint)
	var arm_x := spec.arm_side * 0.7
	if absf(arm_x) > 0.01:
		var arm := BoxMesh.new()
		arm.size = Vector3(absf(arm_x), 0.07, 0.07)
		_mesh(root, arm, Vector3(arm_x * 0.5, h, 0.0), paint)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.7, 0.05, 0.42)
	_mesh(root, cap, Vector3(arm_x, h + 0.1, 0.0), paint)
	# The head glows: an unlit lamp-coloured box (the lens), so the lamp reads as a lit shape, not a black bar.
	var lens_material := StandardMaterial3D.new()
	lens_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens_material.albedo_color = look.lens_color
	lens_material.disable_fog = true
	var lens := BoxMesh.new()
	lens.size = Vector3(0.62, 0.14, 0.34)
	_mesh(root, lens, Vector3(arm_x, h + 0.01, 0.0), lens_material)
	return Vector3(arm_x, h - 0.1, 0.0)


## A barrel with a flame card; the light sits in the flame. Returns the flame's place.
static func _barrel(look: VideoWorldLook, spec: VideoWorldLight, root: Node3D) -> Vector3:
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.3
	barrel.bottom_radius = 0.28
	barrel.height = 0.9
	_mesh(root, barrel, Vector3(0.0, 0.45, 0.0), look.prop_material(look.barrel_color))
	return Vector3(0.0, spec.height_m, 0.0)


static func _halo(spec: VideoWorldLight, at: Vector3) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = VideoWorldLook.HALO_SHADER
	var core := spec.color.lerp(Color.WHITE, 0.75)
	material.set_shader_parameter(&"core_color", core)
	material.set_shader_parameter(&"ring_color", spec.color)
	material.set_shader_parameter(&"rings", spec.halo_rings)
	material.set_shader_parameter(&"energy", spec.halo_energy)
	material.set_shader_parameter(&"wobble", spec.halo_wobble)
	material.set_shader_parameter(&"ring_strength", spec.halo_ring_strength)
	material.set_shader_parameter(&"seed", float(absi(hash(spec.position)) % 97))
	var quad := QuadMesh.new()
	quad.size = Vector2(spec.halo_m, spec.halo_m)
	var instance := MeshInstance3D.new()
	instance.name = "Halo"
	instance.mesh = quad
	instance.position = at - Vector3(0.0, spec.halo_m * 0.08, 0.0)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## A lamp's painted shaft: a vertical card from the lamp head down (a cylindrical billboard in its shader), the cone opening toward the ground.
static func _shaft(spec: VideoWorldLight, head_at: Vector3, index: int) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = VideoWorldLook.SHAFT_SHADER
	material.set_shader_parameter(&"shaft_color", spec.color.lerp(Color.WHITE, 0.15))
	material.set_shader_parameter(&"energy", spec.shaft_energy)
	material.set_shader_parameter(&"seed", float(index) * 3.7 + 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(spec.shaft_w_m, spec.shaft_len_m)
	var instance := MeshInstance3D.new()
	instance.name = "Shaft"
	instance.mesh = quad
	instance.position = head_at - Vector3(0.0, spec.shaft_len_m * 0.5 + 0.05, 0.0)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 4.0
	return instance


## The barrel's painted fire: two flame cards (each its own seed) standing in the barrel's mouth, each with a `flame` material the rig re-rolls.
static func _flame(spec: VideoWorldLight, head_at: Vector3, index: int) -> Array[Node]:
	var out: Array[Node] = []
	for k in 2:
		var material := ShaderMaterial.new()
		material.shader = VideoWorldLook.FLAME_SHADER
		material.set_shader_parameter(&"seed", float(index) * 5.3 + float(k) * 2.9 + 1.0)
		material.set_shader_parameter(&"outer_color", spec.color.darkened(0.1))
		material.set_shader_parameter(&"mid_color", spec.color.lerp(Color(1.0, 0.7, 0.2), 0.45))
		var quad := QuadMesh.new()
		var s := 1.0 - 0.25 * float(k)
		quad.size = Vector2(spec.flame_w_m * s, spec.flame_h_m * s)
		var instance := MeshInstance3D.new()
		instance.name = "Flame%d" % k
		instance.mesh = quad
		instance.position = Vector3(0.0, 0.88 + quad.size.y * 0.5 - 0.06, 0.0) + Vector3(0.05 * float(k), 0.0, 0.0)
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.set_meta(&"flame_material", material)
		out.append(instance)
	return out
