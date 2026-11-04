extends GutTest
## The asset contract of the art pipeline (M4-plan Part C §2.6 as amended by Part A A3, package P1-chain), tested on every
## character GLB the project ships and on the pipeline's own probe bodies: the chain's output is only as good as these checks.
## One GLB is read through Godot's importer exactly as SkinnedArt will read it: the Skeleton3D's bones, the Skin's named
## binds (their inverse origins are the exported joints), each mesh's arrays. Rows: A1 (23 named binds, no neutral_bone, the
## joints within 1 mm of the table chained through the arms' swing, faces -Z, soles at y 0, at most 4 normalised influences,
## every vertex weighted, none on Root), A2 (triangle budgets), A3 (4-6 swatches from the shared atlas, none in the red band),
## A5 (the fists fill the fist box), A13 (every exported file has an ASSETS.md row, a fixture matches its report and shows the
## step reports' keys the characters' reports show), and the hero's 1k detail mask (R-only ink on a UV2 every vertex has, worn
## by player_art.tres).

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
## The Punk's committed chain report: the probe's step reports are measured against it (one script writes both).
const PUNK_REPORT := "res://assets/source/characters/punk/report/report.json"
## The steps whose report keys do not depend on the character: every key a shared step writes unconditionally is in both
## reports. (parts_replace, parts_split and export are not here: their keys follow the character's config, as the Punk's
## `generated`, the probe's `caps` and the Punk's `smooth_normals`.)
const UNCONDITIONAL_REPORT_STEPS: Array[String] = ["inspect", "fit", "rig", "palette"]
const HERO_GLB := "res://assets/export/characters/player/player.glb"
const HERO_MASK := "res://assets/export/characters/player/player_detail.png"
const HERO_ART := "res://game/actors/art/player_art.tres"
const HERO_MESHES: Array[String] = ["Body", "Body__fp_hidden", "Body__fp_torso"]
## Budgets per character id (SPEC §10: 15,000 enemy, 30,000 player); the probe bodies stand in for the player.
const BUDGETS: Dictionary[String, int] = {"punk": 15000, "player": 30000, "probe_body": 30000}
const TOLERANCE_JOINT := 0.001
const FIST_CENTROID_TOLERANCE := 0.015
const FIST_EXTENT_TOLERANCE := 0.2
const SOLE_TOLERANCE := 0.005
## The mean dot of a mesh's decoded hull normal (COLOR) with its NORMAL: the right axes measure 0.92-0.96 on the smoke Punk
## and the probe bodies (a normal baked in Blender's Z-up axes measured 0.31-0.34).
const HULL_AGREE_MIN := 0.85
## The atlas alpha classes (tools/pipeline/gen_palette.py; game/fx/toon.gdshader decodes them with step(0.75), step(0.85) and step(0.95)).
const ALPHA_CLOTHES := 1.0
## The clothes that scuff and never take blood (`"blood": false`, M6 D6).
const ALPHA_NO_BLOOD := 0.9
const ALPHA_SKIN := 0.8
const ALPHA_NONE := 0.5
const SWATCH_MIN := 4
const SWATCH_MAX := 6
## F-punk: a character may spend one more SLOT than it has flat colours (the Punk's lens is the cap's yellow on its own slot, so it
## takes no damage marks; F-punk-fix made it the shared cream and F-cuff's A/B put the yellow back); the number of flat COLOURS
## stays 4-6 (Part B A3, J6).
const SWATCH_SLOTS_MAX := 7
## F-punk-fix (the lead's look at the Punk at 1 m beside the concept). The palette slots the checks name (assets/source/palette):
## the shared dark grey (the gloves, the tank top, the shades' frame), the Punk's yellow (cap, laces) and the Punk's lens.
const SLOT_DARK_GREY := 2
const SLOT_SKIN := 6
const SLOT_CREAM := 14
const SLOT_YELLOW := 17
const SLOT_LENS := 19
## The shades' frame: dark faces above and below the lens (the lens box is y 1.592-1.652 m, the frame's boxes a little beyond it).
## The lens is the cap's yellow (the concept's gold lenses), so what sets it apart from the cap is the frame: in every column of the
## lens (a strip of LENS_COLUMN_M across, over the face's middle) the first face above the lens and the first below it are the dark
## frame, within FRAME_REACH_M of the lens, and the lens spans at least LENS_COLUMNS_MIN columns.
const LENS_BOTTOM_Y := 1.592
const LENS_TOP_Y := 1.652
const FRAME_MIN_FACES := 20
const LENS_COLUMN_M := 0.02
const LENS_COLUMNS_MIN := 8
## The columns are taken across the lens's middle (this far each side of the nose): the lens's last centimetre at each temple meets
## the face's own skin beside the frame's end.
const LENS_COLUMNS_HALF_WIDTH_M := 0.08
const FRAME_REACH_M := 0.025
const FACE_FRONT_Z := -0.05
## The cuff of a glove (hand-weighted vertices up the forearm from the wrist): no triangle thinner than this ratio (longest edge squared
## over twice the area; the old torn cuff measured 2463 and 84 faces over 20, the F-punk-fix collar 26-55 and at most 4, the wrist cuff
## 22.6 and 1), no edge longer than 6.5 cm, no vertex farther than 7 cm from the arm's axis (old: 9 cm; the F-punk-fix flange stood 8.6 cm
## out, the wrist cuff 5.8 cm), and a WRIST CUFF, not a flange: nothing on the cuff stands more than a centimetre farther from the axis
## than the bare forearm just above it (the flange stood 2.6 cm beyond the forearm, the cuff 0.1 cm inside it; F-cuff, M4-calls/F-punk.md).
const CUFF_NEEDLE_MAX := 60.0
const CUFF_NEEDLE_LIMIT := 20.0
const CUFF_NEEDLE_FACES_MAX := 8
const CUFF_EDGE_MAX_M := 0.065
const CUFF_RADIUS_MAX_M := 0.07
const CUFF_OVER_FOREARM_MAX_M := 0.01
## The bare forearm the cuff is measured against: its vertices (all LowerArm) this far above the wrist.
const FOREARM_ALONG_NEAR_M := 0.08
const FOREARM_ALONG_FAR_M := 0.10
## Shading normals: the share of edges whose end normals disagree by more than 25 degrees and the mean disagreement (the lumpy
## generated normals measured 38.5% and 25.4 degrees, 6 rounds of smoothing 11.3% and 15.1, the shipped 12 rounds (re-score rs-04: the
## face's bands were faceted patches at 6) 8.8% and 13.3; the bars were 18% and 19 degrees and are tightened to the 12 rounds).
const NORMAL_EDGE_ANGLE_DEG := 25.0
const NORMAL_EDGE_SHARE_MAX := 0.12
const NORMAL_MEAN_DEG_MAX := 16.0
## The face's skin carries the mouth and the nose line and no speckle: the share of its surface with ink over one half (the speckled
## mask measured 2.6%, the lines alone 1.6%; F-cuff's re-bake 1.98%, the final-v1-06 retune 1.62%: face_skin 0.04 / 0.10).
const FACE_INK_MIN := 0.004
const FACE_INK_MAX := 0.02
## The shipped share is 1.62% (final-v1-06: F-cuff's re-bake had moved it to 1.98% under a 2.0% ceiling, one sample from red); a mask
## over FACE_INK_MARGIN_MAX has lost the margin, so a re-bake that moves a few samples cannot turn the suite red on its own.
const FACE_INK_MARGIN_MAX := 0.0175
const FACE_MIN_Y := 1.5
## The cap's strap slot (final-v1-03): the dark arch in the cap's back panel, two boxes of pipeline.json's palette.regions
## (strap_base, strap_top) cut at their planes so the borders run on edge loops. The mesh's border vertices sit within
## ARCH_PLANE_M of the planes, and the old patch (20 faces, 3.9 x 1.7 cm, a ragged border) is under ARCH_FACES_MIN faces.
const PUNK_CONFIG := "res://assets/source/characters/punk/pipeline.json"
const ARCH_FACES_MIN := 60
const ARCH_PLANE_M := 0.002
const ARCH_ON_PLANE_MIN := 6
## A mask value over this is ink under the sharp cut (look_detail_cut 0.15), whatever the filtered value: the cap, the laces and
## the boots' ankles carry none of it (the generated texture's noise there is not a line).
const INK_CUT := 0.15
const CAP_MIN_Y := 1.69
const LACES_MAX_Y := 0.2
const ANKLE_MIN_Y := 0.05
const CLEAN_INK_SHARE_MAX := 0.005
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
const SWATCH_PX := 8
const ARM_BONES: Array[String] = ["UpperArm", "LowerArm", "Hand"]
## The share of a limb's triangles that may face their bone (creases, the crotch) before the limb is called inside out.
const INSIDE_OUT_MAX := 0.15
## How far (m) the arm's cap must bulge toward the shoulder past the cut (the dome is 0.04 m high).
const DOME_MIN_M := 0.03
## How far (m) the torso's rounded top may rise past the Chest joint (the dome is 0.05 m high).
const TORSO_DOME_MAX_M := 0.06

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


