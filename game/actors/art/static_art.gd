class_name StaticArt
extends Node3D
## A rigid model on the shared palette atlas (Milestone 6, docs/ARCHITECTURE.md "Static props and weapon art"):
## the output of `tools/pipeline/run.py --asset <id> --kind prop`, a GLB of one or more named meshes with UV1 on the
## atlas's swatch centres, the smooth hull normal in COLOR and no skin. It draws and does nothing else: a prop scene is
## visual only (its collider is the block or barrier it dresses), a weapon's art rides a Weapon that keeps its own capsule.
##
## It builds one MeshInstance3D per GLB mesh under itself, named as the mesh is, with ToonMaterials.art_prop(palette) as the
## material and, when `hull` is on, ToonMaterials.outline() as the overlay: the hull reads the rest normal this class writes into
## CUSTOM1 (the vertex normal, so the turn from rest to now is the identity) and pushes along the baked smooth normal, never
## along sign(VERTEX) (D14: a prop is never given the box hull). With `hull` off the screen edge pass draws its lines instead.
## The art is authored at its drawn size in metres; a scene scales it by its transform.

## The model: res://assets/export/props/<id>/<id>.glb. Only its MeshInstance3D nodes are used.
@export var scene: PackedScene
## The shared palette atlas, res://assets/export/palette/palette_atlas.png.
@export var palette: Texture2D
## SPEC section 10: 3000 triangles for a prop or a weapon. check() fails a model above it.
@export var triangle_budget: int = 3000
## Draw the baked-smooth-normal hull. Off, the screen edge pass outlines it instead.
@export var hull: bool = false
## A mesh drawn again along the long axis (the bike chain's `Link`, one link at the origin in the GLB): every
## `repeat_pitch_m` between `repeat_range_m.x` and `.y` on local Y, turned `repeat_twist_deg` about Y more than the one before, so a
## chain reads as a chain before the weapon's own sim takes over. Empty `repeat_mesh` draws each mesh once.
@export var repeat_mesh: StringName = &""
@export var repeat_range_m: Vector2 = Vector2.ZERO
@export var repeat_pitch_m: float = 0.0
@export var repeat_twist_deg: float = 0.0

## What the cache holds for one model: its meshes rebuilt with the rest normal in CUSTOM1, and the contract violations.
class Entry:
	extends RefCounted
	var scene: PackedScene
	var meshes: Array[ArtMesh] = []
	var problems: PackedStringArray = PackedStringArray()
	var triangles: int = 0
	var bounds: AABB = AABB()


## One GLB mesh: its name, its rebuilt ArrayMesh, its transform in the GLB's root and its triangle count.
class ArtMesh:
	extends RefCounted
	var node_name: StringName
	var mesh: ArrayMesh
	var xf: Transform3D = Transform3D.IDENTITY
	var triangles: int = 0
	var bounds: AABB = AABB()
	var has_bounds: bool = false


static var _cache: Dictionary[int, Entry] = {}

## The material this art draws with (made in _ready, null before), and the MeshInstance3Ds it made (the repeats included).
var material: ShaderMaterial
var _instances: Array[MeshInstance3D] = []


func _ready() -> void:
	if scene == null or palette == null:
		return
	var entry := _entry(scene)
	if not entry.problems.is_empty():
		push_warning("StaticArt: %s does not draw: %s" % [scene.resource_path, "; ".join(entry.problems)])
		return
	var drawn_hull := hull and Tuning.data.prop_art_hull
	material = ToonMaterials.art_prop(palette)
	material.set_shader_parameter(&"edge_tag", 0.0 if drawn_hull else 1.0)
	var overlay: ShaderMaterial = ToonMaterials.outline() if drawn_hull else null
	for part: ArtMesh in entry.meshes:
		_add(part, part.node_name, part.xf, overlay)
		if part.node_name == repeat_mesh and repeat_pitch_m > 0.0:
			var k := 0
			var y := repeat_range_m.x
			while y <= repeat_range_m.y:
				k += 1
				if absf(y) > repeat_pitch_m * 0.5:
					var turned := Transform3D(Basis(Vector3.UP, deg_to_rad(repeat_twist_deg) * k), Vector3(0.0, y, 0.0)) * part.xf
					_add(part, StringName("%sRep%d" % [part.node_name, k]), turned, overlay)
				y += repeat_pitch_m


## The contract violations of this model; empty = ok: no scene or palette, no MeshInstance3D, a skinned mesh, a surface with no UV1
## on a swatch centre or no COLOR hull normal (when `hull`), a repeated name, more triangles than `triangle_budget`.
func check() -> PackedStringArray:
	return StaticArt.check_art(scene, palette, triangle_budget, hull)


## The contract violations of the model `scene` drawn on `atlas` within `budget` triangles (hull: the COLOR normal is required).
static func check_art(scene: PackedScene, atlas: Texture2D, budget: int, with_hull: bool) -> PackedStringArray:
	if scene == null:
		return PackedStringArray(["the art has no scene"])
	var problems := PackedStringArray()
	if atlas == null:
		problems.append("the art has no palette atlas")
	var entry := _entry(scene)
	problems.append_array(entry.problems)
	if with_hull and entry.meshes.is_empty():
		problems.append("no mesh to hull")
	if entry.triangles > budget:
		problems.append("%d triangles, over the budget of %d" % [entry.triangles, budget])
	return problems


