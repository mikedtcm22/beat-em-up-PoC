shader_type spatial;
// The burn barrel's body (M7 T16a, F3): flat, unlit, a blue-grey drum with darker rib bands, lit by its own fire. The fire's light is
// two stepped tones, like the trailer's drum (t_05.jpg): the rim and the top third of the wall turn orange, a thin hot line runs along
// each rib on the fire's side, and the open top shows the coals inside. The fire sits above the drum, so the lit tone climbs the wall.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 body_color : source_color = vec3(0.2, 0.22, 0.3);
uniform vec3 rib_color : source_color = vec3(0.11, 0.12, 0.18);
uniform vec3 fire_color : source_color = vec3(0.88, 0.4, 0.12);
uniform vec3 hot_color : source_color = vec3(1.0, 0.66, 0.24);
uniform float height_m = 0.95;
// Where the fire's lit tones begin on the wall (share of the height), and how much of the wall's tone the fire replaces.
uniform float lit_from : hint_range(0.3, 1.0) = 0.62;
uniform float lit_mix : hint_range(0.0, 1.0) = 0.55;

varying float ly;
varying float ny;

void vertex() {
	ly = VERTEX.y / height_m + 0.5;
	ny = NORMAL.y;
}

void fragment() {
	if (ny > 0.9) {
		// The open top: the coals inside, hot orange.
		ALBEDO = mix(hot_color, fire_color, 0.3);
	} else {
		float f = fract(ly * 3.0 + 0.17);
		float rib = step(abs(f - 0.5), 0.07);
		vec3 c = mix(body_color, rib_color, rib);
		// The fire's two stepped tones climb the wall from the rim.
		c = mix(c, fire_color, step(lit_from, ly) * lit_mix);
		c = mix(c, hot_color, step(lit_from + 0.2, ly) * 0.55);
		// A rib's upper lip catches the fire all the way down the drum, a thin hot line.
		float lip = step(0.5, f) * step(f, 0.57);
		c = mix(c, fire_color, lip * 0.7);
		ALBEDO = c;
	}
}
