shader_type spatial;
// The brush pass (round 4, R4-INK; docs/video/P1.md): the world's pixels turned into a painted background before the lines are drawn, the
// way an anime background is painted and the characters are cel on top. A full-screen quad in the transparent pass (video/ink/brush_quad.gd)
// at the head of the transparent queue, so the haze, steam, flames, shafts and mattes draw over it and the screen ink's lines draw over it
// too. (A CompositorEffect before the transparent pass was tried first: with MSAA its writes to the resolved colour are lost.)
//
// What it does to a world pixel:
//  - AN ANISOTROPIC KUWAHARA (Kyprianidis et al. 2009): a structure tensor of the colour (a 5x5 grid of the blurred screen's luminance), and the
//    eight-sector filter on an ellipse that follows it, so the strokes run along the edges and a wall reads as a few flat planes, not a texture.
//    The radius grows with the depth, with the distance from the shot's focus and toward the frame's edge: detail falls off as a painter's does.
//  - A SOFT POSTERIZE of the luminance in bands of a few tenths of a stop, the band edges moved by a world-anchored noise so they are hand-cut.
//  - A HAND WOBBLE: the lookup displaced by a low-frequency noise of the WORLD position (from the depth buffer), a few pixels at 1080p, so a
//    ruler-straight roofline or pole is drawn and the wobble holds still on the world when the camera moves.
// Left alone: the sky (depth 0) and characters (the edge tag, roughness 0), which are never brushed. A character is never sampled into a world
// pixel (it would bleed into the background as a halo), nor is a tap across a large depth step (a pole's edge stays hard): such a tap is replaced
// by the pixel's own colour.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// The radius in pixels at 1080p: at the lens (r_near) to beyond depth_far_m (r_far, a smooth step from depth_near_m), plus focus_gain far from the
// shot's focus (the relative distance), plus edge_gain toward the frame's edge (from edge_start of the radius, 0..1), at most r_max.
uniform float r_near : hint_range(0.0, 16.0) = 2.0;
uniform float r_far : hint_range(0.0, 24.0) = 7.0;
uniform float depth_near_m : hint_range(0.0, 60.0) = 3.0;
uniform float depth_far_m : hint_range(0.5, 120.0) = 22.0;
uniform float focus_gain : hint_range(0.0, 12.0) = 2.0;
uniform float edge_gain : hint_range(0.0, 12.0) = 2.0;
uniform float edge_start : hint_range(0.0, 1.0) = 0.55;
uniform float r_max : hint_range(1.0, 24.0) = 10.0;
uniform float focus_m = 4.0;
// The ellipse's roundness (1 = elongated along an edge as the tensor says, larger = rounder), the sector weight's exponent, the taps from the
// middle to the edge of the window, and the mip level the tensor is read at.
uniform float aniso_alpha : hint_range(0.2, 8.0) = 1.0;
uniform float sharpness : hint_range(1.0, 16.0) = 8.0;
uniform int tap_half : hint_range(2, 8) = 5;
uniform float tensor_lod : hint_range(0.0, 3.0) = 1.0;
// The hand wobble (pixels at 1080p; the world cell in metres) and the depth step beyond which a tap is not sampled.
uniform float wobble_px : hint_range(0.0, 12.0) = 3.0;
uniform float wobble_cell_m : hint_range(0.2, 20.0) = 1.6;
uniform float depth_reject : hint_range(0.01, 1.0) = 0.12;
// The posterize: the band in stops (0 = off), the edge softness, the share applied, and the world noise on the edges (a share of a band).
uniform float post_step : hint_range(0.0, 3.0) = 0.55;
uniform float post_soft : hint_range(0.0, 1.0) = 0.25;
uniform float post_mix : hint_range(0.0, 1.0) = 1.0;
uniform float post_noise : hint_range(0.0, 1.0) = 0.3;
uniform float post_cell_m : hint_range(0.1, 20.0) = 0.9;
// The thin-line fill: a dark line narrower than about twice `fill_near_px` (at the lens) to `fill_far_px` (far away), in pixels at 1080p, is
// filled with the darker of the two sides it runs between (a brick joint, a plank seam, a window mullion: the repeated detail), where a plane's
// edge or a big dark shape is not a valley and stays. `fill_amount` is its share (0 = off).
uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
uniform float fill_near_px : hint_range(0.0, 12.0) = 1.5;
uniform float fill_far_px : hint_range(0.0, 12.0) = 3.5;
uniform float fill_gate : hint_range(0.0, 0.5) = 0.05;
// 0 = the picture; 1 = the radius (red) and anisotropy (green); 2 = the orientation; 3 = the wobble's noise; 4 = the tags (red a character, green the world, blue the sky).
uniform int debug_view : hint_range(0, 4) = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash13(vec3 q) {
	q = fract(q * 0.1031);
	q += dot(q, q.zyx + 31.32);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The colour is filtered in a perceptual encoding (the linear HDR picture's variance is all highlights).
vec3 enc(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(0.4545));
}

vec3 dec(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

bool is_character(ivec2 q, ivec2 size) {
	vec4 nr = texelFetch(normal_tex, clamp(q, ivec2(0), size - 1), 0);
	return nr.a < 0.5 && length(nr.xyz * 2.0 - 1.0) > 0.5;
}

float depth_at(ivec2 q, ivec2 size) {
	return texelFetch(depth_tex, clamp(q, ivec2(0), size - 1), 0).r;
}

// The colour at `q` (encoded) with its thin dark line filled: along four orientations, a pixel darker than both sides at +-w pixels is a valley.
vec3 filled_colour(ivec2 q, ivec2 size, float w) {
	vec3 c = enc(texelFetch(screen_tex, clamp(q, ivec2(0), size - 1), 0).rgb);
	if (fill_amount <= 0.0 || w < 1.0) {
		return c;
	}
	float l = lum(c);
	float best = 0.0;
	vec3 fill = c;
	ivec2 offs[4] = ivec2[](ivec2(1, 0), ivec2(0, 1), ivec2(1, 1), ivec2(1, -1));
	int wi = int(round(w));
	for (int k = 0; k < 4; k++) {
		ivec2 o = offs[k] * wi;
		vec3 a = enc(texelFetch(screen_tex, clamp(q + o, ivec2(0), size - 1), 0).rgb);
		vec3 b = enc(texelFetch(screen_tex, clamp(q - o, ivec2(0), size - 1), 0).rgb);
		float la = lum(a);
		float lb = lum(b);
		float depth_of_valley = min(la, lb) - l;
		float strength = smoothstep(0.0, fill_gate, depth_of_valley);
		if (strength > best) {
			best = strength;
			fill = la < lb ? a : b;
		}
	}
	return mix(c, fill, best * fill_amount);
}

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	float d0 = depth_at(p, size);
	bool character = is_character(p, size);
	if (debug_view == 4) {
		ALBEDO = vec3(character ? 1.0 : 0.0, (!character && d0 > 0.0) ? 1.0 : 0.0, d0 <= 0.0 ? 1.0 : 0.0);
		ALPHA = 1.0;
	} else {
		if (d0 <= 0.0 || character) {
			discard;
		}
		float scale = VIEWPORT_SIZE.y / 1080.0;
		vec2 texel = 1.0 / vec2(size);
		vec4 vp4 = INV_PROJECTION_MATRIX * vec4((vec2(p) + 0.5) * texel * 2.0 - 1.0, d0, 1.0);
		vec3 vp = vp4.xyz / vp4.w;
		float z0 = max(-vp.z, 0.01);
		vec3 wp = (INV_VIEW_MATRIX * vec4(vp, 1.0)).xyz;

		// The radius, in pixels: with the depth, with the distance from the focus, toward the frame's edge.
		float r = mix(r_near, r_far, smoothstep(depth_near_m, max(depth_far_m, depth_near_m + 0.01), z0));
		float focus = max(focus_m, 0.5);
		r += focus_gain * smoothstep(0.15, 1.0, abs(z0 - focus) / focus);
		vec2 q = (vec2(p) + 0.5) * texel - 0.5;
		float radial = length(q * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)) / length(vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0) * 0.5);
		r += edge_gain * smoothstep(edge_start, 1.0, radial);
		r = min(r, r_max) * scale;

		// The hand wobble: the lookup displaced by a low-frequency noise of the world position (never onto a character or the sky).
		vec3 wq = wp / max(wobble_cell_m, 0.01);
		vec2 wob_n = vec2(vnoise(wq), vnoise(wq + vec3(17.3, 5.1, 9.7)));
		vec2 wob = (wob_n - 0.5) * 2.0 * wobble_px * scale;
		ivec2 centre = clamp(p + ivec2(round(wob)), ivec2(0), size - 1);
		if (is_character(centre, size) || depth_at(centre, size) <= 0.0) {
			centre = p;
		}
		float dc = depth_at(centre, size);
		float fill_w = mix(fill_near_px, fill_far_px, smoothstep(depth_near_m, max(depth_far_m, depth_near_m + 0.01), z0)) * scale;
		vec3 c0 = filled_colour(centre, size, fill_w);

		// The structure tensor: a 5x5 grid of the blurred screen's luminance, the gradient at the inner 3x3, smoothed.
		float h = exp2(tensor_lod);
		float lg[25];
		for (int j = 0; j < 5; j++) {
			for (int i = 0; i < 5; i++) {
				vec2 uv = (vec2(centre) + 0.5 + vec2(float(i - 2), float(j - 2)) * h) * texel;
				lg[j * 5 + i] = lum(enc(textureLod(screen_tex, uv, tensor_lod).rgb));
			}
		}
		float te = 0.0;
		float tf = 0.0;
		float tg = 0.0;
		for (int j = 1; j < 4; j++) {
			for (int i = 1; i < 4; i++) {
				float w = (i == 2 ? 2.0 : 1.0) * (j == 2 ? 2.0 : 1.0);
				float gx = lg[j * 5 + i + 1] - lg[j * 5 + i - 1];
				float gy = lg[(j + 1) * 5 + i] - lg[(j - 1) * 5 + i];
				te += w * gx * gx;
				tf += w * gx * gy;
				tg += w * gy * gy;
			}
		}
		float disc = sqrt((te - tg) * (te - tg) + 4.0 * tf * tf);
		float l1 = 0.5 * (te + tg + disc);
		float l2 = 0.5 * (te + tg - disc);
		float aniso = (l1 - l2) / max(l1 + l2, 0.00001);
		float phi = (l1 - l2) > 0.00001 ? atan(-tf, l1 - te) : 0.0;
		float alpha = max(aniso_alpha, 0.05);
		float ea = max(r * clamp((alpha + aniso) / alpha, 0.1, 2.0), 0.5);
		float eb = max(r * clamp(alpha / (alpha + aniso), 0.1, 2.0), 0.5);
		float cp = cos(phi);
		float sp = sin(phi);

		vec3 m[8];
		vec3 s[8];
		float ws[8];
		vec2 centres[8] = vec2[](vec2(1.0, 0.0), vec2(0.70710678, 0.70710678), vec2(0.0, 1.0), vec2(-0.70710678, 0.70710678),
				vec2(-1.0, 0.0), vec2(-0.70710678, -0.70710678), vec2(0.0, -1.0), vec2(0.70710678, -0.70710678));
		for (int k = 0; k < 8; k++) {
			m[k] = vec3(0.0);
			s[k] = vec3(0.0);
			ws[k] = 0.0;
		}
		int n = tap_half;
		float step_px = max(1.0, max(ea, eb) / float(n));
		for (int j = -n; j <= n; j++) {
			for (int i = -n; i <= n; i++) {
				vec2 off = vec2(float(i), float(j)) * step_px;
				// into the ellipse's frame: rotated by -phi, scaled so the rim is 0.5
				vec2 v = vec2((cp * off.x + sp * off.y) / (2.0 * ea), (-sp * off.x + cp * off.y) / (2.0 * eb));
				float r2 = dot(v, v);
				if (r2 > 0.25) {
					continue;
				}
				ivec2 tq = clamp(centre + ivec2(round(off)), ivec2(0), size - 1);
				vec3 col = c0;
				float dq = depth_at(tq, size);
				if (dq > 0.0 && abs(dq - dc) <= depth_reject * dc && !is_character(tq, size)) {
					col = filled_colour(tq, size, fill_w);
				}
				float g = exp(-9.0 * r2);
				vec2 u = r2 > 0.000001 ? v * inversesqrt(r2) : vec2(1.0, 0.0);
				for (int k = 0; k < 8; k++) {
					float w = clamp((dot(u, centres[k]) - 0.8315) / 0.1685, 0.0, 1.0);
					w = r2 > 0.000001 ? w * w * g : g * 0.125;
					m[k] += col * w;
					s[k] += col * col * w;
					ws[k] += w;
				}
			}
		}
		vec3 acc = vec3(0.0);
		float acc_w = 0.0;
		for (int k = 0; k < 8; k++) {
			if (ws[k] <= 0.00001) {
				continue;
			}
			vec3 mean = m[k] / ws[k];
			vec3 variance = max(s[k] / ws[k] - mean * mean, vec3(0.0));
			float sigma = sqrt(variance.r + variance.g + variance.b) * 255.0;
			float w = 1.0 / (1.0 + pow(sigma, sharpness));
			acc += mean * w;
			acc_w += w;
		}
		vec3 lin = dec(acc_w > 0.0 ? acc / acc_w : c0);

		// The soft posterize: the luminance in stops, in bands of `post_step`, the edges moved by a world noise so they are cut by hand.
		if (post_step > 0.0 && post_mix > 0.0) {
			float l = max(lum(lin), 0.00005);
			float band = log2(l) / post_step;
			band += (vnoise(wp / max(post_cell_m, 0.01) + vec3(3.7, 11.1, 5.3)) - 0.5) * 2.0 * post_noise;
			float fl = floor(band);
			float soft = max(post_soft, 0.001) * 0.5;
			float snapped = fl + smoothstep(0.5 - soft, 0.5 + soft, band - fl);
			lin *= mix(1.0, exp2(snapped * post_step) / l, post_mix);
		}

		if (debug_view == 1) {
			lin = vec3(r / (r_max * scale + 0.0001), aniso, 0.0);
		} else if (debug_view == 2) {
			lin = vec3(0.5 + 0.5 * cp, 0.5 + 0.5 * sp, aniso);
		} else if (debug_view == 3) {
			lin = vec3(wob_n, 0.0);
		}
		ALBEDO = lin;
		ALPHA = 1.0;
	}
}
