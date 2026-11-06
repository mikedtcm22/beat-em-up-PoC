extends GutTest
## M6 playtest feedback, FB-FEEL (docs/reviews/M6/fix-feedback.md): no sting on GO (Debug's audio_sting_go),
## and the player feeling each hit he takes (Tuning "Hit feel" > "Hurt", Debug's hurt_feel_enabled): the
## victim's larger shake and punch, the head's roll away from the blow's side, the edge vignette
## (HurtOverlay), the health panel's jolt, blocked hits staying light, and the switch giving M6 back.

const DT := 1.0 / 60.0
## The eye point's height of the stand-in player.
const EYE_Y := 1.68
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const BRUISER_SCENE := preload("res://game/enemies/bruiser/bruiser.tscn")
## How far a real attacker stands from the player for a jab (m): inside the jab's 1.05 m reach.
const JAB_RANGE_M := 0.9
## ...and for the Bruiser's smash.
const SMASH_RANGE_M := 1.2
## The pitches (degrees) of the pitched-view tests: a stomp looks about 45 down, 60 is steeper, 30 up.
const PITCHES_DEG: Array[float] = [-45.0, -60.0, 30.0]
## The roll and kick (degrees) a previous hit left on the camera, in the carried-view tests.
const CARRIED_ROLL_DEG := 12.0
const CARRIED_KICK_DEG := 6.0

## Stand-in for the player (as test_cameras.gd's): the camera-facing API only.
class FakePlayer extends PlayerCharacter:
	func _ready() -> void:
		add_to_group(&"player")

	func _process(_delta: float) -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

	func _input(_event: InputEvent) -> void:
		pass

	func _unhandled_input(_event: InputEvent) -> void:
		pass

	func get_eye_transform() -> Transform3D:
		return Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, EYE_Y, 0.0))

	func get_camera_move_offset() -> Vector2:
		return Vector2.ZERO

	func get_camera_view_yaw(_fraction: float = 1.0) -> float:
		return 0.0

	func is_walking() -> bool:
		return false

var _plays_2d: Array[StringName] = []


func before_each() -> void:
	Tuning.apply(TuningData.new())
	Tuning.data.cam_forward_offset_m = 0.0
	Tuning.data.cam_height_offset_m = 0.0
	_plays_2d.clear()


func after_all() -> void:
	Tuning.apply(TuningData.new())


# --- helpers ----------------------------------------------------------------------------------


func _player() -> FakePlayer:
	var player := FakePlayer.new()
	add_child_autofree(player)
	return player


func _camera(player: PlayerCharacter) -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.set_process(false)
	cam.player = player
	cam.update_camera(DT)
	return cam


## A hit on `victim` from the side `from` (a unit vector in the world, the view looking down -Z): the
## contact is 0.4 m from the lens that way, the push the opposite way.
func _hit(attacker: Node3D, victim: Node3D, tier: CombatTypes.HitTier, from: Vector3,
		damage: float = 8.0) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.tier = tier
	hit.damage = damage
	hit.contact_point = victim.global_position + Vector3(0.0, EYE_Y - 0.3, 0.0) + from * 0.4
	hit.direction = -from
	return hit


func _enemy() -> Node3D:
	var enemy := Node3D.new()
	add_child_autofree(enemy)
	return enemy


## Run the camera until its punches are at their peak (the snap's end), then read the roll.
func _roll_after(cam: FirstPersonCamera, hit: HitInfo) -> float:
	CombatEvents.hit_landed.emit(hit)
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	return cam.get_roll_deg()


func _overlay() -> HurtOverlay:
	var overlay := HurtOverlay.new()
	add_child_autofree(overlay)
	return overlay


# --- GO: no sting by default -------------------------------------------------------------------


func _audio() -> AudioDirector:
	var director := AudioDirector.new()
	add_child_autofree(director)
	director.played_2d.connect(func(pool: StringName, _p: AudioStreamPlayer) -> void: _plays_2d.append(pool))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.data.resize(4410)
	director.bank.pools[&"sting_go"] = [stream]
	director.bank.pools[&"sting_clear"] = [stream]
	return director


func test_clearing_an_arena_plays_no_sting_by_default() -> void:
	assert_false(Tuning.data.audio_sting_go, "the switch is off by default")
	_audio()
	var arena := Node3D.new()
	add_child_autofree(arena)
	CombatEvents.arena_cleared.emit(arena)
	assert_eq(_plays_2d, [] as Array[StringName], "GO is silent")


func test_the_switch_gives_the_go_sting_back() -> void:
	Tuning.data.audio_sting_go = true
	_audio()
	var arena := Node3D.new()
	add_child_autofree(arena)
	CombatEvents.arena_cleared.emit(arena)
	assert_eq(_plays_2d, [&"sting_go"] as Array[StringName])


func test_the_level_clear_still_plays_its_sting() -> void:
	_audio()
	var level := Node3D.new()
	add_child_autofree(level)
	CombatEvents.level_cleared.emit(level)
	assert_eq(_plays_2d, [&"sting_clear"] as Array[StringName], "CLEAR! stays, with the GO switch off")


func test_the_audition_room_still_lists_the_go_sting() -> void:
	assert_true(FileAccess.file_exists("res://assets/export/sfx/sting_go_01.wav"), "the pool's files stay")
	var director := AudioDirector.new()
	add_child_autofree(director)
	var room := AuditionRoom.new()
	add_child_autofree(room)
	assert_has(room.pools, &"sting_go", "the audition room lists sting_go")


