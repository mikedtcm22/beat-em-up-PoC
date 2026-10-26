extends Node
## The warning oracle (Milestone 3, M3-plan A3.5, Part B §B1 and metric R10). At every
## CombatEvents.windup_started it works out, from the rule alone, which corner the rear warning
## must light (ViewGeometry.warning_corner() from the player's look, never a camera), keeps its
## own model of which wind-ups are still warning (the end rule of §B1.3), and compares that with
## what the HUD's widget says every physics frame (RearWarning.corner_state(side), duck-typed:
## {active, count, heavy, alpha, size_px}, found by method in the tree, so nothing here needs the
## widget's class). Each wind-up gets one line, printed and kept in `lines`:
##   WARN-CHECK ok|FAIL <act> <left|right|both|none> f<frame> lat=<n|-> end=<n|->
## (`lat` is how many frames after the wind-up started the widget showed it, `end` how many after
## the model ended it the widget dropped it; a FAIL adds `why=...`). tools/check_m3_log.py parses
## these. The R10 numbers come from result(): agreement, false positives, worst latency and
## worst end lag. A plain helper a bot or a test owns: attach(), start_act(), tick() (once per
## physics frame, done by its own _physics_process unless `auto_tick` is off), end_act().
##
## The thresholds below are acceptance criteria (Part B §B2), so they live here and in the tests,
## never in TuningData. Presentation-side only: it reads state and writes none.

## One line per wind-up as it is judged (the same text that is printed).
signal checked(line: String)

const SIDES: Array[StringName] = [&"left", &"right"]
## R10: the widget shows a wind-up at most this many frames after it started, and drops it at
## most this many frames after the rule ends it (the widget runs on the render frame, so one).
const MAX_LATENCY_FRAMES := 1
const MAX_END_LAG_FRAMES := 1

## Print each WARN-CHECK line (a bot wants it in its log; a test does not).
@export var print_lines: bool = true
## Tick in this node's own _physics_process. Off: the owner calls tick() once per physics frame.
@export var auto_tick: bool = true
## Runs after the actors (a larger number is later), so a tick sees the whole frame's simulation.
@export var late_priority: int = 1000
## Frames an ended wind-up may wait for the widget to drop it before it is judged late.
@export var settle_limit_frames: int = 30
## Frames between searches for the widget while none is found.
@export var rescan_frames: int = 60

## The act's title, in every line.
var act: String = ""
## The player (a PlayerCharacter or anything with look_yaw, global_position and health); found by
## group "player" when attach() is not given one.
var player: Node3D
## The widget with corner_state(side) -> Dictionary; found by method when not set.
var widget: Object
## The lines of the current act, in order.
var lines: PackedStringArray = []

var _live: Array[Entry] = []
var _settling: Array[Entry] = []
var _finished: Array[Entry] = []
var _fp_active: Dictionary[StringName, bool] = {&"left": false, &"right": false}
var _false_positives: int = 0
var _heavy_mismatch_frames: int = 0
var _widget_seen: bool = false
var _rescan_in: int = 0
var _acts: Array[Dictionary] = []
var _attached: bool = false
var _open: bool = false


## One wind-up under judgement.
class Entry:
	extends RefCounted
	var attacker: Node3D
	var attacker_id: int = 0
	var label: String = ""
	var archetype: StringName = &""
	var heavy: bool = false
	var move_id: StringName = &""
	var frame: int = 0
	var bearing: float = 0.0
	var distance: float = 0.0
	var reach: float = 0.0
	## &"" (none), &"left", &"right" or &"both" by the rule at the first frame.
	var expected: StringName = &""
	var sides: Array[StringName] = []
	var ticks_seen: int = 0
	var lit_frame: int = -1
	var ended: bool = false
	var end_frame: int = -1
	var end_reason: String = ""
	var resolved: Dictionary[StringName, bool] = {}
	var settled_frame: int = -1
	var wrong_side: bool = false
	var judged: bool = false
	## Filled by _judge(): agree, latency, end_lag, ok, why.
	var verdict: Dictionary = {}


