class_name ToonMaterials
extends RefCounted
## The one place a surface's material is made (Milestone 4): characters, the skinned art,
## props, the room's boxes and floor grid, and the inverted-hull outlines (docs/ARCHITECTURE.md
## "Toon shader, hull, flash and damage on toon"). Every lit surface of the game is the one
## toon shader (game/fx/toon.gdshader, lighting in toon_light.gdshaderinc; the floor grid's
## grid.gdshader includes the same lighting), so a look, a flash or a damage mark is a uniform
## and never a new shader variant. Their values come from Tuning's Look group (the Toon and
## Outline subgroups): every material made here is tracked weakly and takes the Look values
## again on `Tuning.changed`, so the F1 panel's sliders move the whole game live.
##
## Hulls: the outline of a placeholder or a prop goes on the mesh's `material_overlay` (the
## contact flash keeps `next_pass`), made here per shape; a box that is part of a room has it
## on the material's own `next_pass` (environment(color, true)), since a room's boxes have no
## overlay slot of their own at the call sites. Whether a placeholder has a hull is
## Tuning's `look_hull_on_placeholders`, read when the thing is built.

## The one ink: the hull, the detail lines, the HUD's borders.
const INK := HudStyle.INK
const TOON_SHADER := preload("res://game/fx/toon.gdshader")
const OUTLINE_SHADER := preload("res://game/fx/toon_outline.gdshader")
const GRID_SHADER := "res://game/level/grid.gdshader"
const TRIM_SHADER := "res://game/fx/trim.gdshader"
## The trim material's alpha-scissor variant, for the chain-link's wire alone (see trim.gdshader).
const TRIM_SCISSOR_SHADER := "res://game/fx/trim_scissor.gdshader"
## The painted character material and its hull (M7, T11): the trailer profile's surface language.
const PAINTED_SHADER := preload("res://game/fx/toon_painted.gdshader")
const PAINTED_OUTLINE_SHADER := preload("res://game/fx/toon_outline_painted.gdshader")
## A CharacterArt's painted maps (metadata/paint_tex and metadata/ink_tex in the .tres, like detail_sharp): the paint map (RGB the flat
## local colour with the shadow shapes drawn in) and the ink map (R line, G damage class, B gloss, A hull weight hint), both on UV2.
## An art that carries both is painted (is_painted()); the contract is docs/ARCHITECTURE.md "The painted material (M7)".
const PAINT_META := &"paint_tex"
const INK_META := &"ink_tex"
## What a ShaderMaterial made here is, for which Look values it takes (see apply_look()).
enum Kind { CHARACTER, ART, PROP, ENVIRONMENT, GRID, HULL, ART_PROP, TRIM, PAINTED }
## How the hull pushes a mesh out (toon_outline.gdshader's `mode`): along the normal
## (spheres, capsules), by sign(VERTEX) per axis (boxes), radially plus sign(y) (cylinders),
## from the sphere's centre (a hemisphere's open rim), by the skinned art's baked smooth normal.
enum Hull { NORMAL, BOX, CYLINDER, RADIAL, ART }

## The damage class an ink map's G byte names (the palette atlas's alpha classes: 255, 230, 204, 128).
enum PaintClass { NONE, SKIN, CLOTHES_NO_BLOOD, CLOTHES }

const _PAINTED_HULL_META := &"toon_painted_hull"
const _KIND_META := &"toon_kind"
const _GLOSSY_META := &"toon_glossy"
const _FP_META := &"toon_fp"
const _SHARP_META := &"toon_sharp_detail"
const _WARM_NAME := "ToonWarmUp"
## The static prop the warm-up draws once so StaticArt's pipeline is built at load (smallest of the four).
const WARM_PROP := "res://game/level/props/ac_unit.tscn"
## Where the warm-up's holder stands from the camera: this far ahead and this far below it, so
## a body drawn on it (feet at the holder) is in view.
const WARM_DISTANCE_M := 2.5
const WARM_DROP_M := 1.2
## The registry is swept of dead materials whenever it has grown past this many (and the bar
## doubles from what is left), so a long session of spawns never lets it grow unbounded.
const _SWEEP_AT := 256

## The materials made so far (weak: a rig's own die with it), the shared hulls by mode and
## first-person flag, and whether Tuning.changed is wired.
static var _live: Array[WeakRef] = []
static var _sweep_bar: int = _SWEEP_AT
static var _hulls: Dictionary[int, ShaderMaterial] = {}
static var _wired: bool = false
## The warm-up has run this run (warm_up()), and whether its skinned variant has (the first
## rig of a room is the player's, which has no art of its own, so the variant is asked for
## separately, by the room's load).
static var _warmed: bool = false
static var _art_warmed: bool = false
## The painted hulls, one per ink map and first-person flag (outline_painted()), and the area's own shadow hue and rim colour
## (set_area_look(); unset: the Tuning defaults).
static var _painted_hulls: Dictionary[int, ShaderMaterial] = {}
static var _area_look_set: bool = false
static var _area_shadow_hue: Color = Color.WHITE
static var _area_rim_color: Color = Color.WHITE
## The one trim material (trim()).
static var _trim: ShaderMaterial
static var _trim_scissor: ShaderMaterial


