"""Render the joint table as a chunky grey mannequin in an A-pose (headless Blender; M4 plan Part C section 5 step 2).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_mannequin.py -- <mannequin.json> <out_dir>

Never the Blender MCP. Input: the config (assets/source/mannequin/mannequin.json: every number of the pose, the
shapes and the render lives there) and, named in it, tools/pipeline/joints.json (written by dump_joints.gd from
PlaceholderBody; read-only here). Output in <out_dir>: mannequin_<view>.png for each view of the config (orthographic,
flat background, Workbench studio lighting, one mid-grey material) and mannequin_report.json.

The body is the placeholder rig's own enemy parts (boxes, capsules, ellipsoids, cylinders at their bone offsets), so
its volumes are the volumes the skinned art must fill; costume parts (cap, hair, shades, belt, fist boxes) are skipped
and the hands are open mittens. Only the arm chains are posed: each upper arm swings out about the rig's Z axis and the
forearm and hand continue straight along it; the legs stay parallel. All geometry is built in the rig's space (metres,
+Y up, the character faces -Z) and mapped to Blender as (x, y, z) -> (x, -z, y), so the character faces +Y there.

mannequin_report.json (no timestamps, no absolute paths; the images are identified by a hash of their decoded pixels, since the PNG container's bytes vary between runs) gives, per view, the image size, the pixels
per metre, the camera, where every bone head lands in pixels (u right, v down) and the silhouette's bounding box, so a
generated look-alike image can be compared with the mannequin it was drawn on, and the checks that the background is the
exact configured grey.
"""
import hashlib
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Matrix, Vector

DIGITS = 5


def r(x):
	return round(float(x), DIGITS)


