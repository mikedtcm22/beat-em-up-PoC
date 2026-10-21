# First-Person Beat-em-Up — Proof-of-Concept Spec

Oct 21, 2026 · @Game-boy

## 1. Overview

Build one playable level that proves a first-person beat-em-up feels great: easy cadence combos, fast crowd fights, and hits that land like comic-book bone-crunchers. Under the hood it plays like a classic belt-scroller; the player simply sees it through the hero's eyes.

**Concept.** Double Dragon and Streets of Rage combat, seen through a GoPro on the hero's head, with no guns. Enemies are individually easy. The skill is situational awareness: don't let them get behind you.

**What the PoC must prove**

1. Landing a combo feels visceral: enemies visibly buckle, crumple and fly.
2. Fighting 4–6 enemies at once in first person is readable and fun, not frustrating.
3. Combos are easy to discover: a new player lands a finisher in the first minute by mashing one button.
4. Agent-generated cel-shaded art holds up with an enemy one meter from the camera.

**Non-goals:** co-op, menus beyond start/pause/restart, saves, progression, cutscenes, story, multiple levels, console or online builds, and music beyond a placeholder loop.

**IP rules.** NES Double Dragon II's Mission 1 is a layout and pacing template only. Every character, name, enemy design, line of dialogue, sound and piece of art is original. Never copy, trace or sample anything from a Double Dragon game.

**Numbers are starting points.** Every value in this spec is a tunable default exposed in the tuning panel (Section 11). Game-boy (the project owner) tunes by feel; the agent treats the values as placeholders, not requirements.

## 2. Toolchain and setup

Game-boy sets up everything in the table below; the agent's first task (Milestone 0) is to verify each item and report what is missing. AI tools change quickly, so confirm current APIs and pricing before signing up.

| Tool | Used for | Game-boy sets up | Agent needs |
| --- | --- | --- | --- |
| Godot 4 (latest stable 4.x, standard build, not .NET) | Engine | Install; put the `godot` executable on PATH | Runs `godot --version`, headless imports and tests from the command line |
| Blender 4.x + Blender MCP | Modeling, cleanup, rigging, export | Already set up; confirm the MCP add-on is enabled and `blender` is on PATH | MCP for interactive work; `blender --background --python` for batch scripts |
| Git + Git LFS | Version control for code and binary assets | Install Git LFS; create the repo | LFS tracking for .glb, .blend, .fbx, .png, .wav, .ogg |
| 3D generation service: Hyper3D Rodin, Meshy or Tripo (pick one) | Image-to-3D characters, weapons, props | Account, credits, API key | API key in `.env`; prefer whichever service the installed Blender MCP already integrates |
| Image generation API | Concept art, palette and texture references | Account and API key | API key in `.env` |
| Mixamo (free Adobe account) | Auto-rigging humanoids; base animation library | Account. Mixamo has no official API, so Game-boy uploads and downloads by hand, or with a browsing agent such as Claude in Chrome | Prepares upload-ready FBX files and an exact list of animations to download; ingests the results |
| Video-to-mocap: Move.ai, Rokoko Vision or DeepMotion (pick one) | Custom strikes Mixamo lacks | Account; film each move on a phone; export FBX into `/assets/source/mocap/` | Cleans, trims and retargets the clips |
| Sound effects: Sonniss GDC Game Audio Bundle (free, royalty-free) and/or an AI sound-effects API such as ElevenLabs | Impact layers, whooshes, grunts, ambience | Download the library to `/assets/source/sfx/`, or add an API key | Folder path or API key |
| Gamepad (Xbox layout) | Playtesting | Plug one in | Nothing |
| Optional: a community Godot MCP server | Lets the agent drive the editor and read debug output | Install only if the command-line loop proves limiting | Server connection |

**Keys and secrets.** Store all API keys in `.env` at the repo root and list `.env` in `.gitignore`. Use each service SDK's standard variable name and record which ones exist in `README.md`, never their values.

