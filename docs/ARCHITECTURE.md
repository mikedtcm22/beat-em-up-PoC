# Architecture (module contracts, Milestones 1 and 2)

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
- `TimeController.hitstop(actors, seconds)` freezes from the next physics tick, for `round(seconds × 60 / debug_scale)` ticks.
- The ragdoll (Milestone 2, see "Ragdoll" under "Humanoid rig") runs in each actor's sim time the same way: frozen in its hitstop, slowed by slow-mo and the debug scale.
- The debug scale (F4's 0.25×) slows everything the simulation times, hitstop and slow-mo included: hitstop lasts `1 / debug_scale` times as many ticks, and the slow-mo delay and length count `delta × debug_scale`. A slowed-down hit therefore keeps its feel, only slower. Presentation timers (camera punch and shake, audio, rumble) still run in real time.

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
| 8 | ragdoll | ragdoll bodies (`Ragdoll`, Milestone 2): collide with the world and, with `Tuning.ragdoll_collide_ragdolls`, other ragdolls; no actor body, hurtbox or hit query sees them |

Visual layer 2 (`fp_hidden`) holds the player's head, neck, chest and upper chest (`PlaceholderBody.FP_HIDDEN_BONES`), plus the shoulder balls and the shoulder end of each upper arm (`FP_HIDDEN_PARTS`; the elbow end, forearm and hand stay visible). The first-person camera's cull mask excludes it, and those meshes still cast shadows. Visual layer 3 holds debug geometry.

## Humanoid rig

**Bones** (Godot `SkeletonProfileHumanoid` names, so real skeletons can map onto them later):
`Root, Hips, Spine, Chest, UpperChest, Neck, Head, LeftShoulder, LeftUpperArm, LeftLowerArm, LeftHand, RightShoulder, RightUpperArm, RightLowerArm, RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, LeftToes, RightUpperLeg, RightLowerLeg, RightFoot, RightToes`.
The rig origin is at the feet, the character faces −Z, and the default height is 1.8 m.

**Rig points** (markers that follow bones; `get_point_transform()` accepts these or bone names):

| Point | Where |
| --- | --- |
| `EyePoint` | between the eyes, about 1.66 m in either stance; the first-person lens rides 0.2 m below it (see "First-person lens") |
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
- `&"boxer"` (default): fists up at the chin. Enemies and training dummies keep it; a raised guard reads as a threat from the player's view, "fists up, ready to fight" from 2-10 m and side on. The gloves sit at chin height a hand's width (about 0.26 m) in front of the body, either side of the face, the forearms angled in from elbows held low and a little wide, clear of the chest. Pulled in toward the body (the gloves moved about 13 cm closer, the elbows lower and wider; the fists dropped only about 2 cm) after Game-boy's first-person playtest, where the sparring dummy's guard held two oversized fist blocks at the throat-height lens's eye line and covered most of the view: from the player's lens an enemy in its idle guard 0.9 m in front of it covers at most about 12% of the view with its hands and forearms (the old guard 16%, hiding part of the head), at the sparring step-in (0.9 m between the bodies, about 0.72 m from the lens) its gloves alone cover at most 8% (20%), and its head shows whole above and between the gloves. Closer in, the forearms in front of the chest still cover about a sixth of the view at the step-in: smaller would sink them into the chest or drop the gloves below the chin.
- `&"relaxed"`: the player's (`PlayerCharacter._configure_rig()`). A loose "Bruce Lee" stance: the boxer guard's body, footing and head (the torso a little forward, the lead foot forward) on knees a little softer, the rear heel up so the weight sits on the balls of the feet; the lead hand hangs a little forward at belt height and the rear hand by the hip. The two stances differ in the arms, so a strike (authored on the guard's body) moves the eye, and the first-person camera riding it, no more from one than from the other. Looking ahead in first person, nothing of the arms shows. Idle, the walks (with a small arm swing), the dodges, landing, hit reactions, get-ups, the grab and the haymaker charge start or end in it.
- Strike poses are authored on the boxer guard's body and legs and reach the same envelopes in both stances (the "Strike reach" table below). In the relaxed stance a move starts and ends in the stance, an arm a key pose leaves alone stays loose, and the arm a punch does not throw stays low by the solar plexus instead of guarding the chin (`PlaceholderPoses._FREE_ARM`). The haymaker's wind-up keeps its lead hand reaching out on the left, since it is the charge pose. Clinch moves (knee, throw) start in the hold, bent at the waist (see "First-person hold view"; the knee ends there, the throw, with nothing left to hold, in the stance), pipe moves run in a relaxed weapon carry (the pipe held low, angled down), and air moves in the air guard.

**Block guard** (`PlaceholderPoses.block_guard()`, animation `block`): the "dukes up" guard, both fists raised in front of the face over the stance's legs and torso, held. Its arms (`block_guard_arms()`) are authored for the throat-height lens: from first person both fists sit whole in the upper third of the view, about 34 degrees either side of the center and 0.36 m ahead of the lens, the forearms rise to them from elbows held low and wide outside the lower corners, no forearm or hand comes within 0.3 m of the lens, the arms fill about a quarter of the view, and the center stays clear, framing whoever stands ahead. It is the pose of the held block (B with no stick, see "Block" below), and in the relaxed stance the only "dukes up" image: every dodge, the backstep (B + back) and the forward step included, keeps the stance's arms.

**Block reactions** (both stances; the first-person rules above hold through them):
- `block_hit` (blockstun, authored for the light 10 frames and played at the speed that fits the stun): the hips driven back and the torso rocked back over a deeper rear knee, the chin tucked, the guard jammed in. From the lens both fists jolt toward the center and the forearms stay 0.3 m or more away; side on, the torso rocks back behind the fists. Ends back in the guard.
- `guard_break` (the 45-frame stagger of a guard break): the guard forced open, then the arms flung up and out to the sides while the head snaps back and the rear foot steps back, a reel with the arms low and wide, and back to the stance. From the lens the fists swing out of the upper corners over a few frames.
- `recoil` (the attacker of a blocked hit, `MoveData.blocked_recoil_frames`, 14 by default): the striking right arm knocked back and out to beside the shoulder, the torso twisted away and the head jerked back; the other arm keeps the stance's, turned back against the twist, so a boxer's lead glove holds its side of the chin and the face stays in the defender's view through the punish window. The attacker snaps into it (and a parried attacker into its stagger) on the frame of the block, so the strike is never seen at full reach inside the guard: from the defender's lens the fist meets the guard and is knocked back.
- A strike that lands on the first-person player (`HumanoidRig.first_person_body`) without being knocked back (a clean hit, a guard break, a blocked move with no recoil) holds its contact pose through the hitstop and then snaps back into the stance (`idle`) for the rest of the move: the fist that reached the face never retracts through the throat-height lens, where it filled the upper view for about five frames.

**Hands** (Spec §10: slightly oversized, one size on everyone): about 0.9 times the old fist block (0.12 x 0.13 x 0.135 m) in each direction, about 73% of its volume and still at least 0.1 m across. The forearm (0.112 m across) is slimmer than the fist's length and depth but not its width, so from the front the glove reads as a dark cuff with a skin knuckle band; known, revisit with real art in Milestone 4.
- The player's (`HumanoidRig.wrapped_hands`): skin-colored fists with light wraps across the knuckles and at the wrist, a light wrap on the forearm at the wrist, and a dark fingerless-glove plate on the back of the hand.
- Enemies' (`PlaceholderBody._gloved_hand()`): dark fingerless gloves, the bare fingers showing across the knuckle end and a strap in the accent color across the wrist end, with no wrap on the forearm, so the dark part of the hand is no bigger than the fist. Enemies kept the bigger fist blocks until Game-boy's first-person playtest (see the boxer stance above).
- Each wrap, strap or finger band caps the hand's face it ends at instead of ending flush with it (flush faces z-fight). Fist points, `WeaponGrip` and `WeaponTip` stay where they were, and hitbox radii are move data and do not change.

**Colors** (Spec §10: 4-6 flat colors per character, from `PlaceholderBody.Paint`): `body_color` (shirt), `pants_color` (trousers), `accent_color` (cap, wraps, shoes), `skin_color`, and a dark paint for the shades, belt, soles and hair. Enemies' and dummies' trousers are their `body_color` darkened (`pants_color` left fully transparent). The player's are a neutral gray (`PlayerCharacter._configure_rig()`): in the first-person hold the rising knee sits beside the shaded right sleeve, and trousers in the shirt's navy darkened merged the two into one blue lump; gray ones also stand apart from the held head's dark hair. Every head has dark hair over the back (a ball the head's size set back and up from it), so a head seen from behind, the held head in the hold view above all, reads as a head rather than a bare skin dome; the face is unchanged. Placeholder art until Milestone 4.

**Hit flash** (Spec §6, localized by Game-boy on 2026-10-24; README's M2 departures). Two kinds, both started by the struck `CombatActor` and timed in real ticks:
- **Contact flash** (`flash_at(point, strength, radius, core)`): clean hits, guard breaks, and blocked hits at `CombatActor.BLOCK_FLASH_AMOUNT` of the strength. The body mixes toward white with world-space distance from the hit's contact point: full `hit_flash_strength` out to `hit_flash_core` × `hit_flash_radius_m`, then a smoothstep down to nothing at the radius (Tuning "Hit feel" > "Hit flash": 0.25 m, 1.0, 0.5). It is drawn by a per-rig `ShaderMaterial` (`game/fx/hit_flash.gdshader`, unshaded and transparent, first among the transparent passes so the comic effects draw over it), set as the `next_pass` of the rig's paint materials only while it runs, so an idle rig draws no extra pass and the base materials (DamageLook's marks) stay as they are. The point goes on the struck part as it is drawn: `flash_at()` clamps the contact onto the nearest hurtbox (`hurt_point()`; a thrown pipe's contact, which `Weapon` also puts there, and a flying body's lie off the body), takes it into the animation frame of the bone along that hurtbox nearest it (a chest hit the upper chest, a shin hit the lower leg) and places it on that bone's drawn follower, which it then rides (`follow_flash()`, called each tick by the actor and by the ragdoll as it shows its pose). A body in its animation pose keeps a contact inside a hurtbox where it is; a staggering or ragdolling body, drawn away from its hurtboxes, flashes on the struck part where it is shown. A radius of about 4 m whites the whole body, the flash before the change. The first rig built in a window draws the shader at zero strength (unseen) on a box at its feet until the first contact flash, so its pipelines are compiled at load rather than on the first hit's frame.
- **Whole-body flash** (`set_flash(amount, color)`): emission on every material, used by the cyan parry flash (`parry_flash_frames`). `set_flash(0.0)` clears both kinds, and starting one ends the other.
- **Frames:** the flash shows for exactly `hit_flash_frames` (2) rendered frames. The actor counts it down in its `_physics_process` but skips the tick it started in: the player runs before the dummies in a tick, so a dummy it struck used to count the hit's own tick and showed one white frame.

**Animation ids** the rig must provide (all procedural placeholders in Milestone 1):
- Locomotion: `idle`, `walk_forward`, `walk_back`, `walk_left`, `walk_right`
- Air: `jump`, `fall`, `land`
- Dodge: `dodge_left`, `dodge_right`, `dodge_back`, `dodge_forward`
- Guard: `block` (the block guard, held), `block_hit` (blockstun), `guard_break`, `recoil` (a blocked attacker)
- Grab: `grab`, `hold` (holding someone), `held` (being held), `thrown`, `pickup`, `haymaker_charge`
- Hit reacts: `flinch_head_front`, `flinch_head_left`, `flinch_head_right`, `flinch_gut`, `flinch_legs`, `stagger_back`, `stagger_left`, `stagger_right`, `stagger_forward`
- Down: `launched`, `knockdown_back`, `knockdown_forward`, `downed_back`, `downed_front`, `getup_back`, `getup_front`, `ko_back`, `ko_front`
- Every move id below, through `play_move()`, timed to its frame data

**Playback notes:**
- **Cross-fades are done by the rig, not by `AnimationPlayer`.** Godot keeps every earlier blend running with its own blend time, so a strike that started during a locomotion switch or a dodge would still carry the old pose into its active frames. Instead, starting an animation snapshots the pose on screen (local bone rotations and the Hips position) and plays the new animation at full weight. `advance()` then slerps from the snapshot to the animation's pose over the blend time. `play_move()` caps that time at 75% of the startup, so the strike pose is always reached unblended.
- `haymaker_charge` ends on the haymaker's wind-up pose. The player plays it while P has been held for at least `hold_frames` (when releasing P would start the haymaker). `play_move(haymaker)` started from it uses a variant that begins at the cocked pose, so the release drives straight into the swing. In first person the cocked right fist is out of view (behind the lens), and the lead hand reaches out on the left, so the view center (the aim dot and the target's head) stays clear for as long as P is held.
- A body that is already down or flying does not stand back up first. `ko_*` from a lying animation skips to the end of the slump. `ko_*` and `knockdown_*` from `launched` or `thrown` skip the standing buckle and join the fall at the point where the head is no higher than it is now. A fade out of `launched` or `thrown` that would swing the body up through upright (landing face down after a face-up launch) rolls it over a side instead. The roll turns the spine about the vertical while its tilt moves straight from the start to the end pose, so the head neither rises nor drops below the pose it lands in and bounces back.
- **Skeleton modifiers: the ragdoll path (Milestone 2).** `advance()` computes the FK itself from the skeleton's local (animation) poses. Hurtboxes, rig points and `get_point_transform()` always use that pure-animation FK, so hit detection stays deterministic and independent of the ragdoll. The ragdoll is two `SkeletonModifier3D`s under the skeleton, a `PhysicalBoneSimulator3D` and then the `Ragdoll`, built on the first `ragdoll_start()` and inactive otherwise. While one runs, `skeleton.advance()` defers the skeleton's update to the end of the physics frame (Godot 4.4+), after every actor has posed and before the physics step; there the simulator writes the bodies' poses (blended by its `influence`) and the `Ragdoll` reads the post-modifier local poses and moves the visual followers (meshes and attachment nodes) to them (`show_visual_pose()`; `get_visual_point_transform()` reads the visible pose). With no ragdoll running, `advance()` moves the followers to the animation FK as before, bit for bit. `ragdoll_stop(blend_s)` hands back to the animation through the rig's own cross-fade, starting from the last visible pose.

**Ragdoll** (Spec §6 "Hit reactions", `game/actors/ragdoll.gd`; tunables in the `Ragdoll` TuningData group). A visual layer for enemies and dummies (the player only with `Tuning.ragdoll_player`, off by default: its first-person limbs never flop):
- **Bodies:** one `PhysicalBone3D` per bone from the hips through the head, the arms and the legs (`PlaceholderBody.ragdoll_specs()`: shapes covering the meshes, mass shares, joints); the hands and toes ride their parent. Joints are made on the physics server with frames at the rest pose: cone twists centered on the poses the animations use, hinges for elbows (0 to 150 degrees), knees (-130 to 0) and ankles; they are rebuilt if the actor leaves the tree and comes back. No self-collision; layer 8 (`ragdoll`); continuous collision, so a hand or foot flung at the floor does not tunnel into it. Built once per rig; idle, the bodies are static with no layer and ignore the actor's moves (no transform notifications), so a walking actor costs nothing for them.
- **Partial** (staggers: `STAGGER` hits, guard breaks, perfect-block staggers, a staggering release from a grab): the upper body simulates on the hips and legs, which stay kinematic on the animation and on no layer; the simulator's influence (`ragdoll_partial_influence`, 0.9: above Spec §6's 0.3-0.6 by Game-boy's call, so staggers read from the side view too) holds, then fades to 0 within the stagger, and it stops. A stagger on a staggering body keeps the bodies as they are and raises the influence back from where its fade had got to (`ragdoll_partial_rise_s`), so nothing pops. The arms are pulled toward the stagger animation harder than the spine and head (`ragdoll_partial_limb_pose_hz`): the animation's arm fling stays and the kick adds give on top. The neck and head, and the arms unless the kick landed on them (a guard break, a parry), show less of the simulation on their joints than the trunk (`ragdoll_partial_head_influence`, `ragdoll_partial_arm_influence`, 0.45 against the trunk's 0.9; the `Ragdoll` applies it to the visible pose): they ride the trunk as it gives way, so the hook's head no longer lolls onto a shoulder and an arm no longer trails behind a trunk thrown sideways. A stagger pushed sideways (the hook) also leans the trunk back, away from the attacker: a kick on the trunk of `ragdoll_stagger_back_share` (0.5) of the push's sideways speed, visual only (the body slides with the move's knockback), so the side view, looking along that push, sees the body give way too. A parried attacker's partial ragdoll starts from the snapped stagger pose and drops the part of the striking arm's velocity that runs toward the defender; an arm's kick moves the whole arm, and a stagger's kick on the trunk the whole trunk (on one body the joints soak it up). **Full** (launch, knockdown, throw, KO): every body simulates; its influence rises from 0 to 1 over `ragdoll_full_rise_s` (from standing or from a stagger) with stronger turns meanwhile (`ragdoll_full_rise_pose_hz`), so the hit's frame snaps into the animation's pose as without a ragdoll, the finisher's hitstop and slow-mo show it, and the bodies take over from it. A body launched out of a hold (thrown, or KO'd by a knee) leaves it as a release does instead: its origin moves under the hips as they are drawn, the animation fades out of `held` over the release blend, and the full ragdoll takes over at once from the held pose, so the body leaves bent over and straightens in the air, never snapping upright inside the holder (tests/test_launch_from_hold.gd). It lands (`Phase.DOWN`), goes limp on a KO (`Phase.LIMP`) and sleeps once at rest. Light flinches stay animated.
- **Following the sim:** every body starts from the pose on screen with its bone's animated velocity plus the actor's new velocity, and the hit's kick lands as a velocity change on the struck part (its hurtbox region). Each step a soft spring moves the whole ragdoll toward the animation's hips (where the sim body is), the whole ragdoll turns as one about its hips toward the animation's hips rotation (`ragdoll_flight_turn_hz` flying, `ragdoll_hips_turn_hz` lying), and pose springs pull each body toward the animation's pose re-anchored on the hips as they are (where it sits from them and how it is turned; a KO's are nearly off). A body's turn target is kept inside its joint's limits from its parent body as it is, and the faster turns while the influence rises only turn the bodies, never pull a light head or hand by where it sits (which wrenched necks past their limits). A body launched from behind (the animation's back-arched flight that flips face down on landing) turns toward the face-down lying pose in the air instead (`HumanoidRig.ragdoll_aim_landing()`). The visible body never drifts: lying, its head, torso and legs (the bones the hurtboxes ride) stay within about 0.15 m of the hurtboxes face up and 0.2 m face down (tests/test_ragdoll.gd measures both); its arms, which carry none, are pulled more softly (`ragdoll_down_arm_pose_hz`, against `ragdoll_down_leg_pose_hz` for the legs) and lie more as they fell. A body landing face down can still push a shoulder past its joint limit for a few frames on impact.
- **The kick at the contact point** (Spec §6; `ragdoll_kick_at_contact`, on by default; Tuning "Ragdoll" > "Kick at the contact point"): besides that central kick, the kick's off-center part twists the struck body. Its angular impulse about the struck body's center (the lever clamped to `ragdoll_contact_lever_m`, times `ragdoll_contact_twist`) turns the struck body and its simulating parents (`ragdoll_contact_chain` bodies: the head with the neck, a forearm with the upper arm) as one rigid piece about the joint the piece hangs from, at the rate that impulse gives the piece's inertia, capped per part (`ragdoll_contact_spin_head`, `_trunk`, `_limb`, rad/s). A light hand or neck turned alone spun at about 50 m/s and the joints then fought it (WP4 dropped it for that); the piece turning from its joint keeps the joints together. Off, the kick is central only. Measured (tests/test_ragdoll.gd, the A/B captures of phase 3): within each part's cap on every kick (`Ragdoll.top_contact_twist()`), no NaN and no more joint stretch than the central kick after 60 off-center hits in a row; it adds a little twist (the hook's head turns a few degrees more, the guard break's head and trunk more), but the central kick already throws the head and neck to the neck's joint limits on a stagger, so the two look nearly alike.
- **Time:** the bodies run in the actor's sim time (`TimeController.scale_for(actor)`, passed by the rig each tick): their velocities scale by b/a when the scale changes from a to b, gravity (`Tuning.gravity` times `ragdoll_gravity_mult`) by b² and damping by b; at 0 they are put to sleep with their velocities kept. The step of the frame a ragdoll starts or takes a kick holds still too (that hit's hitstop starts on the next frame), so the kick lands on the first step after the hitstop. `Engine.time_scale` stays 1.
- **KO and blink-off** (Game-boy's departure from Spec §6's "bodies stay until the arena clears", README; `CombatActor`, Tuning "Ragdoll" > "KO and blink-off"): a KO'd enemy or dummy goes limp and lies `ko_linger_s` (1.5 s), blinks on and off for `ko_blink_s` (1.0 s), its rate rising from `ko_blink_start_hz` to `ko_blink_end_hz` (4 to 12 on-off cycles per second, each off first), and is gone for good (`CombatActor.is_gone()`): its ragdoll stopped, hidden, no hurtboxes, on no collision layer and moving no more. It stays KO'd, so nothing hits, grabs, aims at or piles onto it, and `CombatEvents.vanished` drops its health bar if it is still up (the debug draw skips it too). The timing runs in the actor's sim time (hitstop holds it); the rig only shows or hides (`HumanoidRig.set_shown()`). The player never blinks off (`_blinks_off_when_ko()`: team 0 keeps its KO and gets up). A training dummy comes back `dummy_revive_s` (1.0 s) after it blinked off, standing at its post and facing as `set_post()` placed it (or, when someone is on the post, as the player who knocked it out often is, at the nearest free spot one or two body widths around it; with none it waits), at full health (its damage look follows the health back to clean), blinking in over `ko_blink_in_s` (0.5 s, at `ko_blink_in_hz`) out of reach (no hit, no grab, no magnetism: `CombatActor.is_blinking_in()`), a ghost that a thrown pipe passes through, then solid. About 4 s from the KO to back. Milestone 3's enemies stay gone (their spawner can free them on `vanished`).
  - Someone on the post, for `TrainingDummy._respawn_spot()`: a standing body, and any ghost too (a body lying, held, flying or getting up), in the capsule the dummy would stand in; a body drawn lying across the spot (its ragdoll's trunk, legs and arms along the floor, the two bodies' radii away: a ragdoll lies beside its upright capsule); or another dummy that came back there on the same tick (its physics body only moves there in the next step). A spot beside the post also needs floor under it (at the post's level, give or take the body's `floor_snap_length`) and no wall or curb on the way from the post (a capsule cast). The shapes and queries are built once.
  - The comeback stays a ghost until its blink-in is over and no standing body is inside it (the player can walk into a ghost meanwhile; turning solid around it would shove it away).
