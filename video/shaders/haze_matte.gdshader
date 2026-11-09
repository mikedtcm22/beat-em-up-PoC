shader_type spatial;
// A painted matte card (LD-WORLD; PLAN.md section 4 part 4): the far skyline, a smoke bank, a wall of fire, painted by
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
// Round 3: a Gemini-painted backdrop is feathered into the sky at its edges (the share of the card's left, right, top and bottom that fades out), and
// can drift: `phase` is the frame number's slot (the rig writes it; never time), `drift` the sway of the painted smoke in uv, `drift_from` the height
// (uv from the bottom) above which the picture sways, so the fire stays and the smoke moves.
uniform vec4 feather = vec4(0.0);
uniform float phase = 0.0;
uniform float drift : hint_range(0.0, 0.03) = 0.0;
uniform float drift_from : hint_range(0.0, 1.0) = 0.3;

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
	vec2 uvd = UV;
	if (drift > 0.0) {
		float up = smoothstep(drift_from, drift_from + 0.35, 1.0 - UV.y);
		uvd.x += drift * up * (sin(UV.y * 11.0 + phase * 0.045) + 0.6 * sin(UV.x * 7.0 - phase * 0.03 + 1.7));
		uvd.y += drift * 0.5 * up * sin(UV.x * 9.0 + phase * 0.037);
	}
	vec4 m = texture(matte, uvd);
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
