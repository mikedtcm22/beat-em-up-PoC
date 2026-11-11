"""M7 T14: writes assets/source/trailer_art/player/features.svg, the hero's gloves drawn for tools/pipeline/trailer_features.py (the Punk's face is
drawn by hand in its svg; the gloves repeat, so this generates them: both hands, the right one in the arm_r view and the left its mirror in arm_l).

	python3 tools/pipeline/trailer_player_features.py        (no dependencies; writes the svg)

Millimetres on the view's screen (x right, y DOWN, 0 at (0.09 m, 0.30 m) of the view: tools/pipeline/trailer_paint.py `sheet player ... arm_r 0.09 0.30 130 180 3`
shows the grid). The hand's axis on that sheet runs from (-10, -135) at the forearm's middle to (39, 119) at the knuckles. The drawing: four knuckle
arcs with the finger separations and the first joint of each finger on the back of the fist, a stitched leather panel along the back of the hand, a
stitched seam where the glove meets the cuff, and the wrist strap's buckle and stitches on the strap band.
"""
import os


def axis_x(y):
	"""The hand's axis x at screen y (mm): a line through (15, -2) and (39, 119)."""
	return 15.0 + (y + 2.0) * (24.0 / 121.0)


def dashes(points, dash, gap, width, opacity, mirror):
	out = []
	pts = [(-x if mirror else x, y) for x, y in points]
	import math
	for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
		length = math.hypot(x1 - x0, y1 - y0)
		n = max(int(length / (dash + gap)), 1)
		for i in range(n):
			a = i * (dash + gap) / length
			b = min(a + dash / length, 1.0)
			out.append('<path d="M %.1f %.1f L %.1f %.1f"/>' % (x0 + (x1 - x0) * a, y0 + (y1 - y0) * a, x0 + (x1 - x0) * b, y0 + (y1 - y0) * b))
	return out


def mx(x, mirror):
	return -x if mirror else x


def path(pts, mirror):
	"""A cubic path through `pts` given as 'M x y' then triples of control, control, end."""
	p = [(mx(x, mirror), y) for x, y in pts]
	d = "M %.1f %.1f" % p[0]
	for i in range(1, len(p), 3):
		d += " C %.1f %.1f, %.1f %.1f, %.1f %.1f" % (p[i] + p[i + 1] + p[i + 2])
	return '<path d="%s"/>' % d


def hand(mirror):
	name, origin = ("arm_l", "-0.09 0.30") if mirror else ("arm_r", "0.09 0.30")
	o = ['<g data-view="%s" data-origin="%s" data-px="3">' % (name, origin)]
	# knuckles: four arcs along the front of the fist, bulging toward the wrist; the outer two heavier
	o.append('\t<g stroke-width="2.6" opacity="1" data-taper="0.12,0.3" data-wobble="0.5">')
	for k, cx in enumerate((-14, 9, 32, 55)):
		x = cx + 36 + (0 if k else -2)
		o.append("\t\t" + path([(x - 9, 104), (x - 8, 92), (x + 6, 89), (x + 11, 96), (x + 12, 99), (x + 12, 102), (x + 12, 106)], mirror).replace("<path", '<path id="knuckle_%d"' % k))
	o.append("\t</g>")
	# finger separations: three lines from the knuckle row up the back of the hand
	o.append('\t<g stroke-width="2.0" opacity="0.95" data-taper="0.05,0.55" data-wobble="0.45">')
	for k, cx in enumerate((-2, 21, 44)):
		x = cx + 36
		o.append("\t\t" + path([(x, 104), (x - 1.5, 94), (x + 1.5, 82), (x + 0.5, 64)], mirror).replace("<path", '<path id="finger_%d"' % k))
	o.append("\t</g>")
	# the first joint of each finger
	o.append('\t<g stroke-width="1.5" opacity="0.7" data-taper="0.25,0.4" data-wobble="0.4">')
	for k, cx in enumerate((-14, 9, 32, 55)):
		x = cx + 36
		o.append("\t\t" + path([(x - 9, 76), (x - 4, 72), (x + 6, 72), (x + 10, 76)], mirror).replace("<path", '<path id="phalanx_%d"' % k))
	o.append("\t</g>")
	# the stitched leather panel along the back of the hand: two seams, from the cuff toward the knuckles
	o.append('\t<g stroke-width="1.1" opacity="0.8" data-taper="0.0,0.0" data-wobble="0.2">')
	for side in (-1, 1):
		pts = [(axis_x(y) + side * 17 + (y - 40) * 0.0, y) for y in (14, 30, 46, 60)]
		o.extend("\t\t" + d for d in dashes(pts, 3.2, 2.6, 1.1, 0.8, mirror))
	# where the glove meets the cuff
	pts = [(axis_x(y) + dx, y) for dx, y in ((-44, 12), (-22, 7), (0, 5), (22, 7), (46, 12))]
	o.extend("\t\t" + d for d in dashes(pts, 3.2, 2.6, 1.1, 0.8, mirror))
	# the strap's stitches, along both edges of the band
	for yy in (-47, -14):
		pts = [(axis_x(yy) + dx - 4, yy + dx * 0.03) for dx in (-42, -20, 0, 20, 42)]
		o.extend("\t\t" + d for d in dashes(pts, 3.0, 2.6, 1.1, 0.8, mirror))
	o.append("\t</g>")
	# the buckle: a frame and its bar on the strap, the prong across it
	o.append('\t<g stroke-width="2.4" opacity="0.95" data-taper="0.02,0.02" data-wobble="0.25">')
	bx = axis_x(-30) - 4
	for k, pts in enumerate(([(bx - 12, -45), (bx + 12, -45), (bx + 12, -15), (bx - 12, -15), (bx - 12, -45)], [(bx - 3, -45), (bx - 3, -15)])):
		d = "M " + " L ".join("%.1f %.1f" % (mx(x, mirror), y) for x, y in pts)
		o.append('\t\t<path id="buckle_%d" d="%s"/>' % (k, d))
	o.append('\t\t<path id="prong" d="M %.1f -30 L %.1f -30"/>' % (mx(bx - 3, mirror), mx(bx + 9, mirror)))
	o.append("\t</g>")
	o.append("</g>")
	return "\n".join(o)


def main():
	root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "source", "trailer_art", "player", "features.svg")
	svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-130 -180 260 360">',
		"<!-- Generated by tools/pipeline/trailer_player_features.py: the hero's gloves (knuckles, fingers, stitching, the wrist strap's buckle). -->",
		hand(False), hand(True), "</svg>", ""]
	with open(root, "w") as f:
		f.write("\n".join(svg))


main()