- **Enemy health bars over a ragdoll** (`EnemyHealthBars.screen_anchor_of()`, presentation reading the drawn rig): a bar sits just above the body as it is drawn on the current camera's screen, not on the head's top alone, which a stagger bends toward the side view, a launch puts under flung arms, a hold puts at the holder's waist and a fall puts on the floor. Up, at the highest the body shows on that screen: its head's top (`get_head_top_position()`, floating above the head, brought over the head's joint: beside a bent or lying head it would float over empty floor) or any joint raised by `body_margin_m` (0.15 m, the chest's half depth), so it stays about as close above a bent, flying, held or lying body as over a standing head. Across, over the drawn hips: under the head while it stands, the middle of a body lying or flying, and the far side of a body held bent over, off the holder's head. A KO'd body's bar shows the killing hit's chunk drain, then fades out (`fade_seconds`), and is gone by the time the body starts blinking at the latest; no bar is drawn while the body is hidden. Spec §5's 2 s after a hit stays the most a bar lives.
- **Rest:** a lying ragdoll sleeps once every body moved slower than `ragdoll_rest_speed` in the last physics step for `ragdoll_rest_s`, or at the latest `ragdoll_settle_max_s` after it started lying (as long as a knockdown lies, so a body that gets up is not frozen mid-motion first; a KO lies longer); a contact that wakes it (a body falling on it) or a stomp starts the count again.
- **Get-up:** `CombatActor._start_getup()` moves the body's origin along the floor toward where the ragdoll's hips lie, to the spot nearest them where the world and the other bodies (standing or lying) leave room for its capsule. With no room on the way and only standing bodies in it (the player standing over it after a stomp) it gets up where the sim body is, as without a ragdoll; where another body lies too (two that fell on each other) it gets up beside it, at the free spot `ragdoll_getup_aside_m` around its ragdoll's hips nearest to it with no wall or curb on the way there. The get-up animation then fades from the ragdoll's pose as it shows in the body's new frame (`ragdoll_getup_blend_s`, longer when the body has further to go: it slides there no faster than `ragdoll_getup_slide_speed`). This is the one place the ragdoll feeds the simulation.

