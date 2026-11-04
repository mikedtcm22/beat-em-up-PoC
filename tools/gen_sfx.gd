extends SceneTree
## Generates the Milestone 2 placeholder sound effects (Spec §6 "Audio", WP3 in
## docs/milestones/M2-plan.md) as 16-bit mono 44.1 kHz WAV files (see OUT_DIR).
## Everything is synthesized here: filtered and enveloped noise, tones, decaying modes and
## a small formant voice, with no recordings. Each pool has several variants named
## `<pool>_<nn>.wav`; game/audio/sfx_bank.gd loads every pool it finds in that folder, so
## a new pool or variant needs no code beyond this script (the AudioDirector picks pools
## by name).
##
## Milestone 6: the final sounds come from ElevenLabs (tools/audio/), and this script now writes the
## Milestone 2 placeholders to tests/fixtures/sfx_legacy/ (the audition room's "old", Debug
## `audio_legacy_bank`), where they stay as the fixture; assets/export/sfx/ holds whatever the manifest
## (assets/source/sfx/manifest.json) names. The files there that are still gen_sfx rows are byte-identical
## copies of these, which `tools/audio/ingest.py --check` verifies.
##
## Usage, from the project root:
##     godot --headless -s tools/gen_sfx.gd
##     godot --headless --import --quit     (import the new or changed .wav files)
## Success is the "gen_sfx: wrote N sounds" line; a failed save prints "gen_sfx: FAILED"
## and exits 1.
##
## Output is deterministic: every sound seeds its own random numbers from its file name, so
## a re-run with unchanged code leaves git clean, and changing one sound leaves the others
## alone. AudioStreamWAV.save_to_wav() writes no loop points, so the music loop loops
## through its .import file (edit/loop_mode=2, Forward): the script never touches .import
## files, so keep that one when regenerating.
##
## The numbers below are the placeholders' sound design. The in-game balance (each
## layer's volume, the pitch and volume variation, distances) is tuned live in Tuning's
## "Audio" group, never here. Files are normalized to the same peak, so a layer's volume
## in Tuning is its whole loudness.

const OUT_DIR := "res://tests/fixtures/sfx_legacy/"
const RATE := 44100
## Every file is normalized to this peak (-1 dBFS).
const PEAK := 0.89
## Fade-out at the end of each one-shot, so a cut tail never clicks.
const FADE_OUT_S := 0.008
## Fade-in of the voices: their breath noise starts at full level (the hits start from zero
## on their own attack envelopes).
const VOICE_FADE_IN_S := 0.004

enum F { LOW, BAND, HIGH }

## Enemy pain grunts. Each voice: f0 = [start, peak, end] Hz, peak = where f0 peaks (share
## of the duration), formants = Vector3(Hz, bandwidth Hz, gain), dur s, attack s, onset =
## seconds of breath before the voice starts, breath = breath noise level, fry = closing
## share in vocal fry, close = how far F1 falls at the end (the mouth closing).
const ENEMY_GRUNTS: Array[Dictionary] = [
	{  # "ugh"
		f0 = [150.0, 172.0, 98.0], peak = 0.15, dur = 0.24, attack = 0.01, onset = 0.0,
		breath = 0.08, fry = 0.35, close = 0.3,
		formants = [Vector3(640, 80, 1.0), Vector3(1190, 90, 0.55), Vector3(2390, 120, 0.28)],
	},
	{  # "oof"
		f0 = [140.0, 152.0, 96.0], peak = 0.12, dur = 0.2, attack = 0.008, onset = 0.0,
		breath = 0.16, fry = 0.25, close = 0.0,
		formants = [Vector3(330, 60, 1.0), Vector3(880, 90, 0.45), Vector3(2240, 120, 0.2)],
	},
	{  # "agh"
		f0 = [166.0, 188.0, 112.0], peak = 0.18, dur = 0.3, attack = 0.012, onset = 0.0,
		breath = 0.1, fry = 0.4, close = 0.2,
		formants = [Vector3(730, 90, 1.0), Vector3(1090, 100, 0.6), Vector3(2440, 130, 0.3)],
	},
	{  # "huh"
		f0 = [132.0, 146.0, 92.0], peak = 0.2, dur = 0.21, attack = 0.01, onset = 0.035,
		breath = 0.14, fry = 0.3, close = 0.25,
		formants = [Vector3(500, 80, 1.0), Vector3(1500, 100, 0.5), Vector3(2500, 120, 0.3)],
	},
	{  # "awh"
		f0 = [122.0, 140.0, 86.0], peak = 0.15, dur = 0.28, attack = 0.012, onset = 0.0,
		breath = 0.09, fry = 0.45, close = 0.15,
		formants = [Vector3(570, 80, 1.0), Vector3(840, 90, 0.6), Vector3(2410, 120, 0.25)],
	},
]

