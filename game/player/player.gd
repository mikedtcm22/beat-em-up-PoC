class_name PlayerCharacter
extends CombatActor
## The hero. Doom-style movement, look-driven body yaw, cadence combos through
## ComboParser, target magnetism, jump and air attacks, the held block and the dodge (both
## on B), quick turn, grabs (knees and throws) and weapons. Cameras and HUD read only the
## public members (ARCHITECTURE.md).

const MOVE_SETS: Dictionary[StringName, String] = {
	&"ground": "res://game/combat/movesets/ground.tres",
	&"air": "res://game/combat/movesets/air.tres",
	&"hold": "res://game/combat/movesets/hold.tres",
	&"weapon": "res://game/combat/movesets/weapon.tres",
}
const WEAPON_THROW_PATH := "res://game/combat/moves/weapon_throw.tres"
const ATTACK_IDS: Array[StringName] = [&"P", &"K", &"RB"]
## Rig animation shown while a charged P waits for its release (_charging_hold()).
const CHARGE_ANIM := &"haymaker_charge"
## Share of a leftover first-person view turn (a spin or the back elbow cut short) taken
## back toward the look per physics tick.
const _VIEW_SETTLE := 0.25

## Radians. Yaw 0 faces -Z; positive pitch looks up.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
## Eye height above the player's origin in the idle pose (meters).
var standing_eye_height: float = 1.68
## Input source; set `input.scripted = true` to drive the player from code.
var input: PlayerInput = PlayerInput.new()
var parser: ComboParser = ComboParser.new()
## Test room only: get back up at full health Tuning.player_revive_s after a KO (the real
## game over comes later). Off by default.
var auto_revive: bool = false

var _sets: Dictionary[StringName, MoveSet] = {}
var _weapon_throw_move: MoveData
## Button edges since the last sim frame, in arrival order: [button, pressed].
var _pending_edges: Array[Array] = []
var _move_input: Vector2 = Vector2.ZERO
## The stick when B (&"DODGE") was last pressed: it decides block or dodge (_b_action()).
var _dodge_stick: Vector2 = Vector2.ZERO
## The B press still held was a block press (stick centered): holding it keeps the guard,
## and raises it again whenever the player is back to FREE (_holding_block()).
var _block_press_held: bool = false
## The guard up now was raised by a fresh B press with the stick centered and has stopped
## no hit yet: the stick passing block_stick_threshold within Tuning.dodge_late_stick_frames
## (B still held) turns it into a dodge (_control_block()).
var _late_dodge_open: bool = false
## A P or K pressed while the guard is up (BLOCK, BLOCKSTUN), held back here instead of
## aging in the parser's buffer: it drops the guard and is handed to the parser fresh once
## the guard is down, so it always starts its attack (&"" = none).
var _held_attack: StringName = &""
var _magnet_target: CombatActor
var _magnet_preview: CombatActor
var _turn_left: float = 0.0
var _turn_frames: int = 0
var _quick_turn_left: float = 0.0
var _quick_turn_frames: int = 0
var _cam_offset: Vector2 = Vector2.ZERO
## First-person view turn away from the look in degrees (positive turns left), this
## physics tick and the last (_update_view_yaw(); the camera interpolates between them).
var _view_yaw: float = 0.0
var _view_yaw_last: float = 0.0
## The move turning the view (null = none) and its frame last tick; a turn left on screen
## when it changes, settling back to the look (degrees, _VIEW_SETTLE a tick).
var _view_move: MoveData
var _view_frame: int = 0
var _view_carry: float = 0.0
## Spin follow (MoveData.camera_spin_follow): the eyes' yaw (radians) last tick, their turn
## since the move started (radians, unwrapped) and the whole turns the view lands on
## (degrees; NAN until the recovery).
var _spin_eye: float = 0.0
var _spin_turn: float = 0.0
var _spin_land: float = NAN
var _dodge_velocity: Vector3 = Vector3.ZERO
var _air_attack: bool = false
var _held: CombatActor
var _hold_frames: int = 0
## Hold view ramp (0..1, linear in sim ticks): toward 1 while an enemy is held, back to 0
## after a throw or release (_tick_hold_view(); eased by get_hold_view_weight()).
var _hold_view: float = 0.0
var _knees: int = 0
var _weapon: Weapon
var _action_lock: int = 0


func _ready() -> void:
	team = 0
	display_name = "Player"
	add_to_group(&"player")
	super._ready()
	look_yaw = rotation.y
	for key: StringName in MOVE_SETS:
		if ResourceLoader.exists(MOVE_SETS[key]):
			_sets[key] = load(MOVE_SETS[key]) as MoveSet
	if ResourceLoader.exists(WEAPON_THROW_PATH):
		_weapon_throw_move = load(WEAPON_THROW_PATH) as MoveData
	parser.move_set = _sets.get(&"ground")
	rig.advance(0.0)
	standing_eye_height = rig.get_point_position(&"EyePoint").y - global_position.y


