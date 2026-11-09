"""LD-ASSET's Blender step (Phase 1, docs/video/P1.md): one character's video art, in one headless process.

	blender --background --factory-startup --python-exit-code 1 --python tools/video/blender_asset.py -- <name> <workdir> [options]

Reads the finished A-pose work file assets/source/characters/<name>/work/<name>.blend (the game's own mesh, UV1 "palette" and
UV2 "detail", its custom shading normals and its hull normals; the sources stay where they are) and writes into <workdir>:

	maps.npz       the character's surface in its UV2 layout at --size texels (row 0 = glTF v 0): the rest-pose position and
	               normal, the palette UV of the face (UV1), the signed curvature (1/m, convex positive, from the dihedral
	               angles of the mesh, smoothed over rings), the dominant bone, the mesh index and the coverage. tools/video/art_paint.py
	               turns these into the painted albedo and the ink (crease) mask.
	meta.json      the bone names, the head's box and where each mesh's UV islands are.
	<name>_video.glb   the game's GLB with the FACE NORMALS TRANSFERRED FROM AN ELLIPSOID PROXY (Blender's Data Transfer modifier,
	               custom normals, from a UV sphere scaled to the head, weighted by the Head bone's weights and the front of the
	               face) so a face's light and shadow is one clean big shape, not the decimated mesh's facets. Same meshes, same
	               weights, same UVs and hull normals as the shipped GLB (export through tools/pipeline/blender_export.export_glb).

Round 2 (LD-ART2, docs/video/P1.md, after Gate 2): the UV2 layout the textures are made in is NEW. The game's UV2 ("detail") is the layout of
its detail mask: islands of a few hundred texels, a quarter of the player's arm triangles collapsed to slivers or to a point (no texel
to paint: the black holes of Gate 2). The video GLB carries a fresh unwrap in the same "detail" layer (Blender's smart project, every
island rescaled so the texel density follows assets/source/video_art/<name>/paint.json "layout" weights: the hands, the forearms and
the head get more, then packed at --size). The game's detail mask no longer matches it, so CineArtRig turns the game's mask off for
a character that has video art. The player also gets smoothed shading normals (paint.json "normals", the Punk's recipe), where
the game's own are lumpy at a centimetre: the toon bands read as facets on the first-person arm.

Options: --size N (map size, default 4096), --no-normals (export the mesh as it is), --proxy-strength S (0..1, default 0.85),
--keep-uv2 (do not unwrap: the game's layout), --only-maps (skip the export). Video only: the game's files are never written.
Never the Blender MCP.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pipeline"))
import pipe_blender as pb  # noqa: E402
import blender_export as be  # noqa: E402

# +Y is the front of every character in the work files (glTF -Z after the exporter's Y-up turn).
FRONT = np.array([0.0, 1.0, 0.0])
CURVATURE_RINGS = 3
CURVATURE_CLIP = 60.0


def arguments():
	args = sys.argv[sys.argv.index("--") + 1:]
	opts = {"size": 4096, "keep_uv2": False, "no_normals": False, "proxy_strength": 0.85, "only_maps": False}
	pos = []
	i = 0
	while i < len(args):
		a = args[i]
		if a == "--size":
			opts["size"] = int(args[i + 1])
			i += 1
		elif a == "--proxy-strength":
			opts["proxy_strength"] = float(args[i + 1])
			i += 1
		elif a == "--no-normals":
			opts["no_normals"] = True
		elif a == "--keep-uv2":
			opts["keep_uv2"] = True
		elif a == "--only-maps":
			opts["only_maps"] = True
		else:
			pos.append(a)
		i += 1
	return pos[0], pos[1], opts


def bone_weights(obj, bone_names):
	"""(vertices, bones) float32 weights of `obj`'s vertex groups, in `bone_names` order."""
	index = {g.index: bone_names.index(g.name) for g in obj.vertex_groups if g.name in bone_names}
	out = np.zeros((len(obj.data.vertices), len(bone_names)), dtype=np.float32)
	for v in obj.data.vertices:
		for g in v.groups:
			if g.group in index:
				out[v.index, index[g.group]] = g.weight
	return out


