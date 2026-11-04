# Milestone 6 proposal: full art and audio (for Game-boy's sign-off)

SPEC §12: all enemies and the boss, environment modules and set dressing, final SFX. **Done when no placeholder assets remain.** HANDOFF adds the original second weapon (screen 11's chain-like weapon, a pipe stand-in since M5) and M4's two carried-forward looks (the damage marks, the near upper arm).

Written by the lead on 2026-11-04 from HANDOFF, SPEC, README and a survey of the repo. Once signed off, the lead writes the detailed plan (`M6-plan.md`, one self-contained brief per package), and one Opus critic at medium reviews it. That replaces M5's separate planner, because the lead already holds the context.

## 1. What is still placeholder

| Area | Today | M6 |
| --- | --- | --- |
| Enemies | The Punk has M4 art. The Kicker, Pipe Thug, Bruiser and boss are M3's primitive bodies. The veteran Punk is an orange tint over the Punk. | All four types go through M4's pipeline: Gemini concepts, a pick, Tripo, the Blender chain, then the game's own rig and animations. The veteran becomes a palette swap of the Punk model. |
| Training dummies | Primitive bodies (the training room, F6) | M4's probe mannequin, painted as a padded sparring dummy. No Tripo. |
| Weapons | The pipe is a drawn cylinder. The second weapon doesn't exist yet. | A modelled pipe, and an original second weapon with its own moves. |
| Environment | 244 `LevelBlock` boxes in six flat looks across the street, the roofs and the boss roof. The crowd street and the training room are boxes too. | A kit of modules on a 2k trim sheet, set dressing, a skyline, and per-section light. |
| Audio | 38 procedurally generated SFX in 12 banks (`tools/gen_sfx.gd`), plus a placeholder music loop. | Final SFX from a real source. New slots: barriers, weapons, the boss's voice, ambience, and the GO and CLEAR stings. |

**The one placeholder kept:** the music loop. SPEC §1 lists "music beyond a placeholder loop" as a non-goal, and §13 leaves loop-or-silence open. The default is to keep the loop.

## 2. Phases and pauses

**Phase 0 (right after sign-off; about 3%):**
- The detailed plan and its critic.
- **CONCEPTS** (Sonnet, medium; Gemini only, no Tripo):
  - 3 concepts each for the Kicker, Pipe Thug, Bruiser and boss;
  - 3 boss names;
  - 3 second-weapon designs;
  - 2 environment mood frames each for the street and the roofs;
  - A/B stills for the two M4 looks.
- **One DM** carries all of it, the only pick pause. Phase 1 builds while it waits.

**Phase 1 (doesn't need the picks; 3 builders in parallel; about 23%):**
- **KIT** (Sonnet, high; Blender and Godot; about 10%):
  - Blender-scripted modules: facades with window and door variants, cornices, floors (asphalt, kerb, roof tar, gravel), stairs, rails, chain-link, the rolling shutter, the gate. All of them sit on one painted 2k trim sheet in the muted palette, with ink lines in the trim.
  - The art-over-graybox layer: a `LevelBlock` keeps its collider and navmesh and draws a module instead of its box.
  - Proved on the street's A1.
- **AUDIO** (Sonnet, high; about 7%):
  - The ingest pipeline: trim, loudness-normalize and variant-pick.
  - A bank manifest: each slot's file, gain, pitch range, source and licence.
  - The new slots.
  - An **audition room**: in the training room, one key per bank plays the old and the new sound one after the other, so you can judge it all by ear in one sitting.
  - The content follows your answer on the source (§5).
- **LOOKS** (Sonnet, high; about 6%):
  - per-swatch damage marks;
  - the near-upper-arm option;
  - the veteran Punk's palette swap and the dummies;
  - a glint for a weapon on the floor, in place of the amber stand-in;
  - **`tests/test_m6_no_placeholders.gd`**: an inventory of every placeholder in the three shipped scenes. It's a ratchet that has to reach zero (see §4).

**Phase 2 (after your picks; at most 3 Godot-bound builders at once on the 8 GB machine; about 45%):**
- **CREW** (Sonnet, high; Tripo, Blender and Godot; about 12%): the Kicker and the Pipe Thug. Their proportions are standard, the closest to the Punk.
- **HEAVIES** (about 14%): the Bruiser (2.05 m) and the boss (2.3 m, a 30k budget).
  - The chain is fitted at their body heights.
  - Spiked or bulky pieces are checked against the hull outline and the hurtboxes.
- **DRESS** (about 12%): the three sections, the crowd street and the training room, built with the kit.
  - Tripo only for a few organic hero props: the parked car, a dumpster, an AC unit, a water tank. The rest is scripted.
  - The skyline.
  - Light per section.
- **WEAPONS** (about 8%): the pipe model, and the second weapon's model and moves (in `gen_moves.gd`). It lies at A6's floor-weapon spot, where M5 put the stand-in pipe.

**Phase 3 (about 35%):**
1. The lead's own look at full-resolution stills of every character at 1 m and every arena.
2. One review round with 3 lenses:
   - characters (Opus): M4's rubric, abbreviated, per character;
   - the world (Opus): the environment, the weapons, and readability (do spawn doors, drops and enemies still read against the dressing?);
   - code, tests, pipeline and audio data (Sonnet).
3. One fix wave of at most 3 fixers, then a targeted re-check of only what changed.
4. Frame time against M5 on this Mac. The RTX 3060 target stays in M7.
5. README's M6 departures, the PR, and the DM with the run command.

**Total:** about 1.1-1.3 five-hour windows. At M5's rate that's roughly 10-14 weekly points, from today's 12% weekly. That leaves the week for M7.

## 3. Decisions taken by default (you can overrule any of them)

Each item gives the decision, then the alternative not taken.
- **D1. Art over the graybox.** Colliders, the navmesh and hurtboxes stay M5's and M4's, and the art only draws. So every M3-M5 test and readability number holds unchanged.
  - *Not:* collision from the art, which would move every M5 number.
- **D2. Kit modules are Blender-scripted on a painted trim sheet.** Tripo is used for characters, weapons and a few hero props only.
  - *Not:* Tripo for the architecture: noisy walls, more credits, and baked textures that fight the toon shader.
- **D3. Every enemy keeps the game's own animation set,** as the Punk did in M4.
  - *Not:* new clips, which would mean re-timing every telegraph.
- **D4. The veteran Punk is a palette swap** of the Punk model (a new vest colour).
  - *Not:* a separate model.
- **D5. The second weapon keeps the spec's weapon numbers:** 10 a swing, a 3-hit chain, it breaks after 8 hits, and a throw does 15. It differs in reach, arc and timing. A chain-like weapon is drawn by a presentation-only sim, and hits stay on the `WeaponTip` point as the pipe's do.
  - *Not:* new damage rules, which would be a spec change.
- **D6. Damage marks per swatch.** Blood marks only skin, cloth scuffs and darkens, and a cap or hair never takes the blood colour, so no more orange on the yellow cap.
  - *Not:* M4's whole-body stamp. A/B stills come with the concept DM.
- **D7. The near upper arm.** A per-move switch shows the whole upper arm in the haymaker and the uppercut only. Neither spins, so the shoulder doesn't sweep the view. Everywhere else, M3's framing stays.
  - *Not:* keeping the bare knob. A/B stills come with the concept DM.
- **D8. Ambience** (street hum, roof wind) at a low, tunable level, so it never masks the positional wind-up cues.
  - *Not:* silence between fights.
- **D9. The crowd street and the training room** get the same kit, since F6 ships them.
  - *Not:* leaving the two test rooms as graybox.

## 4. The done-when, made checkable

1. **`test_m6_no_placeholders`** passes at zero for the level, the crowd street and the training room. That means:
   - no primitive body is drawn;
   - no `LevelBlock` draws a plain box;
   - no `gen_sfx` sound is referenced;
   - no tint stand-in remains.
   - **Allowed:** the music loop, F3's debug draws, and the hidden hit-test proxies (never drawn).
2. **Budgets and records:**
   - Every model is within budget: 15k triangles for an enemy, 30k for the boss, 5k for a module (with the 2k trim sheet), and 3k for a prop or weapon.
   - Every asset is in ASSETS.md with its source, service and licence.
   - Every generated model rebuilds from its logged downloads (`--check`), as in M4.
3. **The game underneath is unchanged.** The M3, M4 and M5 done-when tests and the readability metrics pass.
4. **Your judgement.** You play the level and judge:
   - the characters at 1 m, at the Punk's bar;
   - the world;
   - the audio, by ear.

## 5. What I need from you now

1. **Sign-off** on this shape: the phases, one pick pause, and the done-when.
2. **The audio source** (SPEC §13's open question). The agent can analyse sound but can't hear it, so the audition room is how you judge.
   - **(a) Recommended:** the Sonniss GDC bundle for the hit stack and the world sounds (recorded Foley, free and royalty-free), plus the ElevenLabs sound-effects API for the voices (efforts, pain grunts, the boss).
     - *Your setup:* download the bundle into `assets/source/sfx/`, and put `ELEVENLABS_API_KEY` in `.env`.
   - **(b)** ElevenLabs for everything. One key, no download.
   - **(c)** Sonniss only. Voices from the bundle, if it has usable ones.
3. **Tripo spend and licence:**
   - **The budget:** M6 needs about 700-900 credits. That's about $7-9 at 1 credit = $0.01: four characters at about 150 each, two weapons, and four hero props, with retries.
     - The live balance is 1,205. M4's floor of 700 leaves only 505 to spend.
     - Either approve lowering the floor to 250, or top up the account.
   - **The licence:** the account type, still open from M4, which decides who owns what it generates.
4. **Ultracode on** for this session. The build and review runners are workflows.
