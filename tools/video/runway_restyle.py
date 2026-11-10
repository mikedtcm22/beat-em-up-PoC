"""Restyle a shot with Runway's Aleph 2.0 (POST /v1/video_to_video), under a hard cap (docs/video/PLAN_B_TEST.md).

Usage:
	python3 -I tools/video/runway_restyle.py <jobs.json> [job ...]             run the jobs (all, or the named ones), one at a time
	python3 -I tools/video/runway_restyle.py <jobs.json> --dry-run [job ...]   check the inputs, the estimate and the cap; send nothing
	python3 -I tools/video/runway_restyle.py <jobs.json> --poll <job>          pick up a submitted job (its newest ledger row's task)
	python3 -I tools/video/runway_restyle.py --balance                         the project's credit balance (GET /v1/organization; free)
A jobs file is a JSON list of
	{"name": "t03_a", "video": "t03_punk_combo_1080.mp4", "prompt": "Restyle the whole video ...",
	 "keyframes": [{"image": "t03_key_a.png", "seconds": 0.0}], "seed": 7}
plus optional "model" (only "aleph2"), "output_format" ("mp4", the default) and "out" (the result's folder, default
<the jobs file's folder>/<name>). Paths are relative to the jobs file's folder. The result is <out>/<name>.mp4, with the task's
record in <out>/<name>_task.json.

The cap: Game-boy approved at most $15 of Runway credits for the test, at $0.01 a credit. Before each submit the tool estimates
the job from the price list (docs.dev.runwayml.com/guides/pricing.md: aleph2 is 28 credits a second, at least 56 a generation),
with the input's seconds rounded up, and refuses it if docs/video/runway_ledger.md's counted total plus the estimate would pass
CAP_CREDITS. It writes the ledger row before the submit and the result after: the task's charged credits (its "cost"), else the
change in the credit balance, else the estimate. A row counts its charge, or its estimate while the charge is unknown; a request
the API answered with an error (no task made) counts 0.

The key is RUNWAYML_API_SECRET (the SDKs' name) or RUNWAY_API_KEY, from the environment, else this checkout's .env, else (in a
linked worktree) the main checkout's .env. It goes only in the Authorization header to api.dev.runwayml.com (never to the
upload or download hosts, and never across a redirect), and is never printed or written. Downloads are data: saved, never run.
"""
import json
import math
import mimetypes
import os
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
API = "https://api.dev.runwayml.com"
API_VERSION = "2024-11-06"
# RUNWAY_LEDGER points the tool at another ledger (for testing the cap); the real one is docs/video/runway_ledger.md.
LEDGER = os.environ.get("RUNWAY_LEDGER") or os.path.join(REPO, "docs", "video", "runway_ledger.md")
KEY_NAMES = ("RUNWAYML_API_SECRET", "RUNWAY_API_KEY")
# Game-boy's approval of 2026-11-09 ($15 at $0.01 a credit), and the price list of the same day: credits a second, and the
# minimum a generation. Non-mp4 outputs add a surcharge a second.
CAP_CREDITS = 1500
RATES = {"aleph2": (28, 56)}
FORMAT_SURCHARGE = {"mp4": 0, "prores": 5, "png_sequence": 5}
# Aleph 2.0's input limits (docs: 2-30 s, at most 30 fps, at most 1080p).
MIN_SECONDS = 2.0
MAX_SECONDS = 30.0
MAX_FPS = 30.0
MAX_SHORT_SIDE = 1080
# The docs: expect no task update more often than every 5 s; poll with backoff.
POLL_FIRST_S = 10
POLL_STEP_S = 5
POLL_MAX_S = 30
POLL_TIMEOUT_S = 45 * 60
SUBMIT_TRIES_ON_429 = 3
SUBMIT_WAIT_ON_429_S = 30
LEDGER_HEADER = "| When (CST) | Job | Task | Input s | Estimate (credits) | Status | Charged (credits) | Counted total (credits) |"
LEDGER_RULE = "| --- | --- | --- | --- | --- | --- | --- | --- |"
TERMINAL = ("SUCCEEDED", "FAILED", "CANCELLED")


