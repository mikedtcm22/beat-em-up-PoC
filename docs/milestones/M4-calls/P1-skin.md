# P1-skin: judgement calls

Package P1-skin (phase 1): `SkinnedArt.attach()` and `check()`, the view proxies' measuring, the ragdoll write-back, `look_show_art`, the strain test. Each call: the decision, an alternative not taken, why.

## C1. One path for both bind routes, `check()` tests the chain
- **Decision.** `bind'_n = Scale(s) * Transform3D(Basis(R_n), p_n)^-1` for every art, with `R_n` the shortest arc from the table's first-child direction to the GLB's, leaves taking the parent's, Root and Hips identity (A3). A table-authored GLB gets `R = identity` out of the same code. `check()` holds `|p_c - (p_n + R_n * (table_c - table_n))|` to 1 mm for every bone, so a GLB passes only when each joint sits where the swing chain puts it (the shortest-arc `R` makes the first child of each bone satisfy it by construction, which leaves the bone lengths, and for Hips and the non-first children (shoulders, legs) the direction, to the 1 mm).
- **Alternative not taken.** Compare each joint with the table (Part C §2.4): it fails every A-pose GLB. Take `R` from the glTF bone axes: the codemap (blender-godot §6.1) showed the roll shreds the mesh.

## C2. A bad art attaches nothing, the rig keeps its primitives
- **Decision.** `attach()` returns `[]` and pushes one warning when `check()` finds anything; `HumanoidRig` keeps the primitives visible (S0's C4). No scene attaches nothing silently (S0's tests build such arts). A budget of 0 fails any mesh; a missing palette or UV1 fails too (the art material samples both).
- **Alternative not taken.** Attach with a warning: an art with a `neutral_bone` or unweighted vertices draws garbage that the placeholders would not. An invisible body is worse than a blocky one.

## C3. The FP-hidden art mesh is not in `_head_meshes`
- **Decision.** The art meshes live in their own list; `SkinnedArt` tags the `*__fp_hidden` one with a meta and `_apply_layers()` reads it. `set_art_shown()` keeps swapping `_head_meshes` and `_body_meshes` (the primitives) with the art, which an art mesh in `_head_meshes` would have hidden.
- **Alternative not taken.** Plan §2.4's "joins the rig's head list": it collides with S0's `set_art_shown`.

## C4. Write-back: every bone's rotation, only Hips and Root positions
- **Decision.** `Ragdoll._process_modification_with_delta` writes `local.basis`'s quaternion for every bone and the position for Root and Hips, when `rig.has_art()`. The other bones' offsets are the table's and the simulator does not change them.
- **Alternative not taken.** Writing every position too: no gain (0.0000 m in the probe, codemap §0.3), and it would put the simulator's tiny joint stretch into the skin.
- **Shown.** The probe modifier after `Ragdoll` reads the skeleton at 0.0000 m of `_visual` in a stagger, a launch out of a stagger and a full ragdoll; with the write-back off the raw simulator output is more than 1 cm off in a stagger (the control). A primitive rig's skeleton is untouched and its followers equal an art rig's.