**Hardware.** Use a machine with a dedicated GPU so Godot can render captures and Blender can bake.

## 3. Architecture

The game simulates a full 3D brawler in world space, and the first-person camera is only a viewpoint into it. No combat logic may read the camera.

&#91;embedded content: architecture · simulation, event bus, presentation\]

The simulation emits events and never looks at a camera; everything the player sees and hears subscribes to those events, and only TimeController reaches back to pause or slow the simulation.

**Simulation layer (camera-agnostic)**

- Player and enemies are `CharacterBody3D` nodes with full humanoid skeletons, hurtboxes per body region (head, torso, legs) and hitboxes on striking limbs.
- Hitboxes are active only during a move's active frames.
- Combat runs on a fixed 60 Hz physics tick in `_physics_process`; all timing is measured in frames at 60 Hz.
- Moves are data: each is a Resource (`.tres`) holding startup/active/recovery frames, damage, hitstun, knockback vector, reaction type, hitstop tier, cancel window, combo branches and camera offsets. No attack numbers are hardcoded in scripts.
- An encounter manager owns arena locks, waves and spawns (Section 9).

**Presentation layer (reads only)**

- First-person camera (Section 5), plus two debug cameras: a classic side-on belt-scroller view and a free-fly camera. All three can be switched mid-fight.
- VFX, audio, rumble, HUD and the rear-attack warning.
- Presentation reads poses and transforms and subscribes to a `CombatEvents` autoload (signals such as `hit_landed`, `windup_started`, `knocked_down`, `ko`). It never writes game state.
- The one exception is time: hitstop and slow-mo go through a single `TimeController` autoload that pauses or scales simulation time.

**Engine settings:** GDScript with static typing, Forward+ renderer, Jolt physics.

**Repo layout**

```
/project.godot
/game/autoload/      CombatEvents, TimeController, Tuning
/game/player/        player scene and scripts
/game/enemies/       one folder per archetype + shared AI
/game/combat/        move resources, hit/hurtboxes, combo parser
/game/camera/        first-person and debug cameras
/game/fx/            toon shader, outlines, VFX scenes, comic sprites
/game/audio/         SFX banks
/game/level/         level scene, modules, encounter data
/game/ui/            HUD, tuning panel
/assets/source/      .blend, raw generator output, mocap, SFX (LFS)
/assets/export/      .glb files ready for Godot (LFS)
/reference/dd2-nes-mission1/   Game-boy's screenshots and notes
/tests/              unit tests (GUT or gdUnit4)
/tools/              Blender batch scripts, pipeline scripts
ASSETS.md            source, service and license for every asset
```

## 4. Controls and moveset

Two attack buttons drive everything: mashing one button always produces a full combo, and rhythm unlocks the variants, Devil May Cry style. Gamepad comes first; keyboard and mouse must also work.

| Action | Gamepad (Xbox layout) | Keyboard + mouse |
| --- | --- | --- |
| Move | Left stick | WASD |
| Look | Right stick | Mouse |
| Punch | X | Left mouse |
| Kick | Y | Right mouse |
| Jump | A | Space |
| Dodge | B | Shift |
| Back attack | RB | Q |
| Grab / pick up / throw weapon | LB | E |
| Quick turn (180° in 0.2 s) | Right stick click | Tab |
| Pause | Menu | Esc |
| Tuning panel | View | F1 |
| Cycle camera (debug) | none | F2 |

Movement is brisk, Doom-style: 6 m/s in every direction, no sprint button.

**Cadence rules**

- Inputs buffer for 8 frames, so an early press still counts.
- Pressing again during a move's recovery continues the chain.
- Waiting 12–30 frames after recovery ends, then pressing, takes the **pause branch** (written `·` below).
- Waiting longer resets to the first hit.
- The last hit of every chain is a **finisher**: it triggers the finisher tier of the hit-feel stack (Section 6).

**Combos** (P = punch, K = kick)

