"""Sound ingest and the audio manifest (Milestone 6, plan D18, D21, D24).

Usage (ffmpeg and the standard library only):
	python3 -I tools/audio/ingest.py --init                 the manifest, from the shipped wavs (once)
	python3 -I tools/audio/ingest.py --analyze <group>      measured features of a group's takes (to choose by)
	python3 -I tools/audio/ingest.py --picks <picks.json>   ingest the chosen takes as pools of wavs
	python3 -I tools/audio/ingest.py [--only <pool>]        rebuild every ElevenLabs row's wav from its MP3
	python3 -I tools/audio/ingest.py --check [--only <pool>]  rebuild in memory and compare; the gate
	python3 -I tools/audio/ingest.py --assets               write the ElevenLabs rows of ASSETS.md

The manifest, assets/source/sfx/manifest.json, is the ingest record:
	{"slots": {"<pool>": {"min_variants", "long", "loop", "space": "3d"|"2d"}},
	 "files": [{"file", "pool", "source": "elevenlabs:<ledger id>" | "gen_sfx", "licence", "trim_s": [start, end],
	            "fade_ms": [in, out], "peak_db" | "lufs", "gain_db", "loop_xfade_ms", "notes"}]}
`file` is a name in assets/export/sfx/ (`<pool>_<nn>.wav`, the pool being the stem up to the last underscore,
as game/audio/sfx_bank.gd reads it). A slot is a pool the game plays; one with fewer files than
`min_variants` is an empty slot (the placeholder inventory counts it). `long` exempts a pool from the
one-shot length cap, `loop` marks a bed. The game itself never reads the manifest.

A take is an MP3 from tools/audio/eleven_sfx.py, assets/source/sfx/eleven/<ledger id>.mp3. Ingest decodes it
with ffmpeg to 16-bit mono 44.1 kHz and does the rest in plain arithmetic, so a rebuild is exact:
	1. trim to `trim_s` (found from the take's own level the first time: its onset, 3 ms before, to its last
	   sound, 30 ms after, or at the pool's `max_s`);
	2. linear fades of `fade_ms` so both ends sit at zero (the tests want the ends within 0.004);
	3. `gain_db`, found the first time from the target `peak_db` (-1 dBFS, like gen_sfx) or `lufs`.
A loop is not trimmed or faded: `loop_xfade_ms` crossfades its tail into its head, so the file ends where
it begins. Every number found is written to the row, so `--check` redoes the same arithmetic and fails on
any difference in the PCM (`--tolerance N` allows N least-significant bits).

A picks file chooses the takes of each pool, in the order they become variants 01, 02, ...:
	{"slots": {"grunt_punk": {"min_variants": 3}},
	 "defaults": {"peak_db": -1.0, "fade_ms": [4, 8], "max_s": 1.4},
	 "pools": {"grunt_punk": {"takes": ["voices/grunt_punk_02", "voices/grunt_punk_01"], "max_s": 1.0, "notes": "..."}}}
A pool's own keys override `defaults`; `lufs` replaces `peak_db`. Ingesting a pool removes its old files
first (the placeholders of the pool included).
"""
import argparse
import array
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SFX_SRC = os.path.join(REPO, "assets", "source", "sfx")
MANIFEST = os.path.join(SFX_SRC, "manifest.json")
LEDGER = os.path.join(SFX_SRC, "eleven_ledger.jsonl")
ELEVEN = os.path.join(SFX_SRC, "eleven")
EXPORT = os.path.join(REPO, "assets", "export", "sfx")
LEGACY = os.path.join(REPO, "tests", "fixtures", "sfx_legacy")
ASSETS_MD = os.path.join(REPO, "ASSETS.md")
RATE = 44100
FULL = 32768.0
ELEVEN_LICENCE = "ElevenLabs Starter plan: commercial use, owned by the project"
GEN_LICENCE = "Project-owned (procedural, tools/gen_sfx.gd)"
ONSET_PRE_S = 0.003
TAIL_S = 0.030
SILENCE_REL_DB = -40.0
SILENCE_FLOOR_DB = -55.0
LONG_FADE_MS = 60.0
NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
TAKE_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
VOICE_POOLS = re.compile(r"^(grunt|effort|ko|player_grunt|boss_phase)(_[a-z]+)?$")

DEFAULTS = {"peak_db": -1.0, "fade_ms": [4.0, 8.0], "max_s": 1.4}

