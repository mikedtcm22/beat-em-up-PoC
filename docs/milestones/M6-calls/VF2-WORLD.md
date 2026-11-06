# VF2-WORLD: judgement calls and numbers

The vfinal round's fix pass for the world (findings vfinal-world-03, vfinal-code-04 to -07, the reviewers' side notes).

## 1. Trim wins over walls (vfinal-world-03)

- **Call: the solver ranks trim by block name** (`TRIM_NAMES`: `Jamb`, `Lintel`, `Post`) between "a kit piece" and "the bigger box". Not taken: ranking by `look` (`dark`/`accent`): the alley's sides and lot walls are `dark` walls that should stay "bigger wins". Not taken: a `trim` property on `LevelBlock` (not my file, and a new serialised field for a one-off ranking).
- Result: street 34 yield lines, 0 unsolved; the roofs' 60 and the boss roof's 3 keep their count (the roofs' lintels had no wall overlap; the rail posts swap with their bars).
- **Rails.** The reviewer's note: the rail top at f763 held the dark slash, the less usual of its two old looks. A post wins the bar's top, so the rail top is olive (88, 84, 92 at (698,320) in 82bab12's f763; mine the same, 3e7084e 16/37). At the terrace rails (pose 9) 82bab12 and 3e7084e showed the slash and mine is olive: 82bab12's winner swung by rail and view, so one winner everywhere was the only steady choice, and the plain face is the usual one. Not taken: the bar winning (the slash everywhere).
- **Look (tour, 20 poses, frame pose+30; mine vs 82bab12 vs 3e7084e, mean abs grey in the crop):** warehouse jamb (f201) 0.034 against 1.009 for 3e7084e; a2_doors lintel (f97) 0.027 against 3.769; skyline_up pilaster edge (f305) 0.706 against 1.180; the skyline_up door reveal (f305) 2.962 against 3.929, the rest being 82bab12's z-fight showing brick over the top of the reveal where the dark face now wins everywhere; rail top f763 differs 77 px (>24 grey) from 82bab12 against 1048 for 3e7084e. No other pose moved (the roofs and boss roof poses: mine vs 3e7084e 0.000 to 0.06 permille).
- **Held-pose flicker** (permille of pixels changing by more than 20 grey per frame, frames pose+8 to +46, mine / 3e7084e / 82bab12): f67 0.12/0.12/0.94, f171 0.16/0.16/0.62, f275 0.06/0.06/3.53, f733 0.30/0.31/0.65, boss gap f1191 0.01/0.01/0.06. The z-fight calm holds.

## 2. Hollow ledges (vfinal-code-04)

- `MeshClip.clip` classifies a triangle as `FACE`, `BOARD_EDGE` (looks along the plane, within the standoff), `BOARD_BACK` or `OTHER`. A `BOARD_EDGE` face is a line in the plane's (u, v) coordinates, so the clip removes the part of its length the rectangle covers (a cap exactly on the rectangle's edge counts as inside, within the coplanar tolerance), not the whole triangle. Not taken: the reviewer's centroid test (a whole long ledge triangle would go when only part of it is covered).
- `Scan.orphans()` before the fix: 14 blocks (StartWall 2, EndWall 4 and 4, RightWall2..6 and LeftWall4..5 at 4 each, the Terrace and Catwalk walls); after: 0 in the level, the crowd street and the training room. The cut end of a part-covered board stays open (as the front's was before); a grazing view of a cut plinth end is the only place it could show.

## 3. Dangling yields (vfinal-code-05)

`InsetBlock.unresolved_yields()` and a `push_warning` in `_make_mesh`; the climb test is "more `..` than steps up to the `LevelSection`" (the boss roof fence's path into the roofs is the one cross-section case). The ground test lists every unresolved path of the level (0) and has a synthetic dangling and cross-section pair. Not taken: warning inside `_clips()` (the scan calls it hundreds of times).

## 4. steps() exemption (vfinal-code-06)

`_stands_by_design(a, b)` exempts a fence block against another fence block, a `Curb*` block or anything under a Barrier, and the pairs in `ACCEPTED_STEPS`. **The shutter is accepted by name** (`ShutterStair3` against `Lintel3`): it is a Barrier's panel hung in the opening, 40 mm wider than the lintel's end, so the ink along its edge is the door leaf's own outline; making it flush means resizing a Barrier's box, which touches what stops the player. Twin: a fence block 20 mm in front of a wall is still reported. Old -> new: the blanket `_stands_by_design(item)` -> the pair form; steps at 0.0001 m2 still 0 in the level.

## 5. Slips and robustness (vfinal-code-07)

- `MIN_AREA_M2` stays a `const` with a comment that it is a numerical epsilon, and now also drops zero-area fan triangles (107 before, 0 after; a test counts them).
- The scan's `COPLANAR_M` is gone: `Scan._coplanar()` reads `Tuning.data.kit_coplanar_m`.
- Clipping carries tangents (every kit mesh has a tangent slot; before, clipping dropped it silently) and `push_error`s on a UV2, custom, bones or weights format (`MeshClip.uncarried`). The check reads the surface format, not the arrays.
- `KitPiece.ensure_mesh()`; `InsetBlock._clips` calls it on a piece partner. Twin test: a block before its piece in the tree is clipped (3 end-cap rectangles).

## 6. The catwalk doorway's floor (the world reviewer's note): not a fault of the world, left

At tour f711 the doorway floor (`Catwalk/EastFloorSide`, x 12 to 14, z -21 to -18 in the roofs' space) is a tan, lit-looking patch. **Cause: the wave's ground paint.** With `ground_sheet_off` (the Debug A/B) the same pose has a grey, shadowed floor like the rest, with no tan; the patch is the new ground tile (mirrored on every other 8 m tile down the street, world (16, 72.5)/8, near the fold) landing a tan patched square in the doorway. It is not a shadow leak (the lit-looking edge is the tile's) and not a z-fight winner (the block is alone in its plane). 82bab12's tile had dark cracks there. A fix is a tile layout change (`tools/gen_trim.gd`, not mine, and FB-GROUND's own call 5 found the mirrored layout hard to move), so it goes to the requests. The look is a tan floor patch in a dark doorway, seen from 8 m on one pose.

## 7. Shared clipped meshes (optional): not done

Sharing means a cache keyed by kit kind, size and the cut rectangles, and the blocks' sizes and rectangles are almost all different; the +24 draws did not move frame time. Left.

## Requests

- `tools/gen_trim.gd` (the ground tile's layout): move or recolour the tan patched square that lands in the catwalk doorway at about world (16, 72.5), if the lead wants the doorway floor shadowed.

## Departures

None.
