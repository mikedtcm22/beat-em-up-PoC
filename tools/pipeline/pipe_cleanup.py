"""Mesh clean-up helpers of the chain (M4 package F-punk): the folded triangles of a generated mesh.

A triangle is FOLDED when its winding opposes the smooth normal at its corners (cross(b - a, c - a) . (n_a + n_b + n_c) < 0
with n the area-weighted vertex normals): the surface doubles back on itself there. Tripo's meshes carry some, the decimation
adds more (the smoke Punk had 159 of 15,000), and A7's flip count charges them to every pose. blender_export.folded_triangles
counts them on the written GLB with the same rule; unfold() removes them before the palette UVs are written.
"""
import numpy as np


def vertex_normals(co, tris):
	a, b, c = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
	fn = np.cross(b - a, c - a)  # area-weighted
	vn = np.zeros_like(co)
	for k in range(3):
		np.add.at(vn, tris[:, k], fn)
	ln = np.linalg.norm(vn, axis=1, keepdims=True)
	return fn, vn / np.maximum(ln, 1e-18)


def folded(co, tris):
	"""Boolean mask of the folded triangles."""
	fn, vn = vertex_normals(co, tris)
	mean = vn[tris[:, 0]] + vn[tris[:, 1]] + vn[tris[:, 2]]
	return (fn * mean).sum(axis=1) < 0.0


def neighbours(n_verts, tris):
	"""Vertex adjacency as (indptr, indices) arrays."""
	e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
	e = np.concatenate([e, e[:, ::-1]])
	order = np.lexsort((e[:, 1], e[:, 0]))
	e = e[order]
	keep = np.ones(len(e), dtype=bool)
	keep[1:] = (e[1:] != e[:-1]).any(axis=1)
	e = e[keep]
	indptr = np.zeros(n_verts + 1, dtype=np.int64)
	np.add.at(indptr, e[:, 0] + 1, 1)
	indptr = np.cumsum(indptr)
	return indptr, e[:, 1]


def unfold(co, tris, locked=None, iterations=12, factor=0.5, ring=1):
	"""Relax the corners of folded triangles (and `ring` neighbour rings of them) toward the mean of their neighbours until
	no triangle is folded or a pass stops helping. `locked` (n,) bool vertices never move. Returns (new co, report)."""
	co = co.copy()
	n = len(co)
	locked = np.zeros(n, dtype=bool) if locked is None else locked
	indptr, idx = neighbours(n, tris)
	start = int(folded(co, tris).sum())
	count = start
	history = [start]
	for _ in range(iterations):
		f = folded(co, tris)
		if not f.any():
			break
		sel = np.zeros(n, dtype=bool)
		sel[tris[f].ravel()] = True
		for _r in range(ring):
			grow = sel.copy()
			for v in np.nonzero(sel)[0]:
				grow[idx[indptr[v]:indptr[v + 1]]] = True
			sel = grow
		sel &= ~locked
		new = co.copy()
		for v in np.nonzero(sel)[0]:
			nb = idx[indptr[v]:indptr[v + 1]]
			if len(nb):
				new[v] = co[v] + factor * (co[nb].mean(axis=0) - co[v])
		now = int(folded(new, tris).sum())
		if now >= count:
			break
		co, count = new, now
		history.append(count)
	return co, {"folded_before": start, "folded_after": count, "passes": len(history) - 1, "history": history}
