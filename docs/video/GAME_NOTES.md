# Game map for the video pipeline

A read-only scout's map (Sonnet, 2026-11-08, at `1ae0b7a`) of the game APIs the video pipeline uses, with `file:line` references. Line numbers drift: grep before relying on one. Builders read the sections their package needs, not the whole file.


Convention: `file:line`. "NOT" means it does not exist. "NEEDS game/tests" means it can't be done without editing a protected tree. Paths are relative to the worktree root.

---------------------------------------------------------------------------
## 1. LEVEL SCENES

### Structure
- `game/level/mission1/mission1.tscn:1-7`: a bare `Node3D` named "Mission1" with `level_root.gd`, `section_paths = [street.tscn, roofs.tscn, boss_roof.tscn]`. Main scene is this file (`project.godot:run/main_scene`).
- `LevelRoot` (`game/level/kit/level_root.gd`, `class_name LevelRoot`, group `level_root`, line 19):
  - Exports: `section_paths`, `start_arena`, `with_presentation` (28), `waves_enabled_on_start` (30), `rng_seed` (32), nav params, `section_switch_margin_m`, `void_depth_m`.
  - Public vars (54-66): `player`, `director` (EnemyDirector), `spawner` (EncounterSpawner), `nav_region`, `player_start`, `player_yaw_deg`, `sections: Array[LevelSection]`, `container` (node "Sections").
  - API: `enemies()` (123), `arenas()` (133), `current_arena()` (139), `route_points()` (150), `first_route_point(arena)` (158), `next_target(arena)` (167), `start_at_arena(index)` (178), `current_section()` (214), `current_light()` (264), `light_for(section)` (274), `static blend_light(a,b,t)` (283), `section_light_applies()` (248).
  - `_ready()` (83-120) builds, in order: environment, sections, wiring, navmesh bake, player, `EnemyDirector`, `EncounterSpawner`, pickups, then `RoomKit.build_presentation(self)` if `with_presentation`.
- Sections are laid end to end in `_build_sections` (384-406): section k+1's `Entry` sits on section k's `Exit`.
- `LevelSection` (`game/level/kit/level_section.gd`, `class_name`): children `Entry`, `Exit`, `Start`, `Geometry`, `Route/R*`, `Arenas/*`, optional `ExitBarrier`, `Barriers`.
  - Accessors: `entry()`, `exit_marker()`, `start_marker()`, `exit_barrier()`, `arena_list()` (66), `route_points()` (73), `barriers()`, `blocks()`, `stairs()`, `edge_guards()`, `pickup_spots()`.
  - Section light exports (19-36): `light_enabled`, `sun_elevation_deg`, `sun_yaw_deg`, `sun_color`, `sun_energy`, `fog_color`, `fog_density`, `sky_top_color`, `sky_horizon_color`. `light()` (41) returns the dictionary.
- `Arena` (`game/level/kit/arena.gd`, `class_name Arena`, group `arena`): `arena_id`, `table`, `behind_barrier`, `ahead_barrier`, `armed`, `state` (WAITING, LOCKED, CLEARED).
  - Signals `locked()` and `cleared()`; methods `lock()`, `clear()`, `reset_waiting()`, `reset_cleared()`, `contains(p)`, `respawn_position()`, `spawn_points()`.
  - Volume = its `LockTrigger` Area3D `BoxShape3D`.
- `SpawnPoint` (`game/level/kit/spawn_point.gd`): Marker3D with `tag` (doorway, alley, vehicle, stairwell), `lane_position()`, `yaw()`.

### Index of arenas (global level order)
`level.arenas()` order. Each arena's trigger position is in its section's space:

| idx | arena_id | file:line | LockTrigger pos (section space) |
|---|---|---|---|
| 0 | `street_a1` | street.tscn:929 | (-1.5, 2.5, -7.75), box 21x7x12.5 |
| 1 | `street_a2` | street.tscn:963 | box 21x7x16 |
| 2 | `street_a3` | street.tscn:1014 | box 18x10x23 |
| 3 | `a4_terrace` | roofs.tscn:1399 | (-2.35, 2.4, -13.75) |
| 4 | `a5_catwalk` | roofs.tscn:1441 | (7.85, 5.6, -18) |
| 5 | `a6_top_roof` | roofs.tscn:1484 | (19, 10.4, -17.05) |
| 6 | `a7` (boss) | boss_roof.tscn:430 | (0, 4, -10.25), box 21x8x20.5 |

### World placement
Derived from the Entry/Exit markers; verify at runtime with `level.sections[i].global_position`.
- Street (section 0): origin (0,0,0). `Start` (3, 0, 0.8) (street.tscn:47). `Exit` (3, 4.5, -53) (street.tscn:44).
- Roofs (section 1): `Entry` (0,0,0) (roofs.tscn:1536), `Start` (-3, 0, -2) (1533), `Exit` (19, 7.5, -30) (1539). Its world offset is the street exit, so about (3, 4.5, -53).
- Boss roof (section 2): `Entry` at origin, `Start` (0, 0, -0.5), `Exit` (0, 0, -20) (boss_roof.tscn:32-38). Its world offset is the roofs exit, so about (22, 12, -83).
- `floor_heights` per section: street (0, 4.5); roofs (0, 1, 4.5, 7.5); boss (0) (street.tscn:29, roofs.tscn:32, boss_roof.tscn:20).

### Environment, sky, sun (all built in code, NOT in the .tscn files)
`RoomKit.build_environment(room)` is at `game/level/room_kit.gd:70-100`. It adds two children to the LevelRoot:
- `WorldEnvironment` (name "WorldEnvironment"):
  - `Environment.background_mode = BG_SKY` with a `ProceduralSkyMaterial` (top `DEFAULT_SKY_TOP` Color(.36,.42,.56), horizon `DEFAULT_SKY_HORIZON` (.72,.62,.55), ground_horizon (.4,.37,.38), ground_bottom (.2,.2,.22)).
  - `ambient_light_source = SKY`, `ambient_light_energy = 0.7` (line 83). The toon shaders use `ambient_light_disabled`, so ambient does not light them.
  - `tonemap_mode = LookPost.tonemap_mode(Tuning.look_tonemap)`; `look_tonemap` default 0 = LINEAR.
  - `fog_enabled = true`, `fog_light_color`, `fog_density = 0.008` default (`room_kit.gd:27`), `fog_sky_affect = Tuning.section_fog_sky_affect` (0.3).
  - NOT set anywhere in game/: glow, SSAO, SSIL, SDFGI, volumetric fog, `adjustment_brightness/contrast/saturation`. All stay at Environment defaults (off). Only `adjustment_enabled` + `adjustment_color_correction` (the LUT) are written, by LookPost.
- `DirectionalLight3D` named "Sun" (the only light in the game): `shadow_enabled = true`, `directional_shadow_max_distance = 40.0`, rotation and energy from Tuning's `look_sun_*` or the section light (`room_kit.gd:93-100`, `103-107`).
- Section light blend:
  - Street: sun elev 38, yaw -50, color (1, .88, .72), energy 1.2, fog (.52,.5,.6) density .011, sky top (.22,.28,.42), horizon (.64,.5,.5) (street.tscn:28-39).
  - Roofs: elev 36, yaw -60, color (1,.8,.62), energy 1.25, fog (.5,.42,.46) density .011, sky (.26,.29,.42)/(.82,.54,.38) (roofs.tscn:32-42).
  - Boss roof: elev 35, yaw -70, color (.98,.74,.6), energy 1.2, fog (.31,.29,.4) density .015, sky (.2,.2,.34)/(.56,.38,.38) (boss_roof.tscn:20-30).
  - `LevelRoot._apply_light` (334-349) writes `Sun` rotation, color and energy, `env.fog_light_color`, `fog_density` and the sky material colors. It runs only while a blend is in progress or the section target changes (`_step_light`, 314-324, called every physics frame from `_physics_process` 372-374). Blend length is `Tuning.section_light_blend_s` (2.5 s).
  - `_apply_fog_sky_affect` (326-331) rewrites `fog_sky_affect` every physics frame to match `Tuning.section_fog_sky_affect`.
  - Consequence: a video script that sets `Sun`/`Environment` directly sticks while the section is steady, but gets overwritten when a section changes or during a blend. For a persistent override, set `Tuning.section_light_enabled = false` (then `default_light()` uses `Tuning.look_sun_*` plus the room default fog/sky) or re-apply after each `_physics_process`.
  - `LookPost._apply_sun` (`look_post.gd:150-163`) yields to the section light while `section_light_applies()`.

