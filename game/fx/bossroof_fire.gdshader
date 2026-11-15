shader_type spatial;
// The boss roof's fire wall (M7 e-bossroof): a cloud of flat tones, a few big columns of stacked lobes whose heights are re-rolled on twos
// (`slot`, written by BossroofFx, never the clock). From the outside in: a plum smoke over the fire, the outer sheet, red, orange and a hot
// core (HDR, so only it blooms), each tone one hard edge, with a dark line on the fire's outer edge. A cylindrical billboard (turns about the
// vertical to face the camera), opaque where there is fire (a pixel outside it is discarded), unshaded and fog-free: it is the far light.
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
uniform vec3 depth_shares = vec3(0.025, 0.06, 0.11);
uniform float energy : hint_range(0.0, 3.0) = 1.0;
uniform float core_energy : hint_range(0.0, 6.0) = 2.0;
// The line's width as a share of the height, never thinner than min_line_px pixels.
uniform float line_share : hint_range(0.0, 0.05) = 0.006;
uniform float min_line_px : hint_range(0.0, 6.0) = 2.0;
// How much of the card's height the columns reach, how wide the columns are as a share of their spacing and how far the edge bumps (a share of the height).
uniform float reach : hint_range(0.1, 1.0) = 0.62;
uniform float smoke_rise : hint_range(0.0, 0.6) = 0.12;
uniform float smoke_grow : hint_range(1.0, 2.5) = 1.25;
uniform float bump : hint_range(0.0, 0.1) = 0.02;
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

void fragment() {
	vec2 q = vec2((UV.x - 0.5) * card_m.x, (1.0 - UV.y) * card_m.y);
	float h = card_m.y;
	float spacing = card_m.x / float(COLUMNS);
	float d_fire = 1e4;
	float d_smoke = 1e4;
	for (int i = 0; i < COLUMNS; i++) {
		float fi = float(i);
		float keep = hash12(vec2(fi * 3.1 + seed, 7.0));
		float roll = hash12(vec2(fi * 5.7 + seed * 2.0, slot * 0.37));
		float cx = (fi + 0.5 - float(COLUMNS) * 0.5) * spacing + (keep - 0.5) * spacing * 0.5;
		// The column's height: its own steady share, re-rolled a little each drawing.
		float ch = h * reach * (0.5 + 0.35 * keep + 0.15 * roll);
		float r = spacing * (0.7 + 0.3 * keep);
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float cy = ch * (0.18 + 0.36 * fk);
			float rr = r * (1.0 - 0.28 * fk);
			vec2 c = vec2(cx + (roll - 0.5) * r * 0.25 * fk, cy);
			d_fire = min(d_fire, length(q - c) - rr);
			// The smoke: the same lobe, higher and bigger.
			d_smoke = min(d_smoke, length(q - c - vec2(0.0, h * smoke_rise * (0.4 + 0.3 * fk))) - rr * smoke_grow);
		}
	}
	// The edge curls: a slow wave that shifts a little each drawing.
	float curl = bump * h * sin(q.x * 0.22 + q.y * 0.31 + hash12(vec2(slot, seed)) * 6.283);
	d_fire += curl;
	d_smoke += curl * 1.4;
	// The base: the foot of the wall is solid fire.
	d_fire = min(d_fire, q.y - h * 0.07);
	d_smoke = min(d_smoke, q.y - h * 0.12);
	float aa = max(fwidth(d_fire) * 1.1, 0.001);
	float pixel_m = max(fwidth(q.x), fwidth(q.y));
	float line_w = max(h * line_share, pixel_m * min_line_px);
	if (d_smoke > 0.0 && d_fire > 0.0) {
		discard;
	}
	vec3 col = mix(smoke_color, smoke_inner_color, smoothstep(-aa * 3.0, aa * 3.0, -d_smoke - smoke_depth * h));
	// The smoke has its own thin edge.
	float smoke_edge = smoothstep(-line_w - aa, -line_w + aa, d_smoke);
	col = mix(col, line_color, smoke_edge * step(0.0, d_fire));
	float inside = 1.0 - smoothstep(-aa, aa, d_fire);
	float depth = -d_fire;
	vec3 fire = outer_color;
	fire = mix(fire, red_color, smoothstep(-aa, aa, depth - depth_shares.x * h));
	fire = mix(fire, orange_color, smoothstep(-aa, aa, depth - depth_shares.y * h));
	fire = mix(fire, core_color * core_energy, smoothstep(-aa, aa, depth - depth_shares.z * h));
	// The ink line round the fire's outer edge.
	float line = smoothstep(-line_w - aa, -line_w + aa, d_fire);
	fire = mix(fire, line_color, line);
	col = mix(col, fire * energy, inside);
	ALBEDO = col;
}
