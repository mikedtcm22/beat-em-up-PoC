# First-Person Beat-em-Up (PoC)

One playable level that tests whether a first-person beat-em-up feels good to play. The full design is in [docs/SPEC.md](docs/SPEC.md).

## Play it

```bash
godot --path .
```

This opens Mission 1 (`game/level/mission1/mission1.tscn`), the graybox level from start to boss: a street, three rooftops and the boss roof, with seven fights in all (the table is in [reference/encounters.md](reference/encounters.md)).
- Each fight shuts the way ahead and behind until its last enemy is down. Then the barrier opens and a "GO" arrow points the way on.
- Stairs take you from the street up to the roofs. You can't fall off an edge, but an enemy you knock over one is out.
- The boss waits on the top roof and calls in two Punks at half health. "CLEAR!" ends the level.
- A first run takes about 8-10 minutes.

F6 cycles the rooms: the level, then the Milestone 3 crowd street, then the Milestone 2 training room, and back to the level.
- **The crowd street** (`game/level/crowd_room.tscn`) is a 30 m lane with doorways, alleys, a parked car and crates. Waves of up to six mixed enemies repeat for as long as you live, about a third of each from outside your view, and the boss comes in alone after every fourth wave.
- **The training room** has the player, three training dummies and a pipe. The centre dummy spars: come within 1.7 m in front of it and it steps in and throws a telegraphed jab every couple of seconds, to block (or dodge, or hit it out of its wind-up). To open the editor instead, run `godot --path . -e`.

| Action | Gamepad (Xbox) | Keyboard + mouse |
| --- | --- | --- |
| Move / look | Left stick / right stick | WASD / mouse |
| Punch / kick | X / Y | Left / right mouse |
| Jump | A | Space |
| Block (held) | B with no stick direction | Shift alone |
| Dodge | B + stick direction | Shift + WASD |
| Back elbow | RB | Q |
| Grab, pick up, throw weapon | LB | E |
| Break free when an enemy grabs you (mash) | X / Y | Left / right mouse |
| Quick turn | Right stick click | Tab |
| Pause (R restarts while paused) | Menu | Esc |
| Cycle camera: first person, side view, free fly | | F2 |
| Debug draw: hitboxes, hurtboxes, magnetism, states, and with enemies their AI states, attack tokens and posture slots | | F3 |
| Tuning panel: every tunable and move, presets | View | F1 |
| Cheats: god mode, one-hit KOs, spawn any enemy at the crosshair, remove spawned / all enemies, waves on / off, freeze AI, time scale 0.25× / 1×, reset dummies | | F4 |
| Sparring: all three dummies throw jabs / none do (training room only) | | F5 |
| Switch room: level / crowd street / training room | | F6 |
| Controls help | | H |

The free-fly camera moves with the arrow keys and PgUp/PgDn, and turns while you hold the middle mouse button. The player keeps WASD and the mouse.

The tuning panel and the cheat menu take every key while open, and the player stands still: close them (F1, F4 or Esc) before using F2, F3, F5, F6 or H. They also hold the fight, so a crowd can't beat you up while you tune: no enemy is given an attack, no wave spawns, and an attack already winding up finishes. The panel works with the mouse, and with a gamepad's D-pad, A and B. Presets save to `user://tuning/`; "Export" writes `tuning/<name>.json` in the project, and `tuning/default.json` holds the shipped values.

**Combos:** P P P P · P (pause) P, then mash (body-blow flurry into the shove) · P P (pause) P (spinning backfist) · K K K · K (pause) K · P P K · hold P, then release (haymaker). The pause means waiting about a quarter second after a hit finishes before pressing again.

**Other moves:** Jump + K (flying kick), Jump + K at the top of the jump (spin kick), K next to a downed enemy (stomp), LB next to any standing enemy (not while its strike is out; a Bruiser only while it is staggered or its armor is broken, and never the boss), then P (knee) or K (throw). LB over a weapon on the floor picks it up: the Pipe Thug drops its pipe when it is knocked down, and a small "LB" cue shows when you can take it.

**Enemy grabs:** a Bruiser's or the boss's grab is telegraphed, and a dodge or a jump gets out of it. Once it has you, mash P or K (8 presses) before its headbutt or slam lands: the holder staggers away and you can't be hit for a third of a second.

**The rear warning:** when an enemy outside your view starts winding up an attack, a red-orange burst flashes in the top-left corner (it is behind you on the left), the top-right (behind on the right), or both (directly behind). It stays until the attack lands or is stopped, so turn, dodge or block.

**Blocking:** hold B (Shift) with no direction to put the guard up; it stops hits from the front (within 60° of where you look) for a little chip damage and drains the guard meter under your health bar. Raise it on reaction to an attacker's wind-up, up to about a quarter second before the hit, for a perfect block ("PARRY!"): no damage, and the attacker staggers, so you can let go of B and grab it. An empty guard meter breaks the guard. P or K out of the guard attacks at once; pressed while a blocked hit pushes you back, it attacks as soon as the push-back ends. Holding B keeps the block: after a hit, a guard break or an attack out of the guard, the guard comes back up while B is still held (a perfect block needs a fresh press of B). Jump and LB do nothing while the guard is up.

## Milestone 5 status: the level blockout

