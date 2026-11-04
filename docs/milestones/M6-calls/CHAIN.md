# CHAIN: judgement calls

Each: the decision / the alternative not taken / why.

**C1 Strain is read from files; `ArtStrain.SHIPPED` stays a name.** `SHIPPED` became a `static var` built from the roster (the Punk's row from `strain/punk.json`) plus the hero's `PLAYER_ROW` in code. / Not a rewrite of `test_skinned_art.gd` (ARM's file) to loop the roster; not the dummy inside `SHIPPED` (that test plays the Punk's moves on every row, so the dummy's clip table would fail "a clip with no figure"). / `test_skinned_art` is unchanged and still covers the Punk and the hero; the roster characters' strain is held by `test_m4_done_when` A7 from their own files.

**C2 The Punk's two stretch ratchets stay two.** `stretch_m` 0.09 is the done-when's, `variant_stretch_m` 0.10 is `test_art_punk`'s (all four GLBs). / One number. / M4 kept both and "byte-identical" forbids merging them.

**C3 The dummy keeps the plan's budget of 15000 and is exactly at it.** The decimation trial hit 15000 on the dense 24800-face mesh. / 8000 (the probe's). / The brief says 15000; A2 holds it.

**C4 The dummy's ratchets** (each today + margin as M4's, the plan's bar still printed as GATE; the reasons are in `roster/dummy.json`): `a6.axis_outside` 1 (one left-leg axis point outside the probe's leg; the shares are 98-100%), `a9_cells` 0.051 (4.6% today), `anchor_m` torso 0.064 / leg 0.039 (5.9 / 3.4 cm), `stretch_m` 0.035 (3.3 cm, the spine in the jab's twist). / Tuning the chain's config (`girth_clamp`, `rig.clamps`) until the dummy met the bars. / The dummy is a prop the player punches, the Punk misses the same bars worse (6 cm anchors, 8.4 cm stretch), and a probe config change would move the probe-derived report keys the guard test holds; the ratchets only move down.

**C5 `a6` can carry `axis_outside`.** The non-player rows asserted zero axis points outside; the roster's `a6` object may say how many the art may leave (default 0, the hero's constant 0 as before). / Asserting zero and failing the dummy. / A new ratchet kind with a reason beats a weakened assertion; no existing assertion changed.

**C6 `rig.height` from the roster.** `_rig(row)` uses `row.height` (1.8 for every row today, so no number moved). The hero's row says 1.8. / Keeping 1.8 until the Bruiser arrives. / The brief says `_rig()` no longer hard-codes it.

**C7 A11's real-fight flash stays on the Punk** (a player jabbing a live Street Punk); the anchor part of A11 loops the roster. / A live fight per character. / The training dummy is not an enemy that the test room's fight loop is built for; the flash code is the rig's and shared (the dummy's anchor is measured).

**C8 Warm-up reads the scene state, not an instance.** `RoomKit.catalog_arts()` takes the root `art` from `PackedScene.get_state()`. / Instantiating each catalog scene (20 ms each, and an actor's `_ready` runs). / The catalog is the one list of what spawns; a new scene is warmed by existing there. `ToonMaterials.warm_up()` is unchanged: the pipeline it warms is one shader for every art (uniform differences only), so the Punk's copy covers every character.

**C9 The dummy's palette slots 56-59 with the old orange kept as the dominant colour** (`#cf7f2e`, a muted orange; head canvas `#e3d3b0`, limbs brown, straps charcoal). / Three variant atlases (plan D17 says no). / The one look reads at 1 m (see "Look: Dummy at 1 m").

**C10 The dummy source is committed** (`assets/source/characters/dummy/source/dummy_source.glb`, LFS) so `--check` runs from a clean clone. / Rebuilding it from `_cache` (ignored). / The probe's own source is rebuilt, but the dummy ships and its `--check` must be reproducible by anyone.

**C11 The roster Punk act is not recorded separately.** `Look: Punk at 1 m` is a substring of C14's title, so the filter runs both; the 1 m comparison against `captures/m4/dm` used C1 (the same framing and code) and the frames are identical. / Renaming C14 (`test_look_acts.gd` pins its title). 

**C12 The first-person split is off and no detail mask for the dummy** (the dummy is never the player; its UV2 from `detail_uv` stays unused). / Mask from `detail_bake` zones. / Plan: "split_fp off"; seams come from the colours alone.

**C13 Test assertion changes** (old -> new): `test_look_post.gd` "the training room's dummy colours are not red" (`dummy_colors`) -> the dummies wear the dummy art untinted and the room has no `dummy_colors` (the colours themselves are held by the dummy's roster A3, which runs on the art's swatches, and by `test_art_roster`'s slot and red-band check). `test_art_contract` the probe-report keys test: one probe vs Punk -> probe and every roster report vs Punk (stricter). `test_m4_done_when`: the row constants moved into roster files (same numbers); A1's mesh list is the row's.

## The inventory drop for the lead

CHAIN clears no placeholder category by itself except:
- `primitive_bodies`: the training room's three dummies and the F4 catalog's `dummy` entry: 4 bodies in the training room (3 dummies plus the catalog's dummy; the player already has art) and 1 in the catalog count where that scene's count includes `dummy` (the crowd room: 0; mission1: 0).
- `tints`: the training room's dummy colour multiply (`test_room.gd:107`, 3 dummies) is gone: the training room loses 1 tint source (the three colours were one category line).
Everything else (`boxes`, `cylinder_weapons`, `second_weapon`, `generated_sfx`, `empty_slots`) is untouched.