# --- The key ---------------------------------------------------------------------------------------------------------------

def env_files() -> list:
	"""`.env` candidates: this checkout's, then (in a linked worktree) the main checkout's."""
	out = [os.path.join(REPO, ".env")]
	dot_git = os.path.join(REPO, ".git")
	if os.path.isfile(dot_git):
		with open(dot_git) as f:
			first = f.readline().strip()
		if first.startswith("gitdir:"):
			# gitdir: <main>/.git/worktrees/<name>
			gitdir = first.split(":", 1)[1].strip()
			out.append(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(gitdir))), ".env"))
	return out


def read_key() -> str:
	for name in KEY_NAMES:
		if os.environ.get(name, "").strip():
			return os.environ[name].strip()
	for path in env_files():
		if not os.path.isfile(path):
			continue
		with open(path) as f:
			lines = f.read().splitlines()
		for name in KEY_NAMES:
			for line in lines:
				if line.startswith(name + "="):
					value = line.split("=", 1)[1].strip().strip('"').strip("'")
					if value:
						return value
	sys.exit("No Runway key: set RUNWAYML_API_SECRET (or RUNWAY_API_KEY) in the environment or the main checkout's .env")


# --- The API -----------------------------------------------------------------------------------------------------------------

class ApiError(Exception):
	"""An error answer from api.dev.runwayml.com: the request was refused, so it made no task."""

	def __init__(self, code: int, text: str):
		super().__init__(f"HTTP {code}: {text}")
		self.code = code


def api(key: str, method: str, path: str, body=None, timeout: int = 120) -> dict:
	"""One call to api.dev.runwayml.com, the only host that gets the key."""
	data = None if body is None else json.dumps(body).encode()
	request = urllib.request.Request(API + path, data=data, method=method)
	# Unredirected: urllib copies ordinary headers onto a redirect, so the key would follow one to another host.
	request.add_unredirected_header("Authorization", "Bearer " + key)
	request.add_header("X-Runway-Version", API_VERSION)
	if data is not None:
		request.add_header("Content-Type", "application/json")
	try:
		with urllib.request.urlopen(request, timeout=timeout) as response:
			raw = response.read()
	except urllib.error.HTTPError as e:
		text = e.read().decode(errors="replace").replace(key, "<key>")
		raise ApiError(e.code, clean(text, 600)) from None
	return json.loads(raw) if raw else {}


def api_retry(key: str, method: str, path: str, tries: int = 4) -> dict:
	"""A read (GET) that rides out a network hiccup or a 5xx; other errors go up."""
	for attempt in range(tries):
		try:
			return api(key, method, path)
		except ApiError as e:
			if e.code < 500 or attempt == tries - 1:
				raise
		except (urllib.error.URLError, socket.timeout, ConnectionError):
			if attempt == tries - 1:
				raise
		time.sleep(5 * (attempt + 1))
	return {}


def balance(key: str):
	"""The project's credit balance, or None when it can't be read."""
	try:
		return int(api_retry(key, "GET", "/v1/organization").get("creditBalance"))
	except (ApiError, urllib.error.URLError, socket.timeout, ConnectionError, TypeError, ValueError):
		return None


def multipart(fields: dict, filename: str, content_type: str, data: bytes) -> tuple:
	"""A multipart/form-data body: the storage's fields first, the file last (a presigned POST wants it last)."""
	boundary = "runway-restyle-" + uuid.uuid4().hex
	out = []
	for k, v in fields.items():
		out.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
	out.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\n'
		f"Content-Type: {content_type}\r\n\r\n".encode())
	out.append(data)
	out.append(f"\r\n--{boundary}--\r\n".encode())
	return b"".join(out), "multipart/form-data; boundary=" + boundary


