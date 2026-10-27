class_name SkinnedArt
extends RefCounted
## Turns a CharacterArt into skinned meshes on a HumanoidRig's skeleton (Milestone 4,
## docs/ARCHITECTURE.md "Skinned art on the rig"). The art is a GLB exported by tools/pipeline
## with the project's 23 bone names, authored at 1.8 m, +Y up, facing -Z. Only its meshes, its
## vertex weights and its joint positions are used: the GLB's own Skeleton3D never goes under
## the rig (its rests carry Blender's bone axes, the rig's are identity), and its inverse binds
## are read for their joint positions only.
##
## The bind route (M4-plan A3). The GLB's rest may be the table (arms hanging) or an A-pose
## whose arm chains are swung. For each bone n, R_n is the shortest arc from the rig's rest
## direction (n to its first child in PlaceholderBody's table) to the GLB's direction
## (p_child - p_n); leaves take their parent's R, Root and Hips take identity. The Skin keeps
## the GLB's bind order (the mesh's bone indices point into it) and binds
##   bind'_n = Scale(s) * Transform3D(Basis(R_n), p_n).affine_inverse()      s = rig.rig_scale()
## so at the rig's rest a vertex lands rotated about its joint from the GLB's pose to the
## table's hanging pose, and scaled with the rig. A GLB authored at the table has R = identity
## and the binds reduce to translations: one code path serves both routes.

## A GLB mesh named with this suffix is the first-person-hidden part (head, neck, chest,
## shoulders, the shoulder half of each upper arm): it goes on CombatTypes.VIS_FP_HIDDEN on a
## first_person_body rig, like the primitives PlaceholderBody.is_fp_hidden() names.
const FP_HIDDEN_SUFFIX := "__fp_hidden"
## Set on the meshes attach() makes for a FP-hidden GLB mesh (HumanoidRig._apply_layers()).
const FP_HIDDEN_META := &"fp_hidden"
## The GLB's joints sit within this of the table chained through the swing (A3, row A1).
const JOINT_TOLERANCE_M := 0.001
## A vertex's weights sum to 1 within this (row A1: normalized).
const WEIGHT_SUM_TOLERANCE := 0.01
## An antiparallel rest and GLB direction has no shortest arc: the swing is refused.
const MIN_ARC_DOT := -0.9999
## The influence slots of an ArrayMesh surface (Godot's default; 8 is refused).
const INFLUENCES := 4
## The name Blender's glTF exporter gives the bone it adds when some vertex has no weight.
const NEUTRAL_BONE := &"neutral_bone"

## What the art cache holds for one art: the GLB's meshes, ready to attach, and the contract
## violations found reading them.
class Entry:
	extends RefCounted
	var art_ref: WeakRef
	var scene: PackedScene
	var meshes: Array[ArtMesh] = []
	var problems: PackedStringArray = PackedStringArray()


## One GLB mesh: its rebuilt ArrayMesh (with CUSTOM0/1), its bind names and joint origins in
## the GLB's bind order, and the Skins made from them, one per rig scale.
class ArtMesh:
	extends RefCounted
	var node_name: StringName
	var mesh: ArrayMesh
	var fp_hidden: bool = false
	var triangles: int = 0
	var bind_names: Array[StringName] = []
	var bind_origins: PackedVector3Array = PackedVector3Array()
	## Per bind (the same order): the swing R_n, once the bind names are known.
	var bind_rotations: Array[Quaternion] = []
	var skins: Dictionary[int, Skin] = {}

static var _cache: Dictionary[int, Entry] = {}


