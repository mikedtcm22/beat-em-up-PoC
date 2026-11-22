shader_type spatial;
// A painted matte card (M7 T10, ported from the video branch's haze_matte): the far skyline, a smoke bank, a wall of fire, painted by
// tools/video/paint_mattes.py (RGBA: the paint and a silhouette alpha). The card hangs in the world behind the playfield. It is
// unshaded and takes the haze's tint by `fade`, so a distant card sits in the air; a fine brush grain anchored in the card's own
// metres breaks the flat bands. The depth test hides it behind any real geometry.
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D matte : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 haze_color : source_color = vec3(0.1, 0.12, 0.3);
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;
uniform float energy : hint_range(0.0, 3.0) = 1.0;
uniform float grain : hint_range(0.0, 0.4) = 0.06;
uniform vec2 card_size_m = vec2(100.0, 30.0);
// A Gemini-painted backdrop is feathered into the sky at its edges: the share of the card's left, right, top and bottom that fades out.
uniform vec4 feather = vec4(0.0);
// G4: a low-frequency wobble that bends the plate's rows (a share of the card), and the share of its lit windows painted out, so the far
// windows are never an exact grid. 0 leaves the plate as painted.
uniform float warp : hint_range(0.0, 0.03) = 0.0;
uniform float drop_share : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// The rows wander: the plate is read through a slow noise of its own coordinates (finer in x than in y, as a hand's rows drift).
	vec2 wobble = vec2(vnoise(UV * vec2(23.0, 11.0) + 3.7), vnoise(UV * vec2(17.0, 29.0) + 11.3)) - 0.5;
	vec2 uv = UV + wobble * 2.0 * warp * vec2(1.0, 1.6);
	vec4 m = texture(matte, uv);
	// A lit window (warm, bright) is painted out in some cells of a coarse grid, a hash picking which: the rest stay lit.
	float lit = step(0.45, m.r) * step(m.b, m.r * 0.95);
	vec2 cell = floor(uv * vec2(36.0, 17.0));
	float out_ = step(hash12(cell + 5.3), drop_share) * lit;
	m.rgb = mix(m.rgb, m.rgb * vec3(0.18, 0.2, 0.34), out_);
	vec3 col = m.rgb * tint;
	vec2 metres = UV * card_size_m;
	float g = 0.65 * vnoise(metres * vec2(0.5, 1.6)) + 0.35 * vnoise(metres * vec2(1.4, 4.1) + 9.0);
	col *= 1.0 + (g - 0.5) * 2.0 * grain;
	col = mix(col, haze_color, fade);
	ALBEDO = col * energy;
	float feather_a = smoothstep(0.0, max(feather.x, 0.0001), UV.x) * (1.0 - smoothstep(1.0 - max(feather.y, 0.0001), 1.0, UV.x))
		* smoothstep(0.0, max(feather.z, 0.0001), UV.y) * smoothstep(0.0, max(feather.w, 0.0001), 1.0 - UV.y);
	feather_a = mix(1.0, feather_a, step(0.0001, max(max(feather.x, feather.y), max(feather.z, feather.w))));
	ALPHA = m.a * alpha_mul * feather_a;
}
