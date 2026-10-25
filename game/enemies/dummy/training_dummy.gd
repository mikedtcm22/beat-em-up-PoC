class_name TrainingDummy
extends CombatActor
## A training target (Milestone 1). Full hit reactions, health from Tuning, faces the
## player, and walks back to its post when left alone (not while someone stands on it or in
## its way, and it gives up a walk that goes nowhere: _walk_home()). KO'd, it lies, blinks off like every
## enemy (CombatActor), and Tuning.dummy_revive_s later blinks back in standing at its post
## (set_post()), or beside it when someone stands there (clear of him, in his view:
## _respawn_spot()), at full health, its damage look clean (_respawn()).
##
## Sparring (`sparring`, F5 in the test room): with the player within Tuning.sparring_range
## in front of it, the dummy walks in (facing the player, at Tuning.dummy_walk_speed) until
## the player is within Tuning.sparring_step_in_m, inside its jab's reach, and throws a
## telegraphed jab (DUMMY_JAB_PATH) every Tuning.sparring_interval_s from one jab's start
## to the next, give or take a seeded Tuning.sparring_jitter_s. The jab's startup is its
## wind-up (ActorState.WINDUP, scaled by Tuning.windup_mult), so the player can block,
## dodge or hit it out of it. It only steps straight in, never moves to flank. This is the
## first piece of Milestone 3's enemy-attack plumbing.

const DUMMY_JAB_PATH := "res://game/combat/moves/dummy_jab.tres"
const DUMMY_JAB_ID := &"dummy_jab"
## A body drawn lying (_has_room()), as segments between rig points: trunk, legs, arms.
const _DRAWN_LIMBS: Array[Array] = [
	[&"Hips", &"HeadTopPoint"], [&"Hips", &"LeftFootPoint"], [&"Hips", &"RightFootPoint"],
	[&"ChestPoint", &"LeftFistPoint"], [&"ChestPoint", &"RightFistPoint"],
]

@export var face_player: bool = true
@export var return_home: bool = true
@export var color: Color = Color(0.86, 0.5, 0.16)
@export var accent: Color = Color(0.16, 0.16, 0.18)
## Throws telegraphed jabs at the player (see the class docs).
@export var sparring: bool = false:
	set(value):
		if value != sparring:
			sparring = value
			_spar_wait = _next_spar_wait()

var _home: Vector3
## The yaw it comes back at after a KO (set_post()).
var _home_yaw: float = 0.0
var _idle_frames: int = 0
## The walk back to the post (_walk_home()): the nearest it has got to the post on this
## walk (INF between walks) and the sim frames since it last got nearer.
var _home_walk_best: float = INF
var _home_walk_stalled: int = 0
## Where it gave up a walk home (something fixed in the way): it tries no more until it is hit
## or moved Tuning.dummy_return_retry_moved_m from here. INF: no give-up to remember.
var _home_gave_up_at: Vector3 = Vector3.INF
var _jab: MoveData
## The jab with its startup scaled by Tuning.windup_mult, for the multiplier it was built for.
var _scaled_jab: MoveData
var _scaled_for: float = 1.0
## Sim frames until the next jab, re-armed when a jab starts; counts down while the player
## is in sparring reach or the dummy is busy with its jab (_tick_spar_clock()).
var _spar_wait: int = 0
var _rng := RandomNumberGenerator.new()
## set_post() made the body a ghost until the physics step has moved it (see there); a
## comeback (_respawn()) keeps it one until its blink-in is over and no standing body is
## inside it (_turn_solid()).
var _solid_after_step: bool = false
var _solid_when_clear: bool = false
## Built once (_respawn_spot(), _turn_solid(), _body_in_the_way()): the body's capsule where
## it would stand, the way along the floor from the post to a spot beside it, the ray down to
## the floor under that spot (those two against the world only), and the way a step toward
## the post (against the standing bodies only).
var _room_query: PhysicsShapeQueryParameters3D
var _way_query: PhysicsShapeQueryParameters3D
var _floor_query: PhysicsRayQueryParameters3D
var _ahead_query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	team = 1
	add_to_group(&"enemy")
	max_health = Tuning.data.dummy_health
	super._ready()
	_home = global_position
	_home_yaw = rotation.y
	_rng.seed = hash(String(name))
	if ResourceLoader.exists(DUMMY_JAB_PATH):
		_jab = load(DUMMY_JAB_PATH) as MoveData
	_spar_wait = _next_spar_wait()
	Tuning.changed.connect(_on_tuning_changed)


