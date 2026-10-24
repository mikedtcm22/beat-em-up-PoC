extends GutTest
## Audio and rumble (game/audio/, M2 WP3; Spec §6 "Audio" and the audio and rumble rows):
## the generated SFX bank (and the samples themselves: front-loaded whooshes, no clicks, the
## tiers ranking in loudness), the AudioDirector's layers per tier, one swing through several
## bodies, no immediate repeats, the pitch and volume variation, positional placement,
## grunts, whiff, block, wind-up and music sounds, the rear muffle, voice stealing, and the
## RumbleDirector's pulses with the Input calls stubbed. Events are emitted on CombatEvents
## directly, with plain Node3Ds in the "enemy" and "player" groups as actors; the last tests
## play a real jab in the test room.

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


## A generated sample's 16-bit PCM (read from the .wav file itself, not the imported,
## compressed stream), as floats in -1..1.
static func _pcm(file: String) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(SfxBank.DIR.path_join(file))
	var at := 12
	while at + 8 <= bytes.size():
		var chunk := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if chunk == "data":
			var out := PackedFloat32Array()
			out.resize(size / 2)
			for i in out.size():
				out[i] = bytes.decode_s16(at + 8 + i * 2) / 32768.0
			return out
		at += 8 + size + size % 2
	return PackedFloat32Array()


## RMS of `pcm` over `from`..`to` seconds (44.1 kHz).
static func _rms(pcm: PackedFloat32Array, from: float, to: float) -> float:
	var i0 := int(from * 44100.0)
	var i1 := mini(pcm.size(), int(to * 44100.0))
	var sum := 0.0
	for i in range(i0, i1):
		sum += pcm[i] * pcm[i]
	return sqrt(sum / maxf(1.0, i1 - i0))


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


func test_the_audio_tuning_group_sits_before_debug() -> void:
	var groups: Array[String] = []
	var audio_props: Array[String] = []
	var subgroups: Array[String] = []
	for prop in TuningData.new().get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			groups.append(prop.name)
		elif groups.size() > 0 and groups[-1] == "Audio" and prop.usage & PROPERTY_USAGE_SUBGROUP:
			subgroups.append(prop.name)
		elif groups.size() > 0 and groups[-1] == "Audio" and prop.usage & PROPERTY_USAGE_EDITOR:
			audio_props.append(prop.name)
			if prop.type == TYPE_FLOAT:
				assert_eq(prop.hint, PROPERTY_HINT_RANGE, "%s is a slider" % prop.name)
	var at := groups.find("Audio")
	assert_gt(at, -1)
	assert_eq(groups[at + 1] if at + 1 < groups.size() else "", "Debug")
	for prop_name: String in [
		"sfx_pitch_variation", "sfx_volume_variation", "whoosh_db", "rumble_strength", "music_enabled",
		"hit_light_db", "hit_heavy_db", "hit_finisher_db", "extra_victim_db",
	]:
		assert_has(audio_props, prop_name)
	# Subgroup headings, so the panel doesn't show some 45 sliders as one flat list.
	assert_eq(subgroups, ["Mix", "Tiers", "Layers", "Voices", "Blocks", "Distance", "Music", "Rumble"])


## The swing's whoosh plays at the contact frame (a hit) or as the active frames end (a whiff),
## after the limb has come through, so its loudest part comes first: the earlier slow swell
## peaked 0.1-0.24 s in, after the thud it was layered on.
func test_whooshes_are_loudest_right_away() -> void:
	var bank := SfxBank.new()
	for i in bank.count(&"whoosh"):
		var pcm := _pcm("whoosh_%02d.wav" % (i + 1))
		assert_gt(pcm.size(), 0)
		var window := 0.005
		var loudest := 0
		var level := 0.0
		for w in int(pcm.size() / (window * 44100.0)):
			var rms := _rms(pcm, w * window, (w + 1) * window)
			if rms > level:
				level = rms
				loudest = w
		assert_lt(loudest * window, 0.05, "whoosh %d peaks %.0f ms in" % [i + 1, loudest * window * 1000.0])


## Every one-shot starts and ends at silence: a sample that starts on a step clicks (the
## voices' breath noise did).
func test_one_shots_start_and_end_without_a_click() -> void:
	var bank := SfxBank.new()
	for pool: StringName in bank.pools:
		if pool == &"music_loop":
			continue
		for i in bank.count(pool):
			var pcm := _pcm("%s_%02d.wav" % [pool, i + 1])
			assert_lt(absf(pcm[0]), 0.004, "%s %d starts at silence" % [pool, i + 1])
			assert_lt(absf(pcm[-1]), 0.004, "%s %d ends at silence" % [pool, i + 1])


