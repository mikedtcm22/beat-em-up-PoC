shader_type sky;
// The video's painted sky (LD-WORLD; PLAN.md section 4 part 4): domain-warped noise quantised into brush bands, cloud
// banks in two hard values, and one or two discs (the sun, the moons) each with a BANDED halo: uneven painted rings, like ref 2
// at 50.5 s. Everything is a function of the view direction (the sky is at infinity), so it never swims with the camera.
// No time input: a still sky.

uniform vec3 zenith_color : source_color = vec3(0.03, 0.04, 0.12);
uniform vec3 mid_color : source_color = vec3(0.08, 0.09, 0.26);
uniform vec3 horizon_color : source_color = vec3(0.30, 0.2, 0.3);
uniform vec3 below_color : source_color = vec3(0.04, 0.04, 0.09);
// Elevation (sine) where each band starts: the horizon colour up to `mid_at`, the zenith above `top_at`.
uniform float mid_at : hint_range(0.0, 1.0) = 0.25;
uniform float top_at : hint_range(0.0, 1.0) = 0.8;
uniform float band_count : hint_range(2.0, 12.0) = 6.0;
uniform float band_soft : hint_range(0.0, 0.3) = 0.04;
// How far the brush noise bends the band edges (in bands), and its scale (cycles round the horizon).
uniform float band_warp : hint_range(0.0, 2.0) = 0.6;
uniform vec2 warp_scale = vec2(5.0, 9.0);
// Cloud banks: colour of the lit top and of the shaded underside, share of the sky they cover (0: none), their elevation range.
uniform vec3 cloud_lit : source_color = vec3(0.25, 0.25, 0.45);
uniform vec3 cloud_shade : source_color = vec3(0.04, 0.05, 0.15);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cloud_range = vec2(0.05, 0.6);
uniform vec2 cloud_scale = vec2(3.0, 14.0);
// The discs: direction (toward the disc), angular radius in radians, colour, halo colour, rings, ring spacing (in radii), the
// wobble of a ring's edge, and the strength of the halo (0: none; a disc with radius 0 is off).
uniform vec3 disc_dir = vec3(0.0, 0.3, -1.0);
uniform float disc_radius : hint_range(0.0, 0.6) = 0.0;
uniform vec3 disc_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 halo_color : source_color = vec3(1.0, 0.8, 0.5);
uniform float halo_rings : hint_range(0.0, 5.0) = 3.0;
uniform float halo_gap : hint_range(0.1, 6.0) = 1.1;
uniform float halo_wobble : hint_range(0.0, 0.6) = 0.18;
uniform float halo_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec3 disc2_dir = vec3(0.3, 0.4, -1.0);
uniform float disc2_radius : hint_range(0.0, 0.3) = 0.0;
uniform vec3 disc2_color : source_color = vec3(0.7, 0.9, 1.0);
uniform vec3 halo2_color : source_color = vec3(0.3, 0.5, 0.9);
// Stars: share of cells that hold a star, colour.
uniform float star_cover : hint_range(0.0, 0.2) = 0.0;
uniform vec3 star_color : source_color = vec3(0.8, 0.85, 1.0);

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

// Noise on the sphere's (azimuth, elevation), wrapped in azimuth so there is no seam.
float snoise(vec2 ae, vec2 scale, float seed) {
	float a = ae.x / 6.2831853;
	float n = 0.0;
	float amp = 0.6;
	float norm = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 s = scale * pow(2.0, float(i));
		float period = floor(s.x);
		vec2 p = vec2(a * period, ae.y * s.y / 6.2831853 * 6.0 + seed + float(i) * 13.7);
		float u = fract(a) * period;
		float k = floor(u);
		float f = u - k;
		f = f * f * (3.0 - 2.0 * f);
		float y0 = floor(p.y);
		float fy = p.y - y0;
		fy = fy * fy * (3.0 - 2.0 * fy);
		float h00 = hash12(vec2(mod(k, period), y0 + seed));
		float h10 = hash12(vec2(mod(k + 1.0, period), y0 + seed));
		float h01 = hash12(vec2(mod(k, period), y0 + 1.0 + seed));
		float h11 = hash12(vec2(mod(k + 1.0, period), y0 + 1.0 + seed));
		n += amp * mix(mix(h00, h10, f), mix(h01, h11, f), fy);
		norm += amp;
		amp *= 0.5;
	}
	return n / norm;
}

