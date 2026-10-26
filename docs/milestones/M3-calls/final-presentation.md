# M3 final review: ARCHITECTURE wording from the presentation fixes

Proposed text for docs/ARCHITECTURE.md, from the fixer of package "lens-floor-and-warning-size" (findings final-crowd-01 and final-warn-01). The fixer does not edit ARCHITECTURE.md; the lead folds these in. Neither change is a spec change.

## 1. "First-person lens" (the paragraph at ARCHITECTURE.md:266)

Add after the sentence that ends "...never use it.":

> **Floor under the lens** (final review, crowd-01): the lens is never lower than the floor under the player plus `Tuning.cam_floor_clearance_m` (0.13 m: the near plane's 0.05 m and a margin for the shake). The fixed 0.2 m drop is right for an upright body; a player lying face-down (struck from the side or behind) has `EyePoint` only 0.15 m up, which put the lens 4.4 cm inside the street for the whole 1.1 s of the knockdown, and the street's top face is drawn from above only, so the floor vanished. `FirstPersonCamera._view_with()` takes the `max` of the lens y and `lens_floor_y(player, eye) + cam_floor_clearance_m`, before the KO view's mix (so the KO blend is unchanged) and before punch and shake (the shake's 4 cm leaves the lens above the near plane). `lens_floor_y()` is the player's own interpolated height while it is on the floor, and in the air (a launch, a throw) the first world-layer surface straight down from `EyePoint`, never from the lens, which may already be inside the floor and would see nothing; it is `-INF` (no clamp) outside the tree or with nothing below. Being a max against a floor that is the player's own height (or the world below it), it adds no jump of its own: the lens never moves more in a tick than it would without it. A body that falls face-up (`EyePoint` 0.3 m up, the lens 0.116 m) is lifted 1.3 to 1.4 cm. It does not touch the belly-slab question (how much of the view the own body covers face-up), which stays Game-boy's. `view_from_eye()` includes the clamp, so the rig tests judge the real view. Tests: `tests/test_ko_view.gd` knocks the real player down with a Kicker's sweep and a Bruiser's smash from 90, 135 and 180 degrees (and from the front) and judges the lens on every frame of LAUNCHED, DOWNED and GETUP.

Also, in the tuning list for the "Camera" group, if ARCHITECTURE lists it: `cam_floor_clearance_m` (0 to 0.5 m, default 0.13), next to `cam_height_offset_m` and `cam_forward_offset_m`.

## 2. "Rear warning", the "Look" bullet (ARCHITECTURE.md:540)

Replace "a heavy attacker (`attacker.heavy`, read duck-typed) makes the corner's burst `rear_warning_heavy_scale` times larger." with:

> a heavy attacker (`attacker.heavy`, read duck-typed) makes the corner's burst `rear_warning_heavy_scale` times larger, at every size setting (SPEC section 8): the steady size is `min(rear_warning_base_px x rear_warning_size, edge / rear_warning_heavy_scale)`, times the heavy scale for a heavy one, where `edge` is the short side of the reserved corner (216 px at 1080p), so a heavy burst always fits it and the normal burst is held to `edge / heavy_scale` (166 px at the defaults): above a size of about 1.04 the size slider does nothing, which the plan's binding 20% x 20% corner makes inherent.

and replace the last sentence "`burst_rect()` keeps every burst inside the reserved 20% x 20% corner whatever `rear_warning_size` says." with:

> `burst_rect()` keeps every burst inside the reserved 20% x 20% corner whatever `rear_warning_size` says; it clips steady x pulse to the corner, so a heavy burst is never smaller than a normal one's at rest or at the pop's peak (the default heavy pop, 208 x 1.25, is clipped to 216 px, against the normal pop's 200).

Also in the `corner_state` API bullet: `size_px` is the steady size from `_steady_size()` (the size tunable, the heavy scale for a heavy burst, inside the corner).
