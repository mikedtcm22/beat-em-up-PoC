extends GutTest
## Audio and rumble (game/audio/, M2 WP3; Spec §6 "Audio" and the audio and rumble rows):
## the generated SFX bank, the AudioDirector's layers per tier, no immediate repeats, the
## pitch and volume variation, positional placement, grunts, whiff, block, wind-up and
## music sounds, the rear muffle, and the RumbleDirector's pulses with the Input calls
## stubbed. Events are emitted on CombatEvents directly, with plain Node3Ds in the "enemy"
## and "player" groups as actors; the last tests play a real jab in the test room.

const ROOM := preload("res://game/level/test_room.tscn")
const IMPACT_POOLS: Array[StringName] = [
	&"whoosh", &"thud", &"crack", &"crunch", &"body_fall", &"sub_thump",
	&"block_clack", &"parry_ting", &"guard_break",
]

var _director: AudioDirector
var _rumble: RumbleDirector
## Every one-shot the director played: {pool, voice, stream, at, pitch, volume_db, bus}.
var _plays: Array[Dictionary] = []
## Every rumble pulse: Vector3(weak, strong, seconds).
var _pulses: Array[Vector3] = []
var _enemy: Node3D
var _attacker: Node3D


func before_each() -> void:
	Tuning.apply(TuningData.new())
	_plays.clear()
	_pulses.clear()
	_director = AudioDirector.new()
	add_child_autofree(_director)
	_director.rng.seed = 1234
	_director.played.connect(_on_played)
	# Heard from the origin, looking down -Z.
	_director.listener.global_transform = Transform3D.IDENTITY
	_director.listener.make_current()
	_rumble = RumbleDirector.new()
	_rumble.vibrate = func(weak: float, strong: float, seconds: float) -> void:
		_pulses.append(Vector3(weak, strong, seconds))
	add_child_autofree(_rumble)
	_enemy = _actor("Dummy1", &"enemy", Vector3(0.0, 0.0, -1.0))
	_attacker = _actor("Dummy2", &"enemy", Vector3(0.0, 0.0, -2.0))


func _on_played(pool: StringName, voice: AudioStreamPlayer3D) -> void:
	_plays.append({
		pool = pool,
		voice = voice,
		stream = voice.stream,
		at = voice.global_position,
		pitch = voice.pitch_scale,
		volume_db = voice.volume_db,
		bus = voice.bus,
	})


