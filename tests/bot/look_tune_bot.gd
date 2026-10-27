extends "res://tests/bot/combo_bot.gd"
## The training room's look-tuning bot (Milestone 4, F-look): the combo bot's harness (the room, the
## scripted player, the camera director, the caption) running the acts of tests/bot/acts/look_tune_acts.gd,
## the same ones the crowd bot runs, so both rooms are judged from one script. The training room has
## no navmesh or director: an enemy spawned here only stands (the acts freeze the AI, and place and
## trigger by hand). Record with
##   tools/capture_bot.sh res://tests/bot/look_tune_bot.tscn captures/t1t "Look: tune bands at 1 m" 6
## It offers the helpers those acts use from the crowd bot: spawn(), clear_enemies(), god(),
## freeze_ai(), tune(), log_line().

const TuneActs := preload("res://tests/bot/acts/look_tune_acts.gd")

## Tunables an act changed (property -> the value before), put back at the next act's reset.
var _tuned: Dictionary = {}
var _spawned: Array[Node] = []


func _run() -> void:
	await _ticks(3)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	director = get_tree().get_first_node_in_group(&"camera_director")
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
		if child.has_method(&"set_combat_log_visible"):
			child.call(&"set_combat_log_visible", false)
	for act in TuneActs.acts(self):
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		# The three dummies stand where the player's view looks: out of the way, as in every act.
		await _stage([])
		caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await _ticks(45)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	_quit()


## Leave: the acts' enemies go, then the tree quits (a test's bot overrides this to stop instead).
func _quit() -> void:
	clear_enemies()
	get_tree().quit()


func _reset(cam: StringName) -> void:
	clear_enemies()
	for property: StringName in _tuned:
		Tuning.set_value(property, _tuned[property])
	_tuned.clear()
	Tuning.set_value(&"god_mode", false)
	await super._reset(cam)


## Spawn enemy `id` `rel` from the player (x right, y ahead, metres), facing him.
func spawn(id: StringName, rel: Vector2) -> EnemyActor:
	var scene := EnemyCatalog.scene(id)
	if scene == null:
		return null
	var enemy := scene.instantiate() as EnemyActor
	enemy.name = "%s%d" % [String(id).capitalize(), _spawned.size() + 1]
	var at := player.global_position + player.global_basis * Vector3(rel.x, 0.0, -rel.y)
	at.y = player.global_position.y
	enemy.position = at
	var to_player := player.global_position - at
	enemy.rotation.y = atan2(-to_player.x, -to_player.z)
	room.add_child(enemy)
	_spawned.append(enemy)
	return enemy


func clear_enemies() -> void:
	for enemy: Node in _spawned:
		if is_instance_valid(enemy):
			enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
	_spawned.clear()


func god(on: bool = true) -> void:
	Tuning.set_value(&"god_mode", on)


func freeze_ai(on: bool) -> void:
	Tuning.set_value(&"ai_frozen", on)


## Set a tunable for the rest of the act; the next act's reset puts it back.
func tune(property: StringName, value: Variant) -> void:
	if not _tuned.has(property):
		_tuned[property] = Tuning.data.get(property)
	Tuning.set_value(property, value)


func log_line(text: String) -> void:
	log_lines.append(text)
	print(text)
