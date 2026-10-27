"""Step 4 of the chain: part replacement and the first-person split (M4-plan Part C section 5 step 4, Part A A2).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_parts.py -- <pipeline.json> replace
	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_parts.py -- <pipeline.json> split

replace: reads work/03_rig.blend, writes work/04_parts.blend. The rig has no fingers, so a hand is always a fist: the faces
	dominated by each Hand bone are deleted and a Blender-made rounded fist (no credits) takes their place:
	a rounded block of the fist box (0.1 x 0.118 x 0.116 m, centred 0.065 m below the wrist, taken from joints.json),
	four knuckle bumps on the striking face, a thumb on the front, and a cuff-and-strap ring over the cut weighted
	Hand/LowerArm so it blends into the forearm. It is built hanging, then swung with the arm (the A-pose chain) and placed
	at the Hand joint. Weights are 100% Hand (the cuff ramps to LowerArm). New faces carry the palette slot to use
	(face attribute pipe_slot = slot + 1; 0 = take it from the texture), so the palette step needs no texture for them.
	parts.fists: {enabled, glove_slot, strap_slot, strap_height_m, cuff_margin_m, cuff_over_m, bevel_m, bump_m}.

split: reads work/05_palette.blend, writes work/06_split.blend. For the player's first-person body (parts.split_fp.enabled):
	the hidden part Body__fp_hidden = Chest and above, both Shoulders and the shoulder half of each upper arm (the cuts
	are planes: a horizontal one at the Chest joint, one across each upper arm at upper_arm_cut of its length, found by
	bisecting so every loop is clean); the visible Body keeps everything else, and EVERY open loop of it (waist, both
	upper arms) is closed with an inward rounded cap (cap_depth_m deep, cap_rings rings) so a look down the belly is never
	hollow. Caps carry the neighbouring faces' palette UV and face attribute pipe_cap. The two parts keep all 23 groups.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
from blender_fit import rotation_between  # noqa: E402

NAMES = pc.bone_names()
SLOT_ATTR = "pipe_slot"
CAP_ATTR = "pipe_cap"


# --------------------------------------------------------------------------- primitives (numpy)

def rounded_box(half, radius, cuts=7):
	"""(verts, tri faces) of a rounded box with the given half extents (closed, outward normals)."""
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=2.0)
	bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
	hx, hy, hz = half
	inner = np.array([hx - radius, hy - radius, hz - radius])
	for v in bm.verts:
		p = np.array([v.co.x * hx, v.co.y * hy, v.co.z * hz])
		c = np.clip(p, -inner, inner)
		d = p - c
		ln = np.linalg.norm(d)
		if ln > 1e-9:
			p = c + d / ln * radius
		v.co = Vector(p)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	co = np.array([tuple(v.co) for v in bm.verts])
	faces = [tuple(v.index for v in f.verts) for f in bm.faces]
	bm.free()
	return co, faces


def ellipsoid(center, radii, u_seg=10, v_seg=6):
	co = [tuple(np.array(center) + np.array([0, 0, -radii[2]]))]
	for j in range(1, v_seg):
		th = math.pi * j / v_seg
		for i in range(u_seg):
			ph = 2 * math.pi * i / u_seg
			co.append(tuple(np.array(center) + np.array([radii[0] * math.sin(th) * math.cos(ph), radii[1] * math.sin(th) * math.sin(ph), -radii[2] * math.cos(th)])))
	co.append(tuple(np.array(center) + np.array([0, 0, radii[2]])))
	faces = []
	for i in range(u_seg):
		faces.append((0, 1 + (i + 1) % u_seg, 1 + i))
	for j in range(v_seg - 2):
		for i in range(u_seg):
			a, b = 1 + j * u_seg + i, 1 + j * u_seg + (i + 1) % u_seg
			faces.append((a, b, b + u_seg, a + u_seg))
	last = len(co) - 1
	for i in range(u_seg):
		faces.append((last, 1 + (v_seg - 2) * u_seg + i, 1 + (v_seg - 2) * u_seg + (i + 1) % u_seg))
	return np.array(co), faces


def tube(center_xy, radius, z_top, z_bottom, segs=16, rings=6, radius_bottom=None):
	"""A closed cylinder along z from z_top down to z_bottom (outward normals), with fan caps. The radius is constant over
	the upper half and tapers to radius_bottom over the lower half (the cuff flares into the forearm, narrows to the fist)."""
	radius_bottom = radius if radius_bottom is None else radius_bottom
	co = [(center_xy[0], center_xy[1], z_top)]
	for j in range(rings + 1):
		z = z_top + (z_bottom - z_top) * j / rings
		r = radius + (radius_bottom - radius) * min(1.0, max(0.0, (j / rings - 0.3) / 0.4))
		for i in range(segs):
			ph = 2 * math.pi * i / segs
			co.append((center_xy[0] + r * math.cos(ph), center_xy[1] + r * math.sin(ph), z))
	co.append((center_xy[0], center_xy[1], z_bottom))
	faces = []
	for i in range(segs):
		faces.append((0, 1 + i, 1 + (i + 1) % segs))
	for j in range(rings):
		for i in range(segs):
			a, b = 1 + j * segs + i, 1 + j * segs + (i + 1) % segs
			faces.append((a, a + segs, b + segs, b))
	last = len(co) - 1
	base = 1 + rings * segs
	for i in range(segs):
		faces.append((last, base + (i + 1) % segs, base + i))
	return np.array(co), faces


class Acc:
	"""Accumulates primitives into one vertex/face list with a slot per face and a weight ramp per vertex."""

	def __init__(self):
		self.co, self.faces, self.slot, self.part = [], [], [], []

	def add(self, co, faces, slot, part):
		base = len(self.co)
		self.co += [tuple(c) for c in co]
		self.part += [part] * len(co)
		self.faces += [tuple(i + base for i in f) for f in faces]
		self.slot += [slot] * len(faces)


def fist_geometry(cfg_f, table_box, cuff_radius, cuff_top_z, cuff_bottom_z):
	"""The fist in the HANGING frame, origin at the wrist (Blender axes: x lateral, y forward, z up). Returns an Acc."""
	size = table_box["size"]  # Godot (x, y, z) -> Blender extents (x, z, y)
	off = table_box["center_offset"]
	center = np.array([off[0], -off[2], off[1]])
	half = np.array([size[0] / 2, size[2] / 2, size[1] / 2])
	inset, bump = cfg_f.get("bump_m", 0.006) / 2.0, cfg_f.get("bump_m", 0.006)
	acc = Acc()
	block_half = half - inset
	co, faces = rounded_box(tuple(block_half), cfg_f.get("bevel_m", 0.022))
	acc.add(co + center, faces, cfg_f["glove_slot"], "block")
	bottom_z = center[2] - block_half[2]
	for k in range(4):  # the knuckle row: four bumps front to back on the striking face
		y = center[1] + block_half[1] * (-0.62 + 0.413 * k)
		co, faces = ellipsoid((center[0], y, bottom_z + bump * 0.2), (0.016, 0.014, bump * 1.4))
		acc.add(co, faces, cfg_f["glove_slot"], "knuckle")
	co, faces = ellipsoid((center[0] - 0.004, center[1] + block_half[1] - bump * 0.3, center[2] + 0.018), (0.022, bump * 1.6, 0.034))
	acc.add(co, faces, cfg_f["glove_slot"], "thumb")
	r_bottom = min(cuff_radius, block_half[0] + 0.004)
	co, faces = tube((0.0, center[1] - 0.004), cuff_radius, cuff_top_z, cuff_bottom_z, radius_bottom=r_bottom)
	acc.add(co, faces, cfg_f["glove_slot"], "cuff")
	strap_top = center[2] + block_half[2] - 0.003 + 0.0
	co, faces = tube((0.0, center[1] - 0.004), r_bottom + 0.003, strap_top, strap_top - cfg_f.get("strap_height_m", 0.03) * 0.8, rings=2)
	acc.add(co, faces, cfg_f["strap_slot"], "strap")
	return acc, (cuff_top_z, cuff_bottom_z)


def replace_hands(cfg, extra):
	pf = cfg["parts"]["fists"]
	pb.open_blend(pc.work_path(cfg, "03_rig.blend"))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	dirs = {k: np.array(v) for k, v in pb.scene_prop("pipe_dirs").items()}
	targets = pb.scene_prop("pipe_targets")
	table_boxes = {b["side"]: b for b in pc.table()["fist_boxes"]}
	if not pf.get("enabled", True):
		pb.save_blend(pc.work_path(cfg, "04_parts.blend"))
		return {"enabled": False}
	co = pb.verts(me)
	w = pb.weights_matrix(body, NAMES)
	start, total, lv = pb.poly_arrays(me)
	face_hand = np.zeros(len(start), dtype=bool)
	hand_cols = {side: NAMES.index(side + "Hand") for side in pc.SIDES}
	deleted = {}
	fh = np.zeros((len(start), 2))
	for k in range(int(total.max())):
		mask = total > k
		for si, side in enumerate(pc.SIDES):
			fh[mask, si] += w[lv[start[mask] + k], hand_cols[side]]
	for si, side in enumerate(pc.SIDES):
		sel = (fh[:, si] / np.maximum(total, 1)) > 0.5
		deleted[side] = int(sel.sum())
		face_hand |= sel

	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(face_hand)[0]], context="FACES")
	loose = [v for v in bm.verts if not v.link_faces]
	if loose:
		bmesh.ops.delete(bm, geom=loose, context="VERTS")
	bm.to_mesh(me)
	bm.free()
	me.update()

	# the boundary of each cut: along-axis range and radius, in the arm's own frame
	co = pb.verts(me)
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.edges.ensure_lookup_table()
	boundary = set()
	for e in bm.edges:
		if len(e.link_faces) == 1:
			boundary.add(e.verts[0].index)
			boundary.add(e.verts[1].index)
	bm.free()
	boundary = np.array(sorted(boundary), dtype=np.int64)
	made = {}
	cuts = {}
	fists = []
	for side in pc.SIDES:
		p_hand = np.array(targets[side + "Hand"]["head"])
		d = dirs[side]
		near = boundary[np.linalg.norm(co[boundary] - p_hand, axis=1) < 0.2] if len(boundary) else boundary
		if len(near) < 6:
			cuts[side] = {"note": "no open boundary near the hand: the fist is placed without a cut"}
			a0, r_cut = 0.0, 0.05
		else:
			a = (co[near] - p_hand) @ d
			radial = np.linalg.norm((co[near] - p_hand) - np.outer(a, d), axis=1)
			a0, r_cut = float(a.min()), float(np.percentile(radial, 90))
			cuts[side] = {"boundary_vertices": int(len(near)), "a_min_m": a0, "a_max_m": float(a.max()), "radius_m": r_cut}
		cuff_r = max(r_cut, 0.05) + pf.get("cuff_margin_m", 0.008)
		z_top = -(min(a0, 0.0) - pf.get("cuff_over_m", 0.035))
		z_bottom = -pf.get("cuff_below_wrist_m", 0.012)
		acc, (zt, zb) = fist_geometry(pf, table_boxes[side], cuff_r, z_top, z_bottom)
		R = rotation_between(np.array(pc.HANGING), d)
		world = (np.array(acc.co) @ R.T) + p_hand
		obj = pb.new_mesh_object("Fist" + side, world, acc.faces)
		fm = obj.data
		slot_attr = fm.attributes.new(SLOT_ATTR, "INT", "FACE")
		slot_attr.data.foreach_set("value", np.array(acc.slot, dtype=np.int32) + 1)
		fw = np.zeros((len(acc.co), len(NAMES)))
		part = np.array(acc.part)
		local_z = np.array(acc.co)[:, 2]
		hc, lc = NAMES.index(side + "Hand"), NAMES.index(side + "LowerArm")
		fw[:, hc] = 1.0
		cuff = part == "cuff"
		t = np.clip((zt - local_z[cuff]) / max(zt - zb, 1e-6), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		fw[cuff, hc] = t
		fw[cuff, lc] = 1.0 - t
		pb.write_weights(obj, NAMES, fw)
		for p in fm.polygons:
			p.use_smooth = True
		made[side] = obj
		fists.append(obj)
		cuts[side].update({"cuff_radius_m": cuff_r, "cuff_z_top": zt, "cuff_z_bottom": zb, "fist_triangles": len(acc.faces), "faces_deleted": deleted[side]})
	# the Body's own face attribute pipe_slot: 0 everywhere (take the slot from the texture)
	if SLOT_ATTR not in me.attributes:
		a = me.attributes.new(SLOT_ATTR, "INT", "FACE")
		a.data.foreach_set("value", np.zeros(len(me.polygons), dtype=np.int32))
	pb.activate(body)
	for o in fists:
		o.select_set(True)
	bpy.ops.object.join()
	body = bpy.context.view_layer.objects.active
	body.name = pb.BODY
	pb.attach_armature(body, bpy.data.objects[pb.ARMATURE])
	for p in body.data.polygons:
		p.use_smooth = True

	# A5 on the work file: fist vertices (Hand weight >= 0.9) un-swung into the table's frame
	co = pb.verts(body.data)
	w = pb.weights_matrix(body, NAMES)
	fist_check = {}
	for side in pc.SIDES:
		sel = w[:, NAMES.index(side + "Hand")] >= 0.9
		p_hand = np.array(targets[side + "Hand"]["head"])
		R = rotation_between(np.array(pc.HANGING), dirs[side])
		rest = (co[sel] - p_hand) @ R + np.array(pc.table_joints()[side + "Hand"])
		box = table_boxes[side]
		bc = np.array(pc.g2b(box["center_rest_global"]))
		ext = rest.max(axis=0) - rest.min(axis=0)
		want = np.array([box["size"][0], box["size"][2], box["size"][1]])
		fist_check[side] = {"vertices": int(sel.sum()), "centroid_offset_m": float(np.linalg.norm(rest.mean(axis=0) - bc)),
			"bbox_centre_offset_m": float(np.linalg.norm((rest.max(axis=0) + rest.min(axis=0)) / 2 - bc)),
			"extent_ratio": (ext / want).tolist()}
	pb.save_blend(pc.work_path(cfg, "04_parts.blend"))
	return {"enabled": True, "cuts": cuts, "fist_check": fist_check, "triangles_after": pb.triangle_count(body.data)}


TORSO_SET = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]


def dominant_per_face(me, w):
	"""Bone column of the largest summed weight per face (n_faces,)."""
	start, total, lv = pb.poly_arrays(me)
	acc = np.zeros((len(start), w.shape[1]))
	for k in range(int(total.max())):
		mask = total > k
		acc[mask] += w[lv[start[mask] + k]]
	return np.argmax(acc, axis=1)


def boundary_loops(bm):
	"""Ordered lists of BMVerts, one per closed boundary loop, in the direction of the surrounding faces' winding."""
	seen = set()
	loops = []
	for e in bm.edges:
		if not e.is_boundary or e.index in seen:
			continue
		start_loop = e.link_loops[0]
		order = []
		l = start_loop
		guard = 0
		while guard < 100000:
			guard += 1
			seen.add(l.edge.index)
			order.append(l)
			nxt = l.link_loop_next
			steps = 0
			while not nxt.edge.is_boundary and steps < 1000:
				nxt = nxt.link_loop_radial_next.link_loop_next
				steps += 1
			l = nxt
			if l == start_loop or l.edge.index in seen:
				break
		if len(order) >= 3:
			loops.append(order)
	return loops