| Input | Moves | Damage | Finisher effect |
| --- | --- | --- | --- |
| P P P P | Jab, jab, hook, uppercut | 6, 6, 8, 12 | Launches the target into a knockdown |
| P P · P (mash) | Jab, jab, body-blow flurry ending in a shove | 6, 6, 2 per hit, 6 | Shove sends the target staggering into others |
| K K K | Front kick, roundhouse, spinning heel kick | 8, 10, 14 | Wide arc hits everyone in front; knockdown |
| K · K | Front kick, then a straight stomp kick | 8, 16 | Sends the target flying; anyone it hits falls too |
| P P K | Jab, jab, push kick | 6, 6, 10 | Heavy knockback that clears space |
| Hold P 0.4 s, release | Haymaker | 18 | Breaks Bruiser armor; heaviest hitstop |

**Other moves**

| Move | Input | Damage | Notes |
| --- | --- | --- | --- |
| Flying kick | Jump, then K | 12 | Lunges up to 2 m |
| Spin kick | Jump, then K at the jump's peak | 10 each | Hits all around (360°): the escape when surrounded |
| Back elbow | RB | 12 | Hits directly behind without turning; knockdown |
| Grab | LB next to a staggered enemy | 0 | Holds the enemy in front of you |
| Knee (while holding) | P | 6 each, up to 3 | Third knee releases into a stagger |
| Throw (while holding) | K | 15 | Thrown in the stick direction; knocks down anyone hit |
| Dodge | B + stick direction | 0 | 3 m sidestep or backstep, invulnerable for 8 frames, cancels recovery |
| Stomp | K next to a downed enemy | 8 | Ground hit |
| Weapon swings | P while holding a weapon | 10 each, 3-hit chain | Weapon breaks after 8 hits; LB throws it for 15 |

Player health is 100. A single knockdown should never take more than 15% of it, except from the boss.

## 5. First-person presentation

The camera rides the player character's head, so every strike the player sees is the same full-body animation the side-view debug camera shows. There is no separate set of floating first-person arms.

**Body and camera**

- The full player body renders in first person. Head and neck meshes sit on their own render layer, hidden from the first-person camera but still casting shadows.
- The camera follows an eye-height marker on the head bone with damped smoothing (about 0.05 s) and stays steady. Vertical bob is clamped to ±1.5 cm while walking.
- Camera rotation comes only from look input, never from the head bone. The exception is per-move camera offsets stored in the move resource.
- **Kicks:** during startup the camera pitches down 8–12° and drops 5 cm so the kicking leg enters the frame, then eases back during recovery.
- **Fallback:** if punches read poorly from the eye position, add a first-person-only additive pose layer that nudges the arms toward screen center. It must never move hitboxes.
- Field of view is 90° horizontal by default, adjustable from 75° to 110°. The near clip plane is 0.05 m.

**Target magnetism (no hard lock-on)**

- When an attack starts, pick the enemy closest to screen center within a 35° half-angle cone and 2.5 m range.
- During startup, lunge toward that enemy by up to 0.8 m and turn the body up to 15° toward it. The camera follows the turn smoothly.
- With no enemy in the cone, the attack goes straight ahead and whiffs cleanly.

**HUD**

- Keep the top-left and top-right corners clear for the rear-attack warning (Section 8).
- Player health sits bottom-left and boss health bottom-center, both styled as comic panels.
- An enemy shows a small health bar over its head for 2 s after taking a hit.
- A small center dot anchors aim and can be toggled off.

**Comfort options:** screen-shake intensity, field of view, and an impact-frame toggle (Section 6).

## 6. Hit feel

Every hit runs the same impact stack, scaled by one of three tiers set in the move resource. This is the section the PoC lives or dies on, so every value is live-tunable.