func _configure_rig(r: HumanoidRig) -> void:
	r.first_person_body = true
	# Loose arms and smaller wrapped hands keep the first-person view clear (Game-boy's
	# M1 playtest); enemies keep the boxer guard.
	r.stance = PlaceholderPoses.STANCE_RELAXED
	r.wrapped_hands = true
	r.body_color = Color(0.2, 0.36, 0.62)
	r.accent_color = Color(0.93, 0.9, 0.82)
	r.skin_color = Color(0.82, 0.6, 0.45)


func _physics_process(delta: float) -> void:
	var frame := input.poll()
	_move_input = frame.move
	# Within one poll presses come before releases (a same-tick tap is press, release).
	for button in frame.pressed:
		_pending_edges.append([button, true])
	for button in frame.released:
		_pending_edges.append([button, false])
	super._physics_process(delta)
	_update_view_yaw()


func _process(delta: float) -> void:
	if input.scripted or GameInput.paused:
		return
	var mouse := GameInput.consume_mouse_delta() * Tuning.data.mouse_sensitivity
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", Tuning.data.stick_deadzone)
	stick *= Tuning.data.stick_look_speed * delta
	var dy := mouse.y + stick.y
	if Tuning.data.invert_look_y:
		dy = -dy
	look_yaw = wrapf(look_yaw - deg_to_rad(mouse.x + stick.x), -PI, PI)
	look_pitch = clampf(look_pitch - deg_to_rad(dy), deg_to_rad(-85.0), deg_to_rad(85.0))


# --- Camera/HUD API -----------------------------------------------------------------


func get_eye_transform() -> Transform3D:
	return rig.get_point_transform(&"EyePoint")


func get_look_basis() -> Basis:
	return Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0))


## The first-person view's extra pitch (x, degrees, negative looks down) and drop (y,
## meters, negative raises it): the running move's (MoveData.camera_pitch_deg and
## camera_drop_m) plus the hold view's (Tuning.grab_view_pitch_deg, grab_view_rise_m), each
## already eased, so a knee's own pitch adds to the hold's without a jump.
func get_camera_move_offset() -> Vector2:
	var hold := Vector2(-Tuning.data.grab_view_pitch_deg, -Tuning.data.grab_view_rise_m)
	return _cam_offset + hold * get_hold_view_weight()


## Meters the first-person lens moves back along the flat look: the hold view's
## (Tuning.grab_view_back_m, eased).
func get_camera_pull_back() -> float:
	return Tuning.data.grab_view_back_m * get_hold_view_weight()


## Weight (0..1, smoothstepped) of the hold view: it eases in over Tuning.grab_view_in_s
## once an enemy is held and back out over grab_view_out_s after a throw or a release.
## Runs in sim ticks, so it holds still through hitstop like the moves' camera offsets.
func get_hold_view_weight() -> float:
	return smoothstep(0.0, 1.0, _hold_view)


## The first-person view's turn away from the look in degrees (positive turns left): a
## spinning move's body turn (MoveData.camera_spin_follow) and a move's camera_yaw_deg (the
## back elbow). `fraction` (0..1) interpolates from the last physics tick to this one, so
## render frames between ticks turn smoothly. Presentation only: aim never uses it.
func get_camera_view_yaw(fraction: float = 1.0) -> float:
	return lerpf(_view_yaw_last, _view_yaw, clampf(fraction, 0.0, 1.0))


func is_walking() -> bool:
	if not is_on_floor():
		return false
	if state != CombatTypes.ActorState.FREE and state != CombatTypes.ActorState.GRABBING:
		return false
	return Vector2(sim_velocity.x, sim_velocity.z).length() > 0.5


func get_magnetism_cone() -> Dictionary:
	return {
		origin = get_eye_transform().origin,
		forward = get_look_basis() * Vector3.FORWARD,
		half_angle_deg = Tuning.data.magnet_half_angle_deg,
		range = Tuning.data.magnet_range,
		target = _magnet_target if state == CombatTypes.ActorState.ATTACK else _magnet_preview,
	}


func holding_weapon() -> bool:
	return _weapon != null


func weapon_durability_left() -> int:
	return _weapon.durability if _weapon else 0


func holding_enemy() -> CombatActor:
	return _held


func debug_state_text() -> String:
	var text := super.debug_state_text()
	if parser.current:
		text += "\nchain %d %s" % [parser.chain_step, parser.current.id]
	return text


