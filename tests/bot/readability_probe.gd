extends Node
## The readability probe (Milestone 3, M3-plan A3.5 and Part B §B2): measures whether a crowd fight
## can be read, metrics R1 to R15, over the acts of a bot run. A plain helper a bot (or a test)
## owns: attach() once, then start_act(title) ... end_act() per act, then write_json(). Every
## physics frame it samples the cheap metrics from the simulation; every few frames the first-person
## ones (the lens, through tests/fp_view.gd). It prints a one-screen summary at the end of each act
## and writes readability.json (per act and total) next to the capture (the --write-movie path, or
## --probe-out=<dir>), else under user://.
##
## It reads state and CombatEvents and writes nothing in the game. Enemies are the nodes of group
## `attacker_group` (the AI enemies, "ai_enemy"); the player is the first node in group "player".
## The warning's metrics (R10) come from the oracle it owns (warning_oracle.gd).
##
## **The thresholds are acceptance criteria (Part B §B2): they live in LIMITS and in the tests,
## never in TuningData.** Hard ones (R1, R2, R3, R10, R11) are also asserted by headless tests;
## soft ones are judged by the reviewers, and a miss is a finding, not a failed build.
##
## | key | what it counts |
## | --- | --- |
## | R1 max_concurrent_attackers | enemies in WINDUP, ATTACK or holding the player at once |
## | R2 min_windup_start_gap_frames | least gap between wind-up starts of two different enemies |
## | R3 unwarned_hits | hits on the player whose attack had no wind-up of at least the floor |
## | R4 occluded_windup_share | in-view wind-ups whose chest another enemy hid for over half of it |
## | R5 front_wedge_crowding | share of frames with over 3 posturing enemies within 45 degrees of the look |
## | R6 ring_adherence | posturing enemies' flat distance to the player: median and 10th percentile |
## | R7 capsule_overlap_frames | frames with two standing enemies' capsules overlapping |
## | R8 fp_enemy_coverage | share of the lens covered by enemy meshes: p50 and p95 |
## | R9 blind_grant_share | token grants to an enemy out of view when both kinds waited |
## | R10 warning_* | the widget's corner against the rule (the oracle) |
## | R11 max_knockdown_hit_damage_non_boss | most damage of a non-boss hit that knocked the player down |
## | R12 passive_time_to_ko_s, max_damage_2s | a player who never acts: time to KO, worst 2 s of damage |
## | R13 stuck_events, waves_cleared_90s | enemies with no progress for 3 s; waves cleared in 90 s |
## | R14 windup_voices_stolen | wind-up voices the pool stole before their wind-up ended |
## | R15 frame_ms_p95, spawn_hitch_ms | frame time (the probe's own cost taken out), worst after a spawn |

const Oracle := preload("res://tests/bot/warning_oracle.gd")
const FPView := preload("res://tests/fp_view.gd")

## The act's summary dictionary, as end_act() returns it.
signal act_ended(summary: Dictionary)

## The acceptance thresholds of Part B §B2 (see the class docs).
const LIMITS := {
	"occluded_windup_share_max": 0.10,
	"front_wedge_crowding_max": 0.05,
	"ring_median_min_m": 2.5,
	"ring_median_max_m": 4.0,
	"ring_p10_min_m": 2.2,
	"capsule_overlap_share_max": 0.005,
	"coverage_p50_max": 0.25,
	"coverage_p95_max": 0.50,
	"blind_grant_share_min_crowd": 0.6,
	"max_knockdown_hit_damage": 15.0,
	"passive_time_to_ko_min_s": 12.0,
	"max_damage_2s": 30.0,
	"stuck_events_max": 0,
	"waves_cleared_90s_min": 2,
	"windup_voices_stolen_max": 0,
	"frame_ms_p95_max": 16.7,
	"spawn_hitch_ms_max": 33.0,
}
## R5: "crowded" is more than this many posturing enemies within this half angle of the look.
const FRONT_WEDGE_DEG := 45.0
const FRONT_WEDGE_MAX := 3
## R13: no progress for this long (s) is a stuck enemy, and this is the wave-clearing window (s).
const STUCK_S := 3.0
const WAVE_WINDOW_S := 90.0
## R12 and R15: the damage window and the spawn window (s).
const DAMAGE_WINDOW_S := 2.0
const SPAWN_WINDOW_S := 0.5

## Print the one-screen summary at the end of each act.
@export var print_summary: bool = true
## Print the oracle's WARN-CHECK lines (a bot wants them in its log).
@export var print_oracle_lines: bool = true
## Close the open act and write readability.json when this node leaves the tree (a bot that
## just calls get_tree().quit() still leaves its report).
@export var write_on_exit: bool = false
## Sample in this node's own _physics_process. Off: the owner calls tick() once per physics frame.
@export var auto_tick: bool = true
## Runs after the actors (a larger number is later), so a tick sees the whole frame's simulation.
@export var late_priority: int = 1000
## The group of the enemies measured. Set &"enemy" to measure training dummies as well.
@export var attacker_group: StringName = &"ai_enemy"
@export_group("Sampling")
## Frames between occlusion samples of the wind-ups in progress (0 = off).
@export_range(0, 60) var occlusion_every: int = 3
## Frames between lens-coverage samples (0 = off) and the columns of their grid.
@export_range(0, 120) var lens_every: int = 10
@export_range(8, 96) var lens_cols: int = 32
## A neighbour's mesh hides a wind-up's chest only when it is nearer than the chest by this (m).
@export_range(0.0, 0.5) var occlusion_margin_m: float = 0.05
## R13: an enemy that moved less than this (m) in STUCK_S, while heading for its slot, is stuck;
## and it only heads for it if the slot is further than this (m).
@export_range(0.05, 2.0) var stuck_move_m: float = 0.3
@export_range(0.1, 3.0) var stuck_slot_dist_m: float = 0.75

## The player and the node whose subtree the lens is cast against (the room or the bot).
var player: Node3D
var root: Node
## The oracle the probe owns (warning_oracle.gd), created by attach().
var oracle: Oracle

