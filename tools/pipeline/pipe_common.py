"""Shared helpers of the art pipeline (M4 package P1-chain). Pure Python 3: run.py (system python3, no numpy)
and every Blender step import it.

The pipeline works in two coordinate frames:
	Godot / rig space: metres at 1.8 m, +Y up, the character faces -Z, own right is +X. tools/pipeline/joints.json
	is written in it and is the joint table of the asset contract; this file only reads it.
	Blender frame: (x, y, z)_blender = (x, -z, y)_godot, so the character faces +Y and Z is up. Every Blender
	step works in it; the glTF exporter (export_yup) turns it back into Godot space with no rotation.

The A-pose chain (M4-plan A3): the exported armature's rest is the A-pose, every arm chain swung as one straight
limb by the mesh's measured direction d (a unit vector, hanging = (0, 0, -1) in the Blender frame):
	p_LowerArm = p_UpperArm + |table LowerArm - table UpperArm| * d
	p_Hand     = p_LowerArm + |table Hand - table LowerArm| * d
and every other joint is the table joint. chain_joints() is that rule, and test_art_contract.gd checks it.
"""
import hashlib
import json
import math
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
JOINTS_PATH = os.path.join(REPO, "tools", "pipeline", "joints.json")
PALETTE_DIR = os.path.join(REPO, "assets", "source", "palette")
ATLAS_PATH = os.path.join(REPO, "assets", "export", "palette", "palette_atlas.png")

DIGITS = 6
SIDES = ("Left", "Right")
HANGING = (0.0, 0.0, -1.0)  # an arm hanging, in the Blender frame


def rnd(x, digits=DIGITS):
	"""Round numbers (and lists, tuples, dicts of them) for deterministic JSON."""
	if isinstance(x, bool) or x is None or isinstance(x, str):
		return x
	if isinstance(x, dict):
		return {str(k): rnd(v, digits) for k, v in x.items()}
	if isinstance(x, (list, tuple)):
		return [rnd(v, digits) for v in x]
	try:
		f = float(x)
	except (TypeError, ValueError):
		return x
	if f != f or f in (float("inf"), float("-inf")):
		return None
	value = round(f, digits)
	if value == 0:
		value = 0.0
	return int(value) if isinstance(x, int) else value


def write_json(obj, path):
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	with open(path, "w") as f:
		json.dump(rnd(obj), f, indent="\t", sort_keys=False)
		f.write("\n")


def load_json(path):
	with open(path) as f:
		return json.load(f)


