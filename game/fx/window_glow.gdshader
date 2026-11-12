shader_type spatial;
// A lit window (M7 T10, redrawn in G4): a warm pane laid just in front of a kit window piece, drawn as a hand would: a slightly uneven
// quad (each corner pulled in by a hash of the window's seed, so no two windows are the same rectangle), one stroke of dark paint for
// each mullion (its place and its slant a seed's, its width wavering along its length), a dark ragged frame stroke, two flat tones (a
// glowing top and a deeper lower part split at a level of its own) and, for some windows, a blind half drawn across the top. Flat
// colour, no photographic gradient; mixed over the picture, unshaded. Presentation only.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 0.32);
uniform vec3 deep_color : source_color = vec3(0.85, 0.4, 0.12);
uniform vec3 mullion_color : source_color = vec3(0.1, 0.06, 0.1);
uniform float energy : hint_range(0.0, 4.0) = 1.0;
// The panes: how many the mullion strokes divide the window into (x, y; 1 = no stroke), and a stroke's width as a share of the window.
uniform vec2 grid = vec2(2.0, 2.0);
uniform float mullion : hint_range(0.0, 0.3) = 0.08;
// The margin round the whole (a share), how far each corner may be pulled in (a share), and the frame stroke's width (a share).
uniform float margin : hint_range(0.0, 0.3) = 0.1;
uniform float uneven : hint_range(0.0, 0.3) = 0.1;
uniform float frame : hint_range(0.0, 0.2) = 0.05;
// Per window: a seed, and the share of the panes' cells that stay lit (a pane may be dark: the window then draws its deep tone only).
uniform float seed = 1.0;
uniform float lit_share : hint_range(0.0, 1.0) = 0.85;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float h(float k) {
	return hash12(vec2(seed * 7.13 + k, k * 3.71 + seed));
}

void fragment() {
	vec2 uv = (UV - vec2(margin)) / (1.0 - 2.0 * margin);
	// The uneven quad: the four corners pulled in by up to `uneven` of the window, the sides straight lines between them.
	float j = uneven;
	vec2 c00 = vec2(h(1.0), h(2.0)) * j;
	vec2 c10 = vec2(1.0 - h(3.0) * j, h(4.0) * j);
	vec2 c01 = vec2(h(5.0) * j, 1.0 - h(6.0) * j);
	vec2 c11 = vec2(1.0 - h(7.0) * j, 1.0 - h(8.0) * j);
	float xl = mix(c00.x, c01.x, uv.y);
	float xr = mix(c10.x, c11.x, uv.y);
	float yb = mix(c00.y, c10.y, uv.x);
	float yt = mix(c01.y, c11.y, uv.x);
	vec2 l = vec2((uv.x - xl) / max(xr - xl, 0.01), (uv.y - yb) / max(yt - yb, 0.01));
	float aa = max(max(fwidth(l.x), fwidth(l.y)) * 1.2, 0.004);
	float inside = step(0.0, l.x) * step(l.x, 1.0) * step(0.0, l.y) * step(l.y, 1.0);
	// The frame stroke, ragged: its width wavers a little along each side.
	float rag = 0.5 + 0.5 * sin(l.y * 9.0 + h(9.0) * 6.28) * sin(l.x * 7.0 + h(10.0) * 6.28);
	float fw_ = frame * (0.6 + 0.8 * rag);
	float edge = min(min(l.x, 1.0 - l.x), min(l.y, 1.0 - l.y));
	float in_frame = 1.0 - smoothstep(fw_ - aa, fw_ + aa, edge);
	// The mullion strokes: a vertical stroke and a horizontal one, off the middle by a seed and slanted a little, each wavering in width.
	float bars = 0.0;
	for (int k = 1; k < 4; k++) {
		float fk = float(k);
		if (fk < grid.x) {
			float at = fk / grid.x + (h(11.0 + fk) - 0.5) * 0.18 + (l.y - 0.5) * (h(14.0 + fk) - 0.5) * 0.25;
			float w = mullion * 0.5 * (0.75 + 0.5 * sin(l.y * 6.0 + h(15.0) * 6.28));
			bars = max(bars, 1.0 - smoothstep(w - aa, w + aa, abs(l.x - at)));
		}
		if (fk < grid.y) {
			float at = fk / grid.y + (h(18.0 + fk) - 0.5) * 0.18 + (l.x - 0.5) * (h(21.0 + fk) - 0.5) * 0.25;
			float w = mullion * 0.5 * (0.75 + 0.5 * sin(l.x * 6.0 + h(22.0) * 6.28));
			bars = max(bars, 1.0 - smoothstep(w - aa, w + aa, abs(l.y - at)));
		}
	}
	// Two flat tones split at a level of the window's own; some windows have a blind drawn halfway down from the top.
	float split = 0.3 + 0.25 * h(24.0);
	vec3 col = mix(deep_color, glow_color, step(split, l.y));
	float blind_depth = step(0.7, h(25.0)) * (0.3 + 0.3 * h(26.0));
	float blind = step(1.0 - blind_depth - 0.03 * sin(l.x * 11.0 + h(27.0) * 6.28), l.y);
	col = mix(col, deep_color * 0.55, blind);
	float lit = step(hash12(floor(l * grid) + vec2(seed * 13.1, seed * 5.7)), lit_share);
	col = mix(deep_color * 0.5, col, lit);
	col = mix(col, mullion_color, max(bars, in_frame));
	ALBEDO = col * mix(energy, 1.0, max(bars, in_frame));
	ALPHA = inside;
}