## Milestone 2 tuning panel: a new Tuning.dummy_health applies at once, keeping the share of
## health left (max_health is otherwise read only at start and on revive), and an edit of the
## jab's move data drops the wind-up-scaled copy, rebuilt on its next use.
func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or String(property).begins_with("%s%s/" % [Tuning.MOVE_PREFIX, DUMMY_JAB_ID]):
		_scaled_jab = null
	if property != &"dummy_health" and property != &"":
		return
	if is_equal_approx(max_health, Tuning.data.dummy_health):
		return
	var share := health / max_health if max_health > 0.0 else 1.0
	max_health = Tuning.data.dummy_health
	health = max_health * share
	CombatEvents.health_changed.emit(self, health, max_health)


func _physics_process(delta: float) -> void:
	if _solid_after_step:
		_turn_solid()
	super._physics_process(delta)


## A ghost after set_post() turns solid once the physics step has moved it, unless it went
## down, flew or was grabbed in the meantime (those stay ghosts). After a comeback it waits
## for the end of its blink-in, and for any standing body that walked into it meanwhile (a
## ghost can be walked through) to step out, instead of shoving it away.
func _turn_solid() -> void:
	if is_blinking_in():
		return
	if not (is_flying() or is_downed() or is_ko() or state in [
			CombatTypes.ActorState.GETUP, CombatTypes.ActorState.GRABBED]):
		if _solid_when_clear and _standing_body_inside():
			return
		_set_ghost(false)
	_solid_after_step = false
	_solid_when_clear = false


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _tick_control() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CombatActor
	var partner := _sparring_partner(player)
	_tick_spar_clock(partner)
	if state != CombatTypes.ActorState.FREE:
		_idle_frames = 0
		_home_gave_up_at = Vector3.INF
		return
	if partner:
		_idle_frames = 0
		_spar(partner)
		return
	_idle_frames += 1
	if return_home and _walk_home():
		return
	_home_walk_best = INF
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	if face_player and player:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			_turn_toward(to_player.normalized(), Tuning.data.dummy_face_turn_rate)
	rig.play_locomotion(Vector2.ZERO, 0.0)


## Left alone for Tuning.dummy_return_idle_s and further than Tuning.dummy_return_slack_m
## from its post: walk toward it. Stays where it is while the post has no room (someone is
## standing on it: a walk would only push against him) and while a standing body is in the
## way (_body_in_the_way(): it waits, facing the player, until he steps aside, rather than
## walk into him). A walk that gets no nearer for Tuning.dummy_return_stuck_s (something
## fixed is in the way: a crate, a wall) is given up for good: it stands there until it is
## hit or moved Tuning.dummy_return_retry_moved_m from where it gave up, so it bumps into
## the thing once, not every idle time. True when it walked this tick.
func _walk_home() -> bool:
	var tuning := Tuning.data
	var to_home := _home - global_position
	to_home.y = 0.0
	var dist := to_home.length()
	if _idle_frames <= roundi(tuning.dummy_return_idle_s * Engine.physics_ticks_per_second) \
			or dist <= tuning.dummy_return_slack_m or not _home_has_room():
		return false
	if _home_gave_up_at.is_finite():
		if Vector2(global_position.x - _home_gave_up_at.x, global_position.z - _home_gave_up_at.z).length() \
				< tuning.dummy_return_retry_moved_m:
			return false
		_home_gave_up_at = Vector3.INF
	var dir := to_home / dist
	if _body_in_the_way(dir, dist):
		return false
	# Any nearer than before counts, to a millimetre's float noise.
	if dist < _home_walk_best - 0.001:
		_home_walk_best = dist
		_home_walk_stalled = 0
	else:
		_home_walk_stalled += 1
		if _home_walk_stalled > roundi(tuning.dummy_return_stuck_s * Engine.physics_ticks_per_second):
			_home_walk_best = INF
			_home_walk_stalled = 0
			_home_gave_up_at = global_position
			return false
	_walk(dir, tuning.dummy_return_turn_rate)
	return true