def sha256_file(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


def canonical_hash(obj):
	"""sha256 of the canonical JSON of obj (rounded, sorted keys): the report hash."""
	return hashlib.sha256(json.dumps(rnd(obj), sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def repo_path(rel):
	"""Absolute path of a repo-relative one (absolute paths pass through)."""
	return rel if os.path.isabs(rel) else os.path.join(REPO, rel)


def repo_rel(path):
	"""Repo-relative path with forward slashes, for reports (no absolute path ever enters a report)."""
	try:
		return os.path.relpath(os.path.abspath(path), REPO).replace(os.sep, "/")
	except ValueError:
		return os.path.basename(path)


# --------------------------------------------------------------------------- the joint table

_TABLE = None


def table():
	"""joints.json, parsed once."""
	global _TABLE
	if _TABLE is None:
		_TABLE = load_json(JOINTS_PATH)
	return _TABLE


def bone_names():
	return [b["name"] for b in table()["bones"]]


def bone_parent():
	return {b["name"]: (b["parent"] or None) for b in table()["bones"]}


def bone_children():
	kids = {n: [] for n in bone_names()}
	for n, p in bone_parent().items():
		if p:
			kids[p].append(n)
	return kids


def g2b(p):
	"""Godot (x, y, z) -> Blender (x, -z, y)."""
	return (p[0], -p[2], p[1])


def b2g(p):
	"""Blender (x, y, z) -> Godot (x, z, -y)."""
	return (p[0], p[2], -p[1])


def table_joints():
	"""{bone: Blender-frame rest position} of the table (arms hanging)."""
	return {b["name"]: g2b(b["rest_global"]) for b in table()["bones"]}


def vsub(a, b):
	return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vadd(a, b):
	return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vmul(a, s):
	return (a[0] * s, a[1] * s, a[2] * s)


def vlen(a):
	return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def vnorm(a):
	n = vlen(a)
	return (a[0] / n, a[1] / n, a[2] / n) if n > 1e-12 else (0.0, 0.0, 0.0)


def vdot(a, b):
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def vcross(a, b):
	return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def swing_dir(side, deg):
	"""Unit direction of an arm swung `deg` outward from hanging about the forward axis (Blender frame)."""
	a = math.radians(deg)
	sign = -1.0 if side == "Left" else 1.0
	return (sign * math.sin(a), 0.0, -math.cos(a))


def swing_deg_of(side, d):
	"""The sideways swing (degrees) of an arm direction d from hanging, positive outward."""
	sign = -1.0 if side == "Left" else 1.0
	return math.degrees(math.atan2(sign * d[0], -d[2]))


def chain_joints(dirs):
	"""The table joints with each arm chain swung straight along dirs[side] (Blender frame): see the module doc."""
	j = dict(table_joints())
	for side in SIDES:
		d = dirs[side]
		ua, la, hd = (side + n for n in ("UpperArm", "LowerArm", "Hand"))
		table_j = table_joints()
		j[la] = vadd(j[ua], vmul(d, vlen(vsub(table_j[la], table_j[ua]))))
		j[hd] = vadd(j[la], vmul(d, vlen(vsub(table_j[hd], table_j[la]))))
	return j


def leaf_lengths():
	"""Lengths of the leaf bones' segments from the table: Head up to head_top is config; the hand from the wrist to the
	bottom of the fist box; the toes from the toe joint to the toe tip. {bone: length_m}"""
	t = table()
	out = {}
	fist = t["fist_boxes"][0]
	out["Hand"] = abs(fist["center_offset"][1]) + fist["size"][1] / 2.0
	by = {b["name"]: b for b in t["bones"]}
	toe = by["LeftToes"]["rest_global"]
	tip = t["soles"][2]["rest_global"]
	out["Toes"] = vlen(vsub(tuple(tip), tuple(toe)))
	return out


def segments(joints, head_top_m, dirs):
	"""(head, tail) per bone, Blender frame, for the 22 non-root bones. tail = the first child's head; the leaf bones'
	tails: Head -> straight up to head_top_m, Hand -> along its arm direction, Toes -> the table's toe tip."""
	kids = bone_children()
	lens = leaf_lengths()
	t = table()
	out = {}
	for n in bone_names():
		if n == "Root":
			continue
		head = joints[n]
		if kids[n]:
			tail = joints[kids[n][0]]
		elif n == "Head":
			tail = (head[0], head[1], head_top_m)
		elif n.endswith("Hand"):
			tail = vadd(head, vmul(dirs[n[:-4]], lens["Hand"]))
		elif n.endswith("Toes"):
			idx = 2 if n.startswith("Left") else 5
			tail = g2b(t["soles"][idx]["rest_global"])
		else:
			tail = vadd(head, (0.0, 0.0, -0.05))
		out[n] = (head, tail)
	return out


# --------------------------------------------------------------------------- config and reports

def load_config(path):
	cfg = load_json(path)
	cfg["_path"] = os.path.abspath(path)
	return cfg


def cfg_dir(cfg, key):
	return repo_path(cfg["paths"][key])


def work_path(cfg, name):
	return os.path.join(cfg_dir(cfg, "work"), name)


def step_argv():
	"""Arguments after `--` in the Blender command line (or sys.argv[1:] outside Blender)."""
	import sys
	return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def step_report_path(cfg, step):
	return work_path(cfg, step + ".report.json")


def fail(msg):
	"""Print and exit non-zero (inside Blender `--python-exit-code 1` turns an exception into a failed run)."""
	import sys
	print("PIPELINE ERROR: " + msg)
	sys.exit(3)