def upload(key: str, path: str) -> str:
	"""An ephemeral upload (free): POST /v1/uploads, then the file to its storage URL without the key. Its runway:// URI."""
	name = os.path.basename(path)
	content_type = mimetypes.guess_type(name)[0] or "application/octet-stream"
	with open(path, "rb") as f:
		data = f.read()
	last = ""
	# The docs: a failed upload isn't retried; ask /v1/uploads for a new one.
	for _attempt in range(2):
		slot = api(key, "POST", "/v1/uploads", {"filename": name, "type": "ephemeral"})
		body, form_type = multipart(slot.get("fields", {}), name, content_type, data)
		request = urllib.request.Request(slot["uploadUrl"], data=body, method="POST", headers={"Content-Type": form_type})
		try:
			with urllib.request.urlopen(request, timeout=600) as response:
				if 200 <= response.status < 300:
					return slot["runwayUri"]
				last = f"HTTP {response.status}"
		except urllib.error.HTTPError as e:
			last = f"HTTP {e.code} {clean(e.read().decode(errors='replace'), 300)}"
		except (urllib.error.URLError, socket.timeout, ConnectionError) as e:
			last = clean(str(getattr(e, "reason", e)), 300)
	raise RuntimeError(f"the upload of {name} failed: {last}")


def download(url: str, out_path: str) -> int:
	"""Save an output URL (no key sent) to out_path; its size in bytes."""
	request = urllib.request.Request(url, headers={"User-Agent": "runway-restyle"})
	part = out_path + ".part"
	with urllib.request.urlopen(request, timeout=600) as response, open(part, "wb") as f:
		while True:
			chunk = response.read(1 << 20)
			if not chunk:
				break
			f.write(chunk)
	os.replace(part, out_path)
	return os.path.getsize(out_path)


def clean(text: str, limit: int) -> str:
	"""Text from a server, made safe for one ledger cell or log line."""
	return re.sub(r"\s+", " ", text.replace("|", "/"))[:limit]


# --- The ledger --------------------------------------------------------------------------------------------------------------

def ledger_lines() -> list:
	if not os.path.isfile(LEDGER):
		sys.exit(f"No ledger at {LEDGER}: it must exist, with its table header, before any spend")
	with open(LEDGER) as f:
		return f.read().split("\n")


def table_span(lines: list) -> tuple:
	"""The table's first row index and the index after its last row."""
	if LEDGER_HEADER not in lines:
		sys.exit(f"{LEDGER}: the table's header line is missing or changed; fix it by hand")
	head = lines.index(LEDGER_HEADER)
	if head + 1 >= len(lines) or lines[head + 1] != LEDGER_RULE:
		sys.exit(f"{LEDGER}: the table's rule line is missing or changed; fix it by hand")
	end = head + 2
	while end < len(lines) and lines[end].startswith("|"):
		end += 1
	return head + 2, end


def ledger_rows() -> list:
	"""The table's rows, each a list of its 8 cells."""
	lines = ledger_lines()
	start, end = table_span(lines)
	rows = []
	for line in lines[start:end]:
		cells = [c.strip() for c in line.strip().strip("|").split("|")]
		if len(cells) != 8:
			sys.exit(f"{LEDGER}: a row without 8 cells ({line[:80]}...); fix it by hand")
		rows.append(cells)
	return rows


def counted(cells: list) -> int:
	"""What a row counts toward the cap: its charge, else its estimate; 0 for a request answered with an error."""
	status = cells[5].upper()
	if status.startswith("REJECTED"):
		return 0
	if re.fullmatch(r"\d+", cells[6]):
		return int(cells[6])
	estimate = re.match(r"\d+", cells[4])
	# A row whose estimate can't be read blocks all spending until it's fixed by hand.
	return int(estimate.group(0)) if estimate else CAP_CREDITS + 1


def ledger_total(rows: list) -> int:
	return sum(counted(r) for r in rows)


def ledger_save(rows: list) -> None:
	"""Rewrite the table (running totals recomputed), keeping the text around it."""
	lines = ledger_lines()
	start, end = table_span(lines)
	table = []
	total = 0
	for cells in rows:
		total += counted(cells)
		cells = [clean(c, 400) for c in cells[:7]] + [str(total)]
		table.append("| " + " | ".join(cells) + " |")
	lines[start:end] = table
	tmp = LEDGER + ".tmp"
	with open(tmp, "w") as f:
		f.write("\n".join(lines))
	os.replace(tmp, LEDGER)


