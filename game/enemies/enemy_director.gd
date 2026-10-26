class_name EnemyDirector
extends Node
## The enemy director (Milestone 3, SPEC §7): hands out attack tokens (at most
## Tuning.data.attacker_cap attack at once, 0 = unlimited; enemies in the player's blind spot
## first), paces the wind-ups (no two start together) and spreads the waiting enemies all the
## way around the player on the posture ring, so a crowd attacks in turns the player can read.
## It is not an actor: it runs its own _physics_process on `delta * TimeController.sim_scale()`
## (so it keeps running through hitstop, and slows with slow-mo) with a seeded RNG. Lives in
## group "enemy_director". It reads the player and the enemies and writes only through the
## enemies' director hooks (grant_token(), revoke_token(), set_slot()); it never reads a camera.
##
## What it does each tick (the contract: docs/ARCHITECTURE.md "Director"):
## - discovers the members of group "ai_enemy" that are alive; a freed, dead, gone, token-less
##   or reacting holder loses its token (every exit path of an attack ends here at the latest);
## - tracks who wants a token (EnemyActor.wants_token()) and since when;
## - grants tokens while fewer than the cap are attacking (a holder, or an enemy already in
##   WINDUP, ATTACK or GRABBING, counts), but only while the player can be hit: not missing,
##   dead, downed, flying, held, in a revive grace or invulnerable. The roll that lets a
##   blind-spot waiter jump the queue is `blind_spot_priority`; otherwise the longest waiting goes
##   first. A token whose wind-up has not started is taken back when the player closes (hard:
##   dead, downed, flying, held, revive grace), while F1 or F4 is open (GameInput.menu_open) or
##   while the AI is frozen, and after director_token_timeout_s;
## - answers may_start_windup() with the pacing rule (director_min_windup_gap_s between two
##   wind-up starts, readability metric R2), and windup_eta_s() with how soon it would say yes, so
##   a holder waits squared up on the ring and steps in only when its go is near;
## - gives every live enemy a posture slot: the enemies that are not Kickers evenly spaced around the
##   player, the arrangement turned as little as possible from where they stand (a newcomer
##   weighs little against one already seated), each on its own radius of the ring, snapped onto
##   the navmesh when there is one; each Kicker has a seat of its own as near directly behind the
##   look as it can be, and the others never move for it.
##
## A subclass that defines its own script (the test fixture tests/fixtures/stub_director.gd)
## decides nothing on its own: the loop only runs for this script itself.

## Seeds the director's random rolls (the blind-spot priority roll). Setting it reseeds.
@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		_rng.seed = value

## Slack on float time comparisons (s): a gap of N whole ticks must not need an N+1st because
## 21 additions of 1/60 came out a hair under 0.35.
const _CLOCK_SLACK_S := 0.001
## Slack on an angular cost comparison (degrees): the first of equal arrangements wins.
const _COST_SLACK_DEG := 0.000001
## Resolution of the per-enemy name hash that picks its jitter and radius.
const _HASH_BUCKETS := 4096
## The step (degrees) of the search for a Kicker's seat outward from directly behind the look.
const _FLANK_SEARCH_DEG := 5.0

