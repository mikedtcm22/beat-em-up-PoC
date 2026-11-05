"""Step 5 of the chain: palette colours, border-protected decimation, palette UVs (M4-plan Part C section 5 step 4).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_palette.py -- <pipeline.json>

Reads work/04_parts.blend, writes work/05_palette.blend. SPEC section 10: every character is flat colours looked up in the
shared atlas (assets/export/palette/palette_atlas.png, built by gen_palette.py), so the dense, textured body becomes a
low-poly body whose every face sits on one swatch:

	1. label: each face of the dense mesh takes the nearest swatch (Lab, among config palette.slots) to the texture colour
	   around its UV centre (a 3x3 texel box); faces that carry pipe_slot (the fists, from blender_parts) take that slot;
	2. prune swatches: the least used swatch is folded into the next nearest until at most palette.max_swatches remain and
	   none is under palette.min_share of the surface;
	3. majority filter: palette.majority_passes passes, a face flips to the label most of its neighbours share;
	4. relax the border loops: the vertices where two labels meet are smoothed along the border (iterations, factor), so a
	   colour edge is not a staircase; fist vertices stay put;
	   (M6 FB-DETAIL: palette.min_island_area_m2, a patch of one label smaller than that takes its neighbours' label);
	5. decimate (Collapse) to palette.budget_tris with the border vertices and the part-replacement vertices PROTECTED, so
	   the colour borders keep their resolution and the fists their shape (a protected-position survival check is reported);
	6. relabel every face of the decimated mesh from the nearest face of the dense one (BVH), then give every face its swatch
	   centre as UV1 "palette" (u, v from gen_palette.uv_of_slot); with palette.detail_uv a second layer "detail" (UV2,
	   smart-projected: the player's 1k ink mask is painted on it).
The source texture and materials are dropped: the game draws the atlas.

F-punk's additions (all opt-in by config, so the probe and the player run as before):
	palette.regions: faces of a slot inside a box take another slot (the Punk's lens: the cap's yellow in front of the eyes,
	  on its own swatch that takes no damage marks; the cap's strap slot: a dark arch of two boxes). A region with bisect_z
	  and/or bisect_x cuts the mesh along the box's horizontal and/or vertical planes first, so its borders run along edge
	  loops and survive the decimation straight;
	faces with the pipe_fist attribute (generated fists, blender_parts) are decimated on their own to
	  palette.fist_budget_tris each, the rest of the body to the budget less both fists (their borders still protected);
	palette.unfold: relax the folded triangles of the decimated mesh away (pipe_cleanup.unfold) and report the counts;
	palette.detail_bake: the 1k ink-only detail mask on UV2 baked from the dense texture (pipe_detail.bake, plan A18; G holds the lens's
	  glint-gate streaks when `glint` is set, and the glove's authored lines when `glove_lines` is); its
	  no_ink_slots (the lens) get no ink, and so does a zone with "no_ink": true (the Punk's laces and cap: the generated
	  texture's noise there is not a line, and the colour border already gives the shape);
	palette.detail_bake.crease (M6 FB-DETAIL): the dense mesh's sharp edges as ink (pipe_detail.crease_field), a zone's crease_deg per face.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import gen_palette as gp  # noqa: E402
import pipe_cleanup  # noqa: E402
import pipe_detail  # noqa: E402

SLOT_ATTR = "pipe_slot"
FIST_ATTR = "pipe_fist"
BAND_ATTR = "pipe_band"
COLLAR_ATTR = "pipe_collar"


def srgb_to_lab(rgb):
	"""rgb (n, 3) in 0..1 sRGB -> CIE Lab (D65)."""
	c = np.asarray(rgb, dtype=np.float64)
	lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
	xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
	f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
	return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def source_image(body):
	for mat in body.data.materials:
		if mat and mat.use_nodes:
			for n in mat.node_tree.nodes:
				if n.type == "TEX_IMAGE" and n.image is not None:
					return n.image
	return None


def edge_faces(me):
	"""(edge -> list of face indices) from the loops."""
	start, total, lv = pb.poly_arrays(me)
	le = np.empty(len(me.loops), dtype=np.int32)
	me.loops.foreach_get("edge_index", le)
	owner = np.repeat(np.arange(len(start)), total)
	pairs = {}
	for loop_i, (f, e) in enumerate(zip(owner, le)):
		pairs.setdefault(int(e), []).append(int(f))
	return pairs


def neighbours(me):
	pairs = edge_faces(me)
	nb = [[] for _ in range(len(me.polygons))]
	for faces in pairs.values():
		if len(faces) == 2:
			nb[faces[0]].append(faces[1])
			nb[faces[1]].append(faces[0])
	return nb, pairs


def sample_texture(pix, w, h, uv, box=1):
	"""Mean colour of a (2 box + 1)^2 texel window around each uv (n, 2) in 0..1 (Blender uv, origin bottom left)."""
	x = np.clip((uv[:, 0] * w).astype(np.int64), 0, w - 1)
	y = np.clip((uv[:, 1] * h).astype(np.int64), 0, h - 1)
	acc = np.zeros((len(uv), 3))
	cnt = 0
	for dy in range(-box, box + 1):
		for dx in range(-box, box + 1):
			acc += pix[np.clip(y + dy, 0, h - 1), np.clip(x + dx, 0, w - 1), :3]
			cnt += 1
	return acc / cnt


def decimate_trial(body, ratio, group, invert):
	"""Apply a Collapse decimation to a COPY of body and return (copy object, triangle count)."""
	dup = body.copy()
	dup.data = body.data.copy()
	pb.link(dup)
	for m in list(dup.modifiers):
		dup.modifiers.remove(m)
	mod = dup.modifiers.new("Decimate", "DECIMATE")
	mod.decimate_type = "COLLAPSE"
	mod.ratio = float(min(max(ratio, 0.01), 1.0))
	mod.use_collapse_triangulate = True
	mod.vertex_group = group
	mod.invert_vertex_group = invert
	mod.vertex_group_factor = 1.0
	pb.activate(dup)
	bpy.ops.object.modifier_apply(modifier="Decimate")
	return dup, pb.triangle_count(dup.data)


def run(cfg, extra):
	pc_cfg = cfg["palette"]
	pb.open_blend(pc.work_path(cfg, "04_parts.blend"))  # the static-prop path's inspect step writes this name too
	body = bpy.data.objects[pb.BODY]
	me = body.data
	bm = bmesh.new()
	bm.from_mesh(me)
	# regions with "bisect_z": the mesh is cut along the box's two horizontal planes (inside its x/y span) first, so the colour
	# border runs along an edge loop and survives the decimation straight
	cuts_made = []
	for reg in pc_cfg.get("regions", []):
		if not reg.get("bisect_z") and not reg.get("bisect_x"):
			continue
		for plane_z in ((reg["min"][2], reg["max"][2]) if reg.get("bisect_z") else ()):
			geom_faces = []
			for f in bm.faces:
				c = f.calc_center_median()
				if reg["min"][0] <= c.x <= reg["max"][0] and reg["min"][1] <= c.y <= reg["max"][1] and abs(c.z - plane_z) < 0.03:
					geom_faces.append(f)
			geom = list(geom_faces) + sorted({e for f in geom_faces for e in f.edges}, key=lambda e: e.index) + sorted({v for f in geom_faces for v in f.verts}, key=lambda v: v.index)
			before = len(bm.faces)
			bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=(0.0, 0.0, plane_z), plane_no=(0.0, 0.0, 1.0))
			cuts_made.append({"region": reg.get("name", ""), "z": plane_z, "faces_before": before, "faces_after": len(bm.faces)})
		# the vertical planes (the strap slot's sides), cut after the horizontal ones so the faces they pass are already small:
		# the cut runs the box's height plus a margin (a face straddling a corner is cut too, so the corner is a vertex)
		margin_z = 0.01
		for plane_x in ((reg["min"][0], reg["max"][0]) if reg.get("bisect_x") else ()):
			geom_faces = []
			for f in bm.faces:
				c = f.calc_center_median()
				if reg["min"][1] <= c.y <= reg["max"][1] and reg["min"][2] - margin_z <= c.z <= reg["max"][2] + margin_z and abs(c.x - plane_x) < 0.03:
					geom_faces.append(f)
			geom = list(geom_faces) + sorted({e for f in geom_faces for e in f.edges}, key=lambda e: e.index) + sorted({v for f in geom_faces for v in f.verts}, key=lambda v: v.index)
			before = len(bm.faces)
			bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=(plane_x, 0.0, 0.0), plane_no=(1.0, 0.0, 0.0))
			cuts_made.append({"region": reg.get("name", ""), "x": plane_x, "faces_before": before, "faces_after": len(bm.faces)})
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.to_mesh(me)
	bm.free()
	me.update()
	n_faces = len(me.polygons)
	co = pb.verts(me)
	start, total, lv = pb.poly_arrays(me)
	areas = pb.face_areas(me)
	swatches = gp.swatches()
	slots = list(pc_cfg["slots"])
	cand_rgb = np.array([[c / 255.0 for c in swatches[s]["rgba"][:3]] for s in slots])
	cand_lab = srgb_to_lab(cand_rgb)

	# ----- 1. label from the texture
	override = np.zeros(n_faces, dtype=np.int32)
	if SLOT_ATTR in me.attributes:
		me.attributes[SLOT_ATTR].data.foreach_get("value", override)
	image = source_image(body)
	uv_loops = np.empty(len(me.loops) * 2, dtype=np.float32)
	if me.uv_layers:
		me.uv_layers[0].data.foreach_get("uv", uv_loops)
	uv_loops = uv_loops.reshape(-1, 2)
	label_slot = np.zeros(n_faces, dtype=np.int32)
	de = np.zeros(n_faces)
	need = override == 0
	if need.any():
		if image is None:
			pc.fail("the body has no texture and no slot override for %d faces" % need.sum())
		w, h = image.size
		pix = np.empty(w * h * 4, dtype=np.float32)
		image.pixels.foreach_get(pix)
		pix = pix.reshape(h, w, 4)
		fuv = np.zeros((n_faces, 2))
		for k in range(3):
			fuv += uv_loops[start + k]
		fuv /= 3.0
		col = sample_texture(pix, w, h, fuv[need])
		lab = srgb_to_lab(col)
		dist = np.linalg.norm(lab[:, None, :] - cand_lab[None, :, :], axis=2)
		pick = np.argmin(dist, axis=1)
		label_slot[need] = np.array(slots)[pick]
		de[need] = dist[np.arange(len(pick)), pick]
	label_slot[~need] = override[~need] - 1

	# ----- 2. prune swatches
	fixed = ~need
	pruned = []
	while True:
		used, counts = np.unique(label_slot[need], return_counts=True)
		share = {int(s): float(areas[need & (label_slot == s)].sum() / max(areas[need].sum(), 1e-9)) for s in used}
		overall_used = set(int(s) for s in np.unique(label_slot))
		small = min(share, key=share.get) if share else None
		if small is None or (len(overall_used) <= pc_cfg.get("max_swatches", 6) and share[small] >= pc_cfg.get("min_share", 0.004)):
			break
		pool = [s for s in share if s != small]
		if not pool:
			break
		i_small = slots.index(small)
		best = min(pool, key=lambda s: np.linalg.norm(cand_lab[slots.index(s)] - cand_lab[i_small]))
		label_slot[need & (label_slot == small)] = best
		pruned.append({"slot": small, "into": best, "share": share[small]})

	# ----- 3. majority filter
	nb, pairs = neighbours(me)
	flipped = 0
	for _ in range(int(pc_cfg.get("majority_passes", 2))):
		new = label_slot.copy()
		for f in np.nonzero(need)[0]:
			ns = nb[f]
			if len(ns) < 2:
				continue
			vals = {}
			for g in ns:
				vals[label_slot[g]] = vals.get(label_slot[g], 0) + 1
			top = max(vals, key=vals.get)
			if top != label_slot[f] and vals[top] * 2 > len(ns):
				new[f] = top
				flipped += 1
		label_slot = new

	# ----- 3-island. M6 FB-DETAIL: a connected patch of one label under palette.min_island_area_m2 takes the label its border
	# shares most (the texture's purple on a steel plate is a stray patch, not a jacket; the majority filter only trims a patch's rim)
	island_flips = None
	if float(pc_cfg.get("min_island_area_m2", 0.0)) > 0.0:
		island_flips = 0
		limit = float(pc_cfg["min_island_area_m2"])
		for _ in range(int(pc_cfg.get("island_passes", 2))):
			seen = np.zeros(n_faces, dtype=bool)
			changed = 0
			for f0 in np.nonzero(need)[0]:
				if seen[f0]:
					continue
				comp, stack = [], [int(f0)]
				seen[f0] = True
				while stack:
					f = stack.pop()
					comp.append(f)
					for g in nb[f]:
						if need[g] and not seen[g] and label_slot[g] == label_slot[f0]:
							seen[g] = True
							stack.append(g)
				if areas[comp].sum() >= limit:
					continue
				votes = {}
				inside = set(comp)
				for f in comp:
					for g in nb[f]:
						if g not in inside and need[g]:
							votes[label_slot[g]] = votes.get(label_slot[g], 0.0) + 1.0
				if votes:
					label_slot[comp] = max(votes, key=votes.get)
					changed += len(comp)
			island_flips += changed
			if not changed:
				break

	# ----- 3a. the generated fists' strap: exactly the faces between its two planes (pipe_band) are the strap's paint slot, and a
	# fist face outside them that the texture called strap-coloured (palette.strap_slot) is the glove's (no stray spikes of yellow
	# above or below the ring). F-punk-fix: palette.strap_paint_slot (default: the strap's own slot) is what the band is painted
	# with, so the strap can be the glove's colour; the faces of the clean collar (pipe_collar) are the glove's whole.
	band_report = None
	collar_dense = np.zeros(n_faces, dtype=np.int32)
	if COLLAR_ATTR in me.attributes:
		me.attributes[COLLAR_ATTR].data.foreach_get("value", collar_dense)
	if FIST_ATTR in me.attributes and pc_cfg.get("strap_slot") is not None:
		band = np.zeros(n_faces, dtype=np.int32)
		if BAND_ATTR in me.attributes:
			me.attributes[BAND_ATTR].data.foreach_get("value", band)
		fist_f = np.zeros(n_faces, dtype=np.int32)
		me.attributes[FIST_ATTR].data.foreach_get("value", fist_f)
		strap, glove = int(pc_cfg["strap_slot"]), int(pc_cfg["glove_slot"])
		strap_paint = int(pc_cfg.get("strap_paint_slot", strap))
		in_band = (fist_f > 0) & (band > 0)
		stray = (fist_f > 0) & (band == 0) & (label_slot == strap)
		label_slot[in_band] = strap_paint
		label_slot[stray] = glove
		label_slot[collar_dense > 0] = glove
		band_report = {"strap_faces": int(in_band.sum()), "stray_strap_faces_made_glove": int(stray.sum()), "collar_faces": int((collar_dense > 0).sum())}

	# ----- 3b. regions: faces of one slot inside a box take another slot
	region_report = []
	if island_flips is not None:  # an entry of the always-present list, so the shared report keys stay the Punk's (test_art_contract's guard)
		region_report.append({"name": "island_merge", "min_area_m2": float(pc_cfg["min_island_area_m2"]), "faces": int(island_flips)})
	if pc_cfg.get("regions"):
		centers_dense = pb.face_centers(me)
		for reg in pc_cfg["regions"]:
			lo, hi = np.array(reg["min"]), np.array(reg["max"])
			inside = np.all((centers_dense >= lo) & (centers_dense <= hi), axis=1)
			if reg.get("only_from"):
				inside &= np.isin(label_slot, reg["only_from"])
			sel = inside & need
			label_slot[sel] = int(reg["slot"])
			region_report.append({"name": reg.get("name", ""), "slot": int(reg["slot"]), "faces": int(sel.sum())})

	# ----- 4. relax the border loops
	vert_faces = [[] for _ in range(len(co))]
	for f in range(n_faces):
		for k in range(total[f]):
			vert_faces[lv[start[f] + k]].append(f)
	border_edges = []
	for e, faces in pairs.items():
		if len(faces) == 2 and label_slot[faces[0]] != label_slot[faces[1]] and need[faces[0]] and need[faces[1]]:
			border_edges.append(e)
	ev = np.empty(len(me.edges) * 2, dtype=np.int32)
	me.edges.foreach_get("vertices", ev)
	ev = ev.reshape(-1, 2)
	border_nb = {}
	for e in border_edges:
		a, b = int(ev[e][0]), int(ev[e][1])
		border_nb.setdefault(a, []).append(b)
		border_nb.setdefault(b, []).append(a)
	fixed_verts = set()
	for f in np.nonzero(fixed)[0]:
		fixed_verts.update(int(v) for v in lv[start[f]:start[f] + total[f]])
	fist_mask = np.zeros(n_faces, dtype=np.int32)
	if FIST_ATTR in me.attributes:
		me.attributes[FIST_ATTR].data.foreach_get("value", fist_mask)
	fist_mask = fist_mask > 0
	still_verts = set(fixed_verts)  # the generated fists keep their shape: border relaxation leaves them be
	for f in np.nonzero(fist_mask)[0]:
		still_verts.update(int(v) for v in lv[start[f]:start[f] + total[f]])
	movable = [v for v in border_nb if v not in still_verts]
	for _ in range(int(pc_cfg.get("border_relax_iterations", 3))):
		new_co = co.copy()
		for v in movable:
			nbs = border_nb[v]
			new_co[v] = co[v] + pc_cfg.get("border_relax_factor", 0.5) * (co[nbs].mean(axis=0) - co[v])
		co = new_co
	pb.set_verts(me, co)

	# ----- 5. decimate with the borders and the replaced parts protected
	protected = set(border_nb) | fixed_verts
	cell = float(pc_cfg.get("fist_border_cell_m", 0.0))
	thinned = 0
	# the static-prop path (M6 PROPS): the same thinning for every colour border of the body (a rust patch's border at the dense
	# mesh's millimetres would hold more triangles than a prop's budget), one protected vertex per palette.border_cell_m
	body_cell = float(pc_cfg.get("border_cell_m", 0.0))
	if body_cell > 0.0:
		seen_body = set()
		for v in sorted(border_nb):
			if v not in fixed_verts:
				key = tuple(np.floor(co[v] / body_cell).astype(int))
				if key in seen_body:
					protected.discard(v)
					thinned += 1
				else:
					seen_body.add(key)
	if cell > 0.0 and fist_mask.any():
		# a colour border of a generated fist is thinned to one protected vertex per `cell` metres (a ring at the dense
		# mesh's 1.5 mm would hold most of the fists' budget); the decimator closes the gaps with straight edges
		fist_verts = set()
		for f in np.nonzero(fist_mask)[0]:
			fist_verts.update(int(v) for v in lv[start[f]:start[f] + total[f]])
		seen = set()
		for v in sorted(border_nb):
			if v in fist_verts and v not in fixed_verts:
				key = tuple(np.floor(co[v] / cell).astype(int))
				if key in seen:
					protected.discard(v)
					thinned += 1
				else:
					seen.add(key)
	protected_mask = np.zeros(len(co), dtype=bool)
	protected_mask[list(protected)] = True
	pb.write_weights(body, ["pipe_keep"], protected_mask.astype(np.float64)[:, None], eps=0.5)
	dense_tris = pb.triangle_count(me)
	budget = int(pc_cfg["budget_tris"])
	dense_label = label_slot.copy()
	dense_verts = [tuple(v) for v in co]
	dense_polys = [tuple(int(i) for i in lv[start[f]:start[f] + total[f]]) for f in range(n_faces)]
	bvh = BVHTree.FromPolygons(dense_verts, dense_polys)
	dense_uv_loops = uv_loops.copy()

	def survival(obj, protected_co):
		kd_co = pb.verts(obj.data)
		from mathutils import kdtree
		kd = kdtree.KDTree(len(kd_co))
		for i, p in enumerate(kd_co):
			kd.insert(Vector(p), i)
		kd.balance()
		worst = 0.0
		sample = protected_co[:: max(1, len(protected_co) // 600)]
		for p in sample:
			_, _, d = kd.find(Vector(p))
			worst = max(worst, d)
		return worst

	def decimate_part(target, part_budget, label):
		"""Collapse `target` (an object carrying the pipe_keep group) to at most part_budget triangles, within 3% under it,
		with the group's vertices protected. Returns (decimated object, report)."""
		t_co = pb.verts(target.data)
		keep = pb.weights_matrix(target, ["pipe_keep"])[:, 0] > 0.5
		protected_co = t_co[keep]
		t_dense = pb.triangle_count(target.data)
		invert = False
		trial, tris = decimate_trial(target, 0.8, "pipe_keep", invert)
		worst = survival(trial, protected_co)
		bpy.data.objects.remove(trial)
		if worst > 1e-3:
			invert = True
		trials = []
		lo, hi = 0.01, 1.0
		ratio = min(1.0, part_budget / max(t_dense, 1))
		best = None
		for it in range(7):
			trial, tris = decimate_trial(target, ratio, "pipe_keep", invert)
			trials.append({"ratio": round(ratio, 4), "tris": tris})
			ok = tris <= part_budget
			if ok and (best is None or tris > best[1]):
				if best is not None:
					bpy.data.objects.remove(best[0])
				best = (trial, tris, ratio)
			else:
				bpy.data.objects.remove(trial)
			if ok and tris >= part_budget * 0.97:
				break
			if ok:
				lo = max(lo, ratio)
			else:
				hi = min(hi, ratio)
			ratio = (lo + hi) / 2.0 if hi < 1.0 and lo > 0.01 else (ratio * part_budget / max(tris, 1) * (0.99 if not ok else 1.0))
		if best is None:
			pc.fail("could not decimate %s to %d triangles with %d protected vertices (%s)" % (label, part_budget, int(keep.sum()), trials))
		deci_part, tris, ratio = best
		return deci_part, {"part": label, "invert_group": invert, "trials": trials, "triangles": tris, "budget": part_budget,
			"budget_ok": tris <= part_budget, "protected_vertices": int(keep.sum()), "protected_position_worst_m": survival(deci_part, protected_co)}

	def part_object(source_obj, keep_faces, name):
		"""A copy of source_obj holding only the faces in keep_faces (weights, UVs and attributes ride along)."""
		new_me = source_obj.data.copy()
		new_obj = source_obj.copy()
		new_obj.data = new_me
		new_obj.name = name
		pb.link(new_obj)
		for m in list(new_obj.modifiers):
			new_obj.modifiers.remove(m)
		bm2 = bmesh.new()
		bm2.from_mesh(new_me)
		bm2.faces.ensure_lookup_table()
		drop = [bm2.faces[i] for i in np.nonzero(~keep_faces)[0]]
		bmesh.ops.delete(bm2, geom=drop, context="FACES")
		loose2 = [v for v in bm2.verts if not v.link_faces]
		if loose2:
			bmesh.ops.delete(bm2, geom=loose2, context="VERTS")
		bm2.to_mesh(new_me)
		bm2.free()
		new_me.update()
		return new_obj

	decimate_reports = []
	if fist_mask.any():
		fist_budget = int(pc_cfg.get("fist_budget_tris", 1500))
		n_fists = 2
		body_part = part_object(body, ~fist_mask, "BodyPart")
		fist_part = part_object(body, fist_mask, "FistPart")
		reserve = int(pc_cfg.get("reserve_tris", 0))  # what the strap planes' cuts add after the decimation
		deci_body, rep_b = decimate_part(body_part, budget - n_fists * fist_budget - reserve, "body")
		deci_fist, rep_f = decimate_part(fist_part, n_fists * fist_budget, "fists")
		decimate_reports = [rep_b, rep_f]
		bpy.data.objects.remove(body_part)
		bpy.data.objects.remove(fist_part)
		pb.activate(deci_body)
		deci_fist.select_set(True)
		bpy.ops.object.join()
		deci = bpy.context.view_layer.objects.active
		tris = pb.triangle_count(deci.data)
		worst = max(r["protected_position_worst_m"] for r in decimate_reports)
		trials = rep_b["trials"] + rep_f["trials"]
		invert = rep_b["invert_group"]
	else:
		deci, rep = decimate_part(body, budget, "body")
		decimate_reports = [rep]
		tris, worst, trials, invert = rep["triangles"], rep["protected_position_worst_m"], rep["trials"], rep["invert_group"]
	# swap the decimated mesh into Body
	old_mesh = body.data
	body.data = deci.data
	deci.data = old_mesh
	bpy.data.objects.remove(deci)
	bpy.data.meshes.remove(old_mesh)
	me = body.data
	me.name = pb.BODY
	vg = body.vertex_groups.get("pipe_keep")
	if vg is not None:
		body.vertex_groups.remove(vg)
	if SLOT_ATTR in me.attributes:
		me.attributes.remove(me.attributes[SLOT_ATTR])
	if BAND_ATTR in me.attributes:
		me.attributes.remove(me.attributes[BAND_ATTR])

	# ----- 5a. the generated fists' strap, again on the DECIMATED mesh: cut the fists along the strap's two planes (straight edge
	# loops, a few dozen faces each) and make the faces between them the strap's slot below (the dense mesh's band, held by a thinned
	# border, came out of the decimation a ragged zigzag)
	fist_planes = pb.scene_prop("pipe_fist_planes", {}) if FIST_ATTR in me.attributes else {}
	strap_cuts = []
	if fist_planes and pc_cfg.get("strap_slot") is not None:
		bm3 = bmesh.new()
		bm3.from_mesh(me)
		fist_layer = bm3.faces.layers.int.get(FIST_ATTR)
		for side, planes in fist_planes.items():
			if not planes:
				continue
			for plane_co, plane_no in planes:
				geom_faces = [f for f in bm3.faces if f[fist_layer] > 0 and abs((f.calc_center_median() - Vector(plane_co)).dot(Vector(plane_no))) < 0.03
					and (f.calc_center_median() - Vector(plane_co)).length < 0.25]
				geom = list(geom_faces) + sorted({e for f in geom_faces for e in f.edges}, key=lambda e: e.index) + sorted({v for f in geom_faces for v in f.verts}, key=lambda v: v.index)
				before = len(bm3.faces)
				bmesh.ops.bisect_plane(bm3, geom=geom, dist=1e-6, plane_co=tuple(plane_co), plane_no=tuple(plane_no))
				strap_cuts.append({"side": side, "faces_added": len(bm3.faces) - before})
		bmesh.ops.triangulate(bm3, faces=bm3.faces[:])
		bm3.to_mesh(me)
		bm3.free()
		me.update()

	# ----- 5b. unfold: the decimated mesh's folded triangles relaxed away (opt-in)
	unfold_report = None
	if pc_cfg.get("unfold"):
		uf = pc_cfg["unfold"]
		start_u, total_u, lv_u = pb.poly_arrays(me)
		tri_v = lv_u[start_u[:, None] + np.arange(3)[None, :]] if len(start_u) and int(total_u.max()) == 3 else pb.tri_arrays(me)[0]
		co_u = pb.verts(me)
		new_co_u, unfold_report = pipe_cleanup.unfold(co_u, tri_v, None, int(uf.get("iterations", 12)), float(uf.get("factor", 0.5)), int(uf.get("ring", 1)))
		pb.set_verts(me, new_co_u)

	# ----- 6. relabel from the dense mesh, palette UVs, optional detail UV
	centers = pb.face_centers(me)
	new_label = np.zeros(len(me.polygons), dtype=np.int32)
	new_collar = np.zeros(len(me.polygons), dtype=bool)
	for i, c in enumerate(centers):
		loc, nrm, idx, d = bvh.find_nearest(Vector(c))
		new_label[i] = dense_label[idx]
		new_collar[i] = collar_dense[idx] > 0
	if fist_planes and pc_cfg.get("strap_slot") is not None and FIST_ATTR in me.attributes:
		fist_final = np.zeros(len(me.polygons), dtype=np.int32)
		me.attributes[FIST_ATTR].data.foreach_get("value", fist_final)
		for side, planes in fist_planes.items():
			if not planes:
				continue
			(c0, n0), (c1, n1) = planes
			h0 = (centers - np.asarray(c0)) @ np.asarray(n0)
			h1 = (centers - np.asarray(c1)) @ np.asarray(n1)
			near = (fist_final > 0) & (np.linalg.norm(centers - np.asarray(c0), axis=1) < 0.25)
			new_label[near & (h0 >= -1e-6) & (h1 <= 1e-6)] = int(pc_cfg.get("strap_paint_slot", pc_cfg["strap_slot"]))
			new_label[near & ~((h0 >= -1e-6) & (h1 <= 1e-6)) & (new_label == int(pc_cfg["strap_slot"]))] = int(pc_cfg["glove_slot"])
	if FIST_ATTR in me.attributes:
		me.attributes.remove(me.attributes[FIST_ATTR])
	if COLLAR_ATTR in me.attributes:
		me.attributes.remove(me.attributes[COLLAR_ATTR])
	start2, total2, lv2 = pb.poly_arrays(me)
	layer = me.uv_layers[0] if me.uv_layers else me.uv_layers.new(name="palette")
	for extra_layer in [l for l in me.uv_layers if l.name != layer.name]:
		me.uv_layers.remove(extra_layer)
	layer.name = "palette"
	uv = np.zeros((len(me.loops), 2), dtype=np.float32)
	for f in range(len(me.polygons)):
		u, v = gp.uv_of_slot(int(new_label[f]))
		uv[start2[f]:start2[f] + total2[f]] = (u, 1.0 - v)
	layer.data.foreach_set("uv", uv.ravel())
	detail = bool(pc_cfg.get("detail_uv", False))
	db_cfg = pc_cfg.get("detail_bake") or {}
	if detail:
		d_layer = me.uv_layers.new(name="detail")
		me.uv_layers.active = d_layer
		pb.activate(body)
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		collar_apart = bool(new_collar.any() and not db_cfg.get("collar_in_unwrap", False))
		if collar_apart:
			# the clean collar takes no texture ink: it is left out of the unwrap (its islands would only take atlas area from the faces that
			# carry lines) and sent to a texel nothing covers below, unless detail_bake.collar_in_unwrap (rescore-rs-02: the cuff is what a
			# strike's contact shows, and the glove's authored lines need texels there)
			bm_u = bmesh.from_edit_mesh(me)
			bm_u.faces.ensure_lookup_table()
			for f in bm_u.faces:
				f.select_set(not new_collar[f.index])
			bm_u.select_flush_mode()
			bmesh.update_edit_mesh(me)
		bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, correct_aspect=True, scale_to_bounds=False)
		bpy.ops.uv.pack_islands(margin=0.004)
		bpy.ops.object.mode_set(mode="OBJECT")
		if collar_apart:
			grid = 256
			d_layer = me.uv_layers["detail"]  # the edit-mode round trip invalidated the reference
			uv_d = np.empty(len(me.loops) * 2, dtype=np.float32)
			d_layer.data.foreach_get("uv", uv_d)
			uv_d = uv_d.reshape(-1, 2).astype(np.float64)
			start_d, total_d, _lv_d = pb.poly_arrays(me)
			corners = uv_d[start_d[:, None] + np.arange(3)[None, :]][~new_collar]
			covered = pipe_detail.dilate(pipe_detail.coverage(corners, grid, grid), 2) > 0.5
			free = np.argwhere(~covered)
			dead = (0.5 / grid, 0.5 / grid) if len(free) == 0 else ((free[0][1] + 0.5) / grid, (free[0][0] + 0.5) / grid)
			for f in np.nonzero(new_collar)[0]:
				uv_d[start_d[f]:start_d[f] + total_d[f]] = dead
			d_layer.data.foreach_set("uv", uv_d.ravel().astype(np.float32))
		me.uv_layers.active = me.uv_layers["palette"]
	bake_report = None
	if detail and pc_cfg.get("detail_bake") and image is not None:
		db = pc_cfg["detail_bake"]
		dense_verts_np = np.array(dense_verts, dtype=np.float64)
		tri_idx = lv[start[:, None] + np.arange(3)[None, :]]
		corner_uv = dense_uv_loops[start[:, None] + np.arange(3)[None, :]].astype(np.float64)
		out_png = pc.repo_path(db["out"]) if "out" in db else os.path.join(pc.cfg_dir(cfg, "export_dir"), cfg["paths"]["export_name"] + "_detail.png")
		gain = np.where(np.isin(new_label, db.get("no_ink_slots", [])) | new_collar, 0.0, 1.0)
		# zones (F-punk-fix): faces of some slots inside a box take their own ink_low / ink_high (the face's skin: a higher pair, so
		# the texture's speckle drops out and the mouth and nose lines stay)
		zone_low = np.full(len(me.polygons), float(db.get("ink_low", 0.04)))
		zone_high = np.full(len(me.polygons), float(db.get("ink_high", 0.12)))
		zone_id = np.zeros(len(me.polygons), dtype=np.int32)
		zone_names = []
		face_crease = np.full(len(me.polygons), float((db.get("crease") or {}).get("angle_deg", 60.0)))
		for zi, zone in enumerate(db.get("zones", []), start=1):
			zsel = np.ones(len(me.polygons), dtype=bool)
			if zone.get("slots"):
				zsel &= np.isin(new_label, zone["slots"])
			if zone.get("min"):
				zsel &= np.all((centers >= np.array(zone["min"])) & (centers <= np.array(zone["max"])), axis=1)
			zone_low[zsel] = float(zone.get("ink_low", db.get("ink_low", 0.04)))
			zone_high[zsel] = float(zone.get("ink_high", db.get("ink_high", 0.12)))
			if zone.get("no_ink"):
				gain[zsel] = 0.0
			if "crease_deg" in zone:
				face_crease[zsel] = float(zone["crease_deg"])
			zone_id[zsel] = zi
			zone_names.append(zone.get("name", "zone%d" % zi))
		# the glint gate (rescore-rs-01): the faces of the glossy slots (the lens) get the authored streaks in G
		glint_cfg = db.get("glint")
		face_glint = np.isin(new_label, glint_cfg.get("slots", [])) if glint_cfg else None
		# the glove's authored lines (rescore-rs-02): each hand's frame from its bone (the axis wrist to knuckles, the back of the hand outward)
		glove_cfg = db.get("glove_lines")
		frames = {}
		if glove_cfg:
			armature = bpy.data.objects[pb.ARMATURE]
			for side, bone in glove_cfg["bones"].items():
				head, tail = np.array(armature.data.bones[bone].head_local), np.array(armature.data.bones[bone].tail_local)
				axis = (tail - head) / np.linalg.norm(tail - head)
				sign = 1.0 if head[0] > 0 else -1.0
				out_dir = np.array([sign, 0.0, 0.0]) - axis * sign * axis[0]
				out_dir /= np.linalg.norm(out_dir)
				frames[side] = {"sign": sign, "head": head, "a": axis, "b": out_dir, "c": np.cross(axis, out_dir)}
		bake_report = pipe_detail.bake(me, "detail", image, bvh, dense_verts_np, tri_idx, corner_uv, db, out_png, pc.work_path(cfg, "detail_source.png"), gain,
			zone_low, zone_high, zone_id, zone_names, glint_cfg, face_glint, glove_cfg, frames, new_label, face_crease)
		bake_report["png"] = os.path.basename(out_png)  # the folder differs in a --check rebuild; the content must not
		bake_report["sha256"] = pc.sha256_file(out_png)
	me.materials.clear()
	if image is not None:
		bpy.data.images.remove(image)
	for img in list(bpy.data.images):
		if img.users == 0:
			bpy.data.images.remove(img)
	for p in me.polygons:
		p.use_smooth = True
	if pc_cfg.get("armature", True) and pb.ARMATURE in bpy.data.objects:  # the static-prop path (M6 PROPS) has none
		pb.attach_armature(body, bpy.data.objects[pb.ARMATURE])
	pb.set_scene_prop("pipe_face_slots", [int(s) for s in new_label])
	pb.save_blend(pc.work_path(cfg, "05_palette.blend"))

	final_areas = pb.face_areas(me)
	used = {}
	for s in np.unique(new_label):
		used[int(s)] = {"name": swatches[int(s)]["name"], "area_share": float(final_areas[new_label == s].sum() / final_areas.sum()), "faces": int((new_label == s).sum())}
	return {
		"source_image": None if image is None else "removed",
		"faces_dense": n_faces,
		"textured_faces": int(need.sum()),
		"override_faces": int((~need).sum()),
		"delta_e_mean": float(de[need].mean()) if need.any() else 0.0,
		"delta_e_p95": float(np.percentile(de[need], 95)) if need.any() else 0.0,
		"pruned_swatches": pruned,
		"majority_flips": flipped,
		"border_vertices": len(border_nb),
		"border_edges": len(border_edges),
		"protected_vertices": int(protected_mask.sum()),
		"decimate": {"invert_group": invert, "trials": trials, "triangles": tris, "budget": budget, "budget_ok": tris <= budget,
			"protected_position_worst_m": worst},
		"swatches_used": used,
		"swatch_count": len(used),
		"detail_uv": detail,
		"detail_bake": bake_report,
		"regions": region_report,
		"region_cuts": cuts_made,
		"fist_band": band_report,
		"fist_border_thinned": thinned,
		"fist_strap_cuts": strap_cuts,
		"decimate_parts": decimate_reports,
		"unfold": unfold_report,
		"triangles": pb.triangle_count(me),
		"vertices": len(me.vertices),
	}


if __name__ == "__main__":
	pb.run_step("palette", run)
