extends RefCounted
## Milestone 6 KIT (D1): the static colliders of the level and of the two code-built rooms, as data.
## M5's snapshot is tests/fixtures/m6/m5_colliders.json (written by tests/test_m6_colliders.gd with
## M6_WRITE_COLLIDERS=1 from the unchanged level); tests/test_m6_colliders.gd holds every later build to it, so the art can draw
## anything and still never move, add or remove a wall.
##
## One entry per `CollisionShape3D` of a `StaticBody3D` that is not part of an actor: its path under
## the scene root (for the message only: the code-built rooms' bodies are named by the engine, so a
## generated name is written as `@`), the shape's class, the shape's bounding box in world space
## (position and size, millimetres), the body's collision layer and whether the shape is disabled.
## Barriers are in the state a level starts in. Entries compare as a sorted list of their content.

const LEVEL := "res://game/level/mission1/mission1.tscn"
const CROWD := "res://game/level/crowd_room.tscn"
const TRAINING := "res://game/level/test_room.tscn"
## The scenes of the fixture, by key.
const SCENES := {&"mission1": LEVEL, &"crowd_room": CROWD, &"training_room": TRAINING}


## The snapshot of the instantiated scene `root` (already in the tree, so its blocks have built).
static func snapshot(root: Node) -> Array:
	var out: Array = []
	_collect(root, root, out)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return key(a) < key(b))
	return out


## The content of an entry as one string, for sorting and comparing (the path is not in it).
static func key(entry: Dictionary) -> String:
	return "%s|%s|%s|%d|%s" % [entry.shape, entry.position, entry.size, int(entry.layer), entry.disabled]


## `scene_path` instantiated, without presentation and without waves, as a child of `parent`. The
## caller frees it.
static func instantiate(scene_path: String, parent: Node) -> Node:
	var node := (load(scene_path) as PackedScene).instantiate()
	node.set(&"with_presentation", false)
	node.set(&"waves_enabled_on_start", false)
	parent.add_child(node)
	return node


static func _collect(root: Node, node: Node, out: Array) -> void:
	if node is StaticBody3D and not _in_actor(node):
		var index := 0
		for child in node.get_children():
			var shape := child as CollisionShape3D
			if shape == null or shape.shape == null:
				continue
			var local := shape.shape.get_debug_mesh().get_aabb()
			var box := shape.global_transform * local
			out.append({
				path = "%s#%d" % [_clean(root.get_path_to(node)), index],
				shape = shape.shape.get_class(),
				position = _mm(box.position),
				size = _mm(box.size),
				layer = (node as StaticBody3D).collision_layer,
				disabled = shape.disabled,
			})
			index += 1
	for child in node.get_children():
		_collect(root, child, out)


static func _clean(path: NodePath) -> String:
	var parts := PackedStringArray()
	for i in path.get_name_count():
		var part := String(path.get_name(i))
		parts.append("@" if part.begins_with("@") else part)
	return "/".join(parts)


static func _in_actor(node: Node) -> bool:
	var up := node.get_parent()
	while up != null:
		if up is CombatActor or up is Weapon:
			return true
		up = up.get_parent()
	return false


static func _mm(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
