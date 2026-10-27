# M3 codemap: presentation and tooling

Mapped at `78ad5d4` on `m3/enemy-ai` (M2 merged, plus the lead's macOS export preset). Scope: the VFX, audio and rumble directors, the HUD as host of the rear warning, `TuningData` / `Tuning` and the F1 panel's build rule, the default preset generator, the test runner and its conventions, the bots and Movie Maker captures, and the M2 review/fix workflow scripts. Line numbers are at that commit.

**Test baseline (this mapping run):** `tools/run_tests.sh`: **537/537 pass**, 19 scripts, 29147 asserts, **GUT time 82.8 s, 92 s wall** including the import step. No `SCRIPT ERROR` or `ERROR` lines in the output. CLAUDE.md and the M2 workflow prompts still say "about 6 s". That figure is stale: budget about 1.5 minutes per full run, and more once 6-enemy integration tests land.

---

## 0. The short version for M3 builders

- **Most rear-warning pieces already exist; nobody has wired them together yet.**
  - The art: `assets/export/fx/rear_warning.png`, drawn by `tools/gen_fx.gd:500`.
  - Four tunables: `game/autoload/tuning_data.gd:551-555`.
  - The positional wind-up audio cue: `game/audio/audio_director.gd:257-279`.
  - The events: `CombatEvents.windup_started/ended` (`game/autoload/combat_events.gd:8-9`), emitted by `game/actors/combat_actor.gd:452-453, 706, 739`.
  - The kept-clear HUD corners, checked by `tests/test_ui.gd:201-213`.
  - **Missing:** the corner widget itself, the trigger geometry, the "attack range" value the trigger needs, and the end-of-warning rule.
- **`windup_ended(attacker, false)` is not the end of the warning.** It fires when the strike comes out (`combat_actor.gd:703-706`). SPEC §8 ends the flash when the attack *lands* or is interrupted.
- **New tunables appear in F1 with no UI code.** Regenerate `tuning/default.json` after adding any. Several tests pin the group layout; see §4.4 for the list. The ones that will bite M3:
  - `test_tuning_panel.gd:390` asserts that "Enemies" has no subgroups.
  - `test_audio.gd:175` asserts that "Audio" is immediately followed by "Debug".
  - `test_audio.gd:182` pins the exact Audio subgroup list.
- **The combo bot can't be reused for a new room as it stands.** It hard-codes `const ROOM := preload(test_room.tscn)` (`tests/bot/combo_bot.gd:9`) and builds it in `_ready()` (`:28-42`). A subclass can't redeclare the const. A crowd bot needs a small overridable hook in the base, or its own `_ready()`.
- **`tools/capture_combos.sh` is single-agent only.** It writes fixed shared paths (`captures/combos.avi`, `captures/stills/`, `captures/bot.log`) and hard-codes `combo_bot.tscn`. Parallel agents must call Movie Maker directly.
- **The M2 review/fix workflow scripts are reusable almost as they are**, in `docs/reviews/M2-phase3/`:
  - `workflow.js` reviews, verifies with skeptics, runs the critic, partitions and fixes.
  - `workflow-fix.js` runs fixers only.
  - `workflow-r2-close.js` closes later rounds from lead-written briefs.
  - What changes: every path, branch name and commit prefix is hard-coded to M2 (§7.4), and the `COST` constants are old-seat numbers (divide by 5).

---

## 1. Layer rules as they apply here

- `docs/ARCHITECTURE.md:5-29` sets the layers:
  - **simulation** never reads a camera; aim uses `look_yaw` and `look_pitch`;
  - **presentation** (cameras, HUD, VFX, audio, rumble, debug draw) subscribes to `CombatEvents` and reads state, but never writes game state;
  - `TimeController` is the one exception.
- `CheatMenu` (F4) is a second, documented exception (`ARCHITECTURE.md`, "CheatMenu"): it spawns actors and sets the Debug tunables.
- "Reading state" includes `PlayerCharacter.get_look_basis()` (`game/player/player.gd:183`) and `get_eye_transform()` (`:179`). The AudioDirector's listener rides exactly these (`audio_director.gd:397-406`), not the active camera.
  - **The rear warning should use the same source:** the player's look, not `get_viewport().get_camera_3d()`.
  - That way the side-view and free-fly debug cameras still show what the player would get.
- **Groups are the discovery contract:**

  | Group | Who joins it | Where |
  | --- | --- | --- |
  | `"actor"` | every `CombatActor` | `combat_actor.gd:146` |
  | `"player"` | the player | `player.gd:106` |
  | `"enemy"` | each enemy, in its own `_ready()`, not in `CombatActor` | `training_dummy.gd:74` |
  | `"vfx_director"` | `VfxDirector.GROUP` | `vfx_director.gd:40, 86` |
  | `"audio_director"` | the audio director | `audio_director.gd:121` |
  | `"rumble_director"` | the rumble director | `rumble_director.gd:42` |
  | `"camera_director"` | the camera director | `camera_director.gd:33` |
  | `"debug_draw"` | the debug draw | `debug_draw.gd:75` |
  | `"weapon"` | weapons | `weapon.gd:22` |

  - **New M3 enemy archetypes must `add_to_group(&"enemy")`.** Without it they get:
    - no over-head health bar (`enemy_health_bars.gd:62, 74`);
    - no damage look (`vfx_director.gd:390, 433`);
    - no pain grunt (`audio_director.gd:326`);
    - no magnetism target (`player.gd:700`);
    - no cheat-menu handling (`cheat_menu.gd:107, 213`).

## 2. `CombatEvents`, the bus (`game/autoload/combat_events.gd`)

- **Signals:**
  - `attack_started(attacker, move, chain_step, input_timing)` (:5)
  - `attack_whiffed(attacker, move)` (:6)
  - `hit_landed(hit: HitInfo)` (:7)
  - `windup_started(attacker, move)` (:8)
  - `windup_ended(attacker, interrupted: bool)` (:9)
  - `knocked_down` (:10), `got_up` (:11), `ko` (:12)
  - `vanished(actor)` (:15): a KO'd body blinked off for good
  - `revived(actor)` (:17)
  - `health_changed(actor, health, max_health)` (:18)
  - `actor_state_changed(actor, old, new)` (:19)
  - `grabbed(holder, victim)` (:20), `released` (:21), `thrown` (:22)
  - weapon events (:23-25), `dodged` (:26), `jumped` (:27), `landed` (:28), `quick_turned` (:29)
  - `block_started` / `block_ended` (:30-31)
  - `blocked`, `perfect_blocked`, `guard_broken`, `guard_changed` (:33-36)
- **Wind-up semantics** (the rear warning and the AI both depend on them):
  - `CombatActor.start_move(move, chain_step, input_timing, windup := false)` (`combat_actor.gd:432`) enters `WINDUP` only when `windup and move.startup > 0` (:443-444). It emits `attack_started` (:451) and then `windup_started` (:452-453).
  - At the end of startup, `_advance_move()` switches to `ATTACK` and emits **`windup_ended(self, false)`** (:703-706). **The strike is coming out now; nothing has landed yet.**
  - `_cancel_move()` emits **`windup_ended(self, true)`** only if it cancels during `WINDUP` (:736-739). It is called from `receive_hit()` whenever a move is running (:419-420), from `start_grabbed()` (:469) and elsewhere (:343, 378, 392, 508).
    - **M3 note:** SPEC §7 says light hits must not interrupt Bruiser and boss wind-ups. Today *every* accepted hit cancels the move. That is the AI/actor area's change, but it decides whether the warning's "interrupted" path fires.
  - `attack_whiffed` fires once, on the frame the active window closes, only for moves with active frames and hitboxes that hit nothing (:707-713).
  - A grab that connects emits `grabbed`, not `hit_landed`.
  - Nothing is emitted when an actor is freed mid-move (a despawn). Listeners must handle `is_instance_valid()`.
- `TrainingDummy.start_jab()` (`game/enemies/dummy/training_dummy.gd:249-254`) already starts a move with `windup = true`. **Rear-warning tests and bot acts can therefore run today, in the existing test room, with a dummy posted behind the player**, before any M3 AI exists. Its jab's startup is scaled by `Tuning.windup_mult` (:321-330).

## 3. Presentation nodes

### 3.1 How a room builds presentation

- `game/level/test_room.gd` has `@export var with_presentation: bool = true` (:35). `_ready()` (:41-46) builds the environment, the street and the actors, then `_build_presentation()` (:152-168) if presentation is on. In order, `_build_presentation()` adds:
  1. the camera director (scene, else script);
  2. `hud.tscn`;
  3. `debug_draw.tscn`, only if no `"debug_draw"` node exists yet (the HUD already holds one);
  4. `tuning_overlay.tscn`;
  5. `VfxDirector.new()`, `AudioDirector.new()` and `RumbleDirector.new()`.
- All of these are **direct children of the room**. The bots find the HUD by scanning `room.get_children()` for `set_help_visible` and `set_debug_draw_enabled` (`combo_bot.gd:72-74, 546-550`). A crowd room that nests its HUD deeper breaks that lookup.
- Tests pass `with_presentation = false` for pure simulation. `test_vfx.gd:1026-1037` asserts exactly one `VfxDirector` with presentation, and none without.
- **M3:** the new crowd room needs the same presentation set.
  - Don't copy-paste `_build_presentation()`: move it into a shared helper (for example a static `RoomPresentation.build(room)` under `game/level/`) that both rooms call.
  - A copy drifts. The F1/F4 wiring test (`test_tuning_panel.gd:935-988`) is written against the test room only.
  - The player's auto revive is `player.auto_revive = true` (`test_room.gd:133`; `player.gd:32, 634-640`), timed by `Tuning.player_revive_s` (in the "Sparring" group, `tuning_data.gd:612-613`). The crowd room should reuse both.
- The main scene is `project.godot:15` (`run/main_scene`). Switching it to the crowd room is a one-line edit to a file the lead also edits (export settings, autoloads): a hot spot.

### 3.2 Subscription patterns, priorities and time domains

| Node | Connects in | Disconnects | process_priority | Clock |
| --- | --- | --- | --- | --- |
| `VfxDirector` (`game/fx/vfx_director.gd`) | `_enter_tree()` with an is-connected guard (:114-118, `_connect()` :628-630) | `_exit_tree()` (:121-126) | `CameraDirector.PROCESS_PRIORITY + 1` = 51 (:88) | sim time (`real_dt * TimeController.sim_scale()`, :135); impact frame and line flicker in real frames |
| `AudioDirector` (`game/audio/audio_director.gd`) | `_ready()` (:148-151) | never (Godot drops connections when the node is freed) | default | real time (:42-44) |
| `RumbleDirector` (`game/audio/rumble_director.gd`) | `_ready()` (:43) | `_exit_tree()` only stops vibration (:46-51) | default | real time; drops the queued finisher pulse on pause (:54-58) |
| `GameHud` (`game/ui/hud.gd`) | `_ready()` (:44-51) | never | `HudStyle.PROCESS_PRIORITY` = 100 (`hud_style.gd:29`) | real `delta`, plus `game_delta` (0 while paused) for game-timed parts (:74) |
| `CameraDirector` | n/a | n/a | 50 (`camera_director.gd:20, 36, 41`) | real time |

- **The test seam** in every director and the HUD: `_process(delta)` just calls a public `advance(delta)` (`vfx_director.gd:129-151`, `hud.gd:59-84`). Tests turn processing off and step `advance()` by hand.
- **Process order:** anything that projects through the camera or measures from it processes after the cameras (priority above 50). `test_ui.gd:190-194` asserts this for the HUD and the debug draw.
- **Live tunables:** read `Tuning.data.x` at the moment of use. Anything cached must refresh on `Tuning.changed(property)` (`tuning.gd:26`). `VfxDirector._on_tuning_changed()` (:385-393) is the example: `&""` means everything may have changed.
- **The "writes no game state" invariant test** to copy for any new presentation node is `test_vfx.gd:891-902`. It snapshots `[health, state, global_position, sim_velocity]`, drives the node, then asserts nothing changed and no hitstop or slow-mo started.

### 3.3 `VfxDirector` API (`game/fx/vfx_director.gd`)

- Constants:
  - `GROUP` (:40);
  - canvas layers `LINES_LAYER = 5` (under the HUD's 10) and `FLASH_LAYER = 20` (over the HUD) (:42-43). The impact frame therefore inverts the HUD, rear warning included, for 2 frames on finishers.
- Spawning, public for tests and bots:
  - `spawn_pop(kind, point, size_m, seconds, priority, tex = null) -> ComicSprite` (:179)
  - `spawn_word(tier, point, on_player = false) -> ComicSprite` (:197)
  - `spawn_blood(hit)` (:238), `spawn_spit_and_tooth(hit)` (:254), `spawn_splat(point, normal)` (:268)
- Inspection and helpers:
  - `live_effects(kind = &"", motion = -1)` (:294), `clear()` (:303)
  - static `view_aspect(camera)` (:312) and `view_width_at(camera, depth)` (:319)
  - `begin_warm_up(windowed = DisplayServer.get_name() != "headless") -> bool` (:168): a windowed-only first-use warm-up. It is skipped headless, so the tests' frames never see it.
- Event handlers:
  - `_on_hit_landed` (:329-365) picks the effects by tier;
  - `_on_attack_started` (:368) watches the player's lunges;
  - `_on_health_changed` (:381) drives the damage looks (it needs `actor.rig`, :433).
- The sprite pool has no cap (`_acquire()` :588, `_retire()` :621). Blood splats are capped by `vfx_blood_splat_max`. Six enemies trading hits is fine.
- **The rear warning should not live here.** The VFX director draws world-space comic sprites and full-screen overlays on sim time. The warning is a HUD corner element whose corners the HUD already reserves.

### 3.4 `VfxArt` and the art set (`game/fx/vfx_art.gd`, `assets/export/fx/`)

- API:
  - `VfxArt.texture(name: StringName) -> Texture2D` (:24): loads `res://assets/export/fx/<name>.png` once and holds it.
  - `preload_all()` (:49): loads everything, via `ResourceLoader.list_directory`, which also works in an exported build.
  - `has(name)` (:62), `word_texture(word)` (:44), `BURSTS` (:12).
- **Rear-warning art already exists:** `rear_warning.png`.
  - What it is: a 512 px jagged red-orange star with a yellow inner star and a white "!" in ink outline (viewed while mapping).
  - Where it comes from: `tools/gen_fx.gd:499-514` (`_rear_warning()`, seed 3400), saved at :114. It is logged in `ASSETS.md:29` and listed in the art test's `ART` (`test_vfx.gd:16`), which checks it is 512 px with an SVG source (:1061-1075).
  - The "Bruiser and boss get a larger burst" rule needs no new art; scale the same texture.
- **Gotcha: drawing it small in 2D.** The import generates mipmaps (`rear_warning.png.import`: `mipmaps/generate=true`). A 2D canvas item only uses them with `texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. Without that, a 512 px texture drawn at about 120-180 px shimmers.
- **Gotcha: first-use load.** `VfxArt` loads lazily. A HUD element that draws it should call `VfxArt.texture(&"rear_warning")` in `_ready()`, so the first warning doesn't read from disk. `VfxDirector` already preloads everything when it exists, but tests build the HUD without one.
- Colour rule: red only for blood, the rear warning and finisher accents (`HudStyle` header, `hud_style.gd:4-5`; `HudStyle.FINISHER_ACCENT` :21). The warning may use red; nothing else new should.

### 3.5 `AudioDirector` API (`game/audio/audio_director.gd`)

- Signal `played(pool: StringName, voice: AudioStreamPlayer3D)` (:51) fires for every one-shot. The tests capture it.
- Exports:
  - `voice_count = 32` (:85), a voice budget. Its comment says a synthetic six-enemy brawl peaks at about 30.
  - `listen_from_player = true` (:88).
- Methods:
  - `play(pool, at, volume_db, pitch = 1.0) -> AudioStreamPlayer3D` (:169). It returns null beyond `sfx_max_distance_m`, uses the "SFX Rear" bus when `is_behind_listener(at)`, and varies pitch and volume.
  - `listener_transform()` (:196), `distance_db(at)` (:205)
  - `is_behind_listener(at)` (:212): flat angle above `rear_muffle_angle_deg`.
  - `impact_position(hit)` (:287), static `tier_db(tier)` (:298), static `layer_db(pool)` (:308)
  - static `voice_pitch(actor)` (:315): a fixed pitch per actor, hashed from its **name**.
  - `sfx_limiter()` (:438)
- **The wind-up cue, i.e. the rear warning's audio, already works** (`_on_windup_started`, :257-268):
  - It plays an `effort` at the attacker's `EyePoint` (`_voice_position()` :346) and a `whoosh` at the striking limb (`_strike_position()` :354, the move's first point hitbox).
  - Both play at `Tuning.windup_db` (`tuning_data.gd:653-655`), only while `Tuning.rear_warning_audio` is on.
  - `_windup_of[]` (:101) tags the voices, so `windup_ended(attacker, true)` cuts both at once (:271-279).
  - Direction comes from 3D panning plus the rear low-pass bus (`REAR_BUS`, created in `_ensure_buses()` :449-455).
- Pain grunts: `_grunt(actor)` (:322-342) is for the player or members of the `"enemy"` group only, rate-limited by `grunt_min_interval_ms`.
- Voice stealing: `_take_voice()` (:382-394) takes the oldest busy voice when all are busy, **including a wind-up cue**.

### 3.6 `RumbleDirector` (`game/audio/rumble_director.gd`)

- It pulses only for `hit_landed` involving the player (:97-114, `_involves_player()` :126-130).
- `pulse(weak, strong, ms)` (:71) merges with a running pulse (the stronger motor wins, the later end wins).
- `vibrate: Callable` (:25) is the test stub.
- SPEC asks for no rumble on the rear warning. Adding one would be a spec change.

### 3.7 SFX generation (`tools/gen_sfx.gd`, `game/audio/sfx_bank.gd`)

- `SfxBank` (:1-57) loads every `<pool>_<nn>.wav` in `assets/export/sfx/` by name. `pick(pool, rng)` never repeats the last variant.
- Pools today:
  - `whoosh`, `thud`, `crack`, `crunch`, `body_fall`, `sub_thump`;
  - `block_clack`, `parry_ting`, `guard_break`;
  - `grunt` (5), `player_grunt` (3), `effort` (3);
  - `music_loop`.
- To add a pool (for example a heavier effort for the Bruiser and boss): add it in `gen_sfx.gd`, next to `EFFORTS` (:92) and the `_save("effort", ...)` loop (:167). Run `godot --headless -s tools/gen_sfx.gd && godot --headless --import --quit`. The output is deterministic, seeded per file name.
- No code change is needed in `SfxBank`. `AudioDirector` picks pools by name.

### 3.8 The HUD (`game/ui/hud.gd`, `hud.tscn`): the rear warning's host

- `GameHud` is a `CanvasLayer`: layer 10, `process_mode = ALWAYS` (`hud.tscn`).
- Its parts are `@onready` children (:23-32): `PlayerHealthPanel`, `BossHealthBar`, `EnemyHealthBars`, `CenterDot`, `CombatLog`, `BlockCallout`, `CameraToast`, `HelpOverlay`, `PauseOverlay` and `DebugDraw`.
- `advance(delta)` (:70-84) steps them: real `delta` for UI fades, and `game_delta` (0 while paused) for game-timed parts.
- The events it subscribes to are wired in `_ready()` (:44-51).
- Layout (1920 x 1080 canvas, `canvas_items` stretch, `project.godot` [display]):

  | Part | Position |
  | --- | --- |
  | Player panel | bottom left |
  | Boss bar | bottom centre |
  | Combat log | right middle (`offset_top -40`) |
  | Camera toast | top centre, x 700-1220 |
  | Help | left middle |
  | Block callout | just below centre |

- **The top-left and top-right 20% x 20% corners (384 x 216 px) are reserved.** `test_ui.gd:201-213` asserts that the player panel, boss bar, combat log, camera toast and help overlay don't intersect them.
- The callout's pop-and-fade (`game/ui/block_callout.gd`) is the closest existing pattern for a pulsing corner burst. Its timing lives in `@export` node vars (:9-14), an M1 pattern. **For M3, put the warning's timings in `TuningData` "Rear warning"**: feel numbers never live in scripts.
- Pausing: `GameInput.paused_changed` drives the pause overlay. The HUD keeps processing while paused, so a warning must hold its state off `game_delta`.

## 4. Tuning: `TuningData`, `Tuning`, the F1 panel and the default preset

### 4.1 `TuningData` conventions (`game/autoload/tuning_data.gd`)

- It is a `Resource` with only exported properties, plus three tier helpers: `hitstop_s()` (:706), `shake()` (:715) and `cam_punch_deg()` (:724).
- Floats and ints use `@export_range(min, max, step)`; bools use plain `@export`. Every property has a `##` doc comment, which becomes the panel tooltip.
- `@export_group` (= a panel category, in declaration order) and optional `@export_subgroup` (= a heading inside the page).
- The groups, in order, with their line ranges:

  | Group | Lines |
  | --- | --- |
  | Player movement | 7-26 |
  | Combo windows | 28-32 |
  | Magnetism | 34-40 |
  | Grab and weapons (subgroup Hold view) | 42-81 |
  | Reactions | 83-126 |
  | Feel details | 128-147 |
  | Hit feel (subgroup Hit flash) | 149-177 |
  | VFX (7 subgroups) | 179-323 |
  | Ragdoll (8 subgroups) | 325-485 |
  | Camera (subgroup KO view) | 487-543 |
  | **Enemies** | **545-549** |
  | **Rear warning** | **551-555** |
  | Block | 557-598 |
  | **Sparring** | **600-613** |
  | Audio (subgroups Mix, Tiers, Layers, Voices, Blocks, Distance, Music, Rumble) | 615-699 |
  | Debug | 701-703 |

- **The M3 groups that already exist** (already in `tuning/default.json`):
  - "Enemies": `attacker_cap` (int 0-6, default 3, "0 = unlimited"), `blind_spot_priority` (0-1, default 1.0) and `windup_mult` (0.25-3, default 1.0; the training dummy's jab already reads it).
  - "Rear warning": `rear_warning_angle_deg` (20-120, default 55), `rear_warning_size` (0.25-3, default 1.0), `rear_warning_opacity` (0-1, default 0.9) and `rear_warning_audio` (bool, default true; it gates *all* wind-up audio, `audio_director.gd:259`).
  - "Sparring": the test room's dummy sparring values plus `player_revive_s` (:612-613).
- Feel numbers the rear warning still needs, which have **no tunable yet**:
  - the "both corners" cone (SPEC §8: plus or minus 20 degrees of directly behind);
  - the extra trigger range (+1 m);
  - the pulse count (2) and pulse length;
  - the heavy-attacker size multiplier;
  - the brightness step per extra attacker on a side.
  - All of them go in "Rear warning". Don't make them constants (CLAUDE.md "No numbers in scripts").

### 4.2 `Tuning` autoload surface (`game/autoload/tuning.gd`)

- `data: TuningData` (:61) and `signal changed(property: StringName)` (:26):
  - `&""` after `apply()`, a preset load or a reset;
  - `"moves/<id>/<field>"` after a move edit.
- Setting values:
  - `set_value(property, value)` (:80) sets one value and emits `changed`.
  - `apply(new_data)` (:88) replaces everything (tests use `Tuning.apply(TuningData.new())`).
  - `defaults()` (:95) returns the shipped defaults; don't edit them.
  - Writing `Tuning.data.x = ...` directly (the bots and some tests do) emits nothing, so cached readers won't see the change.
- Property lists:
  - `tuning_properties()` (:106, cached in a static);
  - `preset_properties()` (:114): everything outside `PRESET_SKIPPED_GROUPS = ["Debug"]` (:38);
  - `exported_properties(object)` (:142-161): adds `group` and `subgroup` to each entry.
- Presets:
  - `default_preset_dict()` (:296), `apply_preset()` (:309; clamps to range hints, skips unknown names, `_migrate()` :361);
  - `save_preset` / `export_preset` / `load_preset` (:400-427);
  - static `write_preset_file()` (:474).
  - `PRESET_FORMAT = 2` (:41). **Renaming a property silently drops it from older presets.** Add a `_migrate()` step and bump the format if you rename.
- Moves: `move_ids()`, `get_move()`, `set_move_value()` and `MOVE_GROUPS` (:45-47). M3's enemy moves in `game/combat/moves/` show up on the F1 Moves page automatically. That is good, but the move picker grows long.

### 4.3 How the F1 panel shows a group

- `TuningPanel._build()` (`game/ui/tuning_panel.gd:293-393`) loops over `Tuning.tuning_properties()` (:353-370):
  - one page per group, created on first sight (:355-356);
  - a heading whenever the subgroup changes (:357-362);
  - one `TuningField` per property (:363-370), with tooltips from `TuningPanel.doc_comments(TuningData)` (:351).
- Category buttons follow `_category_order` (:374-387); "Moves" comes last.
- **Nothing in the panel needs editing to add tunables.**

### 4.4 Recipe: add a tunable or a group

1. In `tuning_data.gd`, add `## doc` plus `@export_range(lo, hi, step) var name: type = default` inside the right group (and subgroup).
   - Make the range wide enough: preset loads clamp to it.
   - Use a new `@export_subgroup("…")` per work package, so parallel branches merge without overlap.
2. Read it at use (`Tuning.data.name`), or refresh on `Tuning.changed`.
3. Regenerate the shipped preset: `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd` (`tools/gen_default_preset.gd:1-20`; it prints `Wrote res://tuning/default.json (N values)`). Commit `tuning/default.json`.
   - `test_tuning_panel.gd:452-478` fails on a missing or stale key, a value mismatch, or any byte difference from the generator's output (:477-478).
   - After merging branches, **the lead regenerates it again**: two branches each regenerating produce a conflicting file.
4. **Test tripwires that pin the layout** (edit the test in the same commit if you change these):
   - `test_tuning_panel.gd:390`: `headings("Enemies")` must be empty. **Adding subgroups to "Enemies" breaks it.** Planned M3 subgroups (Director, Posture, per-archetype, Waves) must update this assert.
   - `test_tuning_panel.gd:391`: "Camera" headings are exactly `["KO view"]`.
   - `test_tuning_panel.gd:400`: "Hit feel" has exactly 16 rows. Don't add to Hit feel.
   - `test_audio.gd:160-182`: the group after "Audio" must be "Debug" (:175), and the Audio subgroups are exactly `Mix, Tiers, Layers, Voices, Blocks, Distance, Music, Rumble` (:182). New groups go **before** "Audio" (after "Sparring", or next to "Enemies" and "Rear warning"). A new Audio subgroup needs that list updated.
   - `test_vfx.gd:1040-1058`: any property whose name begins with `vfx_` must sit in the "VFX" group, and "VFX" must directly follow "Hit feel". Don't prefix rear-warning or AI tunables `vfx_`.
   - `test_tuning_panel.gd:1032+`: the gamepad walks every row of every category. More rows are fine; it only takes longer.
   - `test_tuning_panel.gd:583-591`: the Debug group (cheats) stays out of presets. A new cheat toggle (for example "AI frozen") belongs in "Debug" for that reason.

## 5. Test conventions

### 5.1 Runner and configuration

- `tools/run_tests.sh` (14 lines):
  - it imports first (`--headless --import --quit`, errors swallowed);
  - then runs `godot --headless --fixed-fps 60 -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"`;
  - `-gselect=<file>` runs one file;
  - it exits non-zero on failure.
- **Read the full output** for `SCRIPT ERROR` and `ERROR` lines: GUT can pass while the engine prints errors.
- `.gutconfig.json` collects `res://tests/`, `include_subdirs: true`, prefix `test_`, suffix `.gd`.
  - The bots (`tests/bot/*.gd`) and `tests/fp_view.gd` are therefore **not** run as tests.
  - `test_scripts_compile.gd:17-34` loads every `.gd`, `.tres` and `.tscn` under **`res://game` only**. **A broken bot script fails nowhere until someone records with it.** Consider a small test that loads `res://tests/bot/*.gd` (compile only).
- `--fixed-fps 60` means one physics tick per frame and no waiting on real time. Frame-timed tests are deterministic.
- Headless means:
  - `DisplayServer.get_name() == "headless"`;
  - no renderer (VFX warm-up skipped, `vfx_director.gd:168`);
  - no Movie Maker;
  - no mouse capture (`game_input.gd:51-52`).
- Baseline: **537 tests, 82.8 s GUT time** (§0).

### 5.2 Integration tests in the real test room

`test_combat_integration.gd:9-113` is the template:

- `const ROOM := preload("res://game/level/test_room.tscn")`.
- Set `room.set(&"with_presentation", false)` **before** `add_child_autofree(room)`; the default is true.
- Then:
  - `await _ticks(2)`;
  - take `player = room.get(&"player")` and set `player.input.scripted = true`;
  - place each dummy with `set_post(pos, yaw, true)`;
  - park the unused ones far away (`FAR` / `PARK`).
- `before_each`: `TimeController.clear()`, `TimeController.debug_scale = 1.0`, `Tuning.apply(TuningData.new())`, connect `CombatEvents`.
- `after_each`: disconnect, then `TimeController.clear()`. Leaking a connection makes later tests record stray events.
- Scripted input (`game/player/player_input.gd`):
  - `push_press(button, hold_ticks)` (:71), `push_wait(ticks)` (:63), `push_down` / `push_up` (:84, :92), `queued()` (:99), `clear_queue()` (:103), `scripted_move: Vector2` (:29);
  - button ids are `BUTTONS` values: `P`, `K`, `RB`, `JUMP`, `DODGE`, `GRAB`, `TURN` (:7-15).
- Turn the player with `player.look_yaw` and `look_pitch` (radians), then set `player.rotation.y = look_yaw` for an instant facing.
- Tuning tests point `Tuning.user_dir` and `export_dir` at a per-process scratch folder (`test_tuning_panel.gd:20-29`). Never write to the shared `user://tuning`.

### 5.3 Presentation unit tests

- **Audio** (`test_audio.gd:27-74`): a director is created standalone, its rng is seeded, and its listener is placed at the origin. Events are emitted directly on `CombatEvents` with plain `Node3D`s in the `"enemy"` and `"player"` groups. `played` is captured.
- **HUD** (`test_ui.gd:10-161`):
  - `FakeEnemy` extends `CombatActor`; `FakePlayer` extends `PlayerCharacter`, so `look_yaw`, `look_pitch` and `get_look_basis()` work with no rig.
  - A current `Camera3D` sits at the origin looking down -Z.
  - The HUD is instanced with `set_process(false)` and stepped with `_hud.advance(dt)`.
  - **This is the harness for rear-warning unit tests:** a FakePlayer looking down -Z, a FakeEnemy at 135 degrees left, 135 right or 180, then `CombatEvents.windup_started.emit(enemy, move)`.
- **VFX** (`test_vfx.gd`): `_land(hit)` and `_advance(seconds)` drive the director; `ART` (:16) is the art list.
- **First-person view helpers** (`tests/fp_view.gd`, preload it):
  - `camera(eye, look)` (:23), `hits(root, cam, cols)` (:41), `share()` (:155), `covered()` (:164), `nearest_mesh()` (:191), `outside_view(root, cam, margin)` (:206);
  - `HALF_H_DEG = 45` (:9) is a constant and does not follow `Tuning.fov_deg`.
  - Use these to bound how much of the first-person view six enemies (or a boss) cover.

## 6. Bots and captures

### 6.1 `tests/bot/combo_bot.gd`, the harness every bot extends

- The scene `tests/bot/combo_bot.tscn` is a single `Node` with the script. `vfx_bot.gd` and `ragdoll_bot.gd` `extends "res://tests/bot/combo_bot.gd"` and override `_run()` only.
- `_ready()` (:28-42):
  - parses user args: `--act=<text>` (`a|b` matches either) and `--tune=<property>=<number>`, which writes `Tuning.data` directly;
  - sets `Tuning.data.dummy_health = 500.0`;
  - **instantiates `ROOM` (:9, the test room)**, builds the caption and calls `_run.call_deferred()`.
- `_run()` (:65-132):
  - grabs `player`, `dummies` and `director`;
  - hides help;
  - holds a table of `{title, cam, fn}` acts (:75-117);
  - for each act whose title matches (`_matches()` :136): `_reset(cam)`, set the caption, `print("=== title (fN)")`, `await fn.call()`, `_wait_idle()`, 45 ticks;
  - at the end, prints every hit line and calls **`get_tree().quit()`, which ends the Movie Maker recording**. A bot that never quits records forever.
- Harness helpers:
  - `_stage(posts)` (:595): posts relative to the player, x right, -z ahead; the rest are parked at `PARK` (:12).
  - `_press(button, hold, gap)` (:607), `_ticks(n)` (:614), `_wait_until(cond, max)` (:619), `_wait_idle()` (:626)
  - `_turn_by(deg, ticks)` (:554), `_look_to(pitch_deg, ticks)` (:565)
  - `_reset(cam)` (:573-590): it reads `room.get(&"player_start")` and `room.get(&"player_yaw_deg")` and cycles the `camera_director` until `mode == cam`.
  - `_hud()` (:546)
  - `_on_hit()` (:45-62) logs `f<physics frame> <victim>: <move> <dmg> <tier> [BLOCKED|PERFECT|GUARD BREAK]`.
- **The closest acts to the rear warning today:**
  - "Flank hit lands" (:108, `_act_flank_hit` :517): turned 90 degrees, a dummy jab lands outside the block arc;
  - "(side view, debug draw)" (:109, :537), which turns F3 on through the HUD.
- The caption is a `CanvasLayer` at layer 50, at (560, 120) in 1920 x 1080 space, font 34 (:638-647).
  - It clears the top-left corner, but a long title can run into the top-right warning corner (x 1536 and up).
  - **Keep crowd and warning act titles short, or move the caption for those acts.**

### 6.2 Recording and stills

- **The single-agent wrapper:** `tools/capture_combos.sh "<filter>" <stills per second>`.
  - It writes `captures/combos.avi`, `captures/bot.log` and `captures/stills/*.png`, always the **same paths**, and only for `combo_bot.tscn`.
  - It runs `--write-movie ... --fixed-fps 60 --resolution 1280x720` and then ffmpeg.
- **What parallel agents do instead** (as the M2 prompts required):

  ```
  godot --path . --write-movie <own folder>/<name>.avi --fixed-fps 60 --resolution 1280x720 \
    res://tests/bot/<bot>.tscn -- --act=<title text> > <own folder>/<name>.log 2>&1
  ffmpeg -loglevel error -y -ss <t> -t <d> -i <avi> -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png
  ```

  Then LOOK at the sheet with the Read tool. Act start times come from the log's `=== title (fN)` lines.
- To judge the rear warning, crop the corners, for example `-vf "crop=iw*0.3:ih*0.3:0:0,scale=480:-1,tile=6x2"`. At 1280 x 720 the 20% corner is only 256 x 144 px.
- Constraints:
  - Movie Maker needs a window: it can't run headless. It opens a real window on this Mac and captures the mouse (`game_input.gd:51-52`).
  - This machine has 8 CPUs and 8 GB of RAM: **one Godot process per agent at a time; never leave one running.** The M2 workflow capped Godot-heavy skeptics at two at once (`godotSlot`, `workflow.js:156`).
  - `captures/` is git-ignored (`.gitignore`) and must never be committed. The scripts `touch captures/.gdignore` so Godot doesn't import AVIs.
  - The release export excludes `tests/*` and `addons/gut/*` (`export_presets.cfg`, `exclude_filter`). Bots never ship.

## 7. The M2 review/fix workflow pattern (`docs/reviews/M2-phase3/`)

### 7.1 `workflow.js`, one full round (459 lines)

| Stage | What runs | Where in the script |
| --- | --- | --- |
| Usage gate | `gate()` is a Haiku agent that calls `mcp__ccd_session_mgmt__get_usage` and returns `five_hour`, `weekly` and `five_hour_resets_at`. `launch(label, phase, est, fn)` starts work only if `est` fits below `LIMIT = 90` minus the higher window minus `reserved` (in-flight estimates). Otherwise it logs SKIPPED, leaving the work for the next account. | `:160-180`, `:16`, `:22` (old-seat costs) |
| Review | One Opus agent per lens. `COMMON` gives the shared context (state, docs, APPROVED list, OPEN WITH GAME-BOY list, code rules, tools, hardware limits). `reviewRules()`: review only, in its own detached worktree `.worktrees/m2-review-<lens>`, writes only under `captures/<folder>/`, at most 12 findings with file:line or capture evidence, a `spec_change` flag, and the files a fix touches. `FINDINGS_SCHEMA` (:36-64). Two heavy agents at a time (`heavySlot`, :155). | `:202-217`, lenses `:219-277`, `review()` `:280-299` |
| Verify | Three Sonnet skeptics per finding: reproduce (in `godotSlot`), spec and code. Each tries to refute it. **The finding survives with at least 2 confirmations**; a spec question is set when the spec skeptic says the fix needs a spec change. | `skepticPrompt()` `:303-314`, `verifyFinding()` `:316-335`, `verifyLens()` `:337-357` (gated, batches what the headroom fits, records `pending`) |
| Critic | An Opus completeness critic compares the coverage with the plan. It may write one gap-review brief, which gets one extra reviewer, verified the same way. | `:363-395` |
| Partition | Survivors (spec questions excluded) go into at most 4 packages with **disjoint files**. The exceptions are append-only shared files (`tuning_data.gd` in its own group or subgroup, `tuning/default.json` regenerated by the lead, `ARCHITECTURE.md` in its own section). Findings that need Game-boy go to `unassigned`. | `:407-421` |
| Fix | One fixer per package in `.worktrees/m2-fix-<key>` on branch `m2/phase3-fix-<key>` from the milestone branch. It owns its files, confirms each finding first, adds a failing test, re-records and LOOKs, reports spec questions instead of implementing them, commits `wip:` every 15-20 minutes and finishes with a fixed subject, then pushes. `FIX_SCHEMA` (:109-139). | `:423-445` |
| Record | A serialized Haiku scribe writes each JSON record byte for byte with a heredoc, checks it with `python3 -m json.tool`, commits and pushes to the notes branch `m2/phase3-review` (from `.worktrees/m2-review-notes`), and does `pull --rebase` on a rejected push. | `scribe()` `:182-199` |

### 7.2 `workflow-fix.js`, fixers only, resumable (219 lines)

- Args (:11-21): `only`, `max_fixers`, `note`, `packages_file`, `fixer_cost`, `fixer_model` (`"sonnet"`; Game-boy's model policy) and `concurrency`.
- A Haiku loader reads the packages file from the notes branch and labels each package by its branch's commit subjects (:171-183):
  - `done`: the final "review fixes (<key>" commit is there;
  - `wip`: the branch exists without it;
  - `new`: no branch.
- **A cut-off run is resumed by rerunning the same args**: done packages are skipped, and wip branches are reused (`fixerPrompt()` :187-199). Within one session, `resumeFromRunId` also works (HANDOFF entries).

### 7.3 `workflow-r2-close.js`, later rounds

- Args are documented at :13-37. The useful ones:
  - `review_briefs` (`{lens: brief}`) skips the critic and runs lead-written lenses;
  - `round` puts `r<n>` into file names and keys;
  - `common_note`, `partition_lenses` and `partition_note`;
  - `reviewer_model` (default opus), `fixer_model`, `fixer_cost` and `no_fix`.
- The lead first makes each reviewer worktree detached at the base sha and imports it (:35-38).
- The exact launch args were saved as `args-*.json` next to the records (`args-r3-review.json`), so a takeover can relaunch them verbatim. **Keep that habit in M3.**

### 7.4 What to change before reusing these for M3

- **Hard-coded M2 strings everywhere:**
  - `NOTES = .worktrees/m2-review-notes` and `REVIEWS = docs/reviews/M2-phase3` (`workflow-fix.js:24-25`, `workflow-r2-close.js:41-42`, `workflow.js:15`);
  - the notes branch `m2/phase3-review` (scribe and loader prompts);
  - the fix base branch `m2/hit-feel` (`workflow-fix.js:194`, `workflow.js:433`);
  - worktree and branch prefixes `m2-fix-` and `m2/phase3-fix-`;
  - the commit subject `"M2 phase 3: review fixes (<key>"`, which **the loader's done detection matches on** (`workflow-fix.js:50, 174, 197`);
  - the review worktree prefix `m2-review-`.
  - Make these constants (or args): `MILESTONE='m3'`, `BASE_BRANCH='m3/enemy-ai'`, `NOTES_BRANCH='m3/review'`, `REVIEWS='docs/reviews/M3'`. Copy the scripts to `docs/reviews/M3/` and don't edit the M2 records in place.
- **`COMMON` is M2's state.** Rewrite it for M3:
  - the merged work packages;
  - APPROVED: Game-boy's M3 answers and the defaults the lead took (HANDOFF 17:05);
  - OPEN WITH GAME-BOY: none during M3; take defaults and log them in `docs/milestones/M3-judgement-calls.md`;
  - the test time (about 90 s, not 6 s).
- **`COST` constants are old-seat numbers:** `reviewer 18, fixer 25, perFinding 2, critic 4, partition 4` (`workflow.js:22`; `workflow-r2-close.js:49`; `workflow-fix.js:28` default 25). On the premium seat divide by 5. HANDOFF's table (`docs/HANDOFF.md:974-990`) says about 3% per review-only agent, about 5% per fixer, 6-10% per WP4-sized builder. Re-measure, as that table asks.
- **Concurrency:** HANDOFF allows about 6 heavy agents while the 5-hour window is under 60%, and 2 above it. Godot-bound agents (recorders, reproduce skeptics, perf probes) should stay at about 2 on this 8 GB machine. Keep `godotSlot` separate from `heavySlot`.
- **Suggested M3 lenses:**
  1. code: AI, director, nav and spawner layer rules; no feel numbers; events on despawn;
  2. crowd readability in first person: 6-enemy captures; spread, posture, tells; armour reads; nothing filling the view;
  3. **rear warning correctness**: behind-left, behind-right and directly behind; several attackers per side; heavy attackers; the end on land, whiff and interrupt; KO view; pause; audio direction;
  4. performance: 6 AI with navigation, ragdolls and VFX, windowed;
  5. boss and enemy grabs on the player: the mash break-free, phase 2, the Punk call-in.
  - Only first-person looks count (Game-boy). Side view is debug only.

## 8. M3 answers for this area

### 8.1 Where the rear-warning UI fits

**Home:** a new `game/ui/rear_warning.gd` (`class_name RearWarning extends Control`), a child of `hud.tscn` anchored full-rect, drawing up to two bursts in the top corners.

Wiring:
- an `@onready var rear_warning: RearWarning = $RearWarning` in `hud.gd` (next to :23-32);
- stepped from `GameHud.advance()` (:70-84);
- covered by the "every part" test (`test_ui.gd:174-199`) and a new test that the bursts stay inside the reserved corner rects (mirror `test_ui.gd:201-213`).

It stays presentation: it subscribes and reads, and writes nothing.

**Inputs:**
- `CombatEvents.windup_started(attacker, move)` starts a warning candidate (`combat_actor.gd:452-453`).
- The end of the warning (SPEC §8: "when the attack lands or is interrupted") is any of:
  - `hit_landed` with `hit.attacker == attacker` (blocked hits included);
  - `attack_whiffed(attacker, _)`;
  - `windup_ended(attacker, true)`;
  - `grabbed(attacker, _)` (enemy grabs);
  - `ko` or `vanished` of the attacker;
  - or, as a catch-all polled each frame, the attacker freed, or `attacker.current_move != move`.
  - **Not** `windup_ended(attacker, false)`: that is the strike coming out (`:703-706`).
- The player comes from `get_tree().get_first_node_in_group(&"player")` (the `PlayerHealthPanel` does the same, `player_health_panel.gd:73`). Its look comes from `get_look_basis()` (`player.gd:183`), its position from `global_position` or `get_eye_transform()`.

**Trigger geometry (SPEC §8):**
- Take the flat angle between the look's forward (`-basis.z`, y = 0) and the direction to the attacker.
- If the angle is above `Tuning.rear_warning_angle_deg` (55) and the distance is at most attack range + `rear_warning_*_range` (new tunable, 1 m), show the warning.
- The side is the sign of the flat cross product: behind-left goes top-left, behind-right top-right.
- Within a new tunable (20 degrees) of 180, **both** corners light.
- Evaluate it at wind-up start. Decide (and log the call) whether a warning already showing follows the player turning during the wind-up. SPEC says the flash appears at wind-up start; re-evaluating each frame is the friendlier read.

**Several attackers:** each corner shows one burst; its brightness rises with the count on that side. That needs a new tunable for the step, capped by `rear_warning_opacity`.

**Size:**
- `rear_warning_size` times a base pixel size. The base belongs in `TuningData`, not as a script constant.
- Heavy attackers (Bruiser, boss) multiply it by a new tunable. The attacker must expose a heavy flag, for example a property on its archetype data. **That is an interface with the enemy package: agree on the name in the plan.**

**Pulse:** two pulses (new tunables for the count and length), timed by `delta * TimeController.sim_scale()`:
- the wind-up is counted in sim frames, so the F4 0.25x scale and slow-mo stretch both together;
- held while paused, which means using `game_delta` (`hud.gd:74`), because the HUD keeps processing.

**Open interfaces the plan must settle** (they cross into the AI and enemy area):
1. **The "attack range" value.** `MoveData` has no range field (`game/combat/move_data.gd:6-78`). Options:
   - a per-archetype `attack_range_m`;
   - or a shared helper that derives reach from the move's hitboxes plus lunge.
   - The AI's "close enough to swing" rule should use the same number.
2. **A single "outside the player's view" helper**, shared by the director's blind-spot priority and the warning, so the two never disagree. One way: a static function taking the player and a point, returning the flat angle off the look (for example on `PlayerCharacter` or in `game/combat/`). It is simulation-safe: it uses the look, not a camera.
3. **The heavy flag** for the larger burst.
4. **Suppressing warnings during the player's KO view, and while the player holds an enemy.** This is a judgement call to log. A KO'd player can't react, so suppress then.

**Tests to write:**
- unit tests on the `test_ui.gd` fakes for behind-left, behind-right, directly behind (both corners), in view (none), out of range (none);
- the end on hit, whiff, interrupt, grab and free, and **not** on `windup_ended(false)`;
- two attackers on one side brighten one burst; a heavy attacker gets the larger burst;
- the tunables are read live;
- pause holds it;
- it writes no game state (copy `test_vfx.gd:891`);
- an integration test in the real test room with presentation on: post a `TrainingDummy` behind-left, behind-right and behind the player (`_stage` style, `set_post()`), call `start_jab()`, and assert the corners, then the end when the jab lands or is blocked.
- This needs no M3 AI, so the warning package can run in parallel with the AI build.

### 8.2 Where the audio cue fits

- **It is already done for any actor that uses `start_move(..., windup = true)`.** The effort plays at the eyes and the whoosh at the limb, positional and rear-muffled, gated by `rear_warning_audio` and cut on interrupt (`audio_director.gd:257-279`). M3 enemies must start their attacks through `start_move(move, …, windup = true)` with `move.startup > 0`, or there is no cue (and no warning).
- **M3 follow-ups in this file:**
  - The voice budget: six enemies add 2 wind-up voices each, plus hits on top of a 32-voice pool (`:85`), and `_take_voice()` steals the oldest, including a wind-up cue that may still be the only warning. Options: raise `voice_count`, or make `_take_voice()` prefer non-wind-up voices. Measure with a 6-enemy fight (connect to `played`).
  - Voices per archetype: `voice_pitch()` hashes the node **name** (`:315-319`). Spawned enemies named `Enemy1`, `Enemy2`… get stable but arbitrary pitches. A deeper Bruiser or boss voice needs either a pitch per archetype or new pools (§3.7).
  - Grunts need the `"enemy"` group (`:326`).
  - `rear_warning_audio` mutes every wind-up, in front of the player too (`:259`). That matches SPEC §8's "audio on/off" literally; record it as a judgement call if kept.
  - **Don't add a UI beep or sting.** SPEC §8 makes the wind-up's own grunt and whoosh the cue, so a sting would be a spec change.

### 8.3 What a crowd-fight bot and its captures need

- **A base-class hook:** `combo_bot.gd` hard-codes `ROOM` (`:9`) and instantiates it in `_ready()` (`:38`). The smallest shared change:
  - turn `:38` into `room = _room_scene().instantiate()`, with `func _room_scene() -> PackedScene: return ROOM`;
  - a `tests/bot/crowd_bot.gd` (`extends "res://tests/bot/combo_bot.gd"`) overrides `_room_scene()` and `_run()`.
  - `_ready()` also forces `dummy_health = 500` (`:37`), which is harmless for enemies.
- **The crowd room's contract for bots:**
  - direct-child HUD and directors, as in §3.1;
  - `player`, `player_start` and `player_yaw_deg` properties (`_reset()` reads them, `:578-581`);
  - `with_presentation`;
  - an enemies list or spawner the bot can query;
  - **controls to stop the repeating waves and to spawn a given archetype at a spot relative to the player**;
  - a seed for every AI and director random generator, so recordings repeat;
  - a scripted-attack hook on enemies (like `TrainingDummy.start_jab()`) to force a wind-up now;
  - an AI-freeze toggle for staged warning acts.
- **Acts to have** (first person unless marked; Game-boy judges only first person):
  1. **Rear warning, staged:** one enemy each at behind-left (about 135 degrees), behind-right and directly behind (180), plus one at 50 degrees as a negative control; then two on one side (brighter); then a heavy one (larger). The player stands still. Combat log hidden, help hidden; crop sheets of the corners.
  2. **The 6-enemy fight, observed:** god mode (`Tuning.data.god_mode = true`, which presets skip) or rely on auto-revive. The player turns slowly through 360 degrees, then fights an autopilot loop: face the nearest posturing enemy, chain P P P P, block or dodge when a wind-up starts in view.
     - What it shows: spread, posture ring, token holders attacking, flankers circling to the blind side, warnings firing.
     - Keep the autopilot in the bot, never in game code.
  3. **The director in debug view:** the same fight with F3 on (`_hud().set_debug_draw_enabled(true)`, as in `combo_bot.gd:537-544`) in side view or free fly, to read the AI-state labels and token holders over the heads (debug only).
  4. Per-archetype tells: the Punk, Kicker, Pipe Thug (and the pipe drop and pickup), Bruiser armour, enemy grab with a mash break-free, boss phase 2 and its Punk call-in.
- **Logging for the reviewer:** besides `_on_hit()`, log:
  - `windup_started` and `windup_ended` per enemy with the physics frame;
  - the warning's side and start/end (a signal on `RearWarning`, for example `shown(side, count)`, that the bot prints);
  - AI state changes and token grants (`actor_state_changed`, plus whatever director signal the AI package adds).
  - "Fires correctly behind-left, behind-right and directly behind" can then be checked from the log as well as from the frames.
- **The recording command:** the direct Movie Maker line in §6.2 with `res://tests/bot/crowd_bot.tscn`.
  - Keep acts to about 10-20 s each. 1280 x 720 MJPEG grows fast.
  - Add a bot-agnostic wrapper (for example `tools/capture_bot.sh <bot> <out dir> [filter] [stills fps]`) rather than changing `capture_combos.sh`'s fixed paths, which other docs reference.
- **Performance:** with the crowd act running windowed, sample `Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` for 6 enemies with navigation, ragdolls and VFX. M2's perf lens method is at `workflow.js:269-275`: median of 3 or more, in-run A/B, note the machine load.

### 8.4 The review/fix pattern to reuse

The pattern used in M2, kept for M3 with the changes in §7.4:

1. **Build** work packages in parallel worktrees (`git worktree add .worktrees/m3-<wp> -b m3/<wp> m3/enemy-ai`, then `godot --headless --import --quit` in each). Each package owns disjoint files. Sonnet builders, with lead-written briefs (M2 used `docs/milestones/M2-plan.md` WP sections and `M2-WP4-brief.md`).
2. **Merge.** The lead merges, regenerates `tuning/default.json`, runs the full tests (all pass, no `SCRIPT ERROR` or `ERROR`) and records first-person sheets of the merged build.
3. **Review round** (`workflow.js`, M3 copy): Opus lenses in detached `.worktrees/m3-review-<lens>`; three Sonnet skeptics per finding (survives with at least 2); critic; partition into at most 4 disjoint packages; Sonnet fixers in `.worktrees/m3-fix-<key>`; a Haiku scribe records JSON on the notes branch. Every launch is gated against the 90% headroom.
4. **Later rounds** (`workflow-r2-close.js`, M3 copy) from lead-written `review_briefs`. Fixers only, resumable: `workflow-fix.js` with the same args.
5. **Docs and PR:** README "Where M3 departs from the spec", ARCHITECTURE sections, the judgement-call log, then the PR, which is never merged without Game-boy.

## 9. Conflict hot spots (files several M3 packages will want)

| File | Who wants it | How to avoid the conflict |
| --- | --- | --- |
| `game/autoload/tuning_data.gd` | AI, director, spawner and waves, archetypes, boss, rear warning, grabs | One `@export_subgroup` per package inside "Enemies" (and "Rear warning" for the warning). Append only, never reformat. New groups go before "Audio". |
| `tuning/default.json` | everyone who adds a tunable | Each branch regenerates it for its own tests. **The lead regenerates it after every merge.** Never hand-merge it. |
| `tests/test_tuning_panel.gd` | anyone adding Enemies subgroups (`:390`), the crowd room's F1/F4 wiring (`:935-988`) | One owner edits the `:390` assert. A shared room-presentation helper keeps the overlay test valid. |
| `game/level/test_room.gd` (`_build_presentation()` :152-168) and the new crowd room | the room and spawner package, presentation additions | Extract the presentation builder once, early, then add to it in one place. |
| `game/ui/hud.gd`, `game/ui/hud.tscn` | the rear warning; maybe a boss bar hookup (`show_boss()` :88); a wave or enemy counter | The rear-warning package owns them. Others ask it, or the lead merges. `.tscn` merges are fragile: one owner. |
| `tests/test_ui.gd` | the rear warning (parts and corner tests), the debug draw (AI labels, tokens), the help overlay (a new room-switch key) | Append new test functions only. Don't edit the fakes' shared shape without coordinating. |
| `game/ui/debug_draw.gd` | F3: AI state and token holders | The AI package adds text through `debug_state_text()` overrides (`combat_actor.gd:531`, `training_dummy.gd:257`). Token markers need a debug-draw change by one owner. |
| `game/ui/cheat_menu.gd` | F4 "spawn any enemy" (today `spawn_dummy()` :189 with `DUMMY_SCENE` :10; `reset_dummies` :211 and `remove_spawned` :226 are dummy-typed) | One owner. Generalize to a spawn list built from an archetype registry. |
| `game/autoload/game_input.gd` (`BINDINGS` :9-42) plus `game/ui/help_overlay.gd` (`DEBUG_ROWS` :28) plus `test_ui.gd:504-512` | the "back to the training room" key, possibly a wave-control key | One owner adds the actions, the help rows and the test together. |
| `game/audio/audio_director.gd` | the voice budget, archetype voices | Small and owned by whoever touches audio. The wind-up code itself needs no change. |
| `game/player/player.gd` | grabs on the player (mash break-free), the shared "outside the view" helper, the KO-view interplay | It is the hub file M2's merges kept colliding in. Keep new code in a clearly separate section, or put helpers in a new file. |
| `game/actors/combat_actor.gd` | armour (light hits not cancelling heavy wind-ups, `:419-420`), the enemy base | One owner (the AI and actor package). The warning only depends on its events staying as they are. |
| `tests/bot/combo_bot.gd` | the crowd bot's room hook | One tiny change (`_room_scene()`), made once by the bot owner. |
| `project.godot` (`run/main_scene` :15) | the crowd room becoming the main scene | The lead does it at merge time. The lead also edited `project.godot` for the export (`78ad5d4`). |
| `docs/ARCHITECTURE.md` | every package | Each package in its own section. Append only. |

## 10. Traps and gotchas, collected

1. **`windup_ended(false)` is the strike coming out, not the attack landing.** Ending the warning there cuts it before contact.
2. **`receive_hit()` cancels any running move** (`combat_actor.gd:419-420`). Bruiser and boss armour changes this. The warning's interrupt path follows whatever the actor does, so test both.
3. **The trigger must come from the player's look, not the active camera.** Otherwise side view and free fly change when warnings fire, and the director's blind-spot check and the warning can disagree.
4. **No attack-range field exists anywhere.** "Attack range + 1 m" needs a new interface, agreed between the AI and warning packages.
5. **Feel numbers:** SPEC §8 lists four tunables, but the warning needs about six more numbers (the both-corners cone, the range bonus, the pulse count and length, the heavy scale, the brightness step). All go in `TuningData`, not in `@export` node vars or constants.
6. **Layout tripwire tests** (§4.4): Enemies with no subgroups (`:390`), Audio followed by Debug (`:175`), the Audio subgroup list (`:182`), `vfx_*` names only in VFX (`test_vfx.gd:1049`), Hit feel's 16 rows (`:400`).
7. **`tuning/default.json` must be byte-identical to the generator's output** (`test_tuning_panel.gd:477-478`). Regenerate it; never hand-edit or hand-merge it.
8. **Direct writes to `Tuning.data.x`** (the bots' `--tune`, test setups) emit no `changed`. Code that caches a tunable won't see them; read at use.
9. **A 512 px texture drawn small in 2D** needs `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, or the corner burst shimmers. Preload it in `_ready()`.
10. **The impact frame (canvas layer 20) draws over the HUD (layer 10).** A finisher inverts the warning for 2 frames. That is fine, but don't put the warning above layer 20.
11. **The HUD runs while paused** (`PROCESS_MODE_ALWAYS`). Time the warning on `game_delta` and sim scale, or it pulses through a pause.
12. **The voice pool steals the oldest voice**, which may be a wind-up cue in a 6-enemy fight. Measure it.
13. **`voice_pitch()` keys on the node name.** Renaming or numbering spawned enemies changes their voices.
14. **New archetypes must join `"enemy"`.** Without it: no health bars, damage looks, grunts, magnetism or cheat handling.
15. **`combo_bot.gd`'s `const ROOM`** can't be overridden by a subclass. Add a virtual `_room_scene()`.
16. **Bots must `get_tree().quit()`**, or the Movie Maker recording never ends. Guard long autopilot acts with `_wait_until(..., max_ticks)`.
17. **`tools/capture_combos.sh` uses fixed shared paths and only `combo_bot.tscn`.** Never use it from parallel agents.
18. **Bot scripts aren't compiled by any test** (`test_scripts_compile.gd` covers `res://game` only), and `.gutconfig.json` only runs `test_*`.
19. **The bot caption** at (560, 120), font 34, can run into the top-right warning corner with long titles.
20. **Six enemies with navmesh in integration tests:** the full suite already takes about 83 s. Keep new crowd tests short (seeded, a few hundred ticks). A navigation map needs at least one sync after the navmesh is set before agents path, so tests must `await` physics frames first.
21. **Only first-person looks count** (Game-boy). Judge readability and the warning from first-person captures. Side view and F3 are debugging aids.
22. **The M2 workflow scripts hard-code M2 paths, branches and the commit subject the loader detects.** Copying them without editing writes M3 records to M2's notes branch and fixes off `m2/hit-feel`. Their `COST` numbers are five times too high for the premium seat, and their prompts still say tests take about 6 s.
23. **The F4 cheat menu's spawn and reset are typed to `TrainingDummy`** (`cheat_menu.gd:189-237`). "Spawn any enemy" needs a generalization, not a second copy.
24. **The release export keeps scripts as text** (`script_export_mode=0`), so F1 tooltips work in the playable build, and it **excludes `tests/*`**. Nothing under `tests/` may be needed at runtime.
