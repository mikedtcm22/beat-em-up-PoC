extends GutTest
## Milestone 6, playtest feedback ROLL-KICKER: the Kicker through the Bruiser pilot's recipe, parts 1 and 2 (docs/milestones/M6-calls/FB-DETAIL.md
## and DETAIL-2.md, "Rollout recipe"; his own calls are in docs/milestones/M6-calls/ROLL-KICKER.md). The Kicker had a border relax of 3, no
## crease ink and three texture zones, so his vest read as a flat lime blob (no hood, zip, pocket or hem line) and his colour borders
## stepped along 2 cm faces. His config now asks for no border relax, a small-island merge, the dense mesh's sharp edges and folds as ink,
## a palette slot per texel and six zones. These tests hold what that bought, each against a floor the M6 export fails (measured by
## checking that GLB out of b454424: the figures are in the calls file). Taking the keys also opts him out of the shared guards in
## test_m6_feedback_detail.gd, which skip any character with a test file of its own.

const GLB := "res://assets/export/characters/kicker/kicker.glb"
const MASK := "res://assets/export/characters/kicker/kicker_detail.png"
const REPORT := "res://assets/source/characters/kicker/report/report.json"
const PIPELINE := "res://assets/source/characters/kicker/pipeline.json"
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## The Kicker's palette slots: lime (22), black (23), the shared skin (6) and the shared cream of the wraps (14).
const SLOT_LIME := 22
const SLOT_BLACK := 23
const SLOT_SKIN := 6
const SLOT_CREAM := 14
const SLOTS_ALLOWED: Array[int] = [22, 23, 6, 14]
## The vest, the wraps and the shorts in the authored 1.8 m frame (x across, y front/back, z up).
const VEST_MIN := Vector3(-0.6, -0.6, 0.95)
const VEST_MAX := Vector3(0.6, 0.6, 1.5)
const WRAP_MIN := Vector3(-0.9, -0.6, 0.7)
const WRAP_MAX := Vector3(0.9, 0.6, 1.5)
const SHORTS_MIN := Vector3(-0.6, -0.6, 0.45)
const SHORTS_MAX := Vector3(0.6, 0.6, 1.05)
## Floors the M6 export fails and today's passes (the figures are in ROLL-KICKER.md).
const VEST_INK_MIN := 0.04
const WRAP_INK_MIN := 0.018
const SHORTS_INK_MIN := 0.02
## Texels sampled per face when the ink is counted.
const SAMPLES: Array[Vector3] = [Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0), Vector3(0.6, 0.2, 0.2), Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.2, 0.6)]

var _arrays: Array = []
var _mask: Image = null


func before_all() -> void:
	var scene := load(GLB) as PackedScene
	var root: Node = scene.instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	_arrays = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	root.free()
	_mask = (load(MASK) as Texture2D).get_image()
	if _mask.is_compressed():
		_mask.decompress()


func _slot_of(uv: Vector2) -> int:
	return int(floorf(uv.x * float(SWATCH_COLUMNS))) + SWATCH_COLUMNS * int(floorf(uv.y * float(SWATCH_ROWS)))


func _tris() -> PackedInt32Array:
	return _arrays[Mesh.ARRAY_INDEX]


func _centre(tri: int) -> Vector3:
	var verts: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	var idx := _tris()
	return (verts[idx[tri * 3]] + verts[idx[tri * 3 + 1]] + verts[idx[tri * 3 + 2]]) / 3.0


func _slot_of_tri(tri: int) -> int:
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	return _slot_of(uvs[_tris()[tri * 3]])


## True when the face's centre (a GLB vertex: x across, y up, -z the front) lies in the authored frame's box (x across, y front, z up).
func _in_box(tri: int, lo: Vector3, hi: Vector3) -> bool:
	var c := _centre(tri)
	var p := Vector3(c.x, -c.z, c.y)
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and p.z >= lo.z and p.z <= hi.z


