extends GutTest
## The HUD under the trailer look profile (Milestone 7, e-hud): the comic caption boxes, the flat bars with a dropping damage chunk,
## the debug line away by default. Under m6 every helper gives what it always gave (the pixel check is in the e-hud stills).

const HUD_SCENE := preload("res://game/ui/hud.tscn")


func before_each() -> void:
	Tuning.reset_to_default()


func after_each() -> void:
	Tuning.reset_to_default()


func _trailer() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)


func test_m6_helpers_are_the_old_ones() -> void:
	assert_false(HudStyle.comic())
	assert_eq(HudStyle.tone(HudStyle.INK), HudStyle.INK)
	assert_eq(HudStyle.tone(HudStyle.PAPER), HudStyle.PAPER)
	assert_eq(HudStyle.empty_tone(), HudStyle.TROUGH)
	assert_eq(HudStyle.slant_of(0.2), 0.2)
	assert_eq(HudStyle.corner_scale(), Vector2.ONE)
	assert_eq(HudStyle.corner_offset(Vector2(500.0, 140.0), Vector2(0.0, 1.0)), Vector2.ZERO)


func test_trailer_palette_comes_from_the_tunables() -> void:
	_trailer()
	assert_true(HudStyle.comic())
	Tuning.set_value(&"hud_m7_ink", Color(0.1, 0.2, 0.3))
	assert_eq(HudStyle.tone(Color(HudStyle.INK, 0.5)), Color(0.1, 0.2, 0.3, 0.5), "ink keeps the alpha it was asked for")
	assert_eq(HudStyle.tone(HudStyle.PAPER), Tuning.data.hud_m7_paper)
	assert_eq(HudStyle.tone(HudStyle.GUARD), HudStyle.GUARD, "other colours as given")
	assert_eq(HudStyle.empty_tone(), Tuning.data.hud_m7_paper_shade)
	assert_almost_eq(HudStyle.slant_of(0.2), 0.2 * Tuning.data.hud_m7_slant_scale, 0.0001)


func test_the_hand_polygon_strays_a_little_and_stays_valid() -> void:
	var rect := Rect2(10.0, 20.0, 300.0, 60.0)
	var plain := HudStyle.hand_polygon(rect, 0.2, HudStyle._STRAY_OUTER, 0.0)
	assert_eq(plain.size(), 4, "no wobble: the plain slanted quad")
	var inked := HudStyle.hand_polygon(rect, 0.2, HudStyle._STRAY_OUTER, 2.0)
	assert_eq(inked.size(), 8)
	var bounds := rect.grow(2.5)
	for point: Vector2 in inked:
		assert_true(bounds.has_point(point), "every point within the wobble of the rect")
	assert_false(Geometry2D.triangulate_polygon(inked).is_empty(), "the outline triangulates")
	var thin := HudStyle.hand_polygon(Rect2(0.0, 0.0, 200.0, 6.0), 0.2, HudStyle._STRAY_OUTER, 5.0)
	assert_false(Geometry2D.triangulate_polygon(thin).is_empty(), "a thin bar stays a clean shape")


func test_a_damage_chunk_hangs_then_drops_away() -> void:
	var gauge := HealthGauge.new()
	gauge.reset(1.0)
	assert_eq(gauge.chunk_hi, gauge.chunk_lo, "no chunk at full health")
	gauge.set_target(0.5)
	assert_almost_eq(gauge.chunk_hi, 1.0, 0.0001)
	assert_almost_eq(gauge.chunk_lo, 0.5, 0.0001)
	gauge.advance(Tuning.data.hud_m7_chunk_hold_s * 0.5)
	assert_gt(gauge.chunk_hi, gauge.chunk_lo, "still hanging")
	gauge.set_target(0.4)
	assert_almost_eq(gauge.chunk_hi, 1.0, 0.0001, "a second hit while it hangs extends it")
	assert_almost_eq(gauge.chunk_lo, 0.4, 0.0001)
	assert_eq(gauge.chunk_age, 0.0, "and restarts its hold")
	gauge.advance(Tuning.data.hud_m7_chunk_hold_s + Tuning.data.hud_m7_chunk_fall_s + 0.1)
	assert_eq(gauge.chunk_hi, gauge.chunk_lo, "gone once it has fallen")
	assert_almost_eq(gauge.value, 0.4, 0.0001, "the bar itself never moved with it")


func test_the_m6_ghost_is_untouched_by_the_chunk() -> void:
	var gauge := HealthGauge.new()
	gauge.reset(1.0)
	gauge.set_target(0.5)
	gauge.advance(0.1)
	assert_almost_eq(gauge.ghost, 1.0, 0.0001, "ghost still holds")
	gauge.advance(2.0)
	gauge.advance(2.0)
	assert_almost_eq(gauge.ghost, 0.5, 0.0001, "and drains as before")


func test_the_combat_log_starts_away_under_trailer_and_comes_back_with_l() -> void:
	_trailer()
	var hud := HUD_SCENE.instantiate() as GameHud
	add_child_autofree(hud)
	hud.set_process(false)
	assert_false(hud.is_combat_log_visible(), "the debug line is off for normal play")
	hud.set_combat_log_visible(true)
	hud.advance(0.016)
	assert_true(hud.is_combat_log_visible(), "its key still brings it up, and it stays")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	hud.advance(0.016)
	assert_true(hud.is_combat_log_visible(), "m6: shown")


func test_the_log_tunable_keeps_it_up_under_trailer() -> void:
	_trailer()
	Tuning.set_value(&"hud_m7_log_visible", true)
	var hud := HUD_SCENE.instantiate() as GameHud
	add_child_autofree(hud)
	hud.set_process(false)
	assert_true(hud.is_combat_log_visible())


func test_every_part_draws_under_trailer_without_errors() -> void:
	_trailer()
	var hud := HUD_SCENE.instantiate() as GameHud
	add_child_autofree(hud)
	hud.set_process(false)
	hud.go_cue.show_clear()
	hud.block_callout.show_parry()
	hud.camera_toast.show_mode(&"first_person")
	hud.pause_overlay.set_paused(true)
	hud.set_help_visible(true)
	hud.queue_redraw_parts()
	await wait_frames(3)
	var box := hud.help_overlay.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_not_null(box)
	assert_eq(box.shadow_size, 0, "hard shadow")
