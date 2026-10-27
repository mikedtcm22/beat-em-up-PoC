# Milestone 4 plan: the art pipeline proof (planner angle: rig risk first)

Planner input for the lead's `docs/milestones/M4-plan.md`, written 2026-10-26 on `m4/art-pipeline` at `85f7f39`. It reads the four maps in `docs/milestones/M4-codemap/`, SPEC §3, §5, §6, §10-§12, README's M1-M3 departures, ARCHITECTURE ("Layers", "Physics and visual layers", "Humanoid rig", the hit flash, the ragdoll) and the M3 plan.

**[V]** means verified by running something. The readers' [V]s are cited by map. Two probes ran for this plan, both from the scratch folder `/private/tmp/claude-501/-Users-arachne-repos-beat-em-up-PoC/097d610a-a8fb-4633-bbe9-6486aed195e7/scratchpad/rigrisk/`:
- `tm_probe.gd`: Godot 4.7.2's `TriangleMesh` is scriptable and fast. It has `create_from_faces`, and `intersect_ray` returns `position`, `normal` and `face_index`. On 15.7k triangles a BVH build takes 5.8 ms, 1,300 rays take 2.5 ms, a GDScript 4-weight LBS of 8,000 vertices takes 2.1 ms, and `Transform3D * PackedVector3Array` on 47k vertices takes 0.09 ms.
- `skin_probe.py`: Blender 5.2.2 headless builds an organic, single-shell A-pose mannequin from the joint table (Skin modifier, subdivision, 10 mm voxel remesh, decimate) in 0.5 s, at 12,000 triangles and 1.80 m tall. Its sole comes out 7 mm under the floor, so the soles need flattening.

---

## 0. The approach in one page

**Thesis.** M4's riskiest unknown isn't the look. It's a generated, skinned body driving a rig built for primitives. That rig has a code-built 23-bone skeleton with identity rests and arms down, 46 named animations plus 41 move clips posed by hand, table-derived hurtboxes and reaches, a ragdoll that writes only its own visual pose, a localized hit flash anchored on bone followers, damage looks that are object-space triplanar, an FP-hidden upper body on a separate render layer, and KO blink-off. On top of that, about 80 tests and the M3 readability probe ray-cast primitive meshes by name. If that path fails late, everything built on it is wasted. So the plan proves it first, before the concept pick returns, with stand-ins that cost no credits (and one 55-credit Tripo pipe-cleaner). The real Punk and the player's limbs then go down a path that's already been walked.

**The path, decided (each is defended in §13):**
1. **Fit the mesh to the skeleton, never the reverse.** The joint table (`PlaceholderBody.BONE_REST`, rest skeleton in rig-render §9(d)) stays exactly as it is. Hurtboxes, rig points, fist points, reaches, ragdoll anchors and every first-person framing rule are derived from it and were tuned and approved in M1-M3.
   - Blender warps the generated mesh onto the table: a per-segment pose-and-apply proportion fit, a sole flattened to y = 0, and fists fitted to the 0.1 x 0.118 x 0.116 m fist envelope.
   - Gates check the joint residuals (5 mm or less), the segment scale ([0.85, 1.18]), the fit to the hurtboxes, and the first-person silhouette against the placeholder's (§11).
2. **The procedural animation set animates the art.** The GLB carries mesh and weights only. A skinned `MeshInstance3D` under the existing `rig.skeleton`, with a Skin rebuilt in code, follows `HumanoidRig.advance()` at zero latency (rig-render [V]). It also works with the A-pose kept, the binds carrying the swing (blender-godot [V] through walk, guard_break and knockdown, at 1.8 and 2.3 m).
   - No Tripo or Mixamo clips are used. Tripo's auto-rig is still tried: its joints give the fit's landmarks, and its weights are A/B'd against Blender's.
   - "In motion" quality comes from deformation quality first, then enemy-only cubic easing on the named clips, then (only if the gate asks) half-joint helper bones driven by Godot 4.7's built-in `CopyTransformModifier3D`.
3. **One toon shader for every rig, primitive or skinned.** Paint materials become toon `ShaderMaterial`s. The contact flash stays the `next_pass` (unchanged mechanism), and the outline moves to `material_overlay` (blender-godot [V] on skinned meshes). The whole-body flash becomes uniforms. Damage looks become a triplanar in bind space, read from `CUSTOM0/1` that the loader fills with authoring-pose positions and normals, so the marks don't swim (rig-render [V]: `VERTEX` is skinned). KO blink-off is `rig.visible` and needs no change.
4. **The ragdoll gets one write-back.** `_visual`'s local rotations are written into the skeleton inside `Ragdoll._process_modification_with_delta`, on skinned rigs only (rig-render [V]: gap from 0.115 m to 0.0000).
5. **The tests learn skinned meshes for real.** `FPView` CPU-skins with the same binds (`SkinnedArt.cpu_skin`) and ray-casts Godot's native `TriangleMesh` (this plan [V], about 10 ms per sample for a full 15k-triangle body, about 3 ms on the 3k-triangle probe LOD). It reports bone regions, not part names. Primitive rigs keep their exact code path, so the roughly 80 primitive tests stay unchanged. A new silhouette gate holds the art to the placeholder's tuned first-person coverage.
6. **The player gets a full generated body** (from the picked hero), split at authoring time into `player_fp_hidden` (head, neck, chest, upper chest, shoulders, the shoulder half of each upper arm) and `player_body`. Each cut is closed with a rounded cap: mid upper arm and chest top.
   - The highest-detail parts are generated separately and fitted: two fists (wraps and fingerless glove) and two shoes. The 30k budget splits 16k body, 2 x 3.5k fists, 2 x 3.5k shoes.
   - The art hangs on a new `CombatActor._configure_art()` hook, not on `_configure_rig()`, which tests use to dress scratch rigs.

**Order:**
1. Phase 0, S0 (about 1 h): contracts, plus a minimal skinned stand-in Punk drawn in game behind a flag.
2. Phase 1, during the pick (six builders, at most four Godot-bound): the Blender chain on a mannequin fixture and on a Tripo pipe-cleaner of an unpicked concept; loader hardening, ragdoll and KO-view fixes; skinned FPView and the test ports; the toon shader and outlines; post and environment.
3. The rig gate: an adversarial review of the pipe-cleaner Punk in every animation at 1 m. It says "proven", or names the contingency to run.
4. Phase 2, after the pick: generate the real Punk and the hero, run them down the proven chain, the VFX pass, motion easing.
5. Phase 3: integration, perf, evidence, the final review, fixes.
6. Pause 2: Game-boy judges the Punk at 1 m.
7. Phase 4: his notes, docs, the PR.

**Resolution table (what the brief asked to resolve):**

| Question | Resolution | Where |
| --- | --- | --- |
| Fit mesh to skeleton or vice versa | Mesh to the fixed table: pose-and-apply segment fit, sole flatten, fist envelope, girth clamp on the player's arms, gates M2-M4 | R0-blender, R1 gate, §11 |
| What animates the Punk | The existing procedural set (46 named + 41 moves, Punk `punk_*`), plus enemy-only cubic easing on named clips, plus helper bones if the gate asks; Tripo presets 0 credits | R0-godot, M1-motion, R3 |
| Player full body? FP split? | Full generated body; split by weights at authoring into `_fp_hidden` / `_body`, rounded caps; fists and shoes as separate generated parts | P-player |
| Flash, damage looks, blink-off on new materials | Flash overlay stays `next_pass` of the toon paint materials; whole-body flash = `flash_color/flash_energy` uniforms; damage = bind-space triplanar (`CUSTOM0/1`), DARK unmarked; blink-off unchanged (`rig.visible`) | L1, R0-godot |
| Outline width, FP body | `material_overlay` hull, constant screen width (`width_px` x `VIEWPORT_SIZE.y/1080`, converted to metres with `PROJECTION_MATRIX[1][1]`), clamped `[min_m, max_m]`, faded past `far_fade_m`; FP body uses `outline_fp_px`; FP-hidden meshes carry their overlay and hide with it; primitive boxes use `box_mode` extrusion; the edge pass skips character pixels (ROUGHNESS flag) so lines don't double | L1, L2 |
| Tests that pin placeholder visuals | Primitive path kept as default (rigs with `art == null`); `FPView` skinned path; name helpers become bone-region helpers in the 7 real-rig files; 3 material test files ported to `ShaderMaterial` | R1, L1 |
| LFS and ASSETS.md | Existing `.gitattributes` already covers `*.glb *.blend *.png *.jpg *.webp`; raw Tripo output of rejected candidates stays local (`assets/source/tripo/_local/`, git-ignored); every file under `assets/export/characters`, `assets/export/look`, `assets/source/concepts` gets a row, enforced by `tests/test_assets_logged.gd` | S0, every asset package |
| What stays placeholder | Kicker, Pipe Thug, Bruiser, Boss, dummies (primitives under the toon shader with box-mode hulls), environment boxes (toon, muted, edge lines), the pipe (toon and hull), the HUD (code-drawn) | L1, L2, review J4 |
| Deferred "until the art is in" questions | Measured with the art in phase 3 (F-due), asked at pause 2 with defaults; nothing changes before he answers | F-due, §9 |

---

## 1. Rules every package follows (paste into every builder prompt)

- **Worktree.** Work only in your absolute worktree path, and `cd` there for every command. First run `godot --headless --import --quit` there, and again after any `.glb`, `.png` or `.gdshader` lands. Never touch the main checkout or another worktree.
- **Code rules (CLAUDE.md).**
  - Static types everywhere, tabs, `##` doc comments on public API, comment density like the surrounding code.
  - **No numbers in scripts or shaders:**
    - attack numbers go in moves via `tools/gen_moves.gd`;
    - look and feel numbers are `@export_range` tunables in your own subgroup of the "Look" group in `game/autoload/tuning_data.gd`;
    - shader uniform defaults mirror those tunables and get pushed from `Tuning` (live on `Tuning.changed`);
    - asset data (budgets, palette maps) goes in `.tres` or `tools/art/characters/<id>.json`.
  - Simulation never reads a camera. Presentation only subscribes and reads.
  - The skeleton's FK (hurtboxes, rig points, `get_point_transform`) must never see art or presentation modifiers.
