extends GutTest
## The comic VFX set's final pass (Milestone 4, package P1-fx; tools/gen_fx.gd, game/fx/): the ink weight
## tied to the character hull, one ink, red only where the look bible allows it, the burst variants that
## never repeat, lettering drawn to one cap height, unshaded blood splats, the warm-up covering every
## material variant an effect draws, and the art reproducing byte for byte from the generator.
## test_vfx.gd keeps the M2 behavior (sizes, caps, pools, 512 px, 8-10 words).

const TICK := 1.0 / 60.0
const SOURCE_DIR := "res://assets/source/fx/"
## Where a hit lands in these tests: 1.2 m ahead of the camera, the distance the ink weights are set for.
const REF_DEPTH_M := 1.2
## The width in px of the canvas the look bible's pixel figures are in (1080p).
const CANVAS_W := 1920.0
## The look bible's VFX ink: main strokes about twice the character hull (1.6 to 2.4 here).
const INK_MIN := 1.6
const INK_MAX := 2.4
## Effects that may hold red (hue 345-15 degrees, saturation above 0.5): blood, the rear warning and the
## finisher accents (the large burst, the finisher lettering's extrusion).
const RED_ALLOWED: Array[String] = [
	"blood_", "damage_blood", "damage_bloodied", "tooth", "rear_warning", "burst_large", "word_krak",
	"word_crunch", "word_whump", "word_kapow",
]
## The words in the lettering set drawn in the finisher style.
const FINISHER_WORDS: Array[String] = ["krak", "crunch", "whump", "kapow"]

var vfx: VfxDirector
var camera: Camera3D


func before_each() -> void:
	Tuning.apply(TuningData.new())
	TimeController.clear()
	TimeController.debug_scale = 1.0
	camera = Camera3D.new()
	camera.fov = Tuning.data.fov_deg
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	add_child_autofree(camera)
	camera.make_current()
	vfx = VfxDirector.new()
	add_child_autofree(vfx)
	vfx.set_process(false)
	vfx.rng.seed = 3


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())


func _hit(tier: CombatTypes.HitTier, point: Vector3 = Vector3(0.0, 0.0, -REF_DEPTH_M),
		region: CombatTypes.Region = CombatTypes.Region.TORSO) -> HitInfo:
	var hit := HitInfo.new()
	hit.tier = tier
	hit.region = region
	hit.contact_point = point
	hit.direction = Vector3.FORWARD
	return hit


func _advance(seconds: float) -> void:
	for i in ceili(seconds / TICK):
		vfx.advance(TICK)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _add_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, -1.5, 0.0)  # top face at y = -1
	add_child_autofree(body)


func _svg(name: String) -> String:
	return FileAccess.get_file_as_string(SOURCE_DIR + name + ".svg")


## The first capture group of `pattern` in `text`, as a float (NAN when it does not match).
func _number(text: String, pattern: String) -> float:
	var found := RegEx.create_from_string(pattern).search(text)
	return found.get_string(1).to_float() if found else NAN


## The texture's file name without its extension ("burst_large_2").
func _art_name(sprite: ComicSprite) -> String:
	return sprite.texture.resource_path.get_file().get_basename()


## `sprite`'s width on a 1080p canvas, for the camera it was placed against.
func _canvas_px(sprite: ComicSprite) -> float:
	return sprite.drawn_width / VfxDirector.view_width_at(camera, -sprite.global_position.z) * CANVAS_W


## The main ink line of the art `name` in px on a 1080p canvas, when its sprite is `canvas_px` wide.
func _ink_px(name: String, canvas_px: float) -> float:
	var svg := _svg(name)
	var units := _number(svg, "Ink line ([0-9.]+) units")
	var view_w := _number(svg, "viewBox=\"[-0-9.]+ [-0-9.]+ ([0-9.]+) [0-9.]+\"")
	return units * canvas_px / view_w


# --- Ink -----------------------------------------------------------------------------


