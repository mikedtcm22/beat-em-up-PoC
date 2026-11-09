# Gemini ledger (the video's look-dev targets)

Game-boy's cap: **$5** in all (D2, 2026-11-08), through `tools/gemini_image.py` only. `tools/gemini_image.py` keeps no ledger and runs four jobs at once, so a row goes in **before** each batch, and its actual result after. Stop before a batch would take the running total past $5.

**Price used:** about $0.14 an image for `gemini-3-pro-image` at 2K: about $0.134 for the output image, plus about $0.001 for each of the three input images and the prompt. That's the published rate for 1K-2K output when this ledger was started; check it again if the totals matter.

| When (CST) | Batch | Jobs | Estimate | Result | Running total (estimated) |
| --- | --- | --- | --- | --- | --- |
| 2026-11-08 15:05 | Gate 1 targets: the six stills repainted (`make_paintover_jobs.py`, gemini-3-pro-image, 2K, 16:9) | 6 | $0.84 | 6 images, all ok (JPEG, 2K) | $0.84 |
| 2026-11-08 15:50 | Gate 1, round 2: five stills repainted with more environment detail and no glare, ref 2's first 15 s as the references (`make_paintover_jobs.py --env`) | 5 | $0.70 | 5 images, all ok (JPEG, 2K) | $1.54 |
| 2026-11-08 (round 3) | LD-WORLD3 backdrops, batch 1: street far skyline x2, roofs far skyline x2, boss sky/fire/smoke x3 (`make_matte_jobs.py`, gemini-3-pro-image, 2K; round 3 cap $2.50) | 7 | $0.98 | 7 images, all ok (JPEG, 2K) | $2.52 |
| 2026-11-09 04:18 | **Approval, no spend:** Game-boy by Slack DM, "Extra $2 for Gemini use is approved if needed", for per-shot background paint-overs (R5-PAINT: a paint-over of each trailer shot's background, projected onto the set). Used only if round 4 still reads 3D; at most $2, so the total stays at most $4.52 | 0 | $0 | - | $2.52 |
| 2026-11-09 (round 5) | **R5-PAINT pilot, take 1:** two plates, street_wide (swatch ref2_42.0) and roof_silhouette (swatch ref2_50.5), blockout + one swatch each, `tools/video/make_plate.sh` (gemini-3-pro-image, 2K, 16:9). Round 5 cap: the approved $2 (about 10 images); the pilot is at most 4 images (two retakes), about $0.56 | 2 | $0.28 | 2 images, both ok (JPEG, 2K) | $2.80 |