### Lamps
There are NO lamp nodes and NO lamp meshes. Verified:
- NO `OmniLight3D` or `SpotLight3D` anywhere under game/ (the only `DirectionalLight3D` is "Sun").
- No "lamp", "sodium", "streetlight" or neon/sign string in any game/level script or scene.
- `KitMesh.KINDS` (`kit/art/kit_mesh.gd:25-28`) = wall, floor, slab, slab_dark, deck, curb, door_frame, window, shutter, housing, rail, post, stair_flight, cornice, chainlink, gate, crate, skyline. No lamp kind. Props in `game/level/props/` are only ac_unit, car, dumpster, water_tank.
- The street's "sodium" look is purely sun color plus fog plus sky. Any lamp light or glow has to be added by video code (e.g. `OmniLight3D` children; note the toon `light()` handles non-directional lights, `toon_light.gdshaderinc:79-121`, so they would be banded) or as emissive quads.

### Roof edge / parapet / boss arena
- Roofs top roof: `ParapetWest` block (roofs.tscn:782, pos (12.3, 8.2, -20.175), size (0.6, 1.4, 18.35)); `RailEastPost*` fence posts around x = 25.85 (roofs.tscn:1040); `EdgeGuardRoof` at (26.15, 9.5, -18), size (0.3, 6, 24) (roofs.tscn:1047). East lip is therefore at about section-local x 26, roughly world x 29.
- Other roof edges: `EdgeGuardTerrace` (-8.15, 2, -14) size (0.3, 7, 28) (roofs.tscn:453); `EdgeGuardCatwalk` (1.85, 6, -16.25) size (0.3, 5, 17.5) (roofs.tscn:704). Fall hazard volumes: `DropFront`, `DropCatwalk`, `DropEast` (roofs.tscn:1074-1085).
- Boss roof: `Geometry/EdgeGuard` (10.15, 2, -10) size (0.3, 4, 20) on the east side (boss_roof.tscn:168-170). `Geometry/Drop` hazard Area (30, -4, -10) size (40, 14, 60) (boss_roof.tscn:172-176). Skyline modules sit at x = 26..92, z = -50..25, y -12..3 (boss_roof.tscn:176-380). Boss arena a7 LockTrigger (0, 4, -10.25); boss RoofDoor spawn (0, 0, -18.6) tag doorway (boss_roof.tscn:446-448). Deck spans about 21 wide by 20 long. `Respawn` (0, 0, -6).
- Existing pose table for reference: `tests/bot/level_acts/tour_acts.gd:14-37` has 20 section-space camera poses (street_start, roofs_top_roof, boss_gap_down, ...), and `kit_acts.gd` has 13 more. A video script can copy those numbers but must not import them.

---------------------------------------------------------------------------
## 2. LOOK / POST

### LookPost (`game/fx/look_post.gd`, `class_name LookPost`, Node3D, child of the room named "LookPost")
- Built by `RoomKit.build_presentation` (`room_kit.gd:263-290`) only when `with_presentation`. Find it with `room.get_node("LookPost")` or `find_children("*","LookPost")`. NO group.
- Edge pass: a full-screen quad `EdgeQuad` (`edge_quad()`, line 82), material `edge_material()` (87), render priority `Material.RENDER_PRIORITY_MIN + 1` (line 33), `extra_cull_margin` 16384.
- Public API: `edge_quad()`, `edge_material()`, `grade_environment()`, `grade_texture()`, `apply()` (re-pushes everything), static `find_environment(room)`, `aa_settings(mode)`, `tonemap_mode(v)`, `depth_only_shader()`, `node_value`, `identity_lut_bytes`, `mix_lut_bytes`.
- Subscribes to `Tuning.changed` for properties starting with `look_` (line 135-137) and re-applies.
- `_apply_edges` (165-177) writes the edge uniforms below from Tuning each time. `_apply_grade` (180-194) sets `tonemap_mode`, then either `adjustment_enabled = false` (grade off) or sets `adjustment_color_correction = ImageTexture3D` and `adjustment_enabled = true`. `_apply_aa` (197-204) writes the viewport `msaa_3d` and `screen_space_aa` (modes: 0 = MSAA 4x, 1 = FXAA, 2 = OFF).

### Shader uniforms
- `edge_pass.gdshader` (spatial, unshaded, `depth_test_disabled`, `fog_disabled`):
  - `ink` (vec3 source_color), `width_px` (0.5-4, 1.25), `depth_threshold` (.08), `normal_threshold` (.35), `fade_start_m` (25), `fade_end_m` (60), `mask_px` (6), `character_mask` (bool), `debug_view` (int 0-6). Samplers: `depth_tex` (hint_depth_texture), `normal_tex` (hint_normal_roughness_texture).
  - It needs the normal-roughness buffer unless `look_edge_depth_only`. Surfaces tag themselves via ROUGHNESS = `edge_tag` (1 on world, 0 on characters/placeholders).
- `toon.gdshader` (characters, props, `ToonMaterials.environment`):
  - Own: `albedo`, `albedo_tex`, `use_albedo_tex`, `detail_tex`, `use_detail_tex`, `use_texel_swatch`, `texel_swatch_fade` (vec2), `detail_strength`, `detail_sharp`, `detail_cut`, `ink`, `flash_color`, `flash_amount`, `damage_tex`, `damage_skin_tex`, `damage_scuff_tex`, `blood_edge`, `damage_scale`, `marks`, `use_rest_custom`, `edge_tag`.
  - Includes `toon_light.gdshaderinc`: `band_1` (.25), `band_2` (.62), `band_soft`, `mid_level`, `shadow_level`, `shadow_tint`, `shadow_tint_amount`, `spec_cut`, `spec_strength`, `spec_gloss`, `fill_strength`, `fill_dir`, `rim_cut`, `rim_power`, `rim_strength`, `halftone_strength`, `halftone_cell_px`, `glint_cut`, `glint_strength`.
  - Lighting is the custom `light()` (79-121): bands, tinted shadow, hard spec, camera-fixed fill (`LIGHT_IS_DIRECTIONAL && fill_strength > 0`), rim. `ambient_light_disabled`.
