class_name CombatActor
extends CharacterBody3D
## Base for every fighter (player, dummies, enemies): health, the hit-reaction state
## machine, move execution with hitboxes, flying-body impacts, grabs, and the sim-time
## step. Subclasses drive behavior from _tick_control() and the hooks at the bottom.
##
## Each physics tick: the actor's sim scale comes from TimeController (0 in hitstop).
## Whole sim frames run _sim_tick(); motion and animation then advance by the scaled
## delta, and hitboxes are tested against the freshly posed skeleton.

signal state_changed(old_state: int, new_state: int)

const IMPACT_KNOCKDOWN_PATH := "res://game/combat/moves/impact_body_knockdown.tres"
const IMPACT_STAGGER_PATH := "res://game/combat/moves/impact_body_stagger.tres"

## Grabbed, the body bends over into &"held" over this blend (sim seconds) while its origin
## eases in from where it stood to the holder's HoldPoint over _GRAB_EASE_S, slowly at
## first: the head drops below the holder's first-person lens (at the throat) before the
## body closes in, instead of sweeping through it.
const _HELD_BLEND_S := 0.12
const _GRAB_EASE_S := 0.23
## Released on its feet, the body stands up over this blend, around its bent-over hips
## (release_from_grab()): the head rises while the release pushes the body away, not up
## through the holder's view at arm's length.
const _RELEASE_BLEND_S := 0.22

@export var max_health: float = 100.0
## 0 = player, 1 = enemies.
@export var team: int = 1
@export var display_name: String = "Actor"
@export var body_radius: float = 0.35
@export var body_height: float = 1.8

var health: float = 100.0
var state: CombatTypes.ActorState = CombatTypes.ActorState.FREE
## Sim frames spent in the current state.
var state_frame: int = 0
var rig: HumanoidRig
var current_move: MoveData
## 0-based frame within current_move.
var move_frame: int = 0
## Chain position and input timing of current_move, copied into each HitInfo.
var move_chain_step: int = 1
var move_input_timing: StringName = &"root"
## Hitbox volumes live this sim frame, for debug draw. See ARCHITECTURE.md for the format.
var debug_hitbox_volumes: Array[Dictionary] = []
## Velocity in sim units. Physics applies it scaled by this actor's sim scale.
var sim_velocity: Vector3 = Vector3.ZERO
## The actor holding this one while GRABBED.
var holder: CombatActor

var _tick_accum: float = 0.0
## Timed states (HITSTUN, STAGGER, GETUP, DODGE) end after this many frames; 0 = untimed.
var _state_length: int = 0
var _invuln_frames: int = 0
var _hit_detector: HitDetector
var _move_landed_hit: bool = false
var _active_this_tick: bool = false
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_left: float = 0.0
## Most the lunge may still travel; _update_lunge() may re-aim within it.
var _lunge_budget: float = 0.0
var _lunge_frames_left: int = 0
var _lunge_velocity: Vector3 = Vector3.ZERO
## Reaction a flying (or shoved) body inflicts on actors it runs into; NONE when not flying.
var _flying_reaction: CombatTypes.Reaction = CombatTypes.Reaction.NONE
var _flying_source: CombatActor
var _flying_hit_ids: Dictionary[int, bool] = {}
## Lying face up (hit from the front) or face down.
var _face_up: bool = true
var _flash_frames: int = 0
## Grab ease-in (see _GRAB_EASE_S): where the body stood relative to its pin spot when it
## was grabbed (in the holder's frame), and the sim time eased so far.
var _pin_from: Vector3 = Vector3.ZERO
var _pin_ease_s: float = 0.0
var _impact_query: PhysicsShapeQueryParameters3D
var _impact_shape: CapsuleShape3D


func _ready() -> void:
	add_to_group(&"actor")
	health = max_health
	_ensure_body()
	_hit_detector = HitDetector.new(self)
	_impact_shape = CapsuleShape3D.new()
	_impact_query = PhysicsShapeQueryParameters3D.new()
	_impact_query.shape = _impact_shape
	_impact_query.collide_with_bodies = true
	_impact_query.collide_with_areas = false
	_impact_query.collision_mask = (
		CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	)
	_set_ghost(false)
	CombatEvents.health_changed.emit.call_deferred(self, health, max_health)


