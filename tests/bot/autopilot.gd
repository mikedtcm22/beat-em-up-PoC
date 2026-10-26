extends Node
## The autopilot (Milestone 3, M3-plan A3.5): a scripted player for the crowd bot's fight acts
## and for the readability probe's metrics (R3, R11, R12, R13 need somebody fighting). It drives
## the player through its scripted PlayerInput like any bot: scripted_move, pushed presses and
## the look's yaw, never game state. It plays like a decent, slightly slow human:
## - **Grabbed:** mashes P and K (the enemy grab's break-free, SPEC §4).
## - **Two or more wind-ups about to land:** dodges sideways, away from where they are.
## - **One wind-up about to land in front:** raises the guard (B with the stick centered) a few
##   frames before the strike, holds it until the attack is over.
## - **A wind-up out of view** (the rear warning's corner): turns to it after a reaction time, and
##   quick-turns (TURN) when it is directly behind (both corners).
## - **Otherwise:** faces the nearest enemy, walks up to it and chains P P P P (then K K K).
## Every threshold below is a bot setting (a skill knob), not a game tunable, so none of them is
## in TuningData; the rules it follows (the guard's arc, the view and behind angles, the dodge
## and quick-turn lengths) are read from Tuning. A plain helper a bot owns: attach(), tick()
## (once per physics frame, done by its own _physics_process unless `auto_tick` is off),
## result(), stop().

## The label of what it decided last tick, for a bot's log: &"idle", &"mash", &"dodge",
## &"block", &"turn_behind", &"quick_turn", &"attack", &"approach", &"face" or &"down".
signal decided(decision: StringName)

## Off: tick() does nothing (and stop() has released everything).
@export var enabled: bool = true
## Tick in this node's own _physics_process. Off: the owner calls tick() once per physics frame.
@export var auto_tick: bool = true
## Runs before the actors (a smaller number is earlier), so the pushed input is this frame's.
@export var early_priority: int = -100
## The group it fights: the AI enemies and the training dummies are both in "enemy".
@export var enemy_group: StringName = &"enemy"
@export_group("Skill")
## Frames between a wind-up's start and the autopilot reacting to it (a human's reaction time).
@export_range(0, 60) var reaction_frames: int = 10
## How fast it turns (degrees per second).
@export_range(30.0, 1440.0) var turn_deg_per_s: float = 540.0
## It raises the guard when the strike is this many frames away.
@export_range(0, 40) var block_lead_frames: int = 6
## It dodges when the strike is this many frames away (the dodge's invulnerability must cover it).
@export_range(0, 40) var dodge_lead_frames: int = 8
## Frames between two dodges.
@export_range(0, 300) var dodge_cooldown_frames: int = 45
## An attack counts as a threat within its reach plus this (m).
@export_range(0.0, 2.0) var threat_margin_m: float = 0.35
## Frames the guard stays up after the last threat, and the most it is held.
@export_range(0, 60) var block_release_frames: int = 10
@export_range(1, 600) var block_hold_max_frames: int = 90
## It throws punches at an enemy within this many metres and walks up to within the stop distance.
@export_range(0.5, 4.0) var engage_range_m: float = 1.9
@export_range(0.5, 4.0) var approach_stop_m: float = 1.3
## It only walks toward an enemy within this (m); beyond it, it just faces it.
@export_range(1.0, 20.0) var approach_max_m: float = 6.0
## It punches when the enemy is within this many degrees of the look.
@export_range(1.0, 90.0) var aim_tolerance_deg: float = 14.0
## Frames between two presses of a chain, and the rest after a whole chain.
@export_range(2, 40) var punch_gap_frames: int = 10
@export_range(0, 120) var chain_rest_frames: int = 24
## The chain lengths: P P P P, then K K K (use_kicks), and so on.
@export_range(1, 8) var punches_per_chain: int = 4
@export_range(1, 8) var kicks_per_chain: int = 3
@export var use_kicks: bool = true
## Frames between two mash presses while grabbed.
@export_range(2, 20) var mash_gap_frames: int = 3
## Frames between two quick turns.
@export_range(0, 300) var quick_turn_cooldown_frames: int = 36
## Which behaviours are on (an act can fight without ever blocking, say).
@export var defend: bool = true
@export var attack: bool = true
@export var approach: bool = true
## Seeds the dodge's coin toss when the threats are dead ahead (deterministic runs).
@export var rng_seed: int = 1

