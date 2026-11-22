# Recipe: give an enemy the trailer look (M7 roll-out, r0)

The trailer look is a second art for each character, worn only under `look_profile` 1: the same mesh and rig with a fresh UV2, a flat-colour **paint map**, an **ink map** (lines, damage class, hull weight), and optionally a **mark map** (where bruises and blood sit). Everything is built from one data folder by one command. **No shared code is edited**: not `tools/pipeline/*`, not the shader, not `ToonMaterials`, not the tests. The Punk is the worked example (`assets/source/trailer_art/punk/`); the contract is `docs/ARCHITECTURE.md`, "The painted material (M7)". Target: `docs/milestones/M7-comic-3d.md` ("The figure recipe").

Python is `~/.venvs/beat-em-up-video/bin/python`; Blender runs headless, one process at a time, never the Blender MCP. Check `pgrep -f write-movie` before recording; the machine has 8 GB.

## The one command

```
tools/pipeline/make_trailer_art.sh <name>
```

`<name>` is the folder name (`thug`, `bruiser`, `kicker`, `boss` for Ox). In order it: bakes the surface in a new UV2 layout in Blender (`trailer_asset.py`), warps your drawn sheets onto it (`trailer_sheets.py align`, only if `sheets.json` exists), paints `paint.png`, `ink.png`, the mark map and the variant recolours (`trailer_paint.py bake`), writes the `.import` files (lossless, mipmaps, no alpha bleed), writes `game/actors/art/<name>_trailer_art.tres` and adds `metadata/trailer` to `<name>_art.tres` once (`trailer_wire.py`), and runs `godot --headless --import --quit`. About 65 s. `ART_SKIP_BLENDER=1` repaints the last bake in about 5 s (use it while tuning `paint.json`); `ART_WORK=<dir>` moves the scratch directory (default `assets/source/_cache/trailer_art`, git-ignored); `ART_NO_IMPORT=1` skips the final import. Run `godot --headless --import --quit` once in a new worktree first.

The Punk goes through exactly this path: with its pre-r0 `paint.json` the command reproduces `punk_trailer.glb`, `punk_paint.png`, `punk_ink.png` and `punk_veteran_paint.png` byte for byte (checked by `git diff`), and with the r0 `paint.json` it adds the mark map.

## 1. The data folder

```
assets/source/characters/<name>/work/<name>.blend      exists already (the game's mesh, UV1 palette, rest rig)
assets/source/trailer_art/<name>/
    paint.json         required: regions, rules, shadows, ink, hull, folds, marks, normals (below)
    sheets.json        optional: the drawn face / body / hand sheets and their landmarks
    gemini/            optional: jobs.json, the reference images and the Gemini outputs (jpg), kept in the repo
    features.svg       optional: hand-drawn extra lines in the sheets' millimetre grid (the Punk's cap seams, vest zip)
    features_uv.svg    generated (the drawing as it sits in the layout); commit it
```

Outputs, by the command: `assets/export/characters/<name>/trailer/<name>_trailer.glb`, `<name>_paint.png`, `<name>_ink.png`, `<name>_marks.png` (when paint.json has "marks"), `<name>_<variant>_paint.png` per `variants`, each with its `.import`; and `game/actors/art/<name>_trailer_art.tres`.

How the game picks them: `<name>_art.tres` carries `metadata/trailer`, `CharacterArt.variant(&"trailer")` returns the trailer art under look_profile 1 and the M6 art under 0, `ToonMaterials.is_painted()` is true because the trailer art carries `metadata/paint_tex` and `metadata/ink_tex`, and `ToonMaterials.art_for()` builds the painted material from them (and from `metadata/marks_tex` when present). `HumanoidRig` swaps live on the profile flip. Nothing else names a character.

## 2. Find the palette cells and the bones

The mesh's own material labels are the 64 cells of the palette atlas (UV1). Look at them and at the bones before writing rules:

```
PY=~/.venvs/beat-em-up-video/bin/python
W=assets/source/_cache/trailer_art/<name>        # after one run of the command (or ART_SKIP_BLENDER off)
$PY -I tools/pipeline/trailer_paint.py cells <name> $W /tmp/cells_front.png front   # each cell in its atlas colour, lit
$PY -I tools/pipeline/trailer_paint.py cells <name> $W /tmp/cells_back.png back
$PY -I tools/pipeline/trailer_paint.py regions <name> $W /tmp/regions.png front     # your regions' base colours
```

The bones are the shared 23-bone rig (`Head`, `Neck`, `Chest`, `LeftUpperArm`, `LeftHand`, `LeftUpperLeg`, ...), the same for every character.

