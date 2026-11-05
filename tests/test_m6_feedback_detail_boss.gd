extends GutTest
## Milestone 6, playtest feedback ROLL-OX: Ox Pellerin through the Bruiser pilot's recipe (docs/milestones/M6-calls/FB-DETAIL.md,
## "Rollout recipe"; his own calls are in docs/milestones/M6-calls/ROLL-OX.md). Ox had no ink zones and a border relax of 5, so his
## colour borders were soft face-sized patches and his belt plate, lapels and robe seams carried no line. His config now asks for no
## border relax, a small-island merge (fine enough to keep the orange laces), the dense mesh's sharp edges as ink and seven zones
## (the robe, the shorts, the boots, the belt, the trim, the face and the gloves). These tests hold what that bought, each against
## a floor that the M6 export before the roll-out fails (measured by checking that GLB out of aca0c10: the figures are in the calls file).

const GLB := "res://assets/export/characters/boss/boss.glb"
const MASK := "res://assets/export/characters/boss/boss_detail.png"
const REPORT := "res://assets/source/characters/boss/report/report.json"
const PIPELINE := "res://assets/source/characters/boss/pipeline.json"
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## Ox's palette slots (assets/source/palette/boss.json plus the shared skin): skin, charcoal, orange, shorts, glove.
const SLOT_SKIN := 7
const SLOT_CHARCOAL := 50
const SLOT_ORANGE := 51
const SLOT_SHORTS := 53
const SLOT_GLOVE := 54
const SLOTS_ALLOWED: Array[int] = [7, 50, 51, 52, 53, 54]
## The belt (the champion's plate and its strap) and the robe's body in the authored 1.8 m frame (x across, y front/back, z up).
const BELT_MIN := Vector3(-0.3, -0.6, 0.95)
const BELT_MAX := Vector3(0.3, 0.6, 1.2)
const ROBE_MIN := Vector3(-0.9, -0.6, 0.7)
const ROBE_MAX := Vector3(0.9, 0.6, 1.9)
## Floors the M6 export fails and today's passes (see ROLL-OX.md for the figures).
const BELT_INK_MIN := 0.1
const ROBE_INK_MIN := 0.03
const LACE_FACES_MIN := 100
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


func test_ox_stays_inside_his_boss_budget() -> void:
	var tris := _tris().size() / 3
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_lte(tris, 30000, "SPEC section 10's boss row, %d triangles" % tris)
	assert_gt(tris, 25000, "and the chain still fills it")
	assert_eq(int(cfg.palette.budget_tris), 30000, "the config says 30000")


func test_his_swatch_set_and_round_gloves_are_unchanged() -> void:
	var seen: Dictionary = {}
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	for uv: Vector2 in uvs:
		seen[_slot_of(uv)] = true
	for slot: int in seen:
		assert_true(SLOTS_ALLOWED.has(slot), "slot %d is one of Ox's" % slot)
	for slot: int in [SLOT_SKIN, SLOT_CHARCOAL, SLOT_ORANGE, SLOT_SHORTS, SLOT_GLOVE]:
		assert_true(seen.has(slot), "slot %d is on the mesh" % slot)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_eq(String(cfg.parts.fists.source), "generated", "the round glove of the final fix is still the generated one")
	assert_true(String(cfg.parts.fists.generated.mesh).ends_with("e3c153f4_gen.glb"), "and it is the same Tripo glove")


func test_the_belt_and_the_robe_carry_their_ink() -> void:
	var belt := _ink_share(func(tri: int) -> bool: return [SLOT_CHARCOAL, SLOT_ORANGE].has(_slot_of_tri(tri)) and _in_box(tri, BELT_MIN, BELT_MAX))
	var robe := _ink_share(func(tri: int) -> bool: return _slot_of_tri(tri) == SLOT_CHARCOAL and _in_box(tri, ROBE_MIN, ROBE_MAX))
	print("ROLL-OX ink: belt %d faces %d of %d samples (%.4f), robe %d faces %d of %d (%.4f)" % [belt.faces, belt.ink, belt.samples, belt.share, robe.faces, robe.ink, robe.samples, robe.share])
	assert_gt(int(belt.faces), 500, "the belt box holds faces (%d)" % belt.faces)
	assert_gte(float(belt.share), BELT_INK_MIN, "the plate and its strap carry their edges (%.4f)" % belt.share)
	assert_gte(float(robe.share), ROBE_INK_MIN, "the robe carries its seams and lapel edges (%.4f)" % robe.share)
	var mask_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette.detail_bake
	assert_true(mask_report.has("crease"), "the report says the crease ink was baked")
	assert_gt(int(mask_report.crease.texels_on_a_crease), 5000, "from texels on a crease of the dense mesh")


## The island merge is fine enough that the orange laces on the boots (a few square centimetres each) survive it.
func test_the_orange_laces_survive_the_island_merge() -> void:
	var laces := 0
	for tri: int in _tris().size() / 3:
		if _slot_of_tri(tri) == SLOT_ORANGE and _centre(tri).y < 0.3:
			laces += 1
	print("ROLL-OX laces: %d orange faces under 0.3 m" % laces)
	assert_gte(laces, LACE_FACES_MIN, "the laces are orange faces on the boots (%d)" % laces)


func test_the_orange_trim_is_not_eaten_by_the_merge() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)).steps.palette
	var share := float(report.swatches_used[str(SLOT_ORANGE)].area_share)
	assert_gt(share, 0.12, "the trim, belt plate, cuffs and wraps keep their share of the surface (%.3f)" % share)


## Ox's own config names the recipe's keys; the gloves, the face and the cloth ask for their own crease.
func test_ox_config_holds_the_recipe_values() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	assert_eq(int(cfg.palette.border_relax_iterations), 0, "no border relax")
	assert_gt(float(cfg.palette.min_island_area_m2), 0.0, "stray patches merge")
	assert_lte(float(cfg.palette.min_island_area_m2), 0.001, "but a lace (a few cm2) is not a stray patch")
	assert_true((cfg.palette.detail_bake as Dictionary).has("crease"), "the crease ink is on")
	var names: Array[String] = []
	var off := {}
	for zone: Dictionary in cfg.palette.detail_bake.zones:
		names.append(String(zone.name))
		if zone.has("crease_deg"):
			off[String(zone.name)] = float(zone.crease_deg)
	for need: String in ["robe", "shorts", "boots", "belt", "trim", "face_skin", "gloves"]:
		assert_true(names.has(need), "zone %s" % need)
	assert_lt(float(off.belt), 45.0, "the belt plate's bevels are soft: a low angle")
	assert_gt(float(off.gloves), 180.0, "the round gloves take no crease line")
	assert_gt(float(off.face_skin), 180.0, "nor does the face")
