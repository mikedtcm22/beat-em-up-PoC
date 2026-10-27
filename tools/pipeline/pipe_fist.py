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

F-punk-fix: with `parts.fists.generated.collar` the generated cuff and strap (everything above the strap's lower plane, torn
flaps and a ragged rim) are thrown away and a clean COLLAR is built in their place (`build_collar`): a surface of revolution
that starts at the block's top loop, funnels out to the arm's own outline plus a margin, carries a low ridge where the strap
was, runs up to a rolled rim `cuff_over_m` above the arm's cut and closes inward, inside the arm. The collar is one colour (the
glove's: the palette step labels its faces from the `pipe_collar` attribute) and takes no ink; the strap is no longer a colour.
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
BAND_ATTR = "pipe_band"  # 1 on the fist faces between the strap's two planes
COLLAR_ATTR = "pipe_collar"  # 1 on the faces of the clean collar (F-punk-fix): the glove's colour, no ink


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
	collar = gen.get("collar")
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
	if collar:
		# the generated cuff is thrown away by add_object: only the levels matter; the rim stands `length_m` above the block's top
		# (the same on both sides: the arm's cut is a ragged loop and its highest point differs from one hand to the other)
		top = z_block_top + float(collar["length_m"])
	elif need > top:
		stretch = (need - z_strap_top) / max(top - z_strap_top, 1e-6)
		above = out[:, 2] > z_strap_top
		out[above, 2] = z_strap_top + (out[above, 2] - z_strap_top) * stretch
		top = float(out[:, 2].max())
	flare = 1.0
	rim_after = 0.0
	clamp = float(gen.get("ring_clamp_m", 0.0))
	clamped = 0
	if not collar:
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

	# no spikes on the cuff: above the block each ring of the mesh (vertices within one bin of the same height) may stand at most
	# ring_clamp_m beyond that ring's median radius, so the strap's buckle and the cuff's torn rim cannot become slivers
	if clamp > 0.0 and not collar:
		bin_m = float(gen.get("ring_bin_m", 0.003))
		upper = out[:, 2] > z_block_top
		rel = out[:, :2] - axis_xy
		radius = np.linalg.norm(rel, axis=1)
		bins = np.floor((out[:, 2] - z_block_top) / bin_m).astype(np.int64)
		for b in np.unique(bins[upper]):
			sel = upper & (bins == b)
			if sel.sum() < 6:
				continue
			limit = float(np.median(radius[sel])) + clamp
			over = sel & (radius > limit)
			if over.any():
				out[over, :2] = axis_xy + rel[over] / radius[over][:, None] * limit
				clamped += int(over.sum())

	# weights are computed from the final positions (add_object, after the strap planes cut the mesh): Hand below the wrist band,
	# ramping to LowerArm up the cuff
	zb = -float(pf.get("cuff_below_wrist_m", 0.012))
	wparams = {"side": side, "top": top, "zb": zb, "block_top": z_block_top, "cuff_hand": float(gen.get("cuff_hand_weight", 0.85))}

	R = _rotation_between(np.array(pc.HANGING), d)
	world = (out @ R.T) + p_hand
	report = {"scale": s, "scale_x": sx, "scale_y": sy, "block_extent_m": [float((bx1 - bx0) * sx), float((by1 - by0) * sy), float(box_z)],
		"cuff_top_m": top, "cuff_stretch": stretch, "cuff_flare": flare, "rim_radius_m": rim_after, "wrist_radius_m": r_wrist,
		"z_cut_m": z_cut, "strap_top_m": z_strap_top, "block_top_m": z_block_top, "triangles": int(len(tris)), "ring_clamped_vertices": clamped}
	# the strap's two planes (the block's top and the strap's top) in the world, normal along the arm
	axis = -np.asarray(d, dtype=np.float64)  # the hanging frame's +z in the world
	planes = [(p_hand + axis * z_block_top, axis), (p_hand + axis * z_strap_top, axis)]
	wparams.update({"p_hand": p_hand, "d": np.asarray(d, dtype=np.float64)})
	collar_info = None
	if collar:
		collar_info = {"cfg": collar, "R": R, "p_hand": np.asarray(p_hand, dtype=np.float64), "z_block_top": z_block_top, "top": top, "z_cut": z_cut,
			"arm_tris": None if cut is None else cut.get("arm_tris")}
	return {"co": world, "tris": tris, "uv": uv, "wparams": wparams, "report": report, "bisect": planes if gen.get("bisect_strap", True) else None,
		"collar": collar_info}


def _rotation_between(a, b):
	from blender_fit import rotation_between
	return rotation_between(a, b)


