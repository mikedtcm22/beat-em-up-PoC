"""Step 4 of the player's chain: the generated fists and the first-person split (M4 package F-player-art, M4-plan Part C section 7).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/player_parts.py -- <pipeline.json> replace
	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/player_parts.py -- <pipeline.json> split

The player's own copy of blender_parts.py's two modes (a change in that shared file is F-punk's; this file is read only by
player_run.py). Everything hero-specific is in the config (parts.fists, parts.split_fp), so a second hero is another config,
another fist GLB and another palette, not a code change.

replace: reads work/03_rig.blend, writes work/04_parts.blend and work/04a_fists_dense.blend. The hands are replaced by T13's
	generated fist piece (a wrapped wrist, a black fingerless-glove plate, bare fingers, a strap), the most-seen asset in the game:
	  1. each hand is cut off the body at a plane across the forearm (parts.fists.cut_a_m from the wrist joint along the arm);
	  2. the piece (one clenched LEFT fist, upright, knuckles up, palm side toward +X, thumb toward +Z in glTF space) is turned
	     into the hanging hand of the table's frame (the rig's fist box: knuckles down the arm, palm to the midline, thumb
	     forward), mirrored for the right hand, scaled so its fist block fills the box, squeezed along the arm between the strap
	     and the wrist by parts.fists.map (a piecewise-linear map of the model's height onto the arm axis), and its strap flared
	     to sit over the forearm at the cut (the body's ring ends INSIDE the strap, so nothing is open and nothing pokes out);
	  3. every face gets a palette swatch from the piece's texture (Lab-nearest among parts.fists.slots, a majority filter),
	     the piece is decimated to parts.fists.target_tris with the colour borders protected, and the faces are relabelled from the
	     dense piece (the face attribute pipe_slot = slot + 1, as blender_palette.py reads it);
	  4. weights: the strap is LowerArm and the hand block is Hand (a smoothstep across parts.fists.ramp_a_m).
	  The dense, textured pieces are kept in work/04a_fists_dense.blend for the detail mask (player_detail.py).

split: reads work/05_palette.blend, writes work/06_split.blend. The first-person body (parts.split_fp): Body__fp_hidden = Chest
	and above, both Shoulders and the shoulder half of each upper arm; the visible Body keeps everything else and EVERY open loop
	of it is closed with an inward rounded cap. Differences from blender_parts.py: the horizontal cut is made through every face
	that can be hidden (the shoulder zone too), so the hidden part never reaches below the Chest joint (a shoulder-zone face
	hung below it in the first run); the generated mesh's pinholes, slits and non-manifold edges are cut out and patched (the contract
	wants no open edge on the visible body); and the faces are triangulated (every later step reads triangles).
	A third mesh Body__fp_torso (the belly and the belt, for fp_knockdown_hide_torso) is NOT built: the shared exporter writes only
	Body and Body__fp_hidden, and test_art_contract names only those two (M4-calls/F-player-art.md C14).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import gen_palette as gp  # noqa: E402
from blender_fit import rotation_between  # noqa: E402

NAMES = pc.bone_names()
SLOT_ATTR = "pipe_slot"
CAP_ATTR = "pipe_cap"
FIST_BONES = ("Hand", "LowerArm")


# --------------------------------------------------------------------------- small numpy helpers

def smoothstep(x, e0, e1):
	t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def srgb_to_lab(rgb):
	"""rgb (n, 3) in 0..1 sRGB -> CIE Lab (D65)."""
	c = np.asarray(rgb, dtype=np.float64)
	lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
	xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
	f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
	return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def image_pixels(image):
	"""(h, w, 4) float array of an image's pixels, bottom row first (Blender's order)."""
	w, h = image.size
	px = np.empty(w * h * 4, dtype=np.float32)
	image.pixels.foreach_get(px)
	return px.reshape(h, w, 4)


def sample_texture(pix, uv, box=1):
	"""Mean colour of a (2 box + 1)^2 texel window around each uv (n, 2) in 0..1 (Blender uv, origin bottom left)."""
	h, w = pix.shape[:2]
	x = np.clip((uv[:, 0] * w).astype(np.int64), 0, w - 1)
	y = np.clip((uv[:, 1] * h).astype(np.int64), 0, h - 1)
	acc = np.zeros((len(uv), 3))
	cnt = 0
	for dy in range(-box, box + 1):
		for dx in range(-box, box + 1):
			acc += pix[np.clip(y + dy, 0, h - 1), np.clip(x + dx, 0, w - 1), :3]
			cnt += 1
	return acc / cnt


def face_neighbours(me):
	"""(neighbour list per face, edge -> faces)."""
	start, total, lv = pb.poly_arrays(me)
	le = np.empty(len(me.loops), dtype=np.int32)
	me.loops.foreach_get("edge_index", le)
	owner = np.repeat(np.arange(len(start)), total)
	pairs = {}
	for f, e in zip(owner, le):
		pairs.setdefault(int(e), []).append(int(f))
	nb = [[] for _ in range(len(start))]
	for faces in pairs.values():
		if len(faces) == 2:
			nb[faces[0]].append(faces[1])
			nb[faces[1]].append(faces[0])
	return nb, pairs


def triangle_uv_centres(me, uv_layer):
	"""Mean UV of each (triangle) face's corners (n_faces, 2)."""
	start, total, lv = pb.poly_arrays(me)
	uv = np.empty(len(me.loops) * 2, dtype=np.float32)
	uv_layer.data.foreach_get("uv", uv)
	uv = uv.reshape(-1, 2)
	acc = np.zeros((len(start), 2))
	for k in range(int(total.max())):
		mask = total > k
		acc[mask] += uv[start[mask] + k]
	return acc / np.maximum(total, 1)[:, None]


