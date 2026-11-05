extends SceneTree
## Paints the environment kit's trim sheet (Milestone 6, KIT; plan D2 and D10; SPEC §10's "2k trim
## sheet" for a module) from assets/source/kit/trim_layout.json into assets/export/kit/trim_sheet.png
## (2048 x 2048, RGBA, imported with mipmaps) and assets/export/kit/trim_strips.json (what the game
## reads: each strip's row in the sheet, its period in metres, its flags). Run it from the project
## folder:
##   godot --headless -s tools/gen_trim.gd                   # paint, write the PNG and the strip table
##   godot --headless -s tools/gen_trim.gd -- --check        # compare the committed files with a repaint
##   godot --headless --import --quit                        # then import the PNG
## The sheet is 16 strips, one row of 128 px each. A strip tiles across the whole row (2048 px =
## `tile_m` metres, 4 by default) and wraps in V every `period_m`; the trim shader (game/fx/trim.gdshader)
## takes a face's UVs in metres and picks the row from the vertex colour, so a wall of any length and
## height fits. Every strip is seamless both ways. The RGB is the surface; the alpha is the INK mask
## (the painted seams, cracks and joints, cut by the shader at `look_trim_ink_cut` with a one-pixel
## edge, so a line stays crisp under the mipmaps), and on the scissor strip (the chain-link) it is the
## wire's coverage. Colours sit in the look bible's environment band, saturation at most 0.30 and
## value 0.25 to 0.6: every painted pixel is clamped into it (the ink strip and the ink are the one
## ink, HudStyle.INK). No ink is painted within a few px of a strip's top or bottom edge or of U = 0, so
## a face's border (which the edge pass draws) never doubles. Every pixel comes from an integer hash of
## its place, so a repaint is identical, byte for byte.
##
## The street's ground (M6 playtest feedback, FB-GROUND) is a second image, assets/export/kit/ground_sheet.png (2048 px over
## `ground.tile_m` metres, 8 by default): flat tonal shapes (worn patches, tar-sealed repairs, oil stains, patched squares) and
## bold tapered ink (branching cracks, the squares' outlines, a manhole, drain grates), every ink feature at least
## MIN_INK_PX wide so it survives the mips. A face on a strip flagged `ground` (the asphalt) samples it in world metres
## (game/fx/trim_body.gdshaderinc), the mips unlimited: it is not a stack of wrapped strips, so nothing can bleed into a
## neighbour. The sheet's own asphalt strip is the fallback (the Debug switch `ground_sheet_off`). The concrete, kerb and
## roof-tar strips get the same treatment: flat tones, bold ink, no one-texel marks.

const LAYOUT := "res://assets/source/kit/trim_layout.json"
const SHEET := "res://assets/export/kit/trim_sheet.png"
const STRIPS := "res://assets/export/kit/trim_strips.json"
const GROUND := "res://assets/export/kit/ground_sheet.png"
## The thinnest ink feature (px) any strip or the ground may paint: narrower marks alias under the mips.
const MIN_INK_PX := 5
## HudStyle.INK, the one ink (0.07, 0.06, 0.09).
const INK := Color(0.07, 0.06, 0.09)
## The environment band the painted colours are clamped into (the look bible), with a margin for the
## 8-bit round trip.
const SAT_MAX := 0.285
const VAL_MIN := 0.27
const VAL_MAX := 0.585

var _w: int = 2048
var _h: int = 128
var _img: Image
var _y0: int = 0
var _hsv: Dictionary = {}
var _seed: int = 0
var _px_per_m_u: float = 512.0
var _px_per_m_v: float = 256.0


func _initialize() -> void:
	var check := "--check" in OS.get_cmdline_user_args()
	var layout := JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) as Dictionary
	if layout == null or layout.is_empty():
		printerr("gen_trim: cannot read %s" % LAYOUT)
		quit(1)
		return
	var sheet := _paint(layout)
	var ground := _paint_ground(layout.ground as Dictionary)
	var table := _table(layout)
	if check:
		var ok := _check(sheet, table, ground)
		quit(0 if ok else 1)
		return
	sheet.save_png(SHEET)
	ground.save_png(GROUND)
	_write(STRIPS, table)
	_patch_import(SHEET)
	_patch_import(GROUND)
	print("Wrote %s, %s and %s (%d strips)" % [SHEET, GROUND, STRIPS, (layout.strips as Array).size()])
	quit(0)


