# First-Person Beat-em-Up (PoC)

One playable level that tests whether a first-person beat-em-up feels good to play. The full design is in [docs/SPEC.md](docs/SPEC.md).

## Play it

```bash
godot --path .
```

This opens the Milestone 1 graybox test room: the player, three training dummies and a pipe. The centre dummy spars: come within 1.7 m in front of it and it steps in and throws a telegraphed jab every couple of seconds, to block (or dodge, or hit it out of its wind-up). To open the editor instead, run `godot --path . -e`.

| Action | Gamepad (Xbox) | Keyboard + mouse |
| --- | --- | --- |
| Move / look | Left stick / right stick | WASD / mouse |
| Punch / kick | X / Y | Left / right mouse |
| Jump | A | Space |
| Block (held) | B with no stick direction | Shift alone |
| Dodge | B + stick direction | Shift + WASD |
| Back elbow | RB | Q |
| Grab, pick up, throw weapon | LB | E |
| Quick turn | Right stick click | Tab |
| Pause (R restarts while paused) | Menu | Esc |
| Cycle camera: first person, side view, free fly | | F2 |
| Debug draw: hitboxes, hurtboxes, magnetism, states | | F3 |
| Time scale 0.25× / 1× (stand-in for the cheat menu) | | F4 |
| Sparring: all three dummies throw jabs / none do | | F5 |
| Controls help | | H |

The free-fly camera moves with the arrow keys and PgUp/PgDn, and turns while you hold the middle mouse button. The player keeps WASD and the mouse.

**Combos:** P P P P · P (pause) P, then mash (body-blow flurry into the shove) · P P (pause) P (spinning backfist) · K K K · K (pause) K · P P K · hold P, then release (haymaker). The pause means waiting about a quarter second after a hit finishes before pressing again.

**Other moves:** Jump + K (flying kick), Jump + K at the top of the jump (spin kick), K next to a downed enemy (stomp), LB next to any standing enemy (not while its strike is out), then P (knee) or K (throw).

**Blocking:** hold B (Shift) with no direction to put the guard up; it stops hits from the front (within 60° of where you look) for a little chip damage and drains the guard meter under your health bar. Raise it on reaction to an attacker's wind-up, up to about a quarter second before the hit, for a perfect block ("PARRY!"): no damage, and the attacker staggers, so you can let go of B and grab it. An empty guard meter breaks the guard. P or K out of the guard attacks at once; pressed while a blocked hit pushes you back, it attacks as soon as the push-back ends. Holding B keeps the block: after a hit, a guard break or an attack out of the guard, the guard comes back up while B is still held (a perfect block needs a fresh press of B). Jump and LB do nothing while the guard is up.

## Milestone 1 status: graybox combat

Every Spec §4 combo and move can be performed and lands on the training dummies, and the side-view debug camera works:
- **Chains:** P P P P, P · P with the flurry mash ending in the shove, P P · P (spinning backfist), K K K, K · K, P P K, and the haymaker.
- **Air moves:** flying kick and spin kick.
- **Grabs:** grab, three knees, then a throw that knocks down whoever the body hits.
- **Other moves:** back elbow, stomp, the pipe (pick up, three swings, break, throw), dodge and quick turn.
- **Hitstop and slow-mo:** both already run on finisher-tier hits.
- **Held block:** guard, chip, guard meter, blockstun and push-back, attacker recoil, guard break and perfect block, against a sparring training dummy's telegraphed jab; the player now takes hits and gets back up after a KO in the test room.
- **Live tuning:** every number lives in `game/autoload/tuning_data.gd` or the move `.tres` files, ready for the Milestone 2 tuning panel.

The characters are procedural placeholders. Real art, VFX and audio come in Milestones 2 and 4.

