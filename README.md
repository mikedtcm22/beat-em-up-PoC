# First-Person Beat-em-Up (PoC)

One playable level that tests whether a first-person beat-em-up feels good to play. The full design is in [docs/SPEC.md](docs/SPEC.md).

## Play it

```bash
godot --path .
```

This opens the Milestone 1 graybox test room: the player, three training dummies and a pipe. To open the editor instead, run `godot --path . -e`.

| Action | Gamepad (Xbox) | Keyboard + mouse |
| --- | --- | --- |
| Move / look | Left stick / right stick | WASD / mouse |
| Punch / kick | X / Y | Left / right mouse |
| Jump / dodge | A / B (+ stick) | Space / Shift (+ WASD) |
| Back elbow | RB | Q |
| Grab, pick up, throw weapon | LB | E |
| Quick turn | Right stick click | Tab |
| Pause (R restarts while paused) | Menu | Esc |
| Cycle camera: first person, side view, free fly | | F2 |
| Debug draw: hitboxes, hurtboxes, magnetism, states | | F3 |
| Time scale 0.25× / 1× (stand-in for the cheat menu) | | F4 |
| Controls help | | H |

The free-fly camera moves with the arrow keys and PgUp/PgDn, and turns while you hold the middle mouse button. The player keeps WASD and the mouse.

**Combos:** P P P P · P P (pause) P, then mash · K K K · K (pause) K · P P K · hold P, then release (haymaker). The pause means waiting about a quarter second after a hit finishes before pressing again.

**Other moves:** Jump + K (flying kick), Jump + K at the top of the jump (spin kick), K next to a downed enemy (stomp), LB on a staggered enemy, then P (knee) or K (throw).

## Milestone 1 status: graybox combat

Every Spec §4 combo and move can be performed and lands on the training dummies, and the side-view debug camera works:
- **Chains:** P P P P, P P · P with the flurry mash ending in the shove, K K K, K · K, P P K, and the haymaker.
- **Air moves:** flying kick and spin kick.
- **Grabs:** grab, three knees, then a throw that knocks down whoever the body hits.
- **Other moves:** back elbow, stomp, the pipe (pick up, three swings, break, throw), dodge and quick turn.
- **Hitstop and slow-mo:** both already run on finisher-tier hits.
- **Live tuning:** every number lives in `game/autoload/tuning_data.gd` or the move `.tres` files, ready for the Milestone 2 tuning panel.

The characters are procedural placeholders. Real art, VFX and audio come in Milestones 2 and 4.

**Where M1 departs from the spec, for Game-boy to rule on:**
- **Camera position (Game-boy's call after the M1 playtest):** the first-person lens sits at throat height, 20 cm below the eye point and 4 cm ahead of it (`cam_height_offset_m`, `cam_forward_offset_m`, tunable), where the spec has the camera ride the eye. Punches come up into the view from below, and looking down shows the lead hand and foot (Mirror's Edge style). The lens used to sit 12 cm ahead to clear the guard's forearms at the chin; the relaxed arms no longer need that, and a lens closer over the body keeps the lead foot in view when looking down.
- **Relaxed player stance:** the player stands in a loose "Bruce Lee" stance, arms low until a strike, instead of a boxer's high guard, so nothing of the arms shows while looking ahead. The boxer guard ("dukes up") shows only on the neutral dodge (the backstep, and the forward dodge). Enemies keep the boxer guard. The player's hands are smaller and skin-colored, with light wraps and a dark fingerless-glove plate (Spec §10).
- **Upper body in first person:** the player's head, neck, chest, shoulders and upper arms are hidden from the first-person camera. Re-checked with the relaxed stance and the new lens, the hiding is still needed: the upper arm starts right beside the lens, so showing it doubles a punch's share of the screen (a jab goes from about 12% to 25%), and the chest boxes sweep across half the view whenever the torso twists (spinning heel, spin kick). The belly, belt and legs stay visible when looking down. The hidden parts still cast shadows and show in the side and free-fly views. The spec says the full body renders in first person; its fallback (a first-person-only arm pose) can replace this once real art exists.
- **Clinch:** a held enemy bends over further than before, so its head sits just under the throat-height view instead of filling it.
- **Flying kick:** it dives forward and down, and its camera pitches down 25° (like the stomp) instead of the 8–12° of the standing kicks. From the air, a foot at hip height passed over a standing enemy's head.

**Automated checks:**
- `tools/run_tests.sh` runs 236 tests headless in about 5 seconds, including an end-to-end suite where a scripted player performs every combo in the real test room.
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
