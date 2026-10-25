# Milestone 3 plan: enemy AI and the rear warning (contracts first, maximum safe parallelism)

Branch `m3/enemy-ai` (cut from `main` at `0d6f8cd`, after M2 merged). SPEC §12, Milestone 3: "All archetypes in graybox, the director, flanking, the rear-attack warning, and a 6-enemy crowd test room." **Done when** a 6-enemy fight is readable, and the warning fires correctly behind-left, behind-right and directly behind.

Read before any package: CLAUDE.md, SPEC §5, §6, §7, §8, §11, §12, the six codemaps in `docs/milestones/M3-codemap/`, and section 4 of this plan (the contracts). Game-boy's M3 answers (HANDOFF 17:05) are binding; every other open call takes a default and is logged in `docs/milestones/M3-judgement-calls.md`.

## 0. The shape of the plan in one screen

| Phase | What | Who | Wall time | Cost (premium seat, % of a 5-hour window) |
| --- | --- | --- | --- | --- |
| 0a | **Interfaces**: every new class shell, every hook in a shared file, every tunable, every enemy move's data, every new event | 1 Sonnet builder (P0-A), lead reviews | ~1.5 h | ~8 |
| 0b | **Scaffolds** that let phase 1 test and record in parallel: rig/pose dispatch (P0-B), a working enemy body plus naive brain/director/room (P0-C), HUD/debug/bot hooks (P0-D) | 3 Sonnet builders in parallel, lead merges and tags `m3-contracts` | ~1.5 h | ~16 |
| 1 | **Ten disjoint packages** built in parallel worktrees: AI, DIR, ROOM, GRAB, WARN, DEBUGUI, GRUNTS, THUG, BRUISER, BOSS | Sonnet builders, 6 at once, then 4 | ~4 h | ~70 |
| 2 | **Integration**: mechanical merges, main scene, crowd-feel pass, done-when proof bots and test | lead + 2 Sonnet builders | ~2 h | ~13 |
| 3 | **Adversarial review rounds** (5 Opus lenses, Sonnet skeptics, critic, ≤4 Sonnet fixers), until no high or medium finding survives | Workflow | ~4-6 h | ~55 per round, plan 2 |
| 4 | **Ship**: README departures, ARCHITECTURE, judgement log, macOS export, GitHub Release, PR, Slack DM | lead + 1 Sonnet | ~1 h | ~5 |

Total: about 2.5-3 five-hour windows. Phases 0 and 1 cost about the same as a conventional plan; what phase 0 buys is that **every phase 1 merge is mechanical**. No phase 1 package edits a shared hot file except inside a pre-cut, non-adjacent section (section 3).

---

## 1. Requirements trace (every M3 requirement, its owner and its proof)

| Requirement (source) | Owner | Proof |
| --- | --- | --- |
| Street Punk: 30 HP, two-hit punch and shove (6 each), approaches head-on (SPEC §7) | WP-GRUNTS | `test_enemy_punk.gd`; FP telegraph sheets |
| Kicker: 25 HP, jump kick and low sweep (8), circles to the player's blind side | WP-GRUNTS (+ WP-DIR slot preference) | `test_enemy_kicker.gd` (slot bearing behind the look); F3 free-fly sheet |
| Pipe Thug: 35 HP, three-swing pipe combo (10), drops the pipe on knockdown, the player can take it | WP-THUG | `test_enemy_thug.gd` (drop on KNOCKDOWN/LAUNCH/THROWN/KO; player picks up and swings) |
| Bruiser: 80 HP, grab and headbutt, overhead smash (15), armored: ignores light hits, staggers on heavy hits and the haymaker | WP-BRUISER (armor, smash) + WP-GRAB (grab, headbutt) | armor matrix test; FP sheets |
| Boss (graybox, placeholder name): 300 HP, two phases, shoulder charge, grab slam, ground pound (15-25); at 50% turns faster and calls in two Street Punks (SPEC §7, Game-boy) | WP-BOSS (+ WP-GRAB slam, WP-DIR summon) | `test_enemy_boss.gd`; boss acts |
| Behavior states 1-7: enter, approach to the 2.5-4 m posture ring, posture (circle, strafe, taunt), wind-up (pose + vocal cue, ≥18 frames grunts, ≥30 Bruiser and boss), attack, recover, hit reactions, get-up with i-frames, KO slump | WP-AI (states), P0-A (floors), existing `CombatActor` (reactions, get-up, KO) | `test_enemy_ai.gd`; AI acts |
| Light hits interrupt grunt wind-ups, not Bruiser or boss wind-ups | P0-A hook + WP-BRUISER/WP-BOSS overrides | `test_m3_contracts.gd`, armor tests |
| Director: attack tokens, cap 3, tunable, 0 = unlimited | WP-DIR | `test_director.gd` |
| Blind-spot priority (out-of-view enemies get tokens first; dangerous) | WP-DIR (reads P0-A `PlayerCharacter.is_outside_view`) | `test_director.gd` |
| Spread: posturing enemies spread around instead of bunching in front | WP-DIR | `test_director.gd` angular-gap test; F3 sheet |
| At most 6 alive; spawn points in doorways, alleys, a vehicle, some behind the player | WP-DIR (cap) + WP-ROOM (points, waves) | `test_crowd_room.gd`, `test_waves.gd` |
| `NavigationAgent3D` on a baked navmesh, with avoidance | P0-C (plumbing, bake) + WP-AI (steering) + WP-ROOM (room bake) | `test_nav_baker.gd`, soak test min pair distance |
| Rear warning: trigger >55° from the look and within range + 1 m; sides; ±20° of behind lights both; flash at wind-up start, ends on land or interrupt; red-orange burst pulsing twice; Bruiser and boss larger; several attackers pulse brighter; positional audio; tunables (SPEC §8) | WP-WARN (+ P0-A `MoveData.reach_m`, `EnemyActor.heavy`) | `test_rear_warning.gd`; `test_m3_done_when.gd`; corner crop sheets |
| Enemy grabs on the player: telegraphed wind-up (a dodge or heavy hit gets out), mash P/K to break free, unbroken the hit lands (Game-boy) | WP-GRAB (+ P0-A hooks) | `test_enemy_grabs.gd`; grab acts |
| A single knockdown never takes more than 15% of the player's 100 HP, except from the boss (SPEC §4) | P0-A data + test | `test_enemy_moves.gd` |
| HUD: top corners kept for the warning; boss bar bottom-centre; over-head bars (SPEC §5) | WP-WARN (boss bar wiring), existing bars | `test_rear_warning.gd` corner test |
| Magnetism in a crowd (SPEC §5) | INT-1 | INT-1 tests |
| Tuning panel groups "Enemies" and "Rear warning" (SPEC §11) | P0-A declares; each owner reads | `test_tuning_panel.gd` |
| F3: each enemy's AI state over its head, who holds attack tokens (SPEC §11) | WP-AI (label text) + WP-DEBUGUI (overlay) | `test_ai_debug_overlay.gd`; F3 sheet |
| F4: spawn any enemy at the crosshair (SPEC §11) | WP-DEBUGUI | `test_cheat_spawn_enemies.gd` |
| Bot + Movie Maker captures that prove the done-when (SPEC §11) | P0-D harness; every WP's acts; INT-2 proof acts | sheets + logs listed in section 9 |
| A 12 x 30 m street-lane crowd room as the main scene, doorway/alley spawns (some behind), repeating mixed waves of up to 6, key back to the training room, auto-revive (Game-boy defaults) | WP-ROOM (+ P0-D F6 key, lead main scene) | `test_crowd_room.gd` |
| Playable link: zipped macOS export on a GitHub Release (Game-boy) | SHIP | the release URL |

---

## 2. Process rules that apply to every package

### 2.1 Worktrees and branches
- Phase 0: `m3/p0-core` (P0-A), then `m3/p0-rig`, `m3/p0-enemy`, `m3/p0-ui` (P0-B, C, D), each from `m3/enemy-ai` after P0-A merges. Worktrees `.worktrees/m3-p0-<x>`.
- After phase 0 merges, the lead tags `m3-contracts` and pushes the tag. Every phase 1 branch is `m3/wp-<key>` from that tag, in `.worktrees/m3-<key>`: `git worktree add .worktrees/m3-<key> -b m3/wp-<key> m3-contracts`, then `cd` there and `godot --headless --import --quit`.
- The Workflow tool's `isolation: 'worktree'` fails here. The lead creates every worktree before the launch; each prompt names its absolute path and says to `cd` there for every command.
- Before phase 0, the lead prunes the 30 M2 worktrees (`git worktree remove` each `.worktrees/m2-*` and `m3-export`): they hold full `.godot` caches and slow every import.

### 2.2 Ownership classes (the rule that makes merges mechanical)
- **Frozen after phase 0** (no phase 1 edits at all): `game/actors/combat_actor.gd`, `humanoid_rig.gd`, `placeholder_body.gd`, `placeholder_anims.gd`, `placeholder_poses.gd`, `game/actors/enemy_poses.gd`; `game/autoload/combat_events.gd`, `time_controller.gd`, `tuning.gd`, `game_input.gd`; `game/combat/*.gd`; `game/enemies/enemy_catalog.gd`, `enemy_move_ids.gd`; `game/enemies/dummy/*`; `game/level/test_room.*`; `game/ui/hud.tscn`, `debug_draw.gd`, `debug_draw.tscn`, `help_overlay.gd`, `tuning_*.gd`; `tests/test_move_data.gd`, `test_tuning_panel.gd`, `test_ui.gd`, `test_humanoid_rig.gd`, `test_combat_integration.gd` and every other M1/M2 test file; `tests/bot/combo_bot.gd`, `tests/bot/crowd_bot.gd`; `project.godot`, `.gitattributes`, `tools/run_tests.sh`, `tools/gen_default_preset.gd`; `docs/ARCHITECTURE.md`, `README.md`, `docs/HANDOFF.md`, `docs/milestones/M3-judgement-calls.md`.
- **Sectioned** (several owners, each in a pre-cut section, hunks never adjacent):
  - `game/autoload/tuning_data.gd`: each package edits only the lines of its own subgroup (section 4.6), may change defaults, ranges and `##` docs of its own tunables, and appends new ones only directly above its subgroup's end marker line `# (end of <subgroup>)`. It never renames or removes a declared tunable.
  - `tools/gen_moves.gd`: each archetype package edits only the body of its own `_<owner>_moves()` function (section 4.7). Regenerating rewrites every `.tres`, but the generator is deterministic and keeps UIDs, so only the package's own `.tres` files change.
  - `tuning/default.json`: regenerated, never hand-edited. `.gitattributes` gives it `merge=keep-ours`; the lead runs `git config merge.keep-ours.driver true` once, and regenerates the file after every merge (the byte test in `test_tuning_panel.gd` catches a stale one).
  - `game/ui/hud.gd`: WP-WARN only in phase 1 (boss bar discovery). Phase 0 already wires the `RearWarning` and `MashPrompt` nodes, so WP-GRAB never touches it.
  - `game/player/player.gd`: P0-A adds the look API; WP-GRAB is its only phase 1 owner; INT-1 owns it in phase 2.
- **Owned**: every other file a package creates or is assigned (section 5 lists them).

### 2.3 Contract amendments (the escape hatch)
A builder that finds a contract gap never edits a frozen file. It:
1. works around it inside its own files when it can (GDScript lets a subclass override `_`-prefixed methods; prefer that to blocking);
2. otherwise records a `contract_requests` entry (file, exact diff, why) in its result and keeps going on the rest.

The lead batches requests into one additive "M3 contract patch N" commit on `m3/enemy-ai`, tags `m3-contracts-N`, and tells affected builders to `git merge m3-contracts-N`. Amendments are additive only (new hook, new tunable, new signal); no signature changes.

### 2.4 Builder common rules (pasted into every builder prompt)
- `cd <absolute worktree path>` before every command. Run `godot --headless --import --quit` first.
- Code rules from CLAUDE.md: static types, tabs, `##` docs on public API, comment density like the surrounding code. **No feel numbers in scripts**: tunables in `tuning_data.gd` (your subgroup only), attack numbers in `tools/gen_moves.gd` (your function only). Layer rules: simulation never reads a camera; presentation subscribes to `CombatEvents` and reads state, never writes it.
- Ownership: edit only your owned files and your sections. Frozen files: section 2.2. Contract gaps: section 2.3.
- Tests: run your new test files with `tools/run_tests.sh -gselect=<file>` while working. Run the **full suite once at the end** (about 90 s now, not 6 s), and read the whole output for `SCRIPT ERROR` and `ERROR`. All tests pass.
- Captures: Movie Maker needs a window, captures the mouse and competes for focus, so **one capture runs at a time across all worktrees**. Always record through `tools/capture_bot.sh` (P0-D), which takes the global lock `/Users/arachne/repos/beat-em-up-PoC/.worktrees/.capture-lock`. Never leave a Godot process running. Write captures only under your worktree's `captures/<key>/` (git-ignored; never commit `captures/`). LOOK at every sheet with the Read tool and say what you saw. Only first-person looks count for Game-boy; side view and F3 are for mechanics.
- Commits: `wip: <key>: ...` every 15-20 minutes, pushed (`git push -u origin <branch>`). Finish with exactly `M3 phase 1: <key> done` (phase 0: `M3 phase 0: <x> done`). Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Docs: don't edit ARCHITECTURE.md or README.md. Write your ARCHITECTURE section into `docs/milestones/M3-notes/<key>.md` (your own file); the lead folds them in during phase 4.
- Decisions: take the default that changes least, never ask Game-boy. Report each decision that shapes what he will play as a judgement call with at least one alternative and why not.
- Result (structured output): `key, branch, head_sha, done, summary, files_changed[], tests {full_suite_pass, count, new_files[]}, captures [{path, act, view, verdict}], acceptance [{criterion, met, evidence}], contract_requests [{file, change, why}], judgement_calls [{decision, alternative, why}], readme_departures [], tunables_added [], open_issues []`.

