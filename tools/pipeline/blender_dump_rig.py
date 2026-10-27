"""Dump a rigged character file to bones.json (headless Blender; M4 plan Part A A2 step 2).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_dump_rig.py -- <in.glb|.gltf|.fbx|.blend> <out/bones.json>
	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_dump_rig.py -- --self-test [workdir]

Never the Blender MCP; one Blender process at a time. The input is untrusted: it is only ever opened as data.
It changes nothing: no file but the output is written, and the output is deterministic (rounded, ordered, no
timestamps, no absolute paths), so a rerun on the same input gives the same bytes.

Everything is reported in GODOT SPACE (glTF space: x right, y up, the rig faces -z), converted from Blender's
world as (x, y, z) -> (x, z, -y), so numbers compare directly with tools/pipeline/joints.json. Blender's
object transforms are applied to every position (a Tripo file may carry a scale or a rotation on the armature).

bones.json:
	version, blender, source {file, bytes, sha256}, import {bone_heuristic, guess_original_bind_pose, ...},
	space, objects [{name, type, parent, location, rotation_euler_deg, scale}]
	armatures [{name, bone_count, bones [{index, name, parent, head, tail, roll_rad, length, deform,
	            weighted_verts}], notes}]   head and tail are world positions. glTF stores only joint heads:
	            the importer invents the tails (bone_heuristic), so trust heads, parents and names, not tails.
	meshes [{name, vertices, triangles, bbox {min, max, size}, armature, modifiers, uv_layers, color_attributes,
	         shape_keys, groups {bone: {count, weight_sum, centroid}}, max_influences, influence_histogram,
	         unweighted, over_four, not_normalized, groups_without_bone, materials [names]}]
	materials [{name, base_color, metallic, roughness, image}]   images [{name, size, packed, colorspace,
	         dominant_colors [{rgb_hex_16_levels, share}]}]
	summary {triangles, vertices, bbox, height_m, feet_y, bones, unweighted, max_influences, over_four,
	         bones_without_vertices, neutral_bone {present, weighted_verts}}
	         neutral_bone: Blender's glTF exporter and Godot's importer add that bone when a vertex has no weight; the
	         asset contract forbids it, so P1-chain's checks read this.
	facing {dir_xz, yaw_deg_to_minus_z, axis, confidence, toe {...}, nose {...}, agreement_deg, params}
	        yaw_deg_to_minus_z is the rotation about +Y (degrees) that turns the model to face -Z.
	sides {left_bones, right_bones, left_minus_right_lateral_m, consistent, left_is_minus_x}
	        consistent is true when the bones named Left sit on the character's own left; a mirrored label
	        (the Tripo "left" ambiguity of the codemap) shows as false.
	names {rig_table_missing, rig_table_extra, profile_matched, profile_unmatched}
	        against the project's 23 bone names and Godot's 56-bone SkeletonProfileHumanoid.

Facing: the toe direction (the long axis of each foot's footprint, signed toward the end that reaches further
from the shin above it) is the primary. The head is the cross-check: a face sticks out in front of the torso's
axis further than the skull does behind it. confidence is "high" (head reach in front >= behind), "weak"
(slightly less), "conflict" (behind exceeds in front by 15%: the toe sign may be wrong), "toe_only" (no head
found) or "none" (no feet).
"""
import hashlib
import json
import math
import os
import re
import shutil
import sys
import tempfile
import traceback

import bpy
import numpy as np
from mathutils import Matrix, Vector

# The rounding of every number written, and the thresholds of the heuristics; all are echoed into the output.
DIGITS = 6
WEIGHT_EPS = 1e-6
NORMALIZED_TOLERANCE = 1e-3
HEURISTICS = {
	"foot_band_of_height": 0.07,
	"shin_band_of_height": [0.12, 0.25],
	"min_foot_elongation": 1.3,
	"head_band_of_height": 0.14,
	"torso_band_of_height": [0.50, 0.78],
	"nose_conflict_ratio": 1.15,
	"dominant_color_samples": 4096,
	"dominant_colors": 6,
}
RIG_BONES = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]


def profile_bones():
	"""The 56 bone names of Godot's SkeletonProfileHumanoid (the Unity HumanBodyBones names)."""
	names = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftEye", "RightEye", "Jaw"]
	for side in ("Left", "Right"):
		names += [side + n for n in ("Shoulder", "UpperArm", "LowerArm", "Hand")]
		for finger, parts in (("Thumb", ("Metacarpal", "Proximal", "Distal")), ("Index", ("Proximal", "Intermediate", "Distal")),
				("Middle", ("Proximal", "Intermediate", "Distal")), ("Ring", ("Proximal", "Intermediate", "Distal")),
				("Little", ("Proximal", "Intermediate", "Distal"))):
			names += [side + finger + p for p in parts]
		names += [side + n for n in ("UpperLeg", "LowerLeg", "Foot", "Toes")]
	return names


def r(x):
	"""Round numbers (and anything iterable of them: lists, arrays, Blender vectors) for a deterministic file."""
	try:
		value = round(float(x), DIGITS)
	except (TypeError, ValueError):
		return [r(v) for v in x]
	return 0.0 if value == 0 else value


