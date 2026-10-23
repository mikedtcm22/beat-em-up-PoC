# Milestone 2: hit feel

From SPEC §12: "The full Section 6 stack with placeholder VFX and SFX, plus the tuning panel". **Done when** Game-boy tunes each tier live and saves a preset.

Read SPEC §6 (hit feel) and §11 (tuning panel and debug tools) in full. Branch: `m2/hit-feel` (from `main` after Milestone 1 merged). PR into `main` when done; it is merged only after Game-boy signs off.

## What already exists (from Milestone 1)
- **Simulation:**
  - hitstop per tier (`TimeController.hitstop`, `Tuning.hitstop_*_ms`);
  - finisher slow-mo (`TimeController.slowmo`);
  - the white 2-frame hit flash (`HumanoidRig.set_flash`);
  - flying bodies knock others down.
- **Camera:** camera punch and trauma shake per tier on the first-person camera.
- **Events:** `CombatEvents` emits everything presentation needs: `hit_landed(HitInfo)` with tier, region, contact point, direction and the blocked/perfect/guard-broken flags, plus `attack_whiffed`, `knocked_down`, `ko`, `windup_started/ended`, `blocked`, `perfect_blocked`, `guard_broken`, `health_changed` and more.
- **Placeholders:** the rig and the effects are placeholders. Real art comes in Milestone 4.
- **Missing:** comic VFX, damage looks, audio, rumble, the partial and full ragdoll, the tuning panel, presets and the F4 cheat menu.

## Work packages
Phase 1 runs WP1-WP3 in parallel, each in its own worktree and with disjoint files. Phase 2 is WP4. Phase 3 integrates and reviews.

### WP1: tuning panel, presets, cheats (worktree `.worktrees/m2-tuning`, branch `m2/tuning`)
SPEC §11.

**Panel (F1 / View):**
- An in-game overlay that pauses nothing. It auto-builds sliders, toggles and number fields from `TuningData`'s exported properties (groups, `@export_range` hints, bools), so new tunables appear without UI code.
- Plus a per-move section: pick a move (all `game/combat/moves/*.tres`) and edit its frame data, damage, knockback, hitstun, camera offsets and blocking fields live. These edit the loaded resources, so changes apply on the next use.
- Usable with mouse, and minimally with a gamepad (focus navigation).
- Doesn't capture gameplay input while open: the player stands still, and the mouse is released while open.

**Presets:**
- Save and load named presets as JSON in `user://tuning/`. A preset holds every TuningData value plus the move overrides that differ from the shipped `.tres`.
- "Export" writes `res://tuning/<name>.json` (works when running from the project folder).
- Ship `res://tuning/default.json`, matching the shipped defaults.
- "Reset to default" button.

**Cheats (F4 menu):** god mode, one-hit KOs, spawn a training dummy at the crosshair, time scale 0.25×/1×, and reset dummies. "Skip to arena N" waits for Milestone 5; show it disabled.

**Hooks:** `Tuning.changed` must be emitted for every edit. Anything that caches a value must re-read on change (the camera FOV, for example).

**Owned files:** `game/ui/tuning_*`, `game/ui/cheat_*`, `game/autoload/tuning.gd` (preset I/O may extend it), `tuning/`, `tests/test_tuning_panel.gd`. Wire it into `game/ui/hud.tscn` or the test room only through one small, clearly marked addition.

**Tests:**
- Every exported TuningData property gets a control.
- Editing a slider changes `Tuning.data` and emits `changed`.
- A preset round-trips through JSON, including move overrides.
- The default preset equals the shipped defaults.
- Cheats toggle.

### WP2: comic VFX and damage looks (worktree `.worktrees/m2-vfx`, branch `m2/vfx`)
SPEC §6, "Comic effects", "Damage you can see" and the VFX row of the tier table; SPEC §10, "2D effects".

**Art:** the agent draws as SVG, in `assets/source/fx/`:
- the comic lettering set: 8-10 words (KRAK, WHAM, THUD, CRUNCH, POW, SMAK, BOFF, WHUMP and so on);
- impact bursts in 3 sizes;
- speed lines;
- blood droplets and splats (comic red);
- spit and tooth;
- a parry spark;
- a guard-break burst;
- the rear-warning burst (used in Milestone 3).

Rasterize to 512 px PNGs (`assets/export/fx/`, LFS). Godot's SVG import or a headless Godot script is fine. Log every file in `ASSETS.md`.

