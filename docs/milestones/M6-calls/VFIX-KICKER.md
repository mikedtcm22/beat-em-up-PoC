# VFIX-KICKER: the Kicker's eyes as the call settled them (judgement calls)

Each call: the decision / the alternative not taken / why. No Tripo, no Gemini, no tunable, no spec change. Base `18784a2`. Sheets (worktree `captures/fix/`, never committed): `row_a.png`, `row_b.png`, `rows_bc.png` (rows b, c1, c2), `final.png` (concept | before the wave | after the wave | shipped at 1 m | shipped at 1.2 m | shipped at 5 m). Each row is the Kicker's head at 1 m (yaw 0, and the 60 degree turn), 1.6 m (yaw 0, 90, 150) and 2.5 m.

## V-1 The settled values, and the correction to FIX-ART-A's A-4

A-4 says the final `eyes` region is z 1.625..1.665 and the zone z 1.62..1.675 (the first build's 1.685 cut 2 cm off the cap's lower edge). The merged `pipeline.json` held the first build (region 1.685, zone 1.69): the edit back was never committed, and the calls file described a build that did not ship. **Correction: the shipped values are now the A-4 ones** (region 1.625..1.665, zone 1.62..1.675). Careful with the config: `1.685` also appears once as the head girth clamp's `from` z (rig step); that is unrelated and unchanged (my first search-and-replace changed it by mistake and the A/B rows a and b were recorded with that change; I redid b and the shipped build with it restored; row a is only a side look). / Keeping 1.685. / It turned the brim's tips and underside skin (verify-chars-01).

## V-2 The three builds, A/B at 1 m, 1.6 m (yaw 0, 90, 150) and 2.5 m

- **(a)** the settled values only: the brim and the cap's lower edge are back, thick, with a dark underside; the band is a flat pale skin strip, and the face still reads empty beside the concept.
- **(b)** (a) plus slot 24 `kicker_shade` (`#8c5f4e`, skin class: alpha 204, so it bruises and bleeds) painted by the region instead of slot 6: the band becomes the cap's shade with the eyes in it, as in `kicker_c.jpg`; a few ink scratches on it at 1 m (the `eyes` zone's 0.06 / 0.14).
- **(c1)** (b) with the `eyes` zone's texture ink at a calmer pair 0.1 / 0.22; **(c2)** at a busier 0.03 / 0.08. c2 grew a near-black bar under the brim again (the thing the review objected to); c1 has the fewest scratches and still keeps the texture's own eye marks as soft dark patches inside the shade.

**Shipped: (c1)**: the shade band from (b), the calm ink pair. It is the closest to the concept at every distance: a thick brim with its underside, a shaded band with no black bar, a skin forehead above it, and the band is skin class so it bruises. / (a) alone: still the "blank" face. / (b) as is: scratchier. / (c2): the black bar.

## V-3 The swatch's colour

`#8c5f4e`: darker than the shared skin `#f0c9a8` by luminance 0.15 or more (a test), warm so it reads as shaded skin and not as the cap's `#3b3a43`, and out of the red band. Slot 24 is inside the Kicker's range 22-27; `gen_palette.py` rewrote `palette_atlas.png` and `punk_veteran_atlas.png` (the variant copies the shared atlas); both are shared files the lead regenerates on merge. / A darker tan `#a87a60` (not tried) and a brown nearer the cap (the black bar's risk).

## V-4 Tests

`tests/test_m6_feedback_detail_kicker.gd` (10 now, 8 before this pass plus the A-4 one): the swatch set now has slot 24 on the mesh; `test_the_eyes_are_skin_and_the_mask_is_plain` pins the region's slot (24) and top (1.665 +- 0.0005) and bottom, the zone's top (1.675) and bottom (1.62) and ink floor, most faces in the eye box are the shade (and none the cap's black), and at least 120 faces of the cap's black stand just above the region (the settled build has 149, the first build's 1.685 has 87, measured by checking out the old export: the first build fails the pin four ways); a new `test_the_shade_is_a_skin_class_swatch` reads the atlas (alpha 0.8, darker than skin by 0.15 luminance). No assertion weakened; the earlier "none is the cap's black" and mask-ink assertions stand.

## V-5 ASSETS.md (verify-code-03, the Kicker part)

The Kicker chain row names the settled region, slot 24 and the calm ink; the mask row names the `mask` and `eyes` zones (nine zones); the palette row names slot 24. The palette atlas row (shared, the Heavies' rows) is for VFIX-HEAVIES: see requests.
