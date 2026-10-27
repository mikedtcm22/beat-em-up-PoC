extends GutTest
## Motion on the same frame data (F-motion, M4-plan Part A A20): the polish makes the idles, walks, flinches and
## get-ups breathe, ease and overlap, and never touches a move. This file holds the proof.
##
## The move clips are compared, key for key, with the hash table written before the polish landed
## (tests/fixtures/motion/move_clip_hashes.json, made by clip_hash.gd).

const ClipHash := preload("res://tests/fixtures/motion/clip_hash.gd")
const PUNK_MOVES: Array[String] = ["punk_jab", "punk_cross", "punk_shove"]
## The Kicker's, Thug's, Bruiser's and boss's moves (their files in game/combat/moves).
const ENEMY_MOVES: Array[String] = ["kicker_jump_kick", "kicker_sweep", "thug_pipe_1", "thug_pipe_2", "thug_pipe_3",
		"bruiser_smash", "bruiser_grab", "bruiser_headbutt", "boss_slam", "boss_charge", "boss_pound", "boss_grab"]

var _table: Dictionary = {}


func before_all() -> void:
	var file := FileAccess.open(ClipHash.TABLE_PATH, FileAccess.READ)
	if file != null:
		_table = JSON.parse_string(file.get_as_text())


# --- A20: the move clips never change ---------------------------------------------------------


func test_the_hash_table_covers_every_move_file_and_every_move_id() -> void:
	assert_false(_table.is_empty(), "the hash table is committed")
	var paths := ClipHash.move_paths()
	assert_gte(paths.size(), 41, "every move resource is hashed")
	var stems := {}
	for path: String in paths:
		stems[path.get_file().get_basename()] = true
		for stance: StringName in ClipHash.STANCES:
			for scale: float in ClipHash.SCALES:
				assert_true(_table.moves.has("%s|%s|%s" % [path.get_file().get_basename(), stance, scale]),
						"%s (%s, %s) is in the table" % [path.get_file(), stance, scale])
	for id: String in PUNK_MOVES + ENEMY_MOVES:
		assert_true(stems.has(id), "the enemy move %s is hashed" % id)
	# Every id PlaceholderAnims.MOVE_IDS names is the anim of some hashed move.
	var anims := {}
	for path: String in paths:
		var move := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveData
		anims[move.get_anim()] = true
	for id: StringName in PlaceholderAnims.MOVE_IDS:
		assert_true(anims.has(id), "MOVE_IDS %s has a hashed move" % id)


func test_every_move_clip_is_identical_to_the_hash_table() -> void:
	var now := ClipHash.compute()
	var changed := PackedStringArray()
	for key: String in _table.moves:
		if now.moves.get(key, "") != _table.moves[key]:
			changed.append(key)
	assert_eq(now.moves.size(), _table.moves.size(), "the same set of move clips")
	assert_true(changed.is_empty(), "no move clip changed key for key (A20); changed: %s" % [changed])
