"""Blender-side helpers of the art pipeline (M4 package P1-chain). Imported by the blender_*.py steps, which run as
	blender --background --factory-startup --python tools/pipeline/blender_<step>.py -- <pipeline.json> [step args]
Never the Blender MCP; one Blender process at a time.

Everything is in the Blender frame (see pipe_common.py): +Z up, the character faces +Y, own right is +X.
Meshes are read and written through numpy (foreach_get / foreach_set), so a step stays fast on a 25k-triangle body.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_common as pc  # noqa: E402

BODY = "Body"
BODY_HIDDEN = "Body__fp_hidden"
BODY_TORSO = "Body__fp_torso"
BODY_ARM = "Body__fp_arm"
# point attributes a part can carry to bend its inverted-hull outline direction (blender_export.write_hull_normals): a weight 0..1 and a
# unit direction (Blender axes); the hull normal of a vertex turns from the smooth normal toward the direction by the weight. M6 ARM:
# the near upper arm's loop on the elbow side turns along the arm, so its hull stays inside the arm and draws no ink line over the forearm
HULL_W_ATTR = "pipe_hull_w"
HULL_DIR_ATTR = "pipe_hull_dir"
ARMATURE = "Armature"
PREVIEW_COLLECTION = "Preview"


# --------------------------------------------------------------------------- scene and files

def reset_scene():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def open_blend(path):
	bpy.ops.wm.open_mainfile(filepath=path)


def save_blend(path):
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path, compress=False)


def link(obj, collection=None):
	(collection or bpy.context.scene.collection).objects.link(obj)
	return obj


def activate(obj, only=True):
	"""Make obj the active, selected object (and the only selected one when only)."""
	if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	if only:
		bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	return obj


def scene_prop(name, default=None):
	"""A JSON value kept on the scene between steps (the .blend carries it)."""
	import json
	raw = bpy.context.scene.get(name)
	return json.loads(raw) if raw else default


def set_scene_prop(name, value):
	import json
	bpy.context.scene[name] = json.dumps(pc.rnd(value, 7))


def body_objects():
	"""The character's mesh objects, Body first, then the first-person hidden upper body, the torso (the belly and belt, which
	fp_knockdown_hide_torso hides) and the shoulder half of each upper arm (which fp_show_upper_arm shows) when they exist."""
	out = [bpy.data.objects[n] for n in (BODY, BODY_HIDDEN, BODY_TORSO, BODY_ARM) if n in bpy.data.objects]
	return out


# --------------------------------------------------------------------------- mesh <-> numpy

def verts(me):
	a = np.empty(len(me.vertices) * 3, dtype=np.float32)
	me.vertices.foreach_get("co", a)
	return a.reshape(-1, 3).astype(np.float64)


def set_verts(me, a):
	me.vertices.foreach_set("co", np.asarray(a, dtype=np.float32).ravel())
	me.update()


def poly_arrays(me):
	"""(loop_start, loop_total, loop_vertex_index) as int arrays."""
	n = len(me.polygons)
	start = np.empty(n, dtype=np.int32)
	total = np.empty(n, dtype=np.int32)
	me.polygons.foreach_get("loop_start", start)
	me.polygons.foreach_get("loop_total", total)
	lv = np.empty(len(me.loops), dtype=np.int32)
	me.loops.foreach_get("vertex_index", lv)
	return start, total, lv


def tri_arrays(me):
	"""(triangle vertex indices (nt, 3), polygon index per triangle (nt,))."""
	me.calc_loop_triangles()
	nt = len(me.loop_triangles)
	tv = np.empty(nt * 3, dtype=np.int32)
	tp = np.empty(nt, dtype=np.int32)
	me.loop_triangles.foreach_get("vertices", tv)
	me.loop_triangles.foreach_get("polygon_index", tp)
	return tv.reshape(-1, 3), tp


def face_centers(me):
	co = verts(me)
	start, total, lv = poly_arrays(me)
	out = np.zeros((len(start), 3))
	for k in range(int(total.max()) if len(total) else 0):
		mask = total > k
		out[mask] += co[lv[start[mask] + k]]
	return out / np.maximum(total, 1)[:, None]


def face_areas(me):
	co = verts(me)
	tv, tp = tri_arrays(me)
	a, b, c = co[tv[:, 0]], co[tv[:, 1]], co[tv[:, 2]]
	tri_area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
	out = np.zeros(len(me.polygons))
	np.add.at(out, tp, tri_area)
	return out


def triangle_count(me):
	me.calc_loop_triangles()
	return len(me.loop_triangles)


def new_mesh_object(name, co, faces, collection=None):
	"""A mesh object from numpy vertices and a list of vertex-index tuples."""
	me = bpy.data.meshes.new(name)
	me.from_pydata([tuple(v) for v in co], [], [tuple(int(i) for i in f) for f in faces])
	me.update()
	obj = bpy.data.objects.new(name, me)
	link(obj, collection)
	return obj


# --------------------------------------------------------------------------- vertex weights

def weights_matrix(obj, names):
	"""(n_vertices, len(names)) weights of the named vertex groups (0 where absent)."""
	me = obj.data
	col = {}
	for c, name in enumerate(names):
		vg = obj.vertex_groups.get(name)
		if vg is not None:
			col[vg.index] = c
	w = np.zeros((len(me.vertices), len(names)))
	for v in me.vertices:
		for g in v.groups:
			c = col.get(g.group)
			if c is not None:
				w[v.index, c] = g.weight
	return w


def write_weights(obj, names, w, eps=1e-5, remove_others=False):
	"""Replace obj's vertex groups named in `names` by the columns of w (created in `names` order)."""
	if remove_others:
		for vg in list(obj.vertex_groups):
			obj.vertex_groups.remove(vg)
	for name in names:
		vg = obj.vertex_groups.get(name)
		if vg is not None:
			obj.vertex_groups.remove(vg)
	groups = [obj.vertex_groups.new(name=n) for n in names]
	for c, vg in enumerate(groups):
		for i in np.nonzero(w[:, c] > eps)[0]:
			vg.add([int(i)], float(w[i, c]), "REPLACE")


