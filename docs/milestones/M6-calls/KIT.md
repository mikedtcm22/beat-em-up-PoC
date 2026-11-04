# KIT: judgement calls and numbers

## Baseline ref

- **M5 baseline ref for D29: `910448e`** ("Perf: level walk"). It holds the act, the level bot with the recorder and `perf_compare.sh --bot`, and no art. Compare the end of M6 with it:
  `tools/perf_compare.sh --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" 910448e <ref>`.

## Calls

1. **The recorder is shared, not copied.** Decision: the frame-time recorder moved out of `perf_bot.gd` into `tests/bot/perf_recorder.gd`, used by `perf_bot.gd` (same output line, same fields) and by the new `perf_level_bot.gd`. Not taken: a second copy in the level bot (two recorders drift apart). Not taken: a `--level` switch in `perf_bot.gd` (it extends the crowd bot, the level bot extends the crowd bot too, and GDScript cannot pick the base at run time). `perf_compare.sh` copies the bench's files (`tests/bot/perf_*`, plus `level_acts/perf_acts.gd` for `--bot`) into each ref's worktree, so a ref from before the act can be measured.
2. **The act plays arenas 0-5 with the autopilot, not a bare walk.** Decision: god mode and `run_level(0, 5)`, seeded, full speed. Not taken: a walk with the arenas skipped: the barriers only open on a cleared arena, and an empty level hides the enemy and effect load that the frame time is measured under. The route and waves are the same on every checkout, the fights differ in length only by the art's draw cost (the frame counts are logged in the result).
