extends GutTest
## Armor that reads (Milestone 3, M3-plan A6.1): a hit that armor absorbed (hit.armor_absorbed: a
## light hit on the Bruiser or the boss) shows a grey spark instead of the tier's burst, rings a low
## clank (the block clack pitched down) and reads ARMOR in grey in the combat log. Presentation
## only: the directors are fed hit_landed events and read, never write, game state. Every other hit
## is unchanged (a clean one still bursts, a block still sparks white).

const BRUISER_SCENE := preload("res://game/enemies/bruiser/bruiser.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const TICK := 1.0 / 60.0
const CONTACT := Vector3(0.0, 1.4, -1.2)

var _vfx: VfxDirector
var _camera: Camera3D
var _audio: AudioDirector
var _plays: Array[Dictionary] = []


func before_each() -> void:
	Tuning.apply(TuningData.new())
	TimeController.clear()
	TimeController.debug_scale = 1.0
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.make_current()
	_vfx = VfxDirector.new()
	add_child_autofree(_vfx)
	_vfx.set_process(false)
	_vfx.rng.seed = 1
	_plays.clear()
	_audio = AudioDirector.new()
	add_child_autofree(_audio)
	_audio.rng.seed = 1234
	_audio.played.connect(_on_played)
	_audio.listener.global_transform = Transform3D.IDENTITY
	_audio.listener.make_current()


func after_each() -> void:
	# A headless run is far ahead of the audio clock: a voice still sounding at exit would keep its
	# stream and print "resources still in use".
	for voice: Node in _audio.find_children("*", "AudioStreamPlayer3D", true, false):
		(voice as AudioStreamPlayer3D).stop()
	TimeController.clear()
	Tuning.apply(TuningData.new())


func after_all() -> void:
	# The audio mixer drops a stopped stream on its own thread: give it a moment before the run exits.
	OS.delay_msec(150)


func _on_played(pool: StringName, voice: AudioStreamPlayer3D) -> void:
	_plays.append({pool = pool, pitch = voice.pitch_scale})


func _hit(absorbed: bool, tier: CombatTypes.HitTier = CombatTypes.HitTier.LIGHT) -> HitInfo:
	var hit := HitInfo.new()
	hit.tier = tier
	hit.region = CombatTypes.Region.TORSO
	hit.contact_point = CONTACT
	hit.direction = Vector3.FORWARD
	hit.damage = 6.0
	hit.armor_absorbed = absorbed
	return hit


func _advance(seconds: float) -> void:
	for i in ceili(seconds / TICK):
		_vfx.advance(TICK)


func _pools() -> Array:
	var out := []
	for play in _plays:
		out.append(play.pool)
	return out


# --- The spark -----------------------------------------------------------------------------------


func test_an_absorbed_hit_shows_a_grey_spark_and_no_burst() -> void:
	CombatEvents.hit_landed.emit(_hit(true))
	assert_eq(_vfx.live_effects(&"block_spark").size(), 1, "a spark")
	assert_eq(_vfx.live_effects(&"burst_small").size(), 0, "not the light burst")
	var spark := _vfx.live_effects(&"block_spark")[0]
	var grey := Tuning.data.armor_spark_grey
	assert_almost_eq(spark.modulate.r, grey, 0.001, "tinted grey")
	assert_almost_eq(spark.modulate.g, grey, 0.001)
	assert_almost_eq(spark.modulate.b, grey, 0.001)
	assert_almost_eq(spark.size_m, Tuning.data.armor_spark_m * Tuning.data.vfx_scale, 0.001, "armor_spark_m wide")
	assert_lt(grey, 1.0, "grey is not the block spark's white")


func test_an_absorbed_hit_has_no_word_no_blood_and_no_speed_lines() -> void:
	Tuning.data.vfx_word_chance_light = 1.0
	Tuning.data.vfx_word_chance_heavy = 1.0
	Tuning.data.vfx_blood_chance_heavy = 1.0
	CombatEvents.hit_landed.emit(_hit(true))
	CombatEvents.hit_landed.emit(_hit(true, CombatTypes.HitTier.HEAVY))
	assert_eq(_vfx.live_effects(&"word").size(), 0, "no lettering: it registered and did nothing")
	assert_eq(_vfx.live_effects(&"blood_spray").size(), 0, "no blood")
	assert_false(_vfx.speed_lines.is_active())


func test_every_other_hit_is_unchanged_and_a_recycled_spark_loses_its_tint() -> void:
	CombatEvents.hit_landed.emit(_hit(false))
	assert_eq(_vfx.live_effects(&"burst_small").size(), 1, "a clean light hit still bursts")
	assert_eq(_vfx.live_effects(&"block_spark").size(), 0)
	_vfx.clear()
	CombatEvents.hit_landed.emit(_hit(true))
	_advance(Tuning.data.vfx_block_fx_s + 0.1)
	assert_eq(_vfx.live_effects(&"block_spark").size(), 0, "the grey spark is over")
	var block := _hit(false)
	block.blocked = true
	CombatEvents.hit_landed.emit(block)
	var white := _vfx.live_effects(&"block_spark")[0]
	assert_almost_eq(white.modulate.r, 1.0, 0.001, "a block's spark is white again (the pool reset the tint)")
	assert_almost_eq(white.modulate.b, 1.0, 0.001)


func test_the_spark_size_is_a_live_tunable() -> void:
	Tuning.data.armor_spark_m = 0.0
	CombatEvents.hit_landed.emit(_hit(true))
	assert_eq(_vfx.live_effects(&"block_spark").size(), 0, "0 m: none")
	Tuning.data.armor_spark_m = 0.5
	CombatEvents.hit_landed.emit(_hit(true))
	assert_almost_eq(_vfx.live_effects(&"block_spark")[0].size_m, 0.5 * Tuning.data.vfx_scale, 0.001)


# --- The clank -----------------------------------------------------------------------------------


func test_an_absorbed_hit_clanks_the_block_clack_pitched_down_with_no_thud_and_no_grunt() -> void:
	var enemy := Node3D.new()
	enemy.add_to_group(&"enemy")
	add_child_autofree(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -1.0)
	var hit := _hit(true)
	hit.victim = enemy
	hit.attacker = Node3D.new()
	add_child_autofree(hit.attacker)
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pools(), [&"whoosh", &"block_clack"], "the swing and the clank: no thud, no grunt")
	var clack: Dictionary = _plays[1]
	var pitch_range := Tuning.data.sfx_pitch_variation
	assert_almost_eq(float(clack.pitch), Tuning.data.armor_clank_pitch, Tuning.data.armor_clank_pitch * pitch_range + 0.001, "pitched down")
	assert_lt(float(clack.pitch), 0.8, "clearly below a block's clack")