## The player's hurt grunts: lower, shorter and tighter than the enemies'.
const PLAYER_GRUNTS: Array[Dictionary] = [
	{  # "hn"
		f0 = [118.0, 128.0, 95.0], peak = 0.15, dur = 0.16, attack = 0.008, onset = 0.0,
		breath = 0.1, fry = 0.2, close = 0.0,
		formants = [Vector3(280, 60, 1.0), Vector3(1350, 120, 0.35), Vector3(2500, 150, 0.2)],
	},
	{  # "uh"
		f0 = [112.0, 124.0, 88.0], peak = 0.18, dur = 0.18, attack = 0.01, onset = 0.02,
		breath = 0.12, fry = 0.3, close = 0.2,
		formants = [Vector3(600, 80, 1.0), Vector3(1150, 90, 0.5), Vector3(2400, 120, 0.25)],
	},
	{  # "oof"
		f0 = [108.0, 118.0, 84.0], peak = 0.12, dur = 0.2, attack = 0.008, onset = 0.0,
		breath = 0.18, fry = 0.25, close = 0.0,
		formants = [Vector3(330, 60, 1.0), Vector3(900, 90, 0.4), Vector3(2250, 120, 0.2)],
	},
]

## Enemy efforts at the start of a wind-up (the rear-warning audio cue, Spec §8): a breath,
## then a rising "hah".
const EFFORTS: Array[Dictionary] = [
	{  # "hah"
		f0 = [125.0, 165.0, 140.0], peak = 0.5, dur = 0.32, attack = 0.02, onset = 0.05,
		breath = 0.18, fry = 0.0, close = 0.0,
		formants = [Vector3(750, 90, 1.0), Vector3(1250, 100, 0.6), Vector3(2600, 130, 0.3)],
	},
	{  # "hup"
		f0 = [130.0, 170.0, 150.0], peak = 0.45, dur = 0.24, attack = 0.015, onset = 0.04,
		breath = 0.16, fry = 0.0, close = 0.5,
		formants = [Vector3(520, 80, 1.0), Vector3(1150, 100, 0.5), Vector3(2400, 120, 0.25)],
	},
	{  # "hyah"
		f0 = [140.0, 186.0, 150.0], peak = 0.4, dur = 0.3, attack = 0.015, onset = 0.03,
		breath = 0.15, fry = 0.0, close = 0.0,
		formants = [Vector3(700, 90, 1.0), Vector3(1650, 110, 0.55), Vector3(2600, 130, 0.3)],
	},
]

var rng := RandomNumberGenerator.new()
var written := 0
var failed := false


