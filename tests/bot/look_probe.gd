extends RefCounted
## The look probe (M4-plan Part B, rows L1-L3 and L5; P1-post): pixel metrics of a rendered frame,
## and `look.json`, where the windowed acts write them. Static functions on `Image`s, so the
## numbers can be checked headless on synthetic images (tests/test_look_post.gd); the acts that
## render (tests/bot/acts/look_post_acts.gd, and the later packages' acts) grab the viewport with
## grab() and call these.
##
## Pixels. Every width is reported at 1080p (an `Image` of any height is scaled by 1080 / height),
## the unit the look bible and the tunables use; a 1600x900 recording is therefore multiplied by
## 1.2. A rectangle is in the image's own pixels.
##
##   line_width_px()       the median width of the lines that exist in one frame and not in the
##                         other (the edge pass on and off): L1, for the environment's lines
##   dark_runs()           the dark runs along a straight scan: a hull is one run, a doubled
##                         silhouette (A8) is two
##   luma_clusters()       the distinct brightness bands of a region (L2: 2-3 on the jacket)
##   bands()               the same for the pixels of one hue family (a swatch), with each band's
##                         mean color, so a band's hue can be set against its swatch's (F-look)
##   hue_gap()             the angle between two hues, in degrees
##   line_width_scan()     the half-maximum width at 1080p of the first dark line met on a straight
##                         scan, and its darkest pixel
##   ring_width_px()       the width at 1080p of the ink ring one frame has over another (L1: the
##                         hull's width, from the frame with the hull and the frame with its width 0),
##                         measured by how much of each pixel the ink covers, so it is sub-pixel
##   shadow_ratio()        the darkest band's brightness over the lightest's (L3: at least 0.4)
##   white_share()         the share of near-white pixels (L5: the flash's share of the view)
##   changed_share()       the share of pixels two frames disagree on
##   mean_delta_e()        the mean CIE76 distance between two frames (the grade's shift)
##   record()              merge one measurement's values into look.json beside the recording
##   read()                the look.json beside the recording, as a Dictionary
##   dump()                write a frame as probe_<name>.png beside it
##   final_rows()          P3-int: Part B's windowed rows L1, L2, L3 and L5 from what the acts measured, each with its
##                         state against the plan's bar ("met", "missed" or "not measured"); the act `Look: final probe`
##                         (tests/bot/acts/look_final_acts.gd) runs the acts in one window and records them under
##                         look.json's "final" key, for the lead to paste
##   parse_bands(), parse_l5()  the text the acts print, back into numbers

const GenLut := preload("res://tools/gen_lut.gd")

## What counts as ink in a frame: the lines and the hull come out of the tonemapper, the grade and
## the fog at a luma of about 0.1 to 0.13 (measured: (27, 24, 31) for an edge line, (34, 29, 33)
## for a fogged hull, of 255), the darkest wall at 0.28, so anything under this is a line or a hull.
const DARK_LUMA := 0.2
## A channel difference (0-1) above which two frames disagree on a pixel (8-bit noise is 0.004).
const CHANGED_DELTA := 0.03
## A pixel is white when its darkest channel is at least this (the contact flash is full white).
const WHITE_LEVEL := 0.92
## Brightness histogram of luma_clusters(): the bins, and the share of the region a bin needs to count.
const CLUSTER_BINS := 32
const CLUSTER_MIN_SHARE := 0.02
## The pixel count one changed run may have at most to be a line and not a region (at 1080p): a
## wider run is skipped by line_width_px().
const LINE_MAX_PX := 12
## The least luma difference between a line's darkest pixel and the pixel 4 px outside it for
## line_width_scan() to call it a line.
const LINE_MIN_CONTRAST := 0.15
## ring_width_px(): the luma of the ink as drawn (a little above black), the least span between a pixel
## without the line and the ink for the pixel to be measured, the coverage a pixel needs to be in a
## run, and the coverage at which it counts as ink for the ink's colour.
const RING_INK_LUMA := 0.06
const RING_MIN_SPAN := 0.1
const COVER_MIN := 0.08
const RING_FULL_COVER := 0.9
## outer_ring_px(): a run is the ink ring only if some pixel of it is at least this covered.
const RING_PEAK_MIN := 0.6
## The reference height pixels are reported at.
const REFERENCE_HEIGHT := 1080.0
const LOOK_JSON := "look.json"
## The look.json key the final rows are recorded under.
const FINAL_KEY := "final"