# --- The camera ----------------------------------------------------------------------------------


func test_the_victim_gets_more_trauma_and_punch_than_the_attacker() -> void:
	var player := _player()
	var enemy := _enemy()
	var cam := _camera(player)
	for tier: CombatTypes.HitTier in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]:
		cam.trauma = 0.0
		CombatEvents.hit_landed.emit(_hit(player, enemy, tier, Vector3.RIGHT))
		var landed := cam.trauma
		assert_almost_eq(landed, Tuning.data.shake(tier), 0.0001, "the hits he lands keep SPEC 6's table")
		cam.trauma = 0.0
		CombatEvents.hit_landed.emit(_hit(enemy, player, tier, Vector3.RIGHT))
		assert_almost_eq(cam.trauma, Tuning.data.hurt_shake(tier), 0.0001)
		assert_gt(cam.trauma, landed, "the victim shakes more (tier %d)" % tier)
	assert_gte(Tuning.data.hurt_shake(CombatTypes.HitTier.LIGHT), Tuning.data.hurt_shake_min,
			"a light hit adds at least the floor")
	assert_gt(Tuning.data.hurt_punch_deg(CombatTypes.HitTier.LIGHT), Tuning.data.cam_punch_deg(CombatTypes.HitTier.LIGHT))


func test_the_roll_goes_away_from_the_side_the_blow_came_from() -> void:
	var player := _player()
	var enemy := _enemy()
	var from_right := _roll_after(_camera(player), _hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT))
	var from_left := _roll_after(_camera(player), _hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.LEFT))
	assert_gt(from_right, 0.5, "a blow on the right tips the head to its left (positive)")
	assert_lt(from_left, -0.5, "a blow on the left tips it right")
	assert_almost_eq(from_right, -from_left, 0.01, "the same size either way")
	assert_almost_eq(absf(from_right), Tuning.data.hurt_roll_heavy_deg, 0.3, "the tier's roll, at the peak")


func test_a_blow_from_ahead_tips_the_head_back_and_still_rolls() -> void:
	var player := _player()
	var enemy := _enemy()
	var cam := _camera(player)
	var ahead := Vector3(0.0, 0.0, -1.0)
	CombatEvents.hit_landed.emit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, ahead))
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	assert_gt(cam.get_punch_deg().x, 1.0, "pitch up")
	assert_gt(absf(cam.get_roll_deg()), 0.5, "a frontal blow still rolls")
	var first_sign := signf(cam.get_roll_deg())
	cam.update_camera(1.0)
	assert_true(cam.is_settled() or cam.trauma > 0.0)
	cam.trauma = 0.0
	CombatEvents.hit_landed.emit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, ahead))
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	assert_eq(signf(cam.get_roll_deg()), -first_sign, "it alternates sides")


func test_the_roll_settles() -> void:
	var player := _player()
	var cam := _camera(player)
	CombatEvents.hit_landed.emit(_hit(_enemy(), player, CombatTypes.HitTier.FINISHER, Vector3.RIGHT))
	cam.update_camera(cam.punch_duration_s + 0.01)
	assert_almost_eq(cam.get_roll_deg(), 0.0, 0.001)
	cam.update_camera(3.0)
	assert_true(cam.is_settled())


func test_a_blocked_hit_keeps_todays_light_feel() -> void:
	var player := _player()
	var enemy := _enemy()
	var cam := _camera(player)
	var hit := _hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT)
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	assert_almost_eq(cam.trauma, Tuning.data.shake(CombatTypes.HitTier.HEAVY) * cam.blocked_feel_scale, 0.0001)
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	assert_eq(cam.get_roll_deg(), 0.0, "no roll on a block")
	assert_lte(cam.get_punch_deg().length(),
			Tuning.data.cam_punch_deg(CombatTypes.HitTier.HEAVY) * cam.blocked_feel_scale + 0.01)


func test_the_switch_off_gives_m6s_view_back() -> void:
	Tuning.data.hurt_feel_enabled = false
	var player := _player()
	var enemy := _enemy()
	var cam := _camera(player)
	var hit := _hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.RIGHT)
	CombatEvents.hit_landed.emit(hit)
	assert_almost_eq(cam.trauma, Tuning.data.shake_light, 0.0001)
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	assert_eq(cam.get_roll_deg(), 0.0)
	assert_almost_eq(cam.get_punch_deg().length(), Tuning.data.cam_punch_light_deg, 0.01)
	var overlay := _overlay()
	overlay.on_player_hit(hit, Transform3D.IDENTITY)
	assert_false(overlay.is_live(), "no vignette")
	var panel := PlayerHealthPanel.new()
	add_child_autofree(panel)
	panel.health = 100.0
	panel.on_health_changed(90.0, 100.0)
	assert_eq(panel.jolt_offset(), Vector2.ZERO, "no jolt")


# --- The overlay ---------------------------------------------------------------------------------


func test_the_overlay_strength_and_depth_follow_the_damage() -> void:
	var player := _player()
	var enemy := _enemy()
	var small := _overlay()
	small.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.RIGHT, 3.0), Transform3D.IDENTITY)
	var big := _overlay()
	big.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.FINISHER, Vector3.RIGHT, 40.0), Transform3D.IDENTITY)
	var edge := HurtOverlay.Edge.RIGHT
	assert_gt(small.edge_strength(edge), 0.0, "a light jab still shows")
	assert_gt(big.edge_strength(edge), small.edge_strength(edge))
	assert_gt(big.depth_share(), small.depth_share())
	assert_almost_eq(big.edge_strength(edge), 1.0, 0.0001, "full damage is full strength")