var _attached: bool = false
var _active: bool = false
var _title: String = ""
var _tags: Dictionary = {}
var _acc: Dictionary = {}
var _acts: Array[Dictionary] = []
var _start_frame: int = 0
var _start_usec: int = 0
# R2
var _last_start_frame: int = -1
var _last_start_id: int = 0
# R3 and R11: per attacker, the attack in progress: {windup_start, windup_ok, damage, held}
var _attacks: Dictionary[int, Dictionary] = {}
# R4: per attacker, the wind-up in progress: {attacker, total, in_view, occluded}
var _wu: Dictionary[int, Dictionary] = {}
# R9: last tick's view of each enemy: {wants, outside, token}
var _prev: Dictionary[int, Dictionary] = {}
# R12: (frame, damage) of the hits on the player in the damage window
var _dmg_window: Array[Vector2] = []
# R13
var _progress: Dictionary[int, Dictionary] = {}
var _alive_prev: int = 0
# R14
var _voice_prev: Array = []
var _voice_counter_start: int = -1
# R15
var _last_usec: int = 0
var _own_usec: int = 0
var _frame_stamp: PackedFloat64Array = PackedFloat64Array()
var _spawn_stamp: PackedFloat64Array = PackedFloat64Array()
var _known: Dictionary[int, bool] = {}


func _ready() -> void:
	process_physics_priority = late_priority
	set_physics_process(auto_tick)


func _physics_process(_delta: float) -> void:
	tick()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _active and _last_usec > 0:
		var ms := float(now - _last_usec - _own_usec) / 1000.0
		_acc.frame_ms.append(maxf(ms, 0.0))
		_frame_stamp.append(float(now) / 1000000.0)
	_own_usec = 0
	_last_usec = now


## Start measuring. `host` is where this node lives if it is not in the tree yet (the bot or the
## room) and the subtree the lens is cast against; `the_player` defaults to group "player".
## Begins an implicit act "run" unless start_act() is called next.
func attach(host: Node = null, the_player: Node3D = null) -> void:
	if not is_inside_tree() and host:
		host.add_child(self)
	root = host if host else (get_tree().current_scene if is_inside_tree() else null)
	player = the_player
	if _attached:
		return
	_attached = true
	oracle = Oracle.new()
	oracle.name = &"WarningOracle"
	oracle.print_lines = print_oracle_lines
	oracle.auto_tick = auto_tick
	add_child(oracle)
	oracle.attach(null, player)
	CombatEvents.attack_started.connect(_on_attack_started)
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.ko.connect(_on_ko)
	CombatEvents.grabbed.connect(_on_grabbed)
	CombatEvents.released.connect(_on_released)
	CombatEvents.grab_escaped.connect(_on_grab_escaped)
	if not _active:
		start_act("run")


func _exit_tree() -> void:
	if not _attached:
		return
	if write_on_exit:
		finish()
	_attached = false
	CombatEvents.attack_started.disconnect(_on_attack_started)
	CombatEvents.windup_started.disconnect(_on_windup_started)
	CombatEvents.windup_ended.disconnect(_on_windup_ended)
	CombatEvents.hit_landed.disconnect(_on_hit_landed)
	CombatEvents.ko.disconnect(_on_ko)
	CombatEvents.grabbed.disconnect(_on_grabbed)
	CombatEvents.released.disconnect(_on_released)
	CombatEvents.grab_escaped.disconnect(_on_grab_escaped)


## Begin an act: `title` appears in the summary and the JSON. `tags` mark what the act is for:
## {passive = true} (the player never acts: R12 applies), {waves = true} is not needed (R13's
## waves are judged by the act's length). The previous act, if open, is ended first.
func start_act(title: String, tags: Dictionary = {}) -> void:
	if _active:
		end_act()
	_title = title
	_tags = tags
	_acc = _new_acc()
	_start_frame = Engine.get_physics_frames()
	_start_usec = Time.get_ticks_usec()
	_last_start_frame = -1
	_last_start_id = 0
	_attacks.clear()
	_wu.clear()
	_prev.clear()
	_dmg_window.clear()
	_progress.clear()
	_frame_stamp = PackedFloat64Array()
	_spawn_stamp = PackedFloat64Array()
	_known.clear()
	for enemy in _live_enemies():
		_known[enemy.get_instance_id()] = true
	_alive_prev = _known.size()
	_voice_prev = _voice_snapshot()
	_voice_counter_start = _voice_counter()
	_acc.voices_measured = _voice_counter_start >= 0 or not _voice_prev.is_empty()
	_active = true
	if oracle:
		oracle.start_act(title)


## Close the act: finish the open wind-ups, compute the metrics, print the summary. Returns
## {title, tags, frames, seconds, metrics, verdict}.
func end_act() -> Dictionary:
	if not _active:
		return {}
	_active = false
	for id in _wu.keys():
		_finish_windup(id)
	_acc.spawn_hitch_ms = _spawn_hitch()
	var warning: Dictionary = oracle.end_act() if oracle else {}
	_acc.voices_stolen += maxi(_voice_counter() - _voice_counter_start, 0) if _voice_counter_start >= 0 else 0
	var frames := int(_acc.frames)
	var summary := {
		"title": _title,
		"tags": _tags.duplicate(),
		"frames": frames,
		"seconds": float(frames) / Engine.physics_ticks_per_second,
		"metrics": _metrics(_acc, warning),
		"acc": _acc,
	}
	summary["verdict"] = verdict(summary.metrics, summary)
	_acts.append(summary)
	if print_summary:
		print(summary_text(summary))
	act_ended.emit(summary)
	return summary


## Close the open act, if any, and write readability.json. Returns the path written ("" when it
## could not be). `dir` overrides the capture directory.
func finish(dir: String = "") -> String:
	end_act()
	return write_json(dir)


## The metrics of the act so far (the open wind-ups of R4 are counted when they end).
func current_metrics() -> Dictionary:
	return _metrics(_acc, oracle.result() if oracle else {})


## Every ended act's summary, in order.
func acts() -> Array[Dictionary]:
	return _acts


## {metrics, verdict} over every act ended so far (the arrays and counters merged, the shares and
## percentiles recomputed from them).
func total() -> Dictionary:
	var merged := _merge_accs()
	var summary := {
		"title": "total",
		"tags": {},
		"frames": int(merged.frames),
		"seconds": float(merged.frames) / Engine.physics_ticks_per_second,
		"acc": merged,
	}
	summary["metrics"] = _metrics(merged, oracle.total_result() if oracle else {})
	summary["verdict"] = verdict(summary.metrics, summary)
	return summary


