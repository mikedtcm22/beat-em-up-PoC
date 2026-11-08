shader_type spatial;
// The chain-link's variant of the flat-paint environment: the same body with the alpha scissor on (a shader that
// writes ALPHA_SCISSOR_THRESHOLD loses the depth prepass, so the opaque faces keep their own shader). Swapped onto
// ToonMaterials.trim_scissor() at runtime by VideoWorldLook.
render_mode ambient_light_disabled;

#define FLAT_PAINT_SCISSOR
#include "res://video/shaders/flat_paint_env_body.gdshaderinc"
