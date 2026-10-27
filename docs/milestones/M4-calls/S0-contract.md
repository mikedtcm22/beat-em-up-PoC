# S0-contract: judgement calls

Package S0-contract (phase 0): the seams, the stubs, the Look tunables, the joint table and one test move. No behavior change to the M3 game.

## C1. `Look` goes between `Audio` and `Debug`, so one existing test changed
- **Decision.** The "Look" group is declared between "Audio" and "Debug" as A9 says. `tests/test_audio.gd::test_the_audio_tuning_group_sits_before_debug` pinned "the group right after Audio is Debug" (M2's way of saying the audio group sits before the cheats). It now expects Look right after Audio and Debug right after Look.
  - Old: `assert_eq(groups[at + 1], "Debug")`.
  - New: `assert_eq(groups[at + 1], "Look")` and `assert_eq(groups[at + 2], "Debug")`.
  - Twin on the visible path: `test_the_look_group_sits_between_audio_and_debug` in `tests/test_m4_contracts.gd` (Look after Audio, Debug after Look, Debug still last).
- **Alternative not taken.** Put Look after Debug, which leaves every existing test untouched. A9 names the placement ("between Audio and Debug") and the panel order is the only reason for it, so the binding text wins over the lead's "no existing test edited" line, which only restates A6's done-when and did not foresee this assertion. The intent of the test (Audio is an ordinary group that precedes Debug, not part of it) is kept. The lead can reverse it by moving the Look block below Debug and reverting the test hunk.

## C2. No `Art` subgroup in Look
- **Decision.** §2.9 listed an Art subgroup whose only name was `look_show_art`; A9 moved that name to Debug. An empty `@export_subgroup` is invisible (the panel and `Tuning.exported_properties()` list properties only), so none is declared. P1-skin adds `@export_subgroup("Art")` itself if it ever has a look tunable.
- **Alternative not taken.** Invent a seed (an art fit offset, say) to fill it: a dead slider nobody asked for.

## C3. The seed values
- **`look_outline_px` = 3.75, not 3.0.** Part C §2.9 said 3.0 at 1080p; the look bible (A11, written later) says "start at 3.75" inside 3.5-4 px. The bible follows A11, which overrides Part C. Range 0.5-8.0. Not read by anything in S0.
- **`look_mid_level` = 0.72** (the bible: mid band at 72% of lit), range 0.3-1.0, as the Toon seed. **`look_edges_enabled`** and **`look_grade_enabled`** (both true, bools) seed Edges and Grade. **`fp_knockdown_hide_torso`** (false, today's behavior; the third deferred feel question of §8) seeds FP feel. **`look_hull_on_placeholders`** (true, A7) sits in Outline and is only declared.
- **Alternative not taken.** Seeds with the plan's other names (`look_band_1`, `look_edge_px`, `look_grade_strength`): they are the owners' to add, and each needs a range that depends on how the shader reads it.

## C4. A rig whose art does not attach keeps its primitives
- **Decision.** `_build_meshes()` builds the proxies, calls `SkinnedArt.attach()`, then `set_art_shown(true)`, which hides the primitives only when attach returned meshes. `has_art()` is `not art_meshes().is_empty()`. With the S0 stub (returns `[]`) an actor given an `art` still draws its primitives.
- **Alternative not taken.** Hide the primitives whenever `art != null`, as §2.2 reads literally: a stub, a failed attach or a bad GLB would then leave an invisible body. Once P1-skin's `attach()` returns meshes the two readings are the same.

## C5. `art_material()` is a plain textured material until P1-toon
- **Decision.** §2.3's `art_material()` returns null without art, and with art one `StandardMaterial3D` per rig (palette as albedo, nearest filter, rough 1, emission on at zero energy like the primitives), included in `base_materials()` so the flash passes reach it. P1-skin can then draw a fixture before P1-toon lands, and the parry and contact flashes work on it from the start.
- **Alternative not taken.** Return null (the "other factories null" line for `ToonMaterials.art`), leaving P1-skin's meshes default white and its flash tests nothing to reach. `ToonMaterials.art()` itself is still the null stub.

## C6. What stayed in the rig
- **Decision.** `HumanoidRig` keeps `_flash_overlay`, `_flash_on`, `flash_at()`, `follow_flash()` and a thin `_show_flash_overlay(on)`; `RigPaint.show_flash_overlay(on, overlay)` does the material loop. `test_hit_flash` reads `rig._flash_overlay` (null before the first flash) and `rig._materials`, so both stay on the rig; `_materials` is `paint.materials`, the same dictionary.
- **The warm-up statics** (`_flash_warmed`, `_flash_warm_box`) moved to `RigPaint` with `warm_up()`. The first contact flash's "drop the warm-up box" is now `RigPaint.end_warm_up()` (static). No test touched either.
- **`_FLASH_SHADER` is preloaded twice** (the rig for `flash_at()`, `RigPaint.FLASH_SHADER` for the warm-up). P1-toon reworks the flash and will fold them.
- **Alternative not taken.** Move all flash state into RigPaint: it would make `test_hit_flash`'s private reads fail and enlarge the rig diff.

## C7. `joints.json` carries more than the plan's list
- **Decision.** Besides bones, parents, rest globals, soles, the fist box and the hurtboxes, the table holds the 14 rig points, the FP-hidden bone and part names, and every placeholder part for the enemy and the player sets (name, bone, shape, size, offset, rotation, paint, FP-hidden). P1-tools' mannequin and P1-chain's checks need the part sizes and the FP split, and one file stays the single source.
- **Format.** One line per bone/point/sole/part so diffs read; numbers rounded to a micrometre (so float32 noise never shows); the drift test compares parsed JSON within 2 micrometres rather than byte for byte, so another platform's float printing cannot fail it.
- **Run as `-s`, not a scene.** `dump_joints.gd` extends `SceneTree` and runs with `godot --headless -s tools/pipeline/dump_joints.gd --quit-after 5`. The brief warned that `-s` scripts cannot see autoloads; `PlaceholderBody` and `CombatTypes` use none, so it works, and GUT calls the same static `table()` and `to_json()`.
- **Alternative not taken.** A GUT helper that writes the file: it would need a test run to regenerate the table.

## C8. The test move is exactly `tests/test_vfx.gd` 688-835
- **Decision.** Six tests and two helpers (`test_rig_damage_look_changes_materials_only` through `_red_share`) moved verbatim to `tests/test_damage_look.gd`: test_vfx.gd 53 -> 47 tests, test_damage_look.gd 6, same total. `test_damage_look_levels_at_66_and_33_percent` (679-686, no material access) and the two director-driven look tests (838+) stay in test_vfx.gd, as the brief's line range says.