## 3. paint.json

Copy `punk/paint.json` and change the data. The keys:

| Key | Meaning |
| --- | --- |
| `seed` | every random choice is seeded; the same file gives the same maps |
| `layout` | `weights`: texel density per bone (the head 2.4, hands 1.4, the rest 1.0), `margin_px`, `planar_front`: `{bones: ["Head"], min_ny: 0.45}` gives the head's front one planar island so a drawn face has no seam |
| `regions` | `{name: {base: [r,g,b], shade: [r,g,b], class: 255 clothes / 230 clothes without blood / 204 skin / 128 none, shadow: 0..1 gate for the procedural shadow shapes}}` |
| `rules` | in order, each sets the region of the texels matching ALL its keys: `cells`, `bones`, `box` ([x, y, z] spans in metres, rest pose, `null` for any), `nx`/`ny`/`nz` normal spans; a later rule overrides an earlier one |
| `shadows` | `hint` (light per body part: the procedural shadow shapes, off for a region with `shadow: 0`), and `designed` (below) |
| `ink` | `border_px`, `border_strength` (the seam between two regions is a line), `merge_for_borders` (`{"jaw": "skin"}`: no line between these two), `clear_regions`, `crease_*` |
| `hull` | the ink map's A, the hull's line weight: `base`, `variation`, `taper_ends` (bones whose tail the line thins toward) |
| `folds` | `{bones, region, count, angle_deg, length_mm, width_mm, strength}`: a few bold tapering crease strokes on a limb or torso |
| `sheets` | the drawn-sheet groups (section 5) |
| `marks` | the placed bruise and blood shapes (section 6) |
| `normals` | `[{bones, rings, strength}]` blur the shading normals of those bones so the shader's one terminator is a clean edge (section 7) |
| `variants` | `{name: {regions: {region: {base, shade}}}}` recolours the same maps (the veteran) |
| `features_skip` | name prefixes of `features.svg` strokes to leave out |

### Colours: flat local fills

