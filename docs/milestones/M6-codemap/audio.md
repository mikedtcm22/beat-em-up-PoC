# M6 codemap: audio

Facts with file:line. Read-only survey; nothing was run, generated or downloaded. Paths are relative to the repo root.

## 0. Shape of the system today

- `game/audio/audio_director.gd` (511 lines) is the only sound player. It is a Node added by `RoomKit` (`game/level/room_kit.gd:187`), joins group `audio_director` (`audio_director.gd:132`), builds an `SfxBank` (`:135`), a 32-voice pool of `AudioStreamPlayer3D` (`:93`, `:139-153`), and a 2D `AudioStreamPlayer` for music (`:154-158`).
- `game/audio/sfx_bank.gd` (57 lines) scans one folder, `res://assets/export/sfx/` (`sfx_bank.gd:8`), for `*.wav` named `<pool>_<nn>.wav`; the pool is the name up to the last `_` (`:25-34`). `pools: Dictionary[StringName, Array]` (`:12`). `pick()` never repeats the last variant per pool (`:48-57`). Only `.wav` is loaded (`:23`); `.ogg`/`.mp3` are ignored.
- Only 5 CombatEvents signals are subscribed (`audio_director.gd:159-163`): `hit_landed`, `attack_whiffed`, `windup_started`, `windup_ended`, `grab_escaped`. Nothing else makes a sound: no footsteps, jump, land, dodge, KO, knockdown, weapon, barrier, GO, CLEAR, boss, ambience (grep of `game/` finds no other `AudioStreamPlayer` outside `game/audio`; `RumbleDirector` is haptics only, `rumble_director.gd:4`).
- Buses are created in code if the project has none (`audio_director.gd:497-504`): "SFX" (Master send, hard limiter), "SFX Rear" (send to SFX, low-pass), "Music" (Master). No `default_bus_layout.tres` dependency.

## 1. Bank to event map

Files on disk: `assets/export/sfx/` has 39 wavs: 38 SFX in 12 banks plus `music_loop_01.wav` (counts from `ls`; generator loop `tools/gen_sfx.gd:148-174`).

| Bank | Variants | Played when | Space | Volume (Tuning) |
|---|---|---|---|---|
| `whoosh` | 4 | Hit swing layer, once per swing (first victim only, not for `input_timing == &"body"`) `audio_director.gd:238-266`; whiff `:268-272`; windup `:274-290`; grab break `:306-319`; block/armor too (`:247`, `:255`) | 3D at contact point, or striking limb (`_strike_position :394`) | `whoosh_db` -10 (`tuning_data.gd:1117`); whiff `whiff_db` -6 (`:1124`); windup `windup_db` -10 (`:1135`) |
| `thud` | 4 | LIGHT, HEAVY, FINISHER hits, per victim (`TIER_LAYERS :66-71`) | 3D contact | `thud_db` -8 |
| `crack` | 3 | HEAVY only | 3D contact | -7 |
| `crunch` | 3 | FINISHER | 3D contact | -10 |
| `body_fall` | 3 | FINISHER | 3D contact | -12 |
| `sub_thump` | 2 | FINISHER, once per swing (`SWING_LAYERS :74`) | 3D contact | -10 |
| `block_clack` | 3 | Blocked hit (`:245-252`); armor absorb pitched `armor_clank_pitch` plus `armor_clank_db` (`:253-257`); grab break (`:315`) | 3D | `block_clack_db` -2.5 |
| `parry_ting` | 3 | Perfect block replaces the clack (`:248-249`) | 3D | -6 |
| `guard_break` | 2 | `hit.guard_broken` adds it (`:250-251`) | 3D | -1 |
| `grunt` | 5 | Victim of a clean hit if enemy (`_grunt :362-383`); also grab-break holder (`:319`) | 3D at EyePoint (`_voice_position :386`) | `grunt_db` -9 (`:1127`) |
| `player_grunt` | 3 | Same, victim is player | 3D at eyes | -13 |
| `effort` | 3 | Enemy windup start, only while `Tuning.rear_warning_audio` (`:274-281`); cut if windup interrupted (`:292-303`) | 3D at eyes | `windup_db` -10 |
| `music_loop` | 1 | 2D `Music` player; plays only when `Tuning.music_enabled` (default false, `tuning_data.gd:1156`) via `_apply_mix :458-483` | 2D, bus Music, `music_volume_db` -14 (`:1157`) | |