def to_godot(p):
	"""Blender world (x, y, z) -> Godot (x, z, -y); accepts one point or an (n, 3) array."""
	p = np.asarray(p, dtype=np.float64)
	return np.stack([p[..., 0], p[..., 2], -p[..., 1]], axis=-1)


def matrix_np(m):
	return np.array([list(row) for row in m], dtype=np.float64)


def world_points(obj, local):
	m = matrix_np(obj.matrix_world)
	return local @ m[:3, :3].T + m[:3, 3]


# --------------------------------------------------------------------------- loading

def load(path):
	"""Open the file into an empty scene. Returns the import options used."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	ext = os.path.splitext(path)[1].lower()
	if ext in (".glb", ".gltf"):
		options = {"bone_heuristic": "BLENDER", "guess_original_bind_pose": True, "disable_bone_shape": True}
		bpy.ops.import_scene.gltf(filepath=path, **options)
		return dict(options, importer="gltf")
	if ext == ".fbx":
		bpy.ops.import_scene.fbx(filepath=path)
		return {"importer": "fbx"}
	if ext == ".blend":
		bpy.ops.wm.open_mainfile(filepath=path)
		return {"importer": "blend"}
	raise SystemExit("unsupported input type: " + ext)


# --------------------------------------------------------------------------- armatures

def side_of(name):
	"""'L', 'R' or None from a bone name (Left/Right anywhere, or a lone l/r token: hand.L, L_Hand, Hand_R)."""
	low = name.split(":")[-1].lower()
	if "left" in low:
		return "L"
	if "right" in low:
		return "R"
	if re.search(r"(^|[._\-])l($|[._\-])", low):
		return "L"
	if re.search(r"(^|[._\-])r($|[._\-])", low):
		return "R"
	return None


def armature_info(obj):
	"""Bones of one armature object, in the armature's own order, with world heads, tails and edit-bone roll."""
	arm = obj.data
	rolls = {}
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.mode_set(mode="EDIT")
	for eb in arm.edit_bones:
		rolls[eb.name] = eb.roll
	bpy.ops.object.mode_set(mode="OBJECT")
	bones = []
	for index, bone in enumerate(arm.bones):
		head = to_godot(world_points(obj, np.array(bone.head_local)))
		tail = to_godot(world_points(obj, np.array(bone.tail_local)))
		bones.append({
			"index": index, "name": bone.name, "parent": bone.parent.name if bone.parent else None,
			"head": r(head), "tail": r(tail), "roll_rad": r(rolls.get(bone.name, 0.0)),
			"length": r(np.linalg.norm(head - tail)), "deform": bool(bone.use_deform),
		})
	return {"name": obj.name, "bone_count": len(bones), "bones": bones,
		"notes": ["head, tail in Godot space after the armature object's transform; tails are the importer's heuristic, not file data"]}


# --------------------------------------------------------------------------- meshes

def mesh_info(obj, bone_names):
	"""Geometry, weights and materials of one mesh object. Returns (info, world points in Godot space)."""
	me = obj.data
	n = len(me.vertices)
	co = np.empty(n * 3, dtype=np.float64)
	me.vertices.foreach_get("co", co)
	points = to_godot(world_points(obj, co.reshape(n, 3)))
	me.calc_loop_triangles()
	group_names = [g.name for g in obj.vertex_groups]
	vi, gi, ww = [], [], []
	for v in me.vertices:
		for g in v.groups:
			vi.append(v.index)
			gi.append(g.group)
			ww.append(g.weight)
	vi, gi, ww = np.array(vi, dtype=np.int64), np.array(gi, dtype=np.int64), np.array(ww, dtype=np.float64)
	live = ww > WEIGHT_EPS
	counts = np.bincount(vi[live], minlength=n) if n else np.zeros(0, dtype=np.int64)
	sums = np.bincount(vi[live], weights=ww[live], minlength=n) if n else np.zeros(0)
	weighted = counts > 0
	groups = {}
	for k, name in enumerate(group_names):
		sel = live & (gi == k)
		if not sel.any():
			groups[name] = {"count": 0, "weight_sum": 0.0, "centroid": None}
			continue
		groups[name] = {"count": int(sel.sum()), "weight_sum": r(ww[sel].sum()), "centroid": r(points[vi[sel]].mean(axis=0))}
	histogram = {str(k): int(c) for k, c in enumerate(np.bincount(counts)) if c} if n else {}
	armature = next((m.object.name for m in obj.modifiers if m.type == "ARMATURE" and m.object), obj.parent.name if obj.parent and obj.parent.type == "ARMATURE" else None)
	info = {
		"name": obj.name, "vertices": n, "triangles": len(me.loop_triangles), "polygons": len(me.polygons),
		"bbox": bbox(points), "armature": armature,
		"modifiers": [m.type for m in obj.modifiers], "uv_layers": [u.name for u in me.uv_layers],
		"color_attributes": [c.name for c in me.color_attributes],
		"shape_keys": len(me.shape_keys.key_blocks) if me.shape_keys else 0,
		"groups": groups, "max_influences": int(counts.max()) if n else 0, "influence_histogram": histogram,
		"unweighted": int((~weighted).sum()), "over_four": int((counts > 4).sum()),
		"not_normalized": int((weighted & (np.abs(sums - 1.0) > NORMALIZED_TOLERANCE)).sum()),
		"groups_without_bone": sorted(g for g in group_names if g not in bone_names),
		"materials": [s.material.name for s in obj.material_slots if s.material],
	}
	return info, points