## Topology-preserving state-variable filter (Zavalishin): low, band and high outputs.
## `band` is normalized to unity gain at the cutoff.
class Svf:
	var low: float = 0.0
	var band: float = 0.0
	var high: float = 0.0
	var _ic1: float = 0.0
	var _ic2: float = 0.0

	func run(x: float, cutoff: float, q: float) -> void:
		var g := tan(PI * clampf(cutoff, 20.0, 19000.0) / 44100.0)
		var k := 1.0 / q
		var a1 := 1.0 / (1.0 + g * (g + k))
		var a2 := g * a1
		var a3 := g * a2
		var v3 := x - _ic2
		var v1 := a1 * _ic1 + a2 * v3
		var v2 := _ic2 + a2 * _ic1 + a3 * v3
		_ic1 = 2.0 * v1 - _ic1
		_ic2 = 2.0 * v2 - _ic2
		low = v2
		band = v1 * k
		high = x - k * v1 - v2

	func out(kind: int) -> float:
		match kind:
			F.LOW:
				return low
			F.HIGH:
				return high
		return band


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for v in 4:
		_save("whoosh", v, _whoosh)
	for v in 4:
		_save("thud", v, _thud)
	for v in 3:
		_save("crack", v, _crack)
	for v in 3:
		_save("crunch", v, _crunch)
	for v in 3:
		_save("body_fall", v, _body_fall)
	for v in 2:
		_save("sub_thump", v, _sub_thump)
	for v in ENEMY_GRUNTS.size():
		_save("grunt", v, _voice.bind(ENEMY_GRUNTS[v]))
	for v in PLAYER_GRUNTS.size():
		_save("player_grunt", v, _voice.bind(PLAYER_GRUNTS[v]))
	for v in EFFORTS.size():
		_save("effort", v, _voice.bind(EFFORTS[v]))
	for v in 3:
		_save("block_clack", v, _block_clack)
	for v in 3:
		_save("parry_ting", v, _parry_ting)
	for v in 2:
		_save("guard_break", v, _guard_break)
	_save("music_loop", 0, _music_loop, true)
	if failed:
		print("gen_sfx: FAILED")
		quit(1)
		return
	print("gen_sfx: wrote %d sounds to %s" % [written, OUT_DIR])
	quit(0)


# --- Sounds ----------------------------------------------------------------------------


## Air past the ear as the limb goes by: band-passed noise, loudest a couple of hundredths
## of a second in, its center sweeping down (a pass-by), over a darker low-passed body.
## Front-loaded because it plays when the swing has arrived: layered on a hit at the contact
## frame it rides the impact, and a whiff (attack_whiffed, as the active frames end) hears
## the limb pass at once. A slow swell peaked 0.1-0.24 s late, after the thud (M2 review).
func _whoosh(v: int) -> PackedFloat32Array:
	# Variants step through the fall time (short and sharp to long and airy), then jitter.
	var rise := rng.randf_range(0.01, 0.016)
	var fall := lerpf(0.04, 0.085, v / 3.0) * rng.randf_range(0.9, 1.1)
	var b := _new(rise + fall * 6.0)
	var f_hi := lerpf(2900.0, 1900.0, v / 3.0) * rng.randf_range(0.9, 1.1)
	var f_lo := rng.randf_range(320.0, 520.0)
	var q := rng.randf_range(1.2, 2.0)
	var bp := Svf.new()
	var lp := Svf.new()
	for i in b.size():
		var t := float(i) / RATE
		var shape := _env(t, rise, fall)
		var fc := f_lo + (f_hi - f_lo) * exp(-t / (fall * 1.5))
		var x := rng.randf_range(-1.0, 1.0)
		bp.run(x, fc, q)
		lp.run(x, fc * 0.45, 0.7)
		b[i] = (bp.band * 0.9 + lp.low * 0.5) * shape
	return b


## A body blow: a tone dropping to the low end, a low-passed slap and a contact click.
func _thud(_v: int) -> PackedFloat32Array:
	var b := _new(0.35)
	_tone_drop(b, 0.0, rng.randf_range(150.0, 190.0), rng.randf_range(52.0, 66.0), rng.randf_range(0.025, 0.04), 0.001, rng.randf_range(0.07, 0.1), 1.0)
	_noise_hit(b, 0.0, F.LOW, rng.randf_range(700.0, 1300.0), 0.7, 0.0005, rng.randf_range(0.015, 0.03), 0.9)
	_noise_hit(b, 0.0, F.HIGH, 3000.0, 0.7, 0.0002, 0.002, 0.25)
	_saturate(b, 1.8)
	return b