| Element | Light (first hits of a chain) | Heavy (chain middles, back elbow, throws) | Finisher (last hit of a chain, haymaker) |
| --- | --- | --- | --- |
| Hitstop (attacker and victim freeze) | 50 ms | 85 ms | 140 ms |
| Camera punch toward the impact | 0.5° | 1.5° | 3° |
| Screen shake (trauma added, 0–1) | 0.1 | 0.25 | 0.5 |
| Slow-mo after hitstop | none | none | 0.3× speed for 250 ms |
| Victim reaction | Additive flinch | Directional stagger + partial ragdoll | Full ragdoll launch, then get-up or KO |
| Comic VFX | Small burst | Medium burst + lettering | Large burst + lettering + speed lines + impact frame |
| Audio layers | Whoosh + thud | Whoosh + thud + crack | Whoosh + thud + crunch + body fall + sub thump |
| Controller rumble | Short, low | Medium | Strong double pulse |

**Hit reactions**

- The reaction is chosen by hit direction and body region: the head snaps back or sideways, the gut folds, the legs buckle.
- Staggers blend a partial ragdoll over the animation (`PhysicalBoneSimulator3D`, influence 0.3–0.6) so bodies physically give way.
- Finishers switch to full ragdoll with an impulse at the contact point. A flying body that hits a standing enemy knocks that enemy down too.
- KO'd enemies go limp and slump instead of freezing. Bodies stay until the arena clears, then fade out.
- On contact, the victim's toon shader flashes white for 2 frames.

**Damage you can see**

- Enemy materials step from clean to bruised to bloodied at 66% and 33% health.
- Head finishers throw comic spit and tooth particles.
- Blood is comic-style red droplets and splats, with no dismemberment.

**Comic effects**

- **Lettering:** words such as KRAK, WHAM, THUD, CRUNCH and POW spawn at the contact point. They face the camera, pop in, and are picked at random per tier without repeating twice in a row.
- **Speed lines:** radial lines on finishers and lunges.
- **Impact frame:** a 1–2 frame high-contrast inverted ink flash of the whole screen on finishers. It is on by default with an off toggle for photosensitive players.

**Audio**

- Every hit is layered one-shots with ±8% random pitch and volume, never the same sample twice in a row, played positionally at the contact point.
- Enemies grunt when hit.
- Missed swings get a whoosh and no hitstop.

## 7. Enemies and AI

Enemies go down fast, telegraph clearly and spend most of their time posturing. The danger is numbers, and enemies that slip behind you.

| Archetype (original designs) | Role | Health | Attacks | Behavior |
| --- | --- | --- | --- | --- |
| Street Punk | Basic grunt, most common | 30 (one P P P P combo) | Two-hit punch, shove (6 each) | Approaches head-on |
| Kicker | Fast flanker | 25 | Jump kick, low sweep (8) | Actively circles to the player's blind side |
| Pipe Thug | Weapon carrier | 35 | Three-swing pipe combo (10) | Drops the pipe on knockdown for the player to take |
| Bruiser | Heavy | 80 | Grab and headbutt, overhead smash (15) | Armored: ignores light hits, staggers on heavy hits and the haymaker |
| Boss (name and design to be decided) | Level boss | 300, two phases | Shoulder charge, grab slam, ground pound (15–25) | At 50% health turns faster and calls in two Street Punks |

**Behavior states**

1. **Enter:** walk in from a level spawn point.
2. **Approach:** pathfind to a posture ring 2.5–4 m from the player.
3. **Posture:** circle, strafe and taunt while waiting for an attack token.
4. **Wind-up:** a readable pose plus a vocal cue. At least 18 frames (0.3 s) for grunts and at least 30 frames for the Bruiser and boss.
5. **Attack**, then **recover** and return to Posture.
6. **Hit reactions** interrupt states 3–5: hitstun, stagger, or knockdown followed by a get-up after 1.0–1.5 s with brief invulnerability.
7. **KO:** limp slump (Section 6).

Light hits interrupt grunt wind-ups but not Bruiser or boss wind-ups.

**Director rules**

