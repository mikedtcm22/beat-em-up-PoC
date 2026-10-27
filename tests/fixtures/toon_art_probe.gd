extends RefCounted
## A procedural skinned art fixture for the toon look (Milestone 4, P1-toon): a two-bone capsule
## with everything a real art GLB brings to the toon shader, so the art path is exercised before
## any GLB exists (the plan's probe body is P1-chain's): palette UVs on swatches of a small atlas
## (alpha 1 takes damage marks, 0.5 does not), a second UV set (UV2) for the detail mask, the
## baked smooth normal in COLOR (n * 0.5 + 0.5) for the hull, and the rest position and normal in
## CUSTOM0 and CUSTOM1 (RGB float) for the marks. Skinned to a base and a tip bone, so the tip
## can be bent and the hull and the marks seen following it.
##
## The capsule is `HEIGHT` m tall from y 0 to HEIGHT, the tip bone's joint at its middle.

## The fixture's size (m).
const HEIGHT := 1.7
const RADIUS := 0.28
const BASE_BONE := &"Base"
const TIP_BONE := &"Tip"
## The atlas: a swatch is this many pixels across, SWATCHES_PER_ROW to a row (the project's
## palette is 256 x 16 of 8 px swatches).
const ATLAS_SIZE := Vector2i(256, 16)
const SWATCH_PX := 8
const SWATCHES_PER_ROW := 32
## The swatches' slots and colors; the last one takes no damage marks (alpha 0.5).
const SLOT_SKIN := 0
const SLOT_JACKET := 1
const SLOT_TRIM := 2
const SLOT_DARK := 3
const SWATCH_COLORS: Array[Color] = [
	Color(0.86, 0.66, 0.5, 1.0), Color(0.02, 0.5, 0.56, 1.0), Color(0.96, 0.82, 0.14, 1.0), Color(0.07, 0.07, 0.08, 0.5),
]
## The mask's size and its ink stripes (R = 1): every STRIPE_PERIOD px, STRIPE_WIDTH wide.
const MASK_SIZE := 64
const STRIPE_PERIOD := 16
const STRIPE_WIDTH := 3


## The palette atlas, as the pipeline writes it: flat swatches, alpha for the marks.
static func atlas() -> ImageTexture:
	var image := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 0.5, 0.5))
	for slot in SWATCH_COLORS.size():
		var origin := Vector2i((slot % SWATCHES_PER_ROW) * SWATCH_PX, (slot / SWATCHES_PER_ROW) * SWATCH_PX)
		image.fill_rect(Rect2i(origin, Vector2i(SWATCH_PX, SWATCH_PX)), SWATCH_COLORS[slot])
	return ImageTexture.create_from_image(image)


## A detail mask: ink stripes (R = 1) across the second UV set's U, black elsewhere.
static func mask() -> ImageTexture:
	var image := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	for x in MASK_SIZE:
		if x % STRIPE_PERIOD < STRIPE_WIDTH:
			for y in MASK_SIZE:
				image.set_pixel(x, y, Color(1.0, 0.0, 0.0, 1.0))
	return ImageTexture.create_from_image(image)


## The UV of the centre of palette swatch `slot`.
static func swatch_uv(slot: int) -> Vector2:
	var cell := Vector2((slot % SWATCHES_PER_ROW) * SWATCH_PX + SWATCH_PX / 2, (slot / SWATCHES_PER_ROW) * SWATCH_PX + SWATCH_PX / 2)
	return cell / Vector2(ATLAS_SIZE)


## The skinned mesh: a capsule with the arrays above, in the rest pose. The bottom third is the
## jacket, the middle skin and the top trim; the very top is dark (no marks).
static func mesh() -> ArrayMesh:
	var source := CapsuleMesh.new()
	source.radius = RADIUS
	source.height = HEIGHT
	source.radial_segments = 24
	source.rings = 12
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	for i in vertices.size():
		# The capsule is centred on the origin: stand it on y = 0.
		var v := vertices[i] + Vector3(0.0, HEIGHT * 0.5, 0.0)
		vertices[i] = v
		var n := normals[i]
		colors.append(Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
		var along := v.y / HEIGHT
		var slot := SLOT_JACKET if along < 0.3 else (SLOT_SKIN if along < 0.7 else (SLOT_TRIM if along < 0.9 else SLOT_DARK))
		uv.append(swatch_uv(slot))
		uv2.append(Vector2(atan2(v.z, v.x) / TAU + 0.5, along))
		var tip := smoothstep(0.4, 0.6, along)
		bones.append_array([0, 1, 0, 0])
		weights.append_array([1.0 - tip, tip, 0.0, 0.0])
		custom0.append_array([v.x, v.y, v.z])
		custom1.append_array([n.x, n.y, n.z])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_CUSTOM1] = custom1
	var flags := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return out


## The fixture under `parent`: a Skeleton3D with the base and tip bones (the tip joint at
## HEIGHT / 2) and the mesh skinned to it, drawn with `material` and `hull` (a hull may be null).
## The tip is bent `bend_deg` about X. Returns the skeleton (its child is the mesh instance).
static func build(parent: Node3D, material: Material, hull: Material, bend_deg: float = 0.0) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var base := skeleton.add_bone(BASE_BONE)
	var tip := skeleton.add_bone(TIP_BONE)
	skeleton.set_bone_parent(tip, base)
	skeleton.set_bone_rest(base, Transform3D.IDENTITY)
	skeleton.set_bone_rest(tip, Transform3D(Basis.IDENTITY, Vector3(0.0, HEIGHT * 0.5, 0.0)))
	skeleton.reset_bone_poses()
	skeleton.set_bone_pose_rotation(tip, Quaternion(Vector3.RIGHT, deg_to_rad(bend_deg)))
	parent.add_child(skeleton)
	var skin := Skin.new()
	skin.add_named_bind(BASE_BONE, Transform3D.IDENTITY)
	skin.add_named_bind(TIP_BONE, Transform3D(Basis.IDENTITY, Vector3(0.0, -HEIGHT * 0.5, 0.0)))
	var instance := MeshInstance3D.new()
	instance.name = "ArtFixture"
	instance.mesh = mesh()
	instance.skin = skin
	instance.material_override = material
	instance.material_overlay = hull
	skeleton.add_child(instance)
	instance.skeleton = NodePath("..")
	return skeleton
