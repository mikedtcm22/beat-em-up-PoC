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
const SLOTS_ALLOWED: Array[int] = [6, 14, 44, 45, 46]
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
		assert_true(SLOTS_ALLOWED.has(slot), "slot %d is one of 6, 14, 44, 45, 46" % slot)
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


## No other character's config asks for a crease, an island merge or a border relax of 0, so their `run.py --check` hashes are the M6 ones.
func test_no_other_character_uses_the_pilots_keys() -> void:
	var dir := DirAccess.open("res://assets/source/characters")
	for id: String in dir.get_directories():
		if id == "bruiser" or id == "boss":  # ROLL-OX: Ox's roll-out owns tests/test_m6_feedback_detail_boss.gd
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
