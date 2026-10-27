"""The art pipeline's driver (M4 package P1-chain): one command from a source model to the shipped GLB.

	python3 -I tools/pipeline/run.py --asset punk                 assets/source/characters/punk/pipeline.json
	python3 -I tools/pipeline/run.py --config tests/fixtures/art/probe_pipeline.json
	  --from STEP     start at STEP, reusing the earlier steps' work files   (idempotent: any step can be rerun)
	  --only STEP     run just STEP
	  --no-stills     skip the Workbench stills   --no-import   skip the Godot import and the .import patches
	  --set a.b=JSON  override a config value (e.g. --set rig.weights='"tripo"'); the effective config is kept in work/
	  --check         rebuild into a scratch folder and compare the report hash with the committed report
	  --list          print the steps

Steps (each is one headless Blender process, never the Blender MCP; one at a time):
	inspect       blender_inspect.py   import, facing, flatten, join, weld, landmarks, the source rig's weights
	fit           blender_fit.py       scale, soles, measured arm swing, proportion warp onto the table
	rig           blender_rig.py       the 23-bone armature on the chained table, weights (tripo or auto)
	parts_replace blender_parts.py     the Blender-made fists replace the hands
	palette       blender_palette.py   swatch labels, border-protected decimation, palette UVs
	parts_split   blender_parts.py     first-person split with inward caps (when parts.split_fp.enabled)
	export        blender_export.py    hull normals, the A-pose GLB and the arms-down bake, read-back checks
	stills        blender_stills.py    Workbench stills and strain numbers at the probe poses
then the atlas (gen_palette.py) is rebuilt and Godot imports the new files (.import patched per the contract).

The report: <paths.report>/report.json = {asset, version, config_sha256, steps, outputs, hash}. The hash covers the config
(minus paths), every step's report and the sha256 of each exported file, and nothing that varies between runs (no time, no
absolute path), so a rerun on the same input gives the same hash. Reads only the repo; the source model is untrusted data
and is only ever opened by Blender as data.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pipe_common as pc  # noqa: E402
import gen_palette  # noqa: E402

STEPS = [
	("inspect", "blender_inspect.py", []),
	("fit", "blender_fit.py", []),
	("rig", "blender_rig.py", []),
	("parts_replace", "blender_parts.py", ["replace"]),
	("palette", "blender_palette.py", []),
	("parts_split", "blender_parts.py", ["split"]),
	("export", "blender_export.py", []),
	("stills", "blender_stills.py", []),
]
STEP_NAMES = [s[0] for s in STEPS]

GLB_PARAMS = {"meshes/generate_lods": "false", "meshes/create_shadow_meshes": "true", "skins/use_named_skins": "true", "animation/import": "false"}
# a detail mask (F-punk, A18) is sampled by a mipmapped sampler and holds ink lines only: keep the lossless mode and make mipmaps
DETAIL_PARAMS = {"compress/mode": "0", "mipmaps/generate": "true", "process/fix_alpha_border": "false", "process/premult_alpha": "false", "detect_3d/compress_to": "0"}
ATLAS_PARAMS = {"compress/mode": "0", "mipmaps/generate": "false", "process/fix_alpha_border": "false", "process/premult_alpha": "false", "detect_3d/compress_to": "0"}


def run_blender(script, cfg_path, extra, log_path):
	cmd = ["blender", "--background", "--factory-startup", "--python-exit-code", "1", "--python", os.path.join(HERE, script), "--", cfg_path] + extra
	t0 = time.time()
	proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=pc.REPO)
	os.makedirs(os.path.dirname(log_path), exist_ok=True)
	with open(log_path, "w") as f:
		f.write(proc.stdout)
	return proc.returncode, proc.stdout, time.time() - t0


def patch_import(path, params):
	"""Set params in a Godot .import file's [params] section; True when something changed."""
	text = open(path).read()
	new = text
	for key, value in params.items():
		new, n = re.subn(r"(?m)^%s=.*$" % re.escape(key), "%s=%s" % (key, value), new)
		if n == 0:
			print("  warning: %s has no %s" % (os.path.basename(path), key))
	if new != text:
		with open(path, "w") as f:
			f.write(new)
		return True
	return False


