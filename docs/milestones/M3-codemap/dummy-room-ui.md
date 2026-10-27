# M3 codemap: the training dummy, the test room and the debug UI

Mapped at `3f5a866` on `m3/enemy-ai` (M2 merged). Read-only survey for the Milestone 3 planners and builders. Every `file:line` is at that commit. Section 9 answers the five M3 questions; section 10 lists the conflict hot spots; section 11 lists the traps.

Files in this area:

| File | Lines | What it is |
| --- | --- | --- |
| `game/enemies/dummy/training_dummy.gd` | 522 | `TrainingDummy extends CombatActor`: posts, walk home, KO comeback, sparring (the only "AI" that exists) |
| `game/enemies/dummy/training_dummy.tscn` | 7 | A bare `CharacterBody3D` with the script and `display_name = "Dummy"`. No children: `CombatActor._ensure_body()` builds the capsule and rig in code |
| `game/level/test_room.gd` / `.tscn` | 205 / 6 | The M1/M2 room, built entirely in code. It is the main scene today (`project.godot:15`) |
| `game/autoload/game_input.gd` | 135 | Input map (`BINDINGS`), mouse capture, pause and restart. A contract file |
| `game/ui/tuning_overlay.gd` / `.tscn` | 267 | The embedded Window that hosts F1 (`TuningPanel`) and F4 (`CheatMenu`) |
| `game/ui/cheat_menu.gd` | 443 | `CheatMenu`: F4 cheats, spawning a dummy at the crosshair |
| `game/ui/debug_draw.gd` / `.tscn` | 441 / 7 | `CombatDebugDraw`: F3 lines and labels in 3D |
| `game/ui/hud.gd` / `.tscn` | 161 / 148 | `GameHud` (CanvasLayer 10): owns and drives every HUD part |
| `game/ui/hud_style.gd` | 122 | `HudStyle`: shared colors, fonts, slanted-panel drawing, `PROCESS_PRIORITY` |
| `game/ui/enemy_health_bars.gd` | 232 | Over-head bars for anything in group `"enemy"` |
| `game/ui/player_health_panel.gd`, `boss_health_bar.gd`, `combat_log_overlay.gd`, `block_callout.gd`, `help_overlay.gd`, `camera_mode_toast.gd`, `center_dot.gd`, `pause_overlay.gd` | 32-199 each | The other HUD parts |

---

## 1. The training dummy (`TrainingDummy`)

### 1.1 Startup and its invariants

`_ready()` is at `training_dummy.gd:72-83`. The order matters:

1. `team = 1` and `add_to_group(&"enemy")` (`:73-74`) run **before** `super._ready()`. `CombatActor._ready()` calls `_set_ghost(false)` (`combat_actor.gd:158`), which picks the body layer from `team` (`combat_actor.gd:1447-1449`).
2. `max_health = Tuning.data.dummy_health` (`:75`) also runs before `super._ready()`, because the base copies it into `health` (`combat_actor.gd:147`).
3. `super._ready()` joins group `"actor"`, builds the capsule and the rig (`_ensure_body()`, `combat_actor.gd:1457-1479`, which calls the `_configure_rig()` hook), and emits `health_changed` deferred.
4. `_home = global_position` and `_home_yaw = rotation.y` (`:77-78`). **The post is wherever the body stands at `_ready()`**, so a spawner must set `position` before `add_child()`. The test room (`test_room.gd:140-144`) and the cheat menu (`cheat_menu.gd:200-202`) both do.
5. `_rng.seed = hash(String(name))` (`:79`). The jitter is deterministic only if the name is set before `add_child()`. The test room uses `"Dummy%d"` (`test_room.gd:137`) and the cheat menu `"SpawnedDummy%d"` (`cheat_menu.gd:197`).
6. The jab is loaded with `load(DUMMY_JAB_PATH)` (`:80-81`). `Tuning` holds every move in `game/combat/moves/` for the session, so this is the same shared `MoveData` that F1 edits.
7. `Tuning.changed.connect(_on_tuning_changed)` (`:83`). The handler (`:89-99`) drops the wind-up-scaled jab on `&""` or `moves/dummy_jab/*`, and rescales `max_health` from `dummy_health`, keeping the share of health left.

The exports (`:27-36`): `face_player`, `return_home`, `color` and `accent` (applied to the rig in `_configure_rig()`, `:124-126`), and `sparring`. Its setter re-arms the jab clock.

### 1.2 The tick

`CombatActor._physics_process()` (`combat_actor.gd:163-202`) runs whole sim ticks scaled by `TimeController.scale_for(self)`. Each `_sim_tick()` (`combat_actor.gd:634-656`) runs in this order: timers, reaction timers (`_tick_reaction_timers()`, `:664-697`; the KO branch calls `_tick_ko_blink()` and then `_tick_ko()`, `:691-694`), `_advance_move()`, **`_tick_control()`**, then `_apply_move_frame()`.

The dummy overrides `_physics_process()` (`training_dummy.gd:102-105`) only to call `_turn_solid()` before `super`.

`_tick_control()` (`:129-152`) runs once per sim frame:

1. It finds the player with `get_first_node_in_group(&"player")`, every tick.
2. `_sparring_partner(player)`, then `_tick_spar_clock(partner)`, which runs in every state.
3. If `state != FREE`: it clears `_idle_frames` and the walk-home give-up, and returns. Hit reactions, wind-ups and attacks are all owned by `CombatActor`. **AI code must do the same: act only in FREE.**
4. With a partner: `_spar(partner)`.
5. Otherwise it counts idle frames, tries `_walk_home()`, and if it doesn't walk it stands still, turns toward the player at `dummy_face_turn_rate` (`_turn_toward()`, `:518-522`) and plays idle locomotion.

Motion contract: the dummy writes `sim_velocity.x/.z`, and `CombatActor._integrate()` (`combat_actor.gd:1297-1325`) applies it scaled. In FREE, WINDUP and ATTACK the body is "self-propelled" (`combat_actor.gd:1327-1336`): `move_and_slide()` does **not** write the slid velocity back, so a walker pushed into a wall keeps pushing. That is why the walk home has stall detection. Facing is written straight to `rotation.y` (`_turn_toward()`; yaw `atan2(-dir.x, -dir.z)`, so characters face −Z).

### 1.3 Sparring (the closest thing to AI)

These functions are the approach, step-in and wind-up pattern that M3's archetypes generalize.

