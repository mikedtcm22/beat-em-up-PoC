"""Plan B trailer sound effects, built from the game's own sounds.

Reads each shot's event log (captures/video/planb/renders/<key>/<key>_events.log) and replays the rules of
game/audio/audio_director.gd in Python with the wavs of assets/export/sfx/:
  - hit_landed: the tier's layers (light whoosh+thud, heavy +crack, finisher whoosh+thud+crunch+body_fall+sub_thump),
    each at its layer dB + the tier's dB; no whoosh for a body hit (move impact_body_*); the whoosh and sub thump play once
    per swing (same attacker, same 60 Hz tick) and every further victim is extra_victim_db quieter; a weapon move adds
    weapon_<impact_sfx>_hit (read from its move .tres); a clean hit makes the victim grunt (player_grunt, or grunt_<archetype>),
    at most once per grunt_min_interval_ms per actor; a KO plays ko_<archetype> and cuts that grunt
  - blocked: whoosh + block_clack, or parry_ting on a perfect block; no grunt
  - attack_whiffed: whoosh at whiff_db
  - windup_started: effort_<archetype> + whoosh at windup_db, cut short when the winder is hit within its move's startup
  - weapon_picked_up / weapon_landed: weapon_pickup / weapon_land
  - ambience: ambience_street (t01-t06) or ambience_roof (t07-t14) under the whole shot, at ambience_db
Every dB value (and the +-8% pitch and volume variation, the voice pitch spread and each archetype's voice_pitch_mult) is read from
game/autoload/tuning_data.gd and the enemy scenes, never copied here. The SFX bus pre-gain (sfx_volume_db) is applied to every sound.
Left out because the log has no position: distance fall-off, the rear muffle, panning (everything is centred, at full level).
Variation is deterministic: each cue's random numbers are seeded by shot key, event index and pool.

Output per shot, in captures/video/planb/audio/: <key>.wav (48 kHz stereo 24-bit, exactly the shot's frames/24 seconds, each sound at
frame/24 s, peak at most -1 dBFS: the whole shot is scaled down if it would exceed that) and <key>_cues.json
(a list of {time_s, event, file, gain_db}; gain_db is the total applied, pre-gain, variation and any shot scale-down included).

Usage: python -I tools/video/planb_sound.py [shot ...]   (shot keys such as t03_punk_combo; all 14 by default)
"""
import hashlib
import json
import math
import random
import re
import subprocess
import sys
import wave
from fractions import Fraction
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[2]
SFX = ROOT / "assets/export/sfx"
RENDERS = ROOT / "captures/video/planb/renders"
INPUTS = ROOT / "captures/video/planb/inputs"
OUT = ROOT / "captures/video/planb/audio"
RATE = 48000
FPS = 24
TICKS = 60.0
PEAK_LIMIT_DB = -1.0
FADE_S = 0.008  # the click guard on a sound cut short (an interrupted wind-up, or a tail past the shot's end)

SHOTS = ["t01_crane_street", "t02_guard_up", "t03_punk_combo", "t04_block_spin", "t05_grab_throw", "t06_pipe_chain", "t07_roof_knockoff",
	"t08_chain_whip", "t09_back_elbow", "t10_ox_reveal", "t11_ox_fight", "t12_haymaker", "t13_ox_falls", "t14_title_embers"]
# Locations (the task): a street at night, then rooftops. The bank has no fire sound, so the boss's roof gets the roof bed.
BED = {s: "ambience_street" for s in SHOTS[:6]}
BED.update({s: "ambience_roof" for s in SHOTS[6:]})

TIER_LAYERS = {  # AudioDirector.TIER_LAYERS, tier 0/1/2 = light/heavy/finisher
	0: ["whoosh", "thud"],
	1: ["whoosh", "thud", "crack"],
	2: ["whoosh", "thud", "crunch", "body_fall", "sub_thump"],
}
SWING_LAYERS = ("whoosh", "sub_thump")


def read_tuning():
	"""Every `name: float = value` of tuning_data.gd, as a dict."""
	text = (ROOT / "game/autoload/tuning_data.gd").read_text()
	return {m.group(1): float(m.group(2)) for m in re.finditer(r"var (\w+): float = (-?[\d.]+)", text)}


TUNE = read_tuning()


def voice_pitch_mult(archetype):
	"""The archetype's voice_pitch_mult from its scene (1.0 when it sets none)."""
	scene = ROOT / f"game/enemies/{archetype}/{archetype}.tscn"
	if scene.exists():
		m = re.search(r"voice_pitch_mult = ([\d.]+)", scene.read_text())
		if m:
			return float(m.group(1))
	return 1.0


