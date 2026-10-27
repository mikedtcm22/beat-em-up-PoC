"""Tripo 3D (API v3): the one door through which this project spends Tripo credits.

Standard library only; run it as `python3 -I tools/pipeline/tripo.py <command> ...`.
Plan: docs/milestones/M4-plan.md Part A A10 and Part C section 5 step 5; the API as read in
docs/milestones/M4-codemap/toolchain-tripo-gemini.md. Base URL https://openapi.tripo3d.ai/v3 (the v2
API shuts down on 2026-10-31).

Commands (a command that creates a task needs --label, the brief's row such as T1):
	balance                          free: live balance, frozen, the ledger's spend, headroom to the stop and the floor
	ledger [--live]                  free: every ledger line summarised; --live also reconciles with the live balance
	task <task_id>                   free: status and progress of one task (no URLs are printed)
	upload <image>                   POST /files; prints the file_token (image: png, jpg, webp, at most 20 MB, at least 256 px)
	image-to-model --label L --input <ref> [--opt k=v]... [--options file.json]
	multiview --label L --front <ref> [--left <ref>] [--back <ref>] [--right <ref>] [--opt k=v]...
	rig-check --label L --input task:<id>      free
	rig --label L --input task:<id> [--opt k=v]...   defaults: model v3.0-20260909, rig_type biped, spec unity, out_format glb
	texture --label L --input task:<id> [--front/--left/--back/--right <ref>] [--text "..."] [--opt k=v]...
	wait <task_id> [--out-dir D]     resume a task the ledger says was created but not finished
	--self-test                      offline: prices, guards, lifecycle on a mock service, the key grep
A <ref> is `task:<id>`, `file:<token>`, `url:https://...` or a local image path (uploaded first).
Every task command takes --dry-run: it prints the request body and the expected cost, touches no network
(--live adds one free balance call) and writes nothing. Task commands create the task, poll it, download every
output at once (the URLs die in 5 minutes) with no Authorization header into a NEW or EMPTY folder (default
assets/source/_cache/tripo/<task_id>/), then append to the ledger. --opt values are JSON where they parse
(true, 20000) and strings otherwise; --options names a JSON object of the same keys. Unknown keys are refused.

The key: TRIPO_API_KEY from the environment or the repo's `.env` (a linked worktree falls back to the main
checkout's `.env`). It is only ever sent in the Authorization header; it is never printed, logged, put in a URL
or written anywhere: every message passes through redact(), which also masks GEMINI_API_KEY.

Spending (tripo_prices.json, no override flag): before each task the live balance is read and the task refused if
balance - frozen - expected < balance_floor (700), or if max(the ledger's M4 sum, start_balance - balance) +
expected > ledger_stop (750). A task that is not priced in the table is refused. A POST that creates a task is
never retried (a retry could double-spend), except on HTTP 429 where nothing was created.

LEDGER assets/source/tripo_ledger.jsonl: append-only, one compact JSON object per line, never edited. Every line
has "v" (1), "event", "ts" (UTC, ISO 8601, seconds), "milestone" (policy.milestone). Events:
	"created"   a task was accepted: "task_id", "call" (image-to-model, multiview, rig-check, rig, texture),
	            "endpoint", "label", "options" (the request body, with file tokens and task ids, never a key),
	            "expected_credits", "balance_before", "frozen_before". Written at once, so a crash after the
	            POST still counts against the 750 stop (the guard counts expected_credits until "finished").
	"finished"  the task ended: the fields of "created" plus "status" (success, failed, cancelled, banned,
	            expired, timeout), "credits_consumed" (the task's own number, a float; if the task omits it the
	            balance delta, with "credits_source": "balance_delta"), "balance_delta" (before - after),
	            "balance_after", "frozen_after", "duration_s", "result" (the small scalar outputs, e.g.
	            riggable, rig_type, normalize_scale; never a URL), "files" ([{"path" (repo-relative), "role",
	            "bytes", "sha256"}]), "error" (null or a redacted message).
	"upload"    a file went to POST /files: "path" (repo-relative), "sha256", "file_token".
The ledger's spend is the sum of "credits_consumed" over the "finished" lines, plus "expected_credits" of every
"created" line that has no "finished" line yet. Rejected raw outputs live in assets/source/_cache/ (git-ignored);
the ledger keeps their task ids and costs.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Any, Callable, Dict, List, Optional, Tuple

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
BASE = "https://openapi.tripo3d.ai/v3"
PRICES_PATH = os.path.join(HERE, "tripo_prices.json")
LEDGER_REL = "assets/source/tripo_ledger.jsonl"
CACHE_REL = "assets/source/_cache/tripo"
USER_AGENT = "beat-em-up-poc/1.0 (tripo.py)"
ID_RE = re.compile(r"^[A-Za-z0-9_-]{6,64}$")
LABEL_RE = re.compile(r"^[A-Za-z0-9_.-]{1,40}$")
TERMINAL_BAD = ("failed", "cancelled", "banned", "expired")
MAX_DOWNLOAD_BYTES = 200 * 1024 * 1024
MAX_IMAGE_BYTES = 20 * 1024 * 1024
MIN_IMAGE_PX = 256
DOWNLOAD_EXTS = (".glb", ".gltf", ".fbx", ".obj", ".stl", ".png", ".jpg", ".jpeg", ".webp")
IMAGE_MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
# output key -> (role, default extension). Only these keys are downloaded; a stray URL is never fetched.
OUTPUT_ROLES = {
	"model_url": ("MODEL", ".glb"),
	"rendered_image_url": ("preview", ".webp"),
	"uv_render_url": ("uv", ".png"),
	"generated_image_url": ("image", ".png"),
	"front_view_url": ("view_front", ".png"),
	"left_view_url": ("view_left", ".png"),
	"back_view_url": ("view_back", ".png"),
	"right_view_url": ("view_right", ".png"),
}
MODEL_ROLE_BY_CALL = {"image-to-model": "gen", "multiview": "gen", "rig": "rig", "texture": "tex"}


class TripoError(Exception):
	"""Any refusal or failure; the message is already free of secrets."""

	def __init__(self, message: str, code: int = 1) -> None:
		super().__init__(message)
		self.code = code


# --------------------------------------------------------------------------- secrets

_SECRETS: List[str] = []


def env_files() -> List[str]:
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


def read_env(name: str) -> Optional[str]:
	"""A value from the environment, else from the first `.env` that has it; None if unset. Never printed."""
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


def load_secrets() -> None:
	"""Remember every key's value (in memory only) so redact() can mask it."""
	for name in ("TRIPO_API_KEY", "GEMINI_API_KEY"):
		value = read_env(name)
		if value and value not in _SECRETS:
			_SECRETS.append(value)


def redact(text: Any) -> str:
	out = str(text)
	for secret in _SECRETS:
		if secret:
			out = out.replace(secret, "<key>")
	return out


def now_utc() -> str:
	return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_file(path: str) -> str:
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


# --------------------------------------------------------------------------- prices and options

def load_prices(path: str = PRICES_PATH) -> Dict[str, Any]:
	with open(path) as f:
		prices = json.load(f)
	for key in ("policy", "generation", "texture", "rig_check", "rig", "upload"):
		if key not in prices:
			raise TripoError("tripo_prices.json is missing '%s'" % key)
	return prices


