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
	&"guard_break", &"rear_warning", &"damage_bruised", &"damage_blood", &"damage_bloodied",
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


# --- Sizes, caps and time ------------------------------------------------------------


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
	assert_almost_eq(burst.drawn_width, burst.size_m * Tuning.data.vfx_pop_start, 0.001, "pops from small")
	assert_gt(burst.global_basis.z.normalized().dot(Vector3.BACK), 0.999, "faces the camera")
	_advance(Tuning.data.vfx_pop_s * 0.5)
	assert_gt(burst.drawn_width, burst.size_m * 1.05, "past full size")
	_advance(Tuning.data.vfx_pop_s)
	assert_almost_eq(burst.drawn_width, burst.size_m, 0.001, "settles at full size")


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


func test_finisher_lines_focus_on_the_contact() -> void:
	var point := Vector3(0.4, 0.2, -1.5)
	_land(_hit(CombatTypes.HitTier.FINISHER, point))
	assert_almost_eq(vfx.speed_lines.focus.x, camera.unproject_position(point).x, 0.5)
	assert_almost_eq(vfx.speed_lines.focus.y, camera.unproject_position(point).y, 0.5)


func test_player_lunges_show_lunge_lines_in_first_person() -> void:
	var fp := FirstPersonCamera.new()
	add_child_autofree(fp)
	fp.make_current()
	var mover := FakeMover.new()
	add_child_autofree(mover)
	var move := MoveData.new()
	mover.current_move = move
	CombatEvents.attack_started.emit(mover, move, 1, &"root")
	mover.global_position += Vector3(0.0, 0.0, -Tuning.data.vfx_lunge_lines_min_m * 0.5)
	vfx.advance(TICK)
	assert_false(vfx.speed_lines.is_active(), "a short step shows nothing")
	mover.global_position += Vector3(0.0, 0.0, -Tuning.data.vfx_lunge_lines_min_m)
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
	assert_false(mats[PlaceholderBody.Paint.BODY].detail_enabled, "clothes still clean")
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bloodied"))
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(mats[paint].detail_albedo, VfxArt.texture(&"damage_blood"), "blood on paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "shades and soles stay")
	rig.set_damage_look(DamageLook.Level.CLEAN)
	for paint: int in mats:
		assert_false(mats[paint].detail_enabled, "clean again: paint %d" % paint)
		assert_false(mats[paint].uv1_triplanar, "original shader: paint %d" % paint)
	assert_eq(rig.find_children("*", "MeshInstance3D", true, false).size(), meshes, "no meshes added")
	assert_eq(rig.get_point_transform(&"RightFistPoint"), fist, "pose untouched")


func test_hit_flash_still_covers_the_damage_look() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	rig.set_flash(1.0)
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	assert_eq(mats[PlaceholderBody.Paint.SKIN].emission_energy_multiplier, 1.0)
	assert_true(mats[PlaceholderBody.Paint.SKIN].detail_enabled)


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
