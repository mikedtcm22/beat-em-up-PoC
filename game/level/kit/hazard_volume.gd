class_name HazardVolume
extends Area3D
## A drop-off's kill zone (Milestone 5, D8): the volume just past an open edge's guard, from the lip
## down to a catch floor. An `EnemyActor` that enters it, in any state, is KO'd at once (a killing
## HitInfo with no attacker; a body already flying just has its health taken and lands KO'd), and
## `CombatEvents.hazard_ko` fires. A standing enemy never gets here (the guard stops it), a knocked-
## down, launched or thrown one crosses the guard and does. The catch floor is an invisible
## world-layer slab at the bottom of the volume, so the body lands there and lies out its KO; put it
## at a depth no section's floor is within the nav bake's tolerance of, or the bake keeps it as an
## island.
##
## The player is not an enemy: with the guard on he never reaches it; with `level_edge_guard` off he
## falls in, loses `level_fall_damage` health and is put back at the arena's Respawn marker, safe for
## `level_fall_invuln_s` (the fall rule). The marker is the `respawn` node's, else the level's current
## arena's. Entry is polled every physics frame, so an enemy still getting up (invulnerable) is
## KO'd the moment it can be.

const GROUP := &"hazard_volume"

## The volume's size (m), centred on this node.
@export var size: Vector3 = Vector3(3.0, 8.0, 10.0)
## What the hazard is (a drop; the room for others).
@export var kind: StringName = &"drop"
## A world-layer slab under the volume for a KO'd body to land on.
@export var catch_floor: bool = true
## The slab's thickness (m).
@export_range(0.1, 2.0, 0.1) var catch_thickness_m: float = 0.5
## Where the player is put back after a fall; empty = the level's current arena's Respawn.
@export var respawn: NodePath

## Enemies this hazard has already killed (a body is KO'd once).
var _killed: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = (
		CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY)
		| CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
		| CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY)
	)
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	shape.name = "Volume"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	if catch_floor:
		RoomKit.add_box(self, Vector3(0.0, -size.y * 0.5 - catch_thickness_m * 0.5, 0.0),
				Vector3(size.x, catch_thickness_m, size.z), null)


## Whether `point` is inside the volume.
func contains(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	var half := size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var enemy := body as EnemyActor
		if enemy:
			_kill(enemy)
		elif body is PlayerCharacter:
			_fall(body as PlayerCharacter)


## KO `enemy` now: through a killing hit, or, when it is flying (its landing KOs it), by taking its
## health. Does nothing for one already dead.
func _kill(enemy: EnemyActor) -> void:
	if enemy.health <= 0.0 or enemy.is_ko() or _killed.has(enemy.get_instance_id()):
		return
	var hit := HitInfo.new()
	hit.victim = enemy
	hit.damage = enemy.health
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.KNOCKDOWN
	hit.contact_point = enemy.global_position + Vector3.UP * enemy.body_height * 0.5
	var flat := Vector3(enemy.sim_velocity.x, 0.0, enemy.sim_velocity.z)
	hit.direction = flat.normalized() if flat.length_squared() > 1e-6 else -enemy.get_forward()
	hit.knockback = enemy.sim_velocity
	hit.is_body_impact = true
	if enemy.is_flying():
		enemy.health = 0.0
		hit.killed = true
		CombatEvents.health_changed.emit(enemy, 0.0, enemy.max_health)
		CombatEvents.ko.emit(enemy, hit)
	elif not enemy.receive_hit(hit) or enemy.health > 0.0:
		return  # invulnerable (getting up) or guarding: polled again next frame
	_killed[enemy.get_instance_id()] = true
	CombatEvents.hazard_ko.emit(enemy, self)


## The fall rule: with the guard off the player loses `level_fall_damage` (never his last health),
## goes back to the Respawn marker and is safe for `level_fall_invuln_s`. With the guard on it does
## nothing (he cannot be here).
func _fall(player: PlayerCharacter) -> void:
	if Tuning.data.level_edge_guard:
		return
	var marker := get_node_or_null(respawn) as Node3D if not respawn.is_empty() else null
	var at: Vector3
	if marker:
		at = marker.global_position
	else:
		var level := get_tree().get_first_node_in_group(&"level_root") as LevelRoot
		var arena := level.current_arena() if level else null
		if arena == null:
			return
		at = arena.respawn_position()
	var damage: float = 0.0 if Tuning.data.god_mode else Tuning.data.level_fall_damage
	var health_after := maxf(player.health - damage, minf(player.health, 1.0))
	var yaw := player.look_yaw
	player.reset_state()
	player.health = health_after
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw
	player._invuln_frames = roundi(Tuning.data.level_fall_invuln_s * Engine.physics_ticks_per_second)
	CombatEvents.health_changed.emit(player, player.health, player.max_health)
