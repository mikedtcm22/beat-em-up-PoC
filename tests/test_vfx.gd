extends GutTest
## Comic VFX and damage looks (game/fx/, Milestone 2 WP2): the per-tier effect stack, the
## lettering pools, blood, spit and tooth, block sparks, speed lines and the impact frame,
## the view caps, the damage looks, the VFX tuning group and the art set. The director's
## time is driven by calling VfxDirector.advance() with chosen deltas (processing is off);
## the camera sits at the origin looking down -Z.

const ROOM := preload("res://game/level/test_room.tscn")
const DUMMY_SCENE := preload("res://game/enemies/dummy/training_dummy.tscn")
const TICK := 1.0 / 60.0
## In front of the camera, as a punch to an enemy's head would land.
const CONTACT := Vector3(0.0, 0.1, -1.2)
const ART := [
	&"burst_small", &"burst_medium", &"burst_large", &"speed_lines", &"blood_drop", &"blood_splat_1",
	&"blood_splat_2", &"blood_splat_3", &"blood_spray", &"spit", &"tooth", &"block_spark", &"parry_spark",
	&"guard_break", &"rear_warning", &"damage_bruised", &"damage_scuffed", &"damage_blood", &"damage_bloodied",
]


## An inert actor in the "player" group for the lunge lines.
class FakeMover:
	extends CombatActor

	func _init() -> void:
		add_to_group(&"actor")
		add_to_group(&"player")

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


## A camera that turns in its own _process after default-priority nodes, as the game's
## cameras do (CameraDirector.PROCESS_PRIORITY).
class TurningCamera:
	extends Camera3D

	var step_deg: float = 0.0

	func _init() -> void:
		process_priority = CameraDirector.PROCESS_PRIORITY

	func _process(_delta: float) -> void:
		rotate_y(deg_to_rad(step_deg))


var vfx: VfxDirector
var camera: Camera3D


func before_each() -> void:
	Tuning.apply(TuningData.new())
	TimeController.clear()
	TimeController.debug_scale = 1.0
	camera = Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	vfx = VfxDirector.new()
	add_child_autofree(vfx)
	vfx.set_process(false)
	vfx.rng.seed = 1


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())


func _hit(tier: CombatTypes.HitTier, point: Vector3 = CONTACT, region: CombatTypes.Region = CombatTypes.Region.TORSO,
		victim: Node3D = null) -> HitInfo:
	var hit := HitInfo.new()
	hit.tier = tier
	hit.region = region
	hit.contact_point = point
	hit.direction = Vector3.FORWARD
	hit.victim = victim
	return hit


func _land(hit: HitInfo) -> void:
	CombatEvents.hit_landed.emit(hit)


func _count(kind: StringName) -> int:
	return vfx.live_effects(kind).size()


func _advance(seconds: float) -> void:
	var steps := ceili(seconds / TICK)
	for i in steps:
		vfx.advance(TICK)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _screen() -> Rect2:
	return Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size)


## The drawn width of each tier's burst and word for hits at `point` (light words forced on).
func _tier_widths(point: Vector3) -> Dictionary:
	Tuning.data.vfx_word_chance_light = 1.0
	var bursts: Array[float] = []
	var words: Array[float] = []
	for tier: int in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		vfx.clear()
		_land(_hit(tier, point))
		_advance(Tuning.data.vfx_pop_s + TICK)
		bursts.append(vfx.live_effects(VfxArt.BURSTS[tier])[0].drawn_width)
		words.append(vfx.live_effects(&"word")[0].drawn_width)
	return {bursts = bursts, words = words}


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


# --- The per-tier stack (Spec §6 table) ----------------------------------------------


func test_light_hit_is_a_small_burst_only() -> void:
	_land(_hit(CombatTypes.HitTier.LIGHT))
	assert_eq(_count(&"burst_small"), 1, "small burst")
	assert_eq(_count(&"burst_medium") + _count(&"burst_large"), 0, "no bigger burst")
	assert_eq(_count(&"word"), 0, "no word by default (light chance 0)")
	assert_eq(_count(&"blood_drop") + _count(&"blood_spray"), 0, "no blood")
	assert_false(vfx.speed_lines.is_active(), "no speed lines")
	assert_false(vfx.impact_frame.is_flashing(), "no impact frame")


func test_light_hit_word_is_small_and_from_the_light_pool() -> void:
	Tuning.data.vfx_word_chance_light = 1.0
	_land(_hit(CombatTypes.HitTier.LIGHT))
	var words := vfx.live_effects(&"word")
	assert_eq(words.size(), 1)
	assert_has(vfx.light_words, words[0].get_meta(&"word"))
	assert_almost_eq(words[0].size_m, Tuning.data.vfx_word_small_m, 0.0001)


func test_heavy_hit_medium_burst_word_and_blood() -> void:
	_land(_hit(CombatTypes.HitTier.HEAVY))
	assert_eq(_count(&"burst_medium"), 1, "medium burst")
	var words := vfx.live_effects(&"word")
	assert_eq(words.size(), 1, "a word")
	assert_has(vfx.heavy_words, words[0].get_meta(&"word"))
	assert_almost_eq(words[0].size_m, Tuning.data.vfx_word_medium_m, 0.0001)
	assert_eq(_count(&"blood_spray"), 1, "blood splash")
	assert_eq(_count(&"blood_drop"), Tuning.data.vfx_blood_drops_heavy, "droplets")
	assert_false(vfx.speed_lines.is_active(), "speed lines are for finishers")
	assert_false(vfx.impact_frame.is_flashing(), "the impact frame is for finishers")


