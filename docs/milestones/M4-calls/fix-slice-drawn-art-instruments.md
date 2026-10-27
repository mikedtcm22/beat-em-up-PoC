# M4 calls: fix-slice-drawn-art-instruments

The slice gate's fixer for the instruments and the warm-up (slice-g1-01, slice-g1-03, slice-g1-06, slice-g2-05): the measurement code and the load-time warm-up follow what the lens draws. Every item is a test or presentation fix; no game state, tunable, move or asset changed. Each call is the decision, an alternative not taken, and why. The ARCHITECTURE sentences for the lead are in `SG-instruments.md`.

**C1. A flip is a triangle folded in the pose and not at the skinned rest ("turned over"), not any change of sign.**
- *Decision.* `flipped` counts triangles that are folded against their skinned vertex normals in the pose and were right at the skinned rest. The reverse (folded at the rest, right in the pose) is reported as `flipped_healed` and printed, not counted. The brief's words were "the sign differs from the sign at the skinned rest"; the numbers it expected (elbow 41-45, knee 60-63, twist 48-59) are the turned-over counts, and measured both ways the "differs" rule adds 2-27 healed triangles per flex (twist on `punk`: 54 turned over, 77 differing, over the 75 bar).
- *Alternative.* The literal sign-differs rule.
- *Why not.* A triangle the mesh has wrong at the rest and a pose happens to set right is not a deformation defect, and charging it is the baseline error the finding is about, reversed. Both numbers are printed, so the gate can use the other.

