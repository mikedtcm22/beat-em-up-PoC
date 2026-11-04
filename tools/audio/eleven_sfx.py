"""Sound generation with the ElevenLabs sound-effects API (Milestone 6, plan D18-D21).

Usage:
	python3 -I tools/audio/eleven_sfx.py <jobs.json> --label <text> --ceiling <credits> [--dry-run] [--only <id> ...]
	python3 -I tools/audio/eleven_sfx.py --balance

A jobs file is one group of sounds, either a JSON list of jobs or
	{"group": "<folder name>", "jobs": [...]}
and a job is
	{"id": "grunt_punk", "text": "<prompt>", "duration_seconds": 0.8, "candidates": 2,
	 "prompt_influence": 0.5, "loop": false}
`duration_seconds` is required (0.5 to 30): a call without it lets the model pick a length and the cost
is unknown. `candidates` (default 1) is how many takes to generate; `loop` asks for a seamless loop.
Each take is one paid call. Its MP3 is written to assets/source/sfx/eleven/<group>/<id>_<nn>.mp3 (the
group defaults to the jobs file's name) and never overwrites a file: a take already in the ledger and on
disk is skipped, so an interrupted run resumes without paying twice. Downloads are untrusted: the MP3s
only ever reach ffmpeg as path arguments (tools/audio/ingest.py).

The ledger, assets/source/sfx/eleven_ledger.jsonl (append-only), gets one line per call:
	{"v", "ts", "milestone", "event": "call"|"error", "id": "<group>/<id>_<nn>", "label", "text",
	 "duration_seconds", "model_id", "prompt_influence", "loop", "expected_credits", "file", "bytes", "sha256"}
and the end of every run one {"event": "settle", "credits_run_used", "credits_recorded", "credits_remainder"}.
The manifest's `source` for a take is "elevenlabs:<id>". Credits are read off GET /v1/user/subscription
(`character_count`) at the start and end of a run (and every 20 calls), so the ledger's total is the measured cost, not the table's.
The counter LAGS a call by many seconds (measured 2026-11-04: a call's credits showed up a call later, the
last ones half a minute after), and polling it around every call hit the API's rate limit. So a run reads it at
the start and every 20 calls, and ends by waiting for it to settle: one {"event": "settle", "label",
"credits_remainder"} line records what the run really cost beyond what its calls recorded. The ledger's total is the sum of the calls' credits_used (the projection when absent) plus the settle remainders.

The policy, tools/audio/eleven_policy.json, is a hard stop: the tool refuses a call that would take the
milestone's ledger past `stop`, or that costs more than `max_call`. `--ceiling` is the package's own limit:
the credits already spent under the same `--label`, plus this run's projection, must fit within it, or
nothing runs. `--dry-run` prints the projection and calls nothing.

The key is ELEVEN_LABS_API_KEY or ELEVENLABS_API_KEY from the environment, else from the repo's .env, else
(in a linked worktree) from the main checkout's .env. It is sent in the xi-api-key header, never printed,
logged or put in a URL.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
POLICY_PATH = os.path.join(HERE, "eleven_policy.json")
LEDGER_PATH = os.path.join(REPO, "assets", "source", "sfx", "eleven_ledger.jsonl")
OUT_ROOT = os.path.join(REPO, "assets", "source", "sfx", "eleven")
BASE = "https://api.elevenlabs.io"
USER_AGENT = "beat-em-up-poc/1.0 (eleven_sfx.py)"
KEY_NAMES = ("ELEVEN_LABS_API_KEY", "ELEVENLABS_API_KEY")
NAME_RE = re.compile(r"^[A-Za-z0-9_.-]{1,48}$")
LABEL_RE = re.compile(r"^[A-Za-z0-9_. -]{1,40}$")
MIN_DURATION_S = 0.5
MAX_DURATION_S = 30.0
MAX_MP3_BYTES = 8 * 1024 * 1024
TIMEOUT_S = 180
CHECK_EVERY = 20
RETRY_WAITS_S = (8, 20, 45)

_SECRETS = []


class ElevenError(Exception):
	"""A refusal or failure; the message is already free of secrets."""


# --------------------------------------------------------------------------- secrets

def env_files():
	"""`.env` candidates: this checkout's, then (in a linked worktree) the main checkout's."""
	out = [os.path.join(REPO, ".env")]
	dot_git = os.path.join(REPO, ".git")
	if os.path.isfile(dot_git):
		with open(dot_git) as f:
			first = f.readline().strip()
		if first.startswith("gitdir:"):
			gitdir = first.split(":", 1)[1].strip()
			out.append(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(gitdir))), ".env"))
	return out


def read_env(name):
	"""A value from the environment, else from the first `.env` that has it; None if unset."""
	if os.environ.get(name):
		return os.environ[name].strip()
	for path in env_files():
		if not os.path.isfile(path):
			continue
		with open(path) as f:
			for line in f:
				line = line.strip()
				if line.startswith("export "):
					line = line[7:].strip()
				if line.startswith(name + "="):
					value = line.split("=", 1)[1].strip().strip('"').strip("'")
					if value:
						return value
	return None


def read_key():
	for name in KEY_NAMES:
		value = read_env(name)
		if value:
			if value not in _SECRETS:
				_SECRETS.append(value)
			return value
	raise ElevenError("no key: set ELEVEN_LABS_API_KEY or ELEVENLABS_API_KEY in the environment or .env")


def redact(text):
	out = str(text)
	for secret in _SECRETS:
		if secret:
			out = out.replace(secret, "<key>")
	return out


def now_utc():
	return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------------------- policy and ledger

def load_policy(path=POLICY_PATH):
	with open(path) as f:
		policy = json.load(f)
	for field in ("milestone", "stop", "max_call", "credits_per_second", "model_id", "output_format"):
		if field not in policy:
			raise ElevenError("%s lacks %s" % (path, field))
	return policy


class Ledger:
	"""The append-only JSONL file; see the module docstring for the line schema."""

	def __init__(self, path, milestone):
		self.path = path
		self.milestone = milestone

	def lines(self):
		out = []
		if not os.path.exists(self.path):
			return out
		with open(self.path) as f:
			for number, line in enumerate(f, 1):
				line = line.strip()
				if not line:
					continue
				try:
					out.append(json.loads(line))
				except ValueError:
					raise ElevenError("%s line %d is not JSON; fix it by hand before spending" % (self.path, number))
		return out

	def append(self, record):
		record = dict(record)
		record.setdefault("v", 1)
		record.setdefault("ts", now_utc())
		record.setdefault("milestone", self.milestone)
		text = redact(json.dumps(record, separators=(",", ":")))
		os.makedirs(os.path.dirname(self.path), exist_ok=True)
		fd = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
		try:
			os.write(fd, (text + "\n").encode())
			os.fsync(fd)
		finally:
			os.close(fd)

	def calls(self):
		"""The paid calls of this milestone (`event` call), oldest first."""
		return [l for l in self.lines() if l.get("milestone") == self.milestone and l.get("event") == "call"]

	def settles(self):
		return [l for l in self.lines() if l.get("milestone") == self.milestone and l.get("event") == "settle"]

	def spent(self, label=None):
		"""Credits spent: the measured use of every call, or its projection when the use is unknown."""
		total = 0.0
		for line in self.calls():
			if label is not None and line.get("label") != label:
				continue
			used = line.get("credits_used")
			total += float(line.get("expected_credits") or 0.0) if used is None else float(used)
		for line in self.settles():
			if label is None or line.get("label") == label:
				total += float(line.get("credits_remainder") or 0.0)
		return round(total, 2)

	def done(self):
		"""Ledger ids of the takes already generated."""
		return set(l["id"] for l in self.calls() if l.get("id"))


def expected_credits(duration_s, policy):
	return round(float(duration_s) * float(policy["credits_per_second"]), 2)


def check_spend(expected, run_total, ledger, policy, ceiling, label):
	"""Refuse a call that breaks the policy's per-call limit, the milestone's stop or the package's ceiling."""
	if expected > float(policy["max_call"]) + 1e-9:
		raise ElevenError("one call would cost %g, past the policy's max_call %g" % (expected, policy["max_call"]))
	if ledger.spent() + run_total + expected > float(policy["stop"]) + 1e-9:
		raise ElevenError("the milestone's ledger (%g spent) plus this run would pass the policy stop %g"
			% (ledger.spent(), policy["stop"]))
	if ledger.spent(label) + run_total + expected > float(ceiling) + 1e-9:
		raise ElevenError("label '%s' has spent %g; this run would pass its ceiling %g"
			% (label, ledger.spent(label), ceiling))


