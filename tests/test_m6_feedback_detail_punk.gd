extends GutTest
## Milestone 6, playtest feedback ROLL-PUNK: the Street Punk through the recipe's parts 1 and 2 (docs/milestones/M6-calls/FB-DETAIL.md and
## DETAIL-2.md, "Rollout recipe"; his own calls are in docs/milestones/M6-calls/ROLL-PUNK.md). His texture has real lines, so his zones of M4
## (face, nose, strap, cap, boots, laces, shades) stay as tuned; what is new is a palette slot per texel (the vest, cap and trousers' colour
## borders follow the texture), crease ink where the geometry has edges (the vest's pockets and hem, the trousers' seams), valley ink on the
## cloth and five zones that keep the texture's own strokes (skin, tank, wraps, lens) free of any crease line. The veteran Punk is a palette
## swap: the codes name a slot and the swap's atlas maps the slot, so he recolours. Each ink floor is one the M6 export fails.

const GLB := "res://assets/export/characters/punk/punk.glb"
const MASK := "res://assets/export/characters/punk/punk_detail.png"
const REPORT := "res://assets/source/characters/punk/report/report.json"
const PIPELINE := "res://assets/source/characters/punk/pipeline.json"
const ATLAS := "res://assets/export/palette/palette_atlas.png"
const VETERAN_ATLAS := "res://assets/export/palette/punk_veteran_atlas.png"
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## The Punk's palette slots: dark grey (tank, gloves), skin, cream (boots, wraps), teal vest, yellow cap and laces, trousers, lens.
const SLOT_DARK := 2
const SLOT_SKIN := 6
const SLOT_CREAM := 14
const SLOT_VEST := 16
const SLOT_YELLOW := 17
const SLOT_JEANS := 18
const SLOT_LENS := 19
const SLOTS_ALLOWED: Array[int] = [2, 6, 14, 16, 17, 18, 19]
## The vest and the trousers in the authored 1.8 m frame (x across, y front/back, z up).
const VEST_MIN := Vector3(-0.75, -0.5, 0.8)
const VEST_MAX := Vector3(0.75, 0.5, 1.7)
const JEANS_MIN := Vector3(-0.5, -0.5, 0.0)
const JEANS_MAX := Vector3(0.5, 0.5, 1.1)
## Floors the M6 export fails and today's passes (see ROLL-PUNK.md for the figures).
const VEST_INK_MIN := 0.04
const JEANS_INK_MIN := 0.03
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


func _mask_at(tri: int, w: Vector3) -> Color:
	var uv2: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV2]
	var idx := _tris()
	var uv: Vector2 = uv2[idx[tri * 3]] * w.x + uv2[idx[tri * 3 + 1]] * w.y + uv2[idx[tri * 3 + 2]] * w.z
	return _mask.get_pixel(clampi(int(uv.x * _mask.get_width()), 0, _mask.get_width() - 1), clampi(int(uv.y * _mask.get_height()), 0, _mask.get_height() - 1))


## The share of the sample points (SAMPLES) of the faces `pick` accepts whose mask value (R) is over 0.5.
func _ink_share(pick: Callable) -> Dictionary:
	var hit := 0
	var total := 0
	var faces := 0
	for tri: int in _tris().size() / 3:
		if not bool(pick.call(tri)):
			continue
		faces += 1
		for w: Vector3 in SAMPLES:
			total += 1
			if _mask_at(tri, w).r > 0.5:
				hit += 1
	return {"faces": faces, "samples": total, "ink": hit, "share": float(hit) / maxf(float(total), 1.0)}


func test_the_punk_stays_inside_his_budget_and_keeps_his_swatch_set() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_lte(_tris().size() / 3, 15000, "SPEC section 10's enemy row")
	assert_eq(int(cfg.palette.budget_tris), 15000, "the config says 15000")
	var seen: Dictionary = {}
	for uv: Vector2 in (_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
		seen[_slot_of(uv)] = true
	for slot: int in seen:
		assert_true(SLOTS_ALLOWED.has(slot), "slot %d is one of the Punk's" % slot)
	for slot: int in [SLOT_DARK, SLOT_SKIN, SLOT_CREAM, SLOT_VEST, SLOT_YELLOW, SLOT_JEANS, SLOT_LENS]:
		assert_true(seen.has(slot), "slot %d is on the mesh" % slot)


## Every sample of every face has a code naming one of his slots; a few per cent (under 8) name a swatch other than their face's.
func test_the_mask_carries_a_palette_slot_per_texel() -> void:
	var coded := 0
	var differ := 0
	var allowed := 0
	var total := 0
	for tri: int in _tris().size() / 3:
		var face_slot := _slot_of_tri(tri)
		for w: Vector3 in SAMPLES:
			var code := roundi(_mask_at(tri, w).b * 255.0)
			total += 1
			if code > 0:
				coded += 1
				if SLOTS_ALLOWED.has(code - 1):
					allowed += 1
				if code - 1 != face_slot:
					differ += 1
	print("ROLL-PUNK codes: %d of %d samples coded, %d differ from the face" % [coded, total, differ])
	assert_gte(float(coded) / float(total), 0.99, "nearly every sample has a code (%d of %d)" % [coded, total])
	assert_eq(allowed, coded, "and each names one of the Punk's slots")
	var share := float(differ) / float(total)
	assert_gt(share, 0.002, "the codes move some borders off the faces (%.4f)" % share)
	assert_lt(share, 0.08, "and most texels keep their face's swatch (%.4f)" % share)
	assert_almost_eq(_mask.get_pixel(0, 0).a, 128.0 / 255.0, 0.01, "the mask carries the marker, 128 / 255")


## The vest's pockets, seams and hem and the trousers' folds are ink now.
func test_the_vest_and_the_trousers_carry_their_ink() -> void:
	var vest := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_VEST and _in_box(tri, VEST_MIN, VEST_MAX))
	var jeans := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_JEANS and _in_box(tri, JEANS_MIN, JEANS_MAX))
	print("ROLL-PUNK ink: vest %d faces %d of %d samples (%.4f), jeans %d faces %d of %d (%.4f)" % [vest.faces, vest.ink, vest.samples, vest.share, jeans.faces, jeans.ink, jeans.samples, jeans.share])
	assert_gt(int(vest.faces), 500, "the vest box holds faces (%d)" % vest.faces)
	assert_gte(float(vest.share), VEST_INK_MIN, "the vest carries its pockets, seams and hem (%.4f)" % vest.share)
	assert_gte(float(jeans.share), JEANS_INK_MIN, "the trousers carry their folds (%.4f)" % jeans.share)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_true(report.has("crease") and report.has("texel_swatch"), "the report says the crease ink and the texel codes were baked")
	assert_gt(int(report.crease.texels_on_a_crease), 5000, "from texels on a crease")
	assert_lt(float(report.texel_swatch.differ_from_face_share), 0.08, "few texels leave their face's swatch")


