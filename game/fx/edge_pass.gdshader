shader_type spatial;
// The look's edge pass (Milestone 4, M4-plan A8): ink lines on the environment, from the depth
// and the normals the renderer already makes. It is a full-screen quad (game/fx/look_post.gd)
// that outputs ALBEDO = ink and ALPHA = the line, and never reads the screen texture: a screen
// copy is taken before the transparent pass and would erase the contact flash drawn just before.
//
// - Depth lines draw on the NEARER side of a depth step, from the second difference of 1/z, so
//   a plane never draws, however steep, and a silhouette gets one line, `width_px` wide.
// - Crease lines (collars, brims, soles, wall-to-floor) come from the normals, only where the
//   depth is continuous, and never across a roughness class.
// - The character mask. A toon material writes ROUGHNESS = 0 on a character (the "edge tag"),
//   1 elsewhere, and the buffer carries it. The hull draws a character's silhouette, so no line
//   is drawn within `mask_px` of a tagged pixel (a ring of 8 taps: the unshaded hull writes
//   roughness 1, so one tap is not enough). The sky is roughness 0 in the buffer, with an empty
//   (zero) normal, which is how it is told from a character and counted as 1.
// - Everything is in whole pixels, scaled by the viewport height over 1080.
//
// With EDGE_FINISH defined (look_post.gd, the trailer profile only; M7 G1) the same pass is also the frame's finish, still with no screen
// read: its lines wobble by a pixel or so and break in places, and a grain is laid over the frame through the quad's own alpha, all new on each
// beat (twos); see edge_finish.gdshaderinc.
//
// With EDGE_DEPTH_ONLY defined (look_post.gd prepends it for the cheap fallback) the shader
// reads no normal buffer: the renderer then makes none, and there are no creases and no mask.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
#ifndef EDGE_DEPTH_ONLY
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
#endif

#ifdef EDGE_FINISH
#include "res://game/fx/edge_finish.gdshaderinc"
#endif

// The one ink (HudStyle.INK); every number below is fed from Tuning by look_post.gd.
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float width_px : hint_range(0.5, 4.0) = 1.25;
uniform float depth_threshold : hint_range(0.02, 1.0) = 0.08;
uniform float normal_threshold : hint_range(0.05, 1.0) = 0.35;
uniform float fade_start_m : hint_range(1.0, 200.0) = 25.0;
uniform float fade_end_m : hint_range(2.0, 300.0) = 60.0;
uniform float mask_px : hint_range(0.0, 16.0) = 6.0;
uniform bool character_mask = true;
// 0 = the picture; 1 roughness; 2 normals; 3 distance; 4 character mask; 5 depth lines; 6 creases.
uniform int debug_view : hint_range(0, 6) = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Built-ins cannot be read in a helper, so the inverse projection comes in as an argument.
float view_distance(ivec2 p, ivec2 size, mat4 inv_proj) {
	p = clamp(p, ivec2(0), size - 1);
	float d = texelFetch(depth_tex, p, 0).r;
	vec2 uv = (vec2(p) + 0.5) / vec2(size);
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return max(-v.z / v.w, 0.001);
}

bool is_sky(ivec2 p, ivec2 size) {
	p = clamp(p, ivec2(0), size - 1);
	return texelFetch(depth_tex, p, 0).r <= 0.0;
}

#ifndef EDGE_DEPTH_ONLY
// Roughness of a pixel, the sky counted as 1: the buffer is cleared to a zero normal there (probed),
// and a pixel whose normal is empty (a silhouette pixel of the MSAA resolve can keep the clear
// value beside real depth) counts as 1 too. One fetch, so the mask's ring stays cheap.
float roughness_at(ivec2 p, ivec2 size) {
	vec4 nr = texelFetch(normal_tex, clamp(p, ivec2(0), size - 1), 0);
	return length(nr.xyz * 2.0 - 1.0) < 0.5 ? 1.0 : nr.a;
}
#endif

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	float scale = VIEWPORT_SIZE.y / 1080.0;
	ivec2 p = ivec2(FRAGCOORD.xy);
#ifdef EDGE_FINISH
	p += edge_finish_shift(FRAGCOORD.xy, TIME, scale);
