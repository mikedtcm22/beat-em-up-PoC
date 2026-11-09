#[compute]
#version 450
// The video's finish pass (Phase 1, LD-INK; docs/video/PLAN.md Plan A part 5), a CompositorEffect compute
// shader (video/ink/post_effect.gd), in the order it matters:
//  - THE GRADE (round 3): the darks pushed toward a tint at the same luminance (navy and indigo at night, maroon and violet on the
//    boss roof, violet on the roofs) and desaturated a little, the highlights pushed toward the key's colour. It runs on the linear
//    colour, before the LUT, so the palette transfer sees the toned picture.
//  - THE DELIVERY (round 3): the references are seen through a stream, soft and grainy; ours are pixel-sharp. A sub-pixel soften (a
//    3x3 kernel blended in by `soften`, so a one-pixel line keeps most of its weight: lines never blur to mush) and a fine grain
//    that is new every `grain_hold` output frames (on twos, like the drawings), seeded from the frame, never the clock. Both are zero
//    when the delivery is switched off, for an A/B.
//  - A static paper grain (fixed to the FRAME: its cells come from the pixel position and the paper seed), a vignette and a little
//    chromatic aberration (radial, zero at the centre).
// Two dispatches: the first writes the finished frame to a temp image reading the colour with offsets, the second copies it back.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform image2D temp_image;

layout(push_constant, std430) uniform Params {
	vec2 size;
	float grain;
	float vignette;
	float vignette_start;
	float aberration;
	float grain_cell;
	float paper_seed;
	float pass_id;
	float soften;
	float fine_grain;
	float fine_seed;
	vec4 dark_tint;   // rgb the tint of the darks, a the share of it
	vec4 dark_grade;  // x the darks' desaturation, y the luminance below which a pixel is dark, z where it is no longer, w the highlights' share
	vec4 high_tint;   // rgb the highlights' multiplier
} p;

float hash12(vec2 q) {
	vec3 p3 = fract(vec3(q.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise on a grid of `cell` pixels (the paper's fibre), two octaves summed.
float paper(vec2 px) {
	float n = 0.0;
	float amp = 0.6;
	float cell = p.grain_cell;
	for (int i = 0; i < 2; i++) {
		vec2 g = px / cell + vec2(p.paper_seed * 17.0);
		vec2 f = fract(g);
		vec2 c = floor(g);
		f = f * f * (3.0 - 2.0 * f);
		float v = mix(mix(hash12(c), hash12(c + vec2(1, 0)), f.x), mix(hash12(c + vec2(0, 1)), hash12(c + vec2(1, 1)), f.x), f.y);
		n += (v - 0.5) * amp;
		amp *= 0.6;
		cell *= 2.3;
	}
	return n;
}

vec3 load_color(ivec2 q) {
	return imageLoad(color_image, clamp(q, ivec2(0), ivec2(p.size) - 1)).rgb;
}

// The colour at `q` with the chromatic aberration's offset.
vec3 load_ca(ivec2 q, ivec2 off) {
	return vec3(load_color(q + off).r, load_color(q).g, load_color(q - off).b);
}

float hash13(vec3 q) {
	q = fract(q * 0.1031);
	q += dot(q, q.zyx + 31.32);
	return fract((q.x + q.y) * q.z);
}

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= int(p.size.x) || id.y >= int(p.size.y)) {
		return;
	}
	if (p.pass_id > 0.5) {
		// Pass 2: the finished frame back into the colour.
		imageStore(color_image, id, imageLoad(temp_image, id));
		return;
	}
	vec2 uv = (vec2(id) + 0.5) / p.size;
	vec2 rd = uv - 0.5;
	// Chromatic aberration: red and blue pulled apart along the radius, a fraction of the frame at the corner.
	ivec2 off = ivec2(round(rd * p.aberration * p.size));
	vec3 col = load_ca(id, off);
	// The delivery's soften: a 3x3 kernel (centre 0.36, the cross 0.12 each, the corners 0.04 each) blended in by `soften`.
	if (p.soften > 0.0) {
		vec3 blur = col * 0.36;
		blur += 0.12 * (load_ca(id + ivec2(1, 0), off) + load_ca(id + ivec2(-1, 0), off) + load_ca(id + ivec2(0, 1), off) + load_ca(id + ivec2(0, -1), off));
		blur += 0.04 * (load_ca(id + ivec2(1, 1), off) + load_ca(id + ivec2(-1, 1), off) + load_ca(id + ivec2(1, -1), off) + load_ca(id + ivec2(-1, -1), off));
		col = mix(col, blur, p.soften);
	}
	// The grade: the darks toward the tint at their own luminance, desaturated; the highlights toward the key.
	float glum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float dark = 1.0 - smoothstep(p.dark_grade.y, max(p.dark_grade.z, p.dark_grade.y + 0.0001), glum);
	vec3 tint = p.dark_tint.rgb * (glum / max(dot(p.dark_tint.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0001));
	col = mix(col, vec3(glum), p.dark_grade.x * dark);
	col = mix(col, tint, p.dark_tint.a * dark);
	float high = smoothstep(p.dark_grade.z, p.dark_grade.z * 4.0 + 0.2, glum);
	col *= mix(vec3(1.0), p.high_tint.rgb, p.dark_grade.w * high);
	// The vignette, in a frame-aspect-corrected radius (0 at the centre, 1 at the corner).
	vec2 q = rd * vec2(p.size.x / p.size.y, 1.0);
	float r = length(q) / length(vec2(p.size.x / p.size.y, 1.0) * 0.5);
	col *= 1.0 - p.vignette * smoothstep(p.vignette_start, 1.0, r);
	// The paper grain: a few percent of value, brighter than dark so the darks stay clean ink.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col *= 1.0 + paper(vec2(id)) * p.grain * (0.4 + 0.6 * smoothstep(0.0, 0.25, lum));
	// The delivery's fine grain: one pixel, new on every hold of the drawings (the seed is the output frame over the hold).
	col *= 1.0 + (hash13(vec3(vec2(id), p.fine_seed)) - 0.5) * 2.0 * p.fine_grain * (0.35 + 0.65 * smoothstep(0.0, 0.3, lum));
	imageStore(temp_image, id, vec4(col, 1.0));
}