func _ready() -> void:
	process_physics_priority = late_priority
	set_physics_process(auto_tick)


func _physics_process(_delta: float) -> void:
	tick()


## Start listening. `host` is where this node lives if it is not in the tree yet (the bot or the
## room); `the_player` defaults to the first node in group "player".
func attach(host: Node = null, the_player: Node3D = null) -> void:
	if not is_inside_tree() and host:
		host.add_child(self)
	player = the_player
	if _attached:
		return
	_attached = true
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_whiffed.connect(_on_attack_whiffed)
	CombatEvents.grabbed.connect(_on_grabbed)
	CombatEvents.ko.connect(_on_ko)
	CombatEvents.vanished.connect(_on_vanished)


## Stop listening and judge what is still live.
func detach() -> void:
	if not _attached:
		return
	_attached = false
	CombatEvents.windup_started.disconnect(_on_windup_started)
	CombatEvents.windup_ended.disconnect(_on_windup_ended)
	CombatEvents.hit_landed.disconnect(_on_hit_landed)
	CombatEvents.attack_whiffed.disconnect(_on_attack_whiffed)
	CombatEvents.grabbed.disconnect(_on_grabbed)
	CombatEvents.ko.disconnect(_on_ko)
	CombatEvents.vanished.disconnect(_on_vanished)


func _exit_tree() -> void:
	detach()


## Begin a fresh act: judge the previous one's leftovers, then clear the counters.
func start_act(title: String) -> void:
	if _open:
		end_act()
	_open = true
	act = title
	lines = PackedStringArray()
	_finished.clear()
	_false_positives = 0
	_heavy_mismatch_frames = 0
	_fp_active = {&"left": false, &"right": false}


## Judge everything still live or waiting and return result() for the act. The act is kept for
## total_result().
func end_act() -> Dictionary:
	for entry: Entry in _live:
		_judge(entry, true)
	for entry: Entry in _settling:
		_judge(entry, true)
	_live.clear()
	_settling.clear()
	var out := result()
	_acts.append(out)
	_finished.clear()
	_open = false
	return out


## The R10 numbers of the act so far (see the keys below; null where nothing was checked).
func result() -> Dictionary:
	var checked_n := 0
	var agreed := 0
	var worst_latency := -1
	var worst_end_lag := -1
	var failed: Array[String] = []
	var events: Array[Dictionary] = []
	for entry: Entry in _finished:
		checked_n += 1
		var verdict := entry.verdict
		if verdict.agree:
			agreed += 1
		if verdict.latency > worst_latency:
			worst_latency = verdict.latency
		if verdict.end_lag > worst_end_lag:
			worst_end_lag = verdict.end_lag
		if not verdict.ok:
			failed.append("%s f%d: %s" % [entry.label, entry.frame, verdict.why])
		events.append({
			"attacker": entry.label,
			"archetype": String(entry.archetype),
			"frame": entry.frame,
			"bearing_deg": snappedf(entry.bearing, 0.1),
			"distance_m": snappedf(entry.distance, 0.01),
			"reach_m": snappedf(entry.reach, 0.01),
			"expected": String(entry.expected),
			"latency": verdict.latency,
			"end_lag": verdict.end_lag,
			"ok": verdict.ok,
		})
	return {
		"act": act,
		"warning_windups": checked_n,
		"warning_oracle_agreement": (float(agreed) / checked_n) if checked_n > 0 else null,
		"warning_oracle_agreed": agreed,
		"warning_false_positives": _false_positives,
		"warning_latency_frames": worst_latency,
		"warning_end_lag_frames": worst_end_lag,
		"warning_heavy_mismatch_frames": _heavy_mismatch_frames,
		"warning_failures": failed,
		"widget_found": _widget_seen,
		"events": events,
	}


