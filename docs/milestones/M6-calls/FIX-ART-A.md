# FIX-ART-A: the Thug and the Kicker (judgement calls)

Each call: the decision / the alternative not taken / why. No Tripo task (0 credits), no Gemini image, no tunable, no chain or shader edit, no spec change. Base `6161da7`. Sheets are in the worktree's `captures/` (never committed): `thug_face1.png` (before | after at 1 m, front and 60 degrees), `thug_body1.png` (before and after body at 1 m, after at 2.5 m), `kick_face1.png` (the first eyes box), `kick_face2.png` (the final: before | after at 1 m, after at 2.5 m and 1.2 m). Before stills are the review's (`captures/m6-feedback-review/r_thug`, `r_kicker`); after stills are the same acts ("Look: Thug", "Look: Kicker") recorded here.

## Calls

**A-1 Thug face and bandana (feedback-chars-01).** Two regions, `bandana_right` {slot 39, only_from [40, 39], x -0.16..0.08, y 0..0.3, z 1.46..1.605} and `face_right` {slot 7, only_from [40, 7], same x and y, z 1.605..1.645}. / The review's suggested boxes (x -0.15..0.15, rim z about 1.66, regions also over x > 0). / I read the dense labels per z and x in `06_split.blend` (decoding the palette UV): the black patch is slot-40 faces at x -0.12..0.0 and z 1.55..1.63 (the viewer's right, since the front is +y), the bandana top is z 1.60 and the beanie's rim z 1.645-1.65 on the clean side. The box stays off x > 0.08 so the beanie and the chest strap keep slot 40. Result at 1 m: skin above the bandana and a plain yellow band on both sides (`thug_face1.png`); region faces are out of the per-texel decision, so the ragged fringe is gone too. No `bisect_z` (the dense mesh's faces are already 1-2 cm and the border read clean).

**A-2 Hoodie by height (feedback-chars-02).** `hoodie` max z 1.8 -> 1.35, new `hood_neck` {slot 38, z 1.35..1.8, crease 60, valley off} after it. / Raising the hoodie's valley_deg to 20-22 (the review's simpler alternative). / The drape lines the concept draws at the neck are creases, and the valleys are what scribbled; a split keeps the pocket and hem valleys at 15 degrees untouched. At 1 m the chest is calm and the hood's drape reads (`thug_body1.png`).

**A-3 Waist (feedback-chars-08).** New `waist` zone {slot 38, z 0.88..1.0, crease and valley off} after the hoodie zones. / Raising the trousers' crease_deg to 80. / That would drop the cuffs and the thigh seam as well. The zone also takes the valleys of the hoodie's first 5 cm above 0.95; the hem fold lines stay above 1.0. At 2.5 m the dotted ring is gone (`thug_body1.png`, right).

**A-4 Kicker eyes (feedback-chars-04).** An `eyes` region {slot 6, only_from [23, 6], x +-0.13, y 0..0.3, z 1.625..1.665} and an `eyes` zone {slots [23, 6], z 1.62..1.675, crease and valley off} after `headwear`. / Region z up to 1.685 (my first build): the cap lost 2 cm of its lower edge and read short (`kick_face1.png`); 1.665 keeps the brim and gives skin eyes in the cap's shade. / A region only, or a zone only (the review's "also, or instead"). / The region fixes the colour and the scuff-instead-of-bruise rule, the zone stops creases on the leftover black near the brim.

**A-5 Kicker mask (feedback-chars-05).** New `mask` zone {slot 22, x +-0.13, y 0..0.3, z 1.5..1.65, crease and valley off} after `vest`. / The review's box (x +-0.2, z 1.45..1.85). / A narrower box keeps the hood's collar and drawstring lines at the neck and shoulders. The two slashes are gone (`kick_face2.png`).

**A-6 Shared guards (feedback-code-05).** `_rolled_out(id)` now also requires `pipeline.json` to exist and hold `palette.detail_bake.crease`; a new test `test_every_roll_out_test_reads_its_own_pipeline_and_the_recipe` checks every `tests/test_m6_feedback_detail_<id>.gd` names `characters/<id>/pipeline.json` and that the config passes. / Only the pipeline-has-the-key half. / The extra test closes the "empty test file" opt-out.

**A-7 ASSETS.md (feedback-code-04, part).** The Thug's chain row names the recipe keys and the new regions and zones; the Kicker's row names the eyes region and zones.

**A-8 Tests (twin on the visible path).** Thug: `test_the_face_and_the_bandana_carry_no_beanie_black` (no slot-40 face in the front face box, regions named with `only_from`) and `test_the_hoodie_draws_its_valleys_low_and_the_waist_is_plain` (zone order, the neck's ink share is under the hem's: 0.0946 against 0.1333 now; on the base export 0.1747 against 0.1736). Kicker: `test_the_eyes_are_skin_and_the_mask_is_plain` (no slot-23 face in the eye band, the zones, the mask box's ink share under 0.02: 0.0438 on the base export). Each new test was checked to fail on the base export (checked out of `6161da7`). No assertion weakened.

## Findings answered
chars-01, -02, -04, -05, -08, code-05 and the Thug's and Kicker's part of code-04: fixed as above.

## Suite
Full `tools/run_tests.sh` on the final build: 2010 tests, 577 s on the loaded machine; no SCRIPT ERROR, SHADER ERROR or ERROR line. One failure, my new Kicker test (it compared JSON floats with `Array.has(23)`); fixed by comparing ints, then `test_m6_feedback_detail_kicker.gd` (9/9) and `_thug.gd` (8/8) rerun green; no other file touched since the full run. `run.py --check` YES for thug, kicker, bruiser, boss, dummy, punk; `player_run.py --asset player --check` YES; `gen_palette.py --check` current; `gen_trim.gd` rewrote identical files. No strain, A9 or roster ratchet moved (the strain and roster tests passed on the new GLBs).