## The strip table the game reads (json text).
func _table(layout: Dictionary) -> String:
	var rows: Array = []
	var sheet_px: float = float(layout.sheet_px)
	var row_px: float = float(layout.row_px)
	for entry: Dictionary in layout.strips:
		rows.append({
			name = entry.name,
			index = int(entry.row),
			v0 = float(entry.row) * row_px / sheet_px,
			vh = row_px / sheet_px,
			period_m = float(entry.period_m),
			scissor = bool(entry.get("scissor", false)),
			ink_only = bool(entry.get("ink_only", false)),
			ground = bool(entry.get("ground", false)),
		})
	var ground: Dictionary = layout.ground
	return JSON.stringify({sheet_px = int(sheet_px), row_px = int(row_px), tile_m = float(layout.tile_m),
			ground = {px = int(ground.px), tile_m = float(ground.tile_m)}, strips = rows}, "\t", true)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text + "\n")
	file.close()


func _check(sheet: Image, table: String, ground: Image) -> bool:
	var ok := true
	var ground_on_disk := Image.load_from_file(ProjectSettings.globalize_path(GROUND))
	if ground_on_disk == null:
		printerr("gen_trim --check: %s is missing" % GROUND)
		ok = false
	else:
		ground_on_disk.convert(Image.FORMAT_RGBA8)
		if ground_on_disk.get_data() != ground.get_data():
			printerr("gen_trim --check: %s differs from a repaint of the layout" % GROUND)
			ok = false
	var committed := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if committed == null:
		printerr("gen_trim --check: %s is missing" % SHEET)
		ok = false
	else:
		committed.convert(Image.FORMAT_RGBA8)
		if committed.get_data() != sheet.get_data():
			printerr("gen_trim --check: %s differs from a repaint of the layout" % SHEET)
			ok = false
	if FileAccess.get_file_as_string(STRIPS) != table + "\n":
		printerr("gen_trim --check: %s differs from the layout" % STRIPS)
		ok = false
	if ok:
		print("gen_trim --check: the sheet and the strip table match the layout")
	return ok


# --- Painting ---------------------------------------------------------------------------------


func _paint(layout: Dictionary) -> Image:
	_w = int(layout.sheet_px)
	_h = int(layout.row_px)
	_img = Image.create(_w, int(layout.sheet_px), false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	_px_per_m_u = float(_w) / float(layout.tile_m)
	for entry: Dictionary in layout.strips:
		_y0 = int(entry.row) * _h
		_seed = int(entry.row) * 7919 + 17
		_px_per_m_v = float(_h) / float(entry.period_m)
		_hsv = entry.hsv
		var name: String = entry.name
		call("_strip_" + name)
	return _img


func _hsv_color(key: String, dv: float = 0.0, ds: float = 0.0) -> Color:
	var v: Array = _hsv[key]
	return _band(float(v[0]), float(v[1]) + ds, float(v[2]) + dv)


## A colour clamped into the environment band.
func _band(h: float, s: float, v: float) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), clampf(s, 0.0, SAT_MAX), clampf(v, VAL_MIN, VAL_MAX))


func _put(x: int, y: int, color: Color) -> void:
	_img.set_pixel(posmod(x, _w), _y0 + posmod(y, _h), Color(color.r, color.g, color.b, 0.0))


func _ink_px(x: int, y: int) -> void:
	_img.set_pixel(posmod(x, _w), _y0 + posmod(y, _h), Color(INK.r, INK.g, INK.b, 1.0))


func _fill(color: Color) -> void:
	for y in _h:
		for x in _w:
			_put(x, y, color)


