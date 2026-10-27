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
##   shadow_ratio()        the darkest band's brightness over the lightest's (L3: at least 0.4)
##   white_share()         the share of near-white pixels (L5: the flash's share of the view)
##   changed_share()       the share of pixels two frames disagree on
##   mean_delta_e()        the mean CIE76 distance between two frames (the grade's shift)
##   record()              merge one measurement's values into look.json beside the recording

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
## The reference height pixels are reported at.
const REFERENCE_HEIGHT := 1080.0
const LOOK_JSON := "look.json"


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