| Step | Code | Rule (defaults) |
| --- | --- | --- |
| Partner? | `_sparring_partner()` `:267-278` | `sparring`, a jab loaded, `player.can_be_hit_by(self, jab)` (not KO'd, dodging, flying or blinking in; `combat_actor.gd:273-280`), within `sparring_range` (1.7 m) and `sparring_facing_deg` (30°) of the dummy's facing. **It never engages a player behind or beside it.** |
| Clock | `_tick_spar_clock()` `:284-289` | `_spar_wait` counts down while there's a partner, during its own jab, or during its blocked recoil (`_recoiling` in HITSTUN). It's re-armed at each jab's start (`start_jab()`), so the interval runs start to start. |
| Wait length | `_next_spar_wait()` `:336-339` | `sparring_interval_s` (2.0 s) ± `sparring_jitter_s` (0.3 s), seeded per dummy |
| Approach | `_spar()` `:294-300` | Walks straight at the player (`_walk()`, `:313-318`, at `dummy_walk_speed` 2.5 m/s, turning at `dummy_face_turn_rate` 4 rad/s) until within `sparring_step_in_m` (0.9 m). It doesn't pathfind or flank. |
| Hold | `_spar()` `:301-308` | Zeroes horizontal velocity, faces the player, and jabs when the clock is due |
| Wind-up | `start_jab()` `:249-254` → `start_move(move, 1, &"root", true)` | The `windup = true` flag runs the startup frames in `ActorState.WINDUP` and emits `CombatEvents.windup_started` (`combat_actor.gd:443-453`). At startup's end it enters ATTACK and emits `windup_ended(self, false)` (`combat_actor.gd:703-706`). Hit or grabbed out of it, it emits `windup_ended(self, true)` (`_cancel_move()`, `combat_actor.gd:736-739`). |
| Wind-up scaling | `_jab_move()` `:322-332` | A `duplicate()` of the jab with `startup = max(1, round(startup * windup_mult))`. It's cached and rebuilt when `windup_mult` changes (`_scaled_for`) or when the jab is edited (`_on_tuning_changed`). |
| The jab | `tools/gen_moves.gd:241-244` → `dummy_jab.tres` | 24/3/16 frames (0.4 s wind-up), 6 damage, LIGHT, FLINCH, `magnetism = false`, `blocked_recoil_frames = 20`, right-fist sphere 0.14. Its reach is about 1.05 m (comment at `tuning_data.gd:609-610`). |

Public timing hooks for bots and tests:
- `spar_in(frames)` (`:244-245`) times the next jab.
- `start_jab()` (`:249`) starts the telegraphed jab now, from FREE, **wherever the player stands**. This is the easy way to test the rear warning without any AI: post a dummy behind the player and call it.

### 1.4 The walk home

`_walk_home()` (`:163-191`), with the tunables at `tuning_data.gd:111-126`:
- It walks only after `dummy_return_idle_s` (1 s) of FREE with no partner, when it's more than `dummy_return_slack_m` (0.3 m) from the post, and the post has room (`_home_has_room()`, `:211-216`).
- It waits, facing the player, while a standing body is within `dummy_return_look_ahead_m` along the way (`_body_in_the_way()`, `:198-206`: the capsule is cast against the player and enemy body layers).
- Stall detection: if it gets no nearer than the best so far (1 mm noise) for `dummy_return_stuck_s` (0.25 s), it gives up and remembers where (`_home_gave_up_at`). It doesn't retry until it's hit (any non-FREE state clears this, `:135`) or moved `dummy_return_retry_moved_m`.
- It returns true when it walked this tick.

### 1.5 KO, blink-off, comeback

- `CombatActor` owns the KO. The body is limp for `ko_linger_s`, blinks for `ko_blink_s`, then `_vanish()` (`combat_actor.gd:1122-1134`): hidden, no hurtboxes, `collision_layer = 0`, `CombatEvents.vanished`. It stays in state KO and in its groups.
- `_tick_ko()` (`training_dummy.gd:342-347`) waits `dummy_revive_s` counted in `_gone_frames` (from the blink-off), then asks for `_respawn_spot()`.
- `_respawn_spot()` (`:361-423`) returns the post if it has room. Otherwise it picks from 8 directions (`_GETUP_DIRECTIONS`, `combat_actor.gd:52`) on ring 1, then ring 2, each `2 * body_radius + dummy_respawn_gap_m` apart. A spot needs room, an unobstructed way from the post (`_way_query`) and floor under it (`_floor_query`).
  - Ranking: in front of or beside the player first, then the farthest from him, then the angle off his facing nearest `dummy_respawn_off_axis_deg` (50°).
  - It uses `player.get_forward()`, the simulation's facing, **never a camera**.
  - It returns `Vector3.INF` while there's no spot, and the dummy waits.
- `_respawn(spot)` (`:506-514`) re-reads `max_health`, calls `set_post(spot, _home_yaw, true)` and restores the original post, stays a ghost until the blink-in ends and nobody stands inside it (`_solid_when_clear`), then emits `CombatEvents.revived` and calls `blink_in()` (`combat_actor.gd:232-237`).

### 1.6 Room queries (reusable spawn-safety logic)

| Function | Lines | Checks |
| --- | --- | --- |
| `_build_room_queries()` | `:478-500` | Builds four cached queries from a capsule of `body_radius`/`body_height`, all excluding self: `_room_query`, `_way_query` (world only), `_floor_query` (world ray) and `_ahead_query` (player and enemy bodies) |
| `_has_room(space, spot)` | `:430-461` | No world, standing, ghost or downed body in the capsule at `spot`. No actor blinking in within the two radii. No **drawn** lying, flying or ragdolled body (its trunk, legs and arms as rig-point segments, `_DRAWN_LIMBS` `:22-25`) within the two radii. Reads `rig.get_visual_point_transform()`, which is presentation-side pose data; that's tolerated here. |
| `_standing_body_inside()` | `:465-474` | A solid body overlaps it where it stands (used before turning solid) |

**There is a second, different clear-spot test** in `CheatMenu._spot_clear()` (`cheat_menu.gd:369-395`). It checks the world-only capsule, `spawn_actor_clearance_m` to actor origins, floor rise and line of sight from the player. It ignores lying bodies. M3's wave spawner should pick **one** of these. See 9.2.

### 1.7 `set_post()` and the Jolt ghost step

`set_post(pos, yaw = rotation.y, fresh = false)` (`:222-239`) teleports the body, makes the spot its post and its comeback yaw, and with `fresh` resets it to standing at full health (`reset_state()`, `combat_actor.gd:506-528`).

**Jolt moves a kinematic body to a new transform only during the next physics step.** So a solid body teleported this way would collide where it stood (a held dummy would shove its holder). `set_post()` therefore makes it a ghost (`_set_ghost(true)`: the downed-body layer, colliding with the world only, `combat_actor.gd:1442-1445`) and `_turn_solid()` (`:112-121`) turns it solid after the step. It stays a ghost if it went down, flew, got grabbed, is blinking in, or (after a comeback) has a body standing inside it.

**Any M3 code that teleports a solid `CharacterBody3D` after `add_child()` needs this** (a spawner moving an enemy to its spawn point, a cheat reset, a boss's summoned Punks). Setting `position` before `add_child()` avoids it.

### 1.8 Public API summary

| Member | Where | Notes |
| --- | --- | --- |
| `sparring: bool` | `:32` | Setter re-arms the clock |
| `face_player`, `return_home: bool` | `:27-28` | Exported; the bots park dummies with them |
| `color`, `accent: Color` | `:29-30` | Set before `add_child()` (the rig is built in `_ready`) |
| `set_post(pos, yaw, fresh)` | `:222` | See 1.7 |
| `spar_in(frames)` | `:244` | Bots and tests |
| `start_jab()` | `:249` | Bots and tests; the rear-warning test hook |
| `debug_state_text() -> String` | `:257-261` | Base text plus `"sparring %.1f s"` while sparring and FREE |
| `DUMMY_JAB_PATH`, `DUMMY_JAB_ID` | `:19-20` | |

The tunables it reads (all in `game/autoload/tuning_data.gd`):
- **"Reactions":** `dummy_health` `:96`, `dummy_revive_s` `:100`, `dummy_respawn_gap_m` `:104`, `dummy_respawn_off_axis_deg` `:110`, `dummy_return_*` `:119-124` and `dummy_face_turn_rate` `:126`.
- **"Feel details":** `dummy_walk_speed` `:147`.
- **"Sparring":** `sparring_*` `:602-611` and `player_revive_s` `:613`.
- **"Enemies":** `windup_mult` `:549`.

The dummy tunables are scattered over four groups, which is a historical accident. New per-archetype enemy tunables should get their own group or subgroups, not be added to these.

---

## 2. The test room (`game/level/test_room.gd`)

### 2.1 How it's built

`test_room.tscn` is only a `Node3D` with the script (`test_room.tscn:5-6`). **Everything is built in code** in `_ready()` (`test_room.gd:41-46`), in this order: `_build_environment()`, `_build_street()`, `_spawn_actors()`, then `_build_presentation()` (only when `with_presentation`). There's no `class_name`. Tests and bots reach it with `room.get(&"player")`, `room.get(&"dummies")` and `room.set(&"with_presentation", false)` **before** `add_child`.

Helpers:
- `_add_box(pos, size, material) -> StaticBody3D` (`:171-183`): layer `LAYER_WORLD`, mask 0, a BoxShape3D plus a mesh, added **directly under the room**.
- `_add_visual_box()` (`:186-189`): a mesh only, no collision (paint).
- `_box_mesh()` (`:192-198`) and `_flat_material()` (`:201-205`).
- `_build_environment()` (`:65-91`): a procedural sky, filmic tonemap, light fog, and one sun with shadows (`directional_shadow_max_distance` 40).

### 2.2 Geometry (world space; the street axis is +X; tests pin these numbers)

With the defaults `street_length` 40 (`:19`) and `street_width` 14 (`:20`):

| Piece | Box center / size | Faces | Code |
| --- | --- | --- | --- |
| Ground (grid shader) | (0, −0.5, 0) / (60, 1, 34) | top at y = 0 | `:97` |
| Far-side building fronts (−Z) | z = −8, depth 2, widths 5/6.5/8 cycling, heights 5-9.5 | **inner face z = −7** | `:104-111` |
| End walls | x = ±21 / (2, 5, 16) | inner faces x = ±20 | `:113-114` |
| Near-side curb (+Z), kept low for the side view | (0, 0.3, 7.25) / (40, 0.6, 0.5) | z = 7.0 to 7.5, 0.6 high | `:116` |
| Crates | (−7, 0.5, −4.5), (−6, 0.5, −5.2), (8, 0.5, 4.5) / 1 m cubes | | `:119-120` |
| Dashed centre line (visual only) | z = −2, every 3 m | | `:122-126` |

Things outside this file that depend on the numbers:
- `test_tuning_panel.gd:800-802` (`_past_north_wall`, z = −7).
- `combo_bot.gd:10-13`: `PARK` at x 24+, on the floor behind the east end wall.
- Many tests' `FAR` posts.
- The KO-view wall tests.
- `SideViewCamera` assumes the street runs along X with the camera on +Z (`side_view_camera.gd:1-6`).

### 2.3 Actors

`_spawn_actors()` (`:129-149`):
- **Player:** `player.tscn`, at `player_start` (−4, 0, 0) with yaw −90°, so it faces +X down the street. `auto_revive = true` is set **before** `add_child` (`player.gd:30-32`; `_tick_ko()` → `_revive()` after `player_revive_s` 2.5 s, `player.gd:634-653`).
- **Dummies:** for each of `dummy_positions` (`:25-27`: (−0.8, 0, −1.8), (−0.5, 0, 0), (−0.8, 0, 1.8), about 3.2-3.5 m ahead of the player), the name `"Dummy%d"`, `display_name` `"Dummy %d"`, a color from `dummy_colors`, the position, a yaw facing the player start, and `sparring = sparring_dummies.has(n)` (default `[1]`, the centre one). Then `add_child`, and appended to `dummies: Array[TrainingDummy]` (`:38`).
- **Pipe:** a `Weapon` (`pipe.tscn`, a `RigidBody3D`; `weapon.gd`) at `pipe_position` (−3, 0.15, 2.6), rotated (0, 30, 90). On the ground it's on `LAYER_PICKUP` in group `"weapon"` (`weapon.gd:22`, `:95-100`), and the player finds it by group (`player.gd:1112`).
  - `Weapon.attach_to(actor)` (`weapon.gd:54`) works for any `CombatActor` whose rig has `WeaponGrip`, so a Pipe Thug can hold one.
  - **There's no public "drop to the ground" API.** `throw_from()` (`weapon.gd:75`) is the only way back to the world, and its projectile mask hits only `LAYER_ENEMY_BODY`.
  - The Pipe Thug's "drops the pipe on knockdown" needs a new `Weapon` method. That belongs to the weapons owner, not this area.

### 2.4 Presentation stack

`_build_presentation()` (`:152-168`), in order:
1. `CameraDirector` (scene or script fallback).
2. `hud.tscn`, whose child `DebugDraw` is the F3 instance.
3. `debug_draw.tscn`, but only if nothing is in group `"debug_draw"` yet. The HUD's instance joins that group in `_init`, so normally this is skipped.
4. `tuning_overlay.tscn`. **It must be a direct child of the room:** `TuningOverlay._ready()` sets `cheats.world = get_parent()` (`tuning_overlay.gd:81`), and tests find it with `room.find_children("*", "TuningOverlay", false, false)` (non-recursive; `test_tuning_panel.gd:814`, `:937`, `:992`, `:1034`, `:1132`).
5. `VfxDirector.new()`, `AudioDirector.new()` and `RumbleDirector.new()`.

`with_presentation = false` skips all of it. Most simulation tests run that way, so **nothing in the simulation may depend on a presentation node existing**.

### 2.5 F5

`_unhandled_input()` (`:49-53`) handles `&"sparring"` and calls `toggle_sparring()` (`:57-62`): all dummies spar, or none if all already do. This is the only room-level key. `test_combat_integration.gd:1154-1169` asserts the default `[false, true, false]` and the toggle.

### 2.6 Who loads the test room (do not break)

`tests/test_combat_integration.gd`, `test_ko_blink.gd`, `test_health_bars.gd`, `test_audio.gd`, `test_tuning_panel.gd`, `test_ko_view.gd`, `test_ragdoll.gd`, `test_vfx.gd`, `test_grab_view.gd`, `test_hit_flash.gd` and `test_launch_from_hold.gd` all preload `res://game/level/test_room.tscn`, as do `tests/bot/combo_bot.gd:9` and the ragdoll and VFX bots built on it. The usual harness is `test_combat_integration.gd:50-75`: instantiate, `with_presentation`, `add_child`, two ticks, script the player, re-post every dummy with `set_post(..., true)`.

---

## 3. F-keys and input (`game/autoload/game_input.gd`)

`BINDINGS` (`:9-42`) maps action names to key, mouse and joypad codes (`"mb:N"`, `"jb:N"`, `"ja:AXIS:SIGN"`). `register_actions()` (`:57-65`) rebuilds the InputMap at startup, and keys bind by **physical** keycode (`:71`). This is a **contract file** (ARCHITECTURE "Ownership"), so a new action needs agreement.

| Key | Action | Handled by | Where |
| --- | --- | --- | --- |
| F1 / View (jb 4) | `tuning_panel` | `TuningOverlay.handle_toggle_event()` | `tuning_overlay.gd:130-139` |
| F2 | `camera_cycle` | `CameraDirector` | `camera_director.gd:61` |
| F3 | `debug_draw` | `CombatDebugDraw._unhandled_input()` | `debug_draw.gd:102-105` |
| F4 | `cheats` | `TuningOverlay.handle_toggle_event()` | `tuning_overlay.gd:130-139` |
| F5 | `sparring` | `test_room.gd` `_unhandled_input()` | `test_room.gd:49-53` |
| H | `help` | `GameHud._unhandled_input()` | `hud.gd:63-66` |
| Esc / Menu | `pause` | `GameInput._unhandled_input()` | `game_input.gd:127-129` |
| R (while paused) | `restart` | `GameInput`: `TimeController.clear()`, then `reload_current_scene()` | `game_input.gd:130-134` |

Rules worth knowing:
- While F1 or F4 is open, **every** `BINDINGS` action except `tuning_panel` and `cheats` (`KEPT_ACTIONS`, `tuning_overlay.gd:26`) is lifted out of the InputMap (`_lift_bindings()`, `:238-246`), and the live player is frozen (`_freeze_player()`, `:218-225`). A new debug action is lifted the same way automatically.
- Free keys: F6-F12, plus most letters (W A S D, Q, E, Tab, Space, Shift, H and R are taken). Free pad buttons: 5 (Guide), 7 (left stick click), the D-pad (used only for menu focus) and the triggers (axes 4/5).
- `HelpOverlay.DEBUG_ROWS` (`help_overlay.gd:28-37`) lists the debug keys from `BINDINGS`, so a new key needs a row there. `test_ui.gd:504-512` asserts "F1"-"F5" and the text "Sparring dummies on / off" are present.
- `TimeController.debug_scale` (F4's 0.25×, `time_controller.gd:10`) is **not** cleared by `clear()` (`:82-85`), so it survives R and any scene change. Tuning values persist too (autoload).

---

## 4. F4: `TuningOverlay` and `CheatMenu`

`TuningOverlay` (`tuning_overlay.gd`) builds the panel and the cheat menu in a borderless, transparent embedded `Window` (`:59-93`):
- The cheat menu is docked top right: `cheat_width` 470, `margin` 24 (`:31-35`, `:78-88`). That puts it at x 1426-1896, y from 24 down to its content height.
- The tuning panel is docked left: x 24-814, y 24-890.
- Opening the cheats calls `cheats.record_posts()` and `refresh()` (`:163-170`).

`CheatMenu` (`cheat_menu.gd`): every action is a public method (tests call them directly).

| Member | Lines | Behaviour |
| --- | --- | --- |
| `world: Node3D` | `:44` | The spawn parent; defaults to `current_scene` (`_world()`, `:428-431`) |
| `god_mode_toggle`, `one_hit_toggle`, `time_scale_buttons`, `skip_arena_button` | `:45-48` | Tests read all four (`test_tuning_panel.gd:693-717`) |
| `spawned: Array[TrainingDummy]` | `:50` | Typed to the dummy |
| `refresh()`, `focus_first()` | `:72-87` | |
| `set_god_mode()`, `set_one_hit_ko()`, `set_time_scale()` | `:90-101` | |
| `record_posts()` | `:106-110` | Casts group `"enemy"` members to `TrainingDummy`, so other enemies are skipped |
| `spawn_point() -> Dictionary` | `:127-185` | `{position, yaw}` or `{}`. The ray starts at the first-person camera, or at the player's eye and look in the other views. It reaches `spawn_max_distance_m` (6), and is placed beside a body, off a wall, on the floor, or `spawn_open_distance_m` (3) out. Then floor drop, min distance from the player, `_clear_spot_near()`, and a yaw facing the player. |
| `spawn_dummy() -> TrainingDummy` | `:189-206` | Loads `DUMMY_SCENE` (`:10`) and sets name, `display_name` (`"Dummy %d"`, with the count of group `"enemy"` + 1), color, local position and yaw **before** `add_child` into `_world()`. Records the post. |
| `reset_dummies() -> int` | `:211-222` | Dummies only: `set_post(post, yaw, true)` at full `dummy_health` |
| `remove_spawned_dummies() -> int` | `:226-237` | `remove_from_group("enemy")` and `("actor")` **before** `queue_free()`, so group scans in the same frame don't see them |
| `_build()` | `:243-309` | Code-built UI: two toggles, the time row, three dummy buttons (`:294-296`) and a disabled "Skip to arena N" row (`:298-306`) |
| `_spot_clear()`, `_clear_spot_near()`, `_on_floor()`, `_clear_of_actors()` | `:333-406` | The spawn-spot search; see 1.6 |
| `_dummy_body() -> Vector2` | `:410-415` | Reads radius and height **once, from the dummy scene only**; caches in `_body_size` |

The cheat menu is a sanctioned exception to "presentation never writes state" (ARCHITECTURE `:383`).

---

## 5. F3: debug draw (`CombatDebugDraw`, `game/ui/debug_draw.gd`)

**Setup:**
- It's a `Node3D`, `process_mode = ALWAYS` (`debug_draw.tscn`), and joins group `"debug_draw"` in `_init` (`:74-75`).
- It processes at `HudStyle.PROCESS_PRIORITY` 100, after the cameras at 50 (`:80`).
- `enabled` (`:27-31`) toggles `_process()`. The F3 handler is at `:102-105`.

**`rebuild()` (`:147-175`) runs every frame while enabled.** For each node in group `"actor"` that isn't `is_gone()`, it calls `_add_actor()` and `_update_label()`. Then it calls `_stack_labels()`, frees labels of actors no longer seen, and `_flush()` writes **one ImmediateMesh of `PRIMITIVE_LINES`**. That mesh is unshaded, has `no_depth_test`, and draws on render layer `VIS_DEBUG` (`:81-98`).

What `_add_actor()` (`:184-210`) draws:
- **Hitboxes:** red (`hitbox_color`, `:32`), from `actor.debug_hitbox_volumes` (format in ARCHITECTURE "Interfaces"). Spheres are drawn as three circles (`_add_sphere()`, `:383`), arcs by `_add_arc_volume()` (`:247-273`).
- **Hurtboxes:** green (`:33`), from `rig.get_hurtboxes()` (`_add_hurtbox()`, `:214-232`). Dimmed while not live; skipped when hugging the camera (`_hugs_camera()`, `:237-241`).
- **The player's magnetism cone:** yellow (`:34`), plus a target line and marker (`:35`; `_add_magnetism_cone()`, `:278-313`, from `PlayerCharacter.get_magnetism_cone()`, `player.gd:246`).
- **The block arc:** cyan (`:36`), from `actor.get_block_arc()`.

Labels:
- `_update_label()` (`:316-339`) keeps one `Label3D` per actor: billboard, no depth test, `pixel_size` 0.0035, `VIS_DEBUG` layer.
- Text: **`actor.debug_state_text()`** (base `combat_actor.gd:531-551`: the name, health, `CombatTypes.state_name(state)`, the move id, frame and phase or the timed state's progress, and the guard).
- Placed at `get_head_top_position()` + `label_lift`; hidden within `label_hide_distance` (1 m) of the camera.
- `_stack_labels()` (`:346-368`) lifts overlapping labels of actors within `label_stack_distance` (2 m).

Building blocks to reuse: `_add_line(from, to, color)` (`:425`), `_add_circle(xform, center, a, b, r, color, from, to, segments)` (`:410`), `_add_sphere()`, `_add_capsule()` (`:393`) and `_add_arc_volume()`.

Test API (`:113-143`): `get_mesh()`, `get_line_colors()`, `count_lines_of_color(color)`, `get_label_count()`, `get_label(actor)`, `line_count` and the static `label_size()`. The tests in `test_ui.gd:559-740` assert **exact line counts and colors**. For example, `test_ui.gd:586` expects a sphere-only actor to give exactly `3 * CIRCLE_SEGMENTS` lines.

---

## 6. The HUD (`GameHud`, `game/ui/hud.tscn` + `hud.gd`)

`GameHud` is a `CanvasLayer` with `layer = 10`, `process_mode = ALWAYS` (`hud.tscn:15-18`) and `process_priority` 100 (`hud.gd:43`):
- It subscribes in `_ready()` (`hud.gd:41-56`) to `CombatEvents.hit_landed`, `attack_started`, `attack_whiffed`, `health_changed`, `vanished`, `perfect_blocked` and `guard_broken`, and to `GameInput.paused_changed`.
- `advance(delta)` (`hud.gd:70-84`) drives every timed part. `game_delta` is 0 while paused, and the startup help, the enemy bars and the block callout use it. The player panel, boss bar and camera toast use real `delta`.
- Tests turn processing off and call `advance()` themselves (`test_ui.gd:112-121`), with a bare `Camera3D` at the origin, fake enemies and **no player and no room**, so every part must tolerate a missing player, director or world.

**Layout on the 1920×1080 canvas** (`project.godot`: stretch `canvas_items`, aspect `expand`, so wider windows add width and anchors hold):

| Part | Anchor | Rect (px) | Node |
| --- | --- | --- | --- |
| **Top-left corner: reserved for the rear warning** | — | **0-384 × 0-216** | (empty) |
| **Top-right corner: reserved for the rear warning** | — | **1536-1920 × 0-216** | (empty) |
| CameraToast | top centre | x 700-1220, y 36-104 | `hud.tscn:95-107` |
| Pause caption | centre at (0.5, 0.17) | about y 146-222, centred | `pause_overlay.gd:10`, `:23-33` |
| HelpOverlay (H) | left middle | x 60-1000, y 260-800; **grows with its rows, both up and down** | `hud.tscn:109-120` |
| CombatLog | right middle | x 1120-1880, y 500-744 | `hud.tscn:78-93` |
| BlockCallout | below centre | x 620-1300, y 610-700 | `hud.tscn:122-137` |
| CenterDot | centre | ±8 | `hud.tscn:32-46` |
| PlayerHealthPanel | bottom left | x 40-540, y 904-1044 | `hud.tscn:48-59` |
| BossHealthBar (hidden until `show_boss()`) | bottom centre | x 580-1340, y 944-1040 | `hud.tscn:61-76` |
| EnemyHealthBars, PauseOverlay | full rect | — | `hud.tscn:22-30`, `:139-148` |
| (F1 panel, in the overlay Window) | left | x 24-814, y 24-890 | `tuning_overlay.gd:69-77` |
| (F4 menu, in the overlay Window) | top right | x 1426-1896, y 24 down | `tuning_overlay.gd:78-88` |

The corner rule is a test. `test_ui.gd:201-216` checks that the player panel, boss bar, combat log, camera toast and help overlay don't intersect the top 20% × 20% of either corner. The help overlay's top sits 44 px below that line, so **adding many help rows can break the test** (the panel grows about half a row upward per row added). The F1 and F4 overlays (a separate Window above the HUD) do cover the corners while open.

Other canvas layers: `SpeedLines` at 5, under the HUD, and the impact-frame flash at 20, over it (`vfx_director.gd:42-43`).

The parts and their public API:
- **`EnemyHealthBars`** (`enemy_health_bars.gd`):
  - Shows a bar for any actor **in group `"enemy"`** for `show_seconds` (2 s) after a hit or a health drop (`on_hit_landed()` `:58`, `on_health_changed()` `:70`). Dropped on `vanished` (`:89`).
  - Projection is in `advance()` (`:98-119`) through `screen_anchor_of()` (`:134-151`).
  - Test helpers: `bar_count()`, `visible_bar_count()`, `has_bar()`, `get_bar_screen_position()` (`:162-183`).
  - The health memory is capped at 64 ids (`:227-232`).
- **`BossHealthBar`** (`boss_health_bar.gd:20` `show_boss(actor)`, `:29` `hide_boss()`, `:35` `advance()`): shows `display_name` uppercased and a violet bar. `GameHud.show_boss()` / `hide_boss()` (`hud.gd:88-94`) are the entry points. **Nothing calls them yet;** the M3 boss is the first user (see 9.5).
- **`PlayerHealthPanel`** (`player_health_panel.gd`): finds the player in group `"player"` and shows HP, weapon pips and the guard meter (`advance()` `:69-93`).
- **`CombatLogOverlay`** (`combat_log_overlay.gd`): the last 10 hits and whiffs. Actor names come from `display_name` (`_actor_name()`, `:147-153`), so **give each enemy a distinct `display_name`** ("Punk 2"), or the log is unreadable in a crowd.
- **`BlockCallout`** (`block_callout.gd`): "PARRY!" and "GUARD BREAK!", player only. Its pop and fade pattern (`advance()` `:38`, `_show()` `:48`) is the nearest template for the rear warning's pulse.
- **`HelpOverlay`** (`help_overlay.gd`): `CONTROL_ROWS`, `DEBUG_ROWS` and `COMBO_ROWS` (`:12-51`), built once in `_build()` (`:122-173`); text comes from `GameInput.BINDINGS`.
- **`HudStyle`** (`hud_style.gd`):
  - Colors (`:9-21`): `INK`, `PAPER`, `HEALTH` (yellow), `BOSS` (violet), `GUARD`, `PARRY`, `MUTED` and `FINISHER_ACCENT` (red-orange).
  - The header comment (`:4-5`) reserves red for blood, the **rear warning** and finisher accents.
  - Helpers: `PROCESS_PRIORITY` (`:29`), `bold_font()`, `label_settings()`, `slanted_quad()`, `with_alpha()`, `draw_panel()`, `draw_gauge()` and `draw_text()`.

---

## 7. Events the UI and the rear warning need (`game/autoload/combat_events.gd`)

| Signal | Emitted at |
| --- | --- |
| `windup_started(attacker, move)` | `combat_actor.gd:452-453`, from `start_move(..., windup = true)` with `startup > 0` |
| `windup_ended(attacker, interrupted: bool)` | `combat_actor.gd:703-706` (false: the strike comes out) and `:736-739` (true: hit or grabbed out of the wind-up) |
| `attack_whiffed(attacker, move)` | `combat_actor.gd:707-713`, at the end of the active frames, **only for moves with hitboxes** |
| `hit_landed(hit)` | `HitDetector`. Blocked hits too (`hit.blocked`). `hit.attacker` is the enemy. |
| `vanished(actor)`, `ko(victim, hit)`, `revived(actor)`, `health_changed(...)`, `actor_state_changed(actor, old, new)` | Various |

`AudioDirector` already plays a positional wind-up grunt on `windup_started`, gated by `Tuning.rear_warning_audio` (`audio_director.gd:150-151`, `:257-275`). The burst art already exists: `assets/export/fx/rear_warning.png` (512 px, red-orange with a "!", made by `tools/gen_fx.gd:500-516`). Load it with `VfxArt.texture(&"rear_warning")` (`vfx_art.gd:24`). `test_vfx.gd:16` already requires the texture.

The "Rear warning" tunables already exist (`tuning_data.gd:551-555`): `rear_warning_angle_deg` 55, `rear_warning_size` 1.0, `rear_warning_opacity` 0.9 and `rear_warning_audio`. So does "Enemies" (`:545-549`): `attacker_cap` 3, `blind_spot_priority` 1.0 and `windup_mult`. **Only `windup_mult` and `rear_warning_audio` are read anywhere today.**

---

## 8. What M3 code can use as it is

- Group conventions:
  - `"actor"`: every `CombatActor`; debug draw iterates it.
  - `"enemy"`: magnetism (`player.gd:700`, `:734`, `:970`), health bars, VFX (`vfx_director.gd:390`, `:433`), audio (`audio_director.gd:326`), cheat posts.
  - `"player"`, `"weapon"`, `"camera_director"`, `"debug_draw"`.
  - **No game code casts to `TrainingDummy`** except the cheat menu and the test room. Everything else goes by group, so a new enemy class that joins `"enemy"` gets health bars, magnetism, VFX, audio, debug labels and F3 hurtboxes for free.
- `CombatActor` hooks for AI (`combat_actor.gd:557-627`): `_tick_control()`, `_on_move_finished()`, `_on_move_hits()`, `_on_hit_received()`, `_on_move_interrupted()`, `_plan_lunge()`, `_update_lunge()`, `_tick_ko()`, `_blinks_off_when_ko()` (true for team ≠ 0) and `_configure_rig()`.
- `HumanoidRig.play_locomotion(local_move: Vector2, speed_ratio)` (`humanoid_rig.gd:282-300`): x is right and y is forward, in the body's frame. It picks `walk_forward`, `walk_back`, `walk_left` or `walk_right`, so **circling and strafing animations already exist**. The dummy only ever passes `(0, 1)`.

---

## 9. Answers for Milestone 3

### 9.1 What should move from `TrainingDummy` into a shared enemy base

Recommendation: a new `EnemyActor extends CombatActor` (for example `game/enemies/enemy_actor.gd`), with `TrainingDummy extends EnemyActor`. The move should be **mechanical only**: same behaviour, same private names where the dummy keeps calling them, and the full suite as the gate. One owner does it in a foundation package, before the archetype packages branch. The archetypes then extend it.

Move into the base (lines are the dummy's today):

| Piece | From | Generalize as |
| --- | --- | --- |
| `team = 1`, `add_to_group(&"enemy")`, `max_health` set before `super._ready()` | `:73-76` | `_ready()`. Health from a per-archetype tunable (see the traps). Keep the before-`super` order. |
| `color`, `accent`, `_configure_rig()` | `:29-30`, `:124-126` | The same, plus a body size per archetype (`body_radius`/`body_height` exports on `CombatActor`, `combat_actor.gd:59-60`) and rig stance |
| `_rng` seeded by name | `:56`, `:79` | Keep. Spawners must name enemies before `add_child`. |
| `_turn_toward(dir, rate)` | `:518-522` | As is |
| `_walk(dir, turn_rate)` | `:313-318` | `_walk(dir, speed, turn_rate)`, plus a strafe/circle variant that passes the real local direction to `play_locomotion()`. The dummy keeps a thin `_walk()` that calls it with `dummy_walk_speed`. |
| The wind-up-scaled move cache (`_jab`, `_scaled_jab`, `_scaled_for`, `_jab_move()`, the `_on_tuning_changed` move branch) | `:49-52`, `:89-91`, `:322-332` | `windup_move(move) -> MoveData`, cached **per move id** and invalidated on `&""`, `moves/<id>/…` and a `windup_mult` change. Every archetype attack goes through it. Spec §7 floors (18 frames for grunts, 30 for the Bruiser and boss) belong in the move data, not here. |
| Start an attack | `start_jab()` `:249-254` | `start_attack(move)`: zero horizontal `sim_velocity` first. FREE, WINDUP and ATTACK are self-propelled, so a walker that starts a wind-up while moving **slides through its telegraph**. Then `start_move(windup_move(move), 1, &"root", true)`. |
| `max_health` live re-read with share kept | `:92-99` | Per archetype |
| The ghost-for-one-step teleport (`_solid_after_step`, `_solid_when_clear`, `_turn_solid()`, the ghost half of `set_post()`) | `:57-61`, `:102-121`, `:228-234` | `place(pos, yaw, fresh = false)`, for spawners, cheats and boss summons. The dummy's `set_post()` = `place()` + post bookkeeping. |
| Room queries (`_build_room_queries()`, `_has_room()`, `_standing_body_inside()`) | `:430-500` | Better as a static helper usable without an actor (for example `BodyRoom.has_room(space, radius, height, spot, exclude)`), so the wave spawner can test a spawn point before instancing. The dummy calls it. |
| `debug_state_text()` | `:257-261` | The base appends the AI state and token line (9.4); the dummy appends its sparring line |
| Player lookup | `:130` | A cached lookup is fine; keep the group (`"player"`) |

Stays dummy-only:
- the post and home (`_home`, `_home_yaw`, `return_home`, `_walk_home()`, `_body_in_the_way()`, `_home_has_room()`);
- the KO comeback (`_tick_ko()`, `_respawn_spot()`, `_respawn()`): real enemies blink off and are freed;
- sparring (`sparring`, `spar_in()`, `start_jab()`, `_sparring_partner()`, `_tick_spar_clock()`, `_spar()`, `_next_spar_wait()`, `DUMMY_JAB_*`);
- every `dummy_*` and `sparring_*` tunable.

Keep the paths `training_dummy.gd` and `.tscn` and the `class_name TrainingDummy`; tests, bots and the cheat menu load them.

The AI itself should not live in `TrainingDummy`. The archetypes' brain (enter, approach, posture, wind-up, attack, recover) is an overlay on `ActorState`: act only in FREE (as in `:133-136`) and resume POSTURE when hit reactions return to FREE. `ActorState` (`combat_types.gd:29-46`) has no AI states, and shouldn't get them.

The director must not manage the dummies. They're in group `"enemy"` too, so a director that scans `"enemy"` would hand tokens to dummies and count them toward the 6-alive cap. Use a separate group or class check for AI enemies (for example `"ai_enemy"`, or `is EnemyActor and has a brain`).

### 9.2 The crowd room: reuse `test_room.gd`, or share a base?

`test_room.gd` can't be reused as the crowd room. Its geometry is pinned by tests and the bots (section 2.2), and its actors are hard-wired to three dummies. But about 60% of it is generic: the environment, the box helpers, player spawning with `auto_revive`, and `_build_presentation()`.

Recommendation:
- **`GrayboxRoom extends Node3D`** (for example `game/level/graybox_room.gd`). It holds `_build_environment()`, `_add_box()`, `_add_visual_box()`, `_box_mesh()`, `_flat_material()`, `_build_presentation()`, `_spawn_player()` (with `auto_revive`), `with_presentation`, `player`, and the room-switch key handler.
- `test_room.gd extends GrayboxRoom`, keeping its exported layout vars, `dummies`, `toggle_sparring()`, F5 and **identical geometry and child order**. Its TuningOverlay stays a direct child.
- `crowd_room.gd extends GrayboxRoom` builds the lane.
- One owner does the extraction, gated by the full suite. **Nobody else edits `test_room.gd` in M3.**
- Lower-risk alternative: leave `test_room.gd` untouched and copy the 60 lines into the new base. That duplicates code but makes merge conflicts with the existing tests impossible.

What the crowd room needs (`game/level/crowd_room.gd` / `.tscn`; main scene via `project.godot:15`):
- **Orientation:** keep the street axis on +X, the lane about 30 m long on X and about 12 m wide on Z, the near side (+Z) low (a curb), and the building fronts on −Z. Then the side-view debug camera (`side_view_camera.gd:1-6`) and the KO view behave as in the test room.
- **Spawn points:**
  - doorways as gaps or recesses in the −Z building fronts, and alleys at the ends or between buildings;
  - each one a position, a yaw and a tag (`doorway`/`alley`), as exported arrays like `dummy_positions`, or `Marker3D` children if the room becomes a real scene;
  - "Some behind the player" is a property of where the player stands when a wave spawns, so the spawner should choose points relative to the player's facing at spawn time;
  - test each point with the shared room check (9.1) before instancing;
  - a spawn point in a recessed doorway must be reachable on the navmesh (or the Enter state walks in straight until it's on the mesh).
- **Navmesh** (room side only; the agent logic is the AI owner's): a `NavigationRegion3D` whose `NavigationMesh` parses the world colliders. Either:
  - add the static bodies as its children (`geometry_source_geometry_mode` = `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`), which means `_add_box()` takes a parent; or
  - put them in a group (`SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN` + `geometry_source_group_name`).

  Also set `geometry_parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS`, `geometry_collision_mask` = the world bit, and `agent_radius` ≥ the largest enemy body radius (0.35 for the dummy-sized ones). Bake synchronously with `bake_navigation_mesh(false)` after the geometry is in the tree, for deterministic tests. **The navigation map only syncs on a later physics frame**, so agents get empty paths for the first tick or two. The AI needs a fallback (direct steering) for that and for rooms with no navmesh (the training room; see 9.3).
- **Waves:** "repeating mixed waves of up to 6" belongs in an encounter/wave node (Spec §3 calls it the encounter manager), not in the room script. The room provides the spawn points and the player.
  - Freeing enemies: after `vanished`, `remove_from_group()` (`"enemy"`, `"actor"`, any AI group) **before** `queue_free()`, like `cheat_menu.gd:231-233`. Group scans in the same frame still see a queued node otherwise, and the alive count and next-wave trigger would be off by one.
- **The player:** `auto_revive = true` before `add_child`. While the player is KO'd or getting up, `player.can_be_hit_by()` is false (`combat_actor.gd:273-280`). The director should grant no tokens then.
- **The room switch:** a new `GameInput` action (for example `switch_room` on F6; a contract-file edit), handled in the shared base with `get_tree().change_scene_to_file()`. Call `TimeController.clear()` and unpause first, as R does (`game_input.gd:130-134`), and add a `HelpOverlay.DEBUG_ROWS` row.
  - F5's "Sparring dummies on / off" row stays (a test asserts it). In the crowd room F5 can do nothing, or the room can override `_unhandled_input()`.
- **Presentation:** the same `_build_presentation()` (HUD, debug draw, overlay as a **direct child**, VFX, audio, rumble), and `with_presentation = false` for tests. Expose `player` and `enemies` (or the spawner) as the test room does, so tests can use `room.get(&"…")`.
- **A pipe:** optional. `Weapon` is a plain `RigidBody3D` scene (`game/weapons/pipe.tscn`).

### 9.3 What F4 needs to spawn any archetype

1. **An archetype catalog** that the cheat menu reads instead of the single `DUMMY_SCENE` (`cheat_menu.gd:10`): for example `[{id, label, scene}]` for the dummy, Street Punk, Kicker, Pipe Thug, Bruiser and boss.
   - It's best owned by the enemies area (for example a `const` in an `EnemyCatalog` script), so the UI doesn't hard-code paths.
   - In parallel worktrees some scenes won't exist yet. Guard with `ResourceLoader.exists()` and show those buttons disabled.
2. **`spawn_enemy(id) -> CombatActor`** generalizing `spawn_dummy()` (`:189-206`). Keep `spawn_dummy()` as a wrapper, because `test_tuning_panel.gd:720-797` calls it and expects a `TrainingDummy`.
   - `spawned` becomes `Array[CombatActor]`; `remove_spawned_dummies()` (`:226-237`) loops typed as `TrainingDummy` today.
   - The display name per archetype plus a counter (the combat log).
   - Color per archetype, or keep `spawn_colors`.
3. **Body size per scene.** `_dummy_body()` (`:410-415`) caches one size from the dummy scene, and the Bruiser and boss are bigger. Make it a `Dictionary[String, Vector2]` keyed by scene path, and pass the size through `_spot_clear()`, `_clear_spot_near()` and `spawn_point()`. Today the size is read inside `_spot_clear()`, so `spawn_point()` needs an archetype argument.
4. **UI:**
   - One button per archetype (six rows) grows the menu down the top-right corner; it already covers the corner while open, which is acceptable.
   - Or, better for a gamepad, an `OptionButton` plus one "Spawn at crosshair" button.
   - Keep `god_mode_toggle`, `one_hit_toggle`, `time_scale_buttons` and `skip_arena_button` (tests). `focus_first()` stays on god mode.
5. **Director interplay:**
   - A spawned enemy should register with the director, by group discovery or an explicit call.
   - Decide whether cheat spawns count toward the 6-alive cap and the wave count. Recommend: they count as alive for tokens, but the wave spawner ignores enemies it didn't spawn.
   - **In the training room there may be no director and no navmesh.** Either the training room also adds a director (cheap, and F4 behaves the same in both rooms), or the AI falls back to "no director: token always granted" and direct steering. Without one of these, an enemy spawned in the training room stands still.
   - A spawned enemy should start in Approach/Enter, not swing at once. `spawn_min_distance_m` is 1 m.
6. **Nice to have:** "Remove all enemies", which keeps the remove-from-groups-then-`queue_free()` order. Also "Freeze AI" or "AI off", useful for tuning and captures; it would be a Tuning "Debug" bool so presets skip it (`PRESET_SKIPPED_GROUPS`).
7. `reset_dummies()` and `record_posts()` already skip non-dummies (they cast with `as`). Leave them.

### 9.4 What debug draw needs for AI state and attack tokens

- **The AI state over each head:** override `debug_state_text()` in the enemy base. For example, a third line `"AI POSTURE  slot 2"`, with `"TOKEN"` while it holds one, and `"blind"` when it got priority from the blind spot. Debug draw already shows it, stacks labels for a crowd (`_stack_labels()`), and hides labels within 1 m of the lens. **No debug-draw change is needed for the text.** Keep each line short: six enemies within 2 m stack tall.
- **Tokens and the director (new drawing):**
  - Debug draw is presentation. It must read the director, never the reverse. The director should **not** draw itself.
  - Pin a small read API in ARCHITECTURE before parallel work. For example, the director joins group `"enemy_director"` and exposes:
    - `debug_token_holders() -> Array[CombatActor]`
    - `debug_slot_of(enemy) -> Vector3` (its posture spot, `Vector3.INF` if none)
    - `debug_ring() -> Vector2` (posture ring min and max)
    - `attacker_cap()`
  - Debug draw finds it like the HUD finds the camera director (`hud.gd:149-156`), duck-typed (`has_method()` / `call()`). That way `debug_draw.gd` compiles before the director's `class_name` exists in its worktree, since `test_scripts_compile.gd` loads every script.
- **Suggested drawing** (new `@export` colors at `debug_draw.gd:32-36`; each one distinct, because tests count lines by exact color):
  - each token holder: a magenta ring at its feet and a line from its chest to the player's chest;
  - each posturing enemy: a small circle at its slot and a dim line to it;
  - the posture ring around the player (two circles, 2.5 and 4 m, at the ankles; `_add_circle()`);
  - the player's view boundary at `rear_warning_angle_deg` (two lines on the floor) and the ±20° behind sector, so blind-spot priority and the rear warning can be judged from side view and free fly;
  - optionally each agent's nav path (`NavigationAgent3D.get_current_navigation_path()`) as a polyline.
- **Keep the existing counts unchanged.** Draw the new layers only when a director or AI enemy exists. Otherwise `test_ui.gd:578-660`'s exact `line_count` assertions break. Add a test of the new colors with a stub director node in the group.
- Debug draw already iterates `"actor"` and skips `is_gone()`. Six to eight enemies plus labels per frame in one ImmediateMesh is fine.

### 9.5 Where the rear-warning UI goes

- **Placement:** a new HUD part, for example `RearWarning extends Control` (`game/ui/rear_warning.gd`):
  - added to `hud.tscn` as a full-rect, `mouse_filter = IGNORE` child, like `EnemyHealthBars` (`hud.tscn:22-30`);
  - drawing one burst in the **top-left** and one in the **top-right** reserved corners (each 384 × 216 px at 1920 × 1080; anchored so wider screens keep them in the corners);
  - drawing `VfxArt.texture(&"rear_warning")`, centred about 40-60 px in from the corner edge, base size about 160-200 px × `rear_warning_size`, alpha `rear_warning_opacity` × pulse;
  - clamping the drawn size so it stays inside its corner rect (`rear_warning_size` goes up to 3.0).
- **Wiring:**
  - `GameHud` adds `@onready var rear_warning: RearWarning = $RearWarning` (`hud.gd:23-32`), connects the events in `_ready()` (`hud.gd:41-56`), and calls `rear_warning.advance(game_delta)` in `advance()` (`hud.gd:70-84`). The warning freezes on pause like the bars.
  - The pulses can run in real time (two pulses) while the burst itself is held by state.
  - In `test_ui.gd:201-216`, add a new assertion that the rear warning lies **inside** the corners. Don't add it to the "clear of corners" list.
- **The trigger, per Spec §8:**
  - On `windup_started(attacker, move)` with `attacker.team != 0`, it reads the player (group `"player"`) and computes the **horizontal** angle between the view forward and the attacker.
  - Use the player's look plus the view's own turn: yaw `look_yaw` (`player.gd:23`) plus `get_camera_view_yaw()` (`player.gd:234`), a sim-side value. Don't use the active `Camera3D`: in side view or free fly it isn't the player's view, and headless tests have no camera.
  - The director's blind-spot priority (simulation, which may never read a camera) should use **the same helper**, so "outside the view" means the same thing in both places. A static function on `PlayerCharacter` or a small shared script would do.
  - Fire when the angle is over `rear_warning_angle_deg` (55) and the distance is under the attack range + 1 m.
  - Side: the signed angle's sign picks left or right. Within ±20° of directly behind (|angle| ≥ 160°), both corners.
  - **The "attack range" doesn't exist in data yet.** `MoveData` has no reach field (`move_data.gd`), and hitbox specs don't give one. Options:
    1. a `reach_m` field on `MoveData`, generated by `tools/gen_moves.gd` (a contract-file change, but it makes range data);
    2. a per-archetype `attack_range_m()` on the enemy base, duck-typed from the UI;
    3. the posture logic's own attack-distance tunable.

    The planner should pick one. The test dummy's jab is about 1.05 m.
  - **New tunables** for the existing "Rear warning" group (`tuning_data.gd:551-555`): behind half-angle (20°), range margin (1 m), pulse count and length, heavy-attacker scale (Bruiser and boss larger), brightness per extra attacker. Then regenerate `res://tuning/default.json` with `tools/gen_default_preset.gd`; `test_tuning_panel.gd` fails until it matches.
  - "Larger burst" needs a readable attacker property, for example an exported `warning_scale` or a `heavy` flag on the enemy base, read duck-typed.
- **The end** (Spec: "ends when the attack lands or is interrupted"). Event-driven cleanup alone is **not enough**:
  - `windup_ended(attacker, false)` only means the strike is coming out. Keep the burst through the active frames.
  - End on: `hit_landed` with `hit.attacker == attacker` (blocked hits included), `attack_whiffed(attacker, move)`, `windup_ended(attacker, true)`, and `vanished` or `ko`.
  - **Also poll each `advance()`:** drop the entry when the attacker is freed, not in WINDUP or ATTACK, or `current_move` is no longer that move. A hit during the active frames, a grab during the active frames, or a move with no hitboxes (a grab attempt, where `attack_whiffed` never fires, `combat_actor.gd:707-713`) emit nothing that ends it.
  - Chained attacks (the Pipe Thug's three swings): each `start_move(..., windup = true)` fires a new `windup_started`. A chain link started without a wind-up fires none.
- **Several attackers:** one burst per corner, brightness from the count on that side (Spec §8).
- **Whether to re-check the side as the player turns during the wind-up:** Spec says the flash "appears at wind-up start". Recommend: decide inside or outside the view at start, and keep the side fixed until the end. Record it as a judgement call.
- **Testing without AI:** post a `TrainingDummy` behind-left, behind-right and directly behind the player with the `_setup()` pattern (`test_combat_integration.gd:50-75`; posts are in the player's frame), call `start_jab()` (`training_dummy.gd:249`), step the HUD's `advance()`, and assert which corner shows. This decouples the rear-warning package from every AI package. The Spec §12 "done when" for the warning can be met and recorded in the training room.
- **Audio** is already done. `AudioDirector` plays the wind-up grunt positionally with a rear low-pass bus.
- **Boss bar:** the boss is the first user of `GameHud.show_boss()`. The HUD (presentation) should find the boss by group (for example `"boss"`) or a new `CombatEvents` signal (a contract change). Don't have the boss or the room call into the HUD; tests run rooms without presentation.

---

## 10. Conflict hot spots (files several M3 packages want)

| File | Who wants it | Advice |
| --- | --- | --- |
| `game/autoload/tuning_data.gd` + `res://tuning/default.json` | Every archetype (health, speeds), the director (Enemies group), the rear warning, AI debug cheats | Append only, inside your own `@export_group` or subgroup. The lead regenerates `default.json` once after merging. `test_tuning_panel.gd:390` asserts **"Enemies" has no subgroups**: update it if you add any. |
| `game/ui/hud.gd` / `hud.tscn` | The rear warning, the boss bar wiring, any AI HUD hint | One owner (the rear-warning package). Others hand over wiring requests. `hud.tscn` ext_resource ids are hand-numbered. |
| `game/ui/cheat_menu.gd` | Spawn-any-enemy, AI cheats, wave cheats | One owner, after the catalog API is pinned |
| `game/ui/debug_draw.gd` | AI state, tokens, slots, nav paths, view boundary | One owner, after the director's read API is pinned |
| `game/enemies/dummy/training_dummy.gd` | The base extraction; anyone tempted to "just reuse" its walk or jab code | The foundation package only |
| `game/level/test_room.gd` | The base extraction, a director or navmesh in the training room, the room-switch key | The foundation/room package only; geometry frozen |
| `game/autoload/game_input.gd` (`BINDINGS`) + `help_overlay.gd` (`DEBUG_ROWS`, `CONTROL_ROWS`) | The room switch, "mash to break free" (if it gets its own action), new cheat keys | A contract file: pin the action names in the plan. Help rows grow the panel toward the top-left corner (`test_ui.gd:201`). |
| `project.godot` (`run/main_scene`) | The crowd room | The lead, at merge |
| `docs/ARCHITECTURE.md` | Every package | Each package adds its own section. Interfaces at `:206-307` (TrainingDummy `:238`), TuningOverlay and CheatMenu at `:355-393`, Ownership at `:395-405`. |

---

## 11. Traps

1. **Teleporting a solid body after `add_child()`** collides at the old spot for one Jolt step. Set `position` before `add_child()`, or ghost it for the step as `set_post()` does (1.7).
2. **`_ready()` order:** `team` and `max_health` before `super._ready()`. The name before `add_child()` for the RNG seed. The position before `add_child()` for the dummy's post.
3. **The self-propelled slide:** in FREE, WINDUP and ATTACK, `sim_velocity` isn't corrected by collisions. Zero the horizontal velocity before starting a wind-up, and add stall detection to any walk.
4. **Act only in FREE.** Every non-FREE state belongs to `CombatActor`. An AI that writes `sim_velocity` or turns in HITSTUN or STAGGER fights the knockback.
5. **Group removal before `queue_free()`**, or same-frame scans of `"enemy"` and `"actor"` still count the body (`cheat_menu.gd:231-233`). A vanished enemy stays KO'd **and in its groups** until freed.
6. **The dummies are in `"enemy"`.** The director and wave counts must not treat them as AI enemies.
7. **Never read a camera in the simulation.** The dummy's comeback uses `player.get_forward()`, and blind-spot priority must use the player's look. The rear warning (presentation) may read a camera, but should use the same look-based helper so the two agree in every camera mode and headless.
8. **The rear warning's end events are incomplete**; poll state as well (9.5).
9. **Debug-draw tests count exact lines and colors.** New lines appear only when AI or director data exists, in new distinct colors.
10. **HUD tests run the HUD with only a bare camera: no player, director or room.** New parts must no-op cleanly then.
11. **Don't change the test room's geometry or child order.** About 11 test files and 3 bots depend on them (2.6), and `TuningOverlay` must stay a direct child of whatever room hosts it.
12. **Parallel compile:** `test_scripts_compile.gd` loads every script under `res://game`. A UI script statically typed to a `class_name` from another worktree (`EnemyDirector`, `EnemyCatalog`) fails to compile until the merge, so use duck typing or groups across package boundaries.
13. **Per-archetype stats are "feel numbers":** health and speeds go in `TuningData` (live in F1) or generated data, never script constants. Spec §7's health values (30, 25, 35, 80, 300) and wind-up floors (18 and 30 frames) belong there and in the move `.tres` files (edit `tools/gen_moves.gd`, never only the `.tres`).
14. **`TimeController.debug_scale` survives R and scene changes**; Tuning values survive too. A room switch should call `TimeController.clear()` and unpause.
15. **The cheat menu and tuning panel cover the top corners while open** (a separate Window above the HUD). Judge the rear warning in captures with F1 and F4 closed.
