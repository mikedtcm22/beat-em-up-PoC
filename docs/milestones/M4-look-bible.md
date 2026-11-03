# M4 look bible: the targets

Written by the lead on 2026-10-26 from look-first §0.1, as M4-plan.md Part A §A11 asks. The names are Part C §2.9's tunables.

**Targets, not pass bars.** P1-toon, P1-post and P1-fx build toward these numbers. F-look tunes to them on the real Punk. The slice gate and the final review judge against them, beside L0-bench's "before" pack. The pass bars are in Part B.

**Pixels.** Every pixel figure is at 1080p. Movie Maker records at 1600×900, so scale pixel figures by 900/1080 (×0.83) when measuring a capture.

## Lines

| Element | Target | Tunables |
| --- | --- | --- |
| Character hull | 3.5-4 px at 1-3 m. At least 2 px out to 10 m. Never above 4.5 px. | `look_outline_px` (start at 3.75), `look_outline_near_m`, `look_outline_far_m` |
| The player's own body | ×0.8 of the character hull. Fades to 0 near the lens. | `look_outline_fp_scale` (0.8), `look_outline_lens_fade_m` |
| Placeholders and props | Hull on by default (A7): primitives, dummies, crates, dumpster, car, pipe | `look_hull_on_placeholders` (true) |
| Environment edge lines | 1-1.5 px. Fade out from 25 m to 60 m. | `look_edge_px`, `look_edge_fade_start_m` (25), `look_edge_fade_end_m` (60) |
| Ink | One colour for hull, edges, VFX strokes and HUD borders: `HudStyle.INK`, (0.07, 0.06, 0.09), about `#120f17` | the shader's `ink` uniform |
| VFX strokes | About 2× the character line at 1-2.5 m. M3's strokes were about 12 px, about 3×. | No tunable: the strokes are baked into the PNGs (SPEC §10's pipeline), so the weight is `INK_TABLE` in `tools/gen_fx.gd`. `test_fx_m4` ties it to `look_outline_px` (M4-calls/P1-fx.md C1). |

## Shading

| Element | Target | Tunables |
| --- | --- | --- |
| Bands | Characters have 3 bands: lit, mid at 72%, shadow at 42%. The environment has 2. Band edges are at most 2 px wide at 1 m. | `look_band_1`, `look_band_2`, `look_band_soft`, `look_mid_level` |
| Shadow | Never black: at least 40% of the lit value, with the hue shifted 45% toward violet (0.36, 0.32, 0.55). | `look_shadow_tint` |
| Specular | One hard highlight, under 3% of the visible surface. Glossy regions (shades, leather, studs) get ×3. | `look_spec_*` |
| Rim | Stepped, on characters only: about 25% of the silhouette band, +35% value. | `look_rim_*` |
| Halftone | Off by default. When on, dots only in the shadow band, in 6 px cells. | `look_halftone_env`, `look_halftone_chars` (false), `look_halftone_cell_px` (6), `look_halftone_strength` |

## Colour

| Element | Target |
| --- | --- |
| Environment saturation | At most 0.30 (HSV), with value 0.25-0.6 |
| Enemy main colours | Saturation at least 0.5 |
| Red | Hue 345-15° with saturation above 0.5, only in blood, the rear warning and finisher accents. The crowd room's car, `Color(0.55, 0.2, 0.2)` at `crowd_room.gd:326`, breaks this and gets recoloured (A13). |
| Grade | A "street_dusk" LUT: cool shadows, warm highlights, low-chroma colours desaturated. Blood red and the enemy palette stay within ΔE76 6. Tunables: `look_grade_enabled`, `look_grade_strength`. |
| Bloom | None, except on VFX (SPEC §10) |

## How it is judged

- **First person only.** The 1 m acts (L0-bench's C1-C13) are the frames that count. The side view only checks mechanics.
- **Compare with the "before" pack.** Before and after are compared at the same act and frame.
- **One game.** The placeholders, the street and the VFX must read as one style with the Punk (rubric J13).
