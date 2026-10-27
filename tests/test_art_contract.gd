extends GutTest
## The asset contract of the art pipeline (M4-plan Part C §2.6 as amended by Part A A3, package P1-chain), tested on every
## character GLB the project ships and on the pipeline's own probe bodies: the chain's output is only as good as these checks.
## One GLB is read through Godot's importer exactly as SkinnedArt will read it: the Skeleton3D's bones, the Skin's named
## binds (their inverse origins are the exported joints), each mesh's arrays. Rows: A1 (23 named binds, no neutral_bone, the
## joints within 1 mm of the table chained through the arms' swing, faces -Z, soles at y 0, at most 4 normalised influences,
## every vertex weighted, none on Root), A2 (triangle budgets), A3 (4-6 swatches from the shared atlas, none in the red band),
## A5 (the fists fill the fist box), A13 (every exported file has an ASSETS.md row, a fixture matches its report).

const JOINTS_PATH := "res://tools/pipeline/joints.json"
const PALETTE_DIR := "res://assets/source/palette"
const ATLAS_PATH := "res://assets/export/palette/palette_atlas.png"
const ASSETS_MD := "res://ASSETS.md"
const EXPORT_DIR := "res://assets/export"
const CONCEPTS_DIR := "res://assets/source/concepts"
const CHARACTERS_DIR := "res://assets/export/characters"
const FIXTURES: Array[String] = [
	"res://tests/fixtures/art/probe_body.glb",
	"res://tests/fixtures/art/probe_body_rest.glb",
]
const PROBE_REPORT := "res://tests/fixtures/art/probe_report.json"
## Budgets per character id (SPEC §10: 15,000 enemy, 30,000 player); the probe bodies stand in for the player.
const BUDGETS: Dictionary[String, int] = {"punk": 15000, "player": 30000, "probe_body": 30000}
const TOLERANCE_JOINT := 0.001
const FIST_CENTROID_TOLERANCE := 0.015
const FIST_EXTENT_TOLERANCE := 0.2
const SOLE_TOLERANCE := 0.005
## The mean dot of a mesh's decoded hull normal (COLOR) with its NORMAL: the right axes measure 0.92-0.96 on the smoke Punk
## and the probe bodies (a normal baked in Blender's Z-up axes measured 0.31-0.34).
const HULL_AGREE_MIN := 0.85
## The atlas alpha classes (tools/pipeline/gen_palette.py; game/fx/toon.gdshader decodes them with step(0.75) and step(0.9)).
const ALPHA_CLOTHES := 1.0
const ALPHA_SKIN := 0.8
const ALPHA_NONE := 0.5
const SWATCH_MIN := 4
const SWATCH_MAX := 6
## F-punk: a character may spend one more SLOT than it has flat colours (the Punk's lens is the cap's yellow on its own slot, so it
## takes no damage marks); the number of flat COLOURS stays 4-6 (Part B A3, J6).
const SWATCH_SLOTS_MAX := 7
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
const SWATCH_PX := 8
const ARM_BONES: Array[String] = ["UpperArm", "LowerArm", "Hand"]
## The share of a limb's triangles that may face their bone (creases, the crotch) before the limb is called inside out.
const INSIDE_OUT_MAX := 0.15
## How far (m) the arm's cap must bulge toward the shoulder past the cut (the dome is 0.04 m high).
const DOME_MIN_M := 0.03

var _cache: Dictionary[String, Dictionary] = {}
var _table: Dictionary = {}


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(JOINTS_PATH))


## Every character GLB under test: the fixtures, then every assets/export/characters/<id>/*.glb.
func _glbs() -> Array[String]:
	var out: Array[String] = FIXTURES.duplicate()
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		var d := DirAccess.open("%s/%s" % [CHARACTERS_DIR, sub])
		if d == null:
			continue
		for f: String in d.get_files():
			if f.ends_with(".glb"):
				out.append("%s/%s/%s" % [CHARACTERS_DIR, sub, f])
	return out


## The character id a GLB path stands for: tests/fixtures/art/probe_body_rest.glb -> probe_body, .../punk/punk_rest.glb -> punk.
func _id_of(path: String) -> String:
	var base: String = path.get_file().get_basename()
	if base.ends_with("_rest"):
		base = base.trim_suffix("_rest")
	for id: String in BUDGETS:
		if base == id or base.begins_with(id + "_"):
			return id
	return base


func _is_rest_variant(path: String) -> bool:
	return path.get_file().get_basename().ends_with("_rest")


func _table_joint(bone: String) -> Vector3:
	for b: Dictionary in _table.bones:
		if b.name == bone:
			var g: Array = b.rest_global
			return Vector3(g[0], g[1], g[2])
	return Vector3.INF


func _table_bones() -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in _table.bones:
		out.append(b.name)
	return out


