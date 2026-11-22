shader_type spatial;
// The boss roof's fire wall (M7 e-bossroof, redrawn in x-roofs as flame tongues): the burn barrel's language at the wall's scale. A row of
// clusters, each a tall tongue with pointed tip, leaning, licking, and two shorter satellites beside it, in three nested flat tones (red
// body, orange middle, hot core: the core is HDR, so only it blooms) with a dark ink line round the outer edge, a few detached flame
// bits above the tips, and flat dark plumes of smoke above them. Tongue heights, leans and the bits are re-rolled on twos (`slot`, written
// by BossroofFx, never the clock). A cylindrical billboard (turns about the vertical to face the camera), opaque where there is fire or
// smoke (a pixel outside both is discarded), unshaded and fog-free: it is the far light. Only the cluster the pixel is in and its two
// neighbours are evaluated, so the cost does not grow with the wall's width.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 smoke_color : source_color = vec3(0.14, 0.05, 0.14);
uniform vec3 smoke_inner_color : source_color = vec3(0.3, 0.07, 0.15);
uniform vec3 outer_color : source_color = vec3(0.5, 0.09, 0.08);
uniform vec3 red_color : source_color = vec3(0.86, 0.2, 0.07);
uniform vec3 orange_color : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 core_color : source_color = vec3(1.0, 0.84, 0.4);
uniform vec3 line_color : source_color = vec3(0.13, 0.025, 0.07);
uniform float slot = 0.0;
uniform float seed = 1.0;
uniform vec2 card_m = vec2(150.0, 60.0);
// The middle and the core tongue as a share of the outer one's size.
uniform vec2 layer_scales = vec2(0.72, 0.42);
uniform float energy : hint_range(0.0, 3.0) = 1.0;
uniform float core_energy : hint_range(0.0, 6.0) = 2.0;
// The line's width as a share of the height, never thinner than min_line_px pixels.
uniform float line_share : hint_range(0.0, 0.05) = 0.006;
uniform float min_line_px : hint_range(0.0, 6.0) = 2.0;
// How much of the card's height the tallest tongue reaches, and the smoke's extra height and width over the tongue's.
uniform float reach : hint_range(0.1, 1.0) = 0.62;
uniform float smoke_rise : hint_range(0.0, 0.6) = 0.06;
uniform float smoke_grow : hint_range(1.0, 2.5) = 1.12;
// How deep inside the smoke its lighter inner tone starts, as a share of the height.
uniform float smoke_depth : hint_range(0.0, 0.2) = 0.05;

const int COLUMNS = 8;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = vec3(cam.x - origin.x, 0.0, cam.z - origin.z);
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	vec3 world = origin + right * VERTEX.x + vec3(0.0, 1.0, 0.0) * (VERTEX.y + card_m.y * 0.5);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Distance-like value (negative inside) to one tongue standing at the origin of p: height h, half-width w at the foot, tapering to a point
// at the top (`sharp` 0.5 blunt, 1 needle), the body leaning and licking (`wave`, a share of w).
float tongue(vec2 p, float h, float w, float lean, float wave, float phase, float sharp) {
	float t = clamp(p.y / max(h, 0.001), 0.0, 1.0);
	float x = p.x - lean * h * 0.3 * t * t - wave * w * sin(t * 4.2 + phase) * t;
	float half_w = w * pow(1.0 - t, sharp);
	float d = abs(x) - half_w;
	return max(d, p.y - h);
}

// A detached bit: the same tongue, closed off at its foot too, so it floats as a flame of its own.
float bit(vec2 p, float h, float w, float lean, float sharp) {
	return max(tongue(p, h, w, lean, 0.0, 0.0, sharp), -p.y);
}