## CombatActor.reset_state(), forgetting the block press and a P or K held back by the guard.
func reset_state() -> void:
	super.reset_state()
	_held_attack = &""
	_block_press_held = false
	_late_dodge_open = false
	_view_yaw = 0.0
	_view_yaw_last = 0.0
	_view_carry = 0.0
	_view_move = null
	_hold_view = 0.0


# --- Control ------------------------------------------------------------------------


func _tick_control() -> void:
	_feed_parser()
	if not is_guarding():
		_hand_back_held_attack()
	_tick_turns()
	if _can_steer_body():
		rotation.y = look_yaw
	match state:
		CombatTypes.ActorState.FREE:
			_control_free()
		CombatTypes.ActorState.AIRBORNE:
			_control_air()
		CombatTypes.ActorState.ATTACK:
			_control_attack()
		CombatTypes.ActorState.DODGE:
			_control_dodge()
		CombatTypes.ActorState.GRABBING:
			_control_holding()
		CombatTypes.ActorState.BLOCK:
			_control_block()
			if state == CombatTypes.ActorState.FREE:
				# The guard dropped at once (no cancel frames): its attack starts now.
				_hand_back_held_attack()
				_control_free()
		CombatTypes.ActorState.BLOCKSTUN:
			_control_blockstun()
		_:
			parser.clear_buffer()
	_magnet_preview = _find_magnet_target(null)
	_tick_hold_view()


func _feed_parser() -> void:
	parser.buffer_frames = Tuning.data.input_buffer_frames
	parser.pause_min_frames = Tuning.data.pause_min_frames
	parser.pause_max_frames = Tuning.data.pause_max_frames
	parser.hold_frames = Tuning.data.hold_frames
	parser.tick()
	for edge in _pending_edges:
		if edge[1]:
			if edge[0] == &"DODGE":
				_dodge_stick = _move_input
				_block_press_held = _move_input.length() < Tuning.data.block_stick_threshold
			parser.press(edge[0])
		else:
			if edge[0] == &"DODGE":
				_block_press_held = false
			parser.release(edge[0])
	_pending_edges.clear()


func _control_free() -> void:
	_use_set(&"weapon" if _weapon else &"ground")
	if parser.consume(&"TURN"):
		_start_quick_turn()
	if _action_lock > 0:
		_action_lock -= 1
		_locomotion(1.0, false)
		return
	if parser.consume(&"DODGE"):
		_b_action()
		return
	if is_on_floor() and parser.consume(&"JUMP"):
		_start_jump()
		return
	if parser.consume(&"GRAB") and _grab_action():
		return
	var selection := parser.select(false, _conditions())
	if selection:
		_start_selection(selection)
		return
	if _holding_block():
		# Holding B keeps the block: back to FREE with it still held (after a hit, a guard
		# break, an attack out of the guard, a grab), the guard comes up again. Only a
		# fresh press can parry.
		_start_block(false)
		return
	var charging := _charging_hold()
	_locomotion(1.0, not charging)
	if charging and rig.current_anim() != CHARGE_ANIM:
		rig.play(CHARGE_ANIM)


## True once P has been held long enough that releasing it starts the move set's hold
## move (the haymaker, Spec §4): the rig then shows the cocked fist until the release.
func _charging_hold() -> bool:
	if not parser.is_held(CombatTypes.IN_PUNCH) or parser.move_set == null:
		return false
	if parser.held_frames(CombatTypes.IN_PUNCH) < parser.hold_frames:
		return false
	for branch: ComboBranch in parser.move_set.root_branches:
		if branch and branch.input == CombatTypes.IN_PUNCH_HOLD and branch.move:
			return true
	return false


func _control_air() -> void:
	_steer(Tuning.data.move_speed, Tuning.data.move_accel * Tuning.data.air_control_mult)
	if is_on_floor() and state_frame > 2:
		_land()
		return
	if sim_velocity.y < 0.0 and rig.current_anim() == &"jump":
		rig.play(&"fall", 0.15)
	_use_set(&"air")
	var selection := parser.select(false, _conditions())
	if selection:
		_air_attack = true
		_start_selection(selection)


func _control_attack() -> void:
	var move := current_move
	if move == null:
		return
	if _air_attack:
		if is_on_floor() and state_frame > 1:
			_cancel_move()
			_land()
			return
		_steer(
			Tuning.data.move_speed * Tuning.data.air_control_mult,
			Tuning.data.move_accel * Tuning.data.air_control_mult * 0.5
		)
	else:
		_steer(Tuning.data.move_speed * Tuning.data.attack_move_mult, Tuning.data.move_accel)
	if not (move.is_recovery(move_frame) and move.can_cancel(move_frame)):
		return
	if not _air_attack and _held == null and parser.consume(&"DODGE"):
		_cancel_move()
		_b_action()
		return
	if parser.consume(&"TURN"):
		_start_quick_turn()
	var selection := parser.select(true, _conditions())
	if selection:
		_start_selection(selection)


