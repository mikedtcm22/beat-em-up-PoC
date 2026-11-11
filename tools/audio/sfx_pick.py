"""Choose the takes of the sound effects by measured features (Milestone 6, package SFX; plan D19).

Usage (ffmpeg and the standard library only; run as python3 -I):
	python3 -I tools/audio/sfx_pick.py --table <group>            every take of a group with its measured features and score
	python3 -I tools/audio/sfx_pick.py --legacy                   the same features for the M2 placeholders (the old role of each pool)
	python3 -I tools/audio/sfx_pick.py --picks <group> [<group>...] write assets/source/sfx/eleven/sfx.picks.json
	python3 -I tools/audio/sfx_pick.py --levels                   loudness of the shipped hit stack and voices (for the dB rebalance)

The ear is Game-boy's (the audition room); this script only keeps a take out of the way that is plainly wrong for
its job. Per take (a take is one candidate of one prompt; a prompt is one variant of a pool):
	active_ms	onset less 3 ms to the last sound within 40 dB of the peak, plus 30 ms (ingest.py's own trim);
	peak_ms		where the loudest 5 ms window starts, from the trimmed start (a whoosh must peak under 50 ms,
			tests/test_audio.gd);
	centroid	the spectral centroid of the first 0.25 s after the onset, in Hz (a thud is low, a crack high);
	tail		the share of the active energy in its last 40 per cent (a dry hit has none; a reverb tail has plenty);
	clip		samples within 0.5 dB of full scale (a flat top).
The score is the sum of the penalties for each feature outside its pool's window (ROLES); the lowest score in a
prompt's takes is the choice, and every other take stays in its job folder for a later swap. A bed is scored on
steadiness instead: the spread of its half-second levels, its loudest half second above the median, and how far
its last half second sits from its first (a loop's seam).
"""
import argparse
import array
import cmath
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ingest  # noqa: E402  (a sibling tool; -I does not put the script's folder on the path by itself)

ELEVEN = ingest.ELEVEN
RATE = ingest.RATE
PICKS_OUT = os.path.join(ELEVEN, "sfx.picks.json")

# pool: (target active ms, lowest ms, highest ms, centroid low Hz, centroid high Hz, max_s, peak_ms limit)
# The windows say what the layer is for. A thud is the low body of a hit; a crack the high snap; a crunch the
# gritty middle; a body fall low and a little longer; a sub thump the lowest of all; a whoosh a bright pass-by
# that is loudest at once.
ROLES = {
	"whoosh": (300, 120, 600, 1200, 6000, 0.6, 45),
	"thud": (180, 80, 400, 150, 1100, 0.5, 40),
	"crack": (150, 60, 400, 1800, 7000, 0.5, 40),
	"crunch": (420, 200, 800, 700, 5000, 0.8, 120),
	"body_fall": (550, 250, 1000, 100, 2500, 1.0, 150),
	"sub_thump": (400, 200, 800, 40, 400, 0.8, 80),
	"block_clack": (140, 60, 400, 900, 5000, 0.5, 40),
	"parry_ting": (500, 250, 800, 1800, 9000, 0.8, 40),
	"guard_break": (650, 350, 1000, 500, 5000, 1.0, 100),
	"barrier_shutter_close": (850, 500, 1400, 400, 5000, 1.4, 1400),
	"barrier_shutter_open": (1000, 500, 1400, 400, 5000, 1.4, 1400),
	"barrier_gate_close": (850, 500, 1400, 400, 5000, 1.4, 1400),
	"barrier_gate_open": (1000, 500, 1400, 400, 5000, 1.4, 1400),
	"barrier_car_close": (1200, 600, 1400, 120, 3500, 1.4, 1400),
	"barrier_car_open": (1200, 600, 1400, 120, 3500, 1.4, 1400),
	"weapon_pickup": (450, 200, 700, 800, 6000, 0.7, 150),
	"weapon_throw": (600, 300, 800, 500, 5000, 0.8, 150),
	"weapon_break": (900, 500, 1200, 500, 6000, 1.2, 120),
	"weapon_land": (650, 300, 800, 500, 6000, 0.8, 100),
	"weapon_pipe_hit": (500, 200, 700, 700, 5500, 0.7, 50),
	"weapon_bike_chain_hit": (550, 250, 800, 800, 6000, 0.8, 50),
	"sting_go": (1500, 900, 1800, 400, 5000, 1.8, 1800),
	"sting_clear": (1700, 1000, 2000, 400, 5000, 2.0, 2000),
}
# A variant whose best take still peaks later than this is left out (a whoosh loudest after 50 ms fails
# tests/test_audio.gd; the pool has more variants than its minimum).
HARD_PEAK_MS = {"whoosh": 50, "weapon_pipe_hit": 100, "weapon_bike_chain_hit": 100, "weapon_break": 150}
# The pools that must be dry: a tail after a hit, a block or a clack is reverb (a barrier rattles on and a sting rings).
HITS_DRY = ("whoosh", "thud", "crack", "crunch", "body_fall", "sub_thump", "block_clack", "parry_ting", "guard_break")
BED_LUFS = -20.0
BED_XFADE_MS = 1000.0


