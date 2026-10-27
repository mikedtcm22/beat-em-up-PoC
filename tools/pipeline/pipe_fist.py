"""Generated glove fists for the chain's `replace` step (M4 package F-punk, plan Part C section 7 step 4, task T9).

Imported by blender_parts.py (Blender 5.x, headless; never the Blender MCP). `parts.fists.source = "generated"` makes the
hands of the body a Tripo-generated fist instead of the procedural block of blender_parts.fist_geometry. The generated
model is a LEFT fist hanging from its wrist (cuff at the top, knuckles at the bottom, thumb toward the front, back of the
hand toward the character's left) that Tripo delivers facing +X like any character (the same yaw the body uses), with its own
texture. The chain does to it what it does to the body:

	1. import (untrusted data), flatten to world space, turn to face +Y (Blender), weld the importer's split vertices
	   (UVs live on the loops), triangulate;
	2. place: the fist block (below the strap) is fitted to the table's fist box (uniform scale from the block's height, then
	   `extent_fit` of the way to the box's widths), the block's centre to the box centre, its bottom to the box's bottom, so
	   knuckles run along the hand bone and the thumb is toward -Y... toward the front (A5 of the contract);
	3. the cuff above the strap is stretched up so it reaches `cuff_over_m` above the arm's cut and flared so its rim is
	   `cuff_margin_m` wider than the WRIST's radius (the median radius of the cut's boundary, not its 90th percentile and not
	   the source's cuff: the arm must pass through the cuff and never poke out), the block is left as drawn;
	4. the right fist is the left one mirrored in x (winding reversed);
	5. weights: 100% Hand, the cuff ramps to LowerArm (smoothstep from `cuff_below_wrist_m` below the wrist to the cuff's top).
The fist's texture is packed with the body's into one image (`pack_textures`), so the palette step labels both from one
image and the detail mask (A18) is baked from both. Every number is in pipeline.json `parts.fists`; the measured strap levels
of the generation (the fraction of the model's height where the strap's lower and upper edges sit) are config, not code.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402

FIST_ATTR = "pipe_fist"


def smoothstep(t):
	t = np.clip(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def source_image_of(obj):
	for mat in obj.data.materials:
		if mat and mat.use_nodes:
			for n in mat.node_tree.nodes:
				if n.type == "TEX_IMAGE" and n.image is not None:
					return n.image
	return None


class Source:
	"""The generated fist, welded and turned: `co` (n, 3) Blender frame facing +Y, `tris` (m, 3), `uv` (m, 3, 2), `image`."""

	def __init__(self):
		self.co = None
		self.tris = None
		self.uv = None
		self.image = None
		self.report = {}


def load_source(gen):
	"""Import gen["mesh"] (a GLB) and return a Source. The imported objects stay in the scene until discard()."""
	path = pc.repo_path(gen["mesh"])
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path, import_shading="NORMALS", bone_heuristic="BLENDER", disable_bone_shape=True)
	new = [o for o in bpy.data.objects if o not in before]
	meshes = [o for o in new if o.type == "MESH"]
	if not meshes:
		pc.fail("no mesh in " + gen["mesh"])
	obj = meshes[0]
	if len(meshes) > 1:
		pb.activate(obj)
		for o in meshes:
			o.select_set(True)
		bpy.ops.object.join()
		obj = bpy.context.view_layer.objects.active
	src = Source()
	src.image = source_image_of(obj)
	world = obj.matrix_world.copy()
	me = obj.data
	me.transform(world)
	me.transform(Matrix.Rotation(math.radians(float(gen.get("facing_yaw_deg", 90.0))), 4, "Z"))
	me.update()
	bm = bmesh.new()
	bm.from_mesh(me)
	before_v = len(bm.verts)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=float(gen.get("weld_m", 1e-5)))
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.verts.ensure_lookup_table()
	bm.verts.index_update()
	uv_layer = bm.loops.layers.uv.active
	src.co = np.array([tuple(v.co) for v in bm.verts], dtype=np.float64)
	tris, uvs = [], []
	for f in bm.faces:
		tris.append([l.vert.index for l in f.loops])
		uvs.append([tuple(l[uv_layer].uv) for l in f.loops])
	src.tris = np.array(tris, dtype=np.int64)
	src.uv = np.array(uvs, dtype=np.float64)
	bm.free()
	src.report = {"mesh": gen["mesh"], "vertices_imported": before_v, "vertices_welded": len(src.co), "triangles": len(src.tris),
		"image": None if src.image is None else list(src.image.size),
		"height": float(src.co[:, 2].max() - src.co[:, 2].min())}
	src.imported = new
	return src


def discard(src, keep_image=True):
	"""Remove the imported objects (the image stays: pack_textures reads it)."""
	for o in src.imported:
		if o.name in bpy.data.objects:
			data = o.data if o.type == "MESH" else None
			bpy.data.objects.remove(o)
			if data is not None and data.users == 0:
				bpy.data.meshes.remove(data)


def make_side(src, side, box, cut, p_hand, d, gen, pf):
	"""One fist in the world: returns {co, tris, uv, weights (n, 23), report}. `box` is the table's fist box for this side,
	`cut` the arm's cut {a_min, radius_m} (None when there is no open boundary near the hand), p_hand and d the Hand joint and
	the arm direction (Blender frame)."""
	names = pc.bone_names()
	co = src.co.copy()
	tris = src.tris.copy()
	if side == "Right":
		co[:, 0] = -co[:, 0]
		tris = tris[:, ::-1]
	uv = src.uv.copy()
	if side == "Right":
		uv = uv[:, ::-1, :]
	z0, z1 = float(co[:, 2].min()), float(co[:, 2].max())
	height = z1 - z0
	block_top = z0 + float(gen["block_top_frac"]) * height
	strap_top = z0 + float(gen["strap_top_frac"]) * height
	block = co[:, 2] < block_top
	bx0, bx1 = float(co[block, 0].min()), float(co[block, 0].max())
	by0, by1 = float(co[block, 1].min()), float(co[block, 1].max())
	size, off = box["size"], box["center_offset"]  # Godot (x, y, z) -> Blender extents (x, z, y)
	box_x, box_y, box_z = size[0], size[2], size[1]
	centre = np.array([off[0], -off[2], off[1]])
	s = box_z / (block_top - z0)
	fit = float(gen.get("extent_fit", 0.9))
	sx = s * (1.0 - fit) + fit * box_x / max(bx1 - bx0, 1e-6)
	sy = s * (1.0 - fit) + fit * box_y / max(by1 - by0, 1e-6)
	out = np.empty_like(co)
	out[:, 0] = (co[:, 0] - (bx0 + bx1) * 0.5) * sx + centre[0]
	out[:, 1] = (co[:, 1] - (by0 + by1) * 0.5) * sy + centre[1]
	z_bottom = centre[2] - box_z * 0.5
	out[:, 2] = (co[:, 2] - z0) * s + z_bottom
	z_block_top = (block_top - z0) * s + z_bottom
	z_strap_top = (strap_top - z0) * s + z_bottom
	axis_xy = np.array([centre[0], centre[1]])

	# the cuff: reach over the cut, then the rim's radius from the wrist
	over = float(pf.get("cuff_over_m", 0.035))
	margin = float(pf.get("cuff_margin_m", 0.008))
	z_cut = 0.0
	r_wrist = None
	if cut is not None:
		z_cut = -min(float(cut["a_min"]), 0.0)
		r_wrist = float(cut["radius_m"])
	top = float(out[:, 2].max())
	need = z_cut + over
	stretch = 1.0
	if need > top:
		stretch = (need - z_strap_top) / max(top - z_strap_top, 1e-6)
		above = out[:, 2] > z_strap_top
		out[above, 2] = z_strap_top + (out[above, 2] - z_strap_top) * stretch
		top = float(out[:, 2].max())
	flare = 1.0
	# the cuff must be wide enough at the arm's cut: its radius where the arm ends (the generated cuff narrows toward the rim)
	band_m = float(gen.get("rim_band_m", 0.012))
	at_cut = np.abs(out[:, 2] - min(max(z_cut, z_strap_top), top)) < band_m
	if not at_cut.any():
		at_cut = out[:, 2] > top - band_m
	rim_r = float(np.linalg.norm(out[at_cut, :2] - axis_xy, axis=1).mean())
	if r_wrist is not None:
		flare = float(np.clip((r_wrist + margin) / max(rim_r, 1e-6), float(gen.get("flare_min", 0.8)), float(gen.get("flare_max", 1.6))))
	# full flare from `ramp_m` above the block's top (a gauntlet: the strap and the cuff share the flared radius, so the strap
	# stays on the visible outside instead of hiding under a bell that opens above it)
	ramp_top = z_block_top + float(gen.get("ramp_m", 0.012))
	ramp = smoothstep((out[:, 2] - z_block_top) / max(ramp_top - z_block_top, 1e-6))
	k = 1.0 + (flare - 1.0) * ramp
	out[:, :2] = axis_xy + (out[:, :2] - axis_xy) * k[:, None]
	rim_after = float(np.linalg.norm(out[at_cut, :2] - axis_xy, axis=1).mean())

	# weights are computed from the final positions (add_object, after the strap planes cut the mesh): Hand below the wrist band,
	# ramping to LowerArm up the cuff
	zb = -float(pf.get("cuff_below_wrist_m", 0.012))
	wparams = {"side": side, "top": top, "zb": zb}

	R = _rotation_between(np.array(pc.HANGING), d)
	world = (out @ R.T) + p_hand
	report = {"scale": s, "scale_x": sx, "scale_y": sy, "block_extent_m": [float((bx1 - bx0) * sx), float((by1 - by0) * sy), float(box_z)],
		"cuff_top_m": top, "cuff_stretch": stretch, "cuff_flare": flare, "rim_radius_m": rim_after, "wrist_radius_m": r_wrist,
		"z_cut_m": z_cut, "strap_top_m": z_strap_top, "block_top_m": z_block_top, "triangles": int(len(tris))}
	# the strap's two planes (the block's top and the strap's top) in the world, normal along the arm
	axis = -np.asarray(d, dtype=np.float64)  # the hanging frame's +z in the world
	planes = [(p_hand + axis * z_block_top, axis), (p_hand + axis * z_strap_top, axis)]
	wparams.update({"p_hand": p_hand, "d": np.asarray(d, dtype=np.float64)})
	return {"co": world, "tris": tris, "uv": uv, "wparams": wparams, "report": report, "bisect": planes if gen.get("bisect_strap", True) else None}


def _rotation_between(a, b):
	from blender_fit import rotation_between
	return rotation_between(a, b)


def fist_weights(co_world, wp):
	"""(n, 23) weights of the fist's vertices: the hanging-frame height of each decides (smoothstep from the wrist band up)."""
	names = pc.bone_names()
	z = -((co_world - wp["p_hand"]) @ wp["d"])  # the hanging frame's +z, up the arm
	t = smoothstep((wp["top"] - z) / max(wp["top"] - wp["zb"], 1e-6))
	w = np.zeros((len(co_world), len(names)))
	w[:, names.index(wp["side"] + "Hand")] = t
	w[:, names.index(wp["side"] + "LowerArm")] = 1.0 - t
	return w


