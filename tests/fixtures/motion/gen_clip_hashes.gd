extends SceneTree
## Writes tests/fixtures/motion/move_clip_hashes.json (see clip_hash.gd): `godot --headless -s
## tests/fixtures/motion/gen_clip_hashes.gd --quit-after 5`.

const ClipHash := preload("res://tests/fixtures/motion/clip_hash.gd")


func _init() -> void:
	var table := ClipHash.compute()
	var file := FileAccess.open(ClipHash.TABLE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % ClipHash.TABLE_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(table, "\t", true) + "\n")
	file.close()
	print("wrote %d move hashes and %d named hashes to %s" % [table.moves.size(), table.named.size(), ClipHash.TABLE_PATH])
	quit(0)