## The R10 numbers over every act ended so far (agreement recomputed from the counts, the lags
## and failures merged).
func total_result() -> Dictionary:
	var windups := 0
	var agreed := 0
	var fps := 0
	var latency := -1
	var end_lag := -1
	var heavy := 0
	var failures: Array[String] = []
	var found := false
	for r in _acts:
		windups += int(r.warning_windups)
		agreed += int(r.warning_oracle_agreed)
		fps += int(r.warning_false_positives)
		latency = maxi(latency, int(r.warning_latency_frames))
		end_lag = maxi(end_lag, int(r.warning_end_lag_frames))
		heavy += int(r.warning_heavy_mismatch_frames)
		failures.append_array(r.warning_failures)
		found = found or bool(r.widget_found)
	return {
		"act": "total",
		"warning_windups": windups,
		"warning_oracle_agreement": (float(agreed) / windups) if windups > 0 else null,
		"warning_oracle_agreed": agreed,
		"warning_false_positives": fps,
		"warning_latency_frames": latency,
		"warning_end_lag_frames": end_lag,
		"warning_heavy_mismatch_frames": heavy,
		"warning_failures": failures,
		"widget_found": found,
		"events": [],
	}


## True when R10 holds on `r` (a result()): every wind-up agrees, no false positive, and the
## worst latency and end lag are within a frame. A run with no wind-up checked is not a pass.
static func passes(r: Dictionary) -> bool:
	if r.warning_windups == 0 or r.warning_oracle_agreement == null:
		return false
	return (
		is_equal_approx(float(r.warning_oracle_agreement), 1.0)
		and int(r.warning_false_positives) == 0
		and int(r.warning_latency_frames) <= MAX_LATENCY_FRAMES
		and int(r.warning_end_lag_frames) <= MAX_END_LAG_FRAMES
	)


## Wind-ups the model still holds (the corner it expects lit), for a bot's log.
func live_count() -> int:
	return _live.size()


## The corner the rule expects for the wind-up of `attacker` that is live, &"" when none or
## none lit; null when it has no live entry.
func expected_corner_of(attacker: Node) -> Variant:
	for entry: Entry in _live:
		if entry.attacker == attacker:
			return entry.expected
	return null


# --- Ticking --------------------------------------------------------------------------------


## Compare the widget with the model for this physics frame. Call once per frame, after the
## simulation (the node's own _physics_process does, at `late_priority`).
func tick() -> void:
	var frame := Engine.get_physics_frames()
	_poll_ends(frame)
	var counts := _widget_counts()
	var heavy_flags := _widget_heavy()
	var hidden := _is_hidden()
	var model: Dictionary[StringName, int] = {&"left": 0, &"right": 0}
	var model_heavy: Dictionary[StringName, bool] = {&"left": false, &"right": false}
	if not hidden:
		for entry: Entry in _live:
			for side in entry.sides:
				model[side] += 1
				model_heavy[side] = model_heavy[side] or entry.heavy
	for entry: Entry in _live:
		entry.ticks_seen += 1
		if entry.lit_frame >= 0 or entry.sides.is_empty() or hidden:
			continue
		var lit := true
		for side in entry.sides:
			if counts[side] < model[side]:
				lit = false
		if lit:
			entry.lit_frame = frame
	for side in SIDES:
		var excess := maxi(counts[side] - model[side], 0)
		var pending: Array[Entry] = []
		for entry: Entry in _settling:
			if entry.sides.has(side) and not entry.resolved.get(side, false):
				pending.append(entry)
		var explained := mini(excess, pending.size())
		for i in pending.size() - explained:
			pending[i].resolved[side] = true
		var unexplained := excess - explained
		if unexplained > 0:
			if not _fp_active[side]:
				_false_positives += 1
				if _live.is_empty():
					_emit("WARN-CHECK FAIL %s none f%d lat=- end=- why=unexplained burst on %s" % [act, frame, side])
			# Whatever was winding up while a burst nobody asked for showed on `side` is wrong.
			for entry: Entry in _live:
				if not entry.sides.has(side):
					entry.wrong_side = true
		_fp_active[side] = unexplained > 0
		if counts[side] > 0 and counts[side] >= model[side] and model[side] > 0 and pending.is_empty():
			if heavy_flags[side] != model_heavy[side]:
				_heavy_mismatch_frames += 1
	var still: Array[Entry] = []
	for entry: Entry in _settling:
		var done := true
		for side in entry.sides:
			if not entry.resolved.get(side, false):
				done = false
		if done:
			entry.settled_frame = frame
			_judge(entry, false)
		elif frame - entry.end_frame >= settle_limit_frames:
			_judge(entry, true)
		else:
			still.append(entry)
	_settling = still