def sha256_file(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


def srgb_byte(hex_color):
	h = hex_color.lstrip("#")
	return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def srgb_to_linear(byte):
	c = byte / 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# Rig space (Godot: +Y up, the character faces -Z) to Blender world (+Z up, the character faces +Y).
RIG_TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def godot_euler_yxz(rot_deg):
	"""Basis of a Godot rotation_degrees (Euler order YXZ): R = Ry * Rx * Rz."""
	x, y, z = (math.radians(a) for a in rot_deg)
	return Matrix.Rotation(y, 4, "Y") @ Matrix.Rotation(x, 4, "X") @ Matrix.Rotation(z, 4, "Z")


def bone_globals(bones, swing_deg):
	"""FK in rig space: {bone: 4x4}. Rest locals are translations; the two upper arms carry a swing about Z."""
	globals_ = {}
	for bone in bones:
		local = Matrix.Translation(Vector(bone["rest_local"]))
		name = bone["name"]
		if name.endswith("UpperArm"):
			# Rz(theta) sends -Y toward +X for a positive angle: the right arm (+X) swings +, the left arm -.
			local = local @ Matrix.Rotation(math.radians(swing_deg if name.startswith("Right") else -swing_deg), 4, "Z")
		parent = bone["parent"]
		globals_[name] = (globals_[parent] if parent else Matrix.Identity(4)) @ local
	return globals_


def to_y_axis(bm, verts):
	"""Turn a Z-axis primitive into a Y-axis one (a proper rotation, so face winding is kept)."""
	for v in verts:
		x, y, z = v.co
		v.co = Vector((x, z, -y))


class MannequinBuilder:
	def __init__(self, cfg):
		self.cfg = cfg
		self.bm = bmesh.new()
		self.mesh_cfg = cfg["mesh"]
		self.parts_built = []

	def _new_verts(self, before):
		return [v for v in self.bm.verts if v not in before]

	def primitive(self, shape, size):
		"""Add one primitive centred on the origin in the part's own axes (Godot's: capsules, cylinders and
		ellipsoids have their axis along Y) and return its vertices. size follows PlaceholderBody: BOX (x, y, z);
		CAPSULE (radius, total height); CYLINDER (radius, height); SPHERE (radius, height)."""
		bm, mc = self.bm, self.mesh_cfg
		before = set(bm.verts)
		if shape == "BOX":
			bmesh.ops.create_cube(bm, size=1.0)
			verts = self._new_verts(before)
			for v in verts:
				v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
			edges = list({e for v in verts for e in v.link_edges})
			width = min(mc["bevel_m"], 0.45 * min(size))
			bmesh.ops.bevel(bm, geom=edges, offset=width, segments=mc["bevel_segments"], profile=0.5, affect="EDGES")
			return self._new_verts(before)
		if shape in ("SPHERE", "CAPSULE"):
			bmesh.ops.create_uvsphere(bm, u_segments=mc["segments"], v_segments=mc["rings"] if shape == "CAPSULE" else mc["rings"] + 1,
				radius=1.0)
			verts = self._new_verts(before)
			radius, height = size[0], size[1]
			if shape == "SPHERE":
				for v in verts:
					v.co = Vector((v.co.x * radius, v.co.y * radius, v.co.z * 0.5 * height))
				to_y_axis(bm, verts)
			else:
				height = max(height, 2.0 * radius)
				stretch = 0.5 * height - radius
				for v in verts:
					z = v.co.z * radius
					v.co = Vector((v.co.x * radius, v.co.y * radius, z + math.copysign(stretch, v.co.z) if abs(v.co.z) > 1e-6 else z))
				to_y_axis(bm, verts)
			return verts
		if shape == "CYLINDER":
			bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=mc["segments"], radius1=size[0], radius2=size[0],
				depth=size[1])
			verts = self._new_verts(before)
			to_y_axis(bm, verts)
			return verts
		raise ValueError("unsupported shape %s (add it to skip_parts or to the builder)" % shape)

	def place(self, verts, matrix_rig):
		"""Put a primitive at a rig-space matrix and finish its shading: smooth, sharp where the face angle is large."""
		to_world = RIG_TO_BLENDER @ matrix_rig
		bmesh.ops.transform(self.bm, matrix=to_world, verts=verts)
		limit = math.radians(self.mesh_cfg["sharp_angle_deg"])
		faces = {f for v in verts for f in v.link_faces}
		for f in faces:
			f.smooth = True
		for e in {e for v in verts for e in v.link_edges}:
			if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > limit:
				e.smooth = False

	def add_part(self, part, bone_global):
		local = Matrix.Translation(Vector(part["offset"])) @ godot_euler_yxz(part["rot_deg"])
		verts = self.primitive(part["shape"], part["size"])
		self.place(verts, bone_global @ local)
		self.parts_built.append(part["name"])

	def add_loft(self, parts, bones_world):
		"""One smooth torso through the boxes of the config's loft parts (pelvis up to the upper chest): a stack of
		superellipse cross-sections, each box's width and depth at its centre height, blended with a smoothstep in
		between, closed flat at both ends. It replaces the stacked slabs, whose bevelled edges left creases that a
		look-alike drawing would copy as belts and folds."""
		lc = self.cfg["loft"]
		stations = []
		for part in parts:
			if part["name"] in lc["parts"]:
				centre = (bones_world[part["bone"]] @ Matrix.Translation(Vector(part["offset"]))).translation
				stations.append((centre.y, 0.5 * part["size"][0], 0.5 * part["size"][2], centre.z, 0.5 * part["size"][1]))
		stations.sort()
		bottom = stations[0][0] - stations[0][4]
		top = stations[-1][0] + stations[-1][4]

		def section(y):
			if y <= stations[0][0]:
				return stations[0][1:4]
			if y >= stations[-1][0]:
				return stations[-1][1:4]
			for a, b in zip(stations, stations[1:]):
				if a[0] <= y <= b[0]:
					t = (y - a[0]) / (b[0] - a[0])
					t = t * t * (3.0 - 2.0 * t)
					return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
			return stations[-1][1:4]

		bm = self.bm
		before = set(bm.verts)
		rings = []
		power = 2.0 / lc["exponent"]
		for j in range(lc["rings"]):
			y = bottom + (top - bottom) * j / (lc["rings"] - 1)
			half_w, half_d, zc = section(y)
			# Round both ends: inside end_round_m of an end the section shrinks along a quarter ellipse to end_floor.
			near_end = min(y - bottom, top - y) / lc["end_round_m"]
			if near_end < 1.0:
				shrink = lc["end_floor"] + (1.0 - lc["end_floor"]) * math.sqrt(1.0 - (1.0 - near_end) ** 2)
				half_w, half_d = half_w * shrink, half_d * shrink
			ring = []
			for k in range(lc["around"]):
				angle = 2.0 * math.pi * k / lc["around"]
				c, sn = math.cos(angle), math.sin(angle)
				ring.append(bm.verts.new(Vector((half_w * math.copysign(abs(c) ** power, c), y, zc + half_d * math.copysign(abs(sn) ** power, sn)))))
			rings.append(ring)
		for a, b in zip(rings, rings[1:]):
			for k in range(lc["around"]):
				bm.faces.new((a[k], a[(k + 1) % lc["around"]], b[(k + 1) % lc["around"]], b[k]))
		bm.faces.new(list(reversed(rings[0])))
		bm.faces.new(rings[-1])
		verts = self._new_verts(before)
		faces = list({f for v in verts for f in v.link_faces})
		bmesh.ops.recalc_face_normals(bm, faces=faces)
		self.place(verts, Matrix.Identity(4))
		self.parts_built.append("TorsoLoft")

	def add_extras(self, joints, bones_world):
		hand = self.cfg["hand"]
		for side in ("Left", "Right"):
			g = bones_world[side + "Hand"]
			# The mitten: a flattened capsule hanging from the wrist, thin toward the body (x), wide front to back (z).
			verts = self.primitive("CAPSULE", (0.5 * hand["thickness_m"], hand["length_m"]))
			for v in verts:
				v.co.z *= hand["width_m"] / hand["thickness_m"]  # stretch z; (x, y, z) are still in the part's axes
			self.place(verts, g @ Matrix.Translation(Vector((0, -0.5 * hand["length_m"], 0))))
			self.parts_built.append(side + "Mitten")
			# The thumb: a small capsule at the front edge, pointing down, a little forward.
			verts = self.primitive("CAPSULE", (hand["thumb_radius_m"], hand["thumb_length_m"]))
			thumb = Matrix.Translation(Vector((0, -hand["thumb_below_wrist_m"], -0.5 * hand["width_m"]))) @ Matrix.Rotation(math.radians(-15), 4, "X")
			self.place(verts, g @ thumb)
			self.parts_built.append(side + "Thumb")
		nose = self.cfg["nose"]
		verts = self.primitive("SPHERE", (0.5 * nose["size_m"][0], nose["size_m"][1]))
		for v in verts:
			v.co.z *= nose["size_m"][2] / nose["size_m"][0]
		self.place(verts, bones_world[nose["bone"]] @ Matrix.Translation(Vector(nose["offset_m"])))
		self.parts_built.append("Nose")

	def finish(self):
		mesh = bpy.data.meshes.new("mannequin")
		self.bm.normal_update()
		self.bm.to_mesh(mesh)
		self.bm.free()
		obj = bpy.data.objects.new("mannequin", mesh)
		bpy.context.scene.collection.objects.link(obj)
		blend = self.mesh_cfg["blend"]
		if blend["voxel_m"] > 0:
			bpy.context.view_layer.objects.active = obj
			obj.select_set(True)
			mesh.remesh_voxel_size = blend["voxel_m"]
			bpy.ops.object.voxel_remesh()
			bpy.ops.object.shade_smooth()
			smooth = obj.modifiers.new("smooth", "SMOOTH")
			smooth.iterations = blend["smooth_iterations"]
			smooth.factor = blend["smooth_factor"]
			bpy.ops.object.modifier_apply(modifier=smooth.name)
		return obj


