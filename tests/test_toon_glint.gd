extends GutTest
## The lens glint is gated by an authored streak mask (re-score finding rescore-rs-01; docs/ARCHITECTURE.md "Toon shader"
## and "The Punk's detail mask"). The glint is a cap on an angle: the camera-fixed fill's half vector is 26 degrees off the view
## axis and the cap's cone 28, so a visor that faces the camera or tips up into it (the head tipped back in a stagger or the
## taunt, the Punk lying seen from above) clipped whole to white, a blindfold. The Punk's detail mask now carries the two
## streaks of concept A per eye in its G channel, on the lens's texels only, and the shader multiplies the glint by it.
## A headless run draws nothing, so the pixels are the captures'; these tests read the shader's text, the mask's content and
## the same cap evaluated over the lens's own texels at head pitches.

const TOON_PATH := "res://game/fx/toon.gdshader"
const LIGHT_PATH := "res://game/fx/toon_light.gdshaderinc"
const GRID_PATH := "res://game/level/grid.gdshader"
const ATLAS_PATH := "res://assets/export/palette/palette_atlas.png"
const PUNK_GLB := "res://assets/export/characters/punk/punk.glb"
const PUNK_MASK := "res://assets/export/characters/punk/punk_detail.png"
## The palette atlas's layout (the contract's): 32 columns of swatches, two rows.
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
## Head pitches about the ears, degrees (positive = the head tipped back, the visor turned up toward the camera).
const PITCHES: Array[float] = [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0]
## The most of the lens the glint may ever light, at any pitch (concept A: the streaks are about a third of the lens).
const GLINT_SHARE_MAX := 0.45
## The least the cap alone (no gate) must light at some pitch, or the bound above would hold without the gate.
const UNGATED_SHARE_MIN := 0.3


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_the_shader_gates_the_glint_with_the_masks_g() -> void:
	var shader := _source(TOON_PATH)
	var light := _source(LIGHT_PATH)
	assert_string_contains(shader, "glint_gate = 1.0;", "no mask, no gate: a flat-painted surface or an art without a mask keeps its glint whole")
	assert_string_contains(shader, "texture(detail_tex, UV2).g", "the gate is G of the mask on the second UV set")
	assert_string_contains(shader, "glint_gate = smoothstep(0.5 - streak_edge, 0.5 + streak_edge, streak);", "cut at 0.5, the distance ramp's edge, one pixel wide")
	assert_true(shader.find("glint_gate = 1.0;") < shader.find("if (use_detail_tex) {"), "the default is set before the mask's branch")
	assert_true(shader.find("texture(detail_tex, UV2).g") > shader.find("if (use_detail_tex) {"), "and G is read only with a mask")
	assert_string_contains(light, "varying float glint_gate;", "the include declares the varying with the other per-swatch ones")
	assert_true(light.find("varying float glint_gate;") > light.find("#ifdef TOON_SWATCH_SPEC"), "under the define, so the grid's own light() is unchanged")
	assert_string_contains(light, "SPECULAR_LIGHT += glint * glint_gate * spec_strength * spec_gloss * glint_strength * light_color;", "the glint can only light a streak")
	assert_false(_source(GRID_PATH).contains("glint_gate"), "the floor does not ask for it")
	assert_string_contains(shader, "texture(detail_tex, UV2).r", "R is still the ink")