func _physics_process(delta: float) -> void:
	var scale := TimeController.scale_for(self)
	_tick_accum += scale
	var ticks := 0
	_active_this_tick = false
	while _tick_accum >= 0.999 and ticks < 4:
		_tick_accum -= 1.0
		ticks += 1
		_sim_tick()
	if state == CombatTypes.ActorState.GRABBED:
		_pin_to_holder(delta * scale)
	elif scale > 0.0:
		_integrate(delta * scale, scale)
	rig.advance(delta * scale)
	# The hit flash counts real ticks so it stays 2 frames even through hitstop.
	if _flash_frames > 0:
		_flash_frames -= 1
		if _flash_frames == 0:
			rig.set_flash(0.0)
	if ticks > 0:
		if _active_this_tick and current_move:
			var hits := _hit_detector.process(current_move, move_frame)
			if not hits.is_empty():
				_move_landed_hit = true
				_on_move_hits(current_move, hits)
		else:
			debug_hitbox_volumes.clear()


# --- Public API ---------------------------------------------------------------------


func is_ko() -> bool:
	return state == CombatTypes.ActorState.KO


func is_downed() -> bool:
	return state == CombatTypes.ActorState.DOWNED


func is_flying() -> bool:
	return state == CombatTypes.ActorState.LAUNCHED or state == CombatTypes.ActorState.THROWN


func is_invulnerable() -> bool:
	return _invuln_frames > 0 or state == CombatTypes.ActorState.KO


func can_be_grabbed() -> bool:
	return state == CombatTypes.ActorState.STAGGER and holder == null


## Whether `attacker`'s `move` may hit this actor right now.
func can_be_hit_by(attacker: CombatActor, move: MoveData) -> bool:
	if is_ko() or is_invulnerable() or is_flying():
		return false
	if state == CombatTypes.ActorState.GRABBED:
		return attacker == holder
	if move and move.hits_downed:
		return state == CombatTypes.ActorState.DOWNED
	return state != CombatTypes.ActorState.DOWNED


func get_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func get_head_top_position() -> Vector3:
	return rig.get_point_position(&"HeadTopPoint")


func get_chest_position() -> Vector3:
	return rig.get_point_position(&"ChestPoint")


## Apply a landed hit. Returns false if the hit was ignored.
func receive_hit(hit: HitInfo) -> bool:
	if is_ko() or is_invulnerable():
		return false
	var damage := hit.damage
	if team == 0 and Tuning.data.god_mode:
		damage = 0.0
	elif team != 0 and Tuning.data.one_hit_ko:
		damage = maxf(damage, health)
	hit.damage = damage
	health = maxf(0.0, health - damage)
	hit.killed = health <= 0.0
	CombatEvents.health_changed.emit(self, health, max_health)
	_flash_frames = Tuning.data.hit_flash_frames
	rig.set_flash(1.0 if _flash_frames > 0 else 0.0)
	if current_move:
		_cancel_move()
	_on_hit_received(hit)
	_apply_reaction(hit)
	if hit.killed:
		CombatEvents.ko.emit(self, hit)
	return true


## Begin executing `move` (from FREE, a cancellable recovery, or a chain). Call it from
## _tick_control() or a move hook: the sim tick then applies the move's frame 0.
func start_move(move: MoveData, chain_step: int = 1, input_timing: StringName = &"root") -> void:
	current_move = move
	move_frame = 0
	move_chain_step = chain_step
	move_input_timing = input_timing
	_move_landed_hit = false
	_lunge_frames_left = 0
	_lunge_velocity = Vector3.ZERO
	_hit_detector.begin()
	if state != CombatTypes.ActorState.ATTACK:
		_enter_state(CombatTypes.ActorState.ATTACK)
	else:
		state_frame = 0
	rig.play_move(move)
	_plan_lunge(move)
	CombatEvents.attack_started.emit(self, move, chain_step, input_timing)


