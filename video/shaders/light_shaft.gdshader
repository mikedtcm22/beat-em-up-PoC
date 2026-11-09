shader_type spatial;
// A lamp's shaft, painted (LD-WORLD3; P1.md, "Atmosphere"): a cone of light from the lamp head down, drawn as flat shapes - a pale body and a
// brighter inner stripe, each with a hand-uneven edge, fading to nothing toward the ground - never a volumetric fog. A cylindrical billboard
// (turns about the vertical to face the camera), added to the picture, hidden by the depth test behind real geometry. The edge is anti-aliased.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shaft_color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy : hint_range(0.0, 1.0) = 0.14;
// The half-width at the lamp as a share of the card's half-width (the cone opens to the full width at the bottom).
uniform float top_w : hint_range(0.02, 1.0) = 0.18;
uniform float seed = 1.0;
uniform float wobble : hint_range(0.0, 0.4) = 0.14;
uniform float depth_fade_m = 1.5;

varying float view_z;

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

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float v = UV.y;
	float u = abs(UV.x - 0.5) * 2.0;
	float half_w = mix(top_w, 1.0, v);
	float n = (vnoise(vec2(v * 5.0 + seed * 3.0, UV.x * 2.0 + seed)) - 0.5) * wobble;
	float e = u / half_w + n;
	float aa = max(fwidth(e) * 1.2, 0.004);
	float body = 1.0 - smoothstep(0.92 - aa, 0.92 + aa, e);
	float inner = 1.0 - smoothstep(0.42 - aa, 0.42 + aa, e + (vnoise(vec2(v * 9.0 + seed, 3.3)) - 0.5) * 0.2);
	float fade = pow(1.0 - v, 1.4) * smoothstep(0.0, 0.06, v);
	// A few painted stripes break the body so it is not one smooth wedge.
	float stripe = step(0.35, vnoise(vec2(UV.x * 7.0 + seed * 5.0, v * 1.5)));
	float a = (body * (0.55 + 0.25 * stripe) + inner * 0.5) * fade;
	ALBEDO = shaft_color * a * energy;
	ALPHA = 1.0;
}