The paint map is **flat local colour**: one `base` per region, one darker `shade` for the designed shadow shapes, no gradient, no grain, no painted highlight. Keep `grain` 0 and `shadows.hint` few. Do not paint a bluish patch to look like shade: the shader supplies the one shade edge (a quantised light term against the key, two tones, the shade tinted toward the area's hue), so a region's `shade` is only for shapes you design on purpose. Choose `base` as the colour you want to read in mid light; the shader shows `look_paint_lit_level` of it. Skin is **one warm tone** (the Punk: `[206,152,118]`, shade `[150,100,84]`); a face needs a skin region of class 204.

### Designed shadows

`shadows.designed: [{ "region": ["skin","jaw"], "shape": {...} | rule keys, "amount": 1.0 }]` puts a shadow shape on purpose, whatever the region's own gate says. Two ellipsoids are the Punk's whole face shading: the brim's shadow across the eyes and the chin's under the jaw:

```
{"region": ["skin","jaw"], "shape": {"at_mm": [0, 12],  "r_mm": [106, 66], "depth_mm": 70, "soft": 0.1, "wobble": 0.06, "wobble_mm": 30}},
{"region": ["skin","jaw"], "shape": {"at_mm": [0, 188], "r_mm": [80, 42],  "depth_mm": 90, "soft": 0.1}}
```

A **shape** is an ellipsoid on the surface, in the millimetre grid of the sheets (`sheets.json` "origin"; x to the viewer's right, y DOWN, the grid `trailer_paint.py sheet` draws): `at_mm` its centre (it sits on the front-most surface of `bones`, default Head, at that point), `r_mm` the two radii in the view's plane, `depth_mm` the third (along the view), `angle_deg` a turn in the plane, `soft` the edge ramp (0.5 is the edge, the shader cuts it crisp), `wobble` (a share of the size) and `wobble_mm` (noise cell) so it is not a perfect ellipse. Or in the rest pose: `{"c": [x, y, z], "r": [rx, ry, rz]}` in metres. Measure the grid with:

```
PX_PER_MM=4 PAINT_PNG=assets/export/characters/<name>/trailer/<name>_paint.png \
  $PY -I tools/pipeline/trailer_paint.py sheet <name> $W /tmp/grid.png front <origin_r_m> <origin_u_m> <half_w_mm> <half_h_mm> 4
```

## 4. The stage fixture and the look test

Record the character with the generic stage (no per-character fixture):

```
godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 400 res://tests/fixtures/m7/trailer_stage.tscn -- \
    --art=res://game/actors/art/<name>_art.tres --head=<head height in m>
```

It shows an 8-step turnaround of the whole body (stills at frame 10k+5), then the face front and three-quarter at clean, bruised and bloodied (frames 80 to 139), then the torso close (frame 140). It prints a `STAGE <shot> frame <n>` line per shot. Cut stills with `ffmpeg -i out.avi -vf "select=eq(n\,86)" -frames:v 1 -fps_mode passthrough still.png`. `--head=` is the head's height (the Punk 1.66, Ox about 1.9; look at the first turn still and adjust). `--profile=m6` shows the same stage under m6, the A/B. Then judge it in the street too: `res://tests/bot/level_bot.tscn -- --level=res://game/level/mission1/mission1.tscn --to=0 "--act=Run: held back" --clean --tune=look_profile=1 --tune=cutins_enabled=0`.

**The test to copy is none: it is discovered.** `tests/test_trailer_art.gd` runs over every folder with a `paint.json` and a `<name>_art.tres`: the variant is present and painted, the art contract holds, the maps are 2048 and the data maps import lossless, the ink map holds only the class bytes, the mesh is the current mesh with a UV2 inside the map, the paint is flat fills, and, with a mark map, its shapes sit on skin only and the level reaches the shader. A new character adds its checks the moment its folder exists. Put character-specific pins (a variant's recolour, the sheets' sources, a face's design) in a `tests/test_trailer_<name>.gd` copied from `tests/test_trailer_punk.gd`, changing the constants at its top.

## 5. The face drawing (Gemini) and its projection

Only if the character has a face worth drawing (the Punk, the Thug, the Kicker, the Bruiser). Without sheets the face is the paint plus procedural ink; Ox's bold face can come from `features.svg`.

1. Add `sheets.json` (copy the Punk's): `origin` of the millimetre grid, `landmarks_mm` (eyes, nose, mouth, chin, brim: measure them on the grid image), and the sheets `front`, `q45`, `qm45` (the q45 file is used mirrored for the other side) with their `window`, `ppm` and `yaw`.
2. Render the grey mesh views the drawings are made over: `$PY -I tools/pipeline/trailer_sheets.py render <name> $W assets/source/trailer_art/<name>/sheets.json assets/source/trailer_art/<name>/gemini`. This writes `in_*.png`.
3. Write `gemini/jobs.json` from the Punk's: a style reference (`ref_punk.png`, `ref_face.png`: crops of a trailer frame with the drawn look), the render as the last ref, and a prompt describing THIS man in the style (heavy flat brows, the brim's shadow as one flat shape, a nose side line, a set mouth, a jaw shadow, flat fills, thick near-black ink, plain background, no text). Then `python3 -I tools/gemini_image.py assets/source/trailer_art/<name>/gemini/jobs.json face_front face_q45`. **About $0.134 an image; one take each; stop if a call fails for lack of credit; add a row to `ASSETS.md` for every image.** Copy the outputs to `*.jpg` (kept in the repo, downscaled).
4. Put each sheet's landmark positions (0..1 in the drawing) into `sheets.json` `points`; run the command with `ART_SKIP_BLENDER=1` and look at `$W/sheets/sheet_*.png` (`trailer_sheets.py align ... --debug` marks the landmarks).
5. Add a `paint.json` `sheets.groups.face` like the Punk's: `views`, `bones`, `ink_regions: ["skin"]`, `z_range`, and **`"tones": {}`**: the face takes its lines from the drawing and its tones from the region colours and your designed shadows (the drawing's own tones gave the grey face and the hard band across the mouth). Add **`ink_allow`**: a list of shapes (section 3) inside which the drawing's lines survive: a brows-and-eyes ellipse, a nose strip, a mouth strip. The cheek creases and ear lines the drawing carries are then gone. The Punk's:

```
"ink_allow": [{"at_mm": [0, 45],  "r_mm": [90, 38], "depth_mm": 70, "soft": 0.1},
              {"at_mm": [0, 85],  "r_mm": [36, 34], "depth_mm": 60, "soft": 0.1},
              {"at_mm": [0, 127], "r_mm": [62, 17], "depth_mm": 60, "soft": 0.1}]
```

6. Add `body` and `hands` groups if the body gets drawn lines (copy the Punk's; `"tones": {}`).

## 6. Bruises and blood: placed shapes (the mark map)

M6's marks are tiles scattered by position; under the trailer look a face should carry **two or three larger placed shapes**. Add to `paint.json`:

```
"marks": [
 {"channel": "R", "shape": {"at_mm": [-62, 94], "r_mm": [24, 15], "angle_deg": -30, "depth_mm": 45, "soft": 0.12, "wobble": 0.22, "wobble_mm": 16}},   // cheekbone: from the bruised look up
 {"channel": "G", "shape": {"at_mm": [46, 77],  "r_mm": [23, 9],  "angle_deg": 8,   "depth_mm": 45, "soft": 0.12, "wobble": 0.2,  "wobble_mm": 14, "seed": 5}},  // under one eye: from the bloodied look
 {"channel": "B", "shape": {"at_mm": [-12, 135], "r_mm": [14, 6],  "angle_deg": 4,   "depth_mm": 45, "soft": 0.12, "wobble": 0.18, "wobble_mm": 10, "seed": 7}}]  // the lip: blood, bloodied look
```

R is a bruise shown from the BRUISED look up, G a bruise shown from the BLOODIED look, B a flat blood shape shown from the BLOODIED look. Shapes live on skin only (class 204). The command writes `<name>_marks.png` (1024, RGBA) and `trailer_wire.py` adds `metadata/marks_tex`; the shader (`toon_painted.gdshader`, `marks_on`, `damage_level`) draws them under the ink in the existing bruise colour (`look_paint_bruise_*`) and blood colour (`look_paint_blood_color`). Never at full health. Clothes keep M6's blood spots. A character with no `marks` key keeps the tile scatter, so nothing about a character without the map changes.

## 7. Clean shade on a big form

The shader's terminator follows the mesh's shading normals, so a crumpled trouser leg or a puffy vest gets blue patches along every crease. `paint.json` `"normals": [{"bones": [...], "rings": 10, "strength": 1.0}]` blurs those bones' normals over rings of the edge graph in the Blender step (stored as custom normals in the GLB), so the one shade edge runs across the form. The Punk: both legs, rings 10, strength 1; the vest, rings 8, strength 0.85. The rim is capped on large dark forms by `look_paint_rim_dark_px` (1.2 px where the paint is darker than `look_paint_rim_dark_luma`), so a vest or a black top shows a rim line and not a band; tune those two values, never the shader.

## 8. Ox, and any character that KEEPS its M6 colours: no repaint

Ox keeps his palette. He still gets the trailer's shade, line, rim, bold face and bruise rules, over his existing albedo. Use the atlas's own swatches as the flat fills with one key and no regions:

```
{
 "seed": 5,
 "layout": {"default_weight": 1.0, "margin_px": 12},
 "regions_from_atlas": {"shade": 0.68, "tint": [50, 50, 110]},
 "regions": {},
 "rules": [],
 "shadows": {"hint": []},
 "ink": {"border_px": 3, "border_strength": 0.95, "crease_strength": 0.0},
 "hull": {"base": 0.62, "variation": 0.3},
 "folds": [],
 "grain": 0.0
}
```

`regions_from_atlas` makes one region per palette cell the mesh uses: its `base` is the swatch of `assets/export/palette/palette_atlas.png` (so the paint map IS his M6 albedo as flat fills), its `shade` the swatch darkened by `shade` and pulled 15 % toward `tint`, its damage class the atlas alpha. The result is the same two-tone cel with the seam lines between cells (the inked shapes of his hood, belt, gloves), the hull, the key-side rim and the area's shade. Your own `regions` and `rules` still override a cell: add a `"face"` region and a `box` rule to give the face a bold skin tone, a `shape` ellipsoid under `shadows.designed` for the hood's shadow across the eyes, `marks` for his bruises, a few `folds` on the coat, `normals` for the big forms. The first run with only the lines above built an Ox that reads as the M6 palette with the trailer's line, shade and rim (record it with `--art=res://game/actors/art/boss_art.tres --head=1.9`); his face and the bruises are the data you add. Colours that must not move: leave `regions` empty of any colour of the palette. `tests/test_trailer_art.gd` covers him like any other.

## Pitfalls

- **Never write in `.worktrees/video` or `.worktrees/mv-*`; never commit `captures/`; never print `.env`.** Gemini cost goes in `ASSETS.md`.
- Edit values in `paint.json`, never in the PNGs or the `.tres`; both are generated and committed.
- The face's `box` and `ellipsoid` coordinates are the rest pose (A-pose): +Y is the front, +Z up, the viewer's right is -X.
- If a region's `rules` match nothing the texels are `-1` and read as a mid grey: check the `regions` preview (section 2) for grey.
- A stippled band in a `trailer_paint.py` preview is the preview's splat showing the surface behind through a gap; look in the game, or at the UV2 crop, before chasing it.
- The test fails with "has metadata/trailer" when `make_trailer_art.sh` has not been run for a folder that exists.