## The whole report as plain data: {acts: [...], total: {...}} (what write_json() saves).
func report() -> Dictionary:
	var out_acts: Array[Dictionary] = []
	for act in _acts:
		out_acts.append(_public(act))
	return {
		"windowed": DisplayServer.get_name() != "headless",
		"recording": OS.has_feature("movie"),
		"acts": out_acts,
		"total": _public(total()),
	}


func write_json(dir: String = "") -> String:
	var folder := dir if not dir.is_empty() else _capture_dir()
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("readability.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("readability_probe: cannot write %s" % path)
		return ""
	file.store_string(JSON.stringify(report(), "\t"))
	file.close()
	return path


## The folder of the capture being recorded: the --write-movie path's folder, or --probe-out=<dir>.
func _capture_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-out="):
			return arg.trim_prefix("--probe-out=")
	# OS.get_cmdline_args() leaves out the arguments the engine takes itself, --write-movie among them.
	var movie := Engine.get_write_movie_path()
	if not movie.is_empty():
		return movie.get_base_dir()
	return ""


# --- Per-frame sampling ------------------------------------------------------------------------


## Sample this physics frame. Call once per frame, after the simulation (the node's own
## _physics_process does, at `late_priority`).
func tick() -> void:
	if not _active or not _find_player():
		return
	var began := Time.get_ticks_usec()
	var frame := Engine.get_physics_frames()
	var live := _live_enemies()
	_acc.frames += 1
	_tick_attackers(live)
	_tick_crowd(live)
	_tick_grants(live)
	_tick_progress(live, frame)
	_tick_spawns(live)
	_tick_voices()
	_poll_windups()
	if occlusion_every > 0 and frame % occlusion_every == 0 and not _wu.is_empty():
		_sample_occlusion(live)
	if lens_every > 0 and frame % lens_every == 0 and not live.is_empty():
		_sample_lens()
	_own_usec += Time.get_ticks_usec() - began


func _find_player() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
		if oracle and player:
			oracle.player = player
	return player != null


## Standing-or-fighting AI enemies: in the group, alive, not blinked off.
func _live_enemies() -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(attacker_group):
		var enemy := node as CombatActor
		if enemy == null or enemy.is_queued_for_deletion() or enemy.health <= 0.0 or enemy.is_gone():
			continue
		out.append(enemy)
	return out


func _look_yaw() -> float:
	return float(player.get(&"look_yaw"))


func _bearing(point: Vector3) -> float:
	return ViewGeometry.bearing_deg(_look_yaw(), player.global_position, point)


func _flat_distance(node: Node3D) -> float:
	var d := node.global_position - player.global_position
	return Vector2(d.x, d.z).length()


func _is_posturing(enemy: CombatActor) -> bool:
	var ai: Variant = enemy.get(&"ai_state")
	return ai != null and int(ai) == EnemyActor.AiState.POSTURE


## R1: the most enemies in WINDUP, ATTACK or holding the player at once, and the frames over the cap.
func _tick_attackers(live: Array[CombatActor]) -> void:
	var count := 0
	var victim := player as CombatActor
	for enemy in live:
		if enemy.state in [CombatTypes.ActorState.WINDUP, CombatTypes.ActorState.ATTACK, CombatTypes.ActorState.GRABBING]:
			count += 1
		elif victim and enemy.is_holding(victim):
			count += 1
	_acc.max_attackers = maxi(_acc.max_attackers, count)
	var cap := _attacker_cap()
	if cap > 0 and count > cap:
		_acc.cap_violation_frames += 1


func _attacker_cap() -> int:
	var director := EnemyDirector.find(get_tree())
	return director.attacker_cap() if director else Tuning.data.attacker_cap


## R5, R6 and R7: who stands where.
func _tick_crowd(live: Array[CombatActor]) -> void:
	if live.is_empty():
		return
	_acc.crowd_frames += 1
	var in_wedge := 0
	for enemy in live:
		if not _is_posturing(enemy):
			continue
		_acc.ring.append(_flat_distance(enemy))
		if absf(_bearing(enemy.global_position)) <= FRONT_WEDGE_DEG:
			in_wedge += 1
	if in_wedge > FRONT_WEDGE_MAX:
		_acc.wedge_frames += 1
	var standing: Array[CombatActor] = []
	for enemy in live:
		if enemy.state not in [CombatTypes.ActorState.DOWNED, CombatTypes.ActorState.LAUNCHED,
				CombatTypes.ActorState.THROWN, CombatTypes.ActorState.GRABBED, CombatTypes.ActorState.KO]:
			standing.append(enemy)
	if standing.size() < 2:
		return
	_acc.standing2_frames += 1
	var overlapping := false
	for i in standing.size():
		for j in range(i + 1, standing.size()):
			var a := standing[i]
			var b := standing[j]
			var d := a.global_position - b.global_position
			if Vector2(d.x, d.z).length() < a.body_radius + b.body_radius:
				overlapping = true
	if overlapping:
		_acc.overlap_frames += 1


## R9: a token that appeared this frame went to an enemy out of view while enemies in view also
## waited (what each wanted and where each stood is last frame's).
func _tick_grants(live: Array[CombatActor]) -> void:
	var now: Dictionary[int, Dictionary] = {}
	var angle := Tuning.data.rear_warning_angle_deg
	var waiting_in := 0
	var waiting_out := 0
	for state in _prev.values():
		if state.wants and not state.token:
			if state.outside:
				waiting_out += 1
			else:
				waiting_in += 1
	for enemy in live:
		var id := enemy.get_instance_id()
		var token := bool(enemy.get(&"has_token"))
		var before: Dictionary = _prev.get(id, {})
		if token and not before.is_empty() and not before.token:
			_acc.grants += 1
			if waiting_in > 0 and waiting_out > 0 and before.wants:
				_acc.mixed_grants += 1
				if before.outside:
					_acc.blind_mixed_grants += 1
		now[id] = {
			"wants": enemy.has_method(&"wants_token") and bool(enemy.call(&"wants_token")),
			"outside": absf(_bearing(enemy.global_position)) > angle,
			"token": token,
		}
	_prev = now


## R13: an enemy walking in or to its slot that has barely moved for STUCK_S, and the waves cleared.
func _tick_progress(live: Array[CombatActor], frame: int) -> void:
	var window := roundi(STUCK_S * Engine.physics_ticks_per_second)
	var seen: Dictionary[int, bool] = {}
	for enemy in live:
		var ai: Variant = enemy.get(&"ai_state")
		if ai == null:
			continue
		var heading := int(ai) == EnemyActor.AiState.ENTER
		if int(ai) == EnemyActor.AiState.APPROACH:
			var slot: Variant = enemy.get(&"posture_slot")
			if slot is Vector3 and slot != Vector3.INF:
				var to_slot: Vector3 = slot - enemy.global_position
				heading = Vector2(to_slot.x, to_slot.z).length() > stuck_slot_dist_m
		if not heading:
			continue
		var id := enemy.get_instance_id()
		seen[id] = true
		var record: Dictionary = _progress.get(id, {})
		if record.is_empty() or enemy.global_position.distance_to(record.pos) >= stuck_move_m:
			_progress[id] = {"pos": enemy.global_position, "since": frame, "flagged": false}
		elif frame - int(record.since) >= window and not record.flagged:
			record.flagged = true
			_acc.stuck_events += 1
	for id in _progress.keys():
		if not seen.has(id):
			_progress.erase(id)
	var alive := live.size()
	if _alive_prev > 0 and alive == 0:
		_acc.waves_cleared += 1
		if float(_acc.frames) / Engine.physics_ticks_per_second <= WAVE_WINDOW_S:
			_acc.waves_cleared_90s += 1
	_alive_prev = alive
	_acc.peak_alive = maxi(_acc.peak_alive, alive)


## R15: note the frame a new enemy appeared.
func _tick_spawns(live: Array[CombatActor]) -> void:
	for enemy in live:
		var id := enemy.get_instance_id()
		if not _known.has(id):
			_known[id] = true
			_acc.spawns += 1
			_spawn_stamp.append(float(Time.get_ticks_usec()) / 1000000.0)


func _spawn_hitch() -> float:
	var worst := -1.0
	for stamp in _spawn_stamp:
		for i in _frame_stamp.size():
			if _frame_stamp[i] >= stamp and _frame_stamp[i] <= stamp + SPAWN_WINDOW_S:
				worst = maxf(worst, _acc.frame_ms[i])
	return worst


# --- R14: the audio director's voice pool ------------------------------------------------------


func _audio() -> Node:
	return get_tree().get_first_node_in_group(&"audio_director") if is_inside_tree() else null


## A counter the AudioDirector keeps of wind-up voices it stole (windup_voices_stolen), or -1.
func _voice_counter() -> int:
	var audio := _audio()
	if audio and "windup_voices_stolen" in audio:
		return int(audio.get(&"windup_voices_stolen"))
	return -1


## Without that counter: for each voice, the attacker (instance id) whose wind-up it is sounding, as
## the director keeps it (_windup_of), and whether it was playing; [] when the director does not.
func _voice_snapshot() -> Array:
	var audio := _audio()
	if audio == null or not ("_windup_of" in audio) or not ("_voices" in audio):
		return []
	var owners: Array = audio.get(&"_windup_of")
	var voices: Array = audio.get(&"_voices")
	var out: Array = []
	for i in mini(owners.size(), voices.size()):
		out.append([int(owners[i]), bool(voices[i].get(&"playing"))])
	return out


## A voice that was sounding an attacker's wind-up, still playing, and now sounds something else
## while that attacker is still in WINDUP was stolen by the pool (an interrupted wind-up cuts its own
## voices, and one that finished playing is simply a free voice: neither is a steal).
func _tick_voices() -> void:
	if _voice_counter_start >= 0:
		return
	var now := _voice_snapshot()
	for i in mini(_voice_prev.size(), now.size()):
		var was: int = _voice_prev[i][0]
		if was != 0 and bool(_voice_prev[i][1]) and was != int(now[i][0]):
			var attacker := instance_from_id(was) as CombatActor
			if attacker and is_instance_valid(attacker) and attacker.state == CombatTypes.ActorState.WINDUP:
				_acc.voices_stolen += 1
	_voice_prev = now


# --- Events: wind-ups, hits, grabs --------------------------------------------------------------


func _is_player(node: Node) -> bool:
	return node != null and node.is_in_group(&"player")


func _is_enemy(node: Node) -> bool:
	var team: Variant = node.get(&"team") if node else null
	return team != null and int(team) != 0


func _on_attack_started(attacker: Node3D, _move: MoveData, chain_step: int, _timing: StringName) -> void:
	if not _active or not _is_enemy(attacker):
		return
	var id := attacker.get_instance_id()
	if chain_step <= 1 or not _attacks.has(id):
		_attacks[id] = {"windup_start": -1, "windup_ok": false, "damage": 0.0, "held": false}


func _on_windup_started(attacker: Node3D, _move: MoveData) -> void:
	if not _active or not _is_enemy(attacker):
		return
	var frame := Engine.get_physics_frames()
	var id := attacker.get_instance_id()
	_acc.windups += 1
	# R2: the gap to the wind-up that started just before, if another enemy's.
	if _last_start_frame >= 0 and _last_start_id != id:
		var gap := frame - _last_start_frame
		if _acc.min_gap < 0 or gap < _acc.min_gap:
			_acc.min_gap = gap
	_last_start_frame = frame
	_last_start_id = id
	if not _attacks.has(id):
		_attacks[id] = {"windup_start": -1, "windup_ok": false, "damage": 0.0, "held": false}
	_attacks[id].windup_start = frame
	_attacks[id].windup_ok = false
	_wu[id] = {"attacker": attacker, "total": 0, "in_view": 0, "occluded": 0}


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	if not _active or attacker == null:
		return
	var id := attacker.get_instance_id()
	if _wu.has(id):
		_finish_windup(id)
	if not _attacks.has(id):
		return
	if interrupted:
		# A hit out of the wind-up ends the attack: nothing follows it.
		_attacks.erase(id)
		return
	var length := Engine.get_physics_frames() - int(_attacks[id].windup_start)
	_attacks[id].windup_ok = _attacks[id].windup_start >= 0 and length >= _windup_floor(attacker)


## R3: the least a wind-up may last (Tuning's floors: heavy attackers have the longer).
func _windup_floor(attacker: Node) -> int:
	var heavy: Variant = attacker.get(&"heavy")
	return Tuning.data.windup_min_frames_heavy if heavy is bool and heavy else Tuning.data.windup_min_frames_grunt


func _on_hit_landed(hit: HitInfo) -> void:
	if not _active or hit == null or not _is_player(hit.victim) or not _is_enemy(hit.attacker):
		return
	var id := hit.attacker.get_instance_id()
	var frame := Engine.get_physics_frames()
	_acc.hits_on_player += 1
	_acc.damage_taken += hit.damage
	var attack: Dictionary = _attacks.get(id, {})
	if not attack.is_empty():
		attack.damage += hit.damage
	# R3: the hit's attack had a wind-up of at least the floor, unless it is a body impact (a
	# flying body is not an attack) or the final hit of a hold (the hold is its telegraph).
	var exempt: bool = hit.is_body_impact or (not attack.is_empty() and attack.held)
	if not exempt and (attack.is_empty() or not attack.windup_ok):
		_acc.unwarned_hits += 1
		_acc.unwarned.append("%s %s f%d" % [hit.attacker.name, hit.move.id if hit.move else &"body", frame])
	# R11: a non-boss hit that knocked the player down.
	var knocked := not hit.blocked and hit.reaction in [CombatTypes.Reaction.KNOCKDOWN,
			CombatTypes.Reaction.LAUNCH, CombatTypes.Reaction.THROWN]
	if knocked and not hit.attacker.is_in_group(&"boss"):
		_acc.knockdowns += 1
		_acc.max_ko_hit_dmg = maxf(_acc.max_ko_hit_dmg, hit.damage)
		_acc.max_ko_attack_dmg = maxf(_acc.max_ko_attack_dmg, float(attack.get("damage", hit.damage)))
	# R12: the worst DAMAGE_WINDOW_S of damage.
	_dmg_window.append(Vector2(frame, hit.damage))
	var span := DAMAGE_WINDOW_S * Engine.physics_ticks_per_second
	while not _dmg_window.is_empty() and frame - _dmg_window[0].x >= span:
		_dmg_window.pop_front()
	var sum := 0.0
	for entry in _dmg_window:
		sum += entry.y
	_acc.max_damage_2s = maxf(_acc.max_damage_2s, sum)


func _on_ko(victim: Node3D, _hit: HitInfo) -> void:
	if _active and _is_player(victim) and _acc.ko_time_s < 0.0:
		_acc.ko_time_s = float(Engine.get_physics_frames() - _start_frame) / Engine.physics_ticks_per_second


func _on_grabbed(holder: Node3D, victim: Node3D) -> void:
	if _active and holder and _is_player(victim) and _attacks.has(holder.get_instance_id()):
		_attacks[holder.get_instance_id()].held = true


func _on_released(holder: Node3D, _victim: Node3D) -> void:
	if _active and holder and _attacks.has(holder.get_instance_id()):
		_attacks[holder.get_instance_id()].held = false


func _on_grab_escaped(_victim: Node3D, holder: Node3D) -> void:
	if _active and holder and _attacks.has(holder.get_instance_id()):
		_attacks[holder.get_instance_id()].held = false


# --- R4 and R8: the lens ------------------------------------------------------------------------


## The first-person lens as the camera places it (tests/fp_view.gd), as a one-item array, or an
## empty one when the player has no rig to look through (a fake).
func _lens() -> Array:
	if not (player.has_method(&"get_eye_transform") and player.has_method(&"get_look_basis")):
		return []
	var eye: Transform3D = player.call(&"get_eye_transform")
	var look: Basis = player.call(&"get_look_basis")
	return [FPView.camera(eye.origin, look)]


## Wind-ups end: the sampled share of them decides whether the wind-up was in view and occluded.
func _finish_windup(id: int) -> void:
	var record: Dictionary = _wu.get(id, {})
	_wu.erase(id)
	if record.is_empty():
		return
	if int(record.total) == 0:
		_acc.occl_unsampled += 1
	elif int(record.in_view) * 2 > int(record.total):
		_acc.occl_in_view += 1
		if int(record.occluded) * 2 > int(record.total):
			_acc.occl_occluded += 1


## Wind-ups whose attacker left WINDUP (a strike, a hit, freed) are over.
func _poll_windups() -> void:
	for id in _wu.keys():
		var attacker: Variant = _wu[id].attacker
		if not is_instance_valid(attacker) or (attacker as CombatActor).state != CombatTypes.ActorState.WINDUP:
			_finish_windup(id)


## R4: for each wind-up in progress, is its chest in the lens, and is another enemy's body in front?
func _sample_occlusion(live: Array[CombatActor]) -> void:
	var lens := _lens()
	if lens.is_empty():
		return
	var cam: Transform3D = lens[0]
	var inverse := cam.affine_inverse()
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var meshes: Dictionary[int, Array] = {}
	for id in _wu.keys():
		var record: Dictionary = _wu[id]
		var attacker := record.attacker as CombatActor
		if not is_instance_valid(attacker):
			continue
		record.total += 1
		var chest := attacker.get_chest_position()
		var local := inverse * chest
		if local.z >= -FPView.NEAR:
			continue
		var depth := -local.z
		if absf(local.x) / depth > tan_h or absf(local.y) / depth > tan_v:
			continue
		record.in_view += 1
		var to_chest := chest - cam.origin
		var dist := to_chest.length()
		var dir := to_chest / dist
		var hidden := false
		for other in live:
			if other == attacker or hidden:
				continue
			var oid := other.get_instance_id()
			if not meshes.has(oid):
				meshes[oid] = FPView.meshes_under(other)
			for mesh: MeshInstance3D in meshes[oid]:
				if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN) or not mesh.is_visible_in_tree():
					continue
				if FPView.ray_hit(mesh, cam.origin, dir) < dist - occlusion_margin_m:
					hidden = true
					break
		if hidden:
			record.occluded += 1