def add_object(name, part, image_name_uv_layer):
	"""A mesh object from make_side()'s dict with its UV layer (named like the body's), the pipe_fist attribute set and the
	weights written."""
	names = pc.bone_names()
	obj = pb.new_mesh_object(name, part["co"], [tuple(int(i) for i in f) for f in part["tris"]])
	me = obj.data
	layer = me.uv_layers.new(name=image_name_uv_layer)
	flat = part["uv"].reshape(-1, 2).astype(np.float32)
	layer.data.foreach_set("uv", flat.ravel())
	if part.get("bisect"):
		# cut along the strap's two planes (perpendicular to the arm): the strap's colour borders run along edge loops and
		# survive the decimation as clean rings instead of a zigzag
		bm = bmesh.new()
		bm.from_mesh(me)
		for plane_co, plane_no in part["bisect"]:
			geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
			bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=tuple(plane_co), plane_no=tuple(plane_no))
		bm.to_mesh(me)
		bm.free()
		me.update()
		part_faces = len(me.polygons)
		uv_after = len(me.uv_layers)
	a = me.attributes.new(FIST_ATTR, "INT", "FACE")
	a.data.foreach_set("value", np.ones(len(me.polygons), dtype=np.int32))
	pb.write_weights(obj, names, fist_weights(pb.verts(me), part["wparams"]))
	for p in me.polygons:
		p.use_smooth = True
	return obj