def save_row(row: list) -> None:
	"""Write one row: replace the row with the same When and Job cells, or add it at the end."""
	rows = ledger_rows()
	for i, cells in enumerate(rows):
		if cells[0] == row[0] and cells[1] == row[1]:
			rows[i] = row
			break
	else:
		rows.append(row)
	ledger_save(rows)


# --- A job -------------------------------------------------------------------------------------------------------------------

def probe(path: str) -> dict:
	"""The video's seconds, size and frame rate (ffprobe)."""
	cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
		"stream=width,height,r_frame_rate:format=duration", "-of", "json", path]
	info = json.loads(subprocess.run(cmd, check=True, capture_output=True, text=True).stdout)
	stream = info["streams"][0]
	num, den = stream["r_frame_rate"].split("/")
	return {"seconds": float(info["format"]["duration"]), "width": int(stream["width"]), "height": int(stream["height"]),
		"fps": float(num) / float(den)}


def estimate(job: dict, seconds: float) -> int:
	"""The job's credits by the price list, the seconds rounded up: at least the real charge."""
	rate, minimum = RATES[job.get("model", "aleph2")]
	rate += FORMAT_SURCHARGE[job.get("output_format", "mp4")]
	return max(minimum, rate * math.ceil(seconds - 1e-6))


def check(job: dict, base: str) -> tuple:
	"""The job's inputs checked against Aleph 2.0's limits; (video path, probe, keyframes with paths, estimate)."""
	name = job.get("name", "?")
	model = job.get("model", "aleph2")
	if model not in RATES:
		sys.exit(f"{name}: model {model!r} isn't priced in this tool (only {', '.join(RATES)})")
	if job.get("output_format", "mp4") not in FORMAT_SURCHARGE:
		sys.exit(f"{name}: output_format must be one of {', '.join(FORMAT_SURCHARGE)}")
	video = os.path.join(base, job["video"])
	if not os.path.isfile(video):
		sys.exit(f"{name}: no video {video}")
	info = probe(video)
	if not MIN_SECONDS <= info["seconds"] <= MAX_SECONDS:
		sys.exit(f"{name}: the video is {info['seconds']:.2f} s; Aleph 2.0 takes {MIN_SECONDS:g}-{MAX_SECONDS:g} s")
	if info["fps"] > MAX_FPS + 1e-3:
		sys.exit(f"{name}: the video is {info['fps']:.2f} fps; Aleph 2.0 takes at most {MAX_FPS:g}")
	if min(info["width"], info["height"]) > MAX_SHORT_SIDE:
		sys.exit(f"{name}: the video is {info['width']}x{info['height']}; Aleph 2.0 takes at most 1080p")
	frames = []
	for k in job.get("keyframes", []):
		path = os.path.join(base, k["image"])
		if not os.path.isfile(path):
			sys.exit(f"{name}: no keyframe image {path}")
		if not 0 <= float(k["seconds"]) <= info["seconds"]:
			sys.exit(f"{name}: keyframe {k['image']} at {k['seconds']} s is outside the video")
		frames.append({"path": path, "seconds": float(k["seconds"])})
	if len(frames) > 5:
		sys.exit(f"{name}: at most 5 keyframes")
	prompt = job.get("prompt", "")
	if len(prompt) > 1000:
		sys.exit(f"{name}: the prompt is {len(prompt)} characters; at most 1000")
	if not prompt and not frames:
		sys.exit(f"{name}: a prompt or a keyframe is needed")
	return video, info, frames, estimate(job, info["seconds"])


def out_paths(job: dict, base: str) -> tuple:
	out_dir = os.path.join(base, job.get("out", job["name"]))
	os.makedirs(out_dir, exist_ok=True)
	return out_dir, os.path.join(out_dir, job["name"] + "_task.json")