# --------------------------------------------------------------------------- the generated piece

def import_piece(path):
	"""Import a Tripo GLB as data: (vertices in glTF Y-up axes (n, 3), faces (list of tuples), loop uvs (n_loops, 2), the image)."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=pc.repo_path(path), import_shading="NORMALS")
	meshes = [o for o in bpy.data.objects if o.type == "MESH"]
	if len(meshes) != 1:
		pc.fail("the fist piece must be one mesh, found %d" % len(meshes))
	ob = meshes[0]
	me = ob.data
	# the importer splits a vertex wherever its UV or normal differs: weld them back by position (the loops keep their UVs),
	# or every UV seam reads as an open edge and the decimation and the caps tear the piece apart
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
	bm.to_mesh(me)
	bm.free()
	me.update()
	co = np.array([tuple(ob.matrix_world @ v.co) for v in me.vertices])
	g = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)  # Blender z-up -> glTF y-up
	start, total, lv = pb.poly_arrays(me)
	faces = [tuple(int(i) for i in lv[start[f]:start[f] + total[f]]) for f in range(len(start))]
	uv = np.empty(len(me.loops) * 2, dtype=np.float32)
	me.uv_layers[0].data.foreach_get("uv", uv)
	image = None
	for mat in me.materials:
		if mat and mat.use_nodes:
			for n in mat.node_tree.nodes:
				if n.type == "TEX_IMAGE" and n.image is not None:
					image = n.image
	if image is None:
		pc.fail("the fist piece has no texture")
	pix = image_pixels(image)
	return g, faces, uv.reshape(-1, 2), pix, image


def piece_labels(me, uv_layer, pix, slot_list):
	"""A palette slot per face of the dense piece: the texture colour at each face's UV centre, Lab-nearest among slot_list,
	then two majority passes. (labels (n_faces,), mean delta-E)"""
	swatches = gp.swatches()
	cand = srgb_to_lab(np.array([[c / 255.0 for c in swatches[s]["rgba"][:3]] for s in slot_list]))
	fuv = triangle_uv_centres(me, uv_layer)
	lab = srgb_to_lab(sample_texture(pix, fuv))
	dist = np.linalg.norm(lab[:, None, :] - cand[None, :, :], axis=2)
	pick = np.argmin(dist, axis=1)
	label = np.array(slot_list)[pick]
	de = float(dist[np.arange(len(pick)), pick].mean())
	nb, _ = face_neighbours(me)
	for _ in range(2):
		new = label.copy()
		for f in range(len(label)):
			ns = nb[f]
			if len(ns) < 2:
				continue
			vals = {}
			for g2 in ns:
				vals[label[g2]] = vals.get(label[g2], 0) + 1
			top = max(vals, key=vals.get)
			if top != label[f] and vals[top] * 2 > len(ns):
				new[f] = top
		label = new
	return label, de


def decimate_with_borders(obj, target, keep_mask):
	"""Collapse-decimate obj (a copy) towards `target` triangles keeping the vertices in keep_mask (the colour borders) where they
	are; returns (the new object, triangles, the worst distance a protected vertex moved). The vertex group's polarity is found by
	a trial (Blender 5.2.2: the INVERTED group protects)."""
	from mathutils import kdtree
	co0 = pb.verts(obj.data)
	protected_co = co0[keep_mask]
	vg = obj.vertex_groups.new(name="pipe_keep")
	for i in np.nonzero(keep_mask)[0]:
		vg.add([int(i)], 1.0, "REPLACE")

	def trial(ratio, invert):
		dup = obj.copy()
		dup.data = obj.data.copy()
		pb.link(dup)
		for m in list(dup.modifiers):
			dup.modifiers.remove(m)
		mod = dup.modifiers.new("Decimate", "DECIMATE")
		mod.decimate_type = "COLLAPSE"
		mod.ratio = float(min(max(ratio, 0.01), 1.0))
		mod.use_collapse_triangulate = True
		mod.vertex_group = "pipe_keep"
		mod.invert_vertex_group = invert
		mod.vertex_group_factor = 1.0
		pb.activate(dup)
		bpy.ops.object.modifier_apply(modifier="Decimate")
		return dup, pb.triangle_count(dup.data)

	def survival(o):
		c = pb.verts(o.data)
		kd = kdtree.KDTree(len(c))
		for i, p in enumerate(c):
			kd.insert(Vector(p), i)
		kd.balance()
		worst = 0.0
		for p in protected_co[:: max(1, len(protected_co) // 400)]:
			worst = max(worst, kd.find(Vector(p))[2])
		return worst

	dup, _ = trial(0.8, True)
	invert = survival(dup) <= 1e-3  # the polarity that keeps the protected vertices where they are
	bpy.data.objects.remove(dup)
	best, lo, hi = None, 0.01, 1.0
	ratio = min(1.0, target / max(pb.triangle_count(obj.data), 1))
	for _ in range(8):
		dup, tris = trial(ratio, invert)
		ok = tris <= target
		if ok and (best is None or tris > best[1]):
			if best is not None:
				bpy.data.objects.remove(best[0])
			best = (dup, tris, ratio)
		else:
			bpy.data.objects.remove(dup)
		if ok and tris >= target * 0.97:
			break
		if ok:
			lo = max(lo, ratio)
		else:
			hi = min(hi, ratio)
		ratio = (lo + hi) / 2.0 if hi < 1.0 and lo > 0.01 else ratio * target / max(tris, 1) * (0.99 if not ok else 1.0)
	if best is None:
		pc.fail("could not decimate the fist to %d triangles" % target)
	return best[0], best[1], survival(best[0])


def boundary_vertices(me):
	"""Indices of the vertices on an open edge."""
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.edges.ensure_lookup_table()
	out = sorted({v.index for e in bm.edges if e.is_boundary for v in e.verts})
	bm.free()
	return np.array(out, dtype=np.int64)


def place_piece(g, side, P, centre, flare, ring_offset_h, R, p_hand, box_y_b):
	"""The piece's vertices (glTF axes) in the Blender world frame for one hand (see the module doc)."""
	a = np.interp(g[:, 1], P["map"]["y_g"], P["map"]["a_m"])
	t = 1.0 - smoothstep(g[:, 1], P["strap_taper_y_g"][0], P["strap_taper_y_g"][1])
	s = P["xz_scale_m"] * (1.0 + (flare - 1.0) * t)
	x = s * (g[:, 0] - centre[0])
	y = s * (g[:, 2] - centre[1])
	if side == "Right":
		x = -x
	fade = 1.0 - smoothstep(a, P["map"]["a_m"][0], P["map"]["a_m"][0] + P["ring_blend_m"])
	hang = np.stack([x + ring_offset_h[0] * fade, y + box_y_b + ring_offset_h[1] * fade, -a], axis=1)
	return hang @ R.T + p_hand, a


