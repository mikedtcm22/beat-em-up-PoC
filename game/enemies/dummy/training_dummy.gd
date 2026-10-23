class_name TrainingDummy
extends CombatActor
## A training target (Milestone 1). Full hit reactions, health from Tuning, revives after a
## KO, faces the player, and walks back to its post when left alone.
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
var _idle_frames: int = 0
var _jab: MoveData
## The jab with its startup scaled by Tuning.windup_mult, for the multiplier it was built for.
var _scaled_jab: MoveData
var _scaled_for: float = 1.0
## Sim frames until the next jab, re-armed when a jab starts; counts down while the player
## is in sparring reach or the dummy is busy with its jab (_tick_spar_clock()).
var _spar_wait: int = 0
var _rng := RandomNumberGenerator.new()
## set_post() made the body a ghost until the physics step has moved it (see there).
var _solid_after_step: bool = false


func _ready() -> void:
	team = 1
	add_to_group(&"enemy")
	max_health = Tuning.data.dummy_health
	super._ready()
	_home = global_position
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
		_solid_after_step = false
		# Unless it went down, flew or was grabbed in the meantime (those stay ghosts).
		if not (is_flying() or is_downed() or is_ko() or state in [
				CombatTypes.ActorState.GETUP, CombatTypes.ActorState.GRABBED]):
			_set_ghost(false)
	super._physics_process(delta)


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _tick_control() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CombatActor
	var partner := _sparring_partner(player)
	_tick_spar_clock(partner)
	if state != CombatTypes.ActorState.FREE:
		_idle_frames = 0
		return
	if partner:
		_idle_frames = 0
		_spar(partner)
		return
	_idle_frames += 1
	var to_home := _home - global_position
	to_home.y = 0.0
	if return_home and _idle_frames > 60 and to_home.length() > 0.3:
		_walk(to_home.normalized(), 6.0)
		return
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	if face_player and player:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			_turn_toward(to_player.normalized(), 4.0)
	rig.play_locomotion(Vector2.ZERO, 0.0)


## Move the dummy and make `pos` the post it walks back to. With `fresh`, also reset it
## to standing at full health (bots and tests stage dummies this way).
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
	_home = pos
	sim_velocity = Vector3.ZERO
	_idle_frames = 0


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
		_walk(dir, 4.0 if face_player else 0.0)
		return
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	if face_player:
		_turn_toward(dir, 4.0)
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
	if state_frame >= int(Tuning.data.dummy_revive_s * 60.0):
		_revive()


func _revive() -> void:
	max_health = Tuning.data.dummy_health
	health = max_health
	rig.set_hurtboxes_enabled(true)
	CombatEvents.health_changed.emit(self, health, max_health)
	CombatEvents.revived.emit(self)
	_start_getup()


## Rotate toward a horizontal direction at `rate` radians per second.
func _turn_toward(dir: Vector3, rate: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var step := rate / Engine.physics_ticks_per_second
	rotation.y = wrapf(rotation.y + clampf(diff, -step, step), -PI, PI)