def vertex_curvature(me):
	"""Signed curvature per vertex (1/m, convex positive): each edge's signed dihedral angle over its length, averaged
	over a vertex's edges weighted by length, then smoothed over CURVATURE_RINGS rings of the edge graph."""
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.edges.ensure_lookup_table()
	n = len(bm.verts)
	total = np.zeros(n)
	weight = np.zeros(n)
	ea, eb = [], []
	for e in bm.edges:
		a, b = e.verts[0].index, e.verts[1].index
		ea.append(a)
		eb.append(b)
		if len(e.link_faces) != 2:
			continue
		length = e.calc_length()
		if length < 1e-7:
			continue
		angle = e.calc_face_angle_signed()
		total[a] += angle
		total[b] += angle
		weight[a] += length
		weight[b] += length
	bm.free()
	curv = np.where(weight > 0, total / np.maximum(weight, 1e-9), 0.0)
	ea = np.array(ea)
	eb = np.array(eb)
	count = np.zeros(n)
	np.add.at(count, ea, 1.0)
	np.add.at(count, eb, 1.0)
	for _ in range(CURVATURE_RINGS):
		acc = curv.copy()
		np.add.at(acc, ea, curv[eb])
		np.add.at(acc, eb, curv[ea])
		curv = acc / (count + 1.0)
	return np.clip(curv, -CURVATURE_CLIP, CURVATURE_CLIP)


def mesh_loops(obj):
	"""Per-loop arrays of `obj`: the UV2 ("detail") and UV1 ("palette") coordinates, the shading normals, the vertex index."""
	me = obj.data
	nl = len(me.loops)
	uv2 = np.zeros(nl * 2, dtype=np.float32)
	me.uv_layers["detail"].data.foreach_get("uv", uv2)
	uv1 = np.zeros(nl * 2, dtype=np.float32)
	me.uv_layers["palette"].data.foreach_get("uv", uv1)
	nrm = np.zeros(nl * 3, dtype=np.float32)
	me.corner_normals.foreach_get("vector", nrm)
	lv = np.zeros(nl, dtype=np.int32)
	me.loops.foreach_get("vertex_index", lv)
	return uv2.reshape(-1, 2), uv1.reshape(-1, 2), nrm.reshape(-1, 3), lv


def bake_maps(objs, bone_names, size):
	"""Rasterise the meshes' triangles in UV2 space into per-texel surface attributes (see the module doc)."""
	pos = np.zeros((size, size, 3), np.float32)
	nrm = np.zeros((size, size, 3), np.float16)
	uv1 = np.zeros((size, size, 2), np.float16)
	curv = np.zeros((size, size), np.float16)
	bone = np.full((size, size), -1, np.int16)
	mesh_id = np.full((size, size), -1, np.int8)
	cover = np.zeros((size, size), bool)
	for mi, obj in enumerate(objs):
		me = obj.data
		co = pb.verts(me).astype(np.float32)
		curvature = vertex_curvature(me)
		weights = bone_weights(obj, bone_names)
		dom = weights.argmax(axis=1).astype(np.int16)
		uv2, uv1l, nl, lv = mesh_loops(obj)
		me.calc_loop_triangles()
		nt = len(me.loop_triangles)
		tl = np.zeros(nt * 3, np.int32)
		me.loop_triangles.foreach_get("loops", tl)
		tl = tl.reshape(-1, 3)
		for t in range(nt):
			loops = tl[t]
			p = uv2[loops].astype(np.float64)
			px = p[:, 0] * size
			py = (1.0 - p[:, 1]) * size
			x0 = max(int(math.floor(px.min() - 0.5)), 0)
			x1 = min(int(math.ceil(px.max() + 0.5)), size - 1)
			y0 = max(int(math.floor(py.min() - 0.5)), 0)
			y1 = min(int(math.ceil(py.max() + 0.5)), size - 1)
			if x1 < x0 or y1 < y0:
				continue
			gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
			d = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
			if abs(d) < 1e-12:
				continue
			w0 = ((py[1] - py[2]) * (gx - px[2]) + (px[2] - px[1]) * (gy - py[2])) / d
			w1 = ((py[2] - py[0]) * (gx - px[2]) + (px[0] - px[2]) * (gy - py[2])) / d
			w2 = 1.0 - w0 - w1
			inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
			if not inside.any():
				continue
			ys, xs = np.nonzero(inside)
			a, b, c = w0[inside], w1[inside], w2[inside]
			ys = ys + y0
			xs = xs + x0
			v = lv[loops]
			pos[ys, xs] = a[:, None] * co[v[0]] + b[:, None] * co[v[1]] + c[:, None] * co[v[2]]
			n = a[:, None] * nl[loops[0]] + b[:, None] * nl[loops[1]] + c[:, None] * nl[loops[2]]
			nrm[ys, xs] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
			uv1[ys, xs] = uv1l[loops[0]]
			curv[ys, xs] = a * curvature[v[0]] + b * curvature[v[1]] + c * curvature[v[2]]
			nearest = np.where(a >= b, np.where(a >= c, v[0], v[2]), np.where(b >= c, v[1], v[2]))
			bone[ys, xs] = dom[nearest]
			mesh_id[ys, xs] = mi
			cover[ys, xs] = True
	return {"pos": pos, "nrm": nrm, "uv1": uv1, "curv": curv, "bone": bone, "mesh": mesh_id, "cover": cover}