func test_finisher_full_stack() -> void:
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_eq(_count(&"burst_large"), 1, "large burst")
	var words := vfx.live_effects(&"word")
	assert_eq(words.size(), 1)
	assert_has(vfx.finisher_words, words[0].get_meta(&"word"))
	assert_almost_eq(words[0].size_m, Tuning.data.vfx_word_large_m, 0.0001)
	assert_eq(_count(&"blood_drop"), Tuning.data.vfx_blood_drops_finisher, "droplets")
	assert_true(vfx.speed_lines.is_active(), "speed lines")
	assert_almost_eq(vfx.speed_lines.opacity, Tuning.data.vfx_speed_lines_opacity, 0.0001)
	assert_true(vfx.impact_frame.is_flashing(), "impact frame")
	assert_eq(_count(&"spit") + _count(&"tooth"), 0, "spit and teeth only on the head")


func test_head_finisher_throws_spit_and_a_tooth() -> void:
	Tuning.data.vfx_tooth_chance = 1.0
	_land(_hit(CombatTypes.HitTier.FINISHER, CONTACT, CombatTypes.Region.HEAD))
	assert_eq(_count(&"spit"), Tuning.data.vfx_spit_drops, "spit")
	assert_eq(_count(&"tooth"), 1, "tooth")
	_land(_hit(CombatTypes.HitTier.HEAVY, CONTACT, CombatTypes.Region.HEAD))
	assert_eq(_count(&"tooth"), 1, "heavy head hits throw no tooth")
	Tuning.data.vfx_tooth_chance = 0.0
	_land(_hit(CombatTypes.HitTier.FINISHER, CONTACT, CombatTypes.Region.HEAD))
	assert_eq(_count(&"tooth"), 1, "no tooth at chance 0")


func test_blood_chance_zero_means_no_blood() -> void:
	Tuning.data.vfx_blood_chance_heavy = 0.0
	Tuning.data.vfx_blood_chance_finisher = 0.0
	_land(_hit(CombatTypes.HitTier.HEAVY))
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_eq(_count(&"blood_drop") + _count(&"blood_spray"), 0)


func test_blocked_hits_get_sparks_not_the_hit_stack() -> void:
	var hit := _hit(CombatTypes.HitTier.FINISHER, CONTACT, CombatTypes.Region.HEAD)
	hit.blocked = true
	_land(hit)
	assert_eq(_count(&"block_spark"), 1, "block spark")
	assert_eq(_count(&"burst_large") + _count(&"word") + _count(&"blood_drop") + _count(&"spit"), 0, "no hit stack")
	assert_false(vfx.speed_lines.is_active())
	assert_false(vfx.impact_frame.is_flashing())
	var perfect := _hit(CombatTypes.HitTier.LIGHT)
	perfect.blocked = true
	perfect.perfect_block = true
	_land(perfect)
	assert_eq(_count(&"parry_spark"), 1, "parry spark")
	var broken := _hit(CombatTypes.HitTier.LIGHT)
	broken.blocked = true
	broken.guard_broken = true
	_land(broken)
	assert_eq(_count(&"guard_break"), 1, "guard-break burst")
	assert_eq(_count(&"block_spark"), 1, "the parry and the break are not plain sparks")


# --- Lettering -----------------------------------------------------------------------


func test_words_never_repeat_twice_in_a_row() -> void:
	for tier: int in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		var last := ""
		var seen := {}
		for i in 300:
			var word := vfx.pick_word(tier)
			assert_ne(word, last, "tier %d pick %d repeats" % [tier, i])
			last = word
			seen[word] = true
		var pool: PackedStringArray = [vfx.light_words, vfx.heavy_words, vfx.finisher_words][tier]
		assert_eq(seen.size(), pool.size(), "tier %d uses its whole pool" % tier)
	# Mixed tiers: still never the same word twice in a row.
	var previous := ""
	for i in 300:
		var word := vfx.pick_word(vfx.rng.randi() % 3)
		assert_ne(word, previous)
		previous = word


func test_one_word_at_a_time() -> void:
	_land(_hit(CombatTypes.HitTier.HEAVY))
	_land(_hit(CombatTypes.HitTier.FINISHER))
	_advance(TICK)
	assert_eq(_count(&"word"), 1, "the new word ends the last")


func test_every_word_has_lettering_and_the_set_is_8_to_10_words() -> void:
	var all := {}
	for pool: PackedStringArray in [vfx.light_words, vfx.heavy_words, vfx.finisher_words]:
		assert_gt(pool.size(), 1, "a pool needs two words to never repeat")
		for word in pool:
			assert_not_null(VfxArt.word_texture(word), "lettering for %s" % word)
			all[word] = true
	assert_between(all.size(), 8, 10, "comic lettering set (WP2: 8-10 words)")
	var files := Array(DirAccess.get_files_at(VfxArt.DIR)).filter(
		func(f: String) -> bool: return f.begins_with("word_") and f.ends_with(".png"))
	assert_eq(files.size(), all.size(), "every lettering PNG is in a pool")


func test_words_stay_inside_the_view() -> void:
	# A contact just above the top of the view, as a hit on an enemy's head seen from below.
	var above := Vector3(0.3, 0.75, -1.0)
	_land(_hit(CombatTypes.HitTier.FINISHER, above))
	_advance(Tuning.data.vfx_pop_s + TICK)
	var word := vfx.live_effects(&"word")[0]
	var size := camera.get_viewport().get_visible_rect().size
	var tex := word.texture
	var half := Vector3(word.drawn_width * 0.5, word.drawn_width * 0.5 * tex.get_height() / tex.get_width(), 0.0)
	for corner: Vector3 in [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(-1, 1, 0), Vector3(1, 1, 0)]:
		var p := camera.unproject_position(word.global_position + camera.global_basis * (half * corner))
		assert_true(Rect2(Vector2.ZERO, size).has_point(p), "word corner %s on screen: %s" % [corner, p])