def girth_clamp(co, w, targets, spec):
	"""Pull the surface of a limb in toward its bone's axis where it is fatter than the proxy's radius allows (the player's own arms
	and legs are what first person measures against the primitives, A9): past radius_m the excess keeps only `soft` of itself, fading in over
	the segment's ends and weighted by the bone's own weight, so a shoulder or a knee never creases. Returns (new vertices, report)."""
	orig = co
	out = co.copy()
	report = {}
	for bone, sp in spec.items():
		head, tail = np.array(targets[bone]["head"]), np.array(targets[bone]["tail"])
		ax = tail - head
		length = float(np.linalg.norm(ax))
		ax = ax / length
		rel = co - head
		t = rel @ ax
		perp = rel - np.outer(t, ax)
		r = np.linalg.norm(perp, axis=1)
		radius, soft = float(sp["radius_m"]), float(sp.get("soft", 0.25))
		target = np.where(r > radius, radius + (r - radius) * soft, r)
		scale = target / np.maximum(r, 1e-9)
		u = t / length
		fade = smoothstep(u, -0.05, 0.12) * (1.0 - smoothstep(u, 0.88, 1.05))
		k = w[:, NAMES.index(bone)] * fade
		out += perp * ((scale - 1.0) * k)[:, None]
		report[bone] = {"radius_m": radius, "vertices_over_radius": int(((r > radius) & (k > 1e-3)).sum()), "worst_overshoot_m": float(np.max((r - radius) * (k > 1e-3), initial=0.0))}
		co = out.copy()
	moved = np.linalg.norm(out - orig, axis=1)
	report["_total"] = {"vertices_moved": int((moved > 1e-5).sum()), "worst_move_m": float(moved.max())}
	return out, report


