shader_type spatial;
// A lit window (M7 T10): warm panes behind dark mullions, laid just in front of a kit window piece. Flat colour with a darker
// lower edge (the glow pools at the top), no photographic gradient; mixed over the picture, unshaded. Presentation only.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 0.32);
uniform vec3 deep_color : source_color = vec3(0.85, 0.4, 0.12);
uniform float energy : hint_range(0.0, 4.0) = 1.0;
// The panes: a grid of cells, the mullion's share of one, the margin round the whole.
uniform vec2 grid = vec2(2.0, 2.0);
uniform float mullion : hint_range(0.0, 0.3) = 0.08;
uniform float margin : hint_range(0.0, 0.3) = 0.1;
// Per window: which panes are dark (a hash of the seed picks them), and the share that stay lit.
uniform float seed = 1.0;
uniform float lit_share : hint_range(0.0, 1.0) = 0.85;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 inner = (UV - vec2(margin)) / (1.0 - 2.0 * margin);
	float inside = step(0.0, inner.x) * step(inner.x, 1.0) * step(0.0, inner.y) * step(inner.y, 1.0);
	vec2 g = inner * grid;
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	vec2 bar = vec2(mullion) / max(grid, vec2(1.0));
	float pane = step(bar.x * grid.x * 0.5, 0.5 - abs(f.x)) * step(bar.y * grid.y * 0.5, 0.5 - abs(f.y));
	float lit = step(hash12(cell + vec2(seed * 13.1, seed * 5.7)), lit_share);
	vec3 col = mix(deep_color, glow_color, smoothstep(0.0, 0.7, inner.y));
	ALBEDO = col * energy;
	ALPHA = inside * pane * lit;
}
