extends SceneTree
## Writes the placeholder painted maps of the M7 T11 fixture (tests/fixtures/m7/painted_paint.png and painted_ink.png), the
## contract of docs/ARCHITECTURE.md "The painted material (M7)" at 512 px (shipped art is 2048): no art, only values a test can
## read back. Run: godot --headless -s tests/fixtures/m7/gen_painted_fixture.gd
##   paint.png RGB: a flat grey with a darker diagonal band (a drawn shadow shape) and a warm band across the top fifth.
##   ink.png R: a grid of lines every 64 px, 3 px wide; G: the damage class by quarter of U (clothes 255, clothes without blood
##   230, skin 204, none 128); B: gloss, 255 on the strip 0.50 to 0.62 of U, 0 elsewhere; A: the hull weight hint, a sine
##   along V (0.1 at the ends, 1.0 in the middle, seams match because it depends on V alone).
const SIZE := 512
const DIR := "res://tests/fixtures/m7/"
const CLASSES: Array[float] = [255.0, 230.0, 204.0, 128.0]


func _initialize() -> void:
	var paint := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var ink := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var color := Color(0.62, 0.6, 0.57)
			if fposmod(u + v, 0.5) < 0.12:
				color = Color(0.42, 0.4, 0.4)
			if v < 0.2:
				color = Color(0.78, 0.5, 0.3)
			paint.set_pixel(x, y, color)
			var line := 1.0 if (x % 64 < 3 or y % 64 < 3) else 0.0
			var klass: float = CLASSES[mini(int(u * 4.0), 3)] / 255.0
			var gloss := 1.0 if (u >= 0.5 and u < 0.62) else 0.0
			var weight := 0.1 + 0.9 * sin(v * PI)
			ink.set_pixel(x, y, Color(line, klass, gloss, weight))
	paint.save_png(DIR + "painted_paint.png")
	ink.save_png(DIR + "painted_ink.png")
	print("Wrote the painted fixture maps in ", DIR)
	quit()
