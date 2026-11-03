# M4 reader: Blender 5.2.2 headless and Godot 4.7.2 (clean-up, rig, import, toon shader)

Reader key `blender-godot`. Everything below marked **[V]** was verified by running it on this machine (Apple M1, 8 GB, Metal 4.0 Forward+, Blender 5.2.2 LTS, Godot 4.7.2.stable); **[R]** was read from the class reference or the project source and not run. The experiment scripts and test assets live in `/private/tmp/claude-501/-Users-arachne-repos-beat-em-up-PoC/097d610a-a8fb-4633-bbe9-6486aed195e7/scratchpad/m4-read-blender-godot/` (called `$S` below; it holds the Blender scripts, `gp/` is a scratch Godot project, `out_rig/` and `gp/out/` hold renders). Nothing in the repo was edited; the Godot runs against the repo only created git-ignored `.godot` state.

## 1. Bottom line for the plan

1. **Every step of SPEC §10 step 3 (clean-up) and the rig step can be scripted in `blender --background --python`** [V]: import, scale/apply, normals, voxel remesh, decimate, UV, palette colours, armature from a joint table, `ARMATURE_AUTO` weights, weight transfer, pose-as-rest, head split, GLB export. Only QuadriFlow is fragile (section 3.5).
2. **Do not use Godot's retarget importer (BoneMap, SkeletonProfileHumanoid) to get the Punk onto the project's rig** [V]. It rewrites bone axes to the profile's T-pose convention (49 of 56 profile bones have non-identity global orientation, Y along the bone, character facing +Z, Left at +X). The project rig is the opposite: every rest rotation identity, arms down, facing -Z, Left at -X (`placeholder_body.gd:8-16, 45-69`).
3. **Instead: take only the mesh, its vertex weights and the bind-pose joint positions from the GLB, and bind the mesh to the project's own `HumanoidRig.skeleton` with a Skin whose binds are recomputed in code** (section 6, working code). **[V]** with the real `HumanoidRig`, its procedural animations (`walk_forward`, `guard_break`, `knockdown_back`), `MODIFIER_CALLBACK_MODE_PROCESS_MANUAL` + `skeleton.advance()`, rig heights 1.8 and 2.3 m. Images: `$S/out_rig/dyn_sheet.png`, `$S/out_rig/walk_sheet.png`. Naive binding (the GLB's own Skin on the identity-rest skeleton) produces garbage [V] (`$S/gp/out/sk00000003.png`, left figure).
4. Consequence: **the Punk needs no animation clips in the GLB** (export with `export_animations=False`); the existing `PlaceholderAnims`/`PlaceholderPoses` drive the skinned mesh. SPEC §10 step 5 (Mixamo/mocap clips) is not needed for the Punk to move in M4. Tripo's auto-rig and Mixamo are only needed for their *vertex weights / joint positions*, and Blender's own `ARMATURE_AUTO` on a rig built from the project's joint table does that job headless with no external service [V].
5. The mesh may stay in an **A-pose** (40 degrees verified): the recomputed binds rotate each bone from the GLB's pose to the rig's hanging rest [V]. A T-pose (90 degrees) is untested and will pinch armpits; bake it to arms-down in Blender first (pose + apply modifier + `pose.armature_apply`, verified, section 3.8).
6. Author the character **facing +Y in Blender**, which becomes -Z in Godot (the rig's forward) [V]. The glTF-standard facing (-Y in Blender, +Z in Godot) is only needed if the retarget importer is ever used (section 5.3).
7. Toon shader, hull outline, depth/normal edge pass, LUT and a compute `CompositorEffect` all work on skinned meshes under Forward+/Metal [V] (section 8), with the exact shader code. Measured cost of the hull pass: +16-19% frame time at 900k skinned triangles; the edge quad: +3 ms at 720p on an M1.

## 2. Running things: commands and traps

| What | Command | Notes |
| --- | --- | --- |
| Blender script | `blender --background --factory-startup --python script.py -- args` | Python 3.13.13; args after `--` in `sys.argv`. numpy, bmesh, mathutils (KDTree, BVHTree) available. Empty scene: `bpy.ops.wm.read_factory_settings(use_empty=True)`. |
| Godot import | `godot --headless --path <proj> --import --quit` | ~9 s for a tiny project. Editor import path runs `EditorScenePostImport` scripts [V]. |
| Godot script | `godot --headless --path <proj> -s x.gd -- args` | `extends SceneTree`, `_initialize()` then `quit()`. **A script error before `quit()` leaves the process hanging forever** (it happened once, `ps`, `kill`). Autoloads (`TimeController`, `Tuning`) are NOT compile-time visible in `-s` mode, so scripts touching `HumanoidRig` fail with "Identifier not found: TimeController". |
| Render a still | `godot --path <proj> --write-movie out/a.png --fixed-fps 60 res://scene.tscn -- args` | Windowed (a window flashes); writes `a00000000.png...`. **Movie Maker ignored `--resolution`** (recorded the project's window size, 480x640 in the scratch project, 1600x900 in the repo). Set the project's viewport size, or accept it. Reports GPU time 0.00 on Metal. |
| Run a scene outside the repo with the repo's classes | `cd /Users/arachne/repos/beat-em-up-PoC && godot --path . --write-movie <abs>.png --fixed-fps 60 <abs path>/real_rig.tscn -- idle 70` | A `.tscn` at an absolute path outside `res://` runs, its script given by absolute path (`$S/real_rig.tscn`), and sees `HumanoidRig` and the autoloads. |
| zsh trap | quote or write literal args | zsh does not word-split `$args`; `-- $args` passed one string and silently disabled options (cost me three renders). |
| Class reference | `godot --headless --doctool <dir>` | Release builds dump **signatures only, empty descriptions**. `/private/tmp/.../scratchpad/godot-doc/doc/classes/*.xml` (810 files) and `.../modules/gltf/doc_classes/` (GLTF classes). |

## 3. Blender 5.2.2 headless (all [V] unless marked)

Shared helpers: `$S/common.py` (`g2b`, `build_body`, `build_armature`, `parent_auto`, `export_glb`, `import_glb`, `weight_summary`, `render_still`), joint table JSON `$S/joints.json` (extracted from `placeholder_body.gd` by `$S/extract_joints.py`).

### 3.1 Coordinates and the joint table
- Godot rig space (x right, y up, -z forward) to Blender: `(x, y, z) -> (x, -z, y)`; the glTF exporter (`export_yup=True`) maps Blender `(x,y,z)` to `(x,z,-y)`, so the round trip is exact. Character faces +Y in Blender = -Z in Godot (checked: shoe AABB z from -0.2 to +0.06 after Godot import).
- World joint positions at 1.8 m, from `BONE_REST` summed down the hierarchy: Hips y 0.975; Spine 1.075; Chest 1.205; UpperChest 1.335; Neck 1.485; Head 1.575; shoulders x=+-0.05 y 1.435; UpperArm x=+-0.22 y 1.425; LowerArm y 1.135; Hand y 0.865; UpperLeg x=+-0.11 y 0.925; LowerLeg 0.505; Foot 0.085; Toes (x +-0.11, y 0.035, z -0.13). Rig left = -X.
- Armature from a joint table works headless: `arm = bpy.data.armatures.new(n); obj = bpy.data.objects.new(n, arm); collection.objects.link(obj); view_layer.objects.active = obj; bpy.ops.object.mode_set(mode="EDIT")`, then `eb = arm.edit_bones.new(name); eb.head = ...; eb.tail = ...; eb.parent = ...; eb.use_connect = False`, then `mode_set(mode="OBJECT")` (`common.build_armature`, 23 bones, instant). Tail = first child's head; leaf bones extend along the parent's direction. Bone roll is irrelevant for the recommended Godot path.

### 3.2 Automatic weights, headless [V]
`bpy.ops.object.select_all(action="DESELECT"); body.select_set(True); arm.select_set(True); view_layer.objects.active = arm; bpy.ops.object.parent_set(type="ARMATURE_AUTO")` works with no context override. 0.08 s on 5k tris, 1.6-2.0 s on 85k tris; creates one vertex group per deform bone (all 23 including Root) and an `ARMATURE` modifier. Findings:
- **Interior / overlapping geometry gets no weights.** Test mesh built from overlapping capsules: 0 unweighted verts when clean, 240 of 43k after subdivision+noise, 85 of 15k after decimation. A single watertight shell (Tripo) should be better, but **always check** (`weight_summary()` in common.py) and fix: copy the weights of the nearest weighted vertex (KDTree; `exp5_misc.py`, 85 fixed -> 0 unweighted).
- **Unweighted vertices make Godot's importer add a `neutral_bone`** to the skeleton and the Skin (24 binds, 24 bones, one named `neutral_bone`); with all vertices weighted the counts stay 23/23 [V]. Fix the weights; if one slips through, map `neutral_bone` to `Root` when rebinding.
- The exporter warns "Mesh is not valid" because auto-weights sum to 1.0000002; `mesh.validate()` reports it. Run `bpy.ops.object.vertex_group_limit_total(limit=4)` then `bpy.ops.object.vertex_group_normalize_all(lock_active=False)` before export (also removes the ">4 influences" warning; Godot's default skinning is 4 weights per vertex).
- Renaming a bone (`arm.data.bones[x].name = "..."`) renames the matching vertex group on the deformed meshes; renaming only the group does not rename the bone. Use this to convert a Tripo/Mixamo skeleton's names to Godot profile names.

### 3.3 Weight transfer (Data Transfer modifier) [V]
Source = the auto-weighted dense mesh (`src`, 23 groups), target = a mesh with no groups (a voxel remesh of the same body, 19k faces):
```python
dt = tgt.modifiers.new("DT", "DATA_TRANSFER"); dt.object = src; dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}; dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
bpy.ops.object.datalayout_transfer(modifier="DT")   # creates the 23 destination groups
bpy.ops.object.modifier_apply(modifier="DT")
```
Result: 23 groups created; dominant group equals the nearest source vertex's for 90.4% of target vertices (17553/19416; the rest are boundary vertices); 227 verts (1.2%) inherited "unweighted" from the source's holes. Use it to move a Tripo-rigged mesh's weights onto the cleaned/decimated mesh (groups match by name), then run the fixes in 3.2.

### 3.4 Scale, transform, normals [V] (`exp1_geometry.py`)
- Simulated delivery: object scale 100, rotated 90 degrees about X, offset, some faces flipped. Recipe: `bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)`, then `me.transform(Matrix.Translation((-cx, -cy, -min_z)))` and `me.transform(Matrix.Scale(1.8 / (max_z - min_z), 4))` on the mesh data (feet at z=0, centred on XY, exactly 1.8 m tall: dims 1.341 x 0.308 x 1.800 on the A-pose test body). Work in mesh data, not object transforms, so nothing is left to apply.
- Flipped normals: signed volume via numpy over `loop_triangles` (positive = outward) detected the flipped left leg (0.0683 vs 0.0711 m^3); `bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False)` in edit mode fixed it.
- Blender 5.x: `Material.use_nodes = True` emits a deprecation warning but still works. glTF import also creates a stray "Icosphere" bone-shape object (pass `disable_bone_shape=True` to the importer).

### 3.5 Remesh and decimate [V]
| Operation | Call | Measured (85k-tri, 1.8 m body) |
| --- | --- | --- |
| Decimate collapse | modifier `DECIMATE`, `decimate_type="COLLAPSE"`, `ratio = target_tris / tris`, `use_collapse_triangulate=True`, then `bpy.ops.object.modifier_apply` | 85k -> 15,000 tris in 0.5 s; **vertex groups and their weights survive** (23 groups kept, weights interpolated). UV preservation not tested (do UVs after decimation). |
| Voxel remesh | `me.remesh_voxel_size = 0.012; bpy.ops.object.voxel_remesh()` | 0.12 s, 38.8k tris, one component, no holes (Euler 2); **drops UVs and vertex groups**; also merges the overlapping-capsule junk into one skin. |
| Remesh modifier | `REMESH`, modes `BLOCKS/SMOOTH/SHARP/VOXEL` | SMOOTH octree 7: 10,732 quads. |
| QuadriFlow | `bpy.ops.object.quadriflow_remesh('EXEC_DEFAULT', mode="FACES", target_faces=N)` | **Works headless on clean meshes** (sphere 0.2 s). Property is `smooth_normals` (not `use_...`). On the voxel-remeshed body it returned `CANCELLED` with "mesh needs to be manifold and have face normals that point in a consistent direction" although bmesh reported 0 non-manifold, 0 non-contiguous edges; **`dissolve_degenerate(threshold=0.0002)` + `delete_loose` + `normals_make_consistent` before it made the check pass**; then "Remeshing failed / wrong init" for target 3000 at 12 mm, success for 8000 faces (3.8 s), 3000 at 20 mm (1.1 s), 6000 at 8 mm (2.3 s). Wrap in try/except and retry with another voxel size or target. Output face count lands 5-15% under target. |
- Order that works: voxel remesh (unify) -> decimate to budget -> UV -> weights. If weights must come from Tripo's rig, Data Transfer them after the topology is final.

### 3.6 Splitting a mesh by region [V] (`exp2_pose_split.py`)
Faces whose mean Head-group weight > 0.5, then edit-mode `bpy.ops.mesh.separate(type="SELECTED")` (set `p.select` on the polygons in object mode first): 1531 of 15,000 faces became a new object; **the new object keeps all 23 vertex groups, the `ARMATURE` modifier and the parent**, the head's open boundary was 22 edges (a clean neck cut). Exported together as two skinned meshes under one skeleton: Godot imports `Body` and `Body_001` as two `MeshInstance3D` that **share one Skin resource** [V], so each can have its own `layers` (FP-hidden), material and shadow settings. `separate(type="LOOSE")` splits by connected component (41 pieces on the overlapping-capsule test mesh, i.e. only useful on clean meshes). Not tested: the shading seam at a cut (separate recalculates normals per part) and a hull outline across the cut; the smooth-normal attribute of 8.3 below fixes the hull side.

### 3.7 UVs and flat palette colours [V] (`exp4_palette.py`, `exp7_bvh.py`)
- `bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, correct_aspect=True, scale_to_bounds=False)` (0.10 s) and `bpy.ops.uv.pack_islands(margin=0.004)` (0.54 s) on 15k tris, in edit mode, headless.
- A synthetic "generated" texture (region colours x baked light x noise: 207,582 unique colours) reduced to a 6-colour palette: **k-means over texels (numpy, 0.1 s)**, or use the shared palette directly.
- Three outputs, all exported and imported in Godot:
  1. **Per-face palette atlas** (SPEC "palette atlas"): sample the texture at each face's UV centre, nearest palette index, 2 passes of a one-ring majority filter (removed 484 speckled faces of 15,000), then set all loop UVs of a face to the swatch centre `((i + 0.5) / 8, 0.5)` of an 8-swatch image (64x8 px, 8 px per swatch). Material: Image Texture, `interpolation = "Closest"`. Godot imports it as a `StandardMaterial3D` with `texture_filter = 2` (nearest with mipmaps), the glTF sampler is honoured; the albedo texture is extracted to `res://<glb>_<imagename>.png` (default `gltf/embedded_image_handling=1`). Face UVs are constant per face so mipmaps never blend swatches.
  2. **Vertex colours**: `me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")` + `export_vertex_color="ACTIVE"`; Godot gets `ARRAY_COLOR` (first colour read back as the palette value) but the material has `vertex_color_use_as_albedo = false`, so a custom/toon shader must read `COLOR`.
  3. **Posterised texture** (nearest palette colour per texel, original islands kept): 6 unique colours left; keeps crisp region borders at texel resolution and avoids the per-face jaggedness of 1.
- **Palette lookup for a retopologised mesh without Cycles baking**: `BVHTree.FromObject(high, depsgraph)`; for each low-poly face centre `loc, nrm, fi, dist = bvh.find_nearest(center)`, barycentric UV of `loc` in high face `fi` (`mathutils.geometry.barycentric_transform`), sample the original texture. 2,999-face target from the 15k textured mesh: 0.06 s, **92.1% faces matched the ground-truth region colour** (errors are border faces). Cycles baking was not tested.

### 3.8 Pose, apply as rest, exporter bind poses [V] (`exp3_pose.py`)
Pose the A-pose arms down: for each `UpperArm` pose bone `pb.matrix = Translation(p) @ Rotation(+-40 deg, 4, "Y") @ Translation(-p) @ pb.matrix` (p = `bone.head_local`; rotation about the forward axis Y; +40 right, -40 left). LeftHand centroid went from (-0.607, -0.026, 0.968) to (-0.223, -0.026, 0.826). Bake: `bpy.ops.object.modifier_apply(modifier="Armature")` on the mesh (applies the pose to the geometry), then pose mode + `bpy.ops.pose.select_all(action="SELECT"); bpy.ops.pose.armature_apply(selected=False)` (the armature's rest becomes the pose; pose bones back to identity), then re-add the `ARMATURE` modifier. Weights survive (still 85 unweighted of 15k, same as before).
How the **glTF exporter treats bind poses** (checked by importing each result in Godot and reading skeleton globals and Skin binds):
| Export | Skeleton rest in GLB | Skin binds in GLB |
| --- | --- | --- |
| armature posed, default `export_rest_position_armature=True` | A-pose (the original rest) | A-pose; the pose is ignored |
| armature posed, `export_rest_position_armature=False` | the **posed** positions (hand at x -0.22) | still the **A-pose** (hand at x -0.58): inconsistent, the mesh deforms at rest |
| pose applied as rest (above) | arms down | arms down: consistent (LeftHand bind at (-0.22, 0.865, 0)) |
Use the third, or leave the A-pose and retarget in Godot (section 6).

### 3.9 glTF/GLB export and import options
Export (`bpy.ops.export_scene.gltf`, 5.2.2 properties verified by listing): `export_format` has **no valid default, pass `"GLB"`** (else a warning and a bad format). Settings that matter here: `export_yup=True`; `export_skins=True`, `export_influence_nb=4`, `export_all_influences=False`; `export_animations=False` (the Punk needs none); `export_rest_position_armature=True` (default); `export_def_bones` (only deform bones, drops control bones) and `export_leaf_bone=False`; `export_apply=False` (the `ARMATURE` modifier must stay a modifier); `export_materials` in `EXPORT|PLACEHOLDER|VIEWPORT|NONE`; `export_vertex_color` in `MATERIAL|ACTIVE|NAME|NONE` plus `export_all_vertex_colors`; `export_attributes`; `export_texcoords`, `export_normals`, `export_tangents=False`; `export_image_format` `AUTO|JPEG|WEBP|NONE`; `export_use_gltfpack`, `export_meshopt_compression_enable`, `export_draco_mesh_compression_enable` (all off; Godot 4.7 does not need them; do not enable Draco). Sizes: 15k-tri skinned mesh with palette UVs 533 KB; 5k tris 155 KB.
Import (`bpy.ops.import_scene.gltf`): objects arrive at identity transforms (Y-up already converted), `Armature` + skinned `Body` with an `ARMATURE` modifier and one vertex group per bone, bone head positions equal the source (`LeftHand head_local (-0.58, 0.0, 0.996)`); options `bone_heuristic` (`BLENDER|TEMPERANCE|FORTUNE`), `guess_original_bind_pose=True`, `disable_bone_shape`, `import_shading`, `merge_vertices`.
FBX for Mixamo (SPEC step 4) also works headless (`bpy.ops.export_scene.fbx(filepath=..., object_types={"ARMATURE","MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True, apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y")`: 187 KB), unused for now.

## 4. What Godot 4.7.2 makes of the GLB [V]

Imported scene (editor path, `res://x.glb`): `Node3D root` > `Armature` (Node3D) > `Skeleton3D` > `MeshInstance3D` (one per exported mesh, `skeleton = NodePath("..")`). Bone names kept; bone order is Blender's (Root, Hips, LeftUpperLeg..., not the project's order). Skeleton rests carry the Blender bone-axis convention: **non-identity rotations** (LeftUpperLeg local euler (0,180,180), LeftUpperArm (-27.9,56.7,-39) in an A-pose, etc.), global positions equal the joint table. The Skin has named binds (`skins/use_named_skins=true` is the default; `get_bind_name(i)` = the bone name, `get_bind_bone(i)` = -1), bind pose = inverse of the bone's global rest in mesh space (in Blender axes). Mesh arrays: ARRAY_BONES/WEIGHTS with 4 influences per vertex, indices into the Skin's bind list (not the skeleton).
- **Runtime `GLTFDocument` differs** [V]: `doc.append_from_file(path, state); doc.generate_scene(state)` gives **unnamed** binds (`get_bind_name = ""`, `get_bind_bone(i)` = skeleton bone index) even with `state.use_named_skin_binds = true` (default false). Resolve names via the source skeleton: `names[i] = n if n != &"" else src_skel.get_bone_name(src_skin.get_bind_bone(i))`. Runtime loading from an absolute path outside `res://` works.
- Importer options seen in the `.import` file: `meshes/generate_lods=true`, `meshes/create_shadow_meshes=true`, `meshes/ensure_tangents=true`, `skins/use_named_skins=true`, `animation/import=true`, `nodes/import_as_skeleton_bones=false`, `gltf/embedded_image_handling=1` (extract textures), `gltf/texture_map_mode=1`. Consider `generate_lods=false` for characters (not tested for pops).
- `neutral_bone`: see 3.2.
- Imported mesh with all-weighted vertices: no extra bones. Skinned meshes' frustum-culling AABB follows the skeleton pose: a mesh whose rest AABB (x +-0.28) was far outside the view but whose Hips bone was moved 1.6 m into view still rendered [V] (`gp/cull_test.gd`), so no `custom_aabb` is needed for ordinary animation (still set one if a rig ever moves far from rest).
- `EditorScenePostImport` works in `--import` headless (`_post_import(scene) -> Object`, `get_source_file()`; set `import_script/path` in the `.import` file) [V].

## 5. The retarget importer (BoneMap + SkeletonProfileHumanoid) [V]

### 5.1 What the profile looks like (dumped, `$S/gp/profile.gd`)
56 bones. The project rig's 23 bones (Root, Hips, Spine, Chest, UpperChest, Neck, Head, 2x Shoulder/UpperArm/LowerArm/Hand, 2x UpperLeg/LowerLeg/Foot/Toes) are a subset; the profile adds LeftEye, RightEye, Jaw and 30 finger bones. Reference pose is a **T-pose facing +Z with Left at +X**: Hips y 0.75, LeftShoulder (+0.05, 1.15), LeftUpperArm global (+0.10, 1.15), LeftHand global (+0.60, 1.15); **49 of 56 bones have non-identity global orientation** (e.g. LeftShoulder euler (-90,-90,0), LeftLowerLeg (0,180,0)). Root bone `Root`, scale base bone `Hips`.
### 5.2 What the importer did with our GLB
`_subresources = {"nodes": {"PATH:Armature/Skeleton3D": {"retarget/bone_map": BoneMap, "retarget/bone_renamer/rename_bones": true, "retarget/bone_renamer/unique_node/make_unique": true, "retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton", "retarget/rest_fixer/apply_node_transforms": true, "retarget/rest_fixer/normalize_position_tracks": true, "retarget/rest_fixer/overwrite_axis": true, "retarget/rest_fixer/reset_all_bone_poses_after_import": true, "retarget/rest_fixer/fix_silhouette/enable": false, "retarget/rest_fixer/fix_silhouette/threshold": 15, "retarget/rest_fixer/fix_silhouette/filter": [], "retarget/remove_tracks/unmapped_bones": false, "retarget/remove_tracks/except_bone_names": []}}}` written with `ConfigFile.set_value("params", "_subresources", ...)` (`BoneMap` serialised inline) worked: skeleton renamed `GeneralSkeleton` (unique name `%GeneralSkeleton`), 23 bones, and **bone axes overwritten to the profile's** (LeftUpperArm bind euler (+90,+90,0), LeftLowerLeg (-180,0,0)), positions unchanged (the A-pose arms stay A-pose; "fix silhouette" off).
### 5.3 Facing matters for it
With the model facing -Z (our recommended Blender +Y facing) the retargeted bones point the wrong way: LeftUpperArm's child offset local `(0, -0.186, 0.222)` (negative Y, the axis flipped). Exported **facing +Z** (armature object rotated 180 degrees about Z; `ch_facing_pz.glb`), the same options give a consistent `(0, +0.186, +0.222)` [V]. So: the importer retarget needs glTF-standard facing and gives a profile-conformant skeleton, **not** the project's identity-rest skeleton. If clips from Tripo/Mixamo are ever wanted on the project rig, the data path is: sample the clip's *global bone rotations* delta from the clip's own rest, and write them as the project's local rotations (project rests are identity, so `local = parent_global_delta^-1 * global_delta`, with the pose-difference correction of section 6). `RetargetModifier3D` (members `enable`, `profile`, `use_global_pose`; flags position/rotation/scale) exists [R] but was not tried; it works through a profile and a source skeleton and would still need the project's bone axes handled.

## 6. Binding the skinned mesh to the project's rig [V]

### 6.1 Why the GLB's Skin cannot be reused
Vertex = `skeleton_global_pose(bone) * bind(bone) * vertex`, summed by weight. The GLB's binds are inverse bone-global transforms in **Blender's bone axes**; the project rig's globals are pure translations (identity rests). Using the GLB's binds therefore rotates each vertex about its joint by the GLB bone's axis rotation: shredded legs and arms, shown in `$S/gp/out/sk00000003.png` (left figure).

### 6.2 The binds that work
For each bind `b` of the GLB (name `n`, mesh-space joint position `p_n = inverse(bind).origin`): `R_n` = the shortest-arc rotation from the **rig's rest direction** (bone to its first child, in the rig's rest globals) to the **GLB's direction** (`p_child - p_n`); leaf bones take their parent's `R`. Then `bind'_n = Scale(s) * inverse(Transform3D(Basis(R_n), p_n))` with `s = rig.rig_scale()` (= height / 1.8). At the rig's rest the vertices land at `G_rig(n) * Scale(s) * R_n^-1 * (v - p_n)`: rotated about the joint from the GLB's pose to the rig's rest and scaled with the rig. A mesh already authored at the rig's rest has `R = identity`. Verified numerically (CPU skinning of the RightLowerArm-dominated vertices lands at (0.22, 1.52, -0.35) for the A-pose mesh vs (0.22, 1.55, -0.36) for the hanging mesh under the same pose) and by render.
Working code (as run in `$S/real_rig.gd`; the `neutral_bone` alias branch should also apply `Scale(s)`, I did not, harmless because only interior vertices use it):
```gdscript
func _retarget_skin(src: Skin, names: PackedStringArray, dst: Skeleton3D, s: float) -> Skin:
	var alias := {"neutral_bone": "Root"}
	var pos := {}
	for i in src.get_bind_count():
		pos[names[i]] = src.get_bind_pose(i).affine_inverse().origin
	var out := Skin.new()
	var rot := {}
	for i in src.get_bind_count():            # keep the GLB's bind ORDER: mesh vertex bone indices point into it
		var n := names[i]
		if alias.has(n):
			out.add_named_bind(alias[n], _rest_global(dst, dst.find_bone(alias[n])).affine_inverse())
			continue
		var bi := dst.find_bone(n)
		var kids := dst.get_bone_children(bi)
		var R := Quaternion.IDENTITY
		var pb: Vector3 = pos[n]
		if kids.size() > 0 and pos.has(dst.get_bone_name(kids[0])):
			var c := dst.get_bone_name(kids[0])
			var rest_dir := (_rest_global(dst, kids[0]).origin - _rest_global(dst, bi).origin).normalized()
			var src_dir := ((pos[c] as Vector3) - pb).normalized()
			if rest_dir.dot(src_dir) > -0.9999:
				R = Quaternion(rest_dir, src_dir)
		else:
			var p := dst.get_bone_parent(bi)
			if p >= 0 and rot.has(dst.get_bone_name(p)):
				R = rot[dst.get_bone_name(p)]
		rot[n] = R
		out.add_named_bind(n, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis(R), pb).affine_inverse())
	return out
```
Attach: `scene.find_children("*","MeshInstance3D")` from the loaded GLB, `remove_child`, `rig.skeleton.add_child(mi)`, `mi.transform = IDENTITY`, `mi.skeleton = NodePath("..")`, `mi.skin = _retarget_skin(...)`, hide the placeholder primitives (`m.visible = false` on `rig.find_children("*","MeshInstance3D")`). Parts that share a Skin in the GLB (head split) each need the retargeted skin (one per rig, shareable between that rig's parts).
Notes: a retargeted Skin per rig (scale differs per height); `bind_name` entries must name bones that exist in the target skeleton (unknown names are an error); `Skeleton3D.create_skin_from_rest_transforms()` [V] builds **index-based** binds (`bind_bone` = skeleton index, no names; for the project rig pure translations `inverse(rest global)`), usable only if the mesh's vertex bone indices are first remapped to the skeleton's order; the name-keeping route above avoids touching mesh arrays.

### 6.3 Real-rig verification
`$S/real_rig.gd` + `real_rig.tscn`: four real `HumanoidRig`s (placeholder, hanging mesh with a `neutral_bone` at 1.8 m, A-pose mesh at 1.8 m, hanging mesh at height 2.3 m), all playing the same procedural animation. Pose agreement frame by frame for `walk_forward` (guard stance), `guard_break` (arms flung out), `knockdown_back` (lying); the 2.3 m rig is correctly taller. Frames: `$S/out_rig/walk_sheet.png`, `$S/out_rig/dyn_sheet.png`. Update path: the rig's `skeleton.advance(step)` in manual modifier mode updates the skinned mesh.
Not verified: the ragdoll (`rig.ragdoll_start()` returned `is_ragdolling = true` but nothing visibly moved on any rig, even the placeholder, in my bare test scene (no `CombatActor`), so inconclusive); a skinned mesh follows the skeleton's final pose by construction, while the placeholder parts are Node3D followers updated by `show_visual_pose()`, so the ragdoll should need no change, but test it in the real game scene. FP-hidden handling needs one `MeshInstance3D` per hidden region (`CombatTypes.VIS_FP_HIDDEN = 2`, `layers` bit) which the Blender split (3.6) provides; `HumanoidRig._head_meshes/_body_meshes` and `_apply_layers()`, `flash_at()`'s `next_pass` on the paint materials and `set_flash()`'s emission all assume `StandardMaterial3D` parts per bone and need an adapter.

## 7. Class reference notes (signatures only; descriptions are empty in the dump) [R]
- `Skin`: `add_bind(bone: int, pose)`, `add_named_bind(name: String, pose)`, `get/set_bind_bone|name|pose(bind_index)`, `get/set_bind_count`, `clear_binds`.
- `MeshInstance3D`: `mesh`, `skeleton: NodePath`, `skin: Skin`.
- `Skeleton3D`: members `animate_physical_bones`, `modifier_callback_mode_process` (PHYSICS 0 / IDLE 1 / MANUAL 2), `motion_scale`, `show_rest_only`; `create_skin_from_rest_transforms() -> Skin`, `register_skin(skin) -> SkinReference`, `get_bone_global_rest`, `localize_rests`, `advance(delta)`, `force_update_all_bone_transforms`, `physical_bones_start_simulation`; signals `pose_updated`, `skeleton_updated`, `rest_updated`.
- `BoneMap`: `profile`, `set_skeleton_bone_name(profile_bone, skeleton_bone)`, `get_skeleton_bone_name`, `find_profile_bone_name`. `SkeletonProfile`: `bone_size`, `group_size`, `root_bone`, `scale_base_bone`, `get_reference_pose(i)`, `get_bone_tail`, `get_tail_direction`. `SkeletonProfileHumanoid` (56 bones above).
- `RetargetModifier3D` (< `SkeletonModifier3D`): `enable` (7 = all), `profile`, `use_global_pose`. `BoneAttachment3D`: `bone_name`, `bone_idx`, `use_external_skeleton`, `external_skeleton`, `override_pose`.
- `EditorScenePostImport`: `_post_import(scene: Node) -> Object`, `get_source_file()`.
- `GLTFState.use_named_skin_binds` (default false), `import_as_skeleton_bones`, `handle_binary_image_mode`; `GLTFDocument`: `append_from_file`, `append_from_buffer`, `generate_scene`, `write_to_filesystem`, `image_format`, `root_node_mode`, `texture_map_mode`.
- `GeometryInstance3D`: `material_override`, `material_overlay`, `extra_cull_margin`, `custom_aabb`, `lod_bias`, `visibility_range_begin/end/fade_mode`, `cast_shadow`. `Material`: `next_pass`, `render_priority`. `BaseMaterial3D` has `stencil_mode` (+ `stencil_color`, `stencil_outline_thickness`, `stencil_flags/compare/reference`): a built-in stencil outline mode exists in 4.7 [R, not tried] as an alternative to a hand-written hull; `vertex_color_use_as_albedo`, `vertex_color_is_srgb`, `texture_filter`.
- `Environment`: `adjustment_enabled`, `adjustment_brightness|contrast|saturation`, **`adjustment_color_correction: Texture`** (takes a `Texture3D` LUT), `glow_enabled` (off by default), `tonemap_mode`. `Texture3D` / `ImageTexture3D.create(format, w, h, d, mipmaps, data: Array[Image])`.
- `Compositor.compositor_effects: Array[CompositorEffect]`; `CompositorEffect`: `effect_callback_type` (PRE_OPAQUE 0, POST_OPAQUE 1, POST_SKY 2, PRE_TRANSPARENT 3, POST_TRANSPARENT 4), `needs_normal_roughness`, `needs_motion_vectors`, `access_resolved_color|depth`, `needs_separate_specular`.

## 8. Toon shader, hull outline, edge pass, LUT, CompositorEffect [V]
Test scene `$S/gp/shader_test.gd` / `.tscn` (args after `--`: `edges lut nooutline dbgn cfx noalpha min`); renders `$S/gp/out/sh_base00000005.png`, `sh_sheet3.png`, `sh_cfx_small.png`. Shader files in `$S/gp/`: `toon.gdshader`, `outline.gdshader`, `outline_smooth.gdshader`, `edges.gdshader`, `invert.glsl`, `invert_effect.gd`.

### 8.1 Toon `light()` on skinned meshes works
`shader_type spatial; render_mode diffuse_lambert, specular_disabled;` then `fragment()` sets `ALBEDO` from a `filter_nearest` palette atlas, and `light()` replaces lighting: `float lit = dot(NORMAL, LIGHT) * ATTENUATION;` (**ATTENUATION already includes the shadow term**), two `smoothstep` band edges (`band_1 0.28`, `band_2 0.62`, `band_soft 0.012`) choosing `mix(shadow_tint.rgb, vec3(mid_level), b1)` then `mix(.., vec3(1), b2)`, `DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI;` (Godot 4's `LIGHT_COLOR` carries energy*PI; `/ PI` is the documented Lambert convention), a hard spec `SPECULAR_LIGHT += step(spec_cut, dot(NORMAL, normalize(LIGHT + VIEW))) * ...`, and a stepped rim `step(rim_cut, pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power))` added to `DIFFUSE_LIGHT`. All values are `uniform`s with `hint_range` (SPEC: no numbers in scripts). Shadows from a `DirectionalLight3D` render on floor and via `ATTENUATION`. Tinted shadows come from the `shadow_tint` term (shadow side is never black).
### 8.2 Inverted hull on skinned meshes works; both slots work
```glsl
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;
uniform float width_m = 0.011; uniform float ref_dist = 3.0; uniform float min_scale = 0.35; uniform float max_scale = 2.5;
void vertex() {
	float dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * width_m * clamp(dist / ref_dist, min_scale, max_scale);   // world width ~ distance: roughly constant on screen, clamped
}
void fragment() { ALBEDO = ink.rgb; }
```
`VERTEX`/`NORMAL` in `vertex()` are the **skinned** values: the hull followed posed limbs (arms bent, legs raised) exactly. It worked both as `toon_material.next_pass = hull` (character 1) and as `MeshInstance3D.material_overlay = hull` (characters 2, 3) with identical results. Recommend `material_overlay` for the outline so `next_pass` stays free for the hit-flash overlay that `HumanoidRig` puts on `next_pass` (`humanoid_rig.gd:126` `_FLASH_SHADER`, `:150` `_flash_overlay`, `:516` `_show_flash_overlay`); draw order between an overlay's hull and a flash `next_pass` was not tested. The `dist/ref_dist` scaling ignores FOV: a first-person FOV change (`PROJECTION_MATRIX[1][1]`) changes screen width; fold it in if needed.
**Hard-edged meshes crack**: on a flat-shaded cube the hull's faces inflate in different directions and the outline breaks at corners; **smooth normals stored per vertex in COLOR fix it** [V] (Blender: per-position averaged face normals into a `FLOAT_COLOR` `CORNER` attribute as `n*0.5+0.5`, `export_vertex_color="ACTIVE"`; Godot `COLOR` is available in `vertex()`: `VERTEX += normalize(COLOR.rgb * 2.0 - 1.0) * width`; precision was 8-bit, fine). Tripo meshes are smooth so probably not needed; split head/neck parts and any hard-edge props are the risk. COLOR is free when palette colours come from the atlas UV. `COLOR_1` is not imported by Godot; UV2 would be the other channel (not tried).
### 8.3 Screen-space edges with a full-screen quad work (Forward+, Metal)
`QuadMesh` size 2x2 as a child of the `Camera3D`, `extra_cull_margin = 16384.0`, shader `render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, skip_vertex_transform;` with `uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;`, `depth_tex : hint_depth_texture`, `normal_tex : hint_normal_roughness_texture`; `void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }` (works with reverse-Z in 4.7). Linear depth: `vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0); v.xyz /= v.w; return -v.z;` (Vulkan/Metal convention, no `*2-1` on depth). Edge = relative depth jump of 5 taps (`threshold 0.12`) OR `1 - dot(n, n_neighbour)` of the normal texture (`0.45`), then `ALBEDO = mix(screen, ink, edge)`. The normal texture holds **view-space normals including skinned deformation** (debug render `sh_dbgn00000039.png`). The quad drew without writing `ALPHA` (a minimal shader with `ALPHA = 0.4` also worked); it appears in the transparent pass automatically when screen/depth/normal textures are read. Lines are 1 px thin at 1280x720; `line_px` widens them. Hull lines on characters plus this pass on the environment coexist.
### 8.4 Colour-grading LUT works
`env.adjustment_enabled = true; env.adjustment_color_correction = ImageTexture3D` (16x16x16 built from 16 `Image.FORMAT_RGB8` slices: `t.create(Image.FORMAT_RGB8, 16, 16, 16, false, slices)` returned OK). The grade (posterise to 4 levels, warm highlights/cool shadows) visibly shifted sky, floor and characters (`sh_sheet.png` bottom-left). Applied after the scene render, so it also grades the hull and edge lines. LUT authoring (a 3D grid or a 2D strip converted in code) is a tooling task; no bloom is on by default (`glow_enabled=false`).
### 8.5 Compute CompositorEffect works on Metal
`class_name InvertEffect extends CompositorEffect`, `effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT`, `RenderingServer.call_on_render_thread(_init_compute)` loading `res://invert.glsl` (`#[compute] #version 450`, imported by the editor as `RDShaderFile`; **load via the import, not `shader_compile_spirv_from_source`, which needs glslang and may be absent in export templates**), `_render_callback(type, render_data)` getting `render_data.get_render_scene_buffers() as RenderSceneBuffersRD`, `get_color_layer(view)`, `UniformSetCacheRD.get_cache(shader, 0, [uniform])`, push constants of `size`, dispatch `(size - 1)/8 + 1` groups. Assigned with `WorldEnvironment.compositor = Compositor` (callback fired, `internal size (1280, 720)`, image changed). It is more code than the quad; its only extra over the quad is access to a separate halftone/LUT pass with full control. Recommendation: **the quad for edges and halftone** (simple, debuggable, verified), CompositorEffect only if a pass needs compute.
### 8.6 Cost (Apple M1, 1280x720, uncapped, wall ms per frame averaged over 300 frames, 60 skinned characters of 15k triangles = 900,000 skinned triangles, directional shadow on) [V]
| Mode | ms/frame |
| --- | --- |
| `StandardMaterial3D` | 6.20 |
| toon shader only | 6.03 |
| toon + hull as `material_overlay` | 7.02 (+16%) |
| toon + hull as `next_pass` | 7.19 (+19%) |
| toon + hull + edge quad (5 depth + 5 normal taps) | 10.14 (+3.0 ms vs hull alone) |
The hull is one extra draw (about +1.0-1.2 ms per 900k triangles); the toon `light()` costs nothing measurable. 6 enemies + player is about 6 x 15k + 30k = 120k skinned triangles, far below this load. GPU timestamps read 0 on Metal (`viewport_get_measured_render_time_gpu`), so these are frame times and relative only; absolute numbers for the RTX 3060 target are unknown. The edge quad scales with pixels (about 6.7 ms extrapolated to 1080p on this M1); use fewer taps or a half-resolution pass if the 3060 target needs it.

## 9. Open questions and things not verified
1. Ragdoll with a skinned body, FP-hidden layers, hit-flash `next_pass` on a `ShaderMaterial` base, `set_flash()` emission and `DamageLook` on toon materials: untested; the rig's `StandardMaterial3D`-per-paint assumption (`humanoid_rig.gd:147` `_materials`, `:516` `_show_flash_overlay`, `:531` `DamageLook.apply`, `:723-735` `_build_materials`, `:744-750` per-part `material_override` and the head/body mesh lists) needs an adapter for a toon `ShaderMaterial` (flash uniform) if the existing flash and damage looks must keep working.
2. T-pose (90 degree) retarget quality, shoulder/armpit pinching, candy-wrapper at the elbow with real clothing; only a 40 degree A-pose on capsule limbs was tested.
3. How Tripo's auto-rig names and orients its bones and where its joints sit (covered by the Tripo reader); if names are not Godot-profile names, rename bones in Blender (3.2 renames vertex groups with them) or add an alias table to the retarget code. Joint positions in the GLB define the pivot of every bone, so a rig that disagrees with the table by more than a few cm shifts the elbow/knee pivots.
4. Hard-edge/seam handling across the head split (normals and hull), and Godot importer behaviour for `meshes/generate_lods` on skinned meshes.
5. Cycles texture bake (BVH lookup was used instead), and an actual photographic/AI texture (the test texture was synthetic: regions x lighting x noise).
6. Absolute GPU cost on the target hardware, CompositorEffect cost, hull behaviour at the first-person FOV and at distance on thin geometry (fingers).
7. QuadriFlow robustness (it needs the recipe in 3.5 and may still fail per target); the alternative is voxel remesh then Decimate, which was reliable.

## 10. Index of experiments and exact commands (all under `$S`)
Blender (run as `blender --background --factory-startup --python <file> [-- args]`):
- `props.py` list exporter/importer operator properties; `build_test.py -- apose|hang` capsule body + armature + `ARMATURE_AUTO` + GLB (`ch_apose.glb`, `ch_hang.glb`); `look_blend.py -- <blend> <png>` Workbench still.
- `exp1_geometry.py` normals, scale, decimate, voxel, weight transfer; `qf_test*.py` QuadriFlow bisection (recipe in `qf_test7.py`); `exp2_pose_split.py` 15k decimate + weights + head split (`rigged15k.blend`, `split.glb`); `exp3_pose.py` pose, apply-as-rest, exporter comparison (`e1/e2/e3_*.glb`, `applied_hang.blend`); `exp4_palette.py` UV, texture, k-means, atlas/vertex colours (`pal_atlas.glb`, `pal_vcol.glb`, `palette_atlas.png`); `exp5_misc.py` weight fix (`fixed_weights.glb`), smooth normals (`hullcube.glb`), re-import, FBX; `exp6.py` bone rename; `exp7_bvh.py` BVH palette lookup; `exp8_face.py` +Z facing GLB.
Godot (scratch project `$S/gp`, import first with `godot --headless --path $S/gp --import --quit`):
- `inspect_glb.gd -- res://x.glb` skeleton rests, Skin binds, AABB; `inspect_mat.gd` materials/colours (**crashes the process into a hang when a mesh has no UVs**, use `inspect_glb.gd`/`binds.gd`); `binds.gd` bind and bone names; `rt.gd` runtime `GLTFDocument` named-bind test; `profile.gd` profile dump; `make_import.gd [-- silhouette noaxis]` writes the BoneMap `.import`; `mkskin.gd` `create_skin_from_rest_transforms`; `post_import.gd` post-import test.
- `skin_test.gd/.tscn` naive vs retargeted vs hanging, rest and posed: `godot --path $S/gp --write-movie out/sk.png --fixed-fps 60 res://skin_test.tscn [-- front notwist]`; `diag.gd` CPU skinning check.
- Real rig: `cd /Users/arachne/repos/beat-em-up-PoC && godot --path . --write-movie $S/out_rig/x.png --fixed-fps 60 $S/real_rig.tscn -- <anim> <frames> [ragdoll]`.
- Shaders: `shader_test.tscn -- edges|lut|cfx|dbgn|nooutline`; `hull_test.tscn`; `cull_test.tscn`; `bench.tscn -- std|toon|hull_overlay|hull_nextpass|hull_edges <count>` (windowed, uncapped).
