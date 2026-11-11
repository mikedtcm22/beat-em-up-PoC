# Milestone 7 (proposed): the trailer's look, playable

**Status:** a plan for Game-boy's review, written 2026-11-10. Nothing is built. Work starts only on his go.
**Budget table:** [.claude/cfo/plan.md](../../.claude/cfo/plan.md) holds every task with its model, effort and done-when. This file holds the reasoning, the gates and the decisions.

## 1. What the trailer is, and what that means

- The trailer (`gameplay-trailer.mp4`, 33.6 s) is this game's own bot-played footage, repainted offline: one Gemini-painted keyframe per shot, then Runway Aleph restyled each clip to match it. Its end card says so ("In-engine gameplay, AI-restyled").
- That repaint takes minutes per second of video. It can't run while someone plays. A real-time neural filter is not an option either: nothing published reaches 1080p at 60 fps, and Godot has no inference runtime.
- So the route is to **move the drawing out of the filter and into the game's assets**: the same painter (Gemini) paints the textures, faces, skies and effect sheets once, and the game's shaders and lights are retuned to show them the way the trailer does.
- The video session already tried a code-only version of this look in the engine ("Plan A", five rounds). It teaches us what works and what doesn't:
  - **Read as drawn:** painted skies, fire, smoke and backdrop plates; the night, dusk and fire colour scripts.
  - **Still read as 3D:** primitive shapes (mitten fists, cylinder arms, box buildings), one outline weight with no inner lines, rims of constant width, exactly repeated windows and bricks, and faces with nothing drawn on them.
  - Its best blind-judge score was 0.78 to 0.93 (1.0 means "looks 3D"; the two reference videos score 0.04 to 0.22). The finished trailer itself was never judged; its review said about 75% of screen time reads as drawn.

## 2. The gap today

| Element | Trailer | Game today (M6) | Kind of work |
|---|---|---|---|
| Light and colour | Night street in indigo with sodium-orange lamps; dusk roof in peach and lilac; boss roof against a red fire wall. Figures are dark with one orange rim. | One neutral grey daylight; saturated character colours. | Lighting, tuning |
| Faces | Drawn: brows, nose line, mouth, jaw shadow. | A flat swatch with ink creases; no eyes. | Painted textures |
| Ink | Heavy outer line that tapers, thin inner fold lines, hatching on Ox. | One constant hull line on characters; thin edge lines on the world. | Shader, textures |
| Shapes | Chunky stitched gloves, puffy vests, hooded Ox. | Cylinder hands, block gloves. | Models |
| World surfaces | Flat painted planes with sparse brick hints, cracks, lit windows. | One tiled trim sheet; noisy brick and planks. | Painted textures, kit variation |
| Sky and backdrop | Painted skyline, sun disc, fire cloud with embers. | Flat procedural sky. | Painted layers |
| Effects | Outlined steam, sprite fire, embers, radial speed lines. | A white star burst and word art. | 2D flipbooks |
| HUD and titles | White condensed type with a red underline. | Cream HP panel and a debug line. | UI restyle |

## 3. Decisions in this plan (mine, open to change)

- **D1. Assets carry the drawing; shaders only present it.** Painted albedo textures with lines, shadow shapes and faces baked in. No full-screen restyle filter, no depth of field, no Kuwahara blur.
- **D2. A look profile, not a replacement.** A tunable `look_profile` (`m6` or `trailer`) selects materials, lights and effects. M6's look and its 2076 tests stay as they are; the trailer look gets its own tests. A debug key switches profiles in play, so every build is a side-by-side. The default flips to `trailer` only at sign-off.
- **D3. A slice first, with two arms.** The riskiest assumption is that painted textures on our meshes read as drawn in motion from a first-person camera. The slice tests it on the Punk and on the player's own arms and gloves (they fill a third of the screen, and the video session's judges named them the worst tell) in one stretch of the night street. The Punk has two arms:
  - Arm A: Gemini paint projected onto the current Punk mesh.
  - Arm B: a new Tripo Punk generated from the trailer's design (better fists and silhouette), then the same paint.
  - The cheaper arm that passes the gate wins and sets the route for every other character.