func test_effects_follow_the_camera_of_the_frame_being_drawn() -> void:
	assert_gt(vfx.process_priority, CameraDirector.PROCESS_PRIORITY, "processes after the cameras")
	var turning := TurningCamera.new()
	add_child_autofree(turning)
	turning.make_current()
	camera = turning
	vfx.set_process(true)
	_land(_hit(CombatTypes.HitTier.FINISHER))
	await get_tree().process_frame
	# The view turns 6 degrees a frame (a spin or a mouse flick).
	turning.step_deg = 6.0
	for i in 4:
		await get_tree().process_frame
		var word := vfx.live_effects(&"word")[0]
		assert_gt(word.global_basis.z.normalized().dot(turning.global_basis.z), 0.9999, "frame %d: faces this frame's view" % i)
		assert_true(_screen().has_point(turning.unproject_position(word.global_position)), "frame %d: on screen" % i)


func test_words_of_hits_behind_or_far_beside_the_camera_stay_at_the_contact() -> void:
	# A back elbow: the contact is behind the camera. Nothing floats in front of the lens.
	_land(_hit(CombatTypes.HitTier.HEAVY, Vector3(0.0, 0.1, 1.0)))
	_advance(Tuning.data.vfx_pop_s + TICK)
	assert_false(vfx.live_effects(&"word")[0].visible, "the word stays behind")
	assert_false(vfx.live_effects(&"burst_medium")[0].visible, "and so does the burst")
	# A spin kick's side victim, far outside the view: the word stays beside it, off screen.
	vfx.clear()
	var beside := Vector3(3.0, 0.1, -0.6)
	_land(_hit(CombatTypes.HitTier.HEAVY, beside))
	_advance(Tuning.data.vfx_pop_s + TICK)
	var word := vfx.live_effects(&"word")[0]
	assert_false(_screen().has_point(camera.unproject_position(word.global_position)), "off screen")
	assert_lt(word.global_position.distance_to(beside), word.size_m * 2.0, "at its contact")
	# Just outside the side edge (within vfx_clamp_reach_side_deg): pulled inside the view.
	vfx.clear()
	var depth := 1.2
	var half_angle := atan2(VfxDirector.view_width_at(camera, depth) * 0.5, depth)
	var edge := Vector3(depth * tan(half_angle + deg_to_rad(Tuning.data.vfx_clamp_reach_side_deg * 0.5)), 0.0, -depth)
	assert_false(_screen().has_point(camera.unproject_position(edge)), "the contact is off screen")
	_land(_hit(CombatTypes.HitTier.HEAVY, edge))
	_advance(Tuning.data.vfx_pop_s + TICK)
	word = vfx.live_effects(&"word")[0]
	assert_true(word.visible and _screen().has_point(camera.unproject_position(word.global_position)), "word in view")
	var burst := vfx.live_effects(&"burst_medium")[0]
	assert_true(burst.visible and _screen().has_point(camera.unproject_position(burst.global_position)), "burst in view")


func test_a_knee_or_stomp_under_the_view_still_shows_its_burst() -> void:
	# Contact 0.5 m ahead of and 0.8 m under the first-person lens.
	var knee := Vector3(0.0, -0.8, -0.5)
	assert_false(_screen().has_point(camera.unproject_position(knee)), "the contact itself is under the view")
	_land(_hit(CombatTypes.HitTier.LIGHT, knee))
	_advance(Tuning.data.vfx_pop_s + TICK)
	var burst := vfx.live_effects(&"burst_small")[0]
	assert_true(burst.visible)
	var p := camera.unproject_position(burst.global_position)
	assert_true(_screen().has_point(p), "the burst sits inside the view: %s" % p)
	assert_gt(p.y, _screen().size.y * 0.5, "at the bottom, on the contact's side")


# --- Sizes, caps and time ------------------------------------------------------------


func test_tier_sizes_keep_their_order_near_far_and_in_the_side_view() -> void:
	var side := Camera3D.new()
	side.fov = 38.0
	side.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child_autofree(side)
	# First person at a dummy's chest from striking range and from 4 m; the side view's depth.
	for setup: Array in [[camera, 0.8], [camera, 4.0], [side, 11.15]]:
		var cam: Camera3D = setup[0]
		var depth: float = setup[1]
		cam.make_current()
		var widths := _tier_widths(Vector3(0.0, 0.0, -depth))
		var view_w := VfxDirector.view_width_at(cam, depth)
		for kind: String in ["bursts", "words"]:
			var w: Array[float] = widths[kind]
			assert_lt(w[0], w[1], "%s at %.1f m: light < heavy (%s)" % [kind, depth, w])
			assert_lt(w[1], w[2], "%s at %.1f m: heavy < finisher (%s)" % [kind, depth, w])
			assert_lte(w[2], Tuning.data.vfx_max_view_share * view_w + 0.001, "%s at %.1f m: capped" % [kind, depth])
			assert_gte(w[0], Tuning.data.vfx_min_view_share * view_w - 0.001, "%s at %.1f m: readable" % [kind, depth])
	# The side view shows each tier's own slider: a smaller finisher burst draws smaller.
	side.make_current()
	var before: Array[float] = _tier_widths(Vector3(0.0, 0.0, -11.15)).bursts
	Tuning.data.vfx_burst_large_m = Tuning.data.vfx_burst_medium_m * 1.2
	var after: Array[float] = _tier_widths(Vector3(0.0, 0.0, -11.15)).bursts
	assert_lt(after[2], before[2], "the finisher slider changes the side view")




func test_vfx_scale_scales_every_size() -> void:
	Tuning.data.vfx_scale = 2.0
	_land(_hit(CombatTypes.HitTier.HEAVY))
	assert_almost_eq(vfx.live_effects(&"burst_medium")[0].size_m, Tuning.data.vfx_burst_medium_m * 2.0, 0.0001)
	assert_almost_eq(vfx.live_effects(&"word")[0].size_m, Tuning.data.vfx_word_medium_m * 2.0, 0.0001)


