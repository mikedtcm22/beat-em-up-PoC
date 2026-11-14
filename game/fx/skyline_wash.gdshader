shader_type spatial;
// A flat tone over a far facade (M7 G4, flattened in C4): a card a hand's breadth in front of each far face dims its windows toward the
// wall so the far street recedes into the night. It was irregular patches of two tones (G4); they read as camouflage over the window
// rows and are gone: this is one flat colour at one even opacity, `cover` of the colour's alpha, and no pattern at all (the kit's facade
// strip itself breaks the rows). Mixed over the picture, unshaded, never written to the depth buffer. Presentation only (the trailer profile).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 wash_color : source_color = vec4(0.2, 0.18, 0.42, 0.7);
// The card's size in metres and the old patch size: kept so the wash is set the way it always was; neither draws anything now.
uniform vec2 card_m = vec2(20.0, 20.0);
uniform float patch_m : hint_range(1.0, 20.0) = 5.0;
// How much of the colour's alpha the tone takes.
uniform float cover : hint_range(0.0, 1.0) = 0.42;
uniform float seed = 1.0;

void fragment() {
	ALBEDO = wash_color.rgb;
	ALPHA = clamp(wash_color.a * cover * 0.35, 0.0, 1.0);
}
