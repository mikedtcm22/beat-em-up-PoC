extends Node
## Writes tests/fixtures/motion/move_clip_hashes.json (see clip_hash.gd): a scene, so the autoloads the clips read
## exist (a `-s` script has none): `godot --headless res://tests/fixtures/motion/gen_clip_hashes.tscn --quit-after 5`.
## Run it only to add a clip: the table is the proof that a clip did not move (tests/test_motion_m4.gd).

const ClipHash := preload("res://tests/fixtures/motion/clip_hash.gd")


func _ready() -> void:
	var table := ClipHash.compute()
	if table.is_empty():
		push_error("nothing to write")
		get_tree().quit(1)
		return
	var file := FileAccess.open(ClipHash.TABLE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % ClipHash.TABLE_PATH)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(table, "\t", true) + "\n")
	file.close()
	print("wrote %d move hashes and %d named hashes to %s" % [table.moves.size(), table.named.size(), ClipHash.TABLE_PATH])
	get_tree().quit(0)
