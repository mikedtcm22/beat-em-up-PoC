#[compute]
#version 450
// The video's finish pass (Phase 1, LD-INK; docs/video/PLAN.md Plan A part 5), a CompositorEffect compute
// shader (video/ink/post_effect.gd): a static paper grain, a vignette and a little chromatic aberration, in
// that order of importance and nothing else. The grain is fixed to the FRAME (its cells come from the pixel
// position and the paper seed, never from the time), like paper under a camera. It never touches the
// colour's hue: it moves the value by a few percent. The aberration is radial and tiny and zero at the
// centre; the vignette darkens toward the corners. Two dispatches: the first writes the finished frame to a temp image reading the colour with offsets, the second copies it back.

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
	float pad0;
	float pad1;
	float pad2;
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
	vec3 col;
	col.r = load_color(id + off).r;
	col.g = load_color(id).g;
	col.b = load_color(id - off).b;
	// The vignette, in a frame-aspect-corrected radius (0 at the centre, 1 at the corner).
	vec2 q = rd * vec2(p.size.x / p.size.y, 1.0);
	float r = length(q) / length(vec2(p.size.x / p.size.y, 1.0) * 0.5);
	col *= 1.0 - p.vignette * smoothstep(p.vignette_start, 1.0, r);
	// The paper grain: a few percent of value, brighter than dark so the darks stay clean ink.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col *= 1.0 + paper(vec2(id)) * p.grain * (0.4 + 0.6 * smoothstep(0.0, 0.25, lum));
	imageStore(temp_image, id, vec4(col, 1.0));
}
