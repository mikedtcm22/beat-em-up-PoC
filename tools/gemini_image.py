"""Batch image generation with Google Gemini (SPEC §10, step 1: concepts).

Usage: python3 -I tools/gemini_image.py <jobs.json> [job-name ...]
A jobs file is a JSON list of
	{"out": "name.png", "prompt": "...", "model": "gemini-3-pro-image",
	 "aspect": "3:4", "size": "2K", "refs": ["ref.png", ...]}
"out" and "refs" are relative to the jobs file's folder; the written file's extension follows
the image type the model returns. Naming jobs (by their "out" stem)
runs only those. The key is GEMINI_API_KEY from the environment, else from the repo's .env,
else (in a linked worktree) from the main checkout's .env. It is sent in the x-goog-api-key
header and never printed. The key's project needs billing (Tier 1): the free tier allows no
image generations.
"""
import base64
import concurrent.futures
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent"


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
	if os.environ.get("GEMINI_API_KEY"):
		return os.environ["GEMINI_API_KEY"].strip()
	for path in env_files():
		if not os.path.isfile(path):
			continue
		with open(path) as f:
			for line in f:
				if line.startswith("GEMINI_API_KEY="):
					return line.split("=", 1)[1].strip()
	sys.exit("GEMINI_API_KEY is missing from the environment and .env")


def run(job: dict, base: str, key: str) -> str:
	out = os.path.join(base, job["out"])
	parts = [{"text": job["prompt"]}]
	for ref in job.get("refs", []):
		path = os.path.join(base, ref)
		mime = mimetypes.guess_type(path)[0] or "image/png"
		with open(path, "rb") as f:
			parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(f.read()).decode()}})
	config = {"responseModalities": ["TEXT", "IMAGE"], "imageConfig": {"aspectRatio": job.get("aspect", "3:4")}}
	if job.get("size"):
		config["imageConfig"]["imageSize"] = job["size"]
	body = json.dumps({"contents": [{"parts": parts}], "generationConfig": config}).encode()
	request = urllib.request.Request(ENDPOINT.format(job.get("model", "gemini-3-pro-image")), data=body,
		headers={"x-goog-api-key": key, "Content-Type": "application/json"})
	try:
		with urllib.request.urlopen(request, timeout=300) as response:
			data = json.load(response)
	except urllib.error.HTTPError as e:
		return f"{job['out']}: HTTP {e.code} {e.read().decode(errors='replace').replace(key, '<key>')[:400]}"
	texts = []
	for candidate in data.get("candidates", []):
		for part in candidate.get("content", {}).get("parts", []):
			if "inlineData" in part:
				# The extension follows the returned type (the models answer in JPEG or PNG).
				ext = mimetypes.guess_extension(part["inlineData"].get("mimeType", "image/png")) or ".png"
				out = os.path.splitext(out)[0] + (".jpg" if ext in (".jpe", ".jpeg") else ext)
				with open(out, "wb") as f:
					f.write(base64.b64decode(part["inlineData"]["data"]))
				return f"{os.path.relpath(out, base)}: ok {' '.join(texts)[:200]}"
			if "text" in part:
				texts.append(part["text"])
	return f"{job['out']}: no image; {json.dumps(data)[:400]}"


def main() -> None:
	jobs_path = os.path.abspath(sys.argv[1])
	base = os.path.dirname(jobs_path)
	with open(jobs_path) as f:
		jobs = json.load(f)
	names = set(sys.argv[2:])
	if names:
		jobs = [j for j in jobs if os.path.splitext(j["out"])[0] in names]
	key = read_key()
	with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
		for line in pool.map(lambda j: run(j, base, key), jobs):
			print(line, flush=True)


if __name__ == "__main__":
	main()
