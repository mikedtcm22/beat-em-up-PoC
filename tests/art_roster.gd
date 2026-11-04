extends RefCounted
## The art roster (Milestone 6, CHAIN; M6 plan D26): one file per character, tests/fixtures/art/roster/<id>.json, drives every
## row of test_m4_done_when (A1-A12), test_art_punk's checks, the strain runs (art_strain.gd) and test_art_roster. A new
## character adds its own file and its own tests/fixtures/strain/<id>.json and changes no test.
##
## A roster file is `{"id", "art", "actor_scene", "height_m", "budget", "meshes", "moves", "ratchets", "notes"}`:
## - `art`: the CharacterArt (game/actors/art/<id>_art.tres); `actor_scene`: the scene whose rig wears it;
## - `height_m`: the body_height the art is checked at (the art is authored at 1.8 m and scaled, M6 D15);
## - `budget`: SPEC §10's triangles (15000, the boss 30000: SPEC §10 has a Boss row);
## - `meshes`: the GLB's mesh names; `moves`: the character's own move ids (game/combat/moves/<id>.tres) that A7's strain run,
##   A9's framing at 1 m and A10 play, in place of the Punk's three;
## - `ratchets`: only what departs from the plan's bar, each with its reason in `notes` (a ratchet only moves down):
##   `a5_extent` (the fist box's extent, 0.2), `a6` ({torso, legs, head}: the vertex shares held in place of 95%),
##   `a9_cells` (cells that differ, 3%), `a9_lens_pp` (the lens-share gap, 4 points: a number, or {"*": default, "<move> pitch
##   <+/-n>": that pose's}), `a9_strike_art_share_min` (the twin of a loosened lens gap: the striking art keeps this share of the
##   view), `anchor_m` ({head, torso, leg}, 2 cm), `stretch_m` (the longest edge growth in view, 2 cm), `variant_stretch_m`,
##   `slide_m` (a planted walk step's slide, 2 cm);
## - `strain`: tests/fixtures/strain/<id>.json = {"whole": {in_bar_min, high_max, low_min, max_max, min_min, flex_share_max},
##   "clips": {"<clip>": {high, low, max, min, bad}}}, written by tests/fixtures/strain/gen_strain_ratchet.tscn.
## The player is not in the roster: his row and his *_PLAYER constants stay in test_m4_done_when (ARM changes them).

const ROSTER_DIR := "res://tests/fixtures/art/roster"
const STRAIN_DIR := "res://tests/fixtures/strain"
## The plan's bars, what a roster file that names no ratchet is held to.
const BARS := {
	a5_extent = 0.2,
	a9_cells = 0.03,
	a9_lens_pp = {"*": 0.04},
	a9_strike_art_share_min = 0.0,
	anchor_m = {head = 0.02, torso = 0.02, leg = 0.02},
	stretch_m = 0.02,
	slide_m = 0.02,
}
## The whole-run strain figures a strain file must hold.
const STRAIN_KEYS: Array[String] = ["in_bar_min", "high_max", "low_min", "max_max", "min_min", "flex_share_max"]

static var _rows: Dictionary[String, Dictionary] = {}


## The roster's ids: the Punk first (the oldest row, ArtStrain.SHIPPED[0]), then the others by name.
static func ids() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ROSTER_DIR)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".json"):
			out.append(file.get_basename())
	out.sort()
	if out.has("punk"):
		out.erase("punk")
		out.push_front("punk")
	return out


## The roster row of `id` with every default filled in (a Dictionary with the keys above; `ratchets` complete). Empty when the
## file is missing or does not parse.
static func row(id: String) -> Dictionary:
	if _rows.has(id):
		return _rows[id]
	var path := "%s/%s.json" % [ROSTER_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var out: Dictionary = (parsed as Dictionary).duplicate(true)
	out.height_m = float(out.get("height_m", 1.8))
	out.budget = int(out.get("budget", 15000))
	out.meshes = out.get("meshes", ["Body"])
	out.moves = out.get("moves", [])
	out.notes = String(out.get("notes", ""))
	var given: Dictionary = out.get("ratchets", {})
	var ratchets: Dictionary = (BARS as Dictionary).duplicate(true)
	for key: String in given:
		ratchets[key] = given[key]
	if not ratchets.has("variant_stretch_m"):
		ratchets.variant_stretch_m = ratchets.stretch_m
	if not ratchets.has("a6"):
		ratchets.a6 = null
	out.ratchets = ratchets
	_rows[id] = out
	return out


## Every roster row, in ids() order.
static func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ids():
		out.append(row(id))
	return out


## The problems of a roster row's own data (a missing key, an art that is not there): empty = well formed.
static func problems(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var r := row(id)
	if r.is_empty():
		out.append("%s: no roster file" % id)
		return out
	for key: String in ["id", "art", "actor_scene", "height_m", "budget", "meshes", "moves", "ratchets"]:
		if not r.has(key):
			out.append("%s: no `%s`" % [id, key])
	if String(r.get("id", "")) != id:
		out.append("%s: the file's id is %s" % [id, r.get("id", "")])
	for key: String in ["art", "actor_scene"]:
		if not ResourceLoader.exists(String(r.get(key, ""))):
			out.append("%s: %s %s does not exist" % [id, key, r.get(key, "")])
	for move_id: String in r.get("moves", []):
		if not ResourceLoader.exists(move_path(move_id)):
			out.append("%s: move %s does not exist" % [id, move_id])
	return out


static func move_path(move_id: String) -> String:
	return "res://game/combat/moves/%s.tres" % move_id


## The MoveData of a roster row's `moves`.
static func moves_of(r: Dictionary) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for move_id: String in r.moves:
		out.append(load(move_path(move_id)) as MoveData)
	return out


## The lens-share gap `r` is held to at the pose `label` ("<move id> pitch +8", or "idle pitch +8").
static func lens_bar(r: Dictionary, label: String) -> float:
	var bars: Variant = r.ratchets.a9_lens_pp
	if bars is Dictionary:
		return float((bars as Dictionary).get(label, (bars as Dictionary).get("*", BARS.a9_lens_pp["*"])))
	return float(bars)


## The GLB path of a roster row's art.
static func glb_of(r: Dictionary) -> String:
	var art := load(r.art) as CharacterArt
	return art.scene.resource_path if art != null and art.scene != null else ""


## The strain file of `id`: {whole, clips}, or an empty Dictionary.
static func strain_file(id: String) -> Dictionary:
	var path := "%s/%s.json" % [STRAIN_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## A roster row as an ArtStrain.SHIPPED row: {name, path, art, player, budget, in_bar_min, high_max, ...}, or empty with no strain file.
static func shipped_row(id: String) -> Dictionary:
	var r := row(id)
	var file := strain_file(id)
	if r.is_empty() or file.is_empty() or not file.has("whole"):
		return {}
	var out := {name = id, path = glb_of(r), art = String(r.art), player = false, budget = int(r.budget)}
	out.merge(file.whole)
	out.in_bar_min = int(out.in_bar_min)
	return out
