extends EnemyActor
## A test-only EnemyActor that stands still (M3-plan A2.12): the packages' tests use it where
## they need an enemy body without the real AI's steering. It never moves or attacks on its own.
## `want_token` drives wants_token(); force_attack() winds up `attack` from FREE (started from
## _tick_control(), as a real controller must); with `attack_on_token` it also takes a granted
## token's turn as the real one does: asks the director's may_start_windup(), then winds up.
## It gives the token back to the director (release_token()) when its attack ends, is
## interrupted or it is hit, unless `releases_token` is off.
## ai_state follows the actor state, so a test can read WINDUP, ATTACK or REACT.

const DEFAULT_ATTACK_PATH := "res://game/combat/moves/dummy_jab.tres"

## wants_token() answers this (while it stands free and holds no token).
var want_token: bool = false
## The move force_attack() and a token's turn wind up (the sparring jab until a test sets one).
var attack: MoveData
## Take a granted token's turn (see the class docs).
var attack_on_token: bool = false
## Give the token back to the director when the attack ends or is cut short.
var releases_token: bool = true

var _force_pending: bool = false


func _ready() -> void:
	if archetype == &"":
		archetype = &"stub"
	super._ready()
	if attack == null and ResourceLoader.exists(DEFAULT_ATTACK_PATH):
		attack = load(DEFAULT_ATTACK_PATH) as MoveData


func wants_token() -> bool:
	return want_token and not has_token and state == CombatTypes.ActorState.FREE and health > 0.0


func attack_range_m() -> float:
	return attack.reach_m if attack else 0.0


func force_attack(_index: int = 0) -> void:
	_force_pending = true


func _tick_control() -> void:
	_follow_state()
	if state == CombatTypes.ActorState.FREE:
		if _force_pending or (attack_on_token and has_token and _director_says_go()):
			_force_pending = false
			if attack:
				start_move(windup_move(attack, heavy), 1, &"root", true)
				_follow_state()
				return
		super._tick_control()


func _on_move_finished(move: MoveData) -> void:
	super._on_move_finished(move)
	_give_token_back()


func _on_move_interrupted() -> void:
	_give_token_back()


func _on_hit_received(_hit: HitInfo) -> void:
	_give_token_back()


func _director_says_go() -> bool:
	var director := EnemyDirector.find(get_tree())
	return director == null or director.may_start_windup(self)


func _give_token_back() -> void:
	if not releases_token or not has_token:
		return
	var director := EnemyDirector.find(get_tree())
	if director:
		director.release_token(self)
	if has_token:
		revoke_token()


## ai_state mirrors what the actor is doing (the real controller's is richer).
func _follow_state() -> void:
	match state:
		CombatTypes.ActorState.WINDUP:
			ai_state = AiState.WINDUP
		CombatTypes.ActorState.ATTACK:
			ai_state = AiState.ATTACK
		CombatTypes.ActorState.FREE:
			ai_state = AiState.ENGAGE if has_token else AiState.POSTURE
		CombatTypes.ActorState.KO:
			ai_state = AiState.KO
		_:
			ai_state = AiState.REACT