**C2. The squash half is unchanged; the flip's reference is built once and shared.**
- *Decision.* `SkinnedView` gets `rest_pose()`, `folded_mask()`, `flip_counts()` and `folded_triangles()`; both `SkinnedView.strain()` (new optional `rest` argument, default the rig's rest pose) and `test_art_punk._strain` count flips through them, so the two cannot drift. The test keeps its own squash (against the skinned rest); `SkinnedView.strain()` keeps squashing against the authored mesh, as before. `test_skinned_art`'s probe fixtures have baseline 0 and stay green.
- *Alternative.* Fix only the test's copy.
- *Why not.* F-punk reuses `SkinnedView.strain()`; it would have had the same constant offset.

**C3. A7's bar stays a printed gate, with one guard test on the metric.**
- *Decision.* The peak flexes print `GATE` over the 75-triangle bar, as the file's rule is (a bar is asserted only where all four GLBs pass it). The new tests assert the metric (a mesh posed at its own rest has no flips, however many folded triangles it carries; `test_skinned_art` winds 40 blended triangles against their normals and expects 0 flips in every peak pose, and a 50% blend still flips triangles) rather than the GLBs' numbers.
- *Alternative.* Assert elbow, knee and twist under the bar on all four GLBs.
- *Why not.* F-punk replaces `punk.glb` in place; asserting the smoke asset's numbers would fail its work for a measurement it did not break.

**C4. SkinnedView's default pose is the drawn one; `hurtbox_fit()` stays FK.**
- *Decision.* `drawn_pose(rig)` (ragdoll `visual_pose(i)` while `rig.is_ragdolling()`, else `animation_pose(i)`) is the default of `_skin_matrices`, `_pose_key`, `_soup` and so `skin_vertices()`, `skin_normals()`, `faces()`, `strain()`, `hits()`, the soups and both `compare_*` wrappers. `fk_pose(rig)` is the FK pose always. `hurtbox_fit()` passes it explicitly: its axis points come from the FK hurtboxes, so the art it is fitted to is skinned in FK too.
- *Alternative.* A `globals` argument on `hits()` only, or one more parameter on every wrapper.
- *Why not.* `hits()` casts at every rig under a root, so one pose array does not fit; the pose is a property of the rig, and the default that matches the screen is the one an L5 evidence act should not have to ask for. A rig that is not ragdolling returns the FK pose bit for bit, so no existing measurement changed.

**C5. R4 counts what R8 counts.**
- *Decision.* `_sample_occlusion` skips a mesh unless `FPView.is_drawn(mesh)` (not `is_visible_in_tree()`), so an art rig occludes through its view proxies. The new test puts two Street Punks in a line with the art on (and the A/B off as a control) and expects share 1.0 and a `miss`; it fails on the old filter (0.0).
- *Alternative.* Ray-cast the skinned art for R4 (SkinnedView, 12-14 ms a sample).
- *Why not.* A4 says the probe measures the proxies; the art's cost does not belong in a long headless act. R4 on "Six Punks, fight" is unchanged at 0% of 13, as is R8.

**C6. The warm-up places the holder on the second frame, hidden until then, and scaled to a speck.**
- *Decision.* Verified in 4.7.2 with a windowed replay: `process_frame` fires before any `_process` (the camera director and its cameras run at process priority 50, after the default nodes), so after one `await process_frame` the camera is at the origin with an identity basis. `warm_up()` now awaits twice before it reads the camera, keeps the holder `visible = false` until then, and shows it after setting its scale to `camera.near`. It stays two frames in the lens and is freed after them, as before. Placement constants and the materials are untouched.
- *Alternative.* `RenderingServer.frame_pre_draw`, or the player's `get_eye_transform()` and look basis through `RoomKit.warm_up_art`.
- *Why not.* A transform set in `frame_pre_draw` comes after the scene tree's own flush of transform notifications (as I read the engine; not tested here), so the holder would at best lose one of its two frames; computing the spot from the player repeats the camera's own placement (view_from_eye, the move offset, the floor clamp) in the instrument. Reading the camera after its first update is the one line that is right whatever moves it.
- *The scale is a finding of the fix.* With the holder in the lens at full size, the first frames of a boot capture show a metre white box in the lower middle of the view for two frames (the hull boxes are unit boxes; seen in `captures/fix/boot_fixed`). The warm-up wants the draw, not the picture (a pipeline is built by the draw call, whatever it covers), so the holder is the size of the camera's near distance (5 cm: a speck under the HUD in the same frames). The camera's own near distance is used so no number is added to the script. Not measured to help or hurt the first-spawn hitch: the lead re-measures first spawn and first hit after the merge (`perf_compare.sh` was not run here).

**C7. W1 replays a cold load in a SubViewport; the training room passes without the fix.**
- *Decision.* The room's own load is cold once per run, so the act clears the warm-up's two flags and loads each room afresh into a `SubViewport` with `own_world_3d` (nothing of the bot's room is touched, the recording stays the bot's view), from a physics frame (before the frame's process step, as the game's start is: a load from a `process_frame` has the camera placed before the warm-up first looks). The room's director is handed the new room's player (it finds the first in the group, the bot's), and the camera is as cold as at the game's start. Each frame the holder is drawn (`frame_pre_draw`), the `ART_GROUP` meshes' AABB and the five boxes under the holder are tested against `camera.get_frustum()` (all eight corners outside one plane = out), after a sanity check of the test (a point 2 m ahead is in, one 2 m behind is out). The line to quote is `LOOK-WARM <room>: OK|FAIL ...`; a headless run prints `LOOK-WARM skipped` and nothing else.
- *Alternative.* Reset the camera to the identity in the bot's own room and re-run the warm-up in place; or an observer on the game's real boot.
- *Why not.* The first covers one room; the second needs a hook before the bot's first act exists (`acts()` is read after eight ticks, the holder is gone by frame 4).
- *Result.* Crowd room: unfixed FAIL (0 of 2 art, 0 of 10 boxes; the holder at (0, -1.2, -2.5), the finding's numbers), fixed OK (2 of 2, 10 of 10). Training room: OK both ways. The unfixed holder lands 2.65 m under the lens at a 3.8 m distance from a camera that starts at x -3.8 looking along +X, and the body is partly in the view by luck, so the act does not discriminate there; it is a check of the placement, not proof of a pipeline compile. The act adds slug `w1` after `p1` (`test_look_acts.gd` pins the order; a headless test runs it and reads the skipped line).

**C8. Not done, by instruction or by decision.**
- Fold removal in the chain is F-punk's (a brief line; the chain report may add the folded count).
- No `tuning_data.gd`, ARCHITECTURE, M4-plan, README or HANDOFF edits; no `perf_compare.sh` run.
- The L5 evidence act is P3-int's: `SkinnedView.drawn_pose()` and the default pose source are the path it needs.
