# Architecture (Milestone 1 contracts)

This is the working contract between modules. [SPEC.md](SPEC.md) §3 decides the shape. This file pins down names, units and interfaces so modules can be built in parallel.

## Layers

```
Simulation (camera-agnostic, 60 Hz, frame-based)
  CombatActor (CharacterBody3D) ─┬─ PlayerCharacter   game/player/
                                 ├─ TrainingDummy     game/enemies/dummy/
                                 └─ (enemy archetypes, Milestone 3)
  HumanoidRig      skeleton, meshes, hurtboxes, rig points, procedural anims   game/actors/
  ComboParser      cadence rules → move choice (pure logic)                    game/combat/
  HitDetector      hitbox queries → HitInfo → victim.receive_hit()             game/combat/
  MoveData / MoveSet / ComboBranch / HitboxSpec  (.tres data)                  game/combat/

        │ emits                                       ▲ only time flows back
        ▼                                             │
CombatEvents (autoload signal bus)            TimeController (autoload: hitstop, slow-mo)
        │
        ▼ subscribe / read poses (never write state)
Presentation: CameraDirector + FP / side / free-fly cameras (game/camera/), HUD, combat log,
debug draw (game/ui/), VFX and audio (Milestone 2)
```

Rules:
- No simulation code reads a camera. Aim comes from the player's own `look_yaw` and `look_pitch`.
- Presentation never writes game state. The only exception is time, via `TimeController`.
- No attack numbers in scripts. They live in `MoveData` `.tres` files. Global tunables live in `TuningData` (`Tuning.data.*`).

## Time model

- Physics runs at 60 Hz and `Engine.time_scale` stays 1.
- Each `CombatActor._physics_process` asks `TimeController.scale_for(self)`. The answer is 0 during that actor's hitstop, 0.3 during slow-mo, and is also multiplied by the debug scale. The actor adds the scale to an accumulator and runs one `sim_tick()` per whole unit. Frame counters therefore advance in whole sim frames, and the actor's frames stop while it is frozen.
- Motion (`move_and_slide`) and animation (`rig.advance(dt)`) use the scaled delta every physics tick, so slow-mo looks smooth.
- `ComboParser` buffers age in sim frames, so a press made during hitstop is still usable afterward.
- `TimeController.hitstop(actors, seconds)` freezes from the next physics tick, for `round(seconds × 60)` ticks.

## Coordinates and units

- Meters, seconds and frames (at 60 Hz). Godot axes: +Y up, and characters face **−Z**.
- `MoveData.knockback` is in the hit's frame. z runs along the horizontal direction from the attacker to the victim, so a positive z pushes the victim away, including for hits behind the attacker. x is that direction's right, and y is up.
- The test room's street axis is world **X**. The side-view camera looks along −Z from +Z.

## Physics and visual layers (`CombatTypes`)

| # | Physics layer | Used by |
| --- | --- | --- |
| 1 | world | static geometry |
| 2 | player_body | player CharacterBody3D |
| 3 | enemy_body | enemy/dummy CharacterBody3D |
| 4 | hurtbox | `Hurtbox` areas (monitorable only) |
| 5 | pickup | weapons on the ground |
| 6 | downed_body | bodies lying down (collide with world only) |
| 7 | projectile | thrown weapons |

Visual layer 2 (`fp_hidden`) holds the player's head, neck, chest, upper chest, shoulders and upper arms (`PlaceholderBody.FP_HIDDEN_BONES`). The first-person camera's cull mask excludes it, and those meshes still cast shadows. Visual layer 3 holds debug geometry.

## Humanoid rig

**Bones** (Godot `SkeletonProfileHumanoid` names, so real skeletons can map onto them later):
`Root, Hips, Spine, Chest, UpperChest, Neck, Head, LeftShoulder, LeftUpperArm, LeftLowerArm, LeftHand, RightShoulder, RightUpperArm, RightLowerArm, RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, LeftToes, RightUpperLeg, RightLowerLeg, RightFoot, RightToes`.
The rig origin is at the feet, the character faces −Z, and the default height is 1.8 m.

**Rig points** (markers that follow bones; `get_point_transform()` accepts these or bone names):

