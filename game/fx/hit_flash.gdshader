shader_type spatial;
// The contact hit flash (Spec §6, localized by Game-boy on 2026-10-24): drawn over a struck
// body as the next_pass of its materials while the flash runs (HumanoidRig.flash_at()), and
// never on an idle body. Each pixel of the body mixes toward the flash color by the strength
// times a falloff of its world-space distance from the hit's contact point: full out to
// flash_core of flash_radius, then fading smoothly to nothing at flash_radius. Unshaded, so
// the core is the flash color itself (pure white), whatever the light. It draws first among
// the transparent passes (render_priority), under the comic effects.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Set from Tuning by the struck actor (CombatActor._flash_at()): world-space contact point,
// radius (m), the share of it at full strength (0..1), strength (0..1) and color.
uniform vec3 flash_point = vec3(0.0);
uniform float flash_radius = 0.0;
uniform float flash_core = 0.0;
uniform float flash_strength = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);

// Mirrored by HumanoidRig.flash_falloff() for the tests.
float falloff(float dist) {
	float inner = flash_radius * clamp(flash_core, 0.0, 1.0);
	float span = flash_radius - inner;
	if (span <= 0.0) {
		return dist <= flash_radius ? 1.0 : 0.0;
	}
	return 1.0 - smoothstep(0.0, 1.0, clamp((dist - inner) / span, 0.0, 1.0));
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float alpha = clamp(flash_strength, 0.0, 1.0) * falloff(distance(world, flash_point));
	if (alpha <= 0.0) {
		discard;
	}
	ALBEDO = flash_color;
	ALPHA = alpha;
}