## Whether a standing body (the player's, another dummy's) is in the way of the next
## Tuning.dummy_return_look_ahead_m (at most `dist`) along the flat `dir`: the body's capsule
## cast that far against the standing bodies. A body it already touches does not count for
## the cast, so one pressed against it is also looked for in the capsule's own place.
func _body_in_the_way(dir: Vector3, dist: float) -> bool:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return false
	_build_room_queries()
	var lift := Vector3.UP * (body_height * 0.5 + _GETUP_FLOOR_CLEARANCE)
	_ahead_query.transform = Transform3D(Basis.IDENTITY, global_position + lift)
	_ahead_query.motion = dir * minf(dist, Tuning.data.dummy_return_look_ahead_m)
	return space.cast_motion(_ahead_query)[0] < 1.0


## Whether the post has room for the dummy to stand on (_has_room(): nobody standing, lying,
## held or flying there, no wall).
func _home_has_room() -> bool:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return true
	_build_room_queries()
	return _has_room(space, _home)


## Move the dummy and make `pos` (facing `yaw`) the post it walks back to and comes back
## at after a KO. With `fresh`, also reset it to standing at full health (bots and tests
## stage dummies this way).
func set_post(pos: Vector3, yaw: float = rotation.y, fresh: bool = false) -> void:
	global_position = pos
	rotation.y = yaw
	if fresh:
		reset_state()
		_spar_wait = _next_spar_wait()
	# The physics server moves a kinematic body to its new spot during the next physics
	# step. Until then a solid body would collide where it stood (a held dummy, inside its
	# holder, would shove the holder away): it stays a ghost for that step.
	if collision_layer != CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY):
		_set_ghost(true)
		_solid_after_step = true
	_solid_when_clear = false
	_home = pos
	_home_yaw = yaw
	sim_velocity = Vector3.ZERO
	_idle_frames = 0
	_home_gave_up_at = Vector3.INF


## Throw the next sparring jab after `frames` sim frames of the player in reach (0 = as
## soon as it is). Bots and tests time the dummy this way.
func spar_in(frames: int) -> void:
	_spar_wait = maxi(frames, 0)


## Start the telegraphed jab now (from FREE), whatever the sparring timer says.
func start_jab() -> void:
	var move := _jab_move()
	if move == null or state != CombatTypes.ActorState.FREE:
		return
	_spar_wait = _next_spar_wait()
	start_move(move, 1, &"root", true)


func debug_state_text() -> String:
	var text := super.debug_state_text()
	if sparring and state == CombatTypes.ActorState.FREE:
		text += "\nsparring %.1f s" % (_spar_wait / float(Engine.physics_ticks_per_second))
	return text


## `player` when this dummy spars with it now: sparring, the player within
## Tuning.sparring_range and Tuning.sparring_facing_deg of the dummy's facing, and open to
## the jab (not dodging through it, down or KO'd). Otherwise null.
func _sparring_partner(player: CombatActor) -> CombatActor:
	if not sparring or player == null or _jab_move() == null:
		return null
	if not player.can_be_hit_by(self, _jab_move()):
		return null
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > Tuning.data.sparring_range or to_player.length_squared() < 0.0001:
		return null
	if rad_to_deg(get_forward().angle_to(to_player.normalized())) > Tuning.data.sparring_facing_deg:
		return null
	return player


## The jab clock runs from one jab's start to the next: through the jab itself and its
## blocked recoil, and otherwise while `partner` is in sparring reach (it waits while the
## player is away).
func _tick_spar_clock(partner: CombatActor) -> void:
	if not sparring or _spar_wait <= 0:
		return
	var jabbing := current_move != null and current_move.id == DUMMY_JAB_ID
	if partner or jabbing or (_recoiling and state == CombatTypes.ActorState.HITSTUN):
		_spar_wait -= 1


## FREE with a sparring partner: face it, walk in until it is within
## Tuning.sparring_step_in_m, and jab when the clock is due.
func _spar(partner: CombatActor) -> void:
	var to_player := partner.global_position - global_position
	to_player.y = 0.0
	var dir := to_player.normalized()
	if to_player.length() > Tuning.data.sparring_step_in_m:
		_walk(dir, Tuning.data.dummy_face_turn_rate if face_player else 0.0)
		return
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	if face_player:
		_turn_toward(dir, Tuning.data.dummy_face_turn_rate)
	if _spar_wait <= 0:
		start_jab()
		return
	rig.play_locomotion(Vector2.ZERO, 0.0)