#endif
	int k = max(1, int(round(width_px * scale)));
	mat4 ip = INV_PROJECTION_MATRIX;

	// Depth: the second difference of 1/z along x and y, relative to this pixel's own 1/z.
	float z0 = view_distance(p, size, ip);
	float w0 = 1.0 / z0;
	float wl = 1.0 / view_distance(p + ivec2(-k, 0), size, ip);
	float wr = 1.0 / view_distance(p + ivec2(k, 0), size, ip);
	float wu = 1.0 / view_distance(p + ivec2(0, -k), size, ip);
	float wd = 1.0 / view_distance(p + ivec2(0, k), size, ip);
	float lap_x = (w0 - 0.5 * (wl + wr)) / w0;
	float lap_y = (w0 - 0.5 * (wu + wd)) / w0;
	float near_side = max(lap_x, lap_y);
	float step_any = max(abs(lap_x), abs(lap_y));
	float depth_line = smoothstep(depth_threshold * 0.5, depth_threshold, near_side);
	float depth_gate = 1.0 - smoothstep(depth_threshold * 0.5, depth_threshold, step_any);

	float rough0 = 1.0;
	float mask = 0.0;
	float crease_line = 0.0;
#ifndef EDGE_DEPTH_ONLY
	vec4 nr0 = texelFetch(normal_tex, clamp(p, ivec2(0), size - 1), 0);
	rough0 = roughness_at(p, size);
	// Creases: forward differences (one pixel line), never to the sky, never across a roughness
	// class, only where the depth is continuous.
	float crease_raw = 0.0;
	vec3 n0 = nr0.xyz * 2.0 - 1.0;
	if (!is_sky(p, size) && length(n0) > 0.5) {
		n0 = normalize(n0);
		ivec2 taps[2] = ivec2[](ivec2(k, 0), ivec2(0, k));
		float sharp = 0.0;
		for (int i = 0; i < 2; i++) {
			ivec2 q = clamp(p + taps[i], ivec2(0), size - 1);
			vec4 nrq = texelFetch(normal_tex, q, 0);
			vec3 nq = nrq.xyz * 2.0 - 1.0;
			if (!is_sky(q, size) && length(nq) > 0.5 && abs(nrq.a - nr0.a) < 0.5) {
				sharp = max(sharp, 1.0 - dot(n0, normalize(nq)));
			}
		}
		crease_raw = smoothstep(normal_threshold * 0.5, normal_threshold, sharp) * depth_gate;
	}
	// The character mask. Only a pixel that has a line to lose looks at the ring (or all of them
	// for the mask's debug view): most pixels have none.
	if (character_mask) {
		if (rough0 < 0.5) {
			mask = 1.0;
		} else if (depth_line > 0.0 || crease_raw > 0.0 || debug_view == 4) {
			int mk = int(round(mask_px * scale));
			vec2 dirs[8] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
					vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, -0.7071));
			for (int i = 0; i < 8 && mk > 0; i++) {
				if (roughness_at(p + ivec2(round(dirs[i] * float(mk))), size) < 0.5) {
					mask = 1.0;
				}
			}
		}
	}
	// Inside a character a crease draws (collars, brims); just outside one it does not (the hull is
	// the line).
	crease_line = (mask > 0.5 && rough0 >= 0.5) ? 0.0 : crease_raw;
#endif
	if (mask > 0.5) {
		depth_line = 0.0;
	}
	float fade = 1.0 - smoothstep(fade_start_m, max(fade_end_m, fade_start_m + 0.01), z0);

	vec3 color = ink;
	float alpha = max(depth_line, crease_line) * fade;
	if (debug_view == 1) {
		color = vec3(rough0);
		alpha = 1.0;
	}
#ifndef EDGE_DEPTH_ONLY
	else if (debug_view == 2) {
		color = nr0.xyz;
		alpha = 1.0;
	}
#endif
	else if (debug_view == 3) {
		color = vec3(fract(z0 * 0.1));
		alpha = 1.0;
	} else if (debug_view == 4) {
		color = vec3(1.0, 0.0, 0.0);
		alpha = mask * 0.6;
	} else if (debug_view == 5) {
		color = vec3(1.0, 0.0, 1.0);
		alpha = depth_line * fade;
	} else if (debug_view == 6) {
		color = vec3(1.0, 0.0, 1.0);
		alpha = crease_line * fade;
	}
#ifdef EDGE_FINISH
	if (debug_view == 0) {
		alpha *= edge_finish_break(FRAGCOORD.xy, TIME, scale);
		vec4 finished = edge_finish(FRAGCOORD.xy, TIME, scale, color, alpha);
		color = finished.rgb;
		alpha = finished.a;
	}
#endif
	ALBEDO = color;
	ALPHA = alpha;
}
