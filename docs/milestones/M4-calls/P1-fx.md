# M4 calls: P1-fx

Judgement calls of the P1-fx package (M4-plan Part C §5 "P1-fx" with the §3 fx rows, as amended by A6, A9 and A11). Each: the decision, an alternative not taken, and why. Part 2 lists every assertion that changed, part 3 what was measured and seen.

## 1. Calls

**C1. The ink weight is a generator parameter, not a runtime tunable.**
- *Decision.* A stroke is baked into its PNG (SPEC §10: SVG drawn by `tools/gen_fx.gd`, rasterized to 512 px), so its width on screen is fixed once the PNG is drawn and the sprite sized. `INK_TABLE` in the generator holds, per effect, the width in px at 1080p the effect is drawn at seen from 1.2 m, and the px of its main ink line there; the generator turns that into units of the 512 px picture. `tests/test_fx_m4.gd` ties the table to the game: it spawns every burst variant and every word at 1.2 m, works out the stroke in 1080p px from the SVG's recorded `Ink line` and the sprite's own drawn width, and asserts 1.6-2.4 times `Tuning.look_outline_px`. Measured: 7.5 px for every burst, word and the guard break (2.0 times the hull's 3.75), 6.0 for the rear warning (the HUD border).
- *Alternative.* A `vfx_ink_weight` slider (the look bible's tunables column names one), by drawing the ink on a separate layer or in a sprite shader that dilates it at runtime.
- *Why not.* A runtime ink weight needs the sprites to carry a custom `ShaderMaterial` (a signed-distance or dilation pass), which replaces `Sprite3D`'s own material and touches every pooled-sprite flag, the warm-up variants and the tests that read them, and adds a shader the SPEC §10 pipeline does not have. The slider would also move the line on screen only up to what the PNG holds. With one rule (the table, the 1.2 m reference) and a test that fails when the sizes or the hull change, a rerun of the generator is the knob. Reported as a departure from the bible's tunables column.

**C2. The reference distance is 1.2 m, so the line is 2x the hull only from 1.0 to about 1.3 m.**
- *Decision.* The effects keep their size in metres (the view-share cap and floor hold it between about 1.0 and 6 m on screen: the largest burst is capped at a quarter of the view's width up to 1.24 m, then its on-screen size falls with 1/distance), and the hull keeps its width in pixels. So a baked line cannot be 2x at every distance: 7.5 px from 1.0 to 1.2 m, about 5.8 px at 1.6 m, 3.7 px (1x) at 2.5 m. 1.2 m is where a first-person fight happens (the player's reach is about 1 m and the effects cap there).
- *Alternative.* A reference of 1.6 m (2x there, 2.6x at 1 m and 1.3x at 2.5 m), nearer the bible's "1-2.5 m" in the middle.
- *Why not.* The hits the player sees nearly all land at 0.8-1.3 m, where a 2.6x line is the 12 px the bible calls heavy. Far hits are small on screen and thinner is right for them.

**C3. Small effects and particles are inked lighter than 2x.**
- *Decision.* The `INK_TABLE` rows: bursts, lettering and the guard break 7.5 px; the parry spark 5; the rear warning 6 (the HUD's panel border, it is drawn on the HUD canvas); the block spark 3.5; blood spray 4.5, splats 4, droplets, spit and the tooth 2.
- *Alternative.* 7.5 px everywhere.
- *Why not.* A 40 px droplet or a 160 px spark with a 7.5 px line is mostly line: the white core of the block spark would be a thread in a black bar. The weights are in proportion to what the effect has room for.

**C4. Blood is outlined in ink.**
- *Decision.* The blood's dark-red outlines (`BLOOD_DARK` strokes) are `INK`; the damage tiles' blood too. The splat's two-pass compound path draws only the outer half of its stroke, so its visible line is half the stroke (the table's px are the visible ones).
- *Alternative.* Keep the dark red.
- *Why not.* The bible asks for one colour for hull, edges, VFX strokes and HUD borders, and blood is the one VFX that sits beside the ink-hulled characters. A test checks that every stroke in every SVG but the damage tiles is the ink or a light colour.

**C5. Lettering: letters drawn to one cap height in the generator, not sized by the director.**
- *Decision.* The brief asks for letters sized by cap height, not word width. Every word's glyphs are stretched or squeezed across until the picture (letters, the ink grown round them and the shadow) is exactly four cap heights wide (`WORD_ASPECT`), so every PNG has the same cap-height share of its width (0.25; the SVG records it) and `vfx_word_*_m`, the width the director sizes by, now sets one letter height for every word. Stretch factors run from 0.70 (CRUNCH) to 1.18 (POW). The letters' ink is grown from their shape (so a counter keeps its ink and its face, which a 2x centred stroke would have closed), the "!" dot is a part of its own (a contour outside the first is not a counter).
- *Alternative.* Keep the letters as they were and give the director a per-word cap-height table: `size = tier_cap * width_over_cap`, with the view-share cap applied to the widest word.
- *Why not.* The view-share cap is a share of the view's width: at 1 m it limits the widest word, so the other words in the pool would have been cut back to its letter height or their letters would have differed at close range, which is where it is seen. In the generator the equal height holds at every distance, needs no new director rule or table, and the test (`test_every_word_is_drawn_to_one_cap_height`) checks the SVG records and the on-screen letter height per tier. The cost: a squeezed CRUNCH and a stretched BAM, which read as one display face.

**C5b. The word's units are not texture pixels.**
- *Decision.* The lettering's picture is 400 units wide and 512 px in the PNG, so a weight in texture px (`INK_TABLE`) is 0.78 as many units (`unit` in `_lettering`). The first version drew the ink in texture px as if they were units and came out 28 percent heavy; the new test measures it.
- *Alternative.* Draw the words in a 512-unit picture.
- *Why not.* The glyph table is in cap-height units (100); the picture's width follows from the aspect.

**C6. Ben-Day dots: explicit circles on a 45-degree lattice, bursts and lettering only.**
- *Decision.* `_dots(poly, holes, pitch, ...)` emits `<circle>`s for the lattice points inside a shape (and outside its holes) at least a margin from every edge, with a radius growing along an axis or outward from a centre. The bursts have them on their outer ring, growing to the tips; the lettering on the lower half of each face. Pitch is 9 px at 1080p, a little coarser than the toon halftone's 6 px cell, so it reads on a 186 px burst. Colours are a shade darker than their ground; none is red but the finisher burst's, which sits on the finisher red.
- *Alternative.* An SVG `<pattern>` with a `clipPath`, or dots on the blood and the sparks too.
- *Why not.* The brief says explicit circles; ThorVG's pattern and clip support is not something to rely on for byte-stable output, and the lattice needs no random numbers. The splats and sparks are too small for a dot to read (a 150 px splat has a 6 px pitch).

**C7. Burst variants keep the tier's `kind` and swap the texture.**
- *Decision.* `spawn_pop(VfxArt.BURSTS[tier], ..., VfxArt.burst_texture(tier, variant))`: the sprite is still named `burst_small`/`burst_medium`/`burst_large`, so every test and bot that finds effects by kind (`live_effects(&"burst_small")`) is unchanged. `pick_burst_variant()` draws from the director's seeded generator (so captures repeat) and never returns the variant shown last for that tier; with two variants it alternates after a random first pick. `vfx_burst_variants` (VFX, Bursts) turns it off.
- *Alternative.* Name the variant (`burst_small_2`) as the kind; a third variant.
- *Why not.* Renaming the kind would have broken the kind lookups in test_vfx and the bots for half the hits. The brief asks for a second variant; two never repeat, at a cost of three PNGs.

**C8. Splats are unshaded and a little dark.**
- *Decision.* A lying splat is `shaded = false` with `modulate` = `vfx_splat_shade` (0.85, VFX, Blood) grey. A sprite lit by the sun and the sky grades smoothly across the stepped toon floor, and the before captures show pale pink splats where the floor is in shade. Unshaded, it is the flat ink-and-colour decal the rest of the set is, and it shares the thrown droplets' material, so the warm-up draws two variants, not three.
- *Alternative.* Keep `shaded`, or tint it by the toon's shadow tint.
- *Why not.* A toon tint needs the floor's band under the splat, which the sprite cannot read; a flat splat a little under full brightness sits in either band.

**C9. The generator writes to another folder with `--out=<dir>`, and a test runs it.**
- *Decision.* `-- --out=<dir>` writes `<dir>/source` and `<dir>/export` and leaves the `.import` files alone. `test_the_generator_reproduces_the_committed_art_byte_for_byte` runs Godot in a second process (`OS.execute`, headless, about a second) and compares every SVG and PNG with the committed ones. This pins "a rerun of the generator leaves every PNG unchanged" and catches a drawing change committed without its output.
- *Alternative.* Compare nothing (the codemap's one-off `cmp` check), or move the drawing into a class a test can call.
- *Why not.* A `SceneTree` script cannot be instantiated by a test, and a new class file is outside the package's files; the second process tests the script as it is run.

## 2. Assertions that changed (old to new, and the twin on the visible path)

- `tests/test_vfx.gd`, the warm-up tests (P1-toon left the file alone; the damage-look tests moved to `test_damage_look.gd` in S0):
  - `test_warm_up_shows_each_sprite_variant_once_then_pools_it`: three variants (`[shaded, no_depth_test]` = plain, no-depth-test and "lying (shaded)") to two (plain and no-depth-test; the plain one is the thrown droplet's and the unshaded splat's); pooled 3 to 2, and 2 to 1 after the first hit takes one.
  - `test_warm_up_waits_for_a_camera`: 3 sprites to 2. `test_warm_up_draws_no_ink_with_the_photosensitivity_toggle_off`: pooled 3 to 2.
  - *Why.* The lying splat is no longer shaded (C8), so the third variant would never be drawn. *Twin.* `test_the_warm_up_covers_every_material_variant_an_effect_draws` in `test_fx_m4.gd` collects the `[shaded, no_depth_test]` of every sprite every effect draws (all three tiers, the four block cases, blood, spit, the tooth, a splat) and asserts each is one the warm-up draws; `test_splats_are_flat_unshaded_and_a_little_dark` asserts the splat's state.
- `test_every_word_has_lettering_and_the_set_is_8_to_10_words` and `test_fx_art_is_512_px_with_svg_sources_and_logged` are unchanged (ten words, 512 px; the new PNGs are covered by `test_fx_m4.gd`'s own check of every file in the folder).

## 3. What was measured and seen

Measured (headless, `test_fx_m4.gd`, the director's own sizing at fov 90, a hit 1.2 m ahead, px at 1080p): burst_small 7.49, burst_medium 7.49, burst_large 7.50 (both variants), guard_break 7.50, every word 7.48-7.50 (heavy pool at 336 px wide, finisher pool at 480), rear_warning 6.00 at its 160 px base. Hull 3.75 px. All 32 PNGs reproduce byte for byte; the damage_bruised, damage_scuffed and speed_lines PNGs did not change at all.

Looked at (first person, 1600x900 captures, `captures/fx_before` and `fx_after` for vfx_bot's tier act and P P P P, `captures/p1fx/c5` and `c13` against `captures/m4_before/c5` and `c13` at the same marks, all 0 errors):
- *Bursts.* The large burst's outline is thinner than M3's (14 units to 8) and even, with the Ben-Day dots visible in its red ring and a second shape on alternate finishers; the medium and small bursts are a little bolder. Both variants read as one family.
- *Lettering.* KRAK, WHUMP, SMAK, WHAM at one letter height; the ink round the word is about twice the dummies' hull; the dots and the top highlight on the faces read at 1 m. Heavier than before (M3's word line was about 1x the hull), and about the bursts' weight.
- *Blood.* Ink-outlined droplets and splats; the splats on the floor are flat, with no pale shaded patch.
- *Impact frame.* On (c5 uppercut) the burst's dots print as a halftone in the ink flash and the word reads; off (c13) the stack is as before. Unchanged apart from that.
- *Not heavier than the characters.* The words' ink is the heaviest line on screen at 2x the hull (6 px against 3 at 1600x900); the bursts' are lighter than M3's. If Game-boy finds the words heavy, the line is one number: `INK_TABLE`'s `word_heavy` and `word_finisher` weights.

## 4. Not done, or for someone else

- No runtime ink-weight slider (C1); the bible's tunables column named one.
- The damage tiles' shapes are unchanged (only the blood's outline colour); their marks live on the characters' toon shader (P1-toon's).
- The rear warning's HUD size and the speed lines (a canvas overlay tinted `HudStyle.INK`) are unchanged.
- The effects' size on screen at 2.5 m and beyond is 1x the hull or less (C2); a distance-aware ink would be a shader.
