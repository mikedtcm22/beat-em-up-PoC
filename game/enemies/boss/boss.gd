class_name Boss
extends EnemyActor
## The graybox boss (Milestone 3, SPEC §7; placeholder name "Boss": its name and look wait for the
## art). 300 HP over two phases, 2.3 m tall and 0.5 m wide, group "boss" (the HUD's bottom bar
## follows it and skips its over-head bar). Armored: a light hit lands its damage and is absorbed
## (no flinch, the move runs on), a heavy hit staggers it (which also gets the player out of its
## grab wind-up: Game-boy's rule) unless it is committed to a charge or a pound, which a heavy hit
## cannot cut short either (_apply_armor()), and a finisher knocks it down (the punish window). It
## can never be grabbed. Three attacks, picked by range (_choose_attack()):
##   the shoulder charge (boss_charge): a held crouch, then a 4 m dash over the move's active frames
##     (stopping at a wall) with an arc in front of the shoulder, 20, a knockdown; blockable. Thrown
##     when the player is at least boss_charge_min_m away.
##   the ground pound (boss_pound): a rearing wind-up, then a ring round the boss at the feet, 15, a
##     knockdown; unblockable, but a jump or a dodge gets out of it. Thrown at any range, and always
##     when others crowd the player.
##   the grab slam (boss_grab, then boss_slam; P2-grab's EnemyHold): a grab that connects by code,
##     then a slam that lifts the held player and throws him, 25; the player mashes free first.
## Every move's wind-up is the heavy floor of 30 frames or more, so the rear warning's larger burst
## (heavy) and the held telegraph read at the posture ring.
##
## Phase 2: at health <= boss_phase2_at of its maximum, once, it emits
## CombatEvents.boss_phase_changed(self, 2), turns faster (its turn rate times boss_phase2_turn_mult)
## and calls in boss_adds_count Street Punks, one every wave_spawn_interval_s (the first at once),
## through the room's EncounterSpawner when there is one (the nearest free spawn points, so they
## walk in from the doorways and alleys) and otherwise on the navmesh boss_add_ring_m round it. A
## beckoning gesture marks it when it is free to make one.
##
## Poise (the final review's stun-lock fix): once it is back on its feet after a stagger or a
## knockdown, it is poised for boss_poise_s, or until its next attack is over, or while it has had
## boss_poise_after_reactions reactions inside boss_poise_window_s (is_poised()): a heavy hit and a
## finisher are absorbed like a light one (the damage lands, a grey spark, no reaction, the move goes
## on). The haymaker (breaks_armor) still knocks it down, a killing hit is never softened, and a heavy
## hit still cuts the grab (Game-boy's rule). Without it the basic chain (jab, jab, hook, uppercut)
## staggered and floored it every 3 s, it spent over half its life reacting and threw its wind-ups at
## a player already hitting it. Waking within boss_read_m of the player it steps back for up to
## boss_back_off_s before it asks for a token, so its wind-up is in view.
##
## A parry (a perfect block) does not stagger it (_parry_staggers() is false: it would be parry-locked
## by a perfect block every time); it takes a short recoil instead, boss_parry_recoil_frames, so a
## parried boss attack opens a small window. A plain block does nothing to it (its moves never
## recoil when blocked: the data rule). Everything else is EnemyActor's; this file is the boss's data.

## The body and its trim: charcoal with orange accents (cap, wrist wraps, shoes), told from the
## Punk's teal, the Kicker's lime, the Thug's olive and the Bruiser's purple at a glance, and not
## red, which SPEC §10 keeps for blood, the rear warning and the finisher's accents.
@export var color: Color = Color(0.13, 0.13, 0.15)
@export var accent: Color = Color(0.96, 0.5, 0.08)

## 1 until it enters phase 2.
var phase: int = 1
## The Street Punks it has called in so far (read by tests and the bots).
var adds: Array[EnemyActor] = []
## The phase 2 call-in: how many Punks are still due, how many were called, and the sim frames until
## the next one (_tick_adds()).
var _adds_due: int = 0
var _adds_called: int = 0
var _adds_frames: int = 0
## The beckoning gesture of phase 2 is due but it was busy (attacking, reacting, with a token): it is
## made the next time it stands posturing with no token.
var _beckon_due: bool = false
## Poise (see is_poised()): the sim frames of it left, whether a stagger or a knockdown is under way
## (the poise starts when it is over), and the control ticks at which its last reactions began.
var _poise_frames: int = 0
var _poise_owed: bool = false
var _poise_attacks_left: int = 0
var _reaction_ticks: Array[int] = []
## The sim frames of stepping back it has left in this ENGAGE (_tick_engage()).
var _back_frames: int = 0


