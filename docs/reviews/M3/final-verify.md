# M3 final fixes: independent verification

An Opus verifier re-checked the final review's high and medium fixes in first person, at `f12e607` (worktree `.worktrees/m3-verify-final`, local). It reproduced each finding with the reviewers' own acts plus probe acts of its own. Nothing was committed.

- **Regressions: none.** 1177/1177 tests pass with no SCRIPT ERROR or ERROR. `test_m3_done_when.gd` passes 5/5, and `tools/check_m3_log.py` is ok on all 11 recorded logs.
- **final-crowd-01, the lens under the street in face-down knockdowns: HOLDS.**
  - Over 12 cases (the Kicker at 0/90/180°, the Bruiser at 0/135°, the boss at 0°, looking level and 20° down), the lowest the lens goes is 0.131 m, with 0 frames under the floor. Before, it went to -0.044 m for 67-68 frames.
  - Still uncovered: a face-down fall into a wall, crate or curb face.
- **final-tells-01, the boss pound's cap through the lens: HOLDS.**
  - The nearest boss mesh is 0.41 m with the player at 0.9 m, against 0.00 m before.
  - In a real fight (5400 frames) it is 0.30 m at the nearest, with 0 frames under 0.25 m.
  - Leftover: with the player jumping the pound at 0.9 m, the follow-through passes at 0.249 m for one frame.
- **final-tells-02, the dropped pipe rolling out of reach: HOLDS.**
  - The pipe rests 0.61-0.66 m from the player within about 50 frames and stays there 20 s.
  - In a real fight, 4 of 5 pipes landed 1.6-2.5 m away, because the Thug is knocked back before it drops the pipe. The player walks to them.
- **final-fair-01, the boss stun-lock: PARTIAL.**
  - The boss now wakes in place and winds up, but a player chaining P P P P still knocks it down about every 3.3 s and kills it in 38-40 s.
  - It spends 53-56% of its life in REACT and lands 2 hits.
  - The lead's follow-up fix is package `F-boss-poise`.
- **final-crowd-02/03, the lens walls and the Kickers stopping the posture: HOLD.**
  - Posturing is 1.3-2.0 of 5.8 across seeds 0-4, against 0.38-0.78 before.
  - APPROACH lens-wall samples are 0-5 of 388, against 12-34 before.
- **final-tells-04, the slam read as the headbutt: HOLDS.** The slam heaves back with both arms flying up and out, and reads differently from the headbutt's dive.
- **Known, unchanged:** a face-up knockdown shows the player's own body over 70-75% of the view for about 1 s (M2's default, open with Game-boy).
