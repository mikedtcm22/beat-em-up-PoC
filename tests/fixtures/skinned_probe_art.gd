extends RefCounted
## A procedural CharacterArt for the skinned-art tests (Milestone 4, P1-skin): no GLB, no
## Blender. Its PackedScene is built in code the way tools/pipeline exports a character: a
## root, an Armature, a Skeleton3D with the 23 bones, and the Body mesh (and, for the player,
## Body__fp_hidden) skinned to it with named binds in an order of its own (the skeleton's,
## reversed, so any confusion of bind index and bone index shows), the binds carrying a roll
## of their own as a Blender bone's do.
##
## The body is the placeholder's own primitives, baked into one mesh: every part's vertices, at
## the part's offset and rotation on its bone. At the table's rest the art is then the
## primitive body itself, so a CPU-skinned vertex can be compared with the same vertex of the
## rig's view proxies at any pose (the exact test), and the first-person framing of the art
## with the proxies' (the fidelity numbers) differ only by the tessellation of a sphere.
##
## Authored in one of two poses:
##   REST   the table's rest (arms hanging): every swing R_n is the identity.
##   A_POSE the arm chains swung 45 degrees out about the shoulder joint, so the swing is not
##          the identity and the bind route of M4-plan A3 is proven without any GLB.
## And weighted one of two ways:
##   rigid   every vertex is 100% on its part's bone (exact skinning).
##   smooth  a vertex within BLEND_M of its joint, on the parent's side of it, blends with the
##           parent bone (linear, 50/50 at the joint), so there are blended weights.

enum Authored { REST, A_POSE }

## The arm swing of the A-pose (degrees about the forward axis).
const A_POSE_SWING_DEG := 45.0
## How far (m) on either side of a joint a smooth vertex blends with the parent.
const BLEND_M := 0.06
## The swatch width in the palette atlas (px) and the atlas size.
const SWATCH_PX := 8
const ATLAS_SIZE := Vector2i(40, 8)
## The colors of the atlas's five swatches, one per PlaceholderBody.Paint (BODY, PANTS,
## ACCENT, SKIN, DARK): the Punk's teal and yellow, the way the placeholder paints it.
const SWATCHES: Array[Color] = [
	Color(0.02, 0.5, 0.56), Color(0.011, 0.275, 0.308), Color(0.96, 0.82, 0.14),
	Color(0.86, 0.66, 0.5), Color(0.07, 0.07, 0.08),
]


## A CharacterArt of the probe body: `authored` pose (Authored), `player` (wrapped hands and the
## FP-hidden part in its own mesh, Body__fp_hidden), `smooth` weights (see the file's docs).
## `budget_slack` is the triangle budget above the mesh's own count. `copies` bakes the parts
## that many times over (the same body again: a heavier mesh for the timing test).
static func make(authored: int = Authored.REST, player: bool = false, smooth: bool = false,
		budget_slack: int = 0, copies: int = 1) -> CharacterArt:
	var pose := a_pose() if authored == Authored.A_POSE else empty_pose()
	var joints := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)
	var order := bind_order()
	var visible_arrays := _empty_arrays()
	var hidden_arrays := _empty_arrays()
	var helper := HumanoidRig.new()
	for copy: int in copies:
		for part: PlaceholderBody.Part in PlaceholderBody.parts(player):
			var target := hidden_arrays if player and PlaceholderBody.is_fp_hidden(part) else visible_arrays
			_add_part(target, helper._make_mesh(part), part, joints, order, smooth)
	helper.free()
	var triangles := 0
	var root := Node3D.new()
	root.name = "Art"
	var armature := Node3D.new()
	armature.name = "Armature"
	root.add_child(armature)
	var skeleton := _skeleton(joints)
	armature.add_child(skeleton)
	for entry: Array in [["Body", visible_arrays], ["Body__fp_hidden", hidden_arrays]]:
		var arrays: Array = entry[1]
		if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = entry[0]
		mesh_instance.mesh = mesh
		skeleton.add_child(mesh_instance)
		mesh_instance.skeleton = NodePath("..")
		mesh_instance.skin = _skin(joints, order)
	_own(root, root)
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var art := CharacterArt.new()
	art.id = &"probe_player" if player else &"probe"
	art.scene = scene
	art.palette = atlas()
	art.triangle_budget = triangles + budget_slack
	return art


## The A-pose: each arm chain swung out about its upper arm joint (the Euler z of the bone).
static func a_pose() -> Dictionary[StringName, Vector3]:
	var pose: Dictionary[StringName, Vector3] = {}
	pose[&"LeftUpperArm"] = Vector3(0.0, 0.0, -A_POSE_SWING_DEG)
	pose[&"RightUpperArm"] = Vector3(0.0, 0.0, A_POSE_SWING_DEG)
	return pose


## The bind order of the probe GLB: the skeleton's, reversed.
static func bind_order() -> Array[StringName]:
	var out: Array[StringName] = PlaceholderBody.BONE_NAMES.duplicate()
	out.reverse()
	return out


