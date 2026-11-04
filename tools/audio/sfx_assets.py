"""Write the "Sound effects (ElevenLabs)" rows of ASSETS.md (Milestone 6, package SFX).

Usage: python3 -I tools/audio/sfx_assets.py

`ingest.py --assets` writes the voices' section; this writes the other one, from the same manifest and
ledger: a row per shipped wav whose source is an ElevenLabs take and whose pool is not a voice, in the same
form, and it drops the placeholder rows of files the manifest no longer calls `gen_sfx`. It reuses ingest.py's
row writer, so the two sections read alike.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ingest  # noqa: E402  (a sibling tool; -I does not put the script's folder on the path by itself)

HEADING = "### › Sound effects (ElevenLabs)"
INTRO = ("Every generated sound effect that is not a voice (the hit stack, the blocks, the barriers, the weapons, "
	"the GO and CLEAR stings and the two ambience beds), from the ElevenLabs sound-effects API on the Starter plan "
	"(commercial licence: ElevenLabs sound-effects API (Starter, commercial licence)), with its ledger id. "
	"16-bit mono 44.1 kHz WAV in Git LFS, rebuilt from the MP3 takes by `tools/audio/ingest.py` (`--check` proves it) "
	"and chosen among three or four candidates per prompt by `tools/audio/sfx_pick.py` (measured features; the ear is "
	"Game-boy's, in the audition room). Source takes, every candidate: `assets/source/sfx/eleven/sfx_hits/`, "
	"`sfx_blocks/`, `sfx_barriers/`, `sfx_weapons/`, `sfx_stings/` and `sfx_beds/` (Git LFS), the jobs files "
	"(`sfx_<group>.jobs.json`) and the picks (`sfx.picks.json`) beside them; the ledger is "
	"`assets/source/sfx/eleven_ledger.jsonl`. The music loop stays the Milestone 2 placeholder (plan D25).")


def main():
	manifest = ingest.load_manifest()
	ledger = ingest.load_ledger()
	with open(ingest.ASSETS_MD) as f:
		lines = f.read().split("\n")
	gen_files = {r["file"] for r in manifest["files"] if r["source"] == "gen_sfx"}
	kept = []
	for line in lines:
		m = re.search(r"`assets/export/sfx/([a-z_0-9]+\.wav)`", line)
		if m and "Procedurally generated" in line and m.group(1) not in gen_files:
			continue
		kept.append(line)
	lines = kept
	rows = [r for r in manifest["files"] if r["source"].startswith("elevenlabs:") and not ingest.VOICE_POOLS.match(r["pool"])]
	table = ["", INTRO, "", "| Asset | Path | Source / service | License | Notes |", "| --- | --- | --- | --- | --- |"]
	table += [ingest.assets_row(r, ledger.get(r["source"].split(":", 1)[1])) for r in sorted(rows, key=lambda r: r["file"])]
	table.append("")
	a, b = ingest.region(lines, HEADING)
	lines[a:b] = table
	with open(ingest.ASSETS_MD, "w") as f:
		f.write("\n".join(lines))
	print("ASSETS.md: %d sound-effect rows written" % len(rows))
	return 0


if __name__ == "__main__":
	sys.exit(main())