func _control_dodge() -> void:
	sim_velocity.x = _dodge_velocity.x
	sim_velocity.z = _dodge_velocity.z
	if state_frame >= _state_length:
		sim_velocity.x = 0.0
		sim_velocity.z = 0.0
		_return_to_neutral()


## Holding the guard: walk slowly, look and quick turn freely (the guard swings with the
## look), no jump or grab. Releasing B drops the guard after Tuning.block_release_frames;
## P or K (held back by _hold_back_attack(), also from a blockstun) drops it after
## Tuning.block_attack_cancel_frames, and the press starts its attack once FREE.
func _control_block() -> void:
	if (
		_late_dodge_open
		and _guard_frames <= Tuning.data.dodge_late_stick_frames
		and parser.is_held(&"DODGE")
		and _move_input.length() >= Tuning.data.block_stick_threshold
	):
		# B came a moment before the stick: a dodge after all (Game-boy's second playtest).
		_block_press_held = false
		_held_attack = &""
		drop_guard(0)
		_start_dodge(_move_input)
		return
	if parser.consume(&"TURN"):
		_start_quick_turn()
	_steer(Tuning.data.move_speed * Tuning.data.block_move_mult, Tuning.data.move_accel)
	_cam_offset = Vector2.ZERO
	_hold_back_attack()
	if _held_attack != &"":
		drop_guard(Tuning.data.block_attack_cancel_frames)
	elif not parser.is_held(&"DODGE"):
		drop_guard(Tuning.data.block_release_frames)
	if is_dropping_guard():
		# JUMP and GRAB pressed from the release on stay buffered: LB right after letting
		# go of B grabs a parried attacker.
		return
	_discard_jump_and_grab()
	if rig.current_anim() != &"block":
		# Back in the plain guard after a blockstun's push-back.
		rig.play(&"block", 0.06)


## Pushed back in the guard (blockstun): no attacks or steps, quick turn works. A P or K
## press waits for the guard to come down (_hold_back_attack()), so punching back during
## the stun attacks right after it.
func _control_blockstun() -> void:
	if parser.consume(&"TURN"):
		_start_quick_turn()
	_hold_back_attack()
	_discard_jump_and_grab()
	_cam_offset = Vector2.ZERO


## While guarding: the first P or K press is held back (_held_attack) for when the guard is
## down; later ones are dropped.
func _hold_back_attack() -> void:
	for input: StringName in [CombatTypes.IN_PUNCH, CombatTypes.IN_KICK]:
		while parser.consume(input):
			if _held_attack == &"":
				_held_attack = input


## While the guard is up: no jump, LB ignored (the presses are dropped, not buffered).
func _discard_jump_and_grab() -> void:
	for input: StringName in [&"JUMP", &"GRAB"]:
		while parser.consume(input):
			pass


## The guard is down: a P or K held back while blocking enters the parser as a fresh press.
func _hand_back_held_attack() -> void:
	if _held_attack != &"":
		parser.buffer(_held_attack)
		_held_attack = &""


## B is held and its press was a block press: the guard stays up, or comes back up.
func _holding_block() -> bool:
	return _block_press_held and parser.is_held(&"DODGE")


func _control_holding() -> void:
	if not _holding_valid():
		_held = null
		_enter_state(CombatTypes.ActorState.FREE)
		return
	_hold_frames += 1
	if _hold_frames >= Tuning.data.hold_max_frames:
		_release_held(true)
		_enter_state(CombatTypes.ActorState.FREE)
		return
	_steer(Tuning.data.move_speed * Tuning.data.hold_move_mult, Tuning.data.move_accel)
	_use_set(&"hold")
	if parser.consume(&"GRAB"):
		_release_held(false)
		_enter_state(CombatTypes.ActorState.FREE)
		return
	var selection := parser.select(false, _conditions())
	if selection:
		_start_selection(selection)
	elif rig.current_anim() != &"hold" and (rig.current_anim() != &"grab" or _hold_frames > 12):
		rig.play(&"hold", 0.1)


# --- Moves --------------------------------------------------------------------------


func _start_selection(selection: ComboParser.Selection) -> void:
	if _weapon == null and selection.move.id.begins_with("pipe_swing"):
		parser.reset_chain()
		return
	parser.notify_started(selection)
	start_move(selection.move, selection.chain_step, selection.timing)


func _on_move_finished(move: MoveData) -> void:
	parser.notify_recovery_ended()
	var auto := parser.take_auto_next()
	if auto:
		_start_selection(auto)
		return
	_air_attack = false
	if _holding_valid():
		_enter_state(CombatTypes.ActorState.GRABBING)
		rig.play(&"hold", 0.1)
	else:
		_held = null
		_return_to_neutral()
	if move.id == &"throw" or move.id == &"weapon_throw":
		_use_set(&"weapon" if _weapon else &"ground")