## The last decision (see `decided`).
var decision: StringName = &"idle"
var player: PlayerCharacter

var _rng := RandomNumberGenerator.new()
var _block_held: bool = false
var _block_since: int = 0
var _last_threat: int = -1000000
var _dodge_ready: int = 0
var _quick_ready: int = 0
var _quick_until: int = -1
var _chain_left: int = 0
var _chain_kind: StringName = &"P"
var _chains_done: int = 0
var _next_press: int = 0
var _next_mash: int = 0
var _mash_p: bool = true
var _counts: Dictionary[StringName, int] = {}
var _attached: bool = false


func _ready() -> void:
	process_physics_priority = early_priority
	set_physics_process(auto_tick)
	_rng.seed = rng_seed
	reset_counters()


func _physics_process(_delta: float) -> void:
	tick()


## Take control of `the_player` (default: the first node in group "player"). `host` is where this
## node lives if it is not in the tree yet (the bot or the room). Puts the player's input in
## scripted mode.
func attach(host: Node = null, the_player: PlayerCharacter = null) -> void:
	if not is_inside_tree() and host:
		host.add_child(self)
	player = the_player
	_find_player()
	if player:
		player.input.scripted = true
	if not _attached:
		_attached = true
		CombatEvents.quick_turned.connect(_on_quick_turned)


func _exit_tree() -> void:
	if _attached:
		_attached = false
		CombatEvents.quick_turned.disconnect(_on_quick_turned)


## Counts of what it has done since reset_counters(): ticks, punches, kicks, blocks, dodges,
## quick_turns, mashes, and the ticks spent blocking, turning and approaching.
func result() -> Dictionary:
	var out: Dictionary = {}
	for key in _counts:
		out[String(key)] = _counts[key]
	return out


func reset_counters() -> void:
	_counts.clear()
	for key: StringName in [&"ticks", &"punches", &"kicks", &"blocks", &"dodges", &"quick_turns",
			&"mashes", &"block_ticks", &"turn_ticks", &"approach_ticks"]:
		_counts[key] = 0


## Let go of everything: the guard, the stick, the queued presses. The player is left standing.
func stop() -> void:
	if player == null or not is_instance_valid(player):
		return
	if _block_held:
		player.input.push_up(&"DODGE")
		_block_held = false
	player.input.scripted_move = Vector2.ZERO
	_chain_left = 0


## Decide and push this frame's input.
func tick() -> void:
	if not enabled:
		return
	if not _find_player():
		return
	var frame := Engine.get_physics_frames()
	_counts[&"ticks"] += 1
	if player.health <= 0.0 or _cannot_act():
		_idle_down()
		_decide(&"down")
		return
	if player.state == CombatTypes.ActorState.GRABBED:
		_mash(frame)
		return
	var enemies := _enemies()
	var threats := _threats(enemies)
	var ready: Array[Dictionary] = []
	for threat in threats:
		if int(threat.age) >= reaction_frames:
			ready.append(threat)
	if not threats.is_empty():
		_last_threat = frame
	var focus := _focus(enemies, threats)
	_face(focus, frame)
	if defend:
		var dodging := _try_dodge(ready, frame)
		if dodging:
			return
		if _try_block(ready, threats, frame):
			return
		if _try_quick_turn(ready, frame):
			return
		if _is_behind_threat(focus, ready):
			# Turning to a wind-up out of view (the warning's corner): hold still until it is in front.
			player.input.scripted_move = Vector2.ZERO
			_chain_left = 0
			_decide(&"turn_behind")
			return
	if attack or approach:
		_fight(focus, frame)
	else:
		player.input.scripted_move = Vector2.ZERO
		_decide(&"face" if focus != null else &"idle")


# --- Seeing -----------------------------------------------------------------------------------


func _find_player() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter if is_inside_tree() else null
		if player:
			player.input.scripted = true
	return player != null


## Live, upright enemies the player could fight.
func _enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(enemy_group):
		var enemy := node as CombatActor
		if enemy == null or enemy == player or enemy.team == player.team or enemy.health <= 0.0 or enemy.is_gone():
			continue
		if enemy.state in [CombatTypes.ActorState.KO, CombatTypes.ActorState.DOWNED,
				CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.THROWN, CombatTypes.ActorState.GETUP,
				CombatTypes.ActorState.GRABBED]:
			continue
		out.append(enemy)
	return out


