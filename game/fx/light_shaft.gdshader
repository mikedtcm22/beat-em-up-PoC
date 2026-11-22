shader_type spatial;
// A lamp's shaft, drawn as two flat wedges (M7 x-street, redrawn from the old fan of soft brush strokes): the see-through fan with a
// soft falloff broke the no-soft-gradient rule, so the shaft is now two flat tones, a wide outer wedge and a narrower brighter core, each
// a straight-sided triangle fanning out of the lamp head with a hard brushed edge (a streak noise bites its sides and its far end, never
// a fade), ending in a flat cut before the ground. Mixed over the picture in a flat warm tone, hidden by the depth test behind real
// geometry. A cylindrical billboard (turns about the vertical to face the camera). Presentation only (the trailer profile).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shaft_color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy : hint_range(0.0, 1.0) = 0.14;
// The two wedges' flat opacity (the core's is over the outer's), the core's half-width as a share of the wedge's, and where each ends (v).
uniform float outer_alpha : hint_range(0.0, 1.0) = 0.09;
uniform float core_alpha : hint_range(0.0, 1.0) = 0.15;
uniform float core_w : hint_range(0.1, 1.0) = 0.45;
uniform float outer_len : hint_range(0.2, 1.0) = 0.7;
uniform float core_len : hint_range(0.2, 1.0) = 0.5;
// The half-width at the lamp as a share of the card's half-width (the cone opens to the full width at the bottom).
uniform float top_w : hint_range(0.02, 1.0) = 0.18;
uniform float seed = 1.0;
uniform float wobble : hint_range(0.0, 0.4) = 0.2;
// Near the camera a shaft is a wall of stripes in the lens: it fades out inside this distance (m, x: gone, y: full).
uniform vec2 near_fade_m = vec2(4.0, 9.0);

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
	// Two wedges: both open from the lamp head (v 0) to the card's foot (v 1); the core is the narrower and ends sooner. Each side is a straight
	// line with a brushed bite, each far end a flat cut with a bite of its own: no fade anywhere.
	float v = UV.y;
	float half_w = mix(top_w, 1.0, v);
	float a = (UV.x - 0.5) * 2.0 / half_w;
	float bite = (vnoise(vec2(a * 9.0 + seed * 4.0, v * 3.0)) - 0.5) * wobble * 0.5;
	float bristle = (vnoise(vec2(a * 37.0 + seed * 2.0, v * 5.0)) - 0.5) * wobble * 0.12;
	float edge = bite + bristle;
	float outer = step(abs(a) + edge, 1.0) * step(v + edge * 0.6, outer_len);
	float core = step(abs(a) + edge * 0.7, core_w) * step(v + edge * 0.6, core_len);
	float cover = max(outer, core);
	float head = smoothstep(0.0, 0.04, v);
	float fade = smoothstep(near_fade_m.x, near_fade_m.y, cam_dist);
	float alpha = mix(outer_alpha, core_alpha, core) * cover * fade * head;
	if (alpha <= 0.0) {
		discard;
	}
	ALBEDO = shaft_color;
	ALPHA = alpha * energy / 0.12;
}
