extends GutTest
## Loads every script, resource and scene under res://game so compile and load errors
## fail the suite (autoloads are available here, unlike `godot --check-only`).


func _collect(dir_path: String, exts: PackedStringArray, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), exts, out)
	for file in dir.get_files():
		if file.get_extension() in exts:
			out.append(dir_path.path_join(file))


func test_all_scripts_compile() -> void:
	var paths := PackedStringArray()
	_collect("res://game", PackedStringArray(["gd"]), paths)
	assert_gt(paths.size(), 0, "found scripts")
	for path in paths:
		var script := load(path) as GDScript
		assert_not_null(script, "loads: %s" % path)
		if script:
			assert_true(script.can_instantiate(), "compiles: %s" % path)


func test_all_resources_and_scenes_load() -> void:
	var paths := PackedStringArray()
	_collect("res://game", PackedStringArray(["tres", "tscn"]), paths)
	if paths.is_empty():
		pass_test("no resources yet")
	for path in paths:
		assert_not_null(load(path), "loads: %s" % path)