# --------------------------------------------------------------------------- the service

class Service:
	def __init__(self, key, policy):
		self.key = key
		self.policy = policy

	def _request(self, method, path, body=None, query=""):
		data = json.dumps(body).encode() if body is not None else None
		request = urllib.request.Request(BASE + path + query, data=data, method=method)
		request.add_header("xi-api-key", self.key)
		request.add_header("User-Agent", USER_AGENT)
		if data is not None:
			request.add_header("Content-Type", "application/json")
		for wait in RETRY_WAITS_S + (None,):
			try:
				with urllib.request.urlopen(request, timeout=TIMEOUT_S) as response:
					payload = response.read(MAX_MP3_BYTES + 1)
					return response.status, payload
			except urllib.error.HTTPError as err:
				detail = redact(err.read(2000).decode("utf-8", "replace"))
				# 429: refused before any work, so nothing was charged; waiting and asking again is safe.
				if err.code == 429 and wait is not None:
					time.sleep(wait)
					continue
				raise ElevenError("HTTP %d from %s: %s" % (err.code, path, detail))
			except (urllib.error.URLError, OSError) as err:
				raise ElevenError("request to %s failed: %s" % (path, redact(err)))

	def subscription(self):
		"""{"tier", "used", "limit"}: the account's credits this period (`character_count`, `character_limit`)."""
		status, payload = self._request("GET", "/v1/user/subscription")
		try:
			info = json.loads(payload.decode("utf-8"))
			return {"tier": str(info.get("tier", "?")), "used": float(info["character_count"]),
				"limit": float(info["character_limit"])}
		except (ValueError, KeyError, TypeError):
			raise ElevenError("the subscription answer was not understood")

	def generate(self, job, take):
		"""One paid call: the MP3 bytes."""
		body = {"text": job["text"], "duration_seconds": float(job["duration_seconds"]),
			"prompt_influence": float(job.get("prompt_influence", 0.3)), "model_id": self.policy["model_id"]}
		if job.get("loop"):
			body["loop"] = True
		query = "?output_format=" + self.policy["output_format"]
		status, payload = self._request("POST", "/v1/sound-generation", body, query)
		if len(payload) > MAX_MP3_BYTES:
			raise ElevenError("the answer is larger than %d bytes; refused" % MAX_MP3_BYTES)
		if not looks_like_mp3(payload):
			raise ElevenError("the answer is not an MP3 (%d bytes)" % len(payload))
		return payload


