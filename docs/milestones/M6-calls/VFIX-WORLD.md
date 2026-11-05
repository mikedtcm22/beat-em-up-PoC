# VFIX-WORLD: judgement calls and numbers

The verification round's fix pass for FB-GROUND (findings verify-world-01, -world-03, -world-04, -code-04, -code-05, and the near deck from the reviewers' notes).

## 1. The insets drew new ink lines (verify-world-01)

- **Cause**, as the review found it: FIX-WORLD pulled an InsetBlock's whole drawn face back 2 to 4 cm. A partner covers only part of many such faces, so the rest of the face stood 2 to 4 cm behind what was flush beside it: a step the edge pass inks (full height, or in dashes that crawl with the sway).
- **Call: the block does not draw the overlap at all.** `InsetBlock` (`yields_to`) cuts, out of its own kit mesh, the rectangle it shares with each block that wins the plane (`MeshClip`). Over that rectangle there is one face in the plane, the partner's: no fight, no step, no second plane to show anywhere. Outside it the face is untouched, with its UV and strip as before.
  - Not taken: **recess only a face its partner covers completely.** I solved it that way first (a greedy keeper choice per plane group): 12 faces solved, 27 not (the lintels over the doors, the wall tops, the jambs, the alley and lot sides, the catwalk's end wall: every one a partial overlap where neither face lies under the other, so no choice of keeper hides the recess).
  - Not taken: **shorten the drawn box at the overlapping end.** It works for an end overlap (a lintel over a door) but not for a face that overlaps along its side, and it moves the box's other faces (a lintel's front is coplanar with the wall's too).
  - Not taken: **a millimetre offset.** The edge pass's depth threshold would not ink it, but its normal-crease pass inks the side face of any step: at 1 mm that face is 0.07 px wide at 5 m, so a pixel centre falls on it one frame in fourteen. The whole line would then switch on and off with the camera's sway, the same dashes with a longer period. Nothing below a flush face is clean.
  - Not taken: **split the drawn box into a recessed core and flush plates** (a notch). It gives the same picture as the cut, with more boxes, corner plates that fight each other and a UV restart at every join.
- **Which block yields** is data in the scenes, written by `tools/solve_insets.gd` and `tools/apply_yields.py` (see ARCHITECTURE): one total order (a kit piece over a block, then the bigger box, then the path), so no two blocks yield to each other and no overlap is left undrawn. Across two sections the later-built block yields, since a block only finds a partner that is already in the tree when it builds (one pair: the roofs' `CurbEast` and the boss roof's `EntryFenceR`).
- **A kit piece is not a box.** A cornice's bounds have a face where its three boards have a staircase (its end caps are 0.18 m2 of the bounds' 0.27), so a block that yields to a piece gives up only the rectangles the piece's mesh really draws on that plane (`MeshClip.face_rects`; twin: `test_a_block_yields_only_what_a_kit_piece_really_draws`), and the scan's hole check and pair check use the same rectangles for a piece. Not taken: making the piece yield (a `KitPiece` has no mesh cut) or excluding pieces (the cornices' ends do share planes with the walls').
- **The plinth boards** (a wall of 3 m or more stands a 0.6 m board 5 cm off its brick) are cut with the face: the cut takes every triangle looking the same way on the plane or up to `kit_clip_standoff_m` (0.06) out from it. Two walls' plinth boards in one plane would fight otherwise. Their ledges (the tops of the boards, a 5 cm strip) are not cut; they existed before the wave and are not seen as a fight at any distance in the tour.
- **Numbers.** `tools/solve_insets.gd` on the level with no `yields_to`: 381 drawn boxes, 163 coplanar pairs over 0.0001 m2 (54 over the guard's 0.02), 97 yields on 89 blocks (27 in the street, 59 on the roofs, 3 on the boss roof), 0 unsolved.

### Looking (tour, 20 poses, `Look: arena tour`; `captures/fix/tour`, not committed)

Three recordings, the same frames: before the insets (`captures/m6-feedback-review/tour`, `82bab12`), the wave (`captures/m6-feedback-verify/tour`, `d582d21`) and this build, frame `pose + 30` of each of the 20 poses.
- **The five findings, before | wave | mine** (crops from `/private/.../vfw/tour/sheetA.png` and `sheetB.png`): the catwalk's brick wall (pose 11) has a dashed vertical line only in the wave's; the terrace's door pillars (pose 8) have new outlines on the left edge and top of the brick pillar only in the wave's; the penthouse's side (pose 13) has a dark vertical line only in the wave's; the pilaster at the street's start (pose 1) has an ink line in all three (its own silhouette), full height in the wave's, as before in mine. Mine matches the before-the-insets crop in each.
- **The difference of mine against the wave** (an amplified, thresholded difference per pose, `dv_sheet.png`) shows only thin lines at the five places and at the brick courses where the wave's smaller box had shifted the texture's phase. **Against the pre-wave recording** (`db_sheet.png`) it shows the new ground's cracks and squares (poses 1 to 6, the floor rows) and a few boss roof lines (the wave's intended Ground move), and no vertical or horizontal line on a wall.
- **The boss roof gap stays fixed:** tour pose 17 (`boss_gap_down`), frames 1200 to 1236, whole-frame d1 at 800 x 450: before the wave 0.185, wave 0.038, this build 0.038 (the same digits).
- **The walk** (`Perf: level walk`, god mode, 9 255 frames in all three recordings): the mean second temporal difference of the picture (grey, 480 x 240, per frame) is 12.38 (82bab12), 12.34 (wave), 12.26 (this build); p95 37.12, 36.94, 37.00; p99 134.2, 134.2, 133.7. The three agree.