- **Own only your files** (your package's list in §3). If you need a change elsewhere, stop and put it as a request in your final message.
- **Tuning.** Append inside your subgroup only. Regenerate `tuning/default.json` for your own tests with `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`. The lead regenerates after every merge.
- **Tests.**
  - `tools/run_tests.sh -gselect=<file>` while developing.
  - The full `tools/run_tests.sh` before your final commit (about 90 s). Read the whole output for `SCRIPT ERROR` and `ERROR`. Everything passes.
  - Tests that build real `player.tscn` or `street_punk.tscn` pass both with `Tuning.data.look_placeholder_bodies = true` and with the art (or the stand-in) on. Reset Tuning in `after_each`.
- **Look at it.**
  - Record with `tools/capture_bot.sh <bot.tscn> <worktree>/captures/<key> "<act filter>" <stills fps>`. It records at 1600x900, holds a machine-wide slot, and allows two at once.
  - Make sheets with `ffmpeg -loglevel error -y -ss <t> -t <d> -i <avi> -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png` and read them.
  - Judge looks in first person only. Side view and free fly are for mechanics.
  - Never commit `captures/`.
- **Art tools.**
  - Blender only headless: `blender --background --factory-startup --python <script> -- <args>`. **Never use the Blender MCP**: it is Game-boy's open Blender.
  - One Blender process at a time, one Godot process at a time per agent, and never leave one running. A Godot `-s` script needs `--quit-after N`, and loads game scripts inside `_initialize()`.
  - Run Python with `python3 -I`. Downloaded Tripo files are untrusted data: each goes into its own new, empty folder `assets/source/tripo/<id>/<task_id>/`. Scripts stay in `tools/art/` and take paths as arguments.
- **Keys and money.**
  - Never print, log or write `TRIPO_API_KEY` or `GEMINI_API_KEY`. They're read from `.env` inside the scripts only. The Gemini key goes in the `x-goog-api-key` header. Nothing goes in a URL. The Tripo CDN download sends no Authorization header.
  - Spend Tripo credits only through `tools/art/tripo.py` (it logs to the ledger and guards the budget), and only on the tasks your brief lists. Run `--dry-run` first.
  - Gemini only through `tools/gemini_image.py` job files.
- **Assets.**
  - Binaries are LFS: check `git lfs ls-files` lists your new `.glb`, `.png`, `.jpg` and `.blend` before pushing.
  - Every new file under `assets/export/**` or `assets/source/concepts/**` gets an `ASSETS.md` row from the package that owns ASSETS.md in that phase (§3). Otherwise put the row in your final message.
  - `assets/source/tripo/_local/` (rejected candidates) is git-ignored. Keep it that way.
- **Commits.** `wip: <key> ...` every 15-20 minutes, pushed. The final commit is `M4 <key>: <summary>`, pushed. Every message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Judgement calls.** Write each one to `docs/milestones/M4-calls/<key>.md`: the decision, at least one alternative not taken, and why. Don't ask Game-boy anything. Take the default that changes least.
- **Spec departures.** Build the reading that departs least, keep the spec value reachable as a tunable, and report it to the lead. Never silently.
- **Hardware.** 8 CPUs, 8 GB of RAM, Metal. Keep Tripo `face_limit` at or below 30,000 on bodies so Blender imports stay small.
- **Your final message:**
  - what you built;
  - the test count and result;
  - the build reports' numbers (art packages);
  - the sheets you looked at and what they show;
  - Tripo credits spent (task ids);
  - requests for files you don't own;
  - open risks.

---

## 2. Pinned contracts (S0 lands the stubs; owners implement; nobody renames)

### 2.1 New and changed classes

```gdscript
# game/actors/art_spec.gd
class_name ArtSpec extends Resource
@export var id: StringName                      # &"punk", &"player", &"standin", &"standin_player", &"pipecleaner"
@export var scene: PackedScene                  # res://assets/export/characters/<id>/<id>.glb
@export var detail_mask: Texture2D              # res://assets/export/characters/<id>/<id>_detail.png or null
@export var tri_budget: int                     # 15000 enemy, 30000 player (SPEC §10 table)
@export var outline: bool = true
@export var helper_bones: Array[StringName] = []   # R3 contingency only; empty in M4 unless the rig gate asks

# game/actors/art_catalog.gd
class_name ArtCatalog extends RefCounted
## The art for an actor id, or null for M3's primitive body. Honours Tuning.data.look_placeholder_bodies
## (true: always null) and look_art_source (0 final art if any, 1 the stand-in mannequin, 2 the pipe-cleaner).
static func spec_for(id: StringName) -> ArtSpec
## res://game/actors/art/<id>_art.tres if it exists, else null. No Tuning (tests).
static func load_spec(id: StringName) -> ArtSpec

# game/actors/skinned_art.gd
class_name SkinnedArt extends RefCounted
class Prepared:                                 # one per spec, cached statically, shared by every rig
	var meshes: Array[ArrayMesh]                # surfaces rebuilt: ARRAY_BONES remapped to skeleton bone order,
	                                            # ARRAY_CUSTOM0 = authoring position (RGBA_FLOAT, w 0), ARRAY_CUSTOM1 = authoring normal
	var names: PackedStringArray                # Blender object names (suffixes below)
	var probe: ArrayMesh                        # the <id>_probe LOD (never drawn; FPView)
	var joints: PackedVector3Array              # authoring-pose joint per skeleton bone (rig space at 1.8 m)
	var swing: Array[Quaternion]                # R_i per bone (2.4)
	var face_bone: Array[PackedInt32Array]      # dominant skeleton bone per triangle, per mesh (and probe last)
static func prepare(spec: ArtSpec) -> Prepared
static func make_skin(prepared: Prepared, rig_scale: float) -> Skin     # 23 binds, bind index == bone index
static func attach(rig: HumanoidRig, spec: ArtSpec) -> void              # MeshInstance3Ds under rig.skeleton
static func cpu_skin(mesh: ArrayMesh, skin: Skin, globals: Array[Transform3D]) -> PackedVector3Array  # rig-space LBS, the GPU's math
static func cpu_faces(mesh: ArrayMesh, skin: Skin, globals: Array[Transform3D]) -> PackedVector3Array # triangle soup for TriangleMesh
static func validate(spec: ArtSpec) -> Dictionary   # {tris, paints, unweighted, max_influences, joint_residual_m: Dictionary, sole_y: PackedFloat32Array}

# game/actors/rig_paint.gd  (extracted from humanoid_rig.gd:723-735, 396-402, 516-531, 1114-1123 by S0)
class_name RigPaint extends RefCounted
const TRIM := 5                                 # a sixth paint, art surfaces only (PlaceholderBody.Paint stays 0..4)
enum Outline { NONE, SMOOTH, BOX }
var materials: Dictionary[int, ShaderMaterial]  # S0: StandardMaterial3D still (no behaviour change); L1 switches the type
static func make(rig: HumanoidRig) -> RigPaint
func material_for_surface(surface_name: String) -> Material   # "BODY","PANTS","ACCENT","SKIN","DARK","TRIM"
func apply_colors(rig: HumanoidRig) -> void      # TRIM = rig.trim_color (new export, alpha 0 = accent lightened by the Look tunable)
func set_flash(amount: float, color: Color) -> void          # whole-body (parry) flash
func show_overlay(overlay: Material) -> void                 # contact flash: next_pass of every paint material, null clears
func set_damage_look(level: int) -> void
func set_bind_space(on: bool) -> void                        # skinned rigs: damage marks from CUSTOM0/1
func set_first_person(on: bool) -> void                      # FP-body outline width
func outline(mi: MeshInstance3D, kind: Outline) -> void      # material_overlay = per-rig outline material of that kind
static func warm_up(parent: Node3D) -> void                  # windowed only: draws every toon/outline variant once
```

`HumanoidRig` (`game/actors/humanoid_rig.gd`) additions, all set or read the same way as `wrapped_hands`:

```gdscript
@export var art: ArtSpec                     # set before build(); null = M3's primitives, exactly as today
@export var trim_color: Color = Color.TRANSPARENT
var paint: RigPaint                          # _materials stays as an alias of paint.materials (tests read it by name)
func is_skinned() -> bool
func skinned_meshes() -> Array[MeshInstance3D]
func fp_hidden_meshes() -> Array[MeshInstance3D]        # _head_meshes, both paths
func drawn_bone_globals() -> Array[Transform3D]         # rig space as drawn: Ragdoll._visual while ragdolling, else the FK
```

- `build()` keeps its order (humanoid_rig.gd:187). `_build_meshes()` (:739) branches: `art != null` calls `SkinnedArt.attach(self, art)`, else the primitives. The followers, points, hurtboxes and animation are built either way.
- `CombatActor` (combat_actor.gd) gets a new virtual, `## Choose the rig's art before it builds (M4); null keeps M3's primitive body.` `func _configure_art(_r: HumanoidRig) -> void`. `_ensure_body()` (:1561) calls it right after `_configure_rig(rig)` and before `rig.build()`.
  - `StreetPunk._configure_art` sets `r.art = ArtCatalog.spec_for(&"punk")`.
  - `PlayerCharacter._configure_art` sets `r.art = ArtCatalog.spec_for(&"player")`.
  - No other archetype overrides it.
  - `_configure_rig` is untouched, so `test_humanoid_rig._player_rig()`, `enemy_move_checks.fp_telegraph_problems` and `test_enemy_moves_thug` still dress primitive rigs (rig-render §8.2).
- `Ragdoll._process_modification_with_delta` (ragdoll.gd:614-647): when `rig.is_skinned()`, after `_visual[i]` is computed, it also does `skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())` and the Hips/Root position. `local` is the share-adjusted, eased local transform. Primitive rigs stay bit-identical. New: `func drawn_globals() -> Array[Transform3D]` (a copy of `_visual`).
- `FirstPersonCamera._head_clear_of` (first_person_camera.gd:384): when `player.rig.is_skinned()`, it tests the lens against spheres on `Head`, `Neck`, `UpperChest`, `Chest`, `LeftShoulder` and `RightShoulder` from `get_visual_point_transform`. The radii come from the region-versus-hurtbox stats in the build report, stored on the ArtSpec as `fp_region_radii` when R0-godot adds that field. Primitive players keep the mesh-AABB path.

### 2.2 The art contract (what a GLB in `assets/export/characters/<id>/` must be)

- **Content.** Mesh objects and one armature only; no animations (`export_animations=False`); no embedded textures (material slots are names only). Skins with 4 influences per vertex, normalized; no vertex weighted to `Root`; no unweighted vertex (an unweighted one makes Godot add a `neutral_bone`, blender-godot §3.2).
- **Bones.** Exactly the 23 `PlaceholderBody.BONE_NAMES`, plus only the `ArtSpec.helper_bones` when R3 has run. Every other bone's weights (fingers, twist, jaw, eyes) are merged into the nearest of the 22 deformers before export.
- **Pose, units, facing.**
  - Metres, at 1.8 m (the table's height). The player is 1.8 m too.
  - Authored in an A-pose: arm angle measured per side, legs per side, spine straight.
  - Facing Blender +Y, which the exporter maps to Godot -Z. Left is -X.
  - The armature's rest is the authoring pose. Binds are the exporter's (consistent, since the rest equals the pose).
- **Joints.** Each authoring joint equals the table joint chained through the swing: `p_UpperArm` = table, `p_LowerArm = p_UpperArm + R_UpperArm * (0,-0.29,0)`, and so on. The residual must be 5 mm or less per bone.
- **Soles.** Heel, ball and toe sample points at y = 0 ± 3 mm (heel z +0.085, ball z -0.13, toe tip z -0.25, x ±0.11).
- **Objects, named `<id>_<role>`:**
  - `_body`;
  - `_fp_hidden` (player only; goes to `_head_meshes`);
  - `_fist_l`, `_fist_r`;
  - `_shoe_l`, `_shoe_r` (player);
  - `_probe` (a 3k-triangle decimation of the union, never drawn).
- **Surfaces.** One material slot per paint, named exactly `BODY`, `PANTS`, `ACCENT`, `SKIN`, `DARK`, `TRIM`. There are 4-6 slots (SPEC §10), and none is red (hue 345-15° with saturation > 0.5 is refused by `test_art_palette`).
- **UVs.** UV1 is unused (paints are flat). UV2 (`TEXCOORD_1`) holds the unwrap for the 1k ink detail mask. `COLOR` holds smooth normals (`n*0.5+0.5`) for the hull, when the build config asks for them (needed on capped cuts and on part seams).
- **Budgets.** Punk: 15,000 triangles in total (body about 11k, fists 2 x 2k). Player: 30,000 (body 16k, fists 2 x 3.5k, shoes 2 x 3.5k). The probe is excluded.

### 2.3 Import path into Godot

- Each GLB has a committed `.import` with:
  - `meshes/generate_lods=false`;
  - `meshes/create_shadow_meshes=true`;
  - `skins/use_named_skins=true`;
  - `animation/import=false`;
  - `nodes/import_as_skeleton_bones=false`.
- The ArtSpec `.tres` is `game/actors/art/<id>_art.tres` and references the GLB as a `PackedScene`.
- `SkinnedArt.prepare()` instantiates the scene once (a static cache keyed by resource path) and takes every `MeshInstance3D`'s mesh and skin. For each surface it reads `surface_get_arrays`, remaps ARRAY_BONES through `skin.get_bind_name(k) -> skeleton bone index` (an unknown name is a hard error, `neutral_bone` maps to `Root`), fills CUSTOM0/1, and calls `add_surface_from_arrays` with `Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT` (and CUSTOM1). It keeps the surface names. The joints come from `inverse(bind).origin`.
- `attach()`:
  - builds one Skin per rig from `make_skin(prepared, rig.rig_scale())`;
  - adds one `MeshInstance3D` per mesh as a child of `rig.skeleton`, with `transform = IDENTITY`, `skeleton = NodePath("..")`, `skin`, `cast_shadow ON`, materials from `paint.material_for_surface()` and the outline from `paint.outline(mi, SMOOTH)`;
  - appends `_fp_hidden` to `_head_meshes` and the rest to `_body_meshes`, then calls `_apply_layers()`.
- Never instantiate the GLB's own `Skeleton3D` under the rig (name clash, non-identity rests, rig-render §1.2). No `custom_aabb`: culling follows the pose (blender-godot §4 [V]). R0-godot's flying-ragdoll capture checks that.

### 2.4 Binds (exact)

For skeleton bone `i` with rest global `rest_i`, from `PlaceholderBody.pose_globals(empty, ZERO, 1.0)` with `empty` a typed `Dictionary[StringName, Vector3]`:
- `d_i` = the rest direction to its first child;
- `a_i = normalize(p_child - p_i)` from the authoring joints;
- `R_i = Quaternion(d_i, a_i)` (shortest arc). Leaves (Head, Hands, Toes) take their parent's `R`, and Root and Hips take identity;
- `bind_i = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis(R_i), p_i).affine_inverse()`, where `s = rig.rig_scale()`.

At the rig rest, a vertex `v` lands at `s * (rest_i + R_i^-1 (v - p_i))`. This is blender-godot §6.2's verified math, with the bind order made equal to the skeleton order. Never reuse the GLB's inverse-bind rotations: exporter bone roll breaks the identity-axis bones.

### 2.5 Shaders, uniforms and passes

- `game/fx/toon.gdshader` is the one surface shader: characters, props, and the environment's flat materials. `game/fx/toon_light.gdshaderinc` holds the shared `light()`, which `game/level/grid.gdshader` includes. Uniform names are pinned, and L1 may add but never rename:
  - `albedo` (source_color);
  - `detail_mask` (sampler2D on UV2), `detail_strength`;
  - `band_1`, `band_2`, `band_soft`, `mid_level`, `shadow_tint`;
  - `spec_cut`, `spec_strength`;
  - `rim_cut`, `rim_power`, `rim_strength`;
  - `halftone_strength`, `halftone_cell_px`;
  - `flash_color`, `flash_energy`;
  - `damage_tex`, `damage_scale`, `damage_on`;
  - `use_bind_space`, `char_flag`.
  - `light()` uses `ATTENUATION` (shadow included) and adds `DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI` (blender-godot §8.1 [V]).
  - The fragment writes `ROUGHNESS = char_flag ? 0.0 : 1.0`. That is the edge pass's character mask; the custom `light()` ignores roughness.
  - The damage marks are a triplanar of `damage_tex`, in object space (primitives) or bind space (`CUSTOM0.xyz` and `CUSTOM1.xyz` passed as varyings), and only where `damage_on`. A look change swaps the texture and the scale, never the shader.
- `game/fx/outline.gdshader` is the inverted hull, used as `material_overlay`: `render_mode unshaded, cull_front, fog_disabled, shadows_disabled`.
  - Uniforms: `ink`, `width_px`, `min_m`, `max_m`, `far_fade_m`, `box_mode`, `use_color_normals`.
  - Width in metres: `clamp(width_px * VIEWPORT_SIZE.y / 1080.0 * 2.0 * depth / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y), min_m, max_m)`. Extrusion is along `NORMAL`, or the `COLOR` smooth normal, or `sign(VERTEX)` per axis in `box_mode` (exact for centred `BoxMesh`).
  - The GDScript mirror `RigPaint.outline_width_m(depth, fov_v_deg, viewport_h)` is what the tests use.
- The contact flash (`hit_flash.gdshader`) stays the `next_pass` of every paint material while it runs. That order puts the flash over the base surface and never over the hull rim. P1-int verifies it on a capture.
- `game/fx/edge_pass.gd` is `class_name EdgePass extends MeshInstance3D`: a 2x2 quad as a room child, with `extra_cull_margin 16384` and `render_priority -127`, between the flash (-128) and the comic sprites (0..3).
  - It reads depth and normal-roughness and skips pixels where the centre or the neighbour has roughness under `edge_char_roughness_max`.
  - Its width is scaled by `VIEWPORT_SIZE.y / 1080`, faded by depth.
  - It is added by `RoomKit.build_presentation()` only, so rooms built without presentation (tests) get none.
- `game/fx/look_grade.gd` is `class_name LookGrade`: `static func lut() -> ImageTexture3D` from `assets/export/look/grade_lut.png` (a 256x16 strip, 16³), set as `Environment.adjustment_color_correction`. Glow stays off.

### 2.6 FPView (tests/fp_view.gd)

- The existing signatures keep their behaviour for primitives.
- Skinned meshes are no longer invisible: `hits()` CPU-skins every `MeshInstance3D` whose `skin != null`, against `rig.drawn_bone_globals()`, through `SkinnedArt.cpu_faces`. It builds a `TriangleMesh` per mesh per frame (cached on `Engine.get_physics_frames()`) and casts. The default is the probe LOD; `exact := true` uses the drawn meshes.
- New:
  - `static func hit_regions(root: Node, cam: Transform3D, cols: int = COLS, exact: bool = false) -> Array[StringName]`, the bone per cell: a primitive's follower bone, or a skinned face's dominant bone;
  - `static func region_share(regions: Array[StringName], bones: Array[StringName]) -> float`;
  - `static func skinned_distance(mesh: MeshInstance3D, point: Vector3) -> float`, the minimum over skinned vertices, accurate to mesh resolution.
  - `mesh_distance`, `nearest_mesh` and `outside_view` dispatch to the skinned versions instead of null-casting (fp_view.gd:170).
- Region sets (pinned constants in fp_view.gd):
  - `ARM_BONES = [LeftLowerArm, LeftHand, RightLowerArm, RightHand]` (the elbow half of the upper arm counts as arm when its face is under the mid-upper-arm plane);
  - `LEG_BONES` (UpperLeg, LowerLeg, Foot, Toes per side);
  - `HEAD_BONES` (Head, Neck);
  - `TORSO_BONES` (Hips, Spine, Chest, UpperChest, Shoulders).

### 2.7 The "Look" tuning group (S0 seeds one tunable per subgroup; one owner each)

| Subgroup | Owner | Seed tunable (S0) | Others the owner adds |
| --- | --- | --- | --- |
| Art | R0-godot | `look_placeholder_bodies: bool = false` | `look_art_source: int` (0..2, Debug use), `look_trim_lighten` |
| Toon | L1 | `toon_band_1 = 0.28` | band 2, softness, mid, shadow tint, spec, rim, detail strength |
| Outline | L1 | `outline_px = 2.0` | `outline_fp_px`, `outline_min_m`, `outline_max_m`, `outline_far_fade_m`, ink |
| Halftone | L1 | `halftone_strength = 0.0` | `halftone_cell_px` (the default comes from the look review) |
| Edges | L2 | `edge_enabled = true` | width, thresholds, fade, `edge_char_roughness_max`, `look_aa_mode` (0 MSAA 4x, 1 FXAA) |
| Grade | L2 | `grade_enabled = true` | strength, environment saturation |
| Motion | M1-motion | `motion_cubic_named = false` | helper influence (R3) |

The group goes after "Debug" so no existing group-order test moves (`test_vfx.gd:1040` pins only "VFX" after "Hit feel"). `tuning/default.json` is regenerated (`test_tuning_panel.gd:454`).

### 2.8 Asset layout, naming, tools

```
assets/source/concepts/                         round 1 (exists): punk_a..d, hero_a..c .jpg, concept_jobs.json
assets/source/concepts/views/<id>/              view_jobs.json, front.png back.png left.png right.png (Gemini), guide_*.png refs
assets/source/concepts/parts/<id>_<part>/       part view jobs and images (fist, shoe, head contingency)
assets/source/tripo/ledger.jsonl                one JSON line per task: utc, task_id, endpoint, options, credits_consumed, balance_after, files
assets/source/tripo/<id>/<task_id>/             raw downloads of ACCEPTED tasks: model.glb, preview.webp, task.json, rig_dump.json
assets/source/tripo/_local/                     rejected candidates (git-ignored; the ledger keeps their ids and costs)
assets/source/characters/<id>/                  <id>.blend, build_report.json, palette.json, guide_{front,side,back}.png
assets/export/characters/<id>/<id>.glb (+.import), <id>_detail.png (1k ink mask, 8-bit L)
assets/export/look/grade_lut.png
game/actors/art/<id>_art.tres
tools/art/tripo.py                              v3 client: balance, upload, image-to-model, multiview, rig-check, rig, retexture, wait, dump; --dry-run; ledger; stops if balance would fall under 700
tools/art/build_character.py                    driver: python3 -I tools/art/build_character.py tools/art/characters/<id>.json [--from <step>]
tools/art/characters/<id>.json                  per-character config: source GLB, landmark source, bone_map, palette_map, parts, splits, budgets
tools/art/joints.json                           generated from PlaceholderBody by tools/art/gen_joints.gd (drift-tested)
tools/art/blender/*.py                          the steps of §5 R0-blender
tools/gemini_image.py                           exists; view and part jobs reuse it
```

Ids are `standin` (the Punk-shaped mannequin), `standin_player`, `pipecleaner`, `punk` and `player`. `ASSETS.md` gets new sections "Concepts", "Characters" and "Tripo tasks". `tests/test_assets_logged.gd` (S0) asserts that every file in `assets/export/characters/**`, `assets/export/look/**` and `assets/source/concepts/**` (except `.import` and job json) is named in ASSETS.md.

---

## 3. Hot spots: who owns which file when

| File | Ph 0 | Ph 1 | Ph 2 | Ph 3 |
| --- | --- | --- | --- | --- |
| `game/actors/humanoid_rig.gd` | S0 (extract, hooks) | R0-godot | M1-motion (helpers, polish hook) | P3-int |
| `game/actors/rig_paint.gd`, `game/fx/toon*.gdshader*`, `outline.gdshader`, `damage_look.gd`, `game/combat/weapon.gd` (pipe material) | S0 (stub) | L1 | L1-tail* | P3-int |
| `game/actors/skinned_art.gd`, `art_spec.gd`, `art_catalog.gd` | S0 (minimal) | R0-godot | M1-motion | P3-int |
| `game/actors/art/<id>_art.tres` | S0 (`standin`) | R0-godot (`standin*`, `pipecleaner`) | P-punk (`punk`), P-player (`player`) | P3-int |
| `game/actors/ragdoll.gd`, `game/camera/first_person_camera.gd` (`_head_clear_of` only) | | R0-godot | | P3-int |
| `game/actors/combat_actor.gd` (hook), `street_punk.gd`, `player.gd` (`_configure_art`) | S0 | | | P3-int |
| `game/actors/placeholder_anims.gd` | | | M1-motion | |
| `game/autoload/tuning_data.gd` | S0 (group, seeds) | own subgroups | own subgroups | own subgroups |
| `tuning/default.json` | lead regenerates after each merge | | | |
| `game/level/room_kit.gd`, `test_room.gd`, `grid.gdshader`, `game/fx/edge_pass.*`, `look_grade.gd`, `tools/gen_lut.gd`, `assets/export/look/*`, `project.godot` | | L2 | | P3-int |
| `game/fx/vfx_director.gd`, `comic_sprite.gd`, `speed_lines.gd`, `impact_frame.*`, `vfx_art.gd`, `tools/gen_fx.gd`, `assets/*/fx/*` | | | V1-vfx | P3-int |
| `game/ui/cheat_menu.gd` (Look stage) | | | | P3-int |
| `tests/fp_view.gd`, `tests/bot/readability_probe.gd`, `engage_meter.gd`, `test_grab_view`, `test_ko_view`, `test_player_grabbed`, `test_launch_from_hold`, `test_health_bars` | | R1 | P-player (player-art cases only, by request to R1's helpers) | P3-int |
| `test_hit_flash.gd`, `test_humanoid_rig.gd` (material asserts 535-590, 642 only), `test_vfx.gd` 688-835 | | L1 | V1-vfx owns all of `test_vfx.gd` | |
| `tests/bot/acts/look_acts.gd` | | R0-godot | P-punk | P3-int |
| `tests/bot/acts/look_perf_acts.gd` | | L2 | | P3-int |
| `tools/art/tripo.py`, `tools/art/blender/dump_rig.py`, `assets/source/tripo/**` | | A1 | A2 | |
| `tools/art/build_character.py`, `tools/art/blender/*` (except `dump_rig.py`), `tools/art/characters/standin*.json`, `pipecleaner.json`, `assets/*/characters/{standin,standin_player,pipecleaner}/**` | S0 (mannequin v0) | R0-blender | R3 (helper bones) | |
| `tools/art/characters/punk.json`, `assets/*/characters/punk/**` / `player.json`, `assets/*/characters/player/**` | | | P-punk / P-player | |
| `assets/source/concepts/views/**`, `parts/**` | | | A2 | |
| `ASSETS.md` | S0 | A1 (all rows of phase 1; others report rows) | A2 (all rows of phase 2) | P3-int |
| `README.md`, `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `docs/milestones/M4-*.md`, `docs/reviews/M4/*` | lead | lead | lead | lead |

\* L1-tail is a short follow-up only if P1-int finds flash or overlay order issues; otherwise L1's files pass to P3-int.

---

## 4. Phase 0: the contract scaffold and the first skinned body

### S0-scaffold (one Sonnet builder, alone; `.worktrees/m4-s0`, branch `m4/s0-scaffold`)

**Owns:** everything in the Ph 0 column of §3, plus `tests/test_m4_contracts.gd`, `tests/test_assets_logged.gd`, `.gitignore`, `tools/art/README.md`, `tools/art/blender/mannequin.py`, `assets/export/characters/standin/standin.glb`, `game/actors/art/standin_art.tres`.

**Brief:**
1. Extract the rig's material code into `RigPaint` (§2.1) with no behaviour change. It still makes `StandardMaterial3D`s, `HumanoidRig._materials` aliases `paint.materials`, and every existing test passes untouched. Add the `TRIM` paint and `trim_color`. Primitive parts never use TRIM.
2. Add `ArtSpec`, `ArtCatalog`, `SkinnedArt` (`prepare`, `make_skin`, `attach` per §2.3-2.4; `cpu_skin` can be a straightforward loop), `HumanoidRig.art` and the branch in `_build_meshes`, `is_skinned`, `skinned_meshes`, `fp_hidden_meshes`, `drawn_bone_globals` (FK only for now), and `CombatActor._configure_art` plus the Punk and player overrides.
3. Add the "Look" group with the seven seed tunables (§2.7), and regenerate the preset.
4. Write `tools/art/blender/mannequin.py`: the Skin-modifier mannequin, verified in this plan's `skin_probe.py`.
   - Vertices at the table joints in an A-pose (arms 50° from vertical, the concepts' "40° down from horizontal"), edges along the bones, radii from the placeholder silhouette (rig-render §9.3: pelvis 0.17, belly to upper chest 0.17-0.22, neck 0.065, head 0.12, upper arm 0.08, forearm 0.06, thigh 0.11, shin 0.08).
   - Apply Skin, subdivision 2, voxel remesh 10 mm, decimate to 11k, flatten the soles to z = 0.
   - Build the armature from `tools/art/joints.json` (write `tools/art/gen_joints.gd` too), weight with `ARMATURE_AUTO`, then nearest-weight fix, `vertex_group_limit_total(4)` and `normalize_all`.
   - Add two rounded fist boxes at the fist envelope, weighted 100% to the Hands. Add one material slot per paint (BODY on the torso, PANTS on the legs, SKIN on the head and arms, DARK on the fists, ACCENT on a cap ring).
   - Export per §2.2 to `standin.glb`.
5. Wire `look_placeholder_bodies` and `look_art_source = 1` into `ArtCatalog`.
6. Write `test_m4_contracts.gd`:
   - classes and signatures exist;
   - `ArtCatalog.spec_for(&"punk")` is null by default and the stand-in with `look_art_source = 1`;
   - a `HumanoidRig` with `art = standin` builds 23 bones, the followers, hurtboxes and points as a primitive rig does (the same `get_point_transform` for every point after `play(&"jab")` and 10 ticks), with no primitive `MeshInstance3D`s;
   - its skinned rest vertices from `cpu_skin` land within 2 mm of `s * (rest_i + R_i^-1 (v - p_i))` at heights 1.8 and 2.3.
7. Write `test_assets_logged.gd`, and add the ASSETS rows for the seven concept images, their job file and the mannequin.
8. Add to `.gitignore`: `assets/source/tripo/_local/` and `*.blend1`.

**Capture:** `tools/capture_bot.sh res://tests/bot/punk_bot.tscn captures/s0 "Punk wind-up at 1 m" 6`, with the stand-in on via `--set=look_art_source=1`. The bot's `--set` switch exists (HANDOFF 12:25 entry). The sheet must show a skinned grey mannequin in the boxer guard, throwing the jab and cross, with no shredding.

**Done:** the full suite is green, plus the two new files; the sheet shows the stand-in moving with the rig; the commit is `M4 S0-scaffold:`.

**Cost:** about 7-8% of a window, about 50 min.

The lead, meanwhile: copy `docs/reviews/M3/workflow-build.js` and `workflow-review.js` to `docs/reviews/M4/`, with the commit prefix `M4 <key>:` and args files `args-<phase>.json`. Update HANDOFF.

---

## 5. Phase 1: the rig proof, during the concept pick

Six packages start together once S0 merges. Four are Godot-bound (R0-godot, R1, L1, L2); A1 and R0-blender are Python and Blender, with only brief headless Godot runs.

### A1-tripo: the Tripo client and the pipe-cleaner (Sonnet, `m4/p1-tripo`)

**Owns:** `tools/art/tripo.py`, `tools/art/tripo_jobs/*.json`, `tools/art/blender/dump_rig.py`, `assets/source/tripo/**`, ASSETS.md (phase 1 rows; the other packages send theirs).

**Brief:**
1. Write the v3 client on toolchain-tripo-gemini §2.6's skeleton:
   - base `https://openapi.tripo3d.ai/v3` (v2 shuts down 2026-10-31);
   - `Authorization: Bearer` read from `.env`;
   - 429 backoff;
   - `--dry-run` prints the body and the expected cost from a price table in the script's job JSON (not literals);
   - before any paid task, it reads the balance and refuses if `balance - expected < 700`;
   - after each task it appends to `ledger.jsonl` and downloads `model_url` and `rendered_image_url` within the same run (they expire in 5 min, and the CDN gets no auth header) into a new folder `assets/source/tripo/<id>/<task_id>/`, saving the whole `output` object as `task.json`.
2. Write `dump_rig.py` (Blender): bones (name, parent, head, tail, roll), vertex-group weight counts, max influences, unweighted count, triangles, bounding box, the facing axis (found from the toe and nose vertices), and the materials and textures, all as `rig_dump.json`.
3. **The pipe-cleaner (about 55 credits).** If Game-boy's Punk pick has arrived, use the pick's front concept; otherwise use `assets/source/concepts/punk_a_denim_vest.jpg`. Its bare arms are the worst case for shoulder deformation, and its one-sided forearm wrap is the mirror check.
   - `POST /files`, then `generation/image-to-model` with `model v3.1-20260211`, `texture true`, `pbr false`, `texture_quality standard`, `texture_version v3.5-20260815`, `delight true`, `orientation align_image`, `face_limit 30000` and `model_seed 4242`. Leave `export_orientation`, `quad`, `compress` and `generate_parts` unset.
   - Then `animations/rig-check` (free; it must say biped), then `animations/rig` with `model v3.0-20260909`, `rig_type biped`, `spec unity`.
   - If that rig fails or its names aren't the Unity humanoid set, run one `v1.0-20240301` rig with `spec mixamo` (25 more).
   - Dump both GLBs.
   - Record `credits_consumed` for the v3.5 texture (the docs don't state it).
4. Write the findings into `tools/art/characters/pipecleaner.json`'s `source` block, as data for R0-blender: the bone map, the facing, the A-pose angles, the scale, and the paths.
5. Add the ASSETS rows: Tripo task ids, model versions, credits, date, and the licence note "Tripo terms §5.2: paid accounts own outputs; this account's type is unknown, ask Game-boy before ship".

**Tests:** `python3 -I tools/art/tripo.py --self-test` (offline: the ledger format, the budget guard refusing a fake balance of 720 at cost 30, no key in any output). The secret check greps the ledger and every new file for `tsk_` and for the key's value read in memory.

**Done:** the pipe-cleaner GLB, rigged GLB and dumps are committed (LFS); the ledger shows at most 80 credits; R0-blender has its source block.

**Cost:** about 3% (mostly waiting on Tripo).

### R0-blender: the scripted clean-up and rig chain (Sonnet, `m4/p1-blender`)

**Owns:** `tools/art/build_character.py`, `tools/art/blender/*.py` (except `dump_rig.py`), `tools/art/characters/{standin,standin_player,pipecleaner}.json` (`pipecleaner.json`'s `source` block comes from A1), `assets/source/characters/{standin,standin_player,pipecleaner}/**`, `assets/export/characters/{standin,standin_player,pipecleaner}/**`.

**Brief:** turn the readers' verified experiments (blender-godot §3) into a chain the driver runs step by step. Each step is idempotent, writes the `.blend`, and appends to `build_report.json`:
1. **`import_normalize.py`.**
   - Import (`disable_bone_shape=True`), apply transforms, merge by 0.5 mm, make normals consistent (a signed-volume check), drop loose parts under 0.5% of the vertices.
   - Rotate so the character faces Blender +Y (using the dump's facing), with the soles at z = 0 and centred on XY.
   - If the shell is non-manifold or multi-shell, voxel remesh at 8-10 mm into `<id>_work`, and keep the textured original as `src_hi` for the texture lookups.
2. **`fit_to_table.py`.** This is the core of the thesis.
   - Landmarks: the Tripo rig's bone heads through `bone_map`, or `landmarks` in the config, or the table (stand-ins).
   - Build an armature `Src` at the landmarks, and an armature `Table` at the table joints, swung into the mesh's measured A-pose: the arm angle per side from shoulder to wrist, the leg spread per side from hip to ankle.
   - Skin the mesh to `Src` (`ARMATURE_AUTO`). Pose each `Src` bone onto its `Table` bone: rotate onto the direction, scale Y to the length with `inherit_scale='NONE'`, translate the root. Apply the Armature modifier, which bakes the proportion fit.
   - Head: a uniform scale about the Head joint so the head region fits the head hurtbox (centre (0, 1.685, -0.01), r 0.15) within the config tolerance.
   - Girth clamp (player only, `girth` in the config): a radial scale toward the bone axis so the forearm, upper arm, thigh and shin radii stay within ±15% of the placeholder's (0.056, 0.075, 0.1, 0.085 m).
   - Flatten the soles: foot-region vertices under 4 mm go to z = 0.
   - Report each segment's scale. Fail outside [0.85, 1.18] unless `allow_warp` is set.
3. **`parts.py`.**
   - Delete the hands past the cuff plane (faces with mean Hand weight above 0.5). Import the fist part (config `parts.fist_l/fist_r`, or the mannequin's rounded fists until real parts exist), fit it into the fist envelope in the Table Hand frame, and weight it 100% Hand, with a cuff ring of 70/30 Hand/LowerArm.
   - Shoes the same way below the ankle cuff (player).
   - Each part stays its own object (§2.2 names).
4. **`weights.py`.**
   - `ARMATURE_AUTO` on `Table` (default), or `weights_from: "tripo"`: a Data Transfer from the Tripo-rigged mesh, with groups renamed through `bone_map` and fingers, twist and face bones merged into their deformer.
   - Then the nearest-weighted-vertex fix (a KDTree), smoothing on the blend zones (`vertex_group_smooth`, the factor and repeats from the config), `vertex_group_limit_total(4)`, `normalize_all`, and an assert of 0 unweighted vertices.
   - Build both variants for the pipe-cleaner (`_auto`, `_tripo`) so the gate can compare them.
5. **`palette.py`.**
   - Sample `src_hi`'s texture per face: a BVH nearest point, barycentric UV, the texel (blender-godot §3.7 [V], 92% on borders).
   - k-means to the config's palette size (6 or fewer), two passes of a majority filter.
   - Map clusters to paints by nearest to the config's named colours, and assign faces to the material slots `BODY`..`TRIM`.
   - Refuse a red slot. Write the colours to `palette.json`. The rig's colour exports (`body_color`, `accent_color`...) get set from it in the ArtSpec's owner script, never baked.
6. **`detail_mask.py`.**
   - UV2: `smart_project` and `pack_islands` on the final mesh.
   - Cycles CPU bake of `src_hi`'s base colour, selected to active with a small cage, to 1024², then luminance, then a threshold on dark thin strokes, then a 1 px dilate: `<id>_detail.png` (8-bit, ink = 0).
   - Fallback when the headless Cycles bake fails: a numpy rasterizer of UV2 triangles with the BVH lookup.
   - The mask holds ink lines only (seams, pockets, laces, wraps, face lines). It never holds shading.
7. **`split_fp.py`** (player and `standin_player`).
   - Faces whose mean weight on {Head, Neck, Chest, UpperChest, LeftShoulder, RightShoulder} is above 0.5, or on an UpperArm above the mid-upper-arm plane, become `<id>_fp_hidden`; the rest is `<id>_body`.
   - Close `<id>_body`'s cut holes with a dome (fill, grid fill, inflate outward by 0.6 x the hole radius, smooth): the rounded elbow-end cap and the chest-top cap.
   - Leave the hidden part 1 cm overlapping and unclosed.
   - Write smooth normals into `COLOR` on both.
8. **`budget.py`:** a Decimate collapse per object to the config budget (the vertex groups survive, [V]), then the weight fix again. Plus the `<id>_probe` object, the union decimated to 3k.
9. **`export_glb.py`:** per §2.2. GLB only, with `export_animations=False`, skins, 4 influences, `export_yup=True`, deform bones only, no leaf bones, `export_apply=False`, materials as placeholders, texcoords and normals, `export_vertex_color='ACTIVE'` when COLOR is used. Then `godot --headless --import --quit` and a check of the `.import` options (§2.3).
10. **`render_check.py`:** orthographic Workbench stills (front, side, back) to `assets/source/characters/<id>/guide_*.png`. They're for the review, and they are the proportion guide A2 hands Gemini.

Build the mannequin variants first, from `mannequin.py`:
- `standin`: Punk-shaped, 11k triangles, fists.
- `standin_player`: the hero's wrapped-hand proportions, the FP split with caps, mannequin shoes from a skinned box with rounded edges, 16k triangles plus parts.

Then `pipecleaner` from A1's GLB (both weight variants, `pipecleaner_tripo` as a second ArtSpec-ready GLB). Tests use the mannequins (deterministic, small); the gate uses the pipe-cleaner.

**Tests:** each `build_report.json` meets §11's M1-M3 numbers; `python3 -I tools/art/build_character.py --check <report>` exits non-zero otherwise. Run it for all three.

**Done:** three GLBs (plus the Tripo-weights variant) committed with passing reports; guide stills exist; the chain reruns from any step.

**Cost:** about 8%.

### R0-godot: the loader, the rig and the proof acts (Sonnet, `m4/p1-rig`)

**Owns:** per §3, Ph 1. Plus `tests/test_skinned_art.gd`, `tests/test_art_deformation.gd`, `tests/test_ragdoll_skinned.gd`, `tests/bot/acts/look_acts.gd`, and `game/actors/art/{standin,standin_player,pipecleaner,pipecleaner_tripo}_art.tres`.

**Brief:**
1. **Harden `SkinnedArt`:**
   - the static cache;
   - the ARRAY_BONES remap and the CUSTOM0/1 fill (§2.3);
   - `face_bone` (the dominant bone per triangle, from the mean weights);
   - `validate()`;
   - `cpu_skin` and `cpu_faces` using `Transform3D * PackedVector3Array` per bone, then a weighted accumulate (this plan [V]: about 2 ms per 8k vertices);
   - an error for an unknown bind name;
   - `neutral_bone` mapped to Root.
2. `drawn_bone_globals()`: `Ragdoll.drawn_globals()` while `is_ragdolling()`, else `_bone_globals`.
3. The ragdoll write-back (§2.1).
4. `_head_clear_of` on bones for skinned players (§2.1).
5. `look_art_source` 2 maps `punk` to the pipe-cleaner. Add an `--art=<0|1|2|tripo>` switch to the crowd and punk bots through `--set`.
6. `test_skinned_art.gd`:
   - `joints.json` equals `PlaceholderBody`;
   - the joint residuals of every committed spec are 5 mm or less;
   - the triangle and paint budgets;
   - binds equal §2.4 at 1.8, 2.05 and 2.3 m;
   - the skin's bind count equals the bone count, and the bind names are in skeleton order;
   - an unknown name errors;
   - CUSTOM0 equals the authoring positions;
   - `set_shown(false)` hides every skinned mesh and its overlay;
   - `first_person_body` puts `_fp_hidden` on `VIS_FP_HIDDEN`, and they still cast shadows;
   - hurtboxes and points are identical to a primitive rig's over `jab`, `flinch_gut`, `guard_break`, `knockdown_back` and `getup_back`.
7. `test_ragdoll_skinned.gd`: a test modifier after `Ragdoll` reads `skeleton.get_bone_pose` inside the stack. In PARTIAL (stagger) and FULL (launch at once from a stagger) the skeleton-versus-`_visual` gap is 1 mm or less on every bone. Primitive rigs show no change from M3 (followers identical to the M3 code path).
8. `test_art_deformation.gd`:
   - for `standin` and `pipecleaner` (when present), over every `PlaceholderAnims.ANIM_IDS` id and every Punk move, at 5 phases each (start, 25%, active or peak, 75%, end), CPU-skin and measure the edge-length strain (edge length posed over rest);
   - pass: p99.9 within [0.6, 1.6] and the maximum within [0.4, 2.2];
   - no NaN;
   - in planted poses no vertex below y = -0.02 (sole sink);
   - under 25 s of runtime. Print the worst 10 (animation, phase, bone) for the review.
9. **`look_acts.gd`** (crowd room, `cam = &"first_person"`, AI frozen, `bot.god()`; a Punk spawned at `Vector2(0, 1.0)` facing the player, `bot._look_to(+8, 10)` for the face shot, the caption hidden). Acts titled `Look: <id> <what>`:
   - `standing`: 4 s idle, then 2 s at the default pitch;
   - `profile`: a second Punk at `Vector2(0.9, 1.1)` turned 90°, so the shoulders and elbows show side on;
   - `circle`: the Punk moved by code on a 1.1 m arc around the player for 6 s, with `rig.play_locomotion()` at the matching speed ratio (the AI can't do this at 1 m: fx-env-tooling §9.3);
   - `attacks`: `force_attack(0)` (jab and cross) and `force_attack(1)` (shove), waiting for RECOVER;
   - `reacts`: `rig.play()` of `flinch_head_front/left/right`, `flinch_gut`, `flinch_legs`, `stagger_back` with the player's scripted hook landing (partial ragdoll), `guard_break`;
   - `down`: the haymaker knockdown, `getup_back`, then the KO and blink-off;
   - `torture`: every `ANIM_IDS` id played back to back on the profile Punk.
10. Record all of the acts for `standin`, `pipecleaner` (auto weights) and `pipecleaner_tripo`.

**Tests:** the new files, plus the full suite green both ways.

**Done:** everything above passes; the sheets are made and read (`captures/r0/<id>_<act>_sheet.png`); the final message ranks the pipe-cleaner's worst joints from both the strain test and the sheets.

**Cost:** about 10%.

### R1-fpview: the tests learn skinned bodies (Sonnet, `m4/p1-fpview`)

**Owns:** per §3, Ph 1. Plus `tests/test_fp_view_skinned.gd`, `tests/test_art_silhouette.gd`.

**Brief:**
1. Implement §2.6, with a per-physics-frame cache so a grid of 48x27 rays costs one skin plus one BVH per mesh.
2. Port these, each to pass with primitives and with `look_art_source = 1`:
   - `test_grab_view` (`_is_arm` 406 and `_is_right_leg` 414 become regions);
   - `test_ko_view` (`_head_meshes` 152 becomes `rig.fp_hidden_meshes()`; `_nearest_any_layer` 180 goes skinned);
   - `test_player_grabbed` (183, 197);
   - `test_launch_from_hold` (93);
   - `test_health_bars` (197: rig points instead of the `BoneHead` children; 94 `_silhouette`: CPU-skinned vertices);
   - `readability_probe._sample_occlusion` (767), `_sample_lens` (811), `_is_enemy_mesh` (826);
   - `engage_meter:108`.
   Don't loosen a threshold. A threshold that fails only with the mannequin goes in the final message, with numbers.
3. `test_fp_view_skinned.gd`:
   - a skinned box-per-bone fixture built to equal a primitive box rig gives hit grids differing by at most 1 cell in 1,296, over idle, jab and spin kick;
   - the probe LOD agrees with `exact` within 1.5 percentage points of coverage;
   - a timing budget of 15 ms or less per sample per exact 15k-triangle body, and 4 ms on the probe, headless.
4. `test_art_silhouette.gd` (the framing gate, §11 M4). For every committed player-type spec in the player poses, and every enemy-type spec in the enemy poses, compare the share of the view against the placeholder rig in the same pose:
   - player poses: idle looking ahead; looking down 45° and 60°; jab, cross, hook and uppercut at their active frames; `block`; the knee in the hold; the spin kick's mid-turn; `haymaker_charge`;
   - enemy poses at 0.9, 1.0 and 1.5 m from the lens: the idle guard, the jab wind-up held, the shove wind-up;
   - pass: `|Δ| ≤ 4` percentage points per pose, and the lens-clearance rules of the ported tests (forearms and hands at least 0.3 m from the lens in `block`) hold with the art.

**Done:** green both ways; the timing printed; the gate passes for `standin` and `standin_player`, and its numbers are reported for `pipecleaner`.

**Cost:** about 10%.

### L1-toon: the toon shader, outlines, flash and damage on every rig (Sonnet, `m4/p1-toon`)

**Owns:** per §3, Ph 1. Plus `tests/test_toon.gd`.

**Brief:**
1. Write `toon.gdshader` and `toon_light.gdshaderinc` per §2.5: a 2-3 band ramp with soft edges, a tinted shadow, a hard spec, a stepped rim, a screen-space halftone in the shadow band, the detail mask multiply on UV2, the flash uniforms, the triplanar damage (object or bind space), and the `char_flag` ROUGHNESS.
2. Write `outline.gdshader`.
3. Switch `RigPaint` to `ShaderMaterial` (six paints).
   - `set_flash` becomes uniforms.
   - `show_overlay` keeps the `next_pass` mechanism (the flash shader is unchanged).
   - `set_damage_look` moves `DamageLook.prepare/apply` (damage_look.gd:61, :75) to `ShaderMaterial` uniforms and textures, with DARK unmarked and "swap a texture, never a variant".
   - `outline()`: SMOOTH for capsules, spheres, cylinders and skinned meshes, BOX for `BoxMesh` parts; `set_first_person(true)` for player rigs.
   - The pipe (`weapon.gd:42`) gets a toon material and a hull.
4. `RigPaint.warm_up()`: the `_warm_flash` pattern (humanoid_rig.gd:501), one tiny draw per variant, windowed only. HumanoidRig calls it where `_warm_flash` is.
5. Port the material asserts:
   - `test_hit_flash` (142-154, 202-204, 276-296, 369-374): `ShaderMaterial`, `flash_energy` instead of `emission_energy_multiplier`;
   - `test_vfx` 688-835 (`detail_*` and `uv1_triplanar` become `damage_tex`, `damage_scale` and `damage_on`; "never switches the shader variant" becomes "the shader resource and every non-texture, non-scale uniform are unchanged");
   - `test_humanoid_rig` 535-590 and 642 (`albedo_color` becomes `get_shader_parameter(&"albedo")`; 4-6 distinct albedos).
6. `test_toon.gd`:
   - every rig paint and every room material uses `toon.gdshader`;
   - `outline_width_m` stays inside [min, max] and is constant in pixels across 0.5-8 m;
   - `box_mode` is set on box parts;
   - skinned paints have `use_bind_space` true;
   - there's no red paint in any archetype's colours or in the art palettes;
   - the hit flash still shows for exactly `hit_flash_frames` frames on a toon rig.

**Capture:** `combo_bot` and `vfx_bot` acts in the training room ("damage looks held at 1 m", the tier sizes, a finisher). The flash must sit on the struck part, the hull must hold an even width with no cracks on the box parts, and the bands must be clean. Get one skinned check from S0's stand-in through `--set=look_art_source=1`.

**Done:** the suite green; sheets read and described.

**Cost:** about 9%.

### L2-env: the environment, edges, grade and both rooms (Sonnet, `m4/p1-env`)

**Owns:** per §3, Ph 1. Plus `tests/test_look_env.gd` and `tests/bot/acts/look_perf_acts.gd`.

**Brief:**
1. `RoomKit.flat_material()` and `grid_material()` use the toon shader (S0's stub until L1 merges; the uniform names are pinned). Environment colours run through a saturation tunable: muted, so the enemies pop (SPEC §10).
2. `test_room.gd` calls `RoomKit.build_environment()`, `flat_material()`, `grid_material()` and `build_presentation()` instead of its own copies (test_room.gd:65, :95, :201, :152), so every bot renders the same look.
3. `EdgePass` and `LookGrade` per §2.5. `tools/gen_lut.gd` is seeded and deterministic, with its numbers as script `@export`s like `gen_fx.gd`'s: warm highlights, cool shadows, a slight posterize.
4. `look_aa_mode`: 1 sets `msaa_3d = DISABLED`, `screen_space_aa = FXAA` on the root viewport. That's presentation, and it is live.
5. Glow stays off.
6. Warm-up: `EdgePass` draws its first frame during the room's load.
7. `test_look_env.gd`:
   - both rooms: every environment material is toon;
   - one `EdgePass` with presentation, none without;
   - the LUT is 16³;
   - `glow_enabled` is false;
   - the edge pass's `render_priority` sits between the flash's and the sprites'.
8. `look_perf_acts.gd`: windowed, unvsynced wall time (fx-env-tooling §6.3's method), the crowd room with 6 primitive enemies; base, edges on, edges plus FXAA, and grade on.

**Capture:** the `room_acts` tour in first person, and a fight close-up. Lines must be on buildings and crates but not doubled on characters, and must fade with distance.

**Done:** green; the perf table is in the final message; the sheets are read.

**Cost:** about 8%.

### P1-int: integration of phase 1 (Sonnet, `m4/p1-int`, after the six merge)

**Brief:**
1. Merge order: S0's base, then A1, R0-blender, R0-godot, R1, L1, L2. The lead regenerates the preset, runs the full suite and pushes after each merge.
2. Check on captures:
   - the contact flash over the base surface but not over the hull rim, on the pipe-cleaner;
   - the damage marks stick in `torture` (bind space);
   - the outline on a flying ragdoll;
   - no culling pops.
3. Record every `Look:` act for `pipecleaner` and `pipecleaner_tripo` under the full look.
4. Run the perf comparison back to back on a quiet machine (load average under 2; check `uptime` first): `main` at `afdb39e` against the integrated branch with six pipe-cleaner Punks, using "Perf, six with ragdolls" (crowd_acts.gd:86).

**Done:** the suite green; the evidence folder for the rig gate exists (`captures/p1-int/gate/`).

**Cost:** about 7%.

### The rig gate (the lead plus `docs/reviews/M4/workflow-review.js`, round "gate")

Four Opus lenses, each finding verified by 2 skeptics:
- **G1, rig mechanics:** binds, joints, the ragdoll gap, FP layers, the KO view, blink-off, the flash anchor on the skinned surface, whether the tests are honest (does any port pass for the wrong reason?).
- **G2, deformation at 1 m in first person:** from the `Look:` sheets, plus the strain test's worst-10 list. This lens also compares `pipecleaner` against `pipecleaner_tripo`.
- **G3, shading on skinned bodies:** the bands, hull stability, the order of the flash and the hull, the marks.
- **G4, perf.**

The verdict picks one of these:
- **(a) proven:** phase 2 uses the default chain;
- **(b) proven with a contingency:**
  - R3-helpers, if elbows, knees or shoulders collapse;
  - `weights_from: tripo`, if those weights win;
  - bake-to-arms-down, if the A-pose binds pinch;
- **(c) not proven:** the lead re-plans before spending on the real Punk.

**Cost:** about 15-20% for the review, plus about 10% for the fixes.

---

## 6. Phase 2: the real Punk and the player's limbs (needs the pick and the gate)

### A2-generate: views and Tripo (Sonnet, non-Godot, `m4/p2-generate`; starts on the pick, even before the gate)

**Owns:** `assets/source/concepts/views/**`, `assets/source/concepts/parts/**`, `tools/art/tripo_jobs/*` (phase 2), `assets/source/tripo/{punk,player,parts}/**`, ASSETS.md (phase 2).

**Brief:**
1. **Gemini views** (`gemini-3-pro-image`, 2K, 3:4, `responseModalities ["IMAGE"]`), one job per view, using toolchain-tripo-gemini §3.4's template. The references are the picked concept, the views already accepted, and `assets/source/characters/standin/guide_{front,side,back}.png` as the **proportion guide**: "match the grey mannequin's body proportions, joint heights and A-pose exactly". The views are:
   - for the Punk: front, back, left side, right side;
   - for the hero: front, back, left, right (from the sheet's main figure);
   - parts: the Punk's gloved fist and the hero's wrapped fist with its fingerless glove, each closed, in front, side and back views from the concept and the callouts; the hero's shoe from the side, front and back.
   A numeric check rejects views whose subject box height differs by more than 3%.
2. **Tripo** (§10 budget):
   - Punk `multiview-to-model`: front, back, one side first, so the left/right label can be checked against the asymmetric detail. Then all four if that was correct; otherwise swap the labels.
   - Judge each candidate from Tripo's preview plus `render_check` stills (the lead reads them). Make up to 2 more generations, or re-texture (10) when only the texture is off.
   - Rig the accepted Punk (v3.0, unity).
   - Glove part (`face_limit 8000`).
   - Hero body, its rig, the hero fist part and the shoe part.
   - Accepted tasks are committed; rejected ones go to `_local/`.
3. Write `tools/art/characters/{punk,player}.json`'s `source` blocks.

**Done:** sources ready for P-punk and P-player; the ledger total is reported.

**Cost:** about 4%, plus about $3 of Gemini.

### P-punk: the Street Punk through the proven chain (Sonnet, `m4/p2-punk`)

**Owns:** `tools/art/characters/punk.json` (everything outside `source`), `assets/{source,export}/characters/punk/**`, `game/actors/art/punk_art.tres`, `tests/test_punk_art.gd`, and `tests/bot/acts/look_acts.gd` (adding `punk` to its id list). The Punk's colour exports (`street_punk.gd:12-13`) go to the palette's teal and yellow, by request to the lead.

**Brief:**
1. Run `build_character.py punk.json` with the rig gate's chosen variant. The budget is 15k, the palette 6 paints or fewer, and the detail mask 1k.
2. Iterate the config, not the code. If the chain itself needs a change, request it from R0-blender's owner (the lead routes it).
3. `punk_art.tres` becomes the default for `&"punk"` (the catalog finds it by filename).
4. `test_punk_art.gd`: `validate()` within §11 M1-M3; the deformation test (R0's harness, `punk` added) and the silhouette gate (R1's, `punk` added) pass.

**Capture:** every `Look: punk` act, plus a crowd-room fight against six Punks in first person.

**Done:** green; the sheets read against §11's J1-J3; a self-score in the final message.

**Cost:** about 10%.

### P-player: the player's arms and legs, highest detail (Sonnet, `m4/p2-player`)

**Owns:** `tools/art/characters/player.json`, `assets/{source,export}/characters/player/**`, `game/actors/art/player_art.tres`, `tests/test_player_art.gd`. Player colour exports in `player.gd:139-146` go by request.

**Brief:**
1. Run the chain with the full hero body, the FP split, caps, the girth clamp, the two fist parts (mirrored) and the two shoe parts. Budgets: 16k body, 3.5k per part. The 1k detail mask carries the wrap layers, glove stitching and shoe panels.
2. `test_player_art.gd`:
   - `validate()`;
   - the FP split: the hidden set covers exactly the bone sets of `PlaceholderBody.FP_HIDDEN_BONES/PARTS` (placeholder_body.gd:121-124);
   - the caps are closed (no open boundary edge on `player_body` except none at all);
   - the silhouette gate for the player poses;
   - R1's ported FP tests pass with the real player art, not only with the mannequin;
   - the KO view (`_head_clear_of` on bones) still un-culls in the same tick window as the placeholder ±3 ticks.

**Capture:** `combo_bot` acts in first person (every chain, the block, the knee in the hold, the haymaker charge), "looking down" acts, and the KO view. The wraps, gloves and shoes must read at 0.3-0.6 m, with no hollow caps and no seam pop at the split.

**Done:** green; the sheets read.

**Cost:** about 12%.

### V1-vfx: the comic VFX set, final pass (Sonnet, `m4/p2-vfx`; toolchain-free, can start any time after L1)

**Owns:** per §3, Ph 2.

**Brief:**
1. Keep SPEC's rules: SVG drawn by `tools/gen_fx.gd`, 512 px PNGs, 8-10 words (pinned by `test_vfx.gd:251`, :1061).
2. Match the ink weight to the hull's on-screen width (a tunable `vfx_ink_px`, regenerated).
3. Add Ben-Day halftone fills inside the bursts and lettering extrusions.
4. Make two variants per burst tier, picked at random and never twice in a row.
5. Size words by cap height instead of width: CRUNCH, KAPOW and WHUMP letters stop being 25-30% smaller (fx-env-tooling §2.3). It's tunable, and the old sizing stays reachable.
6. Lying splats and the damage tiles follow the toon look (unshaded with a darkening factor, or the toon shader for LYING sprites), and blood stays the only red.
7. Warm-up entries for every new variant (`VfxDirector.begin_warm_up`, vfx_director.gd:170).
8. ASSETS rows for every new SVG and PNG pair. `test_vfx` is updated for the variants.

**Capture:** `vfx_bot`'s 22 acts. Judge them against the Punk art at 1 m.

**Done:** green; byte-stable regeneration; sheets read.

**Cost:** about 6%.

### M1-motion: motion polish (Sonnet, `m4/p2-motion`)

**Owns:** `placeholder_anims.gd`, `humanoid_rig.gd`, `skinned_art.gd` (helper bones), `game/actors/art_spec.gd`, `tests/test_motion_polish.gd`.

**Brief:**
1. `motion_cubic_named`: when on, the named library of the boxer stance (enemies only; `_named_library` caches per stance and scale, humanoid_rig.gd:847) uses `INTERPOLATION_CUBIC` on its rotation tracks and the Hips track (placeholder_anims.gd:435, :444). Move clips stay linear, since frame data and contact sync sit on keys.
2. Tests:
   - sole planting: the lowest sole is at or above -0.01 m at 60 samples per named clip;
   - hurtboxes during moves are unchanged;
   - the hold, grab and FP-judged clips are unaffected (the player's stance library stays linear).
3. Default `false`. The final review decides whether to turn it on.
4. **R3-helpers, only if the rig gate asked for it:**
   - `ArtSpec.helper_bones`, for example `LeftElbowHelper` (a child of LeftUpperArm at the elbow), `LeftKneeHelper`, `LeftShoulderHelper` (a child of UpperChest at the shoulder joint, carrying half of UpperArm), mirrored;
   - added after bone index 22 only on skinned rigs;
   - driven by one built-in `CopyTransformModifier3D` (amount from Tuning) kept as the last skeleton child (moved after the ragdoll's when that's built);
   - the same bones in R0-blender's armature (a request to R0-blender's chain: `helpers` in the config);
   - tests: FK, hurtboxes and the ragdoll unchanged; the strain test improves at the named joints.

**Cost:** about 7% (about 10% with R3).

### P2-int (Sonnet, after phase 2's merges)

**Brief:**
1. Merge, regenerate, run the full suite.
2. Record the `Look: punk *` acts, the player FP acts, the crowd fight, and a "Punk among placeholders" act (Punk, Kicker and Bruiser at 1.5-3 m).
3. Rerun the perf comparison on a quiet machine.

**Done:** every §11 measured item passes or is listed with numbers.

**Cost:** about 6%.

---

## 7. Phase 3: integrate, evidence, review, fix

### P3-int (Sonnet)

**Brief:**
1. The F4 cheat "Look stage" (`cheat_menu.gd`): spawns a Punk at 1 m ahead with its AI frozen. In that mode, the number keys cycle idle, circle, jab and cross, shove, flinch, stagger, knockdown and get-up, KO, and damage looks clean, bruised and bloodied. The mode is debug-only and its state stays out of presets (M1 rule).
2. Warm-up audit: the first spawn of each art and look variant hitches 33 ms or less (the perf act's spawn line).
3. `tools/art/evidence.sh`:
   - records the evidence acts (§11);
   - converts AVIs to MP4 (`ffmpeg -c:v libx264 -crf 20`) and makes sheets into `captures/m4/evidence/`;
   - takes the before/after stills from `main` and the M4 branch at matching frames.
4. `docs/milestones/M4-evidence.md` holds the metrics table and the sheet list (numbers only; no images committed).

**Cost:** about 8%.

### F-due: the deferred feel questions, measured with the art (one Opus, review only)

Measure each of these on the M4 branch in first person, and write a default and options for each into `docs/milestones/M4-feel-due.md`:
1. **The contact flash's first-person share** (grab-05 / hit-01): the knee in the hold, a jab at 1 m, the flurry strobe rate and share (HANDOFF lines 620, 822).
2. **The haymaker's flash** (r3look-05): visible area on the Punk at 1 m.
3. **The non-KO knockdown view:** the player's art belly and cap share of the view, frames over 50% (the M2 placeholder measured up to 74%).
4. **grab-03, the combat log over the knee contact:** pixel overlap with the player's art knee.

Nothing changes until Game-boy answers.

**Cost:** about 3%.

### Final review and fixes (`workflow-review.js`, round "final")

Five lenses, judged from the evidence pack:
- L1, the Punk at 1 m (J1-J3, first person);
- L2, the player's limbs (J5);
- L3, look coherence (J4, VFX against the toon look, placeholders next to the Punk, edges, LUT, halftone defaults);
- L4, code, layers and test honesty (no number in a script, FK free of art, tests not loosened);
- L5, perf.

Each finding gets 2 skeptics. The fixers are Sonnet, in worktrees with disjoint files.

**Cost:** about 30-35% for the review, about 15% for the fixes.

---

## 8. Phase 4: the verdict, notes, docs, PR

- Pause 2 (§9).
- His notes become a fix round. A "no" from him names what's off, and the lead plans against §14's matching risk.
- Docs:
  - README "Milestone 4 status" and "Where M4 departs from the spec" (§13's departures, marked for his ruling);
  - ARCHITECTURE "Art and look (M4)": the art contract, binds, RigPaint, passes, FPView, the stand-ins;
  - `docs/milestones/M4-judgement-calls.md`, folded from `M4-calls/`;
  - HANDOFF.
- The PR into `main`, never merged before his sign-off.

**Cost:** about 10% for the notes fixes, about 3% for the docs and PR.

---

## 9. The two pauses

### Pause 1: the concept pick (already out)

- **What was DMed (21:42 CDT, HANDOFF).** Two sheets, uploaded to Michael's DM (`U0AQMKKBL93`):
  - Street Punks A-D (`assets/source/concepts/punk_{a_denim_vest,b_mohawk_tracksuit,c_two_tone_bomber,d_hoodie_jacket}.jpg`);
  - hero sheets A-C (`hero_{a_wraps_tee,b_jacket_boots,c_martial}.jpg`: a full figure plus callouts of the wrapped hand, the fist and the shoe).
  They were generated by `tools/gemini_image.py` from `concept_jobs.json` with `gemini-3-pro-image` at 2K: front A-pose, flat grey, cel style, a palette brief (the Punk teal with a yellow accent as in M3, no red; the hero navy, grey, off-white, black and tan).
  - Asked: one Punk and one hero, mix and match allowed.
- **No new DM is needed.** If he wants changes, run one Gemini edit round on his words (about $1), re-DM, and keep working meanwhile.
- **Reminder.** If there's no answer by the end of the rig gate, send one short reminder: "phase 1 done; the real Punk waits on your pick". Never pick for him.
- **Meanwhile:**
  - S0;
  - phase 1, all of it (the pipe-cleaner uses `punk_a` unless the pick has landed);
  - the rig gate;
  - V1-vfx and M1-motion, which are pick-free and can start early if Godot slots are free.
- **On the pick:** A2-generate starts at once.

### Pause 2: the final judgement

**What he gets** (one Slack DM; files uploaded to the DM):
1. **The playable build:** a Run-button code block `godot --path /Users/arachne/repos/beat-em-up-PoC` (his stated preference over a release), with:
   - the crowd room, where the Punks are in art;
   - F4, "Look stage": a Punk at 1 m, keys cycling standing, circle, attacks, reacts, down and damage looks;
   - F1, "Look" > "Art": `look_placeholder_bodies`, to flip back to M3 for comparison.
2. **Clips, as MP4, first person, 1600x900:**
   - E1 standing;
   - E2 in motion (circle, attacks);
   - E3 reacts and down;
   - E4 hits and damage looks;
   - E5 the six-Punk crowd fight;
   - E6 the player's arms and legs through the combos.
   Each comes with a stills sheet. There's also a before/after pair (E7: M3 placeholder and M4 art at the same frame and distance).
3. A five-line metrics summary: budgets, joint fit, the framing gate, the perf p95 and spawn hitch.
4. The asks:
   - **"Does the Punk look production-quality at 1 m, standing and in motion? Yes, or what's off."**
   - Then, separately and not blocking: the four deferred feel questions with F-due's measured numbers and defaults.
   - The M4 departures for his ruling.
   - The Tripo account's licence status (paid or free), for ASSETS.md.

---

## 10. Tripo credit budget (ceiling 800 of 1,500; `tripo.py` refuses below a 700 balance)

| # | Phase | Task | Options | Each | First try | Retries/fallback budgeted | Subtotal |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | Pipe-cleaner image-to-model (`punk_a` front, or the pick) | H3.1, std texture, v3.5 delight, pbr off, align_image, face_limit 30k, seed | 30 (≤40) | 1 | 0 | 30 |
| 2 | 1 | Rig-check | | 0 | 1 | | 0 |
| 3 | 1 | Rig v3.0 `unity` | | 25 | 1 | 1 (v1.0 `mixamo` if unity fails) | 50 |
| 4 | 2 | Punk multiview-to-model (front/back/side, then 4) | as 1 | 30 | 1 | 2 | 90 |
| 5 | 2 | Punk re-texture (new `texture_seed`) | v3.5 standard | 10 | 0 | 2 | 20 |
| 6 | 2 | Punk detailed geometry (only if J1 fails on geometry) | `geometry_quality detailed` | 50 | 0 | 1 | 50 |
| 7 | 2 | Punk rig v3.0 `unity` (landmarks, weight A/B) | | 25 | 1 | 0 | 25 |
| 8 | 2 | Punk glove part (multiview, face_limit 8k) | | 30 | 1 | 1 | 60 |
| 9 | 2 | Hero body multiview | | 30 | 1 | 2 | 90 |
| 10 | 2 | Hero rig v3.0 `unity` | | 25 | 1 | 0 | 25 |
| 11 | 2 | Hero fist part (wraps + fingerless glove) | | 30 | 1 | 1 | 60 |
| 12 | 2 | Hero shoe part | | 30 | 1 | 1 | 60 |
| 13 | 3 | Head part (contingency: the face fails at 1 m) | | 30 | 0 | 2 | 60 |
| | | Retarget presets, animations | not used: the procedural set animates | 10 | 0 | 0 | 0 |
| | | **Expected first-try path** | rows 1, 3, 4, 7-12 at one each | | | | **255** |
| | | **Planned ceiling with every budgeted retry** | | | | | **620** |

The ceiling leaves 180 of the 800 in reserve. That covers `v3.5` costing 40 instead of 30 on all nine generations (+90), or a single P1 generation (110) as a last resort, without asking. Every task's `credits_consumed` goes in the ledger and in ASSETS.md.

---

## 11. The done-when made checkable: "the Punk looks production-quality at 1 m, standing still and in motion"

### Measured (automatic; the build report, tests and the perf act)

| # | What | Threshold | Where |
| --- | --- | --- | --- |
| M1 | Budget and hygiene | Punk ≤ 15,000 triangles (probe excluded); player ≤ 30,000; 4-6 paints, none red; 0 unweighted; ≤ 4 influences; nothing on Root | `build_report.json`, `test_skinned_art`, `test_punk_art` |
| M2 | Joint fit | every deformer's authoring joint within 5 mm of the table chained through its swing; segment scale in [0.85, 1.18] | `SkinnedArt.validate`, build report |
| M3 | Volume fit | fist AABB centre within 10 mm of `FistPoint` at rest, size ±15% of 0.1 x 0.118 x 0.116; ≥ 95% of torso vertices inside the torso capsule r + 0.08; leg vertices within r + 0.06; head region within the head sphere r + 0.05 (cap brim and hair allowed by part tag); sole samples at y ∈ [-0.003, +0.003] | build report, `test_punk_art` |
| M4 | First-person framing | `test_art_silhouette`: share of view vs placeholder `Δ ≤ 4` pp per pose; the ported lens-clearance rules pass with the art | R1 |
| M5 | Deformation | strain p99.9 ∈ [0.6, 1.6], max ∈ [0.4, 2.2] over every named animation and Punk move at 5 phases; planted vertices ≥ -0.02 m | `test_art_deformation` |
| M6 | Ragdoll | skeleton vs `_visual` ≤ 1 mm, partial and full | `test_ragdoll_skinned` |
| M7 | Flash placement | contact-flash anchor within 2 cm of the CPU-skinned surface for head, torso and leg hits at 1 m; shown `hit_flash_frames` frames | `test_toon`, `test_hit_flash` |
| M8 | Marks stick | `use_bind_space` on skinned paints, CUSTOM0 = authoring positions; a look change changes no shader | `test_toon`, `test_vfx` |
| M9 | Perf (this M1, a soft proxy for SPEC's RTX 3060) | six art Punks plus player art, full look: p95 ≤ 16.7 ms and ≤ pre-M4 p95 + 2.0 ms back to back on a quiet machine; spawn hitch ≤ 33 ms with every new variant's first use | crowd "Perf, six with ragdolls", `look_perf_acts` |
| M10 | Suite | everything green, 0 `SCRIPT ERROR`/`ERROR`; with `look_placeholder_bodies` on, every M3 test behaves as on `main` | `tools/run_tests.sh` |

### Judged from captures (first person only; reviewers score 0-2, pass = no 0 and a mean ≥ 1.5; then Game-boy's yes or no)

| # | Item | Captures |
| --- | --- | --- |
| J1 | **Standing at 1 m:** silhouette chunky and readable; the face covered or simplified and holding up (glasses, cap); gloves read as fists; clean toon bands (no acne, banding noise or texture-lighting fights); even, unbroken ink hull; crisp interior ink lines; 4-6 flat colours; teal and yellow identity kept | `Look: punk standing`, `profile` |
| J2 | **In motion at 1 m:** no visible joint collapse or candy-wrap at shoulders, elbows, wrists, hips or knees, in the guard, jab, cross, shove, circle, flinches, stagger, knockdown and get-up; the outline steady as distance changes; feet planted; no pops between clips; marks don't swim | `circle`, `attacks`, `reacts`, `down`, `torture` |
| J3 | **Hit feel on the art:** the flash on the struck part and legible; damage looks clean → bruised → bloodied visible and stuck to the body; VFX ink matches the hull | `reacts`, the Look stage, vfx acts |
| J4 | **Context:** the Punk pops against the muted environment and next to placeholders; no doubled lines; LUT and halftone don't muddy | crowd fight, "Punk among placeholders" |
| J5 | **The player's limbs (first person):** wraps, gloves, legs and shoes at the highest detail; no hollow cap, seam or pop at the FP split | combo acts, looking down, KO view |

**Evidence pack** (`captures/m4/evidence/`, local; MP4s and sheets uploaded to the DM; `docs/milestones/M4-evidence.md` tracked):
- E1-E7 as in §9;
- E8, the metrics table M1-M10;
- E9, the build-report summaries;
- E10, the Tripo ledger total and the Gemini spend.

---

## 12. Coverage map (SPEC §10 and §12 → built, tested, seen)

| Requirement | Built | Tested | Seen |
| --- | --- | --- | --- |
| Ramp toon 2-3 bands, hard spec, rim, tinted shadows | L1 `toon.gdshader`, `toon_light.gdshaderinc` | `test_toon` | J1, every capture |
| One shader for everything, per-material parameters | L1 (rigs, pipe), L2 (rooms, grid via the include) | `test_toon`, `test_look_env` | J4 |
| Inverted-hull outline on characters and props, width scaled with distance | L1 `outline.gdshader`, `RigPaint.outline`; R0 on skinned | `test_toon` width mirror | J1/J2 at 0.9-8 m |
| Screen-space environment edges from depth and normals | L2 `EdgePass` | `test_look_env` | room acts, J4 |
| Optional halftone in shadows; colour LUT; no bloom except VFX | L1 (halftone), L2 (`LookGrade`, glow off) | `test_look_env` | J4 |
| Perf 1080p60, 6 enemies, RTX 3060 | P1/P2/P3-int perf runs (M1 proxy) | M9 | the perf table |
| Proportions chunky, oversized hands and feet | concepts, the fist envelope (R0-blender) | M3 | J1 |
| Faces covered, holding at 1 m | the concept pick, the detail mask, the head part contingency | | J1 |
| 4-6 flat colours, shared palette; red reserved | `palette.py` → paint slots | `test_art_palette` in `test_toon` | J1 |
| Period, original designs | concepts (Game-boy's pick) | | pause 1 |
| Player: arms, legs, shoes at the highest detail | P-player: parts, 30k, 1k mask | `test_player_art` | J5 |
| Pipeline 1 concept, 2-4 images, a pick | done (round 1) | | pause 1 |
| 2 image-to-3D, T- or A-pose | A1, A2 | the ledger | |
| 3 Blender clean-up: scale, normals, budget, head split, palette UV | R0-blender chain | build reports | |
| 4 Rig (the service's auto-rig if humanoid) | A1/A2 Tripo rig (landmarks, weight A/B) and Blender weights | M2, M5 | J2 |
| 5 Animate (Mixamo base, mocap strikes) | departure: the procedural set (+M1-motion) | M5 | J2 |
| 6 Export `.glb` to `/assets/export/`, humanoid skeleton | `export_glb.py`; departure: code binds on the shared skeleton | `test_skinned_art` | |
| 7 ASSETS.md log | every asset package | `test_assets_logged` | |
| Triangle budgets (player 30k, enemy 15k) | budgets in configs and ArtSpec | M1 | |
| Enemy animation list (idle, posture, walk/circle, attacks with wind-ups, reacts, knockdowns, get-up, KO, held, thrown) | the existing procedural set | `test_art_deformation` covers every id | `torture` |
| 2D effects: 8-10 words, 3 bursts, speed lines, droplets, splats, rear burst; SVG → 512 px | V1 (existing set + final pass) | `test_vfx` | vfx acts, J3 |
| M4 done-when | the whole plan | §11 M1-M10 | pause 2 |

---

## 13. Key judgement calls

1. **Fit the mesh to the fixed skeleton.** *Alternative:* fit the skeleton (bone rests) to the generated mesh. *Why not:* every reach test, hurtbox, rig point, ragdoll anchor and first-person rule (README M1: the lens, the relaxed stance, the FP-hidden set, the glove size) is table-derived and was approved. Moving joints would re-open M1-M3.
2. **Rebuild the binds on the code-built skeleton.** *Alternatives:* Godot's BoneMap retarget importer, or Tripo's skeleton playing Tripo clips. *Why not:* the importer conforms to a T-pose, +Z, Y-along-bone convention (blender-godot §5 [V]), and Tripo's presets have no strikes and none of the tuned timings.
3. **Keep the A-pose; the binds carry the swing.** *Alternative:* bake to arms-down rest in Blender (pose, apply, `armature_apply`; verified). *Why not:* chained LBS (A → down → guard) adds a second blend at the shoulders, and the boxer guard sits nearer the A-pose. Baking stays as the gate's fallback.
4. **Blender `ARMATURE_AUTO` weights on our table armature by default, with Tripo's weights A/B'd on the pipe-cleaner.** *Alternative:* Tripo's weights only. *Why not:* reviews report over-smoothed shoulders, and its finger bones need merging. Game-boy's "try Tripo's auto-rig first" is honoured: its joints are the fit landmarks, and its weights are compared on captures.
5. **The procedural set animates the art (a SPEC §10 step 5 departure, logged).** *Alternative:* Mixamo or Tripo clips. *Why not:* Mixamo is skipped (Game-boy), mocap isn't set up, and a generic clip has no wind-ups or frame-data sync.
6. **A full generated player body with an authoring-time FP split.** *Alternative:* generated limbs on the primitive torso and head. *Why not:* the KO view, the shadows and the side view show the whole body, and a primitive torso next to an art arm would seam at the shoulder.
7. **Fists and shoes as dedicated generated parts.** *Alternative:* the body generation's hands and feet. *Why not:* the concepts' hands are open (Tripo's preference), the rig has no finger bones, and the fists are 0.3-0.6 m from the lens for most of the game.
8. **Every rig moves to the toon `ShaderMaterial`.** *Alternative:* a second dictionary for skinned rigs only (rig-render §11), keeping the tests. *Why not:* SPEC says one shader for everything, and the placeholders must sit coherently next to the Punk. The cost is about 20 assert lines in three files.
9. **Outline on `material_overlay`, flash kept on `next_pass`.** *Alternative:* a `next_pass` chain. *Why not:* it would change `_show_flash_overlay`'s contract and three test asserts. The overlay is verified on skinned meshes.
10. **Damage in bind-space triplanar (CUSTOM0/1).** *Alternatives:* a UV2 mask (seams across islands) or vertex colour (too coarse). *Why:* it reuses the four seamless tiles and swaps textures only, like today.
11. **`FPView` CPU-skins and ray-casts `TriangleMesh`.** *Alternatives:* proxy primitives per bone (they'd test a shape we don't draw), or per-triangle GDScript rays (too slow). *Why:* measured at about 10 ms per exact body sample and about 3 ms on the probe.
12. **The primitive path stays the default for `art == null` (rig-render's Assumption A).** *Alternative:* restyle every rig as skinned now. *Why not:* about 80 primitive tests, and M6 owns the other archetypes.
13. **Paints as material slots, not a texture atlas (a departure, logged).** *Alternative:* one palette-atlas texture per character. *Why not:* per-actor colours, the flash and the "DARK takes no marks" rule are per paint. At seven characters the batching gain is nil. The 1k ink mask carries the drawn detail.
14. **The Punk gets a 1k ink mask too (an addition, logged; `detail_strength = 0` removes it).** *Alternative:* the palette only, as SPEC's enemy row says. *Why not:* interior lines carry most of "production quality at 1 m" on a flat-shaded body.
15. **Stand-ins: a Blender mannequin (0 credits), plus a 55-credit Tripo pipe-cleaner on an unpicked concept.** *Alternatives:* wait for the pick, or generate every concept. *Why:* the first proves the Godot side deterministically. The second answers Tripo's unknowns (rig names, facing, scale, the v3.5 texture cost) while the pick is pending, for about 7% of the allowance.
16. **Constant-pixel hull width with metre clamps** (one reading of "width scaled with distance"). *Alternative:* a pure distance-ratio width (the reader's `dist/ref`). *Why not:* that ignores the FOV and the resolution.
17. **The edge pass is a world quad with a character mask in ROUGHNESS.** *Alternative:* a compute `CompositorEffect`. *Why not:* more code. The quad is verified, debuggable, and serves every camera.
18. **The 1 m judgement uses scripted acts plus an in-game "Look stage".** *Alternative:* video only. *Why not:* Game-boy judges by playing, and the AI can't circle at 1 m.

---

## 14. Risks, and what happens if each shows

| Risk | Sign | Response |
| --- | --- | --- |
| LBS collapse or candy-wrap at elbows, shoulders, knees at 1 m | the strain test's worst-10, G2 sheets | R3-helpers (CopyTransformModifier3D half-joints, built in), weight smoothing at the joints, cuffs and sleeves at the wrists; then bake-to-arms-down; corrective blend shapes are deferred |
| The generated proportions are too far off the table | segment scale outside [0.85, 1.18] | regenerate the views with the mannequin guide weighted harder; Tripo re-generation (budgeted); `allow_warp` only with a design review |
| Tripo's rig names or joints are unusable | `rig_dump.json` | landmarks from the config (`landmarks`, manual), weights from Blender; spend nothing more on rigs |
| Multiview left/right label mirrored | the asymmetric wrap flips | swap the labels; no new images |
| The face or hands are mushy at 1 m | J1 | the detail mask first, then a head part (budgeted 60), then `geometry_quality detailed` (50) |
| Baked lighting in the texture | blotchy palette | `delight` on; a k-means palette replaces the texture anyway; re-texture 10 |
| The ragdoll skin diverges | `test_ragdoll_skinned` | the write-back (verified probe); if Godot restores poses differently in 4.7.2, write from a dedicated `SkeletonModifier3D` after `Ragdoll` |
| Flash and hull order wrong (flash over the ink) | P1-int capture | a higher flash `render_priority`, or the flash on `material_overlay` with the hull as the `next_pass` of the toon material (a swap; L1-tail) |
| M1 frame time over 16.7 ms with edges, MSAA, hulls and 6 skinned bodies | M9 | `look_aa_mode` FXAA (-2 ms), fewer edge taps or a half-resolution edge pass, `edge_enabled` off on the Mac; report both, since the RTX 3060 is the spec |
| First-use shader hitches | spawn line > 33 ms | `RigPaint.warm_up`, the `EdgePass` warm-up, and `VfxDirector` entries for every variant |
| The test blast radius is larger than mapped | R1's both-ways runs | R1 owns the ports; a failing threshold is reported with numbers, never loosened silently |
| Hull cracks at the split caps and part seams | J1/J5 | the `COLOR` smooth normals (verified on a cube) |
| The Cycles bake fails headless | detail-mask step | the numpy BVH rasterizer fallback (BVH lookup verified at face level) |
| The pick is slow | no answer by the gate | one reminder DM; V1 and M1 run; never pick for him |
| Tripo v2 sunset (2026-10-31), expired URLs | | v3 only; download in the same run; keep every accepted GLB in LFS |
| RAM (8 GB) with Blender and four Godot processes | swapping | `face_limit` ≤ 30k; Blender steps run serially; one capture slot per builder |
| LFS quota | large raw GLBs | commit accepted candidates only; rejected ones go to `_local/` |
| Licence unknown (Tripo paid or free account) | | ASSETS.md marks it; asked at pause 2, before any ship |
| Usage runs short mid-phase | the watcher's 90% | `wip:` commits every 15-20 minutes; the M3 resumable runner; phase boundaries in HANDOFF |

---

## 15. Usage estimate (% of a premium 5-hour window; 1 window point ≈ 0.16 weekly points, HANDOFF)

| Phase | Work | Window % |
| --- | --- | --- |
| 0 | S0 (Sonnet), lead set-up | 8-9 |
| 1 | A1 3, R0-blender 8, R0-godot 10, R1 10, L1 9, L2 8; P1-int 7 | 55 |
| Gate | 4 Opus lenses with skeptics 15-20; fixes about 10 | 25-30 |
| 2 | A2 4, P-punk 10, P-player 12, V1 6, M1 7 (+3 with R3); P2-int 6 | 45-48 |
| 3 | P3-int 8, F-due 3, final review 30-35, fixes 15 | 56-61 |
| 4 | the notes fix round 10, docs and PR 3 | 13 |
| **Total** | | **about 200-215, about 2.2 windows, about 33 weekly points** |

Phase 1 alone is about 55%, so it fits one fresh window with the gate starting in the next. Launch each package against the headroom (HANDOFF "Usage rules"). With the window under 60%, up to six heavy agents can run, and at most four of them Godot-bound.
