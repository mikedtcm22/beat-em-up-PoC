# M3 codemap: Godot 4.7.2 navigation, avoidance and crowd performance (hands-on spike)

This is for the M3 builders who give enemies a navmesh and avoidance (SPEC §7, "Movement: `NavigationAgent3D` on a baked navmesh, with avoidance so enemies don't overlap", docs/SPEC.md:246) and build the 12 x 30 m crowd room. It covers:
- what the Godot 4.7.2 API actually does at runtime, measured in a standalone spike project rather than recalled;
- the exact calls that worked;
- the traps the spike hit.

Nothing in the repo uses navigation yet. A repo-wide search for `navig|navmesh|avoidance` finds only docs/SPEC.md:246, docs/HANDOFF.md:22 and unrelated UI focus-navigation comments.

## Path abbreviations used below

| Short | Absolute path |
| --- | --- |
| `DOC/` | `/private/tmp/claude-501/-Users-arachne-repos-beat-em-up-PoC/d761797e-9cb1-4f02-bcab-6d8ac443a839/scratchpad/navspike/doc/doc/classes/` (the 4.7.2 class reference from `godot --headless --doctool <dir>`) |
| `SPIKE/` | `/private/tmp/claude-501/-Users-arachne-repos-beat-em-up-PoC/d761797e-9cb1-4f02-bcab-6d8ac443a839/scratchpad/navspike/proj/` (the spike project) |
| repo paths | relative to `/Users/arachne/repos/beat-em-up-PoC/` |

The scratchpad is session-local and may be gone when you read this. Re-dumping the docs takes about 1 s: `godot --headless --doctool <dir>`. **The dump from the official release binary has signatures only; every `<description>` is empty.** For semantics, use this file, the online docs or your own probe. The spike's key code is quoted below, so this file stands alone.

---

## 0. TL;DR: the recipe that worked (copy this)

1. **Project settings.** Add these to `project.godot` (no `[navigation]` section exists yet). They were verified through `SPIKE/override.cfg`:
   ```ini
   [navigation]

   3d/default_cell_height=0.1
   avoidance/thread_model/avoidance_use_multiple_threads=false
   world/map_use_async_iterations=false
   world/region_use_async_iterations=false
   ```
   - `avoidance_use_multiple_threads=false` makes avoidance **deterministic**. With the default `true`, three identical runs ended at three different crowd positions. With `false`, all three were identical. Single-thread avoidance is also *cheaper* at these crowd sizes (§7).
   - The two `*_async_iterations=false` settings remove a race: with them on, a navmesh assigned to a region after the region is already on the map was **never picked up in 3 of 4 runs** (§4.3). They also make the first-sync timing fixed.
   - `default_cell_height=0.1` matches the navmesh's `cell_height` (see step 2).
2. **Bake once, synchronously, in the room's `_ready()`.** Bake after building the geometry and **before** spawning actors and before adding the region to the tree:
   ```gdscript
   var navmesh := NavigationMesh.new()
   navmesh.cell_size = 0.25            # = navigation/3d/default_cell_size
   navmesh.cell_height = 0.1           # = navigation/3d/default_cell_height; keeps the float small (§3.3)
   navmesh.agent_radius = 0.5          # >= CombatActor.body_radius 0.35; a multiple of cell_size avoids a warning
   navmesh.agent_height = 1.8          # a multiple of cell_height
   navmesh.agent_max_climb = 0.2       # a multiple of cell_height
   navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
   navmesh.geometry_collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
   var source := NavigationMeshSourceGeometryData3D.new()
   NavigationServer3D.parse_source_geometry_data(navmesh, source, geometry_root)   # main thread, root in tree
   NavigationServer3D.bake_from_source_geometry_data(navmesh, source)              # synchronous, ~1.5 ms
   _drop_roof_polygons(navmesh)        # optional post-filter, §3.4
   var region := NavigationRegion3D.new()
   region.navigation_mesh = navmesh    # set BEFORE add_child
   add_child(region)
   ```
   These literals are what the spike used. In the repo they must be `@export`s or Tuning values (§9.6).
3. **Do no map query until the map has synced:** `NavigationServer3D.map_get_iteration_id(map) > 0`, or the `NavigationServer3D.map_changed` signal. Before that, queries print an `ERROR:` line, which the test runner's output check flags. They also return `(0, 0, 0)` or an empty path. Agents get their first path on physics frame 2 or 3 after the room's `_ready()` (§4).
4. **Agents: the latched pattern** (§5.2):
   - every sim tick, `nav.velocity = desired`;
   - `velocity_computed` only *stores* the safe velocity;
   - the actor moves with the stored value on its next tick, through `CombatActor._integrate()`.
   
   Don't call `move_and_slide()` from the callback. It fires after every node's `_physics_process`, including `TimeController`'s, so it would bypass hitstop and time scale.
5. **Player:** give the player a `NavigationObstacle3D` child (radius about 0.5, no vertices, no velocity needed). Without it, enemies walk straight through the player's position (0.008 m minimum distance); with it they kept 0.87 m or more (§6.3).

---

## 1. The spike: what was built and how to rerun it

`SPIKE/project.godot` copies the repo's `[physics]` section (repo `project.godot:60-64`: Jolt Physics, 60 ticks, max 8 steps per frame). Files:

| File | What it does |
| --- | --- |
| `SPIKE/main.gd` (scene `SPIKE/main.tscn`) | Builds the room in code. The lane is 30 m along X by 12 m along Z, with walls 4 m high. A 2.5 m doorway in the north wall at x 8..10.5 leads into a 3.5 x 6 m alley. Obstacles: 2 crates, a 4.2 x 1.4 x 1.9 m car, a dumpster and a pillar. Each is a `StaticBody3D` with a `CollisionShape3D` (`BoxShape3D`) and a `MeshInstance3D` (`BoxMesh`), on layer 1 (world), in the style of `test_room.gd`. It then bakes the navmesh in one of seven modes and spawns N agents: two at the lane ends, one at the alley end (behind the doorway), and others. Each agent heads for a slot on a ring around a moving "player" point, `x = 6 sin(0.4 t)`, `z = 0.8 sin(0.9 t)`. The script prints `SPIKE` metric lines and quits. |
| `SPIKE/agent.gd` | `class_name SpikeAgent extends CharacterBody3D`. Its origin is at the feet, with a capsule of r 0.35, h 1.8 centred at +0.9, exactly like `CombatActor._ensure_body()` (`game/actors/combat_actor.gd:1457-1470`). It has a `NavigationAgent3D` child and the "latched" or "callback" movement modes. |
| `SPIKE/run.sh "<args>" ...` | Runs one config per argument with `--fixed-fps 60` and prints the summary. Use bash; see gotcha G15 on zsh word splitting. |
| `SPIKE/sync.sh N "<args>" ...` | Runs each config N times and prints the physics frame when the server first had polygons and when agent 0 first had a path. |
| `SPIKE/parser_test.gd` | Shows which node types `parse_source_geometry_data` picks up, per parse mode (§3.2). |
| `SPIKE/float_test.gd` | How high the navmesh floats above the floor, by `cell_height` (§3.3). |
| `SPIKE/testroom_bake.gd` | Copies the boxes of `test_room.gd:94-126` and bakes them with default and recommended settings (§8). |
| `SPIKE/query_test.gd` | `query_path` synchronous against callback, plus `map_get_closest_point` and `map_get_random_point` (§5.5). |
| `SPIKE/dbg.gd` | A frame-by-frame path and waypoint-index dump. Found the floating-navmesh stall (§3.3). |

