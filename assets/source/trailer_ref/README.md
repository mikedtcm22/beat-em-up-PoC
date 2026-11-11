# Trailer reference art (M7 P0)

Tracked source art for the trailer's look (M7). Nothing here is imported by Godot: `assets/source/.gdignore` keeps the whole `assets/source/` tree out of the import.

| Folder | Files | Origin |
| --- | --- | --- |
| `frames/` | 34 stills, `t_01.jpg` to `t_34.jpg` (one per second, 1920x1080, JPEG quality 2) | Extracted with `ffmpeg -vf fps=1` from the project's own `gameplay-trailer.mp4` (33.6 s, 1920x1080) |
| `keyframes/` | 10 full-size key frames, `t<NN>_key_pick.jpg` (shots 01, 02, 04, 05, 06, 07, 08, 10, 12, 13) | The picked Gemini keyframes from the video worktree's `captures/video/planb/keyframes/` (the `_pick` copies only; the registered `_reg1080.png` copies are not included) |
| `plates/` | 7 hero plates, `t<NN>_plate_0_gemini.jpg` (shots 01, 03, 04, 07, 08, 10, 12) | Gemini paint-overs from each shot's `plates/<shot>/gemini/`; one per shot, the highest-numbered take (the later takes carry the prompt fixes) |
| `ref/` | 18 reference stills, `ref1_*.png` and `ref2_*.png` | Reference stills from the video worktree's `captures/video/ref/frames/` |

Origin of the Gemini files: the project's own trailer, Gemini keyframes and plates made through the paid Gemini API. Total size about 54 MB.