## Add `art`'s meshes to `rig`, skinned to its skeleton (a child of rig.skeleton, named
## Art<Mesh>, in group HumanoidRig.ART_GROUP, with rig.paint's art material and outline).
## Returns the meshes added; empty when there is nothing to draw (no scene) or the art breaks
## the contract (check()), in which case the rig keeps its primitives visible. Called by
## HumanoidRig._build_meshes() after the primitives are built.
static func attach(rig: HumanoidRig, art: CharacterArt) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if art == null or art.scene == null or rig.skeleton == null:
		return out
	var entry := _entry(art)
	if not entry.problems.is_empty():
		push_warning("SkinnedArt: %s does not attach: %s" % [art.id, "; ".join(entry.problems)])
		return out
	var material := rig.paint.art_material()
	var outline := rig.paint.outline_material()
	for part: ArtMesh in entry.meshes:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Art%s" % part.node_name
		mesh_instance.mesh = part.mesh
		mesh_instance.skin = skin_of(part, rig.rig_scale())
		rig.skeleton.add_child(mesh_instance)
		mesh_instance.skeleton = NodePath("..")
		mesh_instance.material_override = material
		mesh_instance.material_overlay = outline
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.add_to_group(HumanoidRig.ART_GROUP)
		if part.fp_hidden:
			mesh_instance.set_meta(FP_HIDDEN_META, true)
		out.append(mesh_instance)
	return out


## The contract violations of `art`; empty = ok. A bind name outside PlaceholderBody.BONE_NAMES
## (a `neutral_bone` included: it is never aliased), a bone with no bind, a joint more than
## JOINT_TOLERANCE_M off the table chained through the swing, a vertex unweighted, weighted
## to Root, more than 4 influences or not normalized, no UV1, or more triangles than
## art.triangle_budget.
static func check(art: CharacterArt) -> PackedStringArray:
	if art == null:
		return PackedStringArray(["no art"])
	if art.scene == null:
		return PackedStringArray(["the art has no scene"])
	return _entry(art).problems


## The Skin of `part` for a rig of scale `rig_scale` (height / 1.8), in the GLB's bind order
## (see the class docs), made once per scale.
static func skin_of(part: ArtMesh, rig_scale: float) -> Skin:
	var key := roundi(rig_scale * 10000.0)
	if part.skins.has(key):
		return part.skins[key]
	var skin := Skin.new()
	var scale_basis := Basis.from_scale(Vector3.ONE * rig_scale)
	for i: int in part.bind_names.size():
		var pose := Transform3D(Basis(part.bind_rotations[i]), part.bind_origins[i])
		skin.add_named_bind(part.bind_names[i], Transform3D(scale_basis, Vector3.ZERO) * pose.affine_inverse())
	part.skins[key] = skin
	return skin


## The cache entry of `art` (read and checked on first use). For tests: its meshes' bind
## names and rotations.
static func entry_of(art: CharacterArt) -> Entry:
	return _entry(art)


## Forget every cached art (tests that change a scene in place).
static func clear_cache() -> void:
	_cache.clear()


## The swing R_n of every bone in `origins` (bone -> joint position in the GLB, at 1.8 m):
## the shortest arc from the table's direction to the GLB's (see the class docs). A bone whose
## direction is antiparallel gets identity and is named in `problems`.
static func swings(origins: Dictionary[StringName, Vector3], problems: PackedStringArray = PackedStringArray()) -> Dictionary[StringName, Quaternion]:
	var empty: Dictionary[StringName, Vector3] = {}
	var rest := PlaceholderBody.pose_globals(empty, Vector3.ZERO, 1.0)
	var out: Dictionary[StringName, Quaternion] = {}
	for bone: StringName in PlaceholderBody.BONE_NAMES:
		var rotation := Quaternion.IDENTITY
		if bone != &"Root" and bone != &"Hips":
			var child := _first_child(bone)
			if child != &"" and origins.has(bone) and origins.has(child):
				var from: Vector3 = rest[child].origin - rest[bone].origin
				var to: Vector3 = origins[child] - origins[bone]
				if from.length_squared() > 0.0 and to.length_squared() > 0.0:
					from = from.normalized()
					to = to.normalized()
					if from.dot(to) > MIN_ARC_DOT:
						rotation = Quaternion(from, to)
					else:
						problems.append("the direction of %s to %s is opposite the table's" % [bone, child])
			elif child == &"":
				rotation = out[PlaceholderBody.BONE_PARENT[bone]]
		out[bone] = rotation
	return out


