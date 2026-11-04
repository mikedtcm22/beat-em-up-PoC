class_name PropSpot
extends Node3D
## A hero prop's place (Milestone 6, KIT; D13): the car, the dumpster, the AC unit, the water tank.
## The node stands on the floor at the middle of the prop's footprint. It draws
## `res://game/level/props/<prop_id>.tscn` (PROPS builds those, on the shared palette atlas) when that
## scene exists, fitted to `size`, and a plain box of `size` in the muted prop colour with the hull
## otherwise (the fallback, which also stands in until PROPS's scene lands). It is visual only
## (D1): the collider is the block or barrier it dresses. `size` (ZERO: the prop's nominal box) is the
## box it fills. Tuning's `kit_draw_graybox` hides it.

const PROP_DIR := "res://game/level/props/"
## The ids and their fallback boxes (length x height x depth, m) and muted colours (inside the look
## bible's environment band: saturation at most 0.30, value 0.25 to 0.6).
const PROPS := {
	&"car": {size = Vector3(4.2, 1.4, 1.9), color = Color(0.34, 0.38, 0.45)},
	&"dumpster": {size = Vector3(2.0, 1.3, 1.0), color = Color(0.28, 0.4, 0.34)},
	&"ac_unit": {size = Vector3(1.0, 0.8, 0.7), color = Color(0.42, 0.44, 0.46)},
	&"water_tank": {size = Vector3(2.0, 2.6, 2.0), color = Color(0.4, 0.38, 0.34)},
}

@export var prop_id: StringName = &"dumpster":
	set(value):
		prop_id = value
		_rebuild()
## The box the prop fills (m); ZERO takes the prop's nominal box.
@export var size: Vector3 = Vector3.ZERO:
	set(value):
		size = value
		_rebuild()
## The fallback box wears the inverted hull (a prop is inked like a character). PROPS's scene has its own.
@export var hull: bool = true:
	set(value):
		hull = value
		_rebuild()

## The prop's scene instance, or null while the fallback box stands in.
var art: Node3D
## The fallback box, or null when the scene draws.
var fallback: MeshInstance3D


func _ready() -> void:
	_rebuild()


## The scene a prop id draws, or "" when there is none (yet).
static func scene_path(id: StringName) -> String:
	var path := PROP_DIR + String(id) + ".tscn"
	return path if ResourceLoader.exists(path) else ""


## The nominal box of a prop id (ZERO for an id that is not one).
static func nominal_size(id: StringName) -> Vector3:
	return (PROPS[id].size as Vector3) if PROPS.has(id) else Vector3.ZERO


## The box this spot fills.
func box_size() -> Vector3:
	return size if size != Vector3.ZERO else nominal_size(prop_id)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if art != null:
		art.queue_free()
		art = null
	if fallback != null:
		fallback.queue_free()
		fallback = null
	visible = not Tuning.data.kit_draw_graybox
	var box := box_size()
	if box == Vector3.ZERO:
		push_warning("PropSpot '%s': '%s' is not a prop id and has no size" % [name, prop_id])
		return
	var path := scene_path(prop_id)
	var packed := load(path) as PackedScene if path != "" else null
	if packed != null:
		art = packed.instantiate() as Node3D
	if art != null:
		add_child(art)
		_fit(art, box)
		return
	var color: Color = PROPS[prop_id].color if PROPS.has(prop_id) else Color(0.34, 0.38, 0.45)
	fallback = MeshInstance3D.new()
	fallback.name = "Fallback"
	var mesh := BoxMesh.new()
	mesh.size = box
	mesh.material = ToonMaterials.environment(color, hull)
	fallback.mesh = mesh
	fallback.position = Vector3(0.0, box.y * 0.5, 0.0)
	add_child(fallback)


## Scale `node` per axis so its meshes fill `box`, standing on the floor at the middle of it.
func _fit(node: Node3D, box: Vector3) -> void:
	var bounds := _bounds(node, Transform3D.IDENTITY)
	if bounds.size.x < 0.001 or bounds.size.y < 0.001 or bounds.size.z < 0.001:
		return
	node.scale = Vector3(box.x / bounds.size.x, box.y / bounds.size.y, box.z / bounds.size.z)
	var centre := bounds.position + bounds.size * 0.5
	node.position = -Vector3(centre.x * node.scale.x, bounds.position.y * node.scale.y, centre.z * node.scale.z)


## The bounds of the meshes under `node`, in the space of `node`'s own origin.
func _bounds(node: Node, to_root: Transform3D) -> AABB:
	var found := AABB()
	var first := true
	for child in node.get_children():
		var spatial := child as Node3D
		if spatial == null:
			continue
		var xform := to_root * spatial.transform
		var box := AABB()
		var has := false
		var mesh_node := spatial as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			box = xform * mesh_node.mesh.get_aabb()
			has = true
		var inner := _bounds(spatial, xform)
		if inner.size != Vector3.ZERO:
			box = box.merge(inner) if has else inner
			has = true
		if has:
			found = box if first else found.merge(box)
			first = false
	return found
