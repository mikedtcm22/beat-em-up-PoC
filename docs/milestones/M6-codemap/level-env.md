# M6 codemap: level geometry and environment art (level-env)

Read-only survey on branch `m6/full-art-audio`, 2026-11-04. Paths are from the repo root. Scene lines come from a script over the three `.tscn` files (the census), not from reading them whole. Nothing was run (no Godot, no Blender).

## 0. The facts to hold

1. Art can hang on the existing geometry with the colliders and navmesh untouched. The bake parses static colliders only (`game/level/nav_baker.gd:45`, mask layers 1 and 9 at `:46`), so a `MeshInstance3D` is never read by it. Colliders are made in two places, `LevelBlock._make_body` (`game/level/kit/level_block.gd:86-98`) and `Barrier._build` (`game/level/kit/barrier.gd:144-154`). Art must add no `StaticBody3D`.
2. The environment shader supports a palette atlas only. `albedo_tex` is `filter_nearest, repeat_disable` on UV0 (`game/fx/toon.gdshader:22`), and `detail_tex` is a UV2 ink mask with `repeat_disable` (`:26`). A tiling, filtered trim sheet needs a new sampler or a new shader, and the atlas cannot hold it (section 8).
3. `LevelBlock` is the only graybox draw path of the three sections. `LevelStairs` makes `LevelBlock` steps at runtime (`level_stairs.gd:70-89`). `Barrier` draws its own boxes (`barrier.gd:169-222`). The crowd room and the training room do **not** use `LevelBlock`: they call `RoomKit.add_box` directly (`crowd_room.gd:212`, `test_room.gd:126-131`), so D9 needs a second hook.
4. Several M4/M5 tests read environment colours or mesh types and will go silently vacuous or fail (section 5).
5. There is **no windowed frame-time baseline for the level**. The perf acts run in the crowd room (`tests/bot/acts/crowd_acts.gd:86`, `look_acts.gd:214`). `tools/perf_compare.sh` only runs `perf_bot.tscn` (`:118,136`), which extends the crowd bot.

## 1. Census of the level geometry