- **Attack tokens:** at most 3 enemies attack at once (tunable; 0 = unlimited). The rest posture.
- **Blind-spot priority:** an enemy outside the player's view gets token priority. Letting enemies behind you must be genuinely dangerous.
- **Spread:** posturing enemies spread around the player instead of bunching in front.
- **Spawns:** at most 6 enemies alive at once. Spawn points sit in doorways, alleys, vehicles and stairwells, and some arenas spawn enemies behind the player.
- **Movement:** `NavigationAgent3D` on a baked navmesh, with avoidance so enemies don't overlap.

**Enemy damage to the player:** listed per archetype above, against the player's 100 health.

## 8. Rear-attack warning

A small comic-style flash in the top-left or top-right corner fires when an enemy the player can't see starts winding up an attack. It is the only off-screen aid; staying aware is the player's job.

- **Trigger:** the enemy enters Wind-up while outside the player's view (more than 55° from camera forward) and within its attack range + 1 m.
- **Side:** behind-left flashes top-left and behind-right flashes top-right. Within ±20° of directly behind, both corners flash.
- **Timing:** the flash appears at wind-up start, so warning time equals wind-up length (0.3 s for grunts by default). It ends when the attack lands or is interrupted.
- **Look:** a small jagged comic alert burst in red-orange that pulses twice. The Bruiser and boss get a larger burst.
- **Several attackers:** each corner shows one burst at a time; it pulses brighter with more attackers on that side.
- **Audio:** the wind-up's grunt and whoosh play positionally, so the player can also hear the direction.
- **Tunable:** angle threshold, burst size, opacity, and audio on/off.

## 9. Level: NES Double Dragon II, Mission 1

The level copies Mission 1's layout and pacing, not its art or characters, converted from a side-scrolling strip into a 3D street the player walks down.

**Reference.** Game-boy puts screenshots in `/reference/dd2-nes-mission1/`, one per screen of the mission in order, numbered `01.png`, `02.png` and so on. A `notes.md` beside them lists enemies, pickups and hazards per screen. The reference decides layout, pacing and enemy counts. This section decides how they convert to 3D.

**Do not build from memory.** If the reference folder is empty when Milestone 5 starts, stop and ask Game-boy. A remembered layout will be wrong.

**Converting 2D to 3D**

| In the NES original | In this game |
| --- | --- |
| Scrolling strip | A 3D lane 10–14 m wide; one NES screen ≈ 12–16 m of walkable length |
| Walking up and down the screen | Lane width; background buildings become walls and set dressing |
| Screen stops scrolling until enemies are cleared | Arena lock: a barrier closes ahead and behind (rolling shutter, chain-link gate, parked car). It opens on wave clear with a comic "GO →" cue |
| Enemies walking in from the screen edges | Spawn points in doorways, alleys, vehicles and stairwells, sometimes behind the player |
| Pits, ledges and hazards | Real drop-offs and hazards; enemies knocked into them are instantly KO'd |
| Weapons on the ground | The same spots, with original weapon designs |
| Boss fight at the end | A locked boss arena about 20 × 20 m |
| Background art | Original set dressing in this spec's art style; the location type follows the reference |

**Encounter plan.** Before building, the agent turns the reference into an encounter table in `/reference/encounters.md`, with one row per arena: location, enemy mix, spawn points, pickups and hazards. Game-boy approves the table before the level is built.

**Difficulty ramp.** Open with two Street Punks, build to one crowd arena of 5–6 mixed enemies, then the boss with adds. A first run should last 8–12 minutes. Where the reference's counts differ, keep its arena order and adjust counts toward this ramp.

## 10. Art direction and asset pipeline

The look is cel-shaded comic: bold ink outlines, two- or three-band toon lighting, flat palettes and comic-book impact effects. Visual references are Hi-Fi Rush and Borderlands, plus MadWorld for how far red can carry violence in a limited palette.

**Style rules**

