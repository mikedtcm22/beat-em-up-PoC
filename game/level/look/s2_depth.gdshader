shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// S2: the distance from the camera, packed in three bytes of the colour (decode: dot(rgb, vec3(1, 1/255, 1/65025)) * 256).
varying float dist;
vec3 s2l(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
void vertex() {
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
void fragment() {
	float v = clamp(dist / 256.0, 0.0, 0.99999);
	vec3 enc = fract(v * vec3(1.0, 255.0, 65025.0));
	enc -= enc.yzz * vec3(1.0 / 255.0, 1.0 / 255.0, 0.0);
	ALBEDO = s2l(enc);
}
