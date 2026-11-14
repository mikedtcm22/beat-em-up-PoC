# Milestone 7, Phase 3: comic-book 3D (the target)

Approved by Game-boy in chat on 2026-11-13 ("Approve, start"), after two rounds of the painted-texture route and three route spikes failed to make a playable frame pass for the trailer. Rows T40 to T57 in `.claude/cfo/plan.md`.

## The bar

A clean cel-shaded 3D brawler with the trailer's night mood, plus real drawn art at the moments where the camera is fixed. It is judged by Game-boy's eye on a side-by-side reel and a play session. The blind judge is retired: it scored every route 0.72 to 0.78, the trailer's own repaint method included, so it cannot rank them. Frame time stays gated at +10% over M6.

Kept from the slice: the `trailer` look profile and F7, the night-street colour script, painted sky, lamps, pools, burn barrel, steam, the Gemini-painted trim and ground sheets. Characters stay 3D: ragdoll, 60 Hz animation, damage marks and free camera angles are not traded away. Ox keeps his M6 colours.

## The figure recipe (the Punk, the player's arms, then every enemy)

The reference for "what good looks like" is the S1 spike's drawn Punk (`captures/m7-slice/spikes/s1/`, and `routes_sheet.jpg` column 2), not the trailer frame.

- **Fills:** flat local colour. No grain, no hatch or scribble patches, no gradients on a figure.
- **Shade:** two tones with one hard edge per form: the paint colour, and the paint colour darkened and tinted slightly toward the area hue. The edge comes from a quantised light term against the key direction. Painted shadow shapes are few and designed: under the cap brim, under the chin, inside the vest, under the glove cuff.
- **Line:** a dark hull outline whose weight swells on the shadow side and under forms. No line breaks and no wobble by default (both stay as tunables at zero). Inner ink is a few bold lines: folds at elbow and shoulder, vest seams, finger separations.
- **Rim:** a thin warm line (a few pixels, hard-edged) just inside the outline on the key-light side only. Never a band.
- **Face:** taken from the S1 drawing: heavy brows, the brim's shadow as one flat shape across the eyes, a nose side line, a set mouth, a jaw shadow. It must read at fight distance and at 45 degrees.
- **Ground contact:** a soft dark blob under the figure. Figures cast no shadow-map shadow.
- **Damage:** bruises and blood show exactly as in M6, and never at full health.
- **Ox:** the same shade, line and rim rules over his M6 colours; a bold face; no repaint of his palette.

## The frame

- No full-frame grain on figures and no softening: the 3D view renders at full scale under the trailer profile. A light grain may stay on the world only if it costs nothing measurable.
- **Fence:** the chain-link lattice is replaced, under the trailer profile only, by a simple drawn fence of posts, two rails and uneven boards or bars with a few gaps. Collision is unchanged.
- **Windows:** rows are broken in the trim sheet itself: lit, dark, boarded and curtained variants at slightly different sizes and offsets, so no row repeats evenly.
- **Halos and pools:** two or three stepped tones with a brushed edge, as now.

## The drawn cards (cut-ins)

Full-screen drawn stills, made by Gemini repaint of game stills (the one method that scored and looked best on single frames). 1600x900, no HUD in the art; any lettering is drawn by the game over the art, never baked into the image.

| Card | Fires on | Hold (tunable) |
|---|---|---|
| Mission title | the mission's first frame of play | about 1.5 s |
| Enemy entrance | the first time an enemy type appears in the mission (Punk, Thug, Bruiser, Kicker); Ox gets his name card at the boss intro | about 0.9 s |
| Knockout panel | `arena_cleared`, one per arena, picked from the panels of the last enemy knocked out | about 0.5 s |
| Mission end | `level_cleared` | until a button |

Rules: presentation layer only (subscribes to `CombatEvents`, writes no game state); the hold goes through `TimeController`, the one allowed exception; any attack or confirm input skips a card; cards are off under the M6 profile and behind one tunable, so bots and tests can run without them. Tunables live in a "Cut-ins (M7)" group.

## At the end

The new look becomes the default and M6 stays on F7 (T53), after Gate 3 and the roll-out. Gates: T50 (the slice) and T57 (Mission 1), both Game-boy's.