## 2. The rooms and the Dressing (verify-world-04, verify-code-04)

- **The rooms** (`crowd_room.gd`, `test_room.gd`) build their boxes in loops, so `RoomKit.resolve_coplanar(geometry)` decides who yields once the room's boxes are all in (the same rule as the level's solver: the bigger box wins, then the earlier one), clips the smaller box's mesh with the same `MeshClip`, and records what it left out in a meta (`RoomKit.CLIPPED_META`) for the scan. 17 and 2 slivers (up to 0.3 m2: floor joins at y 0, curb and lintel tops at y 6, 8, 9, 2.4, 1, 5) are now 0 at 0.02 m2, and `ROOM_MIN_AREA_M2` is gone. Not taken: building the rooms' boxes as `InsetBlock`s (the collider snapshot's paths and the code-built rooms' structure would change; `tests/test_m6_colliders.gd` holds them).
- **The Dressing** is in the scan now (every `KitPiece` is a box, its mesh's bounds). The seven pairs the review found (wall tops against cornice tops at y 11) were the wall mesh's plinth boards stretching its bounds 5 cm toward the cornice, not real overlaps: the scan takes a `LevelBlock` as the box it draws (its size), so they are gone without a change. Where a piece does share a plane (cornice ends against a wall's end), the piece wins and the block yields: the solver found no pair of two pieces.
- Old -> new in `tests/test_m6_feedback_ground.gd`: `ROOM_MIN_AREA_M2` 0.5 -> `Scan.MIN_AREA_M2` (0.02), the same two tests; `test_an_inset_block_draws_smaller_and_collides_as_the_box` (asserted the pulled-in faces) -> `test_an_inset_block_collides_as_the_box_and_draws_the_box_less_what_its_partner_draws` (its twin on the visible path: the + z face's drawn area is the face less the overlap), `test_the_clipped_face_keeps_its_strips_uv_where_it_is_cut`, and `test_the_scan_finds_a_pair_a_step_and_a_hole_and_passes_a_clean_yield`.

## 3. The guard (verify-world-01's test)

`tests/m6_coplanar_scan.gd`: `pairs()` subtracts what a face leaves out; `holes()` reports a cut rectangle nobody else draws; `steps()` reports two overlapping boxes whose faces of one direction are 5 to 50 mm apart where the nearer covers part of the farther and leaves at least 0.02 m2 of it in view. It must fail on `d582d21`: with that commit's `InsetBlock` and scenes, 27 steps (the catwalk's `Terrace/RightAWall0` against `Catwalk/EndWall0`, 22 m2 covering, 8.2 m2 left, the lintels' ends, the door jambs...), 0 on this build. Exempt, by design: a rail's post (look `fence`) stands inside its curb and a barrier's panel hangs in front of its opening (22 and 3 hits at baseline; neither was a flush face).
Not taken: a step scan that flags a face and its pulled-in twin (the first design): InsetBlock no longer pulls a face in, so there is no twin; the generic scan also guards against anyone putting the step back by hand.

## 4. INSET_STEP_M (verify-code-05)

Deleted with the tiers (a face now yields over a rectangle, not by a step). The two numbers the block still needs (what counts as one plane, and how far a standoff goes out with its face) are Tuning values, `kit_coplanar_m` 0.004 and `kit_clip_standoff_m` 0.06 (Level > Ground).

## 5. The ground's mirrored pair (verify-world-03): tried, not kept

The mirror makes a feature at height `v` (of the tile, 0 to 1) and its reflection `2 min(v, 1 - v)` tiles apart across the fold: 8 m only at v = 0.5, so "at least 8 m" is not reachable for more than one row of features. I moved every strongly shaped feature (the two patched squares, the manhole, both grates, the five cracks) into rows 0.3 to 0.7 (separation at least 4.8 m, the rows next to the fold plain road) and recorded the drift act.

| | still | creep | pan | walk |
| --- | --- | --- | --- | --- |
| A1 before | 0.0291 | 0.1166 | 0.4985 | 1.1179 |
| A1 moved | 0.0239 | 0.0998 | 0.3831 | 1.1737 |
| A2 before | 0.0014 | 0.0192 | 0.0546 | 0.4442 |
| A2 moved | 0.0283 | 0.0950 | 0.5443 | 1.2768 |

A2 looks along the street at the fold itself (z -24), so a feature in rows 0.3 to 0.5 now stands in its view: its drift numbers rise (the walk 2.9 times). The brief's own condition was that they do not, so the old layout stays and `gen_trim.gd --check` holds on it (`ground_sheet.png` unchanged). Not tried: a second ground layer, or a tile 4096 px over 16 m (FB-GROUND call 4: a perf run of its own).

## 6. The near deck (the reviewers' note)

"Look: ground drift" `-- --ground=held`, the shader's footprint measure (`fade_texels`) as the mean side (now) against the longer side (the pre-FIX-WORLD one), same build, d1 `still`/`creep`:

| view | mean side | longer side |
| --- | --- | --- |
| gap | 0.0721 / 0.3639 | 0.0721 / 0.3639 |
| deck | 0.1464 / 0.7364 | 0.1464 / 0.7364 |
| deck_far | 0.0922 / 0.1331 | 0.0919 / 0.1328 |

No difference to four digits: the near deck's creep (0.736, the act's highest) is not the fade; it is the capped mip's seams and the deck's own ink under a 1 degree a second creep, and the longer side would hold it no better. Nothing to floor, so the mean side stays and the default fade (16 to 64 texels) too. The reviewers' worry (the mean goes to 0 at an extreme graze, so the fade never starts) does not show in `deck_far`, the deck looked along at 4 degrees: its d1 is 0.09 with either measure.

## 7. Perf

Not re-measured: the draw count does not change (an `InsetBlock` is one mesh as before), and a clipped mesh has a few more triangles (the cut triangles of 89 blocks and 21 room boxes; each block's mesh is now its own, not the shared cached one). Open: run `tools/perf_compare.sh` on a quiet machine.

## Requests (files not mine)

None.

## Departures

None.