func _rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(xx, yy, color)


## An ink rectangle, kept off the strip's top and bottom edges (no ink on a face's border).
func _ink_rect(x: int, y: int, w: int, h: int) -> void:
	for yy in range(maxi(y, 6), mini(y + h, _h - 6)):
		for xx in range(maxi(x, 6), x + w):
			_ink_px(xx, yy)


func _hash(ix: int, iy: int, salt: int) -> float:
	var n: int = (ix * 374761393 + iy * 668265263 + (salt + _seed) * 1274126177) & 0xffffffff
	n = ((n ^ (n >> 13)) * 1103515245) & 0xffffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


## Tileable value noise at `cell` px (a divisor of the sheet's width and height), 0-1.
func _noise(x: int, y: int, cell: int, salt: int) -> float:
	var cols := _w / cell
	var rows := maxi(_h / cell, 1)
	var gx := float(x) / float(cell)
	var gy := float(y) / float(cell)
	var x0 := floori(gx)
	var y0 := floori(gy)
	var fx := gx - float(x0)
	var fy := gy - float(y0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(posmod(x0, cols), posmod(y0, rows), salt)
	var b := _hash(posmod(x0 + 1, cols), posmod(y0, rows), salt)
	var c := _hash(posmod(x0, cols), posmod(y0 + 1, rows), salt)
	var d := _hash(posmod(x0 + 1, cols), posmod(y0 + 1, rows), salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## A flat colour with blotches (`blotch` of a second colour, in `cell` px) and a fine grain.
func _mottled(base: Color, stain: Color, cell: int, blotch: float, grain: float) -> void:
	for y in _h:
		for x in _w:
			var n := _noise(x, y, cell, 1)
			var color := base.lerp(stain, clampf((n - 0.35) * 2.0, 0.0, 1.0) * blotch)
			var g := (_hash(x, y, 9) - 0.5) * grain
			_put(x, y, _band(color.h, color.s, color.v + g))


## Flat tones: `base`, and `alt` wherever the tileable noise at `cell` px passes `threshold` (a divisor of the strip's height or
## its multiple), with no grain, so the mips and the cut have nothing one texel wide to alias.
func _flat_tones(base: Color, alt: Color, cell: int, threshold: float) -> void:
	for y in _h:
		for x in _w:
			_put(x, y, alt if _noise(x, y, cell, 1) > threshold else base)


## An ink disc (kept off the strip's top and bottom edges and U = 0, like _ink_rect).
func _ink_disc(cx: float, cy: float, radius: float) -> void:
	for yy in range(int(floor(cy - radius)), int(ceil(cy + radius)) + 1):
		for xx in range(int(floor(cx - radius)), int(ceil(cx + radius)) + 1):
			if yy < 6 or yy >= _h - 6 or posmod(xx, _w) < 6:
				continue
			if Vector2(float(xx) - cx, float(yy) - cy).length() <= radius:
				_ink_px(xx, yy)


## A wandering ink crack along the strip from (x, y), `length` px, `radius` px at the start tapering to MIN_INK_PX / 2.
func _strip_crack(x: int, y: int, length: int, radius: float) -> void:
	var fx := float(x)
	var fy := float(y)
	var tip := float(MIN_INK_PX) * 0.5 + 0.8
	for step in length / 3:
		var t := float(step) / float(length / 3)
		_ink_disc(fx, fy, lerpf(radius, tip, t))
		fx += 3.0
		fy = clampf(fy + (_hash(x + step, y, 33) - 0.5) * 3.2, 16.0, float(_h) - 16.0)


func _strip_brick() -> void:
	_fill(_hsv_color("mortar"))
	var course_h := _h / 2
	var brick_w := int(_px_per_m_u * 0.5)
	var mortar_x := int(_px_per_m_u * 0.03)
	var mortar_y := maxi(int(_px_per_m_v * 0.025), 2)
	for course in 2:
		var shift := (brick_w / 2) * (course % 2)
		for n in _w / brick_w:
			var jitter := _hash(n, course, 3)
			var color := _hsv_color("brick").lerp(_hsv_color("brick_alt"), jitter)
			var x0 := n * brick_w + shift
			for y in range(course * course_h + mortar_y, (course + 1) * course_h - 0):
				for x in range(x0 + mortar_x, x0 + brick_w):
					var grain := (_hash(x, y, 4) - 0.5) * 0.04
					# A paler top edge: the brick's face catches the light.
					var lift := 0.03 if y - course * course_h < mortar_y + 5 else 0.0
					_put(x, y, _band(color.h, color.s, color.v + grain + lift))


func _strip_plaster() -> void:
	_mottled(_hsv_color("base"), _hsv_color("stain"), 64, 0.6, 0.03)
	# A few hairline cracks in ink, away from the strip's edges.
	for crack in 5:
		var x := int(_hash(crack, 1, 20) * float(_w))
		var y := 24 + int(_hash(crack, 2, 20) * 60.0)
		for step in 30:
			x += 2 + int(_hash(crack, step, 21) * 4.0)
			y += int(_hash(crack, step, 22) * 5.0) - 2
			y = clampi(y, 12, _h - 12)
			_ink_px(x, y)
			_ink_px(x, y + 1)


func _strip_concrete() -> void:
	# Flat tones (a worn patch or two), then bold ink: panel joints (a vertical one every metre, half a panel off U = 0, and a
	# horizontal one mid-strip), tie holes on a grid, and a tapered hairline crack. Nothing under MIN_INK_PX wide.
	_flat_tones(_hsv_color("base"), _hsv_color("stain"), 128, 0.62)
	var metre := int(_px_per_m_u)
	for n in _w / metre:
		_ink_rect(n * metre + metre / 2 - 6, 0, 12, _h)
	_ink_rect(0, _h / 2 - 3, _w, 6)
	for n in _w / (metre / 2):
		for row in [_h / 4, _h * 3 / 4]:
			var x := n * (metre / 2) + metre / 4
			_ink_rect(x - 6, row - 4, 12, 8)
	_strip_crack(int(_px_per_m_u * 0.7), 40, 420, 3.4)
	_strip_crack(int(_px_per_m_u * 2.6), 98, 380, 3.2)


func _strip_asphalt() -> void:
	# The strip's own paint, the fallback when the ground tile is off (Debug `ground_sheet_off`): flat tones and bold cracks.
	_flat_tones(_hsv_color("base"), _hsv_color("grain"), 128, 0.58)
	_strip_crack(int(_hash(1, 5, 30) * float(_w)), 40, 460, 3.6)
	_strip_crack(int(_hash(2, 5, 30) * float(_w)), 84, 400, 3.4)
	_strip_crack(int(_hash(3, 5, 30) * float(_w)), 62, 340, 3.2)


func _strip_kerb() -> void:
	var base := _hsv_color("base")
	_flat_tones(base, _hsv_color("base", -0.04), 128, 0.6)
	for y in 22:
		for x in _w:
			_put(x, y, _hsv_color("top"))
	for y in range(_h - 20, _h):
		for x in _w:
			_put(x, y, _hsv_color("bottom"))
	var joint := int(_px_per_m_u)
	for n in _w / joint:
		_ink_rect(n * joint + joint / 2 - 5, 22, 10, _h - 44)


func _strip_roof_tar() -> void:
	_flat_tones(_hsv_color("base"), _hsv_color("patch"), 128, 0.6)
	var roll := int(_px_per_m_u)
	for n in _w / roll:
		var x0 := n * roll + roll / 2
		# The lap of one roll over the next: a pale lip beside a bold ink seam.
		_rect(x0 + 6, 0, 12, _h, _hsv_color("lap"))
		_ink_rect(x0 - 5, 0, 10, _h)


func _strip_gravel() -> void:
	_fill(_hsv_color("base"))
	for y in _h:
		for x in _w:
			var n := _noise(x, y, 8, 50)
			var color := _hsv_color("base")
			if n > 0.62:
				color = _hsv_color("light", (n - 0.62) * 0.2)
			elif n < 0.34:
				color = _hsv_color("dark")
			_put(x, y, _band(color.h, color.s, color.v + (_hash(x, y, 51) - 0.5) * 0.05))


func _strip_metal() -> void:
	var rib := 32
	for y in _h:
		var wave := sin(float(y) / float(rib) * TAU)
		for x in _w:
			var color := _hsv_color("base").lerp(_hsv_color("light") if wave > 0.0 else _hsv_color("dark"), absf(wave) * 0.7)
			_put(x, y, _band(color.h, color.s, color.v + (_hash(x, y, 60) - 0.5) * 0.02))
	# A panel seam across the middle with a row of rivets.
	_ink_rect(0, _h / 2 - 1, _w, 3)
	var pitch := int(_px_per_m_u * 0.25)
	for n in _w / pitch:
		var cx := n * pitch + pitch / 2
		_rect(cx - 3, _h / 2 - 12, 6, 6, _hsv_color("rivet"))
		_rect(cx - 3, _h / 2 + 8, 6, 6, _hsv_color("rivet"))


func _strip_shutter() -> void:
	# One slat per period: bright at the top, shaded to the bottom, an ink groove below it.
	for y in _h:
		var t := float(y) / float(_h)
		var color := _hsv_color("top").lerp(_hsv_color("bottom"), t)
		for x in _w:
			_put(x, y, _band(color.h, color.s, color.v + (_hash(x / 4, y, 70) - 0.5) * 0.02))
	_ink_rect(0, _h - 12, _w, 4)
	# The slats' joins show as a lighter fleck every half metre.
	for n in _w / int(_px_per_m_u * 0.5):
		_rect(n * int(_px_per_m_u * 0.5) + 40, 20, 8, 20, _hsv_color("top", 0.05))


func _strip_chainlink() -> void:
	var wire := _hsv_color("wire")
	for y in _h:
		for x in _w:
			_img.set_pixel(x, _y0 + y, Color(wire.r, wire.g, wire.b, 0.0))
	# Diamonds 0.5 m wide and one period (0.25 m) high: two diagonals through each cell, 12 px thick.
	var pitch := _w / int(float(_w) / (_px_per_m_u * 0.5))
	var thick := 7.0
	for y in _h:
		for x in _w:
			var u := posmod(x, pitch)
			var d1 := absf(float(y) - float(_h) * float(u) / float(pitch))
			var d2 := absf(float(y) - float(_h) * (1.0 - float(u) / float(pitch)))
			var d := minf(minf(d1, d2), minf(absf(d1 - float(_h)), absf(d2 - float(_h))))
			if d < thick * 0.5:
				_img.set_pixel(x, _y0 + y, Color(wire.r, wire.g, wire.b, 1.0))


func _strip_crate() -> void:
	var plank_h := _h / 2
	for plank in 2:
		var color := _hsv_color("plank").lerp(_hsv_color("plank_alt"), _hash(plank, 0, 80))
		for y in range(plank * plank_h, (plank + 1) * plank_h):
			for x in _w:
				# The grain runs along the plank: noise stretched in x.
				var grain := _noise(x, y, 16, 81) * 0.06 + _noise(x, y * 4, 32, 82) * 0.03
				_put(x, y, _band(color.h, color.s, color.v + grain - 0.045))
		# The gap under each plank: a darker band (no ink on the strip's edge); ink between the two.
		_rect(0, plank * plank_h + plank_h - 6, _w, 6, _hsv_color("gap"))
	_ink_rect(0, plank_h - 3, _w, 3)
	# A nail at each end of a plank every metre.
	var metre := int(_px_per_m_u)
	for n in _w / metre:
		for plank in 2:
			_rect(n * metre + 24, plank * plank_h + 20, 5, 5, _hsv_color("gap"))
			_rect(n * metre + metre - 30, plank * plank_h + 20, 5, 5, _hsv_color("gap"))


func _strip_trim() -> void:
	# A moulding: a light band on top, a mid face, a dark groove with an ink line under it.
	for y in _h:
		var color: Color
		if y < 32:
			color = _hsv_color("light")
		elif y < 100:
			color = _hsv_color("mid")
		else:
			color = _hsv_color("groove")
		for x in _w:
			_put(x, y, _band(color.h, color.s, color.v + (_hash(x / 2, y, 90) - 0.5) * 0.015))
	_ink_rect(0, 98, _w, 3)


func _strip_ink() -> void:
	for y in _h:
		for x in _w:
			_img.set_pixel(x, _y0 + y, Color(INK.r, INK.g, INK.b, 1.0))


func _strip_glass() -> void:
	for y in _h:
		for x in _w:
			# Diagonal sheen bands every half metre.
			var diag := fposmod(float(x) * 0.5 + float(y) * 1.2, 256.0)
			var sheen := 1.0 if diag < 36.0 else (0.5 if diag > 60.0 and diag < 76.0 else 0.0)
			var color := _hsv_color("base").lerp(_hsv_color("sheen"), sheen)
			_put(x, y, _band(color.h, color.s, color.v + (_hash(x / 4, y / 4, 100) - 0.5) * 0.02))


func _strip_dark() -> void:
	_mottled(_hsv_color("base"), _hsv_color("blotch"), 64, 0.8, 0.015)


func _strip_facade() -> void:
	# One storey (3.2 m): a wall with two windows a tile (2 m pitch), sill below, ink frame round the pane.
	var pitch := int(_px_per_m_u * 2.0)
	for y in _h:
		for x in _w:
			var n := _hash(x / 64, y / 8, 110)
			var color := _hsv_color("wall").lerp(_hsv_color("wall_alt"), n * 0.7)
			_put(x, y, _band(color.h, color.s, color.v + (_hash(x, y, 111) - 0.5) * 0.02))
	for n in _w / pitch:
		var x0 := n * pitch + pitch / 2 - int(_px_per_m_u * 0.55)
		var width := int(_px_per_m_u * 1.1)
		var y0 := 30
		var height := 62
		_ink_rect(x0 - 5, y0 - 5, width + 10, height + 10)
		_rect(x0, y0, width, height, _hsv_color("pane"))
		_rect(x0 - 10, y0 + height + 5, width + 20, 8, _hsv_color("sill"))
		_ink_rect(x0 + width / 2 - 2, y0, 4, height)


# --- The ground tile ---------------------------------------------------------------------------


## The ink layer of the ground tile (a coverage 0-1 a pixel, 0.5 at a feature's true edge), stamped by the helpers below.
var _ink: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


## The ground tile: flat tones (base, worn patches cool and warm, dark patches, tar-sealed seams, oil stains, patched
## squares) under bold ink (branching tapered cracks, the squares' outlines, a manhole, drain grates). Tileable both ways.
func _paint_ground(spec: Dictionary) -> Image:
	var size := int(spec.px)
	_w = size
	_h = size
	_seed = 90001
	_rng.seed = 424242
	var tone := {}
	for key: String in spec.hsv:
		var v: Array = spec.hsv[key]
		tone[key] = _band(float(v[0]), float(v[1]), float(v[2]))
	var count := size * size
	_ink = PackedFloat32Array()
	_ink.resize(count)
	var warp_x := PackedFloat32Array()
	var warp_y := PackedFloat32Array()
	warp_x.resize(count)
	warp_y.resize(count)
	var colors: Array[Color] = []
	colors.resize(count)
	for y in size:
		for x in size:
			var idx := y * size + x
			var wx := float(x) + (_noise(x, y, 128, 210) - 0.5) * 36.0
			var wy := float(y) + (_noise(x, y, 128, 211) - 0.5) * 36.0
			warp_x[idx] = wx
			warp_y[idx] = wy
			var p := posmod(int(wx), size)
			var q := posmod(int(wy), size)
			var color: Color = tone.base
			var worn := _noise(p, q, 256, 202)
			if worn > 0.63:
				# A worn patch is a cool rim round a warm core (the lamp's pool): two flat bands, not a split.
				color = tone.worn_warm if worn > 0.69 else tone.worn
			elif worn < 0.25:
				color = tone.dark
			# A tar-sealed repair: a wavy seam, wider and narrower along its length, only where the gate lets it.
			var seam := absf(_noise(p, q, 256, 203) - 0.5)
			if seam < 0.032 * (0.35 + _noise(x, y, 128, 207)) and _noise(x, y, 512, 206) > 0.42:
				color = tone.tar
			# An oil stain: a dark flat blot.
			if _noise(p, q, 128, 204) > 0.80 and _noise(x, y, 1024, 208) > 0.40:
				color = tone.oil
			colors[idx] = color
	# Patched squares: a flat tone and an inked outline, the edges wobbled by the warp.
	for rect: Array in [[420, 520, 150, 100], [1500, 1180, 190, 120], [900, 1700, 130, 170]]:
		_ground_rect(colors, warp_x, warp_y, tone.patch, int(rect[0]), int(rect[1]), float(rect[2]), float(rect[3]), 4.5)
	# The manhole: a ring, an inner ring, a bar grate.
	_ground_manhole(colors, tone.cover, 1500, 560)
	# Drain grates (a frame and bars), one lying one way and one the other.
	_ground_grate(colors, tone.cover, 250, 1450, 85, 50, false)
	_ground_grate(colors, tone.cover, 1760, 1830, 48, 80, true)
	# Branching cracks, tapered: a fat root, a thin tip, never under MIN_INK_PX wide.
	for crack in [[120, 220, 0.25, 170, 7.5], [980, 140, -0.35, 150, 7.0], [1650, 300, 0.55, 140, 6.5], [300, 980, -0.15, 160, 7.0],
			[1250, 900, 2.6, 130, 6.5], [1800, 1520, 3.5, 150, 7.0], [700, 1300, -0.6, 110, 6.0], [1950, 800, 1.9, 120, 6.0]]:
		_crack(float(crack[0]), float(crack[1]), float(crack[2]), int(crack[3]), float(crack[4]), 0)
	var bytes := PackedByteArray()
	bytes.resize(count * 4)
	for idx in count:
		var color := colors[idx]
		var a := _ink[idx]
		if a >= 0.5:
			color = INK
		bytes[idx * 4] = int(round(color.r * 255.0))
		bytes[idx * 4 + 1] = int(round(color.g * 255.0))
		bytes[idx * 4 + 2] = int(round(color.b * 255.0))
		bytes[idx * 4 + 3] = int(round(a * 255.0))
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)


## Coverage of a feature `distance` px from its centre line (or edge) when it is `half` px from that line to its edge:
## 0.5 at the edge, a one-pixel ramp each side (crisp at any magnification once the shader cuts at 0.5).
func _coverage(half: float, distance: float) -> float:
	return clampf(0.5 + half - distance, 0.0, 1.0)


func _ink_at(x: int, y: int, coverage: float) -> void:
	if coverage <= 0.0:
		return
	var idx := posmod(y, _w) * _w + posmod(x, _w)
	if coverage > _ink[idx]:
		_ink[idx] = coverage


## A disc of ink (a crack's step).
func _stamp(cx: float, cy: float, radius: float) -> void:
	for yy in range(int(floor(cy - radius - 1.0)), int(ceil(cy + radius + 1.0)) + 1):
		for xx in range(int(floor(cx - radius - 1.0)), int(ceil(cx + radius + 1.0)) + 1):
			_ink_at(xx, yy, _coverage(radius, Vector2(float(xx) + 0.5 - cx, float(yy) + 0.5 - cy).length()))


## A crack from (x, y) heading `angle`, `steps` steps of 3 px, half-width `half0` tapering to MIN_INK_PX / 2 + 0.2; it
## forks now and then (twice deep at most), the fork thinner and shorter.
func _crack(x: float, y: float, angle: float, steps: int, half0: float, depth: int) -> void:
	var half_min := float(MIN_INK_PX) * 0.5 + 0.2
	for i in steps:
		var t := float(i) / float(steps)
		_stamp(x, y, lerpf(half0, half_min, pow(t, 0.8)))
		angle += (_rng.randf() - 0.5) * 0.42
		x += cos(angle) * 3.0
		y += sin(angle) * 3.0
		if depth < 2 and i > 10 and i < steps - 20 and _rng.randf() < 0.028:
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			_crack(x, y, angle + side * (0.5 + _rng.randf() * 0.6), int(float(steps - i) * 0.55), maxf(half0 * 0.62, half_min + 0.4), depth + 1)


## A patched square at (cx, cy), `hw` and `hh` px half-size: its inside takes `tone`, its outline `half` px half-width ink.
func _ground_rect(colors: Array[Color], warp_x: PackedFloat32Array, warp_y: PackedFloat32Array, tone: Color, cx: int, cy: int, hw: float, hh: float, half: float) -> void:
	var size := _w
	var half_size := float(size) * 0.5
	for yy in range(cy - int(hh) - 16, cy + int(hh) + 17):
		for xx in range(cx - int(hw) - 16, cx + int(hw) + 17):
			var idx := posmod(yy, size) * size + posmod(xx, size)
			var dx := absf(fposmod(warp_x[idx] - float(cx) + half_size, float(size)) - half_size)
			var dy := absf(fposmod(warp_y[idx] - float(cy) + half_size, float(size)) - half_size)
			var edge := maxf(dx - hw, dy - hh)
			if edge < 0.0:
				colors[idx] = tone
			_ink_at(xx, yy, _coverage(half, absf(edge)))


func _ground_manhole(colors: Array[Color], tone: Color, cx: int, cy: int) -> void:
	for yy in range(cy - 100, cy + 101):
		for xx in range(cx - 100, cx + 101):
			var dx := float(xx - cx)
			var dy := float(yy - cy)
			var d := sqrt(dx * dx + dy * dy)
			var idx := posmod(yy, _w) * _w + posmod(xx, _w)
			if d < 90.0:
				colors[idx] = tone
			_ink_at(xx, yy, _coverage(5.5, absf(d - 90.0)))
			_ink_at(xx, yy, _coverage(3.5, absf(d - 66.0)))
			if d < 62.0:
				# Horizontal bars every 24 px and one upright bar through the middle.
				_ink_at(xx, yy, _coverage(3.5, absf(fposmod(dy + 12.0, 24.0) - 12.0)))
				_ink_at(xx, yy, _coverage(3.5, absf(dx)))


## A drain grate at (cx, cy), `hw` x `hh` px half-size: a frame and bars (across the long side).
func _ground_grate(colors: Array[Color], tone: Color, cx: int, cy: int, hw: int, hh: int, vertical: bool) -> void:
	for yy in range(cy - hh - 10, cy + hh + 11):
		for xx in range(cx - hw - 10, cx + hw + 11):
			var dx := absf(float(xx - cx))
			var dy := absf(float(yy - cy))
			var edge := maxf(dx - float(hw), dy - float(hh))
			var idx := posmod(yy, _w) * _w + posmod(xx, _w)
			if edge < 0.0:
				colors[idx] = tone
			_ink_at(xx, yy, _coverage(4.0, absf(edge)))
			if edge < -7.0:
				var along := float(yy - cy) if vertical else float(xx - cx)
				_ink_at(xx, yy, _coverage(3.5, absf(fposmod(along + 11.0, 22.0) - 11.0)))


## A minimal .import for the sheet: lossless, mipmaps, the alpha untouched (it is the ink mask and the
## wire's coverage, so no alpha-border fix), never VRAM-compressed. The next `godot --import` completes it.
func _patch_import(png: String) -> void:
	var path := png + ".import"
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
		text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
		text = text.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
		text = text.replace("compress/mode=2", "compress/mode=0")
		text = text.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false")
	else:
		text = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
			+ "compress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=false\ndetect_3d/compress_to=0\n")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