def bbox(points):
	if len(points) == 0:
		return {"min": None, "max": None, "size": None}
	lo, hi = points.min(axis=0), points.max(axis=0)
	return {"min": r(lo), "max": r(hi), "size": r(hi - lo)}


# --------------------------------------------------------------------------- materials and textures

def find_image(socket, depth=0):
	"""The image feeding a socket, following links upstream a few nodes."""
	if depth > 4 or not socket.is_linked:
		return None
	node = socket.links[0].from_node
	if node.type == "TEX_IMAGE":
		return node.image
	for inp in node.inputs:
		found = find_image(inp, depth + 1)
		if found:
			return found
	return None


def dominant_colors(image):
	"""The most common colours of an image as stored (not colour-managed), each channel rounded to a multiple of 16, by share; None if unreadable."""
	try:
		w, h = image.size
		if w == 0 or h == 0:
			return None
		px = np.empty(w * h * image.channels, dtype=np.float32)
		image.pixels.foreach_get(px)
		px = px.reshape(h, w, image.channels)[..., :3]
		step = max(1, int(math.sqrt(w * h / HEURISTICS["dominant_color_samples"])))
		sample = np.clip(px[::step, ::step].reshape(-1, 3), 0.0, 1.0)
		quant = np.round(sample * 255.0 / 16.0).astype(np.int64) * 16
		quant = np.clip(quant, 0, 255)
		keys, counts = np.unique(quant, axis=0, return_counts=True)
		order = np.argsort(-counts, kind="stable")[:HEURISTICS["dominant_colors"]]
		return [{"rgb_hex_16_levels": "#%02x%02x%02x" % tuple(keys[i]), "share": r(counts[i] / counts.sum())} for i in order]
	except Exception:
		return None


def material_infos(mesh_objects):
	mats, images = {}, {}
	for obj in mesh_objects:
		for slot in obj.material_slots:
			mat = slot.material
			if not mat or mat.name in mats:
				continue
			entry = {"name": mat.name, "base_color": None, "metallic": None, "roughness": None, "image": None}
			bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat.node_tree else None
			if bsdf:
				entry["base_color"] = r(bsdf.inputs["Base Color"].default_value)
				entry["metallic"] = r(bsdf.inputs["Metallic"].default_value)
				entry["roughness"] = r(bsdf.inputs["Roughness"].default_value)
				image = find_image(bsdf.inputs["Base Color"])
				if image:
					entry["image"] = image.name
					images[image.name] = image
			mats[mat.name] = entry
	image_list = []
	for name in sorted(images):
		image = images[name]
		image_list.append({"name": name, "size": [int(image.size[0]), int(image.size[1])], "packed": image.packed_file is not None,
			"file": os.path.basename(image.filepath) if image.filepath else None, "colorspace": image.colorspace_settings.name,
			"channels": int(image.channels), "dominant_colors": dominant_colors(image)})
	return [mats[k] for k in sorted(mats)], image_list


# --------------------------------------------------------------------------- facing, sides, names

def unit(v):
	n = np.linalg.norm(v)
	return v / n if n > 1e-9 else None


def two_means(xz):
	"""Split 2D points into two clusters along their principal axis; returns labels (0/1) or None if one blob."""
	c = xz - xz.mean(axis=0)
	w, vec = np.linalg.eigh(np.cov(c.T))
	axis = vec[:, 1]
	proj = c @ axis
	if proj.max() - proj.min() < 1e-6:
		return None
	centers = np.array([xz[proj.argmin()], xz[proj.argmax()]])
	labels = np.zeros(len(xz), dtype=np.int64)
	for _ in range(12):
		d = np.linalg.norm(xz[:, None, :] - centers[None, :, :], axis=2)
		labels = d.argmin(axis=1)
		if (labels == 0).sum() == 0 or (labels == 1).sum() == 0:
			return None
		centers = np.array([xz[labels == 0].mean(axis=0), xz[labels == 1].mean(axis=0)])
	return labels


def foot_toe_dirs(P, lo_y, height):
	"""Per foot: the toe direction in the xz plane. Footprints below the foot band; shin = the leg above."""
	h = HEURISTICS
	feet = P[P[:, 1] < lo_y + h["foot_band_of_height"] * height][:, [0, 2]]
	shin_lo, shin_hi = h["shin_band_of_height"]
	shin = P[(P[:, 1] > lo_y + shin_lo * height) & (P[:, 1] < lo_y + shin_hi * height)][:, [0, 2]]
	if len(feet) < 8 or len(shin) < 4:
		return []
	labels = two_means(feet)
	groups = [feet] if labels is None else [feet[labels == 0], feet[labels == 1]]
	centers = np.array([g.mean(axis=0) for g in groups])
	nearest = np.linalg.norm(shin[:, None, :] - centers[None, :, :], axis=2).argmin(axis=1)
	out = []
	for k, foot in enumerate(groups):
		leg = shin[nearest == k]
		if len(foot) < 4 or len(leg) < 2:
			continue
		leg_c = leg.mean(axis=0)
		offset = foot.mean(axis=0) - leg_c
		w, vec = np.linalg.eigh(np.cov((foot - foot.mean(axis=0)).T))
		axis = vec[:, 1]
		elong = math.sqrt(max(w[1], 1e-12) / max(w[0], 1e-12))
		proj = (foot - leg_c) @ axis
		reach_front, reach_back = float(proj.max()), float(-proj.min())
		sign = 1.0 if reach_front >= reach_back else -1.0
		direction = unit(axis * sign) if elong >= h["min_foot_elongation"] else unit(offset)
		if direction is None:
			continue
		out.append({"dir_xz": r(direction), "elongation": r(elong), "reach_toe_m": r(max(reach_front, reach_back)),
			"reach_heel_m": r(min(reach_front, reach_back)), "offset_dir_xz": r(unit(offset)) if unit(offset) is not None else None})
	return out