## F-punk (M4-plan A18): the Punk's detail mask is a 1k PNG with ink in R only (lines, never shading), G the glint gate (the lens's two
## authored streaks per eye, on the lens's texels only: tests/test_toon_glint.gd reads where) and B nothing, and punk.glb and punk_rest.glb
## carry the UV2 it is baked on, every vertex of it inside the unit square.
func test_the_punk_detail_mask_is_a_1k_ink_only_png_on_the_punks_uv2() -> void:
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	assert_not_null(art.detail_mask, "punk_art.tres carries the detail mask")
	var image := art.detail_mask.get_image()
	assert_eq(image.get_size(), Vector2i(1024, 1024), "1k")
	var ink := 0
	var blue := 0.0
	var gate := 0
	var sum := 0.0
	for y: int in range(0, 1024, 2):
		for x: int in range(0, 1024, 2):
			var c := image.get_pixel(x, y)
			sum += c.r
			blue = maxf(blue, c.b)
			if c.g > 0.5:
				gate += 1
			if c.r > 0.5:
				ink += 1
	var mean := sum / (512.0 * 512.0)
	print("ART-CONTRACT punk_detail.png: mean ink %.4f, %d of 262144 sampled texels over 0.5" % [mean, ink])
	assert_lt(blue, 0.01, "B holds nothing (R is the ink, G the lens's glint gate)")
	assert_gt(gate, 50, "G holds the lens's streaks (the glint gate)")
	assert_lt(gate, 3000, "and only the lens's (a few thousand texels at full resolution, a few hundred sampled here)")
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


## The weight of vertex `v` of a mesh on the bone named `bone` (a skin bind), over its four influences.
func _weight_on(arrays: Array, binds: Array[String], v: int, bone: String) -> float:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var w := 0.0
	for k: int in 4:
		if binds[bones[v * 4 + k]] == bone:
			w += weights[v * 4 + k]
	return w


## The palette slot a vertex of a mesh sits on: UV1 is the swatch's centre ((col + 0.5) / 32, (row + 0.5) / 2).
func _slot_of(uv: Vector2) -> int:
	return int(floorf(uv.x * float(SWATCH_COLUMNS))) + SWATCH_COLUMNS * int(floorf(uv.y * float(SWATCH_ROWS)))


## F-punk-fix, the gloves: the lead saw a yellow strap ring with black slivers at its edge, not the concept's dark fingerless gloves
## with a dark wrist cuff. Every face on a hand (all three vertices at least half Hand) is off the Punk's yellow and the lens, the
## cuff above the block (the hand-weighted ramp up the forearm) has no needle triangle, no long edge and no spike beyond 7 cm of the
## arm's axis (F-cuff: 9 cm before), and is a wrist cuff, no wider than the bare forearm above it by a centimetre. The twin of the old
## strap: the same faces, counted on the shipped GLBs.
func test_the_punks_gloves_have_no_yellow_and_the_cuff_has_no_slivers() -> void:
	for path: String in _glbs():
		if _id_of(path) != "punk":
			continue
		var f := _facts(path)
		if not f.ok:
			continue
		var body := _body(path)
		var arrays: Array = body.arrays
		var binds: Array[String] = body.bind_names
		var joints := _joints(path)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var yellow := 0
		var needles := 0
		var needle_max := 0.0
		var edge_max := 0.0
		var radius_max := 0.0
		var over_forearm_max := -INF
		for side: String in ["Left", "Right"]:
			var hand: Vector3 = joints[side + "Hand"]
			var dir: Vector3 = (hand - joints[side + "LowerArm"]).normalized()
			var hand_w := PackedFloat32Array()
			hand_w.resize(verts.size())
			var along := PackedFloat32Array()
			along.resize(verts.size())
			var side_radius_max := 0.0
			var forearm_radius := 0.0
			for v: int in verts.size():
				hand_w[v] = _weight_on(arrays, binds, v, side + "Hand")
				var rel := verts[v] - hand
				along[v] = rel.dot(dir)
				# up the arm is negative along: the cuff ramp is hand-weighted between 0.02 and 0.95, within 7.5 cm of the wrist
				if hand_w[v] > 0.02 and hand_w[v] < 0.95 and along[v] < 0.0 and along[v] > -0.075:
					side_radius_max = maxf(side_radius_max, (rel - dir * along[v]).length())
				if hand_w[v] < 0.02 and along[v] < -FOREARM_ALONG_NEAR_M and along[v] > -FOREARM_ALONG_FAR_M and rel.length() < 0.25 and _weight_on(arrays, binds, v, side + "LowerArm") > 0.95:
					forearm_radius = maxf(forearm_radius, (rel - dir * along[v]).length())
			radius_max = maxf(radius_max, side_radius_max)
			over_forearm_max = maxf(over_forearm_max, side_radius_max - forearm_radius)
			for t: int in index.size() / 3:
				var a := index[t * 3]
				var b := index[t * 3 + 1]
				var c := index[t * 3 + 2]
				if (verts[a] - hand).length() > 0.15 or (verts[b] - hand).length() > 0.15 or (verts[c] - hand).length() > 0.15:
					continue
				if hand_w[a] >= 0.5 and hand_w[b] >= 0.5 and hand_w[c] >= 0.5:
					var slot := _slot_of(uv[a])
					if slot == SLOT_YELLOW or slot == SLOT_LENS:
						yellow += 1
				# a cuff face: some Hand weight on it (the cuff ramps from the hand to the forearm), up to 8 cm above the wrist
				if maxf(hand_w[a], maxf(hand_w[b], hand_w[c])) > 0.05 and maxf(along[a], maxf(along[b], along[c])) < 0.01 and minf(along[a], minf(along[b], along[c])) > -0.08:
					var e0 := (verts[b] - verts[a]).length()
					var e1 := (verts[c] - verts[b]).length()
					var e2 := (verts[a] - verts[c]).length()
					var longest := maxf(e0, maxf(e1, e2))
					var area := 0.5 * (verts[b] - verts[a]).cross(verts[c] - verts[a]).length()
					var needle := longest * longest / maxf(2.0 * area, 1e-9)
					edge_max = maxf(edge_max, longest)
					needle_max = maxf(needle_max, needle)
					if needle > CUFF_NEEDLE_LIMIT:
						needles += 1
		gut.p("ART-CONTRACT gloves %s: %d yellow or lens faces on the hands; cuff needle max %.1f (%d over %.0f), longest edge %.1f cm, widest %.1f cm from the arm's axis, %.1f cm beyond the forearm above it" % [
				path.get_file(), yellow, needle_max, needles, CUFF_NEEDLE_LIMIT, edge_max * 100.0, radius_max * 100.0, over_forearm_max * 100.0])
		assert_eq(yellow, 0, "%s: no face of a glove is the Punk's yellow or the lens (the concept's gloves are dark, with a dark cuff)" % path)
		assert_lt(needle_max, CUFF_NEEDLE_MAX, "%s: no needle triangle on the cuffs" % path)
		assert_lte(needles, CUFF_NEEDLE_FACES_MAX, "%s: at most a few thin triangles on the cuffs" % path)
		assert_lt(edge_max, CUFF_EDGE_MAX_M, "%s: no long edge on the cuffs" % path)
		assert_lt(radius_max, CUFF_RADIUS_MAX_M, "%s: nothing on a cuff stands more than 7 cm from the arm's axis" % path)
		assert_lt(over_forearm_max, CUFF_OVER_FOREARM_MAX_M, "%s: the cuff is a band on the wrist, not a flange: no wider than the forearm above it by a centimetre" % path)