## Lunge `distance` meters along `dir` spread over `frames` sim frames. `budget` (default
## `distance`) caps the total, so a subclass can lengthen a lunge that chases a target.
func set_lunge(dir: Vector3, distance: float, frames: int, budget: float = -1.0) -> void:
	_lunge_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_lunge_left = maxf(distance, 0.0)
	_lunge_budget = maxf(budget if budget >= 0.0 else distance, _lunge_left)
	_lunge_frames_left = maxi(frames, 1) if _lunge_budget > 0.0 else 0


## Held by `by` from now on: pinned in front of it (_pin_to_holder()), easing in from where
## it stands while it bends over into &"held".
func start_grabbed(by: CombatActor) -> void:
	if current_move:
		_cancel_move()
	holder = by
	sim_velocity = Vector3.ZERO
	_pin_from = by.global_basis.inverse() * (global_position - _pin_spot())
	_pin_from.y = 0.0
	_pin_ease_s = 0.0
	_set_ghost(true)
	_enter_state(CombatTypes.ActorState.GRABBED)
	rig.play(&"held", _HELD_BLEND_S)
	CombatEvents.grabbed.emit(by, self)


## Leave a grab on your feet, optionally staggering with `push` velocity. The body stands
## up around its bent-over hips: the origin moves under them (the pose on screen stays put,
## HumanoidRig.carry_fade()), so the head rises away from the holder instead of up through
## its first-person view.
func release_from_grab(push: Vector3, stagger: bool) -> void:
	var by := holder
	holder = null
	_set_ghost(false)
	if stagger:
		sim_velocity = Vector3(push.x, 0.0, push.z)
		_enter_state(CombatTypes.ActorState.STAGGER, Tuning.data.stagger_frames)
		rig.play(_directional_anim(&"stagger", push), _RELEASE_BLEND_S)
	else:
		_enter_state(CombatTypes.ActorState.FREE)
		rig.play(&"idle", _RELEASE_BLEND_S)
	var under_hips := rig.get_point_position(&"Hips") - global_position
	under_hips.y = 0.0
	global_position += under_hips
	rig.carry_fade(under_hips)
	rig.advance(0.0)
	CombatEvents.released.emit(by, self)


## Snap back to a fresh standing state with full health (debug tools, bots, respawns).
func reset_state() -> void:
	if current_move:
		_cancel_move()
	holder = null
	health = max_health
	sim_velocity = Vector3.ZERO
	_invuln_frames = 0
	_flying_reaction = CombatTypes.Reaction.NONE
	_flash_frames = 0
	rig.set_flash(0.0)
	_set_ghost(false)
	rig.set_hurtboxes_enabled(true)
	_enter_state(CombatTypes.ActorState.FREE)
	rig.play(&"idle", 0.0)
	CombatEvents.health_changed.emit(self, health, max_health)


func debug_state_text() -> String:
	var text := "%s  %.0f/%.0f\n%s" % [display_name, health, max_health, CombatTypes.state_name(state)]
	if current_move:
		var phase := "startup"
		if current_move.is_active(move_frame):
			phase = "ACTIVE"
		elif current_move.is_recovery(move_frame):
			phase = "recovery"
		text += " %s f%d %s" % [current_move.id, move_frame, phase]
	elif _state_length > 0:
		text += " %d/%d" % [state_frame, _state_length]
	return text


# --- Subclass hooks -----------------------------------------------------------------


## Configure the rig's exported look before it builds.
func _configure_rig(_r: HumanoidRig) -> void:
	pass


## Per sim frame, after timers and the running move have advanced: input or AI.
func _tick_control() -> void:
	pass


## A move's recovery finished. Default: return to FREE (or fall if airborne).
func _on_move_finished(_move: MoveData) -> void:
	_return_to_neutral()


## Called on every sim frame of a running move after its frame index updated.
func _on_move_frame(_move: MoveData, _frame: int) -> void:
	pass


