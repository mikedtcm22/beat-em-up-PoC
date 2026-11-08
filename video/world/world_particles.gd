class_name VideoWorldParticles
extends RefCounted
## Builds one GPU particle emitter of a world look (LD-WORLD): embers, steam or dust, seeded and fixed-rate so a frame repeats
## (PLAN.md section 4 part 4). The sprites are made by code (VideoWorldSprites), once per kind.

static var _ember: ImageTexture
static var _puff: ImageTexture
static var _mote: ImageTexture


static func build(spec: VideoWorldEmitter, at: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Emitter_%d" % spec.kind
	particles.amount = spec.amount
	particles.lifetime = spec.life_s
	particles.preprocess = spec.preprocess_s
	particles.explosiveness = 0.0
	particles.randomness = 1.0
	particles.fixed_fps = 60
	particles.use_fixed_seed = true
	particles.seed = spec.seed
	particles.visibility_aabb = AABB(Vector3(-30.0, -10.0, -30.0), Vector3(60.0, 40.0, 60.0))
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = spec.extents
	process.direction = spec.direction.normalized()
	process.spread = spec.spread_deg
	process.initial_velocity_min = spec.speed.x
	process.initial_velocity_max = spec.speed.y
	process.gravity = spec.gravity
	process.scale_min = spec.size_m.x
	process.scale_max = spec.size_m.y
	var ramp := Gradient.new()
	ramp.set_color(0, spec.color_start)
	ramp.set_color(1, spec.color_end)
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	if spec.kind == VideoWorldEmitter.Kind.STEAM:
		# A steam puff swells as it rises.
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.5))
		curve.add_point(Vector2(1.0, 1.6))
		var curve_texture := CurveTexture.new()
		curve_texture.curve = curve
		process.scale_curve = curve_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.draw_pass_1 = quad
	quad.material = _sprite_material(spec)
	particles.position = at
	return particles


static func _sprite_material(spec: VideoWorldEmitter) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.disable_fog = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match spec.kind:
		VideoWorldEmitter.Kind.EMBERS:
			if _ember == null:
				_ember = VideoWorldSprites.ember()
			material.albedo_texture = _ember
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_color = Color(spec.energy, spec.energy, spec.energy, 1.0)
		VideoWorldEmitter.Kind.STEAM:
			if _puff == null:
				_puff = VideoWorldSprites.puff()
			material.albedo_texture = _puff
		VideoWorldEmitter.Kind.DUST:
			if _mote == null:
				_mote = VideoWorldSprites.mote()
			material.albedo_texture = _mote
	return material
