class_name EnemyActor
extends CombatActor
## The base of every AI enemy (Milestone 3, SPEC §7): the Street Punk, the Kicker, the Pipe Thug,
## the Bruiser and the boss extend it (TrainingDummy does not). The AI is an overlay on
## CombatActor's state machine: AiState says what the controller is doing, ActorState (state)
## stays CombatActor's, and behaviour runs only while FREE (plus turning during a WINDUP). The
## enemy director grants an attack token (grant_token()) to a waiting enemy; the enemy then
## commits, closes in, asks the director's may_start_windup() and starts its attack with a held
## wind-up (start_move(..., windup = true): the rear warning and the interrupt rules hang off it).
##
## The life of an enemy: ENTER (walk in from its spawn point) -> APPROACH (path to its posture
## slot) -> POSTURE (circle, strafe, pause, now and then taunt on the ring around the player,
## facing him) -> with a token ENGAGE (stop strafing and square up for commit_pause_frames, then
## step in to its attack's reach minus engage_margin_m) -> WINDUP (the attack's startup, scaled
## by windup_mult and floored: it turns toward the player for the first windup_track_share, then
## the facing is locked, so a late sidestep makes it miss) -> ATTACK (a chain link follows with no
## wind-up of its own, only if the last hit landed or was blocked) -> RECOVER (the token goes
## back and the attack cooldown starts, it holds recover_hold_s, then backs off to its slot) ->
## POSTURE. REACT is any reaction state CombatActor put it in (the token is released at once);
## KO is dead. A light hit interrupts a grunt's wind-up (CombatActor's default); armor
## (armor_light and the flags below, used by the heavies) keeps it going.
##
## Moving: a NavigationAgent3D with avoidance, driven the "latched" way (docs/milestones/
## M3-codemap/godot-navigation.md): every sim tick the desired velocity goes to the agent and
## last tick's safe velocity becomes sim_velocity; velocity_computed only stores it, and
## CombatActor._integrate() moves the body (hitstop and slow-mo apply). With no navmesh (the
## training room) it steers straight. All distances are flat (XZ): the navmesh floats above the
## floor.
##
## Groups: every EnemyActor is in "actor" (CombatActor), "enemy" and "ai_enemy"; the boss also
## "boss". A dead enemy is `health <= 0` (not is_ko(): a killing blow flies first); once
## is_gone() it leaves every group, then queue_free()s. Every number is a Tuning value
## (groups Wind-up, Posture, Navigation) or a move's.
##
## An archetype extends this and overrides the hooks (_build_attacks(), _health_tunable(),
## _speed_tunable(), _cooldown_tunable(), _circle_mult(), _choose_attack(), _wakes_in_place(),
## _configure_rig()) and never replaces the control tick. A few archetypes go further, each one
## logged in docs/milestones/M3-calls/ and held by a test of its own: the Bruiser and the boss wrap
## _tick_control() (calling super: the boss's phase 2 and call-in, the Bruiser's armor break), the
## boss also turns by _face() and answers a parry in react_to_block(), the Bruiser keeps a brace
## pose through _stop() and _animate_legs() and moves its hold spot in _pin_spot(), the Kicker picks
## its strafe side in _pick_strafe_dir(), and the Pipe Thug rewrites its attacks. Every override of
## a private member calls super() unless its doc says otherwise, and promoting these to hooks is
## left for a later refactor. The fixture tests/fixtures/stub_enemy.gd replaces every behaviour hook
## with a standing-still enemy for the other packages' tests.

## What the controller is doing. ENTER walks in from the spawn point, APPROACH walks to the
## posture slot, POSTURE circles on the ring, ENGAGE has a token and closes to strike range,
## WINDUP and ATTACK mirror the running move, RECOVER backs off, REACT is any reaction state
## CombatActor put it in, KO is dead.
enum AiState { ENTER, APPROACH, POSTURE, ENGAGE, WINDUP, ATTACK, RECOVER, REACT, KO }

## Two velocities closer than this (m/s, squared) count as the same (_reset_avoidance()).
const RESET_EPSILON_SQ := 0.0025

## &"punk", &"kicker", &"thug", &"bruiser" or &"boss".
@export var archetype: StringName = &""
## Bruiser and boss: the rear warning's burst is larger, the wind-up floor is the heavy one.
@export var heavy: bool = false
## The Kicker: the director gives it slots in the blind arc first.
@export var prefers_blind_side: bool = false
## The audio director's pitch multiplier for this enemy's voice (deeper heavies), read duck-typed.
@export var voice_pitch_mult: float = 1.0
## Armor (the Bruiser and the boss set these): a LIGHT hit that does not break armor lands its
## damage but is absorbed (no flinch, the move runs on); a HEAVY hit staggers instead of
## whatever it would do; a FINISHER staggers instead of launching or knocking down. A hit from a
## move with breaks_armor (the haymaker) and a killing hit are never softened.
@export var armor_light: bool = false
@export var armor_heavy_to_stagger: bool = false
@export var armor_finisher_to_stagger: bool = false

## What the controller is doing. Read-only outside.
var ai_state: AiState = AiState.APPROACH
## Holds an attack token. Read-only outside; the director sets it (grant_token(), revoke_token()).
var has_token: bool = false
## The last token came from blind-spot priority (shown in F3).
var blind_priority_granted: bool = false
## Where the director wants it to stand on the posture ring; Vector3.INF = none.
var posture_slot: Vector3 = Vector3.INF

## Cached wind-up copies of moves (windup_move()), keyed by move id, multiplier and floor.
static var _windup_cache: Dictionary[String, MoveData] = {}
static var _watching_tuning: bool = false

## Where enter_from() was told to walk to (Vector3.INF = nowhere: it goes straight to APPROACH).
var _lane_point: Vector3 = Vector3.INF
var _attacks: Array[EnemyAttack] = []
## The attack it will throw next (picked when it re-arms and when a token is granted) and the
## one it is throwing.
var _next_attack: EnemyAttack
var _attack: EnemyAttack
## force_attack(): the attack index to start from FREE (-1 = none pending).
var _forced_index: int = -1
var _nav: NavigationAgent3D
## Last tick's answer of the avoidance (velocity_computed only stores it).
var _safe_velocity: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _ticks: int = 0
var _navmesh_ready: bool = false
var _director_checked: bool = false
## Sim-frame timers.
var _cooldown_frames: int = 0
var _commit_frames: int = 0
var _engage_frames: int = 0
var _recover_frames: int = 0
var _taunt_frames: int = 0
var _pause_frames: int = 0
var _strafe_frames: int = 0
var _strafe_dir: float = 1.0
## Progress toward the walk's target: the nearest it has got and the frames since it got
## nearer by enemy_slot_reach_m (a stall asks for another slot).
var _progress_best: float = INF
var _progress_frames: int = 0
## A stall's detour spot and the frames it still holds, which way round the player the last one
## went (+1 or -1, 0 before the first) and the tick of the last stall (a stall again soon after
## goes the other way).
var _detour: Vector3 = Vector3.INF
var _detour_frames: int = 0
var _detour_side: float = 0.0
var _last_stall_tick: int = -1000000
## The way round the ring (_orbit_toward()): a point on the ring it is walking to, kept as an angle
## and radius about the player (so it goes with him when he walks), and the physics frame in which
## _posture_target() last handed the walk such a point rather than the goal itself (an arrival is
## only an arrival at a point on the way round in that same frame, whoever calls _enter_posture()
## from another frame takes up the posture).
var _orbit_active: bool = false
var _orbit_angle: float = 0.0
var _orbit_radius: float = 0.0
var _orbit_frame: int = -1
## Sim frames left of the wake-up hold (_resume_posture()): POSTURE does not send it back to a slot
## it left, and the director serves it first.
var _resume_frames: int = 0
var _retarget_offset: int = 0
## Which side of the player's origin a step-in aims at, once per enemy (+1 or -1; see _engage_aim()).
var _engage_side: float = 1.0
var _cleaned_up: bool = false