func test_a_clean_hit_and_a_block_sound_as_they_did() -> void:
	var enemy := Node3D.new()
	enemy.add_to_group(&"enemy")
	add_child_autofree(enemy)
	var clean := _hit(false)
	clean.victim = enemy
	CombatEvents.hit_landed.emit(clean)
	assert_true(_pools().has(&"thud"), "a clean light hit thuds")
	assert_false(_pools().has(&"block_clack"))
	_plays.clear()
	var block := _hit(false)
	block.victim = enemy
	block.blocked = true
	CombatEvents.hit_landed.emit(block)
	var clack: Dictionary = _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"block_clack")[0]
	assert_gt(float(clack.pitch), 0.9, "a block's clack is at pitch")


# --- The log -------------------------------------------------------------------------------------


func test_the_combat_log_reads_armor_in_grey() -> void:
	var log_overlay := CombatLogOverlay.new()
	add_child_autofree(log_overlay)
	log_overlay.add_hit(_hit(true))
	log_overlay.add_hit(_hit(false))
	var lines := log_overlay.get_lines()
	assert_true(lines[0].contains(" ARMOR"), "the absorbed hit's line carries ARMOR (%s)" % lines[0])
	assert_false(lines[1].contains("ARMOR"), "a clean one does not")
	assert_eq(log_overlay.entries[0].color, HudStyle.MUTED, "grey")
	assert_ne(log_overlay.entries[1].color, HudStyle.MUTED)


# --- A real Bruiser ------------------------------------------------------------------------------


func test_a_real_jab_on_a_real_bruiser_shows_the_spark_and_the_clank_and_the_log_says_armor() -> void:
	Tuning.data.ai_frozen = true
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)
	var player := PlayerCharacter.new()
	add_child_autofree(player)
	player.input.scripted = true
	# An enemy with no director in the tree adds one beside itself: give it this one to find.
	add_child_autofree(StubDirector.new())
	var bruiser := BRUISER_SCENE.instantiate() as Bruiser
	bruiser.position = Vector3(0.0, 0.0, -1.2)
	bruiser.rotation.y = PI
	add_child_autofree(bruiser)
	var log_overlay := CombatLogOverlay.new()
	add_child_autofree(log_overlay)
	var feed := func(hit: HitInfo) -> void: log_overlay.add_hit(hit)
	CombatEvents.hit_landed.connect(feed)
	for i in 3:
		await get_tree().physics_frame
	player.input.push_press(&"P", 2)
	for i in 30:
		await get_tree().physics_frame
	CombatEvents.hit_landed.disconnect(feed)
	assert_lt(bruiser.health, bruiser.max_health, "the jab's damage landed")
	assert_eq(bruiser.state, CombatTypes.ActorState.FREE, "and it did not flinch")
	assert_eq(_vfx.live_effects(&"block_spark").size(), 1, "the grey spark")
	assert_eq(_vfx.live_effects(&"burst_small").size(), 0, "and no burst")
	assert_true(_pools().has(&"block_clack"), "the clank rang")
	assert_false(_pools().has(&"thud"), "with no thud")
	assert_true(log_overlay.get_lines()[0].contains(" ARMOR"), "ARMOR in the log (%s)" % log_overlay.get_lines()[0])