Mission 1 now plays from the street to the boss as one graybox level. Enemies attack from Game-boy's attack arcs instead of the even spread round you. Milestone 5 is done when the level plays from start to boss (Spec §12).
- **The attack arcs** (Game-boy's call; Spec §7):
  - Each type attacks from an arc centred on where you looked when it engaged: Punk 90°, Pipe Thug 140°, Bruiser 180°, boss 270°, Kicker 360°.
  - For the first 0.5 s, a quick turn re-aims an enemy's arc. After that its line holds, so turning your back on a Punk lets him hit you from behind.
  - Enemies with no free seat in their arc wait further out (5.5-6.5 m), back from the fray.
  - Variants widen the arc in data: the veteran Punk (orange) attacks from 140°.
  - F3 draws each enemy's arc, and the arcs' numbers are in F1's "Enemies > Attack arcs".
- **The level** (`game/level/mission1/`; the approved table is [reference/encounters.md](reference/encounters.md)):
  - Seven arenas and 34 enemies, laid out after the reference's screens:
    - the street (the loading dock, the crate yard, the warehouse stair);
    - three roofs (the terrace, the catwalk, the top roof's six-at-once crowd);
    - the 20 x 20 m boss roof.
  - **Arena locks:** a car, a gate or a shutter closes the way ahead and behind until the last enemy is down. Then it opens with a "GO" arrow.
  - Stairs climb from the street to the roofs.
  - Every drop has a rail with gaps and an invisible guard for you. An enemy knocked over it is KO'd.
  - A pipe lies on the top roof, and Pipe Thugs drop theirs.
  - The boss calls in two Punks at half health. "CLEAR!" ends the level.
- **The level kit** (`game/level/kit/`) builds any later level from scenes: sections chained by Entry and Exit markers, arenas, barriers, spawn points, stairs, edges, hazards and pickups. Its numbers are in F1's "Level" group.

**How the done-when is proved:**
- **`tests/test_m5_done_when.gd`** plays the real level arena by arena:
  - it checks each arena locks, spawns exactly its table, never has more than six alive and clears in order;
  - it checks the boss's adds and the single `level_cleared`;
  - it checks the edge guard and a launched Punk's KO;
  - it checks that no two sections overlap.
- **The level-run bot** (`tests/bot/level_bot.tscn`) plays the whole level:
  - In god mode at full speed: 197 s, all seven arenas in order, with no stall.
  - Held back with real damage, as the recordings show: about 427 s, about 7 minutes, so a first run takes about 8-11 minutes.
- **M3's readability metrics are re-measured** under the arcs. Every hard row holds in every arena.
  - In the boss arena, two soft rows miss: the ring's closest tenth (R6, p10 about 1.8 m) and the lens covered (R8, p95 about 57%). Every sample behind them is the boss alone up close, during his own moves, with no add involved. That's his size, not a crowd.

## Milestone 4 status: the art pipeline

The game now has its look and its first real art. Everything is cel-shaded, the Street Punks wear a generated, rigged model of Game-boy's pick (Street Punk A), and the player sees his own arms and legs as Hero C. Milestone 4 is done when the Punk looks production-quality at 1 m from the camera, standing still and in motion (Spec §12), and Game-boy judges that.
- **The look** (Spec §10; all of it in F1's "Look" group):
  - **One toon shader for everything:** two or three lighting bands, tinted shadows (never black), one hard highlight and a rim light. Characters also get a soft fill light that follows the camera, so an enemy facing away from the sun doesn't fall into one flat shadow.
  - **Outlines:** an ink outline (an inverted hull) on characters, props and the placeholder enemies, thinner with distance so a close enemy doesn't get a thick line. Your own arms and legs get a slightly thinner one.
  - **Environment lines** from a depth-and-normal edge pass, a colour grade, and a linear tonemapper, which keeps every palette colour true.
  - **Halftone dots:** available, but off by default (see below).
- **The Street Punk** (concept A: a backwards yellow cap, yellow shades in a dark frame, a teal denim vest over a dark tank top, pale ripped jeans, a taped left forearm, fingerless gloves on wrist cuffs, cream high-tops with yellow laces):
  - **Made by the pipeline, not by hand:** Gemini drew four views of the concept, and Tripo turned them into a model and rigged it. A headless Blender chain then fits the model to the game's skeleton, replaces the hands with separately generated glove fists, paints it in six flat palette colours with an ink-line mask, and exports it.
  - **14,300 triangles**, within the 15,000 budget.
  - **Same game underneath:** the game's own animations, hurtboxes, ragdoll, hit flash and damage looks drive the model, so every M3 number (reach, telegraphs, readability) is unchanged.
- **Your own body** (Hero C: a sleeveless navy gi top, bare upper arms, cream forearm wraps, dark fingerless glove plates over bare fingers, slate trousers, wrapped ankles and black slip-ons with cream soles):
  - **Full body:** 29,320 triangles, so the knockout view shows the whole body lying, and the shadow you see on the floor is your own.
  - **Hidden in first person:** the head, chest and shoulders, as in M3. The belly and belt are their own mesh, so "hide torso in knockdowns" (below) hides only them.
  - **Swappable:** the hero is files only (`game/actors/art/player_art.tres` names the model), so a later hero-select menu needs no code change.
- **The comic effects:** a final pass on the lettering, bursts, speed lines and blood, drawn as SVG and rasterized to 512 px.
- **Four first-person feel questions** that M2 left "until the art is in" are switches in F1's "Look > FP feel", each off by default (today's behaviour):
  - **`hit_flash_fp_max_share`:** caps how much of the view a close hit flash can whiten (0.12 is the suggested value).
  - **`hit_flash_finisher_radius_mult`:** makes the haymaker's flash show (2.0 is the suggested value).
  - **`fp_knockdown_hide_torso`:** hides your belly while you lie in a knockdown, so it doesn't fill most of the view.
  - **The combat log:** the L key toggles it, and `combat_log_hide_while_holding` hides it during a hold.
- **To look at it:**
  - F4's "Showcase Punk at 1 m" freezes one Punk in front of you, looping a 40 s take of everything it does, and you can walk round it.
  - F1's Debug switch `look_show_art` off puts M3's primitive bodies back, to compare.

**How the done-when is proved:**
- **`tests/test_m4_done_when.gd`:** one test per measured row of the plan (A1-A14: the model's contract, budgets, colours, feet, fists, hurtbox fit, deformation, ragdoll, first-person framing, damage marks, the flash, the suite, assets and spend, readability). It prints one table of every row's state.
  - Rows the art doesn't meet yet are held at today's figure (a ratchet), and the plan's own bar is printed beside them as a GATE line.
- **The look probe** ('Look: final probe' in the crowd bot) measures the outline widths, the bands and the flash's share of the view.
- **The final review:** six reviewers, each judging one area in first person from full-resolution recordings, scored the plan's 14 judged items 0 (fails), 1 (acceptable) or 2 (production). The mean was 1.29 against the plan's 1.5. Two rounds of fixes followed, then an independent re-score:
  - J1 2 (reads as the concept), J2 1 (face), J3 1 (fists), J4 1 (ink), J5 2 (shading), J6 2 (palette), J7 2 (surface);
  - J8 2 (deformation), J9 1 (life), J10 2 (contact), J11 1 (damage looks), J12 2 (wind-ups), J13 1 (one style), J14 1 (your arms and legs).
  - That is a mean of 1.50, with no 0, so the plan's rule passes exactly at its bar.
  - One more small round then fixed five of the re-score's findings: the shades whiting out when the head tips back, faceted face shading, dotted ink strokes, the striking glove's back, and highlights on the placeholders. It was judged from stills, not re-scored.
  - Game-boy's yes is the last part of the done-when. He gave it on 2026-11-03, after two hand fixes from his playtest (the Punk's fists turned the right way; the player's jab and cross land palm-down): "punks look good - let's say passes at 1m".
- **The rebuild:** every model rebuilds from the logged Tripo downloads to the same file (`tools/pipeline/run.py --asset punk --check` and `tools/pipeline/player_run.py --asset player --check`).
- **Spend:** Tripo took 295 credits of the 750 set aside; each generation is in `assets/source/tripo_ledger.jsonl` and ASSETS.md.

## Milestone 3 status: enemy AI and the rear warning

All five Spec §7 archetypes fight in the crowd street under a director, and the rear warning (Spec §8) flashes when something you can't see starts to wind up. It all runs on placeholder rigs, art and sound. Milestone 3 is done when a six-enemy fight is readable and the warning fires correctly behind-left, behind-right and directly behind (Spec §12).
- **The five archetypes:** each has its own saturated jacket, and none is red (Spec §10 keeps red for blood, the warning and the finisher's accents).
  - **Street Punk:** 30 health, teal with a yellow cap. A two-hit punch and a shove (6 damage each). Walks up head-on, and is the most common in the waves.
  - **Kicker:** 25 health, lime with near-black accents, 1.3x faster. A jump kick and a low sweep (8 each; jump over the sweep). It circles the ring to your blind side and winds up from behind.
  - **Pipe Thug:** 35 health, olive green with a yellow pipe. A three-swing pipe combo (10 each; the third staggers instead of knocking down). It drops the pipe when it is knocked down, launched, thrown or killed, and the pipe slides toward you and lies still, to take with LB. After that it fights with punches.
  - **Bruiser:** 80 health, 2.05 m tall, purple with steel grey. An overhead smash (15) and a grab and headbutt (15). Armored: a light hit lands its damage but doesn't flinch it or stop its wind-up (a grey spark and an ARMOR line in the combat log), a heavy hit staggers it, and the haymaker knocks it down and breaks the armor for 2 s.
  - **Boss:** 300 health, 2.3 m tall, charcoal with orange, with the placeholder name "Boss" and a health bar at the bottom of the view. A shoulder charge (20), a ground pound (15, unblockable: jump or dodge it) and a grab and slam (25). Armored against light hits, never grabbable, slow to turn. After a knockdown or stagger it gets up where it stands and attacks. At half health it turns faster and calls in two Street Punks. A perfect block knocks it back for 0.6 s.
- **Enemy behaviour:** every enemy shares one brain with the Spec §7 states.
  - Enter: it walks in from a spawn point.
  - Approach and posture: it goes to a ring 2.5 to 4 m from you, walking round the ring when its place is across you instead of through you, then circles, strafes and taunts while it waits for an attack token.
  - Engage: with a token it squares up for 0.2 s, then steps in only when its go is near.
  - Wind-up: a readable pose and a vocal cue, 18 frames at least for grunts and 30 for the Bruiser and boss. It turns to track you for the first half, then locks its facing, so a late sidestep or dodge makes it miss.
  - Attack and recover: after it attacks it holds still for 0.35 s (your punish window), then backs off to its place with its face to you.
  - Hit reactions: hitstun, stagger, knockdown and a get-up with brief invulnerability, then KO. A light hit interrupts a grunt's wind-up but not a Bruiser's or the boss's.
- **The director:** it paces the fight, and every number is in F1.
  - At most 3 enemies attack at once (the attack tokens, `attacker_cap`; 0 is no limit). The rest posture.
  - An enemy outside your view gets token priority (`blind_spot_priority`, 1.0 by default: the chance that one jumps the queue).
  - Posturing enemies take slots spread evenly all round you instead of bunching in front. A Kicker takes a seat of its own behind you, and the others' seats don't move for it.
  - No two wind-ups start less than 0.35 s apart. None starts while you are in hitstun or stagger, or within 0.5 s of a hit that wasn't blocked (the hit grace, which stops a chain of hits from locking you in flinches).
- **The crowd room, navmesh and waves:** the crowd street is the main scene, and the training room waits behind F6. Its navmesh is baked when it loads, and enemies walk it with avoidance so they don't overlap. Waves come from a table (`game/level/encounters/crowd_waves.tres`): one enemy spawns every 0.6 s with at most six alive, wave 1 starts 3 s after the load, each later wave starts 3 s after the last enemy of the one before is down, and every fourth wave is the boss alone. Spawn points sit in doorways, alleys and behind the car, and each wave sends round(size × 0.35) of its enemies from outside your view.
- **Enemy grabs:** the Bruiser and the boss grab you. The wind-up is telegraphed, and a dodge, a jump or a heavy hit on an armored grabber gets out of it. Once you are held, your look turns to the holder and the view tips up to its eyes, and a "MASH P / K!" prompt with a fill bar shows. Mashing P or K 8 times before the follow-up strikes breaks free: the holder staggers away and you can't be hit for 20 frames. Unbroken, the headbutt (15) or the slam (25) lands.
- **The rear warning:** an enemy more than 55° off your look that starts a wind-up within its attack range plus 1 m flashes a red-orange comic burst in the top-left corner (behind-left), the top-right (behind-right) or both (within 20° of directly behind). It shows on the wind-up's first frame and ends on contact (a block too), a whiff, an interrupt, a grab or a KO, never when the strike comes out. It pulses twice, brightens with more attackers on a side and is larger for the Bruiser and boss. The wind-up's grunt and whoosh play positionally.
- **Tuning, debug draw and cheats:**
  - F1 has the groups "Enemies" (the cap, the blind-spot priority, the wind-up multiplier, and a subgroup each for the director, the waves and every archetype) and "Rear warning" (angle, size, opacity, audio and the look of the burst).
  - F3 draws each enemy's AI state, slot and token over its head, a magenta ring and line on each token holder, the posture slots and ring, the view edge and the behind sector.
  - F4 spawns any enemy at the crosshair, removes the spawned or all enemies, turns waves on or off and freezes the AI.
- **The "LB" pick-up cue:** a small "LB / PICK UP" panel low in the view while LB would pick up a weapon. A dropped pipe lies below the first-person view, so without it you would have to look down to find it. It stays away when there is an enemy to grab instead. Tunable in "Grab and weapons" > "Pick-up cue".

**How the done-when is proved:**
- `tests/test_m3_done_when.gd` stands each archetype 135° left, 135° right and 180° from the look at its own strike range in the real crowd room, and asserts the HUD's corners from the wind-up's first frame to the contact. Negative controls (in view, out of range) must stay dark. It then soaks 1500 frames of a mixed six, and the waves with the scripted player (the opening waves, and a second run from wave 3 for the mixed waves), against the hard rules below.
- The readability probe (`tests/bot/readability_probe.gd`) takes 15 metrics in every crowd-bot act. Five are hard and pass in every act and seed: at most the cap attacking at once, wind-up starts at least 21 frames apart, no hit without a warned wind-up, the HUD's corner agreeing with the rule at every wind-up, and no non-boss hit over 15 damage that knocks you down. The other ten are soft, judged from the captures (lens coverage, ring adherence, stuck enemies, frame time and more).
- `tools/check_m3_log.py` checks a crowd-bot log the same way.
- The slice gate (`docs/milestones/M3-slice-gate.md`) took one Street Punk end to end, judged in first person, before the other archetypes were built, and locked the feel defaults.

Two soft misses are accepted: lens coverage in a fought crowd (a Bruiser at 1.2 m fills half the view) and the worst 2 s of damage going past 30 when a Pipe Thug is in the fight (36 to 48: its three-hit combo is the spec's). To judge in play: the boss has poise. After a stagger or a knockdown, once it is back on its feet, a heavy hit and a finisher do their damage but don't flinch it, for 4 s or until its next attack is over, and the same after two staggers or knockdowns within 8 s; the haymaker still knocks it down, and a heavy hit still cuts its grab. The scripted player's full chain kills it in about 39 s with the boss in a reaction 21% of the time (it was 48%), taking about 4.6 hits from it (3.1). It steps back before a charge or a pound that would be too close to read. `boss_health` 500 would give about 6 hits and a 56 s fight; it is 300 by the spec. Fine look and feel questions that the placeholder art can't settle keep their defaults until the real art is in (Game-boy, 2026-10-25); each is logged in docs/milestones/M3-judgement-calls.md.

## Milestone 2 status: hit feel

The whole Spec §6 hit-feel stack runs on placeholder art and sound, with the Spec §11 tuning panel to tune it live. Milestone 2 is done when Game-boy tunes each tier live in the panel (F1) and saves a preset.
- **Per-tier hit feel:** hitstop, the finisher's slow-mo, camera punch and shake, the white contact flash (localized, see the departures below), and the finisher's impact frame (a 1-2 frame inverted ink flash of the screen, with an off toggle).
- **Comic VFX:** lettering, impact bursts in three sizes, speed lines, blood, spit and teeth, the parry spark and the guard-break burst. Enemies go from clean to bruised to bloodied at 66% and 33% health.
- **Audio and rumble:** generated placeholder sounds, layered per tier, positional, never the same variant twice in a row; gamepad rumble per tier.
- **Ragdoll:** staggers blend a partial ragdoll over the animation, and knockdowns, throws and KOs hand over to the full ragdoll, pushed at the contact point. A body launched into a wall crumples against it, gets up where it lies, and a KO'd body blinks off. The player keeps animated reactions (a toggle in the "Ragdoll" group).
- **The grab:** while holding, the view pans down and the player bends at the waist, so the knees land in view.
- **The player's KO:** the view leaves the eyes and shows the player's body lying on the floor, then comes back as the player gets up (see the departures below).
- **Tuning panel, presets and cheats:** F1 and F4 (see the controls above). Every tunable and move shows in the panel with no UI code.

Side view and free fly are debug views (Spec §11): looks and feel are judged in first person only. Fine look and feel questions that the placeholder art can't settle (the flash's size in first person, the haymaker's flash, the view during non-KO knockdowns) keep their defaults until the real art is in (Game-boy, 2026-10-25); docs/HANDOFF.md lists them.

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

**Where M2 departs from the spec (approved by Game-boy from 2026-10-23 to 2026-10-25):**
- **The 0.25x cheat slows the hit feel too (Spec §11):** the F4 time scale stretches hitstop and the finisher slow-mo as well as the simulation, so a slowed-down hit keeps its feel, only slower. Camera punch and shake stay at full speed.
- **Cheats stay out of presets (Spec §11):** god mode and one-hit KOs are session state. Saving, loading or resetting a preset skips the "Debug" group, so a preset never turns a cheat on, and loading one never turns a cheat off.
- **The white hit flash is localized (Spec §6, approved 2026-10-24):** on contact, the victim flashes white only around the point the hit landed instead of over the whole body. It is full white at the contact point and fades out by a radius (default about 0.25 m, about a head's width), at a strength you can set. Both are in the "Hit feel" tuning group, and a large radius brings back the whole-body flash. At 1 m in first person, the whole-body flash turned 27-36% of the view white on a jab.
- **Heavy hits that knock a body down get the full ragdoll (Spec §6 tier table, approved 2026-10-24):** the table gives heavy hits a directional stagger with a partial ragdoll. The reaction decides instead of the tier: any hit that takes a body off its feet (the back elbow, the flying kick, the spin kick, a thrown weapon, a body thrown into another) launches the full ragdoll, and heavy hits that leave it standing stagger it with the partial one.
- **Stronger staggers (Spec §6, approved 2026-10-24):** the partial ragdoll blends in at 0.9 influence (`ragdoll_partial_influence`) instead of the spec's 0.3-0.6, so the upper body gives way further (on the hook, about 0.33 m against 0.22 m at 0.6, the same on every hook). The push of a hit lands at its contact point, as the spec says, with each body part's spin capped.
- **KO'd bodies blink off (Spec §6, approved 2026-10-24):** instead of staying until the arena clears, a KO'd body lies limp for 1.5 s (`ko_linger_s`), blinks faster and faster for 1.0 s (`ko_blink_s`), then is gone, with no hurtboxes or collision. KO'd bodies take no hits. In the test room a training dummy comes back standing at its post 1.0 s later (`dummy_revive_s`) with a short blink-in, 4 s after the KO. When someone stands on its post, it comes back at the nearest free spot off to one side in front of the player (about 45°, in view but not in his face). It waits there, and on its way home it stops short of anyone standing in its path instead of walking into them.
- **A finisher's white flash waits out the impact frame (Spec §6, approved 2026-10-25):** the spec flashes the victim on contact. On a finisher, the impact frame's ink flash covers the whole screen on the contact frames, so the white flash starts on the frame right after it and still shows for its 2 frames. With the impact frame off, it starts on contact.
- **The player's KO is seen from outside the body (Spec §5, approved 2026-10-25):** everywhere else the camera rides the player's head. From the killing blow, it eases out of the eyes (0.8 s) to beside the lying body, 1.7 m out and 1.6 m up, looking down 40°, and eases back in as the player gets up (0.5 s). In a corner or between fighters, where that spot has no room, it looks down on the body from over the hips instead. The look is locked from the killing blow until the player is back up, so the view comes back to where the body faces. In the eyes, the lens lay 7 cm above the floor behind the player's own belly. The numbers are in "Camera" > "KO view". Ordinary knockdowns keep the first-person view.

**Where M3 departs from the spec (approved by Game-boy at sign-off, 2026-10-26):**
- **The haymaker knocks a Bruiser down and breaks its armor (Spec §7, §4):** the spec has the Bruiser stagger on heavy hits and the haymaker. Here a hook staggers it, and the haymaker knocks it down and breaks its armor for 2 s (`bruiser_armor_break_s`, counted from the moment it is back on its feet), because "breaks Bruiser armor" (§4) would show nothing with a stagger. The other finishers (the uppercut, the spinning backfist) only stagger it.
- **Armor absorbs light hits instead of ignoring them (Spec §7):** a light hit still does its damage, but the Bruiser (and the boss) doesn't flinch and its wind-up goes on. A hit that did nothing at all would give "armor hits look registered" nothing to show, so each absorbed hit gets a grey spark, a low clank and an ARMOR line in the combat log (`armor_spark_grey`, `armor_clank_pitch`).
- **A Bruiser can be grabbed only while staggered or with its armor broken, and the boss never (Spec §4, and M1's "grab anytime" above):** otherwise LB would hold and throw a heavy at will and walk round its armor. A perfect block staggers a Bruiser, so the parry is the answer to its smash.
- **The 15% knockdown rule is read per attack chain (Spec §4):** one attack that ends in a knockdown, launch or throw costs you at most 15 damage, so the Pipe Thug's third swing staggers instead of knocking down (three 10-damage swings ending in a knockdown would cost 30%). The boss is exempt, and a data test checks every chain.
- **One telegraph per attack (Spec §7, §8):** a chain link (the Punk's cross, the Thug's second and third swings) has no wind-up or warning of its own, and starts only if the hit before it landed or was blocked. A whiffed opener ends the attack, and so does a blocked Punk jab (a 20-frame recoil, which is your punish window). A warning for every hit would double the noise in a crowd.
- **The warning's side is fixed when the wind-up starts, and it hides while you are KO'd (Spec §8):** the spec fires it "at wind-up start", and a fixed side doesn't flicker while the view spins. In the KO view the camera is outside the body, so the corners mean nothing. `rear_warning_follow_turn` re-checks the side every frame, and `rear_warning_hide_in_ko` turns the hide off.
- **The 55° angle leaves a band with no warning (Spec §8):** the lens sees 45° either side of the look, so an attacker 46° to 55° off it is off-screen but is not "outside the view" by the spec's number. The spec's 55° is kept (`rear_warning_angle_deg`, live in F1: set it to 45 to close the band).
- **"Attack range + 1 m" is each move's own `reach_m`, lunge or dash included (Spec §8):** a boss charge (reach 5.3 m) warns out to 6.3 m and a Kicker's jump kick (2.75 m) to 3.75 m, which a fixed range would miss from behind. `reach_m` is editable per move in F1, and a rig test holds it to the measured strike within 0.15 m. The +1 m is `rear_warning_range_margin_m`.
- **Grunt wind-ups run 20 to 22 frames, where the spec says 0.3 s (Spec §8):** the Punk's jab is 22 frames (0.37 s), held from 80% of it, which reads at 1 m and 2.5 m in the first-person sheets. 18 frames, the spec's minimum, stays as the floor that `windup_mult` clamps to (`windup_min_frames_grunt`).
- **Enemy grabs can be broken by mashing P or K (Spec §7, approved by Game-boy, 2026-10-25):** this is his own rule from his M3 answers. 8 presses (`grab_break_presses`) before the follow-up strikes, about a second; a break-free staggers the holder and gives you 20 frames of invulnerability (`grab_break_invuln_frames`).
- **The look turns to the holder while you are held (Spec §5):** the spec has the view rotate only from look input. When a Bruiser or the boss grabs you, the look turns to it over 8 frames and the view tips up toward its eyes by up to 30°, with the look locked, so you see the grabber (a 2.05 m Bruiser's eyes are 0.37 m above the lens). Both are tunables (`grabbed_turn_frames`, `grabbed_view_pitch_deg`).
- **Target magnetism in a crowd uses a flat cone (Spec §4):** the cone is judged by the heading alone, skips bodies in get-up or blink-in invulnerability, and adds the target's radius to the stop distance, so the lunge doesn't drive into a Bruiser or the boss. The cost is that with the look pitched far up or down you still lunge at an enemy on the horizon of your heading.
- **The Pipe Thug never picks its pipe up again (Spec §7):** after it drops the pipe (a knockdown, launch, throw or killing blow) it fights with the Punk's punches, and a Thug you hold and let go unhurt keeps its pipe. The dropped pipe slides toward whoever hit it at 0.5 m/s (`thug_drop_speed_mps`), so it lies within LB's reach (the loose pipe is damped to a rest within about a second: `weapon_rest_linear_damp`, `weapon_rest_angular_damp`).
- **The boss's name stays "Boss" (Spec §13):** the spec leaves its name and design open, and Game-boy's M3 answers allowed a placeholder.
- **F4 can put more than six enemies alive (Spec §7):** spawn-any is a debug tool for testing crowds. Only the waves keep to the cap of six (`wave_max_alive`).
- **A heavy hit during the boss's charge or pound wind-up is absorbed (Spec §7):** the spec only says light hits don't interrupt a boss wind-up. The scripted player's third punch is a heavy hook, and it beat the boss in 38 s without taking a hit because it cut every wind-up. Now only a heavy hit on the boss's grab wind-up cuts it, and it is one place in `boss.gd` to take out. A heavy hit and a finisher are also absorbed for a while after it gets up (its poise, below), the haymaker and the cut of its grab excepted.
- **The boss has poise (Spec §7 says only that light hits don't interrupt it):** once it is back on its feet after a stagger or a knockdown, a heavy hit or a finisher does its damage but doesn't flinch it, for `boss_poise_s` (4 s) or until its next attack ends, and the same after `boss_poise_after_reactions` (2) reactions within `boss_poise_window_s` (8 s). The haymaker still knocks it down. Without it, the basic P P P P chain knocked the boss down every 3.3 s and it spent half its life in reactions. Set the three to 0 for the old boss. Game-boy kept the spec's 300 at sign-off.
- **A KO'd enemy lies limp, blinks off and is freed (Spec §6):** the spec keeps bodies until the arena clears. M2 already approved the blink-off (`ko_linger_s`, `ko_blink_s`), and freeing a body is simpler than pooling it.
- **The crowd mostly waits and attacks in turns (Spec §7):** at most 1 or 2 enemies attack at once against the cap of 3. In a six-Punk fight about a quarter of the crowd is circling on the ring at any moment (1.4-1.6 of 5.8); most of the rest stand squared up on the ring waiting for their go, walk out to it, or back off. The spec says "most of their time posturing", and a Punk attack cooldown of 5.0 s (`punk_attack_cooldown_s`, was 1.4) is the best posture share that doesn't gut the pressure. The hit grace (`director_hit_grace_s`) holds the next wind-up while you take hits.

**Where M4 departs from the spec (accepted by Game-boy with M4's sign-off, 2026-11-03):**
- **Rig and animation (Spec §10, pipeline steps 4-6):** the spec has Mixamo rig the characters, Mixamo and video mocap animate them, and Godot import them with the humanoid skeleton profile. Here Tripo's auto-rigger rigs the model (Game-boy: Tripo first, Mixamo skipped), and the headless Blender chain fits it to the game's own humanoid skeleton. The game's procedural animation set then drives it, the one M1-M3 tuned frame by frame. No Mixamo or mocap clip is used, and there is no humanoid-profile import. Generated clips would have had to be re-timed to every move's frame data, hitboxes and telegraphs.
- **The Punk has a 1k ink-detail mask (Spec §10's table gives enemies the shared palette atlas only):** the mouth, nose, tape wraps, pocket flaps, stitching and the cap's strap are thin ink lines in a 1024 px mask on a second UV set, the same kind of mask the spec gives the player. Flat palette colours alone left the face and tape blank at 1 m. The mask's R is ink only, never shading: its strokes are cleaned at the bake (gaps along a stroke bridged, dots dropped) and the glove and its cuff carry a few authored lines (a seam where the knuckles begin, the dorsal plate's outline, rings round the wrist cuff). Its G holds the glint gate (the shades' lens takes its hard highlight only on two authored streaks per eye, as in the concept, so a head tipped back never whites the lens out; it is not shading either), B nothing. The Punk still uses six flat palette colours.
- **The player's head is not its own mesh (Spec §10, pipeline step 3):** the hero is three meshes. One is the visible body. The second is the hidden upper body (head, neck, chest, shoulders and the shoulder end of each upper arm, as in M3's approved "upper body in first person"). The third is the belly and belt, so the knockdown switch can hide them alone. The head is in the hidden mesh.
- **Environment lines skip the characters:** the edge pass draws depth and normal lines on the street only. The characters already have the ink hull, and drawing both doubled their outlines.
- **Halftone is off by default (Spec §10: "optional"):** it is in F1 (`look_halftone_env`, `look_halftone_chars`). Screen-space dots crawl on a moving body at 1 m.
- **Performance is measured on the Apple M1, not an RTX 3060 (Spec §10):** there is no Windows machine. Interleaved runs on the M1, under load from other apps, put M4's frame time 2.4 ms above M3's on average and 3.4 ms at the 95th percentile ("Perf, six with ragdolls"; the plan's soft bar is +4 ms). M3 itself misses 16.7 ms at the 95th percentile on this machine. A quiet-machine A/B and the RTX 3060 target are still to run.
- **The Punk's shades are the cap's yellow inside a dark frame:** the concept's lenses are a lighter gold. A seventh colour would break "4-6 colours per character", and the dark frame keeps the lens apart from the cap. A cream lens was tried and read as a khaki visor.
- **Some of the plan's own measured bars are not met, and are held as ratchets:** none is a spec rule. The plan's bar is printed beside each, and the figures are in the done-when table.
  - **First-person framing (A9):** the Punk's art covers 6.6% of cells differently from the hidden hit-test shapes (bar 3%), and the jab and cross lens share misses by about 1 point.
  - **The rest:** deformation strain (A7), the hit flash's anchor at the torso (A11), the hero's legs inside the hurtboxes (A6), and the hero's walk keeping M3's step cadence (A4, his feet slide).
- **The player's jab and cross land palm-down (Game-boy's request, 2026-11-02):** the fist rolls about 90 degrees over the punch, so at contact the back of the glove is up and the curled fingers point down. That changes two of the frozen strike poses. The hit point moves 7 mm, so reach and hits are unchanged. With a straight wrist the palm ends 34-36 degrees from level, because the forearm rises at contact. The Punk's and the training dummy's punches keep M3's vertical fist.
- **Two looks carried forward to Milestone 6:**
  - **Damage marks:** they are spread over the whole body, as M3's were, and the blood turns orange on the yellow cap.
  - **The near upper arm:** in the haymaker and uppercut its cut end is a bare knob mid-view. That is M3's approved first-person framing, and showing the whole upper arm instead is an option.

**Where M5 departs from the spec (decided by default, for Game-boy's ruling at sign-off):**
- **M5-1. Attack arcs replace "Spread" (Spec §7; Game-boy's call, 2026-11-03):**
  - Each archetype attacks from an arc centred on where the player looked when it engaged: Punk 90°, Pipe Thug 140°, Bruiser 180°, boss 270°, Kicker 360°.
  - The line follows the player's turns for `engage_commit_s` (0.5 s), then holds until that enemy's attack and recovery end.
  - When its arc has no free seat, an enemy waits on an outer ring (5.5-6.5 m) inside its arc, back from the fray.
  - Variants override the arc in data: the veteran Punk is 140°, a `.tres` file in `game/enemies/variants/`.
  - **Ours, not his:** when a wall or a drop leaves no room anywhere in an arc, the arc slides round to the nearest open stretch, so a wall is never a safe spot.
  - **Keeping the spec reachable:** `director_even_spread` (Debug) brings M3's even spread back.
- **M5-2. Blind-spot priority only for wide arcs (Spec §7; Game-boy's call):** only an enemy whose arc reaches past the view cone (half its arc > `rear_warning_angle_deg`) jumps the token queue from behind. A 90° Punk never does. Turning `blind_spot_needs_wide_arc` off restores "any enemy".
- **Punks never come round behind you on their own (Spec §7, §8; the rear-warning question, left at its default):** a Punk reaches your back only when you turn it on him after he engages, so the warning fires mostly for Kickers, the Bruiser's flank, the boss, and Punks you turned away from. A wider `punk_arc_deg` (or a wider variant, as the veteran Punk's 140°) lets them reach round.
- **M5-3. Stairs where the reference climbs ladders (Spec §9):**
  - Graybox stair flights replace the ladders, with no new player state, and enemies still come down them at you.
  - Walking bodies ride a hidden ramp on the step tips; bodies lying down rest on the steps.
  - A first-person ladder climb is an M7 option.
- **Where the spec is silent:**
  - **Edges:** the player can't fall. An invisible guard holds him in every state. Enemies knocked down, launched or thrown over an edge are KO'd at once.
    - With `level_edge_guard` off, a fall costs `level_fall_damage` (20) and respawns the player at the arena's start.
  - **The player's KO** revives in place, and the arena stays locked. There are no lives.
  - **The level's end:** the boss and his adds down shows "CLEAR!".
- **Graybox stand-ins:**
  - Screen 11's chain-like weapon is the pipe until M6 designs an original second weapon.
  - The veteran Punk is marked by an orange tint over the whole Punk art.

**Automated checks:**
- `tools/run_tests.sh` runs about 1730 tests headless in about 300 s. Among them:
  - an end-to-end suite where a scripted player performs every combo in the real test room;
  - each milestone's done-when test (`tests/test_m3_done_when.gd`, `tests/test_m4_done_when.gd`, `tests/test_m5_done_when.gd`, which plays the whole level arena by arena);
  - the level's own tests (`tests/test_m5_street.gd`, `tests/test_m5_roofs.gd`, `tests/test_level_kit.gd`, `tests/test_level_bot.gd`).
- `tools/capture_combos.sh` records the combo bot with Movie Maker to `captures/combos.avi`, writes a hit log to `captures/bot.log`, and extracts stills for review. Pass text to run only matching acts, for example `tools/capture_combos.sh "haymaker"`. `tests/bot/ragdoll_bot.tscn` and `tests/bot/vfx_bot.tscn` play the ragdoll and VFX acts the same way (record them with Movie Maker, `--write-movie`).
- `tests/bot/crowd_bot.tscn` plays the crowd street the same way: its acts are in `tests/bot/acts/` (one file per area, such as `crowd_acts.gd` for the mixed six, the waves to the boss, the mixed waves, the boss wave held back and the rear warning for every archetype). Pass text to run matching acts and `--seed=<n>` to repeat one with other seeds, for example `tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/crowd "Mixed six" 6`. A probed act runs the readability probe, which writes `readability.json` (15 metrics, five of them hard) next to the recording, and the warning oracle, which checks the HUD's corners against Spec §8 at every wind-up. The perf act is recorded windowed, not with Movie Maker: `godot --path . res://tests/bot/crowd_bot.tscn -- --act="Perf, six with ragdolls"`.
- `tests/bot/level_bot.tscn` plays a level, or a lone section, arena by arena. `--level=<res:// path>` picks it, and `--from=<arena>` / `--to=<arena>` pick the arenas.
  - Acts: "Run: held back" (real damage, the probe in every arena), "Run: knock-off" (a Punk launched over the chosen arena's drop), "Run: timing" (god mode at full speed; run it headless with `--presentation=0` for the `LEVEL` time) and "Look: seams" (both section seams, barrier closed and open).
  - Record any bot with `tools/capture_bot.sh`, or several acts at once into one folder with `tools/record_acts.sh <out dir> "<slug>|<act title>" ...` (`BOT_SCENE` picks the bot, `CAPTURE_ARGS` passes its arguments).
  - The bot's held-back pilot never jumps, so the boss's unblockable Ground Pound always lands. Its A7 damage and time are higher than a human's.
- `tools/check_m3_log.py <bot.log>` reads a crowd bot log and exits 1 if a warning corner is missing or wrong, a token count goes over the cap, a hard metric fails or the log has a script error. `tools/capture_bot.sh` writes `bot.log` next to the recording.

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
| `GEMINI_API_KEY` | Google Gemini, image generation (concepts and the character views) | yes, since 2026-10-26, on a billed (Tier 1) project; sent in the `x-goog-api-key` header by `tools/gemini_image.py` |
| `TRIPO_API_KEY` | Tripo, 3D generation and auto-rigging | yes, since 2026-10-26; every paid call goes through `tools/pipeline/tripo.py --spend <credits>`, logged in `assets/source/tripo_ledger.jsonl` |

## Toolchain status (Milestone 0)

Checked on 2026-10-21 on the dev Mac (Apple M1, macOS 26.3).

| Tool | Status | Notes |
| --- | --- | --- |
| Godot 4 (standard) | ✅ 4.7.2 | Installed via Homebrew; `godot` is on PATH. Headless import and tests work. |
| Blender + Blender MCP | ✅ Blender 5.2.2 LTS / ❌ MCP | Blender installed with Homebrew on 2026-10-26 (`blender` on PATH, headless Python works); 5.2 is the current LTS (the spec's "4.x" predates it). The Blender MCP is connected to Game-boy's own open Blender (2026-10-26); the pipeline never uses it and runs Blender headless (`tools/pipeline/run.py`). |
| Git | ✅ 2.50.1 | |
| Git LFS | ✅ 3.8.0 | Initialized for this repo only. |
| GitHub CLI | ✅ 2.93.0 | Logged in as `mikedtcm22`. |
| 3D generation API | ✅ Tripo | Chosen by Game-boy on 2026-10-26. The v3 API, image-to-model and auto-rig (`tools/pipeline/tripo.py`). |
| Image generation API | ✅ Google Gemini | Chosen by Game-boy on 2026-10-26. Billed since 2026-10-26 (the free tier gives no images); `tools/gemini_image.py`. |
| Mixamo | ⏸ skipped for now | Game-boy, 2026-10-26: skip it and decide later whether it is needed; Tripo's auto-rigging is tried first. |
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
