# M6 LOOKS: calls

1. **The no-blood class is a new alpha, 230, with new thresholds (0.95 / 0.85 / 0.75).** Not a second flag channel or a separate cap swatch (a Punk rebuild, D6) and not 230 under the old 0.9 threshold (a glossy no-blood swatch, 229, would fall under it). Old tests that pinned `0.9` now pin `0.85` (old -> new in test_toon.gd's decode strings and the class asserts in test_art_contract.gd, test_toon.gd; twin assertions added in test_damage_look.gd on the real atlas).
2. **A cap shows the scuffs, not nothing, at the bloodied look (`damage_scuff_tex`).** Alternative: no marks at all on slot 17 (`marks: false`), simpler but the cap would lose its dirt; D6 says "scuffs and darkens".
3. **The hard edge cuts the whole blood look's alpha at `vfx_blood_edge_cut` = 0.5 (not a separate blood-only tile).** A new tile means a gen_fx.gd change and a new asset I do not own. Cost: at BLOODIED the faint dust and grease (alpha 0.42-0.5) of the clothes' blood tile drop out and the bruises' pale rim on the skin tile goes; blood, tears and scratches stay. In the A/B still the bloodied vest reads cleaner, not poorer. The value is a tunable (0 = M4); `look_marks_per_swatch` off gives M4 back.
4. **One triplanar per fragment, chosen by class, with `textureGrad`** instead of sampling all three tiles and mixing: the old shader took 6 taps on every marked art fragment, this takes 3. Derivatives are taken before the branch. `fwidth(d.a)` for the cut is inside the branch (a one-pixel artefact is possible on a swatch border; not seen in the stills).
5. **Veteran: violet vest `#8a3fb0`, burnt-orange trousers `#b8651b`.** Alternatives not taken: the old tint's orange vest (clashes with the yellow cap), olive or ochre (too close to the Punk's grey-teal). Gaps: hue 95 deg from the teal, 45 from the navy; both saturated over 0.5; none in the red band. Cap, lens, skin, gloves, shades stay the Punk's.
6. **Variant files may only recolour (no class keys) and only slots in the shared palette or the variant's base.** A variant that changed an alpha would silently change what takes blood. `gen_palette.py` raises, `test_a_variant_atlas_recolours_swatches_and_keeps_every_alpha` checks the PNG.
7. **`EnemyVariant.tint` stays as a field** (a graybox variant can still use it; the plan's inventory counts a shipped tint, and `test_no_shipped_variant_uses_a_tint` pins that none ships). Alternative: delete the field (breaks the primitives' marker with the art off for no gain). With `look_show_art` off the veteran therefore looks like a plain Punk primitive; arc is still 140.
8. **Inventory counts distinct enemy ids, not instances,** each built once with its variant: the encounter tables, the crowd waves, the boss's adds (`punk`, boss.gd) and, for the training room, the dummy and the F4 catalog. The player adds 1 when his rig has no art (0 now). Boxes skip anything under a `CombatActor`, a `Weapon`, an `EdgeGuard` or a node named `ToonWarmUp`/`FlashWarmUp`/`EdgeQuad`, anything invisible and anything off the default visual layer. Scenes are built with `with_presentation = false` (no LookPost).
9. **`generated_sfx` is per pool, global (not per scene)**: without a manifest every pool but `music_loop` counts (12 now); once AUDIO's manifest lands it counts pools with any file whose row is `gen_sfx` or missing. `empty_slots` reads the manifest `slots` (0 until it exists). Both sit under the ratchet key `global`.
10. **Floor amber counts 1 tint per scene that has a weapon lying on the floor** while it turns amber (`Tuning.weapon_floor_amber`, WEAPONS' Debug switch, when it exists, decides; absent = on).

## Measured ratchet on this base (after LOOKS' own changes)

| Scene | primitive_bodies | tints | boxes | cylinder_weapons | second_weapon |
| --- | --- | --- | --- | --- | --- |
| mission1 | 4 | 1 | 489 | 2 | 1 |
| crowd_room | 4 | 0 | 74 | 1 | 0 |
| test_room | 5 | 4 | 27 | 2 | 0 |
| global | generated_sfx 12 | empty_slots 0 | | | |

(primitive_bodies: Kicker, Pipe Thug, Bruiser, Boss; the test room adds the dummy. Tints: the amber floor pipe, plus the test room's three dummy colours. Veteran tint: 1 -> 0 on this branch.)

## Notes for the lead

- Regenerate `tuning/default.json` and the atlases at merges (`gen_palette.py` now also writes `punk_veteran_atlas.png`, and `--check` covers it).
- A/B stills: `captures/looks/cap/ab_cap.png` (the cap, M4 left, M6 right) and `captures/looks/vet/` (veteran beside the Punk at 1 m and 5 m).
- Expected drops (not mine): CHAIN's dummy takes primitive_bodies test_room 5 -> 4 and the three dummy colours (tints -3); CREW/HEAVIES take 4 bodies each scene they appear in; PROPS' bike_chain and WEAPONS the floor amber and cylinders; KIT/DRESS the boxes; AUDIO/SFX the generated pools.
