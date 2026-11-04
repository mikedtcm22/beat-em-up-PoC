"""Scripted rigid models of the static-prop path (M6 package PROPS). Imported by blender_prop_inspect.py and
blender_export_prop.py (Blender 5.x, headless; never the Blender MCP). Every builder makes a mesh object from
primitives with every face already on a palette slot (the face attribute pipe_slot = slot + 1, which the palette step
and the export both read), so a scripted model needs no texture and no Tripo credit.

Frame: the Blender frame of pipe_common (+Z up). A weapon's long axis is +Z here, which the glTF exporter turns into
the Godot +Y of the weapon art frame (weapon.gd: centred, the grip 0.12 m from the -Y end). Sizes are metres.

	build(name, args, mesh_name) -> bpy object     one of BUILDERS
	fixture_crate   the proving model of the path: a 1 m wooden crate with two cross-braces (no Tripo)
	pipe            the pipe weapon: a painted tube with two caps and a wrapped grip, 0.85 m long, centred
	bike_grip       the bike chain's wrapped handle with a pommel, along +Z from z0
	bike_link       one chain link, at the origin, in the XZ plane
"""
import math

import bmesh
import bpy

SLOT_ATTR = "pipe_slot"


def _new(bm, name):
	"""Write bm into a new object named `name` (a mesh of the same name) in the scene."""
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	if SLOT_ATTR not in me.attributes:
		me.attributes.new(SLOT_ATTR, "INT", "FACE")
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def _layer(bm):
	return bm.faces.layers.int.get(SLOT_ATTR) or bm.faces.layers.int.new(SLOT_ATTR)


def _paint(bm, faces, slot):
	layer = _layer(bm)
	for f in faces:
		f[layer] = int(slot) + 1


def add_box(bm, center, size, slot):
	"""An axis-aligned box on one slot."""
	res = bmesh.ops.create_cube(bm, size=1.0)
	verts = res["verts"]
	bmesh.ops.scale(bm, vec=size, verts=verts)
	bmesh.ops.translate(bm, vec=center, verts=verts)
	faces = list({f for v in verts for f in v.link_faces})
	_paint(bm, faces, slot)
	return faces


def add_tube(bm, center, radius, length, slot, segments=12, axis="z", radius2=None):
	"""A capped cylinder (or cone when radius2 differs) along `axis`, centred on `center`, on one slot."""
	res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius if radius2 is None else radius2, depth=length)
	verts = res["verts"]
	if axis == "x":
		bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=_rot("y", math.pi / 2), verts=verts)
	elif axis == "y":
		bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=_rot("x", math.pi / 2), verts=verts)
	bmesh.ops.translate(bm, vec=center, verts=verts)
	faces = list({f for v in verts for f in v.link_faces})
	_paint(bm, faces, slot)
	return faces


def _rot(axis, angle):
	from mathutils import Matrix
	return Matrix.Rotation(angle, 3, axis.upper())


def add_torus_link(bm, center, length, width, thickness, slot, plane="xz", arc_segments=6, tube_segments=6):
	"""A stadium-shaped chain link (two straight bars and two half-rings), lying in `plane`, its long side along the plane's
	second axis; the wire is a `tube_segments` polygon of radius thickness / 2."""
	half_straight = max(length - width, 0.0) / 2.0
	radius = width / 2.0 - thickness / 2.0
	path = []
	for i in range(arc_segments + 1):  # the top half ring, from +x round to -x
		a = math.pi * i / arc_segments
		path.append((radius * math.cos(a), half_straight + radius * math.sin(a)))
	for i in range(arc_segments + 1):  # the bottom half ring, from -x round to +x
		a = math.pi + math.pi * i / arc_segments
		path.append((radius * math.cos(a), -half_straight + radius * math.sin(a)))
	n = len(path)
	rings = []
	for k, (px, py) in enumerate(path):
		nx, ny = path[(k + 1) % n]
		qx, qy = path[(k - 1) % n]
		tx, ty = nx - qx, ny - qy
		ln = math.hypot(tx, ty) or 1.0
		tx, ty = tx / ln, ty / ln
		out = (ty, -tx)  # the outward normal in the ring plane
		ring = []
		for j in range(tube_segments):
			b = 2.0 * math.pi * j / tube_segments
			r = thickness / 2.0
			u = r * math.cos(b)  # along the in-plane normal
			w = r * math.sin(b)  # out of the plane
			x, y, z = px + out[0] * u, py + out[1] * u, w
			if plane == "xz":
				p = (center[0] + x, center[1] + z, center[2] + y)
			else:
				p = (center[0] + x, center[1] + y, center[2] + z)
			ring.append(bm.verts.new(p))
		rings.append(ring)
	faces = []
	# the path has two duplicate points where the half rings meet (cos / sin repeat): skip degenerate quads
	for k in range(n):
		a, b = rings[k], rings[(k + 1) % n]
		if (a[0].co - b[0].co).length < 1e-7:
			continue
		for j in range(tube_segments):
			try:
				faces.append(bm.faces.new((a[j], a[(j + 1) % tube_segments], b[(j + 1) % tube_segments], b[j])))
			except ValueError:
				pass
	_paint(bm, faces, slot)
	return faces