## Bone: a sharp high transient, a few fast-decaying modes, a splinter just after, and a
## short knock under it. Variants step through the modes' pitch and ring, so they tell apart.
func _crack(v: int) -> PackedFloat32Array:
	var b := _new(0.25)
	_noise_hit(b, 0.0, F.HIGH, rng.randf_range(1800.0, 2600.0), 0.7, 0.0002, rng.randf_range(0.004, 0.008), 1.0)
	var f := lerpf(1400.0, 2400.0, v / 2.0) * rng.randf_range(0.96, 1.04)
	var ring := lerpf(1.3, 0.75, v / 2.0)
	_modes(b, 0.0, [f, f * 1.47, f * 2.09], [0.03 * ring, 0.02 * ring, 0.012 * ring], [0.5, 0.35, 0.25], 1.0)
	var t2 := rng.randf_range(0.008, 0.02)
	_noise_hit(b, t2, F.HIGH, 2500.0, 0.7, 0.0002, 0.004, 0.6)
	_noise_hit(b, t2 * 2.1, F.BAND, 1800.0, 1.5, 0.0003, 0.006, 0.35)
	_tone_drop(b, 0.0, 260.0, 180.0, 0.02, 0.0005, 0.03, 0.5)
	_saturate(b, 1.5)
	return b


## Something giving way: a burst of tiny band-passed grains, densest at the start, over a
## low squish and thump.
func _crunch(_v: int) -> PackedFloat32Array:
	var b := _new(0.35)
	_noise_hit(b, 0.0, F.LOW, rng.randf_range(400.0, 600.0), 0.7, 0.002, 0.06, 0.8)
	_tone_drop(b, 0.0, 120.0, 70.0, 0.03, 0.001, 0.05, 0.6)
	_grains(b, 0.0, rng.randf_range(0.12, 0.2), rng.randi_range(18, 28), 700.0, 4500.0, 0.9)
	_saturate(b, 1.4)
	return b


## A body hitting the ground: a heavy low flump, a smaller limb slap just after, and cloth.
func _body_fall(_v: int) -> PackedFloat32Array:
	var b := _new(0.7)
	_noise_hit(b, 0.0, F.LOW, rng.randf_range(250.0, 380.0), 0.7, 0.003, rng.randf_range(0.09, 0.14), 1.0)
	_tone_drop(b, 0.0, 95.0, rng.randf_range(48.0, 58.0), 0.04, 0.002, 0.12, 0.35)
	var t2 := rng.randf_range(0.07, 0.13)
	_noise_hit(b, t2, F.LOW, 650.0, 0.7, 0.002, 0.05, 0.45)
	_tone_drop(b, t2, 140.0, 80.0, 0.02, 0.001, 0.04, 0.3)
	_noise_hit(b, 0.0, F.BAND, rng.randf_range(1500.0, 2500.0), 0.8, 0.01, 0.12, 0.12)
	_saturate(b, 1.3)
	return b


## The finisher's weight: a sub-bass drop, a little saturated so it reads on small speakers.
func _sub_thump(_v: int) -> PackedFloat32Array:
	var b := _new(0.75)
	_tone_drop(b, 0.0, rng.randf_range(95.0, 115.0), rng.randf_range(36.0, 44.0), 0.05, 0.002, rng.randf_range(0.16, 0.22), 1.0)
	_saturate(b, 1.4)
	return b


## A forearm or glove stopping a strike: a bright tick and woody modes over a leather knock.
## Variants step through the wood's pitch.
func _block_clack(v: int) -> PackedFloat32Array:
	var b := _new(0.25)
	_clack(b, 0.0, 1.0, lerpf(600.0, 950.0, v / 2.0))
	_saturate(b, 1.3)
	return b


## The parry: a bright metallic ting (inharmonic partials, the first beating against a
## detuned copy) over a softer clack.
func _parry_ting(_v: int) -> PackedFloat32Array:
	var b := _new(1.0)
	var f := rng.randf_range(1700.0, 2300.0)
	var ring := rng.randf_range(0.8, 1.2)
	_modes(
		b, 0.0,
		[f, f * 2.76, f * 5.4, f * 8.93, f + 3.0],
		[0.45 * ring, 0.25 * ring, 0.12 * ring, 0.06 * ring, 0.4 * ring],
		[1.0, 0.55, 0.3, 0.15, 0.4],
		0.8
	)
	_noise_hit(b, 0.0, F.HIGH, 4000.0, 0.7, 0.0002, 0.003, 0.6)
	_modes(b, 0.0, [rng.randf_range(800.0, 1000.0)], [0.03], [0.5], 1.0)
	return b


