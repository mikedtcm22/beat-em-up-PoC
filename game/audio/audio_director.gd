class_name AudioDirector
extends Node
## Hit-feel audio (Spec §6 "Audio" and the audio row of the tier table; Spec §8's audio
## cue). Plays the placeholder one-shots of tools/gen_sfx.gd (an SfxBank) for CombatEvents,
## positionally, through a pool of AudioStreamPlayer3D voices. Presentation only: it
## subscribes to CombatEvents and reads actor poses, and never writes game state. Every
## volume, variation and distance is in Tuning's "Audio" group, read when a sound plays.
##
## - **Hits** (`hit_landed`): the tier's layers together at the contact point. Light:
##   whoosh + thud. Heavy: whoosh + thud + crack. Finisher: whoosh + thud + crunch + body
##   fall + sub thump. Every one-shot of a hit is `hit_<tier>_db` louder, so the tiers rank
##   in loudness and not only in layers. A flying or shoved body hitting someone
##   (`input_timing` &"body") has no whoosh: nothing swung.
## - **One swing, several bodies** (hits from one attacker in one physics frame, such as the
##   spinning heel's arc): the swing's own layers (SWING_LAYERS: the whoosh and the sub
##   thump) play once, and every victim after the first is `extra_victim_db` quieter, so a
##   crowd hit doesn't outshout a finisher or pile up in the limiter.
## - **Grunts:** the victim of a clean hit grunts at its eyes (enemies with the enemy voice,
##   the player with its own), at most once per `grunt_min_interval_ms`, each actor's voice
##   pitched by a fixed share of `voice_pitch_spread`.
## - **Hits on the player** sound from `self_hit_offset_m` toward where the blow came from
##   (`-hit.direction`), not from the contact point: that sits within a few centimetres of
##   the listener at the player's eyes, on any side of it, so a frontal block could pan
##   off-center or fall in the rear muffle.
## - **Blocks** (a hit_landed with `hit.blocked`): whoosh + block clack; a perfect block
##   plays the parry ting instead of the clack; a guard break adds the guard-break crash.
##   No grunt.
## - **Armor** (a hit_landed with `hit.armor_absorbed`: a light hit on the Bruiser or the boss): the
##   swing's whoosh and the block clack pitched down by `armor_clank_pitch` (a clank, `armor_clank_db`
##   on top of the clack's own). No thud, no grunt: the hit registered and did nothing.
## - **Whiffs** (`attack_whiffed`): a whoosh at the striking limb, no impact.
## - **Wind-ups** (`windup_started`, while `Tuning.rear_warning_audio`): an effort grunt
##   and a whoosh at the attacker, so the player hears where an attack is coming from. A
##   wind-up knocked out of (`windup_ended` interrupted) cuts both: the effort would talk
##   over the pain grunt that follows.
## - **Breaking free of a grab** (`grab_escaped`): a whoosh and a block clack at the holder's chest
##   (the grip knocked off and the holder shoved away) and the holder's grunt, `grab_break_db`
##   louder: the player's reward for the mash.
## - **Music:** a placeholder loop while `Tuning.music_enabled` (off by default).
## - **Voices per archetype** (Milestone 6, D20): a grunt, an effort or a KO line comes from the pool
##   `<base>_<archetype>` (`grunt_bruiser`) when the actor has an `archetype` and that pool has files, else
##   from the shared `<base>` pool. A KO (`ko`) plays the enemy's own KO line (and cuts its grunt); the boss's
##   phase change plays `boss_phase`.
## - **Weapons** (D22, D23): a swing whose move names an `impact_sfx` adds `weapon_<impact_sfx>_hit` to the
##   hit stack; pickup, throw, break and landing play `weapon_pickup|throw|break|land` where the weapon is.
## - **Barriers** (`barrier_moving`): `barrier_<shutter|gate|car>_<close|open>` where the barrier is.
## - **Stings** (2D, `play_2d()`): `sting_go` on `arena_cleared`, `sting_clear` on `level_cleared`.
## - **Ambience** (D8): one looping bed on its own players, not the pooled voices, crossfaded to the pool the
##   player's section names (`section_entered`, `LevelSection.ambience`), `ambience_street` with no section.
##   An empty pool plays nothing and logs nothing: the slots stay empty until their sounds exist.
## - **Debug `audio_legacy_bank`:** every pool the Milestone 2 placeholders had plays from them instead
##   (tests/fixtures/sfx_legacy/), for the audition room's old / new A/B.
##
## Every one-shot takes a random variant of its pool, never the pool's last one, with its
## pitch and volume varied by up to `sfx_pitch_variation` / `sfx_volume_variation` (±8%).
## With every voice busy, the sound started longest ago gives way, a wind-up cue still
## sounding for its attacker's wind-up last (it may be the only warning). The listener rides the
## player's eyes and look, in every camera mode. A sound plays at its layer's volume within
## `sfx_unit_size_m` of it, 6 dB quieter each time the distance doubles beyond that
## (updated every frame), and not at all beyond `sfx_max_distance_m`. Sounds more than
## `rear_muffle_angle_deg` off the look play through the "SFX Rear" bus, low-passed at
## `rear_muffle_hz`: stereo alone can't tell behind from in front. Everything runs on real
## time: a sound starts on its event's frame and never stretches with hitstop, slow-mo or
## the debug time scale.
##
## Buses (created on first use when the project has none): "SFX" (a hard limiter, so
## stacked layers never clip, with `sfx_volume_db` as its pre-gain) and "SFX Rear" (a
## low-pass, into "SFX") for one-shots, and "Music".