def fist_weights(co_world, wp):
	"""(n, 23) weights of the fist's vertices: the hanging-frame height of each decides (smoothstep from the wrist band up)."""
	names = pc.bone_names()
	z = -((co_world - wp["p_hand"]) @ wp["d"])  # the hanging frame's +z, up the arm
	# the block (below the strap) is all Hand; the cuff above it ramps from `cuff_hand` (under the 0.9 the contract's fist
	# extents count) down to the LowerArm's at the cuff's top
	t = np.where(z <= wp["block_top"], 1.0,
			wp["cuff_hand"] * (1.0 - smoothstep((z - wp["block_top"]) / max(wp["top"] - wp["block_top"], 1e-6))))
	w = np.zeros((len(co_world), len(names)))
	w[:, names.index(wp["side"] + "Hand")] = t
	w[:, names.index(wp["side"] + "LowerArm")] = 1.0 - t
	return w


def arm_section(tris, z, bins, harmonics=0):
	"""The arm's cross-section at height `z` (the hanging frame, z up the arm) as an outline about the frame's axis: the arm's
	triangles `tris` (m, 3, 3) are sliced by the plane, the slice's points binned by angle (`bins` bins, the largest radius in each,
	empty bins interpolated around the circle). With `harmonics` above 0 the outline is smoothed to that many Fourier harmonics
	and then lifted by the largest shortfall, so it is a smooth oval that is nowhere inside the slice (the cuff follows the
	forearm's own outline and the skin never shows through it, F-cuff). Returns (theta bin centres, radius (bins,))."""
	segs = _chords(tris, z)
	if not len(segs):
		pc.fail("collar: the arm has no surface at z %.4f" % z)
	# sample each chord so a long facet fills its bins, not only its two ends
	frac = np.linspace(0.0, 1.0, 8)
	pts = (segs[:, 0:1, :] * (1.0 - frac)[None, :, None] + segs[:, 1:2, :] * frac[None, :, None]).reshape(-1, 2)
	ang = np.arctan2(pts[:, 1], pts[:, 0])
	rad = np.hypot(pts[:, 0], pts[:, 1])
	idx = np.clip(((ang + math.pi) / (2.0 * math.pi) * bins).astype(np.int64), 0, bins - 1)
	r = np.zeros(bins)
	np.maximum.at(r, idx, rad)
	have = np.nonzero(r > 0.0)[0]
	r = np.interp(np.arange(bins), have, r[have], period=bins)
	theta = (np.arange(bins) + 0.5) * (2.0 * math.pi / bins) - math.pi
	if harmonics > 0:
		r = np.maximum(r, np.maximum(np.roll(r, 1), np.roll(r, -1)))  # one bin of dilation: the smooth oval then needs a small lift
		spec = np.fft.rfft(r)
		spec[harmonics + 1:] = 0.0
		smooth = np.fft.irfft(spec, n=bins)
		r = smooth + max(0.0, float((r - smooth).max()))
	return theta, r


def _chords(t, z):
	"""The two points where each triangle of `t` (m, 3, 3) crosses the plane z (m, 2, 2), the xy of its slice."""
	out = np.zeros((len(t), 2, 2))
	count = np.zeros(len(t), dtype=np.int64)
	for i, j in ((0, 1), (1, 2), (2, 0)):
		za, zb = t[:, i, 2], t[:, j, 2]
		hit = ((za <= z) & (zb > z)) | ((zb <= z) & (za > z))
		u = np.where(hit, (z - za) / np.where(zb != za, zb - za, 1.0), 0.0)
		p = t[:, i, :2] + (t[:, j, :2] - t[:, i, :2]) * u[:, None]
		for slot in (0, 1):
			take = hit & (count == slot)
			out[take, slot] = p[take]
		count += hit.astype(np.int64)
	return out[count == 2]


