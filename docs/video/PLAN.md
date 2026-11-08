# Cinematic gameplay video: the operations plan

Written 2026-11-08 by the planning lead (Opus 5.5, account at 78% weekly) for a **second Claude account that starts with an empty usage limit**. Game-boy asked for a 30-45 s cinematic gameplay video of the PoC, drawn in the visual style of two reference videos. This file is the whole brief: the goal, the style target, the method, the phases and gates, the operations rules, and the prompts that start and resume the session (§12).

## 1. The goal

**The prime directive, Game-boy's one non-negotiable:** the finished video has the same visual style as the two reference videos. If it doesn't, the video is not done, whatever else is true.

| | Post | Video | Made with |
| --- | --- | --- | --- |
| **Ref 1** | Goyart.studio, "ANAKIN VS OBI-WAN" ([x.com](https://x.com/Goyart_studio/status/2118343353435594814)) | 28 s, 2560×1440 | AI ("AI cinematic creator"); tools not named |
| **Ref 2** | Mike Miller (pt5films), "ANAKIN" ([x.com](https://x.com/pt5films/status/2118780239904231736)) | 58.5 s, 1280×720, 24 fps | "Midjourney and @dreamina_ai" |

**What the video shows:** almost only the gameplay built in Milestones 1-6. That's first-person combat against the five enemy types and Ox Pellerin, in the street, on the roofs and on the boss roof. A few cinematic shots re-frame the same real gameplay (an establishing shot, the boss reveal, a slow-motion knock-off). Nothing is animated by hand.

**What it isn't:** a change to the game. The game keeps its real-time look. Everything new is video-only and lives under `video/`, `tools/video/` and `docs/video/`. Nothing under `game/` changes, and the 2076-test suite stays green. A hook in `game/` would be a last resort: off by default, and listed for Game-boy.

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
| **P6 Camera** | Cinematic framing: low angles, over-the-shoulders, wides with small figures, close-ups. Shallow depth of field, motion blur or anime smears, shots of 1.5-3.5 s, and speed ramps on big hits. |
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
Today's look: `captures/m6-final/run_street/sheets/overview_01.png` (the street and a Punk) and `captures/m6-vf2-final/r_boss/sheets/r_boss/overview_01.png` (Ox).
- **Characters:** Tripo models of up to 30k triangles, with one shared palette atlas, shaded with M4's toon look: three flat bands and a violet shadow tint.
- **Lines:** an inverted-hull outline at a uniform 3.75 px, and thin edge lines on the environment.
- **World:** a muted dusk grade, and a trim-sheet city.
- **Effects and UI:** comic hit effects (impact frames, speed lines, starbursts), and the HUD.
- **Captures:** 1280×720 or 1600×900.

**The gap, pillar by pillar:**
- **P1:** the lines are uniform, with no inner lines.
- **P2:** the fills are flat.
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
- The game's own simulation plays every shot, from scripted bot acts, as the review captures already do. Movie Maker records it offline, frame by frame.
- Because nothing has to run in real time, the video build can use what the game can't afford: 2× supersampling, volumetric fog, thousands of particles, subdivided models, high-resolution painted textures and a stack of custom post passes.
- Claude writes the painting as code: the shaders, the textures, the line work, the skies, the particles, the grade and the edit.

Claude doesn't paint pictures freehand. It paints the rules a painter follows, and the code applies them the same way to every frame:
- where the ink goes and how heavy it is;
- how the shadows are shaped, and what colour the darks are;
- where the haze, smoke and embers are.

That consistency is exactly what hand-drawn animation needs, and what AI video struggles with.

### Plan A: the painted render, in Godot (preferred)
A video-only "cine" render profile on top of the game, in six parts.
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
   - Inner lines come from an ink texture per character. Folds and creases are baked from curvature; Claude draws the features (brows, eye lines, nose, mouth, scars).
   - An optional sketch mode for close-ups draws 2-3 jittered strokes with overshoot, re-seeded at 12 fps.
4. **Atmosphere.**
   - Painted skies made by code: domain-warped noise quantized into brush bands, and a sun or moon disc with a halo.
   - Painted smoke cards.
   - GPU particles for embers, sparks (extra bursts on hits, from `CombatEvents`), dust and steam, with every sprite generated by code.
5. **Lens and finish.**
   - A palette transfer from the reference frames into a 3D LUT. Code measures both and builds the LUT in `tools/gen_lut.gd`'s format.
   - A vignette, a little chromatic aberration, and grain.
   - The game's own impact frames and speed lines, restyled.
6. **Assets.** Video-only upgrades through headless Blender (never the Blender MCP):
   - subdivided character meshes;
   - face normals transferred from a smooth proxy, for clean anime face shadows;
   - the ink textures, and a painted albedo.

**The odds (the planning lead's estimate):**
- **High** for P3, P4, P5, P6 and P8. Light, colour, atmosphere, camera and coherence are fully in our hands.
- **Good** for P2, and for ref 2's clean graphic look.
- **Lowest** for P1 and P7 in close-ups: hand-drawn line quality and drawn faces.
- **Overall,** roughly a one-in-three to one-in-two chance that Plan A alone passes. So Gate 2 comes early and cheap, and the shot list leans on silhouettes, backlight and mid shots, which hide the weakest pillars.

### The fallbacks, in order (each needs Game-boy's go at Gate 2)
- **A2: Blender line art,** if the ink is the gap. Still all code; about two builders.
  1. A replay recorder writes each take's bone poses, transforms and camera, frame by frame. The game and the Blender rigs share one skeleton.
  2. Headless Blender re-renders the characters with Grease Pencil Line Art: contours, creases and intersections, with thickness and noise modifiers.
  3. The composite lays those lines over the Godot frames.
- **A+: AI-painted static assets,** if the paint or the detail is the gap.
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
1. The lead picks six game frames that match six reference frames shot for shot.
2. If Game-boy allows it (D2), Gemini paints over each one in the reference style, with the reference frames as style references.
3. Game-boy picks or corrects these targets.

The targets are never in the video. They're the bar that every look-dev still is judged against. Cost: about $2-4.

### Hard rules
- **No reference pixels in the video.** No patch transfer from their frames, and no tracing. The references are for analysis, colour measurement and judging, and (with D2) as style references for the look-dev targets only.
- **Nothing from Star Wars:** no sabers, characters or typography. And no imitation of either creator's watermark or title card.
- **Never the Blender MCP tools** (`mcp__blender__*`): they drive Game-boy's own Blender. The pipeline runs Blender headless.
- **Paid services only through the project's tools,** within a cap in their ledgers: Gemini through `tools/gemini_image.py`, Tripo through `tools/pipeline/tripo.py`, ElevenLabs through `tools/audio/`. Never print, log or write a key.
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
| 10 | 0:21-0:25 | Boss roof | Cine: low angle, slow push-in | Ox Pellerin, hooded, before fire and smoke, with embers; he raises his gloves. A name card: "OX PELLERIN" | Ref 1's Anakin before the fire (5.3) |
| 11 | 0:25-0:31 | Boss roof | FP | Block Ox's heavy, then a perfect block, the spinning backfist (P P · P), and the haymaker held and released | |
| 12 | 0:31-0:34 | Boss roof | Cine close-up, 0.25× | The haymaker meets Ox's face, with sparks and the impact frame | Ref 1's face-off (27.3) |
| 13 | 0:34-0:37 | Boss roof | FP | Ox falls (ragdoll); the embers settle; cut to black on the hit sound | |
| 14 | 0:37-0:41 | | Title card | The title (D5) over drifting embers | Ref 2's title card (1.2) |

The lead can swap in stronger beats found in Phase 2's blocking, as long as the mix holds:
- at least 70% first-person gameplay;
- every enemy type, every location, and the boss.

In cine shots the player's whole body shows (the model the KO view uses), so it needs the same upgrades as the enemies.

### Sound
- **Effects:** the game's own ElevenLabs bank (hits, blocks, whooshes, weapons, voices). Code places them from the takes' logs, and mixes them by rules. The bots already log the hits of each act; the trailer acts add a frame number to every event.
- **Music:** decision D4. The references are cut to music, so ours should be too.
- **Loudness:** about -14 LUFS integrated, with true peak below -1 dBTP.

### Text
- There's no HUD.
- The boss's name card and the end title use a bold condensed face. Pick a font with an open licence; none is in the project.
- Optionally, one subtitled line from Ox in ref 1's subtitle style, only if Game-boy wants it.

### Format
- Movie Maker captures at 60 fps, the game's fixed rate.
- The finish converts to 24 fps at 2560×1440: a two-frame blend on fast motion, or picked frames, whichever looks closer to the references in look-dev.
- Encoding: H.264 High at about 30-40 Mbit/s, with AAC at 320 kbit/s. Plus a 1920×1080 copy.
- Ref 2 measured 24 fps. Check ref 1 with `ffprobe` after the download.
- Check that a 2560×1440 capture really comes out at 2560×1440 on this Mac: the display may clamp the window. If it does, render the 3D in a fixed-size `SubViewport` and write its frames from a script instead of Movie Maker.

## 6. Phases, packages and gates

The estimates are in % of a 5-hour window on the seat Game-boy has used since M5. Re-measure: the second account's seat may differ.

### Phase 0: set-up and the target (the lead only, about 5%)
1. **Set up the session** as §7 says: title, watcher, worktree, disk.
2. **Download the two references** (D1) into `captures/video/ref/ref1/` and `captures/video/ref/ref2/`, each in its own new folder. The URLs are in §12. Run `ffprobe` on both.
3. **Extract the gates' reference frames** at full resolution (§2's times), and contact sheets:
   `ffmpeg -ss <t> -i ref1.mp4 -frames:v 1 ref1_<t>.png`.
4. **Measure the references.** For each frame, measure:
   - the luminance histogram;
   - the saturation and hue of the darkest third, and the key's hue;
   - the edge density.

   Write the numbers into `docs/video/STYLE.md`, with the times but not the images. They're the style meter's targets (Phase 1).
5. **Pick six game frames** that match six reference frames shot for shot. Take them from existing captures (`captures/m6-final/`, `captures/m6-vf2-final/`), and record only what's missing.
   - Ox's close-up for 0.9;
   - Ox before the boss roof for 5.3;
   - a fist in the foreground with a Punk at 3 m for 7.2;
   - a first-person shot of a Kicker beside a lamp for 37.4;
   - the street wide for 42.0;
   - a roof-edge silhouette for 50.5.
6. **Gate 1.** Make the targets (D2), then DM Game-boy the six pairs (reference | target) and ask: "Is this the style?" Start Phase 1 meanwhile.

**The paint-over job,** for `tools/gemini_image.py`:
- `refs`: [our frame, two reference frames];
- `aspect`: "16:9";
- `prompt`: "Repaint the first image in the exact art style of the other images: [the §2 description of that reference]. Keep the first image's composition, camera, characters, poses, clothes and every object; change only how it is drawn, painted and lit. No text, no logos, nothing from Star Wars."

### Phase 1: look-dev (about 35-50%, then 15-20% for each extra round)
Three builders (Sonnet, high effort) work in their own worktrees off `video/cinematic-trailer`, alongside the lead. Do the light, colour and atmosphere first: they make the biggest visible jump soonest, and they calibrate the rest.

**LD-RENDER: the stage, the light, the atmosphere.** It owns `video/` (the scaffold, `CineDirector`, the shot scenes), the per-location rigs in `video/look/`, and `tools/video/shoot.sh`.
- **Shot scenes.** `video/shots/<shot>.tscn` instances a game room (mission1's street, a roof, or the boss roof) and adds a `CineDirector`, which:
  - hides the HUD and the debug overlays;
  - applies a `CineLook` resource: the location's environment, lights, fog volumes, sky, depth of field, glow and particles. Every number goes in the `.tres`, none in scripts;
  - optionally adds a `CineCamera` for the non-FP shots: a keyframed path, a look-at target, and keys for the FOV and the focus.
- **The video preset.** Presentation tunables (FOV, camera shake, the look values) go in a `tuning/video.json` preset. Never gameplay values.
- **Atmosphere:**
  - volumetric fog and fog volumes;
  - the painted sky shader (code-made clouds, a sun or moon with a halo);
  - smoke cards;
  - GPU particles for embers, dust, steam and hit sparks, subscribing to `CombatEvents` as presentation does.
- **Determinism.** Seed every RNG the shot touches (`vfx_director.gd` randomizes today, and the audio director too), so a shot re-renders identically.
- **`tools/video/shoot.sh <shot> [--res 2560x1440] [--from f --to f]`.** Movie Maker writes a PNG sequence under `captures/video/takes/<shot>/`. Encode it at once to a mezzanine file (`ffmpeg -c:v libx264 -crf 8 -preset slow -pix_fmt yuv444p`), then delete the PNGs, to spare the disk.
- **Tests:** a smoke test per shot scene in `video/tests/` (run with `-gdir=res://video/tests`, so the main suite doesn't grow).
- **Done when** the six Gate 1 shots render at 2560×1440 with the new light and atmosphere, still on the old toon materials.

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
- **Post passes** as `CompositorEffect` compute shaders (check the 4.7 API with `godot --headless --doctool`):
  - an anisotropic Kuwahara filter for painterly backgrounds, masked off the characters by stencil or a mask pass, so their ink stays crisp;
  - paper grain, a vignette, and chromatic aberration.
- **`tools/video/palette_lut.py`.** It measures a reference frame and one of our frames, and writes a LUT that moves ours toward theirs. Use a smooth transfer (Reinhard means and spreads per value band, or Pitié's iterative distribution transfer). The `CineLook` names the LUT.
- **Tuning by measurement.** A tool script renders one still under a sweep of `CineLook` values and scores each with the style meter. The lead then looks only at the best few.
- **Done when** one character (the Punk) and one street corner pass the lead's look beside the reference frames, at first-person distance and in a close-up.

**LD-ASSET: the upgraded cast.** It owns `tools/video/blender_*.py` and `assets/video/`. These are exports only; the sources stay where they are.
- **Headless Blender** on each character's source in `assets/source/characters/<name>/`, one Blender process at a time:
  `blender --background --factory-startup --python-exit-code 1 --python ...`
  For each character, make:
  - a subdivided video mesh on the same skeleton;
  - face normals transferred from an ellipsoid proxy;
  - curvature and AO baked into ink and paint masks;
  - a painted albedo.
- **Claude-drawn features.** For each face:
  1. render a front view and the UV layout;
  2. draw the feature lines as SVG in UV space: brows, eye lines, lids, nose, mouth, scars, the Kicker's mask edge;
  3. bake them into the ink texture.

  Keep each character's design (the concept sheets are in `assets/source/concepts/m6/sheets/`). This adds drawing; it isn't a redesign.
- **The player's first-person arms and wraps** get the same treatment: they're in most shots.
- **Done when** the Punk and Ox render in Godot with the video mesh and textures, in a close-up and at 1-3 m.

**The lead:**
1. Merges the packages, and renders the Gate 2 set: the six Gate 1 shots, plus one 5 s moving shot (first person, P P P P on a Punk under a street lamp).
2. Looks first, at full resolution, beside the reference frames and the targets (process rule 1).
3. Runs one review round: one Opus visual lens with the rubric, and one Sonnet code lens (coherence, determinism, no diff under `game/`).
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
- **The internal bar:** every pillar at 2 or more, with a mean of 2.4 or more. Then DM Game-boy the pairs and the 5 s clip: "Does this match the references' style?"
- **His answer:**
  - **Pass:** go to Phase 2.
  - **Close:** run another look-dev round on the lowest pillars. At most two more rounds, about 40% in all.
  - **No, or still failing after the third round:** propose the fallback that fixes the failing pillars, with its cost (A2 for the lines, A+ for the paint and the detail, B for the rest), and wait for his choice.
- **While waiting for him,** start SHOTS (Phase 2): its acts and cameras don't depend on the look.

### Phase 2: the shots (about 15-20%)
**SHOTS (one Sonnet builder).** It owns `video/acts/trailer_acts.gd` and `video/shots/`.
- **One act per shot in §5's list,** built from the existing bot tools and the `CineCamera`:
  - the combo bot's inputs;
  - `ShowcaseRunner` for enemy beats;
  - god mode, Freeze AI and F4's spawn;
  - the level bot's `--from`/`--to` arenas, to start in the right place.
- **Slow motion** goes through `TimeController`, the one module allowed to write time.
- **Logs:** each act logs its hits and events with frame numbers, for the sound.
- **The blocking pass comes first,** at 1280×720 in the cine look. It's cheap, and the lead cuts it into an animatic with temporary timing.
- **Then the final renders,** at 2560×1440, one shot at a time, in the background.

**Gate 3: the animatic.** The cut at preview quality, with temporary sound. Game-boy checks the beats and the pacing. It's optional: skip it if he says so in the launch prompt.

### Phase 3: the finish (about 20-25%)
**EDIT (one Sonnet builder, or the lead).** It owns `video/edit.json` and `tools/video/assemble.py`:
- the cut list: for each shot, its in and out points, speed and transition;
- titles rendered by code, with PIL and the chosen font, or a Godot scene;
- the final grade and grain, and the 60→24 conversion;
- the soundtrack: effects placed from the act logs, the music, and the mix (`ffmpeg`'s `loudnorm`);
- the exports.

**The review:** one round of three lenses (process rule 2):
- the style match against the references (Opus);
- the gameplay's legibility and feel (Opus);
- the technical side (Sonnet): flicker, swimming, sync, encoding, loudness.

Then one fix wave, and a targeted re-check.

**Gate 4: the sign-off.** DM Game-boy:
- the 2560×1440 file (as a GitHub Release asset on the branch, or the file itself in the DM), and the 1920×1080 copy;
- a style proof: a contact sheet of our frames beside the reference frames.

He decides.

### Phase 4: the record (the lead, under 5%)
1. Write `docs/video/LEARNINGS.md` (§11).
2. Open the PR for the video tooling. Never merge it without Game-boy's word.

## 7. Operations

### The session
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
- **Workflows.** The runners take these arguments:
  - `milestone: "v"`, which gives branches `mv/<key>`, worktrees `.worktrees/mv-<key>` and commit subjects `Mv <key>: ...`;
  - `plan: "docs/video/PLAN.md"` and `base: "video/cinematic-trailer"`;
  - a `note` saying that cine shots count, not only first person. The runners' briefs say otherwise, so the note has to override them.

  Keep the args files in `docs/video/`. The launch prompt says whether Game-boy allows workflows; without them, run the builders as Sonnet subagents with the same briefs.
- **Usage:** docs/HANDOFF.md, "Usage rules for the working session". Size each launch to the headroom below 90%, hand off at the watcher's 90%, and commit `wip:` often.
- **Comms:** DM Game-boy on Slack (Michael, `U0AQMKKBL93`, DM `D0AQUKX5DB6`) at each gate and whenever you're blocked on him; carry on with anything not blocked. If this account has no Slack tool, ask in the session's chat.

### Git
- **The branch** is `video/cinematic-trailer`, cut from `m6/full-art-audio` at 056e697 (this plan is its first commit), in the worktree `.worktrees/video`. Open the session in that folder, so its CLAUDE.md (with the video session's note) applies, and run `godot --headless --import --quit` there first.
- **Builders** branch `mv/<key>` from it, and the lead merges them in.
- **Commit messages** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `captures/`, the references, or frames from them.
- **If PR #6 merges first,** rebase the video branch on `main` at a quiet moment.
- **Never touch** `m6/*` or `main`.
- **One PR at the end;** never merge it without Game-boy's word.

### The shared machine
An Apple M1 with 8 GB of RAM and 19 GB of disk free on 2026-11-08.
- **One heavy job at a time.** The game's working session may run the 7-minute suite or Movie Maker at the same time. Before a render, check `pgrep -fl godot`.
  - Run at most one Movie Maker or Blender render from this session at a time, in the background, under `nice -n 10`.
  - Builders use their Godot slots as the runners count them.
- **The disk.**
  - Renders go shot by shot to mezzanine files, and the PNGs are deleted at once. `captures/video/` keeps only the current takes.
  - Free space before Phase 1 (D3). `captures/` holds 43 GB, and `.worktrees/` holds 30 GB of merged and review checkouts.
- **The worktrees.** The main HANDOFF asks the game's session never to prune `.worktrees/video` or `.worktrees/mv-*`.

### The budget (an estimate)

| Phase | % of a 5-hour window |
| --- | --- |
| Phase 0: set-up and the target | about 5% |
| Phase 1: look-dev | 35-50%, plus 15-20% for each extra round |
| Phase 2: the shots | 15-20% |
| Phase 3: the finish | 20-25% |
| Phase 4: the record | under 5% |
| **In all** | about 80-105% with one look-dev round; about 1.4 windows with three |

**Paid:** about $2-4 of Gemini targets (D2). Plan B only on Game-boy's go.

## 8. Decisions for Game-boy, and the default the session takes

| # | Decision | Default |
| --- | --- | --- |
| D1 | Downloading the two reference MP4s (about 36 MB and 16 MB, from video.twimg.com) for frame analysis, and one SIL-OFL font for the titles. Never published or committed | Yes, if the launch prompt approves it |
| D2 | About $2-4 of Gemini paint-overs as look-dev targets (never in the video) | Yes, if the launch prompt approves it |
| D3 | Freeing disk: deleting `captures/m5-*`, `captures/m6-feedback*`, `m6-verify-final`, `m6-worktrees`, `m4*` and `m3_evidence` (about 33 GB), and the merged and review worktrees under `.worktrees/` (about 30 GB) | Ask first. Until he answers, do look-dev at 1920×1080 and keep only the current takes; the final renders need the space |
| D4 | The music: (a) ElevenLabs music, within a credit cap; (b) a licensed track he supplies; (c) effects only | (a) if his ElevenLabs plan has music by API; otherwise (c) |
| D5 | The end card's title and label | "FIRST-PERSON BEAT-EM-UP", with a small line: "Proof of concept. In-engine gameplay, cinematic render." (The video's look isn't the game's real-time look) |
| D6 | Plan B's service and spending cap | Asked only at Gate 2, with a recommendation |
| D7 | A+: Gemini or Tripo for textures, backdrops and a close-up bust | Asked only at Gate 2 |
| D8 | Workflows for this session | Yes, if the launch prompt says so |
| D9 | The animatic gate (Gate 3) | Yes |

## 9. Risks
- **The style gap in close-ups (P1, P7).**
  - The shot list keeps close-ups to two, and lights them for silhouette and rim light.
  - LD-ASSET draws the features.
  - A2 and A+ are ready, and Gate 2 comes early.
- **It reads as a filter over a 3D game (P8).** The paint is in object space, there's no screen-space noise on fills, and only the lines boil. The coherence lens checks this in motion.
- **The gameplay drifts.** Every action comes from the game's simulation; cine cameras only re-frame it. Under Plan B, keep the first-person gameplay shots from Plan A if the restyle bends the action.
- **Determinism.**
  - Seed the effects and audio RNGs in video shots, and do a warm-up run, as the crowd test does.
  - Before relying on two cameras on one action, compare two renders of a shot frame by frame.
  - If that doesn't hold, build A2's replay recorder for those shots.
- **The machine:** 8 GB and a nearly full disk, shared with the main session. One render at a time, mezzanine files, and D3.
- **Copyright:** match the style, never use their pixels; nothing from Star Wars; licensed music.
- **Usage limits:** the watcher, the video HANDOFF and the resume task.
- **The main session.** This session has its own title, branch, worktree, HANDOFF and watcher, and never touches `m6/*` or `main`.

## 10. Why this can work
- **The game is a motion-capture stage.** The bots perform real gameplay on demand, the same way every time, so we can shoot takes and coverage like a film crew.
- **Offline rendering lifts every real-time limit,** on the same scenes, characters and effects the game already has.
- **The references are rule-driven styles.** They use 2-3 values, saturated darks, one key with a complementary accent, haze, and ink that follows the light. Rules like these are what code is good at, and what AI video keeps inconsistent from shot to shot.
- **Matching is measured, not guessed.** The palette transfer and the style meter give objective steps between Game-boy's looks. The targets turn "the same style" into pictures he has approved.
- **Claude draws only where drawing is cheap:** a few feature lines per face in UV space, placed on a rendered guide, after which the 3D animation carries them through every frame.

## 11. What to record in LEARNINGS.md
- **For each phase:** the usage it cost, the wall-clock time, and what the gates said.
- **What moved each pillar most,** per unit of work, and what didn't move it.
- **Which steps a single Claude session could do alone next time,** and which needed builders, Opus looks or Game-boy.
- **The reusable kit:** the shot scenes, the cine look, the style meter, the LUT transfer, the SFX placement, the assembler, and how to point them at a new game or scene.
- **If a fallback was used:** why, what it cost, and what Plan A would need to avoid it.

## 12. Prompts and links

### The reference links
- **Ref 1:** <https://x.com/Goyart_studio/status/2118343353435594814>
  - MP4 at 2560×1440: <https://video.twimg.com/amplify_video/2118343216424529921/vid/avc1/2560x1440/mNTZELBj8td17g5a.mp4?tag=29>
- **Ref 2:** <https://x.com/pt5films/status/2118780239904231736>
  - MP4 at 1280×720: <https://video.twimg.com/amplify_video/2118779853529075712/vid/avc1/1280x720/WCE5E1mv45RDKKr3.mp4?tag=29>
- **If the MP4 links expire,** re-read them from `https://api.fxtwitter.com/<handle>/status/<id>`.

### The launch prompt
Game-boy edits the APPROVALS block, then pastes this into the second account's session.

```
You're the video session for a Godot 4.7.2 project: a first-person beat-em-up proof of concept at /Users/arachne/repos/beat-em-up-PoC (GitHub: mikedtcm22/beat-em-up-PoC). I'm Game-boy, the owner. Milestones 1-6 are built; the game's own working session (on another account) may be running at the same time. Your job is different: make a 30-45 s cinematic gameplay video of the game whose visual style matches two reference videos. The whole brief is docs/video/PLAN.md on branch video/cinematic-trailer, checked out in the worktree /Users/arachne/repos/beat-em-up-PoC/.worktrees/video. Work there: run every command in that folder unless the plan names another.

THE PRIME DIRECTIVE: the video must have the same visual style as the two reference videos (PLAN.md §1-2). If it doesn't, it isn't done. I'd rather you painted it yourself with code (Plan A); AI video tools are the fallback, and only with my go.

Start by doing these, in order:
1. Rename this session "Beat-em-up: video session" (mcp__ccd_session_mgmt__set_session_title).
2. Read CLAUDE.md, then .worktrees/video/docs/video/PLAN.md whole, then .worktrees/video/docs/video/HANDOFF.md if it exists (its newest entry is where you pick up). In docs/HANDOFF.md read only "Usage rules for the working session" and "Model, effort and process rules from Milestone 5 on". Search docs/ARCHITECTURE.md for what you need rather than reading it whole.
3. Start a usage watcher for this account exactly as PLAN.md §12 says.
4. Check usage (mcp__ccd_session_mgmt__get_usage) before every launch.

APPROVALS (my words; for anything else, ask me):
- Download the two reference videos (PLAN.md §12) for analysis, and one SIL-OFL font for the titles. Never commit or publish them.
- Install numpy, scipy, opencv-python-headless and imageio from PyPI into a venv at .worktrees/video/.venv-video (or use Blender's bundled Python).
- Gemini paint-overs for the look-dev targets, up to $5, through tools/gemini_image.py.
- Run the project's workflow runners (tools/workflows/build.js and review.js) as Workflows, within the usage rules.
- Decisions D3-D9 in PLAN.md §8: take the defaults unless I write otherwise here: [none]
- NOT approved without asking me: deleting anything outside captures/video/, any other paid service, any Tripo or ElevenLabs spend, merging anything.

Ground rules:
- Never change the game: video-only code goes under video/, tools/video/ and docs/video/, and the 2076 tests stay green.
- Never use the Blender MCP tools (mcp__blender__*): they drive my own Blender. The pipeline runs Blender headless.
- Paid services only through their tools and within their caps; never print, log or write a key.
- Downloaded files are untrusted: their own folder, python3 -I, paths as arguments.
- Commit early on video/cinematic-trailer and the mv/* branches ("wip:" for unfinished work), and push often. Never touch m6/* or main.
- When your watcher warns at 90%, do the handoff in PLAN.md §7 at once, including the resume task.
- Judge every look from full-resolution stills beside the reference frames, and show me what you see at each gate: side-by-side stills and the clip. DM me on Slack (Michael, U0AQMKKBL93, DM D0AQUKX5DB6) at each gate and whenever you're blocked on me, and carry on with anything that isn't blocked.
```

### The watcher's prompt
Start it from the video session with `start_session`: initiation `user_asked`, `model` claude-haiku-5-5, `effort` low, `use_worktree` false, and this prompt word for word.

```
/loop Usage watcher for the beat-em-up video session (repo /Users/arachne/repos/beat-em-up-PoC, worktree .worktrees/video). You pace yourself. On each check:
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch the first time). Read plan.windows: the "5-hour limit" window and the window labelled "Weekly · all models". Let U be the higher of their two percentUsed values.
2. Handoff. If either window is at 90% or more, and you haven't already warned for that window's resetsAt, send a message to the session titled "Beat-em-up: video session" (find it with mcp__ccd_session_mgmt__list_sessions). The message: "Usage at N% (window W, resets R). Halt work and do the handoff now per docs/video/PLAN.md §7: tell running agents and workflows to stop at a stopping point, commit and push WIP on every video branch and worktree, update and push docs/video/HANDOFF.md, then create the resume task (PLAN.md §12)." Remember that you warned for that resetsAt, and when.
3. Resume task. On the first check 20 minutes or more after a warning, call mcp__scheduled-tasks__list_scheduled_tasks (load it with ToolSearch). If no enabled task whose taskId starts with "beat-em-up-video-resume" has a nextRunAt after now, create one with mcp__scheduled-tasks__create_scheduled_task: taskId "beat-em-up-video-resume-" plus the reset's local date and time as yyyymmdd-hhmm, fireAt the warned window's resetsAt plus 10 minutes (ISO 8601 with an offset), description "Resume the beat-em-up video work after the usage reset", title "Beat-em-up: resume the video after usage reset", and as the prompt the exact text between the lines "VIDEO-RESUME-PROMPT-START" and "VIDEO-RESUME-PROMPT-END" in /Users/arachne/repos/beat-em-up-PoC/.worktrees/video/docs/video/PLAN.md (read the file). Do this once per resetsAt.
4. Snapshot. If either window is at 95% or more, write HANDOFF-SNAPSHOT-VIDEO.md at the root of .worktrees/video (untracked; never commit it). It holds the time and the usage numbers; git status, git branch -vv and git worktree list; and for each worktree under .worktrees/ whose name is video or starts with mv-, its git status --short and git log --oneline -3.
5. Next check, from U: below 70, in 30 minutes (1800 s); 70 up to 85, in 15 minutes (900 s); 85 or more, in 5 minutes (300 s).
6. Fast burn. Estimate the rate from your previous check. If at that rate either window would reach 90% before that next check, check again in 5 minutes instead. If it would reach 90% within those 5 minutes, send the step 2 warning now (once per resetsAt).
7. Once a window you warned for has reset (its percentUsed is below 50 again), forget that warning.
8. Schedule the next check with ScheduleWakeup, passing this same prompt back.
Otherwise say nothing beyond one short line: the two percentages and the next check time. Never edit tracked files, run builds or start other work. If the video session tells you to end your loop, call ScheduleWakeup with stop: true.
```

### The resume prompt
The handoff's last step creates the resume task with this text, word for word.

VIDEO-RESUME-PROMPT-START
Resume the beat-em-up cinematic video work after a usage reset. The project is /Users/arachne/repos/beat-em-up-PoC; the video work is on branch video/cinematic-trailer in the worktree .worktrees/video, and its brief is .worktrees/video/docs/video/PLAN.md. Game-boy asked for this work to continue across usage limits without waiting for him, between his gates.
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch). If either the "5-hour limit" or the "Weekly · all models" window is still at 90% or more, create a copy of this task with mcp__scheduled-tasks__create_scheduled_task (a new taskId starting "beat-em-up-video-resume-", fireAt that window's resetsAt plus 10 minutes, the same prompt) and stop.
2. Call mcp__ccd_session_mgmt__list_sessions (load it with ToolSearch). If a session titled exactly "Beat-em-up: video session" is listed and not archived, send it with mcp__ccd_session_mgmt__send_message: "Scheduled resume: the usage window has reset. Check get_usage, make sure the video usage watcher is running (docs/video/PLAN.md §12), then resume from the newest entry in docs/video/HANDOFF.md." If the result says "delivered" or "queued", you're done: say so in one line and stop.
3. Otherwise you are the new video session: follow the launch prompt in .worktrees/video/docs/video/PLAN.md §12 exactly, starting with renaming this session "Beat-em-up: video session". Game-boy's approvals are the ones recorded in docs/video/HANDOFF.md.
VIDEO-RESUME-PROMPT-END