void fragment() {
	vec2 q = vec2((UV.x - 0.5) * card_m.x, (1.0 - UV.y) * card_m.y);
	float h = card_m.y;
	float spacing = card_m.x / float(COLUMNS);
	float limit = h * reach * smoke_grow * 1.3;
	if (q.y > limit) {
		discard;
	}
	float d_out = 1e4;
	float d_mid = 1e4;
	float d_core = 1e4;
	float d_smoke = 1e4;
	int here = int(floor(q.x / spacing + float(COLUMNS) * 0.5));
	for (int k = -1; k <= 1; k++) {
		int i = here + k;
		if (i < 0 || i >= COLUMNS) {
			continue;
		}
		float fi = float(i);
		float keep = hash12(vec2(fi * 3.1 + seed, 7.0));
		float roll = hash12(vec2(fi * 5.7 + seed * 2.0, slot * 0.37));
		float roll2 = hash12(vec2(fi * 2.3 + seed * 4.0, slot * 0.91 + 3.0));
		float roll3 = hash12(vec2(fi * 8.9 + seed * 6.0, slot * 0.53 + 9.0));
		float cx = (fi + 0.5 - float(COLUMNS) * 0.5) * spacing + (keep - 0.5) * spacing * 0.35;
		float ch = h * reach * (0.55 + 0.3 * keep + 0.15 * roll);
		float w = spacing * (0.34 + 0.1 * keep);
		float lean = (roll2 - 0.5) * 1.5;
		float wave = 0.25 + 0.35 * roll3;
		float phase = fi * 2.1 + slot * 0.7;
		vec2 p0 = q - vec2(cx, 0.0);
		// The three tongues of a cluster: the tall one and two shorter ones leaning away from it.
		for (int s = 0; s < 3; s++) {
			float fs = float(s);
			float side = fs - 1.0;
			float sh = s == 1 ? ch : ch * (0.5 + 0.2 * hash12(vec2(fi + fs * 4.0 + seed, slot * 0.29 + 1.0)));
			float sw = s == 1 ? w : w * 0.6;
			float sl = s == 1 ? lean : side * 0.9 + lean * 0.4;
			vec2 p = p0 - vec2(side * w * 1.05, 0.0);
			d_out = min(d_out, tongue(p, sh, sw, sl, wave, phase + fs, 0.78));
			d_mid = min(d_mid, tongue(p, sh * layer_scales.x, sw * layer_scales.x, sl, wave, phase + fs, 0.78));
			d_core = min(d_core, tongue(p, sh * layer_scales.y, sw * layer_scales.y, sl, wave, phase + fs, 0.78));
		}
		// The smoke: a flat dark plume over the cluster, higher and broader than its tongue, with a blunt top.
		vec2 ps = p0 - vec2(lean * ch * 0.1, h * smoke_rise * (0.4 + roll));
		d_smoke = min(d_smoke, tongue(ps, ch * smoke_grow, w * smoke_grow * 1.1, lean * 0.8, wave, phase + 4.0, 0.55));
		// A detached flame bit over the tip (most clusters have one): a small tongue of its own, held clear of the cluster.
		if (roll3 > 0.3) {
			float bh = h * (0.03 + 0.03 * roll);
			vec2 pb = p0 - vec2((roll2 - 0.5) * w * 1.4 + lean * ch * 0.25, ch * (1.08 + 0.3 * roll2));
			d_out = min(d_out, bit(pb, bh, bh * 0.3, lean, 0.8));
			d_mid = min(d_mid, bit(pb + vec2(0.0, bh * 0.08), bh * 0.6, bh * 0.18, lean, 0.8));
		}
	}
	// The foot: the wall's base is solid fire, with the tongues rising from it.
	float foot = q.y - h * 0.07;
	d_out = min(d_out, foot);
	d_mid = min(d_mid, foot - h * 0.03);
	float aa = max(fwidth(d_out) * 1.1, 0.001);
	float pixel_m = max(fwidth(q.x), fwidth(q.y));
	float line_w = max(h * line_share, pixel_m * min_line_px);
	if (d_out > 0.0 && d_smoke > 0.0) {
		discard;
	}
	vec3 col = mix(smoke_color, smoke_inner_color, smoothstep(-aa * 3.0, aa * 3.0, -d_smoke - smoke_depth * h));
	// The smoke has its own thin ink edge.
	float smoke_edge = smoothstep(-line_w * 0.7 - aa, -line_w * 0.7 + aa, d_smoke);
	col = mix(col, line_color, smoke_edge);
	float inside = 1.0 - smoothstep(-aa, aa, d_out);
	vec3 fire = red_color;
	fire = mix(fire, orange_color, 1.0 - smoothstep(-aa, aa, d_mid));
	fire = mix(fire, core_color * core_energy, 1.0 - smoothstep(-aa, aa, d_core));
	// The ink line round the fire's outer edge, and a thin darker band of the body just inside it (the barrel's rim).
	float line = smoothstep(-line_w - aa, -line_w + aa, d_out);
	float band = smoothstep(-line_w * 2.2 - aa, -line_w * 2.2 + aa, d_out) * (1.0 - line);
	fire = mix(fire, outer_color, band);
	fire = mix(fire, line_color, line);
	col = mix(col, fire * energy, inside);
	ALBEDO = col;
}
