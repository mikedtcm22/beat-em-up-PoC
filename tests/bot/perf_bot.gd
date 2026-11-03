extends "res://tests/bot/crowd_bot.gd"
## The perf bench's bot (L0-bench; run by tools/perf_compare.sh): the crowd bot with a frame-time
## recorder over each act it runs, so a perf act (crowd_acts.gd's "Perf, six with ragdolls", SL-int's
## "Look: Perf, six art Punks") is measured the same way on any checkout, whatever the act itself logs.
## It only reads: the act, its spawns and its hits are the crowd bot's. Run it windowed, vsync off
## (the bot turns vsync off itself; perf_compare.sh adds --disable-vsync as well):
##   godot --path . --disable-vsync res://tests/bot/perf_bot.tscn -- --act="Perf, six with ragdolls"
## and the run ends with one line per act (also in the bot's end-of-run summary, so it is printed
## twice; perf_compare.sh takes the last):
##   PERF-BENCH {json}
## with the wall time between two process frames of the act (from its first frame to its last):
##   frames, mean_ms, p95_ms (the sorted frame at floor(0.95 (n - 1)), as the acts' PERF lines),
##   worst_ms, and the hitches: the worst frame within HITCH_WINDOW_S after an event, for
##   spawn_hitch_ms (the worst over every enemy that appeared), first_spawn_ms (the first enemy),
##   first_hit_ms (the first hit of anyone) and first_finisher_ms (the first finisher-tier hit);
##   -1 when the event did not happen. Plus the act's title, the spawn and hit counts, `stalls` (frames of
##   STALL_MS or more) and the vsync mode.
## Options after `--`: `--vsync=on` (default off), `--max-fps=<n>` (default 0, no cap). On this Mac an
## unvsynced window that is not being presented stalls for 1.0 s every few seconds (stalls > 2 says so);
## with vsync on it does not, and the frame times then follow the display's refresh.
## Wall-clock times: a recording (Movie Maker) or a busy machine says nothing.

## The window after an event in which its worst frame is looked for (s): crowd_acts.gd's PERF_AFTER_S.
const HITCH_WINDOW_S := 0.5
## A frame this long (ms) is a stall, not a slow frame (the 1 s of a drawable that was not released).
const STALL_MS := 500.0
## DisplayServer.VSyncMode by value, for the result's `vsync`. (A headless run has a dummy display
## server that reports "enabled".)
const VSYNC_NAMES: Array[String] = ["disabled", "enabled", "adaptive", "mailbox"]

## The window being recorded: process-frame times (ms) and when each frame ended (s), the events'
## times (s, -1 until seen), the number of spawns and hits, and the act's title.
var _recording: bool = false
var _ms: PackedFloat32Array = PackedFloat32Array()
var _stamp: PackedFloat64Array = PackedFloat64Array()
var _spawn_stamps: PackedFloat64Array = PackedFloat64Array()
var _first_hit: float = -1.0
var _first_finisher: float = -1.0
var _hits: int = 0
var _title: String = ""
var _known: Dictionary = {}


func _ready() -> void:
	var vsync_on := false
	var max_fps := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vsync="):
			vsync_on = arg.trim_prefix("--vsync=") == "on"
		elif arg.begins_with("--max-fps="):
			max_fps = int(arg.trim_prefix("--max-fps="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	CombatEvents.hit_landed.connect(_on_hit_for_bench)
	super._ready()


## The act is about to start: close the last window (an act of its own) and open the next.
func _reset(cam: StringName) -> void:
	_close_window()
	await super._reset(cam)
	_open_window()


func _quit() -> void:
	_close_window()
	await super._quit()


func _open_window() -> void:
	_ms = PackedFloat32Array()
	_stamp = PackedFloat64Array()
	_spawn_stamps = PackedFloat64Array()
	_first_hit = -1.0
	_first_finisher = -1.0
	_hits = 0
	_title = ""
	_known.clear()
	_recording = true
	_sample()


func _on_hit_for_bench(hit: HitInfo) -> void:
	if not _recording:
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
	while _recording:
		await tree.process_frame
		if not _recording:
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


## Stop recording and print the window's PERF-BENCH line (nothing when no frame was recorded).
func _close_window() -> void:
	if not _recording:
		return
	_recording = false
	if _ms.is_empty():
		return
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
	var result := {
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
	log_line("PERF-BENCH " + JSON.stringify(result))