## Re-score rs-02: the striking glove was a featureless dome (J3). Its back and cuff carry authored lines now (`detail_bake.glove_lines`: a
## ring where the glove's knuckles begin, the outline of the dorsal plate with its knuckle ticks, three rings round the wrist cuff, which
## the bake now unwraps so it has texels), baked into R beside the texture's strokes. The share of the glove block's and the cuff's surface
## (four by four barycentric samples a triangle of the faces on a hand, the cuff counted by its height above the wrist) with ink over one
## half: the strokes alone measured 0.1 to 0.6% on the block and 0 on the cuff (the cuff had no texels).
const GLOVE_INK_BLOCK_MIN := 0.012
const GLOVE_INK_CUFF_MIN := 0.025


func test_the_punks_glove_and_cuff_carry_the_authored_lines() -> void:
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	if art == null or art.detail_mask == null:
		return
	var mask := art.detail_mask.get_image()
	var size := mask.get_width()
	var path := "res://assets/export/characters/punk/punk.glb"
	if not _facts(path).ok:
		return
	var body := _body(path)
	var arrays: Array = body.arrays
	var binds: Array[String] = body.bind_names
	var joints := _joints(path)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var block := Vector2.ZERO
	var cuff := Vector2.ZERO
	for side: String in ["Left", "Right"]:
		var hand: Vector3 = joints[side + "Hand"]
		var dir: Vector3 = (hand - joints[side + "LowerArm"]).normalized()
		var hand_w := PackedFloat32Array()
		hand_w.resize(verts.size())
		for v: int in verts.size():
			hand_w[v] = _weight_on(arrays, binds, v, side + "Hand")
		for t: int in index.size() / 3:
			var corner: Array[int] = [index[t * 3], index[t * 3 + 1], index[t * 3 + 2]]
			if (verts[corner[0]] - hand).length() > 0.15:
				continue
			var along := maxf((verts[corner[0]] - hand).dot(dir), maxf((verts[corner[1]] - hand).dot(dir), (verts[corner[2]] - hand).dot(dir)))
			var lowest := minf((verts[corner[0]] - hand).dot(dir), minf((verts[corner[1]] - hand).dot(dir), (verts[corner[2]] - hand).dot(dir)))
			var on_block := hand_w[corner[0]] >= 0.5 and hand_w[corner[1]] >= 0.5 and hand_w[corner[2]] >= 0.5
			var on_cuff := maxf(hand_w[corner[0]], maxf(hand_w[corner[1]], hand_w[corner[2]])) > 0.05 and along < 0.01 and lowest > -0.08
			if not (on_block or on_cuff):
				continue
			for i: int in 4:
				for j: int in 4 - i:
					var wa := (float(i) + 0.5) / 4.0
					var wb := (float(j) + 0.5) / 4.0
					var p := uv2[corner[0]] * wa + uv2[corner[1]] * wb + uv2[corner[2]] * (1.0 - wa - wb)
					var inked := 1.0 if mask.get_pixel(clampi(int(p.x * float(size)), 0, size - 1), clampi(int(p.y * float(size)), 0, size - 1)).r > 0.5 else 0.0
					if on_cuff and not on_block:
						cuff += Vector2(inked, 1.0)
					elif on_block:
						block += Vector2(inked, 1.0)
	var block_share := block.x / maxf(block.y, 1.0)
	var cuff_share := cuff.x / maxf(cuff.y, 1.0)
	gut.p("ART-CONTRACT glove ink: the glove block %.2f%% of %d samples, the cuff %.2f%% of %d" % [block_share * 100.0, block.y, cuff_share * 100.0, cuff.y])
	assert_gt(block.y, 1000.0, "the glove block was sampled")
	assert_gt(cuff.y, 500.0, "and the cuff")
	assert_gt(block_share, GLOVE_INK_BLOCK_MIN, "the glove's block has lines (the knuckle seam, the plate's outline)")
	assert_gt(cuff_share, GLOVE_INK_CUFF_MIN, "and the cuff has its rings (the strap's edge a strike's contact shows)")


