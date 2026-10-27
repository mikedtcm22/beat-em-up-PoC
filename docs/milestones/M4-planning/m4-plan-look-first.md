# Milestone 4 plan, look-first: the art pipeline proof

Independent planner, angle **look-first**, written 2026-10-26 against branch `m4/art-pipeline` at `85f7f39`.

**Read for this plan:** CLAUDE.md, the HANDOFF entries of 21:30 and 21:45, SPEC §3, §5, §6, §10, §11, §12, README's departures for M1-M3, ARCHITECTURE (Layers, Physics and visual layers, Humanoid rig, the hit flash, the KO view), the four files in `M4-codemap/`, and the code. Line numbers are at `85f7f39`.

**Probes run for this plan** (in a scratch project; no tracked file touched):
- **(a) Shader features.** Headless Godot 4.7.2 compiles a spatial shader that uses all of these: `FRAGCOORD` and `SCREEN_UV` in `light()`, `render_mode ambient_light_disabled`, `CUSTOM0`, `VIEWPORT_SIZE` and `PROJECTION_MATRIX` in `vertex()`, `stencil_mode`, and a `texelFetch` palette lookup. A deliberately bad shader prints `SHADER ERROR`, so the check is real.
- **(b) A LUT from a PNG.** A 256x16 PNG strip whose `.import` sets `importer="3d_texture"` and `slices/horizontal=16` imports headless as a 16³ `CompressedTexture3D`. `Environment.adjustment_color_correction` accepts it.
- **(c) Global uniforms.** Shaders with `global uniform` compile headless, but the dummy renderer checks neither the declarations nor the values (`global_shader_parameter_get` returns null). So the globals must be declared in `project.godot`, and tests check that list by parsing the file.

**SPEC §12, M4:** "Toon shader and outlines, final player arms and legs, one Street Punk taken through the full pipeline, the comic VFX set. **Done when:** the Punk looks production-quality at 1 m from the camera, standing still and in motion (Game-boy judges)."

---

## 0. The approach in one page

**Thesis.** "Production-quality at 1 m" is a look. At 1 m the Punk fills about half the frame: the 90° lens spans 2.0 x 1.125 m at that distance. The eye reads line weight, band edges, shadow hue, palette, face and hands before it reads polygons. The toon shader, outlines, edge lines, grade and VFX set at least half of the verdict, and that half needs no concept pick. So:

1. **Phase 0: set the target first.**
   - The lead writes the **look bible**, `docs/milestones/M4-look-bible.md`. It holds the numeric targets (§0.1) and a **1 m first-person rubric**: 15 judged items and 10 measured ones (§10).
   - A bench builder adds the **look acts**. These are fixed first-person shots: the Punk's face and body at 1 m, a half-circle strafe, the jab-cross, the shove, hit reactions, damage looks, distances, a lineup, the player's own limbs, the hold, and a turntable. It also writes a script that makes sheets and crops, and a script that compares frame times. Then it records **"before" captures** of the M3 look.
   - A scaffold lands every contract, so phase-1 builders own disjoint files.
   - A tools builder writes the Tripo v3 client with a credit ledger, and the headless Blender pipeline, proven on a synthetic body.
2. **Phase 1: build the whole rendering stack on today's placeholders while the pick is out.**
   - The stack: one toon shader for everything, the inverted-hull outline as `material_overlay`, the screen-space edge pass, an optional halftone, the grade LUT, and the comic VFX final pass. Four Godot builders work in parallel.
   - **Look gate 1** ends the phase. An adversarial review scores the placeholders and the street against the bible from captures, and the look defaults are locked. From then on, a Punk that looks bad means a bad mesh, not an unfinished shader.
3. **Phase 2: drive the assets to that target.**
   - On the pick, the lead runs Gemini for orthographic views (fists, plus the proportion template) and for **style frames**. The style frames are paint-overs of the bench's 1 m shots, used as reference targets. Then the lead runs the Tripo generations and auto-rigs through the ledger.
   - Two Blender builders take the Punk and the hero through clean-up, fitting to the joint table, palette, weights and the first-person split.
   - A Godot builder binds the skinned art to the existing `HumanoidRig`. It recomputes the binds, keeps the primitives as **proxies** so that about 80 placeholder-pinned tests keep their meaning, and adds the ragdoll write-back.
   - A motion builder gives the procedural set idle life and eased in-betweens, without touching any move clip.
4. **Phase 3: prove it at 1 m.**
   - Integration, and an F4 "Look stand" with the four deferred feel questions as A/B options.
   - A four-lens final review against the rubric, then fixes, docs and the PR.
   - **Pause 2:** Game-boy's judgement.

**Pauses.**
- The concept pick was DMed at 21:42 CDT. Phases 0 and 1 don't need it.
- The final judgement is the only other pause. Everything else takes the default that departs least, is logged, and keeps the spec value reachable as a tunable.

**Budget.** About 1.8 premium 5-hour windows (§14). Tripo: 200-530 credits planned, against a cap of 800 (§9). Gemini: about $3-5.

### 0.1 Look targets (numbers the bible starts from; look gate 1 locks them)

| Element | Target at 1080p (Movie Maker records 1600x900; scale px by 900/1080) |
| --- | --- |
| Character hull line | 3.5-4 px at 1-3 m, ≥ 2 px out to 10 m, never > 4.5 px; own body x0.8 |
| Environment edge line | 1-1.5 px; fades out from 25 m to 60 m |
| Ink | `HudStyle.INK` (0.07, 0.06, 0.09) for hull, edges, VFX strokes and HUD borders |
| VFX stroke | about 2x the character line at 1-2.5 m (today about 12 px, i.e. 3x) |
| Bands | characters: 3 (lit, mid at 72%, shadow at 42%); environment: 2. Band edge ≤ 2 px at 1 m |
| Shadow | never black: ≥ 40% of the lit value, hue 45% toward violet `(0.36, 0.32, 0.55)` |
| Specular | one hard highlight under 3% of the visible surface; glossy regions (shades, leather, studs) x3 |
| Rim | stepped, on characters only, about 25% of the silhouette band, +35% value |
| Saturation (HSV) | environment ≤ 0.30 (value 0.25-0.6); enemy main colours ≥ 0.5 |
| Red | hue 345-15° with saturation > 0.5 only in blood, the warning and finisher accents. The crowd room's car `(0.55, 0.2, 0.2)` (`crowd_room.gd:326`) breaks this and gets recoloured |
| Grade | LUT "street_dusk": cool shadows, warm highlights, low-chroma colours desaturated; blood red and the enemy palette kept within ΔE76 ≤ 6 |
| Halftone | off by default; when on, dots only in the shadow band, in 6 px cells |

### 0.2 The brief's questions, resolved (details in the cited sections)

- **Mesh to skeleton, never the reverse.** The joint table (`placeholder_body.gd:45`; rig-render codemap §9(d)) fixes every reach, hurtbox, rig point and the lens. Blender deforms the mesh onto it, using the joints from Tripo's auto-rig. Gemini's **proportion template** makes the mesh start close, and tests M3 and M4 prove the fit (§6 A-punk, §10).
- **What animates the Punk:** the existing procedural set (46 named animations plus `punk_jab`, `punk_cross` and `punk_shove`), through the unchanged `HumanoidRig.advance()`. No Tripo presets: v3 has no guard or strikes, and nothing yet retargets onto this identity-rest rig. Motion quality comes from weights tested at the extreme poses, the ragdoll write-back, idle life and eased in-betweens on non-move loops, and contact. Move clips stay identical, which a test enforces by hashing them (§6 M-motion).
- **The player:** a full generated body of 30k triangles in two skinned meshes. `BodyHidden` (head to the shoulder half of the upper arms) goes on `VIS_FP_HIDDEN` and still casts shadows. `Body` has dome caps at the mid-upper-arm cut and on the belly top. The fists are a separate generated mesh, rigid on `Hand` (§6 A-hero).
- **Flash, damage looks, blink-off:**
  - The contact flash stays the per-rig `next_pass` overlay on every material, the art's included.
  - The parry flash becomes emission uniforms.
  - Damage looks still swap a texture, never a variant. The same tiles are applied triplanar in object space on primitives and in bind-pose space (`CUSTOM0`/`CUSTOM1`) on art, so marks never swim.
  - Blink-off is `rig.visible` (`humanoid_rig.gd:390`), which covers art and hulls (§2.2, §2.5).
- **Outlines:** an inverted hull on `material_overlay`, which inherits layers, blink-off and skinning per instance. Width is in pixels, clamped, with FOV via `PROJECTION_MATRIX`. The player's own body gets x0.8 (§2.3).
- **Tests pinning placeholders:** `HumanoidRig.new()` still builds primitives. Art rigs keep their primitives as invisible **proxies** that `FPView` still ray-casts; their fit to the art is proven by M3 and M4. Material tests move to `ToonMaterial` accessors, about 66 lines in 4 files (§2.6, §6 A-skin).
- **LFS and ASSETS.md:** the binary types are already LFS (`.gitattributes:16-35`). Every concept, view, style frame, raw output, `.blend`, export, texture, palette and LUT gets a row (service, id, date, credits, licence, script). The Tripo licence stays "pending" until pause 2.
- **What stays placeholder:** the other archetypes and the dummies (toon primitives with hulls) and the box rooms (flat toon, edges, grade). Shot C7 and item J13 judge that it all reads as one game.
- **Deferred feel questions:** the flash's first-person size, the haymaker's flash, the knockdown view and grab-03's combat log. Each becomes a tunable defaulting to today's behaviour, is captured A/B with the art in, and goes to pause 2 (§7 F-feel).

---

## 1. Rules every package follows (paste into every builder prompt)

- **Worktree.** Work only in your absolute path `.worktrees/m4-<key>` (branch `m4/<key>`), and `cd` there for every command. Run `godot --headless --import --quit` there first. Never touch another checkout.
- **Code rules (CLAUDE.md).**
  - Static types, tabs, `##` docs on public API, and comment density like the surrounding code.
  - No numbers in scripts:
    - Attack numbers go in move `.tres` files via `tools/gen_moves.gd`.
    - Global tunables are `@export_range` values in `tuning_data.gd`, **in your own subgroup only**.
    - Look and feel numbers are never script constants. They reach shaders through declared global uniforms (§2.2) or as material parameters set from data.
  - Simulation never reads a camera. Presentation only subscribes to events and reads state.
