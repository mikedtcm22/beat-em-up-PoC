"""Writes gen/jobs.json for the Gemini calls of the trailer kit (M7 G3). Run: python3 make_jobs.py"""
import json, os

REFS = ["../../../trailer_ref/frames/t_02.jpg", "../../../trailer_ref/frames/t_04.jpg", "../../../trailer_ref/frames/t_05.jpg"]
STYLE = ("Style: exactly the hand-painted 2D animation look of the reference frames (flat colour fields, bold ink lines that vary in weight "
	"and taper at their ends, loose brush edges, big simple shapes, a little paper grain), NOT a 3D render, NOT a photo, no gradients, "
	"no lighting effects, no perspective, no text, no people. Albedo only: evenly lit, muted mid values (not bright), night-street palette of "
	"slate blue and indigo greys with a few dull brown-red accents. ")
EDGE = "Keep ink lines and brick clusters at least 6% away from the picture's edges, but the wall colour runs right to the edge: no frame, no border, no margin, no vignette. "

WALL = ("A square straight-on elevation (orthographic, filling the frame edge to edge) of a 3 m x 3 m piece of an old city tenement wall, "
	"as a flat texture for a painted-animation night alley. Mostly ONE flat muted slate-blue-grey plaster colour field with a few big soft "
	"irregular tonal patches (slightly lighter and darker blue-grey, loose brush edges). Brick is NOT an all-over pattern: show ")
walls = {
	"wall_a": "only two small sparse clusters of exposed red-brown brick where plaster fell off (6 to 14 bricks each, ragged edges, about half the bricks filled brown-red, the rest outline only, wobbly ink outlines), plus one thin tapering hairline crack.",
	"wall_b": "one vertical drainpipe in a slightly lighter grey with two bracket clamps, one thin ink crack, and just one tiny cluster of five or six brick outlines.",
	"wall_c": "one larger ragged patch of exposed brick low on the wall (about 20 bricks, half filled, loose and irregular, bricks missing at the edges) and nothing else but a couple of hairline cracks.",
	"wall_d": "an almost bare wall: one big diagonal tapering crack with a small branch, one patch of repaint in a different flat blue-grey, and only three or four loose brick outlines near a corner.",
	"wall_e": "a rusty bracket with a loosely drawn cable looping from it, two tiny clusters of brick hints (4 to 8 bricks), one tall thin crack.",
	"wall_f": "a flat painted-over wall with a darker big soft shadow shape across the top third, one small brick cluster at the lower left, and one tapering crack.",
}
jobs = []
for name, extra in walls.items():
	jobs.append({"out": name + ".png", "aspect": "1:1", "size": "2K", "refs": REFS,
		"prompt": WALL + extra + " " + STYLE + EDGE})

GROUND = ("A square TOP-DOWN view (camera straight above, orthographic, filling the frame edge to edge) of 8 m x 8 m of night-street asphalt, as a flat "
	"texture for a painted-animation scene. Mostly flat muted blue-grey asphalt tone with a few big soft irregular patches of slightly different blue-grey "
	"(worn and repaired tar, loose brush edges); drawn black ink cracks that taper at their ends and branch (5 to 8 of them, long and loose); "
	"two or three flat pale blue-grey puddle shapes with a thin ink outline and one lighter highlight shape inside; ")
grounds = {
	"ground_a": "one round manhole cover with a few ink lines and one small drain grate; a patched rectangle of repair with an ink outline.",
	"ground_b": "a painted kerb line (a straight thin pale strip with ink edges and a few expansion-joint ticks) running along one side only, one drain grate, two puddles.",
	"ground_c": "a crack network spreading from the middle, one oil-stain shape in a darker flat tone, a patched rectangle, no manhole.",
}
for name, extra in grounds.items():
	jobs.append({"out": name + ".png", "aspect": "1:1", "size": "2K", "refs": REFS,
		"prompt": GROUND + extra + " " + STYLE + "The left and right borders must match each other in tone and the top and bottom likewise (a seamless repeat), with no ink crossing the very edge."})

FACADE = ("A wide straight-on elevation (orthographic, filling the frame edge to edge) of a far-away tenement block's facade at night, as a flat texture "
	"for a painted-animation alley, two storeys of windows. NOT a regular grid: windows of slightly different widths and heights, a few shifted off the "
	"line, some missing or bricked up, about one in three lit warm sodium-orange (flat orange fills with a darker curtain shape and a hot yellow spot), "
	"the rest dark blue shapes barely lighter than the wall, thin loose ink outlines with weight variation, hand-drawn sills, a couple of flat wall tone patches, "
	"one or two tiny sparse brick-hint clusters. ")
for name in ["facade_a", "facade_b"]:
	jobs.append({"out": name + ".png", "aspect": "21:9", "size": "2K", "refs": REFS,
		"prompt": FACADE + STYLE + "Keep the leftmost and rightmost 5% free of windows, plain wall colour."})

FENCE = ("A loose hand-drawn chain-link fence as in the reference frames (see the fence in the second and third reference), on a PURE WHITE background: "
	"ONLY black ink drawn lines on white, nothing else, no colour, no shading. Hand-drawn diamond lattice with LARGE diamonds (about 6 across the picture height... "
	"each diamond roughly 12% of the picture width), wobbly uneven line weight (thick strokes next to thin ones), the lattice dropping out in places so there are "
	"irregular gaps and ragged unfinished patches (about a quarter of the area has no lines), diagonals that are NOT perfectly parallel or evenly spaced, "
	"a thick sagging top line running slightly downhill across the top edge of the picture, no posts, no perspective, flat frontal view, bold lines at least as thick as a brush stroke. ")
for name in ["fence_a", "fence_b"]:
	jobs.append({"out": name + ".png", "aspect": "16:9", "size": "2K", "refs": REFS[1:], "prompt": FENCE})
json.dump(jobs, open("jobs.json", "w"), indent=1)
print(len(jobs), "jobs")
