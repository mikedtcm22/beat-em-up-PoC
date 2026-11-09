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
// Round 5 (R5-INK) puts the actors on the painting and adds a diffusion glow, in more dispatches (pass_id):
//  - 4 THE ACTORS (into the temp image, then copied back by 3): on a character's pixels (told by the normal-roughness buffer's tag, as the screen ink does),
//    a LIGHT WRAP (a blurred copy of what is behind, added within `wrap` px of the silhouette) and ACTOR FOG (toward the blurred background colour
//    at the actor's screen position, by its distance from the lens, so far figures sink into the haze). The plate is in the colour by now, so both
//    read the painting.
//  - 5..10 THE GLOW: a soft-knee bright pass at quarter size that keeps the hue (5), a 1/16 copy (6), a narrow blur (7, 8) and a wide blur (9, 10),
//    screened onto the picture in the finish pass (2) at a share each. Wide and faint, never a bloom look.
// The delivery's dispatches (0 and 1 only when the re-scale is on): the first two are the delivery's re-scale; pass 2 writes the finished frame to a temp image reading the colour with offsets, pass 3 copies it back.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform image2D temp_image;
layout(rgba16f, set = 0, binding = 2) uniform image2D small_image;
// The glow's images: glow_a is the quarter-size bright pass; glow_b holds the blur's temp in its top quarter-size block and, below it, the two 1/16-size blurs side by side.
layout(rgba16f, set = 0, binding = 3) uniform image2D glow_a;
layout(rgba16f, set = 0, binding = 4) uniform image2D glow_b;
layout(set = 0, binding = 5) uniform sampler2D normal_tex;
layout(set = 0, binding = 6) uniform sampler2D depth_tex;
layout(set = 0, binding = 7, std140) uniform Extra {
	vec4 wrap;     // x the light wrap's strength, y its reach in px from the silhouette, z the nearest and w the farthest px of the colour it reads
	vec4 fog;      // x the actor fog's most, y the metre where it starts, z where it is full, w the radius in px of the colour it fogs toward
	vec4 glow;     // x the narrow glow's share, y the wide glow's, z the bright pass's threshold (linear luminance), w its knee
	vec4 glow_sz;  // xy the quarter size, zw the 1/16 size, in pixels
	vec4 blur;     // x the narrow blur's sigma (quarter-size pixels), y the wide blur's (1/16-size pixels), z the debug view, w the metres out to which the wrap has its full reach
	vec4 proj;     // x and y the projection's A and B (reversed Z: view distance = B / (depth + A)), z actors on, w glow on
} ex;

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
	vec4 deliver;     // xy the re-scale's small size in pixels
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

// ---- round 5: the actors and the glow ----------------------------------------------------------------------------------------

