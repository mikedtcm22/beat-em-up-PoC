# Milestone 2, phase 3: Game-boy's changes, integration and review

Written on 2026-10-24 by account D's working session, from Game-boy's answers that day, for the account that takes over. Branch: `m2/hit-feel` at `33fcc98` (WP1-WP4 and the localized flash merged; 437/437 tests). Read [M2-plan.md](M2-plan.md) "Phase 3" and the newest [HANDOFF](../HANDOFF.md) entry first.

## Decisions (Game-boy, 2026-10-24)
1. **The hit's push on a ragdoll: at the exact contact point.** Game-boy leans to the spec's "impulse at the contact point" (SPEC §6), since exaggerated comic contortions are fine, even preferred. The current build gives the struck body part a capped central kick instead. WP4's builder dropped the off-center push during development because light parts (the neck, a forearm) spun at about 50 m/s, which is close to a body part per frame. That is a glitch, not a contortion.
   - Nobody has recorded what it looks like, so Game-boy hasn't seen it.
   - Build it and show A/B captures before settling it (item A1).
2. **KO bodies blink off.** A KO'd body lies down for a short time, then blinks off the screen, the way old beat-em-ups did, instead of staying until the arena clears. This is a departure from SPEC §6 ("Bodies stay until the arena clears, then fade out"), so it needs a README entry.
3. **The rest of the WP4 builder's questions are approved as they are:**
   - KO bodies take no hits;
   - heavy-tier hits that knock a body off its feet (back elbow, flying kick, spin kick, thrown weapon, flying-body knockdown) get the full ragdoll. The SPEC §6 tier table gives heavy hits a partial ragdoll, so this needs a README entry.
4. **Staggers may be stronger than SPEC §6's 0.3-0.6 influence**, so they read from the side. This needs a README entry.
5. **New fix from Game-boy's testing: the grab.** While holding an enemy, the first-person view should pan down a little, so the player sees the knees land on the held enemy. The player's body should bend at the waist for the hold and the knees, instead of standing straight up. The spec doesn't constrain the grab camera, so this is not a departure.

Still open with Game-boy:
- the localized flash's side view (item C2);
- WP3's audio, which only he can judge by ear.

## Work
Check `mcp__ccd_session_mgmt__get_usage` before every agent launch, and size each launch to the headroom left below the 90% handoff (HANDOFF, "Usage rules for the working session"). Plan on about 25-50% of a 5-hour window per heavy agent. Packages A and B own disjoint files, so they can run as two agents at once, each in its own worktree off `m2/hit-feel`: create them with `git worktree add .worktrees/<name> -b <branch> m2/hit-feel`, then run `godot --headless --import --quit` in each. Tell each agent its absolute worktree path and to `cd` there for every command. The Workflow tool's `isolation: 'worktree'` fails here.

### A. Ragdoll changes (worktree `.worktrees/m2-ragdoll2`, branch `m2/ragdoll-tune`)
Owned files:
- `game/actors/ragdoll.gd`, `game/actors/humanoid_rig.gd` (ragdoll parts only);
- `game/actors/combat_actor.gd` (KO and reaction hooks only), `game/enemies/dummy/training_dummy.gd`;
- the "Ragdoll" group and `dummy_revive_s` in `tuning_data.gd`;
- `tests/test_ragdoll.gd`, `tests/bot/ragdoll_bot.gd`.

1. **Push at the contact point.**
   - Add an off-center impulse at the hit's contact point, on the struck region's body (head, torso, legs; arms for guard breaks and parries), so the body twists and contorts along the hit.
   - Cap the spin: `ragdoll_max_spin` exists. Add a cap per body part if the neck or forearms still whip.
   - Keep the central kick as the alternative behind a tunable (for example `ragdoll_kick_at_contact`, default on).
   - Record A/B sheets, central versus contact, in first person and side view: the hook stagger, the uppercut, the haymaker, the spinning heel and a guard break.
   - Judge: exaggerated is good; a part that tears, spins on its own or jitters is not.
   - Show Game-boy the sheets. If the contact push only reads as glitches even with caps, say so and keep the central kick.
   - A contact push is what the spec says, so it needs no README entry. The central kick, if kept, does.
