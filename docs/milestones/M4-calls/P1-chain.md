# M4 calls: P1-chain

Judgement calls of the P1-chain package (A2 steps 1-3: the Blender chain, the probe body, `test_art_contract`, the smoke Punk in four variants). Each: the decision, an alternative not taken, and why. No Tripo task and no Gemini image: the fists are Blender-made. The smoke sources are P1-tools' (T1 `cb4af11c`, T3 `0366578f`).

## What was measured (the numbers the slice gate wants)

- **Probe body** (`tests/fixtures/art/probe_body.glb`, 9,986 triangles, `Body` + `Body__fp_hidden`): joints 0.0002 mm from the chained table, arm swing measured 38.0 degrees, nearest-vertex landmark residual 1.4 mm (worst joint Spine), 6 swatches, 5 inward caps. Same input, same report hash on a rerun (`run.py --check`); the generated source GLB is byte-identical across builds.
- **Smoke Punk** (`assets/export/characters/punk/punk.glb`, `punk_rest.glb`, `punk_auto.glb`, `punk_auto_rest.glb`): 14,999 triangles of a 19,510 source, 6 swatches (skin, cream, near-black, dark grey, teal, yellow), joints 0.0005 mm from the chained table, swing measured 38.7 / 38.2 degrees (Tripo's own 37.9 / 41.8 from the dump), facing found by the dump at 89.33 degrees (kept as the config override: the dump's own confidence is `weak` because the Punk's cap brim reaches behind the head), soles at -4.3 mm (the foot is re-pitched about 20 degrees by the warp), the fists' vertex-mean centroid 9.5 mm from the fist box centre and their extents within 9% of the box (the test's area-weighted centroid passes under 15 mm), 1,588 triangles each, 0 unweighted vertices, no `neutral_bone`. `run.py --asset punk --check` reproduces the report hash for both weight sources.
- **The landmark residual fails on the Punk: 2.35 cm at UpperChest** (A3: fails above 1 cm). See C6; it is not a failed fit, and it is the number to rule on.
- **Strain at the probe poses** (`report.json` `stills`; edge length against the skinned rig-rest pose; p99.9 / worst edge ratio; the poses are the guard, elbow 150, arm raise 140, knee -130, spine twist):
  - Tripo weights, A-pose route: 1.99 / 7.6, 1.48 / 2.1, 3.73 / 12.3, 1.60 / 2.9, 1.93 / 12.7. Arms-down bake: 2.03 / 7.6, 1.48 / 2.1, 4.27 / 13.6, 1.61 / 2.9, 1.86 / 12.7.
  - Heat-map weights, A-pose route: 1.96 / 5.4, 1.42 / 2.1, 2.89 / 6.2, 1.53 / 2.8, 1.87 / 9.8. Arms-down bake: 1.95 / 5.4, 1.42 / 2.1, 3.03 / 6.2, 1.53 / 2.8, 1.95 / 9.8.
  - A7's bar (p99.9 in 0.6-1.6) is met at the elbow and the knee, and missed at the guard (about 2.0), the arm raise (2.9-4.3) and the spine twist (about 1.9). The worst edges are the armpit (arm raise: ratio 0.03, LeftShoulder / LeftUpperArm), the vest collar between Neck and RightShoulder (spine twist: 12.7) and the jeans hem (guard: 7.6, Tripo weights only).
  - The A/B sheet (`report/stills/ab_weights_x_route.png`) shows no visible winner at that size. The heat-map weights have lower worst-edge numbers everywhere (5.4 / 6.2 / 9.8 against 7.6 / 12.3 / 12.7) and a lower arm-raise p99.9; the A-pose route is no worse than the bake (a little better at the arm raise: 3.73 against 4.27 with Tripo weights).

## The chain

### C1. The first-person split runs after the palette step, not before it
- **Decision.** `blender_parts.py` has two modes, `replace` (the fists) before `blender_palette.py` and `split` (the first-person cut and the caps) after it. Order: inspect, fit, rig, parts replace, palette, parts split, export.
- **Alternative not taken.** Part C §5's order (parts, then palette, with `split_fp` inside parts). **Why not:** the decimation would move and merge vertices on the cut loops, and a cap needs no texture. Splitting the final low-poly mesh gives clean planar loops, caps that never meet a decimator, and a cut that is the same in the dense and the shipped mesh.

### C2. The importer's split vertices are welded in the inspect step
- **Decision.** glTF import duplicates a vertex wherever its UV or normal differs, so a UV seam looks like an open boundary. `blender_inspect.py` merges vertices by position (1e-5 m) right after the join; UVs live on loops and survive.
- **Alternative not taken.** Leave the mesh as imported and weld inside each step that needs topology (fists, split, palette borders). **Why not:** every step would repeat it, and the first test showed the boundary count of the smoke body going from 5,704 edges to a clean cut.

### C3. The proportion warp is numpy linear blend of per-bone affine maps, not Blender pose bones
- **Decision.** Each of the 22 bones maps its source segment onto its target segment: rotate by the shortest arc, stretch along the bone only (`M = R (I + (s - 1) u u^T)`), translation so head goes to head. Vertices blend the maps by weight (the source rig's own, or Blender heat weights on a temporary armature). Girth is never changed. The topology is untouched, so the source's weights stay valid for `tripo`.
- **Alternative not taken.** Pose the temporary armature and apply the modifier (the plan's wording). **Why not:** a stretched parent leaks its non-uniform scale into its children's pose matrices (Blender's inherit-scale modes), so "stretch along each bone only" is not what the pose does; the explicit maps are what the plan describes and are exact at every joint.

### C4. The arm swing is measured per side, and every arm chain is one straight limb
- **Decision.** The swing is `unit(Hand - UpperArm)` in 3D, per side, from the rig's landmarks (config `fit.swing` can fix an angle). `pipe_common.chain_joints` puts LowerArm and Hand along it at the table's bone lengths (A3's chained joints). A forearm that bends in the source is straightened by the warp (the forearm bone is rotated onto the chain).
- **Alternative not taken.** Take the table's 45 degrees, or keep the source's bent forearm. **Why not:** the Tripo arms hang at 38 degrees and the plan asked for the measured angle; a straight chain is what makes R_UpperArm = R_LowerArm in SkinnedArt's formula and what the contract test can check in one line.

### C5. The soles go to z = 0 by moving the ankle landmarks, and the torso landmarks are regularised
- **Decision.** The Foot and Toes landmarks are put 0.085 / 0.035 m above the lowest foot vertices, so the sole offset below the ankle is the table's. `fit.regularize` (Spine, Chest, UpperChest) puts those three landmarks at the table's proportional places between Hips and Neck: Tripo's UpperChest sits 9 cm lower than the table's, which made the neighbouring bones stretch 1.29 and squash 0.64; they now all stretch 0.90.
- **Alternative not taken.** Translate the finished mesh up by the sole error, and map every Tripo joint exactly. **Why not:** a translation moves the mesh off the armature; exact mapping of mismatched torso joints distorts. The Punk's soles still end 4.3 mm below zero (the Foot bone's 20 degree re-pitch lowers heel and toe), inside A4's 5 mm.

### C6. The landmark residual is the nearest-vertex blend, and it fails on the Punk
- **Decision.** For each joint, its source point is warped with the weights of the nearest vertex and compared with its target. That is what "the landmark-warp residual of the mesh" can mean when every bone's own map is exact at its joint. Probe: 1.4 mm. Punk: 2.35 cm at UpperChest (1.2-2.4 cm at the torso and shoulder joints, 0 at the limbs). It does not fall with the torso regularisation or with heat weights for the warp (2.3 cm): the cause is the Tripo torso bones' own tilt (8-17 degrees against the table's vertical), which neighbouring maps rotate differently inside the body.
- **Alternative not taken.** Measure each landmark with its own bone (0 by construction), or raise the limit. **Why not:** the first hides a real cross-talk and the second is the lead's call. `test_art_contract` asserts the residual for the probe (a gate on the chain) and prints the Punk's; the report keeps `residual_ok: false` for it. Open risk for the gate: decide whether 1 cm is the bar for a generated torso.

### C7. The weights: `tripo` is the default, `auto` is kept, smoothing was tried and dropped
- **Decision.** `rig.weights: "tripo"` gives `punk.glb`; `"auto"` (heat map from the project armature with Root not deforming while it solves) gives `punk_auto.glb`. Both: vertices with no weight take their nearest weighted vertex's (KDTree), at most 4 influences, normalised, nothing on Root, groups in table order. Game-boy's rule is Tripo's rig first. The probe uses `auto` (its source weights are Blender's own).
- **Alternative not taken.** `rig.smooth_iterations` (Laplacian smoothing over the edges, kept as an option, off). **Why not:** at 3 and 8 iterations the worst edge went from 5.5 to 22 and the p99.9 did not fall; the 4-influence cut undoes the smoothing and makes the edges that lose a bone worse.

### C8. The bind-route variant "rest" is baked numerically
- **Decision.** `export` rotates each arm chain back to hanging about its UpperArm joint, blended by the arm weights (`w_UpperArm + w_LowerArm + w_Hand`), rebuilds the armature on the plain table and exports `<name>_rest.glb`. That is Blender's pose-apply with the same weights, without the context calls.
- **Alternative not taken.** `pose.armature_apply` and `modifier_apply`. **Why not:** the same result with headless context fragility.

### C9. Palette: Lab-nearest swatches, border-protected decimation, relabel from the dense mesh
- **Decision.** Each face takes the nearest swatch (Lab, 3x3 texels around its UV centre) among config `palette.slots`; faces with `pipe_slot` (fists) keep theirs (`pipe_slot = slot + 1`, 0 = from the texture, so a joined mesh's default can never read as slot 0); swatches under `min_share` fold into their nearest neighbour; two majority passes; border vertices are smoothed along the border (3 iterations, factor 0.5; fists untouched). Decimation (Collapse) protects the border vertices and the fists with a vertex group; in 5.2.2 the INVERTED group protects (weight 0 = untouched; the first trial checks protected positions survive and picks the polarity), the ratio is searched until the count is within 3% under the budget, and every face of the result is relabelled from the nearest face of the dense mesh (BVH), so borders keep their resolution and no decimated face invents a colour. UV1 "palette" is the swatch centre `((col + 0.5)/32, (row + 0.5)/2)` of the 256x16 atlas.
- **Alternative not taken.** Posterised textures or per-vertex colours (blender-godot §3.7, 1 and 3). **Why not:** the contract says one flat swatch per face; the border protection keeps the edges crisp without a texture. Mean delta-E to the chosen swatch: probe 2.6, Punk 9.4 (the Tripo texture has soft shading; p95 16.7).

### C10. The fists
- **Decision.** A rounded block of the fist box (the table's 0.1 x 0.118 x 0.116, inset 3 mm), four knuckle bumps on the striking face, a thumb on the front, a glove-coloured cuff tube that tapers from the forearm's radius to the block's width and is weighted Hand/LowerArm (smoothstep), and a thin strap ring in the accent slot where block and cuff meet. 1,588 triangles each, built hanging at the wrist then swung with the arm. The hand faces (Hand weight mean above 0.5) are deleted; the cut's radius (90th percentile of its boundary) sets the cuff's. The Punk's cuff flares to 0.083 m because the concept's glove cuffs are wide.
- **Alternative not taken.** A strap-coloured cuff, which read as a yellow bracelet on the Punk (first sheet), and a Tripo-generated fist (T9 is F-punk's). **Why not:** the cuff is the glove; the accent is a strap.

### C11. The A5 centroid is the area-weighted centroid of the fist triangles
- **Decision.** `test_art_contract` takes vertices with Hand weight at least 0.9, un-swings them about the wrist by the hand's measured direction, and compares the triangle-area-weighted centroid with the fist box (15 mm) and the extents (within 20%). The plan says "centroid".
- **Alternative not taken.** The vertex mean. **Why not:** it measured 9.5-15 mm on the same mesh, depending on how many vertices the knuckle bumps and the ring happen to have; the area centroid does not move when tessellation does.

### C12. The probe is a synthetic Tripo-like body, built and fitted every time
- **Decision.** `make_probe_body.py` makes five regions from capsules, voxel-remeshes them to one skin, unwraps and paints a texture of the region colours with shading noise, auto-weights a rig with extras (jaw, eyes, finger bones, Unity names), and delivers it off the table: 0.55 scale, centred, facing glTF +Z, swing 38 degrees, arms 8% long, legs 5% short. The chain then does everything it does to a real delivery (facing, merge of extras, swing measurement, warp, fists, palette, split). It uses the shared palette's slots only (6, 1, 5, 10, 4, 2); `48-63` stays reserved.
- **Alternative not taken.** A bare capsule body already on the table, or a committed source GLB. **Why not:** the first would prove nothing about the steps that matter, the second is an LFS binary the script rebuilds byte for byte in 6 s.

### C13. The strain reference is the finding the strain test needs
- **Decision.** The stills step reports strain against two references: `vs_glb_rest` (A19 literally) and `vs_rig_rest` (the same mesh skinned at the rig's rest pose). For the A-pose route the first is already 1.5 (p99.9) and 4.4 (worst) AT rest, because the arms swing 38 degrees down to hang; the second is 1.000 at rest by definition. **A19's literal reference fails the A-pose route at idle by construction.** The strain test (P1-skin) should measure against the skinned rest pose. Logged as a request.

### C14. Godot import params
- **Decision.** `run.py` makes Godot write the `.import` files, then sets the contract's params: `meshes/generate_lods=false`, `meshes/create_shadow_meshes=true`, `skins/use_named_skins=true`, `animation/import=false` for the GLBs; for the atlas `compress/mode=0`, `mipmaps/generate=false`, `process/fix_alpha_border=false`, `process/premult_alpha=false`, `detect_3d/compress_to=0` (the default would VRAM-compress a texture used in 3D, which blurs the swatches' exact colours). Both `.import` files are committed.

### C15. Hull normals and the shading seam
- **Decision.** COLOR `hull_normal` is the position-averaged area-weighted normal over both parts, excluding the caps (a cap's interior ring, which no other face touches, falls back to its own faces), written after the variant's final positions. The shading normals are Blender's; the cut between the two player parts has no custom normal.
- **Alternative not taken.** Custom split normals from the same average. **Why not:** untried in 5.2.2's changed API and the Workbench stills show no seam at the cut; open risk if the toon bands show one at 0.3 m.

### C16. Reproducibility
- `run.py --check` rebuilds into `assets/source/_cache/check_<id>/` (never the committed folders) and compares the report hash: the config minus its paths, every step's report and the sha256 of each exported file. Nothing in it varies between runs. The Workbench stills are outside the hash.

## Requests and open risks (for the lead and the next packages)

- **Strain reference (P1-skin's A19 test).** Measure edge strain against the SKINNED REST POSE, not the GLB's own mesh: for the A-pose route the latter is already 1.7 (p99.9) at idle (C13). The pipeline's `report.json` `stills` block has both references and the worst edges.
- **A3's 1 cm landmark residual** is 2.35 cm on the smoke Punk (1.4 mm on the probe): the slice gate decides what the bar means for a generated torso (C6).
- **A7 on the Punk's current weights** misses its p99.9 bar at the guard, the arm raise and the spine twist (see the numbers above). The contingencies the gate has: heat-map weights (a little better), edge loops at the armpit and the vest collar, a different torso warp. Naive weight smoothing made it worse (C7).
- **`.gitignore`:** the per-run Workbench stills (`assets/source/characters/*/report*/stills/*_*_*.png`, 38 files a run) and the dump copy `report/bones.json` are not committed; only the two sheets and the A/B sheet are. A line for them would keep worktrees clean.
- **Shading seam at the first-person cut** (C15) and the **Punk's wide glove cuff** (0.083 m radius at the wrist, from the concept's gloves) are for the look review at 1 m.
- **Tripo licence** is unchanged (ASSETS rows carry the note).
