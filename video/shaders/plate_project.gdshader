shader_type spatial;
// The plate quad (round 5, R5-PAINT; docs/video/P1.md): a Gemini plate, painted from a camera over a blockout, projected onto the world's pixels.
// A full-screen quad in the transparent pass, drawn right after the brush quad (they share the lowest render priority, and this one sits just
// nearer down the view, so it draws second) and before the contact shadows, haze, steam, flames and cues and the ink quad. Per pixel:
//  - a character (the normal buffer's roughness tag) is never touched: the actors are drawn in front of the painting;
//  - the world's position comes from the depth, and the plate camera's projection maps it to a uv (the sky: the view direction maps it);
//  - a depth test against the plate's own depth (tol_share of z plus tol_m, any of the five nearest texels): where it holds, the plate's colour;
//    where it fails inside the plate's frame (a surface the plate never saw), the plate's blurred mip, never the 3D look;
//    outside the plate's frame nothing is drawn, so the brush pass's picture shows;
//  - two plates: the first one that has the pixel wins.
// The plate's colour is written as it is (the Environment's tone mapper is linear). The plate's depth is plate_depth.gdshader's: 16 bits in red and green.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform sampler2D plate_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_a : filter_nearest, repeat_disable;
uniform mat4 view_a;
uniform vec2 tan_a = vec2(1.0, 0.5625);
uniform float far_a = 200.0;
uniform float valid_a : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D plate_b : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_b : filter_nearest, repeat_disable;
uniform mat4 view_b;
uniform vec2 tan_b = vec2(1.0, 0.5625);
uniform float far_b = 200.0;
uniform float valid_b : hint_range(0.0, 1.0) = 0.0;

uniform float tol_share : hint_range(0.0, 0.3) = 0.03;
uniform float tol_m : hint_range(0.0, 2.0) = 0.05;
uniform float blur_lod : hint_range(0.0, 10.0) = 5.0;
// 0 = the picture; 1 = which plate and how (red: a, green: b, blue: the blurred fallback); 2 = the plate's uv.
uniform int debug_view : hint_range(0, 2) = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

bool is_character(ivec2 q, ivec2 size) {
	vec4 nr = texelFetch(normal_tex, clamp(q, ivec2(0), size - 1), 0);
	return nr.a < 0.5;
}

float plate_depth_m(sampler2D dep, vec2 uv, ivec2 texel_off, float far_m) {
	ivec2 dsize = textureSize(dep, 0);
	ivec2 q = clamp(ivec2(uv * vec2(dsize)) + texel_off, ivec2(0), dsize - 1);
	vec4 t = texelFetch(dep, q, 0);
	float v = floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5);
	return v > 65534.5 ? 1.0e9 : v / 65534.0 * far_m;
}

// (rgb, how): how = 0 the plate does not hold this pixel, 1 the plate's colour, 0.5 the blurred plate. `uv_out` is the plate's uv.
vec4 project_plate(sampler2D col, sampler2D dep, mat4 view, vec2 tan_half, float far_m, float valid, vec3 wp, vec3 dir, bool sky, out vec2 uv_out) {
	uv_out = vec2(0.0);
	if (valid < 0.5) {
		return vec4(0.0);
	}
	vec3 v = sky ? (view * vec4(dir, 0.0)).xyz : (view * vec4(wp, 1.0)).xyz;
	if (v.z >= -0.001) {
		return vec4(0.0);
	}
	vec2 ndc = vec2(v.x / (-v.z) / tan_half.x, v.y / (-v.z) / tan_half.y);
	vec2 uv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	uv_out = uv;
	if (sky) {
		return vec4(texture(col, uv).rgb, 1.0);
	}
	float z = -v.z;
	float tol = tol_share * z + tol_m;
	bool ok = false;
	ivec2 offs[5] = ivec2[](ivec2(0, 0), ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
	for (int k = 0; k < 5; k++) {
		ok = ok || abs(plate_depth_m(dep, uv, offs[k], far_m) - z) < tol;
	}
	if (ok) {
		return vec4(texture(col, uv).rgb, 1.0);
	}
	return vec4(textureLod(col, uv, blur_lod).rgb, 0.5);
}

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	float d0 = texelFetch(depth_tex, p, 0).r;
	bool sky = d0 <= 0.0;
	if (!sky && is_character(p, size)) {
		discard;
	}
	vec2 texel = 1.0 / vec2(size);
	vec2 ndc = (vec2(p) + 0.5) * texel * 2.0 - 1.0;
	vec4 vp4 = INV_PROJECTION_MATRIX * vec4(ndc, sky ? 0.5 : d0, 1.0);
	vec3 vp = vp4.xyz / vp4.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp, 1.0)).xyz;
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(normalize(vp), 0.0)).xyz);
	vec2 uv_a;
	vec2 uv_b;
	vec4 pa = project_plate(plate_a, depth_a, view_a, tan_a, far_a, valid_a, wp, dir, sky, uv_a);
	vec4 res = pa;
	vec2 uv_used = uv_a;
	float which = 0.0;
	if (pa.a < 0.75) {
		// Plate a does not hold the pixel sharply: plate b gets its say first; a's blurred fallback only if b has nothing better.
		vec4 pb = project_plate(plate_b, depth_b, view_b, tan_b, far_b, valid_b, wp, dir, sky, uv_b);
		if (pb.a > pa.a) {
			res = pb;
			uv_used = uv_b;
			which = 1.0;
		}
	}
	if (res.a <= 0.0) {
		discard;
	}
	if (debug_view == 1) {
		ALBEDO = vec3(which < 0.5 ? 1.0 : 0.0, which > 0.5 ? 1.0 : 0.0, res.a < 0.75 ? 1.0 : 0.0);
	} else if (debug_view == 2) {
		ALBEDO = vec3(uv_used, 0.0);
	} else {
		ALBEDO = res.rgb;
	}
	ALPHA = 1.0;
}
