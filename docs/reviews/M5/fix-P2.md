# M5 post-merge fixer (FIX2): what only the whole level shows

STREET, ROOF and FINALE are merged into `m5/level-blockout`. `game/level/mission1/mission1.tscn` (a `LevelRoot` over `street.tscn`, `roofs.tscn`, `boss_roof.tscn`) is the main scene. It plays start to boss: the god-mode timing run cleared all 7 arenas in order in 194.8 s, with no STALL or BLOCKED.

The full suite shows 1719 of 1721 passing; both failures are in `tests/test_m5_done_when.gd`. Fix each item below at its root. Keep every other test green.

You own:
- `tests/test_m5_done_when.gd`, `game/level/mission1/*` (the three sections, the level and `encounters/a*.tres`), `game/level/kit/*` and `game/ui/go_cue.gd`;
- `game/level/encounter_spawner.gd`, `tests/bot/level_bot.gd` and `tests/bot/level_acts/*`;
- the tests of those files, and the "Level" group of `game/autoload/tuning_data.gd`. If you add a tunable, regenerate `tuning/default.json` as earlier milestones did (grep HANDOFF for "preset").

Don't touch README.md or HANDOFF.md (the lead's). Your calls go in `docs/milestones/M5-calls/FIX2.md`, and the contract changes go under ARCHITECTURE.md's existing Mission 1 and Level kit headings.

## 1. The section-first arenas never lock in the done-when (test failure)
`test_every_arena_locks_spawns_its_table_and_clears_in_order`: `street_a1` (arena 0) and `a4_terrace` (arena 3) are the first arenas of their sections. They never leave WAITING after `LevelRoot.start_at_arena(k)` (`game/level/kit/level_root.gd:160`), so they spawn 0 enemies. That makes the level total 27 of 34 and breaks the lock and clear orders.
- Arena 0: `start_at_arena(0)` puts the player at `player_start`, the street's `Start` (3, 0, 0.8). A1's lock volume begins at z -1.5, so he is outside it, and the test's autopilot never walks him in. The test's own comment assumes he starts inside, as on the lone boss roof.
- Arena 3: `first_route_point(A4)` is presumably outside A4's `LockTrigger` (`roofs.tscn`, `Arenas/Arena4`).
- Decide where the fault is and fix it there: the level data (Start, Route, LockTrigger), `start_at_arena`, or the test's assumption.
  - In play, the player must still walk into A1 from the street end: the bot run shows `ARENA+ f57 street_a1`.
  - `level_bot --from=<arena>` uses `start_at_arena` too, so `--from=3` must lock A4.