func test_close_effects_are_capped_and_kept_off_the_lens() -> void:
	Tuning.data.vfx_scale = 3.0
	_land(_hit(CombatTypes.HitTier.FINISHER, Vector3(0.0, 0.0, -0.2)))
	_advance(Tuning.data.vfx_pop_s + TICK)
	var burst := vfx.live_effects(&"burst_large")[0]
	var depth := -burst.global_position.z
	assert_almost_eq(depth, Tuning.data.vfx_min_camera_dist_m, 0.001, "pushed out to the minimum distance")
	var cap := Tuning.data.vfx_max_view_share * VfxDirector.view_width_at(camera, depth)
	assert_almost_eq(burst.drawn_width, cap, 0.001, "capped to the view share")
	assert_lt(burst.drawn_width, burst.size_m)


func test_hits_on_the_player_show_in_view_even_at_the_lens() -> void:
	var me := FakeMover.new()
	add_child_autofree(me)
	# A jab parried at the player's face: a little above and just behind the lens.
	var parry := _hit(CombatTypes.HitTier.LIGHT, Vector3(0.05, 0.2, 0.03), CombatTypes.Region.HEAD, me)
	parry.blocked = true
	parry.perfect_block = true
	_land(parry)
	vfx.advance(0.0)
	var spark := vfx.live_effects(&"parry_spark")[0]
	assert_true(spark.visible, "shown from the first frame")
	assert_almost_eq(-spark.global_position.z, Tuning.data.vfx_min_camera_dist_m, 0.001, "out at the minimum distance")
	var p := camera.unproject_position(spark.global_position)
	assert_true(Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size).has_point(p), "on screen")
	# The same contact on an enemy (not the camera's body) is behind the view: hidden.
	var other := _hit(CombatTypes.HitTier.LIGHT, Vector3(0.05, 0.2, 0.03))
	_land(other)
	vfx.advance(0.0)
	assert_false(vfx.live_effects(&"burst_small")[0].visible)


func test_far_effects_keep_a_readable_size() -> void:
	_land(_hit(CombatTypes.HitTier.LIGHT, Vector3(0.0, 0.0, -40.0)))
	_advance(Tuning.data.vfx_pop_s + TICK)
	var burst := vfx.live_effects(&"burst_small")[0]
	var view := VfxDirector.view_width_at(camera, 40.0)
	assert_almost_eq(burst.drawn_width, Tuning.data.vfx_min_view_share * view, 0.001)


func test_effects_face_the_camera_and_pop_in() -> void:
	_land(_hit(CombatTypes.HitTier.HEAVY))
	vfx.advance(0.0)
	var burst := vfx.live_effects(&"burst_medium")[0]
	var full := burst.size_m * burst.size_factor(VfxDirector.view_width_at(camera, -burst.global_position.z))
	assert_almost_eq(burst.drawn_width, full * Tuning.data.vfx_pop_start, 0.001, "pops from small")
	assert_gt(burst.global_basis.z.normalized().dot(Vector3.BACK), 0.999, "faces the camera")
	_advance(Tuning.data.vfx_pop_s * 0.5)
	assert_gt(burst.drawn_width, full * 1.05, "past full size")
	_advance(Tuning.data.vfx_pop_s)
	assert_almost_eq(burst.drawn_width, full, 0.001, "settles at full size")


func test_effects_expire_and_are_pooled() -> void:
	_land(_hit(CombatTypes.HitTier.FINISHER, CONTACT, CombatTypes.Region.HEAD))
	assert_gt(vfx.live_effects().size(), 0)
	_advance(maxf(Tuning.data.vfx_particle_s, Tuning.data.vfx_word_s) + Tuning.data.vfx_blood_splat_s + 0.1)
	assert_eq(vfx.live_effects().size(), 0, "all gone")
	assert_false(vfx.speed_lines.is_active())
	assert_false(vfx.impact_frame.is_flashing())
	var children := vfx.get_child_count()
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_eq(vfx.get_child_count(), children, "reuses pooled sprites")


func test_effects_run_on_sim_time() -> void:
	TimeController.debug_scale = 0.25
	_land(_hit(CombatTypes.HitTier.LIGHT))
	_advance(Tuning.data.vfx_burst_s * 2.0)
	assert_eq(_count(&"burst_small"), 1, "at 0.25x the burst lasts 4x as long")
	_advance(Tuning.data.vfx_burst_s * 2.5)
	assert_eq(_count(&"burst_small"), 0)


func test_words_fade_out_at_the_end() -> void:
	_land(_hit(CombatTypes.HitTier.HEAVY))
	var word := vfx.live_effects(&"word")[0]
	_advance(Tuning.data.vfx_word_s * 0.5)
	assert_almost_eq(word.modulate.a, 1.0, 0.001, "opaque mid-way")
	_advance(Tuning.data.vfx_word_s * 0.4)
	assert_between(word.modulate.a, 0.01, 0.99, "fading near the end")


# --- Speed lines and the impact frame ------------------------------------------------