var _rng := RandomNumberGenerator.new()
## The player as of this tick (for _committed()).
var _player: PlayerCharacter
## Only this script's own instances run the loop (see the class docs).
var _runs: bool = false
## Sim seconds since the director entered the tree (slowed by slow-mo, not by hitstop).
var _clock_s: float = 0.0
## Enemies holding a token, in grant order. Untyped: a holder may be freed between ticks.
var _holders: Array = []
## Holder -> clock when its token was granted.
var _granted_s: Dictionary = {}
## Waiting enemy -> clock when it first wanted a token (this wait).
var _wait_since: Dictionary = {}
## The waiting enemies, longest first (rebuilt each tick, minus the ones just granted).
var _waiting: Array = []
## Enemy -> its posture slot (world position). A token holder keeps its slot.
var _slots: Dictionary = {}
## Enemy -> the angle (degrees around the player) of the evenly spaced arrangement its slot came
## from last time: the seat it holds, wherever it stands right now.
var _claims: Dictionary = {}
## Enemy -> how many times it reported stalling since its last token: each nudges its angle.
var _stalls: Dictionary = {}
## Clock of the last wind-up start (any enemy); -INF before the first.
var _last_windup_s: float = -INF
## Clock of the last hit that landed on the player (a blocked one does not count); -INF before.
var _last_player_hit_s: float = -INF
## No grants until this clock (the player's revive grace).
var _revive_until_s: float = -INF
## Reassign the slots when the clock passes this, ...
var _reslot_at_s: float = 0.0
## ... or when something asked for it, ...
var _reslot_pending: bool = true
## ... or the player moved from here, ...
var _slot_origin: Vector3 = Vector3.INF
## ... or the set of enemies that hold slots changed (their instance ids, sorted).
var _slot_ids: PackedInt64Array = PackedInt64Array()


func _enter_tree() -> void:
	_runs = get_script() == EnemyDirector
	if not _runs:
		return
	if not CombatEvents.windup_started.is_connected(_on_windup_started):
		CombatEvents.windup_started.connect(_on_windup_started)
	if not CombatEvents.revived.is_connected(_on_revived):
		CombatEvents.revived.connect(_on_revived)
	if not CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.connect(_on_hit_landed)


func _ready() -> void:
	add_to_group(&"enemy_director")
	set_physics_process(_runs)


func _exit_tree() -> void:
	if not _runs:
		return
	if CombatEvents.windup_started.is_connected(_on_windup_started):
		CombatEvents.windup_started.disconnect(_on_windup_started)
	if CombatEvents.revived.is_connected(_on_revived):
		CombatEvents.revived.disconnect(_on_revived)
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)
	# An enemy must not keep a token nobody will ever take back (the room is leaving).
	for holder: Variant in _holders:
		if is_instance_valid(holder) and (holder as EnemyActor).has_token:
			(holder as EnemyActor).revoke_token()
	_holders.clear()


func _physics_process(delta: float) -> void:
	_step(delta * TimeController.sim_scale())


## The director in `tree`, or null.
static func find(tree: SceneTree) -> EnemyDirector:
	return tree.get_first_node_in_group(&"enemy_director") as EnemyDirector


## The director in `host`'s tree, or a new one added under `host` (an enemy spawned by F4 in the
## training room has none). `host` must be in the tree. Idempotent.
static func ensure(host: Node) -> EnemyDirector:
	var found := find(host.get_tree())
	if found:
		return found
	var director := EnemyDirector.new()
	director.name = "EnemyDirector"
	host.add_child(director)
	return director


## The enemy's attack ended, was interrupted or timed out: its token goes back. A call for an
## enemy that holds none only clears what the director kept about it.
func release_token(enemy: EnemyActor) -> void:
	_drop(enemy)


## The posture slot (world position) assigned to `enemy`; Vector3.INF = none. A token holder
## keeps its slot (where it backs off to when its attack ends).
func slot_for(enemy: EnemyActor) -> Vector3:
	return _slots.get(enemy, Vector3.INF)


## An enemy holding a token calls this right before it winds up: true means "go now" and the
## director records that wind-up start. False: wait and ask again. It holds the enemy back until
## Tuning.data.director_min_windup_gap_s has passed since any enemy's wind-up began, so no two
## wind-ups start together (readability metric R2), and while the fight is held (F1 or F4 open,
## AI frozen) or the player cannot be hit; an enemy the director gave no token never gets a go.
func may_start_windup(enemy: EnemyActor) -> bool:
	if not _holders.has(enemy):
		return false
	if GameInput.menu_open or Tuning.data.ai_frozen or _player_closed(_find_player()):
		return false
	if _clock_s - _last_windup_s < Tuning.data.director_min_windup_gap_s - _CLOCK_SLACK_S:
		return false
	if _player_recovering():
		return false
	_last_windup_s = _clock_s
	return true