## The Punk's own face and cap keep M4's tuned ink: the face under the 2% ceiling (the face test's own margin is 1.75%), no ink on the cap's strap arch.
func test_the_punks_tuned_zones_are_kept() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	var zones: Dictionary = {}
	for zone: Dictionary in cfg.palette.detail_bake.zones:
		zones[zone.name] = zone
	for need: String in ["face_skin", "nose", "strap", "cap", "boots", "laces", "shades_frame"]:
		assert_true(zones.has(need), "M4's zone %s stays" % need)
	assert_eq(float(zones.face_skin.ink_high), 0.1, "the face's thresholds are M4's (0.04 / 0.10)")
	assert_eq(float(zones.nose.ink_high), 0.05, "and the nose's")
	assert_true(bool(zones.strap.no_ink) and bool(zones.laces.no_ink) and bool(zones.shades_frame.no_ink), "the strap, the laces and the frame take no ink")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_lt(float(report.zones.face_skin.ink_texels_share), 0.0175, "the face's ink stays under M4's margin")


## The recipe's choices for a character whose texture draws its own lines: the relax stays at the Punk's 3 and there is no island merge (it
## ate the strap arch's faces and broke the laces' edges); the crease is off where the texture's strokes are (skin, tank, wraps, lens, face).
func test_the_punks_config_holds_the_recipe_values() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_false(cfg.palette.has("min_island_area_m2"), "no island merge: the strap arch and the laces are small authored parts")
	var detail: Dictionary = cfg.palette.detail_bake
	assert_true(detail.has("crease") and detail.has("texel_swatch"), "the crease ink and the texel codes are on")
	var across := float(detail.crease.width_m) + 1.7 * float(detail.crease.ramp_m)
	assert_lte(across, 0.008, "crease lines at most 8 mm across (%.4f)" % across)
	assert_gte(across, 0.004, "and not thinner than the mask holds")
	var zones: Dictionary = {}
	for zone: Dictionary in detail.zones:
		zones[zone.name] = zone
	for off: String in ["skin_body", "dark_body", "wraps", "lens", "face_skin", "nose", "laces", "strap", "shades_frame"]:
		assert_gt(float(zones[off].crease_deg), 180.0, "%s draws no crease" % off)
	assert_lt(float(zones.vest.valley_deg), 30.0, "the vest draws shallow valleys")
	assert_lt(float(zones.jeans.valley_deg), 30.0, "and so do the trousers")
	assert_false(zones.cap.has("valley_deg"), "the cap draws none")


## The veteran is a palette swap: his atlas gives slots 16 and 18 another colour and leaves every other swatch alone, so the codes (which name a
## slot) recolour the vest and the trousers at the texture's border. The swap's alpha (damage class, gloss) is the Punk's.
func test_the_veterans_swap_recolours_the_slots_the_codes_name() -> void:
	var base := (load(ATLAS) as Texture2D).get_image()
	var veteran := (load(VETERAN_ATLAS) as Texture2D).get_image()
	for img: Image in [base, veteran]:
		if img.is_compressed():
			img.decompress()
	var recoloured: Array[int] = []
	for slot: int in SLOTS_ALLOWED:
		var uv := ToonMaterials.texel_swatch_uv(slot + 1)
		var a := base.get_pixel(int(uv.x * base.get_width()), int(uv.y * base.get_height()))
		var b := veteran.get_pixel(int(uv.x * veteran.get_width()), int(uv.y * veteran.get_height()))
		assert_almost_eq(a.a, b.a, 0.002, "slot %d: the swap keeps its alpha" % slot)
		if (a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b) > 0.0004:
			recoloured.append(slot)
	assert_eq(recoloured, [SLOT_VEST, SLOT_JEANS], "only the vest's and the trousers' slots are recoloured")
	# the codes give those two slots a large share of the samples: the swap shows
	var named := 0
	var total := 0
	for tri: int in range(0, _tris().size() / 3, 3):
		for w: Vector3 in SAMPLES:
			var code := roundi(_mask_at(tri, w).b * 255.0) - 1
			total += 1
			if code == SLOT_VEST or code == SLOT_JEANS:
				named += 1
	assert_gt(float(named) / float(total), 0.3, "the codes name the vest or the trousers on over 30%% of the samples (%d of %d)" % [named, total])
