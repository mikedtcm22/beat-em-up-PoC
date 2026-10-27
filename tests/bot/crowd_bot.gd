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
##
## Instruments (P1-instruments, wired by P1-int): an act with `probe = true` runs with the
## readability probe on (metrics R1-R15 and the warning oracle's WARN-CHECK lines; `tags` is
## passed to probe.start_act(), e.g. {passive = true}), and prints a READABILITY summary at its
## end; `readability.json` lands next to the recording (or `-- --probe-out=<dir>`). The
## autopilot (`pilot`, off unless an act sets `pilot.enabled = true`) fights for the player and
## is stopped at the end of every act. A lock meter logs, per probed act, the longest chain of
## hit reactions the player could not act out of (`LOCK ...`: the flinch-lock check).

const CROWD_ROOM := preload("res://game/level/crowd_room.tscn")
const ACTS_DIR := "res://tests/bot/acts"
## What spawn() uses for an enemy id whose scene does not exist yet (an archetype not merged).
const STAND_IN := preload("res://tests/fixtures/stub_enemy.tscn")
## The spawn points a surround uses, in the order it fills them (the room's spawn_points indices):
## the east alley (ahead), the doorway at x 0 (left), the side alley (right), the west alley
## (behind), the doorway at x -9 (behind left) and behind the car (behind right). With the
## player at the start facing +X, three of them are outside his view.
const SURROUND_POINTS: Array[int] = [4, 1, 5, 3, 0, 6]
## The frames between two top-up spawns (keep_alive).
const KEEP_ALIVE_GAP_FRAMES := 45
## Real milliseconds the bot waits before quitting for the audio mixer to drop stopped voices.
const QUIT_AUDIO_DRAIN_MS := 150
const Probe := preload("res://tests/bot/readability_probe.gd")
const Pilot := preload("res://tests/bot/autopilot.gd")
## The player's states he cannot act out of (a reaction to a hit), for the lock meter. A KO is
## not one: it ends a chain, and the room revives him.
const LOCKED_STATES: Array[int] = [
	CombatTypes.ActorState.HITSTUN, CombatTypes.ActorState.STAGGER, CombatTypes.ActorState.LAUNCHED,
	CombatTypes.ActorState.DOWNED, CombatTypes.ActorState.GETUP,
]
## An enemy in ENGAGE this close (m) is standing at strike range waiting for its go.
const WAITING_RANGE_M := 1.3
## The autopilot knobs an act may change (see autopilot.gd).
const PILOT_KNOBS: Array[StringName] = [
	&"defend", &"attack", &"approach", &"turn_deg_per_s", &"reaction_frames", &"punches_per_chain", &"kicks_per_chain",
	&"use_kicks", &"punch_gap_frames", &"chain_rest_frames", &"engage_range_m", &"approach_stop_m", &"approach_max_m",
]
## Two reactions with a free gap this short between them (frames) are one chain: the gap is not
## time enough to do anything.
const LOCK_GAP_FRAMES := 12