func _ready() -> void:
	team = 1
	add_to_group(&"enemy")
	add_to_group(&"ai_enemy")
	_apply_health_tunable()
	super._ready()
	_rng.seed = hash(String(name))
	_retarget_offset = absi(hash(String(name)))
	_engage_side = 1.0 if hash(String(name)) & 1 == 0 else -1.0  # from the name: no draw from _rng
	_attacks = _build_attacks()
	_next_attack = _choose_attack()
	_setup_navigation()
	Tuning.changed.connect(_on_tuning_changed)


func _exit_tree() -> void:
	# Despawned, removed by F4 or the room switched with a token in hand: give it back.
	if has_token and is_inside_tree():
		_release_token()


# --- Archetype hooks ------------------------------------------------------------------------


## The attacks this archetype can throw (EnemyAttack: a chain of moves, a pick chance).
func _build_attacks() -> Array[EnemyAttack]:
	return []


## The TuningData property holding this archetype's health (&"punk_health"); empty keeps the
## exported max_health (the base, a test double).
func _health_tunable() -> StringName:
	return &""


## The TuningData property of its walking speed multiplier (&"punk_speed_mult"); empty = 1.
func _speed_tunable() -> StringName:
	return &""


## The TuningData property of the seconds it waits after an attack before it wants another
## token (&"punk_attack_cooldown_s"); empty = none.
func _cooldown_tunable() -> StringName:
	return &""


## Multiplies the posture circling speed (the Kicker flanks fast).
func _circle_mult() -> float:
	return 1.0


## True for an enemy that, once a reaction is over (a hit, a stagger, a knockdown and the get-up) with
## the player within the posture ring's far edge, takes up POSTURE where it stands, eligible for a
## token and served first by the director (has_token_priority()), instead of walking back to a slot
## 2.5-4 m away where it asks for nothing (the boss: a chain that floors it every few seconds could
## otherwise never be answered). Everything else goes back to its slot (APPROACH).
func _wakes_in_place() -> bool:
	return false


## Picks the attack to throw next: by default one at random by each attack's chance
## (EnemyAttack.weight_property), the unweighted ones sharing the rest. The boss picks by range.
func _choose_attack() -> EnemyAttack:
	if _attacks.is_empty():
		return null
	var roll := _rng.randf()
	var cumulative := 0.0
	var unweighted: Array[EnemyAttack] = []
	for attack: EnemyAttack in _attacks:
		if attack.weight_property == &"":
			unweighted.append(attack)
			continue
		cumulative += float(Tuning.data.get(attack.weight_property))
		if roll < cumulative:
			return attack
	if unweighted.is_empty():
		return _attacks[_attacks.size() - 1]
	return unweighted[_rng.randi() % unweighted.size()]


# --- The director's side --------------------------------------------------------------------


## The state's name (&"POSTURE"), for F3 and logs.
func ai_state_name() -> StringName:
	return StringName(AiState.keys()[ai_state])


## True when it would take an attack token now: posturing, its attack cooldown over, done
## entering, free, not mid-taunt, not frozen and no menu open.
func wants_token() -> bool:
	return (
		ai_state == AiState.POSTURE and state == CombatTypes.ActorState.FREE and not has_token
		and health > 0.0 and _cooldown_frames <= 0 and _taunt_frames <= 0
		and not _attacks.is_empty() and not Tuning.data.ai_frozen and not GameInput.menu_open
	)


## True while it is waking in place (_resume_posture()): it has just got up beside the player and
## the director serves it before the others (and before the blind-spot priority), so a heavy that
## was knocked down gets its turn instead of being left behind the queue.
func has_token_priority() -> bool:
	return _resume_frames > 0 and ai_state == AiState.POSTURE and not has_token


## The director grants it the token. `blind` = it came from blind-spot priority. It stops
## strafing and squares up on its next tick.
func grant_token(blind: bool) -> void:
	has_token = true
	blind_priority_granted = blind
	_resume_frames = 0


## The director takes the token back (the player became unhittable, or it timed out). An enemy
## still closing in drops the attack and goes back to its slot; one already winding up finishes.
func revoke_token() -> void:
	var was_engaging := has_token and ai_state == AiState.ENGAGE
	has_token = false
	blind_priority_granted = false
	if was_engaging:
		_enter_approach()


## The director's posture slot for it (world position).
func set_slot(pos: Vector3) -> void:
	posture_slot = pos
	_progress_best = INF
	_progress_frames = 0


## The reach_m of the attack it will throw next (0 = it has none).
func attack_range_m() -> float:
	return _next_attack.reach_m() if _next_attack else 0.0


## Seconds until the last strike of the attack it is throwing begins (the player is hit then, if
## it lands), assuming a chain goes on to its last link: 0 when none is under way, or its last
## strike has begun or whiffed. The director adds the hit grace to it (windup_eta_s()), so a holder
## waits on the ring for a strike that is about to land instead of standing at the nose through it.
func last_strike_eta_s() -> float:
	if current_move == null or not _running_move():
		return 0.0
	var move := current_move
	if move_frame >= move.startup + move.active and not _move_landed_hit:
		return 0.0  # it whiffed: the chain ends here
	var links: Array[MoveData] = []
	if _attack:
		links = _attack.moves
	var index := -1
	for i in links.size():
		if links[i].id == move.id:
			index = i
	var frames := move.startup - move_frame
	if index >= 0 and index < links.size() - 1:
		frames = move.total_frames() - move_frame
		for i in range(index + 1, links.size() - 1):
			frames += links[i].total_frames()
		frames += links[links.size() - 1].startup
	return maxf(float(frames), 0.0) / float(Engine.physics_ticks_per_second)


