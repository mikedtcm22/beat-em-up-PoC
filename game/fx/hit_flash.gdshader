shader_type spatial;
// The contact hit flash (Spec §6, localized by Game-boy on 2026-10-24): drawn over a struck
// body as the next_pass of its materials while the flash runs (HumanoidRig.flash_at()), and
// never on an idle body. Each pixel of the body mixes toward the flash color by the strength
// times a falloff of its world-space distance from the hit's contact point: full out to
// flash_core of flash_radius, then fading smoothly to nothing at flash_radius. Unshaded, so
// the core is the flash color itself (pure white), whatever the light. It draws first among
// the transparent passes (render_priority), under the comic effects.
//
// First-person feel (M4, P3-flash): flash_max_share caps how much of the view the flash may cover on
// screen. A flash a few centimeters from the lens (a knee in a hold, a flurry's jabs at close range)
// would change a fifth of the view; with the cap, a surface is flashed only within a disc around the
// screen position of the flash's point whose area is that share of the view. It is done by stretching
// the space across the line of sight to the point, not along it, by 1 / k, where k is how much the
// flash's reach across that line, at the fragment's own offset along it, would have to shrink on screen
// to fit the share (1 when it already fits, so a flash that fits is not touched): the flash keeps its
// shape and its place, and a point hidden behind the near surface (a knee's contact under a cap's brim)
// still flashes what lies in front of it. It uses the camera that draws the pass (its projection and
// viewport), so the simulation never reads a camera. 0 = off (today's flash, to the last bit).
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Set from Tuning by the struck actor (CombatActor._flash_at()): world-space contact point,
// radius (m), the share of it at full strength (0..1), strength (0..1) and color.
uniform vec3 flash_point = vec3(0.0);
uniform float flash_radius = 0.0;
uniform float flash_core = 0.0;
uniform float flash_strength = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
// The most of the view (0..1) the flash's disc may cover on screen; 0 = no cap. Set from Tuning's
// hit_flash_fp_max_share by HumanoidRig.flash_at().
uniform float flash_max_share : hint_range(0.0, 1.0) = 0.0;

// How much a flash whose reach across the line of sight is `reach` m has to shrink on screen, on a
// surface `depth` m in front of the lens, to cover at most flash_max_share of the view: 1 when it
// already does or the cap is off, else the ratio of the radius that does, `limit` half-heights of the
// view (the disc of that radius covers the share: pi * limit^2 of the view's 4 * aspect), to the
// flash's own: limit * depth / (reach * proj11). proj11 is the camera's abs(PROJECTION_MATRIX[1][1])
// (negative when the pass draws into a flipped target, as it does in a viewport on Vulkan and Metal)
// and aspect the viewport's width over its height (built-ins, so fragment() hands them in). Mirrored
// by HumanoidRig.flash_cap_scale().
float cap_scale(float depth, float reach, float proj11, float aspect) {
	if (flash_max_share <= 0.0 || reach <= 0.0) {
		return 1.0;
	}
	float limit = sqrt(4.0 * aspect * flash_max_share / PI);
	return min(1.0, limit * max(depth, 0.0) / (reach * max(proj11, 0.0001)));
}

// The distance (m) the falloff reads for a fragment at `frag` (view space) from the flash's point at
// `point`: the offset across the line of sight to the point, stretched by 1 / cap_scale(), and the
// offset along it as it is. The reach the scale is figured for is the flash's own across that line at
// the fragment's offset along it, sqrt(radius^2 - along^2): the farthest across the flash is not
// zero. Without the cap, or where the flash fits, the plain distance. Mirrored by
// HumanoidRig.flash_cap_distance().
float cap_distance(vec3 frag, vec3 point, float proj11, float aspect) {
	vec3 off = frag - point;
	vec3 sight = length(point) > 0.0001 ? normalize(point) : vec3(0.0, 0.0, -1.0);
	float along = dot(off, sight);
	float reach = sqrt(max(flash_radius * flash_radius - along * along, 0.0));
	float k = cap_scale(-frag.z, reach, proj11, aspect);
	if (k >= 1.0) {
		return length(off);
	}
	float across = length(off - along * sight);
	return length(vec2(across / max(k, 0.0001), along));
}

// Mirrored by HumanoidRig.flash_falloff() for the tests.
float falloff(float dist, float radius) {
	float inner = radius * clamp(flash_core, 0.0, 1.0);
	float span = radius - inner;
	if (span <= 0.0) {
		return dist <= radius ? 1.0 : 0.0;
	}
	return 1.0 - smoothstep(0.0, 1.0, clamp((dist - inner) / span, 0.0, 1.0));
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(world, flash_point);
	if (flash_max_share > 0.0) {
		// The cap, in view space: the fragment, the flash's point, and the distance between them.
		vec3 point = (VIEW_MATRIX * vec4(flash_point, 1.0)).xyz;
		dist = cap_distance(VERTEX, point, abs(PROJECTION_MATRIX[1][1]), VIEWPORT_SIZE.x / VIEWPORT_SIZE.y);
	}
	float alpha = clamp(flash_strength, 0.0, 1.0) * falloff(dist, flash_radius);
	if (alpha <= 0.0) {
		discard;
	}
	ALBEDO = flash_color;
	ALPHA = alpha;
}