| Point | Where |
| --- | --- |
| `EyePoint` | between the eyes, about 1.68 m in the boxer guard (1.61 m in the player's relaxed stance); the first-person lens rides 0.2 m below it (see "First-person lens") |
| `HeadTopPoint` | about 0.25 m above the top of the head; anchor for over-head UI |
| `ChestPoint` | center of the chest; aim and magnetism target |
| `LeftFistPoint`, `RightFistPoint` | center of each fist |
| `LeftElbowPoint`, `RightElbowPoint` | tip of each elbow |
| `LeftKneePoint`, `RightKneePoint` | front of each knee |
| `LeftFootPoint`, `RightFootPoint` | ball of each foot (the kick contact point) |
| `WeaponGrip` | in the right hand, where a held weapon's handle sits |
| `WeaponTip` | 0.7 m along the held weapon from the grip |
| `HoldPoint` | about 0.55 m in front of the chest at chest height; a grabbed victim is pinned here |

**Hurtboxes:** HEAD is a sphere on Head. TORSO is a capsule from Spine to UpperChest. LEGS is a capsule on each leg. A region can have more than one hurtbox.

**Stance** (`HumanoidRig.stance`, set before `build()`): the pose a body stands and walks in, starts every move from and returns to.
- `&"boxer"` (default): fists up by the chin. Enemies and training dummies keep it; a raised guard reads as a threat from the player's view.
- `&"relaxed"`: the player's (`PlayerCharacter._configure_rig()`). A loose "Bruce Lee" stance: upright and light, the lead foot forward and the rear heel up, the lead hand hanging a little forward at belt height and the rear hand by the hip. Looking ahead in first person, nothing of the arms shows. Idle, the walks (with a small arm swing), the dodges, landing, hit reactions, get-ups, the grab and the haymaker charge start or end in it.
- Strike poses are authored on the boxer guard's body and legs and reach the same envelopes in both stances (the "Strike reach" table below). In the relaxed stance a move starts and ends in the stance, an arm a key pose leaves alone stays loose, and the arm a punch does not throw stays low by the solar plexus instead of guarding the chin (`PlaceholderPoses._FREE_ARM`). The haymaker's wind-up keeps its lead hand reaching out on the left, since it is the charge pose. Clinch moves (knee, throw) run in the hold, pipe moves in a relaxed weapon carry (the pipe held low, angled down), and air moves in the air guard.
- The neutral dodge covers up: `dodge_back` (no stick) and `dodge_forward` (forward-only stick) put the boxer guard's arms up by the face from frame 3 to frame 13 of the 14-frame dodge, in either stance. In the relaxed stance that is the only time the "dukes up" image fills the first-person view. Side dodges slip with the stance's arms.

**Hands** (`HumanoidRig.wrapped_hands`, the player only, Spec §10): skin-colored fists with light wraps across the knuckles and at the wrist and a dark fingerless-glove plate on the back of the hand, on a slimmer forearm. About 0.9 times the enemies' fist block in each direction (about 75% of its volume). Enemies keep the slightly oversized fist blocks. Fist points, `WeaponGrip` and `WeaponTip` stay where they were, and hitbox radii are move data and do not change.

**Animation ids** the rig must provide (all procedural placeholders in Milestone 1):
- Locomotion: `idle`, `walk_forward`, `walk_back`, `walk_left`, `walk_right`
- Air: `jump`, `fall`, `land`
- Dodge: `dodge_left`, `dodge_right`, `dodge_back`, `dodge_forward`
- Grab: `grab`, `hold` (holding someone), `held` (being held), `thrown`, `pickup`, `haymaker_charge`
- Hit reacts: `flinch_head_front`, `flinch_head_left`, `flinch_head_right`, `flinch_gut`, `flinch_legs`, `stagger_back`, `stagger_left`, `stagger_right`, `stagger_forward`
- Down: `launched`, `knockdown_back`, `knockdown_forward`, `downed_back`, `downed_front`, `getup_back`, `getup_front`, `ko_back`, `ko_front`
- Every move id below, through `play_move()`, timed to its frame data

**Playback notes:**
- **Cross-fades are done by the rig, not by `AnimationPlayer`.** Godot keeps every earlier blend running with its own blend time, so a strike that started during a locomotion switch or a dodge would still carry the old pose into its active frames. Instead, starting an animation snapshots the pose on screen (local bone rotations and the Hips position) and plays the new animation at full weight. `advance()` then slerps from the snapshot to the animation's pose over the blend time. `play_move()` caps that time at 75% of the startup, so the strike pose is always reached unblended.
- `haymaker_charge` ends on the haymaker's wind-up pose. The player plays it while P has been held for at least `hold_frames` (when releasing P would start the haymaker). `play_move(haymaker)` started from it uses a variant that begins at the cocked pose, so the release drives straight into the swing. In first person the cocked right fist is out of view (behind the lens), and the lead hand reaches out on the left, so the view center (the aim dot and the target's head) stays clear for as long as P is held.
- A body that is already down or flying does not stand back up first. `ko_*` from a lying animation skips to the end of the slump. `ko_*` and `knockdown_*` from `launched` or `thrown` skip the standing buckle and join the fall at the point where the head is no higher than it is now. A fade out of `launched` or `thrown` that would swing the body up through upright (landing face down after a face-up launch) rolls it over a side instead. The roll turns the spine about the vertical while its tilt moves straight from the start to the end pose, so the head neither rises nor drops below the pose it lands in and bounces back.
- **Skeleton modifiers are bypassed (known limitation).** `advance()` computes the FK itself from the skeleton's local (animation) poses and drives the bone followers (meshes, attachments), rig points and hurtboxes from that result. A `SkeletonModifier3D`, such as the `PhysicalBoneSimulator3D` partial ragdoll for the Spec §6 hit-feel stack, would change only `Skeleton3D`'s own global poses and never reach the meshes. Intended Milestone 2 path: after `skeleton.advance()` has run the modifiers, the visual followers read the post-modifier global poses (`get_bone_global_pose()`). Hurtboxes, rig points and `get_point_transform()` keep the pure-animation FK, so hit detection stays deterministic and independent of the ragdoll.

