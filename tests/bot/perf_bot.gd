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
## The recorder itself is tests/bot/perf_recorder.gd, shared with perf_level_bot.gd (the level walk).

const PerfRecorder := preload("res://tests/bot/perf_recorder.gd")

var _recorder: PerfRecorder


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
	_recorder = PerfRecorder.new()
	add_child(_recorder)
	super._ready()
	_recorder.caption = caption


## The act is about to start: close the last window (an act of its own) and open the next.
func _reset(cam: StringName) -> void:
	_close_window()
	await super._reset(cam)
	_recorder.open()


func _quit() -> void:
	_close_window()
	await super._quit()


## Stop recording and print the window's PERF-BENCH line (nothing when no frame was recorded).
func _close_window() -> void:
	var result := _recorder.close()
	if not result.is_empty():
		log_line("PERF-BENCH " + JSON.stringify(result))
