class_name TrimSheet
extends RefCounted
## The kit's trim sheet and its strip table (Milestone 6, KIT): `assets/export/kit/trim_sheet.png` and
## `trim_strips.json`, both written by tools/gen_trim.gd from assets/source/kit/trim_layout.json. The
## table says, per strip, its row in the sheet, its period in metres and its flags; KitMesh asks it
## for a strip's index (the vertex colour's alpha) and ToonMaterials.trim() feeds it to the shader.

const SHEET_PATH := "res://assets/export/kit/trim_sheet.png"
const STRIPS_PATH := "res://assets/export/kit/trim_strips.json"
## The street's ground tile (FB-GROUND): one picture sampled in world metres by every face on a `ground` strip.
const GROUND_PATH := "res://assets/export/kit/ground_sheet.png"
## The trailer look profile's own sheets (Milestone 7, T15; tools/gen_trailer_kit.py): the same 16 strips under the same names and
## rows as M6's, laid out for the trailer's painting, and a ground tile with crack lines and puddles. The profile selects them
## (`texture()`, `table()` and the others answer for the running profile); the M6 files above are never touched.
const TRAILER_SHEET_PATH := "res://assets/export/kit/trailer_trim_sheet.png"
const TRAILER_STRIPS_PATH := "res://assets/export/kit/trailer_trim_strips.json"
const TRAILER_GROUND_PATH := "res://assets/export/kit/trailer_ground_sheet.png"
## The shader's `strips` array holds this many rows.
const ROWS := 16

static var _table: Dictionary = {}
static var _by_name: Dictionary = {}
static var _trailer_table: Dictionary = {}
static var _trailer_by_name: Dictionary = {}
static var _wired: bool = false


## Whether the running look profile is "trailer" (its sheets are the ones every accessor below answers with).
static func is_trailer() -> bool:
	return LookProfile.current() == LookProfile.Id.TRAILER


## The table: `sheet_px`, `row_px`, `tile_m` and `strips` (each {name, index, v0, vh, period_m,
## scissor, ink_only}) of the running look profile's sheet. The trailer's strips also carry `u_m` (the metres of U one
## repeat of the strip covers), `u_snap_m`, `flip`, `vary_v` and `vary_tint` (what a variant may move: see `variation()`).
## Empty when the file is missing.
static func table() -> Dictionary:
	if is_trailer():
		return _read_table(TRAILER_STRIPS_PATH, true)
	return _read_table(STRIPS_PATH, false)


static func _read_table(path: String, trailer: bool) -> Dictionary:
	var held := _trailer_table if trailer else _table
	if held.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			held = parsed
			var names := {}
			for entry: Dictionary in held.get("strips", []):
				names[StringName(entry.name)] = entry
			if trailer:
				_trailer_table = held
				_trailer_by_name = names
			else:
				_table = held
				_by_name = names
		else:
			push_warning("TrimSheet: %s is missing or unreadable" % path)
	return held


## The strip named `strip_name`, or an empty dictionary.
static func strip(strip_name: StringName) -> Dictionary:
	table()
	return (_trailer_by_name if is_trailer() else _by_name).get(strip_name, {})


## The row of `strip_name` (0 for an unknown one, with a warning).
static func index(strip_name: StringName) -> int:
	var entry := strip(strip_name)
	if entry.is_empty():
		push_warning("TrimSheet: no strip '%s'" % strip_name)
		return 0
	return int(entry.index)


## Whether `strip_name` is a ground strip (the asphalt): its faces sample the ground tile in world metres.
static func is_ground(strip_name: StringName) -> bool:
	return bool(strip(strip_name).get("ground", false))


## The metres one side of the ground tile covers as painted (the tile's own, `ground_m_per_tile` is the live value).
static func ground_tile_m() -> float:
	return float(table().get("ground", {}).get("tile_m", 8.0))


## Whether `strip_name` is an alpha-scissor strip (the chain-link's): its faces wear ToonMaterials.trim_scissor().
static func is_scissor(strip_name: StringName) -> bool:
	return bool(strip(strip_name).get("scissor", false))


## Every strip's name, in row order.
static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Dictionary in table().get("strips", []):
		out.append(StringName(entry.name))
	return out


## The metres of one strip repeat in V.
static func period_m(strip_name: StringName) -> float:
	return float(strip(strip_name).get("period_m", 1.0))