## Bots and tests: skip the token and wind up now, from FREE (started from the next control
## tick, as every move must be). `index` picks the attack from the archetype's list.
func force_attack(index: int = 0) -> void:
	_forced_index = maxi(index, 0)


## The spawner: walk in from `spawn_pos` (where it stands) to `lane_point`, then take up the
## posture ring. A `lane_point` that is not finite goes straight to APPROACH.
func enter_from(_spawn_pos: Vector3, lane_point: Vector3) -> void:
	_lane_point = lane_point
	ai_state = AiState.ENTER
	_progress_best = INF
	_progress_frames = 0


## `move` with its startup scaled by Tuning.data.windup_mult and floored at
## windup_min_frames_heavy (`heavy`) or windup_min_frames_grunt, a duplicate cached per move id
## (compare moves by id: hit.move is the duplicate). A move whose scaled startup is its own is
## returned as it is, so F1 edits of it apply live.
static func windup_move(move: MoveData, heavy_attack: bool) -> MoveData:
	if move == null:
		return null
	_watch_tuning()
	var tuning := Tuning.data
	var floor_frames: int = tuning.windup_min_frames_heavy if heavy_attack else tuning.windup_min_frames_grunt
	var startup := maxi(floor_frames, roundi(move.startup * tuning.windup_mult))
	if startup == move.startup:
		return move
	var key := "%s|%s|%d" % [move.id, tuning.windup_mult, floor_frames]
	var cached: MoveData = _windup_cache.get(key)
	if cached == null or cached.startup != startup:
		cached = move.duplicate() as MoveData
		cached.startup = startup
		_windup_cache[key] = cached
	return cached


## Drops the wind-up copies when the multiplier, a floor or a move (F1) changes.
static func _watch_tuning() -> void:
	if _watching_tuning:
		return
	_watching_tuning = true
	Tuning.changed.connect(_on_windup_inputs_changed)


static func _on_windup_inputs_changed(property: StringName) -> void:
	var text := String(property)
	if text == "" or text == "windup_mult" or text.begins_with("windup_min_frames") or text.begins_with(Tuning.MOVE_PREFIX):
		_windup_cache.clear()


# --- Setup ----------------------------------------------------------------------------------


## Health from the archetype's tunable, before CombatActor._ready() copies it.
func _apply_health_tunable() -> void:
	var tunable := _health_tunable()
	if tunable != &"" and tunable in Tuning.data:
		max_health = float(Tuning.data.get(tunable))


func _setup_navigation() -> void:
	_nav = NavigationAgent3D.new()
	_nav.name = "NavAgent"
	_nav.avoidance_enabled = true
	_nav.use_3d_avoidance = false
	_apply_navigation_settings()
	add_child(_nav)
	_nav.velocity_computed.connect(_on_velocity_computed)


## The agent's numbers from the Navigation tunables (and re-applied when one changes).
func _apply_navigation_settings() -> void:
	var tuning := Tuning.data
	_nav.radius = maxf(tuning.enemy_avoid_radius_m, body_radius)
	_nav.height = body_height
	_nav.max_speed = tuning.enemy_max_speed_mps
	_nav.path_desired_distance = tuning.enemy_waypoint_reach_m
	_nav.target_desired_distance = tuning.enemy_slot_reach_m
	_nav.neighbor_distance = tuning.enemy_avoid_neighbor_m
	_nav.time_horizon_agents = tuning.enemy_avoid_horizon_s


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity


## A new health tunable keeps the share of health left; the navigation numbers re-apply.
func _on_tuning_changed(property: StringName) -> void:
	if _nav and (property == &"" or String(property).begins_with("enemy_")):
		_apply_navigation_settings()
	var tunable := _health_tunable()
	if tunable == &"" or (property != tunable and property != &""):
		return
	var new_max := float(Tuning.data.get(tunable))
	if is_equal_approx(max_health, new_max):
		return
	var share := health / max_health if max_health > 0.0 else 1.0
	max_health = new_max
	health = max_health * share
	CombatEvents.health_changed.emit(self, health, max_health)


# --- The control tick -----------------------------------------------------------------------


func _tick_control() -> void:
	_ticks += 1
	if _cooldown_frames > 0:
		_cooldown_frames -= 1
	if _detour_frames > 0:
		_detour_frames -= 1
	_ensure_director_once()
	_navmesh_ready = _has_navmesh()
	if health <= 0.0:
		_tick_dead()
		return
	var player := _find_player()
	match state:
		CombatTypes.ActorState.FREE:
			_tick_free(player)
		CombatTypes.ActorState.WINDUP:
			_tick_windup(player)
		CombatTypes.ActorState.ATTACK:
			ai_state = AiState.ATTACK
			_report_velocity()
		_:
			_tick_reaction()


## An F4 spawn in the training room has no director: the first tick adds one (deferred, so no
## node joins the tree mid-physics). Left to the first tick rather than _ready() so a test
## double that replaces this tick adds none.
func _ensure_director_once() -> void:
	if _director_checked:
		return
	_director_checked = true
	if EnemyDirector.find(get_tree()) == null:
		_add_director.call_deferred()


func _add_director() -> void:
	if is_inside_tree() and get_parent() and EnemyDirector.find(get_tree()) == null:
		EnemyDirector.ensure(get_parent())


func _tick_dead() -> void:
	ai_state = AiState.KO
	_release_token()
	_taunt_frames = 0
	_resume_frames = 0
	if _nav and _nav.avoidance_enabled:
		_nav.avoidance_enabled = false
	_stop_reporting()


## A reaction state (hitstun, stagger, launched, downed, get-up, grabbed, block): the token is
## released at once, the body is CombatActor's.
func _tick_reaction() -> void:
	ai_state = AiState.KO if state == CombatTypes.ActorState.KO else AiState.REACT
	_taunt_frames = 0
	_resume_frames = 0
	if has_token:
		_release_token()
	_report_velocity()


func _tick_free(player: CombatActor) -> void:
	if _forced_index >= 0 and not _attacks.is_empty():
		var index := mini(_forced_index, _attacks.size() - 1)
		_forced_index = -1
		_next_attack = _attacks[index]
		_start_attack(_next_attack)
		return
	if player == null or Tuning.data.ai_frozen or GameInput.menu_open:
		_hold_still(player)
		return
	if has_token and (ai_state == AiState.POSTURE or ai_state == AiState.APPROACH or ai_state == AiState.ENTER):
		_enter_engage()
	match ai_state:
		AiState.ENTER:
			_tick_enter(player)
		AiState.APPROACH:
			_tick_approach(player)
		AiState.POSTURE:
			_tick_posture(player)
		AiState.ENGAGE:
			_tick_engage(player)
		AiState.RECOVER:
			_tick_recover(player)
		_:
			# REACT, WINDUP, ATTACK or KO left over from before: it is free again.
			_after_reaction(player)