Common behaviour of every one-shot (`play() :181-205`):
- Pool variant via `bank.pick()` (never the last one, `sfx_bank.gd:48`); pitch `pitch * (1 ± sfx_pitch_variation)` (0.08, `tuning_data.gd:1101`), volume ± `sfx_volume_variation` as amplitude (0.08, `:1103`).
- Tier boost `hit_light_db` 0 / `hit_heavy_db` +3 / `hit_finisher_db` +4 (`:1107-1109`), `extra_victim_db` -8 for later bodies of one swing (`:1112`).
- Distance: inverse-distance 6 dB per doubling beyond `sfx_unit_size_m` 3 m (`:1143`), culled beyond `sfx_max_distance_m` 40 (`:1145`); `AudioStreamPlayer3D` attenuation is disabled and `distance_db()` is applied every frame (`audio_director.gd:143-150`, `:168-177`, `:217`).
- Rear muffle: more than `rear_muffle_angle_deg` 110 off the look goes to bus "SFX Rear" low-passed at `rear_muffle_hz` 2500 (`:224-234`, `:195`).
- Hits on the player play `self_hit_offset_m` 0.5 toward the attacker, not at the contact point (`impact_position :322-333`).
- Grunt throttle: per-actor `grunt_min_interval_ms` 300 (`:1130`).
- Per-enemy pitch: `voice_pitch(actor) :351-361` = 1 + fixed random share of ±`voice_pitch_spread` (0.1, `:1132`), seeded by `hash(actor.name)`, times the actor's `voice_pitch_mult` export (`enemy_actor.gd:69`). Set in scenes: boss 0.7 (`game/enemies/boss/boss.tscn:10`), Kicker 1.12 (`kicker/kicker.tscn:8`), Bruiser 0.8 (`bruiser/bruiser.tscn:9`). Applies to `grunt`, `player_grunt`, `effort` only; hit layers pass pitch 1.0.
- Voice stealing: oldest voice, except live windup cues (`_take_voice :423-442`); counter `windup_voices_stolen` read by the readability probe (`tests/bot/readability_probe.gd:603-606`).
- Real-time, never scaled by hitstop or slow-mo (header `:47-50`).
- Gaps in the existing map: weapon hits are ordinary `hit_landed` (pipe moves `pipe_swing_1..3`, `tools/gen_moves.gd:218-222`) so a pipe sounds like a fist; one `grunt` pool serves Punk, Bruiser, Kicker, Pipe Thug and the boss (only pitch differs); no KO/death sound, no knockdown/get-up.

## 2. How a bank is defined, and what a manifest would change

- Today a bank is **files plus a naming convention only**; there is no data file. Slot name equals file stem minus `_<nn>`. A new bank needs: wavs in `assets/export/sfx/`, plus a code path that calls `play(&"slot", ...)` (`audio_director.gd:181`). `gen_sfx.gd` header says as much (`tools/gen_sfx.gd:5-8`).
- Gain is split: per-slot dB lives in `TuningData` (`@export_range` props, Audio group, subgroups Mix/Tiers/Layers/Voices/Blocks/Distance/Music/Rumble, `tuning_data.gd:1095-1179`), reached through `LAYER_DB` (`audio_director.gd:77-87`) for hit and block pools only. Grunt, effort, whiff and windup volumes are read directly (`:271`, `:371-383`). Any slot missing from `LAYER_DB` gets 0 dB (`layer_db :342-346`).
- To point a bank at new files today: drop `<slot>_NN.wav` over the old ones (same stems), or add more. Variants of different length are fine for pick(); there is no per-variant gain, so files must be pre-normalised (the generator normalises to a -1 dBFS peak, `gen_sfx.gd:27`, and says "a layer's volume in Tuning is its whole loudness", `:25-26`). The generator is not needed once real files exist but is the only thing that writes the current wavs; its output is deterministic (`:18-22`).
- Limits to design around: `SfxBank` only globs one folder, only `.wav`, and the pool name is "up to the last underscore", so `hit_light_thud_01.wav` -> pool `hit_light_thud` works but `thud_a.wav` -> pool `thud`, a stem without a trailing `_<nn>` is a pool named by its prefix before the last underscore (e.g. `ambience_street.wav` becomes pool `ambience`). Subfolders are not scanned.
- A manifest (`slot -> [files], gain_db, pitch_min/max, bus, positional?, loop, source, licence`) would change:
  - per-variant and per-slot gain moves out of Tuning and the normaliser; Tuning keeps only live mix offsets;
  - `SfxBank._init` would read the manifest instead of globbing (needs a new loader and a fallback to globbing so existing tests pass);
  - `LAYER_DB` could be dropped for manifest gains, but `test_audio.gd` reads `AudioDirector.layer_db()` (`tests/test_audio.gd:232`, `:316`) and the Tuning-group test pins exact subgroup names (`:160-188`, subgroup list at `:187`), so adding Tuning props requires editing that test;
  - licence/source per slot gives the ASSETS.md rows a machine source (today 38+1 rows by hand, `ASSETS.md:172-205`, all "Procedurally generated ... Project-owned").
