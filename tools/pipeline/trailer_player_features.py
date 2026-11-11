"""M7 T14: writes assets/source/trailer_art/player/features.svg, the hero's gloves drawn for tools/pipeline/trailer_features.py (the Punk's face is
drawn by hand in its svg; the gloves repeat, so this generates them: both hands, the right one in the arm_r view and the left its mirror in arm_l).

	python3 tools/pipeline/trailer_player_features.py        (no dependencies; writes the svg)

Millimetres on the view's screen (x right, y DOWN, 0 at (0.09 m, 0.30 m) of the view: tools/pipeline/trailer_paint.py `sheet player ... arm_r 0.09 0.30 130 180 3`
shows the grid). The hand's axis on that sheet runs from (-10, -135) at the forearm's middle to (39, 119) at the knuckles. The drawing: four knuckle
arcs with the finger separations and the first joint of each finger on the back of the fist, a leather panel along the back of the hand, a
seam where the glove meets the cuff, and the wrist strap's two edge lines.
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
	o.append('\t<g stroke-width="6.0" opacity="1" data-taper="0.12,0.3" data-wobble="0.5">')
	for k, cx in enumerate((-14, 9, 32, 55)):
		x = cx + 36 + (0 if k else -2)
		o.append("\t\t" + path([(x - 9, 104), (x - 8, 92), (x + 6, 89), (x + 11, 96), (x + 12, 99), (x + 12, 102), (x + 12, 106)], mirror).replace("<path", '<path id="knuckle_%d"' % k))
	o.append("\t</g>")
	# finger separations: three lines from the knuckle row up the back of the hand
	o.append('\t<g stroke-width="5.2" opacity="1" data-taper="0.05,0.55" data-wobble="0.45">')
	for k, cx in enumerate((-2, 21, 44)):
		x = cx + 36
		o.append("\t\t" + path([(x, 104), (x - 1.5, 94), (x + 1.5, 82), (x + 0.5, 64)], mirror).replace("<path", '<path id="finger_%d"' % k))
	o.append("\t</g>")
	# the first joint of each finger
	o.append('\t<g stroke-width="4.2" opacity="0.95" data-taper="0.25,0.4" data-wobble="0.4">')
	for k, cx in enumerate((-14, 9, 32, 55)):
		x = cx + 36
		o.append("\t\t" + path([(x - 9, 76), (x - 4, 72), (x + 6, 72), (x + 10, 76)], mirror).replace("<path", '<path id="phalanx_%d"' % k))
	o.append("\t</g>")
	# the leather panel along the back of the hand (two solid seams, from the cuff toward the knuckles), the seam where the glove meets the cuff,
	# the strap's two edges: solid tapered lines (short dashes read as stray black marks on a sleeve at this size)
	o.append('\t<g stroke-width="3.0" opacity="0.9" data-taper="0.15,0.35" data-wobble="0.3">')
	for k, side in enumerate((-1, 1)):
		pts = [(axis_x(y) + side * 17, y) for y in (14, 30, 46, 60)]
		o.append("\t\t" + path([pts[0], pts[1], pts[2], pts[3]], mirror).replace("<path", '<path id="panel_%d"' % k))
	o.append("\t</g>")
	o.append('\t<g stroke-width="4.6" opacity="1" data-taper="0.1,0.2" data-wobble="0.3">')
	pts = [(axis_x(y) + dx, y) for dx, y in ((-44, 12), (-22, 7), (0, 5), (22, 7), (46, 12))]
	o.append("\t\t" + path([pts[0], pts[1], pts[2], pts[3]], mirror).replace("<path", '<path id="cuff_seam"'))
	for k, yy in enumerate((-47, -14)):
		pts = [(axis_x(yy) + dx - 4, yy + dx * 0.03) for dx in (-42, -14, 14, 42)]
		o.append("\t\t" + path(pts, mirror).replace("<path", '<path id="strap_edge_%d"' % k))
	o.append("\t</g>")
	# knuckle creases: short bold arcs across the back of the fist, below the knuckle row
	o.append('\t<g stroke-width="4.6" opacity="0.95" data-taper="0.3,0.3" data-wobble="0.4">')
	for k, cx in enumerate((-14, 9, 32, 55)):
		x = cx + 36
		o.append("\t\t" + path([(x - 8, 88), (x - 4, 84), (x + 4, 84), (x + 8, 88)], mirror).replace("<path", '<path id="crease_%d"' % k))
	o.append("\t</g>")
	# no buckle: its frame and prong, seen at an angle on the strap, read as stray black dashes (t_06's strap is a plain band with a dark edge line)
	o.append("</g>")
	return "\n".join(o)


def main():
	root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "source", "trailer_art", "player", "features.svg")
	svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-130 -180 260 360">',
		"<!-- Generated by tools/pipeline/trailer_player_features.py: the hero's gloves (knuckles, fingers, seams, the strap edges). -->",
		hand(False), hand(True), "</svg>", ""]
	with open(root, "w") as f:
		f.write("\n".join(svg))


main()
