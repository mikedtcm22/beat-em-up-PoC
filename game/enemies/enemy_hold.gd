class_name EnemyHold
extends RefCounted
## An enemy's hold on the player (Milestone 3, SPEC §7: the Bruiser's grab and headbutt, the
## boss's grab and slam), one per holder; EnemyActor creates it when it starts an attack of kind
## &"grab" and calls it from its move hooks. A grab attack is two moves:
##
##  1. the grab: a hitbox-less, unblockable telegraph that is wound up like any attack (the
##     rear warning, the wind-up cue, a dodge, a jump or a heavy hit on an armored grabber all get
##     out of it). At its strike frame the grab connects by code, or whiffs: the player must be
##     within enemy_grab_range_m of it (scaled by the holder's rig scale) and within
##     enemy_grab_half_angle_deg of its facing, and CombatActor.can_be_grabbed() (a dodge, a jump,
##     the strike's own active frames, the ground and a get-up are out). A whiff is announced by
##     hand (CombatEvents.attack_whiffed: nothing has a hitbox to whiff).
##  2. the follow-up (the headbutt, the slam): started on the connect frame with its own wind-up
##     (EnemyActor.windup_move()), run while the player is held. Its startup is the mash window: the
##     player breaks free (PlayerCharacter, Tuning.grab_break_presses presses of P and K, then
##     break_free() and the holder's _on_hold_broken(), which staggers it away) before its strike
##     frame, or at that frame the victim is let go first (a GRABBED body only takes a hold's
##     jolt from its holder) and a hit built from the move lands (the _throw_held() template:
##     receive_hit(), hitstop, hit_landed, and thrown for the slam).
##
## The holder is in WINDUP and then ATTACK of the follow-up for the whole hold (a running move needs
## those states), never in GRABBING. is_holding() is true exactly while the victim is still held by
## it and the follow-up still runs, so the victim's own safety net lets go of a holder that was
## hit, knocked down, killed or vanished. Nothing here reads a camera or a view.

var holder: EnemyActor
## The player while held; null before the connect and after the release.
var victim: CombatActor
## The grab attack in progress: its first move is the grab, the second the follow-up.
var attack: EnemyAttack


func _init(p_holder: EnemyActor) -> void:
	holder = p_holder


## A new grab attack starts: forget any earlier hold.
func arm(p_attack: EnemyAttack) -> void:
	attack = p_attack
	victim = null


## The grab move (the attack's first), or null.
func grab_move() -> MoveData:
	return attack.first() if attack else null


## The follow-up (the attack's second move: headbutt or slam), or null.
func follow_up_move() -> MoveData:
	return attack.moves[1] if attack and attack.moves.size() > 1 else null


## True when `move` is the follow-up (compared by id: a wind-up copy has the same id).
func is_follow_up(move: MoveData) -> bool:
	var follow := follow_up_move()
	return move != null and follow != null and move.id == follow.id


## True while `v` is held by this holder and its follow-up still runs (CombatActor.is_holding()).
func holds(v: CombatActor) -> bool:
	if v == null or not is_instance_valid(v) or v != victim:
		return false
	if v.state != CombatTypes.ActorState.GRABBED or v.holder != holder:
		return false
	return holder_is_holding()


## The holder still stands in its hold: alive, in the follow-up's wind-up or strike.
func holder_is_holding() -> bool:
	if not is_instance_valid(holder) or holder.health <= 0.0 or holder.is_gone():
		return false
	if holder.state != CombatTypes.ActorState.WINDUP and holder.state != CombatTypes.ActorState.ATTACK \
			and holder.state != CombatTypes.ActorState.GRABBING:
		return false
	return holder.current_move != null and is_follow_up(holder.current_move)


## True while it holds `v` up off the floor: the follow-up is a throw (the boss's slam lifts the
## victim in its wind-up), so the victim hangs in the lifted pose (PlaceholderPoses held_lift).
func lifts(v: CombatActor) -> bool:
	var follow := follow_up_move()
	return follow != null and follow.reaction == CombatTypes.Reaction.THROWN and holds(v)


