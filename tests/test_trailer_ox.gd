extends GutTest
## Milestone 7 (e-ox): Ox, the boss, under the trailer look. He KEEPS HIS M6 COLOURING (Game-boy's instruction: the trailer drained him of colour and he
## disliked that): the trailer art is the same palette as flat fills (assets/source/trailer_art/boss/paint.json "regions_from_atlas"), the same hard-edged
## shade, line, rim and blob shadow as the other figures, a bold drawn face, and bruises as placed shapes. Generic checks for every character are in
## tests/test_trailer_art.gd; this file pins what is Ox's: his hues, his face lines, his stage.
const BOSS_ART := "res://game/actors/art/boss_art.tres"
const ATLAS := "res://assets/export/palette/palette_atlas.png"
const STAGE := "res://tests/fixtures/m7/ox_trailer_stage.tscn"
## The palette atlas: 32 x 2 cells of 8 px, a mesh's UV1 names the cell.
const GRID := Vector2i(32, 2)
const CELL_PX := 8
## The palette cells Ox is made of: his coat and trousers, his orange (gloves, band, belt), his skin.
const COAT_CELL := 50
const ORANGE_CELL := 51
const SKIN_CELL := 7
## The grey cells (trousers, belt-cloth) and the near-black one (the coat's trim) that the first version had warmed to brown.
const TROUSER_CELL := 53
const DARK_CELL := 54
## How far the paint's red may lead its blue beyond the swatch's own lead (0..1).
const NEUTRAL_LEAD := 0.04
## What the m6 look shows of a swatch: the swatch times the warm key light of the stage the m6 captures are made on (the same stage and key as
## tests/fixtures/m7/trailer_stage.gd). (The coat's swatch is a near-neutral cool grey; the first trailer version warmed it to brown to match this stage, and the level's m6 look is grey, so only the orange and the skin are held to the key's hue.)
const M6_KEY := Color(1.0, 0.62, 0.34)
## How far (0..1 of the hue circle) the trailer colour's hue may sit from what m6 shows: about 14 degrees.
const HUE_TOLERANCE := 0.04
## The trailer must not drain him: saturation at least this share of the swatch's own.
const MIN_SATURATION_SHARE := 0.4

var _art: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	_art = load(BOSS_ART) as CharacterArt


func after_each() -> void:
	Tuning.reset_to_default()


func _image(tex: Texture2D) -> Image:
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _first_mesh(art: CharacterArt) -> ArrayMesh:
	var holder := art.scene.instantiate()
	var found: ArrayMesh = null
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		found = (node as MeshInstance3D).mesh as ArrayMesh
		break
	holder.free()
	return found


func _swatch(atlas: Image, cell: int) -> Color:
	var cx := cell % GRID.x
	var cy := cell / GRID.x
	return atlas.get_pixel(cx * CELL_PX + CELL_PX / 2, cy * CELL_PX + CELL_PX / 2)


## The paint map's colour in each palette cell of the trailer mesh: the median colour (per channel) of the texels at the UV2 of the cell's vertices.
func _paint_by_cell() -> Dictionary:
	var mesh := _first_mesh(_art.trailer_art())
	var arrays := mesh.surface_get_arrays(0)
	var uv1 := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var uv2 := arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	var paint := _image(_art.trailer_art().get_meta(ToonMaterials.PAINT_META) as Texture2D)
	var samples := {}
	for i in uv1.size():
		var cell := clampi(int(uv1[i].y * GRID.y), 0, GRID.y - 1) * GRID.x + clampi(int(uv1[i].x * GRID.x), 0, GRID.x - 1)
		var px := Vector2i(clampi(int(uv2[i].x * paint.get_width()), 0, paint.get_width() - 1), clampi(int(uv2[i].y * paint.get_height()), 0, paint.get_height() - 1))
		if not samples.has(cell):
			samples[cell] = [[], [], []]
		var c := paint.get_pixelv(px)
		samples[cell][0].append(c.r)
		samples[cell][1].append(c.g)
		samples[cell][2].append(c.b)
	var out := {}
	for cell: int in samples:
		var channels: Array[float] = []
		for ch in 3:
			var values: Array = samples[cell][ch]
			values.sort()
			channels.append(float(values[values.size() / 2]))
		out[cell] = Color(channels[0], channels[1], channels[2])
	return out


func _hue_gap(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 1.0 - d)


func test_ox_carries_a_painted_trailer_variant_and_m6_is_untouched() -> void:
	var trailer := _art.trailer_art()
	assert_not_null(trailer, "boss_art.tres has metadata/trailer")
	assert_true(ToonMaterials.is_painted(trailer), "painted")
	assert_eq(_art.variant(&"m6"), _art)
	assert_eq(_art.variant(&"trailer"), trailer)
	assert_eq(_art.palette.resource_path, ATLAS, "m6 still wears the shared palette atlas")
	assert_eq(_art.scene.resource_path, "res://assets/export/characters/boss/boss.glb", "m6 still wears his own mesh")
	assert_true(SkinnedArt.check(trailer).is_empty(), "the art contract holds: %s" % ", ".join(SkinnedArt.check(trailer)))


