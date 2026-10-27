# M4 codemap: fx-env-tooling (presentation, rooms' rendering, capture tooling)

Reader key `fx-env-tooling`. Legend: **[V]** verified by running something today (2026-10-26, Godot 4.7.2 Metal/Forward+ on the Apple M1, 8 GB); **[R]** read from the code or docs only. Line numbers are against branch `m4/art-pipeline` at `85f7f39`. Scratch material (prototype scripts, capture sheets) is in `/private/tmp/claude-501/-Users-arachne-repos-beat-em-up-PoC/097d610a-a8fb-4633-bbe9-6486aed195e7/scratchpad/m4-read-fx-env-tooling/` (session-local; the useful parts are quoted below).

## 0. The short version for a planner

1. **Every material in the game is built in code. No scene or `.tres` holds a material** (`game/**/*.tscn` are script-only nodes; the 46 `.tres` are moves, movesets and the wave table). Characters, props, environment and the pipe are `StandardMaterial3D` made in GDScript; the floor grid, the hit flash and the impact frame are `ShaderMaterial`s made in GDScript. So the toon look hooks in by changing a handful of factory functions, not by editing resources (section 5).
2. **The two rooms duplicate their rendering setup.** `RoomKit` (`game/level/room_kit.gd`, crowd room) and `test_room.gd` (training room, "frozen for M3") each build their own sky, sun, fog, flat materials and grid floor. **Every bot except `crowd_bot` runs in the training room** (combo, vfx, punk, ragdoll, warning), so a project-wide look has to land in both files or the training-room captures will look different from the game.
3. **A screen-space depth+normal edge pass works here today** [V]: a full-screen spatial quad reading `hint_depth_texture` and `hint_normal_roughness_texture`, added as one node to the room, drew clean ink lines on buildings, crates, the floor and both Punks, in first person and in the side view, with MSAA 4x on. Its cost on the M1 is **+2.3 to +3.6 ms/frame just for requesting the depth / normal-roughness buffers**, and the taps add little (section 6.3). The lines are not anti-aliased by MSAA (stair-steps in the crop).
4. **The comic VFX set already contains everything SPEC §10 lists** (10 words, 3 burst sizes, speed lines, droplets, splats, rear-warning burst), all 29 SVG/PNG pairs reproduce byte-for-byte from `tools/gen_fx.gd` [V]. A "final" pass is polish and consistency with the toon look, not missing assets (section 7). Several tests pin the set's shape (8-10 words, every PNG 512 px).
5. **Switching the character materials from `StandardMaterial3D` to a toon `ShaderMaterial` breaks pinned code in the rig**: the hit flash (`next_pass`), the parry flash (`emission`), the damage look (`detail_*`, `uv1_triplanar`) and the tests that name `StandardMaterial3D` or read `material_override` / `albedo_color` / `next_pass` / `_materials` (21 and 32 lines in `test_humanoid_rig`, `test_hit_flash`, `test_vfx`, `test_ui`), several typed against `Dictionary[int, StandardMaterial3D]`. An inverted-hull outline also wants `next_pass`, which the hit flash already owns (section 6.2).
6. **There is no act that records "an enemy 1 m from the lens, standing still and in motion" as one clip.** Closest: `punk_bot` "Punk wind-up at 1 m" (training room, 0.5 s idle, then jab and cross) and `vfx_bot` "damage looks held at 1 m" (dummy). The recipe to add one is small and was proven today (section 9).
7. **Perf act today is contaminated; M3's recorded numbers are the reference**: p95 12.2-13.1 ms, spawn hitch 25-31.5 ms (limit 33) vs. my re-run mean 16.7-17.5, p95 30-40 ms under a load average of 7.45 (section 9.4).

## 1. Presentation code, `game/fx/` [R unless marked]

Layer rule (ARCHITECTURE "Layers", lines 5-30): presentation subscribes to `CombatEvents` and reads state, never writes game state.

### 1.1 `VfxDirector` (`vfx_director.gd`, 649 lines, `class_name VfxDirector extends Node3D`)
- Created by `RoomKit.build_presentation()` (`room_kit.gd:147`) and `test_room._build_presentation()` (`test_room.gd:152`) as a direct child of the room. Group `&"vfx_director"` (line 42). `process_priority = CameraDirector.PROCESS_PRIORITY + 1` (50+1), so it places effects against the view being rendered this frame.
- `_init()` (line 86): `VfxArt.preload_all()`, seeds `rng`, builds two `CanvasLayer`s: **`SpeedLinesLayer` layer 5** (under the HUD, which is layer 10) holding `SpeedLines`, and **`ImpactFrameLayer` layer 20** holding `ImpactFrame`. Consts `LINES_LAYER := 5`, `FLASH_LAYER := 20`.
- Draw order of world sprites (`Sprite3D.render_priority`): `PRIORITY_SPRAY 0` (blood splash), `PRIORITY_BURST 1`, `PRIORITY_SPLASH 2` (sparks, droplets), `PRIORITY_WORD 3`. The hit-flash overlay uses `Material.RENDER_PRIORITY_MIN` (-128), so it draws first among transparents.
- Word pools are `@export` `PackedStringArray`s on the director: `light_words = [POW, BAM, SMAK]`, `heavy_words = [WHAM, THUD, BOFF, SMAK, BAM]`, `finisher_words = [KRAK, CRUNCH, WHUMP, KAPOW]`. Union = **10 words**. `pick_word()` (line 238) never repeats the previous word.
- Per hit (`_on_hit_landed`, line 345): block -> `block_spark` / `parry_spark` / `guard_break`; armor-absorbed -> grey `block_spark` (`spawn_armor_spark`, line 199); otherwise burst by tier (`VfxArt.BURSTS[tier]`), word by chance (`vfx_word_chance_light/heavy/finisher` = 0.0 / 1.0 / 1.0), blood (`spawn_blood`, heavy+finisher), finisher also speed lines (`finisher_lines_focus()`), the impact frame (`impact_frame.flash(frames/60)` when `Tuning.impact_frame_enabled`), and on a head finisher spit + tooth (`spawn_spit_and_tooth`). Droplets are `Motion.THROWN` sprites that ray-cast the world (`_land`, layer `LAYER_WORLD`) and leave `blood_splat_1..3` (`Motion.LYING`, lit).
- Player lunges (`_on_attack_started` / `_watch_lunge`): light speed lines in first person once the lunge carried `vfx_lunge_lines_min_m` (1.0 m).
- Damage looks: `_update_damage_look()` calls `HumanoidRig.set_damage_look()` from `CombatEvents.health_changed` (66% bruised, 33% bloodied).
- **First-use warm-up** (`begin_warm_up()`, line 170, windowed only): draws one tiny faint sprite per material variant (POP no-depth-test, THROWN plain, LYING shaded) and the impact frame's material on one pixel, because the first draw of each cost 8-16 ms (ARCHITECTURE line 251). **Every new shader or material variant M4 adds (toon, hull, edge pass, halftone) will have the same first-use pipeline-compile hitch on Metal and needs the same warm-up treatment**; the rig does it for the flash in `HumanoidRig._warm_flash()` (`humanoid_rig.gd:501`).