## Moves (Spec §4) and their data

Ids are the `.tres` names in `game/combat/moves/`. Each move's animation id equals its move id. Frame data are starting values; damage values come from the spec and are fixed. Strike reach is where the strike point should be at the strike pose, in the attacker's local frame (−Z forward, y above the feet). With targets standing about 0.85 m away, these values connect.

| Move id | Chain | Startup/Active/Recovery | Dmg | Tier | Reaction | Knockback (x,y,z) | Hitbox | Strike reach |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `jab_1` | P | 4/3/10 | 6 | LIGHT | FLINCH | 0,0,1.5 | LeftFistPoint r0.12 | z ≤ −0.65, y 1.35–1.65 |
| `jab_2` | P P | 4/3/10 | 6 | LIGHT | FLINCH | 0,0,1.5 | RightFistPoint r0.12 | z ≤ −0.65, y 1.35–1.65 |
| `hook` | P P P | 6/3/14 | 8 | HEAVY | STAGGER | −2.2,0,0.6 (snaps the head sideways; the ragdoll also leans the trunk back) | LeftFistPoint r0.14 | z ≤ −0.5, y 1.35–1.65 |
| `uppercut` | P P P P | 8/3/22 | 12 | FINISHER | LAUNCH | 0,6,3 | RightFistPoint r0.14 | z ≤ −0.45, y 1.4–1.8 |
| `body_flurry` | P · P, repeat P up to 6 | 2/2/6 | 2 | LIGHT | FLINCH (hitstun 10) | 0,0,0.3 | both FistPoints r0.12 | z ≤ −0.55, y 1.0–1.3 |
| `shove` | flurry's auto_next | 6/3/18 | 6 | FINISHER | STAGGER (shoves into others) | 0,0,7 | both FistPoints r0.16 | z ≤ −0.55, y 1.1–1.45 |
| `spinning_backfist` | P P · P | 12/3/20 | 14 | FINISHER | KNOCKDOWN | −1.5,3,6 | RightFistPoint r0.15 | z ≤ −0.65, y 1.35–1.65 (after a full turn) |
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
| `throw` | K while holding | 8/2/20 | 15 | HEAVY | THROWN | 0,5,6.5 (stick dir; arcs about 0.6 m up; 0,3,9 until the M2 phase 3 review barely left the floor) | none (applied to held victim) | — |
| `stomp` | K near a downed enemy | 8/3/14 | 8 | LIGHT | GROUND, hits downed only | 0,0,0 | RightFootPoint r0.22 | z ≤ −0.5, y 0.0–0.3 |
| `pipe_swing_1` | P with weapon | 7/3/12 | 10 | LIGHT | FLINCH | 0,0,2 | WeaponTip r0.18 | z ≤ −0.7, y 1.0–1.7 |
| `pipe_swing_2` | P P with weapon | 7/3/12 | 10 | HEAVY | STAGGER | 1,0,2 | WeaponTip r0.18 | z ≤ −0.7, y 1.0–1.7 |
| `pipe_swing_3` | P P P with weapon | 9/4/20 | 10 | FINISHER | KNOCKDOWN | 0,2,6 | WeaponTip r0.2 | z ≤ −0.7, y 1.0–1.7 |
| `weapon_throw` | LB with weapon | 6/1/14 | 15 | HEAVY | KNOCKDOWN | 0,2,6 | none (spawns projectile) | — |
| `impact_body_knockdown` | flying body hits someone | 0/1/0 | 5 | HEAVY | KNOCKDOWN | 0,2,3 | none | — |
| `impact_body_stagger` | shoved body hits someone | 0/1/0 | 0 | LIGHT | STAGGER | 0,0,2 | none | — |
| `dummy_jab` | sparring training dummy | 24/3/16 | 6 | LIGHT | FLINCH | 0,0,1.5 | RightFistPoint r0.14, no magnetism | z ≤ −0.65, y 1.35–1.65 |

