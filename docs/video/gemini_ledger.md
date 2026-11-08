# Gemini ledger (the video's look-dev targets)

Game-boy's cap: **$5** in all (D2, 2026-11-08), through `tools/gemini_image.py` only. `tools/gemini_image.py` keeps no ledger and runs four jobs at once, so a row goes in **before** each batch, and its actual result after. Stop before a batch would take the running total past $5.

**Price used:** about $0.14 an image for `gemini-3-pro-image` at 2K: about $0.134 for the output image, plus about $0.001 for each of the three input images and the prompt. That's the published rate for 1K-2K output when this ledger was started; check it again if the totals matter.

| When (CST) | Batch | Jobs | Estimate | Result | Running total (estimated) |
| --- | --- | --- | --- | --- | --- |
| 2026-11-08 15:05 | Gate 1 targets: the six stills repainted (`make_paintover_jobs.py`, gemini-3-pro-image, 2K, 16:9) | 6 | $0.84 | 6 images, all ok (JPEG, 2K) | $0.84 |
