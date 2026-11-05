extends GutTest
## Milestone 6, playtest feedback FB-DETAIL: the Bruiser pilot of "upscale the detail of every enemy". Game-boy found the Bruiser a
## blob: steel and purple in blotches, almost no interior ink, a visor that read as a black bar. The pilot changed the chain's
## settings for him (no border relax, a patch of one colour under palette.min_island_area_m2 merged into its neighbours, the
## dense mesh's sharp edges drawn as ink: palette.detail_bake.crease and a per-zone crease_deg), and these tests hold what it
## bought: the budget, the swatch set, the steel on the chest plates and the interior ink in the plate and jacket zones, each against
## a floor that the M6 export (before the pilot) fails (measured by checking that GLB out: the figures are in
## docs/milestones/M6-calls/FB-DETAIL.md). Every other character's `run.py --check` is a command, not a test: the roster test
## (tests/test_art_roster.gd) hashes each report against its GLBs, and the shared-step guard in test_art_contract.gd would fail
## on a new unconditional report key.
##
## DETAIL-2 (phase 2a, the Bruiser's quilting, clean colour borders and line weight) adds the tests at the end: the valley ink, the
## palette slot per texel in the mask's blue channel (and what reads it), the helmet region and the lines' weight.

const GLB := "res://assets/export/characters/bruiser/bruiser.glb"
const MASK := "res://assets/export/characters/bruiser/bruiser_detail.png"
const REPORT := "res://assets/source/characters/bruiser/report/report.json"
const PIPELINE := "res://assets/source/characters/bruiser/pipeline.json"
## Floors the M6 export fails (chest steel 0.809, plate ink 0.0616, jacket ink 0.0002) and today's passes (0.853, 0.322, 0.098).
const CHEST_STEEL_MIN := 0.84
const PLATE_INK_MIN := 0.2
const JACKET_INK_MIN := 0.05
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## The Bruiser's palette slots (assets/source/palette/bruiser.json plus the shared cream and skin): purple, steel, black-violet.
const SLOT_SKIN := 6
const SLOT_CREAM := 14
const SLOT_PURPLE := 44
const SLOT_STRAP := 45
const SLOT_BLACK := 46
## The helmet's own purple (FIX-ART-B, feedback-chars-07): the same colour as slot 44 that scuffs and never bleeds.
const SLOT_HELMET := 47
const SLOTS_ALLOWED: Array[int] = [6, 14, 44, 45, 46, 47]
## The no-blood damage class in the atlas's alpha (gen_palette.NO_BLOOD_ALPHA = 230).
const NO_BLOOD_ALPHA := 230.0 / 255.0
## Under the visor in the mesh's frame (x across, y up, -z the front): the scarf's purple, not the texture's cream wedge (FIX-ART-B).
const UNDER_VISOR_MIN := Vector3(-0.17, 1.57, -0.38)
const UNDER_VISOR_MAX := Vector3(0.17, 1.62, -0.05)
## The chest plates in the authored 1.8 m frame (x across, y up, -z the front): the concept's breastplate between the open jacket's
## flaps, from above the belt to under the scarf.
const CHEST_MIN := Vector3(-0.14, 1.12, -0.5)
const CHEST_MAX := Vector3(0.14, 1.36, 0.0)
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


func _in_box(p: Vector3, lo: Vector3, hi: Vector3) -> bool:
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and p.z >= lo.z and p.z <= hi.z


## The share of a triangle's sample points (SAMPLES) of the faces `pick` accepts whose mask value (R) is over 0.5.
func _ink_share(pick: Callable) -> Dictionary:
	var uv2: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV2]
	var idx := _tris()
	var hit := 0
	var total := 0
	for tri: int in idx.size() / 3:
		if not bool(pick.call(tri)):
			continue
		for w: Vector3 in SAMPLES:
			var uv: Vector2 = uv2[idx[tri * 3]] * w.x + uv2[idx[tri * 3 + 1]] * w.y + uv2[idx[tri * 3 + 2]] * w.z
			var c := _mask.get_pixel(clampi(int(uv.x * _mask.get_width()), 0, _mask.get_width() - 1), clampi(int(uv.y * _mask.get_height()), 0, _mask.get_height() - 1))
			total += 1
			if c.r > 0.5:
				hit += 1
	return {"samples": total, "ink": hit, "share": float(hit) / maxf(float(total), 1.0)}