- **D4. One canonical design per character and place,** taken from the trailer frame where it looks best (the trailer changes designs between shots). My picks are in §5, question 2.
- **D5. Reuse the video session's work by reading its branch** (`video/cinematic-trailer`): the colour scripts, the painted-sky, flame, contact-shadow and haze shaders, the paint tools (`blender_asset.py`, `art_paint.py`, the paint path of `cine_toon`), the Gemini matte workflow, and the style meter. Gemini supplies palettes, surfaces, faces and fold references; faces stay on the drawn route, because turnaround views don't agree with each other well enough to project whole. The game session only reads that branch; it never writes in `.worktrees/video` or `.worktrees/mv-*`.
- **D6. What we won't copy:** the 24 fps base (gameplay stays at 60 Hz; only effects and smears hold on twos), Runway's frame-to-frame boil, faces that morph, the blurred mush on fast motion, third-person slow-motion cameras, and a HUD-less screen (the HUD stays, restyled).
- **D7. Measured gates, same judge.** Before building, the blind judge scores the trailer's own frames (fixed prompt, fixed frame set, same encode, three runs) to set the bar. Each gate then needs: the game's stills and 2 s clips, in third person and first person, within 0.10 of that bar, and frame time no more than 10% over M6 on the dev machine by M6's method.
- **D8. Models by role.** Fable only for the design calls and the gate decisions. Opus for integration and visual review. Sonnet for builders and fixers. Haiku for scouts and mechanical edits.

## 4. Phases and gates

**Phase 0: lock the target** (about 15% of a 5-hour window)
- The look target sheet: canonical frames, the palette per area, the do-not-copy list.
- The judge and style meter ported into `tools/look/`, and the bar set from the trailer's own frames.
- The `look_profile` switch in two parts (lights and effects; character art swap), with M6 unchanged under it.

**Phase 1: the slice** (50 to 70% of one window, with a handoff point at the merge)
- Seven builders, each owning its own files: night-street light, sky and contact shadows; the shaders (one owner: paint path, ink weight, rim); Punk arm A; Punk arm B; the player's arms and gloves; the street stretch's painted surfaces; steam and fire.
- Then: merge, suite, one recording, my look at full-size stills, the blind judge, the frame-time check, one fix wave.
- **Gate 1 (Game-boy):** he plays the slice, switches looks with the debug key, and says go, adjust or stop. A side-by-side reel goes with the DM.

**Phase 2: the roll-out** (two to three windows, in two build waves of four)
- Characters by the winning arm: Thug, Kicker, Bruiser, Ox, and the player's arms and gloves.
- Areas: the rest of the street, the dusk roofs, the boss roof with its fire wall.
- Effects, HUD and titles, the Ox name card; the crowd and training rooms adopt the profile.
- Then one review round (three Opus visual lenses, one Sonnet code lens), one fix wave, a targeted re-check, the judge and frame time again.
- **Gate 2 (Game-boy):** he plays Mission 1 start to finish in the trailer look and signs off the PR.

## 5. What I need from Game-boy before starting

1. **Order of milestones.** I propose this becomes Milestone 7, and the old M7 (performance target, Windows export) becomes M8, since M8 should measure the final art. PR #6 is still unsigned; I'd branch `m7/trailer-look` from its tip. Sign off PR #6 first, or branch now?
2. **Canonical designs.** Punk: grey cap, dark puffy vest (trailer at 15 s). Ox: grey hooded brute with a belly plate and stitched gloves (26 s). Player: grey sleeves, dark gloves (6 s). Kicker: flat cap and vest (14 s). Street as at 2 s, roof as at 14 s, fire as at 19 s. This drops M6's yellow cap, teal vest and orange Ox gloves. A one-page sheet comes first in Phase 0 for his yes.
3. **The look bible's limits.** The trailer breaks two M4 rules: environment saturation capped at 0.30, and no bloom except on effects. I'd lift both for the `trailer` profile and record it in README.
4. **Spend.** Gemini: up to $35 (about 250 images; the slice uses at most $8). Tripo: the slice's arm B costs 55 of the 355 credits left. If arm B wins, the roll-out needs about 500 more credits than we have. Runway: none.
5. **What "the same standard" means.** A still from the game should be hard to tell from a trailer still. In motion the game will be steadier and cleaner than the trailer, because nothing is redrawn per frame. If that's not the bar he means, I need to know before the slice.

## 6. Risks

- **Painted textures may slide or seam on deforming meshes.** The slice exists to find this out for 55 credits and one window.
- **First-person arms are the hardest case:** they fill a third of the screen, and their current UV layout has collapsed slivers. They are in the slice, and Gate 1 must pass on first-person stills.
- **Frame time.** M6 is already 15% over its pre-art baseline on the M1. Painted textures cost almost nothing; flipbook overdraw and a second ink pass do. Each gate measures it.
- **The trailer is not a consistent target.** That's why §5 question 2 comes first.
