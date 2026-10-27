# M3 codemap: the player and the cameras

Mapped at `3f5a866` (branch `m3/enemy-ai`, just cut from `main` after M2). Every `file:line` below is at that commit. Read this before editing `game/player/*`, `game/camera/*`, `game/autoload/game_input.gd`, or the parts of `game/actors/combat_actor.gd` the player depends on.

**What M3 needs from this area, in short:**
- **Where the player looks** is `look_yaw` (and `look_pitch`), never the camera. No flat "look forward" or "bearing" helper exists yet: add one (section 12.3) and have both the director and the rear warning read it.
- **Magnetism** finds enemies only through the `"enemy"` group, picks the enemy nearest screen centre within a 35° / 2.5 m cone, and has gaps that matter in a crowd (section 12.2).
- **Enemy grabs on the player:** the base class already has the victim's side (`start_grabbed`, the pin, `release_from_grab`). The player has no `GRABBED` control: no mash counter, no look lock, no held view, and three latent bugs (section 12.1).
- **The cameras need no change for M3** if the held view is expressed through the player's existing camera-offset getters. The first-person camera may *subscribe* to a release to `snap()`.

---

## 1. Files

| File | Lines | What it is |
| --- | --- | --- |
| `game/player/player.gd` | 1133 | `PlayerCharacter` (extends `CombatActor`): look, input → parser, all player states, magnetism, the grab as holder, weapons, KO revive, the first-person camera's offsets |
| `game/player/player_input.gd` | 104 | `PlayerInput`: one tick of intent, live or scripted (bots and tests) |
| `game/player/player.tscn` | 7 | A bare `CharacterBody3D` with the script. The rig and capsule are built in code (`CombatActor._ensure_body()`, `combat_actor.gd:1457`) |
| `game/autoload/game_input.gd` | 135 | The `GameInput` autoload: InputMap bindings, mouse capture and deltas, pause and restart |
| `game/camera/camera_director.gd` (+`.tscn`) | 111 | `CameraDirector`: owns the three cameras and cycles them on F2 |
| `game/camera/first_person_camera.gd` | 594 | `FirstPersonCamera`: the view from the player's eyes, punch and shake, the KO view |
| `game/camera/side_view_camera.gd` | 74 | `SideViewCamera`: a debug belt-scroller shot (debug only, by Game-boy's 2026-10-25 verdict) |
| `game/camera/free_fly_camera.gd` | 95 | `FreeFlyCamera`: debug |
| `game/camera/camera_math.gd` | 12 | `CameraMath.damp_weight()` |
| `game/actors/combat_actor.gd` | 1480 | The base class. The player's hit reactions, KO, invulnerability, block, being grabbed and the sim step all live here (sections 8 and 9) |

Tests that guard this area: `tests/test_cameras.gd`, `tests/test_grab_view.gd`, `tests/test_ko_view.gd`, `tests/test_combat_integration.gd`, `tests/test_launch_from_hold.gd`, `tests/test_ko_blink.gd`, `tests/test_humanoid_rig.gd` (first-person lens rules, using `tests/fp_view.gd`), `tests/test_audio.gd` (listener), `tests/test_tuning_panel.gd` (groups and subgroups). Bots: `tests/bot/combo_bot.gd`, `ragdoll_bot.gd`, `vfx_bot.gd`.

---

## 2. Frame order (what runs when)

**Physics tick, 60 Hz.** Actors run in tree order: in the test room the player is added before the dummies (`test_room.gd:129-145`). `TimeController` runs last (`time_controller.gd:90`, `process_physics_priority = 1000`).
1. `PlayerCharacter._physics_process(delta)` (`player.gd:142`):
   - `input.poll()`, then button edges are appended to `_pending_edges` (presses before releases);
   - `super._physics_process(delta)` (`combat_actor.gd:163`):
     - takes `TimeController.scale_for(self)` (0 in hitstop) and runs 0 to 4 whole `_sim_tick()`s;
     - then **either** `_pin_to_holder()` (if `GRABBED`) **or** `_integrate()` (`move_and_slide`);
     - then `rig.advance()` and the hit flash;
     - then the hit detector for the running move.
   - `_update_view_yaw()` (`player.gd:777`) and `_tick_hold_shift()` (`player.gd:1042`) run after the rig advanced.
2. **`_sim_tick()`** (`combat_actor.gd:634`):
   1. `state_frame++` and the `_pull_strike` snap-back;
   2. `_invuln_frames--`, the blink-in, the guard frames and meter;
   3. `_tick_reaction_timers()` (timed states end here);
   4. `_advance_move()`;
   5. **`_tick_control()`**, the player's controller (`player.gd:295`);
   6. `_apply_move_frame()` (the lunge, `_on_move_frame`).

**Render frame:**
1. `PlayerCharacter._process(delta)` (`player.gd:155`) applies mouse and stick look to `look_yaw` and `look_pitch`. Default priority.
2. `CameraDirector` and its cameras run at `process_priority = 50` (`camera_director.gd:20`), so they always see this frame's look.
3. The HUD and debug draw run later still (`HudStyle.PROCESS_PRIORITY`), and the VFX after the cameras (`vfx_director.gd:88`).

Physics interpolation is **off** (not set in `project.godot`). The camera reads `get_global_transform_interpolated()`, which then returns the latest tick, so the view moves in 60 Hz steps (`first_person_camera.gd:14-21`).

---

## 3. The look: `look_yaw` / `look_pitch`

`player.gd:22-24`: radians. Yaw 0 faces −Z, positive yaw turns **left**, positive pitch looks up. Pitch is clamped to ±85° in `_process` (`player.gd:173`, a literal).

**Writers:**

| Where | When |
| --- | --- |
| `_process()` `player.gd:155-173` | Live mouse (`GameInput.consume_mouse_delta()` × `mouse_sensitivity`) and the right stick (× `stick_look_speed` × render `delta`). Skipped when `input.scripted` or `GameInput.paused`. The mouse delta is consumed **before** the gates, so input during a gate is dropped, not kept (`player.gd:158`). |
| The KO lock, `player.gd:165` | No look from health 0, through `KO`, and through the get-up that follows a revive (`_ko_getup`, set in `_revive()` `player.gd:646` and cleared in `_process` once the state leaves `GETUP`, `player.gd:159-160`). |
| `_ready()` `player.gd:108` | `look_yaw = rotation.y`. **So set `rotation.y` before `add_child`** (the test room does this, `test_room.gd:132`), or set both afterwards. |
| `_tick_turns()` `player.gd:911-921` | The sim's own turns: the magnetism turn (`_turn_left` / `_turn_frames`, clamped to `magnet_turn_deg` and spread over the move's startup, `player.gd:662-665`) and the quick turn (+π over `quick_turn_frames`). Runs every sim tick **in every state**. |
| `_revive()` `player.gd:645` | `look_yaw = rotation.y`, so the view returns to the eyes the body has. |
| Bots and tests | They write `look_yaw` and `look_pitch` directly (`combo_bot.gd:554-582`, `test_combat_integration.gd:62-64`). |