func test_the_bruiser_stays_inside_his_triangle_budget() -> void:
	var tris := _tris().size() / 3
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_lte(tris, 15000, "SPEC section 10's enemy row, %d triangles" % tris)
	assert_gt(tris, 12000, "and the chain still fills it")
	assert_eq(int(cfg.palette.budget_tris), 15000, "the config says 15000 (a build over it is the departure the lead reports, one value away)")


func test_his_swatch_set_is_unchanged() -> void:
	var seen: Dictionary = {}
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	for uv: Vector2 in uvs:
		seen[_slot_of(uv)] = true
	for slot: int in seen:
		assert_true(SLOTS_ALLOWED.has(slot), "slot %d is one of 6, 14, 44, 45, 46, 47" % slot)
	for slot: int in [SLOT_PURPLE, SLOT_STRAP, SLOT_BLACK]:
		assert_true(seen.has(slot), "slot %d is on the mesh" % slot)


func test_the_chest_plates_are_steel_not_blotched_with_purple() -> void:
	var steel := 0
	var purple := 0
	var n := 0
	for tri: int in _tris().size() / 3:
		if not _in_box(_centre(tri), CHEST_MIN, CHEST_MAX):
			continue
		n += 1
		var slot := _slot_of_tri(tri)
		if slot == SLOT_STRAP:
			steel += 1
		elif slot == SLOT_PURPLE:
			purple += 1
	assert_gt(n, 300, "the chest zone holds faces (%d)" % n)
	var share := float(steel) / float(n)
	print("FB-DETAIL chest plates: %d faces, steel %.3f, purple %.3f" % [n, share, float(purple) / float(n)])
	assert_gte(share, CHEST_STEEL_MIN, "the breastplate is steel (%.3f; the M6 export 0.809)" % share)


func test_interior_ink_in_the_plate_and_jacket_zones() -> void:
	var plate := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_STRAP and _in_box(_centre(tri), Vector3(-0.9, 0.55, -0.6), Vector3(0.9, 1.58, 0.6)))
	var jacket := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_PURPLE and _in_box(_centre(tri), Vector3(-0.9, 0.9, -0.6), Vector3(0.9, 1.6, 0.6)))
	print("FB-DETAIL ink: plates %d of %d samples (%.4f), jacket %d of %d (%.4f)" % [plate.ink, plate.samples, plate.share, jacket.ink, jacket.samples, jacket.share])
	assert_gte(float(plate.share), PLATE_INK_MIN, "the plates carry their seams and edges (%.4f; the M6 export 0.0616)" % plate.share)
	assert_gte(float(jacket.share), JACKET_INK_MIN, "the jacket carries its scarf folds and seams (%.4f; the M6 export 0.0002)" % jacket.share)
	var mask_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_true(mask_report.has("crease"), "the report says the crease ink was baked")
	assert_gt(int(mask_report.crease.texels_on_a_crease), 5000, "from texels on a crease of the dense mesh")


## A character has taken the recipe when it has its own roll-out test, `tests/test_m6_feedback_detail_<id>.gd`, AND its `pipeline.json`
## really uses the recipe (`palette.detail_bake.crease`), so an empty or stale test file cannot opt it out (feedback-code-05).
## The guards below skip it, so each roll-out adds its own test and none edits these lists.
func _rolled_out(id: String) -> bool:
	if id != "bruiser" and not FileAccess.file_exists("res://tests/test_m6_feedback_detail_%s.gd" % id):
		return false
	var path := "res://assets/source/characters/%s/pipeline.json" % id
	if not FileAccess.file_exists(path):
		return false
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not cfg is Dictionary:
		return false
	var bake: Variant = ((cfg as Dictionary).get("palette", {}) as Dictionary).get("detail_bake", {})
	return bake is Dictionary and (bake as Dictionary).has("crease")


## Every roll-out test reads its own character's `pipeline.json` (the file names it), and that config holds the recipe's crease. The
## opt-out in `_rolled_out` is then backed by the config, not by a file's existence.
func test_every_roll_out_test_reads_its_own_pipeline_and_the_recipe() -> void:
	var rolled := 0
	var dir := DirAccess.open("res://tests")
	for file: String in dir.get_files():
		if not (file.begins_with("test_m6_feedback_detail_") and file.ends_with(".gd")):
			continue
		var id := file.trim_prefix("test_m6_feedback_detail_").trim_suffix(".gd")
		var text := FileAccess.get_file_as_string("res://tests/" + file)
		assert_string_contains(text, "characters/%s/pipeline.json" % id, "%s reads its own pipeline.json" % file)
		assert_true(_rolled_out(id), "%s: its pipeline.json has detail_bake.crease" % id)
		rolled += 1
	assert_gte(rolled, 4, "the Thug, the Kicker, Ox and the Punk have roll-out tests")
	assert_true(_rolled_out("bruiser"), "the Bruiser's pipeline.json has the recipe")
	assert_false(_rolled_out("dummy"), "the dummy has not rolled out")