# --- Events: a wind-up starts, and the ways it ends -----------------------------------------


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	if attacker == null or move == null:
		return
	var team: Variant = attacker.get(&"team")
	if team != null and int(team) == 0:
		return
	var who := _player()
	if who == null:
		return
	var entry := Entry.new()
	entry.attacker = attacker
	entry.attacker_id = attacker.get_instance_id()
	entry.label = String(attacker.name)
	var archetype: Variant = attacker.get(&"archetype")
	entry.archetype = archetype if archetype is StringName else &""
	var heavy: Variant = attacker.get(&"heavy")
	entry.heavy = heavy is bool and heavy
	entry.move_id = move.id
	entry.frame = Engine.get_physics_frames()
	var look_yaw := float(who.get(&"look_yaw"))
	entry.bearing = ViewGeometry.bearing_deg(look_yaw, who.global_position, attacker.global_position)
	var flat := Vector2(attacker.global_position.x - who.global_position.x, attacker.global_position.z - who.global_position.z)
	entry.distance = flat.length()
	entry.reach = attacker.call(&"warning_reach_m", move) if attacker.has_method(&"warning_reach_m") else move.reach_m
	var tuning := Tuning.data
	entry.expected = ViewGeometry.warning_corner(entry.bearing, entry.distance, entry.reach,
			tuning.rear_warning_angle_deg, tuning.rear_warning_behind_deg, tuning.rear_warning_range_margin_m)
	if _is_hidden():
		# The widget does not fire while the player is in the KO view.
		entry.expected = &""
	match entry.expected:
		&"left":
			entry.sides = [&"left"]
		&"right":
			entry.sides = [&"right"]
		&"both":
			entry.sides = [&"left", &"right"]
	_live.append(entry)


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	# The strike coming out (interrupted false) never ends the warning (§B1.3).
	if interrupted:
		_end_of(attacker, "interrupted")


func _on_hit_landed(hit: HitInfo) -> void:
	if hit != null:
		_end_of(hit.attacker, "hit")


func _on_attack_whiffed(attacker: Node3D, _move: MoveData) -> void:
	_end_of(attacker, "whiff")


func _on_grabbed(holder: Node3D, _victim: Node3D) -> void:
	_end_of(holder, "grab")


func _on_ko(victim: Node3D, _hit: HitInfo) -> void:
	_end_of(victim, "ko")


func _on_vanished(actor: Node3D) -> void:
	_end_of(actor, "vanished")


func _end_of(attacker: Node3D, reason: String) -> void:
	if attacker == null:
		return
	var id := attacker.get_instance_id()
	for entry: Entry in _live.duplicate():
		if entry.attacker_id == id:
			_end(entry, reason)


func _end(entry: Entry, reason: String) -> void:
	if entry.ended:
		return
	entry.ended = true
	entry.end_frame = Engine.get_physics_frames()
	entry.end_reason = reason
	_live.erase(entry)
	if entry.sides.is_empty() or entry.ticks_seen <= MAX_LATENCY_FRAMES:
		# Nothing was showing for it (or it lived too briefly for the widget to be asked).
		_judge(entry, false)
		return
	for side in entry.sides:
		entry.resolved[side] = false
	_settling.append(entry)