// One disc with its banded halo over `base`: the rings are the union of discs of growing radius, each edge wobbling with the
// angle round the disc, each ring fainter than the one inside.
vec3 disc_with_halo(vec3 eye, vec3 base, vec3 dir, float radius, vec3 core, vec3 halo, float rings, float gap, float wobble, float strength) {
	if (radius <= 0.0) {
		return base;
	}
	vec3 d = normalize(dir);
	float cosang = clamp(dot(eye, d), -1.0, 1.0);
	if (cosang < 0.2) {
		return base;
	}
	float ang = acos(cosang);
	vec3 up = abs(d.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 tx = normalize(cross(up, d));
	vec3 ty = cross(d, tx);
	float phi = atan(dot(eye, ty), dot(eye, tx));
	vec3 col = base;
	for (int k = int(rings); k >= 1; k--) {
		float fk = float(k);
		float wob = (vnoise(vec2(phi * 1.3 + fk * 7.1, fk * 3.7)) - 0.5) * 2.0 * wobble * (0.6 + 0.4 * fk);
		float rk = radius * (1.0 + fk * gap) * (1.0 + wob);
		float edge = max(fwidth(ang), 0.0005) * 1.2;
		float inside = 1.0 - smoothstep(rk - edge, rk + edge, ang);
		col = mix(col, mix(col, halo, strength / (1.0 + 0.55 * (fk - 1.0))), inside);
	}
	float edge0 = max(fwidth(ang), 0.0004) * 1.2;
	float r0 = radius * (1.0 + (vnoise(vec2(phi * 2.0, 1.7)) - 0.5) * 0.06);
	col = mix(col, core, 1.0 - smoothstep(r0 - edge0, r0 + edge0, ang));
	return col;
}

void sky() {
	vec3 dir = EYEDIR;
	float elev = dir.y;
	float azim = atan(dir.x, -dir.z) + 3.14159265;
	vec3 col;
	if (elev < 0.0) {
		col = below_color;
	} else {
		float warp = (snoise(vec2(azim, elev), warp_scale, 3.0) - 0.5) * 2.0 * band_warp / band_count;
		float t = clamp(elev + warp * 0.6, 0.0, 1.0);
		float q = t * band_count;
		float fq = floor(q);
		float edge = max(fwidth(q) * 1.2, band_soft);
		float stepped = (fq + smoothstep(0.5 - edge, 0.5 + edge, fract(q))) / band_count;
		float u1 = smoothstep(0.0, mid_at, stepped);
		float u2 = smoothstep(mid_at, top_at, stepped);
		col = mix(mix(horizon_color, mid_color, u1), zenith_color, u2);
		if (cloud_cover > 0.0) {
			float ce = smoothstep(cloud_range.x, cloud_range.x + 0.06, elev) * (1.0 - smoothstep(cloud_range.y - 0.1, cloud_range.y, elev));
			float n = snoise(vec2(azim, elev), cloud_scale, 11.0);
			float thr = 1.0 - cloud_cover;
			float fw = max(fwidth(n) * 1.5, 0.01);
			float body = smoothstep(thr - fw, thr + fw, n);
			float low = snoise(vec2(azim, elev - 0.04), cloud_scale, 11.0);
			vec3 cc = mix(cloud_shade, cloud_lit, smoothstep(0.35, 0.65, (n - low) * 18.0 + 0.5));
			col = mix(col, cc, body * ce);
		}
		if (star_cover > 0.0) {
			vec2 sp = vec2(azim * 180.0, elev * 120.0);
			vec2 cell = floor(sp);
			float h = hash12(cell);
			vec2 local = fract(sp) - 0.5 - (vec2(hash12(cell + 7.3), hash12(cell + 2.1)) - 0.5) * 0.5;
			float star = step(1.0 - star_cover, h) * (1.0 - smoothstep(0.12, 0.2, length(local)));
			col = mix(col, star_color, star * smoothstep(0.1, 0.4, elev));
		}
	}
	col = disc_with_halo(dir, col, disc2_dir, disc2_radius, disc2_color, halo2_color, 2.0, 0.9, 0.15, 0.5);
	col = disc_with_halo(dir, col, disc_dir, disc_radius, disc_color, halo_color, halo_rings, halo_gap, halo_wobble, halo_strength);
	COLOR = col;
}