func _actor(actor_name: String, group: StringName, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = actor_name
	node.add_to_group(group)
	add_child_autofree(node)
	node.global_position = at
	return node


func _hit(tier: CombatTypes.HitTier, victim: Node3D = null, attacker: Node3D = null,
		at: Vector3 = Vector3(0.1, 1.5, -0.8)) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker if attacker else _attacker
	hit.victim = victim if victim else _enemy
	hit.tier = tier
	hit.contact_point = at
	return hit


## The pools played, in order (without the voices: grunts and efforts).
func _pools(exclude_voices: bool = true) -> Array:
	var out := []
	for play in _plays:
		var pool: StringName = play.pool
		if exclude_voices and pool in [&"grunt", &"player_grunt", &"effort"]:
			continue
		out.append(pool)
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- The bank -----------------------------------------------------------------------------


func test_bank_has_every_pool_the_brief_asks_for() -> void:
	var bank := SfxBank.new()
	var minimum := {
		&"whoosh": 3, &"thud": 3, &"crack": 3, &"crunch": 3, &"body_fall": 2, &"sub_thump": 2,
		&"grunt": 3, &"player_grunt": 2, &"effort": 2,
		&"block_clack": 2, &"parry_ting": 2, &"guard_break": 2, &"music_loop": 1,
	}
	for pool: StringName in minimum:
		assert_gte(bank.count(pool), int(minimum[pool]), "%s variants" % pool)
		for stream: AudioStream in bank.pools.get(pool, []):
			assert_true(stream is AudioStreamWAV, "%s is a WAV" % pool)
			assert_gt(stream.get_length(), 0.05, "%s has sound" % pool)
			if pool != &"music_loop":
				assert_lt(stream.get_length(), 1.5, "%s is a one-shot" % pool)
	var music := bank.pick(&"music_loop", RandomNumberGenerator.new()) as AudioStreamWAV
	assert_ne(music.loop_mode, AudioStreamWAV.LOOP_DISABLED, "the music loop loops (its .import: loop mode Forward)")
	assert_null(bank.pick(&"no_such_pool", RandomNumberGenerator.new()))


func test_bank_never_picks_the_same_variant_twice_in_a_row() -> void:
	var bank := SfxBank.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for pool: StringName in bank.pools:
		if bank.count(pool) < 2:
			continue
		var seen := {}
		var last: AudioStream = null
		for i in 200:
			var stream := bank.pick(pool, rng)
			assert_ne(stream, last, "%s pick %d repeats the last one" % [pool, i])
			last = stream
			seen[stream] = true
		assert_eq(seen.size(), bank.count(pool), "%s: every variant comes up" % pool)


# --- Hits -----------------------------------------------------------------------------


func test_each_tier_layers_its_one_shots() -> void:
	var expected := {
		CombatTypes.HitTier.LIGHT: [&"whoosh", &"thud"],
		CombatTypes.HitTier.HEAVY: [&"whoosh", &"thud", &"crack"],
		CombatTypes.HitTier.FINISHER: [&"whoosh", &"thud", &"crunch", &"body_fall", &"sub_thump"],
	}
	for tier: CombatTypes.HitTier in expected:
		_plays.clear()
		CombatEvents.hit_landed.emit(_hit(tier))
		assert_eq(_pools(), expected[tier], CombatTypes.tier_name(tier))


func test_layers_play_at_the_contact_point_with_the_tuned_distances() -> void:
	Tuning.data.sfx_unit_size_m = 4.5
	Tuning.data.sfx_max_distance_m = 25.0
	var at := Vector3(1.2, 1.4, -2.3)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, null, null, at))
	assert_eq(_pools().size(), 5)
	for play in _plays:
		if play.pool in IMPACT_POOLS:
			assert_almost_eq(play.at as Vector3, at, Vector3.ONE * 0.001, "%s at the contact point" % play.pool)
			var voice: AudioStreamPlayer3D = play.voice
			assert_eq(voice.unit_size, 4.5)
			assert_eq(voice.max_distance, 25.0)
			assert_eq(voice.max_db, 0.0, "never boosted near the listener")
			assert_true(voice.playing or voice.has_stream_playback(), "%s started" % play.pool)


func test_pitch_and_volume_vary_within_the_tuned_range() -> void:
	var pitches: Array[float] = []
	var gains: Array[float] = []
	for i in 300:
		CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT))
	for play in _plays:
		if play.pool != &"thud":
			continue
		pitches.append(play.pitch)
		gains.append(db_to_linear(float(play.volume_db) - Tuning.data.thud_db))
	assert_eq(pitches.size(), 300)
	assert_between(pitches.min(), 0.92 - 0.0001, 1.0, "pitch down at most 8%")
	assert_between(pitches.max(), 1.0, 1.08 + 0.0001, "pitch up at most 8%")
	assert_between(gains.min(), 0.92 - 0.0001, 1.0, "volume down at most 8%")
	assert_between(gains.max(), 1.0, 1.08 + 0.0001, "volume up at most 8%")
	assert_gt(pitches.max() - pitches.min(), 0.12, "pitch uses most of the range")
	assert_gt(gains.max() - gains.min(), 0.12, "volume uses most of the range")
	# Variation 0: exactly the layer's volume and pitch.
	Tuning.data.sfx_pitch_variation = 0.0
	Tuning.data.sfx_volume_variation = 0.0
	_plays.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY))
	for play in _plays:
		if play.pool in IMPACT_POOLS:
			assert_eq(play.pitch, 1.0)
			assert_almost_eq(float(play.volume_db), AudioDirector.layer_db(play.pool), 0.0001)


func test_no_layer_repeats_a_sample_twice_in_a_row() -> void:
	for i in 60:
		CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER))
	var last := {}
	var count := 0
	for play in _plays:
		if last.has(play.pool):
			assert_ne(play.stream, last[play.pool], "%s repeats" % play.pool)
			count += 1
		last[play.pool] = play.stream
	assert_gt(count, 250)


func test_layer_volumes_follow_tuning_live() -> void:
	Tuning.data.sfx_volume_variation = 0.0
	Tuning.data.crack_db = -17.0
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY))
	var cracks := _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"crack")
	assert_eq(cracks.size(), 1)
	assert_almost_eq(float(cracks[0].volume_db), -17.0, 0.0001)
	Tuning.data.sfx_volume_db = -12.0
	await _frames(1)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioDirector.SFX_BUS)), -12.0, 0.001)