## A character's flat-colored toon material: `color` is the paint, `takes_marks` whether the
## damage look marks it (skin and clothes, not shades, belts and soles) and `glossy` whether
## it takes the hard highlight, at the glossy factor (shades, belt, soles, hair, gloves: the
## rig's dark paint). A paint that is not glossy is matte and takes none, as the art's matte
## swatches take none. Rim on, hull-tagged for the edge pass when placeholders get hulls.
static func character(color: Color, takes_marks: bool = false, glossy: bool = false) -> ShaderMaterial:
	var material := _make(Kind.CHARACTER, glossy)
	material.set_shader_parameter(&"albedo", color)
	material.set_shader_parameter(&"marks", 1.0 if takes_marks else 0.0)
	material.set_shader_parameter(&"damage_tex", VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", 1.0 / maxf(Tuning.data.vfx_damage_tile_m, 0.01))
	material.set_shader_parameter(&"edge_tag", 0.0 if Tuning.data.look_hull_on_placeholders else 1.0)
	return _track(material)


## The skinned art's material: the palette `atlas` (and the player's `detail` mask on UV2 when
## given). Damage marks come from the rest pose (CUSTOM0/1) and the atlas's alpha; the hull's
## edge tag is 0 (the art always has its hull). `sharp_detail`: the mask's ink is cut at
## `look_detail_cut` with an antialiased edge instead of mixed in by its filtered value (both
## characters' art ask for it: the hero's lines are magnified to several pixels at 0.2 to 0.4 m,
## the Punk's to two at 1 m); false is the soft linear mix. The hard highlight is per swatch: it
## takes `look_spec_gloss` on a glossy swatch of the atlas (the Punk's lens) and nothing on a
## matte one, so the material is the glossy kind and toon.gdshader's `swatch_spec` does the rest.
static func art(atlas: Texture2D, detail: Texture2D = null, sharp_detail: bool = false) -> ShaderMaterial:
	var material := _make(Kind.ART, true)
	material.set_meta(_SHARP_META, sharp_detail)
	material.set_shader_parameter(&"albedo", Color.WHITE)
	material.set_shader_parameter(&"albedo_tex", atlas)
	material.set_shader_parameter(&"use_albedo_tex", atlas != null)
	if detail != null:
		material.set_shader_parameter(&"detail_tex", detail)
		material.set_shader_parameter(&"use_detail_tex", true)
	material.set_shader_parameter(&"ink", INK)
	material.set_shader_parameter(&"use_rest_custom", true)
	material.set_shader_parameter(&"marks", 1.0)
	material.set_shader_parameter(&"damage_tex", VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", 1.0 / maxf(Tuning.data.vfx_damage_tile_m, 0.01))
	material.set_shader_parameter(&"edge_tag", 0.0)
	return _track(material)


## A static art prop's material (M6, StaticArt): the palette `atlas` read per swatch like the skinned art's, with no
## skin, no damage marks, no rim and no fill (the sun lights it like the room), and `tint` multiplying the swatches (a weapon
## on the floor takes the floor colour). The hard highlight and the glint land on the atlas's glossy swatches only. Its hull is
## outline(): the baked smooth normal in COLOR, read from the rest normal StaticArt puts in CUSTOM1.
static func art_prop(atlas: Texture2D, tint: Color = Color.WHITE) -> ShaderMaterial:
	var material := _make(Kind.ART_PROP, true)
	material.set_shader_parameter(&"albedo", tint)
	material.set_shader_parameter(&"albedo_tex", atlas)
	material.set_shader_parameter(&"use_albedo_tex", atlas != null)
	material.set_shader_parameter(&"ink", INK)
	material.set_shader_parameter(&"edge_tag", 0.0)
	return _track(material)


## Whether `art` is painted (M7): it carries both a paint map and an ink map (metadata/paint_tex, metadata/ink_tex).
static func is_painted(art: CharacterArt) -> bool:
	return art != null and art.has_meta(PAINT_META) and art.has_meta(INK_META) \
			and art.get_meta(PAINT_META) is Texture2D and art.get_meta(INK_META) is Texture2D


## The skinned art's material for `art`: the painted one when the art is painted (painted()), else art() with its palette, detail
## mask and sharp-ink flag, as RigPaint always made it.
static func art_for(art: CharacterArt) -> ShaderMaterial:
	if is_painted(art):
		return painted(art.get_meta(PAINT_META) as Texture2D, art.get_meta(INK_META) as Texture2D)
	return ToonMaterials.art(art.palette, art.detail_mask, bool(art.get_meta(&"detail_sharp", false)))


## The hull for `art`'s `material_overlay`: the painted hull of its ink map when painted, else the shared outline().
static func outline_for_art(art: CharacterArt, first_person: bool = false) -> ShaderMaterial:
	if is_painted(art):
		return outline_painted(art.get_meta(INK_META) as Texture2D, first_person)
	return outline(first_person)


## The painted character material (M7, toon_painted.gdshader): the `paint` map (RGB, UV2) and the `ink` map (UV2: R line, G damage
## class, B gloss, A hull weight hint), lit in two flat tones with the area's shadow hue and a one-sided rim. `tint` multiplies the
## paint (a palette swap). Damage marks, the flash and the edge tag are the art's own uniforms, so DamageLook and RigPaint treat it
## as they treat art(); the hull is outline_painted().
static func painted(paint: Texture2D, ink_map: Texture2D, tint: Color = Color.WHITE) -> ShaderMaterial:
	var material := _make(Kind.PAINTED, true, PAINTED_SHADER)
	material.set_shader_parameter(&"albedo", tint)
	material.set_shader_parameter(&"paint_tex", paint)
	material.set_shader_parameter(&"ink_tex", ink_map)
	material.set_shader_parameter(&"ink", INK)
	material.set_shader_parameter(&"use_rest_custom", true)
	material.set_shader_parameter(&"marks", 1.0)
	material.set_shader_parameter(&"damage_tex", VfxArt.clear_detail())
	material.set_shader_parameter(&"damage_scale", 1.0 / maxf(Tuning.data.vfx_damage_tile_m, 0.01))
	material.set_shader_parameter(&"edge_tag", 0.0)
	return _track(material)


## The painted hull for `ink_map`'s art (toon_outline_painted.gdshader): the ink map's A is its line weight. One per map and flag.
static func outline_painted(ink_map: Texture2D, first_person: bool = false) -> ShaderMaterial:
	var key := ink_map.get_instance_id() * 2 + (1 if first_person else 0)
	var hull := _painted_hulls.get(key) as ShaderMaterial
	if hull == null:
		hull = ShaderMaterial.new()
		hull.shader = PAINTED_OUTLINE_SHADER
		hull.set_meta(_KIND_META, Kind.HULL)
		hull.set_meta(_FP_META, first_person)
		hull.set_meta(_PAINTED_HULL_META, true)
		hull.set_shader_parameter(&"ink", INK)
		hull.set_shader_parameter(&"ink_tex", ink_map)
		_painted_hulls[key] = hull
		_track(hull)
	return hull


## Give the painted materials the AREA's colours (T10's light code calls it when the area's light is applied): the hue of the shadow
## tone and the warm colour of the rim. Until it is called, and after clear_area_look(), the Tuning defaults
## (look_paint_shadow_hue, look_paint_rim_color) apply.
static func set_area_look(shadow_hue: Color, rim_color: Color) -> void:
	_area_look_set = true
	_area_shadow_hue = shadow_hue
	_area_rim_color = rim_color
	_apply_all()


## Back to the Tuning defaults for the painted materials' hue and rim.
static func clear_area_look() -> void:
	_area_look_set = false
	_apply_all()


## The hull of the skinned art, for its `material_overlay`: the baked smooth normal, carried
## through the skin. `first_person`: the player's own body, drawn at look_outline_fp_scale (the
## bible's x0.8 of a character's line) and faded out near the lens, like the primitives' hull
## outline_for_part() gives it. One shared material per flag.
static func outline(first_person: bool = false) -> ShaderMaterial:
	return _hull(Hull.ART, first_person)


## The hull of a primitive of `shape` (PlaceholderBody.Shape) for its `material_overlay`, or
## null when placeholders get no hull (`look_hull_on_placeholders`). `first_person`: the
## player's own body, drawn thinner (look_outline_fp_scale). Shared per shape and flag.
static func outline_for_part(shape: PlaceholderBody.Shape, first_person: bool = false) -> ShaderMaterial:
	if not Tuning.data.look_hull_on_placeholders:
		return null
	match shape:
		PlaceholderBody.Shape.BOX:
			return _hull(Hull.BOX, first_person)
		PlaceholderBody.Shape.CYLINDER:
			return _hull(Hull.CYLINDER, first_person)
		PlaceholderBody.Shape.DOME:
			return _hull(Hull.RADIAL, first_person)
	return _hull(Hull.NORMAL, first_person)


## A prop's material (the pipe): `color`, glossy, no rim.
static func prop(color: Color) -> ShaderMaterial:
	var material := _make(Kind.PROP, true)
	material.set_shader_parameter(&"albedo", color)
	material.set_shader_parameter(&"edge_tag", 0.0 if Tuning.data.look_hull_on_placeholders else 1.0)
	return _track(material)


## The hull for a prop's `material_overlay` (the pipe is a cylinder), or null when
## placeholders get no hull.
static func outline_for_prop() -> ShaderMaterial:
	return outline_for_part(PlaceholderBody.Shape.CYLINDER)


## A flat-colored surface of the room (a wall, a crate, the street), matte, two bands.
## `hulled`: a prop box (a crate, a dumpster, a car) that gets the hull, drawn as the
## material's own next_pass, unless placeholders get none; its edge tag is then 0.
static func environment(color: Color, hulled: bool = false) -> ShaderMaterial:
	var material := _make(Kind.ENVIRONMENT, false)
	material.set_shader_parameter(&"albedo", color)
	var hull := _hull(Hull.BOX, false) if hulled else null
	if hull != null and Tuning.data.look_hull_on_placeholders:
		material.next_pass = hull
		material.set_shader_parameter(&"edge_tag", 0.0)
	return _track(material)


## The grey-box floor grid (the training room's and the street's): the grid shader, lit like
## the rest.
static func grid() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(GRID_SHADER)
	material.set_meta(_KIND_META, Kind.GRID)
	return _track(material)


## The environment kit's ONE material (Milestone 6, KIT; D10): the trim shader with the sheet and its
## strip table, shared by every module, dressing piece and barrier panel (the same object on every
## call, so the draw count follows the mesh count only). Lit like the room, two bands and matte; it
## keeps the flat `albedo` tint (white) a test can read, and takes the sheet's tiling and its ink cut
## from Tuning (kit_trim_m_per_tile, look_trim_ink_cut, look_trim_lod_cap).
static func trim() -> ShaderMaterial:
	if _trim == null:
		_trim = _trim_material(TRIM_SHADER)
	return _trim


## The trim material of the faces on the scissor strip (the chain-link's wire): `trim()` with the alpha scissor on.
## Kept apart because a shader that scissors loses the depth prepass and the cheap shadow pass for every mesh it
## draws, so only the faces that need it wear it (KitMesh makes a surface of them).
static func trim_scissor() -> ShaderMaterial:
	if _trim_scissor == null:
		_trim_scissor = _trim_material(TRIM_SCISSOR_SHADER)
	return _trim_scissor


static func _trim_material(shader_path: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	material.set_meta(_KIND_META, Kind.TRIM)
	material.set_shader_parameter(&"albedo", Color.WHITE)
	material.set_shader_parameter(&"trim_tex", TrimSheet.texture())
	material.set_shader_parameter(&"strips", TrimSheet.uniform_rows())
	material.set_shader_parameter(&"ground_tex", TrimSheet.ground_texture())
	material.set_shader_parameter(&"ink", INK)
	material.set_shader_parameter(&"edge_tag", 1.0)
	return _track(material)


## Take the current Look values (Tuning.data) on `material`, a material made here. Called when
## one is made and on every `Tuning.changed`.
static func apply_look(material: ShaderMaterial) -> void:
	var data := Tuning.data
	var kind: int = material.get_meta(_KIND_META, -1)
	if kind == Kind.HULL:
		material.set_shader_parameter(&"width_px", data.look_outline_px * LookProfile.ink_width_scale())
		material.set_shader_parameter(&"near_m", data.look_outline_near_m)
		material.set_shader_parameter(&"far_m", maxf(data.look_outline_far_m, data.look_outline_near_m + 0.1))
		material.set_shader_parameter(&"lens_fade_m", data.look_outline_lens_fade_m)
		material.set_shader_parameter(&"fp_scale", data.look_outline_fp_scale if material.get_meta(_FP_META, false) else 1.0)
		if material.get_meta(_PAINTED_HULL_META, false):
			material.set_shader_parameter(&"near_gain", data.look_paint_hull_near_gain)
			material.set_shader_parameter(&"boost_to_m", data.look_paint_hull_boost_to_m)
			material.set_shader_parameter(&"thin_from_m", data.look_paint_hull_thin_from_m)
			material.set_shader_parameter(&"far_gain", data.look_paint_hull_far_gain)
			material.set_shader_parameter(&"weight_min", data.look_paint_hull_weight_min)
			material.set_shader_parameter(&"weight_max", maxf(data.look_paint_hull_weight_max, data.look_paint_hull_weight_min))
			material.set_shader_parameter(&"weight_lod", data.look_paint_hull_weight_lod)
			material.set_shader_parameter(&"under_bias", data.look_paint_hull_under_bias)
		return
	if kind == Kind.PAINTED:
		_apply_painted(material, data)
		return
	var room_surface := kind == Kind.ENVIRONMENT or kind == Kind.GRID or kind == Kind.TRIM
	material.set_shader_parameter(&"band_1", data.look_band_1)
	material.set_shader_parameter(&"band_2", data.look_band_2)
	material.set_shader_parameter(&"band_soft", data.look_band_soft)
	# The room has two bands (lit and shadow): its mid band is as bright as the lit one.
	material.set_shader_parameter(&"mid_level", 1.0 if room_surface else data.look_mid_level)
	material.set_shader_parameter(&"shadow_level", data.look_shadow_level)
	material.set_shader_parameter(&"shadow_tint", data.look_shadow_tint)
	material.set_shader_parameter(&"shadow_tint_amount", data.look_shadow_tint_amount)
	material.set_shader_parameter(&"spec_cut", data.look_spec_cut)
	# The room is matte, and so is a placeholder paint that is not glossy: the same rule as the art's
	# matte swatches (toon.gdshader's swatch_spec), which take no hard highlight, so a flat-painted
	# helmet, knee or forearm shows no white dot beside the matte Punk. The glossy materials (the
	# glossy paints, the pipe, the art's glossy swatches) get the strength and the factor.
	var matte := room_surface or (kind == Kind.CHARACTER and not bool(material.get_meta(_GLOSSY_META, false)))
	material.set_shader_parameter(&"spec_strength", 0.0 if matte else data.look_spec_strength)
	material.set_shader_parameter(&"spec_gloss", data.look_spec_gloss if material.get_meta(_GLOSSY_META, false) else 1.0)
	# The rim is the characters' alone.
	var has_rim := kind == Kind.CHARACTER or kind == Kind.ART
	material.set_shader_parameter(&"rim_cut", data.look_rim_cut)
	material.set_shader_parameter(&"rim_power", data.look_rim_power)
	material.set_shader_parameter(&"rim_strength", data.look_rim_strength if has_rim else 0.0)
	# The fill is the characters' alone too: the room is lit by the sun.
	material.set_shader_parameter(&"fill_strength", data.look_fill_strength if has_rim else 0.0)
	material.set_shader_parameter(&"fill_dir", fill_direction(data.look_fill_yaw_deg, data.look_fill_pitch_deg))
	var dots := data.look_halftone_env if room_surface else data.look_halftone_chars
	material.set_shader_parameter(&"halftone_strength", data.look_halftone_strength if dots else 0.0)
	material.set_shader_parameter(&"halftone_cell_px", data.look_halftone_cell_px)
	if kind == Kind.TRIM:
		material.set_shader_parameter(&"tile_m", data.kit_trim_m_per_tile)
		material.set_shader_parameter(&"ink_cut", data.look_trim_ink_cut)
		material.set_shader_parameter(&"lod_cap", data.look_trim_lod_cap)
		material.set_shader_parameter(&"ground_m", data.ground_m_per_tile)
		material.set_shader_parameter(&"ground_on", not data.ground_sheet_off)
		material.set_shader_parameter(&"ink_soft", Vector3(data.ground_ink_soft_from_lod, data.ground_ink_soft_per_lod, data.ground_ink_soft_max))
		material.set_shader_parameter(&"ink_fade", Vector2(data.ground_ink_fade_start_texels, maxf(data.ground_ink_fade_end_texels, data.ground_ink_fade_start_texels + 1.0)))
		# The trailer profile's grain on the flat fills; under m6 the two uniforms are unset (null: the shader's own defaults), so
		# an m6 trim material has exactly the uniforms it had before.
		if LookProfile.current() == LookProfile.Id.TRAILER:
			material.set_shader_parameter(&"grain_amount", data.look_paint_trim_grain)
			material.set_shader_parameter(&"grain_cells", data.look_paint_trim_grain_cells)
		else:
			material.set_shader_parameter(&"grain_amount", null)
			material.set_shader_parameter(&"grain_cells", null)
	# The art's own: the glint on its glossy swatches, and the sharp ink of an art that asks for it
	# (only while the cut is above 0: 0 is the A/B).
	if kind == Kind.ART or kind == Kind.ART_PROP:
		material.set_shader_parameter(&"glint_cut", data.look_glint_cut)
		material.set_shader_parameter(&"glint_strength", data.look_glint_strength)
		material.set_shader_parameter(&"detail_sharp", bool(material.get_meta(_SHARP_META, false)) and data.look_detail_cut > 0.0)
		material.set_shader_parameter(&"detail_cut", data.look_detail_cut)
		# M6 DETAIL-2: the texel swatches of a mask that carries them (B above 0), the Bruiser's; the fade is in texels per pixel
		material.set_shader_parameter(&"use_texel_swatch", data.look_texel_swatch)
		material.set_shader_parameter(&"texel_swatch_fade", Vector2(data.look_texel_swatch_fade_near, maxf(data.look_texel_swatch_fade_far, data.look_texel_swatch_fade_near + 0.1)))


static func _apply_painted(material: ShaderMaterial, data: TuningData) -> void:
	material.set_shader_parameter(&"paint_cut", data.look_paint_cut)
	material.set_shader_parameter(&"paint_shadow_level", data.look_paint_shadow_level)
	material.set_shader_parameter(&"paint_shadow_hue", _area_shadow_hue if _area_look_set else data.look_paint_shadow_hue)
	material.set_shader_parameter(&"paint_shadow_hue_amount", data.look_paint_shadow_hue_amount)
	material.set_shader_parameter(&"term_soft", data.look_paint_term_soft_px)
	material.set_shader_parameter(&"dir_floor", data.look_paint_dir_floor)
	material.set_shader_parameter(&"point_gain", data.look_paint_point_gain)
	material.set_shader_parameter(&"fill_strength", data.look_paint_fill)
	material.set_shader_parameter(&"fill_dir", fill_direction(data.look_fill_yaw_deg, data.look_fill_pitch_deg))
	material.set_shader_parameter(&"paint_line_cut", data.look_paint_line_cut)
	material.set_shader_parameter(&"paint_line_strength", data.look_paint_line_strength)
	material.set_shader_parameter(&"paint_grain", data.look_paint_grain)
	material.set_shader_parameter(&"paint_grain_cells", data.look_paint_grain_cells)
	material.set_shader_parameter(&"paint_rim_color", _area_rim_color if _area_look_set else data.look_paint_rim_color)
	material.set_shader_parameter(&"paint_rim_strength", data.look_paint_rim_strength)
	material.set_shader_parameter(&"paint_rim_cut", data.look_paint_rim_cut)
	material.set_shader_parameter(&"paint_rim_key", data.look_paint_rim_key)
	material.set_shader_parameter(&"paint_rim_curve", data.look_paint_rim_curve)
	material.set_shader_parameter(&"band_soft", data.look_band_soft)
	material.set_shader_parameter(&"spec_cut", data.look_spec_cut)
	material.set_shader_parameter(&"spec_strength", data.look_spec_strength)
	material.set_shader_parameter(&"spec_gloss", data.look_spec_gloss)
	material.set_shader_parameter(&"glint_cut", data.look_glint_cut)
	material.set_shader_parameter(&"glint_strength", data.look_glint_strength)


## The damage class an ink map's G value `g` (0 to 1) names, as toon_painted.gdshader reads it: the palette atlas's alpha classes
## (255 clothes, 230 clothes without blood, 204 skin, 128 none) by the same 0.95, 0.85 and 0.75 cuts.
static func painted_class(g: float) -> PaintClass:
	if g > 0.95:
		return PaintClass.CLOTHES
	if g > 0.85:
		return PaintClass.CLOTHES_NO_BLOOD
	if g > 0.75:
		return PaintClass.SKIN
	return PaintClass.NONE


## Whether an ink map's B value `b` marks a glossy texel (at or above one half); the shader cuts the same value for the glint's gate.
static func painted_glossy(b: float) -> bool:
	return b >= 0.5


## The painted shade multiplier of a surface whose light is `lit`: the shadow tone below `cut` (`shadow_level` of the paint, pulled
## toward `hue` by `hue_amount`, luminance kept), 1 above, the edge smoothstepped over `edge`. toon_painted.gdshader's light().
static func painted_shade(lit: float, edge: float, cut: float, shadow_level: float, hue: Color, hue_amount: float) -> Color:
	var luma := maxf(hue.r * 0.2126 + hue.g * 0.7152 + hue.b * 0.0722, 0.001)
	var unit := Color(hue.r / luma, hue.g / luma, hue.b / luma)
	var shadow := Color.WHITE.lerp(unit, hue_amount) * shadow_level
	shadow.a = 1.0
	var out := shadow.lerp(Color.WHITE, smoothstep(cut - edge, cut + edge, lit))
	out.a = 1.0
	return out


## What a lamp (a point or spot light) adds to a painted surface, before the lamp's colour: only what rises above the shadow tone,
## so nothing at all inside the shadow band (`shade` is painted_shade() and `shadow` the same call at a light of 0).
static func painted_lamp_add(shade: Color, shadow: Color) -> Color:
	return Color(maxf(shade.r - shadow.r, 0.0), maxf(shade.g - shadow.g, 0.0), maxf(shade.b - shadow.b, 0.0), 1.0)


## The painted hull's width at `dist` metres from the lens, in metres, as toon_outline_painted.gdshader draws it: outline_width_m()
## times the distance gain (`near_gain` at `near_m`, 1 from `boost_to_m`, then thinning to `far_gain` between `thin_from_m` and
## `far_m`), the ink map's weight (`hint` 0 to 1, between `weight_min` and `weight_max`) and the weight under a form (`facing_down`
## 1 for a surface facing straight down, -1 up, times `under_bias`).
static func painted_hull_width_m(dist: float, px: float, proj11: float, viewport_h: float, near_m: float, far_m: float,
		lens_fade_m: float, fp_scale: float, near_gain: float, boost_to_m: float, thin_from_m: float, far_gain: float,
		hint: float, weight_min: float, weight_max: float, facing_down: float, under_bias: float) -> float:
	var gain := lerpf(near_gain, 1.0, smoothstep(near_m, boost_to_m, dist)) \
			* lerpf(1.0, far_gain, smoothstep(thin_from_m, maxf(far_m, thin_from_m + 0.1), dist))
	var weight := lerpf(weight_min, weight_max, hint)
	var under := 1.0 + under_bias * clampf(facing_down, -1.0, 1.0)
	return outline_width_m(dist, px, proj11, viewport_h, near_m, far_m, lens_fade_m, fp_scale) * gain * weight * under


## The atlas's layout, as tools/pipeline/gen_palette.py has it (COLUMNS, ROWS) and toon.gdshader's ATLAS_GRID.
const ATLAS_COLUMNS := 32
const ATLAS_ROWS := 2


## The atlas UV of the swatch a detail mask's blue channel names (M6 DETAIL-2), `code8` the channel as 0-255: the slot plus 1, so 0 names
## none and the face's own swatch stays (Vector2(-1, -1)). toon.gdshader decodes it the same way (the CPU mirror, for tests).
static func texel_swatch_uv(code8: int) -> Vector2:
	if code8 <= 0:
		return Vector2(-1.0, -1.0)
	var slot := code8 - 1
	return Vector2((float(slot % ATLAS_COLUMNS) + 0.5) / float(ATLAS_COLUMNS), (float(slot / ATLAS_COLUMNS) + 0.5) / float(ATLAS_ROWS))


## The width of the hull line at `dist` metres from the lens, in metres, as toon_outline.gdshader
## draws it: `px` pixels at 1080p (so `viewport_h / 1080` of them on a viewport `viewport_h`
## high, each 2 d / (proj11 * viewport_h) metres at the clamped distance d), the same number
## of pixels between `near_m` and `far_m`, thinner beyond, wider nearer, scaled by `fp_scale`
## on the player's own body and fading to 0 from `lens_fade_m` to twice it from the lens.
## `proj11` is the camera's PROJECTION_MATRIX[1][1] (1 / tan of half the vertical field of view).
static func outline_width_m(dist: float, px: float, proj11: float, viewport_h: float,
		near_m: float, far_m: float, lens_fade_m: float, fp_scale: float = 1.0) -> float:
	var fade := smoothstep(0.0, 1.0, (dist - lens_fade_m) / maxf(lens_fade_m, 0.0001))
	var pixels := px * fp_scale * viewport_h / 1080.0
	return pixels * 2.0 * clampf(dist, near_m, far_m) / (absf(proj11) * viewport_h) * fade


## The fill light's direction in the camera's view space (x right, y up, z toward the lens), a
## unit vector from the surface to the light: `yaw_deg` to the right of the lens (negative: from
## the left) and `pitch_deg` above its axis. toon_light.gdshaderinc's `fill_dir`.
static func fill_direction(yaw_deg: float, pitch_deg: float) -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## The band shade the toon lighting gives a surface whose light (the angle to the sun times the
## shadow map) is `lit`, before the light's color: the shadow level (tinted toward `tint` by
## `tint_amount`, luminance kept) below `band_1`, `mid` below `band_2`, 1 above, the edges
## smoothstepped over `edge` (half a band edge in light units). toon_light.gdshaderinc's
## toon_shade().
static func band_shade(lit: float, edge: float, band_1: float, band_2: float, mid: float,
		shadow_level: float, tint: Color, tint_amount: float) -> Color:
	var luma := maxf(tint.r * 0.2126 + tint.g * 0.7152 + tint.b * 0.0722, 0.001)
	var unit := Color(tint.r / luma, tint.g / luma, tint.b / luma)
	var shadow := Color(1.0, 1.0, 1.0).lerp(unit, tint_amount) * shadow_level
	shadow.a = 1.0
	var b1 := smoothstep(band_1 - edge, band_1 + edge, lit)
	var b2 := smoothstep(band_2 - edge, band_2 + edge, lit)
	var out := shadow.lerp(Color(mid, mid, mid), b1).lerp(Color.WHITE, b2)
	out.a = 1.0
	return out


## Whether the atlas alpha `alpha` (0 to 1) marks a glossy swatch, as toon.gdshader's swatch_gloss()
## decodes it: a damage class's alpha (1.0 clothes, 0.9 clothes without blood, 0.8 skin, 0.5 none, as 255,
## 230, 204, 128 of 255) minus exactly one 8-bit step (any other alpha is matte). gen_palette.py writes it from a swatch's
## `"gloss": true`.
static func swatch_glossy(alpha: float) -> bool:
	var a8 := floorf(alpha * 255.0 + 0.5)
	var class_a8 := 255.0 if alpha > 0.95 else (230.0 if alpha > 0.85 else (204.0 if alpha > 0.75 else 128.0))
	return absf(class_a8 - a8 - 1.0) < 0.5


## The share of ink a surface takes from its detail mask, as toon.gdshader computes it: `mask` is the
## filtered mask value at the pixel, `gradient` how much it changes across one pixel (fwidth) and
## `cut` the sharp ink's cut (`look_detail_cut`). `sharp` false is the linear mix (the mask as it is:
## the Punk's); true cuts it with an edge one pixel wide, so a line is as hard as the hull's.
static func detail_ink(mask: float, gradient: float, cut: float, sharp: bool) -> float:
	if not sharp:
		return mask
	var edge := maxf(0.5 * gradient, 0.0001)
	return smoothstep(cut - edge, cut + edge, mask)


## The hull's push direction for a vertex of a mesh, as toon_outline.gdshader computes it (unit
## per axis for boxes and cylinders): `mode` a Hull, `vertex` and `normal` the mesh's own.
static func hull_direction(mode: int, vertex: Vector3, normal: Vector3) -> Vector3:
	match mode:
		Hull.BOX:
			return Vector3(1.0 if vertex.x >= 0.0 else -1.0, 1.0 if vertex.y >= 0.0 else -1.0,
					1.0 if vertex.z >= 0.0 else -1.0)
		Hull.CYLINDER:
			var radial := Vector2(vertex.x, vertex.z)
			var out := radial / radial.length() if radial.length() > 0.00001 else Vector2.ZERO
			return Vector3(out.x, 1.0 if vertex.y >= 0.0 else -1.0, out.y)
		Hull.RADIAL:
			return vertex.normalized() if vertex.length() > 0.00001 else normal
	return normal


## Draw every toon variant once under `parent` at load, so the renderer compiles its pipelines
## before the first hit instead of on its frame (4-12 ms each, measured for the flash): a
## toon box with every hull mode on its overlay, and `skinned` (an art instance, a Node3D with
## the skinned meshes) drawn with the art's toon material and hull. Windowed only. The boxes
## run once per run and the skinned variant once per run too, whichever call brings it (the
## first rig of a room has no art, so the room's load asks for it separately). The holder
## stands in front of the viewport's camera (WARM_DISTANCE_M ahead, WARM_DROP_M below), where
## it is in view, for two frames, and frees itself after them. It is placed on the second
## frame, not the first: process_frame fires before any node's _process, so on the first frame
## the camera has not been placed yet (the FirstPersonCamera is at the world origin with no
## turn until its own first update) and a holder put by it would stand under the floor behind
## the view, where the renderer culls it and builds nothing. It stays hidden until then, and is
## scaled down to the camera's near distance when it shows: only the draw is wanted.
## `variants` (M7, warm_up_with()): more art instances, each a skinned Node3D wearing its own art's material, drawn
## in the same holder in the same pass: the trailer profile's art, whose mesh format (a UV2) or
## material may not be the m6 art's, so a profile flip compiles nothing mid-fight. They keep their
## own materials and hulls, and are drawn with `skinned`, once.
static func warm_up(parent: Node, skinned: Node3D = null) -> void:
	warm_up_with(parent, skinned, [] as Array[Node3D])


## warm_up() with the trailer profile's art drawn too (see its `variants`).
static func warm_up_with(parent: Node, skinned: Node3D, variants: Array[Node3D]) -> void:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var boxes := not _warmed
	var variant := skinned != null and not _art_warmed
	if not boxes and not variant:
		return
	_warmed = true
	_art_warmed = _art_warmed or skinned != null
	var holder := Node3D.new()
	holder.name = _WARM_NAME
	holder.visible = false
	parent.add_child(holder)
	if boxes:
		var color := character(Color.WHITE, true)
		for mode: int in Hull.values():
			var box := MeshInstance3D.new()
			box.mesh = BoxMesh.new()
			box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			box.material_override = color
			box.material_overlay = _hull(mode, mode == Hull.NORMAL)
			holder.add_child(box)
		# The kit's trim material, on a module, so its pipeline is built here and not on a frame.
		var module := MeshInstance3D.new()
		module.mesh = KitMesh.build(&"wall", Vector3.ONE * 1.2)
		module.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		holder.add_child(module)
		# A static prop (M6 D27): StaticArt's pipeline (art_prop on a mesh with CUSTOM0/1 and COLOR and no
		# skin, with the baked-normal hull on its overlay) is not one the skinned warm-up builds.
		if ResourceLoader.exists(WARM_PROP):
			var prop := (load(WARM_PROP) as PackedScene).instantiate() as Node3D
			if prop != null:
				holder.add_child(prop)
	if variant:
		var copy := skinned.duplicate() as Node3D
		holder.add_child(copy)
		var atlas := art(null)
		for node: Node in copy.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.material_override = atlas
			mesh.material_overlay = outline()
		# The painted material and its hull (M7): their pipelines too, on the same skeleton, whichever art is painted yet.
		var blank := ImageTexture.create_from_image(Image.create_empty(2, 2, true, Image.FORMAT_RGBA8))
		var painted_copy := skinned.duplicate() as Node3D
		holder.add_child(painted_copy)
		var painted_material := painted(blank, blank)
		for node: Node in painted_copy.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.material_override = painted_material
			mesh.material_overlay = outline_painted(blank)
		for other: Node3D in variants:
			if other != null:
				holder.add_child(other.duplicate() as Node3D)
	# Two frames for the camera to be placed (see above), then it is read and the holder stands
	# in its view, shown, for two more.
	await parent.get_tree().process_frame
	await parent.get_tree().process_frame
	var camera := parent.get_viewport().get_camera_3d() if is_instance_valid(holder) else null
	if camera != null and is_instance_valid(holder):
		holder.global_position = camera.global_position - camera.global_basis.z * WARM_DISTANCE_M + Vector3.DOWN * WARM_DROP_M
		# In the lens, so the renderer draws it, but a speck: a pipeline is built by the draw, not by
		# the picture, and a whole body and its metre boxes would flash for two frames at every load.
		holder.scale = Vector3.ONE * camera.near
		holder.visible = true
	await parent.get_tree().process_frame
	await parent.get_tree().process_frame
	if is_instance_valid(holder):
		holder.queue_free()


static func _make(kind: int, glossy: bool, shader: Shader = TOON_SHADER) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_meta(_KIND_META, kind)
	material.set_meta(_GLOSSY_META, glossy)
	# Every uniform a rig or a test reads back is set from the start (a ShaderMaterial hands back
	# nothing for one that was never set), at the value the shader would default to.
	material.set_shader_parameter(&"flash_color", Color.WHITE)
	material.set_shader_parameter(&"flash_amount", 0.0)
	material.set_shader_parameter(&"marks", 0.0)
	material.set_shader_parameter(&"use_albedo_tex", false)
	material.set_shader_parameter(&"use_detail_tex", false)
	material.set_shader_parameter(&"detail_sharp", false)
	material.set_shader_parameter(&"use_rest_custom", false)
	material.set_shader_parameter(&"edge_tag", 1.0)
	return material


static func _hull(mode: int, first_person: bool) -> ShaderMaterial:
	var key := mode + (100 if first_person else 0)
	var hull := _hulls.get(key) as ShaderMaterial
	if hull == null:
		hull = ShaderMaterial.new()
		hull.shader = OUTLINE_SHADER
		hull.set_meta(_KIND_META, Kind.HULL)
		hull.set_meta(_FP_META, first_person)
		hull.set_shader_parameter(&"mode", mode)
		hull.set_shader_parameter(&"ink", INK)
		_hulls[key] = hull
		_track(hull)
	return hull


## Remember `material` weakly, wire Tuning.changed once, and give it the current Look values.
static func _track(material: ShaderMaterial) -> ShaderMaterial:
	_live.append(weakref(material))
	if _live.size() >= _sweep_bar:
		_sweep()
		_sweep_bar = maxi(_SWEEP_AT, _live.size() * 2)
	if not _wired:
		_wired = true
		Tuning.changed.connect(_on_tuning_changed)
	apply_look(material)
	return material


static func _apply_all() -> void:
	var alive: Array[WeakRef] = []
	for ref: WeakRef in _live:
		var material := ref.get_ref() as ShaderMaterial
		if material != null:
			apply_look(material)
			alive.append(ref)
	_live = alive


static func _on_tuning_changed(property: StringName) -> void:
	# Only a Look value (or a whole-set change) moves a material; the damage tile is the damage
	# look's, re-read when it is applied.
	if property != &"" and not String(property).begins_with("look_") and not String(property).begins_with("ground_") and property != &"kit_trim_m_per_tile":
		return
	var alive: Array[WeakRef] = []
	for ref: WeakRef in _live:
		var material := ref.get_ref() as ShaderMaterial
		if material != null:
			apply_look(material)
			alive.append(ref)
	_live = alive


## Drop the registry's dead entries.
static func _sweep() -> void:
	var alive: Array[WeakRef] = []
	for ref: WeakRef in _live:
		if ref.get_ref() != null:
			alive.append(ref)
	_live = alive