## Moves (Spec §4) and their data

Ids are the `.tres` names in `game/combat/moves/`. Each move's animation id equals its move id. Frame data are starting values; damage values come from the spec and are fixed. Strike reach is where the strike point should be at the strike pose, in the attacker's local frame (−Z forward, y above the feet). With targets standing about 0.85 m away, these values connect.

| Move id | Chain | Startup/Active/Recovery | Dmg | Tier | Reaction | Knockback (x,y,z) | Hitbox | Strike reach |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `jab_1` | P | 4/3/10 | 6 | LIGHT | FLINCH | 0,0,1.5 | LeftFistPoint r0.12 | z ≤ −0.65, y 1.35–1.65 |
| `jab_2` | P P | 4/3/10 | 6 | LIGHT | FLINCH | 0,0,1.5 | RightFistPoint r0.12 | z ≤ −0.65, y 1.35–1.65 |
| `hook` | P P P | 6/3/14 | 8 | HEAVY | STAGGER | −2.2,0,0.6 (snaps the head sideways) | LeftFistPoint r0.14 | z ≤ −0.5, y 1.35–1.65 |
| `uppercut` | P P P P | 8/3/22 | 12 | FINISHER | LAUNCH | 0,6,3 | RightFistPoint r0.14 | z ≤ −0.45, y 1.4–1.8 |
| `body_flurry` | P P · P, repeat P up to 6 | 2/2/6 | 2 | LIGHT | FLINCH (hitstun 10) | 0,0,0.3 | both FistPoints r0.12 | z ≤ −0.55, y 1.0–1.3 |
| `shove` | flurry's auto_next | 6/3/18 | 6 | FINISHER | STAGGER (shoves into others) | 0,0,7 | both FistPoints r0.16 | z ≤ −0.55, y 1.1–1.45 |
| `front_kick` | K | 7/3/14 | 8 | LIGHT | FLINCH | 0,0,2 | RightFootPoint r0.15 | z ≤ −0.75, y 0.8–1.2 |
| `roundhouse` | K K | 9/3/16 | 10 | HEAVY | STAGGER | 2,0,1 | RightFootPoint r0.16 | z ≤ −0.6, y 1.1–1.6 |
| `spinning_heel` | K K K | 12/5/24 | 14 | FINISHER | KNOCKDOWN | 0,3,6 | ARC r1.9, ±75°, y 0.3–1.8 | (spin) |
| `stomp_kick` | K · K | 10/3/22 | 16 | FINISHER | LAUNCH | 0,2,10 | RightFootPoint r0.16 | z ≤ −0.75, y 0.7–1.1 |
| `push_kick` | P P K | 8/3/20 | 10 | FINISHER | KNOCKDOWN | 0,1.5,9 | RightFootPoint r0.16 | z ≤ −0.75, y 0.8–1.2 |
| `haymaker` | hold P 24f, release | 14/3/26 | 18 | FINISHER | LAUNCH, breaks armor | 0,4,8 | RightFistPoint r0.16 | z ≤ −0.65, y 1.35–1.65 |
| `flying_kick` | air K | 5/8/14 | 12 | HEAVY | KNOCKDOWN | 0,2,5 | RightFootPoint r0.24; lunge 2.0 | z ≤ −0.7, y 0.35–0.75 (airborne: aims forward and down) |
| `spin_kick` | air K at apex | 6/10/16 | 10 | HEAVY | KNOCKDOWN | 0,2,4 | ARC r1.8, ±180°, y −0.6–1.8 (reaches below the airborne attacker) | (spin) |
| `back_elbow` | RB | 5/3/18 | 12 | HEAVY | KNOCKDOWN | 0,2,4 | ARC r1.4, center 180°, ±50°, y 0.6–1.8 | elbow z ≥ +0.3 |
| `knee` | P while holding | 5/3/12 | 6 | LIGHT | FLINCH | 0,0,0 | RightKneePoint r0.18, no magnetism | z ≤ −0.35, y 0.9–1.25 |
| `throw` | K while holding | 8/2/20 | 15 | HEAVY | THROWN | 0,3,9 (stick dir) | none (applied to held victim) | — |
| `stomp` | K near a downed enemy | 8/3/14 | 8 | LIGHT | GROUND, hits downed only | 0,0,0 | RightFootPoint r0.22 | z ≤ −0.5, y 0.0–0.3 |
| `pipe_swing_1` | P with weapon | 7/3/12 | 10 | LIGHT | FLINCH | 0,0,2 | WeaponTip r0.18 | z ≤ −0.7, y 1.0–1.7 |
| `pipe_swing_2` | P P with weapon | 7/3/12 | 10 | HEAVY | STAGGER | 1,0,2 | WeaponTip r0.18 | z ≤ −0.7, y 1.0–1.7 |
| `pipe_swing_3` | P P P with weapon | 9/4/20 | 10 | FINISHER | KNOCKDOWN | 0,2,6 | WeaponTip r0.2 | z ≤ −0.7, y 1.0–1.7 |
| `weapon_throw` | LB with weapon | 6/1/14 | 15 | HEAVY | KNOCKDOWN | 0,2,6 | none (spawns projectile) | — |
| `impact_body_knockdown` | flying body hits someone | 0/1/0 | 5 | HEAVY | KNOCKDOWN | 0,2,3 | none | — |
| `impact_body_stagger` | shoved body hits someone | 0/1/0 | 0 | LIGHT | STAGGER | 0,0,2 | none | — |

