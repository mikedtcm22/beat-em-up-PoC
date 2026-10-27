# M4 reader: Tripo and Gemini toolchain reference (key `tripo-gemini`)

Written 2026-10-26 by a reader (no tracked file touched, no commit, no Tripo task created, no credits spent, no Gemini image generated). Everything here is tagged **[RAN]** (I ran it against the live service or Godot), **[DOC]** (read from official docs, quoted or paraphrased) or **[INF]** (my inference, unverified). Official docs were read as raw Markdown: both Tripo doc hosts serve every page at `/en/docs/<id>.md` and `llms.txt` / `llms-full.txt`; copies of the pages the pipeline needs are in `/private/tmp/claude-501/-Users-arachne-repos-beat-em-up-PoC/097d610a-a8fb-4633-bbe9-6486aed195e7/scratchpad/m4-read-tripo-gemini/docs-raw/*.md` (scratch, untracked; 19 files).

## 0. Read this first (things that change the plan)

1. **The Tripo API in the handoff (`api.tripo3d.ai/v2/openapi`) is being shut down.** The official SDK page says "The v2 API is scheduled to shut down on 2026-10-31" [DOC, sdk.md]. Today is 2026-10-26. The current API is **v3**, and for our key (a *global* account) the base URL is **`https://openapi.tripo3d.ai/v3`** [RAN: `GET /v3/account/balance` returned `{"code":0,"status":"success","data":{"balance":1500.00,"frozen":0.00}}`]. Our key is rejected by the China hosts: `openapi.tripo3d.com/v3` returns 401 `{"code":2,"message":"Invalid API key"}` and `api.tripo3d.com/v2/openapi` returns 401 `1002` [RAN]. `api.tripo3d.ai/v3` is a 404 [RAN]. Use only `openapi.tripo3d.ai/v3`. The global doc host is `developers.tripo3d.ai` (USD, 1 credit = $0.01 [DOC]); `developers.tripo3d.com` is the China mirror (CNY) with identical content apart from host names. `platform.tripo3d.ai/docs` is a JavaScript single-page app that cannot be fetched as text and documents only the old v2 API.
2. **v2 and v3 are different request shapes.** v2 is one `POST /v2/openapi/task` with a `type` field; v3 has one endpoint per capability and one unified `input` field (a `task_id`, a `file_token` or a public URL). The v3 mapping is in section 2.4. Do not write pipeline scripts against v2.
3. **Credit costs are low for H-series generation and high for P-series.** H3.1 image or multiview to 3D costs 20 credits untextured, 30 with standard texture; P1 and P2 cost 100 to 130 per task [DOC, section 2.5]. Rigging is 25, each preset animation 10, rig-check is free. A full "generate, rig, 5 animations" run is about 105 credits, so 800 credits fit roughly 13 fully rigged attempts (55 each, animations reserved at the end) or about 23 generations plus one rig plus 5 animations (section 4).
4. **Generated file URLs expire after 5 minutes** ("Model URLs expire after 5 minutes. Download immediately after the task succeeds", quick-start page [DOC]). Download inside the same script run, with **no Authorization header** on the download request (SDK page: "No API key is sent to the download host").
5. **Tripo does not document its rig's bone names, bone count, hierarchy or rest orientation** anywhere I could reach (section 5). The only handle is the `spec` option; `unity` is documented as "Unity Humanoid bone naming", and Godot's `SkeletonProfileHumanoid` uses exactly the Unity HumanBodyBones naming [RAN, section 5.1], so `spec: "unity"` is the best bet for a zero-effort Godot BoneMap. That is unverified until one real rig exists; the first spend should therefore include one rig and a bone-name dump (section 7).
6. **Gemini:** all three model ids named in the handoff exist exactly as written, plus newer ones; generation via `generateContent` with `responseModalities` and `imageConfig` is supported and the lead's scratch script already uses that shape (section 3). Per-image price is $0.04 to $0.13, so concept and view sheets cost a few dollars at most.

## 1. What I ran

