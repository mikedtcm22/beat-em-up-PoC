extends "res://tests/bot/combo_bot.gd"
## The Street Punk bot (Milestone 3, P1-ai): the Punk's acts in the training room (no navmesh, so it
## steers straight, and no director, so force_attack() starts its attacks), judged from the
## player's lens. Record with the capture wrapper:
##   tools/capture_bot.sh res://tests/bot/punk_bot.tscn captures/p1-ai "wind-up at 1 m" 12
## It extends the combo bot (its harness: room, player, camera director, caption, helpers) and
## runs its own acts. Log lines: `AI f<frame> <name> <old>-><new>` for each state change and
## `WU+`/`WU-` for each wind-up start and end (`interrupted` or `strike`), with frames.

const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")

var punks: Array[StreetPunk] = []
var _last_state: Dictionary[int, int] = {}


func _ready() -> void:
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	super._ready()


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	_log("WU+ f%d %s %s startup %d" % [Engine.get_physics_frames(), attacker.name, move.id, move.startup])


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	_log("WU- f%d %s %s" % [Engine.get_physics_frames(), attacker.name, "interrupted" if interrupted else "strike"])


func _log(text: String) -> void:
	log_lines.append(text)
	print(text)


func _physics_process(_delta: float) -> void:
	for punk: StreetPunk in punks:
		if not is_instance_valid(punk):
			continue
		var id := punk.get_instance_id()
		if _last_state.get(id, -1) != punk.ai_state:
			var old: int = _last_state.get(id, -1)
			_last_state[id] = punk.ai_state
			_log("AI f%d %s %s->%s" % [Engine.get_physics_frames(), punk.name,
					EnemyActor.AiState.keys()[old] if old >= 0 else "-", punk.ai_state_name()])


func _run() -> void:
	await _ticks(3)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	director = get_tree().get_first_node_in_group(&"camera_director")
	# The help overlay would cover the captures; the combat log stays for timing review.
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
	var acts: Array[Dictionary] = [
		{title = "Punk walks in and postures", cam = &"first_person", fn = _act_walk_in},
		{title = "Punk wind-up at 1 m", cam = &"first_person", fn = _act_windup.bind(1.0, 0)},
		{title = "Punk wind-up at 2.5 m", cam = &"first_person", fn = _act_windup.bind(2.5, 0)},
		{title = "Punk shove wind-up at 1 m", cam = &"first_person", fn = _act_windup.bind(1.0, 1)},
		{title = "Punk shove wind-up at 2.5 m", cam = &"first_person", fn = _act_windup.bind(2.5, 1)},
		{title = "Punk two-hit punch lands", cam = &"first_person", fn = _act_two_hit},
		{title = "Punk shove lands", cam = &"first_person", fn = _act_shove},
		{title = "Punk jab hit out of the wind-up", cam = &"first_person", fn = _act_interrupt},
		{title = "Punk knocked down, gets up, KO", cam = &"first_person", fn = _act_ko},
		{title = "Three Punks posture", cam = &"first_person", fn = _act_three},
		{title = "Punk wind-up (side view)", cam = &"side_view", fn = _act_windup.bind(1.2, 0)},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		await _clear_punks()
		Tuning.data.ai_frozen = false
		caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await _wait_idle()
		await _ticks(45)
	await _clear_punks()
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


# --- Acts ---------------------------------------------------------------------------------


## A Punk walks in from beyond the far end of the view, takes up the ring and circles; the player
## turns slowly to keep it in view.
func _act_walk_in() -> void:
	await _stage([])
	var punk := _spawn_punk(Vector2(3.0, 11.0))
	punk.enter_from(punk.global_position, _world(Vector2(1.0, 7.0)))
	for i in 420:
		await get_tree().physics_frame
		_track(punk, 60.0)


## The wind-up from `distance` metres away, the player standing still looking at it: attack
## `index` (0 the two-hit punch, 1 the shove).
func _act_windup(distance: float, index: int) -> void:
	await _stage([])
	Tuning.data.ai_frozen = true
	var punk := _spawn_punk(Vector2(0.0, distance))
	await _ticks(30)
	punk.force_attack(index)
	await _wait_until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER, 200)
	await _ticks(40)


