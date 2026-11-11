# M6 fix-final-art: judgement calls

Findings: final-chars-01 (Ox Pellerin's gloves), final-chars-03 (the Bruiser's steel plates), final-chars-02 (the heavies' head
framing at 1 m), final-code-04 (the heavies test's leaked EnemyDirector). Each entry: the decision / an alternative not taken / why.

**A-1 The glove is regenerated, not replaced by the procedural block.** The fix redrew the thumb-side view (Gemini, 2 images, the
second kept) and ran one Tripo multiview (50 credits, label FIX-ART-boss_fist, balance 1210 -> 1160). / Option 2, the chain's
block fist with a strap (no credits). / The lead's ruling asks for a real glove, and the left view already read as one; the J came
from the thumb-side view alone.

**A-2 The cause was the thumb-side view, so the rule went into the prompt.** The first prompt said "a narrower silhouette" and
"hanging straight down", and Gemini answered with a curled J. The new prompt forbids a bend (no J, banana, horn or toe), asks for an
upright rounded block with parallel sides and gives the glove's front its thumb oval. Take A still hooked the thumb; take B was a
clean round glove and went to Tripo unedited. / Editing the J by hand (cutting its tail). / Tripo reads its views as drawn.

**A-3 facing_yaw_deg 90 and source_side Right are kept.** The new glove's views use the Punk's convention (left view = back of the
hand, thumb on the image's left; front view = the thumb side), so the Punk's measured facing holds. The first-person look at 1 m
shows round knuckle ends up in the guard. / Re-measuring with a probe fist. / The look shows no curl; the two fists mirror each other.

**A-4 The glove has its own slot (54, boss_glove #211e27) and the wrist wrap is the orange.** `palette.glove_slot` and
`strap_paint_slot` are 51 (orange): the chain paints the clean collar with the glove slot, so the collar becomes the orange wrap
of boss_c.jpg. The glove's body is labelled by the texture's nearest colour (the charcoal, the robe's slot), so two `palette.regions`
boxes (one a hand, below the collar, `only_from` the charcoal) relabel it 54. `parts.fists.glove_slot` (procedural fist only) is set
to 54 as well, so the config agrees with the palette and HEAVIES H-6 (which said slot 2: slot 2 was the lighter grey the collar
took; the "0 protected vertices" failure of H-6 did not return with 51 and 54). / A new chain option "force the fist's colours"
in blender_palette.py (not my file). / The regions need no code.

**A-5 The glove is not enlarged.** The new glove is fitted to the same fist box as every fist (H-11), so a5_extent stays 0.2: no
ratchet moved. / A bigger glove with a5_extent ~0.35 (D16). / The finding asks for the shape; the size would need a chain option.

**A-6 Triangles and ratchets.** The boss builds at 29298 triangles (30000 budget); no boss ratchet moved and the roster fixtures
`boss.json` and `bruiser.json` are unchanged. The boss's per-clip strain figures were regenerated (the new glove moves them a
little; every clip stays inside its +10%, and the whole-run figures are kept).

**B-1 The Bruiser's steel is #7a839e (was #9aa4c0).** The lead's ruling and the reviewer's suggestion agree. The labelling still
tells it from the purple (hue gap, tested). `majority_passes` stays 6: a run with 10 gave the same label counts and the same strain
numbers, so it did nothing here (the purple on the chest is the scarf and the open jacket's flaps, as in the concept). / Region
boxes for the plates (like H-4's boxes for the jacket). / The plates and the jacket overlap in space; boxes would cut the wrong
faces in the poses.

**B-1r The Bruiser's strain ratchets move (old -> new), with the reason.** The darker steel changes which texture colours the nearest-colour
labelling calls steel, so the colour borders (the decimator's protected edges) moved and the decimated mesh with them. Today's
figures: worst p0.1 0.173, deepest compression x0.0195, against the held 0.174 and x0.0205. `tests/fixtures/strain/bruiser.json`
whole: `low_min` 0.174 -> 0.169 and `min_min` 0.0205 -> 0.0185 (today's figure less 2% and 5%); every other whole-run figure is
kept (worst p99.9 8.16 <= 8.65, stretch x22.9 <= x32.7, flex share 2.81% <= 3.02%), and the per-clip figures were regenerated
with `gen_strain_ratchet.tscn -- bruiser boss`. / Keeping the old steel colour. / The finding asks for the darker steel and the
loosening is a few percent of a ratchet that was 5% above the old figure.

**B-2 Plate edges come from an ink zone, tuned twice.** `detail_bake.zones` holds a "plates" zone on the steel over the torso and
shoulders with ink_low 0.006 and ink_high 0.03 (the body's 0.04 / 0.11); 7.7% of its texels are ink, against 1.1% for the whole
body. The first pair (0.012 / 0.045, 4.6%) gave few lines in the smash wind-up; the second shows the shoulder plates' seams. The
ink is the texture's own lines: the Tripo texture has few plate edges, so the plates read as steel with seams on the shoulders,
less than the concept's segmented chest. / Authoring lines by hand (a `glove_lines`-style frame): out of scope for a fix pass.

**C-1 The head framing is the rig's, from the Head bone.** `LookActs.framed_pitch_deg(bot, subject, base_deg)` turns the base pitch by
the elevation of the subject's Head bone from the lens minus that of the same bone on a body scaled to 1.8 m, at the same
distance. A body of rig scale 1 returns the base unchanged, so the Punk's, the dummy's, the Kicker's and the Thug's frames are
byte-identical (the same constants through the same path) and the M4 comparison holds. The body view (-6) is turned the same way,
so the head stands where the Punk's does in both views. / A per-row `face_pitch_deg` in the roster JSON. / The rig knows its
own height; a table would be a second source for it.

**C-2 The framing is a capture-rig change only.** No game file changed for it (D1, no collider or sim change).

**D-1 final-code-04: the actors go under a Node3D holder the test frees.** An EnemyActor makes the EnemyDirector as its sibling, so
it now lives under the holder and goes with it. The GUT warning is gone (no WARNING line in the file's run). No test fails without
the fix (the warning is GUT's own); none was added for it. / Freeing the director in after_each by name.
