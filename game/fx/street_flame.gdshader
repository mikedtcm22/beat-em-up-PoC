// Ported from the video session's flame_painted.gdshader (branch video/cinematic-trailer) for M7 T16a: the burn barrel's flame; StreetFx writes `slot`.
shader_type spatial;
// A painted fire (LD-WORLD3; P1.md, "Fire in the barrel"): a few tongues of flame, each a teardrop with an anti-aliased hard edge, in three nested
// values (a deep red-orange body, an orange middle, a pale yellow core) with a darker line on the outer edge. The tongues' heights and leans are
// re-rolled at 12 frames a second from `slot` (the rig writes the frame number's slot), so the flicker is drawn, never smooth and never time-driven.
// A cylindrical billboard (turns about the vertical to face the camera); unshaded, so it is the brightest thing in the frame.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 outer_color : source_color = vec3(0.9, 0.22, 0.05);
uniform vec3 mid_color : source_color = vec3(1.0, 0.55, 0.1);
uniform vec3 core_color : source_color = vec3(1.0, 0.9, 0.5);
uniform vec3 line_color : source_color = vec3(0.35, 0.06, 0.03);
uniform float slot = 0.0;
uniform float seed = 1.0;
uniform float energy : hint_range(0.0, 3.0) = 1.4;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = vec3(cam.x - origin.x, 0.0, cam.z - origin.z);
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	vec3 world = origin + right * VERTEX.x + vec3(0.0, 1.0, 0.0) * VERTEX.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Signed distance (negative inside) to one tongue at this scale: a teardrop of half-width w at the root, tapering to a point at height h, leaning.
float tongue(vec2 p, float cx, float h, float w, float lean) {
	float y = p.y;
	float t = clamp(y / max(h, 0.001), 0.0, 1.0);
	float half_w = w * pow(1.0 - t, 0.55) * smoothstep(0.0, 0.08, y + 0.02);
	float x = p.x - cx - lean * y * y;
	float d = abs(x) - half_w;
	return max(d, y - h);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0, 1.0 - UV.y);
	float d_outer = 10.0;
	float d_mid = 10.0;
	float d_core = 10.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float h1 = hash12(vec2(fi * 7.1 + seed, slot * 1.3));
		float h2 = hash12(vec2(fi * 3.7 + seed * 2.0, slot * 0.7 + 5.0));
		float h3 = hash12(vec2(fi * 5.3 + seed * 3.0, slot * 1.9 + 11.0));
		float cx = (fi / 4.0 - 0.5) * 1.1 + (h3 - 0.5) * 0.25;
		float h = 0.55 + 0.45 * h1;
		h *= 1.0 - 0.35 * abs(cx);
		float w = 0.2 + 0.1 * h2;
		float lean = (h2 - 0.5) * 0.9;
		d_outer = min(d_outer, tongue(p, cx, h, w, lean));
		d_mid = min(d_mid, tongue(p, cx * 0.9, h * 0.72, w * 0.72, lean * 0.8));
		d_core = min(d_core, tongue(p, cx * 0.8, h * 0.4, w * 0.45, lean * 0.6));
	}
	float aa = max(fwidth(d_outer) * 1.2, 0.004);
	float a_outer = 1.0 - smoothstep(-aa, aa, d_outer);
	float a_mid = 1.0 - smoothstep(-aa, aa, d_mid);
	float a_core = 1.0 - smoothstep(-aa, aa, d_core);
	float rim = (1.0 - smoothstep(-0.07 - aa, -0.07 + aa, d_outer)) ;
	vec3 col = mix(line_color, outer_color, rim);
	col = mix(col, mid_color, a_mid);
	col = mix(col, core_color, a_core);
	ALBEDO = col * energy;
	ALPHA = a_outer;
}