## Emitted for every one-shot played: its pool and the pooled voice it plays on.
signal played(pool: StringName, voice: AudioStreamPlayer3D)
## Emitted for every 2D one-shot (play_2d()): its pool and the player it plays on.
signal played_2d(pool: StringName, player: AudioStreamPlayer)
## Emitted when the bed changes: the new pool (empty for silence).
signal ambience_changed(pool: StringName)

const SFX_BUS := &"SFX"
const REAR_BUS := &"SFX Rear"
const MUSIC_BUS := &"Music"
const MUSIC_POOL := &"music_loop"
## The bed with no section (the crowd and training rooms) or a section that names none.
const AMBIENCE_DEFAULT := &"ambience_street"
## The placeholders' folder, the audition room's "old".
const LEGACY_DIR := "res://tests/fixtures/sfx_legacy/"
## Barrier.Kind in order, as the pool names spell it.
const BARRIER_KINDS: Array[StringName] = [&"shutter", &"gate", &"car"]
## Second players for the bed: one fading out while the next fades in.
const BED_PLAYERS := 2
## Short stings and other non-positional one-shots (play_2d()).
const STING_PLAYERS := 4

## The pools layered on a clean hit of each tier (Spec §6).
const TIER_LAYERS: Dictionary = {
	CombatTypes.HitTier.LIGHT: [&"whoosh", &"thud"],
	CombatTypes.HitTier.HEAVY: [&"whoosh", &"thud", &"crack"],
	CombatTypes.HitTier.FINISHER: [&"whoosh", &"thud", &"crunch", &"body_fall", &"sub_thump"],
}

## Layers heard once per swing, however many bodies it hits in one frame: the whoosh (one
## limb went by) and the sub thump (the finisher's weight). The others play per victim.
const SWING_LAYERS: Array[StringName] = [&"whoosh", &"sub_thump"]

## The TuningData property holding each hit or block pool's volume in dB.
const LAYER_DB: Dictionary = {
	&"whoosh": &"whoosh_db",
	&"thud": &"thud_db",
	&"crack": &"crack_db",
	&"crunch": &"crunch_db",
	&"body_fall": &"body_fall_db",
	&"sub_thump": &"sub_thump_db",
	&"block_clack": &"block_clack_db",
	&"parry_ting": &"parry_ting_db",
	&"guard_break": &"guard_break_db",
}

## Pooled one-shot voices; with all of them busy, a new sound takes the one started longest
## ago. A voice budget, not a feel number: a synthetic six-enemy brawl (three attackers on
## the player, the player's chains, a three-body finisher every 2 s) peaks at about 30, and
## tests/test_audio_crowd.gd measures it with six wind-ups sounding on top.
@export var voice_count: int = 32
## The listener rides the player's eyes and look, so every camera (the debug views too)
## hears what the player would. Off, or with no player, the active camera hears.
@export var listen_from_player: bool = true

var bank: SfxBank
## The Milestone 2 placeholders, loaded the first time Debug `audio_legacy_bank` is on.
var legacy_bank: SfxBank
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var listener: AudioListener3D
var music: AudioStreamPlayer
## The bed players (the pool each plays, its fade share 0..1 and where it is heading) and the pool the
## bed should be (what set_ambience() last asked for).
var ambience: StringName = &""
var _bed: Array[AudioStreamPlayer] = []
var _bed_pool: Array[StringName] = []
var _bed_level: Array[float] = []
var _bed_target: Array[float] = []
var _stings: Array[AudioStreamPlayer] = []
var _next_sting: int = 0