## F-punk-fix, the shades: the lens and the cap were both #e8bd2e, so the head read as one yellow mass from the crown to the cheek.
## The lens is its own slot (marks off) with a dark frame of faces above and below it. F-cuff (the lead's A/B at 1, 2.5, 5 and 10 m):
## the lens is the cap's yellow again, as the concept's gold lenses, so it is no longer set apart by a colour distance (the old
## assertion: the lens at least 0.25 from the cap in RGB; the twin on the visible path is the frame): in every column of the lens
## the first face above it and the first below it are the dark frame, so the cap's yellow never touches the lens.
func test_the_punks_shades_are_a_marks_off_lens_in_a_dark_frame_apart_from_the_cap() -> void:
	var atlas := _atlas_image()
	if atlas == null:
		return
	var cap := _swatch_color(atlas, SLOT_YELLOW)
	var lens := _swatch_color(atlas, SLOT_LENS)
	gut.p("ART-CONTRACT shades: the lens %s, the cap %s" % [lens.to_html(false), cap.to_html(false)])
	assert_almost_eq(_swatch_alpha(atlas, SLOT_LENS), ALPHA_NONE, 0.01, "the lens takes no damage marks")
	assert_false(_in_red_band(lens), "the lens is not red (A13)")
	for path: String in _glbs():
		if _id_of(path) != "punk":
			continue
		var f := _facts(path)
		if not f.ok:
			continue
		var arrays: Array = _body(path).arrays
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var above := 0
		var below := 0
		var lens_faces := 0
		# the centres (height, slot) of the faces in front of the face, by column across it
		var columns: Dictionary = {}
		for t: int in index.size() / 3:
			var a := index[t * 3]
			var centre := (verts[a] + verts[index[t * 3 + 1]] + verts[index[t * 3 + 2]]) / 3.0
			if absf(centre.x) > 0.14 or centre.y < LENS_BOTTOM_Y - 0.02 or centre.y > LENS_TOP_Y + 0.03:
				continue
			var slot := _slot_of(uv[a])
			if slot == SLOT_LENS:
				lens_faces += 1
			elif slot == SLOT_DARK_GREY:
				if centre.y > LENS_TOP_Y - 0.004:
					above += 1
				elif centre.y < LENS_BOTTOM_Y + 0.004:
					below += 1
			if centre.z < FACE_FRONT_Z and absf(centre.x) < LENS_COLUMNS_HALF_WIDTH_M:
				var column := int(floorf(centre.x / LENS_COLUMN_M))
				var list: Array = columns.get(column, [])
				list.append([centre.y, slot])
				columns[column] = list
		var lens_columns := 0
		var unframed := PackedStringArray()
		for column: int in columns:
			var list: Array = columns[column]
			var top := -INF
			var bottom := INF
			for e: Array in list:
				if e[1] == SLOT_LENS:
					top = maxf(top, e[0])
					bottom = minf(bottom, e[0])
			if top == -INF:
				continue
			lens_columns += 1
			var up_y := INF
			var up_slot := -1
			var down_y := -INF
			var down_slot := -1
			for e: Array in list:
				if e[1] == SLOT_LENS:
					continue
				if e[0] > top and e[0] < up_y:
					up_y = e[0]
					up_slot = e[1]
				if e[0] < bottom and e[0] > down_y:
					down_y = e[0]
					down_slot = e[1]
			if up_slot != SLOT_DARK_GREY or up_y - top > FRAME_REACH_M:
				unframed.append("column %d above: slot %d at +%.1f cm" % [column, up_slot, (up_y - top) * 100.0])
			if down_slot != SLOT_DARK_GREY or bottom - down_y > FRAME_REACH_M:
				unframed.append("column %d below: slot %d at -%.1f cm" % [column, down_slot, (bottom - down_y) * 100.0])
		gut.p("ART-CONTRACT shades %s: %d lens faces in %d columns, %d dark frame faces above and %d below; %d columns without a frame next to the lens" % [
				path.get_file(), lens_faces, lens_columns, above, below, unframed.size()])
		assert_gt(lens_faces, 50, "%s: the lens is there" % path)
		assert_gte(above, FRAME_MIN_FACES, "%s: a dark frame above the lens" % path)
		assert_gte(below, FRAME_MIN_FACES, "%s: and below it" % path)
		assert_gte(lens_columns, LENS_COLUMNS_MIN, "%s: the lens spans the face" % path)
		assert_eq(unframed.size(), 0, "%s: in every column the first face above the lens and the first below it are the dark frame: %s" % [path, "; ".join(unframed)])


## F-punk-fix, the blotches: the toon bands are cut on the normal alone, and the generated mesh's normals were lumpy, so the bands
## broke into dark patches on the vest and the forearms. The shipped NORMAL is smoothed (pipe_normals.py): the neighbouring
## vertices' normals agree.
func test_the_punks_shading_normals_are_smoothed_not_lumpy() -> void:
	for path: String in _glbs():
		if _id_of(path) != "punk":
			continue
		var f := _facts(path)
		if not f.ok:
			continue
		var arrays: Array = _body(path).arrays
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var over := 0
		var edges := 0
		var sum := 0.0
		for t: int in index.size() / 3:
			for k: int in 3:
				var angle := rad_to_deg(normals[index[t * 3 + k]].angle_to(normals[index[t * 3 + (k + 1) % 3]]))
				sum += angle
				edges += 1
				if angle > NORMAL_EDGE_ANGLE_DEG:
					over += 1
		var share := float(over) / float(maxi(edges, 1))
		var mean := sum / float(maxi(edges, 1))
		gut.p("ART-CONTRACT normals %s: %.1f%% of %d edges differ by over %.0f degrees, mean %.1f degrees" % [path.get_file(), share * 100.0, edges, NORMAL_EDGE_ANGLE_DEG, mean])
		assert_lt(share, NORMAL_EDGE_SHARE_MAX, "%s: few edges have end normals more than 25 degrees apart" % path)
		assert_lt(mean, NORMAL_MEAN_DEG_MAX, "%s: and the mean disagreement is small" % path)


## Re-score rs-03: the Punk's strokes are lines, not dots. The bake takes one bilinear tap per 2.6 mm texel from lines about 1 to 3 mm wide, so
## a strand came out as dots and dashes: of 1,144 pieces over the shader's cut (look_detail_cut 0.15 of 255 = 38) 886 were 6 texels or fewer,
## a quarter of the ink texels, with a median of 2. pipe_detail.clean_strokes bridges the gaps along a stroke and drops the short pieces
## (`detail_bake.clean`): the pieces of 6 texels or fewer are now a few percent of the ink and the median is a line's length.
const STROKE_CUT_8BIT := 38
const STROKE_SMALL_TEXELS := 6
const STROKE_SMALL_SHARE_MAX := 0.12
const STROKE_MEDIAN_MIN := 6
const STROKE_PIECES_MAX := 600


func test_the_punks_strokes_are_lines_not_dots() -> void:
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	if art == null or art.detail_mask == null:
		return
	var image := art.detail_mask.get_image()
	if image.is_compressed():
		image.decompress()
	var size := image.get_width()
	var channels := 4 if image.get_format() == Image.FORMAT_RGBA8 else 3
	assert_true(image.get_format() == Image.FORMAT_RGBA8 or image.get_format() == Image.FORMAT_RGB8, "an 8-bit mask")
	var bytes := image.get_data()
	var ink := PackedByteArray()
	ink.resize(size * size)
	for i: int in size * size:
		ink[i] = 1 if bytes[i * channels] > STROKE_CUT_8BIT else 0
	var sizes: Array[int] = []
	for start: int in size * size:
		if ink[start] != 1:
			continue
		ink[start] = 2
		var stack := PackedInt32Array([start])
		var count := 0
		while not stack.is_empty():
			var at := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := at % size
			var y := at / size
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= size or ny >= size:
						continue
					var n := ny * size + nx
					if ink[n] == 1:
						ink[n] = 2
						stack.append(n)
		sizes.append(count)
	sizes.sort()
	var total := 0
	var small := 0
	for n: int in sizes:
		total += n
		if n <= STROKE_SMALL_TEXELS:
			small += n
	var share := float(small) / float(maxi(total, 1))
	var median := sizes[sizes.size() / 2] if not sizes.is_empty() else 0
	gut.p("ART-CONTRACT strokes: %d pieces over the cut, median %d texels, %.1f%% of the ink texels in pieces of %d or fewer" % [sizes.size(), median, share * 100.0, STROKE_SMALL_TEXELS])
	assert_gt(total, 3000, "there are strokes")
	assert_lt(share, STROKE_SMALL_SHARE_MAX, "few of the ink texels are in dots (the bake measured a quarter before the cleanup)")
	assert_gte(median, STROKE_MEDIAN_MIN, "the median piece is a line, not a dot (it was 2 texels)")
	assert_lt(sizes.size(), STROKE_PIECES_MAX, "and the strokes are hundreds of pieces, not over a thousand (1,144 before the cleanup)")


