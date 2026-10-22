extends Node
## Scripted combo bot (Spec §11): performs every combo and move against training dummies
## in the test room, alternating first-person and side-view cameras, with a caption per
## act. Record it with Movie Maker:
##   godot --path . --write-movie captures/combos.avi --fixed-fps 60 res://tests/bot/combo_bot.tscn
## (tools/capture_combos.sh wraps this and extracts review stills.)

const ROOM := preload("res://game/level/test_room.tscn")

## Only run acts whose title contains this text (empty = all). Set with
## `-- --act=<text>` after the scene path.
var act_filter: String = ""

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
var director: Node
var caption: Label
var log_lines: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--act="):
			act_filter = arg.trim_prefix("--act=")
	Tuning.data.dummy_health = 500.0
	room = ROOM.instantiate()
	add_child(room)
	_build_caption()
	CombatEvents.hit_landed.connect(_on_hit)
	_run.call_deferred()


func _on_hit(hit: HitInfo) -> void:
	var line := "f%d %s: %s %.0f dmg %s" % [
		hit.physics_frame,
		hit.victim.name,
		hit.move.display_name if hit.move else "body",
		hit.damage,
		CombatTypes.tier_name(hit.tier),
	]
	log_lines.append(line)
	print(line)


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
		{title = "P P P P: jab, jab, hook, uppercut", cam = &"first_person", fn = _act_pppp},
		{title = "P P P P (side view)", cam = &"side_view", fn = _act_pppp},
		{title = "P P · P: jab, jab, flurry (mash), shove", cam = &"first_person", fn = _act_flurry},
		{title = "K K K: front kick, roundhouse, spinning heel", cam = &"first_person", fn = _act_kkk},
		{title = "K K K (side view)", cam = &"side_view", fn = _act_kkk},
		{title = "K · K: front kick, stomp kick", cam = &"first_person", fn = _act_k_pause_k},
		{title = "P P K: jab, jab, push kick", cam = &"first_person", fn = _act_ppk},
		{title = "Hold P, release: haymaker", cam = &"first_person", fn = _act_haymaker},
		{title = "Hold P, release: haymaker (side view)", cam = &"side_view", fn = _act_haymaker},
		{title = "Jump + K: flying kick", cam = &"side_view", fn = _act_flying_kick},
		{title = "Jump + K at apex: spin kick", cam = &"side_view", fn = _act_spin_kick},
		{title = "RB: back elbow", cam = &"side_view", fn = _act_back_elbow},
		{title = "Grab, knee x3, grab, throw", cam = &"first_person", fn = _act_grab},
		{title = "Grab and throw (side view)", cam = &"side_view", fn = _act_grab},
		{title = "Stomp a downed enemy", cam = &"first_person", fn = _act_stomp},
		{title = "Pipe: pick up, 3 swings, throw", cam = &"first_person", fn = _act_pipe},
		{title = "Dodge right, quick turn", cam = &"first_person", fn = _act_dodge_turn},
		{title = "Stance: idle, walk, look down", cam = &"first_person", fn = _act_stance},
		{title = "Dodge back: guard", cam = &"first_person", fn = _act_dodge_back},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not title.to_lower().contains(act_filter.to_lower()):
			continue
		await _reset(act.cam)
		caption.text = title
		print("=== ", title)
		var fn: Callable = act.fn
		await fn.call()
		await _wait_idle()
		await _ticks(45)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


# --- Acts ---------------------------------------------------------------------------


func _act_pppp() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 4:
		await _press(&"P", 2, 8)


func _act_flurry() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", 2, 8)
	await _press(&"P", 2)
	await _wait_until(func() -> bool: return player.parser.current != null and player.parser.frames_since_recovery >= 16)
	for i in 7:
		await _press(&"P", 2, 3)


func _act_kkk() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 3:
		await _press(&"K", 2, 10)


func _act_k_pause_k() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"K", 2)
	await _wait_until(func() -> bool: return player.parser.current != null and player.parser.frames_since_recovery >= 16)
	await _press(&"K", 2)


func _act_ppk() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", 2, 8)
	await _press(&"P", 2, 8)
	await _press(&"K", 2)


func _act_haymaker() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", Tuning.data.hold_frames + 10)


func _act_flying_kick() -> void:
	await _stage([Vector3(0, 0, -2.4)])
	await _press(&"JUMP", 2, 2)
	await _press(&"K", 2)


func _act_spin_kick() -> void:
	await _stage([Vector3(0, 0, -1.2), Vector3(0, 0, 1.2), Vector3(1.2, 0, 0)])
	await _press(&"JUMP", 2)
	await _wait_until(func() -> bool: return player.sim_velocity.y < 1.0)
	await _press(&"K", 2)


func _act_back_elbow() -> void:
	await _stage([Vector3(0, 0, 1.0)])
	await _ticks(20)
	await _press(&"RB", 2)


func _act_grab() -> void:
	await _stage([Vector3(0, 0, -1.4), Vector3(0, 0, -3.6)])
	await _press(&"P", 2, 8)
	await _press(&"P", 2, 8)
	await _press(&"P", 2)
	await _wait_idle()
	await _press(&"GRAB", 2, 10)
	# Knees can't cancel into each other: press each one after the last ends.
	for i in 3:
		await _press(&"P", 2)
		await _wait_idle()
		await _ticks(4)
	await _press(&"GRAB", 2, 15)
	await _press(&"K", 2)