## Free again after a reaction: back to its slot (APPROACH), or, for an archetype that wakes in
## place and stands within the posture ring's far edge, POSTURE where it stands.
func _after_reaction(player: CombatActor) -> void:
	if _wakes_in_place() and _flat_dist(global_position, player.global_position) <= Tuning.data.posture_ring_max_m:
		_resume_posture()
	else:
		_enter_approach()


## Frozen (Debug), a menu open or nobody to fight: stand, facing the player, asking for nothing.
func _hold_still(player: CombatActor) -> void:
	if ai_state == AiState.REACT or ai_state == AiState.WINDUP or ai_state == AiState.ATTACK or ai_state == AiState.KO:
		ai_state = AiState.POSTURE
	_taunt_frames = 0
	_stop()
	if player:
		_face(_flat(player.global_position - global_position), Tuning.data.enemy_turn_rate)


# --- ENTER, APPROACH, POSTURE ---------------------------------------------------------------


func _tick_enter(player: CombatActor) -> void:
	if not _lane_point.is_finite() or _flat_dist(global_position, _lane_point) <= Tuning.data.enemy_slot_reach_m:
		_enter_approach()
		return
	_travel(_lane_point, _walk_speed(), false, player)
	if _stalled(_lane_point):
		# Blocked on the way in: give up the lane and find the ring.
		_enter_approach()


func _enter_approach() -> void:
	# From ENGAGE (a step-in toward the player) or a reaction the agent's velocity points the other
	# way from the walk to the slot: start from rest.
	_reset_avoidance()
	ai_state = AiState.APPROACH
	_progress_best = INF
	_progress_frames = 0
	_commit_frames = 0
	_taunt_frames = 0
	_resume_frames = 0
	_orbit_active = false


func _tick_approach(player: CombatActor) -> void:
	var target := _posture_target(player)
	if _flat_dist(global_position, target) <= Tuning.data.enemy_slot_reach_m:
		_enter_posture()
		return
	var near := _flat_dist(global_position, player.global_position) <= Tuning.data.posture_ring_max_m
	_travel(target, _walk_speed(), near, player)
	if _stalled(target):
		_start_detour(player)


## Where to walk to take up the ring: the slot (or whatever _goal_spot() picked: a detour, the
## nearest spot of the ring) when the straight way there is clear of the player, otherwise a point on
## the ring posture_orbit_lead_deg ahead of it round the short way (_orbit_toward()), so it circles
## the player at the ring's radius instead of crossing his front on the chord to a slot behind him.
## APPROACH and RECOVER ask it every tick, for every archetype.
func _posture_target(player: CombatActor) -> Vector3:
	var goal := _goal_spot(player)
	var round_the_ring := _orbit_toward(player, goal)
	if round_the_ring.is_finite():
		_orbit_frame = Engine.get_physics_frames()
		return round_the_ring
	return goal


## Where posturing happens: a detour after a stall, the director's slot, or the nearest spot of
## the ring on the line from the player (where it stands, once it is on the ring).
func _goal_spot(player: CombatActor) -> Vector3:
	if _detour_frames > 0 and _detour.is_finite():
		return _detour
	if posture_slot.is_finite():
		return posture_slot
	var away := _flat(global_position - player.global_position)
	var dist := away.length()
	if dist < 0.001:
		away = -_flat(player.get_forward())
		dist = away.length()
	var radius := clampf(dist, Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m)
	var spot := player.global_position + away.normalized() * radius
	spot.y = global_position.y
	return spot


## The point to walk to on the ring toward `goal`, or Vector3.INF when the straight way to it is the
## way to go. Inside the ring's near edge it is always a point (the back-out: on the ring, round
## toward the goal by at most the lead, so a body at the player's nose leaves sideways, facing him,
## and never walks through him), and beyond it only when `goal` is more than posture_orbit_gap_deg
## round the ring and the line to it cuts the near edge. A point once chosen is kept, as an angle
## and radius about the player, until it is reached or the goal turns out to lie the other way.
## Every point is checked against the navmesh (a point inside the parked car or a wall is skipped for
## a nearer leg or another radius); with none that is on it the straight way is all there is.
func _orbit_toward(player: CombatActor, goal: Vector3) -> Vector3:
	var tuning := Tuning.data
	var centre := player.global_position
	var mine := _flat(global_position - centre)
	var wanted := _flat(goal - centre)
	var inside := mine.length() < tuning.posture_ring_min_m
	var gap := _signed_angle(mine, wanted) if mine.length() > 0.01 and wanted.length() > 0.01 else 0.0
	if not inside and (absf(gap) <= deg_to_rad(tuning.posture_orbit_gap_deg) or _passes_clear_of(centre, global_position, goal)):
		_orbit_active = false
		return Vector3.INF
	if mine.length() <= 0.01:
		mine = -_flat(player.get_forward())
	var way := signf(gap)
	if _orbit_active:
		var kept := _orbit_position(centre)
		var ahead := _signed_angle(mine, _flat(kept - centre))
		var holds := signf(ahead) == way and (_flat_dist(global_position, kept) > tuning.enemy_slot_reach_m if inside \
				else absf(ahead) < absf(gap))
		if holds and _on_navmesh(kept):
			return kept
	var leg := minf(deg_to_rad(tuning.posture_orbit_lead_deg), absf(gap))
	# The back-out aims a slot reach beyond the near edge, so arriving at it is being on the ring.
	var radius := minf(tuning.posture_ring_min_m + tuning.enemy_slot_reach_m, maxf(tuning.posture_ring_max_m, tuning.posture_ring_min_m)) if inside \
			else clampf(mine.length(), tuning.posture_ring_min_m, tuning.posture_ring_max_m)
	var radii: Array[float] = [radius]
	for other: float in [tuning.posture_ring_max_m, tuning.posture_ring_min_m]:
		if not radii.has(other):
			radii.append(other)
	for factor: float in [1.0, 0.5]:
		var direction := mine.normalized().rotated(Vector3.UP, leg * factor * way)
		for candidate: float in radii:
			var spot := centre + direction * candidate
			spot.y = global_position.y
			if _on_navmesh(spot):
				_orbit_angle = _signed_angle(Vector3.RIGHT, direction)
				_orbit_radius = candidate
				_orbit_active = true
				return spot
	_orbit_active = false
	return Vector3.INF


func _orbit_position(centre: Vector3) -> Vector3:
	var spot := centre + Vector3.RIGHT.rotated(Vector3.UP, _orbit_angle) * _orbit_radius
	spot.y = global_position.y
	return spot


## True when the straight line from `from` to `to` stays at least the posture ring's near edge
## from `centre` (flat).
static func _passes_clear_of(centre: Vector3, from: Vector3, to: Vector3) -> bool:
	var closest := Geometry3D.get_closest_point_to_segment(_flat(centre), _flat(from), _flat(to))
	return _flat_dist(closest, centre) >= Tuning.data.posture_ring_min_m