def replace_hands(cfg, extra):
	pf = cfg["parts"]["fists"]
	if pf.get("source", "tripo") != "tripo":
		import blender_parts
		return blender_parts.replace_hands(cfg, extra)
	slot_list = list(pf["slots"])
	g, faces, uv_loops, pix, _image = import_piece(pf["mesh"])
	pb.open_blend(pc.work_path(cfg, "03_rig.blend"))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	dirs = {k: np.array(v) for k, v in pb.scene_prop("pipe_dirs").items()}
	targets = pb.scene_prop("pipe_targets")
	boxes = {b["side"]: b for b in pc.table()["fist_boxes"]}
	co = pb.verts(me)
	w = pb.weights_matrix(body, NAMES)
	girth_report = {}
	if pf.get("girth"):
		co, girth_report = girth_clamp(co, w, targets, pf["girth"])
		pb.set_verts(me, co)
	start, total, lv = pb.poly_arrays(me)
	centers = pb.face_centers(me)
	cut = np.zeros(len(start), dtype=bool)
	deleted = {}
	for side in pc.SIDES:
		d, ph = dirs[side], np.array(targets[side + "Hand"]["head"])
		rel = centers - ph
		a = rel @ d
		rad = np.linalg.norm(rel - np.outer(a, d), axis=1)
		arm = w[:, [NAMES.index(side + b) for b in FIST_BONES]].sum(axis=1)
		fw = np.zeros(len(start))
		for k in range(int(total.max())):
			mask = total > k
			fw[mask] += arm[lv[start[mask] + k]]
		fw /= np.maximum(total, 1)
		sel = (a > pf["cut_a_m"]) & (rad < pf["radius_max_m"]) & (fw > 0.5) & (np.linalg.norm(rel, axis=1) < pf["reach_max_m"])
		deleted[side] = int(sel.sum())
		cut |= sel
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(cut)[0]], context="FACES")
	# the open hand's fingertips and thumb tip that the plane left behind float free of the body: drop every small component
	bm.faces.ensure_lookup_table()
	seen, stray = set(), []
	for f in bm.faces:
		if f.index in seen:
			continue
		stack, comp = [f], []
		seen.add(f.index)
		while stack:
			x = stack.pop()
			comp.append(x)
			for e in x.edges:
				for g2 in e.link_faces:
					if g2.index not in seen:
						seen.add(g2.index)
						stack.append(g2)
		if len(comp) < int(pf.get("min_component_faces", 200)):
			stray += comp
	if stray:
		bmesh.ops.delete(bm, geom=stray, context="FACES")
	loose = [v for v in bm.verts if not v.link_faces]
	if loose:
		bmesh.ops.delete(bm, geom=loose, context="VERTS")
	bm.to_mesh(me)
	bm.free()
	me.update()
	co = pb.verts(me)
	bnd = boundary_vertices(me)

	# the ring each cut leaves, and the radius of the body where the piece's strap begins
	made, dense_objs, report_sides = [], [], {}
	band = (g[:, 1] > -0.2) & (g[:, 1] < -0.05)
	centre = ((g[band, 0].min() + g[band, 0].max()) / 2.0, (g[band, 2].min() + g[band, 2].max()) / 2.0)
	strap = g[:, 1] < pf["map"]["y_g"][0] + 0.05
	sc = ((g[strap, 0].min() + g[strap, 0].max()) / 2.0, (g[strap, 2].min() + g[strap, 2].max()) / 2.0)
	r_strap = float(np.percentile(np.linalg.norm(g[strap][:, [0, 2]] - np.array(sc), axis=1), 90)) * pf["xz_scale_m"]
	offsets = np.concatenate([[0], np.cumsum([len(f) for f in faces])[:-1]]).astype(int)
	for side in pc.SIDES:
		d, ph = dirs[side], np.array(targets[side + "Hand"]["head"])
		R = rotation_between(np.array(pc.HANGING), d)
		rel = co[bnd] - ph
		a = rel @ d
		rad = np.linalg.norm(rel - np.outer(a, d), axis=1)
		near = bnd[(np.abs(a - pf["cut_a_m"]) < 0.02) & (rad < pf["radius_max_m"])]
		if len(near) < 6:
			pc.fail("%s: no open ring near the cut (%d boundary vertices)" % (side, len(near)))
		rel = co[near] - ph
		a_n = rel @ d
		perp = rel - np.outer(a_n, d)
		c_perp = perp.mean(axis=0)
		r_ring = float(np.percentile(np.linalg.norm(perp - c_perp, axis=1), 90))
		# the body's radius where the strap's bottom plane sits (the ledge is the difference)
		rel_all = co - ph
		a_all = rel_all @ d
		rad_all = np.linalg.norm(rel_all - np.outer(a_all, d), axis=1)
		at = (np.abs(a_all - pf["map"]["a_m"][0]) < 0.012) & (rad_all < pf["radius_max_m"])
		r_body = float(np.percentile(rad_all[at], 90)) if at.any() else r_ring
		flare = float(np.clip((max(r_body, r_ring) + pf["strap_margin_m"]) / r_strap, 1.0, pf["flare_max"]))
		off_h = R.T @ c_perp
		world, a_arm = place_piece(g, side, pf, centre, flare, (off_h[0], off_h[1]), R, ph, -boxes[side]["center_offset"][2])
		fcs = faces if side == "Left" else [tuple(reversed(f)) for f in faces]
		uvs = uv_loops if side == "Left" else np.concatenate([uv_loops[o:o + len(f)][::-1] for o, f in zip(offsets, faces)])
		dense = pb.new_mesh_object("FistDense" + side, world, fcs)
		dme = dense.data
		layer = dme.uv_layers.new(name="UVMap")
		layer.data.foreach_set("uv", np.asarray(uvs, dtype=np.float32).ravel())
		bm = bmesh.new()
		bm.from_mesh(dme)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		bm.to_mesh(dme)
		bm.free()
		dme.update()
		labels, de = piece_labels(dme, dme.uv_layers[0], pix, slot_list)
		# the colour borders: vertices where two labels meet
		nb, pairs = face_neighbours(dme)
		ev = np.empty(len(dme.edges) * 2, dtype=np.int32)
		dme.edges.foreach_get("vertices", ev)
		ev = ev.reshape(-1, 2)
		keep = np.zeros(len(dme.vertices), dtype=bool)
		for e, fs in pairs.items():
			if len(fs) == 2 and labels[fs[0]] != labels[fs[1]]:
				keep[ev[e]] = True
		deci, tris, worst = decimate_with_borders(dense, int(pf["target_tris"]), keep)
		deci.name = "Fist" + side
		# the collapse can leave a pinhole where the piece's own mesh was thin: close every small hole
		bm = bmesh.new()
		bm.from_mesh(deci.data)
		open_edges = [e for e in bm.edges if e.is_boundary]
		holes = 0
		if open_edges:
			made_faces = bmesh.ops.holes_fill(bm, edges=open_edges, sides=int(pf.get("hole_sides_max", 16)))["faces"]
			holes = len(made_faces)
			bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		still_open = sum(1 for e in bm.edges if e.is_boundary)
		bm.to_mesh(deci.data)
		bm.free()
		deci.data.update()
		# relabel from the dense piece
		dco = pb.verts(dme)
		sdense, tdense, ldense = pb.poly_arrays(dme)
		bvh = BVHTree.FromPolygons([tuple(v) for v in dco], [tuple(int(i) for i in ldense[sdense[f]:sdense[f] + tdense[f]]) for f in range(len(sdense))])
		fme = deci.data
		fc = pb.face_centers(fme)
		new_label = np.zeros(len(fme.polygons), dtype=np.int32)
		for i, c in enumerate(fc):
			new_label[i] = labels[bvh.find_nearest(Vector(c))[2]]
		attr = fme.attributes.new(SLOT_ATTR, "INT", "FACE")
		attr.data.foreach_set("value", new_label.astype(np.int32) + 1)
		for vg in list(deci.vertex_groups):
			deci.vertex_groups.remove(vg)
		fco = pb.verts(fme)
		a_f = (fco - ph) @ d  # axial position along the arm, positive toward the fingers
		hand_w = smoothstep(a_f, pf["ramp_a_m"][0], pf["ramp_a_m"][1])
		fw_ = np.zeros((len(fco), len(NAMES)))
		fw_[:, NAMES.index(side + "Hand")] = hand_w
		fw_[:, NAMES.index(side + "LowerArm")] = 1.0 - hand_w
		pb.write_weights(deci, NAMES, fw_)
		for p in fme.polygons:
			p.use_smooth = True
		made.append(deci)
		dense_objs.append(dense)
		for p in dme.polygons:
			p.use_smooth = True
		report_sides[side] = {"faces_deleted": deleted[side], "ring_vertices": int(len(near)), "ring_radius_m": r_ring, "body_radius_at_strap_m": r_body,
			"strap_radius_m": r_strap, "flare": flare, "ring_offset_m": float(np.linalg.norm(c_perp)), "dense_triangles": len(faces), "triangles": tris,
			"protected_vertices": int(keep.sum()), "protected_worst_move_m": worst, "hole_faces_filled": holes, "open_edges_left": still_open, "delta_e_mean": de,
			"labels": {int(s): int((labels == s).sum()) for s in np.unique(labels)}}
	# keep the dense, textured pieces (in world space) for the detail mask, then join the decimated ones into the body
	img = bpy.data.images.new("FistTexture", pix.shape[1], pix.shape[0], alpha=False)
	img.pixels.foreach_set(pix.ravel())
	img.pack()
	mat = bpy.data.materials.new("FistTexture")
	mat.use_nodes = True
	node = mat.node_tree.nodes.new("ShaderNodeTexImage")
	node.image = img
	for o in dense_objs:
		o.data.materials.append(mat)
	bpy.data.libraries.write(pc.work_path(cfg, "04a_fists_dense.blend"), set(dense_objs) | {mat, img}, fake_user=True)
	for o in dense_objs:
		bpy.data.objects.remove(o)
	if SLOT_ATTR not in me.attributes:
		a = me.attributes.new(SLOT_ATTR, "INT", "FACE")
		a.data.foreach_set("value", np.zeros(len(me.polygons), dtype=np.int32))
	pb.activate(body)
	for o in made:
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
		ph = np.array(targets[side + "Hand"]["head"])
		R = rotation_between(np.array(pc.HANGING), dirs[side])
		rest = (co[sel] - ph) @ R + np.array(pc.table_joints()[side + "Hand"])
		box = boxes[side]
		bc = np.array(pc.g2b(box["center_rest_global"]))
		ext = rest.max(axis=0) - rest.min(axis=0)
		want = np.array([box["size"][0], box["size"][2], box["size"][1]])
		fist_check[side] = {"vertices": int(sel.sum()), "centroid_offset_m": float(np.linalg.norm(rest.mean(axis=0) - bc)),
			"bbox_centre_offset_m": float(np.linalg.norm((rest.max(axis=0) + rest.min(axis=0)) / 2 - bc)), "extent_ratio": (ext / want).tolist()}
	pb.save_blend(pc.work_path(cfg, "04_parts.blend"))
	return {"enabled": True, "source": "tripo", "mesh": pf["mesh"], "stray_faces_removed": len(stray), "girth": girth_report, "sides": report_sides, "fist_check": fist_check, "triangles_after": pb.triangle_count(body.data)}