func _on_move_frame(move: MoveData, frame: int) -> void:
	_update_camera_offset()
	if frame != move.startup:
		return
	if move.id == &"throw" and _holding_valid():
		_throw_held(move)
	elif move.id == &"weapon_throw" and _weapon:
		var dir := get_look_basis() * Vector3.FORWARD
		_weapon.throw_from(self, (dir + Vector3.UP * 0.08).normalized() * Tuning.data.weapon_throw_speed, move)
		CombatEvents.weapon_thrown.emit(self, _weapon)
		_weapon = null


func _on_move_hits(move: MoveData, hits: Array[HitInfo]) -> void:
	if move.id == &"knee" and _holding_valid():
		_knees += 1
		if _knees >= Tuning.data.max_knees:
			_release_held(true)
	if _weapon and move.id.begins_with("pipe_swing"):
		_weapon.durability -= hits.size()
		if _weapon.durability <= 0:
			var broken := _weapon
			_weapon = null
			_use_set(&"ground")
			parser.reset_chain()
			CombatEvents.weapon_broke.emit(self, broken)
			broken.break_apart()


func _on_hit_received(_hit: HitInfo) -> void:
	parser.reset_chain()
	parser.clear_buffer()
	_held_attack = &""
	_air_attack = false
	_cam_offset = Vector2.ZERO
	if _holding_valid():
		_release_held(false)
	_held = null


func _on_move_interrupted() -> void:
	parser.reset_chain()
	parser.clear_buffer()
	_air_attack = false
	_cam_offset = Vector2.ZERO


## A guard break staggers the player: what was pressed in the guard is dropped (a held B
## raises the guard again after the stagger).
func _on_hit_blocked(hit: HitInfo) -> void:
	_late_dodge_open = false
	if hit.guard_broken:
		parser.reset_chain()
		parser.clear_buffer()
		_held_attack = &""


## The guard faces where the player looks (the body follows the look while blocking).
func _guard_facing() -> Vector3:
	return Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))


func _tick_ko() -> void:
	if auto_revive and state_frame >= roundi(Tuning.data.player_revive_s * Engine.physics_ticks_per_second):
		_revive()


## Test room: back up from a KO with full health and guard.
func _revive() -> void:
	health = max_health
	rig.set_hurtboxes_enabled(true)
	_set_guard(max_guard())
	CombatEvents.health_changed.emit(self, health, max_health)
	CombatEvents.revived.emit(self)
	_start_getup()


func _plan_lunge(move: MoveData) -> void:
	_magnet_target = _find_magnet_target(move) if move.magnetism else null
	if _magnet_target:
		var to := _magnet_target.get_chest_position() - global_position
		to.y = 0.0
		var max_lunge := move.lunge if move.lunge > 0.0 else Tuning.data.magnet_lunge
		var distance := clampf(to.length() - _stop_distance(move), 0.0, max_lunge)
		set_lunge(to, distance, _lunge_frames(move), max_lunge)
		var target_yaw := atan2(-to.x, -to.z)
		var max_turn := deg_to_rad(Tuning.data.magnet_turn_deg)
		_turn_left = clampf(wrapf(target_yaw - look_yaw, -PI, PI), -max_turn, max_turn)
		_turn_frames = maxi(move.startup, 1)
	elif move.free_lunge > 0.0:
		set_lunge(get_forward(), move.free_lunge, _lunge_frames(move))


func _update_lunge() -> void:
	if _lunge_frames_left <= 0 or not is_instance_valid(_magnet_target) or current_move == null:
		return
	var to := _magnet_target.get_chest_position() - global_position
	to.y = 0.0
	_lunge_dir = to.normalized() if to.length_squared() > 0.0001 else _lunge_dir
	# Re-aim every frame: close in on a target that is reeling away, within the budget.
	_lunge_left = clampf(to.length() - _stop_distance(current_move), 0.0, _lunge_budget)


func _stop_distance(move: MoveData) -> float:
	# Stomps stand over the body; everything else stops at striking distance.
	return Tuning.data.stomp_stop_distance if move.hits_downed else Tuning.data.magnet_stop_distance


func _lunge_frames(move: MoveData) -> int:
	return maxi(move.startup + (move.active if _air_attack else 0), 1)


