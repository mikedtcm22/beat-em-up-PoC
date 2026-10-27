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
	5. decimate (Collapse) to palette.budget_tris with the border vertices and the part-replacement vertices PROTECTED, so
	   the colour borders keep their resolution and the fists their shape (a protected-position survival check is reported);
	6. relabel every face of the decimated mesh from the nearest face of the dense one (BVH), then give every face its swatch
	   centre as UV1 "palette" (u, v from gen_palette.uv_of_slot); with palette.detail_uv a second layer "detail" (UV2,
	   smart-projected: the player's 1k ink mask is painted on it).
The source texture and materials are dropped: the game draws the atlas.

F-punk's additions (all opt-in by config, so the probe and the player run as before):
	palette.regions: faces of a slot inside a box take another slot (the Punk's lens: the cap's yellow in front of the eyes,
	  on its own swatch that takes no damage marks);
	faces with the pipe_fist attribute (generated fists, blender_parts) are decimated on their own to
	  palette.fist_budget_tris each, the rest of the body to the budget less both fists (their borders still protected);
	palette.unfold: relax the folded triangles of the decimated mesh away (pipe_cleanup.unfold) and report the counts;
	palette.detail_bake: the 1k ink-only detail mask on UV2 baked from the dense texture (pipe_detail.bake, plan A18); its
	  no_ink_slots (the lens) get no ink.
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
	pb.open_blend(pc.work_path(cfg, "04_parts.blend"))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	bm = bmesh.new()
	bm.from_mesh(me)
	# regions with "bisect_z": the mesh is cut along the box's two horizontal planes (inside its x/y span) first, so the colour
	# border runs along an edge loop and survives the decimation straight
	cuts_made = []
	for reg in pc_cfg.get("regions", []):
		if not reg.get("bisect_z"):
			continue
		for plane_z in (reg["min"][2], reg["max"][2]):
			geom_faces = []
			for f in bm.faces:
				c = f.calc_center_median()
				if reg["min"][0] <= c.x <= reg["max"][0] and reg["min"][1] <= c.y <= reg["max"][1] and abs(c.z - plane_z) < 0.03:
					geom_faces.append(f)
			geom = list(geom_faces) + sorted({e for f in geom_faces for e in f.edges}, key=lambda e: e.index) + sorted({v for f in geom_faces for v in f.verts}, key=lambda v: v.index)
			before = len(bm.faces)
			bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=(0.0, 0.0, plane_z), plane_no=(0.0, 0.0, 1.0))
			cuts_made.append({"region": reg.get("name", ""), "z": plane_z, "faces_before": before, "faces_after": len(bm.faces)})
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

	# ----- 3b. regions: faces of one slot inside a box take another slot
	region_report = []
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
		deci_body, rep_b = decimate_part(body_part, budget - n_fists * fist_budget, "body")
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
	if FIST_ATTR in me.attributes:
		me.attributes.remove(me.attributes[FIST_ATTR])

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
	for i, c in enumerate(centers):
		loc, nrm, idx, d = bvh.find_nearest(Vector(c))
		new_label[i] = dense_label[idx]
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
	if detail:
		d_layer = me.uv_layers.new(name="detail")
		me.uv_layers.active = d_layer
		pb.activate(body)
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, correct_aspect=True, scale_to_bounds=False)
		bpy.ops.uv.pack_islands(margin=0.004)
		bpy.ops.object.mode_set(mode="OBJECT")
		me.uv_layers.active = me.uv_layers["palette"]
	bake_report = None
	if detail and pc_cfg.get("detail_bake") and image is not None:
		db = pc_cfg["detail_bake"]
		dense_verts_np = np.array(dense_verts, dtype=np.float64)
		tri_idx = lv[start[:, None] + np.arange(3)[None, :]]
		corner_uv = dense_uv_loops[start[:, None] + np.arange(3)[None, :]].astype(np.float64)
		out_png = pc.repo_path(db["out"]) if "out" in db else os.path.join(pc.cfg_dir(cfg, "export_dir"), cfg["paths"]["export_name"] + "_detail.png")
		gain = np.where(np.isin(new_label, db.get("no_ink_slots", [])), 0.0, 1.0)
		bake_report = pipe_detail.bake(me, "detail", image, bvh, dense_verts_np, tri_idx, corner_uv, db, out_png, pc.work_path(cfg, "detail_source.png"), gain)
		bake_report["png"] = pc.repo_rel(out_png)
	me.materials.clear()
	if image is not None:
		bpy.data.images.remove(image)
	for img in list(bpy.data.images):
		if img.users == 0:
			bpy.data.images.remove(img)
	for p in me.polygons:
		p.use_smooth = True
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
		"decimate_parts": decimate_reports,
		"unfold": unfold_report,
		"triangles": pb.triangle_count(me),
		"vertices": len(me.vertices),
	}


if __name__ == "__main__":
	pb.run_step("palette", run)