## Part B's windowed rows (M4-plan section B1), as P3-int reads them.
## L1: the hull's width at these distances (the 1 m shot is the face shot), within HULL_TOLERANCE_PX of look_outline_px at 1080p
## (the player's own body: of look_outline_px x look_outline_fp_scale) and never above the look bible's HULL_MAX_PX.
const HULL_DISTANCES_M: Array[float] = [1.0, 2.5, 5.0, 10.0]
const HULL_FAMILIES: Array[String] = ["crown", "left", "right"]
const OWN_FAMILIES: Array[String] = ["left", "right", "top"]
const HULL_TOLERANCE_PX := 1.0
const HULL_MAX_PX := 4.5
## L2: 2-3 luminance clusters on the jacket at 1 m, the shadow band at least this share of the lit band's luma, its hue nearer the
## shadow tint than the lit band's.
const BANDS_MIN := 2
const BANDS_MAX := 3
const SHADOW_OVER_LIT_MIN := 0.4
## L3: the white share of the view in the frame a jab's contact flash is first drawn in, at most M2's localized figure plus this
## (points). M2's figure is the before pack's own frames of the same hit (the M3 look, C5 frames 44 and 45: 4.1% and 4.3%,
## M4-calls/F-look.md, L3).
const M2_JAB_FLASH_WHITE_SHARE := 0.043
const FLASH_MARGIN := 0.02
## L5: "within noise of M3" is read as the art-drawn R8 within these points of the proxies' at the median and at the 95th
## percentile, and no wind-up hidden by another enemy that the proxies did not see hidden. Part B gives no number. A fight is
## seeded, so a rerun reads the same figures; the spread to read is how far the same measure moved between two states of the
## project: the art-minus-proxies gap on "Six Punks, fight" was +0.5 and +2.8 points on the smoke Punk (P3-early) and is -2.1 and
## +0.5 on the shipped one (M4-calls/P3-int.md C8), so a bar of 2 would call the art's own change a failure; the bar is 3 and 5.
const L5_P50_POINTS := 3.0
const L5_P95_POINTS := 5.0


## The smallest angle in degrees between two hues (0-360).
static func hue_gap(a: float, b: float) -> float:
	var gap := absf(fposmod(a - b + 180.0, 360.0) - 180.0)
	return gap


## The brightness of a color (Rec. 709 luma of its display values).
static func luma(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


## The viewport's current frame as an RGB8 image, or null when there is none to read (a headless
## run draws nothing). Call it after `await RenderingServer.frame_post_draw`.
static func grab(viewport: Viewport) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGB8)
	return image


## How many pixels of `height` pixels a 1080p width is: multiply a width by this to get 1080p.
static func to_1080p(height: int) -> float:
	return REFERENCE_HEIGHT / float(maxi(height, 1))


## The lengths of the runs of dark pixels (luma below `dark_luma`) along the straight scan from
## `from` to `to` (both inclusive, on one row or one column).
static func dark_runs(image: Image, from: Vector2i, to: Vector2i, dark_luma: float = DARK_LUMA) -> PackedInt32Array:
	var runs := PackedInt32Array()
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	var dir := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var run := 0
	for i in steps + 1:
		var at := from + dir * i
		var dark := luma(image.get_pixelv(at)) < dark_luma if _inside(image, at) else false
		if dark:
			run += 1
		elif run > 0:
			runs.append(run)
			run = 0
	if run > 0:
		runs.append(run)
	return runs


