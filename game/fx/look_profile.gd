class_name LookProfile
extends RefCounted
## The look profile (Milestone 7, T05a): which look the presentation draws, "m6" (Milestone 6's, the
## default) or "trailer". Tuning's `look_profile` picks it; the presentation code that builds a look
## (LookPost, ToonMaterials, LevelRoot's light blend) asks here for the profile's resources, which
## live as data in game/fx/look_profiles/ (LookProfileData). Presentation only: simulation code never
## reads it (tests/test_look_profile.gd scans for that).

## The profiles, in `look_profile`'s order.
enum Id { M6, TRAILER }

const DIR := "res://game/fx/look_profiles/"
## Each profile's file name (without ".tres"), by Id.
const NAMES: Array[StringName] = [&"m6", &"trailer"]

## Each profile's data once loaded, by Id. Held here because nothing else keeps it: `load` read the file (and the trailer's
## look rows) from disk again on every call, several times a physics tick from LevelRoot's light (M7 T55: ~0.25 ms a tick
## under m6, ~1.4 ms under the trailer).
static var _loaded: Array[LookProfileData] = []


## The running profile's Id (Tuning's `look_profile`, kept in range).
static func current() -> int:
	return clampi(Tuning.data.look_profile, 0, NAMES.size() - 1)


## The running profile's name, or that of `id`.
static func profile_name(id: int = -1) -> StringName:
	return NAMES[current() if id < 0 else clampi(id, 0, NAMES.size() - 1)]


## The data of the running profile, or of `id` (a missing file gives M6's defaults).
static func data(id: int = -1) -> LookProfileData:
	var index := current() if id < 0 else clampi(id, 0, NAMES.size() - 1)
	if _loaded.size() != NAMES.size():
		_loaded.resize(NAMES.size())
	if _loaded[index] == null:
		var path := DIR + String(NAMES[index]) + ".tres"
		_loaded[index] = load(path) as LookProfileData if ResourceLoader.exists(path) else null
	return _loaded[index] if _loaded[index] != null else LookProfileData.new()


## Switch to the next profile, live (the F7 key): Tuning announces it, so the post pass, the materials
## and the level's light follow at once, with no reload. Returns the new Id.
static func cycle() -> int:
	var next := (current() + 1) % NAMES.size()
	Tuning.set_value(&"look_profile", next)
	return next


## `light` (LevelSection.light()'s shape) with the running profile's overrides on it. The very same
## dictionary when the profile overrides nothing.
static func resolve_light(light: Dictionary) -> Dictionary:
	var overrides := data().light_overrides
	if overrides.is_empty():
		return light
	var out := light.duplicate()
	for key: Variant in overrides:
		out[key] = overrides[key]
	return out


## The grade LUT's path.
static func grade_lut_path() -> String:
	return data().grade_lut_path


## Whether the Environment may glow.
static func bloom_allowed() -> bool:
	return data().bloom_allowed


## The multiplier on the ink widths.
static func ink_width_scale() -> float:
	return data().ink_width_scale


## The folder of the comic effect textures. (Not wired to VfxArt yet: a later task's.)
static func vfx_art_dir() -> String:
	return data().vfx_art_dir


## The HUD's style set. (Not wired to HudStyle yet: a later task's.)
static func hud_style() -> StringName:
	return data().hud_style