## Every bone's joint's distance (m) from the table chained through the swing: |p_c - (p_n +
## R_n * (table_c - table_n))| for each bone c of parent n, keyed by c. Root's own origin is
## compared with the table's. The numbers `check()` holds to JOINT_TOLERANCE_M.
static func chain_residuals(origins: Dictionary[StringName, Vector3], rotations: Dictionary[StringName, Quaternion]) -> Dictionary[StringName, float]:
	var empty: Dictionary[StringName, Vector3] = {}
	var rest := PlaceholderBody.pose_globals(empty, Vector3.ZERO, 1.0)
	var out: Dictionary[StringName, float] = {}
	for bone: StringName in PlaceholderBody.BONE_NAMES:
		if not origins.has(bone):
			continue
		if not PlaceholderBody.BONE_PARENT.has(bone):
			out[bone] = origins[bone].distance_to(rest[bone].origin)
			continue
		var parent: StringName = PlaceholderBody.BONE_PARENT[bone]
		if not origins.has(parent):
			continue
		var expected: Vector3 = origins[parent] + rotations[parent] * (rest[bone].origin - rest[parent].origin)
		out[bone] = origins[bone].distance_to(expected)
	return out


# --- Reading the GLB ---------------------------------------------------------------------


static func _first_child(bone: StringName) -> StringName:
	for name: StringName in PlaceholderBody.BONE_NAMES:
		if PlaceholderBody.BONE_PARENT.get(name, &"") == bone:
			return name
	return &""


static func _entry(art: CharacterArt) -> Entry:
	var id := art.get_instance_id()
	var cached: Entry = _cache.get(id)
	if cached != null and cached.art_ref.get_ref() == art and cached.scene == art.scene:
		return cached
	# Entries of freed arts (an instance id can come round again) go before a new one is made.
	for key: int in _cache.keys():
		if _cache[key].art_ref.get_ref() == null:
			_cache.erase(key)
	var entry := Entry.new()
	entry.art_ref = weakref(art)
	entry.scene = art.scene
	_read(art, entry)
	_cache[id] = entry
	return entry


static func _read(art: CharacterArt, entry: Entry) -> void:
	var problems := entry.problems
	if art.palette == null:
		problems.append("the art has no palette atlas")
	var root := art.scene.instantiate()
	var nodes := root.find_children("*", "MeshInstance3D", true, false)
	if nodes.is_empty():
		problems.append("the scene has no MeshInstance3D")
	var triangles := 0
	for node: Node in nodes:
		var part := _read_mesh(node as MeshInstance3D, problems)
		if part == null:
			continue
		entry.meshes.append(part)
		triangles += part.triangles
	root.free()
	if triangles > art.triangle_budget:
		problems.append("%d triangles, over the budget of %d" % [triangles, art.triangle_budget])


