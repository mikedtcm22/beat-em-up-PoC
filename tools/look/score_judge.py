"""Score judge runs: python3 -I tools/look/score_judge.py <key.json> <judgement.json> [<key.json> <judgement.json> ...]
A judgement file is {"j_01": p_3d, ...} for the key beside it. One key/judgement pair per run (shuffles differ).
Per image: median p_3d over runs, keyed by source file. Per group: median of those, min, max."""
import json, statistics, sys
per = {}
a = sys.argv[1:]
for k, j in zip(a[0::2], a[1::2]):
	key, jd = json.load(open(k)), json.load(open(j))
	for jid, p in jd.items():
		e = key[jid]
		per.setdefault((e["group"], e["src"]), []).append(float(p))
groups = {}
for (g, src), ps in sorted(per.items()):
	groups.setdefault(g, []).append((statistics.median(ps), src))
for g, v in groups.items():
	m = [x for x, _ in v]
	print(f"{g}: n={len(m)} median={statistics.median(m):.2f} min={min(m):.2f} max={max(m):.2f}")
	for x, s in v:
		print(f"   {x:.2f}  {s}")