def head_reach(P, hi_y, lo_y, height, toe):
	"""How far the head reaches in front of and behind the torso's axis along the toe direction (m).

	A face (nose, brow, cap bill, mask) sticks out further in front than the back of the skull behind, so a
	front reach at least the back reach confirms the toe direction. Returns (front, back) or None."""
	h = HEURISTICS
	head = P[P[:, 1] > hi_y - h["head_band_of_height"] * height][:, [0, 2]]
	t_lo, t_hi = h["torso_band_of_height"]
	torso = P[(P[:, 1] > lo_y + t_lo * height) & (P[:, 1] < lo_y + t_hi * height)][:, [0, 2]]
	if len(head) < 8 or len(torso) < 8:
		return None
	proj = (head - torso.mean(axis=0)) @ toe
	return float(proj.max()), float(-proj.min())


def angle_deg(a, b):
	return math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(a, b))))))


def facing_info(P):
	"""The model's facing from the toe and nose vertices (points in Godot space)."""
	h = HEURISTICS
	lo, hi = float(P[:, 1].min()), float(P[:, 1].max())
	height = hi - lo
	feet = foot_toe_dirs(P, lo, height)
	info = {"params": h, "toe": {"feet": feet, "dir_xz": None}, "nose": {"dir_xz": None}, "agreement_deg": None, "confidence": "none",
		"dir_xz": None, "yaw_deg_to_minus_z": None, "axis": None}
	if not feet:
		return info
	toe = unit(np.sum([f["dir_xz"] for f in feet], axis=0))
	if toe is None:
		return info
	info["toe"]["dir_xz"] = r(toe)
	if len(feet) == 2:
		info["toe"]["feet_agree_deg"] = r(angle_deg(np.array(feet[0]["dir_xz"]), np.array(feet[1]["dir_xz"])))
	info["confidence"] = "toe_only"
	reach = head_reach(P, hi, lo, height, toe)
	if reach is not None:
		front, back = reach
		ratio = front / max(back, 1e-9)
		nose = toe if front >= back else -toe
		info["nose"] = {"dir_xz": r(nose), "front_reach_m": r(front), "back_reach_m": r(back), "front_over_back": r(ratio)}
		info["agreement_deg"] = r(angle_deg(toe, nose))
		if back > front * h["nose_conflict_ratio"]:
			info["confidence"] = "conflict"
		elif ratio > 1.0:
			info["confidence"] = "high"
		else:
			info["confidence"] = "weak"
	fx, fz = float(toe[0]), float(toe[1])
	info["dir_xz"] = r([fx, fz])
	info["yaw_deg_to_minus_z"] = r(math.degrees(math.atan2(fx, -fz)))
	axes = {"+X": (1, 0), "-X": (-1, 0), "+Z": (0, 1), "-Z": (0, -1)}
	best = max(axes, key=lambda k: fx * axes[k][0] + fz * axes[k][1])
	info["axis"] = best if angle_deg(toe, np.array(axes[best], dtype=np.float64)) < 20.0 else "oblique"
	return info


def sides_info(bones, facing):
	left = [np.array(b["head"]) for b in bones if side_of(b["name"]) == "L"]
	right = [np.array(b["head"]) for b in bones if side_of(b["name"]) == "R"]
	info = {"left_bones": len(left), "right_bones": len(right), "left_minus_right_lateral_m": None, "consistent": None, "left_is_minus_x": None}
	if not left or not right:
		return info
	delta = np.mean(left, axis=0) - np.mean(right, axis=0)
	info["left_is_minus_x"] = bool(delta[0] < 0)
	if facing.get("dir_xz"):
		fx, fz = facing["dir_xz"]
		right_vec = np.array([-fz, fx])  # facing x up = the character's right, in the xz plane
		lateral = float(np.dot(delta[[0, 2]], right_vec))
		info["left_minus_right_lateral_m"] = r(lateral)
		info["consistent"] = bool(lateral < 0)
	return info


def names_info(bone_names):
	profile = set(profile_bones())
	return {"rig_table_missing": [n for n in RIG_BONES if n not in bone_names],
		"rig_table_extra": [n for n in bone_names if n not in RIG_BONES],
		"profile_matched": sum(1 for n in bone_names if n in profile),
		"profile_unmatched": [n for n in bone_names if n not in profile]}


# --------------------------------------------------------------------------- the dump