## R8: the share of the lens whose nearest surface is an enemy's.
func _sample_lens() -> void:
	var lens := _lens()
	if lens.is_empty() or root == null:
		return
	var cells := FPView.hits(root, lens[0], lens_cols)
	if cells.is_empty():
		return
	var cache: Dictionary[int, bool] = {}
	var covered := 0
	for mesh in cells:
		if mesh and _is_enemy_mesh(mesh, cache):
			covered += 1
	_acc.cover.append(float(covered) / cells.size())


func _is_enemy_mesh(mesh: MeshInstance3D, cache: Dictionary[int, bool]) -> bool:
	var id := mesh.get_instance_id()
	if cache.has(id):
		return cache[id]
	var node: Node = mesh
	var found := false
	while node and node != root:
		if node.is_in_group(attacker_group):
			found = true
			break
		node = node.get_parent()
	cache[id] = found
	return found


# --- The numbers --------------------------------------------------------------------------------


func _new_acc() -> Dictionary:
	return {
		"frames": 0,
		"max_attackers": 0, "cap_violation_frames": 0,
		"min_gap": -1, "windups": 0,
		"hits_on_player": 0, "damage_taken": 0.0, "unwarned_hits": 0, "unwarned": [],
		"occl_in_view": 0, "occl_occluded": 0, "occl_unsampled": 0,
		"crowd_frames": 0, "wedge_frames": 0, "ring": PackedFloat32Array(),
		"standing2_frames": 0, "overlap_frames": 0,
		"cover": PackedFloat32Array(),
		"grants": 0, "mixed_grants": 0, "blind_mixed_grants": 0,
		"knockdowns": 0, "max_ko_hit_dmg": 0.0, "max_ko_attack_dmg": 0.0,
		"max_damage_2s": 0.0, "ko_time_s": -1.0,
		"stuck_events": 0, "waves_cleared": 0, "waves_cleared_90s": 0, "peak_alive": 0,
		"voices_stolen": 0, "voices_measured": false,
		"frame_ms": PackedFloat32Array(), "spawn_hitch_ms": -1.0, "spawns": 0,
	}