## Walk along the horizontal `dir` at Tuning.dummy_walk_speed, turning toward it at
## `turn_rate` radians per second.
func _walk(dir: Vector3, turn_rate: float) -> void:
	sim_velocity.x = dir.x * Tuning.data.dummy_walk_speed
	sim_velocity.z = dir.z * Tuning.data.dummy_walk_speed
	if turn_rate > 0.0:
		_turn_toward(dir, turn_rate)
	rig.play_locomotion(Vector2(0.0, 1.0), Tuning.data.dummy_walk_speed / Tuning.data.move_speed)


## The jab, its startup (the wind-up) scaled by Tuning.windup_mult.
func _jab_move() -> MoveData:
	if _jab == null:
		return null
	var mult := Tuning.data.windup_mult
	if is_equal_approx(mult, 1.0):
		return _jab
	if _scaled_jab == null or not is_equal_approx(_scaled_for, mult):
		_scaled_jab = _jab.duplicate() as MoveData
		_scaled_jab.startup = maxi(1, roundi(_jab.startup * mult))
		_scaled_for = mult
	return _scaled_jab


## Sim frames until the next jab: the interval, give or take the seeded jitter.
func _next_spar_wait() -> int:
	var seconds := Tuning.data.sparring_interval_s
	seconds += _rng.randf_range(-1.0, 1.0) * Tuning.data.sparring_jitter_s
	return maxi(1, roundi(seconds * Engine.physics_ticks_per_second))


func _tick_ko() -> void:
	if not is_gone() or _gone_frames < roundi(Tuning.data.dummy_revive_s * Engine.physics_ticks_per_second):
		return
	var spot := _respawn_spot()
	if spot.is_finite():
		_respawn(spot)


## Where the dummy comes back: its post, or, when someone is there (standing, lying, held,
## flying, or another dummy blinking back in; the player who knocked it out often stands on
## it), the nearest spot around it with room for its body, floor under it and no wall or
## curb on the way from the post: one, then two body widths plus Tuning.dummy_respawn_gap_m
## out, so a body on the post is never touched. Of the spots of the one ring (or the two,
## when the first has none in the player's view) the one in front of the player or beside
## him wins over any behind him, the one farthest from him first, and with several as far
## (a player on the post sees every spot of a ring at the same distance) the one whose angle
## off his facing is nearest Tuning.dummy_respawn_off_axis_deg: off-centre but in view, as dead
## ahead at that distance filled over half of his first-person view (the player's facing from
## the simulation, never a camera). Vector3.INF while there is none; it waits.
func _respawn_spot() -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return _home
	_build_room_queries()
	if _has_room(space, _home):
		return _home
	var player := get_tree().get_first_node_in_group(&"player") as CombatActor
	var facing := player.get_forward() if player else Vector3.ZERO
	var lift := Vector3.UP * (body_height * 0.5 + _GETUP_FLOOR_CLEARANCE)
	var best := Vector3.INF
	var best_ring := 0
	var best_in_view := false
	var best_d := -INF
	var best_off_axis := INF
	for ring: int in [1, 2]:
		# A spot in the player's view is already taken: the next ring only offers more of the same.
		if best.is_finite() and best_in_view:
			break
		for k: int in _GETUP_DIRECTIONS:
			var spot := _home + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / _GETUP_DIRECTIONS) \
					* (body_radius * 2.0 + Tuning.data.dummy_respawn_gap_m) * ring
			if not _has_room(space, spot):
				continue
			_way_query.transform = Transform3D(Basis.IDENTITY, _home + lift)
			_way_query.motion = spot - _home
			if space.cast_motion(_way_query)[0] < 1.0:
				continue
			# Floor under it, at the post's level (give or take a step the body would snap down).
			_floor_query.from = spot + lift
			_floor_query.to = spot + Vector3.DOWN * floor_snap_length
			var ground := space.intersect_ray(_floor_query)
			if ground.is_empty():
				continue
			spot.y = (ground.position as Vector3).y
			var d := 0.0
			var ahead := 0.0
			# How far its angle off his facing is from the one that is wanted.
			var off_axis := 0.0
			if player:
				var to_spot := spot - player.global_position
				to_spot.y = 0.0
				d = to_spot.length()
				ahead = to_spot.normalized().dot(facing) if d > 0.0001 else 1.0
				if d > 0.0001:
					off_axis = absf(rad_to_deg(facing.angle_to(to_spot)) - Tuning.data.dummy_respawn_off_axis_deg)
			var in_view := ahead >= 0.0
			# Spots within a millimetre are as far: a body standing on the post sees every
			# spot of a ring at the same distance. The first of equal ones stays.
			var better := false
			if not best.is_finite():
				better = true
			elif in_view != best_in_view:
				better = in_view
			elif ring == best_ring:
				better = d > best_d + 0.001 or (d > best_d - 0.001 and off_axis < best_off_axis - 0.01)
			if better:
				best = spot
				best_ring = ring
				best_in_view = in_view
				best_d = d
				best_off_axis = off_axis
	return best


