# CONCEPTS: the images for Game-boy's M6 pick (Sonnet, medium; Gemini only; no Godot, no Tripo)

Milestone 6 (SPEC §12: all enemies and the boss, environment modules and set dressing, final SFX) has one pick pause. This package makes everything Game-boy picks from, in one go, so the lead can send it as one DM. The approved proposal is `docs/milestones/M6-proposal.md` (§2 "Phase 0", §3 D4-D5).

## What to make

All images go through `tools/gemini_image.py` from one jobs file, `assets/source/concepts/m6/concept_jobs.json`. Use model `gemini-3-pro-image` at size `2K`. **Ceiling: 30 generated images in all, retries included** (about $3-4).

Before writing a prompt, read `assets/source/concepts/concept_jobs.json`. Its job `punk_a_denim_vest` is the Street Punk Game-boy picked in M4, and its prompt is the house frame. Look at `assets/source/concepts/punk_a_denim_vest.jpg` once.

### 1. Characters: 3 concepts each for the Kicker, the Pipe Thug, the Bruiser and the boss (12 images, aspect 3:4)

**The frame.** Copy the Punk A prompt's whole frame word for word, then change only the role, palette and outfit sentences. The frame covers:
- original cel-shaded comic concept art: bold ink, two-tone tinted shadows, flat colours, no texture noise;
- chunky proportions with slightly oversized hands and feet;
- a plain light-grey background, nothing held, no text;
- a full-body FRONT view in an orthographic A-pose (arms about 40° down, hands open, feet shoulder-width apart), symmetrical, head to soles in frame.

Tripo builds the model from the picked design's front, side and back views later, so the pose and framing matter.

**Every character:**
- **Era:** a late-1980s street gang (SPEC §10): denim, leather, mohawks, track suits.
- **Face:** covered or simplified (shades, bandana, mask, cap low), so it reads at 1 m.
- **Colours:** 4-6 flat colours, and absolutely no red or pink. Red is reserved for blood, the warning and finisher accents.
- **Archetype colour:** each type keeps its M3 colour identity as its main colour, saturated (HSV saturation at least 0.5). Game-boy and the players have learned these:
  - Kicker: lime with near-black accents;
  - Pipe Thug: olive green with a yellow accent (its pipe is yellow);
  - Bruiser: purple with steel grey;
  - boss: charcoal with orange.
- **Silhouette:** it must read apart from the Punk (teal vest, yellow cap) and from each other at 2-10 m.
- **Variety:** the three concepts for a type are different directions (silhouette, outfit idea), not three colourings of one idea.

**The types** (roles from SPEC §7, README "Milestone 3 status"):
- **Kicker:** a fast, lean flanker. Jump kick and low sweep, about 1.8 m. Agile: a martial-arts street fighter or a breakdancer gang member, not a bruiser.
- **Pipe Thug:** the weapon carrier, about 1.8 m. Hands stay empty in the concept (the pipe is its own model), but its look says "carries a pipe": a belt loop or a holster strap is fine.
- **Bruiser:** the armored heavy, 2.05 m. Big, broad and slow, with visible padding or armor-like gear (it shrugs off light hits).
- **Boss:** 2.3 m, the level's boss. A shoulder charge, a ground pound and a grab and slam. At half health he calls in two Punks.
  - **The design must be original.** SPEC §1 forbids copying any Double Dragon character. The reference's boss (`reference/dd2-nes-mission1/notes.md`, screen 12) is "a huge masked heavy with spiked shoulder pads and a bare chest". Do not combine those traits.
  - Three distinct directions, for example a biker-gang chief, a dockyard enforcer, and an underground-fight champion. Pick your own if they're better.

**Names:** 3 original boss names, each with a one-line pitch that fits a concept. None may be the name of a character in any existing game or film. Search the web to check each one.

### 2. The second weapon: 3 designs (3 images, aspect 1:1)

- **Its role:** screen 11's "chain-like weapon" (`reference/encounters.md`, the "Weapons" line), an original object a late-80s street gang would carry.
- **Readability:** it must read from across a roof lying on the floor, and fit 3k triangles.
- **The image:** a product-style shot in the same comic style, on a light-grey background, no hands, no text.
- **Variety:** make at least two chain-like designs (for example a bike chain with a padlock, a tow chain with a hook). The third may be any original weapon if it's clearly better.
- **For each, one line on how it would swing.** The spec's numbers stay (SPEC §4: 10 a swing, a 3-hit chain, breaks after 8 hits, a throw for 15). What differs from the pipe is reach, arc and timing (proposal D5).
- No red.

### 3. Environment mood frames: 2 for the street and 2 for the roofs (4 images, aspect 16:9)

**The scenes:**
- **The street (arenas A1-A3):** a loading dock, a crate yard and a warehouse stair, with the parked car, chain-link gates and a rolling shutter as the arena barriers.
- **The roofs (A4-A7):** a terrace, a catwalk over a drop, a top roof with a chain-link fence and big shutters, and the 20 x 20 m boss roof. Water tanks, AC units, vents and skylights.
- Read `reference/encounters.md` for each arena's location and barriers. Use `reference/dd2-nes-mission1/*.jpg` **only** for the type of place. Never copy or trace a screen (SPEC §1).

**Every frame:**
- **Viewpoint:** first-person eye level (about 1.5 m) down a 10-14 m wide lane, at dusk. No characters, or at most one tiny silhouette for scale.
- **Look:** follow `docs/milestones/M4-look-bible.md` "Shading" and "Colour":
  - the environment is muted (saturation at most 0.30, value 0.25-0.6), so the saturated enemies pop;
  - two-band toon shading with tinted (never black) shadows;
  - thin ink edge lines;
  - a dusk grade: cool shadows, warm highlights;
  - no red.
- **Two real directions per place.** For example: (A) warm brick, rust and sodium light, and (B) cool concrete, corrugated steel and blue hour.

### 4. The sheets and the DM draft

- **Sheets** (PNG, about 1600 px wide), with Pillow (`python3 -I`), each image labelled A/B/C in a corner. Put them in `assets/source/concepts/m6/sheets/`:
  - one per character type (`kicker.png`, `thug.png`, `bruiser.png`, `boss.png`, the boss's with the three names under it);
  - `weapon.png`, with each design's one-line swing note;
  - `moods.png`.
- **The DM draft** goes in your result's `summary`, as short as possible. Numbered asks:
  1. a pick per type (mix-and-match allowed, plus any change he wants in his own words);
  2. a boss name (or his own);
  3. a weapon;
  4. a street mood and a roof mood.

## Checks before you finish

- **Look at every image yourself** (the Read tool, within the image budget). Check:
  - the frame: full body, A-pose, front, grey background;
  - no red or pink;
  - the face covered or simplified;
  - the archetype's colour leading;
  - no text or watermark.
- **Retries:** regenerate a failing image at most once, with the prompt fixed. Note any you kept despite a flaw in your calls file.
- **Records:**
  - ASSETS.md: a row for every file under `assets/source/concepts/m6/` (the jobs file, images and sheets), in a new "Milestone 6 concepts" section, using the M4 concept rows as the pattern.
  - `git check-attr filter -- <file>` says lfs for every image.
- **Calls:** in `docs/milestones/M6-calls/CONCEPTS.md`: the prompts' design ideas, the name checks, and anything kept despite a flaw.
- **Never message Game-boy.** The lead sends the DM.
