shader_type spatial;
// Flat haze layers (LD-WORLD; PLAN.md section 4 part 4) in place of an exact depth fog: a full-screen quad that reads the
// depth and lays up to three flat tints over the picture by DISTANCE BAND, each band's edge bent by a noise anchored in world
// space (a painted edge, never a ruler-straight depth contour and never swimming). A low flat mist layer lies on top of the
// ground by HEIGHT, the same way. Draws before the ink (render priority) so the lines stay on top.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
// Band k starts at start_m[k] metres (view distance) and is a flat tint colour[k] at alpha[k]. start 0 or less: off.
uniform vec3 band_start_m = vec3(9.0, 22.0, 44.0);
uniform vec4 band_color_1 : source_color = vec4(0.1, 0.12, 0.3, 0.2);
uniform vec4 band_color_2 : source_color = vec4(0.1, 0.12, 0.3, 0.35);
uniform vec4 band_color_3 : source_color = vec4(0.1, 0.12, 0.3, 0.5);
// The painted edge: how far the noise moves a band's edge (metres), its scale (cycles per metre) and the edge's softness (metres).
uniform float edge_wobble_m : hint_range(0.0, 20.0) = 3.0;
uniform float edge_scale : hint_range(0.01, 2.0) = 0.12;
uniform float edge_soft_m : hint_range(0.01, 4.0) = 0.25;
// Sky pixels (no depth): which share of the farthest band they take (0: the sky is left alone).
uniform float sky_share : hint_range(0.0, 1.0) = 0.0;
// The ground mist: below `mist_top` metres (world y; wobbling), a flat tint of this colour and alpha.
uniform float mist_top = -1000.0;
uniform vec4 mist_color : source_color = vec4(0.2, 0.2, 0.4, 0.3);
uniform float mist_wobble_m : hint_range(0.0, 4.0) = 0.5;
// Only the near part of the world is hazed, so a shot can keep its subject clear: bands begin after `clear_m`.
uniform float clear_m = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void fragment() {
	float depth = texelFetch(depth_tex, ivec2(FRAGCOORD.xy), 0).r;
	bool sky = depth <= 0.0;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 view = v.xyz / v.w;
	float dist = sky ? 100000.0 : length(view);
	vec3 wp = (INV_VIEW_MATRIX * vec4(view, 1.0)).xyz;
	vec4 result = vec4(0.0);
	if (!sky) {
		float n = vnoise3(wp * edge_scale) - 0.5;
		float d = dist + n * 2.0 * edge_wobble_m - clear_m;
		float soft = max(edge_soft_m, 0.0001);
		vec4 colors[3] = vec4[3](band_color_1, band_color_2, band_color_3);
		float starts[3] = float[3](band_start_m.x, band_start_m.y, band_start_m.z);
		for (int i = 0; i < 3; i++) {
			if (starts[i] > 0.0) {
				float k = smoothstep(starts[i] - soft, starts[i] + soft, d);
				result = mix(result, vec4(colors[i].rgb, colors[i].a), k * step(0.0001, colors[i].a));
			}
		}
		if (mist_top > -999.0) {
			float m = vnoise3(wp * vec3(edge_scale * 1.7, edge_scale * 0.6, edge_scale * 1.7) + 9.0) - 0.5;
			float top = mist_top + m * 2.0 * mist_wobble_m;
			float k = 1.0 - smoothstep(top - 0.12, top + 0.12, wp.y);
			vec4 mc = vec4(mist_color.rgb, mist_color.a * k);
			result = vec4(mix(result.rgb, mc.rgb, mc.a / max(mc.a + result.a * (1.0 - mc.a), 0.0001)), mc.a + result.a * (1.0 - mc.a));
		}
	} else if (sky_share > 0.0) {
		result = vec4(band_color_3.rgb, band_color_3.a * sky_share);
	}
	ALBEDO = result.rgb;
	ALPHA = result.a;
}