## Whether the body has room standing at `spot`: no world, no body (standing, or a ghost:
## lying, held, flying, getting up or blinking in) in its capsule, no body drawn lying there
## (a ragdoll lies beside its upright capsule) and no other actor that came back there this
## tick (its physics body moves there in the next step).
func _has_room(space: PhysicsDirectSpaceState3D, spot: Vector3) -> bool:
	_room_query.collision_mask = (
		CombatTypes.bit(CombatTypes.LAYER_WORLD)
		| CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY)
		| CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
		| CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY)
	)
	_room_query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * (body_height * 0.5 + _GETUP_FLOOR_CLEARANCE))
	if not space.intersect_shape(_room_query, 1).is_empty():
		return false
	var flat_spot := Vector3(spot.x, 0.0, spot.z)
	for node: Node in get_tree().get_nodes_in_group(&"actor"):
		var other := node as CombatActor
		if other == null or other == self or other.is_gone() or other.rig == null:
			continue
		var reach := body_radius + other.body_radius
		var at := other.global_position
		if other.is_blinking_in() and Vector2(at.x - spot.x, at.z - spot.z).length() < reach:
			return false
		# Lying or flying: drawn by its full ragdoll (or, without one, the animation's pose).
		if not (other.is_downed() or other.is_ko() or other.is_flying() or other.rig.ragdoll_mode() == Ragdoll.Mode.FULL):
			continue
		# The drawn body along the floor: trunk, legs and arms (spread out, lying), each kept
		# the two bodies' radii away.
		for limb: Array in _DRAWN_LIMBS:
			var from := other.rig.get_visual_point_transform(limb[0]).origin
			var to := other.rig.get_visual_point_transform(limb[1]).origin
			from.y = 0.0
			to.y = 0.0
			if Geometry3D.get_closest_point_to_segment(flat_spot, from, to).distance_to(flat_spot) < reach:
				return false
	return true


## A standing (solid) body is inside this one's capsule where it stands.
func _standing_body_inside() -> bool:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return false
	_build_room_queries()
	_room_query.collision_mask = (
		CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	)
	_room_query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (body_height * 0.5 + _GETUP_FLOOR_CLEARANCE))
	return not space.intersect_shape(_room_query, 1).is_empty()


## The room, way, floor and ahead queries, built on first use and kept (see their declarations).
func _build_room_queries() -> void:
	if _room_query != null:
		return
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius
	shape.height = body_height
	_room_query = PhysicsShapeQueryParameters3D.new()
	_room_query.shape = shape
	_room_query.collide_with_areas = false
	_room_query.exclude = [get_rid()]
	_way_query = PhysicsShapeQueryParameters3D.new()
	_way_query.shape = shape
	_way_query.collide_with_areas = false
	_way_query.collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	_way_query.exclude = [get_rid()]
	_floor_query = PhysicsRayQueryParameters3D.new()
	_floor_query.collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	_floor_query.exclude = [get_rid()]
	_ahead_query = PhysicsShapeQueryParameters3D.new()
	_ahead_query.shape = shape
	_ahead_query.collide_with_areas = false
	_ahead_query.collision_mask = CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	_ahead_query.exclude = [get_rid()]


## Back from a KO: standing at `spot` (its post, or beside it), facing as it was posted, at
## full health (Tuning.dummy_health; the damage look follows the health), blinking in, a
## ghost until that is over (_turn_solid()). The post stays where it was.
func _respawn(spot: Vector3) -> void:
	max_health = Tuning.data.dummy_health
	var post := _home
	set_post(spot, _home_yaw, true)
	_home = post
	_solid_after_step = true
	_solid_when_clear = true
	CombatEvents.revived.emit(self)
	blink_in()


## Rotate toward a horizontal direction at `rate` radians per second.
func _turn_toward(dir: Vector3, rate: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var step := rate / Engine.physics_ticks_per_second
	rotation.y = wrapf(rotation.y + clampf(diff, -step, step), -PI, PI)
