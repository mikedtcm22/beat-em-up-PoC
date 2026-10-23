class_name VfxArt
extends RefCounted
## The comic effect set (Spec §10, "2D effects"): PNGs in assets/export/fx/, drawn as SVG
## by tools/gen_fx.gd into assets/source/fx/ and logged in ASSETS.md. Loaded on first use
## and cached.

const DIR := "res://assets/export/fx/"
## Burst textures per hit tier (CombatTypes.HitTier order: light, heavy, finisher).
const BURSTS: Array[StringName] = [&"burst_small", &"burst_medium", &"burst_large"]
const BLOOD_SPLATS: Array[StringName] = [&"blood_splat_1", &"blood_splat_2", &"blood_splat_3"]
## The speed-line sheet holds this many streaks, one per row, thick end left.
const SPEED_LINE_ROWS := 4

static var _cache: Dictionary[StringName, Texture2D] = {}


## The effect texture `name` (a file name in DIR without ".png"), or null if missing.
static func texture(name: StringName) -> Texture2D:
	if not _cache.has(name):
		var path := DIR + name + ".png"
		_cache[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[name]


## The lettering texture for `word` ("KRAK" -> word_krak.png).
static func word_texture(word: String) -> Texture2D:
	return texture(StringName("word_" + word.to_lower()))


## True when every texture this module uses exists (tests).
static func has(name: StringName) -> bool:
	return ResourceLoader.exists(DIR + name + ".png")