## No character that hasn't rolled out asks for a crease, an island merge or a border relax of 0, so its `run.py --check` hash is the M6 one.
func test_no_other_character_uses_the_pilots_keys() -> void:
	var dir := DirAccess.open("res://assets/source/characters")
	for id: String in dir.get_directories():
		if _rolled_out(id):
			continue
		var path := "res://assets/source/characters/%s/pipeline.json" % id
		if not FileAccess.file_exists(path):
			continue
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var pal: Dictionary = cfg.get("palette", {})
		assert_false(pal.has("min_island_area_m2"), "%s: no island merge" % id)
		assert_false((pal.get("detail_bake", {}) as Dictionary).has("crease"), "%s: no crease ink" % id)


## The Bruiser's own config names the pilot's keys: the recipe's values for a character with a soft-bevelled Tripo model.
func test_the_bruisers_config_holds_the_recipe_values() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_eq(int(cfg.palette.border_relax_iterations), 0, "no border relax (it smeared the plates' bevels)")
	assert_gt(float(cfg.palette.min_island_area_m2), 0.0, "stray patches of a colour merge")
	assert_true((cfg.palette.detail_bake as Dictionary).has("crease"), "the crease ink is on")
	var with_crease := 0
	for zone: Dictionary in cfg.palette.detail_bake.zones:
		if zone.has("crease_deg"):
			with_crease += 1
	assert_gte(with_crease, 3, "the chest plates, the guards and the cloth ask for their own angle")


# --- DETAIL-2 -------------------------------------------------------------------------------------------------------------------

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


## The colour border follows the texture: every texel the mesh uses has a code, each names one of the Bruiser's slots, and a few
## per cent of them name a swatch other than their face's (the border moved off the faces' staircase), never most of them.
func test_the_mask_carries_a_palette_slot_per_texel() -> void:
	var c := _codes()
	print("DETAIL-2 codes: %d of %d samples coded, %d differ from the face" % [c.coded, c.total, c.differ])
	assert_gte(float(c.coded) / float(c.total), 0.99, "nearly every sample of every face has a code (%d of %d)" % [c.coded, c.total])
	assert_eq(int(c.allowed), int(c.coded), "and each names one of 6, 14, 44, 45, 46, 47")
	var share := float(c.differ) / float(c.total)
	assert_gt(share, 0.002, "the codes move some borders off the faces (%.4f)" % share)
	assert_lt(share, 0.08, "and most texels keep their face's swatch (%.4f)" % share)


