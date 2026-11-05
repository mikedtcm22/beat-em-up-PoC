# ROLL-KICKER: the Kicker through recipe parts 1 and 2 (judgement calls)

Each call: the decision / the alternative not taken / why. No Tripo task (0 credits of the 85), no Gemini image, no tunable (every knob is a pipeline-config key), no spec change. Base `b454424`. Sheets (in the worktree's `captures/roll-kicker/`, never committed): `ab_kicker.png` (concept C, the M6 build and this build at 1.2 m, 2.5 m and 5 m, each panel labelled), `st/sheet1.png` (the stage stills), `cmp1.png` and `cmp2.png` (the wraps' tuning and the back view).

## Step 1: which stage loses which detail (the recipe's step 1)

`blender_stage_still.py` on `04_parts.blend` (solid, front and three-quarter), the texture and `06_split.blend` (solid and swatches). The raw model is thin but not flat: the hood with its rim, the zip line, the kangaroo pocket, the vest's hem, the cargo pockets and the boots' soles all stand in the solid render as 0.5-2 cm steps and shallow folds. The texture is delit and flat (lime, black, cream and skin blocks; almost no lines), as the Bruiser's was, so the concept's seams are in the geometry only. The old chain lost them to the border relax (3) and the 2 cm face-sized borders, and the old texture ink drew only scribbles (the zigzag stripes on the wraps) and nothing on the vest. A Tripo regeneration (`geometry_quality detailed`, 50-85 credits plus a new fit, rig and every ratchet) would add only a denser version of the same folds, so the gain was not clear: **no credits spent.**

## Calls

**K-1 Relax 3 -> 0.** / Keeping 3 for the cloth. / The hood's rim, the pocket and the shoes' welts are hard borders; the Bruiser and Ox found the same (D-4, O-1).

**K-2 Island merge 0.0015 m2 (the recipe's 0.001-0.002 for a Kicker), 2 passes.** / The Bruiser's 0.003. / The Kicker's small features (the cargo pocket flap, the wraps' bands) are a few cm2; it moved only 11 faces (his labelling had few strays), so it is a guard, not a visible change.

**K-3 Crease `{60, 0.003, 0.002, 0.003, 0.12}`.** The recipe's thin-model start for step 8 (angle 55-60, chain 0.12) with step 2 of part 2's slim line (0.003 + 1.7 x 0.002 = 6.4 mm). / The pilot's 70 degrees and 0.2 m. / A slim model has short creases: the vest's hood and zip are shorter than 0.2 m runs. The mask ink share rose 0.5% -> 5.3% (the Bruiser's 11.9%, Ox's 6.9%; a slim character with a lot of bare skin), 16,233 texels on a crease; I did not push it higher because a first look at this share already showed every line the concept draws (hood, drawstrings, zip, pocket, hem).

**K-4 Seven zones, in order (a later zone wins).** Boxes are the authored 1.8 m frame (x across, y front, z up).

| Zone | Slots | Box (z) | Texture ink low / high | `crease_deg` | `valley_deg` | What it is for |
| --- | --- | --- | --- | --- | --- | --- |
| `vest` | 22 lime | 0.95-1.6, whole width | 0.08 / 0.2 | 60 | 15 | the hood's rim, the drawstrings, the zip, the pocket's lip, the hem; shallow folds |
| `tights` | 22 lime | 0.2-0.95 | 0.08 / 0.2 | 181 (off) | none | the lime tights are round: no line |
| `shorts` | 23 black | 0.45-1.05 | 0.08 / 0.2 | 55 | 15 | the cargo pockets, the hem and the waistband |
| `wraps` | 14 cream | 0.7-1.5, |x| to 0.9 | 0.03 / 0.09 | 60 | the wraps' bands and the cuffs |
| `face_skin` | 6 | head, 1.5-1.8 | 0.04 / 0.1 | 181 (off) | none | the M6 zone, face is not an edge |
| `headwear` | 23 | head, 1.6-2.0 | 0.06 / 0.14 | 50 | none | the M6 zone, the cap's brim |
| `boots` | 23 | under 0.2 | 0.06 / 0.14 | 50 | none | the M6 zone, the shoes' welts |

