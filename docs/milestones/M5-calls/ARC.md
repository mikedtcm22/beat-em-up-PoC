# M5 ARC: judgement calls and re-measured numbers

Each call: the decision / an alternative not taken / why.

## Calls

1. **Wait seats keep their own spacing by body size, not by angle.** Two wait-seated enemies are at least `2 * enemy_avoid_radius_m` (0.9 m) apart, flat. / The inner seats' 40 degree gap at 6 m (4 m of chord, only 3 waiters in a 90 degree arc). / A 90 degree arc then seats 10 waiters, none of them touching; the plan gave no wait gap.
2. **Inner seats sit on a grid of the arc** (as many as fit `director_seat_gap_deg`, evenly across: 90 degrees = -45, 0, +45), each enemy taking the free grid point nearest where it stands, then any free 5 degree step in the arc. / First come, first served at any angle. / The first two Punks could take -10 and +30 and leave no room for a third at 40 degrees: a 90 degree arc must really seat three (the plan's test).
3. **Radii step down for an inner seat too** (to the ring's near edge), not only for a wait seat (plan D3 (b)). / Fail and slide at once. / A wall at 3.2 m facing the player leaves no seat at an enemy's own 3.8 m radius at any angle, but a seat at 2.7 m; sliding the arc away for that would turn a Punk off its front for nothing.
4. **Keepers.** A seat is kept (not re-found each reslot) while its enemy has engaged, holds an inner seat and the seat lies inside the arc; a token holder always keeps it. An enemy that never engaged (walking in) holds nothing and ranks last, nearest first. / Everyone re-seats every reslot (flicker). / The longest waiter takes a freed seat, as the plan says, and a settled crowd keeps its seats.
5. **Engagement ends with WINDUP, ATTACK, RECOVER, REACT, KO and ENTER** and begins again on POSTURE, ENGAGE or APPROACH within `arc_engage_radius_m`; an approaching enemy that is already engaged stays engaged at any distance, and its old line and seat are kept while it is not engaged. / Engaging on the first token or at spawn (plan D1 turned both down). / Keeping the old seat through a recovery means a Punk backs off to the seat it came from and re-engages on arrival, with the look as it is then.
6. **The line is tracked in the director (a book per enemy), the arc center for the strafe is `debug_arc_center_of()`** (line plus slide), an extra read call beyond the four of the plan. / Reading `debug_line_of()` and adding the slide in the actor. / A slid arc's seats are centred on the slid center: strafing about the unslid line would walk it out of its seats.
7. **A reslot is also forced when an engaged line drifts more than `director_slot_retry_deg` from the line its seat was made for** (a turn inside the grace, a new engagement). / Wait for the 1.5 s timer. / Inside the grace the seats must follow a turn within a few frames or the "a Punk behind you walks round to your front" would take seconds.
8. **A boss that woke in place inside its arc keeps the priority and may be granted even from a wait seat;** the Kicker is always an inner seat. / Only inner seats, no exception. / The plan's D4.
9. **`stub_enemy.gd` edited (not in ARC's ownership list):** `set_slot(pos, kind = &"inner")`. / Leaving it: the override with fewer parameters than the base is a script error. / Nothing else in the file changed.
10. **The veteran's tint** is the primitives' `body_color` plus the art material's `albedo` (a whole-body multiply on the palette). / The jacket colour only: the art Punk draws the palette atlas, the primitives are hidden. / The tint shows on the art (an orange cast in the "Arcs: mixed six" sheet); logged because no paint seam in the art takes a jacket-only colour.
11. **R9's population:** a waiter counts only with an inner seat, and as "out of view" only when `blind_spot_eligible()` says so. N/A when none waited. / Counting every waiter as M3 did. / D6.
12. **Reading `director_even_spread` in tests:** a Debug value is not reset by `Tuning.reset_to_default()`, so every test file that sets it resets it in `before_each` and `after_each` (a leak made the wall test fail in the full-file run).

## Metrics re-measured (D6): before and after

"Before" is M3's director on the captured crowd acts (`captures/m5-baseline`, the lead's recordings of the crowd room before the arcs); "after" is the arcs on "Arcs:" acts (`tests/bot/acts/arc_acts.gd`, `captures/arc`). The crowd is different (the arc acts are Punk-heavy), so the rows are not like for like; the like-for-like check is the twin soak in `test_m3_done_when.gd` with the switch on, which asserts M3's numbers.

| Row | Before (M3, mixed six) | After (arcs) | Note |
| --- | --- | --- | --- |
| R1, R2, R3, R10, R11 (hard) | ok in every act | ok in every act (R1 max 1, R2 min 35 f, R3 0 of 6..10 hits, R10 100% of 3..18) | unchanged |
| R5 front wedge crowded | 0.0% | 0.0% in all four acts | population: inner-seated within posture_ring_max_m + 0.5 |
| R5a (the M3 population, every posturing enemy) | n/a | 34.1% in "six Punks" (the wait ring in front, by design), 0.0% elsewhere | information |
| R5w wait seats inside 5 m | n/a | 0.0% | new twin |
| R6 ring, median / p10 | 2.91 / 2.51 observed; 3.00 / 2.59 fight | 2.66 / 2.54; 2.72 / 2.64; 3.52 / 2.58; 2.73 / 2.59 | inner-seated only; limits unchanged (2.5-4.0, p10 >= 2.2) |
| R6a ring, all posturing | same as R6 | 5.83 / 2.60 in "six Punks" | information |
| R6w wait ring, median / p10 | n/a | 6.23 / 5.68; 6.65 / 6.65; 6.36 / 6.36 | new twin; limits 5.0-7.0 |
| R9 blind grants | 67% of 3 observed; 100% of 1 fight | 60% of 5 (mixed six); n/a elsewhere (no blind-eligible waiter out of view) | population: inner-seated, blind-eligible out of view |
| R7 capsule overlap | 0 | 0 in every act | unchanged |
| R13 stuck | 0 | 0 | unchanged |
| R8 lens coverage p50 / p95 | 3% / 31% observed; 25% / 53% fight | 23% / 44% (six Punks); 24% / 50% (mixed) | soft limits 25% / 50%: held |

## Tests changed

- `test_readability_probe.gd`, `test_verdict_passes_a_clean_run_and_names_each_threshold`: `rows.size() == 15` became "15 rows named R1..R15" (the M5 info and twin rows R5a, R5w, R6a, R6w are extra); twin assertion: each of the four exists.
- `test_enemy_director.gd`: six M3 spread tests set `director_even_spread = true` (old behaviour asserted unchanged); the tests of tokens, the cap, the blind roll, the Kicker and the navmesh run on the new default with stubs (360 degree arcs).
- `test_m3_done_when.gd`: the soak is now a helper run twice (arcs; the switch on, asserting M3's numbers).
- `test_m3_contracts.gd`: the catalog's id list gains `punk_veteran`.
- `test_slice_crowd.gd` (not in ARC's ownership table; the three tests that assert M3's spread: six Punks round a standing player with R9 "outside the view", "the posture slots are spread all round the player", "a fought mixed six keeps posturing and the Kickers behind"): each sets `director_even_spread = true` as its first line, assertions unchanged, and the file resets the switch in `before_each`/`after_each`. Twin on the visible path for the new default: `tests/test_attack_arcs.gd` and the arc acts. Reported as a request below.
- `test_m3_contracts.gd` (`ENEMY_SUBGROUPS`) and `test_tuning_panel.gd` (the heading list): "Attack arcs" added after "Director" (the plan's own new subgroup).