## The median width, at 1080p, of the lines drawn in `with` and not in `without` (the same frame
## with the edge pass off) inside `rect`: for every pixel the two frames disagree on, the shorter of
## its horizontal and vertical run of disagreeing pixels; runs over LINE_MAX_PX are regions, not
## lines. 0.0 when nothing differs.
static func line_width_px(with: Image, without: Image, rect: Rect2i, step: int = 1) -> float:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, with.get_size()))
	var changed := PackedByteArray()
	changed.resize(r.size.x * r.size.y)
	for y in r.size.y:
		for x in r.size.x:
			var a := with.get_pixel(r.position.x + x, r.position.y + y)
			var b := without.get_pixel(r.position.x + x, r.position.y + y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > CHANGED_DELTA:
				changed[y * r.size.x + x] = 1
	var widths := PackedFloat32Array()
	var limit := ceili(LINE_MAX_PX / to_1080p(with.get_height()))
	for y in range(0, r.size.y, maxi(step, 1)):
		var x := 0
		while x < r.size.x:
			if changed[y * r.size.x + x] == 0:
				x += 1
				continue
			var x1 := x
			while x1 < r.size.x and changed[y * r.size.x + x1] == 1:
				x1 += 1
			var across := x1 - x
			# One sample per run: the vertical run through its middle.
			var mid := x + across / 2
			var y0 := y
			while y0 > 0 and changed[(y0 - 1) * r.size.x + mid] == 1:
				y0 -= 1
			var y1 := y
			while y1 < r.size.y - 1 and changed[(y1 + 1) * r.size.x + mid] == 1:
				y1 += 1
			var width := mini(across, y1 - y0 + 1)
			if width <= limit:
				widths.append(float(width))
			x = x1
	if widths.is_empty():
		return 0.0
	widths.sort()
	return widths[widths.size() / 2] * to_1080p(with.get_height())


## The centres (luma) of the distinct brightness bands of `rect`: maximal runs of histogram bins
## that each hold at least CLUSTER_MIN_SHARE of the pixels, darkest first.
static func luma_clusters(image: Image, rect: Rect2i, step: int = 1) -> PackedFloat32Array:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var counts := PackedInt32Array()
	counts.resize(CLUSTER_BINS)
	var sums := PackedFloat32Array()
	sums.resize(CLUSTER_BINS)
	var total := 0
	for y in range(r.position.y, r.end.y, maxi(step, 1)):
		for x in range(r.position.x, r.end.x, maxi(step, 1)):
			var l := luma(image.get_pixel(x, y))
			var bin := clampi(int(l * CLUSTER_BINS), 0, CLUSTER_BINS - 1)
			counts[bin] += 1
			sums[bin] += l
			total += 1
	var centres := PackedFloat32Array()
	var run_count := 0
	var run_sum := 0.0
	for bin in CLUSTER_BINS + 1:
		var populated := bin < CLUSTER_BINS and float(counts[bin]) >= CLUSTER_MIN_SHARE * float(maxi(total, 1))
		if populated:
			run_count += counts[bin]
			run_sum += sums[bin]
		elif run_count > 0:
			centres.append(run_sum / float(run_count))
			run_count = 0
			run_sum = 0.0
	return centres


## The brightness bands of the pixels of `rect` that pass `filter`, darkest first: one Dictionary a
## band, {luma, color (the mean), share (of the kept pixels)}; bands are found as luma_clusters() does,
## over the kept pixels only. `filter`: `hue` (degrees) with `hue_tol` (the largest gap), `s_min`,
## `s_max`, `v_min` (all optional), and `only` (an Image of the same size: a pixel counts only
## where it differs from this frame, the frame with the character taken away).
static func bands(image: Image, rect: Rect2i, filter: Dictionary, step: int = 2) -> Array[Dictionary]:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var other := filter.get("only") as Image
	var counts := PackedInt32Array()
	counts.resize(CLUSTER_BINS)
	var sums := PackedColorArray()
	sums.resize(CLUSTER_BINS)
	var total := 0
	for y in range(r.position.y, r.end.y, maxi(step, 1)):
		for x in range(r.position.x, r.end.x, maxi(step, 1)):
			var c := image.get_pixel(x, y)
			if other != null:
				var o := other.get_pixel(x, y)
				if maxf(absf(c.r - o.r), maxf(absf(c.g - o.g), absf(c.b - o.b))) <= CHANGED_DELTA:
					continue
			if c.s < float(filter.get("s_min", 0.0)) or c.s > float(filter.get("s_max", 1.0)) \
					or c.v < float(filter.get("v_min", 0.0)):
				continue
			if filter.has("hue") and hue_gap(c.h * 360.0, float(filter.hue)) > float(filter.get("hue_tol", 30.0)):
				continue
			var bin := clampi(int(luma(c) * CLUSTER_BINS), 0, CLUSTER_BINS - 1)
			counts[bin] += 1
			sums[bin] = Color(sums[bin].r + c.r, sums[bin].g + c.g, sums[bin].b + c.b)
			total += 1
	var out: Array[Dictionary] = []
	var run_count := 0
	var run_sum := Color(0.0, 0.0, 0.0)
	for bin in CLUSTER_BINS + 1:
		var populated := bin < CLUSTER_BINS and float(counts[bin]) >= CLUSTER_MIN_SHARE * float(maxi(total, 1))
		if populated:
			run_count += counts[bin]
			run_sum = Color(run_sum.r + sums[bin].r, run_sum.g + sums[bin].g, run_sum.b + sums[bin].b)
		elif run_count > 0:
			var mean := Color(run_sum.r / run_count, run_sum.g / run_count, run_sum.b / run_count)
			out.append({luma = luma(mean), color = mean, share = float(run_count) / float(maxi(total, 1))})
			run_count = 0
			run_sum = Color(0.0, 0.0, 0.0)
	return out


## The half-maximum width, at 1080p, of the first dark line met walking from `from` by the unit
## step `dir` for `max_px` pixels (from outside the figure, inward), and its darkest pixel:
## {width, color}, or {width = -1.0} when there is none to measure (no pixel under DARK_LUMA, little
## contrast with the pixel 4 px before it, or a line that never ends because the body beside it is as
## dark). The half-maximum is the midpoint of the line's darkest luma and that outside pixel's, with
## the two crossings interpolated, so the width is sub-pixel and ignores the line's anti-aliasing.
static func line_width_scan(image: Image, from: Vector2i, dir: Vector2i, max_px: int = 48) -> Dictionary:
	var lumas := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in max_px:
		var at := from + dir * i
		if not _inside(image, at):
			break
		var c := image.get_pixelv(at)
		colors.append(c)
		lumas.append(luma(c))
	var first := -1
	for i in lumas.size():
		if lumas[i] < DARK_LUMA:
			first = i
			break
	if first < 0:
		return {width = -1.0}
	var low := first
	for i in range(first, mini(first + LINE_MAX_PX, lumas.size())):
		if lumas[i] < lumas[low]:
			low = i
	var outside := lumas[maxi(first - 4, 0)]
	if outside - lumas[low] < LINE_MIN_CONTRAST:
		return {width = -1.0}
	var half := 0.5 * (outside + lumas[low])
	var left := float(low)
	while left > 0.0 and lumas[int(left) - 1] < half:
		left -= 1.0
	if left <= 0.0:
		return {width = -1.0}
	var a := lumas[int(left) - 1]
	var b := lumas[int(left)]
	left -= (a - half) / maxf(a - b, 0.0001)
	var right := float(low)
	while int(right) + 1 < lumas.size() and lumas[int(right) + 1] < half:
		right += 1.0
	if int(right) + 1 >= lumas.size():
		return {width = -1.0}
	var c := lumas[int(right)]
	var d := lumas[int(right) + 1]
	right += (half - c) / maxf(d - c, 0.0001)
	return {width = (right - left) * to_1080p(image.get_height()), color = colors[low]}


## The median width, at 1080p, of the ink ring `with` has over `without` inside `rect`: both frames of
## the same scene, `without` with the line's width set to 0. A pixel's coverage is how far `with` has
## moved from `without` toward `ink_luma` (0-1); the ring's width across an edge is the sum of the
## coverage along a run of covered pixels (over COVER_MIN), and a run counts as the shorter of its row's
## and its column's, so a slanted edge is not stretched. A pixel where `without` is already as dark as
## the ink has nothing to measure and covers nothing. {width, ink (the mean colour of the fully covered
## pixels), runs}; width is -1.0 when there is no run.
static func ring_width_px(with: Image, without: Image, rect: Rect2i, ink_luma: float = RING_INK_LUMA) -> Dictionary:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, with.get_size()))
	var w := r.size.x
	var h := r.size.y
	if w <= 0 or h <= 0:
		return {width = -1.0, runs = 0}
	var covered := _coverage(with, without, r, ink_luma)
	var cover: PackedFloat32Array = covered.cover
	var ink_sum: Vector3 = covered.ink_sum
	var ink_n: int = covered.ink_n
	var widths := PackedFloat32Array()
	var limit := ceili(LINE_MAX_PX / to_1080p(with.get_height()))
	for y in h:
		var x := 0
		while x < w:
			if cover[y * w + x] <= COVER_MIN:
				x += 1
				continue
			var x1 := x
			var across := 0.0
			while x1 < w and cover[y * w + x1] > COVER_MIN:
				across += cover[y * w + x1]
				x1 += 1
			var mid := x + (x1 - x) / 2
			var y0 := y
			while y0 > 0 and cover[(y0 - 1) * w + mid] > COVER_MIN:
				y0 -= 1
			var down := 0.0
			var yy := y0
			while yy < h and cover[yy * w + mid] > COVER_MIN:
				down += cover[yy * w + mid]
				yy += 1
			var width := minf(across, down)
			if width <= float(limit):
				widths.append(width)
			x = x1
	if widths.is_empty():
		return {width = -1.0, runs = 0}
	widths.sort()
	var ink := Color(0.0, 0.0, 0.0)
	if ink_n > 0:
		ink = Color(ink_sum.x / ink_n, ink_sum.y / ink_n, ink_sum.z / ink_n)
	return {width = widths[widths.size() / 2] * to_1080p(with.get_height()), ink = ink, runs = widths.size()}