## F-punk-fix, the face: the mask's ink on the face's skin is the mouth mark and the nose line, not the texture's speckle. The share
## of the head's skin surface (sampled at barycentric points of every skin face above the collar) whose ink is over one half stays
## between a floor (the lines are there) and a ceiling (the speckled mask measured 2.6%).
func test_the_punks_face_skin_keeps_its_lines_and_loses_the_speckle() -> void:
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	if art == null or art.detail_mask == null:
		return
	var mask := art.detail_mask.get_image()
	var size := mask.get_width()
	var path := "res://assets/export/characters/punk/punk.glb"
	var f := _facts(path)
	if not f.ok:
		return
	var arrays: Array = _body(path).arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var samples := 0
	var inked := 0
	for t: int in index.size() / 3:
		var a := index[t * 3]
		var b := index[t * 3 + 1]
		var c := index[t * 3 + 2]
		if _slot_of(uv[a]) != SLOT_SKIN or (verts[a] + verts[b] + verts[c]).y / 3.0 < FACE_MIN_Y:
			continue
		for i: int in 4:
			for j: int in 4 - i:
				var wa := (float(i) + 0.5) / 4.0
				var wb := (float(j) + 0.5) / 4.0
				var wc := 1.0 - wa - wb
				if wc < 0.0:
					continue
				var p := uv2[a] * wa + uv2[b] * wb + uv2[c] * wc
				var px := mask.get_pixel(clampi(int(p.x * float(size)), 0, size - 1), clampi(int(p.y * float(size)), 0, size - 1))
				samples += 1
				if px.r > 0.5:
					inked += 1
	var share := float(inked) / float(maxi(samples, 1))
	gut.p("ART-CONTRACT face ink: %.2f%% of %d samples of the head's skin have ink over one half" % [share * 100.0, samples])
	assert_gt(samples, 1000, "the head's skin was sampled")
	assert_gt(share, FACE_INK_MIN, "the mouth mark and the nose line are in the mask")
	assert_lt(share, FACE_INK_MAX, "and the skin's speckle is not")
	assert_lt(share, FACE_INK_MARGIN_MAX, "with a margin under the ceiling (final-v1-06: 1.98% was one sample from red)")


## The share of the samples of the faces `keep` selects ((slot, centre) -> bool) whose mask value is over `above` (four by four
## barycentric samples a triangle, as the face-ink test takes them), and how many samples that was: Vector2(share, samples).
func _mask_share(path: String, mask: Image, keep: Callable, above: float) -> Vector2:
	var size := mask.get_width()
	var arrays: Array = _body(path).arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var samples := 0
	var inked := 0
	for t: int in index.size() / 3:
		var a := index[t * 3]
		var b := index[t * 3 + 1]
		var c := index[t * 3 + 2]
		if not bool(keep.call(_slot_of(uv[a]), (verts[a] + verts[b] + verts[c]) / 3.0)):
			continue
		for i: int in 4:
			for j: int in 4 - i:
				var wa := (float(i) + 0.5) / 4.0
				var wb := (float(j) + 0.5) / 4.0
				var wc := 1.0 - wa - wb
				if wc < 0.0:
					continue
				var p := uv2[a] * wa + uv2[b] * wb + uv2[c] * wc
				samples += 1
				if mask.get_pixel(clampi(int(p.x * float(size)), 0, size - 1), clampi(int(p.y * float(size)), 0, size - 1)).r > above:
					inked += 1
	return Vector2(float(inked) / float(maxi(samples, 1)), float(samples))


## final-v1-03, the cap's strap slot: the old one was a nearest-colour label of a few texels of the generated texture (20 coarse
## faces, a ragged border, a ring of ink specks around it); the new one is authored like the lens: two boxes (an arch) cut at
## their planes, so the dark grey's border is vertices ON the planes, and the cap and the arch take no ink.
func test_the_punks_cap_strap_slot_is_a_clean_arch_on_edge_loops_with_no_ink_around_it() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PUNK_CONFIG))
	var regions: Dictionary = {}
	for region: Dictionary in (config.palette.regions as Array):
		regions[String(region.name)] = region
	assert_true(regions.has("strap_base") and regions.has("strap_top"), "pipeline.json authors the strap slot as two regions (an arch)")
	if not (regions.has("strap_base") and regions.has("strap_top")):
		return
	var half_width := float(regions.strap_base.max[0])
	var base_y := float(regions.strap_base.min[2])
	var top_y := float(regions.strap_top.max[2])
	assert_true(bool(regions.strap_base.get("bisect_z", false)) and bool(regions.strap_base.get("bisect_x", false)), "cut at its planes first")
	var arch := func(slot: int, centre: Vector3) -> bool: return slot == SLOT_DARK_GREY and centre.y > CAP_MIN_Y and centre.z < FACE_FRONT_Z
	for path: String in _glbs():
		if _id_of(path) != "punk" or not _facts(path).ok:
			continue
		var arrays: Array = _body(path).arrays
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var faces := 0
		var members: Dictionary[int, bool] = {}
		for t: int in index.size() / 3:
			var a := index[t * 3]
			var centre := (verts[a] + verts[index[t * 3 + 1]] + verts[index[t * 3 + 2]]) / 3.0
			if not bool(arch.call(_slot_of(uv[a]), centre)):
				continue
			faces += 1
			for k: int in 3:
				members[index[t * 3 + k]] = true
		var low := INF
		var high := -INF
		var left := INF
		var right := -INF
		var on_base := 0
		var on_left := 0
		var on_right := 0
		for v: int in members:
			var p := verts[v]
			low = minf(low, p.y)
			high = maxf(high, p.y)
			left = minf(left, p.x)
			right = maxf(right, p.x)
			if absf(p.y - base_y) < ARCH_PLANE_M:
				on_base += 1
			if absf(p.x + half_width) < ARCH_PLANE_M:
				on_left += 1
			if absf(p.x - half_width) < ARCH_PLANE_M:
				on_right += 1
		gut.p("ART-CONTRACT strap %s: %d dark faces in the arch, x %.1f to %.1f cm, y %.2f to %.2f m; vertices on the planes: base %d, left %d, right %d" % [
				path.get_file(), faces, left * 100.0, right * 100.0, low, high, on_base, on_left, on_right])
		assert_gte(faces, ARCH_FACES_MIN, "%s: the arch is a shape of its own, not a few coarse faces" % path)
		assert_gte(right - left, 1.8 * half_width, "%s: it spans both boxes' width" % path)
		assert_gte(high - low, 0.9 * (top_y - base_y), "%s: and their height" % path)
		assert_lt(maxf(-left, right), half_width + ARCH_PLANE_M, "%s: nothing past the box's sides" % path)
		assert_gt(low, base_y - ARCH_PLANE_M, "%s: nothing under its base" % path)
		assert_lt(high, top_y + ARCH_PLANE_M, "%s: nothing over its top" % path)
		assert_gte(on_base, ARCH_ON_PLANE_MIN, "%s: the base is a run of vertices on its plane (an edge loop)" % path)
		assert_gte(on_left, ARCH_ON_PLANE_MIN, "%s: so is the left side" % path)
		assert_gte(on_right, ARCH_ON_PLANE_MIN, "%s: and the right" % path)
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	if art == null or art.detail_mask == null or not _facts("res://assets/export/characters/punk/punk.glb").ok:
		return
	var mask := art.detail_mask.get_image()
	var punk := "res://assets/export/characters/punk/punk.glb"
	var cap := func(slot: int, centre: Vector3) -> bool: return slot == SLOT_YELLOW and centre.y > CAP_MIN_Y
	var cap_share := _mask_share(punk, mask, cap, INK_CUT)
	var arch_share := _mask_share(punk, mask, arch, INK_CUT)
	gut.p("ART-CONTRACT cap ink: %.2f%% of %d cap samples and %.2f%% of %d arch samples are ink under the cut" % [cap_share.x * 100.0, cap_share.y, arch_share.x * 100.0, arch_share.y])
	assert_gt(cap_share.y, 500.0, "the cap was sampled")
	assert_lt(cap_share.x, CLEAN_INK_SHARE_MAX, "the cap is a clean yellow: no specks around the strap slot")
	assert_eq(arch_share.x, 0.0, "the arch takes no ink")