func test_flying_bodies_hit_without_a_whoosh() -> void:
	var hit := _hit(CombatTypes.HitTier.HEAVY)
	hit.is_body_impact = true
	hit.input_timing = &"body"
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pools(), [&"thud", &"crack"])
	# A thrown weapon still flew through the air.
	_plays.clear()
	hit = _hit(CombatTypes.HitTier.HEAVY)
	hit.is_body_impact = true
	hit.input_timing = &"thrown"
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pools(), [&"whoosh", &"thud", &"crack"])


# --- Grunts -------------------------------------------------------------------------------


func test_enemies_grunt_when_hit_at_their_own_pitch_and_not_too_often() -> void:
	Tuning.data.sfx_pitch_variation = 0.0
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT))
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT))
	var grunts := _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"grunt")
	assert_eq(grunts.size(), 1, "a second hit within grunt_min_interval_ms is silent")
	assert_almost_eq(grunts[0].at as Vector3, _enemy.global_position, Vector3.ONE * 0.001, "at the victim")
	assert_almost_eq(float(grunts[0].pitch), AudioDirector.voice_pitch(_enemy), 0.0001)
	assert_ne(AudioDirector.voice_pitch(_enemy), AudioDirector.voice_pitch(_attacker), "voices differ per actor")
	assert_between(AudioDirector.voice_pitch(_enemy), 0.9, 1.1)
	# After the interval it grunts again.
	await _frames(int(ceil(Tuning.data.grunt_min_interval_ms / 1000.0 * 60.0)) + 2)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT))
	grunts = _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"grunt")
	assert_eq(grunts.size(), 2)


func test_the_player_grunts_with_its_own_voice() -> void:
	var player := _actor("Player", &"player", Vector3(0.0, 0.0, 0.0))
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY, player, _enemy))
	var voices := _plays.filter(func(p: Dictionary) -> bool: return p.pool in [&"grunt", &"player_grunt"])
	assert_eq(voices.size(), 1)
	assert_eq(voices[0].pool, &"player_grunt")


# --- Whiffs, blocks, wind-ups -----------------------------------------------------------


func test_a_whiff_is_a_whoosh_and_no_impact() -> void:
	Tuning.data.sfx_volume_variation = 0.0
	var move := load("res://game/combat/moves/jab_1.tres") as MoveData
	CombatEvents.attack_whiffed.emit(_attacker, move)
	assert_eq(_pools(false), [&"whoosh"])
	assert_almost_eq(float(_plays[0].volume_db), Tuning.data.whiff_db, 0.0001)
	assert_almost_eq(_plays[0].at as Vector3, _attacker.global_position, Vector3.ONE * 0.001)


func test_blocks_clack_parries_ting_and_guard_breaks_crash() -> void:
	var hit := _hit(CombatTypes.HitTier.HEAVY)
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pools(false), [&"whoosh", &"block_clack"], "a block: no thud, no grunt")
	_plays.clear()
	hit = _hit(CombatTypes.HitTier.LIGHT)
	hit.blocked = true
	hit.perfect_block = true
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pools(false), [&"whoosh", &"parry_ting"], "a parry")
	_plays.clear()
	hit = _hit(CombatTypes.HitTier.LIGHT)
	hit.blocked = true
	hit.guard_broken = true
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pools(false), [&"whoosh", &"block_clack", &"guard_break"], "a guard break")


func test_a_windup_plays_an_effort_and_a_whoosh_at_the_attacker() -> void:
	var move := load("res://game/combat/moves/dummy_jab.tres") as MoveData
	CombatEvents.windup_started.emit(_attacker, move)
	assert_eq(_pools(false), [&"effort", &"whoosh"])
	for play in _plays:
		assert_almost_eq(play.at as Vector3, _attacker.global_position, Vector3.ONE * 0.001)
	_plays.clear()
	Tuning.data.rear_warning_audio = false
	CombatEvents.windup_started.emit(_attacker, move)
	assert_eq(_plays.size(), 0, "rear_warning_audio off: silent")


