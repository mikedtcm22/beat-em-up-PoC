# M4 calls: P1-toon

Judgement calls of the P1-toon package (M4-plan Part C §5 "P1-toon" with §2.3 and §2.7, as amended by A7, A8, A9, A11 and A18). Each: the decision, an alternative not taken, and why. Part 2 lists every assertion that changed (old to new, with the twin on the visible path), and part 3 what the captures and measurements showed.

## 1. Calls

**C1. One shader for every lit surface, with the look, the flash and the damage as uniforms.**
- *Decision.* `game/fx/toon.gdshader` serves the primitive characters, the skinned art, the pipe and the room's boxes; `grid.gdshader` includes the same `toon_light.gdshaderinc`. A primitive, the art, a wall and a prop differ only in uniforms (`albedo_tex` on or off, `use_rest_custom`, `marks`, `edge_tag`, the Look values `ToonMaterials` pushes per kind). So a flash, a damage look or a detail mask never changes the shader variant.
- *Alternative.* One shader per kind (character, art, environment). Smaller fragment code each.
- *Why not.* A mid-fight first use of a variant costs 3-12 ms (the damage look's old lesson), and one shader makes `warm_up()` a single pass. The cost is a few uniform branches, which the M1 does not feel (codemap blender §8.6: the lighting costs nothing measurable).

**C2. `edge_tag` is 0 on everything that has its own hull, 1 elsewhere.**
- *Decision.* A8 says ROUGHNESS is 0 on a character's art and 1 elsewhere; A7 came first and gave every primitive character, dummy and prop a hull too. The edge pass skips pixels tagged below 0.5, so a primitive tagged 1 would get a depth line beside its hull (the doubled silhouette A8 exists to prevent). So the tag follows the hull: `character()`, `prop()` and `environment(color, true)` are 0 while `look_hull_on_placeholders` is on, 1 when off; `art()` is always 0; walls, the floor and `grid.gdshader` are 1.
- *Alternative.* The letter of A8: 0 on the art only. Simpler to state; wrong whenever the placeholder hulls are on, which is the default.
- *Why not.* It would double the line on every placeholder. The tag is read when the material is built (C12), so it always agrees with the overlay. P1-post reads it as "any tap below 0.5".

**C3. A prop box in the room takes its hull as the material's own `next_pass`.**
- *Decision.* `ToonMaterials.environment(color, hulled := false)`: with `hulled` and `look_hull_on_placeholders`, the material's `next_pass` is the shared box hull. `RoomKit.box_mesh()` puts the material on the BoxMesh (`box.material`), which has no overlay slot at the call sites, and the hull needs no edit to room_kit.gd or crowd_room.gd. Characters and the pipe use `material_overlay`; their `next_pass` stays the contact flash's.
- *Alternative.* Edit RoomKit to set `material_overlay` on every box, or give `add_box()` a hull argument.
- *Why not.* room_kit.gd is P1-post's (and crowd_room.gd's colours, too). Which boxes are props (crates, dumpster, car) is the room's knowledge. The wiring is a request: P1-post (or SL-int) calls `ToonMaterials.environment(color, true)` for them, for example through a `RoomKit.prop_material(color)`. Until then the crates, dumpster and car have no hull; the walls never should.

**C4. The hull's push direction is a function of position alone, per mesh type (A7's modes, refined).**
- *Decision.* `toon_outline.gdshader` mode 0 along the vertex normal (spheres, capsules), 1 `sign(VERTEX)` per axis (boxes), 2 radial in xz plus `sign(y)` on the whole cylinder (not on the caps only), 3 `normalize(VERTEX)` (the cap's hemisphere), 4 the art's baked smooth normal. `ToonMaterials.hull_direction()` mirrors modes 1-3, and a test runs them over the rig's actual meshes: every vertex at one position gets one direction (no cracks), and for boxes, cylinders, capsules and spheres every vertex moves its face plane out by exactly the width (`dir . normal == 1`).
- *Alternative.* A7 literally: radial on the cylinder's side, `sign(y)` on its caps only. The rim vertices of the side and of the cap would then move apart (a ring crack at every cylinder's rim, which a thick hull makes visible).
- *Why not.* A function of position alone cannot crack. The hemisphere's open rim has its lid disc moved by radius rather than by exactly the width (it sits against the head and is never seen).

