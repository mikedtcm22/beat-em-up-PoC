extends Node
## Live tuning values (autoload "Tuning"). Read values as `Tuning.data.<name>`; they may
## change at any time, so read them when needed rather than caching them (or re-read them
## on `changed`).
##
## Milestone 2 (Spec §11) adds live move editing and presets, which the F1 tuning panel
## (game/ui/tuning_panel.gd) drives:
## - Moves: every MoveData in MOVES_DIR is loaded once and kept for the session, so edits to
##   those shared resources apply on each move's next use and survive a restart (R). The
##   fields in MOVE_GROUPS are editable (set_move_value()); the shipped values come from a
##   fresh load of each .tres.
## - Presets: JSON files named `<name>.json` (names lower case, so one name is one file on
##   every OS), saved and loaded in `user_dir` (USER_DIR) and exported to `export_dir`
##   (EXPORT_DIR, writable when the game runs from the project folder). A preset holds every
##   TuningData value outside PRESET_SKIPPED_GROUPS (the F4 cheats are session state) plus
##   the move fields that differ from the shipped .tres:
##   `{"preset": name, "format": 1, "tuning": {property: value}, "moves": {id: {field: value}}}`,
##   vectors and colors as arrays. Loading starts from the shipped defaults, so values a
##   preset lacks (tunables added later) keep their defaults; values outside their range hint
##   are clamped and unknown enum ids skipped. EXPORT_DIR/default.json is the shipped
##   defaults; `godot --headless -s tools/gen_default_preset.gd` regenerates it.

## Emitted after every edit. `property` is the TuningData property; &"" after a preset load,
## a reset or apply() (anything may have changed); "moves/<move id>/<field>" for a move edit.
signal changed(property: StringName)

const USER_DIR := "user://tuning"
const EXPORT_DIR := "res://tuning"
const MOVES_DIR := "res://game/combat/moves"
## The shipped defaults (EXPORT_DIR only: a user preset can't take this name).
const DEFAULT_PRESET := "default"
## The user preset backup_unsaved() keeps unsaved values in before a load or reset replaces
## them (overwritten each time, so it can't be saved over by hand).
const BACKUP_PRESET := "_backup"
## TuningData groups presets leave out: the F4 cheats are session state, so a preset never
## turns one on and loading or resetting never turns one off.
const PRESET_SKIPPED_GROUPS: PackedStringArray = ["Debug"]
## Preset file layout version.
const PRESET_FORMAT := 1
## The MoveData groups the panel edits and presets override: frame data, damage, knockback,
## hitstun, reaction, blocking, movement and the camera offsets. Hitboxes and combo branches
## are the move's structure, not tuning.
const MOVE_GROUPS: PackedStringArray = [
	"Frames (60 Hz)", "Damage and reaction", "Blocking", "Movement", "Camera",
]
## Value types presets store and the panel edits.
const VALUE_TYPES: Array[int] = [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
	TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR,
]
## Prefix of a move edit's `changed` name.
const MOVE_PREFIX := "moves/"

static var _tuning_props: Array[Dictionary] = []
static var _preset_props: Array[Dictionary] = []
static var _preset_names: Dictionary[StringName, bool] = {}
static var _move_props: Array[Dictionary] = []

var data: TuningData = TuningData.new()
## Problems met by the last apply_preset() or load: unknown names and unreadable values,
## which were skipped, and values clamped into their range.
var last_warnings: PackedStringArray = []
## Where user presets are saved and loaded (tests point it at a scratch folder).
var user_dir: String = USER_DIR
## Where export_preset() writes and shipped presets are read (tests point it elsewhere).
var export_dir: String = EXPORT_DIR

## True after an edit no saved, exported or loaded preset holds (see backup_unsaved()).
var _unsaved: bool = false

var _defaults: TuningData
var _moves: Dictionary[StringName, MoveData] = {}
var _move_paths: Dictionary[StringName, String] = {}
## Move id -> {field: shipped value}.
var _shipped: Dictionary[StringName, Dictionary] = {}


func set_value(property: StringName, value: Variant) -> void:
	data.set(property, value)
	if is_preset_property(property):
		_unsaved = true
	changed.emit(property)


## Replace all values at once (tests). Emits `changed` with an empty name.
func apply(new_data: TuningData) -> void:
	data = new_data
	_unsaved = true
	changed.emit(&"")