## The palette atlas: five flat swatches, SWATCH_PX wide, one per Paint.
static func atlas() -> ImageTexture:
	var image := Image.create_empty(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	for paint: int in SWATCHES.size():
		image.fill_rect(Rect2i(paint * SWATCH_PX, 0, SWATCH_PX, ATLAS_SIZE.y), SWATCHES[paint])
	return ImageTexture.create_from_image(image)


## The vertices of the part `part` of `rig`'s primitives as the rig's view proxy draws them,
## rig space, in the order the fixture's mesh holds them (the order of
## PlaceholderBody.parts()): the expected skinned positions of a rigid probe at the rig's
## pose. With `hidden` set, the FP-hidden mesh's parts only; with `hidden` false the visible
## mesh's (every part on a rig that is not the player's).
static func proxy_vertices(rig: HumanoidRig, player: bool, hidden: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_rig := rig.global_transform.affine_inverse()
	for part: PlaceholderBody.Part in PlaceholderBody.parts(player):
		if player and PlaceholderBody.is_fp_hidden(part) != hidden:
			continue
		var proxy := rig.find_child(String(part.name), true, false) as MeshInstance3D
		var arrays := proxy.mesh.surface_get_arrays(0)
		out.append_array((to_rig * proxy.global_transform) * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array))
	return out


## No bone turned: the table's rest.
static func empty_pose() -> Dictionary[StringName, Vector3]:
	var pose: Dictionary[StringName, Vector3] = {}
	return pose


static func _empty_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return arrays


## Bake `part`'s primitive into `arrays`: its vertices on the bone at the part's offset and
## rotation, the bone in the authoring pose (`joints`), weighted to the bone.
static func _add_part(arrays: Array, primitive: Mesh, part: PlaceholderBody.Part,
		joints: Dictionary[StringName, Transform3D], order: Array[StringName], smooth: bool) -> void:
	var source := primitive.surface_get_arrays(0)
	var local := Transform3D(PlaceholderBody.euler_basis(part.rot_deg), part.offset)
	var to_rig: Transform3D = joints[part.bone] * local
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base := vertices.size()
	var own := order.find(part.bone)
	var parent_bone: StringName = PlaceholderBody.BONE_PARENT.get(part.bone, &"")
	var parent := order.find(parent_bone) if smooth and parent_bone != &"" and parent_bone != &"Root" else -1
	var rest := PlaceholderBody.pose_globals(empty_pose(), Vector3.ZERO, 1.0)
	var axis := Vector3.ZERO
	if parent >= 0:
		axis = (rest[part.bone].origin - rest[parent_bone].origin).normalized()
	var uv := Vector2((part.paint * SWATCH_PX + SWATCH_PX * 0.5) / ATLAS_SIZE.x, 0.5)
	var local_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var local_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	for i: int in local_vertices.size():
		var v := to_rig * local_vertices[i]
		vertices.append(v)
		normals.append(to_rig.basis * local_normals[i])
		uvs.append(uv)
		# Rigid: all on the bone. Smooth: blended with the parent about the joint (measured
		# in the bone's own rest frame, where the part was authored).
		var parent_share := 0.0
		if parent >= 0:
			var along := (local * local_vertices[i]).dot(axis)
			parent_share = clampf(0.5 - 0.5 * along / BLEND_M, 0.0, 1.0)
		bones.append_array(PackedInt32Array([own, maxi(parent, 0), 0, 0]))
		weights.append_array(PackedFloat32Array([1.0 - parent_share, parent_share, 0.0, 0.0]))
	var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	for index: int in source_indices:
		indices.append(base + index)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices


## The scene's Skeleton3D: the 23 bones at the authored joints (the rest is for the file's
## sake; SkinnedArt reads only the mesh's bind names and poses).
static func _skeleton(joints: Dictionary[StringName, Transform3D]) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for bone: StringName in PlaceholderBody.BONE_NAMES:
		var idx := skeleton.add_bone(bone)
		if PlaceholderBody.BONE_PARENT.has(bone):
			var parent := PlaceholderBody.BONE_PARENT[bone]
			skeleton.set_bone_parent(idx, skeleton.find_bone(parent))
			skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, joints[bone].origin - joints[parent].origin))
		else:
			skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, joints[bone].origin))
	return skeleton


## The Skin of the mesh: a named bind per bone in the bind order, each carrying a roll of
## its own (a Blender bone's axes), which only the joint's position survives.
static func _skin(joints: Dictionary[StringName, Transform3D], order: Array[StringName]) -> Skin:
	var skin := Skin.new()
	for i: int in order.size():
		var roll := Basis(Vector3.UP, 0.3 + 0.1 * i)
		skin.add_named_bind(order[i], Transform3D(roll, joints[order[i]].origin).affine_inverse())
	return skin


static func _own(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(child, root)