## The width, at 1080p, of the OUTERMOST ink ring `with` has over `without` along scan lines through
## `rect`, walking in direction `dir` ((0, 1) down the columns from the top, (1, 0) along the rows from
## the left, (-1, 0) from the right): on each line the first run of covered pixels, summed by coverage;
## a line is skipped when its run starts at the window's own edge (the window began inside ink) or is
## wider than a line; a faint run (no pixel in it under RING_PEAK_MIN covered) is skipped. {width (the
## median), runs}; width is -1.0 when no line has a run.
static func outer_ring_px(with: Image, without: Image, rect: Rect2i, dir: Vector2i, ink_luma: float = RING_INK_LUMA) -> Dictionary:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, with.get_size()))
	var w := r.size.x
	var h := r.size.y
	if w <= 0 or h <= 0:
		return {width = -1.0, runs = 0}
	var cover: PackedFloat32Array = _coverage(with, without, r, ink_luma).cover
	var limit := ceili(LINE_MAX_PX / to_1080p(with.get_height()))
	var widths := PackedFloat32Array()
	var vertical := dir.x == 0
	var lines := w if vertical else h
	var length := h if vertical else w
	for line in lines:
		var run := 0.0
		var peak := 0.0
		var started := -1
		var ended := -1
		for i in length:
			var at := i if dir.x >= 0 and dir.y >= 0 else length - 1 - i
			var c := cover[at * w + line] if vertical else cover[line * w + at]
			if c > COVER_MIN:
				if started < 0:
					started = i
				run += c
				peak = maxf(peak, c)
				ended = i
			elif started >= 0:
				if peak >= RING_PEAK_MIN:
					break
				# A faint run (a background line the frames disagree on a little) is not the ring.
				run = 0.0
				peak = 0.0
				started = -1
		if started > 0 and peak >= RING_PEAK_MIN and run <= float(limit):
			# The run's width across the other axis through its middle, so a slanted edge (a run along
			# a scan line is wider than the ring by 1 / cos of the slant) counts as the shorter of the two.
			var mid := started + (ended - started) / 2
			var at_mid := mid if dir.x >= 0 and dir.y >= 0 else length - 1 - mid
			var across := _run_sum(cover, w, h, line if vertical else at_mid, at_mid if vertical else line, vertical)
			widths.append(minf(run, across) if across > 0.0 else run)
	if widths.is_empty():
		return {width = -1.0, runs = 0}
	widths.sort()
	return {width = widths[widths.size() / 2] * to_1080p(with.get_height()), runs = widths.size()}