- ASSETS.md says "Final SFX replace them in Milestone 6" (`ASSETS.md:174`).

## 3. Slots M6 needs that do not exist, and their signals

None of these have any code today (section 0). Signals available:

| Slot (proposed) | Signal / hook | Where emitted | Payload |
|---|---|---|---|
| Barrier close / open (shutter, gate, car) | `Barrier.moved(closed)` (local, not on CombatEvents) | `game/level/kit/barrier.gd:19`; emitted `:59`, `:68`, `:117`; `kind` enum SHUTTER/GATE/CAR `:21`; durations `barrier_close_s` 0.6 / `barrier_open_s` 0.8 (`tuning_data.gd:1027`, `:1029`) | closed bool; `close()`/`open()` start motion at `:56-68`, so the start of motion is an unsignalled call, only arrival is signalled |
| Arena lock | `CombatEvents.arena_locked(arena)` | `game/level/kit/arena.gd:72` | arena node (`behind.close()` fires just before at `:70`) |
| GO cue | `CombatEvents.arena_cleared(arena)` (GoCue listens, `game/ui/go_cue.gd:55`, `:154-160`) | `arena.gd:83` (`ahead.open()` at `:81`) | arena |
| CLEAR | `CombatEvents.level_cleared(level)` (GoCue `:163`) | `game/level/kit/level_root.gd:300` | level |
| Weapon pickup | `CombatEvents.weapon_picked_up(actor, weapon)` | `game/player/player.gd:1363` | player + weapon |
| Weapon throw | `CombatEvents.weapon_thrown(actor, weapon)` | `player.gd:751` | |
| Weapon break | `CombatEvents.weapon_broke(actor, weapon)` | `player.gd:767` (melee durability), `game/weapons/weapon.gd:203` (thrown weapon spent) | |
| Weapon clang / impact | none distinct: weapon hits are `hit_landed` (thrown weapon: `weapon.gd:197`; swings via move ids `pipe_swing*`/`weapon_throw`). `HitInfo` has no `weapon` field (fields: `tier` `hit_info.gd:10`, `input_timing :34`), so a weapon hit is only detectable from the attacker's `_weapon` or move id | | would need a HitInfo field or a director check on `hit.attacker` |
| Weapon drop / landing | no signal; `Weapon.drop()` at `weapon.gd:110-126` | | |
| Second weapon | same signals as above; any new weapon slot must be keyed off the weapon node (group `weapon`, `weapon.gd:27`) or a move id from `tools/gen_moves.gd:218-228` | | |
| Boss phase 2 line | `CombatEvents.boss_phase_changed(boss, 2)` | `game/enemies/boss/boss.gd:372` | boss, phase |
| Boss call-in | none; `_tick_adds` / `_spawn_one_add` `boss.gd:403-424` (the phase change signal is the only hook; per-add spawns are silent) | | |
| Boss attack lines | `windup_started(attacker, move)` already reaches `effort` for the boss; a boss-specific pool needs `attacker` identity (group or script check) | `combat_actor.gd:468` | |
| Per-archetype voices (Punk, Bruiser, Kicker, Pipe Thug, boss) | `_grunt()` and `_on_windup_started()` use fixed pools `grunt`/`effort` (`audio_director.gd:380-383`, `:279`); need archetype in the pool name (e.g. `grunt_bruiser`) from an enemy export or `actor.name`/class | `enemy_actor.gd:69` is the existing per-enemy audio hook (`voice_pitch_mult`) | |
| KO / death line, knockdown, get-up | `CombatEvents.ko(victim, hit)` (`combat_actor.gd:439`), `knocked_down` (`:1133`), `got_up` (`:1192`), `hazard_ko` (`hazard_volume.gd:95`) | | none subscribed today |
| Player jump / land / dodge / quick turn | `jumped` (`player.gd:1070`), `landed` (`:1080`), `dodged` (`:1122`), `quick_turned` (`:1130`) | | optional, not in the proposal |
| Grab / throw / release | `grabbed` (`combat_actor.gd:500`), `thrown` (`enemy_hold.gd:181`, `player.gd:1338`), `released` (`:526`) | | optional |
| Hazard | `hazard_ko` | `hazard_volume.gd:95` | optional |
| Ambience (street, roof) | none. Needs a looping 2D or bed player, started by the level (Mission 1 scenes: `game/level/mission1/{street,roofs,boss_roof}.tscn`, `mission1.tscn`); the music player is the only loop today (`audio_director.gd:154`) | | |
| GO / CLEAR stings | 2D (UI), not positional; the director's `play()` is 3D-only (`:181`), so a `play_2d` or a plain `AudioStreamPlayer` is needed | | |