- `trim.gdshader` / `trim_scissor.gdshader` + `trim_body.gdshaderinc` (the environment's trim sheet, one shared material for all kit modules): `albedo`, `trim_tex` (sheet), `tile_m`, `strips[16]` (vec4: row top, height, period m, flags), `ground_tex`, `ground_m`, `ground_on`, `ink_soft` (vec3), `ink_fade` (vec2), `ink`, `ink_cut`, `lod_cap`, `scissor_cut`, `edge_tag`, `debug_view` (0-4: strip index, mip level, ink mask, alpha), plus the same toon_light uniforms.
  - Faces carry UVs in metres and the strip row in `COLOR.a`; sheet RGB is surface, sheet alpha is the ink mask.
  - `trim_scissor` exists only because alpha scissor kills the depth prepass (cost).
- `toon_outline.gdshader` (inverted hull, `cull_front`, unshaded, `fog_disabled`, set on `material_overlay` or `next_pass`): `ink`, `width_px` (0-16, 3.75), `near_m` (1), `far_m` (12), `fp_scale`, `lens_fade_m`, `mode` (0 normal, 1 box, 2 cylinder, 3 sphere, 4 skinned-art baked normal in `COLOR`/`CUSTOM1`).
  - Width formula (lines 58-66): `width_m = width_px * fp_scale * 2 * clamp(dist, near_m, far_m) / (1080 * abs(PROJECTION_MATRIX[1][1])) * fade`. So it is constant in pixels at a 1080-line reference, independent of window size and FOV. It is 0 in orthographic passes (shadows). The CPU mirror is `ToonMaterials.outline_width_m()` (`toon_materials.gd:292`).
- Others: `hit_flash.gdshader` (contact flash: `flash_point`, `flash_radius`, `flash_core`, `flash_strength`, `flash_color`, `flash_max_share`), `impact_frame.gdshader` (canvas_item: `threshold`, `local_mix`, `blur_lod`, `ink`, `paper`; reads the screen texture), `game/level/grid.gdshader` (floor grid, includes toon_light).

### ToonMaterials (`game/fx/toon_materials.gd`, `class_name ToonMaterials`, all static)
- Factories: `character(color, takes_marks, glossy)` (69), `art(atlas, detail, sharp)` (87), `art_prop` (109), `outline(first_person)` (123), `outline_for_part` (130), `prop(color)` (144), `outline_for_prop()` (153), `environment(color, hulled)` (160), `grid()` (172), `trim()` (184, a static singleton `_trim`), `trim_scissor()` (193).
- `apply_look(material)` (214) copies Tuning to uniforms. Every material is tracked weakly (`_live`, `_track` 468) and re-applied on `Tuning.changed` for properties beginning `look_`, `ground_`, or `kit_trim_m_per_tile` (`_on_tuning_changed`, 480-492).
- Assignment:
  - Environment (kit modules): `RoomKit.box_mesh` (`room_kit.gd:214-227`) puts `KitMesh.build(art,size)` on `ToonMaterials.trim()` (via `kit_mesh.gd:329-336`); the prop overlay is a hull from `LevelBlock._overlay` (`level_block.gd:157-162`). Plain boxes use `ToonMaterials.environment(color)` (`RoomKit.flat_material`, 230); the floor uses `ToonMaterials.grid()` (`level_block.gd:151`). `PropSpot` uses `ToonMaterials.environment(color, hull)` (`prop_spot.gd:89`).
  - Characters: `RigPaint` (`game/actors/rig_paint.gd:44, 63, 71, 77`) uses `ToonMaterials.character` (primitives) or `ToonMaterials.art` (skinned GLB). In `skinned_art.gd:85-96` each art `MeshInstance3D` gets `material_override = material`, `material_overlay = outline`, joins group `HumanoidRig.ART_GROUP` ("rig_art", `humanoid_rig.gd:117`) and gets meta `fp_hidden` for head/arm parts.

### How a video-only script can override looks at runtime (no game/ edits)
1. Tuning: `Tuning.set_value(&"look_...", v)` live-updates the whole game (toon, hull, edges, grade, sun, AA). This is the cleanest route.
2. Uniforms on shared materials: `ToonMaterials.trim().set_shader_parameter(...)` / `ToonMaterials.trim_scissor()` change the whole environment in one call. Re-apply after any later `Tuning.changed` for `look_*`, `ground_*` or `kit_trim_m_per_tile`, which re-run `apply_look` and overwrite the keys it sets (band_*, mid_level, shadow_*, spec_*, rim_*, fill_*, halftone_*, tile_m, ink_cut, lod_cap, ground_*, ink_soft, ink_fade, glint, detail, texel_swatch). Uniforms that `apply_look` does not write, such as `albedo`, `ink`, `trim_tex`, `scissor_cut`, `debug_view` and any new one, are stable. `ink` is set once at creation from `HudStyle.INK`.
3. Shader swap: `ToonMaterials.trim().shader = my_shader` (a copy of trim.gdshader with the same uniform names). Safe because the material is a singleton. Characters: iterate `get_tree().get_nodes_in_group(&"rig_art")` and replace `material_override`/`material_overlay` (hull on `material_overlay`; the contact flash lives on `next_pass`).
4. Post: `LookPost.edge_material().set_shader_parameter(...)` (note `_apply_edges` rewrites its known uniforms on any `look_*` change); `LookPost.edge_quad().visible = false` hides lines (this is what `look_edges_enabled = false` does); or add your own full-screen quad / `CanvasLayer` / `WorldEnvironment` tweaks (`LookPost.find_environment(level)` or `level.get_node("WorldEnvironment").environment`: set `glow_enabled`, `adjustment_brightness`/`contrast`/`saturation`, `fog_*`, etc.).
5. Grade LUT: `tools/gen_lut.gd` writes `assets/export/look/grade_lut.png` (checked: 1024x32, i.e. N=32, 32 slices of 32x32). Recipe is `assets/source/look/grade.json` (name "street_dusk", size 32). Format: a strip of N slices of N x N pixels, RGB8, slice index = blue node, x = red node, y = green node (`gen_lut.gd:8-10, 24-25`; `LookPost` doc lines 6-9, 36-39). Node value is `node_value(i,n)` = 0 for i=0, 1 for i=n-1, else `(i+.5)/n`. `LookPost._read_lut()` (214-235) slices it into an `ImageTexture3D` (`_build_lut_texture`, 280-290) assigned to `Environment.adjustment_color_correction` (applied after tonemap, sRGB), blended with the identity by `look_grade_strength` (the texture is rebuilt when strength changes). A video script can build its own `ImageTexture3D` the same way and assign it to the Environment after LookPost (and re-assign after any `look_*` change), or set `look_grade_enabled = false` and apply its own grade (shader/compositor). There is no LookPost API to load a different LUT path (`LUT_PATH` is a const): NEEDS-game only if you want it through LookPost; the workaround is assigning the texture yourself.

---------------------------------------------------------------------------
## 3. HUD AND OVERLAYS

- HUD scene: `game/ui/hud.tscn` is a `CanvasLayer` (layer 10, `process_mode = 3`) with script `GameHud` (`hud.gd:1`, `class_name GameHud`), added by `RoomKit.build_presentation` as a child of the level root, node name "Hud". NO group. Find it with `level.get_node("Hud")`, `find_children("*","GameHud",true,false)`, or the bots' duck-typing (`has_method("set_debug_draw_enabled")`, `combo_bot.gd:551-556`).
- Children (hud.tscn): `DebugDraw` (instanced `debug_draw.tscn`), `HurtOverlay` (vignette strokes), `EnemyHealthBars`, `CenterDot`, `PlayerHealthPanel` (bottom-left), `BossHealthBar` (hidden until the boss exists), `CombatLog` (right, visible by default), `CameraToast` (hidden until a camera change), `HelpOverlay` (visible at start; auto-hides after `help_startup_seconds` = 8, `hud.gd:22`), `BlockCallout`, `RearWarning`, `GrabPrompt`, `PickupCue`, `PauseOverlay`; plus `GoCue` created in `_ready` (`hud.gd:52-54`, var `go_cue`).
- `GameHud` API: `set_help_visible(bool)` (135), `toggle_help()`, `set_combat_log_visible(bool)` (120), `is_combat_log_visible()`, `show_boss`/`hide_boss` (110-117), `set_debug_draw_enabled(bool)` (141). The camera toast is driven by `camera_changed` (`hud.gd:202`), so switching camera modes pops the toast.
- Cleanest hide-all: `hud.visible = false` (`CanvasLayer.visible` hides every child, incl. go_cue, hurt vignette, bars, toast, log, help, pause overlay). Alternative: `hud.layer = -100` (don't). Also set `Tuning.show_center_dot = false` if the HUD is kept.
- Not inside the HUD (hide separately):
  - `VfxDirector` has two CanvasLayers: `SpeedLinesLayer` (layer 5) and `ImpactFrameLayer` (layer 20) (`vfx_director.gd:45-46, 98-112`). These are gameplay effects, not UI; control through Tuning (section 7).
  - `TuningOverlay` (`game/ui/tuning_overlay.tscn`, `class_name TuningOverlay`) is built by `build_presentation`; its panel (F1) and cheats (F4) live in a separate `Window` and start hidden (`tuning_overlay.gd:63-80`). Nothing to do unless an input event opens it. It freezes the player while open (`_freeze_player`, 220).
  - `CombatDebugDraw`: `enabled = false` by default (`debug_draw.gd:36`), draws on render layer `VIS_DEBUG` (3) (`debug_draw.gd:128, 464`) and joins group `debug_draw` (107). The free-fly cull mask shows layer 3; the first-person camera does not exclude it. Keep it disabled.
  - Bot captions: `ComboBot._build_caption` (`combo_bot.gd:643-651`) makes a `CanvasLayer` (layer 50) with Label `caption` as children of the bot node itself (not the room). `bot.caption.text = title` is set per act (`crowd_bot.gd:~197`). Hide with `bot.caption.get_parent().visible = false` (or `bot.caption.visible = false`). The combo/crowd `_run` also calls `set_help_visible(false)` and `set_combat_log_visible(false)` on every room child that has those methods.
- GameInput: `GameInput.paused`, `GameInput.menu_open` (`game_input.gd:53, 59`); `Input.mouse_mode` is set CAPTURED (`game_input.gd:69, 125-138`). Irrelevant with scripted input.

---------------------------------------------------------------------------
## 4. BOT HARNESS

### Class chain and discovery
- NONE of the bots has a `class_name` (grep over `tests/bot/*.gd` and `level_acts/*`: no matches). They chain by path-based extends:
  - `crowd_bot.gd:1` `extends "res://tests/bot/combo_bot.gd"` (combo_bot is `extends Node`, `combo_bot.gd:1`).
  - `level_bot.gd:1` `extends "res://tests/bot/crowd_bot.gd"`.
  - Scenes: `tests/bot/crowd_bot.tscn` and `level_bot.tscn` are a bare `Node` with the script.
- So a script under `video/` CAN do `extends "res://tests/bot/level_bot.gd"` (or crowd_bot.gd) and a `video/xxx_bot.tscn` can attach it. No edit to tests/ is needed. (`preload("res://tests/bot/level_bot.gd")` works as well.)
- Act format: `static func acts(bot: Node) -> Array[Dictionary]` returning `{title: String, cam: StringName, fn: Callable (awaitable), probe: bool (optional), tags: Dictionary (optional)}`. See `arc_acts.gd:36-42`, `tour_acts.gd:40`, `run_acts.gd:13-18`. Act files are `extends RefCounted`, names ending `_acts.gd`, loaded in file-name order. Acts are chosen with `--act=<text>` (case-insensitive substring of the title; `a|b` for several, `combo_bot.gd:141-146`).
- Discovery directories are hardcoded constants:
  - crowd: `ACTS_DIR := "res://tests/bot/acts"` (`crowd_bot.gd:34`), read in `_collect_acts()` (`crowd_bot.gd:~364-380`).
  - level: `LEVEL_ACTS_DIR := "res://tests/bot/level_acts"` (`level_bot.gd:~21`), `_collect_acts()` overridden at `level_bot.gd:~141-158`. A level act dir only, the crowd acts do not run in a level.
- CRUCIAL answer: the acts dir does NOT have to be under tests/bot. A subclass in video/ can override `func _collect_acts() -> Array[Dictionary]` (a plain overridable method) to read `res://video/acts/*_acts.gd` (with `script.call(&"acts", self)`), without touching tests/. GDScript will not allow redeclaring the constants `ACTS_DIR`/`LEVEL_ACTS_DIR` in the subclass, so define a new const name (e.g. `VIDEO_ACTS_DIR`). An act file anywhere (e.g. `video/acts/trailer_acts.gd`) is just a RefCounted script with `static func acts(bot)`; it can also `preload` helper statics from tests/ (read-only reuse is fine).
- The base `_run` (`crowd_bot.gd:~104-170`) is monolithic. In order it:
  1. waits 8 ticks;
  2. reads `--seed=`;
  3. sets `player = room.player`, `player.input.scripted = true`, `spawner = room.spawner`, `director` = camera_director group;
  4. hides help and combat log on room children;
  5. `_connect_logs()`;
  6. builds `Probe` (readability_probe.gd, heavy) and `Pilot` (autopilot.gd) and attaches them;
  7. loops `_collect_acts()`: for each, `await _reset(act.cam)`, `caption.text = title`, `await act.fn.call()`, `_wait_idle()`, 45 ticks;
  8. `probe.finish()`, `_quit()`.
  Overriding `_run` wholesale is possible (copy the pieces) if you want to drop the probe and pilot (memory and CPU).

### Helper API (available on `bot` inside an act)
From `combo_bot.gd`:
- `_press(button, hold=2, gap=0)` (612): `player.input.push_press`, then waits until the queue is empty. Buttons are `&"P"` punch, `&"K"` kick, `&"RB"` back_attack, `&"JUMP"`, `&"DODGE"` (B: block/dodge), `&"GRAB"` (LB), `&"TURN"` (`player_input.gd:8-16`).
- `_ticks(n)` (619), `_wait_until(cond: Callable, max_ticks=400)` (624), `_wait_idle()` (631), `_turn_by(deg, ticks)` (559), `_look_to(pitch_deg, ticks)` (570, pitch only), `_hud()` (551), `player.input.scripted_move = Vector2(x, y)` (x right, y forward), `player.input.push_wait/push_down/push_up/clear_queue/queued()` (`player_input.gd:63-103`).
- Direct placement (as tour_acts does): `player.global_position = v; player.velocity = Vector3.ZERO; player.rotation.y = yaw; player.look_yaw = yaw; player.look_pitch = pitch_rad` (`tour_acts.gd:76-82`; pitch limit +-85 deg).
From `crowd_bot.gd`:
- `spawn(id, rel: Vector2 (x right, y ahead, m), face_player=true) -> EnemyActor` (~232).
- `spawn_at_point(id, index)` (crowd room points only), `surround(count, gap, id)`, `keep_alive(count, id)`.
- `god(on)` (sets `Tuning.god_mode`), `tune(prop, value)` (per-act, auto-reverted by `_reset`), `freeze_ai(on)` (`Tuning.ai_frozen`), `set_waves(on)`, `clear_enemies()` (`EncounterSpawner.remove_enemies(tree, true)`), `fight(ticks, held_back)`, `hold_back()`, `pilot` (autopilot: `.enabled`, knobs in `PILOT_KNOBS`), `log_line(text)`.
From `level_bot.gd`:
- `level` (LevelRoot), `walk_to(point, tol, budget, until)`, `walk_route(arena_idx)`, `run_arena(held_back, measured)`, `run_level(from, to, held_back, measured)`, `knock_off(from)`, `first_hazard(from)`, `_steer`, `_route_start`, `hazard_kos`.
- Exports to tune the walk: `walk_turn_deg_per_s`, `walk_forward_within_deg`, `route_reach_m`, `go_pause_s`, `finish_pause_s`, `arena_budget_s`, etc.

### `_reset` and seeding
- `LevelBot._reset(cam)` (`level_bot.gd:~161-197`): clear enemies, pilot off, restore pilot knobs, waves off, `ai_frozen` false, revert `_tuned` values, `god_mode` false, clear floor pipes, `spawner._serials = _fresh_serials()`, `spawner._rng.seed = spawner.rng_seed`, `level.director.rng_seed = level.rng_seed`, clear input, `level.start_at_arena(from_arena)`, `_route_start`, reset GO cue, cycle camera until `director.mode == cam`, wait 2 ticks. (Crowd version: `crowd_bot.gd:~172-203`, with `spawner.start_at_wave(1)`.)
  - So between acts everything starts from the same state. An act can use any `cam` in `CameraDirector.MODES`: `&"first_person"`, `&"side_view"`, `&"free_fly"`.
- Seeding: `LevelRoot.rng_seed` (export, default 0) seeds the spawner (`encounter_spawner.gd:97`) and the EnemyDirector (`enemy_director.gd:43-47`). Every `EnemyActor` seeds its own `_rng` from `hash(String(name))` at `_ready` (`enemy_actor.gd:163`); the name is the serial "Punk1", so `_fresh_serials()`/`--seed=N` (`_name_offset = 7*N`) change enemy choices. `TrainingDummy` likewise (`training_dummy.gd:79`). `AudioDirector` per-actor voices use `hash(str(actor.name))` (`audio_director.gd:660-661`).
- Arguments after `--` (read from `OS.get_cmdline_user_args()`):
  - `--act=` (combo_bot), `--tune=<prop>=<number>` (combo_bot.gd:30-37, sets `Tuning.data` directly), `--seed=` (crowd), `--probe-out=<dir>`.
  - `--level=<res://...>` (LevelRoot scene or lone LevelSection scene; default `tests/fixtures/level_strip.tscn`), `--from=<arena idx>`, `--to=<arena idx, -1 last>`, `--presentation=<0|1>` (0 builds no camera/HUD/VFX/audio: all parsed in `level_bot._room_scene`, ~91-127). The scene is re-packed after setting `with_presentation`.
  - For the full game: `--level=res://game/level/mission1/mission1.tscn`.

### tools/record_acts.sh and capture_bot.sh
- `tools/record_acts.sh <out dir> "<slug>|<act title>" ...`:
  - Runs `tools/capture_bot.sh "${BOT_SCENE:-res://tests/bot/crowd_bot.tscn}" "$out/$slug" "$title" 6` per act (one Godot process per act), then `tools/look_sheets.sh` for LOOK-MARK acts, else ffmpeg overview tiles (`SHEET_FPS`, default 2).
  - `BOT_SCENE=res://video/trailer_bot.tscn tools/record_acts.sh ...` works for any scene path. `CAPTURE_ARGS="--level=... --from=N --to=M"` is forwarded after `--act=`.
  - Prints `slug exit=.. errors=..` counting `SCRIPT ERROR|SHADER ERROR|^ERROR` in bot.log.
- `tools/capture_bot.sh <res:// scene> <outdir> [act filter] [stills fps]`:
  - Machine-wide slot lock (default `CAPTURE_SLOTS=2`, dir `~/.cache/beat-em-up-capture`).
  - Runs `godot --path ROOT --write-movie OUT/bot.avi --fixed-fps 60 --resolution 1280x720 --quit-after ${CAPTURE_MAX_FRAMES:-54000} SCENE -- --act=FILTER <CAPTURE_ARGS>`; output goes to `bot.log`.
  - Hardcoded: `.avi` file name and 1280x720 resolution (no knobs besides editing the script; copy it to `tools/video/` for a PNG-sequence or a bigger resolution run, e.g. `--write-movie x.png`). The `GODOT` env var picks the binary.
  - Bot quits itself via `_quit()` (`crowd_bot.gd:~173-185`), which stops all audio players and delays 150 ms for the audio drain.
  - `.gdignore` is dropped in the out dir.

---------------------------------------------------------------------------
## 5. CAMERAS

### CameraDirector (`game/camera/camera_director.gd`, `class_name CameraDirector`, Node3D, group `camera_director`, line 33; scene `camera_director.tscn`)
- Built as a child of the room by `build_presentation` (name "CameraDirector"). Find via `get_tree().get_first_node_in_group(&"camera_director")`.
- Modes: `MODE_FIRST_PERSON`, `MODE_SIDE_VIEW`, `MODE_FREE_FLY` (`&"first_person"`, `&"side_view"`, `&"free_fly"`; lines 12-15). Vars `mode` (setter `set_mode`), `player`, `first_person_camera`, `side_view_camera`, `free_fly_camera` (members, always present and children). Signal `camera_changed(mode)`.
- API: `set_mode(m)` (switches `make_current()`; for free_fly it calls `free_fly_camera.activate_from(previous)`), `cycle()`, `active_camera()`, `add_trauma(amount)`, `refresh_player()`. Input action `camera_cycle` (F2). `PROCESS_PRIORITY = 50` (cameras also 50).

### FreeFlyCamera (`game/camera/free_fly_camera.gd`, `class_name FreeFlyCamera`, Camera3D, `top_level = true`)
- `activate_from(source: Camera3D)` (45): copies `fov`, `keep_aspect` and `global_transform` from source, derives `_yaw/_pitch`. `fly_speed` export.
- `update_camera` (56) runs every `_process` (only moves while `current`); `fly(delta, move: Vector3, look_pixels: Vector2)` (73) is public. `_yaw`/`_pitch` are private.
- Programmatic placement: just set `free_fly_camera.global_transform = Transform3D(...)` (and `.fov`) each frame after `set_mode(MODE_FREE_FLY)`. With zero keyboard/mouse input `fly()` neither changes the basis nor moves it (`velocity = 0`), and the director only copies on activation, so a direct transform set persists. Re-set it every frame (or `_process` with higher priority number than 50) to animate. Mouse look would otherwise reset the basis from private `_yaw/_pitch`; there is NO public yaw/pitch setter (NOT present), so don't call `fly()` with look input mixed with direct sets.
- Alternative: your own `Camera3D` + `make_current()` works (VfxDirector/ComicSprite/HUD use `get_viewport().get_camera_3d()`).
- Cull mask: free fly keeps the default (all layers: the doc says "shows every render layer", line 6); the FPS lens excludes layer 2.

### FirstPersonCamera (`game/camera/first_person_camera.gd`, `class_name FirstPersonCamera`, Camera3D)
- `top_level = true`, `keep_aspect = KEEP_WIDTH` (so `fov` is HORIZONTAL), `near = 0.05`, cull mask has `VIS_FP_HIDDEN` (layer 2) cleared (`_init` 141-153).
- FOV source: `fov = Tuning.data.fov_deg` rewritten EVERY `update_camera` (line 197; and `_init`, `_ready`). `fov_deg` range 75-110, default 90 (`tuning_data.gd:610`). Override only through `Tuning.set_value(&"fov_deg", v)`; setting `camera.fov` directly is overwritten on the next `_process`.
- Placement: rides the player's `EyePoint` (`player.get_eye_transform()`, `player.gd:229`, from `rig.get_point_transform(&"EyePoint")`) with damped offset (`cam_smoothing_s`), the bob clamp, plus camera-move offset/view-yaw. The transform is built in `update_camera`: `global_transform = _view * _effects_transform()` (`first_person_camera.gd:196-203`).
- Shake: public `trauma` (0..1), `add_trauma(amount)` (221), `add_punch(Vector2 deg)`, `add_roll(deg)`, `is_settled()`. Shake export vars `shake_max_deg` (3.0), `shake_max_offset_m` (0.04), `shake_frequency_hz` (15), `trauma_decay_per_s` (1.5), `punch_duration_s`, `punch_attack_share`, `blocked_feel_scale`. The strength is `trauma^2 * Tuning.screen_shake_intensity` (`_effects_transform`, 733-748). Hit tuning: `Tuning.shake_light/heavy/finisher` (0.1/0.25/0.5), `hurt_shake_mult` (2.5), `hurt_shake_min` (0.3). Kill all shake with `screen_shake_intensity = 0`, but punch/roll still apply (`hurt_feel_enabled = false` disables the hit-on-player punch/roll/shake).
- KO view: from killing blow, the lens eases out to a point above and beside the lying body (`ko_view_*` tunables); `ko_view_weight()` (215), `view_transform()` (208, the un-shaken view).
- Uses `player.get_global_transform_interpolated()` with `Engine.get_physics_interpolation_fraction()`, and `physics_interpolation_mode = OFF` on the camera; project physics interpolation is NOT enabled (no `physics_interpolation` key in project.godot), so the view moves in 60 Hz steps (fine in Movie Maker at 60 fps).
- SideViewCamera (`side_view_camera.gd`): `view_fov_deg` export 38 (line 11), `player`.

### First-person arms/fists
- There is NO viewmodel, NO SubViewport, NO second camera. The player's full-body `HumanoidRig` (`player.gd:143-160` `first_person_body = true`, loose arms, wrapped hands) is rendered by the same camera that rides its eyes ("the full body renders in first person", `first_person_camera.gd:19-20`).
- Head/neck/shoulder meshes go on `VIS_FP_HIDDEN` (layer 2) (`humanoid_rig.gd:1306-1314`, `skinned_art.gd:21-27, 95`), which the FP camera never draws (they still cast shadows). The upper arm (`__fp_arm` mesh suffix) is lifted onto the default layer by `FirstPersonCamera._update_arm` (483-497) for moves with `MoveData.fp_show_upper_arm` (haymaker, uppercut) when `Tuning.look_near_arm` is on; torso (`__fp_torso`) is hidden only if `fp_knockdown_hide_torso`.
- The hull for the FP body uses `fp_scale` (`look_outline_fp_scale` = 0.8) via `ToonMaterials.outline(first_person)`.

### Layers
- Render layers (`project.godot` layer names, `combat_types.gd:78-81`): 1 `default` (everything: characters, world, comic sprites, EdgeQuad), 2 `fp_hidden` (player head/neck/shoulder, `VIS_FP_HIDDEN`), 3 `debug` (debug draw only, `VIS_DEBUG`). No separate layer for arms, VFX or environment.
- Physics layers (1-9): world, player_body, enemy_body, hurtbox, pickup, downed_body, projectile, ragdoll, edge_guard (`combat_types.gd:60-75`). `EdgeGuard` is an invisible collider.
- VFX: comic effects are `ComicSprite` = `Sprite3D` children of `VfxDirector` (`comic_sprite.gd:2`); some are `no_depth_test`/`shaded` flags. Speed lines and impact frame are 2D (CanvasLayer 5 and 20).

---------------------------------------------------------------------------
## 6. ENEMIES AND PLAYER

### Spawning
- `EnemyCatalog` (`game/enemies/enemy_catalog.gd`, `class_name`, static): `ENTRIES` (11-20):
  - `&"dummy"` (`enemies/dummy/training_dummy.tscn`)
  - `&"punk"` (`punk/street_punk.tscn`)
  - `&"punk_veteran"` (same scene + `variants/punk_veteran.tres`)
  - `&"kicker"` (`kicker/kicker.tscn`)
  - `&"thug"` (`thug/pipe_thug.tscn`, the Pipe Thug)
  - `&"bruiser"` (`bruiser/bruiser.tscn`)
  - `&"boss"` (`boss/boss.tscn`, Ox Pellerin, class `Boss extends EnemyActor`, group `boss`, `boss.gd:82`).
  - API: `available()`, `scene(id)`, `variant(id)`, `apply_variant(enemy, id)`, `body_size(id)`.
- `EncounterSpawner` (`game/level/encounter_spawner.gd`, class_name, group `encounter_spawner`; `level.spawner`):
  - `static make_enemy(scene, id, serials: Dictionary) -> EnemyActor` (107): names it "Punk3", sets `display_name`, applies the variant (the boss keeps "Ox Pellerin").
  - `spawn_enemy(id, at: Vector3, yaw: float, from_wave=false, lane_point=Vector3.INF) -> EnemyActor` (132): adds it to the room, places it, calls `enter_from(at, lane_point or at)`.
  - Also `spawn_adds`, `set_waves_enabled(on)`, `play_table`, `start_at_wave(n)`, `stop()`, `alive_count()`, `wave_running()`, `static remove_enemies(tree, all)`/`remove_enemy`, `scene_override` Dictionary, signals `wave_started(number, ids)`, `wave_cleared`, `table_finished`.
- F4 cheat menu `CheatMenu.spawn_enemy(id)` (`cheat_menu.gd:~236-265`) spawns at the crosshair using the same spawner. It lives in the F4 Window (not a scene you instantiate separately).
- From a video script: `level.spawner.spawn_enemy(&"boss", pos, yaw)` (yaw = `atan2(-dx, -dz)` toward the player, like `crowd_bot.spawn`, ~232-240). For the boss, the arena table `["boss"]` handles it in a7; the boss bar auto-appears (`hud._follow_boss`, 156).

### Freeze / pose / face
- Freeze all AI: `Tuning.set_value(&"ai_frozen", true)` (`tuning_data.gd:1648`; read at `enemy_actor.gd:252, 544`). Enemies stand where they are and do not attack, but still take hits and animate reactions.
- Placement: set `enemy.global_position` and `enemy.rotation.y = yaw` (the spawner does exactly this, `encounter_spawner.gd:~140-143`). `enemy.look_yaw` is player-only. Facing by AI (`_face`, 1266) is off while frozen.
- Pose/animation: `enemy.rig.play(anim: StringName, blend_s=0.08, speed=1.0)` (`humanoid_rig.gd:240`), `rig.play_move(MoveData)` (274), `play_locomotion`, `advance(dt)` (338). Clip names live in `placeholder_anims.gd` (`idle`, `walk_forward`, `taunt`, `brace`...). `enemy.force_attack(index)` (`enemy_actor.gd:370`) starts an attack. `enemy.abort_move()` (`combat_actor.gd:549`), `reset_state()` (557), `receive_hit(HitInfo)` (413; the level bot builds a `HitInfo` by hand in `knock_off`, `level_bot.gd:~470-482`: attacker, victim, damage, tier, reaction, direction, knockback, contact_point).
- ShowcaseRunner (`game/debug/showcase_runner.gd`) plays scripted rig steps on a Punk taken off its tick; used by F4 and `look_acts.gd`.
- Per-enemy AI state: `enemy.ai_state` (enum `AiState`, `enemy_actor.gd:54`), `has_token`, `archetype`, `heavy`.
- Director: `EnemyDirector` (group `enemy_director`, `level.director`) hands out attack tokens/slots (`rng_seed`, line 43). Ignored when `ai_frozen`.

### Player
- `PlayerCharacter` (`game/player/player.gd`, `class_name`, group `player`; scene `player.tscn` with `art = player_art.tres`). Art: `player_art.tres` metadata `scene_path = assets/export/characters/player/player.glb`, `detail_mask_path = .../player_detail.png` (`worn_art`, `player.gd:162-187`; debug probe art via `look_player_art_probe`).
- The rig body is always present and built with `first_person_body = true`: head/neck/shoulder pieces on layer 2 (hidden from the FP lens). So the full body exists as a normal mesh; the KO view (see section 5) simply moves the same lens outside it and unhides the head by clearing the cull bit while out (`first_person_camera.gd:378-430`). The side and free-fly cameras show the whole body incl. the head.
- Scripted control: `player.input.scripted = true`, `push_press/hold/wait`, `scripted_move`; `look_yaw`, `look_pitch` (rad); `player.state`, `player.health`, `auto_revive`, `reset_state()`.

---------------------------------------------------------------------------
## 7. EVENTS, RNG, TIME, COMIC FX

### CombatEvents (autoload, `game/autoload/combat_events.gd`) signals
- `attack_started(attacker, move: MoveData, chain_step: int, input_timing: StringName)` (5)
- `attack_whiffed(attacker, move)` (6)
- `hit_landed(hit: HitInfo)` (7)
- `windup_started(attacker, move)` (8), `windup_ended(attacker, interrupted: bool)` (9)
- `knocked_down(victim, hit)` (10), `got_up(actor)` (11), `ko(victim, hit)` (12)
- `vanished(actor)` (15), `revived(actor)` (17)
- `health_changed(actor, health, max_health)` (18), `actor_state_changed(actor, old_state: int, new_state: int)` (19)
- `grabbed(holder, victim)` (20), `released(holder, victim)` (21), `grab_escaped(victim, holder)` (23), `thrown(holder, victim)` (24)
- `weapon_picked_up(actor, weapon)` (25), `weapon_thrown(actor, weapon)` (26), `weapon_broke(actor, weapon)` (27), `weapon_landed(weapon)` (59)
- `dodged(actor, direction: Vector3)` (28), `jumped(actor)` (29), `landed(actor)` (30), `quick_turned(actor)` (31)
- `block_started(actor)` (32), `block_ended(actor)` (33)
- `blocked(defender, hit)` (35), `perfect_blocked(defender, hit)` (36), `guard_broken(defender, hit)` (37), `guard_changed(actor, guard, max_guard)` (38)
- `boss_phase_changed(boss, phase: int)` (41)
- `arena_locked(arena)` (43), `arena_cleared(arena)` (45), `level_cleared(level)` (47)
- `hazard_ko(actor, hazard)` (49), `section_entered(section)` (53), `barrier_moving(barrier, closing: bool)` (56).

### RNG
- `VfxDirector`: `var rng: RandomNumberGenerator = RandomNumberGenerator.new()` (`vfx_director.gd:65`, public), `rng.randomize()` at `_init` (line 95). It shares the same object with `speed_lines.rng` (line 101), so `vfx.rng.seed = N` seeds both. Reach it via `get_tree().get_first_node_in_group(&"vfx_director")` (`GROUP`, line 43; added in `_init`, line 91) or `level.get_node("VfxDirector")`. Used for the word pick, burst variants, blood splats, jitter, chance rolls, speed-line phase.
- `AudioDirector`: `var rng` (`audio_director.gd:128`, public), `rng.randomize()` at `_ready` (173). Group `audio_director` (172) and node name "AudioDirector". Used for `SfxBank.pick(pool, rng)`. Per-actor voice RNGs are seeded by actor name (660-661).
- `HurtOverlay` seeds a local rng from `_seed` (not an autoload concern).
- The rest are already deterministic: `EnemyActor._rng` (by name), `EnemyDirector._rng` (`rng_seed`), `EncounterSpawner._rng` (`rng_seed`), `Boss` rolls from `_rng`.
- Determinism fix without game/ edits: after the room's `_ready`, set `vfx.rng.seed = <const>` and `audio.rng.seed = <const>` (re-set it per act/shot).

### TimeController (autoload, `game/autoload/time_controller.gd`)
- `debug_scale: float` (line 10; global sim multiplier, also stretches hitstop/slow-mo), `hitstop(actors: Array, duration_s)` (25), `slowmo(scale, duration_s, delay_s=0.0)` (45), `is_slowmo()` (66), `sim_scale()` (71), `scale_for(actor)` (76), `clear()` (82), `is_in_hitstop(actor)` (55).
- `Engine.time_scale` stays 1.0 (header doc line 5). Actors scale their own step via `scale_for`. A video slow-mo is `TimeController.slowmo(0.3, seconds)` or `TimeController.debug_scale = 0.25`. Tuning knobs: `slowmo_scale` 0.3 / `slowmo_ms` 250 (finisher), `hitstop_light/heavy/finisher_ms` 50/85/140.
- Hit reactions: presentation reads sim time via `TimeController.sim_scale()` (e.g. `vfx_director.advance`, 138-140), so comic FX slow with it.

### Comic words / starbursts / impact frame / speed lines (turning them off)
- Words: `Tuning.vfx_word_chance_light` (0.0), `_heavy` (1.0), `_finisher` (1.0) (`tuning_data.gd:333-335`); set all to 0 and no word spawns (`vfx_director.gd:392`). No single "off" flag.
- Starbursts: no on/off tunable. Options: `vfx_scale = 0.0` (multiplies EVERY comic effect size: bursts, words, blood, splats, sparks; `vfx_director.gd:387`; range 0-3), or `vfx_burst_small_m/medium_m/large_m = 0`, or `vfx_director.visible = false` (all ComicSprites are its children; this does not hide the CanvasLayer effects). `_chance` makes `vfx_word_chance` the only RNG there.
- Block sparks: `vfx_block_spark_m`, `vfx_parry_spark_m`, `vfx_guard_break_m`. Blood: `vfx_blood_chance_heavy/finisher`, `vfx_blood_drops_*`. Damage looks: `vfx_bruised_at`, `vfx_bloodied_at`.
- Impact frame (`game/fx/impact_frame.gd`, `ColorRect` in `ImpactFrameLayer`, layer 20): `Tuning.impact_frame_enabled` (`tuning_data.gd:181`, the photosensitivity toggle) and `vfx_impact_frame_frames` (2); `vfx_director.gd:401` requires both. It only fires on a FINISHER hit.
- Speed lines (`game/fx/speed_lines.gd`, `class_name SpeedLines`, own CanvasLayer 5): fired by finishers (`vfx_director.gd:398`) and lunge lines (`_watch_lunge`). Tunables: `vfx_speed_lines_opacity` (0.85), `vfx_lunge_lines_opacity` (0.45), `vfx_speed_lines_s`, `vfx_lunge_lines_s`, `vfx_speed_lines_count`, `vfx_lunge_lines_min_m`. Set the opacities to 0 to kill them; there is no enabled flag.
- Hit flash (screen/contact flash): `hit_flash_*` tunables (`hit_flash_frames`, `hit_flash_radius_m`, `hit_flash_strength`, `hit_flash_core`, `hit_flash_fp_max_share`, `hit_flash_finisher_radius_mult`).

---------------------------------------------------------------------------
## 8. TUNING

- `Tuning` autoload (`game/autoload/tuning.gd`, Node): `var data: TuningData` (61), `signal changed(property: StringName)` (26).
  - `set_value(property, value)` (80): `data.set(...)`, marks preset dirty, emits `changed(property)`. Prefer this for runtime changes so subscribers (ToonMaterials, LookPost, VFX, enemies) react.
  - `apply(new_data)` (88): replaces the whole data object and emits `changed(&"")` (everything re-reads).
  - Presets: `save_preset`, `load_preset`, `apply_preset(dict)`, `list_presets`, `reset_to_default`, `defaults()`; JSON presets in `user://tuning` and `res://tuning` (`default.json` = shipped defaults, `tuning/` dir). Preset format `{"preset","format":2,"tuning":{prop:value},"moves":{id:{field:value}}}`; loading starts from shipped defaults. The "Debug" group is skipped by presets.
  - Writing `Tuning.data.x = v` directly skips `changed`; `--tune=` in the bot does that (before the room exists).
- `TuningData` (`game/autoload/tuning_data.gd`, 1768 lines): `@export_range` vars in groups. All names below are `Tuning.data.<name>`.
  - Camera (609-673): `fov_deg` 90 (75-110), `cam_smoothing_s` .05, `cam_bob_clamp_m` .015, `cam_height_offset_m` -.2, `cam_forward_offset_m` .04, `cam_floor_clearance_m` .13, `screen_shake_intensity` 1.0, `cam_spin_follow_mult` 1.0, `show_center_dot` true; KO view: `ko_view_distance_m` 1.7, `ko_view_height_m` 1.6, `ko_view_pitch_deg` 40, `ko_view_out_s` .8, `ko_view_in_s` .5, `ko_view_look_lead`, `ko_view_clearance_m`, `ko_view_min_reach`, `ko_view_steep_*`.
  - Hit feel (167-205): `hitstop_light_ms/heavy_ms/finisher_ms` 50/85/140, `shake_light/heavy/finisher` .1/.25/.5, `slowmo_scale` .3, `slowmo_ms` 250, `hit_flash_*`, `hurt_shake_mult`, `hurt_shake_min`, `hurt_overlay_*`.
  - VFX (291-445): `vfx_scale`, `vfx_max_view_share` .25, `vfx_min_view_share`, `vfx_min_camera_dist_m`, `vfx_clamp_reach_*_deg`, `vfx_burst_small/medium/large_m` (.24/.36/.62), `vfx_burst_s` .18, `vfx_burst_variants`, `vfx_pop_*`, `vfx_word_chance_light/heavy/finisher`, `vfx_word_small/medium/large_m`, `vfx_word_s`, `vfx_word_lift/side/rise_m/tilt_*`, speed lines (`vfx_speed_lines_*`, `vfx_lunge_lines_*`), `impact_frame_enabled` (181), `vfx_impact_frame_frames/threshold/local_mix/blur_mip`, blood/spit/tooth (`vfx_blood_*`, `vfx_spit_*`, `vfx_tooth_*`, `vfx_gravity`, `vfx_particle_s`), block sparks, damage looks.
  - Section light (1276-1286): `section_light_blend_s` 2.5, `section_fog_sky_affect` .3; Debug: `section_light_enabled` (1717).
  - Look > Toon (1406-1502): `look_mid_level` .72, `look_band_1` .22, `look_band_2` .52, `look_band_soft` 1.2, `look_shadow_level` .42, `look_shadow_tint`, `look_shadow_tint_amount` .45, `look_spec_cut/strength/gloss`, `look_glint_cut/strength`, `look_rim_cut/power/strength`, `look_sun_elevation_deg` 45, `look_sun_yaw_deg` -50, `look_sun_energy` 1.2, `look_sun_shadow_blur` .25, `look_fill_strength` .4, `look_fill_yaw_deg`, `look_fill_pitch_deg`, `look_halftone_env/chars/cell_px/strength`, `look_detail_cut`, `look_texel_swatch_fade_near/far`.
  - Outline (1504-1524): `look_outline_px` 3.75, `look_outline_near_m` .3, `look_outline_far_m` 12, `look_outline_fp_scale` .8, `look_outline_lens_fade_m` .1, `look_hull_on_placeholders`.
  - Edges (1526-1547): `look_edges_enabled`, `look_edge_px` 1.25, `look_edge_depth_threshold`, `look_edge_normal_threshold`, `look_edge_fade_start_m` 25, `look_edge_fade_end_m` 60, `look_edge_mask_px` 6, `look_aa_mode` (0 MSAA4x, 1 FXAA, 2 off).
  - Grade (1549-1557): `look_tonemap` (0 linear, 1 filmic, 2 Reinhard, 3 ACES), `look_grade_enabled` true, `look_grade_strength` 1.0.
  - Trim (1559-1568): `look_trim_ink_cut` .5, `look_trim_lod_cap` 4; Level: `kit_trim_m_per_tile`, `ground_m_per_tile`, `ground_ink_*`, `ground_sheet_off`, `kit_draw_graybox`.
  - FP feel (1570-1595): `fp_knockdown_hide_torso`, `combat_log_hide_while_holding`, `hit_flash_fp_max_share`; Motion (1597-1630): `look_motion_*` (breath, bounce, shift, guard sway, head, stride, hip roll...), `look_motion_polish`, `look_near_arm` (+ `_band_1/_band_2/_mid_level`).
  - Debug (1632-1720): `god_mode`, `hurt_feel_enabled`, `one_hit_ko`, `ai_frozen`, `look_show_art`, `look_punk_art_variant`, `look_player_art_probe`, `look_edge_debug_view/character_mask/depth_only`, `look_texel_swatch`, `prop_art_hull`, `weapon_chain_sim`, `section_light_enabled`, `audio_legacy_bank`, `waves_enabled` (845), `music_enabled` (1376), `rumble_enabled` (1381), `ragdoll_enabled` (457).
- Writing any `look_*` property triggers LookPost/ToonMaterials to re-apply. Changing `fov_deg` works instantly (read every frame).

---------------------------------------------------------------------------
## 9. PROJECT SETTINGS (`project.godot`)

- Main scene `res://game/level/mission1/mission1.tscn`; features `4.7`, `Forward Plus`; renderer `forward_plus`.
- Window: viewport 1920x1080 (`window/size/viewport_*`), override 1600x900, `stretch/mode = canvas_items`, `aspect = expand`. HUD is authored for a 1920x1080 canvas.
- Anti-aliasing: `anti_aliasing/quality/msaa_3d = 2` (4x), but LookPost overwrites the viewport MSAA/FXAA from `look_aa_mode` (default 0 = MSAA 4x; a viewport MSAA change rebuilds buffers). No scaling-3d or TAA/SSAA settings are in the file. `textures/vram_compression/import_etc2_astc = true`.
- Physics: Jolt Physics, `physics_ticks_per_second = 60`, `max_physics_steps_per_frame = 8`. Physics interpolation not enabled. Navigation: `3d/default_cell_height = 0.1`, avoidance threading off, async map iterations off.
- Layer names: 3d_physics 1 world, 2 player_body, 3 enemy_body, 4 hurtbox, 5 pickup, 6 downed_body, 7 projectile, 8 ragdoll, 9 edge_guard; 3d_render 1 default, 2 fp_hidden, 3 debug.
- Autoloads: `Tuning` (`game/autoload/tuning.gd`), `CombatEvents`, `TimeController`, `GameInput`. Editor plugin `res://addons/gut/plugin.cfg`.
- Debug warnings: `untyped_declaration=1`, `unsafe_property_access=1`, `unsafe_method_access=1`.

---------------------------------------------------------------------------
## Gotchas for a video pipeline

NEEDS-game/tests (cannot be done without editing a protected tree):
1. No lamp lights, lamp meshes, glow or emissives exist in the street; "sodium" has to be added entirely by video code. The toon `light()` handles non-directional lights, but all environment materials are shared singletons without an emissive channel.
2. `LookPost` cannot load a different LUT path (`LUT_PATH` is a const, `look_post.gd:~30`); you can still assign your own `ImageTexture3D` to `Environment.adjustment_color_correction` (re-do it after any `look_*` change), or build the LUT from a different recipe via `tools/gen_lut.gd` (that file is under tools/, which you may add to).
3. No public free-fly yaw/pitch setter; set `global_transform` directly. `FirstPersonCamera` re-writes `fov` every frame, so FOV changes must go through `Tuning.fov_deg` (range 75-110, horizontal FOV, `KEEP_WIDTH`).
4. Comic bursts have no on/off tunable (only `vfx_scale = 0` or `vfx_director.visible = false`), speed lines have no enable flag (opacities to 0).
5. The bots' act dirs are hardcoded constants; use a `video/` subclass and override `_collect_acts()` (not an edit of tests/). The base `_run` always builds the readability Probe and the autopilot, so unless you override `_run` that overhead is present in every capture.
6. `capture_bot.sh` has `.avi` and 1280x720 hardcoded; make a copy under `tools/video/` for other formats (PNG sequence for a 1080p/4K master).

Determinism traps:
7. `VfxDirector.rng.randomize()` (`vfx_director.gd:95`) and `AudioDirector.rng.randomize()` (`audio_director.gd:173`) make comic words/bursts/blood/speed-line phase and SFX picks differ every run. Fix: after the room's `_ready` set `vfx.rng.seed = N` and `audio.rng.seed = N` (both public).
8. Enemy random choices come from `hash(name)`; names come from per-archetype serials, so the order and number of spawns changes behaviour. The bot's `_fresh_serials()`/`--seed=` normalises that per act; do the same, and keep `LevelRoot.rng_seed` fixed. `_reset` re-seeds the spawner and director rng only.
9. Use `--fixed-fps 60` (as capture_bot does) so physics ticks and frames agree; `TimeController`/enemy timers are in frames/physics ticks. `--write-movie` plus a headless/driver difference: the project is not physics-interpolated, so any camera script must run in `_process` (or the physics frame) consistently.
10. `LevelRoot._apply_light`/`_apply_fog_sky_affect` run every physics frame (`_step_light`, 372-374): any direct Environment/Sun edits are overwritten during a section blend, when `section_fog_sky_affect` differs from what you wrote, or when `Tuning.changed(&"")` fires. Prefer Tuning, or set `section_light_enabled = false`. `look_*` changes call `LookPost.apply()` which re-writes tonemap and `adjustment_*` (`_apply_grade` sets `adjustment_enabled = false` when the grade is off!).
11. HUD `GoCue`, `CameraToast`, `HelpOverlay` (8 s auto), `CombatLog`, `EnemyHealthBars`, `CenterDot` are all visible by default; hide the whole `Hud` CanvasLayer and the bot caption. With `--presentation=0`, nothing (HUD/camera/VFX/audio/LookPost) is built.
12. Hitstop is 50-140 ms and finishers add slow-mo (`slowmo_scale` .3, 250 ms); for a controlled shot set `TimeController` explicitly or zero the tunables. `TimeController.clear()` resets hitstop/slowmo.
13. The player is auto-revived on KO (`RoomKit.spawn_player` sets `auto_revive`), and the KO view moves the lens out of the eyes; use `god_mode` for combat takes.

Memory/perf traps (8 GB machine):
14. Only `CAPTURE_SLOTS=2` Movie Maker windows may run at once (machine-wide lock). `--quit-after` default 54000 frames; Movie Maker records at about half real time. One process per act (`record_acts.sh`) avoids leaks.
15. The first-person MSAA 4x + full 1080p Forward+ with SDFGI/SSAO off is moderate; the heavy items are the dozens of shadowed `OmniLight3D`s you might add (the toon `light()` runs per light) and a large `directional_shadow_max_distance` (40 m default).
16. `ToonMaterials._live` holds weak refs only, `ToonMaterials.trim()`/`trim_scissor()` are static singletons, `SkinnedArt` caches by weak entry; the per-boss/bruiser libraries are pre-warmed (`warm_up_libraries`, `warm_catalog_arts`, `RoomKit._catalog_arts` hold the catalog arts for the run), so spawn-time hitches are mostly absent but windowed warm-up costs about two frames at load.
17. `tests/bot/readability_probe.gd` (1266 lines) and `warning_oracle.gd` (579 lines) are attached by the base `_run`; they sample every frame and hold per-act logs. Skip them in a long video run by overriding `_run`.
18. `ComicSprite` pool (VfxDirector `_pool`) and blood splats (`vfx_blood_splat_max` 40, `vfx_blood_splat_s` 8 s) cap themselves; the ragdoll system and nav bake (`nav_region`) are the other per-level costs.

Other facts worth knowing:
19. The level is a single scene, all three sections live at once (about 330 modules in total); there are no loading seams, so `player.global_position = section.global_position + local_pos` teleports (as tour_acts does), after which the section light takes `section_light_blend_s` (2.5 s) to arrive (tour_acts waits `HOLD_S = 0.8` and uses `settle_light`).
20. `docs/video/PLAN.md` is the existing plan for the video; `video/` does not exist yet, and `tools/video/` only has `measure_refs.py` and `style_metrics.py`. Git: branch tip `1ae0b7a`, working tree clean.