## Enemies whose strike can reach the player: in WINDUP, or striking now. Each as {enemy,
## bearing, dist, remaining (frames to the strike, 0 once it is out), age (frames since the
## wind-up began), front (inside the guard's arc)}.
func _threats(enemies: Array[Node3D]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node in enemies:
		var enemy := node as CombatActor
		var move := enemy.current_move
		if move == null:
			continue
		var winding := enemy.state == CombatTypes.ActorState.WINDUP
		var striking := enemy.state == CombatTypes.ActorState.ATTACK and enemy.move_frame < move.startup + move.active
		if not (winding or striking):
			continue
		var dist := _flat_distance(enemy)
		var reach := move.reach_m if move.reach_m > 0.0 else engage_range_m
		if dist > reach + threat_margin_m:
			continue
		var bearing := player.look_bearing_deg(enemy.global_position)
		out.append({
			"enemy": enemy,
			"bearing": bearing,
			"dist": dist,
			"remaining": maxi(move.startup - enemy.move_frame, 0) if winding else 0,
			"age": enemy.move_frame,
			"front": absf(bearing) <= Tuning.data.block_arc_half_angle_deg,
		})
	return out


func _flat_distance(node: Node3D) -> float:
	var d := node.global_position - player.global_position
	return Vector2(d.x, d.z).length()


## Where to look: the nearest wind-up that has been seen long enough, else the nearest enemy.
func _focus(enemies: Array[Node3D], threats: Array[Dictionary]) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for threat in threats:
		if int(threat.age) >= reaction_frames and float(threat.dist) < best_dist:
			best_dist = threat.dist
			best = threat.enemy
	if best:
		return best
	for enemy in enemies:
		var dist := _flat_distance(enemy)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _cannot_act() -> bool:
	return player.state in [CombatTypes.ActorState.KO, CombatTypes.ActorState.DOWNED,
			CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.THROWN, CombatTypes.ActorState.GETUP,
			CombatTypes.ActorState.HITSTUN, CombatTypes.ActorState.STAGGER]


# --- Doing ------------------------------------------------------------------------------------


func _decide(what: StringName) -> void:
	decision = what
	decided.emit(what)


func _idle_down() -> void:
	player.input.scripted_move = Vector2.ZERO
	_chain_left = 0
	if _block_held:
		_block_held = false


## Turn toward `focus` at turn_deg_per_s (not while a quick turn is running).
func _face(focus: Node3D, frame: int) -> void:
	if focus == null or frame < _quick_until:
		return
	var bearing := player.look_bearing_deg(focus.global_position)
	var step := turn_deg_per_s / float(Engine.physics_ticks_per_second)
	var turn := clampf(bearing, -step, step)
	if absf(turn) > 0.0001:
		player.look_yaw = wrapf(player.look_yaw + deg_to_rad(turn), -PI, PI)
		_counts[&"turn_ticks"] += 1


func _mash(frame: int) -> void:
	player.input.scripted_move = Vector2.ZERO
	_chain_left = 0
	if frame >= _next_mash and player.input.queued() == 0:
		_next_mash = frame + mash_gap_frames
		player.input.push_press(&"P" if _mash_p else &"K", 1)
		_mash_p = not _mash_p
		_counts[&"mashes"] += 1
	_decide(&"mash")


## Two or more wind-ups about to land: B with the stick to the side away from them.
func _try_dodge(ready: Array[Dictionary], frame: int) -> bool:
	var imminent: Array[Dictionary] = []
	for threat in ready:
		if int(threat.remaining) <= dodge_lead_frames:
			imminent.append(threat)
	if imminent.size() < 2 or frame < _dodge_ready or player.input.queued() > 0:
		return false
	if player.state not in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.BLOCK, CombatTypes.ActorState.ATTACK]:
		return false
	var lateral := 0.0
	for threat in imminent:
		lateral += sin(deg_to_rad(float(threat.bearing)))
	# Threats on the left (positive bearings): step right (the stick's +x), and the other way round.
	var side := 1.0 if lateral > 0.0 else -1.0
	if absf(lateral) < 0.05:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	if _block_held:
		player.input.push_up(&"DODGE")
		_block_held = false
	# The frames carry the stick held when they are pushed; B with it off center is a dodge.
	player.input.scripted_move = Vector2(side, 0.0)
	player.input.push_press(&"DODGE", 2)
	player.input.scripted_move = Vector2.ZERO
	_dodge_ready = frame + dodge_cooldown_frames
	_counts[&"dodges"] += 1
	_chain_left = 0
	_decide(&"dodge")
	return true


