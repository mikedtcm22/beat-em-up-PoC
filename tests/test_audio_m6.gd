extends GutTest
## Milestone 6's audio (AUDIO package, docs/milestones/M6-plan.md D18-D25): the manifest that records every
## shipped wav, the ElevenLabs ledger and its stop, the voice pools per archetype and their fallback, each
## new slot playing on its signal (with streams injected into the bank, since the world slots stay empty
## until SFX fills them), the bed that is not a pooled voice, the legacy bank, the audition room, and
## the ingest tool's own `--check`. Events are emitted on CombatEvents directly.

const MANIFEST_PATH := "res://assets/source/sfx/manifest.json"
const LEDGER_PATH := "res://assets/source/sfx/eleven_ledger.jsonl"
const POLICY_PATH := "res://tools/audio/eleven_policy.json"
const SFX_SOURCE := "res://assets/source/sfx"
const LEGACY := "res://tests/fixtures/sfx_legacy"
const ARCHETYPES: Array[StringName] = [&"punk", &"kicker", &"thug", &"bruiser", &"boss"]

## An enemy with an archetype, as the director reads it (EnemyActor.archetype).
class ArchActor extends Node3D:
	var archetype: StringName = &""

var _director: AudioDirector
var _plays: Array[Dictionary] = []
var _plays_2d: Array[StringName] = []


func before_each() -> void:
	Tuning.apply(TuningData.new())
	_plays.clear()
	_plays_2d.clear()
	_director = AudioDirector.new()
	add_child_autofree(_director)
	_director.rng.seed = 99
	_director.played.connect(func(pool: StringName, voice: AudioStreamPlayer3D) -> void:
		_plays.append({pool = pool, at = voice.global_position, volume_db = voice.volume_db}))
	_director.played_2d.connect(func(pool: StringName, _player: AudioStreamPlayer) -> void: _plays_2d.append(pool))
	_director.listener.global_transform = Transform3D.IDENTITY
	_director.listener.make_current()


func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary, "the manifest parses")
	return parsed if parsed is Dictionary else {"slots": {}, "files": []}