## The look bible's "VFX strokes about 2x the character line at 1-2.5 m": at 1.2 m every burst tier and
## both lettering styles are inked at 1.6-2.4 times look_outline_px, the hull's width (the sprites'
## sizes, caps and pop are the director's own). If a size or the hull changes, rerun tools/gen_fx.gd
## after editing INK_TABLE.
func test_burst_and_lettering_ink_is_about_twice_the_character_hull() -> void:
	var hull := Tuning.data.look_outline_px
	for tier: int in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		vfx.clear()
		vfx.last_burst_variant = [-1, -1, -1]
		for variant in VfxArt.burst_variant_count(tier):
			vfx.last_burst_variant[tier] = (variant + 1) % VfxArt.burst_variant_count(tier)
			vfx.clear()
			CombatEvents.hit_landed.emit(_hit(tier))
			_advance(Tuning.data.vfx_pop_s + TICK)
			var burst := vfx.live_effects(VfxArt.BURSTS[tier])[0]
			assert_eq(_art_name(burst), String(VfxArt.BURST_VARIANTS[tier][variant]), "tier %d variant %d shown" % [tier, variant])
			var px := _ink_px(_art_name(burst), _canvas_px(burst))
			assert_between(px, hull * INK_MIN, hull * INK_MAX, "%s ink %.2f px against a %.2f px hull" % [_art_name(burst), px, hull])
	# Lettering: every word of the heavy pool (medium size) and the finisher pool (large size).
	Tuning.data.vfx_word_chance_light = 1.0
	for tier: int in [CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		var seen := {}
		for i in 80:
			vfx.clear()
			CombatEvents.hit_landed.emit(_hit(tier))
			_advance(Tuning.data.vfx_pop_s + TICK)
			var word := vfx.live_effects(&"word")[0]
			seen[_art_name(word)] = true
			var px := _ink_px(_art_name(word), _canvas_px(word))
			assert_between(px, hull * INK_MIN, hull * INK_MAX, "%s ink %.2f px" % [_art_name(word), px])
		assert_gt(seen.size(), 3, "most of tier %d's pool was measured" % tier)


## The guard break is a main effect; the rear warning is HUD, drawn at rear_warning_base_px on the
## canvas and inked at the HUD's panel border (6 px).
func test_guard_break_and_rear_warning_ink() -> void:
	var hull := Tuning.data.look_outline_px
	var guard := _hit(CombatTypes.HitTier.HEAVY)
	guard.blocked = true
	guard.guard_broken = true
	CombatEvents.hit_landed.emit(guard)
	_advance(Tuning.data.vfx_pop_s + TICK)
	var burst := vfx.live_effects(&"guard_break")[0]
	var px := _ink_px("guard_break", _canvas_px(burst))
	assert_between(px, hull * INK_MIN, hull * INK_MAX, "guard break ink %.2f px" % px)
	var warning_px := _ink_px("rear_warning", Tuning.data.rear_warning_base_px)
	assert_almost_eq(warning_px, 6.0, 0.75, "the warning burst is inked like the HUD border (6 px): %.2f" % warning_px)


func test_one_ink_for_every_stroke() -> void:
	var ink := Color.html("#120f17")
	for channel: int in 3:
		assert_almost_eq(ink[channel], HudStyle.INK[channel], 1.0 / 255.0, "the SVG ink is HudStyle.INK (channel %d)" % channel)
	# Every stroke of the set but the damage tiles (which carry their own wash colors) is the ink or a
	# light color: no dark red outline on the blood any more.
	var light := ["#ffffff", "#59ebff", "#c9c1a6", "none"]
	var strokes := 0
	for file: String in DirAccess.get_files_at(SOURCE_DIR):
		if file.get_extension() != "svg" or file.begins_with("damage_"):
			continue
		for found in RegEx.create_from_string("stroke=\"([^\"]+)\"").search_all(FileAccess.get_file_as_string(SOURCE_DIR + file)):
			var color := found.get_string(1)
			strokes += 1
			assert_true(color == "#120f17" or light.has(color), "%s strokes in %s" % [file, color])
	assert_gt(strokes, 100)


func test_red_is_only_blood_the_warning_and_the_finisher_accents() -> void:
	for file: String in DirAccess.get_files_at(VfxArt.DIR):
		if file.get_extension() != "png":
			continue
		var allowed := false
		for prefix: String in RED_ALLOWED:
			allowed = allowed or file.begins_with(prefix)
		if allowed:
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(VfxArt.DIR + file))
		image.resize(maxi(1, roundi(image.get_width() * 0.25)), maxi(1, roundi(image.get_height() * 0.25)), Image.INTERPOLATE_NEAREST)
		var opaque := 0
		var red := 0
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a < 0.5:
					continue
				opaque += 1
				if c.v > 0.2 and c.s > 0.5 and (c.h >= 345.0 / 360.0 or c.h <= 15.0 / 360.0):
					red += 1
		assert_gt(opaque, 0, "%s has pixels" % file)
		assert_lt(red, maxi(2, ceili(opaque * 0.002)), "%s holds red (%d of %d px)" % [file, red, opaque])