def fixture_crate(args, mesh_name):
	"""The proving model: a 1 m crate on slots 11 (canvas planks), 63 (rust-brown braces) and 1 (the dark feet)."""
	bm = bmesh.new()
	_layer(bm)
	body, brace, foot = int(args.get("body_slot", 11)), int(args.get("brace_slot", 63)), int(args.get("foot_slot", 1))
	s = float(args.get("size", 1.0))
	add_box(bm, (0, 0, 0.5 * s + 0.05 * s), (s, s, s), body)
	for sx in (-1, 1):
		for sy in (-1, 1):
			add_box(bm, (sx * 0.4 * s, sy * 0.4 * s, 0.025 * s), (0.18 * s, 0.18 * s, 0.05 * s), foot)
	for sy in (-1, 1):  # a brace across each of the two long faces
		add_box(bm, (0, sy * 0.51 * s, 0.55 * s), (0.9 * s, 0.04 * s, 0.1 * s), brace)
	for sx in (-1, 1):
		add_box(bm, (sx * 0.51 * s, 0, 0.55 * s), (0.04 * s, 0.9 * s, 0.1 * s), brace)
	return _new(bm, mesh_name)


def pipe(args, mesh_name):
	"""The pipe weapon, centred on the origin along +Z: the painted tube, a dark cap at each end, a wrapped grip near the
	-Z end (0.12 m of the end to the grip point), all on slots from args."""
	bm = bmesh.new()
	_layer(bm)
	length = float(args.get("length", 0.85))
	radius = float(args.get("radius", 0.032))
	paint, cap, wrap, ring = int(args.get("paint_slot", 31)), int(args.get("cap_slot", 2)), int(args.get("wrap_slot", 1)), int(args.get("ring_slot", 63))
	add_tube(bm, (0, 0, 0), radius, length - 0.04, paint, segments=int(args.get("segments", 12)))
	for end in (-1, 1):
		add_tube(bm, (0, 0, end * (length / 2.0 - 0.02)), radius * 1.25, 0.04, cap, segments=int(args.get("segments", 12)))
	grip_len = float(args.get("grip_length", 0.22))
	add_tube(bm, (0, 0, -length / 2.0 + 0.04 + grip_len / 2.0), radius * 1.18, grip_len, wrap, segments=int(args.get("segments", 12)))
	add_tube(bm, (0, 0, -length / 2.0 + 0.04 + grip_len + 0.012), radius * 1.3, 0.024, ring, segments=int(args.get("segments", 12)))
	add_tube(bm, (0, 0, length / 2.0 - 0.14), radius * 1.3, 0.024, ring, segments=int(args.get("segments", 12)))
	return _new(bm, mesh_name)


def bike_grip(args, mesh_name):
	"""The wrapped handle: yellow tape (slot args.tape_slot) over a steel core with a pommel, along +Z from z = args.z0."""
	bm = bmesh.new()
	_layer(bm)
	z0 = float(args.get("z0", -0.425))
	length = float(args.get("length", 0.22))
	radius = float(args.get("radius", 0.026))
	tape, steel = int(args.get("tape_slot", 30)), int(args.get("steel_slot", 28))
	add_tube(bm, (0, 0, z0 + 0.01), radius * 1.5, 0.02, steel, segments=int(args.get("segments", 10)))  # the pommel
	add_tube(bm, (0, 0, z0 + 0.02 + (length - 0.02) / 2.0), radius, length - 0.02, tape, segments=int(args.get("segments", 10)))
	for k in range(int(args.get("bands", 4))):  # the tape's edge bands, a touch fatter
		z = z0 + 0.04 + k * (length - 0.06) / max(int(args.get("bands", 4)) - 1, 1)
		add_tube(bm, (0, 0, z), radius * 1.12, 0.012, tape, segments=int(args.get("segments", 10)))
	add_tube(bm, (0, 0, z0 + length + 0.012), radius * 0.75, 0.024, steel, segments=int(args.get("segments", 10)))  # the first link's eye
	return _new(bm, mesh_name)


def bike_link(args, mesh_name):
	"""One chain link at the origin in the XZ plane (long side along +Z), steel."""
	bm = bmesh.new()
	_layer(bm)
	add_torus_link(bm, (0, 0, 0), float(args.get("length", 0.05)), float(args.get("width", 0.028)), float(args.get("thickness", 0.009)),
		int(args.get("steel_slot", 28)), plane="xz", arc_segments=int(args.get("arc_segments", 5)), tube_segments=int(args.get("tube_segments", 6)))
	return _new(bm, mesh_name)


BUILDERS = {"fixture_crate": fixture_crate, "pipe": pipe, "bike_grip": bike_grip, "bike_link": bike_link}


def build(name, args, mesh_name):
	"""The scripted model `name` as an object called `mesh_name` (every face on its slot)."""
	if name not in BUILDERS:
		raise ValueError("no scripted prop model %r (have %s)" % (name, ", ".join(sorted(BUILDERS))))
	return BUILDERS[name](dict(args or {}), mesh_name)
