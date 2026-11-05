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


# --- Real hits: the bearing is the attacker's side (feedback-world-01) ---------------------------------


## Run one real hit on a real player: `scene` is the attacker's scene (a Punk or a Bruiser), `from` the
## unit vector (a world direction, the player looking down -Z) it stands along, `range_m` its distance.
## The hit comes out of HitDetector, with the contact on the player's own hurtbox. Returns the hit, the
## camera and the overlay (both listening to the event, the camera the viewport's).
func _real_hit(scene: PackedScene, from: Vector3, range_m: float) -> Dictionary:
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
	var director := preload("res://tests/fixtures/stub_director.gd").new()
	stage.add_child(director)
	var cam := FirstPersonCamera.new()
	stage.add_child(cam)
	cam.set_process(false)
	cam.player = player
	cam.make_current()
	cam.update_camera(DT)
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