## The guard knocked apart: a clack, a wide noise crash closing down, a low boom and a
## shatter of grains. Variants differ in the clack's wood, the crash's length and the boom.
func _guard_break(v: int) -> PackedFloat32Array:
	var b := _new(1.1)
	_clack(b, 0.0, 0.8, lerpf(640.0, 900.0, float(v)))
	var lp := Svf.new()
	var hp := Svf.new()
	var decay := lerpf(0.17, 0.27, float(v)) * rng.randf_range(0.95, 1.05)
	for i in b.size():
		var t := float(i) / RATE
		lp.run(rng.randf_range(-1.0, 1.0), 1500.0 + 5500.0 * exp(-t / 0.15), 0.7)
		hp.run(lp.low, 200.0, 0.7)
		b[i] += hp.high * _env(t, 0.002, decay) * 0.9
	_tone_drop(b, 0.0, lerpf(82.0, 66.0, float(v)), lerpf(44.0, 36.0, float(v)), 0.08, 0.002, 0.25, 0.8)
	_grains(b, 0.05, 0.45, 30, 2500.0, 6000.0, 0.5)
	_saturate(b, 1.5)
	return b


## A formant voice (grunts and efforts): a jittered glottal saw, tilted, through three
## parallel formant band-passes, with breath noise; vocal fry and a closing mouth at the end.
func _voice(_v: int, p: Dictionary) -> PackedFloat32Array:
	var d: float = p.dur
	var onset: float = p.onset
	var total := onset + d
	var b := _new(total)
	var f0: Array = p.f0
	var peak: float = p.peak
	var attack: float = p.attack
	var fry: float = p.fry
	var close: float = p.close
	var breath: float = p.breath
	var forms: Array = p.formants
	var filters: Array[Svf] = []
	for _f in forms:
		filters.append(Svf.new())
	var tilt := Svf.new()
	var asp := Svf.new()
	var phase := 0.0
	var jitter := 0.0
	var shimmer := 1.0
	for i in b.size():
		var t := float(i) / RATE
		var tv := t - onset
		var u := clampf(tv / d, 0.0, 1.0)
		var hz: float
		if u < peak:
			hz = lerpf(f0[0], f0[1], smoothstep(0.0, peak, u))
		else:
			hz = lerpf(f0[1], f0[2], smoothstep(peak, 1.0, u))
		var fry_k := smoothstep(1.0 - fry, 1.0, u) if fry > 0.0 else 0.0
		hz = lerpf(hz, hz * 0.55, fry_k)
		phase += hz * (1.0 + jitter) / RATE
		if phase >= 1.0:
			phase -= 1.0
			jitter = rng.randf_range(-0.02, 0.02) * (1.0 + 4.0 * fry_k)
			shimmer = 1.0 + rng.randf_range(-0.1, 0.1) * (1.0 + 2.0 * fry_k)
		tilt.run((1.0 - 2.0 * phase) * shimmer, 2200.0, 0.7)
		var mouth := 1.0 - close * smoothstep(0.6, 1.0, u)
		var voiced := 0.0
		for k in forms.size():
			var fm: Vector3 = forms[k]
			var fc := fm.x * (mouth if k == 0 else 1.0)
			filters[k].run(tilt.low, fc, fc / fm.y)
			voiced += filters[k].band * fm.z
		asp.run(rng.randf_range(-1.0, 1.0), 1800.0, 0.8)
		var voice_env := 0.0
		if tv > 0.0:
			voice_env = smoothstep(0.0, attack, tv) * (1.0 - smoothstep(0.55, 1.0, u))
		# Breath: a rising "h" before the voice, then a little under it.
		var breath_env := breath * (1.0 - smoothstep(0.7, 1.0, u))
		if onset > 0.0 and tv < 0.0:
			breath_env = breath * 2.5 * smoothstep(0.0, onset, t)
		b[i] = (voiced * voice_env + asp.band * breath_env) * smoothstep(0.0, VOICE_FADE_IN_S, t)
	return b


