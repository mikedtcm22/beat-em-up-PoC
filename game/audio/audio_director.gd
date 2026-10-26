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

const SFX_BUS := &"SFX"
const REAR_BUS := &"SFX Rear"
const MUSIC_BUS := &"Music"
const MUSIC_POOL := &"music_loop"

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
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var listener: AudioListener3D
var music: AudioStreamPlayer

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
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_whiffed.connect(_on_attack_whiffed)
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	CombatEvents.grab_escaped.connect(_on_grab_escaped)
	_follow_player()
	_apply_mix()


func _process(delta: float) -> void:
	_clock_s += delta
	_follow_player()
	_apply_mix()
	for i in _voices.size():
		if _voices[i].playing:
			_voices[i].volume_db = _base_db[i] + distance_db(_voices[i].global_position)


## Plays a random variant of `pool` (never the pool's last one) at `at`, at `volume_db`
## varied by up to ±sfx_volume_variation (as amplitude), and at `pitch` varied by up to
## ±sfx_pitch_variation, quieter with distance (distance_db()). Returns the voice it plays
## on, or null when the pool is empty or `at` is beyond Tuning.sfx_max_distance_m.
func play(pool: StringName, at: Vector3, volume_db: float, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var tuning := Tuning.data
	var far := tuning.sfx_max_distance_m
	if far > 0.0 and listener_transform().origin.distance_to(at) > far:
		return null
	var stream := bank.pick(pool, rng)
	if stream == null:
		return null
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
	var effort := play(&"effort", _voice_position(attacker), tuning.windup_db, voice_pitch(attacker))
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
	_last_grunt_s[id] = _clock_s
	if is_player:
		play(&"player_grunt", _voice_position(actor), tuning.player_grunt_db, voice_pitch(actor))
	else:
		play(&"grunt", _voice_position(actor), tuning.grunt_db, voice_pitch(actor))


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
