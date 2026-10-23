extends SceneTree
## Draws the comic effect set (Spec §6 "Comic effects", §10 "2D effects"; Milestone 2 WP2)
## as SVG into assets/source/fx/, then rasterizes every SVG there to a PNG in
## assets/export/fx/ (512 px on the long side, transparent background). Run it from the
## project folder:
##   godot --headless -s tools/gen_fx.gd                    # draw the SVGs, then rasterize
##   godot --headless -s tools/gen_fx.gd -- --raster-only   # rasterize (hand-edited) SVGs only
##   godot --headless --import --quit                       # then import the PNGs
## Each PNG imports lossless with mipmaps (see _import_settings()).
## Every shape is drawn from a seeded random generator, so a redraw is identical. The
## lettering uses an original block alphabet defined below (no font outlines), since
## Godot's SVG rasterizer has no text support and the art must be original (Spec §1).
## Colors: ink and paper from HudStyle; red only for blood, the rear-warning burst and
## finisher accents (Spec §10).

const SOURCE_DIR := "res://assets/source/fx"
const EXPORT_DIR := "res://assets/export/fx"
## Long side of every PNG, in pixels.
const RASTER_PX := 512.0

const INK := "#120f17"
const PAPER := "#f7f0d9"
const WHITE := "#ffffff"
const PALE_YELLOW := "#fff6b8"
const YELLOW := "#ffd21f"
const ORANGE := "#ff9a1f"
const AMBER := "#ffb030"
## Finisher accent red (the large burst, finisher lettering's extrusion).
const ACCENT_RED := "#e8302a"
const BLOOD := "#d0141f"
const BLOOD_DARK := "#62070e"
const BLOOD_LIGHT := "#ff5a5f"
const PARRY_CYAN := "#59ebff"
const WARNING_RED := "#ff4a2e"
const SPIT := "#dff6ff"
const BRUISE := "#4a2466"
const BRUISE_BLUE := "#2e3a78"
const BRUISE_OLD := "#8c8f2e"
## A bruise's dark middle and outline, and the purple-gray wash over bruised skin.
const BRUISE_DARK := "#1e0f2e"
const BRUISE_WASH := "#5c3d6e"
## Dirt on scuffed clothes: the wash and the smudges.
const DIRT := "#2a2018"
const DIRT_DARK := "#16110d"

## The comic lettering set: word -> style. "finisher" words get the red extrusion accent.
const WORDS := {
	"POW!": "punch", "BAM!": "punch", "SMAK!": "punch", "WHAM!": "punch",
	"THUD": "punch", "BOFF!": "punch", "KRAK!": "finisher", "CRUNCH!": "finisher",
	"WHUMP!": "finisher", "KAPOW!": "finisher",
}

