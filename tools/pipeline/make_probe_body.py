"""The pipeline's own deterministic test body (M4-plan Part C section 5 "P1-pipe" step 3; no credits).

	python3 -I tools/pipeline/make_probe_body.py             build the source, run the whole chain, write the fixture
	python3 -I tools/pipeline/make_probe_body.py --source    only build the source (assets/source/_cache/probe_body/source/)
	  --regions <json>   the five region colours ({"skin", "torso", "arms", "legs", "feet": "#rrggbb"}) in place of REGIONS' defaults
	  --out <dir>        build the source into <dir> instead of SOURCE_DIR
	  --name <name>      the source file is <name>_source.glb (default "probe")
	The three arguments are how the training dummy's source is made (M6 CHAIN):
	  python3 -I tools/pipeline/make_probe_body.py --source --regions assets/source/characters/dummy/regions.json \
	      --out assets/source/characters/dummy/source --name dummy
	With none of them the build is byte for byte the probe's, so the probe report's hash holds.

It stands in for a Tripo delivery so every step of the chain is exercised without spending a credit. The source is a
single watertight skin (five regions: head and neck, torso, arms, legs, feet; hands are blobs the chain replaces with
fists) made of capsules and voxel-remeshed, UV-unwrapped and painted with a texture of the region colours plus shading
noise, rigged with an auto-weighted "Unity"-named armature that has extras (a jaw, eyes, finger bones) the chain must
merge into their parents. It is deliberately NOT on the table: 0.55 scale, centred, facing glTF +Z (Blender -Y), the
A-pose swung 38 degrees instead of 45, arms 8% long, legs 5% short, a big head. The chain has to find the facing,
measure the swing, fit the table and rig it. Same Blender, same bytes: the build uses no randomness but a seeded
numpy generator.

Run inside Blender (`blender --background --factory-startup --python tools/pipeline/make_probe_body.py -- build <dir>`)
it builds <name>_source.glb into <dir>; run by plain python it drives Blender and then run.py.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pipe_common as pc  # noqa: E402

CONFIG = "tests/fixtures/art/probe_pipeline.json"
SOURCE_DIR = "assets/source/_cache/probe_body/source"

try:
	import bpy
	INSIDE_BLENDER = True
except ImportError:
	INSIDE_BLENDER = False

# Region colours (the shared palette's sRGB values, so the texture matches swatches the chain can find).
REGIONS = {"skin": "#f0c9a8", "torso": "#c9c6cf", "arms": "#5c6b7a", "legs": "#4b4854", "feet": "#2b2833"}
SOURCE_SWING_DEG = 38.0
ARM_STRETCH = 1.08
LEG_STRETCH = 0.95
SOURCE_SCALE = 0.55
VOXEL_M = 0.018
TEXTURE_PX = 1024


def build_source(outdir, regions_path=None, name="probe"):
	import json
	import math

	import bmesh
	import numpy as np
	from mathutils import Matrix, Vector

	import pipe_blender as pb

	pb.reset_scene()
	regions = dict(REGIONS)
	if regions_path:
		with open(regions_path) as f:
			given = json.load(f)
		if sorted(given) != sorted(REGIONS):
			raise SystemExit("--regions needs exactly the keys %s, got %s" % (sorted(REGIONS), sorted(given)))
		regions = given
	J = dict(pc.table_joints())
	# Source proportions: long arms, short legs, a taller torso, A-pose swing 38 degrees.
	for side in pc.SIDES:
		d = pc.swing_dir(side, SOURCE_SWING_DEG)
		ua = J[side + "UpperArm"]
		J[side + "LowerArm"] = pc.vadd(ua, pc.vmul(d, 0.29 * ARM_STRETCH))
		J[side + "Hand"] = pc.vadd(J[side + "LowerArm"], pc.vmul(d, 0.27 * ARM_STRETCH))
	for side in pc.SIDES:
		hip = J[side + "UpperLeg"]
		for n in ("LowerLeg", "Foot", "Toes"):
			p = J[side + n]
			J[side + n] = (p[0], p[1], hip[2] - (hip[2] - p[2]) * LEG_STRETCH)
	hips_z = J["Hips"][2]
	for n in ("Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm"):
		p = J[n]
		J[n] = (p[0], p[1], hips_z + (p[2] - hips_z) * 1.04)
	for side in pc.SIDES:  # the arm chains hang from the (moved) upper-arm joints
		d = pc.swing_dir(side, SOURCE_SWING_DEG)
		ua = J[side + "UpperArm"]
		J[side + "LowerArm"] = pc.vadd(ua, pc.vmul(d, 0.29 * ARM_STRETCH))
		J[side + "Hand"] = pc.vadd(J[side + "LowerArm"], pc.vmul(d, 0.27 * ARM_STRETCH))
	dirs = {s: pc.swing_dir(s, SOURCE_SWING_DEG) for s in pc.SIDES}

	# ----- capsules: (region, a, b, ra, rb, (sx, sy))
	caps = []

	def cap(region, a, b, ra, rb=None, sxy=(1.0, 1.0)):
		caps.append((region, tuple(a), tuple(b), ra, ra if rb is None else rb, sxy))

	head_c = (0.0, 0.01, J["Head"][2] + 0.11)
	cap("skin", (0.0, 0.0, J["Neck"][2] - 0.03), (0.0, 0.0, J["Head"][2] + 0.02), 0.065)
	cap("skin", head_c, (head_c[0], head_c[1], head_c[2] + 0.005), 0.135)
	cap("torso", (0.0, 0.0, J["Hips"][2] - 0.1), (0.0, 0.0, J["Hips"][2] + 0.02), 0.15, 0.15, (1.2, 0.8))
	cap("torso", (0.0, 0.0, J["Spine"][2] - 0.03), (0.0, 0.0, J["Chest"][2]), 0.15, 0.17, (1.2, 0.8))
	cap("torso", (0.0, 0.0, J["Chest"][2]), (0.0, 0.0, J["UpperChest"][2]), 0.175, 0.2, (1.25, 0.72))
	cap("torso", (0.0, 0.0, J["UpperChest"][2]), (0.0, 0.0, J["Neck"][2] - 0.02), 0.2, 0.21, (1.25, 0.7))
	for side in pc.SIDES:
		ua, la, hd = J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"]
		cap("arms", ua, ua, 0.08)
		cap("arms", ua, la, 0.072, 0.062)
		cap("arms", la, hd, 0.058, 0.05)
		cap("skin", hd, pc.vadd(hd, pc.vmul(dirs[side], 0.06)), 0.048, 0.046)
		ul, ll, ft, tz = J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"], J[side + "Toes"]
		cap("legs", (ul[0], ul[1], ul[2] + 0.02), ll, 0.1, 0.085)
		cap("legs", ll, ft, 0.085, 0.06)
		cap("feet", (ft[0], -0.045, ft[2] - 0.055), (ft[0], 0.17, ft[2] - 0.055), 0.045, 0.04, (1.1, 1.0))

	def capsule(a, b, ra, rb, sxy, segs=20, body_rings=5, cap_rings=6):
		a, b = Vector(a), Vector(b)
		axis = b - a
		length = axis.length
		axis = axis.normalized() if length > 1e-9 else Vector((0, 0, 1))
		u = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
		v = axis.cross(u).normalized()
		rings = []  # (s, r)
		for i in range(1, cap_rings):
			th = math.pi / 2 * i / cap_rings
			rings.append((-ra * math.cos(th), ra * math.sin(th)))
		for j in range(body_rings + 1):
			t = j / body_rings
			rings.append((length * t, ra + (rb - ra) * t))
		for i in range(cap_rings - 1, 0, -1):
			th = math.pi / 2 * i / cap_rings
			rings.append((length + rb * math.cos(th), rb * math.sin(th)))
		pts = [tuple(a - axis * ra)]
		for s, r in rings:
			c = a + axis * s
			for k in range(segs):
				ang = 2 * math.pi * k / segs
				off = (u * math.cos(ang) + v * math.sin(ang)) * r
				pts.append((c.x + off.x * sxy[0], c.y + off.y * sxy[1], c.z + off.z))
		pts.append(tuple(a + axis * (length + rb)))
		faces = []
		n_rings = len(rings)
		for k in range(segs):
			faces.append((0, 1 + (k + 1) % segs, 1 + k))
		for i in range(n_rings - 1):
			for k in range(segs):
				p0, p1 = 1 + i * segs + k, 1 + i * segs + (k + 1) % segs
				q0, q1 = 1 + (i + 1) * segs + k, 1 + (i + 1) * segs + (k + 1) % segs
				faces.append((p0, p1, q1, q0))
		last = len(pts) - 1
		for k in range(segs):
			faces.append((last, 1 + (n_rings - 1) * segs + k, 1 + (n_rings - 1) * segs + (k + 1) % segs))
		return pts, faces

	all_pts, all_faces, segments, seg_regions = [], [], [], []
	for region, a, b, ra, rb, sxy in caps:
		pts, faces = capsule(a, b, ra, rb, sxy)
		base = len(all_pts)
		all_pts += pts
		all_faces += [tuple(i + base for i in f) for f in faces]
		segments.append((a, b, max(ra, rb) * max(sxy)))
		seg_regions.append(region)
	obj = pb.new_mesh_object("Body", np.array(all_pts), all_faces)
	me = obj.data
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	pb.activate(obj)
	me.remesh_voxel_size = VOXEL_M
	bpy.ops.object.voxel_remesh()
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True

	# ----- UVs and the texture
	me.uv_layers.new(name="UVMap")
	pb.activate(obj)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.002)
	bpy.ops.object.mode_set(mode="OBJECT")
	co = pb.verts(me)
	centers = pb.face_centers(me)
	region_names = sorted(regions)
	dist = np.zeros((len(centers), len(segments)))
	for k, (a, b, r) in enumerate(segments):
		a_, b_ = np.array(a), np.array(b)
		ab = b_ - a_
		t = np.clip(((centers - a_) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
		dist[:, k] = np.linalg.norm(centers - (a_ + t[:, None] * ab), axis=1) - r
	nearest = np.argmin(dist, axis=1)
	face_region = np.array([region_names.index(seg_regions[k]) for k in nearest])
	rgb = {n: np.array([int(regions[n][i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255.0 for n in region_names}
	rng = np.random.RandomState(1234)
	shade = 0.94 + 0.12 * rng.random_sample(len(centers))
	shade *= 0.9 + 0.1 * np.clip((centers[:, 2] - 0.3) / 1.5, 0.0, 1.0)
	n_loops = len(me.loops)
	uv = np.empty(n_loops * 2, dtype=np.float32)
	me.uv_layers[0].data.foreach_get("uv", uv)
	uv = uv.reshape(-1, 2)
	start, total, lv = pb.poly_arrays(me)
	img_px = np.zeros((TEXTURE_PX, TEXTURE_PX, 4))
	img_px[..., :3] = np.array([0.4, 0.4, 0.4])
	img_px[..., 3] = 1.0
	for f in range(len(start)):
		tri = uv[start[f]:start[f] + 3] * TEXTURE_PX
		x0, y0 = np.floor(tri.min(axis=0)).astype(int) - 1
		x1, y1 = np.ceil(tri.max(axis=0)).astype(int) + 1
		x0, y0 = max(x0, 0), max(y0, 0)
		x1, y1 = min(x1, TEXTURE_PX - 1), min(y1, TEXTURE_PX - 1)
		xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
		a, b, c = tri
		d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
		if abs(d) < 1e-9:
			continue
		w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
		w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
		w2 = 1.0 - w0 - w1
		inside = (w0 >= -0.2) & (w1 >= -0.2) & (w2 >= -0.2)
		col = np.clip(rgb[region_names[face_region[f]]] * shade[f], 0.0, 1.0)
		img_px[y0:y1 + 1, x0:x1 + 1][inside, :3] = col
	image = bpy.data.images.new("probe_albedo", TEXTURE_PX, TEXTURE_PX, alpha=False)
	image.pixels.foreach_set(np.ascontiguousarray(img_px.reshape(-1)).astype(np.float32))
	image.pack()
	mat = bpy.data.materials.new("ProbeSkin")
	mat.use_nodes = True
	bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
	tex.image = image
	mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	me.materials.append(mat)

	# ----- the source rig: the 23 Unity-named bones plus extras, auto weights
	segs = pc.segments(J, J["Head"][2] + 0.25, dirs)
	segs["Root"] = ((0.0, 0.0, 0.0), J["Hips"])
	extras = {"Jaw": ("Head", (0.0, 0.03, J["Head"][2] + 0.05), (0.0, 0.1, J["Head"][2] + 0.04)),
		"LeftEye": ("Head", (-0.04, 0.1, J["Head"][2] + 0.13), (-0.04, 0.13, J["Head"][2] + 0.13)),
		"RightEye": ("Head", (0.04, 0.1, J["Head"][2] + 0.13), (0.04, 0.13, J["Head"][2] + 0.13))}
	parents = dict(pc.bone_parent())
	for side in pc.SIDES:
		hd = J[side + "Hand"]
		d = dirs[side]
		extras[side + "IndexProximal"] = (side + "Hand", pc.vadd(hd, pc.vmul(d, 0.03)), pc.vadd(hd, pc.vmul(d, 0.06)))
		extras[side + "ThumbProximal"] = (side + "Hand", pc.vadd(hd, pc.vmul(d, 0.01)), pc.vadd(hd, pc.vmul(d, 0.04)))
	order = pc.bone_names() + sorted(extras)
	for n, (parent, h, t) in extras.items():
		segs[n] = (h, t)
		parents[n] = parent
	arm = pb.make_armature("Armature", segs, order, parents)
	pb.attach_armature(obj, arm)
	names = pb.auto_weights(obj, arm, skip=("Root",))
	w = pb.weights_matrix(obj, order)
	w, filled = pb.fill_unweighted(co, w)
	w = pb.limit_and_normalize(w, 4)
	pb.write_weights(obj, order, w, remove_others=True)
	print("probe source: %d vertices, %d triangles, %d bones, %d vertices filled after the heat weights" % (len(co), len(me.polygons), len(order), filled))

	# ----- into the delivery frame: scaled, centred, facing glTF +Z (Blender -Y)
	mid_z = 0.5 * (co[:, 2].max() + co[:, 2].min())
	m = Matrix.Scale(SOURCE_SCALE, 4) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation((0.0, 0.0, -mid_z))
	obj.parent = None
	obj.data.transform(m)
	arm.data.transform(m)
	arm.matrix_world = Matrix.Identity(4)
	obj.matrix_world = Matrix.Identity(4)
	obj.parent = arm
	obj.matrix_parent_inverse = Matrix.Identity(4)
	os.makedirs(outdir, exist_ok=True)
	path = os.path.join(outdir, name + "_source.glb")
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_skins=True, export_influence_nb=4,
		export_animations=False, export_apply=False, export_materials="EXPORT", export_image_format="AUTO", export_texcoords=True)
	print("wrote " + path)
	return path


def option(argv, flag):
	"""The value after `flag` in argv, or None."""
	if flag in argv:
		return argv[argv.index(flag) + 1]
	return None


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	if INSIDE_BLENDER:
		if argv[:1] == ["build"]:
			build_source(argv[1], argv[2] or None, argv[3])
		return 0
	regions = option(argv, "--regions")
	out = option(argv, "--out")
	name = option(argv, "--name") or "probe"
	source_dir = pc.repo_path(out or SOURCE_DIR)
	os.makedirs(source_dir, exist_ok=True)
	cmd = ["blender", "--background", "--factory-startup", "--python-exit-code", "1", "--python", os.path.join(HERE, "make_probe_body.py"), "--", "build", source_dir,
		pc.repo_path(regions) if regions else "", name]
	print("+ " + " ".join(cmd[:3]) + " ... build")
	subprocess.run(cmd, check=True)
	if "--source" in argv:
		return 0
	passthrough = []
	skip = False
	for a in argv:
		if skip:
			skip = False
		elif a in ("--regions", "--out", "--name"):
			skip = True
		elif a != "--source":
			passthrough.append(a)
	cmd = [sys.executable, "-I", os.path.join(HERE, "run.py"), "--config", CONFIG] + passthrough
	print("+ " + " ".join(cmd))
	return subprocess.run(cmd).returncode


if __name__ == "__main__":
	sys.exit(main())
