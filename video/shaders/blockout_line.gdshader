shader_type spatial;
// The plate blockout's thin dark line on depth edges (round 5, R5-PAINT; docs/video/P1.md): a full-screen quad that draws `line_color` on the NEARER
// side of every depth step (a rooftop against the sky, a wall against the street behind it), so a Gemini paint-over keeps the outline of every large
// mass where the blockout has it. The step is a relative one: a neighbour `width_px` away (at 1080p, scaled to the render) whose depth differs by
// more than `step_share` of the nearer's. Characters are hidden in the capture, so the line never draws them.

render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 line_color : source_color = vec3(0.07, 0.06, 0.13);
uniform float width_px : hint_range(0.5, 6.0) = 1.6;
uniform float step_share : hint_range(0.01, 1.0) = 0.12;
uniform float sky_m : hint_range(50.0, 2000.0) = 400.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_z(ivec2 q, ivec2 size, mat4 inv_proj) {
	float d = texelFetch(depth_tex, clamp(q, ivec2(0), size - 1), 0).r;
	if (d <= 0.0) {
		return sky_m;
	}
	vec4 vp4 = inv_proj * vec4((vec2(q) + 0.5) / vec2(size) * 2.0 - 1.0, d, 1.0);
	return -vp4.z / vp4.w;
}

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	float z = view_z(p, size, INV_PROJECTION_MATRIX);
	if (z >= sky_m) {
		discard;
	}
	int w = max(int(round(width_px * VIEWPORT_SIZE.y / 1080.0)), 1);
	float nearer = 0.0;
	ivec2 offs[4] = ivec2[](ivec2(1, 0), ivec2(0, 1), ivec2(-1, 0), ivec2(0, -1));
	for (int k = 0; k < 4; k++) {
		float zn = view_z(p + offs[k] * w, size, INV_PROJECTION_MATRIX);
		nearer = max(nearer, step(z * (1.0 + step_share), zn));
	}
	if (nearer < 0.5) {
		discard;
	}
	ALBEDO = line_color;
	ALPHA = 1.0;
}