func test_the_overlay_side_follows_the_contact() -> void:
	var player := _player()
	var enemy := _enemy()
	var right := _overlay()
	right.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT), Transform3D.IDENTITY)
	assert_gt(right.edge_strength(HurtOverlay.Edge.RIGHT), right.edge_strength(HurtOverlay.Edge.LEFT))
	var left := _overlay()
	left.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.LEFT), Transform3D.IDENTITY)
	assert_gt(left.edge_strength(HurtOverlay.Edge.LEFT), left.edge_strength(HurtOverlay.Edge.RIGHT))
	var behind := _overlay()
	behind.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.BACK), Transform3D.IDENTITY)
	assert_gt(behind.edge_strength(HurtOverlay.Edge.BOTTOM), behind.edge_strength(HurtOverlay.Edge.TOP))
	# The same contact, the view turned a quarter to the right (now looking along +X): the blow is ahead.
	var turned := _overlay()
	var view := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0.0, EYE_Y, 0.0))
	turned.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT), view)
	assert_gt(turned.stroke_strength(HurtOverlay.Edge.TOP), turned.stroke_strength(HurtOverlay.Edge.BOTTOM),
			"a view turned to face the blow sees it from ahead")
	for edge: int in 4:
		assert_gt(right.edge_strength(edge), 0.0, "every edge shows the even share")


func test_a_clean_hit_from_behind_is_inked_heavier_than_the_same_blow_on_another_edge() -> void:
	var player := _player()
	var enemy := _enemy()
	var gain := Tuning.data.hurt_overlay_bottom_ink_gain
	assert_gt(gain, 1.0, "the bottom ink is heavier by default")
	var behind := _overlay()
	behind.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.BACK, 6.0), Transform3D.IDENTITY)
	var left := _overlay()
	left.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.LEFT, 6.0), Transform3D.IDENTITY)
	# VF2-FEEL: the stored edge is the same as any struck edge's (it stays at 1 or below); the gain is the drawn
	# strength's, on the struck share only (was: edge_strength(BOTTOM) == the left's x gain).
	assert_almost_eq(behind.edge_strength(HurtOverlay.Edge.BOTTOM), left.edge_strength(HurtOverlay.Edge.LEFT), 0.0001,
			"the stored edge is the same as the struck edge of any blow")
	var even := Tuning.data.hurt_overlay_even_share
	var struck := left.edge_strength(HurtOverlay.Edge.LEFT) - even * HurtOverlay.strength_for(6.0)
	assert_almost_eq(behind.drawn_strength(HurtOverlay.Edge.BOTTOM),
			left.drawn_strength(HurtOverlay.Edge.LEFT) + struck * (gain - 1.0), 0.0001,
			"the same blow, the bottom edge drawn heavier by the gain on the struck share")
	assert_gt(behind.drawn_strength(HurtOverlay.Edge.BOTTOM), left.drawn_strength(HurtOverlay.Edge.LEFT), "heavier on screen")
	assert_almost_eq(behind.stroke_strength(HurtOverlay.Edge.BOTTOM), left.stroke_strength(HurtOverlay.Edge.LEFT), 0.0001,
			"the strokes' strength is the same (their length is the gain's, in the draw)")
	# A block stays as faint as M6: no gain, no strokes.
	var blocked := _hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.BACK, 6.0)
	blocked.blocked = true
	var guarded := _overlay()
	guarded.on_player_hit(blocked, Transform3D.IDENTITY)
	assert_almost_eq(guarded.edge_strength(HurtOverlay.Edge.BOTTOM),
			HurtOverlay.strength_for(6.0) * Tuning.data.hurt_overlay_blocked_scale, 0.0001, "a block's bottom edge is not boosted")
	assert_almost_eq(guarded.drawn_strength(HurtOverlay.Edge.BOTTOM), guarded.edge_strength(HurtOverlay.Edge.BOTTOM), 0.0001,
			"nor drawn heavier")
	assert_almost_eq(guarded.stroke_strength(HurtOverlay.Edge.BOTTOM), 0.0, 0.0001, "no strokes on a block")


func test_the_gain_is_on_the_struck_share_only() -> void:
	var player := _player()
	var enemy := _enemy()
	# A blow from the front or a side has no struck share on the bottom edge: it is inked as any unstruck edge.
	for from: Vector3 in [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		var overlay := _overlay()
		overlay.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, from, 15.0), Transform3D.IDENTITY)
		assert_almost_eq(overlay.drawn_strength(HurtOverlay.Edge.BOTTOM), overlay.edge_strength(HurtOverlay.Edge.TOP), 0.0001,
				"the bottom is no heavier than the top on a blow from %s" % str(from))
	# Behind, the more behind the heavier: a blow a little off dead behind is inked less than one dead behind.
	var dead := _overlay()
	dead.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.BACK, 15.0), Transform3D.IDENTITY)
	var slant := _overlay()
	slant.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3(0.7, 0.0, 0.7).normalized(), 15.0), Transform3D.IDENTITY)
	assert_gt(dead.drawn_strength(HurtOverlay.Edge.BOTTOM), slant.drawn_strength(HurtOverlay.Edge.BOTTOM))


