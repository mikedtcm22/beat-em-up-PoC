# M4 slice gate

Written by the lead on 2026-10-27 from the gate's review round (A15), run as `docs/reviews/M4/workflow-review.js`, round "slice", run `wf_36e8400a-165`. The base is `59a0adf`: every phase-1 package plus SL-int, green at 1378/1378. The full output is in `docs/reviews/M4/slice-result.json`.

- **The lenses.**
  - G1 (Opus): mechanics and contract.
  - G2 (Opus): deformation and look at 1 m in first person.
- **Checking.** Each of the 16 findings was checked by one Sonnet skeptic, and 10 survive.
- **Fixes.** At most two Sonnet fix packages run (see "Fixes made").
- **What was judged.** This is the smoke Punk, concept A, because Game-boy has not picked yet. So the gate judged the **chain** and what the real Punk will inherit from it, not the smoke asset's design.

## Verdict: (b) proven, with a contingency

Both lenses returned (b). Phase 2 uses the locked chain below, with these contingencies:

1. **Precondition: the hull-normal axis fix.** It must land before F-punk or F-player-art exports anything. This is the gate's fix package `chain-contract`.
2. **A18's Punk detail mask.** F-punk adds the 1k ink-only mask on UV2. A18's trigger is met: the concept's mouth, pocket flaps, buttons, stitching and tape edges are gone at 1 m. The mask departs from SPEC §10's asset table, so it goes into README's M4 departures for Game-boy's ruling.
3. **A girth clamp in `blender_fit`, only if A6 misses on the real Punk.** The test is torso, legs and head at least 95% inside their hurtbox + 6 cm, plus the art-drawn lens-distance rules below. The clamp is radial toward the bone axis, applied past the hurtbox radius + slack, before decimation.
4. **Weight smoothing and clamps at the shoulder, collar and waist, only if F-punk's visible-stretch test fails.** The test: no edge in an FP-visible cell grows by more than 2 cm in the 1 m acts' poses. Turn on `rig.smooth_iterations`, `smooth_factor` and the named clamps. If smoothing on the Tripo weights still fails, switch to `auto`.

Why not (a): two defects that the real Punk and the player would both inherit show in first person at 1 m. The hull ink is missing on every top and bottom silhouette, and the interior detail is lost. Why not (c): the chain works end to end, both defects have local, cheap fixes, and no credit or re-plan is needed.

## Pass items (Part C §6, as amended by A15)

| Item | Result | Evidence |
| --- | --- | --- |
| 1. Reproducible | **Pass** | `python3 -I tools/pipeline/run.py --asset punk --check` prints "reproducible: YES" (report hash `c0d8255d`) in 11 s. The heat-map variant (`--set rig.weights="auto" --set paths.report=… --set paths.export_name="punk_auto"`) gives YES `262013f2`. No step imports a network module. The plan's literal `--from smoke` crashed, because "smoke" is not a step; `--check` is the command (fixed by `chain-contract`). |
| 1. Ledger | **Pass** | 3 tasks, 55 credits, balance 1500 to 1445. Every `balance_after` equals the next `balance_before`. |
| 2. Contract | **Pass** | test_art_contract 15/15, test_skinned_art 41/41 and test_art_punk 14/14. `check()` is empty on all four GLBs, with 14,999 triangles each. Joints sit 0.0005 mm off the chained table. There is no `neutral_bone`. |
| 3. Mechanics with the art | **Pass** | It fights in both rooms. The flash shows for exactly 2 frames on the struck spot (C5 frames 44-45, C11 frames 68-69). Marks stick (A10). In a real StreetPunk through hitstun, stagger, launch, downed, get-up and KO, the skeleton equals the followers to 0.0000 m. The KO view shows the art for 139 frames, then blinks off cleanly. No art vertex comes inside the 5 cm near plane during a hold. |
| 3. Proxy honesty (L5) | **Pass, with an instrument fix** | With the art drawn, R8 agrees with the proxies within 0.5 pp at p50 and 2 pp at p95 ("Six Punks, fight" and "Mixed six, fight"). R4 reads 0 of 14 either way, but only by luck: its occluder test could not see an art Punk (fixed by `drawn-art-instruments`). |
| 4. The look chain on the real asset | **Pass, after the axis fix** | Shadows are tinted and never black (darkest fill luma 27 against ink 16). Palette borders are clean at 1 m (R5 does not happen). There is no doubled silhouette with the edge pass; the lapel's double line is hull on hull. The grade is on. The hull is on target where its normals are right (3.6 px at 1080p on the head side at 1 m), but it is **missing on top and bottom silhouettes** (the axis bug). The front at 1 m reads as **one violet band** (F-look's first brief line). |
| 5. The perf delta | **Measured** | The lead's run (vsync on; load 2.4-4.6 from other apps, so noisy in absolute terms, but the refs were interleaved). "Perf, six with ragdolls": M3 mean 12.10 ms against M4 14.53 (+2.4), p95 +3.4, spawn hitch +2.9. First spawn (+1.0) and first hit (+1.4) are within A16's +2 ms. M3 itself misses the 16.7 ms p95 bar on this machine. Logs are in `captures/perf_compare/a16/` (local). |