## The names of the GLB's meshes (the nodes' names, as Godot imports them), sorted.
func mesh_names() -> PackedStringArray:
	return StaticArt.mesh_names_of(scene)


static func mesh_names_of(model: PackedScene) -> PackedStringArray:
	var out := PackedStringArray()
	for part: ArtMesh in _entry(model).meshes:
		out.append(String(part.node_name))
	out.sort()
	return out


## The bounding box of the model's meshes in its own frame (a weapon's art frame: centred, long axis +Y).
func bounds() -> AABB:
	return StaticArt.bounds_of(scene)


static func bounds_of(model: PackedScene) -> AABB:
	return _entry(model).bounds


## The triangle count of the model.
func triangles() -> int:
	return _entry(scene).triangles


## The MeshInstance3Ds this art made, repeats included.
func instances() -> Array[MeshInstance3D]:
	return _instances


## Multiply the swatches by `tint` (a weapon lying on the floor takes the floor colour); white is the atlas's own colours.
func set_tint(tint: Color) -> void:
	if material != null:
		material.set_shader_parameter(&"albedo", tint)


## Forget every cached model (tests that change a scene in place).
static func clear_cache() -> void:
	_cache.clear()


func _add(part: ArtMesh, node_name: StringName, xf: Transform3D, overlay: ShaderMaterial) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = part.mesh
	instance.transform = xf
	instance.material_override = material
	instance.material_overlay = overlay
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
	_instances.append(instance)


static func _entry(model: PackedScene) -> Entry:
	var id := model.get_instance_id()
	var cached: Entry = _cache.get(id)
	if cached != null and cached.scene == model:
		return cached
	var entry := Entry.new()
	entry.scene = model
	_read(model, entry)
	_cache[id] = entry
	return entry


static func _read(model: PackedScene, entry: Entry) -> void:
	var root := model.instantiate()
	var nodes := root.find_children("*", "MeshInstance3D", true, false)
	if nodes.is_empty():
		entry.problems.append("the scene has no MeshInstance3D")
	var seen: Dictionary[StringName, bool] = {}
	var first := true
	for node: Node in nodes:
		var instance := node as MeshInstance3D
		var label := String(instance.name)
		if seen.has(instance.name):
			entry.problems.append("%s: two meshes of this name" % label)
		seen[instance.name] = true
		if instance.skin != null or instance.get_node_or_null(instance.skeleton) is Skeleton3D:
			entry.problems.append("%s is skinned (a static prop has no skeleton)" % label)
			continue
		if not instance.mesh is ArrayMesh:
			entry.problems.append("%s is not an ArrayMesh" % label)
			continue
		var part := ArtMesh.new()
		part.node_name = instance.name
		part.xf = _frame_of(instance, root)
		part.mesh = _rebuild(instance.mesh as ArrayMesh, part, label, entry.problems)
		entry.meshes.append(part)
		entry.triangles += part.triangles
		var box := part.xf * part.bounds
		entry.bounds = box if first else entry.bounds.merge(box)
		first = false
	root.free()


## The mesh's transform from the model's root (the GLB's scene root: identity for a Blender export, a node's own for others).
static func _frame_of(instance: MeshInstance3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var node: Node = instance
	while node != null and node != root:
		if node is Node3D:
			xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf


## The surfaces rebuilt with the vertex normal in CUSTOM1 (and the position in CUSTOM0, as the skinned art has): toon.gdshader's
## hull mode 4 turns the baked smooth normal in COLOR by the shortest arc from CUSTOM1 to NORMAL, which is the identity here.
static func _rebuild(source: ArrayMesh, part: ArtMesh, label: String, problems: PackedStringArray) -> ArrayMesh:
	var out := ArrayMesh.new()
	var custom_flags := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for surface: int in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var count := vertices.size()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		part.triangles += (indices.size() if not indices.is_empty() else count) / 3
		if arrays[Mesh.ARRAY_TEX_UV] == null:
			problems.append("%s has no UV1 (the palette swatch of each face)" % label)
		if arrays[Mesh.ARRAY_COLOR] == null:
			problems.append("%s has no COLOR (the baked smooth hull normal)" % label)
		if normals.size() != count:
			problems.append("%s has no normals" % label)
			continue
		var rest_position := PackedFloat32Array()
		rest_position.resize(count * 3)
		var rest_normal := PackedFloat32Array()
		rest_normal.resize(count * 3)
		for v: int in count:
			rest_position[v * 3] = vertices[v].x
			rest_position[v * 3 + 1] = vertices[v].y
			rest_position[v * 3 + 2] = vertices[v].z
			rest_normal[v * 3] = normals[v].x
			rest_normal[v * 3 + 1] = normals[v].y
			rest_normal[v * 3 + 2] = normals[v].z
			part.bounds = part.bounds.expand(vertices[v]) if part.has_bounds else AABB(vertices[v], Vector3.ZERO)
			part.has_bounds = true
		arrays[Mesh.ARRAY_CUSTOM0] = rest_position
		arrays[Mesh.ARRAY_CUSTOM1] = rest_normal
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, custom_flags)
	return out