func test_the_extra_ink_fades_with_the_edges() -> void:
	var player := _player()
	var overlay := _overlay()
	overlay.on_player_hit(_hit(_enemy(), player, CombatTypes.HitTier.HEAVY, Vector3.BACK, 20.0), Transform3D.IDENTITY)
	overlay.advance(Tuning.data.hurt_overlay_fade_s * 2.0)
	assert_false(overlay.is_live(), "the extra ink is gone with the rest")
	assert_almost_eq(overlay.drawn_strength(HurtOverlay.Edge.BOTTOM), 0.0, 0.0001)


## VF2-FEEL (vfinal-world-01, -code-01): the depth was multiplied by the share of the strongest edge, and the
## bottom edge's gain put that share at up to 1.5, so every clean heavy blow from behind deepened the vignette
## (0.32, 0.48, 0.72, 1.08 ...) and nothing lowered it. Edge strengths and the depth stay bounded.
func _assert_bounded_after(hits: Array[Dictionary], gap_s: float, what: String) -> void:
	var player := _player()
	var enemy := _enemy()
	var overlay := _overlay()
	var limit := Tuning.data.hurt_overlay_depth_max
	for part: Dictionary in hits:
		overlay.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, part.from, part.damage), Transform3D.IDENTITY)
		assert_lte(overlay.depth_share(), limit + 0.0001, "%s: the depth stays within depth_max" % what)
		for edge: int in 4:
			assert_lte(overlay.edge_strength(edge), 1.0 + 0.0001, "%s: a stored edge stays at 1 or below" % what)
		overlay.advance(gap_s)


func test_full_damage_hits_from_behind_leave_the_depth_within_its_maximum() -> void:
	var hits: Array[Dictionary] = []
	for i: int in 8:
		hits.append({from = Vector3.BACK, damage = 20.0})
	_assert_bounded_after(hits, 2.0, "20 damage, 2 s apart")
	_assert_bounded_after(hits, 0.25, "20 damage, 0.25 s apart")
	_assert_bounded_after(hits, 0.0, "20 damage, at once")


func test_three_thug_pipe_hits_from_behind_leave_the_depth_within_its_maximum() -> void:
	var pipe := (load("res://game/combat/moves/thug_pipe_1.tres") as MoveData).damage
	var hits: Array[Dictionary] = []
	for i: int in 3:
		hits.append({from = Vector3.BACK, damage = pipe})
	_assert_bounded_after(hits, 0.4, "the pipe, 0.4 s apart")


func test_a_burst_from_behind_and_the_sides_leaves_the_depth_within_its_maximum() -> void:
	var hits: Array[Dictionary] = []
	for i: int in 4:
		hits.append({from = Vector3.BACK, damage = 15.0})
		hits.append({from = Vector3.LEFT, damage = 15.0})
		hits.append({from = Vector3(0.5, 0.0, 1.0).normalized(), damage = 20.0})
	_assert_bounded_after(hits, 0.0, "a burst")


func test_a_heavy_blow_from_behind_is_as_deep_as_a_heavy_blow_from_the_front() -> void:
	var player := _player()
	var enemy := _enemy()
	var front := _overlay()
	front.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.FORWARD, 20.0), Transform3D.IDENTITY)
	var behind := _overlay()
	for i: int in 3:
		behind.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.BACK, 20.0), Transform3D.IDENTITY)
	assert_almost_eq(behind.depth_share(), front.depth_share(), 0.0001)


func test_the_bottom_strokes_have_a_floor_and_a_heavy_blows_are_no_longer_than_any_edges() -> void:
	var data := Tuning.data
	assert_gt(data.hurt_overlay_bottom_stroke_floor, 0.0, "a light jab's teeth clear the health panel")
	# The longest a tooth gets on any edge: the depth x the stroke's longest share, at full strength.
	var longest := data.hurt_overlay_depth_max * (data.hurt_overlay_stroke_len_min + data.hurt_overlay_stroke_len_range)
	assert_gt(longest, data.hurt_overlay_bottom_stroke_floor, "the floor is not what a heavy blow's teeth are")
	var overlay := _overlay()
	overlay.size = Vector2(1600.0, 900.0)
	overlay.on_player_hit(_hit(_enemy(), _player(), CombatTypes.HitTier.LIGHT, Vector3.BACK, 3.0), Transform3D.IDENTITY)
	var lengths := overlay.stroke_lengths_px(HurtOverlay.Edge.BOTTOM)
	assert_eq(lengths.size(), data.hurt_overlay_strokes)
	for length: float in lengths:
		assert_gte(length, data.hurt_overlay_bottom_stroke_floor * 900.0 - 0.01, "a light jab's bottom teeth clear the panel")
	# vf2check-feelworld-01: lifted to the floor, the comb stays jagged instead of a row of equal teeth.
	assert_gt(lengths.max() - lengths.min(), data.hurt_overlay_bottom_stroke_floor * 900.0 * 0.1,
			"a light jab's bottom teeth vary in length like every other edge's")
	var heavy := _overlay()
	heavy.size = Vector2(1600.0, 900.0)
	heavy.on_player_hit(_hit(_enemy(), _player(), CombatTypes.HitTier.HEAVY, Vector3.BACK, 20.0), Transform3D.IDENTITY)
	var front := _overlay()
	front.size = Vector2(1600.0, 900.0)
	front.on_player_hit(_hit(_enemy(), _player(), CombatTypes.HitTier.HEAVY, Vector3.FORWARD, 20.0), Transform3D.IDENTITY)
	var rear_max: float = heavy.stroke_lengths_px(HurtOverlay.Edge.BOTTOM).max()
	assert_lte(rear_max, longest * 900.0 + 0.01, "no tooth of a heavy rear blow passes the longest of any edge")
	assert_lte(rear_max, maxf(front.stroke_lengths_px(HurtOverlay.Edge.TOP).max(), 0.0) + data.hurt_overlay_bottom_stroke_floor * 900.0,
			"no further than a heavy front blow's reach plus the lift")