### 2.5 Usage and handoff
- `mcp__ccd_session_mgmt__get_usage` before every launch; launch only what fits below 90% (HANDOFF "Usage rules"). Concurrency: up to 6 heavy agents under 60% of the window, 2 above.
- Phase 1 runs as one Workflow, `docs/reviews/M3/workflow-build.js` (new, modelled on `workflow-fix.js`): one gated Sonnet builder per package; a package is `done` when its branch has the commit `M3 phase 1: <key> done`, `wip` when the branch exists, `new` otherwise, so **a cut-off run resumes by rerunning the same args**. Save the args as `docs/reviews/M3/args-build.json`.
- HANDOFF at every phase boundary: package states, running workflow ids, exact resume commands.
- Judgement calls from builder results are appended to `docs/milestones/M3-judgement-calls.md` by the lead at merge time (never by builders: it's a shared file).

---

## 3. Contract hot spots, and how each one is defused

| Hot spot | Who would want it | How this plan avoids conflicts |
| --- | --- | --- |
| `game/actors/combat_actor.gd` | armor, enemy grabs (victim and holder hooks), abort, parry vs armor | **P0-A lands every hook** (section 4.3). Frozen in phase 1. Archetype logic lives in `EnemyActor` and archetype files. |
| `game/player/player.gd` | look API, GRABBED control and mash, look lock, held pin, magnetism in a crowd | P0-A adds the look API only. **WP-GRAB is the only phase 1 owner.** INT-1 owns the magnetism changes in phase 2, after WP-GRAB merged. |
| `game/autoload/tuning_data.gd` + `tuning/default.json` + `test_tuning_panel.gd` | every package | **P0-A declares all of M3's ~100 new tunables** in owner-labelled subgroups with end markers, regenerates the preset and updates the subgroup assertion. Phase 1 edits stay inside own subgroup lines; `default.json` merges with `keep-ours` and is regenerated. |
| `game/autoload/combat_events.gd` | armor, grab escape, AI state, tokens, waves, boss phase, weapon drop | **P0-A adds all nine signals** (section 4.2). Frozen. |
| `game/combat/move_data.gd`, `hit_info.gd`, `combat_types.gd` | reach, AI states, armor text | P0-A: `reach_m`, wider `lunge` range, `AIState`, `describe()` armor text. Frozen. |
| `tools/gen_moves.gd`, `game/combat/moves/*.tres`, `tests/test_move_data.gd` | every attack | **P0-A writes all 15 enemy moves' starting data** in six per-owner functions, generates the `.tres`, and makes the folder test accept `EnemyMoveIds.all()`. Phase 1 tunes only its own function. Enemy-move checks live in new per-package test files. |
| `game/actors/placeholder_poses.gd`, `placeholder_anims.gd`, `humanoid_rig.gd` | every recipe, new named anims, the held wind-up | **P0-B** adds `windup_hold_at`, routes unknown move ids and new named ids to `EnemyPoses` (a frozen dispatcher), which calls one pose file per owner. Phase 1 edits only its own pose file. |
| `game/ui/hud.tscn` / `hud.gd` | rear warning, mash prompt, boss bar | **P0-D adds the `RearWarning` and `MashPrompt` nodes and their `advance()` calls.** `hud.tscn` frozen; `hud.gd` WP-WARN only (boss bar). |
| `game/ui/debug_draw.gd` | tokens, slots, ring, view wedge, nav paths | **P0-D adds a child `AiDebugOverlay` node and public line helpers.** WP-DEBUGUI owns only the overlay file. Existing exact line-count tests stay valid (the overlay draws nothing without AI enemies). |
| `game/ui/cheat_menu.gd` | spawn any enemy, AI freeze | WP-DEBUGUI only, reading the frozen `EnemyCatalog`. |
| `game/autoload/game_input.gd`, `help_overlay.gd`, `test_ui.gd` | F6 room switch | **P0-D** adds `switch_room` (F6), its handler, the help row and the "F6" test expectation. Frozen after. |
| `game/level/test_room.gd` | base extraction, navmesh, room switch | **Not touched in M3.** The crowd room uses a new `RoomPresentation` helper; F6 lives in `GameInput`; enemies spawned by F4 in the training room get a lazy `NavBaker.ensure_for()` bake and director. |
| `tests/bot/combo_bot.gd` | crowd bot | P0-D adds `_room_scene()` and `_configure_room()` hooks once. Acts live in one file per package under `tests/bot/acts/`. |
| `project.godot` | `[navigation]` block, main scene | P0-A adds `[navigation]`; the lead switches `run/main_scene` in phase 2. |
| `docs/ARCHITECTURE.md`, `README.md`, judgement log | everyone | Builders write `docs/milestones/M3-notes/<key>.md` and report calls in their result; the lead edits the shared docs. |
| `game/weapons/weapon.gd` | Pipe Thug drop | WP-THUG only. |
| `game/audio/audio_director.gd` | wind-up voice budget, heavy voices | WP-WARN only. |

---

## 4. Phase 0: the contracts

Phase 0a (P0-A) lands the interfaces in one commit series; phase 0b (P0-B, P0-C, P0-D) fills the scaffolds in parallel, against those interfaces. The lead reviews each diff against this section before merging; the full suite must pass after each merge; then the lead adds an "M3 contracts" section to ARCHITECTURE.md (a copy of 4.1-4.9, kept current by later amendments), tags `m3-contracts`, pushes, and updates HANDOFF.

### 4.1 `CombatTypes` additions (`game/combat/combat_types.gd`)

```gdscript
## Behaviour state of an AI enemy (EnemyBrain), an overlay on ActorState: hit reactions,
## wind-ups and attacks still run in CombatActor. Milestone 3, Spec §7 "Behavior states".
enum AIState {
	IDLE,      ## AI off (Tuning.ai_frozen, EnemyActor.ai_enabled false): stands, faces nobody.
	ENTER,     ## Walking in from its spawn point to EnemyActor.enter_target.
	APPROACH,  ## Pathing to its posture slot on the ring.
	POSTURE,   ## On the ring: circle, strafe, taunt; waiting for an attack token.
	ENGAGE,    ## Holds a token; stepping in to its attack's reach.
	WINDUP,    ## Telegraphing (ActorState.WINDUP).
	ATTACK,    ## Active and recovery frames, chain links included.
	RECOVER,   ## A beat after an attack before posturing again.
	REACT,     ## Hitstun, stagger, launched, thrown (CombatActor owns the body).
	DOWN,      ## Downed or getting up.
	HOLD,      ## Holding the player (EnemyHold).
	KO,        ## Knocked out; despawns when gone.
}

static func ai_state_name(s: int) -> String:
	return AIState.keys()[s]
```

### 4.2 `CombatEvents` additions (`game/autoload/combat_events.gd`), appended at the end

```gdscript
## An armored body took a hit without reacting (EnemyActor._apply_armor): damage landed, no
## cancel, no reaction. Also emitted as hit_landed with hit.armor_absorbed = true.
signal armor_absorbed(victim: Node3D, hit: HitInfo)
## A held victim broke free (CombatActor.break_free), before the holder's hit landed.
signal grab_escaped(victim: Node3D, holder: Node3D)
## An AI enemy's behaviour state changed (CombatTypes.AIState).
signal ai_state_changed(enemy: Node3D, old_state: int, new_state: int)
## The director granted (held = true) or took back an attack token.
signal token_changed(enemy: Node3D, held: bool)
## An AI enemy entered the world: tag is the spawn point's (&"doorway", &"alley", &"vehicle"),
## or &"cheat", &"summon", &"bot".
signal enemy_spawned(enemy: Node3D, tag: StringName)
signal wave_started(index: int, ids: PackedStringArray)
signal wave_cleared(index: int)
## The boss crossed into `phase` (2 at boss_phase2_health_frac).
signal boss_phase_changed(boss: Node3D, phase: int)
## A carried weapon fell to the ground (Weapon.drop()); the player can pick it up.
signal weapon_dropped(actor: Node3D, weapon: Node3D)
```

Emitters: `armor_absorbed` and `grab_escaped` by `CombatActor`; `ai_state_changed` by `EnemyBrain`; `token_changed` by `EnemyDirector`; `enemy_spawned` by `WaveSpawner`, `EnemyDirector.summon()`, `CheatMenu` and the bots; `wave_*` by `WaveSpawner`; `boss_phase_changed` by `BossEnemy`; `weapon_dropped` by `Weapon.drop()`.

### 4.3 `CombatActor` hooks (`game/actors/combat_actor.gd`)

All additive; no existing behaviour changes for the player or the dummies.

1. **Armor.** In `receive_hit()`, right after `_flash_at(...)` and before `if current_move: _cancel_move()`:
   ```gdscript
   	_apply_armor(hit)
   	if hit.armor_absorbed and not hit.killed:
   		CombatEvents.armor_absorbed.emit(self, hit)
   		return true
   ```
   ```gdscript
   ## Armor (Spec §7). Called for every unblocked hit after its damage is applied. Set
   ## hit.armor_absorbed to take the damage with no cancel and no reaction; or downgrade
   ## hit.reaction / hit.knockback (a heavy hit that staggers instead of knocking down). A
   ## killing hit is never absorbed. Default: no armor.
   func _apply_armor(_hit: HitInfo) -> void:
   	pass
   ```
2. **Held animation.** `## The looping animation this body plays while held (the player's is upright).` `func _held_anim() -> StringName: return &"held"`. Replace both literal `&"held"` plays (`start_grabbed()` and the knee jolt in `_apply_reaction()`) with `_held_anim()`.
3. **Grabbed notice.** `func _on_grabbed(_by: CombatActor) -> void: pass`, called in `start_grabbed()` right before `CombatEvents.grabbed.emit(...)`. Doc: "Victim side: reset anything a grab cuts short (a move's camera offset, a chain)."
4. **Break free.**
   ```gdscript
   ## Victim side: leave the hold on your feet before the holder's hit lands (the mash, Spec
   ## addition approved by Game-boy). The holder hears it first (_on_hold_broken), then the
   ## body is released with `push` and invulnerable for `invuln_frames` sim frames.
   func break_free(push: Vector3, invuln_frames: int) -> void:
   	var by := holder
   	if by == null or state != CombatTypes.ActorState.GRABBED:
   		return
   	by._on_hold_broken(self)
   	release_from_grab(push, false)
   	_invuln_frames = maxi(_invuln_frames, invuln_frames)
   	CombatEvents.grab_escaped.emit(self, by)

   ## Holder side: `victim` broke free (break_free). Default: nothing.
   func _on_hold_broken(_victim: CombatActor) -> void:
   	pass
   ```
5. **Abort.** `## Stop the running move now and return to neutral (no reaction).` `func abort_move() -> void:` `if current_move: _cancel_move()` then `_return_to_neutral()`.
6. **Parry vs armor.** `## Whether a perfect block staggers this attacker (react_to_block). Default true.` `func _parry_staggers() -> bool: return true`. In `react_to_block()`: `if hit.perfect_block and _parry_staggers():` (the existing branch); a perfect block on an attacker that returns false falls through to the ordinary recoil path.

`tests/test_m3_contracts.gd` (P0-A) covers: an absorbing override keeps a WINDUP running and emits `armor_absorbed` (no `windup_ended`); a killing hit is never absorbed; `break_free()` calls the holder hook, releases on the feet, grants i-frames and emits `grab_escaped`; `_held_anim()` is played on grab; `abort_move()`; `_parry_staggers()` false gives no stagger; the look API below.

### 4.4 `PlayerCharacter` look API (`game/player/player.gd`, a new section near `get_look_basis()`)

```gdscript
## Flat unit vector the player looks along (look_yaw only; pitch ignored). Simulation-safe:
## never the camera. The director's blind spot and the rear warning both read this.
func get_look_forward() -> Vector3:
	return Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))


## Signed flat angle in degrees from the look to `point`: 0 dead ahead, positive to the
## left, +-180 directly behind. Measured from the body's origin, so poses never move it.
func look_bearing_deg(point: Vector3) -> float:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(wrapf(atan2(-to.x, -to.z) - look_yaw, -PI, PI))


## True when `point` lies more than `half_angle_deg` (flat) from the look: out of view.
func is_outside_view(point: Vector3, half_angle_deg: float) -> bool:
	return absf(look_bearing_deg(point)) > half_angle_deg
```
"Out of view" is one number everywhere: `Tuning.data.rear_warning_angle_deg` (55°), read by the director and the warning.

### 4.5 `MoveData` and `HitInfo`
- `move_data.gd`: `## Enemy moves: flat reach in metres from the attacker's origin, including any travel (lunge). The AI steps in to it; the rear warning's "attack range" (Spec §8). 0 for player moves.` `@export_range(0.0, 10.0, 0.05) var reach_m: float = 0.0`. Widen `lunge`'s range to `0.0, 8.0` (the boss charge travels 5 m). For enemy moves `lunge` is the distance the archetype applies with `set_lunge()` from `_on_attack_frame()`, never through `_plan_lunge()`.
- `hit_info.gd` `describe()`: append `" ARMOR"` when `armor_absorbed` (the combat log shows it).

### 4.6 TuningData: every M3 tunable, declared once (P0-A)

Group order after P0-A: ... Camera, **Enemies**, **Enemy archetypes** (new), **Rear warning**, Block, Sparring, Audio, Debug. ("Audio" must stay directly before "Debug": `test_audio.gd:175`.) No name starts with `vfx_`. Every subgroup ends with a marker comment line `# (end of <subgroup>)`. P0-A writes a `##` doc for each (it becomes the F1 tooltip), regenerates `tuning/default.json`, and changes `test_tuning_panel.gd:390` to expect Enemies headings `["Director", "Posture", "Navigation", "Enemy grabs", "Waves"]` and Enemy archetypes headings `["Street Punk", "Kicker", "Pipe Thug", "Bruiser", "Boss"]`.

**Enemies** (no subgroup, existing): `attacker_cap` int 0-6 = 3 (DIR), `blind_spot_priority` 0-1 = 1.0 (DIR), `windup_mult` 0.25-3 = 1.0 (AI; the dummy keeps reading it).

| Subgroup (owner) | Tunables (range = default) |
| --- | --- |
| Director (WP-DIR) | `director_blind_bonus_s` 0-10 = 3.0 (queue head start for an out-of-view enemy, times `blind_spot_priority`); `director_grant_gap_s` 0-2 = 0.35 (min time between two grants); `director_token_max_hold_s` 0.5-10 = 4.0 (an unused token returns); `director_player_hit_grace_s` 0-2 = 0.25 (no grant right after the player is hit); `director_revive_grace_s` 0-5 = 1.5; `director_slot_refresh_s` 0.05-2 = 0.5; `director_slot_hysteresis_deg` 0-90 = 25; `director_spread_min_gap_deg` 0-120 = 35; `director_slot_snap_tolerance_m` 0-2 = 0.6; `director_max_alive` int 1-12 = 6 |
| Posture (WP-AI) | `posture_ring_min_m` 1-8 = 2.5; `posture_ring_max_m` 1-10 = 4.0; `posture_action_min_s` 0.1-5 = 0.6; `posture_action_max_s` 0.1-8 = 1.8; `posture_strafe_step_m` 0-3 = 0.8; `posture_taunt_chance` 0-1 = 0.15; `enemy_attack_cooldown_s` 0-10 = 1.6; `enemy_recover_s` 0-3 = 0.4; `enemy_engage_timeout_s` 0.2-8 = 2.5; `enemy_step_in_margin_m` 0-1 = 0.15; `enemy_windup_turn_rate` 0-10 = 1.2 (rad/s tracking during a wind-up); `enemy_stuck_s` 0.1-5 = 1.0; `enemy_enter_timeout_s` 0.5-10 = 4.0; `windup_min_frames_grunt` int 1-60 = 18; `windup_min_frames_heavy` int 1-120 = 30 |
| Navigation (WP-AI) | `nav_avoid_margin_m` 0-1 = 0.1 (avoidance radius = body radius + this); `nav_neighbor_distance_m` 0.5-20 = 6; `nav_time_horizon_s` 0.05-3 = 0.75; `nav_waypoint_reach_m` 0.25-2 = 0.5; `nav_target_reach_m` 0.25-1.5 = 0.3; `nav_retarget_frames` int 1-60 = 6; `nav_max_speed_mps` 1-20 = 8 |
| Enemy grabs (WP-GRAB) | `grab_break_presses` int 1-40 = 8; `grab_break_decay_per_s` 0-10 = 1.5; `grab_break_push_mps` 0-8 = 3.0; `grab_break_invuln_frames` int 0-60 = 20; `enemy_grab_hold_s` 0.1-4 = 1.0 (held before the hit move starts); `enemy_grab_half_angle_deg` 5-120 = 45; `enemy_grab_range_margin_m` 0-1 = 0.2; `grabbed_turn_frames` int 0-30 = 8; `grabbed_pin_distance_m` 0.3-1.5 = 0.75; `grabbed_view_pitch_deg` -30-30 = 4; `boss_grab_break_mult` 0.5-4 = 1.5 |
| Waves (WP-ROOM) | `wave_first_delay_s` 0-10 = 1.5; `wave_spawn_interval_s` 0.05-3 = 0.4; `wave_gap_s` 0-20 = 3.0; `wave_behind_share` 0-1 = 0.34 |

**Enemy archetypes** (new group):

| Subgroup (owner) | Tunables |
| --- | --- |
| Street Punk (WP-GRUNTS) | `punk_health` 1-300 = 30; `punk_walk_speed` 0.5-8 = 2.6; `punk_circle_speed` 0.2-6 = 1.5; `punk_turn_rate` 0.5-20 = 6; `punk_cross_chance` 0-1 = 0.85; `punk_shove_chance` 0-1 = 0.3; `punk_ring_bias` -1-1 = -0.3 |
| Kicker (WP-GRUNTS) | `kicker_health` = 25; `kicker_walk_speed` = 3.4; `kicker_circle_speed` = 2.6; `kicker_turn_rate` = 8; `kicker_sweep_chance` 0-1 = 0.4; `kicker_sweep_max_range_m` 0.5-3 = 1.4; `kicker_blind_side_bias` 0-1 = 1.0 |
| Pipe Thug (WP-THUG) | `thug_health` = 35; `thug_walk_speed` = 2.4; `thug_circle_speed` = 1.3; `thug_turn_rate` = 5; `thug_chain_chance` 0-1 = 0.8; `thug_drop_speed_mps` 0-8 = 2.0 |
| Bruiser (WP-BRUISER) | `bruiser_health` = 80; `bruiser_body_height_m` 1.6-2.6 = 2.05; `bruiser_body_radius_m` 0.25-0.7 = 0.42; `bruiser_walk_speed` = 1.8; `bruiser_circle_speed` = 0.9; `bruiser_turn_rate` = 3; `bruiser_grab_chance` 0-1 = 0.4; `bruiser_grabbable_when_staggered` bool = true |
| Boss (WP-BOSS) | `boss_health` 50-1000 = 300; `boss_body_height_m` = 2.3; `boss_body_radius_m` = 0.5; `boss_walk_speed` = 2.0; `boss_turn_rate` = 2.5; `boss_phase2_health_frac` 0-1 = 0.5; `boss_phase2_speed_mult` 1-3 = 1.35; `boss_phase2_turn_mult` 1-4 = 1.6; `boss_phase2_windup_mult` 0.5-1 = 0.85; `boss_summon_count` int 0-4 = 2; `boss_charge_min_range_m` 0-8 = 3.0; `boss_pound_chance` 0-1 = 0.35; `boss_grab_chance` 0-1 = 0.35; `boss_token_bonus_s` 0-10 = 2.0 |

Health ranges 1-1000, speeds 0.5-8 m/s, turn rates 0.5-20 rad/s unless shown.

**Rear warning** (existing four, then WP-WARN's): `rear_warning_behind_deg` 0-60 = 20; `rear_warning_range_margin_m` 0-5 = 1.0; `rear_warning_base_px` 40-400 = 170; `rear_warning_inset_px` 0-200 = 48; `rear_warning_heavy_scale` 1-3 = 1.35; `rear_warning_pulses` int 0-6 = 2; `rear_warning_pulse_s` 0.05-1 = 0.15; `rear_warning_pulse_gain` 0-1 = 0.35; `rear_warning_rest_alpha` 0-1 = 0.65; `rear_warning_count_gain` 0-1 = 0.25; `rear_warning_follow_turn` bool = true; `rear_warning_drop_in_view` bool = true. (Rear warning has no subgroups today; WP-WARN appends above `# (end of Rear warning)`.)

**Debug** (skipped by presets): `ai_frozen` bool = false (brains idle, bodies still react), `waves_paused` bool = false.

### 4.7 Enemy move data (P0-A, in `tools/gen_moves.gd`)

`_build_moves()` ends with `_build_enemy_moves()`, which calls, in this order and separated by at least one blank line and a doc line each: `_punk_moves()`, `_kicker_moves()`, `_thug_moves()`, `_bruiser_moves()`, `_boss_moves()`, `_grab_moves()`. Every enemy move sets `magnetism = false`, `free_lunge = 0`, `lunge` as below (travel applied by the archetype), and `reach_m` as below. Name tunable literals as constants at the top of the generator, like `KICK_PITCH_DEG`. The reach values are starting estimates: each archetype package measures its strike point at the active frame (at its body height) and corrects `reach_m` with a test.

| id | owner | S/A/R | dmg | tier | reaction | knockback (x,y,z) | hitboxes | flags | lunge | reach_m |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `punk_jab` | GRUNTS | 22/3/14 | 6 | LIGHT | FLINCH | 0,0,1.5 | RightFistPoint r0.14 | recoil 16 | 0 | 1.05 |
| `punk_cross` | GRUNTS | 8/3/16 | 6 | LIGHT | FLINCH | 0,0,2.0 | LeftFistPoint r0.14 | recoil 16 | 0 | 1.0 |
| `punk_shove` | GRUNTS | 20/3/18 | 6 | LIGHT | STAGGER | 0,0,3.5 | both FistPoints r0.16 | recoil 16 | 0 | 0.95 |
| `kicker_jump_kick` | GRUNTS | 22/6/18 | 8 | HEAVY | STAGGER | 0,0.5,3.0 | RightFootPoint r0.2 | | 1.4 | 2.4 |
| `kicker_sweep` | GRUNTS | 20/5/22 | 8 | HEAVY | KNOCKDOWN | 0,1.0,1.5 | arc r1.3 ±80° height 0-0.5 | | 0 | 1.3 |
| `thug_pipe_1` | THUG | 22/3/14 | 10 | LIGHT | FLINCH | 0,0,1.5 | WeaponTip r0.18 | guard mult 1.5 | 0 | 1.6 |
| `thug_pipe_2` | THUG | 12/3/14 | 10 | LIGHT | FLINCH | 0,0,1.5 | WeaponTip r0.18 | guard mult 1.5 | 0 | 1.6 |
| `thug_pipe_3` | THUG | 14/4/22 | 10 | HEAVY | KNOCKDOWN | 0,1.0,2.5 | WeaponTip r0.2 | guard mult 1.5 | 0 | 1.6 |
| `bruiser_smash` | BRUISER | 34/4/26 | 15 | HEAVY | KNOCKDOWN | 0,1.0,2.5 | both FistPoints r0.22 | recoil 0 | 0 | 1.3 |
| `boss_charge` | BOSS | 32/24/30 | 20 | HEAVY | KNOCKDOWN | 0,1.5,5.0 | arc r1.1 ±35° height 0.5-1.9 | recoil 0 | 5.0 | 6.1 |
| `boss_pound` | BOSS | 36/4/30 | 15 | HEAVY | KNOCKDOWN | 0,2.0,3.0 | arc r2.5 ±180° height 0-0.6 | unblockable, recoil 0 | 0 | 2.5 |
| `bruiser_grab` | GRAB | 32/6/24 | 0 | HEAVY | NONE | 0 | none | unblockable, recoil 0 | 0 | 1.2 |
| `bruiser_headbutt` | GRAB | 20/3/24 | 15 | HEAVY | KNOCKDOWN | 0,1.0,3.0 | none (code-applied) | unblockable, recoil 0 | 0 | 0 |
| `boss_grab` | GRAB | 34/6/26 | 0 | HEAVY | NONE | 0 | none | unblockable, recoil 0 | 0 | 1.4 |
| `boss_slam` | GRAB | 24/3/30 | 25 | HEAVY | KNOCKDOWN | 0,2.5,1.0 | none (code-applied) | unblockable, recoil 0 | 0 | 0 |

No enemy move is FINISHER tier (a FINISHER starts the global slow-mo and impact frame meant for player payoffs). No enemy move has branches, `auto_next` or `repeat_*` (chains are the AI's, `test_finisher_tier_matches_branch_graph` stays valid). Every non-boss KNOCKDOWN does at most 15 damage (SPEC §4).

`game/enemies/enemy_move_ids.gd` (P0-A, frozen):
```gdscript
class_name EnemyMoveIds
extends RefCounted
## Every Milestone 3 enemy move id, by owner (docs/milestones/M3-plan.md, section 4.7).
const PUNK: Array[StringName] = [&"punk_jab", &"punk_cross", &"punk_shove"]
const KICKER: Array[StringName] = [&"kicker_jump_kick", &"kicker_sweep"]
const THUG: Array[StringName] = [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"]
const BRUISER: Array[StringName] = [&"bruiser_smash"]
const BOSS: Array[StringName] = [&"boss_charge", &"boss_pound"]
const GRAB: Array[StringName] = [&"bruiser_grab", &"bruiser_headbutt", &"boss_grab", &"boss_slam"]
## Started with a wind-up (WINDUP, rear warning): the wind-up floors apply.
const OPENERS: Array[StringName] = [&"punk_jab", &"punk_shove", &"kicker_jump_kick", &"kicker_sweep",
		&"thug_pipe_1", &"bruiser_smash", &"bruiser_grab", &"boss_charge", &"boss_pound", &"boss_grab"]
## Chain links: started when the previous move ends, with no new wind-up.
const CHAINS: Dictionary[StringName, StringName] = {&"punk_jab": &"punk_cross",
		&"thug_pipe_1": &"thug_pipe_2", &"thug_pipe_2": &"thug_pipe_3"}
## A grab, and the hit that lands if the player doesn't break free.
const GRAB_HITS: Dictionary[StringName, StringName] = {&"bruiser_grab": &"bruiser_headbutt",
		&"boss_grab": &"boss_slam"}

static func all() -> Array[StringName]: ...      # PUNK + KICKER + THUG + BRUISER + BOSS + GRAB
static func is_heavy(id: StringName) -> bool: ...  # bruiser_* or boss_* (floor windup_min_frames_heavy)
```

P0-A also: `test_move_data.gd`'s `test_moves_folder_holds_only_table_moves` accepts `TABLE` plus `EnemyMoveIds.all()` (count = both sizes); new `tests/test_enemy_moves.gd` checks for every enemy id: the `.tres` exists, `get_anim() == id`, magnetism off, `free_lunge == 0`, no branches, tier not FINISHER, `reach_m > 0` except the two grab hits, openers' startup ≥ the floor (18, or 30 for heavy), chain links in `CHAINS`, grabs and grab hits have no hitboxes and are unblockable, Bruiser and boss moves have recoil 0, non-boss knockdowns ≤ 15 damage.

### 4.8 New class shells (P0-A creates each file with its frozen public signatures, `##` docs and trivial bodies; 0b and phase 1 fill the bodies)

**`EnemyActor`** (`game/enemies/enemy_actor.gd`; bodies by P0-C, then owned by WP-AI)
```gdscript
class_name EnemyActor
extends CombatActor
## Base of every Milestone 3 AI enemy. Brain: EnemyBrain. Holder side of grabs: EnemyHold.
## Archetypes override the "Archetype" virtuals only.

const AI_GROUP := &"ai_enemy"

var archetype: StringName = &""          ## EnemyCatalog id; set in the archetype's _init().
var heavy: bool = false                  ## Bruiser, boss: larger warning, 30-frame floor.
var spawn_tag: StringName = &""          ## &"doorway", &"alley", &"vehicle", &"cheat", &"summon", &"bot".
var enter_target: Vector3 = Vector3.INF  ## Where ENTER walks to (the doorway mouth); INF skips ENTER.
var ai_enabled: bool = true              ## Bots and tests freeze one enemy; Tuning.ai_frozen all.
var ai_state: int = CombatTypes.AIState.ENTER  ## Written only by EnemyBrain.set_state().
var brain: EnemyBrain
var hold: EnemyHold
var nav: NavigationAgent3D

# Archetype virtuals (defaults are grunt-like)
func _archetype_health() -> float
func _walk_speed() -> float
func _circle_speed() -> float
func _turn_rate() -> float
## The opener to start now (EnemyMoveIds.OPENERS), or &"" to keep posturing.
func choose_attack(player: PlayerCharacter, distance: float) -> StringName
## The chain link after `finished` (EnemyMoveIds.CHAINS, gated by a chance), or &"".
func next_in_chain(finished: MoveData, landed: bool) -> StringName
## Per move frame of its own attacks: travel (set_lunge), drops. Not called for grab moves.
func _on_attack_frame(move: MoveData, frame: int) -> void
## Preferred posture bearing in degrees off the player's look (0 front, 180 behind), or NAN.
func slot_bearing_preference() -> float
## Posture action weights: x circle, y strafe, z taunt.
func posture_weights() -> Vector3
## -1 inner edge of the posture ring, +1 outer edge.
func ring_bias() -> float
## Seconds of head start in the director's token queue.
func token_bonus_s() -> float
## Every sim tick, in every state, before the brain (the boss's phase check).
func _tick_archetype() -> void

# Body API (brain, hold, bots, cheats)
func find_player() -> PlayerCharacter
func find_director() -> EnemyDirector
func get_move(id: StringName) -> MoveData          ## Tuning.get_move(id): the shared, F1-edited copy
func windup_move(move: MoveData) -> MoveData      ## startup * windup_mult, floored (grunt 18 / heavy 30), cached per id
func attack_reach(id: StringName) -> float        ## get_move(id).reach_m
func start_attack(id: StringName) -> bool         ## FREE only: zero xz velocity, start_move(windup_move(m), 1, &"root", true)
func abort_attack() -> void                       ## abort_move() for brain timeouts
func drive(desired: Vector3) -> void              ## submit to avoidance; sim_velocity.xz = last safe velocity (direct if no nav map)
func stop() -> void
func face_toward(point: Vector3, rate: float) -> void
func animate_locomotion() -> void                 ## rig.play_locomotion() from sim_velocity in the body frame
func set_nav_target(point: Vector3) -> void       ## snapped to the navmesh once synced
func nav_ready() -> bool                          ## NavigationServer3D.map_get_iteration_id(map) > 0
func place(pos: Vector3, yaw: float) -> void      ## teleport, ghost for one Jolt step, set_velocity_forced(ZERO)
```
Overrides of `CombatActor` written by P0-C (bodies may change in WP-AI; the routing must stay):
- `_ready()`: `team = 1`, `add_to_group(&"enemy")` and `AI_GROUP`, `max_health = _archetype_health()` before `super._ready()`; `hold = EnemyHold.new(self)`, `brain = EnemyBrain.new(self)`; create and configure `nav` from the Navigation subgroup (`avoidance_enabled = true`, `radius = body_radius + nav_avoid_margin_m`, `height = body_height`, `max_speed`, reaches, neighbour distance, time horizon), connect `velocity_computed` to store `_safe_velocity` (the latched pattern: never move in the callback); register with `find_director()`; connect `Tuning.changed` (health share kept, nav values re-applied, scaled-move cache dropped on `&""`, `windup_*` and `moves/<id>/...`); seed `_rng` from `name`.
- `_tick_control()`: `_tick_archetype()`, then `if hold.is_holding(): hold.tick(); return`, then `brain.tick()`.
- `_on_move_frame(move, frame)`: `hold.on_move_frame()` for `hold.owns_move(move)`, else `_on_attack_frame()`.
- `_on_move_finished(move)`: grab moves go to `hold.on_move_finished()`; otherwise `next_in_chain()`, and if it returns an id, `start_move(get_move(id), move_chain_step + 1, &"chain", false)` (no wind-up); else `_return_to_neutral()` and `brain.on_attack_finished(move)`.
- `_on_hit_received(hit)`: `hold.on_holder_hit(hit)`, then `brain.on_hit(hit)`.
- `_on_hold_broken(victim)`: `hold.on_broken(victim)`.
- `_plan_lunge(_move)`: no planned lunge (enemy travel comes from `_on_attack_frame()`).
- `_tick_ko()`: once `is_gone()`: release the token, unregister, leave the groups `enemy`, `actor`, `ai_enemy`, then `queue_free()`.
- `debug_state_text()`: base text plus `brain.debug_text()` (one short line, e.g. `AI POSTURE TOKEN blind`).

**`EnemyBrain`** (`game/enemies/enemy_brain.gd`; naive body by P0-C, owned by WP-AI)
```gdscript
class_name EnemyBrain
extends RefCounted
func _init(enemy: EnemyActor) -> void
func tick() -> void                              ## once per sim tick from EnemyActor._tick_control()
func on_attack_finished(move: MoveData) -> void
func on_hit(hit: HitInfo) -> void
func set_state(s: int) -> void                   ## writes enemy.ai_state, emits ai_state_changed
func has_token() -> bool
func reset() -> void
func debug_text() -> String
```

**`EnemyHold`** (`game/enemies/enemy_hold.gd`; stub by P0-A (grabs whiff), owned by WP-GRAB)
```gdscript
class_name EnemyHold
extends RefCounted
func _init(enemy: EnemyActor) -> void
func owns_move(move: MoveData) -> bool           ## EnemyMoveIds.GRAB
func on_move_frame(move: MoveData, frame: int) -> void
func on_move_finished(move: MoveData) -> void
func is_holding() -> bool
func held() -> CombatActor
func tick() -> void
func on_holder_hit(hit: HitInfo) -> void
func on_broken(victim: CombatActor) -> void
func break_presses() -> int                      ## presses the held player needs (per grabber)
func release(push: Vector3) -> void
```

**`EnemyDirector`** (`game/enemies/director/enemy_director.gd`; naive body by P0-C, owned by WP-DIR)
```gdscript
class_name EnemyDirector
extends Node
const GROUP := &"enemy_director"
static func find(tree: SceneTree) -> EnemyDirector
static func ensure_in(root: Node) -> EnemyDirector      ## adds one under root if none exists
func register(enemy: EnemyActor) -> void
func unregister(enemy: EnemyActor) -> void
func enemies() -> Array[EnemyActor]
func alive_count() -> int                               ## health > 0 and not gone (a killing blow counts as dead)
func can_spawn(count: int = 1) -> bool
func request_token(enemy: EnemyActor) -> bool
func release_token(enemy: EnemyActor) -> void
func holds_token(enemy: EnemyActor) -> bool
func is_blind(enemy: EnemyActor) -> bool                ## player.is_outside_view(..., rear_warning_angle_deg)
func slot_for(enemy: EnemyActor) -> Vector3             ## posture slot (world), Vector3.INF if none
func summon(id: StringName, count: int, near: Vector3) -> Array[EnemyActor]
func set_spawner(spawner: WaveSpawner) -> void
func debug_token_holders() -> Array[EnemyActor]
func debug_slot_of(enemy: EnemyActor) -> Vector3
func debug_ring() -> Vector2
func attacker_cap() -> int
```
The director runs its timers in `_physics_process` on `delta * TimeController.sim_scale()`; it never starts moves (the brain does, from `_tick_control()`).

**Room and navigation** (bodies by P0-C, owned by WP-ROOM)
```gdscript
class_name NavBakeSettings extends Resource       ## @export cell_size 0.25, cell_height 0.1, agent_radius 0.5,
                                                  ## agent_height 1.8, agent_max_climb 0.2, roof_max_y 0.5 (layout numbers)
class_name NavBaker extends RefCounted
static func bake(geometry_root: Node3D, parent: Node, settings: NavBakeSettings, filter_aabb := AABB()) -> NavigationRegion3D
static func ensure_for(world: Node3D) -> void     ## bake once if no node in group "nav_region"; add the player obstacle
static func add_player_obstacle(player: PlayerCharacter) -> void
static func map_ready(node: Node3D) -> bool
static func snap(node: Node3D, point: Vector3) -> Vector3   ## closest navmesh point, or `point` before the sync
class_name SpawnPoint extends Marker3D            ## @export tag: StringName; @export enter_offset: Vector3; group "spawn_point"
class_name WaveSpawner extends Node
@export var waves: Array[PackedStringArray]
var enabled: bool
func spawn(id: StringName, point: SpawnPoint) -> EnemyActor
func spawn_at(id: StringName, pos: Vector3, yaw: float, tag: StringName) -> EnemyActor
func pick_points(count: int) -> Array[SpawnPoint]
func current_wave() -> int
func alive_from_waves() -> int
```

**Presentation shells** (stubs by P0-A/P0-D)
```gdscript
class_name RearWarning extends Control            ## owned by WP-WARN
signal shown(side: StringName, count: int)        ## &"left" / &"right"
signal hidden(side: StringName)
func advance(delta: float) -> void
func corner_count(side: StringName) -> int
func corner_rect(side: StringName) -> Rect2       ## drawn rect, canvas px; empty when hidden
func corner_alpha(side: StringName) -> float
func active_attackers() -> Array[Node3D]
class_name MashPrompt extends Control             ## owned by WP-GRAB
func advance(delta: float) -> void
func is_showing() -> bool
class_name AiDebugOverlay extends Node            ## owned by WP-DEBUGUI; child of DebugDraw
func append_lines(draw: CombatDebugDraw) -> void  ## adds nothing when no EnemyActor or director exists
```

**`EnemyCatalog`** (`game/enemies/enemy_catalog.gd`, P0-A, frozen): ids `dummy`, `punk`, `kicker`, `thug`, `bruiser`, `boss`, with labels ("Training dummy", "Street Punk", "Kicker", "Pipe Thug", "Bruiser", "Boss (placeholder)"), scene paths (`game/enemies/dummy/training_dummy.tscn`, `game/enemies/<id>/<id>.tscn`) and `ai` flags. `static func ids()`, `label(id)`, `scene_path(id)`, `is_ai(id)`, `exists(id)` (guards with `ResourceLoader.exists()`), `instantiate(id, node_name) -> CombatActor`.

### 4.8b P0-A's deliverables, in one list (`.worktrees/m3-p0-core`, branch `m3/p0-core` from `m3/enemy-ai`)
1. 4.1 `CombatTypes.AIState`; 4.2 the nine signals; 4.3 the six `CombatActor` hooks; 4.4 the player's look API; 4.5 `reach_m`, the wider `lunge` range, the ARMOR text.
2. 4.6 every tunable with docs and end markers; regenerate `tuning/default.json`; update `test_tuning_panel.gd:390`.
3. 4.7 `_build_enemy_moves()` and the six owner functions with the table's data; run the generator (check the "wrote N moves" line); commit the 15 new `.tres`; `EnemyMoveIds`; the folder test change; `tests/test_enemy_moves.gd`.
4. 4.8 every new class file with its frozen signatures and trivial bodies (`EnemyActor`, `EnemyBrain`, `EnemyHold`, `EnemyDirector`, `NavBaker`, `NavBakeSettings`, `SpawnPoint`, `WaveSpawner`, `RearWarning`, `MashPrompt`, `AiDebugOverlay`) plus the complete `EnemyCatalog`, so P0-B, P0-C and P0-D compile against them in parallel (`test_scripts_compile.gd` loads every script).
5. `project.godot`: the `[navigation]` block from the navigation codemap section 0 (`3d/default_cell_height=0.1`, `avoidance/thread_model/avoidance_use_multiple_threads=false`, `world/map_use_async_iterations=false`, `world/region_use_async_iterations=false`). `.gitattributes`: `tuning/default.json merge=keep-ours`.
6. `tests/test_m3_contracts.gd` (4.3, 4.4). Full suite passes. Commit `M3 phase 0: core done`.

### 4.9 Phase 0b scaffolds (what each of B, C, D must deliver)

**P0-B, rig and pose scaffold** (worktree `.worktrees/m3-p0-rig`, branch `m3/p0-rig`)
1. `MovePoses.windup_hold_at: float = -1.0` (`placeholder_poses.gd:30-67`), mirrored in `mirrored()`, keyed in `build_move()` as a second wind-up key at `windup_hold_at * startup` (holds the threat, then the strike comes over the last frames). Test in a new `tests/test_windup_hold.gd`: key present, player moves unchanged (every existing rig test passes).
2. `game/actors/enemy_poses.gd` (`class_name EnemyPoses`, frozen after): `static func recipe(id, g, wg) -> PlaceholderPoses.MovePoses` dispatching by `EnemyMoveIds` list to `PunkPoses`, `KickerPoses`, `ThugPoses`, `BruiserPoses`, `BossPoses`, `GrabPoses`; `static func has_recipe(id) -> bool`; `static func named(id: StringName, g, scale) -> Dictionary` (`{length, keys, loop}` or empty) dispatching the new named ids.
3. `PlaceholderPoses._recipe()`: replace the final `return null` with `return EnemyPoses.recipe(id, g, wg)`. `PlaceholderAnims.build_named()`: before the unknown-id fallback, try `EnemyPoses.named()`. `HumanoidRig.has_anim()`: also `EnemyPoses.has_recipe(anim)`.
4. New named ids in `ANIM_IDS`: `taunt` (owner WP-AI, file `game/enemies/shared/common_poses.gd`), `brace` (WP-BRUISER), `run_forward` (WP-BOSS; in `LOOPING`), `hold_collar`, `held_collar` (both `LOOPING`), `held_lift` (WP-GRAB, `game/enemies/shared/grab_poses.gd`).
5. Stub pose files, each with its own `class_name` and `static func recipe()` / `named()`: `game/enemies/punk/punk_poses.gd`, `kicker/kicker_poses.gd`, `thug/thug_poses.gd`, `bruiser/bruiser_poses.gd`, `boss/boss_poses.gd`, `shared/grab_poses.gd`, `shared/common_poses.gd`. Stubs reuse the nearest player recipe with a `_dummy_jab`-style wind-up (`windup_at` 0.5): punches from `_dummy_jab`/`_jab_1`, the shove from `_shove`, kicks from `_front_kick`, the sweep from `_spinning_heel`, pipes from `_pipe_swing_1..3(wg)`, the smash from `_dummy_jab`, the charge from `_shove`, the pound from `_stomp`, grabs from `grab_reach`, the headbutt and slam from `hold()`. Named stubs hold the stance (hold poses from `hold()`/`held()`).
6. Optional, only if it stays small and every rig test passes: a static cache of the named `AnimationLibrary` per (scale, stance) in `HumanoidRig._build_animation()` (rig builds cost about 10 ms each; six spawned together hitch). Otherwise skip; WP-ROOM staggers spawns anyway.
7. `tests/test_enemy_recipes.gd`: every `EnemyMoveIds.all()` id has a recipe that isn't the generic fallback (no `push_warning`), its clip length equals `total_frames()/60`, it returns to guard, and its wind-up key sits in 40-60% of startup; every new named id builds with bone tracks.

**P0-C, enemy body and room scaffold** (`.worktrees/m3-p0-enemy`, `m3/p0-enemy`)
1. `EnemyActor` bodies, as 4.8 says, ported from `TrainingDummy` helpers (`_turn_toward`, `_walk`, the wind-up cache, `set_post`'s ghost-step teleport) and the navigation codemap's latched pattern. Direct steering when the nav map isn't synced or has no region (training room, first 2-3 frames).
2. Naive `EnemyBrain`: ENTER (walk to `enter_target`) → APPROACH (`set_nav_target(director.slot_for(self))`) → POSTURE (face the player, idle) → when `director.request_token()` and `choose_attack()` returns an id: ENGAGE (step in to `attack_reach - enemy_step_in_margin_m`) → `start_attack()` → WINDUP/ATTACK → RECOVER → POSTURE; REACT/DOWN/KO from `CombatActor.state`; release the token on finish, hit, KO. Honours `ai_enabled` and `Tuning.ai_frozen` (IDLE).
3. Naive `EnemyDirector`: grant while holders < cap (0 = unlimited) and the player can be hit; slot = the enemy's current bearing at the ring's middle radius; register/unregister; alive count by `health > 0`; `summon()` via `spawner` or a ring spot near `near`.
4. Archetype scripts and scenes, stubs: `game/enemies/punk/punk.gd` (`PunkEnemy`), `kicker/kicker.gd` (`KickerEnemy`), `thug/thug.gd` (`ThugEnemy`), `bruiser/bruiser.gd` (`BruiserEnemy`), `boss/boss.gd` (`BossEnemy`) plus a `.tscn` each (a bare `CharacterBody3D` with the script, like `training_dummy.tscn`). Each sets `archetype`, `heavy`, body size from its Tuning subgroup, distinct graybox colours (no red: red is reserved; 4-6 colours per rig) and display names, reads its health/speeds from Tuning, and `choose_attack()` returns its first opener when in reach. The boss joins group `"boss"`. The thug spawns with a pipe (`Weapon.attach_to`).
5. `NavBaker` and `NavBakeSettings` per the navigation codemap section 0 (parse `STATIC_COLLIDERS` on `LAYER_WORLD` from a geometry root, synchronous bake, roof post-filter, region assigned before `add_child`, group `"nav_region"`), `add_player_obstacle()` (`NavigationObstacle3D`, radius 0.5, as a player child), `ensure_for()`.
6. `RoomPresentation.build(room)` (`game/level/room_presentation.gd`): the same nodes, in the same order, as `test_room.gd:_build_presentation()`, all direct children of the room (`test_room.gd` itself is not touched).
7. Crowd room skeleton `game/level/crowd_room.gd` (`class_name CrowdRoom`) + `.tscn`: exports `with_presentation`, `waves_enabled`, `player_start` (-3, 0, 0), `player_yaw_deg` -90, lane 30 x 12 m on +X (building fronts on -Z, a low curb on +Z, as the test room, so side view and the KO view behave), a `Geometry` node holding every world box, two doorway recesses, alley gaps at both ends, one parked vehicle; six `SpawnPoint`s; the bake; the player (`auto_revive = true`, rotation set before `add_child`, obstacle); `EnemyDirector.ensure_in(self)`; a `WaveSpawner` with `spawn()`/`spawn_at()` working and no waves yet; `RoomPresentation.build(self)`. Exposes `player`, `player_start`, `player_yaw_deg`, `director`, `spawner`, `enemies()`.
8. `project.godot` is not touched here (P0-A added `[navigation]`).
9. `tests/test_enemy_scaffold.gd`: each catalog id spawns in the crowd room, joins `enemy`/`ai_enemy`, has its archetype health, and walks to the ring within N frames; `start_attack()` emits `windup_started` with the floored startup; a chain link starts with no `windup_started`; a gone enemy frees itself and leaves its groups the same frame; the navmesh has polygons and none above the roof cut; `place()` doesn't shove the player; avoidance keeps two enemies ≥ 0.7 m apart over 300 frames.

**P0-D, UI, input and bot scaffold** (`.worktrees/m3-p0-ui`, `m3/p0-ui`)
1. `hud.tscn`: two new full-rect, `mouse_filter = 2` nodes, `RearWarning` (ext id `12_rear`) and `MashPrompt` (`13_mash`), with their scripts. `hud.gd`: `@onready` vars; `advance()` calls `rear_warning.advance(game_delta)` and `mash_prompt.advance(game_delta)`. Both stubs no-op and tolerate a missing player (HUD tests build the HUD with only a camera).
2. `debug_draw.tscn`: a child `AiDebugOverlay` node; `debug_draw.gd`: `rebuild()` calls `_ai_overlay.append_lines(self)` after the actor loop; public helpers `add_debug_line(from, to, color)`, `add_debug_circle(center, radius, color, segments)`, `add_debug_ring(center, radius, color)` wrapping the private ones. The stub overlay adds nothing, so every exact line-count test still passes.
3. `GameInput`: `&"switch_room": [KEY_F6]`; on press: unpause, `TimeController.clear()`, `change_scene_to_file()` to the other room (`const CROWD_ROOM_SCENE`, `TRAINING_ROOM_SCENE`). `HelpOverlay.DEBUG_ROWS`: `["Crowd room / training room", &"switch_room"]`. `test_ui.gd`: add "F6" to the expected help texts; check the help panel still clears the top corners.
4. `combo_bot.gd`: `room = _room_scene().instantiate()` with `func _room_scene() -> PackedScene: return ROOM`, and `_configure_room(room)` called before `add_child` (default: nothing).
5. `tests/bot/crowd_bot.gd` + `.tscn` (frozen after): extends `combo_bot.gd`; room = crowd room with `waves_enabled = false`; act table assembled from `tests/bot/acts/*_acts.gd` (`static func acts(bot: Node) -> Array[Dictionary]`, one stub file per phase 1 package: `ai`, `dir`, `room`, `grab`, `warn`, `debugui`, `grunts`, `thug`, `bruiser`, `boss`, plus `proof` for INT-2); helpers `spawn_enemy(id, rel: Vector3, frozen := true) -> EnemyActor` (player frame: x right, -z ahead; faces the player), `force_attack(enemy, id)`, `set_god_mode(on)`, `look_bearing(deg, ticks)`; a log of `windup_started/ended`, `token_changed`, `ai_state_changed`, `grabbed`/`released`/`grab_escaped`, `armor_absorbed`, `wave_*`, `enemy_spawned`, `boss_phase_changed` and `RearWarning.shown/hidden`, each line with the physics frame (`WARN L 1 f1234`, `TOKEN Punk2 +`, ...). Short captions (the top-right corner must stay clear).
6. `tools/capture_bot.sh <bot> <out dir> [act filter] [stills fps]`: takes the global lock (`mkdir` spin on `.worktrees/.capture-lock`, removed by `trap` on exit), runs Movie Maker 1280x720 at fixed 60 fps, writes `<out>/<bot>.avi`, `<out>/<bot>.log` and tiled stills. Never touches `captures/combos.*`.
7. `tests/test_bots_compile.gd`: loads every `res://tests/bot/**/*.gd`.

### 4.10 Phase 0 gate (the lead, before tagging)
- Full suite passes, no `SCRIPT ERROR` or `ERROR` (the bake runs after `add_child`; no map query before the sync).
- `godot --path . res://game/level/crowd_room.tscn` shows the lane, F4 still spawns a dummy, F6 switches rooms.
- One crowd_bot smoke act (`tools/capture_bot.sh crowd_bot captures/p0 "smoke"`): six stub enemies walk in and stand on a ring; the lead looks at the sheet.
- Every signature in 4.1-4.8 matches this plan. ARCHITECTURE "M3 contracts" written. Tag `m3-contracts`, push, HANDOFF.

Sizes: P0-A ≈ M2 phase-3 builder B plus half (data and declarations, little logic); P0-B ≈ phase-3 B; P0-C ≈ WP4 (the largest scaffold); P0-D ≈ half of B.

---

## 5. Phase 1: the ten packages

All branch from `m3-contracts`. Every package reads section 2.4 first. "Consumes" lists only contracts from section 4.

### WP-AI: enemy behaviour (`.worktrees/m3-ai`, `m3/wp-ai`). Size: WP4.
**Goal.** Spec §7's behaviour states as a readable, deterministic brain, with navigation, for every archetype.
**Owned.** `game/enemies/enemy_actor.gd` (bodies; signatures frozen), `game/enemies/enemy_brain.gd`, `game/enemies/shared/common_poses.gd` (`taunt`), the Posture and Navigation subgroups, `tests/test_enemy_ai.gd`, `tests/bot/acts/ai_acts.gd`, `docs/milestones/M3-notes/ai.md`.
**Consumes.** `EnemyDirector` API (the naive director until WP-DIR merges), `EnemyHold.is_holding()`, archetype virtuals, `CombatTypes.AIState`, `ai_state_changed`, the look API, `MoveData.reach_m`.
**Build.**
- States per 4.1. Act only in `ActorState.FREE` (every other state belongs to `CombatActor`); in WINDUP turn toward the player at `enemy_windup_turn_rate` only (a sidestep or dodge escapes). Map `CombatActor` states to REACT/DOWN/KO/HOLD every tick; resume APPROACH after a reaction ends.
- ENTER: walk to `enter_target` ignoring tokens; APPROACH after arrival or `enemy_enter_timeout_s`.
- APPROACH/POSTURE: target `director.slot_for(self)`, re-target every `nav_retarget_frames` (staggered by instance), flat XZ distances only (the navmesh floats 0.2 m). POSTURE actions every `posture_action_min_s..max_s` (seeded `_rng`), weighted by `posture_weights()`: **circle** (follow the slot as it moves along the ring, strafing animation while facing the player), **strafe** (a `posture_strafe_step_m` side-step left or right of the slot), **taunt** (`rig.play(&"taunt")` standing, then back to locomotion; non-looping anims hold their last pose). Always face the player in posture. No-progress for `enemy_stuck_s` → ask the director for a new slot.
- Tokens: in POSTURE, after `enemy_attack_cooldown_s` since the last attack, `request_token()` each tick until granted. ENGAGE: path to within `attack_reach(id) - enemy_step_in_margin_m` of the player (id from `choose_attack()` at grant time), then `start_attack(id)`; give the token back after `enemy_engage_timeout_s`. Release on `on_attack_finished`, `on_hit` (an interrupted wind-up), KO, `ai_enabled` false, and when the player becomes unhittable.
- RECOVER for `enemy_recover_s`, then POSTURE.
- Avoidance: off (`avoidance_layers = 0`) while ghosted (downed, KO, held); report real knockback velocity to the agent in reaction states (latched pattern). `place()` and `reset_state()` force the agent velocity to zero.
- Wind-up cache: `windup_move()` returns a cached duplicate with `startup = max(floor, round(startup × windup_mult))`, the floor being `windup_min_frames_heavy` if `heavy` else `windup_min_frames_grunt`; openers only (chain links keep their authored startup); the cache drops on the Tuning changes listed in 4.8.
- Default armor for grunts is none, so any accepted hit (a light one included) cancels a grunt wind-up: assert it.
- `debug_state_text()`: `AI <STATE>` plus `TOKEN` and `blind` when true; at most one extra line.
- Author `taunt` in `common_poses.gd` (about 1.0-1.2 s, beckon or chest-thump, from the boxer guard back to it, upper arms ≤ 140° so a stagger's ragdoll doesn't snap, G7).
**Tests** (`test_enemy_ai.gd`, a test-only `EnemyActor` subclass using `punk_jab`, crowd room without presentation): ENTER → APPROACH → POSTURE path; stays between ring min and max; faces the player in posture; never acts outside FREE; WINDUP length = floored startup (18 grunt, 30 heavy, with `windup_mult` 0.25); a jab interrupts a grunt wind-up (`windup_ended(true)`, token released); recovery returns to POSTURE; get-up then APPROACH; KO frees the node and its token; `ai_frozen` → IDLE; determinism: two identical seeded runs give identical positions after 600 frames; with the naive director, three enemies attack in turn, never more than the cap at once.
**Captures** (`ai_acts.gd`): "AI: three Punks posture" (FP, the player turns slowly 360°: circling, strafing, a taunt, no one walks into the lens); "AI: wind-up, attack, recover" (FP, one Punk); "AI: hit out of a wind-up" (FP); side view of the same for mechanics. Judge: posture distance reads as 2.5-4 m in FP; tells are visible; no jitter or sliding through a wind-up.
**Acceptance.** All states reachable and logged by `ai_state_changed`; no enemy stuck more than 2 s in a 1200-frame 6-enemy soak; min pair distance ≥ 0.7 m standing; suite passes.

### WP-DIR: the director (`.worktrees/m3-dir`, `m3/wp-dir`). Size: two thirds of WP4.
**Goal.** Spec §7 director rules: tokens with a cap, blind-spot priority, spread, alive cap, summons.
**Owned.** `game/enemies/director/enemy_director.gd` (bodies), the Director subgroup, `tests/test_director.gd`, `tests/bot/acts/dir_acts.gd`, `docs/milestones/M3-notes/dir.md`.
**Consumes.** `EnemyActor` (positions, `heavy`, `archetype`, `slot_bearing_preference()`, `ring_bias()`, `token_bonus_s()`, `health`, `is_gone()`), `PlayerCharacter.is_outside_view()`, `can_be_hit_by()`, `state`, `NavBaker.snap()`/`map_ready()`, `WaveSpawner.spawn()`/`pick_points()`, `EnemyCatalog`, `token_changed`, `enemy_spawned`.
**Build.**
- **Tokens.** Holders ≤ `attacker_cap` (0 = unlimited). Requests queue; each tick (sim time) grant to the best-scoring requester if: a slot is free, `director_grant_gap_s` passed since the last grant, the player can be hit (not KO, downed, flying, invulnerable, or GRABBED by anyone), `director_player_hit_grace_s` passed since the player was last hit and `director_revive_grace_s` since `revived`. Score = seconds waiting + `token_bonus_s()` + (`blind_spot_priority` × `director_blind_bonus_s` when `is_blind()`). Ties by instance id (deterministic). Auto-release on unregister, health ≤ 0, gone, held for `director_token_max_hold_s` without a wind-up, or the player grabbed by someone else (holders not yet in WINDUP). Emit `token_changed` on every change.
- **Slots (spread).** Every `director_slot_refresh_s`: for the N enemies in APPROACH/POSTURE/ENGAGE/RECOVER, spread target bearings evenly around the player in **world** angles (not look-relative, so turning in place doesn't send everyone running), rotated to minimise total movement from the enemies' current bearings, keep an existing assignment unless a better one beats it by `director_slot_hysteresis_deg`; enforce `director_spread_min_gap_deg`. Preferences: an enemy with `slot_bearing_preference()` (the Kicker's 180) gets the free slot closest to `look_yaw + preference`, re-evaluated against the current look each refresh (so a Kicker keeps circling to the blind side as the player turns). Radius = ring min..max by `ring_bias()`. Snap with `NavBaker.snap()` once the map is ready; reject a slot whose snap moved it more than `director_slot_snap_tolerance_m` and try ±15° steps; fall back to the enemy's own position.
- **Alive cap.** `can_spawn(n)`: `alive_count() + n <= director_max_alive`. Cheat spawns are registered and count for tokens; the wave spawner counts only its own waves (WP-ROOM).
- **Summon.** `summon(id, count, near)`: as many as `can_spawn` allows, from `spawner.pick_points()` if a spawner is set, else ring spots 3-4 m from `near` snapped to the navmesh; `enemy_spawned(e, &"summon")`.
- Debug read API per 4.8.
**Tests** (`test_director.gd`, crowd room without presentation, enemies with `ai_enabled = false` placed by `place()`): cap 3 → at most 3 holders; cap 0 → all; a blind enemy that asked later beats an in-view one with priority 1.0, and not with 0.0; grant gap honoured; no grants while the player is KO, in get-up i-frames or held; token returns on KO, unregister and timeout; six enemies' slots keep ≥ `director_spread_min_gap_deg` and lie in the ring; turning the player 90° in place leaves non-Kicker slots within the hysteresis; a Kicker slot lands within 45° of directly behind the look; slots never inside the vehicle (snap check); `alive_count()` drops at the killing blow (LAUNCHED with health 0); `summon()` respects the cap.
**Captures** (`dir_acts.gd`): "Director: six spread" (free-fly from above, then FP turning 360°), "Director: blind side first" (FP: two enemies, one behind; the one behind winds up first).
**Acceptance.** Token invariants hold through a 1200-frame 6-enemy soak (log check: never more than the cap holding at once); spread visible in the overhead sheet.

### WP-ROOM: crowd room, waves, navmesh (`.worktrees/m3-room`, `m3/wp-room`). Size: two thirds of WP4.
**Goal.** Game-boy's crowd room: a 12 x 30 m street lane with doorway, alley and vehicle spawns (some behind the player), repeating mixed waves of up to 6, auto-revive, playable as the main scene.
**Owned.** `game/level/crowd_room.gd`/`.tscn`, `game/level/nav_baker.gd`, `nav_bake_settings.gd`, `spawn_point.gd`, `room_presentation.gd`, `game/enemies/director/wave_spawner.gd`, the Waves subgroup, `tests/test_crowd_room.gd`, `tests/test_nav_baker.gd`, `tests/test_waves.gd`, `tests/bot/acts/room_acts.gd`, `docs/milestones/M3-notes/room.md`.
**Consumes.** `EnemyCatalog`, `EnemyActor.place()`, `enter_target`, `spawn_tag`, `EnemyDirector.can_spawn()`/`set_spawner()`, the `wave_*`/`enemy_spawned` signals.
**Build.**
- Geometry (layout `@export`s, not Tuning): lane x -15..15, z -6..6; building fronts on -Z with two doorway recesses 2.5 m wide, 1.5 m deep (x ≈ -7 and +5); alley gaps 3 m wide in both end walls leading into 6 m alleys; a parked van (about 4.2 x 1.9 x 1.9 m) near the +Z curb with room behind it; two crates. Every world box under `Geometry`. Floor margin trimmed (no navmesh islands outside the walls: `filter_baking_aabb` on X/Z only, the full obstacle height kept, codemap G7). Doorways ≥ 1.5 m after erosion.
- Spawn points (six): two doorways (`doorway`), two alley ends (`alley`), behind the van (`vehicle`), a stairwell niche or second vehicle (`vehicle`). Each has `enter_offset` to its mouth; all reachable on the navmesh.
- `WaveSpawner`: waves as level data (`@export var waves: Array[PackedStringArray]`), default cycle `[punk, punk]`, `[punk, kicker, punk]`, `[punk, kicker, thug, punk]`, `[bruiser, punk, kicker, thug]`, `[punk, punk, kicker, thug, bruiser, kicker]`, `[boss]`, then repeat. Next wave when its own enemies are all dead (`health <= 0`) plus `wave_gap_s`. Spawn one enemy per `wave_spawn_interval_s` (rig builds cost ~10 ms each), only while `director.can_spawn()`. `pick_points()` puts at least `wave_behind_share` of a wave on spawn points behind the player's look (`look_bearing_deg` > 90° in magnitude) when any exist, never a point within 2 m of the player, and spreads the rest. Names `Punk3` etc. and `display_name` "Punk 3" set before `add_child` (seed, combat log, voice pitch). Respects `waves_enabled` and `Tuning.waves_paused`. Emits `wave_started`, `wave_cleared`, `enemy_spawned`.
- The room: `with_presentation`, `waves_enabled`, seed export for every RNG; player auto-revive; `NavBaker.add_player_obstacle()`; `director.set_spawner(spawner)`; map sync guard (no `map_get_*` before `map_ready()`).
**Tests.** Bake: polygons > 0, none above the roof cut, no vertex outside the walls, every spawn point has a non-empty path to the lane centre; waves: composition order and repeat; never more than 6 alive; at least one of a 3-plus wave spawns behind the look when a rear point exists; deterministic spawn order with a seed; F4/bot-spawned enemies don't stall the waves; F6 round trip keeps `TimeController` clear.
**Captures** (`room_acts.gd`): "Room: wave 3 arrives" (FP, then free-fly overview): enemies walk out of doorways and alleys, some from behind. Judge: entries read; nobody pops into view inside the lane.
**Acceptance.** `godot --path . res://game/level/crowd_room.tscn` plays repeating waves; spawn hitch not visible in the sheet; suite passes.

### WP-GRAB: enemies grab the player (`.worktrees/m3-grab`, `m3/wp-grab`). Size: WP4.
**Goal.** Game-boy's rule: a telegraphed grab wind-up (a dodge or a heavy hit gets out), mash P/K to break free, unbroken the hit lands. For the Bruiser (grab + headbutt) and the boss (grab + slam).
**Owned.** `game/enemies/enemy_hold.gd`, `game/enemies/shared/grab_poses.gd`, `game/ui/mash_prompt.gd`, `game/player/player.gd` (the only phase 1 owner), `_grab_moves()` in `gen_moves.gd` and its four `.tres`, the Enemy grabs subgroup, `tests/test_enemy_grabs.gd`, `tests/test_grabbed_view.gd`, `tests/bot/acts/grab_acts.gd`, `docs/milestones/M3-notes/grab.md`.
**Consumes.** `break_free()`, `_on_hold_broken()`, `_on_grabbed()`, `_held_anim()`, `_pin_spot()` (overridable), `EnemyMoveIds.GRAB_HITS`, `EnemyActor` body API, `grab_escaped`.
**Build.**
- **Connect.** In `on_move_frame()` of `bruiser_grab`/`boss_grab`, on each active frame: the player within `reach_m + enemy_grab_range_margin_m` (flat) and `enemy_grab_half_angle_deg` of the grabber's facing, and `player.can_be_grabbed()` (false in a dodge, the air, get-up i-frames, while holding an enemy): `player.start_grabbed(enemy)`, then the enemy aborts the grab move, enters GRABBING (`_enter_state`), plays `hold_collar`, sets `process_physics_priority` below the player's so the pin reads this tick's HoldPoint (restore on release), `ai_state` HOLD. A miss lets the move play out; emit `attack_whiffed` at the end of active so the audio and log hear it.
- **Hold.** `tick()` each sim frame: validate (`player.state == GRABBED and player.holder == enemy`), else end the hold. After `enemy_grab_hold_s`, start the grab hit (`GRAB_HITS`) with `start_move(..., windup = false)`; at its `startup` frame: `player.release_from_grab(Vector3.ZERO, false)` first (holder hits other than THROWN keep a victim held, CA:952), then a code-applied `HitInfo` (template `PC._throw_held()`), `receive_hit`, `TimeController.hitstop([enemy, player], HitDetector.hitstop_for(hit))`, `hit_landed`. Then recover and release the token.
- **Break.** `break_presses()` = `grab_break_presses` (× `boss_grab_break_mult` for the boss). `on_broken()`: the enemy staggers (STAGGER, punishable; the Bruiser grabbable after if `bruiser_grabbable_when_staggered`). `on_holder_hit()`: any hit on the holder (a flying body from its own team) releases the player on its feet.
- **Player side** (`player.gd`, a clearly separated "Grabbed by an enemy" section): `_on_grabbed(by)` resets `_cam_offset`, the parser chain and buffer, `_held_attack`, `_air_attack`, `_turn_frames`, `_quick_turn_frames`, the mash count, and starts a look turn to the holder over `grabbed_turn_frames`; a `GRABBED` arm in `_tick_control()` that feeds the parser, counts P and K presses (`parser.consume`) with `grab_break_decay_per_s`, then `parser.clear_buffer()`; at `holder.hold.break_presses()` calls `break_free(away_from_holder * grab_break_push_mps, grab_break_invuln_frames)`; safety net: holder invalid, KO, gone or not GRABBING → `release_from_grab(ZERO, false)`. Look lock: extend the `_process` gate to GRABBED. `_held_anim()` → `&"held_collar"`. `_pin_spot()` override: `grabbed_pin_distance_m × holder.rig.rig_scale()` in front of the holder. View pitch via `get_camera_move_offset()` (`grabbed_view_pitch_deg`), so the camera files aren't touched. `grab_break_progress() -> float` (0..1) for the prompt. `reset_state()` resets all of it.
- **Poses** (`grab_poses.gd`): `hold_collar` (holder upright, both fists at the victim's collar at HoldPoint distance), `held_collar` (victim upright, hips over the origin so release doesn't move the lens, arms up at the holder's wrists; a faster struggle loop reads as breaking free), `held_lift` (optional; the slam's wind-up lift), and recipes for the four grab moves (grab: arms spread wide and a forward crouch, strike = `grab_reach`; headbutt: from `hold_collar`, head and spine back then snapped forward; slam: arms up with the victim ≤ 140°, then a deep crouch). Author the boss's at its scale.
- **Mash prompt** (`mash_prompt.gd`): "MASH P / K" plus a fill bar from `grab_break_progress()`, lower centre, outside the top corners, shown only while the player is GRABBED by an enemy; red not used.
**Tests** (`test_enemy_grabs.gd`): N presses (`push_press(&"P", 1)`) break free before the hit, N-1 don't; unbroken, the headbutt lands 15 and knocks down; boss slam 25 and needs 1.5x presses; a dodge through the wind-up is never grabbed; a jump neither; a heavy hit (the hook) cancels the Bruiser's grab wind-up; a jab doesn't; other enemies' strikes can't hit the held player; the holder hit by a flying body releases the player; the player KO'd by the slam gets the KO view and revives; no stale `_cam_offset` after a grab during a kick; look doesn't turn with mouse input while held and ends facing the holder; release doesn't jump the origin by more than 0.05 m. `test_grabbed_view.gd` with `tests/fp_view.gd`: own body ≤ a third of the view, grabber's head and hands ≥ 0.25 m from the lens through the hold and the headbutt.
**Captures** (`grab_acts.gd`, FP): "Grab: Bruiser, mash free", "Grab: Bruiser, headbutt lands", "Grab: dodge the wind-up", "Grab: boss slam". Judge: the telegraph reads, the held view isn't buried, the prompt reads, the release doesn't pop.
**Acceptance.** Every Game-boy grab rule demonstrated in a test and a sheet; suite passes.

### WP-WARN: the rear-attack warning and HUD wiring (`.worktrees/m3-warn`, `m3/wp-warn`). Size: half of WP4.
**Goal.** SPEC §8 exactly, plus the boss bar and the audio voice budget.
**Owned.** `game/ui/rear_warning.gd`, `game/ui/hud.gd` (boss bar discovery only), `game/ui/enemy_health_bars.gd` (skip group `"boss"`), `game/ui/combat_log_overlay.gd` (if the ARMOR tag needs layout), `game/audio/audio_director.gd`, the Rear warning tunables, `tests/test_rear_warning.gd`, `tests/test_rear_warning_room.gd`, `tests/bot/acts/warn_acts.gd`, `docs/milestones/M3-notes/warn.md`.
**Consumes.** `windup_started`, `windup_ended`, `hit_landed`, `attack_whiffed`, `grabbed`, `ko`, `vanished`; `PlayerCharacter.look_bearing_deg()`; `MoveData.reach_m`; `EnemyActor.heavy`; the group `"boss"`.
**Build.**
- **Trigger** on `windup_started(attacker, move)` with `attacker.team != 0`: `b = player.look_bearing_deg(attacker.global_position)`; fire if `|b| > rear_warning_angle_deg` and the flat distance ≤ `move.reach_m + rear_warning_range_margin_m`. Side: `b > 0` → left (top-left), `b < 0` → right; `|b| ≥ 180 - rear_warning_behind_deg` → both corners. Use the look, never the active camera (side view, free fly and headless must agree with the director).
- **End**: `hit_landed` with that attacker (blocked included), `attack_whiffed(attacker)`, `windup_ended(attacker, true)`, `grabbed(attacker, _)`, `ko`/`vanished` of the attacker; plus a poll each `advance()`: attacker freed, not in WINDUP/ATTACK, or `current_move.id` no longer the move's id (grab moves never whiff). **Not** `windup_ended(attacker, false)` (the strike coming out).
- **While showing** (judgement call, both tunable): with `rear_warning_follow_turn`, re-derive the side each frame from the current bearing (a quick turn moves or clears the burst); with `rear_warning_drop_in_view`, drop the attacker's entry once `|b| ≤ rear_warning_angle_deg`.
- **Look**: `VfxArt.texture(&"rear_warning")` (preload in `_ready()`, `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`), centred `rear_warning_inset_px` in from the corner, size `rear_warning_base_px × rear_warning_size` (× `rear_warning_heavy_scale` if any attacker on that side is `heavy`), clamped inside the reserved 384 x 216 corner rect (anchored, so wider windows keep it in the corner), alpha `rear_warning_opacity`; `rear_warning_pulses` pulses of `rear_warning_pulse_s` (scale and brightness up by `rear_warning_pulse_gain`), then rest at `rear_warning_rest_alpha × opacity`. One burst per corner; each extra attacker on that side adds `rear_warning_count_gain` brightness, capped by the opacity. Timed on `game_delta × TimeController.sim_scale()` (holds on pause, slows with 0.25x and slow-mo). Below the impact-frame layer (20).
- **Signals** `shown(side, count)` and `hidden(side)` for bots and tests; the test API per 4.8.
- **HUD**: `GameHud` shows the boss bar for the first live member of `"boss"` and hides it on `vanished`; over-head bars skip the boss.
- **Audio** (`audio_director.gd`): `_take_voice()` prefers stealing a non-wind-up voice (the wind-up cue may be the only warning); heavy attackers' effort pitch lowered through `voice_pitch()` reading `EnemyActor.heavy` (no new pool unless needed). `rear_warning_audio` keeps gating the cue (judgement call: SPEC §8's "audio on/off" literally).
**Tests** (`test_rear_warning.gd`, the `test_ui.gd` harness pattern with `FakePlayer` and an `EnemyActor` fake): behind-left (135°) → left only; behind-right (-135°) → right only; 180° → both; 161° → both, 159° → one; 50° (in view) → none; 120° but beyond reach + 1 m → none; two left attackers → one burst, brighter, `corner_count` 2; heavy → larger, still inside the corner rect at `rear_warning_size` 3; ends on hit, whiff, interrupt, grab, KO, freed, move change, and **not** on `windup_ended(false)`; the quick turn re-sides or drops it per the bools; pause holds the pulses; tunables read live; writes no game state (copy `test_vfx.gd:891`). `test_rear_warning_room.gd`: the real test room with presentation, a `TrainingDummy` posted behind-left, behind-right and behind, `start_jab()`, the right corners at wind-up start and cleared at the hit (needs no AI).
**Captures** (`warn_acts.gd`; the test room via a `warning` act set if needed, corners cropped `crop=iw*0.3:ih*0.3`): "Warning: left", "right", "behind", "in view (none)", "two left", "heavy" (a Bruiser stub forcing `bruiser_smash`). Judge: readable, red-orange, inside the corners, two pulses.
**Acceptance.** Every SPEC §8 bullet has a passing test; sheets show all three placements correct.

### WP-DEBUGUI: F3 overlay and F4 spawns (`.worktrees/m3-debugui`, `m3/wp-debugui`). Size: half of WP4.
**Goal.** SPEC §11: F3 shows each enemy's AI state and who holds attack tokens; F4 spawns any enemy at the crosshair.
**Owned.** `game/ui/ai_debug_overlay.gd`, `game/ui/cheat_menu.gd`, `tests/test_ai_debug_overlay.gd`, `tests/test_cheat_spawn_enemies.gd`, `tests/bot/acts/debugui_acts.gd`, `docs/milestones/M3-notes/debugui.md`.
**Consumes.** The director's debug read API, `EnemyActor.nav`, `PlayerCharacter.look_yaw`, `Tuning.rear_warning_*`, `EnemyCatalog`, `NavBaker.ensure_for()`, `EnemyDirector.ensure_in()`, `enemy_spawned`.
**Build.**
- Overlay (`@export` colours, each distinct from the existing ones because tests count lines by colour): token holder = magenta ring at the feet plus a line chest-to-chest to the player; posturing enemy = small circle at its slot plus a dim line; the posture ring (two circles at `debug_ring()`); the view boundary at ±`rear_warning_angle_deg` and the behind sector at ±(180 - `rear_warning_behind_deg`) as floor lines; each agent's `get_current_navigation_path()` as a polyline. Nothing at all when no `EnemyActor` and no director exist. Reads only. The label text itself is WP-AI's `debug_state_text()`.
- Cheat menu: an `OptionButton` of `EnemyCatalog.ids()` (unavailable scenes disabled) plus "Spawn at crosshair"; `spawn_enemy(id) -> CombatActor` generalising `spawn_dummy()` (keep `spawn_dummy()` returning a `TrainingDummy`; tests call it); per-archetype body size for the clear-spot test (Bruiser and boss are bigger); before an AI spawn call `NavBaker.ensure_for(world)` and `EnemyDirector.ensure_in(world)`; `enemy_spawned(e, &"cheat")`; the enemy starts in APPROACH (no ENTER) facing the player; "Remove spawned enemies" (groups out, then `queue_free()`); toggles for `Tuning.ai_frozen` and `waves_paused`. Keep `god_mode_toggle`, `one_hit_toggle`, `time_scale_buttons`, `skip_arena_button` and `focus_first()` on god mode.
**Tests.** Overlay: no new lines without AI; with a stub director, the expected colours and counts; reads nothing it writes. Cheats: each AI id spawns in the crowd room and in the training room (which then has a navmesh and a director, and the enemy walks), "No room" when blocked, remove leaves no group members, the freeze toggle idles brains.
**Captures**: "F3: crowd in side view" and "F3: free fly" (debug only), FP "F4: spawn a Kicker" (the spawn reads, faces the player).
**Acceptance.** SPEC §11 F3 and F4 items demonstrated; existing `test_ui.gd` and `test_tuning_panel.gd` unchanged and passing.

### WP-GRUNTS: Street Punk and Kicker (`.worktrees/m3-grunts`, `m3/wp-grunts`). Size: two thirds of WP4.
**Goal.** The two grunt archetypes, with readable telegraphs and the Kicker's flanking.
**Owned.** `game/enemies/punk/*`, `game/enemies/kicker/*` (scripts, scenes, pose files), `_punk_moves()` and `_kicker_moves()` and their `.tres`, the Street Punk and Kicker subgroups, `tests/test_enemy_punk.gd`, `tests/test_enemy_kicker.gd`, `tests/bot/acts/grunts_acts.gd`, `docs/milestones/M3-notes/grunts.md`.
**Consumes.** Archetype virtuals, `EnemyMoveIds`, `set_lunge()`, `windup_hold_at`.
**Build.**
- Punk: approaches head-on (`slot_bearing_preference()` 0, `ring_bias` from `punk_ring_bias`). `choose_attack()`: `punk_shove` with `punk_shove_chance`, else `punk_jab`; `next_in_chain(punk_jab)` → `punk_cross` with `punk_cross_chance`.
- Kicker: `slot_bearing_preference()` = 180 × `kicker_blind_side_bias` (0 = none); faster circle; `choose_attack()`: `kicker_sweep` if within `kicker_sweep_max_range_m` and the roll beats `kicker_sweep_chance`, else `kicker_jump_kick`. Jump kick travel: `set_lunge(forward, move.lunge, frames)` from `_on_attack_frame()` over the last 6 frames of startup plus active (the body visibly leaves the ground through `HIPS_POS` in the strike pose; the capsule stays grounded).
- Recipes (own pose files): `punk_jab` (a lead-cocked telegraph with `windup_hold_at`), `punk_cross` (short cock from `_jab_1`), `punk_shove` (hands drawn to the chest, step back, then `_shove`'s strike), `kicker_jump_kick` (crouch with arms back, then a front-kick leg with hips raised 0.3-0.4 m), `kicker_sweep` (crouched turn with the right leg out low, explicit `HIPS_POS`, G9). Upper arms ≤ 140° (G7). Wind-up key in 40-60% of startup.
- Correct `reach_m` from the measured strike points; distinct graybox colours (no red).
**Tests.** Move rows (frames, damage, reaction, hitboxes) as authored; reach within ±0.15 m of the measured strike; each opener's wind-up is visible from the defender's lens (`tests/fp_view.gd`, as `test_dummy_jab_telegraphs_its_wind_up`); the jab's strike connects with a 1.8 m player at its reach; the chain; seeded choice distribution; Kicker slot bias (with a real director stub) and the sweep knocking the player down; Punk 30 HP dies to one P P P P combo (6+6+8+12 = 32 ≥ 30).
**Captures** (FP from the defender at 2-3 m, frozen AI, forced attacks): every attack's wind-up and strike; "Kicker flanks" (free-fly plus FP turning). Judge: each tell distinct and readable; nothing within 0.25 m of the lens.

### WP-THUG: Pipe Thug and the dropped pipe (`.worktrees/m3-thug`, `m3/wp-thug`). Size: half of WP4.
**Owned.** `game/enemies/thug/*`, `game/weapons/weapon.gd`, `_thug_moves()` and its `.tres`, the Pipe Thug subgroup, `tests/test_enemy_thug.gd`, `tests/bot/acts/thug_acts.gd`, `docs/milestones/M3-notes/thug.md`.
**Build.**
- Spawns holding a pipe (`pipe.tscn`, `Weapon.attach_to(self)`). `choose_attack()`: `thug_pipe_1` armed, the Punk's openers unarmed (no pickup by enemies in M3); chain `thug_pipe_1 → 2 → 3` with `thug_chain_chance` each.
- **Drop**: `Weapon.drop(velocity: Vector3)` (new, public): reparent to the world at its current transform, unfreeze, `_set_ground_physics()` (group `"weapon"`, `LAYER_PICKUP`), `holder = null`, `weapon_dropped`. The thug drops on entering LAUNCHED, THROWN, DOWNED or KO, or at health ≤ 0 (connect its own `state_changed`), pushed at `thug_drop_speed_mps` along its fall; on `_tick_ko()`'s despawn it never frees a dropped pipe. Durability resets to full on drop. The player picks it up with LB and swings it exactly as the test-room pipe.
- Recipes `thug_pipe_1..3` reuse `_pipe_swing_1..3(wg)` strikes and follow-throughs with new held wind-ups (pipe cocked back and higher), upper arms ≤ 140° (`_pipe_swing_3`'s 170° breaks the ragdoll cone, G7).
**Tests.** Drop on each knockdown path and KO; the dropped pipe is available and the player's `_find_weapon()` finds it; the player's swing hits an enemy; an unarmed thug uses `punk_jab`; the chain; guard drain 1.5x; telegraph visible from the lens; reach measured.
**Captures** (FP): the three swings; "Thug: knockdown drops the pipe, the player takes it".

### WP-BRUISER: Bruiser and armor (`.worktrees/m3-bruiser`, `m3/wp-bruiser`). Size: half of WP4.
**Owned.** `game/enemies/bruiser/*` (with `brace`), `_bruiser_moves()` and its `.tres`, the Bruiser subgroup, `tests/test_enemy_bruiser.gd`, `tests/bot/acts/bruiser_acts.gd`, `docs/milestones/M3-notes/bruiser.md`.
**Build.**
- Body `bruiser_body_height_m`/`_radius_m`, `heavy = true`, slow, `choose_attack()`: `bruiser_grab` with `bruiser_grab_chance` (more when the player is blocking: grabs beat guards), else `bruiser_smash`.
- **Armor** (`_apply_armor`): LIGHT and not `breaks_armor` → absorbed (damage lands, no reaction, no cancel; play `brace` as a short overlay without changing state; any state, wind-ups included). HEAVY (not `breaks_armor`) → STAGGER (knockdowns and launches downgraded, knockback flattened to the stagger push). FINISHER or `breaks_armor` (the haymaker) → its own reaction (knockdown or launch). Killing hits never absorbed. Body impacts and thrown weapons go through the same rule (they're HEAVY).
- `_parry_staggers()`: true (a perfect block staggers the Bruiser; judgement call). `can_be_grabbed()` override: only while STAGGER and `bruiser_grabbable_when_staggered`.
- Recipes: `bruiser_smash` (both arms overhead ≤ 140°, spine back, held beat, both fists driven down to head-and-shoulder height of a 1.8 m player; it aims down by construction, so it lands at 2.05 m), `brace` (named: a short shoulder hunch).
**Tests.** The armor matrix: jab absorbed (WINDUP continues, `armor_absorbed`, no `windup_ended`), hook staggers out of the wind-up, uppercut (finisher) knocks down, haymaker knocks down, a killing jab kills; body impact staggers; a parried smash staggers; grab only when staggered; smash reach and FP telegraph; 80 HP.
**Captures** (FP): "Bruiser: jabs bounce off", "Bruiser: hook staggers", "Bruiser: smash tell".

### WP-BOSS: the graybox boss (`.worktrees/m3-boss`, `m3/wp-boss`). Size: two thirds of WP4 to WP4.
**Owned.** `game/enemies/boss/*` (with `run_forward`), `_boss_moves()` and its `.tres`, the Boss subgroup, `tests/test_enemy_boss.gd`, `tests/bot/acts/boss_acts.gd`, `docs/milestones/M3-notes/boss.md`.
**Build.**
- `display_name` "Boss" (placeholder; name and look wait for the art milestones), group `"boss"`, `heavy = true`, `boss_body_height_m`/`_radius_m`, 300 HP, `token_bonus_s()` = `boss_token_bonus_s`, never grabbable by the player.
- **Phases**: `_tick_archetype()` polls health; at ≤ `boss_phase2_health_frac` × max (once): phase 2, `boss_phase_changed(self, 2)`, a roar (`taunt`), `director.summon(&"punk", boss_summon_count, global_position)`; phase 2 multiplies walk speed, turn rate and the wind-up (via the scaled move, never below the 30-frame floor) by the phase-2 tunables.
- **Armor** (`_apply_armor`): during WINDUP and ATTACK, LIGHT (not `breaks_armor`) is absorbed (light hits don't interrupt boss wind-ups); HEAVY → STAGGER (a heavy hit gets out of the grab wind-up, Game-boy); FINISHER and `breaks_armor` → STAGGER as well, so the boss is never knocked down before its KO (judgement call; alternative: finishers knock it down). Outside wind-ups and attacks, light hits flinch it.
- `choose_attack()`: beyond `boss_charge_min_range_m` → `boss_charge`; close and the player in front → `boss_grab` with `boss_grab_chance`, else `boss_pound` with `boss_pound_chance` (more when two or more enemies are near the player or the player is beside or behind), else the charge from range. Charge travel: `set_lunge(forward, move.lunge, move.active)` at `frame == startup`, playing `run_forward` through the active window; stops on a wall (move_and_slide). Pound: the ARC hits all around (behind included), so it fires the rear warning when the player has his back to the boss.
- Recipes: `boss_charge` (crouched, shoulder dropped, rear foot back; strike held through active), `boss_pound` (both fists overhead ≤ 140°, up on the toes; strike a crouch with fists at the floor), `run_forward` loop.
**Tests.** Phase 2 at 150 HP exactly once, summons two Punks (fewer if the cap allows fewer), speed and turn rate up, wind-up ≥ 30; charge travels about `lunge` m and knocks the player down for 20; pound hits a player behind, is unblockable; a jab during the pound wind-up doesn't interrupt it; the hook staggers the boss out of its grab wind-up; HUD-independent (no presentation calls).
**Captures** (FP): "Boss: charge from range", "Boss: pound from behind", "Boss: phase 2 calls Punks", "Boss: grab slam" (with WP-GRAB's moves once merged; with the stub before).

---

## 6. Phase 2: integration

### 6.1 Merge (lead, ~1 h)
Order: WP-AI, WP-DIR, WP-ROOM, WP-GRAB, WP-WARN, WP-DEBUGUI, WP-GRUNTS, WP-THUG, WP-BRUISER, WP-BOSS, then any contract patch tags. Expected conflicts: none, except `tuning/default.json` (resolved automatically by `keep-ours`). After each merge: regenerate moves only if a merge touched `gen_moves.gd` (`godot --headless --import --quit && godot --headless -s tools/gen_moves.gd && godot --headless --import --quit`; check the "wrote N moves" line; `git status` must show no `.tres` change), regenerate the preset, run the full suite. Then: `run/main_scene = res://game/level/crowd_room.tscn`, fold builder judgement calls into `M3-judgement-calls.md`, push, HANDOFF.

### 6.2 INT-1: crowd feel and the player in a crowd (`.worktrees/m3-int-crowd`, `m3/int-crowd`). Size: phase-3 B.
Owned: `game/player/player.gd` (magnetism and crowd parts only), tuning defaults in any subgroup (it is the only builder editing `tuning_data.gd` at this point), the "Magnetism" group, `tests/test_crowd_feel.gd`. Not `tests/bot/acts/proof_acts.gd` (INT-2's).
- Magnetism: skip bodies in get-up i-frames (so a strike doesn't lunge at an unhittable body), the stop distance plus the target's `body_radius` (Bruiser, boss), a flat cone test for bodies taller than 2 m (the boss's chest drops out of the 3D cone at 1 m), the stomp only when no standing enemy is in the magnetism cone. Move the literal 4°/m tie-break into the "Magnetism" group as you touch it.
- Readability tuning from the 6-enemy captures (posture spacing, grant gap, cooldowns, warning size) with A/B sheets; take the default that reads best in first person and log it.
- Measure: concurrent attackers, strikes landing within 10 frames of each other, enemy coverage of the FP view (`fp_view.gd`), frame times windowed (`Time.get_ticks_usec()`, median of 3, 6 enemies with ragdolls and VFX) and the wave spawn hitch.

### 6.3 INT-2: done-when proof (`.worktrees/m3-int-proof`, `m3/int-proof`), parallel with INT-1. Size: half of WP4.
Owned: `tests/test_m3_done_when.gd`, `tests/bot/acts/proof_acts.gd`, `tools/check_m3_log.sh` (or a GDScript log checker under `tools/`).
- `test_m3_done_when.gd` (headless, deterministic, crowd room **with** presentation so the real `RearWarning` runs): real archetypes (Punk, Kicker, Bruiser) posted with frozen AI at 135° left, 135° right and 180°, at their reach, forced openers: assert the left, right and both corners at the wind-up's first frame and cleared when the hit lands; negative controls at 50° (in view) and 135° beyond reach + 1 m; the Bruiser's burst larger; two on the left brighter. Then a 1500-frame 6-enemy soak (god mode, waves off, six spawned, a scripted autopilot player): never more than `attacker_cap` token holders, never more than 6 alive, every off-screen opener within range produced a warning on the right side, no enemy stuck more than 2 s, no `ERROR` line.
- Proof acts (FP unless noted, combat log and help hidden, short captions): "Proof: warning left", "right", "behind", "in view", "two left", "heavy"; "Proof: 6-enemy fight" (god mode, autopilot: face the nearest posturing enemy, P P P P, block or dodge when a wind-up starts in view, a slow 360° turn first); "Proof: F3 director" (side view and free fly, debug only).
- `check_m3_log`: parses the proof log: `WARN` lines per staged act match the expected sides; `TOKEN` holders never exceed the cap; every `windup_started` from beyond 55° and within range has a `WARN` within 1 frame.

---

## 7. Phase 3: adversarial review rounds

Copy the M2 scripts to `docs/reviews/M3/` (`workflow.js`, `workflow-fix.js`, `workflow-r2-close.js`) and make `MILESTONE = 'm3'`, `BASE_BRANCH = 'm3/enemy-ai'`, `NOTES_BRANCH = 'm3/review'`, `REVIEWS = 'docs/reviews/M3'`, the fix commit subject `M3 phase 3: review fixes (<key>`, costs divided by 5, tests about 90 s. Rewrite `COMMON` for M3 (merged packages, Game-boy's answers as APPROVED, OPEN WITH GAME-BOY: none, take defaults and log them). Save launch args as `args-r<n>-*.json`.

Lenses (Opus, each in a detached `.worktrees/m3-review-<lens>` at the merged head, imported; at most two Godot-bound at once):
1. **code**: layer rules (no camera in the simulation, presentation writes nothing), contracts honoured, no feel numbers, despawn hygiene (groups out before free, tokens returned, nothing holding a freed enemy), determinism, map queries before sync, ERROR lines.
2. **crowd** (FP): the 6-enemy fight is readable: spread, posture distance, tells, how many attack at once, nothing filling the view, armor reads, flankers dangerous but fair, the boss fight.
3. **warning**: every SPEC §8 bullet in the merged build, behind-left, behind-right and directly behind with real archetypes, several per side, heavy, the end on land, whiff, interrupt and grab, pause, KO view, audio direction.
4. **grabs-boss-thug**: mash, dodge, heavy-out, held view, boss phases and summons, charge and pound, the pipe drop and pickup.
5. **perf**: windowed frame times with six enemies, navigation, ragdolls and VFX; the wave spawn and first-knockdown hitches.

Then three Sonnet skeptics per finding (reproduce, spec and README check, code read; survives with ≥ 2 confirmations), an Opus completeness critic, a partition into ≤ 4 fix packages with disjoint files, Sonnet fixers. Repeat with lead-written briefs (`workflow-r2-close.js`) until no high or medium finding survives (plan for two rounds).

---

## 8. Phase 4: docs, build, release, PR, Slack

1. **README**: Milestone 3 status; controls (F3 AI overlay, F4 spawn any enemy, F6 room switch, mash P/K when grabbed); "Where M3 departs from the spec": the warning re-sides or drops when the attacker comes into view (if kept), chain links without their own wind-up, the parried Bruiser staggers, the boss never knocked down before KO (if kept), enemy pipe pickup not in M3, the mash-to-break-free rule (Game-boy's addition), wind-up multiplier floored at SPEC's minimums; test count and time (fix CLAUDE.md's stale "about 6 s").
2. **ARCHITECTURE**: title to Milestones 1-3; fold in `docs/milestones/M3-notes/*.md` as sections (Enemies and the brain, Director, Navigation, Enemy grabs, Rear warning, Crowd room and waves, F3/F4/F6); Moves table rows for the 15 enemy moves; the new animation ids; ownership for M3.
3. **Judgement-call log** complete; it is the source of the Slack digest.
4. **macOS export** (preset from `78ad5d4`; templates installed): `godot --headless --export-release "macOS" build/beat-em-up-m3.zip`. Smoke test the exported app: launch its binary with `--quit-after 900` and read the output for `SCRIPT ERROR`/`ERROR`; launch it windowed once and look (crowd room, a wave, F6, F1). Never commit `build/`.
5. **GitHub Release**: `gh release create m3-playtest-1 build/beat-em-up-m3.zip --repo mikedtcm22/beat-em-up-PoC --target m3/enemy-ai --prerelease --title "Milestone 3 playtest 1" --notes-file <notes>` (notes: first launch is right-click → Open because the build is ad-hoc signed; controls; what to try).
6. **PR** `m3/enemy-ai` → `main`, description ending with the Claude Code line. **Never merge it** without Game-boy's sign-off.
7. **Slack DM** to Michael (`U0AQMKKBL93`): the release link and the judgement-call digest (each decision, at least one alternative not taken, why). HANDOFF final entry.

---

## 9. Bots and captures that prove the done-when

| Proof | How | Pass |
| --- | --- | --- |
| Warning behind-left / behind-right / directly behind | `test_m3_done_when.gd` + "Proof: warning *" acts, corner crop sheets, `WARN` log lines | left only / right only / both, at the wind-up's first frame, cleared on landing |
| Negative controls | 50° in view; 135° out of range | no burst |
| Several attackers, heavy | "two left", "heavy" acts and asserts | one brighter burst; larger burst inside the corner |
| 6-enemy fight readable | "Proof: 6-enemy fight" FP sheet (12 fps tiles over 60 s), the soak test, log checks, INT-1 metrics, the crowd lens verdict | ≤ cap attacking at once; spread around the player; every off-screen opener warned; no stuck enemy; enemies never fill the view; a reviewer can name who is about to attack in each sheet row |
| Director legible in debug | "Proof: F3 director" (side view, free fly) | token holders, slots and the ring visible |
| Archetypes and grabs | each package's acts | listed per package |

Command pattern (every agent): `tools/capture_bot.sh crowd_bot captures/<key> "<act filter>" 6`, then tile with `ffmpeg -i <avi> -vf "fps=6,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png` (corners: `crop=iw*0.3:ih*0.3:0:0`) and LOOK.

---

## 10. Schedule, concurrency and dependencies

- Phase 0: P0-A alone (gate: suite + lead review) → P0-B, P0-C, P0-D in parallel → lead merges, gate 4.10, tag.
- Phase 1 wave 1 (6 builders): WP-AI, WP-GRAB, WP-BOSS, WP-DIR, WP-ROOM, WP-WARN (the critical path and the heaviest pose work first). Wave 2 as slots free: WP-GRUNTS, WP-THUG, WP-BRUISER, WP-DEBUGUI. No phase 1 package waits on another's merge: all of them build and record against the phase 0 scaffolds (the naive brain and director make stub enemies walk, posture and attack).
- Memory: 8 GB, so builders run single test files while working and the full suite once; captures serialised by the global lock.
- Phase 2 needs every phase 1 package merged; INT-1 and INT-2 run in parallel (disjoint files).
- Phases 3 and 4 as above. HANDOFF at every boundary; the usage watcher's 90% halt applies throughout; each builder commits `wip:` every 15-20 minutes so a halt loses little and a rerun of the same workflow args resumes.

---

## 11. Judgement calls made in this plan

| Decision | Alternative not taken | Why |
| --- | --- | --- |
| Phase 0 freezes every shared signature, signal, tunable, move id and HUD/debug hook before any parallel build | M2's pattern: packages append to hot files, the lead hand-merges | Ten packages and eight hot files would make phase 1's merge a serial bottleneck and a regression risk; frozen contracts make every merge mechanical |
| Phase 0 coded by Sonnet builders from exact code in this plan; the lead (Opus) reviews | The lead codes the contracts itself | Game-boy's model policy (Opus plans and reviews, Sonnet codes); the plan already carries the signatures |
| Phase 0b ships working scaffolds (an enemy body, a naive brain and director, a room with a navmesh) | Pure shells, with phase 1 packages waiting on WP-AI's merge | Lets archetype, warning and grab packages record real wind-ups in phase 1 instead of serialising behind the AI |
| `MoveData.reach_m` is the single attack range, for the AI's step-in and the warning's trigger | A per-archetype `attack_range_m()` read by duck typing; reach derived from hitboxes | One number, tunable in F1, travelling with `windup_started`'s move argument; hitbox reach isn't static |
| One "out of view" number (`rear_warning_angle_deg`) for both the director and the warning, from the look (`look_bearing_deg`) | A separate blind-spot angle; the active camera's basis | They must never disagree; the camera is wrong in spins, the KO view and the debug cameras |
| `TrainingDummy` and `test_room.gd` untouched; new `EnemyActor` base, `RoomPresentation` helper, F6 in `GameInput`, a lazy navmesh bake and director for F4 spawns in the training room | Make the dummy extend `EnemyActor`; extract a `GrayboxRoom` base from the test room | About 11 test files and 3 bots pin the dummy and the room's geometry and child order; a little duplication is cheaper than that risk |
| Wind-up floors (18 grunt, 30 heavy) clamp `windup_mult` | Let the multiplier go below the floors | SPEC §7 states minimums; Game-boy can still lengthen wind-ups |
| Chain links (the Punk's cross, the Thug's swings 2 and 3) start without a wind-up of their own; only the opener telegraphs and warns | Every hit a full ≥ 18-frame wind-up | Three 0.3 s telegraphs make a combo read slow and repetitive; the spec lists each combo as one attack |
| Bruiser: light absorbed always; heavy staggers (knockdowns downgraded); finishers and the haymaker get their full reaction | Absorb everything except the haymaker | SPEC: "ignores light hits, staggers on heavy hits and the haymaker"; combos still pay off with a finisher |
| Boss: light absorbed only during wind-ups and attacks; heavy and finishers stagger; never knocked down before KO | Boss armored at all times; finishers knock it down | "Light hits don't interrupt boss wind-ups" plus Game-boy's "a heavy hit gets out of the grab"; a 300 HP boss sliding down every combo would read cheap. Tunable later if Game-boy disagrees |
| A perfect block staggers the Bruiser; the player can grab a staggered Bruiser, never the boss | Heavies ignore parries and grabs | Rewards the M1 parry Game-boy approved; a held 2.3 m boss would look broken |
| Enemy grab: no hitbox (connect checked in code), the hit applied after `release_from_grab()`, an upright `held_collar` pose with the hips over the origin, the holder ticking before the player | A damage-0 hitbox grab; reuse the bent-over `held` pose | A hitbox grab fires a fake `hit_landed` (burst, sound, camera punch); `held` buries the first-person lens in the grabber's chest and pops it on release |
| The rear warning re-sides each frame and drops once the attacker is in view (both tunable bools) | Side frozen at wind-up start until the attack ends | A quick turn shouldn't leave a stale corner; the bools let Game-boy compare both reads live |
| Posture slots in world angles, re-solved with hysteresis; only the Kicker's preference follows the look | Slots fixed relative to the player's look | Look-relative slots send every enemy running whenever the player turns in place |
| Navigation: latched `velocity_computed`, single-thread avoidance, async iterations off, a synchronous bake with a roof filter, a player `NavigationObstacle3D` | The Godot docs' `move_and_slide()` in the callback; default settings | The spike measured these: the callback bypasses hitstop and time scale, multi-threaded avoidance is nondeterministic, async iterations lose late navmeshes |
| No enemy move uses the FINISHER tier | A FINISHER boss slam | FINISHER triggers the global slow-mo and impact frame that SPEC §6 reserves for the player's payoffs |
| The director grants nothing while the player can't be hit (KO, get-up i-frames, held), with hit and revive graces | Let tokens queue and swing | Avoids whiffing wind-ups and warnings at an untargetable player and flinch-locks |
| Cheat-spawned enemies count as alive for tokens; waves count only their own | Cheat spawns block waves | F4 is a debug tool; waves keep running predictably |
| Waves are level data on the room (default 6-wave cycle ending with the boss) | Waves as tunables in F1 | They're layout, like the test room's posts; F1 stays about feel |
| Pipe Thug fights with the Punk's moves after losing the pipe; enemies never pick weapons up in M3 | It walks back for the pipe | Enemy pickup is outside M3's scope and the pipe should stay the player's reward |
| `tuning/default.json` merges with `keep-ours` and is regenerated after every merge | Hand-merge it, or leave it out of builder commits | It is generated and byte-checked; regeneration is the only correct resolution |
| Builders write ARCHITECTURE text to their own notes file and report judgement calls in their result | Builders edit ARCHITECTURE.md and the judgement log | Shared docs would be the last conflict hot spot |
| One Movie Maker capture at a time across all worktrees (a global lock in `tools/capture_bot.sh`) | Each agent captures freely | Movie Maker opens a window, captures the mouse and competes for focus on an 8 GB machine |
| The playable link is a prerelease GitHub Release with the zipped universal macOS export, smoke-tested from the exported binary | Share a branch and ask Game-boy to run the editor | Game-boy asked for a link he can click; the export proves the build outside the editor |

## 12. Risks and their mitigations
- **A contract gap found mid-phase-1.** The amendment protocol (2.3); the lead reviews requests at least every hour of phase 1.
- **The naive scaffolds diverge from the real implementations** (an archetype tuned against the naive brain). Phase 2's INT-1 retunes against the merged build; review lens 2 checks the whole fight.
- **Navigation in the training room** (no navmesh before F4): `NavBaker.ensure_for()` plus direct steering when the map isn't synced.
- **Six rig builds in one tick (~60 ms)**: one spawn per `wave_spawn_interval_s`; the optional library cache in P0-B.
- **Test time** grows past 90 s: per-package tests stay short (seeded, a few hundred ticks); only `test_m3_done_when.gd` runs a long soak.
- **The non-KO knockdown view** (the open M2 "belly slab") shows up more in a crowd: grunts mostly flinch or stagger the player; only sweeps, the third pipe swing and heavies knock down. Review lens 2 judges it.