# --------------------------------------------------------------------------- the first-person split

TORSO_SET = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]


def dominant_per_face(me, w):
	start, total, lv = pb.poly_arrays(me)
	acc = np.zeros((len(start), w.shape[1]))
	for k in range(int(total.max())):
		mask = total > k
		acc[mask] += w[lv[start[mask] + k]]
	return np.argmax(acc, axis=1)


def boundary_loops(bm):
	"""Ordered lists of BMLoops, one per closed boundary loop, in the direction of the surrounding faces' winding."""
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


def heal_slits(bm, max_len, rounds):
	"""Collapse the short open edges that a generated mesh leaves where two surfaces nearly touch (a sliver of one triangle, an
	edge shared by three): each merges its two vertices, then the faces that collapse to nothing go. Only edges shorter than
	max_len qualify, so the long edges of a real cut are never touched. Returns the number of edges collapsed."""
	if max_len <= 0.0:
		return 0
	total = 0
	for _ in range(rounds):
		slits = [e for e in bm.edges if e.is_boundary and e.calc_length() < max_len]
		if not slits:
			break
		bmesh.ops.collapse(bm, edges=slits, uvs=True)
		bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])
		total += len(slits)
	return total


def small_open_edges(bm, ring_min_edges):
	"""The open edges that do not belong to a long boundary loop (a loop of ring_min_edges or more edges is a real cut, like the
	forearm's ring; shorter ones are defects of the generated mesh)."""
	be = [e for e in bm.edges if e.is_boundary]
	parent = {}

	def find(x):
		while parent.setdefault(x, x) != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	for e in be:
		a, b = (v.index for v in e.verts)
		parent[find(a)] = find(b)
	size = {}
	for e in be:
		r = find(e.verts[0].index)
		size[r] = size.get(r, 0) + 1
	return [e for e in be if size[find(e.verts[0].index)] < ring_min_edges]