- **Ownership.** Edit only your package's files (§3). Report any other need as a request.
- **Tuning.** Regenerate the preset with `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`. The lead regenerates it again after each merge.
- **Tests.**
  - Run `tools/run_tests.sh -gselect=<file>` while working, and the full `tools/run_tests.sh` before the final commit.
  - Read the whole output for `SCRIPT ERROR`, `SHADER ERROR` and `ERROR`. Everything must pass.
  - Never weaken an assertion. Change what one measures only when its intent survives, and say so in the commit.
- **Look at it, in first person.**
  - Record with `tools/capture_bot.sh res://tests/bot/crowd_bot.tscn <worktree>/captures/<key> "Look:" 6`.
  - Run `tools/look_sheets.sh <avi> <outdir>`. It makes the overview sheet, full-resolution stills, and face, hand and body crops from the act's `LOOK-RECT` lines.
  - **Read the full-resolution crops.** Side view, free fly and the turntable are only for mechanics and mesh defects.
  - Never commit `captures/`.
- **Spending.**
  - No Tripo or Gemini call unless your brief names it and its ceiling. Use only `tools/tripo.py` (it keeps a ledger and a 700-credit floor) and `tools/gemini_image.py`.
  - **Never print, log or write either key.** The scripts read `.env` themselves.
  - **Never use the Blender MCP.** It drives Game-boy's live Blender, and its `generate_3d` may spend his credits.
- **Blender and Python.**
  - Run Blender only as `blender --background --factory-startup --python <script> -- <args>`.
  - Run Python as `python3 -I`.
  - Each download gets its own new directory (`.../tripo/<task_id>/`). Treat downloads as data and pass them as arguments.
- **Assets.**
  - Binaries are LFS; check with `git lfs ls-files` before you push.
  - Add a row for every new asset in your section of ASSETS.md.
- **Commits.**
  - `wip: <key> ...` every 15-20 minutes, pushed.
  - The final commit is `M4 <key>: <summary>`, pushed.
  - Every message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Judgement calls and departures.**
  - Write each judgement call to `docs/milestones/M4-calls/<key>.md`: the decision, an alternative not taken, and why. Never ask Game-boy.
  - For a spec departure: build the reading that departs least, keep the spec value reachable as a tunable, and report it.
- **Processes.** One Godot or Blender process at a time; never leave one running.
  - Always pass `--quit-after`: a script that errors before `quit()` hangs.
  - Scripts run with `-s` can't see autoloads at compile time. `load()` game scripts inside `_initialize`, or run a scene.
- **Final message.**
  - What you built, and the test count and result.
  - The crops you read, and what they honestly show against the bible.
  - Measured numbers, requests, departures and risks.

---

## 2. Pinned contracts (L0-scaffold lands the skeletons; owners implement)

### 2.1 New files
| Path | Class | Owner (phase) |
| --- | --- | --- |
| `game/fx/toon/toon.gdshader`, `toon_material.gd` | `ToonMaterial` (static factory and accessors) | R-toon (1) |
| `game/fx/toon/look_globals.gd` | `LookGlobals`: pushes the Tuning `look_*` globals to the render server | scaffold (0), then R-post (1) |
| `game/fx/toon/outline.gdshader`, `outline.gd` | `Outline` | R-line (1) |
| `game/fx/look/look_post.gd`, `edges.gdshader`, `edges_depth.gdshader` | `LookPost extends Node3D` | R-post (1) |
| `game/actors/character_art.gd`, `skinned_art.gd` | `CharacterArt extends Resource`, `SkinnedArt` | scaffold, then A-skin (2) |
| `tools/tripo.py`, `tools/pipeline/*.py`, `tools/dump_poses.gd` | Tripo v3 client; Blender pipeline; pose export | A-tools (0) |
| `tools/look_sheets.sh`, `tools/perf_compare.sh`, `tests/bot/acts/look_acts.gd` | capture tooling and the look acts | L0-bench (0) |
| `tools/gen_lut.gd` | LUT strips | R-post (1) |

### 2.2 Toon material (R-toon)
```gdscript
class_name ToonMaterial extends RefCounted
const SHADER: Shader = preload("res://game/fx/toon/toon.gdshader")
enum Albedo { COLOR, TEXTURE }     # uniform int albedo_mode
enum Marks { OBJECT, BIND }        # uniform int mark_space: VERTEX/NORMAL (primitives) or CUSTOM0/CUSTOM1 (skinned)
static func paint(color: Color) -> ShaderMaterial       # one per PlaceholderBody.Paint per rig
static func art(texture: Texture2D) -> ShaderMaterial   # TEXTURE, BIND, marks and gloss read from the texture's alpha
static func flat(color: Color) -> ShaderMaterial        # environment: 2 bands, no rim
static func grid() -> ShaderMaterial                    # floors: flat + world 1 m / 5 m lines (grid.gdshader's look)
static func prop(color: Color) -> ShaderMaterial        # crates, dumpster, car, pipe
static func set_albedo(mat: Material, color: Color) -> void
static func albedo_of(mat: Material) -> Color
static func set_emission(mat: Material, color: Color, energy: float) -> void  # parry flash
static func emission_energy_of(mat: Material) -> float
static func set_damage(mat: Material, tile: Texture2D, tile_m: float) -> void # swaps a texture, never a variant
static func damage_of(mat: Material) -> Texture2D
static func is_toon(mat: Material) -> bool
```
- **Shader:** `render_mode ambient_light_disabled` with a custom `light()`.
  - Per-material uniforms: `albedo`, `albedo_mode`, `albedo_tex` (filter_linear_mipmap), `bands_override`, `spec_mult`, `rim_mult`, `halftone_mult`, `emission_color`, `emission_energy`, `damage_tex` (default `VfxArt.clear_detail()`), `damage_tile_m`, `mark_space`, `grid_strength`, `grid_color`.
  - The art texture's alpha has three values:
    - 1.0: matte, takes marks;
    - 0.5: glossy, takes no marks, spec x3;
    - 0.0: matte, takes no marks (the DARK paint).
- **Globals.** The scaffold declares every starred property of §2.7 in `project.godot [shader_globals]`.
  - `LookGlobals.apply(Tuning.data)` pushes their values. `game/autoload/tuning.gd` calls it at start-up and on every `Tuning.changed`.
  - `tests/test_look_globals.gd` parses `project.godot` and checks that each global is declared with the right type.