## final-v1-05, the laces: the generated texture's laces are noisy, and the top-hat inked 23% of the lace faces fully (leopard spots)
## and 14% more faintly; the laces and the boots' ankles take no ink (the colour border of the yellow on the cream is the shape), the
## sole and the toe keep their lines.
func test_the_punks_laces_and_ankles_are_clean_the_soles_keep_their_lines() -> void:
	var art := load("res://game/actors/art/punk_art.tres") as CharacterArt
	var punk := "res://assets/export/characters/punk/punk.glb"
	if art == null or art.detail_mask == null or not _facts(punk).ok:
		return
	var mask := art.detail_mask.get_image()
	var laces := func(slot: int, centre: Vector3) -> bool: return slot == SLOT_YELLOW and centre.y < LACES_MAX_Y
	var ankles := func(slot: int, centre: Vector3) -> bool: return (slot == SLOT_YELLOW or slot == SLOT_CREAM) and centre.y > ANKLE_MIN_Y and centre.y < LACES_MAX_Y
	var soles := func(slot: int, centre: Vector3) -> bool: return slot == SLOT_CREAM and centre.y < ANKLE_MIN_Y
	var lace_share := _mask_share(punk, mask, laces, INK_CUT)
	var ankle_share := _mask_share(punk, mask, ankles, INK_CUT)
	var sole_share := _mask_share(punk, mask, soles, INK_CUT)
	gut.p("ART-CONTRACT laces: %.2f%% of %d lace samples, %.2f%% of %d ankle samples and %.2f%% of %d sole samples are ink under the cut" % [
			lace_share.x * 100.0, lace_share.y, ankle_share.x * 100.0, ankle_share.y, sole_share.x * 100.0, sole_share.y])
	assert_gt(lace_share.y, 500.0, "the laces were sampled")
	assert_lt(lace_share.x, CLEAN_INK_SHARE_MAX, "the yellow laces are clean (leopard spots before: 23% inked)")
	assert_lt(ankle_share.x, CLEAN_INK_SHARE_MAX, "and so is the cream round them")
	assert_gt(sole_share.x, 0.0, "the sole keeps a line")


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


## F-fist-turn (the lead's note on Game-boy's playtest: "his curled fingers are facing outward instead of inward when he has his
## hands up to fight"). A5 says each fist hangs knuckles down the arm (-Y), palm to the midline, thumb forward (-Z), and the A5 box is
## symmetric, so the extents and the centroid above cannot see which way a hand faces. The Punk's fist is a generated glove, a fingerless
## glove on a clenched hand: its bare fingers and thumb are the skin-coloured faces, curled into the palm, and its padded back is the dark
## side. So the area-weighted centroid of the fist's skin faces, taken from the centroid of the whole fist in the hand's table frame
## (un-swung as in A5), says where the palm is (x: toward the midline is +x for the left hand, -x for the right) and where the thumb and
## the fingers' front are (z: forward is -z). The first F-punk build had both fists with the palm OUTWARD (the model is a right-hand fist
## and was taken for a left one): -2.0 cm and -1.5 cm on the left. The bars are a centimetre and a centimetre, the shipped about 2 cm.
const FIST_PALM_MIN_M := 0.01
const FIST_THUMB_FRONT_MIN_M := 0.008


## The skin faces' centroid minus the whole fist's, in the hand's table frame, per side ("Left" or "Right") of the GLB at `path`.
func _fist_skin_offset(path: String, side: String) -> Vector3:
	var body := _body(path)
	var joints := _joints(path)
	var arrays: Array = body.arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var hand := side + "Hand"
	var basis := Basis(Quaternion((joints[hand] - joints[side + "LowerArm"]).normalized(), Vector3.DOWN))
	var wrist: Vector3 = joints[hand]
	var hand_w := PackedFloat32Array()
	hand_w.resize(verts.size())
	for v: int in verts.size():
		hand_w[v] = _weight_on(arrays, body.bind_names, v, hand)
	var area := 0.0
	var centroid := Vector3.ZERO
	var skin_area := 0.0
	var skin_centroid := Vector3.ZERO
	for t: int in index.size() / 3:
		var i0 := index[t * 3]
		var i1 := index[t * 3 + 1]
		var i2 := index[t * 3 + 2]
		if hand_w[i0] < 0.9 or hand_w[i1] < 0.9 or hand_w[i2] < 0.9:
			continue
		var p0 := basis * (verts[i0] - wrist)
		var p1 := basis * (verts[i1] - wrist)
		var p2 := basis * (verts[i2] - wrist)
		var a := (p1 - p0).cross(p2 - p0).length() * 0.5
		var c := (p0 + p1 + p2) / 3.0
		area += a
		centroid += c * a
		if _slot_of(uv[i0]) == SLOT_SKIN:
			skin_area += a
			skin_centroid += c * a
	if area < 0.001 or skin_area < 0.0005:
		return Vector3.INF
	return skin_centroid / skin_area - centroid / area