func test_impact_frame_lasts_its_frames_and_respects_the_toggle() -> void:
	for frames: int in [1, 2]:
		Tuning.data.vfx_impact_frame_frames = frames
		_land(_hit(CombatTypes.HitTier.FINISHER))
		var shown := 0
		for i in 10:
			vfx.advance(TICK)
			if vfx.impact_frame.is_flashing():
				shown += 1
		assert_eq(shown, frames, "%d frame(s) shown" % frames)
	Tuning.data.impact_frame_enabled = false
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_false(vfx.impact_frame.is_flashing(), "the photosensitivity toggle turns it off")
	assert_eq(vfx.impact_frame.get_parent().get(&"layer"), VfxDirector.FLASH_LAYER)
	var hud := (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	assert_gt(VfxDirector.FLASH_LAYER, hud.get(&"layer"), "drawn over the HUD (the whole screen)")
	assert_lt(VfxDirector.LINES_LAYER, hud.get(&"layer"), "speed lines under the HUD")
	hud.free()


func test_fx_textures_are_loaded_once_and_held() -> void:
	var files := Array(ResourceLoader.list_directory(VfxArt.DIR)).filter(
		func(f: String) -> bool: return f.get_extension() == "png")
	assert_eq(VfxArt.held_count(), files.size(), "the director loaded the whole set when it was made")
	var rids := {}
	for name: StringName in ART:
		rids[name] = VfxArt.texture(name).get_rid()
	vfx.set_process(true)
	_land(_hit(CombatTypes.HitTier.FINISHER, CONTACT, CombatTypes.Region.HEAD))
	assert_true(vfx.speed_lines.is_active())
	for i in 4:
		await get_tree().process_frame
	vfx.clear()
	for i in 2:
		await get_tree().process_frame
	for name: StringName in ART:
		assert_true(ResourceLoader.has_cached(VfxArt.DIR + name + ".png"), "%s still loaded" % name)
		assert_eq(VfxArt.texture(name).get_rid(), rids[name], "%s is the same texture, never reloaded" % name)


func test_speed_lines_do_not_flicker_with_the_photosensitivity_toggle_off() -> void:
	_land(_hit(CombatTypes.HitTier.FINISHER))
	_advance(Tuning.data.vfx_speed_lines_s * 0.5)
	assert_gt(vfx.speed_lines.shuffles, 1, "they flicker by default")
	vfx.clear()
	Tuning.data.impact_frame_enabled = false
	_land(_hit(CombatTypes.HitTier.FINISHER))
	var placed := vfx.speed_lines.lines()
	_advance(Tuning.data.vfx_speed_lines_s * 0.8)
	assert_true(vfx.speed_lines.is_active(), "still fading")
	assert_eq(vfx.speed_lines.shuffles, 1, "never redrawn in new places")
	assert_eq(vfx.speed_lines.lines(), placed)


## Captures repeat: the lines draw from the director's rng, which the bots seed.
func test_seeding_the_director_repeats_the_speed_lines() -> void:
	_land(_hit(CombatTypes.HitTier.FINISHER))
	var first := vfx.speed_lines.lines()
	vfx.clear()
	vfx.rng.seed = 1
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_eq(vfx.speed_lines.lines(), first)


func test_speed_lines_stop_at_the_burst_and_the_word() -> void:
	_land(_hit(CombatTypes.HitTier.FINISHER))
	_advance(Tuning.data.vfx_pop_s + TICK)
	var lines := vfx.speed_lines
	assert_gte(lines.keep_clear.size(), 2, "the burst's and the word's rects")
	var crossings := 0
	for line: Vector4 in lines.lines():
		var ends := lines.streak_ends(line)
		var dir := Vector2.from_angle(line.x)
		for k in 24:
			var p := lines.focus + dir * lerpf(ends.x + 1.0, ends.y, k / 23.0)
			for rect: Rect2 in lines.keep_clear:
				if rect.grow(-1.0).has_point(p):
					crossings += 1
	assert_eq(crossings, 0, "no line runs over a live effect")


func test_line_droplet_and_word_randomness_follow_their_tunables() -> void:
	var t := Tuning.data
	t.vfx_speed_lines_width_min = 0.9
	t.vfx_speed_lines_width_max = 1.0
	t.vfx_speed_lines_inner_max = 1.1
	t.vfx_blood_launch_min_deg = 30.0
	t.vfx_blood_launch_max_deg = 31.0
	t.vfx_word_tilt_min_deg = 8.0
	t.vfx_word_tilt_deg = 9.0
	t.vfx_impact_frame_local_mix = 0.25
	t.vfx_impact_frame_blur_mip = 3.0
	_land(_hit(CombatTypes.HitTier.FINISHER))
	for line: Vector4 in vfx.speed_lines.lines():
		assert_between(line.w, 0.9, 1.0, "line thickness")
		assert_between(line.y, 1.0, 1.1, "line inner end")
	for drop: ComicSprite in vfx.live_effects(&"blood_drop"):
		var v := drop.velocity
		assert_between(rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length())), 29.9, 31.1, "launch angle")
	assert_between(rad_to_deg(absf(vfx.live_effects(&"word")[0].roll)), 7.99, 9.01, "word tilt")
	var mat := vfx.impact_frame.material as ShaderMaterial
	assert_almost_eq(float(mat.get_shader_parameter(&"local_mix")), 0.25, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter(&"blur_lod")), 3.0, 0.0001)


func test_speed_lines_respect_screen_shake_intensity() -> void:
	Tuning.data.screen_shake_intensity = 0.0
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_false(vfx.speed_lines.is_active(), "off at intensity 0")
	Tuning.data.screen_shake_intensity = 0.5
	_land(_hit(CombatTypes.HitTier.FINISHER))
	assert_almost_eq(vfx.speed_lines.opacity, Tuning.data.vfx_speed_lines_opacity * 0.5, 0.0001)
	assert_eq(vfx.speed_lines.line_count(), Tuning.data.vfx_speed_lines_count)
	_advance(Tuning.data.vfx_speed_lines_s + TICK)
	assert_false(vfx.speed_lines.is_active(), "fades out")


func test_finisher_lines_focus_between_the_center_and_the_contact() -> void:
	# A contact near the top edge, as an uppercut to a head seen from close up.
	var point := Vector3(0.4, 0.95, -1.5)
	_land(_hit(CombatTypes.HitTier.FINISHER, point))
	var center := vfx.speed_lines.size * 0.5
	var contact := camera.unproject_position(point)
	var follow := Tuning.data.vfx_speed_lines_focus_follow
	assert_almost_eq(vfx.speed_lines.focus.x, lerpf(center.x, contact.x, follow), 0.5)
	assert_almost_eq(vfx.speed_lines.focus.y, lerpf(center.y, contact.y, follow), 0.5)
	# The middle of the view stays clear of lines: every tip is at least the clear radius
	# from the focus, which sits only `follow` of the way out to the contact.
	var clear := vfx.speed_lines.size.length() * 0.5 * Tuning.data.vfx_speed_lines_clear
	var off_center := vfx.speed_lines.focus.distance_to(center)
	assert_lt(off_center, clear * 0.5, "the focus stays near the middle")
	for line: Vector4 in vfx.speed_lines.lines():
		var ends := vfx.speed_lines.streak_ends(line)
		var tip := vfx.speed_lines.focus + Vector2.from_angle(line.x) * ends.x
		assert_gt(tip.distance_to(center), clear - off_center - 0.5, "line tip %s clear of the view center" % tip)