## The signed flat angle (radians) from `a` to `b` about +Y, wrapped to -PI..PI.
static func _signed_angle(a: Vector3, b: Vector3) -> float:
	return a.signed_angle_to(b, Vector3.UP)


## True when `point` is on the navmesh (within director_slot_snap_tolerance_m of it, flat), or there
## is no navmesh to ask (the training room, a flat test floor).
func _on_navmesh(point: Vector3) -> bool:
	if not _navmesh_ready:
		return true
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)
	return _flat_dist(closest, point) <= Tuning.data.director_slot_snap_tolerance_m


## Arriving at the target takes up the posture, but reaching a point on the way round the ring is not
## reaching the slot: the walk goes on (the next tick picks the next point, or the slot when that is
## near) instead of taking up the posture, which would send it straight back to APPROACH, a stutter
## at every leg. Only an arrival in the same physics frame as the _posture_target() call that
## returned such a point is swallowed: any other caller gets the posture.
func _enter_posture() -> void:
	if _orbit_frame == Engine.get_physics_frames():
		_orbit_frame = -1
		_orbit_active = false
		_progress_best = INF
		_progress_frames = 0
		return
	ai_state = AiState.POSTURE
	_progress_best = INF
	_progress_frames = 0
	_detour_frames = 0
	_orbit_active = false
	_begin_pause()


## Free after a reaction beside the player (_wakes_in_place()): POSTURE where it stands, for
## posture_resume_s ignoring the slot it left (it strafes toward it, as POSTURE does, and backs out
## to the ring's near edge when it is inside), eligible for a token and served first (has_token_priority()).
## No taunt: it just got up.
func _resume_posture() -> void:
	_reset_avoidance()
	ai_state = AiState.POSTURE
	_progress_best = INF
	_progress_frames = 0
	_detour_frames = 0
	_orbit_active = false
	_commit_frames = 0
	_taunt_frames = 0
	_pause_frames = 0
	_resume_frames = maxi(_frames(Tuning.data.posture_resume_s), 1)
	_begin_strafe()


func _tick_posture(player: CombatActor) -> void:
	var tuning := Tuning.data
	var to_player := _flat(player.global_position - global_position)
	var dist := to_player.length()
	if dist > 0.01:
		_face(to_player, tuning.enemy_turn_rate)
	var waking := _resume_frames > 0
	if waking:
		_resume_frames -= 1
	# A taunt in progress plays out first: a reslot that moved the slot must not cut a gesture that
	# the director's own call-in started (the boss's beckon).
	if _taunt_frames > 0:
		_taunt_frames -= 1
		_stop()
		if _taunt_frames == 0:
			rig.play_locomotion(Vector2.ZERO, 0.0)
		return
	# Out of place (the slot moved, it was shoved, the player walked off): back to APPROACH. An
	# enemy waking in place has no business with the slot it left until the hold is over.
	var strayed := false
	if posture_slot.is_finite():
		strayed = not waking and _flat_dist(global_position, posture_slot) > tuning.posture_wander_m + tuning.enemy_slot_reach_m
	else:
		strayed = dist > tuning.posture_ring_max_m + tuning.posture_wander_m
	if strayed:
		_enter_approach()
		return
	var outward := -to_player.normalized() if dist > 0.01 else Vector3.ZERO
	# Never closer than the ring: back out at walking speed (a pause does not stop it).
	var too_close := dist < tuning.posture_ring_min_m
	if _pause_frames > 0:
		_pause_frames -= 1
		if too_close:
			_apply_velocity(outward * _walk_speed())
		else:
			_stop()
		if _pause_frames == 0:
			_begin_strafe()
		return
	_strafe_frames -= 1
	if _strafe_frames <= 0 or (not waking and posture_slot.is_finite() and _flat_dist(global_position, posture_slot) > tuning.posture_wander_m):
		# The segment is over, or it has strayed its leash: stand a moment, then go the other way.
		_begin_pause()
		return
	var tangent := Vector3(-outward.z, 0.0, outward.x) * _strafe_dir
	var velocity := tangent * (tuning.posture_circle_speed_mps * _circle_mult() * _speed_mult())
	# Stay on the ring: one metre a second per metre of error, at most the walking speed.
	var radius := clampf(dist, tuning.posture_ring_min_m, tuning.posture_ring_max_m)
	velocity += outward * clampf(radius - dist, -_walk_speed(), _walk_speed())
	_apply_velocity(velocity.limit_length(_walk_speed()))


## Stand for posture_pause_s; now and then, in that pause, taunt.
func _begin_pause() -> void:
	_strafe_frames = 0
	_pause_frames = _frames(Tuning.data.posture_pause_s)
	if _resume_frames <= 0 and _rng.randf() < Tuning.data.posture_taunt_chance:
		_start_taunt()
	if _pause_frames <= 0:
		_begin_strafe()


func _begin_strafe() -> void:
	var tuning := Tuning.data
	var seconds := tuning.posture_strafe_switch_s + _rng.randf_range(-1.0, 1.0) * tuning.posture_strafe_jitter_s
	_strafe_frames = maxi(_frames(seconds), 1)
	_strafe_dir = _pick_strafe_dir()


## Strafes either way at random, but back toward the slot once it is off it by more than the
## slot reach (a segment also ends at the leash, posture_wander_m).
func _pick_strafe_dir() -> float:
	var player := _find_player()
	if player and posture_slot.is_finite():
		var outward := _flat(global_position - player.global_position).normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var offset := _flat(posture_slot - global_position).dot(tangent)
		if absf(offset) > Tuning.data.enemy_slot_reach_m:
			return signf(offset)
	return 1.0 if _rng.randf() < 0.5 else -1.0


func _start_taunt() -> void:
	if not rig.anim_player.has_animation(&"taunt"):
		return
	_taunt_frames = _frames(rig.anim_player.get_animation(&"taunt").length)
	rig.play(&"taunt", rig.locomotion_blend_s)


# --- ENGAGE, the attack, RECOVER ------------------------------------------------------------


func _enter_engage() -> void:
	ai_state = AiState.ENGAGE
	_taunt_frames = 0
	_commit_frames = Tuning.data.commit_pause_frames
	_engage_frames = 0
	_next_attack = _choose_attack()
	_stop()


## True when the director's go is due before the walk to strike range (`distance_m` more) is over,
## give or take engage_go_lead_s: it should start walking now so as to arrive when the go does,
## not stand at the player's nose waiting for it. With no director there is nothing to wait for.
func _go_is_near(distance_m: float) -> bool:
	var director := EnemyDirector.find(get_tree())
	if director == null:
		return true
	var walk_s := distance_m / maxf(Tuning.data.engage_speed_mps * _speed_mult(), 0.01)
	return director.windup_eta_s(self) <= walk_s + Tuning.data.engage_go_lead_s