## The shipped TuningData defaults (do not edit).
func defaults() -> TuningData:
	if _defaults == null:
		_defaults = TuningData.new()
	return _defaults


# --- Property lists --------------------------------------------------------------------


## Every exported TuningData property in declaration order: its property-list entry plus
## "group" (the @export_group it sits in, "" before the first).
static func tuning_properties() -> Array[Dictionary]:
	if _tuning_props.is_empty():
		_tuning_props = exported_properties(TuningData.new())
	return _tuning_props


## The TuningData properties a preset holds: tuning_properties() of the VALUE_TYPES, outside
## PRESET_SKIPPED_GROUPS.
static func preset_properties() -> Array[Dictionary]:
	if _preset_props.is_empty():
		for info: Dictionary in tuning_properties():
			if VALUE_TYPES.has(int(info.type)) and not PRESET_SKIPPED_GROUPS.has(str(info.group)):
				_preset_props.append(info)
				_preset_names[StringName(info.name)] = true
	return _preset_props


## True if TuningData property `property` is one a preset holds (preset_properties()).
static func is_preset_property(property: StringName) -> bool:
	preset_properties()
	return _preset_names.has(property)


## The editable MoveData fields (MOVE_GROUPS, VALUE_TYPES), with "group" like
## tuning_properties().
static func move_properties() -> Array[Dictionary]:
	if _move_props.is_empty():
		for info: Dictionary in exported_properties(MoveData.new()):
			if MOVE_GROUPS.has(str(info.group)) and VALUE_TYPES.has(int(info.type)):
				_move_props.append(info)
	return _move_props