## The running move landed `hits` this frame.
func _on_move_hits(_move: MoveData, _hits: Array[HitInfo]) -> void:
	pass


## A hit was accepted, before its reaction is applied (cancel chains, drop held things).
func _on_hit_received(_hit: HitInfo) -> void:
	pass


## Decide this move's lunge (magnetism) right after it starts.
func _plan_lunge(move: MoveData) -> void:
	if move.free_lunge > 0.0:
		set_lunge(get_forward(), move.free_lunge, maxi(move.startup, 1))


## Refresh lunge direction/distance each frame (e.g. to follow a moving target).
func _update_lunge() -> void:
	pass


## Sim frames spent KO'd; dummies revive from here.
func _tick_ko() -> void:
	pass


## Whether AIRBORNE ends automatically on touching the floor (the player lands itself).
func _auto_land() -> bool:
	return true


# --- Simulation step ----------------------------------------------------------------


func _sim_tick() -> void:
	state_frame += 1
	if _invuln_frames > 0:
		_invuln_frames -= 1
	_tick_reaction_timers()
	if state == CombatTypes.ActorState.ATTACK and current_move:
		_advance_move()
	_tick_control()
	if state == CombatTypes.ActorState.ATTACK and current_move:
		_apply_move_frame()


func _tick_reaction_timers() -> void:
	match state:
		CombatTypes.ActorState.HITSTUN, CombatTypes.ActorState.STAGGER:
			if state_frame >= _state_length:
				_enter_state(CombatTypes.ActorState.FREE)
				_flying_reaction = CombatTypes.Reaction.NONE
		CombatTypes.ActorState.DOWNED:
			if state_frame >= Tuning.data.downed_frames:
				_start_getup()
		CombatTypes.ActorState.GETUP:
			if state_frame >= _state_length:
				_set_ghost(false)
				_enter_state(CombatTypes.ActorState.FREE)
		CombatTypes.ActorState.KO:
			_tick_ko()
		CombatTypes.ActorState.AIRBORNE:
			if _auto_land() and is_on_floor() and state_frame > 2:
				_enter_state(CombatTypes.ActorState.FREE)


func _advance_move() -> void:
	move_frame += 1
	var move := current_move
	if (
		move_frame == move.startup + move.active
		and move.active > 0
		and not move.hitboxes.is_empty()
		and not _move_landed_hit
	):
		CombatEvents.attack_whiffed.emit(self, move)
	if move_frame >= current_move.total_frames():
		var finished := current_move
		current_move = null
		debug_hitbox_volumes.clear()
		_on_move_finished(finished)


func _apply_move_frame() -> void:
	var move := current_move
	_update_lunge()
	if _lunge_frames_left > 0:
		var step := _lunge_left / float(_lunge_frames_left)
		_lunge_left -= step
		_lunge_budget -= step
		_lunge_frames_left -= 1
		_lunge_velocity = _lunge_dir * step * Engine.physics_ticks_per_second
	else:
		_lunge_velocity = Vector3.ZERO
	_active_this_tick = move.is_active(move_frame)
	_on_move_frame(move, move_frame)


func _cancel_move() -> void:
	current_move = null
	_lunge_frames_left = 0
	_lunge_velocity = Vector3.ZERO
	debug_hitbox_volumes.clear()


func _return_to_neutral() -> void:
	if is_on_floor():
		_enter_state(CombatTypes.ActorState.FREE)
	else:
		_enter_state(CombatTypes.ActorState.AIRBORNE)


func _enter_state(new_state: CombatTypes.ActorState, length: int = 0) -> void:
	var old := state
	state = new_state
	state_frame = 0
	_state_length = length
	if old != new_state:
		state_changed.emit(old, new_state)
		CombatEvents.actor_state_changed.emit(self, old, new_state)


# --- Reactions ----------------------------------------------------------------------


