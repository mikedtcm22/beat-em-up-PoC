extends "res://tests/bot/level_bot.gd"
## The perf bench's level bot (M6 KIT, D29): the level bot (Mission 1 by default) with the same
## frame-time recorder as perf_bot.gd over each act it runs, so "Perf: level walk"
## (tests/bot/level_acts/perf_acts.gd) is measured the same way on any checkout. It prints one
## `PERF-BENCH {json}` line per act (see perf_bot.gd's header); tools/perf_compare.sh takes the last:
##   tools/perf_compare.sh --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" <ref>...
## or one run by hand, windowed, vsync off:
##   godot --path . --disable-vsync res://tests/bot/perf_level_bot.tscn -- --act="Perf: level walk"
## Options after `--`: `--vsync=on|off|adaptive|mailbox` (default off), `--max-fps=<n>`, and the level bot's own.

const PerfRecorder := preload("res://tests/bot/perf_recorder.gd")

var _recorder: PerfRecorder


func _ready() -> void:
	var vsync_mode := DisplayServer.VSYNC_DISABLED
	var max_fps := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vsync="):
			vsync_mode = _vsync_mode_named(arg.trim_prefix("--vsync="))
		elif arg.begins_with("--max-fps="):
			max_fps = int(arg.trim_prefix("--max-fps="))
	DisplayServer.window_set_vsync_mode(vsync_mode)
	Engine.max_fps = max_fps
	_recorder = PerfRecorder.new()
	add_child(_recorder)
	super._ready()
	_recorder.caption = caption


## `--vsync=` by name: on, off (default), adaptive or mailbox (T54: a swapchain that does not wait for the refresh).
func _vsync_mode_named(vsync_name: String) -> DisplayServer.VSyncMode:
	match vsync_name:
		"on":
			return DisplayServer.VSYNC_ENABLED
		"adaptive":
			return DisplayServer.VSYNC_ADAPTIVE
		"mailbox":
			return DisplayServer.VSYNC_MAILBOX
	return DisplayServer.VSYNC_DISABLED


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
