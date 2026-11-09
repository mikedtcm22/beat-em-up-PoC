shader_type spatial;
// A plume of steam, drawn (R4-WORLD; P1.md, "Steam and smoke as drawn shapes"): a few big lobes in a curling column, each a flat cel shape in two values
// (a light top, a darker underside) with a clean edge and an ink line on the shadow side only. It rises slowly and is redrawn on twos: `slot` is the shot's
// frame at the look's flicker rate (12 a second), written by the rig, never the clock, and each new slot nudges the edge's bumps a little (a hand redrawing it).
// A cylindrical billboard (turns about the vertical to face the camera), drawn in the transparent pass, hidden by the depth test behind real geometry.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 light_color : source_color = vec3(0.55, 0.62, 0.86);
uniform vec3 dark_color : source_color = vec3(0.26, 0.31, 0.55);
uniform vec3 line_color : source_color = vec3(0.03, 0.04, 0.1);
uniform float light_alpha : hint_range(0.0, 1.0) = 0.72;
uniform float dark_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float seed = 1.0;
// The shot's frame at 12 fps (the rig writes it); `rate` is how far a lobe's life a slot moves it, so a plume's life is 1 / (rate * 12) seconds.
uniform float slot = 0.0;
uniform float rate : hint_range(0.001, 0.1) = 0.012;
// The card's size in metres (the shapes are drawn in metres), and the number of lobes in the column.
uniform vec2 card_m = vec2(1.6, 3.2);
uniform int lobes : hint_range(3, 9) = 6;
// The widest lobe's radius (m), how far the column curls sideways (m), and the share of a lobe's radius its bumps swing.
uniform float lobe_r_m : hint_range(0.1, 1.0) = 0.38;
uniform float curl_m : hint_range(0.0, 1.0) = 0.3;
uniform float bump : hint_range(0.0, 0.5) = 0.2;
// The shadow side: how far the light's copy of the shape is shifted (m, to the lower right), the ink line's width (m), and the share of the edge that gets a line.
uniform float shade_m : hint_range(0.02, 0.5) = 0.15;
uniform float line_m : hint_range(0.005, 0.1) = 0.03;
uniform float line_share : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = vec3(cam.x - origin.x, 0.0, cam.z - origin.z);
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	vec3 world = origin + right * VERTEX.x + vec3(0.0, 1.0, 0.0) * (VERTEX.y + card_m.y * 0.5);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float hash11(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

// One lobe of the column: returns the signed distance (m) of `q` from its edge, and writes its centre and radius.
float lobe(vec2 q, float i, float ph, float jit, out vec2 centre) {
	float u = ph + i / float(lobes);
	float s = fract(u);
	float id = i + float(lobes) * floor(u) + seed * 7.0;
	float hx = hash11(id);
	float hr = hash11(id * 1.7 + 3.0);
	float ht = hash11(id * 2.3 + 8.0);
	// The lobe is born small at the vent, swells as it rises and thins out at the top.
	float size = lobe_r_m * (0.45 + 0.75 * pow(s, 0.55)) * (0.75 + 0.5 * hr) * smoothstep(0.0, 0.1, s) * (1.0 - smoothstep(0.7, 1.0, s));
	float sway = curl_m * s * sin(s * 4.2 + seed * 2.0 + hx * 1.6);
	centre = vec2(sway + (hx - 0.5) * lobe_r_m * 0.9 * s, s * card_m.y * 0.86 + 0.1);
	vec2 d = q - centre;
	float ang = atan(d.y, d.x);
	float r = size * (1.0 + bump * sin(ang * 3.0 + ht * 6.283 + jit) + bump * 0.55 * sin(ang * 5.0 + hr * 6.283 - jit * 1.3));
	return length(d) - r;
}

void fragment() {
	vec2 q = vec2((UV.x - 0.5) * card_m.x, (1.0 - UV.y) * card_m.y);
	float ph = slot * rate;
	// The boil: each slot's edge differs a little from the last, a hand redrawing the shape every second frame.
	float jit = (hash11(slot + seed * 13.0) - 0.5) * 0.5;
	float d = 1e3;
	float d_lit = 1e3;
	vec2 near_c = vec2(0.0);
	for (int k = 0; k < 9; k++) {
		if (k >= lobes) {
			break;
		}
		vec2 c;
		float dk = lobe(q, float(k), ph, jit, c);
		if (dk < d) {
			d = dk;
			near_c = c;
		}
		vec2 c2;
		d_lit = min(d_lit, lobe(q + vec2(shade_m, -shade_m * 1.25), float(k), ph, jit, c2));
	}
	float aa = max(fwidth(d) * 1.1, 0.004);
	float body = 1.0 - smoothstep(-aa, aa, d);
	float lit = 1.0 - smoothstep(-aa, aa, d_lit);
	// The ink line: a band just inside the edge, on the underside (away from the light) and where a noise lets it run, thinning to nothing at its ends.
	vec2 n = normalize(q - near_c + vec2(0.0001));
	float under = dot(n, normalize(vec2(0.55, -0.85)));
	float run = under + (hash11(floor(atan(n.y, n.x) * 2.4) + seed * 5.0 + floor(near_c.y * 3.0)) - 0.5) * 1.1;
	float gate = smoothstep(1.0 - 2.0 * line_share - 0.2, 1.0 - 2.0 * line_share + 0.3, run + 0.5);
	float w = line_m * gate;
	float line = smoothstep(-w - aa, -w + aa, d) * body * step(0.0005, w);
	vec3 fill = mix(dark_color, light_color, lit);
	float fill_a = mix(dark_alpha, light_alpha, lit);
	ALBEDO = mix(fill, line_color, line);
	ALPHA = body * mix(fill_a, 0.95, line);
}
