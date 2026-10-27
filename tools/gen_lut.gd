extends SceneTree
## Writes the grade LUT of Milestone 4 (M4-plan Part A A8's "Grade", the look bible's "street_dusk"):
## assets/export/look/grade_lut.png, from the recipe in assets/source/look/grade.json.
##
##   godot --headless --import --quit && godot --headless -s tools/gen_lut.gd --quit-after 5 \
##       && godot --headless --import --quit
##
## The LUT is a strip of N slices of N x N pixels (N = the recipe's "size"): slice b holds the blue
## node b, x the red node and y the green node, and a pixel is the graded color of its node's
## input (`node_value()`). The identity LUT is the ramp of `node_value()`s. game/fx/look_post.gd reads the
## strip into an ImageTexture3D for Environment.adjustment_color_correction, which is applied to
## the picture after tonemapping, so every number here is in sRGB.
##
## The grade (`grade()`): a luma-weighted tint (cool in the shadows, warm in the highlights, both
## multiplicative, so black stays black and white stays white) and a saturation factor, both by the color's own HSV
## saturation: below `chroma_low` the color takes the whole tint and is pulled toward its grey by
## `low_chroma_saturation`; above `chroma_high` (the enemies and the blood) it takes only
## `saturated_tint_share` of the tint and keeps its saturation; smoothly between. The recipe's
## `keep_delta_e` is what a saturated color may move (CIE76, `delta_e76()`); tests/test_look_post.gd
## holds the project's palette to it.
##
## GUT calls the static functions; the script itself needs no autoload.

const RECIPE_PATH := "res://assets/source/look/grade.json"
const LUT_PATH := "res://assets/export/look/grade_lut.png"
## The D65 white point's XYZ (CIE76 in CIELAB).
const WHITE_XYZ := Vector3(0.95047, 1.0, 1.08883)


func _initialize() -> void:
	var recipe := load_recipe()
	if recipe.is_empty():
		printerr("Could not read %s" % RECIPE_PATH)
		quit(1)
		return
	var image := build_strip(recipe)
	var err := image.save_png(LUT_PATH)
	if err != OK:
		printerr("Could not write %s: %s" % [LUT_PATH, error_string(err)])
		quit(1)
		return
	print("Wrote %s (%dx%d, %s)" % [LUT_PATH, image.get_width(), image.get_height(), recipe.get("name", "?")])
	quit(0)


## The recipe's dictionary (empty if the file is missing or not a JSON object).
static func load_recipe() -> Dictionary:
	var file := FileAccess.open(RECIPE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## The strip image: N slices of N x N pixels (RGB8), the `recipe`'s grade of every node.
static func build_strip(recipe: Dictionary) -> Image:
	var n := int(recipe.size)
	var image := Image.create(n * n, n, false, Image.FORMAT_RGB8)
	for b in n:
		for y in n:
			for x in n:
				var node := Color(node_value(x, n), node_value(y, n), node_value(b, n))
				var graded := grade(node, recipe)
				image.set_pixel(b * n + x, y, graded)
	return image


## The color value LUT node `i` of `n` holds the grade of. The renderer samples the 3D texture at
## the picture's color itself, so node i sits at (i + 0.5) / n, not i / (n - 1); the first and last
## nodes hold black and white, so those stay (a node at 0.5 / n would lift black by 1.5%).
static func node_value(i: int, n: int) -> float:
	if i <= 0:
		return 0.0
	if i >= n - 1:
		return 1.0
	return (float(i) + 0.5) / float(n)


## The grade of one sRGB color (alpha passes through).
static func grade(color: Color, recipe: Dictionary) -> Color:
	var rgb := Vector3(color.r, color.g, color.b)
	var luma := rgb.dot(Vector3(0.2126, 0.7152, 0.0722))
	var shadow_weight := 1.0 - smoothstep(0.0, float(recipe.shadow_end_luma), luma)
	var highlight_weight := smoothstep(float(recipe.highlight_start_luma), 1.0, luma) \
			* (1.0 - smoothstep(float(recipe.white_keep_luma), 1.0, luma))
	var peak := maxf(rgb.x, maxf(rgb.y, rgb.z))
	var low := minf(rgb.x, minf(rgb.y, rgb.z))
	var saturation := 0.0 if peak <= 0.0 else (peak - low) / peak
	var keep := smoothstep(float(recipe.chroma_low), float(recipe.chroma_high), saturation)
	var tint_share := lerpf(1.0, float(recipe.saturated_tint_share), keep)
	rgb *= Vector3.ONE.lerp(_vec(recipe.shadow_tint), float(recipe.shadow_amount) * shadow_weight * tint_share)
	rgb *= Vector3.ONE.lerp(_vec(recipe.highlight_tint), float(recipe.highlight_amount) * highlight_weight * tint_share)
	var factor := lerpf(float(recipe.low_chroma_saturation), 1.0, keep)
	var grey := rgb.dot(Vector3(0.2126, 0.7152, 0.0722))
	rgb = Vector3(grey, grey, grey).lerp(rgb, factor)
	return Color(clampf(rgb.x, 0.0, 1.0), clampf(rgb.y, 0.0, 1.0), clampf(rgb.z, 0.0, 1.0), color.a)


## CIE76 distance between two sRGB colors.
static func delta_e76(a: Color, b: Color) -> float:
	return lab(a).distance_to(lab(b))


## The CIELAB (D65) of an sRGB color, as (L, a, b).
static func lab(color: Color) -> Vector3:
	var lin := color.srgb_to_linear()
	var x := 0.4124564 * lin.r + 0.3575761 * lin.g + 0.1804375 * lin.b
	var y := 0.2126729 * lin.r + 0.7151522 * lin.g + 0.0721750 * lin.b
	var z := 0.0193339 * lin.r + 0.1191920 * lin.g + 0.9503041 * lin.b
	var fx := _lab_f(x / WHITE_XYZ.x)
	var fy := _lab_f(y / WHITE_XYZ.y)
	var fz := _lab_f(z / WHITE_XYZ.z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lab_f(t: float) -> float:
	var delta := 6.0 / 29.0
	if t > delta * delta * delta:
		return pow(t, 1.0 / 3.0)
	return t / (3.0 * delta * delta) + 4.0 / 29.0


static func _vec(value: Variant) -> Vector3:
	var a: Array = value
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