def setup_scene(cfg):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	rc = cfg["render"]
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.render.resolution_x = rc["width_px"]
	scene.render.resolution_y = rc["height_px"]
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGB"
	scene.render.image_settings.color_depth = "8"
	scene.render.film_transparent = False
	scene.render.dither_intensity = 0.0  # dither would speckle the flat background
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.view_settings.exposure = 0.0
	scene.view_settings.gamma = 1.0
	scene.display.render_aa = rc["antialiasing_samples"]
	shading = scene.display.shading
	shading.light = "STUDIO"
	shading.color_type = "SINGLE"
	shading.show_object_outline = False
	shading.show_shadows = False
	shading.show_cavity = False
	shading.use_dof = False
	body = srgb_byte(cfg["colors"]["mannequin_srgb"])
	shading.single_color = tuple(srgb_to_linear(c) for c in body)
	world = bpy.data.worlds.new("flat")
	# Blender truncates the encoded value to a byte (217.0 can come out as 216), so aim half a level high; the
	# report's background_is_flat check compares the written pixels with the exact configured grey.
	world.color = tuple(srgb_to_linear(c + 0.5) for c in srgb_byte(cfg["colors"]["background_srgb"]))
	scene.world = world
	cam_data = bpy.data.cameras.new("cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = rc["ortho_scale_m"]
	cam_data.sensor_fit = "VERTICAL"
	cam_data.clip_start = 0.1
	cam_data.clip_end = 4.0 * rc["camera_distance_m"]
	cam = bpy.data.objects.new("cam", cam_data)
	scene.collection.objects.link(cam)
	scene.camera = cam
	return scene, cam


def aim(cam, cfg, view):
	"""Put the camera on the view's side of the character, looking at the figure's mid-height."""
	rc = cfg["render"]
	toward_cam = (RIG_TO_BLENDER.to_3x3() @ Vector(view["camera_dir_rig"])).normalized()
	target = Vector((0.0, 0.0, rc["look_at_height_m"]))
	cam.location = target + toward_cam * rc["camera_distance_m"]
	cam.rotation_euler = (-toward_cam).to_track_quat("-Z", "Y").to_euler()
	bpy.context.view_layer.update()


def read_png(path):
	"""The file's raw 8-bit values as an (h, w, 3) uint8 array, top row first."""
	image = bpy.data.images.load(path)
	image.colorspace_settings.name = "Non-Color"
	w, h = image.size
	pixels = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3]
	bpy.data.images.remove(image)
	return np.rint(pixels[::-1] * 255.0).astype(np.uint8)


