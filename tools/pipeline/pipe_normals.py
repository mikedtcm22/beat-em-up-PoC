"""Smoothed shading normals for a generated body (M4 package F-punk-fix): the toon bands without the blotches.

Imported by blender_export.py (Blender 5.x, headless; never the Blender MCP) when the config has `export.smooth_normals`.
A generated mesh decimated to 15k triangles is lumpy at the scale of a centimetre or two: a vertex's normal follows the
lump, and the toon shader cuts its three bands on the normal alone (dot(normal, light)), so the band edges break into dark
patches on the vest and the forearms. The cure is in the normals, not the positions (the silhouette, the hurtbox fit and
every skinning number stay as they were): the shading normal of each vertex is blended with its neighbours' over
`iterations` rounds, each neighbour weighted by how well its normal agrees with the vertex's own, so a lump (a few degrees
of disagreement) is averaged away and a real crease (more than `crease_deg`) is left alone.

	smooth_normals(co, tris, iterations, crease_deg, falloff) -> (n, 3) unit normals

The hull's normal (write_hull_normals) is a separate attribute and is not touched; the glTF NORMAL is the smoothed one.
"""
import math

import numpy as np


def vertex_normals(co, tris):
	"""Area-weighted vertex normals of an indexed triangle mesh (n, 3), unit length."""
	a, b, c = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
	fn = np.cross(b - a, c - a)  # its length is twice the area: the weight
	out = np.zeros_like(co)
	for k in range(3):
		np.add.at(out, tris[:, k], fn)
	ln = np.linalg.norm(out, axis=1, keepdims=True)
	return out / np.maximum(ln, 1e-12)


def smooth_normals(co, tris, iterations=12, crease_deg=50.0, falloff=2.0, self_weight=1.0):
	"""The crease-preserving neighbour blend described in the module doc. `falloff` shapes the agreement weight
	(cos mapped from the crease angle to 1, to the power falloff): 1 = linear, higher = only close neighbours count."""
	co = np.asarray(co, dtype=np.float64)
	tris = np.asarray(tris, dtype=np.int64)
	n = vertex_normals(co, tris)
	edges = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]], axis=0)
	edges = np.concatenate([edges, edges[:, ::-1]], axis=0)
	i, j = edges[:, 0], edges[:, 1]
	cos_c = math.cos(math.radians(float(crease_deg)))
	for _ in range(int(iterations)):
		agree = np.einsum("ij,ij->i", n[i], n[j])
		w = np.clip((agree - cos_c) / max(1.0 - cos_c, 1e-9), 0.0, 1.0) ** float(falloff)
		acc = n * float(self_weight)
		np.add.at(acc, i, n[j] * w[:, None])
		ln = np.linalg.norm(acc, axis=1, keepdims=True)
		n = acc / np.maximum(ln, 1e-12)
	return n


def report(before, after):
	"""How far the smoothing moved the normals: mean and p99 angle in degrees, and the share moved more than 15 degrees."""
	ang = np.degrees(np.arccos(np.clip(np.einsum("ij,ij->i", before, after), -1.0, 1.0)))
	return {"mean_deg": float(ang.mean()), "p99_deg": float(np.percentile(ang, 99)), "over_15_deg_share": float((ang > 15.0).mean())}
