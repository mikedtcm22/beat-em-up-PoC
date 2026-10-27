class_name VfxArt
extends RefCounted
## The comic effect set (Spec §10, "2D effects"): PNGs in assets/export/fx/, drawn as SVG
## by tools/gen_fx.gd into assets/source/fx/ and logged in ASSETS.md. Every texture is held
## here once loaded, for the whole run: ResourceLoader's cache holds no reference of its
## own, so a texture only drawn (a canvas draw call keeps just its RID) would be freed after
## the frame and reloaded from disk on the next use. VfxDirector loads the whole set when it
## is created (preload_all()), so no hit frame reads a file.

const DIR := "res://assets/export/fx/"
## Burst textures per hit tier (CombatTypes.HitTier order: light, heavy, finisher): the first of each
## tier's variants, and the name an effect of that tier goes by (ComicSprite.kind), whichever
## variant it shows.
const BURSTS: Array[StringName] = [&"burst_small", &"burst_medium", &"burst_large"]
## Every tier's burst variants, in the same order (tools/gen_fx.gd draws two of each). VfxDirector
## never shows one variant twice running.
const BURST_VARIANTS: Array[Array] = [
	[&"burst_small", &"burst_small_2"],
	[&"burst_medium", &"burst_medium_2"],
	[&"burst_large", &"burst_large_2"],
]
const BLOOD_SPLATS: Array[StringName] = [&"blood_splat_1", &"blood_splat_2", &"blood_splat_3"]
## The speed-line sheet holds this many streaks, one per row, thick end left.
const SPEED_LINE_ROWS := 4

## Name -> texture, kept alive for the run (null for a name with no PNG).
static var _held: Dictionary[StringName, Texture2D] = {}
## The damage look's "nothing" (clear_detail()).
static var _clear_detail: Texture2D


## The effect texture `name` (a file name in DIR without ".png"), or null if missing.
static func texture(name: StringName) -> Texture2D:
	if _held.has(name):
		return _held[name]
	var path := DIR + name + ".png"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_held[name] = tex
	return tex


## A 1x1 fully transparent texture, made once and held for the run: a detail layer showing
## nothing, which stands for a clean look in DamageLook (the layer never switches off).
static func clear_detail() -> Texture2D:
	if _clear_detail == null:
		var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.0, 0.0, 0.0, 0.0))
		_clear_detail = ImageTexture.create_from_image(image)
	return _clear_detail


## How many burst variants `tier` (a CombatTypes.HitTier) has.
static func burst_variant_count(tier: int) -> int:
	return BURST_VARIANTS[tier].size()


## The texture of `tier`'s burst variant `variant` (wrapped into range), or null if missing.
static func burst_texture(tier: int, variant: int = 0) -> Texture2D:
	var names: Array = BURST_VARIANTS[tier]
	return texture(names[posmod(variant, names.size())])


## The lettering texture for `word` ("KRAK" -> word_krak.png).
static func word_texture(word: String) -> Texture2D:
	return texture(StringName("word_" + word.to_lower()))


## Load and hold every PNG in DIR now. Returns how many are held.
static func preload_all() -> int:
	for file: String in ResourceLoader.list_directory(DIR):
		if file.get_extension() == "png":
			texture(StringName(file.get_basename()))
	return held_count()


## How many textures are held (tests).
static func held_count() -> int:
	return _held.values().filter(func(t: Texture2D) -> bool: return t != null).size()


## True when every texture this module uses exists (tests).
static func has(name: StringName) -> bool:
	return ResourceLoader.exists(DIR + name + ".png")
