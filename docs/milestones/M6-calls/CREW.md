# CREW: judgement calls

Each: the decision / the alternative not taken / why.

**C1 Three views, not four.** Front, back and left go to Tripo and to `views_check.py`; the right view is not drawn. / The Punk's four. / Tripo's multiview takes front, left and back (T4 was the model; T5's fourth view was no better, F-punk C4), so the fourth image would only have been checked. It saved two Gemini images per character.

**C2 The views are normalised onto the mannequin by an image edit, not re-rolled.** Gemini's figures were 5-10% too tall with the soles 76 px low (`views_check.py` failed all three views of both). `tools/pipeline/views_normalize.py` scales the subject uniformly and sets its feet row and centre; the originals stay as `view_*_raw.jpg`. / Re-generating until a try passed (the Punk needed up to three per view). / Flat colour blocks on a flat ground lose nothing in a Lanczos resize; the fit rescales to 1.82 m anyway. The Kicker's back view also came on a grey ground (`#a3a3a3`): its ground was flood-filled to `#d9d9d9` first. The Thug's left view came back as a true profile facing right; it was mirrored (the asymmetry of the character is the chest strap, which Tripo reads from the front and back views).

**C3 Prompts: the ponytail hangs straight, the stance is the mannequin's.** The concept's ponytail streams sideways and its stance is wide; the first Kicker front copied both. The prompt now says the ponytail is hidden behind the head from the front and the legs are parallel. / Taking the concept's pose. / A flying ponytail would be a separate floating mesh for the rig and the head clamp. Gemini images: Thug 5 (front, back x2, left x2), Kicker 6 (front x3, back x2, left x1; two of them came back PROHIBITED_CONTENT with no image, retried unchanged), 11 in all, at most 20.

**C4 The Kicker is the seed-4102 retry (30 + 25 credits).** The first model's right hand was cut 16.8 cm up the forearm (the wraps' loose boundary counted as the cut), so the right fist's cuff was x1.29 of the fist box (A5, which only the boss may loosen). The retry cuts both hands at 2-3 cm. / Fixing the first with a ratchet on `a5_extent`; per-side cuff settings (the config has none). / The plan allows two retries and the retry fixed the fists by itself. It did not change the boots, so the first model's other numbers were no better.

**C5 The Kicker's boots: a mesh lift and a front bulge, in `blender_fit.py`.** After the warp the chunky boots' lugs sat 8 mm under the floor (A4: 5 mm) and their sole-level toe reached only -0.166 (A1: -0.2). `fit.sole_lift_m` 0.0065 and `fit.bulge` with `direction: "front"` (6 cm, half height 0.3 m) fix both; both are opt-in with no new report key. / A ratchet on A1/A4 (the roster has none for them, and CHAIN's test file is not mine); a radial bulge (it also widened the boot 5 cm); another seed (the retry's boots were the same). / It is the smallest change that keeps the plan's bars. REQUEST for the lead: these two options are in a file CHAIN owns; if HEAVIES makes the same change, keep one copy.

**C6 Skin is shared slot 6 for the Kicker and 7 for the Thug; the wraps are cream (14).** The delight texture is paler than the concept, so the Lab-nearest label put pale skin on cream when only the tan slot was offered; offering slot 6 keeps the skin on skin. The Thug's skin is the warmer tan (7). / New skin swatches (a palette range spent on a colour the shared set has). / Each character keeps 4 colours.

**C7 Black and yellow take no blood.** The Kicker's black (cap, hair, shorts, boots) and the Thug's black (beanie, strap, boots) and yellow (bandana, wraps, buckle, bands) are `blood: false` (LOOKS's rule, M6 D6): they scuff and darken. / A second black swatch for the hair (the Lab-nearest labelling would split the same colour at random). / One swatch each, three at most per character.

**C8 The Thug's shin bands are two `palette.regions` with `bisect_z`; the grey reflective band between them stays olive.** z 0.575-0.598 and 0.628-0.651 from the front view's pixel rows and the fit's leg stretch; the first run's bands were blotches. / A grey swatch (a fifth colour for a 2 cm stripe). / The two yellow lines carry the read at 5 m (the lineup shows them).

**C9 The detail mask: the Punk's recipe, with `no_ink` for the Thug's bandana pattern and buckle.** The generated bandana pattern baked into black splotches and the buckle into a black spot at 1 m. / Leaving the ink. / R4 of the rubric (no specks).

**C10 Ratchets** (reasons in the roster files, each today's figure plus a margin; the plan's bar is held for everything else): see ARCHITECTURE's CREW section. The Kicker's jump kick is the one that matters (a9_cells 7.6%, lens 6.6-7.1 points: the raised boot and the cargo shorts fill the lens differently from the proxy capsule); the Punk's cross is at 7.0%.

**C11 `a5_extent` and A6 are at the plan's bar for both** (A6: Kicker torso 100%, legs 99.3%, head 99.0%; Thug 100/97/100, no axis point outside, after the Punk's head clamp and knee bulge). No `a6` ratchet, no `a5_extent` ratchet.

**C12 No generated fist** (the lead's note: procedural for both unless the lead says yes). / T9's 50-credit glove. / The ceiling and the lead's note.

**C13 The Thug's pipe is still the cylinder in the captures.** PROPS's pipe art is wired by WEAPONS (`pipe_thug.gd`'s pipe lines are WEAPONS's). The fist box is 0.1 x 0.118 x 0.116 m and the pipe 0.064 m, so the procedural fists hold it at any grip offset between 0.028 and 0.04 m. Seen in "Thug three swings".

**Credits** (Tripo, 165 in all, ceiling 250): Kicker generation 30 + rig 25 (first model, unused), generation 30 + rig 25 (the retry, used); Thug generation 30 + rig 25; rig-checks free.
