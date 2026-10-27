# M4 calls: P1-tools

Judgement calls of the P1-tools package, first launch (A2 steps 1-2: `tripo.py` and `blender_dump_rig.py`; no credits spent). Each: the decision, an alternative not taken, and why. Steps 3-4 (the mannequin renders and the smoke Punk T1-T3) append to this file in the second launch.

## tripo.py

1. **The v3 API at `https://openapi.tripo3d.ai/v3`, not the v2 route the handoff cites.**
   - *Alternative:* `https://api.tripo3d.ai/v2/openapi` (it still answers today).
   - *Why not:* v2 shuts down on 2026-10-31, and the codemap measured that our key is a global-account key (the `.com` hosts return 401). A live `GET /account/balance` through the script returned 1500.00, frozen 0.00. The only live calls made by this package so far are free balance reads.

2. **Every task command is one run: create, poll, download, ledger.** `wait <task_id>` resumes one that timed out.
   - *Alternative:* separate `create`, `status` and `download` commands.
   - *Why not:* the output URLs live 5 minutes, so a download left to a later command can lose the files. A task that is `created` but not `finished` in the ledger counts at its expected cost, so a crash never hides spend.

3. **The ledger has two events per task (`created` right after the POST, `finished` with the real `credits_consumed`), and `upload` lines.**
   - *Alternative:* one line per task, written at the end, as A10's sentence reads.
   - *Why not:* a process killed between the POST and the final line would leave a paid task out of the 750 sum. `finished` is the line A10 describes; `created` is the safety net. Uploads are logged for traceability and cost nothing in the sum.

4. **The 750 stop uses `max(ledger sum, start balance - live balance)`, and the 700 floor uses `balance - frozen`.**
   - *Alternative:* the ledger sum alone (A10 literally) and the plain balance.
   - *Why not:* P1-tools, P1-chain's later runs, F-punk and F-player each work in their own worktree with their own copy of the ledger, so one ledger cannot see another's spend. The live balance can. Subtracting `frozen` is conservative if the API's `balance` already excludes it (it only blocks when tasks run at once).

5. **The policy (floor 700, stop 750, start 1500) lives in `tripo_prices.json`, and no flag loosens it.**
   - *Alternative:* `--floor` and `--stop` options.
   - *Why not:* "past 750 the lead asks Game-boy" is a rule a builder must not be able to switch off. The lead edits the JSON if Game-boy agrees.

6. **Strict options.** Unknown keys, wrong types, values outside an enum and combinations the API rejects (`fast` without texture v3.5, `generate_parts` with texture, v3 options on model v2.5, `unity` on rig v1.0, P-series keys) are refused before any call.
   - *Alternative:* pass everything through and let the API answer 1004.
   - *Why not:* a typo like `textur` would silently change the price; a 1004 comes after the request left. The sets are from the codemap section 2.4 and the raw doc pages.

7. **`rig` always sends `model v3.0-20260909, rig_type biped, spec unity, out_format glb`** unless overridden. The API's own default model is v1.0, which fails `unity`. *Alternative:* send only what the user gave. *Why not:* a forgotten `--opt model=` would give v1.0 and Tripo-native bone names, the opposite of plan section 10's T3.

8. **Request shapes:** `input` is a plain string (a task id, file token or URL), as the raw v3 doc pages show; multiview `inputs` is a view-keyed array of `{"front": "<file_token>"}` objects.
   - *Alternative:* the object forms `{"file_token": ...}`.
   - *Why not:* the doc examples use plain strings for both. This is verified only against the docs, so **the first live call (T1) is also the check of the body shape**; `--dry-run` prints the exact body to compare.

9. **Unpriced assumptions are flagged, not blocked.** Texture v3.5's price on generation and on `/models/texture`, and uploads, are not in the pricing table; the table treats v3.5 as its quality tier (30 on generation) and the output says `UNVERIFIED PRICE`. *Alternative:* refuse them. *Why not:* T1 exists to read v3.5's real cost (plan section 10), and the guard still holds (750 is 50 under the 800 allowance).

10. **The download folder is new or empty, inside the repo, default `assets/source/_cache/tripo/<task_id>/`.** *Alternative:* write straight into `assets/source/characters/<id>/tripo/` as Part C section 2.6 draws it. *Why not:* A10 says a new empty folder per task for untrusted downloads; the chain copies an accepted GLB up to `characters/<id>/tripo/<task8>_gen.glb`. Only known output keys are fetched, https only, redirects to http refused, 200 MB cap, and file names are built by the script (never taken from the URL).

11. **`.env` lookup:** the environment, then this checkout's `.env`, then (in a linked worktree) the main checkout's, found by reading the worktree's `.git` file. *Alternative:* symlink `.env` into each worktree. *Why not:* a secret-bearing file in the tree is exactly what the key grep is there to catch; reading the main checkout's file does not write the key anywhere.

