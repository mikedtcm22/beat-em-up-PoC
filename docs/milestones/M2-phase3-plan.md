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
Check `mcp__ccd_session_mgmt__get_usage` before every agent launch, and launch nothing new at 65% or more of either window. Plan on about 25-50% of a 5-hour window per heavy agent. Packages A and B own disjoint files, so they can run as two agents at once, each in its own worktree off `m2/hit-feel`: create them with `git worktree add .worktrees/<name> -b <branch> m2/hit-feel`, then run `godot --headless --import --quit` in each. Tell each agent its absolute worktree path and to `cd` there for every command. The Workflow tool's `isolation: 'worktree'` fails here.

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
1. Merge A and B into `m2/hit-feel`. Then run `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`, run `tools/run_tests.sh` (all pass, no SCRIPT ERROR or ERROR), and push. Update HANDOFF.
2. Record every act in first person and side view: `tests/bot/combo_bot.tscn`, `vfx_bot.tscn` and `ragdoll_bot.tscn`. Judge them from the frames as Game-boy would:
   - hit feel per tier, and readability;
   - no effect fills the first-person view;
   - the localized flash with the ragdoll;
   - the grab and the knees;
   - KO blink-off and respawn.

   Also check the known items in HANDOFF's 10:55 entry:
   - a hit on the player shows no flash in first person; does it still read?
   - the side-view flash hides under the burst (an open question for Game-boy: a minimum on-screen size for the flash, which would be new design; default: leave it as it is);
   - WP4 and WP2 leftovers;
   - the unseeded speed-line random generator, which makes captures differ after a finisher;
   - the stale emission comment in `tests/test_vfx.gd`;
   - the help overlay's F1 label.

   Show Game-boy the most telling sheets.
3. One adversarial review-then-fix agent over the integrated build (mechanics, plus feel from captures). It commits "M2 phase 3: review fixes (...)" and pushes.

### D. Docs and the PR
1. README:
   - Milestone 2 status, and controls (F1 tuning panel, F4 cheats).
   - New entries in "Where M2 departs from the spec": heavy-tier knockdowns get the full ragdoll, staggers above 0.6 influence, and KO bodies blink off. Add the central kick only if A1 keeps it.
2. ARCHITECTURE: the title still says "Milestone 1 contracts". Check the VFX, Audio, Ragdoll and Hit flash sections against the code, and add the KO blink-off.
3. Open the Milestone 2 PR from `m2/hit-feel` into `main`. The description ends with the Claude Code line. **Never merge it.** Game-boy plays it, tunes each tier live, saves a preset and signs it off.