## Every act's accumulators in one: counters added, maxima and minima taken, samples joined.
func _merge_accs() -> Dictionary:
	var out := _new_acc()
	for act in _acts:
		var acc: Dictionary = act.acc
		for key in ["frames", "cap_violation_frames", "windups", "hits_on_player", "unwarned_hits",
				"occl_in_view", "occl_occluded", "occl_unsampled", "crowd_frames", "wedge_frames",
				"standing2_frames", "overlap_frames", "grants", "mixed_grants", "blind_mixed_grants",
				"knockdowns", "stuck_events", "waves_cleared", "waves_cleared_90s", "voices_stolen", "spawns"]:
			out[key] += acc[key]
		for key in ["damage_taken"]:
			out[key] += acc[key]
		for key in ["max_attackers", "peak_alive"]:
			out[key] = maxi(out[key], acc[key])
		for key in ["max_ko_hit_dmg", "max_ko_attack_dmg", "max_damage_2s", "spawn_hitch_ms"]:
			out[key] = maxf(out[key], acc[key])
		if acc.min_gap >= 0 and (out.min_gap < 0 or acc.min_gap < out.min_gap):
			out.min_gap = acc.min_gap
		if acc.ko_time_s >= 0.0 and (out.ko_time_s < 0.0 or acc.ko_time_s < out.ko_time_s):
			out.ko_time_s = acc.ko_time_s
		out.unwarned.append_array(acc.unwarned)
		for key in ["ring", "cover", "frame_ms"]:
			out[key].append_array(acc[key])
		out.voices_measured = out.voices_measured or acc.voices_measured
	return out