var _voices: Array[AudioStreamPlayer3D] = []
## Each voice's volume before the distance fall-off (its layer's, varied).
var _base_db: Array[float] = []
## When each voice's sound started, as a count of play() calls (higher is newer).
var _started: Array[int] = []
## Instance id of the actor whose wind-up each voice is sounding (0: none).
var _windup_of: Array[int] = []
## Wind-up cues taken over by another sound while their wind-up was still running (only when
## every voice held one): the probe's R14, 0 in a healthy crowd fight.
var windup_voices_stolen: int = 0
var _plays: int = 0
var _next: int = 0
## The swing the last hit came from (attacker instance id, physics frame), and the victims
## it has hit in that frame.
var _swing: Vector2i = Vector2i.ZERO
var _swing_victims: Array[int] = []
var _music_on: bool = false
## Seconds of _process time, for the grunt interval.
var _clock_s: float = 0.0
## Actor instance id -> _clock_s of its last grunt.
var _last_grunt_s: Dictionary[int, float] = {}
## Actor instance id -> the voice its last grunt plays on (a KO line cuts it).
var _grunt_voice: Dictionary[int, AudioStreamPlayer3D] = {}
var _player: PlayerCharacter


func _init() -> void:
	name = &"AudioDirector"


func _ready() -> void:
	add_to_group(&"audio_director")
	rng.randomize()
	_ensure_buses()
	bank = SfxBank.new()
	listener = AudioListener3D.new()
	listener.name = &"Listener"
	add_child(listener)
	for i in voice_count:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % i
		voice.bus = SFX_BUS
		# The fall-off is distance_db(), applied every frame: Godot's own models raise sounds
		# inside unit_size, and max_db clamps volume and distance gain together, which
		# flattened every layer within reach to one loudness. Its distance low-pass (tied to
		# that gain) is off too; the rear muffle is the one filter.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.attenuation_filter_db = 0.0
		add_child(voice)
		_voices.append(voice)
		_base_db.append(0.0)
		_started.append(0)
		_windup_of.append(0)
	music = AudioStreamPlayer.new()
	music.name = &"Music"
	music.bus = MUSIC_BUS
	music.stream = bank.pick(MUSIC_POOL, rng)
	add_child(music)
	for i in BED_PLAYERS:
		var bed := AudioStreamPlayer.new()
		bed.name = "Bed%d" % i
		bed.bus = SFX_BUS
		add_child(bed)
		_bed.append(bed)
		_bed_pool.append(&"")
		_bed_level.append(0.0)
		_bed_target.append(0.0)
	for i in STING_PLAYERS:
		var sting := AudioStreamPlayer.new()
		sting.name = "Sting%d" % i
		sting.bus = SFX_BUS
		add_child(sting)
		_stings.append(sting)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_whiffed.connect(_on_attack_whiffed)
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	CombatEvents.grab_escaped.connect(_on_grab_escaped)
	CombatEvents.ko.connect(_on_ko)
	CombatEvents.boss_phase_changed.connect(_on_boss_phase_changed)
	CombatEvents.barrier_moving.connect(_on_barrier_moving)
	CombatEvents.weapon_picked_up.connect(_on_weapon_picked_up)
	CombatEvents.weapon_thrown.connect(_on_weapon_thrown)
	CombatEvents.weapon_broke.connect(_on_weapon_broke)
	CombatEvents.weapon_landed.connect(_on_weapon_landed)
	CombatEvents.arena_cleared.connect(_on_arena_cleared)
	CombatEvents.level_cleared.connect(_on_level_cleared)
	CombatEvents.section_entered.connect(_on_section_entered)
	_follow_player()
	_apply_mix()
	set_ambience(AMBIENCE_DEFAULT)


func _process(delta: float) -> void:
	_clock_s += delta
	_follow_player()
	_apply_mix()
	_step_bed(delta)
	for i in _voices.size():
		if _voices[i].playing:
			_voices[i].volume_db = _base_db[i] + distance_db(_voices[i].global_position)