func _apply_reaction(hit: HitInfo) -> void:
	var reaction := hit.reaction
	var kb := hit.knockback
	if state == CombatTypes.ActorState.GRABBED and hit.attacker == holder and reaction != CombatTypes.Reaction.THROWN:
		# Knees on a held victim: jolt in the hunched held pose and stay held (unless this
		# hit killed). A standing flinch here would raise the head into the holder's view.
		if not hit.killed:
			rig.play(&"held", 0.03)
			return
		holder = null
	if hit.killed and state == CombatTypes.ActorState.DOWNED:
		_enter_ko()
		return
	if hit.killed and reaction in [CombatTypes.Reaction.NONE, CombatTypes.Reaction.FLINCH, CombatTypes.Reaction.STAGGER, CombatTypes.Reaction.GROUND]:
		reaction = CombatTypes.Reaction.KNOCKDOWN
		kb = hit.direction * maxf(Vector2(kb.x, kb.z).length(), Tuning.data.ko_push) + Vector3.UP * Tuning.data.ko_lift
	match reaction:
		CombatTypes.Reaction.NONE:
			if state == CombatTypes.ActorState.ATTACK:
				_return_to_neutral()
		CombatTypes.Reaction.FLINCH:
			sim_velocity = Vector3(kb.x, 0.0, kb.z)
			var stun := hit.move.hitstun if hit.move else 12
			_enter_state(CombatTypes.ActorState.HITSTUN, stun)
			rig.play(_flinch_anim(hit), 0.03)
		CombatTypes.Reaction.STAGGER:
			sim_velocity = Vector3(kb.x, 0.0, kb.z)
			_enter_state(CombatTypes.ActorState.STAGGER, Tuning.data.stagger_frames)
			rig.play(_directional_anim(&"stagger", kb), 0.04)
			if Vector2(kb.x, kb.z).length() >= Tuning.data.body_impact_min_speed:
				_begin_flying(CombatTypes.Reaction.STAGGER, hit.attacker)
		CombatTypes.Reaction.KNOCKDOWN, CombatTypes.Reaction.LAUNCH, CombatTypes.Reaction.THROWN:
			_launch(hit, reaction, kb)
		CombatTypes.Reaction.GROUND:
			# Already down: the hit lands but the victim stays down a little longer.
			state_frame = maxi(0, state_frame - 20)
			rig.play(&"downed_back" if _face_up else &"downed_front", 0.02)


func _launch(hit: HitInfo, reaction: CombatTypes.Reaction, kb: Vector3) -> void:
	holder = null
	var v := kb
	v.y = maxf(v.y, Tuning.data.min_launch_up)
	sim_velocity = v
	_face_up = not hit.from_behind
	_set_ghost(true)
	var new_state := CombatTypes.ActorState.THROWN if reaction == CombatTypes.Reaction.THROWN else CombatTypes.ActorState.LAUNCHED
	_enter_state(new_state)
	if reaction == CombatTypes.Reaction.KNOCKDOWN:
		rig.play(&"knockdown_back" if _face_up else &"knockdown_forward", 0.03)
	else:
		rig.play(&"launched", 0.03)
	_begin_flying(CombatTypes.Reaction.KNOCKDOWN, hit.attacker)
	CombatEvents.knocked_down.emit(self, hit)


func _begin_flying(reaction: CombatTypes.Reaction, source: Node3D) -> void:
	_flying_reaction = reaction
	_flying_source = source as CombatActor
	_flying_hit_ids.clear()


func _land_from_flight() -> void:
	_flying_reaction = CombatTypes.Reaction.NONE
	var keep := Tuning.data.landing_slide_keep
	sim_velocity = Vector3(sim_velocity.x * keep, 0.0, sim_velocity.z * keep)
	if health <= 0.0:
		_enter_ko()
		return
	_enter_state(CombatTypes.ActorState.DOWNED)
	rig.play(&"downed_back" if _face_up else &"downed_front", 0.08)


func _start_getup() -> void:
	_enter_state(CombatTypes.ActorState.GETUP, Tuning.data.getup_frames)
	_invuln_frames = Tuning.data.getup_invuln_frames
	rig.play(&"getup_back" if _face_up else &"getup_front", 0.06)
	CombatEvents.got_up.emit(self)


