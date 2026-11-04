class_name Weapon
extends RigidBody3D
## A pick-up melee weapon (placeholder pipe). Lies on the ground as a rigid body, rides
## the holder's WeaponGrip while held, and flies as a projectile when thrown.
## Swing hitboxes use the holder's WeaponTip rig point, so the visual never affects hits.

@export var display_name: String = "Pipe"
@export var length: float = 0.85
@export var color: Color = Color(0.55, 0.58, 0.62)
## The drawn pipe's radius (m); the collision capsule stays as it is, so a thicker pipe (the Pipe
## Thug's, which has to read on the floor from across the street) never changes a hit or a fall.
@export var radius: float = 0.028
## The weapon's art (M6, game/weapons/art/<id>.tscn: a StaticArt in the art frame, centred on the origin with its long axis on +Y
## and the grip 0.12 m from the -Y end). Set, the art draws and the cylinder does not (it stays, hidden, as the hit-free proxy the
## floor look and the M1-M5 tests read); null keeps the placeholder cylinder.
@export var art_scene: PackedScene

## Hits left before the weapon breaks (Spec §4: 8).
var durability: int = 8
var holder: CombatActor

var _thrower: CombatActor
var _throw_move: MoveData
var _flying: bool = false
var _mesh: MeshInstance3D
var _cylinder: CylinderMesh
var _material: ShaderMaterial
var _art: StaticArt


func _ready() -> void:
	add_to_group(&"weapon")
	durability = Tuning.data.weapon_durability
	mass = 2.0
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.035
	capsule.height = length
	shape.shape = capsule
	add_child(shape)
	if art_scene != null:
		_art = art_scene.instantiate() as StaticArt
		if _art != null:
			add_child(_art)
	_mesh = MeshInstance3D.new()
	_cylinder = CylinderMesh.new()
	_cylinder.height = length
	_material = ToonMaterials.prop(color)
	_cylinder.material = _material
	_mesh.mesh = _cylinder
	_mesh.material_overlay = ToonMaterials.outline_for_prop() if _art == null else null
	_mesh.visible = _art == null
	add_child(_mesh)
	_set_ground_physics()
	_refresh_look()


func is_available() -> bool:
	return holder == null and not _flying


## The look: lying on the floor (nobody holds it, it is not flying) the pipe takes the tunable
## weapon_floor_color and a thicker radius (weapon_floor_radius_scale), so it reads against the
## floor's grey from across a room; in a hand or in the air it keeps its own `color` and `radius`.
func _refresh_look() -> void:
	if _material == null or _cylinder == null:
		return
	var lying := holder == null and not _flying
	_material.set_shader_parameter(&"albedo", Tuning.data.weapon_floor_color if lying else color)
	var drawn := radius * (Tuning.data.weapon_floor_radius_scale if lying else 1.0)
	_cylinder.top_radius = drawn
	_cylinder.bottom_radius = drawn
	if _art != null:
		_art.set_tint(Color.WHITE.lerp(Tuning.data.weapon_floor_color, Tuning.data.weapon_art_floor_tint) if lying else Color.WHITE)


## Attach to `actor`'s grip. The pipe's long axis points from grip to tip.
func attach_to(actor: CombatActor) -> void:
	holder = actor
	_flying = false
	_refresh_look()
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var grip := actor.rig.get_attachment(&"WeaponGrip")
	_attach_deferred.call_deferred(grip)


func _attach_deferred(grip: Node3D) -> void:
	if not is_instance_valid(grip) or not is_instance_valid(holder):
		return
	reparent(grip, false)
	var tip_local := grip.global_transform.affine_inverse() * holder.rig.get_point_position(&"WeaponTip")
	var dir := tip_local.normalized() if tip_local.length_squared() > 0.0001 else Vector3.UP
	var basis := Basis(Quaternion(Vector3.UP, dir))
	transform = Transform3D(basis, dir * (length * 0.5 - 0.12))