## Block letters on a 100-unit cap height, y down. Each glyph is a list of closed
## contours; contours after the first are counters (holes, drawn even-odd).
const GLYPHS := {
	"A": [[0, 100, 30, 0, 58, 0, 88, 100, 64, 100, 58, 80, 30, 80, 24, 100], [36, 60, 52, 60, 44, 28]],
	"B": [[0, 0, 54, 0, 72, 12, 72, 38, 62, 47, 76, 58, 76, 88, 62, 100, 0, 100],
		[22, 18, 46, 18, 50, 22, 50, 35, 46, 39, 22, 39], [22, 58, 48, 58, 53, 63, 53, 77, 48, 82, 22, 82]],
	"C": [[14, 0, 78, 0, 78, 24, 24, 24, 24, 76, 78, 76, 78, 100, 14, 100, 0, 86, 0, 14]],
	"D": [[0, 0, 56, 0, 80, 22, 80, 78, 56, 100, 0, 100],
		[22, 22, 46, 22, 57, 33, 57, 67, 46, 78, 22, 78]],
	"F": [[0, 0, 70, 0, 70, 23, 22, 23, 22, 40, 60, 40, 60, 62, 22, 62, 22, 100, 0, 100]],
	"H": [[0, 0, 23, 0, 23, 39, 57, 39, 57, 0, 80, 0, 80, 100, 57, 100, 57, 61, 23, 61, 23, 100, 0, 100]],
	"K": [[0, 0, 23, 0, 23, 40, 52, 0, 82, 0, 46, 50, 84, 100, 54, 100, 23, 60, 23, 100, 0, 100]],
	"M": [[0, 100, 0, 0, 26, 0, 51, 42, 76, 0, 102, 0, 102, 100, 79, 100, 79, 44, 51, 86, 23, 44, 23, 100]],
	"N": [[0, 100, 0, 0, 24, 0, 61, 58, 61, 0, 84, 0, 84, 100, 60, 100, 23, 42, 23, 100]],
	"O": [[16, 0, 70, 0, 86, 16, 86, 84, 70, 100, 16, 100, 0, 84, 0, 16],
		[28, 23, 58, 23, 63, 28, 63, 72, 58, 77, 28, 77, 23, 72, 23, 28]],
	"P": [[0, 0, 58, 0, 76, 17, 76, 50, 58, 66, 23, 66, 23, 100, 0, 100],
		[23, 20, 48, 20, 53, 25, 53, 41, 48, 46, 23, 46]],
	"R": [[0, 0, 58, 0, 76, 17, 76, 46, 63, 57, 82, 100, 55, 100, 39, 64, 23, 64, 23, 100, 0, 100],
		[23, 20, 48, 20, 53, 25, 53, 39, 48, 44, 23, 44]],
	"S": [[14, 0, 76, 0, 76, 23, 24, 23, 24, 38, 62, 38, 76, 52, 76, 86, 62, 100, 0, 100, 0, 77,
		52, 77, 52, 62, 14, 62, 0, 48, 0, 14]],
	"T": [[0, 0, 80, 0, 80, 24, 51, 24, 51, 100, 29, 100, 29, 24, 0, 24]],
	"U": [[0, 0, 23, 0, 23, 77, 57, 77, 57, 0, 80, 0, 80, 84, 64, 100, 16, 100, 0, 84]],
	"W": [[0, 0, 23, 0, 31, 56, 44, 0, 66, 0, 79, 56, 87, 0, 110, 0, 94, 100, 69, 100, 55, 46, 41, 100, 16, 100]],
	"!": [[2, 0, 28, 0, 22, 68, 8, 68], [6, 77, 25, 77, 25, 100, 6, 100]],
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	var raster_only := OS.get_cmdline_user_args().has("--raster-only")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	if not raster_only:
		_draw_all()
	var count := _rasterize_all()
	print("gen_fx: %d PNGs in %s" % [count, EXPORT_DIR])
	quit()


# --- Drawing ---------------------------------------------------------------------------


func _draw_all() -> void:
	for word: String in WORDS:
		_save("word_" + _file_word(word), _lettering(word, WORDS[word] == "finisher"))
	_save("burst_small", _burst_small())
	_save("burst_medium", _burst_medium())
	_save("burst_large", _burst_large())
	_save("speed_lines", _speed_lines())
	_save("blood_drop", _blood_drop())
	for i in 3:
		_save("blood_splat_%d" % (i + 1), _blood_splat(i))
	_save("blood_spray", _blood_spray())
	_save("spit", _spit())
	_save("tooth", _tooth())
	_save("block_spark", _block_spark())
	_save("parry_spark", _parry_spark())
	_save("guard_break", _guard_break())
	_save("rear_warning", _rear_warning())
	_save("damage_bruised", _damage_tile(true, false))
	_save("damage_scuffed", _damage_tile(false, false))
	_save("damage_bloodied", _damage_tile(true, true))
	_save("damage_blood", _damage_tile(false, true))


## "KRAK!" -> "krak"
static func _file_word(word: String) -> String:
	return word.replace("!", "").to_lower()


func _save(name: String, svg: String) -> void:
	var path := ProjectSettings.globalize_path(SOURCE_DIR.path_join(name + ".svg"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(svg)
	file.close()


## SVG document of `size` pixels showing `view` (user units), with `defs` and `body`.
static func _doc(view: Rect2, defs: String, body: String, note: String) -> String:
	var scale := RASTER_PX / maxf(view.size.x, view.size.y)
	var w := roundi(view.size.x * scale)
	var h := roundi(view.size.y * scale)
	return (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">\n' % [
			w, h, _n(view.position.x), _n(view.position.y), _n(view.size.x), _n(view.size.y)]
		+ "<!-- %s Drawn by tools/gen_fx.gd (original art, Beat-em-up PoC). -->\n" % note
		+ ("<defs>\n%s</defs>\n" % defs if defs != "" else "")
		+ body
		+ "</svg>\n"
	)


static func _n(v: float) -> String:
	return String.num(v, 1)


static func _pts(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for i in points.size():
		parts.append(("M" if i == 0 else "L") + _n(points[i].x) + " " + _n(points[i].y))
	return " ".join(parts) + " Z"


static func _path(d: String, fill: String, stroke: String = "", width: float = 0.0, extra: String = "") -> String:
	var s := '<path d="%s" fill="%s"' % [d, fill]
	if stroke != "":
		s += ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % [stroke, _n(width)]
	return s + extra + "/>\n"


static func _linear(id: String, top: String, bottom: String, y1: float = 0.0, y2: float = 1.0,
		user_space: bool = false) -> String:
	var units := ' gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="%s" y2="%s"' % [_n(y1), _n(y2)] if user_space \
		else ' x1="0" y1="0" x2="0" y2="1"'
	return '<linearGradient id="%s"%s><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>\n' % [
		id, units, top, bottom]


static func _radial(id: String, inner: String, outer: String, inner_opacity: float = 1.0,
		outer_opacity: float = 1.0) -> String:
	return ('<radialGradient id="%s" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="%s" stop-opacity="%s"/>'
		+ '<stop offset="1" stop-color="%s" stop-opacity="%s"/></radialGradient>\n') % [
		id, inner, _n(inner_opacity), outer, _n(outer_opacity)]


## A jagged comic star: `spikes` points between radius ranges `outer` and `inner`.
func _star(c: Vector2, spikes: int, outer: Vector2, inner: Vector2, rot: float = 0.0,
		angle_jitter: float = 0.22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := TAU / spikes
	for i in spikes:
		var a0 := rot + step * i + _rng.randf_range(-angle_jitter, angle_jitter) * step
		pts.append(c + Vector2.from_angle(a0) * _rng.randf_range(outer.x, outer.y))
		var a1 := rot + step * (i + 0.5) + _rng.randf_range(-angle_jitter, angle_jitter) * step * 0.5
		pts.append(c + Vector2.from_angle(a1) * _rng.randf_range(inner.x, inner.y))
	return pts


## A smooth irregular blob around `c` (quadratic curves through the midpoints).
func _blob(c: Vector2, radius: float, lobes: int, jitter: float) -> String:
	var pts := PackedVector2Array()
	for i in lobes:
		var a := TAU * i / lobes + _rng.randf_range(-0.2, 0.2) * TAU / lobes
		pts.append(c + Vector2.from_angle(a) * radius * _rng.randf_range(1.0 - jitter, 1.0 + jitter))
	var d := "M%s %s" % [_n((pts[0].x + pts[1].x) * 0.5), _n((pts[0].y + pts[1].y) * 0.5)]
	for i in lobes:
		var p := pts[(i + 1) % lobes]
		var next := pts[(i + 2) % lobes]
		d += " Q%s %s %s %s" % [_n(p.x), _n(p.y), _n((p.x + next.x) * 0.5), _n((p.y + next.y) * 0.5)]
	return d + " Z"


## A teardrop: round head of radius `r` at `head`, tail tip `length` away at `angle`
## (radians, 0 = +x).
static func _teardrop(head: Vector2, r: float, length: float, angle: float) -> String:
	var dir := Vector2.from_angle(angle)
	var side := Vector2(-dir.y, dir.x)
	var tip := head + dir * length
	var c1a := head + dir * (length * 0.45) + side * (r * 0.25)
	var c1b := head + dir * (r * 0.9) + side * r
	var right := head + side * r
	var left := head - side * r
	var c2a := head + dir * (r * 0.9) - side * r
	var c2b := head + dir * (length * 0.45) - side * (r * 0.25)
	return "M%s %s C%s %s %s %s %s %s A%s %s 0 1 1 %s %s C%s %s %s %s %s %s Z" % [
		_n(tip.x), _n(tip.y), _n(c1a.x), _n(c1a.y), _n(c1b.x), _n(c1b.y), _n(right.x), _n(right.y),
		_n(r), _n(r), _n(left.x), _n(left.y),
		_n(c2a.x), _n(c2a.y), _n(c2b.x), _n(c2b.y), _n(tip.x), _n(tip.y)]


static func _circle(c: Vector2, r: float, fill: String, stroke: String = "", width: float = 0.0,
		extra: String = "") -> String:
	var s := '<circle cx="%s" cy="%s" r="%s" fill="%s"' % [_n(c.x), _n(c.y), _n(r), fill]
	if stroke != "":
		s += ' stroke="%s" stroke-width="%s"' % [stroke, _n(width)]
	return s + extra + "/>\n"


# --- Lettering -------------------------------------------------------------------------


## One word in the block alphabet: each letter leaned, tilted, sized and bobbed a little,
## overlapping its neighbor. Ink outline drawn under every letter first, so overlapping
## letters share one outline; a drop shadow (punch) or a red extrusion (finisher) behind.
func _lettering(word: String, finisher: bool) -> String:
	_rng.seed = hash(word)
	var outline := 11.0
	var shadow := Vector2(7.0, 9.0) if not finisher else Vector2(10.0, 12.0)
	var letters: Array[PackedStringArray] = []  # per letter: its contours as path data
	var all_points := PackedVector2Array()
	var x := 0.0
	for i in word.length():
		var ch := word[i]
		var contours: Array = GLYPHS[ch]
		var width := _glyph_width(contours)
		var s := _rng.randf_range(0.95, 1.05) * (1.12 if i == 0 else 1.0)
		var angle := deg_to_rad(_rng.randf_range(-6.0, 6.0))
		var bob := _rng.randf_range(-5.0, 5.0) - (5.0 if i == 0 else 0.0)
		var xf := Transform2D(angle, Vector2(s, s), 0.0, Vector2(x + width * s * 0.5, 50.0 + bob))
		var center := Vector2(width * 0.5, 50.0)
		var paths := PackedStringArray()
		for contour: Array in contours:
			var pts := PackedVector2Array()
			for k in range(0, contour.size(), 2):
				var p := Vector2(contour[k], contour[k + 1]) - center
				p.x += -p.y * 0.17  # lean right (italic)
				pts.append(xf * p)
			all_points.append_array(pts)
			paths.append(_pts(pts))
		letters.append(paths)
		x += width * s + 1.0
	var bounds := Rect2(all_points[0], Vector2.ZERO)
	for p in all_points:
		bounds = bounds.expand(p)
	var top := bounds.position.y
	var bottom := bounds.end.y
	var view := bounds.grow(outline * 0.5 + 4.0)
	view = view.merge(Rect2(view.position + shadow, view.size).grow(outline * 0.25))
	var defs := _linear("fill", WHITE if finisher else PALE_YELLOW, YELLOW if finisher else ORANGE, top, bottom, true)
	var body := ""
	# Shadow or extrusion.
	var steps := 6 if finisher else 1
	for step in range(steps, 0, -1):
		var offset := shadow * float(step) / steps
		for paths in letters:
			body += '<g transform="translate(%s %s)">' % [_n(offset.x), _n(offset.y)]
			body += _path(" ".join(paths), ACCENT_RED if finisher else INK, INK if step == steps else (ACCENT_RED if finisher else INK),
					outline if step == steps else outline * 0.6, ' fill-rule="evenodd"').trim_suffix("\n")
			body += "</g>\n"
	# Ink outline under every letter, then the fills.
	for paths in letters:
		body += _path(" ".join(paths), INK, INK, outline, ' fill-rule="evenodd"')
	for paths in letters:
		body += _path(" ".join(paths), "url(#fill)", "", 0.0, ' fill-rule="evenodd"')
	# A glint on the first letter.
	var glint := all_points[0].lerp(all_points[1], 0.5) + Vector2(4.0, 9.0)
	body += _path("M%s %s l14 -3 l-2 6 l-14 3 Z" % [_n(glint.x), _n(glint.y)], WHITE)
	return _doc(view, defs, body, "Comic lettering \"%s\"%s." % [word, " (finisher style)" if finisher else ""])


static func _glyph_width(contours: Array) -> float:
	var outer: Array = contours[0]
	var w := 0.0
	for k in range(0, outer.size(), 2):
		w = maxf(w, float(outer[k]))
	return w


# --- Bursts ----------------------------------------------------------------------------


func _burst_small() -> String:
	_rng.seed = 1101
	var c := Vector2(256, 256)
	var defs := _radial("core", WHITE, PALE_YELLOW)
	var body := _path(_pts(_star(c, 10, Vector2(210, 240), Vector2(95, 120))), "url(#core)", INK, 16.0)
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Impact burst, small (light hits).")


func _burst_medium() -> String:
	_rng.seed = 1202
	var c := Vector2(256, 256)
	var defs := _radial("core", WHITE, PALE_YELLOW) + _radial("mid", YELLOW, ORANGE)
	var body := _path(_pts(_star(c, 14, Vector2(195, 242), Vector2(120, 150))), "url(#mid)", INK, 15.0)
	body += _path(_pts(_star(c, 9, Vector2(120, 150), Vector2(62, 80), 0.3)), "url(#core)", INK, 9.0)
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Impact burst, medium (heavy hits).")


func _burst_large() -> String:
	_rng.seed = 1303
	var c := Vector2(256, 256)
	var defs := _radial("core", WHITE, PALE_YELLOW) + _radial("mid", YELLOW, ORANGE)
	var body := ""
	# Flying shards around the burst (finisher accent red).
	for i in 7:
		var a := TAU * (i + 0.4) / 7.0 + _rng.randf_range(-0.2, 0.2)
		var r := _rng.randf_range(205, 232)
		var tip := c + Vector2.from_angle(a) * (r + 22.0)
		var side := Vector2.from_angle(a + PI * 0.5) * _rng.randf_range(7, 11)
		var base := c + Vector2.from_angle(a) * (r - 12.0)
		body += _path(_pts(PackedVector2Array([tip, base + side, base - side])), ACCENT_RED, INK, 6.0)
	body += _path(_pts(_star(c, 18, Vector2(170, 214), Vector2(118, 140), 0.0, 0.3)), ACCENT_RED, INK, 14.0)
	body += _path(_pts(_star(c, 13, Vector2(126, 152), Vector2(78, 96), 0.2)), "url(#mid)", INK, 11.0)
	body += _path(_pts(_star(c, 9, Vector2(72, 88), Vector2(38, 48), 0.5)), "url(#core)", INK, 8.0)
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Impact burst, large (finishers), red finisher accent.")


## Four tapered streaks, one per 128 px row, thick end left, point right. White, tinted at
## runtime; the speed-line overlay draws each line from one row.
func _speed_lines() -> String:
	_rng.seed = 1404
	var body := ""
	var thickness := [16.0, 26.0, 38.0, 52.0]
	for row in 4:
		var cy := 64.0 + 128.0 * row
		var h: float = thickness[row]
		var pts := PackedVector2Array([
			Vector2(4, cy - h * 0.5), Vector2(60, cy - h * 0.46), Vector2(508, cy + _rng.randf_range(-2, 2)),
			Vector2(60, cy + h * 0.46), Vector2(4, cy + h * 0.5),
		])
		body += _path(_pts(pts), WHITE)
	return _doc(Rect2(0, 0, 512, 512), "", body, "Speed lines: four tapered streaks (rows of 128 px).")


# --- Blood, spit, tooth ----------------------------------------------------------------


## One comic blood droplet, tail pointing up (the runtime turns the tail away from where
## the drop flies).
func _blood_drop() -> String:
	var defs := _linear("red", BLOOD_LIGHT, BLOOD)
	var body := _path(_teardrop(Vector2(256, 330), 118.0, 300.0, -PI * 0.5), "url(#red)", BLOOD_DARK, 16.0)
	body += _path(_teardrop(Vector2(212, 318), 30.0, 70.0, -PI * 0.62), WHITE, "", 0.0, ' opacity="0.85"')
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Blood droplet (comic red).")


func _blood_splat(variant: int) -> String:
	_rng.seed = 2100 + variant
	var c := Vector2(256, 256)
	var body := ""
	var shapes := ""
	# Streaks thrown out from the middle.
	for i in 3 + variant:
		var a := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(160, 200)
		shapes += _teardrop(c + Vector2.from_angle(a) * dist, _rng.randf_range(18, 26), dist - 40.0, a + PI) + " "
	shapes += _blob(c, _rng.randf_range(118, 136), 13 + variant, 0.28) + " "
	var satellites := ""
	for i in 7 + variant * 2:
		var a := _rng.randf_range(0.0, TAU)
		var p := c + Vector2.from_angle(a) * _rng.randf_range(160, 222)
		var r := _rng.randf_range(9, 24)
		satellites += _circle(p, r, BLOOD, BLOOD_DARK, 7.0)
	body += _path(shapes, BLOOD, BLOOD_DARK, 14.0)
	body += _path(shapes, BLOOD)
	body += satellites
	body += _path(_blob(c + Vector2(-34, -30), 30.0, 7, 0.3), BLOOD_LIGHT, "", 0.0, ' opacity="0.8"')
	body += _circle(c + Vector2(-52, -48), 9.0, WHITE, "", 0.0, ' opacity="0.85"')
	return _doc(Rect2(0, 0, 512, 512), "", body, "Blood splat, variant %d (comic red)." % (variant + 1))


## The splash at the contact: a crown of droplets thrown outward around a small blob.
func _blood_spray() -> String:
	_rng.seed = 2200
	var c := Vector2(256, 256)
	var defs := _linear("red", BLOOD_LIGHT, BLOOD)
	var body := ""
	for i in 11:
		var a := TAU * i / 11.0 + _rng.randf_range(-0.18, 0.18)
		var dist := _rng.randf_range(120, 175)
		var r := _rng.randf_range(16, 30)
		body += _path(_teardrop(c + Vector2.from_angle(a) * dist, r, _rng.randf_range(60, 100), a + PI),
				"url(#red)", BLOOD_DARK, 10.0)
	for i in 6:
		var a := _rng.randf_range(0.0, TAU)
		body += _circle(c + Vector2.from_angle(a) * _rng.randf_range(200, 236), _rng.randf_range(8, 15), BLOOD, BLOOD_DARK, 6.0)
	body += _path(_blob(c, 70.0, 9, 0.3), "url(#red)", BLOOD_DARK, 12.0)
	body += _circle(c + Vector2(-22, -24), 12.0, WHITE, "", 0.0, ' opacity="0.85"')
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Blood spray at the contact point (comic red).")


func _spit() -> String:
	var defs := _linear("spit", WHITE, SPIT)
	var body := _path(_teardrop(Vector2(256, 330), 112.0, 290.0, -PI * 0.5), "url(#spit)", INK, 12.0,
			' fill-opacity="0.92"')
	body += _path(_teardrop(Vector2(214, 316), 28.0, 66.0, -PI * 0.62), WHITE)
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Spit droplet.")


## A knocked-out molar: crown, two roots, a touch of blood at the root tips.
func _tooth() -> String:
	var d := ("M150 120 Q150 70 205 72 Q232 74 256 92 Q280 74 307 72 Q362 70 362 120 L360 236 "
		+ "Q358 268 340 286 L332 420 Q328 452 302 450 Q282 448 280 420 L272 310 Q256 300 240 310 "
		+ "L232 420 Q230 448 210 450 Q184 452 180 420 L172 286 Q154 268 152 236 Z")
	var body := _path(d, PAPER, INK, 18.0)
	body += _path("M178 392 Q184 452 210 450 Q230 448 232 420 L234 396 Q206 410 178 392 Z", BLOOD)
	body += _path("M280 396 Q282 448 302 450 Q328 452 332 420 L334 394 Q306 410 280 396 Z", BLOOD)
	body += _path("M190 112 Q200 96 222 100", "none", WHITE, 14.0)
	body += _path("M200 150 Q230 168 256 150 Q282 168 312 150", "none", "#c9c1a6", 7.0)
	return _doc(Rect2(80, 40, 352, 440), "", body, "Tooth (head finishers).")


# --- Blocks ----------------------------------------------------------------------------


## A plain block: a small white star of short clanking spikes.
func _block_spark() -> String:
	_rng.seed = 3100
	var c := Vector2(256, 256)
	var body := ""
	for i in 8:
		var a := TAU * i / 8.0 + _rng.randf_range(-0.15, 0.15)
		var r0 := _rng.randf_range(120, 140)
		var r1 := _rng.randf_range(200, 236)
		body += _path("M%s %s L%s %s" % [_n(c.x + cos(a) * r0), _n(c.y + sin(a) * r0), _n(c.x + cos(a) * r1),
				_n(c.y + sin(a) * r1)], "none", INK, 26.0)
		body += _path("M%s %s L%s %s" % [_n(c.x + cos(a) * r0), _n(c.y + sin(a) * r0), _n(c.x + cos(a) * r1),
				_n(c.y + sin(a) * r1)], "none", WHITE, 12.0)
	body += _path(_pts(_star(c, 4, Vector2(118, 128), Vector2(30, 34), PI * 0.25, 0.0)), WHITE, INK, 10.0)
	return _doc(Rect2(0, 0, 512, 512), "", body, "Block spark (a blocked hit).")


## A perfect block: a tall cyan four-point flare with a ring and sparkles (distinct from
## the block spark by color and shape).
func _parry_spark() -> String:
	_rng.seed = 3200
	var c := Vector2(256, 256)
	var defs := _radial("glow", WHITE, PARRY_CYAN)
	var body := _circle(c, 168.0, "none", INK, 22.0) + _circle(c, 168.0, "none", PARRY_CYAN, 10.0)
	body += _path(_pts(_star(c, 4, Vector2(160, 170), Vector2(26, 30), PI * 0.25, 0.0)), "url(#glow)", INK, 9.0)
	body += _path(_pts(_star(c, 4, Vector2(244, 250), Vector2(30, 34), 0.0, 0.0)), "url(#glow)", INK, 10.0)
	for i in 5:
		var a := _rng.randf_range(0.0, TAU)
		var p := c + Vector2.from_angle(a) * _rng.randf_range(185, 225)
		body += _path(_pts(_star(p, 4, Vector2(16, 20), Vector2(5, 6), 0.0, 0.0)), WHITE, INK, 4.0)
	body += _circle(c, 26.0, WHITE)
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Parry spark (a perfect block), cyan.")


## A guard break: an amber burst split into shards with cracks between them.
func _guard_break() -> String:
	_rng.seed = 3300
	var c := Vector2(256, 256)
	var defs := _radial("amber", PALE_YELLOW, AMBER)
	var star := _star(c, 16, Vector2(190, 240), Vector2(120, 150))
	var body := ""
	var shards := 6
	var per := star.size() / shards
	for s in shards:
		var pts := PackedVector2Array()
		var gap := 0.06
		var a0 := TAU * s / shards
		var push := Vector2.from_angle(a0 + TAU / shards * 0.5) * 18.0
		pts.append(c + push)
		for k in range(s * per, (s + 1) * per + 1):
			pts.append(star[k % star.size()] + push)
		body += _path(_pts(pts), "url(#amber)", INK, 13.0)
		body += _path("M%s %s L%s %s" % [_n(c.x + push.x), _n(c.y + push.y),
				_n(c.x + push.x + cos(a0 + gap) * 90.0), _n(c.y + push.y + sin(a0 + gap) * 90.0)], "none", INK, 7.0)
	body += _path(_pts(_star(c, 7, Vector2(60, 72), Vector2(26, 32))), WHITE, INK, 8.0)
	return _doc(Rect2(0, 0, 512, 512), defs, body, "Guard-break burst (amber shards).")


## Milestone 3's rear-attack warning (Spec §8): a jagged red-orange alert burst with a "!".
func _rear_warning() -> String:
	_rng.seed = 3400
	var c := Vector2(256, 256)
	var body := _path(_pts(_star(c, 12, Vector2(200, 244), Vector2(140, 160))), WARNING_RED, INK, 16.0)
	body += _path(_pts(_star(c, 10, Vector2(150, 170), Vector2(110, 122), 0.3)), YELLOW, INK, 10.0)
	var bang: Array = GLYPHS["!"]
	var xf := Transform2D(0.0, Vector2(2.3, 2.3), 0.0, c - Vector2(16, 50) * 2.3)
	var paths := PackedStringArray()
	for contour: Array in bang:
		var pts := PackedVector2Array()
		for k in range(0, contour.size(), 2):
			pts.append(xf * Vector2(contour[k], contour[k + 1]))
		paths.append(_pts(pts))
	body += _path(" ".join(paths), WHITE, INK, 14.0)
	return _doc(Rect2(0, 0, 512, 512), "", body, "Rear-attack warning burst (Milestone 3), red-orange.")


# --- Damage tiles ----------------------------------------------------------------------


## A seamless 512 px tile for the enemies' damage looks (triplanar detail texture), drawn
## to read from 1 m in first person and from the side view, with no red until the blood:
##   skin     a purple-gray wash and big comic bruises (an olive rim, a purple or blue body
##            with a dark middle and an ink edge) and ink scrapes;
##   clothes  a dirt wash, dark scuffs and ink tears;
## with `blood`, comic blood splats over either (the bloodied look keeps the bruises).
func _damage_tile(skin: bool, blood: bool) -> String:
	var shapes := ""
	if skin:
		_rng.seed = 4100
		shapes += '<rect x="0" y="0" width="512" height="512" fill="%s" opacity="0.3"/>\n' % BRUISE_WASH
		for i in 6:
			var c := _cell_point([0, 2, 3, 5, 6, 7][i], 3, 3)
			var r := _rng.randf_range(40, 86)
			var fill := BRUISE if i % 3 != 2 else BRUISE_BLUE
			var rim := _blob(Vector2.ZERO, r * 1.3, 10, 0.3)
			var body := _blob(Vector2.ZERO, r, 9, 0.35)
			var core := _blob(Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35)) * r, r * 0.35, 7, 0.4)
			var shape := 'rotate(%s) scale(1 %s)' % [_n(_rng.randf_range(0.0, 180.0)), String.num(_rng.randf_range(0.6, 0.95), 2)]
			# The rim reaches 1.3 x (1 + jitter) of the radius.
			for o in _wraps(c, r * 1.75):
				shapes += '<g transform="translate(%s %s) %s">' % [_n(o.x), _n(o.y), shape]
				shapes += _path(rim, BRUISE_OLD, "", 0.0, ' opacity="0.5"').trim_suffix("\n")
				shapes += _path(body, fill, BRUISE_DARK, 5.0, ' opacity="0.9"').trim_suffix("\n")
				shapes += _path(core, BRUISE_DARK, "", 0.0, ' opacity="0.6"').trim_suffix("\n") + "</g>\n"
		shapes += _scratches(4, INK, 6.0, 0.75)
	else:
		_rng.seed = 4300
		shapes += '<rect x="0" y="0" width="512" height="512" fill="%s" opacity="0.28"/>\n' % DIRT
		for i in 9:
			var c := _cell_point(i, 3, 3)
			var r := _rng.randf_range(50, 84)
			var d := _blob(Vector2.ZERO, r, 11, 0.35)
			var shape := 'rotate(%s) scale(1 %s)' % [_n(_rng.randf_range(0.0, 180.0)), String.num(_rng.randf_range(0.35, 0.6), 2)]
			for o in _wraps(c, r * 1.4):
				shapes += '<g transform="translate(%s %s) %s">' % [_n(o.x), _n(o.y), shape]
				shapes += _path(d, DIRT_DARK, "", 0.0, ' opacity="0.7"').trim_suffix("\n") + "</g>\n"
		for i in 6:
			var c := Vector2(_rng.randf_range(0, 512), _rng.randf_range(0, 512))
			var tear := _tear(_rng.randf_range(70, 120), _rng.randf_range(12, 20), _rng.randf_range(0.0, PI))
			for o in _wraps(c, 70.0):
				shapes += '<g transform="translate(%s %s)">' % [_n(o.x), _n(o.y)]
				shapes += _path(tear, INK, "", 0.0, ' opacity="0.92"').trim_suffix("\n") + "</g>\n"
		shapes += _scratches(4, INK, 5.0, 0.6)
	if blood:
		_rng.seed = 4200
		for i in 12:
			var c := _cell_point(i, 4, 3)
			var r := _rng.randf_range(18, 34)
			var d := _blob(Vector2.ZERO, r, 9, 0.3)
			for k in 2 + i % 3:
				var a := _rng.randf_range(0.0, TAU)
				var dist := r + _rng.randf_range(10, 22)
				d += " " + _teardrop(Vector2.from_angle(a) * dist, _rng.randf_range(5, 8), dist - r * 0.4, a + PI)
			var drops := ""
			for k in 4:
				var p := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(r + 20, r + 44)
				drops += _circle(p, _rng.randf_range(3, 7), BLOOD).trim_suffix("\n")
			for o in _wraps(c, r + 50.0):
				shapes += '<g transform="translate(%s %s)">' % [_n(o.x), _n(o.y)]
				shapes += _path(d, BLOOD, BLOOD_DARK, 6.0).trim_suffix("\n") + _path(d, BLOOD).trim_suffix("\n")
				shapes += drops + "</g>\n"
	var note := "Damage-look tile (seamless): " + ("bruised skin" if skin else "scuffed clothes") \
		+ (" with blood" if blood else "") + "."
	return _doc(Rect2(0, 0, 512, 512), "", shapes, note)


## `count` comic scratches (three short parallel strokes each) in `color`, wrapping.
func _scratches(count: int, color: String, width: float, opacity: float) -> String:
	var out := ""
	for i in count:
		var c := Vector2(_rng.randf_range(0, 512), _rng.randf_range(0, 512))
		var a := _rng.randf_range(0.0, PI)
		var d := ""
		for k in 3:
			var off := Vector2.from_angle(a + PI * 0.5) * (k - 1) * 11.0
			var half := Vector2.from_angle(a) * _rng.randf_range(24, 38)
			d += "M%s %s L%s %s " % [_n(off.x - half.x), _n(off.y - half.y), _n(off.x + half.x), _n(off.y + half.y)]
		for o in _wraps(c, 45.0):
			out += '<g transform="translate(%s %s)">' % [_n(o.x), _n(o.y)]
			out += _path(d, "none", color, width, ' opacity="%s"' % _n(opacity)).trim_suffix("\n") + "</g>\n"
	return out


## A ripped tear in cloth: a jagged slit `length` long and up to `width` wide along `angle`,
## centered on the origin.
func _tear(length: float, width: float, angle: float) -> String:
	var dir := Vector2.from_angle(angle)
	var side := Vector2(-dir.y, dir.x)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var steps := 7
	for k in steps + 1:
		var u := float(k) / steps
		var along := dir * (u - 0.5) * length
		var w := width * sin(u * PI) * 0.5
		top.append(along + side * w * _rng.randf_range(0.5, 1.3))
		bottom.append(along - side * w * _rng.randf_range(0.5, 1.3))
	bottom.reverse()
	return _pts(top + bottom)


## A random point in cell `i` of a `cols` x `rows` grid over the 512 px tile, so shapes
## spread over the tile instead of clumping.
func _cell_point(i: int, cols: int, rows: int) -> Vector2:
	var cell := Vector2(512.0 / cols, 512.0 / rows)
	return Vector2((i % cols + _rng.randf_range(0.2, 0.8)) * cell.x, (i / cols % rows + _rng.randf_range(0.2, 0.8)) * cell.y)


## Where to draw a shape centered at `c` (reaching `reach` px) so the 512 px tile wraps.
static func _wraps(c: Vector2, reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for ox: float in [-512.0, 0.0, 512.0]:
		for oy: float in [-512.0, 0.0, 512.0]:
			var p := c + Vector2(ox, oy)
			if p.x + reach > 0.0 and p.x - reach < 512.0 and p.y + reach > 0.0 and p.y - reach < 512.0:
				out.append(p)
	return out


# --- Rasterizing -----------------------------------------------------------------------


## Rasterize every SVG in SOURCE_DIR to EXPORT_DIR at its own pixel size (width/height).
func _rasterize_all() -> int:
	var count := 0
	var dir := DirAccess.open(SOURCE_DIR)
	for file in dir.get_files():
		if file.get_extension() != "svg":
			continue
		var svg := FileAccess.get_file_as_string(SOURCE_DIR.path_join(file))
		var image := Image.new()
		var err := image.load_svg_from_string(svg, 1.0)
		if err != OK:
			push_error("gen_fx: could not rasterize %s (%d)" % [file, err])
			continue
		var png := EXPORT_DIR.path_join(file.get_basename() + ".png")
		image.save_png(ProjectSettings.globalize_path(png))
		_import_settings(png)
		count += 1
	return count


## Import every PNG lossless with mipmaps (crisp ink edges near the camera, clean at a
## distance), and never VRAM-compressed on first 3D use. Writes a minimal .import file
## that the next `godot --import` completes, or patches an existing one.
static func _import_settings(png: String) -> void:
	var path := ProjectSettings.globalize_path(png + ".import")
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
		text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
		text = text.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
		text = text.replace("compress/mode=2", "compress/mode=0")
	else:
		text = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
			+ "compress/mode=0\nmipmaps/generate=true\ndetect_3d/compress_to=0\n")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