- Done when the test passes on the whole level, with 7 arenas in order, 34 enemies (the boss's 2 adds included) and the wall budget.

## 2. A double wall at the ROOF / FINALE seam, z -83 (test failure)
`test_no_two_sections_solid_blocks_overlap` finds 8 overlaps. Section 1 (roofs) and section 2 (boss roof) both put solid blocks on the seam line, in level space:
- Boss roof: P (11, 12, -83) S (1, 5, 0.6); P (12, 12, -83) S (8, 3, 0.6); P (24, 12, -83) S (8, 3, 0.6).
- Roofs, overlapping them:
  - P (8.5, 9, -83) S (3, 5.6, 0.5) and P (8.5, 11.6, -83) S (3, 3, 2);
  - a tall block P (11.5, -0.5, -83) S (4, 15.1, 2);
  - P (15, 12, -83) S (0.6, 1.4, 19);
  - P (15.6, 12, -82.8) S (4, 4.5, 4) and S (4.4, 3.5, 0.2);
  - P (24, 12, -82.8) S (5, 3.5, 0.2).

Give each piece of the seam one owner. The A6/A7 gate is ROOF's `ExitBarrier` (GATE, 4 m, centred on the Exit at (22, 12, -83)). Remove or trim the duplicates so nothing stands doubled or z-fights, there is no gap round the closed gate, and the boss roof's entry fence still closes everything but the gate.

Look in first person from both sides of the gate, standing in A6 and in A7, with the gate closed and open. Done when the test passes and the look is clean.

## 3. The STREET / ROOF seam, z -53
STREET's seam shutter (its `ExitBarrier`, 6 m wide, x 0..6 at y 4.5) opens onto the terrace. ROOF reported that the shutter's last metre meets the terrace's right wall. ROOF's EntryWall (z -54..-53) closes the terrace's rear-left corner. Nobody has looked at the two together.

Look in first person from the stair landing and from the terrace, with the shutter closed and open. Fix any gap, a double wall, or a shutter that slides into or through geometry. Done when the look is clean.

## 4. The GO cue's triangulation ERROR
`game/ui/go_cue.gd:191` (`_draw_arrow`) printed `ERROR: Invalid polygon data, triangulation failed` once in a presentation run, after A5 cleared, with the arrow pointing toward A6. The arrow polygon degenerates for some look/target angle.
- Make the polygon valid at every angle: skip or clamp the degenerate case.
- Add a test that draws or builds the arrow over a sweep of angles with no ERROR.

## 5. A named spawn can hold its wave for ever
`EncounterSpawner._spawn_named()` (`encounter_spawner.gd:395`) falls back only to a free point with the same tag. A2's Alley and Office, and A3's Brick, have unique tags. While the player stands within the spawn clearance of such a point, its enemy (and the wave behind it) waits indefinitely, so a player holding that spot stalls the arena.
- Add a second fallback: after a further wait (a new tunable in "Level" > "Arena locks", for example `spawn_named_any_wait_s`), take the nearest free point of any tag in the same arena.
- Add a test: hold the player at a unique-tag point and the wave still arrives.

## 6. The knock-off act always uses A4's drop
`tests/bot/level_acts/run_acts.gd`'s "Run: knock-off" picks the first hazard by flat gap to each arena's lock box, so the catwalk's and the boss roof's edges are never recorded.
- Let `--from=<arena>` choose the arena, or pick the hazard nearest the player in the current arena.
- Then `CAPTURE_ARGS="--level=res://game/level/mission1/mission1.tscn --from=4"` records the catwalk drop, and `--from=6` the boss roof's edge.

## 7. Anything else the lead's look finds
The lead's notes on the whole-level held-back recording are appended below, if there are any. Fix those too.

## Done when
- The full suite passes with no SCRIPT ERROR, SHADER ERROR or ERROR line. Run it alone on the machine and report its time; M5 has grown it to about 325 s.
- The whole-level "Run: held back" recording is clean at both seams. Record it with `BOT_SCENE=res://tests/bot/level_bot.tscn CAPTURE_ARGS="--level=res://game/level/mission1/mission1.tscn" tools/record_acts.sh <worktree>/captures/fix2 "held|Run: held back"`.
- One knock-off act recorded on the catwalk.

Report each item as fixed, with the commit, or why not.

## The lead's look (whole-level "Run: held back", `captures/m5-p2/rec/held/`: bot.avi, bot.log, readability.json)
The bot plays all 7 arenas in order with real damage: `LEVEL 437.4` s, A1 20.4, A2 54.5, A3 53.0, A4 45.7, A5 50.8, A6 70.1 and A7 112.2 s. Every hard readability row holds in every arena. In first person:
- the street's gates, cars and shutter read;
- the stair up to the shutter and onto the terrace is clean at this resolution;
- the GO arrows point the right way;
- the A6 crowd reads, and the A6/A7 gate posts frame the boss roof;
- the boss walks out of the roof door, his two adds come at half health, and "CLEAR!" shows.

Items for you:
- **7a. The go_cue ERROR** (item 4) appeared once in this run too.
- **7b. R13 in the boss arena** reads "miss": its limit wants at least 2 waves, and A7 has one wave plus the boss's adds. Make R13's wave count not apply to a table with fewer than 2 waves (the boss arena), in `readability_probe.gd`, and keep the crowd room's meaning. A7's R6 p10 of 1.80 m and R8 p95 of 57% come from the boss's size up close: leave them for the review.
- **7c. A ~11 s pause** at 432 s is a key press that reached the recording window (`GameInput.set_paused`); the bot never pauses. No fix, but keep focus off the recording window when you record.
- **7d. The seams weren't looked at backwards.** The bot only looks ahead, so the doubled walls at z -83 were never seen from A7 looking back at the gate. Look at them yourself (item 2).