def looks_like_mp3(data):
	if len(data) < 128:
		return False
	return data[:3] == b"ID3" or (data[0] == 0xFF and (data[1] & 0xE0) == 0xE0)


# --------------------------------------------------------------------------- jobs

def load_jobs(path):
	with open(path) as f:
		raw = json.load(f)
	if isinstance(raw, list):
		group, jobs = os.path.splitext(os.path.basename(path))[0], raw
	else:
		group = raw.get("group") or os.path.splitext(os.path.basename(path))[0]
		jobs = raw.get("jobs", [])
	if not NAME_RE.match(group):
		raise ElevenError("bad group name '%s'" % group)
	seen = set()
	for job in jobs:
		name = job.get("id", "")
		if not NAME_RE.match(str(name)):
			raise ElevenError("bad job id '%s'" % name)
		if name in seen:
			raise ElevenError("job id '%s' appears twice" % name)
		seen.add(name)
		if not str(job.get("text", "")).strip():
			raise ElevenError("job '%s' has no text" % name)
		if "duration_seconds" not in job:
			raise ElevenError("job '%s' has no duration_seconds: a call without one has an unknown cost" % name)
		duration = float(job["duration_seconds"])
		if not (MIN_DURATION_S <= duration <= MAX_DURATION_S):
			raise ElevenError("job '%s': duration_seconds %g is outside %g to %g" % (name, duration, MIN_DURATION_S, MAX_DURATION_S))
		if not (1 <= int(job.get("candidates", 1)) <= 8):
			raise ElevenError("job '%s': candidates must be 1 to 8" % name)
		influence = float(job.get("prompt_influence", 0.3))
		if not (0.0 <= influence <= 1.0):
			raise ElevenError("job '%s': prompt_influence must be 0 to 1" % name)
	return group, jobs


