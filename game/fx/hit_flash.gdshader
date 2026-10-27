shader_type spatial;
// The contact hit flash (Spec §6, localized by Game-boy on 2026-10-24): drawn over a struck
// body as the next_pass of its materials while the flash runs (HumanoidRig.flash_at()), and
// never on an idle body. Each pixel of the body mixes toward the flash color by the strength
// times a falloff of its world-space distance from the hit's contact point: full out to
// flash_core of flash_radius, then fading smoothly to nothing at flash_radius. Unshaded, so
// the core is the flash color itself (pure white), whatever the light. It draws first among
// the transparent passes (render_priority), under the comic effects.
//
// First-person feel (M4, P3-flash): flash_max_share caps how much of the view the flash's disc may
// cover on screen. A flash a few centimeters from the lens (a knee in a hold, a flurry's jabs at
// close range) would whiten up to 16% of the view; here the radius, and the core with it, shrinks
// until the disc a surface at the fragment's own depth would show covers at most that share of the
// view. Computed from the camera that draws the pass (its projection and viewport), so the simulation
// never reads a camera, and a flash farther off is not changed. 0 = off (today's flash).
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

// The flash's radius (m) for a surface `depth` m in front of the lens, with the share cap: the radius
// whose disc on screen, pi * (radius * proj11 / depth)^2 in half-heights of the view, is
// flash_max_share of the view's 4 * aspect, or the flash's own radius when that is smaller.
// proj11 is the camera's PROJECTION_MATRIX[1][1] and aspect the viewport's width over its height
// (built-ins, so fragment() hands them in). Mirrored by HumanoidRig.flash_capped_radius().
float capped_radius(float depth, float proj11, float aspect) {
	if (flash_max_share <= 0.0) {
		return flash_radius;
	}
	float half_heights = sqrt(4.0 * aspect * flash_max_share / PI);
	return min(flash_radius, half_heights * max(depth, 0.0) / max(proj11, 0.0001));
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
	float radius = capped_radius(-VERTEX.z, PROJECTION_MATRIX[1][1], VIEWPORT_SIZE.x / VIEWPORT_SIZE.y);
	float alpha = clamp(flash_strength, 0.0, 1.0) * falloff(distance(world, flash_point), radius);
	if (alpha <= 0.0) {
		discard;
	}
	ALBEDO = flash_color;
	ALPHA = alpha;
}
