shader_type spatial;
// The video's impact cues, redone INSIDE the 3D render (Phase 1, LD-INK; PLAN.md Plan A part 5): the game's
// impact frame and speed lines are CanvasLayers of the main viewport and never reach the 2560x1440
// SubViewport. This is one full-screen quad in the 3D scene (as the ink pass is) that draws
//  - a FLASH FRAME: a flat paper-white fill (alpha `flash`) with the radial lines over it in ink, and
//  - SPEED LINES: ink streaks radiating from `center` (screen uv), count and length from hashes of the
//    streak's cell and `seed`, so they are irregular, re-seeded from the output frame (12 fps) by the rig.
// No time and no screen noise: every value is a uniform the rig sets from the output frame.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform vec3 paper : source_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ink : source_color = vec3(0.09, 0.055, 0.05);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float lines : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float seed : hint_range(0.0, 1000.0) = 0.0;
uniform float count : hint_range(8.0, 200.0) = 72.0;
uniform float inner : hint_range(0.0, 1.0) = 0.28;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash11(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 d = (uv - center) * vec2(aspect, 1.0);
	float r = length(d);
	float a = atan(d.y, d.x) / TAU + 0.5;
	// Streak cells around the circle; each has a presence, a width and an inner radius from its hash.
	float cell = floor(a * count);
	float h1 = hash11(cell + seed * 13.0);
	float h2 = hash11(cell * 1.7 + seed * 29.0 + 5.0);
	float h3 = hash11(cell * 2.3 + seed * 7.0 + 11.0);
	float within = fract(a * count) - 0.5;
	// The streak is a thin wedge that gets wider with the radius, from its own start outward.
	float start = inner * (0.8 + 0.7 * h3);
	float wedge = 0.12 + 0.3 * h2;
	float width = wedge * smoothstep(start, start + 0.35, r);
	float streak = (1.0 - smoothstep(width * 0.5 - 0.04, width * 0.5 + 0.04, abs(within))) * step(0.42, h1) * step(start, r);
	float line_alpha = streak * lines;
	// Paper under the lines in a flash frame; the lines are ink on it, or ink on the picture without one.
	vec3 color = mix(ink, paper, flash * (1.0 - line_alpha));
	float alpha = clamp(max(flash, line_alpha), 0.0, 1.0);
	ALBEDO = color;
	ALPHA = alpha;
}
