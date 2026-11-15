shader_type spatial;
// The boss roof's skyline as flat silhouettes (M7 e-bossroof): a card of two layers of buildings (mode 0, a far plate, the buildings' roofs
// stepping across it) or one flat face with its window grid (mode 1, laid over a kit skyline block). One dark body tone, a dull window tone
// and a few lit windows in the fire's orange, a hard fire-lit edge along the roofs. Opaque where there is a building, a pixel outside it is
// discarded; unshaded and fog-free (the plate's own colours are the haze).
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 body_color : source_color = vec3(0.1, 0.045, 0.12);
uniform vec3 window_color : source_color = vec3(0.16, 0.07, 0.16);
uniform vec3 lit_color : source_color = vec3(1.0, 0.46, 0.14);
uniform vec3 edge_color : source_color = vec3(0.96, 0.36, 0.1);
uniform float lit_share : hint_range(0.0, 1.0) = 0.1;
uniform float lit_energy : hint_range(0.0, 4.0) = 1.3;
uniform float seed = 1.0;
// 0: a skyline plate. 1: a flat face.
uniform int mode = 0;
uniform vec2 card_m = vec2(150.0, 40.0);
uniform vec2 cell_m = vec2(7.0, 11.0);
uniform vec2 roof_m = vec2(9.0, 24.0);
// A window's cell (m) and the share of it the pane fills.
uniform vec2 window_cell_m = vec2(1.7, 2.3);
uniform vec2 pane_share = vec2(0.55, 0.6);
// The lit edge: its width in metres (never under min_edge_px pixels), and how much of a roof's run it covers.
uniform float edge_m = 0.35;
uniform float min_edge_px : hint_range(0.0, 6.0) = 1.5;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float roof_height(float x, float cell, float seed_off, float lo, float hi) {
	float id = floor(x / cell);
	float keep = hash12(vec2(id, seed + seed_off));
	// A third of the cells are low gaps between towers.
	return mix(lo, hi, keep * keep * 0.85 + 0.15 * step(0.6, keep));
}

void fragment() {
	vec2 q = vec2(UV.x * card_m.x, (1.0 - UV.y) * card_m.y);
	float top = card_m.y;
	float aa = max(fwidth(q.y), 0.0005);
	float pixel_m = max(fwidth(q.x), fwidth(q.y));
	if (mode == 0) {
		float a = roof_height(q.x, cell_m.x, 0.0, roof_m.x * 0.6, roof_m.y);
		float b = roof_height(q.x + cell_m.y * 0.37, cell_m.y, 11.0, roof_m.x * 0.4, roof_m.y * 0.6);
		top = max(a, b);
	}
	if (q.y > top) {
		discard;
	}
	vec3 col = body_color;
	// A window grid on the building.
	vec2 wc = q / window_cell_m;
	vec2 cell = floor(wc);
	vec2 f = fract(wc);
	vec2 pane = abs(f - 0.5) * 2.0;
	float in_pane = step(pane.x, pane_share.x) * step(pane.y, pane_share.y) * step(window_cell_m.y * 1.2, q.y) * step(q.y, top - window_cell_m.y * 1.1);
	float roll = hash12(cell + vec2(seed * 3.0, 5.0));
	float alive = step(0.25, hash12(cell * 0.37 + vec2(seed, 9.0)));
	vec3 pane_col = window_color;
	if (roll < lit_share) {
		pane_col = lit_color * lit_energy;
	}
	col = mix(col, pane_col, in_pane * alive);
	// The fire-lit edge along the roof.
	float edge_w = max(edge_m, pixel_m * min_edge_px);
	float on_edge = step(top - edge_w, q.y);
	// Only where the roof is higher than its left neighbour's, so the edge is a lit side, not a full outline.
	col = mix(col, edge_color, on_edge * 0.9);
	ALBEDO = col;
}