## What the importer made of a GLB, once per path: the skeleton, the meshes with their arrays and skins, the exported joints.
func _facts(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var facts: Dictionary = {"path": path, "ok": false}
	var scene := load(path) as PackedScene
	if scene == null:
		_cache[path] = facts
		return facts
	var root: Node = scene.instantiate()
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var bone_names: Array[String] = []
	var bone_rests: Dictionary[String, Vector3] = {}
	if skel != null:
		for i: int in skel.get_bone_count():
			bone_names.append(skel.get_bone_name(i))
			bone_rests[skel.get_bone_name(i)] = skel.get_bone_global_rest(i).origin
	facts["bone_names"] = bone_names
	facts["bone_rests"] = bone_rests
	var meshes: Dictionary = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var m: ArrayMesh = mi.mesh as ArrayMesh
		var arrays: Array = m.surface_get_arrays(0)
		var skin: Skin = mi.skin
		var bind_names: Array[String] = []
		var joints: Dictionary[String, Vector3] = {}
		if skin != null:
			for i: int in skin.get_bind_count():
				var n := String(skin.get_bind_name(i))
				bind_names.append(n)
				joints[n] = skin.get_bind_pose(i).affine_inverse().origin
		meshes[String(mi.name)] = {
			"arrays": arrays, "skin": skin, "bind_names": bind_names, "joints": joints,
			"surfaces": m.get_surface_count(), "xf": mi.transform,
		}
	facts["meshes"] = meshes
	facts["ok"] = skel != null and not meshes.is_empty()
	root.free()
	_cache[path] = facts
	return facts


func _body(path: String) -> Dictionary:
	var f := _facts(path)
	return (f.meshes as Dictionary).get("Body", {})


func _triangles(mesh: Dictionary) -> int:
	return (mesh.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


## The exported joints of a GLB (the Body's skin binds), by bone name.
func _joints(path: String) -> Dictionary[String, Vector3]:
	var body := _body(path)
	if body.is_empty():
		return {}
	return body.joints


func test_every_art_glb_loads_and_has_a_body() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		assert_true(f.ok, "%s imports as a scene with a skeleton and meshes (run godot --headless --import --quit)" % path)
		if not f.ok:
			continue
		var names: Array = (f.meshes as Dictionary).keys()
		names.sort()
		for n: String in names:
			assert_true(n in ["Body", "Body__fp_hidden", "Body__fp_torso"], "%s: mesh %s is named Body, Body__fp_hidden or Body__fp_torso" % [path, n])
			assert_eq((f.meshes[n] as Dictionary).surfaces, 1, "%s %s: one surface" % [path, n])
			assert_true(((f.meshes[n] as Dictionary).xf as Transform3D).is_equal_approx(Transform3D.IDENTITY), "%s %s: at the skeleton's origin" % [path, n])
		assert_true("Body" in names, "%s has a Body" % path)
		if _id_of(path) == "punk":
			assert_eq(names, ["Body"], "%s: the Punk is one mesh" % path)
		if _id_of(path) == "probe_body":
			assert_eq(names, ["Body", "Body__fp_hidden"], "%s: the probe stands in for the player: visible and first-person-hidden parts" % path)
		if _id_of(path) == "player":
			assert_eq(names, ["Body", "Body__fp_hidden", "Body__fp_torso"], "%s: the hero is the visible body, the first-person-hidden upper body and the torso (the belly and belt: fp_knockdown_hide_torso hides only that)" % path)


func test_the_skeleton_has_the_23_table_bones_and_no_neutral_bone() -> void:
	var expected := _table_bones()
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var names: Array[String] = f.bone_names
		assert_eq(names.size(), 23, "%s: 23 bones" % path)
		assert_false("neutral_bone" in names, "%s: no neutral_bone (an unweighted vertex)" % path)
		for b: String in expected:
			assert_true(b in names, "%s has the bone %s" % [path, b])
		for n: String in (f.meshes as Dictionary):
			var mesh: Dictionary = f.meshes[n]
			var binds: Array[String] = mesh.bind_names
			assert_eq(binds.size(), 23, "%s %s: 23 named binds" % [path, n])
			assert_false("neutral_bone" in binds, "%s %s: no neutral_bone bind" % [path, n])
			assert_false("" in binds, "%s %s: every bind is named (skins/use_named_skins)" % [path, n])
			for b: String in expected:
				assert_true(b in binds, "%s %s: bind %s" % [path, n, b])


## A3: every exported joint is the table joint chained through the arm swing. Off the arm chains the joints are the table's
## (within 1 mm); each arm chain is one straight limb along a measured direction d: p_LowerArm = p_UpperArm + |table|*d and
## p_Hand = p_LowerArm + |table|*d, the upper-arm joint itself on the table.
func test_the_exported_joints_are_the_table_chained_through_the_swing() -> void:
	for path: String in _glbs():
		var joints := _joints(path)
		if joints.is_empty():
			continue
		for bone: String in _table_bones():
			var is_arm_chain: bool = (bone.ends_with("LowerArm") or bone.ends_with("Hand"))
			if is_arm_chain:
				continue
			assert_lt(joints[bone].distance_to(_table_joint(bone)), TOLERANCE_JOINT, "%s: %s is on the table" % [path, bone])
		for side: String in ["Left", "Right"]:
			var ua: Vector3 = joints[side + "UpperArm"]
			var la: Vector3 = joints[side + "LowerArm"]
			var hd: Vector3 = joints[side + "Hand"]
			var t_ua := _table_joint(side + "UpperArm")
			var len_ua: float = (_table_joint(side + "LowerArm") - t_ua).length()
			var len_la: float = (_table_joint(side + "Hand") - _table_joint(side + "LowerArm")).length()
			var d: Vector3 = (la - ua).normalized()
			assert_lt(la.distance_to(ua + d * len_ua), TOLERANCE_JOINT, "%s: %sLowerArm = UpperArm + R*(0,-0.29,0)" % [path, side])
			assert_lt(hd.distance_to(la + d * len_la), TOLERANCE_JOINT, "%s: %sHand = LowerArm + R*(0,-0.27,0), a straight chain" % [path, side])
			var swing: float = rad_to_deg(Vector3.DOWN.angle_to(d))
			assert_between(swing, 0.0, 60.0, "%s: %s arm swing %.2f deg is an A-pose, not a T-pose" % [path, side, swing])
			if _is_rest_variant(path):
				assert_lt(swing, 0.1, "%s: the arms-down bake hangs (R = identity)" % path)
			var outward: float = d.x * (1.0 if side == "Right" else -1.0)
			assert_gt(outward, -0.0001, "%s: the %s arm swings outward (or hangs)" % [path, side])


func test_the_skeleton_rest_agrees_with_the_binds() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var rests: Dictionary[String, Vector3] = f.bone_rests
		var joints := _joints(path)
		for bone: String in rests:
			assert_lt(rests[bone].distance_to(joints[bone]), TOLERANCE_JOINT,
					"%s: %s: the skeleton's rest and the skin's binds are one pose (blender-godot §3.8, row 1)" % [path, bone])


## At most 4 influences, normalised, every vertex weighted, none on Root.
func test_weights_are_four_normalised_influences_none_on_root() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		for n: String in (f.meshes as Dictionary):
			var mesh: Dictionary = f.meshes[n]
			var arrays: Array = mesh.arrays
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var verts: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			assert_eq(bones.size(), verts * 4, "%s %s: 4 bone slots per vertex (no 8-weight arrays)" % [path, n])
			var binds: Array[String] = mesh.bind_names
			var worst_sum := 0.0
			var root_weight := 0.0
			var unweighted := 0
			for v: int in verts:
				var s := 0.0
				for k: int in 4:
					var w: float = weights[v * 4 + k]
					s += w
					if w > 0.0 and binds[bones[v * 4 + k]] == "Root":
						root_weight = maxf(root_weight, w)
				worst_sum = maxf(worst_sum, absf(s - 1.0))
				if s < 0.99:
					unweighted += 1
			assert_eq(unweighted, 0, "%s %s: every vertex is weighted" % [path, n])
			assert_lt(worst_sum, 0.002, "%s %s: weights sum to 1" % [path, n])
			assert_eq(root_weight, 0.0, "%s %s: nothing is weighted to Root (it never moves)" % [path, n])


func test_the_character_faces_minus_z_with_its_soles_on_the_floor() -> void:
	for path: String in _glbs():
		var body := _body(path)
		if body.is_empty():
			continue
		var verts: PackedVector3Array = body.arrays[Mesh.ARRAY_VERTEX]
		for side: float in [-1.0, 1.0]:
			var lowest := INF
			for v: Vector3 in verts:
				if v.x * side > 0.02 and v.y < 0.12:
					lowest = minf(lowest, v.y)
			assert_between(lowest, -SOLE_TOLERANCE, SOLE_TOLERANCE, "%s: the %s sole is at y = 0 (+-5 mm), got %.4f" % [path, "left" if side < 0.0 else "right", lowest])
			var z_min := INF
			var z_max := -INF
			for v: Vector3 in verts:
				if v.x * side > 0.02 and v.y < lowest + 0.012:
					z_min = minf(z_min, v.z)
					z_max = maxf(z_max, v.z)
			assert_lt(z_min, -0.2, "%s: the toe reaches forward to -Z (z %.3f)" % [path, z_min])
			assert_gt(z_max, 0.04, "%s: the heel sits behind the ankle at +Z (z %.3f)" % [path, z_max])
			assert_lt(absf(z_min + 0.25), 0.07, "%s: the toe tip is near the table's -0.25 (z %.3f)" % [path, z_min])


func test_triangle_budgets() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var total := 0
		for n: String in (f.meshes as Dictionary):
			total += _triangles(f.meshes[n])
		var budget: int = BUDGETS.get(_id_of(path), 15000)
		assert_true(total <= budget, "%s: %d triangles against its budget %d" % [path, total, budget])
		assert_gt(total, 500, "%s: not an empty mesh" % path)


## A face is a swatch: every vertex of a triangle sits on one swatch centre of the 256x16 atlas, and a character uses 4-6 flat colours (at most 7
## slots: see SWATCH_SLOTS_MAX), none in the red band (hue 345-15 degrees with saturation above 0.5: red is for blood and the warning).
func test_palette_uvs_sit_on_swatch_centres_few_and_never_red() -> void:
	var atlas := _atlas_image()
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var slots: Dictionary = {}
		for n: String in (f.meshes as Dictionary):
			var arrays: Array = (f.meshes[n] as Dictionary).arrays
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			assert_eq(uvs.size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "%s %s: UV1 for every vertex" % [path, n])
			var bad_centres := 0
			var mixed_faces := 0
			for t: int in index.size() / 3:
				var a := uvs[index[t * 3]]
				var b := uvs[index[t * 3 + 1]]
				var c := uvs[index[t * 3 + 2]]
				if not (a.is_equal_approx(b) and b.is_equal_approx(c)):
					mixed_faces += 1
			for uv: Vector2 in uvs:
				var col := uv.x * SWATCH_COLUMNS - 0.5
				var row := uv.y * SWATCH_ROWS - 0.5
				if absf(col - roundf(col)) > 0.01 or absf(row - roundf(row)) > 0.01:
					bad_centres += 1
				slots[int(roundf(row)) * SWATCH_COLUMNS + int(roundf(col))] = true
			assert_eq(bad_centres, 0, "%s %s: every UV is a swatch centre" % [path, n])
			assert_eq(mixed_faces, 0, "%s %s: each face is on one swatch" % [path, n])
		var colours: Dictionary = {}
		for slot: int in slots:
			colours[_swatch_color(atlas, slot).to_html(false)] = true
		assert_between(colours.size(), SWATCH_MIN, SWATCH_MAX, "%s: %d flat colours used" % [path, colours.size()])
		assert_between(slots.size(), SWATCH_MIN, SWATCH_SLOTS_MAX, "%s: %d swatches used" % [path, slots.size()])
		for slot: int in slots:
			var c := _swatch_color(atlas, slot)
			assert_ne(c, Color(1, 0, 1), "%s: slot %d is defined (not the magenta of an unused slot)" % [path, slot])
			assert_false(_in_red_band(c), "%s: slot %d (%s) is in the red band" % [path, slot, c.to_html(false)])


func test_hull_normals_and_the_detail_uv_are_there() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var by_position: Dictionary[Vector3i, Vector3] = {}
		var worst_split := 0.0
		for n: String in (f.meshes as Dictionary):
			var arrays: Array = (f.meshes[n] as Dictionary).arrays
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			assert_eq(colors.size(), verts.size(), "%s %s: COLOR (hull_normal) on every vertex" % [path, n])
			if colors.size() != verts.size():
				continue
			var uv2 := PackedVector2Array()
			if arrays[Mesh.ARRAY_TEX_UV2] != null:
				uv2 = arrays[Mesh.ARRAY_TEX_UV2]
			if _id_of(path) == "probe_body":
				assert_eq(uv2.size(), verts.size(), "%s %s: UV2 (detail) is present" % [path, n])
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var agree := 0.0
			var agree_z_up := 0.0
			var agree_z_down := 0.0
			for i: int in verts.size():
				var c := colors[i]
				var nrm := Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b * 2.0 - 1.0)
				if i % 97 == 0:
					assert_between(nrm.length(), 0.97, 1.03, "%s %s vertex %d: a unit normal" % [path, n, i])
				var key := Vector3i((verts[i] * 100000.0).round())
				if by_position.has(key):
					worst_split = maxf(worst_split, (by_position[key] - nrm).length())
				else:
					by_position[key] = nrm
				# the axis frame (slice-g2-01): COLOR is the hull direction in the file's Y-up axes, like NORMAL
				if normals.size() == verts.size():
					var dir := nrm.normalized()
					agree += dir.dot(normals[i])
					agree_z_up += Vector3(dir.x, dir.z, -dir.y).dot(normals[i])
					agree_z_down += Vector3(dir.x, -dir.z, dir.y).dot(normals[i])
			if normals.size() == verts.size() and not verts.is_empty():
				agree /= verts.size()
				agree_z_up /= verts.size()
				agree_z_down /= verts.size()
				gut.p("ART-CONTRACT hull axis: %s %s: mean dot(COLOR, NORMAL) as read %.3f (read as Blender Z-up %.3f, as Z-down %.3f)" % [path.get_file(), n, agree, agree_z_up, agree_z_down])
				assert_gt(agree, HULL_AGREE_MIN, "%s %s: the hull normal (COLOR) agrees with NORMAL on average, so it is in the same Y-up axes (baked in Blender's Z-up it measures 0.3)" % [path, n])
				assert_gt(agree, agree_z_up, "%s %s: COLOR reads better as (x, y, z) than as Blender's Z-up axes (x, z, -y)" % [path, n])
				assert_gt(agree, agree_z_down, "%s %s: COLOR reads better as (x, y, z) than as (x, -z, y)" % [path, n])
		assert_lt(worst_split, 0.03, "%s: vertices at one position share one hull normal, across both parts too (no cracks)" % path)


## F-punk (M4-plan A18): the Punk's detail mask is a 1k PNG with ink in R only (lines, never shading), and punk.glb and punk_rest.glb
## carry the UV2 it is baked on, every vertex of it inside the unit square.
func test_the_punk_detail_mask_is_a_1k_ink_only_png_on_the_punks_uv2() -> void:
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	assert_not_null(art.detail_mask, "punk_art.tres carries the detail mask")
	var image := art.detail_mask.get_image()
	assert_eq(image.get_size(), Vector2i(1024, 1024), "1k")
	var ink := 0
	var other := 0.0
	var sum := 0.0
	for y: int in range(0, 1024, 2):
		for x: int in range(0, 1024, 2):
			var c := image.get_pixel(x, y)
			sum += c.r
			other = maxf(other, maxf(c.g, c.b))
			if c.r > 0.5:
				ink += 1
	var mean := sum / (512.0 * 512.0)
	print("ART-CONTRACT punk_detail.png: mean ink %.4f, %d of 262144 sampled texels over 0.5" % [mean, ink])
	assert_lt(other, 0.01, "G and B hold nothing (R is the ink)")
	assert_gt(ink, 500, "there are lines")
	assert_lt(mean, 0.08, "and they are lines, not a wash (shading would raise the mean)")
	for name: String in ["punk.glb", "punk_rest.glb"]:
		var path := "res://assets/export/characters/punk/%s" % name
		var f := _facts(path)
		if not f.ok:
			continue
		for n: String in (f.meshes as Dictionary):
			var arrays: Array = (f.meshes[n] as Dictionary).arrays
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			assert_eq(uv2.size(), verts.size(), "%s %s: UV2 (detail) on every vertex" % [path, n])
			var outside := 0
			for uv: Vector2 in uv2:
				if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
					outside += 1
			assert_eq(outside, 0, "%s %s: UV2 inside the unit square" % [path, n])


## A5: the fist fills the fist box. Vertices with weight >= 0.9 on a Hand bone, un-swung to the table's frame (the hand's
## measured direction turned back to hanging about the wrist joint), area-weighted centroid within 15 mm of the box centre,
## extents within 20% of 0.1 x 0.118 x 0.116 m.
func test_the_fists_fill_the_fist_box() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var body := _body(path)
		var joints := _joints(path)
		var arrays: Array = body.arrays
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var binds: Array[String] = body.bind_names
		for box: Dictionary in _table.fist_boxes:
			var side: String = box.side
			var hand := side + "Hand"
			var d: Vector3 = (joints[hand] - joints[side + "LowerArm"]).normalized()
			var basis := Basis(Quaternion(d, Vector3.DOWN))
			var wrist: Vector3 = joints[hand]
			var table_wrist := _table_joint(hand)
			var fist: PackedByteArray = PackedByteArray()
			fist.resize(verts.size())
			for v: int in verts.size():
				var w := 0.0
				for k: int in 4:
					if binds[bones[v * 4 + k]] == hand:
						w += weights[v * 4 + k]
				fist[v] = 1 if w >= 0.9 else 0
			var lo := Vector3.INF
			var hi := -Vector3.INF
			var area := 0.0
			var centroid := Vector3.ZERO
			for t: int in index.size() / 3:
				var i0 := index[t * 3]
				var i1 := index[t * 3 + 1]
				var i2 := index[t * 3 + 2]
				if fist[i0] == 0 or fist[i1] == 0 or fist[i2] == 0:
					continue
				var p0 := table_wrist + basis * (verts[i0] - wrist)
				var p1 := table_wrist + basis * (verts[i1] - wrist)
				var p2 := table_wrist + basis * (verts[i2] - wrist)
				var a := (p1 - p0).cross(p2 - p0).length() * 0.5
				area += a
				centroid += (p0 + p1 + p2) / 3.0 * a
				for p: Vector3 in [p0, p1, p2]:
					lo = lo.min(p)
					hi = hi.max(p)
			assert_gt(area, 0.001, "%s: %s fist found" % [path, side])
			if area <= 0.001:
				continue
			centroid /= area
			var c: Array = box.center_rest_global
			var want := Vector3(c[0], c[1], c[2])
			assert_lt(centroid.distance_to(want), FIST_CENTROID_TOLERANCE, "%s: the %s fist's centroid is %.1f mm from the fist box" % [path, side, centroid.distance_to(want) * 1000.0])
			var sz: Array = box.size
			var ext := hi - lo
			for axis: int in 3:
				assert_between(ext[axis] / float(sz[axis]), 1.0 - FIST_EXTENT_TOLERANCE, 1.0 + FIST_EXTENT_TOLERANCE, "%s: %s fist extent on axis %d is %.3f against %.3f" % [path, side, axis, ext[axis], sz[axis]])


## The first-person split: the hidden part is the upper body (everything at or above the waist cut), and the visible body has
## no open loop left (every cut closed by an inward cap), welded by position.
func test_the_first_person_split_is_closed_and_above_the_waist() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok or not (f.meshes as Dictionary).has("Body__fp_hidden"):
			continue
		var hidden: Dictionary = f.meshes["Body__fp_hidden"]
		var verts: PackedVector3Array = hidden.arrays[Mesh.ARRAY_VERTEX]
		var lowest := INF
		for v: Vector3 in verts:
			lowest = minf(lowest, v.y)
		assert_gt(lowest, _table_joint("Chest").y - 0.002, "%s: the hidden part starts at the Chest joint (y %.3f)" % [path, lowest])
		assert_eq(_open_edges(_body(path)), 0, "%s: the visible body has no open loop: every cut is capped" % path)
		if (f.meshes as Dictionary).has("Body__fp_torso"):
			# the torso is the band between the hip joint and the Chest joint, closed on its own like the body
			var torso: Dictionary = f.meshes["Body__fp_torso"]
			var tv: PackedVector3Array = torso.arrays[Mesh.ARRAY_VERTEX]
			var t_low := INF
			var t_high := -INF
			for v: Vector3 in tv:
				t_low = minf(t_low, v.y)
				t_high = maxf(t_high, v.y)
			assert_gt(t_low, _table_joint("LeftUpperLeg").y - 0.002, "%s: the torso starts at the hip joint (y %.3f)" % [path, t_low])
			assert_lt(t_high, _table_joint("Chest").y + 0.002, "%s: and ends at the Chest joint (y %.3f)" % [path, t_high])
			assert_eq(_open_edges(torso), 0, "%s: the torso has no open loop either" % path)


## The limbs are the right way out: a triangle of a leg or a foot faces away from its bone. The first split of the hero
## recalculated the body's normals as a whole and turned the legs, the feet and part of the hips inside out: 65-98% of their triangles
## faced the bone, the base pass culled them and the hull drew the near wall as a black fill (the front kick, the look-down). A leg
## that is right measures 0-7% (the creases and the crotch face the other way); the bar is 15%. (A forearm is not measured: the Punk's
## gauntlet cuff flares, so a good forearm faces its bone in 17-26%.)
func test_no_limb_is_inside_out_its_triangles_face_away_from_their_bone() -> void:
	for path: String in _glbs():
		var f := _facts(path)
		if not f.ok:
			continue
		var child_of: Dictionary[String, String] = {}
		for b: Dictionary in _table.bones:
			if String(b.parent) != "":
				child_of[String(b.parent)] = String(b.name)
		var rests: Dictionary[String, Vector3] = f.bone_rests
		for n: String in (f.meshes as Dictionary):
			var mesh: Dictionary = f.meshes[n]
			var arrays: Array = mesh.arrays
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var binds: Array[String] = mesh.bind_names
			var inward: Dictionary[String, int] = {}
			var total: Dictionary[String, int] = {}
			for t: int in index.size() / 3:
				var share: Dictionary[int, float] = {}
				for k: int in 3:
					var v := index[t * 3 + k]
					for s: int in 4:
						share[bones[v * 4 + s]] = share.get(bones[v * 4 + s], 0.0) + weights[v * 4 + s]
				var best := -1
				var best_w := 0.0
				for bind: int in share:
					if share[bind] > best_w:
						best_w = share[bind]
						best = bind
				var bone := binds[best]
				if not (bone.ends_with("UpperLeg") or bone.ends_with("LowerLeg") or bone.ends_with("Foot")):
					continue
				var a := verts[index[t * 3]]
				var b := verts[index[t * 3 + 1]]
				var c := verts[index[t * 3 + 2]]
				var head: Vector3 = rests[bone]
				var tail: Vector3 = rests[child_of[bone]]
				var axis := tail - head
				var length := axis.length()
				axis /= length
				var rel := (a + b + c) / 3.0 - head
				var radial := rel - axis * clampf(rel.dot(axis), 0.0, length)
				if radial.length() < 0.01:
					continue
				# Godot's front faces wind clockwise, so the outward normal is (c - a) x (b - a)
				var normal := (c - a).cross(b - a)
				if normal.length() < 1e-10:
					continue
				total[bone] = total.get(bone, 0) + 1
				if normal.normalized().dot(radial.normalized()) < -0.2:
					inward[bone] = inward.get(bone, 0) + 1
			for bone: String in total:
				if total[bone] < 100:
					continue
				var share_in := float(inward.get(bone, 0)) / total[bone]
				assert_lt(share_in, INSIDE_OUT_MAX, "%s %s %s: %d of %d triangles face the bone (%.0f%%): the limb is inside out" % [path, n, bone, inward.get(bone, 0), total[bone], share_in * 100.0])


## The hero's upper arms end in a dome that bulges toward the shoulder (the first-person split's cut: M3's Elbow capsule has a
## rounded end there, the first version had a flat inward cap): the visible mesh reaches at least DOME_MIN_M past the cut plane (the
## upper-arm joint plus half the bone's length along it) toward the shoulder. Only the hero is cut this way.
func test_the_upper_arm_cut_is_a_dome_that_bulges_toward_the_shoulder() -> void:
	for path: String in _glbs():
		if _id_of(path) != "player":
			continue
		var f := _facts(path)
		if not f.ok:
			continue
		var rests: Dictionary[String, Vector3] = f.bone_rests
		var body := _body(path)
		var verts: PackedVector3Array = body.arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = body.arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = body.arrays[Mesh.ARRAY_WEIGHTS]
		var binds: Array[String] = body.bind_names
		for side: String in ["Left", "Right"]:
			var ua: Vector3 = rests[side + "UpperArm"]
			var axis: Vector3 = rests[side + "LowerArm"] - ua
			var length := axis.length()
			axis /= length
			var reach := INF
			for v: int in verts.size():
				var w := 0.0
				for s: int in 4:
					if binds[bones[v * 4 + s]] == side + "UpperArm":
						w += weights[v * 4 + s]
				if w >= 0.5:
					reach = minf(reach, (verts[v] - ua).dot(axis))
			var cut := length * 0.5
			assert_lt(reach, cut - DOME_MIN_M, "%s: the %s upper arm's visible part reaches %.3f m along the arm, the cut is at %.3f: a dome of at least %.0f mm bulges toward the shoulder" % [path, side.to_lower(), reach, cut, DOME_MIN_M * 1000.0])


## Boundary edges of a mesh (an edge used by one triangle), counting vertices at one position as one vertex.
func _open_edges(mesh: Dictionary) -> int:
	var verts: PackedVector3Array = mesh.arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = mesh.arrays[Mesh.ARRAY_INDEX]
	var key_of: Dictionary[Vector3i, int] = {}
	var ids := PackedInt32Array()
	ids.resize(verts.size())
	for i: int in verts.size():
		var k := Vector3i((verts[i] * 10000.0).round())
		if not key_of.has(k):
			key_of[k] = key_of.size()
		ids[i] = key_of[k]
	var uses: Dictionary[Vector2i, int] = {}
	for t: int in index.size() / 3:
		for e: int in 3:
			var a := ids[index[t * 3 + e]]
			var b := ids[index[t * 3 + (e + 1) % 3]]
			var key := Vector2i(mini(a, b), maxi(a, b))
			uses[key] = uses.get(key, 0) + 1
	var open := 0
	for key: Vector2i in uses:
		if uses[key] == 1:
			open += 1
	return open


## The palette atlas is the shared palette JSON made real: 256x16, every swatch at its slot's centre, alpha the damage class:
## 1.0 clothes marks, 0.8 skin marks (`"skin": true`, slots 6-9), 0.5 none (slice-g2-07).
func test_the_palette_atlas_is_the_palette_json_made_real() -> void:
	var atlas := _atlas_image()
	assert_not_null(atlas, "the atlas imports")
	if atlas == null:
		return
	assert_eq(atlas.get_size(), Vector2i(SWATCH_COLUMNS * SWATCH_PX, SWATCH_ROWS * SWATCH_PX), "256x16")
	var seen: Dictionary[int, String] = {}
	var dir := DirAccess.open(PALETTE_DIR)
	assert_not_null(dir, "assets/source/palette exists")
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [PALETTE_DIR, file]))
		var lo: int = pal.slot_range[0]
		var hi: int = pal.slot_range[1]
		for sw: Dictionary in pal.swatches:
			var slot: int = sw.slot
			assert_between(slot, lo, hi, "%s: slot %d is inside the file's range %d-%d" % [file, slot, lo, hi])
			assert_false(seen.has(slot), "%s: slot %d is already defined by %s" % [file, slot, seen.get(slot, "")])
			seen[slot] = file
			var want := Color.html(sw.srgb)
			var got := _swatch_color(atlas, slot)
			assert_almost_eq(got.r, want.r, 0.005, "%s slot %d red" % [file, slot])
			assert_almost_eq(got.g, want.g, 0.005, "%s slot %d green" % [file, slot])
			assert_almost_eq(got.b, want.b, 0.005, "%s slot %d blue" % [file, slot])
			var skin := bool(sw.get("skin", false))
			var takes := bool(sw.get("marks", true))
			assert_false(skin and not takes, "%s slot %d: a skin swatch takes marks" % [file, slot])
			var want_alpha := ALPHA_NONE if not takes else ALPHA_SKIN if skin else ALPHA_CLOTHES
			var alpha := _swatch_alpha(atlas, slot)
			assert_almost_eq(alpha, want_alpha, 0.01, "%s slot %d: alpha 1.0 takes the clothes' marks, 0.8 the skin's, 0.5 none" % [file, slot])
			# the shader's own decode (toon.gdshader: takes_marks *= step(0.75, a); skin_marks = 1 - step(0.9, a)) gives the same classes
			assert_eq(alpha >= 0.75, takes, "%s slot %d: the shader reads 'takes marks' from the alpha" % [file, slot])
			assert_eq(alpha >= 0.75 and alpha < 0.9, skin, "%s slot %d: the shader reads 'skin' from the alpha" % [file, slot])
			assert_false(_in_red_band(want), "%s slot %d (%s) is in the red band" % [file, slot, sw.srgb])
	assert_gt(seen.size(), 10, "the shared palette is there")


