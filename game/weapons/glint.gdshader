shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// The floor glint (Milestone 6, D28): a four-point sparkle on a camera-facing quad. Additive, so it only ever adds light.
// The quad is one unit wide; `size_m` is its drawn width near the lens and `min_angle_tan` the tangent of the least angle it
// may cover on screen, so it is never smaller than that wherever it is seen from. Every number is a TuningData value
// (Level > Weapon look), pushed by WeaponGlint.

uniform vec4 glint_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform float intensity = 1.2;
uniform float size_m = 0.35;
uniform float min_angle_tan = 0.028;
uniform float pulse_hz = 1.1;
uniform float pulse_depth = 0.35;
uniform float spin_rps = 0.5;

void vertex() {
	// Face the lens: the model matrix's translation with the camera's axes.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float dist = length(MODELVIEW_MATRIX[3].xyz);
	float width = max(size_m, dist * min_angle_tan);
	VERTEX.xy *= width;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = TIME * spin_rps * 6.2831853;
	vec2 q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * p;
	float core = exp(-dot(p, p) * 16.0);
	float points = exp(-abs(q.x) * 26.0 - abs(q.y) * 2.6) + exp(-abs(q.y) * 26.0 - abs(q.x) * 2.6);
	float pulse = 1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * 6.2831853 * pulse_hz));
	float fade = smoothstep(1.0, 0.75, length(p));
	float light = clamp(core * 1.3 + points, 0.0, 1.6) * pulse * fade * intensity;
	ALBEDO = glint_color.rgb * light;
	ALPHA = 1.0;
}
