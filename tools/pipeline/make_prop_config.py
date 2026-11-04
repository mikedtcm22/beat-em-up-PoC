"""Write assets/source/props/<id>/pipeline.json for a static prop (M6 PROPS): python3 -I tools/pipeline/make_prop_config.py <id>
Keeps the table of the props' settings in one place; the json it writes is what run.py --kind prop reads (and is committed)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

# slots: shared 1 near_black, 2 dark_grey, 3 mid_grey, 4 light_grey, 10 steel, 14 cream; props 60 car_orange, 61 dumpster_green,
# 62 tank_blue, 63 rust_brown; weapons 28 chain_steel, 29 padlock_brass, 30 grip_tape, 31 pipe_paint.
PROPS = {
	"pipe": {
		"note": "The pipe weapon, scripted in Blender (prop_models.pipe, no Tripo): a painted tube with dark caps, a wrapped grip near the -Y end and two rings, 0.85 m long, centred, long axis +Y in the weapon art frame.",
		"builder": "pipe",
		"builder_args": {"length": 0.85, "radius": 0.032},
		"orient": {},
		"target": {"origin": "keep"},
		"palette": {"slots": [31, 2, 1, 63], "max_swatches": 4, "min_share": 0.0, "budget_tris": 1000},
		"export": {"mesh_name": "Pipe", "smooth_angle_deg": 35.0},
	},
	"bike_chain": {
		"note": "The bike chain (weapon A of M6: Lock, Grip, Link). The padlock, weapon_a.jpg): Tripo image-to-model from ref.jpg, turned shackle toward the grip and body toward the free end, 0.15 m, centred at 0.35 m on the weapon's Y axis; the Grip and the Link are scripted parts.",
		"mesh": "assets/source/props/bike_chain/tripo/270451cc_gen.glb",
		"orient": {"rotate_x_deg": 180.0, "yaw_deg": 90.0},
		"target": {"axis": "y", "size_m": 0.15, "origin": "center", "offset_m": [0.0, 0.35, 0.0]},
		"palette": {"slots": [29, 10, 1], "max_swatches": 3, "min_share": 0.01, "budget_tris": 1500, "border_cell_m": 0.012},
		"export": {"mesh_name": "Lock", "smooth_angle_deg": 60.0, "parts": [
			{"name": "Grip", "builder": "bike_grip", "args": {"z0": -0.425, "length": 0.22}, "offset_m": [0.0, 0.0, 0.0]},
			{"name": "Link", "builder": "bike_link", "args": {}, "offset_m": [0.0, 0.0, 0.0]}]},
	},
	"car": {
		"note": "A parked late-1970s sedan, rust-orange, from Tripo; long axis X, the nose toward +X, wheels on the floor (origin at the base centre); the barrier car and the crowd street's car draw it.",
		"mesh": "assets/source/props/car/tripo/d0e6fac3_gen.glb",
		"orient": {"yaw_deg": -45.0},
		"target": {"dims_m": {"x": 4.2, "y": 1.5, "z": 1.9}, "origin": "base_center"},
		"palette": {"slots": [60, 63, 1, 2, 4, 14, 10], "max_swatches": 6, "min_share": 0.002, "budget_tris": 2800, "border_cell_m": 0.05},
		"export": {"mesh_name": "Car", "smooth_normals": {"iterations": 12, "crease_deg": 50.0, "falloff": 2.0}, "smooth_angle_deg": 75.0},
	},
	"dumpster": {
		"note": "A steel street dumpster, dark green with rust at the corners, from Tripo; long axis X, origin at the base centre, stretched to the pinned 2.0 x 1.3 x 1.0 box (the generated one is deeper); the crowd street's dumpster and the street's PropSpots draw it.",
		"mesh": "assets/source/props/dumpster/tripo/651a6569_gen.glb",
		"orient": {"yaw_deg": 45.0},
		"target": {"dims_m": {"x": 2.0, "y": 1.3, "z": 1.0}, "origin": "base_center"},
		"palette": {"slots": [61, 63, 2, 1, 4], "max_swatches": 5, "min_share": 0.01, "budget_tris": 2800, "border_cell_m": 0.04},
		"export": {"mesh_name": "Dumpster", "smooth_angle_deg": 60.0},
	},
	"ac_unit": {
		"note": "A rooftop air-conditioning condenser, grey with a few rust stains, from Tripo; long axis X, origin at the base centre, stretched to a 1.0 x 0.7 x 0.7 box (the pinned box is 0.8 high; the generated unit is flatter, 0.7 reads as a unit on its feet).",
		"mesh": "assets/source/props/ac_unit/tripo/6b76be5c_gen.glb",
		"orient": {"yaw_deg": 45.0},
		"target": {"dims_m": {"x": 1.0, "y": 0.7, "z": 0.7}, "origin": "base_center"},
		"palette": {"slots": [4, 3, 63, 1, 2], "max_swatches": 5, "min_share": 0.01, "budget_tris": 3000, "border_cell_m": 0.04},
		"export": {"mesh_name": "AcUnit", "smooth_angle_deg": 60.0},
	},
	"water_tank": {
		"note": "A rooftop water tank on four braced legs, blue-grey steel with rust bands, from Tripo; rotationally symmetric, origin at the base centre, stretched to the pinned 2.0 x 2.6 x 2.0 box (the roof's tanks and the boss roof's skyline draw it).",
		"mesh": "assets/source/props/water_tank/tripo/6353938e_gen.glb",
		"orient": {"yaw_deg": 0.0},
		"target": {"dims_m": {"x": 2.0, "y": 2.6, "z": 2.0}, "origin": "base_center"},
		"palette": {"slots": [62, 63, 2], "max_swatches": 3, "min_share": 0.01, "budget_tris": 3000, "border_cell_m": 0.12},
		"export": {"mesh_name": "WaterTank", "smooth_normals": {"iterations": 12, "crease_deg": 50.0, "falloff": 2.0}, "smooth_angle_deg": 80.0},
	},
}


def main(argv):
	if len(argv) != 1 or argv[0] not in PROPS:
		print("usage: make_prop_config.py <%s>" % "|".join(PROPS))
		return 2
	key = argv[0]
	p = PROPS[key]
	pal = dict(p["palette"], majority_passes=p["palette"].get("majority_passes", 2), armature=False, unfold={"iterations": 12, "factor": 0.5, "ring": 1})
	cfg = {
		"id": key, "kind": "prop", "version": 1, "note": p["note"],
		"source": {"mesh": p["mesh"]} if "mesh" in p else {"builder": p["builder"], "builder_args": p.get("builder_args", {})},
		"orient": p["orient"], "target": p["target"], "palette": pal, "export": p["export"],
		"paths": {
			"work": "assets/source/_cache/%s/work" % key,
			"blend_dir": "assets/source/_cache/%s/work" % key,
			"report": "assets/source/props/%s/report" % key,
			"export_dir": "assets/export/props/%s" % key,
			"export_name": key,
		},
	}
	out = os.path.join(REPO, "assets", "source", "props", key, "pipeline.json")
	os.makedirs(os.path.dirname(out), exist_ok=True)
	with open(out, "w") as f:
		json.dump(cfg, f, indent="\t")
		f.write("\n")
	print("wrote " + os.path.relpath(out, REPO))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