def build_collar(me, part, uv_name):
	"""Replace the generated cuff and strap by the clean collar (module doc). `me` is the fist's mesh in the WORLD, already cut
	along the strap's lower plane; returns a report dict. The faces above the plane are deleted, the loop the cut leaves on the
	block is the collar's first ring, and rings of the same vertex count are lofted from it to the rim."""
	info = part["collar"]
	cfg = info["cfg"]
	R, p = info["R"], info["p_hand"]
	z_bt, top, z_cut = info["z_block_top"], info["top"], info["z_cut"]
	arm = info["arm_tris"]
	if arm is None:
		pc.fail("collar: no arm surface to take the outline from")
	bm = bmesh.new()
	bm.from_mesh(me)
	uv_layer = bm.loops.layers.uv.get(uv_name) or bm.loops.layers.uv.active
	layer_c = bm.faces.layers.int.new(COLLAR_ATTR)  # before any face reference is taken: a new layer reallocates the face data
	# the cut at the block's top, exactly: bisect, then drop every face above the plane
	axis_w = R @ np.array([0.0, 0.0, 1.0])
	plane_co = tuple(p + axis_w * z_bt)
	geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
	bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=plane_co, plane_no=tuple(axis_w))
	bm.faces.ensure_lookup_table()
	above = [f for f in bm.faces if float((np.array(f.calc_center_median()) - np.array(plane_co)) @ axis_w) > 1e-6]
	bmesh.ops.delete(bm, geom=above, context="FACES")
	loose = [v for v in bm.verts if not v.link_faces]
	if loose:
		bmesh.ops.delete(bm, geom=loose, context="VERTS")
	bm.verts.ensure_lookup_table()
	bm.edges.ensure_lookup_table()
	boundary = [e for e in bm.edges if len(e.link_faces) == 1]
	if not boundary:
		pc.fail("collar: the cut left no open loop on the block")
	# order the loop into one cycle, each edge in its face's direction (start -> end)
	nxt = {}
	for e in boundary:
		lp = e.link_loops[0]
		a, b = lp.vert, lp.link_loop_next.vert
		if a in nxt:
			pc.fail("collar: the block's top is not a single simple loop")
		nxt[a] = (b, lp)
	start_v = next(iter(nxt))
	cycle = [start_v]
	v = nxt[start_v][0]
	while v != start_v:
		cycle.append(v)
		if v not in nxt:
			pc.fail("collar: the block's top loop is not closed")
		v = nxt[v][0]
	if len(cycle) != len(nxt):
		pc.fail("collar: the cut left %d loop edges but one cycle of %d" % (len(nxt), len(cycle)))
	loop_uv = []
	for a in cycle:
		loop_uv.append(tuple(nxt[a][1][uv_layer].uv))
	n = len(cycle)
	local = (np.array([tuple(a.co) for a in cycle]) - p) @ R  # (n, 3) in the hanging frame
	c_loop = local[:, :2].mean(axis=0)
	rel = local[:, :2] - c_loop
	theta = np.arctan2(rel[:, 1], rel[:, 0])
	rho0 = np.hypot(rel[:, 0], rel[:, 1])
	# the arm's outline: the slice of its surface at each ring's height (a ring below the trimmed end reads the outline at the end)
	bins = int(cfg.get("outline_bins", 48))
	harmonics = int(cfg.get("outline_harmonics", 4))
	margin = float(cfg.get("margin_m", 0.004))
	inner_in = float(cfg.get("inner_inset_m", 0.003))
	rows = []  # (z, blend, extra radius in m) from the block's top up the rim
	for dz, blend, extra in cfg["rings"]:
		rows.append((z_bt + float(dz), float(blend), float(extra)))
	for dz, extra in cfg.get("rim", []):  # the rolled rim: heights below the top, each a little wider than the band
		rows.append((top + float(dz), 1.0, float(extra)))
	for a, b in zip(rows[:-1], rows[1:]):
		if b[0] <= a[0]:
			pc.fail("collar: the rings must climb (z %.4f then %.4f); the rim's heights are below the top %.4f" % (a[0], b[0], top))
	# no gap between two rings above `ring_step_m`: the forearm's own bumps would show through a long straight run between them
	step = float(cfg.get("ring_step_m", 0.006))
	filled = [rows[0]]
	for a, b in zip(rows[:-1], rows[1:]):
		parts = int(math.ceil((b[0] - a[0]) / step - 1e-9))
		for q in range(1, parts):
			f = q / parts
			filled.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f))
		filled.append(b)
	rows = filled
	rows.append((top, 1.0, None))  # the inner lip, inside the arm
	full = [r[0] for r in rows if r[1] >= 1.0 and r[2] is not None]
	z_full = min(full) if full else top
	# the outline is read no lower than the arm's trimmed end (the ragged loop under it is gone), nor lower than the cut plus a floor
	z_floor = z_bt + float(cfg["arm_trim_above_block_m"])  # the arm's trimmed end: the lowest level its surface is there
	ring_vertices = [cycle]
	ring_z = []
	ring_centre = []
	ring_rho = []
	for z, blend, extra in rows:
		zs = max(z, z_floor)
		th_o, r_o = arm_section(arm, zs + float(cfg.get("outline_above_m", 0.0005)), bins, harmonics)
		a_theta = np.interp(theta, th_o, r_o, period=2.0 * math.pi)
		centre = c_loop * (1.0 - blend) if blend < 1.0 else np.zeros(2)  # the arm's axis is the hanging frame's origin
		bl = float(smoothstep(blend))
		if extra is None:
			target = a_theta - inner_in
		else:
			target = a_theta + margin + extra
		rho = rho0 * (1.0 - bl) + target * bl
		pos = np.stack([centre[0] + rho * np.cos(theta), centre[1] + rho * np.sin(theta), np.full(n, z)], axis=1)
		world = pos @ R.T + p
		ring = [bm.verts.new(tuple(w)) for w in world]
		ring_vertices.append(ring)
		ring_z.append(z)
		ring_centre.append(centre.copy())
		ring_rho.append(rho)
	# the arm's skin must stay inside the collar from the level where the funnel reaches the outline up to the rim: the smallest gap
	# (the collar's radius minus the arm's slice, at heights between the rings) in metres, and where it is
	zr = np.array(ring_z)
	clearance = None
	clearance_at = None
	order = np.argsort(theta)
	for zq in np.arange(max(z_full, z_floor), top - float(cfg.get("clearance_top_m", 0.006)), float(cfg.get("clearance_step_m", 0.002))):
		k = int(np.clip(np.searchsorted(zr, zq, side="right") - 1, 0, len(zr) - 2))
		t = float(np.clip((zq - zr[k]) / max(zr[k + 1] - zr[k], 1e-9), 0.0, 1.0))
		th_q, r_q = arm_section(arm, float(zq), bins, 0)
		rho_k = np.interp(th_q, theta[order], ring_rho[k][order], period=2.0 * math.pi)
		rho_k1 = np.interp(th_q, theta[order], ring_rho[k + 1][order], period=2.0 * math.pi)
		gap = rho_k * (1.0 - t) + rho_k1 * t - r_q
		worst = int(np.argmin(gap))
		if clearance is None or float(gap[worst]) < clearance:
			clearance = float(gap[worst])
			clearance_at = [round(float(zq), 4), round(math.degrees(float(th_q[worst])), 1), round(float(r_q[worst]), 4)]
	faces_made = 0
	collar_new = []
	for j in range(len(ring_vertices) - 1):
		lo, hi = ring_vertices[j], ring_vertices[j + 1]
		for i in range(n):
			a, b = cycle[i], cycle[(i + 1) % n]
			a2, b2 = lo[i], lo[(i + 1) % n]
			a3, b3 = hi[i], hi[(i + 1) % n]
			# the loop edge a -> b runs in the block face's direction, so the strip runs b -> a on the lower edge of each quad
			f = bm.faces.new((b2, a2, a3, b3))
			f[layer_c] = 1
			collar_new.append(f)
			for lp, k in zip(f.loops, (i, i, i, i)):
				lp[uv_layer].uv = loop_uv[(k + 1) % n] if lp.vert in (b2, b3) else loop_uv[k]
			faces_made += 1
	# the strip's quads run along the loop edges opposite to the block's faces, so the winding is consistent with the block by
	# construction (no recalc_face_normals: the open surface has no inside to measure against)
	bmesh.ops.triangulate(bm, faces=collar_new)
	bm.to_mesh(me)
	bm.free()
	me.update()
	return {"loop_vertices": n, "loop_rho_m": [round(float(v), 4) for v in (rho0.min(), np.median(rho0), rho0.max())], "rings": len(rows), "arm_vertices": int(len(arm)), "collar_quads": faces_made, "ring_z_m": [round(float(z), 5) for z in ring_z],
		"full_z_m": round(float(z_full), 5), "top_z_m": round(float(top), 5), "min_clearance_m": None if clearance is None else round(clearance, 5), "min_clearance_at": clearance_at}