## True while the player is still reeling from a hit: in hitstun or a stagger, or within
## director_hit_grace_s of the last hit that landed on him. No new wind-up starts then (a flinch-lock
## guard: the starts are spaced by director_min_windup_gap_s, about a flinch long).
func _player_recovering() -> bool:
	var player := _player if _player and is_instance_valid(_player) else _find_player()
	if player and (player.state == CombatTypes.ActorState.HITSTUN or player.state == CombatTypes.ActorState.STAGGER):
		return true
	return _clock_s - _last_player_hit_s < Tuning.data.director_hit_grace_s - _CLOCK_SLACK_S


## How long (sim seconds) until may_start_windup(`enemy`) would say yes if nothing else happened:
## 0 = now, INF = not while the fight is held or the player cannot be hit, or `enemy` holds no
## token. Read-only: it records no wind-up and changes nothing, so asking every tick is free. A
## holder uses it to wait squared up on the ring and step in only when its go is about to come
## (EnemyActor._tick_engage()) instead of standing at the player's nose through the pacing gap, a
## flinch and the hit grace; may_start_windup() stays the one gate at the wind-up itself (R2).
## It counts what that gate counts, the gap since the last wind-up start, the player's hitstun or
## stagger and the hit grace, and the player's invulnerability (a dodge or a get-up), which an
## enemy also waits out. A director that decides nothing (a test double with its own script) has
## no estimate: 0.
func windup_eta_s(enemy: EnemyActor) -> float:
	if not _runs:
		return 0.0
	var player := _player if _player and is_instance_valid(_player) else _find_player()
	if not _holders.has(enemy) or GameInput.menu_open or Tuning.data.ai_frozen or _player_closed(player):
		return INF
	var tuning := Tuning.data
	var ticks_per_s := float(Engine.physics_ticks_per_second)
	var wait := tuning.director_min_windup_gap_s - _CLOCK_SLACK_S - (_clock_s - _last_windup_s)
	wait = maxf(wait, tuning.director_hit_grace_s - _CLOCK_SLACK_S - (_clock_s - _last_player_hit_s))
	if player.state == CombatTypes.ActorState.HITSTUN or player.state == CombatTypes.ActorState.STAGGER:
		wait = maxf(wait, float(player._state_length - player.state_frame) / ticks_per_s)
	wait = maxf(wait, float(player._invuln_frames) / ticks_per_s)
	# A strike already on its way (another enemy's wind-up or attack) will start the grace when it
	# lands: the go is not before it and the grace after it.
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var other := node as EnemyActor
		if other == null or other == enemy or other.health <= 0.0 or other.is_queued_for_deletion():
			continue
		var strike_s := other.last_strike_eta_s()
		if strike_s > 0.0:
			wait = maxf(wait, strike_s + tuning.director_hit_grace_s)
	# One holder at a time walks in: the head of the line, the first holder that has not started
	# its attack. The others wait on the ring, and their turn comes with its wind-up (the strike
	# above). Ordered by arrival, not by whose tick is first: a holder that waited longest must not
	# lose the race to one granted later.
	if _line_head() != enemy:
		return INF
	return maxf(wait, 0.0)


## An enemy that made no progress toward its slot for Tuning.data.enemy_stuck_s (a pocket
## behind a crate, a car) asks for another one: its angle is nudged by
## Tuning.data.director_slot_retry_deg (alternating sides, growing) and the slots are
## reassigned on the next tick.
func report_stalled(enemy: EnemyActor) -> void:
	_stalls[enemy] = int(_stalls.get(enemy, 0)) + 1
	_reslot_pending = true


# --- Read API for the F3 overlay and tests (presentation reads, never writes) ---