def _enums(prices: Dict[str, Any]) -> Dict[str, List[str]]:
	h, p = prices["generation"]["h"], prices["generation"]["p"]
	return {
		"model": h["models"] + p["models"],
		"texture_quality": ["fast", "standard", "detailed", "extreme"],
		"texture_version": ["v3.5-20260815", "v3.0-20250812", "v2.5-20250123"],
		"texture_alignment": ["original_image", "geometry"],
		"orientation": ["default", "align_image"],
		"geometry_quality": ["standard", "detailed"],
		"compress": ["geometry"],
		"export_orientation": ["+x", "-x", "+y", "-y"],
	}


def option_schema(call: str, prices: Dict[str, Any]) -> Dict[str, Tuple[str, Optional[List[str]]]]:
	"""Allowed request keys per call: name -> (type tag b/i/s, enum or None)."""
	e = _enums(prices)
	gen = {
		"model": ("s", e["model"]), "enable_image_autofix": ("b", None), "texture_alignment": ("s", e["texture_alignment"]),
		"orientation": ("s", e["orientation"]), "face_limit": ("i", None), "texture": ("b", None), "pbr": ("b", None),
		"texture_seed": ("i", None), "texture_quality": ("s", e["texture_quality"]),
		"texture_version": ("s", e["texture_version"]), "delight": ("b", None),
		"geometry_quality": ("s", e["geometry_quality"]), "auto_size": ("b", None), "quad": ("b", None),
		"smart_low_poly": ("b", None), "generate_parts": ("b", None), "compress": ("s", e["compress"]),
		"export_orientation": ("s", e["export_orientation"]), "model_seed": ("i", None), "export_uv": ("b", None),
	}
	if call in ("image-to-model", "multiview"):
		return gen
	if call == "rig":
		return {
			"model": ("s", ["v1.0-20240301", "v2.5-20260210", "v3.0-20260909"]),
			"rig_type": ("s", ["biped", "quadruped", "hexapod", "octopod", "avian", "serpentine", "aquatic", "others"]),
			"spec": ("s", ["tripo", "mixamo", "actorcore", "unity", "unreal", "vrm"]),
			"out_format": ("s", ["glb", "fbx"]),
		}
	if call == "texture":
		return {
			"model": ("s", e["texture_version"]), "pbr": ("b", None), "texture_seed": ("i", None),
			"texture_alignment": ("s", e["texture_alignment"]), "texture_quality": ("s", e["texture_quality"]),
			"bake": ("b", None), "delight": ("b", None), "compress": ("s", e["compress"]),
		}
	return {}


# P-series (P1, P2) takes this subset of the generation keys.
P_SERIES_KEYS = ("model", "model_seed", "face_limit", "texture", "pbr", "texture_quality", "texture_version", "delight",
	"auto_size", "export_uv", "export_orientation", "orientation", "texture_alignment", "quad")
V3_ONLY_KEYS = ("texture_quality", "geometry_quality", "auto_size", "quad", "smart_low_poly", "generate_parts", "compress")


def validate_options(call: str, options: Dict[str, Any], prices: Dict[str, Any]) -> List[str]:
	"""Refuse unknown keys, wrong types, values outside an enum and combinations the API rejects. Returns warnings."""
	schema = option_schema(call, prices)
	warnings: List[str] = []
	for key, value in options.items():
		if key not in schema:
			raise TripoError("option '%s' is not a known %s option (known: %s)" % (key, call, ", ".join(sorted(schema))))
		tag, enum = schema[key]
		if tag == "b" and not isinstance(value, bool):
			raise TripoError("option '%s' must be true or false, got %r" % (key, value))
		if tag == "i" and (isinstance(value, bool) or not isinstance(value, int)):
			raise TripoError("option '%s' must be an integer, got %r" % (key, value))
		if tag == "s" and not isinstance(value, str):
			raise TripoError("option '%s' must be a string, got %r" % (key, value))
		if enum is not None and value not in enum:
			raise TripoError("option '%s' must be one of %s, got %r" % (key, enum, value))
	if call in ("image-to-model", "multiview"):
		h, p = prices["generation"]["h"], prices["generation"]["p"]
		model = options.get("model", h["default_model"])
		if model in p["models"]:
			for key in options:
				if key not in P_SERIES_KEYS:
					raise TripoError("option '%s' is not available on the P series (%s)" % (key, model))
			if options.get("quad") and model != "P2-20260801":
				raise TripoError("quad is P2 only")
		if model == "v2.5-20250123":
			for key in V3_ONLY_KEYS:
				if key in options:
					raise TripoError("option '%s' needs model v3.0 or newer, not %s" % (key, model))
		if options.get("texture_quality") == "fast" and options.get("texture_version") != "v3.5-20260815":
			raise TripoError("texture_quality=fast needs texture_version=v3.5-20260815 (anything else returns 1004)")
		if options.get("generate_parts"):
			if options.get("texture", True) or options.get("pbr", False):
				raise TripoError("generate_parts needs texture=false and pbr=false (the API returns 1004 otherwise)")
		if options.get("pbr") and options.get("texture") is False:
			warnings.append("pbr=true forces texture on; priced as textured")
		if options.get("delight") and options.get("texture_version") != "v3.5-20260815":
			warnings.append("delight is read only by texture v3.5-20260815; this version ignores it")
		if "export_orientation" in options:
			warnings.append("export_orientation breaks later rig/texture steps unless the model is only converted; leave it unset")
		if options.get("compress"):
			warnings.append("compress=geometry (meshopt) is unproven in Blender and Godot here; avoid it")
	if call == "rig":
		if options.get("spec", "tripo") in ("unity", "unreal", "vrm") and options.get("model") == "v1.0-20240301":
			raise TripoError("spec unity/unreal/vrm fails on rig model v1.0; use v3.0-20260909 or v2.5-20260210")
	if call == "texture" and options.get("texture_quality") == "fast" and options.get("model") != "v3.5-20260815":
		raise TripoError("texture_quality=fast needs model=v3.5-20260815 on /models/texture")
	return warnings


def expected_cost(call: str, body: Dict[str, Any], prices: Dict[str, Any]) -> Tuple[float, List[str]]:
	"""Credits the table charges for this request, and the notes (price basis, unverified assumptions)."""
	notes: List[str] = []
	if call in ("image-to-model", "multiview"):
		gen = prices["generation"]
		series = "p" if body.get("model", gen["h"]["default_model"]) in gen["p"]["models"] else "h"
		table = gen[series]
		textured = body.get("texture", True) or body.get("pbr", False)
		tier = "no_texture"
		if textured:
			tier = gen["quality_alias"].get(body.get("texture_quality", "standard"), body.get("texture_quality", "standard"))
		cost = float(table[tier])
		notes.append("%s series, %s: %s" % (series.upper(), tier, cost))
		adds = table["add"]
		for flag, key in (("quad", "quad"), ("smart_low_poly", "smart_low_poly"), ("generate_parts", "generate_parts")):
			if body.get(flag) and key in adds:
				cost += adds[key]
				notes.append("+%s %s" % (adds[key], flag))
		if body.get("geometry_quality") == "detailed" and "geometry_quality_detailed" in adds:
			cost += adds["geometry_quality_detailed"]
			notes.append("+%s geometry_quality=detailed" % adds["geometry_quality_detailed"])
		call_key = "generation"
	elif call == "texture":
		tex = prices["texture"]
		tier = tex["quality_alias"].get(body.get("texture_quality", "standard"), body.get("texture_quality", "standard"))
		cost = float(tex[tier])
		notes.append("texture %s: %s" % (tier, cost))
		call_key = "texture"
	elif call == "rig":
		cost = float(prices["rig"])
		call_key = "rig"
	elif call == "rig-check":
		cost = float(prices["rig_check"])
		call_key = "rig_check"
	else:
		raise TripoError("no price for '%s'; refusing to spend" % call)
	for entry in prices.get("unverified", []):
		if entry["call"] == call_key and all(body.get(k) == v for k, v in entry["when"].items()):
			notes.append("UNVERIFIED PRICE: " + entry["note"])
	return cost, notes


