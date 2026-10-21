class_name Weapon
extends RigidBody3D
## A pick-up melee weapon (placeholder pipe). Lies on the ground as a rigid body, rides
## the holder's WeaponGrip while held, and flies as a projectile when thrown.
## Swing hitboxes use the holder's WeaponTip rig point, so the visual never affects hits.

@export var display_name: String = "Pipe"
@export var length: float = 0.85
@export var color: Color = Color(0.55, 0.58, 0.62)

## Hits left before the weapon breaks (Spec §4: 8).
var durability: int = 8
var holder: CombatActor

var _thrower: CombatActor
var _throw_move: MoveData
var _flying: bool = false
var _mesh: MeshInstance3D


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
	_mesh = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.028
	cylinder.bottom_radius = 0.028
	cylinder.height = length
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.4
	cylinder.material = material
	_mesh.mesh = cylinder
	add_child(_mesh)
	_set_ground_physics()


func is_available() -> bool:
	return holder == null and not _flying


## Attach to `actor`'s grip. The pipe's long axis points from grip to tip.
func attach_to(actor: CombatActor) -> void:
	holder = actor
	_flying = false
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
	_flying = true
	collision_layer = CombatTypes.bit(CombatTypes.LAYER_PROJECTILE)
	collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	linear_velocity = velocity
	angular_velocity = actor.get_forward().cross(Vector3.UP) * -14.0


func break_apart() -> void:
	queue_free()


func _set_ground_physics() -> void:
	freeze = false
	collision_layer = CombatTypes.bit(CombatTypes.LAYER_PICKUP)
	collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)


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
			hit.contact_point = global_position
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
				TimeController.hitstop([victim], Tuning.data.hitstop_s(_throw_move.tier))
				CombatEvents.hit_landed.emit(hit)
		linear_velocity *= -0.2
	_flying = false
	_set_ground_physics.call_deferred()
	if durability <= 0:
		CombatEvents.weapon_broke.emit(_thrower, self)
		break_apart()