## The enemies holding a token now, in the order they were granted.
func debug_token_holders() -> Array[EnemyActor]:
	return _live(_holders)


## `enemy`'s posture slot, Vector3.INF when it has none.
func debug_slot_of(enemy: EnemyActor) -> Vector3:
	return slot_for(enemy)


## The posture ring's nearest and furthest distance from the player (m).
func debug_ring() -> Vector2:
	return Vector2(Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m)


## Most simultaneous attackers (0 = unlimited).
func attacker_cap() -> int:
	return Tuning.data.attacker_cap


## The enemies that want a token and have none, longest waiting first.
func debug_waiting() -> Array[EnemyActor]:
	return _live(_waiting)


# --- The loop ---


func _step(dt: float) -> void:
	_clock_s += dt
	_scrub()
	var members := _members()
	var player := _find_player()
	_player = player
	_prune_holders()
	_track_waiting(members)
	_stretch_waits(dt)
	var held := GameInput.menu_open or Tuning.data.ai_frozen
	var closed := _player_closed(player)
	_take_back(not (held or closed))
	# Slots first: an enemy granted a token this tick already has the slot it backs off to.
	if player:
		_update_slots(player, members)
	if not held and not closed and not player.is_invulnerable():
		_grant(player, members)


## Forget what the director kept about freed enemies.
func _scrub() -> void:
	var i := _holders.size() - 1
	while i >= 0:
		if not is_instance_valid(_holders[i]):
			_holders.remove_at(i)
		i -= 1
	for book: Dictionary in [_granted_s, _wait_since, _slots, _claims, _stalls]:
		for key: Variant in book.keys():
			if not is_instance_valid(key):
				book.erase(key)


## The live AI enemies: in group "ai_enemy" with health left and not blinked off.
func _members() -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as EnemyActor
		if enemy and not enemy.is_queued_for_deletion() and enemy.health > 0.0 and not enemy.is_gone():
			out.append(enemy)
	return out


func _find_player() -> PlayerCharacter:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player and player.is_queued_for_deletion():
		return null
	return player


## True while a hit on the player would not count: missing, dead, downed, in the air, held by
## someone, or in the grace after a revive. (Invulnerability alone, a dodge or a get-up, only
## withholds new tokens; it does not take back the ones in hand.)
func _player_closed(player: PlayerCharacter) -> bool:
	if player == null:
		return true
	return player.health <= 0.0 or player.is_ko() or player.is_downed() or player.is_flying() \
			or player.state == CombatTypes.ActorState.GRABBED or _clock_s < _revive_until_s


## True once the enemy's attack is running: its wind-up, strike or hold, any move at all (a jump
## kick may be flying under AIRBORNE), or the player in its grip. A token is not taken back from
## it (the token is what keeps the count of attackers honest).
func _committed(enemy: EnemyActor) -> bool:
	match enemy.state:
		CombatTypes.ActorState.WINDUP, CombatTypes.ActorState.ATTACK, CombatTypes.ActorState.GRABBING:
			return true
	return enemy.current_move != null or (_player != null and _player.holder == enemy)


## Holders that are dead, gone, freed, no longer holding or reacting to something lose the token.
func _prune_holders() -> void:
	for holder: Variant in _holders.duplicate():
		var enemy := holder as EnemyActor
		var reacting := enemy != null and enemy.state != CombatTypes.ActorState.FREE and not _committed(enemy)
		if enemy == null or enemy.is_queued_for_deletion() or enemy.health <= 0.0 or enemy.is_gone() \
				or not enemy.has_token or reacting:
			_drop(holder)


## The holder whose turn it is to come near: the first in the line of holders that have not
## started their attack, in the order the tokens were granted (blind-spot priority acts at the
## grant, so a blind waiter that is granted with others is ahead of them). Null when there is none.
func _line_head() -> EnemyActor:
	for holder: Variant in _holders:
		var enemy := holder as EnemyActor
		if enemy != null and not _committed(enemy):
			return enemy
	return null


