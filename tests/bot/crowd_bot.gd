extends "res://tests/bot/combo_bot.gd"
## The crowd-room bot (Milestone 3): the combo bot's harness (captions, the scripted player,
## camera switching) in the crowd street, with the acts of every package. Each file
## tests/bot/acts/<key>_acts.gd has `static func acts(bot: Node) -> Array[Dictionary]` of
## `{title, cam, fn}` (a title, a camera mode, an awaitable Callable); the files are read in file
## name order and the acts run in that order (`-- --act=<text>` filters by title, as in the combo
## bot). Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "<act filter>" 6
##
## Helpers for the act files: spawn(), clear_enemies(), set_waves(), freeze_ai(), log_line(), and
## the combo bot's _press(), _ticks(), _wait_until(), _turn_by(), _look_to(), _hud(). The bot
## prints these log lines, one per event, each with its physics frame:
##   W+ f<frame> side=<left|right> count=<n> heavy=<bool>   the rear warning lit a corner
##   W- f<frame> side=<left|right>                            ... and it went out
##   AI f<frame> <enemy> <old>-><new>                        an enemy's AiState changed
##   TOK+ / TOK- f<frame> <enemy>                            an enemy took / gave back a token
##   WU+ f<frame> <attacker> <move>                          a wind-up started
##   WU- f<frame> <attacker> interrupted=<bool>              ... and ended
## (W+ and W- come from the RearWarning in the HUD, found by its signals, so the bot needs no
## class of it.) Without `--tune`, the waves are off in every act: an act that wants them calls
## set_waves(true).

const CROWD_ROOM := preload("res://game/level/crowd_room.tscn")
const ACTS_DIR := "res://tests/bot/acts"
## What spawn() uses for an enemy id whose scene does not exist yet (an archetype not merged).
const STAND_IN := preload("res://tests/fixtures/stub_enemy.tscn")

var spawner: EncounterSpawner
## id of an enemy -> its last AiState / token, for the change lines.
var _ai_seen: Dictionary = {}
var _token_seen: Dictionary = {}
var _warning: Node


func _room_scene() -> PackedScene:
	return CROWD_ROOM


func _physics_process(_delta: float) -> void:
	if room == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as EnemyActor
		if enemy == null:
			continue
		var id := enemy.get_instance_id()
		var state := int(enemy.ai_state)
		if _ai_seen.get(id, -1) != state:
			var old := int(_ai_seen.get(id, -1))
			_ai_seen[id] = state
			log_line("AI f%d %s %s->%s" % [Engine.get_physics_frames(), enemy.name,
					_state_name(old), _state_name(state)])
		var holds := enemy.has_token
		if _token_seen.get(id, false) != holds:
			_token_seen[id] = holds
			log_line("%s f%d %s" % ["TOK+" if holds else "TOK-", Engine.get_physics_frames(), enemy.name])


func _run() -> void:
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after the room's _ready()
	player = room.get(&"player")
	player.input.scripted = true
	spawner = room.get(&"spawner")
	director = get_tree().get_first_node_in_group(&"camera_director")
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
		if child.has_method(&"set_combat_log_visible"):
			child.call(&"set_combat_log_visible", false)  # the bot logs the hits itself
	_connect_logs()
	set_waves(false)
	for act in _collect_acts():
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await _wait_idle()
		await _ticks(45)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


func _reset(cam: StringName) -> void:
	clear_enemies()
	set_waves(false)
	freeze_ai(false)
	await super._reset(cam)


# --- Helpers for the act files -------------------------------------------------------------


## Spawn enemy `id` at `rel` from the player (x right, y ahead, metres), facing the player when
## `face_player`. A stand-in that only stands still when the archetype's scene does not exist
## yet. Returns it, or null.
func spawn(id: StringName, rel: Vector2, face_player: bool = true) -> EnemyActor:
	ensure_scene(id)
	var at := player.global_position + player.global_basis * Vector3(rel.x, 0.0, -rel.y)
	at.y = player.global_position.y
	var yaw := player.rotation.y + PI
	if face_player:
		var to_player := player.global_position - at
		yaw = atan2(-to_player.x, -to_player.z)
	return spawner.spawn_enemy(id, at, yaw)


## Make sure enemy `id` can be spawned: when its scene does not exist yet (an archetype that is
## not merged), the stand-in that only stands still is used for it.
func ensure_scene(id: StringName) -> void:
	if EnemyCatalog.scene(id) == null and not spawner.scene_override.has(id):
		spawner.scene_override[id] = STAND_IN


## Take every AI enemy out of the room now (groups first, then queue_free).
func clear_enemies() -> void:
	EncounterSpawner.remove_enemies(get_tree(), true)


func set_waves(on: bool) -> void:
	if spawner:
		spawner.set_waves_enabled(on)


## Freeze the AI (the Debug tunable ai_frozen): every enemy stands and asks for nothing.
func freeze_ai(on: bool) -> void:
	Tuning.set_value(&"ai_frozen", on)


## Print `text` and keep it for the end-of-run summary.
func log_line(text: String) -> void:
	log_lines.append(text)
	print(text)


# --- Acts and logs -------------------------------------------------------------------------


## Every act of every tests/bot/acts/*_acts.gd, in file name order.
func _collect_acts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(ACTS_DIR)
	if dir == null:
		return out
	var files := PackedStringArray()
	for file in dir.get_files():
		if file.ends_with("_acts.gd"):
			files.append(file)
	files.sort()
	for file in files:
		var script := load(ACTS_DIR.path_join(file)) as GDScript
		if script:
			out.append_array(script.call(&"acts", self))
	return out


func _connect_logs() -> void:
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	_warning = _find_warning(room)
	if _warning:
		_warning.connect(&"shown", _on_warning_shown)
		# A Control already has a `hidden` signal of its own (no arguments), so the widget's
		# "a corner went out" signal may be called `cleared`; either takes the side.
		_warning.connect(&"cleared" if _warning.has_signal(&"cleared") else &"hidden", _on_warning_hidden)


## The RearWarning in the HUD (a node with its `shown` signal, a corner_state() and a signal
## for a corner going out, `cleared` or `hidden`).
func _find_warning(node: Node) -> Node:
	if node.has_signal(&"shown") and node.has_method(&"corner_state") \
			and (node.has_signal(&"cleared") or node.has_signal(&"hidden")):
		return node
	for child in node.get_children():
		var found := _find_warning(child)
		if found:
			return found
	return null


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	log_line("WU+ f%d %s %s" % [Engine.get_physics_frames(), attacker.name, move.id])


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	log_line("WU- f%d %s interrupted=%s" % [Engine.get_physics_frames(), attacker.name, interrupted])


func _on_warning_shown(side: StringName, count: int, heavy: bool) -> void:
	log_line("W+ f%d side=%s count=%d heavy=%s" % [Engine.get_physics_frames(), side, count, heavy])


func _on_warning_hidden(side: StringName = &"") -> void:
	log_line("W- f%d side=%s" % [Engine.get_physics_frames(), side])


func _state_name(state: int) -> String:
	return String(EnemyActor.AiState.keys()[state]) if state >= 0 else "new"