def limit_and_normalize(w, limit=4):
	"""Keep the `limit` largest weights per vertex and normalise the row to 1 (rows that are all zero stay zero)."""
	w = np.array(w, dtype=np.float64)
	if w.shape[1] > limit:
		order = np.argsort(-w, axis=1, kind="stable")
		drop = order[:, limit:]
		rows = np.arange(w.shape[0])[:, None]
		w[rows, drop] = 0.0
	s = w.sum(axis=1, keepdims=True)
	return np.where(s > 1e-9, w / np.maximum(s, 1e-12), 0.0)


def fill_unweighted(co, w, min_sum=1e-4):
	"""Give each vertex with no weight the weights of the nearest weighted vertex (KDTree). Returns (w, count filled)."""
	have = w.sum(axis=1) > min_sum
	if have.all():
		return w, 0
	kd = kdtree.KDTree(int(have.sum()))
	src = np.nonzero(have)[0]
	for k, i in enumerate(src):
		kd.insert(Vector(co[i]), k)
	kd.balance()
	out = w.copy()
	for i in np.nonzero(~have)[0]:
		_, k, _ = kd.find(Vector(co[i]))
		out[i] = w[src[k]]
	return out, int((~have).sum())


def smooth_weights(me, w, iterations, factor):
	"""Laplacian smoothing of a weight matrix over the mesh's edges: w <- (1 - f) w + f * mean(neighbour w), `iterations` times."""
	ev = np.empty(len(me.edges) * 2, dtype=np.int32)
	me.edges.foreach_get("vertices", ev)
	a, b = ev[0::2], ev[1::2]
	deg = np.zeros(len(w))
	np.add.at(deg, a, 1.0)
	np.add.at(deg, b, 1.0)
	out = np.array(w, dtype=np.float64)
	for _ in range(iterations):
		acc = np.zeros_like(out)
		np.add.at(acc, a, out[b])
		np.add.at(acc, b, out[a])
		mean = acc / np.maximum(deg, 1.0)[:, None]
		out = np.where(deg[:, None] > 0, (1.0 - factor) * out + factor * mean, out)
	return out