def render_view(scene, cam, cfg, view, joints_world, out_dir):
	aim(cam, cfg, view)
	path = os.path.join(out_dir, "mannequin_%s.png" % view["name"])
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	rc = cfg["render"]
	width, height = rc["width_px"], rc["height_px"]
	pixels = read_png(path)
	background = np.array(srgb_byte(cfg["colors"]["background_srgb"]), dtype=np.uint8)
	figure = np.any(pixels != background, axis=2)
	ys, xs = np.nonzero(figure)
	corner = [int(c) for c in pixels[0, 0]]
	joints_px = {}
	for name, p in joints_world.items():
		uv = world_to_camera_view(scene, cam, p)
		joints_px[name] = [r(uv.x * width), r((1.0 - uv.y) * height)]
	ppm = height / rc["ortho_scale_m"]
	return {
		"file": os.path.basename(path),
		"pixels_sha256": hashlib.sha256(pixels.tobytes()).hexdigest(),
		"size_px": [width, height],
		"pixels_per_metre": r(ppm),
		"camera": {"toward_camera_rig": view["camera_dir_rig"], "ortho_scale_m": rc["ortho_scale_m"], "look_at_height_m": rc["look_at_height_m"]},
		"background_rgb": corner,
		"background_is_flat": bool(np.all(pixels[0, :, :] == background) and np.all(pixels[-1, :, :] == background)
			and np.all(pixels[:, 0, :] == background) and np.all(pixels[:, -1, :] == background)),
		"silhouette_bbox_px": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else None,
		"silhouette_share": r(float(figure.mean())),
		"joints_px": joints_px,
		"note": view.get("note", ""),
	}


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if len(argv) != 2:
		print("usage: blender --background --factory-startup --python tools/pipeline/blender_mannequin.py -- <mannequin.json> <out_dir>")
		sys.exit(2)
	config_path, out_dir = argv
	repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
	with open(config_path) as f:
		cfg = json.load(f)
	joints_path = os.path.join(repo, cfg["joints"])
	with open(joints_path) as f:
		joints = json.load(f)
	os.makedirs(out_dir, exist_ok=True)
	swing = 90.0 - cfg["pose"]["upper_arm_down_from_horizontal_deg"]
	world = bone_globals(joints["bones"], swing)
	scene, cam = setup_scene(cfg)  # resets Blender's data, so before the body is made
	builder = MannequinBuilder(cfg)
	skip = set(cfg["skip_parts"]) | set(cfg["loft"]["parts"])
	for part in joints[cfg["parts_set"]]:
		if part["name"] not in skip:
			builder.add_part(part, world[part["bone"]])
	builder.add_loft(joints[cfg["parts_set"]], world)
	builder.add_extras(joints, world)
	builder.finish()
	joints_world = {name: (RIG_TO_BLENDER @ g).translation.copy() for name, g in world.items()}
	report = {
		"version": 1,
		"blender": bpy.app.version_string,
		"config": cfg,
		"joints": {"file": cfg["joints"], "sha256": sha256_file(joints_path)},
		"a_pose": {"swing_from_hanging_deg": r(swing), "bones_rig": {n: [r(c) for c in g.translation] for n, g in world.items()}},
		"parts": builder.parts_built,
		"views": {},
	}
	for view in cfg["views"]:
		report["views"][view["name"]] = render_view(scene, cam, cfg, view, joints_world, out_dir)
		info = report["views"][view["name"]]
		print("mannequin_%s.png  %s  flat background %s  silhouette %s" % (view["name"], info["size_px"], info["background_is_flat"], info["silhouette_bbox_px"]))
	with open(os.path.join(out_dir, "mannequin_report.json"), "w") as f:
		json.dump(report, f, indent="\t", sort_keys=False)
		f.write("\n")


if __name__ == "__main__":
	main()