## Where a step-in aims: the player's origin moved engage_aim_offset_m to this enemy's side of the
## line between them. The avoidance sees the player as a circle, and a body whose wish points
## exactly at its centre is slowed to a crawl (the head-on tie) before it gets there.
func _engage_aim(player: CombatActor) -> Vector3:
	var to_player := _flat(player.global_position - global_position)
	if to_player.length_squared() < 0.0001:
		return player.global_position
	var side := Vector3(-to_player.z, 0.0, to_player.x).normalized() * (_engage_side * Tuning.data.engage_aim_offset_m)
	return player.global_position + side


func _tick_engage(player: CombatActor) -> void:
	if not has_token:
		_enter_approach()
		return
	var to_player := _flat(player.global_position - global_position)
	if to_player.length() > 0.01:
		_face(to_player, Tuning.data.enemy_turn_rate)
	if player.is_ko() or player.is_downed() or player.is_flying() or player.state == CombatTypes.ActorState.GRABBED:
		_give_up_engage()
		return
	if _commit_frames > 0:
		# "I'm next": stand square to the player before stepping in.
		_commit_frames -= 1
		_stop()
		return
	var want := attack_range_m() - Tuning.data.engage_margin_m
	if to_player.length() > want:
		if not _go_is_near(to_player.length() - want):
			# Its go is not due yet (the wind-up gap, a flinch, the hit grace, another holder's turn):
			# stay squared up where it stands, on the ring at first, and step in when the go is near.
			# The wait is not a failed chase: engage_timeout_s counts only the frames it spends walking.
			_stop()
			return
		_engage_frames += 1
		if _engage_frames > _frames(Tuning.data.engage_timeout_s):
			_give_up_engage()
			return
		_travel(_engage_aim(player), Tuning.data.engage_speed_mps * _speed_mult(), true, player)
		return
	_stop()
	if player.is_invulnerable() or not _director_says_go():
		return
	_start_attack(_next_attack)


func _give_up_engage() -> void:
	_release_token()
	_cooldown_frames = _frames(_cooldown_seconds())
	_enter_approach()


func _director_says_go() -> bool:
	var director := EnemyDirector.find(get_tree())
	return director == null or director.may_start_windup(self)


## Wind up `attack` now: the opening move scaled and floored, started from the control tick. The
## grab kind (an enemy holding the player) winds up the same way: its EnemyHold connects or whiffs
## at the strike frame (_on_move_frame()).
func _start_attack(attack: EnemyAttack) -> void:
	var move := attack.first() if attack else null
	if move == null:
		return
	_attack = attack
	if attack.kind == &"grab":
		_hold_arm(attack)
	_taunt_frames = 0
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	_stop_reporting()
	start_move(windup_move(move, heavy or attack.heavy), 1, &"root", true)
	ai_state = AiState.WINDUP if state == CombatTypes.ActorState.WINDUP else AiState.ATTACK


## The wind-up keeps turning toward the player for the first windup_track_share of its length,
## then the facing is locked.
func _tick_windup(player: CombatActor) -> void:
	ai_state = AiState.WINDUP
	_report_velocity()
	if player == null or current_move == null:
		return
	var tracking_frames := roundi(current_move.startup * Tuning.data.windup_track_share)
	if move_frame < tracking_frames:
		_face(_flat(player.global_position - global_position), deg_to_rad(Tuning.data.windup_track_deg_per_s))


func _on_move_frame(move: MoveData, frame: int) -> void:
	if _hold != null:
		_hold.on_move_frame(move, frame)
	# A step-in during the strike (a jump kick, a charge), never a slide through the telegraph. It
	# is set on the last startup frame: the lunge starts moving the body on the next one, the first
	# active frame, so the whole of free_lunge (which reach_m includes) is covered while the strike
	# is active.
	if frame == move.startup - 1 and move.free_lunge > 0.0:
		set_lunge(get_forward(), move.free_lunge, maxi(move.active, 1))


func _plan_lunge(_move: MoveData) -> void:
	pass


## The chain goes on only if the last hit landed or was blocked (a whiffed opener ends the
## attack); a link starts with no wind-up of its own. Otherwise it recovers.
func _on_move_finished(move: MoveData) -> void:
	var next := _attack.next_after(move) if _attack else null
	if next and _move_landed_hit and _chain_open():
		start_move(next, move_chain_step + 1, &"chain", false)
		return
	_return_to_neutral()
	_enter_recover()


## Anyone still there to be hit by the next link (the player is not down, flying or held).
func _chain_open() -> bool:
	var player := _find_player()
	return player != null and not (player.is_ko() or player.is_downed() or player.is_flying()
			or player.state == CombatTypes.ActorState.GRABBED)


## The attack is over: the token goes back and the cooldown starts, it holds for recover_hold_s
## and then backs off to its slot, facing the player.
func _enter_recover() -> void:
	ai_state = AiState.RECOVER
	_recover_frames = _frames(Tuning.data.recover_hold_s)
	_attack = null
	_release_token()
	_cooldown_frames = _frames(_cooldown_seconds())
	_next_attack = _choose_attack()
	_progress_best = INF
	_progress_frames = 0
	_orbit_active = false
	_reset_avoidance()


func _tick_recover(player: CombatActor) -> void:
	var to_player := _flat(player.global_position - global_position)
	if to_player.length() > 0.01:
		_face(to_player, Tuning.data.enemy_turn_rate)
	if _recover_frames > 0:
		_recover_frames -= 1
		_stop()
		return
	var target := _posture_target(player)
	if _flat_dist(global_position, target) <= Tuning.data.enemy_slot_reach_m:
		_enter_posture()
		return
	_travel(target, _walk_speed(), true, player)
	if _stalled(target):
		_start_detour(player)


# --- Reactions ------------------------------------------------------------------------------


## Hit (the guard did not stop it, armor did not absorb it): the attempt is over, the token goes
## back, a killing blow ends the AI.
func _on_hit_received(hit: HitInfo) -> void:
	var was_attacking := has_token or ai_state == AiState.WINDUP or ai_state == AiState.ATTACK or ai_state == AiState.ENGAGE
	_hold_release()
	_release_token()
	if was_attacking:
		_cooldown_frames = _frames(_cooldown_seconds())
	_attack = null
	_forced_index = -1
	_taunt_frames = 0
	ai_state = AiState.KO if hit.killed else AiState.REACT


## The guard knocked its attack back (a block's recoil, a parry's stagger).
func _on_move_interrupted() -> void:
	_release_token()
	_cooldown_frames = _frames(_cooldown_seconds())
	_attack = null
	ai_state = AiState.REACT


## Grabbed (the player's hold): the move is cancelled by CombatActor, the token goes back.
func _on_grabbed(_by: CombatActor) -> void:
	_release_token()
	_attack = null
	_taunt_frames = 0
	ai_state = AiState.REACT


