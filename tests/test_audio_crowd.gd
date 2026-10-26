extends GutTest
## The audio director in a crowd (Milestone 3, P1-hud): the wind-up's own effort and whoosh is
## the rear warning's audio cue (Spec §8), so with six enemies and a brawl on top of a 32-voice
## pool, the voice stealer must take any other sound first. Also the pitch multiplier of a deep
## voice (a Bruiser's, the boss's) and the counter of wind-up cues that were taken over anyway
## (the readability probe's R14). Built like test_audio.gd: a standalone director, events emitted
## on CombatEvents with plain Node3Ds in the "enemy" group; everything runs in one frame, so no
## voice ends on its own.

var _director: AudioDirector
var _enemies: Array[Node3D] = []
var _player: Node3D
var _move: MoveData


## An enemy with a deeper voice (what EnemyActor.voice_pitch_mult is).
class DeepEnemy:
	extends Node3D
	var voice_pitch_mult: float = 0.8


func before_each() -> void:
	Tuning.apply(TuningData.new())
	_director = AudioDirector.new()
	add_child_autofree(_director)
	_director.rng.seed = 99
	_director.listener.global_transform = Transform3D.IDENTITY
	_director.listener.make_current()
	_move = load("res://game/combat/moves/dummy_jab.tres") as MoveData
	_enemies.clear()
	for i in 6:
		var enemy := Node3D.new()
		enemy.name = "Punk%d" % i
		enemy.add_to_group(&"enemy")
		add_child_autofree(enemy)
		enemy.global_position = Vector3(sin(i) * 2.0, 0.0, cos(i) * 2.0)
		_enemies.append(enemy)
	_player = Node3D.new()
	_player.name = "Player"
	_player.add_to_group(&"player")
	add_child_autofree(_player)


func _busy() -> int:
	var n := 0
	for child: Node in _director.get_children():
		if child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).playing:
			n += 1
	return n


## The voices tagged as `attackers`' wind-up cues (read from the director's tags).
func _windup_voices(attackers: Array[Node3D]) -> Array[AudioStreamPlayer3D]:
	var ids: Array[int] = []
	for a: Node3D in attackers:
		ids.append(a.get_instance_id())
	var tags: Array = _director.get(&"_windup_of")
	var out: Array[AudioStreamPlayer3D] = []
	for i in tags.size():
		if tags[i] in ids:
			out.append(_director.get_node("Voice%d" % i) as AudioStreamPlayer3D)
	return out


func _hit(tier: CombatTypes.HitTier, victim: Node3D, attacker: Node3D) -> void:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.tier = tier
	hit.contact_point = victim.global_position + Vector3.UP
	CombatEvents.hit_landed.emit(hit)


## A brawl on top of everything else: finisher hits (five layers and a grunt each) from the
## player through the crowd, and the crowd's hits back. Far more sounds than the pool has voices.
func _brawl(rounds: int) -> void:
	for i in rounds:
		_hit(CombatTypes.HitTier.FINISHER, _enemies[i % 6], _player)
		_hit(CombatTypes.HitTier.HEAVY, _player, _enemies[(i + 1) % 6])


func test_six_simultaneous_windups_keep_their_cues_through_a_brawl() -> void:
	for enemy: Node3D in _enemies:
		CombatEvents.windup_started.emit(enemy, _move)
	var cues := _windup_voices(_enemies)
	assert_eq(cues.size(), 12, "an effort and a whoosh for each of six")
	for voice: AudioStreamPlayer3D in cues:
		assert_true(voice.playing)
	var plays: Array[int] = [0]  # a lambda captures a number by value, an array by reference
	_director.played.connect(func(_pool: StringName, _voice: AudioStreamPlayer3D) -> void: plays[0] += 1)
	_brawl(12)
	assert_gt(plays[0], _director.voice_count, "the brawl is more sounds than the pool has voices")
	assert_eq(_busy(), _director.voice_count, "the pool is full")
	for voice: AudioStreamPlayer3D in cues:
		assert_true(voice.playing, "%s still sounds its wind-up" % voice.name)
	assert_eq(_director.windup_voices_stolen, 0, "none taken over")
	assert_eq(_windup_voices(_enemies).size(), 12, "and still tagged as warnings")


func test_the_oldest_other_sound_gives_way_not_the_oldest_overall() -> void:
	# The wind-up cues are the OLDEST sounds in the pool; a new sound still takes another.
	CombatEvents.windup_started.emit(_enemies[0], _move)
	var cues := _windup_voices([_enemies[0]])
	var others: Array[AudioStreamPlayer3D] = []
	var at := Vector3(0.0, 1.0, -2.0)
	for i in _director.voice_count - 2:
		others.append(_director.play(&"parry_ting", at, 0.0))
	assert_eq(_busy(), _director.voice_count)
	var taken := _director.play(&"thud", at, 0.0)
	assert_eq(taken, others[0], "the oldest sound that is not a live wind-up cue")
	for voice: AudioStreamPlayer3D in cues:
		assert_true(voice.playing)
	assert_eq(_director.windup_voices_stolen, 0)


