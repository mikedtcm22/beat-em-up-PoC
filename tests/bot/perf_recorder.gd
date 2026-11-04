extends Node
## The perf bench's frame-time recorder (L0-bench, shared by perf_bot.gd and perf_level_bot.gd): over
## one act it records the wall time between process frames, the first time each enemy is seen and the
## hits, and `close()` returns the PERF-BENCH result (see perf_bot.gd's header for the fields). It only
## reads. Wall-clock times: a recording (Movie Maker) or a busy machine says nothing.

## The window after an event in which its worst frame is looked for (s): crowd_acts.gd's PERF_AFTER_S.
const HITCH_WINDOW_S := 0.5
## A frame this long (ms) is a stall, not a slow frame (the 1 s of a drawable that was not released).
const STALL_MS := 500.0
## DisplayServer.VSyncMode by value, for the result's `vsync`. (A headless run has a dummy display
## server that reports "enabled".)
const VSYNC_NAMES: Array[String] = ["disabled", "enabled", "adaptive", "mailbox"]

## The window being recorded: process-frame times (ms) and when each frame ended (s), the events'
## times (s, -1 until seen), the number of hits, and the act's title (read from `caption` on the
## first frame).
var recording: bool = false
## The Label whose text is the act's title (the bot's caption).
var caption: Label
var _ms: PackedFloat32Array = PackedFloat32Array()
var _stamp: PackedFloat64Array = PackedFloat64Array()
var _spawn_stamps: PackedFloat64Array = PackedFloat64Array()
var _first_hit: float = -1.0
var _first_finisher: float = -1.0
var _hits: int = 0
var _title: String = ""
var _known: Dictionary = {}


func _ready() -> void:
	CombatEvents.hit_landed.connect(_on_hit)


## Start a window (the last one must have been closed).
func open() -> void:
	_ms = PackedFloat32Array()
	_stamp = PackedFloat64Array()
	_spawn_stamps = PackedFloat64Array()
	_first_hit = -1.0
	_first_finisher = -1.0
	_hits = 0
	_title = ""
	_known.clear()
	recording = true
	_sample()


func _on_hit(hit: HitInfo) -> void:
	if not recording:
		return
	var now := float(Time.get_ticks_usec()) / 1000000.0
	_hits += 1
	if _first_hit < 0.0:
		_first_hit = now
	if _first_finisher < 0.0 and hit.tier == CombatTypes.HitTier.FINISHER:
		_first_finisher = now


## One entry per process frame until the window is closed: the wall time since the last frame, and
## the first time each enemy is seen. Its own coroutine, beside the act.
func _sample() -> void:
	var tree := get_tree()
	var last := Time.get_ticks_usec()
	while recording:
		await tree.process_frame
		if not recording:
			return
		var now := Time.get_ticks_usec()
		_ms.append(float(now - last) / 1000.0)
		_stamp.append(float(now) / 1000000.0)
		last = now
		if _title == "" and caption != null:
			_title = caption.text
		for node: Node in tree.get_nodes_in_group(&"ai_enemy"):
			var id := node.get_instance_id()
			if not _known.has(id):
				_known[id] = true
				_spawn_stamps.append(float(now) / 1000000.0)


## The worst frame (ms) within HITCH_WINDOW_S after `stamp` (s); -1 when there was no such event.
func _worst_after(stamp: float) -> float:
	if stamp < 0.0:
		return -1.0
	var worst := 0.0
	for i in _stamp.size():
		if _stamp[i] >= stamp and _stamp[i] <= stamp + HITCH_WINDOW_S:
			worst = maxf(worst, _ms[i])
	return worst


## Stop recording and return the window's PERF-BENCH result (empty when no window was open or no
## frame was recorded).
func close() -> Dictionary:
	if not recording:
		return {}
	recording = false
	if _ms.is_empty():
		return {}
	var sorted := _ms.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in _ms:
		sum += value
	var stalls := 0
	for value in _ms:
		if value >= STALL_MS:
			stalls += 1
	var spawn_hitch := -1.0
	for stamp in _spawn_stamps:
		spawn_hitch = maxf(spawn_hitch, _worst_after(stamp))
	return {
		act = _title,
		frames = _ms.size(),
		mean_ms = snappedf(sum / float(_ms.size()), 0.001),
		p95_ms = snappedf(sorted[mini(int(floor(0.95 * (sorted.size() - 1))), sorted.size() - 1)], 0.001),
		worst_ms = snappedf(sorted[sorted.size() - 1], 0.001),
		spawn_hitch_ms = snappedf(spawn_hitch, 0.001),
		first_spawn_ms = snappedf(_worst_after(_spawn_stamps[0]) if not _spawn_stamps.is_empty() else -1.0, 0.001),
		first_hit_ms = snappedf(_worst_after(_first_hit), 0.001),
		first_finisher_ms = snappedf(_worst_after(_first_finisher), 0.001),
		spawns = _spawn_stamps.size(),
		hits = _hits,
		stalls = stalls,
		vsync = VSYNC_NAMES[DisplayServer.window_get_vsync_mode()],
	}
