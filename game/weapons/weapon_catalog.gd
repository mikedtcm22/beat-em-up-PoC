class_name WeaponCatalog
extends RefCounted
## Every weapon kind the game has (Milestone 6, D5): the WeaponDefs in `game/weapons/defs/`, loaded once. The player asks it for
## the def of the weapon in his hand; PickupSpot, the Pipe Thug and the training room place a weapon by its scene.

const DEFS_DIR := "res://game/weapons/defs/"
## The ids in catalog order: the pipe first (the Pipe Thug's, the graybox's), the second weapon after it.
const IDS: Array[StringName] = [&"pipe", &"bike_chain"]

static var _defs: Dictionary[StringName, WeaponDef] = {}


## The def called `id`, or null.
static func get_def(id: StringName) -> WeaponDef:
	if _defs.is_empty():
		_load()
	return _defs.get(id)


## Every def, in `IDS` order.
static func all() -> Array[WeaponDef]:
	if _defs.is_empty():
		_load()
	var out: Array[WeaponDef] = []
	for id: StringName in IDS:
		if _defs.has(id):
			out.append(_defs[id])
	return out


## Whether any def owns `move_id` as a swing (a swing the player may not start without the weapon).
static func is_swing(move_id: StringName) -> bool:
	for def: WeaponDef in all():
		if def.owns_swing(move_id):
			return true
	return false


## Whether any def throws with `move_id`.
static func is_throw(move_id: StringName) -> bool:
	for def: WeaponDef in all():
		if def.throw_move != null and def.throw_move.id == move_id:
			return true
	return false


## Forget what was loaded (tests that change a def in place).
static func clear() -> void:
	_defs.clear()


static func _load() -> void:
	for id: StringName in IDS:
		var path := "%s%s.tres" % [DEFS_DIR, id]
		if ResourceLoader.exists(path):
			var def := load(path) as WeaponDef
			if def != null:
				_defs[id] = def