def godot_import():
	proc = subprocess.run(["godot", "--headless", "--import", "--quit"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=pc.REPO)
	if "ERROR" in proc.stdout.replace("ERROR: ", "ERROR "):
		print("  godot import printed errors:")
		for line in proc.stdout.splitlines():
			if "ERROR" in line:
				print("   " + line)


def ensure_imports(glbs, details=()):
	"""Make Godot write the .import files, then set the contract's params (and the atlas's and any detail mask's), reimporting on a change."""
	files = [(g, GLB_PARAMS) for g in glbs] + [(pc.ATLAS_PATH, ATLAS_PARAMS)] + [(d, DETAIL_PARAMS) for d in details]
	if any(not os.path.exists(f + ".import") for f, _ in files):
		godot_import()
	changed = False
	for f, params in files:
		if os.path.exists(f + ".import"):
			changed |= patch_import(f + ".import", params)
		else:
			print("  warning: no .import for " + pc.repo_rel(f))
	if changed:
		godot_import()


def apply_overrides(cfg, sets):
	for item in sets:
		key, _, raw = item.partition("=")
		try:
			value = json.loads(raw)
		except ValueError:
			value = raw
		node = cfg
		parts = key.split(".")
		for p in parts[:-1]:
			node = node.setdefault(p, {})
		node[parts[-1]] = value
	return cfg


def build_report(cfg, steps_done):
	steps = {}
	for name in STEP_NAMES:
		path = pc.step_report_path(cfg, name)
		if os.path.exists(path) and name != "stills":
			steps[name] = pc.load_json(path)
	stills_path = pc.step_report_path(cfg, "stills")
	outputs = {}
	for variant, info in steps.get("export", {}).get("variants", {}).items():
		outputs[os.path.basename(info["file"])] = info["sha256"]
		info["file"] = os.path.basename(info["file"])
	body = {k: v for k, v in cfg.items() if k not in ("paths", "_path")}
	report = {"asset": cfg["id"], "version": cfg.get("version", 1), "config_sha256": pc.canonical_hash(body), "steps": steps, "outputs": outputs}
	text = json.dumps(pc.rnd(report))
	if "/Users/" in text or "\\Users\\" in text:
		pc.fail("an absolute path leaked into the report")
	report["hash"] = pc.canonical_hash(report)
	if os.path.exists(stills_path):  # informative, outside the hash (it names image files)
		report["stills"] = pc.load_json(stills_path)
	return report


def usage():
	"""The one-line usage printed on a bad step name or a missing value."""
	return ("usage: run.py (--asset <id> | --config <pipeline.json>) [--from STEP | --only STEP] [--no-stills] [--no-import] "
		"[--set a.b=JSON] [--check] [--list]\nsteps: " + ", ".join(STEP_NAMES) + "\n(the reproducibility command is --check, not a step)")


def main(argv):
	if "--list" in argv:
		for name, script, extra in STEPS:
			print("%-14s %s %s" % (name, script, " ".join(extra)))
		return 0
	opts = {"from": None, "only": None, "config": None, "asset": None, "sets": [], "stills": True, "import": True, "check": False}
	i = 0
	while i < len(argv):
		a = argv[i]
		if a in ("--from", "--only", "--config", "--asset", "--set"):
			if i + 1 >= len(argv):
				print("%s needs a value\n%s" % (a, usage()))
				return 2
			val = argv[i + 1]
			i += 1
			if a == "--set":
				opts["sets"].append(val)
			else:
				opts[a[2:]] = val
		elif a == "--no-stills":
			opts["stills"] = False
		elif a == "--no-import":
			opts["import"] = False
		elif a == "--check":
			opts["check"] = True
		else:
			print("unknown argument " + a)
			return 2
		i += 1
	# a step name is checked before anything is written (the atlas, the effective config, a check's scratch folder)
	for key in ("from", "only"):
		if opts[key] is not None and opts[key] not in STEP_NAMES:
			print("unknown step %r for --%s\n%s" % (opts[key], key, usage()))
			return 2
	if opts["asset"]:
		cfg_path = os.path.join(pc.REPO, "assets", "source", "characters", opts["asset"], "pipeline.json")
	elif opts["config"]:
		cfg_path = pc.repo_path(opts["config"])
	else:
		print(__doc__)
		return 2
	cfg = apply_overrides(pc.load_config(cfg_path), opts["sets"])
	committed = None
	if opts["check"]:
		rj = cfg["paths"].get("report_json")
		committed_path = pc.repo_path(rj) if rj else os.path.join(pc.cfg_dir(cfg, "report"), "report.json")
		committed = pc.load_json(committed_path)["hash"]
		scratch = os.path.join("assets", "source", "_cache", "check_" + cfg["id"])
		shutil.rmtree(pc.repo_path(scratch), ignore_errors=True)
		cfg["paths"] = dict(cfg["paths"], work=scratch + "/work", report=scratch + "/report", export_dir=scratch + "/export", blend_dir=scratch + "/blend")
		cfg["paths"].pop("report_json", None)
		opts["import"] = False
		opts["stills"] = False
		opts["from"] = None
		opts["only"] = None
	for key in ("work", "report", "export_dir"):
		os.makedirs(pc.cfg_dir(cfg, key), exist_ok=True)
	# the effective config the Blender steps read (overrides applied), kept with the work files
	eff = os.path.join(pc.cfg_dir(cfg, "work"), "effective_pipeline.json")
	pc.write_json({k: v for k, v in cfg.items() if k != "_path"}, eff)
	gen_palette_ok = gen_palette.main([]) == 0
	if not gen_palette_ok:
		return 1
	names = STEP_NAMES
	if opts["only"]:
		names = [opts["only"]]
	elif opts["from"]:
		names = STEP_NAMES[STEP_NAMES.index(opts["from"]):]
	if not opts["stills"] and "stills" in names:
		names = [n for n in names if n != "stills"]
	print("pipeline %s: %s" % (cfg["id"], " > ".join(names)))
	for name in names:
		script, extra = next((s[1], s[2]) for s in STEPS if s[0] == name)
		if name == "stills" and "stills" not in cfg:
			continue
		code, out, dt = run_blender(script, eff, extra, os.path.join(pc.cfg_dir(cfg, "work"), "logs", name + ".log"))
		print("  %-14s %s  (%.1f s)" % (name, "ok" if code == 0 else "FAILED", dt))
		if code != 0:
			print("\n".join(out.splitlines()[-40:]))
			return 1
	report = build_report(cfg, names)
	rep_dir = pc.cfg_dir(cfg, "report")
	pc.write_json(report, os.path.join(rep_dir, "report.json"))
	if cfg["paths"].get("report_json"):
		pc.write_json(report, pc.repo_path(cfg["paths"]["report_json"]))
	print("report hash " + report["hash"])
	if opts["import"]:
		glbs = [os.path.join(pc.cfg_dir(cfg, "export_dir"), n) for n in report["outputs"]]
		export_dir = pc.cfg_dir(cfg, "export_dir")
		details = [os.path.join(export_dir, n) for n in sorted(os.listdir(export_dir)) if n.endswith("_detail.png")] if os.path.isdir(export_dir) else []
		ensure_imports(glbs, details)
	if committed is not None:
		same = committed == report["hash"]
		print("reproducible: %s (committed %s)" % ("YES, the same report hash" if same else "NO, the hash differs", committed[:12]))
		return 0 if same else 1
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