## A placeholder fight loop: 4 bars at 112 BPM (kick, snare, hats, a saw bass riff and a
## minor stab), written around the end so it loops without a seam.
func _music_loop(_v: int) -> PackedFloat32Array:
	var step_s := 60.0 / 112.0 / 4.0
	var steps := 64
	var b := PackedFloat32Array()
	b.resize(int(round(step_s * steps * RATE)))
	var kick := _new(0.4)
	_tone_drop(kick, 0.0, 130.0, 46.0, 0.03, 0.001, 0.22, 1.0)
	_noise_hit(kick, 0.0, F.LOW, 2000.0, 0.7, 0.0002, 0.004, 0.4)
	var snare := _new(0.35)
	_noise_hit(snare, 0.0, F.BAND, 1800.0, 0.7, 0.0005, 0.11, 0.8)
	_tone_drop(snare, 0.0, 220.0, 185.0, 0.02, 0.0005, 0.06, 0.5)
	var hat := _new(0.12)
	_noise_hit(hat, 0.0, F.HIGH, 7000.0, 0.7, 0.0002, 0.022, 1.0)
	var open_hat := _new(0.4)
	_noise_hit(open_hat, 0.0, F.HIGH, 6500.0, 0.7, 0.0005, 0.11, 1.0)
	var bass_riff := [0, -1, 0, 12, -1, 0, 10, -1, 0, -1, 7, -1, 5, -1, 3, -1]
	var bar_roots := [0, 0, 5, 3]
	for s in steps:
		var bar := int(s / 16.0)
		var k := s % 16
		var at := int(round(s * step_s * RATE))
		if k in [0, 6, 8] or (bar == 3 and k == 14):
			_add_wrapped(b, at, kick, 1.0)
		if k in [4, 12] or (bar == 3 and k == 15):
			_add_wrapped(b, at, snare, 0.7 if k != 15 else 0.45)
		if k % 2 == 0:
			_add_wrapped(b, at, open_hat if (k == 14 and bar < 3) else hat, 0.18 if k == 14 else 0.22)
		var note: int = bass_riff[k]
		if note >= 0:
			var hz := 82.41 * pow(2.0, (note + int(bar_roots[bar])) / 12.0)
			_add_wrapped(b, at, _saw_note([hz], step_s * 0.9, 300.0, 1500.0, 2.0), 0.5)
		if k == 0 and bar % 2 == 0:
			var root := 164.81 * pow(2.0, int(bar_roots[bar]) / 12.0)
			_add_wrapped(b, at, _saw_note([root, root * 1.189, root * 1.498], step_s * 3.0, 900.0, 1800.0, 1.0), 0.25)
	return b


# --- Building blocks ---------------------------------------------------------------------