## A13: an ASSETS.md row for every exported file, every concept image, and the pipeline's fixtures.
func test_every_exported_file_has_an_assets_row() -> void:
	var assets := FileAccess.get_file_as_string(ASSETS_MD)
	var missing: Array[String] = []
	for dir_path: String in [EXPORT_DIR, CONCEPTS_DIR, "res://tests/fixtures/art"]:
		for file_path: String in _files_under(dir_path):
			if file_path.ends_with(".import") or file_path.ends_with(".uid") or file_path.ends_with(".gitkeep"):
				continue
			var rel := file_path.trim_prefix("res://")
			if not assets.contains(rel):
				missing.append(rel)
	assert_eq(missing, [] as Array[String], "every file under assets/export, assets/source/concepts and tests/fixtures/art is named in ASSETS.md")


func _files_under(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		out.append("%s/%s" % [dir_path, f])
	for d: String in dir.get_directories():
		out.append_array(_files_under("%s/%s" % [dir_path, d]))
	return out


## The probe fixtures are the chain's output: the committed report names their hashes, and its landmark residual is inside 1 cm.
func test_the_probe_fixtures_match_their_report() -> void:
	assert_true(FileAccess.file_exists(PROBE_REPORT), "the probe report is committed")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROBE_REPORT))
	var outputs: Dictionary = report.outputs
	for path: String in FIXTURES:
		var name := path.get_file()
		assert_true(outputs.has(name), "%s is in the report" % name)
		if outputs.has(name):
			assert_eq(FileAccess.get_sha256(path), outputs[name], "%s is the file the report hashed (rerun tools/pipeline/make_probe_body.py)" % name)
	var fit: Dictionary = report.steps.fit
	assert_true(float(fit.worst_joint_residual.m) <= float(fit.residual_limit_m), "the landmark-warp residual of the mesh stays under 1 cm (A3)")
	assert_true(fit.residual_ok)
	var exported: Dictionary = report.steps.export.variants.apose
	assert_false(exported.neutral_bone)
	assert_eq(int(exported.unweighted), 0)
	assert_lt(float(exported.worst_joint_error_mm), 1.0, "joints within 1 mm of the chained table, as Blender read the file back")
	assert_eq(String((exported.facing as Dictionary).axis), "-Z")