- **HumanoidRig (R-toon's region).**
  - `_materials` becomes `Dictionary[int, ShaderMaterial]` (`:147`).
  - New: `var _art_material: ShaderMaterial = null`, which A-skin sets.
  - `func materials() -> Array[ShaderMaterial]` returns the paint materials plus the art material. It is the one loop behind `set_flash` (`:396`), `_show_flash_overlay` (`:516`) and `set_damage_look` (`:528`).
  - New: `paint_material(paint: int) -> ShaderMaterial` and `paint_color(paint: int) -> Color`.
  - `next_pass` keeps today's meaning: the overlay while a flash runs, otherwise null.
- **DamageLook.** `prepare(material: ShaderMaterial, paint: int)` and `apply(material: ShaderMaterial, paint: int, level: int)`. The new `apply_art(material: ShaderMaterial, level: int)` uses the texture's alpha where `bruisable(paint)` is used today.

### 2.3 Outline (R-line)
```gdscript
class_name Outline extends RefCounted
enum Kind { PRIMITIVE, SKINNED, PROP }   # extrude_mode: RADIAL (normalize(VERTEX); boxes don't crack) or NORMAL (smooth skinned)
static func attach(mesh: GeometryInstance3D, kind: Kind, own_body: bool = false) -> void   # material_overlay, shared per kind
static func width_px(dist_m: float, viewport_h: float, own_body: bool = false) -> float     # GDScript mirror for tests
```
- **Shader:** `render_mode unshaded, cull_front`, with fog on.
  - It extrudes `px * d * 2 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y)` metres, where `d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1)).z`.
- **Call sites** (the scaffold places them):
  - `HumanoidRig._build_meshes`, on each primitive (`:739-754`);
  - the new `RoomKit.add_prop`, used by `crowd_room._build_props` (`:322`) and the training room's crates;
  - `weapon.gd:42`;
  - `SkinnedArt.attach` (A-skin).
- **Switch:** `look_outline_primitives` (a bool read at build time) turns the hulls on primitives off, for perf.

### 2.4 LookPost (R-post)
```gdscript
class_name LookPost extends Node3D   # added by RoomKit.build_presentation() (both rooms), never without presentation
static func warm(material: Material, skinned: bool = false) -> void   # first-use warm-up queue (windowed), like VfxDirector.begin_warm_up
func edge_material() -> ShaderMaterial
```
- **The edge quad.** A `QuadMesh(2, 2)` child of LookPost. It is a world node, so it serves the first-person, side and free-fly cameras.
  - Node settings: `extra_cull_margin 16384`, no shadows.
  - Material settings:
    - `render_priority = RENDER_PRIORITY_MIN + 1`: after the flash at -128, before the comic sprites at 0-3;
    - `render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled`;
    - it outputs `ALBEDO = ink` and `ALPHA = edge`.
  - **It never reads `hint_screen_texture`.** A full-screen copy would erase the transparent flash drawn just before it.
  - Two variants, picked by `look_edge_normals`:
    - `edges.gdshader`: depth plus `hint_normal_roughness_texture`;
    - `edges_depth.gdshader`: depth only, with normals rebuilt from depth.

    The normal buffer is the main cost on the M1 (fx-env codemap §6.3).
- **The grade.**
  - From `look_grade_enabled` and `look_grade_lut`, LookPost sets `adjustment_enabled` and `adjustment_color_correction` on the room's `WorldEnvironment`. The LUT is `res://assets/export/look/grade_<name>.png`, imported as a `3d_texture` with 16x1 slices (verified).
  - It also sets the tonemap from `look_tonemap`.
  - It sets the root viewport's `msaa_3d` and `screen_space_aa` from `look_msaa` and `look_fxaa`.
  - Glow stays off.

### 2.5 Character art (A-skin)
```gdscript
class_name CharacterArt extends Resource
@export var scene: PackedScene                  # the imported GLB
@export var body_mesh: StringName = &"Body"
@export var hidden_mesh: StringName = &""       # player: &"BodyHidden" → VIS_FP_HIDDEN when first_person_body
@export var texture: Texture2D                  # palette-only albedo + mark/gloss alpha (§2.8)
@export var gloss_spec_mult: float = 3.0        # data, not a script constant
class_name SkinnedArt extends RefCounted
static func attach(rig: HumanoidRig, art: CharacterArt) -> Array[MeshInstance3D]
static func is_proxy(mesh: MeshInstance3D) -> bool      # hidden primitive kept for tests (meta &"art_proxy")
static func is_art(mesh: MeshInstance3D) -> bool        # mesh.skin != null
static func skin_for(rig: HumanoidRig, art: CharacterArt) -> Skin   # cached per art and round(rig_scale * 10000)
static func cpu_skin(rig: HumanoidRig, art_mesh: MeshInstance3D) -> PackedVector3Array  # tests: rig-space vertices at the current FK
```
- **The `art` export.** The scaffold adds `@export var art: CharacterArt` to `HumanoidRig`; it is set before `build()`.
- **Attaching.** `_build_meshes()` builds the primitives as today, then calls `SkinnedArt.attach` if `art != null` and `Tuning.data.art_skinned_enabled`. `attach`:
  1. **Loads the GLB once** per art (a static cache). It rebuilds each surface with `ARRAY_CUSTOM0` holding the bind position and `ARRAY_CUSTOM1` the bind normal.
  2. **Builds the Skin for this rig,** in the GLB's bind order: `bind' = Scale(s) * inverse(Transform3D(Basis(R), p))`, where `R` is the shortest arc from the rig's rest bone direction to the GLB's. This is the blender-godot codemap's §6.2, verified on the real rig at 1.8 and 2.3 m, in A-pose and arms-down. `neutral_bone` is aliased to Root; any unknown bone name is an error.
  3. **Adds the meshes:** one `MeshInstance3D` per art mesh under `rig.skeleton`, with `skeleton = ^".."`, `skin`, `material_override = rig._art_material` (`ToonMaterial.art(art.texture)`) and `Outline.attach(mi, SKINNED, rig.first_person_body)`.
  4. **Joins the mesh lists:** appends each mesh to `_body_meshes` or `_head_meshes`, so `_apply_layers()` (`:1125`) keeps working.
  5. **Hides the primitives as proxies:** `visible = false` and meta `&"art_proxy"`. Names, followers and layers don't change.
  6. **Warms up:** queues `LookPost.warm(rig._art_material, true)`.
- **Hooks.** The scaffold adds a virtual `CombatActor._configure_art(rig)`, called right after `_configure_rig` (`combat_actor.gd:1582`). `StreetPunk` and `PlayerCharacter` override it.
  - It is not `_configure_rig`, because tests use that one to dress scratch rigs (`test_humanoid_rig.gd:162`, `enemy_move_checks.gd:233`, `test_enemy_moves_thug.gd:158`).
- **Ragdoll write-back.** `Ragdoll._process_modification_with_delta` (`ragdoll.gd:614-647`) writes `_visual`'s local rotations, and the position of Hips and Root, back into the skeleton. This takes the gap between skin and blended pose from 0.115 m to 0.0000 (rig-render codemap §9(a)3).
- **The KO view.** `FirstPersonCamera._head_clear_of` (`first_person_camera.gd:384-394`) skips meshes where `SkinnedArt.is_art` is true; the posed proxies do the test instead.
- **Debug switch.** `Tuning.art_skinned_enabled`, in group "Debug", defaults to true. It gives A/B captures and placeholder-only perf runs.

### 2.6 FPView (scaffold)
- **Enumerations.** `tests/fp_view.gd`'s filters (`:50`, `:194`, `:212`) skip every mesh where `SkinnedArt.is_art` is true. They keep a proxy when its parent is visible in the tree.
- **Distance helpers.** `mesh_distance` and `nearest_mesh` skip skinned meshes, so the `SphereMesh` cast at `:184` never meets an `ArrayMesh`.

### 2.7 Tuning group "Look"
The group comes after "VFX"; `test_vfx.gd:1056-1058` only needs VFX to directly follow Hit feel. The scaffold creates every property below, and the owners tune the defaults. `*` marks a global uniform.

| Subgroup (owner) | Properties (defaults) |
| --- | --- |
| Toon (R-toon) | `look_bands`* 3, `look_band_lit_cut`* 0.55, `look_band_mid_cut`* 0.12, `look_band_softness`* 0.015, `look_mid_value`* 0.72, `look_shadow_value`* 0.42, `look_shadow_tint`* (0.36,0.32,0.55), `look_shadow_tint_mix`* 0.45, `look_spec_cut`* 0.92, `look_spec_strength`* 0.5, `look_rim_width`* 0.28, `look_rim_strength`* 0.35, `look_halftone_enabled`* false, `look_halftone_cell_px`* 6, `look_halftone_strength`* 0.35 |
| Outline (R-line) | `look_outline_px`* 3.0, `look_outline_ref_m`* 3.0, `look_outline_falloff`* 0.25, `look_outline_min_px`* 1.5, `look_outline_max_px`* 4.5, `look_outline_fp_mult`* 0.8, `look_outline_color`* INK, `look_outline_primitives` true |
| Edges (R-post) | `look_edges_enabled` true, `look_edge_normals` true, `look_edge_px`* 1.25, `look_edge_depth_threshold`* 0.12, `look_edge_normal_threshold`* 0.45, `look_edge_fade_start_m`* 25, `look_edge_fade_end_m`* 60 |
| Grade (R-post) | `look_grade_enabled` true, `look_grade_lut` enum (neutral, street_dusk), `look_tonemap` enum (linear, reinhard, filmic, aces, agx; default filmic), `look_msaa` enum (off, 2x, 4x; default 4x), `look_fxaa` false |
| Motion (M-motion) | `look_idle_breath_deg` 1.2, `look_idle_breath_s` 3.4, `look_idle_sway_m` 0.008, `look_ease_strength` 0.6 (read at build time) |
| Hit feel > Hit flash (F-feel) | `hit_flash_max_view_share`* 1.0 (1 = off, today's flash) |

### 2.8 Assets: layout, naming, import path
```
assets/source/concepts/                      round 1 (exists) + later rounds, concept_jobs.json
assets/source/characters/palette.json        shared palette: cells {name, hex, alpha 1|0.5|0, paint}
assets/source/characters/proportion_template_{front,side}.png
assets/source/characters/tripo_ledger.jsonl  label, endpoint, options, task_id, status, credits_consumed, balance before/after, files
assets/source/characters/<char>/views/       Gemini orthographic views + views_jobs.json   (<char> = punk | hero)
assets/source/characters/<char>/tripo/<task_id>/  model.glb, preview.webp, task.json (raw, untouched)
assets/source/characters/<char>/pipeline.json, reports/*.json, <char>.blend
assets/source/look/style_frames/ (+ jobs.json), assets/source/look/lut/*.json
assets/export/characters/palette.png         16x16 swatch atlas from palette.json (the shared palette atlas)
assets/export/characters/<char>/<char>.glb   mesh + weights only (23 bones, no animations, no images)
assets/export/characters/<char>/<char>_albedo.png   2048², palette colours only, alpha = marks/gloss
assets/export/characters/<char>/<char>_art.tres     CharacterArt
assets/export/look/grade_<name>.png          256x16 LUT strip (.import: "3d_texture", slices 16x1)
tests/fixtures/art/test_body.glb (+ _albedo.png, _art.tres)   synthetic A-pose body
```
- **Blender to GLB.**
  - The character faces **+Y in Blender**, which becomes -Z in Godot.
  - The armature, `Armature`, holds exactly the 23 `PlaceholderBody.BONE_NAMES`, built from the joint table with the arm chain turned to the mesh's measured A-pose angle. The vertex groups carry the same names.
  - The mesh objects are `Body` (plus `BodyHidden` for the hero), with one material slot, `ART`.
  - Export options: `export_format="GLB"`, `export_yup=True`, `export_skins=True`, `export_influence_nb=4`, `export_animations=False`, `export_def_bones=True`, `export_leaf_bone=False`, `export_apply=False`, `export_image_format="NONE"`, `export_materials="PLACEHOLDER"`.
  - The mesh is smooth-shaded, has no unweighted vertex and no Root weight, and its weights are normalized to 4 influences.
- **Godot import.**
  - Options: `meshes/generate_lods=false`, `meshes/create_shadow_meshes=true`, `skins/use_named_skins=true`, `animation/import=false`. The albedo PNG is lossless with mipmaps.
  - From the GLB we use only its `MeshInstance3D`s, its `ArrayMesh`es and the joint positions in its named-bind `Skin`.
  - Its Skeleton3D and binds are never reused. Neither is Godot's BoneMap / SkeletonProfileHumanoid retarget importer, which rewrites bone axes to a T-pose facing +Z (blender-godot codemap §5).

### 2.9 Tool contracts (A-tools)
- **`python3 -I tools/tripo.py`.** Commands:
  - `balance`
  - `upload <file>`
  - `multiview --front --back --left [--right] --seed N --face-limit N [--detailed-geometry] --label L --char C`
  - `image --input <png>`
  - `rig-check --input <task_id>`
  - `rig --input <task_id|glb> --version v3.0-20260909 --spec unity`
  - `texture --input <task_id> --texture-seed N`
  - `retarget --rig <task_id> --anims preset:walk`

  Behaviour:
  - It calls `https://openapi.tripo3d.ai/v3` only; v2 shuts down on 2026-10-31.
  - `--dry-run` prints the request body and the expected cost.
  - It refuses any call that would leave less than 700 credits (`--floor`).
  - It downloads the outputs at once, with no auth header, into `tripo/<task_id>/`, because the URLs expire after 5 minutes.
  - It appends a ledger line for every call, and scrubs the key from every message.
- **The pipeline.** `blender ... --python tools/pipeline/run_character.py -- --config <pipeline.json> [--steps ...]`.
  - The steps: `normalize, joints, fit, cleanup, palette, weights, split_fp, export, verify, render`.
  - Each step writes `reports/<step>.json` and fails loudly against the §10 limits.
- **Helper scripts.**
  - `synth_body.py` builds the synthetic body and renders the proportion templates.
  - `pose_apply.py` poses the Blender armature from the JSON written by `tools/dump_poses.gd`. The JSON holds the procedural key poses as rig-space globals, so bone roll doesn't matter. It renders Workbench stills of the extremes.

### 2.10 Look acts
`tests/bot/acts/look_acts.gd` belongs to L0-bench. M-motion adds C12 in phase 2, and A-int finishes the file in phase 3.
- **Loading.** `crowd_bot._collect_acts()` (`crowd_bot.gd:370`) loads the file in the crowd room. Act titles start with `Look:`.
- **What every act does.** Hide the caption, freeze the AI, set god mode, and seed the VFX random generator.
- **What every act prints.**
  - `LOOK-RECT <slug> f<frame> <head|hands|body> x y w h`: a rectangle in 1600x900 px, from `get_visual_point_transform` projected by the active camera;
  - `LOOK-MARK <slug> f<frame> <label>`.

| Id | Act | Shows |
| --- | --- | --- |
| C1 | `Look: Punk face at 1 m` | pitch +8°, 3 s idle |
| C2 | `Look: Punk body at 1 m` | default pitch -6°, 3 s idle |
| C3 | `Look: Punk strafes at 1 m` | AI frozen; the actor moved on a half circle at 1.0-1.3 m facing the lens, with `rig.play_locomotion`, then a step in and a step back. AI-driven circling at 1 m doesn't work (fx-env codemap §9.3) |
| C4 | `Look: Punk attacks at 1 m` | `force_attack(0)` jab-cross, then `force_attack(1)` shove |
| C5 | `Look: Punk reacts at 1 m` | jab (flinch and flash), hook (partial ragdoll), uppercut (launch), get-up; then health at 100/65/30% held 1 s each |
| C6 | `Look: distances` | the Punk at 1, 2.5, 5 and 10 m |
| C7 | `Look: lineup` | the Punk with a Kicker, a Thug and a Bruiser at 2.2 m, the street behind |
| C8 | `Look: own limbs` | looking down 45°: jab, cross, hook, front kick, block guard, walking |
| C9 | `Look: street tour` | room_acts' tour |
| C10 | `Look: turntable` | side-camera orbit at rest, in the guard and lying (mesh QA) |
| C11 | `Look: hold the Punk` | grab, three knees, throw |
| C12 | `Look: extremes` | (M-motion) slowed peak poses: elbow 150°, knee -130°, arm raise 140°, spins, lying |
| C13 | `Look: Punk, impact frame off` | C5 with `impact_frame_enabled = false` |

---

## 3. Hot spots: who owns which file when

| File | P0 | P1 | P2 | P3 |
| --- | --- | --- | --- | --- |
| `game/actors/humanoid_rig.gd` | scaffold (`art`, the `Outline.attach` and `SkinnedArt.attach` calls) | **R-toon** (materials, flash, damage, colours: `:147`, `:396-402`, `:516-531`, `:723-737`, `:1114-1122`) | **A-skin** (art, proxies) | A-int |
| `game/actors/ragdoll.gd` | — | — | A-skin | A-int |
| `placeholder_anims.gd`, `placeholder_poses.gd` | — | — | M-motion (idle and ease only) | A-int |
| `game/actors/combat_actor.gd` | scaffold | — | — | — |
| `street_punk.gd`, `player.gd` | — | — | A-skin | A-int |
| `first_person_camera.gd` | — | — | A-skin | F-feel |
| `tuning_data.gd` | scaffold (group) | owners, each in its own subgroup | owners | owners |
| `tuning.gd`, `project.godot [shader_globals]` | scaffold | lead (on request) | lead | lead |
| `project.godot [rendering]` | — | R-post | — | — |
| `room_kit.gd` | scaffold (factories delegate to ToonMaterial and return `Material`; `add_prop`; LookPost) | **R-post** | — | — |
| `test_room.gd` | scaffold (calls RoomKit) | — | — | — |
| `crowd_room.gd` | scaffold (`add_prop`) | R-post (colours) | — | — |
| `weapon.gd` | scaffold (outline call) | R-toon | — | — |
| `vfx_director.gd`, `comic_sprite.gd`, `vfx_art.gd`, `impact_frame.*`, `speed_lines.gd`, `tools/gen_fx.gd`, `assets/*/fx/` | — | **R-vfx** | — | F-feel (`vfx_director.gd` only) |
| `damage_look.gd` | — | R-toon | A-skin (`apply_art`) | — |
| `hit_flash.gdshader`, `combat_log_overlay.gd`, `help_overlay.gd` | — | — | — | F-feel |
| `cheat_menu.gd` | — | — | — | A-int |
| `tests/fp_view.gd` | scaffold | — | A-skin | A-int |
| `test_hit_flash.gd`, `test_humanoid_rig.gd` | — | R-toon (material lines) | A-skin (skinned skips) | A-int |
| `tests/test_damage_look.gd` (moved verbatim from `test_vfx.gd:688-835`) | scaffold | R-toon | A-skin | — |
| `test_vfx.gd` | scaffold (the move) | R-vfx | — | F-feel |
| `test_ko_view`, `test_health_bars`, `test_player_grabbed`, `test_grab_view`, `test_launch_from_hold` | — | — | A-skin (skinned skips only) | A-int |
| `look_acts.gd` | L0-bench | — | M-motion (C12) | A-int |
| `tools/pipeline/*` | A-tools | — | A-punk (shared modules); A-hero (`split_fp.py`, `fist_merge.py`, `hero_*.py`) | — |
| `ASSETS.md` | scaffold (adds the Characters and Look sections) | R-vfx (Effects), R-post (Look) | A-punk and A-hero (their rows) | A-int |
| README, ARCHITECTURE, HANDOFF, the look bible, `tuning/default.json` | lead | lead | lead | lead |

---

## 4. Phase 0: target, contracts, tools

**The lead first** (no builder):
1. Write the look bible from §0.1 and §10.
2. Copy `docs/reviews/M3/workflow-build.js` and `workflow-review.js` to `docs/reviews/M4/`, with the `M4 <key>:` commit prefix and `m4/` branches.
3. Write `args-P0.json`.

### L0-scaffold (Sonnet, Godot-bound; est 6%)
**Owns** the P0 cells of §3.

**Brief:**
1. **Skeleton files.** Create every §2.1 file as a compiling skeleton with its signatures. **The stubs keep the M3 look:**
   - `ToonMaterial.flat` and `ToonMaterial.grid` return today's materials (code moved from `room_kit.gd:116-131`);
   - `Outline.attach` and `LookPost.warm` do nothing;
   - `LookPost` is empty.
2. **Hooks.**
   - `HumanoidRig.art`, the `Outline.attach` call in `_build_meshes`, and `SkinnedArt.attach` after it.
   - `CombatActor._configure_art`.
   - `RoomKit.add_prop`, used for the crates, the dumpster and the car.
   - `test_room.gd` calls RoomKit's environment, `flat_material` and `grid_material` instead of its copies (`test_room.gd:65-92`, `:95`, `:201`).
   - The outline call in `weapon.gd`.
3. **Tuning.** The "Look" group, `art_skinned_enabled` and `hit_flash_max_view_share` (§2.7). Also the `[shader_globals]` for the starred properties, the `LookGlobals` list and `apply()`, and the hook in `tuning.gd`.
4. **Test moves.** Move `test_vfx.gd:688-835` verbatim into `tests/test_damage_look.gd`.
5. **FPView.** Apply the rules of §2.6. They do nothing until art exists.
6. **ASSETS.md.** Add the M4 sections, with rows for concept round 1 (`gemini-3-pro-image`, 2K, `concept_jobs.json`).

**Tests:**
- The full suite passes.
- New `tests/test_m4_contracts.gd`:
  - every class and signature exists;
  - the Look group comes after VFX;
  - every global is declared;
  - with no art, the rigs still have 41 and 45 meshes, as today.

**Done:** merged, and the C1 and C9 captures look identical to `main`.

### A-tools (Sonnet, Python and Blender; est 7%; runs alongside L0-scaffold)
**Owns** `tools/tripo.py`, `tools/pipeline/*`, `tools/dump_poses.gd`, `palette.json`, `palette.png`, the proportion templates, and `tests/fixtures/art/test_body.*` (except the `.tres`).

**Brief:**
1. **The Tripo client,** as §2.9. Try it live only with `balance` and `--dry-run`.
2. **The pipeline steps:**
   - **joints:** parsed from `BONE_REST` and `BONE_PARENT` in `placeholder_body.gd`, never retyped;
   - **fit:** pose and stretch a source armature onto the target joints, apply it to the mesh, and keep the UVs;
   - **cleanup:** merge by distance, delete loose parts, make normals consistent, smooth-shade, then Decimate COLLAPSE to budget;
   - **palette:** posterize to the character's `palette.json` cells (k-means seeded from the palette, then snapped, with two 3x3 majority passes), writing a 2048² PNG with alpha from each cell;
   - **weights:** ARMATURE_AUTO on our A-pose armature, or a transfer by bone name from a Tripo-weighted mesh. Finger, twist, jaw and eye weights merge into Hand, LowerArm, UpperArm and Head. Then fill unweighted vertices from their nearest neighbours (KDTree), limit to 4 influences, normalize, and zero Root;
   - **export, verify, render:** export as §2.8, re-import to check the 23 groups and the weight sums, and render Workbench stills (front, side, back, and the extremes via `pose_apply.py`).
3. **Pose export.** `dump_poses.gd`, one headless run.
4. **End-to-end proof.** Run `synth_body.py` through the whole pipeline to make `test_body.glb`. One `godot --headless --import --quit` must show 23 binds and no `neutral_bone`.
5. **The proportion templates.**

**Tests:** `tools/pipeline/self_test.py` runs every step on the synthetic body and checks:
- a joint residual of 0;
- the triangle budget;
- ≤ 6 colours;
- no unweighted vertex;
- ≤ 4 influences;
- no Root weight.

**Done:** the fixture is in LFS, and a dry run of the Punk's planned calls prints 85 credits.

### L0-bench (Sonnet, Godot-bound; est 6%; after the scaffold merges)
**Owns** `look_acts.gd`, `tools/look_sheets.sh`, `tools/perf_compare.sh` and `tests/test_look_acts.gd`.

**Brief:**
1. **The acts:** C1-C11 and C13, with their `LOOK-RECT` and `LOOK-MARK` lines.
2. **`look_sheets.sh`:** a 6 fps overview tile, full-resolution stills at every mark, and 2x crops of the head and hands. Use `-fps_mode vfr`.
3. **`perf_compare.sh <branch-a> <branch-b>`:**
   - runs "Perf, six with ragdolls" windowed with vsync off, 3 runs per branch, back to back;
   - refuses to run if the 1-minute load average is above 3.0;
   - prints the mean, p95, worst, spawn hitch, first-hit hitch and first-finisher frame time.
4. **The "before" pack:** record every act into `captures/m4_before/`, with a baseline from a quiet machine.

**Tests:** the acts load and compile. One act runs headless for 120 ticks with no errors and prints its RECT lines.

**Done:** the before pack exists. The lead has stills of C1, C4, C7 and C8 for the style frames.

---

## 5. Phase 1: the rendering stack on placeholders (4 Godot builders), then look gate 1

### R-toon (Sonnet; est 10%)
**Owns** the R-toon cells of §3 and `tests/test_toon_material.gd`.

**Brief:**
1. **`fragment()`:**
   - albedo by mode;
   - triplanar damage from the varyings `mark_p` and `mark_n` (VERTEX and NORMAL in object space, or CUSTOM0 and CUSTOM1), mixed by the tile's alpha x the mark weight;
   - emission from the uniforms;
   - world-space grid lines on floors, ported from `grid.gdshader`.
2. **`light()`:**
   - `lit = dot(NORMAL, LIGHT) * ATTENUATION` (the shadow is included);
   - 2 or 3 bands, with smoothstep softness from the globals;
   - shade from the shadow value tinted toward `look_shadow_tint`, up through mid to lit, never black;
   - a hard spec, `step(cut, dot(N, H))` x `spec_mult`, x3 where alpha says glossy;
   - a stepped rim;
   - the halftone, only in the shadow band, in `FRAGCOORD` cells scaled by the viewport height (pass the height through a varying or a global if `VIEWPORT_SIZE` isn't there).
3. **Render mode:** `ambient_light_disabled`, so the sky's gradient no longer muddies the shadow side. Fog stays.
4. **Switch everything to the toon shader:** `ToonMaterial`, the rig's material region, `DamageLook`, the pipe, and the RoomKit factories (ToonMaterial's internals). Call `LookPost.warm` once per process for each material kind.
5. **Update the material tests:** `test_hit_flash`, `test_damage_look` and `test_humanoid_rig`'s material lines switch to the accessors and `materials()`. Keep each test's intent: for example, "never switches the variant" becomes "the same `Shader`, only parameters changed".

**Tests:**
- New `test_toon_material.gd`:
  - every rig, room and prop material is toon;
  - colours round-trip;
  - parry emission works;
  - a damage swap keeps the shader;
  - the flash `next_pass` is on every material or on none;
  - no `SHADER ERROR` when loaded headless;
  - bruises aren't red.
- The full suite.

**Captures:** C1, C2, C5, C7 and C9 against the before pack. Crop the placeholder Punk's face and gloves at 1 m.

**Done:**
- the tests pass;
- the crops show 3 crisp bands, tinted shadows and one highlight;
- the perf delta is ≤ +0.5 ms.

### R-line (Sonnet; est 7%)
**Owns** `outline.gdshader`, `outline.gd` and `tests/test_outline.gd`.

**Brief:**
1. **Implement §2.3:**
   - RADIAL extrusion on primitives: BoxMesh splits vertices per face, so extruding along NORMAL cracks the corners (blender-godot codemap §8.2);
   - NORMAL extrusion on skinned art;
   - the pixel formula, own body x `look_outline_fp_mult`, one shared material per kind;
   - `LookPost.warm`.
2. **Check and record four things:**
   - whether `material_overlay` draws in the shadow pass (if it does, report the shadow fattening, and accept it at 4 px);
   - that the hull doesn't clip a contact flash near the silhouette;
   - no artefacts on the player's own body near the lens;
   - that `set_shown(false)` hides the hulls.

**Tests:**
- `width_px` is monotone, stays within [min, max], and scales with viewport height and FOV;
- every primitive, prop and the pipe has the overlay; walls and floors don't;
- layers are untouched;
- the outline never uses `next_pass`.

**Captures:**
- C6: measure the line's px at 1, 2.5, 5 and 10 m on full-resolution stills, and report the 4 numbers;
- C1, C7 and C8.

**Done:** 2.0-4.5 px at 1080p-equivalent from 1 to 10 m, and no cracks at box corners in the C1 crops.

### R-post (Sonnet; est 8%)
**Owns** `game/fx/look/*`, `look_globals.gd`, `tools/gen_lut.gd`, `assets/*/look/`, `room_kit.gd`, `crowd_room.gd` (colours) and `project.godot [rendering]`.

**Brief:**
1. **LookPost** (§2.4): both edge variants, with no lines on the sky, a fade with distance and px scaling.
2. **`gen_lut.gd`:** writes `grade_neutral` and `grade_street_dusk` from JSON recipes, with `.import` files that make them 3D textures.
3. **Environment and room colours:**
   - the tonemap, MSAA and FXAA from Tuning;
   - the room's palette muted to §0.1, and the car recoloured to a muted non-red.
4. **The warm-up queue:** a tiny instance per material, drawn for 2 frames at load, windowed only.
5. **Perf:** run `perf_compare` against `main` on a quiet machine, with edges off, depth-only and depth+normals, at MSAA 4x and 2x. Report the table.

**Tests** (new `test_look_post.gd`):
- one LookPost when the room has presentation, none without;
- the edge pass's priority is between -128 and 0, and it reads no screen texture;
- the LUT is a 16³ Texture3D;
- the LUT keeps `#d0141f`, `#e8302a` and the enemy palette within ΔE76 6, read from the strip's pixels;
- glow is off;
- the toggles act live.

**Captures:** C9, C1's background, and C7.

**Done:**
- environment lines are 1-1.5 px;
- no line is doubled on characters (if one is, report an A/B with the edges masked off them);
- the perf table is in the final message;
- the default edge variant is the cheapest one that passes C9.

### R-vfx (Sonnet; est 7%)
**Owns** the R-vfx cells of §3.

**Brief:** a final style pass on the set. Keep the 512 px rule (SPEC §10; `test_vfx.gd:1061`).
1. Ink weight per §0.1.
2. Ben-Day dots on the bursts and the finisher extrusion, drawn as explicit circles (ThorVG patterns are unproven).
3. Two seeded variants per burst tier, never the same one twice in a row.
4. Words sized by cap height, so CRUNCH matches POW. A size-mode tunable defaults to the new way and keeps the old one reachable.
5. Lying splats unshaded, at `look_shadow_value`, so they no longer show the sun's smooth gradient.
6. Colours from `palette.json`'s VFX cells; the impact frame's ink and paper match INK and PAPER.
7. Byte-reproducible output: run twice and `cmp`.
8. An ASSETS row for every new file.

**Tests:** test_vfx passes: 8-10 words, a PNG for each, 512 px, an SVG source and an ASSETS row for every file, warm-up for every variant, and no burst repeated twice in a row.

**Captures:** vfx_bot's tier acts, and C5 at 1 m.

**Done:** in the C5 crops, the effects read as the same ink as the 3D lines.

### Phase 1 merge and look gate 1 (the lead, `workflow-review.js`)
1. **Merge** R-toon, then R-line, R-post and R-vfx. After each merge, regenerate the preset and run the full suite.
2. **Review**, with two Opus lenses:
   - **G1-look** scores J4-J7, J12 and J13, plus M7 and M8, on the placeholders and the street. Inputs: the before and after packs of C1, C2 and C5-C9, the bible, and the style frames if they exist.
   - **G1-tech** checks layers, warm-ups (the first-hit and first-spawn hitch), that presentation writes no state, that no script holds numbers, that no test was weakened, and that the globals are declared.
3. **Verify and fix:** a Sonnet skeptic checks each finding, then Sonnet fixers fix what survives.
4. **Lock:** the lead locks the Look defaults, writes a "Gate 1" section with stills into the bible, and updates HANDOFF.

**Pass:**
- no J-item scores 0;
- outlines measure 2-4.5 px;
- p95 ≤ `main` + 3 ms and ≤ 16.7 ms on a quiet M1 (soft, as in M3);
- the spawn hitch is ≤ 33 ms.

---

## 6. Phase 2: the pipeline (needs the pick; up to 2 Blender-bound and 2 Godot-bound builders)

### The lead's A0, on the pick (about $3, about 2% of a window)
1. **Views.** Per character, `views/views_jobs.json` holds one `gemini-3-pro-image` 2K 3:4 job per view: front, then back, left and right.
   - References: the pick, the views already accepted, and the proportion template.
   - The prompt is the template from the tripo-gemini codemap's §3.4, with four additions:
     - **"hands closed into loose fists, thumbs outside"**, because the rig has no finger bones, so a hand is rigid in every pose;
     - "match the silhouette reference's joint heights and limb lengths, ignore its style";
     - "no logos or brand marks", for concept D's swoosh-like sneaker mark;
     - the colours from `palette.json`.
   - **Check:** the canvas sizes must match and the subject's height must agree within 3%; regenerate any view that fails.
   - **The hero** gets the same views plus `fist_right.png`: an isolated wrapped fist in a fingerless glove, in 3/4 view, from the sheet's callout.
2. **Style frames.** `style_frames/jobs.json` paints over the before stills of C1, C4, C8 and C7. References: the still, the pick, and a palette strip.
   - The prompt keeps the camera, the composition, the HUD and where everything stands.
   - It renders the character as the concept: bold INK lines about 4 px wide, 3 tinted bands, one hard highlight, a muted street with thin edge lines, and no new text.
   - Two variants per shot; the lead keeps one. They are references for the J-items, not pixel targets.
3. **FYI DM** in the concept thread: the sheet of views and the style frames, with "no reply needed; say if anything is off". This is **not a pause**.

### The lead's A1: Tripo, through the ledger (§9)
1. **Generate the Punk.** Upload the views, then run G1 (front, back, left) and G2 (all four views, another seed).
2. **Inspect both** with `run_character.py --steps render`: front, side and back stills, triangle count, holes, fists. Compare them with the concept, and use an asymmetric detail to tell which side Tripo means by "left".
3. **Pick a reconstruction** (the lead's call). Run G3, detailed geometry, only if both have a mush face or fists.
4. **Rig it.** Rig-check, then R1, a v3.0 rig with spec `unity`, on the accepted raw mesh. Dump the bones to `reports/tripo_rig.json`: names, heads, tails and weights.
5. **The hero** goes the same way: H1, H2, H3 (the rig) and H4 (the fist, image-to-model). Log every `credits_consumed`.

### A-punk (Sonnet, Blender-bound; est 10%)
**Owns** `assets/source/characters/punk/**`, `assets/export/characters/punk/{punk.glb, punk_albedo.png}` with their `.import` files, and `tools/pipeline/*` shared modules for this phase.

**Brief:**
1. **Run the pipeline:**
   - 1.8 m tall;
   - joints from the Tripo rig report, renamed, with the fingers merged;
   - fit to the table at the measured A-pose angle;
   - a budget of 15,000 triangles;
   - palette cells teal, yellow, charcoal, off-white, skin and pale teal-grey;
   - ARMATURE_AUTO weights.
2. **Render the extremes** and fix the weights. The poses: the guard, the jab and cross peaks, the shove, the walk's mid-stride, the flinch, the stagger's lean, and lying.
   - Smooth the blend zones at the shoulders, elbows, knees and hips. Add an edge loop wherever a joint collapses.
   - Keep the fists 100% on `Hand`, with the wrist blending into `LowerArm`.
3. **If the shoulders fail the extremes,** the lead may approve R2 (25 credits) for a weight-transfer A/B. Keep the better result and log the call.
4. **Export, verify, and add the ASSETS rows:** the concept, the views, every generation with its task id and credits, R1, the `.blend`, the GLB, the albedo and the palette.

**Checks** (limits in `reports/`):
- a joint residual of 0;
- ≤ 15,000 triangles;
- ≤ 6 colours, none of them red;
- no unweighted vertex;
- ≤ 4 influences;
- no Root weight;
- the sole's lowest vertex within z ∈ [-0.005, 0.01];
- the heel, the ball and the toe tip at +0.085, -0.13 and -0.25 (±0.02);
- the fists within ±15% of the 0.10 x 0.118 x 0.116 m envelope (`FistPoint` doesn't move).

**Done:** `test_skinned_art` passes on `punk.glb`, and the extreme stills show no collapse and no candy-wrapper twist at the crop scale of 1 m.

### A-hero (Sonnet, Blender-bound; est 10%)
**Owns** `assets/source/characters/hero/**`, `assets/export/characters/hero/*`, `split_fp.py`, `fist_merge.py` and `hero_*.py`. The shared modules are read-only to A-hero: if blocked, copy one and extend it into `hero_*.py`.

**Brief:** the A-punk pipeline, with these differences:
- **Budget and palette:** 30,000 triangles (`Body` ≤ 22,000 and `BodyHidden` ≤ 8,000), with the hero's palette.
- **`fist_merge.py`:** puts the H4 fist on the right hand and a mirrored copy on the left.
  - Each fist is fitted to the fist envelope and aligned to the Hand bone frame: knuckles along -Z, with `FistPoint` at (0, -0.065, -0.005) from the wrist.
  - Each is welded to the forearm at the wrist.
- **`split_fp.py`:** moves to `BodyHidden` every face whose main bone group is Chest, UpperChest, Neck, Head or a Shoulder, plus the UpperArm above a plane 45% down the bone, with 1 cm of overlap.
  - It caps `Body`'s cuts with smooth domes: one at the mid-upper-arm cut, seen end-on in first person, and one on the belly top, rounded like `BellyTop` (`placeholder_body.gd:207`).
  - `Body` is left with no open boundary.
- **Detail where the lens looks:** the wraps and glove seams as geometry where the budget allows, otherwise as ink lines in the albedo, and the shoes' panels.

**Done:**
- the reports are within the limits;
- Workbench renders taken from the lens point (y 1.456, 4 cm ahead, looking 45° down) show the caps, the wraps and the shoes;
- `test_skinned_art` passes on `hero.glb`.

### A-skin (Sonnet, Godot-bound; est 10%; once phase 1 has merged; uses the fixture until the real GLBs land)
**Owns** the A-skin cells of §3, `skinned_art.gd`, `character_art.gd`, `tests/test_skinned_art.gd` and the fixture's `.tres`.

**Brief:**
1. **Contracts.** Implement §2.5 and §2.6, the write-back, the skinned warm-up and `apply_art`.
2. **Test skips.** Make the five listed tests skip skinned meshes, and change nothing else in them.
3. **`test_skinned_art`**, run on every `*_art.tres` under `res://assets/export/characters/` and on the fixture:
   - **(a)** binds: rest vertices go within 1 cm of the GLB pose mapping;
   - **(b)** a 2.3 m rig scales correctly;
   - **(c)** CUSTOM0 holds the bind positions, and the marks don't change with the pose;
   - **(d)** proxies are hidden, keep their names and layers, and are still counted by `FPView.hits` and `outside_view`;
   - **(e)** `_head_clear_of` ignores skinned meshes;
   - **(f)** in a partial ragdoll, the skeleton pose a probe modifier reads after Ragdoll matches `_visual` within 1 mm;
   - **(g)** M3-M6 of §10, over the sample poses;
   - **(h)** with `art_skinned_enabled` false, the rig is exactly M3's.
4. **A test Punk with the fixture's art** runs the Punk tests and the readability probe's R4 and R8 unchanged.

**Done:**
- the full suite passes;
- a windowed C2 and C5 recorded with the fixture shows the flash on the skin, a stagger that matches the proxies, and the blink-off.

### M-motion (Sonnet, Godot-bound; est 7%)
**Owns** the M-motion cells of §3, `tests/test_motion_polish.gd` and C12.

**Brief:**
1. **Idle life.** The boxer and relaxed idles breathe through the chest and upper chest (`look_idle_breath_deg` over `look_idle_breath_s`) and sway at the hips.
2. **Eased in-betweens.** `_subdivide` (`placeholder_anims.gd:463-495`) places the in-between keys in time along an ease curve set by `look_ease_strength`. This applies only to an `EASED` set: the idles, taunt, brace, the get-ups and `downed`. Never moves, walks, or reactions that depend on hit timing.
3. **Foot slide.** Measure how far a planted sole drifts per step, in each walk at the Punk's speeds. Report it. If a drift is over 2 cm, request a `play_locomotion` fix from A-int.
4. **The C12 act.**

**Tests:**
- every clip in `MOVE_IDS`, and every enemy-move clip, is key-for-key identical to before (a hash);
- the idle hurtboxes stay within 1 cm of before;
- the shape of the named-library cache key is unchanged;
- the enemy-move checks and the telegraph tests are unchanged.

**Done:** the C1 idle breathes at 1 m, with no pop at the loop seam.

**At the end of phase 2,** merge A-skin, M-motion, then the assets, and update HANDOFF.

---

## 7. Phase 3: the 1 m proof

### A-int (Sonnet, Godot-bound; est 9%)
**Owns** the P3 cells of §3, plus `punk_art.tres` and `hero_art.tres`.

**Brief:**
1. **Wire the real art:** `_configure_art` for the Punk and the player.
2. **Run the full suite.** `test_skinned_art` now covers both real assets, and `test_m3_done_when` and `test_slice_crowd` run unchanged.
3. **Fix** whatever integration breaks.
4. **Add the F4 "Look stand"** to `cheat_menu.gd`.
   - It spawns a frozen Punk 1 m ahead, facing you, cycling through a 3 s idle, the C3 strafe, the jab-cross, the shove and a flinch.
   - A second entry steps through the damage looks.
   - It is a debug spawn like F4's others: the AI is frozen, and it adds no game state.
5. **Record the evidence pack** (§10.3) at 6 and 12 fps, with crops. Run `perf_compare` against `main`.

**Done:** the pack is complete, and every M-number is in the final message.

### F-feel (Sonnet, Godot-bound; est 6%): the deferred questions
**Owns** the F-feel cells of §3 and `tests/bot/acts/feel_acts.gd`. Every option is a tunable whose default is today's behaviour, with first-person A/B stills of the real art.
1. **The flash's size in first person** (grab-05, hit-01): `hit_flash_max_view_share`.
   - The shader caps the blob's view share from the fragment's view depth and `PROJECTION_MATRIX`. That is presentation only; the simulation never reads the camera.
   - A/B at 1.0 against 0.10, on three hits: the jab at 1 m, the knee in the hold (16% of the view today), the hook.
2. **The haymaker's flash** (r3look-05): re-measure it with the art in.
   - New option `vfx_finisher_flash_on_visible`: when the contact is hidden from the lens, flash the nearest part the lens sees (the chest).
3. **The non-KO knockdown view** (the "belly slab", up to 74% of the view): re-measure it with the hero's art.
   - The option `cam_knockdown_lift_m` (default 0) lifts the lens a little while the player lies there. It's built only if the art made the slab worse.
4. **grab-03, the combat log over the knee:** a `toggle_combat_log` action on F7 (listed in the help overlay), and `combat_log_position`.
   - The positions: bottom-left (today's), or top-right just below the warning's reserved 20% corner.

**Tests:**
- with every option off, the game behaves as today and the existing tests pass untouched;
- with an option on, it does what it says.

### The final review (the lead, `workflow-review.js`)
Four Opus lenses, then Sonnet skeptics and fixers.
- **L1, the Punk standing at 1 m:** J1-J7, J11 and J13, from C1, C2 and C7 at full resolution, with the style frames.
- **L2, the Punk in motion at 1 m:** J8-J10, J12 and J15, from C3, C4, C5, C11, C12 and C13 at 12 fps, with crops.
- **L3, the player's own limbs:** J14 and M1's lens rules, from C8 and C11.
- **L4, pipeline and tech:** M1-M10, the ASSETS rows and LFS, the ledger, layers, that no test was weakened, and perf.

**Then:**
1. Fixes, and fresh captures of everything they touch.
2. Docs:
   - README: "Where M4 departs from the spec", and the M4 status;
   - ARCHITECTURE: "Look (M4)" and "Character art (M4)";
   - ASSETS.md and HANDOFF.
3. The PR (never merged).
4. Pause 2.

---

## 8. The two pauses

### Pause 1: the concept pick (in progress)
**Sent** at 21:42 CDT in Game-boy's DM (`U0AQMKKBL93`). The images:
- **Street Punks:**
  - A: denim vest, cap, wraparound shades;
  - B: mohawk, bandana, track suit;
  - C: two-tone bomber, beanie, mask, boots;
  - D: hoodie under a denim vest, headband.
- **Hero sheets:**
  - A: wraps and tee;
  - B: jacket and boots;
  - C: martial.

**How they were made:** `gemini-3-pro-image` at 2K and 3:4, front A-pose, from `assets/source/concepts/concept_jobs.json` via `tools/gemini_image.py`. Every prompt shares one preamble: cel shading, bold ink, tinted shadows, chunky proportions, and five colours (teal and yellow plus charcoal, off-white and skin), with **no red**.

**Asked:** "one Punk and one hero, mix and match allowed".

**Meanwhile:** all of phases 0 and 1, and A-skin and M-motion if phase 1 ends first. None of them needs the pick.

**On his answer:**
- A0 and A1 start at once.
- If he asks for changes, round 2 is up to three edits of the nearest concept, using his own words, in the same thread (about $0.40, still the same pause).
- If he hasn't answered by look gate 1, send one reminder DM (the "Slack when blocked" memory).

### Pause 2: the final judgement
**DMed:**
1. The run command as a Run-button block (`godot --path /Users/arachne/repos/beat-em-up-PoC`), and "F4 → Look stand".
2. A 45-60 s MP4 (H.264, 1600x900), made with ffmpeg from the C1-C5 Movie Maker AVIs.
3. Six stills: the C1 face, the C2 body, the C4 jab at its peak, C5 bloodied, the C7 lineup, the C8 limbs.
4. A one-line summary of each rubric item: every J score and M number.
5. The list of M4 departures, for his ruling.
6. The four feel questions, with A/B stills and the defaults.
7. Whether the Tripo account is paid (all rights in the outputs) or free (Tripo keeps the rights).

**Asked:** "Does the Punk look production-quality at 1 m, standing and in motion? If not, which numbered items fail?" A "no" gets a fix round on the items he names and another DM; it doesn't add a pause.

---

## 9. Tripo credit budget (cap 800; the ledger never lets the balance drop below 700)

| # | Task | Call | Credits | When |
| --- | --- | --- | --- | --- |
| P1 | Punk G1 | multiview-to-model H3.1 `v3.1-20260211`: front/back/left, texture std, `v3.5-20260815` delight, `align_image`, face_limit 16000, seed 41 | 30 (the v3.5 price isn't published: read the actual) | planned |
| P2 | Punk G2 | the same plus right, seed 42 (settles what "left" means) | 30 | planned |
| P3 | rig-check | the accepted mesh | 0 | planned |
| P4 | Punk R1 | rig `v3.0-20260909`, spec unity (joints for the fit, bone dump) | 25 | planned |
| P5 | Punk G3 | detailed geometry on the better input | 50 | if the face or fists are mush |
| P6 | Punk re-texture | `models/texture`, a new texture_seed | 10 | if baked light survives |
| P7 | Punk R2 | rig the fitted GLB (file_token) for the weight A/B | 25 | if the shoulders fail |
| P8 | Punk fist | image-to-model from a glove crop | 30 | if J3 fails |
| H1-H2 | Hero G1, G2 | as P1, P2 | 60 | planned |
| H3 | Hero R1 | as P4 | 25 | planned |
| H4 | Hero fist | image-to-model of `fist_right.png` | 30 | planned |
| H5 | Fist retry | | 30 | if H4 fails |
| H6 | Hero shoe | image-to-model of the shoe callout | 30 | if J14's shoes fail |
| H7 | Hero R2 | as P7 | 25 | if needed |
| E1 | Retarget probe | `preset:walk` on Punk R1, `export_with_geometry` false | 10 | optional, data for M6 |
| R | Retries | 2 Punk and 2 hero generations | 120 | on failure |

**Totals:**
- planned (P1-P4, H1-H4): **200**;
- with every conditional (P5-P8, H5-H7, E1): **410**;
- with the retries: **530**.

The 270 credits left under 800 are never spent without asking Game-boy.

---

## 10. The done-when, made checkable

**Pass** needs all three:
- every M-item passes;
- the final review scores no J-item 0, every critical item (J1, J2, J3, J4, J5, J8, J14) at least 1, and a mean of at least 1.5;
- Game-boy says yes at pause 2.

### 10.1 Measured
| # | What | Pass | Where |
| --- | --- | --- | --- |
| M1 | Triangles | Punk ≤ 15,000; hero ≤ 30,000 (Body ≤ 22k) | reports, test_skinned_art |
| M2 | Palette | ≤ 6 `palette.json` cells per character; no red cell | reports |
| M3 | Fit to proxies | at rest and in 8 sample poses, per region (main bone group): centroid ≤ 3 cm off; extents 0.75-1.25x (forearm and hand 0.8-1.2x) | test_skinned_art |
| M4 | Fit to hurtboxes | ≥ 90% of a region's vertices inside its hurtbox + 6 cm; the hurtbox centre inside the region's bounds | test_skinned_art |
| M5 | Feet | at rest, the sole's lowest point is at y ∈ [-0.005, 0.01] m; in planted sample poses, within ±1.5 cm of the floor | test_skinned_art |
| M6 | Skin health | 23 binds, no `neutral_bone`, no unweighted vertex, ≤ 4 influences, no Root weight; posed/rest edge length within [0.4, 1.8] for 99.5% of edges in the C12 poses | test_skinned_art |
| M7 | Outline | `width_px` between 2.0 and 4.5 at 1, 2.5, 5 and 10 m; C6 stills within ±0.75 px of it | test_outline, stills |
| M8 | Perf | quiet M1, `main` against M4 back to back: p95 ≤ 16.7 ms (soft) and ≤ `main` + 3 ms; spawn hitch ≤ 33 ms; first-hit and first-spawn hitch ≤ `main` + 2 ms | `perf_compare.sh` |
| M9 | Marks don't swim | CUSTOM0 holds the bind positions; the mark coordinates of 100 sample vertices are the same in every pose | test_skinned_art |
| M10 | Clean | full suite passes; no `SCRIPT ERROR`, `SHADER ERROR` or `ERROR` in the suite or in any evidence log | run_tests.sh, bot.log |

### 10.2 Judged
Scores: 0 fails, 1 acceptable, 2 production. Each is scored per shot from full-resolution crops; `*` marks a critical item.

| # | Item | Shots |
| --- | --- | --- |
| J1* | The silhouette and proportions read at a glance: chunky, with oversized hands and feet, and true to the pick | C1 C2 C7 |
| J2* | The face holds up at 1 m: shades, cap and mask crisp and symmetric, no AI mush | C1 |
| J3* | Gloved fists read as fists in the guard and in strikes: no blob, the strap and bare knuckles visible | C1 C4 |
| J4* | Ink: continuous silhouette and interior lines, steady weight; no cracks, swimming or flicker; hull and edge lines don't clash | C1 C3 C6 |
| J5* | Shading: 2-3 crisp bands, tinted shadows, one hard highlight, a readable rim, no baked-light mud | C1 C2 C3 |
| J6 | Palette: 4-6 flat colours; a saturated enemy against a muted street; red only for blood | C1 C7 C9 |
| J7 | Surface: no holes, floaters, z-fighting, UV stretch or seams | C1 C2 C10 |
| J8* | Deformation: shoulders, elbows, knees and hips keep their volume through the guard, strikes, walk, stagger and knockdown, with no candy-wrapper twist and no visible self-intersection | C3 C4 C5 C12 |
| J9 | Contact: the fist reaches the hit, the flash lands on the struck part, and feet slide no more than today | C4 C5 |
| J10 | Life: the idle breathes, nothing pops, nothing floats | C1 C3 |
| J11 | Damage looks: clean, bruised and bloodied read at 1 m, and the marks stay on the body as it moves | C5 |
| J12 | Hit reactions: the flash's size and shape; bursts and lettering in the same ink as the 3D lines | C5 C13 |
| J13 | One game: the Punk with the placeholder enemies and the street reads as one style | C7 C9 |
| J14* | Own limbs: the wraps, gloves, forearms and shoes are the most detailed things on screen; no holes; the elbow cap reads; nothing clips the lens | C8 C11 |
| J15 | M3 readability holds: wind-ups read at 1 m and 2.5 m, and the probe's R1-R15 stay the same within noise | C4, readability.json |

### 10.3 Evidence pack
Everything goes in `captures/m4_evidence/`, which is never committed.
- C1-C13 recorded with `capture_bot.sh` and processed with `look_sheets.sh`.
- The before pack beside the after pack for C1, C2, C5, C7 and C9.
- The style frames beside C1, C4, C7 and C8.
- The `perf_compare` output, and `readability.json` from "Crowd: autopilot" with the art in.
- The pipeline reports, a ledger excerpt, and the M1-M10 numbers.
- The F-feel A/B stills, and the MP4 sent to Game-boy.

---

## 11. Coverage map

| Requirement | Built | Tested | Seen |
| --- | --- | --- | --- |
| Toon shader: 2-3 band ramp, hard spec, rim, tinted shadows, one shader with per-material parameters (§10) | R-toon | test_toon_material | C1 C2 C9, J5 |
| Inverted-hull outlines on characters and props, width scaled by distance | R-line | test_outline | C6 C1 C8, J4, M7 |
| Screen-space environment lines from depth and normals | R-post | test_look_post | C9 C7, J4 |
| Optional halftone in shadows | R-toon | test_toon_material | gate-1 A/B |
| Colour-grading LUT; no bloom except VFX | R-post | test_look_post (ΔE, glow off) | C9, J6 |
| 1080p60 with 6 enemies | every package; toggles | perf_compare (M8) | L4 |
| Final player arms and legs (wraps, fingerless gloves, legs, shoes) | A-hero, A-skin, A-int | test_skinned_art; first-person tests through proxies | C8 C11, J14 |
| Head and neck on their own layer, still casting shadows | the A-hero split; `_apply_layers` | test_skinned_art, test_ko_view | C8, the KO view |
| Concept: 2-4 images, Game-boy picks | round 1, pause 1 | ASSETS rows | the DM |
| Image-to-3D in an A-pose | A1 (Tripo multiview) | ledger, reports | renders |
| Blender clean-up: metres, normals, decimate, head split, palette in place of generated textures | A-tools, A-punk, A-hero | `self_test.py`, M1, M2 | C10, J7 |
| Rig | Tripo R1 joints + our armature + ARMATURE_AUTO or Tripo weights | M6 | C12, J8 |
| Animation | the procedural set (D2) + M-motion | test_motion_polish | C3-C5, J8-J10 |
| `.glb` export; humanoid profile and shared animations | GLB + CharacterArt; the project skeleton is shared (D2) | test_skinned_art | — |
| ASSETS.md logging | every package | test_vfx rule, L4 | — |
| Budgets (15k, 30k, palette atlas + detail mask) | reports; 2k texture (D10) | M1, M2 | — |
| Faces covered, holding up at 1 m | views prompt, A-punk | — | C1, J2 |
| Red reserved | palette, room recolour, LUT ΔE | test_look_post, `test_bruises_are_not_red_paint` | J6 |
| Comic VFX set as SVG to 512 px | R-vfx | test_vfx | C5 C13, vfx_bot, J12 |
| §6 flash, damage looks, ragdoll and blink-off on the new art | R-toon, A-skin | test_hit_flash, test_damage_look, test_skinned_art (f), test_ko_blink | C5, J9 J11 |
| M3 readability and warnings unchanged | proxies | test_m3_done_when, test_slice_crowd | J15 |
| Done-when | everything | M1-M10 | J1-J15, pause 2 |

**Departures for Game-boy's ruling** (README "Where M4 departs"):
- **D1:** colour from a palette-only texture instead of per-face cells (only if the A/B picks it).
- **D2:** the project's skeleton and procedural animations instead of Mixamo, mocap or a humanoid-profile import.
- **D3:** rigid fists, no finger bones.
- **D4:** edge normals rebuilt from depth, if perf picks it.
- **D5:** halftone in the material, not as a post-process.
- **D10:** a 2048² texture instead of the 1k detail mask.

---

## 12. Key judgement calls (call; alternative not taken; why not)
1. **Look gate 1 before any mesh.** *Alternative:* build the Punk end to end first. *Why not:* shader churn would hide or fake mesh faults, and the look work fills the wait for the pick.
2. **Fit the mesh to the joint table.** *Alternative:* a joint table per character. *Why not:* `reach_m` (tested within 0.15 m), the hurtboxes, rig points, ragdoll anchors and the throat lens all come from the table, and M1-M3 were signed off on it.
3. **The procedural set animates the art.** *Alternative:* Tripo or Mixamo clips through a retargeter. *Why not:* v3 has no guard and no strikes; v1's boxing clips would bypass the tuned telegraphs and the 15% rule; nothing retargets onto the identity-rest rig yet. E1 gathers data on clips for M6.
4. **Author in A-pose and recompute the binds.** *Alternative:* re-rest the mesh arms-down with translation-only binds. *Why not:* that stacks two linear-blend deformations, and arms-down weighting fuses the hands to the thighs (rig-render codemap §9(b)2).
5. **Our 23-bone skeleton; Tripo's rig gives the joints and weight candidate R2.** *Alternative:* Tripo's skeleton through Godot's humanoid retarget import. *Why not:* that import can't produce identity-rest bones facing -Z, and Tripo's weights reportedly over-smooth shoulders. Tripo's rig is still tried first, as Game-boy asked.
6. **Proxies for the tests.** *Alternative:* CPU skinning in FPView, or rewriting about 80 tests around bones. *Why not:* far too slow in GDScript, and the rewrite would lose M1-M3's lens rules. Proxies plus the fit tests M3 and M4 keep every assertion meaningful.
7. **Toon on the placeholders too.** *Alternative:* leave them on StandardMaterial3D. *Why not:* SPEC's "one shader for everything", and J13. The cost is about 66 test lines.
8. **Hull on `material_overlay`.** *Alternative:* a `next_pass` chain, separate hull meshes, or the material stencil outline. *Why not:* a chain rewires the flash; separate meshes must mirror layers, visibility and skin; the stencil outline is StandardMaterial-only and untried.
9. **Width in pixels.** *Alternative:* world width scaled by distance. *Why not:* that ignores FOV and resolution.
10. **Edge quad in the world, no screen texture.** *Alternative:* a CompositorEffect. *Why not:* the quad is verified on Metal and serves all cameras. A screen copy would erase the transparent flash.
11. **Halftone in `light()`.** *Alternative:* a post pass. *Why not:* only the material knows where the shadow band is, at no extra pass.
12. **A 2048² palette-only texture, A/B against per-face cells.** *Alternative:* per-face cells only. *Why not:* at 15k triangles, colour borders zig-zag in 15-20 px teeth at 1 m. The final review picks one. Index maps shimmer at distance.
13. **Rigid fists.** *Alternative:* finger bones. *Why not:* that changes the rig and all 46 clips, for hands that are fists almost always.
14. **Full generated player body, split in two.** *Alternative:* a hybrid on a primitive torso. *Why not:* the KO view and the shadows show the whole body.
15. **Bind-pose triplanar marks.** *Alternative:* painted masks. *Why not:* this keeps M2's tiles and texture swaps; masks can come in M6.
16. **Look tunables as global uniforms.** *Alternative:* per-rig material updates. *Why not:* one write per change, and a test checks the declared list.
17. **Gemini style frames.** *Alternative:* the concepts as the target. *Why not:* concepts show neither the 1 m first-person framing nor the street.
18. **The training room delegates to RoomKit.** *Alternative:* copy each change into it. *Why not:* five of the six bots render there.
19. **512 px VFX kept.** *Alternative:* 1024 px. *Why not:* pinned by the SPEC and a test, and about 1:1 at 1080p.

---

## 13. Risks

| Risk | Sign | Response |
| --- | --- | --- |
| Tripo mush (face, fists, back) | renders, J2, J3 | P5; a separate fist or head generation merged in Blender; tighter views; P-series only with Game-boy's OK past 800 |
| The fit distorts the design | a region scaled more than ±20% | regenerate the views with the template weighted higher; change girth, never joints |
| Linear-blend skinning at the extremes (no twist bones) | C12, M6 | smooth the weights, add loops, try the R2 weights; worst case, put J8 to Game-boy with stills (the poses are signed off and stay) |
| M1 perf | M8 | depth-only edges; MSAA 2x with FXAA; primitive hulls off; the 3060 target stays unmeasured, and the report says so |
| First-use hitches | first-hit and first-spawn hitch | the LookPost warm-up queue, for every material and skinned variant |
| Proxies drift from the art | M3, M4 | fix the art, never the proxies |
| Toon makes the placeholders look worse than M3 | gate 1, J13 | tune toward M3's values; the before/after A/B decides |
| Hull artefacts on thin parts or near the lens | C1, C8 | own-body multiplier, min px, a per-mesh opt-out |
| Damage tiles read as wallpaper | J11 | a bigger tile size on the art; masks in M6 |
| Gemini views mirrored or inconsistent | numeric check, P2 | per-view generation with references; swap labels |
| The pick comes late | no answer by gate 1 | a reminder DM; A-skin and M-motion run first on the fixture |
| Usage overrun from asset loops | the watcher | at most 3 Blender rounds per character per session; hand off at 90% with `wip:` commits |
| Tripo licence unknown | — | an ASSETS row marked "pending", asked at pause 2 |
| Tripo v2 sunset | — | v3 only |

---

## 14. Sequencing and usage (premium seat; % of a 5-hour window)

| Phase | Work | Est. |
| --- | --- | --- |
| 0 | L0-scaffold 6, A-tools 7 (in parallel), L0-bench 6, lead 2 | 21 |
| 1 | R-toon 10, R-line 7, R-post 8, R-vfx 7; merges 2; gate 1: 2 Opus 6, skeptics 3, fixers 12 | 55 |
| 2 | lead A0/A1 3; A-skin 10, M-motion 7, A-punk 10, A-hero 10; merges 2; iteration reserve 10 | 52 |
| 3 | A-int 9, F-feel 6; final review: 4 Opus 12, skeptics 5, 3 fixers 15; docs, PR and DM 4 | 51 |
| **Total** | | **about 180, about 1.8 windows (one reset)** |

**At every phase boundary,** HANDOFF records the runner, its args file and each package's state from its branch: done, wip or new.

**At the watcher's 90% message:**
1. Stop the workflow.
2. Commit `wip:` everywhere and push.
3. Update HANDOFF.
4. Create the resume task.