## The share of the sample points (SAMPLES) of the faces `pick` accepts whose mask value (R) is over 0.5.
func _ink_share(pick: Callable) -> Dictionary:
	var uv2: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV2]
	var idx := _tris()
	var hit := 0
	var total := 0
	var faces := 0
	for tri: int in idx.size() / 3:
		if not bool(pick.call(tri)):
			continue
		faces += 1
		for w: Vector3 in SAMPLES:
			var uv: Vector2 = uv2[idx[tri * 3]] * w.x + uv2[idx[tri * 3 + 1]] * w.y + uv2[idx[tri * 3 + 2]] * w.z
			var c := _mask.get_pixel(clampi(int(uv.x * _mask.get_width()), 0, _mask.get_width() - 1), clampi(int(uv.y * _mask.get_height()), 0, _mask.get_height() - 1))
			total += 1
			if c.r > 0.5:
				hit += 1
	return {"faces": faces, "samples": total, "ink": hit, "share": float(hit) / maxf(float(total), 1.0)}


func test_the_kicker_stays_inside_his_triangle_budget() -> void:
	var tris := _tris().size() / 3
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_lte(tris, 15000, "SPEC section 10's enemy row, %d triangles" % tris)
	assert_gt(tris, 12000, "and the chain still fills it")
	assert_eq(int(cfg.palette.budget_tris), 15000, "the config says 15000, not 20000")


func test_his_swatch_set_is_unchanged() -> void:
	var seen: Dictionary = {}
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	for uv: Vector2 in uvs:
		seen[_slot_of(uv)] = true
	for slot: int in seen:
		assert_true(SLOTS_ALLOWED.has(slot), "slot %d is one of the Kicker's" % slot)
	for slot: int in SLOTS_ALLOWED:
		assert_true(seen.has(slot), "slot %d is on the mesh" % slot)


## The vest, the wraps and the shorts carry lines inside their outlines (hood, zip, pocket and hem; the wraps' bands; the pockets and hem).
func test_the_vest_the_wraps_and_the_shorts_carry_their_ink() -> void:
	var vest := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_LIME and _in_box(tri, VEST_MIN, VEST_MAX))
	var wraps := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_CREAM and _in_box(tri, WRAP_MIN, WRAP_MAX))
	var shorts := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_BLACK and _in_box(tri, SHORTS_MIN, SHORTS_MAX))
	print("ROLL-KICKER ink: vest %d faces (%.4f), wraps %d faces (%.4f), shorts %d faces (%.4f)" % [vest.faces, vest.share, wraps.faces, wraps.share, shorts.faces, shorts.share])
	assert_gt(int(vest.faces), 800, "the vest box holds faces (%d)" % vest.faces)
	assert_gte(float(vest.share), VEST_INK_MIN, "the hood, zip, pocket and hem are inked (%.4f)" % vest.share)
	assert_gte(float(wraps.share), WRAP_INK_MIN, "the wraps keep their bands (%.4f)" % wraps.share)
	assert_gte(float(shorts.share), SHORTS_INK_MIN, "the shorts carry their pockets and hem (%.4f)" % shorts.share)
	var mask_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_true(mask_report.has("crease"), "the report says the crease ink was baked")
	assert_gt(int(mask_report.crease.texels_on_a_crease), 5000, "from texels on a crease of the dense mesh")


## The wraps (cream, a few cm wide) are not eaten by the island merge.
func test_the_wraps_and_the_mask_are_not_eaten_by_the_merge() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette
	assert_gt(float(report.swatches_used[str(SLOT_CREAM)].area_share), 0.12, "the wraps and the gloves keep their share of the surface")
	assert_gt(float(report.swatches_used[str(SLOT_SKIN)].area_share), 0.08, "and the skin its own")


## Samples of the mask's blue channel over the mesh: how many carry a code, how many name a slot other than the face's own.
func _codes() -> Dictionary:
	var uv2: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV2]
	var idx := _tris()
	var coded := 0
	var differ := 0
	var allowed := 0
	var total := 0
	for tri: int in idx.size() / 3:
		var face_slot := _slot_of_tri(tri)
		for w: Vector3 in SAMPLES:
			var uv: Vector2 = uv2[idx[tri * 3]] * w.x + uv2[idx[tri * 3 + 1]] * w.y + uv2[idx[tri * 3 + 2]] * w.z
			var c := _mask.get_pixel(clampi(int(uv.x * _mask.get_width()), 0, _mask.get_width() - 1), clampi(int(uv.y * _mask.get_height()), 0, _mask.get_height() - 1))
			var code := roundi(c.b * 255.0)
			total += 1
			if code > 0:
				coded += 1
				if SLOTS_ALLOWED.has(code - 1):
					allowed += 1
				if code - 1 != face_slot:
					differ += 1
	return {"total": total, "coded": coded, "differ": differ, "allowed": allowed}