func test_a_windup_cue_is_only_taken_when_every_voice_is_one() -> void:
	# 16 wind-ups fill the 32 voices with live cues: the oldest of them has to give way.
	var wide: Array[Node3D] = []
	for i in _director.voice_count / 2:
		var enemy := Node3D.new()
		enemy.name = "Wide%d" % i
		add_child_autofree(enemy)
		wide.append(enemy)
		CombatEvents.windup_started.emit(enemy, _move)
	assert_eq(_busy(), _director.voice_count)
	var first := _windup_voices([wide[0]])
	assert_eq(_director.windup_voices_stolen, 0)
	var taken := _director.play(&"thud", Vector3(0.0, 1.0, -2.0), 0.0)
	assert_eq(_director.windup_voices_stolen, 1, "counted")
	assert_true(taken in first, "the oldest wind-up's cue went")


func test_a_windup_that_ends_in_its_strike_stops_being_protected() -> void:
	CombatEvents.windup_started.emit(_enemies[0], _move)
	var cues := _windup_voices([_enemies[0]])
	assert_eq(cues.size(), 2)
	CombatEvents.windup_ended.emit(_enemies[0], false)
	assert_true(cues[0].playing and cues[1].playing, "the cue rings out")
	assert_eq(_windup_voices([_enemies[0]]).size(), 0, "but is no longer the warning")
	# Now the oldest sounds in a full pool: they are taken first, and it is not a steal.
	var at := Vector3(0.0, 1.0, -2.0)
	for i in _director.voice_count - 2:
		_director.play(&"parry_ting", at, 0.0)
	var taken := _director.play(&"thud", at, 0.0)
	assert_true(taken in cues)
	assert_eq(_director.windup_voices_stolen, 0)


func test_an_interrupted_windup_still_cuts_its_cue() -> void:
	CombatEvents.windup_started.emit(_enemies[1], _move)
	var cues := _windup_voices([_enemies[1]])
	CombatEvents.windup_ended.emit(_enemies[1], true)
	for voice: AudioStreamPlayer3D in cues:
		assert_false(voice.playing, "knocked out of the wind-up: the effort stops")
	assert_eq(_director.windup_voices_stolen, 0)


func test_the_worst_moment_of_a_six_enemy_fight_fits_the_pool() -> void:
	# Six wind-ups, three attackers landing on the player, the player's three-body finisher, all
	# starting in one frame (no sound has ended yet): the most the pool is ever asked for.
	var plays: Array[int] = [0]
	_director.played.connect(func(_pool: StringName, _voice: AudioStreamPlayer3D) -> void: plays[0] += 1)
	for enemy: Node3D in _enemies:
		CombatEvents.windup_started.emit(enemy, _move)
	for i in 3:
		_hit(CombatTypes.HitTier.HEAVY, _player, _enemies[i])
	for i in 3:
		_hit(CombatTypes.HitTier.FINISHER, _enemies[3 + i], _player)
	var busy := _busy()
	gut.p("six-enemy worst moment: %d sounds asked of %d voices" % [plays[0], _director.voice_count], 2)
	assert_lte(busy, _director.voice_count)
	assert_eq(_director.windup_voices_stolen, 0, "no wind-up cue was needed for the rest")
	assert_eq(_windup_voices(_enemies).size(), 12, "all six warnings are still sounding")


func test_a_deeper_voice_pitches_down_by_its_multiplier() -> void:
	var deep := DeepEnemy.new()
	deep.name = "Bruiser"
	add_child_autofree(deep)
	deep.voice_pitch_mult = 1.0
	var base := AudioDirector.voice_pitch(deep)
	deep.voice_pitch_mult = 0.8
	assert_almost_eq(AudioDirector.voice_pitch(deep), base * 0.8, 0.0001)
	deep.voice_pitch_mult = 0.0
	assert_almost_eq(AudioDirector.voice_pitch(deep), base, 0.0001, "a zero multiplier is ignored, not silence")
	# An actor with no such property is unchanged (its name's pitch).
	var holder := Node3D.new()
	add_child_autofree(holder)
	var plain := Node3D.new()
	plain.name = "Bruiser"
	holder.add_child(plain)
	assert_almost_eq(AudioDirector.voice_pitch(plain), base, 0.0001, "same name, same pitch, no multiplier")
	# The wind-up's effort plays at that pitch (within the usual variation).
	deep.voice_pitch_mult = 0.5
	deep.add_to_group(&"enemy")
	var pitches: Array[float] = []
	_director.played.connect(func(pool: StringName, voice: AudioStreamPlayer3D) -> void:
		if pool == &"effort":
			pitches.append(voice.pitch_scale))
	CombatEvents.windup_started.emit(deep, _move)
	assert_eq(pitches.size(), 1)
	var variation := Tuning.data.sfx_pitch_variation
	assert_between(pitches[0], base * 0.5 * (1.0 - variation), base * 0.5 * (1.0 + variation))