## The tiers rank in loudness, not only in layers: each tier's layers summed at their tuned
## volumes (the samples themselves, variant 1), over the first 0.4 s. The crack alone added
## a fraction of a dB, so heavy hits sounded as loud as light ones.
func test_the_tiers_rank_in_loudness() -> void:
	var t := Tuning.data
	assert_lt(t.hit_light_db, t.hit_heavy_db)
	assert_lt(t.hit_heavy_db, t.hit_finisher_db)
	var level := {}
	for tier: CombatTypes.HitTier in AudioDirector.TIER_LAYERS:
		var mix := PackedFloat32Array()
		mix.resize(int(0.4 * 44100.0))
		for pool: StringName in AudioDirector.TIER_LAYERS[tier]:
			var pcm := _pcm("%s_01.wav" % pool)
			var gain := db_to_linear(AudioDirector.layer_db(pool) + AudioDirector.tier_db(tier))
			for i in mini(mix.size(), pcm.size()):
				mix[i] += pcm[i] * gain
		level[tier] = linear_to_db(_rms(mix, 0.0, 0.4))
	var light: float = level[CombatTypes.HitTier.LIGHT]
	var heavy: float = level[CombatTypes.HitTier.HEAVY]
	var finisher: float = level[CombatTypes.HitTier.FINISHER]
	assert_gt(heavy - light, 2.0, "heavy over light")
	assert_gt(finisher - heavy, 2.0, "finisher over heavy")


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


func test_layers_play_at_the_contact_point() -> void:
	var at := Vector3(1.2, 1.4, -2.3)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, null, null, at))
	assert_eq(_pools().size(), 5)
	for play in _plays:
		if play.pool in IMPACT_POOLS:
			assert_almost_eq(play.at as Vector3, at, Vector3.ONE * 0.001, "%s at the contact point" % play.pool)
			var voice: AudioStreamPlayer3D = play.voice
			assert_eq(voice.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED, "the director's own fall-off")
			assert_true(voice.playing, "%s started" % play.pool)


## Within sfx_unit_size_m every layer keeps its own volume (Godot's max_db would flatten
## them all to one loudness); beyond it, 6 dB per doubling, live as the listener moves; past
## sfx_max_distance_m, nothing plays.
func test_sounds_fall_off_with_distance_from_the_listener() -> void:
	var t := Tuning.data
	t.sfx_volume_variation = 0.0
	t.sfx_unit_size_m = 3.0
	t.sfx_max_distance_m = 20.0
	var near_thud := _director.play(&"thud", Vector3(0.0, 0.0, -0.8), t.thud_db)
	var near_whoosh := _director.play(&"whoosh", Vector3(0.0, 0.0, -0.8), t.whoosh_db)
	assert_almost_eq(near_thud.volume_db, t.thud_db, 0.001, "close by: the layer's volume")
	assert_almost_eq(near_whoosh.volume_db, t.whoosh_db, 0.001, "...each its own")
	var far := _director.play(&"thud", Vector3(0.0, 0.0, -12.0), t.thud_db)
	assert_almost_eq(far.volume_db, t.thud_db - 12.04, 0.01, "4x the unit size: -12 dB")
	assert_null(_director.play(&"thud", Vector3(0.0, 0.0, -21.0), t.thud_db), "beyond the max distance")
	# The listener walks up to the far sound: it gets louder while it plays.
	_director.listener.global_position = Vector3(0.0, 0.0, -9.0)
	await _frames(1)
	assert_almost_eq(far.volume_db, t.thud_db, 0.01)


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
	# Variation 0: exactly the layer's volume (plus the tier's) and pitch.
	Tuning.data.sfx_pitch_variation = 0.0
	Tuning.data.sfx_volume_variation = 0.0
	_plays.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY))
	for play in _plays:
		if play.pool in IMPACT_POOLS:
			assert_eq(play.pitch, 1.0)
			assert_almost_eq(float(play.volume_db), AudioDirector.layer_db(play.pool) + Tuning.data.hit_heavy_db, 0.0001)


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


