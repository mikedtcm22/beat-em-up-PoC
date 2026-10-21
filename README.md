# First-Person Beat-em-Up (PoC)

One playable level that tests whether a first-person beat-em-up feels good to play. The full design is in [docs/SPEC.md](docs/SPEC.md).

## Repo layout

```
/project.godot           (added once Godot is installed)
/game/autoload/          CombatEvents, TimeController, Tuning
/game/player/            player scene and scripts
/game/enemies/           one folder per archetype + shared AI
/game/combat/            move resources, hit/hurtboxes, combo parser
/game/camera/            first-person and debug cameras
/game/fx/                toon shader, outlines, VFX scenes, comic sprites
/game/audio/             SFX banks
/game/level/             level scene, modules, encounter data
/game/ui/                HUD, tuning panel
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
| Godot 4 (standard) | ❌ missing | Not on PATH or in /Applications. Homebrew offers 4.7.2. |
| Blender + Blender MCP | ❌ missing | Not installed, and no Blender MCP is connected to Claude. |
| Git | ✅ 2.50.1 | |
| Git LFS | ✅ 3.8.0 | Initialized for this repo only. |
| GitHub CLI | ✅ 2.93.0 | Logged in as `mikedtcm22`. |
| 3D generation API | ❌ no key | |
| Image generation API | ❌ no key | |
| Mixamo | ❓ unknown | Needs Game-boy's Adobe account. |
| Video mocap | ❓ unknown | |
| SFX library / API | ❌ missing | `assets/source/sfx/` is empty. |
| Gamepad | ❓ unknown | |
| ffmpeg | ✅ installed | Useful for audio and capture processing. |
| GPU | ⚠️ Apple M1 integrated | The spec asks for a dedicated GPU and targets an RTX 3060 on Windows. Development works on Metal, but the performance target and Windows export need a Windows test machine. |

## Running tests

Will be added with the Godot project skeleton (Milestone 0).