def repair_defects(bm, ring_min_edges, sides, rounds=4):
	"""Cut out the generated mesh's non-manifold edges and its short open loops (the faces round them) and close what is left with
	holes_fill: a manifold patch instead of a slit. Returns (faces deleted, faces made)."""
	deleted = made = 0
	for _ in range(rounds):
		bad_edges = [e for e in bm.edges if len(e.link_faces) > 2] + small_open_edges(bm, ring_min_edges)
		if not bad_edges:
			break
		faces = list({f for e in bad_edges for f in e.link_faces})
		deleted += len(faces)
		bmesh.ops.delete(bm, geom=faces, context="FACES")
		loose = [v for v in bm.verts if not v.link_faces]
		if loose:
			bmesh.ops.delete(bm, geom=loose, context="VERTS")
		edges = small_open_edges(bm, ring_min_edges)
		if edges:
			made += len(fill_holes_edges(bm, edges, sides))
	return deleted, made


def fill_holes_edges(bm, edges, sides):
	made = bmesh.ops.holes_fill(bm, edges=edges, sides=sides)["faces"]
	uv_p = bm.loops.layers.uv.get("palette") or bm.loops.layers.uv.active
	uv_d = bm.loops.layers.uv.get("detail")
	new = set(made)
	for f in made:
		src = None
		for e in f.edges:
			for nb in e.link_faces:
				if nb not in new:
					src = nb
					break
			if src is not None:
				break
		f.smooth = True
		if src is not None:
			for lp in f.loops:
				lp[uv_p].uv = src.loops[0][uv_p].uv.copy()
				if uv_d is not None:
					lp[uv_d].uv = src.loops[0][uv_d].uv.copy()
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return made


