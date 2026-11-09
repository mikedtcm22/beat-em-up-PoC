shader_type spatial;
// A lamp's shaft, painted (LD-WORLD3, redrawn in R4-WORLD; P1.md, "Light drawn, not computed"): a wedge of a few brush strokes fanning out of the lamp head, each its own length
// and opacity, with a broken edge, fading out before the ground - never a straight-edged cone of constant opacity and never a volumetric fog. A cylindrical billboard
// (turns about the vertical to face the camera), added to the picture, hidden by the depth test behind real geometry. The edge is anti-aliased.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shaft_color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy : hint_range(0.0, 1.0) = 0.14;
// The half-width at the lamp as a share of the card's half-width (the cone opens to the full width at the bottom).
uniform float top_w : hint_range(0.02, 1.0) = 0.18;
uniform float seed = 1.0;
uniform float wobble : hint_range(0.0, 0.4) = 0.2;
// Near the camera a shaft is a wall of stripes in the lens: it fades out inside this distance (m, x: gone, y: full).
uniform vec2 near_fade_m = vec2(4.0, 9.0);
uniform int strokes : hint_range(3, 12) = 9;

varying float cam_dist;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = vec3(cam.x - origin.x, 0.0, cam.z - origin.z);
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	vec3 world = origin + right * VERTEX.x + vec3(0.0, 1.0, 0.0) * VERTEX.y;
	cam_dist = length(world - cam);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// A wedge painted in a few strokes fanning out of the lamp head: each stroke has its own length and opacity, its edges are broken by a noise, and
	// the whole fades out well before the ground. Nothing is a straight edge of constant opacity.
	float v = UV.y;
	float half_w = mix(top_w, 1.0, v);
	float a = (UV.x - 0.5) * 2.0 / half_w;
	float rag = (vnoise(vec2(v * 2.2 + seed * 3.0, a * 3.5 + seed)) - 0.5) * wobble * 2.0;
	float pos = (a + rag) * 0.5 + 0.5;
	float strokes_n = float(strokes);
	float id = floor(pos * strokes_n);
	float f = fract(pos * strokes_n);
	float h_len = hash12(vec2(id, seed * 1.9));
	float h_op = hash12(vec2(id + 7.0, seed * 2.7));
	float len = mix(0.45, 1.0, h_len);
	float opacity = mix(0.18, 0.75, h_op * h_op);
	// A stroke: soft on its sides, brushed by streaks along its length, ending where its own length does.
	float side = smoothstep(0.0, 0.3, f) * (1.0 - smoothstep(0.6, 1.0, f));
	float bristle = 0.55 + 0.45 * vnoise(vec2(a * 17.0 + seed * 4.0, v * 2.2));
	float along = 1.0 - smoothstep(len * 0.35, len, v);
	float inside = step(abs(a + rag), 1.0);
	float head = smoothstep(0.0, 0.08, v);
	float a_out = side * bristle * along * opacity * inside * head * smoothstep(near_fade_m.x, near_fade_m.y, cam_dist);
	ALBEDO = shaft_color * a_out * energy;
	ALPHA = 1.0;
}