### 1.2 `ComicSprite` (`comic_sprite.gd`, 207 lines, `extends Sprite3D`)
Pooled, driven by `VfxDirector.advance()`, never self-processing. `enum Motion { POP, THROWN, LYING }` (line 18). `_init`: `top_level`, `double_sided`, `visible=false`. `set_art()` (line 74) sets `pixel_size = 1/max(w,h)` so the long side is 1 m at scale 1. `place(camera)` (line 93): faces the active camera, caps/floors its size by view share (`Tuning.vfx_max_view_share` 0.25, `vfx_min_view_share` 0.04) at its depth, keeps it `vfx_min_camera_dist_m` (0.45) off the lens, pulls it inside the view (`_inside_view`) near the edges, pop-in curve `pop_factor()` (`vfx_pop_start 0.5` -> `vfx_pop_peak 1.25` -> 1 over `vfx_pop_s 0.07`), fade `fade_alpha()`. LYING splats use `shaded = true` (lit by the sun; they will not follow a toon ramp unless given one).
Sprite3D builds its own material internally; the sprites are the one world-space thing M4's toon shader does not need to touch.

### 1.3 `SpeedLines` (`speed_lines.gd`, 176 lines, `extends Control`, canvas layer 5)
`_draw()` (line 157) draws `speed_lines.png` rows (`VfxArt.SPEED_LINE_ROWS = 4`) as tapered streaks from past the screen corners toward a focus point, tinted `HudStyle.INK` at `current_alpha()`. 34 lines (`vfx_speed_lines_count`), reshuffled every `vfx_speed_lines_redraw_frames` (2) real frames (comic flicker; off with `impact_frame_enabled = false`, the photosensitivity toggle), scaled by `screen_shake_intensity`, kept clear of live burst/word rects (`keep_clear`). `start(focus_px, seconds, strength)` line 45.

### 1.4 `ImpactFrame` (`impact_frame.gd` 84 lines + `impact_frame.gdshader` 25 lines, `extends ColorRect`, canvas layer 20)
`canvas_item` shader reading `hint_screen_texture` (`filter_linear_mipmap`): per pixel luma vs a mix of `threshold` (0.45) and the blurred neighborhood (`blur_lod` 5, `local_mix` 0.6); output `mix(paper, ink, step(cut, here))`, `ink = (0.07,0.06,0.09)`, `paper = (0.97,0.94,0.85)`. `flash(seconds)` (line 48) sets the three uniforms from Tuning; shown at least one rendered frame; `warm()` draws it on one pixel at load. **It reads the whole screen including the HUD and any 3D post pass**, so an edge pass / LUT / halftone added to the 3D scene will be inside the impact frame's input automatically.

### 1.5 `HitFlash` and `DamageLook`
- `hit_flash.gdshader` (37 lines, spatial, `unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled`): drawn as `next_pass` of every rig material while a flash runs; mixes `flash_color` by `flash_strength x falloff(distance(world, flash_point))` with `flash_radius` (0.25 m), `flash_core` (0.5). Mirrored in GDScript by `HumanoidRig.flash_falloff()`.
- `damage_look.gd` (82 lines): `prepare()` (line 61) turns on `detail_enabled`, `detail_blend_mode MIX`, `detail_uv_layer UV1`, `uv1_triplanar`, `detail_albedo = VfxArt.clear_detail()` on the BODY/PANTS/ACCENT/SKIN materials (never DARK); `apply()` (line 75) swaps only `detail_albedo` and `uv1_scale` so the shader variant never changes. Tiles: `damage_bruised`, `damage_scuffed`, `damage_bloodied`, `damage_blood` (512 px seamless). **These are `StandardMaterial3D` features; a toon `ShaderMaterial` must re-implement a triplanar detail overlay with the same four textures.**