def fill_holes(bm, sides):
	"""Close every boundary loop of at most `sides` edges (pinholes the generator left; the real cut loops are longer) and give
	each new face the palette and detail UVs of a neighbour. Returns the number of faces made."""
	edges = [e for e in bm.edges if e.is_boundary]
	if not edges:
		return 0
	made = bmesh.ops.holes_fill(bm, edges=edges, sides=sides)["faces"]
	uv_p = bm.loops.layers.uv.get("palette") or bm.loops.layers.uv.active
	uv_d = bm.loops.layers.uv.get("detail")
	new = set(made)
	for f in made:
		src = None
		for e in f.edges:
			for nb in e.link_faces:
				if nb not in new:
					src = nb
					break
			if src is not None:
				break
		f.smooth = True
		if src is not None:
			for lp in f.loops:
				lp[uv_p].uv = src.loops[0][uv_p].uv.copy()
				if uv_d is not None:
					lp[uv_d].uv = src.loops[0][uv_d].uv.copy()
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return len(made)


def add_caps(me, depth, rings, heal_max=0.0):
	"""Close every open loop of a mesh with an inward rounded cap (rings rings, depth deep); returns the cap report."""
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	dl = bm.verts.layers.deform.verify()
	uv_p = bm.loops.layers.uv["palette"]
	uv_d = bm.loops.layers.uv.get("detail")
	cap_attr = bm.faces.layers.int.get(CAP_ATTR) or bm.faces.layers.int.new(CAP_ATTR)
	report = []
	for order in boundary_loops(bm):
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
				for gi, wt in v[dl].items():
					q[dl][gi] = wt
				ring.append(q)
			ring_verts.append(ring)
		apex = bm.verts.new(tuple(c + n_in * depth))
		acc = {}
		for v in verts:
			for gi, wt in v[dl].items():
				acc[gi] = acc.get(gi, 0.0) + wt / len(verts)
		for gi, wt in acc.items():
			apex[dl][gi] = wt
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
		report.append({"vertices": n, "centre": c.tolist(), "dir_in": n_in.tolist(), "orientation_flipped": flipped, "tris": 2 * n * (rings - 1) + n})
	# a slit the cap walk stepped over (a vertex shared by three faces on a cut loop) is a short open edge now: collapse it
	left = heal_slits(bm, heal_max, 3)
	cut_out, patched = repair_defects(bm, 10 ** 9, 12, rounds=6) if heal_max > 0.0 else (0, 0)
	report.append({"slit_edges_collapsed_after_caps": left, "defect_faces_cut_out": cut_out, "defect_faces_patched": patched,
		"open_edges_left": sum(1 for e in bm.edges if e.is_boundary)})
	bmesh.ops.triangulate(bm, faces=bm.faces[:])  # the hole patches are n-gons and the caps quads: every later step reads triangles
	bm.to_mesh(me)
	bm.free()
	me.update()
	return report


