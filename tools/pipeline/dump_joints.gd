extends SceneTree
## Writes tools/pipeline/joints.json, the asset contract's joint table, from PlaceholderBody
## (Milestone 4): the 23 bones with their parents and rest transforms, the rig points, the
## sole points, the fist box, the hurtboxes and every placeholder part. The art pipeline
## (tools/pipeline/*.py) reads it to build the mannequin, the armature and the checks, and
## never writes it; tests/test_m4_contracts.gd fails when PlaceholderBody changes without it.
##
## Run after any change to PlaceholderBody:
##   godot --headless --import --quit && godot --headless -s tools/pipeline/dump_joints.gd --quit-after 5
## It needs no autoload, so `-s` runs it. GUT calls table() and to_json() directly.
##
## Space: the rig's, in metres at PlaceholderBody.REF_HEIGHT (1.8 m), +Y up, the character
## faces -Z (so its own right is +X), the origin on the floor between the feet. Every
## bone's rest rotation is identity: a rest global is the sum of the local offsets.

const PATH := "res://tools/pipeline/joints.json"
## Numbers are written with this many decimals (a micrometre), so single-precision noise
## never shows.
const _DECIMALS := 6


func _initialize() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		printerr("Could not write %s: %s" % [PATH, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	file.store_string(to_json())
	file.close()
	print("Wrote %s (%d bones)" % [PATH, PlaceholderBody.BONE_NAMES.size()])
	quit(0)


## The joint table as plain data (arrays and dictionaries of strings and numbers), in a fixed
## order: bones parents first, as PlaceholderBody.BONE_NAMES has them.
static func table() -> Dictionary:
	var rest: Dictionary[StringName, Vector3] = {}
	var globals := PlaceholderBody.pose_globals(rest, Vector3.ZERO, 1.0)
	var bones: Array = []
	for bone: StringName in PlaceholderBody.BONE_NAMES:
		bones.append({
			"name": String(bone),
			"parent": String(PlaceholderBody.BONE_PARENT.get(bone, &"")),
			"rest_local": _vec(PlaceholderBody.BONE_REST[bone]),
			"rest_global": _vec(globals[bone].origin),
		})
	var points: Dictionary = {}
	for point: StringName in PlaceholderBody.POINT_BONE:
		var bone: StringName = PlaceholderBody.POINT_BONE[point]
		points[String(point)] = {
			"bone": String(bone),
			"offset": _vec(PlaceholderBody.POINT_OFFSET[point]),
			"rest_global": _vec(globals[bone] * PlaceholderBody.POINT_OFFSET[point]),
		}
	var soles: Array = []
	for i: int in PlaceholderBody.SOLE_BONES.size():
		var bone := PlaceholderBody.SOLE_BONES[i]
		soles.append({
			"bone": String(bone),
			"offset": _vec(PlaceholderBody.SOLE_OFFSETS[i]),
			"rest_global": _vec(globals[bone] * PlaceholderBody.SOLE_OFFSETS[i]),
		})
	var fists: Array = []
	for part: PlaceholderBody.Part in PlaceholderBody.parts(false):
		if part.name == &"LeftFist" or part.name == &"RightFist":
			fists.append({
				"side": String(part.name).trim_suffix("Fist"),
				"bone": String(part.bone),
				"size": _vec(part.size),
				"center_offset": _vec(part.offset),
				"center_rest_global": _vec(globals[part.bone] * part.offset),
			})
	var hurtboxes: Array = []
	for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
		var entry := {
			"name": String(spec.name),
			"region": CombatTypes.Region.find_key(spec.region),
			"shape": "capsule" if spec.is_capsule() else "sphere",
			"radius": _num(spec.radius),
			"bone_a": String(spec.bone_a),
			"offset_a": _vec(spec.offset_a),
			"a_rest_global": _vec(globals[spec.bone_a] * spec.offset_a),
		}
		if spec.is_capsule():
			entry["bone_b"] = String(spec.bone_b)
			entry["offset_b"] = _vec(spec.offset_b)
			entry["b_rest_global"] = _vec(globals[spec.bone_b] * spec.offset_b)
		hurtboxes.append(entry)
	return {
		"format": 1,
		"source": "game/actors/placeholder_body.gd via tools/pipeline/dump_joints.gd; do not edit",
		"ref_height_m": _num(PlaceholderBody.REF_HEIGHT),
		"space": "rig: metres at ref_height_m, +Y up, faces -Z (own right is +X), origin on the floor between the feet; every bone's rest rotation is identity",
		"bones": bones,
		"points": points,
		"soles": soles,
		"fist_boxes": fists,
		"hurtboxes": hurtboxes,
		"fp_hidden_bones": _names(PlaceholderBody.FP_HIDDEN_BONES),
		"fp_hidden_parts": _names(PlaceholderBody.FP_HIDDEN_PARTS),
		"parts_enemy": _parts(false),
		"parts_player": _parts(true),
	}


## table() as the file's text: one line per bone, point, part and so on, so a change shows
## in a diff.
static func to_json() -> String:
	var data := table()
	var lines := PackedStringArray()
	lines.append("{")
	var keys: Array = data.keys()
	for i: int in keys.size():
		var key: String = keys[i]
		var value: Variant = data[key]
		var tail := "," if i < keys.size() - 1 else ""
		if value is Array and not (value as Array).is_empty() and (value as Array)[0] is Dictionary:
			lines.append("\t\"%s\": [" % key)
			var rows: Array = value
			for j: int in rows.size():
				lines.append("\t\t%s%s" % [JSON.stringify(rows[j], "", false), "," if j < rows.size() - 1 else ""])
			lines.append("\t]%s" % tail)
		elif value is Dictionary:
			lines.append("\t\"%s\": {" % key)
			var entries: Dictionary = value
			var names: Array = entries.keys()
			for j: int in names.size():
				lines.append("\t\t\"%s\": %s%s" % [names[j], JSON.stringify(entries[names[j]], "", false),
						"," if j < names.size() - 1 else ""])
			lines.append("\t}%s" % tail)
		else:
			lines.append("\t\"%s\": %s%s" % [key, JSON.stringify(value, "", false), tail])
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _parts(wrapped_hands: bool) -> Array:
	var out: Array = []
	for part: PlaceholderBody.Part in PlaceholderBody.parts(wrapped_hands):
		out.append({
			"name": String(part.name),
			"bone": String(part.bone),
			"shape": PlaceholderBody.Shape.find_key(part.shape),
			"size": _vec(part.size),
			"offset": _vec(part.offset),
			"rot_deg": _vec(part.rot_deg),
			"paint": PlaceholderBody.Paint.find_key(part.paint),
			"fp_hidden": PlaceholderBody.is_fp_hidden(part),
		})
	return out


static func _names(names: Array[StringName]) -> Array:
	var out: Array = []
	for bone_name: StringName in names:
		out.append(String(bone_name))
	return out


static func _vec(v: Vector3) -> Array:
	return [_num(v.x), _num(v.y), _num(v.z)]


static func _num(value: float) -> float:
	var rounded := String.num(value, _DECIMALS).to_float()
	# -0.0 would print as "-0.0".
	return 0.0 if rounded == 0.0 else rounded
