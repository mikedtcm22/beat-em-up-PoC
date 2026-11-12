// The trailer's frame finish (Milestone 7, G1), included by edge_pass.gdshader under EDGE_FINISH (look_post.gd prepends the define for the
// trailer profile only). It reads no screen copy: a copy costs a full-screen resolve (measured at about 3 ms on the 8 GB machine, ten times the
// budget) and erases the haze and the contact flash drawn before this quad. Instead the same quad's own alpha carries three things:
//  - the paper grain: a cell noise, new on each beat (twos), light grains a little warm and dark ones ink, at `grain` of the value;
//  - the lines' wobble: the pixel the depth taps start from shifts by a pixel or so with a low-frequency noise, new on each beat;
//  - the lines' breaks: a coarse noise, new on each beat, thins a line and drops it in places (`line_break`), so a line is drawn, not ruled.
// The softening is the viewport's 3D scale with its bilinear upscale (look_post.gd; the HUD stays sharp). A helper cannot read built-ins, so the
// caller passes the fragment's.
uniform float grain : hint_range(0.0, 0.2) = 0.04;
uniform float grain_px : hint_range(1.0, 6.0) = 2.0;
uniform float wobble_px : hint_range(0.0, 3.0) = 1.0;
uniform float wobble_cell_px : hint_range(20.0, 400.0) = 120.0;
uniform float line_break : hint_range(0.0, 1.0) = 0.25;
uniform float beat_hz : hint_range(1.0, 30.0) = 12.0;

float finish_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float finish_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(finish_hash(i), finish_hash(i + vec2(1.0, 0.0)), f.x), mix(finish_hash(i + vec2(0.0, 1.0)), finish_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The whole-pixel shift the line taps start from.
ivec2 edge_finish_shift(vec2 fc, float time, float scale) {
	float beat = floor(time * beat_hz);
	vec2 cell = fc / (wobble_cell_px * scale);
	vec2 w = vec2(finish_noise(cell + vec2(beat * 1.7, beat * 0.3)), finish_noise(cell + vec2(17.0 + beat * 0.5, beat * 1.3))) - 0.5;
	return ivec2(round(w * 2.0 * wobble_px * scale));
}

// A line's alpha after its breaks (1 where whole, thinned and dropped in the coarse noise's low places).
float edge_finish_break(vec2 fc, float time, float scale) {
	float beat = floor(time * beat_hz);
	float n = finish_noise(fc / (34.0 * scale) + vec2(beat * 0.9, 41.0 + beat * 1.9));
	return 1.0 - line_break * (1.0 - smoothstep(0.22, 0.42, n));
}

// The colour and alpha the quad outputs: the line (`color`, `alpha`) over the grain.
vec4 edge_finish(vec2 fc, float time, float scale, vec3 color, float alpha) {
	float beat = floor(time * beat_hz);
	float g = finish_hash(floor(fc / (grain_px * scale)) + vec2(beat * 37.0, beat * 11.0)) - 0.5;
	vec3 grain_color = g > 0.0 ? vec3(0.45, 0.4, 0.4) : color;
	float grain_alpha = abs(g) * 2.0 * grain * (g > 0.0 ? 1.0 : 0.6);
	float total = alpha + (1.0 - alpha) * grain_alpha;
	return vec4(mix(grain_color, color, alpha / max(total, 0.0001)), total);
}
