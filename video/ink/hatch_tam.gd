class_name CineHatchTam
extends RefCounted
## The hatching's tonal art map, made by code (PLAN.md Plan A part 2). One tileable 256x256 RGBA8 image whose
## four channels are four CUMULATIVE densities of pen strokes (value 1 = ink): R a few long diagonal strokes,
## G those and more, B the cross strokes on top, A a dense mesh. cine_toon.gdshader picks the channel by how
## deep in shadow a surface is, so a darker patch gets more strokes and the strokes of a lighter patch are
## kept (the property of a tonal art map). Every stroke is irregular: it has its own length, gap, wobble and
## taper from a hash of its line, so it never reads as a ruler's rule. The image tiles because every period
## divides the size.

const SIZE := 256
## The spacing of the strokes (pixels, dividing SIZE) of the four levels, and their widths (pixels).
const SPACING := [32, 16, 16, 8]
const WIDTH := [1.6, 1.5, 1.4, 1.3]
## The share of a stroke line that is drawn (the rest is its gap).
const DASH := [0.62, 0.7, 0.62, 0.7]


static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## The image of the four densities.
static func build() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cover := PackedFloat32Array()
	cover.resize(SIZE * SIZE * 4)
	# Levels 0 and 1 stroke along u = x + y; level 2 adds the cross along w = x - y; level 3 a denser u.
	_strokes(cover, 0, SPACING[0], WIDTH[0], DASH[0], false, 11)
	_strokes(cover, 1, SPACING[1], WIDTH[1], DASH[1], false, 23)
	_strokes(cover, 2, SPACING[2], WIDTH[2], DASH[2], true, 37)
	_strokes(cover, 3, SPACING[3], WIDTH[3], DASH[3], false, 51)
	# Cumulative: each level contains the one before it.
	for i in SIZE * SIZE:
		var c0 := cover[i * 4]
		var c1 := maxf(c0, cover[i * 4 + 1])
		var c2 := maxf(c1, cover[i * 4 + 2])
		var c3 := maxf(c2, cover[i * 4 + 3])
		cover[i * 4] = c0
		cover[i * 4 + 1] = c1
		cover[i * 4 + 2] = c2
		cover[i * 4 + 3] = c3
	for y in SIZE:
		for x in SIZE:
			var i := (y * SIZE + x) * 4
			image.set_pixel(x, y, Color(cover[i], cover[i + 1], cover[i + 2], cover[i + 3]))
	return image


## Draw one level's strokes into channel `channel` of `cover`. A stroke line runs along the diagonal; its
## index is the line's cell, its dashes come from the hash of that index.
static func _strokes(cover: PackedFloat32Array, channel: int, spacing: int, width: float, dash: float,
		cross: bool, seed_value: int) -> void:
	var lines := SIZE / spacing
	for y in SIZE:
		for x in SIZE:
			# Position across the lines (u) and along them (v); the wobble bends u by a periodic sine.
			var u := float(x + y) if not cross else float(x - y + SIZE)
			var v := float(x - y + SIZE) if not cross else float(x + y)
			var line_index := int(floorf(u / float(spacing)))
			var line_hash := _hash(line_index % (lines * 2) + seed_value, seed_value)
			var wob := sin(v * TAU / float(SIZE) * 3.0 + line_hash * TAU) * 0.9
			var across := fmod(u + wob + float(SIZE) * 4.0, float(spacing))
			var d := absf(across - float(spacing) * 0.5)
			# The dash: along the line, a segment starting at a hashed offset, with a hashed length.
			var period := float(SIZE) * 0.5
			var along := fmod(v + line_hash * period, period) / period
			var length := clampf(dash + (_hash(line_index + 7, seed_value) - 0.5) * 0.3, 0.2, 0.95)
			if along > length:
				continue
			# A taper at both ends of the stroke.
			var taper := clampf(minf(along, length - along) / 0.12, 0.0, 1.0)
			var half := width * 0.5 * (0.4 + 0.6 * taper)
			var ink := clampf((half - d) / 0.8 + 0.5, 0.0, 1.0)
			var i := (y * SIZE + x) * 4 + channel
			cover[i] = maxf(cover[i], ink)


## The texture (cached per process), mipmapped for the shader's trilinear read.
static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture == null:
		var image := build()
		image.generate_mipmaps()
		_texture = ImageTexture.create_from_image(image)
	return _texture