2. **KO bodies blink off.** A KO'd body goes limp, lies for a tunable time, then blinks (flickers on and off, faster toward the end) and disappears. Tunables: `ko_linger_s` (default about 1.5 s), `ko_blink_s` (about 1.0 s) and the blink rate. The body is gone for good: free its ragdoll, hurtboxes and collision.
   - Training dummies in the test room must keep coming back. Lead default: after blinking off, a dummy respawns standing at its home spot after `dummy_revive_s`, with a short blink-in. It no longer gets up where it lay.
   - Milestone 3 enemies blink off and don't return.
   - The ragdoll bot's KO act should show the whole cycle.
   - Rules: presentation never writes game state, so the blink timing lives in the simulation (the actor). The rig only shows or hides.
3. **Stronger staggers.** Raise `ragdoll_partial_influence` above 0.6 (its range already goes to 1.0), together with the stagger impulse if needed, until staggers read from the side view as well as in first person.
   - Check first person isn't too floppy: the hook already knocks the head out of the frame.
   - Record A/B sheets at the old and new values.
4. **Tests:**
   - the contact push stays within its caps, with no NaN, after many hits in a row;
   - a KO'd dummy lies, blinks, disappears (no hurtboxes, no collision) and respawns at home;
   - stagger deviation at the new influence;
   - all existing tests pass.
5. Commit "M2 phase 3: ragdoll contact push, KO blink-off, stronger staggers (...)", and push.