func test_sounds_behind_the_listener_are_muffled() -> void:
	var front := _director.play(&"thud", Vector3(0.0, 1.0, -3.0), 0.0)
	var side := _director.play(&"thud", Vector3(3.0, 1.0, 0.0), 0.0)
	var behind := _director.play(&"thud", Vector3(0.5, 1.0, 3.0), 0.0)
	assert_eq(front.bus, AudioDirector.SFX_BUS)
	assert_eq(side.bus, AudioDirector.SFX_BUS, "90 degrees off is not behind")
	assert_eq(behind.bus, AudioDirector.REAR_BUS)
	# Turned around, the same spots swap.
	_director.listener.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	assert_true(_director.is_behind_listener(Vector3(0.0, 1.0, -3.0)))
	assert_false(_director.is_behind_listener(Vector3(0.5, 1.0, 3.0)))
	# The rear bus low-passes at the tuned cutoff, into the SFX bus.
	Tuning.data.rear_muffle_hz = 1800.0
	await _frames(1)
	var rear := AudioServer.get_bus_index(AudioDirector.REAR_BUS)
	assert_eq(AudioServer.get_bus_send(rear), AudioDirector.SFX_BUS)
	var low_pass := AudioServer.get_bus_effect(rear, 0) as AudioEffectLowPassFilter
	assert_not_null(low_pass)
	assert_eq(low_pass.cutoff_hz, 1800.0)


func test_the_voice_pool_takes_the_oldest_when_all_are_busy() -> void:
	var used := {}
	for i in _director.voice_count * 3:
		var voice := _director.play(&"whoosh", Vector3(0.0, 1.0, -2.0), 0.0)
		assert_not_null(voice)
		used[voice] = true
	assert_eq(used.size(), _director.voice_count, "every voice is used, and no more are made")
	var voices := _director.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D)
	assert_eq(voices.size(), _director.voice_count)


func test_music_is_off_by_default_and_follows_the_toggle() -> void:
	await _frames(2)
	assert_false(_director.music.playing, "off by default (Spec §13: an open question)")
	Tuning.data.music_enabled = true
	Tuning.data.music_volume_db = -20.0
	await _frames(2)
	assert_true(_director.music.playing)
	assert_eq(_director.music.bus, AudioDirector.MUSIC_BUS)
	assert_eq(_director.music.volume_db, -20.0)
	Tuning.data.music_enabled = false
	await _frames(2)
	assert_false(_director.music.playing)


# --- Rumble -------------------------------------------------------------------------------


func test_rumble_pulses_per_tier_for_the_players_hits() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	var t := Tuning.data
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT, _enemy, player))
	assert_eq(_pulses, [Vector3(t.rumble_light_weak, t.rumble_light_strong, t.rumble_light_ms / 1000.0)] as Array[Vector3], "light: short and low")
	_pulses.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY, _enemy, player))
	assert_eq(_pulses, [Vector3(t.rumble_heavy_weak, t.rumble_heavy_strong, t.rumble_heavy_ms / 1000.0)] as Array[Vector3], "heavy: medium")
	assert_gt(t.rumble_heavy_ms, t.rumble_light_ms)
	assert_gt(t.rumble_heavy_weak + t.rumble_heavy_strong, t.rumble_light_weak + t.rumble_light_strong)
	# Taking a hit rumbles too.
	_pulses.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT, player, _enemy))
	assert_eq(_pulses.size(), 1, "the player hit")
	# Nobody's hit but the dummies': nothing.
	_pulses.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, _enemy, _attacker))
	assert_eq(_pulses.size(), 0)
	assert_eq(_rumble.queued_pulses(), 0)


func test_a_finisher_rumbles_a_strong_double_pulse() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	var t := Tuning.data
	var strong := Vector3(t.rumble_finisher_weak, t.rumble_finisher_strong, t.rumble_finisher_ms / 1000.0)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, _enemy, player))
	assert_eq(_pulses, [strong] as Array[Vector3])
	assert_gte(strong.y, t.rumble_heavy_strong, "stronger than heavy")
	# The second pulse comes rumble_finisher_ms + rumble_finisher_gap_ms later (real time).
	var due := (t.rumble_finisher_ms + t.rumble_finisher_gap_ms) / 1000.0
	await _frames(int(floor(due * 60.0)) - 2)
	assert_eq(_pulses.size(), 1, "not yet")
	await _frames(4)
	assert_eq(_pulses, [strong, strong] as Array[Vector3])