func _act_stomp() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 3:
		await _press(&"K", 2, 10)
	await _wait_idle()
	await _wait_until(func() -> bool: return dummies[0].is_downed(), 120)
	# Walk up to the body, then stomp.
	player.input.scripted_move = Vector2(0, 1)
	await _wait_until(
		func() -> bool:
			var d := dummies[0].get_chest_position() - player.global_position
			return Vector2(d.x, d.z).length() < 1.1,
		90
	)
	player.input.scripted_move = Vector2.ZERO
	await _ticks(4)
	await _press(&"K", 2)


func _act_pipe() -> void:
	await _stage([Vector3(0, 0, -1.6), Vector3(0, 0, -6.0)])
	var pipe := get_tree().get_first_node_in_group(&"weapon") as Weapon
	if pipe == null:
		return
	pipe.global_position = player.global_position + player.global_basis * Vector3(0, 0.1, -0.6)
	pipe.linear_velocity = Vector3.ZERO
	await _ticks(10)
	await _press(&"GRAB", 2, 16)
	for i in 3:
		await _press(&"P", 2, 10)
	await _wait_idle()
	dummies[0].set_post(Vector3(30, 0, -30))
	await _ticks(20)
	await _press(&"GRAB", 2, 40)


func _act_dodge_turn() -> void:
	await _stage([Vector3(0, 0, -2.5)])
	player.input.scripted_move = Vector2(1, 0)
	await _press(&"DODGE", 2)
	player.input.scripted_move = Vector2.ZERO
	await _wait_idle()
	await _ticks(20)
	await _press(&"TURN", 2, 30)
	await _press(&"TURN", 2, 20)


## The relaxed stance in first person: idle looking level, a walk, then a look down at
## the player's own hands, legs and feet (45 degrees for a second, then 65, where the lead
## leg comes in) and back up.
func _act_stance() -> void:
	await _stage([Vector3(1.5, 0, -9.0)])
	await _look_to(0.0, 10)
	await _ticks(60)
	player.input.scripted_move = Vector2(0, 1)
	await _ticks(60)
	player.input.scripted_move = Vector2.ZERO
	await _wait_until(func() -> bool: return not player.is_walking(), 60)
	await _ticks(10)
	await _look_to(-45.0, 15)
	await _ticks(60)
	await _look_to(-65.0, 10)
	await _ticks(30)
	await _look_to(0.0, 15)
	await _ticks(20)


## A dodge with no stick: the backstep, with the block guard up for its frames.
func _act_dodge_back() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _look_to(0.0, 6)
	for i in 2:
		player.input.scripted_move = Vector2.ZERO
		await _press(&"DODGE", 2)
		await _wait_idle()
		await _ticks(40)


# --- Harness ------------------------------------------------------------------------


## Turn the view to `pitch_deg` (negative looks down) evenly over `ticks` physics ticks.
func _look_to(pitch_deg: float, ticks: int) -> void:
	var from := player.look_pitch
	var to := deg_to_rad(pitch_deg)
	for i in ticks:
		await get_tree().physics_frame
		player.look_pitch = lerpf(from, to, float(i + 1) / ticks)


func _reset(cam: StringName) -> void:
	player.input.clear_queue()
	player.input.scripted_move = Vector2.ZERO
	player.global_position = room.get(&"player_start")
	player.sim_velocity = Vector3.ZERO
	player.look_yaw = deg_to_rad(room.get(&"player_yaw_deg"))
	player.rotation.y = player.look_yaw
	player.look_pitch = deg_to_rad(-6.0)
	player.parser.reset_chain()
	player.parser.clear_buffer()
	if director:
		var guard := 0
		while director.get(&"mode") != cam and guard < 4:
			director.call(&"cycle")
			guard += 1
	await _ticks(2)


## Place dummies relative to the player (x right, -z ahead); the rest go far away.
func _stage(posts: Array[Vector3]) -> void:
	for i in dummies.size():
		var d := dummies[i]
		# Posts are in the player's frame (x right, -z ahead).
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else Vector3(30 + i * 3, 0, -30)
		var to_player := player.global_position - pos
		d.max_health = 500.0
		d.set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(20)


func _press(button: StringName, hold: int = 2, gap: int = 0) -> void:
	player.input.push_press(button, hold)
	player.input.push_wait(gap)
	while player.input.queued() > 0:
		await get_tree().physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> void:
	for i in max_ticks:
		if condition.call():
			return
		await get_tree().physics_frame


func _wait_idle() -> void:
	await _wait_until(
		func() -> bool:
			return (
				player.input.queued() == 0
				and player.current_move == null
				and player.state in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.GRABBING]
			),
		600
	)


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	caption = Label.new()
	caption.add_theme_font_size_override(&"font_size", 34)
	caption.add_theme_color_override(&"font_outline_color", Color.BLACK)
	caption.add_theme_constant_override(&"outline_size", 8)
	caption.position = Vector2(560, 120)
	layer.add_child(caption)
	add_child(layer)
