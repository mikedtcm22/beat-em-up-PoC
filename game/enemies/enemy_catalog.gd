class_name EnemyCatalog
extends RefCounted
## Every enemy the game can spawn (Milestone 3): the F4 cheat menu and the encounter spawner
## read it, and nothing else hard-codes an enemy's path. An entry is {id, label, scene}, the
## scene as a res:// path; available() lists only the scenes that exist, so a missing archetype
## (a package not merged yet) simply isn't offered.

const ENTRIES: Array[Dictionary] = [
	{id = &"dummy", label = "Training dummy", scene = "res://game/enemies/dummy/training_dummy.tscn"},
	{id = &"punk", label = "Street Punk", scene = "res://game/enemies/punk/street_punk.tscn"},
	{id = &"kicker", label = "Kicker", scene = "res://game/enemies/kicker/kicker.tscn"},
	{id = &"thug", label = "Pipe Thug", scene = "res://game/enemies/thug/pipe_thug.tscn"},
	{id = &"bruiser", label = "Bruiser", scene = "res://game/enemies/bruiser/bruiser.tscn"},
	{id = &"boss", label = "Boss", scene = "res://game/enemies/boss/boss.tscn"},
]

## id -> Vector2(body radius, body height), read once from an instance (body_size()).
static var _sizes: Dictionary[StringName, Vector2] = {}


## The entries whose scene exists, in ENTRIES order.
static func available() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		if ResourceLoader.exists(entry.scene):
			out.append(entry)
	return out


## The scene of enemy `id`, or null when the id is unknown or its scene doesn't exist.
static func scene(id: StringName) -> PackedScene:
	for entry: Dictionary in ENTRIES:
		if entry.id == id and ResourceLoader.exists(entry.scene):
			return load(entry.scene) as PackedScene
	return null


## (body radius, body height) in meters of enemy `id`: its exported body_radius and body_height,
## read once from an instance that is never added to the tree. A CombatActor's defaults when
## the id is unknown or its scene doesn't exist.
static func body_size(id: StringName) -> Vector2:
	if _sizes.has(id):
		return _sizes[id]
	var probe: Node = null
	var packed := scene(id)
	if packed:
		probe = packed.instantiate()
	if not (probe is CombatActor):
		if probe:
			probe.free()
		probe = CombatActor.new()
	var actor := probe as CombatActor
	var size := Vector2(actor.body_radius, actor.body_height)
	probe.free()
	_sizes[id] = size
	return size
