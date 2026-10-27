# Milestone 4 plan, vertical-slice angle: one Punk end to end first, then fidelity in passes

Planner "vertical-slice", 2026-10-26, branch `m4/art-pipeline` at `85f7f39`. Read-only: no tracked file changed, no credits, no Gemini call. Sources: the codemaps in `docs/milestones/M4-codemap/` (cited **[rig]**, **[fx]**, **[tripo]**, **[blender]** with their section numbers), SPEC §3, §5, §6, §10-§12, README's M1-M3 departures, ARCHITECTURE ("Layers", "Physics and visual layers", "Humanoid rig", "Hit flash", "Ragdoll"), HANDOFF's newest entries, and the code at the cited lines. Concept round 1 is out: `assets/source/concepts/` (Punks A-D, hero sheets A-C, gemini-3-pro-image 2K), DMed 2026-10-26 21:42 CDT.

**SPEC §12, M4:** toon shader and outlines, final player arms and legs, one Street Punk through the full pipeline, the comic VFX set. **Done when** the Punk looks production-quality at 1 m from the camera, standing still and in motion (Game-boy judges).

---

## 0. The approach in one page

M4's risk is the **chain**, not any one link: concept → views → Tripo → Blender → rig → Godot → the existing procedural animation, hurtboxes, ragdoll, hit flash, damage looks, FP layers and ~1,200 tests. Each link hides an unknown only a real asset answers: Tripo's bone names and facing, which side "left" is, what texture v3.5 costs, how a real mesh deforms at the guard's 130° elbow, whether palette borders hold at 1 m, what the edge pass costs with toon materials. Perfecting the shader while the pick is pending and finding at hour 12 that the GLB faces +X and pinches at the elbow puts all the schedule risk at the end. So:

1. **Phase 0 (now, during the pick).** `S0-contract` lands every seam: `CharacterArt`, `HumanoidRig.art`, all material code moved into a new `RigPaint` (zero behaviour change), `CombatActor.art` + `_configure_art()`, the "Look" Tuning group, a contract test. `P1-pipe` starts at once on the Blender/Tripo tooling; it needs only this plan's asset contract.
2. **Phase 1 (the low-fidelity slice plus the toolchain-free tracks).** `P1-pipe` takes a **smoke Punk** through the whole chain unattended: a Gemini flat re-render of a concept (the pick if it is in, else Punk A), Tripo image-to-model (30 credits), rig-check and Tripo's auto-rig (25; Game-boy: Tripo's rig before Mixamo), headless Blender fit, weights, fists, palette, export. In parallel, on fixtures: `P1-skin` (skinned art on the real rig, view proxies, ragdoll write-back), `P1-toon` (one toon shader for everything, the hull, flash and damage on it), `P1-post` (edge pass, LUT, both rooms through `RoomKit`, the look probe), then `P1-fx` (final comic VFX pass).
3. **Phase 1c (the slice).** `SL-int` puts the smoke Punk in the crowd room, **fighting**, under toon, hull, edges and grade, and records the 1 m acts. **The slice gate** (lead + one Opus reviewer) judges it from first-person captures and logs, locks the open choices (weights source, fit, outline px, edge mask) and turns every gap into a phase-2 brief line. From here the game always has a working art-pipeline Punk; the rest is fidelity.
4. **Phase 2 (fidelity passes, after the pick).** `F-punk` reruns the proven chain on the picked concept at full quality (4 orthographic views on the rig's own proportions, multiview-to-model, a dedicated glove-fist generation, crisp palette borders) and replaces the smoke GLB **in place**. `F-player` does the hero (full body, FP-hidden split with closed caps, wrapped fists, 1k detail mask). `F-motion` makes the procedural set look alive without moving one active-frame pose. `F-look` tunes the look on the real Punk and makes the placeholders sit beside it.
5. **Phase 3 (the done-when).** `P3-int` (final evidence acts, an F4 showcase, the four deferred feel questions as toggles, the perf A/B), a six-lens first-person review, fixes, docs, the PR (never merged), the **final-judgement DM**.

Why it is safe: the art is **fitted to the skeleton**, never the reverse, so hurtboxes, rig points, reaches, telegraphs and first-person framing are unchanged by construction; the primitives stay built as **hidden view proxies**, so every first-person test measures the same geometry, and new tests bound the art-vs-proxy gap. Tripo: **385 credits expected, 740 ceiling, hard stop 750**. Usage: about 120-160% of a 5-hour window (§15).

---

## 1. Rules every package follows (paste into every builder prompt)

- **Worktree:** only `/Users/arachne/repos/beat-em-up-PoC/.worktrees/m4-<key>` (branch `m4/<key>`), `cd` there for every command; run `godot --headless --import --quit` there first. Never touch the main checkout or another worktree.
- **Code (CLAUDE.md):** static types, tabs, `##` docs on public API, comment density like the code around it. **No numbers in scripts:** tunables go in `tuning_data.gd` as `@export_range` **in your own subgroup** (§2.9); shader parameters are `uniform`s with `hint_range` fed from Tuning; pipeline parameters live in `assets/source/characters/<id>/pipeline.json`, not in Blender scripts. Simulation never reads a camera; presentation only reads state and subscribes to `CombatEvents`.
- **Own only your files** (§3). Anything else is a request in your final message.
- **Tuning:** after adding tunables, `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd` (the lead regenerates after merges; `merge=keep-ours`).
- **Tests:** `tools/run_tests.sh -gselect=<file>` while working, the full suite (about 145 s) before the final commit; read the output for `SCRIPT ERROR`, `SHADER ERROR`, `ERROR`. **Never weaken an assertion to pass.** If one must change (a material type, a parent name), log old → new in your calls file and add a twin assertion on the visible path.
- **Look:** `tools/capture_bot.sh <bot.tscn> <worktree>/captures/<key> "<act filter>" <fps>` (2-slot lock, records 1600×900). Sheets: `ffmpeg -loglevel error -y -i <avi> -vf "fps=6,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png`; full-res stills `-vf "select='not(mod(n\,30))'" -fps_mode vfr`. **Read them.** First person is what counts; side view only checks mechanics. Never commit `captures/`.
- **Blender:** headless only, `blender --background --factory-startup --python <script> -- <args>`. **Never use the Blender MCP** (it drives Game-boy's open Blender). One Blender process per agent, two machine-wide.
- **Keys and services:** scripts read `TRIPO_API_KEY`/`GEMINI_API_KEY` from `.env`; **never print, log or write a key**, never put one in a URL. Tripo only via `tools/pipeline/tripo.py` (v3, `https://openapi.tripo3d.ai/v3`; v2 shuts 2026-10-31 [tripo §0]): every task appended to `assets/source/tripo_ledger.jsonl` with its real `credits_consumed`; the script refuses a task that would take M4's spend past **750**; outputs downloaded at once (URLs live 5 min), no auth header. Gemini only via `tools/gemini_image.py` job files.
- **Assets:** an `ASSETS.md` row per new file under `assets/` in your section (service, model id, task id, date, credits, job file, licence note). Binaries via LFS: `git check-attr filter <file>` must say `lfs` before you commit. Rejected raw outputs go to `assets/source/_cache/` (git-ignored).
- **Commits:** `wip: <key> ...` every 15-20 min, pushed; final `M4 <key>: <summary>`, pushed; every message ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Calls:** each judgement call (decision, alternative, why) in `docs/milestones/M4-calls/<key>.md`. Ask Game-boy nothing. A spec departure: build the reading that departs least, keep the spec value reachable as a tunable, report it.
- **Hardware:** 8 GB. One Godot process per agent, never left running; `-s` scripts always with `--quit-after` (an error before `quit()` hangs) and they cannot see autoloads [blender §2], so test through GUT or a scene.
- **Final message:** what you built, tests and result, sheets read and what they show, credits (task ids), requests, risks.

---

## 2. Pinned contracts

### 2.1 Character art (`game/actors/character_art.gd`, S0)
```gdscript
class_name CharacterArt
extends Resource
## One character's skinned art: a GLB exported by tools/pipeline to the project's rest skeleton.
@export var id: StringName                  # &"punk", &"player"
@export var scene: PackedScene              # res://assets/export/characters/<id>/<id>.glb
@export var palette: Texture2D              # res://assets/export/palette/palette_atlas.png
@export var detail_mask: Texture2D          # player only (SPEC §10 "1k detail mask")
@export var triangle_budget: int            # SPEC §10: 15000 enemy, 30000 player
```
Resources: `game/actors/art/<id>_art.tres`.

### 2.2 Actor and rig seams (S0; P1-skin implements)
```gdscript
# combat_actor.gd (S0 only)
@export var art: CharacterArt                # null = placeholder primitives; set in the scene
func _configure_art(r: HumanoidRig) -> void  # virtual; called by _ensure_body() after _configure_rig(), before build(); default r.art = art

# humanoid_rig.gd
@export var art: CharacterArt                # set before build(); null builds exactly today's 41/45 primitives
const VIEW_PROXY_GROUP := &"view_proxy"
const ART_GROUP := &"rig_art"
var paint: RigPaint
func has_art() -> bool
func art_meshes() -> Array[MeshInstance3D]
func set_art_shown(shown: bool) -> void      # live A/B with the primitives (Tuning look_show_art)
```
With `art` set, `_build_meshes()` (humanoid_rig.gd:739) still builds every primitive (names, followers, layers, materials), sets each `visible = false`, adds it to `VIEW_PROXY_GROUP`, then calls `SkinnedArt.attach()`. Followers, rig points, hurtboxes, `get_attachment()`, flash anchors and health bars are untouched [rig §1.6]. Art comes only through `_configure_art` from `_ensure_body()` (combat_actor.gd:1561); `PlayerCharacter._configure_rig` (player.gd:133), which tests call on scratch rigs [rig §6], never sets it. `EnemyCatalog.body_size()` probes never `_ready()`, so they load no art.

### 2.3 Materials (`game/actors/rig_paint.gd`; S0 moves today's code in, P1-toon owns it after)
```gdscript
class_name RigPaint
extends RefCounted
func _init(rig: HumanoidRig) -> void
func build() -> void                                   # was HumanoidRig._build_materials (:723)
func material(paint: int) -> Material                  # per PlaceholderBody.Paint (primitives)
func art_material() -> Material                        # palette atlas [+ detail mask]; one per rig
func outline_material() -> Material                    # inverted hull for material_overlay, or null
func apply_colors() -> void                            # was _apply_colors (:1114)
func color_of(paint: int) -> Color                     # what tests read instead of albedo_color
func set_flash(amount: float, color: Color) -> void    # was set_flash (:396), whole-body (parry)
func show_flash_overlay(on: bool, overlay: Material) -> void  # was _show_flash_overlay (:516); every base material, art's too
func set_damage_look(level: int) -> void               # was set_damage_look (:528)
func base_materials() -> Array[Material]
func warm_up(parent: Node3D) -> void                   # was _warm_flash (:501), plus the toon variants
```
After S0, `HumanoidRig._materials` is the same `Dictionary[int, StandardMaterial3D]` RigPaint fills, so `test_hit_flash`, `test_vfx`, `test_humanoid_rig` pass unedited. P1-toon retypes it to `ShaderMaterial` and updates those tests via `color_of()`/`base_materials()`. **`next_pass` stays the hit flash's**; **the outline goes on `material_overlay`** (verified on skinned meshes [blender §8.2]).

### 2.4 Skinned art (`game/actors/skinned_art.gd`; S0 stub, P1-skin implements)
```gdscript
class_name SkinnedArt
extends RefCounted
static func attach(rig: HumanoidRig, art: CharacterArt) -> Array[MeshInstance3D]
static func check(art: CharacterArt) -> PackedStringArray   # contract violations; empty = ok
```
- Once per art (static cache): instantiate `art.scene`, take each `MeshInstance3D`'s `ArrayMesh` and its Skin's bind names (editor import names them [blender §4]); rebuild each surface once adding `ARRAY_CUSTOM0`/`CUSTOM1` = rest position/normal (RGB_FLOAT) for the damage look. Never put the GLB's `Skeleton3D` under the rig [rig §1.2].
- One Skin per (art, `rig.rig_scale()` = s), binds **in the GLB's bind order**: `add_named_bind(name, Transform3D(Basis.IDENTITY * s, -s * rest_global_unscaled[name].origin))`, rests from `PlaceholderBody.pose_globals(<typed empty dict>, Vector3.ZERO, 1.0)` [rig §9a]. Translation-only because the GLB's rest **is** the table (2.6); its inverse binds are only checked, never used [blender §6.1].
- Each mesh: child of `rig.skeleton`, name `Art<Mesh>`, `skeleton = ^".."` (explicitly), `skin`, `material_override = paint.art_material()`, `material_overlay = paint.outline_material()`, `cast_shadow ON`, group `ART_GROUP`; a GLB mesh named `*__fp_hidden` joins the rig's head list so `_apply_layers()` (:1125) and the `first_person_body` setter treat it like the primitives.
- `check()` fails on a bind name outside `PlaceholderBody.BONE_NAMES`, a `neutral_bone`, a joint > 1 mm off the table, or more triangles than the budget.

### 2.5 View proxies, FPView, KO view (P1-skin)
- `tests/fp_view.gd` gets `static func is_drawn(mesh) -> bool`: false for `ART_GROUP`; `mesh.get_parent().is_visible_in_tree()` for `VIEW_PROXY_GROUP`; else `mesh.is_visible_in_tree()`. `hits()` (:41), `ray_hit()` (:86), `outside_view()` and `mesh_distance()` (:170, which null-casts on an `ArrayMesh` today) use it; non-primitives return INF.
- `FirstPersonCamera._head_clear_of` (first_person_camera.gd:384) skips `ART_GROUP` and keeps reading the (hidden) proxies, which follow FK; the player never ragdolls by default, so the KO view's un-cull timing is unchanged.
- `tests/skinned_view.gd` (new): `skin_vertices(mi, rig) -> PackedVector3Array` (CPU skinning) and a triangle rasterizer onto FPView's 48×27 grid, for the fidelity tests (§11).

### 2.6 Asset contract (P1-pipe)
```
assets/source/
  concepts/                 exists (concept_jobs.json + 7 images)
  mannequin/                mannequin_{front,left,back}.png: the joint table in a 45° A-pose (Workbench, 3:4, 2K)
  palette/<id>.json         per character: fixed slot range, [{slot, name, srgb, marks}]
  look/grade.json           LUT recipe (P1-post)
  characters/<id>/
    pipeline.json           every step and parameter of this asset
    views/                  views_jobs.json, view_{front,left,back,right}.png
    parts/<part>/views/     separately generated parts (fist, head)
    tripo/                  <task8>_gen.glb, <task8>_preview.webp, <task8>_rig.glb, tasks.json
    work/<id>.blend         final Blender work file
    report/                 report.json, bones.json, stills/*.png
    smoke/                  phase-1 smoke sources (punk only)
  tripo_ledger.jsonl        every Tripo task, append-only
  _cache/                   git-ignored rejects and intermediates
assets/export/
  characters/<id>/<id>.glb (+ .import)   mesh, weights, armature; no animations, no embedded textures
  characters/player/player_detail.png    1k detail mask (R = ink lines)
  palette/palette_atlas.png (+ .import)  shared, built from every palette/*.json
  look/grade_lut.png (+ .import)
tests/fixtures/art/probe_body.glb        the pipeline's own deterministic test body (no credits)
```
**Palette:** slots 0-15 shared (inks, neutrals, skins), 16-31 punk, 32-47 player, 48-63 reserved; atlas 256×16 RGBA8, 8 px swatches; rgb = sRGB colour, **alpha 1.0 = takes damage marks, 0.5 = not** (today's DARK). Nearest filter, no mipmaps. Built by `tools/pipeline/gen_palette.py` (lead reruns after merges; `merge=keep-ours`).
**GLB:** rig space at 1.8 m, +Y up, **faces −Z in Godot** (author facing +Y in Blender [blender §3.1]), feet at y = 0; **the rest pose is the table**: armature `Armature` with exactly the 23 `BONE_NAMES`, every joint within 1 mm of [rig §9d], arms hanging. Meshes: Punk `Body`; player `Body` + `Body__fp_hidden`. ≤ 4 normalized weights, every vertex weighted, none on `Root`. UV1 `palette` (each face on its swatch centre), UV2 `detail` (player), COLOR `hull_normal` (position-averaged smooth normal `n*0.5+0.5`, computed **before** any split so hulls never crack [blender §8.2]). Soles: lowest vertices at y = 0 ±5 mm over heel z +0.085 … toe z −0.25, x ±0.11 [rig §9b.6]. Fists: about the 0.1×0.118×0.116 m box at (0, −0.065, −0.005) on the hand bone, knuckles along the bone (−Y at rest), palm to the midline, thumb to −Z [rig §9b.9]. Export: `export_format="GLB"`, `export_yup`, skins, `export_influence_nb=4`, `export_animations=False`, `export_def_bones`, no leaf bones, `export_apply=False`, `export_vertex_color="ACTIVE"`, `export_image_format="NONE"`, no Draco/meshopt [blender §3.9]. `.import`: `meshes/generate_lods=false`, `create_shadow_meshes=true`, `skins/use_named_skins=true`, `animation/import=false`.

### 2.7 Toon (P1-toon; F-look tunes)
- `game/fx/toon_light.gdshaderinc`: the one `light()` (bands, tinted shadow, hard spec, rim, halftone), included by `game/fx/toon.gdshader` (characters, props, environment boxes) and `game/level/grid.gdshader`. `render_mode ambient_light_disabled`: the ramp owns the shadow side, never black.
- `toon.gdshader` uniforms: `albedo`, `albedo_tex`, `use_albedo_tex`, `detail_tex`, `use_detail_tex`, `ink`, `band_1`, `band_2`, `band_soft`, `mid_level`, `shadow_tint`, `spec_cut`, `spec_strength`, `rim_cut`, `rim_power`, `rim_strength`, `flash_color`, `flash_amount`, `damage_tex`, `damage_scale`, `marks`, `use_rest_custom`, `halftone_strength`, `halftone_cell_px`, `edge_tag`. Damage = a triplanar of `damage_tex` over `CUSTOM0/1` (rest space, art) or local `VERTEX` (rigid primitives), × `marks` × atlas alpha; swapping the texture never changes the shader. Parry flash = `flash_color`×`flash_amount` after lighting. `ROUGHNESS = edge_tag` (0 art, 1 elsewhere) for the edge mask.
- `game/fx/toon_outline.gdshader` (`unshaded, cull_front`): `VERTEX += n * w`, `n` from `COLOR` when `use_color_normal`; `w` = `width_px × VIEWPORT_SIZE.y/1080` px in metres at `clamp(dist, near_m, far_m)` via `PROJECTION_MATRIX[1][1]`, × `fp_scale` on the player's own body, faded to 0 within `lens_fade_m` (a lens inside a hull shell would see ink). Mirror `ToonMaterials.outline_width_m(dist, px, proj11, viewport_h, near, far, lens_fade) -> float`.
- `game/fx/toon_materials.gd` (`ToonMaterials`, static): `character(color)`, `art(atlas, detail)`, `outline()`, `environment(color) -> Material`, `warm_up(parent, skinned := null)`; a weak registry of live materials gets Look tunables on `Tuning.changed`. S0's stub `environment()` returns today's `RoomKit.flat_material` recipe so P1-post can call it first.

### 2.8 Post (P1-post; F-look tunes)
`game/fx/look_post.gd` (`LookPost extends Node3D`), built by `RoomKit.build_presentation()` (room_kit.gd:147) **for both rooms** (test_room.gd calls RoomKit from M4 on): the edge quad (`edge_pass.gdshader`, QuadMesh 2×2, `extra_cull_margin 16384`, `unshaded, depth_test_disabled, skip_vertex_transform`, `render_priority −127`, between the flash at −128 and sprites at 0..3 [fx §6.2]), the LUT (`Environment.adjustment_color_correction` = `ImageTexture3D` from `grade_lut.png`), the viewport AA mode. Depth lines skip pixels where any tap has roughness < 0.5 (the hull draws art silhouettes); normal-crease lines everywhere (collars, brims, soles). `tests/bot/look_probe.gd`: windowed pixel metrics into `<capture dir>/look.json` (§11).

### 2.9 Tuning group "Look" (S0: each subgroup with one seed; after "Audio", before "Debug", so presets save it, tuning.gd:38)
| Subgroup | Owner P1 → P2 | Names |
| --- | --- | --- |
| Art | P1-skin → F-look | `look_show_art` (true) |
| Toon | P1-toon → F-look | `look_band_1/2`, `look_band_soft`, `look_mid_level`, `look_shadow_tint` (Color), `look_spec_*`, `look_rim_*`, `look_halftone_env` (true), `look_halftone_chars` (false), `look_halftone_cell_px`, `look_halftone_strength` |
| Outline | P1-toon → F-look | `look_outline_px` (3.0 at 1080p), `look_outline_near_m`, `look_outline_far_m`, `look_outline_fp_scale`, `look_outline_lens_fade_m`, `look_hull_on_placeholders` (false) |
| Edges | P1-post → F-look | `look_edges_enabled` (true), `look_edge_px`, `look_edge_depth_threshold`, `look_edge_normal_threshold`, `look_edge_fade_start_m/end_m`, `look_aa_mode` (MSAA 4x / FXAA / off) |
| Grade | P1-post → F-look | `look_grade_enabled` (true), `look_grade_strength` |
| FP feel | P3-int | the four deferred-question toggles (§8), each defaulting to today |

### 2.10 Acts
Act files load by name (crowd_bot.gd:370); one per owner: `skin_acts.gd` (P1-skin), `toon_acts.gd` (P1-toon), `look_post_acts.gd` (P1-post), `look_acts.gd` (SL-int, then P3-int), `look_player_acts.gd` (F-player), `look_motion_acts.gd` (F-motion), `look_tune_acts.gd` (F-look). Titles start "Look:". 1 m recipe [fx §9.3]: `bot.god(); bot.freeze_ai(true); bot.spawn(&"punk", Vector2(0, 1.0))`; face shot `await bot._look_to(+8.0, 10)` (combo_bot.gd:570); motion is **scripted** (`rig.play`, `play_locomotion`, `play_move`, `force_attack`): AI-driven motion at 1 m sits in RECOVER.

---

## 3. Hot spots: who owns which file when

| File(s) | P0 | P1 | P1c | P2 | P3 |
| --- | --- | --- | --- | --- | --- |
| `combat_actor.gd` | S0 | — | — | — | — |
| `humanoid_rig.gd`, `skinned_art.gd`, `character_art.gd`, `ragdoll.gd` | S0 | P1-skin | SL-int | — (→ lead) | P3-int |
| `rig_paint.gd`, `game/fx/toon*`, `toon_materials.gd`, `damage_look.gd`, `hit_flash.gdshader`, `grid.gdshader`, `weapon.gd` (pipe, :42) | S0 (rig_paint, stub) | P1-toon | SL-int | F-look | P3-int |
| `look_post.gd`, `edge_pass.gdshader`, `room_kit.gd`, `test_room.gd`, `tools/gen_lut.gd`, `tests/bot/look_probe.gd` | — | P1-post | SL-int (L4) | F-look | P3-int |
| `vfx_director.gd`, `vfx_art.gd`, `comic_sprite.gd`, `tools/gen_fx.gd`, `assets/*/fx/` | — | P1-fx | — | — | P3-int |
| `first_person_camera.gd` | — | P1-skin | — | F-player | P3-int |
| `placeholder_poses.gd`, `placeholder_anims.gd`, `game/actors/poses/*.gd` | — | — | — | F-motion | — |
| `street_punk.tscn`, `game/actors/art/punk_art.tres` | — | — | SL-int | (GLB replaced in place) | — |
| `player.tscn`, `player.gd`, `player_art.tres` | — | — | — | F-player | — |
| `tuning_data.gd` | S0 (group) | own subgroup | own | own | own |
| `tools/pipeline/**`, `palette/shared.json`, `tests/fixtures/art/**` | P1-pipe | P1-pipe | — | F-punk (F-player: only `player_*.py`) | — |
| `assets/*/characters/punk/**`, `palette/punk.json` | P1-pipe | P1-pipe | — | F-punk | — |
| `assets/*/characters/player/**`, `palette/player.json` | — | — | — | F-player | — |
| `tests/fp_view.gd`, `tests/skinned_view.gd` | — | P1-skin | — | — | P3-int |
| `test_humanoid_rig.gd`, `test_hit_flash.gd`, `test_vfx.gd` | — | P1-toon | SL-int (Punk fallout) | F-player (player fallout) | fixers |
| `test_grab_view`, `test_ko_view`, `test_player_grabbed`, `test_launch_from_hold`, `test_health_bars` | — | — | — | F-player | fixers |
| `readability_probe.gd`, `engage_meter.gd` | — | — | SL-int | — | — |
| `cheat_menu.gd`, `combat_log_overlay.gd`, `help_overlay.gd` | — | — | — | — | P3-int |
| `ASSETS.md` | lead pre-cuts | "Characters" P1-pipe, "Look" P1-post, "Effects (VFX)" P1-fx | — | "› Punk" F-punk, "› Player" F-player | lead |
| `ARCHITECTURE.md` | lead pre-cuts "Art pipeline and look (Milestone 4)", a heading per package | own heading | own | own | lead |
| `.gitignore` (`assets/source/_cache/`), `.gitattributes` (`palette_atlas.png merge=keep-ours`) | lead | — | — | — | — |

Moving the material methods into `RigPaint` in S0 is what lets P1-skin and P1-toon run in parallel; both needed `humanoid_rig.gd` otherwise [rig §11.7].

---

## 4. Phase 0: contracts, and the pipeline starts (now)

**Lead first (< 1%):** pre-cut ASSETS.md and ARCHITECTURE headings, `docs/milestones/M4-calls/`, the `.gitignore`/`.gitattributes` lines; copy `docs/reviews/M3/workflow-build.js` to `docs/reviews/M4/` (prefix `M4 <key>:`, branches `m4/<key>`, worktrees `.worktrees/m4-<key>`, plan `M4-plan.md`); push; create the two worktrees.

### S0-contract (Sonnet, Godot; est. 6-8%)
Owns: `combat_actor.gd`, `humanoid_rig.gd`, new `rig_paint.gd`, `character_art.gd`, `skinned_art.gd` (stub), `game/fx/toon_materials.gd` (stub), `tuning_data.gd` (the group), `tests/test_m4_contracts.gd`.
1. Move `_build_materials`, `_apply_colors`, `set_flash`, `_show_flash_overlay`, `set_damage_look`, `_warm_flash` (humanoid_rig.gd:396-531, 723-735, 1114-1122) into `RigPaint` per 2.3; `HumanoidRig` delegates; `_materials` stays the same object. No behaviour change.
2. 2.1, 2.2 and the `SkinnedArt` stub (`attach` → `[]`, `check` → `["not implemented"]`); the proxy branch in `_build_meshes()`; `has_art`, `art_meshes`, `set_art_shown`.
3. `CombatActor.art` and `_configure_art()` called after `_configure_rig(rig)` (combat_actor.gd:1582).
4. "Look" with 2.9's subgroups, one documented seed each; regenerate the preset.
5. `ToonMaterials` stub (`environment()` = today's flat recipe; other factories null).
6. `test_m4_contracts.gd`: the signatures; `art == null` builds 41/45 meshes as before; `_configure_art` runs once per body; the subgroups exist.
**Done:** full suite green with **no existing test edited**; a combo_bot sheet identical before and after.

**P1-pipe** starts at the same time (brief in §5; it owns only pipeline rows).
Phase 0 ends when S0 merges (green, preset regenerated, HANDOFF updated).

---

## 5. Phase 1: the smoke Punk and the toolchain-free tracks (≤ 4 Godot-bound builders; P1-pipe counts as one)

### P1-pipe: the pipeline and the smoke Punk (Sonnet, Blender + Tripo; est. 10-12%; T1-T3, 55 credits)
Commit after each step:
1. **One joint table:** `tools/pipeline/dump_joints.gd` (run from a GUT helper or a scene, autoloads) writes `tools/pipeline/joints.json` from `PlaceholderBody` (bones, parents, rest globals, sole points, fist box, hurtboxes).
2. **Mannequin:** `blender_mannequin.py` renders the table as a chunky grey mannequin in a **45° A-pose** (upper arms 45° below horizontal, forearms straight, legs parallel), orthographic front/left/back, 3:4, 2K, flat #d9d9d9.
3. **Probe body (no credits):** `make_probe_body.py` builds a 5-region capsule body on the table in the A-pose and runs it through the chain → `tests/fixtures/art/probe_body.glb`, deterministic (same report hash on rerun). Push it early.
4. **The chain**, `run.py --asset <id>` driven by `pipeline.json`, idempotent, each step writing `report/report.json` and Workbench stills:
   - `blender_inspect.py`: import (`disable_bone_shape=True`), join, apply transforms; tris, bbox, facing (toe-direction heuristic, override `facing_yaw_deg`), Tripo bones → `bones.json`.
   - `blender_fit.py`: soles to z = 0, centred between the feet; **landmarks** from the Tripo rig (name map in `pipeline.json`; `spec: unity` should be identity [tripo §5.2]) or from config; **proportion warp**: a source armature on the landmarks, each bone posed so head and tail land on the table's joints in the measured A-pose (rotate and stretch along the bone, never girth), applied; report the worst joint residual.
   - `blender_rig.py`: the project armature on the table with A-pose arms; weights `"tripo"` (Tripo's groups renamed, fingers merged into the hand, extras into their parent) or `"auto"` (`ARMATURE_AUTO` [blender §3.2]); KDTree fill of unweighted vertices, limit 4, normalize; **arms posed down and applied as rest** (the one exporter-consistent route [blender §3.8]).
   - `blender_parts.py`: part replacement (delete faces dominated by the hand bones, add a fist weighted 100% to the hand with its cuff blended into `*LowerArm`; the same for a head at the neck); `split_fp(hidden_bones, upper_arm_cut, cap_depth_m)`: Chest, UpperChest, Neck, Head, both Shoulders and the shoulder half of each upper arm [rig §2] into `Body__fp_hidden`; **every open loop of the visible part closed with an inward rounded cap** (the elbow end reads as a rounded cap; a look down the belly is never hollow).
   - `blender_palette.py`: label the dense mesh's faces from the Tripo texture (BVH nearest + barycentric UV [blender §3.7], Lab-nearest of this character's swatches, 2-pass majority filter), relax the border loops, **decimate to budget with border vertices protected** (Decimate COLLAPSE with a "keep" vertex group), then per-face palette UVs; UV2 smart-project when `detail: true`.
   - `blender_export.py`: smooth normals to COLOR, export per 2.6, write the `.import`, save `work/<id>.blend`. `gen_palette.py`: the atlas.
5. **`tripo.py`** (stdlib, on [tripo §2.6]'s skeleton): `balance`, `upload`, `image-to-model`, `multiview`, `rig-check`, `rig`, `texture`, `wait`, `--dry-run` (body + expected cost); ledger, the 750 stop, download in the same run.
6. **The smoke Punk** (`characters/punk/smoke/`): one Gemini job, the pick or else `punk_a_denim_vest.jpg` plus `mannequin_front.png`: "the same character on the mannequin's exact proportions and A-pose, orthographic front, **flat unshaded albedo colours, no ink outlines, no cel shading**, no cast shadow, flat #d9d9d9" (the concepts' ink lines would bake into Tripo's texture). Then T1, T2, T3 (§10); dump bones; **weights A/B**: `tripo` vs `auto` on the same table armature, Workbench stills at the guard (UpperArm 43°, LowerArm 130°), elbow 150°, arm raise 140°, knee −130°, spine twist; choose by eye, log why. Fists: a Blender-made rounded fist (no credits) to exercise the replacement. Export `assets/export/characters/punk/punk.glb` and `palette/punk.json`.
7. `tests/test_art_contract.gd`: for every `assets/export/characters/*/*.glb` and the fixture: 2.6's contract, budget, sole plane, fist envelope, 4-6 swatches, **no swatch in the red band** (the rule of `test_bruises_are_not_red_paint`), every export named in ASSETS.md.
**Done:** fixture and smoke GLB pass; the ledger shows T1-T3 with real costs; stills sane (faces −Z, joints on the table, weights hold at the probe poses). Findings (side label, facing axis, v3.5 cost, bone names) in `M4-calls/P1-pipe.md`.

### P1-skin: skinned art on the real rig (Sonnet, Godot; est. 8-10%)
Owns §3's rig rows, `first_person_camera.gd`, `fp_view.gd`, `skinned_view.gd`, `test_skinned_art.gd`, `tests/fixtures/skinned_probe_art.gd`, `skin_acts.gd`.
Implement 2.4 and 2.5. **Ragdoll write-back** in `Ragdoll._process_modification_with_delta` (ragdoll.gd:614-647): after each `_visual[i]`, `skeleton.set_bone_pose_rotation(i, <local of _visual[i] against _visual[parent]>.basis.get_rotation_quaternion())` plus the Hips/Root position, so the skin shows exactly what the followers show (0.115 m → 0.0000 in the probe [rig §0.3]). `look_show_art` drives `set_art_shown` live. Fixture: a procedural `CharacterArt` (a `PackedScene` built in code, one skinned capsule per bone) so nothing waits for P1-pipe; add the probe GLB as a second fixture once pushed. Tests: CPU-skinned vertices = FK at idle/jab/flinch; binds at 1.8, 2.05, 2.3 m; layers and the `first_person_body` setter; `set_shown` (KO blink) hides art and overlay; `set_art_shown` swaps; ragdoll gap 0 in a test modifier after `Ragdoll`; FPView counts proxies, skips art; `_head_clear_of` unchanged; ragdoll with art error-free; `check()` catches each violation. Captures: "Look: skin probe" (probe art on a hand-spawned Punk in the crowd room: idle, jab, stagger, knockdown, KO blink; FP at 1.5 m and side view). **Done:** green; only `fp_view.gd` among existing tests edited.

### P1-toon: one toon shader, the hull, flash and damage on it (Sonnet, Godot; est. 8-10%)
Owns §3's toon rows, `test_humanoid_rig.gd`, `test_hit_flash.gd`, `test_vfx.gd`, new `test_toon.gd`, `toon_acts.gd`.
Build 2.7 from the verified shaders [blender §8.1-8.2]. Convert **every** character and prop material: primitives (`character()`, flat `albedo` per Paint, `marks` 1 except DARK), the art (`art()`, `edge_tag` 0), the pipe, `environment()` for boxes, `grid.gdshader` via the include. In `RigPaint`: `_materials` → `Dictionary[int, ShaderMaterial]`; `set_flash` → `flash_color/amount`; `show_flash_overlay` → `next_pass` on `base_materials()`; `DamageLook.prepare/apply` (damage_look.gd:61/75) retyped to the toon uniforms with the same four tiles and the texture-swap-only rule; `outline_material()` = the hull (art; primitives only with `look_hull_on_placeholders`). Halftone in the include: screen-space dots in the shadow band, environment on, characters off by default. `warm_up()`: windowed only, one frame per variant (primitive, art, hull) at load, the `_warm_flash` pattern. Update the pinned material assertions through `color_of()`, `base_materials()` and the uniforms ("never switches the variant" → "the shader and every uniform but the flash/damage ones unchanged"), each change logged. `test_toon.gd`: shaders load with no `SHADER ERROR`; the `outline_width_m` mirror (constant px between near and far, thinner beyond, 0 within `lens_fade_m`); a band mirror; Tuning pushes uniforms; flash and damage on toon. Captures: dummies and a primitive Punk at 1 m and 3 m, before/after. **Done:** green; sheets show 2-3 bands, a tinted shadow side, rim and a hard highlight.

### P1-post: edges, grade, both rooms, the look probe (Sonnet, Godot; est. 6-8%)
Owns §3's post rows, `test_look_post.gd`, `look_post_acts.gd`, `assets/*/look/`, ASSETS "Look".
Build 2.8 from the verified prototype [fx §6.3, blender §8.3]: roughness mask, depth fade, `VIEWPORT_SIZE.y/1080` scaling; `tools/gen_lut.gd` → `grade_lut.png` (warm highlights, cool shadows, enemies' saturation kept, environment slightly muted) and its `ImageTexture3D`; `look_aa_mode` applied to the viewport (project.godot untouched); glow off (SPEC: no bloom but VFX). `test_room.gd` calls `RoomKit.build_environment/flat_material/grid_material/build_presentation`; `RoomKit.flat_material` returns `ToonMaterials.environment(color)` typed `Material`. `look_probe.gd` L1-L3, L5, L6 (§11). Perf: "Perf, six with ragdolls" windowed, vsync off, edges on/off × AA modes, in a quiet slot the lead schedules (no Blender) → calls file. **Done:** green; ink lines on buildings, crates, floor edges and primitives in FP; HUD, impact frame, speed lines unaffected.

### P1-fx: the comic VFX set, final pass (Sonnet, light Godot; est. 5-7%; starts in the first free Godot slot)
Owns §3's fx rows, new `test_fx_m4.gd`. Within SPEC §10 (SVG from `tools/gen_fx.gd`, 512 px PNGs, 8-10 words; test_vfx.gd:251/:1061 untouched): ink weight matched to the hull and HUD border (one INK `#120f17`); Ben-Day dots drawn as explicit circles; a second variant per burst tier, never repeated twice running; letters sized by cap height, not word width [fx §2.3]; an inner highlight on lettering; LYING splats unshaded or toon-tinted; red only for blood, warning and finisher accents; seeded, byte-stable. Captures: vfx_bot tiers side by side, a finisher with the impact frame on and off. **Done:** green; new art logged.

Phase 1 ends when the five merge green (lead: preset and palette regenerated, suite, HANDOFF).

---

## 6. Phase 1c: the slice and its gate

### SL-int: the smoke Punk fights in the crowd room (Sonnet, Godot; est. 5%)
Owns in 1c: `street_punk.tscn` (`art = punk_art.tres`), `punk_art.tres`, `look_acts.gd`, `readability_probe.gd` (only if it breaks), the Punk fallout in the three pinned tests, wiring fixes in rig/paint files. Turn the art on; fix only what a real art Punk breaks; warm the art variants at room load (`ToonMaterials.warm_up(room, <a Punk art instance>)`, 2 frames); probe L4 (art vs proxies by an ID render). Acts (crowd room, AI frozen, waves off, caption hidden; a second set with the impact frame off):
- "Look: Punk at 1 m, standing" (5 s at default pitch, 5 s face shot at +8°); "…turntable" (the actor turned 360° in 8 s); "…in motion" (scripted walks toward/back/left/right on a 1.0-1.6 m path, taunt, jab+cross, shove); "…takes hits" (jab → flinch + flash, hook → partial-ragdoll stagger, haymaker → launch, knockdown, get-up, one-hit KO → slump and blink-off); "…damage looks" (100/65/30%, 1 s each, then a jab);
- "Look: Punk beside the placeholders" (Punk, Kicker, Thug at 1.4 m); "Look: six Punks at 2-10 m" (AI on, god mode, 30 s, probe on).
**Done:** green; the 60 s autopilot crowd act with art Punks has 0 errors and every hard R-metric (R1-R3, R10, R11) met.

### The slice gate (lead + one Opus reviewer + ≤ 2 Sonnet fixers; est. 8-12%)
From SL-int's full-res sheets, `look.json`, `readability.json`, the ledger and `report/`. Pass = all of: (1) **reproducible**: `run.py --asset punk --check` rebuilds the same report hash, the ledger accounts for every credit; (2) **contract**: `test_art_contract`, `test_skinned_art` green, no `neutral_bone`; (3) **mechanics with art**: it fights, the flash lands on the struck spot for 2 frames, damage marks stick, skin = followers in ragdolls, KO blink-off, the full suite green with the count only up; (4) **the look chain** works on the real asset: bands, tinted shadows, hull near `look_outline_px`, edges with no double silhouette (or R7's fallback chosen), grade on; (5) the perf delta measured (not a bar yet). Output `docs/milestones/M4-slice-gate.md`: locked choices (weights source, fit, border method, outline px, edge mask, AA mode), the ranked fidelity gaps (each → a phase-2 brief line), fixes made. HANDOFF.
**If the pick is still out:** start F-motion and F-look on the smoke Punk; when only pick work remains, one DM that it is blocked on the pick (Comms rule, 2026-10-25).

---

## 7. Phase 2: fidelity passes (after the pick and the gate)

### F-punk: the picked Punk at full fidelity (Sonnet, Blender + Tripo; est. 10-12%; T4-T10, 145 expected)
1. **Views** (`views_jobs.json`, gemini-3-pro-image, 2K, 3:4, `responseModalities ["IMAGE"]`): front, then back, left, right, each referencing the concept, the mannequin view of that side and the accepted views; [tripo §3.4]'s template plus "on the mannequin's exact proportions and A-pose" and "flat albedo, no ink outlines, no cel shading". `views_check.py` (Blender Python + numpy): same size, subject height within 3%, feet on one row; regenerate failures (~$0.13).
2. **T4** front/left/back: an asymmetric detail (Punk A: the forearm tape) settles which side "left" is [tripo §7.2]; fix the mapping in `tripo.py`. **T5** the 4-view model (retries change `model_seed` or a view). T6 only if mushy at 1 m. T7 re-texture (10) when only the texture is off.
3. **T8 rig** (v3.0, `spec: unity`): warp landmarks and the weights candidate per the gate's lock.
4. **T9 glove fist:** Gemini fist views (knuckles, thumb side, back plate; dark fingerless glove, bare fingers, accent strap), multiview `geometry_quality: "detailed"`; orient to 2.6's fist frame, mirror, replace both hands.
5. Borders per the gate; ≤ 15,000 tris (head, cap, glasses ~3.5k; torso 5k; arms 2.5k; fists 1.5k; legs and shoes 2.5k: at 1 m the lens sees cap to thighs [fx §9.2]).
6. **Head pass, T10, only if** the 1 m face shot fails rubric 2-3: Gemini head views filling the frame → multiview detailed → cut at the neck, weight Neck/Head, replace.
7. Export over `punk.glb` (same path; `punk_art.tres` and the scene unchanged); ASSETS rows; re-record `look_acts.gd`. **Done:** contract green; the 1 m sheets beside the concept read as the pick.

### F-player: the player's arms and legs, and the body carrying them (Sonnet, Blender + Tripo + Godot; est. 10-12%; T11-T14, 185 expected)
**A full generated body**, not a hybrid: the KO view shows the whole lying body (README M2) and the hidden upper body casts the shadows the player sees. ≤ 30,000 tris, two thirds FP-visible (fists 2×3k, forearms 2×1.5k, belly/belt 1.5k, legs 2×2k, shoes 2×2k).
1. Views of the hero pick (mix-and-match: separate references per part, e.g. sheet A's wraps, sheet B's boots) on the mannequin; T11 body; T12 rig.
2. **T13 wrapped fist** (wraps across knuckles and wrist, dark fingerless-glove plate, skin fingers [ARCHITECTURE "Hands"]) from the sheet's hand callouts, detailed geometry, up to 3 tries: the most-seen asset in the game. T14 a shoe only if the body's fail the FP look-down.
3. `split_fp` with caps; **1k detail mask** on UV2 (R = ink: wrap edges, glove stitching, shoe seams, trouser folds, from palette borders in UV2 space and the fist texture's dark strokes) → `player_detail.png`; the shader multiplies toward `ink` by it.
4. Godot: `player_art.tres`, `player.tscn` `art = …`; fix the player fallout tests (§3); `test_art_player.gd` (FP-visible art never ≥ 2 cm nearer the lens than its proxies over `test_humanoid_rig`'s FP poses; art/proxy coverage per pose; the visible mesh watertight, caps closed). `look_player_acts.gd`: "Look: my arms and legs" (idle ahead, look down 45° and 65°, jab, cross, hook, uppercut, front kick, spin kick, block guard, hold + knee, haymaker charge, KO view).
**Done:** FP sheets show wraps, glove plate, sleeves/trousers, shoes crisp at 0.3-0.6 m, no hollow cut, outlines not heavy; green.

### F-motion: "in motion" on the same frame data (Sonnet, Godot; est. 6-8%)
Owns the pose and animation files. **Every active-frame and contact pose is a key and stays the key.** Cubic rotation interpolation (`Animation.INTERPOLATION_CUBIC`) on the named loops and posture clips (idle, walks, run, taunt), on moves only if every reach/FP test stays green, else eased in-between keys (anticipation before wind-ups, ease-out in recoveries). Life: breathing in the idles (Chest/UpperChest ±1-2°, ~0.25 Hz), a boxer bounce and weight shift for the enemy guard (Hips ±1 cm, knees compensating so `resolve_hips` keeps the soles planted), head micro-motion; the player's relaxed idle calmer (its FP tests decide). Overlap: head and shoulder lead/lag keys on `punk_jab/cross/shove` and the flinches. Walks: counter-swing, hip roll; foot slide (art soles in planted frames via `skinned_view.gd`) ≤ 2 cm per step, else stride matched to `punk_speed_mult`. Tests: the suite untouched and green; `test_motion_m4.gd` (key poses identical at active frames, no hurtbox change at an active frame, slide bound). Captures `look_motion_acts.gd` at 1 m, 12 fps. **Done:** sheets read alive, not pose-to-pose.

### F-look: tune on the real Punk; placeholders beside it (Sonnet, Godot; est. 5-7%)
Owns the toon, post and paint files and `look_tune_acts.gd`. Tune every Look tunable against the Punk at 1, 3 and 8 m in both rooms: 2-3 readable bands on the jacket, shadow tint toward the sky's blue-grey, a rim that lifts the Punk off the street, a small hard highlight on cap and glasses, hull reading like the edge lines and the VFX ink, crease lines without noise, the grade; environment muted, enemies saturated (SPEC §10). Retune the placeholders (Kicker, Thug, Bruiser, Boss, dummies, pipe) through the same tunables only. **Done:** L1-L5 in range, sheets read as one game.

Phase 2 ends when the four merge green and §11's A-rows pass for the Punk and the player.

---

## 8. Phase 3: the done-when

### P3-int (Sonnet, Godot; est. 6-8%)
- Final evidence acts (`look_acts.gd`) on the picked Punk, plus "Look: Punk at 1 m, the long take" (one 40 s clip: idle, turntable, walk in, taunt, jab+cross, takes a jab, stagger, knockdown, get-up, KO) for the DM.
- **F4 "Showcase Punk at 1 m"** (cheat_menu.gd): a frozen Punk 1 m ahead looping the long take's script, so Game-boy can walk round it in the game (F4's Freeze AI alone shows only an idle).
- `look_probe` final; `tests/test_m4_done_when.gd` asserting every A-row headless.
- **The four deferred feel questions** (README M2 "until the art is in"; HANDOFF 21:10), measured with the art, each alternative behind an "FP feel" toggle **defaulting to today**: (1) flash size in FP (grab-05: knee flash ~16% of the view 3× per hold; hit-01: flurry strobes 14-18% at 8.6 Hz) → `hit_flash_fp_max_share` (0 = off), a shader cap on the on-screen radius from the camera distance (the sim's `flash_at` untouched); (2) the haymaker's flash barely shows in FP (r3look-05) → `hit_flash_finisher_radius_mult` (1.0); (3) the non-KO knockdown "belly slab" (up to 74% of the view) → `fp_knockdown_hide_torso` (false); (4) grab-03, the combat log over the knee → a log toggle key in the help overlay and `combat_log_hide_while_holding` (false).
- Perf A/B (the lead runs it, quiet machine, back to back): `main` at `afdb39e` vs the M4 branch, "Perf, six with ragdolls", vsync off.

### Review round (`docs/reviews/M4/workflow-review.js`, the M3 copy; est. 25-35%)
Six Opus lenses, first person, full-res stills and 12 fps sheets: **V1** Punk standing at 1 m (rubric 1-8), **V2** Punk in motion (9-15), **V3** the player's arms and legs (17), **V4** one look (toon, hull, edges, grade, halftone, VFX, placeholders, both rooms; 16), **V5** pipeline and assets (rebuild from ledger and `pipeline.json`, ASSETS, LFS, budgets, licences), **V6** code, tests, perf (proxy honesty: does any FP number now measure something nobody sees? no numbers in scripts, layers, warm-ups, R15 A/B, spawn hitch). A skeptic per finding; survivors to ≤ 4 fixers with disjoint files.

### Docs, PR, DM (lead; 2-3%)
README "Milestone 4 status" and "Where M4 departs from the spec" (§13's D-list, "decided by default, for Game-boy's ruling"), ARCHITECTURE "Art pipeline and look", ASSETS.md, `M4-judgement-calls.md`, HANDOFF; the PR into `main` (never merged without sign-off); the DM (§9.2).

---

## 9. The two pauses

### 9.1 The concept pick (out since 21:42; nothing needs it before phase 2)
- **Sent:** Punks A-D (front A-pose, teal with a yellow accent, covered faces, no red) and hero sheets A-C (full body plus hand, fist and shoe callouts), from `concept_jobs.json` via `tools/gemini_image.py`, gemini-3-pro-image, 2K. **Asked:** one Punk and one hero, mix-and-match allowed.
- **Meanwhile:** phases 0, 1, 1c (the smoke uses Punk A if the pick is late and is replaced in place), then F-motion and F-look. Only F-punk and F-player wait.
- **On his answer:** no follow-up question. The lead checks F-punk's/F-player's views against the pick and sends one FYI image only if they visibly drift. If he rejects all: round 2 (up to 4 of each, ~$1) with his notes, same thread. If the pick is all that's left: one "blocked on the pick" DM.

### 9.2 The final judgement
- **Shown** (same thread): (a) stills sheets of the Punk at 1 m standing (default pitch, face shot, turntable quarters), in motion (walks, taunt, attacks), taking hits (flash, stagger, knockdown, get-up, KO blink), damage looks, each beside the picked concept; (b) 2-3 MP4 clips (H.264, 1280×720, ≤ 10 MB): the long take at 1 m, a six-Punk fight at 2-10 m, his own arms and legs in FP; (c) the run command as a Run-button block, `godot --path /Users/arachne/repos/beat-em-up-PoC`, with "F4 → Waves off → Showcase Punk at 1 m, walk round it, or fight live; F1 → Look → `look_show_art` flips to the placeholders for comparison"; (d) the rubric with the measured numbers; (e) the four feel questions, each with a sheet and its F1 toggle; (f) the judgement-call digest and the departures for his ruling; (g) credits used and the licence question (is the Tripo account paid? [tripo §6]).
- **Asked:** "Is the Punk production-quality at 1 m, standing and in motion? Yes, or what fails." A "no" → rubric item → package → fix round → the same DM again.

---

## 10. Tripo credit budget (v3; costs [tripo §2.5])

Generation options: `model: "v3.1-20260211"`, `texture: true`, `pbr: false`, `texture_quality: "standard"`, `texture_version: "v3.5-20260815"`, `delight: true`, `orientation: "align_image"`, `face_limit: 20000`, fixed `model_seed`; `export_orientation`, `quad`, `compress`, `generate_parts` unset. T1 reads v3.5's real cost; above 30 → `v3.0-20250812` and rescale.

| # | Task | Package | Call | Each | Exp. runs | Expected | Max runs | Ceiling |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Smoke Punk, one flat front view | P1-pipe | image-to-model | 30 | 1 | 30 | 2 | 60 |
| T2 | Smoke rig-check | P1-pipe | rig-check | 0 | 1 | 0 | 1 | 0 |
| T3 | Smoke auto-rig: names, joints, weights A/B | P1-pipe | rig v3.0 `unity` | 25 | 1 | 25 | 1 | 25 |
| T4 | Punk side-label probe (front, left, back) | F-punk | multiview | 30 | 1 | 30 | 1 | 30 |
| T5 | Punk 4-view model | F-punk | multiview | 30 | 1 | 30 | 2 | 60 |
| T6 | Punk detailed geometry (only if mushy) | F-punk | multiview + detailed | 50 | 0 | 0 | 1 | 50 |
| T7 | Re-texture accepted geometry | F-punk | models/texture | 10 | 1 | 10 | 2 | 20 |
| T8 | Punk rig | F-punk | rig v3.0 | 25 | 1 | 25 | 2 | 50 |
| T9 | Punk glove fist | F-punk | multiview + detailed | 50 | 1 | 50 | 2 | 100 |
| T10 | Punk head (only if the face fails) | F-punk | multiview + detailed | 50 | 0 | 0 | 1 | 50 |
| T11 | Player body | F-player | multiview | 30 | 2 | 60 | 3 | 90 |
| T12 | Player rig | F-player | rig v3.0 | 25 | 1 | 25 | 1 | 25 |
| T13 | Player wrapped fist | F-player | multiview + detailed | 50 | 2 | 100 | 3 | 150 |
| T14 | Player shoe (only if FP fails) | F-player | multiview | 30 | 0 | 0 | 1 | 30 |
| | **Total** | | | | | **385** | | **740** |

No retarget presets (J2). The ledger stops at 750 (50 under the 800 allowance, for float costs and surprises); past that the lead asks Game-boy. Gemini: ~40 images on 3 Pro 2K, about $5.

---

## 11. The done-when, made checkable

Production-quality at 1 m, standing and in motion = every measured row passes, every rubric item is "yes" from the lenses, and Game-boy says yes.

### 11.1 Measured (headless GUT unless [W] = windowed `look_probe.gd` → `look.json`)
| ID | What | Pass |
| --- | --- | --- |
| A1 | GLB contract (2.6): 23 named binds, no `neutral_bone`, joints vs table | ≤ 1 mm |
| A2 | Triangles | Punk ≤ 15,000; player ≤ 30,000 |
| A3 | Colours: swatches per character from the shared atlas; none red | 4-6; 0 |
| A4 | Soles at rest; feet over a walk cycle (CPU-skinned) | y 0 ±5 mm; never below −15 mm |
| A5 | Fist vs the fist box at `FistPoint` | centroid ≤ 15 mm; extents ±20% |
| A6 | Hurtbox fit at idle: axis points inside the art; art within radius + 6 cm (torso, legs) | 100%; ≥ 95% of vertices |
| A7 | Peak flexes (guard, elbow 150°, arm raise 140°, knee −130°, spine twist, lying): triangles under 15% of rest area or flipped | ≤ 0.5% |
| A8 | Ragdoll skin vs `_visual`, worst bone, partial and full | 0.000 m |
| A9 | Art vs proxies on the FP grid at the 1 m acts' poses (Punk) and the FP poses (player) | ≤ 3% of cells differ; player art never ≥ 2 cm nearer the lens |
| A10 | Damage-look coordinates of a vertex across idle, jab, knockdown | identical (no swimming) |
| A11 | Flash: 2 rendered frames on the struck part, on the art | the hit-flash tests, on art |
| A12 | Every pre-M4 test passes; count only rises | 1198+, 0 `SCRIPT/SHADER ERROR` |
| L1 [W] | Distinct luminance clusters on the jacket at 1 m (ID-render mask) | 2-3 |
| L2 [W] | Hull width at 1 m and 5 m (silhouette ink runs, at 1080p) | `look_outline_px` ±1 px |
| L3 [W] | Shadow-band / lit-band luma on the jacket; hue toward the tint | ≥ 0.4 |
| L4 [W] | Punk's lens share at 1 m, art (ID render) / proxies (FPView) | 0.85-1.15 |
| L5 [W] | Flash white share of the view on a jab at 1 m | ≤ M2's localized figure + 2 points |
| L6 [W] | Perf A/B, "Perf, six with ragdolls", vsync off, quiet machine | soft: p95 ≤ pre-M4 + 4 ms on the M1; spawn hitch ≤ 33 ms |

### 11.2 Judged (V1-V4, then Game-boy)
Standing at 1 m: (1) reads as the pick beside it; (2) the face is covered or simplified and holds up; (3) no holes, spikes, smears or baked light; (4) colour borders crisp on clean lines, 4-6 flat colours; (5) 2-3 bands, tinted shadows, rim, hard highlight; (6) outlines even, uncracked, not thick; (7) the hands read as gloved fists at the chin; (8) a chunky silhouette that reads at a glance. In motion: (9) the idle is alive, no robotic snaps; (10) the feet plant walking and circling; (11) wind-ups read, elbows and shoulders deform cleanly (no candy-wrap, no collapse); (12) flinch, stagger, knockdown, get-up follow the ragdoll exactly; (13) the flash lands on the struck spot; (14) damage looks stick to the body; (15) KO slump and blink-off read. Around it: (16) the placeholders under the same shader don't clash; (17) the player's arms and legs read in FP (wraps, glove plate, sleeves, trousers, shoes; no hollow cuts; crisp lines at 0.3-0.6 m).

### 11.3 Evidence pack
`docs/reviews/M4/evidence/` (PNG via LFS, JSON): the 1 m sheets per act, full-res and 12 fps, beside the concept; `art_metrics.json` (A-rows), `look.json` (L-rows), the perf table, the ledger summary, `index.md` mapping each rubric item to frames. Clips stay in `captures/m4_evidence/` and go to the DM.

---

## 12. Coverage map

| SPEC §10/§12 requirement | Built | Tested | Seen |
| --- | --- | --- | --- |
| 2-3 band ramp, hard spec, rim, tinted shadows; one shader, per-material parameters | P1-toon, F-look | `test_toon`, L1, L3 | `toon_acts`, `look_tune_acts`, V4 |
| Inverted hull, width scaled with distance | P1-toon (art; placeholders via toggle) | width mirror, L2 | 1 m / 5 m acts, V1, V4 |
| Environment edges from depth and normals | P1-post | `test_look_post` | `look_post_acts`, V4 |
| Optional halftone; LUT; no bloom but VFX | P1-toon (halftone), P1-post | `test_look_post` | V4 |
| Final player arms and legs | F-player | `test_art_player`, A9, FP suite | `look_player_acts`, V3 |
| Concept, 2-4 images, Game-boy picks | round 1 (done) | — | DM 21:42 |
| Image-to-3D in an A-pose | P1-pipe, F-punk | ledger, A1 | `report/`, V5 |
| Blender clean-up: metres, transforms, normals, decimate, head split, palette UVs | the chain | `test_art_contract` | V5 |
| Rig (Tripo's auto-rig first) | T3, T8, T12, `blender_rig.py` | A1, A7 | weights A/B stills |
| Animate in place, code drives movement | procedural set, F-motion | A12, `test_motion_m4` | `look_motion_acts`, V2 |
| `.glb` export to `/assets/export/`; Godot import | `blender_export.py`, `SkinnedArt` | `test_skinned_art`, A1 | SL-int acts |
| ASSETS.md for every asset | every asset package | contract test | V5 |
| Budgets 15k/30k; palette atlas; player 1k detail mask | pipeline | A2, A3 | V5 |
| Comic VFX set (SVG → 512 px) | P1-fx | `test_vfx`, `test_fx_m4` | vfx_bot, V4 |
| Faces covered and holding at 1 m; red reserved | concepts, F-punk head pass | A3 | V1 (2) |
| 1080p60 with 6 enemies on an RTX 3060 | toggles (`look_edges_enabled`, `look_aa_mode`) | L6 on the M1 (soft) | V6 (target unmeasurable here) |
| Done-when | all above | §11.1 | §11.2, §9.2 |
| Approved departures kept: throat lens, relaxed stance, localized flash, FP-hidden upper body, KO blink-off, KO view | unchanged code paths, FP split, proxies | FP suite, A9, A11 | V2, V3 |

---

## 13. Key judgement calls (alternative not taken, and why)

- **J1 Smoke first, with a stand-in if the pick is late.** *Alt:* no Tripo call before the pick. *Why not:* 55 credits buy every chain unknown before it matters; the smoke is replaced in place.
- **J2 The existing procedural set animates the art; no Tripo or Mixamo clips.** *Alt:* Tripo's v3.0 presets or v1.0's box/kick clips. *Why not:* 26 moves and 46 animations are tuned to frame data, hitboxes, telegraphs and the FP view, and the profile importer can't produce the identity-rest skeleton [blender §5]. A departure (D1).
- **J3 Fit the mesh to the skeleton.** *Alt:* move the joints to the mesh. *Why not:* hurtboxes, rig points, ragdoll anchors, reaches and FP framing derive from the table [rig §9b.4].
- **J4 Re-rest arms-down in Blender, translation-only binds.** *Alt:* A-pose mesh with the swing in the binds [blender §6.2]. *Why not:* a GLB in the project's rest is self-describing and checkable (A1); both deform alike.
- **J5 Hidden primitives as view proxies.** *Alt:* CPU skinning inside FPView, or deleting the primitives and ~80 tests. *Why not:* far too slow in GDScript [rig §8.1]; rewritten tests lose their M1-M3 meaning. A9 and L4 bound the gap.
- **J6 Full generated player body with an FP split.** *Alt:* art arms and legs on a primitive torso. *Why not:* the KO view and the FP shadows show the whole body.
- **J7 Fists generated separately, replacing the hands.** *Alt:* Tripo's hands, or finger bones. *Why not:* the rig has no fingers, so hands are always fists; A-pose hands come out open and blobby; finger bones touch every pose.
- **J8 Tripo's auto-rig first, A/B against Blender's.** *Alt:* Blender only, or Mixamo. *Why not:* Game-boy's rule; Tripo's joints double as warp landmarks; Blender is the verified fallback.
- **J9 Hull on `material_overlay`, art only; placeholders outlined by the edge pass.** *Alt:* a `next_pass` chain, or hulls on every primitive. *Why not:* the flash owns `next_pass` and its tests pin it [fx §6.2]; 41 more draws per placeholder rig. Reachable: `look_hull_on_placeholders` (D2).
- **J10 Edge pass as a world quad with a roughness tag.** *Alt:* a CompositorEffect. *Why not:* the quad is verified in both cameras at the same buffer cost; the tag avoids double silhouettes (D3).
- **J11 Halftone on the environment only, by default.** *Alt:* everywhere. *Why not:* screen dots swim on a moving body at 1 m (D4; the spec calls it optional).
- **J12 Damage look as a rest-space triplanar (CUSTOM0/1).** *Alt:* a damage UV2 atlas or vertex colours. *Why not:* same tiles and look, no authoring, no seams; object space swims on skin [rig §0.5].
- **J13 Placeholders go toon too.** *Alt:* keep StandardMaterial3D and skip the test edits. *Why not:* "one shader for everything"; V4 would see two games.
- **J14 Art Punks aren't recoloured per actor.** *Alt:* an index atlas with per-rig palettes. *Why not:* all Punks wear the same colours; the atlas holds flat colours.
- **J15 VFX stay 512 px.** *Alt:* 1024. *Why not:* SPEC and test_vfx pin it; 512 is ~1:1 at the 0.25 view-share cap at 1080p [fx §7].
- **J16 The training room renders through RoomKit.** *Alt:* copy the look into `test_room.gd`. *Why not:* every bot but crowd_bot renders there.
- **J17 The deferred feel questions become toggles defaulting to today, asked in the final DM.** *Alt:* decide them. *Why not:* they are his (README M2), and now judgeable.
- **J18 Views drawn on a mannequin rendered from the table.** *Alt:* free proportions and a bigger warp. *Why not:* the closer the generation, the smaller the warp.

**Departures for his ruling:** D1 pipeline steps 4-6 (rigged to the project's own humanoid, animated by its procedural set, no humanoid-profile import); D2 hulls on art characters only; D3 no depth edge lines on hulled characters; D4 character halftone off by default.

---

## 14. Risks, and what we do if each shows

| # | Risk | Shows as | Then |
| --- | --- | --- | --- |
| R1 | Tripo geometry or face mushy at 1 m | V1 (2-3) | T6 detailed; T10 head replacement; a covered face rebuilds easily |
| R2 | Tripo rig names unusable | `bones.json` doesn't map | `weights: auto` (verified) and config landmarks |
| R3 | The warp distorts | residual > 1 cm, stretching | regenerate views nearer the mannequin; lengths only |
| R4 | Skinning fails at the guard elbow or arm raise | A7, V2 (11) | smooth shoulder/elbow weights, blend UpperChest-Shoulder-UpperArm; never a pose change |
| R5 | Palette borders jaggy at 1 m | V1 (4) | border-protected decimation; fallback a per-character posterized 1k texture in palette colours (logged departure) |
| R6 | Views disagree or "left" mirrors | `views_check`, T4 | regenerate a view; swap labels; Tripo image-to-multiview (10) |
| R7 | The roughness tag isn't in the buffer | double silhouettes | depth lines everywhere with a thinner hull, or hull off on art |
| R8 | Edge + hull cost on the M1 | L6 | FXAA (~−2 ms), fewer taps, edges off on the Mac; target machine unmeasured (flagged) |
| R9 | First-use compiles | spawn hitch > 33 ms | warm every variant at room load, the skinned one included |
| R10 | Proxies hide an art problem in FP | A9, L4 | refit the art, or swap that region's proxy for a capsule fitted to the art |
| R11 | A hull inks the view as a limb passes the lens | black flashes in FP | `look_outline_lens_fade_m`; the FP-hidden set keeps chest and shoulders away |
| R12 | Motion polish moves a tuned pose | reach/telegraph/FP tests | keep the keys, ease only between; drop cubic on that clip |
| R13 | 8 GB with Blender and Godot | swapping | ≤ 4 Godot builders, ≤ 2 Blender processes; P1-fx waits |
| R14 | The pick is late or rejected | F-punk/F-player idle | slice, F-motion, F-look first; one blocked DM; round 2 |
| R15 | LFS quota | push refused | only accepted raw outputs committed |
| R16 | Tripo licence (free vs paid) | unknown | noted in ASSETS.md; asked in the DM before anything ships |
| R17 | Texture v3.5 costs more than 30 | T1's `credits_consumed` | texture v3.0; rescale §10 |
| R18 | The write-back changes ragdoll test results | test_ragdoll | it writes only in the modifier after the simulator and the skeleton restores its pose [rig §9a.3]; the suite decides |

---

## 15. Sequencing and usage (% of a premium 5-hour window)

| Step | Runs | Est. | Ends |
| --- | --- | --- | --- |
| Lead pre-cut | lead | < 1 | push |
| S0-contract ∥ P1-pipe starts | 2 builders | 6-8 | S0 merged |
| P1-pipe, P1-skin, P1-toon, P1-post, then P1-fx | 5 builders, ≤ 4 Godot-bound | 37-47 | merged |
| SL-int + slice gate | 1 builder, 1 Opus, ≤ 2 fixers | 13-17 | gate file |
| F-punk, F-player, F-motion, F-look | 4 builders | 31-39 | merged, A-rows pass |
| P3-int | 1 builder | 6-8 | evidence |
| Review round | 6 lenses, skeptics, ≤ 4 fixers | 25-35 | fixes merged |
| Docs, PR, DM | lead | 2-3 | DM |
| **Total** | | **120-160** | about 1.2-1.6 windows, ~20-26 weekly points |

`get_usage` before every launch; launch what fits below 90%. A phase that doesn't fit is split: phase 1's critical pair is P1-pipe + P1-skin, phase 2's F-punk + F-motion. `wip:` commits every 15-20 min; at the watcher's 90% the lead stops the workflow, updates HANDOFF (package states, runner args, ledger total, resume steps) and creates the resume task; HANDOFF at every phase boundary; Sonnet costs re-measured after phase 1.

---

## 16. The questions this plan had to resolve

| Question | Answer (where) |
| --- | --- |
| Fitting without breaking reaches, hurtboxes, FP framing | Mesh warped onto the table, re-rested arms-down, translation-only binds; the rig is untouched (§2.4, §2.6, P1-pipe; J3, J4; A1, A6, A9) |
| What animates the Punk; production-quality motion | The procedural set, polished on the same keys (F-motion; J2; rubric 9-15) |
| Player full body? FP split? | Yes; `Body__fp_hidden` + `Body` with inward caps (`split_fp`, F-player; J6) |
| Hit flash, damage looks, blink-off on new materials | Unchanged overlay on every base material's `next_pass`; parry via uniforms; rest-space triplanar; `set_shown` hides art and hull (§2.3, §2.7; J12; A10, A11) |
| Outlines with distance and on the FP body | Constant px between near and far, `fp_scale` on the player, faded near the lens; hidden meshes' hulls hidden with them (§2.7; L2; R11) |
| Tests that pin placeholder visuals | Art opt-in via `_configure_art`; hidden proxies + `FPView.is_drawn`; material asserts through `RigPaint` with twins; each flip package fixes its own fallout (§2.2-§2.5, §3; A12) |
| Git LFS and ASSETS.md | Existing LFS rules cover glb/blend/png/jpg/webp; `_cache/` ignored; atlas keep-ours; a row per file, enforced by the contract test (§1, §2.6) |
| What stays placeholder and how it looks | Other archetypes, pipe, environment: toon primitives with edge lines, tuned by F-look; a side-by-side act (F-look; J9, J13; rubric 16) |
| The deferred feel questions | Measured with art, toggles default to today, asked in the final DM (P3-int; J17) |