func test_the_strokes_have_an_ink_rim_that_is_ink_not_red() -> void:
	var data := TuningData.new()
	assert_gt(data.hurt_overlay_outline_width, 0.0, "a rim by default")
	var rim := data.hurt_overlay_outline_color
	assert_lt(maxf(rim.r, maxf(rim.g, rim.b)), 0.2, "dark ink")
	assert_gt(rim.a, 0.8, "opaque enough to read on any ground")
	assert_eq([data.hurt_overlay_outline_width, data.hurt_overlay_bottom_ink_gain, data.hurt_overlay_bottom_stroke_floor],
			[0.007, 1.5, 0.2], "the shipped look")


func test_the_overlay_fades_out_and_a_block_is_lighter() -> void:
	var player := _player()
	var enemy := _enemy()
	var clean := _overlay()
	clean.on_player_hit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT), Transform3D.IDENTITY)
	var blocked_hit := _hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT)
	blocked_hit.blocked = true
	var blocked := _overlay()
	blocked.on_player_hit(blocked_hit, Transform3D.IDENTITY)
	assert_lt(blocked.edge_strength(HurtOverlay.Edge.RIGHT), clean.edge_strength(HurtOverlay.Edge.RIGHT) * 0.5)
	assert_eq(blocked.stroke_strength(HurtOverlay.Edge.RIGHT), 0.0, "no strokes on a block")
	assert_gt(clean.stroke_strength(HurtOverlay.Edge.RIGHT), 0.0)
	clean.advance(Tuning.data.hurt_overlay_fade_s * 0.5)
	assert_true(clean.is_live())
	clean.advance(Tuning.data.hurt_overlay_fade_s)
	assert_false(clean.is_live(), "gone after the fade")


func test_the_overlay_listens_to_hits_on_the_player_only() -> void:
	var player := _player()
	var enemy := _enemy()
	var overlay := _overlay()
	CombatEvents.hit_landed.emit(_hit(player, enemy, CombatTypes.HitTier.HEAVY, Vector3.RIGHT))
	assert_false(overlay.is_live(), "a hit he lands draws nothing")
	CombatEvents.hit_landed.emit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, Vector3.RIGHT))
	assert_true(overlay.is_live())


func test_the_overlays_colour_is_not_red() -> void:
	var color := Tuning.data.hurt_overlay_color
	assert_lt(color.r, 0.3, "SPEC 10 reserves red")
	assert_lt(color.r, color.b + 0.1)


# --- The panel jolt -------------------------------------------------------------------------------


func test_the_health_panel_jolts_in_proportion_to_the_damage_and_settles() -> void:
	var small := PlayerHealthPanel.new()
	add_child_autofree(small)
	small.health = 100.0
	small.on_health_changed(97.0, 100.0)
	var big := PlayerHealthPanel.new()
	add_child_autofree(big)
	big.health = 100.0
	big.on_health_changed(80.0, 100.0)
	assert_gt(big._jolt_px, small._jolt_px)
	assert_gt(small._jolt_px, 0.0)
	assert_lte(big._jolt_px, Tuning.data.hurt_panel_jolt_max_px)
	assert_gt(big.jolt_offset().length(), 0.0)
	big._jolt_left = 0.0
	assert_eq(big.jolt_offset(), Vector2.ZERO, "settled")
	var healed := PlayerHealthPanel.new()
	add_child_autofree(healed)
	healed.health = 50.0
	healed.on_health_changed(80.0, 100.0)
	assert_eq(healed._jolt_left, 0.0, "healing does not jolt")


# --- Real hits: the bearing is the attacker's side (feedback-world-01) ---------------------------------


## Run one real hit on a real player: `scene` is the attacker's scene (a Punk or a Bruiser), `from` the
## unit vector (a world direction, the player looking down -Z) it stands along, `range_m` its distance.
## The hit comes out of HitDetector, with the contact on the player's own hurtbox. Returns the hit, the
## camera and the overlay (both listening to the event, the camera the viewport's).
## `pitch_deg` is the player's look pitch (negative looks down) and `carry`, when set, adds a roll and a
## punch of a earlier hit to the camera (and lets them reach their peak) before the attack.
func _real_hit(scene: PackedScene, from: Vector3, range_m: float, pitch_deg: float = 0.0, carry: bool = false) -> Dictionary:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	Tuning.data.cam_forward_offset_m = 0.0
	Tuning.data.cam_height_offset_m = 0.0
	TimeController.clear()
	PlaceholderAnims.warn_on_fallback = false
	var stage := Node3D.new()
	add_child_autofree(stage)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	var player := PlayerCharacter.new()
	stage.add_child(player)
	player.input.scripted = true
	player.look_pitch = deg_to_rad(pitch_deg)
	var director := preload("res://tests/fixtures/stub_director.gd").new()
	stage.add_child(director)
	var cam := FirstPersonCamera.new()
	stage.add_child(cam)
	cam.set_process(false)
	cam.player = player
	cam.make_current()
	cam.update_camera(DT)
	if carry:
		cam.add_roll(CARRIED_ROLL_DEG)
		cam.add_punch(Vector2(CARRIED_KICK_DEG, CARRIED_KICK_DEG))
		cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	var overlay := HurtOverlay.new()
	stage.add_child(overlay)
	var hits: Array[HitInfo] = []
	var on_hit := func(hit: HitInfo) -> void:
		if hit.victim == player:
			hits.append(hit)
	CombatEvents.hit_landed.connect(on_hit)
	var enemy := scene.instantiate() as EnemyActor
	enemy.position = from * range_m
	enemy.rotation.y = atan2(enemy.position.x, enemy.position.z)
	stage.add_child(enemy)
	for i: int in 10:
		await get_tree().physics_frame
	enemy.force_attack(0)
	for i: int in 240:
		if not hits.is_empty():
			break
		await get_tree().physics_frame
	CombatEvents.hit_landed.disconnect(on_hit)
	return {hit = hits[0] if not hits.is_empty() else null, cam = cam, overlay = overlay, player = player}