func _init() -> void:
	archetype = &"boss"
	heavy = true
	armor_light = true
	armor_heavy_to_stagger = true
	armor_finisher_to_stagger = false


func _ready() -> void:
	add_to_group(&"boss")
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _build_attacks() -> Array[EnemyAttack]:
	return [
		EnemyAttack.of(&"shoulder charge", [&"boss_charge"], &"boss_charge_chance", true),
		EnemyAttack.of(&"ground pound", [&"boss_pound"], &"boss_pound_chance", true),
		EnemyAttack.of(&"grab and slam", [&"boss_grab", &"boss_slam"], &"boss_grab_chance", true, &"grab"),
	]


func _health_tunable() -> StringName:
	return &"boss_health"


func _speed_tunable() -> StringName:
	return &"boss_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"boss_attack_cooldown_s"


# --- What it throws ---------------------------------------------------------------------------


## By range, with the chances as weights: the charge only while the player is at least
## boss_charge_min_m away (an enemy up in its face gets the pound or the grab; there is no run-up),
## the pound and the grab at any range (it walks in for them), and with boss_crowd_count or more
## other enemies within boss_crowd_m of the player (a crowd to catch in the ring, no room for a
## grab) only the pound. With nothing weighted the base picks.
func _choose_attack() -> EnemyAttack:
	var player := _find_player()
	if player == null or _attacks.size() < 3:
		return super._choose_attack()
	var tuning := Tuning.data
	var run_up := _flat_dist(global_position, player.global_position) >= tuning.boss_charge_min_m
	var crowded := _crowded_round(player)
	var weights: Array[float] = [
		tuning.boss_charge_chance if run_up else 0.0,
		tuning.boss_pound_chance,
		tuning.boss_grab_chance,
	]
	if crowded:
		weights = [0.0, 1.0, 0.0]  # only the pound, whatever the chances say
	var total := weights[0] + weights[1] + weights[2]
	if total <= 0.0:
		return super._choose_attack()
	var roll := _rng.randf() * total
	for i in 3:
		roll -= weights[i]
		if roll < 0.0:
			return _attacks[i]
	return _attacks[2]


## Other live AI enemies within boss_crowd_m of the player, boss_crowd_count or more.
func _crowded_round(player: CombatActor) -> bool:
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var other := node as EnemyActor
		if other == null or other == self or other.health <= 0.0 or other.is_gone():
			continue
		if _flat_dist(other.global_position, player.global_position) <= Tuning.data.boss_crowd_m:
			count += 1
	return count >= Tuning.data.boss_crowd_count


## Never grabbable (the player's grab cannot take a boss: SPEC §7).
func can_be_grabbed() -> bool:
	return false


## It wakes in place: free again beside the player after a stagger, a knockdown or a parry recoil, it
## postures where it stands and the director serves it first (EnemyActor._resume_posture()), instead of
## walking 2.5-4 m back to a slot while the next chain lands. Without this a continuous chain (its
## armor absorbs the first jabs, the hook staggers it, the uppercut floors it) kept it in REACT and
## APPROACH, never in POSTURE, the only state that asks for a token: it threw one attack in 40 s.
func _wakes_in_place() -> bool:
	return true


# --- Stepping back ----------------------------------------------------------------------------


## With a token and squared up (the commit pause is over), a charge or a pound that its wind-up cannot
## be read at (the player closer than boss_read_m: at 1 m the pound's raised arms are over the top of
## the lens and the head is out of the view) is preceded by a step back, for up to boss_back_off_s.
## The bound lets a player who follows it back, as a chain does, still be attacked.
func _tick_engage(player: CombatActor) -> void:
	if has_token and _commit_frames <= 0 and _back_frames > 0 and _too_close_to_read(player):
		_back_frames -= 1
		var away := _flat(global_position - player.global_position)
		_face(-away, Tuning.data.enemy_turn_rate)
		_apply_velocity(away.normalized() * _walk_speed())
		return
	super._tick_engage(player)