`dummy_jab` is the sparring dummy's telegraphed right (see "Block"): its 24 frames (0.4 s; 18 until Game-boy's second playtest) of startup are the wind-up (the fist cocked back beside the head by 60% of it, the lead fist holding its side of the chin while the shoulders turn away, so from the defender's lens the face and the cocked fist both stay in view), then `jab_2`'s straight right. It connects out to about 1.05 m between the two bodies' centers; the sparring dummy steps in to `sparring_step_in_m` (0.9 m) before it throws it.

**Blocking fields** (every move): `unblockable` (false for all of Milestone 1), `guard_damage_mult` (1.0; the pipe swings 1.5), `blocked_recoil_frames` (14).

Kicks use the camera offsets `camera_pitch_deg = −10` and `camera_drop_m = 0.05`. The flying kick (it dives at the target) and the stomp use −25, with the same 0.05 drop. The knee uses −12 and 0.05 on top of the hold view's pitch (see "First-person hold view").

**View-turn fields** (Game-boy's second playtest; first-person presentation only, aim and hits never use them):
- `camera_spin_follow` (0..1): the share of the eyes' turn since the move started (`HumanoidRig.eye_yaw()`, unwrapped) the view turns with, eased onto whole turns over the recovery so it lands back on the heading. 1 on `spin_kick`, `spinning_heel` and `spinning_backfist`; times `Tuning.cam_spin_follow_mult` (1; 0 turns it off). The three spins key the head to lead the turn (spotting): the eyes turn 360° at an even rate (at most 30° a frame from idle, about 40 chained out of the roundhouse) and face the target at contact.
- `camera_yaw_deg` (positive turns left) with `camera_hold_frames`: a view turn eased in over the startup, held through the active frames and `camera_hold_frames` more, eased out over the rest of the recovery (the pitch and drop use the same weight). The back elbow: −150° and pitch −10, held 6 frames. Game-boy asked for about 100–120°, but the elbow drives straight back behind the spine: at the 90° FOV a 120° turn shows neither it nor a body straight behind (that body's edge comes in from about 121°, the elbow's tip from about 140°); at 150° both are in the right half of the view while it connects. The player's own right upper arm then shows large near the lens, under the third of the view the rig tests allow.

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
- `jab_1`: `P → jab_2`, `P (PAUSE) → body_flurry`
- `jab_2`: `P → hook`, `K → push_kick`, `P (PAUSE) → spinning_backfist`
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
- Blocking: `guard: float`, `max_guard() -> float`, `is_guarding() -> bool` (BLOCK or BLOCKSTUN), `is_guard_effective() -> bool`, `is_dropping_guard() -> bool`, `start_block(can_parry = true)` (false: a guard re-raised by a held button, which never parries), `drop_guard(frames)`, `react_to_block(hit)` (the attacker's side, called by HitDetector), `get_block_arc() -> Dictionary` (`{origin, forward, half_angle_deg, effective}`, empty when not guarding)
- `start_move(move, chain_step, input_timing, windup = false)`: with `windup` the startup runs in WINDUP (enemy telegraphs) and emits `windup_started` / `windup_ended`
- `get_head_top_position() -> Vector3`, `get_chest_position() -> Vector3`
- `can_be_grabbed() -> bool` (grab anytime, Game-boy's second playtest): standing and not held, in FREE, WINDUP, HITSTUN, STAGGER, BLOCK, BLOCKSTUN, or ATTACK outside the active frames; never invulnerable, dodging, airborne, downed, flying, getting up or KO
- `receive_hit(hit: HitInfo) -> bool`
- `debug_state_text() -> String`
- `debug_hitbox_volumes: Array[Dictionary]` holds this sim frame's active hitboxes:
  - `{kind = &"sphere", center: Vector3, radius: float}`, or
  - `{kind = &"arc", origin: Vector3, forward: Vector3, radius: float, half_angle_deg: float, h_min: float, h_max: float}`

**`PlayerCharacter`** (`game/player/player.gd`, group `"player"`) adds what the cameras and HUD read:
- `look_yaw: float`, `look_pitch: float` (radians). Yaw 0 faces −Z, and positive pitch looks up.
- `get_eye_transform() -> Transform3D`: the world transform of `EyePoint`.
- `get_look_basis() -> Basis`: `Basis.from_euler(Vector3(look_pitch, look_yaw, 0))`.
- `get_camera_move_offset() -> Vector2`: x is the extra pitch in degrees (negative is down), y is the camera drop in meters (negative raises): the running move's plus the hold view's. Both are already eased.
- `get_camera_pull_back() -> float`: meters the lens moves back along the flat look (the hold view's, eased). `get_hold_view_weight() -> float`: the hold view's eased weight, 0..1.
- `get_camera_view_yaw(fraction = 1.0) -> float`: the view's turn away from the look in degrees (positive left): spin follow plus `camera_yaw_deg`, computed once per physics tick after the rig advances; `fraction` interpolates from the last tick to this one. Whenever the turning move changes (it ends, is cut short, or is cancelled into another, such as a back elbow out of a spin) the turn on screen is wrapped to ±180°, on both ticks alike, and carried over, settling back by a quarter per tick on top of the new move: the view never jumps or sweeps round between ticks.
- `is_walking() -> bool`: on the ground and moving under the player's own control.
- `standing_eye_height: float`: the eye height above the player's origin in the idle pose.
- `get_magnetism_cone() -> Dictionary`: `{origin, forward, half_angle_deg, range, target}` for debug draw.
- `holding_weapon() -> bool`, `weapon_durability_left() -> int`
- `auto_revive: bool`: the test room sets it; a KO'd player gets back up after `Tuning.player_revive_s` with full health

**`TrainingDummy`** (`game/enemies/dummy/training_dummy.gd`, group `"enemy"`): `sparring: bool`, `set_post(pos, yaw, fresh)`, `start_jab()` (the telegraphed jab now, from FREE, wherever the player stands), `spar_in(frames)` (time the next sparring jab; the dummy still steps in first). `set_post()` keeps a moved body a ghost for one physics step: Jolt moves a kinematic body to a new transform during the next step, so it would otherwise turn solid where it stood (a held dummy inside its holder). A comeback after a KO (`_respawn()`) stays a ghost through its blink-in (see "KO and blink-off").

**`CameraDirector`** (`game/camera/camera_director.gd`, group `"camera_director"`):
- `signal camera_changed(mode: StringName)`
- `mode: StringName`: one of `&"first_person"`, `&"side_view"` or `&"free_fly"`
- `cycle()`: bound to `camera_cycle` (F2)
- `active_camera() -> Camera3D`

**VFX** (Milestone 2 WP2, `game/fx/`; the test room adds a `VfxDirector`, group `"vfx_director"`). Presentation only: it subscribes to `CombatEvents` and never writes game state; the damage look changes rig materials only (`HumanoidRig.set_damage_look(level)`). Every size, time and chance is in Tuning's "VFX" group.
- It processes after the cameras (`CameraDirector.PROCESS_PRIORITY + 1`), so billboards, size caps and keep-in-view clamps use the view being rendered this frame.
- `VfxArt` holds every effect texture for the run and the director loads the whole set when it is created: a canvas draw keeps only a texture's RID, and Godot's resource cache holds no reference, so an unheld texture is freed after the frame (the speed lines once drew as gray boxes) and reloaded from disk on the next hit.
- A hit's world effects are pooled `ComicSprite`s. Each kind (bursts, words, block sparks) scales its tiers by one shared factor between `vfx_min_view_share` (the smallest of the kind) and `vfx_max_view_share` (the largest), so light, heavy and finisher keep their size ratios at any distance. They sit at the contact, pulled inside the view only when the contact is within `vfx_clamp_reach_side_deg` / `_low_deg` of it; hits on the player are brought out ahead of the lens and always shown.
- `SpeedLines` (a canvas layer under the HUD) converge between the view center and the contact (`vfx_speed_lines_focus_follow`) and stop at the screen rects of the live bursts and words. Lunge lines need a move with its own lunge (`MoveData.lunge` / `free_lunge`), not the magnetism step-in. With `impact_frame_enabled` off they never re-shuffle (no flicker).

**ComboParser usage** (decisions settled during the build):
- Interrupt branches, such as RB into the back elbow from a recovery, continue the chain: timing `&"chain"` and `chain_step + 1`. Only root branches give `&"root"` with step 1.
- `ComboBranch.timing` only matters on a move's own branches. Root and interrupt branches ignore it.
- The owner calls `reset_chain()` whenever a move is cut short (hit, dodge cancel, grab, KO) and whenever the context changes (jump, landing, grab or release, picking up or losing a weapon).
- `buffer(input)` hands a press back at age 0 without touching the hold timers: the player holds a P or K pressed in the guard outside the buffer and buffers it fresh once the guard is down.
- `HitInfo.input_timing` is one of `root`, `chain`, `pause`, `repeat` or `auto` from the parser. Code-applied hits add `body` (flying or shoved bodies) and `thrown` (thrown weapons).

**First-person view turn:** the camera turns the look basis about world up by `player.get_camera_view_yaw(Engine.get_physics_interpolation_fraction())` before the move's pitch, and puts the lens ahead along the turned view. Interpolated always (unlike the origin), so a spin turns smoothly on displays faster than 60 Hz, at the cost of up to a tick of lag behind the body.

**First-person camera smoothing:** the camera follows the player's origin rigidly and damps only the eye's offset from that origin (about 0.05 s). Damping the whole world position would make the camera trail the body by speed × 0.05 s.

**First-person lens** (Game-boy's call after the M1 playtest): the camera sits at `EyePoint + FirstPersonCamera.lens_offset(look_basis)`, 0.2 m below the eye at throat height (`Tuning.cam_height_offset_m`) and 0.04 m ahead along the flat look (`cam_forward_offset_m`), Mirror's Edge style. It is presentation only: aim, magnetism and hit detection never use it. The rig tests judge every first-person view from this lens (`tests/test_humanoid_rig.gd` with the ray-cast helpers in `tests/fp_view.gd`):
- Looking ahead at rest or walking, the arms stay out of view.
- A punch comes in from below or the side: the arm (the elbow end of the upper arm, forearm and fist) runs off the edge of the view, and the body covers at most a third of it.
- Kicks show the foot and lower leg, with the move's camera pitch and drop.
- Looking down, nothing of the torso stands in front of the legs. The view's bottom edge is 74 degrees below level when looking down 45 degrees, short of the feet under the body: 45 degrees shows the lead hand, the lead shoe comes in from about 60 degrees and the lead thigh from about 65 (walking, the striding foot and shin from 55). Looking steeply down shows the belly's rounded top (`BellyTop`), not a flat lid.
- An enemy's boxer guard leaves the view to the fight: 0.9 m in front of the lens its hands and forearms cover at most about 12% of the view, at the sparring step-in its gloves at most 8%, and its head shows whole in the guard and all but whole through the sparring jab's wind-up and its recoil (see the boxer stance above).
- The block guard keeps its fists in the upper third and its forearms 0.3 m or more from the lens. Through a blocked hit's push-back (`block_hit`) the fists stay up on their own sides, the forearms that far away, the center clear and the body under a third of the view; a guard break swings the fists out of the upper corners over a few frames.
The forward offset stays small: the guard's forearms stay that far from the lens, the lead foot stays ahead of it when looking down, and a held victim's head stays further off. At 0.02 m or less the belly sits under the lens and comes up over the legs.

**First-person hold view** (Game-boy's playtest of the grab, 2026-10-24; Tuning "Grab and weapons" > "Hold view"). The hold (`PlaceholderPoses.hold()`) bends the player forward at the waist over the held victim, hips back and knees soft, fists on its shoulders, so it reads as a clinch side on; the knees keep the bend. The bend leans the eyes about 0.12 m forward and 0.07 m down, out over the victim. While an enemy is held (knees included), the first-person view therefore:
- pitches down `grab_view_pitch_deg` (16), moves the lens back `grab_view_back_m` (0.24) along the flat look and raises it `grab_view_rise_m` (0.1), so the victim's shoulders, back and head sit in the lower part of the view, the street ahead above them, and its head and back stay 0.25 m or more from the lens;
- eases in over `grab_view_in_s` (0.2) after the grab and back out over `grab_view_out_s` (0.45) once nothing is held (thrown on the throw's startup frame, let go with LB, released by the third knee, or a hit that breaks the hold), from wherever it is, in sim ticks (still through hitstop), smoothstepped;
- adds a knee's own pitch and drop (−12, 0.05) on top, so the view dips onto the knee as it comes up beside the victim's head (out to the right; from straight under, the head hid it) and the knee shows landing on it; the hold's weight stays full, so nothing jumps between knees, into the throw or out of a release.
`PlayerCharacter` ramps the weight (`_tick_hold_view()`) and returns the offsets; `FirstPersonCamera.view_from_eye(player, eye)` builds the view from them (the camera passes the smoothed eye, tests EyePoint itself). The walking bob clamp is skipped while holding: walking with a held enemy shows the hold pose, whose eye sits well under the standing height. `tests/test_grab_view.gd` checks the easing, the knees' pitch, and, looking level through the hold, three knees and a throw, that no forearm or hand comes within 0.3 m of the lens, the player's own body covers at most a third of the view, the victim at most half, and the knee shows meeting the victim on every active frame.

**Input:** actions are registered by the `GameInput` autoload (`game/autoload/game_input.gd`). `PlayerInput.poll()` reports button edges; live, it also releases a button it reported held whose action is no longer pressed, so a release it never saw (let go while paused, when the player does not poll) cannot leave the guard or a haymaker charge stuck. Mouse look comes from `GameInput.consume_mouse_delta()`. The free-fly camera uses `consume_fly_mouse_delta()` and the `fly_*` actions, so the player keeps WASD and the mouse.

**Audio and rumble** (Milestone 2 WP3, `game/audio/`; the test room adds both). Presentation only: they subscribe to `CombatEvents` and never write game state. Every volume, variation, distance and rumble value is in Tuning's "Audio" group.
- `AudioDirector` (group `"audio_director"`): `signal played(pool, voice)` for every one-shot; `play(pool, at, volume_db, pitch = 1.0) -> AudioStreamPlayer3D` (a random variant, never the pool's last one, ±`sfx_pitch_variation` / `sfx_volume_variation`); `impact_position(hit)`, `tier_db(tier)`, `layer_db(pool)`, `listener_transform()`, `sfx_limiter()`. Samples come from `SfxBank` (`<pool>_<nn>.wav` in `assets/export/sfx/`, made by `tools/gen_sfx.gd`).
- A hit plays its tier's layers at the contact point, each `hit_<tier>_db` louder. One swing through several bodies in a frame (same attacker, same physics frame, different victims) plays the whoosh and sub thump once and the rest of each further body `extra_victim_db` quieter. Hits on the player play `self_hit_offset_m` from the listener toward the attacker (`-hit.direction`): the contact point sits around the listener itself.
- A fixed pool of `AudioStreamPlayer3D` voices; with all busy, the one started longest ago gives way. The listener rides the player's eyes and look in every camera mode. Real time throughout: sounds start on the contact frame and never stretch with hitstop, slow-mo or the debug time scale.
- Buses, made on first use without a project layout: "SFX" (a hard limiter whose pre-gain is `sfx_volume_db`: a bus volume applies after its effects), "SFX Rear" (a low-pass for sounds behind the listener, into "SFX") and "Music".
- `RumbleDirector` (group `"rumble_director"`): `Input.start_joy_vibration` on every connected joypad for hits the player lands or takes (`vibrate` is the test stub). A pulse during a running one takes the stronger motors and the later end; the finisher's second pulse runs on real time and is dropped on pause.

## Block (Game-boy's held block, approved after the M1 playtest; an addition to Spec §4)

Blocking lives in `CombatActor`, so any actor can block (enemies may in Milestone 3); for now the player controller drives it. Every number is a `TuningData` default in the groups "Block" and "Sparring" (`Tuning.data.*`), or a `MoveData` field.

**Input** (`PlayerCharacter._b_action()`): the B (`dodge`) press decides when it is pressed. With the stick under `block_stick_threshold` (0.3) it raises the guard; otherwise it dodges that way (the backstep is B + back). Keyboard: Shift alone blocks, Shift + WASD dodges. A press buffered during a move is decided by the stick when it was pressed. The block starts from FREE or a cancellable recovery, like the dodge.
- Late stick (Game-boy's second playtest, "I couldn't get the character to dodge"): replayed through live input (joypad motion and button events, keyboard, `Input.action_press`, through `PlayerInput.poll()`), stick-then-B dodged, but B or Shift pressed a moment before the direction raised the guard. A guard raised by a fresh B press with the stick centered now turns into a dodge when the stick passes the threshold within `dodge_late_stick_frames` (8) of the press, B still held, unless the guard has stopped a hit. Later, the stick walks in the guard as before.
- Holding B keeps the "dukes up" guard (`block`): walking at `block_move_mult` (0.35) of the move speed, looking and quick-turning freely (the body, and the guard, follow the look), no jump, LB ignored: JUMP and GRAB presses are dropped while the guard is up (from the release on they stay buffered, so LB right after letting go grabs a parried attacker).
- Releasing B drops the guard; the block ends `block_release_frames` (4) later. P or K drops it too and starts its attack `block_attack_cancel_frames` (2) later. The press is held back outside the ComboParser buffer while guarding, blockstun included, and buffered fresh (`ComboParser.buffer()`) once the guard is down, so it always attacks: pressed during a blockstun, the guard stays up through it and the attack starts 2 frames after it. A dropping guard stops nothing.
- Holding B keeps the block (Game-boy): back to FREE with the B press that blocked still held (after a hit, a knockdown, a guard break's stagger, an attack out of the guard, a grab), the guard comes up again, raise frames and all. A guard re-raised that way never parries (`start_block(false)`): a perfect block needs a fresh press. B pressed with a stick direction and held is a dodge, not a block.

**Coverage** (`CombatActor._try_block()`): the guard stops a hit once it has been up `block_raise_frames` (1; 4 until Game-boy's second playtest), when the attacker stands within `block_arc_half_angle_deg` (60) of the guard's facing (the player's look). Flying bodies and thrown objects (`hit.is_body_impact`) are judged by where they came from. Side and back hits land in full. `MoveData.unblockable` moves go through. Thrown or launched bodies are blockable from the front and drain the guard `body_impact_guard_mult` (2.0) times harder; thrown weapons by their move's `guard_damage_mult`.

**A blocked hit** keeps its contact: `CombatEvents.hit_landed` still fires, with `hit.blocked`, `hit.damage` = the chip and `hit.reaction` = what the defender did (NONE, or STAGGER for a guard break), followed by `blocked(defender, hit)`.
- Chip: `chip_ratio` (0.15) of the damage, never below 1 health (god mode: none).
- Guard meter: `guard_max` (100), drained by `guard_drain_per_damage` (4) × damage × `guard_damage_mult`; it regenerates `guard_regen_per_s` (35) after `guard_regen_delay_s` (0.75) without a blocked hit. `guard_changed(actor, guard, max_guard)` on every change.
- Blockstun (BLOCKSTUN, `block_hit`): `blockstun_light_frames` (10) for LIGHT, `blockstun_heavy_frames` (16) for HEAVY and FINISHER, pushed back `block_push_light_m` (0.3) or `block_push_heavy_m` (0.6) along the hit, slowing evenly to a stop. Still guarding; no attacks or steps (presses stay buffered).
- Hitstop: `block_hitstop_ms` (30) on attacker and defender, not the tier's, and no finisher slow-mo (`HitDetector.hitstop_for()` for code-applied hits).
- Attacker recoil: when every hit of the frame was blocked, HitDetector calls `react_to_block()`: HITSTUN for `blocked_recoil_frames` with `recoil` (0 = none, for Bruiser and boss moves): the punish window.
- Guard break: the meter at 0 staggers the defender (STAGGER, `guard_break`, grabbable) for `guard_break_frames` (45); the guard drops (`guard_broken(defender, hit)`, `hit.guard_broken`), the meter stays empty for those frames and then refills to `guard_break_refill` (50). The attacker does not recoil.
- Perfect block (`perfect_block_enabled`): a blockable frontal hit landing at most `perfect_block_window_frames` (14) frames after a block started by a fresh B press (until Game-boy's second playtest: raise 4 + window 8, which only an early guess could hit). Against the 24-frame sparring jab any press from 10 frames into the wind-up until 2 frames before contact parries, a reaction 200 ms in included: no chip, drain or blockstun, `hit.perfect_block`, `perfect_blocked(defender, hit)` after `blocked`, the defender's rig flashes cyan for `parry_flash_frames` (8), and the attacker staggers (a real STAGGER, grabbable) for `perfect_block_stagger_frames` (30).

**Presentation:** the guard meter sits under the player's health bar while blocking or below full and flashes red-orange on a guard break; "PARRY!" or "GUARD BREAK!" pops just below the view center (`BlockCallout`, drawn over the combat log and the help); the combat log shows "<chip> chip" and BLOCKED, PERFECT or BLOCKED GUARD BREAK; the first-person camera shakes and punches blocked hits at `blocked_feel_scale` (0.5); debug draw (F3) draws the block arc in cyan (dimmed while the guard rises or drops), and state labels show BLOCK, BLOCKSTUN, "recoil", the guard and a dummy's WINDUP (labels of actors side by side that would print over each other are stacked).

**Sparring dummy** (`TrainingDummy.sparring`; the test room's centre dummy spars, F5 / action `sparring` toggles all three): with the player within `sparring_range` (1.7 m) and `sparring_facing_deg` (30) of its facing (and open to the jab), it walks straight in, facing the player, at `dummy_walk_speed` until the player is within `sparring_step_in_m` (0.9 m, inside the jab's reach of about 1.05 m), and throws `dummy_jab` from there every `sparring_interval_s` (2.0 s) give or take a seeded `sparring_jitter_s` (0.3). The interval runs from one jab's start to the next: the clock keeps running through the jab and its recoil, and otherwise only while the player is in sparring reach. A blocked jab's push-back therefore never makes the next one whiff: the dummy steps back in. The startup is a WINDUP (`windup_started` / `windup_ended`), scaled by `windup_mult`; any accepted hit knocks it out of it (`windup_ended(dummy, true)`, Spec §7 grunts). It never moves to flank, so the player tests flank hits by turning away. With F5, a spot between two dummies brings both in, inside the guard's arc, and their jabs drain the guard faster than it regenerates. Left alone, it walks back to its post. `sparring_jitter_s`, `sparring_facing_deg`, `sparring_step_in_m` and `parry_flash_frames` were added to the contract groups during the build.

**Player taking hits:** the player reacts like any actor (flinch, stagger, knockdown). In the test room (`auto_revive`) a KO'd player gets back up after `player_revive_s` (2.5 s) at full health; the real game over comes later. `Tuning.god_mode` still prevents damage.

## Tuning panel, presets and cheats (Milestone 2, Spec §11)

**`Tuning`** (autoload, `game/autoload/tuning.gd`):
- `data: TuningData`, `set_value(property, value)`, `apply(new_data)`, `defaults()` (the shipped values; don't edit).
- `signal changed(property)` after every edit: the TuningData property's name; `&""` after a preset load, a reset or `apply()` (anything may have changed); `"moves/<move id>/<field>"` after a move edit. Code that keeps a tunable re-reads it on `changed`: a training dummy updates `max_health` from `dummy_health` (keeping its share of health) and drops its wind-up-scaled jab after a `dummy_jab` edit. The cameras read theirs (FOV and the rest) every frame.
- `tuning_properties()`: TuningData's exported properties in declaration order, each property-list entry with its `group` and `subgroup`.
- Moves: `move_ids()`; `get_move(id)` returns the loaded, shared MoveData (every `.tres` in `game/combat/moves/`, kept for the session, so edits survive a restart with R). `move_properties()` lists the editable fields, the groups in `MOVE_GROUPS`: frame data, damage and reaction (damage, hitstun, knockback, reaction, tier...), blocking, movement and camera. Hitboxes and combo branches are structure and stay out. `set_move_value(id, field, value)` edits one; `shipped_move_value()` (from a fresh load of the `.tres`), `move_overrides()` (the fields that differ), `reset_move(id)` and `reset_moves()`. An edit applies on the move's next use: move sets and branches reference the same resources, and the rig keys its move animations by frame data, so a startup edit gets a re-timed animation.
- Presets are JSON: `{"preset": name, "format": 2, "tuning": {property: value}, "moves": {id: {field: value}}}`, in TuningData declaration order, with vectors and colors as arrays. A preset holds every TuningData value outside the "Debug" group and only the move fields that differ from the shipped `.tres`.
  - The F4 cheats stay out: `PRESET_SKIPPED_GROUPS` ("Debug": `god_mode`, `one_hit_ko`) is never saved, loaded or reset, so a preset can't turn a cheat on and Reset to default doesn't turn one off. `preset_properties()` lists what a preset holds.
  - Names are lower case and file-safe (`sanitize_preset_name()`), so one name is one file on every OS, including this case-insensitive macOS disk.
  - `save_preset(name)` writes `user_dir/<name>.json` (`user://tuning`). It refuses (`ERR_ALREADY_IN_USE`) the reserved names `default` and `_backup` (`is_reserved_preset_name()`).
  - `export_preset(name)` writes `export_dir/<name>.json` (`res://tuning`, only when running from the project folder). It refuses `default`, in any case, unless every value is the shipped default.
  - `load_preset(name)` reads the user's copy first, then the shipped one; `default` is always the shipped one. `load_preset_file(path)`, `apply_preset(dict)` and `preset_dict(name)` are the parts underneath.
  - Loading starts from the shipped defaults (TuningData and moves), so a value a preset lacks keeps its default. Unknown names, unreadable values and enum ids the hint lacks are skipped; a number past its `@export_range` end is clamped to it (unless `or_greater` / `or_less`). Each is listed in `last_warnings`.
  - A value whose meaning changed is migrated from an older `format` (`_migrate()`, listed in `last_warnings`; a preset with no `format` counts as the current one). Format 2 (M2 phase 3): `dummy_revive_s` counts from the KO's blink-off instead of from the KO, so a format-1 preset saved before the blink-off (it has no `ko_linger_s`) loads its old count less `ko_linger_s` and `ko_blink_s`, at least 0, and the dummy is back as long after the KO as it was. A format-1 preset with `ko_linger_s` was saved since and loads as it is.
  - `backup_unsaved()` writes the current values to the user preset `_backup` when they hold edits no saved, exported or loaded preset holds (`has_unsaved()`). The panel calls it before Load and Reset to default, so loading `_backup` undoes either.
  - `user_dir` and `export_dir` default to `USER_DIR` and `EXPORT_DIR`. The tests point them at a scratch folder of their own run, so they never touch the `user://tuning` that every worktree and Game-boy's own presets share.
  - `reset_to_default()`, `is_default()`, `list_presets()` and `sanitize_preset_name()` complete the API.
  - `res://tuning/default.json` is the shipped defaults. `godot --headless -s tools/gen_default_preset.gd` regenerates it after a TuningData default changes or a tunable is added, and `tests/test_tuning_panel.gd` fails until it matches.

**`TuningOverlay`** (`game/ui/tuning_overlay.gd`/`.tscn`; the test room adds one in `_build_presentation()`):
- It hosts the panel and the cheat menu in one full-screen, transparent, embedded `Window` over the game. Nothing pauses.
- **Input:** an embedded window's input never reaches the game's `_input` / `_unhandled_input` handlers. A click on the panel therefore can't recapture the mouse (`GameInput._input`) or punch, and keys typed into a field don't reach the debug keys. The window covers the screen, so clicks around the menus land on it too.
- **Player:** while open, the live player's `PlayerInput` is switched to scripted, so it gets idle frames with no look. It is switched back `UNFREEZE_TICKS` (2) physics ticks after closing, so the key or button that closed the overlay (gamepad B is also the dodge) never reaches the player. A player that is already scripted (the combo bot, tests) is left alone.
- **Mouse:** released while open, and captured again on closing unless the game is paused.
- **Bindings:** while open, every `GameInput.BINDINGS` action except `tuning_panel` and `cheats` has its events lifted out of the InputMap (and is released); closing puts them back. Code that polls the Input singleton, such as the free-fly camera's arrow and Page keys, therefore stays still while the panel uses those keys.
- **Keys:** F1 / View toggles the panel and F4 the cheat menu, from the game or the window. Esc (`ui_cancel`, also gamepad B) closes both and does not pause. The other debug keys (F2, F3, F5, H) work once the overlay is closed.
- **Gamepad UI:** Godot 4.7's default `ui_accept` and `ui_cancel` have no joypad buttons. The overlay adds A and B to them (`add_gamepad_ui_events()`), so A presses buttons, flips toggles and opens drop-downs, and B closes a drop-down, then the menus.
- **Help:** opening the panel hides the HUD's startup help, which sits where the panel docks. H shows it again.

**`TuningPanel`** and **`TuningField`** (`game/ui/tuning_panel.gd`, `tuning_field.gd`): the panel is docked left, clear of the view center and the combat log.
- **Built from the data:** one category per TuningData `@export_group`, in declaration order, with a row per exported property and a heading per `@export_subgroup` (`Tuning.exported_properties()` records each property's `group` and `subgroup`). New tunables, the M2 VFX, Audio and ragdoll groups included, appear with no UI code; a long group is organized by wrapping its sections in `@export_subgroup`, which renames nothing (presets key on property names).
- **Editors by type:**
  - a ranged number gets a slider plus a number field (the field allows the hint's `or_greater` / `or_less`);
  - a bool gets a toggle that says on or off, and an enum a drop-down;
  - a Vector2 or Vector3 gets one number field per axis, a Color a color button, and a String a text field.
- **Changed values:** a value away from its default turns yellow and lights its "reset". Categories and moves holding one are marked " *".
- **Moves page:** pick a move, edit its `move_properties()`, or reset the move. The picker row sits above the scrolling rows, so it stays in view.
- **Presets:** a name field with Save and Export, a list of presets with Load, and Reset to default, with a status line for the result. Load and Reset first keep unsaved values as `_backup` and say so.
- **Markers:** an edit updates only its own row and category mark; the move markers are rebuilt only on a move edit or a full refresh.
- **Tooltips:** the `##` doc comments, plus the default and the range. They are read from the script source, so an exported build shows only the default and the range.
- **Gamepad:** focus links are set explicitly, never left to where rows happen to line up.
  - The category buttons chain up and down; focusing one shows its page. Right enters the page's first row.
  - A page's rows (sliders, toggles, drop-downs) chain up and down; the first goes up to Load, and the last holds. Left goes back to the category button, except on a slider, where left and right step the value.
  - LB / RB switch to the previous / next category from anywhere in the panel, keeping the focus in the page or in the list.
  - The focused row's name gets a bar behind it.
  - Number fields and vectors take the mouse and keyboard only, because up and down would step them instead of moving on.

**`CheatMenu`** (`game/ui/cheat_menu.gd`, docked top right): a debug tool. Like `TimeController`, it is an exception to "presentation never writes game state". Every action is a public method:
- `set_god_mode()` and `set_one_hit_ko()` set Tuning's "Debug" group, which presets leave out (session state).
- `set_time_scale()` sets `TimeController.debug_scale` to 0.25× or 1×, which also stretches hitstop and slow-mo (see "Time model").
- `spawn_dummy()` places a training dummy at the crosshair (`spawn_point()`), or says "No room" when there is no clear spot:
  - The ray runs from the first-person camera's view center. In side view and free fly (no crosshair) or with no camera, it runs from the player's eye and look. It reaches `spawn_max_distance_m` (6 m) and meets the world and actor bodies.
  - On a body, the spot is `spawn_beside_m` (1 m) to its side, whichever side is clear, so the new dummy stands in view rather than behind it. On a wall, the spot is `spawn_wall_clearance_m` (0.5 m) off it along its normal. On the floor, it's where the ray lands. A ray that meets nothing ends `spawn_open_distance_m` (3 m) out.
  - The spot drops to the floor and stays at least `spawn_min_distance_m` (1 m) from the player.
  - A spot is clear when a capsule the dummy's size overlaps no world geometry, no actor stands within `spawn_actor_clearance_m` (0.7 m), its floor is within `spawn_max_rise_m` of the player's, and the player can see it. Otherwise the nearest clear spot within `spawn_search_radius_m` (2 m) is used, trying beside it first, then toward the player, then behind.
  - The dummy faces the player.
- `reset_dummies()` puts every dummy back on the post recorded when the menu first saw it, standing, at full `dummy_health`. `remove_spawned_dummies()` removes the spawned ones.
- "Skip to arena N" shows disabled until Milestone 5.

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