def head_box(obj, bone_names):
	"""(centre, radii, vertex indices) of the vertices weighted mostly to the Head bone: the proxy ellipsoid's size."""
	w = bone_weights(obj, bone_names)[:, bone_names.index("Head")]
	co = pb.verts(obj.data)
	idx = np.nonzero(w > 0.5)[0]
	lo, hi = co[idx].min(axis=0), co[idx].max(axis=0)
	return (lo + hi) / 2.0, (hi - lo) / 2.0, idx


def transfer_face_normals(obj, bone_names, strength):
	"""Face normals from an ellipsoid proxy: a UV sphere scaled to the head's box, Data Transfer (custom normals, nearest face
	interpolated) onto the mesh through a vertex group that is the Head weight times the front of the head, applied."""
	centre, radii, _idx = head_box(obj, bone_names)
	co = pb.verts(obj.data)
	w = bone_weights(obj, bone_names)[:, bone_names.index("Head")]
	nrm = np.zeros((len(co), 3))
	me = obj.data
	vn = np.zeros(len(me.vertices) * 3)
	me.vertex_normals.foreach_get("vector", vn)
	nrm = vn.reshape(-1, 3)
	front = np.clip((nrm @ FRONT - 0.1) / 0.5, 0.0, 1.0) * np.clip((co[:, 1] - centre[1]) / max(radii[1], 1e-6) + 0.6, 0.0, 1.0)
	group = obj.vertex_groups.new(name="video_face_proxy")
	for i in range(len(co)):
		weight = float(w[i] * front[i])
		if weight > 0.001:
			group.add([i], weight, "REPLACE")
	bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0, location=tuple(centre))
	proxy = bpy.context.active_object
	proxy.name = "video_face_proxy"
	proxy.scale = tuple(radii * 1.0)
	bpy.ops.object.shade_smooth()
	proxy.data.polygons.foreach_set("use_smooth", [True] * len(proxy.data.polygons))
	mod = obj.modifiers.new("video_face_transfer", "DATA_TRANSFER")
	mod.object = proxy
	mod.use_loop_data = True
	mod.data_types_loops = {"CUSTOM_NORMAL"}
	mod.loop_mapping = "POLYINTERP_NEAREST"
	mod.mix_mode = "REPLACE"
	mod.mix_factor = strength
	mod.vertex_group = group.name
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
	bpy.ops.object.modifier_apply(modifier=mod.name)
	obj.vertex_groups.remove(obj.vertex_groups["video_face_proxy"])
	bpy.data.objects.remove(proxy, do_unlink=True)
	return {"centre": [round(float(x), 4) for x in centre], "radii": [round(float(x), 4) for x in radii]}