float lum_of(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Godot's normal-roughness buffer, as a spatial shader sees it through hint_normal_roughness_texture.
vec4 decode_normal_roughness(vec4 raw) {
	float roughness = raw.w;
	if (roughness > 0.5) {
		roughness = 1.0 - roughness;
	}
	roughness /= (127.0 / 255.0);
	return vec4(normalize(raw.xyz * 2.0 - 1.0 + vec3(0.0, 0.0, 0.00001)) * 0.5 + 0.5, roughness);
}

// 1 where the pixel is a character (roughness tag 0, and not the sky), as the screen ink tells.
float is_character(ivec2 q) {
	q = clamp(q, ivec2(0), ivec2(p.size) - 1);
	float d = texelFetch(depth_tex, q, 0).r;
	if (d <= 0.0) {
		return 0.0;
	}
	vec4 raw = texelFetch(normal_tex, q, 0);
	// (A character's normal buffer has stray pixels whose normal is the zero vector, so the tag is the roughness alone.)
	return decode_normal_roughness(raw).w < 0.5 ? 1.0 : 0.0;
}

float view_distance_m(ivec2 q) {
	float d = texelFetch(depth_tex, clamp(q, ivec2(0), ivec2(p.size) - 1), 0).r;
	return ex.proj.y / max(d + ex.proj.x, 0.000001);
}

// The mean colour of the non-character pixels on a ring of `n` taps at `radius` px (w = how many were found).
vec4 ring_background(ivec2 c, float radius, int n, float turn) {
	vec3 sum = vec3(0.0);
	float count = 0.0;
	for (int i = 0; i < n; i++) {
		float a = 6.2831853 * (float(i) + turn) / float(n);
		ivec2 q = c + ivec2(round(vec2(cos(a), sin(a)) * radius));
		if (is_character(q) < 0.5) {
			sum += load_color(q);
			count += 1.0;
		}
	}
	return vec4(sum, count);
}

// Pass 4: the light wrap and the actor fog on a character's pixel.
void actors(ivec2 id) {
	vec3 col = load_color(id);
	if (ex.blur.z > 2.5 && ex.blur.z < 5.5) {
		vec4 raw = texelFetch(normal_tex, id, 0);
		imageStore(temp_image, id, vec4(ex.blur.z < 3.5 ? raw.rgb : (ex.blur.z < 4.5 ? vec3(raw.w) : vec3(texelFetch(depth_tex, id, 0).r > 0.0 ? 1.0 : 0.0, length(raw.xyz * 2.0 - 1.0) > 0.5 ? 1.0 : 0.0, decode_normal_roughness(raw).w < 0.5 ? 1.0 : 0.0)), 1.0));
		return;
	}
	if (ex.proj.z < 0.5 || is_character(id) < 0.5) {
		imageStore(temp_image, id, vec4(col, 1.0));
		return;
	}
	if (ex.blur.z > 5.5) {
		// A stand-in for a back-lit silhouette's flat dark fill (debug 6), to judge the wrap and the fog on one.
		col = vec3(0.02, 0.015, 0.03);
	}
	float scale = p.size.y / 1080.0;
	float z = view_distance_m(id);
	// The wrap's reach narrows with distance (a far figure is small: a 6 px wrap would be all of it), to a quarter at four times the reference distance.
	float wrap_px = ex.wrap.y * scale * clamp(ex.blur.w / max(z, 0.01), 0.25, 1.0);
	// How near the silhouette is: the nearest non-character pixel on six rings round this one.
	float dmin = 1.0e9;
	if (ex.wrap.x > 0.0) {
		for (int j = 1; j <= 6; j++) {
			float r = wrap_px * float(j) / 6.0;
			for (int i = 0; i < 8; i++) {
				float a = 0.7853982 * float(i) + 0.31 * float(j);
				if (is_character(id + ivec2(round(vec2(cos(a), sin(a)) * r))) < 0.5) {
					dmin = min(dmin, r);
					break;
				}
			}
			if (dmin < 1.0e8) {
				break;
			}
		}
	}
	vec3 outc = col;
	if (dmin < 1.0e8) {
		// The blurred background: non-character taps on rings beyond the outline's hull.
		vec3 sum = vec3(0.0);
		float count = 0.0;
		for (int k = 0; k < 3; k++) {
			float r = mix(ex.wrap.z, ex.wrap.w, float(k) / 2.0) * scale;
			vec4 ring = ring_background(id, r, 8, 0.37 * float(k));
			sum += ring.rgb;
			count += ring.w;
		}
		if (count > 0.5) {
			float edge = mix(1.0, 0.15, clamp((dmin / wrap_px - 1.0 / 6.0) / (5.0 / 6.0), 0.0, 1.0));
			vec3 add = (sum / count) * ex.wrap.x * edge;
			outc += add * (1.0 - clamp(outc, vec3(0.0), vec3(1.0)));
		}
	}
	// Actor fog toward the blurred background colour at this pixel, by distance.
	float f = ex.fog.x * smoothstep(ex.fog.y, max(ex.fog.z, ex.fog.y + 0.01), z);
	if (f > 0.001) {
		float r = ex.fog.w * scale;
		vec4 a = ring_background(id, r * 0.5, 8, 0.11);
		vec4 b = ring_background(id, r, 8, 0.43);
		vec4 c = ring_background(id, r * 1.5, 8, 0.77);
		float count = a.w + b.w + c.w;
		if (count > 0.5) {
			outc = mix(outc, (a.rgb + b.rgb + c.rgb) / count, f);
		}
	}
	if (ex.blur.z > 0.5 && ex.blur.z < 1.5) {
		outc = vec3(clamp(z / 20.0, 0.0, 1.0), 0.0, f);
	} else if (ex.blur.z > 1.5 && ex.blur.z < 2.5) {
		outc = vec3(dmin < 1.0e8 ? 1.0 : 0.0, 0.0, 0.0);
	}
	imageStore(temp_image, id, vec4(outc, 1.0));
}

// Pass 5: the bright pass, a soft knee on luminance that scales the colour (so the hue is kept), averaged over 4x4 pixels into the quarter-size image.
void glow_bright(ivec2 id) {
	ivec2 qs = ivec2(ex.glow_sz.xy);
	if (id.x >= qs.x || id.y >= qs.y) {
		return;
	}
	vec3 sum = vec3(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec3 c = max(load_color(id * 4 + ivec2(x, y)), vec3(0.0));
			float l = lum_of(c);
			float knee = max(ex.glow.w, 0.0001);
			float soft = clamp(l - ex.glow.z + knee, 0.0, 2.0 * knee);
			soft = soft * soft / (4.0 * knee);
			float k = max(soft, l - ex.glow.z) / max(l, 0.0001);
			sum += min(c * max(k, 0.0), vec3(4.0));
		}
	}
	imageStore(glow_a, id, vec4(sum / 16.0, 1.0));
}