func test_blocks_tick_and_guard_breaks_pulse_heavy() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	var t := Tuning.data
	var hit := _hit(CombatTypes.HitTier.FINISHER, player, _enemy)
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	hit = _hit(CombatTypes.HitTier.LIGHT, _enemy, player)
	hit.blocked = true
	hit.perfect_block = true
	CombatEvents.hit_landed.emit(hit)
	var tick := Vector3(t.rumble_block_weak, t.rumble_block_strong, t.rumble_block_ms / 1000.0)
	assert_eq(_pulses, [tick, tick] as Array[Vector3], "a block and a parry: light ticks")
	assert_eq(_rumble.queued_pulses(), 0, "no double pulse on a blocked finisher")
	assert_lt(t.rumble_block_ms, t.rumble_light_ms)
	_pulses.clear()
	hit = _hit(CombatTypes.HitTier.LIGHT, player, _enemy)
	hit.blocked = true
	hit.guard_broken = true
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pulses, [Vector3(t.rumble_heavy_weak, t.rumble_heavy_strong, t.rumble_heavy_ms / 1000.0)] as Array[Vector3])


func test_rumble_strength_scales_and_the_toggle_turns_it_off() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	var t := Tuning.data
	t.rumble_strength = 0.5
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY, _enemy, player))
	assert_almost_eq(_pulses[0], Vector3(t.rumble_heavy_weak * 0.5, t.rumble_heavy_strong * 0.5, t.rumble_heavy_ms / 1000.0), Vector3.ONE * 0.0001)
	_pulses.clear()
	t.rumble_enabled = false
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, _enemy, player))
	await _frames(30)
	assert_eq(_pulses.size(), 0)
	# Switched off between the two pulses of a finisher: the second never comes.
	t.rumble_enabled = true
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, _enemy, player))
	t.rumble_enabled = false
	await _frames(30)
	assert_eq(_pulses.size(), 1)


# --- In the test room ---------------------------------------------------------------------


func test_the_test_room_hears_a_real_jab_from_the_players_eyes() -> void:
	# The fixture's own directors would double every sound: this test uses the room's.
	_director.free()
	_rumble.free()
	var room: Node3D = ROOM.instantiate()
	add_child_autofree(room)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var director := get_tree().get_first_node_in_group(&"audio_director") as AudioDirector
	var rumble := get_tree().get_first_node_in_group(&"rumble_director") as RumbleDirector
	assert_not_null(director, "the test room builds an AudioDirector")
	assert_not_null(rumble, "the test room builds a RumbleDirector")
	if director == null or rumble == null:
		return
	director.played.connect(_on_played)
	rumble.vibrate = func(weak: float, strong: float, seconds: float) -> void:
		_pulses.append(Vector3(weak, strong, seconds))
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var dummies: Array = room.get(&"dummies")
	for i in dummies.size():
		var dummy: TrainingDummy = dummies[i]
		dummy.sparring = false
		var pos := player.global_position + player.global_basis * Vector3(0.0, 0.0, -1.6) if i == 0 else Vector3(30.0 + i * 3.0, 0.0, -30.0)
		var to_player := player.global_position - pos
		dummy.set_post(pos, atan2(-to_player.x, -to_player.z), true)
	for i in 10:
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(director.listener.is_current(), "the listener rides the player")
	var eye := player.get_eye_transform().origin
	assert_almost_eq(director.listener.global_position, eye, Vector3.ONE * 0.05, "at the player's eyes")
	assert_almost_eq(-director.listener.global_basis.z, -player.get_look_basis().z, Vector3.ONE * 0.01, "looking where the player looks")
	_plays.clear()
	var landed: Array[HitInfo] = []
	var on_hit := func(hit: HitInfo) -> void: landed.append(hit)
	CombatEvents.hit_landed.connect(on_hit)
	player.input.push_press(&"P", 2)
	for i in 40:
		await get_tree().physics_frame
		if not landed.is_empty():
			break
	CombatEvents.hit_landed.disconnect(on_hit)
	assert_eq(landed.size(), 1, "the jab lands")
	if landed.is_empty():
		return
	assert_eq(_pools(), [&"whoosh", &"thud"], "a light hit's layers")
	for play in _plays:
		if play.pool in IMPACT_POOLS:
			assert_almost_eq(play.at as Vector3, landed[0].contact_point, Vector3.ONE * 0.001)
	assert_true(_pools(false).has(&"grunt"), "the dummy grunts")
	assert_eq(_pulses.size(), 1, "the player's light hit rumbles once")
