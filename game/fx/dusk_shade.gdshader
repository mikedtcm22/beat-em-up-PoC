shader_type spatial;
// A long flat shadow shape on the dusk roofs' deck (M7 x-roofs, DuskDeck): one hard-edged slanted band in two stepped tones (the shape,
// and a lighter step just outside it), the ends cut on a slant like a parapet's shadow under a low sun. Unshaded, drawn over the deck.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 shade_color : source_color = vec4(0.1, 0.03, 0.2, 0.5);
uniform vec4 edge_color : source_color = vec4(0.2, 0.07, 0.3, 0.3);
// How far the ends lean along the band (a share of the width), and the edge step's width as a share of the width.
uniform float slant : hint_range(-1.0, 1.0) = 0.45;
uniform float edge_share : hint_range(0.0, 0.3) = 0.06;
uniform vec2 card_m = vec2(10.0, 3.0);
uniform float seed = 1.0;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash12(vec2(i, seed)), hash12(vec2(i + 1.0, seed)), f);
}

// Signed distance-ish (negative inside) to the band with slanted ends, in metres. p is metres from the card's middle.
float band(vec2 p, float grow) {
	float half_w = card_m.y * 0.5 + grow;
	float half_l = card_m.x * 0.5 + grow;
	// A ragged long edge: the band's width drifts by a few tens of centimetres along it.
	float rag = (vnoise(p.x * 0.35 + seed * 3.0) - 0.5) * card_m.y * 0.12;
	float across = abs(p.y) - (half_w + rag);
	float along = abs(p.x - slant * p.y) - half_l;
	return max(across, along);
}

void fragment() {
	vec2 p = (UV - 0.5) * card_m;
	float aa = max(max(fwidth(p.x), fwidth(p.y)) * 1.2, 0.002);
	float edge_m = card_m.y * edge_share;
	float d_in = band(p, 0.0);
	float d_out = band(p, edge_m);
	float a_in = 1.0 - smoothstep(-aa, aa, d_in);
	float a_out = 1.0 - smoothstep(-aa, aa, d_out);
	if (a_out <= 0.0) {
		discard;
	}
	vec4 col = mix(edge_color, shade_color, a_in);
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a * opacity, 0.0, 1.0) * a_out;
}