func _enter_ko() -> void:
	holder = null
	_flying_reaction = CombatTypes.Reaction.NONE
	_set_ghost(true)
	_enter_state(CombatTypes.ActorState.KO)
	rig.play(&"ko_back" if _face_up else &"ko_front", 0.1)
	rig.set_hurtboxes_enabled(false)


func _flinch_anim(hit: HitInfo) -> StringName:
	match hit.region:
		CombatTypes.Region.HEAD:
			var side := _local_side(hit.knockback if hit.knockback.length_squared() > 0.01 else hit.direction)
			if side > 0.35:
				return &"flinch_head_right"
			if side < -0.35:
				return &"flinch_head_left"
			return &"flinch_head_front"
		CombatTypes.Region.LEGS:
			return &"flinch_legs"
	return &"flinch_gut"


## Picks <prefix>_back/_forward/_left/_right from a world push direction.
func _directional_anim(prefix: String, push: Vector3) -> StringName:
	var flat := Vector3(push.x, 0.0, push.z)
	if flat.length_squared() < 0.0001:
		return StringName(prefix + "_back")
	flat = flat.normalized()
	var fwd := get_forward()
	var right := fwd.cross(Vector3.UP)
	var along := flat.dot(fwd)
	var side := flat.dot(right)
	if absf(side) > absf(along):
		return StringName(prefix + ("_right" if side > 0.0 else "_left"))
	return StringName(prefix + ("_forward" if along > 0.0 else "_back"))