# --------------------------------------------------------------------------- files, images

def image_size(path: str) -> Optional[Tuple[int, int]]:
	"""(width, height) of a PNG or JPEG from its header; None for WebP or anything unreadable."""
	with open(path, "rb") as f:
		head = f.read(32)
		if head[:8] == b"\x89PNG\r\n\x1a\n" and head[12:16] == b"IHDR":
			return struct.unpack(">II", head[16:24])
		if head[:2] == b"\xff\xd8":
			f.seek(2)
			while True:
				marker = f.read(2)
				if len(marker) < 2 or marker[0] != 0xFF:
					return None
				if marker[1] in (0xD8, 0x01) or 0xD0 <= marker[1] <= 0xD7:
					continue
				size = f.read(2)
				if len(size) < 2:
					return None
				length = struct.unpack(">H", size)[0]
				if 0xC0 <= marker[1] <= 0xCF and marker[1] not in (0xC4, 0xC8, 0xCC):
					data = f.read(5)
					if len(data) < 5:
						return None
					height, width = struct.unpack(">HH", data[1:5])
					return width, height
				f.seek(length - 2, 1)
	return None


def check_image(path: str) -> str:
	ext = os.path.splitext(path)[1].lower()
	if ext not in IMAGE_MIME:
		raise TripoError("%s: only png, jpg and webp images can be uploaded" % path)
	size = os.path.getsize(path)
	if size == 0 or size > MAX_IMAGE_BYTES:
		raise TripoError("%s: %d bytes (the limit is 20 MB)" % (path, size))
	dims = image_size(path)
	if dims is not None and min(dims) < MIN_IMAGE_PX:
		raise TripoError("%s: %dx%d, Tripo needs at least %d px" % (path, dims[0], dims[1], MIN_IMAGE_PX))
	return IMAGE_MIME[ext]


def multipart(field: str, filename: str, mime: str, data: bytes) -> Tuple[bytes, str]:
	boundary = "----tripo" + uuid.uuid4().hex
	head = ('--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
		% (boundary, field, filename.replace('"', ""), mime)).encode()
	return head + data + ("\r\n--%s--\r\n" % boundary).encode(), "multipart/form-data; boundary=" + boundary


class _HttpsOnlyRedirect(urllib.request.HTTPRedirectHandler):
	def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
		if not newurl.lower().startswith("https://"):
			raise urllib.error.URLError("refusing a redirect to a non-https URL")
		return super().redirect_request(req, fp, code, msg, headers, newurl)


class Http:
	"""The only code that touches the network. api() carries the key; download() never does."""

	def __init__(self, key: str, base: str = BASE) -> None:
		self._key = key
		self.base = base

	def api(self, method: str, path: str, body: Optional[Dict[str, Any]] = None,
			upload: Optional[Tuple[str, str, bytes]] = None) -> Dict[str, Any]:
		headers = {"Authorization": "Bearer " + self._key, "User-Agent": USER_AGENT}
		data: Optional[bytes] = None
		if upload is not None:
			data, headers["Content-Type"] = multipart("file", upload[0], upload[1], upload[2])
		elif body is not None:
			data = json.dumps(body).encode()
			headers["Content-Type"] = "application/json"
		creates = method == "POST"
		attempts = 6 if creates else 4
		for attempt in range(attempts):
			request = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
			try:
				with urllib.request.urlopen(request, timeout=120) as response:
					payload = json.load(response)
			except urllib.error.HTTPError as e:
				text = redact(e.read().decode(errors="replace"))[:400]
				if e.code == 429 and attempt < attempts - 1:
					time.sleep(min(int(e.headers.get("Retry-After", 2 ** attempt)), 60))
					continue
				if e.code >= 500 and not creates and attempt < attempts - 1:
					time.sleep(2 ** attempt)
					continue
				hint = " The task may have been created: check `balance` before running it again." if creates and e.code >= 500 else ""
				raise TripoError("HTTP %d on %s %s: %s%s" % (e.code, method, path, text, hint), 2)
			except (urllib.error.URLError, TimeoutError, OSError) as e:
				if creates:
					raise TripoError("%s %s failed in flight (%s). The request may have been received: check `balance` and "
						"the live usage before running it again." % (method, path, redact(e)), 2)
				if attempt < attempts - 1:
					time.sleep(2 ** attempt)
					continue
				raise TripoError("%s %s: %s" % (method, path, redact(e)), 2)
			if payload.get("code", 0) != 0:
				raise TripoError("API error %s on %s %s: %s" % (payload.get("code"), method, path,
					redact(payload.get("message", ""))[:300]), 2)
			return payload
		raise TripoError("%s %s: out of retries" % (method, path), 2)

	def download(self, url: str, dest: str, max_bytes: int = MAX_DOWNLOAD_BYTES) -> Tuple[int, str]:
		"""Fetch a signed URL with no Authorization header. Returns (bytes, sha256)."""
		parts = urllib.parse.urlsplit(url)
		if parts.scheme != "https" or not parts.hostname or parts.username or parts.password:
			raise TripoError("refusing to download from a non-https or credentialed URL")
		opener = urllib.request.build_opener(_HttpsOnlyRedirect)
		request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
		h = hashlib.sha256()
		total = 0
		try:
			with opener.open(request, timeout=300) as response, open(dest, "wb") as f:
				for chunk in iter(lambda: response.read(1 << 20), b""):
					total += len(chunk)
					if total > max_bytes:
						raise TripoError("download passed %d bytes; stopped" % max_bytes)
					h.update(chunk)
					f.write(chunk)
		except (urllib.error.URLError, OSError) as e:
			raise TripoError("download failed: %s" % redact(e), 2)
		return total, h.hexdigest()


# --------------------------------------------------------------------------- ledger

class Ledger:
	"""The append-only JSONL file; see the module docstring for the line schema."""

	def __init__(self, path: str, milestone: str) -> None:
		self.path = path
		self.milestone = milestone

	def lines(self) -> List[Dict[str, Any]]:
		out: List[Dict[str, Any]] = []
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
					raise TripoError("%s line %d is not JSON; fix it by hand before spending" % (self.path, number))
		return out

	def append(self, record: Dict[str, Any]) -> None:
		record = dict(record)
		record.setdefault("v", 1)
		record.setdefault("ts", now_utc())
		record.setdefault("milestone", self.milestone)
		text = redact(json.dumps(record, separators=(",", ":")))
		fd = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
		try:
			os.write(fd, (text + "\n").encode())
			os.fsync(fd)
		finally:
			os.close(fd)

	def tasks(self) -> Dict[str, Dict[str, Any]]:
		"""task_id -> {"created": line, "finished": line or None}, for this milestone."""
		out: Dict[str, Dict[str, Any]] = {}
		for line in self.lines():
			if line.get("milestone") != self.milestone or line.get("event") not in ("created", "finished"):
				continue
			entry = out.setdefault(line["task_id"], {"created": None, "finished": None})
			entry[line["event"]] = line
		return out

	def spent(self) -> float:
		total = 0.0
		for entry in self.tasks().values():
			if entry["finished"] is not None:
				total += float(entry["finished"].get("credits_consumed") or 0.0)
			elif entry["created"] is not None:
				total += float(entry["created"].get("expected_credits") or 0.0)
		return round(total, 2)