## Part B's metrics, under their readability.json keys, from one act's (or the merged)
## accumulators and the oracle's result for it. A metric nothing measured is null.
func _metrics(acc: Dictionary, warning: Dictionary) -> Dictionary:
	var ring: PackedFloat32Array = acc.ring
	var cover: PackedFloat32Array = acc.cover
	var frame_ms: PackedFloat32Array = acc.frame_ms
	var sampled_windups := int(acc.occl_in_view)
	var windups_checked := int(warning.get("warning_windups", 0))
	return {
		"max_concurrent_attackers": acc.max_attackers,
		"attacker_cap": _attacker_cap() if is_inside_tree() else Tuning.data.attacker_cap,
		"attacker_cap_violation_frames": acc.cap_violation_frames,
		"min_windup_start_gap_frames": acc.min_gap if acc.min_gap >= 0 else null,
		"windups": acc.windups,
		"hits_on_player": acc.hits_on_player,
		"unwarned_hits": acc.unwarned_hits,
		"unwarned_detail": acc.unwarned.duplicate(),
		"occluded_windup_share": (float(acc.occl_occluded) / sampled_windups) if sampled_windups > 0 else null,
		"occlusion_windups_in_view": sampled_windups,
		"front_wedge_crowding": (float(acc.wedge_frames) / acc.crowd_frames) if acc.crowd_frames > 0 else null,
		"ring_adherence": {
			"median": _percentile(ring, 0.5) if not ring.is_empty() else null,
			"p10": _percentile(ring, 0.1) if not ring.is_empty() else null,
			"samples": ring.size(),
		},
		"capsule_overlap_frames": acc.overlap_frames,
		"capsule_overlap_share": (float(acc.overlap_frames) / acc.standing2_frames) if acc.standing2_frames > 0 else null,
		"fp_enemy_coverage": {
			"p50": _percentile(cover, 0.5) if not cover.is_empty() else null,
			"p95": _percentile(cover, 0.95) if not cover.is_empty() else null,
			"samples": cover.size(),
			"share_over_50": _share_over(cover, 0.5) if not cover.is_empty() else null,
			"max": _max_of(cover) if not cover.is_empty() else null,
		},
		"blind_grant_share": (float(acc.blind_mixed_grants) / acc.mixed_grants) if acc.mixed_grants > 0 else null,
		"grants": acc.grants,
		"mixed_grants": acc.mixed_grants,
		"warning_oracle_agreement": warning.get("warning_oracle_agreement"),
		"warning_false_positives": warning.get("warning_false_positives") if windups_checked > 0 or warning.get("warning_false_positives", 0) > 0 else null,
		"warning_latency_frames": warning.get("warning_latency_frames") if windups_checked > 0 else null,
		"warning_end_lag_frames": warning.get("warning_end_lag_frames") if windups_checked > 0 else null,
		"warning_windups": windups_checked,
		"warning_widget_found": warning.get("widget_found", false),
		"max_knockdown_hit_damage_non_boss": acc.max_ko_hit_dmg,
		"max_knockdown_attack_damage_non_boss": acc.max_ko_attack_dmg,
		"knockdowns_on_player": acc.knockdowns,
		"passive_time_to_ko_s": acc.ko_time_s if acc.ko_time_s >= 0.0 else null,
		"max_damage_2s": acc.max_damage_2s,
		"damage_taken": acc.damage_taken,
		"stuck_events": acc.stuck_events,
		"waves_cleared": acc.waves_cleared,
		"waves_cleared_90s": acc.waves_cleared_90s,
		"windup_voices_stolen": acc.voices_stolen if acc.voices_measured else null,
		"frame_ms_p95": _percentile(frame_ms, 0.95) if not frame_ms.is_empty() else null,
		"spawn_hitch_ms": acc.spawn_hitch_ms if acc.spawn_hitch_ms >= 0.0 else null,
		"spawns": acc.spawns,
		"peak_alive": acc.peak_alive,
	}


