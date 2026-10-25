extends GutTest
## Loads every script under res://tests/bot (the bots, their act files, the instruments) so a
## compile error in one fails the suite, the way test_scripts_compile.gd does for res://game.
## A bot is a scene run with Movie Maker, so a typo in an act file would otherwise show only when
## somebody records it. Scenes under tests/bot load too.


func _collect(dir_path: String, exts: PackedStringArray, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), exts, out)
	for file in dir.get_files():
		if file.get_extension() in exts:
			out.append(dir_path.path_join(file))


func test_every_bot_script_compiles() -> void:
	var paths := PackedStringArray()
	_collect("res://tests/bot", PackedStringArray(["gd"]), paths)
	assert_gt(paths.size(), 0, "found bot scripts")
	for path in paths:
		var script := load(path) as GDScript
		assert_not_null(script, "loads: %s" % path)
		if script:
			assert_true(script.can_instantiate(), "compiles: %s" % path)


func test_every_bot_scene_loads() -> void:
	var paths := PackedStringArray()
	_collect("res://tests/bot", PackedStringArray(["tscn"]), paths)
	assert_gt(paths.size(), 0, "found bot scenes")
	for path in paths:
		assert_not_null(load(path), "loads: %s" % path)