def takes(group, jobs, only):
	"""[(job, take number, ledger id, path)] for every candidate of the selected jobs."""
	out = []
	for job in jobs:
		if only and job["id"] not in only:
			continue
		for n in range(1, int(job.get("candidates", 1)) + 1):
			ledger_id = "%s/%s_%02d" % (group, job["id"], n)
			out.append((job, n, ledger_id, os.path.join(OUT_ROOT, group, "%s_%02d.mp3" % (job["id"], n))))
	return out


def sha256_bytes(data):
	return hashlib.sha256(data).hexdigest()


def say(text=""):
	print(redact(text), flush=True)


def run(args):
	policy = load_policy()
	ledger = Ledger(LEDGER_PATH, policy["milestone"])
	group, jobs = load_jobs(args.jobs)
	if args.only:
		unknown = [name for name in args.only if name not in [j["id"] for j in jobs]]
		if unknown:
			raise ElevenError("no such job: %s" % ", ".join(unknown))
	if not LABEL_RE.match(args.label or ""):
		raise ElevenError("--label is required (letters, digits, space, . _ -)")
	if args.ceiling is None:
		raise ElevenError("--ceiling is required: the credits this label may spend in all")
	done = ledger.done()
	todo = []
	for job, n, ledger_id, path in takes(group, jobs, args.only):
		if ledger_id in done and os.path.exists(path):
			continue
		if os.path.exists(path):
			raise ElevenError("%s exists but the ledger has no call for it; move it away first" % os.path.relpath(path, REPO))
		todo.append((job, n, ledger_id, path))
	total = round(sum(expected_credits(j["duration_seconds"], policy) for j, _, _, _ in todo), 2)
	say("group %s: %d takes to generate (%d already done), projected %g credits at %g a second; "
		"M6 ledger %g of stop %g; label '%s' %g of ceiling %g"
		% (group, len(todo), len(takes(group, jobs, args.only)) - len(todo), total, policy["credits_per_second"],
			ledger.spent(), policy["stop"], args.label, ledger.spent(args.label), args.ceiling))
	run_total = 0.0
	for job, n, ledger_id, path in todo:
		check_spend(expected_credits(job["duration_seconds"], policy), run_total, ledger, policy, args.ceiling, args.label)
		run_total += expected_credits(job["duration_seconds"], policy)
	if args.dry_run:
		for job, n, ledger_id, path in todo:
			say("  %s  %gs  %g credits  %s" % (ledger_id, job["duration_seconds"],
				expected_credits(job["duration_seconds"], policy), job["text"][:70]))
		return 0
	if not todo:
		return 0
	service = Service(read_key(), policy)
	start = service.subscription()
	say("account %s: %g of %g credits used" % (start["tier"], start["used"], start["limit"]))
	if start["limit"] - start["used"] < total:
		raise ElevenError("the account has %g credits left; this run needs %g" % (start["limit"] - start["used"], total))
	recorded_run = 0.0
	seen = start["used"]
	for index, (job, n, ledger_id, path) in enumerate(todo, 1):
		expected = expected_credits(job["duration_seconds"], policy)
		# The ledger already holds this run's earlier calls, so only this call is still to add.
		check_spend(expected, 0.0, ledger, policy, args.ceiling, args.label)
		record = {"event": "call", "id": ledger_id, "label": args.label, "text": job["text"],
			"duration_seconds": float(job["duration_seconds"]), "model_id": policy["model_id"],
			"prompt_influence": float(job.get("prompt_influence", 0.3)), "loop": bool(job.get("loop", False)),
			"expected_credits": expected}
		try:
			payload = service.generate(job, n)
		except ElevenError as err:
			record.update({"event": "error", "error": str(err)[:400]})
			ledger.append(record)
			settle(service, ledger, args.label, start["used"], recorded_run)
			raise
		os.makedirs(os.path.dirname(path), exist_ok=True)
		with open(path, "xb") as f:
			f.write(payload)
		# The call is on the ledger before anything else can fail; the cost is the projection until the
		# run settles (the counter lags and a poll per call hit the rate limit).
		record.update({"file": os.path.relpath(path, REPO), "bytes": len(payload), "sha256": sha256_bytes(payload)})
		ledger.append(record)
		recorded_run += expected
		say("  %s: %d bytes" % (ledger_id, len(payload)))
		if index % CHECK_EVERY == 0:
			seen = service.subscription()["used"]
			say("  account: %g credits used since the run began (projected so far %g)" % (seen - start["used"], recorded_run))
			if seen - start["used"] > recorded_run * 1.5 + 20:
				settle(service, ledger, args.label, start["used"], recorded_run)
				raise ElevenError("the run has cost %g, far past its projection %g: stopped; the rate in "
					"eleven_policy.json needs correcting" % (seen - start["used"], recorded_run))
	final = settle(service, ledger, args.label, start["used"], recorded_run)
	say("done: %g credits this run (projected %g)" % (final - start["used"], total))
	return 0