**C5. The art's baked COLOR normal is carried through the skin by the turn from the rest normal to the skinned normal.**
- *Decision.* COLOR is a plain vertex attribute, so the skin does not rotate it; with a body bent at the elbow a COLOR normal in rest space would push the hull the wrong way. Mode 4 takes the rest normal from CUSTOM1 (which P1-skin's `attach()` already adds for the damage look), the skinned `NORMAL`, and rotates the baked smooth normal by the shortest arc between them (Rodrigues). Where a vertex has no CUSTOM1 it falls back to the skinned normal. Seen working on the bent fixture (part 3).
- *Alternative.* Put the smooth normal in TANGENT (the skin transforms it) or use the skinned NORMAL alone.
- *Why not.* The contract names COLOR (P1-chain exports it) and P1-skin rebuilds the surfaces with CUSTOM0/1; TANGENT would change both. NORMAL alone cracks at hard edges, the problem COLOR exists for. The arc loses only the twist about the normal, which is small where the smooth and the face normal agree (Tripo's meshes are smooth).

**C6. The width: pixels at 1080p between `near` and `far`, `near` default 0.3 m, a lens fade of one to two fade lengths.**
- *Decision.* `w = px * 2 * clamp(d, near, far) / (1080 * P11)`, where `P11` is `PROJECTION_MATRIX[1][1]`: the viewport height cancels, so the line is `look_outline_px` at 1080p on every window size and FOV (measured, part 3). `look_outline_near_m` defaults to 0.3 (the plan's "near" had no value): nearer than that the line keeps its world width and grows on screen; between 0.3 and 12 m (`look_outline_far_m`) it is constant; beyond 12 m it thins (2 px or more out to 10 m, as the bible asks). The fade is `smoothstep((d - fade) / fade)`: 0 within `look_outline_lens_fade_m` (0.1 m), full at twice that. `ToonMaterials.outline_width_m()` mirrors all of it.
- *Alternative.* `near` of 1 m (the first value tried): the player's own arms at 0.3-0.6 m would then be drawn at 2-3 times the line (7 px), against J14 ("outlines aren't heavy"). Or a lens fade that starts at the near plane (0.05 m).
- *Why not.* The arms need a constant line from 0.3 m; 0.1 m is where a lens meets the shell of a 3-4 px hull at the near plane's 0.05 m with margin.

**C7. A hull on `material_overlay` draws into the shadow map; it is cut to nothing there.**
- *Decision.* A7 asked. Measured (part 3): without a guard a 40 px hull fattened a box's shadow from 8,516 to 12,802 shadow pixels (+50%), because the overlay's vertex shader also runs in the directional light's shadow pass, with the light's orthographic projection. The shader sets the width to 0 when `PROJECTION_MATRIX[3][3] != 0.0` (orthographic), and the toon shader keeps shadows on (no `shadows_disabled`). With the guard a 40 px hull gave 8,387 against 8,516 with none: the shadow is the mesh's own. The game has no orthographic camera, so the guard costs nothing visible; a future orthographic debug camera would draw no hulls.
- *Alternative.* `cast_shadow = OFF` on the overlaid meshes (no shadows from characters), or a thin hull accepted (the shadow fattens by the hull's world width, about 7 mm at 3.75 px).
- *Why not.* The characters' shadows matter to the look (the player reads them on the street), and the fattening scaled with the pixel width and was garbage under the light's projection.

**C8. The lighting: lit is the albedo, band edges are pixels wide, the shadow keeps its brightness.**
- *Decision.* `light()` is one function. Light is `dot(NORMAL, LIGHT) * ATTENUATION` (the shadow term is in it). The shade is `shadow_level` (0.42, tinted 45% toward the violet with its luminance kept, so it never drops below the level), `mid_level` (0.72), then 1, with the edges smoothstepped over `look_band_soft` pixels at 1080p (scaled by `VIEWPORT_SIZE.y / 1080`, as the halftone cell is) of the light's own gradient (`fwidth`, capped so a shadow map's hard edge stays hard). The light's color is `LIGHT_COLOR / PI` capped at 1, so the lit band is the palette as authored whatever the sun's energy (the room's 1.2 sun washed the first version). One highlight (`look_spec_cut` 0.99, x3 on glossy materials), a stepped rim where the light reaches. `ambient_light_disabled`: the ramp owns the shadow side. The room has two bands (its `mid_level` is pushed as 1).
- *Alternative.* Fixed-width edges in light units (the codemap's first prototype: `band_soft 0.012`), and `LIGHT_COLOR / PI` uncapped.
- *Why not.* A light-unit edge is 1 px on one surface and 10 on another (a sphere's gradient against a cylinder's), which the bible's "at most 2 px at 1 m" cannot hold; the blurred highlight in the first render showed it. The uncapped light made the skin read pale pink under filmic tonemapping. `fwidth` in `light()` is derivative-dependent and the loop over lights is not guaranteed uniform; with one sun it is. If a second light ever shows ragged edges, `look_band_soft` 0 gives hard steps.

**C9. Both halftone switches default off.**
- *Decision.* Part C §2.9 had `look_halftone_env` (true); the look bible (A11, later) says "halftone off by default". Both `look_halftone_env` and `look_halftone_chars` are false. The dots are screen-space cells in the shadow band (`look_halftone_cell_px` 6, `look_halftone_strength` 0.5).
- *Alternative.* The environment on, as Part C had it.
- *Why not.* A11 overrides Part C, and F-look can switch it on with a toggle.

**C10. The art has one damage texture per level: the clothes' tiles.**
- *Decision.* The art is one material with one `damage_tex`, so `DamageLook.apply_art()` gives it `damage_scuffed` at BRUISED and `damage_blood` at BLOODIED, on the atlas's marks alpha. The primitives still show the skin's bruise and blood tiles on their SKIN paint.
- *Alternative.* Two textures (`damage_skin_tex`) and a skin mask.
- *Why not.* The palette has no skin marker (alpha is 1.0 marks, 0.5 none), and the contract is P1-chain's. If the final review wants bruises on the skin, the palette needs a skin range (the shared slots 0-15 hold the skins) and the shader a second texture; open risk.

**C11. `ToonMaterials.character()` and `environment()` gained optional parameters.**
- *Decision.* `character(color, takes_marks := false, glossy := false)` and `environment(color, hulled := false)`. Callers of the pinned one-argument forms still work; the contract test counts every parameter, so its two rows changed (1 to 3, 1 to 2).
- *Alternative.* Keep the arities and set marks and gloss after the call.
- *Why not.* The glossy flag decides which Look value the registry pushes later, so it belongs to the factory.

**C12. `look_hull_on_placeholders` is read when a body, a prop or a box is built.**
- *Decision.* Whether a part has its hull is the overlay's presence, decided in `outline_material_for()`, and the edge tag agrees with it. The slider's doc says so. The A16 fallback measure ("placeholder hulls off") therefore costs nothing when off, and a preset or `--tune` sets it before the room spawns anything.
- *Alternative.* A live toggle (a `hull_enabled` uniform that collapses the shell in the vertex shader).
- *Why not.* The overlay would stay on every mesh (the draw calls and the vertex work remain), so "off" would not be the fallback it is measured as, and the edge tags would need a second live path.

**C13. Three lines of humanoid_rig.gd, which P1-skin owns.**
- *Decision.* `_materials` is a `Dictionary[int, ShaderMaterial]` now (a typed dictionary cannot hold RigPaint's), and `HumanoidRig._FLASH_SHADER` is gone: `flash_at()` uses `RigPaint.FLASH_SHADER` (the lead's note asked for the fold). Nothing else in the file changed.
- *Alternative.* Leave the type and keep the second preload; both would be an untyped `Dictionary` and a duplicate.
- *Why not.* The retype is forced (RigPaint's materials changed type), and the hunks are three lines far from where P1-skin works (`_build_meshes`, `set_art_shown`). Reported in "requests" for the merge.

**C14. The toon is built and tested on a procedural fixture; the probe GLB is P1-chain's.**
- *Decision.* A18 says to implement and test the detail mask on the probe body. That GLB is not on this branch, so `tests/fixtures/toon_art_probe.gd` makes a two-bone skinned capsule with everything a real art has (palette UVs on swatches, UV2 for the mask, COLOR smooth normal, CUSTOM0/1 rest position and normal), tests check its channels and the shader's use of them, and the act "Look: toon art fixture" shows it windowed: palette, mask stripe, hull, bent tip, scuffed marks, flash. Re-pointing the act at `probe_body.glb` after the merge is a one-line change for SL-int.
- *Alternative.* Wait for the probe.
- *Why not.* The art path was the riskiest part (COLOR, CUSTOM, UV2 under a skin) and should be seen before phase 1c.

**C15. Two tunables beyond the plan's list, both in the Toon subgroup.**
- *Decision.* `look_shadow_level` (0.42) and `look_shadow_tint_amount` (0.45), since the bible gives "42%" and "45% toward violet" as two numbers and `look_shadow_tint` (Color) as one. Also `look_band_1/2/soft`, `look_spec_cut/strength/gloss`, `look_rim_cut/power/strength` and the four halftone values; and in Outline `look_outline_near_m/far_m/fp_scale/lens_fade_m`. All `@export_range` with a `##` line each; 20 new values in the preset (462 to 482).
- *Alternative.* Encode the tint amount in the Color's alpha.
- *Why not.* A slider is clearer in the F1 panel.

**C16. Warm-up.**
- *Decision.* `ToonMaterials.warm_up(parent, skinned := null)`: once per run, windowed, a toon box under each hull mode (and the art's variant when given an art instance) for two frames, then freed. `RigPaint.warm_up()` calls it inside its existing once-per-run gate, so the first rig built in a window warms it. The flash's own warm-up box is unchanged. The fixture act ran the skinned path windowed without an error.
- *Alternative.* Warm in `HumanoidRig.build()` per rig.
- *Why not.* The pipelines are per shader and vertex format, not per rig.

## 2. Assertions that changed (old to new, and the twin on the visible path)

The visible path is the captures (part 3): a headless run draws nothing, so each twin is a uniform or a source check in `tests/test_toon.gd` plus the sheet that shows it.

- `tests/test_m4_contracts.gd`:
  - `test_the_contract_signatures_exist`: `character` arity 1 to 3, `environment` 1 to 2 (C11). Twin: the same row still checks every other signature.
  - `test_a_rig_without_art_builds_exactly_the_m3_primitives`: `assert_null(mesh.material_overlay)` to a hull ShaderMaterial with the outline shader; `material_override is StandardMaterial3D` to a ShaderMaterial of `TOON_SHADER`. Twin: `test_every_rig_primitive_gets_the_hull_of_its_shape_with_no_cracks`.
  - `test_rig_paint_holds_the_rigs_materials_and_colors`: `Dictionary[int, StandardMaterial3D]` to ShaderMaterial; `albedo_color` to the `albedo` uniform (same colors); `emission_energy_multiplier == 0` and `emission_enabled` to `flash_amount == 0` and one shader for every paint ("the parry flash never switches variants"); `assert_null(outline_material())` and `outline_material_for` to not null (the hulls exist). Twin: `test_a_rig_has_one_toon_material_per_paint_and_the_dark_one_is_glossy_and_takes_no_marks`.
  - `test_rig_paint_flash_damage_and_overlay_reach_every_base_material`: the art material is a ShaderMaterial; `albedo_texture` to the `albedo_tex` uniform; `texture_filter == NEAREST` to the sampler hint `filter_nearest` in the shader source; `emission`/`emission_energy_multiplier` to `flash_color`/`flash_amount`; `detail_albedo` to `damage_tex`. Twin: `test_the_art_material_flashes_and_takes_the_damage_look_by_texture_swaps_alone`.
  - `test_toon_material_stubs_keep_todays_recipes` to `test_toon_material_factories_return_the_toon_materials`: the StandardMaterial3D recipes (prop rough 0.5 / metal 0.4, environment rough 0.9) and the null stubs became toon materials and hulls; the colors, the grid's shader and the headless warm-up no-op are kept.
  - `test_room_kit_materials_delegate_to_toon_materials`: `StandardMaterial3D` rough 0.9 to a `TOON_SHADER` ShaderMaterial; colors and one-per-call kept.
  - `test_the_pipe_takes_its_material_and_overlay_from_toon_materials`: `StandardMaterial3D` rough/metal and no overlay to a toon ShaderMaterial and a cylinder hull on the overlay.
- `tests/test_damage_look.gd` (the six moved tests; their count is unchanged, 6):
  - `test_rig_damage_look_changes_materials_only`: `detail_enabled` to `marks > 0.5` (the dark paint's stays 0); `detail_albedo` to `damage_tex`; `uv1_triplanar` to the shader's three-tap triplanar blend in its source. Twin: the capture of the bloodied Punk (part 3).
  - `test_damage_look_never_switches_the_shader_variant`: "every stored property but `detail_albedo` and `uv1_scale`" to "the shader and every declared uniform but `damage_tex` and `damage_scale`", compared across five level changes (uniform names read from the shader source, since a headless ShaderMaterial lists none). Twin: the same check on the art material in `test_toon.gd`.
  - `test_damage_look_rereads_the_tile_size`: `uv1_scale == ONE / tile` to `damage_scale == 1 / tile`.
  - `test_whole_body_flash_still_covers_the_damage_look`: `emission`, `emission_energy_multiplier` to `flash_color`, `flash_amount`; `detail_enabled` to `marks` and the `damage_tex` kept under the flash. Twin: the cyan capture with the marks showing through.
  - `test_clean_detail_texture_is_clear_and_held` and `test_bruises_are_not_red_paint`: unchanged.
- `tests/test_hit_flash.gd`: `_materials()` returns ShaderMaterials; every `emission_energy_multiplier` read became `flash_amount`, `emission` became `flash_color`, `detail_enabled` became `marks`. Nothing else changed (the contact flash is still every material's `next_pass`).
- `tests/test_humanoid_rig.gd`: `material_override as StandardMaterial3D` and `.albedo_color` became `_albedo(material)`, the `albedo` uniform (the colors are the same, so "4 to 6 flat colors" and the trouser and hand checks stand); `test_flash_is_white_emission_per_rig` reads `flash_color`/`flash_amount`.
- `tests/test_vfx.gd`: nothing read the rig's materials once the damage-look tests moved, so nothing changed there.

## 3. What was measured and seen

Measured (windowed, Metal, M1; scratch scenes, not committed):
- *Hull width.* 1280x720 (2.5 px expected at 3.75 px 1080p), a sphere at 1, 2.5, 5, 10, 20 m: 2.85, 2.34, 2.06, 2.06, 1.34 px; the same for a cylinder. A box at 1 m read 4.1 px (an off-axis box's near corner also moves toward the lens, which a wide field of view stretches; curved parts do not). At 1600x900 (3.12 px expected): 3.52, 2.97, 2.76, 2.60, 1.14 px. At 20 m the line is thinner by design (far 12 m). So 1080p-equivalents of 4.2, 3.6, 3.3, 3.1 at 1-10 m: inside the bible's 3.5-4 px at 1-3 m and 2 px or more to 10 m, never past 4.5 on curved parts.
- *Shadows.* 8,516 shadow pixels with no hull; 8,514 with a 3.75 px hull; 8,387 with 40 px; with the guard removed 12,802 (C7).
- *Cracks.* A 14 px hull on boxes, cylinders and spheres at five distances showed no cracks at corners or rims.

Looked at, first person (captures/after against captures/before, same act and frame; "before" is the S0 base 42d56bd run from a scratch copy of this tree):
- *Primitive Punk at 1 m and 3 m.* Even ink line at 3 px (1600x900), three bands on the arms and legs (lit, mid and a violet-tinted shadow side), a stepped rim on the shoulder, one small hard highlight each on the cap and the fists. The shading reads as cel-shaded where the M3 Punk read as soft CG.
- *Dummies and two Punks at 1-3 m.* The same on the orange dummies; the street's shadows and the far building read violet (the tint is strong on the environment: it is the bible's 45%; F-look and P1-post tune the room's colors).
- *Hit and damage.* The contact flash and the burst on a jab; the bruised and bloodied marks on the toon materials look like M3's (the triplanar's axes differ a little); the parry flash covers the body in cyan with the marks showing through and the hull on top.
- *The player's own limbs* (looking 20 degrees down, a jab coming in). The forearm in three bands (lit peach, tan, a pink shadow side), white wraps with a lilac shadow side, the fist with its hull at 0.8 of the Punk's line; no heavy line, and no hull from the hidden head, chest or shoulders reaches the lens.
- *Halftone on* (live, through the registry): dots in the shadow bands of the room and of both Punks' fronts, 6 px cells; off by default.
- *The art fixture* (palette, mask stripe, hull, bent, marked, flashed): the hull is even all round and follows the bent tip, the marks sit on the swatches with alpha 1 and not on the dark top, the mask's ink stripe shows on every swatch.

## 4. Not done, or for someone else

- The crates, dumpster and car have no hull until the room calls `ToonMaterials.environment(color, true)` for them (C3).
- The first-hour edge-mask probe is P1-post's (A8); here only the tag's value is set (C2). It is not known yet whether the toon fragment's `ROUGHNESS` reaches the normal-roughness buffer.
- The art path is seen only on the fixture. The real Punk's COLOR and CUSTOM channels, and Tripo's meshes' hull evenness, are SL-int's first look.
- Damage on the art's skin (C10), and the per-region gloss (leather, studs: the glossy factor is per material today).
- Perf: a hull is one extra draw per mesh (about 41 per primitive character, 45 for the player); the slice gate measures it (A7, A16).