def dump(path):
	"""Load path and return the bones.json dictionary."""
	options = load(path)
	with open(path, "rb") as f:
		data = f.read()
	objects = []
	for obj in sorted(bpy.data.objects, key=lambda o: o.name):
		objects.append({"name": obj.name, "type": obj.type, "parent": obj.parent.name if obj.parent else None,
			"location": r(obj.location), "rotation_euler_deg": r([math.degrees(a) for a in obj.rotation_euler]), "scale": r(obj.scale)})
	armature_objs = sorted((o for o in bpy.data.objects if o.type == "ARMATURE"), key=lambda o: o.name)
	armatures = [armature_info(o) for o in armature_objs]
	bone_names = {b["name"] for a in armatures for b in a["bones"]}
	mesh_objs = sorted((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: o.name)
	meshes, clouds = [], []
	for obj in mesh_objs:
		info, points = mesh_info(obj, bone_names)
		meshes.append(info)
		clouds.append(points)
	materials, images = material_infos(mesh_objs)
	cloud = np.concatenate(clouds) if clouds else np.zeros((0, 3))
	totals = {}
	for m in meshes:
		for name, g in m["groups"].items():
			totals[name] = totals.get(name, 0) + g["count"]
	main_bones = max(armatures, key=lambda a: a["bone_count"])["bones"] if armatures else []
	for b in main_bones:
		b["weighted_verts"] = totals.get(b["name"], 0)
	facing = facing_info(cloud) if len(cloud) else {"dir_xz": None, "confidence": "none"}
	box = bbox(cloud)
	summary = {
		"triangles": sum(m["triangles"] for m in meshes), "vertices": sum(m["vertices"] for m in meshes), "bbox": box,
		"height_m": box["size"][1] if box["size"] else None, "feet_y": box["min"][1] if box["min"] else None,
		"bones": len(main_bones), "unweighted": sum(m["unweighted"] for m in meshes),
		"max_influences": max((m["max_influences"] for m in meshes), default=0), "over_four": sum(m["over_four"] for m in meshes),
		"bones_without_vertices": [b["name"] for b in main_bones if b["deform"] and b["weighted_verts"] == 0],
		# Blender's own glTF exporter, and Godot's importer, add a "neutral_bone" when any vertex has no weight: the contract forbids it.
		"neutral_bone": {"present": "neutral_bone" in bone_names, "weighted_verts": totals.get("neutral_bone", 0)},
	}
	return {
		"version": 1, "blender": bpy.app.version_string,
		"source": {"file": os.path.basename(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()},
		"import": options, "space": "godot: x right, y up, the rig faces -z; blender (x, y, z) -> (x, z, -y)",
		"objects": objects, "armatures": armatures, "meshes": meshes, "materials": materials, "images": images, "summary": summary,
		"facing": facing, "sides": sides_info(main_bones, facing), "names": names_info(bone_names),
	}


def write_json(report, out_path):
	os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
	with open(out_path, "w") as f:
		json.dump(report, f, indent="\t")
		f.write("\n")


def print_summary(report):
	s, f = report["summary"], report["facing"]
	print("DUMP %s: %d bones, %d meshes, %d tris, %d verts, %d unweighted, max %d influences, height %s m" % (
		report["source"]["file"], s["bones"], len(report["meshes"]), s["triangles"], s["vertices"], s["unweighted"], s["max_influences"], s["height_m"]))
	print("DUMP facing %s yaw_to_-z %s (%s), sides consistent=%s, names: %d/%d in the 56-bone profile, %d of the 23 rig bones missing, neutral_bone %s" % (
		f.get("axis"), f.get("yaw_deg_to_minus_z"), f.get("confidence"), report["sides"]["consistent"],
		report["names"]["profile_matched"], s["bones"], len(report["names"]["rig_table_missing"]), s["neutral_bone"]["present"]))


# --------------------------------------------------------------------------- self test

# A small humanoid authored in GODOT space (the rig's own conventions: 1.8 m, faces -z, left is -x).
TEST_JOINTS = [
	("Root", None, (0, 0, 0), (0, 0.975, 0)),
	("Hips", "Root", (0, 0.975, 0), (0, 1.075, 0)),
	("Spine", "Hips", (0, 1.075, 0), (0, 1.205, 0)),
	("Chest", "Spine", (0, 1.205, 0), (0, 1.485, 0)),
	("Neck", "Chest", (0, 1.485, 0), (0, 1.575, 0)),
	("Head", "Neck", (0, 1.575, 0), (0, 1.8, 0)),
	("LeftUpperArm", "Chest", (-0.22, 1.425, 0), (-0.22, 1.135, 0)),
	("LeftLowerArm", "LeftUpperArm", (-0.22, 1.135, 0), (-0.22, 0.865, 0)),
	("LeftHand", "LeftLowerArm", (-0.22, 0.865, 0), (-0.22, 0.76, 0)),
	("RightUpperArm", "Chest", (0.22, 1.425, 0), (0.22, 1.135, 0)),
	("RightLowerArm", "RightUpperArm", (0.22, 1.135, 0), (0.22, 0.865, 0)),
	("RightHand", "RightLowerArm", (0.22, 0.865, 0), (0.22, 0.76, 0)),
	("LeftUpperLeg", "Hips", (-0.11, 0.925, 0), (-0.11, 0.505, 0)),
	("LeftLowerLeg", "LeftUpperLeg", (-0.11, 0.505, 0), (-0.11, 0.085, 0)),
	("LeftFoot", "LeftLowerLeg", (-0.11, 0.085, 0), (-0.11, 0.035, -0.13)),
	("RightUpperLeg", "Hips", (0.11, 0.925, 0), (0.11, 0.505, 0)),
	("RightLowerLeg", "RightUpperLeg", (0.11, 0.505, 0), (0.11, 0.085, 0)),
	("RightFoot", "RightLowerLeg", (0.11, 0.085, 0), (0.11, 0.035, -0.13)),
]
# (bone, centre xyz, size xyz): each box is a cube subdivided TEST_CUTS times (a real mesh has rows of vertices
# along its limbs; the facing heuristic reads the leg's vertices), weighted 1.0 to its bone.
TEST_CUTS = 4
TEST_BOXES = [
	("Hips", (0, 1.0, 0), (0.30, 0.16, 0.18)),
	("Chest", (0, 1.30, 0), (0.36, 0.34, 0.20)),
	("Head", (0, 1.69, 0), (0.20, 0.22, 0.22)),
	("Head", (0, 1.67, -0.16), (0.04, 0.07, 0.10)),  # the nose: reaches z = -0.21, the head's front is -0.11
	("LeftUpperArm", (-0.22, 1.28, 0), (0.09, 0.29, 0.09)),
	("LeftLowerArm", (-0.22, 1.00, 0), (0.08, 0.27, 0.08)),
	("LeftHand", (-0.22, 0.81, 0), (0.09, 0.11, 0.06)),
	("RightUpperArm", (0.22, 1.28, 0), (0.09, 0.29, 0.09)),
	("RightLowerArm", (0.22, 1.00, 0), (0.08, 0.27, 0.08)),
	("RightHand", (0.22, 0.81, 0), (0.09, 0.11, 0.06)),
	("LeftUpperLeg", (-0.11, 0.715, 0), (0.14, 0.42, 0.14)),
	("LeftLowerLeg", (-0.11, 0.295, 0), (0.11, 0.42, 0.11)),
	("LeftFoot", (-0.11, 0.045, -0.07), (0.10, 0.09, 0.30)),  # heel z +0.08, toe z -0.22
	("RightUpperLeg", (0.11, 0.715, 0), (0.14, 0.42, 0.14)),
	("RightLowerLeg", (0.11, 0.295, 0), (0.11, 0.42, 0.11)),
	("RightFoot", (0.11, 0.045, -0.07), (0.10, 0.09, 0.30)),
]


def yaw_xz(p, degrees):
	"""Rotate a Godot-space point about +Y by `degrees` (Godot's convention)."""
	a = math.radians(degrees)
	x, y, z = p
	return (x * math.cos(a) + z * math.sin(a), y, -x * math.sin(a) + z * math.cos(a))


def build_test_glb(path, facing_yaw, swap_sides=False, five_influences=True):
	"""Author the test character rotated by facing_yaw degrees (0 = faces -z), export it as a GLB, return the truth."""
	import bmesh
	bpy.ops.wm.read_factory_settings(use_empty=True)

	def bl(p):
		"""Godot-space authored point -> Blender (x, -z, y)."""
		x, y, z = yaw_xz(p, facing_yaw)
		return (x, -z, y)

	def name_of(n):
		if swap_sides and (n.startswith("Left") or n.startswith("Right")):
			return ("Right" + n[4:]) if n.startswith("Left") else ("Left" + n[5:])
		return n

	arm_data = bpy.data.armatures.new("Armature")
	arm_obj = bpy.data.objects.new("Armature", arm_data)
	bpy.context.scene.collection.objects.link(arm_obj)
	bpy.context.view_layer.objects.active = arm_obj
	bpy.ops.object.mode_set(mode="EDIT")
	made = {}
	for name, parent, head, tail in TEST_JOINTS:
		eb = arm_data.edit_bones.new(name_of(name))
		eb.head, eb.tail = bl(head), bl(tail)
		if parent:
			eb.parent = made[parent]
		made[name] = eb
	bpy.ops.object.mode_set(mode="OBJECT")

	bm = bmesh.new()
	owner = []
	box_of = {}
	for box_index, (bone, centre, size) in enumerate(TEST_BOXES):
		start = len(bm.verts)
		cube = bmesh.ops.create_cube(bm, size=1.0)["verts"]
		bmesh.ops.subdivide_edges(bm, edges=list({e for v in cube for e in v.link_edges}), cuts=TEST_CUTS, use_grid_fill=True)
		bm.verts.ensure_lookup_table()
		for v in list(bm.verts)[start:]:
			sx, sy, sz = v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]
			# the box is authored in Godot axes (x, y, z); convert to Blender after the facing yaw
			v.co = Vector(bl((centre[0] + sx, centre[1] + sy, centre[2] + sz)))
			owner.append((v.index, bone))
			box_of[v.index] = box_index
	loose = [bm.verts.new(bl(p)) for p in ((0.6, 1.0, 0.0), (0.65, 1.0, 0.0), (0.6, 1.05, 0.0))]
	bm.faces.new(loose)  # three unweighted vertices, one triangle
	bm.verts.ensure_lookup_table()
	bm.faces.index_update()
	uv = bm.loops.layers.uv.new("UVMap")
	for face in bm.faces:
		for loop in face.loops:
			# one UV per box (a vertex keeps one UV, so the exporter splits nothing), alternating the two texels
			loop[uv].uv = (0.25, 0.5) if box_of.get(loop.vert.index, 0) % 2 == 0 else (0.75, 0.5)
		face.smooth = True
	me = bpy.data.meshes.new("Body")
	bm.to_mesh(me)
	tris_expected = sum(len(f.verts) - 2 for f in bm.faces)
	bm.free()
	obj = bpy.data.objects.new("Body", me)
	bpy.context.scene.collection.objects.link(obj)
	groups = {name_of(j[0]): obj.vertex_groups.new(name=name_of(j[0])) for j in TEST_JOINTS}
	assigned = {}  # group -> number of vertices with a live weight
	for index, bone in owner:
		groups[name_of(bone)].add([index], 1.0, "REPLACE")
		assigned[name_of(bone)] = assigned.get(name_of(bone), 0) + 1
	# the first Hips vertex is shared 50/50 with the Spine; one head vertex carries five influences
	hips_vertex = next(i for i, b in owner if b == "Hips")
	groups[name_of("Hips")].add([hips_vertex], 0.5, "REPLACE")
	groups[name_of("Spine")].add([hips_vertex], 0.5, "REPLACE")
	assigned[name_of("Spine")] = assigned.get(name_of("Spine"), 0) + 1
	if five_influences:
		head_vertex = next(i for i, b in owner if b == "Head")
		for b in ("Neck", "Head", "Chest", "Spine", "Hips"):
			groups[name_of(b)].add([head_vertex], 0.2, "REPLACE")
			if b != "Head":
				assigned[name_of(b)] = assigned.get(name_of(b), 0) + 1
	mod = obj.modifiers.new("Armature", "ARMATURE")
	mod.object = arm_obj
	obj.parent = arm_obj

	image = bpy.data.images.new("test_tex", 4, 4)
	px = []
	for y in range(4):
		for x in range(4):
			px += [0.0, 0.6, 0.6, 1.0] if x < 2 else [1.0, 0.8, 0.0, 1.0]
	image.pixels = px
	image.pack()
	mat = bpy.data.materials.new("TestMat")
	mat.use_nodes = True
	bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
	tex.image = image
	tex.interpolation = "Closest"
	mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	obj.data.materials.append(mat)

	bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(path)[0] + ".blend")
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_skins=True, export_influence_nb=4,
		export_all_influences=True, export_animations=False, export_apply=False, export_materials="EXPORT", export_texcoords=True)
	return {"tris": tris_expected, "bones": [name_of(j[0]) for j in TEST_JOINTS], "parents": {name_of(j[0]): (name_of(j[1]) if j[1] else None) for j in TEST_JOINTS},
		"heads": {name_of(j[0]): yaw_xz(j[2], facing_yaw) for j in TEST_JOINTS}, "unweighted": 3, "max_influences": 5 if five_influences else 2,
		"vertices": len(owner) + 3, "group_counts": assigned}