def pack_textures(body, fist_image, gen):
	"""One image for both: the body's (2048 x 2048 as delivered) below, the fist's above, one atlas twice as tall. Every
	loop's v is remapped (body v / 2, fist 0.5 + v / 2), the body's material points at it, and it is packed into the
	.blend. Returns the new image. Runs after the fists are joined into `body` (the FIST_ATTR face attribute says which)."""
	me = body.data
	body_image = source_image_of(body)
	if body_image is None or fist_image is None:
		pc.fail("pack_textures: both the body and the fist need a texture")
	bw, bh = body_image.size
	fw, fh = fist_image.size
	width = max(bw, fw)
	pix_b = np.empty(bw * bh * 4, dtype=np.float32)
	body_image.pixels.foreach_get(pix_b)
	pix_b = pix_b.reshape(bh, bw, 4)
	pix_f = np.empty(fw * fh * 4, dtype=np.float32)
	fist_image.pixels.foreach_get(pix_f)
	pix_f = pix_f.reshape(fh, fw, 4)
	total_h = bh + fh
	atlas = np.ones((total_h, width, 4), dtype=np.float32)
	atlas[:bh, :bw] = pix_b  # row 0 is the bottom in Blender's pixel order: the body below
	atlas[bh:, :fw] = pix_f
	img = bpy.data.images.new("fist_body_atlas", width, total_h, alpha=False)
	img.colorspace_settings.name = "sRGB"
	img.pixels.foreach_set(atlas.ravel())
	img.update()
	img.pack()
	# v remap
	layer = me.uv_layers[0]
	uv = np.empty(len(me.loops) * 2, dtype=np.float32)
	layer.data.foreach_get("uv", uv)
	uv = uv.reshape(-1, 2)
	start, total, lv = pb.poly_arrays(me)
	fist = np.zeros(len(start), dtype=np.int32)
	me.attributes[FIST_ATTR].data.foreach_get("value", fist)
	owner = np.repeat(np.arange(len(start)), total)
	is_fist = fist[owner] > 0
	# u scaled when the images differ in width (they do not today); v into its half
	uv[~is_fist, 0] *= bw / width
	uv[is_fist, 0] *= fw / width
	uv[~is_fist, 1] = uv[~is_fist, 1] * (bh / total_h)
	uv[is_fist, 1] = (bh + uv[is_fist, 1] * fh) / total_h
	layer.data.foreach_set("uv", uv.ravel())
	for mat in me.materials:
		if mat and mat.use_nodes:
			for n in mat.node_tree.nodes:
				if n.type == "TEX_IMAGE":
					n.image = img
	if body_image.users == 0 or True:
		pass
	return {"atlas": [width, total_h], "body_image": [bw, bh], "fist_image": [fw, fh]}