def move_field(move, field, default=""):
	"""A field of game/combat/moves/<move>.tres (impact_sfx = &"pipe", startup = 22), or the default."""
	path = ROOT / f"game/combat/moves/{move}.tres"
	if path.exists():
		m = re.search(rf"^{field} = (?:&?\"([^\"]*)\"|(-?[\d.]+))", path.read_text(), re.M)
		if m:
			return m.group(1) if m.group(1) is not None else m.group(2)
	return default


def archetype_of(actor):
	"""The enemy archetype from its node name ("Punk1" and "Punk Veteran1" are punks, "Boss1" the boss); None for the player."""
	if actor == "Player":
		return None
	return re.sub(r"\d+$", "", actor).split()[0].lower()


def voice_pitch(actor):
	"""AudioDirector.voice_pitch: 1 +- voice_pitch_spread from a fixed share of the actor's name, times its voice_pitch_mult."""
	spread = TUNE["voice_pitch_spread"]
	share = random.Random(actor).uniform(-spread, spread)
	return (1.0 + share) * voice_pitch_mult(archetype_of(actor) or "")


_cache = {}


def load_wav(name):
	"""A bank file as float mono at 44.1 kHz-or-whatever it has: (samples, rate)."""
	if name not in _cache:
		rate, x = wavfile.read(SFX / f"{name}.wav")
		x = x.astype(np.float64) / (32768.0 if x.dtype == np.int16 else float(np.iinfo(x.dtype).max) + 1.0)
		if x.ndim > 1:
			x = x.mean(axis=1)
		_cache[name] = (x, rate)
	return _cache[name]


def to_48k(x, rate, pitch=1.0):
	"""Resample to 48 kHz, played at `pitch` times its speed (the pitch_scale of a Godot player), with scipy.signal.resample_poly."""
	ratio = Fraction(RATE / (rate * pitch)).limit_denominator(2000)
	if ratio == 1:
		return x
	return resample_poly(x, ratio.numerator, ratio.denominator)


def pool_files(pool):
	return sorted(p.stem for p in SFX.glob(f"{pool}_[0-9][0-9].wav"))


class Shot:
	"""One shot's mix: collects cues (a sound at a time, a gain), then renders them."""

	def __init__(self, key, frames):
		self.key = key
		self.n = int(round(frames / FPS * RATE))
		self.cues = []  # dicts: time_s, event, file, gain_db, samples (float mono at 48k), start (sample index)
		self.last = {}  # pool -> the file picked last (never the same variant twice running)
		self.serial = 0

	def pick(self, pool, rng):
		files = pool_files(pool)
		if not files:
			return None
		if len(files) > 1 and self.last.get(pool) in files:
			files = [f for f in files if f != self.last[pool]]
		choice = rng.choice(files)
		self.last[pool] = choice
		return choice

	def play(self, pool, time_s, event, db, pitch=1.0, idx=0, until_s=None):
		"""AudioDirector.play(): a variant of `pool` at db (+ the SFX pre-gain), varied by +-sfx_volume_variation as amplitude and
		+-sfx_pitch_variation in pitch. until_s cuts the sound short there (an interrupted wind-up)."""
		self.serial += 1
		seed = hashlib.md5(f"{self.key}:{idx}:{pool}:{self.serial}".encode()).hexdigest()
		rng = random.Random(seed)
		name = self.pick(pool, rng)
		if name is None:
			return None
		pitch *= 1.0 + rng.uniform(-TUNE["sfx_pitch_variation"], TUNE["sfx_pitch_variation"])
		vol = 1.0 + rng.uniform(-TUNE["sfx_volume_variation"], TUNE["sfx_volume_variation"])
		gain_db = db + 20.0 * math.log10(vol) + TUNE["sfx_volume_db"]
		x, rate = load_wav(name)
		x = to_48k(x, rate, pitch) * 10.0 ** (gain_db / 20.0)
		start = int(round(time_s * RATE))
		if until_s is not None:
			x = x[: max(0, int(round((until_s - time_s) * RATE)))]
		self.cues.append({"time_s": round(time_s, 4), "event": event, "file": name + ".wav", "gain_db": gain_db, "samples": x, "start": start})
		return name

	def render(self):
		"""Sum the cues (and fade the ones cut short) into a stereo bed of exactly the shot's length; scale down to -1 dBFS if needed."""
		mix = np.zeros(self.n)
		fade = int(FADE_S * RATE)
		for cue in self.cues:
			x = cue["samples"].copy()
			s = cue["start"]
			if s >= self.n or len(x) == 0:
				continue
			cut = len(x) > self.n - s or cue.get("cut")
			x = x[: self.n - s]
			if cut and len(x) > 0:
				f = min(fade, len(x))
				x[-f:] *= np.linspace(1.0, 0.0, f)
			mix[s: s + len(x)] += x
		peak = np.abs(mix).max()
		scale = 1.0
		if peak > 10.0 ** (PEAK_LIMIT_DB / 20.0):
			scale = 10.0 ** (PEAK_LIMIT_DB / 20.0) / peak
			mix *= scale
			for cue in self.cues:
				cue["gain_db"] += 20.0 * math.log10(scale)
		return mix, scale