## The script's exported properties of `object`, in declaration order, each entry a copy of
## its property-list dictionary with "group" (its @export_group, "" before the first) and
## "subgroup" (its @export_subgroup within that group, "" outside one) added.
static func exported_properties(object: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group := ""
	var subgroup := ""
	for info: Dictionary in object.get_property_list():
		var usage: int = info.usage
		if usage & PROPERTY_USAGE_CATEGORY:
			group = ""
			subgroup = ""
		elif usage & PROPERTY_USAGE_GROUP:
			group = str(info.name)
			subgroup = ""
		elif usage & PROPERTY_USAGE_SUBGROUP:
			subgroup = str(info.name)
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			var entry := info.duplicate()
			entry.group = group
			entry.subgroup = subgroup
			out.append(entry)
	return out


static func _property_info(list: Array[Dictionary], property: StringName) -> Dictionary:
	for info: Dictionary in list:
		if StringName(info.name) == property:
			return info
	return {}


# --- Moves ------------------------------------------------------------------------------


## Ids of every move in MOVES_DIR, sorted.
func move_ids() -> Array[StringName]:
	_ensure_moves()
	var ids: Array[StringName] = []
	ids.assign(_moves.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## The loaded (shared) MoveData for `id`, or null. Edits to it apply on its next use.
func get_move(id: StringName) -> MoveData:
	_ensure_moves()
	return _moves.get(id)


## Set one editable field of a move and emit `changed` ("moves/<id>/<field>").
func set_move_value(id: StringName, field: StringName, value: Variant) -> void:
	var move := get_move(id)
	if move == null or _property_info(move_properties(), field).is_empty():
		push_warning("Tuning: no editable move field %s/%s" % [id, field])
		return
	move.set(field, value)
	_unsaved = true
	changed.emit(StringName(MOVE_PREFIX + "%s/%s" % [id, field]))


## The value of `field` in the shipped .tres of move `id` (null if unknown).
func shipped_move_value(id: StringName, field: StringName) -> Variant:
	_ensure_moves()
	var shipped: Dictionary = _shipped.get(id, {})
	return shipped.get(field)


## {move id: {field: value}} for every editable field that differs from the shipped .tres.
func move_overrides() -> Dictionary:
	var out := {}
	for id: StringName in move_ids():
		var fields := move_override(id)
		if not fields.is_empty():
			out[id] = fields
	return out


## {field: value} for each editable field of move `id` that differs from its shipped .tres.
func move_override(id: StringName) -> Dictionary:
	var fields := {}
	var move := get_move(id)
	if move == null:
		return fields
	var shipped: Dictionary = _shipped.get(id, {})
	for info: Dictionary in move_properties():
		var field := StringName(info.name)
		if not values_equal(move.get(field), shipped.get(field)):
			fields[field] = move.get(field)
	return fields


## Put the shipped values back into move `id` and emit `changed` (&"").
func reset_move(id: StringName) -> void:
	_restore_move(id)
	_unsaved = true
	changed.emit(&"")


## Put the shipped values back into every move and emit `changed` (&"").
func reset_moves() -> void:
	for id: StringName in move_ids():
		_restore_move(id)
	_unsaved = true
	changed.emit(&"")


func _restore_move(id: StringName) -> void:
	var move := get_move(id)
	if move == null:
		return
	var shipped: Dictionary = _shipped.get(id, {})
	for field: StringName in shipped:
		move.set(field, shipped[field])


func _ensure_moves() -> void:
	if not _move_paths.is_empty():
		return
	for file: String in ResourceLoader.list_directory(MOVES_DIR):
		if file.get_extension() not in ["tres", "res"]:
			continue
		var path := MOVES_DIR.path_join(file)
		var move := load(path) as MoveData
		if move == null:
			continue
		var id := move.id if move.id != &"" else StringName(file.get_basename())
		_moves[id] = move
		_move_paths[id] = path
		# A fresh copy from disk holds the shipped values even if the shared one was edited.
		var fresh := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveData
		var shipped := {}
		for info: Dictionary in move_properties():
			var field := StringName(info.name)
			shipped[field] = (fresh if fresh else move).get(field)
		_shipped[id] = shipped


# --- Presets ----------------------------------------------------------------------------


## The current values as a preset dictionary (see the class docs).
func preset_dict(preset_name: String) -> Dictionary:
	var values := {}
	for info: Dictionary in preset_properties():
		values[str(info.name)] = encode_value(data.get(info.name))
	var moves := {}
	var overrides := move_overrides()
	for id: StringName in overrides:
		var fields := {}
		for field: StringName in overrides[id]:
			fields[String(field)] = encode_value(overrides[id][field])
		moves[String(id)] = fields
	return {"preset": preset_name, "format": PRESET_FORMAT, "tuning": values, "moves": moves}


## The shipped defaults as a preset dictionary (what EXPORT_DIR/default.json holds).
func default_preset_dict() -> Dictionary:
	var values := {}
	for info: Dictionary in preset_properties():
		values[str(info.name)] = encode_value(defaults().get(info.name))
	return {"preset": DEFAULT_PRESET, "format": PRESET_FORMAT, "tuning": values, "moves": {}}


## Load a preset dictionary: every value starts from the shipped defaults (TuningData and
## moves), then takes the preset's. Unknown names, unreadable values and enum ids the hint
## lacks are skipped, and numbers outside their range hint clamped (_checked()), each listed
## in `last_warnings`. PRESET_SKIPPED_GROUPS (the cheats) are left as they are, even if the
## preset holds them. Emits `changed` (&"") once.
func apply_preset(preset: Dictionary) -> Error:
	last_warnings.clear()
	var tuning: Variant = preset.get("tuning", {})
	var moves: Variant = preset.get("moves", {})
	if not tuning is Dictionary or not moves is Dictionary:
		last_warnings.append("not a tuning preset")
		return ERR_INVALID_DATA
	var values := defaults().duplicate() as TuningData
	for key: Variant in tuning:
		var info := _property_info(tuning_properties(), StringName(str(key)))
		if info.is_empty():
			last_warnings.append("unknown tunable %s" % key)
			continue
		if not is_preset_property(StringName(info.name)):
			continue  # a cheat (PRESET_SKIPPED_GROUPS), from a preset saved before they were left out
		var value: Variant = _checked(info, decode_value(tuning[key], int(info.type)), str(key))
		if value == null:
			last_warnings.append("unreadable value for %s" % key)
			continue
		values.set(info.name, value)
	for info: Dictionary in preset_properties():
		data.set(info.name, values.get(info.name))
	for id: StringName in move_ids():
		_restore_move(id)
	for id: Variant in moves:
		var move := get_move(StringName(str(id)))
		var fields: Variant = moves[id]
		if move == null or not fields is Dictionary:
			last_warnings.append("unknown move %s" % id)
			continue
		for key: Variant in fields:
			var info := _property_info(move_properties(), StringName(str(key)))
			var label := "%s/%s" % [id, key]
			var value: Variant = _checked(info, decode_value(fields[key], int(info.type)), label) if not info.is_empty() else null
			if value == null:
				last_warnings.append("skipped %s" % label)
				continue
			move.set(info.name, value)
	_unsaved = false
	changed.emit(&"")
	return OK


## Every preset value and every move back to the shipped defaults (the cheats stay as they
## are). Emits `changed` (&"").
func reset_to_default() -> void:
	apply_preset(default_preset_dict())


## True when every value a preset holds (and every move) equals the shipped defaults.
func is_default() -> bool:
	for info: Dictionary in preset_properties():
		if not values_equal(data.get(info.name), defaults().get(info.name)):
			return false
	return move_overrides().is_empty()


## True after an edit that no preset saved, exported or loaded since holds.
func has_unsaved() -> bool:
	return _unsaved


## Keep the current values as the user preset BACKUP_PRESET when they hold edits no saved,
## exported or loaded preset holds, before a load or reset replaces them. True if it wrote one.
func backup_unsaved() -> bool:
	if not _unsaved or is_default():
		return false
	return write_preset_file(user_dir.path_join(BACKUP_PRESET + ".json"), preset_dict(BACKUP_PRESET)) == OK


## Save the current values as `user_dir`/<name>.json. Refuses (ERR_ALREADY_IN_USE) the
## reserved names (is_reserved_preset_name()).
func save_preset(preset_name: String) -> Error:
	if is_reserved_preset_name(preset_name):
		return ERR_ALREADY_IN_USE
	return _write_named(user_dir, preset_name)


## Write the current values to `export_dir`/<name>.json (a res:// preset to commit). Refuses
## (ERR_INVALID_PARAMETER) to write "default", in any case, unless the values are the
## shipped defaults.
func export_preset(preset_name: String) -> Error:
	if sanitize_preset_name(preset_name) == DEFAULT_PRESET and not is_default():
		return ERR_INVALID_PARAMETER
	return _write_named(export_dir, preset_name)


## Load preset `<name>`: the user's copy (`user_dir`) if there is one, else the shipped one
## (`export_dir`). "default" is always the shipped one.
func load_preset(preset_name: String) -> Error:
	var clean := sanitize_preset_name(preset_name)
	var dirs: Array[String] = [export_dir]
	if clean != DEFAULT_PRESET:
		dirs.push_front(user_dir)
	for dir: String in dirs:
		var path := dir.path_join(clean + ".json")
		if FileAccess.file_exists(path):
			return load_preset_file(path)
	return ERR_FILE_NOT_FOUND


func load_preset_file(path: String) -> Error:
	var preset := read_preset_file(path)
	if preset.is_empty():
		last_warnings = PackedStringArray(["could not read %s" % path])
		return ERR_PARSE_ERROR
	return apply_preset(preset)


## Saved and shipped presets: [{name, path, shipped}], user presets first, each by name. A
## user "default" (from before the name was reserved) is left out: "default" is the shipped one.
func list_presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dir: String in [user_dir, export_dir]:
		var names: Array[String] = []
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file: String in DirAccess.get_files_at(dir):
			if file.get_extension() == "json":
				names.append(file.get_basename())
		names.sort()
		for preset_name: String in names:
			if dir == user_dir and preset_name.to_lower() == DEFAULT_PRESET:
				continue
			out.append({name = preset_name, path = dir.path_join(preset_name + ".json"), shipped = dir == export_dir})
	return out


## A file-safe preset name: trimmed and lower case (one name is one file on every OS, also
## on case-insensitive disks), with spaces and anything outside [a-z0-9_-] as "_".
static func sanitize_preset_name(text: String) -> String:
	var out := ""
	for c: String in text.strip_edges().to_lower():
		var code := c.unicode_at(0)
		var ok := (code >= 48 and code <= 57) or (code >= 97 and code <= 122) or c == "_" or c == "-"
		out += c if ok else "_"
	return out


## True for the names a user preset can't take: DEFAULT_PRESET (the shipped defaults) and
## BACKUP_PRESET (backup_unsaved() overwrites it), in any case.
static func is_reserved_preset_name(preset_name: String) -> bool:
	return sanitize_preset_name(preset_name) in [DEFAULT_PRESET, BACKUP_PRESET]


## Write `preset` to `path` as tab-indented JSON in declaration order.
static func write_preset_file(path: String, preset: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(preset, "\t", false) + "\n")
	file.close()
	return OK


## The preset dictionary in the JSON file at `path`, or {} if it can't be read.
static func read_preset_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_named(dir: String, preset_name: String) -> Error:
	var clean := sanitize_preset_name(preset_name)
	if clean.is_empty():
		return ERR_INVALID_PARAMETER
	var err := write_preset_file(dir.path_join(clean + ".json"), preset_dict(clean))
	if err == OK:
		_unsaved = false
	return err


## `value` (decoded, or null) checked against the property-list entry's hint: a number past
## a range hint's end is clamped to it (unless the hint's or_greater / or_less allows that
## side), noted in last_warnings as `label`; an enum id the hint lacks gives null.
func _checked(info: Dictionary, value: Variant, label: String) -> Variant:
	if not (value is int or value is float):
		return value
	var hint: int = info.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = info.get("hint_string", "")
	if hint == PROPERTY_HINT_ENUM:
		return value if enum_ids(hint_string).has(int(value)) else null
	var parts := hint_string.split(",")
	if hint != PROPERTY_HINT_RANGE or parts.size() < 2 or not parts[0].strip_edges().is_valid_float() \
			or not parts[1].strip_edges().is_valid_float():
		return value
	var number := float(value)
	var flags: Array[String] = []
	for part: String in parts:
		flags.append(part.strip_edges())
	if number < float(parts[0]) and not flags.has("or_less"):
		number = float(parts[0])
	elif number > float(parts[1]) and not flags.has("or_greater"):
		number = float(parts[1])
	else:
		return value
	last_warnings.append("%s clamped to %s" % [label, number])
	return roundi(number) if value is int else number


# --- Values -----------------------------------------------------------------------------


## `value` as JSON: vectors and colors become arrays, StringNames strings.
static func encode_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return [v2.x, v2.y]
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return [v3.x, v3.y, v3.z]
		TYPE_COLOR:
			var c: Color = value
			return [c.r, c.g, c.b, c.a]
		TYPE_STRING_NAME:
			return String(value)
	return value


## The JSON value `raw` as a Variant of `type`, or null if it doesn't fit.
static func decode_value(raw: Variant, type: int) -> Variant:
	var number := raw is float or raw is int
	match type:
		TYPE_BOOL:
			if raw is bool:
				return raw
			return (float(raw) != 0.0) if number else null
		TYPE_INT:
			return roundi(float(raw)) if number else null
		TYPE_FLOAT:
			return float(raw) if number else null
		TYPE_STRING:
			return str(raw) if raw is String else null
		TYPE_STRING_NAME:
			return StringName(str(raw)) if raw is String else null
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR:
			var parts := _numbers(raw)
			if type == TYPE_VECTOR2 and parts.size() == 2:
				return Vector2(parts[0], parts[1])
			if type == TYPE_VECTOR3 and parts.size() == 3:
				return Vector3(parts[0], parts[1], parts[2])
			if type == TYPE_COLOR and parts.size() in [3, 4]:
				return Color(parts[0], parts[1], parts[2], parts[3] if parts.size() == 4 else 1.0)
	return null


## The ids an enum hint_string lists ("Name:id" entries; a bare "Name" takes the id after the
## previous one), as the editor reads them.
static func enum_ids(hint_string: String) -> PackedInt32Array:
	var ids := PackedInt32Array()
	var next := 0
	for entry: String in hint_string.split(",", false):
		var parts := entry.split(":")
		var id := int(parts[1]) if parts.size() > 1 else next
		ids.append(id)
		next = id + 1
	return ids


## Equal, with float tolerance for floats, vectors and colors.
static func values_equal(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	if a is Vector2 and b is Vector2:
		return (a as Vector2).is_equal_approx(b)
	if a is Vector3 and b is Vector3:
		return (a as Vector3).is_equal_approx(b)
	if a is Color and b is Color:
		return (a as Color).is_equal_approx(b)
	return typeof(a) == typeof(b) and a == b


static func _numbers(raw: Variant) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not raw is Array:
		return out
	for item: Variant in raw:
		if not (item is float or item is int):
			return PackedFloat64Array()
		out.append(float(item))
	return out