func test_layer_and_tier_volumes_follow_tuning_live() -> void:
	Tuning.data.sfx_volume_variation = 0.0
	Tuning.data.crack_db = -17.0
	Tuning.data.hit_heavy_db = 1.5
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY))
	var cracks := _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"crack")
	assert_eq(cracks.size(), 1)
	assert_almost_eq(float(cracks[0].volume_db), -15.5, 0.0001)
	# Each tier's gain lifts every one-shot of its hits, blocked ones too.
	for tier: CombatTypes.HitTier in [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.FINISHER]:
		_plays.clear()
		var hit := _hit(tier)
		CombatEvents.hit_landed.emit(hit)
		var thud: Array = _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"thud")
		assert_almost_eq(float(thud[0].volume_db), Tuning.data.thud_db + AudioDirector.tier_db(tier), 0.0001)
		_plays.clear()
		hit = _hit(tier)
		hit.blocked = true
		CombatEvents.hit_landed.emit(hit)
		var clack: Array = _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"block_clack")
		assert_almost_eq(float(clack[0].volume_db), Tuning.data.block_clack_db + AudioDirector.tier_db(tier), 0.0001)
	# The SFX volume is the limiter's pre-gain: the bus volume applies after the limiter, so
	# turning it down never gave the limiter headroom.
	Tuning.data.sfx_volume_db = -12.0
	await _frames(1)
	var limiter := _director.sfx_limiter()
	assert_not_null(limiter)
	assert_almost_eq(limiter.pre_gain_db, -12.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioDirector.SFX_BUS)), 0.0, 0.001)


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


## One swing through several bodies in a frame (the spinning heel's arc): one whoosh and one
## sub thump, every body its own thud, crunch and fall (the ones after the first
## extra_victim_db quieter) and its own grunt. Three full finisher stacks used to play, 18
## voices at once, louder than a single finisher and flattened by the limiter.
func test_one_swing_through_several_bodies_whooshes_once() -> void:
	var t := Tuning.data
	t.sfx_volume_variation = 0.0
	var victims: Array[Node3D] = [
		_enemy,
		_actor("Dummy3", &"enemy", Vector3(1.0, 0.0, -1.0)),
		_actor("Dummy4", &"enemy", Vector3(-1.0, 0.0, -1.0)),
	]
	for victim in victims:
		CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, victim))
	var pools := _pools()
	assert_eq(pools.count(&"whoosh"), 1, "one limb went by")
	assert_eq(pools.count(&"sub_thump"), 1, "one finisher's weight")
	for pool: StringName in [&"thud", &"crunch", &"body_fall"]:
		assert_eq(pools.count(pool), 3, "%s per body" % pool)
	assert_eq(_pools(false).count(&"grunt"), 3, "every body grunts")
	var thuds := _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"thud")
	var full := t.thud_db + t.hit_finisher_db
	assert_almost_eq(float(thuds[0].volume_db), full, 0.0001)
	assert_almost_eq(float(thuds[1].volume_db), full + t.extra_victim_db, 0.0001)
	assert_almost_eq(float(thuds[2].volume_db), full + t.extra_victim_db, 0.0001)
	# The same attacker's next swing (a later frame) whooshes again, and so does a second hit
	# on a body already struck this frame (two swings, not one through two bodies).
	await get_tree().physics_frame
	_plays.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT, victims[1]))
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT, victims[1]))
	assert_eq(_pools(), [&"whoosh", &"thud", &"whoosh", &"thud"])


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
	# The table of recent grunts forgets the actors whose interval has run out (it held every
	# actor ever hit).
	await _frames(int(ceil(Tuning.data.grunt_min_interval_ms / 1000.0 * 60.0)) + 2)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT, _attacker, _enemy))
	assert_eq(_director._last_grunt_s.keys(), [_attacker.get_instance_id()])


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


## Hit (or grabbed) out of its wind-up, an attacker's effort and whoosh stop at once: the
## effort talked over the pain grunt that follows. Another attacker's wind-up, and a wind-up
## that ends in its strike, ring out.
func test_a_windup_knocked_out_of_cuts_its_effort_and_whoosh() -> void:
	var move := load("res://game/combat/moves/dummy_jab.tres") as MoveData
	CombatEvents.windup_started.emit(_attacker, move)
	CombatEvents.windup_started.emit(_enemy, move)
	assert_eq(_plays.size(), 4)
	var cut: Array[AudioStreamPlayer3D] = [_plays[0].voice, _plays[1].voice]
	var kept: Array[AudioStreamPlayer3D] = [_plays[2].voice, _plays[3].voice]
	for voice in cut + kept:
		assert_true(voice.playing)
	CombatEvents.windup_ended.emit(_attacker, true)
	for voice in cut:
		assert_false(voice.playing, "the interrupted wind-up's %s stopped" % voice.name)
	CombatEvents.windup_ended.emit(_enemy, false)
	for voice in kept:
		assert_true(voice.playing, "a wind-up that struck rings out")
	# A voice reused for another sound is no longer the wind-up's.
	CombatEvents.windup_ended.emit(_enemy, true)
	var reused := _director.play(&"thud", Vector3(0.0, 1.0, -2.0), 0.0)
	CombatEvents.windup_ended.emit(_attacker, true)
	assert_true(reused.playing)


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