Kicks use the camera offsets `camera_pitch_deg = −10` and `camera_drop_m = 0.05`. The flying kick (it dives at the target) and the stomp use −25, with the same 0.05 drop.

**Move sets** (`game/combat/movesets/`):
- `ground.tres`
  - Roots: `K [require downed_target_near] → stomp`, `K → front_kick`, `P → jab_1`, `P_HOLD → haymaker`, `RB → back_elbow`
  - Interrupt: `RB → back_elbow`
- `air.tres`
  - Roots: `K [require at_apex] → spin_kick`, `K → flying_kick`
- `hold.tres`
  - Roots: `P → knee`, `K → throw`
- `weapon.tres`
  - Roots: `P → pipe_swing_1`, `K [downed_target_near] → stomp`, `K → front_kick`, `RB → back_elbow`
  - Interrupt: `RB → back_elbow`

**Branches:**
- `jab_1`: `P → jab_2`
- `jab_2`: `P → hook`, `K → push_kick`, `P (PAUSE) → body_flurry`
- `hook`: `P → uppercut`
- `body_flurry`: `repeat_input P`, `repeat_max 6`, `auto_next shove`
- `front_kick`: `K → roundhouse`, `K (PAUSE) → stomp_kick`
- `roundhouse`: `K → spinning_heel`
- `pipe_swing_1`: `P → pipe_swing_2`
- `pipe_swing_2`: `P → pipe_swing_3`

The knee count, releasing the victim on the third knee, the throw direction, dodging, jumping, grabbing and weapon handling are player-controller logic. They are not branches.

## Interfaces between modules

**`CombatActor`** (`game/actors/combat_actor.gd`). The player and dummies extend it. It is in group `"actor"`, plus `"player"` or `"enemy"`.
- `health: float`, `max_health: float`, `team: int` (0 = player, 1 = enemies), `state: CombatTypes.ActorState`, `display_name: String`
- `rig: HumanoidRig`
- `current_move: MoveData`, `move_frame: int`
- `is_ko() -> bool`, `is_downed() -> bool`, `is_invulnerable() -> bool`
- `get_head_top_position() -> Vector3`, `get_chest_position() -> Vector3`
- `receive_hit(hit: HitInfo) -> bool`
- `debug_state_text() -> String`
- `debug_hitbox_volumes: Array[Dictionary]` holds this sim frame's active hitboxes:
  - `{kind = &"sphere", center: Vector3, radius: float}`, or
  - `{kind = &"arc", origin: Vector3, forward: Vector3, radius: float, half_angle_deg: float, h_min: float, h_max: float}`