def run_job(job: dict, base: str, key: str, dry_run: bool) -> bool:
	name = job["name"]
	video, info, frames, est = check(job, base)
	rows = ledger_rows()
	total = ledger_total(rows)
	verdict = "fits" if total + est <= CAP_CREDITS else "REFUSED: it would pass the cap"
	print(f"{name}: {info['seconds']:.2f} s at {info['width']}x{info['height']} {info['fps']:g} fps, {len(frames)} keyframe(s); "
		f"estimate {est} credits; ledger {total} + {est} of {CAP_CREDITS}: {verdict}", flush=True)
	if total + est > CAP_CREDITS or dry_run:
		return total + est <= CAP_CREDITS
	before = balance(key)
	if before is not None and before < est:
		print(f"{name}: REFUSED: the project's balance is {before} credits, under the estimate", flush=True)
		return False
	# The uploads are free; the ledger row goes in after them and before the submit.
	video_uri = upload(key, video)
	key_uris = [{"uri": upload(key, f["path"]), "seconds": f["seconds"]} for f in frames]
	body = {"model": job.get("model", "aleph2"), "videoUri": video_uri}
	if job.get("prompt"):
		body["promptText"] = job["prompt"]
	if key_uris:
		body["keyframes"] = key_uris
	if "seed" in job:
		body["seed"] = int(job["seed"])
	if job.get("output_format", "mp4") != "mp4":
		body["outputFormat"] = job["output_format"]
	row = [time.strftime("%Y-%m-%d %H:%M:%S"), name, "-", f"{info['seconds']:.2f}", str(est), "SUBMITTING", "-", ""]
	save_row(row)
	created = None
	for attempt in range(SUBMIT_TRIES_ON_429):
		try:
			created = api(key, "POST", "/v1/video_to_video", body)
			break
		except ApiError as e:
			if e.code == 429 and attempt < SUBMIT_TRIES_ON_429 - 1:
				print(f"{name}: rate limited (429); trying again in {SUBMIT_WAIT_ON_429_S} s", flush=True)
				time.sleep(SUBMIT_WAIT_ON_429_S)
				continue
			row[5] = f"REJECTED {e}"
			save_row(row)
			print(f"{name}: {row[5]}", flush=True)
			return False
		except (urllib.error.URLError, socket.timeout, ConnectionError) as e:
			# No answer: a task may exist. The row keeps counting its estimate until it's checked by hand.
			row[5] = f"UNKNOWN: no answer to the submit ({clean(str(getattr(e, 'reason', e)), 120)}); check the portal"
			save_row(row)
			print(f"{name}: {row[5]}", flush=True)
			return False
	task_id = created["id"]
	row[2] = task_id
	row[5] = "PENDING"
	api_est = (created.get("estimatedCost") or {}).get("credits")
	if api_est is not None and math.ceil(api_est) > est:
		# Count the API's higher estimate; if that passes the cap, cancel the task at once.
		row[4] = str(math.ceil(api_est))
		if total + math.ceil(api_est) > CAP_CREDITS:
			try:
				api(key, "DELETE", f"/v1/tasks/{task_id}")
				row[5] = f"CANCELLED: the API's estimate ({api_est}) would pass the cap"
			except ApiError as e:
				row[5] = f"OVER THE CAP: the API's estimate ({api_est}); the cancel failed ({e})"
			save_row(row)
			print(f"{name}: {row[5]}", flush=True)
			return False
	save_row(row)
	print(f"{name}: submitted, task {task_id} (the API's estimate: {api_est} credits)", flush=True)
	return finish(job, base, key, row, before, body)