## A hit on the player sounds from where the blow came from: its contact point sits within
## centimetres of the listener at the eyes, and a frontal block's clack, 3 cm behind the eye,
## went through the rear muffle (2 of 5 blocks in the guard-break act) and panned at random.
func test_hits_on_the_player_sound_from_the_attackers_side() -> void:
	var player := _actor("Player", &"player", Vector3(0.0, -1.6, 0.0))
	var t := Tuning.data
	var hit := _hit(CombatTypes.HitTier.LIGHT, player, _enemy, Vector3(-0.03, -0.08, 0.03))
	hit.direction = Vector3(0.0, 0.0, 1.0)  # pushed toward +Z: the attacker stands at -Z, ahead
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	for play in _plays:
		assert_almost_eq(play.at as Vector3, Vector3(0.0, 0.0, -t.self_hit_offset_m), Vector3.ONE * 0.001, "%s ahead" % play.pool)
		assert_eq(play.bus, AudioDirector.SFX_BUS, "%s not muffled" % play.pool)
	# From behind-right: behind-right, and muffled.
	_plays.clear()
	hit = _hit(CombatTypes.HitTier.LIGHT, player, _enemy, Vector3(0.0, -0.1, -0.02))
	hit.direction = Vector3(-1.0, 0.0, -1.0).normalized()
	CombatEvents.hit_landed.emit(hit)
	var thud: Dictionary = _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"thud")[0]
	assert_gt((thud.at as Vector3).x, 0.0)
	assert_gt((thud.at as Vector3).z, 0.0)
	assert_eq(thud.bus, AudioDirector.REAR_BUS)
	# Anyone else's hit plays at its contact point.
	_plays.clear()
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.LIGHT, _enemy, player, Vector3(0.2, 1.4, -0.9)))
	assert_almost_eq(_plays[0].at as Vector3, Vector3(0.2, 1.4, -0.9), Vector3.ONE * 0.001)


func test_the_voice_pool_takes_the_oldest_when_all_are_busy() -> void:
	var at := Vector3(0.0, 1.0, -2.0)
	var voices: Array[AudioStreamPlayer3D] = []
	for i in _director.voice_count:
		voices.append(_director.play(&"parry_ting", at, 0.0))
	assert_eq(voices.filter(func(v: AudioStreamPlayer3D) -> bool: return v != null and v.playing).size(), _director.voice_count)
	# One sound ends early (a short one): the next takes its voice.
	voices[3].stop()
	assert_eq(_director.play(&"parry_ting", at, 0.0), voices[3])
	# All busy: each new sound takes the one started longest ago, not the next in turn.
	assert_eq(_director.play(&"parry_ting", at, 0.0), voices[0])
	assert_eq(_director.play(&"parry_ting", at, 0.0), voices[1])
	assert_eq(_director.play(&"parry_ting", at, 0.0), voices[2])
	assert_eq(_director.play(&"parry_ting", at, 0.0), voices[4], "voice 3 is newer")
	var used := {}
	for i in _director.voice_count * 3:
		used[_director.play(&"whoosh", at, 0.0)] = true
	assert_eq(used.size(), _director.voice_count, "every voice is used, and no more are made")
	var children := _director.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D)
	assert_eq(children.size(), _director.voice_count)


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


## A joypad plays one vibration at a time: a block tick or a light hit while a heavy pulse
## runs keeps the heavy's motors to its end (it used to cut it to a 40 ms tick); once it has
## ended, a tick is a tick again.
func test_a_weaker_pulse_never_cuts_a_stronger_one_short() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	var t := Tuning.data
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY, _enemy, player))
	await _frames(2)
	var hit := _hit(CombatTypes.HitTier.LIGHT, player, _enemy)
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_pulses.size(), 2)
	assert_almost_eq(_pulses[1].x, t.rumble_heavy_weak, 0.0001)
	assert_almost_eq(_pulses[1].y, t.rumble_heavy_strong, 0.0001)
	assert_between(_pulses[1].z, t.rumble_block_ms / 1000.0, t.rumble_heavy_ms / 1000.0, "the heavy's remaining time")
	# A stronger pulse during a weaker one takes over at its own strength and length.
	await _frames(int(ceil(t.rumble_heavy_ms / 1000.0 * 60.0)) + 2)
	_pulses.clear()
	CombatEvents.hit_landed.emit(hit)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.HEAVY, _enemy, player))
	assert_eq(_pulses, [
		Vector3(t.rumble_block_weak, t.rumble_block_strong, t.rumble_block_ms / 1000.0),
		Vector3(t.rumble_heavy_weak, t.rumble_heavy_strong, t.rumble_heavy_ms / 1000.0),
	] as Array[Vector3])