def uv2_slivers(objs, size):
	"""Per mesh: the triangles whose UV2 area is under half a texel (nothing to bake: they would sample padding) and their share."""
	out = {}
	for o in objs:
		me = o.data
		uv, _a, _b, _c = mesh_loops(o)
		me.calc_loop_triangles()
		tl = np.zeros(len(me.loop_triangles) * 3, np.int32)
		me.loop_triangles.foreach_get("loops", tl)
		p = uv[tl.reshape(-1, 3)].astype(np.float64) * size
		area = 0.5 * np.abs((p[:, 1, 0] - p[:, 0, 0]) * (p[:, 2, 1] - p[:, 0, 1]) - (p[:, 2, 0] - p[:, 0, 0]) * (p[:, 1, 1] - p[:, 0, 1]))
		out[o.name] = {"triangles": int(len(area)), "under_half_texel": int((area < 0.5).sum())}
	return out


def load_config(name):
	with open(os.path.join("assets", "source", "video_art", name, "paint.json")) as f:
		return json.load(f)


def triangle_islands(obj):
	"""(island index per polygon, island count): polygons joined where two corners share a vertex and a UV2 position."""
	me = obj.data
	n = len(me.polygons)
	parent = list(range(n))

	def find(a):
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a

	uv, _uv1, _nrm, lv = mesh_loops(obj)
	loop_poly = np.zeros(len(me.loops), np.int32)
	for p in me.polygons:
		loop_poly[p.loop_start:p.loop_start + p.loop_total] = p.index
	seen = {}
	key = np.round(uv * 20000.0).astype(np.int64)
	for li in range(len(me.loops)):
		k = (int(lv[li]), int(key[li, 0]), int(key[li, 1]))
		pi = int(loop_poly[li])
		other = seen.get(k)
		if other is None:
			seen[k] = pi
		else:
			a, b = find(pi), find(other)
			if a != b:
				parent[a] = b
	roots = np.array([find(i) for i in range(n)])
	_u, inverse = np.unique(roots, return_inverse=True)
	return inverse, len(_u)


