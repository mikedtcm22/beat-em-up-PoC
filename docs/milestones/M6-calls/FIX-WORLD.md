# FIX-WORLD: judgement calls and numbers

The review's fix wave for FB-GROUND (findings feedback-world-02, -world-05, -code-02, -code-03, -code-04).

## 1. The boss roof flash (world-02, code-02)

- **Cause**, as the review found it: `BossRoof/Geometry/Ground` (200 m, `slab_dark`, drawn only) had its top at world -0.5, the top of three 75 m `Roofs/Geometry/Skyline` walk strips (`WestWalkRoof`, `EastWalkFacade`, `EastWalkRoof`; `WestWalkFacade` lies outside the Ground's footprint).
- **Call: the Ground goes to a top of -0.25** (`boss_roof.tscn`, `Ground` y -13 to -12.75), not the review's -1.0.
  - Why: under M6 the Ground (top 0) hid the whole skyline street under it. At -1.0 the strips (-0.5) and their lane dashes would stand 0.5 m proud of the Ground and show for the first time (a new look nobody asked for, and slabs floating over a dark plane). At -0.25 the skyline stays hidden as in M6, the Ground is still 0.25 m clear below the street's floor (top 0), and no drawn plane lies within 0.2 m of it.
  - Not taken: -1.0 (the above); clipping the Ground's footprint (the far drop reads against it); turning the strips' `draw_box` off (they are the skyline's, and visible west of the Ground).
- **Numbers** (`tools/ground_flicker.py` on "Look: ground drift" `-- --ground=held`, the gap-down pose: section 2 at (8.5, 0, -10.5), yaw -90, pitch -38; the machine is deterministic here, two runs gave the same digits):

| | d1 `still` | d1 `creep` | note |
| --- | --- | --- | --- |
| before (Ground top -0.5) | 0.315 | 0.581 | per frame it alternates 0.03 / 0.3: the review's toggle |
| after (top -0.25) | 0.072 | 0.364 | M6's own steady 0.03 to 0.09 |

## 2. The general guard (world-02, code-02)

`tests/m6_coplanar_scan.gd` replaces the old floor/deck/slab_dark test, and `tests/test_m6_feedback_ground.gd` holds Mission 1, the crowd street and the training room to it. What it counts, and why each rule:

- every drawn box, whatever its module, look or thickness (a `LevelBlock`'s mesh or the mesh of a world-layer body a room builds); a rotated box is skipped (the street's one ramp);
- two faces that look the same way within 4 mm over an overlap in view; **a face that looks down is never compared** (the eye is above every floor), and **a pair on one flat colour or on the grid is not reported** (it draws one picture wherever it lies: the rooms' flat materials), while two trim faces always count (each box lays its own UVs);
- the overlap loses what a third drawn box covers just outside the plane and what has no world collider below a point 0.4 m off the face (the far side of a building: it looks into nothing the camera is ever in);
- what is left must be at least 0.02 m2 (a corner's sliver of a hand's width is not a z-fight).

Old -> new: the old test (floor, slab_dark and deck modules at most 1 m thick, tops only, 0.01 m tolerance) is replaced; its Ground-versus-street case is covered by the new scan (the scan finds the Ground and the skyline strips on the committed code, which is how world-02 was reproduced) and by `test_the_boss_roofs_far_ground_is_not_solid_and_lies_below_the_street`, kept. Twin on the visible path: `test_the_scan_finds_a_pair_it_is_given` builds two coplanar slabs and a stepped one and expects exactly the one pair (and none a tenth of a metre apart).

**Pairs found in Mission 1** (88 over 0.02 m2 in view, 0 after): 3 Ground-versus-skyline (fixed by the move above; in the first scan of 295 drawn boxes they were 75 x 2.5, 3.4 and 4 m), then 85 between solid blocks, all of one of these kinds:
- wall tops against the lintel, back or jamb over a door, alley or lot (top faces at y 11, 8, 6, 10.5, 14.6, 16.5, 17.5): 60 pairs;
- two walls ending in one side plane at a corner (the street's Start/End/Left/Right walls, the terrace's RightA/RightB walls and the catwalk's end walls, alley and lot sides against their backs, the barricades, the penthouse's walls): 25 pairs, the biggest `Street/EndWall` against `LeftWall5` (24 m2) and `Terrace/RightAWall0` against `Catwalk/EndWall0` (12 m2).

Fixed with a new `InsetBlock` (below) in 41 blocks of `street.tscn` (17), `roofs.tscn` (23) and `boss_roof.tscn` (1).

## 3. InsetBlock, not a smaller block

**Decision:** `game/level/kit/inset_block.gd` (a `LevelBlock`) pulls the drawn mesh in per face (`inset_min`, `inset_max`, metres) and leaves the collider the box. A face that would share a plane with another's gives way by 0.02 m, a third by 0.04 (`INSET_STEP_M`); the keeper in each plane is the biggest block (a scripted greedy colouring of the plane's conflict graph, so no two blocks in one plane receive the same tier).
- Not taken: resizing blocks (moves colliders and the navmesh; `tests/test_m6_colliders.gd` pins them); `draw_box = false` on one of the pair (hides its other faces); a depth bias in the shader (only hides a coplanar pair at some distances, and the shadow pass would still fight; FB-GROUND call 1); a clip of the box's faces in KitMesh (not mine).
- 2 cm is below what the eye sees as a step and above the depth buffer's resolution at the distances these faces are seen (reversed-Z float depth: about 1 cm at 100 m, less closer).
- New file; `LevelBlock` is untouched.

## 4. The ground's look (world-05)

Judged against `assets/source/concepts/m6/mood_street_a.jpg` (broad pale pools of light, a few ink ticks), before and after stills at A1 and A2 (`captures/cmp_a1.png`, `cmp_a2.png`, not committed). Kept: the after is clearly calmer and closer to the mood.
- **Fewer and larger tone patches:** the worn pools are painted on a 4 x 4 lattice, not 8 x 8 (twice the size), with a rarer threshold; **the tar seams and the oil stains are gone** (they were the camouflage-like brush strokes); five cracks, not eight; two patched squares, not three.
- **A paler base:** base value 0.38 to 0.455, worn 0.43 to 0.505, patch 0.42 to 0.495, dark 0.335 to 0.405 (in the `ground.hsv` band, `trim_layout.json`).
- **An ink outline on some patches:** the dark patches (the lattice's minima, one a tile) and the two squares carry a 6 px outline (`gen_trim.gd`'s `_outline_mask`: the dilated mask without the eroded one, softened a pixel), at least 5 px as before. Alternative not taken: outlining the worn pools (their edge is a noise contour, so a ring would be thin where the noise is flat).
- **Breaking the 8 m repeat:** the shader mirrors the tile on every other tile along z (the street's length), so the manhole and the grates repeat every 16 m. Not taken: an offset per world cell (it cuts the picture at the cell's edge, a seam); a 4096 px tile over 16 m (the sampling and memory cost, and the perf bar); mirroring across the street too (the two halves of the street became each other's reflection, with a fold down the street's middle at x = 0). The manhole and grates are moved inside the tile (not near the z edge) so a feature is not beside its own reflection. A 4096 tile or a second layer would need a perf run of its own.
- **Kept:** features at least 5 px (the thin-ink test), unlimited mips, the edge that softens with mip.

Flicker numbers (the same act, d1 in grey levels, before -> after):

| | still | creep | pan | walk |
| --- | --- | --- | --- | --- |
| A1 | 0.0165 -> 0.0291 | 0.094 -> 0.117 | 0.382 -> 0.499 | 0.574 -> 1.118 |
| A2 | 0.0392 -> 0.0014 | 0.152 -> 0.019 | 0.630 -> 0.055 | 1.035 -> 0.444 |

**A1 rose** (still +0.013, creep +0.023), A2 fell by an order of magnitude; against M6's 5.1 (the z-fight) both are nothing, and the sum of the four still and creep numbers falls (0.30 to 0.17). The A1 view now has a drain grate and a manhole within 4 m, where the old tile had a crack and a square; the `still` value is the eye settling by a millimetre over ink edges, and a paler base raises every edge's contrast. I lightened the grate and manhole bars (36 px pitch, 4.5 px half-width, from 24/22 and 3.5) and kept the rest: the brief asks for the pale ground, which costs contrast. If Game-boy sees the A1 grate shimmer, the lever is `ground_ink_soft_*` (live) or fewer bars in `gen_trim.gd`.

## 5. The strips' ink fade (code-03)

**Decision:** the fade measures the footprint by its mean side, `sqrt(|det|)` of the two gradients (times the sheet's width), not its longer side; the ground's own softening still uses the longer one. For a wall seen square the two are equal (nothing changes); for a deck at a graze the mean is the geometric mean of 46 and 5, about 15, so seams hold to about 10 m and fade by 20 m, where before they were 68% faded at 10 m. Defaults (16 to 64) kept; the tunables' comment now says so. Not taken: the min axis (an anisotropic footprint's thin side says nothing of the long one: ink would never fade on a very grazing surface, where the capped mip is worst); raising the defaults (it would also change walls).
- Check: "Look: ground drift" `--ground=held`, the roofs' deck looked along (`deck_far`), before | after shader: d1 `still` 0.0919 -> 0.0922, `creep` 0.1328 -> 0.1331 (no new shimmer); the near-mid deck's lap seams hold a little farther (the sheet at `captures/fade_cmp.png`).
- Test: the shader's code is asserted (`fade_texels`, the mean-side expression); old -> new `mask *= 1.0 - smoothstep(ink_fade.x, ink_fade.y, texels)` -> `... fade_texels)`.

## 6. Other

- ASSETS.md: the trim sheet's row gains the FB-GROUND flat-tone repaint clause (code-04); the ground sheet's row is updated. The Thug's and Ox's chain rows belong to FIX-ART-A and FIX-ART-B.
- `tests/bot/level_acts/ground_acts.gd`: the act "Look: ground drift" ends with `HELD` views (the gap, the deck, the deck looked along; `-- --ground=held` runs only those). The act's title is unchanged, so `tests/test_level_bot.gd`'s expected titles are untouched.
- No new Tuning value (the inset, the fade and the repeat are scene and tile data; `ground_ink_fade_*` and `ground_m_per_tile` only had their comments changed, so `tuning/default.json` is unchanged).
- The deck still-view's d1 (0.146) is not a z-fight: the per-frame values vary smoothly 0.03 to 0.2 with an occasional spike (the eye's settling); the guard is clean.

## 7. Perf

`tools/perf_compare.sh --force --vsync on --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" --runs 2 82bab12 HEAD` (HEAD 70bbaa7, the code as shipped here; **the machine was busy**: load 3.3 when it started, 4.3 to 4.5 between runs, other builders running, so the absolute numbers are not a baseline, the ratio is the lead):

| | 82bab12 | HEAD |
| --- | --- | --- |
| mean ms | 17.80 (17.77..17.84) | 18.29 (18.05..18.53), +0.49 (+2.8%) |
| p95 ms | 24.35 | 25.25 |
| worst ms | 43.6 | 298 (one HEAD run had a single 391 ms frame, in the first spawn's window; the other 38.5 ms) |
| first hit / first spawn ms | 28.2 / 27.8 | 26.6 / 25.8 |
| draws / objects per frame | 108.5 / 192.0 | 110.3 / 193.1 |
| shadow_prims | 128 343 | 127 245 |

The ground's sampling cost is unchanged by construction (one `textureGrad` read, now with a triangle wave of the tile's z and a sign: a few ALU ops); `InsetBlock` draws the same number of meshes as the block it replaces. The +1.8 draws a frame is the bot's path (the HEAD runs took 8 424 frames to the walk's 8 642: a different time in each section). The mean's +0.49 ms sits inside this machine's noise (the two HEAD runs differ by 0.48) but is not proved to be; rerun on a quiet machine before reading it as a cost.

## Requests (files not mine)

- **The crowd street and the training room** (`crowd_room.gd`, `test_room.gd`) build their boxes in code, so no `.tscn` of mine can change them. The scan finds 17 and 2 coplanar slivers there (floor joins at y 0, curb and lintel tops at y 6, 8, 9, 2.4, 1 and 5; none over 0.3 m2), so their tests hold the 0.5 m2 line. To bring them to 0, build those boxes as `InsetBlock`s (or give `RoomKit.add_box` an inset) and drop `ROOM_MIN_AREA_M2` from `test_m6_feedback_ground.gd`.

## Departures

None. (The Ground's top is -0.25 where the review suggested -1.0, a choice inside the brief's "clear of every drawn plane under it".)