def fft(values):
	"""A radix-2 FFT of a list whose length is a power of two (the takes are short, so pure Python is enough)."""
	n = len(values)
	if n == 1:
		return values
	even = fft(values[0::2])
	odd = fft(values[1::2])
	out = [0j] * n
	for k in range(n // 2):
		t = cmath.exp(-2j * math.pi * k / n) * odd[k]
		out[k] = even[k] + t
		out[k + n // 2] = even[k] - t
	return out


def centroid_hz(samples, start, count=11025):
	"""The spectral centroid of `count` samples from `start` (zero-padded to a power of two, Hann-windowed)."""
	chunk = [float(s) for s in samples[start:start + count]]
	if len(chunk) < 64:
		return 0.0
	size = 1
	while size < len(chunk):
		size *= 2
	n = len(chunk)
	chunk = [v * (0.5 - 0.5 * math.cos(2.0 * math.pi * i / max(n - 1, 1))) for i, v in enumerate(chunk)] + [0.0] * (size - n)
	spectrum = fft(chunk)
	num = den = 0.0
	for k in range(1, size // 2):
		mag = abs(spectrum[k])
		num += k * RATE / size * mag
		den += mag
	return num / den if den > 0.0 else 0.0


def measure(samples, max_s=None):
	"""The features of one take (see the module docstring)."""
	trim, cut = ingest.find_trim(samples, max_s)
	a, b = int(round(trim[0] * RATE)), int(round(trim[1] * RATE))
	active = samples[a:b]
	peak = ingest.peak_of(samples)
	# The loudest 5 ms window exactly as tests/test_audio.gd finds it (windows of 0.005 s, the first maximum wins).
	best, best_w = -1.0, 0
	for w in range(int(len(active) / (0.005 * RATE))):
		level = ingest.rms_of(active[int(w * 0.005 * RATE):int((w + 1) * 0.005 * RATE)])
		if level > best:
			best, best_w = level, w
	split = int(len(active) * 0.6)
	whole = sum(float(s) * s for s in active) or 1.0
	tail = sum(float(s) * s for s in active[split:]) / whole
	clipped = sum(1 for s in active if abs(s) >= 0.944 * 32768.0)
	return {"length_s": len(samples) / RATE, "active_ms": (trim[1] - trim[0]) * 1000.0, "cut": cut,
		"peak_db": ingest.to_db(peak), "rms_db": ingest.to_db(ingest.rms_of(active)),
		"crest_db": ingest.to_db(peak) - ingest.to_db(ingest.rms_of(active)), "peak_ms": best_w * 5.0,
		"centroid": centroid_hz(samples, a + int(0.003 * RATE)), "tail": tail, "clip": clipped, "trim": trim}


def score(pool, f):
	"""(penalty, why) for a one-shot take: 0 is a take inside every window of its pool's role."""
	target, lo, hi, c_lo, c_hi, max_s, peak_limit = ROLES[pool]
	pen, why = 0.0, []
	active = min(f["active_ms"], max_s * 1000.0)
	pen += abs(math.log(max(active, 1.0) / target)) * 1.0
	if f["active_ms"] > hi * 1.15:
		pen += 0.6
		why.append("long")
	if f["active_ms"] < lo * 0.85:
		pen += 0.6
		why.append("short")
	if f["centroid"] < c_lo:
		pen += math.log2(c_lo / max(f["centroid"], 1.0)) * 1.2
		why.append("dull")
	if f["centroid"] > c_hi:
		pen += math.log2(f["centroid"] / c_hi) * 1.2
		why.append("bright")
	if f["peak_ms"] > peak_limit:
		pen += 2.0 + (f["peak_ms"] - peak_limit) / 50.0
		why.append("late peak")
	if f["tail"] > 0.25 and (pool in HITS_DRY or pool.endswith("_hit")):
		pen += (f["tail"] - 0.25) * 4.0
		why.append("tail")
	if f["clip"] > 40:
		pen += 0.5
		why.append("flat top")
	if f["rms_db"] < -29.0:
		pen += 1.0 + (-29.0 - f["rms_db"]) * 0.2
		why.append("air")
	return pen, ",".join(why)


def bed_features(samples):
	"""Steadiness of a bed: dB spread of its half-second levels, loudest above the median, and the seam."""
	step = int(0.5 * RATE)
	levels = [ingest.to_db(ingest.rms_of(samples[i:i + step])) for i in range(0, len(samples) - step + 1, step)]
	ordered = sorted(levels)
	median = ordered[len(ordered) // 2]
	mean = sum(levels) / len(levels)
	spread = math.sqrt(sum((v - mean) ** 2 for v in levels) / len(levels))
	return {"length_s": len(samples) / RATE, "spread_db": spread, "event_db": max(levels) - median,
		"seam_db": abs(levels[0] - levels[-1]), "median_db": median, "peak_db": ingest.to_db(ingest.peak_of(samples)),
		"centroid": centroid_hz(samples, int(len(samples) / 2), 16384)}


def bed_score(f):
	return f["spread_db"] * 1.0 + max(f["event_db"] - 3.0, 0.0) * 0.5 + f["seam_db"] * 0.3 + (3.0 if f["length_s"] < 20 else 0.0)


def load_group(group):
	"""{job id: [(take number, ledger id, path)]} and the jobs file's jobs."""
	with open(os.path.join(ELEVEN, group + ".jobs.json")) as f:
		jobs = json.load(f)["jobs"]
	out = {}
	for job in jobs:
		out[job["id"]] = (job, [(n, "%s/%s_%02d" % (group, job["id"], n),
			os.path.join(ELEVEN, group, "%s_%02d.mp3" % (job["id"], n))) for n in range(1, int(job.get("candidates", 1)) + 1)])
	return out


def cmd_table(groups, write=None):
	chosen = {}
	for group in groups:
		for job_id, (job, takes) in load_group(group).items():
			pool = job["pool"]
			rows = []
			for n, ledger_id, path in takes:
				samples = ingest.decode_mp3(path)
				if job.get("loop"):
					f = bed_features(samples)
					pen, why = bed_score(f), ""
				else:
					f = measure(samples, ROLES[pool][5])
					pen, why = score(pool, f)
				rows.append((pen, n, ledger_id, f, why))
			rows.sort(key=lambda r: (r[0], r[1]))
			dropped = pool in HARD_PEAK_MS and rows[0][3]["peak_ms"] >= HARD_PEAK_MS[pool]
			if not dropped:
				chosen.setdefault(pool, []).append((job_id, rows[0], rows))
			print("%s  (%s)%s" % (job_id, job["text"][:78], "  DROPPED: no take peaks in time" if dropped else ""))
			for pen, n, ledger_id, f, why in sorted(rows, key=lambda r: r[1]):
				mark = "*" if ledger_id == rows[0][2] else " "
				if job.get("loop"):
					print("  %s %-34s len %5.1fs spread %4.1f event %4.1f seam %4.1f median %6.1f peak %5.1f centroid %5.0f  score %5.2f"
						% (mark, ledger_id, f["length_s"], f["spread_db"], f["event_db"], f["seam_db"], f["median_db"], f["peak_db"], f["centroid"], pen))
				else:
					print("  %s %-34s active %5.0f ms peak@ %4.0f ms centroid %5.0f Hz  pk %5.1f rms %5.1f crest %4.1f tail %.2f clip %3d  score %5.2f %s"
						% (mark, ledger_id, f["active_ms"], f["peak_ms"], f["centroid"], f["peak_db"], f["rms_db"], f["crest_db"],
							f["tail"], f["clip"], pen, why))
	if write:
		pools = {}
		slots = {}
		for pool, picks in chosen.items():
			rows = sorted(picks, key=lambda p: p[0])
			first_job = load_group(next(g for g in groups if any(j for j in load_group(g).values() if j[0]["pool"] == pool)))
			job = next(j for j, _t in first_job.values() if j["pool"] == pool)
			spec = {"takes": [p[1][2] for p in rows]}
			if job.get("loop"):
				spec.update({"lufs": BED_LUFS, "loop_xfade_ms": BED_XFADE_MS,
					"notes": "the take with the steadiest levels, no events and the closest seam; the loop is crossfaded over %d ms" % BED_XFADE_MS})
				slots[pool] = {"min_variants": 1, "long": True, "loop": True, "space": "2d"}
			else:
				spec.update({"peak_db": -1.0, "max_s": ROLES[pool][5],
					"notes": "one take per prompt, the lowest score of its candidates for the pool's role (active length, spectral centroid, peak time, tail, flat top)"})
				if pool.startswith("sting_"):
					slots[pool] = {"long": True}
			pools[pool] = spec
		with open(write, "w") as f:
			json.dump({"slots": slots, "defaults": {"peak_db": -1.0}, "pools": pools}, f, indent="\t")
			f.write("\n")
		print("wrote %s" % os.path.relpath(write, ingest.REPO))


def cmd_legacy():
	for pool in sorted(ROLES):
		path = os.path.join(ingest.LEGACY, "%s_01.wav" % pool)
		if not os.path.isfile(path):
			continue
		f = measure(ingest.read_wav(path), ROLES[pool][5])
		print("%-14s legacy 01: active %5.0f ms peak@ %4.0f ms centroid %5.0f Hz rms %5.1f crest %4.1f"
			% (pool, f["active_ms"], f["peak_ms"], f["centroid"], f["rms_db"], f["crest_db"]))


def cmd_levels():
	"""rms over the first 0.4 s (what the tier test sums) and over the active part, of variant 01 of each pool."""
	for pool in ("whoosh", "thud", "crack", "crunch", "body_fall", "sub_thump", "block_clack", "parry_ting", "guard_break",
			"grunt", "effort", "ko_punk", "player_grunt", "weapon_pipe_hit", "weapon_bike_chain_hit"):
		files = sorted(n for n in os.listdir(ingest.EXPORT) if n.endswith(".wav") and ingest.pool_of(n) == pool)
		if not files:
			continue
		rows = []
		for name in files:
			s = ingest.read_wav(os.path.join(ingest.EXPORT, name))
			head = s[:int(0.4 * RATE)]
			f = measure(s)
			rows.append("%s head %5.1f / active %5.1f" % (name[len(pool) + 1:-4], ingest.to_db(ingest.rms_of(head)) + 10.0 * math.log10(len(head) / (0.4 * RATE)), f["rms_db"]))
		print("%-22s %s" % (pool, "  ".join(rows)))


def main(argv):
	parser = argparse.ArgumentParser(description="Choose sound-effect takes by measured features.")
	parser.add_argument("--table", metavar="GROUP")
	parser.add_argument("--legacy", action="store_true")
	parser.add_argument("--picks", nargs="+", metavar="GROUP")
	parser.add_argument("--levels", action="store_true")
	args = parser.parse_args(argv)
	try:
		if args.table:
			cmd_table([args.table])
		elif args.legacy:
			cmd_legacy()
		elif args.picks:
			cmd_table(args.picks, PICKS_OUT)
		elif args.levels:
			cmd_levels()
		else:
			parser.print_help()
	except ingest.IngestError as err:
		print("sfx_pick: %s" % err)
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