// Pass 6: the quarter-size image to 1/16 size (4x4 average), into glow_b below its quarter-size block.
void glow_down(ivec2 id) {
	ivec2 qs = ivec2(ex.glow_sz.xy);
	ivec2 ss = ivec2(ex.glow_sz.zw);
	if (id.x >= ss.x || id.y >= ss.y) {
		return;
	}
	vec3 sum = vec3(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			sum += imageLoad(glow_a, clamp(id * 4 + ivec2(x, y), ivec2(0), qs - 1)).rgb;
		}
	}
	imageStore(glow_b, ivec2(id.x, qs.y + id.y), vec4(sum / 16.0, 1.0));
}

// One separable Gaussian pass. `which`: 7 narrow horizontal (glow_a -> glow_b's top block), 8 narrow vertical (back into glow_a),
// 9 wide horizontal (1/16 block 1 -> block 2) and 10 wide vertical (block 2 -> block 1).
void glow_blur(ivec2 id, int which) {
	ivec2 qs = ivec2(ex.glow_sz.xy);
	ivec2 ss = ivec2(ex.glow_sz.zw);
	bool wide = which >= 9;
	ivec2 dims = wide ? ss : qs;
	if (id.x >= dims.x || id.y >= dims.y) {
		return;
	}
	float sigma = max(wide ? ex.blur.y : ex.blur.x, 0.3);
	int radius = min(int(ceil(sigma * 3.0)), 14);
	bool horizontal = (which == 7 || which == 9);
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = -radius; i <= radius; i++) {
		float w = exp(-0.5 * float(i * i) / (sigma * sigma));
		ivec2 q = id + (horizontal ? ivec2(i, 0) : ivec2(0, i));
		q = clamp(q, ivec2(0), dims - 1);
		vec3 c;
		if (which == 7) {
			c = imageLoad(glow_a, q).rgb;
		} else if (which == 8) {
			c = imageLoad(glow_b, q).rgb;
		} else if (which == 9) {
			c = imageLoad(glow_b, ivec2(q.x, qs.y + q.y)).rgb;
		} else {
			c = imageLoad(glow_b, ivec2(ss.x + q.x, qs.y + q.y)).rgb;
		}
		sum += c * w;
		wsum += w;
	}
	vec4 res = vec4(sum / wsum, 1.0);
	if (which == 7) {
		imageStore(glow_b, id, res);
	} else if (which == 8) {
		imageStore(glow_a, id, res);
	} else if (which == 9) {
		imageStore(glow_b, ivec2(ss.x + id.x, qs.y + id.y), res);
	} else {
		imageStore(glow_b, ivec2(id.x, qs.y + id.y), res);
	}
}