User args go after `--`. Each is `key=value`:
- `bake`: parse, node, manual, projected, postfilter, async or region_async;
- `ch` and `cs`: cell sizes; `mapcell=0` leaves the map's cell sizes alone;
- `async=0`: map iterations off; `rasync=0`: region iterations off;
- `avoid=0|1`, `bodies=0|1` (agents collide with each other or not), `move=latched|callback`;
- `retarget=K` (ticks between target updates), `agents=N`, `obstacle=0|1|child`;
- `ring` (m), `ar` (agent radius), `th` (time horizon), `pho` (path height offset), `filter=1` (`filter_baking_aabb`), `frames`, `log=1` (callback-order log).

Single-thread avoidance was switched on per run with an `override.cfg` beside `project.godot`:
```bash
cd SPIKE && printf '[navigation]\n\navoidance/thread_model/avoidance_use_multiple_threads=false\n' > override.cfg
./run.sh "ch=0.1 async=0 rasync=0 bake=postfilter frames=1800"; rm override.cfg
```
A 900-frame run takes about 0.5 s of wall time.

---

## 2. Key 4.7.2 APIs (signatures from the doc dump)

### 2.1 NavigationAgent3D (extends `Node`; must be a direct child of the moving `Node3D`)

| API | Signature or default | Ref |
| --- | --- | --- |
| `target_position` | `Vector3`, default `(0,0,0)`. Setting it marks the path dirty; the next `get_next_path_position()` re-queries synchronously. | DOC/NavigationAgent3D.xml:179 |
| `get_next_path_position()` | `-> Vector3`. With no path (before map sync, or finished) it returns the **parent's own position**. | DOC/NavigationAgent3D.xml:58 |
| `is_navigation_finished()` | `-> bool`. It is `true` on the very first frame, before any target is set. | DOC/NavigationAgent3D.xml:73 |
| `is_target_reached()` / `is_target_reachable()` | `-> bool`. Both use 3D distances (§3.3). | DOC/NavigationAgent3D.xml:83 / :78 |
| `get_current_navigation_path()` / `_index()` | `-> PackedVector3Array` / `-> int` | DOC/NavigationAgent3D.xml:27 / :32 |
| `get_final_position()`, `distance_to_target()`, `get_path_length()` | `-> Vector3`, `-> float`, `-> float` | DOC/NavigationAgent3D.xml:42, :10, :63 |
| `set_velocity_forced(velocity: Vector3)` | Overwrites the avoidance sim's velocity; use it on a teleport or respawn | DOC/NavigationAgent3D.xml:115 |
| `velocity` | `Vector3`. The **desired** velocity you submit to avoidance | DOC/NavigationAgent3D.xml:187 |
| `avoidance_enabled` | `bool`, **default false** | DOC/NavigationAgent3D.xml:123 |
| `avoidance_layers` / `avoidance_mask` / `avoidance_priority` | `int` 1 / `int` 1 / `float` 1.0 | DOC/NavigationAgent3D.xml:125-129 |
| `radius` | 0.5 (avoidance radius, separate from the navmesh's `agent_radius`) | DOC/NavigationAgent3D.xml:171 |
| `height` | **1.0** by default. Set it to the body height, because 2D avoidance uses the vertical overlap. | DOC/NavigationAgent3D.xml:139 |
| `max_speed` | 10.0. **Clamps the safe velocity.** Set it to at least the fastest desired speed. | DOC/NavigationAgent3D.xml:145 |
| `neighbor_distance` / `max_neighbors` | 50.0 / 10 | DOC/NavigationAgent3D.xml:149 / :143 |
| `time_horizon_agents` / `time_horizon_obstacles` | 1.0 / 0.0 | DOC/NavigationAgent3D.xml:181 / :183 |
| `use_3d_avoidance` | false (2D RVO on the XZ plane; keep it) | DOC/NavigationAgent3D.xml:185 |
| `keep_y_velocity` | true (the safe velocity keeps the submitted y) | DOC/NavigationAgent3D.xml:141 |
| `path_desired_distance` / `target_desired_distance` | **1.0 / 1.0** by default. The spike used 0.5 / 0.3. | DOC/NavigationAgent3D.xml:151 / :177 |
| `path_height_offset` | 0.0 (§3.3: subtracts from path points only) | DOC/NavigationAgent3D.xml:153 |
| `path_max_distance` | 5.0 (re-paths when pushed this far off the path) | DOC/NavigationAgent3D.xml:155 |
| `navigation_layers`, `pathfinding_algorithm`, `path_postprocessing`, `simplify_path` | defaults are fine | DOC/NavigationAgent3D.xml:147, :169, :159, :175 |
| `debug_enabled` | Engine debug draw; debug builds only (§9.4) | DOC/NavigationAgent3D.xml:131 |
| signal `velocity_computed(safe_velocity: Vector3)` | **Fires every physics frame for every avoidance-enabled agent**, after all `_physics_process` calls (§5.1) | DOC/NavigationAgent3D.xml:208 |
| signals `path_changed`, `target_reached`, `navigation_finished`, `waypoint_reached(details)`, `link_reached(details)` | `path_changed` fires on every re-target (about once per tick if you re-target every tick) | DOC/NavigationAgent3D.xml:191-217 |

### 2.2 NavigationRegion3D

| API | Signature or default | Ref |
| --- | --- | --- |
| `navigation_mesh` | `NavigationMesh`. Set it **before** `add_child` (§4.3). | DOC/NavigationRegion3D.xml:68 |
| `bake_navigation_mesh(on_thread: bool = true)` | Parses its source (by default its **own children**, `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`) and bakes. Pass `false` for synchronous. | DOC/NavigationRegion3D.xml:10 |
| `get_rid()` / `get_region_rid()` | `-> RID` (for `NavigationServer3D.region_*`) | DOC/NavigationRegion3D.xml:37 / :32 |
| `enabled`, `navigation_layers`, `enter_cost`, `travel_cost`, `use_edge_connections` | defaults are fine | DOC/NavigationRegion3D.xml:62-72 |
| signals `bake_finished`, `navigation_mesh_changed` | | DOC/NavigationRegion3D.xml:76 / :80 |

### 2.3 NavigationMesh (bake settings and the polygon list)

| API | Default | Ref |
| --- | --- | --- |
| `cell_size` / `cell_height` | 0.25 / 0.25 | DOC/NavigationMesh.xml:81 / :79 |
| `agent_radius` / `agent_height` / `agent_max_climb` / `agent_max_slope` | 0.5 / 1.5 / 0.25 / 45 | DOC/NavigationMesh.xml:75 / :69 / :71 / :73 |
| `geometry_parsed_geometry_type` | **2 = `PARSED_GEOMETRY_BOTH`** (meshes and colliders) | DOC/NavigationMesh.xml:103, constants :127-131 |
| `geometry_collision_mask` | `4294967295` (all layers) | DOC/NavigationMesh.xml:101 |
| `geometry_source_geometry_mode` / `geometry_source_group_name` | `ROOT_NODE_CHILDREN` / `&"navigation_mesh_source_group"` | DOC/NavigationMesh.xml:105 / :107, constants :135-139 |
| `filter_baking_aabb` / `filter_baking_aabb_offset` | empty / zero. **A trap; see §3.5.** | DOC/NavigationMesh.xml:91 / :93 |
| `filter_ledge_spans`, `filter_low_hanging_obstacles`, `filter_walkable_low_height_spans` | false | DOC/NavigationMesh.xml:95-99 |
| `region_min_size`, `region_merge_size`, `edge_max_error`, `vertices_per_polygon`, `sample_partition_type` | defaults are fine | DOC/NavigationMesh.xml:109-115 |
| `get_vertices()`, `get_polygon_count()`, `get_polygon(idx)`, `clear_polygons()`, `add_polygon(PackedInt32Array)`, `set_vertices()` | used by the roof post-filter | DOC/NavigationMesh.xml:49, :44, :38, :21, :10, :61 |

### 2.4 NavigationMeshSourceGeometryData3D (what the baker eats)

| API | Ref |
| --- | --- |
| `add_mesh(mesh: Mesh, xform: Transform3D)` (a `BoxMesh` works) | DOC/NavigationMeshSourceGeometryData3D.xml:17 |
| `add_faces(faces: PackedVector3Array, xform: Transform3D)` / `add_mesh_array(mesh_array: Array, xform)` | :10 / :24 |
| `add_projected_obstruction(vertices: PackedVector3Array, elevation: float, height: float, carve: bool)` | :31 |
| `get_vertices() -> PackedFloat32Array` (flat x,y,z), `get_indices()`, `get_bounds() -> AABB`, `has_data()`, `clear()`, `merge(other)` | :72, :62, :57, :77, :47, :82 |

### 2.5 NavigationServer3D (the parts that matter)

| API | Ref (DOC/NavigationServer3D.xml) |
| --- | --- |
| `parse_source_geometry_data(navigation_mesh, source_geometry_data, root_node: Node, callback := Callable())`. Main thread; `root_node` must be inside the tree. | :762 |
| `bake_from_source_geometry_data(navigation_mesh, source_geometry_data, callback := Callable())`. Synchronous. | :249 |
| `bake_from_source_geometry_data_async(...)`. Threaded; the callback ran on the main thread 1 frame later. | :257 |
| `is_baking_navigation_mesh(navigation_mesh) -> bool` | :287 |
| `map_get_iteration_id(map) -> int`. **0 until the first sync.** | :486 |
| `map_get_closest_point(map, to_point) -> Vector3`, `map_get_closest_point_to_segment(...)` | :450, :471 |
| `map_get_path(map, origin, destination, optimize: bool, navigation_layers := 1) -> PackedVector3Array` | :516 |
| `map_get_random_point(map, navigation_layers: int, uniformly: bool) -> Vector3` | :526 |
| `query_path(parameters: NavigationPathQueryParameters3D, result: NavigationPathQueryResult3D, callback := Callable())` | :771 |
| `map_get_regions(map) -> RID[]`, `map_force_update(map)` | :534, :426 |
| `map_set_use_async_iterations(map, enabled)` / `map_get_use_async_iterations(map)` | :613 / :546 |
| `region_set_use_async_iterations(region, enabled)` / `region_get_use_async_iterations(region)` | :971 / :896 |
| `region_set_navigation_mesh(region, navigation_mesh)` | :943 |
| `map_set_cell_size(map, cell_size)` / `map_set_cell_height(map, cell_height)` | :578 / :571 |
| `agent_set_avoidance_callback(agent, callback)`, `agent_set_velocity_forced(agent, velocity)` (the RID-level forms of the node API) | :123, :242 |
| signal `map_changed(map: RID)` | :1022 |
| `get_process_info(process_info)` with `INFO_POLYGON_COUNT` etc. | :281, :1041 |

The default map is `get_world_3d().navigation_map` (DOC/World3D.xml:18). `Performance.NAVIGATION_3D_POLYGON_COUNT` (DOC/Performance.xml:166) shows whether polygons reached the server. `Performance.TIME_NAVIGATION_PROCESS` (DOC/Performance.xml:66) **read 0.0 on every frame in headless `--fixed-fps` runs**, so don't use it for cost measurements (§7).

### 2.6 NavigationObstacle3D, NavigationPathQueryParameters3D and Result

| API | Ref |
| --- | --- |
| `NavigationObstacle3D.radius` (0.0), `height` (1.0), `velocity`, `vertices` (empty), `avoidance_enabled` (true), `avoidance_layers` (1), `use_3d_avoidance` (false), `affect_navigation_mesh` (false), `carve_navigation_mesh` (false) | DOC/NavigationObstacle3D.xml:51, :49, :55, :57, :43, :45, :53, :41, :47 |
| `NavigationPathQueryParameters3D.map`, `start_position`, `target_position`, `navigation_layers`, `path_postprocessing`, `simplify_path`, `metadata_flags` | DOC/NavigationPathQueryParameters3D.xml:14, :36, :38, :18, :20, :34, :16 |
| `NavigationPathQueryResult3D.path`, `path_length`, `reset()` | DOC/NavigationPathQueryResult3D.xml:17, :19, :10 |

### 2.7 Project settings (navigation)

| Setting | Default | Ref (DOC/ProjectSettings.xml) |
| --- | --- | --- |
| `navigation/3d/default_cell_size` / `default_cell_height` | 0.25 / 0.25 | :1407 / :1405 |
| `navigation/3d/default_edge_connection_margin` | 0.25 | :1409 |
| `navigation/avoidance/thread_model/avoidance_use_multiple_threads` | **true (nondeterministic)** | :1427 |
| `navigation/baking/thread_model/baking_use_multiple_threads` | true | :1431 |
| `navigation/pathfinding/max_threads` | 4 | :1435 |
| `navigation/world/map_use_async_iterations` | true | :1437 |
| `navigation/world/region_use_async_iterations` | true | :1439 |

---

## 3. Runtime baking from code-built geometry

### 3.1 Seven ways tried

All seven produce the same 47-49 polygon navmesh for the spike room.

| Mode (`bake=`) | Calls | Cost | Reliable? |
| --- | --- | --- | --- |
| `parse` (recommended base) | `parse_source_geometry_data` + `bake_from_source_geometry_data`, then `region.navigation_mesh = navmesh` and `add_child(region)` (`SPIKE/main.gd:182-193`) | 1.4-1.8 ms | Yes, 4 of 4 runs and every config |
| `postfilter` (**recommended**) | `parse`, then drop polygons whose highest vertex is above floor + step (`SPIKE/main.gd:227-246`) | about 1.7 ms | Yes |
| `node` | A `NavigationRegion3D` with the geometry as **its children**; `region.navigation_mesh = navmesh`; `region.bake_navigation_mesh(false)` (`SPIKE/main.gd:178-181`, `:109-112`) | about 1.6 ms | Yes. It forces the geometry to live under the region node. |
| `manual` | `source.add_mesh(BoxMesh, Transform3D(Basis.IDENTITY, pos))` per box, then bake (`SPIKE/main.gd:194-204`) | 1.5-2.6 ms | Yes, but it keeps a second copy of the geometry |
| `projected` (carve=false) | Floors via `add_mesh`; anything on the floor via `add_projected_obstruction(outline, bottom_y, height, false)` (`SPIKE/main.gd:205-226`) | 1.2-2.8 ms | Yes, and no roof islands at all (40 polys) |
| `async` | `bake_from_source_geometry_data_async(..., callback)`, assigning in the callback (`SPIKE/main.gd:247-254`, `:273-287`) | about 0.5 ms on the main thread | **No** with region async iterations on (§4.3) |
| `region_async` | Group-mode parse plus `region.bake_navigation_mesh(true)` (`SPIKE/main.gd:255-272`) | n/a | **No** with region async iterations on (§4.3) |

The `projected` mode with **carve=true** (no agent-radius inflation) gave 7 stuck events and a mean ring error of 1.78 m, against 0.42 m with carve=false. Never use carve=true for things agents walk around.

### 3.2 What the parser picks up

Measured by `SPIKE/parser_test.gd`. Each cell is the parsed triangle count for one object; 12 = one box.

| Node | `STATIC_COLLIDERS`, mask = world | `MESH_INSTANCES` | `BOTH` (**the default**), mask = world |
| --- | --- | --- | --- |
| `StaticBody3D` on world + box mesh | 12 | 12 | 24 (mesh and collider both, duplicated) |
| `StaticBody3D` on world, no mesh | 12 | 0 | 12 |
| `StaticBody3D` on another layer | 0 | 12 | 12 |
| `AnimatableBody3D` on world | 12 | 12 | 24 |
| `CharacterBody3D` (any layer; actors) | 0 | 12 | 12 |
| `RigidBody3D` (the `Weapon` pipe is one: `game/weapons/weapon.gd:2`) | 0 | 12 | 12 |
| `Area3D` on world | 0 | 12 | 12 |
| bare `MeshInstance3D` (paint dashes, `test_room.gd:186`) | 0 | 12 | 12 |

So `PARSED_GEOMETRY_STATIC_COLLIDERS` with `geometry_collision_mask = bit(LAYER_WORLD)` is the only setting that keeps actors, weapons, rig meshes and decals out of the bake. With the defaults, baking from the room root also bakes the player's and every enemy's rig meshes as obstacles. The `test_room` copy parsed 3804 triangles with defaults against 168 with the recommended settings (§8).

`parse_source_geometry_data` needs `root_node` inside the SceneTree. Otherwise it prints `ERROR: The root node needs to be inside the SceneTree.` and parses nothing. It is fine in a room's `_ready()`. In a SceneTree `-s` script's `_initialize()` the root isn't ready yet; defer to `process_frame`.

### 3.3 The navmesh floats above the floor, and the 3D distance checks see it

Recast puts polygons between 1 and 2 `cell_height` above the walkable surface (`SPIKE/float_test.gd`, floor top at y = 0):

| `cell_height` | 1.0 m thick floor (bottom aligned to the cell grid) | 1.1 m floor | 0.33 m floor |
| --- | --- | --- | --- |
| 0.25 (default) | **0.50** | 0.40 | 0.42 |
| 0.10 | 0.20 | 0.20 | 0.17 |
| 0.05 | 0.10 | 0.10 | 0.07 |

- **Failure seen:** with the default `cell_height` 0.25 and `path_desired_distance` 0.5, **all 6 agents stood still for the whole run** (stuck at their spawns).
  - Why: the first path point sat 0.5 m straight above the agent's feet. The waypoint advance check is 3D and needs a distance *below* `path_desired_distance`, so 0.5 never qualified. Re-targeting every tick reset the index to that point.
  - `SPIKE/dbg.gd` showed `next = (-13.0, 0.5, -4.0)` for an agent at `(-13, 0, -4)`.
- **Fix used:** `cell_height = 0.1` (a 0.2 m float), with `path_desired_distance` 0.5 and `target_desired_distance` 0.3. Both must stay above the float.
  - The map's cell height should match: `navigation/3d/default_cell_height=0.1`, or `map_set_cell_height`. In 4.7.2 no mismatch warning appeared even when they differed, but keep them equal.
- **`path_height_offset` is not a clean fix.** It subtracts from path points only.
  - With `ch` 0.25 and `pho` 0.5 the agents moved.
  - But `is_target_reachable()` reported false on 5370 of 5400 agent-frames, because the target (snapped with `map_get_closest_point`, so at y 0.5) no longer matched the offset path end.
- **Rule for AI code:** compare positions with flat XZ distances (as `SPIKE/agent.gd:76-79` does), never 3D distances against navmesh points.

### 3.4 Roof islands, and the post-filter that removes them

- **The problem.** Every box at least `2*agent_radius` wide with clear sky above becomes a walkable island on its roof. In the spike these were the car and the dumpster, 4 polygons at y 1.6-1.7.
- **Why it matters:**
  - `map_get_closest_point(map, (0, 5, 0))` returned `(2.25, 1.6, 0.0)`, **on the car roof** (`SPIKE/query_test.gd`).
  - `map_get_random_point` can return roof points.
  - From floor height the closest point is usually on the floor, but a wide vehicle could still win.
- **Fix: post-filter after baking.** Agents only ever walk on the street floor:
  ```gdscript
  ## Keeps only the polygons on the street floor: roofs of crates, cars and walls go.
  static func drop_roof_polygons(navmesh: NavigationMesh, max_floor_y: float) -> void:
  	var verts := navmesh.get_vertices()
  	var keep: Array[PackedInt32Array] = []
  	for p in navmesh.get_polygon_count():
  		var poly := navmesh.get_polygon(p)
  		var top := -INF
  		for idx in poly:
  			top = maxf(top, verts[idx].y)
  		if top < max_floor_y:
  			keep.append(poly)
  	navmesh.clear_polygons()
  	for poly in keep:
  		navmesh.add_polygon(poly)
  ```
  This is `SPIKE/main.gd:227-246`, which used `max_floor_y` 0.5. The unused vertices stay harmlessly. The result was 45 polys, no roofs, behaviour otherwise identical to `parse`.
- **Alternative: the `projected` mode** (§3.1, carve=false) never creates roofs. It needs the room to keep a list of obstacle footprints beside the physics bodies, which means two sources of truth.

### 3.5 Trap: `filter_baking_aabb` that cuts through obstacles

- **What was tried:** `filter_baking_aabb = AABB(Vector3(-16, -1, -13), Vector3(32, 1.5, 26))` (y -1..0.5), meant to drop roofs.
- **What it did:** it removed the roofs (0 polys above 0.5 m). But obstacles taller than 0.5 m were clipped into **hollow shells**: the top face falls outside the AABB and is dropped. The **floor inside the car's footprint became a walkable island**.
- **The result:**
  - `map_get_closest_point` snapped ring slots *into* the car, e.g. `(5.295, 0.2, 3.25)`;
  - 4 stuck events and 564 unreachable agent-frames.
- **Rule:** if you use the filter, its y range must contain every obstacle's full height. Use it only to trim X and Z, e.g. the street interior without the outer margin (§8).

### 3.6 Warnings to keep the log clean

The bake prints `WARNING: Property agent_radius is ceiled to cell_size voxel units and loses precision.` (nav_mesh_generator_3d.cpp:373). It does the same for `agent_height` (:367, "ceiled to cell_height") and `agent_max_climb` (:370, "floored to cell_height"). Pick values that are exact multiples:
- `agent_radius` 0.5 with `cell_size` 0.25;
- `agent_height` 1.8 and `agent_max_climb` 0.2 with `cell_height` 0.1.

---

## 4. Map sync timing and first-frame gotchas

### 4.1 Timeline

The region is baked and added in `_ready()`, which is physics frame 0. The frame numbers are `Engine.get_physics_frames()`.

| | **Defaults** (map and region async on) | Async off via runtime calls in `_ready()` (`map_set_use_async_iterations(map, false)` + `region_set_use_async_iterations(rid, false)`) | **Async off via project settings** (recommended) |
| --- | --- | --- | --- |
| In `_ready()`, after `add_child(region)` | `map_get_iteration_id` = 0, `map_get_regions().size()` = 0; `map_get_closest_point` → **ERROR** and `(0,0,0)`; `map_get_path` → `[]` | same | same |
| `map_changed` emitted on frames | 2 and 4 | 1 | 2 |
| Server polygons first > 0 | frame 3 | frame 2 | frame 2-3 |
| First non-empty agent path | **frame 5** | **frame 2** | **frame 3** |
| `velocity_computed` | every frame from frame 1 on, safe velocity `(0,0,0)` until a path exists | same | same |

The exact error text is printed once, from `nav_map_3d.cpp:197`:
```
ERROR: NavigationServer navigation map query failed because it was made before first map synchronization.
	NavigationServer 'map_changed' signal can be used to receive update notifications.
	NavigationServer 'map_get_iteration_id()' can be used to check if a map has finished its newest iteration.
```
CLAUDE.md asks test runs to be read for `ERROR`, so **guard every direct map query**:
```gdscript
var map := get_world_3d().navigation_map
if NavigationServer3D.map_get_iteration_id(map) == 0:
	return  # not synced yet: no spawn snapping, no slot validation, no map_get_path
```

### 4.2 Before the first sync, NavigationAgent3D is harmless

- `get_next_path_position()` returns the parent's own position, so the desired velocity is zero and the agent stands.
- `is_navigation_finished()` is `true` on frame 1 and `false` after a target is set.
- No error lines came from the agents themselves.

So enemies spawned in the same frame as the bake just wait 2 to 5 frames. Spawn snapping (`map_get_closest_point`) and director slot validation must wait for the sync. Otherwise every spawn lands at `(0,0,0)`.

### 4.3 Race: a navmesh assigned to a region already on the map can be lost (async iterations)

Measured with `SPIKE/sync.sh 4`, 95 frames per run:

| Config | Run 1 | Run 2 | Run 3 | Run 4 |
| --- | --- | --- | --- | --- |
| `bake=parse` (navmesh set before `add_child`) | path@5 | path@5 | path@5 | path@5 |
| `bake=async apply=direct` (region added empty, navmesh set in the bake callback) | **never** | **never** | **never** | path@7 |
| `bake=async apply=rid` (`region_set_navigation_mesh` on the RID) | never | never | never | never |
| `bake=region_async` (`region.bake_navigation_mesh(true)`) | path@5 | path@7 | **never** | **never** |
| any of the above with `rasync=0` or the project settings off | path@3-5 | path@3-5 | path@3-5 | path@3-5 |

- In the "never" runs:
  - the map stopped iterating (`map_changed` fired only once, on frame 2);
  - `Performance.NAVIGATION_3D_POLYGON_COUNT` stayed 0 for all 95 frames;
  - `map_force_update(map)` did not help.
- **Rules:**
  1. Bake synchronously and set `region.navigation_mesh` before `add_child(region)`.
  2. If anything re-bakes or swaps a navmesh at runtime (an F1 change of the agent radius, an arena barrier), turn region async iterations off, either in the project setting or with `NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)` (DOC/NavigationServer3D.xml:971).

---

## 5. Agents

### 5.1 When `velocity_computed` fires

From the `log=1` order log, frames 1-4, two agents plus a priority-1000 node like `TimeController` (`game/autoload/time_controller.gd:90`):
```
agent0._physics_process f=1 seq=1
agent1._physics_process f=1 seq=2
main._physics_process (process_physics_priority 1000) f=1 seq=3
agent0.velocity_computed f=1 seq=4
agent1.velocity_computed f=1 seq=5
```
- The callback runs in the same physics frame, **after every node's `_physics_process`**, including priority-1000 nodes, so after `TimeController` expires hitstops.
- It fires every frame for each avoidance-enabled agent: 899 times in 900 frames, also while the safe velocity is zero.

### 5.2 Movement pattern that fits CombatActor (the "latched" mode)

`CombatActor` moves exactly once per physics frame:
- `_physics_process()` → `_sim_tick()` ×N → `_tick_control()` (`game/actors/combat_actor.gd:163`, `:563`);
- then `_integrate()`, which sets `velocity = (sim_velocity + lunge) * scale` and calls `move_and_slide()` (`combat_actor.gd:1297-1310`).

Calling `move_and_slide()` from `velocity_computed` (the Godot docs' pattern, spike `move=callback`) would:
- move the enemy a second time per frame;
- move it after `TimeController`;
- skip the time scale.

Use the latched pattern instead. It adds one tick of latency, and the measured crowd quality was identical to `callback` (min pair 0.924 against 0.925, slot error 0.546 against 0.543):
```gdscript
# Sketch for an enemy class extending CombatActor (all numbers from Tuning.data):
var _nav: NavigationAgent3D
var _safe_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	super()
	_nav = NavigationAgent3D.new()
	_nav.avoidance_enabled = true
	_nav.radius = Tuning.data.enemy_avoid_radius_m          # e.g. 0.45 (>= body_radius 0.35)
	_nav.height = body_height
	_nav.max_speed = Tuning.data.enemy_max_speed_mps        # >= every desired speed or the output is clamped
	_nav.path_desired_distance = Tuning.data.enemy_waypoint_reach_m   # 0.5 (> navmesh float)
	_nav.target_desired_distance = Tuning.data.enemy_slot_reach_m     # 0.3 (> navmesh float)
	_nav.neighbor_distance = Tuning.data.enemy_avoid_neighbor_m       # 6
	_nav.time_horizon_agents = Tuning.data.enemy_avoid_horizon_s      # 0.75
	add_child(_nav)
	_nav.velocity_computed.connect(func(v: Vector3) -> void: _safe_velocity = v)

func _tick_control() -> void:   # once per sim tick, inside _sim_tick()
	if state == CombatTypes.ActorState.FREE and _wants_to_move():
		var next := _nav.get_next_path_position()           # re-queries if target_position changed
		var flat := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
		var desired := flat.normalized() * _move_speed() if flat.length() > Tuning.data.enemy_arrive_epsilon_m else Vector3.ZERO
		_nav.velocity = desired                               # answered after all _physics_process
		sim_velocity.x = _safe_velocity.x                     # last tick's answer
		sim_velocity.z = _safe_velocity.z
	else:
		# Knockback, hitstun, attacks: tell neighbours the truth so they steer around it.
		_nav.velocity = Vector3(sim_velocity.x, 0.0, sim_velocity.z)
```
Under hitstop no sim tick runs, so `_tick_control()` is skipped and `_nav.velocity` keeps its last value. Submit `Vector3.ZERO` from `_physics_process()` when `ticks == 0` if neighbours should treat the frozen enemy as stopped. This was not measured; the effect is small.

### 5.3 Targets: ring slots

- Snap every slot onto the navmesh, only after the sync:
  ```gdscript
  _nav.target_position = NavigationServer3D.map_get_closest_point(map, slot)
  ```
  (`SPIKE/main.gd:378`). A slot inside a car or wall then becomes the nearest reachable edge point.
- Snapped points are at navmesh height (floor + about 0.2 m). That is fine with `target_desired_distance` 0.3.
- Re-targeting every tick costs one synchronous path query per agent per tick (about 4.5 µs each, §7) and fires `path_changed` every tick.
- Re-targeting every 6 ticks (staggered per agent) cut `path_changed` from about 905 to about 150 per 900 frames. The mean slot error went from 0.546 to 0.585 m.
- **Pockets.** A slot snapped into an inner corner of the L-shaped crate pair left one agent with less than 0.3 m of progress per second while 2.4 m from its slot. That was one stuck event per 1800 frames in most configs.
  - The director should reject slots whose snap moved them more than some tolerance, and pick another angle.
  - It should also keep a no-progress timer that re-picks the slot.

### 5.4 Spawn points behind doorways and alleys

- The 2.5 m doorway (eroded by `agent_radius` 0.5 into a 1.5 m corridor) connected the alley. The alley-end spawn got a 12-point, 27.3 m path to the far lane end.
- A doorway narrower than `2*agent_radius` plus a cell closes completely. Keep doorways at 1.5 m or more.
- Spawn points must be at least `agent_radius` from walls, or snapped with `map_get_closest_point` after the sync.

### 5.5 Direct queries

All measured after the sync with `SPIKE/query_test.gd` and `SPIKE/main.gd:_report()`:

| Call | Result |
| --- | --- |
| `map_get_path(map, from, to, true)` | 100 calls took 454 µs (about 4.5 µs each) for the 27 m lane-to-alley path |
| `query_path(params, result)` | 100 calls took 408 µs. `result.path_length` = 27.30 m. |
| `query_path(params, result, callback)` | **Synchronous in 4.7.2:** the callback fired before `query_path` returned |
| `map_get_closest_point(map, Vector3(4, 0, 0))` (a point inside the car) | `(3.86, 0.2, 1.49)`, the floor beside the car |
| `map_get_random_point(map, 1, true)` | a floor point; can be a roof without the post-filter |

---

## 6. Avoidance (RVO) results

### 6.1 The crowd metrics

These are 6 agents and 900 frames, with ring radius 3 m (SPEC §7 posture ring 2.5-4 m). The "player" moves up to 2.4 m/s. Agent radius is 0.45 and the body capsule radius 0.35, so capsules touch at 0.70 m. The metrics are measured before each tick's re-target, from frame 240 on (settled), unless the column says all.

| Config | Min pair distance (all / settled) | Pair-frames < 0.70 m | Stuck events | Mean distance to slot |
| --- | --- | --- | --- | --- |
| Avoidance on, bodies collide (baseline, `ch=0.1`) | 0.924 / 1.060 | **0** | 0 | 0.546 |
| Avoidance on, bodies don't collide ("enemies don't block") | 0.923 / 1.060 | **0** | 0 | 0.545 |
| Avoidance off, bodies collide | 0.680 / 0.718 | 2 | 0 | 0.504 |
| Avoidance off, bodies don't collide | 0.365 / 0.516 | **25** | 0 | 0.503 |
| Avoidance on, agent radius 0.35 | 0.725 / 0.883 | 0 | 0 | 0.541 |
| Avoidance on, `time_horizon_agents` 0.25 | 0.917 | 0 | 0 | 0.540 |
| Avoidance on, `time_horizon_agents` 2.0 | 0.919 / 1.247 | 0 | 0 | 0.567 |
| **Recommended full config** (project settings, postfilter, 1800 frames) | 0.885 | 0 | 1 (the crate pocket, §5.3) | 0.437 |

- Avoidance alone, without body collision, keeps agents apart at about 2 × `NavigationAgent3D.radius`.
- Body collision alone lets capsules press together.
- Avoidance does not know about walls: there are no static avoidance obstacles unless `time_horizon_obstacles > 0` and obstacles have `vertices`. Walls are handled by the navmesh path plus `move_and_slide()`.

### 6.2 Determinism (important for the frame-timed GUT tests)

`final_positions_hash` is an md5 of all agents' final x and z after 900 frames, from three identical runs each:

| Config | Run 1 | Run 2 | Run 3 |
| --- | --- | --- | --- |
| Avoidance off | `38c03add27` | `38c03add27` | `38c03add27` |
| Avoidance on, `avoidance_use_multiple_threads=true` (default) | `29f259936b` | `7a12105998` | `71f51aa5e1` |
| Avoidance on, `avoidance_use_multiple_threads=false` | `de58648b83` | `de58648b83` | `de58648b83` |
| Avoidance on, single thread, map async **on** | `d14e0f9924` | `d14e0f9924` | `d14e0f9924` |
| Full recommended project settings | `005560f605` | `005560f605` | n/a |

Multi-threaded avoidance is nondeterministic run to run, so any test asserting enemy positions or timing would flake. Set the project setting (§0).

### 6.3 Player as an avoidance obstacle

With ring radius 0.5, agents try to stand on the player:

| Player representation | Min agent-to-player distance |
| --- | --- |
| None | **0.008 m** (they walk through the player's position) |
| `NavigationObstacle3D` (radius 0.5, height 1.8), a sibling moved each tick with `velocity` set | 0.908-0.931 |
| `NavigationObstacle3D` as a **child of the moving player node, no velocity set** | 0.871 |

- An obstacle with no `vertices` is a dynamic obstacle: `radius` plus position, followed automatically as a child.
- In the game, the player's capsule also blocks enemy bodies physically. `_set_ghost(false)` gives enemies a mask that includes `LAYER_PLAYER_BODY` (`combat_actor.gd:1442-1455`). The obstacle makes them steer around the player smoothly instead of shoving.

### 6.4 Downed, KO'd and grabbed enemies (not measured; the expected engine behaviour)

- An agent with `avoidance_enabled = false` leaves the avoidance sim.
- For a downed or KO'd enemy that ghosts its body (`_set_ghost(true)` puts it on `LAYER_DOWNED_BODY`), decide whether the living enemies should steer around it:
  - to keep it, leave avoidance on;
  - to drop it, set `avoidance_enabled = false` or `avoidance_layers = 0`.
- On KO-and-blink-off (`is_gone()`), disable avoidance or free the agent. Otherwise live enemies keep circling an invisible corpse.
- On a teleport (reset, respawn), call `set_velocity_forced(Vector3.ZERO)` in the same frame (DOC/NavigationAgent3D.xml:115).

---

## 7. Crowd performance

Whole-frame wall time in headless `--fixed-fps 60`, 1200 frames, mean of µs per frame. Everything is included: physics, avoidance, path queries, GDScript. The agents are bare capsules with no rigs, so the real enemies cost more, but the rigs dominate, not the navigation.

| Agents | Multi-thread avoidance (default) | Single-thread avoidance |
| --- | --- | --- |
| 1 | 154 | 122 |
| 6 | 219-235 | **172** |
| 6, avoidance off | n/a | 165 |
| 12 | 417-423 | 345-383 |
| 24 | 776-810 | 730 |

- Avoidance for 6 agents costs about 7 µs per frame (172 against 165).
- Path re-queries at 6 per tick are about 27 µs.
- The spike script's own per-tick work (targets, snapping) was about 9 µs.
- **The navigation budget is negligible against 16.7 ms**, and single-thread avoidance is faster at these sizes.
- The bake costs:
  - spike crowd room: 1.4-1.8 ms;
  - `test_room` copy with the recommended settings: 75 µs parse plus 1.2 ms bake;
  - `test_room` copy with the defaults: 0.6 ms plus 8.5 ms, because it parses every mesh.
- `Performance.TIME_NAVIGATION_PROCESS` and `TIME_PHYSICS_PROCESS` read 0.0 every frame in these headless runs. Measure with `Time.get_ticks_usec()` deltas instead.

---

## 8. How the crowd room should feed the baker (and what `test_room.gd` does today)

`game/level/test_room.gd` builds everything in code in `_ready()` (`:41-46`): `_build_environment()`, `_build_street()` (`:94-126`), `_spawn_actors()` (`:129-149`), then `_build_presentation()`.

- **Geometry:** `_add_box(pos, size, material)` (`:171-183`) creates a `StaticBody3D` with:
  - `collision_layer = bit(LAYER_WORLD)` and `collision_mask = 0`;
  - a `CollisionShape3D` holding a `BoxShape3D`;
  - a `MeshInstance3D` holding a `BoxMesh` (`_box_mesh()`, `:192-198`).
  
  It is added **directly to the room root** with `add_child(body)` at `:182`. Inside `_build_street()`:
  - the floor is one box `(street_length+20) × 1 × (street_width+20)` centred at y -0.5, so its top is at y 0 (`:97`). The floor spreads 10 m beyond every wall.
  - the building fronts on -Z are 5-9.5 m tall (`:104-111`);
  - the street ends (`:113-114`);
  - a **0.6 m near-side curb** at +Z (`:116`; with `agent_max_climb` 0.2 it is a wall, and the floor beyond it is a separate island);
  - 3 crates (`:118-120`).
- **Decals:** `_add_visual_box()` (`:186-189`) adds a bare `MeshInstance3D` (paint dashes at y 0.005, 0.01 thick) to the room root.
- **Actors share the parse root:** the player, the dummies and the pipe (a `RigidBody3D`) are also direct children of the room root (`:134`, `:144`, `:149`). So are cheat-spawned dummies, through `game/ui/cheat_menu.gd:202` (`host.add_child(dummy)`).

What `SPIKE/testroom_bake.gd` measured on a copy of those boxes:

| Settings | Parsed tris | Polys | Vertices outside the street (beyond the walls or curb) | Roof vertices (y > 0.5) | Cost |
| --- | --- | --- | --- | --- | --- |
| NavigationMesh defaults (BOTH, all layers, `ch` 0.25), room root as parse root | 3804 (includes a fake actor's capsule mesh and the decal) | 100 | **106** | **37** | 0.6 + 8.5 ms |
| Recommended + `filter_baking_aabb` = street interior x ±20, z ±7, y -1..0.5 | 168 | 20 | 0 | 0 | 0.08 + 1.2 ms |

The y range in the second row clips the 5 m walls, but they only bound the street, so nothing reachable becomes hollow. Check the hollow-shell trap (§3.5) if any free-standing obstacle is taller than the filter.

**Recommendations for the crowd room:**

1. **One parse root for static geometry.** Add every world `StaticBody3D` under a dedicated `Node3D` (e.g. `Geometry`), not the room root. Parse that node.
   - Or keep `_add_box()` on the room root and rely on `STATIC_COLLIDERS` plus the world mask, which ignores actors, weapons and decals anyway (§3.2).
   - The dedicated root is safer if someone ever switches to `BOTH`.
2. **Order in `_ready()`:** build the geometry, bake synchronously, add the region, then spawn actors and presentation. Spawn waves, director slot snapping and F4 enemy spawns wait for `map_get_iteration_id(map) > 0`.
3. **Floor extent.** Don't copy the test room's +20 m floor margin, or trim it with `filter_baking_aabb` on X and Z only (§3.5). Otherwise the navmesh has islands outside the walls, and `map_get_closest_point` from a spawn point outside the walls lands there.
4. **Doorways and alleys** for spawns behind the player: at least 1.5 m wide (§5.4), with an alley floor box that touches the lane floor (the spike used an alley floor box beside the lane floor, `SPIKE/main.gd:118`). Each spawn point sits on the navmesh.
5. **Roofs:** post-filter (§3.4), or keep obstacles under `2*agent_radius` wide.
6. **Training room (key back to M2):** `game/level/test_room.gd` has **no navmesh**. If F4 spawns AI enemies there, it needs the same bake. Two options:
   - put the bake in a shared helper (e.g. `game/level/nav_baker.gd`, `class_name NavBaker`, static `bake_room(geometry_root: Node3D, settings) -> NavigationRegion3D`);
   - or have the enemy fall back to a straight-line approach when `map_get_regions(map)` is empty or the path is empty.
   
   About 12 test files preload `test_room.tscn` (e.g. `tests/test_combat_integration.gd:9`). A bake adds about 1.3 ms per room instance, which is harmless.

---

## 9. Integration points and extension points in the repo

1. **`project.godot`**: add the `[navigation]` block from §0. There is no `[navigation]` section today. The main scene is at `project.godot:15`, and the crowd room replaces it.
2. **`game/actors/combat_actor.gd`** stays navigation-free. The player doesn't navigate.
   - Put the `NavigationAgent3D` in the M3 enemy class: a CombatActor subclass, as `TrainingDummy` is (`game/enemies/dummy/training_dummy.gd:2`).
   - Hooks: `_ready()` (`:145`; call `super()`), `_tick_control()` (`:563`), `reset_state()` (`:506`; call `set_velocity_forced(Vector3.ZERO)` and clear the target), `_set_ghost()` (`:1442`; avoidance on or off).
   - Velocity flows through `sim_velocity` (`:76`) into `_integrate()` (`:1297-1310`). Only FREE, ATTACK, WINDUP, AIRBORNE, DODGE, GRABBING and BLOCK are self-propelled (`_self_propelled()`, `:1327`). In knockback states the slide velocity owns the body, and the enemy should report it to avoidance (§5.2).
3. **Player obstacle:** a `NavigationObstacle3D` child of the player. The room or the director can add it at spawn, so `game/player/player.gd` doesn't have to change (§6.3).
4. **F3 debug draw** (`game/ui/debug_draw.gd`):
   - Draw each enemy's `_nav.get_current_navigation_path()` as polyline segments with the existing `_add_line(from, to, color)` (`:425`). Hook it from `_add_actor()` (`:184`) or `rebuild()` (`:147`). Add the ring slots and token owners there too.
   - Don't rely on `NavigationAgent3D.debug_enabled` or `NavigationServer3D.set_debug_enabled()`. They draw only in debug builds, and the M3 playable is an exported macOS build (docs/HANDOFF.md:14, the GitHub Release).
   - Read only; debug draw never writes simulation state.
5. **F4 cheat menu** (`game/ui/cheat_menu.gd`):
   - `spawn_dummy()` (`:189-206`) and `spawn_point()` (`:127`) use physics rays. Enemy spawns should also snap with `map_get_closest_point` after the sync.
   - New spawns are added under the room after the bake, which is fine; never re-bake with the room root as parse root and `BOTH` (§3.2).
6. **Tuning** (`game/autoload/tuning_data.gd`):
   - The groups `Enemies` (`:545`) and `Rear warning` (`:551`) exist. Feel numbers go there as `@export_range`: enemy speeds, ring radius 2.5-4, avoidance radius, time horizon, neighbour distance, slot reach and re-target interval.
   - `NavigationAgent3D` properties can be re-applied on `Tuning.changed`; the setters take effect immediately.
   - Navmesh build numbers (`cell_size`, `cell_height`, `agent_radius`, climb, the post-filter height) are level-layout numbers. Make them `@export`s on the room or baker, as `test_room.gd`'s layout exports are (`:19-35`).
   - A live F1 change to a navmesh number needs a re-bake, and with region async iterations off that is reliable (§4.3).
7. **Layers:** `CombatTypes.LAYER_WORLD` (`game/combat/combat_types.gd:60`) and `CombatTypes.bit()` (`:80`) give the navmesh `geometry_collision_mask`. Enemy bodies are on `LAYER_ENEMY_BODY` (`:62`).

---

## 10. Invariants

1. The navmesh is baked once per room, synchronously, from `StaticBody3D`s on `LAYER_WORLD` only. It is assigned before the region enters the tree.
2. No map query (`map_get_closest_point`, `map_get_path`, `map_get_random_point`, `query_path`) before `map_get_iteration_id(map) > 0`.
3. Enemies move only through `CombatActor._integrate()`. `velocity_computed` stores and never moves.
4. Every distance the AI compares against a navmesh point is flat (XZ). The navmesh floats 1-2 `cell_height` above the floor.
5. `NavigationAgent3D.max_speed` ≥ every desired speed. `radius` ≥ `body_radius`. `height` = `body_height`.
6. `navigation/avoidance/thread_model/avoidance_use_multiple_threads=false` stays, or tests stop being deterministic.
7. Simulation never reads a camera: the AI can use the player's facing (`CombatActor.get_forward()`), not the camera (CLAUDE.md layer rule). Presentation (F3 draw) reads agent paths and never writes.

---

## 11. Gotchas (numbered, each one hit or measured in the spike)

- **G1. Floating navmesh.** With the default `cell_height` 0.25 the navmesh sits 0.5 m above the floor, and agents with `path_desired_distance` 0.5 never move (§3.3).
- **G2. Queries before the first sync** print an `ERROR` once and return `(0,0,0)` or `[]`. Snapping spawns then puts every enemy at the origin (§4.1).
- **G3. The first path arrives late:** physics frame 5 with the defaults, 2-3 with async off. Tests that spawn enemies and assert movement must wait about 5 physics frames (§4.1).
- **G4. Late navmesh assignment** (async bake, `region.bake_navigation_mesh(true)`, re-bake) with region async iterations on is lost in 3 of 4 runs (§4.3).
- **G5. Default parse settings** (`PARSED_GEOMETRY_BOTH`, all layers) bake actor rigs, the pipe and paint decals as obstacles, and double-count every static box (§3.2).
- **G6. Roof islands** on crates, cars and walls catch `map_get_closest_point` from above and `map_get_random_point` (§3.4).
- **G7. `filter_baking_aabb`** whose top cuts an obstacle turns it into a hollow shell with a walkable island inside (§3.5).
- **G8. `add_projected_obstruction(..., carve=true)`** skips the agent-radius inflation, and agents scrape the obstacles: 7 stuck events (§3.1).
- **G9. Multi-threaded avoidance** (the default) is nondeterministic (§6.2).
- **G10. `velocity_computed`** fires after every `_physics_process`, including `TimeController`'s at priority 1000, every frame. Moving in it bypasses hitstop and time scale (§5.1, §5.2).
- **G11. `NavigationAgent3D` defaults are wrong for this game:**
  - `avoidance_enabled=false`;
  - `height=1.0`;
  - `max_speed=10`, which clamps safe velocities if lower than the desired speed;
  - `path_desired_distance` and `target_desired_distance` 1.0 (too coarse for 2.5-4 m posture slots);
  - `neighbor_distance=50`.
- **G12. `path_height_offset`** fixes waypoint advance but makes `is_target_reachable()` false when the target is a snapped navmesh point (§3.3).
- **G13. `parse_source_geometry_data`** needs the root in the tree. From a SceneTree script's `_initialize()` it fails with `ERROR: The root node needs to be inside the SceneTree.`
- **G14. Bake warnings** for `agent_radius`, `agent_height` or `agent_max_climb` that are not multiples of the cell sizes (§3.6).
- **G15. Spike tooling.**
  - In zsh, `godot ... -- $cfg` does not word-split `"a=1 b=2"`. Use bash, or zsh's `${=cfg}`.
  - macOS has no `timeout` command. Use Godot's `--quit-after N` as the guard against a parse-error hang. A script parse error leaves the scene scriptless and the process never quits.
  - A `match` inside a multi-line lambda passed as a call argument is a GDScript parse error ("Expected expression for match pattern"). Use a named method.
- **G16. The `--doctool` dump** from the release binary has no descriptions.
- **G17. Debug draw:** `NavigationAgent3D.debug_enabled` and the server debug draw need a debug build; the M3 playable is an export.
- **G18. Posture pockets:** a ring slot snapped into a concave obstacle corner can leave an agent stalled (§5.3). The director needs slot validation and a no-progress re-pick.

---

## 12. Conflict hot spots (files several M3 work packages will touch)

| File | Who needs it | Why |
| --- | --- | --- |
| `project.godot` | the nav, crowd-room and boss work packages, and the build/export WP | `[navigation]` block, main-scene switch (`:15`), input actions are registered in code by the `GameInput` autoload (`project.godot:23`), not in an `[input]` section |
| `game/autoload/tuning_data.gd` (`:545` Enemies, `:551` Rear warning) | AI, director, rear warning, archetypes, boss | Every work package adds `@export_range` values to the same two groups. Agree on the names up front, or give each work package its own subgroup (`@export_subgroup("Navigation")`, `("Director")`, ...). |
| The new enemy base class (e.g. `game/enemies/enemy_actor.gd`) | all archetypes and the boss, the director, the rear warning (reads wind-up) | the `NavigationAgent3D` setup and the latched movement live here once; archetypes override behaviour, not movement plumbing |
| `game/ui/debug_draw.gd` (`_add_actor()` `:184`, `rebuild()` `:147`) | nav (paths, slots), director (tokens), AI (state labels via `debug_state_text()`) | One owner should add a single "AI overlay" hook, and the others feed data through public getters |
| `game/ui/cheat_menu.gd` (`spawn_dummy()` `:189`, `_build()` `:243`) | the F4 "spawn any enemy" work package; the crowd room (spawn snapping) | the spawn list and the navmesh snap |
| `game/level/test_room.gd` | needed only if AI enemies must path in the training room (§8.6) | an optional bake call; tests preload this scene |
| The new crowd room script and a possible `game/level/nav_baker.gd` | crowd room, director (spawn points, slots), wave spawner | one owner; the director reads spawn points and the map RID |
| `game/combat/combat_types.gd` | AI and rear warning (`ActorState.WINDUP` already exists, `:43`) | new states or layers (an avoidance layer constant if downed bodies are excluded) |

---

## 13. Not measured (verify when building)

- Behaviour with the real `CombatActor` (rig, hurtboxes, hitstop, knockback) instead of capsule agents. The latched pattern is designed for it but was only run on `SpikeAgent`.
- Whether skipping `nav.velocity` on a tick keeps the old desired velocity in the RVO sim. The spike submitted every tick.
- `avoidance_enabled = false` and `avoidance_layers = 0` on downed enemies (§6.4).
- Windowed (non-headless) timing. The headless sync timing in physics frames should hold, but the async race in §4.3 may differ. The recommended settings remove it either way.
- The macOS export: no reason to differ, but run the crowd room once in the exported build.