| Check | Result |
| --- | --- |
| `GET https://openapi.tripo3d.ai/v3/account/balance` (key read from `.env` inside the script, never printed) | 200, balance 1500.00, frozen 0.00 |
| `GET https://openapi.tripo3d.ai/v3/account/usage` | 200, `data: []` (no tasks ever run) |
| `GET https://api.tripo3d.ai/v2/openapi/user/balance` (the old v2 route, still live today) | 200, `{"code":0,"data":{"balance":1500,"frozen":0}}` |
| Same key on `openapi.tripo3d.com/v3`, `api.tripo3d.com/v2` | 401 both; on `api.tripo3d.ai/v3` 404 |
| `GET /v3/tasks/task_doesnotexist` and `POST /v3/tasks/list` with a bogus id | 400 `1004` "invalid task_id: expected UUID format" (so real task ids are UUIDs; the docs' `task_abc123` is only an example) |
| Gemini `GET /v1beta/models` (header `x-goog-api-key`, paged) | 60 models; image ids in section 3.1 |
| Gemini `GET https://generativelanguage.googleapis.com/$discovery/rest?version=v1beta` (public, no key) | schemas for `GenerationConfig`, `ImageConfig`, `ThinkingConfig`, `Part`, `Blob` read exactly (section 3.2) |
| Gemini `countTokens` with `generateContentRequest` incl. `imageConfig` for 4 models | 200 each, but `countTokens` does not validate image config, so it proves only that the model ids exist |
| Godot 4.7.2 headless script printing `SkeletonProfileHumanoid` | 56 bones, names and T-pose reference listed in section 5.1 |

Not run, on purpose: any Tripo task (including free `rig-check`, which is a task), `POST /v3/files` upload (not listed in the price table, so probably free, but it creates server-side state), any Gemini `generateContent` image call (costs money).

## 2. Tripo API v3

### 2.1 Host, auth, envelope, errors

- Base `https://openapi.tripo3d.ai/v3`. Header `Authorization: Bearer <TRIPO_API_KEY>` (key prefix `tsk_`, present in `.env` [RAN]). JSON bodies need `Content-Type: application/json`. [DOC authentication.md]
- Success envelope `{"code":0,"status":"success","data":{...}}` [RAN for balance]. Error envelope `{"code":N,"status":"error","message":...,"suggestion":...,"request_id":...}`.
- HTTP codes [DOC error-handling.md]: 400 bad parameter, 401 key, 403 permission or **credits**, 404, 429 rate or concurrency, 500. Error codes: `1000` invalid key, `1001` unauthorized, `1004` invalid parameter (also returned for option combinations such as `texture_quality=fast` on an old texture model, `smart_uv` on retopology v1/v2), `1007` rate limit, `2000` concurrency limit exceeded (header `Retry-After`), `2002` unsupported parameter, `2003` empty file, `2004` unsupported file type, `2008` content-policy violation, `2010` insufficient credits, `2015` version deprecated, `2018` model too complex.
- Numbers `credits_consumed`, `balance`, `frozen` are **floats** with two decimals; never `int()` them [DOC changelog "Documentation correction (2026-08)"].
- Rate limits are per API key (headers `X-RateLimit-Limit/Remaining/Reset`; 429 code `1007`). Concurrency is per account and per category, default 10 each except P-series 5 and Image generation **1** [DOC rate-limits.md]: 3D generation H = 10, 3D generation P = 5, Image generation (text-to-image, image-to-image, image-to-multiview, edit-multiview) = 1, Animation (rig-check, rig, retarget) = 10, Model processing (texture, convert, refine) = 5, Mesh operations (segment, complete, retopology) = 10. Docs advise 1 to 2 s polling and backoff 1, 2, 4 ... 32 s.

### 2.2 Files (uploading our Gemini images)

- `POST /v3/files`, `multipart/form-data`, field `file`. Images JPEG or PNG, max 20 MB; models GLB, GLTF, FBX, OBJ, STL, max 150 MB. Returns `{"code":0,"data":{"file_token":"file_..."}}`. [DOC files.md]
- `POST /v3/files/presign` with `{"format":"png"}` returns `presigned_url` (HTTP PUT, no auth, 30 min) and `file_token`; meant for files over 60 MB, accepts jpeg, jpg, png, webp, bmp, tiff and model formats incl. 3mf, usdz. [DOC files-presign.md]
- No price is listed for uploads. A task `input` can also be a public URL, but our images are local, so upload them. `input` takes exactly one of `task_id`, `file_token`, URL; never mix.
- Model files given as `file_token` or URL are imported and normalized first; the task output then carries `normalize_scale` (`final size = original size x normalize_scale`). It is **not** returned for `task_id` inputs. [DOC task-query.md, models-import.md]

### 2.3 Task lifecycle, polling, download

- Every generation, processing and animation call returns `{"code":0,"data":{"task_id":"..."}}`. Poll `GET /v3/tasks/{task_id}` (or `POST /v3/tasks/list` with `{"task_ids":[...]}`, max 100; response `{tasks:{id:{...}}, missed:[...]}`). [DOC]
- Statuses: `queued` (progress 0), `running` (0-100), `success` (output present, 100), `failed`, `cancelled`, `banned` (content policy), `expired` (output gone). Task fields: `task_id, type, status, progress, error_code, error_message, output, credits_consumed, created_at, completed_at`.
- Credits are frozen at creation, consumed on success, returned on failure or cancel ("failed and cancelled tasks are not charged"). `GET /v3/account/balance` shows `balance` and `frozen`; `GET /v3/account/usage` lists per-task `credits_consumed`. [DOC billing.md; balance and usage RAN]
- Output keys: `output.model_url` (GLB for generation, rig and retarget; FBX if `quad` or `out_format=fbx`), `output.rendered_image_url` (preview PNG or WebP), for `mesh/uv` also `uv_render_url`; image-to-multiview returns `front_view_url, left_view_url, back_view_url, right_view_url`; image-to-image returns `generated_image_url`; rig-check returns `output.riggable` (bool) and `output.rig_type`; **batch retarget returns `output.model_urls` (plural)** per the quick-start page, so the script must accept either key. [DOC]
- Typical durations: generation 10 to 120 s, rig about 30 s, retarget about 5 s [DOC]. Use a 20-minute poll timeout (the SDK default).

### 2.4 Task catalogue (v3 endpoints, options, v2 type names)

v2 type to v3 route [DOC changelog.md]: `image_to_model` -> `POST /generation/image-to-model`; `multiview_to_model` -> `/generation/multiview-to-model`; `text_to_model` -> `/generation/text-to-model`; `text_to_image` -> `/generation/text-to-image`; `generate_image` -> `/generation/image-to-image`; `generate_multiview_image` -> `/generation/image-to-multiview`; `edit_multiview_image` -> `/generation/edit-multiview`; `texture_model` -> `/models/texture`; `convert_model` -> `/models/convert`; `import_model` -> `/models/import`; `animate_prerigcheck` -> `/animations/rig-check`; `animate_rig` -> `/animations/rig`; `animate_retarget` -> `/animations/retarget`; `mesh_segmentation` -> `/mesh/segment`; `mesh_completion` -> `/mesh/complete`; `highpoly_to_lowpoly` -> `/mesh/decimate`; new `/mesh/uv`, `/mesh/smartsegment`, `/generation/image-to-splat`. **`refine_model` and `stylize_model` are retired** (SDK 1.0 raises instead of sending; no docs page): there is no stylize task to use.

**Model ids** [DOC models-and-versions.md]: `v3.1-20260211` (H3.1, default, "AAA production"), `v3.0-20250812` (H3.0), `v2.5-20250123` (H2.5), `P2-20260801` (P2 Preview, native quad, 48-50,000 tris or 48-25,000 quads), `P1-20260311` (P1, 50-20,000 faces). The P series is selected only by setting `model`; an omitted `model` runs H3.1.

**`POST /generation/image-to-model`** (H series) [DOC generation-image-to-model/standard.md]:

| Option | Type, default, values |
| --- | --- |
| `input` (required) | file_token, public URL, or task_id of a text-to-image/image-to-image task. PNG/JPEG/WebP, max 20 MB, at least 256 px |
| `model` | `v3.1-20260211` default; `v3.0-20250812`; `v2.5-20250123` |
| `enable_image_autofix` | bool, false: AI-completes and enhances low-quality input |
| `texture_alignment` | `original_image` (default, match input colours) or `geometry` |
| `orientation` | `default` or `align_image` (align model to the image viewpoint; only with `texture: true`) |
| `face_limit` | int; omitted = adaptive. Upper limits: v3.1 1,500,000 (2,000,000 with `geometry_quality=detailed`), v3.0 1,000,000 (2,000,000 ultra), v2.5 500,000; `quad` 150,000. With `smart_low_poly`: 500-20,000 tris (500-10,000 quads). "Game-ready: 50,000-100,000" |
| `texture` / `pbr` | bool, both default **true**; `pbr: true` forces `texture: true`; PBR = base_color, metallic, roughness, normal |
| `texture_quality` | `standard` (default), `detailed`, `extreme` (8K), `fast` (only with `texture_version=v3.5-20260815`, same cost as standard; any other texture version returns 1004) |
| `texture_version` | `v3.5-20260815` (newest; required for `fast` and `delight`), `v3.0-20250812` (default for v3.x and P series), `v2.5-20250123` |
| `delight` | bool, true: removes baked-in lighting from the reference before texturing; **read only by texture v3.5** |
| `geometry_quality` | `standard` or `detailed` ("Ultra", finer geometry); v3.0+ only |
| `auto_size` | bool, false: scale to real-world metres |
| `quad` | bool, false: quad mesh, **forces FBX output**; default 10,000 faces if no `face_limit` |
| `smart_low_poly` | bool, false: hand-made-style clean topology; "best for simple inputs, complex models may occasionally fail" |
| `generate_parts` | bool, false: segmented parts; needs `texture=false` and `pbr=false` (otherwise 1004) |
| `compress` | `geometry` = meshopt compression (v3.0+). **Avoid** unless Godot and Blender import is proven |
| `export_orientation` | `+x` (default), `-x`, `+y`, `-y` forward axis. **Leave unset** if the model will be rigged, textured or converted: "post-processing may produce a wrongly-oriented result while the task still reports success"; convert orientation in the last step via `/models/convert` |
| `model_seed` / `texture_seed` | ints; same seed + same input = same mesh / same texture. Keep `model_seed`, vary `texture_seed` to re-texture the same geometry |
| `export_uv` | bool, true; false = faster and smaller, UVs made at texturing |

P-series (`P1-20260311`, `P2-20260801`) takes the same input plus `model_seed, face_limit (P1 50-20,000; P2 48-50,000 tris or 48-25,000 quads), texture, pbr, texture_quality, texture_version, delight, auto_size, export_uv, export_orientation, orientation, texture_alignment`, and `quad` for P2 only. It has no `geometry_quality`, `smart_low_poly`, `generate_parts`, `compress`. "Simple models start from 150 faces, complex from 250." [DOC generation-image-to-model/p.md]

**`POST /generation/multiview-to-model`**: same options as image-to-model, but `inputs` replaces `input`, with three formats (use one): (a) **view-key** array of single-key objects, keys `front`, `left`, `back`, `right` (values URL, file_token, `{url}`, `{file_token}`); order is irrelevant, the server canonicalises to [front, left, back, right]; (b) legacy positional 4-string array `[front, left, back, right]` with `""` to skip; (c) `[{"task_id":"..."}]` reusing an `image-to-multiview` or `edit-multiview` task. **`front` is mandatory, at least 2 images, same object and consistent lighting**, PNG/JPEG/WebP, at least 256 px. The docs do not say whether `left` means the character's left side or the camera's left; see section 7. [DOC generation-multiview-to-model/standard.md, .../p.md]

**`POST /models/texture`** (re-texture an existing model): `input` (task_id, file_token, URL), `model` (texture model: `v3.5-20260815`, `v3.0-20250812` default, `v2.5-20250123`), `texture_prompt` (object: exactly one of `text`, `image`, `images` (view-key or 4-positional); `style_image` may accompany `text`), `pbr` (true), `texture_seed`, `texture_alignment`, `texture_quality` (standard, detailed, extreme, fast), `part_names`, `compress`, `bake` (true), `delight` (true; v3.5 only). It is "strongly recommended" to re-supply the reference image when texturing from a `task_id`. [DOC models-texture.md]

**`POST /models/convert`**: `input`, `format` (required: GLTF, FBX, USDZ, OBJ, STL, 3MF), `quad`, `force_symmetry` (quad only), `face_limit` (omitted = keep original count), `flatten_bottom`, `flatten_bottom_threshold` (0.01), `texture_size` (4096), `texture_format` (JPEG default; PNG, WEBP, BMP, DPX, HDR, OPEN_EXR, TARGA, TIFF), `bake` (true), `pack_uv` (false), `export_vertex_colors` (OBJ/GLTF only), `pivot_to_center_bottom`, `scale_factor`, `with_animation` (true: keep skeleton and animation), `animate_in_place`, `part_names`, `export_orientation`, `fbx_preset` (`blender` default, `3dsmax`, `mixamo`, `bake_scale`). Any non-default value of quad, face_limit, flatten_bottom(_threshold), texture_size, texture_format, pivot_to_center_bottom, scale_factor bills as "Advanced convert" (10 instead of 5). [DOC models-convert.md, pricing]

**`POST /mesh/decimate`** (retopology): `input`, `model` (`v2.0` default smart; `v3.0` newest; `v1.0` basic), `face_limit` (v3.0: 500-20,000 tris or 500-10,000 quads), `quad`, `smart_uv` (**v3.0 only**, no extra cost; v1/v2 return 1004), `bake` (true; not v1.0), `part_names`. **`POST /mesh/uv`** (Smart UV): re-unwraps UVs and remaps existing textures, rigging and animation; input at most 80,000 equivalent triangles (larger fails and refunds); output also has `uv_render_url`. `POST /mesh/segment`, `/mesh/smartsegment`, `/mesh/complete` (`completion_mode` `ai_completion` or `quick_cap`) are not needed for M4.

**`POST /animations/rig-check`**: `input` (task_id, file_token, URL; GLB, FBX, OBJ, STL, max 150 MB). Output `riggable` (bool) and `rig_type` (biped, quadruped, hexapod, octopod, avian, serpentine, aquatic). Free. A task, with its own `task_id` (poll it). [DOC animations-rig-check.md]

**`POST /animations/rig`**: `input`; `model` (`v1.0-20240301` is the **default**, biped only, 90+ presets; `v2.5-20260210` for non-humanoids; `v3.0-20260909` "recommended for humanoid characters: faster, higher-quality humanoid rigging", must be requested explicitly); `rig_type` (biped default; also `others` on v3.0); `spec` (`tripo` default, `mixamo`, and `actorcore`, `unity`, `unreal`, `vrm`; **only takes effect for biped**); `out_format` (`glb` default, `fbx`). Measured compatibility by the SDK authors on 2026-10-15 [DOC, tripo-python-sdk docs/API.md]: `tripo`, `mixamo`, `actorcore` work on every rig version; `unity`, `unreal`, `vrm` need `v2.5-20260210` or `v3.0-20260909` and **fail on v1.0**; v3.0 handles humanoid and `others`; v1.0 is biped only. (The docs page itself lists `actorcore` as v3.0 only; trust the SDK measurement.) 25 credits. [DOC animations-rig.md]

**`POST /animations/retarget`**: `input` = the **rig task_id** (not the generation task); `animation` (one preset) **or** `animations` (array, max 5; more is an error); `out_format` (glb, fbx); `export_with_geometry` (true; false returns animation and skeleton without the mesh, which the SDK example uses [INF that the skeleton is kept]); `animate_in_place` (false; a third-party skill reports it can corrupt the bake, unverified, so try it on walk and run and compare, or strip root motion in Blender); `bake_animation` is deprecated and ignored. The retarget algorithm "has been replaced in place with a faster, higher-quality version" (no version bump). Presets must match the rig version [DOC animations-retarget.md]:

- Rig v2.5 or v3.0 (16 presets): biped `preset:idle`, `preset:walk`, `preset:run`, `preset:dive`, `preset:climb`, `preset:jump`, `preset:slash`, `preset:shoot`, `preset:hurt`, `preset:fall`, `preset:turn`; others `preset:quadruped:walk`, `preset:hexapod:walk`, `preset:octopod:walk`, `preset:serpentine:march`, `preset:aquatic:march`.
- Rig v1.0 (all `preset:biped:` + name; 90+): afraid, agree, angry_01-03, basketball_shot, bow, **box_01, box_02, box_03**, cast_a_spell, cheer, chop, clap, climb, complain_01-02, cross_body_crunch, crossover_dribble, cry, dance_01-06, defeat_02, defeat_03, depressed, dig, dive, dribble, **fall**, fire, flee_01-02, flip, fold_arms, football_catch/save/pass, freaky, **front_kick_01, front_kick_02**, frightened, frustrated_01-02, golf, greet_01-04, heart_pose, **hit_to_body_01, hit_to_body_02, hit_to_head, hit_to_side, hit_to_stomach**, hug, **hurt**, **idle**, jump_down, jump, jump_rope_01-02, laugh_01-02, lift_heavy, look_around, make_a_call_01-02, pitch_baseball, play_mobile_game, play_video_game, press-up, run_upstairs, **run**, scared_01-02, scratch, shoot, shovel, sing_01-04, sit, slash, sob, standing_relax, surf, swagger, swim, **turn**, victory_celebration, volleyball, **wait**, **walk**, warm_up, wave_goodbye_01-02.

**Image tasks on Tripo (not needed, Gemini does this)**: `POST /generation/image-to-image` (models seedream_v5 default, banana, banana_pro, banana2, chat_image_2, chat_image_2.5_flare, chat_image_2.5_sunburst; `template` `t_pose`, `character_completion`, `3d_enhance`, `variants`, `figure`; up to 4 refs seedream, 10 banana, 16 chat_image) and `POST /generation/image-to-multiview` (input an image, returns four views, 10 credits). `3d_enhance` and `t_pose` are a cheap (5 to 10 credits) fallback if a Gemini concept is a poor reconstruction input; `chat_image_1` retired 2026-10-23, `chat_image_1.5` retires 2026-12-01. [DOC]

### 2.5 Credit costs (official pricing table, global site, 1 credit = $0.01; the same numbers as the China site) [DOC developers.tripo3d.ai/en/pricing, models/v3-1, models/p1, models/p2, changelog]

| Operation | Credits |
| --- | --- |
| Text to 3D (H) | 10 no texture, 20 standard, 30 detailed (+10), 40 8K (+20) |
| **Image to 3D and Multiview to 3D (H3.1/3.0/2.5)** | **20 no texture, 30 standard, 40 detailed, 50 8K** |
| Add-ons (H only, stack on the base) | detailed geometry +20, quad +5, smart low-poly +10, generate parts +20 |
| P1 and P2, any of text/image/multiview | 100 no texture, 110 standard, 120 detailed, 130 8K (no geometry-quality, smart-low-poly or parts add-ons) |
| Texture task | fast 10, standard 10, HD 20, 8K 30 |
| Format convert | basic 5; advanced 10 |
| Retopology (`/mesh/decimate`) | v3.0 triangles 35, v3.0 quads 40, v2.0 30, v1.0 10 |
| Smart UV | 20 |
| Segmentation 40; part completion 50 (quick cap 30); smart segmentation 85 (image) / 55 (model) | |
| **Rig-check** | **free** |
| **Auto rig (any version, any spec)** | **25** ("Credits are unchanged" for v3.0) |
| **Animation retarget** | **10 per animation** (batch = 10 x count, max 5 per task) |
| Image generation on Tripo | seedream 5; banana 5; banana2 10/10/15 (1K/2K/4K); banana_pro 15/15/20; chat_image_2 10/10/15 (high 20/25/40) |
| Image to multiview | 10; edit multiview 5 per edited image |

Unstated: the cost of `texture_version=v3.5-20260815` on generation (the docs only say `fast` costs the same as `standard`); the cost of file upload (assume 0); whether `pbr` changes the price (the table shows only the texture level). Read `credits_consumed` and the balance after every task and log them. Credit packs: $50, $100, $250 or any amount from $1; 100 credits = $1.00, so our 1,500 credits = $15, the 800-credit allowance = $8.

### 2.6 A minimal, safe script skeleton (stdlib only; reads the key itself, never prints it)

```python
import json, os, time, urllib.request, urllib.error
BASE = "https://openapi.tripo3d.ai/v3"
def _key():
    for line in open("/Users/arachne/repos/beat-em-up-PoC/.env"):
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
KEY = _key()
def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    h = {"Authorization": "Bearer " + KEY, "User-Agent": "beat-em-up-poc/1.0"}
    if data: h["Content-Type"] = "application/json"
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(BASE + path, data, h, method=method), timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(int(e.headers.get("Retry-After", 2 ** attempt))); continue
            raise RuntimeError(f"HTTP {e.code} {e.read()[:300]!r}")    # message text only, no headers
def balance(): return call("GET", "/account/balance")["data"]
def wait(task_id, timeout=1200, every=2):
    t0 = time.time()
    while time.time() - t0 < timeout:
        t = call("GET", f"/tasks/{task_id}")["data"]
        if t["status"] == "success": return t
        if t["status"] in ("failed", "cancelled", "banned", "expired"):
            raise RuntimeError(f"{task_id} {t['status']} {t.get('error_code')} {t.get('error_message')}")
        time.sleep(every)
    raise TimeoutError(task_id)
def download(url, path):   # signed URL: no Authorization header, URL dies in 5 min
    urllib.request.urlretrieve(url, path)
```

Guard rails worth building in: a `--dry-run` that prints the body and the expected cost; read the balance before and after each task and append `{task_id, type, options, credits_consumed, balance_after}` to a ledger file under `docs/` or `assets/source/` (the 800-credit allowance, i.e. stop at balance < 700); download the GLB and preview immediately after `success`; keep every `task_id` (rig and retarget need the generation or rig task id, and old tasks may reach `expired`, lifetime unstated).

## 3. Gemini image generation

### 3.1 Model ids [RAN: `GET /v1beta/models`]

| Model id | Display name | Notes |
| --- | --- | --- |
| `gemini-3-pro-image` (alias `gemini-3-pro-image-preview`, `nano-banana-pro-preview`) | Nano Banana Pro | in 131,072 / out 32,768 tokens; thinking model; the premium, most prompt-faithful model; 1K, 2K, 4K |
| `gemini-3.1-flash-image` (alias `-preview`) | Nano Banana 2 | in 65,536 / out 65,536; thinking; 512, 1K, 2K, 4K |
| `gemini-2.5-flash-image` | Nano Banana | in 32,768 / out 32,768; legacy: the pricing page says it "will be shut down on October 2, 2026" while the models page says 2.5 models "will continue to be served until further notice, access limited to users who used them in the past"; it is still listed today |
| `gemini-nano-banana-2.1` | Nano Banana 2.1 | newest, the docs' "primary high-efficiency model", stable; 1K, 2K, 4K |
| `gemini-3.1-flash-lite-image` | Nano Banana 2 Lite | cheapest; 1K only; "not optimized for multiple reference inputs or multi-turn editing" |

All five list `generateContent`, `countTokens`, `batchGenerateContent` [RAN]. The `imageSize` and reference limits are from the docs, not run.

### 3.2 The generateContent request (what the lead's scratch script uses) [RAN schema via discovery doc; DOC for limits]

`POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`, headers `x-goog-api-key: <key>` (never put the key in the URL) and `Content-Type: application/json`:

```json
{
  "contents": [{"role": "user", "parts": [
      {"text": "<prompt>"},
      {"inline_data": {"mime_type": "image/png", "data": "<base64, no data: prefix>"}}   // 0..14 reference images
  ]}],
  "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"],            // ["IMAGE"] is allowed; the set must match a supported combination
      "imageConfig": {"aspectRatio": "3:4", "imageSize": "2K"},
      "thinkingConfig": {"thinkingLevel": "HIGH"}         // optional; MINIMAL | LOW | MEDIUM | HIGH; Gemini 3+ only
  }
}
```

- `ImageConfig` [RAN, discovery]: `imageSize` supports `512`, `1K`, `2K`, `4K` (**uppercase K required**; default `1K`); `aspectRatio` supports `1:1, 1:4, 4:1, 1:8, 8:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9` (if omitted, the model picks one from the reference images). An error is returned if `imageConfig` is set for a model that does not support it. The docs say per model: Pro 1K/2K/4K, 3.1 Flash 512/1K/2K/4K, Lite 1K only; the extreme ratios 1:4, 4:1, 1:8, 8:1 are documented only for some models (use 1:1, 3:4, 4:3, 2:3, 3:2, 16:9 for safety). The docs give no pixel table; 1K 1:1 is about 1024 x 1024 and long edges at 2K are about 2048.
- Response [DOC]: `candidates[0].content.parts[]`; each image part is `{"inlineData":{"mimeType":"image/png","data":"<base64>"}}` (decode `data`); text parts and, for thinking models, parts with `thought: true` and a `thoughtSignature` may appear (up to two interim "thought images"; thought images are not charged; the last image is the final one). Always iterate all parts and take the **last** image part. When no image arrives, log `candidates[0].finishReason`: `IMAGE_SAFETY`, `IMAGE_PROHIBITED_CONTENT`, `IMAGE_OTHER`, `IMAGE_RECITATION`, `NO_IMAGE`, `PROHIBITED_CONTENT`, `SAFETY`, `OTHER`; `promptFeedback.blockReason` covers blocked prompts. Retry once with a softer prompt; these are not charged as images when nothing is produced [INF].
- All outputs carry an invisible SynthID watermark [DOC]. Gemini 3 image models always think (cannot be disabled); thinking tokens are billed.
- **The current docs page documents a different endpoint**, the Interactions API (`POST /v1beta/interactions`, `response_format: {type:"image", aspect_ratio, image_size}`, `previous_interaction_id` for multi-turn). `generateContent` is still listed for every image model and is what the lead's `/private/tmp/.../scratchpad/gemini_gen.py` uses; its output sheets (`m4_street_punk_concepts.jpg`, `m4_hero_arms_legs_concepts.jpg`) exist, which is strong evidence the shape works end to end. Prefer `generateContent`; if Google removes it, port to Interactions.
- Reference images: up to **14 in total** for the Nano Banana family; per model [DOC, table cells were flattened, so inferred from column order, verify]: object images 3 Pro up to 6, 3.1 Flash and 2.1 up to 10, Lite up to 14; character-consistency images 3 Pro up to 5, 3.1 Flash and 2.1 up to 4; style references 3 Pro up to 3. Inline image data counts toward a **20 MB total request** (use the Files API above that); PNG, JPEG, WebP, HEIC, HEIF accepted; the docs advise putting the text prompt before a single image.
- Rate limits are per project, tiered by spend (Tier 1 = billing linked); free tier has **no** image models [DOC pricing]. IPM (images per minute) exists but the numbers are not published. The lead's script runs 4 workers in parallel. Batch API: 50% price, up to 24 h turnaround.

### 3.3 Price per image [DOC ai.google.dev/gemini-api/docs/pricing, standard tier]

| Model | per image |
| --- | --- |
| `gemini-3-pro-image` | $0.134 at 1K or 2K; $0.24 at 4K |
| `gemini-3.1-flash-image` | $0.045 at 512; $0.067 at 1K; $0.101 at 2K; $0.151 at 4K |
| `gemini-nano-banana-2.1` | $0.0336 at 1K; $0.0504 at 2K; $0.113 at 4K |
| `gemini-3.1-flash-lite-image` | $0.0336 at 1K |
| `gemini-2.5-flash-image` | $0.039 (up to 1024 x 1024) |

Input tokens are extra but tiny (Pro: $2 per million, 560 tokens per input image). Budget: 4 Punk views plus 3 retries on Pro at 2K is about $1; the whole M4 image spend should stay under $5. Output terms: Google claims no ownership of generated content; do not use outputs to build competing models; attribution may be required by law [DOC ai.google.dev/gemini-api/terms].

### 3.4 Prompt guidance: orthographic A-pose views that reconstruct well

Google's own templates [DOC]: stylized illustration "A [style] of a [subject, with details about accessories or actions] doing [activity]. The design features [visual qualities, e.g., bold outlines, cel-shading] and [color/background preference]"; editing "Using the provided image, change only the [element]... Keep everything else exactly the same, preserving the original style, lighting, and composition"; "be specific about the visual detail (bold lines, colors, etc.) for consistent results"; "for edits, state what must stay the same". The docs have no character-sheet recipe; what follows is my synthesis, partly from Tripo's reconstruction advice ("T-pose, A-pose or relaxed neutral pose with visible limbs", plain non-reflective background that contrasts with the subject, even light, whole body in frame, resolution 2048 or above [Tripo blog, third-party summaries]) and not tested here.

What Tripo's reconstruction needs from each image: one figure, full body with margin, hands open with separated fingers (no fists, nothing held), both feet fully visible, neutral A-pose (arms about 35 to 45 degrees from the body, legs parallel), flat even light with **no cast shadow and no rim light**, a plain flat background that differs in colour from every garment (a similar-coloured background made decorations read as holes in one report), the same height and framing in every view, and no text, labels, grids or extra views.

Workflow that keeps the character consistent: (1) the concept stage already exists (front A-pose, 3:4, 2K, flat light-grey background); after Game-boy's pick, (2) one `generateContent` call **per view** with the picked concept as the first reference image and, for each later view, also the previously accepted views, because a single "turnaround sheet" in one image cannot be fed to Tripo without cropping and gives inconsistent scale; the sheet is good only as a human review image. Generate: front (clean re-render of the concept so the front input is exactly orthographic), back, left side, and optionally right side. Use `gemini-3-pro-image`, `imageSize: "2K"`, `aspectRatio: "3:4"` (Tripo recommends at least 256 px, ideally 2048 on the long side). Template:

```
Reference image(s): the character concept [and the already approved views]. Redraw the SAME character from the reference, with an identical
design, outfit, colours, proportions, accessories and face covering, as a strictly ORTHOGRAPHIC {FRONT | BACK | LEFT-SIDE | RIGHT-SIDE} view
for 3D modelling: no perspective, camera at chest height, the character centred, full body from the top of the head to the soles of the
shoes with a clear margin on all sides, same height and scale as the reference. Neutral A-pose: standing upright, feet shoulder-width apart
and parallel, arms straight and angled about 40 degrees down from the body, hands open with the fingers slightly separated, nothing in the
hands. Flat even lighting, no cast shadows, no rim light, flat plain light-grey background (#d9d9d9). Same cel-shaded flat-colour style with
clean ink outlines as the reference. {BACK: show the back of the same garments, invent only plausible details, no new logos.}
{LEFT-SIDE: the camera is on the character's left, so the character faces the LEFT edge of the image and we see its own left arm and leg.}
One figure only, no text, no labels, no grid, no extra views.
```

Set `responseModalities: ["IMAGE"]` to avoid commentary parts. Reject and regenerate any view whose height, foot position or colours differ visibly from the front; then run a numeric check before uploading (same image size, subject bounding box height within 3 percent across views; a 10-line Pillow or ImageMagick script).

## 4. Recommended route: picked concept to rigged GLB, with credits

All endpoints `https://openapi.tripo3d.ai/v3`. Costs are from section 2.5 (the last column is the running total if every step runs once).

| # | Step | Call and options | Credits | Running |
| --- | --- | --- | --- | --- |
| 0 | Views (Gemini, dollars not credits) | 3 to 4 views as in 3.4 | 0 | 0 |
| 1 | Upload | `POST /files` once per view -> `file_token` | 0 (unlisted) | 0 |
| 2 | Generate | `POST /generation/multiview-to-model`: `inputs` = front, left, back (+ right) as view-key objects with file_tokens; `model: "v3.1-20260211"`; `texture: true`, `pbr: false` (base colour only; the toon shader needs no PBR maps and the SPEC replaces them with palette colours anyway), `texture_quality: "standard"`, `texture_version: "v3.5-20260815"`, `delight: true` (flat albedo for toon shading), `orientation: "align_image"`, `face_limit: 20000` (enemy budget is 15k tris; trim the last 25 percent in Blender with weights preserved), fixed `model_seed`; leave `export_orientation`, `quad`, `compress`, `generate_parts` unset | 30 (expect; 40 with `texture_quality: "detailed"`; +20 for `geometry_quality: "detailed"`) | 30 |
| 3 | Inspect (free) | download `model_url` GLB and `rendered_image_url` at once; headless Blender: bounding box, facing axis, tri count, arms and hands visible, A-pose; reject early | 0 | 30 |
| 4 | Rig-check | `POST /animations/rig-check` `{"input": gen_task_id}` -> `riggable`, `rig_type` (must be `biped`) | 0 | 30 |
| 5 | Rig | `POST /animations/rig` `{"input": gen_task_id, "model": "v3.0-20260909", "rig_type": "biped", "spec": "unity", "out_format": "glb"}`; download immediately; dump bone names (section 7) before anything else | 25 | 55 |
| 6 | Animations (v3.0 presets) | `POST /animations/retarget` `{"input": rig_task_id, "animations": ["preset:idle","preset:walk","preset:run","preset:hurt","preset:fall"], "out_format": "glb", "export_with_geometry": false}` | 50 | 105 |
| 6b | Optional combat clips | second rig with `model: "v1.0-20240301"`, `spec: "mixamo"` (25), then `animations` from `preset:biped:box_01/02/03, front_kick_01/02, hit_to_head, hit_to_body_01/02, hit_to_side, hit_to_stomach, hurt, fall, idle, walk, run, turn` in batches of at most 5 (10 each, e.g. 8 clips = 80) | 25 + 80 | 210 |

Notes on the choices:

- **Multiview (3 to 4 views) over single image**: same price as image-to-model (20/30), far better back and side geometry. Fallback if the views disagree: single front image to 3D (30) or Tripo's `image-to-multiview` (10) then multiview-to-model with `[{"task_id": ...}]` (30) = 40.
- **v3.0 rig first** because it is the "recommended for humanoids" version, supports the `unity` naming and has hand bones [DOC]; its 11 biped presets contain no punch or kick (`slash` and `shoot` are the nearest). The v1.0 rig is the one with boxing, kicking and hit-reaction clips, but it cannot use the `unity`, `unreal` or `vrm` specs (use `mixamo` there). Both rigs hang off the same generation `task_id`, so the second rig costs only 25.
- **Cost-saving**: re-texture the same geometry with `POST /models/texture` (`model_seed` unchanged, new `texture_seed`, `v3.5-20260815`, `fast` or `standard` = 10 credits) instead of regenerating (30). Retopology is not needed (Blender decimate is free); Tripo's v3.0 retopology (35, `smart_uv` free in the same task) is the paid alternative for clean topology before rigging, and Tripo's rigging announcement recommends retopology before rigging a dense mesh (its example was reduced to about 18,000 faces). Do not pay for `/models/convert` unless a different format is needed; GLB comes out of rig and retarget already (`fbx_preset: "blender"` exists if FBX is wanted).
- **How many retries fit in the 800-credit allowance** (the account starts at 1,500; the lead's rule is to spend at most 800 without asking, so the ledger should stop when the balance reaches 700). "Reserve 105" means one rig plus 5 animations are kept back for the accepted model:

| Scenario | Cost each | Count in 800 | Count with 105 reserved |
| --- | --- | --- | --- |
| Generation only (std texture), judged from preview and Blender | 30 | 26 | 23 (19 if both rigs and 13 clips, 210, are reserved) |
| Generation with `texture_quality: detailed` | 40 | 20 | 17 |
| Generation with `geometry_quality: detailed` + std texture | 50 | 16 | 13 |
| Generation and rig every candidate (std texture) | 55 | 14 | 13 (reserving only the 50 for animations) |
| Generation and rig every candidate (detailed geometry) | 75 | 10 | 10 |
| Re-texture only (same geometry, `texture_seed` changed) | 10 | 80 | 69 |
| P1/P2 generation (100-130) | 110 | 7 | 6 |

  The sensible shape: one or two cheap generations (30 each, about 60), judge, optionally one detailed-geometry run (50), rig only the accepted model (25), 5 to 8 animations (50 to 80): a first accepted Punk costs 105 to 210 credits and leaves 590 or more of the 800 for iterations, including the player's arms and legs reference if that goes through the same pipeline.

## 5. What Tripo's rig gives us

### 5.1 Godot's target, measured [RAN: Godot 4.7.2 headless, `SkeletonProfileHumanoid.new()`]

`SkeletonProfileHumanoid` has **56 bones**, `root_bone = "Root"`, `scale_base_bone = "Hips"`, groups Body, Face, LeftHand, RightHand. Bone names (parent in brackets): Root, Hips[Root], Spine[Hips], Chest[Spine], UpperChest[Chest], Neck[UpperChest], Head[Neck], LeftEye/RightEye/Jaw[Head], LeftShoulder[UpperChest], LeftUpperArm[LeftShoulder], LeftLowerArm, LeftHand, then per hand ThumbMetacarpal/Proximal/Distal, Index/Middle/Ring/Little Proximal/Intermediate/Distal (15 finger bones), the Right side mirrored, LeftUpperLeg[Hips], LeftLowerLeg, LeftFoot, LeftToes and the Right side. These are exactly the Unity HumanBodyBones names. The profile's reference pose is a **T-pose** (e.g. `LeftUpperArm` reference basis X = (-1,0,0), Hips origin y = 0.75). The project's placeholder rig uses the 23-name subset Root, Hips, Spine, Chest, UpperChest, Neck, Head, L/R Shoulder, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes, origin at the feet, facing -Z, 1.8 m, rests with identity rotations and arms hanging down (docs/ARCHITECTURE.md "Humanoid rig"). `BoneMap` exposes `profile`, `get_skeleton_bone_name(profile_bone)`, `set_skeleton_bone_name(profile_bone, skeleton_bone)` and `find_profile_bone_name(skeleton_bone)` [RAN: doc dump], so a BoneMap `.tres` can be generated by script without the editor.

### 5.2 Tripo's rig

- **Documented [DOC]:** "Automatically adds a skeleton rig with weight painting"; 7 creature types (v3.0 adds `others`); about 30 s; output rigged GLB or FBX; bone naming by `spec` (Tripo native, Mixamo-compatible; v3.0 adds ActorCore, Unity Humanoid, Unreal Mannequin, VRM 1.0). Tripo's announcement says the new humanoid algorithm improves following around key joints and "adds support for hand bones"; the humanoid rig needs a T-pose or A-pose "so the arms and legs are clearly separated" [secondary source, spatialinsiders.com]. Studio says rigging costs 20 credits; the API charges 25.
- **Not documented anywhere I could reach:** the bone list, bone count, hierarchy, rest orientations, root bone, weight influence count. Reviews report: shoulders and chest "over-smoothed" (arm raises slump the mesh on broad shoulder pads), noisy jaw weights, no facial joints, no IK chains pre-set, retarget onto the Unreal mannequin "required only a minor tweak (foot bones offset)" [one independent test, strayspark.studio, 2026]. So expect biped body bones plus (v3.0) finger bones, no face bones; unverified.
- **Does it match `SkeletonProfileHumanoid`?** [INF] With `spec: "unity"` (v2.5 or v3.0 only) the names should be the Unity Humanoid set, which equals Godot's profile names for the body (Hips, Spine, Chest, UpperChest if present, Neck, Head, LeftShoulder ... LeftToes) and fingers (Thumb*, Index*, ...). That makes the BoneMap an identity map (the profile's extra `Root`, `LeftEye`, `RightEye`, `Jaw` would be unmapped, which Godot allows). With `spec: "mixamo"` the names are `mixamorig:Hips` style (Mixamo's own convention) and need a name map; with `tripo` unknown names. Rest pose is the pose of the mesh we feed in (A-pose), not the profile's T-pose, so Godot's retarget importer (`Skeleton3D > Retarget > Bone Map` with the Rest Fixer) or a one-time Blender re-rest has to normalise it. See the other readers (`m4-read-blender-godot`, `m4-read-rig-render`) for the importer and rig mechanics.
- **Skin weights after retargeting to our own skeleton:** The GLB carries skin joints and weights (glTF `JOINTS_0`, `WEIGHTS_0`) [INF from "weight painting" plus standard glTF]. Weights are bound to named bones, so if bone names map 1:1 (via a BoneMap import, or by renaming vertex groups in Blender), they follow the remap with no loss. For the placeholder code rig (23 bones, no fingers) the weights of finger bones must be merged into `LeftHand`/`RightHand` (a short Blender script: add each finger vertex group's weights into its hand group, then delete the finger groups), and any extra Tripo bones (twist, jaw, eyes) merged to their parent. Re-skinning the Punk mesh onto our own rig is possible with Blender's Data Transfer or Armature "with automatic weights" if Tripo's weights are poor. Two integration styles for the planner: (A) keep Tripo's skeleton, import with a BoneMap to the profile, and play Tripo's retargeted clips (shoulder and silhouette quality limited by Tripo's weights); (B) transfer weights to the project's own humanoid rig so the existing procedural animations (`placeholder_anims.gd`), hit flash and ragdoll keep working; B needs the Blender weight-merge step above.
- **Verification step (cheapest possible, about 55 credits, already inside the route):** after step 5, run a headless Blender script that imports the rig GLB and prints every armature bone with parent, head and tail (rest) positions, the per-vertex-group weight counts and the maximum influences per vertex. That answers the naming, hierarchy, rest-pose and weight questions in one go and decides between `unity` and `mixamo` naming and between integration A and B.

## 6. Licensing and ASSETS.md notes

- **Tripo terms** (developers.tripo3d.ai/en/terms): **paid users "generally have all rights" in Outputs** (5.2.2); on a free account "Tripo retains all rights" to Inputs and Outputs (5.2.1). No attribution is required (3.1); no exclusivity guaranteed (3.2: other users may get similar outputs); outputs may not be used to build competing services; Tripo has no obligation to store inputs or outputs (4). It is not known whether account `dev@arachnefinance.com` is a paid account (the 1,500 credits may be a trial grant); record it in ASSETS.md and ask Game-boy before ship.
- **Gemini terms**: Google claims no ownership; commercial use is allowed; SynthID is embedded in all images.
- ASSETS.md row suggestion per asset: service (Tripo v3.1-20260211 or Gemini model id), task id, date, credits used, prompts or input image paths, licence note as above.

## 7. Open questions and cheap experiments for the planner

1. **Bone names and rest pose of the Tripo rig** (section 5): decided by the first rig; run the Blender dump described there. Until then do not commit to `unity` versus `mixamo`.
2. **Which side is `left`?** The docs name views `front, left, back, right` without saying whether `left` is the character's left or the camera's left. Mitigation: first run with front, back and one side, then compare the result with the concept for mirrored details (a belt buckle, an asymmetric glove); a 30-credit experiment. If wrong, swap the labels (no regeneration of images).
3. **Cost of `texture_version: v3.5-20260815` on generation** and of `delight`: read `credits_consumed` on the first run; if it is above the standard price drop to `v3.0-20250812` (default).
4. **Does `export_with_geometry: false` on retarget keep the skeleton**, and what does `animate_in_place: true` do to the root bone? Test with a single 10-credit `preset:walk`.
5. **Retarget batch output**: one GLB per animation in `output.model_urls`, or one GLB with several animations? Log the whole `output` object.
6. **Account type** (paid or free) for licence, section 6.
7. Whether `POST /files` is free and whether tasks created from our `file_token` images may later reach `expired`; keep local copies of every GLB.
8. Gemini: one real `generateContent` smoke test per model (about $0.04 to $0.13) to confirm `imageSize: "2K"` and the aspect ratio on each id (`countTokens` does not validate); and whether `gemini-2.5-flash-image` is still served after its announced 2026-10-02 shutdown (it is listed today).
9. The v2 route the handoff cites stays up until 2026-10-31 only. Fix the HANDOFF note (balance check should use `https://openapi.tripo3d.ai/v3/account/balance`).
10. Orientation: Tripo's default `export_orientation` is `+x` and we do not know how that relates to glTF's +Z-forward convention or the project's -Z-facing rig; check the nose or toe direction in the first headless Blender dump and fix it at the Blender export step, not on Tripo's side.

## 8. Sources

Tripo (global): developers.tripo3d.ai `/en/docs/{quick-start,introduction,authentication,billing,account,task-lifecycle,task-query,task-batch-query,files,files-presign,models-and-versions,rate-limits,error-handling,changelog,sdk,migration-v2-to-v3,generation-image-to-model/standard,.../p,generation-multiview-to-model/standard,.../p,generation-image-to-image,generation-image-to-multiview,generation-edit-multiview,models-texture,models-convert,models-import,mesh-decimate,mesh-uv,mesh-complete,animations-rig-check,animations-rig,animations-retarget}`, `/en/models/{rig,animation,v3-1,p1,p2}`, `/en/pricing`, `/en/terms`; `github.com/VAST-AI-Research/tripo-python-sdk` `docs/API.md` (1.0.0, v3 route list, rig compatibility table measured 2026-10-15). Secondary: strayspark.studio "AI Auto-Rigging Showdown 2026", spatialinsiders.com Tripo rigging article, Tripo blog tips (summaries only). Gemini: ai.google.dev `/gemini-api/docs/{image-generation,pricing,models,image-understanding,rate-limits}`, `/api/generate-content`, `/gemini-api/terms`, the public REST discovery document `generativelanguage.googleapis.com/$discovery/rest?version=v1beta`, and the live `GET /v1beta/models`.
