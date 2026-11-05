# ROLL-PUNK: the Street Punk through the recipe's parts 1 and 2 (judgement calls)

Each call: the decision / the alternative not taken / why. No Tripo task (0 credits), no Gemini image, no tunable, no spec change, no chain or shader change. Base `c06ccf7`. The mesh, the rig, the budget (15,000 triangles) and the three locked A/B GLBs are unchanged byte for byte: only `punk_detail.png` (now RGBA, 274 KB), the report and the work blend move. Sheets (in the worktree's `captures/`, never committed): `ab_punk.png` (concept A | M6 | this build at 1 m, 2.5 m and 5 m, every panel labelled), `r5/jacket.png` and `r7/pair_r7.png` (the look acts), `head_r*.png` (the A/B steps on the head).

## Step 1: what the raw model has

The Punk's geometry is real (the vest's pockets, collar and hem, the trousers' creases and rips, the boots' soles are 1-3 cm steps, as in the Bruiser's raw model), and his texture has true strokes (the tape, the vest's seam lines). So the recipe applies as it stands and Tripo would buy nothing (the model is locked since M4 anyway).

## Calls

**P-1 Texel swatches on, at the recipe's start values (`blur_px` 1.0, `passes` 2, `fill_px` 3, `rings` 1).** / A larger ring or `passes` 3. / `differ_from_face_share` is 0.66% (the Bruiser's 1.1%, the band is 0.5-3%): the Punk's texture is clean. The gain shows on the veteran's violet vest against his skin and on the cap's brim, not as a big visible change: his 2 cm steps were already softened by relax 3.

**P-2 Border relax stays 3, not 0.** / The recipe's 0 (tried: r1, r2). / The relax-0 builds (r1, r2) showed no cleaner border on the lens, the frame or the cloth than relax 3 with the texel codes: the codes already carry the border (P-1), so 0 buys nothing here, and the recipe keeps a value above 0 where the borders are cloth against skin. (The glint's shrinking in r1 and r3 was the crease line on the lens, fixed by the `lens` zone, P-6, not the relax.)

**P-3 No island merge.** `palette.min_island_area_m2` / 0.001 (r1-r3: 1553 faces moved) and 0.0004 (r6: 1337 faces moved), both recorded. / The Punk's small parts are authored (the cap's strap arch from two region boxes, the laces, the shades' frame, the tape): the merge turned the arch's faces into ragged pieces at any value that merged a stray patch (visible at yaw 0 in `head_r3.png`), and 0.0004 still moved 1337 faces. The recipe's step 3 says to raise the value until a stray patch is gone and no real feature disappears; here no value does both, so the key stays absent (the shared guard "no other character uses the pilot's keys" is skipped for him, and a test holds the absence).

