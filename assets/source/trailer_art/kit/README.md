# Trailer kit paintings (M7 G3)

`make_jobs.py` writes `jobs.json`, the Gemini jobs (model gemini-3-pro-image, the trailer frames t_02, t_04, t_05 as style references).
Run them from a scratch folder next to a copy of jobs.json: `python3 -I tools/gemini_image.py jobs.json` writes the pictures,
which are kept here downscaled (longest side 2048 px) in `src/`. `tools/gen_trailer_kit.py` turns them into the sheets in
assets/export/kit/ (ink mask from the dark lines, a flat colour layer under them, seams made invisible, palette matched).