## No art that hasn't rolled out has a mask marked as carrying codes (alpha 128/255; they are opaque), whatever their blue channel holds
## (the hero's is a grey), so the shader leaves their swatches as they were. The Bruiser's is marked.
func test_no_other_mask_has_codes() -> void:
	for id: String in ["punk", "player", "kicker", "thug", "boss"]:
		if _rolled_out(id):
			continue
		var img := (load("res://assets/export/characters/%s/%s_detail.png" % [id, id]) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var least := 1.0
		for y: int in range(0, img.get_height(), 4):
			for x: int in range(0, img.get_width(), 4):
				least = minf(least, img.get_pixel(x, y).a)
		assert_gte(least, 0.999, "%s: the mask is opaque" % id)
	assert_almost_eq(_mask.get_pixel(0, 0).a, 128.0 / 255.0, 0.01, "the Bruiser's mask carries the marker, 128 / 255")


## The decode: a code names its slot's swatch centre (the face UVs of the mesh are the same function), 0 names none.
func test_the_code_decodes_to_the_slots_swatch() -> void:
	assert_eq(ToonMaterials.texel_swatch_uv(0), Vector2(-1.0, -1.0), "0 is none")
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	var checked := 0
	for tri: int in range(0, _tris().size() / 3, 97):
		var uv := uvs[_tris()[tri * 3]]
		var slot := _slot_of(uv)
		assert_eq(ToonMaterials.texel_swatch_uv(slot + 1), uv, "slot %d: the code's swatch is the face's UV" % slot)
		checked += 1
	assert_gt(checked, 100, "faces were checked")
	var shader := FileAccess.get_file_as_string("res://game/fx/toon.gdshader")
	assert_string_contains(shader, "const vec2 ATLAS_GRID = vec2(32.0, 2.0);", "the shader's atlas grid is the layout's")
	assert_string_contains(shader, "texelFetch(detail_tex", "a code is read with no filtering (an index must not be interpolated)")
	assert_string_contains(shader, "w > 0.5 ? texel_swatch.a : swatch.a", "the damage class and gloss follow the texel's swatch")
	assert_string_contains(shader, "uniform bool use_texel_swatch = true;", "a uniform, never a shader variant")


## The art's material takes the switch and the fade from Tuning; off is M6's face swatches.
func test_the_material_carries_the_switch_and_the_fade() -> void:
	var material := ToonMaterials.art(load("res://assets/export/palette/palette_atlas.png") as Texture2D, load(MASK) as Texture2D, true)
	ToonMaterials.apply_look(material)
	assert_true(bool(material.get_shader_parameter(&"use_texel_swatch")), "on by default")
	var fade: Vector2 = material.get_shader_parameter(&"texel_swatch_fade")
	assert_lt(fade.x, fade.y, "a fade from %.1f to %.1f texels per pixel" % [fade.x, fade.y])
	var before := Tuning.data.look_texel_swatch
	Tuning.data.look_texel_swatch = false
	ToonMaterials.apply_look(material)
	assert_false(bool(material.get_shader_parameter(&"use_texel_swatch")), "the A/B switch gives the face swatches back")
	Tuning.data.look_texel_swatch = before
	ToonMaterials.apply_look(material)


## The helmet is the purple of the concept (the texture painted its back and sides steel in patches); the visor stays steel.
func test_the_helmet_is_purple() -> void:
	var purple := 0
	var n := 0
	for tri: int in _tris().size() / 3:
		var c := _centre(tri)
		if c.y > 1.72 and absf(c.x) < 0.25:
			n += 1
			if _slot_of_tri(tri) == SLOT_HELMET:
				purple += 1
	assert_gt(n, 100, "the helmet's top holds faces (%d)" % n)
	assert_gte(float(purple) / float(n), 0.95, "its top is the helmet's purple (%d of %d)" % [purple, n])


## FIX-ART-B (feedback-chars-07): hard headgear scuffs and never bleeds, so the helmet's purple is its own swatch (the same colour,
## alpha class 230), where the jacket's purple (slot 44) takes blood.
func test_the_helmet_swatch_is_the_jackets_purple_that_never_bleeds() -> void:
	var atlas := (load("res://assets/export/palette/palette_atlas.png") as Texture2D).get_image()
	if atlas.is_compressed():
		atlas.decompress()
	var jacket := atlas.get_pixel((SLOT_PURPLE % SWATCH_COLUMNS) * 8 + 4, (SLOT_PURPLE / SWATCH_COLUMNS) * 8 + 4)
	var helmet := atlas.get_pixel((SLOT_HELMET % SWATCH_COLUMNS) * 8 + 4, (SLOT_HELMET / SWATCH_COLUMNS) * 8 + 4)
	assert_eq(helmet.to_html(false), jacket.to_html(false), "the same purple")
	assert_almost_eq(helmet.a, NO_BLOOD_ALPHA, 0.005, "the helmet takes scuffs and no blood")
	assert_almost_eq(jacket.a, 1.0, 0.005, "the jacket still takes the clothes' marks and blood")
	var on_helmet := 0
	for tri: int in _tris().size() / 3:
		if _slot_of_tri(tri) == SLOT_HELMET:
			on_helmet += 1
	assert_gt(on_helmet, 300, "the swatch is on the mesh (%d faces)" % on_helmet)


## FIX-ART-B (feedback-chars-06): under the visor is the scarf's purple, not the texture's cream or skin wedge.
func test_under_the_visor_is_the_scarf_not_a_cream_wedge() -> void:
	var n := 0
	var wedge := 0
	for tri: int in _tris().size() / 3:
		if _in_box(_centre(tri), UNDER_VISOR_MIN, UNDER_VISOR_MAX):
			n += 1
			var slot := _slot_of_tri(tri)
			if slot == SLOT_CREAM or slot == SLOT_SKIN:
				wedge += 1
	assert_gt(n, 30, "the box under the visor holds faces (%d)" % n)
	assert_eq(wedge, 0, "none of them is cream or skin (%d of %d)" % [wedge, n])


## The line weight: a crease line is `width_m` plus 1.7 `ramp_m` across at the shader's cut, 10 mm in the pilot and about 7.8 mm now; the valley ink (quilting, folds) is on for the cloth and off for the scarf and the helmet.
func test_the_lines_are_the_punks_weight_and_the_quilting_is_on() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	var crease: Dictionary = cfg.palette.detail_bake.crease
	var across := float(crease.width_m) + 1.7 * float(crease.ramp_m)
	assert_lte(across, 0.008, "crease lines at most 8 mm across (%.4f; the pilot's 0.0101)" % across)
	assert_gte(across, 0.004, "and not thinner than the mask holds (%.4f)" % across)
	assert_true(crease.has("valley"), "the valley ink is configured")
	var zones: Dictionary = {}
	for zone: Dictionary in cfg.palette.detail_bake.zones:
		zones[zone.name] = zone
	assert_lt(float(zones.cloth.valley_deg), 30.0, "the cloth draws shallow valleys")
	assert_gt(float(zones.scarf.valley_deg), 180.0, "the scarf draws none")
	assert_gt(float(zones.helmet.valley_deg), 180.0, "nor the helmet")
	assert_false(zones.chest_plates.has("valley_deg"), "the steel keeps its creases only")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_true(report.has("texel_swatch"), "the report says the texel codes were baked")
	assert_lt(float(report.texel_swatch.differ_from_face_share), 0.08, "few texels leave their face's swatch")


## The new keys belong to the characters that have rolled out (their absence is what keeps every other `run.py --check` hash).
func test_no_other_character_uses_the_valley_or_texel_keys() -> void:
	var dir := DirAccess.open("res://assets/source/characters")
	for id: String in dir.get_directories():
		if _rolled_out(id):
			continue
		var path := "res://assets/source/characters/%s/pipeline.json" % id
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("texel_swatch"), "%s: no texel codes" % id)
		assert_false(text.contains("valley"), "%s: no valley ink" % id)