def settle(service, ledger, label, start_used, recorded_run):
	"""Wait for the lagging counter to stop moving, then record the run's real cost against what its calls
	recorded: the remainder makes the ledger's total the account's. Returns the final count."""
	final = None
	steady = 0
	for _ in range(30):
		time.sleep(5)
		try:
			now = service.subscription()["used"]
		except ElevenError:
			continue
		steady = steady + 1 if now == final else 0
		final = now
		if steady >= 3:
			break
	if final is None:
		final = start_used + recorded_run
	ledger.append({"event": "settle", "label": label, "credits_start": start_used, "credits_final": final,
		"credits_run_used": final - start_used, "credits_recorded": recorded_run,
		"credits_remainder": round(final - start_used - recorded_run, 2)})
	return final


def build_parser():
	parser = argparse.ArgumentParser(description="ElevenLabs sound generation with a ledger and a policy stop.")
	parser.add_argument("jobs", nargs="?", help="the jobs file (one group)")
	parser.add_argument("--label", help="the package's name in the ledger (the ceiling counts per label)")
	parser.add_argument("--ceiling", type=float, help="credits this label may spend in all")
	parser.add_argument("--dry-run", action="store_true", help="print the projection and call nothing")
	parser.add_argument("--only", nargs="*", help="run only these job ids")
	parser.add_argument("--balance", action="store_true", help="print the account's credits and the ledger's totals")
	parser.add_argument("--reconcile", action="store_true", help="wait for the counter to settle and write the "
		"settle line that makes the ledger's total equal the account's (after a run that was killed)")
	return parser


def main(argv):
	args = build_parser().parse_args(argv)
	try:
		if args.balance:
			policy = load_policy()
			ledger = Ledger(LEDGER_PATH, policy["milestone"])
			info = Service(read_key(), policy).subscription()
			say("account %s: %g of %g credits used; the M6 ledger holds %g of stop %g in %d calls"
				% (info["tier"], info["used"], info["limit"], ledger.spent(), policy["stop"], len(ledger.calls())))
			return 0
		if args.reconcile:
			policy = load_policy()
			ledger = Ledger(LEDGER_PATH, policy["milestone"])
			service = Service(read_key(), policy)
			final = settle(service, ledger, args.label or "AUDIO", service.subscription()["used"], 0.0)
			# settle() wrote final - start - 0 = 0 as its remainder; replace it with the ledger's gap.
			gap = round(final - ledger.spent(), 2)
			with open(LEDGER_PATH) as f:
				lines = f.read().rstrip("\n").split("\n")
			record = json.loads(lines[-1])
			record["credits_remainder"] = gap
			record["note"] = "reconcile: the account's count less the ledger's total"
			lines[-1] = json.dumps(record, separators=(",", ":"))
			with open(LEDGER_PATH, "w") as f:
				f.write("\n".join(lines) + "\n")
			say("reconciled: the account holds %g, the ledger now %g" % (final, Ledger(LEDGER_PATH, policy["milestone"]).spent()))
			return 0
		if not args.jobs:
			raise ElevenError("a jobs file is required")
		return run(args)
	except ElevenError as err:
		say("eleven_sfx: %s" % err)
		return 1


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