# --- Burst variants ---------------------------------------------------------------------


func test_every_burst_tier_has_two_variants_and_never_repeats_one() -> void:
	for tier: int in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		assert_eq(VfxArt.burst_variant_count(tier), 2, "tier %d has two variants" % tier)
		assert_ne(VfxArt.burst_texture(tier, 0), VfxArt.burst_texture(tier, 1), "and they are two textures")
		assert_eq(VfxArt.burst_texture(tier, 0), VfxArt.texture(VfxArt.BURSTS[tier]), "variant 0 is the tier's own")
		var last := ""
		var seen := {}
		for i in 40:
			vfx.clear()
			CombatEvents.hit_landed.emit(_hit(tier))
			var burst := vfx.live_effects(VfxArt.BURSTS[tier])
			assert_eq(burst.size(), 1, "the effect is still named for its tier")
			var name := _art_name(burst[0])
			assert_ne(name, last, "tier %d hit %d repeats %s" % [tier, i, name])
			last = name
			seen[name] = true
		assert_eq(seen.size(), 2, "tier %d shows both" % tier)


func test_burst_variants_off_always_shows_the_first() -> void:
	Tuning.data.vfx_burst_variants = false
	for tier: int in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		for i in 6:
			vfx.clear()
			CombatEvents.hit_landed.emit(_hit(tier))
			assert_eq(vfx.live_effects(VfxArt.BURSTS[tier])[0].texture, VfxArt.texture(VfxArt.BURSTS[tier]))


func test_the_burst_variant_pick_follows_the_seed_and_each_tier_has_its_own_history() -> void:
	var first: Array[int] = []
	for tier in 3:
		first.append(vfx.pick_burst_variant(tier))
	vfx.rng.seed = 3
	vfx.last_burst_variant = [-1, -1, -1]
	var again: Array[int] = []
	for tier in 3:
		again.append(vfx.pick_burst_variant(tier))
	assert_eq(again, first, "the same seed picks the same variants")
	for tier in 3:
		assert_eq(vfx.last_burst_variant[tier], first[tier])
		assert_ne(vfx.pick_burst_variant(tier), first[tier], "the next one of a tier differs")


# --- Lettering -----------------------------------------------------------------------------


