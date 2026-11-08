# Cinematic gameplay video: the operations plan

Written 2026-11-08 by the planning lead (Opus 5.5) for a **second Claude account that starts with an empty usage limit**, and revised the same day after one Opus critic pass. Game-boy asked for a 30-45 s cinematic gameplay video of the PoC, drawn in the visual style of two reference videos. This file is the whole brief: the goal, the style target, the method, the phases and gates, the operations rules, and the prompts that start and resume the session (§12).

## 1. The goal

**The prime directive, Game-boy's one non-negotiable:** the finished video has the same visual style as the two reference videos. If it doesn't, the video is not done, whatever else is true.

| | Post | Video | Made with |
| --- | --- | --- | --- |
| **Ref 1** | Goyart.studio, "ANAKIN VS OBI-WAN" ([x.com](https://x.com/Goyart_studio/status/2118343353435594814)) | 28 s, 2560×1440 | AI ("AI cinematic creator"); tools not named |
| **Ref 2** | Mike Miller (pt5films), "ANAKIN" ([x.com](https://x.com/pt5films/status/2118780239904231736)) | 58.5 s, 1280×720, 24 fps | "Midjourney and @dreamina_ai" |

**What the video shows:** almost only the gameplay built in Milestones 1-6. That's first-person combat against the five enemy types and Ox Pellerin, in the street, on the roofs and on the boss roof. A few cinematic shots re-frame the same real gameplay (an establishing shot, the boss reveal, a slow-motion knock-off). Nothing is animated by hand.

**What it isn't:** a change to the game. The game keeps its real-time look. Everything new is video-only and lives under `video/`, `tools/video/` and `docs/video/`. Nothing under `game/`, `tuning/` or `tests/` changes, and the 2076-test suite stays green.

**Game-boy's preferences, in order:**
1. **Plan A: Claude paints it, with code.** No generated pixels in the frames.
2. **Creativity and efficiency.** The method should teach us how to make videos like this with Claude alone. Record what worked and what it cost (§11).
3. **AI video tools as the fallback.** Use them only if Plan A can't meet the prime directive, and only with his go.

**Done when:**
1. Game-boy watches the final cut beside the references and says the style matches.
2. It runs 30-45 s (aim for 40), at 2560×1440 and 24 fps, H.264, with sound. There's also a 1920×1080 copy.
3. Every action in it is real gameplay from the game's own simulation, played by scripted bots, then re-lit and re-drawn for the video.
4. The pipeline is committed in one PR (Game-boy merges it or not), and `docs/video/LEARNINGS.md` is written.

## 2. The target style: the style bible

The planning lead watched both videos frame by frame. Times are seconds into each video. These frames are the gates' references; Phase 0 extracts them at full resolution.

### Ref 1 (Goyart): sketch-ink anime with painted fire
- **Line.** Warm brown-black ink, never pure black.
  - In close-ups the lines are sketchy: several overlapping strokes, construction lines that overshoot corners, and short hatching strokes for form (brow, cheekbones, beard, cloth folds).
  - In mid and wide shots the lines thin out, and figures read as rim-lit silhouettes.
- **Fill.** Hard-edged shadow shapes, 2-3 values to a material, with painted texture inside them. There are no 3D gradients and no plastic highlights.
- **Light and colour.** A lava-orange and amber key against electric-cyan sabers. The darks are saturated violet-maroon, not grey. Strong rim light in the key colour.
- **Atmosphere.**
  - Haze in every shot, and billowing smoke painted in large soft shapes.
  - Embers and sparks drifting, and dust kicked up.
  - Heavy bloom on light sources: a white core with a cyan halo.
- **Camera.**
  - Low angles, and dark over-the-shoulder silhouettes in the foreground.
  - Wides with small figures against a wall of fire, and extreme close-ups of faces.
  - A face-off close-up split by crossed blades.
  - Shallow depth of field, motion blur, light shake. Shots last 1.5-3 s.
- **Text.** Subtitles in white bold condensed capitals with a dark outline, bottom centre.
- **Frames:**
  - 0.9: Obi-Wan's close-up, for the ink and the hatching;
  - 5.3: Anakin before fire clouds;
  - 7.2: a low-angle blade in the foreground;
  - 15.6: an over-the-shoulder silhouette;
  - 24.4: the wide duel against a wall of fire;
  - 27.3: the face-off close-up.

### Ref 2 (pt5films): flat, graphic anime at night and at sunset
- **Line.** Bold, clean dark outlines, with little hatching.
- **Fill.** Flat colour fields with hard, angular shadow shapes, close to *Castlevania* or *Primal* TV anime. The backgrounds are painted mattes with graphic rock shapes and texture.
- **Light and colour.**
  - Night: navy and indigo with cold moonlight, warm orange firelight on faces and tents, a cyan-white saber glow.
  - Day: a dusky gold desert with a huge sun disc and halo, soft gradients, long shadows.
- **Camera.** Slow and moody:
  - night establishing shots under two moons;
  - eye close-ups;
  - silhouettes against fire;
  - a low-angle saber ignition;
  - a silhouette on a dune against the sun.
- **Text.** A title card ("ANAKIN" in big bold condensed cyan capitals over a small credit line), and an end card.
- **Frames:**
  - 1.2: the title card;
  - 12.9: Anakin's face close-up;
  - 37.4: an over-the-shoulder shot of the saber against a Tusken;
  - 42.0: the camp at night under two moons;
  - 50.5: the sunset dune silhouette.

### What "the same style" means for us: eight pillars
Both videos share these eight things. Each one is a column in the Gate 2 rubric.

| Pillar | Target |
| --- | --- |
| **P1 Line** | Hand-drawn ink: tinted dark, with variable weight (heavier on the shadow side, lost in rim light), and inner lines on faces and folds. Sketchy hatching in close-ups (ref 1), clean and bold in mid shots (ref 2). Environment lines are sparse and fade with distance. |
| **P2 Fill** | Painted, not rendered: hard shadow shapes, 2-3 values to a material, and fine brush grain anchored to the surface. No plastic specular: sharp glints on metal only. |
| **P3 Value and light** | Most of the frame is dark. Each shot has one motivated key and one accent of the opposite temperature. Strong rim light, and silhouettes that read. |
| **P4 Colour** | A complementary warm/cool scheme, with saturated darks (violet-maroon or navy, never grey). The palette for each location is below. |
| **P5 Atmosphere** | Depth haze tinted by the key, volumetric shafts at lamps, painted smoke banks, embers, sparks, dust, and bloom with wide halos. |
| **P6 Camera** | Cinematic framing: low angles, over-the-shoulders, wides with small figures, close-ups. Shallow depth of field, anime smears on fast motion, shots of 1.5-3.5 s, and speed ramps on big hits. |
| **P7 Detail** | Faces, hands and folds drawn with the reference's detail at the same shot size. |
| **P8 Coherence** | No swimming textures and no flicker beyond deliberate line boil. Nothing that reads as a filter over a 3D game. |

### Our three locations in that language
- **The street at night** (like ref 2's camp):
  - sodium lamps (about #ff9a3c) as the key, with cold blue moonlight and night sky as the fill, and navy shadows;
  - steam from the manholes, and a burning barrel or two (video-only dressing) for warm accents and embers.
- **The roofs at dusk** (like ref 2's dunes):
  - a low sun behind the action with a big disc and halo, and a gold, rose and violet sky;
  - long shadows, and figures in silhouette;
  - the slow-motion knock-off over the parapet plays against the sun.
- **The boss roof** (like ref 1's Mustafar): a violet-black sky, firelight from below, embers and smoke, and Ox Pellerin rim-lit in orange.

## 3. Where the game stands
Today's look: `/Users/arachne/repos/beat-em-up-PoC/captures/m6-look/street_punk_overview.png` (the street and a Punk) and `/Users/arachne/repos/beat-em-up-PoC/captures/m6-look/boss_overview.png` (Ox). These are contact sheets of M6's last recordings, the only captures kept after the 2026-11-08 cleanup.
- **Characters:** Tripo models of up to 30k triangles, with one shared palette atlas, shaded with M4's toon look: three flat bands and a violet shadow tint. Ox's face is faceted and simple.
- **Lines:** an inverted-hull outline at a uniform 3.75 px, and thin edge lines on the environment.
- **World:** a muted dusk grade, and a trim-sheet city whose brick and grime read as near-photographic texture.
- **Effects and UI:** comic hit effects (impact frames, speed lines, starbursts, words), and the HUD.
- **Captures:** 1280×720 or 1600×900.

**The gap, pillar by pillar:**
- **P1:** the lines are uniform, with no inner lines.
- **P2:** the fills are flat, and the environment's textures are photographic.
- **P3:** the light is even and low in contrast.
- **P4:** the palette is muted and greyish.
- **P5:** there's no haze, smoke or particles beyond the hit effects.
- **P6:** the only camera is the player's eyes.
- **P7:** the faces are simple.
- **P8:** the frame reads as a clean 3D toon game.

Every pillar needs work: P1, P3, P4, P5 and P7 most.

## 4. The approach

### The idea
**The game is the motion source; Claude is the painter.**
- The game's own simulation plays every shot, from scripted bot acts, as the review captures already do. A script writes the frames offline, at whatever cost each frame takes.
- Because nothing has to run in real time, the video build can afford what the game can't: volumetric fog, thousands of particles, painted mattes, extra render passes for masks and ink, and a stack of custom post passes.
- **2D first.** No upgrade is there for more 3D fidelity. Each one must make the frame read as drawn and painted. Light and a LUT alone would only make a better-lit toon game, and that fails the prime directive.
- Claude writes the painting as code: the shaders, the textures, the line work, the skies, the particles, the grade and the edit.

Claude doesn't paint pictures freehand. It paints the rules a painter follows, and the code applies them the same way to every frame:
- where the ink goes and how heavy it is;
- how the shadows are shaped, and what colour the darks are;
- where the haze, smoke and embers are.

That consistency is exactly what hand-drawn animation needs, and what AI video struggles with.

### Plan A: the painted render, in Godot (preferred)
A video-only "cine" render profile on top of the game, in seven parts. Part 7, the 2D cues, matters most: without it, parts 1-6 make a better-lit toon game, not the references' style.
1. **Light.**
   - A lighting rig per location, designed shot by shot as in a film. Each shot has one motivated key, one accent of the opposite temperature, rim lights that follow the characters, and practical lights (lamps, fire barrels).
   - Volumetric fog and fog volumes for the haze and the shafts, glow with wide halos, and depth of field per shot.
2. **Paint.** A cine toon material that extends `toon.gdshader`:
   - hard terminators with a painted edge, a shadow hue per scene, and a rim tinted by the key;
   - brush grain in object space, so the paint never swims;
   - hatching (tonal art maps) in the shadow band for close-ups;
   - glints on metal only.
3. **Ink.**
   - Line weight follows the light (heavy in shadow, thin or lost in rim light) and the distance. The ink is tinted per scene.
   - Inner lines come from an ink texture per character. Creases come from a curvature mask; Claude draws the features (brows, eye lines, nose, mouth, scars).
   - An optional sketch mode for close-ups draws 2-3 jittered strokes with overshoot, re-seeded at 12 fps.
4. **Atmosphere.**
   - Painted skies made by code: domain-warped noise quantized into brush bands, and a sun or moon disc with a halo.
   - GPU particles for embers, sparks (extra bursts on hits, from `CombatEvents`), dust and steam, with every sprite generated by code.
5. **Lens and finish.**
   - A palette transfer from the reference frames into a 3D LUT. Code measures both and builds the LUT in `tools/gen_lut.gd`'s format.
   - A vignette, a little chromatic aberration, and grain.
   - The game's impact frames and speed lines, restyled as anime smears and flash frames. The comic word sprites and starbursts are hidden: neither reference has them. Both choices are A/B'd at Gate 2.
6. **Assets.** Video-only, through headless Blender (never the Blender MCP):
   - an ink (crease) mask baked from curvature;
   - face normals transferred from a smooth proxy, for clean anime face shadows;
   - a painted albedo, and the drawn feature lines (part 3).

   Subdivision and AO bakes come in only if a Gate 2 A/B shows they raise P2 or P7: they add 3D fidelity, not drawing.
7. **The 2D cues.** These are required look-dev items, each A/B'd at Gate 2:
   - **Characters on twos.** Each character's drawing holds for 2 frames at 24 fps (12 drawings a second), while the camera and the effects move at 24.
   - **Picked frames, no blending.** The 24 fps frames are picked from the 60 fps simulation and never blended, because blended ink ghosts. Fast limbs get anime smears or a directional blur instead.
   - **The environment as flat paint.** A video-only material override per location posterizes the trim textures into 2-3 value bands, keeping the big shapes (windows, doors, shutters) and dropping the brick and grime detail. It adds object-space grain, and keeps ink only on major silhouettes.
   - **Painted mattes.** The sky, the far skyline and the smoke banks are code-painted layers on cards behind the playfield. The Kuwahara filter is allowed on these layers only, never on the 3D environment, where it would swim under a moving camera.

**The odds (the planning lead's estimate):**
- **High** for P3, P4, P5, P6 and P8. Light, colour, atmosphere, camera and coherence are fully in our hands.
- **Good** for P2, and for ref 2's clean graphic look.
- **Lowest** for P1 and P7 in close-ups: hand-drawn line quality and drawn faces.
- **Overall,** roughly a one-in-three to one-in-two chance that Plan A alone passes. So Phase 0 tests the hardest question first (the spike and the blind check), Gate 2 proposes fallbacks as soon as a pillar lags, and the shot list leans on silhouettes, backlight and mid shots, which hide the weakest pillars.

### The fallbacks (each needs Game-boy's go)
They're proposed as soon as a pillar scores 1 or less (Gate 2), not after the look-dev rounds run out.
- **A2: Blender line art,** if the ink (P1) is the gap. Still all code; about two builders.
  1. A replay recorder writes each take's bone poses, transforms and camera, frame by frame. The game and the Blender rigs share one skeleton.
  2. Headless Blender re-renders the characters with Grease Pencil Line Art: contours, creases and intersections, with thickness and noise modifiers.
  3. The composite lays those lines over the Godot frames, through the character mask.
- **A+: AI-painted static assets,** if the paint or the detail (P2, P7) is the gap.
  - Gemini (`tools/gemini_image.py`, already paid for) or Tripo makes painted textures, matte backdrops and a close-up bust.
  - The code pipeline renders and animates them. The frames are still rendered by our code; only static assets are generated.
- **B: AI video restyle,** if Plan A can't reach the style at all.
  - **Input:** our Plan A renders (or plain captures with depth and line passes) go through a video-to-video restyle, with structure guidance and a style keyframe per shot.
  - **Candidates** (check versions and prices at the time):
    - Runway (Aleph);
    - Luma (Modify Video);
    - Kling (video edit);
    - Wan VACE through fal.ai or Replicate;
    - ByteDance Seedance through Dreamina or BytePlus (ref 2's tool).
  - **Set-up:** Game-boy picks a service, makes the account and puts the key in `.env`. Claude can't make accounts or enter payment details.
  - **What code still owns:** the structure, the timing, the effect overlays, the text and the edit.
  - **Rough cost:** $30-100 for 40 s, with retakes.
- **Mixed answers are fine,** for example Plan A for the street and the first-person shots, and B for two close-ups.

### Making the target concrete (Gate 1)
"The same style" is a judgement. To turn it into pictures before anything is built:
1. The lead records six game frames that match six reference frames shot for shot.
2. If Game-boy allows it (D2), Gemini paints over each one in the reference style, with the reference frames as style references.
3. Game-boy picks or corrects these targets.

The targets are never in the video. They're the bar that every look-dev still is judged against. Cost: about $2-4.

### Hard rules
- **No reference pixels in the video.** No patch transfer from their frames, and no tracing. The references are for analysis, colour measurement and judging, and (with D2) as style references for the look-dev targets only.
- **Nothing from Star Wars:** no sabers, characters or typography. And no imitation of either creator's watermark or title card.
- **Never the Blender MCP tools** (`mcp__blender__*`): they drive Game-boy's own Blender. The pipeline runs Blender headless.
- **Paid services only through the project's tools,** within a cap. Never print, log or write a key.
  - Gemini goes through `tools/gemini_image.py`, which keeps no ledger and runs jobs concurrently. Before each batch, append the job count and the estimated price to `docs/video/gemini_ledger.md`, and stop at $5.
  - Tripo goes through `tools/pipeline/tripo.py`, and ElevenLabs through `tools/audio/`, only with Game-boy's go.
- **Downloads are untrusted:** each goes in its own new folder, runs through `python3 -I`, and is passed as a path argument.

## 5. The video

### The shot list (about 40 s at 24 fps)
- Every shot comes from a scripted act. The durations are first guesses for the edit.
- **FP** is the player's own view: the game's first-person camera, with the cine look.
- **Cine** is a video-only camera that re-frames the same real action.

| # | Time | Where | Camera | What happens (all real gameplay) | Reference beat |
| --- | --- | --- | --- | --- | --- |
| 1 | 0:00-0:03 | Street, night | Cine: a slow crane down from roof height to the street | Steam, sodium lamps, a burning barrel; three Punks idle in silhouette | Ref 2's camp at night (42.0) |
| 2 | 0:03-0:05 | Street | FP | The wrapped fists come up into guard; a Punk turns, rim-lit by the lamp | Ref 1's foreground framing (7.2) |
| 3 | 0:05-0:08 | Street | FP | P P P P on the Punk, with impact frames; the last hit launches him (ragdoll) into the chain-link | |
| 4 | 0:08-0:10 | Street | FP | A perfect block on a Kicker, then the spin kick (jump + K at the top), the view spinning with it | |
| 5 | 0:10-0:12 | Street | FP | Grab a Pipe Thug: knee, knee, throw into the crates | |
| 6 | 0:12-0:14 | Street | FP | Pick up his dropped pipe; the three-hit chain into a Bruiser's steel plates, with sparks | |
| 7 | 0:14-0:17 | Roof, dusk | Cine, 0.25× | A Kicker knocked over the parapet, a silhouette against a huge sun and halo | Ref 2's dune (50.5) |
| 8 | 0:17-0:19 | Roof | FP | The bike chain's whip on two Punks, the padlock landing last | |
| 9 | 0:19-0:21 | Roof | FP | The rear warning flashes; the back elbow (Q) turns the view 150° into the attacker | |
| 10 | 0:21-0:25 | Boss roof | Cine: low angle, slow push-in | Ox Pellerin, hooded and rim-lit against fire and smoke, with embers; he raises his gloves. A name card: "OX PELLERIN" | Ref 1's Anakin before the fire (5.3) |
| 11 | 0:25-0:31 | Boss roof | FP | Block Ox's heavy, then a perfect block, the spinning backfist (P P · P), and the haymaker held and released | |
| 12 | 0:31-0:34 | Boss roof | Cine, 0.25× | The haymaker lands. By default, a backlit silhouette of fist and head against the fire, with the impact frame. A face close-up only if Ox's close-up scored P7 ≥ 2 at Gate 2 | Ref 1's face-off (27.3) |
| 13 | 0:34-0:37 | Boss roof | FP | Ox falls (ragdoll); the embers settle; cut to black on the hit sound | |
| 14 | 0:37-0:41 | | Title card | The title (D5) over drifting embers | Ref 2's title card (1.2) |

The lead can swap in stronger beats found in Phase 2's blocking, as long as the mix holds:
- at least 70% first-person gameplay;
- every enemy type, every location, and the boss.

In cine shots the player's whole body shows (the model the KO view uses), so it needs the same upgrades as the enemies.

### Sound
- **Effects:** the game's own ElevenLabs bank (hits, blocks, whooshes, weapons, voices). Code places them from the takes' logs, and mixes them by rules. The bots already log the hits of each act; the trailer acts add a frame number to every event.
- **Music:** decision D4, asked at Gate 3 with the animatic. The references are cut to music, so ours should be too. Until then, the temporary sound is effects only.
- **Loudness:** about -14 LUFS integrated, with true peak below -1 dBTP.

### Text
- There's no HUD, and no comic word sprites (part 5).
- The boss's name card and the end title use a bold condensed face. Pick a font with an open licence; none is in the project.
- Optionally, one subtitled line from Ox in ref 1's subtitle style, only if Game-boy wants it.

### Format
- The simulation runs at 60 fps, as in the game (`--fixed-fps 60`). The frame writer (Phase 1, LD-RENDER) keeps only the 24 fps picks, at 2560×1440, with no blending: frame i is written when floor(i·24/60) changes.
- Encoding: H.264 High at about 30-40 Mbit/s, with AAC at 320 kbit/s. Plus a 1920×1080 copy.
- Ref 2 measured 24 fps. Check ref 1 with `ffprobe` after the download.

## 6. Phases, packages and gates

The estimates are in % of a 5-hour window on the seat Game-boy has used since M5. Re-measure: the second account's seat may differ.

### Phase 0: set-up, the target and the spike (about 10-15%)
1. **Set up the session** as §7 says: title, watcher, worktree, disk.
2. **Keep the captures out of Godot and git.** The worktree has no `captures/` folder yet; the main checkout's `.gdignore` there is untracked, because `/captures/` is git-ignored.
   - Run `mkdir -p captures/video && touch captures/.gdignore captures/video/.gdignore` in the worktree.
   - If the venv is approved, make it outside the project: `python3 -m venv ~/.venvs/beat-em-up-video`.
3. **Download the two references** (D1) into `captures/video/ref/ref1/` and `captures/video/ref/ref2/`, each in its own new folder. The URLs are in §12. Run `ffprobe` on both.
4. **Extract the gates' reference frames** at full resolution (§2's times), and contact sheets:
   `ffmpeg -ss <t> -i ref1.mp4 -frames:v 1 ref1_<t>.png`.
5. **Measure the references.** For each frame, measure:
   - the luminance histogram;
   - the saturation and hue of the darkest third, and the key's hue;
   - the edge density.

   Write the numbers into `docs/video/STYLE.md`, with the times but not the images. They're the style meter's targets (Phase 1).
6. **Record six game stills, with the HUD off,** that match six reference frames shot for shot. The old recordings were deleted in the 2026-11-08 cleanup (D3), so these are all new.
   - **First person:**
     - 7.2: a fist in the foreground with a Punk at 3 m;
     - 37.4: a Kicker beside a lamp.
   - **The free-fly camera** (`CameraDirector`'s `free_fly` mode, placed by the act):
     - 0.9: Ox's close-up;
     - 5.3: Ox on the boss roof, from a low angle;
     - 42.0: the street, wide;
     - 50.5: a silhouette on the roof edge.
7. **The spike,** before any builder starts (the lead, or one Sonnet builder on the lead's brief; about 5-10%). Make one still of the street with a Punk at 2 m, using only:
   - a hand-placed key and rim light, and fog;
   - the LUT transfer;
   - a screen-space ink pass from depth and normals, weighted by light;
   - the flat-paint environment override (Plan A part 7).

   Score it with the rubric (Gate 2).
8. **The blind check** (one Opus agent, about 2-3%), to guard against the team's optimism.
   - Give it 12 unlabelled stills, shuffled, with neutral file names:
     - the six reference frames of step 6;
     - three Gemini targets;
     - the spike;
     - two plain game frames.
   - Ask which of them are renders of a 3D game, and why.
   - If it calls the spike 3D, say so in the Gate 1 DM, with the costs of A2 and A+.
9. **Gate 1.** Make the targets (D2), then DM Game-boy the six pairs (reference | target), the spike, and the blind check's verdict, and ask: "Is this the style?" Start Phase 1 meanwhile.

**The paint-over job,** for `tools/gemini_image.py`:
- `refs`: [our frame, two reference frames];
- `aspect`: "16:9";
- `prompt`: "Repaint the first image in the exact art style of the other images: [the §2 description of that reference]. Keep the first image's composition, camera, characters, poses, clothes and every object; change only how it is drawn, painted and lit. No text, no logos, nothing from Star Wars."

### Phase 1: look-dev (about 35-50%, then 15-20% for each extra round)
Three builders (Sonnet, high effort) work in their own worktrees off `video/cinematic-trailer`, alongside the lead. While the game session is active, run at most two at once (§7). Do the light, colour, flat paint and atmosphere first: they make the biggest visible jump soonest, and they calibrate the rest.

**LD-RENDER: the stage, the light, the atmosphere, the frame writer.** It owns `video/` (the scaffold, `CineDirector`, the shot scenes), the per-location rigs in `video/look/`, and `tools/video/shoot.sh`.
- **Shot scenes.** `video/shots/<shot>.tscn` instances a game room (mission1's street, a roof, or the boss roof) and adds a `CineDirector`, which:
  - hides the HUD and the debug overlays;
  - applies a `CineLook` resource: the location's environment, lights, fog volumes, sky, mattes, depth of field, glow and particles;
  - optionally adds a `CineCamera` for the non-FP shots: a keyframed path, a look-at target, and keys for the FOV and the focus.
- **Look values** live only in `CineLook` `.tres` files under `video/look/`.
  - The few presentation tunables a shot needs (FOV, shake) are set by `CineDirector` at runtime, from the `CineLook`: `Tuning.data.<name> = …`, then `Tuning.apply`.
  - No file goes in `tuning/`: every JSON there shows in the game's tuning panel as a preset.
- **Atmosphere:**
  - volumetric fog and fog volumes;
  - the painted sky shader (code-made clouds, a sun or moon with a halo), and the painted matte cards (the far skyline, the smoke banks);
  - GPU particles for embers, dust, steam and hit sparks, subscribing to `CombatEvents` as presentation does.
- **Determinism.** `vfx_director.gd` and `audio_director.gd` call `rng.randomize()` in their `_ready`.
  - `CineDirector` seeds `VfxDirector.rng` and `AudioDirector.rng` with `call_deferred` from its own `_ready`. That needs no edit to `game/`.
  - Acts start through `level_bot`'s `_reset` path, so the simulation's seeds match the review captures.
- **The frame writer, `tools/video/shoot.sh <shot>`.** Movie Maker can't start or stop mid-act, and its window is clamped by `project.godot`'s 1600×900 override and by the display. So a script writes the frames instead:
  - **The picture.** The shot scene renders through a fixed 2560×1440 `SubViewport`, independent of the display, while the game runs with `--fixed-fps 60`, so the simulation is unchanged. The viewport's camera copies the active game camera's transform, FOV and cull mask every frame.
  - **The character mask.** A second `SubViewport` shares the `World3D`, with only the characters' layer and a transparent background. Its alpha is the character mask for the composite: the ink, the on-twos hold, and the matte passes.
  - **Only what's needed.** The writer saves only frames inside the shot's [from, to] window, and only the 24 fps picks. Outside them, the main window's viewport has `UPDATE_DISABLED`.
  - **The disk.** Every 200 frames it encodes to the shot's mezzanine file (`ffmpeg -c:v libx264 -crf 8 -preset slow -pix_fmt yuv444p`), then deletes those PNGs.
  - **Quality.** It defaults to MSAA 4× with no supersampling. Raise `scaling_3d_scale` above 1 only after measuring memory and seconds per frame with the game session's Godot also running.
  - **The lock.** It takes the machine-wide capture slot lock that `tools/capture_bot.sh` uses (`CAPTURE_LOCK_DIR`, default `~/.cache/beat-em-up-capture`). The game session's captures take it too.
  - **The numbers.** Record the measured seconds per frame and MB per frame in docs/video/HANDOFF.md at Gate 2.
- **Tests:** a smoke test per shot scene in `video/tests/`, run on its own, so the main suite doesn't grow. For example, `godot --headless --fixed-fps 60 -s addons/gut/gut_cmdln.gd -gdir=res://video/tests -gexit`; check the flags against `addons/gut`.
- **Done when** the six Gate 1 shots render at 2560×1440 with the new light, mattes and atmosphere, still on the old toon materials.

**LD-INK: the paint and the line.** It owns `video/shaders/` and the post passes.
- **`cine_toon.gdshader`** includes `toon_light.gdshaderinc` rather than forking it, and adds:
  - the painted terminator, the scene's shadow hue, and the key-tinted rim;
  - brush grain in object space;
  - hatching tonal art maps in the shadow band, generated by code;
  - metal glints, and sampling of the ink texture.
- **The line upgrade:**
  - lines weighted by light and distance, in a tinted ink;
  - the sketch mode with 12 fps boil;
  - inner lines from the ink textures.
- **The flat-paint environment override** (Plan A part 7): the posterized trim, the object-space grain, ink on major silhouettes only.
- **The 2D-cue switches** for the A/Bs: characters on twos (holding the character layer through the mask), smears on fast limbs, the hidden comic words.
- **Post passes** as `CompositorEffect` compute shaders (check the 4.7 API with `godot --headless --doctool`):
  - an anisotropic Kuwahara filter on the matte layers only;
  - paper grain, a vignette, and chromatic aberration.
- **`tools/video/palette_lut.py`.** It measures a reference frame and one of our frames, and writes a LUT that moves ours toward theirs. Use a smooth transfer (Reinhard means and spreads per value band, or Pitié's iterative distribution transfer). The `CineLook` names the LUT.
- **Tuning by measurement.** A tool script renders one still under a sweep of `CineLook` values and scores each with the style meter. The lead then looks only at the best few.
- **Done when** one character (the Punk) and one street corner pass the lead's look beside the reference frames, at first-person distance and in a close-up.

**LD-ASSET: the upgraded cast.** It owns `tools/video/blender_*.py` and `assets/video/`. These are exports only; the sources stay where they are.
- **Round 1 covers only the Punk, Ox** (`assets/source/characters/boss/`) **and the player's first-person arms and wraps,** which are in most shots. The other four enemies and the player's full body follow after Gate 2 passes, as one builder (about 8-10%, in Phase 2).
- **Headless Blender** on each character's source in `assets/source/characters/<name>/`, one Blender process at a time:
  `blender --background --factory-startup --python-exit-code 1 --python ...`
  For each character, make:
  - curvature baked into an ink (crease) mask;
  - face normals transferred from an ellipsoid proxy;
  - a painted albedo.

  No subdivision and no AO bake, unless a Gate 2 A/B shows they raise P2 or P7.
- **Claude-drawn features.** For each face:
  1. render a front view and the UV layout;
  2. draw the feature lines as SVG in UV space: brows, eye lines, lids, nose, mouth, scars;
  3. bake them into the ink texture.

  Keep each character's design (the concept sheets are in `assets/source/concepts/m6/sheets/`). This adds drawing; it isn't a redesign.
- **Done when** the Punk and Ox render in Godot with the video textures, in a close-up and at 1-3 m.

**The lead:**
1. Merges the packages, and renders the Gate 2 set: the six Gate 1 shots, plus one 5 s moving shot (first person, P P P P on a Punk under a street lamp).
2. Looks first, at full resolution, beside the reference frames and the targets (process rule 1).
3. Runs one review round: one Opus visual lens with the rubric, and one Sonnet code lens (coherence, determinism, no diff under `game/`, `tuning/` or `tests/`). Then the blind check again, on the Gate 2 set.
4. Runs one fix wave, then the targeted re-check.

**The style meter,** `tools/video/style_meter.py` (the lead or a Sonnet helper):
- It scores each frame against STYLE.md's targets: the value distribution, the saturation and hue of the shadows, the palette distance in Lab, the edge density, and the flicker over time.
- It's a guard rail between looks, not the gate, and far cheaper than an Opus look.

**Gate 2: the prime directive, early.**
- **The rubric.** Score each pillar, P1 to P8, from 0 to 3 for each still, against the matching reference frame and target:
  - 0: a 3D game's look, or missing;
  - 1: there, but it reads as a filter or a game;
  - 2: it matches at a glance, but differs on a closer look;
  - 3: the same style at the same shot size.
- **The internal bar:** every pillar at 2 or more, a mean of 2.4 or more, and the blind check doesn't call our frames 3D renders. Then DM Game-boy the pairs and the 5 s clip: "Does this match the references' style?"
- **Any pillar at 1 or less after round 1:** in the same DM, propose the fallback for that pillar, with its cost, to run beside round 2: A2 for P1, A+ for P2 and P7. Don't wait for round 3.
- **His answer:**
  - **Pass:** go to Phase 2.
  - **Close:** run another look-dev round on the lowest pillars. At most two more rounds, about 40% in all.
  - **No, or still failing after the third round:** propose the fallback that fixes the failing pillars, with its cost (A2 for the lines, A+ for the paint and the detail, B for the rest), and wait for his choice.
- **While waiting for him,** start SHOTS (Phase 2): its acts and cameras don't depend on the look.

### Phase 2: the shots and the rest of the cast (about 25-30%)
**SHOTS (one Sonnet builder).** It owns `video/acts/trailer_acts.gd` and `video/shots/`.
- **One act per shot in §5's list,** built from the existing bot tools and the `CineCamera`:
  - the combo bot's inputs;
  - `ShowcaseRunner` for enemy beats;
  - god mode, Freeze AI and F4's spawn;
  - the level bot's `--from`/`--to` arenas, to start in the right place.
- **Slow motion** goes through `TimeController`, the one module allowed to write time.
- **Logs:** each act logs its hits and events with frame numbers, for the sound.
- **The blocking pass comes first,** at 1280×720 in the cine look. It's cheap, and the lead cuts it into an animatic with temporary timing.
- **Then the final renders,** at 2560×1440, one shot at a time, in the background. Before starting, write the total render hours into docs/video/HANDOFF.md, from Gate 2's measured seconds per frame.

**LD-ASSET's second round (one Sonnet builder):** the Kicker, the Pipe Thug, the Bruiser and the player's full body, the same way as round 1.

**Gate 3: the animatic.** The cut at preview quality, with temporary sound.
- Game-boy checks the beats and the pacing. It's optional: skip it if he says so in the launch prompt.
- Ask D4 (the music) with it.

### Phase 3: the finish (about 20-25%)
**EDIT (one Sonnet builder, or the lead).** It owns `video/edit.json` and `tools/video/assemble.py`:
- the cut list: for each shot, its in and out points, speed and transition;
- titles rendered by code, with PIL and the chosen font, or a Godot scene;
- the final grade and grain;
- the soundtrack: effects placed from the act logs, the music, and the mix (`ffmpeg`'s `loudnorm`);
- the exports.

**The review:** one round of three lenses (process rule 2):
- the style match against the references (Opus);
- the gameplay's legibility and feel (Opus);
- the technical side (Sonnet): flicker, swimming, sync, encoding, loudness.

Then one fix wave, and a targeted re-check.

**Gate 4: the sign-off.** DM Game-boy, as file uploads:
- the 2560×1440 file, and the 1920×1080 copy;
- a style proof: a contact sheet of our frames beside the reference frames.

He decides. Make a GitHub Release (a draft, never public) only on his word.

### Phase 4: the record (the lead, under 5%)
1. Write `docs/video/LEARNINGS.md` (§11).
2. Open the PR for the video tooling against `m6/full-art-audio` while PR #6 is open, or against `main` once it's merged. List the size of `assets/video/` in its description (the repo has no LFS), so Game-boy can choose to keep the video work on its branch. Never merge it without his word.

## 7. Operations

### The session
- **Open it in the folder** `/Users/arachne/repos/beat-em-up-PoC/.worktrees/video`, so the video branch's CLAUDE.md (with the video session's note) applies.
- **Title it "Beat-em-up: video session"** with `mcp__ccd_session_mgmt__set_session_title`, not "working session". That title belongs to the game's working session, which may run at the same time on another account.
- **Start a watcher for this account:** "Beat-em-up: video usage watcher", Haiku at low effort, with the prompt in §12. It's docs/HANDOFF.md's watcher, re-aimed at this session.
- **Keep `docs/video/HANDOFF.md`** on the video branch, the way docs/HANDOFF.md is kept: newest entry first, at every phase boundary and before every limit.
  - Its first entry copies the launch prompt's APPROVALS word for word, so a takeover session has them.
  - It keeps a running line of what each paid service has spent.
- **The handoff at a limit** is CLAUDE.md's protocol, with this file's names:
  1. Halt new work, and commit `wip:` on every video branch and worktree.
  2. Push.
  3. Update and push `docs/video/HANDOFF.md`.
  4. Create the resume task `beat-em-up-video-resume-<yyyymmdd-hhmm>` with §12's resume prompt.
- **Model and effort:** docs/HANDOFF.md, "Model, effort and process rules from Milestone 5 on".
  - Opus at high effort for the lead and the visual lenses (at most 3 lenses a round).
  - Sonnet at high for builders, fixers and code lenses; Sonnet at medium for skeptics.
  - Haiku at low for the watcher.

  Its process rules 1-8 apply as written.
- **Workflows.** The runners assume milestone work, so the video takes these arguments:
  - **`tools/workflows/build.js`:** `milestone: "v"` (branches `mv/<key>`, worktrees `.worktrees/mv-<key>`, commit subjects `Mv <key>: ...`), `base: "video/cinematic-trailer"`, `plan: "docs/video/PLAN.md"`, and `note`.
  - **`tools/workflows/review.js`:** `milestone: "v"`, `base: "<the merged head's sha>"`, `base_branch: "video/cinematic-trailer"`, `common_note`, and `partition: false`.
  - **Both notes start with this text, word for word:**
    "VIDEO WORK OVERRIDES: cine (non-first-person) shots count as much as first person. Judge against docs/video/PLAN.md §2 and the reference frames, not SPEC.md. Never edit game/, tuning/ or tests/: look values go in CineLook .tres files under video/look/, not in tuning_data.gd. Instead of the full suite, run the video tests (PLAN.md §6, LD-RENDER) and `git diff --quiet origin/video/cinematic-trailer -- game tuning tests` (it must exit 0). Calls files go to docs/video/calls/<key>.md."
  - The runners may still create `docs/milestones/Mv-calls/`; move it into `docs/video/calls/` when merging.
  - Keep the args files in `docs/video/`. Without Game-boy's go for workflows, run the builders as Sonnet subagents with the same briefs.
- **Usage:** docs/HANDOFF.md, "Usage rules for the working session". Size each launch to the headroom below 90%, hand off at the watcher's 90%, and commit `wip:` often.
- **Comms:** DM Game-boy on Slack (Michael, `U0AQMKKBL93`, DM `D0AQUKX5DB6`) at each gate and whenever you're blocked on him; carry on with anything not blocked. If this account has no Slack tool, ask in the session's chat.

### Git
- **The branch** is `video/cinematic-trailer`, cut from `m6/full-art-audio` at 056e697, in the worktree `.worktrees/video`. This plan is its first commit. Run `godot --headless --import --quit` there first.
- **Builders** branch `mv/<key>` from it, and the lead merges them in.
- **Commit messages** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `captures/`, the references, or frames from them.
- **If PR #6 merges first,** rebase the video branch on `main` at a quiet moment.
- **Never touch** `m6/*` or `main`, and never commit, push, stash or reset in the game session's worktrees.
- **One PR at the end;** never merge it without Game-boy's word.

### The shared machine
An Apple M1 with 8 GB of RAM, and 92 GB of disk free after the 2026-11-08 cleanup (D3).
- **The capture lock.** Every render takes the machine-wide slot lock that `tools/capture_bot.sh` uses (`CAPTURE_LOCK_DIR`). The game session's captures take it too.
- **Builders.** At most two video builders at once while the game session is active (`pgrep -fl godot` shows its processes); three when it's idle. Builders use their Godot slots as the runners count them.
- **One Blender process at a time,** and renders in the background under `nice -n 10`.
- **Render hours.** Size Phase 2's renders from Gate 2's measured seconds per frame, and write the total into docs/video/HANDOFF.md before starting.
- **The disk.**
  - The frame writer encodes as it goes and deletes its PNGs. `captures/video/` keeps only the current takes.
  - D3 is done. Keep the space: delete a shot's takes once its final is in the edit.
- **The worktrees.** docs/HANDOFF.md tells the game session never to prune, commit, push, stash or reset in `.worktrees/video` or `.worktrees/mv-*`.

### The budget (an estimate)

| Phase | % of a 5-hour window |
| --- | --- |
| Phase 0: set-up, the target, the spike, the blind check | about 10-15% |
| Phase 1: look-dev | 35-50%, plus 15-20% for each extra round |
| Phase 2: the shots and the rest of the cast | 25-30% |
| Phase 3: the finish | 20-25% |
| Phase 4: the record | under 5% |
| **In all** | about 1-1.25 windows with one look-dev round; about 1.6 with three |

- **Wall-clock render time** is measured at Gate 2 and budgeted before Phase 2's final renders.
- **Paid:** about $2-4 of Gemini targets (D2, cap $5, with the ledger). Music and Plan B only on Game-boy's go.

## 8. Decisions for Game-boy, and the default the session takes

| # | Decision | Default |
| --- | --- | --- |
| D1 | Downloading the two reference MP4s (about 36 MB and 16 MB, from video.twimg.com) for frame analysis, and one SIL-OFL font for the titles. Never published or committed | Yes, if the launch prompt approves it |
| D2 | About $2-4 of Gemini paint-overs as look-dev targets (never in the video) | **Decided: yes.** Game-boy chose to keep them on 2026-11-08 (cap $5, with the ledger) |
| D3 | Freeing disk: the old captures and worktrees | **Done 2026-11-08.** Game-boy: "anything that isn't currently required to run the latest iteration of the Beat-em-up game can go." The 33 M6 worktrees are removed, and `captures/` is emptied except `captures/m6-look/`. 92 GB is free |
| D4 | The music: (a) ElevenLabs music within a cap, through a new `tools/audio/eleven_music.py` that keeps a ledger like `eleven_sfx.py`'s; (b) a licensed track he supplies; (c) effects only | Asked at Gate 3, with the animatic. Until then, (c) |
| D5 | The end card's title and label | "FIRST-PERSON BEAT-EM-UP", with a small line: "Proof of concept. In-engine gameplay, cinematic render." (The video's look isn't the game's real-time look) |
| D6 | Plan B's service and spending cap | Asked at Gate 2, with a recommendation |
| D7 | A+: Gemini or Tripo for textures, backdrops and a close-up bust | Asked at Gate 2 |
| D8 | Workflows for this session | Yes, if the launch prompt says so |
| D9 | The animatic gate (Gate 3) | Yes |

## 9. Risks
- **The style gap in close-ups (P1, P7).**
  - The shot list keeps close-ups to two, lights them for silhouette and rim light, and shot 12 defaults to a silhouette.
  - LD-ASSET draws the features.
  - A2 and A+ are proposed as soon as a pillar scores 1 or less.
- **It reads as a 3D game with a filter (P8).**
  - The 2D cues (Plan A part 7): characters on twos, picked frames, the flat-paint environment, painted mattes.
  - The Kuwahara filter only on mattes, and the paint in object space. There's no screen-space noise on fills, and only the lines boil.
  - The blind check at Gates 1 and 2, and the coherence lens in motion.
- **The gameplay drifts.** Every action comes from the game's simulation; cine cameras only re-frame it. Under Plan B, keep the first-person gameplay shots from Plan A if the restyle bends the action.
- **Determinism.**
  - Deferred seeding of the effects and audio RNGs, acts started through `level_bot`'s `_reset`, and a warm-up run, as the crowd test does.
  - Before relying on two cameras on one action, compare two renders of a shot frame by frame.
  - If that doesn't hold, build A2's replay recorder for those shots.
- **The machine:** 8 GB, shared with the game session. The capture lock, at most two builders while the game session is active, and a frame writer that encodes as it goes.
- **Copyright:** match the style, never use their pixels; nothing from Star Wars; licensed music.
- **Usage limits:** the watcher, the video HANDOFF and the resume task.
- **The game session.** This session has its own title, branch, worktree, HANDOFF and watcher, and never touches `m6/*`, `main` or the game session's worktrees.

## 10. Why this can work
- **The game is a motion-capture stage.** The bots perform real gameplay on demand, the same way every time, so we can shoot takes and coverage like a film crew.
- **Offline rendering lifts every real-time limit,** on the same scenes, characters and effects the game already has.
- **The references are rule-driven styles.** They use 2-3 values, saturated darks, one key with a complementary accent, haze, and ink that follows the light. Rules like these are what code is good at, and what AI video keeps inconsistent from shot to shot.
- **The 2D cues are cheap in code:** holding drawings on twos, picking frames, posterizing a texture and painting a matte are each a few hundred lines, and each one moves the frame from "rendered" toward "drawn".
- **Matching is measured, not guessed.** The palette transfer and the style meter give objective steps between Game-boy's looks. The targets turn "the same style" into pictures he has approved, and the blind check keeps the team honest.
- **Claude draws only where drawing is cheap:** a few feature lines per face in UV space, placed on a rendered guide, after which the 3D animation carries them through every frame.

## 11. What to record in LEARNINGS.md
- **For each phase:** the usage it cost, the wall-clock time, and what the gates said.
- **What moved each pillar most,** per unit of work, and what didn't move it. The A/B results of the 2D cues.
- **Which steps a single Claude session could do alone next time,** and which needed builders, Opus looks or Game-boy.
- **The reusable kit:** the shot scenes, the frame writer, the cine look, the style meter, the LUT transfer, the SFX placement, the assembler, and how to point them at a new game or scene.
- **If a fallback was used:** why, what it cost, and what Plan A would need to avoid it.

## 12. Prompts and links

### The reference links
- **Ref 1:** <https://x.com/Goyart_studio/status/2118343353435594814>
  - MP4 at 2560×1440: <https://video.twimg.com/amplify_video/2118343216424529921/vid/avc1/2560x1440/mNTZELBj8td17g5a.mp4?tag=29>
- **Ref 2:** <https://x.com/pt5films/status/2118780239904231736>
  - MP4 at 1280×720: <https://video.twimg.com/amplify_video/2118779853529075712/vid/avc1/1280x720/WCE5E1mv45RDKKr3.mp4?tag=29>
- **If the MP4 links expire,** re-read them from `https://api.fxtwitter.com/<handle>/status/<id>`.

### The launch prompt
Game-boy opens the second account's session in the folder `/Users/arachne/repos/beat-em-up-PoC/.worktrees/video`, edits the APPROVALS block, then pastes this.

```
You're the video session for a Godot 4.7.2 project: a first-person beat-em-up proof of concept at /Users/arachne/repos/beat-em-up-PoC (GitHub: mikedtcm22/beat-em-up-PoC). I'm Game-boy, the owner. Milestones 1-6 are built; the game's own working session (on another account) may be running at the same time. Your job is different: make a 30-45 s cinematic gameplay video of the game whose visual style matches two reference videos. The whole brief is docs/video/PLAN.md on branch video/cinematic-trailer, checked out in the worktree /Users/arachne/repos/beat-em-up-PoC/.worktrees/video.

THE PRIME DIRECTIVE: the video must have the same visual style as the two reference videos (PLAN.md §1-2). If it doesn't, it isn't done. I'd rather you painted it yourself with code (Plan A); AI video tools are the fallback, and only with my go.

Start by doing these, in order:
1. Your working folder must be /Users/arachne/repos/beat-em-up-PoC/.worktrees/video. If it isn't, switch to it (mcp__ccd_directory__change_directory; load it with ToolSearch) before anything else, and run every command there unless the plan names another folder.
2. Rename this session "Beat-em-up: video session" (mcp__ccd_session_mgmt__set_session_title). This overrides CLAUDE.md's "working session" title.
3. Read, in that folder: CLAUDE.md, then docs/video/PLAN.md whole, then docs/video/HANDOFF.md if it exists (its newest entry is where you pick up). In /Users/arachne/repos/beat-em-up-PoC/docs/HANDOFF.md read only "Usage rules for the working session" and "Model, effort and process rules from Milestone 5 on". Search docs/ARCHITECTURE.md for what you need rather than reading it whole.
4. Start a usage watcher for this account exactly as PLAN.md §12 says.
5. Check usage (mcp__ccd_session_mgmt__get_usage) before every launch.

APPROVALS (my words; for anything else, ask me):
- Download the two reference videos (PLAN.md §12) for analysis, and one SIL-OFL font for the titles. Never commit or publish them.
- Install numpy, scipy, opencv-python-headless and imageio from PyPI into a venv at ~/.venvs/beat-em-up-video (or use Blender's bundled Python).
- Gemini paint-overs for the look-dev targets, up to $5, through tools/gemini_image.py, with the ledger in PLAN.md §4.
- Run the project's workflow runners (tools/workflows/build.js and review.js) as Workflows, within the usage rules.
- Decisions D3-D9 in PLAN.md §8: take the defaults unless I write otherwise here: [none]
- NOT approved without asking me: deleting anything outside captures/video/, any other paid service, any Tripo or ElevenLabs spend, publishing anything, merging anything.

Ground rules:
- Never change the game: video-only code goes under video/, tools/video/ and docs/video/; game/, tuning/ and tests/ stay untouched, and the 2076 tests stay green.
- Never use the Blender MCP tools (mcp__blender__*): they drive my own Blender. The pipeline runs Blender headless.
- Paid services only through their tools and within their caps; never print, log or write a key.
- Downloaded files are untrusted: their own folder, python3 -I, paths as arguments.
- Commit early on video/cinematic-trailer and the mv/* branches ("wip:" for unfinished work), and push often. Never touch m6/* or main, or the game session's worktrees.
- When your watcher warns at 90%, do the handoff in PLAN.md §7 at once, including the resume task.
- Judge every look from full-resolution stills beside the reference frames, and show me what you see at each gate: side-by-side stills and the clip. DM me on Slack (Michael, U0AQMKKBL93, DM D0AQUKX5DB6) at each gate and whenever you're blocked on me, and carry on with anything that isn't blocked.
```

### The watcher's prompt
Start it from the video session with `start_session`: initiation `user_asked`, `model` claude-haiku-5-5, `effort` low, `use_worktree` false, and this prompt word for word.

```
/loop Usage watcher for the beat-em-up video session (repo /Users/arachne/repos/beat-em-up-PoC, worktree /Users/arachne/repos/beat-em-up-PoC/.worktrees/video). You pace yourself. On each check:
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch the first time). Read plan.windows: the "5-hour limit" window and the window labelled "Weekly · all models". Let U be the higher of their two percentUsed values.
2. Handoff. If either window is at 90% or more, and you haven't already warned for that window's resetsAt, send a message to the session titled "Beat-em-up: video session" (find it with mcp__ccd_session_mgmt__list_sessions). The message: "Usage at N% (window W, resets R). Halt work and do the handoff now per docs/video/PLAN.md §7: tell running agents and workflows to stop at a stopping point, commit and push WIP on every video branch and worktree, update and push docs/video/HANDOFF.md, then create the resume task (PLAN.md §12)." Remember that you warned for that resetsAt, and when.
3. Resume task. On the first check 20 minutes or more after a warning, call mcp__scheduled-tasks__list_scheduled_tasks (load it with ToolSearch). If no enabled task whose taskId starts with "beat-em-up-video-resume" has a nextRunAt after now, create one with mcp__scheduled-tasks__create_scheduled_task: taskId "beat-em-up-video-resume-" plus the reset's local date and time as yyyymmdd-hhmm, fireAt the warned window's resetsAt plus 10 minutes (ISO 8601 with an offset), description "Resume the beat-em-up video work after the usage reset", title "Beat-em-up: resume the video after usage reset", and as the prompt the exact text between the lines "VIDEO-RESUME-PROMPT-START" and "VIDEO-RESUME-PROMPT-END" in /Users/arachne/repos/beat-em-up-PoC/.worktrees/video/docs/video/PLAN.md (read the file). Do this once per resetsAt.
4. Snapshot. If either window is at 95% or more, write HANDOFF-SNAPSHOT-VIDEO.md at the root of /Users/arachne/repos/beat-em-up-PoC/.worktrees/video (untracked; never commit it). It holds the time and the usage numbers; git status, git branch -vv and git worktree list; and for each worktree under .worktrees/ whose name is video or starts with mv-, its git status --short and git log --oneline -3.
5. Next check, from U: below 70, in 30 minutes (1800 s); 70 up to 85, in 15 minutes (900 s); 85 or more, in 5 minutes (300 s).
6. Fast burn. Estimate the rate from your previous check. If at that rate either window would reach 90% before that next check, check again in 5 minutes instead. If it would reach 90% within those 5 minutes, send the step 2 warning now (once per resetsAt).
7. Once a window you warned for has reset (its percentUsed is below 50 again), forget that warning.
8. Schedule the next check with ScheduleWakeup, passing this same prompt back.
Otherwise say nothing beyond one short line: the two percentages and the next check time. Never edit tracked files, run builds or start other work. If the video session tells you to end your loop, call ScheduleWakeup with stop: true.
```

### The resume prompt
The handoff's last step creates the resume task with this text, word for word.

VIDEO-RESUME-PROMPT-START
Resume the beat-em-up cinematic video work after a usage reset. The project is /Users/arachne/repos/beat-em-up-PoC; the video work is on branch video/cinematic-trailer in the worktree /Users/arachne/repos/beat-em-up-PoC/.worktrees/video, and its brief is /Users/arachne/repos/beat-em-up-PoC/.worktrees/video/docs/video/PLAN.md. Game-boy asked for this work to continue across usage limits without waiting for him, between his gates.
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch). If either the "5-hour limit" or the "Weekly · all models" window is still at 90% or more, create a copy of this task with mcp__scheduled-tasks__create_scheduled_task (a new taskId starting "beat-em-up-video-resume-", fireAt that window's resetsAt plus 10 minutes, the same prompt) and stop.
2. Call mcp__ccd_session_mgmt__list_sessions (load it with ToolSearch). If a session titled exactly "Beat-em-up: video session" is listed and not archived, send it with mcp__ccd_session_mgmt__send_message: "Scheduled resume: the usage window has reset. Check get_usage, make sure the video usage watcher is running (docs/video/PLAN.md §12), then resume from the newest entry in docs/video/HANDOFF.md." If the result says "delivered" or "queued", you're done: say so in one line and stop.
3. Otherwise you are the new video session. Switch your working folder to /Users/arachne/repos/beat-em-up-PoC/.worktrees/video first (mcp__ccd_directory__change_directory; load it with ToolSearch). Then follow the launch prompt in PLAN.md §12 exactly, from its step 2. Game-boy's approvals are the ones recorded in docs/video/HANDOFF.md.
VIDEO-RESUME-PROMPT-END
