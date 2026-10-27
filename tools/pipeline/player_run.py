"""The player's chain driver (M4 package F-player-art): run.py with the player's own part and detail steps.

	python3 -I tools/pipeline/player_run.py --asset player            every step, then the Godot import
	python3 -I tools/pipeline/player_run.py --asset player --check    rebuild into a scratch folder and compare the report hash
	python3 -I tools/pipeline/player_run.py --asset player --only parts_replace

It takes run.py's options, steps and report as they are (the shared driver is F-punk's and is not edited) and swaps in
tools/pipeline/player_parts.py for blender_parts.py (the generated fists, the first-person split with an optional belly mesh),
then adds the step `detail` (player_detail.py: the 1k ink mask on UV2) after parts_split. Everything hero-specific lives in
assets/source/characters/<id>/pipeline.json, so a second hero is another folder and this same command.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run as shared  # noqa: E402


def player_steps():
	out = []
	for name, script, extra in shared.STEPS:
		out.append((name, "player_parts.py" if script == "blender_parts.py" else script, extra))
		if name == "parts_split":
			out.append(("detail", "player_detail.py", []))
	return out


MASK_PARAMS = {"compress/mode": "0", "mipmaps/generate": "true", "process/fix_alpha_border": "false", "process/premult_alpha": "false",
	"detect_3d/compress_to": "0"}


def ensure_mask_import(asset):
	"""The detail mask is read as data (R = ink), never VRAM-compressed: set its .import after Godot has written it."""
	cfg = shared.pc.load_config(os.path.join(shared.pc.REPO, "assets", "source", "characters", asset, "pipeline.json"))
	mask = os.path.join(shared.pc.cfg_dir(cfg, "export_dir"), cfg.get("detail", {}).get("name", "player_detail.png"))
	if not os.path.exists(mask):
		return
	if not os.path.exists(mask + ".import"):
		shared.godot_import()
	if os.path.exists(mask + ".import") and shared.patch_import(mask + ".import", MASK_PARAMS):
		shared.godot_import()


if __name__ == "__main__":
	shared.STEPS = player_steps()
	shared.STEP_NAMES = [s[0] for s in shared.STEPS]
	argv = sys.argv[1:]
	code = shared.main(argv)
	if code == 0 and "--check" not in argv and "--no-import" not in argv and "--asset" in argv:
		ensure_mask_import(argv[argv.index("--asset") + 1])
	sys.exit(code)