func _enter_engage() -> void:
	super._enter_engage()
	_back_frames = _frames(Tuning.data.boss_back_off_s)


func _too_close_to_read(player: CombatActor) -> bool:
	var tuning := Tuning.data
	if tuning.boss_read_m <= 0.0 or _next_attack == null or _next_attack.kind == &"grab":
		return false  # the grab's own range is 1.3 m: it is thrown from where it stands
	if player.is_ko() or player.is_downed() or player.is_flying() or player.state == CombatTypes.ActorState.GRABBED:
		return false
	return _flat_dist(global_position, player.global_position) < tuning.boss_read_m


# --- Armor ------------------------------------------------------------------------------------


## The base's armor (light absorbed, heavy staggers, a finisher knocks it down), except that once the
## charge or the pound is winding up (or running) a heavy hit is absorbed too, as a light one is:
## the damage lands and the move goes on. Only the grab's wind-up is cut short by a heavy hit (Game-
## boy's rule); the charge and the pound are answered by a dodge, a jump, a block or a finisher.
## Without this an aggressive player's third punch (a heavy hook) cancelled every wind-up there
## was, and the autopilot beat the boss in 38 s without taking a hit.
func _apply_armor(hit: HitInfo) -> void:
	if not hit.killed and not (hit.move != null and hit.move.breaks_armor) and (
			(hit.tier == CombatTypes.HitTier.HEAVY and _commits_to_its_move()) or _poised_against(hit)):
		hit.armor_absorbed = true
		hit.reaction = CombatTypes.Reaction.NONE
		hit.knockback = Vector3.ZERO
		return
	super._apply_armor(hit)


## True while it is winding up or running a charge or a pound: any attack but the grab (EnemyHold's
## hold is cut by a heavy hit, and a hit that lands on it releases the player).
func _commits_to_its_move() -> bool:
	return _running_move() and current_move != null and _attack != null and _attack.kind != &"grab"


# --- Poise ------------------------------------------------------------------------------------


## Whether it is poised: a heavy hit or a finisher (never the haymaker) is absorbed as a light one is.
## True for boss_poise_s after it is back on its feet from a stagger or a knockdown, until its next
## attack is over (RECOVER), and while boss_poise_after_reactions reactions of the last
## boss_poise_window_s are on its books. Read by the bots and the tests; never writes game state.
func is_poised() -> bool:
	return health > 0.0 and (_poise_frames > 0 or _reaction_capped())


## Sim seconds of the after-getting-up poise left (0 when it has none; the cap is not counted).
func poise_left_s() -> float:
	return float(_poise_frames) / float(Engine.physics_ticks_per_second)


## A heavy hit or a finisher it is poised against. The grab (any phase of it, the hold included) is
## the one thing poise never absorbs: a heavy hit cuts it and lets the player go (Game-boy's rule).
func _poised_against(hit: HitInfo) -> bool:
	if hit.tier == CombatTypes.HitTier.LIGHT or not is_poised():
		return false
	return not (_running_move() and current_move != null and _attack != null and _attack.kind == &"grab")


## boss_poise_after_reactions or more reactions (a hit that staggered or floored it) inside the last
## boss_poise_window_s: a rate cap, so a chain that keeps landing cannot floor it again and again.
func _reaction_capped() -> bool:
	var cap := Tuning.data.boss_poise_after_reactions
	if cap <= 0:
		return false
	var window := _frames(Tuning.data.boss_poise_window_s)
	var recent := 0
	for tick: int in _reaction_ticks:
		if _ticks - tick <= window:
			recent += 1
	return recent >= cap


## Counts the reactions for the cap (a hit that was not absorbed and staggered or floored it).
func _on_hit_received(hit: HitInfo) -> void:
	if not hit.killed and hit.reaction in [CombatTypes.Reaction.STAGGER, CombatTypes.Reaction.KNOCKDOWN,
			CombatTypes.Reaction.LAUNCH, CombatTypes.Reaction.THROWN]:
		_reaction_ticks.append(_ticks)
		var window := _frames(Tuning.data.boss_poise_window_s)
		while not _reaction_ticks.is_empty() and _ticks - _reaction_ticks[0] > window:
			_reaction_ticks.remove_at(0)
	super._on_hit_received(hit)