## The shader's `strips` uniform: per row (v0, vh, period_m, flags: 1 scissor, 2 ink only, 4 ground).
static func uniform_rows() -> PackedVector4Array:
	var rows := PackedVector4Array()
	rows.resize(ROWS)
	for entry: Dictionary in table().get("strips", []):
		var flags := (1.0 if bool(entry.scissor) else 0.0) + (2.0 if bool(entry.ink_only) else 0.0) + (4.0 if bool(entry.get("ground", false)) else 0.0)
		rows[int(entry.index)] = Vector4(float(entry.v0), float(entry.vh), float(entry.period_m), flags)
	return rows


## The ground tile's texture (imported, with mipmaps), the running profile's.
static func ground_texture() -> Texture2D:
	return load(TRAILER_GROUND_PATH if is_trailer() else GROUND_PATH) as Texture2D


## The sheet's texture (imported, with mipmaps), the running profile's.
static func texture() -> Texture2D:
	return load(TRAILER_SHEET_PATH if is_trailer() else SHEET_PATH) as Texture2D


## Puts the running profile's sheets on the two shared trim materials (`ToonMaterials.trim()`, `trim_scissor()`): the trim
## texture, the ground tile and the strip rows. A flip of `look_profile` calls it (`ensure_wired()`); it touches no other
## uniform, so ToonMaterials' own values (bands, ink cut, tile size) stay as they are.
static func apply_profile() -> void:
	for material: ShaderMaterial in [ToonMaterials.trim(), ToonMaterials.trim_scissor()]:
		material.set_shader_parameter(&"trim_tex", texture())
		material.set_shader_parameter(&"ground_tex", ground_texture())
		material.set_shader_parameter(&"strips", uniform_rows())


## Connects the profile flip to `apply_profile()` once (KitMesh asks before it builds a mesh).
static func ensure_wired() -> void:
	if _wired:
		return
	_wired = true
	Tuning.changed.connect(_on_tuning_changed)


static func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile":
		apply_profile()


# --- Variants (trailer profile) -----------------------------------------------------------------


## The variant of a block or piece at `pos` (its position in its parent, which is what the scene file fixes): a stable hash
## of the position into [0, Tuning's trailer_kit_variants). -1 under any other profile (no variation: M6's meshes).
static func variant_for(pos: Vector3) -> int:
	if not is_trailer():
		return -1
	var count := maxi(Tuning.data.trailer_kit_variants, 1)
	var h := _mix(_mix(_mix(0, roundi(pos.x * 100.0)), roundi(pos.y * 100.0)), roundi(pos.z * 100.0))
	return h % count


## A 32-bit integer hash of two integers (a Murmur-style finalizer): the same everywhere, every run.
static func _mix(a: int, b: int) -> int:
	var h := (a * 0x9E3779B1 + b * 0x85EBCA6B + 0x27D4EB2F) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	return h ^ (h >> 15)


## A number in [0, 1) from `seed` and a `salt`.
static func _unit(seed_value: int, salt: int) -> float:
	return float(_mix(seed_value, salt) & 0xFFFFFF) / 16777216.0


## How variant `variant` moves face number `face_n` of a mesh on strip `strip_name`: {u, v, flip, tint}. `u` and `v` are the
## offsets of the face's UVs in the strip's own metres (U inside `u_m`, snapped to `u_snap_m` where the strip says so; V inside
## `period_m` where `vary_v`), `flip` mirrors U, `tint` is the vertex colour's rgb multiplier (Tuning's trailer_kit_tint_jitter
## about white, warm or cool). Every strip is seamless, so any offset joins; the strip's `vary_*` flags keep the ones that
## must line up (a window pane's cell, the chain-link's lattice) where they are.
static func variation(strip_name: StringName, variant: int, face_n: int) -> Dictionary:
	var entry := strip(strip_name)
	var seed_value := _mix(variant + 1, face_n * 31 + int(entry.get("index", 0)))
	var out := {u = 0.0, v = 0.0, flip = false, tint = Color.WHITE}
	if variant < 0 or entry.is_empty():
		return out
	var u_m := float(entry.get("u_m", 4.0))
	var snap := float(entry.get("u_snap_m", 0.0))
	var offset := _unit(seed_value, 1) * u_m
	out.u = floorf(offset / snap) * snap if snap > 0.0 else offset
	out.flip = bool(entry.get("flip", false)) and _unit(seed_value, 2) < 0.5
	if bool(entry.get("vary_v", false)):
		out.v = _unit(seed_value, 3) * float(entry.get("period_m", 1.0))
	if bool(entry.get("vary_tint", false)):
		var jitter := Tuning.data.trailer_kit_tint_jitter
		var warm := (_unit(seed_value, 4) * 2.0 - 1.0) * jitter
		var level := (_unit(seed_value, 5) * 2.0 - 1.0) * jitter
		out.tint = Color(1.0 + level + warm, 1.0 + level, 1.0 + level - warm)
	return out