Not wired: the music loop is placeholder and off by default; the proposal lists it as final-audio scope only via "ambience" (`docs/milestones/M6-proposal.md:15`).

## 4. Tests that assert on audio, and what breaks if files change

Files referencing audio (grep, `tests/`): `test_audio.gd` (836 lines), `test_audio_crowd.gd` (203), `test_armor_presentation.gd` (creates `AudioDirector.new()` at `:31`), `test_crowd_room.gd` (`:190`, `:194` expect the AudioDirector class present), `test_readability_probe.gd` (`:55`, `:647`, `:684`: a fake director, R14), `tests/bot/readability_probe.gd` (`:603-606`). Other listed files mention "sfx|audio" incidentally.

Asserts on the bank and the samples in `tests/test_audio.gd`:
- `:124-141` `test_bank_has_every_pool_the_brief_asks_for`: minimum variants per pool (whoosh 3, thud 3, crack 3, crunch 3, body_fall 2, sub_thump 2, grunt 3, player_grunt 2, effort 2, block_clack 2, parry_ting 2, guard_break 2, music_loop 1); every stream `is AudioStreamWAV`; length over 0.05 s; one-shots under **1.5 s** (voices or boss lines longer than 1.5 s in an existing pool fail); music loop `loop_mode != DISABLED` (comes from the `.import`, see section 8).
- `:143-157` no-repeat and every variant comes up (iterates every pool in `bank.pools`, so any new pool is covered for free).
- `:90-103` `_pcm()` reads the **16-bit PCM wav file directly** (parses RIFF chunks at 44.1 kHz; assumes mono and 16-bit, `decode_s16`). Tests using it break on 24-bit, 48 kHz (time maths uses 44100), stereo, or non-wav files:
  - `:190-205` whooshes peak within 50 ms (5 ms windows): real whooshes with a slow swell fail;
  - `:208-218` every one-shot starts and ends within 0.004 of silence (needs a fade-in/out on ingest; applies to all pools except `music_loop`);
  - `:222-243` tier loudness ranking summed over the first 0.4 s from `<pool>_01.wav` using `AudioDirector.layer_db` plus tier db; a swap of the hit stack can invert the ranking unless gains are re-balanced;
  - `:291-317` pitch and volume variation tests key on the `thud` pool.
