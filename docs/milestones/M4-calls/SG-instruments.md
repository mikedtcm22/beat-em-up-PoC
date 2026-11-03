# M4 slice gate: the instruments follow the drawn body (package drawn-art-instruments)

For the lead to paste at merge. ARCHITECTURE.md belongs to the other fixer, so none of it is edited here: each block below is the exact replacement for the line named. Line numbers are those of `m4/art-pipeline` at 0a002f3. Findings: slice-g1-01 (R4), slice-g1-03 (the warm-up), slice-g1-06 (the pose source), slice-g2-05 (the strain's flip rule). The calls behind them are in `fix-slice-drawn-art-instruments.md`.

## ARCHITECTURE.md, line 569 (R4's row)

Replace the whole row with:

```
| R4 `occluded_windup_share` | every `occlusion_every` (3) frames, for each wind-up, is its chest in the lens and hidden by another enemy's mesh that `FPView.is_drawn()` counts (`FPView.ray_hit`): the same meshes R8 casts at, so a rig with art counts through its view proxies (they stand in for the art, A4, and are hidden while it shows) and its skinned ArrayMesh is never ray-cast here; by majority of the wind-up's samples; counted from the act's first frame (not the engine's frame counter), so an act samples the same frames whatever ran before it |
```

## ARCHITECTURE.md, lines 904-908 (Measuring the first-person view, A4)

After the `skin_vertices` bullet (line 905) add this bullet:

```
- **The pose.** Every call below skins `SkinnedView.drawn_pose(rig)` unless it is handed `globals`: the ragdoll's visual pose per bone (`rig.get_ragdoll().visual_pose(i)`, which an art rig writes back into its skeleton) while `rig.is_ragdolling()`, the FK `rig.animation_pose(i)` otherwise. `fk_pose(rig)` is the FK pose whatever a ragdoll shows (`hurtbox_fit()` skins in it, the hurtboxes being FK). `hits()`, its triangle soups and their pose key, and so `compare_with_proxies()` and `compare_with_exact_proxies()` (the proxies' bone followers show the ragdoll's pose too), measure the body that is on screen in a stagger or a launch.
```

Replace the `strain(...)` bullet (line 908) with:

```
- `strain(mi, rig, globals, squash_below, with_triangles, rest) -> Dictionary` and `worst_lines()`: every edge's posed length over its rest length (the authored mesh at the rig's scale), the p0.1 and p99.9 over all edges (edges on one bind are exactly 1 and not measured; edges shorter than 0.1 mm are not either), min, max, NaN, the lowest vertex, and with `with_triangles` the triangles under 15% of their rest area (`squashed`) and the flipped ones (`flipped`). A triangle is folded when its winding's geometric normal opposes the mean of its corners' skinned vertex normals (`folded_mask()`); it is **flipped** when it is folded in the pose and was not at the skinned rest (`rest_pose(rig)`, or `rest`), so the mesh's own folded triangles are a baseline, never charged to a pose (`rest_folded`; `folded_triangles(mi)` counts the authored mesh's, about 159 on `punk.glb`, and `folded_triangles(mi, rig, globals)` those at a pose). A triangle folded at the rest and right in the pose is `flipped_healed`: no defect, not in `flipped`. `tests/test_art_punk.gd` measures the same flips and the squash against the skinned rest (P1-chain C13), and prints the baseline.
```

Line 996 (the Tests paragraph): "(`tests/test_art_punk.gd`, 14)" becomes "(`tests/test_art_punk.gd`, 15)", and after "A19 (the strain against the SKINNED REST pose ... the worst ten printed)" add "; the flip count against the skinned rest (a mesh posed at its own rest has no flips, the authored mesh's folded triangles printed as `ART-PUNK A7 ... folded triangles`)".

## ARCHITECTURE.md, line 933 (Warm-up)

Replace with:

```
**Warm-up.** `ToonMaterials.warm_up()` (windowed, once per run, called from `RigPaint.warm_up()`'s gate): a toon box under every hull mode, and `skinned` (an art instance) with the art's material and hull, on a holder that is hidden for the call's first two frames and then stands in the camera's view (`WARM_DISTANCE_M` ahead, `WARM_DROP_M` below, scaled to the camera's near distance: a speck, since the draw builds the pipelines and the picture is not wanted) for two frames, and is freed. The camera is read on the second frame, not the first: `process_frame` fires before any node's `_process`, so on a room's first frame the `FirstPersonCamera` is still at the world origin with no turn, and a holder placed from it lands under the floor behind the view, where the renderer culls it and builds nothing (slice-g1-03). SL-int passes the Punk's art instance at the room's load.
```

## ARCHITECTURE.md, line 992 (RoomKit.warm_up_art)

Replace the last clause, from "and its holder stands" to the end of the bullet, with:

```
and its holder stands `WARM_DISTANCE_M` ahead of and `WARM_DROP_M` below the viewport's camera, read on the room's second frame (after the camera's first update), in the lens for two frames. The look act `W1` ("Look: warm-up in the lens", `tests/bot/acts/look_acts.gd`) checks it windowed: it clears the two once-per-run flags and loads the crowd room and then the training room cold into a `SubViewport` of its own (from a physics frame, so the load is before the frame's process step as the game's start is), and logs `LOOK-WARM <room>: OK ...` when the holder's skinned `ArtBody` AABB and its five hull boxes are in the camera's frustum on both frames the holder is drawn. Headless it logs `LOOK-WARM skipped`.
```

## Look acts table (ARCHITECTURE, wherever the look acts are listed, and look_acts.gd's header)

W1 is the new act after P1: `Look: warm-up in the lens`, slug `w1`, `cam = first_person`, no marks and no rectangles beyond `start` and `end`, no probe. `test_look_acts.gd` pins the slug order C1-C11, C13, P1, W1. P3-int adding acts to the same file adds them after W1 (or before; only the pin changes).

## What the evidence says

- W1 recorded (`captures/fix/w1/bot.log`, not committed):

```
LOOK-WARM crowd f12 holder (2.68 0.25 0.00) camera (0.18 1.45 0.00): skinned 1/1 hulls 5/5
LOOK-WARM crowd f13 holder (2.68 0.25 0.00) camera (0.18 1.45 0.00): skinned 1/1 hulls 5/5
LOOK-WARM crowd: OK the holder's skinned ArtBody AABB (2 of 2) and hull boxes (10 of 10) are in the camera frustum on 2 frames it is drawn (2 expected; 1 hidden before it was placed; frustum test sane: true)
LOOK-WARM training f18 holder (-1.32 0.25 0.00) camera (-3.82 1.45 0.00): skinned 1/1 hulls 5/5
LOOK-WARM training f19 holder (-1.32 0.25 0.00) camera (-3.82 1.45 0.00): skinned 1/1 hulls 5/5
LOOK-WARM training: OK the holder's skinned ArtBody AABB (2 of 2) and hull boxes (10 of 10) are in the camera frustum on 2 frames it is drawn (2 expected; 1 hidden before it was placed; frustum test sane: true)
```

- The same act against the unfixed `warm_up()` (`captures/fix/w1_unfixed/bot.log`) reproduces the finding: `LOOK-WARM crowd f11 holder (0.00 -1.20 -2.50) camera (0.18 1.45 0.00): skinned 0/1 hulls 0/5` on both frames, `crowd: FAIL ... (0 of 2) ... (0 of 10)`. In the training room the unfixed holder still overlaps the frustum, by luck (the camera starts 3.8 m from the same cold spot and looks along +X, so the body 2.65 m below the lens is partly in view): the act passes there with or without the fix. The crowd room is the one that discriminates.
- R4 on an autopilot crowd act ("Six Punks, fight", headless, `captures/fix/six_fight`): R4 `0% of 13` in view, R8 p50 30% / p95 45%, both identical to SL-int's `auto_six` (R4 0.0 of 13; R8 samples 165, p50 0.2951, p95 0.4479, share over 50% 0.0242). R4 reads its true figure and can now fail when a Punk is in front.
- A7 and A19 for the four GLBs, flips against the skinned rest (squashed + turned over; bar 75 = 0.5% of 14,999):

| flex | punk | punk_rest | punk_auto | punk_auto_rest |
| --- | --- | --- | --- | --- |
| guard | 117 GATE | 128 GATE | 105 GATE | 97 GATE |
| elbow 150 | 45 | 45 | 41 | 41 |
| arm raise 140 | 228 GATE | 262 GATE | 262 GATE | 264 GATE |
| knee -130 | 60 | 60 | 61 | 63 |
| spine twist | 54 | 48 | 59 | 49 |
| lying | 0 | 0 | 1 | 1 |
| folded: authored mesh / at the skinned rest (blended) | 159 / 194 (177) | 159 / 159 (142) | 159 / 179 (173) | 160 / 161 (155) |

The elbow, knee, spine twist and lying pass on every GLB. The guard fails on all four (97-128 against 75, so it is over the bar, not near it) and the arm raise by a factor of three to four. The slice gate's "missed everywhere by 2-5x" was the constant baseline (142-194 folded triangles charged as flips); with it removed, the weights/bind-route comparison reads: the four GLBs differ by less than the baseline did (guard 97 auto_rest to 128 rest; arm raise 228 punk to 264 auto_rest), so the GLB choice is not what separates the flexes, the arm-raise and guard shoulder is.
- The authored mesh's folded triangles (about 1% of every GLB) are a chain defect, not a measurement one: removing them (decimation, normal recompute) is an F-punk brief line, and the chain report may carry the count.
