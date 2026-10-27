# M3 slice gate: the Street Punk, end to end

Judged on 2026-10-26 by the lead and the slice review round (`docs/reviews/M3/workflow-review.js`, round "slice", base `356fccf`). The records are in `docs/reviews/M3/slice-*.json`, and the review run was `wf_10d57668-722` (64 agents).

The round had:
- three Opus reviewers: L1 warning, L2 crowd readability, L4 code and layers;
- three Sonnet skeptics per finding;
- one fix package, `m3/fix-slice-punk-crowd-pressure`, merged at the commit after `4470830` (869/869 tests).

## Verdict: the gate passes, with one follow-up fix
- **Hard metrics** (Part B §B2) pass in every act and every seed: 42 runs by the crowd reviewer, plus P1-int's runs.
  - R1: at most 2 attackers at once (the cap is 3).
  - R2: wind-up starts at least 21 frames apart.
  - R3: 0 unwarned hits.
  - R10: 100% agreement, with 0 false positives, 0 latency and 0 end lag.
  - R11: max 0.
- **The rear warning (the done-when's second half) passes,** with training dummies and with real Punks, clause by clause against Part B §B1 (L1 reviewer; sheets in `.worktrees/m3-review-slice-warn/captures/review/sheets/`, local).
  - Behind-left lights the top-left only, behind-right the top-right only, directly behind both corners. The 161°/159° edge lights both and then one.
  - Nothing shows in view or out of range.
  - The warning shows on the wind-up's first frame and ends on contact, a block, a whiff, an interrupt or a KO, never when the strike comes out.
  - Two attackers on a side read brighter, and a heavy one larger.
  - Pause, the 0.25x cheat, slow-mo, the impact frame over the HUD and the KO-view hide all behave, and the audio cue's stereo direction matches.
  - Across 190 and 134 real-Punk wind-ups, R10 was 100%.
- **Crowd readability (the done-when's first half, for the slice):**
  - **Fixed** (found by the L2 reviewer, confirmed by the skeptics):
    - backing-off Punks walked the wrong way at up to 6 m/s (a stale latched avoidance velocity; fixed, peak walk now 3.0 m/s, 0 wrong-way frames);
    - Punks hardly postured (the cooldown never bound; fixed by retuning the cadence, below);
    - non-attacking Punks walled the lens. R8 p95 now passes in 29 of 32 runs; the misses are marginal, at 51-57%.
  - **Rubric:**
    - Q1 in-view wind-ups read at 1 m;
    - Q2 corners match;
    - Q4 no two wind-ups start together;
    - Q7 attackers back off;
    - Q8 taunts and strafes never read as threats;
    - Q3 archetypes tell apart (only Punks so far).
  - **Flinch-lock:** the longest chain is 0.72-1.13 s, under 1.5 s, after P1-int's hit grace.
  - **R6 ring:** median 2.66-3.44 m, p10 at least 2.42 m.
  - **R13:** 0 stuck in every act; 3-4 waves cleared in 90 s.
  - **R15 windowed:** p95 frame 12.2-12.3 ms; spawn hitch 26-31.5 ms, against a 33 ms limit (little margin, to watch with bigger rigs).
  - **Get-ups:** 2 of 21 in the knockdown act moved the origin 0.74-0.79 m in one frame, both behind the player. That is M2's design (the body gets up where it lies).
- **Follow-up before phase 2 closes (package `P1-engage`):** a token holder that has stepped in waits at the player's nose for the director's go, for 2-3 s while rear hits land, covering 40-60% of the lens. It should wait squared up on the ring and step in only when its go is near. P1-engage also takes the lone Punk on the player's axis, which slows to 0.4 m/s at about 1.05 m (ORCA against the player obstacle) and times out of ENGAGE.

## Refuted, and the calls they leave
- **slice-warn-01:** a Punk winding up 46-55° off the look at strike range is off-screen, since the lens's 90° FOV covers ±45°, and gets no warning. The skeptics refuted it as a defect: SPEC §8 sets 55°, and Part B §B1 binds it. **Call: keep the spec's 55°** (`rear_warning_angle_deg`, tunable). *Alternative:* 45° to match the FOV, or measure the bearing from the lens. *Why not:* it's a spec number. It goes in the digest for Game-boy, and he can set 45 in F1.
- The rest (slice-warn-02, slice-crowd-04/05, slice-code-01..04) were refuted or out of scope: a training-room re-arm during the KO ease-back, the same off-screen band seen from the crowd lens, a probe blind spot, per-act metric reproducibility, the seeding of an F4-ensured director, the exit message of a headless main-scene run, and a few missing `##` docs.

## Feel defaults locked at the gate
| Tunable | Value | Why |
| --- | --- | --- |
| `posture_ring_min_m` / `_max_m` | 2.5 / 4.0 | SPEC §7. Measured median 2.66-3.44 m. |
| `posture_circle_speed_mps` | 1.1 | Reads as circling with no jitter. |
| `punk_attack_cooldown_s` | **5.0** (was 1.4) | Lowest swept value with R8 p95 passing in every seed. Below about 4 s it never binds, because it counts from the attack's end through the recover and the walk back. |
| `attacker_cap` | 3 | SPEC §7. R1 measured at most 2. |
| `director_min_windup_gap_s` | 0.35 | R2 at least 21 frames. |
| `director_hit_grace_s` | 0.5 | P1-int. It ends the flinch-lock (longest chain 4.8 s before, 1.15 s after). |
| `engage_margin_m` | 0.05 | P1-int. Fewer lens samples over 50%. |
| Wind-up | Punk jab 22 frames (floor 18) | Reads at 1 m and 2.5 m. The hold from 80% of the startup. |
| `wave_max_alive` | 6 | SPEC §7. With the 5 s cooldown about two of six attack at a time, and the rest posture. |

Pressure fell a lot with the 5 s cooldown: the held-back autopilot takes 9.5 hits in 90 s of waves, against 32.8 before. A passive player still dies in 14-16 s, and the worst 2 s of damage is exactly the limit of 30. That matches SPEC §7's "the danger is numbers... spend most of their time posturing". Mixed waves in phase 2 add the Kicker's flanking and the heavies.
