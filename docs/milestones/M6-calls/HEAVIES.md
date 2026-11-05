# HEAVIES: judgement calls and numbers

Each: the decision / the alternative not taken / why. Credits: H1 30, H1c 0, H1r 25 (the Bruiser: 55); H2 50, H2c 0, H2r 25, H3 50 (the boss: 125). Total 180 of the 350 ceiling, no retry. Gemini: 18 images of 24 (Bruiser: front 2, back 1, left 2, right 2 unused; boss: front 1, back 1, left 3, right 2 unused; glove 4: the first pair drew boots and a repeated view).

## Calls

**H-1 Three views, not four.** The right view is dropped from both views jobs. / Four views as the Punk's jobs file lists. / The Punk's accepted Tripo run (T4) was front, left, back; Gemini returned the Bruiser's right as a three-quarter front and the boss's right as a copy of its left (facing the wrong way), and the multiview call never used it. The two right views per character were spent before this was seen (4 images); asking for them was the mistake.

**H-2 Views are fitted after the fact, by a script.** `tools/pipeline/views_fit.py` crops and rescales a view to the mannequin's height and feet row. / Regenerating until Gemini hit the 3% bar (the hood and helmet make a heavy 3-12% too tall). / The pixels are only moved; one image per view was already spent on the style and the profile.

**H-3 The Bruiser's front was the second try, the boss's left the third.** The first Bruiser front copied the concept's outlines; "ABSOLUTELY NO OUTLINES" and the arms-held-out sentence fixed it. The left views of both came back as front views with the references of the Punk's route; the left now takes only the concept and the mannequin's left, with a profile rule, and the boss's got a "do not copy the front-facing posture" paragraph. / Keeping outlined views (Tripo bakes them into the texture). / The detail mask is baked from that texture.

**H-4 Palette colours follow the Tripo texture, not the concept.** The delit texture's purple is a dull violet (#806090) and the steel #8080a0; the pipeline labels by nearest colour, so a saturated purple (#7b4fa6) lost the jacket to the steel (3% purple). Bruiser purple is `#755394` (saturation 0.44; the 0.5 look-bible bar is tested on variants only). / Region boxes to force the jacket. / The jacket and the plates overlap in space. Boss charcoal `#35323b` (darkened, per Game-boy), orange `#ee6a1c` (hue 23, the dummy's is 31), tights `#1c1a21` (merged into the charcoal by the labelling: 5 colours used), shorts `#78747f`.

**H-5 `blood: false` on the Bruiser's steel and the boss's orange; none on the hoods.** The hoods share a swatch with the jacket and the robe, which take blood fine. / A separate hood swatch. / The texture's labelling cannot tell a hood from a jacket.

**H-6 The boss's gloves use the shared slot 2.** `palette.glove_slot` 50 with `strap_slot` 51 (or 17) made the fist decimation fail ("0 protected vertices"); the Punk's 2/17/2 work. Slot 2 (`#4b4854`) is a shade lighter than the robe, which suits a glove. / Debugging the fist protection in `blender_palette.py`. / Not my file; the look is right.

**H-7 Three fit knobs added to unowned tool files (opt-in).** `fit.sole_offset_m`, `fit.sole_flatten` (blender_fit.py) and `rig.clamps[].below_z_m` (blender_rig.py), plus `views_fit.py`. / Pre-processing Tripo's GLB, or accepting A1/A4 ratchets (the sole rows have none and the test constants are the plan's). / Without them the Bruiser's toes sat 2 cm above its heel (A1: the toe must reach -Z within the lowest band) and 4 vertices of its heel were foot-bound (A4 needs 40). Every key is absent from the Punk's, the hero's and the dummy's configs, so their report hashes are unchanged (`--check` for the Bruiser and the boss says YES; I did not rerun the others'; the full suite's report tests do).

**H-8 Two test rows were 1.8 m only and are made scale-aware (shared file, CHAIN's).** `test_m4_done_when.gd` A4: the walk and idle clips are built at `rig.rig_scale()` (they were built at 1.0, so a 2.05 m rig's hips sat 12 cm too low in the walk: soles 127 mm under the floor, boss 272 mm); A5: the table's fist box and centroid are multiplied by the rig scale (the box is the 1.8 m table's). Old -> new: `build_named(id, 1.0, ...)` -> `build_named(id, rig.rig_scale(), ...)`; `gap < 15 mm` -> `gap / rig_scale < 15 mm`; `ratio = ext / size` -> `ext / (size * rig_scale)`. Twins: the same assertions, unchanged numbers, at scale 1 for the Punk, the dummy and the hero (every figure in their rows is identical), and at the heavies' own heights for the Bruiser and the boss.