## One wind-up about to land inside the guard's arc: the guard up (B with the stick centered), held
## until the attack is over. Returns true while it is (or just was) blocking this tick.
func _try_block(ready: Array[Dictionary], threats: Array[Dictionary], frame: int) -> bool:
	var imminent := false
	for threat in ready:
		if bool(threat.front) and int(threat.remaining) <= block_lead_frames:
			imminent = true
	if imminent and not _block_held:
		if player.input.queued() > 0 or player.state not in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.ATTACK]:
			return false
		player.input.scripted_move = Vector2.ZERO
		player.input.push_down(&"DODGE")
		_block_held = true
		_block_since = frame
		_chain_left = 0
		_counts[&"blocks"] += 1
	if not _block_held:
		return false
	var over := threats.is_empty() and frame - _last_threat >= block_release_frames
	if over or frame - _block_since >= block_hold_max_frames:
		if player.input.queued() == 0:
			player.input.push_up(&"DODGE")
			_block_held = false
		return false
	player.input.scripted_move = Vector2.ZERO
	_counts[&"block_ticks"] += 1
	_decide(&"block")
	return true


## A wind-up out of view and directly behind (the warning's both corners): quick turn.
func _try_quick_turn(ready: Array[Dictionary], frame: int) -> bool:
	if frame < _quick_ready or player.input.queued() > 0 or _block_held:
		return false
	if player.state != CombatTypes.ActorState.FREE:
		return false
	for threat in ready:
		if absf(float(threat.bearing)) >= 180.0 - Tuning.data.rear_warning_behind_deg:
			player.input.push_press(&"TURN", 2)
			_quick_ready = frame + quick_turn_cooldown_frames
			_chain_left = 0
			_decide(&"quick_turn")
			return true
	return false


## True when `focus` is one of the seen wind-ups and out of the view (the rear warning's rule).
func _is_behind_threat(focus: Node3D, ready: Array[Dictionary]) -> bool:
	for threat in ready:
		if threat.enemy == focus and absf(float(threat.bearing)) > Tuning.data.rear_warning_angle_deg:
			return true
	return false


func _on_quick_turned(actor: Node3D) -> void:
	if actor == player:
		_quick_until = Engine.get_physics_frames() + maxi(Tuning.data.quick_turn_frames, 1)
		_counts[&"quick_turns"] += 1


## The offence: close in on the focus and chain punches and kicks while it is in range and in the
## look's sights.
func _fight(focus: Node3D, frame: int) -> void:
	if focus == null:
		player.input.scripted_move = Vector2.ZERO
		_chain_left = 0
		_decide(&"idle")
		return
	var dist := _flat_distance(focus)
	var bearing := player.look_bearing_deg(focus.global_position)
	var walk := approach and dist > approach_stop_m and dist <= approach_max_m and absf(bearing) <= 90.0
	player.input.scripted_move = Vector2(0.0, 1.0) if walk else Vector2.ZERO
	if walk:
		_counts[&"approach_ticks"] += 1
	if attack and dist <= engage_range_m and absf(bearing) <= aim_tolerance_deg:
		_press_chain(frame)
		_decide(&"attack")
	else:
		_decide(&"approach" if walk else &"face")


func _press_chain(frame: int) -> void:
	if player.input.queued() > 0 or frame < _next_press:
		return
	if player.state not in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.ATTACK]:
		return
	if _chain_left <= 0:
		_chain_kind = &"K" if (use_kicks and _chains_done % 2 == 1) else &"P"
		_chain_left = kicks_per_chain if _chain_kind == &"K" else punches_per_chain
	player.input.push_press(_chain_kind, 2)
	_counts[&"kicks" if _chain_kind == &"K" else &"punches"] += 1
	_chain_left -= 1
	_next_press = frame + punch_gap_frames
	if _chain_left <= 0:
		_next_press = frame + punch_gap_frames + chain_rest_frames
		_chains_done += 1