**Where M1 departs from the spec, for Game-boy to rule on:**
- **Grab anytime (Game-boy's second playtest, a Spec §4 change):** LB grabs any standing enemy in front within reach (free, winding up, in hitstun, staggered or blocking), not only a staggered one. It whiffs while the enemy's strike is out (its active frames) and on bodies that are down, flying or KO'd.
- **Spinning backfist on P P · P, flurry on P · P (Game-boy's second playtest, Spec §4 change):** the pause after the second jab now starts a spinning backfist (a full turn and the back of the right fist, 14 damage, knockdown); the body-blow flurry moved to the pause after the first jab, then mash, still ending in the shove.
- **The view spins with spinning moves (Game-boy's second playtest):** in first person, the spin kick, the spinning heel kick and the spinning backfist turn the view a full circle with the eyes (the head leads the turn, so the view lands on the target at contact) and back onto the heading; aim and hits do not change. Turn it down or off with `cam_spin_follow_mult`. The back elbow turns the view about 150° over the right shoulder (Game-boy asked for 100-120°, which shows neither the elbow nor an enemy straight behind at the 90° field of view) and back.
- **Parry and dodge timing (Game-boy's second playtest):** the guard is up 1 frame after B (was 4), a parry is a hit within 14 frames (about a quarter second) of the press, and the sparring jab winds up for 0.4 s (was 0.3), so a parry works on reaction. B (or Shift) pressed a moment before the stick direction now dodges instead of blocking.
- **Held block (Game-boy-approved addition to Spec §4):** B with no stick direction blocks while held; B + a direction dodges (the backstep is B + back, where the spec's neutral B backstepped). The guard covers 60° either side of the look, chips 15% of the damage and drains a guard meter (guard break when it empties), with a perfect block for a guard raised just in time. Numbers are in the "Block" and "Sparring" groups of `tuning_data.gd`; details in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) "Block". Within its 1.7 m sparring range the sparring dummy steps in to 0.9 m (`sparring_step_in_m`) before it jabs, inside the jab's reach of about 1.05 m, and jabs every 2 s from one jab's start to the next. A guard re-raised by a B that stayed held never parries.
- **Camera position (Game-boy's call after the M1 playtest):** the first-person lens sits at throat height, 20 cm below the eye point and 4 cm ahead of it (`cam_height_offset_m`, `cam_forward_offset_m`, tunable), where the spec has the camera ride the eye. Punches come in from below or the side, the arm running off the edge of the view, and kicks bring the foot and shin into it. Looking down 45 degrees shows the lead hand; the feet stand under the body, below the view's bottom edge at that angle, so the lead shoe comes in from about 60 degrees and the lead leg from about 65 (walking, the striding foot from 55; Mirror's Edge style). The lens used to sit 12 cm ahead to clear the guard's forearms at the chin; the relaxed arms no longer need that, and a lens closer over the body keeps the block guard's forearms 30 cm or more away and the lead foot ahead of it when looking down.
- **Relaxed player stance:** the player stands in a loose "Bruce Lee" stance, arms low until a strike, instead of a boxer's high guard, so nothing of the arms shows while looking ahead. It keeps the guard's body and footing, so strikes move the camera no more than before. The "dukes up" image is the held block's guard (the `block` animation): fists up in the upper corners of the view, forearms rising from the lower corners, the center clear. The dodges keep the stance's arms. Enemies keep the boxer guard. The player's hands are skin-colored, with light wraps and a dark fingerless-glove plate (Spec §10).
- **Enemy hands and guard (after Game-boy's first-person playtest):** at the sparring dummy's 0.9 m step-in, its boxer guard held two oversized fist blocks at the throat-height lens's eye line, covering most of the view through the whole exchange. Enemies now wear dark fingerless gloves (bare fingers at the knuckles, a strap in the accent color) the size of the player's hands, still slightly oversized (Spec §10), and hold them at the chin a hand's width in front of it, the forearms angled in from low elbows; the dummy's jab wind-up and its blocked recoil keep the lead glove on its side of the chin. From the player's lens the face and cap show whole; the gloves cover 7% of the view at the step-in (20% before), the gloves and forearms 17% (35%), and about 9% with the enemy 0.9 m from the lens. The forearms in front of the chest cannot get much smaller at 0.9 m without sinking into the chest or dropping the gloves below the chin; a step-in of about 1.0 m (`sparring_step_in_m`) would bring them to about 12%.
- **Upper body in first person:** the player's head, neck, chest, upper chest, shoulder balls and the shoulder end of each upper arm are hidden from the first-person camera; the elbow end of the upper arm, the forearms and hands, the belly, belt and legs show. Re-checked with the relaxed stance and the new lens: hiding the whole upper arm left a punch's forearm floating mid-view, its rounded elbow end inside the frame, while showing all of it let the shoulders sweep across the view on every twist (two fifths of it on a spinning heel or a spin kick). Hiding only the shoulder end keeps both right: a jab covers about a quarter of the view and the spins under a sixth. The chest is still hidden (it swept across half the view on every twist), so the belly has a rounded top for looking steeply down. The hidden parts still cast shadows and show in the side and free-fly views. The spec says the full body renders in first person; its fallback (a first-person-only arm pose) can replace this once real art exists.
- **Clinch:** a held enemy bends over further than before, so its head sits just under the throat-height view instead of filling it. A grab eases the victim in from where it stood while it bends over, head first, so its head and shoulders never sweep through the lens; released on its feet, it stands up around its hips, away from the holder.
- **Flying kick:** it dives forward and down, and its camera pitches down 25° (like the stomp) instead of the 8–12° of the standing kicks. From the air, a foot at hip height passed over a standing enemy's head.

**Where M2 departs from the spec (approved by Game-boy on 2026-10-23 and 2026-10-24):**
- **The 0.25x cheat slows the hit feel too (Spec §11):** the F4 time scale stretches hitstop and the finisher slow-mo as well as the simulation, so a slowed-down hit keeps its feel, only slower. Camera punch and shake stay at full speed.
- **Cheats stay out of presets (Spec §11):** god mode and one-hit KOs are session state. Saving, loading or resetting a preset skips the "Debug" group, so a preset never turns a cheat on, and loading one never turns a cheat off.
- **The white hit flash is localized (Spec §6, approved 2026-10-24):** on contact, the victim flashes white only around the point the hit landed instead of over the whole body. It is full white at the contact point and fades out by a radius (default about 0.25 m, about a head's width), at a strength you can set. Both are in the "Hit feel" tuning group, and a large radius brings back the whole-body flash. At 1 m in first person, the whole-body flash turned 27-36% of the view white on a jab.

**Automated checks:**
- `tools/run_tests.sh` runs 297 tests headless in about 13 seconds, including an end-to-end suite where a scripted player performs every combo in the real test room.
- `tools/capture_combos.sh` records the combo bot with Movie Maker to `captures/combos.avi`, writes a hit log to `captures/bot.log`, and extracts stills for review. Pass text to run only matching acts, for example `tools/capture_combos.sh "haymaker"`.

## Repo layout

```
/project.godot           Godot 4.7 project (GDScript, Forward+, Jolt, 60 Hz physics)
/addons/gut/             GUT 9.7.1 unit-test framework (vendored)
/game/autoload/          CombatEvents, TimeController, Tuning
/game/player/            player scene and scripts
/game/enemies/           one folder per archetype + shared AI
/game/combat/            move resources, hit/hurtboxes, combo parser
/game/camera/            first-person and debug cameras
/game/fx/                toon shader, outlines, VFX scenes, comic sprites
/game/audio/             SFX banks
/game/level/             level scene, modules, encounter data
/game/ui/                HUD, combat log, debug draw, overlays
/game/actors/            CombatActor base and the placeholder humanoid rig
/game/weapons/           pick-up weapons (the pipe)
/assets/source/          .blend, raw generator output, mocap, SFX (LFS)
/assets/export/          .glb files ready for Godot (LFS)
/reference/dd2-nes-mission1/   level reference screenshots + notes
/tests/                  unit tests (run headless)
/tools/                  Blender batch scripts, pipeline scripts
/tuning/                 exported tuning presets
/docs/                   spec and design notes
ASSETS.md                source, service and license for every asset
```

Binary assets (`.glb .blend .fbx .png .jpg .wav .ogg` and others) are stored with Git LFS. See `.gitattributes`.

## API keys

Keys go in `.env` at the repo root. `.env` is git-ignored. `.env.example` lists the variable names. This table records which keys exist, never their values.

| Variable | Service | Present |
| --- | --- | --- |
| none yet | | |

## Toolchain status (Milestone 0)

Checked on 2026-10-21 on the dev Mac (Apple M1, macOS 26.3).

| Tool | Status | Notes |
| --- | --- | --- |
| Godot 4 (standard) | ✅ 4.7.2 | Installed via Homebrew; `godot` is on PATH. Headless import and tests work. |
| Blender + Blender MCP | ❌ missing | Not installed, and no Blender MCP is connected to Claude. |
| Git | ✅ 2.50.1 | |
| Git LFS | ✅ 3.8.0 | Initialized for this repo only. |
| GitHub CLI | ✅ 2.93.0 | Logged in as `mikedtcm22`. |
| 3D generation API | ❌ no key | |
| Image generation API | ❌ no key | |
| Mixamo | ❓ unknown | Needs Game-boy's Adobe account. |
| Video mocap | ❓ unknown | |
| SFX library / API | ❌ missing | `assets/source/sfx/` is empty. |
| GUT (unit tests) | ✅ 9.7.1 | Vendored in `addons/gut/`. |
| Movie Maker capture | ✅ works | Records at about half real-time speed on the M1; `tools/capture_combos.sh`. |
| Gamepad | ❓ unknown | |
| ffmpeg | ✅ installed | Useful for audio and capture processing. |
| GPU | ⚠️ Apple M1 integrated | The spec asks for a dedicated GPU and targets an RTX 3060 on Windows. Development works on Metal, but the performance target and Windows export need a Windows test machine. |

## Running tests

```bash
tools/run_tests.sh
```

Runs every `tests/test_*.gd` file headless with GUT and exits non-zero on failure. Pass extra GUT flags through, for example `tools/run_tests.sh -gselect=test_combo_parser`.

Folders containing a `.gdignore` file (`reference/`, `docs/`, `assets/source/`, `tools/`) are skipped by Godot's importer.