func test_player_lunges_show_lunge_lines_in_first_person() -> void:
	var fp := FirstPersonCamera.new()
	add_child_autofree(fp)
	fp.make_current()
	var mover := FakeMover.new()
	add_child_autofree(mover)
	# A plain magnetism move (a jab or a chain hit) steps in without lines, however far.
	var jab := MoveData.new()
	jab.magnetism = true
	mover.current_move = jab
	CombatEvents.attack_started.emit(mover, jab, 1, &"root")
	mover.global_position += Vector3(0.0, 0.0, -Tuning.data.vfx_lunge_lines_min_m * 2.0)
	vfx.advance(TICK)
	assert_false(vfx.speed_lines.is_active(), "the magnetism step-in is no lunge")
	# A move with its own lunge (the flying kick) shows them once it has carried the player.
	var move := MoveData.new()
	move.lunge = 2.0
	move.free_lunge = 2.0
	mover.current_move = move
	CombatEvents.attack_started.emit(mover, move, 1, &"root")
	mover.global_position += Vector3(0.0, 0.0, -Tuning.data.vfx_lunge_lines_min_m * 0.5)
	vfx.advance(TICK)
	assert_false(vfx.speed_lines.is_active(), "a short step shows nothing")
	mover.global_position += Vector3(0.0, 0.0, -Tuning.data.vfx_lunge_lines_min_m * 0.6)
	vfx.advance(TICK)
	assert_true(vfx.speed_lines.is_active(), "a lunge shows lines")
	assert_almost_eq(vfx.speed_lines.opacity, Tuning.data.vfx_lunge_lines_opacity, 0.0001)
	# Not in the side view (any camera other than the first-person one).
	vfx.clear()
	camera.make_current()
	CombatEvents.attack_started.emit(mover, move, 1, &"root")
	mover.global_position += Vector3(0.0, 0.0, -2.0)
	vfx.advance(TICK)
	assert_false(vfx.speed_lines.is_active())


# --- Blood, spit and teeth in the world ----------------------------------------------


func test_droplets_leave_splats_where_they_land() -> void:
	_add_floor()
	await _ticks(2)
	_land(_hit(CombatTypes.HitTier.FINISHER))
	_advance(Tuning.data.vfx_particle_s)
	assert_eq(_count(&"blood_drop"), 0, "droplets landed")
	var splats := vfx.live_effects(&"", ComicSprite.Motion.LYING)
	assert_eq(splats.size(), Tuning.data.vfx_blood_drops_finisher, "one splat per droplet")
	for splat in splats:
		assert_almost_eq(splat.global_position.y, -1.0, 0.02, "on the floor")
		assert_gt(splat.global_basis.z.normalized().dot(Vector3.UP), 0.99, "flat on it")
	assert_eq(_count(&"blood_spray"), 0, "the splash is over")


func test_splats_are_capped_and_fade() -> void:
	_add_floor()
	await _ticks(2)
	Tuning.data.vfx_blood_splat_max = 3
	_land(_hit(CombatTypes.HitTier.FINISHER))
	_advance(Tuning.data.vfx_particle_s)
	assert_eq(vfx.live_effects(&"", ComicSprite.Motion.LYING).size(), 3, "oldest splats give way")
	_advance(Tuning.data.vfx_blood_splat_s)
	assert_eq(vfx.live_effects(&"", ComicSprite.Motion.LYING).size(), 0, "faded")


func test_a_tooth_lies_where_it_lands() -> void:
	_add_floor()
	await _ticks(2)
	Tuning.data.vfx_tooth_chance = 1.0
	_land(_hit(CombatTypes.HitTier.FINISHER, CONTACT, CombatTypes.Region.HEAD))
	_advance(Tuning.data.vfx_particle_s * 0.9)
	assert_eq(_count(&"spit"), 0, "spit vanished")
	var teeth := vfx.live_effects(&"tooth")
	assert_eq(teeth.size(), 1, "the tooth stays")
	assert_eq(teeth[0].velocity, Vector3.ZERO, "lying still")
	assert_lt(teeth[0].anchor.y, -0.9, "on the floor")


# --- Damage looks --------------------------------------------------------------------


func test_damage_look_levels_at_66_and_33_percent() -> void:
	assert_eq(DamageLook.level_for(1.0), DamageLook.Level.CLEAN)
	assert_eq(DamageLook.level_for(0.67), DamageLook.Level.CLEAN)
	assert_eq(DamageLook.level_for(0.66), DamageLook.Level.BRUISED)
	assert_eq(DamageLook.level_for(0.34), DamageLook.Level.BRUISED)
	assert_eq(DamageLook.level_for(0.33), DamageLook.Level.BLOODIED)
	assert_eq(DamageLook.level_for(0.0), DamageLook.Level.BLOODIED)