## The enemy nearest screen center inside the magnetism cone (Spec §5). With `move` null
## this previews the target a ground attack would pick, for debug draw.
func _find_magnet_target(move: MoveData) -> CombatActor:
	var wants_downed := move != null and move.hits_downed
	var aim := get_look_basis() * Vector3.FORWARD
	# Measured from chest height, so an enemy in your face isn't "below center" and
	# losing to one farther away (the eye sits ~0.4 m above enemy chests).
	var origin := get_chest_position()
	var cone := deg_to_rad(Tuning.data.magnet_half_angle_deg)
	var best: CombatActor = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as CombatActor
		if enemy == null or enemy.is_ko() or enemy.is_flying() or enemy.is_downed() != wants_downed:
			continue
		var to := enemy.get_chest_position() - origin
		var flat := Vector3(to.x, 0.0, to.z)
		var dist := flat.length()
		if dist > Tuning.data.magnet_range:
			continue
		# Downed bodies are below the view; judge them by heading alone.
		var angle := aim.angle_to(to) if not wants_downed else Vector3(aim.x, 0.0, aim.z).angle_to(flat)
		if angle > cone:
			continue
		# Closest to screen center wins; a few degrees per meter break near-ties toward the nearer enemy.
		var score := angle + deg_to_rad(4.0) * dist
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _conditions() -> Dictionary:
	return {
		CombatTypes.COND_DOWNED_TARGET_NEAR: _downed_target_near(),
		CombatTypes.COND_AT_APEX: _at_apex(),
	}


func _downed_target_near() -> bool:
	var fwd := get_forward()
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as CombatActor
		if enemy == null or not enemy.is_downed():
			continue
		var to := enemy.get_chest_position() - global_position
		to.y = 0.0
		if to.length() <= Tuning.data.stomp_range and fwd.angle_to(to) <= deg_to_rad(Tuning.data.stomp_half_angle_deg):
			return true
	return false


func _at_apex() -> bool:
	return absf(sim_velocity.y) <= Tuning.data.gravity * Tuning.data.apex_window_frames / 60.0


func _update_camera_offset() -> void:
	var move := current_move
	if move == null:
		_cam_offset = Vector2.ZERO
		return
	var w := _camera_weight(move, move_frame)
	_cam_offset = Vector2(move.camera_pitch_deg * w, move.camera_drop_m * w)


## Weight (0..1) of `move`'s camera offsets on its frame `f`: eased in over the startup,
## full through the active frames and camera_hold_frames more, eased out over the rest.
static func _camera_weight(move: MoveData, f: int) -> float:
	var w := 1.0
	if f < move.startup:
		w = float(f + 1) / float(maxi(move.startup, 1))
	else:
		var out := f - move.startup - move.active - move.camera_hold_frames
		if out >= 0:
			w = 1.0 - float(out + 1) / float(maxi(move.recovery - move.camera_hold_frames, 1))
	return smoothstep(0.0, 1.0, clampf(w, 0.0, 1.0))


## The first-person view turn this physics tick, after the rig advanced (presentation; see
## get_camera_view_yaw()): the running move's camera_yaw_deg, eased like the pitch, plus
## its camera_spin_follow share (times Tuning.cam_spin_follow_mult) of the eyes' turn
## since it started (HumanoidRig.eye_yaw()), eased onto whole turns over the recovery so
## the view lands back on the heading. A turn still on screen when the turning move
## changes (cut short, cancelled into another) settles back on top of the new one.
func _update_view_yaw() -> void:
	_view_yaw_last = _view_yaw
	var move := current_move if _running_move() else null
	var follow := move.camera_spin_follow * Tuning.data.cam_spin_follow_mult if move else 0.0
	if move and follow <= 0.0 and is_zero_approx(move.camera_yaw_deg):
		move = null
	if move != _view_move or (move and move_frame < _view_frame):
		# A turn ends or another starts (a cancel, a chain, a move cut short): the turn on
		# screen carries over and settles back, whole turns dropped from both ticks alike
		# (they are the look itself), so the view never jumps or sweeps round.
		var wrapped := wrapf(_view_yaw, -180.0, 180.0)
		_view_yaw_last += wrapped - _view_yaw
		_view_yaw = wrapped
		_view_carry = wrapped
		_view_move = move
		_spin_turn = 0.0
		_spin_land = NAN
		if move:
			_spin_eye = rig.eye_yaw()
	elif move and follow > 0.0:
		var eye := rig.eye_yaw()
		_spin_turn += wrapf(eye - _spin_eye, -PI, PI)
		_spin_eye = eye
	_view_frame = move_frame
	var own := 0.0
	if move:
		var spin := follow * rad_to_deg(_spin_turn)
		if follow > 0.0 and move_frame >= move.startup + move.active:
			if is_nan(_spin_land):
				_spin_land = roundf(spin / 360.0) * 360.0
			spin = lerpf(spin, _spin_land, 1.0 - _camera_weight(move, move_frame))
		own = spin + move.camera_yaw_deg * _camera_weight(move, move_frame)
	_view_yaw = own + _view_carry
	_view_carry = lerpf(_view_carry, 0.0, _VIEW_SETTLE) if absf(_view_carry) > 0.01 else 0.0