## A holder whose go the director itself is holding back (the wind-up gap, a flinch, the hit
## grace, another holder's turn: windup_eta_s() above zero) is waiting for a reason, not hanging
## on to its token, so that time does not run down director_token_timeout_s. Without this a holder
## standing squared up on the ring through a long volley would lose its token and re-queue for
## nothing. (A fight that is held or a player who cannot be hit answers INF and takes the tokens
## back anyway, in _take_back().)
func _stretch_waits(dt: float) -> void:
	for holder: Variant in _holders:
		var enemy := holder as EnemyActor
		if enemy == null or _committed(enemy) or not _granted_s.has(holder):
			continue
		if windup_eta_s(enemy) > 0.0:
			_granted_s[holder] = float(_granted_s[holder]) + dt


## Take tokens back. With `timed_out_only`, only from holders whose wind-up has not started and
## that held on for director_token_timeout_s; otherwise from every holder whose wind-up has not
## started (the player closed, a menu opened).
func _take_back(timed_out_only: bool) -> void:
	for holder: Variant in _holders.duplicate():
		var enemy := holder as EnemyActor
		if enemy == null or _committed(enemy):
			continue
		if timed_out_only:
			var held_s := _clock_s - float(_granted_s.get(holder, _clock_s))
			if held_s <= Tuning.data.director_token_timeout_s:
				continue
		_drop(holder)


## Drop `enemy` from the holders (and its token, if it still has one).
func _drop(enemy: Variant) -> void:
	_holders.erase(enemy)
	_granted_s.erase(enemy)
	if is_instance_valid(enemy) and (enemy as EnemyActor).has_token:
		(enemy as EnemyActor).revoke_token()


## Who wants a token and since when; fills _waiting, longest first (ties in tree order).
func _track_waiting(members: Array[EnemyActor]) -> void:
	var rows: Array = []
	var seen: Dictionary = {}
	for i in members.size():
		var enemy := members[i]
		if _holders.has(enemy) or not enemy.wants_token():
			continue
		seen[enemy] = true
		if not _wait_since.has(enemy):
			_wait_since[enemy] = _clock_s
		rows.append([float(_wait_since[enemy]), i, enemy])
	for key: Variant in _wait_since.keys():
		if not seen.has(key):
			_wait_since.erase(key)
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	_waiting.clear()
	for row: Array in rows:
		_waiting.append(row[2])


## Hand out tokens while fewer than the cap are attacking.
func _grant(player: PlayerCharacter, members: Array[EnemyActor]) -> void:
	var cap := Tuning.data.attacker_cap
	var active := _holders.size()
	for enemy in members:
		if not _holders.has(enemy) and _committed(enemy):
			active += 1
	var angle := Tuning.data.rear_warning_angle_deg
	while not _waiting.is_empty() and (cap == 0 or active < cap):
		var pick: EnemyActor = _waiting[0]
		var blind := false
		var blind_ones: Array = []
		var waking: EnemyActor = null
		for waiter: EnemyActor in _waiting:
			if waking == null and waiter.has_token_priority():
				waking = waiter
			if player.is_outside_view(waiter.global_position, angle):
				blind_ones.append(waiter)
		if waking != null:
			# An enemy that just got up beside the player (the boss) is served before the queue and
			# before the blind-spot roll, which is not drawn for it.
			pick = waking
		elif not blind_ones.is_empty() and _rng.randf() < Tuning.data.blind_spot_priority:
			pick = blind_ones[0]
			blind = true
		_waiting.erase(pick)
		_wait_since.erase(pick)
		_stalls.erase(pick)
		_holders.append(pick)
		_granted_s[pick] = _clock_s
		pick.grant_token(blind)
		active += 1


# --- Posture slots (spread) ---


