extends RefCounted
## Key-for-key hashes of the placeholder clips (Milestone 4, F-motion; not a test script). A20: F-motion never changes a
## move clip, so every clip PlaceholderAnims builds for a move is hashed, key for key, into
## tests/fixtures/motion/move_clip_hashes.json before the polish lands, and tests/test_motion_m4.gd compares
## against that table. The table also holds the named clips as M3 built them: the polish may change only the clips A20
## names (PlaceholderAnims.POLISHED_IDS), and with the polish off every named clip is the M3 clip again.
##
## `godot --headless res://tests/fixtures/motion/gen_clip_hashes.tscn --quit-after 5` rewrites the table (a scene: a `-s` script has no
## autoloads, which the polished clips read). Rewrite it only to
## add a clip: the table is the proof that a clip did not move.

const MOVES_DIR := "res://game/combat/moves"
const TABLE_PATH := "res://tests/fixtures/motion/move_clip_hashes.json"
## Rig sizes a clip is built for (the Hips position track carries the scale): the Punk's and the boss's.
const SCALES: Array[float] = [1.0, 1.278]
const STANCES: Array[StringName] = [&"boxer", &"relaxed"]
## Why a named hash is not the M3 clip's any more: the table is rewritten only for a reason, and each reason is kept in the table's
## `notes` (with the M3 hashes it replaced), so the file says what moved and why.
const NOTES := {
	"stagger_back": "M4 call 24 (the lead's, final review finding final-v2-01; a departure from A20's frozen-clip list, not from the SPEC): stagger_back_a and stagger_back_b are re-posed like stagger_right (upper arms about 40 degrees off the body then 28, elbows folded to 90-110 degrees, forearms forward and raised), so the skinned Punk's arms never go straight and horizontal, the rig's bind pose, after the third knee, on a grab release and in the long take. Only the arm tracks changed. The M3 hashes it replaced: boxer|1.0 5d4f1e7a896c, boxer|1.278 a770c027ff85, relaxed|1.0 49ca3e4c03f6, relaxed|1.278 b0aa3f3f405b.",
}


## `{moves: {"<file>|<stance>|<scale>": hash}, named: {"<id>|<stance>|<scale>": hash}, notes: NOTES}` for every move file in
## MOVES_DIR and every id in PlaceholderAnims.ANIM_IDS. A move's entry hashes its clip four ways (plain, mirrored,
## from its charge, both), as a rig builds them.
static func compute() -> Dictionary:
	var moves := {}
	for path: String in move_paths():
		var move := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveData
		if move == null:
			continue
		for stance: StringName in STANCES:
			for scale: float in SCALES:
				var text := ""
				for mirrored: bool in [false, true]:
					for from_charge: bool in [false, true]:
						text += clip_text(PlaceholderAnims.build_move(move, scale, mirrored, from_charge, stance))
				moves["%s|%s|%s" % [path.get_file().get_basename(), stance, scale]] = sha(text)
	var named := {}
	for id: StringName in PlaceholderAnims.ANIM_IDS:
		for stance: StringName in STANCES:
			for scale: float in SCALES:
				named["%s|%s|%s" % [id, stance, scale]] = sha(clip_text(named_clip(id, scale, stance)))
	return {moves = moves, named = named, notes = NOTES}


## The named clip as M3 built it (the polish off).
static func named_clip(id: StringName, scale: float, stance: StringName) -> Animation:
	return PlaceholderAnims.build_named(id, scale, stance, PlaceholderAnims.Life.off())


## Every move resource in MOVES_DIR (sorted).
static func move_paths() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(MOVES_DIR)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".tres"):
			out.append(MOVES_DIR.path_join(file))
	out.sort()
	return out


## The clip as text: its length and loop mode, then every track's type, path, interpolation and keys (time and value,
## rounded to a micro-unit).
static func clip_text(anim: Animation) -> String:
	var out := "L%.6f M%d\n" % [anim.length, anim.loop_mode]
	for t: int in anim.get_track_count():
		out += "T%d %s i%d w%s n%d\n" % [anim.track_get_type(t), anim.track_get_path(t),
				anim.track_get_interpolation_type(t), anim.track_get_interpolation_loop_wrap(t),
				anim.track_get_key_count(t)]
		for k: int in anim.track_get_key_count(t):
			var value: Variant = anim.track_get_key_value(t, k)
			var parts := PackedFloat64Array()
			if value is Quaternion:
				var q: Quaternion = value
				parts = PackedFloat64Array([q.x, q.y, q.z, q.w])
			elif value is Vector3:
				var v: Vector3 = value
				parts = PackedFloat64Array([v.x, v.y, v.z])
			out += "%.6f" % anim.track_get_key_time(t, k)
			for x: float in parts:
				# Never "-0.000000": a sign flip of nothing is not a change.
				out += " %.6f" % (x + 0.0 if absf(x) >= 5e-7 else 0.0)
			out += "\n"
	return out


## SHA-256 of `text` (hex).
static func sha(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()