- **Proportions:** stylized and chunky, with slightly oversized hands and feet. Silhouettes must read at a glance from 2–10 m.
- **Faces:** covered or simplified with sunglasses, bandanas, masks, hockey masks or caps pulled low. Faces must hold up at 1 m from the camera.
- **Color:** 4–6 flat colors per character on a shared palette atlas. Environments are muted and enemies saturated so they pop.
- **Red** is reserved for blood, the rear-attack warning and finisher accents.
- **Period:** late-1980s street gangs (denim, leather, mohawks, track suits), all original designs.
- **Player:** arms (wrapped hands, fingerless gloves), legs and shoes are on screen constantly, so they get the highest detail budget.

**Rendering**

- **Toon shader** (Godot shading language): ramp-based 2–3 band diffuse, a hard specular highlight, rim light, and tinted shadows rather than black. One shader for everything, with per-material parameters.
- **Character outlines:** an inverted-hull outline pass on characters and props, its width scaled with distance so close enemies don't get thick lines.
- **Environment lines:** a screen-space edge-detection post-process using depth and normals.
- **Post-processing:** an optional halftone dot pattern in shadows and a color-grading LUT. No bloom except on VFX.
- **Performance target:** 1080p at 60 fps or better on an RTX 3060-class GPU with 6 enemies on screen.

**Pipeline per character or prop**

1. **Concept:** generate 2–4 concept images with the image API; Game-boy picks one.
2. **Generate:** create the mesh with the 3D generation service, image-to-3D from the chosen concept, in a T-pose or A-pose.
3. **Clean up in Blender** (scripted where possible):
   - Scale to meters (player 1.8 m tall), apply transforms and fix normals.
   - Remesh or decimate to budget, and split the player's head into its own mesh.
   - UV to the palette atlas and replace generated textures with flat palette colors, since baked-in lighting fights the toon shader.
4. **Rig:** export an FBX for Mixamo auto-rigging (Game-boy runs the upload and download). Alternatively use the 3D service's auto-rigger if it outputs a standard humanoid skeleton.
5. **Animate:** take the base set from Mixamo and custom strikes from video mocap. Trim clips, set loop points and strip root motion (animations play in place; code drives movement).
6. **Export:** save `.glb` files to `/assets/export/` and import them into Godot with the humanoid skeleton profile, so every character shares retargeted animations.
7. **Log:** record the source, service and license of every asset in `ASSETS.md`.

| Asset | Triangle budget | Textures |
| --- | --- | --- |
| Player body, including arms | 30k | Palette atlas + 1k detail mask |
| Boss | 30k | Shared palette atlas |
| Enemy | 15k | Shared palette atlas |
| Environment module | 5k | 2k trim sheet |
| Weapon or prop | 3k | Shared palette atlas |

**Animation list**

- **Player:** locomotion (idle, walk in 8 directions, backpedal), every move in Section 4, hit reacts, knockdown and get-up, and holding and throwing a grabbed enemy.
- **Enemies:** idle and posture, walk and circle, each attack with a distinct wind-up, hit reacts (head left, right and front; gut; legs), knockdowns forward and back, get-up, KO slump, being held and being thrown.

**2D effects.** The agent draws the comic lettering set (8–10 words), impact bursts in three sizes, speed lines, droplets, splats and the rear-warning burst as SVG. It rasterizes them to 512 px PNGs, which keeps edges crisp without an image API.

## 11. Tuning panel and debug tools

The agent can't feel the game, so Game-boy tunes it. Every tunable value lives in one `Tuning` resource and is editable live in-game, with no restart.

**Tuning panel (F1 / View button)**

- **Sliders, grouped by section:**
  - Hit feel: hitstop, camera punch and shake per tier, slow-mo speed and duration.
  - Camera and moves: magnetism cone, range, lunge and turn; combo windows; per-move frame data and damage.
  - Enemies: attacker cap, blind-spot priority, wind-up multiplier.
  - Rear warning: angle, size and opacity.
  - Display: field of view.
- **Presets:** save and load values as JSON in `user://`, export them to `res://tuning/` presets, and ship a `default` preset.