## The wake-up hold (the base's: POSTURE where it stands, ignoring the slot it left, served first)
## lasts as long as the poise does: a boss that stands its ground while nothing can floor it does not
## walk back to its slot with the player at its nose, where it could ask for no token.
func _resume_posture() -> void:
	super._resume_posture()
	_resume_frames = maxi(_resume_frames, _poise_frames)


## An attack of its own is over: with boss_poise_attacks of them to a poise, the last one ends it.
func _enter_recover() -> void:
	super._enter_recover()
	if _poise_frames > 0 and _poise_attacks_left > 0:
		_poise_attacks_left -= 1
		if _poise_attacks_left == 0:
			_poise_frames = 0


## The poise's clock, before the AI's tick: it starts the first tick it is on its feet after a stagger
## or a knockdown (not a parry's recoil), runs down, and ends with its next attack (RECOVER).
func _tick_poise() -> void:
	if _poise_frames > 0:
		_poise_frames -= 1
	match state:
		CombatTypes.ActorState.STAGGER, CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.THROWN, \
		CombatTypes.ActorState.DOWNED, CombatTypes.ActorState.GETUP:
			_poise_owed = true
		CombatTypes.ActorState.FREE:
			if _poise_owed:
				_poise_owed = false
				_poise_frames = _frames(Tuning.data.boss_poise_s)
				_poise_attacks_left = Tuning.data.boss_poise_attacks


# --- Turning ----------------------------------------------------------------------------------


## It turns at boss_turn_rate where the base's posture turn is enemy_turn_rate: every turn the base
## makes (posture, engage, the wind-up's tracking) is scaled by the ratio, and by
## boss_phase2_turn_mult from phase 2, so the boss is slow to follow a sidestep and faster after
## the change.
func _face(dir: Vector3, rate: float) -> void:
	super._face(dir, rate * _turn_scale())


func _turn_scale() -> float:
	var scale := Tuning.data.boss_turn_rate / maxf(Tuning.data.enemy_turn_rate, 0.001)
	if phase >= 2:
		scale *= Tuning.data.boss_phase2_turn_mult
	return scale


# --- Parry ------------------------------------------------------------------------------------


## A boss is not staggered by a perfect block (it would be parry-locked); react_to_block() gives it
## a recoil instead.
func _parry_staggers() -> bool:
	return false


## The attacker's side of a blocked hit. An ordinary block does nothing to the boss (its moves have
## no blocked recoil); a perfect one knocks it into a recoil of boss_parry_recoil_frames, a small
## window to hit it in (light hits are absorbed, a heavy one staggers). The recoil is the base's
## (HITSTUN with the recoil pose), only longer than a move's data allows for the boss.
func react_to_block(hit: HitInfo) -> void:
	var frames := Tuning.data.boss_parry_recoil_frames
	if not hit.perfect_block or hit.guard_broken or is_ko() or frames <= 0:
		super.react_to_block(hit)
		return
	if current_move:
		_cancel_move()
	sim_velocity = Vector3(0.0, sim_velocity.y, 0.0)
	_enter_state(CombatTypes.ActorState.HITSTUN, frames)
	_recoiling = true
	var length := rig.anim_player.get_animation(&"recoil").length
	rig.play(&"recoil", 0.0, length * Engine.physics_ticks_per_second / frames)
	rig.advance(0.0)
	_on_move_interrupted()


# --- Phase 2 ----------------------------------------------------------------------------------


## Polled every sim tick, so every way health can fall (a hit, an absorbed hit, a block's chip, a
## cheat) is seen: at health <= boss_phase2_at of its maximum, once, while it is alive. The Punks it
## calls in come one at a time (_tick_adds()).
func _tick_control() -> void:
	_tick_poise()
	super._tick_control()
	if phase == 1 and health > 0.0 and health <= max_health * Tuning.data.boss_phase2_at:
		_enter_phase2()
	_tick_beckon()
	_tick_adds()


func _enter_phase2() -> void:
	phase = 2
	CombatEvents.boss_phase_changed.emit(self, 2)
	# The beckoning gesture, when it is free and standing on the ring: "come on". Busy (it attacks a good
	# deal more often than it stands there), it makes it at its next free moment (_tick_beckon()).
	_beckon_due = true
	_tick_beckon()
	_adds_due = maxi(Tuning.data.boss_adds_count, 0)
	_adds_called = _adds_due
	_adds_frames = 0