## Reassign the slots when due: on the timer, when the player moved, when the set of enemies
## changed (a spawn, a death) or when something asked. Every live enemy has a seat, token holders
## included, so an attack neither moves the others nor loses its enemy its place.
func _update_slots(player: PlayerCharacter, members: Array[EnemyActor]) -> void:
	for book: Dictionary in [_slots, _claims]:
		for key: Variant in book.keys():
			if not members.has(key):
				book.erase(key)
	var ids := PackedInt64Array()
	for enemy in members:
		ids.append(enemy.get_instance_id())
	ids.sort()
	var origin := player.global_position
	var moved := _slot_origin == Vector3.INF \
			or Vector2(origin.x - _slot_origin.x, origin.z - _slot_origin.z).length() > Tuning.data.director_reslot_move_m
	if not (_reslot_pending or moved or _clock_s >= _reslot_at_s or ids != _slot_ids):
		return
	_slot_ids = ids
	_slot_origin = origin
	_reslot_at_s = _clock_s + Tuning.data.director_reslot_s
	_reslot_pending = false
	_assign_slots(player, members)


## Spread `set` around the player. The enemies that are not Kickers share the 360 degrees evenly, the
## arrangement turned the least it can be from where they sit (an enemy that has a seat from last
## time sits there, wherever it stands now: a crowd that walks past each other, or an attacker at
## the player's nose, does not reshuffle the ring; a new one sits where it stands but weighs only
## director_newcomer_weight against a seated one, so a call-in never turns the ring or hands an
## enemy already on it the seat across the player). A Kicker is no part of that arrangement: it
## takes a seat of its own as near directly behind the look as it can be (_flank_angles()), so the
## look turning moves the Kickers and nobody else.
func _assign_slots(player: PlayerCharacter, set: Array[EnemyActor]) -> void:
	var n := set.size()
	if n == 0:
		return
	var origin := player.global_position
	var angles := PackedFloat64Array()
	var offsets := PackedFloat64Array()
	var radii := PackedFloat64Array()
	var jitter := Tuning.data.director_spread_jitter_deg
	var ring_min := Tuning.data.posture_ring_min_m
	var ring_max := maxf(Tuning.data.posture_ring_max_m, ring_min)
	var ring: Array[int] = []
	var flank: Array[int] = []
	for i in n:
		var enemy := set[i]
		var name_text := String(enemy.name)
		var offset := jitter * (_unit_hash(name_text + "/jitter") * 2.0 - 1.0) + _stall_nudge(enemy)
		offsets.append(offset)
		radii.append(lerpf(ring_min, ring_max, _unit_hash(name_text + "/radius")))
		if _claims.has(enemy):
			angles.append(float(_claims[enemy]) + offset)
		else:
			angles.append(ViewGeometry.bearing_deg(0.0, origin, enemy.global_position))
		(flank if enemy.prefers_blind_side else ring).append(i)
	var seat := PackedFloat64Array()  # the seat (degrees, before the enemy's own offset) of each enemy
	seat.resize(n)
	var taken := PackedFloat64Array()  # where the seats taken so far are, offsets included
	if not ring.is_empty():
		var ring_angles := PackedFloat64Array()
		var ring_offsets := PackedFloat64Array()
		var ring_weight := PackedFloat64Array()
		var seated := PackedByteArray()
		for i in ring:
			ring_angles.append(angles[i])
			ring_offsets.append(offsets[i])
			var has_seat := _claims.has(set[i])
			seated.append(1 if has_seat else 0)
			ring_weight.append(1.0 if has_seat else Tuning.data.director_newcomer_weight)
		var step := 360.0 / float(ring.size())
		var base := _best_base(ring_angles, ring_offsets, step, ring_weight)
		var slot_angles := PackedFloat64Array()
		for k in ring.size():
			slot_angles.append(base + float(k) * step)
		var slot_of := _match_slots(ring_angles, slot_angles, seated)
		for r in ring.size():
			seat[ring[r]] = slot_angles[slot_of[r]]
			taken.append(slot_angles[slot_of[r]] + ring_offsets[r])
	if not flank.is_empty():
		var behind := rad_to_deg(player.look_yaw) + 180.0
		var order := _flank_order(set, flank, behind, origin)
		for i in order:
			var side := signf(wrapf(float(_claims[set[i]]) - behind, -180.0, 180.0)) if _claims.has(set[i]) else 1.0
			if side == 0.0:
				side = 1.0
			var found := _flank_angle(behind, offsets[i], taken, side)
			seat[i] = found
			taken.append(found + offsets[i])
	for i in n:
		var slot := _snap_slot(player, seat[i] + offsets[i], radii[i])
		_claims[set[i]] = seat[i]
		_slots[set[i]] = slot
		set[i].set_slot(slot)