vec3 glow_bilinear(bool wide, vec2 uv) {
	ivec2 qs = ivec2(ex.glow_sz.xy);
	ivec2 ss = ivec2(ex.glow_sz.zw);
	ivec2 dims = wide ? ss : qs;
	vec2 g = uv * vec2(dims) - 0.5;
	ivec2 i0 = ivec2(floor(g));
	vec2 f = fract(g);
	vec3 c[4];
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			ivec2 q = clamp(i0 + ivec2(i, j), ivec2(0), dims - 1);
			c[j * 2 + i] = wide ? imageLoad(glow_b, ivec2(q.x, qs.y + q.y)).rgb : imageLoad(glow_a, q).rgb;
		}
	}
	return mix(mix(c[0], c[1], f.x), mix(c[2], c[3], f.x), f.y);
}

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= int(p.size.x) || id.y >= int(p.size.y)) {
		return;
	}
	if (p.pass_id > 3.5) {
		int which = int(p.pass_id + 0.5);
		if (which == 4) {
			actors(id);
		} else if (which == 5) {
			glow_bright(id);
		} else if (which == 6) {
			glow_down(id);
		} else {
			glow_blur(id, which);
		}
		return;
	}
	if (p.pass_id < 0.5) {
		// Pass 0 (the delivery's re-scale, down): the colour box-filtered to the small size, each small pixel the area average of the
		// source pixels it covers.
		if (id.x >= int(p.deliver.x) || id.y >= int(p.deliver.y)) {
			return;
		}
		vec2 ratio = p.size / p.deliver.xy;
		vec2 lo = vec2(id) * ratio;
		vec2 hi = lo + ratio;
		vec3 sum = vec3(0.0);
		float wsum = 0.0;
		for (int y = int(floor(lo.y)); y < int(ceil(hi.y)); y++) {
			for (int x = int(floor(lo.x)); x < int(ceil(hi.x)); x++) {
				float w = (min(float(x + 1), hi.x) - max(float(x), lo.x)) * (min(float(y + 1), hi.y) - max(float(y), lo.y));
				sum += load_color(ivec2(x, y)) * w;
				wsum += w;
			}
		}
		imageStore(small_image, id, vec4(sum / max(wsum, 0.0001), 1.0));
		return;
	}
	if (p.pass_id < 1.5) {
		// Pass 1 (the re-scale, up): bicubic (Catmull-Rom) from the small image back into the colour.
		vec2 u = (vec2(id) + 0.5) * p.deliver.xy / p.size - 0.5;
		vec2 f = fract(u);
		ivec2 i0 = ivec2(floor(u));
		vec2 w0 = ((-0.5 * f + 1.0) * f - 0.5) * f;
		vec2 w1 = (1.5 * f - 2.5) * f * f + 1.0;
		vec2 w2 = ((-1.5 * f + 2.0) * f + 0.5) * f;
		vec2 w3 = (0.5 * f - 0.5) * f * f;
		float wx[4] = float[](w0.x, w1.x, w2.x, w3.x);
		float wy[4] = float[](w0.y, w1.y, w2.y, w3.y);
		vec3 sum = vec3(0.0);
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				sum += imageLoad(small_image, clamp(i0 + ivec2(i - 1, j - 1), ivec2(0), ivec2(p.deliver.xy) - 1)).rgb * (wx[i] * wy[j]);
			}
		}
		imageStore(color_image, id, vec4(max(sum, vec3(0.0)), 1.0));
		return;
	}
	if (p.pass_id > 2.5) {
		// Pass 3: the finished frame back into the colour.
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
	// The diffusion glow: the two blurred bright passes screened on, so it brightens the darks and never clips the lights.
	if (ex.proj.w > 0.5) {
		vec3 g = glow_bilinear(false, uv) * ex.glow.x + glow_bilinear(true, uv) * ex.glow.y;
		col += g * (1.0 - clamp(col, vec3(0.0), vec3(1.0)));
	}
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