def relayout_uv2(objs, bone_names, cfg, size):
	"""Replace the "detail" (UV2) layer of `objs` with a new unwrap packed in one atlas (see the module doc). Returns a report."""
	layout = cfg.get("layout", {})
	weights_by_bone = layout.get("weights", {})
	default_weight = float(layout.get("default_weight", 1.0))
	margin_px = float(layout.get("margin_px", 20))
	bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
		o.data.uv_layers.active = o.data.uv_layers["detail"]
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(float(layout.get("angle_deg", 66.0))), island_margin=0.002, area_weight=0.0,
		correct_aspect=True, scale_to_bounds=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	# the density of every island against the median, then the weights
	infos = []
	for oi, o in enumerate(objs):
		me = o.data
		co = pb.verts(me)
		tv, _tp = pb.tri_arrays(me)
		me.calc_loop_triangles()
		bw = bone_weights(o, bone_names)
		dom = bw.argmax(axis=1)
		uv, _uv1, _n, lv = mesh_loops(o)
		isl, count = triangle_islands(o)
		area3 = np.zeros(count)
		areaz = np.zeros(count)
		wsum = np.zeros(count)
		cnt = np.zeros(count)
		centre = np.zeros((count, 2))
		for p in me.polygons:
			vs = [lv[p.loop_start + k] for k in range(p.loop_total)]
			a3 = 0.5 * np.linalg.norm(np.cross(co[vs[1]] - co[vs[0]], co[vs[2]] - co[vs[0]]))
			q = uv[p.loop_start:p.loop_start + 3].astype(np.float64)
			az = 0.5 * abs((q[1, 0] - q[0, 0]) * (q[2, 1] - q[0, 1]) - (q[2, 0] - q[0, 0]) * (q[1, 1] - q[0, 1]))
			i = isl[p.index]
			area3[i] += a3
			areaz[i] += az
			w = np.mean([float(weights_by_bone.get(bone_names[dom[v]], default_weight)) for v in vs])
			wsum[i] += w * a3
			cnt[i] += a3
			centre[i] += q.mean(axis=0) * a3
		infos.append((isl, area3, areaz, wsum / np.maximum(cnt, 1e-12), centre / np.maximum(area3, 1e-12)[:, None], uv))
	dens = np.concatenate([np.sqrt(i[2] / np.maximum(i[1], 1e-12)) for i in infos])
	area_all = np.concatenate([i[1] for i in infos])
	ok = area_all > 1e-8
	ref = float(np.median(dens[ok]))
	for o, (isl, area3, areaz, wt, cen, uv) in zip(objs, infos):
		d = np.sqrt(areaz / np.maximum(area3, 1e-12))
		scale = np.where(area3 > 1e-8, wt * ref / np.maximum(d, 1e-9), 1.0)
		scale = np.clip(scale, 0.05, 20.0)
		me = o.data
		new = uv.copy()
		for p in me.polygons:
			i = isl[p.index]
			sl = slice(p.loop_start, p.loop_start + p.loop_total)
			new[sl] = cen[i] + (uv[sl] - cen[i]) * scale[i]
		me.uv_layers["detail"].data.foreach_set("uv", new.astype(np.float32).ravel())
		me.update()
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	props = bpy.ops.uv.pack_islands.get_rna_type().properties.keys()
	kw = dict(rotate=True, margin=margin_px / size)
	if "margin_method" in props:
		kw["margin_method"] = "ADD"
	if "shape_method" in props:
		kw["shape_method"] = layout.get("shape", "CONCAVE")
	if "scale" in props:
		kw["scale"] = True
	bpy.ops.uv.pack_islands(**kw)
	bpy.ops.object.mode_set(mode="OBJECT")
	rep = {"islands": int(sum(i[1].shape[0] for i in infos)), "ref_density": ref}
	return rep


def relax(objs, bone_names, cfg):
	"""Laplacian smoothing of the positions of the vertices weighted to `bones` (paint.json "smooth": {"bones": [...], "iterations", "factor"}):
	the decimated mesh's lumps and dents (a notch on the forearm that reads as an arrow) go, the limb becomes one round form. A Smooth
	modifier through a vertex group of those bones' summed weights, applied before the subdivision. The weights and UVs are untouched."""
	spec = cfg.get("smooth")
	if not spec:
		return {}
	for o in objs:
		bw = bone_weights(o, bone_names)
		w = np.clip(bw[:, [bone_names.index(b) for b in spec["bones"]]].sum(axis=1), 0.0, 1.0)
		co = pb.verts(o.data)
		tv, _tp = pb.tri_arrays(o.data)
		edges = np.concatenate([tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]], axis=0)
		edges = np.concatenate([edges, edges[:, ::-1]], axis=0)
		count = np.bincount(edges[:, 0], minlength=len(co)).astype(np.float64)
		# the open boundary of a cut mesh is held (a smoothed boundary shrinks away from the mesh it meets)
		key = np.sort(np.concatenate([tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]], axis=0), axis=1)
		_u, inv, cnt = np.unique(key, axis=0, return_inverse=True, return_counts=True)
		boundary = np.zeros(len(co), bool)
		for e in _u[cnt == 1]:
			boundary[e] = True
		hold = np.where(boundary, 0.0, 1.0)
		for _ in range(int(spec.get("iterations", 6))):
			acc = np.zeros_like(co)
			np.add.at(acc, edges[:, 0], co[edges[:, 1]])
			avg = acc / np.maximum(count, 1.0)[:, None]
			co = co + (float(spec.get("factor", 0.5)) * w * hold)[:, None] * (avg - co)
		pb.set_verts(o.data, co)
	return {"iterations": spec.get("iterations", 6)}