## The Kickers of `set` (indices `flank`), the one nearest directly behind first.
func _flank_order(set: Array[EnemyActor], flank: Array[int], behind: float, origin: Vector3) -> Array[int]:
	var order := flank.duplicate()
	var distance := func(i: int) -> float:
		var angle := float(_claims[set[i]]) if _claims.has(set[i]) else ViewGeometry.bearing_deg(0.0, origin, set[i].global_position)
		return absf(wrapf(angle - behind, -180.0, 180.0))
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: float = distance.call(a)
		var db: float = distance.call(b)
		return da < db or (da == db and a < b))
	var out: Array[int] = []
	for i: int in order:
		out.append(i)
	return out


## A seat (degrees) for a Kicker whose own offset is `offset`: as near `behind` as it can be and, offset
## included, at least director_flank_gap_deg from every angle in `taken` (the other seats). The
## search goes outward from `behind` in _FLANK_SEARCH_DEG steps, on `side` (+1 or -1: the side it sat
## on last time) first. With no room at all it sits directly behind.
func _flank_angle(behind: float, offset: float, taken: PackedFloat64Array, side: float) -> float:
	var gap := Tuning.data.director_flank_gap_deg
	var steps := int(180.0 / _FLANK_SEARCH_DEG)
	for k in steps + 1:
		for way: float in [side, -side]:
			if k == 0 and way < 0.0:
				continue
			var candidate := behind + way * float(k) * _FLANK_SEARCH_DEG
			var clear := true
			for other in taken:
				if absf(wrapf(candidate + offset - other, -180.0, 180.0)) < gap:
					clear = false
					break
			if clear:
				return candidate
	return behind


## The rotation (degrees) of the evenly spaced slots that moves the enemies least: the weighted L1
## optimum over the cyclic assignments (enemies in angular order, slot k = base + k * step plus
## the enemy's own offset, an enemy's distance counting `weights` times). Some enemy sits exactly
## on its slot at the optimum, so it is enough to try each enemy as that anchor under each cyclic
## shift.
func _best_base(angles: PackedFloat64Array, offsets: PackedFloat64Array, step: float, weights: PackedFloat64Array) -> float:
	var n := angles.size()
	var order: Array = range(n)
	order.sort_custom(func(a: int, b: int) -> bool:
		return angles[a] < angles[b] or (angles[a] == angles[b] and a < b))
	var best_cost := INF
	var best_base := 0.0
	for shift in n:
		for anchor in n:
			var anchored: int = order[anchor]
			var base := angles[anchored] - offsets[anchored] - float((anchor + shift) % n) * step
			var cost := 0.0
			for pos in n:
				var idx: int = order[pos]
				var slot := base + offsets[idx] + float((pos + shift) % n) * step
				cost += weights[idx] * absf(wrapf(angles[idx] - slot, -180.0, 180.0))
			if cost < best_cost - _COST_SLACK_DEG:
				best_cost = cost
				best_base = base
	return best_base


