# M6 calls: AUDIO

Package AUDIO (branch `m6/audio`). Each call: decision; alternatives not taken; why.

## The measured ElevenLabs rate (first call, D18)

- **Call 1:** one 0.5 s job (`probe/probe_grunt_01`, model `eleven_text_to_sound_v3`, `mp3_44100_128`, `duration_seconds` 0.5). The subscription counter (`character_count`) read 0 before and 0 right after: it **lags the call**. Call 2 (1.0 s, `probe/probe_effort_01`) read 5 after (call 1's share arrived a call late); the counter read 15 once settled (30 to 60 s later).
- **Rate: 15 credits for 1.5 s = 10 credits a second**, not the docs' 40. Confirmed by 7 takes of 0.8 s that settled at 56 = 7 x 8 (the counter lags: its first reads said 0), and by the whole batch below.
- **The projection rule** (brief): rate x summed durations x candidates. The voices are 57 clips (the plan's counts: per archetype 4 grunts, 3 efforts, 2 KO lines; the shared 4 and 3; 3 player grunts; 2 boss phases) of 0.7 to 2.0 s; at **three candidates each that is 171 takes and 1626 credits** (the tool's dry run: 162.6 s of audio at 10 a second), under the 6000 ceiling, so **no cut was needed**: all 57 clips, **three candidates each** (the brief says two when the budget allows; three costs about 540 more credits and gives the choice more to choose from), no minimum-per-pool fallback, no stop commit.
- **Final spend: 1649 credits** (173 calls: 2 probes at 15, 171 voice takes at 1634) of the package's 6000 and the milestone's stop of 30000; 38351 credits remain on the account for SFX. The ledger's total equals the account's (`eleven_sfx.py --balance`).
- Counter lag and rate limit: polling the subscription before and after every call hit HTTP 429 after 7 calls (the first run stopped at the poll before its 8th call; its 7 takes were on the ledger and nothing was lost). The tool now writes the ledger line first, reads the counter every 20 calls and after the run settles, retries 429 after 8, 20 and 45 s (a 429 is refused before work, so a retry is safe), and `settle` lines carry the difference so the ledger's total is the account's. The policy's `credits_per_second` is 10.

## Calls

1. **Three candidates per prompt, one prompt per kept variant.** Each kept variant has its own prompt (a different vowel and situation: "ugh", "oof", "agh", "hunh"), so the four grunts of a pool differ in sound, not only in the take. *Not taken:* one prompt with 8 candidates and the best four (the takes would be near-duplicates); two candidates (cheaper by 500 credits, no need).
2. **Choosing by measured features** (`ingest.py --analyze`, the ear is Game-boy's): per prompt the take whose active length (onset less 3 ms to the last sound above -40 dB of its peak) is nearest a target (grunt 350 ms, window 150 to 750; effort 300, 120 to 500; KO 900, 500 to 1350; player grunt 300; boss phase 1500, 1100 to 1900), penalising a flat-topped peak (over -0.5 dBFS), a mostly-air take (rms under -26 dBFS) and a high crest. A grunt's pain should be short and an effort must not outlast its 0.3 s wind-up by much. Seven efforts or grunts came out of their window (the three takes of the prompt were all long) and are cut at `max_s` with a 60 ms fade. The table is below. *Not taken:* picking by prompt order (take 01); picking the loudest.
3. **Loudness by RMS, not peak, for voices** (`rms_db` -16, peak capped at -1 dBFS). Peak normalisation left the takes of a pool 8 dB apart in loudness (a short breathy effort versus a grunt with a hard onset); by RMS they are within about 4 dB. The hit stack stays peak-normalised at -1 dBFS (the generator's rule). *Not taken:* `lufs` (unreliable under 0.4 s).
4. **The boss and the Bruiser are prompted "deep, natural speed", not "very/extremely deep".** `voice_pitch_mult` (0.8 and 0.7) stays a multiplier, so a voice prompted extremely deep and then slowed by 0.7 would double up (and a 1.0 s sample plays 1.43 s). The first prompts for the Bruiser and boss said "very/extremely deep"; I stopped the run before those jobs, changed the wording and resumed, so no take was wasted. *Not taken:* ingesting at the pitch already lowered (the scene's multiplier is the knob Game-boy can turn).
5. **KO pool fallback is silence, not the shared pools.** The brief gives `grunt` and `effort` shared pools; there is no shared `ko`, so the dummy and any enemy without a `ko_<archetype>` pool plays no KO line, and the grunt of the killing blow is not cut. *Not taken:* falling back to `grunt` (a second grunt would play on top of the killing blow's own).
6. **A KO line cuts the killing blow's grunt** (`_grunt_voice` per actor). The two are on the same frame (the finishing hit grunts, then `ko`); both would talk over each other. Same reasoning as the wind-up cut in M2.
7. **`weapon_<impact_sfx>_hit` layers on the tier's stack** and does not replace it, at `weapon_hit_db` plus the tier's gain (clean hits only; a block or an armor absorb keeps its own clack). A pipe hit is a thud plus a clang. *Not taken:* replacing the thud (a pipe hitting a body should still thud; SFX can drop the weapon layer's level to 0 dB-floor if Game-boy prefers).
8. **The weapon pools' names for the two weapons are `weapon_pipe_hit` and `weapon_bike_chain_hit`**, i.e. `impact_sfx` = `pipe` and `bike_chain`: slots are declared for them (min 2, empty until SFX). WEAPONS owns the values in `gen_moves.gd`; if it uses other ids, SFX renames the slots in the manifest (data only).
9. **Ambience is forced to loop in code** (`_looped`): the bed's `.import` would need `edit/loop_mode=2` hand-written per file, which a new file does not have until Godot imports it. *Not taken:* writing `.import` files by the ingest tool (the uid and the cache hash are Godot's).
10. **The bed has its own two players, crossfading, outside the pool;** `play_2d()` has its own four. Beds and stings must not take pooled voices (the six-enemy worst case already asks 36 of 32). *Not taken:* putting the bed on the music player (music has its own volume, switch and bus).
11. **`audio_legacy_bank` is read inside the director** (`bank_for()`), not only in the audition room, so `-` also A/Bs the real hits in a fight. The legacy folder is loaded the first time the switch is on. A pool the placeholders never had (an archetype's voice) comes from the new bank either way.
12. **`gen_sfx.gd` writes to `tests/fixtures/sfx_legacy/`** (D24). The 39 files there are the generator's output (rerunning it leaves git clean), including the music loop so the folder is the whole generator's output; the 38 SFX are all that A/B needs. The `gen_sfx` rows in `assets/export/sfx/` are byte-identical copies, which `--check` and a test verify, so SFX's replacement of a row is one `--picks` away.
13. **The manifest's slots include the other packages' pools now** (barriers, weapons, stings, beds) with `min_variants` 2 (1 for stings and beds), so `empty_slots` is 16 from this package's merge and SFX's done-when is its drop to 0. SFX may change a number.
14. **`rms_db` and `peak_cap_db` are manifest row fields beyond the plan's `peak_db | lufs`;** `gain_db` is the number found from them and what `--check` rebuilds with, so the rebuild never has to re-find anything.
15. **No Sonniss anything** (D19): `ingest.py` has no download or SONNISS_DIR path, any `source` string is accepted by name (`gen_sfx`, `elevenlabs:<id>`; a recorded library would add its own form).
16. **MP3s per candidate are all committed** (171 takes, about 2.8 MB in LFS): the unchosen takes are the audition's alternates, and `--check` needs only the chosen ones. ASSETS rows list the source folders (a row per folder, the test accepts a folder row) and one row per shipped wav.
17. **The audition room's help rows are three, not five** (`]` with `[`, `1` with the digits and `=`, `-`): the help overlay's right column is already full.

## Voice choices (chosen by measured features)

| Pool | Takes chosen (active ms / peak dBFS / rms dBFS of the raw take) |
| --- | --- |
| grunt_punk | grunt_punk_v1_01 (444 / -1.6 / -16.5); grunt_punk_v2_02 (737 / -8.3 / -24.2); grunt_punk_v3_03 (476 / -3.8 / -19.2); grunt_punk_v4_02 (395 / -1.1 / -15.9) |
| effort_punk | effort_punk_v1_02 (445 / -3.5 / -20.9); effort_punk_v2_02 (305 / -1.8 / -17.7); effort_punk_v3_03 (557 / -1.0 / -19.4) |
| ko_punk | ko_punk_v1_03 (1011 / -1.8 / -18.2); ko_punk_v2_02 (1033 / -1.3 / -20.2) |
| grunt_kicker | grunt_kicker_v1_03 (365 / -2.0 / -17.0); grunt_kicker_v2_01 (620 / -5.7 / -19.2); grunt_kicker_v3_01 (470 / -2.6 / -18.8); grunt_kicker_v4_01 (355 / -7.2 / -20.1) |
| effort_kicker | effort_kicker_v1_01 (307 / -4.1 / -20.9); effort_kicker_v2_02 (207 / -1.5 / -17.4); effort_kicker_v3_02 (533 / -1.1 / -20.2) |
| ko_kicker | ko_kicker_v1_01 (985 / -1.4 / -17.2); ko_kicker_v2_02 (1028 / -1.9 / -15.6) |
| grunt_thug | grunt_thug_v1_03 (622 / -6.7 / -21.7); grunt_thug_v2_02 (535 / -2.8 / -16.2); grunt_thug_v3_03 (560 / -1.3 / -16.1); grunt_thug_v4_02 (542 / -4.1 / -18.7) |
| effort_thug | effort_thug_v1_03 (532 / -2.4 / -21.0); effort_thug_v2_02 (343 / -1.2 / -17.4); effort_thug_v3_03 (543 / -3.3 / -19.8) |
| ko_thug | ko_thug_v1_01 (936 / -3.1 / -17.9); ko_thug_v2_01 (926 / -3.1 / -18.8) |
| grunt_bruiser | grunt_bruiser_v1_03 (364 / -1.3 / -14.9); grunt_bruiser_v2_01 (593 / -1.5 / -12.2); grunt_bruiser_v3_03 (504 / -1.3 / -18.8); grunt_bruiser_v4_01 (355 / -1.7 / -13.0) |
| effort_bruiser | effort_bruiser_v1_02 (307 / -1.8 / -16.1); effort_bruiser_v2_03 (307 / -1.6 / -18.7); effort_bruiser_v3_03 (598 / -2.4 / -17.0) |
| ko_bruiser | ko_bruiser_v1_03 (1194 / -2.3 / -17.3); ko_bruiser_v2_01 (1094 / -1.3 / -18.3) |
| grunt_boss | grunt_boss_v1_01 (523 / -0.8 / -17.6); grunt_boss_v2_02 (843 / -4.2 / -15.4); grunt_boss_v3_02 (706 / -1.9 / -20.0); grunt_boss_v4_02 (363 / -3.8 / -15.8) |
| effort_boss | effort_boss_v1_03 (423 / -3.9 / -23.0); effort_boss_v2_03 (253 / -0.8 / -16.0); effort_boss_v3_03 (765 / -1.3 / -17.3) |
| ko_boss | ko_boss_v1_03 (1139 / -2.2 / -19.0); ko_boss_v2_02 (1182 / -2.7 / -16.9) |
| grunt | grunt_v1_03 (363 / -2.8 / -16.6); grunt_v2_02 (674 / -2.1 / -16.7); grunt_v3_03 (478 / -1.5 / -16.9); grunt_v4_03 (286 / -1.6 / -17.0) |
| effort | effort_v1_03 (292 / -1.7 / -17.8); effort_v2_03 (280 / -2.1 / -17.2); effort_v3_03 (428 / -2.1 / -18.6) |
| player_grunt | player_grunt_v1_02 (360 / -1.5 / -12.8); player_grunt_v2_03 (295 / -1.0 / -14.1); player_grunt_v3_02 (587 / -6.4 / -19.7) |
| boss_phase | boss_phase_v1_03 (1711 / -1.8 / -17.7); boss_phase_v2_03 (1725 / -1.8 / -18.7) |

The choice list is also `assets/source/sfx/eleven/voices.picks.json` (the input of `ingest.py --picks`). Per-pool ffprobe and loudness of the shipped wavs (16-bit mono 44.1 kHz, `ingest --check` verifies the format; peak -1.0 to -5.3 dBFS and rms -16.0 to -20.1 dBFS inside every pool):

| Pool | Files | Length s | Pool | Files | Length s |
| --- | --- | --- | --- | --- | --- |
| grunt | 4 | 0.29-0.67 | ko_punk | 2 | 1.01-1.03 |
| effort | 3 | 0.28-0.43 | ko_kicker | 2 | 0.98-1.03 |
| player_grunt | 3 | 0.29-0.59 | ko_thug | 2 | 0.93-0.94 |
| grunt_punk | 4 | 0.39-0.74 | ko_bruiser | 2 | 1.09-1.19 |
| grunt_kicker | 4 | 0.36-0.62 | ko_boss | 2 | 1.14-1.18 |
| grunt_thug | 4 | 0.53-0.62 | effort_punk | 3 | 0.30-0.56 |
| grunt_bruiser | 4 | 0.36-0.59 | effort_kicker | 3 | 0.21-0.53 |
| grunt_boss | 4 | 0.36-0.84 | effort_thug | 3 | 0.34-0.54 |
| boss_phase (long) | 2 | 1.71-1.72 | effort_bruiser, effort_boss | 3 + 3 | 0.31-0.60, 0.25-0.76 |

## Placeholder inventory: the drop this package expects (per scene, same in the level, the crowd street and the training room)

- `generated_sfx`: the manifest rows whose source is `gen_sfx` fall from 12 pools to 9 (`grunt`, `effort` and `player_grunt` are ElevenLabs now; the hit stack, the blocks and `music_loop` stay; `music_loop` is allowed by name, D25).
- `empty_slots`: **starts at 16** in every scene (barriers 6, weapons 6, stings 2, beds 2); SFX takes it to 0.
- Other categories: no change.

## Requests (changes in files AUDIO does not own)

- **DRESS:** set `LevelSection.ambience` in the Mission 1 scenes (`&"ambience_street"` for the street sections, `&"ambience_roof"` for the roofs and the boss roof); with it empty the bed is the street everywhere.
- **KIT:** `section_entered` must be emitted for the director to follow sections (step 0 declared it; KIT owns the emit).
- **WEAPONS:** `MoveData.impact_sfx` values `pipe` and `bike_chain` (the pools are `weapon_pipe_hit`, `weapon_bike_chain_hit`), emit `weapon_landed`; the director also needs `weapon_picked_up`, `weapon_thrown` and `weapon_broke` to keep carrying the weapon node (it plays at `weapon.global_position`).
- **LOOKS (ratchet):** `generated_sfx` 12 -> 9 pools and `empty_slots` 16 at this merge.
- **Lead:** the merge regenerates `tuning/default.json` (this branch's copy is generated); `tools/audio/eleven_policy.json`'s rate 10 is measured, tell SFX.

## Evidence

- Full suite on this branch: 1794 of 1794 pass (1766 at M5's end, +27 in `test_audio_m6.gd`, +1 in `test_audio.gd`), 320 s, no SCRIPT ERROR, SHADER ERROR or ERROR.
- `python3 -I tools/audio/ingest.py --check`: 85 rows, 0 problems, 16 empty slots. `gen_sfx.gd` rerun leaves `tests/fixtures/sfx_legacy/` unchanged.
- No captures: the package has no visual work beyond the audition room's one label.
- The lead plays the audition room: training room (F6 twice), `]` pages the banks, `1` to `9` play variants, `-` old and new, `=` the whole bank.