**Debug cameras (F2):** cycle first-person, side-view belt-scroller and free-fly cameras. Gameplay keeps running in all three.

**Debug draw (F3):** active hitboxes in red, hurtboxes, the magnetism cone, each enemy's AI state over its head, and who holds attack tokens.

**Cheats (F4):** god mode, one-hit KOs, spawning any enemy at the crosshair, skipping to arena N, and time scale at 0.25× or 1×.

**Combat log overlay:** the last 10 hits with move, damage and frame timing, so Game-boy can report precise combo-timing problems.

**Automated checks**

- Unit tests (GUT or gdUnit4) for the combo parser and move data, runnable headless from the command line.
- A scripted bot performs every combo against a training dummy and records it with Godot's Movie Maker mode. The agent reviews those captures to check its own visual work before handing a build to Game-boy.

## 12. Milestones

Each milestone ends with a build Game-boy plays, and the next milestone starts only after Game-boy signs off. Feel is tuned early in graybox, before any final art exists.

| # | Milestone | Scope | Done when |
| --- | --- | --- | --- |
| 0 | Toolchain and skeleton | Verify every tool in Section 2; create the repo, layout and Git LFS rules; set up command-line test runs | A report lists each tool as working or missing, and the empty test suite runs headless |
| 1 | Graybox combat | Placeholder humanoid player in a test room, first-person camera, every Section 4 move with placeholder animations, hit/hurtboxes, 3 training dummies | Every combo can be performed and registers hits, and the side-view debug camera works |
| 2 | Hit feel | The full Section 6 stack with placeholder VFX and SFX, plus the tuning panel | Game-boy tunes each tier live and saves a preset |
| 3 | Enemy AI and rear warning | All archetypes in graybox, the director, flanking, the rear-attack warning, and a 6-enemy crowd test room | A 6-enemy fight is readable, and the warning fires correctly behind-left, behind-right and directly behind |
| 4 | Art pipeline proof | Toon shader and outlines, final player arms and legs, one Street Punk taken through the full pipeline, the comic VFX set | The Punk looks production-quality at 1 m from the camera, standing still and in motion (Game-boy judges) |
| 5 | Level blockout | Approved encounter plan; graybox level built from the reference with arena locks, spawns, pickups, hazards and the boss arena | The level plays start to boss |
| 6 | Full art and audio | All enemies and the boss, environment modules and set dressing, final SFX | No placeholder assets remain |
| 7 | Polish and playtest build | Performance target met, bugs fixed, Windows export | Game-boy plays start to finish and answers the four questions in Section 1 |

## 13. Decisions and open questions

The core choices are locked for the PoC; the open items below can be settled as the agent reaches them.

| Decision | Choice | Why |
| --- | --- | --- |
| Engine | Godot 4: GDScript, Forward+, Jolt physics | Plain-text project files and full command-line control maximize agent autonomy; cel-shading doesn't need Unreal or Unity rendering |
| Art style | Cel-shaded comic, stylized proportions, covered faces | Hides AI-generation flaws, and one shader unifies assets from different sources |
| Level template | NES Double Dragon II, Mission 1 | Proven pacing, so the PoC needs no level design |
| Camera | Mounted on the full-body character's head, with no separate first-person arms | One animation set, and the first-person and side views show the same game |
| Off-screen aid | Corner flash at wind-up start, plus positional audio | Awareness is the skill being tested |
| Platform and input | Windows PC, gamepad first, keyboard and mouse supported | Cadence combos feel best on face buttons |
| Players | Single-player only | Keeps the PoC focused on feel |
| Gore ceiling | Comic blood, bruising and audible bone breaks; no dismemberment | Visceral without turning the PoC into a gore study |

**Open questions**

- [ ] Working title
- [ ] Which 3D generation service, based on what the installed Blender MCP integrates
- [ ] Sound: the Sonniss library, an AI sound-effects API, or both
- [ ] Boss name and design
- [ ] Music: a placeholder loop or silence