# --------------------------------------------------------------------------- armature

def make_armature(name, segs, order, parents, deform=True, collection=None):
	"""An armature object whose bones run segs[bone] = (head, tail) (Blender frame, object at the origin)."""
	arm = bpy.data.armatures.new(name)
	obj = bpy.data.objects.new(name, arm)
	link(obj, collection)
	activate(obj)
	bpy.ops.object.mode_set(mode="EDIT")
	made = {}
	for n in order:
		head, tail = segs[n]
		if (Vector(tail) - Vector(head)).length < 1e-4:
			tail = (head[0], head[1], head[2] + 0.01)
		eb = arm.edit_bones.new(n)
		eb.head = Vector(head)
		eb.tail = Vector(tail)
		eb.roll = 0.0
		eb.use_deform = deform
		made[n] = eb
	for n in order:
		p = parents.get(n)
		if p and p in made:
			made[n].parent = made[p]
			made[n].use_connect = False
	bpy.ops.object.mode_set(mode="OBJECT")
	return obj


def attach_armature(mesh_obj, arm_obj):
	"""Parent mesh_obj to arm_obj with an Armature modifier and no automatic weights."""
	for m in [m for m in mesh_obj.modifiers if m.type == "ARMATURE"]:
		mesh_obj.modifiers.remove(m)
	mesh_obj.parent = arm_obj
	mesh_obj.matrix_parent_inverse = Matrix.Identity(4)
	mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
	mod.object = arm_obj


def auto_weights(mesh_obj, arm_obj, skip=("Root",)):
	"""Blender's heat-map weights from arm_obj (bones in `skip` do not deform while it runs). Creates one vertex group per
	remaining bone; the caller renames or removes them. Returns the names created."""
	for n in skip:
		if n in arm_obj.data.bones:
			arm_obj.data.bones[n].use_deform = False
	activate(mesh_obj)
	arm_obj.select_set(True)
	bpy.context.view_layer.objects.active = arm_obj
	bpy.ops.object.parent_set(type="ARMATURE_AUTO")
	for n in skip:
		if n in arm_obj.data.bones:
			arm_obj.data.bones[n].use_deform = True
	return [b.name for b in arm_obj.data.bones if b.name not in skip]


# --------------------------------------------------------------------------- normals

def smooth_vertex_normals(co, tris, keep=None, digits=5):
	"""Position-averaged vertex normals. co: list of (n, 3) coordinate arrays (one per mesh), tris: list of (nt, 3) triangle
	index arrays, keep: optional list of per-triangle boolean masks of the triangles allowed to contribute. Every vertex at
	one position (a UV or normal split, a cut between two meshes) gets the same unit normal: the area-weighted mean of the
	kept faces around that position; a position no kept face touches (a cap's inner ring) falls back to all faces."""
	kept, every = {}, {}
	keys = []
	for m, (c, tri) in enumerate(zip(co, tris)):
		a, b, d = c[tri[:, 0]], c[tri[:, 1]], c[tri[:, 2]]
		fn = np.cross(b - a, d - a)  # length = 2 * area: the area weight
		q = np.round(c * (10 ** digits)).astype(np.int64)
		keys.append([(int(r[0]), int(r[1]), int(r[2])) for r in q])
		for tag, weights in (("all", fn), ("kept", fn * (keep[m][:, None] if keep is not None else 1.0))):
			vn = np.zeros_like(c)
			for k in range(3):
				np.add.at(vn, tri[:, k], weights)
			dst = every if tag == "all" else kept
			for i, key in enumerate(keys[-1]):
				dst[key] = dst.get(key, 0.0) + vn[i]
	out = []
	for c, ks in zip(co, keys):
		n = np.zeros_like(c)
		for i, key in enumerate(ks):
			v = kept.get(key, 0.0)
			if np.linalg.norm(v) < 1e-12:
				v = every.get(key, 0.0)
			ln = np.linalg.norm(v)
			n[i] = v / ln if ln > 1e-12 else (0.0, 0.0, 1.0)
		out.append(n)
	return out