## Paused between a finisher's two pulses, the second never comes (it used to fire on
## unpausing).
func test_pausing_drops_a_finishers_second_pulse() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, _enemy, player))
	assert_eq(_rumble.queued_pulses(), 1)
	_rumble.notification(Node.NOTIFICATION_PAUSED)
	_rumble.notification(Node.NOTIFICATION_UNPAUSED)
	await _frames(30)
	assert_eq(_pulses.size(), 1)


## A finisher through three bodies queues its second pulse once, not three times.
func test_a_finisher_through_several_bodies_queues_one_second_pulse() -> void:
	var player := _actor("Player", &"player", Vector3.ZERO)
	for victim: Node3D in [_enemy, _attacker, _actor("Dummy3", &"enemy", Vector3(1.0, 0.0, -1.0))]:
		CombatEvents.hit_landed.emit(_hit(CombatTypes.HitTier.FINISHER, victim, player))
	assert_eq(_rumble.queued_pulses(), 1)


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
	# A swing at nothing: only a whoosh, at the player's fist, and no rumble.
	var dummy: TrainingDummy = dummies[0]
	dummy.set_post(Vector3(30.0, 0.0, 30.0), 0.0, true)
	for i in 40:
		await get_tree().physics_frame
	_plays.clear()
	_pulses.clear()
	var whiffed: Array[MoveData] = []
	var on_whiff := func(_attacker: Node3D, move: MoveData) -> void: whiffed.append(move)
	CombatEvents.attack_whiffed.connect(on_whiff)
	player.input.push_press(&"P", 2)
	for i in 40:
		await get_tree().physics_frame
		if not whiffed.is_empty():
			break
	CombatEvents.attack_whiffed.disconnect(on_whiff)
	assert_eq(whiffed.size(), 1, "the jab whiffs")
	assert_eq(_pools(false), [&"whoosh"], "a whiff: a whoosh and nothing else")
	if not _plays.is_empty():
		var fist := player.rig.get_point_position(whiffed[0].hitboxes[0].point)
		assert_lt((_plays[0].at as Vector3).distance_to(fist), 0.5, "at the striking fist")
	assert_eq(_pulses.size(), 0)
	# The dummy's jab lands on the player from the front: its layers sound ahead of the
	# listener and unmuffled (the real contact sits on the head or chest, around the
	# listener), and the player grunts and feels it.
	for i in 120:
		if player.state == CombatTypes.ActorState.FREE:
			break
		await get_tree().physics_frame
	var post := player.global_position + player.get_forward() * Tuning.data.sparring_step_in_m
	var to_player := player.global_position - post
	dummy.set_post(post, atan2(-to_player.x, -to_player.z), true)
	for i in 10:
		await get_tree().physics_frame
	_plays.clear()
	_pulses.clear()
	landed.clear()
	CombatEvents.hit_landed.connect(on_hit)
	dummy.start_jab()
	for i in 90:
		await get_tree().physics_frame
		if not landed.is_empty():
			break
	CombatEvents.hit_landed.disconnect(on_hit)
	assert_eq(landed.size(), 1, "the dummy's jab lands")
	if landed.is_empty():
		return
	assert_eq(landed[0].victim, player)
	assert_true(_pools().has(&"thud"), "a clean hit's thud")
	var view := director.listener_transform()
	for play in _plays:
		if play.pool in IMPACT_POOLS and play.pool != &"whoosh":
			var local: Vector3 = view.affine_inverse() * (play.at as Vector3)
			assert_lt(local.z, -0.3, "%s ahead of the listener" % play.pool)
			assert_lt(absf(local.x), 0.1, "%s centred" % play.pool)
			assert_eq(play.bus, AudioDirector.SFX_BUS, "%s not muffled" % play.pool)
	assert_true(_pools(false).has(&"player_grunt"))
	assert_eq(_pulses.size(), 1)
