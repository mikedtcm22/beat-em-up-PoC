# M4 calls: fix-final-done-when-ratchets-and-suite-time

The final review's package for findings final-v6-02 (A7's ratchet cannot fail), final-v6-03 (the done-when's loose ratchets), final-v6-05 (`PlaceholderAnims.Life`'s copied Motion defaults), final-v6-06 (the suite's whole-mesh skinning cost) and final-v2-01 (the lead's call 24: the `stagger_back` re-pose). Base: `m4/art-pipeline` at e476c0a, the final art geometry (F-cuff and the punk-detail rebuild are in). Every ratchet below is set from the figures printed on that base: today's figure plus a small stated margin, with the plan's bar still printed as GATE where the art misses it. No tunable was added (`tuning_data.gd` and `tuning/default.json` are untouched), no GLB changed, no Tripo or Gemini call, no spec change. The full suite is at the end of section 7.

## 1. What each finding came to

| Finding | Outcome | What changed |
| --- | --- | --- |
| final-v6-02 (A7 cannot fail) | fixed | `problems_max` dropped; a per-art ratchet on the in-bar count, the worst p99.9, p0.1, the longest stretch, the deepest compression and the flex share; a per-clip table; a teeth test. C1, C2, C3. |
| final-v6-03 (loose done-when ratchets) | fixed | every A4, A6, A7 (stretch), A9, A11 ratchet re-set; the hero's A9 reads `test_art_player`'s `HERO_*`; stale comments refreshed. C4. |
| final-v6-05 (Life's copied defaults) | fixed | `Life.new()` reads a fresh `TuningData`; contract tests. C5. |
| final-v6-06 (suite time) | fixed | subset skinning, the M3 deformation frozen, the Punk's strain run shared, the A/B variants opt-in; 335.0 s to 286.0 s. C6, C7. |
| final-v2-01 (the lead's call 24) | fixed | `stagger_back_a` and `_b` re-posed; hashes regenerated with the reason in the table; pose tests; first-person stills. C8. |

## 2. C1: A7's whole-run ratchet, per art (final-v6-02)

**Decision.** `ArtStrain.SHIPPED` no longer has `problems_max`. Its cap (560 and 480) was above the most problem lines a run can make (two a sample plus one a peak flex: 508 and 478), so it could not fail. Each art holds, from today's figures plus about 5%:

| Row | Punk old -> new (today) | Hero old -> new (today) |
| --- | --- | --- |
| `problems_max` | 560 -> dropped (503) | 480 -> dropped (472) |
| `high_max` (worst p99.9) | 4.6 -> 4.23 (4.03) | 9.5 -> 9.1 (8.67) |
| `low_min` (worst p0.1) | none -> 0.153 (0.161) | none -> 0.14 (0.147) |
| `max_max` (longest stretch) | none -> x12.85 (x12.24) | none -> x39.1 (x37.23) |
| `min_min` (deepest compression) | none -> x0.0144 (x0.0152) | none -> x0.0282 (x0.02969) |
| `in_bar_min` | none -> 1 (1) | none -> 1 (1) |
| `flex_share_max` (was one shared `FLEX_RATCHET_SHARE` 0.02) | 0.02 -> 0.0173 (1.65%) | 0.02 -> 0.0066 (0.63%) |

`FLEX_RATCHET_SHARE` is gone (it was 3x the hero's figure). The margins are printed beside the DONE-WHEN A7 lines and the gate lines of `test_skinned_art` (`ArtStrain.margin_text()`). Both tests read the same table and the same `ArtStrain.ratchet_problems()`.

**Not taken.** Keeping a problem-line count at today's exact value: a count saturates, and a worse sample cannot raise it; the deepest-compression floor is the number a mis-weighted vertex would take to zero, so it is held directly. The reviewer's suggested figures (Punk 4.4 / floor x0.015, hero 9.0 / cap x40) were not used as written: the Punk's floor is x0.0152 on this base (it was x0.02 at the review base) and the task asks for today plus a small margin.

## 3. C2: the per-clip table (final-v6-02)

**Decision.** Every clip's own p99.9, p0.1, longest stretch and deepest compression over its five phases, and every peak flex's squashed or turned-over triangles, are held to today's figure plus 10% (`ArtStrain.CLIP_MARGIN`; the triangle count plus 10% plus two). The figures are in `tests/fixtures/strain/strain_ratchet.json` (55 Punk clips, 52 hero clips), made by `tests/fixtures/strain/gen_strain_ratchet.tscn` (`godot --headless res://tests/fixtures/strain/gen_strain_ratchet.tscn --quit-after 5`, about 13 s; it also prints the whole-run figures SHIPPED is set from). A clip with no figure in the table fails ("no per-clip ratchet figure"), so a new animation is held from its first run.

**Not taken.** A constant Dictionary in `art_strain.gd` (about 220 lines of numbers); the table is a measurement, so it is a generated file with the margin applied in code, where it is visible. It first sat in `tests/fixtures/art/`, which `test_art_contract` requires to be named in ASSETS.md (a file the ASSETS rows own): it moved to its own `tests/fixtures/strain/`.

**Figures that moved with C8.** The table was made after the `stagger_back` re-pose. `stagger_back` per clip, old (the M3 pose) -> new: Punk p99.9 2.33 -> 1.90, p0.1 0.339 -> 0.357, stretch x6.76 -> x4.60, compression x0.120 -> x0.057 (a deeper inner-elbow edge: the elbows fold to 90-110 degrees instead of 40); hero p99.9 3.65 -> 3.65, p0.1 0.354 -> 0.324, stretch x19.9 -> x19.9, compression x0.185 -> x0.129. No whole-run figure moved (the worst edges are the arm raise, the KO lying clips and the get-ups).

## 4. C3: a teeth test (final-v6-02)

`test_skinned_art.gd::test_the_strain_ratchet_has_teeth` runs on the kept Punk run: the shipped ratchet holds, each of `high_max`, `low_min`, `max_max`, `min_min`, `flex_share_max` and `in_bar_min` tightened past today's figure fails, each of the five per-clip figures tightened (on the idle and on the arm-raise flex) fails, and a table without `walk_forward` fails. It costs nothing (the run is cached).

## 5. C4: the done-when's ratchets (final-v6-03)

**Decision.** Each is today's printed figure plus a small margin: 5% on a length or slide, half a point on a share of cells or of vertices, half a centimetre on an anchor. Old -> new (today):

| Constant | Old -> new | Today |
| --- | --- | --- |
| `SLIDE_RATCHET_PLAYER_M` (A4) | 3.0 -> 2.4 | 2.2885 m |
| `FIT_RATCHET_PLAYER` (A6) | one scalar 0.75 -> torso 0.985, legs 0.88, head 0.975 | 100%, 89.4%, 99.0% |
| `AXIS_OUTSIDE_RATCHET_PLAYER` (A6) | 2 -> 0 | 0 |
| `VISIBLE_STRETCH_RATCHET_M` (A7) | 0.10 -> 0.09 | 8.4 cm |
| `FRAMING_RATCHET_PUNK_DIFFER` (A9) | 0.09 -> 0.07 | 6.5% |
| `FRAMING_RATCHET_PLAYER_*` (A9) | 0.10 / 0.10 / 0.12 -> read from `test_art_player` (`HERO_DIFFER_MAX`, `HERO_SHARE_MAX`, `HERO_NEAREST_MAX_M`: 0.09 / 0.09 / 0.09) | 8.4%, 8.4 points, 8.1 cm |
| `ANCHOR_RATCHET_M` (A11, Punk) | head 0.02, torso 0.10, leg 0.05 -> 0.02, 0.065, 0.032 | 1.4, 6.0, 2.7 cm |
| `ANCHOR_RATCHET_PLAYER_M` (A11, hero) | 0.06, 0.12, 0.08 -> 0.033, 0.051, 0.052 | 2.8, 4.6, 4.7 cm |

The hero's A9 reads `test_art_player.gd`'s constants (public constants of that script, `preload`ed) rather than copying them, so the done-when's mirror cannot be looser than its source again. F-cuff's per-pose A9 lens-share ratchets (`punk_jab pitch +8` 0.051, `punk_cross pitch +8` 0.054) are kept as they are (exact at 5.0 points today); every other Punk pose is asserted at the 4-point bar. The notes the rows print now show each margin beside the GATE line (for A4, A6, A7's stretch, both A9 rows and A11). The comments that quoted pre-fix figures ("today 2.33 m", "89.8%, one point", "6.7%", "6.9 / 6.9 / 7.6 cm") were rewritten with the final ones.

**Not taken.** The finding's proposed values as written (A6 legs 0.87, A11 leg 0.035, `FRAMING_RATCHET_PUNK_DIFFER` 0.075 and the others): each sat 1 to 2 points above today; the task asks for a small margin. `test_art_punk.gd`'s own `VISIBLE_STRETCH_RATCHET_M` (0.10) was left: it holds all four GLBs, and the A/B variants' stretch is not 8.4 cm.

## 6. C5: Life's defaults (final-v6-05)

**Decision.** `PlaceholderAnims.Life` has no float literal now: `Life._init(source: TuningData = null)` reads every Motion value, `move_speed` and the polish switch from `source`, or from a fresh `TuningData` when it is null. `from_tuning()` is `Life.new(Tuning.data)` (one object, no double construction) and has its `##` doc; `off()` is `Life.new()` with `enabled = false`. So no test file needed a change: the A4 walks, `test_motion_m4`'s `_clip()` and the player-calm test now measure the clips of the shipped defaults, and a re-tuned default in `tuning_data.gd` reaches them. Game behaviour is unchanged: every named clip hashes as before (only `stagger_back` moved, C8, and no move clip).

**Tests** (`test_motion_m4.gd`): `test_a_default_life_is_the_default_tunables_and_there_is_no_second_copy_of_them` (every script variable of `Life.new()` equals `Life.from_tuning()` on a fresh `TuningData`; the 15 values are all there; a `Life` made from re-tuned tunables follows them; and a structural twin: the `class Life` block of the script holds no `: float = ` default), and `test_a_clip_built_from_a_default_life_is_the_clip_the_game_plays` (every polished id, both stances, key for key). Checked against the old class (`git show e476c0a:game/actors/placeholder_anims.gd` put back for one run, then restored): `test_motion_m4.gd` no longer parses ("Too many arguments for new() call": the old `Life` has no constructor argument, which is the twin's call), and its structural check would list the old class's 14 float defaults.

**Not taken.** Switching the four test sites to `from_tuning()`: it leaves the copy in the class for the next test that writes `Life.new()`.

## 7. C6: suite time (final-v6-06)

**Per-file times before and after** (GUT's JUnit export; load average 3 to 5 before and 4 to 5 for the last run; 73 files and 1580 tests before, 74 files and 1588 after):

| File | Before | After |
| --- | --- | --- |
| `test_motion_m4.gd` | 54.2 s | 15.5 s |
| `test_art_punk.gd` | 25.5 s | 11.8 s |
| `test_m4_done_when.gd` | 23.1 s | 13.4 s |
| `test_skinned_art.gd` | 12.9 s | 11.6 s |
| the whole suite | 335.0 s (338 s wall) | 264.5 s (267 s wall; the first run after the changes was 286.0 s at a load of 7 to 8) |

Per test (JUnit, before -> after): the idle soles 20.5 s -> 0.5 s, the Punk's walks 6.8 s -> 0.2 s, the rig-playback walks 4.1 s -> 0.1 s, the deformation comparison 18.1 s -> 9.3 s, the Punk's strain test in `test_art_punk` 18.1 s -> 4.7 s (it makes the Punk's kept run once), the done-when's A7 12.8 s -> 7.5 s (it reads the Punk's kept run and makes the hero's) and A4 4.5 s -> 0.5 s. `test_skinned_art` reads both runs from the cache. The files above 1 s that got slower (`test_m3_done_when` +3.7 s, `test_ko_view` +1.7 s, `test_ragdoll` and `test_combat_integration` +1.3 s) are untouched by this package: the machine was busier for the second run. CLAUDE.md says 'about 4.5 minutes (267 s ...)' where it said 'about 90 s' (an M3 figure).

**Decisions.**
1. **Subset skinning.** `SkinnedView.skin_subset(mi, rig, indices, globals)` skins only the given vertices with the same matrices and weights (`MeshData.entry_start` gives each vertex's entries); `MotionProbe.walk_slide` skins only the sole vertices, and `test_a_punk_walking_through_the_rigs_own_playback_plants_its_feet` does too. `test_the_subset_skin_is_the_whole_skin_at_those_vertices` holds it to `skin_vertices()` at 1e-6 m on three poses.
2. **The idle stays at 120 Hz over three cycles** (the note offered 30 Hz over one cycle if the figures stayed within a tolerance). One cycle would measure nothing: `walk_slide_with` counts only the runs that begin in the middle cycle (the skeptic's point). And it is not needed: at the same sampling the idle test no longer shows in the per-test times over 1 s. The printed MOTION figures (idle soles, every walk slide, the rig-playback slides: 24 lines) are identical before and after, so there is no tolerance to state.
3. **The M3 side of the deformation comparison is frozen**: `tests/fixtures/motion/m3_deformation.json` (34 clips: 17 polished ids, two stances), made by `gen_m3_deformation.tscn` (`godot --headless res://tests/fixtures/motion/gen_m3_deformation.tscn --quit-after 5`, about 10 s). It names the SHA-256 of punk.glb's vertices, bones and weights; if they differ (or the file is missing) the comparison measures the M3 clips live, says so, and still passes, and `test_the_frozen_m3_deformation_is_the_m3_clips_on_this_art` fails with the regeneration command. The same test measures two clips live (`boxer|walk_forward`, `relaxed|downed_front`) against the file at 1e-4, so a change of the rig or of the measure shows. The printed `MOTION A19` comparison lines are identical to before (34 of them).
4. **`test_art_punk`'s strain test** takes punk.glb's run from `ArtStrain.cached()` (making and keeping it when it runs first: it does, alphabetically) and measures the three locked A/B variants only with `ART_PUNK_VARIANT_STRAIN=1` (documented in the file's header, the test and CLAUDE.md; run once by hand: 4 of 4 GLBs in 18.5 s, 20 of 20 pass). `ArtStrain.strain()` gained `flipped_healed` so the printed flex lines are unchanged.

**Not taken.** Moving the strain run of the three variants out of the suite entirely: they stay a shipped tunable (`look_punk_art_variant`), so the opt-in keeps them one command away.

## 8. C7: stagger_back re-pose (final-v2-01, the lead's call 24)

**Decision.** `stagger_back_a` and `_b` (arm entries only; the trunk, the head and the legs are as M3 had them) are re-posed like `stagger_right`:

| | M3 | now |
| --- | --- | --- |
| key a (0.12 s), left / right upper arm (x, y, z) | (40, 0, -60) / (30, 0, 66) | (22, 0, -42) / (18, 0, 44) |
| key a, lower arm | 40 / 36 | 95 / 92 |
| key b (0.34 s), upper arm | (30, 0, -36) / (24, 0, 40) | (12, 0, -28) / (8, 0, 30) |
| key b, lower arm | 40 / 36 (inherited from a) | 108 / 105 |

Measured by FK (`PlaceholderBody.pose_globals`, on the drawn trunk, which leans back 24 degrees at key a): the upper arm 59 degrees off hanging at key a and 33 at key b (M3: 77 and 49), the elbow's inner angle 85-88 and 72-75 degrees (M3: 140-144 at both keys), the wrist 0.21 and 0.27 m in front of the hips (the boxer's guard holds the fist 0.26 m forward). The clip still runs g, a, b, g over 0.6 s and the torso is still thrown back (30 degrees at its furthest). The taunt is left as it is (its elbows bend 70 degrees).

**First-person check** (1 m, the art; `captures/fix/c11/`, `captures/fix/c14/`, never committed; 1600x900 crops at 2x beside the reviewer's `stagger_arms_pair.png`): at the widest frame (c11 f152-f158, after the third knee; c14 f1462-f1472, the long take) both arms are bent, the elbows folded, the fists up at shoulder and chest height beside the vest, the head thrown back, then the fists come up to the face as the guard returns. No frame has a straight horizontal arm. It reads as a body knocked back with its hands flung up, not the rig's bind pose. A first draft (upper arms 44-46 degrees out, elbows 80-85) was rejected after the stills: the forearms pointed outward and the pose read as an open-armed shrug; folding the elbows further (90-110 degrees) raised the fists.

**Hashes.** `tests/fixtures/motion/move_clip_hashes.json` was regenerated with `tests/fixtures/motion/gen_clip_hashes.tscn`: exactly the four `stagger_back|<stance>|<scale>` entries changed (no move clip, no other named clip, which also shows `Life.new()` in C5 builds the same M3 clips). The table has a new `notes` object (`ClipHash.NOTES`) saying why and giving the M3 hashes it replaced (boxer|1.0 5d4f1e7a896c, boxer|1.278 a770c027ff85, relaxed|1.0 49ca3e4c03f6, relaxed|1.278 b0aa3f3f405b), so a rewrite of the table keeps the reason. A20's frozen-clip list now has one departure, stagger_back (README's departures list is the lead's).

**Tests.** `tests/test_stagger_back_pose.gd` (new): the keys' arms (upper arm still out, elbow not shut, hand not at the lens, no straight wide arm: upper arm at most 65 degrees off hanging and the elbow's inner angle at most 125); the M3 key poses as the twin, which break both rules on both arms at key a and the elbow rule at key b (checked by the test itself); and the played clip, in both stances and both arms: no frame has a wide arm (upper arm over 45 degrees) with a near-straight elbow, the fist stays within 0.45 m in front of the hips and 0.68 m from the trunk axis (M3 about 0.75), the arms still open at least 0.1 m past the guard, and the trunk leans at least 15 degrees. The ragdoll, KO-view, grab-view, stagger and readability tests (F-motion C10's knife-edge cases) are in the full suite below; none needed a change, so `test_humanoid_rig.gd` and `test_ragdoll.gd` are untouched.

## 9. What is handed back

- **Full suite: 1588 of 1588** (1580 before, plus the 8 this package added), 112,132 asserts, 0 `SCRIPT ERROR`, 0 `SHADER ERROR`, and the only lines with `ERROR` in them are the done-when A12 note's own text; 267 s. The run before it (before the strain table moved directories) was 1587 of 1588, the one failure being `test_art_contract::test_every_exported_file_has_an_assets_row` naming the three files then in `tests/fixtures/art/`; they moved to `tests/fixtures/strain/`.
- **For `M4-calls/P3-int.md` C4 (toon-light-and-ink owns the file):** "C4's ratchets were re-set on the final art by fix-final-done-when-ratchets-and-suite-time (M4-calls/fix-final-done-when-ratchets-and-suite-time.md C1 to C4): today's figure plus a small margin, A7's `problems_max` dropped because it saturated, the per-clip strain table in tests/fixtures/strain/strain_ratchet.json."
- **For ARCHITECTURE's P3-int heading:** "A7's ratchet is `tests/art_strain.gd`'s SHIPPED rows (per art) plus `tests/fixtures/strain/strain_ratchet.json` (per clip, made by `gen_strain_ratchet.tscn`); the A9 hero ratchets are `test_art_player.gd`'s `HERO_*`; `PlaceholderAnims.Life.new()` is the defaults of a fresh `TuningData`."
- **README's departures (the lead's):** A20's frozen-clip list is departed from once, for `stagger_back` (the lead's call 24).