def add_object(name, part, image_name_uv_layer):
	"""A mesh object from make_side()'s dict with its UV layer (named like the body's), the pipe_fist attribute set and the
	weights written."""
	names = pc.bone_names()
	obj = pb.new_mesh_object(name, part["co"], [tuple(int(i) for i in f) for f in part["tris"]])
	me = obj.data
	layer = me.uv_layers.new(name=image_name_uv_layer)
	flat = part["uv"].reshape(-1, 2).astype(np.float32)
	layer.data.foreach_set("uv", flat.ravel())
	if part.get("collar"):
		part["collar_report"] = build_collar(me, part, image_name_uv_layer)
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
	if part.get("bisect"):
		# which faces lie between the strap's two planes (the palette step makes exactly those the strap's slot, so the strap is a
		# clean ring and no stray yellow face survives above or below it)
		(c0, n0), (c1, n1) = part["bisect"]
		centres = pb.face_centers(me)
		h0 = (centres - np.asarray(c0)) @ np.asarray(n0)
		h1 = (centres - np.asarray(c1)) @ np.asarray(n1)
		band = ((h0 >= -1e-6) & (h1 <= 1e-6)).astype(np.int32)
		b = me.attributes.new(BAND_ATTR, "INT", "FACE")
		b.data.foreach_set("value", band)
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
