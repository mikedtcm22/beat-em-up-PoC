@tool
class_name LevelBlock
extends Node3D
## One box of a level's geometry (Milestone 5): a wall, a floor slab, a prop. Place it in a section
## scene with a transform (the centre) and a size, so the level is a list of boxes the scene file
## shows. A `solid` block builds a world-layer collider (the navmesh bakes from it) and a mesh in
## the `look`'s material through RoomKit; a non-solid one is drawn only (paint, a skyline, the
## ground seen from an edge). Every number is an export, never a script constant.
##
## Looks: `wall` (the street's flat grey), `floor` (the grid), `accent` (the warm grey), `dark`
## (doorways and alleys: a spawn point reads from across the street), `prop` (a muted prop with the
## inverted hull, like the crowd room's crates and car), `fence` (a darker, thinner-looking rail).
## In the editor it draws a plain coloured box (the toon materials need the autoloads).

## Looks a block can have.
const LOOKS: Array[StringName] = [&"wall", &"floor", &"accent", &"dark", &"prop", &"fence"]
## The editor's stand-in colours, and the runtime flat colours of the looks that have no shared
## material: wall, accent, dark, prop, fence.
const COLORS := {
	&"wall": Color(0.42, 0.4, 0.44),
	&"floor": Color(0.34, 0.34, 0.36),
	&"accent": Color(0.5, 0.46, 0.4),
	&"dark": Color(0.26, 0.24, 0.27),
	&"prop": Color(0.34, 0.38, 0.45),
	&"fence": Color(0.2, 0.2, 0.23),
}

@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value
		_rebuild()
@export var look: StringName = &"wall":
	set(value):
		look = value
		_rebuild()
## A solid block collides (world layer) and is baked into the navmesh; otherwise it is drawn only.
@export var solid: bool = true:
	set(value):
		solid = value
		_rebuild()

## The collider (null when not solid), for tests.
var body: StaticBody3D
var _visual: Node3D


func _ready() -> void:
	_rebuild()


## The box in world space (its centre and size, no rotation assumed beyond the node's).
func world_aabb() -> AABB:
	return AABB(global_position - size * 0.5, size)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if body != null:
		body.queue_free()
		body = null
	if _visual != null:
		_visual.queue_free()
		_visual = null
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	var material := _material()
	if solid:
		body = _make_body(material)
		add_child(body)
	else:
		_visual = RoomKit.box_mesh(size, material, _overlay())
		add_child(_visual)


## The collider's layer: the world's. EdgeGuard overrides it (layer 9, no mesh).
func _layer_bit() -> int:
	return CombatTypes.bit(CombatTypes.LAYER_WORLD)


## Whether the box is drawn.
func _drawn() -> bool:
	return true


func _make_body(material: Material) -> StaticBody3D:
	var out := StaticBody3D.new()
	out.name = "Body"
	out.collision_layer = _layer_bit()
	out.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	out.add_child(shape)
	if _drawn():
		out.add_child(RoomKit.box_mesh(size, material, _overlay()))
	return out


func _material() -> Material:
	if Engine.is_editor_hint():
		var plain := StandardMaterial3D.new()
		plain.albedo_color = COLORS.get(look, COLORS[&"wall"])
		return plain
	match look:
		&"floor":
			return RoomKit.grid_material()
		&"prop":
			return RoomKit.prop_material(COLORS[&"prop"])
	return RoomKit.flat_material(COLORS.get(look, COLORS[&"wall"]))


func _overlay() -> Material:
	return null
