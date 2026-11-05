extends GutTest
## Milestone 6, playtest feedback ROLL-THUG: the Pipe Thug through recipe parts 1 and 2 (docs/milestones/M6-calls/FB-DETAIL.md and
## DETAIL-2.md, "Rollout recipe"; his own calls are in docs/milestones/M6-calls/ROLL-THUG.md). The Thug had a border relax of 3, no
## crease ink and face-sized colour borders: the strap's buckle, the hood's drape and the hoodie's hem were soft patches. His config now
## asks for no border relax, a small-island merge (fine enough to keep the buckle and the shin bands), the dense mesh's sharp edges
## and the hoodie's folds as ink, and a palette slot per texel. These tests hold what that bought, each against a floor that the M6
## export before the roll-out fails (measured by checking that GLB out of b454424: the figures are in the calls file).

const GLB := "res://assets/export/characters/thug/thug.glb"
const MASK := "res://assets/export/characters/thug/thug_detail.png"
const REPORT := "res://assets/source/characters/thug/report/report.json"
const PIPELINE := "res://assets/source/characters/thug/pipeline.json"
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## The Thug's palette slots (assets/source/palette/thug.json plus the shared skin): olive hoodie and trousers, yellow, black, skin.
const SLOT_OLIVE := 38
const SLOT_YELLOW := 39
const SLOT_BLACK := 40
const SLOT_SKIN := 7
const SLOTS_ALLOWED: Array[int] = [7, 38, 39, 40]
## The hoodie's body (the olive above the hips) in the authored 1.8 m frame (x across, y front/back, z up).
const HOODIE_MIN := Vector3(-0.9, -0.6, 0.95)
const HOODIE_MAX := Vector3(0.9, 0.6, 1.5)
## The chest strap with its buckle: the black and yellow faces of the torso (the box leaves the hands and the bandana out).
const STRAP_MIN := Vector3(-0.3, -0.5, 1.0)
const STRAP_MAX := Vector3(0.3, 0.5, 1.45)
## Floors the M6 export fails and today's passes (see ROLL-THUG.md for the figures).
const HOODIE_INK_MIN := 0.08
const STRAP_FACES_MIN := 500
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


func test_the_thug_stays_inside_his_budget() -> void:
	var tris := _tris().size() / 3
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_lte(tris, 15000, "SPEC section 10's enemy row, %d triangles" % tris)
	assert_gt(tris, 12000, "and the chain still fills it")
	assert_eq(int(cfg.palette.budget_tris), 15000, "the config says 15000")


func test_his_swatch_set_is_unchanged() -> void:
	var seen: Dictionary = {}
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	for uv: Vector2 in uvs:
		seen[_slot_of(uv)] = true
	for slot: int in seen:
		assert_true(SLOTS_ALLOWED.has(slot), "slot %d is one of the Thug's" % slot)
	for slot: int in SLOTS_ALLOWED:
		assert_true(seen.has(slot), "slot %d is on the mesh" % slot)


func test_the_hoodie_carries_its_folds_and_hem_as_ink() -> void:
	var hoodie := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_OLIVE and _in_box(tri, HOODIE_MIN, HOODIE_MAX))
	print("ROLL-THUG ink: hoodie %d faces %d of %d samples (%.4f)" % [hoodie.faces, hoodie.ink, hoodie.samples, hoodie.share])
	assert_gt(int(hoodie.faces), 1000, "the hoodie box holds faces (%d)" % hoodie.faces)
	assert_gte(float(hoodie.share), HOODIE_INK_MIN, "the drape, the hem and the pocket carry lines (%.4f)" % hoodie.share)
	var mask_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_true(mask_report.has("crease"), "the report says the crease ink was baked")
	assert_gt(int(mask_report.crease.texels_on_a_crease), 5000, "from texels on a crease of the dense mesh")


## The island merge is fine enough that the strap's buckle and the bandana (a few square centimetres of yellow on black and olive) survive it.
func test_the_buckle_and_the_strap_survive_the_island_merge() -> void:
	var faces := 0
	for tri: int in _tris().size() / 3:
		if [SLOT_BLACK, SLOT_YELLOW].has(_slot_of_tri(tri)) and _in_box(tri, STRAP_MIN, STRAP_MAX):
			faces += 1
	print("ROLL-THUG strap: %d black and yellow faces on the torso" % faces)
	assert_gte(faces, STRAP_FACES_MIN, "the strap and its buckle are faces of the torso (%d)" % faces)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette
	var share := float(report.swatches_used[str(SLOT_YELLOW)].area_share)
	assert_gt(share, 0.04, "the yellow (bandana, wraps, shin bands, buckle) keeps its share of the surface (%.3f)" % share)


## The colour border follows the texture: every texel the mesh uses has a code, each names one of the Thug's slots, and a few per
## cent of them name a swatch other than their face's, never most of them.
func test_the_mask_carries_a_palette_slot_per_texel() -> void:
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
	print("ROLL-THUG codes: %d of %d samples coded, %d differ from the face" % [coded, total, differ])
	assert_gte(float(coded) / float(total), 0.99, "nearly every sample of every face has a code (%d of %d)" % [coded, total])
	assert_eq(allowed, coded, "and each names one of 7, 38, 39, 40")
	var share := float(differ) / float(total)
	assert_gt(share, 0.002, "the codes move some borders off the faces (%.4f)" % share)
	assert_lt(share, 0.08, "and most texels keep their face's swatch (%.4f)" % share)
	assert_almost_eq(_mask.get_pixel(0, 0).a, 128.0 / 255.0, 0.01, "the mask carries the marker, 128 / 255")


