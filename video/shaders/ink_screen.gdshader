shader_type spatial;
// The video's screen-space ink (Phase 0 spike, PLAN.md section 4, Plan A part 3). A full-screen quad in
// Forward+, built on game/fx/edge_pass.gdshader: lines from the depth's second difference (a silhouette
// is drawn once, on its nearer side) and from normal creases, never reading the screen texture.
//
// What it adds to the game's edge pass:
//  - LINE WEIGHT FOLLOWS THE LIGHT. The surface's light factor is the best of the key lamp, the rim light
//    and the moon, each as dot(normal, direction to the light) times a distance falloff, from the light
//    positions the spike script sets every frame (view space). A surface that faces away from every
//    light gets the heavy width at full strength; one that faces the key gets the thin width, faded to
//    `lit_floor` or lost.
//  - DISTANCE: the line fades out between fade_start_m and fade_end_m, and the environment keeps only its
//    major silhouettes: its depth threshold grows with the distance (env_major_m), and its creases stop.
//  - TINT: the ink is a warm brown-black (never pure black).
//  - WOBBLE: the alpha is broken by a noise anchored in WORLD space (from the depth), so the line looks
//    inked by hand and never swims with the camera.
// A character is told from the world by the edge tag (ROUGHNESS 0 on a character), as in edge_pass.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec3 ink : source_color = vec3(0.09, 0.055, 0.05);
uniform float alpha_max : hint_range(0.0, 1.0) = 0.96;
uniform float width_thin_px : hint_range(0.5, 6.0) = 1.0;
uniform float width_heavy_px : hint_range(0.5, 8.0) = 3.2;
uniform float lit_lost : hint_range(-1.0, 1.0) = 0.55;
uniform float lit_full : hint_range(-1.0, 1.0) = -0.1;
uniform float lit_floor : hint_range(0.0, 1.0) = 0.1;
uniform float depth_threshold : hint_range(0.02, 1.0) = 0.07;
uniform float normal_threshold : hint_range(0.05, 1.0) = 0.45;
uniform float env_major_m : hint_range(0.5, 40.0) = 8.0;
uniform float fade_start_m : hint_range(1.0, 100.0) = 10.0;
uniform float fade_end_m : hint_range(2.0, 200.0) = 40.0;
uniform float wobble : hint_range(0.0, 1.0) = 0.25;
uniform float wobble_scale : hint_range(0.5, 40.0) = 9.0;
// The lights, in VIEW space: xyz the position, w the range in metres (0 = off). The moon is a direction.
uniform vec4 key_view = vec4(0.0, 3.0, -2.0, 9.0);
uniform vec4 rim_view = vec4(0.0, 2.0, -4.0, 5.0);
uniform vec3 moon_dir_view = vec3(0.0, 0.7, 0.7);
uniform float moon_share : hint_range(0.0, 1.0) = 0.3;
// How strongly a character's creases draw (0 = silhouettes only).
uniform float crease_gain : hint_range(0.0, 1.0) = 1.0;
// 0 = the picture; 1 = the light factor; 2 = the line width; 3 = the lines only.
uniform int debug_view : hint_range(0, 3) = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_pos(ivec2 p, ivec2 size, mat4 inv_proj) {
	p = clamp(p, ivec2(0), size - 1);
	float d = texelFetch(depth_tex, p, 0).r;
	vec2 uv = (vec2(p) + 0.5) / vec2(size);
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

float view_distance(ivec2 p, ivec2 size, mat4 inv_proj) {
	return max(-view_pos(p, size, inv_proj).z, 0.001);
}

bool is_sky(ivec2 p, ivec2 size) {
	p = clamp(p, ivec2(0), size - 1);
	return texelFetch(depth_tex, p, 0).r <= 0.0;
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// How much light a surface at view position `v` with normal `n` gets, 0 to 1: the best of the key, the rim and the moon.
float light_factor(vec3 v, vec3 n) {
	float best = 0.0;
	if (key_view.w > 0.0) {
		vec3 to = key_view.xyz - v;
		float d = length(to);
		best = max(best, max(dot(n, to / max(d, 0.001)), 0.0) * (1.0 - smoothstep(0.35 * key_view.w, key_view.w, d)));
	}
	if (rim_view.w > 0.0) {
		vec3 to = rim_view.xyz - v;
		float d = length(to);
		best = max(best, max(dot(n, to / max(d, 0.001)), 0.0) * (1.0 - smoothstep(0.35 * rim_view.w, rim_view.w, d)));
	}
	best = max(best, moon_share * max(dot(n, moon_dir_view), 0.0));
	return clamp(best, 0.0, 1.0);
}

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	float scale = VIEWPORT_SIZE.y / 1080.0;
	mat4 ip = INV_PROJECTION_MATRIX;

	vec3 v0 = view_pos(p, size, ip);
	float z0 = max(-v0.z, 0.001);
	vec4 nr0 = texelFetch(normal_tex, clamp(p, ivec2(0), size - 1), 0);
	vec3 n0 = nr0.xyz * 2.0 - 1.0;
	bool has_normal = !is_sky(p, size) && length(n0) > 0.5;
	bool character = nr0.a < 0.5 && has_normal;
	n0 = has_normal ? normalize(n0) : vec3(0.0, 0.0, 1.0);

	// The weight: lit surface -> thin and lost, surface facing away from every light -> heavy and full.
	float lit = light_factor(v0, n0);
	// lit is 0..1 (the light's share); map the author's -1..1 thresholds onto it by treating them as
	// (2 * lit - 1), so a surface square to the key is 1 and a surface edge-on is 0 -> -1.
	float lf = 2.0 * lit - 1.0;
	float heavy_t = smoothstep(lit_lost, lit_full, lf);
	float width = mix(width_thin_px, width_heavy_px, heavy_t);
	float strength = mix(lit_floor, 1.0, heavy_t);
	int k = max(1, int(round(width * scale)));

	// Depth lines (as edge_pass): the second difference of 1/z, on the nearer side of a step.
	float w0 = 1.0 / z0;
	float wl = 1.0 / view_distance(p + ivec2(-k, 0), size, ip);
	float wr = 1.0 / view_distance(p + ivec2(k, 0), size, ip);
	float wu = 1.0 / view_distance(p + ivec2(0, -k), size, ip);
	float wd = 1.0 / view_distance(p + ivec2(0, k), size, ip);
	float lap_x = (w0 - 0.5 * (wl + wr)) / w0;
	float lap_y = (w0 - 0.5 * (wu + wd)) / w0;
	float near_side = max(lap_x, lap_y);
	float step_any = max(abs(lap_x), abs(lap_y));
	// The environment keeps only its major steps, more of them dropped the further away.
	float thr = depth_threshold * (character ? 1.0 : 1.0 + z0 / env_major_m);
	float depth_line = smoothstep(thr * 0.5, thr, near_side);
	float depth_gate = 1.0 - smoothstep(thr * 0.5, thr, step_any);

	// Creases from the normals, where the depth is continuous: characters, and the world only up close.
	float crease_line = 0.0;
	if (has_normal && (character || z0 < env_major_m)) {
		float sharp = 0.0;
		ivec2 taps[2] = ivec2[](ivec2(k, 0), ivec2(0, k));
		for (int i = 0; i < 2; i++) {
			ivec2 q = clamp(p + taps[i], ivec2(0), size - 1);
			vec4 nrq = texelFetch(normal_tex, q, 0);
			vec3 nq = nrq.xyz * 2.0 - 1.0;
			if (!is_sky(q, size) && length(nq) > 0.5 && abs(nrq.a - nr0.a) < 0.5) {
				sharp = max(sharp, 1.0 - dot(n0, normalize(nq)));
			}
		}
		crease_line = smoothstep(normal_threshold * 0.5, normal_threshold, sharp) * depth_gate * (character ? crease_gain : 1.0);
	}

	float fade = 1.0 - smoothstep(fade_start_m, max(fade_end_m, fade_start_m + 0.01), z0);
	// A hand-inked break in the line, in world space.
	vec3 wp = (INV_VIEW_MATRIX * vec4(v0, 1.0)).xyz;
	float broken = mix(1.0, 0.35 + 0.65 * smoothstep(0.25, 0.7, vnoise(wp * wobble_scale)), wobble);
	float line = max(depth_line, crease_line);
	float alpha = line * strength * fade * broken * alpha_max;

	vec3 color = ink;
	if (debug_view == 1) {
		color = vec3(lit);
		alpha = 1.0;
	} else if (debug_view == 2) {
		color = vec3(width / 8.0);
		alpha = 1.0;
	} else if (debug_view == 3) {
		color = vec3(1.0);
		alpha = line;
	}
	ALBEDO = color;
	ALPHA = alpha;
}