**The body follows the look** (`rotation.y = look_yaw`, `player.gd:300-301`) only in `_can_steer_body()` states (`player.gd:928-937`): FREE, AIRBORNE, ATTACK, DODGE, GRABBING, BLOCK, BLOCKSTUN. In HITSTUN, STAGGER, LAUNCHED, DOWNED, GETUP, KO, GRABBED and THROWN the body keeps its facing while the live look keeps turning (except in KO). Two consequences:
- **Look and body diverge** during reactions. `get_forward()` (`combat_actor.gd:283`) is the **body** facing, not the look.
- The body snaps to the look when the player is back in a steerable state.

**Readers:**
- Aim: `_find_magnet_target` (`player.gd:693`), the weapon throw (`player.gd:575`) and the block arc (`_guard_facing()` `player.gd:630`).
- Movement: `_input_world_dir()` (`player.gd:835`) and the dodge (`player.gd:885`).
- The first-person camera, through `get_look_basis()`.
- The audio listener (`audio_director.gd:404`).
- The cheat-menu ray, when no first-person camera is active (`cheat_menu.gd:136-137`).

The flat forward `Vector3(-sin(look_yaw), 0, -cos(look_yaw))` is written out three times (`player.gd:631`, `836`, `885`). There is **no public flat-look or bearing helper**; section 12.3 proposes one.

---

## 4. Public API of `PlayerCharacter` (what other modules may read)

| Member | Line | Notes |
| --- | --- | --- |
| `look_yaw: float`, `look_pitch: float` | 23-24 | Section 3 |
| `standing_eye_height: float` | 26 | Measured from the rig in `_ready` |
| `input: PlayerInput` | 28 | Set `input.scripted = true` to drive from code |
| `parser: ComboParser` | 29 | Tests and bots poke `parser.release/reset_chain/clear_buffer` |
| `auto_revive: bool` | 32 | Test room only, set at `test_room.gd:133`. Without it a KO'd player stays KO'd forever (there is no game over yet) |
| `get_eye_transform() -> Transform3D` | 179 | World transform of the rig's `EyePoint` (animated; follows the pose) |
| `get_look_basis() -> Basis` | 183 | `Basis.from_euler(Vector3(look_pitch, look_yaw, 0))` |
| `get_camera_move_offset() -> Vector2` | 192 | x = extra pitch in degrees (negative is down), y = drop in metres: the running move's `_cam_offset` plus the hold view's. Eased |
| `get_camera_pull_back() -> float` | 199 | The hold view's pull-back |
| `get_hold_view_weight() -> float` | 207 | 0..1, smoothstepped |
| `get_hold_view_pitch_deg() -> float` | 215 | |
| `get_hold_view_shift() -> Vector2` | 226 | Rise and pull-back, in metres |
| `get_camera_view_yaw(fraction := 1.0) -> float` | 234 | Degrees, positive left: spin follow and `camera_yaw_deg` (the back elbow). **Presentation only; aim never uses it** |
| `is_walking() -> bool` | 238 | FREE or GRABBING, on the floor, faster than 0.5 m/s |
| `get_magnetism_cone() -> Dictionary` | 246 | `{origin = eye, forward = look, half_angle_deg, range, target}`. `target` is `_magnet_target` in ATTACK, else the per-tick preview. For F3 |
| `holding_weapon() -> bool` / `weapon_durability_left() -> int` | 256 / 260 | |
| `holding_enemy() -> CombatActor` | 264 | `_held`; may be stale or invalid. Check `is_instance_valid` |
| `debug_state_text() -> String` | 268 | F3 label |
| `reset_state()` | 276 | Base reset plus the player's guard, view and hold state |