## Plays a random variant of `pool` (never the pool's last one) at `at`, at `volume_db`
## varied by up to ±sfx_volume_variation (as amplitude), and at `pitch` varied by up to
## ±sfx_pitch_variation, quieter with distance (distance_db()). Returns the voice it plays
## on, or null when the pool is empty or `at` is beyond Tuning.sfx_max_distance_m.
func play(pool: StringName, at: Vector3, volume_db: float, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var far := Tuning.data.sfx_max_distance_m
	if far > 0.0 and listener_transform().origin.distance_to(at) > far:
		return null
	var stream := _pick(pool)
	if stream == null:
		return null
	return play_stream(pool, stream, at, volume_db, pitch)


## `play()` for a stream already chosen (the audition room's digit keys pick a variant): the same voice
## taking, variation, rear muffle and distance fall-off, and `played` for `pool`.
func play_stream(pool: StringName, stream: AudioStream, at: Vector3, volume_db: float, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var tuning := Tuning.data
	var index := _take_voice()
	var voice := _voices[index]
	_plays += 1
	_started[index] = _plays
	_windup_of[index] = 0
	voice.stream = stream
	voice.global_position = at
	voice.bus = REAR_BUS if is_behind_listener(at) else SFX_BUS
	var pitch_var := tuning.sfx_pitch_variation
	voice.pitch_scale = pitch * (1.0 + rng.randf_range(-pitch_var, pitch_var))
	var volume_var := tuning.sfx_volume_variation
	_base_db[index] = volume_db + linear_to_db(1.0 + rng.randf_range(-volume_var, volume_var))
	voice.volume_db = _base_db[index] + distance_db(at)
	voice.play()
	played.emit(pool, voice)
	return voice


## A non-positional one-shot (a GO or CLEAR sting): a random variant of `pool` at `volume_db`, never
## the pool's last one, on the SFX bus, on one of STING_PLAYERS players (the oldest gives way). Returns
## the player, or null when the pool is empty. Not one of the pooled voices.
func play_2d(pool: StringName, volume_db: float) -> AudioStreamPlayer:
	var stream := _pick(pool)
	if stream == null:
		return null
	return play_stream_2d(pool, stream, volume_db)


## `play_2d()` for a stream already chosen.
func play_stream_2d(pool: StringName, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := _stings[_next_sting]
	_next_sting = (_next_sting + 1) % _stings.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	player.play()
	played_2d.emit(pool, player)
	return player


## A variant of `pool` the way play() would take it: from the placeholders while Debug
## `audio_legacy_bank` is on and they have the pool, else from the bank. Null for an empty pool.
func _pick(pool: StringName) -> AudioStream:
	var source := bank_for(pool)
	return source.pick(pool, rng)


## The bank a pool plays from: the placeholders (Debug `audio_legacy_bank`) when they have it, else the
## real one.
func bank_for(pool: StringName) -> SfxBank:
	if Tuning.data.audio_legacy_bank:
		if legacy_bank == null:
			legacy_bank = SfxBank.new(LEGACY_DIR)
		if legacy_bank.count(pool) > 0:
			return legacy_bank
	return bank


## Where sounds are heard from: the listener riding the player, else the active camera.
func listener_transform() -> Transform3D:
	if listener.is_current():
		return listener.global_transform
	var camera := get_viewport().get_camera_3d()
	return camera.global_transform if camera else listener.global_transform


## The distance fall-off for a sound at `at`, in dB: 0 within Tuning.sfx_unit_size_m of
## the listener, 6 dB less each time the distance doubles beyond it (inverse distance).
func distance_db(at: Vector3) -> float:
	var unit := Tuning.data.sfx_unit_size_m
	var distance := listener_transform().origin.distance_to(at)
	return linear_to_db(unit / maxf(distance, unit))


## True when `at` lies more than Tuning.rear_muffle_angle_deg off the listener's flat look.
func is_behind_listener(at: Vector3) -> bool:
	var view := listener_transform()
	var to := at - view.origin
	to.y = 0.0
	var ahead := -view.basis.z
	ahead.y = 0.0
	if to.length_squared() < 0.0001 or ahead.length_squared() < 0.0001:
		return false
	return rad_to_deg(ahead.angle_to(to)) > Tuning.data.rear_muffle_angle_deg


# --- CombatEvents ------------------------------------------------------------------------


func _on_hit_landed(hit: HitInfo) -> void:
	var tuning := Tuning.data
	var at := impact_position(hit)
	var first := _first_victim_of_swing(hit)
	var gain := tier_db(hit.tier) + (0.0 if first else tuning.extra_victim_db)
	var swung := first and hit.input_timing != &"body"
	if hit.blocked:
		if swung:
			play(&"whoosh", at, tuning.whoosh_db + gain)
		if hit.perfect_block:
			play(&"parry_ting", at, tuning.parry_ting_db + gain)
		else:
			play(&"block_clack", at, tuning.block_clack_db + gain)
		if hit.guard_broken:
			play(&"guard_break", at, tuning.guard_break_db + gain)
		return
	if hit.armor_absorbed:
		if swung:
			play(&"whoosh", at, tuning.whoosh_db + gain)
		play(&"block_clack", at, tuning.block_clack_db + tuning.armor_clank_db + gain, tuning.armor_clank_pitch)
		return
	for pool: StringName in TIER_LAYERS.get(hit.tier, []):
		if pool == &"whoosh" and not swung:
			continue
		if pool in SWING_LAYERS and not first:
			continue
		play(pool, at, layer_db(pool) + gain)
	if hit.move != null and hit.move.impact_sfx != &"":
		play(weapon_hit_pool(hit.move.impact_sfx), at, tuning.weapon_hit_db + gain)
	_grunt(hit.victim)


func _on_attack_whiffed(attacker: Node3D, move: MoveData) -> void:
	if attacker == null:
		return
	play(&"whoosh", _strike_position(attacker, move), Tuning.data.whiff_db)


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	var tuning := Tuning.data
	if attacker == null or not tuning.rear_warning_audio:
		return
	var id := attacker.get_instance_id()
	# Each cue is tagged as the attacker's wind-up the moment it starts, so the next one cannot
	# take it over.
	var effort := play(voice_pool(&"effort", attacker), _voice_position(attacker), tuning.windup_db, voice_pitch(attacker))
	if effort:
		_windup_of[_voices.find(effort)] = id
	var whoosh := play(&"whoosh", _strike_position(attacker, move), tuning.windup_db)
	if whoosh:
		_windup_of[_voices.find(whoosh)] = id


## A wind-up knocked out of (a hit, a grab) cuts its effort and whoosh at once. One that ends
## in its strike lets them ring out, and they stop being protected from voice stealing: the
## warning they were is over.
func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	if attacker == null:
		return
	var id := attacker.get_instance_id()
	for i in _voices.size():
		if _windup_of[i] == id:
			_windup_of[i] = 0
			if interrupted and _voices[i].playing:
				_voices[i].stop()


## A held player mashed free of an enemy's grab: the grip tears off with a whoosh and a clack at
## the holder's chest, and the holder grunts as it is shoved away (existing pools, played
## `grab_break_db` louder).
func _on_grab_escaped(_victim: Node3D, holder: Node3D) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var tuning := Tuning.data
	var actor := holder as CombatActor
	var at := actor.get_chest_position() if actor and actor.rig else holder.global_position
	play(&"whoosh", at, tuning.whoosh_db + tuning.grab_break_db)
	play(&"block_clack", at, tuning.block_clack_db + tuning.grab_break_db)
	_grunt(holder)


## A KO: the enemy's own KO line at its eyes, cutting the grunt of the blow that did it (the player and
## the dummy, whose archetype is empty, have no KO pool: `ko` has no files).
func _on_ko(victim: Node3D, _hit: HitInfo) -> void:
	if victim == null or not is_instance_valid(victim) or not victim.is_in_group(&"enemy"):
		return
	var grunt: AudioStreamPlayer3D = _grunt_voice.get(victim.get_instance_id())
	var pool := voice_pool(&"ko", victim)
	if bank_for(pool).count(pool) == 0:
		return
	if grunt != null and is_instance_valid(grunt) and grunt.playing:
		grunt.stop()
	play(pool, _voice_position(victim), Tuning.data.ko_db, voice_pitch(victim))


## The boss entering phase 2: its roar (`boss_phase`, one line a phase), at its eyes.
func _on_boss_phase_changed(boss: Node3D, _phase: int) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	play(&"boss_phase", _voice_position(boss), Tuning.data.boss_line_db)


func _on_barrier_moving(barrier: Node3D, closing: bool) -> void:
	if barrier == null or not is_instance_valid(barrier):
		return
	var kind := int(barrier.get(&"kind"))
	var shape := BARRIER_KINDS[kind] if kind >= 0 and kind < BARRIER_KINDS.size() else BARRIER_KINDS[0]
	var pool := StringName("barrier_%s_%s" % [shape, "close" if closing else "open"])
	var height: Variant = barrier.get(&"height_m")
	var at := barrier.global_position + Vector3.UP * (float(height) * 0.5 if height is float else 0.0)
	play(pool, at, Tuning.data.barrier_db)


func _on_weapon_picked_up(_actor: Node3D, weapon: Node3D) -> void:
	_play_weapon(&"weapon_pickup", weapon, Tuning.data.weapon_pickup_db)


func _on_weapon_thrown(_actor: Node3D, weapon: Node3D) -> void:
	_play_weapon(&"weapon_throw", weapon, Tuning.data.weapon_throw_db)


func _on_weapon_broke(_actor: Node3D, weapon: Node3D) -> void:
	_play_weapon(&"weapon_break", weapon, Tuning.data.weapon_break_db)


func _on_weapon_landed(weapon: Node3D) -> void:
	_play_weapon(&"weapon_land", weapon, Tuning.data.weapon_land_db)


func _play_weapon(pool: StringName, weapon: Node3D, volume_db: float) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	play(pool, weapon.global_position, volume_db)


## GO: the arena's table is done and its way ahead opens.
func _on_arena_cleared(_arena: Node3D) -> void:
	play_2d(&"sting_go", Tuning.data.sting_go_db)


## CLEAR!: the level's last arena is done.
func _on_level_cleared(_level: Node3D) -> void:
	play_2d(&"sting_clear", Tuning.data.sting_clear_db)


func _on_section_entered(section: Node3D) -> void:
	var pool: Variant = section.get(&"ambience") if section != null else null
	set_ambience(StringName(pool) if (pool is StringName or pool is String) and str(pool) != "" else AMBIENCE_DEFAULT)


# --- The bed -----------------------------------------------------------------------------


## Crossfades the bed to `pool` over Tuning.ambience_fade_s: the current bed fades out as the new one
## fades in. The same pool again changes nothing; an empty pool (no files) fades the bed out and plays
## nothing. The bed loops, whatever the file's import says.
func set_ambience(pool: StringName) -> void:
	if pool == ambience:
		return
	ambience = pool
	var stream := _pick(pool) if pool != &"" else null
	var now: int = _bed_pool.find(pool) if stream != null else -1
	for i in _bed.size():
		_bed_target[i] = 1.0 if i == now else 0.0
	if stream != null and now < 0:
		# Take the quietest player (a fully faded one when there is one) for the new bed.
		var free := 0
		for i in _bed.size():
			if _bed_level[i] < _bed_level[free]:
				free = i
		_bed_pool[free] = pool
		_bed[free].stop()
		_bed[free].stream = _looped(stream)
		_bed_level[free] = 0.0
		_bed_target[free] = 1.0
		_bed[free].volume_db = -80.0
		_bed[free].play()
	ambience_changed.emit(pool if stream != null else &"")


## `stream` with a forward loop over its whole length (a bed is a file that loops; the music loop's
## .import sets its own).
func _looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func _step_bed(delta: float) -> void:
	var tuning := Tuning.data
	var step := delta / maxf(Engine.time_scale, 0.01) / maxf(tuning.ambience_fade_s, 0.01)
	for i in _bed.size():
		_bed_level[i] = move_toward(_bed_level[i], _bed_target[i], step)
		if _bed[i].playing:
			_bed[i].volume_db = tuning.ambience_db + linear_to_db(maxf(_bed_level[i], 0.0001))
			if _bed_level[i] <= 0.0 and _bed_target[i] <= 0.0:
				_bed[i].stop()
				_bed_pool[i] = &""


## The pool the bed is settled on (the player in a section, or the default): the one whose player is
## audible and heading up; empty when silent.
func bed_pool() -> StringName:
	for i in _bed.size():
		if _bed_target[i] >= 1.0 and _bed[i].playing:
			return _bed_pool[i]
	return &""


# --- Helpers -----------------------------------------------------------------------------


## Where `hit`'s one-shots play: its contact point, or on the player, Tuning.self_hit_offset_m
## from the listener toward the attacker (the contact sits around the listener itself).
func impact_position(hit: HitInfo) -> Vector3:
	if not (is_instance_valid(hit.victim) and hit.victim.is_in_group(&"player")):
		return hit.contact_point
	var from := -hit.direction
	from.y = 0.0
	if from.length_squared() < 0.0001:
		return hit.contact_point
	return listener_transform().origin + from.normalized() * Tuning.data.self_hit_offset_m


## The extra volume in dB of every one-shot of a `tier` hit (Tuning.data.hit_<tier>_db).
static func tier_db(tier: CombatTypes.HitTier) -> float:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return Tuning.data.hit_heavy_db
		CombatTypes.HitTier.FINISHER:
			return Tuning.data.hit_finisher_db
	return Tuning.data.hit_light_db


## A hit or block pool's volume in dB (Tuning.data.<pool>_db).
static func layer_db(pool: StringName) -> float:
	if not LAYER_DB.has(pool):
		return 0.0
	return float(Tuning.data.get(LAYER_DB[pool]))


## The pool of `actor`'s `base` voice (&"grunt", &"effort", &"ko"): `<base>_<archetype>` when the actor has an
## `archetype` and that pool has files, else `base` itself (the dummy's archetype is empty, a bare Node3D has
## none: both use the shared pool).
func voice_pool(base: StringName, actor: Node) -> StringName:
	var archetype: Variant = actor.get(&"archetype")
	if (archetype is StringName or archetype is String) and str(archetype) != "":
		var specific := StringName("%s_%s" % [base, archetype])
		if bank_for(specific).count(specific) > 0:
			return specific
	return base


## The pool of a weapon's impact layer: `weapon_<impact_sfx>_hit`.
static func weapon_hit_pool(impact_sfx: StringName) -> StringName:
	return StringName("weapon_%s_hit" % impact_sfx)


## The tuned volume in dB of any pool the director plays, by its name: a hit or block layer, a voice (the
## archetype's pools share the base's), a world sound, a sting or the bed. The audition room plays every
## bank at it.
static func pool_db(pool: StringName) -> float:
	var tuning := Tuning.data
	var key := str(pool)
	if LAYER_DB.has(pool):
		return layer_db(pool)
	if key == "player_grunt":
		return tuning.player_grunt_db
	if key == "boss_phase":
		return tuning.boss_line_db
	if key.begins_with("grunt"):
		return tuning.grunt_db
	if key.begins_with("effort"):
		return tuning.windup_db
	if key.begins_with("ko"):
		return tuning.ko_db
	if key.begins_with("barrier_"):
		return tuning.barrier_db
	if key.begins_with("weapon_"):
		if key.ends_with("_hit"):
			return tuning.weapon_hit_db
		match key:
			"weapon_pickup":
				return tuning.weapon_pickup_db
			"weapon_throw":
				return tuning.weapon_throw_db
			"weapon_break":
				return tuning.weapon_break_db
			"weapon_land":
				return tuning.weapon_land_db
	if key == "sting_go":
		return tuning.sting_go_db
	if key == "sting_clear":
		return tuning.sting_clear_db
	if key.begins_with("ambience"):
		return tuning.ambience_db
	return 0.0


## `actor`'s voice pitch: 1 plus a fixed share (from its name) of ±voice_pitch_spread, times
## its `voice_pitch_mult` when it has one (a Bruiser's or the boss's deeper voice).
static func voice_pitch(actor: Node) -> float:
	var spread := Tuning.data.voice_pitch_spread
	var voice := RandomNumberGenerator.new()
	voice.seed = hash(str(actor.name))
	var pitch := 1.0 + voice.randf_range(-spread, spread)
	var mult: Variant = actor.get(&"voice_pitch_mult")
	if mult is float and mult > 0.0:
		pitch *= mult
	return pitch


func _grunt(actor: Node3D) -> void:
	if actor == null:
		return
	var is_player := actor.is_in_group(&"player")
	if not is_player and not actor.is_in_group(&"enemy"):
		return
	var tuning := Tuning.data
	var id := actor.get_instance_id()
	var interval_s := tuning.grunt_min_interval_ms / 1000.0
	if _last_grunt_s.has(id) and _clock_s - _last_grunt_s[id] < interval_s:
		return
	# Forget the actors whose interval has run out (freed ones included), so the table only
	# holds who grunted lately.
	for other: int in _last_grunt_s.keys():
		if _clock_s - _last_grunt_s[other] >= interval_s:
			_last_grunt_s.erase(other)
			_grunt_voice.erase(other)
	_last_grunt_s[id] = _clock_s
	if is_player:
		play(&"player_grunt", _voice_position(actor), tuning.player_grunt_db, voice_pitch(actor))
	else:
		var voice := play(voice_pool(&"grunt", actor), _voice_position(actor), tuning.grunt_db, voice_pitch(actor))
		if voice != null:
			_grunt_voice[id] = voice


## Where `actor`'s voice comes from: its eyes.
func _voice_position(actor: Node3D) -> Vector3:
	var combat_actor := actor as CombatActor
	if combat_actor and combat_actor.rig:
		return combat_actor.rig.get_point_position(&"EyePoint")
	return actor.global_position


## Where `move`'s swing is: its first point hitbox (the fist or foot), else the chest.
func _strike_position(actor: Node3D, move: MoveData) -> Vector3:
	var combat_actor := actor as CombatActor
	if combat_actor == null or combat_actor.rig == null:
		return actor.global_position
	if move:
		for spec in move.hitboxes:
			if spec.kind == HitboxSpec.Kind.POINT_SPHERE:
				return combat_actor.rig.get_point_transform(spec.point) * spec.offset
	return combat_actor.get_chest_position()


## True for the first victim `hit`'s swing (its attacker, this physics frame) strikes, false
## for every further body the same swing hits in the frame. A victim hit again starts a
## new swing (two hits on one body are two swings).
func _first_victim_of_swing(hit: HitInfo) -> bool:
	var attacker_id := hit.attacker.get_instance_id() if is_instance_valid(hit.attacker) else 0
	var victim_id := hit.victim.get_instance_id() if is_instance_valid(hit.victim) else 0
	var swing := Vector2i(attacker_id, Engine.get_physics_frames())
	if swing != _swing or victim_id in _swing_victims:
		_swing = swing
		_swing_victims = [victim_id]
		return true
	_swing_victims.append(victim_id)
	return false


## The index of a free voice, else of the busy one started longest ago (stopped), a wind-up
## cue whose wind-up is still running last: in a crowd it may be the only warning of an attack
## from behind. Searching from the last one taken keeps a voice's tail free as long as possible.
func _take_voice() -> int:
	var n := _voices.size()
	for k in n:
		var index := (_next + k) % n
		if not _voices[index].playing:
			_next = (index + 1) % n
			return index
	var oldest := -1
	for i in n:
		if _windup_of[i] == 0 and (oldest < 0 or _started[i] < _started[oldest]):
			oldest = i
	if oldest < 0:
		# Every voice is a live wind-up cue: the oldest of them gives way.
		windup_voices_stolen += 1
		oldest = 0
		for i in n:
			if _started[i] < _started[oldest]:
				oldest = i
	_voices[oldest].stop()
	return oldest


func _follow_player() -> void:
	if not listen_from_player:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if _player == null or _player.rig == null:
		return
	listener.global_transform = Transform3D(_player.get_look_basis(), _player.get_eye_transform().origin)
	if not listener.is_current():
		listener.make_current()


## Bus volumes, the rear muffle and the music, from Tuning (every frame: values change live).
func _apply_mix() -> void:
	var tuning := Tuning.data
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	if sfx >= 0:
		# A bus's volume applies after its effects, so on the SFX bus it left the limiter
		# squashing as hard at any setting: the SFX volume goes in as the limiter's pre-gain.
		var limiter := sfx_limiter()
		if limiter:
			limiter.pre_gain_db = tuning.sfx_volume_db
			AudioServer.set_bus_volume_db(sfx, 0.0)
		else:
			AudioServer.set_bus_volume_db(sfx, tuning.sfx_volume_db)
	var rear := AudioServer.get_bus_index(REAR_BUS)
	if rear >= 0 and AudioServer.get_bus_effect_count(rear) > 0:
		var low_pass := AudioServer.get_bus_effect(rear, 0) as AudioEffectLowPassFilter
		if low_pass:
			low_pass.cutoff_hz = tuning.rear_muffle_hz
	music.volume_db = tuning.music_volume_db
	var want_music := tuning.music_enabled and music.stream != null
	if want_music != _music_on:
		_music_on = want_music
		if want_music:
			music.play()
		else:
			music.stop()


## The SFX bus's hard limiter (null without one: a project bus layout may leave it out).
func sfx_limiter() -> AudioEffectHardLimiter:
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	if sfx < 0:
		return null
	for i in AudioServer.get_bus_effect_count(sfx):
		var limiter := AudioServer.get_bus_effect(sfx, i) as AudioEffectHardLimiter
		if limiter:
			return limiter
	return null


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		AudioServer.add_bus_effect(_add_bus(SFX_BUS, &"Master"), AudioEffectHardLimiter.new())
	if AudioServer.get_bus_index(REAR_BUS) < 0:
		AudioServer.add_bus_effect(_add_bus(REAR_BUS, SFX_BUS), AudioEffectLowPassFilter.new())
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		_add_bus(MUSIC_BUS, &"Master")


static func _add_bus(bus_name: StringName, send: StringName) -> int:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	return index