## Leave the holder's hand flying at `velocity`; the first enemy it hits takes `move`.
func throw_from(actor: CombatActor, velocity: Vector3, move: MoveData) -> void:
	var start := global_transform
	var world := actor.get_parent()
	holder = null
	_thrower = actor
	_throw_move = move
	reparent(world, false)
	global_transform = start
	freeze = false
	_set_air_damping()
	_flying = true
	_refresh_look()
	collision_layer = CombatTypes.bit(CombatTypes.LAYER_PROJECTILE)
	collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	linear_velocity = velocity
	angular_velocity = actor.get_forward().cross(Vector3.UP) * -14.0


## Leave the holder's hand and fall to the ground at `velocity` (the Pipe Thug, knocked down or
## killed): back in the world as a rigid body in group "weapon", a pick-up again (is_available()),
## with the durability it has left. A no-op unless it is held. It keeps the pose it had in the hand
## and spins about the vertical at `spin_rps` radians a second as it falls (the sign follows the
## push), so the drop shows. The world is the holder's parent (the room), or the current scene
## when the holder is already gone.
func drop(velocity: Vector3 = Vector3.ZERO, spin_rps: float = 0.0) -> void:
	if holder == null or not is_inside_tree():
		return
	var start := global_transform
	var world: Node = holder.get_parent() if is_instance_valid(holder) and holder.get_parent() else get_tree().current_scene
	holder = null
	_flying = false
	_thrower = null
	_refresh_look()
	reparent(world, false)
	global_transform = start
	freeze = false
	_set_air_damping()
	linear_velocity = velocity
	angular_velocity = Vector3(0.0, signf(velocity.x + velocity.z + 0.001) * spin_rps, 0.0)
	_set_ground_physics()


func break_apart() -> void:
	queue_free()


func _set_ground_physics() -> void:
	if holder != null:
		return  # picked up on the frame it landed
	freeze = false
	collision_layer = CombatTypes.bit(CombatTypes.LAYER_PICKUP)
	collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)


## Once a loose weapon touches the world it rests (Tuning weapon_rest_*_damp): damped, it stops
## sliding and rolling where it fell and Jolt puts it to sleep. In the air, and while it flies as a
## projectile, it keeps the engine's damping, so the fall and the throw are unchanged. Set every
## step it touches something, so the values are live.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _flying or holder != null or freeze or state.get_contact_count() == 0:
		return
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = Tuning.data.weapon_rest_linear_damp
	angular_damp = Tuning.data.weapon_rest_angular_damp


## Back to the engine's damping (the weapon leaves a hand, to fall or to fly).
func _set_air_damping() -> void:
	linear_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
	angular_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
	linear_damp = 0.0
	angular_damp = 0.0


func _on_body_entered(body: Node) -> void:
	if not _flying:
		return
	var victim := body as CombatActor
	if victim and is_instance_valid(_thrower) and victim.team != _thrower.team and _throw_move:
		if victim.can_be_hit_by(_thrower, _throw_move):
			var dir := Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized()
			var hit := HitInfo.new()
			hit.attacker = _thrower
			hit.victim = victim
			hit.move = _throw_move
			hit.damage = _throw_move.damage
			hit.tier = _throw_move.tier
			hit.reaction = _throw_move.reaction
			hit.region = CombatTypes.Region.TORSO
			# The pipe meets the body's capsule, short of the body itself: the contact (the
			# flash, the comic effects, the sound) goes on the nearest hurtbox.
			hit.contact_point = victim.rig.hurt_point(global_position)
			hit.direction = dir
			hit.knockback = (
				dir * _throw_move.knockback.z
				+ dir.cross(Vector3.UP) * _throw_move.knockback.x
				+ Vector3.UP * _throw_move.knockback.y
			)
			hit.from_behind = victim.get_forward().dot(dir) > 0.0
			hit.is_body_impact = true
			hit.physics_frame = Engine.get_physics_frames()
			hit.input_timing = &"thrown"
			if victim.receive_hit(hit):
				durability -= 1
				TimeController.hitstop([victim], HitDetector.hitstop_for(hit))
				CombatEvents.hit_landed.emit(hit)
		linear_velocity *= -0.2
	_flying = false
	_refresh_look()
	_set_ground_physics.call_deferred()
	if durability <= 0:
		CombatEvents.weapon_broke.emit(_thrower, self)
		break_apart()