func _peak_roll(cam: FirstPersonCamera) -> float:
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	return cam.get_roll_deg()


## The struck edge carries the strokes, and every other edge far fewer (a real attacker is never exactly
## on an axis, so a few degrees of bearing leak a little onto a neighbour); on the sides and behind the
## vignette is also strongest there.
func _assert_edge(overlay: HurtOverlay, lit: int, others: Array[int], what: String, vignette: bool = true) -> void:
	var stroke := overlay.stroke_strength(lit)
	assert_gt(stroke, 0.0, "%s: strokes on the struck edge" % what)
	for edge: int in others:
		assert_lt(overlay.stroke_strength(edge), stroke * 0.3, "%s: far fewer strokes on edge %d" % [what, edge])
		if vignette:
			assert_lt(overlay.edge_strength(edge), overlay.edge_strength(lit), "%s: edge %d is weaker" % [what, edge])


func test_a_real_jab_from_the_front_lights_the_top_edge_and_rolls_either_way() -> void:
	var r := await _real_hit(PUNK_SCENE, Vector3(0.0, 0.0, -1.0), JAB_RANGE_M)
	assert_not_null(r.hit, "the jab landed")
	var overlay: HurtOverlay = r.overlay
	_assert_edge(overlay, HurtOverlay.Edge.TOP, [HurtOverlay.Edge.LEFT, HurtOverlay.Edge.RIGHT, HurtOverlay.Edge.BOTTOM],
			"from the front", false)
	assert_gt(absf(_peak_roll(r.cam)), 0.5, "a frontal blow still rolls the head, by the frontal share")


func test_a_real_jab_from_the_left_lights_the_left_edge_and_rolls_the_head_right() -> void:
	var r := await _real_hit(PUNK_SCENE, Vector3.LEFT, JAB_RANGE_M)
	assert_not_null(r.hit, "the jab landed")
	_assert_edge(r.overlay, HurtOverlay.Edge.LEFT, [HurtOverlay.Edge.RIGHT, HurtOverlay.Edge.TOP, HurtOverlay.Edge.BOTTOM],
			"from the left")
	assert_lt(_peak_roll(r.cam), -0.5, "tipped to the right, away from the blow")


func test_a_real_jab_from_the_right_lights_the_right_edge_and_rolls_the_head_left() -> void:
	var r := await _real_hit(PUNK_SCENE, Vector3.RIGHT, JAB_RANGE_M)
	assert_not_null(r.hit, "the jab landed")
	_assert_edge(r.overlay, HurtOverlay.Edge.RIGHT, [HurtOverlay.Edge.LEFT, HurtOverlay.Edge.TOP, HurtOverlay.Edge.BOTTOM],
			"from the right")
	assert_gt(_peak_roll(r.cam), 0.5, "tipped to the left, away from the blow")


func test_a_real_jab_from_behind_lights_the_bottom_edge() -> void:
	var r := await _real_hit(PUNK_SCENE, Vector3.BACK, JAB_RANGE_M)
	assert_not_null(r.hit, "the jab landed")
	_assert_edge(r.overlay, HurtOverlay.Edge.BOTTOM, [HurtOverlay.Edge.LEFT, HurtOverlay.Edge.RIGHT, HurtOverlay.Edge.TOP],
			"from behind")


func test_a_real_bruiser_smash_from_the_front_is_not_read_as_from_the_right() -> void:
	# The review's own case (feedback-world-01): the smash from straight ahead struck the right and bottom edges.
	var r := await _real_hit(BRUISER_SCENE, Vector3(0.0, 0.0, -1.0), SMASH_RANGE_M)
	assert_not_null(r.hit, "the smash landed")
	_assert_edge(r.overlay, HurtOverlay.Edge.TOP, [HurtOverlay.Edge.LEFT, HurtOverlay.Edge.RIGHT, HurtOverlay.Edge.BOTTOM],
			"the smash from the front", false)


func test_a_real_bruiser_smash_from_the_left_rolls_right() -> void:
	var r := await _real_hit(BRUISER_SCENE, Vector3.LEFT, SMASH_RANGE_M)
	assert_not_null(r.hit, "the smash landed")
	_assert_edge(r.overlay, HurtOverlay.Edge.LEFT, [HurtOverlay.Edge.RIGHT, HurtOverlay.Edge.TOP, HurtOverlay.Edge.BOTTOM],
			"the smash from the left")
	assert_lt(_peak_roll(r.cam), -0.5)


# --- The bearing is measured on the floor plane (verify-world-02) ----------------------------------------


