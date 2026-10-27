# M3 codemap: actor core and combat

Read this before you touch `CombatActor`, the hit pipeline, or anything an enemy controller drives. It maps the code as of `m3/enemy-ai` at `3f5a866` (M2 merged). Every reference is `file:line` at that commit.

Files covered:
- `game/actors/combat_actor.gd` (1480 lines)
- `game/combat/hit_detector.gd`, `combat_types.gd`, `hit_info.gd`, `move_data.gd`, `move_set.gd`, `combo_branch.gd`, `hitbox_spec.gd`, `hurtbox.gd`
- `game/autoload/combat_events.gd`, `time_controller.gd`

Also read where they matter: `game/player/player.gd` (the only holder-side grab code), `game/enemies/dummy/training_dummy.gd` (the only enemy controller so far, and the M3 attack plumbing's first piece) and `game/weapons/weapon.gd`.

Short names used below: **CA** = `game/actors/combat_actor.gd`, **HD** = `game/combat/hit_detector.gd`, **PC** = `game/player/player.gd`, **TD** = `game/enemies/dummy/training_dummy.gd`, **TDa** = `game/autoload/tuning_data.gd`.

---

## 1. The big picture in 12 lines

- `CombatActor extends CharacterBody3D` (CA:1) is the base for the player, the dummies and every M3 enemy. It owns health, the reaction state machine, move execution (hitboxes, lunge, the enemy wind-up), the block, grabs (the **victim** side only), flying-body impacts, ragdoll hand-offs and the KO blink-off.
- Subclasses drive behaviour from one per-sim-frame hook, `_tick_control()` (CA:563), plus about a dozen other hooks (§6).
- Time: each physics tick, the actor reads `TimeController.scale_for(self)` (0 in its hitstop) and runs whole **sim frames** (`_sim_tick()`, CA:634). Frame counters (`state_frame`, `move_frame`, every timer) count sim frames. AI timers written in sim frames inside `_tick_control()` therefore freeze in hitstop and slow in slow-mo for free.
- A move: `start_move(move, chain_step, input_timing, windup)` (CA:432). With `windup = true`, the startup frames run in `WINDUP` and emit `windup_started` / `windup_ended`. Active frames test hitboxes (`HitDetector.process()`, HD:34) against hurtboxes. Each hit is built into a `HitInfo` and applied by `victim.receive_hit(hit)` (CA:404).
- `receive_hit()` either blocks (`_try_block()`, CA:793) or applies damage, cancels the victim's move and applies a reaction (`_apply_reaction()`, CA:949).
- Grabs: the holder side (find, hold, knee, throw, release) lives **only in `PlayerCharacter`**. `CombatActor` has only the victim side: `start_grabbed()` (CA:467), `_pin_to_holder()` (CA:1409) and `release_from_grab()` (CA:487).
- Presentation hears everything through `CombatEvents` (§9). The only write-back is `TimeController` (§10).

---

## 2. Identity: team, groups, physics layers

| Thing | Where | Notes |
| --- | --- | --- |
| `team: int` export, 0 = player, 1 = enemies | CA:57 | Default 1. The player sets 0 in `_ready()` (PC:104). |
| Group `"actor"` | CA:146 | Added by the base for everyone. |
| Group `"player"` | PC:106 | |
| Group `"enemy"` | TD:74 | **Not added by the base.** Every new archetype must `add_to_group(&"enemy")` itself, or magnetism (PC:700), grab targeting (PC:970), stomp conditions (PC:734), the cheat menu (`game/ui/cheat_menu.gd:107`, `:196`, `:213`) and the health bars won't see it. |
| `max_health` export | CA:55 | `_ready()` copies it into `health` (CA:147). Set it **before** `super._ready()`, as TD:75 does. |
| `body_radius`, `body_height` exports | CA:59-60 | Capsule size; `rig.height = body_height` (CA:1477) scales the whole rig (`_scale = height / REF_HEIGHT`, `humanoid_rig.gd:189`): strike points, hurtboxes, HoldPoint and move animations all scale with it. A bigger Bruiser or boss only needs a bigger `body_height`. |

**Team effects** (things `team` switches):
- `HitDetector._consider()` skips victims on the attacker's own team (HD:168). Enemies never hit enemies, and a ground pound never hurts the Punks.
- Flying-body impacts hit **only the same team** (`_check_body_impacts()`, CA:1363). An enemy launched by the player knocks down other enemies. A flying player never touches enemies, and a flying enemy never touches the player.
- `god_mode` protects team 0 and `one_hit_ko` hits team != 0 (CA:410-413, chip at CA:816).
- Ragdolls are for team != 0, unless `Tuning.ragdoll_player` (`_ragdoll_allowed()`, CA:1139).
- The KO blink-off is for team != 0 (`_blinks_off_when_ko()`, CA:622).
- The body's collision layer depends on team (`_set_ghost(false)`, CA:1447).

**Physics layers** (`CombatTypes`, `combat_types.gd:60-70`; `bit(layer)` at `:80`):

| State of the body | `collision_layer` | `collision_mask` | Set at |
| --- | --- | --- | --- |
| Standing (solid) | PLAYER_BODY (2) or ENEMY_BODY (3), by team | WORLD, PLAYER_BODY, ENEMY_BODY | CA:1447-1454 |
| Ghost: flying, downed, getting up, held, KO | DOWNED_BODY (6) | WORLD only | CA:1443-1445 |
| Vanished (blinked off) | 0 | 0 | CA:1130-1131 |

- Standing enemies are **solid** to each other and to the player (mask 2|3). They slide against each other in `move_and_slide()`. Game-boy's "enemies don't block" default means no guard, not no collision.
- Ghosting happens in `start_grabbed()` (CA:475), `_launch()` (CA:1008) and `_enter_ko()` (CA:1093). Solid again at the end of `GETUP` (CA:689) and on release (CA:490). During DOWNED and GETUP the body is a ghost, so a standing body can end up inside it when it turns solid again. The dummy has its own fix for comebacks (TD:112 `_turn_solid()`); in a crowd, expect occasional overlap pops after get-ups.
- Hurtboxes are `Area3D`s on LAYER_HURTBOX (4), monitorable only (`hurtbox.gd:13-17`). HD queries areas on that mask only (HD:21-23). `rig.set_hurtboxes_enabled(false)` turns them off (KO, CA:1096; vanish, CA:1127).
- Body-impact queries hit bodies on PLAYER_BODY | ENEMY_BODY (CA:155-157).
- NavigationAgent3D avoidance is separate from these layers (avoidance layers). Bake the navmesh from WORLD geometry only, not actor capsules.

---

## 3. State machine

### 3.1 States (`CombatTypes.ActorState`, `combat_types.gd:29-46`)

| State | Who uses it | Ends by | Timer | Can act? |
| --- | --- | --- | --- | --- |
| `FREE` | all | the controller | none | yes: walk, start_move, start_block |
| `ATTACK` | all | move finishes, so `_on_move_finished()` runs (CA:714-718) | `move_frame` vs `total_frames()` | the move's own hooks; chain via `start_move()` |
| `WINDUP` | enemies (`windup = true`) | `move_frame >= startup` turns it into ATTACK (CA:703-706) | `move_frame` | `_tick_control()` still runs (turn, track) |
| `AIRBORNE` | player jump; anyone off a ledge | floor contact if `_auto_land()` (CA:695-697); the player lands itself (PC:924) | none | |
| `DODGE` | player only | PC:436 | `_state_length` | |
| `HITSTUN` | flinch; recoil from a blocked attack (`_recoiling`) | `state_frame >= _state_length`, then FREE (CA:666-669) | `move.hitstun` (FLINCH) or `blocked_recoil_frames` (recoil) | no |
| `STAGGER` | heavy hits, guard break, parried attacker, release-with-stagger | as HITSTUN | `Tuning.stagger_frames` (40, TDa:84), `guard_break_frames`, `perfect_block_stagger_frames` | no; **grabbable** |
| `LAUNCHED` | KNOCKDOWN, LAUNCH (and any killing blow) | landing: DOWNED, or KO if health is 0 (`_land_from_flight()`, CA:1061) | physics | no; can't be hit (`is_flying()`) |
| `THROWN` | THROWN reaction | as LAUNCHED | physics | no |
| `DOWNED` | after landing | `state_frame >= Tuning.downed_frames` (75, TDa:85) starts the get-up (CA:684-686). A GROUND hit pushes `state_frame` back by 20 (CA:985) | `downed_frames` | only `hits_downed` moves can hit it |
| `GETUP` | after DOWNED, after a player revive | `getup_frames` (30, TDa:86), then FREE, solid (CA:687-690) | `_state_length` | invulnerable for `getup_invuln_frames` (30, TDa:87) |
| `GRABBING` | **player only today** (holder) | PC:517-537 | the player's `_hold_frames` | |
| `GRABBED` | victim | the holder: `release_from_grab()` or a throw; also a killing blow, or the holder becoming invalid (CA:1410-1412) | **none on the victim side** | no; pinned |
| `KO` | from a landing with 0 health, or killed while DOWNED | the player: `_revive()` (PC:640); the dummy: `reset_state()` via `set_post(..., fresh)` | `_tick_ko_blink()` | no; invulnerable |
| `BLOCK` | anyone (`start_block()`) | `drop_guard()` countdown, then `_end_block()` (CA:679-683, 784) | `_guard_drop_left` | walk (controller), no attacks |
| `BLOCKSTUN` | blocked hit | back to BLOCK (CA:670-678) | `_state_length` | no |

### 3.2 The transitions that matter for AI

- **Killing blows never go straight to KO.** In `_apply_reaction()` (CA:962-964), a killing hit with reaction NONE, FLINCH, STAGGER or GROUND becomes a KNOCKDOWN with `ko_push` and `ko_lift` (TDa:143-144). The body flies (LAUNCHED) and enters KO **when it lands** (CA:1065-1067). So for 0.5-1 s, `health <= 0` while `state == LAUNCHED`. `CombatEvents.ko` fires at the killing blow (CA:423-424), not on landing. **A director or wave counter must treat `health <= 0` as dead**, not `is_ko()`. The exception: killed while DOWNED goes to KO at once (CA:959-961).
- `_enter_state(new, length)` (CA:763) is the only state writer. It resets `state_frame` and `_state_length`, clears `_recoiling`, drops guard bookkeeping when leaving a guard, and emits `state_changed(old, new)` (the actor's own signal, CA:38) plus `CombatEvents.actor_state_changed` (only when the state really changes). It also emits `block_ended` when leaving a guard. A move chained ATTACK to ATTACK doesn't re-enter; it only resets `state_frame` (CA:447-448).
- `_return_to_neutral()` (CA:756) means FREE on the floor, else AIRBORNE.
- `_cancel_move()` (CA:736) clears `current_move` and the lunge, and emits `windup_ended(self, true)` if it was in WINDUP. **It doesn't change state**; callers do.
- `reset_state()` (CA:506): full health, FREE, ghost off, hurtboxes on, shown, guard full, no holder. It is the respawn and debug reset. It doesn't notify a holder.

### 3.3 Sim time and the order of work in one tick

`_physics_process(delta)` (CA:163-202):
1. `scale = TimeController.scale_for(self)`. Accumulate it; run `_sim_tick()` once per whole unit, at most 4 per tick (CA:164-171).
2. If GRABBED: `_pin_to_holder(delta * scale)`. Otherwise, if `scale > 0` and not gone: `_integrate()`, which is gravity, friction in reaction states, `move_and_slide`, landing and body impacts (CA:1297-1324).
3. `rig.advance(delta * scale)`, then the hit flash bookkeeping (real ticks).
4. If a sim tick ran and the move is in an active frame: `HitDetector.process(move, move_frame)` against the **freshly posed** skeleton. Then `_on_move_hits()`, then the first-person strike pull (CA:192-202).

`_sim_tick()` (CA:634-656), in order:
1. `state_frame += 1`; the strike pull after a hit on a first-person body (CA:636-640);
2. invulnerability and blink-in countdowns;
3. `_guard_frames`, guard meter regen (`_tick_guard_meter()`, CA:884);
4. `_tick_reaction_timers()` (CA:664): state timers, the get-up, KO blink, auto-land;
5. if a move runs: `_advance_move()` (CA:700), which does `move_frame += 1`, WINDUP to ATTACK, the whiff event and the finish;
6. **`_tick_control()`**, the subclass hook;
7. if a move runs: `_apply_move_frame()` (CA:721), which steps the lunge, sets `_active_this_tick` and calls `_on_move_frame()`.

Consequences:
- **Start moves from inside `_tick_control()` (or a move hook), never from outside.** Started there, step 7 applies frame 0 in the same tick. Started from a director's own `_physics_process`, frame 0's lunge step and its `_on_move_frame(…, 0)` are skipped (the next tick advances straight to frame 1). The doc says so (CA:428-429). **A director grants tokens; the actor's `_tick_control()` starts the attack.**
- When a move ends (step 5, back to FREE), `_tick_control()` sees FREE in the same tick and can start the next one with no gap.
- `_tick_control()` does **not** run during the actor's hitstop (no sim ticks). Anything that must run in real time (rare) belongs elsewhere.
- Physics process order between actors follows tree order (only `TimeController` has a priority, 1000: `time_controller.gd:90`). Hits apply immediately inside the attacker's `_physics_process`. A victim processed earlier in the tick already moved this tick; one processed later moves after the hit. Hitstop starts on the **next** tick for both (`time_controller.gd:30`), so it is symmetric.

### 3.4 Frame timeline of a move

With startup S, active A and recovery R (`move_data.gd:12-14`), the tick that calls `start_move()` is frame 0:
- frames 0..S-1: startup (WINDUP if `windup`, else ATTACK). The lunge runs here by default.
- frames S..S+A-1: active. `_active_this_tick` makes HD test the hitboxes after the rig advances. At `move_frame == S`, `_advance_move()` turns WINDUP into ATTACK and emits `windup_ended(self, false)`: the strike comes out (CA:703-706).
- At `move_frame == S + A`, if the hitboxes are non-empty and nothing landed: `attack_whiffed` (CA:707-713). Blocked hits count as landed (`_move_landed_hit`, CA:198).
- At `move_frame >= S + A + R`: `current_move = null`, then `_on_move_finished(move)`. The default is `_return_to_neutral()` (CA:568-569).
- `MoveData` phase helpers: `is_startup/is_active/is_recovery/can_cancel` (`move_data.gd:94-107`), `total_frames()` (`:85`).

---

## 4. How a move starts and runs

### 4.1 `start_move(move: MoveData, chain_step := 1, input_timing := &"root", windup := false) -> void` (CA:432-453)

- It doesn't check the current state. **The caller must only start moves from FREE, a cancellable recovery, or a chain.**
- It resets `move_frame`, chain info, `_move_landed_hit`, `_pull_strike` and the lunge, and calls `_hit_detector.begin()` (HD:27). That clears "one hit per victim per activation", so **a two-hit punch is two MoveData chained, not one move** (each `start_move()` re-arms the detector).
- State: WINDUP if `windup and move.startup > 0`; else ATTACK. ATTACK to ATTACK only resets `state_frame`. **`windup = true` from ATTACK re-enters WINDUP**: every chained hit started with `windup` is a fresh telegraph, and fires the rear warning again.
- `rig.play_move(move)` (`humanoid_rig.gd:242`) builds and caches an animation per `(anim id, startup, active, recovery)`. A move id with no recipe in `PlaceholderPoses` falls back to a generic punch or kick and **push_warns** (`placeholder_anims.gd:357-363`). New enemy moves need recipes and an entry in `PlaceholderAnims.MOVE_IDS` (`placeholder_anims.gd:54`); both live in the rig area.
- `_plan_lunge(move)` (CA:605, a hook): the base lunges `free_lunge` straight ahead over `max(startup, 1)` frames. **`MoveData.magnetism` is player-only**: the base ignores it, and the player's override (PC:654) picks a target.
- Emits `attack_started(self, move, chain_step, input_timing)` at the **start of the wind-up**, not at the strike; then `windup_started(self, move)` if in WINDUP.
- **Velocity gotcha:** in FREE, ATTACK and WINDUP, `sim_velocity` has no friction and isn't overwritten by slides (`_self_propelled()`, CA:1327-1336; friction only in reaction states, CA:1339-1346). An actor that starts a move while walking **keeps sliding at walk speed through the whole move**. Zero (or set) `sim_velocity.x/z` when an attack starts, as `TD._spar()` does (TD:301-302). The lunge velocity adds on top (CA:1308).

### 4.2 Lunge (the enemy's "magnetism" hooks)

- `set_lunge(dir, distance, frames, budget := -1)` (CA:458): `distance` m along flat `dir`, spread over `frames` sim frames. `budget` caps a re-aimed total.
- `_update_lunge()` (CA:611), a hook run each move frame before the step (CA:723), can re-aim `_lunge_dir` and `_lunge_left` within `_lunge_budget`. The player's version tracks its magnet target and stops at `magnet_stop_distance` (PC:670-677). Enemies have none: **a tracking lunge for an enemy is an override in the enemy base**, modelled on PC:654-682.
- The lunge velocity applies only while `_running_move()` (WINDUP or ATTACK), CA:1308.
- For a lunge in the **active** frames (the boss's shoulder charge, the Kicker's jump kick), call `set_lunge(..., frames = move.active)` from `_on_move_frame()` at `frame == move.startup`. The default plans it over the startup.
- Bodies are solid, so a lunge into the player slides along the player's capsule rather than passing through.

### 4.3 Hitboxes and the hit pipeline (HD)

- `HitboxSpec` (`hitbox_spec.gd`): `POINT_SPHERE` on a rig point (`point`, `offset`, `radius`, `:15-18`) or `ARC` around the attacker's origin (`arc_radius`, `arc_half_angle_deg`, `arc_center_yaw_deg`, `arc_height`, `:22-28`). Rig points include `RightFistPoint`, `LeftFistPoint`, `RightFootPoint`, `RightKneePoint`, `WeaponTip` and `HoldPoint` (ARCHITECTURE "Rig points"; `WeaponTip`/`WeaponGrip` exist on **every** rig, `placeholder_body.gd:84-85`, `:103-104`, so any actor can swing pipe moves).
- `HitDetector.process(move, move_frame) -> Array[HitInfo]` (HD:34-87):
  1. Every hitbox queries LAYER_HURTBOX areas. Points also test the midpoint to last frame's centre, so they don't tunnel (HD:98-118); arcs filter by angle and height (HD:121-161). Results go to `attacker.debug_hitbox_volumes` for F3 (HD:44).
  2. `_consider()` (HD:164) skips the attacker itself, teammates, victims already hit this activation, and anything `victim.can_be_hit_by(attacker, move)` refuses. It keeps the nearest hurtbox per victim.
  3. Victims in distance order, up to `move.max_targets` (0 = unlimited): `_build_hit()` (HD:178) then `victim.receive_hit(hit)`.
  4. Hitstop: clean hits freeze the attacker plus clean victims for `Tuning.hitstop_s(tier)` (TDa:706), and a FINISHER also starts the global slow-mo after it. Blocked hits freeze for `block_hitstop_ms` (HD:75-81).
  5. `hit_landed` for every hit (HD:82-83).
  6. **If every hit this frame was blocked**: `attacker.react_to_block(strongest)` (HD:85-86).
- `_build_hit()` fields: `direction` is the flat attacker-to-victim radial (the attacker's forward at zero distance). `knockback` is `move.knockback` in the hit's frame (z along the radial, x its right, y up). `from_behind = victim.get_forward().dot(radial) > 0` (HD:199). `region` comes from the hurtbox; `chain_step` and `input_timing` from the attacker.
- `static hitstop_for(hit) -> float` (HD:92): the hitstop to use for code-applied hits (throws, body impacts, thrown weapons).
- **Code-applied hits** (no hitbox): build a `HitInfo` by hand, call `victim.receive_hit(hit)`, then `TimeController.hitstop([...], HitDetector.hitstop_for(hit))` and `CombatEvents.hit_landed.emit(hit)`. Templates: `PC._throw_held()` (PC:1082-1109), `CA._impact()` (CA:1371-1397), `Weapon._on_body_entered()` (`weapon.gd:103-134`). An enemy grab's headbutt or slam follows this pattern.

### 4.4 `HitInfo` (`hit_info.gd`)

| Field | Line | Notes |
| --- | --- | --- |
| `attacker`, `victim: Node3D` | 6-7 | Typed loosely. |
| `move: MoveData` | 8 | May be a **duplicate** (the dummy's scaled jab), so compare by `move.id`, not by identity. |
| `damage` | 9 | Rewritten by `receive_hit()` (god mode, one-hit KO, or the chip when blocked). |
| `tier`, `reaction`, `region` | 10-12 | `reaction` is rewritten when blocked (NONE or STAGGER). |
| `contact_point`, `direction`, `knockback` | 14-18 | |
| `from_behind`, `is_body_impact` | 20-22 | |
| `armor_absorbed` | 24 | **Exists, set by nothing yet.** It is the M3 armor flag (§11.2). |
| `killed` | 26 | |
| `physics_frame`, `move_frame`, `chain_step`, `input_timing` | 28-34 | `input_timing` values: `root`, `chain`, `pause`, `repeat`, `auto`, plus code-applied `body` and `thrown`. |
| `blocked`, `perfect_block`, `guard_broken` | 36-40 | |
| `describe() -> String` | 43 | Used by the combat log. |

### 4.5 `MoveData` fields an enemy uses (`move_data.gd`)

- Frames: `startup`, `active`, `recovery`, `cancel_start` (12-17).
- `damage` (20); `hitstun` (22, FLINCH only; STAGGER and KNOCKDOWN use Tuning); `knockback` (25); `reaction` (26); `tier` (27).
- `breaks_armor` (29): **declared for the Bruiser and read by nothing yet**. `haymaker` sets it (`tools/gen_moves.gd:152`).
- `hits_downed` (31), `max_targets` (33).
- Blocking: `unblockable` (37), `guard_damage_mult` (39), `blocked_recoil_frames` (42; Spec says 0 for Bruiser and boss moves, so no recoil on block).
- `hitboxes` (45).
- Movement: `magnetism` (49; player only, see §4.2), `lunge` and `free_lunge` (52-53).
- Camera fields (58-68) are first-person **player** presentation; ignored for enemies.
- `branches`, `repeat_*` and `auto_next` (71-78) are ComboParser data, which is the player's. **Enemy AI doesn't use ComboParser**: chain moves by calling `start_move()` yourself, from `_on_move_finished()` or during `can_cancel()` recovery.
- There is **no "range" field**. The rear warning's "attack range + 1 m" (Spec §8) and AI spacing need a range from somewhere: a new MoveData field (a contract change), a per-archetype export, or one computed from the hitboxes (point-sphere reach isn't static).

`MoveSet` (`move_set.gd:5-11`) and `ComboBranch` (`combo_branch.gd:6-11`) are player combo-tree data. M3 doesn't need them.

---

## 5. Taking hits: `receive_hit()` and every reaction path

### 5.1 `can_be_hit_by(attacker, move) -> bool` (CA:273-280)
- false if KO, invulnerable (`_invuln_frames > 0` or KO, CA:220-221) or flying (LAUNCHED or THROWN; no juggles).
- GRABBED: only the holder may hit it.
- `move.hits_downed`: only DOWNED victims; otherwise DOWNED victims are skipped.

### 5.2 `receive_hit(hit: HitInfo) -> bool` (CA:404-425)
1. Return false if KO or invulnerable.
2. `_try_block(hit)` (CA:793). If the guard stopped the hit, return **true** (blocked hits are "landed").
3. Damage: `god_mode` gives team 0 no damage; `one_hit_ko` makes team != 0 take at least its health. `health -= damage`; `hit.killed`; `health_changed`.
4. Contact flash (`_flash_at()`, CA:922), delayed past a finisher's impact frame (`impact_frame_ticks()`, CA:939).
5. **`_cancel_move()` if a move runs.** This is how any accepted hit knocks an actor out of its wind-up (`windup_ended(self, true)`). **This is the line armor must get in front of** (§11.2).
6. `_on_hit_received(hit)` hook (CA:584), then `_apply_reaction(hit)` (CA:949).
7. If killed: `CombatEvents.ko(self, hit)`.

### 5.3 `_apply_reaction(hit)` (CA:949-989)
- **Held victim hit by its holder** (knees), reaction not THROWN: it stays held and jolts in `&"held"` unless killed (CA:952-958). **Gotcha for enemy grabs: any non-THROWN hit from the holder, even KNOCKDOWN, keeps the victim held.** Killed: `holder = null` and fall through.
- Killed while DOWNED: KO now.
- Killed by NONE, FLINCH, STAGGER or GROUND: becomes KNOCKDOWN with KO push and lift (CA:962-964).
- `NONE`: if a move was running (`_running_move()` still true, since state hasn't changed), `_return_to_neutral()`. So **a NONE hit still knocks an attacker out of its move.**
- `FLINCH`: `sim_velocity` is the flat knockback; HITSTUN for `move.hitstun` (literal 12 without a move); a directional flinch anim by region (`_flinch_anim()`, CA:1257).
- `STAGGER`: flat knockback; STAGGER for `stagger_frames`; directional anim (`_directional_anim()`, CA:1272); partial ragdoll (`_ragdoll_stagger()`, CA:1160). If the knockback is at least `body_impact_min_speed` (3.0, TDa:95), it becomes a shoved body that staggers teammates (`_begin_flying(STAGGER)`).
- `KNOCKDOWN`, `LAUNCH`, `THROWN`: `_launch()` (CA:1002). Upward speed is at least `Tuning.min_launch_up` (2.5, TDa:141), **so every knockdown, launch, throw or slam lifts the body**. `_face_up = not from_behind`; ghost; state LAUNCHED (THROWN for THROWN); fall anim; a hold left from under the hips; full ragdoll (at once from a hold, into a wall, or from behind); `_begin_flying(KNOCKDOWN)` (it knocks down teammates it hits); `knocked_down(self, hit)`.
- `GROUND`: stays down 20 frames longer; ragdoll push.

### 5.4 Landing, get-up, KO, blink-off
- Flying and touching the floor after 2 frames with `vy <= 0`: `_land_from_flight()` (CA:1061). Health 0 means KO; otherwise DOWNED with a face-up or face-down anim and the ragdoll's DOWN phase.
- DOWNED for `downed_frames`: `_start_getup()` (CA:1073). It moves the origin under the ragdoll's hips if there is room (`_move_under_ragdoll()`, CA:1195; **the body teleports up to about 1 m** to where it is drawn lying, so nav agents must cope), GETUP for `getup_frames`, invulnerable for `getup_invuln_frames`, and `got_up(self)`.
- `_enter_ko()` (CA:1090): `holder = null`, ghost, KO anim, hurtboxes off, limp ragdoll.
- Blink-off for team != 0 (`_tick_ko_blink()`, CA:1106): lie `ko_linger_s` (1.5, TDa:475), blink `ko_blink_s` (1.0, TDa:476), then `_vanish()` (CA:1122): hidden, ragdoll stopped, hurtboxes off, layer and mask 0, velocity 0, `vanished(self)`. `is_gone()` (CA:226) becomes true and `_gone_frames` counts up. **The node is never freed by the base**, and `_tick_ko()` (CA:617) keeps being called every sim frame. M3 enemies should `queue_free()` once gone (from `_tick_ko()` when `is_gone()`), or a spawner should recycle them with `reset_state()` + `blink_in()` (the dummy's `_respawn()`, TD:506-514). Anything holding a reference (director tokens, a held weapon) must drop it first.
- `blink_in()` (CA:232) gives invulnerability for the blink-in; `is_blinking_in()` (CA:242). Magnetism skips such bodies (PC:706).
- The player: `_tick_ko()` with `auto_revive` gives `_revive()` after `player_revive_s` (PC:634-651). It revives in place through a get-up.

### 5.5 Invulnerability windows (all through `_invuln_frames`, CA:103; or the KO state)
- Get-up: `getup_invuln_frames` (CA:1078). That is the whole get-up by default, so **AI can't hit a getting-up player**.
- Dodge: the player only, `dodge_invuln_frames` (PC:893).
- Blink-in: CA:235.
- KO: always (CA:221).
- There is **no post-hit invulnerability**. With three token holders, a player can be flinch-locked; only the director's pacing prevents it.

### 5.6 What hits the player today (the sparring jab path, all tested)
`TD.start_jab()` (TD:249) calls `start_move(_jab_move(), 1, &"root", true)`, which gives WINDUP (24 frames, scaled by `windup_mult`), then ATTACK, then HD hits the player's hurtboxes and `PC.receive_hit` runs.

Everything below already works for any enemy that does the same:
- block, perfect block (the attacker staggers and is grabbable), guard break (the defender staggers), chip, blockstun and attacker recoil (`blocked_recoil_frames`);
- the player's flinch, stagger, knockdown, KO and auto-revive;
- the first-person camera's punch and shake on hits taken (`first_person_camera.gd:554-563`);
- rumble, hit audio, VFX bursts and the combat log;
- wind-up audio: the effort plus the whoosh, positional, cut on interrupt (`audio_director.gd:257-279`, gated by `Tuning.rear_warning_audio`);
- the enemy's strike pulled back after it lands on the first-person body (`_pull_strike`, CA:200, 636-640).

Tests: `tests/test_combat_integration.gd:663-1437` (sparring, parry, blockstun punish, grabbing out of a wind-up).

---

## 6. Subclass hooks (the extension points)

| Hook | Line | Called | Default | Notes for M3 |
| --- | --- | --- | --- | --- |
| `_configure_rig(r)` | CA:558 | before `rig.build()`, in `_ensure_body()` (CA:1478) | none | Colours, stance, `wrapped_hands`. Size comes from `body_height`. |
| `_tick_control()` | CA:563 | each sim frame, after timers and move advance (CA:654) | none | **The AI's brain.** It runs in every state (the dummy returns early unless FREE, TD:133). |
| `_on_move_finished(move)` | CA:568 | recovery over, `current_move` already null | `_return_to_neutral()` | Chain the next move here, or go back to posture. |
| `_on_move_frame(move, frame)` | CA:573 | every move frame after the index updates (CA:733) | none | Code-applied effects at a frame (the throw at `frame == startup`, PC:568-578; a grab check; an active-frames lunge). |
| `_on_move_hits(move, hits)` | CA:578 | the move landed hits this frame (blocked ones included: check `hit.blocked`) | none | |
| `_on_hit_received(hit)` | CA:584 | accepted unblocked hit, **after** `_cancel_move()`, before the reaction | none | Drop a held weapon, release a held victim, interrupt AI. |
| `_on_hit_blocked(hit)` | CA:590 | the guard stopped a hit | none | |
| `_on_move_interrupted()` | CA:595 | own move cut by the defender's guard (`react_to_block`) | none | |
| `_guard_facing()` | CA:600 | blocking | `get_forward()` | |
| `_plan_lunge(move)` | CA:605 | in `start_move()` | `free_lunge` straight | Enemy tracking goes here. |
| `_update_lunge()` | CA:611 | each move frame | none | |
| `_tick_ko()` | CA:617 | each sim frame while KO (after the blink tick) | none | Free or recycle here. |
| `_blinks_off_when_ko()` | CA:622 | | `team != 0` | |
| `_auto_land()` | CA:627 | AIRBORNE | true | |

Signals on the actor: `state_changed(old_state: int, new_state: int)` (CA:38).

GDScript has no `private`. `_cancel_move()`, `_enter_state()`, `_return_to_neutral()`, `_set_ghost()`, `_pin_spot()` and others can be called or overridden from a subclass, and TD already does (`_set_ghost` at TD:119 and :232). Two tests poke privates (`._enter_state` twice, `._guard_frames` once). Prefer adding small public wrappers in an enemy base over editing CA.

---

## 7. Blocking (could an enemy reuse it?)

Everything lives in CA and works for any actor. Every number is in Tuning's "Block" group (TDa:557-598) or MoveData.
- `start_block(can_parry := true)` (CA:341): cancels the current move, enters BLOCK, plays `&"block"`, emits `block_started`. It stops hits from `block_raise_frames`.
- `drop_guard(frames)` (CA:355): it stops blocking now and ends the block `frames` later (0 ends it at once).
- Queries: `is_guarding()` (CA:301), `is_guard_effective()` (CA:306), `is_dropping_guard()` (CA:315), `guard`, `max_guard()` (CA:320), `get_block_arc()` (CA:326, for F3).
- `_try_block()` (CA:793) handles perfect block, guard break and chip + drain + blockstun. Arc check: `_in_guard_arc()` (CA:872), from the attacker's position (from the flight direction for body impacts). `unblockable` moves pass. Blockstun pushes along the hit (CA:670-678).
- `react_to_block(hit)` (CA:373) is the **attacker's** side, called by HD. A perfect block makes the attacker STAGGER for `perfect_block_stagger_frames` (grabbable), **whatever the attacker is: no armor check, so a parried Bruiser or boss staggers too** (a design call). An ordinary block puts the attacker in HITSTUN for `move.blocked_recoil_frames` (0 = none) with `_recoiling = true`. A guard break does nothing to the attacker.
- **Game-boy's default: enemies don't block in M3.** If one ever does: `start_block(false)` (never parry the player), `drop_guard(n)` later from `_tick_control()`, and leave the facing as the body's. The block pose was tuned for the player's first-person lens and was never judged on an enemy.

Enemy hits on a blocking player: the drain is `guard_drain_per_damage (4) x damage x guard_damage_mult`. A 15-damage Bruiser smash drains 60 of 100, so two blocked smashes break the guard. Grabs and the ground pound need `unblockable = true` (see the test trap in §12).

---

## 8. Grabs today (the player holds an enemy)

### 8.1 Who owns what

**Holder side: entirely in `PlayerCharacter`.**
- LB (`_grab_action()`, PC:950) runs `_find_grab_target()` (PC:966): group `"enemy"`, `can_be_grabbed()`, within `grab_range` (1.3, TDa:43) and `grab_half_angle_deg` (60, TDa:44) of the facing.
- `_start_grab(victim)` (PC:983): `_held = victim`, `victim.start_grabbed(self)`, zero velocity, GRABBING, the `&"grab"` anim, the hold move set.
- `_control_holding()` (PC:517-537): validates (`_holding_valid()`, PC:1067: `_held.state == GRABBED and _held.holder == self`); `hold_max_frames` (180) timeout releases with stagger; slow walk; LB releases; P is `knee`, K is `throw` (ComboParser hold set); idle in `&"hold"`.
- Knees: hits through HD on the held victim (it is allowed because the attacker is the holder). `_on_move_hits()` (PC:581) counts them, and `max_knees` (3) releases with stagger.
- Throw: at `frame == move.startup` of `throw` (PC:568-573), `_throw_held()` (PC:1082) builds a code-applied hit with reaction THROWN along the stick, then `receive_hit`, hitstop on both, `thrown` and `hit_landed`.
- A hit on the holder tears the hold apart (`_on_hit_received()`, PC:603-608): hitstop on the held body, then a release with stagger.
- `_release_held(stagger)` (PC:1075) calls `held.release_from_grab(get_forward() * release_push, stagger)`.
- The hold view (first-person camera pitch and lens shift) is player and camera code (PC:996-1060).

**Victim side: in `CombatActor`, generic.**
- `can_be_grabbed()` (CA:260-269): not held, not invulnerable; FREE, WINDUP, HITSTUN, STAGGER, BLOCK or BLOCKSTUN; or ATTACK outside active frames. Not DODGE (also invulnerable), AIRBORNE, DOWNED, GETUP, flying, KO, GRABBING or GRABBED.
- `start_grabbed(by)` (CA:467-480): cancels the move (a wind-up emits `windup_ended(true)`), `holder = by`, zero velocity, records the ease-in offset, **ghost**, GRABBED, plays `&"held"` (bent over, authored for a victim pinned under the holder's HoldPoint, facing it: `humanoid_rig.gd:46-49`, `placeholder_poses.gd:290-294`), stops the ragdoll, emits `grabbed(by, self)`.
- Each physics tick while GRABBED, instead of `_integrate()`: `_pin_to_holder(dt)` (CA:1409). Position is `_pin_spot()` (CA:1401): the holder's `HoldPoint` (Chest + (0, 0.07, −0.55) on the holder's rig, `placeholder_body.gd:86`, `:105`) dropped to the holder's floor, eased in over `grab_pin_ease_s`. **Rotation faces the holder.** If the holder is invalid: `release_from_grab(0, false)`.
- `can_be_hit_by()`: only the holder can hit a GRABBED body (CA:276-277). Others can't.
- `_apply_reaction()`: holder hits other than THROWN keep it held (CA:952-958).
- `release_from_grab(push, stagger)` (CA:487-502): `holder = null`, solid, FREE or STAGGER with `push`, `_leave_hold_under_hips()` (CA:1432; **moves the origin by the hips' offset**, so the drawn body doesn't jump), stagger ragdoll, `released(by, self)`.
- `_launch()` from GRABBED (a throw, a killing knee) leaves under the hips too and starts the ragdoll at once (CA:1003-1022).
- **The victim has no timer and no input.** In GRABBED, `_tick_reaction_timers()` does nothing, and the dummy's `_tick_control()` returns early. The holder drives everything.

### 8.2 The held victim's state, in one line
`state == GRABBED`, `holder != null`, ghost layer, pinned and facing the holder every physics tick, hurtboxes on, hittable only by the holder, not grabbable, no timeout, playing `&"held"`.

---

## 9. CombatEvents (`game/autoload/combat_events.gd`)

Emitted only by the simulation. Presentation subscribes and never writes state.

| Signal (args) | Line | Emitted at | Current subscribers |
| --- | --- | --- | --- |
| `attack_started(attacker: Node3D, move: MoveData, chain_step: int, input_timing: StringName)` | 5 | `start_move()` (CA:451), **at wind-up start** | hud (combat log), vfx (player lunges only, `vfx_director.gd:369`) |
| `attack_whiffed(attacker, move)` | 6 | end of active frames with nothing landed (CA:713) | audio, hud |
| `hit_landed(hit: HitInfo)` | 7 | HD:83, PC:1109, CA:1397, weapon.gd:134 (blocked hits too) | audio, rumble, FP camera, hud, vfx |
| `windup_started(attacker, move)` | 8 | `start_move()` with WINDUP (CA:453) | audio (the rear-warning sound) |
| `windup_ended(attacker, interrupted: bool)` | 9 | false: the strike comes out (CA:706); true: cancelled in WINDUP (hit, grab, or any `_cancel_move()`, CA:739) | audio |
| `knocked_down(victim, hit)` | 10 | `_launch()` (CA:1028) | none |
| `got_up(actor)` | 11 | `_start_getup()` (CA:1087) | none |
| `ko(victim, hit)` | 12 | the killing blow in `receive_hit()` (CA:424), before the KO state | none |
| `vanished(actor)` | 15 | `_vanish()` (CA:1134) | hud (health bars) |
| `revived(actor)` | 17 | PC:650, TD:513 | none |
| `health_changed(actor, health, max_health)` | 18 | `_ready` (deferred), each hit, chip, reset, revive | hud, vfx (damage look) |
| `actor_state_changed(actor, old_state: int, new_state: int)` | 19 | `_enter_state()` (CA:775) | tests only |
| `grabbed(holder, victim)` | 20 | `start_grabbed()` (CA:480) | none |
| `released(holder, victim)` | 21 | `release_from_grab()` (CA:502) | none |
| `thrown(holder, victim)` | 22 | PC:1108 | none |
| `weapon_picked_up(actor, weapon)` | 23 | PC:1133 | none |
| `weapon_thrown(actor, weapon)` | 24 | PC:577 | none |
| `weapon_broke(actor, weapon)` | 25 | PC:593, weapon.gd:139 | tests |
| `dodged(actor, direction: Vector3)` | 26 | PC:900 | none |
| `jumped(actor)`, `landed(actor)`, `quick_turned(actor)` | 27-29 | player | none |
| `block_started(actor)`, `block_ended(actor)` | 30-31 | CA:350, CA:777 | tests |
| `blocked(defender, hit)` | 33 | `_try_block()` (CA:810, 845, 864) | tests |
| `perfect_blocked(defender, hit)` | 34 | CA:811 | hud (PARRY!) |
| `guard_broken(defender, hit)` | 35 | CA:846 | hud |
| `guard_changed(actor, guard, max_guard)` | 36 | `_set_guard()` (CA:907) | (the health panel reads it via the hud) |

For the rear warning (Spec §8): `windup_started` gives the attacker and the move, so the HUD reads the attacker's position, the player's look or camera, and the range. End it on `windup_ended(attacker, _)`. Either value works: false means the strike came out, which makes the warning time equal the wind-up length, as Spec §8 asks; true means it was interrupted. A KO'd or freed attacker always passes through `windup_ended(true)` first (`_cancel_move()` on the hit). A gone attacker can't wind up.

New M3 signals, if any (armor absorbed, grab escape progress, token changes), mean editing `combat_events.gd`: a contract file and a merge hot spot (§13). Prefer reading director or actor state from presentation, or add all new signals in one package.

---

## 10. TimeController (`game/autoload/time_controller.gd`)

- `hitstop(actors: Array, duration_s)` (:25): freezes from the next tick, for at least 1 tick, stretched by `1/debug_scale`. Overlaps extend.
- `slowmo(scale, duration_s, delay_s := 0)` (:45): global. A player finisher slows every enemy (0.3x for 250 ms) after its hitstop.
- `is_in_hitstop(actor)` (:55), `is_slowmo()` (:66), `sim_scale()` (:71; the global scale for non-actor sim objects), `scale_for(actor)` (:76; 0 in that actor's hitstop), `clear()` (:82), `debug_scale` (:10; F4's 0.25x).
- It runs after every actor (priority 1000, :90) and expires windows at the end of a tick.
- **For a director or spawner node** (not an actor), run timers on `delta * TimeController.sim_scale()`, so slow-mo and the debug 0.25x slow them like everything else. Only actors are frozen by hitstop; the director keeps running through a hit's hitstop.

---

## 11. M3 answers

### 11.1 What an AI controller needs to drive an actor (API surface)

Recommended shape: a new `EnemyActor extends CombatActor` base (a new file, e.g. `game/enemies/enemy_actor.gd`) that each archetype extends, holding the brain in `_tick_control()`. A separate controller node could do it, but it would have to inject actions into `_tick_control()` anyway (§3.3), so a base class is simpler. Leave `TrainingDummy` alone (tests depend on it). Copy its helpers rather than refactoring it.

**Read (already public):**
- `state`, `state_frame`, `current_move`, `move_frame`, `health`, `max_health`, `team`, `holder`, `guard`, `sim_velocity` (CA:62-81)
- `is_ko()`, `is_downed()`, `is_flying()`, `is_invulnerable()`, `is_gone()`, `is_blinking_in()` (CA:208-243)
- `can_be_grabbed()` (CA:260), `can_be_hit_by(attacker, move)` (CA:273; e.g. "is the player open to this move now?", as TD:270 does)
- `get_forward()` (CA:283), `get_chest_position()` (CA:296), `get_head_top_position()` (CA:292; presentation anchor), `is_guarding()` (CA:301)
- The target: `get_tree().get_first_node_in_group(&"player") as CombatActor` (TD:130). Player extras: `look_yaw` and `get_look_basis()` (PC:22, :183) for "outside the player's view". This is simulation-legal (it is the player's own look, not a camera), and it is what blind-spot priority should use.

**Act (from `_tick_control()` only):**
- Locomotion in FREE: set `sim_velocity.x/z` every tick (there is no friction in FREE, so zero it to stop). Face by writing `rotation.y` (yaw 0 faces −Z; turn at a rate like `TD._turn_toward()`, TD:518-522). Animate with `rig.play_locomotion(local_move: Vector2, speed_ratio)` (`humanoid_rig.gd:286`; local x is right and y is forward, **relative to the body's facing**, so strafing while facing the player uses x). Template: `TD._walk()` (TD:313-318).
- **Never call `move_and_slide()`**: `_integrate()` does it with time scaling (CA:1309-1310). With `NavigationAgent3D`: set `agent.velocity` to the desired sim-unit velocity in `_tick_control()`, and copy `velocity_computed`'s safe velocity into `sim_velocity` (it arrives after the navigation server's step, so it lags one tick; fine). Skip it during hitstop (no ticks run, no motion), and expect the agent's "stuck" heuristics to be confused by frozen ticks.
- Attack: zero the velocity, then `start_move(scaled_move, 1, &"root", true)` from FREE. Chain from `_on_move_finished()` or in `can_cancel()` recovery with `windup = false` for follow-ups if one telegraph per combo is wanted.
- Tracking: override `_plan_lunge()` and `_update_lunge()` (§4.2).
- Aborting your own move (the target left): there is no public API. Use `_cancel_move()` + `_return_to_neutral()`, or add a public `abort_move()` in the enemy base.
- Block (not used in M3): `start_block(false)` / `drop_guard(n)`.

**React:**
- Poll `state` each tick, or connect your own `state_changed`. Hit reactions interrupt posture, wind-up and attack automatically (`receive_hit()` cancels the move and changes state). The AI only needs to notice it is back in FREE and re-plan. Any token held for an interrupted attack must be released then. Watch `windup_ended(self, true)`, or the state leaving WINDUP or ATTACK.
- Use `_on_hit_received()` for "I was hit": drop a weapon, aggro, phase checks (the boss at 50%).

**Debug (F3):** override `debug_state_text()` (CA:531; call super, then append the AI state and "TOKEN"). `debug_draw.gd:337` already shows it above every actor in group `"actor"` (skipping gone ones, `debug_draw.gd:162`).

**Spawning:** instance the scene or `EnemyActor.new()`; set `max_health`, `team`, `body_height`, `display_name` and colours before it enters the tree (`_ready()` builds the rig: `_ensure_body()`, CA:1457). `rig.build()` runs on the main thread per spawn; with 6 enemies plus ragdolls, **check for a hitch when a wave spawns**. To recycle a body: `reset_state()` + position + `blink_in()` (TD's `set_post()` and `_respawn()` show the Jolt one-step ghost trick for teleports: TD:222-240).

### 11.2 Armor (Bruiser: "ignores light hits, staggers on heavy hits and the haymaker")

There is no armor code yet. Prepared but unused: `HitInfo.armor_absorbed` (`hit_info.gd:24`) and `MoveData.breaks_armor` (`move_data.gd:29`, set on `haymaker`).

**Where it hooks:** inside `receive_hit()` (CA:404-425), after damage and `killed` are computed (CA:409-418) and **before** `_cancel_move()` (CA:419-420). Anything later is too late: the cancel ends the wind-up, and even a NONE reaction returns a running move to neutral (CA:966-968). Suggested minimal core change, one virtual hook:

```gdscript
## Armor (Spec §7): may absorb `hit`'s reaction (sets hit.armor_absorbed, the damage still
## lands) or change it (hit.reaction / hit.knockback). Default: no armor.
func _apply_armor(_hit: HitInfo) -> void:
	pass
```

called at about CA:418 (after the flash). Then: `if hit.armor_absorbed and not hit.killed: emit health_changed, then return true`, skipping `_cancel_move()`, `_on_hit_received()` and `_apply_reaction()`. The Bruiser's override: LIGHT and not `breaks_armor` means absorbed, with `hit.reaction = NONE` and `knockback = ZERO`, so the combat log, VFX and audio see what happened. HEAVY or `breaks_armor` means `hit.reaction = STAGGER` (or keep KNOCKDOWN for FINISHER and `breaks_armor`; a design call; MoveData's doc says "Staggers/knocks down armored enemies regardless of tier"). A killing hit is never absorbed.

Also decide:
- Spec: "light hits interrupt grunt wind-ups but not Bruiser or boss wind-ups". If the boss's armor applies only while winding up, the hook checks `state == WINDUP`.
- Body impacts (`impact_body_knockdown` is HEAVY, CA:1371-1397) and thrown weapons (`weapon_throw` is HEAVY) both go through `receive_hit()`, so they get armor automatically.
- Throws: should a Bruiser be grabbable? Override `can_be_grabbed()` if not.
- A **perfect block** staggers any attacker (`react_to_block()`, CA:376-387, with no armor check). Decide whether a parried Bruiser or boss staggers (override `react_to_block()` in the base).
- HD still freezes an armored victim in hitstop (HD:72). That is fine: it reads as weight.

### 11.3 Where the enemy wind-up multiplier applies

- `Tuning.windup_mult` (0.25-3.0, default 1.0, TDa:549, group "Enemies") is read **only** by `TD._jab_move()` (TD:322-332). It scales a **duplicate** MoveData's `startup` (`max(1, round(startup * mult))`), cached by mult, and drops the copy on `Tuning.changed` for `""` or `"moves/dummy_jab/..."` (TD:89-91), because F1 edits the shared `.tres` instance.
- Why a duplicate: `startup` is read everywhere: phase helpers (`move_data.gd:94-107`), WINDUP to ATTACK (CA:703), the whiff frame (CA:708), `rig.play_move()`'s animation key and wind-up pose time (`humanoid_rig.gd:258`, `placeholder_anims.gd:329-332`), and the default lunge frames (CA:607). One startup value keeps them all consistent.
- **M3:** put this in one shared helper used by every archetype (e.g. a static cache keyed by `move.id` + mult, cleared on `Tuning.changed`), not copied into each class. Apply it at `start_move()` time in the enemy base.
- Decide whether it can scale below the Spec's floors (at least 18 frames for grunts, at least 30 for the Bruiser and boss); currently nothing clamps. Per-archetype multipliers would be new tunables in the "Enemies" group (see the subgroup test trap in §12). The rear-warning time is the scaled startup, automatically.
- Side effects: `hit.move` is the duplicate (compare ids); each distinct mult value builds and caches one more animation per move on each rig (harmless).

### 11.4 How enemies hit the player (what already works)

See §5.6: the whole path works today through `start_move(..., windup = true)` plus hitboxes. To add an archetype attack:
1. Add the MoveData to `tools/gen_moves.gd` (the template is `dummy_jab`, `tools/gen_moves.gd:236-245`: `magnetism = false`; `blocked_recoil_frames` 0 for the Bruiser and boss), and regenerate (`CLAUDE.md` "Move data").
2. Add a pose recipe (rig area) and the id to `PlaceholderAnims.MOVE_IDS`.
3. Start it from `_tick_control()`, scaled by the wind-up helper.

Damage numbers per Spec §7: Punk 6, Kicker 8, Pipe 10, Bruiser 15, boss 15-25. Points to note:
- **Friendly fire is off** (HD:168), so a boss ground pound (an ARC with `arc_half_angle_deg` 180, a low `arc_height`, `unblockable`) only hits the player.
- A sweep that knocks the player down puts the player in its non-KO knockdown, whose first-person view is the open "belly slab" question (HANDOFF 12:05). In a 6-enemy fight it will happen far more often.
- A player in the air is still hittable (only flying, meaning LAUNCHED or THROWN, is excluded).
- Hits from behind land in full (outside the guard arc); `from_behind` sets the fall direction.
- Three token holders can flinch-lock the player (§5.5).

### 11.5 What it takes for an ENEMY to grab the PLAYER

Game-boy's rule: a telegraphed wind-up (a dodge or a heavy hit gets out of it); once held, mashing P/K breaks free before the hit; unbroken, the hit lands.

**What can be reused as is:**
- `can_be_grabbed()` on the player already encodes "a dodge gets out": DODGE and invulnerability return false. It also excludes the air, a get-up and GRABBING (a player holding an enemy can't be grabbed). It *includes* BLOCK and BLOCKSTUN (grabs beat guards) and HITSTUN and STAGGER (a design call: a flinched player gets grabbed).
- "A heavy hit gets out" comes free from armor (§11.2): a heavy hit staggers the Bruiser, which cancels its grab move (`windup_ended(true)`). For the boss, its armor rule must let heavy hits through during the grab wind-up.
- `start_grabbed()`, `_pin_to_holder()` and `release_from_grab()` are generic. Only the holder can hit the held player, so other enemies can't gang up on a held player. `_set_ghost()` is team-aware. A KO while held clears `holder` (`_enter_ko()`, CA:1091; killing hit, CA:958).

**The grab move itself (recommended):** a MoveData with **no hitboxes** (so no `attack_whiffed`, no HD involvement), `unblockable = true`, startup = the wind-up (WINDUP, rear warning, audio). At `_on_move_frame(move, move.startup)` the enemy checks range and angle and `player.can_be_grabbed()` (the player's `_find_grab_target()` logic, PC:966-980, inverted), then calls `player.start_grabbed(self)` and enters GRABBING. On a miss, the move plays out as a whiff (emit `attack_whiffed` yourself if the audio and log should hear it). Doing it through a damage-0 hitbox instead would fire `hit_landed` (VFX burst, hit sound, camera punch) for a grab, and blockers would need `unblockable` anyway.

**Holder side for an enemy (new code, the enemy base):** the GRABBING state exists in the enum and in `_self_propelled()`, but nothing in CA drives it.
- Keep `_held`, a hold-frames counter and a validity check copied from `_holding_valid()` (PC:1067-1072). Re-check every tick: the player may break free, be KO'd, be `reset_state()`'d or revive, and none of these notify the holder.
- Hold for N frames (a tunable), then the hit.
- An enemy holder hit by the player is impossible while it holds (the player is GRABBED and can't attack), but a thrown weapon or flying body still can't reach it either (team rules). Decide what ends a hold besides the mash and the timer.
- Anims: `&"grab"` and `&"hold"` exist (the clinch, `placeholder_poses.gd:262-288`), authored for a bent-over victim; see the problems below.

**The hit at the end (the trap):** a code-applied hit from the holder with any reaction other than THROWN **keeps the victim held** (CA:952-958). So:
- **Headbutt** (Bruiser): either `release_from_grab(push, false)` first, then `receive_hit()` with STAGGER or KNOCKDOWN; or keep it held for a jolt and release afterwards.
- **Grab slam** (boss): reaction THROWN goes through `_launch()` from GRABBED (CA:1003-1022). Every launch lifts at least `min_launch_up` (2.5 m/s up, TDa:141), so a "slam into the floor" is a short high throw unless a new tunable or reaction is added.
- Use the `_throw_held()` template (PC:1082-1109) for the HitInfo, the hitstop and `thrown` + `hit_landed`.

**Player-specific problems (victim side; player, rig and camera areas):**
1. **The held pose and pin are authored for a third-person victim.** `&"held"` bends the body forward; `_pin_spot()` stands it under the holder's HoldPoint, about 0.55 m ahead of the holder's chest. The player's first-person camera rides its own EyePoint, so the lens would sit low against the holder's chest. A player-held pose (upright, held by the collar or shoulders) and a pin distance for a first-person victim are needed. Both `start_grabbed()` (the `&"held"` play at CA:477) and `_pin_spot()` (CA:1401) are overridable in `PlayerCharacter`, or make the anim and pin offset virtual in CA. The "knees" jolt at CA:956 also plays `&"held"`.
2. **Look vs body facing.** `_pin_to_holder()` writes `rotation.y` to face the holder, but the camera follows `look_yaw` (PC:183). GRABBED isn't in `_can_steer_body()` (PC:928-937), so body and view split. On grab, set `look_yaw` toward the holder and drop or limit look input while held (like the KO lock in `PC._process()`, PC:165).
3. **Input is discarded while held.** `PC._tick_control()`'s fallback arm calls `parser.clear_buffer()` every tick (PC:321-322). A `GRABBED:` arm must count P/K presses (`parser.consume(IN_PUNCH)` / `IN_KICK`, after `_feed_parser()`) toward a `Tuning` mash threshold. On success, the player breaks free. There is no API for that: `release_from_grab()` on itself works (it emits `released(holder, player)`), but the enemy only learns by polling. A small CA addition helps: `break_free(push)` on the victim, calling a holder hook (e.g. `_on_hold_broken(victim)`, so the Bruiser staggers) before `release_from_grab()`.
4. **Leaving the hold moves the origin under the hips** (`_leave_hold_under_hips()`, CA:1432-1437, from release and from `_launch()`). The first-person camera follows the origin rigidly, so a bent held pose would pop the lens on release. A player-held pose with the hips over the origin avoids it.
5. **Tick order.** The pin reads the holder's HoldPoint from the holder's latest `rig.advance()`. If the player processes before its holder (likely: spawned enemies come later in the tree), the pin lags one tick behind a walking holder, a visible jitter in first person. Fix it with `process_physics_priority`, or pin from the holder's side.
6. Presentation: a "MASH!" prompt (HUD) reads a public escape-progress getter on the player; a held view, if wanted, is camera work. Rumble and audio come from `hit_landed` of the final hit; `grabbed` and `released` have no subscribers yet.

---

## 12. Gotchas and traps (quick list)

- **Tests that will break when you add enemy moves** (`tests/test_move_data.gd`): `test_moves_folder_holds_only_table_moves` (:345) requires every `.tres` in `game/combat/moves/` to be in `TABLE`; `test_blocking_fields` (:365) asserts **every** move is blockable with `blocked_recoil_frames` 14 (dummy_jab 20). Unblockable grabs and Bruiser/boss recoil 0 must update it. `EXPECTED_*` tables (:120-194) list every move's branches.
- `Tuning._ensure_moves()` loads every MoveData in `res://game/combat/moves` for F1 editing (`tuning.gd:255-272`). Enemy moves placed there become tunable in F1, which is good, but they also enter `default.json` move overrides only if edited. Put them anywhere else and F1 won't see them.
- `tests/test_tuning_panel.gd:390` asserts the **"Enemies" group has no subgroups**. New per-archetype tunables in "Enemies" need flat names, or that test changes. Every new `TuningData` export needs `tools/gen_default_preset.gd` re-run (`test_tuning_panel.gd:454-469` checks `tuning/default.json`).
- `start_move()` from outside `_tick_control()` skips frame 0's lunge and hook (§3.3).
- `sim_velocity` persists in FREE, ATTACK and WINDUP; zero it (§4.1).
- A killing blow is LAUNCHED for a while before KO. Count deaths by `health <= 0` (§3.2).
- `MoveData.magnetism` does nothing for enemies (§4.2).
- One hit per victim per `start_move()` (HD:27, :172). Multi-hit means chained moves.
- `_cancel_move()` doesn't change state (CA:736).
- A NONE reaction on an attacking actor still ends its move (CA:966-968). Armor must bypass, not set NONE and continue (§11.2).
- Holder hits other than THROWN keep a held victim held (CA:952).
- Every knockdown, launch, throw or slam lifts at least `min_launch_up` (CA:1006).
- The base never frees KO'd actors; `_tick_ko()` runs forever (§5.4).
- Groups: add `"enemy"` yourself (§2).
- Bodies are solid to each other (mask 2|3) and become ghosts while down. Expect overlap pops at get-up in a crowd (§2). The get-up teleports the origin up to about 1 m (§5.4).
- `_pull_strike` (CA:636-640) snaps the enemy's arm to `idle` the sim frame after its strike's hitstop when it hit the player. Recovery frames then show idle (still ATTACK). Side view is debug-only, so this is fine.
- Literal numbers already in CA that aren't tunables (don't copy the pattern): FLINCH fallback 12 (CA:971), GROUND +20 frames (CA:985), `BLOCK_FLASH_AMOUNT` and `PARRY_FLASH_COLOR` (CA:45-46), and the 0.999 accumulator threshold (CA:168).
- `HitInfo.move` may be a duplicate; compare `move.id`.
- `attack_started` fires at wind-up start; the strike is `windup_ended(false)`.
- `Weapon.throw_from()` collides with ENEMY_BODY only (`weapon.gd:86`), so an enemy can't throw a pipe at the player without changes. There is no `drop()`: the Pipe Thug's knockdown drop needs a new public `Weapon.drop()` (reparent to the world, unfreeze, `_set_ground_physics()`). `Weapon.attach_to(actor)` (`weapon.gd:54`) works for any CombatActor's WeaponGrip. Durability is only decremented by the player (PC:587).

---

## 13. Conflict hot spots (files several M3 packages will want)

| File | Who will want it | Advice |
| --- | --- | --- |
| `game/actors/combat_actor.gd` | armor hook (Bruiser, boss); enemy-grab victim API (`break_free`, held anim and pin hooks); maybe a public `abort_move()`; maybe parry vs armor | **One owner.** Land the small core API additions (armor hook, grab hooks) first, as a "core hooks" package, then branch everything else from it. Keep archetype logic out of it. |
| `game/player/player.gd` | the GRABBED arm and mash; look lock while held; player-held pose and pin overrides; maybe auto-revive in the crowd room | One owner (the enemy-grab package). |
| `game/combat/move_data.gd`, `hit_info.gd`, `combat_types.gd` | a range field for AI and rear warning; armor-related fields; maybe a new Reaction | Contract files (ARCHITECTURE "Ownership"). Decide fields in the plan; one package adds them all. |
| `game/autoload/combat_events.gd` | any new signal (armor, grab escape, tokens) | Same: decide in the plan, one package adds them. |
| `tools/gen_moves.gd`, `game/combat/moves/*.tres`, `tests/test_move_data.gd` | every archetype's moves | **One "enemy moves" package** owns generator, `.tres` and tests; the archetype packages consume ids. Regenerating rewrites all `.tres`, so parallel edits conflict. |
| `game/actors/placeholder_poses.gd`, `placeholder_anims.gd` (`MOVE_IDS`) | pose recipes for every enemy move; player-held and enemy-hold poses | Rig area; one owner, or one package per recipe block with care. |
| `game/autoload/tuning_data.gd` + `tuning/default.json` | the "Enemies" and "Rear warning" groups, grab-escape tunables, director tunables | One owner, or append-only per group and the lead regenerates `default.json` after merging. Mind the no-subgroups test. |
| `game/enemies/dummy/training_dummy.gd` | an enemy base refactor | Avoid. Leave the dummy as is (M2 tests and bots depend on it). |
| `tests/test_combat_integration.gd` (59 tests) | everyone's integration tests | Each package writes **new** test files instead. |
| `game/weapons/weapon.gd` | Pipe Thug drop (`drop()`), maybe enemy swings | Owned by the Pipe Thug package. |