## Lettering is drawn to one cap height: every word is the same number of cap heights wide, so at one
## sprite width (the director sizes by width) every word's letters are the same height.
func test_every_word_is_drawn_to_one_cap_height() -> void:
	var shares := {}
	for file: String in DirAccess.get_files_at(VfxArt.DIR):
		if not (file.begins_with("word_") and file.ends_with(".png")):
			continue
		var name := file.get_basename()
		shares[name] = _number(_svg(name), "Cap height share of the width ([0-9.]+)")
		var tex := VfxArt.texture(StringName(name))
		assert_eq(tex.get_width(), 512, "%s is as wide as the texture goes" % name)
	assert_eq(shares.size(), 10, "the ten words")
	var lo := INF
	var hi := 0.0
	for name: String in shares:
		assert_false(is_nan(shares[name]), "%s records its cap share" % name)
		lo = minf(lo, shares[name])
		hi = maxf(hi, shares[name])
	assert_lt(hi / lo, 1.03, "cap heights agree within 3 percent (%.4f to %.4f of the width)" % [lo, hi])
	# The words of one tier share one drawn width, so their letters stand equally tall on screen.
	for tier: int in [CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		var heights := {}
		for i in 40:
			vfx.clear()
			CombatEvents.hit_landed.emit(_hit(tier))
			_advance(Tuning.data.vfx_pop_s + TICK)
			var word := vfx.live_effects(&"word")[0]
			heights[_art_name(word)] = word.drawn_width * shares[_art_name(word)]
		assert_gt(heights.size(), 3)
		var short := INF
		var tall := 0.0
		for name: String in heights:
			short = minf(short, heights[name])
			tall = maxf(tall, heights[name])
		assert_lt(tall / short, 1.03, "tier %d letters are one height on screen" % tier)


# --- Splats and the warm-up ------------------------------------------------------------------


func test_splats_are_flat_unshaded_and_a_little_dark() -> void:
	var splat := vfx.spawn_splat(Vector3(0.0, -1.0, -2.0), Vector3.UP)
	assert_false(splat.shaded, "unshaded: a lit sprite would grade smoothly on the stepped toon floor")
	var shade := Tuning.data.vfx_splat_shade
	assert_lt(shade, 1.0)
	for channel: int in 3:
		assert_almost_eq(splat.modulate[channel], shade, 0.001, "a grey of the shade (channel %d)" % channel)
	_advance(Tuning.data.vfx_blood_splat_s * 0.9)
	assert_almost_eq(splat.modulate.r, shade, 0.001, "the fade moves its alpha only")
	assert_lt(splat.modulate.a, 1.0)
	Tuning.data.vfx_splat_shade = 1.0
	var plain := vfx.spawn_splat(Vector3(1.0, -1.0, -2.0), Vector3.UP)
	assert_eq(plain.modulate, Color.WHITE, "1: as drawn")


## The warm-up draws one sprite of every material variant the effects use, so no first hit compiles one.
## Every variant any effect draws (every tier, blocks, an armor spark, blood, spit, a tooth, a splat) is
## one the warm-up draws.
func test_the_warm_up_covers_every_material_variant_an_effect_draws() -> void:
	_add_floor()
	await _ticks(2)
	assert_true(vfx.begin_warm_up(true))
	vfx.advance(TICK)
	var warmed := {}
	for child: Node in vfx.get_children():
		var sprite := child as ComicSprite
		if sprite and sprite.visible:
			warmed["%s/%s" % [sprite.shaded, sprite.no_depth_test]] = true
	assert_eq(warmed.size(), 2, "two variants: popping, and plain")
	vfx.advance(TICK)
	Tuning.data.vfx_tooth_chance = 1.0
	Tuning.data.vfx_word_chance_light = 1.0
	var kinds := {}
	var drawn := {}
	var hits: Array[HitInfo] = []
	for tier: int in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		hits.append(_hit(tier, Vector3(0.0, 0.1, -1.2), CombatTypes.Region.HEAD))
	for style: String in ["block", "perfect", "guard_break", "armor"]:
		var hit := _hit(CombatTypes.HitTier.HEAVY)
		hit.blocked = style != "armor"
		hit.perfect_block = style == "perfect"
		hit.guard_broken = style == "guard_break"
		hit.armor_absorbed = style == "armor"
		hits.append(hit)
	for hit in hits:
		CombatEvents.hit_landed.emit(hit)
		for i in ceili(Tuning.data.vfx_particle_s / TICK):
			vfx.advance(TICK)
			for sprite in vfx.live_effects():
				drawn["%s/%s" % [sprite.shaded, sprite.no_depth_test]] = true
				kinds[sprite.kind] = sprite.motion
	var splat := vfx.spawn_splat(Vector3(0.0, -1.0, -2.0), Vector3.UP)
	drawn["%s/%s" % [splat.shaded, splat.no_depth_test]] = true
	for kind: StringName in [&"burst_small", &"burst_large", &"word", &"blood_drop", &"spit", &"tooth", &"block_spark", &"parry_spark", &"guard_break"]:
		assert_true(kinds.has(kind), "%s was drawn" % kind)
	assert_gt(vfx.live_effects(&"", ComicSprite.Motion.LYING).size(), 0, "splats were drawn")
	for variant: String in drawn:
		assert_true(warmed.has(variant), "%s (shaded/no_depth_test) is drawn by an effect and warmed at load" % variant)


# --- The art -----------------------------------------------------------------------------------


func test_the_set_has_a_source_a_log_row_and_lossless_mipmapped_import_for_every_png() -> void:
	var assets_md := FileAccess.get_file_as_string("res://ASSETS.md")
	var pngs := 0
	for file: String in DirAccess.get_files_at(VfxArt.DIR):
		if file.get_extension() != "png":
			continue
		pngs += 1
		var name := file.get_basename()
		var tex := VfxArt.texture(StringName(name))
		assert_not_null(tex, "%s loads" % name)
		if tex:
			assert_eq(maxi(tex.get_width(), tex.get_height()), 512, "%s is 512 px" % name)
		assert_true(FileAccess.file_exists(SOURCE_DIR + name + ".svg"), "%s.svg" % name)
		assert_true(assets_md.contains("%s.png" % name), "%s.png is a row in ASSETS.md" % name)
		var import := FileAccess.get_file_as_string(VfxArt.DIR + file + ".import")
		assert_true(import.contains("compress/mode=0") and import.contains("mipmaps/generate=true"), "%s imports lossless with mipmaps" % name)
	assert_eq(pngs, 32, "29 from M2 and M3 plus three burst variants")
	for file: String in DirAccess.get_files_at(SOURCE_DIR):
		if file.get_extension() == "svg":
			assert_true(FileAccess.file_exists(VfxArt.DIR + file.get_basename() + ".png"), "%s has its PNG" % file)


## A rerun of the generator leaves every file unchanged: it writes a copy (`--out=`) in a second
## process and compares every SVG and PNG with the committed ones, byte for byte.
func test_the_generator_reproduces_the_committed_art_byte_for_byte() -> void:
	var out := ProjectSettings.globalize_path("user://gen_fx_check")
	for sub: String in ["source", "export"]:
		DirAccess.make_dir_recursive_absolute(out.path_join(sub))
		for old: String in DirAccess.get_files_at(out.path_join(sub)):
			DirAccess.remove_absolute(out.path_join(sub).path_join(old))
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--quit-after", "600", "-s", "res://tools/gen_fx.gd", "--", "--out=" + out], output, true)
	assert_eq(code, 0, "the generator ran: %s" % [output])
	for pair: Array in [["source", "svg", SOURCE_DIR], ["export", "png", VfxArt.DIR]]:
		var committed := Array(DirAccess.get_files_at(pair[2])).filter(func(f: String) -> bool: return f.get_extension() == pair[1])
		var made := Array(DirAccess.get_files_at(out.path_join(pair[0]))).filter(func(f: String) -> bool: return f.get_extension() == pair[1])
		committed.sort()
		made.sort()
		assert_eq(made, committed, "the same set of %s files" % pair[1])
		for file: String in committed:
			assert_eq(FileAccess.get_file_as_bytes(out.path_join(pair[0]).path_join(file)),
					FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(pair[2] + file)), "%s is reproduced exactly" % file)
