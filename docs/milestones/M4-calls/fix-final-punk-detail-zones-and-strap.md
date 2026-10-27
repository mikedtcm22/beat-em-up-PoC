# M4 calls: fix-final-punk-detail-zones-and-strap

The final review's wave-2 package "the Punk's ink" (findings final-v1-01, final-v1-03, final-v1-05 and final-v1-06 in `docs/reviews/M4/final-findings.json`, `packages_wave2`). Base: `m4/art-pipeline` at d82b195. The calls themselves (decision, an alternative not taken, why) are in `F-punk.md` under "Final review fixes (wave 2)", W1 to W6, as the lead asked; this file is the package's own record: what each finding came to, the tests, the numbers, the stills and what is handed back. No Tripo task, no Gemini image, no credit, no tunable (`tuning/default.json` is unchanged), no spec change.

## 1. The four findings

| Finding | Outcome | What changed |
| --- | --- | --- |
| final-v1-01 (soft, dotted ink lines at 1 m) | fixed | `punk_art.tres` asks for wave 1's sharp cut (`metadata/detail_sharp`); the mask's content cleaned by the zones below. W1. |
| final-v1-03 (the cap's strap slot: a ragged patch ringed by specks) | fixed, with the highlight left to the gloss fixer | The strap slot is an arch of two authored regions on edge loops (`bisect_x` is new), the cap and the arch take no ink. W2. |
| final-v1-05 (the laces are black leopard spots) | fixed | Zone `laces` (slots 14 and 17, z 0.05-0.2) takes no ink, `boots` 0.06 / 0.14. W3. |
| final-v1-06 (face ink 1.98% under a 2.0% ceiling) | fixed | `face_skin` 0.04 / 0.10 plus a `nose` zone: 1.62%; a margin test at 1.75%; the docs say the shipped figure. W5. |

Not in a finding, done: the shades' frame takes no ink (W4).

## 2. Code and data

- `tools/pipeline/blender_palette.py`: a region's `bisect_x` (the vertical planes at the box's x limits, cut after the horizontal ones, with a 1 cm margin so a corner is a vertex; `region_cuts` gets `x` entries); a zone's `no_ink` (gain 0) and its `ink_low` / `ink_high` default to the bake's own. No unconditional report key was added, so the probe report and the key guard are untouched.
- `tools/pipeline/pipe_detail.py`: a zone's `ink_texels_share` in the report is counted after the gain (it was before, so a no-ink zone would have shown its raw share).
- `assets/source/characters/punk/pipeline.json`: regions `cap_clean`, `strap_base`, `strap_top`; zones `nose`, `strap`, `cap`, `boots`, `laces`, `shades_frame`; `face_skin` 0.04 / 0.10.
- The four GLBs, `punk_detail.png`, both reports, `work/punk.blend`: rebuilt. Hashes: Punk `a8a00ffabb97`, heat-map `49b980a0f544`, probe `b61973f6d579` (unchanged), all three `--check` YES.
- `game/actors/art/punk_art.tres`: `metadata/detail_sharp = true`.

## 3. Tests

- `tests/test_art_contract.gd` (the Punk rows): `test_the_punks_cap_strap_slot_is_a_clean_arch_on_edge_loops_with_no_ink_around_it` (92 dark faces against 60, the arch's extents against the config's boxes, at least 6 vertices on each of the base and side planes, no ink under the cut on the cap above 0.5% and none on the arch), `test_the_punks_laces_and_ankles_are_clean_the_soles_keep_their_lines` (laces and ankles under 0.5% of samples over the cut, the sole keeps a line), and `FACE_INK_MARGIN_MAX` 1.75% in the face-ink test (the 2.0% ceiling stays). Each fails on the old assets, checked by hand with `git checkout d82b195 -- assets/export/characters/punk` and a re-import: 20 arch faces, 0 / 0 / 1 vertices on the planes, 2.93% of the cap's and 11.5% of the arch's samples inked, the face at 1.98% over the 1.75% margin (the lace test was cut off by my filter; the laces were 23% inked at the reviewed commit by the skeptic's probe and the finding's). The assets were restored afterwards.
- `tests/test_toon.gd` (outside the package's list, unavoidable): the Punk's art now asks for the cut; a duplicate of its art without the flag is the twin that keeps the linear-mix default honest. Test renamed `test_the_heros_and_the_punks_art_ask_for_sharp_ink_and_a_bare_art_does_not`.
- `tests/test_art_punk.gd`, `tests/test_m4_done_when.gd`: no ratchet moved.
- Full suite: **1580 of 1580** (1578 plus the two), 0 `SCRIPT ERROR`, 0 `SHADER ERROR`, and the only lines with `ERROR` in them are the done-when A12 note's own text. I started the suite twice by mistake (once in the background, once in the foreground) so two Godot processes overlapped for part of a run; both passed and no process was left.

## 4. What the first-person stills show (`captures/fix/`, never committed; 1600x900 recordings, crops at 2x to 4x nearest, beside V1's `captures/review/probe/` crops)

- **C1, the face and the cap** (`crops/c1_cap_mouth_before_after.png`, `captures/fix/c1_final/`): before, a grey strap patch with a triangle spike, black and grey specks round it, a mouth of fuzzy dashes and a nose that is a faint scratch; after, a clean yellow cap with a dark arch and a thin dark strap line, a thin crisp mouth bar, a hooked nose stroke in three pieces, no cheek or forehead speckle, the shades' frame a clean dark band.
- **C2, the tape** (`crops/c2_tape_after_before.png`): the wraps are solid black strokes with a pixel-wide edge (V1's were dotted grey hairs). They are bold and a little ragged at 4x (one texel is 1.7 mm): a hand-inked line, thicker than the concept's pen line. That weight is wave 1's cut (0.15) and the 1k mask, not this package's.
- **C4 f85, the cap in the cross** (`crops/c4_f85_cap_before_after.png`): the cap is clean yellow and the arch is a defined shape; the cap's hard highlight still washes over the arch's lower half (W2: the gloss fixer's per-swatch gloss).
- **C5 f200, the uppercut landing, the boots** (`crops/c5_f200_boots_before_after.png`, `crops/c5_f200_boots_after3_2x.png`): the yellow laces are clean patches with no black, the cream boots keep a sole line. A few small dark marks stand on the cream above the right boot's laces (z over 0.2, outside the zone).

## 5. For the lead

- **Two comments say what is no longer true**: `game/fx/toon.gdshader` lines 22-23 ("off for the Punk, whose face ink is tuned for the soft mix") and `game/fx/toon_materials.gd` lines 74-76 ("the Punk's mask stays the soft mix"). They are the toon-gloss fixer's files; one-line edits on merge.
- **C4 f85 and J11/J2's cap**: re-check once per-swatch gloss lands; the arch should then stay dark.
- **Known, not fixed**: the jeans show black dashes in the C5 landing (the left thigh and calf). They are not the mask's ink (a jeans zone at 0.035 / 0.09 cut the jeans' inked share to 0.2% and the dashes stayed; I took the zone out again), so they are the hull on the mesh's folds or the damage marks; not investigated. The Punk's nose is three pieces of a hooked line, not one stroke (the texture's nose is a few faint texels). The arch is stepped, two boxes.
- **Departures from the spec**: none (the Punk's detail mask is already README's A18 departure; turning the cut on for it changes how the mask is drawn, not what it is).
