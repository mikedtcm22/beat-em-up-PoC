# fix-final-perf: judgement calls and numbers

Finding: final-perf-01 (the level walk +19.5% mean against 910448e, first hit +4.9 ms).

## What the cost was

The machine's load (3 to 17 from other apps) makes wall time worth little, so the work was measured with a fixed-pose act and the renderer's counters first (`"Perf: counters"` in `tests/bot/level_acts/perf_acts.gd`: the arena tour's poses, AI frozen, each held 90 ticks, then 40 frames counted; `perf_compare.sh` prints the means). Experiments switched things off at the poses and took the minimum of several interleaved runs.

- **Shadows were the larger share of the gap**: with every shadow off the poses cost about what 910448e does; the other share was the visible pass.
- **The trim material was the cause.** `trim.gdshader` wrote `ALPHA_SCISSOR_THRESHOLD` (for the chain-link's wire) on one branch. A shader that writes it, even on a branch, is an alpha-clip material to the renderer: no depth prepass and the whole fragment (a gradient fetch from the 2048 px sheet, the toon lighting) run in every shadow cascade, for every one of the level's 330 kit meshes, where 910448e's flat boxes took the shared opaque path. Making the material opaque (a throwaway shader without the scissor) took the fixed poses from 143 to 132 ms (minimum of runs; 910448e 113).
- **The props' shadows**: a car, a tank, a dumpster and an AC unit are 2800 to 3000 triangles each and were drawn whole into each shadow cascade (910448e's boxes were 12). The shadow pass's primitives per pose were 2.3 times 910448e's.
- Not a cost: visible LODs of the props (200 000 fewer primitives, no measurable time), the props' hull (removing it: no change), far visibility ranges on the props (about 10% of the primitives, nothing in time).

## Calls

1. **The trim material is split in two shaders, opaque and scissor, sharing one body.** Decision: `trim.gdshader` (opaque) and `trim_scissor.gdshader` (`#define TRIM_SCISSOR`) both include `trim_body.gdshaderinc`; `ToonMaterials.trim()` is the opaque one and `ToonMaterials.trim_scissor()` the wire's; `KitMesh` puts the faces on a scissor strip in a second surface (`chainlink` and `gate`: posts and rails on surface 0, the wire on surface 1). Not taken: one shader with the scissor behind a uniform (the compiler decides from the code, not the uniform); a second mesh instance for the wire (a node per fence); dropping the chain-link's scissor (a visible change). D10's "one trim material" now reads "one trim material and the wire's variant"; the draw count follows the mesh count plus one per fence. Tests: `test_kit.gd` (surface counts, which surface wears which material, "only the scissor strip's faces wear the scissor shader"), `test_m6_perf.gd`. `test_m4_contracts.gd` reads the include now (its string check on the shader's code moved with the body).
2. **A prop's shadow is cast by a coarser twin.** Decision: `StaticArt` builds, per mesh, a shadow-only twin (`SHADOWS_ONLY`, the same material and vertex format, the mesh's coarsest level of detail within `draw_prop_shadow_error_m`, 0.12 m by default: about half the triangles of a car, a tank, a dumpster; an AC unit has none within it) and the drawn mesh stops casting. Levels come from `ImporterMesh.generate_lods` at build time (the GLB import has `generate_lods` off by contract, for the characters). Not taken: the renderer's `ArrayMesh.shadow_mesh` (built and set; the primitives did not move: it is ignored for a material with a vertex function, which the toon shader has); levels of detail on the drawn mesh (no measurable time, and the palette's per-face UVs can smear across a collapsed edge); a larger error (the shadow of a car 20 cm off is a shadow somebody sees). Tunables: Level > Draw cost (`draw_prop_shadow_error_m`, `draw_prop_lod_merge_deg`, `draw_prop_lod_split_deg`). The prop shadow's primitives per pose: 1.05M to 0.66M over the 14 poses.
3. **Shadow casting stays on for windows and the skyline.** Tried and recorded (tour before and after, same frames): windows off and skyline off. Windows' shadows are a dark band under each sill and beside each frame (about 45 levels over 13 000 pixels of a2_doors); the skyline's facades throw a large shadow across the street's walls. Both are seen, so both stay. The tour after the final change is pixel-identical (PSNR infinite) at 15 of 20 poses and 56 to 80 dB at the other 5 (the prop shadows' few pixels).
4. **Occlusion culling was tried and dropped.** One `OccluderInstance3D` per solid wall, floor and slab block, inset 15 cm, with `Viewport.use_occlusion_culling` on halved the visible primitives, but in the tour the roofs' drop pose lost the skyline and the cars below it (a gray void where the facades are). Not shipped: a culling that can hide what is seen is not "no visible change", and finding why would cost more than its 10% was worth.
5. **The glint's `_process` is left as it is.** It early-outs when no weapon is lying (`wanted()`), and pushes seven shader parameters only while shown; nothing in the walk measured on it.
6. **The first-hit and first-finisher hitches** (first hit +4.9, finisher +4.8 ms) are the worst frame within 0.5 s of the event; the worst frame in a window scales with the mean, and the two came down with it (see Numbers). Nothing in the audio or the damage look showed a first-use cost at a hit in the counters, so no warm-up was added (D27's warm-up of the arts is unchanged).
7. **The bench keeps its counters.** `perf_recorder.gd` adds the renderer's counters (draw calls, objects, primitives for the visible and shadow passes, the renderer's CPU time and GPU time, which Metal does not report) to the PERF-BENCH line, `perf_compare.sh` prints them, and the act `"Perf: counters"` gives a load-proof before and after. `"Perf: inventory"` (diagnostic, not a bench) lists the biggest meshes in the frustum per pose.
8. **Test changes (old -> new, with their twins).**
   - `test_kit.gd`: "one surface" -> two for `chainlink` and `gate`; "draws on the shared material" -> the wire's surface on `trim_scissor()`; "one material in the level" -> the trim material and the scissor variant (twin: `test_only_the_scissor_strips_faces_wear_the_scissor_shader`).
   - `test_m6_dress.gd`: a prop's meshes must wear the hull -> except the shadow-only twins (they draw nothing).
   - `test_level_bot.gd`: the act list gains the two perf acts.
   - `test_m4_contracts.gd`: see call 1.

## Numbers

Fixed poses (`"Perf: counters"`, 14 poses, windowed, vsync off), sum of the 25th percentile frame time, minimum of runs, interleaved:

| | 910448e | HEAD before | after |
|---|---|---|---|
| ms (sum over 14 poses) | 113 | 143 | 132 |
| draws per frame (visible) | 2425 total | 1181 total | 1202 total |
| visible primitives (sum) | 448k | 1 159k | 1 159k |
| shadow primitives (sum) | 450k | 1 051k | 662k |

The level walk, `tools/perf_compare.sh --force --runs 4 --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" 910448e HEAD`: see the report below.