**Correction.** SL-int's §4 claims "an even 3 px ink hull" and "2-3 crisp bands". Neither is supported by the pixels: the top and bottom silhouettes have no hull, and one band dominates the vest, cap and face at 1 m.

## Locked choices

| Choice | Locked | Alternative not taken, and why |
| --- | --- | --- |
| Bind route (A3) | **The A-pose route**: `punk.glb`, bound by SkinnedArt's chained formula | The arms-down bake (`punk_rest.glb`). The two are mechanically identical: the same A6, A9 and A11, and `check()` passes both. The A-pose route is A3's spec route and is better or equal at the poses the game shows (guard, raised arms). The bake wins only at the rest pose, which the player never sees. It stays behind `look_punk_art_variant=1`. |
| Weights source | **`tripo`** (Tripo's auto-rig weights) | `auto` (Blender heat-map weights). Game-boy's order is Tripo first. The A/B can't be told apart at 1 m, and the numbers split (tripo is better at the arm raise, auto at the staggers). Switch only if smoothing on the Tripo weights fails F-punk's visible-stretch test. |
| Fit | **The landmark-warp fit onto the chained table**, keeping the art's bulk | Slim the art to the proxies, or widen the proxies. Slimming loses the concept's chunk (J1). Widening moves M3's tuned lens shares and view rules (A4). The girth clamp is contingency 3. |
| A3 landmark residual | **Reported, not failed**: 2.35 cm at UpperChest against the 1 cm bar | Hold the bar and re-fit now. The residual moves the art's surface about 2 cm, against 4-6 cm of mechanical slack, and has no mechanical effect. F-punk targets 1 cm or less through views on the rig's own proportions. |
| Proxies (A4, A9) | **Accept the proxy figures** for crowd-scale readability (R8 agrees within M3's spread), and add **art-drawn guards for the close-range distance rules**: a held victim at least 0.25 m from the lens, and no vertex of a striking Punk inside the 5 cm near plane. A9's 3% cell bar on the Punk's strikes is reported; the 4 pp lens-share bar is the binding one. | Widen the proxies' arms and head. That would move every first-person test M3 tuned. |
| Border method | **Border-protected decimation** | The posterized-texture fallback. R5 does not happen: borders follow mesh edges and read clean at 1 m under both AA modes. |
| Outline px | **`look_outline_px` = 3.75 px at 1080p**, valid once the axis fix lands | 4.0 px. With correct normals, 3.75 sits inside the bible's 3.5-4 px. Raising it now would only thicken the sides while the tops stay at zero. F-look re-measures L1 at 1, 2.5, 5 and 10 m. |
| Placeholder hulls (A7) | **On** (`look_hull_on_placeholders` = true) | Off. They cost nothing measurable (14.50 ms off against 14.43 on), and hulls on is the only setting where the placeholders and the Punk share an ink weight (J13). |
| Edge mask (A8) | **The dilated character mask, as built** (`look_edge_character_mask` on) | Fallback 1, a lit hull writing ROUGHNESS 0: an extra lit pass per hull, and it measured thinner (3.0 px). Fallback 2 (mask off) stays a Debug switch. No doubled line appears with the mask. |
| AA mode | **4x MSAA** (`look_aa_mode` 0) | FXAA (`look_aa_mode` 1). It saves 2.3 ms mean and 3.0 ms p95, and is clean at 1 m by look (PSNR 33.5 dB against MSAA, differing only along edges). MSAA is spec-faithful and slightly crisper on the 1-2 px interior lines. The final DM gives Game-boy the FXAA switch with its numbers. |

## Ranked fidelity gaps (each one becomes a phase-2 brief line)

1. **[Gate fix, then F-punk and F-player-art] The hull's smooth normals are baked in Blender's Z-up axes,** so the ink line is missing on every top and bottom silhouette. Mean dot is 0.338, against 0.930 when read as Z-up. `chain-contract` fixes the export and adds a contract assertion; F-punk and F-player-art export only after it lands.
2. **[F-look] The Punk's front at 1 m reads as one violet shadow band** (J5\*, J1\*): teal reads blue and skin reads lilac. Brief line: set `look_band_2` below cos(sun elevation) = 0.616, and change the sun or add a character light so contre-jour fronts (about half of all enemies) still show 2-3 bands. Keep each swatch's rendered mid band within about 10° of its hue. Record C2 front-lit and back-lit.
3. **[F-punk T9] The gloves read as canisters, not fists** (J3\*). Brief line: a fingerless glove with bare skin fingers and the knuckle face toward the lens in straight punches. Use a glove swatch with value at least about 0.3 (for example `dark_grey #4b4854`), so bands and ink read on it. Set the cuff radius from the wrist, not the cut's 90th percentile, and leave no spikes on the cuff. Judge at the C2 chin guard and the C4 jab and cross.
4. **[F-punk] The vest turns a flat slab to the lens in the jab wind-up hold, and the collar folds in the hook stagger** (J8\*). The skeptic showed the slab is the clip's roughly 48° torso yaw presenting the vest's front panel, not a skinning stretch; rigid binding gives the same slab. A20 freezes the move clips, so the fix is the real asset's shape. Brief line: shape the vest's front panel and armholes so the jab wind-up's yaw doesn't turn a flat slab to the lens. Add the visible-stretch test (contingency 4) and turn on smoothing only if it fails. Re-record C4 and C5 at 12 fps.
5. **[F-punk, A18, for Game-boy's ruling] The interior detail is lost at 1 m:** mouth, pocket flaps and buttons, stitching, tape edges (J2, J4). Brief line: A18's 1k ink-only mask on UV2, baked from the dense texture (never shading), logged in README's M4 departures.
6. **[Gate fix; then F-punk and F-look] Damage looks on the art** (J11). The skin takes the clothes' tiles, so it goes grey and translucent and bloodied skin gets clothes-density splats. `chain-contract` adds a skin class and a skin damage texture. Brief lines: thin the marks on the lenses and the cap's crown (F-punk, which owns the palette slots); the scuffed tile's own art (F-look).
7. **[F-punk; F-player-int] The art's bulk beyond the hurtboxes and proxies.** A6 legs are 89-91% (a waist and hip band, not the thighs) and the head is 95.0%. The cap comes 0.20 m from the lens in a hold, and the cross reaches 4.6 cm. Brief lines:
   - F-punk: assert A6 for `punk.glb` in test_art_punk, and add the art-drawn lens rules (hold: grab, 3 knees and throw, victim at least 0.25 m; the jab-cross at 0.95 m, no in-view vertex nearer than 5 cm). Keep the cap and head inside the head sphere + 5 cm. The girth clamp is contingency 3.
   - F-player-int: run test_grab_view's lens rules and the KO view's head-layer clearance on the player's skinned art.
8. **[Gate fix] The instruments measured what M3 drew, not what the lens draws:**
   - R4's occluder test was blind to art Punks;
   - SkinnedView skinned the FK pose during ragdolls;
   - A7's flip count had no rest reference;
   - the load-time art warm-up was placed before the camera's first update, so it never drew.
   `drawn-art-instruments` fixes all four. The lead re-measures first spawn and first hit after the merge.
9. **[F-punk] The authored mesh has about 159 folded triangles,** which makes A7's triangle bar unpassable in any pose. Brief line: remove the folds in the chain's decimation or normal recompute, and report the fold count as its own J7 number.
10. **[P3-int] No test guards the ragdoll write-back on the real GLB** (only the fixtures). Brief line: add the SkeletonModifier3D-after-Ragdoll check G1 ran, on a real StreetPunk through jab, stagger, launch, get-up and KO, asserting skeleton equals followers within 1 mm. Also land the windowed L5 evidence act (R4 and R8 with the art drawn beside the proxies), with ragdolling rigs skinned from the ragdoll's visual pose.
11. **[F-look] A stippled 10-20 px edge on the forearm at 1 m.** The skeptic showed it is the mid-to-shadow band edge dithered by the shadow map's soft filter, not the rim. Brief line: band edges at most 2 px at 1 m (the bible); check the shadow filter and `look_band_soft`. Also: an unexplained ink-dark wedge crosses the near glove at about 0.35 m in the C4 jab strike; check the hull's width inside `look_outline_near_m`.
12. **[P3-int] Face-down evidence.** Add a face-down knockdown, `downed_front` and `getup_front` at 1-2 m to the evidence acts. The skeptic recorded them and saw no visible defect, but the final review should see them.
13. **[F-punk] Colour fidelity:** the vest and jeans read as one blue mass, and one forearm's tape is a whole cream sleeve. The skeptic traced this to the smoke source image, not to the chain's swatch mapping. Brief line: judge the real pick's views for it, and draw the tape as a narrow wrap with ink edges from the detail mask.

## Fixes made by the gate

The two packages run with disjoint files, beside F-motion. Filled in at merge.

- **`chain-contract`** (slice-g2-01, slice-g2-07, slice-g1-05):
  - hull normals in glTF axes, with the re-export proven to change only COLOR_0 and a contract assertion;
  - a skin class for damage marks;
  - `run.py` rejects unknown steps, and the plan cites `--check`.
- **`drawn-art-instruments`** (slice-g1-03, slice-g2-05, slice-g1-01, slice-g1-06):
  - the warm-up holder placed after the camera's first update;
  - A7's flip rule against the skinned rest;
  - R4 counts art Punks through `FPView.is_drawn()`;
  - SkinnedView reads the ragdoll's visual pose.

## Refuted (kept for the record)

| Finding | Why the skeptic refuted it |
| --- | --- |
| slice-g1-02: lens distances | The numbers reproduce, but no M4 row covers an enemy's art in the lens. It is a gap (7), not a defect. |
| slice-g1-04: A6 legs from girth | The thighs and shins sit inside the hurtbox + 6 cm. The miss is a waist and hip band. It stays gap 7. |
| slice-g2-02: the vest fin from skinning | It comes from the clip's torso yaw, not stretch. It stays gap 4. |
| slice-g2-08: rim stipple | It is the shadow-filter band edge, not the rim. It stays gap 11. |
| slice-g2-09: face-down strain unseen | Recorded with no visible defect. It stays gap 12. |
| slice-g2-10: palette merge from the chain | It is in the source image. It stays gap 13. |