# The slots the game plays (the plan's "New pools"), for --init; every later change is made in the manifest.
SLOT_DEFAULTS = {
	"whoosh": [3, False, False, "3d"], "thud": [3, False, False, "3d"], "crack": [3, False, False, "3d"],
	"crunch": [3, False, False, "3d"], "body_fall": [2, False, False, "3d"], "sub_thump": [2, False, False, "3d"],
	"block_clack": [2, False, False, "3d"], "parry_ting": [2, False, False, "3d"], "guard_break": [2, False, False, "3d"],
	"music_loop": [1, True, True, "2d"],
}


class IngestError(Exception):
	pass


def say(text=""):
	print(text, flush=True)


# --------------------------------------------------------------------------- wav and ffmpeg

def decode_mp3(path):
	"""A take's PCM as array('h'): mono, 44.1 kHz, 16-bit, through ffmpeg (the path is an argument, never code)."""
	if not os.path.isfile(path):
		raise IngestError("missing source %s" % os.path.relpath(path, REPO))
	cmd = ["ffmpeg", "-v", "error", "-nostdin", "-i", path, "-map_metadata", "-1", "-ac", "1", "-ar", str(RATE),
		"-f", "s16le", "-acodec", "pcm_s16le", "-"]
	result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	if result.returncode != 0:
		raise IngestError("ffmpeg could not decode %s: %s" % (os.path.basename(path), result.stderr.decode("utf-8", "replace")[:200]))
	samples = array.array("h")
	samples.frombytes(result.stdout[:len(result.stdout) // 2 * 2])
	if sys.byteorder == "big":
		samples.byteswap()
	return samples


def read_wav(path):
	"""The PCM of a shipped wav; fails unless it is 16-bit mono 44.1 kHz."""
	with wave.open(path, "rb") as w:
		if (w.getnchannels(), w.getsampwidth(), w.getframerate()) != (1, 2, RATE):
			raise IngestError("%s is %d ch, %d-bit, %d Hz; the game wants mono 16-bit 44100"
				% (os.path.basename(path), w.getnchannels(), w.getsampwidth() * 8, w.getframerate()))
		frames = w.readframes(w.getnframes())
	samples = array.array("h")
	samples.frombytes(frames)
	if sys.byteorder == "big":
		samples.byteswap()
	return samples


def write_wav(path, samples):
	data = array.array("h", samples)
	if sys.byteorder == "big":
		data.byteswap()
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(data.tobytes())


def to_db(linear):
	return 20.0 * math.log10(linear) if linear > 0.0 else -200.0


def peak_of(samples):
	return max((abs(s) for s in samples), default=0) / FULL


def rms_of(samples):
	if len(samples) == 0:
		return 0.0
	return math.sqrt(sum(s * s for s in samples) / len(samples)) / FULL


def integrated_lufs(samples):
	"""ffmpeg's ebur128 integrated loudness of `samples` (meant for beds: it needs a second or more)."""
	data = array.array("h", samples)
	cmd = ["ffmpeg", "-nostdin", "-v", "info", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-",
		"-af", "ebur128=peak=true", "-f", "null", "-"]
	result = subprocess.run(cmd, input=data.tobytes(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	text = result.stderr.decode("utf-8", "replace")
	found = re.findall(r"I:\s+(-?[0-9.]+) LUFS", text)
	if not found:
		raise IngestError("ffmpeg's ebur128 gave no integrated loudness")
	return float(found[-1])


# --------------------------------------------------------------------------- the arithmetic

def find_trim(samples, max_s):
	"""[start_s, end_s]: the take's onset less 3 ms to its last sound plus 30 ms, ending at `max_s` at the latest."""
	peak = peak_of(samples)
	threshold = max(peak * 10.0 ** (SILENCE_REL_DB / 20.0), 10.0 ** (SILENCE_FLOOR_DB / 20.0)) * FULL
	first = next((i for i, s in enumerate(samples) if abs(s) >= threshold), 0)
	last = next((i for i in range(len(samples) - 1, -1, -1) if abs(samples[i]) >= threshold), len(samples) - 1)
	start = max(0, first - int(ONSET_PRE_S * RATE))
	end = min(len(samples), last + int(TAIL_S * RATE))
	if max_s and end - start > int(max_s * RATE):
		end = start + int(max_s * RATE)
	return [round(start / RATE, 6), round(end / RATE, 6)]


def apply_row(source, row):
	"""The shipped PCM (list of ints) for `source` and a manifest row's trim, fades, crossfade and gain."""
	loop = row.get("loop_xfade_ms") is not None
	if row.get("trim_s"):
		a = int(round(row["trim_s"][0] * RATE))
		b = int(round(row["trim_s"][1] * RATE))
		work = [float(s) for s in source[a:b]]
	else:
		work = [float(s) for s in source]
	if loop:
		n = int(round(float(row["loop_xfade_ms"]) / 1000.0 * RATE))
		if n > 0 and len(work) > 2 * n:
			head, tail = work[:n], work[len(work) - n:]
			blended = [head[i] * ((i + 1) / (n + 1)) + tail[i] * (1.0 - (i + 1) / (n + 1)) for i in range(n)]
			work = blended + work[n:len(work) - n]
	elif row.get("fade_ms"):
		fade_in = int(round(row["fade_ms"][0] / 1000.0 * RATE))
		fade_out = int(round(row["fade_ms"][1] / 1000.0 * RATE))
		count = len(work)
		for i in range(min(fade_in, count)):
			work[i] *= i / max(fade_in, 1)
		for i in range(min(fade_out, count)):
			work[count - 1 - i] *= i / max(fade_out, 1)
	gain = 10.0 ** (float(row.get("gain_db", 0.0)) / 20.0)
	out = []
	for value in work:
		v = int(round(value * gain))
		out.append(32767 if v > 32767 else (-32768 if v < -32768 else v))
	return out


def fit_gain(source, row):
	"""gain_db for a row whose trim and fades are set: the `peak_db` target, or `lufs` capped to -1 dBFS peak."""
	trial = dict(row)
	trial["gain_db"] = 0.0
	shaped = apply_row(source, trial)
	peak = peak_of(shaped)
	if peak <= 0.0:
		raise IngestError("%s is silent" % row.get("file"))
	if row.get("lufs") is not None:
		gain = float(row["lufs"]) - integrated_lufs(shaped)
		limit = float(row.get("peak_cap_db", -1.0)) - to_db(peak)
		gain = min(gain, limit)
	else:
		gain = float(row.get("peak_db", DEFAULTS["peak_db"])) - to_db(peak)
	return round(gain, 2)


def build_row(take_path, row, loop):
	"""Fill in what a row leaves to be found (trim, then gain) from its take; returns the PCM."""
	source = decode_mp3(take_path)
	if loop:
		row.setdefault("loop_xfade_ms", 0.0)
	else:
		if not row.get("trim_s"):
			row["trim_s"] = find_trim(source, row.pop("max_s", None))
		else:
			row.pop("max_s", None)
		if "fade_ms" not in row or row["fade_ms"] is None:
			row["fade_ms"] = list(DEFAULTS["fade_ms"])
		span = row["trim_s"][1] - row["trim_s"][0]
		if span * 1000.0 < row["fade_ms"][0] + row["fade_ms"][1]:
			raise IngestError("%s: %.0f ms is too short for its fades" % (row["file"], span * 1000.0))
	if "gain_db" not in row:
		row["gain_db"] = fit_gain(source, row)
	return apply_row(source, row)


# --------------------------------------------------------------------------- manifest, ledger, files

def load_manifest():
	if not os.path.isfile(MANIFEST):
		raise IngestError("no manifest: run --init first")
	with open(MANIFEST) as f:
		return json.load(f)


def save_manifest(manifest):
	manifest["files"].sort(key=lambda r: r["file"])
	manifest["slots"] = dict(sorted(manifest["slots"].items()))
	with open(MANIFEST, "w") as f:
		json.dump(manifest, f, indent="\t", sort_keys=False)
		f.write("\n")


def load_ledger():
	"""ledger id -> its call line."""
	out = {}
	if os.path.isfile(LEDGER):
		with open(LEDGER) as f:
			for line in f:
				line = line.strip()
				if line:
					record = json.loads(line)
					if record.get("event") == "call" and record.get("id"):
						out[record["id"]] = record
	return out


def take_path(ledger_id):
	if not TAKE_RE.match(ledger_id):
		raise IngestError("bad ledger id '%s'" % ledger_id)
	return os.path.join(ELEVEN, ledger_id + ".mp3")


def pool_of(file_name):
	stem = os.path.splitext(file_name)[0]
	return stem[:stem.rfind("_")]


def sha256_file(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		h.update(f.read())
	return h.hexdigest()


def cmd_init(args):
	if os.path.isfile(MANIFEST):
		raise IngestError("the manifest exists; --init only starts one")
	os.makedirs(LEGACY, exist_ok=True)
	files = sorted(f for f in os.listdir(EXPORT) if f.endswith(".wav"))
	rows = []
	slots = {}
	for name in files:
		legacy = os.path.join(LEGACY, name)
		if not os.path.isfile(legacy):
			with open(os.path.join(EXPORT, name), "rb") as src, open(legacy, "wb") as dst:
				dst.write(src.read())
		pool = pool_of(name)
		rows.append({"file": name, "pool": pool, "source": "gen_sfx", "licence": GEN_LICENCE,
			"trim_s": None, "fade_ms": None, "peak_db": -1.0, "notes": "the Milestone 2 placeholder"})
		slots.setdefault(pool, None)
	for pool in slots:
		minimum, long_, loop, space = SLOT_DEFAULTS.get(pool, [1, False, False, "3d"])
		slots[pool] = {"min_variants": minimum, "long": long_, "loop": loop, "space": space}
	save_manifest({"slots": slots, "files": rows})
	say("manifest: %d rows, %d slots; %d legacy copies in %s" % (len(rows), len(slots), len(files), os.path.relpath(LEGACY, REPO)))


# --------------------------------------------------------------------------- analyze

def features(samples):
	peak = peak_of(samples)
	trim = find_trim(samples, None)
	a, b = int(trim[0] * RATE), int(trim[1] * RATE)
	active = samples[a:b]
	crossings = sum(1 for i in range(1, len(active)) if (active[i - 1] < 0) != (active[i] < 0))
	loud = next((i for i, s in enumerate(samples) if abs(s) >= 0.5 * peak * FULL), 0)
	return {"length_s": len(samples) / RATE, "onset_ms": trim[0] * 1000.0 + ONSET_PRE_S * 1000.0,
		"active_ms": (trim[1] - trim[0]) * 1000.0, "peak_db": to_db(peak), "rms_db": to_db(rms_of(active)),
		"crest_db": to_db(peak) - to_db(rms_of(active)), "to_half_peak_ms": loud / RATE * 1000.0,
		"zcr_hz": crossings / max(len(active) / RATE, 1e-6) / 2.0}


def cmd_analyze(args):
	folder = os.path.join(ELEVEN, args.analyze)
	if not os.path.isdir(folder):
		raise IngestError("no folder %s" % os.path.relpath(folder, REPO))
	say("%-26s %7s %7s %7s %7s %7s %7s %8s" % ("take", "len s", "onset", "active", "peak", "rms", "crest", "zcr Hz"))
	for name in sorted(os.listdir(folder)):
		if not name.endswith(".mp3"):
			continue
		f = features(decode_mp3(os.path.join(folder, name)))
		say("%-26s %7.2f %6.0fm %6.0fm %7.1f %7.1f %7.1f %8.0f" % (name[:-4], f["length_s"], f["onset_ms"],
			f["active_ms"], f["peak_db"], f["rms_db"], f["crest_db"], f["zcr_hz"]))


# --------------------------------------------------------------------------- picks and rebuild

def remove_pool_files(pool, manifest):
	kept = []
	for row in manifest["files"]:
		if row["pool"] != pool:
			kept.append(row)
			continue
		for suffix in ("", ".import"):
			path = os.path.join(EXPORT, row["file"] + suffix)
			if os.path.exists(path):
				os.remove(path)
	manifest["files"] = kept


def cmd_picks(args):
	manifest = load_manifest()
	ledger = load_ledger()
	with open(args.picks) as f:
		picks = json.load(f)
	for pool, slot in picks.get("slots", {}).items():
		current = manifest["slots"].setdefault(pool, {"min_variants": 1, "long": False, "loop": False, "space": "3d"})
		current.update(slot)
	defaults = dict(DEFAULTS)
	defaults.update(picks.get("defaults", {}))
	for pool, spec in picks["pools"].items():
		if not NAME_RE.match(pool):
			raise IngestError("bad pool name '%s'" % pool)
		if args.only and pool != args.only:
			continue
		slot = manifest["slots"].get(pool)
		if slot is None:
			raise IngestError("pool '%s' has no slot: declare it under \"slots\"" % pool)
		options = dict(defaults)
		options.update({k: v for k, v in spec.items() if k not in ("takes", "notes")})
		if "lufs" in spec and "peak_db" not in spec:
			options.pop("peak_db", None)
		remove_pool_files(pool, manifest)
		for n, take in enumerate(spec["takes"], 1):
			if take not in ledger:
				raise IngestError("take '%s' is not in the ledger" % take)
			file_name = "%s_%02d.wav" % (pool, n)
			row = {"file": file_name, "pool": pool, "source": "elevenlabs:" + take, "licence": ELEVEN_LICENCE}
			for key in ("peak_db", "lufs", "max_s", "fade_ms", "peak_cap_db"):
				if key in options and options[key] is not None:
					row[key] = options[key]
			if slot.get("loop"):
				row.pop("max_s", None)
				row["loop_xfade_ms"] = float(options.get("loop_xfade_ms", 0.0))
			row["notes"] = spec.get("notes", "")
			pcm = build_row(take_path(take), row, bool(slot.get("loop")))
			write_wav(os.path.join(EXPORT, file_name), pcm)
			manifest["files"].append(row)
		say("%s: %d variants" % (pool, len(spec["takes"])))
	save_manifest(manifest)


def source_pcm(row):
	return decode_mp3(take_path(row["source"].split(":", 1)[1]))


def cmd_rebuild(args):
	manifest = load_manifest()
	count = 0
	for row in manifest["files"]:
		if not row["source"].startswith("elevenlabs:") or (args.only and row["pool"] != args.only):
			continue
		write_wav(os.path.join(EXPORT, row["file"]), apply_row(source_pcm(row), row))
		count += 1
	say("rebuilt %d files" % count)


# --------------------------------------------------------------------------- check

def cmd_check(args):
	manifest = load_manifest()
	ledger = load_ledger()
	problems = []
	rows = {r["file"]: r for r in manifest["files"]}
	shipped = sorted(f for f in os.listdir(EXPORT) if f.endswith(".wav"))
	for name in shipped:
		if name not in rows:
			problems.append("%s has no manifest row" % name)
	for name, row in rows.items():
		if args.only and row["pool"] != args.only:
			continue
		path = os.path.join(EXPORT, name)
		if not os.path.isfile(path):
			problems.append("%s: a row without a file" % name)
			continue
		if row["pool"] not in manifest["slots"]:
			problems.append("%s: pool %s has no slot" % (name, row["pool"]))
		if pool_of(name) != row["pool"]:
			problems.append("%s: the name does not give pool %s" % (name, row["pool"]))
		try:
			have = read_wav(path)
		except (IngestError, wave.Error, EOFError) as err:
			problems.append(str(err))
			continue
		source = row["source"]
		if source == "gen_sfx":
			legacy = os.path.join(LEGACY, name)
			if not os.path.isfile(legacy) or sha256_file(legacy) != sha256_file(path):
				problems.append("%s: a gen_sfx row whose file differs from tests/fixtures/sfx_legacy/" % name)
		elif source.startswith("elevenlabs:"):
			ledger_id = source.split(":", 1)[1]
			call = ledger.get(ledger_id)
			if call is None:
				problems.append("%s: %s is not in the ledger" % (name, ledger_id))
				continue
			try:
				take = take_path(ledger_id)
				if sha256_file(take) != call.get("sha256"):
					problems.append("%s: the take's MP3 differs from its ledger sha256" % name)
				want = apply_row(decode_mp3(take), row)
			except (IngestError, OSError) as err:
				problems.append("%s: %s" % (name, err))
				continue
			if len(want) != len(have):
				problems.append("%s: rebuilt %d samples, shipped %d" % (name, len(want), len(have)))
			else:
				worst = max((abs(a - b) for a, b in zip(want, have)), default=0)
				if worst > args.tolerance:
					problems.append("%s: the rebuilt PCM differs by up to %d" % (name, worst))
		else:
			problems.append("%s: unknown source '%s'" % (name, source))
	empty = [(p, s["min_variants"], sum(1 for r in manifest["files"] if r["pool"] == p))
		for p, s in manifest["slots"].items() if sum(1 for r in manifest["files"] if r["pool"] == p) < s["min_variants"]]
	for pool, minimum, have in empty:
		say("empty slot: %s has %d of %d variants" % (pool, have, minimum))
	for problem in problems:
		say("FAIL " + problem)
	checked = len(rows) if not args.only else sum(1 for r in rows.values() if r["pool"] == args.only)
	say("ingest --check: %d rows, %d problems, %d empty slots" % (checked, len(problems), len(empty)))
	return 1 if problems else 0


# --------------------------------------------------------------------------- ASSETS.md

def titled(file_name):
	pool = pool_of(file_name)
	n = file_name[len(pool) + 1:-4]
	return "%s %d" % (pool.replace("_", " ").capitalize(), int(n))


def assets_row(row, call):
	prompt = (call or {}).get("text", "")
	source = "ElevenLabs sound-effects API (`%s`, Starter plan); ledger `%s`; prompt: \"%s\"" % (
		(call or {}).get("model_id", "?"), row["source"].split(":", 1)[1], prompt.replace("|", "/"))
	notes = row.get("notes", "") or ""
	extras = "trim %s s, gain %+.2f dB" % ("-".join("%g" % t for t in row["trim_s"]), row["gain_db"]) if row.get("trim_s") else \
		"loop, gain %+.2f dB" % row["gain_db"]
	return "| %s | `assets/export/sfx/%s` | %s | %s | %s |" % (titled(row["file"]), row["file"], source,
		row["licence"], (notes + " " if notes else "") + extras)


def region(lines, heading):
	"""[first, end) of the body under `heading`, up to the next heading."""
	start = next((i for i, l in enumerate(lines) if l.strip() == heading), None)
	if start is None:
		raise IngestError("ASSETS.md has no heading '%s'" % heading)
	end = start + 1
	while end < len(lines) and not lines[end].startswith("#"):
		end += 1
	return start + 1, end


def cmd_assets(args):
	manifest = load_manifest()
	ledger = load_ledger()
	with open(ASSETS_MD) as f:
		lines = f.read().split("\n")
	generated = {r["file"] for r in manifest["files"]}
	# A placeholder row whose file was re-sourced goes (its file is gone or now an ElevenLabs take).
	gen_files = {r["file"] for r in manifest["files"] if r["source"] == "gen_sfx"}
	kept = []
	for line in lines:
		m = re.search(r"`assets/export/sfx/([a-z_0-9]+\.wav)`", line)
		if m and "Procedurally generated" in line and m.group(1) not in gen_files:
			continue
		kept.append(line)
	lines = kept
	sections = [("### › Voices (ElevenLabs)", True, "Every generated voice, from the ElevenLabs sound-effects API on the Starter plan (commercial licence), with its ledger id. 16-bit mono 44.1 kHz WAV in Git LFS, rebuilt from the MP3 takes in `assets/source/sfx/eleven/` by `tools/audio/ingest.py` (`--check` proves it). Source takes: `assets/source/sfx/eleven/voices/` (every candidate MP3, Git LFS), jobs and picks beside it; the ledger is `assets/source/sfx/eleven_ledger.jsonl`. The M2 placeholders of the 38 SFX that were not replaced are kept as `tests/fixtures/sfx_legacy/` (procedural, project-owned) for the audition room's A/B.")]
	for heading, voices, intro in sections:
		rows = [r for r in manifest["files"] if r["source"].startswith("elevenlabs:") and bool(VOICE_POOLS.match(r["pool"])) == voices]
		table = ["", intro, "", "| Asset | Path | Source / service | License | Notes |", "| --- | --- | --- | --- | --- |"]
		table += [assets_row(r, ledger.get(r["source"].split(":", 1)[1])) for r in sorted(rows, key=lambda r: r["file"])]
		table.append("")
		a, b = region(lines, heading)
		lines[a:b] = table
	with open(ASSETS_MD, "w") as f:
		f.write("\n".join(lines))
	say("ASSETS.md: voice rows written")


def main(argv):
	parser = argparse.ArgumentParser(description="Ingest ElevenLabs takes into the game's SFX folder.")
	parser.add_argument("--init", action="store_true")
	parser.add_argument("--analyze", metavar="GROUP")
	parser.add_argument("--picks", metavar="FILE")
	parser.add_argument("--check", action="store_true")
	parser.add_argument("--assets", action="store_true")
	parser.add_argument("--only", metavar="POOL")
	parser.add_argument("--tolerance", type=int, default=0)
	args = parser.parse_args(argv)
	try:
		if args.init:
			cmd_init(args)
		elif args.analyze:
			cmd_analyze(args)
		elif args.picks:
			cmd_picks(args)
		elif args.check:
			return cmd_check(args)
		elif args.assets:
			cmd_assets(args)
		else:
			cmd_rebuild(args)
	except IngestError as err:
		say("ingest: %s" % err)
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