## C5. The fixture is the primitives baked, not one capsule per bone
- **Decision.** `tests/fixtures/skinned_probe_art.gd` bakes every primitive of `PlaceholderBody.parts()` into one skinned mesh (the player's FP-hidden parts into `Body__fp_hidden`). With the arms swung 45 degrees (`A_POSE`) or hanging (`REST`), rigid or gently blended. It is "procedural, in code, the A-pose and the table variants" as briefed, and a superset of one capsule per bone: the art at the rest is the primitive body, so a skinned vertex can be compared with the same primitive's vertex at any pose to 0.2 mm, and the first-person framing with the proxies' to tessellation.
- **Alternative not taken.** One capsule per bone: its skinned positions have no independent expectation (only "follows FK", which the primitives' followers already prove), and A9 could not be run on it at all.

## C6. A9 on the fixture: FPView's looseness
- **Decision.** The art stood up to 7 cm nearer the lens than the proxies in 1 m poses with the probe, though its vertices are the primitives' to 0.2 mm. The cause is FPView: it models the cap (a hemisphere) as a flat full ellipsoid and a capsule seen along its axis by its closest approach, so its proxies are looser than the primitives as drawn. `SkinnedView.framing_problems()` keeps the plan's 2 cm as its default for GLBs; the fixture tests hold it at 7 cm (`FPVIEW_LOOSENESS_M`) against `FPView`, and at 5 mm and 0.5% of the cells against `compare_with_exact_proxies()` (a TriangleMesh of the proxies' own triangles, cast the same way), which is the art measuring itself. The "nearest" figure is the second-largest gap over the cells, so one cell on a silhouette edge is no bulge (a real bulge covers many).
- **Alternative not taken.** Fix FPView's dome and capsule: it changes M1-M3's tuned numbers (lens shares, wind-up occlusion), and A4 says the proxies keep measuring "the rig's tuned shapes". Relax A9 for everyone: the rule is the guard against art poking into the lens.
- **For F-punk and F-player-int.** Their GLBs go through `SkinnedView.compare_with_proxies()` and `framing_problems()` at 2 cm; where FPView's looseness shows against a fitted mesh they decide with the gate (the exact-proxy comparison says whether it is the art's or the proxies').

## C7. The strain test (A19): what it measures and how
- **Decision.** Every unique edge's posed length over its rest length (the authored mesh at the rig's scale: the A-pose route's distortion at the rig's rest counts), p0.1 and p99.9 over all edges, min and max, the lowest vertex in a planted pose (the lowest of the six sole points at 0, within 2 mm), and at the peak flexes (guard, elbow 150, arm raise 140, knee -130, spine twist, lying) the triangles under 15% of their rest area or flipped (face normal against the skinned vertex normals) at most 0.5%. Edges whose two vertices sit on one bind alone are exactly 1 and not measured, only counted, and edges under 0.1 mm at rest (sphere poles) are not measured either: the run is 2.4 s for 3 fixtures, 245 samples each. Both ends of the range are checked (p0.1 above 0.6, min above 0.4), since compression is the candy-wrap.
- **Phases.** start, 25%, peak, 75%, end: for a move the peak is the middle of its active frames, for an animation the middle of its length.
- **Controls.** A wide blend (50% over 6 cm) fails many samples and flips or collapses triangles; a body 5 cm too low fails the floor rule. The smooth probe's blend is gentle (10% at the joint) because the primitives' edges are centimeters long and a wide blend stretches them past the range at idle.
- **Alternative not taken.** All edges every sample (6x slower, same numbers); rest = the arms-down pose of the same mesh (hides the A-pose route's shoulder tearing at the rest, which the gate's A/B is about).

## C8. P1-chain's probe body: reported, not asserted (a finding for the gate)
- **Decision.** `probe_body.glb` and `probe_body_rest.glb` pass `check()`, attach as a player and a Punk at 1.8, 2.05 and 2.3 m, stand on the floor at the rest (the lowest vertex within 5 mm) and their rigid vertices follow the bind formula. Their A19 run is printed (worst ten) and asserted only for NaN and the floor, because they do not pass the deformation numbers and are a stress body, not shipping art:
  - the A-pose GLB: 463 sample problems over 236 samples. At idle p99.9 is 2.08 and p0.1 0.45 (P1-chain's own report says 2.03 for the same rest), the worst edges collapse to 3-8% (arm raise 140 at the right upper arm x0.03, thrown x0.03 at the left upper arm), and 55-184 of 10,022 triangles are squashed or flipped at each peak flex (guard 102, elbow 150 99, arm raise 184, knee 63, twist 55);
  - the arms-down bake: 357 problems; idle is nearly inside the range (max 2.25, min 0.46) but walking reaches p99.9 1.96 and x3.3, and the same shoulders collapse (arm raise x0.04, 177 triangles).
  Both are the arm chain at the shoulder: the auto weights from P1-chain (`weights: auto`) blend the upper arm, shoulder and chest hard. Weight smoothing at the shoulders, or Tripo's weights, are the gate's contingencies (A15 (b)).
- **Alternative not taken.** Assert the A19 numbers on the probe body: the suite would be red for a body that is not the product. F-punk and F-player-int add their GLBs to `_strain_run()` with `run.problems` asserted empty.

## C9. Cost of an exact sample, and a test that cannot flap
- **Decision.** `SkinnedView.hits()` for a 15k-triangle art takes 11-14 ms best case on this M1 headless (median 12-16 while other builders ran, load 6-8): skinning, soup, BVH and 1296 rays. The test takes the best of nine, up to three rounds, at 15 ms. Built from the plain version it was 17-19 ms: the grouped soup (one native transform per bind, the blended triangles by hand), the frustum cull of groups and the box test per ray cut it by a third; the BVH build (5-7 ms) is the floor.
- **Alternative not taken.** A median threshold (flaps under load); per-bind rest-space BVHs built once (the ray count per cell makes it slower in GDScript); a smaller grid (A4 names 48x27).

## C10. Face normals from the winding
- **Decision.** `TriangleMesh.intersect_ray()` returns a normal that always faces the ray (checked: the same triangle from either side), so a back face cannot be told from it. `SkinnedView` keeps the soup and reads the winding (`Plane(a, b, c).normal` against the ray). A lens inside a limb then skips the back faces as the camera does; a point inside the art (row A6) is one whose axis ray leaves through a back face.
- **Alternative not taken.** Trust the reported normal: the A9 numbers would count the far side of a limb the lens is inside.

## C11. A6, A11 and the anchors on the probe
- **Decision.** `hurtbox_fit()` (axis points inside, the shares of torso, leg and head vertices near their hurtbox) and `surface_gap()` (the flash anchor's distance to the skinned surface) are shared helpers with a test on the probe, whose numbers are the primitives': torso 93% (the upper-chest box is wider than the hurtbox), legs 97%, head 98%, the leg hurtbox's mid-axis point outside at the bent knee (a notch between the two capsules), and the flash anchors within 3 cm of what they were on the primitives. The plan's 95% and 2 cm are for the fitted Punk (F-punk, SL-int); the fixture does not claim them.
- **Alternative not taken.** Hold the primitives to numbers they do not meet, or leave the rows without a harness.

## C12. A/B act
- **Decision.** `Look: skin probe` (first person), `(side view)` and `(primitives)` (the first with `look_show_art` off) in `tests/bot/acts/skin_acts.gd`, on a Punk wearing the probe (`tests/fixtures/skin_punk.tscn`): idle, the jab and cross, a stagger, a knockdown and its get-up, a KO whose rig blinks off and in. The art and primitive recordings of the same offsets differ only in the damage-look marks the primitives show (the art is P1-toon's), the camera banner and the caption (PSNR 38 dB median over the 581 frames, 91 MSE in the first 80 from the banner); in the stagger, the launch and the lying frames the silhouettes are identical.
- **Alternative not taken.** Compare with the previous commit's capture: the VFX generator is unseeded, frames never match.

## C13. No tunables
- **Decision.** `look_show_art` (Debug, S0) is the only switch and no new tunable is added: no "Art" subgroup in Look (S0's C2). The thresholds in the tests are the plan's.