## Each shipped character's committed chain report(s) (assets/source/characters/<id>/report*/report.json) hash the GLBs that
## are in assets/export/characters/<id>/: a GLB edited by hand, or rebuilt without its report, fails here. The landmark
## residual (A3's 1 cm) is printed for the record: a generated torso with tilted bones does not meet it (M4-calls/P1-chain.md C6).
func test_each_character_report_names_the_glbs_it_exported() -> void:
	var dir := DirAccess.open("res://assets/source/characters")
	if dir == null:
		return
	for id: String in dir.get_directories():
		var sub := DirAccess.open("res://assets/source/characters/%s" % id)
		if sub == null:
			continue
		for rd: String in sub.get_directories():
			var report_path := "res://assets/source/characters/%s/%s/report.json" % [id, rd]
			if not rd.begins_with("report") or not FileAccess.file_exists(report_path):
				continue
			var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
			var outputs: Dictionary = report.outputs
			assert_gt(outputs.size(), 0, "%s names its outputs" % report_path)
			for glb: String in outputs:
				var path := "%s/%s/%s" % [CHARACTERS_DIR, id, glb]
				assert_true(FileAccess.file_exists(path), "%s: %s is exported" % [report_path, glb])
				if FileAccess.file_exists(path):
					assert_eq(FileAccess.get_sha256(path), outputs[glb], "%s is the file %s hashed" % [glb, report_path])
			var fit: Dictionary = report.steps.fit
			gut.p("%s: landmark residual %.1f mm at %s (limit %.0f mm)" % [report_path, float(fit.worst_joint_residual.m) * 1000.0, fit.worst_joint_residual.bone, float(fit.residual_limit_m) * 1000.0])


# --------------------------------------------------------------------------- the atlas

func _atlas_image() -> Image:
	var tex := load(ATLAS_PATH) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _swatch_pixel(slot: int) -> Vector2i:
	return Vector2i((slot % SWATCH_COLUMNS) * SWATCH_PX + SWATCH_PX / 2, (slot / SWATCH_COLUMNS) * SWATCH_PX + SWATCH_PX / 2)


func _swatch_color(atlas: Image, slot: int) -> Color:
	var p := _swatch_pixel(slot)
	var c := atlas.get_pixel(p.x, p.y)
	return Color(c.r, c.g, c.b, 1.0)


func _swatch_alpha(atlas: Image, slot: int) -> float:
	var p := _swatch_pixel(slot)
	return atlas.get_pixel(p.x, p.y).a


## Red is reserved (SPEC §10; test_bruises_are_not_red_paint): hue 345-15 degrees with saturation above 0.5.
func _in_red_band(c: Color) -> bool:
	var hue := c.h * 360.0
	return (hue >= 345.0 or hue <= 15.0) and c.s > 0.5