From `CombatActor` (also the player's): `health`, `max_health` (100), `team` (0, set at `player.gd:104`), `state`, `state_frame`, `current_move`, `move_frame`, `sim_velocity`, `holder`, `guard`, `is_ko()`, `is_downed()`, `is_flying()`, `is_invulnerable()`, `is_guarding()`, `can_be_grabbed()`, `can_be_hit_by(attacker, move)`, `get_forward()` (the body), `get_chest_position()`, `receive_hit()`, `start_grabbed()`, `release_from_grab()` (see `docs/ARCHITECTURE.md` "Interfaces").

Groups: `"actor"` (`combat_actor.gd:146`) and `"player"` (`player.gd:106`). Enemies find the player with `get_tree().get_first_node_in_group(&"player")` (`training_dummy.gd:130`).

Private members that tests call (renaming them breaks tests): `_find_magnet_target(move)` (`test_ko_blink.gd:197,524,529,553`), `_find_grab_target()`, `_revive()`, `_process(delta)` (`test_ko_view.gd:617`), `_enter_state()`, `_guard_frames`.

---

## 5. Input pipeline, and how bots and tests drive the player

**Live input:**
1. `GameInput` (`game_input.gd`) registers `BINDINGS` (`game_input.gd:9-42`) into the InputMap at startup.
2. It accumulates mouse motion into `_mouse_delta`, or `_fly_mouse_delta` while the middle button is held (`game_input.gd:114-120`). Each frame's reader consumes it (`consume_mouse_delta()` `:93`).
3. Esc toggles pause (`set_paused()` `:106`). R while paused reloads the current scene (`:130-135`).

**Each tick, live:**
1. `PlayerInput.poll()` (`player_input.gd:40`) returns a `Frame{move: Vector2, pressed, released}`, using the `BUTTONS` map (`player_input.gd:7-15`): P, K, RB, JUMP, DODGE (B), GRAB (LB), TURN.
2. Live, a button reported held whose action is no longer pressed is released, even without an edge (`:56`).
3. `_physics_process` stores the edges in `_pending_edges`. On each sim tick, `_feed_parser()` (`player.gd:327`) hands them to `ComboParser.press/release`. `_dodge_stick` and `_block_press_held` are latched on the B press (`player.gd:335-337`).
4. Presses then wait in the parser buffer (8 sim frames) until a state's control function `consume()`s or `select()`s them.
5. **During hitstop no sim tick runs, so the edges pile up** and are all fed on the next sim tick.

**Scripted mode** (`input.scripted = true`):
- `poll()` pops queued frames, or returns an idle frame with `scripted_move` (`player_input.gd:41-46`).
- Helpers:
  - `push_wait(ticks)` `:63`;
  - `push_press(button, hold_ticks = 2)` `:71`: a press frame, `hold_ticks - 1` waits, then a release frame. The fastest press-and-release is 2 frames, so a scripted mash tops out at 30 presses per second;
  - `push_down` / `push_up` `:84/92` (the held block);
  - `queued()` `:99`, `clear_queue()` `:103`.
- `scripted_move` is sticky: it is reused for every frame that has no value of its own.
- **`_process()` returns early when scripted** (`player.gd:156`): no mouse or stick look. Scripts set `look_yaw` and `look_pitch` directly. (`_ko_getup` is also only cleared in `_process`. That is harmless, because only `_process` reads it.)
- `TuningOverlay` switches a live player's input to scripted while F1 or F4 is open, and back 2 ticks after closing (`tuning_overlay.gd:218-233`). An already-scripted player is left alone.

**Harness patterns** (copy these for M3 tests and bots):
- `test_combat_integration.gd:51-75` `_setup()`:
  - instantiate the room with `with_presentation` false;
  - `input.scripted = true`;
  - set `look_yaw` and `rotation.y` together;
  - place actors with `set_post()` in the player's frame.
- `_press()`, `_drain()`, `_wait_until()`, `_wait_idle()` (`:82-113`).
- `combo_bot.gd`:
  - `_run()` `:65` reads `room.get(&"player")`, `room.get(&"dummies")`, `player_start` and `player_yaw_deg`;
  - `_reset()` `:573` resets the player and its look;
  - `_turn_by()` `:554` and `_look_to()` `:565` animate the look;
  - `_stage()` `:595`.
  - **A new crowd room should expose `player` the same way**, so bots and tests can be built on it.
- Mouse look in a test (`test_ko_view.gd:606-620`):
  1. set `GameInput._mouse_delta`;
  2. switch the input to live;
  3. call `player._process(FRAME)`;
  4. switch back to scripted.

---

## 6. Player state machine (`_tick_control`, `player.gd:295-324`)

Order each sim tick:
1. `_feed_parser()`.
2. Hand back a P/K held by the guard.
3. `_tick_turns()`.
4. Steer the body to the look (if steerable).
5. `match state`.
6. `_magnet_preview = _find_magnet_target(null)`.
7. `_tick_hold_view()`.

| State | Control | Notes |
| --- | --- | --- |
| FREE | `_control_free` `:346` | Priority order: TURN (does not return), `_action_lock`, DODGE→`_b_action`, JUMP, GRAB→`_grab_action` (only if it did something), parser `select`, the held block re-raise, then locomotion (and the charge pose) |
| AIRBORNE | `_control_air` `:391` | Air set; lands itself (`_auto_land()` is false, `:924`) |
| ATTACK | `_control_attack` `:405` | Steer at `attack_move_mult`. In a cancellable recovery: DODGE (not airborne, not holding), TURN, chain `select(true)` |
| DODGE | `_control_dodge` `:433` | Fixed velocity for `dodge_frames`, then neutral |
| GRABBING | `_control_holding` `:517` | Player as holder (section 9) |
| BLOCK | `_control_block` `:446` | Late-stick dodge, TURN, slow walk, P/K held back, B release drops the guard; JUMP and GRAB are dropped |
| BLOCKSTUN | `_control_blockstun` `:481` | TURN, holds P/K back |
| **anything else** (`_:` `:321-322`) | `parser.clear_buffer()` | HITSTUN, STAGGER, LAUNCHED, DOWNED, GETUP, KO, **GRABBED**, THROWN, WINDUP. **Every press made in these states is thrown away each tick.** A mash counter must run *before* this branch, or in a new `GRABBED` arm |

Hooks the player overrides (base defaults are at `combat_actor.gd:557-628`): `_configure_rig` `:126`, `_tick_control` `:295`, `_on_move_finished` `:551`, `_on_move_frame` `:568`, `_on_move_hits` `:581`, `_on_hit_received` `:597`, `_on_move_interrupted` `:612`, `_on_hit_blocked` `:621`, `_guard_facing` `:630` (the look, not the body), `_tick_ko` `:634`, `_plan_lunge` `:654`, `_update_lunge` `:670`, `_auto_land` `:924`. Not overridden: `_blinks_off_when_ko()` (false for team 0, `combat_actor.gd:622`). The player never blinks off.

---

## 7. Target magnetism (Spec §5)

- **Chosen at move start:** `start_move()` → `_plan_lunge(move)` (`player.gd:654`). If `move.magnetism`, `_magnet_target = _find_magnet_target(move)`. Then:
  - a lunge toward its chest, clamped to `move.lunge` or `Tuning.magnet_lunge` (0.8 m), stopping at `_stop_distance()` (`:680`): `magnet_stop_distance` 0.85 m, centre to centre, or `stomp_stop_distance` for `hits_downed` moves;
  - a look turn toward it, clamped to `magnet_turn_deg` (15°) and spread over `move.startup` frames (`:662-665`). This turns `look_yaw` itself, so the camera follows.
- **No target:** `free_lunge` straight ahead, if the move has one (`:666-667`).
- **Re-aimed every frame of the lunge** (`_update_lunge` `:670`) at the target's current chest, within the budget.
- **`_find_magnet_target(move)`** (`player.gd:691-722`):
  - Candidates: `get_tree().get_nodes_in_group(&"enemy")` cast to `CombatActor`. **The `"enemy"` group is the only way in.** `CombatActor` does not add it; `TrainingDummy._ready` does (`training_dummy.gd:74`). Every M3 archetype must call `add_to_group(&"enemy")`.
  - Skips: `is_ko()`, `is_flying()`, `is_downed() != wants_downed` (stomp moves want downed bodies), and `is_blinking_in()`. **It does not skip** `is_invulnerable()` (a body in its get-up's `getup_invuln_frames`), `is_gone()` (gone bodies are KO, so already skipped), bodies held by someone, other teams, or bodies hidden behind a wall or crate (no line-of-sight test).
  - Origin is the **player's chest** (not the eye, `:696`). Aim is `get_look_basis() * FORWARD`, which **includes pitch**. The angle is the full 3D `aim.angle_to(to)` to the enemy's chest (`:714`); for downed targets it is flat heading only. Range is the flat distance ≤ `magnet_range` (2.5 m). Cone is `magnet_half_angle_deg` (35°).
  - Score is `angle + deg_to_rad(4.0) * dist`, lowest wins (`:718`). **The 4°/m tie-break is a literal in the script** (pre-existing debt; move it to `Tuning` "Magnetism" if you touch it).
- **Preview:** `_magnet_preview` is recomputed every sim tick (`:323`) for F3 (`debug_draw.gd:199`).
- **Related searches**, which use the **body** forward and the `"enemy"` group:
  - `_find_grab_target()` `:966`: nearest `can_be_grabbed()` enemy within `grab_range` 1.3 m and `grab_half_angle_deg` 60°;
  - `_downed_target_near()` `:732`: any downed enemy within `stomp_range` 1.5 m and `stomp_half_angle_deg` 70°. This is the `COND_DOWNED_TARGET_NEAR` condition. **The stomp branch comes before the front kick in the ground set** (`tools/gen_moves.gd:276`).
  - `_find_weapon()` `:1112`: nearest available `"weapon"` within `pickup_range`.
- **LB priority** (`_grab_action` `:950`): throw the held weapon, then grab an enemy, then pick up a weapon.
- Moves with `magnetism = false` (`tools/gen_moves.gd`): spinning heel, spin kick, back elbow, knee, throw, weapon throw, and body impacts.

---

## 8. How the player takes hits (all in `CombatActor`)

- **The way in:** `HitDetector._consider()` (`hit_detector.gd:164`). Victims must be on another team and pass `can_be_hit_by(attacker, move)` (`combat_actor.gd:273`):
  - not KO, not invulnerable, not flying (no juggling);
  - **while GRABBED only the holder can hit you** (`:276-277`);
  - DOWNED only by `hits_downed` moves.
  - Then `receive_hit()` (`:404`).
- **Inside `receive_hit()`:**
  1. Return false if KO or invulnerable.
  2. `_try_block()` (`:793`): the guard faces the **look** (`_guard_facing`).
  3. Apply damage (`god_mode` zeroes it for team 0) and set `hit.killed`.
  4. Emit `health_changed`.
  5. Start the contact flash.
  6. Cancel the running move.
  7. Call `_on_hit_received(hit)`, the player's (`player.gd:597`):
     - reset the parser chain and buffer, `_held_attack`, `_air_attack` and `_cam_offset`;
     - if the player is holding someone, hitstop the held body and release it with a stagger.
  8. `_apply_reaction(hit)` (`:949`).
  9. Emit `ko` if `hit.killed`.
- **Reactions** (`_apply_reaction`):

  | Reaction | Result |
  | --- | --- |
  | FLINCH | HITSTUN for `move.hitstun`, with a flinch animation by region and side |
  | STAGGER | STAGGER for `stagger_frames` (40), with a directional animation; a body-impact flyer if pushed fast enough |
  | KNOCKDOWN, LAUNCH, THROWN | `_launch()` (`:1002`) → LAUNCHED or THROWN → `_land_from_flight()` (`:1061`) → DOWNED for `downed_frames` (75) → `_start_getup()` (`:1073`): GETUP for `getup_frames` (30) with `getup_invuln_frames` (30) → FREE |

  A killing hit whose reaction is NONE, FLINCH, STAGGER or GROUND becomes a KNOCKDOWN with at least `ko_push` and `ko_lift` (`:962-964`). Landing with health 0 goes to `_enter_ko()` (`:1090`): ghost body, hurtboxes off, KO. `downed_frames`, `getup_frames` and `getup_invuln_frames` are **shared by the player and every enemy**. SPEC §7's enemy get-up of 1.0-1.5 s means changing them, or splitting them per archetype.
- **The player has no ragdoll** unless `Tuning.ragdoll_player` (`combat_actor.gd:1139`). It animates every reaction, and the first-person view rides those animations (the KO view is the exception).
- **Invulnerability:** `_invuln_frames` counts down in sim frames (`combat_actor.gd:641`), so it does not run down during hitstop.
  - Dodge: `dodge_invuln_frames` 8 of `dodge_frames` 14 (`player.gd:892-893`).
  - Get-up: 30 frames.
  - KO counts as invulnerable (`is_invulnerable()`, `:220`).
- **KO and revive:**
  1. `_tick_ko()` (`player.gd:634`): with `auto_revive`, after `player_revive_s` (2.5 s, in Tuning "Sparring"), call `_revive()` (`:640`).
  2. `_revive()`:
     - full health and guard, hurtboxes back on;
     - `look_yaw = rotation.y` and `_ko_getup = true`;
     - emits `health_changed` and `revived`;
     - `_start_getup()` (with get-up invulnerability).
- **KO view** (`first_person_camera.gd:23-31`, `:283-347`; ARCHITECTURE "KO view"):
  - Triggered by **`player.health <= 0.0`** alone (`:297`), never by the state. It runs on the player's sim time (`TimeController.scale_for(player)`).
  - `_choose_ko_pose()` (`:412`) runs once at the killing blow. It reads `player.sim_velocity` (which way the head goes), the rig's basis and Hips, and `_ko_crowding()` (`:442`). That avoids **standing actors**, i.e. the enemies around you.
  - `_ko_room()` (`:463`) ray-tests and sphere-tests the world and enemy body layers. **With 6 enemies ringing a KO'd player, expect the steep over-the-hips pose often.** Check it in a crowd capture.
- **Camera feel on hits:** `FirstPersonCamera._on_hit_landed` (`:554`) adds trauma and a punch for **every** `hit_landed` with the player as attacker or victim. A spin kick through 4 enemies adds trauma 4 times (it clamps at 1; shake is trauma²). Punches merge (`add_punch` `:182`).

---

## 9. Grabs, with the player as holder

**Flow:**
1. LB → `_grab_action` → `_find_grab_target` → `_start_grab(victim)` (`player.gd:983`):
   - reset the chain; set `_held`, `_hold_frames` and `_knees`;
   - **`victim.start_grabbed(self)`**; stop;
   - GRABBING, the `grab` animation, the `hold` move set.
2. `_control_holding` (`:517`) each tick:
   - the validity check (`_holding_valid()` `:1067`: valid, the victim GRABBED, and its holder is self);
   - auto-release at `hold_max_frames`;
   - steer at `hold_move_mult`;
   - LB releases (no stagger);
   - P = knee, K = throw (through the parser's `hold` set).
3. Knees count in `_on_move_hits` (`:581`); the third (`max_knees`) releases with a stagger.
4. The throw: `_on_move_frame` at the throw's startup calls `_throw_held` (`:1082`), a code-built `HitInfo` with reaction THROWN and the stick direction.
5. `_on_move_finished` (`:551`) returns to GRABBING if the hold is still valid, else to neutral.
6. A hit on the player releases the held body (`_on_hit_received` `:603-608`).

**Generic, in `CombatActor`, reusable for an enemy holding the player:**
- `holder` (`:78`);
- `start_grabbed(by)` (`:467`): cancels the move, ghost body, GRABBED, `held` animation, stops the ragdoll, emits `grabbed`;
- `release_from_grab(push, stagger)` (`:487`): solid again, STAGGER or FREE, `_leave_hold_under_hips()` (`:1432`), emits `released`;
- `_pin_spot()` (`:1401`): on the floor under the holder's rig `HoldPoint` (`placeholder_body.gd:86,105`: Chest + (0, 0.07, −0.55));
- `_pin_to_holder(dt)` (`:1409`): eases in over `grab_pin_ease_s` and turns to face the holder; **runs in the victim's `_physics_process`, not in a sim tick**;
- `can_be_grabbed()` (`:260`);
- the GRABBED rules in `can_be_hit_by` (`:276`) and `_apply_reaction` (`:952-958`);
- `_launch(from_hold)` (`:1003`).

**Player-only (in `player.gd`):**
- `_held`, `_hold_frames`, `_knees`;
- `_holding_valid`, `_release_held`, `_throw_held`, `_start_grab`, `_find_grab_target`, `_grab_action`, `_control_holding`;
- the hold view: `_hold_view`, `_hold_lens`, `_hold_shift`, `_hold_kept`, `_hold_from`, `_tick_hold_view` `:1002`, `_tick_hold_shift` `:1042`, `_keeps_hold_bend` `:1028`, `_ramp`, `_lens_ease`, and the getters in section 4.
- The holder's knee and throw moves and `hold.tres`.

**Enemies have no holder logic.** An enemy that grabs needs its own GRABBING control (victim, hold timer, the hit, release on interruption), or the player's holder side must be lifted into the base class. Lifting it means rewriting the hold-view code that `test_grab_view.gd` checks closely. **Recommendation:** keep the player's holder side as it is, and write the enemy holder in the shared enemy base.

---

## 10. Quick turn, dodge, block (the player's side)

- **Quick turn:**
  - `_start_quick_turn()` (`:903`): ignored while one is running. It always turns **+π (to the left)** over `quick_turn_frames` (12 = 0.2 s) and emits `quick_turned`. `_tick_turns` applies it to `look_yaw` (`:917-921`), so the body follows in steerable states.
  - Accepted in FREE, in a cancellable ATTACK recovery, in BLOCK and BLOCKSTUN. Not while holding (the hold set has no TURN, and the press ages out) and not in reactions.
  - A quick turn started just before a hit keeps turning the **look** through the hitstun; the body catches up at FREE.
- **Dodge:**
  - `_b_action()` (`:864`): B with the stick ≥ `block_stick_threshold` → `_start_dodge` (`:881`). A fixed velocity covers `dodge_distance` 3 m over `dodge_frames` 14, plus `_invuln_frames = dodge_invuln_frames` (8). Emits `dodged`.
  - DODGE is **never grabbable** (not in `can_be_grabbed`'s list), so a dodge escapes a grab wind-up for all 14 frames, but strikes can land in frames 9-14.
  - Enemy bodies are solid to the player (`_set_ghost(false)` mask, `combat_actor.gd:1447-1454`), so a dodge into an enemy stops dead. **In a ring of 6 the player can be boxed in.** That's a feel risk for the crowd room; a design call, not a bug.
- **Block:** see ARCHITECTURE "Block". The guard faces the look and covers `block_arc_half_angle_deg` (60°), so **side and back hits land in full**, which is what makes flanking dangerous. A BLOCK or BLOCKSTUN player **can be grabbed** (grabs beat the guard). The held B re-raises the guard after a release (`_holding_block()` `:513`).

---

## 11. Cameras

**`CameraDirector`** (`camera_director.gd`):
- Group `"camera_director"`. It creates the three cameras in `_init` (`:32-42`). F2 → `cycle()` (`:61`); `set_mode()` (`:67`) emits `camera_changed`.
- `refresh_player()` (`:99`) re-finds the player through the `"player"` group every frame while it has none. A scene switch or reload therefore needs no wiring.
- `add_trauma()` (`:93`) forwards to the first-person camera. `active_camera()` (`:83`).

**`FirstPersonCamera`** (`first_person_camera.gd`):
- Settings: `top_level`, `keep_aspect = KEEP_WIDTH` (so **`fov_deg` is the horizontal FOV**, 90 by default and 75-110 in Tuning), `near` 0.05, the `VIS_FP_HIDDEN` layer culled, interpolation off (`_init` `:100-111`).
- **The view is built only from the player's public getters** (`_follow` `:218`, `_view_with` `:253`):
  - position: interpolated origin + the smoothed eye offset (`get_eye_transform()`), with the walking bob clamp weighted by `get_hold_view_weight()`;
  - drop: `get_camera_move_offset().y`, plus the hold rise swapped for its smoothed value;
  - turn: `Basis(UP, get_camera_view_yaw(fraction)) * get_look_basis()`;
  - lens: `lens_offset(look_basis, hold_shift.y)` (`:274`), with `cam_height_offset_m` −0.2 and `cam_forward_offset_m` 0.04;
  - pitch: `get_camera_move_offset().x` added (clamped ±89°, `:591`).
- **Extension point:** anything the player's view must do while held can be expressed through `get_camera_move_offset()`, `get_hold_view_shift()` and `get_camera_view_yaw()`, with **no edit to the camera**.
- `snap()` (`:144`) jumps to the eye on the next update; `set_player()` (`:133`) resets the KO view.
- Punch and shake feel numbers are `@export`s on the camera node (`:33-46`), not in `TuningData`. That's pre-existing; leave it.
- Read API: `view_transform()` (`:160`), `ko_view_weight()` (`:167`), `get_punch_deg()`, `is_settled()`, `trauma`.
- The camera writes nothing to the simulation. It subscribes only to `CombatEvents.hit_landed` (`:114-121`).

**`SideViewCamera`** follows the player along world X; **`FreeFlyCamera`** uses the `fly_*` actions and the middle-button mouse. Both are debug only. Neither reads look or KO state.

---

## 12. What M3 needs here

### 12.1 The player grabbed by an enemy (the Bruiser's grab and headbutt, the boss's grab slam)

Game-boy's rule:
- the grab has a telegraphed wind-up; a dodge or a heavy hit gets out of it;
- once held, mashing P/K breaks free before the hit;
- unbroken, the hit lands.

**What already works on the player's side:**
- **The gate:** `player.can_be_grabbed()` (`combat_actor.gd:260`) is true in FREE, HITSTUN, STAGGER, BLOCK, BLOCKSTUN, and ATTACK outside the active frames. It is false while invulnerable (the dodge's i-frames, the get-up), and in DODGE, AIRBORNE, GRABBING (a player holding an enemy cannot be grabbed), DOWNED, GETUP, LAUNCHED and KO, and when already held. So "a dodge gets out of it" is already true for the whole dodge, and so is a jump. The enemy should test `can_be_grabbed()` at the connect frame, not at the wind-up's start, and **whiff** if it is false.
- `start_grabbed(enemy)` puts the player in GRABBED as a ghost body, pinned at the enemy's `HoldPoint` and facing it, and emits `grabbed(enemy, player)`.
- While GRABBED only the holder can hit the player (`can_be_hit_by`). The other five enemies' strikes whiff, so the director should not hand them tokens against a held player.
- The guard is dropped (`_enter_state` clears it); a B still held re-raises it after the release.

**What is missing or wrong (fix in `player.gd` unless stated):**
1. **No GRABBED control.** GRABBED falls into the `_:` arm (`player.gd:321-322`), which clears the parser buffer every tick. Add a `CombatTypes.ActorState.GRABBED:` arm calling a new `_control_grabbed()` that:
   - drains P and K with `while parser.consume(CombatTypes.IN_PUNCH)` and `parser.consume(CombatTypes.IN_KICK)`, adding to a mash counter;
   - then `parser.clear_buffer()`;
   - at `Tuning.grab_break_presses` breaks free.
2. **Stale state from a grab mid-move.** `start_grabbed()` calls `_cancel_move()`, which does **not** call `_on_move_interrupted()`. So a player grabbed in a kick's startup or recovery keeps:
   - the kick's camera pitch and drop (`_cam_offset` is only refreshed in `_on_move_frame`, so it freezes for the whole hold, about −8 to −12° and 5 cm);
   - the parser chain (`reset_chain` per ARCHITECTURE's ComboParser rules);
   - `_held_attack`.

   Add a victim-side hook to `CombatActor`, e.g. `_on_grabbed(by: CombatActor)`, called at the end of `start_grabbed()`. The player's override:
   - resets `_cam_offset`, the chain, the buffer, `_held_attack`, `_air_attack`, `_turn_frames`, `_quick_turn_frames` and the mash counter;
   - starts the look turn toward the holder (item 3).
3. **Look lock.** In GRABBED the body is turned to face the holder by `_pin_to_holder` (`combat_actor.gd:1422`), but the live look still turns. The view would leave the grabber, and the body snaps to the look at release.
   - Extend the `_process` gate (`player.gd:165`) with `or state == CombatTypes.ActorState.GRABBED`. The mouse delta is already consumed before the gate, so it is dropped.
   - Ease `look_yaw` toward the holder with the existing `_turn_left` / `_turn_frames` turn (`player.gd:56-57`, applied by `_tick_turns`) over a new `Tuning` frame count. At release the look and the body already agree, so nothing snaps.
   - Keep `look_pitch` (or ease it toward level: a decision for the plan).
4. **The first-person view while held.**
   - The camera rides `EyePoint` in whatever pose the player's rig plays. `start_grabbed` plays **`&"held"`**, the *bent-over victim* pose (`placeholder_poses.gd:289-296`). From the player's eyes that pose looks into the grabber's belly at about 0.35 m. It is authored for an enemy held by the player, not for the player.
   - `_pin_spot()` puts the player's origin 0.55 m ahead of the grabber's chest, so even upright the lens would sit close to the grabber's chest.
   - Needed:
     - a player-held pose (upright, gripped at arm's length; rig area: `placeholder_poses.gd` and `placeholder_anims.gd` `ANIM_IDS` and `LOOPING`, `:20-36`);
     - a virtual play: let `start_grabbed()` call an overridable `_held_anim() -> StringName` instead of the literal `&"held"`;
     - a farther pin for the player: override `_pin_spot()` in `player.gd`, or read a new holder rig point or Tuning distance.
   - Express any view nudge (pitch up to the grabber's face, a pull-back) through `get_camera_move_offset()` / `get_hold_view_shift()`; then `first_person_camera.gd` is untouched.
   - Judge the result with `tests/fp_view.gd`: the own body covers at most a third of the view, the grabber's head and hands stay at least 0.25-0.3 m from the lens, and the headbutt reads.
5. **Breaking free.**
   - Call `release_from_grab(push_away_from_holder, false)`. This makes the body solid again, sets FREE, plays `idle` and emits `released(holder, player)`.
   - Give a few i-frames (new Tuning) so the holder's pending hit cannot land on the same tick.
   - The **holder** must notice and react (stagger or recoil). Either it checks `victim.state == GRABBED and victim.holder == self` each tick, as the player's `_holding_valid()` does, or a new `CombatEvents` signal (e.g. `grab_escaped(victim, holder)`; `combat_events.gd` is a contract file) tells it.
   - Report progress for a HUD prompt through a public getter, e.g. `grab_break_progress() -> float`.
6. **The hit that lands unbroken.** Watch `_apply_reaction`'s GRABBED rule (`combat_actor.gd:952-958`): **a non-killing hit from the holder whose reaction is not THROWN keeps the victim GRABBED** and only replays `held` (it was written for the player's knees). So a headbutt with KNOCKDOWN or STAGGER would **not** knock the player out of the hold. The holder must either:
   - `release_from_grab()` the player first, then apply its hit (a code-built `HitInfo` like `_throw_held`, `player.gd:1082`); or
   - use `Reaction.THROWN` (it flies out like a throw, `_launch(from_hold = true)`).
7. **The holder's strike on a first-person body.** `_pull_strike` (`combat_actor.gd:636-640`) snaps the **attacker's** rig to `idle` on the first sim frame after any hit that lands on `first_person_body` (the player). A headbutt or slam from a holding enemy would flash its hold pose to idle. The holder needs an exemption, e.g. skip it while the attacker is GRABBING.
8. **The holder becoming invalid.** `_pin_to_holder` releases only when the holder node is **freed** (`combat_actor.gd:1410-1412`).
   - If the holder is knocked down by a flying body, KO'd or blinked off (`_vanish()` keeps the node valid), the player stays pinned to it: following a flying body, or held by an invisible one.
   - The enemy holder must release on its own `_on_hit_received`, as the player does at `player.gd:603-608`.
   - Add a victim-side safety net too: in `_control_grabbed()`, if the holder is not in its holding state, or is KO or gone, release.
9. **Physics order.** The victim pins in **its own** `_physics_process`, reading the holder's `HoldPoint` from the holder's latest rig advance.
   - Player holding an enemy: the player runs first (tree order), so the enemy reads the current tick. Correct.
   - Enemy holding the player: the player runs **before** its holder, so it trails the holder's pose by one tick, which may show as jitter in first person when the holder walks or sways.
   - Options:
     - raise the player's `process_physics_priority` above the enemies' while GRABBED and restore it on release (check the property in the 4.7 doctool);
     - spawn enemies before the player;
     - pin from the holder's tick.
   - Verify with a capture.
10. **The release in first person.** `release_from_grab()` and `_launch(from_hold)` call `_leave_hold_under_hips()` (`combat_actor.gd:1432`), which **moves the origin** under the drawn hips (`held` has a 0.3 m hips nudge).
    - The first-person camera follows the origin rigidly and damps only the eye offset, so the view jumps by that amount and eases back over `cam_smoothing_s`.
    - Use a player-held pose without a hips nudge, or have the camera `snap()` on `CombatEvents.released` when the victim is its player. Both are presentation-legal.

**The KO view while held:**
- A killing hit from the holder bypasses the GRABBED rule: `holder = null`, then a forced KNOCKDOWN with `ko_push` and `ko_lift`, then `_launch(from_hold = true)` (`combat_actor.gd:958-964`, `1003-1018`).
- `health <= 0` starts the KO view regardless of state. `_choose_ko_pose` reads `sim_velocity`, which is already set by `_launch`, and `_ko_crowding` steers the lens away from the standing grabber. No camera change is needed.
- Item 10's origin jump happens at the killing blow, under a lens that is starting to leave. Look at it in a capture.
- The look lock (item 3) and the KO lock compose: `_revive()` puts `look_yaw` on the body anyway.
- A grab cannot start on a KO'd, downed, getting-up or launched player (`can_be_grabbed`), so no grab can begin under the KO view.

**Suggested tunables** (in `tuning_data.gd`, e.g. a new subgroup under "Grab and weapons" or "Enemies"; regenerate `res://tuning/default.json` and keep `tests/test_tuning_panel.gd` green):
- `grab_break_presses` (int);
- optionally `grab_break_decay_per_s`;
- `grab_break_invuln_frames`;
- `grab_break_push` (m/s);
- `grabbed_turn_frames` (the look easing to the grabber);
- the player-held pin distance;
- any held-view pitch or pull-back.

The hold time before the headbutt or slam belongs to the enemy's move or tunables.

**Tests to add:**
- a scripted mash: `push_press(&"P", 1)` × N breaks free before the hit, and N−1 does not;
- the look doesn't turn while held (the `_process` mouse pattern from `test_ko_view.gd:606`) and faces the grabber;
- no stale `_cam_offset` after a grab during a kick's recovery;
- the holder hit by a flying body releases the player;
- a dodge or jump through the wind-up is never grabbed;
- a killing slam starts the KO view and the player revives;
- the first-person coverage checks with `fp_view.gd`.

### 12.2 Magnetism with 6 enemies

Most of it works unchanged. Checklist for the archetype and director builders:
1. **Join the `"enemy"` group** in every archetype's `_ready` (the base doesn't). Without it there is no magnetism, grab, stomp condition or KO-blink search.
2. **Free the gone.** The group search (`_find_magnet_target`, `_find_grab_target`, `_downed_target_near`) and the camera's `_ko_crowding` and debug draw iterate their groups every tick. Gone bodies stay in the group, skipped but iterated, until freed. With repeating waves, `queue_free()` an enemy on `CombatEvents.vanished`, or the groups grow without bound.
3. **Invulnerable get-ups.** Magnetism doesn't skip `is_invulnerable()`. With bodies getting up all over a crowd, a strike may lunge and turn toward one in its 30 get-up i-frames and whiff. Options:
   - skip invulnerable bodies (the strike goes to the next enemy, and no lunge toward a body that can't be hit);
   - leave it (it keeps tracking a body you are fighting).

   A decision for the plan. `test_ko_blink.gd` already pins the blink-in skip.
4. **Big bodies** (Bruiser, boss):
   - `_stop_distance()` is a fixed 0.85 m centre to centre, which ignores the target's `body_radius`. A Bruiser or boss with a radius over about 0.5 m means the lunge drives into its capsule (`move_and_slide` stops it, harmless) and the reach is judged against the wrong distance. Consider `magnet_stop_distance + (target.body_radius - Tuning default)`.
   - The cone angle is 3D, chest to chest. A tall boss's chest sits about 15-20° above the player's at 1 m: inside 35° looking level, but it can drop out if the player looks down.
5. **The stomp takes over K** (`player.gd:732`, root order at `tools/gen_moves.gd:276`). Any downed enemy within 1.5 m and 70° of the body turns the first K into a stomp, even with a standing enemy dead centre. In a crowd with bodies on the floor this will happen often. Options:
   - require that the stomp target also beats any standing magnet target, or that there is no standing enemy in the cone;
   - leave it.
6. **No occlusion test.** A farther enemy behind a nearer one at a similar angle loses on the 4°/m tie-break. A crate or wall between the player and an enemy is not checked (2.5 m range keeps that rare).
7. **The grab target is the nearest, not the centred one** (within 60° of the body). In a scrum LB may grab the enemy beside the one you look at. LB near a dropped pipe *and* a grabbable enemy grabs the enemy (`_grab_action` order).
8. **F3 already draws the cone and its `target`** (`get_magnetism_cone()`). If the director wants it, the same debug pass could draw the view wedge of 12.3.
9. **Cost:** six enemies × one group walk per sim tick is negligible.

### 12.3 "Where the player looks": the API the director and the rear warning should read

**Rule:** simulation (the director's blind-spot priority, token logic) must not read a camera (ARCHITECTURE "Layers"). The rear warning is presentation and *may* read the camera, but it should **not**:
- During spins (spin kick, spinning heel, spinning backfist) the first-person view sweeps 360° (`get_camera_view_yaw()`), and the back elbow turns the view over the shoulder (`camera_yaw_deg`). A camera-based angle would flip corners mid-spin.
- During the KO view the camera is out of the body.
- In the side view and free fly there is no first-person forward at all.

So use **one definition, from `look_yaw`**, for both. That also lets tests set `look_yaw` and enemy positions directly, with no camera (headless tests use `with_presentation = false`).

**Proposed additions to `PlayerCharacter`** (one small "contract" commit, merged before the parallel packages, since several of them read it):

```gdscript
## Flat unit vector the player looks along (look_yaw only; pitch ignored). Simulation-safe:
## never the camera. Aim, the director's blind spot and the rear warning all read this.
func get_look_forward() -> Vector3:
	return Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))


## Signed flat angle in degrees from the look to `point`: 0 dead ahead, positive to the
## left, +-180 directly behind. Measured from the body's origin (global_position), not the
## eye, so the pose (the hold's bend) never moves it.
func look_bearing_deg(point: Vector3) -> float:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(wrapf(atan2(-to.x, -to.z) - look_yaw, -PI, PI))


## True when `point` lies more than `half_angle_deg` (flat) from the look: outside the view.
func is_outside_view(point: Vector3, half_angle_deg: float) -> bool:
	return absf(look_bearing_deg(point)) > half_angle_deg
```

(`atan2(-to.x, -to.z)` is the yaw convention already used at `player.gd:662`. Positive left matches `look_yaw`. Optionally refactor `_guard_facing`, `_input_world_dir` and `_start_dodge` onto `get_look_forward()`.)

**How each consumer uses it:**
- **Director** (simulation): blind spot = `player.is_outside_view(enemy.global_position, Tuning.data.rear_warning_angle_deg)`. Or add a separate `blind_spot_angle_deg` in "Enemies". One shared number is the simpler and more consistent default: what counts as "out of view" should be one value.
  - It should also skip or hold tokens while the player can't be hit: `player.is_ko()`, `is_downed()`, `is_flying()`, `is_invulnerable()` (the get-up and revive), or `state == GRABBED` (only the holder can hit).
  - Consider a grace period after `CombatEvents.revived`. A revive puts the player on their feet inside the ring with 30 i-frames.
- **Rear warning** (HUD, subscribes to `CombatEvents.windup_started(attacker, move)`):
  - `b := player.look_bearing_deg(attacker.global_position)`. Fire if `absf(b) > rear_warning_angle_deg` and the flat distance ≤ the attack's range + 1 m.
  - Side: `b > 0` → behind-left → top-left; `b < 0` → top-right; `absf(b) >= 180 - rear_warning_behind_deg` → both corners. **Add `rear_warning_behind_deg` = 20 to the "Rear warning" group**, since the ±20° in SPEC §8 must not be a script constant.
  - End it on `hit_landed` with that attacker, `attack_whiffed`, or `windup_ended(attacker, true)`. Note that `windup_ended(attacker, false)` fires when the strike *comes out* (`combat_actor.gd:703-706`), not when it lands.
  - Optionally hide it while `director.first_person_camera.ko_view_weight() > 0`.
- **Already flat and look-based:** `AudioDirector.is_behind_listener()` (`audio_director.gd:212`), from the listener at the eye with `get_look_basis()`, against `rear_muffle_angle_deg` 110. A separate number for a separate effect. Leave it.
- **Not to use:**
  - `get_forward()` (the body; it lags the look in reactions);
  - `get_magnetism_cone()` (eye origin, 3D);
  - `get_camera_view_yaw()` (presentation only);
  - the active camera's basis (wrong in spins, the KO view and the debug cameras).
- **FOV note:** `fov_deg` is horizontal (KEEP_WIDTH). At the default 90° the screen edge is 45°, so an enemy at 45-55° is off screen but not "outside the view" by SPEC §8's 55°. This is as the spec says; no coupling to `fov_deg` is required.

---

## 13. Invariants (do not break)

- **No simulation code reads a camera.** Aim and awareness come from `look_yaw` and `look_pitch` (ARCHITECTURE "Layers"). Cameras, HUD, VFX and audio only read and subscribe; only `TimeController` writes time.
- **Camera rotation comes only from the look**, plus move and hold offsets via the player's getters. Never from the head bone (Spec §5).
- **No numbers in scripts.** New feel values go in `tuning_data.gd` as `@export_range` values in a group, with `##` docs (they become tooltips). Then regenerate `res://tuning/default.json` with `tools/gen_default_preset.gd`.
- **The head layer** (`VIS_FP_HIDDEN`) stays culled in first person, except during the KO view (`first_person_camera.gd:295-347`).
- **The KO lock:** no look from health 0 through the post-revive get-up; `_revive()` puts the look on the body (`test_ko_view.gd:606`).
- **The hold view is driven by sim ticks** (it holds still in hitstop) and eases from wherever it is (`test_grab_view.gd`).
- **The player's `_ready` measures `standing_eye_height` and `_hold_bend` from the rig.** New poses must not change `idle` or `hold`'s `EyePoint` silently.
- **`reset_state()`** (`player.gd:276`) must reset any new per-grab or per-view state you add. Bots call it between acts.
- **Owners call `parser.reset_chain()`** whenever a move is cut short or the context changes (ARCHITECTURE "ComboParser usage"). Being grabbed is such a change.

## 14. Gotchas

- Set the player's `rotation.y` **before** `add_child` (the look copies it in `_ready`), and set `auto_revive = true` in the crowd room.
- `get_forward()` is the body, not the look.
- `_tick_turns()` runs in every state. A quick turn or magnetism turn keeps rotating the look through a hitstun or a grab unless you zero `_turn_frames` and `_quick_turn_frames`.
- Look is written at the render rate (`_process`, the real-time `delta` for the stick) and at the sim rate (`_tick_turns`). Simulation readers see the latest value. Tests are deterministic only because scripted input skips `_process`.
- Presses during hitstop pile up and arrive on the next sim tick. Presses in reaction states are discarded every tick (the `_:` arm).
- `push_press(b, 1)` takes 2 ticks; mash tests can't exceed 30 presses per second without building frames by hand.
- `_cancel_move()` doesn't call `_on_move_interrupted()`, so anything that cancels the player's move without a hit (`start_grabbed`) leaves `_cam_offset` and the chain stale.
- `_apply_reaction`'s GRABBED rule swallows non-THROWN, non-lethal holder hits (12.1 item 6).
- `_pull_strike` snaps the attacker of a first-person hit to `idle` (12.1 item 7).
- `_pin_to_holder` only notices a freed holder (12.1 item 8).
- The victim pins in its own physics callback, which is order-dependent (12.1 item 9).
- `release_from_grab` and `_launch(from_hold)` move the origin under the hips (12.1 item 10).
- `downed_frames`, `getup_frames` and `getup_invuln_frames` are shared by the player and all enemies.
- The cheat menu's spawn ray deliberately reads the first-person camera (`cheat_menu.gd:127-137`). It is a debug tool, allowed like `TimeController`. Reuse `spawn_point()` for "spawn any enemy at the crosshair".
- `GameInput.BINDINGS` actions are lifted out of the InputMap while F1 or F4 is open (`tuning_overlay.gd`). A new room-switch key added there is handled automatically; add it to the help overlay too.
- R while paused reloads the **current** scene (`game_input.gd:134`). The camera director re-finds the player by group, so a room switch needs no camera wiring.
- The player is solid to enemies (`_set_ghost(false)`). Navigation avoidance will not see the player unless the player gets an avoidance obstacle or agent (`player.tscn` is bare, and its children are built in code).

## 15. Conflict hot spots (files several M3 packages will want)

| File | Who wants it |
| --- | --- |
| `game/player/player.gd` | The look API (director and rear warning), the GRABBED control and mash, the look lock and held view (enemy grabs), magnetism changes (crowd), maybe an avoidance obstacle. **Land the look API and the `_on_grabbed` hook first, in one small commit; give the rest to one package.** |
| `game/actors/combat_actor.gd` | The enemy grabs (the `_on_grabbed` hook, `_held_anim()`, the `_pull_strike` exemption, the pin's holder check), the archetypes (Bruiser armor, wind-up interrupt rules), the director (states and tokens) |
| `game/autoload/tuning_data.gd` (+ `res://tuning/default.json`, `tests/test_tuning_panel.gd`) | Every package adds tunables: Enemies, Rear warning (`rear_warning_behind_deg`), enemy grabs, magnetism, spawns. One owner, or merge by appending whole groups |
| `game/autoload/combat_events.gd` | New signals (grab escaped, tokens). A contract file; agree before the parallel build |
| `game/autoload/game_input.gd` | The room-switch key, maybe spawn keys |
| `game/actors/placeholder_poses.gd`, `placeholder_anims.gd` | The player-held pose, the enemy grab, headbutt and slam poses, the archetype stances |
| `tests/test_combat_integration.gd`, `tests/bot/combo_bot.gd` | Shared harnesses, and both bound to `test_room.tscn` (keep that room working) |
| `project.godot` | The main scene changes to the crowd room |
| `game/camera/first_person_camera.gd` | Ideally **untouched**. At most a `snap()` on `CombatEvents.released` for the player (12.1 item 10) |
| `docs/ARCHITECTURE.md` | "Interfaces" (the new player API) and a new "Enemy grabs" section |
