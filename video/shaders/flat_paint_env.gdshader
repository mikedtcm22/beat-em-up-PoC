shader_type spatial;
// The video's flat-paint environment, the opaque material (every face of the kit but the chain-link's); see
// flat_paint_env_body.gdshaderinc. Swapped onto ToonMaterials.trim() at runtime by VideoWorldLook.
render_mode ambient_light_disabled;

#include "res://video/shaders/flat_paint_env_body.gdshaderinc"