def split_fp(cfg, extra):
	sc = cfg["parts"].get("split_fp", {})
	pb.open_blend(pc.work_path(cfg, "05_palette.blend"))
	body = bpy.data.objects[pb.BODY]
	if not sc.get("enabled", False):
		pb.save_blend(pc.work_path(cfg, "06_split.blend"))
		return {"enabled": False}
	targets = pb.scene_prop("pipe_targets")
	me = body.data
	w = pb.weights_matrix(body, NAMES)
	dom = dominant_per_face(me, w)
	col = {n: i for i, n in enumerate(NAMES)}
	z_cut = targets[sc.get("torso_cut_bone", "Chest")]["head"][2]
	cut_t = float(sc.get("upper_arm_cut", 0.5))
	arm_axes = {}
	for side in pc.SIDES:
		ua, la = np.array(targets[side + "UpperArm"]["head"]), np.array(targets[side + "LowerArm"]["head"])
		arm_axes[side] = (ua, la - ua, float(np.linalg.norm(la - ua)))

	# ----- bisect: the torso along z = z_cut, each upper arm across its axis at upper_arm_cut
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	torso_cols = [col[n] for n in TORSO_SET]
	torso_faces = [bm.faces[i] for i in np.nonzero(np.isin(dom, torso_cols))[0]]
	arm_faces = {side: [bm.faces[i] for i in np.nonzero(dom == col[side + "UpperArm"])[0]] for side in pc.SIDES}
	geom = list(torso_faces) + list({e for f in torso_faces for e in f.edges}) + list({v for f in torso_faces for v in f.verts})
	bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=(0.0, 0.0, z_cut), plane_no=(0.0, 0.0, 1.0))
	for side in pc.SIDES:
		ua, axis, length = arm_axes[side]
		faces = [f for f in arm_faces[side] if f.is_valid]
		geom = list(faces) + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
		bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=tuple(ua + axis * cut_t), plane_no=tuple(axis / length))
	bm.to_mesh(me)
	bm.free()
	me.update()

	# ----- classify and separate
	w = pb.weights_matrix(body, NAMES)
	dom = dominant_per_face(me, w)
	centers = pb.face_centers(me)
	hidden = np.zeros(len(me.polygons), dtype=bool)
	torso_mask = np.isin(dom, torso_cols)
	hidden |= torso_mask & (centers[:, 2] > z_cut)
	for side in pc.SIDES:
		ua, axis, length = arm_axes[side]
		t = ((centers - ua) @ axis) / (length * length)
		zone = np.isin(dom, [col[side + "UpperArm"], col[side + "Shoulder"]])
		hidden |= zone & (t < cut_t)
	for p in me.polygons:
		p.select = bool(hidden[p.index])
	pb.activate(body)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_mode(type="FACE")
	bpy.ops.mesh.select_all(action="DESELECT")
	bpy.ops.object.mode_set(mode="OBJECT")
	for p in me.polygons:
		p.select = bool(hidden[p.index])
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.separate(type="SELECTED")
	bpy.ops.object.mode_set(mode="OBJECT")
	parts = [o for o in bpy.data.objects if o.type == "MESH"]
	hid = next(o for o in parts if o != body)
	hid.name = pb.BODY_HIDDEN
	hid.data.name = pb.BODY_HIDDEN
	body = bpy.data.objects[pb.BODY]

	# ----- inward rounded caps on every open loop of the visible part
	me = body.data
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	dl = bm.verts.layers.deform.verify()
	uv_p = bm.loops.layers.uv["palette"]
	uv_d = bm.loops.layers.uv.get("detail")
	cap_attr = bm.faces.layers.int.new(CAP_ATTR)
	depth = float(sc.get("cap_depth_m", 0.03))
	rings = int(sc.get("cap_rings", 4))
	loops = boundary_loops(bm)
	cap_report = []
	for order in loops:
		verts = [l.vert for l in order]
		pts = np.array([tuple(v.co) for v in verts])
		c = pts.mean(axis=0)
		nrm = np.zeros(3)
		for i in range(len(pts)):
			nrm += np.cross(pts[i] - c, pts[(i + 1) % len(pts)] - c)
		ln = np.linalg.norm(nrm)
		if ln < 1e-12:
			continue
		n_in = nrm / ln
		adj = np.mean([np.mean([tuple(v.co) for v in l.face.verts], axis=0) for l in order], axis=0)
		flipped = float((adj - c) @ n_in) < 0.0
		if flipped:
			n_in = -n_in
		ring_verts = [verts]
		for k in range(1, rings):
			phi = math.pi / 2 * k / rings
			ring = []
			for v in verts:
				p = np.array(tuple(v.co))
				q = bm.verts.new(tuple(c + n_in * depth * math.sin(phi) + (p - c) * math.cos(phi)))
				for g, wt in v[dl].items():
					q[dl][g] = wt
				ring.append(q)
			ring_verts.append(ring)
		apex = bm.verts.new(tuple(c + n_in * depth))
		acc = {}
		for v in verts:
			for g, wt in v[dl].items():
				acc[g] = acc.get(g, 0.0) + wt / len(verts)
		for g, wt in acc.items():
			apex[dl][g] = wt
		n = len(verts)
		made = []
		for k in range(1, rings):
			for i in range(n):
				a0, b0 = ring_verts[k - 1][i], ring_verts[k - 1][(i + 1) % n]
				a1, b1 = ring_verts[k][i], ring_verts[k][(i + 1) % n]
				made.append((bm.faces.new((b0, a0, a1, b1)), order[i]))
		for i in range(n):
			a, b = ring_verts[rings - 1][i], ring_verts[rings - 1][(i + 1) % n]
			made.append((bm.faces.new((b, a, apex)), order[i]))
		for f, src in made:
			f.smooth = True
			f[cap_attr] = 1
			src_uv = src.face.loops[0][uv_p].uv.copy()
			for lp in f.loops:
				lp[uv_p].uv = src_uv
				if uv_d is not None:
					lp[uv_d].uv = (0.0, 0.0)
		cap_report.append({"vertices": n, "centre": c.tolist(), "dir_in": n_in.tolist(), "orientation_flipped": flipped, "tris": 2 * n * (rings - 1) + n})
	bm.to_mesh(me)
	bm.free()
	me.update()
	pb.attach_armature(body, bpy.data.objects[pb.ARMATURE])
	pb.attach_armature(hid, bpy.data.objects[pb.ARMATURE])
	over_four = 0
	for o in (body, hid):
		# bisecting and the caps interpolate weights across edges: back to at most 4 normalised influences
		ww = pb.weights_matrix(o, NAMES)
		over_four += int(((ww > 1e-4).sum(axis=1) > 4).sum())
		pb.write_weights(o, NAMES, pb.limit_and_normalize(ww, int(cfg.get("rig", {}).get("max_influences", 4))), remove_others=True)
		for p in o.data.polygons:
			p.use_smooth = True
	pb.save_blend(pc.work_path(cfg, "06_split.blend"))
	hc = pb.verts(hid.data)
	return {"enabled": True, "z_cut_m": z_cut, "upper_arm_cut": cut_t, "hidden_faces": int(hidden.sum()), "visible_triangles": pb.triangle_count(body.data),
		"hidden_triangles": pb.triangle_count(hid.data), "vertices_over_four_influences_before_limit": over_four, "caps": cap_report, "hidden_bbox": {"min": hc.min(axis=0).tolist(), "max": hc.max(axis=0).tolist()}}


if __name__ == "__main__":
	mode = pc.step_argv()[1] if len(pc.step_argv()) > 1 else "replace"
	pb.run_step("parts", replace_hands if mode == "replace" else split_fp)
