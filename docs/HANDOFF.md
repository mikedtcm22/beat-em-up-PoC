# Handoff: live status

Update this file at every phase boundary and before every usage limit (see CLAUDE.md, "Handoff protocol"). The newest state goes at the top of "Status".

## Status (newest first)

### 2026-10-25 10:53 CDT: Game-boy's verdicts; today's plan in legs, across accounts
Account E is at 91% of its 5-hour window (resets 12:30 CDT) and 78% weekly (resets Tue 2026-10-27 17:00 CDT). Game-boy played the build and gave his verdicts. **Another account starts leg 1 now.** Account E's session is renamed "Beat-em-up: account E session (paused)", and its watcher is stopped. After 12:30 it picks up the next leg nobody has claimed.
- **Decisions (Game-boy, 2026-10-25; also in the Decisions log):**
  - **Side view is a debug view**, not a player mode, so its looks don't matter now. Only first person counts; it may matter later for a 2-player mode. So:
    - hit-05 (side-view burst sizes) and gap-06 (the stomp's shins) are **dropped**;
    - the side-view flash's minimum size is answered: **leave it**;
    - hit-03 (the log in side view) is moot; grab-03, the log over the knee in first person, stays open.
  - **The player's KO: an "out of body" view.** The camera pans away from the body a bit and shows the player fully lying on the floor. It's the only time the camera leaves the player's eyes, and it needs a README departure in D.
  - **Every other proposed fix is approved as is:**
    - gap-01: the body hits the wall and crumples (full ragdoll from the pose on screen);
    - gap-03: a launch from behind pitches forward, away from the attacker;
    - gap-05: a dummy comes back in front of or beside the player, with room, and waits instead of walking into him;
    - gap-04: the hook's far arm stays bent near the guard;
    - gap-07: the ragdoll's first tick is seeded from the animation pose;
    - gap-08: the leftover numbers become tunables;
    - perf-01 and perf-02: warm-ups at load, and no shader-variant switch.
  - **Models: Opus plans and reviews; Sonnet codes and executes.** `workflow-fix.js` and `workflow-r2-close.js` have a new `fixer_model` arg. Skeptics already run on Sonnet; gates and scribes on Haiku.
  - **Passing between accounts today is fine**, to finish the fixes today.
- **Packages** (`packages-r2.json` on `m2/phase3-review` @ `ac0cfe9`, rewritten per the above, with notes that tell each fixer what changed):

  | Package | Findings |
  | --- | --- |
  | `r2-launch-into-walls` | gap-01, gap-03, gap-07, part of gap-08 |
  | `r2-vfx-first-use` | perf-01, perf-02, part of gap-08 |
  | `r2-player-ko-view` | gap-02, the out-of-body KO view |
  | `r2-dummy-comeback` | gap-05, gap-04, part of gap-08 |

- **Legs.** Each leg's owner writes "Leg N claimed by account X at HH:MM" here before starting and "Leg N done" when finished, so two accounts never work at once on the same files.
  - **Leg 1, the round 2 fixes** (the account starting now):
    1. Start-up as in the takeover prompt: the session title, a watcher, `get_usage`.
    2. `Workflow({scriptPath: "<repo>/docs/reviews/M2-phase3/workflow-fix.js", args: <the contents of docs/reviews/M2-phase3/args-r2-fix.json>})`. It runs four Sonnet fixers, two at once, each usage-gated. If a gate skips a package, rerun later with `only`.
    3. Merge the four `m2/phase3-fix-r2-*` branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run `tools/run_tests.sh` (all pass, no SCRIPT ERROR or ERROR), and push.
    4. Look at the KO-view sheets yourself (first person). It's new design, so show Game-boy one sheet.
  - **Leg 2, a final Opus review of the fixes, in first person:**
    - **Code review** of `c27afaf..m2/hit-feel`, the critic's high gap: the fixes were never code-reviewed. Check the layer rules, no feel numbers, static types and `##` docs, live `Tuning.changed` re-reads, and interactions between fixes built on separate branches (the from-hold launch against grab-02's release, the delayed flash against `_vanish`, `_turn_solid` against the respawn queries).
    - **First-person look** at the merged build: ragdoll_bot's acts, the finishers after hit-04, the KO view, the respawn.
    - **Tooling:** give `workflow-r2-close.js` a `review_brief` arg that skips the critic, and a `round` suffix for the file names (`review-r3.json`, `packages-r3.json`). Reviewers run on Opus, skeptics and fixers on Sonnet.
  - **Leg 3, D and the PR:**
    - Final first-person sheets for Game-boy.
    - README: the Milestone 2 status; the hook figure (0.346 m at 0.9 against 0.217 m at 0.6); new departures for the out-of-body KO view and the delayed finisher flash if it counts as one; side view noted as debug-only.
    - ARCHITECTURE's VFX, Audio, Ragdoll, Hit flash, hold-view and KO-view sections checked against the code.
    - Open the M2 PR from `m2/hit-feel` into `main`. **Never merge it** without Game-boy's sign-off.
  - gap-09 (bot harness: ragdoll_bot's `--act` ignores `a|b`, and parked dummies fall) is unverified and low. Fold it into leg 2 if cheap.
- **Still open with Game-boy** (each keeps its default, as now):
  - grab-03, the combat log over the knee in first person;
  - grab-05 and hit-01, the flash's first-person size and the flurry strobe;
  - hit-02, a hit on the player in first person;
  - grab-06's dead band;
  - the new look;
  - `ragdoll_partial_head_influence`;
  - more contortion on the contact push;
  - WP3's audio.

### 2026-10-25 09:12 CDT: round 2 reviewed (gap review: 8 of 8 verified survive); four r2 packages wait; weekly at 76%
The 5-hour window is at 83% (resets 12:30 CDT); **weekly is at 76%** (resets Tue 2026-10-27 17:00 CDT). Nothing is running. Every branch is pushed. `m2/hit-feel` @ `ed36d1b` has every C record (486/486 tests; no code changed since `8f5519f`).
- **The round 2 close** (`wf_e4327a11-eae`, 40 agents) took the window from 22% to 83% and weekly from 66% to 76%. The gap reviewer and its skeptics alone cost about 44 points of the window.
  - **The critic** (`critic-r2.json`): 16 gaps, 4 high:
    - hit-04's delayed flash judged only on the uppercut;
    - the merged build's first-person ragdoll acts never judged independently;
    - the player's own KO never probed;
    - the fix diffs never code-reviewed.
  - **The gap review** (`review-gap.json`, `verify-gap.json`): 9 findings. 8 are verified and survive, with no spec question; gap-09 is unverified.
    - gap-01 (medium): a body launched into a wall or the curb sinks its head up to 0.38 m into it.
    - gap-02 (medium): on the player's own KO, the first-person lens lies 7 cm above the floor behind the player's navy belly (41% of the view).
    - gap-03 (medium): an uppercut from behind snaps the body into the "launched" pose and throws its head into the attacker's lens (0.098 m).
    - gap-04 (low): the hook stagger's far arm still swings out dead straight (the stagger animation itself).
    - gap-05 (low): a dummy that comes back beside its occupied post arrives touching the player and walks in place against him.
    - gap-06 (low): on the stomp, the player's shins sink into the lying body's hips.
    - gap-07 (low): the respawn check reads the drawn ragdoll, which is wrong on a new ragdoll's first tick.
    - gap-08 (low): feel numbers left in scripts by the fixes.
- **Round 2's packages** (`packages-r2.json`, ordered by the partition):

  | Package | Findings |
  | --- | --- |
  | `r2-launch-into-walls` | gap-01, gap-03, gap-07, part of gap-08 |
  | `r2-vfx-first-use` | perf-01, perf-02, hit-05, part of gap-08 |
  | `r2-player-ko-view` | gap-02, gap-06 |
  | `r2-dummy-comeback` | gap-05, gap-04, part of gap-08 |

  All four fixers were skipped by the gate (7 points of headroom). None has a branch yet.
- **Weekly budget:** a 5-hour point costs about 0.16 weekly points here, so a fixer at 15-25 window points costs about 3-4 weekly points. The four fixers plus D (README, ARCHITECTURE, the PR) and the final sheets come to about 14-18 weekly points, against 14 left below 90% before Tuesday 17:00. **Game-boy's call:**
  - (a) D and the M2 PR first, so he can play, then the r2 fixers in priority order as the weekly allows;
  - (b) all four fixers first, then D and the PR, likely after the weekly reset.
- **Resume:**
  - the fixers: `workflow-fix.js` with `packages_file` "packages-r2.json", `concurrency` 1, `fixer_cost` 15 (or 20), and `only` for the order Game-boy picks. Use a `note` like the round 2 close's `fix_note` (merge head `ed36d1b`).
  - Then merge, regenerate the preset, run the tests.
  - D: README's Milestone 2 status, and the hook figure (0.346 m at 0.9 against 0.217 m at 0.6); ARCHITECTURE's VFX, Audio, Ragdoll, Hit flash and hold-view sections checked against the code; the PR, never merged without his sign-off.
  - gap-09 still needs its three skeptics.
- **Questions from the gap findings** (no spec change; the defaults are the fixers' proposals):
  - gap-01: wall-splat or bounce, or deflect along the wall?
  - gap-02: what the first-person view should show while the player is KO'd and getting up;
  - gap-03: whether the near-lens head for about 5 frames is acceptable;
  - gap-05: whether the dummy should come back in front of the player or beside him;
  - gap-06: whether the shin overlap is acceptable on a placeholder body.
- **Also open with Game-boy:**
  - grab-03 and hit-03, the combat log;
  - grab-05 and hit-01, the flash size and the flurry strobe;
  - hit-02, a hit on the player in first person;
  - the side-view flash;
  - grab-06's dead band;
  - bars on bodies that aren't upright;
  - the new look;
  - `ragdoll_partial_head_influence`;
  - the 12:40 entry's items.

### 2026-10-25 08:10 CDT: perf review done (2 of 2 survive); round 2 close running; weekly is now the limit
The 5-hour window is at 22% (resets 12:30 CDT); **weekly is at 66%** (resets Tue 2026-10-27 17:00 CDT). Weekly's 90% stop leaves 24 points until Tuesday, about two windows of heavy work, so round 2 runs lean: fixers one at a time, at a 15-point estimate each.
- **Perf review** (`review-perf.json`, `verify-perf.json`; both findings have 3 of 3 confirmations). Phase 3's code is cheap and doesn't leak:
  - six full ragdolls cost 1.35-1.41 ms a tick with the contact push on or off (partial: 1.12-1.22 ms), and they sleep 1.73 s after the hit;
  - 21 KO cycles of six dummies leave the node, object, resource, joint and body counts flat;
  - `hurt_point()` costs 4.9 µs, `flash_at()` 13 µs, `screen_anchor_of()` 19 µs a bar, `_respawn_spot()` 8-169 µs;
  - the hold view is negligible;
  - the flash warm-up works in both views (the first flash costs 0.15-0.88 ms with it, 3.3-8.7 ms without);
  - six rigs flashing cost about 0.24 ms of GPU;
  - known item (c), the first finisher's dropped frame, no longer reproduces (6 real-time runs).
  - **To fix:**
    - **perf-01:** the first hit of every fresh run drops a frame. The first comic sprite builds its material on the hit frame: 7-20 ms of main-thread CPU, and 24-38 ms real-time frames.
    - **perf-02:** a clean-to-bruised switch rebuilds the damage-look shader variant whenever no body shows a look: 3-5 ms, and 12-16 ms the first time.
  - Both are pre-phase-3 VFX code; the fix is a load-time warm-up or a constant material variant. Perf note on hit-02's option (c), a HUD vignette: it would need the same warm-up.
- **Running:** workflow `wf_e4327a11-eae`: `workflow-r2-close.js` with `base` `bba8633`, `concurrency` 1, `fixer_cost` 15 and a `fix_note`. It runs:
  - the critic (`critic-r2.json`);
  - a gap review only if the critic names high gaps (worktree `.worktrees/m2-review-gap` at `bba8633`, imported);
  - the partition of hit-05, perf-01, perf-02 and any gap survivors into `packages-r2.json`;
  - then the fixers through `workflow-fix.js`.
- **If cut off:**
  - with no `critic-r2.json`, rerun the same args;
  - with `packages-r2.json` there, run `workflow-fix.js` with `packages_file` "packages-r2.json", `concurrency` 1 and `fixer_cost` 15;
  - within this session, use `resumeFromRunId: "wf_e4327a11-eae"`.
- **Then:** merge the fix branches and `m2/phase3-review`, regenerate the preset, run the tests, record the final sheets for Game-boy, then D (README's Milestone 2 status and hook figures, ARCHITECTURE checked against the code, the M2 PR, never merged without his sign-off).

### 2026-10-25 07:25 CDT: account E resumed (Game-boy's call); round 2's perf review running
The 02:30 reset passed. At 07:15 the window was at 6% (it resets at 07:30 CDT); weekly was at 60% (resets Tue 2026-10-27 17:00 CDT).
- **Running:** workflow `wf_bd40aeb8-b63`: `workflow.js` with [reviews/M2-phase3/args-r2-perf.json](reviews/M2-phase3/args-r2-perf.json). It runs the perf review in `.worktrees/m2-review-perf` at `8f5519f`, then three skeptics per finding. The scribe writes `review-perf.json` and `verify-perf.json`.
- **New:** [reviews/M2-phase3/workflow-r2-close.js](reviews/M2-phase3/workflow-r2-close.js) (`b0f045b`) closes round 2 in one launch. Every agent reads the review files itself. In order:
  - the completeness critic over every review (`critic-r2.json`);
  - one gap reviewer if the critic names high gaps, with three skeptics per finding (`review-gap.json`, `verify-gap.json`);
  - the partition of hit-05 and the perf and gap survivors into `packages-r2.json` (keys `r2-`);
  - then `workflow-fix.js` as a child workflow.
  - Args: `base` (required), plus optional `no_gap_round`, `no_fix`, `fix_note` and `concurrency`.
  - First: `git worktree add --detach .worktrees/m2-review-gap <base>` and import it.
- **If cut off:**
  - If `review-perf.json` is missing on `m2/phase3-review`, rerun the perf args.
  - If it's there but `verify-perf.json` is missing, verify it the way the hit lens was verified.
  - Then run `workflow-r2-close.js`.

### 2026-10-24 23:23 CDT: hit-04 fixed and merged (486/486); 7 points left, so the lead stops here
The 5-hour window is at 83% (resets 02:30 CDT on 10-25); weekly is at 59% (resets Tue 2026-10-27 17:00 CDT). Nothing is running. Every branch is pushed. The worktrees have no uncommitted tracked changes.
- **Merged into `m2/hit-feel`:**
  - `m2/phase3-fix-r2-finisher-flash` (`9698617`). A finisher's contact flash now starts on the first rendered frame after the impact frame, and still lasts `hit_flash_frames`. With the toggle off it starts on the hit tick, as before. In first person: 2 frames of ink, then 2 frames of white on the struck chin. In side view the burst and its word still cover it (hit-05, and the open side-view flash question). Sheets (local): `.worktrees/m2-fix-r2-finisher-flash/captures/fix/s_*.png`.
  - `m2/phase3-review` again (the hit records, `packages-r2a.json`, `fix-r2-finisher-flash.json`).
  - **Head `8f5519f`. 486/486 tests pass with no SCRIPT ERROR or ERROR.** The preset regenerated unchanged (300 values).
- **Ready for the next window:** `.worktrees/m2-review-perf` is detached at `8f5519f` and imported. [reviews/M2-phase3/args-r2-perf.json](reviews/M2-phase3/args-r2-perf.json) holds the perf run's exact args.
- **Resume:**
  1. `Workflow({scriptPath: "<repo>/docs/reviews/M2-phase3/workflow.js", args: <the contents of args-r2-perf.json>})`. This runs the perf review (about 18%) and its skeptics.
  2. The round 2 critic. Run `workflow.js` with `lenses: []` (none to run), `suffix` "-r2" and a `common_note` that lists all the lenses run so far. Its critic prompt then gets an empty coverage list, so tell it in the note to read `review-*.json` and `verify-*.json`. Or do this step as lead work.
  3. The partition of hit-05 and the perf survivors into `packages-r2.json` (keys prefixed `r2-`). Use `workflow-verify-partition.js`'s pattern, or a lead-written file as with `packages-r2a.json`.
  4. `workflow-fix.js` with `packages_file` "packages-r2.json".
  5. Merge, then the final sheets for Game-boy, then D.
- **Waiting on Game-boy** (each has a default; none blocks the work):
  - the combat log: grab-03 and hit-03;
  - the flash's first-person size and the flurry strobe: grab-05 and hit-01;
  - a hit on the player in first person: hit-02;
  - the side-view flash: a minimum size alone won't show it;
  - the hold's look dead band (grab-06);
  - bars over the middle of a body that isn't upright;
  - the new look: gray trousers and dark hair;
  - the FYI on `ragdoll_partial_head_influence`;
  - the 12:40 entry's items.

### 2026-10-24 23:09 CDT: round 2 hit review done (5 of 5 survive, 3 are spec questions); hit-04's fixer running
The 5-hour window is at 74% (resets 02:30 CDT on 10-25); weekly is at 57%. The hit review and its 15 skeptics took the window from 46% to 66% in about 35 minutes.
- **Hit-feel review** (`review-hit.json`, `verify-hit.json` on `m2/phase3-review`, `d38b199`). It used five recordings at `f1e2d0f`: every vfx_bot act, 36 combo_bot acts, and every side-view ragdoll_bot act with and without the effects. Each of the five findings has 3 of 3 confirmations.
  - **To fix:**
    - **hit-04** (medium): no finisher ever shows its white flash. The flash's 2 frames are exactly the impact frame's 2 frames.
    - **hit-05** (low): in side view, the view-share floor grows the heavy word, the guard-break burst and the finisher burst to 2-2.5 times their size. They cover the struck body through the start of its reaction.
  - **Spec questions for Game-boy** (defaults: as now):
    - **hit-01**, which joins grab-05: the flurry strobes a white patch over 14-18% of the first-person view at 8.6 Hz, 7 times in a row, and the photosensitivity toggle doesn't cover it. Options:
      - (a) the impact-frame toggle becomes a general "reduce flashing" switch that also softens the contact flash;
      - (b) cap the flash's on-screen share in first person;
      - (c) soften repeat flashes on the same victim within N frames.
    - **hit-02**: a hit on the player in first person shows no flash. The only on-screen effect is a small white burst at screen centre, like the player's own jab, plus about 3 px of shake and the HP bar. Options:
      - (a) flash the player's first-person arms at a reduced strength;
      - (b) a distinct "taken" burst;
      - (c) a short HUD edge vignette from the hit's side.
    - **hit-03**, which joins grab-03: the always-on combat log hides where every side-view knockdown lands. Round 1's proposal, the log moved to the upper right under the rear-warning corner (with a toggle key), clears both views.
  - **The side-view flash** (the open question): about 30 px across, always under the light burst (64 px at the 4% floor) or the word. A minimum size alone wouldn't show it; it would have to be larger than the burst or start after it pops. With the effects off, it reads on the contact for every ragdoll case.
  - **Verdicts on the 10:55 known items:**
    - (a) a hit on the player reads weakly (hit-02);
    - (b) the side-view flash is under the burst: confirmed;
    - (c) the first finisher's dropped frame doesn't show in Movie Maker captures (a perf-lens job);
    - (d) the light burst is 10.3% of the view width;
    - (e) the bruised look is still subtle in side view;
    - (f) the log covers the side view: confirmed (hit-03);
    - (g) the speed lines repeat exactly in vfx_bot, and vary in combo_bot and in play.
  - **Also noticed** (minor):
    - in side-view piles, a lying body's bar crosses the standing body in front of it (after ragdoll-03);
    - when a jab breaks the hold, the released victim's dark hair rises through the first-person view at about 0.4 m, about 25% of the width for 6 frames (within grab-02's tested bounds);
    - the blood splash slides down a launched body;
    - hits on the player put sparks at screen centre over the attacker's face.
- **Running:** workflow `wf_9d7bfb9c-048`: `workflow-fix.js` with `packages_file: "packages-r2a.json"` (one package, `r2-finisher-flash`: hit-04, written by the lead) and `fixer_cost` 12. The fixer works in `.worktrees/m2-fix-r2-finisher-flash` on branch `m2/phase3-fix-r2-finisher-flash`. Only it fit the 16 points of headroom.
- **Next, in the next window:**
  1. The perf lens: `workflow.js` with `lenses: ["perf"]`, `base` at the merge head, `skip_critic`, `skip_fix`, `suffix` "-r2", and a `common_note` like the hit run's (see the run args in this session, or rewrite them from the 22:33 entry).
  2. The critic (round 2).
  3. The partition of hit-05 plus the perf survivors into `packages-r2.json`, with keys prefixed `r2-`.
  4. `workflow-fix.js` with `packages_file` "packages-r2.json".
  5. Merge, then the final sheets for Game-boy, then D.
- **If cut off:** rerun `workflow-fix.js` with the same args. The loader reuses a `wip:`-only branch.

### 2026-10-24 22:33 CDT: package C round 1 done and merged (484/484); round 2's hit review running
The 5-hour window is at about 47% (resets 02:30 CDT on 10-25); weekly is at 53% (resets Tue 2026-10-27 17:00 CDT). hold-view's finish and ko-respawn-bars ran one after another, at about 22% of the window together.
- **Merged into `m2/hit-feel`** (pushed; head `b22e08e`): `m2/phase3-fix-hold-view` (`acea488`), `m2/phase3-fix-ko-respawn-bars` (`a4c9bee`) and `m2/phase3-review` (`f1e2d0f`, all of C's JSON records). All three merged cleanly, and the preset regenerated unchanged (300 values). **484/484 tests pass with no SCRIPT ERROR or ERROR.** All 17 round 1 findings are fixed.
  - **hold-view** (471/471 in its worktree):
    - code-03: the lens moves on an eased path, and the walking-bob clamp scales with the hold's weight;
    - grab-06: a new tunable `grab_view_target_pitch_deg` 22, so the hold pitch reaches a target total;
    - grab-07: the throw's right arm is out wide, so there's no elbow ball. The ramps still hold through hitstop, so B's design is unchanged;
    - grab-02: a hit breaks the hold into a stagger;
    - code-06: its grab-view half.
    - Sheets (local): `.worktrees/m2-fix-hold-view/captures/fix/a_*.png`.
  - **ko-respawn-bars** (480/480):
    - code-02: the respawn spot checks lying bodies, walls and floor;
    - code-04: a dummy stays a ghost through its blink-in, and magnetism skips it;
    - code-05: `PRESET_FORMAT` 2 migrates an old preset's `dummy_revive_s`;
    - ragdoll-03: bars sit just above the drawn body when it isn't upright;
    - ragdoll-04: KO bars fade before the blink.
    - The pile test now sets up its pile with scripted knockdowns and passes in any order.
    - Sheets (local): `.worktrees/m2-fix-ko-respawn-bars/captures/fix/`.
- **New notes for Game-boy** (each has a default):
  - grab-06's formula leaves a look dead band while holding. Looking between 6° and 22° down, the view stays at 22°, so about 16° of mouse travel gets no response; the bots never show it. A softer mapping is possible. Default: as built.
  - SPEC §5's bar "over its head": a body that isn't upright (lying, flying, held) now has its bar over the middle of its drawn body. Treated as within the spec. Default: as built.
- **Round 2** (the 14:15 entry's step 3) uses `workflow.js`'s new options (`b22e08e`): `base`, `common_note`, `lenses`, `skip_critic`, `suffix`. The reviewer worktrees `m2-review-hit` and `m2-review-perf` are moved to `f1e2d0f` and imported.
  - **Running:** workflow `wf_29d8de46-ea9`, with `lenses: ["hit"]`, `base` `f1e2d0f`, `skip_critic`, `skip_fix`, `suffix` "-r2" and a `common_note`. The note lists round 1's changes and the critic's gap (the flash on a ragdoll in side view). It runs the hit-feel review, then three skeptics per finding, gated. The scribe writes `review-hit.json` and `verify-hit.json` to `m2/phase3-review`.
  - The window fits only one reviewer: the rule's headroom was 37, and a reviewer that's cut off saves nothing.
  - **Next:** the perf lens the same way (`lenses: ["perf"]`). Then the critic, a gap lens for its medium gaps if needed, and the partition into `packages-r2.json` (keys prefixed `r2-`). Then the fixers: `workflow-fix.js` needs a `packages_file` arg first. Then merge, the final sheets, and D.
- **If cut off:** check `m2/phase3-review` for `review-hit.json` and `verify-hit.json`. If the review is missing, rerun the same args. If it's there, pass it in `reviews.hit`, and the verdicts in `verdicts`.

### 2026-10-24 21:35 CDT: account E after its 21:30 reset; hold-view and ko-respawn-bars running, one after another
The 5-hour window is at 0% (resets 02:30 CDT on 10-25); weekly is at 45%. The usage rule's headroom (90 minus the higher window, here weekly) is 45, which fits one fixer. So the run is sequential: `workflow-fix.js` gained `concurrency` (`80c39ea`), and the second fixer's gate runs when the first ends.
- **Running:** workflow `wf_17408a9e-962`: `workflow-fix.js` with `only: ["hold-view", "ko-respawn-bars"]`, `concurrency` 1 and a lead's note:
  - hold-view continues from `06733a3`;
  - ko-respawn-bars also takes over `test_ragdoll.gd`'s pile test and sets up its pile without the chaotic flight.
  - The watcher checks every 10 minutes.
- **If cut off:** rerun the same way (the loader skips a package whose branch has its final commit). Within this session, use `resumeFromRunId: "wf_17408a9e-962"`.
- **Then:** merge both into `m2/hit-feel`, regenerate the preset, run the tests (all 467+ pass, no SCRIPT ERROR), push; then round 2 (the 14:15 entry's step 3).

### 2026-10-24 18:10 CDT: handoff, account E's 5-hour window at 91%
The watcher called the handoff at 91% of the 5-hour window (resets 21:30 CDT); weekly is at about 45% (resets Tue 2026-10-27 17:00 CDT). The hold-view fixer alone took the window from about 62% to 91% in about 40 minutes, more than the 25% estimate. The workflow `wf_5656a5ef-18c` is stopped, and nothing else is running. Every branch is pushed. The worktrees have no uncommitted tracked changes.
- **`hold-view`: cut off with two `wip:` commits**, pushed on `m2/phase3-fix-hold-view` (worktree `.worktrees/m2-fix-hold-view`, off `m2/hit-feel` at `0905690`, which has the two merged packages).
  - `d50348c`, in `player.gd`, `first_person_camera.gd` and `tuning_data.gd`:
    - the hold-view lens moves on an eased path (code-03);
    - the hold pitch has a target total (grab-06);
    - a hit breaks the hold into a stagger (grab-02).
  - `06733a3`, in `placeholder_poses.gd` and `test_grab_view.gd`:
    - the throw strike's right arm is out wide (grab-07);
    - the ease-in is front-loaded;
    - the tests follow the lens (code-06's grab-view half).
  - **Unknown:** whether the full suite passes on it, whether the after-sheets were recorded and judged, and whether `ARCHITECTURE`'s "First-person hold view" and the preset are updated. There's no `fix-hold-view.json`.
- **Decision (Game-boy, 19:21):** stay on this account. The working session waits for the 21:30 CDT reset, with the watcher still running, and then resumes here with the steps below.
- **Resume (next account or after 21:30):**
  1. Run `workflow-fix.js` with `only: ["hold-view", "ko-respawn-bars"]` and a `note`. The loader sees hold-view as `wip`, and its fixer reuses the worktree and goes on from `06733a3`. The note should say:
     - the merge state (as in the 17:25 entry's run);
     - the known pile-test failure;
     - for ko-respawn-bars: also make `test_ragdoll.gd`'s pile test set up its pile without a chaotic flight. launch-from-hold, which owned that file, is done.
  2. Merge both branches into `m2/hit-feel`, regenerate the preset, run the tests (all pass, no SCRIPT ERROR), push.
  3. Round 2, review: the hit-feel and performance lenses on the merged build, plus the critic's medium gaps (the 14:15 entry's step 3). Then round 2's fixes, the final sheets for Game-boy, and D. D also updates README's hook figures (17:25 entry).
- **Waiting on Game-boy:**
  - grab-03 and grab-05 (13:55 entry);
  - the new look (17:25 entry, `side_looks.png`);
  - the FYI on `ragdoll_partial_head_influence`;
  - the 12:40 entry's items.
  - Each has a default.

### 2026-10-24 17:25 CDT: two fix packages merged; hold-view running; ko-respawn-bars left
The 5-hour window is at about 62% (resets about 21:30 CDT); weekly is at 40%. The first fix run (`wf_3e329695-5fc`) took the window from 10% to 58% in 35 minutes: two fixers at about 24% each.
- **Merged into `m2/hit-feel`** (`4683f81`, `4cc2f56`, pushed). Both merged cleanly, and the preset regenerated unchanged (299 values).
  - **`launch-from-hold`** (`999d565`, 461/461 in its worktree). All four findings are fixed:
    - grab-01 and ragdoll-01: a launch out of the hold starts from the drawn pose, with `carry_fade`. The throw now arcs about 0.6 m up and lands about 3 m away. A knee KO stays 0.30 m from the lens and fills at most 39% of the view; before, it was 0.12 m and 47%.
    - ragdoll-02: new tunables `ragdoll_partial_head_influence` 0.45, `ragdoll_partial_arm_influence` 0.45 and `ragdoll_stagger_back_share` 0.5. The hook stagger now rocks back from the side.
    - code-06: its `test_ragdoll.gd` half.
    - A new ragdoll_bot act, "knee KOs the held dummy".
    - Sheets (local): `.worktrees/m2-fix-launch-from-hold/captures/fix/after/`.
  - **`flash-and-looks`** (`50af435`, 463/463). All four findings are fixed:
    - code-01: `flash_at()` clamps the contact onto the nearest hurtbox and rides the drawn bone (new `hurt_point()`).
    - grab-04: the player wears gray trousers (new `HumanoidRig.pants_color`).
    - grab-08: every rig has a dark "Hair" part on the back of its head.
    - ragdoll-05: the stomp's strike foot lands on top of the lying torso.
    - Sheets (local): `.worktrees/m2-fix-flash-and-looks/captures/fix/`.
- **Tests at the merge: 466/467, no SCRIPT ERROR.** `test_ragdoll.gd`'s `test_two_bodies_that_fell_on_each_other_get_up_beside_each_other` fails in the full suite ("the kicked body lies on the other"; the one underneath moves 0.211 m against a 0.2 m limit).
  - The cause is an **old order dependence**. At `c27afaf`, before any fix, it already fails whenever `test_grab_view.gd` or `test_humanoid_rig.gd` runs before `test_ragdoll.gd`. The kick's flight lands differently after other tests have created and freed bodies, probably through Jolt's body order. The new suite order exposed it.
  - **To do:** make the pile test set up its pile without depending on a chaotic flight. Do it in the `ko-respawn-bars` run (pass it in `note`) or as lead work.
  - To reproduce in about 30 s: a GUT config without `dirs`, run with `-gtest=res://tests/test_grab_view.gd,res://tests/test_ragdoll.gd`.
- **For Game-boy to see:** the player's new gray trousers and the dark hair on every head change the side view: `.worktrees/m2-fix-flash-and-looks/captures/fix/side_looks.png`. On dummies with a dark accent colour, the cap and hair read as one dark helmet.
- **FYI for Game-boy** (no spec change): `ragdoll_partial_head_influence` 0.45 halves how much of the simulated head turn shows in a stagger, including the contact twist on a struck head. Raising it toward 0.9 brings back the old head look without touching the spin caps. This sits next to the open "more contortion" question.
- **README note (not edited yet):** the approved stagger departure quotes the hook at about 0.32 m against 0.22 m. It now measures 0.346 m at 0.9 against 0.217 m at 0.6. Update the number in D.
- **Running:** workflow `wf_5656a5ef-18c`, `workflow-fix.js` with `only: ["hold-view"]`, `max_fixers` 1 and a lead's note (the merge state, and the known failure). `workflow-fix.js` gained the `note` arg.
- **Left:** `ko-respawn-bars` (code-02, code-04, code-05, ragdoll-03, ragdoll-04). Both gates found 7 points of headroom while flash-and-looks still ran, so it waits for the next window. Then come the merge, the pile test, and round 2 (the 14:15 entry's step 3).
- **If cut off:** rerun `workflow-fix.js` (no args, or `only` with the keys left). Within this session, use `resumeFromRunId: "wf_5656a5ef-18c"`.

### 2026-10-24 16:45 CDT: account E after its reset; partition done, fix round running
The 5-hour window reset at 16:30 (next reset about 21:30 CDT); weekly is at 30%. This session resumed as Game-boy decided at 14:29. The watcher `usage-watcher-h` still runs, asked to check every 10 minutes during the heavy run.
- **Partition done:** `packages.json` on `m2/phase3-review` (`e7c3255`) holds four packages with all 17 survivors. Where two packages share a hub file, each package's notes say which functions it may touch.

  | Package | Findings | Main files |
  | --- | --- | --- |
  | `launch-from-hold` | grab-01, ragdoll-01, ragdoll-02, code-06 (ragdoll half) | owns `combat_actor.gd`, `ragdoll.gd`, `gen_moves.gd` (throw, hook) |
  | `flash-and-looks` | code-01, grab-04, grab-08, ragdoll-05 | `humanoid_rig.gd` (except `ragdoll_start()`, `carry_fade()`), `weapon.gd`, `placeholder_body.gd`, `placeholder_poses.gd` (except `_throw()`) |
  | `hold-view` | code-03, grab-07, grab-06, grab-02, code-06 (grab-view half) | owns `player.gd` (except `_configure_rig()`, `_find_magnet_target()`), `first_person_camera.gd`, `_throw()` |
  | `ko-respawn-bars` | code-02, code-04, code-05, ragdoll-03, ragdoll-04 | `training_dummy.gd`, `enemy_health_bars.gd`, `tuning.gd` (preset migration) |

- **Running:** workflow `m2-phase3-fix` (run `wf_3e329695-5fc`, [reviews/M2-phase3/workflow-fix.js](reviews/M2-phase3/workflow-fix.js), no args). Fixers run in that order, two at once, each usage-gated (about 25%):
  - each works in `.worktrees/m2-fix-<key>` on branch `m2/phase3-fix-<key>` off `m2/hit-feel`;
  - each commits `wip:` and pushes every 15-20 minutes, and ends with "M2 phase 3: review fixes (<key>: ...)";
  - a scribe commits `fix-<key>.json` to `m2/phase3-review`.
  - A package the gate skips stays for a later run.
- **Things to watch at the merge:**
  - hold-view's grab-07 fix may ease the hold view out during the throw's hitstop, a change to B's design ("still through hitstop"), which its fixer flags;
  - launch-from-hold re-measures the hook's side-view stagger quoted in README's departure, and reports any change rather than editing README;
  - `tuning_data.gd`, `tuning/default.json` and `docs/ARCHITECTURE.md` get additions from several packages (regenerate the preset after merging).
- **If cut off:** rerun `workflow-fix.js` (no args). Its loader skips a package whose branch has the final commit and reuses a `wip:`-only branch. Within this session, use `resumeFromRunId: "wf_3e329695-5fc"`.
- **Then:** merge the four fix branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset, run the tests, push. Then round 2 (the 14:15 entry's step 3).

### 2026-10-24 14:25 CDT: handoff, account E's 5-hour window at 89%
The watcher called the handoff at 89% of the 5-hour window (resets 16:30 CDT); weekly is at 28% (resets Tue 2026-10-27 17:00 CDT). The first task took the window from 76% to 89% in about 25 minutes: nine Sonnet skeptics cost about 6 points, and the lead's reading about 4. The workflow `wf_338da5ae-007` is stopped mid-partition, and nothing else is running. Every branch is pushed. The reviewer worktrees have no tracked changes.
- **Done:** grab-06, -07 and -08 are verified. All three survive with 3 of 3 confirmations, with no spec question. They're merged into `verify-grab.json` on `m2/phase3-review` (`5b77fcd`), and its `pending` is now empty.
  - grab-06: the hold pitch adds to the look pitch with no limit. Looking down 25°, the player's own body fills 52-62% of the view at the knee's peak.
  - grab-07: the hold view's ease is advanced per sim tick, so it stands still through the throw's hitstop. The lens stays back and up while the right upper arm swings out, which leaves the elbow as a blue ball mid-view.
  - grab-08: the placeholder head has no hair or back-of-head part.
- **Not done:** the partition. It was stopped before it returned, so there's no `packages.json` yet.
- **Survivors to fix:** 17 findings with no spec question, from code-01 to -06, ragdoll-01 to -05, and grab-01, -02, -04, -06, -07 and -08. The spec questions grab-03 and grab-05 are Game-boy's.
- **Decision (Game-boy, 14:29):** stay on this account. The working session waits for the 16:30 CDT reset, with the watcher `usage-watcher-h` still running, and then resumes here with the steps below.
- **Resume (next account or after the 16:30 reset):**
  1. Run [reviews/M2-phase3/workflow-verify-partition.js](reviews/M2-phase3/workflow-verify-partition.js) inline (`scriptPath`) with `args: {"skip_verify": true}`. Only the usage gate and the partition run (about 4%). A scribe commits `packages.json`.
  2. Then follow steps 1-4 of "C's order from here" in the 14:15 entry below. Start with `workflow-fix.js`, two fixers at once.
- **Waiting on Game-boy:** grab-03 and grab-05 (13:55 entry), plus the 12:40 entry's items. Each has a default.

### 2026-10-24 14:15 CDT: account E back at 74%; first task: verify grab-06 to -08, partition the survivors
The account Game-boy switched to at 14:10 has account E's reset times. It was at 74% of its 5-hour window (resets 16:30 CDT) and 27% weekly (resets Tue 2026-10-27 17:00 CDT). That left 16 points below 90%, less than one reviewer (18). Per the usage rules, this session split off a first task that fits. Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-h` (Haiku, low effort, self-paced).
- **Running:** workflow `m2-phase3-c-verify-partition` (run `wf_338da5ae-007`), a copy in [reviews/M2-phase3/workflow-verify-partition.js](reviews/M2-phase3/workflow-verify-partition.js). It does two things, each usage-gated:
  - three Sonnet skeptics each for grab-06, -07 and -08, merged into `verify-grab.json`;
  - a partition agent that groups every survivor without a spec question into at most four fix packages with disjoint files, saved as `packages.json`.
  - A Haiku scribe commits both to `m2/phase3-review`.
- **New for the next window:** [reviews/M2-phase3/workflow-fix.js](reviews/M2-phase3/workflow-fix.js), the fix round. It needs no args. A Haiku loader reads `packages.json` and skips a package whose branch has its final "review fixes" commit; a `wip:`-only branch is reused. Each fixer reads its findings and verdicts from the review files by id, so the lead no longer pastes about 170 KB of JSON as args. Optional args: `only` (package keys) and `max_fixers`. `workflow.js` now has `COST.reviewer` 18 and `perFinding` 2.
- **C's order from here** (the lead's call):
  1. **Round 1, fix:** run `workflow-fix.js` inline (`scriptPath`). Two fixers at once at about 25% each, so a full window covers about three packages.
  2. **Merge** the fix branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run the tests, push.
  3. **Round 2, review on the merged build,** so it doesn't re-find what round 1 fixed: the hit-feel and performance lenses, plus the critic's medium gaps (the flash on a ragdoll in side view, the player's KO while holding, bodies against a wall or the curb). `workflow.js` can run them. First make fresh detached reviewer worktrees at the merge commit, change `c27afaf` in its `COMMON` and `reviewRules`, and pass `reviews` code, ragdoll and grab as `{"lens": "<lens>", "skipped": true}`.
  4. Round 2's fixes, then the final sheets for Game-boy, then D.
- **If cut off:** on `m2/phase3-review`, an empty `pending` in `verify-grab.json` means grab-06 to -08 are verified, and `packages.json` means the partition is done. Rerun whatever is missing with `workflow-verify-partition.js`. Within this session, use `resumeFromRunId: "wf_338da5ae-007"`.
- **Waiting on Game-boy:** grab-03 and grab-05 (13:55 entry), plus the 12:40 entry's items. Each has a default.

### 2026-10-24 13:55 CDT: handoff, account F's 5-hour window at 90%
The watcher called the handoff at 90% of the 5-hour window (resets 17:39 CDT); weekly is at 28% (resets Wed 2026-10-28 10:59 CDT). **Game-boy switched to a fresh account at 14:10.** This session is renamed "Beat-em-up: account F session (handed off)", which frees the working-session title, and its watcher `usage-watcher-g` is told to end its loop. The new account starts its own watcher. The workflow `wf_f6697464-ea0` is stopped, and nothing else is running. Every branch is pushed. The reviewer worktrees have no tracked changes (only untracked `captures/`).
- **Package C state.** Everything below is committed as JSON on `m2/phase3-review` (`a39ba62`), in `docs/reviews/M2-phase3/`.

  | Lens | Findings | Verified (3 skeptics each) |
  | --- | --- | --- |
  | code | 6 | 6 of 6 survive |
  | ragdoll feel | 5 | 5 of 5 survive |
  | grab feel | 8 | 5 of 5 survive; grab-06, -07 and -08 (low) are unverified |
  | hit feel | not run (usage) | |
  | performance | not run (usage) | |

  `critic.json` holds the completeness critic: 13 gaps. The high ones are the two lenses not run and no verdicts on the 10:55 known items. Medium: the flash on a ragdoll in side view, the player's KO while holding, bodies against a wall or the curb. Its `gap_review_brief` merges hit feel and performance into one reviewer. Run them as the two planned lenses instead. The partition agent was stopped mid-run, so no packages exist yet, and no fixer ran.
- **The surviving findings** (no fix is needed from Game-boy):
  - code-01 (high): the contact flash misses the struck body. A thrown pipe shows none, body impacts a faint one, and a staggering body flashes on the wrong part.
  - code-02: a respawning dummy can blink in inside a body lying on its post.
  - code-03: the hold view bobs the lens 5-7 cm on every grab and release, and pops 3.5 cm on a release while walking.
  - code-04: a dummy blinking in still attracts magnetism and blocks a thrown pipe.
  - code-05: `dummy_revive_s` changed meaning under the same preset key, so older presets give a 5.5 s comeback.
  - code-06: two tests would pass with what they guard broken: the per-part spin caps and the lens rules on an LB release.
  - ragdoll-01: the throw pops the held victim upright in one frame, then it skates away on its feet and trips onto its face.
  - ragdoll-02: the hook stagger at 0.9 flops like a rag in first person but still doesn't read from the side.
  - ragdoll-03: the side-view health bar sits on the head or body when the head isn't on top.
  - ragdoll-04: a KO'd body's empty health bar hangs through its first blink-offs.
  - ragdoll-05: the stomping foot sinks into the lying body.
  - grab-01 (high): a body launched out of the hold, by a knee that KOs it or by the throw, pops into the holder and fills the view.
  - grab-02: a hit that breaks the hold lets the victim stand up through the holder's frozen view.
  - grab-04: in first person the knee is the same navy as the shaded right sleeve, a blue lump.
- **New spec questions for Game-boy:**
  - grab-03, the combat log over the knee contact (the open question). Proposal: a key that toggles the combat log, shown in the help overlay, and the log moved to the upper right below the rear-warning zone, narrower or with fewer lines; optionally faded while holding in first person. Default: as it is until Game-boy answers.
  - grab-05: the knee's localized flash whitens about 16% of the first-person view, three times per hold. Proposal: cap the flash's on-screen size in first person, for example by scaling `hit_flash_radius_m` with the contact's distance from the camera. Default: leave it.
- **On the open contact-push question:** both the code and the ragdoll reviewer found the contact push near frame-for-frame the same as the central kick. Their evidence is the hook A/B in `.worktrees/m2-review-ragdoll/captures/review_ragdoll/ab_hook_*.png` and a probe in which the head reaches 41-47 rad/s either way. The joint limits and pose springs decide the contortion, not the twist. More contortion would need wider joint limits or softer stagger springs. Default: as it is.
- **Sheets for Game-boy** (local): `review_ragdoll/throw_side60.png`, `throw_fp60.png`, `hook_fp60.png`, `bar_overlap_side.png`; `review_grab/p6_knee_ko_fp_f1340-1359.png`, `p5_hit_while_holding_fp.png`; `review_code/pipe_throw_zoom.png`, `grab_release_moment.png`. Each is under `captures/` in its reviewer's worktree.
- **Measured cost (correct the estimates):** the window went from 5% to 90% in about 58 minutes. That was three reviewers, 16 findings verified (48 Sonnet skeptics), the critic and part of the partition. A reviewer costs about **17-20%**, not 13%. Verifying a finding costs about **1.5-2%**. In `workflow.js`, set `COST.reviewer` to 18 before the next run.
- **Resume (next account):**
  1. Load `docs/reviews/M2-phase3/*.json` from `m2/phase3-review`. Run `docs/reviews/M2-phase3/workflow.js` inline (with `COST.reviewer` 18) with `args`:
     - `reviews`: {code, ragdoll, grab: the three `review-<lens>.json` objects};
     - `verdicts`: {each id in the three `verify-<lens>.json` files: its verdict object}.
  2. It then runs, all usage-gated:
     - the hit and performance reviews;
     - verification of their findings and of grab-06 to -08;
     - the critic again, and a gap round (it should cover the critic's medium gaps);
     - the partition and the fixers.
  3. The reviewer worktrees `.worktrees/m2-review-*` must stay; they're at `c27afaf`, imported.
  - A whole window covers about the two reviews, their verification, the critic and the partition. The fixers (about 25% each) likely need the window after that.
  - To fix the 14 survivors first instead (the lead's call), also pass:
    - `reviews.hit` and `reviews.perf` as `{"lens": "<lens>", "skipped": true}`;
    - `no_gap_round: true`.

    The script then goes straight to the critic, the partition and the fixers. Run hit and perf in a later run.
- **Waiting on Game-boy:** grab-03 and grab-05 above, plus the 12:40 entry's items (each has a default).

### 2026-10-24 12:52 CDT: account F took over; package C workflow running
A fresh account's working session took over at 2% of its 5-hour window (resets 17:39 CDT) and 13% weekly (resets Wed 2026-10-28 10:59 CDT). Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-g` (Haiku, low effort, self-paced), asked to check every 10 minutes during the heavy run.
- **Running:** workflow `m2-phase3-review-fix` (run `wf_f6697464-ea0`, started from this session). A copy of the script is in the repo: [docs/reviews/M2-phase3/workflow.js](reviews/M2-phase3/workflow.js).
  - **Review:** five lenses (code, ragdoll feel, grab feel, hit feel, performance), two heavy agents at once. Each works in its own detached worktree at `c27afaf`, `.worktrees/m2-review-<lens>` (imported), and records into `captures/review_<lens>/` there.
  - **Verify:** as each review ends, three Sonnet skeptics per finding (reproduce, spec, code). A finding survives with two confirmations. Survivors whose fix changes the spec, or that touch a question open with Game-boy, become spec questions.
  - **Critic:** a completeness critic, then one gap reviewer if it names high-priority gaps.
  - **Fix:** a partition agent groups the survivors into at most four packages with disjoint files. Fixers run two at once. Each makes `.worktrees/m2-fix-<key>` on branch `m2/phase3-fix-<key>` off `m2/hit-feel`, commits `wip:` and pushes, and ends with "M2 phase 3: review fixes (<key>: ...)".
  - **Record:** a Haiku scribe commits each result as JSON to `docs/reviews/M2-phase3/` on branch `m2/phase3-review` (worktree `.worktrees/m2-review-notes`) and pushes it: `review-<lens>.json`, `verify-<lens>.json`, `critic.json`, `packages.json`, `fix-<key>.json`.
  - **Usage gates:** a Haiku gate before every launch. A launch goes ahead only if its estimate fits 90% minus the usage minus what's still in flight: a reviewer 13%, 2.5% per verified finding, the critic and the partition 4% each, a fixer 25%. Skipped work is logged and left for the next account.
- **Expect** the reviews and verification to fill most of this window; the fixers probably start on the next account.
- **If cut off (another account):**
  1. Read `docs/reviews/M2-phase3/*.json` on `m2/phase3-review`.
  2. Run `docs/reviews/M2-phase3/workflow.js` inline as a Workflow with `args`:
     - `reviews`: {lens: that lens's `review-<lens>.json` object};
     - `verdicts`: {finding id: its verdict object from `verify-<lens>.json`};
     - `packages`: `packages.json`'s `packages`;
     - `done_packages`: the keys whose fix branch has its final "review fixes" commit.
  3. Finished work is skipped, and only the rest runs. A fixer whose branch has only `wip:` commits reuses the worktree and goes on from there. The reviewer worktrees must stay, since skeptics read them.
  - Within this session, resume with `resumeFromRunId: "wf_f6697464-ea0"`.
- **Waiting on Game-boy:** unchanged from the 12:40 entry. Each item has a default, and none blocks C.

### 2026-10-24 12:40 CDT: new usage rule, work up to the 90% handoff
Game-boy finds stopping launches at 65-70% too conservative. From now on, work runs up to the watcher's 90% handoff, and each launch is sized to the headroom left below 90%. When a new phase or milestone doesn't fit, split off a first task that does, run it, and hand off at 90%. The rules are under "Usage rules for the working session"; the takeover prompt, CLAUDE.md and the phase 3 plan match. Nothing else changed since the 12:40 handoff entry below.

### 2026-10-24 12:40 CDT: handoff to a fresh account for package C (Game-boy's call)
Account E is at 70% of its 5-hour window (resets 16:30 CDT) and 26% weekly (resets Tue 2026-10-27 17:00 CDT), past the 65% launch line. Game-boy chose to switch accounts now rather than wait for the reset. This session is renamed "Beat-em-up: account E session (handed off)", which frees the working-session title. Its watcher `usage-watcher-f` is told to end its loop.
- **State:** `m2/hit-feel` @ the commit after `c9ec777` (this entry) has phases 1-2, the flash, and phase 3's A and B merged. **457/457 tests pass with no SCRIPT ERROR or ERROR.** **No agents or workflows are running.** Every branch is pushed. The worktrees are clean apart from untracked `captures/`. `m2/ragdoll-tune` and `m2/grab-view` are merged; their worktrees hold the A/B, KO and grab sheets (local only).
- **Next: package C as a Workflow.** Follow [M2-phase3-plan.md](milestones/M2-phase3-plan.md), "C", step 2: reviewer worktrees, five review lenses, three skeptics per finding, fixers in worktrees with disjoint files, a completeness critic, and usage gates. Then D: check ARCHITECTURE's VFX, Audio, Ragdoll, Hit flash and hold-view sections against the code, add README's Milestone 2 status and the test count, then the M2 PR (never merged without Game-boy's sign-off). D's README controls, the three departures and ARCHITECTURE's title are done.
- **Usage this account (E):** A and B, run together, took the window from 1% to 68% in about 50 minutes: A about 417k tokens, B about 464k. Plan on about 30-35% of a 5-hour window per builder of that size.
- **Waiting on Game-boy** (each has a default; none blocks C):
  - A: more contortion on the contact push? It would mean wider joint limits or softer stagger pose springs. Default: as it is.
  - B: is the lens pull-back while holding acceptable, and is the bend deep enough? Default: as it is.
  - The combat log sits over the knee contact. Default: C's review proposes a fix.
  - The flash's minimum on-screen size in side view. Default: leave it.
  - A listen to WP3's audio.

### 2026-10-24 12:25 CDT: A and B merged (457/457); C waits for usage
- **A done:** `m2/ragdoll-tune` @ `7010250` (448/448 in its worktree, re-run by the lead). Tunables:
  - `ragdoll_partial_influence` 0.6 -> 0.9 (`ragdoll_partial_impulse` stays 7.0: the hook and guard-break kicks already reach `ragdoll_max_kick` 14);
  - "Kick at the contact point": `ragdoll_kick_at_contact` on, `ragdoll_contact_lever_m` 0.15, `ragdoll_contact_twist` 1.0, `ragdoll_contact_chain` 2, spin caps head 14, trunk 8, limb 14 rad/s;
  - "KO and blink-off": `ko_linger_s` 1.5, `ko_blink_s` 1.0, `ko_blink_start_hz` 4, `ko_blink_end_hz` 12, `ko_blink_in_s` 0.5, `ko_blink_in_hz` 8; `dummy_revive_s` 2.5 -> 1.0, counted from the blink-off (4.0 s from KO to back).
  - New: `CombatEvents.vanished`, `HumanoidRig.set_shown()`, `tests/test_ko_blink.gd`; bot switches `--central-kick` and `--set=<tunable>=<value>`.
  - Departures: a dummy whose post is occupied comes back at the nearest free spot beside it; it can't be hit or grabbed during its blink-in.
- **The lead's judgement of A's sheets** (local, `.worktrees/m2-ragdoll2/captures/ab_contact/`, `ab_stagger/`, `ko/`): the contact push is stable (no tearing, spin or jitter; 60 hits in a row stay in the caps) but looks almost the same as the central kick, since the joint limits and pose springs already hold the head and neck at their limits. More contortion would need wider joint limits or softer stagger pose springs. Staggers at 0.9 bend a little further from the side; the hook pushes along the side camera's depth axis. The KO cycle reads well.
- **A's known items:** in side view the enemy health bar sits on the head when a stagger bends it toward the camera; the central kick alone already spins the neck and head at the 40 rad/s cap in staggers; blood splats stay on the floor after a body vanishes.
- **Merged:** `2543cc6` (A) and `f98bb21` (B) into `m2/hit-feel`, no conflicts. The preset regenerated unchanged (296 values). **457/457 tests pass with no SCRIPT ERROR or ERROR.** Pushed. README has the three approved departures (heavy knockdowns full ragdoll, staggers at 0.9, KO blink-off); the central kick isn't kept, so it has no entry.
- **Usage:** 68% of the 5-hour window at 12:22 (resets 16:30 CDT), 26% weekly. Past the 65% launch line, so package C's workflow waits for the reset or a fresh account (Game-boy's call). The watcher checks every 10 minutes.
- **Waiting on Game-boy:** A's sheets (more contortion, or as it is?), B's questions (the lens pull-back, the bend's depth), the combat log over the knee contact, the flash's minimum size in side view, WP3's audio, and when to run C.

### 2026-10-24 11:34 CDT: account E took over; phase 3 packages A and B running
A fresh account's working session took over at 1% of its 5-hour window (resets 16:29 CDT) and 15% weekly (resets Tue 2026-10-27 16:59 CDT). Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-f` (Haiku, low effort, self-paced).
- **Running:** two background agents (Agent tool, started from this session), per [M2-phase3-plan.md](milestones/M2-phase3-plan.md):
  - **A, ragdoll:** `.worktrees/m2-ragdoll2`, branch `m2/ragdoll-tune` (off `f43ab9a`, imported, pushed). Contact push behind `ragdoll_kick_at_contact` (default on) with spin caps, A/B sheets central vs contact in `captures/ab_contact/`; KO blink-off (`ko_linger_s`, `ko_blink_s`, blink rates), dummies respawn at home after `dummy_revive_s` with a blink-in, sheets in `captures/ko/`; stronger staggers with A/B sheets in `captures/ab_stagger/`. Ends with a commit "M2 phase 3: ragdoll contact push, KO blink-off, stronger staggers (...)".
  - **B, grab:** `.worktrees/m2-grab`, branch `m2/grab-view` (off `f43ab9a`, imported, pushed). `grab_view_pitch_deg` eased in and out, the waist bend in `hold()` and the knee, before/after sheets in `captures/grab/`. Ends with a commit "M2 phase 3: grab view and waist bend (...)".
  - Both commit `wip:` every 15-20 minutes and push. Both regenerate `tuning/default.json` on their branch; expect a conflict there and in `tuning_data.gd` (different groups) at the merge, and regenerate the preset after it.
- **If cut off:** check each branch for its final commit. Without one, rerun that package from its newest `wip:` commit with the brief in the plan (package A or B).
- **Then:** show Game-boy A's contact-vs-central and stagger sheets, merge A and B into `m2/hit-feel`, and go on with package C.
- **Package C runs as a Workflow (Game-boy turned ultracode on at 11:38).** Plan:
  - per-reviewer worktrees detached at the merge commit (the Workflow tool's `isolation: 'worktree'` fails here);
  - review lenses: the phase 3 code (mechanics), ragdoll feel, grab feel, hit feel across all tiers and both views (including HANDOFF 10:55's known items), and performance;
  - three skeptics per finding, then fixers in their own worktrees with disjoint files;
  - a completeness critic at the end;
  - a Haiku usage gate before each launch: nothing new at 65%, and at most two heavy agents at once.
- **B done (12:25):** `m2/grab-view` @ `329b67f`, 445/445 tests in its worktree (the lead re-ran them; no SCRIPT ERROR or ERROR). Tunables in "Grab and weapons" > "Hold view": `grab_view_pitch_deg` 16, `grab_view_back_m` 0.24, `grab_view_rise_m` 0.10, `grab_view_in_s` 0.2, `grab_view_out_s` 0.45; knee `camera_pitch_deg` -12, `camera_drop_m` 0.05. Departures from the plan: the lens moves back and up while holding (the bend put the eyes over the victim: a wall of shirt), the knee rises a little to the right (the victim's head hid it), the throw ends in the stance (a forearm came within 0.28 m of the lens), no walking-bob clamp while holding, the victim stands 6 cm closer. Sheets (local): `.worktrees/m2-grab/captures/grab/compare_*.png`. Open: the combat log (SPEC's debug overlay, always on) sits over the knee contact; the player's blue sleeves match the knee's blue; the head reads as a skin dome from behind.
- **Done meanwhile on `m2/hit-feel`:** `ac58377` (speed lines seeded, F1 help label, flash test comment) and `dbf0dcc` (README F1/F4 controls, ARCHITECTURE title). 438/438 tests.

### 2026-10-24 11:05 CDT: Game-boy answered the ragdoll questions; phase 3 plan written
Account D, already handed off, wrote [docs/milestones/M2-phase3-plan.md](milestones/M2-phase3-plan.md) from Game-boy's answers (see the Decisions log) and his new grab fix. The takeover prompt's "Next steps" now point to that plan. Nothing else changed: `m2/hit-feel` code is still at `33fcc98`, 437/437 tests pass, and nothing is running. Only the flash's side-view question and WP3's audio are still open with Game-boy.

### 2026-10-24 10:55 CDT: handoff to a fresh account for phase 3 (account D's weekly at 66%)
Game-boy chose to hand phase 3 to a fresh account once the flash merged. Account D is at 59% of its 5-hour window (resets 13:40 CDT) and **66% weekly** (resets Tue 2026-10-27 12:00 CDT), past the 65% launch line. This session is renamed "Beat-em-up: account D session (handed off)", which frees the working-session title. Its watcher `usage-watcher-e` is told to end its loop. **No agents or workflows are running.** Every branch is pushed, and the worktrees are clean apart from untracked `captures/`.
- **State:** `m2/hit-feel` @ `33fcc98` has phases 1 and 2 plus the localized flash. **437/437 tests pass with no SCRIPT ERROR or ERROR.** The preset has 278 values.
  - WP4: `398a2ad` merged `m2/ragdoll` @ `4181f53` (see the 10:45 entry).
  - Flash: `33fcc98` merged `m2/hit-flash` @ `dfc56e8`:
    - `game/fx/hit_flash.gdshader` is a per-rig overlay, `next_pass` only while flashing, and warmed up at load;
    - `HumanoidRig.flash_at()` and `follow_flash()`; `set_flash()` stays whole-body for the cyan parry flash;
    - a "Hit flash" subgroup in "Hit feel": `hit_flash_radius_m` 0.25, `hit_flash_strength` 1.0, `hit_flash_core` 0.5, and `hit_flash_frames`, which moved there;
    - it lasts exactly `hit_flash_frames` rendered frames: before, the player's own hits showed one, because of the tick order;
    - first-person white on a jab at 1 m fell from 27.5% to 3.8%; a 4 m radius gives the old whole-body look;
    - sheets (local) in `.worktrees/m2-flash/captures/flash/`.
- **Known items for phase 3** (judge from captures; fix or ask Game-boy):
  - Flash: in side view the 0.25 m flash hides under the comic burst (the burst has a minimum view share). A minimum on-screen size for the flash would be new design: ask Game-boy.
  - Flash: when the player is hit, the contact is behind the lens, so the flash no longer shows in first person; before, the player's arms flashed white. Judge whether a hit on the player still reads (shake, HUD).
  - Flash: `tests/test_vfx.gd`, `test_hit_flash_still_covers_the_damage_look`, has a doc comment that still says emission.
  - WP4 leftovers:
    - joint-limit transients on impact (probes only);
    - staggers subtle from the side (influence is at the spec's 0.6);
    - lying poses close to M1's;
    - six ragdolls cost about 1.2-1.5 ms a frame.
  - WP2 leftovers:
    - the first finisher of a run drops about one frame;
    - light bursts are about 10% of the view at jab range;
    - the bruised look is subtle in side view;
    - the combat log covers the side view in combo_bot captures.
  - The speed lines use an unseeded random generator, so captures differ after a finisher.
  - WP1 notes: the F1/F4 overlay takes all keys while open, and the help overlay still labels F1 "Tuning panel (Milestone 2)".
  - The flash and the ragdoll have not been recorded together yet.
- **Resume:** start from the takeover prompt below. Its "Next steps" are current.
- **Waiting on Game-boy:** the four open questions in the takeover prompt, and a listen to WP3's audio.
- **Usage this account (D):**
  - WP4's builder cost about 52% of a window; its two reviewers about 22% each.
  - The WP4 fix pass cost about 40% and was cut off; its finish took about a third of a window, run alongside the flash agent.
  - Plan on about a whole 5-hour window for phase 3's review and fix.

### 2026-10-24 10:45 CDT: WP4 merged into `m2/hit-feel` (429/429); flash agent running; weekly at 65%
- **WP4 done:** `m2/ragdoll` @ `4181f53`, "M2 WP4: review fixes (...)".
  - Of the 18 findings, 15 are fixed and 3 partly (mech-F4 joint-limit transients on impact, feel-F3 staggers still subtle from the side, feel-F4 lying poses close to M1's). mech-F13 is a spec question.
  - The verdicts are in [docs/reviews/M2-WP4-fix-results.json](reviews/M2-WP4-fix-results.json). The A/B after-sheets (local) are in `.worktrees/m2-ragdoll/captures/review_after/sheets_after/`.
  - The lead judged the haymaker, face-down and hook A/B sheets, and they read as reported.
  - The lead accepts two changes:
    - `get_head_top_position()` now follows the visible head; only the health bars and debug draw read it;
    - a pile's top body gets up about 0.8 m aside (brief decision 3).
- **Merged:** `398a2ad`. The preset regenerated unchanged (275 values). **429/429 tests pass with no SCRIPT ERROR or ERROR.** Pushed.
- **Running:** the localized-flash agent in `.worktrees/m2-flash` (see the 10:38 entry). Merge `m2/hit-flash` next; its `tuning_data.gd`, `combat_actor.gd` and `humanoid_rig.gd` edits sit beside WP4's.
- **Usage:** 53% of the 5-hour window (resets 13:40 CDT). **Weekly is at 65%** (resets Tue 2026-10-27 12:00 CDT), the "launch nothing new" line. This account launches no new heavy agent; that is Game-boy's call.
- **Waiting on Game-boy:**
  - mech-F13: approve the capped central kick on the struck part instead of SPEC §6's "impulse at the contact point", with a README entry;
  - the builder's three questions (KO bodies sleep until the arena clears; KO bodies take no hits; heavy-tier knockdowns get the full ragdoll);
  - whether staggers may go above the spec's 0.6 influence to read better from the side.
  - All are left as they are until he answers.

### 2026-10-24 10:38 CDT: two agents running (WP4 fixes, localized hit flash)
Usage is at 14% of the 5-hour window (resets 13:40 CDT) and 58% weekly.
- **Running (agent 1):** the WP4 verify-and-fix finish in `.worktrees/m2-ragdoll` (see the 10:08 entry).
- **Running (agent 2):** the localized white hit flash (Game-boy approved it at 10:40) in a new worktree `.worktrees/m2-flash`, branch `m2/hit-flash` (off `m2/hit-feel` @ `d99eecf`, imported and pushed). It builds:
  - a per-rig overlay ShaderMaterial, used as `next_pass` only while flashing; the parry flash stays whole-body;
  - `hit_flash_radius_m` (0.25), `hit_flash_strength` (1.0) and `hit_flash_core` (0.5) in "Hit feel";
  - a fix so the flash shows for `hit_flash_frames` rendered frames (the captures show one);
  - `tests/test_hit_flash.gd`, and captures in `captures/flash/`.
  - It ends with a commit "M2 phase 3: localized white hit flash (...)".
- **Merge plan:** merge `m2/ragdoll` and `m2/hit-flash` into `m2/hit-feel`. Both touch `combat_actor.gd`, `humanoid_rig.gd` and `tuning_data.gd` in different places. Then regenerate `tuning/default.json` (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run the tests and push.
- **If cut off:** check each branch for its final commit. Without one, rerun that agent's step from its newest `wip:` commit.

### 2026-10-24 10:08 CDT: account D resumed after its reset; WP4 verify-and-fix finishing
Game-boy stayed on account D. The 5-hour window is at 4% (resets 13:40 CDT), and weekly is at 56% (resets Tue 2026-10-27 12:00 CDT). Extra usage now shows as enabled ($0 spent). The watcher `usage-watcher-e` is still running.
- **Running:** one background agent, started from this session, finishes the WP4 verify-and-fix pass in `.worktrees/m2-ragdoll`, as in the 23:50 entry's resume step 1. It will:
  - give a verdict for each of the 18 findings;
  - finish or revert `5be9500`'s half-done edits;
  - re-record into `captures/review_after/`;
  - write `docs/reviews/M2-WP4-fix-results.json`;
  - commit "M2 WP4: review fixes (...)" and push, with `wip:` commits every 15-20 minutes.
- **If cut off:** check `m2/ragdoll` for the "review fixes" commit. Without one, rerun the same step from the newest `wip:` commit.
- **Still open with Game-boy:** the builder's three ragdoll spec questions. The agent leaves all three ragdoll behaviours as they are. (The white hit flash was decided at 10:40: localize it; see the Decisions log.)

### 2026-10-23 23:50 CDT: handoff, account D's 5-hour window at 84%
The watcher warned at 84% of the 5-hour window (resets 03:30 CDT on 10-24), climbing about 1.2 points a minute. Weekly is at about 47%. The workflow `wf_6868f11f-7bd` is stopped, and nothing else is running. Every branch is committed and pushed, and the worktrees are clean apart from the untracked `captures/` folders.
- **WP4 state** (`m2/ragdoll`, `.worktrees/m2-ragdoll`):
  - **Build:** done at `96defb9` (see the 21:55 entry).
  - **Reviews:** done. 18 findings (13 mechanics, 5 feel) are committed in [docs/reviews/M2-WP4-review-findings.json](reviews/M2-WP4-review-findings.json) on `m2/ragdoll` (`f51cc42`).
    - High: mechanics F1 (the get-up fade drops the relocation, a pop), F2 (a player standing over the body moves the get-up spot about 0.7 m after a stomp) and F3 (face-down landings lie twisted, up to 1.42 m from the hurtboxes). Feel F1 (a parried jab's forearm swings into the lens) and F2 (finisher launches stay upright through the hitstop exit and the slow-mo).
    - Mechanics F13 is a spec question (the README departure for heavy-tier knockdowns).
  - **Verify and fix: cut off mid-pass.**
    - Its `wip:` commits are `47758b4`, `a599de1` and `73fb051`, plus the lead's `5be9500`, which commits the agent's uncommitted `combat_actor.gd`, `tuning_data.gd` and `default.json` edits. Those edits may be half done.
    - Going by the commit messages, the pass touched almost every finding:
      - the get-up fade, no ring jump, re-anchored and limit-clamped pose springs, a whole-body turn, landing aim, influence rise, kick hold and rest from real motion;
      - new tests (kick held, forced relocation, stomp get-up, face-down, joint limits, re-stagger, calm sleep, idle bodies, re-entered tree, parry, launch snap, CCD), and the arms tracking a stagger.
    - It recorded **no verdicts**, no after-captures and no final commit.
    - **`5be9500` passes 425/425 tests**, with no SCRIPT ERROR.
- **Resume steps:**
  1. Run **one** agent in `.worktrees/m2-ragdoll` (absolute path; `cd` there for every command). Give it each of the 18 findings in `docs/reviews/M2-WP4-review-findings.json`, and have it:
     - check each against `96defb9..5be9500` and give a verdict (confirmed, partial or refuted; fixed or not);
     - finish any gaps;
     - re-record `tests/bot/ragdoll_bot.tscn` in both views into `captures/review_after/` and judge the frames;
     - run `tools/run_tests.sh`;
     - write the verdicts to `docs/reviews/M2-WP4-fix-results.json`;
     - commit "M2 WP4: review fixes (...)" and push.
  2. Merge `m2/ragdoll` into `m2/hit-feel`, run the tests (all pass, no SCRIPT ERROR), push and update this file.
  3. Phase 3 (see the takeover prompt).
- **Usage this window:** the two reviewers together took the window from 0% to 44%, about 22% each. The verify-and-fix agent then took it from 44% to 84% in about 35 minutes and wasn't finished. Plan on a full window for a WP4-sized build, and about half a window for its fix pass.
- **Waiting on Game-boy:** the white hit flash (localize it, or keep it as the spec says), and the builder's three ragdoll spec questions (in the 21:55 entry).

### 2026-10-23 21:55 CDT: WP4 built; reviews wait for the 22:30 reset
- **Builder done:** `m2/ragdoll` @ `96defb9`, "M2 WP4: partial and full ragdoll". **412/412 tests pass** with no SCRIPT ERROR, and the branch is pushed.
  - Core: `game/actors/ragdoll.gd`, a SkeletonModifier3D after the PhysicalBoneSimulator3D.
  - Layer 8 "ragdoll", a "Ragdoll" tuning group (34 values in 6 subgroups), and `tuning/default.json` regenerated (265 values).
  - Tests in `tests/test_ragdoll.gd` (12), and `tests/bot/ragdoll_bot.tscn` with 10 acts × 2 views.
  - Captures (local) in `.worktrees/m2-ragdoll/captures/ragdoll/`: `ragdoll_acts.avi` and 20 sheets in `sheets/`.
- **Builder's departures from the brief:**
  - joints are made on the physics server;
  - time scaling uses velocity changes, not a custom integrator;
  - per-body pose springs, besides the hips spring;
  - central kicks on the struck body part, chosen by hurtbox region;
  - no gravity on the partial ragdoll;
  - ragdolls collide with each other.
- **Builder's known issues:**
  - the visible body is up to 0.96 m from the hurtboxes for about 0.05 s just after a finisher's hitstop, 0.13 m lying;
  - the get-up position now depends on Jolt;
  - lying bodies sleep, so the downed breathing stops.
- **Stopped:** the workflow `wf_6868f11f-7bd` ended at the review gate at 68% of the 5-hour window. The builder alone took the window from 16% to 68%, about 52% (twice the estimate). Weekly is at 40%.
- **Resume (this session, after 22:30 CDT):** `Workflow({scriptPath: "<session>/workflows/scripts/m2-wp4-ragdoll-wf_6868f11f-7bd.js", resumeFromRunId: "wf_6868f11f-7bd", args: {review_gate_attempt: 2}})`. The builder comes back from cache; the reviewers and then the verify-and-fix agent run live.
- **Resume (another account):** run the two reviews (mechanics; feel from re-recorded captures) and then the verify-and-fix pass on `m2/ragdoll`, as in the 20:38 entry.
- **Waiting on Game-boy:**
  - phase 3's white hit flash (localize it, or keep it as the spec says);
  - the builder's three spec questions:
    - KO bodies sleep where they lie until the arena clears (Milestone 3);
    - KO bodies take no hits;
    - heavy-tier knockdowns get the full ragdoll, because the reaction decides, not the tier.

### 2026-10-23 20:38 CDT: account D took over; WP4 workflow running
A fresh account's working session took over at 15% of its 5-hour window (resets 22:30 CDT) and 31% weekly (resets Tue 2026-10-27 17:00 CDT). Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-e` (Haiku, low effort, self-paced).
- **Running:** workflow `m2-wp4-ragdoll` (run `wf_6868f11f-7bd`, started from this session), all in `.worktrees/m2-ragdoll`:
  1. A usage gate, then **one builder**. It implements M2-WP4-brief.md, writes `tests/test_ragdoll.gd` and `tests/bot/ragdoll_bot.*`, records into `captures/ragdoll/` and ends with a commit "M2 WP4: partial and full ragdoll".
  2. A usage gate, then **two reviewers at once**, both review-only: mechanics (scratch in `captures/review_mech/`) and feel from re-recorded captures (`captures/review_feel/`).
  3. A usage gate, then **one verify-and-fix agent**. Its first step writes the reviewers' findings to `docs/reviews/M2-WP4-review-findings.json` and commits them. It then verifies each finding, fixes those that hold, records `captures/review_after/` and ends with a commit "M2 WP4: review fixes (...)".
  - Every gate stops new launches at 65% of either window. The verify-and-fix gate will probably land before the 22:30 reset. If it stops there, resume after the reset in this session: `Workflow({scriptPath, resumeFromRunId: "wf_6868f11f-7bd", args: {fix_gate_attempt: 2}})`. The script is under this session's `workflows/scripts/`. The finished stages come back from cache.
- **If cut off (another account):**
  - check `m2/ragdoll` for its "M2 WP4" commits;
  - with no "partial and full ragdoll" commit, rerun the builder from its last `wip:` commit, using the brief;
  - with no findings file, run the two reviews;
  - with no "review fixes" commit, run the verify-and-fix pass on `docs/reviews/M2-WP4-review-findings.json`.
- **Then:** merge `m2/ragdoll` into `m2/hit-feel`, run `tools/run_tests.sh` (all pass, no SCRIPT ERROR), push, then phase 3 (see the takeover prompt's "Next steps").

### 2026-10-23 20:33 CDT: Game-boy switches to a fresh account now
This account is at 86% of its 5-hour window, which resets at 21:39 CDT; weekly is at 15%. Game-boy chose a fresh account over waiting for that reset. This session stopped its 21:41 WP4 launch timer, so nothing launches here. It told its watcher (`usage-watcher-d`) to end its loop and renamed itself "Beat-em-up: 20:20 takeover session (handed off)", which frees the working-session title.
- **State:** everything is committed and pushed, and the worktrees are clean. No workflows or agents are running.
  - `m2/hit-feel` @ `584be65` (this entry follows): phase 1 merged, 400/400 tests.
  - `m2/ragdoll` @ `584be65`, `.worktrees/m2-ragdoll`: up to date and imported, with no WP4 work yet.
- **Decisions since the last entry:** Game-boy kept all eight phase 1 spec defaults (see "Decisions log"). README now has "Where M2 departs from the spec" with the two WP1 items.
- **Resume steps:**
  1. Start from the takeover prompt under "Takeover prompt". Its "Next steps" are current.
  2. Run WP4 as a workflow in `.worktrees/m2-ragdoll`: one builder, then two reviewers at once, then one verify-and-fix agent, with a usage gate before each launch. Tell each agent the absolute worktree path, since the Workflow tool's `isolation: 'worktree'` fails here.

### 2026-10-23 20:25 CDT: phase 1 merged into `m2/hit-feel`; spec questions with Game-boy
A new working session took over at 79% of its 5-hour window (resets 21:39 CDT) and 14% weekly (resets Tue 2026-10-27 17:00 CDT). These are account B's reset times. Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-d`. It launched no agents (over the 65% gate) and did the rest itself.
- **WP1 done:** the lead checked all 17 findings against `a9f2aca` and `77455ed`; every one is fixed. Marker commit `99ff984`, "M2 WP1: review fixes (...)", pushed. Per-finding verdicts are in [docs/reviews/M2-phase1-fix-results.json](reviews/M2-phase1-fix-results.json) under `WP1-tuning`. The panel capture is `.worktrees/m2-tuning/captures/panel_after.avi` (local): pad focus walks a subgrouped page.
- **WP2 judged from its after-sheets** (and shown to Game-boy):
  - The speed lines are now crisp, tapered ink with a clear middle, in both views.
  - The three tier sizes read distinctly. The jab step has no lunge lines and the flying kick does.
  - Words stay with their dummies.
  - Damage looks read at 1 m in first person. In the full side view the bruised step is near invisible and bloodied faint, and the bloodied splats tile evenly over the shirt, like a print.
  - Phase 3 item, out of WP2's scope: M1's white hit flash fills about 40% of the first-person view on a jab at contact, and a wide band on knees.
- **Merged** `m2/tuning`, `m2/vfx` and `m2/audio` into `m2/hit-feel` (`361b4ec`, `4fbfef6`, `a3579fd`), keeping all four presentation lines and both ASSETS.md sections. The default preset is regenerated (231 values, `8a00724`). **400/400 tests pass with no SCRIPT ERROR.** Pushed.
- **Answered at 20:30 CDT: keep all eight defaults** (see "Decisions log"). Before that, the session was waiting on Game-boy for answers to the 8 spec questions below (WP3 ×4, WP2 ×2, and WP1 ×2, which are already implemented with the reviewers' defaults). Nothing acts on them until he answers.
  - WP1, debug time scale: 0.25x also stretches hitstop and the slow-mo timers, while camera punch and shake stay real time. Default: keep.
  - WP1, cheats out of presets: Save, Load and Reset skip the Debug group. Default: keep, and note it in README's Milestone 2 departures.
- **Next:** WP4 starts only after the 21:39 CDT reset (a heavy agent costs about 25%), per [docs/milestones/M2-WP4-brief.md](milestones/M2-WP4-brief.md), in a new worktree off `m2/hit-feel`.
- **WP4 setup (20:26 CDT):** worktree `.worktrees/m2-ragdoll` on branch `m2/ragdoll` (from `8f0b5f7`, imported, pushed). WP4 is to run as a workflow:
  - one builder;
  - then two reviewers at once, one on mechanics and one on feel from captures;
  - then one agent that verifies each finding adversarially and fixes the ones that hold.
  - A Haiku usage gate runs before each launch.
  - If cut off: check `m2/ragdoll` for its "M2 WP4" commits and resume from the last finished stage.

### 2026-10-23 20:20 CDT: Game-boy switches to a fresh account
Account C stopped work at 76% of its 5-hour window and 13% weekly. Both of its watchers are told to stop and are being archived. This session is renamed "Beat-em-up: account C session (handed off)", which frees the working-session title.
- **The next account:** start from the takeover prompt under "Takeover prompt". Its "Next steps" are current.
- **State:** everything is committed and pushed, and the worktrees are clean. The resume steps are those of the 19:15 entry.

### 2026-10-23 20:13 CDT: watcher relaxed; takeover prompt drafted
Account C sits idle at 74% of its 5-hour window (resets 23:00 CDT) and 13% weekly, after the 19:15 handoff below.
- **New watcher cadence**, set by Game-boy: every 20 minutes below 70%, every 10 minutes up to 85%, every 5 minutes above that. Halt and hand off at 90%. "Usage watcher" has the full rules and the prompt.
- **Takeover prompt:** the prompt for the next account is under "Takeover prompt".
- **Resume steps** are unchanged from the 19:15 entry.

### 2026-10-23 19:15 CDT: handoff, account C's 5-hour window at 71%
The watcher warned at 71% of account C's 5-hour window, which resets at 23:00 CDT; C's weekly is at about 10%. The workflow `m2-phase1-verify-fix` (run `wf_3d9df549-bac`) is stopped. Every branch is committed and pushed, and the worktrees are clean. The agents' full results are in [docs/reviews/M2-phase1-fix-results.json](reviews/M2-phase1-fix-results.json): verdicts, test counts, capture paths, spec questions and remaining items.

| WP | Branch / worktree | State |
| --- | --- | --- |
| WP2 VFX | `m2/vfx` @ `0d9a8a3`, `.worktrees/m2-vfx` | **Done.** "M2 WP2: review fixes". 16 findings (the 13 reviewed plus the lead's 3): 14 confirmed and 2 partial, all fixed. 341/341 tests pass with no errors. Fixes: speed lines are now crisp tapered ink (FX textures are held and preloaded), lunge lines need a ≥1.0 m lunge (`vfx_lunge_lines_min_m`), damage looks read at 1 m (bruised skin plus scuffed clothes, new `damage_scuffed.png`), VFX run after the cameras, tier size ratios, word and burst clamp rules, no flicker without the photosensitivity toggle, VFX subgroups. After-sheets (local, untracked) are in `.worktrees/m2-vfx/captures/review/after_*.png`. **Not yet judged by the lead.** |
| WP3 audio | `m2/audio` @ `73f0a39`, `.worktrees/m2-audio` | **Done.** "M2 WP3: review fixes". Its own review found 27 items: 13 confirmed, 5 partial and 9 refuted; 18 fixed. 329/329 tests pass. Fixes: front-loaded whooshes, tier loudness order, blocks louder, one swing through several bodies layers once, wind-up cut on interrupt, hits on the player placed from the attacker's side, limiter pre-gain, oldest-voice stealing (32 voices), rumble merge and pause handling. Spectrograms are in `.worktrees/m2-audio/captures/review/`. |
| WP1 tuning | `m2/tuning` @ `77455ed`, `.worktrees/m2-tuning` | **Cut off near the end.** The agent reproduced all 17 findings and implemented the fixes: gamepad A/B and D-pad focus links, free fly held while the panel is open, preset range and enum checks and backups, cheats left out of presets, "default" export and shadowing, spawn clear of walls, the debug scale stretching hitstop (TimeController), subgroup headings, cheaper change markers, and tests in a scratch preset folder. The `wip:` commit passes **324/324 tests with no SCRIPT ERROR**. It was recording its panel capture. |

**Resume steps:**
1. **Finish WP1** with one agent in `.worktrees/m2-tuning`:
   - check each of the 17 findings in `docs/reviews/M2-phase1-review-findings.json` (keys `review:wp1:*`) against the `wip:` commits `a9f2aca` and `77455ed`, and fix any gap;
   - record a short panel capture (gamepad focus, a subgrouped category);
   - run the tests, commit "M2 WP1: review fixes (...)" and push.
2. **The lead judges the WP2 after-sheets** in `.worktrees/m2-vfx/captures/review/` and shows them to Game-boy.
3. **Merge** `m2/tuning`, `m2/vfx` and `m2/audio` into `m2/hit-feel`:
   - keep all four `_build_presentation()` lines in `test_room.gd` and both ASSETS.md sections;
   - WP2's ARCHITECTURE "VFX" paragraph sits after CameraDirector, WP3's "Audio and rumble" after "Input";
   - WP2 changed `vfx_min_view_share` to 0.04 and `vfx_lunge_lines_min_m` to 1.0;
   - WP2 added a `##` doc comment above `impact_frame_enabled` in "Hit feel".
4. **After merging:** `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`, then `tools/run_tests.sh`. Everything must pass with no SCRIPT ERROR. Push and update this file.
5. **WP4:** the player-ragdoll default is confirmed.

**Spec questions for Game-boy (defaults keep the spec as written; none implemented):**
- **WP3, body fall:** the body-fall layer plays at contact, but the body lands 0.5-1 s later. Proposal: play it on ground contact (needs a new sim event).
- **WP3, swing whoosh:** `attack_whiffed` fires when the active frames end, so whiffs sound 1-3 frames late. Proposal: a new `attack_active` event, and one swing whoosh per attack at its first active frame.
- **WP3, wind-up whoosh:** it plays at wind-up start. Proposal: keep only the effort grunt as the cue.
- **WP3, slow-mo audio:** an optional pitch-down or low-pass of the SFX during the finisher slow-mo, a tunable that defaults off.
- **WP2, bruised look:** "bruised" now also scuffs the clothes, because the skin barely shows at 1 m or in side view. If Game-boy wants skin only, it's a one-line revert.
- **WP2, flashing toggle:** the photosensitivity toggle (`impact_frame_enabled`) also stops the speed-line flicker. A separate "reduce flashing" toggle would be a spec change.

**Usage this window:** WP2 and WP3 ran together and took account C from 3% to 55% in about 40 minutes, about 26% each for a combined review and fix. WP1 launched at 55%, and the window reached 71% by 19:11. **Plan on roughly 25% of a 5-hour window per combined review-and-fix agent.**

### 2026-10-23 18:10 CDT: account C took over; phase 1 verify-and-fix running
A third account's working session took over at 0% of its 5-hour window (resets 23:00 CDT) and 0% weekly (resets Wed 2026-10-28 11:00 CDT). Its usage watcher runs (Haiku, low effort, `/loop 5m`, session "Beat-em-up: usage watcher").
- **Running:** workflow `m2-phase1-verify-fix` (run `wf_3d9df549-bac`, started from this session). It runs one heavy agent per WP and at most two at once: WP2 and WP3 first, then WP1. A Haiku usage gate runs before each launch and stops new launches at 65% (5-hour) or 85% (weekly).
  - **WP2:** verifies the 13 findings and fixes them in `.worktrees/m2-vfx`. It also fixes the speed-line texture lifetime (the lines must end as crisp tapered ink), lunge lines on plain jabs, and the bruised look at 1 m. It leaves after-sheets in `.worktrees/m2-vfx/captures/review/`.
  - **WP3:** reviews from scratch (mechanics, plus feel by WAV and capture-audio analysis), then verifies and fixes in `.worktrees/m2-audio`.
  - **WP1:** verifies the 17 findings and fixes them in `.worktrees/m2-tuning`, including the panel showing `@export_subgroup` headings. WP2 and WP3 put their own groups into subgroups.
  - Each agent commits "M2 WPn: review fixes (...)" and pushes its branch, committing `wip:` along the way.
- **If cut off:** check each WP branch for a "review fixes" commit. A WP without one needs its pass redone. Copy that WP's prompt from the workflow script in this session's transcript, or rewrite it from this entry. Within the same session, resume with `resumeFromRunId`.
- **Then:** merge into `m2/hit-feel` as the trial did, regenerate the preset, run the tests, push. Then WP4: Game-boy confirmed the player-ragdoll default at 18:20 CDT (enemies and dummies ragdoll; the player keeps animated reactions, with a toggle).

### 2026-10-23 17:25 CDT: handoff, account B's 5-hour window at 72% (switched accounts 17:55)
The watcher warned at 72% of account B's 5-hour window, which resets at 21:40 CDT; B's weekly is at 12%. Account A's weekly is still at 95% until Mon 2026-10-26 01:00 CDT. Everything is committed and pushed; the worktrees are clean.
- **Burn rate.** In about 20 minutes, four parallel review agents took the window from 7% to 62%. Each heavy reviewer costs about 13% of a 5-hour window here, so run at most 2 at once and gate every launch on `get_usage`.
- **Stopped:** workflow `m2-phase1-review-fix` (run `wf_18e38241-91a`). Four of its six reviewers finished.
  - Their 30 findings are saved in [docs/reviews/M2-phase1-review-findings.json](reviews/M2-phase1-review-findings.json) (WP1 mechanics and feel, WP2 mechanics and feel).
  - None are verified or fixed yet.
  - The two WP3 reviewers were cut off with no result. Their scratch probes sit in `.worktrees/m2-audio/captures/scratch_probes/` and `.worktrees/m2-trial/captures/scratch_probes/` (untracked, ignored).
- **Headline findings, unverified:**
  - WP2: the speed-line defect has a root cause. `VfxArt` keeps no texture alive, so `speed_lines.png` is freed after every `_draw` and reloads from disk, and every FX texture loads at the moment of the hit.
  - WP2: a per-sprite view clamp makes the light, heavy and finisher bursts the same size.
  - WP2: effects are placed against the previous frame's camera.
  - WP2: words are forced into view even for hits behind the camera.
  - WP2: the speed lines flicker at 30 Hz regardless of the photosensitivity toggle.
  - WP1: the gamepad can't reach the sliders, and A/B do nothing (`ui_accept`/`ui_cancel` have no joypad buttons in 4.7).
  - WP1: spawn-at-crosshair can place dummies in walls or bodies.
  - WP1: presets aren't range-checked.
  - WP1: the 0.25x cheat doesn't slow hitstop or slow-mo.
- **Resume steps:**
  1. Run a verify-then-fix pass per WP from the JSON, at most 2 heavy agents at once: one skeptic per WP, then one fixer per worktree that commits "M2 WPn: review fixes" and pushes.
  2. WP3 still needs its two reviews (mechanics; feel by audio analysis of the WAVs and a capture's audio track).
  3. Then merge into `m2/hit-feel`. The trial merge at `.worktrees/m2-trial` (local only) shows how: keep all four `_build_presentation()` lines and both ASSETS.md sections, then `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`, then `tools/run_tests.sh` (371 pass).
  4. Then WP4.
- **WP4 brief:** the lead's design decisions for the ragdoll are drafted in [docs/milestones/M2-WP4-brief.md](milestones/M2-WP4-brief.md). The player keeps animation-only reactions by default, with a toggle (asked of Game-boy, no answer yet). Staggers get a partial ragdoll on the upper body. Every off-feet reaction gets a full ragdoll held to the simulation's body by a soft spring. The ragdoll follows each actor's hitstop and slow-mo scale. A "Ragdoll" tuning group.
- **17:55 CDT: Game-boy switched accounts.** Account B's watcher has been told to end its loop, and B's working session was renamed "Beat-em-up: account B session (handed off)", which frees the title. The new account's session renames itself "Beat-em-up: working session" and starts its own watcher. The player-ragdoll default is still unanswered; ask Game-boy before WP4 starts.

### 2026-10-23 17:05 CDT: account B took over; phase 1 review and fix running
Account B's working session took over at 1% of its 5-hour window (resets 21:39 CDT) and 0% weekly (resets Tue 2026-10-27 17:00 CDT). Its usage watcher runs (Haiku, `/loop 5m`, session "Beat-em-up: usage watcher").
- **WP2 tests:** all 332 pass in `.worktrees/m2-vfx`. The lead recorded the whole `vfx_bot` (13 acts, first person and side view) and judged it. Bursts, words, the 2-frame impact frame and its toggle, blood, spit and tooth, and the block, parry and guard-break sparks all read well. Three defects:
  - the speed lines render as wide gray translucent rectangles instead of tapered ink streaks (about 40% of the screen in side view on finishers);
  - lunge lines fire on ordinary jab steps;
  - the bruised look barely reads at 1 m.
- **Trial merge:** `.worktrees/m2-trial` (branch `m2/trial-merge`, local scratch, never merge it) has all three WPs merged, with only the expected conflicts (the `test_room.gd` presentation lines, keep all four; `ASSETS.md` Effects and Audio sections, keep both; `tuning_data.gd` merged cleanly). With `tools/gen_default_preset.gd` re-run, **all 371 tests pass**.
- **Running:** workflow `m2-phase1-review-fix` (run `wf_18e38241-91a`). Per WP, a mechanics reviewer and a feel reviewer (from captures) feed one adversarial verifier, then a fixer in that WP's worktree that commits "M2 WPn: review fixes ..." and pushes its branch. A usage gate drops to 2 agents at once past 50% of the 5-hour window and stops at 75%.
- **If cut off:** check each WP branch for a "review fixes" commit. Any WP without one needs its review/fix redone, or resume the workflow in the same session with `resumeFromRunId`. Then merge into `m2/hit-feel` as the trial did, regenerate the preset, run the tests and push.

### 2026-10-23 13:05 CDT: handoff to the second account (account A's weekly limit is at 95%)
Account A's weekly limit is at 95% and resets Mon 2026-10-26 about 01:00 CDT. Its 5-hour window has just reset. Everything is committed and pushed. Milestone 2, phase 1:

| WP | Worktree / branch | State | Next |
| --- | --- | --- | --- |
| WP1 tuning panel, presets, cheats | `.worktrees/m2-tuning` / `m2/tuning` | **Built**: `bb4b3c1`, 313 tests pass. F1 panel auto-built from TuningData plus a Moves page; JSON presets; F4 cheat menu; ARCHITECTURE section. | Adversarial review, then fix. |
| WP2 comic VFX, damage looks | `.worktrees/m2-vfx` / `m2/vfx` | **Builder cut off mid-build.** Five `wip:` commits: the SVG art set (`tools/gen_fx.gd`, PNGs), VfxDirector, damage looks, the VFX tuning group, bot acts, `tests/test_vfx.gd`, ASSETS.md. Unknown whether the tests pass. | Run `tools/run_tests.sh` in the worktree. Finish the brief (M2-plan.md WP2): judge captures from first person and side view. Commit, then review and fix. |
| WP3 audio, rumble | `.worktrees/m2-audio` / `m2/audio` | **Built**: `2d562d7`. `tools/gen_sfx.gd`, `.wav` set, AudioDirector, RumbleDirector, Audio tuning group, `tests/test_audio.gd`. | Adversarial review, then fix. |

**On a new machine:** `git fetch` and create the worktrees from the pushed branches, for example `git worktree add .worktrees/m2-vfx m2/vfx`.

**Then merge into `m2/hit-feel`.** Expect trivial conflicts in:
- `game/level/test_room.gd` `_build_presentation()`, where each WP added one marked line;
- `ASSETS.md`, where WP2 and WP3 each added a section;
- maybe `game/autoload/tuning_data.gd` (WP2 put "VFX" after "Hit feel"; WP3 put "Audio" before "Debug").

**After merging:** regenerate the default preset with `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd` (WP1's test fails by design until you do). Run all tests, push, and update this file.

**Phases 2 and 3 after that:** see [docs/milestones/M2-plan.md](milestones/M2-plan.md).

**Notes from WP1's builder:**
- The F1/F4 overlay takes all keys while open, so F2, F3, F5 and H work only after closing it.
- The help overlay still labels F1 "Tuning panel (Milestone 2)".
- README controls are phase 3's job.

**Lesson (usage).** Three parallel builders burned about 70% of a 5-hour window in roughly 30 minutes, inside one 15-minute watcher interval, so the window ran out with no warning. Before launching a workflow, check `mcp__ccd_session_mgmt__get_usage`. Run at most two heavy agents at once when the window is past 50%. The watcher now checks every 5 minutes and also warns on fast burn (see below).

### Earlier: Milestone 2 phase 1 started
- Milestone 1 is done: Game-boy signed it off after three playtest rounds, and it's merged into `main` (PR #1, merge `c3e6a98`). Milestone 2 is on branch `m2/hit-feel`, from `main`.

## Decisions log (Game-boy)
Every approved spec change so far is in README.md, "Where M1 departs from the spec". In short:
- **Camera and stance:** throat-height lens; relaxed player stance; smaller wrapped hands; enemy gloves and guard pulled in.
- **Block and grab:** a held block on neutral B (guard meter, perfect block, guard break, sparring dummy); grab anytime except against a mid-strike enemy; dodges kept, with a late-stick fix.
- **Moves and camera:**
  - the view follows the spin of the spin kick, the heel kick and the spinning backfist;
  - the spinning backfist is on P P · P and the flurry on P · P;
  - the back elbow turns the view 150° (Game-boy is to confirm whether 110° is preferred).
- **Ragdoll (M2 WP4, 2026-10-23):** enemies and training dummies ragdoll. The player keeps animated reactions by default, with a toggle in the "Ragdoll" tuning group.
- **Usage watcher cadence (20:13 CDT):** checks every 20 minutes below 70%, every 10 minutes up to 85%, every 5 minutes above that. It halts work and hands off at 90% (it was 70% before). See "Usage watcher".
- **Phase 1 spec questions (20:30 CDT): all eight defaults kept.**
  - WP3: the body fall stays at contact, there's no new `attack_active` event, the wind-up whoosh stays, and there's no slow-mo audio filter.
  - WP2: bruised still scuffs the clothes, and there's no separate "reduce flashing" toggle.
  - WP1: the 0.25x cheat also stretches hitstop and slow-mo, and cheats stay out of presets. Both are recorded in README, "Where M2 departs from the spec".
- **White hit flash (2026-10-24 10:40 CDT): localized.** Full white at the contact point, fading out by a tunable radius (default about 0.25 m), with a tunable strength, both in "Hit feel". A large radius gives the old whole-body look. Recorded in README's M2 departures. It's implemented in phase 3, after WP4 merges: `combat_actor.gd` and `humanoid_rig.gd` overlap WP4. Also check that it really shows `hit_flash_frames` (2) frames, since the WP2 captures show one white frame per hit.
- **WP4 ragdoll questions (2026-10-24 11:05 CDT):**
  - the hit's push at the exact contact point is preferred, since comic contortions are fine; phase 3 builds it with spin caps and shows A/B captures first;
  - KO bodies lie briefly, then blink off (a departure from SPEC §6's "stay until the arena clears");
  - KO bodies take no hits;
  - heavy-tier knockdowns get the full ragdoll (a departure);
  - staggers may exceed SPEC §6's 0.6 influence (a departure).
- **Grab view (2026-10-24 11:05 CDT):** while holding, the first-person view pans down so the knees show landing on the held enemy, and the player bends at the waist for the hold and the knees. The spec doesn't cover it, so it's not a departure. Details: [milestones/M2-phase3-plan.md](milestones/M2-phase3-plan.md).
- **Ultracode (2026-10-24 11:38 CDT):** Game-boy turned ultracode on. Substantive work runs as Workflow scripts (multi-lens review, adversarial verification, completeness critic), with the usage rules still in force.
- **Handoff for package C (2026-10-24 12:38 CDT):** switch accounts now rather than wait for account E's 16:30 reset.
- **Usage thresholds (2026-10-24 12:40 CDT):** work up to the 90% handoff instead of stopping new launches at 65%. Size each launch to the headroom left below 90%. When a new phase or milestone doesn't fit, split off a first task that does, run it, and hand off at 90%. See "Usage rules for the working session".
- **Side view is debug-only (2026-10-25):** only first-person looks and feel count; side view only checks mechanics (it may matter later for a 2-player mode). hit-05 and gap-06 are dropped, and the side-view flash's minimum size stays as it is.
- **The player's KO, an "out of body" view (2026-10-25):** the camera pans away from the body and shows the player lying on the floor, the only time it leaves the player's eyes. It's a README departure.
- **Round 2's proposed fixes are approved as written (2026-10-25)**, with the KO view as above.
- **Models (2026-10-25):** Opus for planning and review, Sonnet for coding and execution. Fixers run with `fixer_model: "sonnet"`.
- **Process:** at each usage limit, hand off to Game-boy's second Claude account. Never assume the same session resumes.

## Usage watcher
A separate low-cost Claude Code session, "Beat-em-up: usage watcher". Start it from the working session with `start_session`: initiation `user_asked`, `model` claude-haiku-5-5, `effort` low, `use_worktree` false, and the prompt below verbatim.

It paces itself (`/loop` with no interval), on Game-boy's cadence from 2026-10-23:

| Usage (the higher of the 5-hour and weekly windows) | Next check |
| --- | --- |
| below 70% | in 20 minutes |
| 70% up to 85% | in 10 minutes |
| 85% and up | in 5 minutes |

At 90% of either window it tells the working session to halt work and hand off. On a fast burn it checks sooner, and it warns early if it would cross 90% before its next check.

Its prompt:

```
/loop Usage watcher for the beat-em-up repo. You pace yourself. On each check:
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch the first time). Read plan.windows: the "5-hour limit" window and the window whose label starts with "Weekly". Let U be the higher of their percentUsed values.
2. Handoff. If either window is at 90% or more, and you haven't already warned for that window's resetsAt, send a message to the session titled "Beat-em-up: working session" (find it with ListAgents). The message: "Usage at N% (window W, resets R). Halt work and do the handoff now per CLAUDE.md: stop new work, commit and push WIP on every branch and worktree, update and push docs/HANDOFF.md, then tell Game-boy." Remember that you warned for that resetsAt.
3. Snapshot. If either window is at 95% or more, write HANDOFF-SNAPSHOT.md at the repo root (untracked; never commit it). It holds:
   - the time and the usage numbers;
   - git status, git branch -vv and git worktree list;
   - for each worktree under .worktrees/, its git status --short and git log --oneline -3.
4. Next check, from U:
   - below 70: in 20 minutes (1200 s);
   - 70 up to 85: in 10 minutes (600 s);
   - 85 or more: in 5 minutes (300 s).
5. Fast burn. Estimate the rate from your previous check. If at that rate either window would reach 90% before that next check, check again in 5 minutes instead. If it would reach 90% within those 5 minutes, send the step 2 warning now (once per resetsAt).
6. Schedule the next check with ScheduleWakeup, passing this same prompt back.
Otherwise say nothing beyond one short line: the two percentages and the next check time. Never edit tracked files, run builds or start other work.
```

**Usage rules for the working session** (Game-boy, 2026-10-24 12:40 CDT; they replace the old "launch nothing new at 65%" line, which stopped work too early):
- **Work up to the 90% handoff.** The watcher's 90% message is the only stop. Don't stop, idle or hand off at 65-70% because a big piece won't fit.
- **Size each launch to the headroom.** Call `mcp__ccd_session_mgmt__get_usage` before every launch. The headroom is 90% minus the higher of the 5-hour and weekly `percentUsed`. Launch work whose estimated cost fits it. Measured costs, in % of a 5-hour window:

  | Work | Cost |
  | --- | --- |
  | A builder the size of WP4, or phase 3's A or B | 30-50% |
  | A heavy agent that both reviews and fixes | about 25% |
  | A fixer | about 25% |
  | A review-only agent | about 13% |
  | Lead work (merging, judging sheets, docs) | a few % |
  | Two heavy agents at once | about 1.2-1.6 points a minute |

- **When the next phase or milestone doesn't fit:** say it's 70% and a new phase is next. Spend a little of the headroom splitting that phase into a first task that fits the rest, and run that task. Examples:
  - the setup: worktrees, imports, briefs, the workflow script;
  - one reviewer instead of five;
  - one fix package;
  - one well-scoped build step.

  Commit `wip:` as it goes, and hand off at 90%. Write the split into the milestone plan and HANDOFF, so the next account starts at the next task.
- **Keep the 90% cut cheap:** agents commit `wip:` and push every 15-20 minutes, so a halt loses little.
- **At most two heavy agents at once.** Near the top of the window, prefer one: two burn about 1.2-1.6 points a minute, and the watcher's 20-minute checks below 70% can't catch a faster burn.
- **Tighter checks during heavy runs:** while two heavy agents run, ask the watcher to check every 10 minutes even below 70%.

If no watcher is running, for example after an account switch, start one with that prompt. A new account's watcher reports that account's usage.

**The working session must be titled "Beat-em-up: working session"** so the watcher can find it. A new account's working session renames itself to that first, with `mcp__ccd_session_mgmt__set_session_title`.

**At an account switch, the old working session:**
- renames itself "Beat-em-up: account X session (handed off)", which frees the title;
- tells its watcher to end its loop: "End your loop now: call ScheduleWakeup with stop: true, or CronDelete your job if you run on a fixed interval."

## Takeover prompt
Game-boy pastes this into a new account's session. Keep the "Next steps" list current at every handoff; the rest changes rarely.

```
You're taking over an in-progress Godot 4.7.2 project: a first-person beat-em-up proof of concept at /Users/arachne/repos/beat-em-up-PoC (GitHub: mikedtcm22/beat-em-up-PoC). I'm Game-boy, the project owner. Other Claude accounts did the work so far and handed off at their usage limits. We switch accounts at every usage limit, so treat the repo as the only source of truth. Work happens on branch m2/hit-feel and the worktrees under .worktrees/.

Start by doing these, in order:
1. Rename this session to "Beat-em-up: working session" (mcp__ccd_session_mgmt__set_session_title). The usage watcher finds you by that title.
2. Read CLAUDE.md, then docs/HANDOFF.md (live status and exact resume steps; the newest entry is at the top). Then read the milestone docs and review files it points to: docs/milestones/M2-plan.md, docs/milestones/M2-WP4-brief.md, docs/reviews/M2-phase1-review-findings.json and docs/reviews/M2-phase1-fix-results.json. Read docs/ARCHITECTURE.md and docs/SPEC.md §6, §10 and §11 before touching code.
3. Start a usage watcher exactly as docs/HANDOFF.md describes under "Usage watcher" (Haiku, low effort, self-paced /loop, shares this checkout, its prompt verbatim). Confirm it's running.
4. Check usage (mcp__ccd_session_mgmt__get_usage) before launching any workflow or agent.

USAGE RULES:
- A builder the size of a work package costs 30-50% of a 5-hour window; a heavy agent that both reviews and fixes about 25%; a review-only agent about 13%.
- Run at most TWO heavy agents at once.
- Work up to the 90% handoff; don't stop early. Check get_usage before each launch and size the launch to the headroom left below 90%. If the next phase or milestone doesn't fit (say at 70%), spend a little of the headroom splitting it into a first task that fits, run it with wip commits, and hand off at 90%. Details: docs/HANDOFF.md, "Usage rules for the working session".
- Prefer one agent per work package doing review, then fix, over many reviewers per package.
- The watcher checks every 20 minutes below 70%, every 10 minutes up to 85% and every 5 minutes above that. It tells you to halt and hand off at 90%.

Next steps (Milestone 2; details are in docs/HANDOFF.md):
- Phases 1 and 2, the localized flash and phase 3's packages A (ragdoll: contact push, KO blink-off, staggers at 0.9) and B (grab view and waist bend) are merged into m2/hit-feel. 457/457 tests pass with no SCRIPT ERROR, at f98bb21. README has the three approved M2 ragdoll departures. WP3's audio was judged by analysis only, so I'll listen to it.
- Phase 3's package C runs as a Workflow (I turned ultracode on), per docs/milestones/M2-phase3-plan.md, "C", step 2. The code, ragdoll and grab reviews are done, and all 19 of their findings are verified: every one survives, and 2 are spec questions for me (grab-03, grab-05). The 17 others are split into four fix packages (docs/reviews/M2-phase3/packages.json on branch m2/phase3-review). All four packages are fixed and merged into m2/hit-feel with the review records (484/484 tests, no SCRIPT ERROR). Round 2 reviewed the merged build: the hit-feel, performance and gap lenses and a completeness critic. hit-04 is fixed and merged (486/486). I gave my verdicts on 2026-10-25: side view is debug-only, the KO gets an "out of body" view, and every other proposed fix is approved. The four round 2 packages are in docs/reviews/M2-phase3/packages-r2.json. Today runs in legs across accounts, as docs/HANDOFF.md's newest entry says: leg 1 the round 2 fixes (workflow-fix.js with docs/reviews/M2-phase3/args-r2-fix.json, Sonnet fixers), leg 2 a final Opus review of the fixes in first person, leg 3 the docs and the PR. Claim a leg in HANDOFF before starting it. Then record the final sheets and show me. Then D: check ARCHITECTURE against the code, README's Milestone 2 status, and the M2 PR, which is never merged without my sign-off.
- Open for me (each has a default; none blocks C): more contortion on the ragdoll contact push (default: as it is); the grab's lens pull-back and the bend's depth (default: as they are); the combat log over the knee contact (default: C proposes a fix); a minimum on-screen size for the side-view flash (default: leave it). And I'll listen to WP3's audio.

Ground rules:
- Never merge a milestone PR into main until I've played it and signed it off.
- Any change to the spec needs my approval. Ask me with a short proposal and defaults.
- Commit early on branches (prefix "wip:" for unfinished work), push often, and update docs/HANDOFF.md at every phase boundary.
- When the watcher warns, do the handoff in CLAUDE.md immediately. Stop running workflows and agents, commit and push everything, save any unfinished agents' findings into the repo, and update HANDOFF.md, including this prompt's "Next steps". Then tell me.
- Judge visual and feel work from recorded captures (Movie Maker via tools/capture_combos.sh or tests/bot/vfx_bot.tscn), not just tests, and show me what you saw.
- Keep me posted briefly: what's done, what's running, what you need from me.
```
