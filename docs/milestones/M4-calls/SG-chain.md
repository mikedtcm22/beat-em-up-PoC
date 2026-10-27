# M4 calls: SG-chain

Slice-gate fix package "chain-contract" (branch `m4/fix-slice-chain-contract`, from `m4/art-pipeline` at 0a002f3): what the chain bakes into the GLB and the atlas now matches what the toon shaders read. Three findings: slice-g2-01 (the hull normals were baked in Blender's axes), slice-g2-07 (the skin took the clothes' damage tiles) and slice-g1-05 (`run.py --from smoke` crashed). Each call is the decision, an alternative not taken, and why; part 2 is the proof that the re-export changed only COLOR_0; part 3 the numbers and what the first-person sheets show. No tunable was added (`tuning/default.json` is unchanged).

## 1. Calls

**C1. slice-g2-01: the export turns the hull normal to glTF Y-up itself; the shader is untouched.**
- *Decision.* `blender_export.write_hull_normals` encodes `(x, z, -y)` of the position-averaged smooth normal (`to_gltf_axes()`, the exporter's own mapping for POSITION and NORMAL) before `n * 0.5 + 0.5`. The module doc says "in glTF Y-up axes". `toon_outline.gdshader` is not touched: its Godot-side fixture, `test_toon` and the documented contract (ARCHITECTURE, M4-plan 2.6) already assume Y-up COLOR.
- *Alternative.* Read COLOR as `(x, z, -y)` in the shader (what the reviewer's local probe did).
- *Why not.* It would make COLOR a Blender-frame attribute that every other reader (the fixture, the tests, the next asset's author, a viewer) has to know about, and `test_toon`'s fixture would break. The exporter converts what it knows about; the one attribute it passes through is the chain's to convert.

**C2. The re-export runs from the cached steps, after a baseline that proves the cache.**
- *Decision.* `assets/source/_cache/` is gitignored, so the worktree had none; the `work/` folders of `punk`, `punk_auto` and `probe_body` were copied from the P1-chain worktree (`.worktrees/m4-p1-chain/assets/source/_cache/`; `tools/pipeline`, the palette JSON and the committed characters are unchanged since P1-chain's ef4a3f7, checked with `git diff --stat ef4a3f7 HEAD`). Before touching the code, `run.py --asset punk --only export --no-import --no-stills` was run on the old code: it reproduced `punk.glb` and `punk_rest.glb` byte for byte and the committed report hash `c0d8255da219` (only `work/punk.blend` differs: Blender's `.blend` is not byte-reproducible, so after each re-run it was either kept as the new export's or reverted). So the cache is the one the committed GLBs came from.
  - Tripo weights: `python3 -I tools/pipeline/run.py --asset punk --only export --no-import --no-stills`.
  - Auto weights, the override set read from `report_auto`'s recorded config (`assets/source/_cache/punk_auto/work/effective_pipeline.json`: only `rig.weights` and the paths differ from the Tripo run; `warp_weights` stays `tripo`): `python3 -I tools/pipeline/run.py --asset punk --only export --no-import --no-stills --set 'rig.weights="auto"' --set 'paths.work="assets/source/_cache/punk_auto/work"' --set 'paths.blend_dir="assets/source/_cache/punk_auto/blend"' --set 'paths.report="assets/source/characters/punk/report_auto"' --set 'paths.export_name="punk_auto"'`.
  - Probe fixtures: `python3 -I tools/pipeline/make_probe_body.py` (the whole chain, from the source it builds; it also shows the chain is deterministic, see part 2).
- *Alternative.* `--from export` as the brief wrote it (which also re-runs the Workbench stills), or the whole chain from the source for the Punk.
- *Why not.* `--only export` is the step that changed; the stills read the work blends, not the GLB's COLOR, so `report/stills/` and the report's informative `stills` section are kept as committed. The whole chain from the source is what `--check` does (C3), so the cached re-export is cross-checked from scratch.

**C3. The reproducibility command is `--check`, run from the source for each variant.**
- *Decision.* After the re-export, `run.py` rebuilt each asset from its source into `assets/source/_cache/check_*` and compared the report hash (the gate's pass (1), M4-plan Part A A15 and Part C section 6):
  - `python3 -I tools/pipeline/run.py --asset punk --check`: "reproducible: YES, the same report hash (committed d409e85826b3)".
  - `python3 -I tools/pipeline/run.py --asset punk --check --set 'rig.weights="auto"' --set 'paths.report="assets/source/characters/punk/report_auto"' --set 'paths.export_name="punk_auto"'`: "reproducible: YES, the same report hash (committed 145c3ecc4ce7)".
  - `python3 -I tools/pipeline/run.py --config tests/fixtures/art/probe_pipeline.json --check`: "reproducible: YES, the same report hash (committed 7ae6ca3339b4)".
  - New committed hashes (old in brackets): punk `d409e85826b3...` (`c0d8255da219`), punk_auto `145c3ecc4ce7...` (`262013f2a60a`), probe `7ae6ca3339b4...` (`3185bfc1e67c`). They moved because the GLBs' sha256 are in the hash, and because of C4.
- *Alternative.* none; the plan's `--from smoke` was never a step (C9).

**C4. The export report counts the folded triangles (slice-g2-05's optional line); geometry and decimation are not touched.**
- *Decision.* `check_glb()` also reports `folded_triangles` and `folded_share` per variant: the triangles of the written GLB whose winding opposes the mean of their three vertex NORMALs (`cross(b - a, c - a) . (n_a + n_b + n_c) < 0`, glTF is counter-clockwise), read from the file's own bytes with numpy (`folded_triangles(path)`). Measured: punk 159 (1.06% of 14,999), punk_rest 159, punk_auto 159, punk_auto_rest 160 (the reviewer's independent count was 159), probe_body 39 and probe_body_rest 35 (0.39% and 0.35%). It is a mesh-QA number for J7; fold removal stays an F-punk brief line.
- *Alternative.* Count on the authored source mesh in the `inspect` step.
- *Why not.* The brief asks for the export step's report, and the number that matters to F-punk is the shipped mesh's (the source has 30 per the reviewer; the decimation and the fist replacement add the rest).

**C5. slice-g2-07: the skin class is the atlas alpha 0.8 (not 0.75).**
- *Decision.* `shared.json` slots 6-9 carry `"skin": true`; `gen_palette.py` writes alpha 255 (1.0) for clothes marks, 204 (0.8) for skin marks, 128 (0.5) for none, and refuses `skin` without `marks`. The shader reads `takes_marks *= step(0.75, a)` (the existing literal, which `test_toon` pins) and `skin_marks = 1 - step(0.9, a)`.
- *Alternative.* 0.75, the brief's example.
- *Why not.* 0.75 sits exactly on the existing `step(0.75, ...)` edge: 8-bit 191/255 is 0.749 and would read as "no marks", 192/255 passes by 0.003. 0.8 keeps 0.05 of margin on both thresholds and leaves the pinned literal valid.
- *Check.* The atlas is byte-reproducible (two builds, the same sha256 `9ef95980ab30...`); against the old atlas only slots 6-9 changed, RGB identical, alpha 255 to 204. `pipe_common.py` does not read the alpha, so it is untouched. `test_art_contract` asserts each swatch's class from the JSON and the shader's decode of it.

**C6. `damage_skin_tex` is `hint_default_transparent`; both textures are sampled and mixed.**
- *Decision.* `uniform sampler2D damage_skin_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;` so a material nobody filled (the art's, from `ToonMaterials.art()`, which the other package owns) shows a clean skin without a default set anywhere. The fragment samples the skin triplanar next to the clothes' one and `mix`es them by `skin_marks`; `DamageLook.apply_art()` sets `damage_tex` to the clothes' tile as before and `damage_skin_tex` to `texture_for(Paint.SKIN)` (bruised, then bloodied); `prepare()` fills both slots with `VfxArt.clear_detail()` on the primitives. `toon_materials.gd`, `rig_paint.gd` and `test_art_punk.gd` are untouched (A10 reads `damage_tex`, whose clothes sequence is unchanged).
- *Alternative.* Branch on the class (`if (skin) texture(damage_skin_tex...) else ...`) to save three taps on clothes.
- *Why not.* The taps sit inside the existing `takes_marks > 0` branch; a second, data-dependent branch changes between neighbouring faces (a skin swatch beside a clothes swatch), and `texture()` derivatives inside a branch that differs within a 2x2 quad are undefined, so the mip would glitch on the border. The skin triplanar adds 3 fetches of a held 1x1 or small texture, on marked fragments only. The A16 perf rows were not re-run (the lead owns them); the shader change adds those 3 taps and nothing else.

**C7. The cap and lens swatch, the scuffed tile and the primitives are left alone.**
- *Decision.* The cap and the lenses share the `punk_yellow` swatch (`marks: true`, clothes class), so blood still lands on them; re-assigning palette slots would change the GLB's UVs and break the "only COLOR_0 changed" proof (part 2). The scuffed tile's own art (the dark teal blotches on jeans and vest) is `tools/gen_fx.gd`'s. Both are F-punk brief lines: a separate lens swatch with `marks: false`, and a scuffed tile that does not read as camouflage.
- *Alternative.* Give the lens its own slot now.
- *Why not.* As above; the brief says to leave punk.json alone.

**C8. The primitives are unchanged.**
- *Decision.* A primitive's paint is one class, so `use_albedo_tex` is false for it, `skin_marks` stays 0 and it never reads `damage_skin_tex`; `apply()` is untouched, so M3's skin paint wears the same bruised and bloodied tiles (`test_m4_contracts` line 276 still passes).

**C9. slice-g1-05: `run.py` validates `--from` and `--only` before any side effect.**
- *Decision.* After the argument loop and before the config is read, the atlas is rebuilt, the check's scratch folder is wiped or the effective config is written, a step name that is not in `STEP_NAMES` prints "unknown step 'smoke' for --from", the usage line with the eight steps (and "the reproducibility command is --check, not a step") and returns 2. A flag at the end of the line with no value ("--from") does the same instead of an `IndexError`. Confirmed: `run.py --asset punk --from smoke` exits 2, `--only nothing` exits 2, `--check --only bogus` exits 2, and no file under `assets/`, `tests/` or `tools/` is newer afterwards; `--from export` still runs.
- *Alternative.* Validate where the names are indexed.
- *Why not.* That is after `gen_palette` and the effective-config write, the order the finding names. M4-plan's text and the vertical-slice plan now cite `--check`.

**C10. Docs.** ARCHITECTURE: the run.py options paragraph (the step validation, the two `--check` commands), the asset contract's COLOR bullet (Y-up axes, the contract test), the palette atlas alpha classes, the `toon.gdshader` bullet (`damage_skin_tex`, the classes), the hull mode 4 sentence, RigPaint on toon (`set_damage_look` and `apply_art()`), the tests list. M4-plan: the hull bullet in the P1-toon brief, Part C 2.6 (palette alpha, GLB COLOR), 2.7 (toon uniforms, the outline's `n`), the P1-toon build brief's DamageLook sentence, the gate's pass (1) (`--check`); m4-plan-vertical-slice.md line 256. `M4-calls/SL-int.md` and `P1-*.md` are not edited (the lead's M4-slice-gate.md corrects "an even 3 px ink hull"); `M4-calls/README.md` is not edited either (an index row for this file is the lead's).

## 2. The proof: the re-export changed only COLOR_0

Method: each new GLB is compared with the old one (`git show 0a002f3:<path>` through LFS; copied from the working tree before the re-export, and their sha256 equal the committed reports') by parsing the GLB's JSON and BIN chunks: every accessor's bytes (POSITION, NORMAL, TEXCOORD_0/1, JOINTS_0, WEIGHTS_0, the indices, the skins' inverse bind matrices) compared one by one through the accessor and bufferView tables; the JSON chunk (nodes, skins, meshes, bufferViews, accessors with their types and counts) compared whole with COLOR_0's `min`/`max` removed; and every byte of the BIN chunk that differs located against the COLOR_0 accessors' byte ranges. Same size, same layout.

| GLB | old sha256 (12) | new sha256 (12) | COLOR_0 vectors that changed | every other accessor | JSON chunk apart from COLOR_0 min/max | BIN bytes differing outside COLOR_0 |
|---|---|---|---|---|---|---|
| punk.glb | dae40500a369 | 9525b500b60f | 17,326 of 17,326 | 7 of 7 byte-identical | identical | 0 |
| punk_rest.glb | e6aa00f1d3a9 | 20326cd0fb34 | 17,263 of 17,326 | 7 of 7 | identical | 0 |
| punk_auto.glb | 633b01eef850 | 49162f6fe5f9 | 17,338 of 17,338 | 7 of 7 | identical | 0 |
| punk_auto_rest.glb | 06b463c7685e | 8ed4c5f2cce3 | 17,275 of 17,338 | 7 of 7 | identical | 0 |
| probe_body.glb | 3bc5db67554e | 583f251d06f5 | 12,738 + 3,318 (two meshes) | 15 of 15 | identical | 0 |
| probe_body_rest.glb | 67755fea7128 | 2c110cb72af2 | 12,652 + 3,318 | 15 of 15 | identical | 0 |

The 63 (punk, 86 for the probe) vectors per mesh that did not change in the rest variants are the ones facing straight along +-X, where `(x, y, z)` and `(x, z, -y)` agree: the finding's "only +-X-facing silhouettes got the right push". The probe fixtures came out of the whole chain (`make_probe_body.py`: the source built, then inspect to stills) and still differ in COLOR_0 only, so the chain is deterministic end to end. So A6, A9, A19, the strain and the perf numbers (everything that reads POSITION, NORMAL, UV, JOINTS, WEIGHTS, the indices or the binds) stay valid on the new files; only what reads COLOR_0 (the hull) changes.

The new contract assertions (`test_hull_normals_and_the_detail_uv_are_there`, per mesh of every shipped GLB and fixture) measure, mean dot(decoded COLOR, NORMAL) as read / read as Blender Z-up `(x, z, -y)`:

| mesh | new files | old files (the assertions fail, 16 failed asserts) |
|---|---|---|
| punk.glb Body | 0.930 / 0.352 | 0.338 / 0.930 |
| punk_rest.glb Body | 0.927 / 0.357 | 0.343 / 0.927 |
| punk_auto.glb Body | 0.929 / 0.353 | 0.339 / 0.929 |
| punk_auto_rest.glb Body | 0.928 / 0.356 | 0.343 / 0.928 |
| probe_body.glb Body, Body__fp_hidden | 0.922, 0.964 / 0.320, 0.329 | 0.321, 0.312 / 0.922, 0.964 |
| probe_body_rest.glb Body, Body__fp_hidden | 0.924, 0.953 / 0.317, 0.419 | 0.319, 0.407 / 0.924, 0.953 |

(The old column is from running the new test against the old GLBs swapped back in: the bar of 0.85 fails on all eight meshes, and "beats the permuted read" fails too.)

## 3. Numbers and sheets (windowed, crowd bot, 1600x900 recordings; the stills are in `captures/fix/`, never committed)

**L1, hull width at 1, 2.5, 5 and 10 m** (C6 stills; the tool is a Godot script that scans inward from outside the figure and takes the first dark line: the top of the cap (columns across the middle of the head rect) and the left and right silhouettes (rows through the lower half of the body rect); widths at 1080p, x1.2; the half-maximum width is sub-pixel, between the line's darkest pixel and the background 4 px outside; the target is `look_outline_px` 3.75 within 1 px, never over 4.5):

| distance | family | before (SL-int c6): no ink / half-max width | after: no ink / half-max width (p10 to p90) | dark core (luma < 0.2) after |
|---|---|---|---|---|
| 1 m | cap crown | 10 of 83 scans / 1.77 | 0 of 83 / 3.61 (3.12 to 4.53) | 2.4 |
| 1 m | left side | 9 of 102 / 2.32 | 0 / 3.21 (2.80 to 5.93) | 2.4 |
| 1 m | right side | 11 of 102 / 2.07 | 5 of 102 / 2.92 (1.91 to 7.50) | 2.4 |
| 2.5 m | cap crown | 5 of 31 / 2.80 | 0 of 31 / 2.65 (2.03 to 3.30) | 3.6 |
| 2.5 m | left side | 3 of 70 / 3.46 | 0 / 3.43 (3.19 to 4.53) | 2.4 |
| 2.5 m | right side | 2 of 70 / 2.89 | 0 / 2.96 (2.70 to 5.52) | 2.4 |
| 5 m | cap crown | 5 of 18 / 1.81 | 0 of 18 / 2.46 (1.77 to 3.74) | 2.4 |
| 5 m | left side | 1 of 42 / 3.29 | 0 / 3.35 (2.79 to 4.39) | 2.4 |
| 5 m | right side | 1 of 42 / 2.94 | 0 / 3.02 (2.51 to 3.42) | 2.4 |
| 10 m | cap crown | 3 of 11 / 1.61 | 2 of 11 / 2.49 (1.69 to 3.49) | 1.2 |
| 10 m | left side | 7 of 22 / 2.38 | 4 of 22 / 2.66 (1.65 to 5.00) | 1.2 |
| 10 m | right side | 16 of 22 / 2.49 | 14 of 22 / 2.09 (1.19 to 9.36) | 1.2 |

What it says. Where the silhouette normal is mostly in X (the sides) the width was already near target and stays (2.9 to 3.4 at 1 to 5 m). The top of the cap is where it changes: the scans that found no ink at all fall from 12%, 16%, 28% and 27% to 0, 0, 0 and 18% (10 m: two of eleven columns, a 55 px head), and the median width goes from 1.6-1.8 to 2.5-3.6. At 2.5, 5 and 10 m the crown reads 2.65, 2.46 and 2.49 at 1080p, 0.1 to 0.3 under the 2.75 floor of the plan's tolerance by this half-maximum measure (the dark core is 2.4 to 3.6; the hull's own width is `look_outline_px` before the grade, the hull's antialiased rim and the fog); nothing is over 4.5 except single scans at the p90 (a glove or sleeve edge meeting the hull). The right side at 10 m has no ink in 14 of 22 rows because the figure is 55 px wide and the scan's outer end lands on the lit wall: the sample is noise, not a finding. L1 is a soft row: reported, not tuned (the width tunable is F-look's).

**What the sheets show** (full-resolution stills and 2x crops, C1, C2, C4, C6 against SL-int's of the same frames):
- C1/C6 1 m: the ink is continuous over the cap's crown and brim, one line, an even width along it, no gap where the crown is flat to the camera (before, the sky ran straight into the yellow there); the chin, nose and collar lines are unchanged.
- C2 1 m, the forearm and elbow bottoms: vertical scans through ten columns across the left forearm's bottom and the right elbow's bottom show ink in all ten (minimum luma 0.07 to 0.12, runs of 1 to 3 px at 1600x900, most 2), against five of ten with none before (minimum luma 0.21 to 0.36).
- C4 (jab, cross, shove) and C6 at 2.5 m: the vest, jeans, sleeves and gloves are outlined all round, with no doubled line anywhere the edge pass could add its own (the crown, the shoulders, the elbows), and no hull poking through the body.

**Damage on skin (C5, the damage-looks act, 100 / 65 / 30%, then hits)**, 1 m, against SL-int's and M3's frames:
- 100%: unchanged, a clean pink skin (the skin class changes nothing when the tiles are clear).
- 65% (bruised): the face and both arms take purple bruises (the M3 skin tile), the vest, tee and jeans take the dark teal scuffs (M3's clothes tile, unchanged; they still read as a mottled pattern, which is the tile's art, C7), no grey on the skin.
- 30% (bloodied): the face and arms take the skin's bloodied tile: red splats over a purple-pink wash, where SL-int's frame had a translucent grey with dark smudges. The vest, tee and jeans keep the clothes' blood. The cap and the lenses still take clothes-density splats (they share the clothes swatch, C7); the right forearm (the cream sleeve, a clothes swatch) shows the scuffed or bloody clothes tile, as before. The skin's bloodied tile has a translucent purple wash, so the skin at 30% reads lilac and slightly glassy rather than opaque as on M3's flat paint: that is the tile's alpha (`tools/gen_fx.gd`), the lead's call or F-punk's.
- The act ends in the KO and blink-off as before; no SHADER ERROR in the log.

## 4. For the lead

- Gate pass (1) is the three `--check` lines in C3.
- The fold counts (C4) go in the J7 mesh-QA line: 159 / 159 / 159 / 160 on the four Punk GLBs.
- F-punk brief lines this package leaves open: a separate lens swatch with `marks: false` and a thinner cap mark (C7); the scuffed tile's art; folds removed in the chain (the decimation or the fist replacement adds about 130 to the source's 30).
- `tuning/default.json` needs no regeneration (no tunable was added).