def taper_wrist(co, w, side, p_hand, d, r_now, pf):
	"""Pull the forearm's vertices toward the arm's axis so its radius at the wrist is pf["wrist_radius_m"] and the arm is
	back to its own radius `wrist_taper_m` above the wrist (smoothstep). `co` (n, 3) is returned moved; w the weights
	(n, 23); r_now the median radius of the cut. Only vertices that are mostly LowerArm or Hand and within 0.2 m of the axis move."""
	names = pc.bone_names()
	arm = w[:, names.index(side + "LowerArm")] + w[:, names.index(side + "Hand")] > 0.5
	rel = co - p_hand
	along = rel @ d  # negative above the wrist (toward the elbow)
	radial_vec = rel - np.outer(along, d)
	radial = np.linalg.norm(radial_vec, axis=1)
	length = float(pf.get("wrist_taper_m", 0.14))
	k = float(pf["wrist_radius_m"]) / max(r_now, 1e-6)
	u = np.clip(-along / max(length, 1e-6), 0.0, 1.0)
	weight = 1.0 - smoothstep(u)
	sel = arm & (radial < 0.2) & (along < 0.05) & (along > -length)
	scale = np.ones(len(co))
	scale[sel] = 1.0 - (1.0 - k) * weight[sel]
	out = co.copy()
	out[sel] = p_hand + np.outer(along[sel], d) + radial_vec[sel] * scale[sel][:, None]
	return out, {"vertices": int(sel.sum()), "scale_at_wrist": k, "length_m": length, "radius_before_m": r_now, "radius_after_m": float(pf["wrist_radius_m"])}