# --- Movement -----------------------------------------------------------------------


func _locomotion(speed_mult: float, animate: bool = true) -> void:
	_steer(Tuning.data.move_speed * speed_mult, Tuning.data.move_accel)
	_cam_offset = Vector2.ZERO
	if animate:
		var speed := Vector2(sim_velocity.x, sim_velocity.z).length()
		rig.play_locomotion(_move_input, speed / Tuning.data.move_speed)


## Accelerate horizontal velocity toward the stick direction (relative to look yaw).
func _steer(max_speed: float, accel: float) -> void:
	var desired := _input_world_dir() * max_speed
	var current := Vector2(sim_velocity.x, sim_velocity.z)
	var target := Vector2(desired.x, desired.z)
	var rate := accel if target.length() > 0.01 else Tuning.data.move_decel
	current = current.move_toward(target, rate / Engine.physics_ticks_per_second)
	sim_velocity.x = current.x
	sim_velocity.z = current.y


func _input_world_dir() -> Vector3:
	var forward := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
	var right := Vector3(cos(look_yaw), 0.0, -sin(look_yaw))
	var dir := right * _move_input.x + forward * _move_input.y
	return dir.limit_length(1.0)


func _start_jump() -> void:
	parser.reset_chain()
	sim_velocity.y = Tuning.data.jump_velocity
	_enter_state(CombatTypes.ActorState.AIRBORNE)
	rig.play(&"jump", 0.05)
	_use_set(&"air")
	CombatEvents.jumped.emit(self)


func _land() -> void:
	_air_attack = false
	parser.reset_chain()
	_use_set(&"weapon" if _weapon else &"ground")
	_enter_state(CombatTypes.ActorState.FREE)
	rig.play(&"land", 0.04)
	_action_lock = Tuning.data.land_lock_frames
	CombatEvents.landed.emit(self)


## B at press time (Game-boy's held block, approved after the M1 playtest): with the
## stick under Tuning.block_stick_threshold it raises the guard, otherwise it dodges that
## way (the backstep is B + back).
func _b_action() -> void:
	if _dodge_stick.length() < Tuning.data.block_stick_threshold:
		_start_block()
		_late_dodge_open = true
	else:
		_start_dodge(_dodge_stick)


## Raise the guard; `can_parry` false for one re-raised by a held B (no perfect block).
func _start_block(can_parry: bool = true) -> void:
	parser.reset_chain()
	_cam_offset = Vector2.ZERO
	_late_dodge_open = false
	start_block(can_parry)


## Dodge along the stick direction `local` (x = right, y = forward).
func _start_dodge(local: Vector2) -> void:
	parser.reset_chain()
	if local.length() < Tuning.data.block_stick_threshold:
		local = Vector2(0.0, -1.0)
	var forward := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
	var right := Vector3(cos(look_yaw), 0.0, -sin(look_yaw))
	var dir := (right * local.x + forward * local.y).normalized()
	var frames := maxi(Tuning.data.dodge_frames, 1)
	_dodge_velocity = dir * Tuning.data.dodge_distance / (frames / 60.0)
	sim_velocity.x = _dodge_velocity.x
	sim_velocity.z = _dodge_velocity.z
	_enter_state(CombatTypes.ActorState.DODGE, frames)
	_invuln_frames = Tuning.data.dodge_invuln_frames
	var anim := &"dodge_back"
	if absf(local.x) > absf(local.y):
		anim = &"dodge_right" if local.x > 0.0 else &"dodge_left"
	elif local.y > 0.0:
		anim = &"dodge_forward"
	rig.play(anim, 0.03)
	CombatEvents.dodged.emit(self, dir)


func _start_quick_turn() -> void:
	if _quick_turn_frames > 0:
		return
	_quick_turn_left = PI
	_quick_turn_frames = maxi(Tuning.data.quick_turn_frames, 1)
	CombatEvents.quick_turned.emit(self)


func _tick_turns() -> void:
	if _turn_frames > 0:
		var step := _turn_left / _turn_frames
		look_yaw = wrapf(look_yaw + step, -PI, PI)
		_turn_left -= step
		_turn_frames -= 1
	if _quick_turn_frames > 0:
		var q_step := _quick_turn_left / _quick_turn_frames
		look_yaw = wrapf(look_yaw + q_step, -PI, PI)
		_quick_turn_left -= q_step
		_quick_turn_frames -= 1


func _auto_land() -> bool:
	return false


func _can_steer_body() -> bool:
	return state in [
		CombatTypes.ActorState.FREE,
		CombatTypes.ActorState.AIRBORNE,
		CombatTypes.ActorState.ATTACK,
		CombatTypes.ActorState.DODGE,
		CombatTypes.ActorState.GRABBING,
		CombatTypes.ActorState.BLOCK,
		CombatTypes.ActorState.BLOCKSTUN,
	]


