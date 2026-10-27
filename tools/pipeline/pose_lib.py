"""Numpy mirror of the game's skinning, for the pipeline's stills and strain numbers (M4 package P1-chain).

It reproduces, in Godot space, what HumanoidRig + SkinnedArt do with an exported GLB (M4-plan Part A A3):
	G_n    the bone's posed global transform, FK down the table (joints.json rest_local, rotation = Euler degrees in Godot's
	       YXZ order, so Basis = Ry * Rx * Rz), exactly PlaceholderBody.pose_globals;
	R_n    the shortest arc from the rig's rest direction (bone -> its first child, in the table) to the GLB's direction
	       (p_child - p_n); leaves take their parent's R; Root and Hips take identity;
	bind_n = (Transform(R_n, p_n))^-1, p_n = the GLB's joint (its inverse bind's origin);
	v' = sum over the vertex's bones of w * G_n * bind_n * v.
A GLB authored at the table's rest (the arms-down bake) gives R = identity, so one function serves both bind routes.
Pure numpy, no bpy: the strain statistics run anywhere numpy does.
"""
import math

import numpy as np

import pipe_common as pc

NAMES = pc.bone_names()


def euler_basis(deg):
	"""Godot Basis.from_euler(degrees, YXZ): Ry * Rx * Rz."""
	x, y, z = (math.radians(a) for a in deg)
	rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
	ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
	rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
	return ry @ rx @ rz


def shortest_arc(a, b):
	a = np.asarray(a, dtype=np.float64)
	b = np.asarray(b, dtype=np.float64)
	a = a / max(np.linalg.norm(a), 1e-12)
	b = b / max(np.linalg.norm(b), 1e-12)
	v = np.cross(a, b)
	c = float(a @ b)
	s = float(np.linalg.norm(v))
	if s < 1e-12:
		return np.eye(3) if c > 0 else -np.eye(3)
	k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
	return np.eye(3) + k + k @ k * ((1.0 - c) / (s * s))


def rest_table():
	"""(local offsets, global positions) per bone from joints.json, Godot space."""
	t = pc.table()
	local = {b["name"]: np.array(b["rest_local"]) for b in t["bones"]}
	glob = {b["name"]: np.array(b["rest_global"]) for b in t["bones"]}
	return local, glob


def fk(pose_deg):
	"""{bone: (3x3, origin)} posed globals; pose_deg maps a bone to (x, y, z) Euler degrees."""
	local, _ = rest_table()
	out = {}
	for n in NAMES:
		basis = euler_basis(pose_deg.get(n, (0.0, 0.0, 0.0)))
		p = pc.bone_parent()[n]
		if p:
			pb_, po = out[p]
			out[n] = (pb_ @ basis, pb_ @ local[n] + po)
		else:
			out[n] = (basis, local[n].copy())
	return out


def binds(glb_joints_godot):
	"""{bone: (R, p)} for a GLB whose joints (Godot space) are glb_joints_godot: see the module doc."""
	_, rest = rest_table()
	kids = pc.bone_children()
	parent = pc.bone_parent()
	rot = {}
	for n in NAMES:
		if n in ("Root", "Hips"):
			rot[n] = np.eye(3)
		elif kids[n]:
			c = kids[n][0]
			rest_dir = rest[c] - rest[n]
			glb_dir = np.array(glb_joints_godot[c]) - np.array(glb_joints_godot[n])
			rot[n] = shortest_arc(rest_dir, glb_dir)
		else:
			rot[n] = rot[parent[n]]
	return {n: (rot[n], np.array(glb_joints_godot[n])) for n in NAMES}


def skin(verts_g, w, glb_joints_godot, pose_deg):
	"""Posed vertices (n, 3) in Godot space for rest vertices verts_g and weights w (n, 23 in NAMES order)."""
	g = fk(pose_deg)
	b = binds(glb_joints_godot)
	out = np.zeros_like(verts_g)
	for i, n in enumerate(NAMES):
		col = w[:, i]
		if not (col > 1e-6).any():
			continue
		R, p = b[n]
		# bind: v -> R^T (v - p); then G: -> Gb @ that + Go
		local = (verts_g - p) @ R
		gb, go = g[n]
		out += col[:, None] * (local @ gb.T + go)
	return out


def strain(rest_g, posed_g, tris, w=None):
	"""Edge-length ratios and triangle-area ratios of a pose against rest. Returns a dict of statistics."""
	edges = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
	edges = np.unique(np.sort(edges, axis=1), axis=0)
	l0 = np.linalg.norm(rest_g[edges[:, 0]] - rest_g[edges[:, 1]], axis=1)
	l1 = np.linalg.norm(posed_g[edges[:, 0]] - posed_g[edges[:, 1]], axis=1)
	keep = l0 > 1e-5
	ratio = l1[keep] / l0[keep]
	a0 = 0.5 * np.linalg.norm(np.cross(rest_g[tris[:, 1]] - rest_g[tris[:, 0]], rest_g[tris[:, 2]] - rest_g[tris[:, 0]]), axis=1)
	a1 = 0.5 * np.linalg.norm(np.cross(posed_g[tris[:, 1]] - posed_g[tris[:, 0]], posed_g[tris[:, 2]] - posed_g[tris[:, 0]]), axis=1)
	big = a0 > 1e-9
	area = a1[big] / a0[big]
	return {
		"edge_p999": float(np.percentile(ratio, 99.9)), "edge_p001": float(np.percentile(ratio, 0.1)),
		"edge_max": float(ratio.max()), "edge_min": float(ratio.min()),
		"area_under_15pct": float((area < 0.15).mean()),
		"nan": bool(np.isnan(posed_g).any()),
	}


def worst_edges(ref_g, posed_g, tris, w, k=5):
	"""The k edges whose length changed most (ratio against the reference, stretch or squash): [{ratio, at, bones}]."""
	edges = np.unique(np.sort(np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]), axis=1), axis=0)
	l0 = np.linalg.norm(ref_g[edges[:, 0]] - ref_g[edges[:, 1]], axis=1)
	l1 = np.linalg.norm(posed_g[edges[:, 0]] - posed_g[edges[:, 1]], axis=1)
	keep = l0 > 1e-5
	ratio = np.where(keep, l1 / np.maximum(l0, 1e-9), 1.0)
	score = np.abs(np.log(np.maximum(ratio, 1e-3)))
	out = []
	for i in np.argsort(-score)[:k]:
		a, b = edges[i]
		out.append({"ratio": float(ratio[i]), "at": ((ref_g[a] + ref_g[b]) / 2).tolist(),
			"bones": [NAMES[int(np.argmax(w[a]))], NAMES[int(np.argmax(w[b]))]]})
	return out