func test_rig_damage_look_changes_materials_only() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var meshes := rig.find_children("*", "MeshInstance3D", true, false).size()
	var fist := rig.get_point_transform(&"RightFistPoint")
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_eq(rig.damage_look, DamageLook.Level.BRUISED)
	assert_true(mats[PlaceholderBody.Paint.SKIN].detail_enabled, "bruised skin")
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bruised"))
	assert_true(mats[PlaceholderBody.Paint.SKIN].uv1_triplanar, "mapped triplanar")
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(mats[paint].detail_albedo, VfxArt.texture(&"damage_scuffed"), "scuffed clothes: paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "shades and soles stay")
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bloodied"))
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(mats[paint].detail_albedo, VfxArt.texture(&"damage_blood"), "blood on paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "shades and soles stay")
	rig.set_damage_look(DamageLook.Level.CLEAN)
	for paint: int in mats:
		if DamageLook.bruisable(paint):
			assert_eq(mats[paint].detail_albedo, VfxArt.clear_detail(), "clean again: nothing shows on paint %d" % paint)
		else:
			assert_false(mats[paint].detail_enabled, "still no detail layer: paint %d" % paint)
	assert_eq(rig.find_children("*", "MeshInstance3D", true, false).size(), meshes, "no meshes added")
	assert_eq(rig.get_point_transform(&"RightFistPoint"), fist, "pose untouched")


## Every stored property of `mat` but the two a damage look changes (the detail texture and
## its tile size): together they pick the material's shader variant, so equal dictionaries
## mean the same shader.
func _variant_props(mat: StandardMaterial3D) -> Dictionary:
	var out := {}
	for info: Dictionary in mat.get_property_list():
		var key: String = info.name
		if (info.usage as int) & PROPERTY_USAGE_STORAGE != 0 and key != "detail_albedo" and key != "uv1_scale":
			out[key] = mat.get(key)
	return out


## perf-02: the detail layer is on from the build (a transparent texture while clean), so a
## look change swaps the texture only and never the shader variant (a switch recompiled it
## on the first bruise of every clean cast: 3-5 ms and a pipeline compile).
func test_damage_look_never_switches_the_shader_variant() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	var variants := {}
	for paint: int in mats:
		variants[paint] = _variant_props(mats[paint])
	for paint: int in [PlaceholderBody.Paint.SKIN, PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS,
			PlaceholderBody.Paint.ACCENT]:
		var mat := mats[paint]
		assert_true(mat.detail_enabled, "detail layer on from the build: paint %d" % paint)
		assert_true(mat.uv1_triplanar, "triplanar from the build: paint %d" % paint)
		assert_eq(mat.detail_blend_mode, BaseMaterial3D.BLEND_MODE_MIX)
		assert_eq(mat.detail_uv_layer, BaseMaterial3D.DETAIL_UV_1)
		assert_eq(mat.detail_albedo, VfxArt.clear_detail(), "clean shows nothing: paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "the dark paint takes no marks")
	for level: int in [DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED, DamageLook.Level.CLEAN,
			DamageLook.Level.BRUISED, DamageLook.Level.CLEAN]:
		rig.set_damage_look(level)
		for paint: int in mats:
			assert_eq(_variant_props(mats[paint]), variants[paint], "level %d keeps paint %d's variant" % [level, paint])
	# The same textures as before (the look picks them by paint and level).
	assert_null(DamageLook.texture_for(PlaceholderBody.Paint.SKIN, DamageLook.Level.CLEAN))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.SKIN, DamageLook.Level.BRUISED), VfxArt.texture(&"damage_bruised"))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.SKIN, DamageLook.Level.BLOODIED), VfxArt.texture(&"damage_bloodied"))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.PANTS, DamageLook.Level.BRUISED), VfxArt.texture(&"damage_scuffed"))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.ACCENT, DamageLook.Level.BLOODIED), VfxArt.texture(&"damage_blood"))
	assert_null(DamageLook.texture_for(PlaceholderBody.Paint.DARK, DamageLook.Level.BLOODIED))


## The "nothing" texture shows nothing: fully transparent, one pixel, held for the run.
func test_clean_detail_texture_is_clear_and_held() -> void:
	var tex := VfxArt.clear_detail()
	assert_eq(tex, VfxArt.clear_detail(), "one texture for the run")
	var image := tex.get_image()
	assert_eq(image.get_size(), Vector2i(1, 1))
	assert_eq(image.get_pixel(0, 0).a, 0.0, "mixes in nothing")


## The tile size is the one thing besides the texture a look re-reads (Tuning.vfx_damage_tile_m).
func test_damage_look_rereads_the_tile_size() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var skin: StandardMaterial3D = (rig.get(&"_materials") as Dictionary[int, StandardMaterial3D])[PlaceholderBody.Paint.SKIN]
	assert_eq(skin.uv1_scale, Vector3.ONE / Tuning.data.vfx_damage_tile_m, "from the build")
	Tuning.data.vfx_damage_tile_m = 0.5
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_eq(skin.uv1_scale, Vector3.ONE / 0.5)
	rig.set_damage_look(DamageLook.Level.CLEAN)
	assert_eq(skin.uv1_scale, Vector3.ONE / 0.5)
	assert_eq(skin.detail_albedo, VfxArt.clear_detail())


## The whole-body flash (set_flash(), the parry's) is emission added over the lit, marked
## albedo; the hit flash is the contact overlay instead (test_hit_flash.gd checks it keeps
## the marks). Here: every marked material flashes whole-body, and keeps its marks.
func test_whole_body_flash_still_covers_the_damage_look() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	rig.set_flash(1.0)
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	for paint: int in mats:
		assert_true(mats[paint].emission_enabled, "paint %d can flash" % paint)
		assert_eq(mats[paint].emission, Color.WHITE)
		assert_eq(mats[paint].emission_energy_multiplier, 1.0, "paint %d flashes" % paint)
	assert_true(mats[PlaceholderBody.Paint.SKIN].detail_enabled, "the marks stay under the flash")
	rig.set_flash(0.0)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].emission_energy_multiplier, 0.0)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bloodied"), "and show again")


func test_bruises_are_not_red_paint() -> void:
	# Spec §10: red is for blood, the rear warning and finisher accents. The bruised look's
	# textures hold no blood-red pixels; the bloodied ones do.
	for name: StringName in [&"damage_bruised", &"damage_scuffed"]:
		assert_eq(_red_share(name), 0.0, "%s has no red" % name)
	for name: StringName in [&"damage_bloodied", &"damage_blood"]:
		assert_gt(_red_share(name), 0.02, "%s has blood" % name)


