shader_type spatial;
// The video's impact cues, redone INSIDE the 3D render (Phase 1, LD-INK; PLAN.md Plan A part 5): the game's
// impact frame and speed lines are CanvasLayers of the main viewport and never reach the 2560x1440
// SubViewport. This is one full-screen quad in the 3D scene (as the ink pass is) that draws
//  - a FLASH FRAME: a flat paper-white fill (alpha `flash`) with the radial lines over it in ink, and
//  - SPEED LINES: ink streaks radiating from `center` (screen uv), count and length from hashes of the
//    streak's cell and `seed`, so they are irregular, re-seeded from the output frame (12 fps) by the rig.
//  - THE REAR WARNING (round 3): the game's warning is a HUD burst that never reaches the render, so the cue pass draws its own from
//    the HUD's state: a hard-edged red shard-burst with an ink outline and a paper core in the top corner it lights (`warn_left`,
//    `warn_right`: xy the centre in screen uv, z the half height in uv, w the alpha), its spikes re-rolled by `seed` (12 fps).
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
uniform vec4 warn_left = vec4(0.0);
uniform vec4 warn_right = vec4(0.0);
uniform vec3 warn_color : source_color = vec3(0.95, 0.16, 0.08);
uniform float warn_spikes : hint_range(5.0, 16.0) = 9.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash11(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

// One warning burst at `w` (centre uv, half height uv, alpha): rgb and coverage. A jagged star whose spikes differ in length and
// angle (the hash of its cell and the seed), an ink rim, a hot fill and a paper core; the edges are smoothed by the pixel footprint.
vec4 warning_burst(vec2 uv, vec4 w, float aspect) {
	if (w.w <= 0.001) {
		return vec4(0.0);
	}
	vec2 d = (uv - w.xy) * vec2(aspect, 1.0) / max(w.z, 0.001);
	float r = length(d);
	if (r > 1.4) {
		return vec4(0.0);
	}
	float a = atan(d.y, d.x) / TAU + 0.5;
	float cell = floor(a * warn_spikes);
	float h = hash11(cell * 3.1 + seed * 17.0 + w.x * 9.0);
	float t = abs(fract(a * warn_spikes + 0.15 * h) - 0.5) * 2.0;
	float reach = (0.62 + 0.38 * h) * mix(1.0, 0.34, smoothstep(0.0, 1.0, t));
	float aa = fwidth(r) * 1.5;
	float body = 1.0 - smoothstep(reach - aa, reach + aa, r);
	float rim = 1.0 - smoothstep(reach - 0.13 - aa, reach - 0.13 + aa, r);
	float core = 1.0 - smoothstep(0.22 - aa, 0.22 + aa, r);
	vec3 c = mix(ink, warn_color, rim);
	c = mix(c, paper, core);
	return vec4(c, body * w.w);
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
	// The rear warning's bursts over it.
	vec4 wl = warning_burst(uv, warn_left, aspect);
	vec4 wr = warning_burst(uv, warn_right, aspect);
	color = mix(color, wl.rgb, wl.a);
	alpha = max(alpha, wl.a);
	color = mix(color, wr.rgb, wr.a);
	alpha = max(alpha, wr.a);
	ALBEDO = color;
	ALPHA = alpha;
}