Counted from `game/level/mission1/{street,roofs,boss_roof}.tscn`. Every graybox node is a `LevelBlock` (`level_block.gd`), an `EdgeGuard` or a `LevelStairs`. The proposal says 244 boxes (`docs/milestones/M6-proposal.md`, section 1). The census finds **296 `LevelBlock` nodes plus 7 `EdgeGuard` nodes**, and 68 more step blocks built at runtime. (244 = 296 - 52, the roofs' identical rail posts; I do not know how the 244 was counted.)

| Section | blocks | wall | floor | accent | dark | prop | fence | solid / drawn-only | EdgeGuards | Stairs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| street | 94 | 25 | 10 | 11 | 26 | 14 | 8 | 72 / 22 | 3 | 1 flight |
| roofs | 151 | 27 | 14 | 17 | 12 | 3 | 78 | 61 / 90 | 3 | 3 flights |
| boss roof | 51 | 8 | 2 | 25 | 6 | 6 | 4 | 9 / 42 | 1 | none |
| total | 296 | 60 | 26 | 53 | 44 | 23 | 90 | 142 / 154 | 7 | 4 |

Solid means a world-layer collider plus mesh; drawn-only is `solid = false`. The runtime step count is `ceil(rise / 0.18)` (`level_stairs.gd:55`). The street's flight has 25 steps (`street.tscn:532`, rise 4.5). The roofs' flights have 6, 20 and 17 (`roofs.tscn:427,434,668`, rises 1, 3.5, 3). Each step is a box from the floor up (`level_stairs.gd:80-88`), so the flights are 68 stacked boxes plus 4 hidden glide ramps on layer 9 (`:94-110`).

**Kinds, per section** (line numbers are `.tscn` lines).

- **Street, 56 m long**, footprint x -6..6, z +3.5..-52.5.
  - Floor: `Floor` 12x1x56 (`street.tscn:38`).
  - Walls: 6 right and 5 left slabs, 12 m tall, 2 m thick, 1 to 17.5 m long (`:55-109`), plus the start and end walls (`:44,49`). Openings break them up, so the lengths vary.
  - Door recesses: each is `DoorFloor` (floor look), `DoorBack` and two `DoorJambs` (dark), `DoorLintel` (accent). The 3 right-side doors (`:110-199`) are identical (jambs 3x4.4x0.2, lintel 3x7.6x2.9). The warehouse shutter recess (`:200-229`) is the same set, 6.4 m wide. Each set is 5 blocks.
  - Shutter ribs: 11 blocks of 0.2x0.08x6 (`:230-295`), drawn-only, exact repeats.
  - Alleys (2) and lots (2): 5 blocks each (`:296-415`).
  - Props (`:416-531`): 4 barricades (3x1.5-2.3x1.8), 9 crate blocks, `Van` 2.4x2.05x5 plus `VanWheels`.
  - Fences: `FenceAcross` and `SideFence` (`:440-451`).
  - Beyond the left wall: `BeyondFloor` and `BeyondWall`, drawn-only (`:452-465`).
  - Landing: solid, 6x4.5x4.5 (`:539`). Rails and posts are drawn-only `fence` blocks (1 stair rail, 2 landing rails, 3 posts of 0.12x1x0.12). The 3 EdgeGuards are `:587-601`.
  - Skyline: `SkylineL` 20x25x54, `SkylineR` 17x21x54, `SkylineFar` 24x14x1, all drawn-only (`:602-620`).
- **Roofs**, local x -8..26, z 0..-30.
  - Terrace: 2 mass blocks and 2 floor slabs (10x0.5x14, stepping up 1 m).
  - 10 doors, each `*Floor/*Back/*Lintel` plus flanking walls. Door sizes differ, so they are not exact repeats.
  - 2 curbs (0.3x0.25x14, accent).
  - Rails: 25 bars of 0.1x0.1x1.8, 52 posts of 0.12x1x0.12 (`fence`, drawn-only), a few shorter bars.
  - Catwalk deck 10x0.5x20 and top-roof deck 14x0.5x24. The solid masses under them (`Mass`, 8x9x20 and 12x12x24) are blocks too.
  - Penthouse: `PenthouseBody` 4x4.5x3.6 plus a shutter recess.
  - `StackA` and `StackB` (2.8x2.4x3.3) are prop blocks; `CrateLoose` is 1.6 cubed. `ParapetWest` is 0.6x1.4x18.35 (`roofs.tscn:738`).
  - Skyline: 2 ground planes (74.7x0.5x75 and 51x0.5x75 at y -5.55) and 6 blocks, 8.8 to 24.8 m tall (`:1033-1080`).
  - 3 EdgeGuards (`:422,663,990`).
- **Boss roof**, 20 x 20 m deck, open edge on +X.
  - Deck 20x1x20 floor (`boss_roof.tscn:28`), `Building` 20x11x20 under it, `SideWall`, `BackBulkhead`.
  - Doors are drawn-only (`GateDoor`, `ServiceDoor`, `RoofDoor`, 0.3 thick, `:46-92`). Solid back and entry fences, `fence` look, 0.6 thick (`:94-123`).
  - Rails: `RailA` 0.15x1x8 and `RailB` 0.15x1x7, then `RailEndNear` and `RailEndFar` posts (`:124-150`).
  - The open edge: a 5 m gap between z -8 and -13 at x 9.85. EdgeGuard 0.3x4x20 at x 10.15 (`:152`); HazardVolume at (30,-4,-10), 40x14x60 (`:158-160`).
  - Lip stripes: 5 of 0.6x0.06x1, dark and accent alternating (`:351-385`).
  - Drawn-only far world: `Ground` 200x1x200 at y -12.5 (`:162-168`), 4 skyline towers (12 to 30 m), 3 low blocks, 2 sidewalks 4x0.3x90, 11 lane dashes (0.25x0.04x2.5) and 6 parked cars (1.9x1.4x4.4).

**Repeated sizes (module candidates).**
- Street: 6x (3, 4.4, 0.2) jambs; 4x (3.4, 9, 0.4) and 4x (5.4, 7, 0.4) alley and lot sides; 3x (0.5, 5, 2.9); 3x (3, 7.6, 2.9) lintels; 11 shutter ribs.
- Roofs: 52 posts; 25 rail bars; the 3-wide door sets.
- Boss roof: 6 cars; 11 lane dashes; 5 lip stripes.
- Wall lengths and heights are otherwise free, so wall art must follow the block's size (section 2).

**Colliders versus drawn faces.** Walls are 2 m thick and 12 m tall (the street) while only the inner face shows. Several solids are buried (`Building`, the roofs' `Mass` blocks). A module may therefore draw only the visible faces; only the collider box must keep its size.

## 2. Where art can attach

**The rebuild path.** `LevelBlock._rebuild()` (`level_block.gd:56-73`) frees `body` and `_visual`, then:
- solid: `_make_body(material)` adds a `StaticBody3D` with a `CollisionShape3D` and, if `_drawn()`, a `RoomKit.box_mesh` child (`:86-98`);
- not solid: `_visual = RoomKit.box_mesh(...)` (`:72`).

`_drawn()` (`:82`) is already a virtual that `EdgeGuard` overrides to false (`edge_guard.gd:36`); the collider is unaffected. So the minimum change is new exports on `LevelBlock` (an art scene or module id, plus a `draw_box` switch), and in both draw sites (`:72` and `:97`) build the module instead of `RoomKit.box_mesh`. The module is a child of `body` (solid) or of the block (drawn-only), so it moves with the block.

More facts about the path:
- `size`, `look` and `solid` setters call `_rebuild()` (`:28-40`), and `_ready()` builds once (`:47-49`). `_rebuild` returns when the node is not in the tree (`:57`). The class is `@tool` and uses a plain `StandardMaterial3D` in the editor (`:102-105`).
- `LevelBlock.COLORS` is read by a test (`tests/test_level_kit.gd:658`), so keep it.
- `RoomKit.add_box(parent, pos, size, material, overlay)` (`room_kit.gd:103-117`) takes a `Material`, not a mesh, and `box_mesh` (`:129-136`) is a `BoxMesh` with `material` set. A module path needs a new `RoomKit` helper that adds the same collider and a given mesh or scene.
- Collider-only blocks (hidden art) already exist: `EdgeGuard`, and the crowd room's invisible curb barrier (`add_box` with a `null` material, in `_build_south`).

**Can a block hide its box and instance a module to its size?** Yes. Three ways, a lead decision:
1. **Procedural mesh from `size`:** a builder writes an `ArrayMesh` whose UVs are in metres along each face (one strip per face kind). It always fits exactly and removes the repeated-size problem (street walls run 1 to 17.5 m).
2. **Tile a Blender module by count:** `n = round(length / module_width)`, with the remainder as stretch. This suits the exact repeats (jambs, shutter ribs, rail posts, lane dashes, parked cars). It needs a fixed-width module and a remainder rule.
3. **Scale one mesh to size:** non-uniform scale smears bevels and window proportions. Fine for flat slabs (floors, decks), poor for facades.

**Multi-block art.** A doorway is 5 blocks, which no single block can draw as one frame. The kit needs a section-level non-solid dressing node (a sibling of `Geometry`, which `LevelSection` does not read) holding module instances placed over blocks whose boxes are hidden. The solid-block tests skip non-solid blocks (`tests/test_m5_street.gd:166-169`, `test_m5_roofs.gd:367-371`, `test_m5_done_when.gd:385-387`), so non-solid `LevelBlock`s are safe; any other node type is invisible to them.

**Stairs.** `LevelStairs._rebuild()` (`level_stairs.gd:70-89`) makes one `LevelBlock` per step with `look`. Per-step modules would be 68 draws; use one flight mesh and keep the step boxes collider-only. The glide ramp (`:94`) and `footprint()` (`:65`, read by the bake, `level_root.gd:241-270`) stay.

**Trim-sheet tiling rules** (SPEC 12: module 5k triangles, 2k trim sheet, `docs/SPEC.md:326`).
- The shader needs `filter_linear_mipmap` and `repeat_enable`. Tiling along a trim strip means U runs past 1 while V stays inside the strip's row, so pad each strip (16 to 32 px at 2k) so mip levels do not bleed, and set an anisotropy level.
- One surface and one shared material per module (section 7).
- Import with mipmaps. Uncompressed RGBA8 with mips is about 22 MB of VRAM. The atlas import is the opposite (`assets/export/palette/palette_atlas.png.import:18,26`: `compress/mode=0`, `mipmaps/generate=false`).
- Ink lines painted in the sheet blur under mips. `toon.gdshader:99-103` already solves this for characters: cut the ink mask at `detail_cut` with a one-pixel edge from `fwidth`. Reuse it (for example the mask in the sheet's alpha), and check it against the edge pass (section 4) so the two lines do not double.

## 3. Barriers

`Barrier` (`barrier.gd`) is built at runtime and is not `@tool`. It is a `Node3D` in group `barrier` (`:23`) with these children:
- `Collider` (`StaticBody3D`, a `BoxShape3D` of `width_m x height_m x thickness_m` centred at y `height_m/2`, `:145-154`). Its layer is world when closed and 0 when open (`:120-124`); it changes at once on `close()` and `open()`, before the panel arrives.
- `Panel` (`Node3D`, `:155-157`). Closed it sits at local zero; open it sits at `_open_offset()` (`:137-141`), eased by `_place_panel()` (`:127-133`): the shutter ease-out, the gate and car smoothstep.
  - SHUTTER: panel goes up by `height_m`.
  - GATE and CAR: panel goes sideways by `open_side * (width_m + 0.2)`.
- A static housing outside the panel (shutter only, a box 0.5 m above the opening, `:177`).

**Frame:** the opening spans local X (centred) and rises `height_m` from y 0; local -Z is the walk (`:9-12`). A barrier in a wall running the other way is rotated 180 degrees (street) or -90 (roofs `GateStair2`, `ShutterStair3`).

**What a modelled version must expose:**
- A node named `Panel` whose `position` is the animated offset. `tests/test_level_kit.gd:210` asserts `Panel.position.y > 3` for an open shutter, `:212` asserts `abs(Panel.position.x) > 10` for an open gate (the fixture's wide gate), and `:214` asserts a closed car's `Panel.position == Vector3.ZERO`.
- The `Collider` body with a `BoxShape3D` of the opening's size, world layer only while closed, and the bake's all-closed `snap(true)` (`level_root.gd:258`). Art must not collide.
- The same API (`progress()`, `moved(closed)`, `snap`, `close`, `open`, `is_closed`, `is_moving`, `walk_direction`, `past`, `barrier.gd:54-104`) and the tunables `barrier_close_s` 0.6 and `barrier_open_s` 0.8 (`game/autoload/tuning_data.gd:1027,1029`).
- A closed panel that covers `width_m x height_m x thickness_m`, and an open one that leaves the opening clear, so the open barrier still reads as a gap (the GO cue's twin, finding `final-sees-05`).
- Solid wall or an alley mouth beside the opening for a gate or car to slide into (`width_m + 0.2`).
- Shadows on (the boxes cast them, `barrier.gd:222`).

**Instances in the level:**
- Street (`street.tscn:620-660`):
  - `StartCar`: CAR, 6 wide, 2.2 high, 1.8 thick, `car_length_m` 3.2 (so 2 cars of 3 m), starts open;
  - `Gate`: GATE 6x3.5, `open_side` -1, closed;
  - `YardCar`: CAR 6x2.2, closed;
  - `ExitBarrier`: SHUTTER 6x3.5 at y 4.5, closed.
- Roofs (`roofs.tscn:1088-1111`): `GateStair2` GATE 3x3, `ShutterStair3` SHUTTER 3x3.5, `ExitBarrier` GATE 4x3.5.
- The boss roof has none.
- `Arena` reads only the barrier API (`arena.gd:51-60`); `LevelSection` finds barriers by script (`level_section.gd:31,54`).

**Car:** the drawn cars are boxes with a hull via `prop_material` (`barrier.gd:210`). A Tripo parked car at about 3 m long and 1.8 deep needs the hull answer in section 4.

## 4. Environment shading

**Where it comes from.** `LevelBlock._material()` (`level_block.gd:101-111`) gives `floor` the grid, `prop` a hulled flat material, and the rest `ToonMaterials.environment(color)` (`game/fx/toon_materials.gd:138-146`), one material per call (`tests/test_m4_contracts.gd:323`). `game/actors/rig_paint.gd` has no environment code (the brief named it; its only relevant line is `warm_up`, `:145`).

**Shader.**
- `ToonMaterials.environment` is `Kind.ENVIRONMENT`, made by `_make` on `toon.gdshader` (`toon_materials.gd:343-357`) with a flat `albedo` and `use_albedo_tex` false.
- Lighting is `toon_light.gdshaderinc`: `render_mode ambient_light_disabled` (`toon.gdshader:8`), so only the sun lights a surface and the sky's ambient does nothing. `lit = N.L * ATTENUATION` (`toon_light.gdshaderinc:79-82`).
- `toon_shade` (`:71-77`) gives a shadow band, a mid band and a lit band at `look_band_1` 0.22 and `look_band_2` 0.52 (`tuning_data.gd:1193,1195`), edge `look_band_soft` 1.2 px, `look_shadow_level` 0.42 tinted 45% toward violet.
- The environment gets two bands because `apply_look` sets `mid_level` 1.0 for `room_surface` (`toon_materials.gd:169,174`); it has no rim, no fill, and is matte (`:183-194`).
- `ROUGHNESS = edge_tag` (`toon.gdshader:122`), 1 for the environment.
- `grid.gdshader` is the precedent for a second environment shader: it includes `toon_light.gdshaderinc`, is `Kind.GRID`, and takes the same Look values through `apply_look` (`toon_materials.gd:150-155`).
- Halftone is off (`look_halftone_env`, `tuning_data.gd:1260`).

**Edge pass** (`game/fx/edge_pass.gdshader`, `game/fx/look_post.gd`):
- A full-screen quad at render priority min+1 (`look_post.gd:30,152`). It draws depth lines (on the nearer side of a step) and normal creases, 1.25 px (`look_edge_px`), fading from 25 m to 60 m (`tuning_data.gd:1302-1312`; the bible says 1 to 1.5 px, `docs/milestones/M4-look-bible.md:16`).
- A character's hull is tagged ROUGHNESS 0, which masks the lines near it.
- Modules get a free outline wherever there is a depth step or a crease. Bevels and detail add crease lines, and two coplanar faces draw a dashed line (finding `final-sees-06`), so the dressing must avoid coplanar overlaps.
- Every environment material must keep writing ROUGHNESS 1, or the pass skips it.

**Prop hull** (`prop_material`, `room_kit.gd:147-149`): `environment(color, true)` puts `Hull.BOX` on `next_pass` (`toon_materials.gd:141-146`). `Hull.BOX` pushes out by `sign(VERTEX)` per axis (mode 1, `toon_outline.gdshader:42-44`), correct only for boxes. A non-box prop (car, dumpster, AC unit, water tank) needs `Hull.NORMAL` (cracks at hard edges), `Hull.ART`, which reads a baked smooth normal in CUSTOM1 (`toon_outline.gdshader:50-52`, so the mesh must carry it), or no hull plus trim ink. Not decided yet.

**Does the toon shader support a trim texture?** Partly. Today: `albedo_tex` on UV0 (nearest, no repeat, the palette atlas, whose alpha is the damage class, `toon.gdshader:20-22,90-97`) and `detail_tex` on UV2 (linear mipmap, no repeat, R is the ink line, `:26,98-104`). Neither tiles a painted sheet.

**Change needed:** either (A) a new `Kind.TRIM` shader like `grid.gdshader`, including `toon_light.gdshaderinc`, with `trim_tex` (linear mipmap, repeat), an `albedo` tint kept as a `Color` uniform for the tests, and `room_surface` true in `apply_look`; or (B) new uniforms in `toon.gdshader`. The architecture rule is "a look is a uniform, never a new shader variant" (`toon_materials.gd:5-8`), but `grid.gdshader` is already an exception. (A) leaves the character shader alone. Either way, draw the new shader in `ToonMaterials.warm_up` (`:296`, windowed only), so its first draw does not compile on a frame.

## 5. Readability the dressing must keep, and the tests that read the environment

**Readability.**
- **Spawn doorways read as dark openings.** The `dark` look is `Color(0.26, 0.24, 0.27)` (`level_block.gd:23`), value 0.26, at the bible's floor of 0.25 (`M4-look-bible.md:34`). The doorways are the 5-block recesses of section 1, with spawn points inside.
  - Street: `Doorway` (7.4,0,-10.75), `Office` (7.4,0,-25.25), `Brick` (7.4,0,-34.25), `WarehouseA/B` (-7.4,0,-40/-43), 2 alleys, `VanL/R` (vehicle), `LandingA/B` (stairwell) (`street.tscn:714-832`).
  - Roofs: 10 points (`roofs.tscn:1196-1306`). Boss roof: `RoofDoor`, `ServiceDoor`, `GateDoor` (`boss_roof.tscn:412-428`).
  - Street door openings are 3.4 m high (jamb tops at y 3.4). Dressing in or beside an opening must stay dark and clear.
  - `SpawnRoomCheck` queries physics (`spawn_room_check.gd`), so a visual prop that overhangs its collider will not block a spawn but will look like an enemy standing inside it.
- **Rails at drops.** Rails are the drawn-only `fence` look. The EdgeGuard (layer 9, `edge_guard.gd:32-37`) and the HazardVolume are invisible, so the posts and the lower floor's look are all that says "drop". Finding `final-sees-03` (medium, `docs/reviews/M5/findings-final.json`): the boss roof's gap reads as a ledge onto a pale lower plane, because the `Ground` at y -12.5 is fog-lightened and untextured with no void or depth falloff, while the A5 catwalk side reads well (terrace below, grid, rail). The boss roof's skyline and ground need depth and detail, and the gap's rail ends and lip stripes must stay.
- **GO cue.** It is HUD 2D: `GoCue` (`game/ui/go_cue.gd`) draws "GO" and an arrow at a world point, `level.next_target(arena)` (`level_root.gd:149`), the next arena's first route point. It does not depend on the art, but the open barrier is its twin (`final-sees-05`).
- **Floor weapon.** `final-sees-02`: the pipe is hidden behind a crate stack on grey. `weapon_floor_color` is (0.96,0.7,0.1) (`tuning_data.gd:1055`), and `tests/test_level_kit.gd:644-660` requires it to contrast with `LevelBlock.COLORS[&"floor"]` (luminance gap 0.25 or saturation gap 0.5). The proposal replaces the amber with a glint, so that test moves with it, and the floor's tone will matter to the glint's contrast.
- Lens coverage R8 measures rig meshes only (`tests/fp_view.gd`), not the environment.

**Tests that read the environment.**
- `tests/test_look_post.gd:452-466`: loops the training room's `StaticBody3D` children, takes `body.get_child(1) as MeshInstance3D` and `.mesh as BoxMesh`. It **breaks** if the training room's boxes become modules.
- `test_look_post.gd:518-541` and `:545-560`: scan the crowd room and the training room for a colour read through `ShaderMaterial.get_shader_parameter(&"albedo")` (`_albedo`, `:493-500`), checking not-red, saturation <= 0.30 and value 0.25-0.6.
  - The car colour (0.34,0.38,0.45) must be among the seen colours (`:527`), and `checked > 20` (`:559`).
  - A texture-only trim material has no `albedo` colour, and an `ArrayMesh` is not a `PrimitiveMesh`, so the bible check goes silently vacuous and the count asserts fail. A new test must check the sheet's own pixels against the bible, and the new material should keep an `albedo` tint.
- `tests/test_m4_contracts.gd:302-324`: `ToonMaterials.environment` and `RoomKit.flat_material` are toon `ShaderMaterial`s with `albedo` as set, one per call; the grid keeps its shader.
- `tests/test_level_kit.gd:210-214` (the barrier panel) and `:658` (`LevelBlock.COLORS`).
- Tests that read `LevelBlock.world_aabb()`: `test_m5_street.gd:166-169,425`, `test_m5_roofs.gd:367-371`, `test_m5_done_when.gd:385-387` (nothing solid past the exit, inside the footprint, sections do not overlap). Dressing must not be a solid `LevelBlock`.
- `tests/fixtures/level_strip*.tscn` also use `LevelBlock` and `Barrier`, so the art layer must work there.
- The navmesh tests (`test_level_kit.gd:234-300`, `test_m5_roofs.gd:292-320`) need the colliders unchanged; meshes do not affect them.
- Acts that show the world: `Look: drops` (`tests/bot/level_acts/drop_acts.gd:26`), `Look: seams` (`seam_acts.gd:35`), `Run: held back / knock-off / timing` (`run_acts.gd:15-17`), recorded by `tools/record_acts.sh` with `BOT_SCENE=res://tests/bot/level_bot.tscn` and `CAPTURE_ARGS="--level=... --from= --to="`. The M5 final captures are in `captures/m5-final/{street,roofs,boss,seams,knock-catwalk}`.

## 6. The crowd room and the training room

**Crowd room** (`game/level/crowd_room.gd`, 350 lines): built in code under one `Geometry` node.
- `_build_geometry` (`:194-209`) makes 3 materials (wall 0.42, accent 0.5, dark 0.26) and calls `_build_lane` (grid floor 30x1x12, dashes), `_build_north`, `_build_ends`, `_build_south`, `_build_props` and `_build_backdrop`.
- North: 4 front blocks with 3 doorway recesses (floor, dark back, lintel) at x -9, 0, 9; windows are drawn-only boxes 1x1.3x0.12 at pitch 2.2 (`:255-268`), shadows off.
- The ends have an alley each; the south has a curb and a side alley, with an invisible barrier box above the curb.
- Props: 2 crates of 1 m, a car 4.2x1.9x1.4 (0.34,0.38,0.45), a dumpster 2x1.3x1 (0.28,0.4,0.34) (`:326-338`).
- Backdrop: a 160x1x60 ground and a skyline of drawn-only boxes (`:343-350`).
- It uses `RoomKit.add_box(geometry, ...)` throughout, so `LevelBlock` is not on this path. Spawn points are code (`spawn_point_list`, `:152`). The bake reads `geometry` (`_bake_navigation`, `:181`).

**Training room** (`game/level/test_room.gd`, 131 lines): a grid-floor slab (`:65`), far-side fronts of varied heights (`:77`), 2 end walls (`:81-82`), a 0.6 m near curb (`:84`), 3 crates (`:86-88`), dashes (`:90-93`), 3 `TrainingDummy` scenes (`:97-113`). No spawn doors, no navmesh bake, no barriers.

**What reusing the kit there needs.** Both rooms use only `RoomKit.add_box` and `add_visual_box`. The least invasive route is a module option inside `RoomKit` itself (an optional art argument on `add_box`), so both rooms, `LevelBlock` and `Barrier` share one hook, and the code-built rooms need no `LevelBlock` refactor. The cost is the tests in section 5 (`test_look_post.gd:452-466,518-560` assume `BoxMesh` and `albedo`).

## 7. Perf

**How frame time is measured.** `tests/bot/perf_bot.gd` (a crowd bot) records wall time between process frames over a perf act and prints `PERF-BENCH {json}`: frames, mean, p95, worst, spawn hitch, first spawn, first hit, stalls (`:3-24`). `tools/perf_compare.sh <ref>...` runs each ref in a temporary worktree, interleaved, windowed, vsync off by default (`--vsync on` avoids a Mac stall of 1 s every few seconds, `:30-35`), refusing to start above load average 2.0, and checks the soft bars (p95 <= 16.7 ms, spawn hitch <= 33 ms, first hit and first spawn within +2 ms of the first ref, `:46-47`). R15 in the probe has the same limits (`readability_probe.gd:64-65`). The `frame_ms_p95` of 44.8 ms in `captures/m5-final/street/held/readability.json` came from a Movie Maker recording, so it is not a measure (`perf_bot.gd:26`).

**Baselines in the repo.** All are crowd room, M3 against M4 (`docs/HANDOFF.md:789`, `captures/perf_compare/a16/`):
- "Perf, six with ragdolls" mean 12.10 ms (M3) vs 14.53 ms (M4), p95 up 3.4. The raw `PERF-BENCH` lines show p95 26 ms (M3) and 29 ms (M4), vsync on, with other apps loading the machine at 2.4-4.6.
- M3 already misses the p95 16.7 bar on this machine (HANDOFF `:640`).
- The edge pass costs about 3.1 ms at 4x MSAA and 2.0 ms with FXAA (HANDOFF `:810`); edges off saves 3.5, depth-only edges 1.0, FXAA 2.3, and hulls on placeholders nothing measurable (HANDOFF `:789`). `project.godot:79` sets MSAA 2x.
- **No level number exists.** M5 added no perf act, and `level_bot` extends the crowd bot, not `perf_bot`. The proposal's phase 3 item 4 ("frame time against M5") needs a new act first: a level walk (for example the street A1 to A3, then the roofs) under `perf_bot`, run on `main` and on `m6` with `perf_compare.sh --act "<title>"`.

**The risk from more meshes.**
- Today's draw count is about 300 blocks plus 68 steps plus about 100 barrier boxes (the shutter alone is 11 ribs plus a slab, `barrier.gd:169-177`), each its own `MeshInstance3D` with its own `ShaderMaterial` (one per `flat_material` call), so nothing batches or instances. Props add a hull `next_pass`, doubling their draws (`toon_materials.gd:141-146`).
- Every material is tracked and re-set on each `Tuning.changed`, about 25 parameters each (`toon_materials.gd:377-404`). That costs when dragging F1 sliders, not in play.
- The sun's shadow distance is 40 m (`room_kit.gd:88`). Modules cast shadows, which adds to the shadow pass.
- Advice: one shared trim material and one surface per module (draw count then follows the mesh count only); merge static dressing per section (one `ArrayMesh` or `MultiMesh` for rails, posts and shutter ribs, which are exact repeats); keep hulls to hero props; watch overdraw from the 9 to 30 m skyline blocks.
- Any new shader or material variant must be drawn once at load (`RoomKit.warm_up_art`, `room_kit.gd:201-210`, windowed only), or its first draw hitches.
- Triangle budgets: module 5k, weapon or prop 3k (`docs/SPEC.md:326-327`).

## 8. The palette atlas and the look bible

**The atlas** (`assets/export/palette/palette_atlas.png`): 256x16 RGBA8, 64 slots of 8 px. Slots 0-15 are shared, 16-31 punk, 32-47 player, **48-63 reserved** (`tools/pipeline/gen_palette.py:6-9`; `assets/source/palette/{shared,punk,player}.json`). Shared uses 0-14, so slot 15 and 48-63 are free (17 slots).
- It is nearest-filtered with no mipmaps and no repeat (the `.import` and `toon.gdshader:22`).
- Alpha encodes the damage class: 255 clothes, 204 skin, 128 none, minus 1 for glossy (`gen_palette.py:7-10`). An environment swatch would use alpha 128. Environment materials have `marks` 0 anyway.
- Rebuilt by `python3 -I tools/pipeline/gen_palette.py`; `--check` compares the committed PNG with the JSON.
- Shared swatches that already sit in the environment band (S <= 0.30, V 0.25-0.6): `dark_grey` #4b4854, `steel` #5c6b7a, `olive_grey` #6f7466, `violet_grey` #6a6478. `mid_grey` #8b8793 is V 0.58. `canvas` #b9a98a is V 0.73, too bright.

**Can environment swatches live on it?**
- **Hero props: yes.** SPEC 12 gives a prop or weapon the shared palette atlas, 3k triangles (`SPEC.md:327`). A dumpster or car can sit on a few flat swatches (up to 17 free slots), and `use_albedo_tex` already works.
- **Modules: no.** A painted, tiling, filtered sheet with ink lines is a different texture: the atlas is 8 px flat swatches, nearest, no repeat. SPEC 12 asks for "a 2k trim sheet" for modules (`SPEC.md:326`), so it is a separate asset beside the atlas. It takes no palette slots; if its painted colours must match the atlas, `gen_palette.py` is the place to check them.

**The look bible for the environment** (`docs/milestones/M4-look-bible.md`):
- Saturation at most 0.30 (HSV), value 0.25-0.6 (`:34`).
- The environment has 2 bands; band edges at most 2 px at 1 m (`:24`).
- Shadow never below 40% of the lit value, hue shifted 45% toward violet (0.36,0.32,0.55) (`:25`).
- Halftone off (`:28`). Edge lines 1-1.5 px, fading from 25 m to 60 m (`:16`). Red only for blood and accents (`:36`).
- A grade LUT is applied to the whole picture (`:37`; `look_post.gd:193`; tunables `look_grade_enabled`, `look_grade_strength`).
- Two practical points. (1) The bands multiply the sheet by 1.0 lit and 0.42 shadow, so a sheet painted at value 0.6 renders darker in shadow; the existing tests check the flat `albedo` against 0.25-0.6, so the new sheet test must decide whether it measures the sheet's pixels or pixels times a band. (2) `dark` is already at the 0.25 edge, and the dark doorway reads only by contrast with its neighbours.

**Per-section light** (proposal: "light per section"). There is one `WorldEnvironment` and one `Sun` for the whole level, built once by `RoomKit.build_environment(self)` in `LevelRoot._ready` (`level_root.gd:69`, `room_kit.gd:62-89`): procedural sky, ambient 0.7 (disabled in the toon shader), fog density 0.008, sun energy 1.2. No other `Light3D` exists in the game code or scenes. `LookPost` re-applies the sun from Tuning on any `look_*` change (`look_post.gd:164-175`), which would overwrite a per-section sun. So per-section light needs a new mechanism: for example `LevelSection` exports (sun yaw, energy, fog, sky) that `LevelRoot` swaps as the player enters, plus a rule in `LookPost`. Omni lights also work in the toon `light()` (`LIGHT_IS_DIRECTIONAL` branches only the fill, `toon_light.gdshaderinc:79-82`), but cost shadow passes. Sections are placed end to end on their `Entry` and `Exit` markers (`level_root.gd:205-224`).

## Risks

1. The `LevelBlock` rebuild covers the 296 blocks one by one but not multi-block features (the 5-block doorway). A section-level dressing layer is needed, and its solids must not be solid `LevelBlock`s.
2. `Hull.BOX` is box-only, so non-box hero props need another hull mode or none (section 4).
3. Tests that will fail or go silently vacuous with art: `test_look_post.gd` (BoxMesh, `get_child(1)`, `albedo`, `checked > 20`), `test_m4_contracts.gd` (flat material API), `test_level_kit.gd` (Panel offsets, floor colour). Each needs a replacement check that reads the trim sheet itself.
4. No level frame-time baseline exists. Add the act and take the M5 baseline before the first module lands.
5. A `ShaderMaterial` per block plus a hull per prop gives about 400+ draws today. Modules on one shared material reduce this; modules on per-block materials add to it.
6. Per-section light collides with `LookPost`'s sun write.
7. Edge-pass crease lines on detailed modules, and coplanar overlaps (`final-sees-06`), add noise.
8. The boss roof's far world (`Ground`, skyline) causes the weak drop read (`final-sees-03`); flat dressing there keeps the finding open.
9. Sections overlap visually at seams (skyline and drawn-only blocks are not tested), and the roofs' footprint test has a 1 m tolerance (`test_m5_roofs.gd:360-372`).

## Questions for the lead

1. Procedural trim-mapped meshes from `size`, tiled Blender modules, or a mix?
2. A new `Kind.TRIM` shader like the grid (recommended), or new uniforms in `toon.gdshader`?
3. Hull for non-box props: a baked smooth normal in CUSTOM1, mode 0, or no hull plus trim ink?
4. Where should the module hook live for D9: `RoomKit.add_box` (shared by both code-built rooms and `LevelBlock`) or `LevelBlock` only?
5. Per-section light by section-export swaps, or one level light plus local omnis?
6. Accept replacing the `BoxMesh` and `albedo` assumptions in `test_look_post.gd` as part of the LOOKS package's placeholder test?
7. Add a level perf act, and an M5 baseline run on `main`, in Phase 1?