# --------------------------------------------------------------------------- the service

def parse_ref(value: str) -> Tuple[str, str]:
	"""`task:<id>`, `file:<token>`, `url:<https url>` or a local path -> (kind, value)."""
	for kind in ("task", "file", "url"):
		if value.startswith(kind + ":"):
			rest = value[len(kind) + 1:]
			if kind == "url":
				if not rest.startswith("https://"):
					raise TripoError("url: refs must be https")
			elif not ID_RE.match(rest):
				raise TripoError("'%s' is not a valid %s id" % (rest, kind))
			return kind, rest
	return "path", value


class Tripo:
	def __init__(self, http: Any, prices: Dict[str, Any], ledger: Ledger, repo: str = REPO,
			sleep: Callable[[float], None] = time.sleep, out: Any = None) -> None:
		self.http = http
		self.prices = prices
		self.ledger = ledger
		self.repo = os.path.realpath(repo)
		self.sleep = sleep
		self.out = out if out is not None else sys.stdout
		self.policy = prices["policy"]
		self._upload_noted = False

	def say(self, text: str = "") -> None:
		print(redact(text), file=self.out)

	# --- free calls

	def balance(self) -> Tuple[float, float]:
		data = self.http.api("GET", "/account/balance")["data"]
		return float(data["balance"]), float(data.get("frozen", 0.0))

	def upload(self, path: str, record: bool = True) -> str:
		mime = check_image(path)
		with open(path, "rb") as f:
			data = f.read()
		if not self._upload_noted:
			self._upload_noted = True
			for entry in self.prices.get("unverified", []):
				if entry["call"] == "upload":
					self.say("NOTE: " + entry["note"])
		token = self.http.api("POST", "/files", upload=(os.path.basename(path), mime, data))["data"]["file_token"]
		if not ID_RE.match(token):
			raise TripoError("the upload returned an unexpected file_token")
		if record:
			self.ledger.append({"event": "upload", "path": self.rel(path), "sha256": hashlib.sha256(data).hexdigest(),
				"file_token": token})
		return token

	def rel(self, path: str) -> str:
		return os.path.relpath(os.path.realpath(path), self.repo)

	# --- planning (offline)

	def resolve(self, ref: str, dry: bool, want_image: bool = True) -> str:
		kind, value = parse_ref(ref)
		if kind in ("task", "file", "url"):
			return value
		if not os.path.isfile(value):
			raise TripoError("%s is not a file" % value)
		if dry:
			check_image(value)
			return "file_<upload of %s, sha256 %s, at run time>" % (os.path.basename(value), sha256_file(value)[:8])
		return self.upload(value)

	def plan(self, call: str, args: Dict[str, Any], dry: bool) -> Dict[str, Any]:
		"""Build {call, endpoint, body, expected, notes, warnings} for one task. Uploads only when not dry."""
		options: Dict[str, Any] = dict(args.get("options") or {})
		if call == "rig":
			defaults = {"model": "v3.0-20260909", "rig_type": "biped", "spec": "unity", "out_format": "glb"}
			options = dict(defaults, **options)
		warnings = validate_options(call, options, self.prices)
		body: Dict[str, Any] = {}
		if call == "image-to-model":
			body["input"] = self.resolve(args["input"], dry)
			endpoint = "/generation/image-to-model"
		elif call == "multiview":
			views = [{view: self.resolve(args[view], dry)} for view in ("front", "left", "back", "right") if args.get(view)]
			if not args.get("front") or len(views) < 2:
				raise TripoError("multiview needs --front and at least one more view")
			body["inputs"] = views
			endpoint = "/generation/multiview-to-model"
		elif call == "rig-check":
			kind, value = parse_ref(args["input"])
			if kind != "task":
				raise TripoError("rig-check takes task:<id> (a generation task)")
			body["input"] = value
			endpoint = "/animations/rig-check"
		elif call == "rig":
			kind, value = parse_ref(args["input"])
			if kind != "task":
				raise TripoError("rig takes task:<id> (a generation task)")
			body["input"] = value
			endpoint = "/animations/rig"
		elif call == "texture":
			kind, value = parse_ref(args["input"])
			if kind != "task":
				raise TripoError("texture takes task:<id> (a generation task)")
			body["input"] = value
			endpoint = "/models/texture"
			views = [{view: self.resolve(args[view], dry)} for view in ("front", "left", "back", "right") if args.get(view)]
			if views and args.get("text"):
				raise TripoError("texture_prompt takes either views or --text, not both")
			if views:
				if not args.get("front") or len(views) < 2:
					raise TripoError("texture views need --front and at least one more")
				body["texture_prompt"] = {"images": views}
			elif args.get("text"):
				body["texture_prompt"] = {"text": args["text"]}
		else:
			raise TripoError("unknown call %s" % call)
		body.update(options)
		cost, notes = expected_cost(call, body, self.prices)
		return {"call": call, "endpoint": endpoint, "body": body, "expected": cost, "notes": notes, "warnings": warnings}

	def check_out_dir(self, out_dir: Optional[str]) -> Optional[str]:
		"""A given --out-dir must be inside the repo and new or empty; checked BEFORE any spend."""
		if out_dir is None:
			return None
		path = os.path.realpath(out_dir)
		if os.path.commonpath([path, self.repo]) != self.repo:
			raise TripoError("--out-dir must be inside the repo (%s)" % self.repo)
		if os.path.exists(path) and (not os.path.isdir(path) or os.listdir(path)):
			raise TripoError("--out-dir %s exists and is not empty; a download goes into a new empty folder" % out_dir)
		return path

	# --- the spending guard

	def guard(self, expected: float) -> Dict[str, float]:
		balance, frozen = self.balance()
		available = balance - frozen
		floor, stop, start = float(self.policy["balance_floor"]), float(self.policy["ledger_stop"]), float(self.policy["start_balance"])
		ledger_spent = self.ledger.spent()
		account_spent = round(start - balance, 2)
		effective = max(ledger_spent, account_spent)
		if available - expected < floor:
			raise TripoError("REFUSED: balance %.2f (frozen %.2f) minus %.2f expected would fall below the floor %.0f"
				% (balance, frozen, expected, floor), 3)
		if effective + expected > stop:
			raise TripoError("REFUSED: spend so far %.2f (ledger %.2f, account %.2f) plus %.2f expected would pass the stop %.0f; "
				"the lead asks Game-boy" % (effective, ledger_spent, account_spent, expected, stop), 3)
		if account_spent - ledger_spent > 0.5:
			self.say("WARNING: the account shows %.2f credits spent but the ledger accounts for %.2f (spend outside this ledger)."
				% (account_spent, ledger_spent))
		return {"balance": balance, "frozen": frozen, "ledger_spent": ledger_spent, "account_spent": account_spent}

	# --- dry run

	def dry_run(self, plan: Dict[str, Any], live: bool) -> None:
		self.say("DRY RUN %s: no task is created, nothing is written" % plan["call"])
		self.say("POST %s%s" % (BASE, plan["endpoint"]))
		self.say(json.dumps(plan["body"], indent=2))
		self.say("expected credits: %s" % plan["expected"])
		for note in plan["notes"]:
			self.say("  " + note)
		for warning in plan["warnings"]:
			self.say("WARNING: " + warning)
		spent = self.ledger.spent()
		stop = float(self.policy["ledger_stop"])
		verdict = "ok" if spent + plan["expected"] <= stop else "WOULD BE REFUSED"
		self.say("ledger: %.2f spent + %.2f = %.2f against the stop %.0f: %s" % (spent, plan["expected"], spent + plan["expected"], stop, verdict))
		if live:
			balance, frozen = self.balance()
			floor = float(self.policy["balance_floor"])
			ok = "ok" if balance - frozen - plan["expected"] >= floor else "WOULD BE REFUSED"
			self.say("live balance %.2f (frozen %.2f), floor %.0f: %s" % (balance, frozen, floor, ok))
		else:
			self.say("the floor %.0f is checked against the live balance when the task runs (add --live to check now)" % float(self.policy["balance_floor"]))

	# --- running a task

	def run(self, plan: Dict[str, Any], label: str, out_dir: Optional[str], poll_every: float, timeout: float) -> Dict[str, Any]:
		if not LABEL_RE.match(label or ""):
			raise TripoError("--label is required (the brief's row, e.g. T1)")
		out_path = self.check_out_dir(out_dir)
		for note in plan["notes"]:
			if note.startswith("UNVERIFIED"):
				self.say("NOTE: " + note)
		for warning in plan["warnings"]:
			self.say("WARNING: " + warning)
		state = self.guard(plan["expected"])
		created = self.http.api("POST", plan["endpoint"], body=plan["body"])["data"]
		task_id = created["task_id"]
		if not ID_RE.match(task_id):
			raise TripoError("the API returned an unexpected task_id")
		self.ledger.append({"event": "created", "task_id": task_id, "call": plan["call"], "endpoint": plan["endpoint"],
			"label": label, "options": plan["body"], "expected_credits": plan["expected"],
			"balance_before": state["balance"], "frozen_before": state["frozen"]})
		self.say("%s %s created (%s, expected %s credits)" % (plan["call"], task_id, label, plan["expected"]))
		return self.finish(task_id, out_path, poll_every, timeout)

	def finish(self, task_id: str, out_path: Optional[str], poll_every: float, timeout: float) -> Dict[str, Any]:
		entry = self.ledger.tasks().get(task_id)
		if entry is None or entry["created"] is None:
			raise TripoError("task %s is not in the ledger; refusing to handle a task created outside it" % task_id)
		if entry["finished"] is not None:
			raise TripoError("task %s is already finished in the ledger (%s)" % (task_id, entry["finished"]["status"]))
		created = entry["created"]
		started = time.time()
		task = None
		status = "timeout"
		while time.time() - started < timeout:
			task = self.http.api("GET", "/tasks/" + task_id)["data"]
			status = task.get("status", "")
			if status == "success" or status in TERMINAL_BAD:
				break
			self.sleep(poll_every)
		else:
			status = "timeout"
		duration = round(time.time() - started, 1)
		files: List[Dict[str, Any]] = []
		result: Dict[str, Any] = {}
		error: Optional[str] = None
		if status == "timeout":
			self.say("task %s is not done after %.0fs and its ledger line stays 'created'. Resume it with: "
				"python3 -I tools/pipeline/tripo.py wait %s" % (task_id, timeout, task_id))
			raise TripoError("timeout waiting for %s" % task_id, 5)
		if status == "success":
			files, result = self.download_outputs(task_id, created["call"], task.get("output") or {}, out_path)
		else:
			error = redact("%s %s" % (task.get("error_code"), task.get("error_message")))[:300]
		balance_after, frozen_after = self.balance()
		if frozen_after > 0.001:
			self.sleep(2)
			balance_after, frozen_after = self.balance()
		delta = round(float(created["balance_before"]) - balance_after, 2)
		consumed = task.get("credits_consumed")
		source = "task"
		if consumed is None:
			consumed, source = delta, "balance_delta"
		record = {"event": "finished", "task_id": task_id, "call": created["call"], "endpoint": created["endpoint"],
			"label": created["label"], "options": created["options"], "expected_credits": created["expected_credits"],
			"status": status, "credits_consumed": float(consumed), "credits_source": source, "balance_delta": delta,
			"balance_before": created["balance_before"], "balance_after": balance_after, "frozen_after": frozen_after,
			"duration_s": duration, "result": result, "files": files, "error": error}
		self.ledger.append(record)
		self.say("%s %s: %s, %.2f credits (expected %s), balance %.2f -> %.2f" % (created["call"], task_id, status, float(consumed),
			created["expected_credits"], float(created["balance_before"]), balance_after))
		for f in files:
			self.say("  %s  %s (%d bytes)" % (f["role"], f["path"], f["bytes"]))
		if error:
			self.say("  error: " + error)
			raise TripoError("task %s %s" % (task_id, status), 4)
		return record

	def download_outputs(self, task_id: str, call: str, output: Dict[str, Any], out_path: Optional[str]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
		result: Dict[str, Any] = {}
		urls: List[Tuple[str, str, str]] = []
		for key, value in output.items():
			if key in OUTPUT_ROLES and isinstance(value, str) and value:
				role, ext = OUTPUT_ROLES[key]
				urls.append((MODEL_ROLE_BY_CALL.get(call, "model") if role == "MODEL" else role, ext, value))
			elif key == "model_urls" and isinstance(value, list):
				for i, item in enumerate(value):
					if isinstance(item, str):
						urls.append(("model_%d" % i, ".glb", item))
			elif isinstance(value, (bool, int, float)) or (isinstance(value, str) and not value.startswith(("http://", "https://"))):
				result[key] = value
		files: List[Dict[str, Any]] = []
		if not urls:
			return files, result
		folder = out_path or os.path.join(self.repo, CACHE_REL, task_id)
		if os.path.exists(folder) and os.listdir(folder):
			raise TripoError("%s is not empty; the task %s was created, run `wait` with another --out-dir" % (folder, task_id))
		os.makedirs(folder, exist_ok=True)
		prefix = re.sub(r"^task_", "", task_id)[:8]
		for role, default_ext, url in urls:
			ext = os.path.splitext(urllib.parse.urlsplit(url).path)[1].lower()
			if ext not in DOWNLOAD_EXTS:
				ext = default_ext
			dest = os.path.join(folder, "%s_%s%s" % (prefix, role, ext))
			size, digest = self.http.download(url, dest)
			files.append({"path": self.rel(dest), "role": role, "bytes": size, "sha256": digest})
		summary = {"task_id": task_id, "call": call, "result": result, "files": [f["path"] for f in files]}
		with open(os.path.join(folder, "task.json"), "w") as f:
			json.dump(summary, f, indent="\t")
			f.write("\n")
		return files, result


# --------------------------------------------------------------------------- command line

def parse_options(opts: List[str], options_file: Optional[str]) -> Dict[str, Any]:
	options: Dict[str, Any] = {}
	if options_file:
		with open(options_file) as f:
			loaded = json.load(f)
		if not isinstance(loaded, dict):
			raise TripoError("%s must hold a JSON object" % options_file)
		options.update(loaded)
	for item in opts or []:
		if "=" not in item:
			raise TripoError("--opt wants key=value, got %r" % item)
		key, raw = item.split("=", 1)
		try:
			options[key] = json.loads(raw)
		except ValueError:
			options[key] = raw
	return options


def build_parser():  # type: ignore[no-untyped-def]
	parser = argparse.ArgumentParser(prog="tripo.py", description=__doc__.split("\n")[0])
	parser.add_argument("--self-test", action="store_true", help="offline checks; no network, no spend")
	sub = parser.add_subparsers(dest="command")
	sub.add_parser("balance", help="live balance and the spend headroom (free)")
	p = sub.add_parser("ledger", help="summarise the ledger (free)")
	p.add_argument("--live", action="store_true")
	p = sub.add_parser("task", help="status of one task (free)")
	p.add_argument("task_id")
	p = sub.add_parser("upload", help="upload an image, print the file_token")
	p.add_argument("image")
	for name in ("image-to-model", "multiview", "rig-check", "rig", "texture"):
		p = sub.add_parser(name)
		p.add_argument("--label", help="the brief's row, e.g. T1 (required to run)")
		p.add_argument("--dry-run", action="store_true")
		p.add_argument("--live", action="store_true", help="with --dry-run: also read the live balance")
		p.add_argument("--out-dir")
		p.add_argument("--opt", action="append", default=[], metavar="KEY=VALUE")
		p.add_argument("--options", metavar="FILE.json")
		p.add_argument("--poll-every", type=float, default=2.0)
		p.add_argument("--timeout", type=float, default=1200.0)
		if name == "image-to-model":
			p.add_argument("--input", required=True)
		if name in ("rig-check", "rig", "texture"):
			p.add_argument("--input", required=True)
		if name in ("multiview", "texture"):
			for view in ("front", "left", "back", "right"):
				p.add_argument("--" + view)
		if name == "texture":
			p.add_argument("--text")
	p = sub.add_parser("wait", help="resume a created, unfinished task")
	p.add_argument("task_id")
	p.add_argument("--out-dir")
	p.add_argument("--poll-every", type=float, default=2.0)
	p.add_argument("--timeout", type=float, default=1200.0)
	return parser


def make_service() -> Tripo:
	key = read_env("TRIPO_API_KEY")
	if not key:
		raise TripoError("TRIPO_API_KEY is missing from the environment and .env")
	prices = load_prices()
	ledger = Ledger(os.path.join(REPO, LEDGER_REL), prices["policy"]["milestone"])
	return Tripo(Http(key), prices, ledger)


def cmd_balance(svc: Tripo) -> None:
	balance, frozen = svc.balance()
	policy = svc.policy
	spent = svc.ledger.spent()
	account = round(float(policy["start_balance"]) - balance, 2)
	svc.say("balance %.2f, frozen %.2f" % (balance, frozen))
	svc.say("%s spend: ledger %.2f, account (start %.0f - balance) %.2f" % (policy["milestone"], spent, float(policy["start_balance"]), account))
	svc.say("headroom to the stop %.0f: %.2f; to the floor %.0f: %.2f" % (float(policy["ledger_stop"]),
		float(policy["ledger_stop"]) - max(spent, account), float(policy["balance_floor"]), balance - frozen - float(policy["balance_floor"])))


def cmd_ledger(svc: Tripo, live: bool) -> None:
	for task_id, entry in svc.ledger.tasks().items():
		line = entry["finished"] or entry["created"]
		credits = line.get("credits_consumed", "expected %s" % line.get("expected_credits"))
		svc.say("%-6s %-14s %-9s %s  %s credits  %s files" % (line.get("label"), line.get("call"), line.get("status", "created"),
			task_id, credits, len(line.get("files", []))))
	spent = svc.ledger.spent()
	svc.say("ledger spend %.2f of the stop %.0f" % (spent, float(svc.policy["ledger_stop"])))
	if live:
		balance, frozen = svc.balance()
		account = round(float(svc.policy["start_balance"]) - balance, 2)
		verdict = "reconciled" if abs(account - spent) <= 0.01 else "NOT reconciled: %.2f credits unaccounted for" % (account - spent)
		svc.say("account spend %.2f (balance %.2f): %s" % (account, balance, verdict))


def main(argv: List[str]) -> int:
	args = build_parser().parse_args(argv)
	if args.self_test:
		return self_test()
	if not args.command:
		build_parser().print_help()
		return 1
	load_secrets()
	try:
		svc = make_service()
		if args.command == "balance":
			cmd_balance(svc)
		elif args.command == "ledger":
			cmd_ledger(svc, args.live)
		elif args.command == "task":
			if not ID_RE.match(args.task_id):
				raise TripoError("bad task id")
			task = svc.http.api("GET", "/tasks/" + args.task_id)["data"]
			svc.say("%s %s %s%% credits %s" % (task.get("task_id"), task.get("status"), task.get("progress"), task.get("credits_consumed")))
		elif args.command == "upload":
			svc.say(svc.upload(args.image))
		elif args.command == "wait":
			svc.finish(args.task_id, svc.check_out_dir(args.out_dir), args.poll_every, args.timeout)
		else:
			call = args.command
			fields = {"options": parse_options(args.opt, args.options)}
			for name in ("input", "front", "left", "back", "right", "text"):
				if getattr(args, name, None):
					fields[name] = getattr(args, name)
			if not args.dry_run:
				# Cheap refusals first: nothing is uploaded for a task that could not run.
				if not LABEL_RE.match(args.label or ""):
					raise TripoError("--label is required (the brief's row, e.g. T1)")
				svc.check_out_dir(args.out_dir)
			plan = svc.plan(call, fields, args.dry_run)
			if args.dry_run:
				svc.dry_run(plan, args.live)
			else:
				svc.run(plan, args.label or "", args.out_dir, args.poll_every, args.timeout)
	except TripoError as e:
		print("tripo.py: " + redact(e), file=sys.stderr)
		return e.code
	return 0


# --------------------------------------------------------------------------- self test

class FakeHttp:
	"""A scripted stand-in for Http. It insists on the real-looking key in its Authorization header and, like a
	misbehaving server, can echo that key in an error message, to prove redact() holds."""

	def __init__(self, key: str, balance: float = 1500.0) -> None:
		self.key = key
		self.balance = balance
		self.frozen = 0.0
		self.calls: List[str] = []
		self.tasks: Dict[str, Dict[str, Any]] = {}
		self.next_status: List[str] = ["queued", "running", "success"]
		self.price = 30.0
		self.echo_key_error = False
		self.downloads: List[str] = []
		self.upload_count = 0

	def api(self, method: str, path: str, body: Optional[Dict[str, Any]] = None, upload: Optional[Tuple[str, str, bytes]] = None) -> Dict[str, Any]:
		self.calls.append("%s %s" % (method, path))
		if self.echo_key_error and method == "POST" and path != "/files":
			raise TripoError("HTTP 400 on POST %s: invalid request for key %s" % (path, self.key), 2)
		if path == "/account/balance":
			return {"code": 0, "data": {"balance": self.balance, "frozen": self.frozen}}
		if path == "/files":
			self.upload_count += 1
			return {"code": 0, "data": {"file_token": "file_fake%04d" % self.upload_count}}
		if method == "POST":
			task_id = str(uuid.uuid4())
			self.tasks[task_id] = {"path": path, "body": body, "polls": 0}
			return {"code": 0, "data": {"task_id": task_id}}
		task_id = path.rsplit("/", 1)[1]
		task = self.tasks[task_id]
		status = self.next_status[min(task["polls"], len(self.next_status) - 1)]
		task["polls"] += 1
		data: Dict[str, Any] = {"task_id": task_id, "type": "fake", "status": status, "progress": 50}
		if status == "success":
			self.balance -= self.price
			data["credits_consumed"] = self.price
			data["output"] = {"model_url": "https://cdn.example.invalid/out/model.glb?sig=abc",
				"rendered_image_url": "https://cdn.example.invalid/out/preview.webp?sig=abc",
				"rig_type": "biped", "riggable": True, "stray_url": "https://cdn.example.invalid/never"}
			task["polls"] = 99
		elif status == "failed":
			data.update({"error_code": 3001, "error_message": "bad input " + self.key})
		return {"code": 0, "data": data}

	def download(self, url: str, dest: str, max_bytes: int = MAX_DOWNLOAD_BYTES) -> Tuple[int, str]:
		self.downloads.append(url)
		data = b"fake-bytes-for-" + url.encode()
		with open(dest, "wb") as f:
			f.write(data)
		return len(data), hashlib.sha256(data).hexdigest()


def _png(path: str, width: int, height: int) -> None:
	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", width, height) + b"\x08\x06\x00\x00\x00" + b"\x00" * 4)
		f.write(b"\x00" * 64)


def scan_for_secrets(paths: List[str], secrets: List[str]) -> List[str]:
	"""Files among paths whose bytes contain any secret value."""
	hits: List[str] = []
	needles = [s.encode() for s in secrets if len(s) >= 8]
	for path in paths:
		if not os.path.isfile(path) or os.path.getsize(path) > 64 * 1024 * 1024:
			continue
		with open(path, "rb") as f:
			data = f.read()
		if any(n in data for n in needles):
			hits.append(path)
	return hits


def new_files(repo: str) -> List[str]:
	"""Every file this package added or changed: untracked, modified, and added since origin/m4/art-pipeline."""
	found = set()
	for command in (["git", "ls-files", "--others", "--exclude-standard"], ["git", "diff", "--name-only", "HEAD"],
			["git", "diff", "--name-only", "--diff-filter=AM", "origin/m4/art-pipeline...HEAD"]):
		try:
			out = subprocess.run(command, cwd=repo, capture_output=True, text=True, timeout=60).stdout
		except (OSError, subprocess.SubprocessError):
			continue
		found.update(line for line in out.splitlines() if line)
	found.update(["assets/source/tripo_ledger.jsonl", "docs/milestones/M4-calls/P1-tools.md"])
	for root, _dirs, names in os.walk(os.path.join(repo, "tools", "pipeline")):
		found.update(os.path.relpath(os.path.join(root, n), repo) for n in names if not n.endswith(".pyc"))
	return sorted(os.path.join(repo, rel) for rel in found)


def self_test() -> int:
	failures: List[str] = []

	def check(name: str, ok: bool, detail: str = "") -> None:
		print("%s  %s%s" % ("ok  " if ok else "FAIL", name, ("  " + detail) if detail and not ok else ""))
		if not ok:
			failures.append(name)

	def refuses(name: str, fn: Callable[[], Any], contains: str) -> None:
		try:
			fn()
		except TripoError as e:
			check(name, contains in str(e), str(e))
			return
		check(name, False, "no refusal")

	load_secrets()
	real = list(_SECRETS)
	key = real[0] if real else "tsk_selftest_%s" % uuid.uuid4().hex
	if not real:
		_SECRETS.append(key)
		print("note  no key in the environment or .env: using a synthetic one for the mock")
	prices = load_prices()
	tmp = tempfile.mkdtemp(prefix="tripo_selftest_")
	sink = io.StringIO()
	try:
		# --- prices
		t1 = {"input": "file_x", "model": "v3.1-20260211", "texture": True, "pbr": False, "texture_quality": "standard",
			"texture_version": "v3.5-20260815", "delight": True, "orientation": "align_image", "face_limit": 20000, "model_seed": 7}
		cost, notes = expected_cost("image-to-model", t1, prices)
		check("T1 options cost 30", cost == 30.0, str(cost))
		check("T1 flags the unpriced v3.5 texture", any(n.startswith("UNVERIFIED") for n in notes))
		check("untextured H3.1 is 20", expected_cost("multiview", {"texture": False, "pbr": False}, prices)[0] == 20.0)
		check("detailed geometry + standard texture is 50", expected_cost("multiview", {"geometry_quality": "detailed"}, prices)[0] == 50.0)
		check("detailed texture and geometry is 60", expected_cost("multiview", {"geometry_quality": "detailed", "texture_quality": "detailed"}, prices)[0] == 60.0)
		check("P1 standard is 110", expected_cost("image-to-model", {"model": "P1-20260311"}, prices)[0] == 110.0)
		check("pbr forces texture", expected_cost("image-to-model", {"texture": False, "pbr": True}, prices)[0] == 30.0)
		check("fast is priced as standard", expected_cost("image-to-model", {"texture_quality": "fast"}, prices)[0] == 30.0)
		check("rig 25, rig-check 0", expected_cost("rig", {}, prices)[0] == 25.0 and expected_cost("rig-check", {}, prices)[0] == 0.0)
		check("texture standard 10, extreme 30", expected_cost("texture", {}, prices)[0] == 10.0 and expected_cost("texture", {"texture_quality": "extreme"}, prices)[0] == 30.0)
		refuses("an unpriced call is refused", lambda: expected_cost("retarget", {}, prices), "no price")
		# --- option validation
		refuses("unknown option refused", lambda: validate_options("image-to-model", {"textur": True}, prices), "not a known")
		refuses("wrong type refused", lambda: validate_options("image-to-model", {"face_limit": "20000"}, prices), "integer")
		refuses("bool is not an int", lambda: validate_options("image-to-model", {"face_limit": True}, prices), "integer")
		refuses("fast needs v3.5", lambda: validate_options("image-to-model", {"texture_quality": "fast"}, prices), "v3.5")
		refuses("generate_parts needs no texture", lambda: validate_options("multiview", {"generate_parts": True}, prices), "texture=false")
		refuses("v2.5 refuses v3 options", lambda: validate_options("image-to-model", {"model": "v2.5-20250123", "quad": True}, prices), "v3.0")
		refuses("P series refuses smart_low_poly", lambda: validate_options("image-to-model", {"model": "P1-20260311", "smart_low_poly": True}, prices), "P series")
		refuses("unity needs rig v2.5+", lambda: validate_options("rig", {"model": "v1.0-20240301", "spec": "unity"}, prices), "fails on rig model v1.0")
		# --- images
		png_ok, png_small = os.path.join(tmp, "ok.png"), os.path.join(tmp, "small.png")
		_png(png_ok, 1536, 2048)
		_png(png_small, 100, 100)
		check("png size read", image_size(png_ok) == (1536, 2048))
		refuses("a 100 px image is refused", lambda: check_image(png_small), "at least 256")
		refuses("a non-image is refused", lambda: check_image(os.path.join(tmp, "x.glb")), "only png")
		# --- a repo-shaped sandbox for the lifecycle
		repo = os.path.join(tmp, "repo")
		os.makedirs(os.path.join(repo, "assets", "source"))
		ledger = Ledger(os.path.join(repo, LEDGER_REL), prices["policy"]["milestone"])
		fake = FakeHttp(key)
		svc = Tripo(fake, prices, ledger, repo=repo, sleep=lambda s: None, out=sink)
		args = {"input": png_ok, "options": {k: v for k, v in t1.items() if k != "input"}}
		# dry run: no network, no ledger
		fake.calls.clear()
		svc.dry_run(svc.plan("image-to-model", args, True), False)
		check("--dry-run makes no call", fake.calls == [], str(fake.calls))
		check("--dry-run writes no ledger", not os.path.exists(ledger.path))
		check("--dry-run prints the body and the cost", "expected credits: 30.0" in sink.getvalue() and '"inputs"' not in sink.getvalue() and "file_<upload of ok.png" in sink.getvalue())
		# guards
		fake.balance = 720.0
		refuses("the 700 floor is enforced", lambda: svc.guard(30.0), "floor")
		fake.balance = 1500.0
		ledger.append({"event": "created", "task_id": "task_old001", "call": "rig", "endpoint": "/animations/rig", "label": "X",
			"options": {}, "expected_credits": 740.0, "balance_before": 1500.0, "frozen_before": 0.0})
		refuses("the 750 ledger stop counts an unfinished task's expected cost", lambda: svc.guard(30.0), "stop")
		check("a 10 credit task still fits at 740", svc.guard(10.0)["ledger_spent"] == 740.0)
		os.remove(ledger.path)
		fake.balance = 1500.0 - 760.0 + 0.0
		refuses("spend outside the ledger counts toward the stop", lambda: svc.guard(5.0), "REFUSED")
		fake.balance = 1500.0
		# lifecycle
		out_dir = os.path.join(repo, "out", "t1")
		plan = svc.plan("image-to-model", args, False)
		check("the image was uploaded once", fake.upload_count == 1)
		record = svc.run(plan, "T1", out_dir, 0, 30)
		check("success recorded with the task's real credits", record["status"] == "success" and record["credits_consumed"] == 30.0 and record["credits_source"] == "task")
		check("balance before and after in the ledger", record["balance_before"] == 1500.0 and record["balance_after"] == 1470.0 and record["balance_delta"] == 30.0)
		check("only known outputs are downloaded, none with a key header", len(fake.downloads) == 2 and not any("never" in u for u in fake.downloads))
		names = sorted(os.listdir(out_dir))
		check("files are named <task8>_<role><ext> with a task.json", len(names) == 3 and "task.json" in names and any(n.endswith("_gen.glb") for n in names) and any(n.endswith("_preview.webp") for n in names), str(names))
		check("scalar outputs kept, URLs not", record["result"] == {"rig_type": "biped", "riggable": True})
		lines = ledger.lines()
		kinds = [ln["event"] for ln in lines]
		check("ledger has upload, created, finished", kinds == ["upload", "created", "finished"], str(kinds))
		check("ledger spend is 30", ledger.spent() == 30.0)
		check("ledger lines carry no URLs", "https://" not in open(ledger.path).read())
		refuses("a non-empty --out-dir is refused before spending", lambda: svc.run(plan, "T1b", out_dir, 0, 30), "not empty")
		check("...and no task was created for it", len(fake.tasks) == 1)
		refuses("a label is required", lambda: svc.run(plan, "", None, 0, 30), "label")
		refuses("--out-dir outside the repo is refused", lambda: svc.check_out_dir(os.path.join(tmp, "elsewhere")), "inside the repo")
		# a failure
		fake.next_status = ["running", "failed"]
		fake.price = 0.0
		try:
			svc.run(svc.plan("rig", {"input": "task:" + list(fake.tasks)[0]}, False), "T3", None, 0, 30)
			check("a failed task raises", False)
		except TripoError as e:
			check("a failed task raises code 4", e.code == 4)
		last = ledger.lines()[-1]
		check("failed task: status failed, 0 credits, error redacted", last["status"] == "failed" and last["credits_consumed"] == 0.0 and key not in (last["error"] or ""), str(last["error"]))
		# rig defaults
		rig_plan = svc.plan("rig", {"input": "task:abc12345"}, True)
		check("rig defaults to v3.0 unity glb", rig_plan["body"] == {"input": "abc12345", "model": "v3.0-20260909", "rig_type": "biped", "spec": "unity", "out_format": "glb"}, str(rig_plan["body"]))
		check("multiview body is view-keyed", svc.plan("multiview", {"front": "file:file_a123456", "left": "file:file_b123456"}, True)["body"]["inputs"] == [{"front": "file_a123456"}, {"left": "file_b123456"}])
		refuses("multiview needs two views", lambda: svc.plan("multiview", {"front": "file:file_a123456"}, True), "at least one more")
		# a crash between created and finished is recoverable by wait
		fake.next_status = ["running", "running", "success"]
		fake.price = 25.0
		plan2 = svc.plan("rig-check", {"input": "task:abc12345"}, True)
		try:
			svc.run(plan2, "T2", None, 0, 0)  # a zero timeout: created, then 'timeout'
			check("a timeout raises", False)
		except TripoError as e:
			check("a timeout raises code 5 and leaves the created line", e.code == 5 and ledger.lines()[-1]["event"] == "created")
		pending = ledger.lines()[-1]["task_id"]
		resumed = svc.finish(pending, None, 0, 30)
		check("wait finishes the pending task", resumed["status"] == "success" and ledger.tasks()[pending]["finished"] is not None)
		refuses("a finished task is not recorded twice", lambda: svc.finish(pending, None, 0, 30), "already finished")
		refuses("a task outside the ledger is refused", lambda: svc.finish("task_unknown1", None, 0, 30), "not in the ledger")
		# secrets
		fake.echo_key_error = True
		try:
			svc.run(svc.plan("rig", {"input": "task:abc12345"}, False), "T3b", None, 0, 30)
		except TripoError as e:
			printed = redact(e)
			check("an error that echoes the key is masked", key not in printed and "<key>" in printed)
		fake.echo_key_error = False
		check("the key is not in anything printed", key not in sink.getvalue())
		hits = scan_for_secrets([os.path.join(r, n) for r, _d, ns in os.walk(tmp) for n in ns], _SECRETS)
		check("the key is in no file the mock run wrote", hits == [], str(hits))
		# the repo itself
		files = new_files(REPO)
		hits = scan_for_secrets(files, _SECRETS)
		check("no key value in the ledger or any of the %d new or changed files" % len(files), hits == [], str(hits))
		ledger_file = os.path.join(REPO, LEDGER_REL)
		check("the repo ledger exists", os.path.isfile(ledger_file))
		if os.path.isfile(ledger_file):
			real_ledger = Ledger(ledger_file, prices["policy"]["milestone"])
			check("the repo ledger parses and is within the stop", real_ledger.spent() <= float(prices["policy"]["ledger_stop"]))
		print("note  scanned for %d key value(s), read in memory only" % len(_SECRETS))
	finally:
		shutil.rmtree(tmp, ignore_errors=True)
		_SECRETS[:] = real
	print("\n%s" % ("self-test passed" if not failures else "self-test FAILED: " + ", ".join(failures)))
	return 0 if not failures else 1


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
