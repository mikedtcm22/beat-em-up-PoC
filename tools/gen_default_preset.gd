extends SceneTree
## Writes res://tuning/default.json, the shipped-defaults tuning preset, from TuningData's
## defaults (every exported value, no move overrides). Run it after adding or changing a
## TuningData default (tests/test_tuning_panel.gd checks the file matches):
##   godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd

const TuningScript := preload("res://game/autoload/tuning.gd")


func _initialize() -> void:
	var tuning: Node = TuningScript.new()
	var path: String = TuningScript.EXPORT_DIR.path_join(TuningScript.DEFAULT_PRESET + ".json")
	var preset: Dictionary = tuning.call(&"default_preset_dict")
	var err: Error = TuningScript.write_preset_file(path, preset)
	tuning.free()
	if err == OK:
		print("Wrote %s (%d values)" % [path, (preset.tuning as Dictionary).size()])
	else:
		printerr("Could not write %s: %s" % [path, error_string(err)])
	quit(0 if err == OK else 1)