def subdivide(objs, cfg):
	"""One level of Catmull-Clark on each mesh (paint.json "subdivide": {"levels": 1}), applied: the first-person arm's polygonal silhouette
	(an 8-sided forearm, a block of a fist) turns round. The weights, the UV1 and the hull-normal colour interpolate with it; the
	open boundary loops (a cut cap) stay where they were (boundary smoothing off). Done before the normals and the unwrap."""
	spec = cfg.get("subdivide")
	if not spec:
		return {}
	out = {}
	for o in objs:
		bpy.context.view_layer.objects.active = o
		before = len(o.data.polygons)
		mod = o.modifiers.new("video_subdivide", "SUBSURF")
		mod.levels = int(spec.get("levels", 1))
		mod.render_levels = mod.levels
		mod.subdivision_type = "CATMULL_CLARK"
		mod.boundary_smooth = "PRESERVE_CORNERS"
		mod.uv_smooth = "PRESERVE_BOUNDARIES"
		mod.use_creases = False
		bpy.ops.object.modifier_apply(modifier=mod.name)
		tri = o.modifiers.new("video_triangulate", "TRIANGULATE")
		tri.quad_method = "BEAUTY"
		bpy.ops.object.modifier_apply(modifier=tri.name)
		out[o.name] = [before, len(o.data.polygons)]
	return out


def smooth_player_normals(objs, cfg):
	"""The Punk's shading-normal recipe (tools/pipeline/blender_export.smooth_shading_normals) with paint.json "normals" for the values."""
	sn = cfg.get("normals", {"iterations": 12, "crease_deg": 50.0, "falloff": 2.0, "self_weight": 1.0})
	return be.smooth_shading_normals(objs, sn)


def main():
	name, workdir, opts = arguments()
	os.makedirs(workdir, exist_ok=True)
	pb.open_blend(os.path.join("assets", "source", "characters", name, "work", name + ".blend"))
	objs = pb.body_objects()
	arm = bpy.data.objects[pb.ARMATURE]
	bone_names = [b.name for b in arm.data.bones]
	meta = {"name": name, "front": FRONT.tolist(), "bones": bone_names, "meshes": [o.name for o in objs],
		"bone_heads": {b.name: [round(float(x), 5) for x in b.head_local] for b in arm.data.bones},
		"bone_tails": {b.name: [round(float(x), 5) for x in b.tail_local] for b in arm.data.bones}}
	cfg = load_config(name)
	meta["smooth"] = relax(objs, bone_names, cfg)
	meta["subdivide"] = subdivide(objs, cfg)
	if name != "player" and not opts["no_normals"]:
		meta["proxy"] = transfer_face_normals(objs[0], bone_names, opts["proxy_strength"])
	if cfg.get("normals") and not opts["no_normals"]:
		meta["normals"] = smooth_player_normals(objs, cfg)
	if not opts["keep_uv2"]:
		meta["layout"] = relayout_uv2(objs, bone_names, cfg, opts["size"])
	meta["uv2_slivers"] = uv2_slivers(objs, opts["size"])
	maps = bake_maps(objs, bone_names, opts["size"])
	np.savez_compressed(os.path.join(workdir, "maps.npz"), **maps)
	hc, hr, _ = head_box(objs[0], bone_names) if "Head" in bone_names and name != "player" else (None, None, None)
	if hc is not None:
		meta["head"] = {"centre": [round(float(x), 4) for x in hc], "radii": [round(float(x), 4) for x in hr]}
	meta["coverage"] = float(maps["cover"].mean())
	with open(os.path.join(workdir, "meta.json"), "w") as f:
		json.dump(meta, f, indent=1)
	if not opts["only_maps"]:
		for m in objs:
			for p in m.data.polygons:
				p.use_smooth = True
		be.export_glb(os.path.join(workdir, name + "_video.glb"), objs, arm)
	print("LD-ASSET %s: coverage %.3f meshes %s" % (name, meta["coverage"], meta["meshes"]))


main()