def separate_faces(body, mask, name):
	"""Move the faces of `body` selected by mask into a new object `name`; returns it."""
	me = body.data
	pb.activate(body)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_mode(type="FACE")
	bpy.ops.mesh.select_all(action="DESELECT")
	bpy.ops.object.mode_set(mode="OBJECT")
	for p in me.polygons:
		p.select = bool(mask[p.index])
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.separate(type="SELECTED")
	bpy.ops.object.mode_set(mode="OBJECT")
	new = [o for o in bpy.data.objects if o.type == "MESH" and o != body and o.name not in ("Body", "Body__fp_hidden")]
	part = new[-1]
	part.name = name
	part.data.name = name
	return part


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

	# ----- weld the hairline cracks the generator leaves (open edges a millimetre apart): boundary vertices within weld_boundary_m merge
	bm = bmesh.new()
	bm.from_mesh(me)
	open_before = sum(1 for e in bm.edges if e.is_boundary)
	bvs = list({v for e in bm.edges if e.is_boundary for v in e.verts})
	if bvs and float(sc.get("weld_boundary_m", 0.0)) > 0.0:
		bmesh.ops.remove_doubles(bm, verts=bvs, dist=float(sc["weld_boundary_m"]))
	open_after = sum(1 for e in bm.edges if e.is_boundary)
	filled = fill_holes(bm, int(sc.get("hole_sides_max", 12)))
	healed = heal_slits(bm, float(sc.get("heal_edge_max_m", 0.0)), int(sc.get("heal_rounds", 3)))
	cut_out = patched = 0
	open_after_fill = sum(1 for e in bm.edges if e.is_boundary)
	bm.to_mesh(me)
	bm.free()
	me.update()

	# ----- bisect: each upper arm across its axis at upper_arm_cut, then the horizontal cut through every face that can be hidden
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	dl = bm.verts.layers.deform.verify()
	torso_cols = [col[n] for n in TORSO_SET]
	shoulder_cols = [col[s2 + "Shoulder"] for s2 in pc.SIDES]
	arm_cols = [col[s2 + "UpperArm"] for s2 in pc.SIDES]

	def dominant(f):
		acc = {}
		for v in f.verts:
			for gi, wt in v[dl].items():
				acc[gi] = acc.get(gi, 0.0) + wt
		return max(acc, key=acc.get) if acc else -1
	names_by_group = {vg.index: col.get(vg.name, -1) for vg in body.vertex_groups}

	def faces_of(cols):
		want = set(cols)
		return [f for f in bm.faces if f.is_valid and names_by_group.get(dominant(f), -1) in want]

	def bisect(faces, co_, no_):
		geom = list(faces) + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
		bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=co_, plane_no=no_)
	for side in pc.SIDES:
		ua, axis, length = arm_axes[side]
		bisect(faces_of([col[side + "UpperArm"]]), tuple(ua + axis * cut_t), tuple(axis / length))
	# the horizontal cut goes through every face that can be hidden, the arms' and shoulders' too, so no hidden face hangs below it
	bisect(faces_of(torso_cols + shoulder_cols + arm_cols), (0.0, 0.0, z_cut), (0.0, 0.0, 1.0))
	bm.to_mesh(me)
	bm.free()
	me.update()

	# ----- classify
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
		hidden |= zone & (t < cut_t) & (centers[:, 2] > z_cut - 1e-6)
	hid = separate_faces(body, hidden, pb.BODY_HIDDEN)
	body = bpy.data.objects[pb.BODY]

	# ----- the hidden part's own pinholes (the generated mesh's defects, not its cuts): patch the short open loops
	bm = bmesh.new()
	bm.from_mesh(hid.data)
	hid_cut, hid_patched = repair_defects(bm, int(sc.get("ring_min_edges", 14)), int(sc.get("hole_sides_max", 12)))
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.to_mesh(hid.data)
	bm.free()
	hid.data.update()

	# ----- inward rounded caps on every open loop of the visible parts
	depth, rings = float(sc.get("cap_depth_m", 0.03)), int(sc.get("cap_rings", 4))
	heal = float(sc.get("heal_edge_max_m", 0.0))
	cap_report = {"Body": add_caps(body.data, depth, rings, heal)}
	parts = [body, hid]
	over_four = 0
	for o in parts:
		pb.attach_armature(o, bpy.data.objects[pb.ARMATURE])
		ww = pb.weights_matrix(o, NAMES)
		over_four += int(((ww > 1e-4).sum(axis=1) > 4).sum())
		pb.write_weights(o, NAMES, pb.limit_and_normalize(ww, int(cfg.get("rig", {}).get("max_influences", 4))), remove_others=True)
		for p in o.data.polygons:
			p.use_smooth = True
	pb.save_blend(pc.work_path(cfg, "06_split.blend"))
	hc = pb.verts(hid.data)
	return {"enabled": True, "open_edges_before_weld": open_before, "open_edges_after_weld": open_after, "hole_faces_filled": filled, "slit_edges_collapsed": healed, "defect_faces_cut_out": cut_out, "defect_faces_patched": patched, "open_edges_after_fill": open_after_fill, "z_cut_m": z_cut, "upper_arm_cut": cut_t, "hidden_faces": int(hidden.sum()), "visible_triangles": pb.triangle_count(body.data),
		"hidden_triangles": pb.triangle_count(hid.data), "hidden_defect_faces_cut_out": hid_cut, "hidden_defect_faces_patched": hid_patched,
		"vertices_over_four_influences_before_limit": over_four, "caps": cap_report,
		"hidden_bbox": {"min": hc.min(axis=0).tolist(), "max": hc.max(axis=0).tolist()}}


if __name__ == "__main__":
	mode = pc.step_argv()[1] if len(pc.step_argv()) > 1 else "replace"
	pb.run_step("parts", replace_hands if mode == "replace" else split_fp)