var spawner: EncounterSpawner
## id of an enemy -> its last AiState / token, for the change lines.
var _ai_seen: Dictionary = {}
var _token_seen: Dictionary = {}
var _warning: Node
## The readability probe and the autopilot (see above).
var probe: Probe
var pilot: Pilot
## The autopilot's skill knobs as it was built, put back at every act's reset (an act may change them).
var _pilot_defaults: Dictionary = {}
## `-- --seed=<n>`: starts every archetype's numbering at 7n, which reseeds each one's own random
## choices (they are seeded by name), so a measurement can be repeated over several fights.
var _name_offset: int = 0
## keep_alive(): how many AI enemies to keep alive (0 = off), of which archetype, the frame of the
## last top-up spawn and how many spawns it has made.
var _keep_alive: int = 0
var _keep_alive_id: StringName = &"punk"
var _keep_alive_frame: int = -1000000
var _keep_alive_spawns: int = 0
## Tunables an act changed (property -> the value before), put back at the next act's reset.
var _tuned: Dictionary = {}
## The lock meter: on during a probed act; the frames of the act, of reactions, of the longest
## unbroken reaction and of the longest chain (reactions merged across gaps up to LOCK_GAP_FRAMES).
var _lock_on: bool = false
var _lock_frames: int = 0
var _lock_locked: int = 0
var _lock_run: int = 0
var _lock_run_longest: int = 0
var _lock_chain_start: int = -1
var _lock_last_locked: int = -1
var _lock_chain_longest: int = 0
## The crowd's make-up, summed over the frames of a probed act (see _sample_lock()): enemies
## alive, posturing, committed to an attack (ENGAGE, WINDUP, ATTACK) and backing off (RECOVER).
var _crowd_alive: int = 0
var _crowd_posture: int = 0
var _crowd_attack: int = 0
var _crowd_recover: int = 0
var _crowd_waiting: int = 0
var _crowd_lingering: int = 0
## The widest empty arc (degrees) between the standing enemies seen from the player, over the
## samples with four or more: the largest, and the sum and count for the mean.
var _crowd_arc_max: float = 0.0
var _crowd_arc_sum: float = 0.0
var _crowd_arc_n: int = 0


func _room_scene() -> PackedScene:
	return CROWD_ROOM


func _physics_process(_delta: float) -> void:
	if room == null:
		return
	if _lock_on:
		_sample_lock()
	if _keep_alive > 0:
		_top_up()
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_name_offset = 7 * int(arg.trim_prefix("--seed="))
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
	probe = Probe.new()
	# attach() opens an implicit act "run": close it quietly, so it is neither printed nor reported.
	probe.print_summary = false
	probe.attach(self, player)
	probe.end_act()
	probe.acts().clear()
	probe.print_summary = true
	pilot = Pilot.new()
	pilot.enabled = false
	pilot.enemy_group = &"ai_enemy"
	pilot.attach(self, player)
	for knob: StringName in PILOT_KNOBS:
		_pilot_defaults[knob] = pilot.get(knob)
	for act in _collect_acts():
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var measured: bool = act.get("probe", false)
		if measured:
			_start_measuring(title, act.get("tags", {}))
		var fn: Callable = act.fn
		await fn.call()
		if measured:
			# The act's own length is what is measured: no waiting for the player to be idle.
			_stop_measuring(title)
		else:
			await _wait_idle()
		await _ticks(45)
	caption.text = "done"
	await _ticks(10)
	probe.finish()
	print("\n".join(log_lines))
	await _quit()


## Leave cleanly: no sound may still be mixing when the process exits, or the audio server
## keeps its streams and the exit prints "ERROR: N resources still in use". A headless run is
## far ahead of the audio clock, so the voices are stopped and the mixer is given a moment
## (real time) to drop them.
func _quit() -> void:
	clear_enemies()
	for node: Node in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
	for node: Node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	await _ticks(2)
	OS.delay_msec(QUIT_AUDIO_DRAIN_MS)
	await _ticks(2)
	get_tree().quit()


func _reset(cam: StringName) -> void:
	clear_enemies()
	pilot.enabled = false
	pilot.stop()
	for knob: StringName in _pilot_defaults:
		pilot.set(knob, _pilot_defaults[knob])
	set_waves(false)
	freeze_ai(false)
	_keep_alive = 0
	_keep_alive_id = &"punk"
	for property: StringName in _tuned:
		Tuning.set_value(property, _tuned[property])
	_tuned.clear()
	Tuning.set_value(&"god_mode", false)
	_clear_floor_pipes()
	# Every act starts from the same names, seeds and slots, whichever acts ran before it. The waves
	# start over too (wave 1 after the gap), so an act that turns them on does not carry on a
	# wave an earlier act left half played (and picks the same spawn points); an act that wants a
	# later one calls spawner.start_at_wave(n).
	spawner.set(&"_serials", _fresh_serials())
	spawner.start_at_wave(1)
	(spawner.get(&"_rng") as RandomNumberGenerator).seed = spawner.rng_seed
	_keep_alive_spawns = 0
	var crowd := room as CrowdRoom
	crowd.director.rng_seed = crowd.rng_seed
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