## The sides of a Punk's jab and the edge each lights: ahead the top, behind the bottom, left and right
## their own. One real hit per test (a second stage in a test would feed its first player's hits to the
## new overlay too).
const SIDE_EDGES: Array[Dictionary] = [
	{from = Vector3(0.0, 0.0, -1.0), edge = HurtOverlay.Edge.TOP, name = "front"},
	{from = Vector3.BACK, edge = HurtOverlay.Edge.BOTTOM, name = "behind"},
	{from = Vector3.LEFT, edge = HurtOverlay.Edge.LEFT, name = "left"},
	{from = Vector3.RIGHT, edge = HurtOverlay.Edge.RIGHT, name = "right"},
]


## A real jab from side `side` (an index of SIDE_EDGES) at `pitch_deg`, the camera carrying a hit's roll and
## kick or not: the struck edge has the strokes and every other far fewer.
func _assert_side(side: int, pitch_deg: float, carry: bool) -> void:
	var s: Dictionary = SIDE_EDGES[side]
	var r := await _real_hit(PUNK_SCENE, s.from, JAB_RANGE_M, pitch_deg, carry)
	var label := "%s at pitch %.0f%s" % [s.name, pitch_deg, " carrying a hit" if carry else ""]
	assert_not_null(r.hit, "the jab landed: %s" % label)
	if r.hit == null:
		return
	var overlay: HurtOverlay = r.overlay
	var lit: int = s.edge
	assert_gt(overlay.stroke_strength(lit), 0.0, "strokes on the struck edge: %s" % label)
	for edge: int in 4:
		if edge != lit:
			assert_lt(overlay.stroke_strength(edge), overlay.stroke_strength(lit) * 0.3,
					"far fewer strokes on edge %d: %s" % [edge, label])


func test_a_real_jab_from_the_front_lights_the_top_edge_looking_down_45() -> void:
	await _assert_side(0, -45.0, false)


func test_a_real_jab_from_behind_lights_the_bottom_edge_looking_down_45() -> void:
	await _assert_side(1, -45.0, false)


func test_a_real_jab_from_the_left_lights_the_left_edge_looking_down_45() -> void:
	await _assert_side(2, -45.0, false)


func test_a_real_jab_from_the_right_lights_the_right_edge_looking_down_45() -> void:
	await _assert_side(3, -45.0, false)


func test_a_real_jab_from_behind_lights_the_bottom_edge_looking_down_60() -> void:
	await _assert_side(1, -60.0, false)


func test_a_real_jab_from_the_front_lights_the_top_edge_looking_down_60() -> void:
	await _assert_side(0, -60.0, false)


func test_a_real_jab_from_the_front_lights_the_top_edge_looking_up_30() -> void:
	await _assert_side(0, 30.0, false)


func test_a_real_jab_from_behind_lights_the_bottom_edge_looking_up_30() -> void:
	await _assert_side(1, 30.0, false)


func test_a_real_jab_from_the_left_lights_the_left_edge_looking_up_30() -> void:
	await _assert_side(2, 30.0, false)


func test_a_real_jab_from_behind_lights_the_bottom_edge_with_a_carried_roll_and_kick() -> void:
	await _assert_side(1, 0.0, true)


func test_a_real_jab_from_the_front_lights_the_top_edge_with_a_carried_roll_and_kick() -> void:
	await _assert_side(0, 0.0, true)


func test_a_real_jab_from_the_right_lights_the_right_edge_looking_down_with_a_carried_roll_and_kick() -> void:
	await _assert_side(3, -45.0, true)


func test_the_bearing_ignores_pitch_roll_and_the_attackers_height_under_the_lens() -> void:
	var player := _player()
	var enemy := _enemy()
	var hit := _hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.BACK)
	hit.direction = Vector3.ZERO
	var eye := Vector3(0.0, EYE_Y, 0.0)
	var cases: Array[Dictionary] = [
		{at = Vector3(0.0, 0.0, 0.9), want = PI},
		{at = Vector3(0.0, 0.0, -0.9), want = 0.0},
		{at = Vector3(0.9, 0.0, 0.0), want = PI / 2.0},
		{at = Vector3(-0.9, 0.0, 0.0), want = -PI / 2.0},
	]
	for pitch: float in [-80.0, -60.0, -45.0, -30.0, 0.0, 30.0, 60.0]:
		for roll: float in [0.0, 12.0, -20.0]:
			var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), 0.0, deg_to_rad(roll)), EULER_ORDER_YXZ)
			var view := Transform3D(basis, eye)
			for c: Dictionary in cases:
				enemy.global_position = c.at
				assert_almost_eq(absf(FirstPersonCamera.hit_bearing(view, hit)), absf(float(c.want)), 0.001,
						"pitch %.0f roll %.0f, attacker at %s" % [pitch, roll, str(c.at)])
	# A yawed view: the attacker is measured against where the player looks.
	var yawed := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-45.0), deg_to_rad(90.0), 0.0), EULER_ORDER_YXZ), eye)
	enemy.global_position = Vector3(0.0, 0.0, -0.9)  # the player looks along -X: this is on his right
	assert_almost_eq(FirstPersonCamera.hit_bearing(yawed, hit), PI / 2.0, 0.001, "a yawed, pitched view")