12. **A paid run requires `--label`** (the brief's row, T1 and so on). *Alternative:* optional. *Why not:* the ledger is read by the lead against section 10's table; unlabeled lines cannot be mapped. The label is checked before anything is uploaded.

## blender_dump_rig.py

13. **Everything is reported in Godot space** (`(x, y, z)` Blender becomes `(x, z, -y)`, after every object's transform). *Alternative:* Blender space. *Why not:* the joint table, the rig and the contract are all Godot space; a Tripo file may carry a scale or a rotation on its armature, and reading `head_local` raw would hide it.

14. **Tails are reported but marked as the importer's guess.** glTF has no tail; Blender invents them (`bone_heuristic BLENDER`, recorded in `import`). The joints that matter are heads, parents and names.

15. **Facing: toe primary, the head as the cross-check by reach.**
    - *First attempt, dropped:* the nose as the mean offset of the head's farthest points from the head's mean. On the test head (a box with a nose) it picked the back corner, because the mean is pulled toward the vertex-dense nose and a box corner is far from any centre.
    - *Landed:* the head's reach in front of and behind the torso's axis along the toe direction (nose 0.21 m versus skull 0.11 m in the test). The toe is a stronger signal (the footprint's long axis, signed toward the end that reaches further from the shin) and the head only confirms or contradicts it: `confidence` is `high`, `weak`, `conflict` (behind exceeds in front by 15%), `toe_only` or `none`.
    - *Known limit:* a head with a long ponytail or a big back hat can read `weak`; the pipeline's `facing_yaw_deg` override exists for that.

16. **`neutral_bone` is surfaced in `summary`.** Found while building the test: Blender's own glTF exporter adds a `neutral_bone` when any vertex has no weight (the codemap had only seen Godot's importer do it). The contract forbids it, so P1-chain's checks can read `summary.neutral_bone` instead of rediscovering it.

17. **The self-test builds its GLB in-process rather than committing a fixture.** *Alternative:* a committed `.glb` under `tests/fixtures/art/`. *Why not:* P1-chain owns that folder, a binary needs LFS, and a script that can rebuild the truth is a stronger test (the authored joints, weights and facing are the expected answers; the `.blend` input path proves the unweighted count that the GLB export hides).

18. **`dominant_colors` are "as stored", each channel rounded to 16 levels** (`rgb_hex_16_levels`). *Alternative:* convert from sRGB to linear or back. *Why not:* the point is to see how few flat colours a Tripo texture has; exact values are not needed and colour management of `image.pixels` is not worth guessing.

## Process notes

19. **A command that would have created a paid task was blocked, and nothing ran.** While testing the CLI's refusal paths I typed a batch whose first line was `image-to-model --label T1 ...` without `--dry-run` (I meant to check the label refusal and passed a label). The permission classifier denied the whole batch before it ran. No task was created: `tripo.py ledger --live` afterwards reads "ledger spend 0.00; account spend 0.00 (balance 1500.00): reconciled". After that, only `--dry-run` task commands and the mock self-test were run. The refusal paths (no label, a non-empty `--out-dir`, the floor, the stop) are covered by `--self-test` on the mock service.

# Second launch (steps 3-4)

## tripo.py: the second key

20. **A paid run needs `--spend <credits>` equal to the price table's expected cost for that exact request, and rig-check needs `--spend 0`.** The check (`check_spend`) runs in `cmd_task` before anything is uploaded and again at the top of `Tripo.run`, so a label alone never spends, a stale number never spends (a different `--spend` is refused, `nan` included), and neither the CLI nor a script calling `run()` can skip it.
    - *Alternative:* require it only for calls with a cost above 0 (the lead's wording: "a paid call"). *Why not:* the table could be wrong about the free call too, and one rule for every task-creating command is simpler to remember and to test; `--dry-run` prints the exact flag to add.
    - *Alternative:* a `--yes` flag. *Why not:* a flag with no value can be typed from habit; a number has to be read off the dry run and compared with the brief's budget row.
    - The self-test now covers: no `--spend`, below, above, zero on a paid task, `nan`, the CLI path with a real-looking image (no network call, no upload, no task), and the dry-run hint.

## The mannequin (step 3)

21. **Built from the placeholder's own enemy parts, with the torso as one loft.**
    - *First try:* every box, capsule, sphere and cylinder of `parts_enemy` at its bone offset, posed. *Seen:* the torso read as stacked slabs with creases a look-alike drawing would copy as belts and folds, and the open-hand ellipsoids as spikes.
    - *Landed:* the arms, legs, head, neck, shoulders, traps, shoes from the table; pelvis to upper chest as one superellipse loft through each box's width and depth at its centre height (so the waist and the shoulders are the table's, smoothly blended); the two hands as flattened capsules with a thumb (A13: open hands); a small nose so the left view shows which way it faces; everything melted by a voxel remesh and smoothed. *Alternative:* a hand-sculpted generic mannequin. *Why not:* the art must fill the rig's volumes, and these are the rig's volumes.
22. **The mannequin is mid-grey (#b0b0b0 before Workbench shading) on a flat #d9d9d9 background.** Part C writes "flat #d9d9d9" once for the mannequin and once for the Gemini re-render's background; reading it as the background of both keeps the reference and the output on the same ground, and a grey figure on it shows its form. *Alternative:* a #d9d9d9 mannequin. *Why not:* the figure and the ground would merge.
23. **The background is exactly #d9d9d9 (217,217,217).** Blender writes 216 for the linear value of 217 (it truncates the encoded byte), so the world colour is aimed half a level high, and `mannequin_report.json` checks the four borders of every PNG against the configured grey. Dither is off (it speckled the background).
24. **The A-pose swing is 45 degrees from hanging, which is 45 below horizontal** (the concepts asked for about 40; Part C asks for 45). Only the two upper arms rotate about Z; the forearm and hand continue straight; the legs stay parallel. The report carries every bone head in rig space and in pixels per view, so A3's chained-joint rule (each exported joint is the table joint chained through the swing) can be checked against the same numbers.
25. **Views: front, left, back, 1536x2048, orthographic, 952.56 pixels per metre.** The left view shows the character's own left side and it faces the image's left; the front view puts the character's own right on the image's left. Which side Tripo calls "left" is the unknown the smoke measures, not something the mannequin can settle. 2048 is the 3:4 "2K" at its long side (Gemini answered 1792x2400 to the same request for the concepts; the aspect is what matters).
26. **Pixel hashes, not file hashes, identify the renders.** The PNG container's bytes differ between runs of the same scene; the decoded pixels do not (two runs, identical report).