def self_test(workdir):
	failures = []

	def check(name, ok, detail=""):
		print("%s  %s%s" % ("ok  " if ok else "FAIL", name, ("  " + str(detail)) if detail and not ok else ""))
		if not ok:
			failures.append(name)

	cases = [("faces_minus_z", 0.0, False), ("faces_plus_x", -90.0, False), ("faces_plus_z_mirrored_names", 180.0, True)]
	reports = {}
	for label, yaw, swap in cases:
		glb = os.path.join(workdir, label + ".glb")
		truth = build_test_glb(glb, yaw, swap_sides=swap)
		out = os.path.join(workdir, label + "_bones.json")
		report = dump(glb)
		write_json(report, out)
		again = dump(glb)
		write_json(again, out + ".again")
		reports[label] = report
		print_summary(report)
		check(label + ": the dump is deterministic", open(out).read() == open(out + ".again").read())
		os.remove(out + ".again")
		bones = {b["name"]: b for a in report["armatures"] for b in a["bones"]}
		# Blender's glTF exporter adds a "neutral_bone" for the unweighted vertices; the dump must show it.
		check(label + ": %d bones plus the exporter's neutral_bone" % len(truth["bones"]), set(bones) == set(truth["bones"]) | {"neutral_bone"}, sorted(set(bones) ^ set(truth["bones"])))
		check(label + ": parents", all(bones[n]["parent"] == p for n, p in truth["parents"].items() if n in bones))
		worst = max(np.linalg.norm(np.array(bones[n]["head"]) - np.array(h)) for n, h in truth["heads"].items() if n in bones)
		check(label + ": bone heads within 0.1 mm of the authored joints (worst %.6f)" % worst, worst < 1e-4)
		s = report["summary"]
		mesh = report["meshes"][0]
		check(label + ": %d triangles" % truth["tris"], s["triangles"] == truth["tris"], s["triangles"])
		check(label + ": %d vertices (nothing split)" % truth["vertices"], s["vertices"] == truth["vertices"], s["vertices"])
		check(label + ": neutral_bone is reported with the 3 vertices that had no weight", s["neutral_bone"] == {"present": True, "weighted_verts": 3} and s["unweighted"] == 0, s["neutral_bone"])
		check(label + ": max influences %d, one vertex over 4" % truth["max_influences"], s["max_influences"] == truth["max_influences"] and s["over_four"] == 1, (s["max_influences"], s["over_four"]))
		counts = {g: c["count"] for g, c in mesh["groups"].items() if c["count"] and g != "neutral_bone"}
		check(label + ": per-group vertex counts equal the authored weights", counts == truth["group_counts"],
			{g: (counts.get(g), truth["group_counts"].get(g)) for g in set(counts) | set(truth["group_counts"]) if counts.get(g) != truth["group_counts"].get(g)})
		check(label + ": height 1.8 m", abs(s["height_m"] - 1.8) < 1e-3, s["height_m"])
		check(label + ": bones without vertices are only Root", set(s["bones_without_vertices"]) <= {"Root"}, s["bones_without_vertices"])
		check(label + ": the 23-name table reports its missing bones", "UpperChest" in report["names"]["rig_table_missing"] and "Hips" not in report["names"]["rig_table_missing"])
		check(label + ": one material with its base-colour image", len(report["materials"]) == 1 and report["materials"][0]["image"] is not None and len(report["images"]) == 1 and report["images"][0]["size"] == [4, 4] and report["images"][0]["packed"], report["materials"])
		colors = [c["rgb_hex_16_levels"] for c in (report["images"][0]["dominant_colors"] or [])]
		check(label + ": the texture's two colours are found", len(colors) == 2, colors)
		check(label + ": no absolute path in the file", workdir not in open(out).read())
	# The same character as the .blend it was authored in: nothing exported, so the unweighted vertices stay unweighted.
	blend = dump(os.path.join(workdir, "faces_minus_z.blend"))
	write_json(blend, os.path.join(workdir, "faces_minus_z_blend_bones.json"))
	s = blend["summary"]
	check("blend input: 3 unweighted vertices, no neutral_bone", s["unweighted"] == 3 and not s["neutral_bone"]["present"] and s["bones"] == 18, (s["unweighted"], s["neutral_bone"], s["bones"]))
	check("blend input: one vertex over 4 influences, max 5", s["over_four"] == 1 and s["max_influences"] == 5)
	check("blend input: every weighted vertex is normalised (the 50/50 and the 5 x 0.2 vertices sum to 1)",
		blend["meshes"][0]["not_normalized"] == 0, blend["meshes"][0]["not_normalized"])
	f0, f1, f2 = reports["faces_minus_z"]["facing"], reports["faces_plus_x"]["facing"], reports["faces_plus_z_mirrored_names"]["facing"]
	check("facing -Z: yaw 0 (got %s), axis %s, confidence %s" % (f0["yaw_deg_to_minus_z"], f0["axis"], f0["confidence"]),
		abs(f0["yaw_deg_to_minus_z"]) < 3 and f0["axis"] == "-Z" and f0["confidence"] == "high", f0["nose"])
	check("facing +X: yaw 90 (got %s), axis %s, %s" % (f1["yaw_deg_to_minus_z"], f1["axis"], f1["confidence"]), abs(f1["yaw_deg_to_minus_z"] - 90) < 3 and f1["axis"] == "+X" and f1["confidence"] == "high")
	check("facing +Z: yaw 180 (got %s), axis %s, %s" % (f2["yaw_deg_to_minus_z"], f2["axis"], f2["confidence"]), abs(abs(f2["yaw_deg_to_minus_z"]) - 180) < 3 and f2["axis"] == "+Z" and f2["confidence"] == "high")
	check("the head reaches further in front than behind (nose 0.21 m vs back 0.11 m)", all(f["nose"]["front_over_back"] > 1.5 for f in (f0, f1, f2)), [f["nose"] for f in (f0, f1, f2)])
	check("sides: Left bones on the character's left (-Z and +X cases)", reports["faces_minus_z"]["sides"]["consistent"] is True and reports["faces_plus_x"]["sides"]["consistent"] is True, reports["faces_minus_z"]["sides"])
	check("sides: swapped names are reported as inconsistent", reports["faces_plus_z_mirrored_names"]["sides"]["consistent"] is False, reports["faces_plus_z_mirrored_names"]["sides"])
	check("sides: facing -Z, the Left bones are at -x", reports["faces_minus_z"]["sides"]["left_is_minus_x"] is True)
	print("\n%s" % ("blender_dump_rig self-test passed" if not failures else "blender_dump_rig self-test FAILED: " + ", ".join(failures)))
	return 0 if not failures else 1


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	try:
		if argv and argv[0] == "--self-test":
			keep = len(argv) > 1
			workdir = os.path.abspath(argv[1]) if keep else tempfile.mkdtemp(prefix="dump_rig_selftest_")
			os.makedirs(workdir, exist_ok=True)
			try:
				code = self_test(workdir)
			finally:
				if not keep:
					shutil.rmtree(workdir, ignore_errors=True)
			sys.exit(code)
		if len(argv) != 2:
			print(__doc__)
			sys.exit(2)
		report = dump(os.path.abspath(argv[0]))
		write_json(report, argv[1])
		print_summary(report)
	except SystemExit:
		raise
	except Exception:
		traceback.print_exc()
		sys.exit(2)


if __name__ == "__main__":
	main()