func test_the_punks_fists_hang_palm_to_the_midline_and_thumb_forward() -> void:
	for path: String in _glbs():
		if _id_of(path) != "punk":
			continue
		var f := _facts(path)
		if not f.ok:
			continue
		for side: String in ["Left", "Right"]:
			var toward_midline := 1.0 if side == "Left" else -1.0
			var off := _fist_skin_offset(path, side)
			assert_ne(off, Vector3.INF, "%s: the %s fist has bare skin on it" % [path, side])
			if off == Vector3.INF:
				continue
			gut.p("ART-CONTRACT fist %s %s: the bare fingers sit %+.1f mm toward the midline, %+.1f mm along the bone toward the knuckles, %+.1f mm toward the front of the hand" % [
					path.get_file(), side, off.x * toward_midline * 1000.0, -off.y * 1000.0, -off.z * 1000.0])
			assert_gt(off.x * toward_midline, FIST_PALM_MIN_M, "%s: the %s fist's palm (the curled bare fingers) is toward the midline, not outward (A5)" % [path, side])
			assert_gt(-off.z, FIST_THUMB_FRONT_MIN_M, "%s: the %s fist's thumb and finger pads are toward the front, -Z (A5)" % [path, side])


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
			# the torso is the band between the hip joint and the Chest joint (its top is a rounded dome, M3's BellyTop, rising a little
			# past the joint), closed on its own like the body
			var torso: Dictionary = f.meshes["Body__fp_torso"]
			var tv: PackedVector3Array = torso.arrays[Mesh.ARRAY_VERTEX]
			var t_low := INF
			var t_high := -INF
			for v: Vector3 in tv:
				t_low = minf(t_low, v.y)
				t_high = maxf(t_high, v.y)
			assert_gt(t_low, _table_joint("LeftUpperLeg").y - 0.002, "%s: the torso starts at the hip joint (y %.3f)" % [path, t_low])
			assert_lt(t_high, _table_joint("Chest").y + TORSO_DOME_MAX_M, "%s: and ends at the Chest joint, its top a dome of at most %.0f mm (y %.3f)" % [path, TORSO_DOME_MAX_M * 1000.0, t_high])
			assert_eq(_open_edges(torso), 0, "%s: the torso has no open loop either" % path)


## The limbs are the right way out: a triangle of a leg or a foot faces away from its bone. The first split of the hero
## recalculated the body's normals as a whole and turned the legs, the feet and part of the hips inside out: 49-96% of their triangles
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
## 1.0 clothes marks, 0.9 clothes scuffs without blood (`"blood": false`, M6 D6), 0.8 skin marks (`"skin": true`,
## slots 6-9), 0.5 none (slice-g2-07).
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
			var blood := bool(sw.get("blood", true))
			assert_false(skin and not blood, "%s slot %d: a skin swatch always takes blood" % [file, slot])
			assert_false(not takes and not blood, "%s slot %d: blood: false means something only where marks land" % [file, slot])
			var want_alpha := ALPHA_NONE if not takes else ALPHA_SKIN if skin else ALPHA_CLOTHES if blood else ALPHA_NO_BLOOD
			var alpha := _swatch_alpha(atlas, slot)
			assert_almost_eq(alpha, want_alpha, 0.01, "%s slot %d: alpha 1.0 takes the clothes' marks, 0.9 the scuffs only, 0.8 the skin's, 0.5 none" % [file, slot])
			# the shader's own decode (toon.gdshader: takes_marks *= step(0.75, a); skin_marks = 1 - step(0.85, a);
			# no_blood = step(0.85, a) * (1 - step(0.95, a))) gives the same classes
			assert_eq(alpha >= 0.75, takes, "%s slot %d: the shader reads 'takes marks' from the alpha" % [file, slot])
			assert_eq(alpha >= 0.75 and alpha < 0.85, skin, "%s slot %d: the shader reads 'skin' from the alpha" % [file, slot])
			assert_eq(alpha >= 0.85 and alpha < 0.95, takes and not blood, "%s slot %d: the shader reads 'no blood' from the alpha" % [file, slot])
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


## The probe report's step reports have the keys a character's report has. The report hash covers every key of every step's
## report, so a shared step that writes a new unconditional key moves the hash of a rebuild while the GLBs stay byte for byte
## the same (F-punk's `rig.torso_blend`, 691fcfd: the probe's report went stale and its `--check` said NO for hours with this
## suite green). The Punk's chain report is the reference: it is the one a shared-step change regenerates first. Only the key
## sets of the steps that do not depend on the character are compared, and only their first level: the nested keys follow the
## data (a swatch per slot, a snap per bone).
func test_the_probe_report_has_the_step_report_keys_the_punks_report_has() -> void:
	assert_true(FileAccess.file_exists(PUNK_REPORT), "the Punk's chain report is committed")
	var probe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROBE_REPORT))
	var punk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PUNK_REPORT))
	for step: String in UNCONDITIONAL_REPORT_STEPS:
		assert_true((probe.steps as Dictionary).has(step), "the probe report has the %s step" % step)
		assert_true((punk.steps as Dictionary).has(step), "the Punk's report has the %s step" % step)
		if not (probe.steps as Dictionary).has(step) or not (punk.steps as Dictionary).has(step):
			continue
		var probe_keys: Array = (probe.steps[step] as Dictionary).keys()
		var punk_keys: Array = (punk.steps[step] as Dictionary).keys()
		probe_keys.sort()
		punk_keys.sort()
		var missing: Array = punk_keys.filter(func(k: Variant) -> bool: return not probe_keys.has(k))
		var extra: Array = probe_keys.filter(func(k: Variant) -> bool: return not punk_keys.has(k))
		assert_eq(missing, [], "steps.%s: keys the Punk's report has and the probe's lacks (rerun python3 -I tools/pipeline/make_probe_body.py: the GLBs come out unchanged, the report and its hash move)" % step)
		assert_eq(extra, [], "steps.%s: keys the probe's report has and the Punk's lacks (the Punk's report is the stale one: run.py --asset punk)" % step)


## M4-plan A18 for the hero (Spec §10: "palette atlas + 1k detail mask"; the most-seen asset of the milestone): his mask is a
## 1k PNG with ink and no shading, and player.glb carries the UV2 it is baked on, on every vertex of all three meshes. His
## mask repeats the ink in R, G and B (the Punk's is R only), and its bars are the Punk's: lines and not a wash (the mean),
## and some (the count). Which lines is the hero's own affair: his mean is about 0.04 today and the bar is not drawn to it.
func test_the_hero_detail_mask_is_a_1k_ink_only_grey_png_on_the_heros_uv2() -> void:
	var mask := load(HERO_MASK) as Texture2D
	assert_not_null(mask, "player_detail.png loads")
	if mask == null:
		return
	var image := mask.get_image()
	assert_eq(image.get_size(), Vector2i(1024, 1024), "1k")
	assert_false(image.is_compressed(), "the mask is read as data, never VRAM-compressed")
	var import := FileAccess.get_file_as_string(HERO_MASK + ".import")
	assert_true(import.contains("compress/mode=0") and import.contains("mipmaps/generate=true"), "it imports lossless with mipmaps (player_run.py patches the .import after Godot writes it)")
	var ink := 0
	var not_grey := 0.0
	var sum := 0.0
	for y: int in range(0, 1024, 2):
		for x: int in range(0, 1024, 2):
			var c := image.get_pixel(x, y)
			sum += c.r
			not_grey = maxf(not_grey, maxf(absf(c.r - c.g), absf(c.r - c.b)))
			if c.r > 0.5:
				ink += 1
	var mean := sum / (512.0 * 512.0)
	print("ART-CONTRACT player_detail.png: mean ink %.4f, %d of 262144 sampled texels over 0.5" % [mean, ink])
	assert_lt(not_grey, 0.01, "R, G and B are one grey: the ink repeated, never a colour")
	assert_gt(ink, 500, "there are lines")
	assert_lt(mean, 0.08, "and they are lines, not a wash (shading would raise the mean)")
	var f := _facts(HERO_GLB)
	assert_true(f.ok, "player.glb loads")
	if not f.ok:
		return
	for n: String in HERO_MESHES:
		assert_true((f.meshes as Dictionary).has(n), "player.glb has the mesh %s" % n)
		if not (f.meshes as Dictionary).has(n):
			continue
		var arrays: Array = (f.meshes[n] as Dictionary).arrays
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		assert_gt(verts.size(), 0, "%s has vertices" % n)
		assert_eq(uv2.size(), verts.size(), "%s: UV2 (detail) on every vertex" % n)
		var outside := 0
		for uv: Vector2 in uv2:
			if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
				outside += 1
		assert_eq(outside, 0, "%s: UV2 inside the unit square" % n)