## The rule's polled ends (§B1.3): the attacker freed, out of WINDUP and ATTACK, or running a
## different move.
func _poll_ends(_frame: int) -> void:
	for entry: Entry in _live.duplicate():
		var attacker: Node3D = entry.attacker
		if not is_instance_valid(attacker) or attacker.is_queued_for_deletion() or not attacker.is_inside_tree():
			_end(entry, "freed")
			continue
		var state: Variant = attacker.get(&"state")
		if state == null:
			continue
		if state != CombatTypes.ActorState.WINDUP and state != CombatTypes.ActorState.ATTACK:
			_end(entry, "state")
			continue
		var current: Variant = attacker.get(&"current_move")
		if current == null or (current as MoveData).id != entry.move_id:
			_end(entry, "move")


# --- Judging and lines ------------------------------------------------------------------------


## Decide what became of `entry` and print its line. `forced`: the act ended, or the widget was
## given its whole settle limit, while the wind-up's end was still waiting to be seen on screen.
func _judge(entry: Entry, forced: bool) -> void:
	if entry.judged:
		return
	entry.judged = true
	var latency := entry.lit_frame - entry.frame if entry.lit_frame >= 0 else -1
	var end_lag := entry.settled_frame - entry.end_frame if entry.settled_frame >= 0 else -1
	var seen := entry.ticks_seen > MAX_LATENCY_FRAMES
	if forced and entry.ended and not entry.sides.is_empty() and entry.settled_frame < 0 and seen:
		# Still showing when the wait ran out: the lag is at least what was waited.
		var waited := Engine.get_physics_frames() - entry.end_frame
		if waited > MAX_END_LAG_FRAMES:
			end_lag = waited
	var why: Array[String] = []
	var agree := true
	if not entry.sides.is_empty() and seen and entry.lit_frame < 0:
		agree = false
		why.append("not-lit")
	if entry.wrong_side:
		agree = false
		why.append("wrong-side")
	if latency > MAX_LATENCY_FRAMES:
		why.append("late")
	if end_lag > MAX_END_LAG_FRAMES:
		why.append("end-late")
	entry.verdict = {
		"agree": agree,
		"latency": latency,
		"end_lag": end_lag,
		"ok": why.is_empty(),
		"why": ",".join(why),
	}
	_finished.append(entry)
	var corner := "none" if entry.expected == &"" else String(entry.expected)
	var line := "WARN-CHECK %s %s %s f%d lat=%s end=%s" % [
		"ok" if entry.verdict.ok else "FAIL", act, corner, entry.frame,
		str(latency) if latency >= 0 else "-",
		str(end_lag) if end_lag >= 0 else "-",
	]
	if not entry.verdict.ok:
		line += " why=%s" % entry.verdict.why
	_emit(line)


func _emit(line: String) -> void:
	lines.append(line)
	if print_lines:
		print(line)
	checked.emit(line)


# --- The widget and the player ----------------------------------------------------------------


func _player() -> Node3D:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	return player


## True while the widget is suppressed (the player's health is 0 and rear_warning_hide_in_ko is on).
func _is_hidden() -> bool:
	var who := _player()
	if who == null or not Tuning.data.rear_warning_hide_in_ko:
		return false
	var health: Variant = who.get(&"health")
	return health != null and float(health) <= 0.0


func _find_widget() -> Object:
	if widget != null and is_instance_valid(widget):
		return widget
	widget = null
	if not is_inside_tree():
		return null
	if _rescan_in > 0:
		_rescan_in -= 1
		return null
	_rescan_in = rescan_frames
	for node in get_tree().root.find_children("*", "", true, false):
		if node.has_method(&"corner_state"):
			widget = node
			_widget_seen = true
			return widget
	return null


func _side_state(side: StringName) -> Dictionary:
	var found := _find_widget()
	if found == null:
		return {}
	_widget_seen = true
	var state: Variant = found.call(&"corner_state", side)
	return state if state is Dictionary else {}


func _widget_counts() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for side in SIDES:
		var state := _side_state(side)
		var active := bool(state.get("active", false))
		out[side] = maxi(int(state.get("count", 1)), 1) if active else 0
	return out


func _widget_heavy() -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	for side in SIDES:
		out[side] = bool(_side_state(side).get("heavy", false))
	return out
