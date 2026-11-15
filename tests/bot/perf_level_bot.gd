extends "res://tests/bot/level_bot.gd"
## The perf bench's level bot (M6 KIT, D29): the level bot (Mission 1 by default) with the same
## frame-time recorder as perf_bot.gd over each act it runs, so "Perf: level walk"
## (tests/bot/level_acts/perf_acts.gd) is measured the same way on any checkout. It prints one
## `PERF-BENCH {json}` line per act (see perf_bot.gd's header); tools/perf_compare.sh takes the last:
##   tools/perf_compare.sh --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" <ref>...
## or one run by hand, windowed, vsync off:
##   godot --path . --disable-vsync res://tests/bot/perf_level_bot.tscn -- --act="Perf: level walk"
## The bench measures the M6 look unless `--tune=look_profile=1` asks for the comic one: the baselines and the older refs perf_compare.sh
## compares against are M6's, and the comic look is the game's default since M7 T53.
## Options after `--`: `--vsync=on` (default off), `--max-fps=<n>`, and the level bot's own.

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
	_use_m6_look_unless_tuned()
	super._ready()
	_recorder.caption = caption


## The bench's look: M6's unless `--tune=look_profile=<n>` is given (a ref from before M7 has no such tunable: left alone).
func _use_m6_look_unless_tuned() -> void:
	if not &"look_profile" in Tuning.data:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tune=look_profile="):
			return
	Tuning.set_value(&"look_profile", 0)


## The act is about to start: close the last window and open the next.
func _reset(cam: StringName) -> void:
	_close_window()
	await super._reset(cam)
	_recorder.open()


func _quit() -> void:
	_close_window()
	await super._quit()


func _close_window() -> void:
	var result := _recorder.close()
	if not result.is_empty():
		log_line("PERF-BENCH " + JSON.stringify(result))