## Share of the visible pixels of FX texture `name` that are saturated red.
func _red_share(name: StringName) -> float:
	var image := VfxArt.texture(name).get_image()
	image.decompress()
	var seen := 0
	var red := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var c := image.get_pixel(x, y)
			if c.a < 0.3:
				continue
			seen += 1
			if c.r > 0.55 and c.r > c.g * 2.5 and c.r > c.b * 2.5:
				red += 1
	return float(red) / maxf(seen, 1.0)


func test_director_steps_enemy_looks_from_health() -> void:
	var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
	add_child_autofree(dummy)
	await _ticks(2)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.CLEAN)
	CombatEvents.health_changed.emit(dummy, 20.0, 30.0)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.CLEAN, "two thirds is above 66%")
	CombatEvents.health_changed.emit(dummy, 19.5, 30.0)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.BRUISED, "at 65%")
	CombatEvents.health_changed.emit(dummy, 9.0, 30.0)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.BLOODIED, "at 30%")
	CombatEvents.health_changed.emit(dummy, 30.0, 30.0)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.CLEAN, "revived clean")
	# A tuning change re-reads the thresholds against the actor's health.
	dummy.max_health = 30.0
	dummy.health = 21.0
	CombatEvents.health_changed.emit(dummy, 21.0, 30.0)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.CLEAN, "70%")
	Tuning.set_value(&"vfx_bruised_at", 0.75)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.BRUISED, "70% is bruised at 0.75")


func test_real_hits_bruise_and_bloody_a_dummy_but_not_the_player() -> void:
	var room := ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(3)
	var player: PlayerCharacter = room.get(&"player")
	var dummy: TrainingDummy = room.get(&"dummies")[0]
	dummy.max_health = 30.0
	dummy.reset_state()
	var jab: MoveData = load("res://game/combat/moves/jab_1.tres")
	for i in 2:
		var hit := HitInfo.new()
		hit.attacker = player
		hit.victim = dummy
		hit.move = jab
		hit.damage = jab.damage
		hit.tier = jab.tier
		hit.reaction = CombatTypes.Reaction.NONE
		hit.contact_point = dummy.get_chest_position()
		dummy.receive_hit(hit)
	assert_eq(dummy.rig.damage_look, DamageLook.Level.BRUISED, "18 of 30 health")
	var player_hit := HitInfo.new()
	player_hit.attacker = dummy
	player_hit.victim = player
	player_hit.move = jab
	player_hit.damage = 90.0
	player_hit.reaction = CombatTypes.Reaction.NONE
	player.receive_hit(player_hit)
	assert_eq(player.rig.damage_look, DamageLook.Level.CLEAN, "only enemies show damage")


func test_presentation_writes_no_game_state() -> void:
	var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
	add_child_autofree(dummy)
	await _ticks(2)
	var before := [dummy.health, dummy.state, dummy.global_position, dummy.sim_velocity]
	var hit := _hit(CombatTypes.HitTier.FINISHER, dummy.get_head_top_position(), CombatTypes.Region.HEAD, dummy)
	hit.attacker = dummy
	_land(hit)
	_advance(1.0)
	assert_eq([dummy.health, dummy.state, dummy.global_position, dummy.sim_velocity], before)
	assert_false(TimeController.is_in_hitstop(dummy), "no time changes either")
	assert_false(TimeController.is_slowmo())


# --- Wiring, tuning and art ----------------------------------------------------------


func test_test_room_adds_one_director_with_presentation() -> void:
	vfx.free()
	var room := ROOM.instantiate()
	add_child_autofree(room)
	await _ticks(2)
	assert_eq(get_tree().get_nodes_in_group(VfxDirector.GROUP).size(), 1)
	room.free()
	var bare := ROOM.instantiate()
	bare.set(&"with_presentation", false)
	add_child_autofree(bare)
	await _ticks(2)
	assert_eq(get_tree().get_nodes_in_group(VfxDirector.GROUP).size(), 0, "tests without presentation get none")


func test_vfx_tuning_group_follows_hit_feel_and_every_value_is_a_slider_or_toggle() -> void:
	var groups: Array[String] = []
	var group := ""
	var vfx_props := 0
	for prop: Dictionary in TuningData.new().get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			group = prop.name
			groups.append(group)
			continue
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not String(prop.name).begins_with("vfx_"):
			continue
		vfx_props += 1
		assert_eq(group, "VFX", "%s is in the VFX group" % prop.name)
		if prop.type != TYPE_BOOL:
			assert_eq(prop.hint, PROPERTY_HINT_RANGE, "%s has a range (a panel slider)" % prop.name)
	assert_gt(vfx_props, 30)
	var at := groups.find("VFX")
	assert_gt(at, 0)
	assert_eq(groups[at - 1], "Hit feel", "right after Hit feel")


func test_fx_art_is_512_px_with_svg_sources_and_logged() -> void:
	var assets_md := FileAccess.get_file_as_string("res://ASSETS.md")
	var names: Array = ART.duplicate()
	for file: String in DirAccess.get_files_at(VfxArt.DIR):
		if file.begins_with("word_") and file.ends_with(".png"):
			names.append(StringName(file.get_basename()))
	for name: StringName in names:
		assert_true(VfxArt.has(name), "%s.png exported" % name)
		var tex := VfxArt.texture(name)
		if tex:
			assert_eq(maxi(tex.get_width(), tex.get_height()), 512, "%s is 512 px" % name)
		assert_true(FileAccess.file_exists("res://assets/source/fx/%s.svg" % name), "%s.svg source" % name)
		assert_true(assets_md.contains("%s.png" % name) or assets_md.contains("%s.svg" % name)
				or assets_md.contains(String(name).trim_prefix("word_")), "%s logged in ASSETS.md" % name)
	assert_true(assets_md.contains("## Effects (VFX)"), "ASSETS.md effects section")
