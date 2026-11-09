shader_type spatial;
// The plate capture's depth pass (round 5, R5-PAINT; docs/video/P1.md): a full-screen quad that replaces the picture with the linear view depth of
// every pixel, in metres along the camera's axis, as a 16-bit number in the red (high byte) and green (low byte) channels: 0..65534 spans 0..far_m,
// 65535 is the sky. The 8-bit values are put through the inverse of the display's sRGB encode, so what the viewport writes is exactly the byte
// (the capture camera has a linear Environment and no post). tools/video/register_plates.py reads it back as metres; the plate quad
// (plate_project.gdshader) reads it as the plate's depth.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float far_m : hint_range(10.0, 2000.0) = 200.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	float d = texelFetch(depth_tex, clamp(p, ivec2(0), size - 1), 0).r;
	float v = 65535.0;
	if (d > 0.0) {
		vec4 vp4 = INV_PROJECTION_MATRIX * vec4((vec2(p) + 0.5) / vec2(size) * 2.0 - 1.0, d, 1.0);
		float z = -vp4.z / vp4.w;
		v = floor(clamp(z / far_m, 0.0, 1.0) * 65534.0 + 0.5);
	}
	float hi = floor(v / 256.0);
	float lo = v - hi * 256.0;
	ALBEDO = srgb_to_linear(vec3(hi, lo, 0.0) / 255.0);
	ALPHA = 1.0;
}