def parse_events(path):
	"""The game events of a log, in order: dicts with f, t, name, args (the list after the name). The scripted bot's "beat #" lines are skipped."""
	events = []
	for line in path.read_text().splitlines():
		m = re.match(r"EVENT f(\d+) t(\d+) (\S+)\s*(.*)", line)
		if not m or m.group(3) == "beat":
			continue
		events.append({"f": int(m.group(1)), "t": int(m.group(2)), "name": m.group(3), "rest": m.group(4)})
	return events


def parse_hit(rest):
	"""'Player>Punk1 jab_1 dmg=6 tier=0 blocked perfect' -> attacker, victim, move, tier, blocked, perfect."""
	words = rest.split()
	attacker, victim = words[0].split(">", 1)
	flags = set(words[3:])
	tier = next((int(w[5:]) for w in words if w.startswith("tier=")), 0)
	return {"attacker": attacker, "victim": victim, "move": words[1], "tier": tier,
		"blocked": "blocked" in flags, "perfect": "perfect" in flags, "killed": "killed" in flags, "armor": "ARMOR" in flags}


def frame_count(key):
	"""The 1080p input's frame count (ffprobe), which fixes the shot's length."""
	out = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=nb_read_frames",
		"-of", "csv=p=0", str(INPUTS / f"{key}_1080.mp4")], capture_output=True, text=True, check=True).stdout.strip()
	return int(out)


def tier_db(tier):
	return TUNE[{1: "hit_heavy_db", 2: "hit_finisher_db"}.get(tier, "hit_light_db")]