## VFIX-HEAVIES (verify-chars-02): the helmet's front band between the visor frame and the dome is the no-blood swatch too (it kept the
## jacket's slot 44 and a drip landed above the visor); the scarf below the visor still takes blood.
func test_the_helmet_front_never_bleeds_and_the_scarf_still_does() -> void:
	var band := 0
	var bleeding := 0
	var scarf := 0
	for tri: int in _tris().size() / 3:
		var c := _centre(tri)
		if absf(c.x) > 0.3 or c.z > -0.02:
			continue
		var slot := _slot_of_tri(tri)
		if c.y >= 1.64 and c.y <= 1.71:
			band += 1
			if slot == SLOT_PURPLE:
				bleeding += 1
		elif c.y < 1.55 and c.y > 1.3 and slot == SLOT_PURPLE:
			scarf += 1
	assert_gt(band, 40, "the band above the visor holds faces (%d)" % band)
	assert_eq(bleeding, 0, "none of them is the bleeding purple (%d)" % bleeding)
	assert_gt(scarf, 100, "the scarf below the visor still bleeds (%d faces)" % scarf)


## VFIX-HEAVIES (verify-chars-04): the scarf's top edge under the visor is one straight horizontal border (the region is cut along its
## top plane), so no scarf face stands in the steel frame above it and no steel or cream face hangs in the scarf below it.
func test_the_scarf_border_under_the_visor_is_straight() -> void:
	var stray_up := 0
	var stray_down := 0
	for tri: int in _tris().size() / 3:
		var c := _centre(tri)
		if absf(c.x) > 0.15 or c.z > -0.1 or c.z < -0.38:
			continue
		var slot := _slot_of_tri(tri)
		if c.y > 1.58 and c.y < 1.66 and slot == SLOT_PURPLE:
			stray_up += 1
		if c.y > 1.50 and c.y < 1.57 and (slot == SLOT_STRAP or slot == SLOT_CREAM or slot == SLOT_SKIN):
			stray_down += 1
	assert_eq(stray_up, 0, "no scarf purple stands in the frame (%d)" % stray_up)
	assert_eq(stray_down, 0, "no steel, cream or skin face hangs in the scarf (%d)" % stray_down)