## Where a grab connects: the flat distance (m) from the holder's origin to the victim's.
func connect_range_m() -> float:
	return Tuning.data.enemy_grab_range_m * holder.rig.rig_scale()


## Called every frame of every move the holder runs (EnemyActor._on_move_frame()): the grab's
## strike frame connects or whiffs, the follow-up's strike frame lets go and hits.
func on_move_frame(move: MoveData, frame: int) -> void:
	if attack == null or frame != move.startup:
		return
	var grab := grab_move()
	if grab != null and move.id == grab.id:
		_connect_or_whiff(move)
	elif is_follow_up(move):
		_strike(move)


## The holder is hit, killed or removed mid-hold: let the victim go with no hit (it was not
## broken free of: no invulnerability, no stagger). A no-op when nothing is held.
func release() -> void:
	var held := victim
	victim = null
	if held != null and is_instance_valid(held) and held.state == CombatTypes.ActorState.GRABBED and held.holder == holder:
		held.release_from_grab(Vector3.ZERO, false)


## The victim broke free by mashing (CombatActor.break_free() calls the holder's _on_hold_broken()
## first, then lets the victim go itself): the hold is over.
func broken() -> void:
	victim = null


## The grab's strike frame: connect to the player, or whiff.
func _connect_or_whiff(grab: MoveData) -> void:
	var player := holder._find_player()
	if not _can_connect(player):
		CombatEvents.attack_whiffed.emit(holder, grab)
		return
	var follow := follow_up_move()
	if follow == null:
		return
	victim = player
	# The follow-up is the running move from now on, in its wind-up. The hold is set before it
	# starts: its windup_started asks the holder for the warning's reach (EnemyActor.
	# warning_reach_m(): no warning for a player already in its hands).
	player.start_grabbed(holder)
	holder.start_move(EnemyActor.windup_move(follow, holder.heavy or attack.heavy), 1, &"root", true)


## Whether the grab takes hold now.
func _can_connect(player: CombatActor) -> bool:
	if player == null or player.health <= 0.0 or not player.can_be_grabbed():
		return false
	var to := player.global_position - holder.global_position
	to.y = 0.0
	if to.length() > connect_range_m():
		return false
	if to.length_squared() < 0.0001:
		return true
	return holder.get_forward().angle_to(to) <= deg_to_rad(Tuning.data.enemy_grab_half_angle_deg)


## The follow-up's strike frame: let the victim go and land the hit, when it is still held.
func _strike(move: MoveData) -> void:
	var held := victim
	victim = null
	if held == null or not is_instance_valid(held) or held.state != CombatTypes.ActorState.GRABBED or held.holder != holder:
		return
	# A GRABBED body takes a hit from its holder only as a jolt that keeps it held: let go first.
	held.release_from_grab(Vector3.ZERO, false)
	var dir := held.global_position - holder.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.0001 else holder.get_forward()
	var hit := HitInfo.new()
	hit.attacker = holder
	hit.victim = held
	hit.move = move
	hit.damage = move.damage
	hit.tier = move.tier
	hit.reaction = move.reaction
	# The knockdown follow-up is the headbutt (the face), the throw the slam (the body).
	var to_face := move.reaction == CombatTypes.Reaction.KNOCKDOWN
	hit.region = CombatTypes.Region.HEAD if to_face else CombatTypes.Region.TORSO
	hit.contact_point = held.rig.get_point_position(&"EyePoint") if to_face else held.get_chest_position()
	hit.direction = dir
	# The radial knockback frame of every strike: z along the push, y up, x to its right.
	hit.knockback = dir * move.knockback.z + dir.cross(Vector3.UP) * move.knockback.x + Vector3.UP * move.knockback.y
	hit.from_behind = held.get_forward().dot(dir) > 0.0
	hit.physics_frame = Engine.get_physics_frames()
	hit.move_frame = move.startup
	hit.chain_step = holder.move_chain_step
	hit.input_timing = holder.move_input_timing
	if held.receive_hit(hit):
		TimeController.hitstop([holder, held], HitDetector.hitstop_for(hit))
		if move.reaction == CombatTypes.Reaction.THROWN:
			CombatEvents.thrown.emit(holder, held)
		CombatEvents.hit_landed.emit(hit)
