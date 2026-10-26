class_name Kicker
extends EnemyActor
## The Kicker (Milestone 3, SPEC §7): the fast flanker. 25 HP, no armor, so a light hit knocks it
## out of its wind-up. Two attacks: the jump kick (a held crouch, then a leap of 1.6 m with the
## right foot out, 8, a flinch) and the low sweep (a held drop to the floor, then a low spin that
## takes a standing player's legs out, 8, a knockdown; a jumping player passes over it). It
## prefers the player's blind side: the director gives it the slots nearest directly behind first,
## and it gets there by walking round the posture ring at a fast pace, visibly leaving the view
## at its edge, never through the player. Told from the Punk by a lime jacket with near-black
## accents (SPEC §10 reserves red) and a higher voice.
##
## What is the Kicker's own, beside the data (hooks, as the Punk): the way round to its slot
## (_posture_target() hands the walk a point on the ring a few tens of degrees ahead rather than
## the slot across the player, _enter_posture() keeps walking until the slot is near) and which
## way it strafes when it is in view (toward the nearer edge of the view). Everything else is
## EnemyActor's.

## The jacket and the accents (cap, wrist wraps, shoes), distinct from the dummy's orange, the
## player's blue and the Punk's.
@export var color: Color = Color(0.55, 0.84, 0.14)
@export var accent: Color = Color(0.1, 0.12, 0.1)

## The way round to its slot (see _orbit_toward()): a point on the ring it is walking to, kept as
## an angle and radius about the player (so it goes with him when he walks), and the physics frame
## in which _posture_target() last handed the walk such a point rather than the goal itself (an
## arrival is only an arrival at a point on the way round in that same frame, whoever calls
## _enter_posture() from another frame goes to the posture).
var _orbit_active: bool = false
var _orbit_angle: float = 0.0
var _orbit_radius: float = 0.0
var _orbit_frame: int = -1


func _ready() -> void:
	archetype = &"kicker"
	prefers_blind_side = true
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _build_attacks() -> Array[EnemyAttack]:
	return [
		EnemyAttack.of(&"jump kick", [&"kicker_jump_kick"]),
		EnemyAttack.of(&"sweep", [&"kicker_sweep"], &"kicker_sweep_chance"),
	]


func _health_tunable() -> StringName:
	return &"kicker_health"


func _speed_tunable() -> StringName:
	return &"kicker_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"kicker_attack_cooldown_s"


func _circle_mult() -> float:
	return Tuning.data.kicker_circle_mult


# --- The way round -----------------------------------------------------------------------------


## Where to walk to take up the ring: the slot (or whatever the base picked: a detour, the nearest
## spot of the ring) when the straight way there is clear of the player, otherwise a point on the
## ring kicker_orbit_lead_deg ahead of it on the short way round, so it circles the player at the
## ring's radius instead of crossing his front on the straight line to a slot behind him.
func _posture_target(player: CombatActor) -> Vector3:
	var goal := super._posture_target(player)
	var round_the_ring := _orbit_toward(player, goal)
	if round_the_ring.is_finite():
		_orbit_frame = Engine.get_physics_frames()
		return round_the_ring
	return goal


## Reaching a point on the way round is not reaching the slot: it goes on (the next tick picks the
## next point, or the slot when that is near) instead of taking up the posture, which would send
## it straight back to APPROACH, a stutter at every point.
func _enter_posture() -> void:
	if _orbit_frame == Engine.get_physics_frames():
		_orbit_frame = -1
		_orbit_active = false
		_progress_best = INF
		_progress_frames = 0
		return
	super._enter_posture()


## The point to walk to on the ring toward `goal`, or Vector3.INF when the straight way to it is
## the way to go: `goal` is no more than the orbit lead round the ring from it, or the line to it
## keeps the ring's near edge between it and the player. A point once chosen is kept, as an angle
## about the player, until it is reached or the goal turns out to lie the other way.
func _orbit_toward(player: CombatActor, goal: Vector3) -> Vector3:
	var centre := player.global_position
	var mine := _flat(global_position - centre)
	var wanted := _flat(goal - centre)
	var lead := deg_to_rad(Tuning.data.kicker_orbit_lead_deg)
	var gap := _signed_angle(mine, wanted) if mine.length() > 0.01 and wanted.length() > 0.01 else 0.0
	if absf(gap) <= lead or _passes_clear_of(centre, global_position, goal):
		_orbit_active = false
		return Vector3.INF
	if _orbit_active:
		var ahead := _signed_angle(mine, Vector3.RIGHT.rotated(Vector3.UP, _orbit_angle))
		if signf(ahead) == signf(gap) and absf(ahead) < absf(gap):
			return _orbit_position(centre)
	var direction := mine.normalized().rotated(Vector3.UP, lead * signf(gap))
	_orbit_angle = _signed_angle(Vector3.RIGHT, direction)
	_orbit_radius = clampf(mine.length(), Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m)
	_orbit_active = true
	return _orbit_position(centre)


func _orbit_position(centre: Vector3) -> Vector3:
	var spot := centre + Vector3.RIGHT.rotated(Vector3.UP, _orbit_angle) * _orbit_radius
	spot.y = global_position.y
	return spot


## True when the straight line from `from` to `to` stays at least the posture ring's near edge
## from `centre` (flat).
static func _passes_clear_of(centre: Vector3, from: Vector3, to: Vector3) -> bool:
	var closest := Geometry3D.get_closest_point_to_segment(_flat(centre), _flat(from), _flat(to))
	return _flat_dist(closest, centre) >= Tuning.data.posture_ring_min_m


## Strafing in view: toward the nearer edge of the view, so it works its way out of sight (a
## strafe segment is short, so it keeps heading that way until it is out). Out of view it strafes
## as any enemy does.
func _pick_strafe_dir() -> float:
	var player := _find_player()
	if player and player.has_method(&"is_outside_view") and player.has_method(&"look_bearing_deg") \
			and not player.call(&"is_outside_view", global_position, Tuning.data.rear_warning_angle_deg):
		var away := _flat(global_position - player.global_position)
		if away.length() > 0.01:
			# The tangent the base strafes along for _strafe_dir = +1, and which way it moves the bearing.
			var tangent := Vector3(-away.normalized().z, 0.0, away.normalized().x)
			var now := absf(float(player.call(&"look_bearing_deg", global_position)))
			var later := absf(float(player.call(&"look_bearing_deg", global_position + tangent * 0.5)))
			if not is_equal_approx(now, later):
				return 1.0 if later > now else -1.0
	return super._pick_strafe_dir()


## The signed flat angle (radians) from `a` to `b` about +Y, wrapped to -PI..PI.
static func _signed_angle(a: Vector3, b: Vector3) -> float:
	return a.signed_angle_to(b, Vector3.UP)
