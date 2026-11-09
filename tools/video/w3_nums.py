"""Print edge density, dark share and the darkest third's grey share from style_meter --json files (LD-WORLD3 helper): w3_nums.py <json> ..."""
import json, sys
for path in sys.argv[1:]:
	data = json.load(open(path))
	for name, fr in data["frames"].items():
		v = {d["key"]: d["value"] for d in fr["detail"]}
		print("%-34s L*%.1f dark %.2f grey3 %.2f edge %.3f ink %.3f score %.2f" % (path.split("/")[-1][:34], v.get("L_mean", 0), v.get("frac_dark", 0), v.get("dark_frac_grey", 0), v.get("edge_density", 0), v.get("ink_frac", 0), fr["score"]))