## The colour border follows the texture: every texel the mesh uses has a code naming one of the Kicker's slots, and a small share name a
## swatch other than their face's (the 2 cm staircase moved), never most of them.
func test_the_mask_carries_a_palette_slot_per_texel() -> void:
	var c := _codes()
	print("ROLL-KICKER codes: %d of %d samples coded, %d differ from the face" % [c.coded, c.total, c.differ])
	assert_gte(float(c.coded) / float(c.total), 0.99, "nearly every sample of every face has a code (%d of %d)" % [c.coded, c.total])
	assert_eq(int(c.allowed), int(c.coded), "and each names one of 6, 14, 22, 23")
	var share := float(c.differ) / float(c.total)
	assert_gt(share, 0.002, "the codes move some borders off the faces (%.4f)" % share)
	assert_lt(share, 0.08, "and most texels keep their face's swatch (%.4f)" % share)
	assert_almost_eq(_mask.get_pixel(0, 0).a, 128.0 / 255.0, 0.01, "the Kicker's mask carries the marker, 128 / 255")


## The decode: a code names its slot's swatch centre (the face UVs of the mesh are the same function).
func test_the_code_decodes_to_the_slots_swatch() -> void:
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	var checked := 0
	for tri: int in range(0, _tris().size() / 3, 97):
		var uv := uvs[_tris()[tri * 3]]
		assert_eq(ToonMaterials.texel_swatch_uv(_slot_of(uv) + 1), uv, "slot %d: the code's swatch is the face's UV" % _slot_of(uv))
		checked += 1
	assert_gt(checked, 100, "faces were checked")


## His art's material takes the shader's texel switch from Tuning; off gives M6's face swatches back.
func test_the_material_carries_the_switch() -> void:
	var material := ToonMaterials.art(load("res://assets/export/palette/palette_atlas.png") as Texture2D, load(MASK) as Texture2D, true)
	ToonMaterials.apply_look(material)
	assert_true(bool(material.get_shader_parameter(&"use_texel_swatch")), "on by default")
	var before := Tuning.data.look_texel_swatch
	Tuning.data.look_texel_swatch = false
	ToonMaterials.apply_look(material)
	assert_false(bool(material.get_shader_parameter(&"use_texel_swatch")), "the A/B switch gives the face swatches back")
	Tuning.data.look_texel_swatch = before
	ToonMaterials.apply_look(material)


## His own config names the recipe's keys: thin lines for a slim model, valleys on the vest and shorts only, the face and tights round.
func test_the_kickers_config_holds_the_recipe_values() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_eq(int(cfg.palette.border_relax_iterations), 0, "no border relax")
	assert_gt(float(cfg.palette.min_island_area_m2), 0.0, "stray patches merge")
	assert_lte(float(cfg.palette.min_island_area_m2), 0.002, "but a pocket or a lace (a few cm2) is not a stray patch")
	var bake: Dictionary = cfg.palette.detail_bake
	var crease: Dictionary = bake.crease
	var across := float(crease.width_m) + 1.7 * float(crease.ramp_m)
	assert_lte(across, 0.0075, "crease lines at most 7.5 mm across for a slim model (%.4f)" % across)
	assert_gte(across, 0.004, "and not thinner than the mask holds (%.4f)" % across)
	assert_lte(float(crease.min_chain_m), 0.15, "a thin raw model draws short creases")
	assert_true(crease.has("valley"), "the valley ink is configured")
	assert_true(bake.has("texel_swatch"), "the texel codes are on")
	var zones: Dictionary = {}
	for zone: Dictionary in bake.zones:
		zones[zone.name] = zone
	for need: String in ["vest", "tights", "shorts", "wraps", "face_skin", "headwear", "boots"]:
		assert_true(zones.has(need), "zone %s" % need)
	assert_lt(float(zones.vest.valley_deg), 30.0, "the vest draws its folds")
	assert_gt(float(zones.face_skin.crease_deg), 180.0, "the face takes no crease line")
	assert_gt(float(zones.tights.crease_deg), 180.0, "nor do the tights")
	assert_false(zones.boots.has("valley_deg"), "the boots keep their creases only")
