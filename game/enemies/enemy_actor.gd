class_name EnemyActor
extends CombatActor
## The base of every AI enemy (Milestone 3, SPEC §7): the Street Punk, the Kicker, the Pipe Thug,
## the Bruiser and the boss extend it (TrainingDummy does not). The AI is an overlay on
## CombatActor's state machine: AiState says what the controller is doing, ActorState (state)
## stays CombatActor's, and behaviour runs only while FREE (plus turning during a WINDUP). The
## enemy director grants an attack token (grant_token()) to a waiting enemy; its _tick_control()
## then closes in, asks the director's may_start_windup() and starts the attack with a held
## wind-up (start_move(..., windup = true): the rear warning and the interrupt rules hang off it).
##
## Groups: every EnemyActor is in "actor" (CombatActor), "enemy" and "ai_enemy"; the boss also
## "boss". A dead enemy is `health <= 0` (not is_ko(): a killing blow flies first); once
## is_gone() it leaves every group, then queue_free()s.
##
## This is the skeleton (the contract, docs/ARCHITECTURE.md "Enemy AI and the rear warning"):
## it stands still, keeps the token bookkeeping the director writes, and asks for nothing.
## Implemented by P1-ai (and P2-grab for the grab attack kind). The fixture tests/fixtures/
## stub_enemy.gd is the standing-still enemy the other packages' tests use.

## What the controller is doing. ENTER walks in from the spawn point, APPROACH walks to the
## posture slot, POSTURE circles on the ring, ENGAGE has a token and closes to strike range,
## WINDUP and ATTACK mirror the running move, RECOVER backs off, REACT is any reaction state
## CombatActor put it in, KO is dead.
enum AiState { ENTER, APPROACH, POSTURE, ENGAGE, WINDUP, ATTACK, RECOVER, REACT, KO }

## &"punk", &"kicker", &"thug", &"bruiser" or &"boss".
@export var archetype: StringName = &""
## Bruiser and boss: the rear warning's burst is larger, the wind-up floor is the heavy one.
@export var heavy: bool = false
## The Kicker: the director gives it slots in the blind arc first.
@export var prefers_blind_side: bool = false
## The audio director's pitch multiplier for this enemy's voice (deeper heavies), read duck-typed.
@export var voice_pitch_mult: float = 1.0

## What the controller is doing. Read-only outside.
var ai_state: AiState = AiState.POSTURE
## Holds an attack token. Read-only outside; the director sets it (grant_token(), revoke_token()).
var has_token: bool = false
## The last token came from blind-spot priority (shown in F3).
var blind_priority_granted: bool = false
## Where the director wants it to stand on the posture ring; Vector3.INF = none.
var posture_slot: Vector3 = Vector3.INF

## Where enter_from() was told to start and walk to.
var _spawn_position: Vector3 = Vector3.INF
var _lane_point: Vector3 = Vector3.INF


func _ready() -> void:
	team = 1
	add_to_group(&"enemy")
	add_to_group(&"ai_enemy")
	super._ready()


func _tick_control() -> void:
	# The skeleton just stands: no steering, no attacks.
	if state == CombatTypes.ActorState.FREE:
		sim_velocity.x = 0.0
		sim_velocity.z = 0.0
		rig.play_locomotion(Vector2.ZERO, 0.0)


## The state's name (&"POSTURE"), for F3 and logs.
func ai_state_name() -> StringName:
	return StringName(AiState.keys()[ai_state])


## True when it would take an attack token now: posturing, its attack cooldown over, done
## entering, free. The skeleton never wants one.
func wants_token() -> bool:
	return false


## The director grants it the token. `blind` = it came from blind-spot priority.
func grant_token(blind: bool) -> void:
	has_token = true
	blind_priority_granted = blind


## The director takes the token back (the player became unhittable, or it timed out).
func revoke_token() -> void:
	has_token = false
	blind_priority_granted = false


## The director's posture slot for it (world position).
func set_slot(pos: Vector3) -> void:
	posture_slot = pos


## The reach_m of the attack it will throw next (0 = it has none).
func attack_range_m() -> float:
	return 0.0


## Bots and tests: skip the token and wind up now, from FREE. The skeleton does nothing.
func force_attack(_index: int = 0) -> void:
	pass


## The spawner: walk in from `spawn_pos` to `lane_point`, then take up the posture ring.
func enter_from(spawn_pos: Vector3, lane_point: Vector3) -> void:
	_spawn_position = spawn_pos
	_lane_point = lane_point


## `move` with its startup scaled by Tuning.data.windup_mult and floored at
## windup_min_frames_heavy (`heavy`) or windup_min_frames_grunt, a duplicate cached per move id
## (compare moves by id: hit.move is the duplicate). The skeleton returns `move` unchanged.
static func windup_move(move: MoveData, _heavy: bool) -> MoveData:
	return move