## God mode for the rest of the act (the player takes no damage; reactions still play).
func god(on: bool = true) -> void:
	Tuning.set_value(&"god_mode", on)


## Set a tunable for the rest of the act; the next act's reset puts it back.
func tune(property: StringName, value: Variant) -> void:
	if not _tuned.has(property):
		_tuned[property] = Tuning.data.get(property)
	Tuning.set_value(property, value)


## Spawn enemy `id` at the room's spawn point `index` (spawner.spawn_points: the three doorways
## at x -9, 0 and 9, the west and east alleys, the side alley, behind the car), walking in.
func spawn_at_point(id: StringName, index: int) -> EnemyActor:
	ensure_scene(id)
	var point: Dictionary = spawner.spawn_points[index]
	return spawner.spawn_enemy(id, point.position, point.yaw, false, point.lane_point)


## Spawn `count` Punks (or `id`) round the player, one every `gap` ticks, from SURROUND_POINTS in
## turn: they walk in from ahead, left, right, behind, behind left and behind right.
func surround(count: int, gap: int = 24, id: StringName = &"punk") -> void:
	for i in count:
		spawn_at_point(id, SURROUND_POINTS[_keep_alive_spawns % SURROUND_POINTS.size()])
		_keep_alive_spawns += 1
		if gap > 0:
			await _ticks(gap)


## Keep `count` AI enemies alive for the rest of the act: a new enemy `id` walks in from the next
## surround point every KEEP_ALIVE_GAP_FRAMES while fewer are alive (0 stops it).
func keep_alive(count: int, id: StringName = &"punk") -> void:
	_keep_alive = count
	_keep_alive_id = id


## The autopilot fights for `ticks` physics ticks. `held_back`: a slower, defensive player (one
## jab-jab at a time, no kicks, a long rest, no walking up to anyone), so a crowd gets to
## attack instead of falling to the first combo.
func fight(ticks: int, held_back: bool = true) -> void:
	if held_back:
		hold_back()
	pilot.enabled = true
	await _ticks(ticks)


## Set the autopilot to the held-back style (see fight()); it is not switched on.
func hold_back() -> void:
	pilot.approach = false
	pilot.use_kicks = false
	pilot.punches_per_chain = 2
	pilot.chain_rest_frames = 60


func _top_up() -> void:
	var frame := Engine.get_physics_frames()
	if frame - _keep_alive_frame < KEEP_ALIVE_GAP_FRAMES or spawner.alive_count() >= _keep_alive:
		return
	_keep_alive_frame = frame
	spawn_at_point(_keep_alive_id, SURROUND_POINTS[_keep_alive_spawns % SURROUND_POINTS.size()])
	_keep_alive_spawns += 1


## The spawner's name counters at the start of an act: every AI archetype's numbering begins at
## the bot's `--seed` offset (the enemies' own random choices are seeded by name, so a repeated
## measurement is repeatable whichever archetypes the act spawns).
func _fresh_serials() -> Dictionary:
	var serials := {}
	for entry in EnemyCatalog.ENTRIES:
		if entry.id != &"dummy":
			serials[String(entry.id).capitalize()] = _name_offset
	return serials


## Free the pipes that lie on the floor (the Thug's drops, group `thug_pipe`) so one act's
## leftovers are not in the next one's street. A pipe the player holds is never touched.
func _clear_floor_pipes() -> void:
	for node: Node in get_tree().get_nodes_in_group(PipeThug.DROPPED_GROUP):
		var weapon := node as Weapon
		if weapon != null and weapon.is_available():
			weapon.remove_from_group(PipeThug.DROPPED_GROUP)
			weapon.remove_from_group(&"weapon")
			weapon.queue_free()


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


## Start the readability probe on this act and the lock meter.
func _start_measuring(title: String, tags: Dictionary) -> void:
	probe.start_act(title, tags)
	pilot.reset_counters()
	_lock_frames = 0
	_lock_locked = 0
	_lock_run = 0
	_lock_run_longest = 0
	_lock_chain_start = -1
	_lock_last_locked = -1
	_lock_chain_longest = 0
	_crowd_alive = 0
	_crowd_posture = 0
	_crowd_attack = 0
	_crowd_recover = 0
	_crowd_waiting = 0
	_crowd_lingering = 0
	_crowd_arc_max = 0.0
	_crowd_arc_sum = 0.0
	_crowd_arc_n = 0
	_lock_on = true