**H-9 The Bruiser's A6 legs are a ratchet (0.895); everything else meets the bar.** Torso 99%, head 97%, boss 95-96% on all three. The Bruiser's trousers are baggy over knee pads against a leg capsule of r 0.1 x 1.139; the clamps are 0.085/0.075 m (the Punk's 0.078/0.068 give 90.2% anyway: the misses are the hip and the knee against the stance's axis, not the width). / Clamping to sticks. / Reads worse than the concept and doesn't pass either.

**H-10 A9 and A11 and A7 ratchets are the measured figures plus a margin, with their reasons in each roster file's `notes`.** The Bruiser at 1 m fills 65-88% of the view in the smash, grab and headbutt, against the primitive body's 60-82% (a padded jacket, plates and guards against boxes): cells that differ 25.4%, lens-share gap up to 21.6 points. The boss's charge: 8.3 points, the grab's cells 14%. / Slimming the heavies to the proxies (the girth clamps already cut the torso and legs). / The plan asks the framing and lens rules to be held; the arms and the plates ARE the character. The plan's bar stays printed as GATE. Open risk below.

**H-11 The fist is not enlarged for the boss.** The glove is fitted to the same fist box as every fist (the chain does it), so A5 holds with the default `a5_extent` 0.2: no ratchet. / A bigger glove with `a5_extent` ~0.35 as D16 allows. / The chain scales the block to the box by construction; a bigger glove needs a new chain option, and at 2.3 m the 10 x 11.5 x 11.8 cm glove is 12.8 x 14.7 x 15 cm in the game.

**H-12 The boss's lens rule runs at `boss_read_m`, not 0.95 m.** At 0.95 m the pound put its right forearm 2.9 cm from the lens (inside the near plane). / Asserting at 0.95 m and slimming the sleeve. / The live AI steps the boss back before a charge or a pound when the player is nearer than `boss_read_m` (1.5 m): no strike of the game starts closer. At that range the nearest vertex is 0.37 m. The Bruiser's strikes hold at 0.95 m (0.21 m).

**H-13 `EncounterSpawner.make_enemy` keeps a boss scene's own name.** It wrote "Boss" over `display_name`, so the HUD bar read "BOSS" whatever the scene said. A scene that names the boss now wins; one that leaves the default ("Actor" or "") still reads "Boss". Old -> new in `tests/test_boss.gd`: `display_name == "Boss"` -> `"Ox Pellerin"`; twin: `test_art_heavies` checks the scene, the catalog and the spawner (and that a Bruiser is still "Bruiser 1").

**H-14 The facing yaw is the heuristic's (high confidence), pinned.** Bruiser 90.3298, boss 89.9120; both agree with the toe signal (A1's toes at -Z pass). / Reading the toe signal by hand as the Punk's C5 did. / The heuristic said "high" for both (the Punk's said "conflict" because of the backwards cap).

## Requests (files I do not own)

- `tools/pipeline/blender_fit.py` and `blender_rig.py` carry the opt-in keys of H-7; CHAIN or the lead may want a line in the CHAIN section of ARCHITECTURE (I put them in HEAVIES').
- `test_m4_done_when.gd` and `game/level/encounter_spawner.gd` and `tests/test_boss.gd` carry H-8 and H-13 (small).
- CREW's Kicker (1.8 m) and Pipe Thug (1.8 m) need none of them.
- The lead: `primitive_bodies` 4 -> 2 in `mission1`, `crowd_room` and `test_room` (done in the ratchet file); the default preset needs nothing (no tunable added).

## Open risks

- The Bruiser's bulk against the proxies (H-10): the wind-up of the overhead smash and the grab fill 80-88% of the view at 1 m. The look at 1 m reads as huge armour; whether the wind-up still reads is Game-boy's to feel.
- The Bruiser's legs are thin under the jacket (clamps 0.085/0.075 m).
- The boss's gloves are the chain's fist-box size, smaller than the concept's.
- Strain: the bruiser's visible stretch (14 cm, the jacket's hem and hips in the smash lunge, bones Hips/Hips) and the boss's (7.3 cm, the robe sleeve over the upper arm in the grab) are ratcheted, not fixed.
- Tripo ledger: the ledger file on this branch counts the PROPS rows too; the account shows other builders' spending.
