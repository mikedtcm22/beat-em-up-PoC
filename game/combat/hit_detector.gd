class_name HitDetector
extends RefCounted
## Runs a move's hitboxes during its active frames: shape queries against hurtboxes, at
## most one hit per victim per activation, HitInfo construction, hitstop and events.
## Point hitboxes also test the midpoint from the previous frame so fast limbs can't
## tunnel through a target between frames.

var attacker: CombatActor
## Victims hit during the current activation.
var landed: int = 0

var _hit_ids: Dictionary[int, bool] = {}
var _prev_centers: Dictionary[int, Vector3] = {}
var _sphere: SphereShape3D = SphereShape3D.new()
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()


func _init(owner_actor: CombatActor) -> void:
	attacker = owner_actor
	_query.shape = _sphere
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = CombatTypes.bit(CombatTypes.LAYER_HURTBOX)


## Reset per-activation state; call when a move starts.
func begin() -> void:
	_hit_ids.clear()
	_prev_centers.clear()
	landed = 0


## Test every hitbox of `move` at the attacker's current pose. Applies and returns the hits.
func process(move: MoveData, move_frame: int) -> Array[HitInfo]:
	var volumes: Array[Dictionary] = []
	var candidates: Dictionary[int, Dictionary] = {}
	var space := attacker.get_world_3d().direct_space_state
	for i in move.hitboxes.size():
		var spec := move.hitboxes[i]
		if spec.kind == HitboxSpec.Kind.ARC:
			_query_arc(spec, move, space, candidates, volumes)
		else:
			_query_point(spec, i, move, space, candidates, volumes)
	attacker.debug_hitbox_volumes = volumes

	var hits: Array[HitInfo] = []
	if candidates.is_empty():
		return hits
	var ordered: Array[Dictionary] = []
	ordered.assign(candidates.values())
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)
	# Clean hits freeze with the attacker for the tier's hitstop; blocked hits only for the
	# short block hitstop (and never start the finisher slow-mo). An armored victim that
	# absorbed the hit (hit.armor_absorbed) never freezes: the strike still feels solid to the
	# attacker, but a jab would otherwise stretch a Bruiser's wind-up, and its rear warning.
	var frozen: Array = [attacker]
	var guarded: Array = [attacker]
	var blocked: HitInfo
	var clean := false
	# A clean hit the victim felt (not absorbed by armor, or killing): only those start the
	# finisher's slow-mo, which would otherwise slow down a grey spark and nothing else.
	var felt := false
	for c: Dictionary in ordered:
		if move.max_targets > 0 and landed >= move.max_targets:
			break
		var victim: CombatActor = c.actor
		var hit := _build_hit(move, move_frame, victim, c.hurtbox, c.sample)
		if victim.receive_hit(hit):
			_hit_ids[victim.get_instance_id()] = true
			landed += 1
			hits.append(hit)
			if hit.blocked:
				guarded.append(victim)
				# The attacker answers the strongest block: a perfect one, else an ordinary one.
				if blocked == null or (hit.perfect_block and not blocked.perfect_block) or blocked.guard_broken:
					blocked = hit
			else:
				clean = true
				if not hit.armor_absorbed or hit.killed:
					frozen.append(victim)
					felt = true
	if hits.is_empty():
		return hits
	if clean:
		var stop := Tuning.data.hitstop_s(move.tier)
		TimeController.hitstop(frozen, stop)
		if felt and move.tier == CombatTypes.HitTier.FINISHER and Tuning.data.slowmo_ms > 0.0:
			TimeController.slowmo(Tuning.data.slowmo_scale, Tuning.data.slowmo_ms / 1000.0, stop)
	if guarded.size() > 1:
		TimeController.hitstop(guarded, Tuning.data.block_hitstop_ms / 1000.0)
	for hit in hits:
		CombatEvents.hit_landed.emit(hit)
	# Every hit of this frame was blocked: the attack recoils (or staggers on a parry).
	if blocked and not clean:
		attacker.react_to_block(blocked)
	return hits


## Hitstop for one code-applied hit (body impacts, throws, thrown weapons): the tier's,
## or the short block hitstop when the guard stopped it.
static func hitstop_for(hit: HitInfo) -> float:
	if hit.blocked:
		return Tuning.data.block_hitstop_ms / 1000.0
	return Tuning.data.hitstop_s(hit.tier)