## End the act's measuring: the autopilot lets go, the probe prints its summary, and the lock meter
## and the autopilot's counts go in the log.
func _stop_measuring(title: String) -> void:
	_lock_on = false
	pilot.enabled = false
	pilot.stop()
	probe.end_act()
	var seconds := maxf(float(_lock_frames), 1.0) / Engine.physics_ticks_per_second
	log_line("LOCK %s: longest chain %.2f s, longest unbroken reaction %.2f s, %.0f%% of %.1f s in reaction" % [
			title, float(_lock_chain_longest) / Engine.physics_ticks_per_second,
			float(_lock_run_longest) / Engine.physics_ticks_per_second,
			100.0 * float(_lock_locked) / maxf(float(_lock_frames), 1.0), seconds])
	var frames := maxf(float(_lock_frames), 1.0)
	log_line("CROWD %s: on average %.1f alive, %.1f posturing, %.1f attacking (ENGAGE, WINDUP, ATTACK), %.1f backing off, %.2f waiting at strike range, %.2f still within it in RECOVER, widest empty arc %.0f deg (mean %.0f)" % [
			title, _crowd_alive / frames, _crowd_posture / frames, _crowd_attack / frames, _crowd_recover / frames,
			_crowd_waiting / frames, _crowd_lingering / frames, _crowd_arc_max, _crowd_arc_sum / maxf(float(_crowd_arc_n), 1.0)])
	log_line("PILOT %s: %s" % [title, JSON.stringify(pilot.result())])


## One frame of the lock meter: is the player in a reaction, and how long has the run lasted.
func _sample_lock() -> void:
	var frame := Engine.get_physics_frames()
	_lock_frames += 1
	if player.state in LOCKED_STATES:
		_lock_locked += 1
		_lock_run += 1
		_lock_run_longest = maxi(_lock_run_longest, _lock_run)
		if _lock_chain_start < 0 or frame - _lock_last_locked > LOCK_GAP_FRAMES + 1:
			_lock_chain_start = frame
		_lock_last_locked = frame
		_lock_chain_longest = maxi(_lock_chain_longest, frame - _lock_chain_start + 1)
	else:
		_lock_run = 0
	var bearings: Array[float] = []
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as EnemyActor
		if enemy == null or enemy.health <= 0.0:
			continue
		_crowd_alive += 1
		if _lock_frames % 10 == 0 and enemy.state in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.WINDUP, CombatTypes.ActorState.ATTACK]:
			bearings.append(player.look_bearing_deg(enemy.global_position))
		match enemy.ai_state:
			EnemyActor.AiState.POSTURE:
				_crowd_posture += 1
			EnemyActor.AiState.ENGAGE, EnemyActor.AiState.WINDUP, EnemyActor.AiState.ATTACK:
				_crowd_attack += 1
				if enemy.ai_state == EnemyActor.AiState.ENGAGE and Vector2(enemy.global_position.x - player.global_position.x,
						enemy.global_position.z - player.global_position.z).length() <= WAITING_RANGE_M:
					_crowd_waiting += 1
			EnemyActor.AiState.RECOVER:
				_crowd_recover += 1
				if Vector2(enemy.global_position.x - player.global_position.x,
						enemy.global_position.z - player.global_position.z).length() <= WAITING_RANGE_M:
					_crowd_lingering += 1
	if bearings.size() >= 4:
		bearings.sort()
		var arc := bearings[0] + 360.0 - bearings[bearings.size() - 1]
		for i in range(1, bearings.size()):
			arc = maxf(arc, bearings[i] - bearings[i - 1])
		_crowd_arc_max = maxf(_crowd_arc_max, arc)
		_crowd_arc_sum += arc
		_crowd_arc_n += 1


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
