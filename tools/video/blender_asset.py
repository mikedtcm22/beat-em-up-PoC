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

Options: --size N (map size, default 2048), --no-normals (export the mesh as it is), --proxy-strength S (0..1, default 0.85),
--only-maps (skip the export). Video only: the game's files are never written. Never the Blender MCP.
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
	opts = {"size": 2048, "no_normals": False, "proxy_strength": 0.85, "only_maps": False}
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
	if name != "player" and not opts["no_normals"]:
		meta["proxy"] = transfer_face_normals(objs[0], bone_names, opts["proxy_strength"])
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