- `:160-188` the Audio tuning group must be followed by "Look" then "Debug" and have subgroup list `["Mix","Tiers","Layers","Voices","Blocks","Distance","Music","Rumble"]`; new Tuning props in that group must keep float props as range sliders.
- `:246-256`, `:363-409` the exact pool lists per tier (`[whoosh, thud, crack, crunch, body_fall, sub_thump]` composition) and pool counts per swing, so renaming pools or adding layers to `TIER_LAYERS` breaks them.
- `:584-598` music off by default; the music player needs a stream.
- `tests/test_audio_crowd.gd:158-175` the voice budget (peak about 30 voices with six windups, 32 voices); longer real samples keep voices busy longer and could exhaust the pool, and `:176-192` the pitch multiplier maths.
- `:727-836` (not read in full) test-room integration with a real jab.
- Files-changing impact summary: unique-stem pool names survive; anything over 1.5 s, non-44.1k/16-bit/mono, or starting/ending above 0.004 breaks tests; changing sample peak or tail changes the tier-ranking and "whoosh peaks early" asserts; removing a pool below the minimum fails `:124`.
- No test pins `.import` compress settings except via loop mode on the music stream.

## 5. Tools on this machine

- `which ffmpeg sox`: `/opt/homebrew/bin/ffmpeg`; **sox not found**.
- `ffmpeg -filters | grep loudnorm`: present (`loudnorm  A->A  EBU R128 loudness normalization`).
- `python3 -c 'import numpy, scipy, soundfile'`: **fails at the first import**; checked separately, `numpy`, `scipy` and `soundfile` are each `ModuleNotFoundError` (system python3, no venv). The ingest pipeline must use ffmpeg (`silenceremove`, `atrim`, `afade`, `loudnorm`/`volume`, `aresample=44100`, `-ac 1 -sample_fmt s16`, `ffprobe`/`astats` for peak) and stdlib `wave`/`struct`/`urllib`, or `pip install` into a venv (not done).
- The repo has `tools/gemini_image.py` (stdlib-style HTTP client reading `.env`, `tools/gemini_image.py:9`, `:28-43`) as the pattern for a key loader; it also falls back to the main checkout's `.env` in a worktree (`:28-37`).
- `.env` exists and is git-ignored (`.gitignore:2-4`); its variable names (values not read) are GEMINI_API_KEY, TRIPO_API_KEY, ELEVEN_LABS_API_KEY. `.env.example` documents `ELEVEN_LABS_API_KEY` and says the tools should read that or `ELEVENLABS_API_KEY`. The ElevenLabs SDK's name is `ELEVENLABS_API_KEY`, so the tool must accept both.
- `assets/source/` exists and is git-ignored (`git check-ignore assets/source` matched); it currently holds `_cache characters concepts fx look mannequin palette tripo_ledger.jsonl` and **no `sfx/`** folder yet. SPEC says SFX sources go to LFS (`docs/SPEC.md:83`), but `git check-ignore` shows `assets/source` ignored here; confirm which wins before a Sonniss subset is "committed".
- `.gitattributes` LFS-tracks `*.wav`, `*.ogg`, `*.mp3` (`:29-31`).

## 6. ElevenLabs sound-generation API (WebFetch, 2026-11-04)