## The Thug's own config names the recipe's keys: part 1's relax and island merge, the crease, and part 2's texel codes and line weight.
func test_the_thug_config_holds_the_recipe_values() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_eq(int(cfg.palette.border_relax_iterations), 0, "no border relax")
	assert_gt(float(cfg.palette.min_island_area_m2), 0.0, "stray patches merge")
	assert_lte(float(cfg.palette.min_island_area_m2), 0.002, "but a buckle (a few cm2) is not a stray patch")
	var bake: Dictionary = cfg.palette.detail_bake
	assert_true(bake.has("crease"), "the crease ink is on")
	assert_true(bake.has("texel_swatch"), "the palette slot per texel is on")
	var crease: Dictionary = bake.crease
	var across := float(crease.width_m) + 1.7 * float(crease.ramp_m)
	assert_lte(across, 0.0075, "lines at most 7.5 mm across for the slimmer model (%.4f)" % across)
	assert_gte(across, 0.004, "and not thinner than the mask holds (%.4f)" % across)
	assert_true(crease.has("valley"), "the valley ink is configured")
	var zones: Dictionary = {}
	for zone: Dictionary in bake.zones:
		zones[zone.name] = zone
	for need: String in ["hoodie", "trousers", "face_skin", "headwear", "boots", "bandana", "buckle", "wraps"]:
		assert_true(zones.has(need), "zone %s" % need)
	assert_lt(float(zones.hoodie.valley_deg), 30.0, "the hoodie draws shallow valleys")
	assert_gt(float(zones.trousers.valley_deg), 180.0, "the trousers draw none (the crotch scribbled)")
	assert_gt(float(zones.face_skin.crease_deg), 180.0, "the face takes no crease line")
	assert_gt(float(zones.headwear.valley_deg), 180.0, "nor does the beanie draw valleys")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_lt(float(report.texel_swatch.differ_from_face_share), 0.08, "few texels leave their face's swatch")

## Playtest fix (feedback-chars-01): the right half of the face and the bandana are skin and yellow, not the beanie's black (slot 40
## never bleeds or bruises). The faces between the bandana's bottom and the beanie's rim, across the front, name only 7 and 39.
func test_the_face_and_the_bandana_carry_no_beanie_black() -> void:
	var lo := Vector3(-0.12, 0.02, 1.51)
	var hi := Vector3(0.06, 0.3, 1.62)
	var faces := 0
	var black := 0
	for tri: int in _tris().size() / 3:
		if not _in_box(tri, lo, hi):
			continue
		faces += 1
		if _slot_of_tri(tri) == 40:
			black += 1
	assert_gt(faces, 40, "the face box holds faces (%d)" % faces)
	assert_eq(black, 0, "none of them is the beanie's slot 40")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	var names: Array[String] = []
	for reg: Dictionary in cfg.palette.regions:
		assert_true(reg.has("only_from"), "%s only repaints the slots it names" % reg.name)
		names.append(str(reg.name))
	assert_true(names.has("face_right") and names.has("bandana_right"), "the face and the bandana have their regions")


## Playtest fix (feedback-chars-02, -08): the hoodie keeps its valleys at the pocket and hem and draws none on the neck and chest drape;
## the waistband draws no ring of dashes.
func test_the_hoodie_draws_its_valleys_low_and_the_waist_is_plain() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	var zones: Dictionary = {}
	for zone: Dictionary in cfg.palette.detail_bake.zones:
		zones[zone.name] = zone
	assert_lt(float(zones.hoodie.valley_deg), 30.0, "the hoodie's pocket and hem keep valleys")
	assert_lte(float(zones.hoodie.max[2]), 1.4, "but only below the chest")
	assert_gte(float(zones.hood_neck.min[2]), float(zones.hoodie.max[2]), "the neck zone starts where the hoodie's ends")
	assert_gt(float(zones.hood_neck.valley_deg), 180.0, "the neck and chest draw no valley ink")
	assert_lt(float(zones.hood_neck.crease_deg), 180.0, "but the hood's drape keeps its creases")
	assert_gt(float(zones.waist.crease_deg), 180.0, "the waist draws no crease ring")
	var names: Array[String] = []
	for zone: Dictionary in cfg.palette.detail_bake.zones:
		names.append(str(zone.name))
	assert_gt(names.find("waist"), names.find("trousers"), "the waist zone comes after the trousers, so it wins")
	var neck := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == 38 and _in_box(tri, Vector3(-0.2, 0.0, 1.4), Vector3(0.2, 0.3, 1.6)))
	var hem := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == 38 and _in_box(tri, Vector3(-0.4, -0.4, 0.95), Vector3(0.4, 0.4, 1.3)))
	gut.p("thug neck ink %.4f (%d faces), hem ink %.4f (%d faces)" % [neck.share, neck.faces, hem.share, hem.faces])
	assert_gt(int(neck.faces), 20, "the neck box holds olive faces")
	assert_lt(float(neck.share), float(hem.share), "the neck is calmer than the pocket and the hem")
