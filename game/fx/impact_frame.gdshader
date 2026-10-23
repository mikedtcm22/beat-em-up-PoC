shader_type canvas_item;
// The finisher impact frame (Spec §6): the screen redrawn as a high-contrast, inverted
// two-tone ink print. Bright parts print ink and dark parts paper; each pixel is judged
// against a blend of the threshold and its blurred neighborhood, so shapes keep their
// edges instead of flooding into one tone.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float threshold : hint_range(0.0, 1.0) = 0.45;
// How much the neighborhood (a blurred mip) moves the threshold, 0..1.
uniform float local_mix : hint_range(0.0, 1.0) = 0.6;
uniform vec4 ink : source_color = vec4(0.07, 0.06, 0.09, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.94, 0.85, 1.0);

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	float here = luma(textureLod(screen_texture, SCREEN_UV, 0.0).rgb);
	float around = luma(textureLod(screen_texture, SCREEN_UV, 5.0).rgb);
	float cut = mix(threshold, around, local_mix);
	COLOR = mix(paper, ink, step(cut, here));
}
