# M4 evidence pack: index

M4-plan Part B section B3, A17 and A23. Recorded by P3-evidence on branch `m4/p3-evidence`, which is the merged head of `m4/art-pipeline` (`6e2a2e1`: every package and both fix waves of the final review). The game wears Street Punk A (`assets/source/concepts/punk_a_denim_vest.jpg`) and Hero C (`hero_c_martial.jpg`).

**Where the files are.** Every image and clip named below is under `captures/m4/evidence/` of the worktree `/Users/arachne/repos/beat-em-up-PoC/.worktrees/m4-p3-evidence/` (called `EV/` here). They are local and git-ignored (A17): the lead copies what the DM needs. What is committed is this index and five JSON files beside it: [art_metrics.json](art_metrics.json) (the A rows), [look.json](look.json) (the L rows), [readability.json](readability.json) (R1-R15 and R4/R8 with the art drawn), [ledger.json](ledger.json) (Tripo and Gemini) and [strain_worst10.json](strain_worst10.json) (A19's worst ten per GLB). The calls behind the choices are in [M4-calls/P3-evidence.md](../../../milestones/M4-calls/P3-evidence.md).

**How it was recorded.** 26 windowed recordings (Movie Maker, 1600x900), each act in its own process through `tools/capture_bot.sh`, cut with `tools/look_sheets.sh`. All 26 `bot.log` files have 0 `SCRIPT ERROR`, `SHADER ERROR` and `ERROR` lines. The full suite on the same head is 1593 of 1593, 0 error lines. First person is what is read; the side view was never used. **What follows describes what the frames show, in plain words; it is not a score** (the re-score scores J1-J14). Where a frame shows a fault, it says so.

## 1. The five-line metrics summary (A23)

1. **Budgets.** Punk 14,300 of 15,000 triangles, hero 29,320 of 30,000 (A2 PASS); 6 flat colours on each character's swatches, none in the red band, and none in the rooms (A3 PASS).
2. **Joint fit.** Every exported joint is within 1 mm of the chained joint table, 23 named binds, no `neutral_bone` (A1 PASS). Fists are 3.2-4.4 mm (Punk) and 8.9-9.0 mm (hero) off their box, bar 15 mm (A5 PASS). Hurtbox fit: Punk torso 100%, legs 95.2%, head 99.9% (meets the bar); **hero legs 89.4% against 95% (A6 GATE)**.
3. **A9 framing (art against the proxies, first person).** **Not met, held at a ratchet (A9 GATE).** Punk: worst 6.5% of the 48x27 cells differ (bar 3%), lens-share gap 5.0 points (bar 4; the jab and the cross at +8 degrees, from the wrist cuff). Hero: 11 of 15 poses miss, worst 8.4% of cells and 8.4 points, and the art stands 8.1 cm nearer the lens than its proxies in the front kick (bar 2 cm). The block guard's clearance holds (0.336 m, bar 0.3). With the art drawn instead of the proxies, R8 differs by -2.1 / -0.7 points at the median and R4 hides no wind-up that the proxies did not (L5 MET).
4. **Perf, p95 and spawn hitch. LOADED MACHINE, NOT QUIET, and not re-run on the final head.** The lead's interleaved run at the slice gate (M3 `afdb39e` against M4 `59a0adf`, vsync on, load 2.4-4.6, "Perf, six with ragdolls"): mean 12.10 to 14.53 ms, **p95 26.05 to 29.43 ms (+3.4)**, **spawn hitch 37.1 to 40.0 ms (+2.9)**, first spawn +1.0 and first hit +1.4 (both within A16's +2). M3 itself misses the 16.7 ms p95 and 33 ms hitch bars on this machine. The later run at `bf7b0ab` read +4.2 p95, +3.3 hitch, first hit +3.2. FXAA saves 2.3 ms mean and 3.0 ms p95. The RTX 3060 is unmeasured.
5. **Tripo credits.** 12 tasks, **295 credits** (M4's stop is 750, the cap 800), balance 1205 of 1500; 23 Gemini images by the job files, no Gemini ledger.

**Said beside the five lines, not in them.** The measured rows are 9 PASS and 5 GATE: A4 (the hero's walk slides his planted soles 2.29 m against 2 cm: M3's 0.6 s cycle at his speed), A6, A7, A9 and A11. **A7 (deformation) is not met on either GLB**: Punk worst p99.9 strain 4.03 against 1.6, 1.65% of triangles folded or squashed at the worst peak flex against 0.5%, the longest visible stretch 8.4 cm against 2 cm; hero worst p99.9 8.67, 0.63% at the worst flex. The windowed row **L1 is missed** (the hull at 10 m is 2.0-2.6 px against 3.75 +-1; the player's own top edge 4.05 px); L2, L3 and L5 are met. Details in [art_metrics.json](art_metrics.json) and [look.json](look.json).

## 2. What the DM needs, with absolute paths

Every path below starts `/Users/arachne/repos/beat-em-up-PoC/.worktrees/m4-p3-evidence/captures/m4/evidence/` (`EV/`).

| What | File | Reads as |
| --- | --- | --- |
| **The DM pair** (M3 left, M4 right, same frame and distance: the Punk 1 m ahead, default view, 1 s in) | `EV/pairs/c2/stills/c2_f109_idle_t060_m3_left_m4_right.png` | the placeholder's block fists and black cuffs against the Punk in its guard |
| The DM pair's face-shot twin (+8 degrees) | `EV/pairs/c1/stills/c1_f109_idle_t060_m3_left_m4_right.png` | the cap and head |
| The two halves alone | `EV/c2/sheets/c2/stills/c2_f109_idle_t060.png` (M4), `/Users/arachne/repos/beat-em-up-PoC/captures/m4_before/c2/sheets/c2/stills/c2_f109_idle_t060.png` (M3) | |
| **Punk beside its concept** (concept A left, the C2 guard right) | `EV/concept_pairs/punk_concept_left_c2_body_right.png` | see J1 |
| Punk concept, face shot | `EV/concept_pairs/punk_concept_left_c1_face_right.png` | |
| Punk concept, full body (the turntable's front, at rest, about 2.5 m) | `EV/concept_pairs/punk_concept_left_c10_turntable_front_rest_right.png` | the whole figure, jeans and shoes, against the concept's A-pose |
| Punk concept, then the turntable's three other quarters | `EV/concept_pairs/punk_concept_then_turntable_q90_q180_q270.png` | |
| **The player beside his concept** (hero C left, six first-person frames of his limbs right) | `EV/concept_pairs/hero_concept_left_first_person_limbs_right.png` | he is never seen from outside in the game, so his side is what the lens draws (see J14) |
| **Clip 1, the 40 s long take at 1 m** | `EV/clips/long_take_1m_c14.mp4` (5.2 MB, 1280x720, H.264, 60 fps, 40.2 s) | see section 5 |
| **Clip 2, a six-Punk fight** | `EV/clips/six_punk_fight_2_to_10m.mp4` (7.7 MB, 28.6 s) | see section 5 |
| **Clip 3, the player's own limbs** | `EV/clips/own_limbs_pa1.mp4` (1.6 MB, 10.6 s) | see section 5 |
| **Feel 1, flash share** (today 0 left, 0.12 right) | `EV/feel_ab/q1_hold_knee1_flash_share_today_0_left_cap_0p12_right.png` (also `..._knee2_...`, `..._knee3_...`) | section 6 |
| **Feel 2, finisher radius** (1.0 left, 2.0 right) | `EV/feel_ab/q2_haymaker_finisher_radius_today_1p0_left_mult_2p0_right.png`, `EV/feel_ab/q2_uppercut_finisher_radius_today_1p0_left_mult_2p0_right.png` | section 6 |
| **Feel 3, knockdown torso** (false left, true right) | `EV/feel_ab/q3_my_knockdown_f146_down_t045_hide_torso_false_left_true_right.png` (also `f121`, `f171`) | section 6 |
| **Feel 4, combat log** (false left, true right) | `EV/feel_ab/q4_hold_f68_knee_took_combat_log_hide_while_holding_false_left_true_right.png` (also `f100`, `f40`) | section 6 |

## 3. The rubric, item by item (Part B section B2)

A frame is `<act>_f<video frame>_<mark>`; stills are `EV/<dir>/sheets/<slug>/stills/`, crops `.../crops/` (head, hands, body, 2x), 6 fps overviews `.../overview_NN.png`, 12 fps sheets `EV/fps12/`, side by sides `EV/pairs/<slug>/`, montages `EV/montages/`. Directory names are in the table of section 8.

### Standing at 1 m

| Item | Act, frame | Crop and files | What the frame shows |
| --- | --- | --- | --- |
| **J1\*** reads as the pick; reads at 2.5, 5 and 10 m | C2 `f109_idle_t060`; C6 `f109_d1_0_m`, `f199_d2_5_m`, `f289_d5_0_m`, `f379_d10_0_m` | `EV/c2/sheets/c2/crops/c2_f109_body.png`; `EV/montages/c6_distances_1_2p5_5_10m.png`; the concept pairs of section 2 | Yellow backwards cap, teal vest over a black tank, dark fingerless gloves, a taped right forearm, light jeans with knee rips, cream-and-yellow shoes (seen from 2.5 m): the concept's parts are all there and the figure is chunky. Not like the concept: the yellow shades read as a yellow band under the cap's brim, the forearms are very large in the guard, and the face is simpler than the concept's. At 10 m it is a yellow cap over a teal body, a few dozen pixels tall, still a figure. |
| **J2\*** face covered or simplified, crisp, symmetric | C1 `f109_idle_t060` (+8 degrees) | `EV/c1/sheets/c1/crops/c1_f109_head.png`; `EV/pairs/c1/crops/c1_f109_head_m3_left_m4_right.png` | The brow and eyes are under the cap and the shades; below them a nose stroke, a short mouth bar and a lilac shadow side. Symmetric, no smear or mush. One white glint on the lens; the cap's strap slot is a dark arch. It is a mask, not a face, which the concept also is. |
| **J3\*** gloved fists read as fists | C2 `f109`; C4 `f62_punk_jab_strike`, `f90_punk_cross_strike` | `EV/c2/sheets/c2/crops/c2_f109_hands.png`; `EV/montages/c4_attacks_windup_strike_jab_cross_shove.png` | At the chin guard they read as fingerless gloves: dark grey backs, bare fingertips and thumbs, a cuff. **Plain**: no strap, stud or knuckle plate shows, only the outline and a band or two. At the jab's and the cross's landing the glove fills the top of the lens as one large flat dark shape with the hit burst on it, so the fist is a mass there, not a detailed glove. |
| **J4\*** ink: even, continuous, not heavy, crisp inside, no doubles | C2 `f109`; C1 `f109` | `EV/c2/sheets/c2/crops/c2_f109_body.png`; `EV/c1/sheets/c1/crops/c1_f109_head.png` | The silhouette hull is continuous and even around the cap, the head, the arms and the vest, and not heavy. No doubled outline seen. Inside, the lines are crisp on the cap and the face but **ragged and dashed on the vest edges and the tape wraps** (dotted strokes along the placket, broken wraps on the forearm). |
| **J5\*** shading: 2-3 bands, tinted shadows, one highlight, rim | C2 `f109`; C10 `f51_rest_q0` | `EV/c2/sheets/c2/crops/c2_f109_body.png`; `EV/montages/c10_turntable_rest_q0_q90_q180_q270.png` | The vest has three bands (teal, a mid teal and a blue-violet shadow), the face a lilac shadow side; shadows are tinted, never black. One small white glint, on the lens. The rim is faint at best. The probe: L2 MET, 3 bands front-lit, shadow/lit 0.66 ([look.json](look.json)). |
| **J6** palette: 4-6 flat colours; muted street; red only for blood and warnings | C7 `f109_lineup_t060`; C2 | `EV/pairs/c7/stills/c7_f109_lineup_t060_m3_left_m4_right.png` | The Punk's colours are teal, yellow, tan, black, a grey-blue jean and cream: clean borders, no red. The street is muted and darker than M3's. **The placeholders beside it are louder**: lime, olive and purple. Red appears only as blood and the "!" warning (A3: none of the 313 room surfaces is in the red band; the car is muted). |
| **J7** surface: no holes, spikes, floaters, z-fighting, seams or UV smears | C10 every quarter; C1, C2 | `EV/montages/c10_turntable_rest_q0_q90_q180_q270.png`, `EV/montages/c10_turntable_guard_q0_q90_q180_q270.png`; `EV/c10/sheets/c10/stills/` | No hole, spike, floater or z-fight seen in the four quarters at rest, in the guard and lying. The vest hem and armholes are ragged by design. **Small dark specks on the cap's crown from behind** (C12 `f1289_spine_twist_90`, in `EV/montages/c12_extremes_guard_elbow150_armraise140_knee130_twist90_deepknee.png`). |

### In motion at 1 m (12 fps sheets and the long take)

| Item | Act, frame | Files | What the frame shows |
| --- | --- | --- | --- |
| **J8\*** deformation keeps volume | C3 strafe; C4 jab, cross, shove; C5 flinch, stagger, knockdown, get-up; C12 extremes | `EV/fps12/c3_12fps_01.png` to `_03`, `EV/fps12/c5_12fps_01.png` to `_07`; `EV/montages/c12_extremes_guard_elbow150_armraise140_knee130_twist90_deepknee.png`; `EV/c12/sheets/c12/stills/` (44 stills) | In the guard, the elbow at 150, the arm raise at 140, the knee at -130, the spine twist, the strafe and the hook stagger the shoulders, elbows and knees keep their volume: no candy-wrap, no collapse, no self-intersection seen. The raised arms at 140 are long, thin forearms. **The numbers do not agree with the eye:** A7 is not met on either GLB (section 1). |
| **J9** life: breathes, no pops, feet plant | C14 the long take; C3 | `EV/clips/long_take_1m_c14.mp4`; `EV/c14/sheets/c14/overview_01.png`; `EV/seams/c14_seams_950_1731_1873_2161.png` | The idle moves, but subtly (the fists and shoulders drift; the frame-to-frame difference of the idle is 0.0006 on average). **The feet are out of the frame at 1 m** (the view shows the Punk from the knees up), so planting is the number (A4: the Punk's four walks slide at most 1.25 cm, the lowest sole -5.4 mm) and the walk-in at about 3 m in the clip. For pops: a frame-difference scan of C14 finds one-frame steps of 0.03-0.04 at the scripted seams (f950, f1731, f1874, f1933, f2161, f2221) against 0.0016 for an ordinary frame; four seams looked at frame by frame (640 px) show no visible snap. I cannot rule out a one-frame blend start from the stills; the clip is the evidence. |
| **J10** contact: fist reaches, flash on the struck spot, stagger follows the ragdoll, KO slump and blink-off | C5; C13 (the same with the impact frame off); C11 | `EV/pairs/c5/stills/c5_f44_jab_1_took_...`, `c5_f149_hook_took_...`, `c5_f149_state_stagger_...`, `c5_f165_uppercut_took_...`, `c5_f629_ko_slump_...`, `c5_f674_ko_blink_off_...` (all `..._m3_left_m4_right.png`); `EV/fps12/c5_12fps_02.png`; `EV/montages/c5_ko_state_lying_blink_off_blink_on.png` | The jab and the hook land on the jaw with a white glow, the burst and lettering (SMAK!) on the struck spot; the hook staggers him back with his arms out; the uppercut launches him (an impact frame of white and black ink, WHUMP!), he flies, lies, and the KO view shows the body, then blinks it off for a frame (the street and blood marks stay) and on again. The fist reaches the head in the player's own arm, which is large in the frame. |
| **J11** damage looks stick | C5 `f411_health_100`, `f471_health_65`, `f531_health_30`; C14 `lying` | `EV/pairs/c5/stills/c5_f471_health_65_...`, `c5_f531_health_30_...`; `EV/c14/sheets/c14/stills/` | Clean, then bruised at 65% (violet on the forearm and the face, grey scuffs on the vest, no blood yet), then bloodied at 30% (red splats on the cap, vest, tank and gloves, a purple bruise on the forearm): each reads at 1 m and rides the body through the stagger and the lying poses. **The bloodied wash reads grey-lilac and glassy over the vest.** |
| **J12** wind-ups read at 1 m and at 2.5 m | C4 `f40_punk_jab_windup`, `f82_punk_cross_windup`, `f153_punk_shove_windup`; the six-Punk fight | `EV/montages/c4_attacks_windup_strike_jab_cross_shove.png`; `EV/montages/six_windups_f339_to_f1206.png` | The first frame of a wind-up has barely left the guard (the montage's frames are the start of each). **Mid wind-up it reads clearly at 1 m**: the jab cocks the far fist back above the shoulder (f50, f58), the cross swings the right arm out wide (f86), the shove spreads both arms like a hug (f160, f166); `EV/montages/c4_midwindup_jab_f44_f50_f58_cross_f86_shove_f160_f166.png`. **No still shows a 2.5 m wind-up**: in the twelve wind-ups cut from the six-Punk fight the attacker is within about 1.5 m. The 2.5 m reading is the probe's: R2 56 f minimum gap, R3 0 unwarned of 8, R10 100% of 16 ([readability.json](readability.json)). |

### Around it and the player

| Item | Act, frame | Files | What the frame shows |
| --- | --- | --- | --- |
| **J13** one game | C7 lineup; C9 tour; C5 VFX; C13 | `EV/pairs/c7/stills/c7_f109_lineup_t060_m3_left_m4_right.png`; `EV/pairs/c9/stills/c9_f489_tour_t0450_m3_left_m4_right.png` (and six more); `EV/pairs/c5/stills/c5_f149_hook_took_...`; `EV/pairs/c13/stills/` | The Kicker, Thug and Bruiser wear the same ink hull and bands as the Punk and the street has the same edge lines, a darker grade and a blue car: one ink language. **They are visibly less detailed**: faceless blocks beside a Punk with a mask, wraps and tears. The lettering and the burst carry a heavier black outline than the hull (about twice, by design: P1-fx). The street is flatter and greyer than M3's. |
| **J14\*** his own arms and legs in first person | PA1; C8; C11 | `EV/montages/pa1_idle45_jab_hook_frontkick_guard_knee.png`; `EV/montages/c8_own_limbs_jab45_hook45_guard45_jab20_guard20_walk65.png`; `EV/montages/c11_hold_grab_knees_regrab_throw.png`; `EV/pa1/sheets/pa1/stills/` (48) and `crops/`; `EV/clips/own_limbs_pa1.mp4`; `EV/concept_pairs/hero_concept_left_first_person_limbs_right.png` | When they are in the view they are the most detailed thing on screen: wrapped forearms with ink wraps, dark fingerless gloves, a grey trouser leg with ink folds, a black shoe with a cream toe cap (the front kick), the hold's knee under the held Punk's cap. No hollow cut, seam or pop at the head/torso split seen; nothing clips the lens (the block guard is 0.336 m away). **But they are often not in the view**: at 45 degrees down the idle and the guard show only the street and the shadow of the arms; in strikes the forearm is a large flat skin-tone slab, and I could not pick out an elbow cap in the frames I looked at. |

## 4. Before and after (C1, C2, C5, C7, C9, and C13)

M3 left, M4 right, same frame number, 3200x900 (crops scaled to the same height). M3 sides: `captures/m4_before/` for C1, C2, C7; `captures/m4_before_recut/` for C5, C9, C13 (re-cut with the new act framing).

| Act | Stills | Crops | Frames |
| --- | --- | --- | --- |
| C1 face at +8 | `EV/pairs/c1/stills/` | `EV/pairs/c1/crops/` | f49, f109, f169, f229 |
| C2 body at -6 | `EV/pairs/c2/stills/` | `EV/pairs/c2/crops/` | f49, f109, f169, f229 |
| C5 reacts | `EV/pairs/c5/stills/` (30) | `EV/pairs/c5/crops/` (75) | the jab, the hook stagger, the uppercut launch, downed, get-up, health 100/65/30%, the KO and its blink |
| C7 lineup | `EV/pairs/c7/stills/` | `EV/pairs/c7/crops/` | f49, f109, f169, f229 |
| C9 street tour | `EV/pairs/c9/stills/` (7) | (the tour has no rectangles) | f189 to f1089 |
| C13 impact frame off | `EV/pairs/c13/stills/` (30) | `EV/pairs/c13/crops/` (75) | as C5 |

## 5. The clips (H.264, 1280x720, 60 fps, with the game's sound)

| Clip | Size | What it shows, honestly |
| --- | --- | --- |
| `EV/clips/long_take_1m_c14.mp4`, the 40 s long take at 1 m | 5.2 MB, 40.2 s | One scripted first-person take of one Punk at 1 m (`game/debug/showcase_script.gd`): idle (breathing), a turntable, it backs off and walks in, a taunt, a jab and a cross at the lens, it takes a jab, staggers, is knocked down and lies (bloodied) for about 2.5 s, gets up, turns its back, falls face down and gets up, turns, and is KO'd. **Two stretches are nearly still**: the idle (the first 5 s) and the lying (2-3 s, twice). The jab and the cross put a dark glove across the lens for a moment. The pose changes at the scripted seams are clean to the eye. 22 steps. |
| `EV/clips/six_punk_fight_2_to_10m.mp4`, six Punks | 7.7 MB, 28.6 s | `Six Punks, fight`: six art Punks walk in from the surround points, the autopilot fights them in god mode for 25 s, a Punk walking in whenever one falls. They approach from a distance (the first frames show one far down the street), posture, wind up, and the warning icon ("!") shows when one winds up out of view; the player's fists and a "PARRY!" appear. Punks go bloody as they are hit. **Most of the fight is at 1-3 m**, not at 10 m; the bot's caption "Six Punks, fight" is at the top of the frame. R1 max 1 attacker, R3 0 of 8 unwarned, R8 misses its soft bar (p50 29%). |
| `EV/clips/own_limbs_pa1.mp4`, the player's limbs | 1.6 MB, 10.6 s | `Look: my arms and legs` from 1.7 s: looking 45 and 65 degrees down (little in view), then at -20 degrees the jab, cross, hook and uppercut, the front kick (leg, trouser and shoe), the block's guard (the lens sees only the street and the GUARD bar), the spin kick, a jab, the haymaker's charge and swing, then a Punk held 1.1 m ahead and kneed (the knee, his wraps and gloves at the lower corners, the white flash on the cap). **About five of the twelve seconds sampled show no limb at all**; the strongest seconds are the kick, the haymaker and the hold. |

## 6. The four feel questions (A/B stills, each at today and at its suggested value)

The toggles are Tuning > Look > FP feel (F1), each defaulting to today. Figures are the acts' own (`FLASH-FP` lines) unless marked as mine.

| Question | Toggle: today / suggested | Stills | What changes |
| --- | --- | --- | --- |
| **1. Flash size in first person** (the hold's knee, grab-05) | `hit_flash_fp_max_share` 0 / 0.12 | `EV/feel_ab/q1_hold_knee{1,2,3}_flash_share_today_0_left_cap_0p12_right.png` from `EV/ff2/` (act 'Look: flash share, hold knees') | Today the knee's flash washes the cap and the shoulder white: **the flash changes 21.7% of the view** (4.9% pure white). At 0.12 it is a small glow on the cap's edge beside the burst: **4.8%** (0.8% white), 3 knees each. The jab loses 40% of its flash at 0.12 (P3-flash). |
| **2. The haymaker's flash** | `hit_flash_finisher_radius_mult` 1.0 / 2.0 | `EV/feel_ab/q2_haymaker_...` and `q2_uppercut_...` from `EV/ff3/` | The finisher at 1 m changes **0.2% of the view today** (the burst and the lettering carry it, the Punk looks unhit). At 2.0: **6.6%** for the haymaker (the raised arm and the vest edge go light), **3.5%** for the uppercut (today 0.3%). The act's first hit is the held jab, so the haymaker is its hit n2. |
| **3. The "belly slab" when he is knocked down** | `fp_knockdown_hide_torso` false / true | `EV/feel_ab/q3_my_knockdown_f{121,146,171}_..._false_left_true_right.png` from `EV/pa2/` and `EV/pa2_hide/` | Lying, the hero's navy torso is **about a third of the frame** (32-34% of pixels by a navy colour count, my own measure from the stills). Hidden, it is **about 11%** and the standing Kicker shows above it. A navy lump remains in front of the lens (the belly and hips), so it shrinks, it does not go. |
| **4. The combat log over the knee in a hold** | `combat_log_hide_while_holding` false / true | `EV/feel_ab/q4_hold_f{68,100,40}_..._false_left_true_right.png` from `EV/c11_log_show/` and `EV/c11_log_hide/` | The log is a grey panel with the hit line over the glove and the knee's burst (f68, f100); hidden, the knee's burst and the glove read clean. Recorded with a scratch bot that leaves the log on, because the crowd bot hides it (calls C2). At the grab (f40) it is an empty panel, its header across the Punk's right glove. |

## 7. The JSON files

| File | Holds | Headline |
| --- | --- | --- |
| [art_metrics.json](art_metrics.json) | A1-A14: state, the figures verbatim, the plan's bar, the ratchet, the full run (1593 of 1593, 74 scripts, 301.1 s, 0 error lines) and the evidence logs' error count | 9 PASS (A1, A2, A3, A5, A8, A10, A12, A13, A14), 5 GATE (A4, A6, A7, A9, A11): the plan's bar is not met on them |
| [look.json](look.json) | L1-L5: the final probe's rows with their numbers and `LOOK-FINAL` lines, the acts' slugs, and L4's perf figures (marked loaded, earlier heads) | L1 MISSED (10 m hull 2.0-2.6 px; own top 4.05), L2 MET, L3 MET (3.6% against 6.3%), L5 MET |
| [readability.json](readability.json) | R1-R15 of `Waves to the boss` (56.4 s, the 60 s autopilot act) and `Six Punks, fight` (27.4 s) with the art on, `check_m3_log.py`'s verdicts, and R4 and R8 with the art drawn beside the proxies | hard rows (R1-R3, R10, R11) met on both; soft misses R6 and R7 (waves) and R8 (six); R4 0 hidden, R8 within 2.1 points |
| [ledger.json](ledger.json) | the 12 Tripo tasks with their real credits, the balance, the Gemini images by job file | 295 credits, balance 1205, 23 Gemini images |
| [strain_worst10.json](strain_worst10.json) | A19's worst ten per shipped GLB, the peak flexes, the verdict and the ratchets | the Punk's worst ten are squashed edges (to 2-5% of rest length), the hero's are stretches (30-37x), in the get-ups, the run and the head flinch; A7 not met |

## 8. The recordings

One act per process. Each directory holds `bot.avi`, `bot.log`, `readability.json` (or `look.json`), `stills/` (the 6 fps stills `capture_bot.sh` takes) and, where the act prints marks, `sheets/<slug>/` (overview pages, full-resolution stills at every mark, head, hands and body crops). 0 error lines in every log.

| Dir | Act | Title | Frames | Seconds | Stills | Crops | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `c1` | C1 | Look: Punk face at 1 m | 290 | 4.8 | 4 | 12 | |
| `c2` | C2 | Look: Punk body at 1 m | 290 | 4.8 | 4 | 12 | |
| `c3` | C3 | Look: Punk strafes at 1 m | 392 | 6.5 | 8 | 24 | |
| `c4` | C4 | Look: Punk attacks at 1 m | 298 | 5.0 | 19 | 36 | |
| `c5` | C5 | Look: Punk reacts at 1 m | 795 | 13.2 | 30 | 75 | |
| `c6` | C6 | Look: distances | 440 | 7.3 | 4 | 12 | |
| `c7` | C7 | Look: lineup | 290 | 4.8 | 4 | 12 | |
| `c8` | C8 | Look: own limbs | 696 | 11.6 | 35 | 53 | |
| `c9` | C9 | Look: street tour | 1244 | 20.7 | 7 | none | |
| `c10` | C10 | Look: turntable | 1634 | 27.2 | 15 | 45 | |
| `c11` | C11 | Look: hold the Punk | 358 | 6.0 | 15 | 39 | |
| `c12` | C12 | Look: extremes | 3230 | 53.8 | 44 | 76 | 6 fps overviews only (30 pages at 12 fps) |
| `c13` | C13 | Look: Punk, impact frame off | 795 | 13.2 | 30 | 75 | |
| `c14` | C14 | Look: Punk at 1 m, the long take | 2520 | 42.0 | 40 | 117 | the clip's source |
| `pa1` | PA1 | Look: my arms and legs | 1114 | 18.6 | 48 | 65 | the limbs clip's source; `LOOK-PLAYER art hero 19868` |
| `pa2` | PA2 | Look: my knockdown | 287 | 4.8 | 10 | 17 | feel 3, today |
| `t8` | T8 | Look: tune own hull | 174 | 2.9 | 1 | 2 | L1's own body |
| `fp` | FP | Look: final probe | 4474 | 74.6 | none | none | `look.json` with the `final` key, the `LOOK-FINAL` lines |
| `l5` | L5 | Look: readability with the art drawn | 3778 | 63.0 | none | none | R4 and R8, art and proxies |
| `six` | | Six Punks, fight | 1714 | 28.6 | none | none | clip 2's source; R1-R15 |
| `waves` | | Waves to the boss | 3455 | 57.6 | none | none | the 60 s autopilot act; R1-R15 |
| `ff2` | FF2 | Look: flash share, hold knees | 1085 | 18.1 | 20 | 60 | feel 1, every cap in one run |
| `ff3` | FF3 | Look: flash share, haymaker and finishers | 2275 | 37.9 | 48 | 144 | feel 2, every multiple in one run |
| `pa2_hide` | PA2 | Look: my knockdown | 287 | 4.8 | 10 | 17 | `--tune=fp_knockdown_hide_torso=1` |
| `c11_log_show` | C11 | Look: hold the Punk | 358 | 6.0 | 15 | 39 | feel 4, log shown (scratch bot) |
| `c11_log_hide` | C11 | Look: hold the Punk | 358 | 6.0 | 15 | 39 | feel 4, `--tune=combat_log_hide_while_holding=1` |

Also in `EV/`: `full_suite.log` (the full run, 1593 of 1593), `fps12/` (12 fps sheets of C3, C4, C5, C11), `montages/` (contact sheets of the three clips and the montages cited above), `seams/` (the four seams of the long take), `windups/` (the twelve wind-up stills of the six-Punk fight and the mid-wind-up frames of C4).

## 9. What this pack does not show

- **Scores.** The re-scorer's J1-J14 is the judgement; this index describes frames.
- **L4 on the final head, or on a quiet machine.** Section 1, line 4.
- **`Mixed waves` and `Waves` (90 s) on the final art.** The 60 s act is `Waves to the boss`.
- **A 2.5 m wind-up still** (J12).
- **The slice gate's bind-route and weights A/B stills** (B3's "Assets and money" line): they are in the lead's `captures/sl-int/ab/` and the gate's records, not recorded again here.
- **A labelled side by side**: left is M3, right M4, in every file name.
