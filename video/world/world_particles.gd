class_name VideoWorldParticles
extends RefCounted
## Builds one GPU particle emitter of a world look (LD-WORLD): embers, steam or dust, seeded and fixed-rate so a frame repeats
## (PLAN.md section 4 part 4). The sprites are made by code (VideoWorldSprites), once per kind.

static var _ember: ImageTexture
static var _puff: ImageTexture
static var _mote: ImageTexture
static var _ember_atlas: ImageTexture
static var _puff_atlas: ImageTexture


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
	elif spec.kind == VideoWorldEmitter.Kind.EMBERS:
		# An ember burns down as it rises.
		var shrink := Curve.new()
		shrink.add_point(Vector2(0.0, 1.0))
		shrink.add_point(Vector2(1.0, 0.3))
		var shrink_texture := CurveTexture.new()
		shrink_texture.curve = shrink
		process.scale_curve = shrink_texture
	if spec.kind != VideoWorldEmitter.Kind.DUST:
		# A flipbook of shapes: each particle picks its own frame (the animation offset is random, its speed zero) and turns to its own angle.
		process.anim_speed_min = 0.0
		process.anim_speed_max = 0.0
		process.anim_offset_min = 0.0
		process.anim_offset_max = 0.99
		process.angle_min = -180.0 if spec.kind == VideoWorldEmitter.Kind.EMBERS else -12.0
		process.angle_max = 180.0 if spec.kind == VideoWorldEmitter.Kind.EMBERS else 12.0
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
			if _ember_atlas == null:
				_ember_atlas = VideoWorldSprites.ember_atlas()
			material.albedo_texture = _ember_atlas
			_flipbook(material)
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_color = Color(spec.energy, spec.energy, spec.energy, 1.0)
		VideoWorldEmitter.Kind.STEAM:
			if _puff_atlas == null:
				_puff_atlas = VideoWorldSprites.puff_atlas()
			material.albedo_texture = _puff_atlas
			_flipbook(material)
		VideoWorldEmitter.Kind.DUST:
			if _mote == null:
				_mote = VideoWorldSprites.mote()
			material.albedo_texture = _mote
	return material


## The material reads a flipbook of VideoWorldSprites.ATLAS_FRAMES shapes side by side; each particle's own frame comes from the process material.
static func _flipbook(material: StandardMaterial3D) -> void:
	material.particles_anim_h_frames = VideoWorldSprites.ATLAS_FRAMES
	material.particles_anim_v_frames = 1
	material.particles_anim_loop = false