# --------------------------------------------------------------------------- previews (Workbench stills)

def preview_materials(slots, swatch_table):
	"""{slot: Material} with the swatch colour as the viewport colour (Workbench 'Material' colouring)."""
	out = {}
	for s in sorted(slots):
		rgba = swatch_table.get(s, {"rgba": (255, 0, 255, 255)})["rgba"]
		mat = bpy.data.materials.new("pv_%d" % s)
		lin = [((c / 255.0) / 12.92 if c / 255.0 <= 0.04045 else ((c / 255.0 + 0.055) / 1.055) ** 2.4) for c in rgba[:3]]
		mat.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
		out[s] = mat
	return out


def setup_preview_scene(res=(480, 640)):
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.render.resolution_x, scene.render.resolution_y = res
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.film_transparent = False
	sh = scene.display.shading
	sh.light = "STUDIO"
	sh.color_type = "MATERIAL"
	sh.show_cavity = False
	sh.show_object_outline = True
	sh.object_outline_color = (0.07, 0.06, 0.09)
	sh.show_shadows = False
	if scene.world is None:
		scene.world = bpy.data.worlds.new("PreviewWorld")
	scene.world.color = (0.30, 0.31, 0.34)
	scene.display.render_aa = "8"
	scene.view_settings.view_transform = "Standard"
	return scene


def render_view(path, eye, target, ortho_scale=2.2, res=(480, 640)):
	"""One orthographic Workbench still of everything visible in the scene."""
	scene = setup_preview_scene(res)
	cam_data = bpy.data.cameras.new("PreviewCam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = ortho_scale
	cam = bpy.data.objects.new("PreviewCam", cam_data)
	link(cam)
	cam.location = Vector(eye)
	direction = Vector(target) - Vector(eye)
	cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	scene.camera = cam
	scene.render.filepath = path
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	bpy.ops.render.render(write_still=True)
	bpy.data.objects.remove(cam)
	bpy.data.cameras.remove(cam_data)
	return path


STANDARD_VIEWS = {
	"front": ((0.0, 6.0, 0.9), (0.0, 0.0, 0.9)),  # the character faces +Y, so the front camera sits at +Y looking back
	"side": ((6.0, 0.0, 0.9), (0.0, 0.0, 0.9)),
	"three_quarter": ((4.2, 4.2, 1.2), (0.0, 0.0, 0.9)),
	"back": ((0.0, -6.0, 0.9), (0.0, 0.0, 0.9)),
}


# --------------------------------------------------------------------------- step bootstrap

def run_step(step, fn):
	"""Run fn(cfg, extra_args) -> report dict for the step `step`: argv after `--` is <pipeline.json> [extra...]. Writes the
	report to <work>/<step>.report.json and exits 0; an exception prints a traceback and exits 1 (run.py stops there)."""
	import traceback
	argv = pc.step_argv()
	try:
		cfg = pc.load_config(argv[0])
		report = fn(cfg, argv[1:])
		pc.write_json(report, pc.step_report_path(cfg, step if not argv[1:] else step + "_" + "_".join(argv[1:])))
		print("STEP %s ok" % step)
	except SystemExit:
		raise
	except Exception:
		traceback.print_exc()
		sys.exit(1)