func test_the_overlay_reads_the_view_without_the_kick_of_a_previous_hit() -> void:
	var player := _player()
	var cam := _camera(player)
	cam.make_current()
	var enemy := _enemy()
	enemy.global_position = Vector3(0.0, 0.0, 0.9)
	cam.add_roll(CARRIED_ROLL_DEG * 2.0)
	cam.add_punch(Vector2(CARRIED_KICK_DEG, CARRIED_KICK_DEG))
	cam.update_camera(cam.punch_duration_s * cam.punch_attack_share)
	var overlay := HurtOverlay.new()
	add_child_autofree(overlay)
	var hit := _hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.BACK)
	overlay.call(&"_on_hit_landed", hit)
	assert_gt(overlay.stroke_strength(HurtOverlay.Edge.BOTTOM), 0.0, "from behind: the bottom edge")
	assert_almost_eq(overlay.stroke_strength(HurtOverlay.Edge.LEFT), 0.0, 0.001, "not tipped onto the left by the carried roll")
	assert_almost_eq(overlay.stroke_strength(HurtOverlay.Edge.RIGHT), 0.0, 0.001, "nor onto the right")


func test_the_real_contact_is_on_the_players_own_hurtbox_and_says_nothing_of_the_side() -> void:
	# Why the bearing reads the attacker: the contact is within a body's width of the lens, whichever
	# side the blow came from, and often on the wrong side of it.
	var r := await _real_hit(PUNK_SCENE, Vector3.LEFT, JAB_RANGE_M)
	var hit: HitInfo = r.hit
	assert_not_null(hit)
	var view := (r.cam as FirstPersonCamera).view_transform()
	assert_lt((hit.contact_point - view.origin).length(), 0.5, "the contact is a few tenths from the lens")
	assert_almost_eq(rad_to_deg(FirstPersonCamera.hit_bearing(view, hit)), -90.0, 15.0, "the attacker is on the left")


func test_the_bearing_reads_the_attacker_not_the_contact() -> void:
	var player := _player()
	var enemy := _enemy()
	enemy.global_position = Vector3(0.0, 0.0, -2.0)
	var view := Transform3D(Basis.IDENTITY, Vector3(0.0, EYE_Y, 0.0))
	var hit := _hit(enemy, player, CombatTypes.HitTier.LIGHT, Vector3.BACK)
	# A contact behind and right of the lens, as a real one often is; the attacker stands ahead.
	hit.contact_point = view.origin + Vector3(0.2, -0.1, 0.25)
	hit.direction = Vector3(0.0, 0.0, 1.0)
	assert_almost_eq(FirstPersonCamera.hit_bearing(view, hit), 0.0, 0.001, "ahead, whatever the contact says")
	enemy.global_position = Vector3(2.0, 0.0, 0.0)
	assert_almost_eq(FirstPersonCamera.hit_bearing(view, hit), PI / 2.0, 0.001, "from the right")
	enemy.global_position = Vector3(0.0, 0.0, 2.0)
	assert_almost_eq(absf(FirstPersonCamera.hit_bearing(view, hit)), PI, 0.001, "from behind")


func test_the_bearing_falls_back_to_the_push_without_an_attacker_or_at_the_lens() -> void:
	var view := Transform3D(Basis.IDENTITY, Vector3(0.0, EYE_Y, 0.0))
	var hit := HitInfo.new()
	hit.contact_point = view.origin + Vector3(0.0, 0.0, 0.2)
	hit.direction = Vector3.RIGHT  # pushed to the right: it came from the left
	assert_almost_eq(FirstPersonCamera.hit_bearing(view, hit), -PI / 2.0, 0.001, "no attacker: the push")
	var enemy := _enemy()
	enemy.global_position = Vector3(0.0, 0.0, 0.0)  # at the lens horizontally
	hit.attacker = enemy
	assert_almost_eq(FirstPersonCamera.hit_bearing(view, hit), -PI / 2.0, 0.001, "at the lens: the push")
	Tuning.data.hurt_bearing_min_m = 0.0
	enemy.global_position = Vector3(0.0, 0.0, -0.5)
	assert_almost_eq(FirstPersonCamera.hit_bearing(view, hit), 0.0, 0.001, "the minimum is a tunable")


func test_the_hurt_shape_numbers_are_tunables_with_todays_defaults() -> void:
	var data := TuningData.new()
	assert_eq([data.hurt_bearing_min_m, data.hurt_roll_frontal_sine, data.hurt_overlay_mid_stop,
			data.hurt_overlay_mid_alpha, data.hurt_overlay_stroke_len_min, data.hurt_overlay_stroke_len_range,
			data.hurt_overlay_stroke_len_floor, data.hurt_overlay_stroke_width, data.hurt_overlay_stroke_lean,
			data.hurt_overlay_stroke_jitter, data.hurt_overlay_stroke_gain, data.hurt_overlay_top_threshold,
			data.hurt_overlay_blocked_depth_gain, data.hurt_panel_jolt_rate_x, data.hurt_panel_jolt_rate_y],
			[0.05, 0.1, 0.4, 0.4, 0.55, 0.7, 0.3, 0.4, 0.6, 0.3, 1.5, 0.5, 2.0, 95.0, 113.0], "unchanged on screen")
	# And they reach the screen: a shorter stroke range shortens what the overlay draws; the jolt rate moves the rattle.
	var panel := PlayerHealthPanel.new()
	add_child_autofree(panel)
	panel.health = 100.0
	panel.on_health_changed(80.0, 100.0)
	panel._time = 0.01
	var before := panel.jolt_offset()
	Tuning.data.hurt_panel_jolt_rate_x = 200.0
	assert_ne(panel.jolt_offset().x, before.x, "the rattle's rate is read from Tuning")
