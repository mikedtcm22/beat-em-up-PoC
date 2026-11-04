# Milestone 6 plan: full art and audio

SPEC §12: all enemies and the boss, environment modules and set dressing, final SFX (`docs/SPEC.md:375`). **Done when no placeholder assets remain.** Plus HANDOFF's carried items: an original second weapon, and M4's two looks (per-swatch damage marks, the near upper arm, README "Two looks carried forward").

**Inputs.** [M6-proposal.md](M6-proposal.md), approved 2026-11-04 with audio option (a), ElevenLabs Starter, and Tripo topped up to 1705. The four codemaps in [M6-codemap/](M6-codemap/). Game-boy's answers since then (HANDOFF `d2a0cba`, `0d6a5c9`):
- **The pick** (files in `assets/source/concepts/m6/`):
  - Kicker C (`kicker_c.jpg`), Pipe Thug B (`thug_b.jpg`), Bruiser A (`bruiser_a.jpg`).
  - Boss C (`boss_c.jpg`), named **Ox Pellerin**. Darken his charcoal: it rendered as light slate.
  - Second weapon A, the bike chain and padlock (`weapon_a.jpg`), id `bike_chain`.
  - Moods: street A (`mood_street_a.jpg`) and roof C (`mood_roof_a.jpg`; the sheet relabels the roofs C/D).