From https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert and the capabilities page:
- Endpoint: `POST https://api.elevenlabs.io/v1/sound-generation`; header `xi-api-key: <key>`, `Content-Type: application/json`. Regional hosts exist (`api.us.elevenlabs.io`, EU, India, Singapore).
- Body: `text` (string, required); `duration_seconds` (double, nullable, 0.5 to 30; omitted = model guesses from prompt); `prompt_influence` (double, 0 to 1, default 0.3; higher follows the prompt closely, less variation); `loop` (bool, default false, seamless loop); `model_id` (default `eleven_text_to_sound_v2`; also `eleven_text_to_sound_v3`).
- Query: `output_format` (default `mp3_44100_128`; form `codec_samplerate_bitrate`, e.g. `mp3_22050_32`; options include MP3, Opus, PCM, WAV, A-law, mu-law; 192 kbps MP3 needs Creator and up; **PCM and WAV at 44.1 kHz need Pro and up**); `enable_logging` (default true; false is Enterprise zero-retention).
- Response: 200 returns the audio bytes as a file download in the requested format; 422 returns `detail[]` with `loc`, `msg`, `type`.
- Cost: set duration costs **40 credits per second** (capabilities page); the page does not state the cost of automatic duration; the API reference page says nothing about credits. At 40 credits/s, Starter's 30000 credits/month (Game-boy's figure, not verified here) is 750 s (12.5 minutes) of generation at a set duration; a 1 s effort is 40 credits, a 2 s boss line is 80.
- Reading usage: `GET https://api.elevenlabs.io/v1/user/subscription` returns `tier` (example "starter"), `character_count` (used this period), `character_limit`, `next_character_count_reset_unix`. Credits used by a run = `character_count` after minus before.
- What the docs disagree on or leave open:
  1. Names: the API says `character_count`/`character_limit` while the product bills "credits"; the pages do not say they are the same unit for sound effects, so measure it with a before/after on one cheap call.
  2. Duration floor: API reference says 0.5 to 30 s; the capabilities page says 0.1 to 30 s.
  3. WAV: the capabilities page says WAV at 48 kHz for non-looping effects, the API reference says WAV/PCM at 44.1 kHz needs Pro. So on Starter plan, expect MP3 only (default `mp3_44100_128`, and `mp3_44100_192` is not allowed below Creator); an ingest step must decode MP3 with ffmpeg and not assume a WAV. Whether 48 kHz WAV is open to Starter is unconfirmed.
  4. Model: `eleven_text_to_sound_v2` is the default but is **deprecated and removed 2027-03-01**; v3 follows multi-part prompts better and clips less on high frequencies. Pin `model_id` explicitly.
  5. Commercial licence terms are not on these pages (a help-centre credits article returned HTTP 403, so the Starter credit count and licence were not verified from ElevenLabs). Game-boy's note says Starter has a commercial licence; record the plan, date and a copy of the terms in ASSETS.md.
  6. Voice use: SFX v3 is said to handle "vocal and musical sounds better" (efforts, grunts are vocal sounds); results are text-prompted and not a controlled speaker, so per-archetype consistency depends on prompt wording and `prompt_influence`.

## 7. Sonniss GDC Game Audio Bundle (public info only; nothing downloaded)

From https://sonniss.com/gameaudiogdc (WebFetch) and a web search:
- What: yearly free packs of professionally recorded and designed game sound from many vendors, published around GDC. Sizes per year: 2024 9 parts 23.5 GB (a search hit says 27.5 GB+); 2021 to 2023 14 parts 38.7 GB; 2020 14 parts 48.2 GB; 2019 26.2 GB; 2018 29.3 GB; 2017 19.2 GB; 2016 12.9 GB; 2015 9.0 GB. The 2026 bundle has its own page (a search hit says 347 files, 7.47 GB, unverified). The page lists no 2025 bundle. Search snippets disagree on sizes for the same year (2024: 23.5 vs 27.5 GB; 2023 44 GB+ vs 38.7 GB for "2021 to 2023"), so size before downloading.
- Delivery: multi-part ZIP, torrent, and a mirror; a Sonniss login permits re-download. Track lists are separate Google Sheets/PDF.
- Licence (page): royalty-free, commercial use, "No attribution is required", unlimited projects and lifetime; editing allowed; limited to media production; **no resale or redistribution as sound effects (sample packs/libraries) and no AI/ML training**. Including edited sounds inside the shipped game is allowed. Consequence: shipping edited wavs inside the game is fine, but committing the raw source bundle to a public repo is a redistribution risk; keep source in the git-ignored `assets/source/sfx/` and commit only processed, game-ready files.
- Folder layout and naming: not stated on the page. From general knowledge of the bundles (not verified here, check on the downloaded files): one folder per vendor library, each with WAV (mostly 24-bit, 48 or 96 kHz, mono or stereo) and often a metadata spreadsheet or embedded BWF/Soundminer tags; vendors vary between descriptive names and UCS (Universal Category System) names like `CATSUB_VendorCat_Description.wav`. Do not assume UCS.
- Picking by an agent: no audio listening is possible, so selection is by filename and metadata plus measured features. Workflow: unzip each part into its own empty directory, `find`/`ffprobe` to build a CSV (path, duration, sample rate, channels, bit depth, embedded tags via `ffprobe -show_entries format_tags`), filter by keyword and by duration (hit layers short, under 1.5 s because of the test cap), then rank with `ffmpeg astats`/`ebur128` (peak, RMS, early-peak position) and have Game-boy audition the shortlist in the audition room. Vendor spreadsheets (track lists) are the best description source if downloaded with the bundle.

## 8. Import settings and the audition room