func _use_set(key: StringName) -> void:
	if _sets.has(key):
		parser.move_set = _sets[key]


# --- Grabs and weapons --------------------------------------------------------------


## LB: throw the held weapon, else grab an enemy in front (CombatActor.can_be_grabbed():
## anytime it stands, outside its strike's active frames), else pick up a weapon.
func _grab_action() -> bool:
	if _weapon and _weapon_throw_move:
		parser.reset_chain()
		start_move(_weapon_throw_move, 1, &"root")
		return true
	var target := _find_grab_target()
	if target:
		_start_grab(target)
		return true
	var weapon := _find_weapon()
	if weapon:
		_pick_up(weapon)
		return true
	return false


func _find_grab_target() -> CombatActor:
	var fwd := get_forward()
	var best: CombatActor = null
	var best_dist := Tuning.data.grab_range
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as CombatActor
		if enemy == null or not enemy.can_be_grabbed():
			continue
		var to := enemy.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= best_dist and fwd.angle_to(to) <= deg_to_rad(Tuning.data.grab_half_angle_deg):
			best_dist = dist
			best = enemy
	return best


func _start_grab(victim: CombatActor) -> void:
	parser.reset_chain()
	_held = victim
	_hold_frames = 0
	_knees = 0
	victim.start_grabbed(self)
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	_enter_state(CombatTypes.ActorState.GRABBING)
	rig.play(&"grab", 0.04)
	_use_set(&"hold")


## One sim tick of the hold view ramp: toward 1 over Tuning.grab_view_in_s while an enemy
## is held (knees included), toward 0 over grab_view_out_s once it is not (thrown on the
## throw's startup frame, released, or the hold broken by a hit). From wherever it is, so
## a hold that ends while the view is still easing in turns back without a jump.
func _tick_hold_view() -> void:
	var holding := _holding_valid()
	var seconds := Tuning.data.grab_view_in_s if holding else Tuning.data.grab_view_out_s
	var step := 1.0 if seconds <= 0.0 else 1.0 / (seconds * Engine.physics_ticks_per_second)
	_hold_view = move_toward(_hold_view, 1.0 if holding else 0.0, step)


func _holding_valid() -> bool:
	return (
		is_instance_valid(_held)
		and _held.state == CombatTypes.ActorState.GRABBED
		and _held.holder == self
	)


func _release_held(stagger: bool) -> void:
	if _holding_valid():
		_held.release_from_grab(get_forward() * Tuning.data.release_push, stagger)
	_held = null
	_use_set(&"weapon" if _weapon else &"ground")


func _throw_held(move: MoveData) -> void:
	var victim := _held
	_held = null
	var dir := _input_world_dir()
	if dir.length() < 0.3:
		dir = get_forward()
	dir = dir.normalized()
	var hit := HitInfo.new()
	hit.attacker = self
	hit.victim = victim
	hit.move = move
	hit.damage = move.damage
	hit.tier = move.tier
	hit.reaction = CombatTypes.Reaction.THROWN
	hit.region = CombatTypes.Region.TORSO
	hit.contact_point = victim.get_chest_position()
	hit.direction = dir
	# throw.tres knockback, turned toward the stick direction (z along it, y up).
	hit.knockback = dir * move.knockback.z + dir.cross(Vector3.UP) * move.knockback.x + Vector3.UP * move.knockback.y
	hit.from_behind = victim.get_forward().dot(dir) > 0.0
	hit.physics_frame = Engine.get_physics_frames()
	hit.move_frame = move_frame
	hit.chain_step = move_chain_step
	hit.input_timing = move_input_timing
	if victim.receive_hit(hit):
		TimeController.hitstop([self, victim], Tuning.data.hitstop_s(move.tier))
		CombatEvents.thrown.emit(self, victim)
		CombatEvents.hit_landed.emit(hit)


func _find_weapon() -> Weapon:
	var best: Weapon = null
	var best_dist := Tuning.data.pickup_range
	for node in get_tree().get_nodes_in_group(&"weapon"):
		var weapon := node as Weapon
		if weapon == null or not weapon.is_available():
			continue
		var dist := weapon.global_position.distance_to(global_position + Vector3.UP * 0.3)
		if dist <= best_dist:
			best_dist = dist
			best = weapon
	return best


func _pick_up(weapon: Weapon) -> void:
	parser.reset_chain()
	_weapon = weapon
	weapon.attach_to(self)
	_use_set(&"weapon")
	rig.play(&"pickup", 0.05)
	_action_lock = Tuning.data.pickup_lock_frames
	CombatEvents.weapon_picked_up.emit(self, weapon)