## The phase 2 beckon, once, the first tick it is free and posturing with no token and no gesture under way.
func _tick_beckon() -> void:
	if _beckon_due and health > 0.0 and state == CombatTypes.ActorState.FREE and ai_state == AiState.POSTURE \
			and not has_token and _taunt_frames <= 0:
		_beckon_due = false
		_start_taunt()


## The Punks it called in arrive one every wave_spawn_interval_s, the first at once: a rig takes
## about 10 ms to build, and two in one frame was a 40 ms hitch where the spawn limit is 33.
func _tick_adds() -> void:
	# Punks that were freed (a KO that blinked off, F4's remove-all) drop out of the list.
	for i in range(adds.size() - 1, -1, -1):
		if not is_instance_valid(adds[i]):
			adds.remove_at(i)
	if _adds_due <= 0:
		return
	if health <= 0.0 or is_gone():
		_adds_due = 0
		return
	if GameInput.menu_open:
		return  # the fight holds while F1 or F4 is open (A2.2): the call-in waits with the waves
	if _adds_frames > 0:
		_adds_frames -= 1
		return
	var made := _spawn_one_add(_adds_called - _adds_due)
	if made != null:
		adds.append(made)
	_adds_due -= 1
	_adds_frames = _frames(Tuning.data.wave_spawn_interval_s)


## One Street Punk: the spawner's free spawn point nearest the boss (so it walks in from a doorway
## or an alley and joins the running wave), or, with no spawner or no free point, on the navmesh
## boss_add_ring_m round the boss. `index` is which of the call-in it is (it picks the direction on
## the ring). Null when there is nowhere to put it.
func _spawn_one_add(index: int) -> EnemyActor:
	var spawner := get_tree().get_first_node_in_group(&"encounter_spawner") as EncounterSpawner
	if spawner != null:
		var made := spawner.spawn_adds(&"punk", 1, global_position)
		if not made.is_empty():
			return made[0]
	return _spawn_add_on_ring(index)


## A Punk on the ring round the boss, at the nearest navmesh point (the flat spot itself with no
## navmesh) that has room: `index` of `_adds_called` directions spread evenly round it, the first
## toward the player, and the next free one round from there when a wall or a crate is in the way.
func _spawn_add_on_ring(index: int) -> EnemyActor:
	var scene := EnemyCatalog.scene(&"punk")
	var parent := get_parent() as Node3D
	if scene == null or parent == null:
		return null
	var player := _find_player()
	var start := _flat(player.global_position - global_position) if player else -get_forward()
	if start.length_squared() < 0.0001:
		start = -get_forward()
	var space := get_world_3d().direct_space_state
	var body := EnemyCatalog.body_size(&"punk")
	var turns := maxi(_adds_called, 1)
	# A few more directions than the call-in has punks, so a blocked one is skipped.
	var steps := maxi(turns * 3, 6)
	var first := float(index) * float(steps) / float(turns)
	for i in steps:
		var dir := start.normalized().rotated(Vector3.UP, TAU * (first + float(i)) / float(steps))
		var spot := _nav_snap(global_position + dir * Tuning.data.boss_add_ring_m)
		if not SpawnRoomCheck.has_room(space, body.x, body.y, spot):
			continue
		var serials := {"Punk": _highest_serial("Punk")}
		var punk := EncounterSpawner.make_enemy(scene, &"punk", serials)
		if punk == null:
			return null
		punk.position = parent.to_local(spot)
		var to_boss := global_position - spot
		punk.rotation.y = atan2(-to_boss.x, -to_boss.z) - parent.global_rotation.y
		parent.add_child(punk)
		punk.enter_from(spot, spot)
		return punk
	return null


## The nearest point on the navmesh to `spot` when there is one (and it has synced), else `spot` itself
## on the boss's floor.
func _nav_snap(spot: Vector3) -> Vector3:
	var flat := Vector3(spot.x, global_position.y, spot.z)
	if not _has_navmesh():
		return flat
	var snapped := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, flat)
	return Vector3(snapped.x, global_position.y, snapped.z)


## The highest number after `label` among the live AI enemies' names ("Punk12" is 12), so the adds
## get fresh names.
func _highest_serial(label: String) -> int:
	var highest := 0
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var text := String(node.name)
		if text.begins_with(label) and text.substr(label.length()).is_valid_int():
			highest = maxi(highest, text.substr(label.length()).to_int())
	return highest