func _query_point(
	spec: HitboxSpec,
	index: int,
	move: MoveData,
	space: PhysicsDirectSpaceState3D,
	candidates: Dictionary[int, Dictionary],
	volumes: Array[Dictionary],
) -> void:
	var center := attacker.rig.get_point_transform(spec.point) * spec.offset
	volumes.append({kind = &"sphere", center = center, radius = spec.radius})
	var samples: Array[Vector3] = [center]
	if _prev_centers.has(index):
		samples.append(_prev_centers[index].lerp(center, 0.5))
	_prev_centers[index] = center
	_sphere.radius = spec.radius
	for sample in samples:
		_query.transform = Transform3D(Basis(), sample)
		for result: Dictionary in space.intersect_shape(_query, 32):
			var hurtbox := result.get("collider") as Hurtbox
			if hurtbox:
				_consider(hurtbox, sample, hurtbox.global_position.distance_to(sample), move, candidates)


func _query_arc(
	spec: HitboxSpec,
	move: MoveData,
	space: PhysicsDirectSpaceState3D,
	candidates: Dictionary[int, Dictionary],
	volumes: Array[Dictionary],
) -> void:
	var origin := attacker.global_position
	var forward := attacker.get_forward().rotated(Vector3.UP, deg_to_rad(spec.arc_center_yaw_deg))
	var h_min := spec.arc_height.x
	var h_max := spec.arc_height.y
	volumes.append({
		kind = &"arc",
		origin = origin,
		forward = forward,
		radius = spec.arc_radius,
		half_angle_deg = spec.arc_half_angle_deg,
		h_min = h_min,
		h_max = h_max,
	})
	var half_h := (h_max - h_min) * 0.5
	_sphere.radius = sqrt(spec.arc_radius * spec.arc_radius + half_h * half_h) + 0.3
	_query.transform = Transform3D(Basis(), origin + Vector3.UP * (h_min + half_h))
	for result: Dictionary in space.intersect_shape(_query, 64):
		var hurtbox := result.get("collider") as Hurtbox
		if hurtbox == null:
			continue
		var rel := hurtbox.global_position - origin
		var flat := Vector3(rel.x, 0.0, rel.z)
		var dist := flat.length()
		if dist > spec.arc_radius + hurtbox.radius:
			continue
		if rel.y < h_min - hurtbox.radius or rel.y > h_max + hurtbox.radius:
			continue
		if dist > 0.05:
			var angle := rad_to_deg(forward.angle_to(flat / dist))
			var slack := rad_to_deg(atan2(hurtbox.radius, dist))
			if angle > spec.arc_half_angle_deg + slack:
				continue
		var sample := origin + flat.limit_length(spec.arc_radius) + Vector3.UP * rel.y
		_consider(hurtbox, sample, dist, move, candidates)


func _consider(
	hurtbox: Hurtbox, sample: Vector3, dist: float, move: MoveData, candidates: Dictionary[int, Dictionary]
) -> void:
	var victim := hurtbox.actor as CombatActor
	if victim == null or victim == attacker or victim.team == attacker.team:
		return
	var id := victim.get_instance_id()
	if _hit_ids.has(id) or not victim.can_be_hit_by(attacker, move):
		return
	if candidates.has(id) and candidates[id].dist <= dist:
		return
	candidates[id] = {actor = victim, hurtbox = hurtbox, sample = sample, dist = dist}


func _build_hit(move: MoveData, move_frame: int, victim: CombatActor, hurtbox: Hurtbox, sample: Vector3) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.move = move
	hit.damage = move.damage
	hit.tier = move.tier
	hit.reaction = move.reaction
	hit.region = hurtbox.region
	var center := hurtbox.global_position
	hit.contact_point = center + (sample - center).limit_length(hurtbox.radius)
	# Knockback frame: z points from attacker to victim (radial), x is its right, y up.
	var radial := victim.global_position - attacker.global_position
	radial.y = 0.0
	radial = radial.normalized() if radial.length_squared() > 0.0001 else attacker.get_forward()
	hit.direction = radial
	hit.knockback = (
		radial.cross(Vector3.UP) * move.knockback.x
		+ Vector3.UP * move.knockback.y
		+ radial * move.knockback.z
	)
	hit.from_behind = victim.get_forward().dot(radial) > 0.0
	hit.physics_frame = Engine.get_physics_frames()
	hit.move_frame = move_frame
	hit.chain_step = attacker.move_chain_step
	hit.input_timing = attacker.move_input_timing
	return hit