- Import settings seen: every sfx `.wav.import` uses `compress/mode=2` (QOA, the project default; `ASSETS.md:174` says "default QOA compression"), `edit/loop_mode=0` for one-shots (`assets/export/sfx/thud_01.wav.import:21`); the music loop has `edit/loop_mode=2` (Forward), `loop_begin=0`, `loop_end=-1`, `compress/mode=2`, `force/mono=false`, `force/max_rate=false`, `edit/trim=false`, `edit/normalize=false` (`music_loop_01.wav.import:15-24`). The generator does not touch `.import` files so the loop mode is kept (`gen_sfx.gd:21-23`). A re-imported or renamed ambience wav needs the same `.import` edit (`edit/loop_mode=2`, `loop_begin`, `loop_end` as sample frames; -1 = end), or `AudioStreamWAV.loop_mode` set from code after `load`; the director would then need to set it since a `.import` is only written by the editor import. `.import` is text and committed (`.gitattributes` `*.import text`). Test at `tests/test_audio.gd:138-139` checks the music stream's `loop_mode`, and QOA means the stream is `AudioStreamWAV` (test `:134`).
- Loop quality: ElevenLabs `loop=true` gives a seamless loop on its side, but after MP3 decode and trimming the loop points move, so ambience should be produced with the same length untouched or crossfaded in ffmpeg (`acrossfade`) and checked that the first and last 5 ms match.
- QOA caveat: QOA is lossy and tuned for games; for the hit stack it is fine (what the placeholders use), but a click test (`:208`) reads the `.wav` file not the import, so QOA artifacts are not tested.
- Keys in use (input map `game/autoload/game_input.gd:10-37`): W A S D, Q, E, Space, Shift, Tab, Esc, R, F1 (tuning panel, `jb:4`), F2 camera cycle, F3 debug draw, F4 cheats, **H** help (`:32`), F5 sparring (`:33`), F6 switch room (`:34`), arrows and PageUp/PageDown free-fly (`:37-42`), mouse buttons 1 to 3. **L** is the combat-log toggle, a raw key check in `game/ui/combat_log_overlay.gd:17`, `:46-48`, and is the only entry of `HelpOverlay.KEY_ROWS` (`game/ui/help_overlay.gd:41-43`). The training-room code adds no other key (`game/level/test_room.gd:44-48` only handles `sparring`). The F1/F4 overlay holds the fight via `GameInput.menu_open` (`game_input.gd` header). The `physical_keycode` is used for actions (`:86`).
- Free keys: F7 to F12 and the digits 1 to 0 (including the numpad), and Z X C V B N M, plus `-`, `=`, `[`, `]`, `,`, `.`. Digits are the simplest "one key per bank": 13 banks plus new slots exceed 10 keys, so use a page system (Left/Right is taken by free-fly; use `[` and `]` for page, digits to play) or a second key for "new vs old". Caveats: the DebugDraw (`game/ui/debug_draw.gd:134`), HUD (`hud.gd:73`), CameraDirector (`camera_director.gd:54`), TuningPanel (`tuning_panel.gd:554`) and TuningOverlay (`tuning_overlay.gd:117`) have their own `_unhandled_input` handlers; the digit and bracket keys were not found bound there (grep for `keycode` found only the combat log and game_input), but the tuning panel has text fields, so ignore keys while `GameInput.menu_open` is true.
- Audition room design implied by the code: the training room is `res://game/level/test_room.tscn` (third entry of `ROOM_SCENES`, `game_input.gd:47-51`); `TestRoom` (`game/level/test_room.gd`) builds its own presentation, so an `AuditionRoom` node/script added to it (only in the training room, gated by `with_presentation`, `test_room.gd:40`) can call the director's `play()` with the old and new variant. To A/B old vs new it needs the old generated files kept in a second folder (e.g. `assets/export/sfx_legacy/`) and a second `SfxBank.new(dir)` (the constructor takes a folder, `sfx_bank.gd:17`), which exists already. Slots without a signal in the live game (GO, CLEAR, barrier, weapon) can still be auditioned because `play()` takes a pool name and position. 2D stings need the 2D path noted in section 3. The help overlay (`help_overlay.gd:41`) lists non-action keys and should list the audition keys.