## Armor (the Bruiser and the boss): see the exports. Never on a killing hit.
func _apply_armor(hit: HitInfo) -> void:
	if hit.killed or not (armor_light or armor_heavy_to_stagger or armor_finisher_to_stagger):
		return
	if state == CombatTypes.ActorState.GRABBED and hit.attacker == holder:
		return  # the hold's own knees and its throw: a held body takes them as any held body does
	if hit.move != null and hit.move.breaks_armor:
		return
	match hit.tier:
		CombatTypes.HitTier.LIGHT:
			if armor_light:
				hit.armor_absorbed = true
				hit.reaction = CombatTypes.Reaction.NONE
				hit.knockback = Vector3.ZERO
		CombatTypes.HitTier.HEAVY:
			if armor_heavy_to_stagger:
				hit.reaction = CombatTypes.Reaction.STAGGER
		CombatTypes.HitTier.FINISHER:
			if armor_finisher_to_stagger:
				hit.reaction = CombatTypes.Reaction.STAGGER


## An absorbed hit: the damage landed and the move runs on; the contact flash is the only sign
## here (the heavies add a spark and a clank in presentation).
func _on_armor_absorbed(_hit: HitInfo) -> void:
	pass


## A dead body leaves the game (the base never frees a KO'd body): off every group first (a
## same-frame scan must not find it), no avoidance, then freed.
func _tick_ko() -> void:
	if not is_gone() or _cleaned_up:
		return
	_cleaned_up = true
	_release_token()
	if _nav:
		_nav.avoidance_enabled = false
	for group: StringName in [&"ai_enemy", &"enemy", &"boss", &"actor"]:
		if is_in_group(group):
			remove_from_group(group)
	queue_free()


## Gives the token back to the director (and clears it here, whether or not a director took it).
func _release_token() -> void:
	if not has_token:
		return
	if is_inside_tree():
		var director := EnemyDirector.find(get_tree())
		if director:
			director.release_token(self)
	if has_token:
		revoke_token()


func _cooldown_seconds() -> float:
	var tunable := _cooldown_tunable()
	return float(Tuning.data.get(tunable)) if tunable != &"" and tunable in Tuning.data else 0.0


# --- Moving ---------------------------------------------------------------------------------


## The walking speed (m/s) of approaching, entering and backing off.
func _walk_speed() -> float:
	return Tuning.data.approach_speed_mps * _speed_mult()


func _speed_mult() -> float:
	var tunable := _speed_tunable()
	return float(Tuning.data.get(tunable)) if tunable != &"" and tunable in Tuning.data else 1.0


## Walk toward `target` at `speed`: along the nav path (straight when there is no navmesh),
## facing the player or the way it goes.
func _travel(target: Vector3, speed: float, face_player: bool, player: CombatActor) -> void:
	var dir := _path_direction(target)
	if face_player and player:
		_face(_flat(player.global_position - global_position), Tuning.data.enemy_turn_rate)
	elif dir.length_squared() > 0.0001:
		_face(dir, Tuning.data.enemy_turn_rate)
	_apply_velocity(dir * speed, false)


## The flat unit direction to the next waypoint toward `target` (zero before the first path), or
## straight at it when there is no navmesh. The agent is always aimed at `target` too: it only
## passes a velocity through its avoidance while it has somewhere to go.
func _path_direction(target: Vector3) -> Vector3:
	var ticks := maxi(Tuning.data.enemy_retarget_ticks, 1)
	if (_ticks + _retarget_offset % ticks) % ticks == 0 or _flat_dist(_nav.target_position, target) > Tuning.data.enemy_slot_reach_m:
		_nav.target_position = target
	var next := _nav.get_next_path_position()
	if not _navmesh_ready:
		return _flat(target - global_position).normalized()
	return _flat(next - global_position).normalized()


## The avoidance's answer to last tick's desired velocity becomes the velocity (latched), and
## this tick's desired one goes in. Walks the legs to match. A move that steers by itself (the
## strafe) aims the agent a second ahead, so it has somewhere to go.
func _apply_velocity(desired: Vector3, aim_agent: bool = true) -> void:
	if _nav and _nav.avoidance_enabled:
		if aim_agent and desired.length_squared() > 0.0001:
			_nav.target_position = global_position + Vector3(desired.x, 0.0, desired.z)
			_nav.get_next_path_position()
		_nav.velocity = Vector3(desired.x, 0.0, desired.z)
		var safe := Vector3(_safe_velocity.x, 0.0, _safe_velocity.z)
		if desired.length_squared() > 0.0001:
			# The answer is for last tick's wish. A net for a stale or squeezed one: never against this
			# tick's wish (only its sideways part, which slides a body out of a squeeze where a zero
			# would hold it there), and never faster than the wish asks.
			var wish := desired.normalized()
			var along := safe.dot(wish)
			if along < 0.0:
				safe -= wish * along
			safe = safe.limit_length(desired.length())
		sim_velocity.x = safe.x
		sim_velocity.z = safe.z
	else:
		sim_velocity.x = desired.x
		sim_velocity.z = desired.z
	_animate_legs()


func _stop() -> void:
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	_reset_avoidance()
	if _taunt_frames <= 0:
		rig.play_locomotion(Vector2.ZERO, 0.0)


## Tell the neighbours' avoidance what this body really does (a reaction, a wind-up or strike).
func _report_velocity() -> void:
	if _nav and _nav.avoidance_enabled:
		var actual := Vector3(sim_velocity.x, 0.0, sim_velocity.z)
		if _running_move():
			actual += Vector3(_lunge_velocity.x, 0.0, _lunge_velocity.z)
		_reset_avoidance(actual)


func _stop_reporting() -> void:
	_reset_avoidance()


## Put the avoidance agent's memory of this body at `velocity` (at rest by default): what it will
## be told the neighbours see, and what its own answers are built around. The agent keeps its own
## velocity from the last walk: setting the wish (_nav.velocity) does not touch it, so after a
## stop or a reaction it went on answering with the old course (a Punk that had just attacked
## walked back past the player's shoulder at 4-6 m/s). The latched answer goes with it. Called only
## while there is something to clear (the forced reset every tick can leave an agent stuck).
func _reset_avoidance(velocity: Vector3 = Vector3.ZERO) -> void:
	if _nav == null or not _nav.avoidance_enabled:
		return
	var stale := Vector3(_safe_velocity.x, 0.0, _safe_velocity.z).distance_squared_to(velocity) > RESET_EPSILON_SQ \
			or Vector3(_nav.velocity.x, 0.0, _nav.velocity.z).distance_squared_to(velocity) > RESET_EPSILON_SQ
	_nav.velocity = velocity
	if stale:
		_safe_velocity = velocity
		_nav.set_velocity_forced(velocity)


