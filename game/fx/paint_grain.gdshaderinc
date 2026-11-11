// The grain on a flat fill (Milestone 7, T11): a value noise in whatever space the caller hands it (the painted
// character's rest-pose position, so it sticks to the moving body; the trim's face metres). Fine on purpose: cells of a
// few millimetres to a centimetre, never brick scale. Returns 0..1, 0.5 on average.

float paint_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float paint_grain_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(paint_hash13(i), paint_hash13(i + vec3(1, 0, 0)), f.x), mix(paint_hash13(i + vec3(0, 1, 0)), paint_hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(paint_hash13(i + vec3(0, 0, 1)), paint_hash13(i + vec3(1, 0, 1)), f.x), mix(paint_hash13(i + vec3(0, 1, 1)), paint_hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