- **The Tripo licence:** the key is on Tripo's paid API platform. Each ASSETS row reads "Tripo API (paid credits): owned by the project, commercial use".
- **The prune is done:** one worktree is left, and `df` shows 89 GB free.
- **Every sound from ElevenLabs** (Game-boy, 2026-11-04 15:05, session chat, replacing his option (a)'s Sonniss half): "Why don't we just use ElevenLabs for all sound instead?" The account is Starter with 40,000 credits. So there is no download, SONNISS became SFX (§3), and nothing is open.

So nothing waits on the pick any more. The packages are phased by what must merge first and by the machine's slots.

**Where the codemaps were wrong (checked):**
- `assets/source/` is tracked: 139 files in `git ls-files`, and `.gitignore:38-47` ignores only `_cache/` and per-run stills (audio.md §5 says the folder is ignored). Godot skips it (`assets/source/.gdignore`).
- The boss's 30k needs no exception: SPEC §10 has a Boss row (`SPEC.md:324`), and A2 checks each row against its own budget (`tests/test_m4_done_when.gd:313-326`).
- CONCEPTS made no A/B stills for D6 or D7 (`M6-calls/CONCEPTS.md:3`), so LOOKS and ARM make them.

## 0. The approach

- **Step 0 (the lead, one commit on `m6/full-art-audio`, pushed before P1):**
  - The ARCHITECTURE.md heading `## Full art and audio (Milestone 6)`, with one `### <the package's title in §3> (<KEY>)` per package, in §3's order, between `## Level blockout (Milestone 5)` (`ARCHITECTURE.md:1150`) and `## Ownership (Milestones 1-3)` (`:1257`). The ASSETS.md headings of §2.
  - The palette ranges of §2. Narrowing `punk.json` and `player.json` changes no GLB, and `gen_palette.py --check` still passes.
  - **The shared declarations**, so that no two packages add the same line:
    - three new signals, `CombatEvents.section_entered(section: Node3D)`, `barrier_moving(barrier: Node3D, closing: bool)` and `weapon_landed(weapon: Node3D)` (none exists today, `combat_events.gd:5-49`);
    - an emit line at the top of `Barrier.close()` and of `open()` (`barrier.gd:56-68`);
    - the field `LevelSection.ambience: StringName`;
    - the field `MoveData.impact_sfx: StringName = &""`.
- **Phase 1, P1 (`args-P1.json`): CHAIN, KIT, PROPS, AUDIO, LOOKS.**
  - Each needs only step 0. Three Godot slots; CHAIN and PROPS hold the two Blender slots.
  - The lead merges each package as it finishes. After each merge: regenerate the default preset and the atlas (`python3 -I tools/pipeline/gen_palette.py`), re-measure the inventory ratchet, and run the full suite.
- **Phase 2, P2 (`args-P2.json`), once all of phase 1 has merged: SFX, HEAVIES, CREW, DRESS, WEAPONS, ARM.** HEAVIES, CREW and ARM are Blender-bound, at most two at once. SFX needs only AUDIO's merge.
- **Phase 3:**
  - the lead's look;
  - one review round (3 lenses), one fix wave (at most 3 fixers), a targeted re-check;
  - frame time against M5;
  - README's departures, the PR, the DM.
- **Done:** every row of §5.

## 1. Decisions taken by default

Each gives the decision / the alternative not taken / why / whether it's a README departure.

- **D1 Art over the graybox** (proposal D1). Colliders, the navmesh, hurtboxes and hit-test proxies stay; the art only draws. A prop scene is visual only, and its collider is the block or barrier it dresses. KIT snapshots M5's static colliders into a fixture, and a test holds them. / Not collision from the art. / Every M3-M5 number holds. / No.
- **D2 Modules are Godot-scripted and procedural, on one trim sheet.**
  - `KitMesh.build(kind, size)` writes an `ArrayMesh` with trim UVs in metres, so a wall of any length fits (walls run 1-17.5 m, `level-env.md` §1). The shaped repeats are kinds of the same builder.
  - `tools/gen_trim.gd` paints the sheet (the `gen_fx.gd` precedent).
  - This changes the approved proposal's method (its D2 said Blender-scripted, `M6-proposal.md:77`), not the spec. The lead names the change in the phase 1 DM.
  - / Not Blender GLB modules: they need a stretch rule and would take a Blender slot. Not Tripo. / No (SPEC §10's 5k module and 2k sheet are kept).
- **D3 The game's own animation set for every enemy** (proposal D3). / Not new clips. / The telegraph timings stay. / Continues M4's "Rig and animation" departure (`README.md:237`).
- **D4 The veteran Punk is a palette swap** (proposal D4).
  - `EnemyVariant.palette`: a second atlas built from `assets/source/palette/variants/punk_veteran.json`, set on that rig's art material's `albedo_tex` (a uniform, `toon_materials.gd:79-94`).
  - The tint retires.
  - / Not the albedo multiply (`enemy_actor.gd:322-329`), which recolours skin too. / Clear at 5 m, same silhouette. / No.
- **D5 The second weapon keeps the spec's numbers** (SPEC §4, `SPEC.md:143`): 10 a swing, a 3-hit chain, it breaks after 8, a throw does 15.
  - `bike_chain` differs in reach (`HitboxSpec` offset and radius on `WeaponTip`), arc and timing, reusing the three pipe pose recipes (`placeholder_poses.gd:1211-1218`). The concept: a short sideways whip, the padlock landing last, medium reach.
  - A presentation-only sim draws it from the grip and the tip.
  - It lies at A6's spot (screen 11); the pipe comes from Pipe Thugs.
  - / Not new damage rules. / The reach and lens tests hold. / No.
- **D6 Damage marks per swatch** (proposal D6).
  - A swatch may say `"blood": false`: it scuffs and darkens but never takes blood. The Punk's slot 17 (cap, laces, strap) gets it, so there's no Punk rebuild.
  - Blood gets a hard edge (a cut on `d.a`).
  - A/B switch: `look_marks_per_swatch` (Debug).
  - / Not a separate cap swatch (a rebuild). / No.
- **D7 The near upper arm** (proposal D7).
  - The hero GLB gains a fourth mesh, `Body__fp_arm`: the shoulder half of each upper arm, split from `Body__fp_hidden` (`player_parts.py:24-35`).
  - In first person it shows only while a move with `fp_show_upper_arm` plays (the haymaker and the uppercut), the way `FirstPersonCamera` swaps `Body__fp_torso` (`first_person_camera.gd:419-466`).
  - A/B switch: `look_near_arm` (Debug).
  - **ARM builds it in phase 2, after CHAIN merges.** The fourth mesh breaks the three-mesh asserts in `test_m4_done_when.gd:285`, which CHAIN rewrites in phase 1, and in `test_art_contract.gd:33, 251, 260`.
  - / Not a runtime partition, not a camera reframe. / No.
- **D8 Ambience** (proposal D8).
  - One looping bed per section (street hum, roof wind) on its own non-pooled player, at `ambience_db`, crossfading on `section_entered`.
  - With no section (the crowd and training rooms), the bed is `ambience_street`.
  - AUDIO subscribes and owns the hookup.
  - / Not silence. / No.
- **D9 The crowd street and the training room get the kit**, through one hook in `RoomKit.add_box` that `LevelBlock` and both code-built rooms share (`crowd_room.gd:212`, `test_room.gd:126-131`). / Not a `LevelBlock` refactor of the rooms. / No.
- **D10 One trim material.**
  - A new `Kind.TRIM` shader, like `grid.gdshader` (`game/level/grid.gdshader`, `toon_materials.gd:150-155`): linear mipmaps, repeat, the ink cut of `toon.gdshader:99-103`, ROUGHNESS 1 so the edge pass keeps working, and an `albedo` tint uniform.
  - One shared material, drawn in `warm_up`.
  - / Not new uniforms in `toon.gdshader`. / No.
- **D11 Multi-block features are dressing.**
  - A section's non-solid `Dressing` node holds `KitPiece`s over blocks whose boxes are hidden (`draw_box = false`); never a solid `LevelBlock` (`test_m5_done_when.gd:385-387`).
  - Stairs draw one flight mesh; the steps stay collider-only.
  - / No.
- **D12 Section light** (DRESS).
  - `LevelSection` exports a sun (direction, colour, energy) and fog, and `LevelRoot` blends to them over `section_light_blend_s`.
  - `LookPost` keeps Tuning's sun only where no section light applies (`look_post.gd:164-175`). The crowd and training rooms keep Tuning's sun.
  - `section_entered` comes from `LevelRoot` (KIT): it fires when the section owning the route point nearest the player changes, and once at the start. LevelRoot tracks no section today (`level_root.gd:105-130`).
  - / Not local omni lights (`toon.gdshader:8` is sun-only). / No.
- **D13 Hero props through Tripo, placed by `PropSpot`.**
  - PROPS makes the car, dumpster, AC unit and water tank on the shared atlas (SPEC §10's 3k).
  - A spot draws `res://game/level/props/<id>.tscn` when it exists, and its fallback box otherwise.
  - The car barrier draws the car the same way.
  - / Not boxes. / No.
- **D14 Prop hulls follow the shape.** A baked smooth normal or no hull; never `Hull.BOX` (`toon_outline.gdshader:42-44`). PROPS picks from a capture and logs the choice. / No.
- **D15 Heights by uniform scale.** Art is authored at 1.8 m and scaled by `body_height` (`skinned_art.gd:2-4`, `humanoid_rig.gd:220`), so the Bruiser (2.05) and the boss (2.3) get their bulk from girth. A per-character A6 ratchet needs a logged reason (as the hero's has, `test_m4_done_when.gd:96-100`). / No.
- **D16 Fists.**
  - The boss wears boxing gloves (`boss_c.jpg`), so his default is a generated glove fist (50 credits, the Punk's T9 route).
  - Everyone else gets the chain's procedural block fist.
  - A5's fist box (`test_m4_done_when.gd:422`, 0.1 x 0.118 x 0.116 m ±20%) holds through the roster's `a5_extent` ratchet. It can loosen only for the boss, with a logged reason.
  - / Not a generated fist for each (200 credits). / No.
- **D17 Dummies: one padded look.** The probe mannequin is re-run through the chain into `assets/export/characters/dummy/` with its own palette, and the three per-dummy colours (`test_room.gd:23-25`) go. / Not three variant atlases. / No.
- **D18 The audio manifest is the ingest record.**
  - `assets/source/sfx/manifest.json` maps each shipped wav to its source, licence, trim, fades and gain. It writes the ASSETS rows, and `ingest.py --check` rebuilds from it.
  - The game keeps `SfxBank`'s glob (`sfx_bank.gd:17`) and Tuning's dB (`LAYER_DB`, `audio_director.gd:77`).
  - / Not a runtime manifest. / No.
- **D19 Every sound is generated** (Game-boy's call, 2026-11-04).
  - The hit stack, blocks, barriers, weapons, stings and the two beds come from the ElevenLabs sound-effects API through AUDIO's tools, as the voices do. SFX (phase 2) generates and chooses them.
  - There's no download, no redistribution clause, and every sound is prompted to the game's comic style.
  - **The fallback** if his audition finds the generated impacts weak: the manifest's `source` takes any origin, so a recorded library can replace one pool without code.
  - / Not the Sonniss bundle (option (a)'s first half, which he replaced the same day). / No departure: SPEC §2 lists an AI sound-effects API.
- **D20 Voices per archetype** from ElevenLabs.
  - Pools `grunt_<archetype>`, `effort_<archetype>` and `ko_<archetype>`, keyed by `EnemyActor.archetype` (`enemy_actor.gd:62`).
  - An empty pool falls back to the shared `grunt` and `effort`, which are re-sourced too: the dummy's archetype is `&""`, so it always uses them.
  - `voice_pitch_mult` stays.
  - / Not one pool pitched five ways. / No.
- **D21 MP3 in, WAV out.**
  - Starter returns MP3 (`audio.md` §6). Ingest decodes with ffmpeg to 16-bit mono 44.1 kHz (`test_audio.gd:90-103`), written with `-bitexact -map_metadata -1 -fflags +bitexact`.
  - `--check` compares the PCM data.
  - The model is pinned to `eleven_text_to_sound_v3`.
  - / No.
- **D22 Weapon impacts by move.** `MoveData.impact_sfx` (step 0; empty for fists); the director reads `hit.move` (`hit_info.gd:8`). / Not a `HitInfo` field. / No.
- **D23 New slots and their hooks:**
  - barriers on `barrier_moving` (step 0);
  - weapons on `weapon_picked_up`/`weapon_thrown`/`weapon_broke`, plus `weapon_landed`, which WEAPONS emits at the first contact after a throw or a drop (`weapon.gd:166-200`);
  - KO lines on `ko`; the boss on `boss_phase_changed`;
  - GO and CLEAR as 2D stings on `arena_cleared`/`level_cleared`.
  - Long pools (boss lines, beds) are declared long in the manifest and exempt from the 1.5 s cap. / No.
- **D24 Legacy sounds kept as a fixture.** The 38 generated SFX are copied to `tests/fixtures/sfx_legacy/` for the audition room's old/new A/B (Debug `audio_legacy_bank`, allowed by name), and `gen_sfx.gd` writes there. / No.
- **D25 The music loop stays** (SPEC §1 non-goal). It's the one allowed placeholder. / A README line.
- **D26 Tests per character from a roster.** One file per character, `tests/fixtures/art/roster/<id>.json`, drives A1-A12 and the Punk's checks; a new character adds its own file. / Not rows inside `test_m4_done_when.gd`. / No.
- **D27 Every catalog art is warmed** (`room_kit.gd:202-240`; a cold GLB read costs 17-19 ms). / No.
- **D28 A floor glint replaces the amber.** `weapon_floor_amber` (Debug) brings M5's look back. / No.
- **D29 Frame time against M5 on this Mac.** KIT's first commit adds "Perf: level walk" before any art, and that commit is the baseline ref. / No.

## 2. Pinned contracts

**Art roster (CHAIN; CREW, HEAVIES add rows).**
- Each character has a file `tests/fixtures/art/roster/<id>.json`: `{"id", "art", "actor_scene", "height_m", "budget" (15000; boss 30000), "meshes": ["Body"], "moves": [...], "ratchets": {"a5_extent" (default 0.2, test_art_contract.gd:38), "a6": {...}, "a9_cells", "a9_lens_pp", "anchor_m": {...}, "stretch_m"}, "notes"}`.
- Strain rows go in `tests/fixtures/strain/<id>.json`. A ratchet only moves down.
- Per character:
  - `assets/source/characters/<id>/pipeline.json`;
  - `assets/export/characters/<id>/<id>.glb` (and `_rest`);
  - `game/actors/art/<id>_art.tres`;
  - `report/report.json`;
  - `python3 -I tools/pipeline/run.py --asset <id> --check` says YES.
- **The player** keeps his own tests. CHAIN carries his mesh list and the `*_PLAYER` constants (`test_m4_done_when.gd:96-121, 285`) over verbatim; only ARM changes them.

**Palette slots** (`slot_range`, inclusive; each file defines only its own):
- shared 0-15 · punk 16-21 · kicker 22-27 · weapons 28-31 · player 32-37 · thug 38-43 · bruiser 44-49 · boss 50-55 · dummy 56-59 · props 60-63.
- A swatch may add `"blood": bool` (LOOKS).
- Variant atlases come from `assets/source/palette/variants/<id>.json` and are written to `assets/export/palette/<id>_atlas.png`.
- **A package that adds or changes a palette JSON regenerates the atlas on its branch**, because `test_art_contract.gd:1336-1360` checks every JSON against it. The lead regenerates it at every merge.

**Static props (PROPS; KIT, DRESS, WEAPONS use).**
- `python3 -I tools/pipeline/run.py --asset <id> --kind prop` reads `assets/source/props/<id>/pipeline.json`: inspect, palette with no armature, then a new `blender_export_prop.py`. It writes `assets/export/props/<id>/<id>.glb` (one or more named meshes, UV1 on the atlas, smooth normals for the hull, no skin) and a report.
- `StaticArt` (`game/actors/art/static_art.gd`, a `Node3D`):
  - exports `scene: PackedScene`, `palette: Texture2D`, `triangle_budget: int = 3000` and `hull: bool`;
  - draws with `ToonMaterials.art_prop(atlas)`;
  - `check() -> PackedStringArray`.
- **The weapon art frame:**
  - centred on the weapon's origin, long axis on local +Y, the grip 0.12 m from the -Y end (`weapon.gd:83-87`), length `Weapon.length` (the pipe's is 0.85, `weapon.gd:8`);
  - `Weapon.art_scene: PackedScene` (PROPS adds it): when set, the art draws and the cylinder doesn't, and the floor colour tints the art until D28.
- `bike_chain.glb` holds three meshes in that frame: `Lock` (the padlock, at the free end), `Grip` (the wrapped handle) and `Link` (one link at the origin, which WEAPONS's sim repeats).
- **Prop ids and fallback boxes** (length x height x depth, m):
  - `car` 4.2 x 1.4 x 1.9;
  - `dumpster` 2.0 x 1.3 x 1.0 (`crowd_room.gd:326-338`);
  - `ac_unit` 1.0 x 0.8 x 0.7;
  - `water_tank` 2.0 x 2.6 x 2.0.
  - Scenes: `game/level/props/<id>.tscn` and `game/weapons/art/<id>.tscn`.

**Kit (KIT; DRESS uses).**
- `KitMesh.build(kind: StringName, size: Vector3) -> ArrayMesh`, cached per (kind, size). The kinds are at least `wall`, `floor`, `slab`, `deck`, `curb`, `door_frame`, `window`, `shutter`, `rail`, `post`, `stair_flight`, `cornice`, `chainlink`, `gate`, `crate` and `skyline`, each at most 5000 triangles.
- `ToonMaterials.trim() -> ShaderMaterial`.
- The sheet `assets/export/kit/trim_sheet.png` (2048², mipmaps) is built from `assets/source/kit/trim_layout.json` by `godot --headless -s tools/gen_trim.gd` (`--check` compares).
- `RoomKit.add_box(parent, pos, size, material, overlay, art: StringName = &"")` keeps the same collider and draws the `KitMesh` kind `art` (`&"box"` = M5's look). `LevelBlock` exports `module: StringName` (`&""` = derived from `look`) and `draw_box: bool = true`.
- `Dressing` is a non-solid `Node3D` holding `KitPiece`s (`kind`, `size`). `PropSpot` exports `prop_id: StringName`, `size: Vector3` and `hull: bool`.
- `Barrier` keeps `Panel`, `Collider`, its API and its tunables.

**Audio (AUDIO; SFX, WEAPONS use).**
- **The manifest** `assets/source/sfx/manifest.json`: `{"slots": {"<pool>": {"min_variants", "long", "loop", "space": "3d"|"2d"}}, "files": [{"file", "pool", "source": "elevenlabs:<ledger id>" | "gen_sfx", "licence", "trim_s", "fade_ms", "peak_db" | "lufs", "notes"}]}`.
- **Tools:**
  - `python3 -I tools/audio/ingest.py [--only <pool>] [--check]`:
    - uses ffmpeg only;
    - `--check` rebuilds every row's PCM from its source and fails on any difference.
  - `python3 -I tools/audio/eleven_sfx.py <jobs.json> --label <text> --ceiling <credits>`:
    - reads `ELEVEN_LABS_API_KEY` or `ELEVENLABS_API_KEY` and never prints it;
    - sets `model_id` and `duration_seconds`;
    - reads `GET /v1/user/subscription` before and after each call;
    - keeps a ledger, `assets/source/sfx/eleven_ledger.jsonl`;
    - refuses calls past `tools/audio/eleven_policy.json` `{"milestone": "M6", "stop": 30000, "max_call": 1200}` (a 30 s bed at 40 credits a second fits one call);
    - puts the MP3s in LFS under `assets/source/sfx/eleven/<job>/`.
- **New pools:**
  - `grunt_|effort_|ko_` + `punk|kicker|thug|bruiser|boss`, and the shared `grunt` and `effort` (re-sourced);
  - `player_grunt` (re-sourced), `boss_phase` (long);
  - `barrier_<shutter|gate|car>_<close|open>`;
  - `weapon_pickup|throw|break|land`, `weapon_<impact_sfx>_hit`;
  - `sting_go`, `sting_clear` (2D);
  - `ambience_street`, `ambience_roof` (loop, long).
  - The hit stack keeps its names (`audio_director.gd:66-71`).
- **`AudioDirector`:** `play()` unchanged, `play_2d(pool, volume_db) -> AudioStreamPlayer`, `set_ambience(pool)`. It subscribes to `section_entered` and calls `set_ambience(section.ambience)`.

**Weapons (WEAPONS).**
- `WeaponDef` (`game/weapons/weapon_def.gd`): `id`, `display_name`, `scene`, `move_set`, `throw_move`, `swing_ids`, `impact_sfx`; files in `game/weapons/defs/<id>.tres`.
- `Weapon.def`. `player.gd` reads the held weapon's def (today `player.gd:11-14, 718, 760`).
- Scenes: `game/weapons/pipe.tscn` (path kept) and `game/weapons/bike_chain.tscn`.

**The placeholder inventory (LOOKS writes it).** `tests/test_m6_no_placeholders.gd` builds the level (`mission1.tscn`), the crowd street and the training room headless, and counts per scene:
- **`primitive_bodies`:** every enemy id the scene can put in play, instanced with its variant and counted when its rig has no art (`has_art()` false), plus the player.
  - The ids: the level's encounter tables (`game/level/mission1/encounters/a1-a7.tres`) and the boss's adds (`boss.gd:403-424`); the crowd room's waves (`game/level/encounters/crowd_waves.tres`, `encounter_spawner.gd:44`); the training room's dummies and the F4 catalog (`EnemyCatalog.available()`, `enemy_catalog.gd:10-19`).
  - Enemies spawn at runtime (`EncounterSpawner.make_enemy`, `encounter_spawner.gd:107`; `grep -c enemies/` finds none in `mission1/*.tscn`), so a count of the built scene alone would read 0.
- **`tints`:** a shipped variant with a non-white `tint`, a dummy colour multiply (`test_room.gd:107`), or the floor amber.
- **`boxes`:** a visible `BoxMesh` or `PrimitiveMesh`: blocks, barrier parts, steps, crates, the skyline, prop fallbacks.
- **`cylinder_weapons`:** every weapon a scene places or an enemy carries (pickup spots, the training room's pipe, the Thug's pipe) and draws with a `CylinderMesh` (`weapon.gd:39-46`).
- **`second_weapon`:** 1 while A6's `PickupSpot` holds `pipe.tscn` (`roofs.tscn:1117`, `pickup_spot.gd:9`).
- **`generated_sfx`:** a shipped pool whose manifest source is `gen_sfx`, or that has no row.
- **`empty_slots`:** a manifest slot with fewer files than its `min_variants`.
- **Allowed, by name:**
  - `music_loop` (D25);
  - F3's debug draws, the hidden proxies and the hidden-layer meshes, `EdgeGuard`;
  - `LookPost`'s `EdgeQuad` (`look_post.gd:153-156`);
  - the warm-up meshes (`toon_materials.gd:313`, `rig_paint.gd:152`);
  - the audition room's legacy bank (D24).
- **The ratchet** is `tests/fixtures/m6/placeholder_ratchet.json`, one key per scene and category.
  - In phase 1, LOOKS measures it on its own base. Every phase 1 builder writes the drop it expects in its calls file. After each phase 1 merge, the lead re-measures and writes the ratchet; `empty_slots` starts when AUDIO's manifest lands.
  - From phase 2 on, a package lowers only what it cleared. At a conflict, the lead takes the lower number.

**Tuning** (new properties are `@export_range`, in the package's own subgroup):
- "Level": "Kit" (KIT, `kit_trim_m_per_tile`); "Section light" (DRESS, `section_light_blend_s`); "Weapon look" (WEAPONS, the glint; `tuning_data.gd:1052`).
- "Audio" (AUDIO): new subgroups "World", "Stings" and "Ambience" (`ambience_db`, `ambience_fade_s`), and `boss_line_db` in "Voices". `test_audio.gd:187`'s list becomes `["Mix", "Tiers", "Layers", "Voices", "Blocks", "World", "Stings", "Ambience", "Distance", "Music", "Rumble"]`. SFX changes values only.
- "Look": "Trim" (KIT). "VFX" > "Damage looks" (LOOKS): `vfx_blood_edge_cut`.
- "Debug" (`tuning_data.gd:1392`; lines appended at its end): `kit_draw_graybox` (KIT), `look_marks_per_swatch` (LOOKS), `look_near_arm` (ARM), `audio_legacy_bank` (AUDIO), `weapon_floor_amber` (WEAPONS).

**ASSETS.md** (the headings come from step 0):
- "## Characters (Milestone 6)", with "### › Dummy" (CHAIN), "### › Veteran Punk" (LOOKS), "### › Kicker" and "### › Pipe Thug" (CREW), "### › Bruiser" and "### › Boss" (HEAVIES). ARM updates M4's "### › Player" rows.
- "## Props and weapons (Milestone 6)" (PROPS).
- "## Environment kit (Milestone 6)", with "### › Kit" (KIT) and "### › Dressing" (DRESS).
- "## Audio" (`ASSETS.md:172`) gains "### › Voices (ElevenLabs)" (AUDIO) and "### › Sound effects (ElevenLabs)" (SFX).

**Acts:**
- CHAIN: "Look: <Name> at 1 m" for every roster id (`tests/bot/acts/roster_acts.gd`).
- KIT: "Perf: level walk" (`tests/bot/level_acts/perf_acts.gd`, which prints `PERF-BENCH`; `perf_compare.sh` gains `--bot <scene>`) and "Look: kit strip".
- PROPS: "Look: props" (`tests/bot/acts/prop_acts.gd`).
- DRESS: "Look: arena tour" (`tests/bot/level_acts/tour_acts.gd`).
- WEAPONS: "Look: weapons" (`tests/bot/acts/weapon_acts.gd`).

**File ownership.**

| Package | Owns |
| --- | --- |
| CHAIN | `tools/pipeline/make_probe_body.py` (a `--regions` argument; the probe's defaults and report stay the same), `assets/source/characters/dummy/`, `assets/source/palette/dummy.json`, `assets/export/characters/dummy/`, `game/actors/art/dummy_art.tres`, `game/enemies/dummy/*`, `test_room.gd`'s dummy lines (`:23-25`, `:97-113`), the warm-up (`room_kit.gd:202-257`, `toon_materials.gd:296-342`), `tests/{test_m4_done_when,test_art_punk,art_strain}.gd` (the player's row and constants verbatim), `tests/fixtures/strain/*`, `tests/fixtures/art/roster/*`, `test_art_contract.gd`'s `BUDGETS`/`_id_of` (`:35`, `:152-160`) and report tests (`:1423`, `:1453`), `test_look_post.gd:578-580`, `tests/{test_art_roster,test_m6_tripo_ledger}.gd`, `tests/bot/acts/roster_acts.gd` |
| LOOKS | `tools/pipeline/gen_palette.py`, `assets/source/palette/{punk,shared}.json` and `variants/`, `assets/export/palette/` (by rule), `game/fx/{toon.gdshader,damage_look.gd}`, `ToonMaterials.swatch_glossy()`, `game/enemies/{enemy_variant.gd,variants/*}`, `_apply_variant_look()`, `tests/{test_toon,test_damage_look}.gd`, `test_attack_arcs.gd:322-340`, `test_art_contract.gd`'s palette tests (`:397`, `:1336-1360`), `tests/test_m6_no_placeholders.gd`, the ratchet (by rule) |
| KIT | `game/level/kit/*` (except `pickup_spot.gd` and step 0's lines), `game/level/kit/art/*`, `RoomKit.add_box`/`add_visual_box`/`box_mesh`/`build_environment`, `game/fx/trim.gdshader`, `ToonMaterials.trim()` and `Kind.TRIM`, `tools/gen_trim.gd`, `assets/{source,export}/kit/`, the `section_entered` emit in `level_root.gd`, `tests/{test_kit,test_m6_colliders}.gd`, `tests/fixtures/m6/m5_colliders.json`, `test_look_post.gd:452-466, 518-560`, `test_level_kit.gd:210-214`, `test_m4_contracts.gd:302-324`, `perf_acts.gd`, `tools/perf_compare.sh`, street A1's lines in `street.tscn` |
| AUDIO | `game/audio/*` (a new `audition_room.gd`), `tools/audio/{ingest.py,eleven_sfx.py,eleven_policy.json}`, `tools/gen_sfx.gd` (the output folder), `assets/source/sfx/{manifest.json,eleven/,eleven_ledger.jsonl}`, `assets/export/sfx/{grunt,effort,ko,player_grunt,boss}*`, `tests/fixtures/sfx_legacy/`, `test_room.gd`'s audition lines, `help_overlay.gd:41-43`, `tests/{test_audio,test_audio_crowd,test_audio_m6}.gd` |
| PROPS | `tools/pipeline/run.py` (the `--kind prop` branch), `blender_palette.py` (the no-armature flag), `blender_export_prop.py`, `assets/source/props/`, `assets/source/palette/{weapons,props}.json`, `assets/export/props/`, `game/actors/art/static_art.gd`, `ToonMaterials.art_prop()`, `game/level/props/*`, `game/weapons/art/*`, `weapon.gd`'s `art_scene` lines and `pipe.tscn` (phase 1 only), `tests/test_static_art.gd`, `tests/bot/acts/prop_acts.gd` |
| HEAVIES | `assets/source/characters/{bruiser,boss}/`, `assets/source/palette/{bruiser,boss}.json`, `assets/export/characters/{bruiser,boss}/`, `game/actors/art/{bruiser,boss}_art.tres`, the `art` lines of `bruiser.tscn` and `boss.tscn`, `boss.tscn:7` (`display_name`), `enemy_catalog.gd:18` (the label), `tests/fixtures/{art/roster,strain}/{bruiser,boss}.json` |
| CREW | the same as HEAVIES, for `kicker` and `thug` (`kicker.tscn`, `pipe_thug.tscn`) |
| DRESS | `game/level/mission1/{street,roofs,boss_roof}.tscn` (everything except A6's `weapon_scene`), `LevelSection`'s light exports, the light blend in `level_root.gd`, `look_post.gd:164-175`, `crowd_room.gd` and `test_room.gd` geometry, `trim_layout.json` colours, `tests/test_m6_dress.gd`, `tour_acts.gd`, `tests/test_m5_{street,roofs}.gd` (dressing-only edits) |
| WEAPONS | `game/weapons/*` (except `art/`), `player.gd`'s weapon paths, `pipe_thug.gd`'s pipe lines, the weapon tables of `placeholder_poses.gd` and `placeholder_anims.gd`, `gen_moves.gd`'s weapon moves and `impact_sfx` values, `test_room.gd:114-117`, `tests/{test_weapons_m6,test_pickup_cue}.gd`, `test_level_kit.gd:621-661`, `weapon_acts.gd` |
| ARM | `tools/pipeline/{player_parts.py,player_run.py}`, `assets/{source,export}/characters/player/`, `first_person_camera.gd` (the arm swap), the `__fp_arm` lines in `skinned_art.gd` (`:23-25`, `:243`) and `humanoid_rig.gd` (`:1311-1313`), `fp_show_upper_arm` in `move_data.gd`, `gen_moves.gd:134-160`, `tests/{test_art_player,test_skinned_art}.gd`, `test_art_contract.gd:33, 245-262, 1180-1200`, the player's row and `*_PLAYER` constants wherever CHAIN put them |
| SFX | `assets/source/sfx/eleven/sfx_*` (its jobs and MP3s), the hit-stack, block, world, sting and ambience wavs and their manifest rows, values in the Audio group, `test_audio.gd`'s ranking expectations |
| Lead | step 0, README.md, docs/HANDOFF.md, the ASSETS.md headings, `tuning_presets/default.tres`, the atlas PNG and the ratchet at merges, A6's `weapon_scene` (`roofs.tscn:1117-1119`), the merges |

**Shared files.** Each owner edits only its own region, appends, and never reorders; the lead resolves conflicts between adjacent lines:
- `room_kit.gd` (CHAIN, KIT);
- `toon_materials.gd`: the `Kind` enum at `:24` (KIT and PROPS append), `warm_up` (CHAIN), `swatch_glossy` (LOOKS), `art_prop` (PROPS), `trim` (KIT);
- `test_room.gd` (CHAIN and AUDIO in phase 1; DRESS and WEAPONS in phase 2);
- `test_art_contract.gd` (CHAIN and LOOKS; then ARM);
- `test_look_post.gd` (KIT, CHAIN);
- `tuning_data.gd`;
- `move_data.gd` and `gen_moves.gd` (ARM, WEAPONS);
- `weapon.gd` (PROPS, then WEAPONS).

## 3. The packages

Every brief adds to build.js's COMMON rules. Each package:
- fills its own ARCHITECTURE.md heading;
- writes its calls to `docs/milestones/M6-calls/<KEY>.md`;
- reports spec departures for README's "Where M6 departs from the spec".

Estimates are % of a 5-hour window, and are the gate's reservation. A builder who finds that a pinned contract can't work as written stops at a `wip:` commit and reports, rather than changing it. A Tripo retry for a character costs 55 credits, because a new generation must be rigged again (30 + 25, `tripo_prices.json`).

### CHAIN: The art chain for every character
est 10 · Godot · Blender · P1 · no paid services.
**Goal.** Make M4's chain and tests per-character once, so that CREW and HEAVIES add a folder and a roster file and nothing else. Prove it with the dummy (D17).
**Read.** `art-chain.md` §1-§6 and §8; this plan §1 D15-D17, D26-D27, §2 "Art roster", "Palette slots".
**Build.**
- The roster loader. Every A1-A12 row and `test_art_punk.gd`'s checks read it; `_rig()` no longer hard-codes 1.8 (`test_m4_done_when.gd:177`). The Punk's numbers move unchanged into `punk.json` and `strain/punk.json`. The player's row and the `*_PLAYER` constants carry over verbatim.
- `test_art_contract.gd`'s `BUDGETS` and `_id_of` read the roster (`:35`, `:152-160`, `:390`).
- `gen_strain_ratchet` per id, at each id's height.
- The M6 Tripo ledger test: every M6 task finished, the sum at most 900, the balance never below 700, A13's M4 check unchanged.
- Warm-up of every catalog art (D27). A broken art fails a roster test (`has_art()`), not only a warning (`skinned_art.gd:75`).
- **The dummy:**
  - `make_probe_body.py` gains `--regions <json>`, keeping its defaults, so the probe report and `:1453`'s guard hold;
  - `--source` builds into `assets/source/characters/dummy/`, with a padded palette in slots 56-59 (no red, 4-6 colours), `split_fp` off and a budget of 15000;
  - `dummy_art.tres` and `training_dummy.tscn`'s `art`. The KO segments still draw (`training_dummy.gd:40-46`), and the dummy colours go.
- "Look: <Name> at 1 m" for every roster id.

**Tests.** `test_art_roster.gd` (each file loads, its art attaches at its height, the report is present); the M4 suites green on the roster; the dummy's rows; the ledger test.
**Evidence.** "Look: Dummy at 1 m", and "Look: Punk at 1 m" unchanged against `captures/m4`.
**Done when:**
- the full suite passes;
- the Punk's M4 numbers are byte-identical;
- `run.py --asset dummy --check` says YES;
- the calls file names the inventory drop the lead should see.

### LOOKS: Damage classes, the veteran's palette, the inventory
est 7 · Godot · no Blender · P1 · no paid services.
**Goal.** D6, D4 and the placeholder inventory that defines M6's done. (D7 is ARM's, in phase 2.)
**Read.** `weapons-looks.md` §4 and §6; this plan §1 D4, D6, D17, D24-D25, §2 "Palette slots", "Placeholder inventory".
**Build.**
- **D6:** the `blood` flag, its alpha class and thresholds in `gen_palette.py` (documented in its docstring), `swatch_glossy()` and the shader; slot 17 gets `blood: false`; `vfx_blood_edge_cut`; `look_marks_per_swatch`.
- **D4:** variant atlases and `EnemyVariant.palette`, applied in `_apply_variant_look()`. `punk_veteran.json` recolours the vest and trousers: saturated, not red, clear of the Punk's teal and the player's blue. No shipped variant uses a tint.
- **The inventory** exactly as §2 describes it, with the ratchet measured on this base.

**Tests.** The class decode and atlas tests extended; blood never on a `blood: false` swatch (a shader-side sample test); the veteran's atlas (4-6 colours, not red, the same alphas); `test_attack_arcs.gd:322-340` checks the palette instead of the tint; `test_m6_no_placeholders.gd`.
**Evidence.** A/B stills at 1 m: the bloodied Punk's cap, old and new; the veteran beside the Punk at 1 m and 5 m. Name their paths in the result: the lead sends them to Game-boy.
**Done when:**
- the full suite passes;
- `gen_palette.py --check` says YES;
- the inventory passes at its measured ratchet.

### KIT: The environment kit
est 10 · Godot · no Blender · P1 · no paid services.
**Goal.** Everything the dressing needs, proved on street A1:
- the trim shader and sheet;
- procedural modules and the art hook;
- dressing and prop spots;
- barrier panels and stair flights;
- `section_entered`;
- the collider guard and the level perf act.

**Read.** `level-env.md` (all); this plan §1 D1-D2, D9-D13, D29, §2 "Kit", "Static props" (the prop ids), "Tuning", "Acts"; `docs/milestones/M4-look-bible.md`.
**Build.**
- **First commit, before any art:** "Perf: level walk" (street A1-A3 and the roofs, god mode, a fixed route) and `perf_compare.sh --bot`. Its sha goes in `M6-calls/KIT.md`. Then `m5_colliders.json` and its test.
- The trim shader, `gen_trim.gd` and the sheet:
  - strips for brick, plaster, concrete, asphalt, kerb, roof tar, gravel, metal, shutter, chain-link (alpha scissor), wood crate, trim and ink;
  - colours inside the bible's band (DRESS retunes them to the moods).
- `KitMesh` (§2's kinds), the `add_box` hook, `LevelBlock.module`/`draw_box`, `Dressing`, `KitPiece`, `PropSpot` (it draws PROPS's scenes when they exist), and `kit_draw_graybox`.
- The barrier panels (`shutter`, `gate`; the car through `PropSpot`'s rule, one per `car_length_m`, `barrier.gd:201-217`) and the stair flight.
- `section_entered` from `LevelRoot` (D12's rule).
- Trim-aware checks replace the box and albedo assumptions of `test_look_post.gd` and `test_m4_contracts.gd`. They read the sheet's pixels against the bible (saturation at most 0.30, value 0.25-0.6).
- Street A1 dressed as the proof.

**Tests.** `test_kit.gd`:
- every kind within 5000 triangles at sizes from the census;
- UVs in metres;
- one shared material;
- `draw_box` hides only the mesh;
- `section_entered` fires once per crossing.

The colliders, barrier and navmesh tests stay unchanged.
**Evidence.** "Look: kit strip" against `captures/m5-final/street`:
- the doorways are still dark openings;
- no dashed coplanar lines;
- no doubled ink.

Plus the perf act's numbers, at the first commit and at the end.
**Done when:**
- the full suite passes;
- A1 reads as a street in first person;
- the perf act runs on both commits;
- the calls file names the inventory drop.

### AUDIO: Ingest, manifest, voices and the audition room
est 8 · Godot · no Blender · P1 · ElevenLabs at most 6000 credits; no Tripo, no Gemini.
**Goal.** The pipeline and the slots, so that SFX only generates and chooses files; every voice from ElevenLabs; an audition room for Game-boy's ear.
**Read.** `audio.md` (all); this plan §1 D8, D18-D25, §2 "Audio", "Tuning", "Placeholder inventory".
**Build.**
- **`ingest.py`** (§2):
  - decode, mono, 44.1 kHz, s16, trim;
  - fades so the ends sit within 0.004;
  - a loudness or peak target;
  - `--check`.
  - Also: the manifest, with every existing file as a `gen_sfx` row, and the legacy copies (D24).
- **`eleven_sfx.py` and its policy:**
  - **First call:** one 0.5 s job, to measure the real cost (before and after). Write the rate in `M6-calls/AUDIO.md`.
  - **Then project the batch:** rate x the summed durations x the candidates.
    - Over 6000: drop to one candidate per clip, starting with the KO lines and the player grunts.
    - Still over: generate only the minimum per pool (grunt 3, effort 2, ko 1, `boss_phase` 1, `player_grunt` 2), stop at a `wip:` commit, and ask in `requests`.
    - Always set `duration_seconds`.
  - **The voices (D20):**
    - per archetype: 4 grunts, 3 efforts and 2 KO lines (role and build per SPEC §7; the boss's 0.7 pitch stays a multiplier, so prompt a deep voice and don't double it);
    - the shared `grunt` (4) and `effort` (3);
    - 3 player grunts and 2 boss phase lines.
  - Two candidates per kept clip when the budget allows. Choose by measured features (onset, length, peak) and log each choice.
- **The slots** of D23 on step 0's signals:
  - `play_2d`, `set_ambience` and the bed player, subscribed to `section_entered`, defaulting to `ambience_street` with no section;
  - per-archetype pools with the fallback;
  - `impact_sfx` read off `hit.move`.
  - World slots stay empty until SFX: an empty pool plays nothing and logs nothing, and the inventory counts it as `empty_slots`.
- **The audition room** in the training room:
  - `[` and `]` page through the banks;
  - the digits play the variants;
  - `-` toggles old and new;
  - `=` plays the whole bank;
  - listed in the help overlay, ignored while `GameInput.menu_open`.

**Tests.**
- `test_audio.gd`: the subgroup list and the long-pool exemption.
- `test_audio_m6.gd`:
  - every shipped wav has a manifest row, and the reverse;
  - the format;
  - the ledger's sum within the stop;
  - the fallback pools;
  - each slot plays on its signal;
  - the bed is not a pooled voice;
  - every file under `assets/source/sfx/` has an ASSETS row and is in LFS (A13 scans only `assets/export` and the concepts, `test_m4_done_when.gd:1128`).
- `test_audio_crowd.gd`'s voice peak stays under 32.

**Evidence.** The ledger and the per-call costs, plus `ffprobe` and loudness per new pool, in the calls file. The lead plays the audition room.
**Done when:**
- the full suite passes;
- every voice pool meets its `min_variants`, or the stop is committed and requested;
- `ingest.py --check` rebuilds every ElevenLabs file's PCM.

### PROPS: The static-prop path and every rigid model
est 9 · Godot · Blender · P1 · Tripo at most 270 credits (six models x 30, three retries x 30); Gemini at most 16 images.
**Goal.**
- The static-prop path.
- Then the pipe, the bike chain's parts, and the car, dumpster, AC unit and water tank, so that WEAPONS (phase 2) and DRESS find real art waiting.

**Read.** `art-chain.md` §1, §7 and §8; `weapons-looks.md` §1-§3; this plan §1 D5, D13-D14, §2 "Static props", "Palette slots"; `tools/pipeline/tripo_prices.json`; the concepts `weapon_a.jpg`, `mood_street_a.jpg` and `mood_roof_a.jpg`.
**Build.**
- **The path:**
  - `run.py --kind prop`, the no-armature flag, `blender_export_prop.py`;
  - `StaticArt` and its `check()`, and `art_prop()`;
  - first proved on a Blender-scripted `_fixture` crate, with no Tripo;
  - D14's hull choice from a capture.
- **Per model:**
  - one Gemini reference in the house style (the props follow the moods);
  - Tripo image-to-model at standard (30 credits);
  - a palette (weapons in slots 28-31, props in 60-63, no red);
  - at most 3000 triangles;
  - an ASSETS row with the licence string.
- **The bike chain:** a Tripo padlock, plus a scripted `Grip` and `Link`, in the pinned frame.
- **The art scenes:** `Weapon.art_scene`; `pipe.tscn` sets it. The Thug's and the training room's pipes then draw art.

**Tests.**
- `test_static_art.gd`: every scene's `check()` is empty; the weapon art sits in the frame within 2 cm of `length`; `bike_chain` has `Lock`, `Grip` and `Link`.
- The M1-M5 weapon tests stay unchanged (`weapons-looks.md` §7).

**Evidence.** "Look: props" (each model at 1 m and 5 m in the training room, the pipe in a Thug's hand) and a still of a hull.
**Done when:**
- the full suite passes;
- `--check` says YES for each prop;
- the ledger's PROPS rows come to at most 270;
- the calls file names the inventory drop.

### HEAVIES: The Bruiser and the boss
est 13 · Godot · Blender · P2 · Tripo at most 350 (the Bruiser 55; the boss 75 with `geometry_quality detailed`; the boss's glove fist 50; at most three retries x 55) · Gemini at most 24 images.
**Goal.** Both through the chain at their heights, at the Punk's bar at 1 m.
**Read.** `art-chain.md` §1-§4 and §8-§9; this plan §1 D3, D6, D15-D16, §2 "Art roster", "Palette slots"; ARCHITECTURE.md "### The art chain for every character (CHAIN)".
**Build.** Per character:
1. Views on the mannequin's bone lengths, with the bulk added sideways (`views_check.py` passes).
2. Tripo generation, the rig-check (free), the rig.
3. `pipeline.json`: girth and rig clamps, `facing_yaw_deg` from the toe signal.
4. The palette: slots 44-49 and 50-55, no red, `blood: false` on hoods, hair and armour.
5. The GLB, the art resource, the scene's `art`, the roster and strain files, the ASSETS rows.

The details:
- **Bruiser A:** a purple hood with a steel visor and a mask, a padded purple jacket over steel plates, steel forearm guards and knee pads, a procedural fist.
- **The boss:** Ox Pellerin (`boss.tscn:7`'s `display_name`, the catalog label). A hooded robe in charcoal, darker than the concept's slate, with orange trim; the champion's belt; boxing gloves through a generated glove fist; budget 30000.
- **A6** at the torso limit (0.288 m at 2.05, 0.316 m at 2.3, `art-chain.md:56`): clamp first. A ratchet (A6, or the boss's `a5_extent`) only with a logged reason.

**Tests.** The roster rows; A9 framing and the lens rules for each strike that reaches the lens (the overhead smash, headbutt, charge, slam, pound).
**Evidence.** "Look: Bruiser at 1 m" and "Look: Boss at 1 m"; the boss beside a Punk at 5 m. Judge by `art-chain.md` §9's rubric.
**Done when:**
- the full suite passes;
- `--check` says YES for both;
- `primitive_bodies` drops by both ids.

### CREW: The Kicker and the Pipe Thug
est 12 · Godot · Blender · P2 · Tripo at most 250 (2 x 55, at most two retries x 55; procedural fists, and a generated one only with the lead's yes) · Gemini at most 20 images.
**As HEAVIES**, for:
- **`kicker`** (1.8 m, slots 22-27; moves: the jump kick and the low sweep). Kicker C: a hooded lime vest, a lime bandana, a black cap, a ponytail, wrapped forearms, black cargo shorts over lime leggings.
- **`thug`** (slots 38-43; the three pipe swings and the carry, `enemy_poses_thug.gd`). Thug B: a black beanie, a yellow-patterned bandana, a sleeveless olive hoodie with a chest strap and a yellow buckle, yellow wrist wraps, olive trousers with yellow bands. He holds PROPS's pipe, so his hands must hold a 0.028-0.04 m grip.

Read `game/enemies/{kicker,thug}/*.gd` in place of the heavies' scripts. **Done when:** as HEAVIES.

### DRESS: The level, the crowd street and the training room
est 12 · Godot · no Blender · P2 · no paid services.
**Goal.** Every section and both rooms in the kit: the skyline, section light (D12), ambience ids and the prop spots, with readability kept.
**Read.** This plan §1 D1, D8-D13, §2 "Kit", "Static props", "Tuning"; ARCHITECTURE.md "### The environment kit (KIT)"; `level-env.md` §1, §4-§6 and §8; the look bible's "Colour"; `mood_street_a.jpg` and `mood_roof_a.jpg`.
**Build.**
- The sheet's colours tuned to the moods, inside the bible's band.
- Facades, doorways, shutters, rails and stairs in `Dressing`.
- `PropSpot`s for the four pinned ids, visual only, never on a walkable cell without a block below.
- The skyline and far ground with depth, fixing `final-sees-03`'s pale drop at the boss roof's gap.
- Section light and ambience per section.
- The crowd street and the training room through `add_box`'s art.
- Spawn doorways stay dark openings, and nothing overhangs its collider into a spawn.

**Tests.** `test_m6_dress.gd`: no graybox box drawn in the three scenes; spawn doorways darker than their walls; `section_light_blend_s` honoured. The colliders, M5 done-when and navmesh tests stay unchanged.
**Evidence.** "Look: arena tour", "Look: drops" and "Look: seams" against `captures/m5-final`; "Perf: level walk" against KIT's baseline commit.
**Done when:**
- the full suite passes;
- `boxes` is 0 in all three scenes.

### WEAPONS: The catalog, the second weapon and the glint
est 8 · Godot · no Blender · P2 · no paid services.
**Goal.**
- `WeaponDef` and the catalog, and `player.gd` generalised (D5, D22).
- `impact_sfx` on every weapon move.
- `bike_chain` (its scene from PROPS's parts, its moves, its sim).
- The floor glint (D28), and `weapon_landed`.

**Read.** `weapons-looks.md` §1-§3 and §6-§7; this plan §1 D5, D22-D23, D28, §2 "Weapons", "Static props"; ARCHITECTURE.md "### The static-prop path and every rigid model (PROPS)".
**Build.**
- The weapon scenes keep the capsule collider and the grip and tip points.
- The moves go in `gen_moves.gd`, reusing the pipe recipes with their own reach, arc and timing.
- The sim:
  - reads the grip and the tip and the game-time delta, as Verlet points;
  - draws the `Link` meshes as a `MultiMesh`;
  - never touches hits or physics.
- `weapon_landed` fires at the first contact after a throw or a drop.
- The Thug's pipe drop is unchanged.

**Tests.**
- `test_weapons_m6.gd`, for both weapons: pick up, the 3-hit chain at 10, the break after 8 hits, the 15 throw, the guard drain, durability per def.
- The M1-M5 weapon tests pass.
- The glint is visible from 10 m in a ray test from eye height.
- `weapon_landed` fires once per landing.

**Evidence.** "Look: weapons": pick up, three swings, the throw, the glint at 5 and 10 m.
**Done when:**
- the full suite passes;
- `cylinder_weapons` and the amber `tints` are 0.

### ARM: The near upper arm
est 6 · Godot · Blender · P2 (after CHAIN) · no paid services.
**Goal.** D7, and the A/B stills the proposal promised.
**Read.** `weapons-looks.md` §5; this plan §1 D7, §2 "Art roster" (the player's row); `docs/milestones/M4-calls/F-player-art.md` (grep `check`); the roster's player row as CHAIN landed it.
**Build.**
- The hero rebuild with `Body__fp_arm`, closed with inward caps at the new cut (`player_run.py`).
- `skinned_art.gd` treats the `__fp_arm` suffix as first-person-hidden (`:243`).
- `fp_show_upper_arm` on the haymaker and the uppercut (`gen_moves.gd`, then `--import`).
- The camera's swap and restore.
- The three-mesh tests become four.
- Report any player constant that moves, with old -> new.

**Tests.** The first-person camera draws the arm only during those two moves, and the side view always draws it; `player_run.py --check`.
**Evidence.** The haymaker and the uppercut mid-strike, old and new. Look for dashed edge-pass lines at the dome (`weapons-looks.md` §5).
**Done when:**
- the full suite passes;
- `player_run.py --check` says YES.

### SFX: The generated sound effects
est 6 · Godot · no Blender · P2 (needs only AUDIO's merge) · ElevenLabs at most 20000 credits; no Tripo, no Gemini.
**Goal.** Generate, choose and ingest every pool that isn't a voice, through AUDIO's `eleven_sfx.py` and `ingest.py`, so that `generated_sfx` and `empty_slots` reach 0 (the music loop excepted, D25):
- the hit stack (`whoosh`, `thud`, `crack`, `crunch`, `body_fall`, `sub_thump`) and the blocks (`block_clack`, `parry_ting`, `guard_break`);
- the barriers, the weapons (`weapon_pickup|throw|break|land`, and `weapon_<impact_sfx>_hit` for the pipe and the bike chain);
- the GO and CLEAR stings, and the two ambience beds.

**Read.** `audio.md` §1, §4 and §6; this plan §1 D18-D19, D21, D23-D24, §2 "Audio", "Placeholder inventory"; ARCHITECTURE.md "### Ingest, manifest, voices and the audition room (AUDIO)"; `docs/milestones/M6-calls/AUDIO.md` (the measured rate); the manifest; `tests/test_audio.gd` lines 124-243.
**Build.**
- One jobs file per group (`assets/source/sfx/eleven/sfx_<group>/`).
  - Prompts in the game's style: comic-book, punchy, dry (no reverb tail), and original (never "like <a game or film>").
  - Each hit-stack pool is one layer: a thud is the body impact alone, a crack the bone snap alone. The tier stack layers them.
- Always set `duration_seconds` (0.5 s at least).
  - Ingest trims to the test's limits: one-shots under 1.5 s, and whooshes peaking within 50 ms.
  - The beds use `loop: true` at about 20-30 s; the stings are 1-2 s, in 2D.
- **Before the batch, project its cost** from AUDIO's measured rate. Use 3 candidates per kept clip within the ceiling; otherwise 2; otherwise 1, and say so in `requests`.
- **Choosing:**
  - choose by measured features (onset, peak time, length, spectral centroid against the old file's role) and log each choice;
  - the runners-up stay in their job folders, so a later swap needs no new generation.
- 3-4 variants per hit-stack pool (at least the test's minimums), and 2 per world pool.
- Rebalance the Layers dB so that `test_audio.gd`'s tier ranking holds.
- The ASSETS rows read "ElevenLabs sound-effects API (Starter, commercial licence)", with the ledger id.

**Done when:**
- the full suite passes;
- `ingest.py --check` rebuilds every row;
- `generated_sfx` and `empty_slots` are 0;
- the audition room plays every pool new;
- the calls file lists the cost by group.

## 4. Merge order and phase 3

1. **Step 0 (§0).**
   - DM Game-boy D2's change (sent 14:56 CST; the Sonniss ask in it is withdrawn, D19).
   - Launch P1 after `get_usage`.
2. **Phase 1 merges.** Merge each P1 package as it finishes; after each, the preset, the atlas, the ratchet and the full suite.
   - After LOOKS, send its A/B stills.
   - After AUDIO, play the audition room and send its run command.
   - HANDOFF.
3. **Phase 2 launches.** Launch P2 once phase 1 has merged. With under 35% headroom, launch `only: ["DRESS", "WEAPONS"]` and leave the rest for a fresh window. Launch P2b as §0 says.
4. **Phase 2 merges.** Merge each P2 package as it finishes.
   - After WEAPONS, set `Pickups/PipeBigShutter`'s `weapon_scene` to `bike_chain.tscn` (`roofs.tscn:1117-1119`), rerun `test_m5_roofs.gd`, and lower `second_weapon`.
   - After ARM, send its stills.
   - One post-merge fixer (Sonnet). HANDOFF.
5. **Record once** into `captures/m6-final/` with `tools/record_acts.sh`:
   - every "Look: <Name> at 1 m" (punk, kicker, thug, bruiser, boss, dummy), "Look: lineup", "Look: weapons", "Look: props", "Look: own limbs";
   - with `BOT_SCENE=res://tests/bot/level_bot.tscn`: "Look: arena tour", "Look: drops", "Look: seams", and "Run: held back" for the street (0-2), the roofs (3-5) and the boss (6).
6. **The lead's look** at full-resolution stills of each character at 1 m beside its concept, every arena's tour, and the weapons.
7. **Review** (`tools/workflows/review.js`, `args-review-final.json`):
   - `chars` (Opus, high): `art-chain.md` §9 per character, height read, the veteran against the Punk, D6.
   - `world` (Opus, high): the dressing in first person, doorways, drops, the weapons and the glint, the light, both rooms.
   - `code` (Sonnet, high): §2 as landed, no numbers in scripts, the layer rules, an honest inventory, budgets, ledgers, the manifest, `--check`.
   - Skeptics (Sonnet, medium) for high and medium findings only. One fix wave of at most 3, then a re-check of the changed items only.
8. **Frame time:** `tools/perf_compare.sh --bot res://tests/bot/level_bot.tscn --act "Perf: level walk" --runs 3 <KIT baseline sha> HEAD`, and "Perf, six with ragdolls" for `main` against HEAD. A mean more than 15% over is a fix item.
9. **Close:** README's "Where M6 departs from the spec" (D19, D25, and anything the packages report), the PR, and the DM with the run command and the audition keys.

## 5. The done-when, row by row

| # | Row | Checked by |
| --- | --- | --- |
| 1 | No placeholder in the level, the crowd street or the training room (only the allowed list) | `test_m6_no_placeholders.gd`, every key of the ratchet at 0 |
| 2 | Triangle budgets: enemy 15000, boss 30000, module 5000, prop or weapon 3000; the sheet 2048² | A2 on the roster, `test_kit.gd`, `StaticArt.check()` |
| 3 | Every asset has an ASSETS.md row with source, service and licence; binaries in LFS | A13 (`assets/export`, concepts), `test_audio_m6.gd` (`assets/source/sfx`) |
| 4 | Every generated asset rebuilds | `run.py --check` per character and prop, `player_run.py --check`, `gen_palette.py --check`, `gen_trim.gd --check`, `ingest.py --check` (no skips) |
| 5 | Paid services stay inside the policy | `test_m6_tripo_ledger.gd` (<= 900, floor 700); `test_audio_m6.gd` (ElevenLabs <= 30000) |
| 6 | The game underneath is unchanged | `test_m6_colliders.gd`; the M3, M4 (on the roster) and M5 done-when tests; the readability metrics |
| 7 | Frame time | §4 step 8, against M5 |
| 8 | Game-boy's judgement | the characters at 1 m at the Punk's bar, the world, the audio in the audition room |

## 6. Budget

Usage at the plan's start was about 3% of the 5-hour window and 12% weekly. A Sonnet builder measured 4-7% in M4 (HANDOFF "Model, effort and process rules"). The packages below carry more than one M4 builder's scope, so the estimates sit above that range.

| Phase | Agents | Estimate |
| --- | --- | --- |
| 0 | The plan, its critic, the synthesis | about 6% |
| 1 | CHAIN 10, KIT 10, PROPS 9, AUDIO 8, LOOKS 7; the lead (step 0, 5 merges, suites, the DM) 8 | about 52% |
| 2 | SFX 6, HEAVIES 13, CREW 12, DRESS 12, WEAPONS 8, ARM 6; a fixer 5; the lead 9 | about 71% |
| 3 | 2 Opus lenses 12, a Sonnet lens 3, skeptics 5, fixers up to 15, re-check 4, perf 2, the lead 6 | at most 47% |
| M6 | | about 175% at most: three windows with handoffs, about 17-21 weekly points |

**Splits at the 90% handoff.** Check `get_usage` before every launch.
- **Window 1:** phases 0 and 1 (about 60%), then DRESS and WEAPONS (§4 step 3).
- **Window 2:** SFX, HEAVIES, CREW, ARM, the fixer. A builder that's cut off resumes from its `wip:` commit when the same args are rerun.
- **Window 3:** phase 3. The lenses and skeptics in one window, never splitting a lens.

## 7. Critique applied

| Id | Applied? | Why |
| --- | --- | --- |
| H1 | Applied (the sequenced form) | D7 moved to a new phase 2 package, ARM, which cuts after CHAIN merges and owns the named regions (§2). LOOKS drops Blender and the hero. `test_attack_arcs.gd:322-340` goes to LOOKS, `test_look_post.gd:578-580` to CHAIN. |
| H2 | Applied | `SONNISS_DIR` lives outside the repo (default `~/sfx-library/sonniss`). Sources are written `sonniss:<relative path>`, `--check` reports skips, and the DM names the folder. The disk now has 89 GB free, so the bundle is his choice. |
| H3 | Applied | `primitive_bodies` and `cylinder_weapons` count every id and weapon a scene can put in play (checked: `grep -c enemies/` is 0 in `mission1/*.tscn`). |
| H4 | Applied | SONNISS moved to `args-P2b.json`, with a WAV check as its first step. P2 has `only`, and WEAPONS is Godot-only now, so it never holds a slot while waiting for Blender. |
| M1 | Applied | `EdgeQuad`, the warm-up meshes and the legacy A/B are allowed by name. AUDIO re-sources the shared `grunt`/`effort`. New categories: `second_weapon` and `empty_slots`. |
| M2 | Applied | In phase 1 the builders report the expected drop, and the lead re-measures after each merge. Phase 2 lowers the ratchet itself. |
| M3 | Applied | Step 0 declares the three signals, both barrier emits, `ambience` and `impact_sfx`. KIT emits `section_entered`; AUDIO owns the bed hookup (rooms default to `ambience_street`); WEAPONS emits `weapon_landed`. The prop ids and sizes are pinned. After step 0, `barrier.gd` is KIT's alone; the shared-file list now covers `toon_materials.gd` and `tuning_data.gd`. |
| M4 | Applied | AUDIO's brief has the projection rule after the measuring call. |
| M5 | Applied | Character retries are priced at 55. Ceilings: HEAVIES 350, CREW 250, PROPS 270 (870 of the 900 stop). The boss gets a generated glove fist and an `a5_extent` ratchet. |
| M6 | Applied, in another form | The static-prop path went to a new phase 1 package, PROPS, which also makes every rigid model. It pairs with CHAIN on the Blender slots, and WEAPONS becomes Godot-only in phase 2. Section light moved to DRESS, and the gate estimates were raised. |
| M7 | Applied | The pick and the licence are in the inputs and the args notes. Roof C is `mood_roof_a.jpg`. No pick or Tripo gate remains. `args-P1.json` launches only packages that need nothing but step 0. PROPS uses the weapon pick and the moods, both already answered. |
| L1 | Applied | `game/level/grid.gdshader`. |
| L2 | Applied | The atlas rule is in §2 "Palette slots". |
| L3 | Applied | `test_audio_m6.gd` covers `assets/source/sfx`; A13 is unchanged. |
| L4 | Applied | Bitexact flags, and `--check` compares PCM. |
| L5 | Applied | D2 names the change, and §4 step 1's DM carries it. |
| L6 | Applied | CHAIN owns `make_probe_body.py --regions`. |

**Since the critique:** Game-boy chose ElevenLabs for every sound (2026-11-04 15:05). SONNISS became SFX in phase 2 (§3), D19 was rewritten, the ElevenLabs stop went from 12000 to 30000 (40,000 on the account), and H2 and H4's Sonniss parts are moot.