## The walk cycle that matches the velocity in the body's own frame: strafing reads as the
## side-step, backing off as the walk back.
func _animate_legs() -> void:
	if _taunt_frames > 0:
		return
	var velocity := Vector3(sim_velocity.x, 0.0, sim_velocity.z)
	var forward := get_forward()
	var right := forward.cross(Vector3.UP)
	rig.play_locomotion(Vector2(velocity.dot(right), velocity.dot(forward)), velocity.length() / Tuning.data.move_speed)


## Turn toward the flat direction `dir` at `rate` radians per second.
func _face(dir: Vector3, rate: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var step := rate / Engine.physics_ticks_per_second
	rotation.y = wrapf(rotation.y + clampf(diff, -step, step), -PI, PI)


## True when it has not got nearer to `target` by enemy_slot_reach_m for enemy_stuck_s: a stall.
func _stalled(target: Vector3) -> bool:
	var dist := _flat_dist(global_position, target)
	if dist < _progress_best - Tuning.data.enemy_slot_reach_m:
		_progress_best = dist
		_progress_frames = 0
		return false
	_progress_frames += 1
	if _progress_frames < _frames(Tuning.data.enemy_stuck_s):
		return false
	_progress_best = dist
	_progress_frames = 0
	return true


## A stall: tell the director (if it takes the report) and try a spot enemy_detour_deg around the
## player for a while, then the slot again. The side is random the first time and, for a stall soon
## after the last one (the detour did not free it), the other one; a side whose spot is not on the
## navmesh (inside the parked car) gives way to the other.
func _start_detour(player: CombatActor) -> void:
	var director := EnemyDirector.find(get_tree())
	if director and director.has_method(&"report_stalled"):
		director.call(&"report_stalled", self)
	var away := _flat(global_position - player.global_position)
	if away.length_squared() < 0.0001:
		return
	var tuning := Tuning.data
	var repeat := _ticks - _last_stall_tick <= _frames(tuning.enemy_detour_s + 2.0 * tuning.enemy_stuck_s)
	_last_stall_tick = _ticks
	var side := _detour_side
	if side == 0.0 or not repeat:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	else:
		side = -side
	var radius := clampf(away.length(), tuning.posture_ring_min_m, tuning.posture_ring_max_m)
	var spot := _detour_spot(player, away, radius, side)
	if not _on_navmesh(spot):
		var other := _detour_spot(player, away, radius, -side)
		if _on_navmesh(other):
			side = -side
			spot = other
	_detour_side = side
	_detour = spot
	_detour_frames = _frames(tuning.enemy_detour_s)


func _detour_spot(player: CombatActor, away: Vector3, radius: float, side: float) -> Vector3:
	var spot := player.global_position + away.normalized().rotated(Vector3.UP, deg_to_rad(Tuning.data.enemy_detour_deg) * side) * radius
	spot.y = global_position.y
	return spot


## Whether a navmesh is on the map (the training room has none), and it has synced.
func _has_navmesh() -> bool:
	if _nav == null or not is_inside_tree():
		return false
	var map := get_world_3d().navigation_map
	return NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty()


func _find_player() -> CombatActor:
	return get_tree().get_first_node_in_group(&"player") as CombatActor if is_inside_tree() else null


## Sim frames in `seconds`.
static func _frames(seconds: float) -> int:
	return maxi(roundi(seconds * Engine.physics_ticks_per_second), 0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Debug ----------------------------------------------------------------------------------


## The base text plus an "AI <STATE>  slot <bearing>" line: the slot's bearing from the player's
## look (the director's spread), "TOKEN" while it holds one and "(blind)" when blind-spot
## priority gave it. Short: six labels stack.
func debug_state_text() -> String:
	var text := "%s\nAI %s  slot %s" % [super.debug_state_text(), ai_state_name(), _slot_text()]
	if has_token:
		text += "  TOKEN"
		if blind_priority_granted:
			text += " (blind)"
	return text


func _slot_text() -> String:
	var player := _find_player()
	if not posture_slot.is_finite() or player == null or not player.has_method(&"look_bearing_deg"):
		return "-"
	return "%d" % roundi(player.call(&"look_bearing_deg", posture_slot))


# --- Grabs (P2-grab) --------------------------------------------------------------------------

## The hold of a grab attack in progress (EnemyHold); null until the first grab attack starts.
var _hold: EnemyHold


## A grab attack starts (the seam of _start_attack()): the EnemyHold that will connect it.
func _hold_arm(attack: EnemyAttack) -> void:
	if _hold == null:
		_hold = EnemyHold.new(self)
	_hold.arm(attack)


## Let a held victim go with no hit: this body was hit, killed or removed mid-hold.
func _hold_release() -> void:
	if _hold != null:
		_hold.release()


## CombatActor's holder hook: true while `victim` is held by this body's grab and the follow-up
## runs. The player's own check each tick lets go of a holder that stopped (hit, killed, gone).
func is_holding(victim: CombatActor) -> bool:
	return _hold != null and _hold.holds(victim)


## True while this body's slam holds `victim` off the floor (PlayerCharacter reads it, duck-typed,
## to hang him in the lifted pose).
func lifts_victim(victim: CombatActor) -> bool:
	return _hold != null and _hold.lifts(victim)


## The victim mashed free (CombatActor.break_free() calls this first): the hold is over, the
## attempt is spent, and this body staggers away from it at Tuning.grab_break_push_mps, the token
## given back, the cooldown started. The victim stays where it stands, invulnerable for a moment.
func _on_hold_broken(victim: CombatActor) -> void:
	if _hold != null:
		_hold.broken()
	_release_token()
	_cooldown_frames = _frames(_cooldown_seconds())
	_attack = null
	_taunt_frames = 0
	var away := _flat(global_position - victim.global_position)
	away = away.normalized() if away.length_squared() > 0.0001 else -get_forward()
	_stagger_away(away * Tuning.data.grab_break_push_mps)
	ai_state = AiState.REACT


## Cut the running move and stagger with `push` (m/s, flat): what a mashed-out holder does. The
## stagger is CombatActor's (a body that is staggering is hit-reacting: REACT, grabbable).
func _stagger_away(push: Vector3) -> void:
	if current_move:
		_cancel_move()
	sim_velocity = Vector3(push.x, 0.0, push.z)
	_enter_state(CombatTypes.ActorState.STAGGER, Tuning.data.stagger_frames)
	rig.play(_directional_anim(&"stagger", push), Tuning.data.stagger_snap_blend_s)
	_ragdoll_stagger(get_chest_position(), push, Ragdoll.Part.TORSO)


## The reach (m) the rear warning measures this attack's range from (RearWarning and the warning
## oracle ask it, duck-typed, before move.reach_m). A grab's follow-up winds up on a player
## already in this body's hands, face to face: the warning is for what comes from out of view,
## so it gets a reach nothing is within (its margin cannot make up for it).
func warning_reach_m(move: MoveData) -> float:
	if _hold != null and _hold.is_follow_up(move) and _hold.victim != null:
		return -Tuning.data.rear_warning_range_margin_m - 1.0
	return move.reach_m