func _json_lines(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	return out


## A short silent stream to stand in a pool.
func _wav(seconds: float = 0.2) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(int(seconds * 44100.0) * 2)
	stream.data = data
	return stream


func _stub(pool: StringName) -> void:
	_director.bank.pools[pool] = [_wav()]


func _enemy(archetype: StringName, at: Vector3 = Vector3(0.0, 0.0, -1.0)) -> ArchActor:
	var actor := ArchActor.new()
	actor.archetype = archetype
	actor.name = "Enemy_%s" % archetype
	actor.add_to_group(&"enemy")
	add_child_autofree(actor)
	actor.global_position = at
	return actor


func _hit(victim: Node3D, move: MoveData = null) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = _enemy(&"punk", Vector3(0.0, 0.0, -2.0))
	hit.victim = victim
	hit.move = move
	hit.tier = CombatTypes.HitTier.LIGHT
	hit.contact_point = victim.global_position + Vector3.UP
	return hit


func _pools_played() -> Array:
	return _plays.map(func(p: Dictionary) -> StringName: return p.pool)


# --- The manifest, the files and the ledger -----------------------------------------------


func test_every_shipped_wav_has_a_manifest_row_and_the_reverse() -> void:
	var manifest := _manifest()
	var rows := {}
	for row: Dictionary in manifest.files:
		assert_false(rows.has(row.file), "%s has one row" % row.file)
		rows[row.file] = row
	var shipped := {}
	for file in DirAccess.get_files_at("res://assets/export/sfx"):
		if file.get_extension() == "wav":
			shipped[file] = true
			assert_true(rows.has(file), "%s has a manifest row" % file)
	for file: String in rows:
		assert_true(shipped.has(file), "the row %s has its file" % file)
		var row: Dictionary = rows[file]
		var cut := file.get_basename().rfind("_")
		assert_eq(file.substr(0, cut), str(row.pool), "%s names its pool" % file)
		assert_true(manifest.slots.has(row.pool), "%s's pool has a slot" % file)
		assert_true(str(row.source) == "gen_sfx" or str(row.source).begins_with("elevenlabs:"), "%s has a known source" % file)
		assert_ne(str(row.licence), "", "%s has a licence" % file)


func test_the_shipped_wavs_are_16_bit_mono_44100() -> void:
	for file in DirAccess.get_files_at("res://assets/export/sfx"):
		if file.get_extension() != "wav":
			continue
		var bytes := FileAccess.get_file_as_bytes("res://assets/export/sfx/" + file)
		assert_eq(bytes.slice(0, 4).get_string_from_ascii(), "RIFF", file)
		var at := 12
		var found := false
		while at + 8 <= bytes.size():
			var chunk := bytes.slice(at, at + 4).get_string_from_ascii()
			var size := bytes.decode_u32(at + 4)
			if chunk == "fmt ":
				found = true
				assert_eq(bytes.decode_u16(at + 8), 1, "%s is PCM" % file)
				assert_eq(bytes.decode_u16(at + 10), 1, "%s is mono" % file)
				assert_eq(bytes.decode_u32(at + 12), 44100, "%s is 44.1 kHz" % file)
				assert_eq(bytes.decode_u16(at + 22), 16, "%s is 16-bit" % file)
				break
			at += 8 + size + size % 2
		assert_true(found, "%s has a fmt chunk" % file)


func test_the_gen_sfx_rows_are_the_legacy_copies() -> void:
	for row: Dictionary in _manifest().files:
		if str(row.source) != "gen_sfx":
			continue
		var shipped := FileAccess.get_file_as_bytes("res://assets/export/sfx/" + str(row.file))
		var legacy := FileAccess.get_file_as_bytes(LEGACY + "/" + str(row.file))
		assert_gt(legacy.size(), 0, "%s has a legacy copy" % row.file)
		assert_eq(shipped, legacy, "%s is still the placeholder it says" % row.file)


func test_the_ledger_stays_within_the_policy_stop() -> void:
	var policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	assert_true(policy is Dictionary)
	var total := 0.0
	var calls := 0
	for line in _json_lines(LEDGER_PATH):
		if line.get("milestone", "") != policy.milestone:
			continue
		if line.get("event", "") == "call":
			calls += 1
			total += float(line.credits_used) if line.get("credits_used") != null else float(line.expected_credits)
			assert_lte(float(line.expected_credits), float(policy.max_call), "%s is within max_call" % line.id)
			assert_eq(str(line.model_id), str(policy.model_id), "%s used the pinned model" % line.id)
			assert_gt(float(line.duration_seconds), 0.0, "%s set a duration" % line.id)
		elif line.get("event", "") == "settle":
			total += float(line.credits_remainder)
	assert_gt(calls, 0)
	gut.p("ElevenLabs ledger: %d calls, %.0f credits of the %.0f stop" % [calls, total, float(policy.stop)], 2)
	assert_lte(total, float(policy.stop), "the M6 ledger is within the stop")


func test_every_eleven_labs_row_names_a_ledger_call_and_its_take() -> void:
	var calls := {}
	for line in _json_lines(LEDGER_PATH):
		if line.get("event", "") == "call":
			calls[str(line.id)] = line
	for row: Dictionary in _manifest().files:
		var source := str(row.source)
		if not source.begins_with("elevenlabs:"):
			continue
		var id := source.trim_prefix("elevenlabs:")
		assert_true(calls.has(id), "%s: %s is on the ledger" % [row.file, id])
		assert_true(FileAccess.file_exists("%s/eleven/%s.mp3" % [SFX_SOURCE, id]), "%s: its take exists" % row.file)


## Every voice pool meets its slot's `min_variants` (the plan's done-when for the voices).
func test_every_voice_pool_meets_its_minimum() -> void:
	var bank := SfxBank.new()
	var voice := RegEx.create_from_string("^(grunt|effort|ko|player_grunt|boss_phase)(_[a-z]+)?$")
	var checked := 0
	for pool: String in _manifest().slots:
		if voice.search(pool) == null:
			continue
		checked += 1
		assert_gte(bank.count(StringName(pool)), int(_manifest().slots[pool].min_variants), "%s meets its minimum" % pool)
	assert_gte(checked, 3 + 3 * ARCHETYPES.size() + 1, "the shared, per-archetype, player and boss voice slots exist")
	for archetype in ARCHETYPES:
		for base in ["grunt", "effort", "ko"]:
			assert_true(_manifest().slots.has("%s_%s" % [base, archetype]), "slot %s_%s" % [base, archetype])


## Every sound source and legacy file has an ASSETS.md row (its own path, or the folder it sits in, in
## backticks) and is in LFS (a `*.<ext> filter=lfs` line of .gitattributes): A13 scans only assets/export
## and the concepts.
func test_every_sfx_source_file_has_an_assets_row_and_is_in_lfs() -> void:
	var assets := FileAccess.get_file_as_string("res://ASSETS.md")
	var attributes := FileAccess.get_file_as_string("res://.gitattributes")
	var checked := 0
	for dir_path in [SFX_SOURCE, LEGACY]:
		for path in _files_under(dir_path):
			var ext := path.get_extension()
			if not (ext in ["mp3", "wav", "ogg"]):
				continue
			checked += 1
			var rel := path.trim_prefix("res://")
			var covered := assets.contains("`%s`" % rel)
			var folder := rel.get_base_dir()
			while not covered and folder != "":
				covered = assets.contains("`%s/`" % folder)
				folder = folder.get_base_dir()
			assert_true(covered, "%s has an ASSETS row" % rel)
			assert_true(attributes.contains("*.%s filter=lfs" % ext), "*.%s is in LFS" % ext)
	assert_gt(checked, 0)


func _files_under(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		out.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		out.append_array(_files_under(dir_path.path_join(sub)))
	return out


## `ingest.py --check` rebuilds every ElevenLabs row's PCM from its MP3 and fails on any difference; the
## tool needs python3 and ffmpeg, so a machine without them skips.
func test_ingest_check_rebuilds_every_elevenlabs_file() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var probe: Array = []
	if OS.execute("ffmpeg", ["-version"], probe) != 0:
		pending("ffmpeg is not installed")
		return
	var output: Array = []
	var code := OS.execute("python3", ["-I", root.path_join("tools/audio/ingest.py"), "--check"], output, true)
	var text := "\n".join(output)
	assert_eq(code, 0, "ingest --check passes:\n" + text.right(1500))
	assert_true(text.contains("0 problems"), text.right(300))


# --- Voices per archetype ------------------------------------------------------------------


func test_a_voice_comes_from_the_archetypes_pool_and_falls_back_to_the_shared_one() -> void:
	_stub(&"grunt")
	_stub(&"effort")
	# The real bank has the archetype pools now: this test builds its own.
	for pool in [&"grunt_punk", &"grunt_bruiser", &"effort_punk"]:
		_director.bank.pools.erase(pool)
	_stub(&"grunt_punk")
	var punk := _enemy(&"punk")
	var bruiser := _enemy(&"bruiser")
	var dummy := _enemy(&"")
	var plain := Node3D.new()
	add_child_autofree(plain)
	assert_eq(_director.voice_pool(&"grunt", punk), &"grunt_punk", "the punk has its own grunts")
	_director.bank.pools.erase(&"grunt_bruiser")
	assert_eq(_director.voice_pool(&"grunt", bruiser), &"grunt", "the bruiser's pool is empty: the shared one")
	assert_eq(_director.voice_pool(&"grunt", dummy), &"grunt", "the dummy's archetype is empty: the shared one")
	assert_eq(_director.voice_pool(&"grunt", plain), &"grunt", "an actor with no archetype: the shared one")
	assert_eq(_director.voice_pool(&"effort", punk), &"effort", "no effort_punk: the shared one")
	CombatEvents.hit_landed.emit(_hit(punk))
	CombatEvents.hit_landed.emit(_hit(bruiser))
	assert_has(_pools_played(), &"grunt_punk")
	assert_has(_pools_played(), &"grunt")


func test_every_archetype_has_all_three_voice_pools_in_the_real_bank() -> void:
	for archetype in ARCHETYPES:
		for base in [&"grunt", &"effort", &"ko"]:
			var pool := StringName("%s_%s" % [base, archetype])
			assert_gt(_director.bank.count(pool), 0, "%s has files" % pool)
			var actor := _enemy(archetype)
			assert_eq(_director.voice_pool(base, actor), pool, "%s is the %s's %s" % [pool, archetype, base])


func test_an_enemy_ko_plays_its_own_line_and_cuts_the_grunt() -> void:
	_stub(&"grunt_punk")
	_stub(&"ko_punk")
	Tuning.data.sfx_volume_variation = 0.0
	var punk := _enemy(&"punk")
	var hit := _hit(punk)
	hit.killed = true
	CombatEvents.hit_landed.emit(hit)
	var grunt_voice: AudioStreamPlayer3D = _director._grunt_voice.get(punk.get_instance_id())
	assert_not_null(grunt_voice)
	assert_true(grunt_voice.playing)
	CombatEvents.ko.emit(punk, hit)
	assert_false(grunt_voice.playing, "the KO line cuts the grunt of the blow")
	assert_eq(_pools_played().back(), &"ko_punk")
	assert_almost_eq(float(_plays.back().volume_db), Tuning.data.ko_db, 0.0001)


func test_a_ko_with_no_pool_is_silent_and_keeps_the_grunt() -> void:
	_stub(&"grunt")
	var dummy := _enemy(&"")
	CombatEvents.hit_landed.emit(_hit(dummy))
	var grunt_voice: AudioStreamPlayer3D = _director._grunt_voice.get(dummy.get_instance_id())
	var before := _plays.size()
	CombatEvents.ko.emit(dummy, _hit(dummy))
	assert_eq(_plays.size(), before, "no KO pool: nothing plays")
	assert_true(grunt_voice.playing, "and the grunt is not cut for nothing")
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	CombatEvents.ko.emit(player, _hit(player))
	assert_eq(_plays.size(), before, "the player has no KO line")


func test_the_boss_phase_line_plays_at_the_boss() -> void:
	_stub(&"boss_phase")
	var boss := _enemy(&"boss", Vector3(1.0, 0.0, -3.0))
	CombatEvents.boss_phase_changed.emit(boss, 2)
	assert_eq(_pools_played(), [&"boss_phase"])
	assert_almost_eq(float(_plays[0].volume_db), Tuning.data.boss_line_db + _director.distance_db(boss.global_position),
		0.7, "at boss_line_db (varied a little)")


# --- The world slots on their signals -------------------------------------------------------


func test_a_barrier_closing_and_opening_plays_its_kind() -> void:
	for kind: int in Barrier.Kind.values():
		var shape: StringName = AudioDirector.BARRIER_KINDS[kind]
		_stub(StringName("barrier_%s_close" % shape))
		_stub(StringName("barrier_%s_open" % shape))
		var barrier := Barrier.new()
		barrier.kind = kind as Barrier.Kind
		add_child_autofree(barrier)
		barrier.position = Vector3(0.0, 0.0, -4.0)
		_plays.clear()
		barrier.close()
		assert_eq(_pools_played(), [StringName("barrier_%s_close" % shape)], "closing a %s" % shape)
		assert_almost_eq(_plays[0].at as Vector3, barrier.global_position + Vector3.UP * barrier.height_m * 0.5,
			Vector3.ONE * 0.001, "at the barrier")
		_plays.clear()
		barrier.close()
		assert_eq(_plays.size(), 0, "closing a closed barrier changes nothing")
		barrier.open()
		assert_eq(_pools_played(), [StringName("barrier_%s_open" % shape)], "opening a %s" % shape)


func test_the_weapon_slots_play_on_their_signals() -> void:
	for pool in [&"weapon_pickup", &"weapon_throw", &"weapon_break", &"weapon_land"]:
		_stub(pool)
	var weapon := Node3D.new()
	add_child_autofree(weapon)
	weapon.global_position = Vector3(0.5, 0.2, -2.0)
	var actor := _enemy(&"")
	CombatEvents.weapon_picked_up.emit(actor, weapon)
	CombatEvents.weapon_thrown.emit(actor, weapon)
	CombatEvents.weapon_broke.emit(actor, weapon)
	CombatEvents.weapon_landed.emit(weapon)
	assert_eq(_pools_played(), [&"weapon_pickup", &"weapon_throw", &"weapon_break", &"weapon_land"])
	for play in _plays:
		assert_almost_eq(play.at as Vector3, weapon.global_position, Vector3.ONE * 0.001, "%s at the weapon" % play.pool)


func test_a_weapon_swing_adds_its_impact_to_the_hit_stack() -> void:
	_stub(&"weapon_pipe_hit")
	_stub(&"thud")
	_stub(&"whoosh")
	var move := MoveData.new()
	move.impact_sfx = &"pipe"
	var victim := _enemy(&"")
	CombatEvents.hit_landed.emit(_hit(victim, move))
	var pools := _pools_played()
	assert_has(pools, &"weapon_pipe_hit")
	assert_has(pools, &"thud", "the tier's stack still plays")
	var impact: Dictionary = _plays.filter(func(p: Dictionary) -> bool: return p.pool == &"weapon_pipe_hit")[0]
	assert_almost_eq(float(impact.volume_db), Tuning.data.weapon_hit_db + AudioDirector.tier_db(CombatTypes.HitTier.LIGHT)
		+ _director.distance_db(impact.at as Vector3), 0.7)
	_plays.clear()
	await get_tree().physics_frame
	CombatEvents.hit_landed.emit(_hit(victim, MoveData.new()))
	assert_does_not_have(_pools_played(), &"weapon_pipe_hit", "a fist names no impact")


func test_the_stings_play_2d_on_arena_cleared_and_level_cleared() -> void:
	_director.bank.pools[&"sting_go"] = [_wav()]
	_director.bank.pools[&"sting_clear"] = [_wav()]
	var arena := Node3D.new()
	add_child_autofree(arena)
	CombatEvents.arena_cleared.emit(arena)
	CombatEvents.level_cleared.emit(arena)
	assert_eq(_plays_2d, [&"sting_go", &"sting_clear"])
	assert_eq(_plays.size(), 0, "a sting is not one of the pooled 3D voices")
	var player := _director.play_2d(&"sting_go", -3.0)
	assert_not_null(player)
	assert_almost_eq(player.volume_db, -3.0, 0.0001)
	assert_true(player.playing)
	assert_eq(player.bus, AudioDirector.SFX_BUS)


func test_an_empty_slot_plays_nothing_and_says_nothing() -> void:
	for pool in [&"barrier_shutter_close", &"weapon_pickup", &"sting_go", &"ko_no_such", &"boss_phase_no_such"]:
		_director.bank.pools.erase(pool)
	var barrier := Barrier.new()
	add_child_autofree(barrier)
	barrier.close()
	CombatEvents.weapon_picked_up.emit(_enemy(&""), barrier)
	CombatEvents.arena_cleared.emit(barrier)
	assert_eq(_plays.size(), 0)
	assert_eq(_plays_2d.size(), 0)
	assert_null(_director.play(&"no_such_pool", Vector3.ZERO, 0.0))
	assert_null(_director.play_2d(&"no_such_pool", 0.0))


# --- The bed -------------------------------------------------------------------------------


func test_the_bed_defaults_to_the_street_and_is_not_a_pooled_voice() -> void:
	assert_eq(_director.ambience, AudioDirector.AMBIENCE_DEFAULT, "no section: the street bed")
	var voices := _director.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D)
	assert_eq(voices.size(), _director.voice_count)
	_director.bank.pools[&"ambience_street"] = [_wav(2.0)]
	_director.ambience = &""
	_director.set_ambience(&"ambience_street")
	assert_eq(_director.bed_pool(), &"ambience_street")
	for voice: Node in voices:
		assert_false((voice as AudioStreamPlayer3D).playing, "the bed is on its own player")
	assert_eq(_plays.size(), 0, "and sends no `played`")
	var stream := _director._bed[0].stream as AudioStreamWAV
	if stream == null:
		stream = _director._bed[1].stream as AudioStreamWAV
	assert_ne(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "a bed loops whatever its import says")


func test_the_bed_crossfades_to_the_section_it_enters_and_back_to_the_default() -> void:
	_director.bank.pools[&"ambience_street"] = [_wav(2.0)]
	_director.bank.pools[&"ambience_roof"] = [_wav(2.0)]
	Tuning.data.ambience_fade_s = 0.2
	_director.ambience = &""
	_director.set_ambience(AudioDirector.AMBIENCE_DEFAULT)
	await _frames(20)
	var section := LevelSection.new()
	section.ambience = &"ambience_roof"
	add_child_autofree(section)
	CombatEvents.section_entered.emit(section)
	assert_eq(_director.ambience, &"ambience_roof")
	await _frames(5)
	var playing := _director._bed.filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_eq(playing.size(), 2, "mid-fade both beds sound")
	await _frames(20)
	playing = _director._bed.filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_eq(playing.size(), 1, "the street bed has faded out and stopped")
	assert_eq(_director.bed_pool(), &"ambience_roof")
	assert_almost_eq((playing[0] as AudioStreamPlayer).volume_db, Tuning.data.ambience_db, 0.5, "at ambience_db")
	var bare := LevelSection.new()
	add_child_autofree(bare)
	CombatEvents.section_entered.emit(bare)
	assert_eq(_director.ambience, AudioDirector.AMBIENCE_DEFAULT, "a section naming none: the default bed")
	await _frames(25)
	assert_eq(_director.bed_pool(), &"ambience_street")


# --- Debug: the legacy bank and the pool volumes -----------------------------------------------


func test_the_legacy_bank_plays_the_placeholders_when_the_debug_switch_is_on() -> void:
	_director.bank.pools[&"thud"] = [_wav()]
	Tuning.data.audio_legacy_bank = true
	assert_eq(_director.bank_for(&"thud"), _director.legacy_bank, "the placeholders have a thud")
	assert_eq(_director.bank_for(&"grunt_punk"), _director.bank, "a pool they never had comes from the bank")
	var voice := _director.play(&"thud", Vector3(0.0, 0.0, -1.0), 0.0)
	assert_true(_director.legacy_bank.pools[&"thud"].has(voice.stream), "the stream is a placeholder")
	Tuning.data.audio_legacy_bank = false
	voice = _director.play(&"thud", Vector3(0.0, 0.0, -1.0), 0.0)
	assert_false(_director.legacy_bank.pools[&"thud"].has(voice.stream))


func test_every_pool_has_its_tuned_volume() -> void:
	var t := Tuning.data
	var expected := {
		&"thud": t.thud_db, &"block_clack": t.block_clack_db, &"grunt": t.grunt_db, &"grunt_boss": t.grunt_db,
		&"effort_kicker": t.windup_db, &"ko_thug": t.ko_db, &"player_grunt": t.player_grunt_db,
		&"boss_phase": t.boss_line_db, &"barrier_car_open": t.barrier_db, &"weapon_pickup": t.weapon_pickup_db,
		&"weapon_throw": t.weapon_throw_db, &"weapon_break": t.weapon_break_db, &"weapon_land": t.weapon_land_db,
		&"weapon_bike_chain_hit": t.weapon_hit_db, &"sting_go": t.sting_go_db, &"sting_clear": t.sting_clear_db,
		&"ambience_roof": t.ambience_db,
	}
	for pool: StringName in expected:
		assert_almost_eq(AudioDirector.pool_db(pool), float(expected[pool]), 0.0001, str(pool))


# --- The audition room ----------------------------------------------------------------------


func _room() -> AuditionRoom:
	var room := AuditionRoom.new()
	add_child_autofree(room)
	return room


func test_the_audition_room_pages_through_the_banks_and_plays_variants_ahead_of_the_listener() -> void:
	var room := _room()
	assert_gt(room.pools.size(), 20, "every pool of the bank and the placeholders")
	assert_eq(room.current_pool(), room.pools[0])
	assert_true(room.handle_key(KEY_BRACKETRIGHT))
	assert_eq(room.page, 1)
	assert_true(room.handle_key(KEY_BRACKETLEFT))
	assert_true(room.handle_key(KEY_BRACKETLEFT))
	assert_eq(room.page, room.pools.size() - 1, "paging wraps")
	room.page = room.pools.find(&"thud")
	assert_true(room.handle_key(KEY_2))
	assert_eq(_pools_played(), [&"thud"])
	assert_almost_eq(_plays[0].at as Vector3, Vector3(0.0, 0.0, -AuditionRoom.AHEAD_M), Vector3.ONE * 0.001,
		"in front of the listener (looking down -Z)")
	assert_almost_eq(float(_plays[0].volume_db), Tuning.data.thud_db, 0.7, "at the pool's tuned volume")
	assert_false(room.play_variant(9), "a variant the bank doesn't have plays nothing")
	assert_false(room.handle_key(KEY_Q), "other keys are not the room's")


func test_the_audition_room_toggles_old_and_new() -> void:
	var room := _room()
	room.page = room.pools.find(&"grunt")
	assert_false(Tuning.data.audio_legacy_bank)
	assert_true(room.handle_key(KEY_MINUS))
	assert_true(Tuning.data.audio_legacy_bank, "minus turns old on")
	assert_eq(room.streams().size(), SfxBank.new(AudioDirector.LEGACY_DIR).count(&"grunt"), "it lists the placeholders' grunts")
	room.handle_key(KEY_MINUS)
	assert_false(Tuning.data.audio_legacy_bank)


func test_the_audition_room_plays_the_whole_bank_and_a_key_stops_it() -> void:
	var room := _room()
	room.page = room.pools.find(&"parry_ting")
	var count := room.streams().size()
	room.handle_key(KEY_EQUAL)
	assert_eq(_plays.size(), 1, "the first variant starts at once")
	await get_tree().create_timer(room.streams()[0].get_length() + AuditionRoom.BANK_GAP_S + 0.2).timeout
	assert_eq(_plays.size(), 2, "the next follows when the first has ended")
	room.handle_key(KEY_BRACKETRIGHT)
	await get_tree().create_timer(2.0).timeout
	assert_eq(_plays.size(), 2, "a key stops the run (parry ting has %d variants)" % count)


func test_the_audition_room_ignores_keys_while_an_overlay_holds_the_fight() -> void:
	var room := _room()
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_BRACKETRIGHT
	GameInput.menu_open = true
	room._unhandled_input(event)
	assert_eq(room.page, 0, "ignored while F1 or F4 is open")
	GameInput.menu_open = false
	room._unhandled_input(event)
	assert_eq(room.page, 1)


func test_the_training_room_has_the_audition_room_and_the_help_overlay_lists_its_keys() -> void:
	var scene := (load("res://game/level/test_room.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await _frames(2)
	assert_not_null(scene.find_child("AuditionRoom", false, false), "the training room has it")
	var rows: Array[String] = []
	for row: Array in HelpOverlay.KEY_ROWS:
		rows.append(str(row[0]))
	for row: Array in AuditionRoom.HELP_ROWS:
		assert_has(rows, str(row[0]), "the help overlay lists the sound room's keys")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
