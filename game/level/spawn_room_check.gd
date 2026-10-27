class_name SpawnRoomCheck
extends RefCounted
## Whether a body has room to appear at a spot (Milestone 3): the wave spawner and the F4 menu
## ask it before putting an enemy down. Adapted from TrainingDummy._has_room(), which answers the
## same question for a dummy coming back to its post: nothing may be in the way, standing or
## lying.


## Metres the capsule is lifted off the floor, so the floor it stands on is no obstacle (the
## same margin as CombatActor's get-up clearance; a geometry epsilon, not a feel number).
const FLOOR_CLEARANCE := 0.03

## The limbs of a lying body, as segments between rig points: trunk, legs, arms.
const DRAWN_LIMBS: Array[Array] = [
	[&"Hips", &"HeadTopPoint"], [&"Hips", &"LeftFootPoint"], [&"Hips", &"RightFootPoint"],
	[&"ChestPoint", &"LeftFistPoint"], [&"ChestPoint", &"RightFistPoint"],
]


## Whether a capsule of `radius` and `height` standing at `spot` (on the floor) fits: no world
## geometry in it, no body of any kind in it (standing, or a ghost: lying, held, flying,
## getting up), no body drawn lying there (a ragdoll lies beside its upright capsule), and no
## actor that is blinking in there. `exclude` (an actor, or null) is the one body to ignore
## (an enemy that is leaving the spot, or the actor asking). The actors are read from the
## running scene tree's "actor" group.
static func has_room(space: PhysicsDirectSpaceState3D, radius: float, height: float, spot: Vector3,
		exclude: Node = null) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height - FLOOR_CLEARANCE, radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = (
		CombatTypes.bit(CombatTypes.LAYER_WORLD)
		| CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY)
		| CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
		| CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY)
	)
	query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * (FLOOR_CLEARANCE + capsule.height * 0.5))
	if exclude is CollisionObject3D:
		query.exclude = [(exclude as CollisionObject3D).get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return true
	var flat_spot := Vector3(spot.x, 0.0, spot.z)
	for node: Node in tree.get_nodes_in_group(&"actor"):
		var other := node as CombatActor
		if other == null or other == exclude or other.is_gone() or other.rig == null:
			continue
		var reach := radius + other.body_radius
		var at := other.global_position
		if other.is_blinking_in() and Vector2(at.x - spot.x, at.z - spot.z).length() < reach:
			return false
		# Lying or flying: drawn by its full ragdoll (or, without one, the animation's pose).
		if not (other.is_downed() or other.is_ko() or other.is_flying() or other.rig.ragdoll_mode() == Ragdoll.Mode.FULL):
			continue
		for limb: Array in DRAWN_LIMBS:
			var from := other.rig.get_visual_point_transform(limb[0]).origin
			var to := other.rig.get_visual_point_transform(limb[1]).origin
			from.y = 0.0
			to.y = 0.0
			if Geometry3D.get_closest_point_to_segment(flat_spot, from, to).distance_to(flat_spot) < reach:
				return false
	return true