**`PlayerCharacter`** (`game/player/player.gd`, group `"player"`) adds what the cameras and HUD read:
- `look_yaw: float`, `look_pitch: float` (radians). Yaw 0 faces −Z, and positive pitch looks up.
- `get_eye_transform() -> Transform3D`: the world transform of `EyePoint`.
- `get_look_basis() -> Basis`: `Basis.from_euler(Vector3(look_pitch, look_yaw, 0))`.
- `get_camera_move_offset() -> Vector2`: x is the extra pitch in degrees (negative is down), y is the camera drop in meters. Both are already eased.
- `is_walking() -> bool`: on the ground and moving under the player's own control.
- `standing_eye_height: float`: the eye height above the player's origin in the idle pose.
- `get_magnetism_cone() -> Dictionary`: `{origin, forward, half_angle_deg, range, target}` for debug draw.
- `holding_weapon() -> bool`, `weapon_durability_left() -> int`

**`CameraDirector`** (`game/camera/camera_director.gd`, group `"camera_director"`):
- `signal camera_changed(mode: StringName)`
- `mode: StringName`: one of `&"first_person"`, `&"side_view"` or `&"free_fly"`
- `cycle()`: bound to `camera_cycle` (F2)
- `active_camera() -> Camera3D`

**ComboParser usage** (decisions settled during the build):
- Interrupt branches, such as RB into the back elbow from a recovery, continue the chain: timing `&"chain"` and `chain_step + 1`. Only root branches give `&"root"` with step 1.
- `ComboBranch.timing` only matters on a move's own branches. Root and interrupt branches ignore it.
- The owner calls `reset_chain()` whenever a move is cut short (hit, dodge cancel, grab, KO) and whenever the context changes (jump, landing, grab or release, picking up or losing a weapon).
- `HitInfo.input_timing` is one of `root`, `chain`, `pause`, `repeat` or `auto` from the parser. Code-applied hits add `body` (flying or shoved bodies) and `thrown` (thrown weapons).

**First-person camera smoothing:** the camera follows the player's origin rigidly and damps only the eye's offset from that origin (about 0.05 s). Damping the whole world position would make the camera trail the body by speed × 0.05 s.

**First-person lens** (Game-boy's call after the M1 playtest): the camera sits at `EyePoint + FirstPersonCamera.lens_offset(look_basis)`, 0.2 m below the eye at throat height (`Tuning.cam_height_offset_m`) and 0.04 m ahead along the flat look (`cam_forward_offset_m`), so punches come up into the view and kicks and the lead foot show below it, Mirror's Edge style. It is presentation only: aim, magnetism and hit detection never use it. The rig tests judge every first-person view from this lens (`tests/test_humanoid_rig.gd`, `_fp_camera()` and the ray-cast `_fp_hits()`): looking ahead at rest or walking the arms stay out of view; a punch's forearm and fist come in from below or the side and the body covers at most a third of the view; kicks show the foot and lower leg; looking down 45 degrees shows the lead hand and the toe of the lead foot, and 55 degrees the lead leg too, with no torso in the way. The forward offset stays small because the relaxed arms no longer need clearing at the chin, and it keeps the lead foot inside the view when looking down; at 0.02 m or less the belly sits under the lens and comes up over the legs.

**Input:** actions are registered by the `GameInput` autoload (`game/autoload/game_input.gd`). Mouse look comes from `GameInput.consume_mouse_delta()`. The free-fly camera uses `consume_fly_mouse_delta()` and the `fly_*` actions, so the player keeps WASD and the mouse.

## Ownership (Milestone 1 build)

| Area | Files |
| --- | --- |
| Contracts (change only by agreement) | `game/autoload/*`, `game/combat/{combat_types,move_data,move_set,combo_branch,hitbox_spec,hit_info,hurtbox}.gd`, this doc |
| Combo parser | `game/combat/combo_parser.gd`, `tests/test_combo_parser.gd` |
| Move data | `game/combat/moves/*.tres`, `game/combat/movesets/*.tres`, `tests/test_move_data.gd`, `tools/gen_moves.gd` (optional) |
| Rig and placeholder animation | `game/actors/humanoid_rig.gd`, `game/actors/placeholder_*.gd`, `tests/test_humanoid_rig.gd` |
| Cameras | `game/camera/*`, `tests/test_cameras.gd` |
| HUD and debug UI | `game/ui/*`, `tests/test_ui.gd` |
| Actor core, player, dummies, hit detection, test room | `game/actors/combat_actor.gd`, `game/combat/hit_detector.gd`, `game/player/*`, `game/enemies/*`, `game/level/*`, `game/weapons/*`, integration tests |