func _act_two_hit() -> void:
	Tuning.data.punk_shove_chance = 0.0
	await _stage([])
	Tuning.data.ai_frozen = true
	var punk := _spawn_punk(Vector2(0.0, 0.95))
	await _ticks(30)
	punk.force_attack(0)
	await _wait_until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER, 240)
	await _ticks(60)


func _act_shove() -> void:
	await _stage([])
	Tuning.data.ai_frozen = true
	var punk := _spawn_punk(Vector2(0.0, 0.95))
	await _ticks(30)
	punk.force_attack(1)
	await _wait_until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER, 240)
	await _ticks(80)


## The player's jab lands a few frames into the wind-up: it is cut short, the Punk flinches.
func _act_interrupt() -> void:
	await _stage([])
	Tuning.data.ai_frozen = true
	var punk := _spawn_punk(Vector2(0.0, 0.95))
	await _ticks(30)
	punk.force_attack(0)
	await _wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 10)
	await _ticks(8)
	await _press(&"P", 2)
	Tuning.data.ai_frozen = false
	await _wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.FREE and punk.ai_state == EnemyActor.AiState.APPROACH, 120)
	await _ticks(60)


## Four punches (the uppercut launches it), it gets up with its invulnerability and walks back;
## the next four finish it: it lies, blinks and is gone.
func _act_ko() -> void:
	await _stage([])
	var punk := _spawn_punk(Vector2(0.0, 1.0))
	punk.max_health = 50.0
	punk.health = 50.0
	await _ticks(30)
	for i in 4:
		await _press(&"P", 2, 8)
	await _wait_until(func() -> bool: return punk.is_downed(), 120)
	await _wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.FREE and punk.ai_state == EnemyActor.AiState.POSTURE, 400)
	# Stand it in front of the player again, nearly dead, and finish it: it lies, blinks and is gone.
	punk.health = 8.0
	Tuning.data.ai_frozen = true
	punk.global_position = _world(Vector2(0.0, 1.0))
	await _ticks(20)
	for i in 2:
		await _press(&"P", 2, 8)
	var ref: WeakRef = weakref(punk)
	punk = null
	await _wait_until(func() -> bool: return ref.get_ref() == null, 600)


## Three Punks spawned around the player (one behind): each walks to the ring and circles; the
## player stands and watches the one ahead.
func _act_three() -> void:
	await _stage([])
	var ahead := _spawn_punk(Vector2(2.0, 8.0))
	_spawn_punk(Vector2(-6.0, 3.0))
	_spawn_punk(Vector2(2.0, -7.0))
	for punk: StreetPunk in punks:
		punk.enter_from(punk.global_position, punk.global_position)
	for i in 480:
		await get_tree().physics_frame
		_track(ahead, 20.0)


# --- Helpers ------------------------------------------------------------------------------


## World position `rel` metres from the player (x right, y ahead).
func _world(rel: Vector2) -> Vector3:
	var pos := player.global_position + player.global_basis * Vector3(rel.x, 0.0, -rel.y)
	pos.y = 0.0
	return pos


## A Punk `rel` from the player (x right, y ahead), facing him.
func _spawn_punk(rel: Vector2) -> StreetPunk:
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.name = "Punk%d" % (punks.size() + 1)
	punk.display_name = "Punk %d" % (punks.size() + 1)
	var pos := _world(rel)
	punk.position = pos
	var to_player := player.global_position - pos
	punk.rotation.y = atan2(-to_player.x, -to_player.z)
	room.add_child(punk)
	punks.append(punk)
	return punk


func _clear_punks() -> void:
	for punk: StreetPunk in punks:
		if is_instance_valid(punk):
			punk.queue_free()
	punks.clear()
	_last_state.clear()
	await _ticks(2)


## Turn the look toward `punk` at up to `deg_per_s` (keeps it in the view).
func _track(punk: StreetPunk, deg_per_s: float) -> void:
	if not is_instance_valid(punk):
		return
	var to := punk.global_position - player.global_position
	var yaw := atan2(-to.x, -to.z)
	var diff := wrapf(yaw - player.look_yaw, -PI, PI)
	player.look_yaw = wrapf(player.look_yaw + clampf(diff, -deg_to_rad(deg_per_s) / 60.0, deg_to_rad(deg_per_s) / 60.0), -PI, PI)


func _flat_gap(punk: StreetPunk) -> float:
	return Vector2(punk.global_position.x - player.global_position.x, punk.global_position.z - player.global_position.z).length()