**P-4 Crease ink `{70, 0.0035, 0.0025, 0.003, 0.2}`, the recipe's part 2 weight (7.8 mm across), valley block `{999, 0.45, 0.003, 0.002}`.** / The pilot's 0.005 / 0.003 (10 mm: too heavy for M4's 6 px strokes); valley chains 0.35 (r5: too many short dashes on the vest at 1 m, see `pair_r7.png`'s predecessor). / The Punk's own strokes (tape, the vest's lines) are about 6-7 mm; the crease lines now match them. The report: `texels_on_a_crease` 10,031, `ink_share_after` 4.1% (the whole mask was 0.89% before; the Bruiser's 11.9%).

**P-5 M4's seven zones kept as tuned (ink thresholds unchanged); each gains an explicit `crease_deg`.** / Retuning their ink thresholds. / The brief says to keep them. Face, nose, strap, laces and shades_frame: 181 (off, the face is not an edge, the strap and laces take no ink at all); cap 60 (the brim's edge and the button); boots 55 (the sole's welt). The face's ink share is 1.28% (M4's margin test is 1.75%).

**P-6 Six new zones, put BEFORE M4's seven so a later (tuned) zone wins on the shared faces.** `lens` (slot 19, crease off: the glint is authored, r3 showed the crease eating it), `skin_body` and `dark_body` (slots 6 and 2, crease off: the skin and the tank take the texture's own lines only), `wraps` (slot 14, z 0.4-1.6, off: the tape is texture strokes), `vest` (slot 16, z 0.8-1.7, crease 75, valley 15) and `jeans` (slot 18, z under 1.1, crease 75, valley 18). / One crease angle for the whole body. / The seams on the vest and the trousers are what the concept draws (pocket flaps, the collar, the hem, the jeans' pocket and fly creases); skin and tape would get cracks.

**P-7 The veteran needs no change.** / Adding veteran-only slots. / The codes name a slot and the veteran's atlas maps slots 16 and 18 to violet and rust (the swap's own file `assets/source/palette/variants/punk_veteran.json`), so the codes recolour. A test reads both atlases at the codes' swatch cells: only slots 16 and 18 differ, alpha identical. `pair_r7.png` (1 m on top, 2.5 m below): the violet vest and the rust trousers are crisp at the texture's border, the cap, wraps, gloves and skin are the Punk's.

**P-8 Ratchets: none moved; three M4 assertions about the Punk's mask moved (old -> new), found by the first full run (1986 of 1989).** The mesh did not change, so `test_m4_done_when.gd`, `tests/test_art_punk.gd` (with `ART_PUNK_VARIANT_STRAIN=1`) and the roster/strain fixtures stand. The three that failed read the mask the M4 way:
- `tests/test_art_contract.gd` `test_the_punk_detail_mask_is_a_1k_ink_only_png_on_the_punks_uv2`: B `< 0.01` ("B holds nothing") -> `<= 20/255 + 0.001` (B now holds slot + 1, at most the lens's 19 + 1). Twin on the visible path: `test_the_mask_carries_a_palette_slot_per_texel` in the new test file (each code names one of the Punk's seven slots; the alpha marker is 128/255).
- `tests/test_toon_glint.gd` (the glint gate): `max_blue == 0` -> `<= 20`, same reason and twin.
- `tests/test_art_contract.gd` `test_the_punks_strokes_are_lines_not_dots`: `STROKE_PIECES_MAX` 600 -> 800 (654 measured: the crease lines are new pieces, the dots tests, 3.0% in pieces of 6 or fewer against 12% and a median of 14 against 6, are unchanged and well inside; the 1,144 dotted pieces of the bake before the cleanup still fail). Twin: `test_the_vest_and_the_trousers_carry_their_ink` (the crease's `texels_on_a_crease` over 5,000).
These two files are outside the ROLL-PUNK ownership list; the edits are Punk-only lines (listed in the result's "requests" so the lead can take either merge).

**P-9 Tests.** `tests/test_m6_feedback_detail_punk.gd` (6): budget and swatch set, a code per texel (56,917 of 57,196 samples coded, 3.0% differ from their face's slot), the vest's and the trousers' ink (floors 0.04 and 0.03; the M6 export 0.0138 and 0.0104 measured by checking it out of `origin/m6/full-art-audio`, today 0.1200 and 0.1017), M4's tuned zones kept (face thresholds, no-ink strap, laces and frame; face ink under 1.75%), the config's recipe values (no island merge, crease on and 4-8 mm across, crease off on the skin, tank, wraps, lens and face, shallow valleys on the vest and trousers) and the veteran's swap recolouring exactly slots 16 and 18. Every character's `run.py --check` and `player_run.py --asset player --check` say YES.

## What the stills show

- **Look: Punk jacket** (0, 90, 150 degrees, 1.6 m; `r5/jacket.png`): the vest's pocket flaps, its hem and the back pocket of the jeans now carry ink; from behind the vest's lower hem is a clean line. The vest's armhole edge is frayed with a few dark dashes (the concept's ragged cut sleeve; acceptable). The blue patches on the vest's lit side are the toon ramp, not a palette slot.
- **A/B sheet:** at 1 m and 2.5 m the vest has pockets and a hem line, the trousers have fold lines; at 5 m the difference is the darker outline of the vest's hem. Honest: his gain is smaller than the Bruiser's (his M4 mask was already hand tuned), as the brief expected.

## Open risks

- The vest's valley ink is a little scribbly on its back and lower hem at 1 m; `crease.valley.min_chain_m` 0.55 or the vest's `valley_deg` 18 would calm it (a config-only change).
- The concept's torn trousers (the rips) are in the texture only, not the geometry; texel borders show them as skin patches at the knees, which is as it was.
