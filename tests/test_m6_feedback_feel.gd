extends GutTest
## M6 playtest feedback, FB-FEEL (docs/reviews/M6/fix-feedback.md): no sting on GO (Debug's audio_sting_go),
## and the player feeling each hit he takes (Tuning "Hit feel" > "Hurt", Debug's hurt_feel_enabled): the
## victim's larger shake and punch, the head's roll away from the blow's side, the edge vignette
## (HurtOverlay), the health panel's jolt, blocked hits staying light, and the switch giving M6 back.

const DT := 1.0 / 60.0
## The eye point's height of the stand-in player.
const EYE_Y := 1.68

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