func test_his_trailer_colours_keep_the_hue_m6_shows_in_three_body_regions() -> void:
	var atlas := (load(ATLAS) as Texture2D).get_image()
	if atlas.is_compressed():
		atlas.decompress()
	var by_cell := _paint_by_cell()
	# the orange and the skin keep the hue the m6 look shows (the swatch times the warm key)
	for region: Array in [["orange trim", ORANGE_CELL], ["skin", SKIN_CELL]]:
		var cell: int = region[1]
		assert_true(by_cell.has(cell), "%s: the mesh uses palette cell %d" % [region[0], cell])
		var swatch := _swatch(atlas, cell)
		var m6 := swatch * M6_KEY
		var trailer: Color = by_cell[cell]
		assert_lt(_hue_gap(trailer.h, m6.h), HUE_TOLERANCE, "%s: trailer hue %.3f vs m6 %.3f" % [region[0], trailer.h, m6.h])
		assert_gt(trailer.s, swatch.s * MIN_SATURATION_SHARE, "%s: the trailer paint is not drained (s %.2f of the swatch's %.2f)" % [region[0], trailer.s, swatch.s])
	# x-chars: the coat, the trousers and the belt-cloth are the palette's neutral greys (the m6 level shows grey trousers and a near-black coat), never a warm brown:
	# the paint's red-over-blue lead stays within a few steps of the swatch's own
	for cell: int in [COAT_CELL, TROUSER_CELL, DARK_CELL]:
		assert_true(by_cell.has(cell), "the mesh uses palette cell %d" % cell)
		var swatch := _swatch(atlas, cell)
		var trailer: Color = by_cell[cell]
		assert_lt(trailer.r - trailer.b, maxf(swatch.r - swatch.b, 0.0) + NEUTRAL_LEAD, "cell %d is neutral grey, not brown (r %.2f b %.2f)" % [cell, trailer.r, trailer.b])
		assert_lt(trailer.s, swatch.s + 0.12, "cell %d is not warmed" % cell)


## x-chars: his orange is not darkened to burnt rust. The shared lit level shows the paint at a fraction of itself, so the paint carries at least the swatch's own
## value and saturation (the review found the boss roof showing the m6 safety orange as brown).
func test_his_orange_keeps_the_m6_saturation_and_value() -> void:
	var atlas := (load(ATLAS) as Texture2D).get_image()
	if atlas.is_compressed():
		atlas.decompress()
	var paint: Color = _paint_by_cell()[ORANGE_CELL]
	var swatch := _swatch(atlas, ORANGE_CELL)
	assert_gte(paint.v, swatch.v - 0.01, "orange value %.2f vs swatch %.2f" % [paint.v, swatch.v])
	assert_gte(paint.s, swatch.s - 0.02, "orange saturation %.2f vs swatch %.2f" % [paint.s, swatch.s])
	assert_lt(_hue_gap(paint.h, swatch.h), 0.025, "orange hue %.3f vs swatch %.3f" % [paint.h, swatch.h])


func test_he_has_a_drawn_face_and_placed_marks() -> void:
	assert_true(FileAccess.file_exists("res://assets/source/trailer_art/boss/features.svg"), "the face drawing (brows, eyes, nose, mouth)")
	var marks := _art.trailer_art().get_meta(ToonMaterials.MARKS_META) as Texture2D
	assert_not_null(marks, "a mark map: bruises as placed shapes")
	assert_eq(marks.get_width(), 1024)
	# lines at the face: texels at the UV2 of the vertices in front of the head are inked far more than the same count anywhere on the coat
	var mesh := _first_mesh(_art.trailer_art())
	var arrays := mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uv2 := arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	var ink := _image(_art.trailer_art().get_meta(ToonMaterials.INK_META) as Texture2D)
	var size := ink.get_width()
	var face_hits := 0
	var face_n := 0
	for i in verts.size():
		var v := verts[i]
		# the face: in front of the head (the rig faces -Z), between the chin and the hood's brim, in the middle
		if v.z < -0.1 and v.y > 1.5 and v.y < 1.66 and absf(v.x) < 0.06:
			face_n += 1
			var px := Vector2i(int(uv2[i].x * size), int(uv2[i].y * size))
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if ink.get_pixel(clampi(px.x + dx, 0, size - 1), clampi(px.y + dy, 0, size - 1)).r > 0.5:
						face_hits += 1
	assert_gt(face_n, 20, "the face has vertices to sample")
	assert_gt(float(face_hits) / (face_n * 49.0), 0.03, "the drawn face's lines reach the ink map (%d of %d samples)" % [face_hits, face_n * 49])


func test_the_ox_stage_defaults_to_his_art() -> void:
	var stage := (load(STAGE) as PackedScene).instantiate()
	assert_eq(stage.call("_arg", "--art", ""), BOSS_ART)
	assert_gt(float(stage.call("_arg", "--head", "0")), 1.0)
	stage.free()