## The sum of the coverage over the run of covered pixels through (x, y), along the row when
## `horizontal`, else down the column.
static func _run_sum(cover: PackedFloat32Array, w: int, h: int, x: int, y: int, horizontal: bool) -> float:
	var step_x := 1 if horizontal else 0
	var step_y := 0 if horizontal else 1
	var cx := x
	var cy := y
	while cx - step_x >= 0 and cy - step_y >= 0 and cover[(cy - step_y) * w + cx - step_x] > COVER_MIN:
		cx -= step_x
		cy -= step_y
	var sum := 0.0
	while cx < w and cy < h and cover[cy * w + cx] > COVER_MIN:
		sum += cover[cy * w + cx]
		cx += step_x
		cy += step_y
	return sum


## How much of each pixel of `r` the ink covers: {cover (a PackedFloat32Array, row after row), ink_sum
## and ink_n (the sum of the fully covered pixels' colours and how many)}.
static func _coverage(with: Image, without: Image, r: Rect2i, ink_luma: float) -> Dictionary:
	var cover := PackedFloat32Array()
	cover.resize(r.size.x * r.size.y)
	var ink_sum := Vector3.ZERO
	var ink_n := 0
	for y in r.size.y:
		for x in r.size.x:
			var a := with.get_pixel(r.position.x + x, r.position.y + y)
			var b := without.get_pixel(r.position.x + x, r.position.y + y)
			var span := luma(b) - ink_luma
			if span < RING_MIN_SPAN:
				continue
			var c := clampf((luma(b) - luma(a)) / span, 0.0, 1.0)
			cover[y * r.size.x + x] = c
			if c > RING_FULL_COVER:
				ink_sum += Vector3(a.r, a.g, a.b)
				ink_n += 1
	return {cover = cover, ink_sum = ink_sum, ink_n = ink_n}


## The darkest band's brightness over the lightest's in `rect` (1.0 for a single band).
static func shadow_ratio(image: Image, rect: Rect2i, step: int = 1) -> float:
	var centres := luma_clusters(image, rect, step)
	if centres.size() < 2:
		return 1.0
	return centres[0] / centres[centres.size() - 1]


## The share of `rect`'s pixels that are white (WHITE_LEVEL), the whole frame when the rect is empty.
static func white_share(image: Image, rect: Rect2i = Rect2i(), step: int = 1) -> float:
	var r := Rect2i(Vector2i.ZERO, image.get_size()) if not rect.has_area() \
			else rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var white := 0
	var total := 0
	for y in range(r.position.y, r.end.y, maxi(step, 1)):
		for x in range(r.position.x, r.end.x, maxi(step, 1)):
			var c := image.get_pixel(x, y)
			if minf(c.r, minf(c.g, c.b)) >= WHITE_LEVEL:
				white += 1
			total += 1
	return float(white) / float(maxi(total, 1))