def finish(job: dict, base: str, key: str, row: list, before, body) -> bool:
	"""Poll the row's task to its end, download the output, and write the charge into the ledger."""
	name = job["name"]
	task_id = row[2]
	out_dir, record = out_paths(job, base)
	task = poll(key, task_id, name)
	status = task.get("status", "?")
	if status not in TERMINAL:
		row[5] = f"{status}: still running after {POLL_TIMEOUT_S // 60} min; resume with --poll {name}"
		save_row(row)
		print(f"{name}: {row[5]}", flush=True)
		return False
	charged = (task.get("cost") or {}).get("credits")
	after = balance(key)
	source = "the task's cost"
	if charged is None and before is not None and after is not None and before >= after:
		charged = before - after
		source = "the balance's change"
	saved = []
	if status == "SUCCEEDED":
		for i, url in enumerate(task.get("output") or []):
			ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower() or ".mp4"
			if ext not in (".mp4", ".mov", ".zip", ".png", ".jpg", ".webp"):
				ext = ".bin"
			path = os.path.join(out_dir, name + ("" if i == 0 else f"_{i}") + ext)
			size = download(url, path)
			saved.append({"path": os.path.relpath(path, REPO), "bytes": size})
		row[5] = "SUCCEEDED" if saved else "SUCCEEDED (no output listed)"
	else:
		row[5] = f"{status}: {task.get('failureCode', '')} {clean(str(task.get('failure', '')), 200)}".strip()
	if charged is not None:
		row[6] = str(int(math.ceil(charged)))
	save_row(row)
	with open(record, "w") as f:
		json.dump({"job": job, "request": body, "task": task, "charged": charged, "charged_from": source if charged is not None
			else None, "balance_before": before, "balance_after": after, "saved": saved}, f, indent=1)
	total = ledger_total(ledger_rows())
	print(f"{name}: {row[5]}; charged {row[6]} credits ({source if charged is not None else 'unknown: the estimate counts'}); "
		f"saved {', '.join(s['path'] for s in saved) or 'nothing'}; ledger {total} of {CAP_CREDITS}; balance {after}", flush=True)
	return status == "SUCCEEDED"


def poll(key: str, task_id: str, name: str) -> dict:
	"""GET the task, backing off, until it ends or POLL_TIMEOUT_S passes."""
	start = time.time()
	wait = POLL_FIRST_S
	last = ""
	while True:
		task = api_retry(key, "GET", f"/v1/tasks/{task_id}")
		status = task.get("status", "?")
		progress = task.get("progress")
		line = f"{name}: {status}" + (f" {progress:.0%}" if isinstance(progress, (int, float)) else "")
		if line != last:
			print(f"{line} ({time.time() - start:.0f} s)", flush=True)
			last = line
		if status in TERMINAL or time.time() - start > POLL_TIMEOUT_S:
			return task
		time.sleep(wait)
		wait = min(POLL_MAX_S, wait + POLL_STEP_S)


def resume(job: dict, base: str, key: str) -> bool:
	"""--poll: the job's newest ledger row with a task, polled and downloaded."""
	rows = [r for r in ledger_rows() if r[1] == job["name"] and re.fullmatch(r"[0-9a-fA-F-]{36}", r[2])]
	if not rows:
		sys.exit(f"{job['name']}: no ledger row with a task to poll")
	record = out_paths(job, base)[1]
	body = None
	if os.path.isfile(record):
		with open(record) as f:
			body = json.load(f).get("request")
	return finish(job, base, key, rows[-1], None, body)


def main() -> None:
	args = sys.argv[1:]
	if args == ["--balance"]:
		key = read_key()
		org = api_retry(key, "GET", "/v1/organization")
		tier = org.get("tier") or {}
		print(f"credit balance {org.get('creditBalance')} (${(org.get('creditBalance') or 0) / 100:.2f}); "
			f"monthly spend limit {tier.get('maxMonthlyCreditSpend')}; ledger {ledger_total(ledger_rows())} of {CAP_CREDITS}")
		return
	if not args or args[0].startswith("--"):
		sys.exit(__doc__)
	jobs_path = os.path.abspath(args[0])
	base = os.path.dirname(jobs_path)
	with open(jobs_path) as f:
		jobs = json.load(f)
	dry_run = "--dry-run" in args
	names = [a for a in args[1:] if not a.startswith("--")]
	if "--poll" in args:
		if len(names) != 1:
			sys.exit("--poll takes one job name")
		job = next((j for j in jobs if j["name"] == names[0]), None)
		if job is None:
			sys.exit(f"no job {names[0]} in {jobs_path}")
		sys.exit(0 if resume(job, base, read_key()) else 1)
	if names:
		missing = set(names) - {j["name"] for j in jobs}
		if missing:
			sys.exit(f"no job {', '.join(sorted(missing))} in {jobs_path}")
		jobs = [j for j in jobs if j["name"] in names]
	key = None if dry_run else read_key()
	ok = True
	for job in jobs:
		ok = run_job(job, base, key, dry_run) and ok
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