## The largest of `values` (0 when empty).
static func _max_of(values: PackedFloat32Array) -> float:
	var out := 0.0
	for value in values:
		out = maxf(out, value)
	return out


## The share of `values` above `limit`.
static func _share_over(values: PackedFloat32Array, limit: float) -> float:
	var count := 0
	for value in values:
		if value > limit:
			count += 1
	return float(count) / float(maxi(values.size(), 1))


## The `q` quantile (0 to 1) of `values`, the nearest rank.
static func _percentile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(roundi(q * (sorted.size() - 1)), 0, sorted.size() - 1)]


# --- Verdict and summary --------------------------------------------------------------------------


## Judge `m` (a metrics dictionary) against Part B §B2: one {id, name, status, hard, value, limit}
## per row, status "ok", "FAIL" (a hard row that misses), "miss" (a soft one) or "n/a" (nothing
## measured, or the row does not apply to this act). `summary` (the act's, for its tags, length
## and whether it was recorded or headless) may be empty.
func verdict(m: Dictionary, summary: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seconds := float(summary.get("seconds", 0.0))
	var tags: Dictionary = summary.get("tags", {})
	var cap := int(m.attacker_cap)
	# R1 (hard)
	out.append(_row("R1", "attackers at once", true, int(m.attacker_cap_violation_frames) == 0,
			"max %d" % m.max_concurrent_attackers, "cap %s" % ("none" if cap == 0 else str(cap))))
	# R2 (hard)
	var need := ceili(Tuning.data.director_min_windup_gap_s * Engine.physics_ticks_per_second - 0.001)
	if m.min_windup_start_gap_frames == null:
		out.append(_na("R2", "wind-up start gap", true, "no two wind-ups"))
	else:
		out.append(_row("R2", "wind-up start gap", true, int(m.min_windup_start_gap_frames) >= need,
				"min %d f" % m.min_windup_start_gap_frames, ">= %d f" % need))
	# R3 (hard)
	out.append(_row("R3", "unwarned hits", true, int(m.unwarned_hits) == 0,
			"%d of %d hits" % [m.unwarned_hits, m.hits_on_player], "0"))
	# R4
	if m.occluded_windup_share == null:
		out.append(_na("R4", "occluded wind-ups", false, "none in view"))
	else:
		out.append(_row("R4", "occluded wind-ups", false, float(m.occluded_windup_share) <= LIMITS.occluded_windup_share_max,
				"%.0f%% of %d" % [float(m.occluded_windup_share) * 100.0, m.occlusion_windups_in_view],
				"<= %.0f%%" % (LIMITS.occluded_windup_share_max * 100.0)))
	# R5
	if m.front_wedge_crowding == null:
		out.append(_na("R5", "front wedge crowded", false, "no enemies"))
	else:
		out.append(_row("R5", "front wedge crowded", false, float(m.front_wedge_crowding) <= LIMITS.front_wedge_crowding_max,
				"%.1f%% of frames" % (float(m.front_wedge_crowding) * 100.0),
				"<= %.0f%%" % (LIMITS.front_wedge_crowding_max * 100.0)))
	# R6
	var ring: Dictionary = m.ring_adherence
	if ring.median == null:
		out.append(_na("R6", "posture ring", false, "nobody posturing"))
	else:
		var ring_ok: bool = (
			float(ring.median) >= LIMITS.ring_median_min_m
			and float(ring.median) <= LIMITS.ring_median_max_m
			and float(ring.p10) >= LIMITS.ring_p10_min_m
		)
		out.append(_row("R6", "posture ring", false, ring_ok, "median %.2f m, p10 %.2f m" % [ring.median, ring.p10],
				"median %.1f-%.1f, p10 >= %.1f" % [LIMITS.ring_median_min_m, LIMITS.ring_median_max_m, LIMITS.ring_p10_min_m]))
	# R7
	if m.capsule_overlap_share == null:
		out.append(_na("R7", "capsule overlap", false, "under two standing"))
	else:
		out.append(_row("R7", "capsule overlap", false, float(m.capsule_overlap_share) <= LIMITS.capsule_overlap_share_max,
				"%d f (%.2f%%)" % [m.capsule_overlap_frames, float(m.capsule_overlap_share) * 100.0],
				"<= %.1f%%" % (LIMITS.capsule_overlap_share_max * 100.0)))
	# R8
	var cover: Dictionary = m.fp_enemy_coverage
	if cover.p50 == null:
		out.append(_na("R8", "lens covered by enemies", false, "no samples"))
	else:
		out.append(_row("R8", "lens covered by enemies", false,
				float(cover.p50) <= LIMITS.coverage_p50_max and float(cover.p95) <= LIMITS.coverage_p95_max,
				"p50 %.0f%%, p95 %.0f%%" % [float(cover.p50) * 100.0, float(cover.p95) * 100.0],
				"p50 <= %.0f%%, p95 <= %.0f%%" % [LIMITS.coverage_p50_max * 100.0, LIMITS.coverage_p95_max * 100.0]))
	# R9 (the 0.9 in the director's own test is hard; in a crowd act it is soft)
	if m.blind_grant_share == null:
		out.append(_na("R9", "blind grants", false, "no mixed grants"))
	else:
		out.append(_row("R9", "blind grants", false, float(m.blind_grant_share) >= LIMITS.blind_grant_share_min_crowd,
				"%.0f%% of %d" % [float(m.blind_grant_share) * 100.0, m.mixed_grants],
				">= %.0f%%" % (LIMITS.blind_grant_share_min_crowd * 100.0)))
	# R10 (hard)
	if int(m.warning_windups) == 0 or m.warning_oracle_agreement == null:
		out.append(_na("R10", "warning vs the rule", true, "no wind-ups checked"))
	else:
		var r10_ok := (
			is_equal_approx(float(m.warning_oracle_agreement), 1.0)
			and int(m.warning_false_positives) == 0
			and int(m.warning_latency_frames) <= Oracle.MAX_LATENCY_FRAMES
			and int(m.warning_end_lag_frames) <= Oracle.MAX_END_LAG_FRAMES
		)
		out.append(_row("R10", "warning vs the rule", true, r10_ok,
				"%.0f%% of %d, %d false, lat %s, end %s" % [
					float(m.warning_oracle_agreement) * 100.0, m.warning_windups, m.warning_false_positives,
					_frames_or_dash(m.warning_latency_frames), _frames_or_dash(m.warning_end_lag_frames)],
				"100%%, 0, lat <= %d f, end <= %d f" % [Oracle.MAX_LATENCY_FRAMES, Oracle.MAX_END_LAG_FRAMES]))
	# R11 (hard)
	out.append(_row("R11", "knockdown hit damage", true,
			float(m.max_knockdown_hit_damage_non_boss) <= LIMITS.max_knockdown_hit_damage,
			"max %.0f" % float(m.max_knockdown_hit_damage_non_boss), "<= %.0f" % LIMITS.max_knockdown_hit_damage))
	# R12 (the passive act)
	if not bool(tags.get("passive", false)):
		out.append(_na("R12", "passive player", false, "not a passive act"))
	else:
		var survived: bool = m.passive_time_to_ko_s == null and seconds >= LIMITS.passive_time_to_ko_min_s
		var ko_ok: bool = survived or (m.passive_time_to_ko_s != null and float(m.passive_time_to_ko_s) >= LIMITS.passive_time_to_ko_min_s)
		out.append(_row("R12", "passive player", false, ko_ok and float(m.max_damage_2s) <= LIMITS.max_damage_2s,
				"KO %s, worst 2 s %.0f" % ["no" if m.passive_time_to_ko_s == null else "%.1f s" % float(m.passive_time_to_ko_s), float(m.max_damage_2s)],
				"KO >= %.0f s, 2 s <= %.0f" % [LIMITS.passive_time_to_ko_min_s, LIMITS.max_damage_2s]))
	# R13
	var waves_applies := seconds >= WAVE_WINDOW_S
	var r13_ok := int(m.stuck_events) <= LIMITS.stuck_events_max and (not waves_applies or int(m.waves_cleared_90s) >= LIMITS.waves_cleared_90s_min)
	out.append(_row("R13", "stuck enemies, waves", false, r13_ok,
			"%d stuck, %d waves" % [m.stuck_events, m.waves_cleared_90s],
			"0 stuck%s" % (", >= %d waves" % LIMITS.waves_cleared_90s_min if waves_applies else "")))
	# R14
	if m.windup_voices_stolen == null:
		out.append(_na("R14", "wind-up voices stolen", false, "not measurable"))
	else:
		out.append(_row("R14", "wind-up voices stolen", false, int(m.windup_voices_stolen) <= LIMITS.windup_voices_stolen_max,
				"%d" % m.windup_voices_stolen, "0"))
	# R15 (this Mac, windowed and not recording)
	var measured := DisplayServer.get_name() != "headless" and not OS.has_feature("movie")
	if m.frame_ms_p95 == null or not measured:
		out.append(_na("R15", "frame time", false, "needs a windowed run, not a recording"))
	else:
		var hitch_ok: bool = m.spawn_hitch_ms == null or float(m.spawn_hitch_ms) <= LIMITS.spawn_hitch_ms_max
		out.append(_row("R15", "frame time", false, float(m.frame_ms_p95) <= LIMITS.frame_ms_p95_max and hitch_ok,
				"p95 %.1f ms, spawn %s" % [float(m.frame_ms_p95), "-" if m.spawn_hitch_ms == null else "%.1f ms" % float(m.spawn_hitch_ms)],
				"p95 <= %.1f, spawn <= %.0f" % [LIMITS.frame_ms_p95_max, LIMITS.spawn_hitch_ms_max]))
	return out


## "<n> f", or "-" when nothing was measured (the oracle's -1).
func _frames_or_dash(frames: Variant) -> String:
	return "-" if frames == null or int(frames) < 0 else "%d f" % int(frames)


func _row(id: String, label: String, hard: bool, ok: bool, value: String, limit: String) -> Dictionary:
	return {"id": id, "name": label, "hard": hard, "status": "ok" if ok else ("FAIL" if hard else "miss"),
			"value": value, "limit": limit}


func _na(id: String, label: String, hard: bool, why: String) -> Dictionary:
	return {"id": id, "name": label, "hard": hard, "status": "n/a", "value": why, "limit": ""}


## True when no hard row of `rows` (verdict()) says FAIL.
static func hard_ok(rows: Array[Dictionary]) -> bool:
	for row in rows:
		if row.status == "FAIL":
			return false
	return true


## The rows of `rows` that FAIL (hard) or miss (soft).
static func misses(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows:
		if row.status == "FAIL" or row.status == "miss":
			out.append(row)
	return out


## One screen: a header and a line per row.
func summary_text(summary: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("READABILITY %s  (%d frames, %.1f s)" % [summary.title, summary.frames, summary.seconds])
	for row: Dictionary in summary.verdict:
		var mark: String = row.status
		if row.hard and mark != "n/a":
			mark = "%s (hard)" % mark
		lines.append("  %-3s %-24s %-38s %-8s %s" % [row.id, row.name, row.value, mark, "" if row.status == "ok" else row.limit])
	return "\n".join(lines)


## An act's summary without the raw accumulators, as plain JSON-safe data.
func _public(summary: Dictionary) -> Dictionary:
	return _clean({
		"title": summary.title,
		"tags": summary.tags,
		"frames": summary.frames,
		"seconds": summary.seconds,
		"metrics": summary.metrics,
		"verdict": summary.verdict,
	})


## Strip what JSON cannot hold (NaN, infinity, StringNames) from `value`, recursively.
func _clean(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			out[String(key)] = _clean(value[key])
		return out
	if value is Array:
		var list := []
		for item in value:
			list.append(_clean(item))
		return list
	if value is StringName:
		return String(value)
	if value is float and (is_nan(value) or is_inf(value)):
		return null
	return value