### B. The grab: view down, bend at the waist (worktree `.worktrees/m2-grab`, branch `m2/grab-view`)
Owned files:
- the first-person camera code that applies move camera offsets (`game/camera/`, and `game/player/player.gd` if the hold's view lives there);
- `game/actors/placeholder_poses.gd` (`hold()` and the knee poses only);
- the knee in `tools/gen_moves.gd` (regenerate the moves as CLAUDE.md says; never edit only the `.tres`);
- "Grab and weapons" in `tuning_data.gd`;
- tests, and the grab acts in the bots.

1. **View down.** While holding, pitch the first-person view down by a tunable (`grab_view_pitch_deg`, default about 15-20°), eased in on the grab and back out on the throw or release. Use the knee's `camera_pitch_deg` and `camera_drop_m` in `gen_moves.gd`, as the kicks and the stomp already do, if the knees need more. Done when the knee visibly lands on the held enemy's body in first person, with the held enemy still readable.
2. **Bend at the waist.** The player's `hold()` and knee poses lean the torso forward from the hips (spine and chest), so the body isn't straight up and down. Check side view (it reads as a clinch) and first person. ARCHITECTURE's first-person rules still hold: no forearm or hand within 0.3 m of the lens, and nothing filling the view.
3. Check how this combines with the WP2 knee bursts (`vfx_bot` act "VFX: knees under the view") and the localized flash: both now land in view.
4. Tests: the view pitch while holding, eased in and back out, and the lens-clearance rules in the hold and the knees. All existing tests pass.
5. Commit "M2 phase 3: grab view and waist bend (...)", and push.

### C. Integrate, record, review (the lead, after A and B)
1. **Done (account E, 2026-10-24 12:25 CDT):** A and B are merged into `m2/hit-feel` (`2543cc6`, `f98bb21`), the preset regenerated unchanged (296 values), and 457/457 tests pass with no SCRIPT ERROR or ERROR. Also done: the speed lines draw from VfxDirector's seeded `rng` (`ac58377`), the help overlay's F1 label and the stale emission comment in `tests/test_vfx.gd` are fixed, and README has the controls and the three approved departures.
2. **Review, verify and fix as one Workflow** (Game-boy turned ultracode on at 11:38: thoroughness over cost; the usage rules still hold). Author the script inline (load the `workflow-authoring` skill first). The Workflow tool's `isolation: 'worktree'` fails here, so the lead makes every worktree before the launch and each prompt names its absolute path:
   - one per reviewer, detached at the `m2/hit-feel` head: `git worktree add --detach .worktrees/m2-review-<lens> m2/hit-feel`, then `godot --headless --import --quit` inside it;
   - fixers later, one branch each: `git worktree add .worktrees/m2-fix-<area> -b m2/phase3-fix-<area> m2/hit-feel`.

   **Stage 1, review (review only; each records its own captures in its worktree's `captures/`):**
   - **Code:** the phase 3 diff `f43ab9a..m2/hit-feel` (A, B and the lead's fixes). Correctness; layer rules (simulation never reads a camera; presentation never writes game state, including the vanish path through `CombatEvents.vanished`, `HumanoidRig.set_shown()`, `hud.gd`, `enemy_health_bars.gd` and `debug_draw.gd`); no feel numbers in scripts; edge cases:
     - a body that vanishes while held, thrown, in a pile or under a stomp;
     - a grab or lock-on aimed at a blinking body;
     - a respawn into an occupied post;
     - the player's own KO;
     - the hold view when the hold ends early: hit while holding, the held enemy KO'd by a knee, `hold_max_frames`, a release;
     - presets that predate the new tunables;
     - the contact push's caps and NaN guards.
   - **Ragdoll feel:** every `ragdoll_bot` act in both views. Whether the contact push reads, the staggers at 0.9, the KO lie, blink, vanish and respawn, and the localized flash on a ragdoll. Also A's known items: the side-view health bar on a staggered head, and blood splats left after a vanish.
   - **Grab feel:** the `combo_bot` grab acts (including "Grab looking level") and `vfx_bot` "VFX: knees under the view", first person and side view. The first-person rules (no forearm or hand within 0.3 m of the lens, nothing fills the view), the combat log over the knee contact, the blue sleeves against the blue knee, and the head as a skin dome from behind.
   - **Hit feel:** every `combo_bot` and `vfx_bot` act in both views, tier by tier: readability, and no effect filling the first-person view. Also HANDOFF 10:55's known items:
     - a hit on the player shows no flash in first person; does it still read?
     - the side-view flash hides under the burst;
     - the first finisher of a run drops about one frame;
     - light bursts are about 10% of the view at jab range;
     - the bruised look is subtle in side view;
     - the combat log covers the side view in `combo_bot` captures;
     - the speed lines now repeat between captures.
   - **Performance:** frame times with six ragdolls (about 1.2-1.5 ms before), the contact push, the flash overlay and the first finisher's dropped frame (shader or texture warm-up?).
   - Each reviewer returns findings through a schema: id, lens, title, severity, evidence (capture path and frame, test or log line), repro steps, suggested fix, and the files a fix touches.

   **Stage 2, verify:** in a `pipeline()`, so each lens's findings verify as soon as its review ends. For every finding, three skeptics, each told to refute it, one per lens:
   - reproduce it from captures or a test;
   - check it against SPEC, README's departures and HANDOFF's Decisions log, since approved behaviour isn't a defect;
   - read the code path.

   A finding survives with two or more confirmations. Skeptics are cheaper: a narrow scope, and a Sonnet model with medium effort is fine.

   **Stage 3, fix:** partition the surviving findings into fix packages with disjoint files. That needs all findings at once, so a barrier is justified here. Run at most two fixers at once, each in its own fix worktree. Each fixer:
   - fixes its findings and adds tests;
   - re-records the affected acts and judges them;
   - runs `tools/run_tests.sh` (all pass, no SCRIPT ERROR or ERROR);
   - commits `wip:` along the way, then "M2 phase 3: review fixes (<area>)", and pushes.

   Spec questions go back to the lead for Game-boy, not into code.

   **Stage 4, completeness critic:** which lens, act, view or finding went unchecked? What it names becomes another round, or goes in the report.

   **Usage gates:** a Haiku agent calls `mcp__ccd_session_mgmt__get_usage` before every heavy launch. A launch goes ahead only if its estimated cost fits the headroom left below the 90% handoff (HANDOFF, "Usage rules for the working session"). When it doesn't, the workflow runs a smaller piece that fits, such as one reviewer, and returns, so the lead hands off at 90%. At most two heavy agents run at once (reviewers and fixers count as heavy). Expect C to need more than one 5-hour window: a reviewer costs about 13% and a fixer about 25%. Within a session, resume with `resumeFromRunId`. Across accounts, the findings must be in the repo: have the workflow's first verify step write `docs/reviews/M2-phase3-review-findings.json` and commit it in a fix worktree, or have the lead do it.
3. **After the workflow:** the lead merges the fix branches into `m2/hit-feel`, regenerates the preset, runs the tests, pushes, records the final sheets (both views: grab, knees, ragdoll acts, KO cycle, a finisher), shows Game-boy the most telling ones, and updates HANDOFF.

### D. Docs and the PR
1. README:
   - Milestone 2 status, and controls (F1 tuning panel, F4 cheats).
   - New entries in "Where M2 departs from the spec": heavy-tier knockdowns get the full ragdoll, staggers above 0.6 influence, and KO bodies blink off. Add the central kick only if A1 keeps it.
2. ARCHITECTURE: the title still says "Milestone 1 contracts". Check the VFX, Audio, Ragdoll and Hit flash sections against the code, and add the KO blink-off.
3. Open the Milestone 2 PR from `m2/hit-feel` into `main`. The description ends with the Claude Code line. **Never merge it.** Game-boy plays it, tunes each tier live, saves a preset and signs it off.
