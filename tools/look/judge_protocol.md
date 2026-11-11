# Blind look judge: "does it read as drawn" (M7 gates)

A repeatable measurement. The judge is a model (or person) that has not seen the key.

## Set-up
1. Frame set: fixed per gate. The baseline set (25 trailer frames, 8 reference stills, 9 M6 tiles) is built by `tools/look/build_baseline.sh <work_dir>`. A gate set is the same frames re-captured, plus the reference groups, so the bar and the candidate sit in one shuffle. Candidate frames must be native resolution (no HUD crops, no debug text).
2. `SEED=<n> tools/look/make_judge_set.sh <out> <dir>...` re-encodes everything to 960x540 JPEG (ffmpeg q:v 5), shuffles with a fixed seed, writes `j_NN.jpg` and `key.json`. Three runs, seeds 101, 202, 303.
3. `python3 -I tools/look/judge_sheets.py <out> 6` writes contact sheets of at most 6, labelled by id only.
4. The judge must NOT open `key.json`, the input dirs, or any path with a group name.

## Judge prompt (fixed)
> You are shown shuffled, unlabelled stills, all at the same size and JPEG quality. For each, give p_3d: 0 = hand-drawn 2D animation, 1 = real-time 3D render. Judge only what is in the frame. For each frame also list its top tells (at most three), strongest first. Tells to look for: mechanical repetition (tiled brick, window rows, chain-link in exact perspective), ruler-clean outlines, smooth bloom or Gaussian haze, depth-exact fog, flat texture-mapped faces, shadow-map terminators, identical copies of one model, constant-width rim light, pixel-sharp vs. streaming softness. Output JSON {"j_01": p_3d, ...} and, per frame, the tells.

## Scoring
Three runs, each judged on a fresh shuffle. Per image: median p_3d over the 3 runs. Per group: median of those, and the spread (min to max of the per-image medians). Run `python3 -I tools/look/score_judge.py run1/key.json run1/judged.json run2/key.json ...`.
Also run the style meter: `~/.venvs/beat-em-up-video/bin/python -I tools/look/group_meter.py <dir>...`.

## Reading it
The gate is the trailer group's median and spread (see baseline.md). A candidate passes when its median is inside the trailer's spread; a median above the trailer's max is not a pass, however the style meter looks.