/ One crease angle for the body. / The vest and the tights are the same slot, so only a zone box splits them. Per-zone ink share in the report: vest 8.5%, wraps 6.1%, shorts 5.5%, headwear 5.2%, boots 4.8%, face 2.6% (the Punk's face figure is 1.6%; the face here has always been 4%/10%), tights 0.006%.

**K-5 The wraps' texture ink stays at 0.03 / 0.09, not the flat-texture pair 0.08 / 0.2.** The first build (0.08 / 0.2) lost the diagonal stripes on the forearms (`cmp1.png`): the texture's strokes on the wraps are real wrap bands, the only place the Kicker's texture has them. The M6 base was 0.02 / 0.07, which also inked a few smears; 0.03 / 0.09 keeps the bands (wraps ink 0.0132 -> 0.0234). / 0.02 / 0.07 as before. / It kept the smears and the thicker zigzag.

**K-6 Valleys on the vest and shorts at 15 degrees, 0.3 m chains, 5.9 mm lines (`width_m` 0.0025 + 1.7 x 0.002); off elsewhere (999 base).** / Valleys on all cloth. / DETAIL-2 step 3 for thinner cloth (14-16, 0.3). It adds a little (the vest's hem line and the hood's fold); the dominant lines are the ridges. Not the face, the tights or the wraps.

**K-7 `texel_swatch` as the recipe says (`blur_px` 1.0, `passes` 2, `fill_px` 3, `rings` 1).** `differ_from_face_share` 0.786% (in the recipe's 0.5-3%), 302,926 of 335,423 texels decided by the texture. The lime-on-skin border under the mask and the cream-on-skin edge of the wraps follow the texture instead of 2 cm steps (`ab_kicker.png`, 1.2 m: the mask and the wraps' lower edge). / `rings` 2. / The recipe says 1 for a small cloth block.

**K-8 No regions.** DETAIL-2 step 4: the back and side views at 0, 90 and 150 degrees ("Look: Kicker vest") show the hood's back and the hem right, and the mask's knot on the back of the head lime, as in the concept; the neck shows a small lime patch under the chin that the concept's mask also covers. / A region to turn it skin. / It is the mask's own lower edge, not a mistake.

**K-9 Budget 15000, normals unchanged** (14,999 triangles; `smooth_normals` 12 / 50). / 20000. / The recipe's step 7.

**K-10 Ratchets.** Only one moved, measured today:
- `tests/fixtures/strain/kicker.json` whole `min_min` 0.0367 -> 0.0183 (deepest compression today x0.0194 in `walk_forward` and `walk_back`; the M6 whole-run bar was x0.0367; the per-clip figures regenerated with `tests/fixtures/strain/gen_strain_ratchet.tscn -- kicker` (the walk's compression 0.0856 -> 0.0194, `fall` 0.1126 -> 0.0447, `dodge_left` 0.1183 -> 0.1061, `dodge_back` 0.1238 -> 0.1074); the other whole-run bars hold: worst p99.9 2.76 under 3.07, worst p0.1 0.23 over 0.21, longest stretch x13.5 under x21.8, flex share 0.93% under 1.10%; the in-bar sample count holds at 1). / Pulling the mesh back with relax 1-2. / The compression is one edge in the walk, not a visible fold (the strain's worst numbers all improved or held); the same reasoning as Ox's (O-8) and the Bruiser's (D-9). Not a re-weight of the rig, which is not this package's.
- A6, A9 cells and lens rows, `anchor_m` and `stretch_m`: held; `test_m4_done_when.gd` passes with the roster rows unchanged. Twin on the visible path: the A9 and strain rows still run on the new GLB at the same bars.

**K-11 Tests.** `tests/test_m6_feedback_detail_kicker.gd` (8): the budget (at most 15000, over 12000, config says 15000), the swatch set (only 6, 14, 22, 23), the ink in the vest, wraps and shorts boxes (floors 0.04, 0.018, 0.02; the M6 export 0.0150, 0.0132, 0.0066, now 0.1210, 0.0234, 0.0849; measured by checking the M6 `kicker.glb` and its mask out of `b454424` and re-importing), the wraps and skin share, the code per texel (59,785 of 59,996 samples coded, 795 differ), the decode, the material switch and the config's recipe values. Taking the keys opts him out of the guards in `tests/test_m6_feedback_detail.gd`, which skip a character that has its own `test_m6_feedback_detail_<id>.gd`; no edit there. Every character's `run.py --check` says YES (bruiser, boss, dummy, kicker, punk, thug) and the hero's `player_run.py --asset player --check` too.

**K-12 The look act.** `tests/bot/acts/detail_kicker_acts.gd`: "Look: Kicker vest" (0, 90 and 150 degrees at 1.6 m) and "Look: Kicker beside a Punk" (1.2, 2.5 and 5 m, level view). A filter of "Look: Kicker" also runs the roster's own "r_kicker" act.

## Rollout notes for the recipe (what the Kicker adds)

- A slim, thin-geometry character gains most from the crease with short chains (0.12 m) and a hard cloth zone; the concept's hood, zip and pocket come out of the geometry with 60 degrees.
- Keep a texture-ink zone at the low pair (0.03 / 0.09) when the texture has real strokes (wraps); the flat-texture pair (0.08 / 0.2) erased them.
- The tights and the face stay round with `crease_deg` 181, and the first recording is enough to find that out (one slot split in two zones by a box).
