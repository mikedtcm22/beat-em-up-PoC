# R5-INK calls

- One line per silhouette: the hull owns the silhouette; the screen ink draws creases and overlaps only. Alternative not taken: keep both and offset-match them (fragile). Second slow wander octave (`wander2`) and `under_mult` added.
- `ink_env_weight` = 0 in all three looks (plates and brush carry the environment).
- Light wrap and actor fog live in the finish pass (`post_finish.glsl`), values in the ink look pieces. Alternative: a separate compositor effect (more passes on an 8 GB machine).
- Diffusion glow in the finish pass at quarter size, two radii; 12-16% per location. Alternative: Godot's glow (rejected: the bloom look).
- Rear warning (cine_cue_screen) is a flat jagged chevron. Not a flower.
- Resumed at the 80% weekly budget: no new captures were recorded in the resume; the first cut's looks were set before the 88% handoff. Honest status: pixels not re-judged this run.

## Requests
- The lead should look at the six stills and moving_punk beside round 4 before the hero plates.