## The hero wears his mask: player_art.tres names it by metadata, and PlayerCharacter.worn_art() drops it WITHOUT a warning when
## the path does not resolve (a typo, a renamed file), so the wraps, the stitching and the seams would vanish from the first-
## person view with the suite green. What is read here: the metadata names the file, the worn copy holds that texture and the
## sharp-ink flag, and a rig built on it hands its art material the mask with `use_detail_tex` on (that the material then cuts
## its ink at look_detail_cut is test_toon's).
func test_the_hero_wears_his_detail_mask_with_sharp_ink() -> void:
	var scene_art := load(HERO_ART) as CharacterArt
	assert_not_null(scene_art, "player_art.tres loads")
	if scene_art == null:
		return
	assert_eq(String(scene_art.get_meta(PlayerCharacter.ART_DETAIL_META, "")), HERO_MASK, "player_art.tres names the mask")
	assert_true(ResourceLoader.exists(HERO_MASK), "and the file is there")
	assert_true(bool(scene_art.get_meta(&"detail_sharp", false)), "player_art.tres asks for sharp ink: the hero's lines are magnified to several pixels")
	var worn := PlayerCharacter.worn_art(scene_art)
	assert_not_null(worn, "the hero's art is worn")
	if worn == null:
		return
	assert_not_null(worn.detail_mask, "the worn art holds a detail mask")
	if worn.detail_mask == null:
		return
	assert_eq(worn.detail_mask.resource_path, HERO_MASK, "it is player_detail.png")
	assert_true(bool(worn.get_meta(&"detail_sharp", false)), "the worn copy keeps the sharp-ink flag")
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = worn
	add_child_autofree(rig)
	rig.build()
	var material := rig.paint.art_material() as ShaderMaterial
	assert_not_null(material, "the built rig has an art material")
	if material == null:
		return
	assert_true(bool(material.get_shader_parameter(&"use_detail_tex")), "its toon material reads the detail mask")
	assert_eq(material.get_shader_parameter(&"detail_tex"), worn.detail_mask, "the mask on UV2 is player_detail.png")


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


# --- Variant atlases (M6 D4, LOOKS) -----------------------------------------------------------


## The slots a GLB's faces sit on (the UV1 swatch centres of every mesh).
func _slots_used_by(path: String) -> Dictionary:
	var slots: Dictionary = {}
	var f := _facts(path)
	if not f.ok:
		return slots
	for n: String in (f.meshes as Dictionary):
		var uvs: PackedVector2Array = ((f.meshes[n] as Dictionary).arrays as Array)[Mesh.ARRAY_TEX_UV]
		for uv: Vector2 in uvs:
			slots[int(roundf(uv.y * SWATCH_ROWS - 0.5)) * SWATCH_COLUMNS + int(roundf(uv.x * SWATCH_COLUMNS - 0.5))] = true
	return slots


func _variant_atlas(id: String) -> Image:
	var tex := load("res://assets/export/palette/%s_atlas.png" % id) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _hue_gap(a: Color, b: Color) -> float:
	var gap := absf(a.h - b.h) * 360.0
	return minf(gap, 360.0 - gap)


## A variant atlas is the shared atlas with a few slots recoloured: every alpha is the base's (the damage class and the gloss), every
## other swatch is the base's colour, the recoloured ones are the variant JSON's, saturated, not red, and clear of the Punk's teal and
## the player's navy; the Punk's body still uses 4-6 colours under it (A3).
func test_a_variant_atlas_recolours_swatches_and_keeps_every_alpha() -> void:
	var base := _atlas_image()
	var dir := DirAccess.open(PALETTE_DIR + "/variants")
	assert_not_null(dir, "assets/source/palette/variants exists")
	if dir == null:
		return
	var teal := _swatch_color(base, 16)
	var navy := _swatch_color(base, 32)
	var checked := 0
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var v: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/variants/%s" % [PALETTE_DIR, file]))
		var img := _variant_atlas(String(v.id))
		assert_not_null(img, "%s: the atlas is built (python3 -I tools/pipeline/gen_palette.py)" % file)
		if img == null:
			continue
		checked += 1
		assert_eq(img.get_size(), base.get_size(), "%s: the same 256x16" % file)
		var changed: Dictionary = {}
		for sw: Dictionary in v.swatches:
			changed[int(sw.slot)] = Color.html(sw.srgb)
			for key: String in ["marks", "skin", "gloss", "blood"]:
				assert_false(sw.has(key), "%s slot %d: a variant keeps its swatch's damage class (no %s)" % [file, sw.slot, key])
		for slot in 64:
			assert_eq(_swatch_alpha(img, slot), _swatch_alpha(base, slot), "%s slot %d: the alpha (damage class, gloss) is the base's" % [file, slot])
			var got := _swatch_color(img, slot)
			if changed.has(slot):
				var want: Color = changed[slot]
				assert_almost_eq(got.r, want.r, 0.005, "%s slot %d red" % [file, slot])
				assert_almost_eq(got.g, want.g, 0.005, "%s slot %d green" % [file, slot])
				assert_almost_eq(got.b, want.b, 0.005, "%s slot %d blue" % [file, slot])
				assert_ne(got.to_html(false), _swatch_color(base, slot).to_html(false), "%s slot %d: really recoloured" % [file, slot])
				assert_gte(got.s, 0.5, "%s slot %d: an enemy's main colour keeps saturation of 0.5 (look bible)" % [file, slot])
				assert_false(_in_red_band(got), "%s slot %d: not red" % [file, slot])
				assert_gte(_hue_gap(got, teal), 40.0, "%s slot %d: clear of the Punk's teal" % [file, slot])
				assert_gte(_hue_gap(got, navy), 40.0, "%s slot %d: clear of the player's navy" % [file, slot])
			else:
				assert_eq(got.to_html(false), _swatch_color(base, slot).to_html(false), "%s slot %d: the base's colour" % [file, slot])
		for path: String in _glbs():
			if _id_of(path) != String(v.base):
				continue
			var colours: Dictionary = {}
			var slots := _slots_used_by(path)
			for slot: int in slots:
				colours[_swatch_color(img, slot).to_html(false)] = true
				assert_false(_in_red_band(_swatch_color(img, slot)), "%s under %s: slot %d is not red" % [path.get_file(), file, slot])
			assert_between(colours.size(), SWATCH_MIN, SWATCH_MAX, "%s under %s: %d flat colours used" % [path.get_file(), file, colours.size()])
			if path.get_file() == "%s.glb" % v.base:
				for slot: int in changed:
					assert_true(slots.has(slot), "%s: the swatch %d the variant recolours is on the body" % [path.get_file(), slot])
	assert_gt(checked, 0, "at least one variant atlas (the veteran Punk's)")