## The atlas, with its alpha, as the shader samples it.
func _glossy_slots() -> Array[int]:
	var image := (load(ATLAS_PATH) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var out: Array[int] = []
	for slot in SWATCH_COLUMNS * SWATCH_ROWS:
		var alpha := image.get_pixel((slot % SWATCH_COLUMNS) * 8 + 4, (slot / SWATCH_COLUMNS) * 8 + 4).a
		if ToonMaterials.swatch_glossy(alpha):
			out.append(slot)
	return out


func _slot_of(uv: Vector2) -> int:
	return int(floorf(uv.x * float(SWATCH_COLUMNS))) + SWATCH_COLUMNS * int(floorf(uv.y * float(SWATCH_ROWS)))


## The lens's texels in the mask: each is {x, y (pixel), n (the surface normal, model space), px (the model-space x)}, from every
## triangle of the Punk's Body whose three vertices wear a glossy slot, rasterised on UV2 at the mask's size. `border` also
## returns the texels within 3 of the lens's own (the fill the bake writes outside an island), as a flag per pixel.
func _lens(mask_size: int) -> Dictionary:
	var glossy := _glossy_slots()
	var root := (load(PUNK_GLB) as PackedScene).instantiate() as Node3D
	add_child_autofree(root)
	var texels: Array[Dictionary] = []
	var near := PackedByteArray()
	near.resize(mask_size * mask_size)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t in index.size() / 3:
				var i := [index[t * 3], index[t * 3 + 1], index[t * 3 + 2]]
				if not (glossy.has(_slot_of(uv[i[0]])) and glossy.has(_slot_of(uv[i[1]])) and glossy.has(_slot_of(uv[i[2]]))):
					continue
				var p: Array[Vector2] = [uv2[i[0]] * float(mask_size), uv2[i[1]] * float(mask_size), uv2[i[2]] * float(mask_size)]
				var lo := Vector2(minf(p[0].x, minf(p[1].x, p[2].x)), minf(p[0].y, minf(p[1].y, p[2].y)))
				var hi := Vector2(maxf(p[0].x, maxf(p[1].x, p[2].x)), maxf(p[0].y, maxf(p[1].y, p[2].y)))
				for y in range(maxi(int(floorf(lo.y)) - 3, 0), mini(int(ceilf(hi.y)) + 4, mask_size)):
					for x in range(maxi(int(floorf(lo.x)) - 3, 0), mini(int(ceilf(hi.x)) + 4, mask_size)):
						near[y * mask_size + x] = 1
				for y in range(maxi(int(floorf(lo.y)), 0), mini(int(ceilf(hi.y)), mask_size)):
					for x in range(maxi(int(floorf(lo.x)), 0), mini(int(ceilf(hi.x)), mask_size)):
						var w := _barycentric(Vector2(float(x) + 0.5, float(y) + 0.5), p[0], p[1], p[2])
						if w.x < 0.0 or w.y < 0.0 or w.z < 0.0:
							continue
						var n := (normals[i[0]] * w.x + normals[i[1]] * w.y + normals[i[2]] * w.z).normalized()
						var pos := verts[i[0]] * w.x + verts[i[1]] * w.y + verts[i[2]] * w.z
						texels.append({x = x, y = y, n = n, px = pos.x})
	return {texels = texels, near = near}


func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var d := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 1e-12:
		return Vector3(-1, -1, -1)
	var l0 := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
	var l1 := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
	return Vector3(l0, l1, 1.0 - l0 - l1)


func test_the_lens_streaks_are_in_g_on_the_lens_texels_only() -> void:
	var mask := (load(PUNK_MASK) as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	var size := mask.get_width()
	var lens := _lens(size)
	var texels: Array[Dictionary] = lens.texels
	var near: PackedByteArray = lens.near
	assert_gt(texels.size(), 1000, "the lens has texels in the mask")
	# G is 0 on every texel that is not the lens's or its border fill: the streaks are on the lens alone.
	var stray := 0
	var lit_anywhere := 0
	var max_blue := 0
	var bytes := mask.get_data()
	var stride := 4 if mask.get_format() == Image.FORMAT_RGBA8 else 3
	assert_true(mask.get_format() == Image.FORMAT_RGBA8 or mask.get_format() == Image.FORMAT_RGB8, "the mask is an 8-bit RGB(A) image")
	for y in size:
		for x in size:
			var at := (y * size + x) * stride
			max_blue = maxi(max_blue, bytes[at + 2])
			if bytes[at + 1] > 2:
				lit_anywhere += 1
				if near[y * size + x] == 0:
					stray += 1
	assert_eq(max_blue, 0, "B holds nothing")
	assert_gt(lit_anywhere, 500, "there are streaks")
	assert_eq(stray, 0, "G is 0 everywhere but the lens and its 3-texel border: the gate is not shading and not ink")
	# The streaks are a share of the lens, on both of its halves (the viewer's two eyes), with edges (a ramp, not a flat fill).
	var on := 0
	var on_left := 0
	var on_right := 0
	var ramp := 0
	for t: Dictionary in texels:
		var g := mask.get_pixel(int(t.x), int(t.y)).g
		if g >= 0.5:
			on += 1
			if float(t.px) < -0.01:
				on_left += 1
			elif float(t.px) > 0.01:
				on_right += 1
		if g > 0.05 and g < 0.95:
			ramp += 1
	var share := float(on) / float(texels.size())
	gut.p("GLINT-GATE streak texels %d of %d lens texels (%.1f%%), left %d right %d, %d on the ramp" % [on, texels.size(), share * 100.0, on_left, on_right, ramp])
	assert_between(share, 0.15, 0.45, "the streaks are about a third of the lens, as concept A's are")
	assert_gt(on_left, 100, "streaks on one half of the lens")
	assert_gt(on_right, 100, "and on the other")
	assert_gt(ramp, 100, "the field is a distance ramp (0.5 on an edge), so the shader's cut stays sharp from a 1k texel")


## The shader's glint cap (toon_light.gdshaderinc) over the lens's own texels with the head pitched back: the share of the lens the cap
## lights with no gate, and with the mask's G as the gate. The Punk faces the camera (a half turn about Y, then the pitch about the
## ears), the light is the camera-fixed fill (ToonMaterials.fill_direction of the Look values), the view the lens axis.
func _glint_shares(pitch_deg: float, mask: Image, texels: Array[Dictionary]) -> Vector2:
	var d := Tuning.data
	var half := (ToonMaterials.fill_direction(d.look_fill_yaw_deg, d.look_fill_pitch_deg) + Vector3.BACK).normalized()
	var turn := Basis(Vector3.RIGHT, deg_to_rad(-pitch_deg)) * Basis(Vector3.UP, PI)
	var ungated := 0
	var gated := 0
	for t: Dictionary in texels:
		var n := turn * (t.n as Vector3)
		if n.dot(half) >= d.look_glint_cut:
			ungated += 1
			if mask.get_pixel(int(t.x), int(t.y)).g >= 0.5:
				gated += 1
	return Vector2(float(ungated), float(gated)) / float(texels.size())


func test_no_head_pose_whites_out_the_lens() -> void:
	var mask := (load(PUNK_MASK) as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	var texels: Array[Dictionary] = _lens(mask.get_width()).texels
	assert_gt(texels.size(), 1000, "the lens has texels")
	var worst_ungated := 0.0
	var worst_gated := 0.0
	var worst_pitch := 0.0
	var line := PackedStringArray()
	for pitch: float in PITCHES:
		var shares := _glint_shares(pitch, mask, texels)
		line.append("%+.0f: %.0f%%/%.0f%%" % [pitch, shares.x * 100.0, shares.y * 100.0])
		if shares.x > worst_ungated:
			worst_ungated = shares.x
		if shares.y > worst_gated:
			worst_gated = shares.y
			worst_pitch = pitch
	gut.p("GLINT-GATE lens lit by the cap, ungated/gated, by head pitch (positive = tipped back): %s" % ", ".join(line))
	assert_gt(worst_ungated, UNGATED_SHARE_MIN, "the cap alone lights over a third of the lens at some pitch (the bug this gate is for)")
	assert_lt(worst_gated, GLINT_SHARE_MAX, "with the gate no pitch lights more than the streaks (worst at %+.0f degrees)" % worst_pitch)