## The share of `rect`'s pixels (the whole frame when empty) the two frames disagree on.
static func changed_share(a: Image, b: Image, rect: Rect2i = Rect2i(), step: int = 1) -> float:
	var r := Rect2i(Vector2i.ZERO, a.get_size()) if not rect.has_area() \
			else rect.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	var changed := 0
	var total := 0
	for y in range(r.position.y, r.end.y, maxi(step, 1)):
		for x in range(r.position.x, r.end.x, maxi(step, 1)):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > CHANGED_DELTA:
				changed += 1
			total += 1
	return float(changed) / float(maxi(total, 1))


## The mean CIE76 distance between the two frames over `rect` (the whole frame when empty).
static func mean_delta_e(a: Image, b: Image, rect: Rect2i = Rect2i(), step: int = 1) -> float:
	var r := Rect2i(Vector2i.ZERO, a.get_size()) if not rect.has_area() \
			else rect.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	var sum := 0.0
	var total := 0
	for y in range(r.position.y, r.end.y, maxi(step, 1)):
		for x in range(r.position.x, r.end.x, maxi(step, 1)):
			sum += GenLut.delta_e76(a.get_pixel(x, y), b.get_pixel(x, y))
			total += 1
	return sum / float(maxi(total, 1))


## Merge `values` under `key` into look.json in `dir` (the folder of the recording, or
## `--probe-out=<dir>`, else user://); other keys stay. Returns the path written, or "".
static func record(key: String, values: Dictionary, dir: String = "") -> String:
	var folder := dir if not dir.is_empty() else _capture_dir()
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join(LOOK_JSON)
	var data := {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	data[key] = values
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("look_probe: cannot write %s" % path)
		return ""
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	return path


## The look.json beside the recording (or `--probe-out=<dir>`, else user://) as a Dictionary: what record() has written, `{}` when
## there is none.
static func read(dir: String = "") -> Dictionary:
	var folder := dir if not dir.is_empty() else _capture_dir()
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("user://")
	var path := folder.path_join(LOOK_JSON)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The bands text a tuning act prints (`luma/hue/share/saturation` per band, darkest first, joined by commas) as
## `[{luma, hue (degrees), share, saturation}]`; empty for an empty or unreadable text.
static func parse_bands(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: String in text.split(",", false):
		var fields := part.split("/")
		if fields.size() != 4 or not fields[0].is_valid_float():
			return [] as Array[Dictionary]
		out.append({luma = float(fields[0]), hue = float(fields[1]), share = float(fields[2]), saturation = float(fields[3])})
	return out


## The LOOK-L5 lines of the readability act (tests/bot/look_l5.gd lines()) as `{<fight label>: {samples, ticks, r8_proxies_p50,
## r8_proxies_p95, r8_art_p50, r8_art_p95 (shares, 0-1), diff_p50, diff_p95 (points), cells_mean, cells_worst (shares),
## windups, windups_in_view, r4_proxies, r4_art, worst_ms}}`. A fight with only one of its two lines has only that part.
static func parse_l5(lines: PackedStringArray) -> Dictionary:
	var r8 := RegEx.new()
	r8.compile("LOOK-L5 (.+) R8 \\((\\d+) samples of the lens, (\\d+) ticks\\): proxies p50 ([\\d.]+)% p95 ([\\d.]+)% max ([\\d.]+)% \\| art drawn p50 ([\\d.]+)% p95 ([\\d.]+)% max ([\\d.]+)% \\| difference p50 ([+-][\\d.]+) pp p95 ([+-][\\d.]+) pp \\| cells that differ: mean ([\\d.]+)% worst ([\\d.]+)%")
	var r4 := RegEx.new()
	r4.compile("LOOK-L5 (.+) R4 \\((\\d+) wind-ups, (\\d+) in the lens, (\\d+) never sampled\\): hidden by another enemy: proxies (\\d+) of \\d+ \\| art drawn (\\d+) of \\d+ \\| worst sample ([\\d.]+) ms")
	var out := {}
	for line: String in lines:
		var m := r8.search(line)
		if m != null:
			var fight: Dictionary = out.get(m.get_string(1), {})
			fight.merge({
				samples = int(m.get_string(2)), ticks = int(m.get_string(3)),
				r8_proxies_p50 = float(m.get_string(4)) / 100.0, r8_proxies_p95 = float(m.get_string(5)) / 100.0,
				r8_art_p50 = float(m.get_string(7)) / 100.0, r8_art_p95 = float(m.get_string(8)) / 100.0,
				diff_p50 = float(m.get_string(10)), diff_p95 = float(m.get_string(11)),
				cells_mean = float(m.get_string(12)) / 100.0, cells_worst = float(m.get_string(13)) / 100.0,
			}, true)
			out[m.get_string(1)] = fight
			continue
		m = r4.search(line)
		if m != null:
			var fight: Dictionary = out.get(m.get_string(1), {})
			fight.merge({
				windups = int(m.get_string(2)), windups_in_view = int(m.get_string(3)),
				r4_proxies = int(m.get_string(5)), r4_art = int(m.get_string(6)), worst_ms = float(m.get_string(7)),
			}, true)
			out[m.get_string(1)] = fight
	return out


## Part B's windowed rows from what the acts measured, `{L1, L2, L3, L5, ...}`: each a `{state ("met", "missed" or "not measured"),
## text (one line for the log), ...the numbers}`.
##   `data`            look.json as read(): the slugs t1 (bands), t3 (hull widths), t5 (the jab's flash) and t8 (the own hull)
##   `l5_lines`        the LOOK-L5 lines the readability act printed
##   `outline_px`      look_outline_px; `fp_scale` look_outline_fp_scale; `tint_hue_deg` the hue of look_shadow_tint
static func final_rows(data: Dictionary, l5_lines: PackedStringArray, outline_px: float, fp_scale: float, tint_hue_deg: float) -> Dictionary:
	return {
		"L1": _row_l1(data.get("t3", {}), data.get("t8", {}), outline_px, fp_scale),
		"L2": _row_l2(data.get("t1", {}), tint_hue_deg),
		"L3": _row_l3(data.get("t5", {})),
		"L5": _row_l5(parse_l5(l5_lines)),
	}


## The final rows as log lines, `LOOK-FINAL <row> <state> <text>`.
static func final_lines(rows: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ["L1", "L2", "L3", "L5"]:
		var row: Dictionary = rows.get(id, {})
		out.append("LOOK-FINAL %s %s %s" % [id, String(row.get("state", "not measured")).to_upper(), row.get("text", "")])
	return out


static func _within(width: float, target: float) -> bool:
	return width >= 0.0 and absf(width - target) <= HULL_TOLERANCE_PX and width <= HULL_MAX_PX


static func _row_l1(t3: Dictionary, t8: Dictionary, outline_px: float, fp_scale: float) -> Dictionary:
	var widths := {}
	var measured := 0
	var misses := PackedStringArray()
	for distance: float in HULL_DISTANCES_M:
		var label := "d%s_m" % str(distance).replace(".", "_")
		var at := {}
		for family: String in HULL_FAMILIES:
			var key := "%s_%s_px1080" % [label, family]
			if not t3.has(key) or float(t3[key]) < 0.0:
				at[family] = null
				continue
			var width := float(t3[key])
			at[family] = width
			measured += 1
			if not _within(width, outline_px):
				misses.append("%s m %s %.2f" % [str(distance), family, width])
		widths["%s m" % str(distance)] = at
	var own := {}
	var own_target := outline_px * fp_scale
	var own_measured := 0
	for family: String in OWN_FAMILIES:
		var key := "guard_%s_px1080" % family
		if not t8.has(key) or float(t8[key]) < 0.0:
			own[family] = null
			continue
		var width := float(t8[key])
		own[family] = width
		own_measured += 1
		if not _within(width, own_target):
			misses.append("own %s %.2f" % [family, width])
	var state := "not measured"
	if measured > 0 or own_measured > 0:
		state = "met" if misses.is_empty() else "missed"
	var text := "hull width at 1080p, target %.2f px +-%.0f and at most %.1f (own body %.2f): %s; own %s; %s" % [
			outline_px, HULL_TOLERANCE_PX, HULL_MAX_PX, own_target, JSON.stringify(widths), JSON.stringify(own),
			("outside the bar: " + ", ".join(misses)) if not misses.is_empty() else "all inside"]
	return {state = state, text = text, target_px = outline_px, own_target_px = own_target, widths = widths, own = own,
			measured = measured + own_measured, misses = misses}


static func _row_l2(t1: Dictionary, tint_hue_deg: float) -> Dictionary:
	var lights := {}
	var met := true
	var any := false
	var parts := PackedStringArray()
	for light: String in ["front_lit", "back_lit"]:
		var count := int(t1.get("%s_jacket_bands" % light, -1))
		if count < 0:
			continue
		any = true
		var ratio := float(t1.get("%s_jacket_shadow_over_lit" % light, 1.0))
		var bands := parse_bands(String(t1.get("%s_jacket_luma_hue" % light, "")))
		var toward := false
		if bands.size() >= 2:
			toward = hue_gap(float(bands[0].hue), tint_hue_deg) < hue_gap(float(bands[bands.size() - 1].hue), tint_hue_deg)
		var ok := count >= BANDS_MIN and count <= BANDS_MAX and ratio >= SHADOW_OVER_LIT_MIN and toward
		lights[light] = {bands = count, shadow_over_lit = ratio, shadow_hue_toward_tint = toward, met = ok}
		parts.append("%s %d bands, shadow/lit %.2f, shadow hue %s the tint: %s" % [
				light, count, ratio, "toward" if toward else "not toward", "met" if ok else "missed"])
		# The plan's bar is the default (front-lit) view of C2; the back-lit one (the contre-jour case, M4-slice-gate.md gap 2) is reported.
		if light == "front_lit" and not ok:
			met = false
	var state := "not measured" if not any else ("met" if met else "missed")
	return {state = state, text = "jacket bands at 1 m (bar: %d-%d bands, shadow/lit at least %.1f, hue toward the tint; the front-lit view decides): %s" % [
			BANDS_MIN, BANDS_MAX, SHADOW_OVER_LIT_MIN, "; ".join(parts)], lights = lights}


static func _row_l3(t5: Dictionary) -> Dictionary:
	if not t5.has("jab_flash_white_share_of_view"):
		return {state = "not measured", text = "the jab's flash share was not measured"}
	var share := float(t5.get("jab_flash_white_share_of_view", 0.0))
	var landed: bool = t5.get("jab_flash_hit_landed", false)
	var bar := M2_JAB_FLASH_WHITE_SHARE + FLASH_MARGIN
	var ok := landed and share <= bar
	return {state = "met" if ok else "missed", white_share = share, bar = bar, m2_share = M2_JAB_FLASH_WHITE_SHARE, hit_landed = landed,
			text = "white share of the view on a jab at 1 m %.1f%%, bar M2's %.1f%% + %.0f points = %.1f%%%s" % [
					share * 100.0, M2_JAB_FLASH_WHITE_SHARE * 100.0, FLASH_MARGIN * 100.0, bar * 100.0, "" if landed else " (the jab did not land)"]}


static func _row_l5(fights: Dictionary) -> Dictionary:
	if fights.is_empty():
		return {state = "not measured", text = "no LOOK-L5 line was printed"}
	var met := true
	var parts := PackedStringArray()
	for label: String in fights:
		var f: Dictionary = fights[label]
		var r8 := f.has("diff_p50")
		var r4 := f.has("r4_art")
		var ok8 := r8 and absf(float(f.diff_p50)) <= L5_P50_POINTS and absf(float(f.diff_p95)) <= L5_P95_POINTS
		var ok4 := r4 and int(f.r4_art) <= int(f.r4_proxies)
		if not (ok8 and ok4):
			met = false
		parts.append("%s: R8 p50 proxies %.1f%% art %.1f%% (%+.1f points), p95 %.1f%% / %.1f%% (%+.1f); R4 hidden wind-ups proxies %d art %d of %d: %s" % [
				label, float(f.get("r8_proxies_p50", 0.0)) * 100.0, float(f.get("r8_art_p50", 0.0)) * 100.0, float(f.get("diff_p50", 0.0)),
				float(f.get("r8_proxies_p95", 0.0)) * 100.0, float(f.get("r8_art_p95", 0.0)) * 100.0, float(f.get("diff_p95", 0.0)),
				int(f.get("r4_proxies", 0)), int(f.get("r4_art", 0)), int(f.get("windups_in_view", 0)), "met" if ok8 and ok4 else "missed"])
	return {state = "met" if met else "missed", fights = fights,
			text = "R8 and R4 with the art drawn beside the proxies (bar: R8 within %.0f points at the median and %.0f at the 95th, no wind-up hidden that the proxies did not see hidden): %s" % [
					L5_P50_POINTS, L5_P95_POINTS, "; ".join(parts)]}


## Write `image` as `probe_<name>.png` beside the recording (or `--probe-out=<dir>`), for a look at what
## a metric measured. Returns the path, or "" when there is nowhere to write.
static func dump(image: Image, name: String, dir: String = "") -> String:
	var folder := dir if not dir.is_empty() else _capture_dir()
	if folder.is_empty() or image == null:
		return ""
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("probe_%s.png" % name)
	image.save_png(path)
	return path


static func _capture_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-out="):
			return arg.trim_prefix("--probe-out=")
	var movie := Engine.get_write_movie_path()
	if not movie.is_empty():
		return movie.get_base_dir()
	return ""


static func _inside(image: Image, at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height()