## One GLB mesh: its binds, weights and joints checked, its surfaces rebuilt with the rest
## position and normal in CUSTOM0 and CUSTOM1 (the damage look's marks stay on the body: the
## shader reads them instead of the skinned position). Null when it cannot be used.
static func _read_mesh(node: MeshInstance3D, problems: PackedStringArray) -> ArtMesh:
	var label := String(node.name)
	if not node.mesh is ArrayMesh:
		problems.append("%s is not an ArrayMesh" % label)
		return null
	if node.skin == null:
		problems.append("%s has no skin" % label)
		return null
	var part := ArtMesh.new()
	part.node_name = node.name
	part.fp_hidden = label.ends_with(FP_HIDDEN_SUFFIX)
	var skeleton := node.get_node_or_null(node.skeleton) as Skeleton3D
	var origins: Dictionary[StringName, Vector3] = {}
	var seen: Dictionary[StringName, bool] = {}
	var known := true
	for i: int in node.skin.get_bind_count():
		var bone_name := StringName(node.skin.get_bind_name(i))
		if bone_name == &"" and skeleton != null and node.skin.get_bind_bone(i) >= 0:
			bone_name = skeleton.get_bone_name(node.skin.get_bind_bone(i))
		if bone_name == NEUTRAL_BONE:
			problems.append("%s binds a neutral_bone (a vertex has no weight)" % label)
			known = false
		elif not PlaceholderBody.BONE_NAMES.has(bone_name):
			problems.append("%s binds '%s', which is not one of the 23 bones" % [label, bone_name])
			known = false
		elif seen.has(bone_name):
			problems.append("%s binds %s twice" % [label, bone_name])
			known = false
		seen[bone_name] = true
		part.bind_names.append(bone_name)
		var origin := node.skin.get_bind_pose(i).affine_inverse().origin
		part.bind_origins.append(origin)
		origins[bone_name] = origin
	for bone_name: StringName in PlaceholderBody.BONE_NAMES:
		if not seen.has(bone_name):
			problems.append("%s has no bind for %s" % [label, bone_name])
			known = false
	if not known:
		return null
	var swing_problems := PackedStringArray()
	var rotations := swings(origins, swing_problems)
	for text: String in swing_problems:
		problems.append("%s: %s" % [label, text])
	for i: int in part.bind_names.size():
		part.bind_rotations.append(rotations[part.bind_names[i]])
	var residuals := chain_residuals(origins, rotations)
	for bone_name: StringName in PlaceholderBody.BONE_NAMES:
		if residuals[bone_name] > JOINT_TOLERANCE_M:
			problems.append("%s: joint %s is %.1f mm off the table chained through the swing" % [
					label, bone_name, residuals[bone_name] * 1000.0])
	part.mesh = _rebuild(node.mesh as ArrayMesh, part, label, problems)
	return part


static func _rebuild(source: ArrayMesh, part: ArtMesh, label: String, problems: PackedStringArray) -> ArrayMesh:
	var out := ArrayMesh.new()
	var custom_flags := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var root_index := part.bind_names.find(&"Root")
	var unweighted := 0
	var unnormalized := 0
	var on_root := 0
	var out_of_range := 0
	for surface: int in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var count := vertices.size()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		part.triangles += (indices.size() if not indices.is_empty() else count) / 3
		if arrays[Mesh.ARRAY_TEX_UV] == null:
			problems.append("%s has no UV1 (the palette swatch of each face)" % label)
		if source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			problems.append("%s has 8 influences per vertex (4 at most)" % label)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if bones.size() != count * INFLUENCES or weights.size() != count * INFLUENCES:
			problems.append("%s has no 4-influence skin weights" % label)
		else:
			for v: int in count:
				var total := 0.0
				for j: int in INFLUENCES:
					var w := weights[v * INFLUENCES + j]
					if w <= 0.0:
						continue
					total += w
					var bind := bones[v * INFLUENCES + j]
					if bind < 0 or bind >= part.bind_names.size():
						out_of_range += 1
					elif bind == root_index:
						on_root += 1
				if total < 1e-4:
					unweighted += 1
				elif absf(total - 1.0) > WEIGHT_SUM_TOLERANCE:
					unnormalized += 1
		# The rest position and normal, per vertex (RGB_FLOAT: three floats each).
		var rest_position := PackedFloat32Array()
		rest_position.resize(count * 3)
		var rest_normal := PackedFloat32Array()
		rest_normal.resize(count * 3)
		for v: int in count:
			rest_position[v * 3] = vertices[v].x
			rest_position[v * 3 + 1] = vertices[v].y
			rest_position[v * 3 + 2] = vertices[v].z
			if not normals.is_empty():
				rest_normal[v * 3] = normals[v].x
				rest_normal[v * 3 + 1] = normals[v].y
				rest_normal[v * 3 + 2] = normals[v].z
		arrays[Mesh.ARRAY_CUSTOM0] = rest_position
		arrays[Mesh.ARRAY_CUSTOM1] = rest_normal
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, custom_flags)
	if unweighted > 0:
		problems.append("%s: %d vertices have no weight" % [label, unweighted])
	if unnormalized > 0:
		problems.append("%s: %d vertices' weights do not sum to 1" % [label, unnormalized])
	if on_root > 0:
		problems.append("%s: %d vertices are weighted to Root" % [label, on_root])
	if out_of_range > 0:
		problems.append("%s: %d weights point past the binds" % [label, out_of_range])
	return out
