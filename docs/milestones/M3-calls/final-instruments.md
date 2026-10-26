# M3 final review: the instruments (wording for ARCHITECTURE.md)

The fixer for "instruments-and-evidence" does not own `docs/ARCHITECTURE.md`; this file holds the wording its changes need there, for the lead to paste when merging. Line numbers are those of `docs/ARCHITECTURE.md` at `a063e75`. The calls behind the changes are in `fix-final-instruments-and-evidence.md` (and, for the probe and oracle, "Amended by the final review fixes" in `P1-instruments.md`).

## Line 560 (the probe's paragraph): where `readability.json` goes

Replace "into `dir`, else the folder of `--write-movie`, else `--probe-out=<dir>`, else `user://`" with:

> into `dir`, else the probe's `out_dir` (a test's own folder), else `--probe-out=<dir>`, else the folder of `--write-movie`, else `user://`

(The code has always tried `--probe-out` before the movie's folder; the old text had the two the other way round.) And after "`write_on_exit` does that when the node leaves the tree, for a bot that only calls `get_tree().quit()`" add: "(into `out_dir` when set)".

## Line 578 (wiring): the oracle and the gap between acts

Replace the last sentence, "The oracle ignores the HUD while no act is open, so a wind-up cut off by the end of an act is nobody's false positive." with:

> The oracle ignores the HUD, and any wind-up that starts, while no act is open (the bot runs on 45 frames after an act and then resets the room), and `start_act()` empties its model, so a wind-up cut off by the end of an act, or begun in the gap before the next one, is nobody's false positive and is not judged under the next act's title. Between its READABILITY block and the next header the bot's log may still carry a `WARN-CHECK` line for such a wind-up; the log checker skips it (see line 732).

Replace "`readability.json` goes to the folder of the recording (`Engine.get_write_movie_path()`: `OS.get_cmdline_args()` leaves `--write-movie` out), else `--probe-out=<dir>`, else `user://`." with: "`readability.json` goes where line 560 says (a recording's folder, `Engine.get_write_movie_path()`, since `OS.get_cmdline_args()` leaves `--write-movie` out, unless `--probe-out=<dir>` names one)."

## Lines 567 and 569 (the R4 and R8 rows)

Append to both "Sampled" cells: "counted from the act's first frame (not the engine's frame counter), so an act samples the same frames whatever ran before it".

## Line 732 (the log checker): the skip rule

Replace "skips a wind-up that began after its act's READABILITY block" with:

> skips a wind-up that began outside its act: a `WARN-CHECK` line that follows a `READABILITY` block with no header since, or whose frame is earlier than the frame in the header of the act it is printed under (a wind-up that began in the gap before the act and was judged after its header; logs recorded before the oracle stopped doing that have such lines)

## Line 527 (EncounterSpawner): the start-at-wave hook

Add to the list of the spawner's calls: "`start_at_wave(number)`: make wave `number` (1 = the first; boss waves count) the next to start, after a full `wave_gap_s`; drops the wave in progress (what is queued never spawns, what spawned stays as ordinary enemies); `start_at_wave(1)` starts the sequence over, a number under 1 is 1. For bots and tests that need a later wave without playing the earlier ones; the crowd bot calls `start_at_wave(1)` in every act's reset."

## Line 734 (the acts)

After "Waves to the boss" (waves on, `boss_wave_every` 2, ...) add: "(the two opening Punk waves and the boss's arrival and call-in: no mixed wave, and the boss is beaten before it attacks)", and add two acts to the list: "Mixed waves" (the spawner starts at wave 3 with the boss waves off, the held-back autopilot for 90 s: the table's Punk, Kicker, Thug and Bruiser waves, WAVE lines for each start and clear) and "Boss wave, held back" (the spawner starts at the boss wave, `boss_wave_every` + 1; the held-back autopilot; the boss's health is set to the phase 2 line by hand if the autopilot has not taken it there in 45 s (a `BOSS ... forced` line says so); then 30 s with its Punks in: the boss's attacks and adds in a crowd). In the "Perf, six with ragdolls" sentence replace "the worst frame after a body goes down" with "the worst frame after an enemy goes down", and add: "the engine monitors it prints (`process`, `physics`) hold the maximum of the last second, not the last frame; the bodies are counted directly (simulating ragdoll bodies of running, not-asleep ragdolls, and awake pipes); the frame lines and the probe's R15 are the measure". Under "Crowd bot additions" add: "`_reset` starts the waves over (`start_at_wave(1)`) and reseeds the spawner's random generator."

And under `tests/test_m3_done_when.gd` (*The waves*) add: "A second case starts the spawner at wave 3 (the table's mixed waves, no boss wave, the autopilot held back, 2700 frames, god mode, the probe on): `alive_count()` never over `wave_max_alive`, at least three archetypes seen, R1, R3 and R10 held."

## `CombatEvents.released` and `grab_escaped`

If the contracts section lists the events: "`released(holder, victim)` and `grab_escaped(victim, holder)` carry `null` for the holder when it was freed mid-hold (a typed listener cannot take a freed object); a listener must not assume the holder is there."