func _new(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Attack and decay time constants (s): rises as 1 - exp(-t/attack), falls as exp(-t/decay).
func _env(t: float, attack: float, decay: float) -> float:
	return (1.0 - exp(-t / attack)) * exp(-t / decay)


## Adds a sine whose pitch drops from `f_from` to `f_to` (time constant `drop`).
func _tone_drop(b: PackedFloat32Array, start: float, f_from: float, f_to: float, drop: float, attack: float, decay: float, gain: float) -> void:
	var i0 := int(start * RATE)
	var phase := 0.0
	for i in range(i0, b.size()):
		var t := float(i - i0) / RATE
		var hz := f_to + (f_from - f_to) * exp(-t / drop)
		phase += TAU * hz / RATE
		b[i] += sin(phase) * _env(t, attack, decay) * gain


## Adds a filtered noise burst.
func _noise_hit(b: PackedFloat32Array, start: float, kind: int, cutoff: float, q: float, attack: float, decay: float, gain: float) -> void:
	var i0 := int(start * RATE)
	var i1 := mini(b.size(), i0 + int((attack * 4.0 + decay * 7.0) * RATE))
	var f := Svf.new()
	for i in range(i0, i1):
		var t := float(i - i0) / RATE
		f.run(rng.randf_range(-1.0, 1.0), cutoff, q)
		b[i] += f.out(kind) * _env(t, attack, decay) * gain


## Adds decaying sine modes (struck objects), skipping any above 18 kHz.
func _modes(b: PackedFloat32Array, start: float, freqs: Array, decays: Array, amps: Array, gain: float) -> void:
	var i0 := int(start * RATE)
	for m in freqs.size():
		var hz: float = freqs[m]
		if hz > 18000.0:
			continue
		var decay: float = decays[m]
		var amp: float = amps[m]
		var i1 := mini(b.size(), i0 + int(decay * 7.0 * RATE))
		for i in range(i0, i1):
			var t := float(i - i0) / RATE
			b[i] += sin(TAU * hz * t) * _env(t, 0.0003, decay) * amp * gain


## Adds `count` tiny band-passed noise grains over `window` s, denser and louder early.
func _grains(b: PackedFloat32Array, start: float, window: float, count: int, f_lo: float, f_hi: float, gain: float) -> void:
	for g in count:
		var at := window * pow(rng.randf(), 1.6)
		var amp := rng.randf_range(0.3, 1.0) * (1.0 - 0.6 * at / window)
		_noise_hit(b, start + at, F.BAND, rng.randf_range(f_lo, f_hi), rng.randf_range(2.0, 4.0), 0.0002, rng.randf_range(0.001, 0.004), amp * gain)


## The block clack (also under the guard break): a bright tick, woody modes around `wood` Hz,
## a leather knock.
func _clack(b: PackedFloat32Array, start: float, gain: float, wood: float) -> void:
	_noise_hit(b, start, F.BAND, rng.randf_range(2600.0, 3400.0), 1.0, 0.0002, 0.004, 0.8 * gain)
	var f := wood * rng.randf_range(0.96, 1.04)
	_modes(b, start, [f, f * 2.31, f * 3.87], [0.05, 0.03, 0.018], [1.0, 0.6, 0.35], 0.8 * gain)
	_tone_drop(b, start, 150.0, 120.0, 0.02, 0.0005, 0.04, 0.5 * gain)


## A low-passed saw chord (one or more notes) with a filter sweep, `length` s long.
func _saw_note(freqs: Array, length: float, f_floor: float, f_sweep: float, q: float) -> PackedFloat32Array:
	var b := _new(length + 0.03)
	var f := Svf.new()
	var phases: Array[float] = []
	for _n in freqs:
		phases.append(rng.randf())
	for i in b.size():
		var t := float(i) / RATE
		var x := 0.0
		for n in freqs.size():
			phases[n] = fmod(phases[n] + float(freqs[n]) / RATE, 1.0)
			x += 1.0 - 2.0 * phases[n]
		f.run(x / freqs.size(), f_floor + f_sweep * exp(-t / 0.05), q)
		var gate := smoothstep(0.0, 0.003, t) * (1.0 - smoothstep(length, length + 0.025, t))
		b[i] = f.low * gate * exp(-t / (length * 1.5))
	return b


## Adds `src` into the loop `b` at sample `at`, wrapping around its end.
func _add_wrapped(b: PackedFloat32Array, at: int, src: PackedFloat32Array, gain: float) -> void:
	for i in src.size():
		var j := (at + i) % b.size()
		b[j] += src[i] * gain


## Normalizes to 1, then soft-clips with tanh (drive > 1 thickens the transient).
func _saturate(b: PackedFloat32Array, drive: float) -> void:
	_normalize(b, 1.0)
	var norm := tanh(drive)
	for i in b.size():
		b[i] = tanh(b[i] * drive) / norm


func _normalize(b: PackedFloat32Array, peak: float) -> void:
	var top := 0.0
	for x in b:
		top = maxf(top, absf(x))
	if top <= 0.0:
		return
	var k := peak / top
	for i in b.size():
		b[i] *= k


# --- Output ------------------------------------------------------------------------------


## Builds `<pool>_<nn>.wav` (variant `v`, 1-based in the name) from `make.call(v)` with
## its own seed, normalizes it to PEAK and saves it. `loop` writes a forward loop over the
## whole file and no fade.
func _save(pool: String, v: int, make: Callable, loop: bool = false) -> void:
	var file := "%s_%02d.wav" % [pool, v + 1]
	rng.seed = hash(file)
	var b: PackedFloat32Array = make.call(v)
	_normalize(b, PEAK)
	if not loop:
		var fade := int(FADE_OUT_S * RATE)
		for i in fade:
			b[b.size() - 1 - i] *= float(i) / fade
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(round(clampf(b[i], -1.0, 1.0) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = b.size()
	var err := wav.save_to_wav(OUT_DIR + file)
	if err != OK:
		push_error("gen_sfx: could not save %s (%s)" % [file, error_string(err)])
		failed = true
		return
	written += 1