## -1..1: how far a world direction points to this actor's right.
func _local_side(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	return flat.normalized().dot(get_forward().cross(Vector3.UP))


# --- Motion -------------------------------------------------------------------------


func _integrate(dt: float, scale: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor or sim_velocity.y > 0.0:
		sim_velocity.y -= Tuning.data.gravity * dt
	elif sim_velocity.y < 0.0:
		sim_velocity.y = -0.5
	if on_floor and _uses_friction():
		var flat := Vector2(sim_velocity.x, sim_velocity.z)
		flat = flat.move_toward(Vector2.ZERO, Tuning.data.ground_friction * dt)
		sim_velocity.x = flat.x
		sim_velocity.z = flat.y
	var lunge := _lunge_velocity if state == CombatTypes.ActorState.ATTACK else Vector3.ZERO
	velocity = (sim_velocity + lunge) * scale
	move_and_slide()
	var after := velocity / scale
	sim_velocity.y = after.y
	if not _self_propelled():
		# Knockback slides stop at walls; self-propelled states re-steer every frame.
		sim_velocity.x = after.x
		sim_velocity.z = after.z
	if is_flying() and is_on_floor() and state_frame > 2 and sim_velocity.y <= 0.0:
		_land_from_flight()
	if _flying_reaction != CombatTypes.Reaction.NONE:
		_check_body_impacts()


func _self_propelled() -> bool:
	return state in [
		CombatTypes.ActorState.FREE,
		CombatTypes.ActorState.ATTACK,
		CombatTypes.ActorState.AIRBORNE,
		CombatTypes.ActorState.DODGE,
		CombatTypes.ActorState.GRABBING,
	]


func _uses_friction() -> bool:
	return state in [
		CombatTypes.ActorState.HITSTUN,
		CombatTypes.ActorState.STAGGER,
		CombatTypes.ActorState.DOWNED,
		CombatTypes.ActorState.GETUP,
		CombatTypes.ActorState.KO,
	]


## Flying or shoved bodies knock over teammates they run into (Spec §6).
func _check_body_impacts() -> void:
	var speed := Vector2(sim_velocity.x, sim_velocity.z).length()
	if speed < Tuning.data.body_impact_min_speed:
		if state == CombatTypes.ActorState.STAGGER:
			_flying_reaction = CombatTypes.Reaction.NONE
		return
	_impact_shape.radius = body_radius + 0.1
	_impact_shape.height = body_height
	_impact_query.transform = Transform3D(Basis(), global_position + Vector3.UP * body_height * 0.5)
	_impact_query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	for result: Dictionary in space.intersect_shape(_impact_query, 16):
		var other := result.get("collider") as CombatActor
		if other == null or other == self or other == _flying_source or other.team != team:
			continue
		if _flying_hit_ids.has(other.get_instance_id()):
			continue
		_flying_hit_ids[other.get_instance_id()] = true
		_impact(other, speed)


func _impact(other: CombatActor, speed: float) -> void:
	var path := IMPACT_STAGGER_PATH if _flying_reaction == CombatTypes.Reaction.STAGGER else IMPACT_KNOCKDOWN_PATH
	var move: MoveData = null
	if ResourceLoader.exists(path):
		move = load(path) as MoveData
	var source: CombatActor = _flying_source if is_instance_valid(_flying_source) else self
	if move == null or not other.can_be_hit_by(source, move):
		return
	var dir := Vector3(sim_velocity.x, 0.0, sim_velocity.z) / speed
	var hit := HitInfo.new()
	hit.attacker = source
	hit.victim = other
	hit.move = move
	hit.damage = move.damage
	hit.tier = move.tier
	hit.reaction = move.reaction
	hit.region = CombatTypes.Region.TORSO
	hit.contact_point = (global_position + other.global_position) * 0.5 + Vector3.UP * 1.0
	hit.direction = dir
	hit.knockback = dir * move.knockback.z + dir.cross(Vector3.UP) * move.knockback.x + Vector3.UP * move.knockback.y
	hit.from_behind = other.get_forward().dot(dir) > 0.0
	hit.is_body_impact = true
	hit.physics_frame = Engine.get_physics_frames()
	hit.input_timing = &"body"
	if other.receive_hit(hit):
		TimeController.hitstop([other], Tuning.data.hitstop_s(move.tier))
		CombatEvents.hit_landed.emit(hit)


## Where a held body stands: on the holder's floor below its HoldPoint.
func _pin_spot() -> Vector3:
	var p := holder.rig.get_point_position(&"HoldPoint")
	return Vector3(p.x, holder.global_position.y, p.z)


## Pin the held body below the holder's HoldPoint, facing it. Over the first _GRAB_EASE_S
## of the grab (`dt` sim seconds this frame) it eases in from where it stood (ease-in).
func _pin_to_holder(dt: float) -> void:
	if not is_instance_valid(holder):
		release_from_grab(Vector3.ZERO, false)
		return
	global_position = _pin_spot()
	if _pin_ease_s < _GRAB_EASE_S:
		_pin_ease_s += dt
		var u := clampf(_pin_ease_s / _GRAB_EASE_S, 0.0, 1.0)
		global_position += holder.global_basis * _pin_from * (1.0 - u * u)
	var to_holder := holder.global_position - global_position
	to_holder.y = 0.0
	if to_holder.length_squared() > 0.0001:
		rotation.y = atan2(-to_holder.x, -to_holder.z)
	velocity = Vector3.ZERO
	sim_velocity = Vector3.ZERO


## Ghost bodies (flying, downed, held, KO) only collide with the world, so the living
## can walk over them; flying-body impacts use a shape query instead.
func _set_ghost(ghost: bool) -> void:
	if ghost:
		collision_layer = CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY)
		collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	else:
		collision_layer = CombatTypes.bit(
			CombatTypes.LAYER_PLAYER_BODY if team == 0 else CombatTypes.LAYER_ENEMY_BODY
		)
		collision_mask = (
			CombatTypes.bit(CombatTypes.LAYER_WORLD)
			| CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY)
			| CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
		)


func _ensure_body() -> void:
	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
		elif child is HumanoidRig:
			rig = child
	if not has_shape:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = body_radius
		capsule.height = body_height
		shape.shape = capsule
		shape.position = Vector3.UP * body_height * 0.5
		add_child(shape)
	if rig == null:
		rig = HumanoidRig.new()
		rig.name = "Rig"
		add_child(rig)
	rig.actor = self
	rig.height = body_height
	_configure_rig(rig)
	rig.build()
	rig.set_hurtboxes_enabled(true)