### 1.6 `VfxArt` (`vfx_art.gd`, 63 lines)
`DIR = res://assets/export/fx/`; `texture(name)` holds every loaded texture for the whole run in a static dictionary (ResourceLoader's cache holds no reference of its own); `preload_all()` loads every PNG; `word_texture(word)` -> `word_<lower>.png`; `clear_detail()` is the 1x1 transparent texture; `BURSTS`, `BLOOD_SPLATS`, `SPEED_LINE_ROWS`.

### 1.7 Tuning
Group "VFX" (`tuning_data.gd:197-341`; 77 `vfx_*` properties, subgroups Size and view, Bursts, Lettering, Speed lines and impact frame, Blood spit and teeth, Block sparks, Damage looks); "Hit feel" > "Hit flash" at 182. `impact_frame_enabled` (181). **There is no "Look"/"Rendering" group yet**: the toon, outline, edge, LUT and halftone parameters need one (CLAUDE.md: no numbers in scripts; feel numbers are tunables). Adding a group means regenerating `tuning/default.json` (`godot --headless -s tools/gen_default_preset.gd`; it is `merge=keep-ours` in `.gitattributes:14`) because `tests/test_tuning_panel.gd:454` (`test_the_default_preset_equals_the_shipped_defaults`) compares them. The F1 panel builds its categories from the group names, so a new group just appears. Live updates follow the existing pattern: subscribe to `Tuning.changed` (see `VfxDirector._enter_tree`, `RoomKit.PlayerObstacle`).

## 2. `tools/gen_fx.gd` and the assets

### 2.1 What exists
`assets/source/fx/*.svg` (29, 268 KB) -> `assets/export/fx/*.png` (29 + 29 `.import`, 1.4 MB). All PNGs are **512 px on the long side** (words are 512 x 136..216, `tooth` 410 x 512). PNGs are Git LFS (`.gitattributes:22`) but real files in this checkout. Logged row by row in `ASSETS.md` "Effects (VFX)".
Files: `block_spark, blood_drop, blood_splat_1..3, blood_spray, burst_small/medium/large, damage_blood, damage_bloodied, damage_bruised, damage_scuffed, guard_break, parry_spark, rear_warning, speed_lines, spit, tooth, word_{bam,boff,crunch,kapow,krak,pow,smak,thud,wham,whump}`.

### 2.2 How each SVG is drawn (script is 679 lines, `extends SceneTree`)
- Run: `godot --headless -s tools/gen_fx.gd` (draw + rasterize), `-- --raster-only` (rasterize hand-edited SVGs only), then `godot --headless --import --quit`. `_init()` line 84; `_draw_all()` line 98 lists every asset; `_save(name, svg)` line 126 writes `SOURCE_DIR`.
- **Deterministic**: a `RandomNumberGenerator` seeded per asset (`_rng.seed = 1101` small burst, 1202 medium, 1303 large, 1404 speed lines, 2100+i splats, 2200 spray, 3100 block, 3200 parry, 3300 guard break, 3400 rear warning, 4100/4200/4300 damage tiles; the lettering uses `hash(word)`).
- Primitives (all static/instance helpers): `_doc(view, defs, body, note)` (134, wraps in `<svg width height viewBox>` scaled so the long side is `RASTER_PX = 512`), `_path` (159), `_linear`/`_radial` gradients (166/174), `_star(c, spikes, outer_range, inner_range, rot, jitter)` (182: jagged comic stars; every burst), `_blob` (195: quadratic-curve irregular blobs; splats, bruises), `_teardrop` (210: droplets, streaks), `_circle` (226), `_tear`/`_scratches`/`_wraps`/`_cell_point` (damage tiles; `_wraps` draws shapes shifted by +-512 so tiles are seamless).
- Colors are string consts at the top (INK `#120f17` = `HudStyle.INK`, PAPER `#f7f0d9`, YELLOW, ORANGE, ACCENT_RED `#e8302a`, BLOOD `#d0141f`, WARNING_RED `#ff4a2e`, PARRY_CYAN `#59ebff`, ...). Red is reserved for blood, the rear warning and finisher accents (SPEC §10).
- **Rasterize** (`_rasterize_all()` line 644): `Image.new().load_svg_from_string(svg, 1.0)` (Godot's ThorVG, which has **no text support**, hence the custom alphabet) -> `image.save_png`. `_import_settings()` (line 666) writes/patches each PNG's `.import`: lossless (`compress/mode=0`), `mipmaps/generate=true`, `detect_3d/compress_to=0`.
- **Verified [V]**: I copied the script to a scratch project and ran it headless (0.8 s, 29 PNGs): **all 29 SVGs and all 29 PNGs are byte-identical (`cmp`) to the committed files.** A redraw is safe and reproducible.

### 2.3 The lettering alphabet
- `WORDS` (line 47): `"POW!","BAM!","SMAK!","WHAM!","THUD","BOFF!"` -> `"punch"`; `"KRAK!","CRUNCH!","WHUMP!","KAPOW!"` -> `"finisher"` (red extrusion). Ten words.
- `GLYPHS` (line 55): a hand-authored block alphabet on a **100-unit cap height, y down**. Each glyph is a list of closed contours as flat `[x0,y0,x1,y1,...]`; contour 0 is the outline, the rest are counters (holes, `fill-rule="evenodd"`). **Only 17 letters + "!" exist: A B C D F H K M N O P R S T U W !** (exactly what the ten words need). New words need E, G, I, J, L, Q, V, X, Y or Z drawn as new contours; words buildable today include CRASH, SMASH, BASH, WHACK, THWACK, THUMP, KABOOM, BONK, SOCK, WHAP.
- `_lettering(word, finisher)` (line 240): seeds `hash(word)`; per letter scale 0.95-1.05 (first letter x1.12), tilt +-6 deg, bob +-5, italic lean `x += -y*0.17`, 1-unit overlap; draws, in order: drop shadow (punch: offset 7,9, one step) or red extrusion (finisher: offset 10,12, 6 steps), a shared ink outline (stroke 11) under all letters, then the fill (linear gradient PALE_YELLOW -> ORANGE, or WHITE -> YELLOW for finishers), and a white glint on the first letter.
- Resulting aspect ratios differ (CRUNCH 512x136, KAPOW 151, WHUMP 155 vs. POW 208, BAM 216): the director sizes by **width** (`vfx_word_small/medium/large_m` 0.3/0.42/0.6), so the long words have visibly smaller letters at the same tier.

## 3. HUD and the rear warning [R]
- `hud.tscn` root `Hud` is a `CanvasLayer`, **layer 10** (`hud.tscn:20`), `process_mode ALWAYS`, `process_priority = HudStyle.PROCESS_PRIORITY` (100). Children: `DebugDraw`, `EnemyHealthBars`, `CenterDot`, `PlayerHealthPanel` (bottom-left, offsets (40,-176)-(540,-36)), `BossHealthBar` (bottom-center, 760x96, hidden until a boss), `CombatLog`, `CameraToast`, `HelpOverlay` (`PanelContainer`), `BlockCallout`, `RearWarning`, `GrabPrompt`, `PickupCue`, `PauseOverlay`. All sizes assume the 1920x1080 canvas (project stretch `canvas_items`, aspect `expand`).
- **Everything is code-drawn with `_draw()` and `HudStyle` helpers** (`hud_style.gd`, 122 lines): `draw_panel` (shadow + ink border + flat fill on a slanted quad, `slanted_quad`), `draw_gauge` (trough, white damage ghost, fill), `draw_text` (optional ink outline), consts `INK (0.07,0.06,0.09)`, `PAPER (0.97,0.94,0.85)`, `TROUGH`, `HEALTH (1,0.82,0.16)`, `BOSS (0.7,0.42,0.98)`, `GUARD`, `PARRY`, `FINISHER_ACCENT`. Slants 0.16 (player) / 0.22 (boss), borders 6 / 5 px.
- **No HUD texture except `rear_warning.png`, no font file, no `Theme`.** Text is `ThemeDB.fallback_font` with `variation_embolden 0.9` (`HudStyle.bold_font()`, line 35). `grep` for `FontFile|.ttf|.otf|theme` under `game/ui` finds nothing. The help, tuning and cheat overlays use default Godot styling. A comic font would be a new asset (needs an `ASSETS.md` row) and is not in SPEC §10.
- `RearWarning` (`rear_warning.gd`, 360 lines, `extends Control`): `_texture = VfxArt.texture(&"rear_warning")` (line 72), `texture_filter LINEAR_WITH_MIPMAPS`; `_draw()` (line 352) `draw_texture_rect(_texture, state.rect, false, Color(b,b,b,alpha))`, one burst per top corner, 160 px base (`rear_warning_base_px`), inset 96 px, heavy x1.3, pulses twice (`rear_warning_pulses`, `_pulse_s 0.12`, `_pulse_grow 0.25`, `_min_alpha 0.65`), always inside the reserved 20% x 20% corner (`CORNER_SHARE`). Signals `shown(side,count,heavy)` / `cleared(side)` feed the bots' `W+` / `W-` lines.
- Health bars: `EnemyHealthBars` (238 lines) projects over-head bars with `Camera3D.unproject_position`; `HealthGauge` (55 lines) holds the ghost/flash easing.

## 4. Rooms and project rendering setup

### 4.1 `project.godot` [R]
`[rendering]`: `renderer/rendering_method="forward_plus"`, `anti_aliasing/quality/msaa_3d=2` (**4x MSAA**; confirmed at runtime: `Viewport.msaa_3d == 2`). Nothing else: no TAA/FXAA, no SSAO/SSIL/SSR, no glow, no custom shader globals. Display: base 1920x1080, **`window_width_override=1600`, `window_height_override=900`**, stretch `canvas_items`, aspect `expand`. Physics: Jolt, 60 Hz. Render layers named: 1 default, 2 fp_hidden, 3 debug. No autoload for rendering.

### 4.2 Environment, lights, shadows (identical numbers in two places)
`RoomKit.build_environment()` (`room_kit.gd:49-81`, used by `CrowdRoom._ready()` line 115) and `TestRoom._build_environment()` (`test_room.gd:65-92`, own copy). Both:
- `WorldEnvironment` (named "WorldEnvironment" in RoomKit) with one `Environment`: `BG_SKY`, `ProceduralSkyMaterial` (top `(0.36,0.42,0.56)`, horizon `(0.72,0.62,0.55)`, ground horizon `(0.4,0.37,0.38)`, ground bottom `(0.2,0.2,0.22)`), ambient from sky at energy 0.7, tonemap `FILMIC`, fog on with light color `(0.6,0.56,0.55)`, density 0.008.
- **No `Compositor`, no `CameraAttributes`, no adjustments (`adjustment_enabled` false = no LUT), no glow (so SPEC's "no bloom" already holds).**
- One `DirectionalLight3D` ("Sun" in RoomKit), rotation `(-52, 32, 0)` deg, energy 1.2, shadows on, `directional_shadow_max_distance 40`. No other lights. Shadow atlas size is the project default (not set).
- The three cameras (`game/camera/camera_director.gd`: first person, side view, free fly) set no environment of their own; `WorldEnvironment` serves all. The FP camera: `near 0.05`, `fov = Tuning.fov_deg` (90, `KEEP_WIDTH`), cull mask excludes `VIS_FP_HIDDEN` (`first_person_camera.gd:112-117`), `standing_eye_height 1.68` (`player.gd:26`).

### 4.3 Materials of the rooms
- **Crowd room** (`crowd_room.gd:189 _build_geometry`): `RoomKit.flat_material(color)` (`room_kit.gd:116`: `StandardMaterial3D`, `albedo_color`, `roughness 0.9`) for walls `(0.42,0.4,0.44)`, accent `(0.5,0.46,0.4)`, dark openings `(0.12,0.1,0.13)`, windows `(0.16,0.2,0.28)` (visual boxes, `cast_shadow OFF`, line 261), road paint `(0.82,0.8,0.72)`, crates `(0.55,0.46,0.3)` (two 1 m boxes, line 322 `_build_props`), **the parked car is one red box `(0.55,0.2,0.2)`, 4.2 x 1.9 x 1.4 m**, the dumpster one green box `(0.2,0.42,0.3)`, backdrop ground `(0.24,0.23,0.26)` and skyline boxes. Floors (lane, alley floors) use `RoomKit.grid_material()` (`room_kit.gd:124`) = `ShaderMaterial` of `game/level/grid.gdshader` (25 lines, spatial; flat base + 1 m and 5 m world-space grid lines via `fwidth`; writes `ALBEDO`, `ROUGHNESS 0.92`; lit by the standard pipeline, so a toon `light()` would need to be added to it). All geometry sits under one `Geometry` node (the navmesh bakes from it). **Props are plain `BoxMesh`es** (`RoomKit.box_mesh`, line 107; `box.material = material`), not models.
- **Training room** (`test_room.gd`): its own `_flat_material()` (line 201, same recipe), its own grid `ShaderMaterial` (line 95), `_box_mesh` (192), same colors, plus three dummies in `dummy_colors`. `test_room.gd` is "frozen for M3" (ARCHITECTURE line 431) but nothing stops M4 changing it.
- Debug draw (`debug_draw.gd:106`): unshaded transparent `StandardMaterial3D`, `render_priority MAX-2`, on `VIS_DEBUG` layer 3: leave alone. The pipe (`weapon.gd:42`): `StandardMaterial3D`, roughness 0.5, metallic 0.4, `CylinderMesh.material`.

## 5. Material inventory: code vs scene resources (answer to (a), part 1)

| Where | What | Type | Built in |
| --- | --- | --- | --- |
| `humanoid_rig.gd:723 _build_materials()` | 5 materials per rig, one per `PlaceholderBody.Paint` (`BODY, PANTS, ACCENT, SKIN, DARK`, `placeholder_body.gd:141`); `roughness 1`, `metallic_specular 0.2`, `emission_enabled` with black-energy emission always on, `DamageLook.prepare()` on four paints; field `_materials: Dictionary[int, StandardMaterial3D]` (line 147) | StandardMaterial3D | code, per rig (flashes stay per actor) |
| `humanoid_rig.gd:739 _build_meshes()` | every part: `mesh_instance.material_override = _materials[part.paint]`, `cast_shadow ON`, rigid primitive (Box/Capsule/Sphere/Cylinder/Dome) under a bone follower, layers via `_apply_layers()` (1125) | MeshInstance3D | code |
| `humanoid_rig.gd:1114 _apply_colors()` | writes `.albedo_color` of each paint from `body_color/accent_color/skin_color/pants_color` and `_DARK_COLOR` | | code |
| `humanoid_rig.gd:396 set_flash()` | parry flash = `.emission` + `.emission_energy_multiplier` on all five | | code |
| `humanoid_rig.gd:516 _show_flash_overlay()` | `mat.next_pass = _flash_overlay if on else null` (overlay `ShaderMaterial`, `hit_flash.gdshader`, made in `flash_at()` line 420, `render_priority = RENDER_PRIORITY_MIN`) | ShaderMaterial | code |
| `humanoid_rig.gd:501 _warm_flash()` | a box with the overlay shader at zero strength so the pipeline compiles at load | ShaderMaterial | code |
| `weapon.gd:42` | pipe | StandardMaterial3D | code |
| `room_kit.gd:116`, `test_room.gd:201` | flat environment materials | StandardMaterial3D | code |
| `room_kit.gd:124`, `test_room.gd:95` | grid floor | ShaderMaterial (`grid.gdshader`) | code |
| `impact_frame.gd:20` | impact frame | canvas ShaderMaterial | code |
| `comic_sprite.gd` | Sprite3D's internal material | n/a | engine |
| `debug_draw.gd:106` | debug lines | StandardMaterial3D | code |
| scenes / `.tres` | none | | |

## 6. (a) Where a project-wide toon look hooks in

### 6.1 Hook map (exact files)
1. **Shared toon `ShaderMaterial` for characters**: replace `HumanoidRig._build_materials()` (`humanoid_rig.gd:723`), `_apply_colors()` (1114), `set_flash()` (396), `_show_flash_overlay()` (516), `DamageLook.prepare/apply` (`damage_look.gd:61,75`) and the typed `_materials` (147). Per-paint parameters become shader uniforms (`albedo`, damage tile, tile size, emission/parry). Pinned by tests (section 8). The pipe (`weapon.gd:42`) follows.
2. **Environment materials**: `RoomKit.flat_material()` (`room_kit.gd:116`) and `grid_material()` (124) are the single points for the crowd room; `test_room._flat_material()` (201) and its grid (95) are the duplicate for the training room. Make the training room call `RoomKit` (or copy the change) so both rooms and every bot match. `grid.gdshader` needs the toon ramp in a `light()` function or a shared `.gdshaderinc` (Godot 4 supports `#include`; not tested here).
3. **Sky, sun, fog, ambient, tonemap, LUT**: `RoomKit.build_environment()` (`room_kit.gd:49`) and `TestRoom._build_environment()` (`test_room.gd:65`). Built-ins that exist on `Environment` in 4.7.2 (class dump [V]): `adjustment_enabled`, `adjustment_color_correction` (a `Texture`: the **built-in color-grading LUT**), `adjustment_brightness/contrast/saturation`, `glow_enabled` (leave off: SPEC allows bloom only on VFX). `WorldEnvironment.compositor` and `Camera3D.compositor` (`Compositor` -> `CompositorEffect[]`, with `needs_normal_roughness`, `needs_motion_vectors`, `access_resolved_color/depth`, callback types `PRE_OPAQUE .. POST_TRANSPARENT`) exist for a compute-shader post pass (not tried; the quad below is simpler and worked).
4. **Screen-space edge pass, halftone, dither**: one new node added next to the director in `RoomKit.build_presentation()` (`room_kit.gd:147`) and `test_room._build_presentation()` (`test_room.gd:152`), or inside `build_environment()` so it exists wherever the sky does. Bots and tests that build rooms with `with_presentation = false` get none (good: tests stay cheap). Because the quad is a world node (not a camera child) it served **both the first-person and the side-view camera** in the prototype [V].
5. **Outlines (inverted hull)**: per-part mesh work in `HumanoidRig._build_meshes()` (line 739; each part is its own `MeshInstance3D` under a bone follower). See 6.2 for the `next_pass` conflict. A separate hull `MeshInstance3D` must copy `layers` (FP-hidden head/chest must stay hidden from the FP camera, `_apply_layers()` line 1125) and should be `SHADOW_CASTING_SETTING_OFF`. Width scaled by distance is a vertex-shader job using `MODEL_MATRIX`/`VIEW_MATRIX` (built-ins are available in `vertex()`).
6. **Tunables**: a new `@export_group` in `game/autoload/tuning_data.gd` and a regenerated `tuning/default.json` (section 1.7).
7. **Tests that must keep compiling**: `tests/test_scripts_compile.gd` loads every `.gd/.tres/.tscn` under `res://game`; it does not load `.gdshader` files directly, but a `.tres` or script `preload` of a shader parses it.

### 6.2 Conflicts and gotchas
- **`next_pass` is taken.** `humanoid_rig.gd:521` sets `mat.next_pass` to the flash overlay (and `null` when idle). Tests assert it is exactly the overlay or exactly null (`test_hit_flash.gd:154, 297, 374`). A hull outline via `next_pass` needs either a chain (base -> outline -> flash, which changes those asserts) or separate hull meshes. The screen-space pass alone already outlined the Punks acceptably in the prototype (silhouette depth jump + normal creases), so "hull for characters, screen-space for environment" (SPEC §10) can be built independently.
- **FPView raycasts only primitive meshes** (`tests/fp_view.gd` `ray_hit`/`mesh_distance` handle `BoxMesh`, `CylinderMesh`, `CapsuleMesh`, `SphereMesh`; anything else returns INF). 17 test/bot files use it (section 8). A real skinned Punk mesh makes R4/R8 of the readability probe and the FP-view tests see nothing unless `FPView` learns `ArrayMesh` (that is the rig-render reader's area; flagged here because it is where presentation meets the tests).
- **Shader built-ins cannot be read inside helper functions** [V]: using `INV_PROJECTION_MATRIX` in a helper gave `SHADER ERROR: Unknown identifier in expression: 'INV_PROJECTION_MATRIX'`. Pass it as an argument (`float lin(vec2 uv, mat4 ip)`).
- **Headless runs parse shaders** [V]: a bad `.gdshader` prints `SHADER ERROR ... Shader compilation failed` at load even with the dummy renderer, so tests that load the shader show the typo; GPU pipeline compile errors and `get_shader_uniform_list()` (returns 0 headless) do not.
- **Post lines are not anti-aliased by MSAA** [V]: stair-steps are visible on long building edges in the 1600x900 crop. Options: a soft `smoothstep` ramp (used), thicker lines, `Viewport.screen_space_aa = FXAA` (exists in the class dump, untested), or hull outlines on characters.
- **VIEWPORT_SIZE is in real pixels (1600x900 in captures)**; a line width in px should scale with `VIEWPORT_SIZE.y / 1080` to look the same at 4K.
- **Order against transparents (untested)**: the quad draws in the transparent pass with `depth_test_disabled`; give it `render_priority` between the flash overlay (-128) and the comic sprites (0..3), e.g. -127, so lines do not draw over bursts/words and the flash is under the lines. Fog is applied to opaque geometry before the quad, so distant lines stay full-strength unless the shader fades them by depth.
- **Impact frame and speed lines are canvas layers** (5 and 20): a 3D edge/LUT/halftone is under both, and the HUD (layer 10) is untouched by 3D post. A halftone that should also cover the HUD would be a canvas shader.

### 6.3 Prototype and cost measurements [V]
`edge_proto.gd` (scratch, not committed): loads `crowd_room.tscn` (waves off, AI frozen), two Punks at 1.5 m and ~4 m, runs a `SceneTree` script windowed with `godot --path <repo> -s edge_proto.gd`, adds this node to the room, saves viewport stills. **It worked first time**:
```
quad: MeshInstance3D, QuadMesh size (2,2), extra_cull_margin = 16384, cast_shadow OFF, material_override = ShaderMaterial
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
float lin(vec2 uv, mat4 ip) { float d = texture(depth_tex, uv).r; vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0); v.xyz /= v.w; return -v.z; }
vec3 nrm(vec2 uv) { return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0); }   // view-space normal
// fragment(): 4 neighbour taps at width_px / VIEWPORT_SIZE; edge = max(smoothstep on sum(|depth diff| / depth),
//             smoothstep on sum(1 - dot(n0, n_i))); ALBEDO = ink, ALPHA = edge
```
Findings: depth view (`fract(d*0.1)`) and normal view (`n*0.5+0.5`) look right (ground green, walls pink/cyan, round limbs shaded); ink outlines on the Punks' silhouettes, hands, cap, building corners, crate edges; HUD unaffected; the side-view camera also shows the lines (`edges_side_view.png`). Stills: `proto_sheet.png` (base / edges / depth / normal) and `crop_and_side.png` in the scratch folder.

**Frame cost on the M1** (windowed 1600x900, `vsync` off, crowd room, two Punks, noise about +-0.5 ms, other agents' processes running; `edge_cost.gd`):

| variant | MSAA 4x (project setting) | MSAA off |
| --- | --- | --- |
| base, no quad | 10.8-11.3 ms | 8.8 ms |
| flat quad, no texture reads | 11.5 | 9.4 |
| depth texture, 1 tap | 14.1 (+2.8) | 11.1 (+2.3) |
| normal-roughness texture, 1 tap | 14.9 (+3.6) | 11.8 (+3.0) |
| depth only, 5 taps | 13.5 (+2.4) | 11.6 (+2.8) |
| normal only, 5 taps | 16.1 (+5.0) | 11.3 (+2.5) |
| depth + normal, 5 taps each (first prototype run, 300 frames) | 16.3 (+4.8) | not run |

So: **the price is requesting the buffers (depth copy / normal-roughness prepass / MSAA resolve), not the number of taps**, and MSAA 4x itself costs about 2 ms of an 11 ms frame here. At the 60 Hz budget (16.7 ms) the M1 has about 5.5 ms of headroom in this scene before toon materials, hull passes and six enemies. The RTX 3060 target is not measured. `RenderingServer.viewport_get_measured_render_time_gpu()` returns **0.00 on this Metal setup** (Movie Maker's own log also says "GPU render time: 0.00 seconds"), so GPU time cannot be read in-engine; use unvsynced wall time (`DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`, `Engine.max_fps = 0`) as above. With vsync on every variant reads 16.66 ms and hides the difference.

## 7. (b) M2's VFX set vs SPEC §10, and what a final pass would change

| SPEC §10 "2D effects" item | Present | Where |
| --- | --- | --- |
| lettering set, 8-10 words | **10 words** (POW BAM SMAK WHAM THUD BOFF KRAK CRUNCH WHUMP KAPOW) | `gen_fx.gd:47`, `word_*.png`; pools in `VfxDirector` |
| impact bursts, 3 sizes | `burst_small/medium/large` (large has red shards, SPEC §10 finisher accent) | `_burst_*`, `VfxArt.BURSTS` |
| speed lines | one 4-row streak sheet, arranged radially at runtime (34 lines, flicker, keep-clear rects) | `speed_lines.png`, `SpeedLines` |
| droplets | `blood_drop` (tail turns away from flight), `spit` | |
| splats | `blood_splat_1..3`, `blood_spray` (contact splash), lying on surfaces, capped 40, 8 s | |
| rear-warning burst | `rear_warning.png` (red-orange star with "!") | M3, `RearWarning` |
| beyond the list (M2/M3) | `tooth`, `block_spark`, `parry_spark` (cyan), `guard_break` (amber shards), grey armor spark (tinted block spark), 4 damage tiles, impact-frame shader, localized hit flash | |

What I saw on the contact sheet (`fxsheet/sheet2.png` in scratch) and in captures, as **candidates for a final pass, not decisions** (SPEC says 512 px PNGs drawn as SVG; changing that needs Game-boy):
- Flat vector fills with one ink outline each; no halftone/Ben-Day texture, no inner highlight on lettering beyond one glint, no motion/dust/shockwave kinds. Bursts of one tier are a single texture, rotated randomly (`roll`), so repetition is visible over a long fight; blood splats have three variants, words ten.
- **Resolution**: the view-share cap `vfx_max_view_share` 0.25 x 1920 = 480 px, so 512 px is about 1:1 on a 1080p screen and about 2:1 soft at 4K. `test_fx_art_is_512_px_with_svg_sources_and_logged` pins `maxi(w,h) == 512`; raising it needs a test + spec change.
- **Style consistency with the 3D look**: SVG ink strokes are 16/15/14 units of 512 (about 3% of width); 3D outline width and HUD borders (6 px at 1080p) are separate numbers. Matching them is the "production" consistency task.
- **Word size by width** gives long words (CRUNCH, KAPOW, WHUMP, 512x136-155) letters about 25-30% shorter than POW/BAM/THUD (208-216) at the same tier width.
- HUD text is the engine's fallback font emboldened; the only comic lettering in 2D is `rear_warning.png`'s "!". The in-world alphabet (`GLYPHS`) could be reused for HUD callouts (PARRY, GUARD BREAK are plain text today, `block_callout.gd`).
- LYING splats and the damage tiles are lit/blended by the standard pipeline; they need a pass once the toon shader exists (no red until the blood rule must keep holding: `test_bruises_are_not_red_paint`).
- The warm-up (section 1.1) must cover any new material variant.

## 8. (c) Tests and bots that pin VFX, HUD or environment visuals

Baseline run today, headless `--fixed-fps 60`, one file at a time [V]: all green with 0 SCRIPT/SHADER ERROR: `test_vfx` 53 tests / 1996 asserts (1.0 s), `test_hit_flash` 13 / 1917, `test_ui` 34 / 2803, `test_rear_warning` 29 / 890, `test_crowd_room` 18 / 127, `test_health_bars` 6 / 33, `test_armor_presentation` 8 / 34, `test_pickup_cue` 7 / 27, `test_humanoid_rig` 57 / 10156, `test_scripts_compile` 2 / 229, `test_bot_scripts_compile` 2 / 48. (Full suite: `tools/run_tests.sh`, about 90 s; not rerun.)

| Test file | What it pins that M4 can break |
| --- | --- |
| `test_vfx.gd` (1075 lines) | **8-10 words and a PNG per pool word** (`test_every_word_has_lettering_and_the_set_is_8_to_10_words`, line 251); **every `fx` PNG is 512 px, has an `.svg` source and an `ASSETS.md` mention** (line 1061); textures loaded once and held by RID (482); effect sizes, view caps and word-in-view rules (264-410); impact frame length/toggle and its three shader params `threshold/local_mix/blur_lod` (462, 562); speed-line behavior (502-600); **damage look: `Dictionary[int, StandardMaterial3D]` `_materials`, `detail_enabled`, `detail_albedo`, `uv1_triplanar`, `detail_blend_mode`, and "never switches the shader variant" via every stored `StandardMaterial3D` property (688-835)**; bruises are not red paint (812); presentation writes no game state (891); warm-up variants (925-1025); room adds exactly one director with presentation and none without (1026); every `vfx_*` tunable is in group "VFX" with a range or bool and the group follows "Hit feel" (1040). `ART` list at line 14 names the 19 non-word textures. |
| `test_hit_flash.gd` (635) | overlay on every `_materials` entry or none (`next_pass`, 154/297/374), `hit_flash.gdshader` path (192), parameters `flash_point/radius/core/strength/color` (195-200), exactly `hit_flash_frames` rendered frames, point follows the struck part |
| `test_humanoid_rig.gd` (57 tests, 39 lines using FPView) | `mesh.material_override as StandardMaterial3D` and `.albedo_color` per part (lines 542-736: player skin/glove colors, wrapped hands, enemy colors); FP-hidden layers; primitive-mesh raycasts |
| `test_ui.gd`, `test_rear_warning.gd`, `test_health_bars.gd`, `test_pickup_cue.gd`, `test_armor_presentation.gd` | HUD scene has every part and stays out of the top corners (`test_ui.gd:174,201`); rear-warning rect inside the reserved 20% corner at every size, heavy larger than normal, "on the shipped canvas" (1920x1080) (`test_rear_warning.gd:420`); pulses and sim-time; armor spark |
| `test_crowd_room.gd` | navmesh and spawn points only; **no test pins the sky, sun, fog, tonemap, any room material or the grid** (grep for `WorldEnvironment/Environment/DirectionalLight/flat_material/fog/tonemap` in tests finds only `RoomKit.add_box/spawn_player`) |
| `test_scripts_compile.gd` / `test_bot_scripts_compile.gd` | load every script/tres/tscn under `res://game` and every script/scene under `res://tests/bot`: a typo in a new bot act file fails the suite |
| `test_tuning_panel.gd:454` | `tuning/default.json` equals the shipped `TuningData` defaults: regenerate after adding a group |
| FPView users (17 files) | `test_bruiser, test_boss, test_boss_close_lens, test_combat_integration, test_grab_view, test_enemy_moves_thug/kicker, test_humanoid_rig, test_ko_blink, test_hit_flash, test_launch_from_hold, test_ko_view, test_player_grabbed, test_ragdoll, enemy_move_checks, bot/engage_meter, bot/readability_probe` (R4 occlusion, R8 lens coverage) |

Bots that exercise VFX/HUD (all record with `tools/capture_bot.sh`, section 9): `tests/bot/vfx_bot.gd` (22 acts, training room: every tier's burst + word, haymaker spit/tooth, damage looks clean->bruised->bloodied, block/parry/guard-break sparks, lunge lines, impact frame off, tier sizes side by side, knees/stomp under the view, back elbow, spin kick; seeds `vfx.rng.seed = 7` per act so captures repeat), `warning_bot.gd` (rear warning acts + `WARN-CHECK` lines), `crowd_bot` acts `room_acts.gd` (room tour, free-fly tour with F3, spawn points, F4 menu: the **environment look** acts) and `crowd_acts.gd` ("Rear warning, every archetype", "Perf, six with ragdolls"), `punk_bot`, `ragdoll_bot`, `combo_bot`.

## 9. (d) Recording a first-person capture of an enemy 1 m from the lens

### 9.1 The tool chain [V]
- `tools/capture_bot.sh <res:// bot scene> <out dir> ["<act filter>"] [stills fps]` (92 lines): takes one of 2 machine-wide slots (`CAPTURE_SLOTS`, lock dir `~/.cache/beat-em-up-capture`), runs `godot --path <repo> --write-movie <out>/bot.avi --fixed-fps 60 --resolution 1280x720 --quit-after 54000 <scene> -- --act=<filter>`, writes `bot.log`, counts `SCRIPT ERROR|^ERROR` lines, optionally `ffmpeg ... fps=N,scale=960:-1 stills/%04d.png`. `captures/` is git-ignored; a `.gdignore` is dropped in the out dir.
- **Real recording size is 1600x900, not 1280x720** [V]: Movie Maker logged "recording movie in 1600x900 @ 60 FPS" and `ffprobe` says 1600x900 MJPEG; `project.godot`'s `window_width/height_override` beat `--resolution`. Wall cost about 4x real time (a 3.8 s clip took 15.6 s; 14.8 s of clip took 27 s). The 3D viewport is 1600x900 pixels while HUD coordinates stay on the 1920x1080 canvas.
- **Sheets**: `ffmpeg -i bot.avi -vf "fps=2,scale=480:-1,tile=4x3" -frames:v 1 sheet.png` (what I used; a sparse sheet leaves black rows). Pick frames with `select='not(mod(n\,75))'` plus `-fps_mode vfr` (this ffmpeg rejects `-vsync`). `capture_combos.sh` is the older combo-bot wrapper (`captures/combos.avi`, stills at 4/s).
- `tools/capture_bot.sh` prints each act's log lines at the end twice (the bot prints during the run and again as a summary): not an error.

### 9.2 What exists at about 1 m
| Act | Scene | Room | What it shows |
| --- | --- | --- | --- |
| "Punk wind-up at 1 m" (`punk_bot.gd:70`) | `tests/bot/punk_bot.tscn` | training | Punk spawned 1 m ahead with the AI frozen, 30 ticks idle, `force_attack(0)` (jab then cross), recover. **Run today: `tools/capture_bot.sh res://tests/bot/punk_bot.tscn <dir> "Punk wind-up at 1 m" 6` -> exit 0, 0 errors, 228 frames, 23 stills.** First person, throat-height lens pitched 6 deg down: the Punk fills the frame from cap (cropped at the top edge) to belt. |
| "Punk shove wind-up at 1 m", "Punk two-hit punch lands" / "shove lands" / "jab hit out of the wind-up" (0.95 m), "Punk knocked down, gets up, KO" (1.0 m) | `punk_bot` | training | |
| "VFX: damage looks held at 1 m" (`vfx_bot.gd`) | `vfx_bot.tscn` | training | a dummy (not a Punk) at 1 m, still for 1 s each at 100%/65%/30% health, then a jab |
| "Final pound at 0.9 m / 1.1 m" (`final_boss_poses_acts.gd`) | `crowd_bot.tscn` | crowd | the boss, not a Punk |

None records "idle, then moving, then attacking, at 1 m" as one clip with a face-height view.

### 9.3 What a new act needs (proven today with a scratch bot [V])
No new bot scene is needed. In the crowd room: add `tests/bot/acts/look_acts.gd` with `static func acts(bot: Node) -> Array[Dictionary]` returning `{title, cam = &"first_person", fn}` (`crowd_bot._collect_acts()` loads every `*_acts.gd` in file-name order, `crowd_bot.gd:370`), then `tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/look "Look:" 6`. I ran three such acts through a scratch subclass (`extends "res://tests/bot/crowd_bot.gd"`, overriding `_collect_acts()`, started by a `-s` runner script with `--write-movie`): 887 frames, 0 errors.
- **Standing still**: `bot.god(); bot.freeze_ai(true); bot.spawn(&"punk", Vector2(0.0, 1.0)); await bot._ticks(150)` (`spawn(id, rel)` is x right / y ahead, faces the player; `crowd_bot.gd:241`). The frozen Punk plays its boxer-stance idle.
- **Attacking**: `punk.force_attack(0)` then `await bot._wait_until(func(): return punk.ai_state == EnemyActor.AiState.RECOVER, 200)` (jab+cross; index 1 is the shove).
- **In motion at 1 m is the hard part**: with the AI on and `posture_ring_min_m = posture_ring_max_m = 1.0` (`bot.tune(...)`, the slider minimum is 1.0) the Punk **attacks at once, then stands in RECOVER at 0.99 m for the rest of the act** (the 5 s `punk_attack_cooldown_s`): not a walk or circle. To see it move, script the rig: `punk.rig.play(&"<clip>", blend_s, speed)` (`humanoid_rig.gd:210`), `rig.play_locomotion(Vector2, speed_ratio)` (288) or `rig.play_move(move)` (244), or move the actor with the AI frozen. Which clip names exist is the rig-render reader's area.
- **Face at 1 m**: at 1 m the 90 deg horizontal FOV spans 2.0 m x 1.125 m (16:9, `KEEP_WIDTH`). With the default `look_pitch -6 deg` (`combo_bot._reset`, line 578) the cap is cropped at the top edge; for a face shot `await bot._look_to(+8.0, 10)` (`combo_bot.gd:570`, degrees, negative looks down) before the idle. Camera mode is picked by the act's `cam` (`&"first_person"`, `&"side_view"`, `&"free_fly"`; `_reset` cycles the director).
- **Side-by-side / reference**: spawn a second enemy at `Vector2(1.1, 1.0)`, or use `vfx_bot._act_tier_sizes`'s pattern (three posts at -1.1/0/+1.1 m at 1.4 m).
- Hide overlays: `crowd_bot._run` already hides help and the combat log; the bot's own caption `Label` sits at (560,120) on layer 50 inside the view (`combo_bot._build_caption`), so a clean hero still needs `caption.visible = false`.
- For a production-quality judgement also keep the HUD in frame (it is part of the 1 m view) and take the same act with the impact frame off (`Tuning.data.impact_frame_enabled = false`) so a finisher is not an ink print.

### 9.4 Frame time of the existing perf act
`tests/bot/acts/crowd_acts.gd:86` "Perf, six with ragdolls" (`_perf`, line 255; windows of 120 frames, 1800 ticks = 30 s of an autopilot player knocking down six enemies with a Punk topping up). It needs a **window that is not recording**: `godot --path . res://tests/bot/crowd_bot.tscn -- --act="Perf, six with ragdolls"`; it prints `PERF f<frame> window <n>: <frames> frames, mean, p95, worst ...` lines, `PERF spawn <name>: worst frame within 0.5 s`, and the readability probe's `R15 frame time p95 <= 16.7, spawn <= 33` row (wall time between `_process` calls, with the probe's own cost removed). Limits in `docs/milestones/M3-plan.md:203` (soft, "this Mac, not the SPEC §10 machine").
- **Recorded by M3**: slice gate p95 **12.2-12.3 ms**, spawn hitch **26-31.5 ms** (`M3-slice-gate.md:39`); after the named-library cache p95 **13.1 ms**, spawn hitch median 28.8 -> **25 ms** (ARCHITECTURE line 752, HANDOFF line 113). "Little margin, to watch with bigger rigs."
- **My re-run today [V]**: windowed on this M1, vsync on, 1600x900, no recording: 15 windows of 120 frames, **mean 16.6-17.5 ms, window p95 29.9-40.7 ms, worst 56.4 ms; whole run 1914 frames mean 16.8, p95 33.0**; spawn hitches 29.5-56.4 ms (21 spawns); probe R15 **p95 20.0 ms, spawn 38.9 ms, "miss"**. **This run is not a valid baseline**: the system load average was 7.45 (another reader's Blender at about 98% CPU, a ChatGPT/Codex renderer at about 100%, WindowServer 37%, plus other Godot processes). It shows how load-sensitive R15 is. M4's perf comparison must be taken on a quiet machine, the pre-M4 branch and the M4 branch back to back, the same day.

## 10. Open questions and risks for the plan
1. **Where does the outline come from for characters** (hull via separate meshes vs `next_pass` chain vs screen-space only)? Owner of `humanoid_rig.gd` must decide with the flash/damage-look rewrite; both rig-render and this area touch it.
2. **One toon shader for everything, or two** (opaque lit + the existing flash/overlay passes)? The flash overlay and damage tiles must survive (approved departures: localized flash, finisher flash after the impact frame).
3. **Edge pass: world quad (worked) vs `CompositorEffect`** (compute, can run POST_OPAQUE before transparents; not tried). The M1 cost of the depth/normal buffers (+2.3 to +3.6 ms) may need an option (a Tuning toggle for the edge pass, MSAA off + FXAA) for the Mac; the 3060 target is unmeasured.
4. **Training room**: keep it frozen with duplicated setup, or make it call `RoomKit` (smaller total change, one place for the look). All bot acts except `crowd_bot` render in it.
5. **512 px VFX PNGs** are pinned by a test and SPEC §10; a "final" quality pass inside that limit is mostly style work (halftone fills, variants per tier, ink weight matched to the 3D outline).
6. **HUD font/panels**: nothing in SPEC requires a font asset; a comic font would add an `ASSETS.md` row and a license check.
7. **First-use compile hitches** on every new material variant (the project already measured 8-16 ms per first draw): the plan should give the toon/outline/edge shaders a warm-up step and a windowed perf check.
8. **GPU time is unreadable in-engine on this Mac**; the plan's perf evidence has to be unvsynced wall time.

## 11. Verified by running (index)
- [V] `tools/gen_fx.gd` copy in a scratch project regenerated 29 SVG + 29 PNG, all `cmp`-identical to the repo, 0.8 s.
- [V] Edge pass prototype in the crowd room, first-person and side cameras, MSAA 4x; cost table in 6.3 (3 runs).
- [V] Headless parses shaders (bad `.gdshader` -> `SHADER ERROR`); `INV_PROJECTION_MATRIX` unusable in helpers.
- [V] `capture_bot.sh` on `punk_bot` "Punk wind-up at 1 m" (exit 0, 1600x900, 228 frames, 23 stills) and a scratch crowd-room "Look" bot with three 1 m acts (887 frames, 0 errors); AI-driven 1 m circling fails (attacks, then RECOVER).
- [V] `-s` runner + `--write-movie` + a scratch bot subclass works for ad-hoc acts outside the repo.
- [V] The perf act re-run (contaminated) and ten test files' baseline pass counts.
- [R] Everything else (line references, tunables, tests' contents, HUD layout) from reading; the `CompositorEffect`, LUT (`adjustment_color_correction`), `screen_space_aa` and `.gdshaderinc` routes were confirmed to exist in the class dump or docs only, not rendered.
