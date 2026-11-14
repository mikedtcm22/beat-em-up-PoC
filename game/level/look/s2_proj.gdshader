shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// S2: the world takes its colour from painted plates projected from four vantage cameras, picked per pixel by facing and
// by a distance map (occlusion). Nothing here is lit: the light is in the painting.
uniform sampler2D plate0 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D plate1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D plate2 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D plate3 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D dist0 : filter_nearest, repeat_disable;
uniform sampler2D dist1 : filter_nearest, repeat_disable;
uniform sampler2D dist2 : filter_nearest, repeat_disable;
uniform sampler2D dist3 : filter_nearest, repeat_disable;
uniform mat4 vp0;
uniform mat4 vp1;
uniform mat4 vp2;
uniform mat4 vp3;
uniform vec3 cam0;
uniform vec3 cam1;
uniform vec3 cam2;
uniform vec3 cam3;
uniform vec3 base_color : source_color = vec3(0.04, 0.05, 0.11);
uniform float sharpen = 3.0;
uniform float debug_cover = 0.0;
uniform float view_bias = 1.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 take(sampler2D plate, sampler2D dist, mat4 vp, vec3 cam, vec3 wp, vec3 n, out float w, out float wu) {
	vec4 clip = vp * vec4(wp, 1.0);
	w = 0.0;
	wu = 0.0;
	if (clip.w <= 0.01) {
		return vec4(0.0);
	}
	vec2 ndc = clip.xy / clip.w;
	vec2 uv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
	vec2 cuv = clamp(uv, vec2(0.001), vec2(0.999));
	vec4 col = texture(plate, cuv);
	vec3 e = texture(dist, cuv).rgb;
	float sd = dot(e, vec3(1.0, 1.0 / 255.0, 1.0 / 65025.0)) * 256.0;
	vec3 to_cam = cam - wp;
	float d = length(to_cam);
	float facing = abs(dot(n, to_cam / d));
	float bias = 0.06 + d * 0.015 / max(facing, 0.2);
	float vis = (d < sd + bias) ? 1.0 : 0.0;
	vec2 edge = min(uv, 1.0 - uv);
	float fade = smoothstep(0.0, 0.04, min(edge.x, edge.y));
	wu = pow(pow(max(facing, 0.02), 2.0) * fade, sharpen);
	w = vis * fade * pow(max(facing, 0.02), 2.0) * view_bias;
	w = pow(w, sharpen);
	return col;
}

void fragment() {
	float w0, w1, w2, w3, u0, u1, u2, u3;
	vec4 c0 = take(plate0, dist0, vp0, cam0, wpos, wnorm, w0, u0);
	vec4 c1 = take(plate1, dist1, vp1, cam1, wpos, wnorm, w1, u1);
	vec4 c2 = take(plate2, dist2, vp2, cam2, wpos, wnorm, w2, u2);
	vec4 c3 = take(plate3, dist3, vp3, cam3, wpos, wnorm, w3, u3);
	float sum = w0 + w1 + w2 + w3;
	vec3 col = (c0.rgb * w0 + c1.rgb * w1 + c2.rgb * w2 + c3.rgb * w3) / max(sum, 1e-9);
	float cover = smoothstep(0.0, 1e-5, sum);
	// No view saw this surface (its back, a side face, behind a near object): the nearest views' paint smeared on it, darker.
	float usum = u0 + u1 + u2 + u3;
	vec3 smear = (c0.rgb * u0 + c1.rgb * u1 + c2.rgb * u2 + c3.rgb * u3) / max(usum, 1e-9) * 0.55;
	smear = mix(base_color, smear, smoothstep(0.0, 1e-5, usum));
	col = mix(smear, col, cover);
	if (debug_cover > 0.5 && cover < 0.5) {
		col = vec3(1.0, 0.0, 1.0);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
