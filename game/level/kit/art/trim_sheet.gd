class_name TrimSheet
extends RefCounted
## The kit's trim sheet and its strip table (Milestone 6, KIT): `assets/export/kit/trim_sheet.png` and
## `trim_strips.json`, both written by tools/gen_trim.gd from assets/source/kit/trim_layout.json. The
## table says, per strip, its row in the sheet, its period in metres and its flags; KitMesh asks it
## for a strip's index (the vertex colour's alpha) and ToonMaterials.trim() feeds it to the shader.

const SHEET_PATH := "res://assets/export/kit/trim_sheet.png"
const STRIPS_PATH := "res://assets/export/kit/trim_strips.json"
## The shader's `strips` array holds this many rows.
const ROWS := 16

static var _table: Dictionary = {}
static var _by_name: Dictionary = {}


## The table: `sheet_px`, `row_px`, `tile_m` and `strips` (each {name, index, v0, vh, period_m,
## scissor, ink_only}). Empty when the file is missing.
static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRIPS_PATH))
		if parsed is Dictionary:
			_table = parsed
			for entry: Dictionary in _table.get("strips", []):
				_by_name[StringName(entry.name)] = entry
		else:
			push_warning("TrimSheet: %s is missing or unreadable" % STRIPS_PATH)
	return _table


## The strip named `strip_name`, or an empty dictionary.
static func strip(strip_name: StringName) -> Dictionary:
	table()
	return _by_name.get(strip_name, {})


## The row of `strip_name` (0 for an unknown one, with a warning).
static func index(strip_name: StringName) -> int:
	var entry := strip(strip_name)
	if entry.is_empty():
		push_warning("TrimSheet: no strip '%s'" % strip_name)
		return 0
	return int(entry.index)


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


## The shader's `strips` uniform: per row (v0, vh, period_m, flags: 1 scissor, 2 ink only).
static func uniform_rows() -> PackedVector4Array:
	var rows := PackedVector4Array()
	rows.resize(ROWS)
	for entry: Dictionary in table().get("strips", []):
		var flags := (1.0 if bool(entry.scissor) else 0.0) + (2.0 if bool(entry.ink_only) else 0.0)
		rows[int(entry.index)] = Vector4(float(entry.v0), float(entry.vh), float(entry.period_m), flags)
	return rows


## The sheet's texture (imported, with mipmaps).
static func texture() -> Texture2D:
	return load(SHEET_PATH) as Texture2D