**Runtime:** a `VfxDirector` subscribing to `CombatEvents`:
- **Lettering:** spawns at the contact point, billboarded, pops in and fades. Words are picked at random per tier and never twice in a row. Light hits get none or a small word, heavy hits medium, finishers large.
- **Bursts:** small, medium or large per tier.
- **Speed lines:** on finishers and lunges (a screen-space overlay).
- **Impact frame:** a 1-2 frame high-contrast inverted ink flash of the whole screen on finishers, toggled by `Tuning.impact_frame_enabled`.
- **Blood:** comic red droplets and splats on heavy and finisher hits.
- **Head finishers:** spit and tooth particles.
- **Blocks:** a block spark, a distinct parry spark, and a guard-break burst.

**Damage looks:** enemy materials step from clean to bruised to bloodied at 66% and 33% health. Add `HumanoidRig.set_damage_look(level: int)`, the one allowed rig change; keep it to materials.

**Scale:** every size, duration and probability is a new TuningData group "VFX". Respect `screen_shake_intensity` and the photosensitivity toggle.

**Owned files:** `game/fx/*`, `assets/source/fx/*`, `assets/export/fx/*`, `ASSETS.md`, the set_damage_look addition to `game/actors/humanoid_rig.gd`, the "VFX" TuningData group, `tests/test_vfx.gd`.

**Bot and captures:** add VFX acts or reuse existing ones. Judge them from first-person and side-view captures. The red is reserved for blood, the rear warning and finisher accents.

### WP3: audio and rumble (worktree `.worktrees/m2-audio`, branch `m2/audio`)
SPEC §6, "Audio" and the audio and rumble rows.

**Placeholder SFX:** generated by a script, `tools/gen_sfx.gd`. It is GDScript run headless that builds `AudioStreamWAV` buffers (noise, filtered and enveloped, plus tones) and saves them to `.wav` in `assets/export/sfx/` (LFS). It covers:
- whooshes (3+);
- thuds (3+), cracks (3+), crunches (3+);
- a body fall (2+) and a sub thump (2+);
- grunts (several, enemy and player, pitched);
- block clack, parry ting and guard-break crash;
- footstep scuffs (optional).

Log them in `ASSETS.md` as "procedurally generated".

**AudioDirector**, subscribing to `CombatEvents`:
- **Layered one-shots per tier:**
  - Light: whoosh + thud.
  - Heavy: whoosh + thud + crack.
  - Finisher: whoosh + thud + crunch + body fall + sub thump.
- **Variation:** ±8% random pitch and volume, never the same sample twice in a row.
- **Positional:** played at the contact point through a pooled `AudioStreamPlayer3D` set.
- **Reactions:** enemies grunt when hit; missed swings (`attack_whiffed`) get a whoosh and no impact.
- **Blocks:** a block clack, a parry ting and a guard-break crash.
- **Wind-ups:** they play positionally (the rear-warning audio cue, SPEC §8).
- **Music:** a placeholder loop toggle (off by default; an open question in SPEC §13).

**Rumble** (a `RumbleDirector`, which may live in `game/audio/` or `game/fx/`): `Input.start_joy_vibration` per tier. Light is short and low, heavy medium, finisher a strong double pulse; blocks are a light tick. The strength is tunable.

**Tuning:** every volume, variation and rumble value goes in a new TuningData group "Audio".

**Owned files:** `game/audio/*`, `tools/gen_sfx.gd`, `assets/export/sfx/*`, `ASSETS.md` (an audio section only), the "Audio" TuningData group, `tests/test_audio.gd`.

**Tests:** layering per tier, no immediate repeats, the pitch and volume range, positional placement, whiff and block sounds, and rumble calls (stub the Input calls).

### WP4: partial ragdoll and finisher ragdoll (phase 2, after phase 1 merges)
SPEC §6, "Hit reactions".

**Staggers:** blend a partial ragdoll (`PhysicalBoneSimulator3D`, influence 0.3-0.6) over the animation, so bodies physically give way.

**Finishers:** switch to full ragdoll with an impulse at the contact point, then a get-up blend or a KO limp slump. A flying body still knocks standing enemies down.

**Rig path:** follow the path documented in the HumanoidRig class doc. The visual followers read post-modifier global poses, while hurtboxes and `get_point_transform()` keep the pure-animation FK, so hits stay deterministic.

**Integration:** the CombatActor's position follows the ragdoll's hips on get-up. The tunables (influence, impulse scale, blend times) go in TuningData.

**Tests:** hurtboxes are unaffected by the ragdoll; the body comes to rest, gets up and stands; no explosions or jitter (check the captures).

### Phase 3: integration and review
1. Merge WP branches into `m2/hit-feel` and wire everything into the test room.
2. Run the full tests.
3. Record every act and review it as Game-boy would: hit feel per tier, readability, no screen-filling effects in first person.
4. Run an adversarial review, then fix.
5. Update the README (controls: F1 panel, F4 cheats) and ARCHITECTURE.md.
6. Open the M2 PR.
7. Game-boy tunes each tier live, saves a preset, and signs off.