## Which slot each enemy takes (an index into `slot_angles`): the seated ones first, by the smallest
## angular change, greedy, then the newcomers take what is left the same way.
func _match_slots(angles: PackedFloat64Array, slot_angles: PackedFloat64Array, seated: PackedByteArray) -> PackedInt32Array:
	var n := angles.size()
	var slot_of := PackedInt32Array()
	slot_of.resize(n)
	slot_of.fill(-1)
	var slot_free := PackedByteArray()
	slot_free.resize(n)
	slot_free.fill(1)
	var pairs: Array = []
	for i in n:
		for k in n:
			pairs.append([0 if seated[i] == 1 else 1, absf(wrapf(angles[i] - slot_angles[k], -180.0, 180.0)), i, k])
	pairs.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2] or (a[2] == b[2] and a[3] < b[3]))
	for pair: Array in pairs:
		if slot_of[pair[2]] < 0 and slot_free[pair[3]] == 1:
			slot_of[pair[2]] = pair[3]
			slot_free[pair[3]] = 0
	return slot_of


## The slot at `angle_deg` (world, see ViewGeometry.bearing_deg() with a yaw of 0) and `radius`
## m from the player. With a synced navmesh it is snapped onto it; a slot that snaps further
## than director_slot_snap_tolerance_m (inside a crate, past a wall) tries the next angle step,
## director_slot_retry_deg, to either side, and so on around. No navmesh (the training room), or
## no angle that works: the raw point.
func _snap_slot(player: PlayerCharacter, angle_deg: float, radius: float) -> Vector3:
	var origin := player.global_position
	var raw := origin + ViewGeometry.forward(deg_to_rad(angle_deg)) * radius
	var map := player.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return raw
	var tolerance := Tuning.data.director_slot_snap_tolerance_m
	var retry := Tuning.data.director_slot_retry_deg
	var steps := int(180.0 / retry)
	for i in steps + 1:
		for side: float in [1.0, -1.0]:
			if i == 0 and side < 0.0:
				continue
			var tried := origin + ViewGeometry.forward(deg_to_rad(angle_deg + side * float(i) * retry)) * radius
			var snapped := NavigationServer3D.map_get_closest_point(map, tried)
			if Vector2(snapped.x - tried.x, snapped.z - tried.z).length() <= tolerance:
				return snapped
	return raw


## The angular nudge (degrees) of an enemy that reported stalling: +1, -1, +2, -2 retry steps.
func _stall_nudge(enemy: EnemyActor) -> float:
	var count := int(_stalls.get(enemy, 0))
	if count == 0:
		return 0.0
	var magnitude := ceilf(float(count) * 0.5) * Tuning.data.director_slot_retry_deg
	return magnitude if count % 2 == 1 else -magnitude


## A stable 0..1 number from `text` (an enemy's name): its jitter and radius.
static func _unit_hash(text: String) -> float:
	return float(text.hash() % _HASH_BUCKETS) / float(_HASH_BUCKETS - 1)


# --- Events ---


## A wind-up began anywhere (a forced one too): the next may follow only after the gap.
func _on_windup_started(attacker: Node3D, _move: MoveData) -> void:
	if attacker is EnemyActor:
		_last_windup_s = _clock_s


## The player revived: no tokens for director_revive_grace_s.
func _on_revived(actor: Node3D) -> void:
	if actor and actor.is_in_group(&"player"):
		_revive_until_s = _clock_s + Tuning.data.director_revive_grace_s


## A hit landed somewhere: the ones on the player (not blocked) start the grace of
## director_hit_grace_s (see _player_recovering()).
func _on_hit_landed(hit: HitInfo) -> void:
	if hit.blocked or hit.victim == null or not hit.victim.is_in_group(&"player"):
		return
	_last_player_hit_s = _clock_s


## `book`'s live enemies as a typed array.
static func _live(book: Array) -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for entry: Variant in book:
		if is_instance_valid(entry):
			out.append(entry as EnemyActor)
	return out