def build(key):
	frames = frame_count(key)
	shot = Shot(key, frames)
	events = parse_events(RENDERS / key / f"{key}_events.log")
	T = lambda ev: ev["f"] / FPS
	left = set()  # event names with no sound, for the report

	# The wind-ups cut short: a clean hit (not blocked) on the winder within its move's startup, from its wind-up tick.
	hits = [(i, e, parse_hit(e["rest"])) for i, e in enumerate(events) if e["name"] == "hit_landed"]

	def interrupted_at(actor, move, t0):
		startup = float(move_field(move, "startup", "0"))
		for _, e, h in hits:
			if h["victim"] == actor and not h["blocked"] and t0 <= e["t"] < t0 + startup:
				return e["f"] / FPS
		return None

	swing = None  # (attacker, tick) of the last hit, and the victims it has struck
	swing_victims = []
	last_grunt = {}  # actor -> tick of its last grunt
	grunt_cue = {}  # actor -> its last grunt's cue (a KO line cuts it)
	for i, ev in enumerate(events):
		name, t = ev["name"], T(ev)
		if name == "hit_landed":
			h = parse_hit(ev["rest"])
			first = True
			key_swing = (h["attacker"], ev["t"])
			if key_swing != swing or h["victim"] in swing_victims:
				swing, swing_victims = key_swing, [h["victim"]]
			else:
				swing_victims.append(h["victim"])
				first = False
			gain = tier_db(h["tier"]) + (0.0 if first else TUNE["extra_victim_db"])
			swung = first and not h["move"].startswith("impact_body")
			if h["blocked"]:
				if swung:
					shot.play("whoosh", t, name, TUNE["whoosh_db"] + gain, idx=i)
				if h["perfect"]:
					shot.play("parry_ting", t, name, TUNE["parry_ting_db"] + gain, idx=i)
				else:
					shot.play("block_clack", t, name, TUNE["block_clack_db"] + gain, idx=i)
				continue  # a guard_broken hit would add guard_break; the log carries no such flag
			if h["armor"]:
				continue  # no hit in the 14 logs is armor-absorbed (the HitInfo text would end in ARMOR)
			for pool in TIER_LAYERS[h["tier"]]:
				if pool == "whoosh" and not swung:
					continue
				if pool in SWING_LAYERS and not first:
					continue
				shot.play(pool, t, name, TUNE[f"{pool}_db"] + gain, idx=i)
			impact = move_field(h["move"], "impact_sfx")
			if impact:
				shot.play(f"weapon_{impact}_hit", t, name, TUNE["weapon_hit_db"] + gain, idx=i)
			# The victim grunts (a KO line at the same tick replaces it, below).
			victim = h["victim"]
			if victim in last_grunt and ev["t"] - last_grunt[victim] < TUNE["grunt_min_interval_ms"] / 1000.0 * TICKS:
				continue
			killed_here = any(e["name"] == "ko" and e["t"] == ev["t"] and e["rest"].split()[0] == victim for e in events)
			if killed_here:
				continue
			last_grunt[victim] = ev["t"]
			arch = archetype_of(victim)
			if arch is None:
				shot.play("player_grunt", t, "grunt", TUNE["player_grunt_db"], voice_pitch(victim), idx=i)
			else:
				pool = f"grunt_{arch}" if pool_files(f"grunt_{arch}") else "grunt"
				shot.play(pool, t, "grunt", TUNE["grunt_db"], voice_pitch(victim), idx=i)
		elif name == "attack_whiffed":
			shot.play("whoosh", t, name, TUNE["whiff_db"], idx=i)
		elif name == "windup_started":
			actor, move = ev["rest"].split()[:2]
			arch = archetype_of(actor)
			until = interrupted_at(actor, move, ev["t"])
			pool = f"effort_{arch}" if pool_files(f"effort_{arch}") else "effort"
			shot.play(pool, t, name, TUNE["windup_db"], voice_pitch(actor), idx=i, until_s=until)
			shot.play("whoosh", t, name, TUNE["windup_db"], idx=i, until_s=until)
			if until is not None:
				for cue in shot.cues[-2:]:
					cue["cut"] = True
		elif name == "ko":
			victim = ev["rest"].split()[0]
			arch = archetype_of(victim)
			if arch and pool_files(f"ko_{arch}"):
				shot.play(f"ko_{arch}", t, name, TUNE["ko_db"], voice_pitch(victim), idx=i)
		elif name == "weapon_picked_up":
			shot.play("weapon_pickup", t, name, TUNE["weapon_pickup_db"], idx=i)
		elif name == "weapon_landed":
			shot.play("weapon_land", t, name, TUNE["weapon_land_db"], idx=i)
		else:
			left.add(name)

	# The bed: a seeded stretch of the 24 s loop, 48 kHz, at ambience_db plus the pre-gain.
	bed_name = BED[key] + "_01"
	x, rate = load_wav(bed_name)
	x = to_48k(x, rate)
	off = random.Random(key).randint(0, max(0, len(x) - shot.n))
	bed_db = TUNE["ambience_db"] + TUNE["sfx_volume_db"]
	x = x[off: off + shot.n] * 10.0 ** (bed_db / 20.0)
	x = np.pad(x, (0, shot.n - len(x)))
	f = int(0.010 * RATE)
	x[:f] *= np.linspace(0, 1, f)
	x[-f:] *= np.linspace(1, 0, f)
	shot.cues.insert(0, {"time_s": 0.0, "event": "ambience", "file": bed_name + ".wav", "gain_db": bed_db, "samples": x, "start": 0})
	return shot, left


def write_wav24(path, stereo):
	"""24-bit PCM stereo wav from a float array (n, 2)."""
	ints = np.clip(np.round(stereo * 8388607.0), -8388608, 8388607).astype(np.int32)
	raw = ints.astype("<i4").tobytes()
	b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 4)[:, :3]  # little-endian: the low three bytes
	with wave.open(str(path), "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(3)
		w.setframerate(RATE)
		w.writeframes(b.tobytes())


def main():
	keys = sys.argv[1:] or SHOTS
	OUT.mkdir(parents=True, exist_ok=True)
	unsounded = set()
	for key in keys:
		shot, left = build(key)
		mix, scale = shot.render()
		write_wav24(OUT / f"{key}.wav", np.stack([mix, mix], axis=1))
		cues = [{"time_s": c["time_s"], "event": c["event"], "file": c["file"], "gain_db": round(c["gain_db"], 2)} for c in shot.cues]
		(OUT / f"{key}_cues.json").write_text(json.dumps(cues, indent="\t") + "\n")
		peak_db = 20.0 * math.log10(max(np.abs(mix).max(), 1e-9))
		print(f"{key}: {len(cues)} cues ({len(cues) - 1} sounds + bed), {shot.n / RATE:.3f} s, peak {peak_db:.2f} dBFS" + (f" (scaled {20 * math.log10(scale):.1f} dB)" if scale < 1 else ""))
		unsounded |= left
	print("events with no sound:", ", ".join(sorted(unsounded)) or "none")


if __name__ == "__main__":
	main()
