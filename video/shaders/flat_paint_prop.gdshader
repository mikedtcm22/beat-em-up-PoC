shader_type spatial;
// The flat-paint environment's prop variant (LD-WORLD): a lamp post, a barrel, a video-only prop painted by the same light() as the
// kit, in the `albedo` colour. See flat_paint_env_body.gdshaderinc.
render_mode ambient_light_disabled;

#define FLAT_PAINT_PROP
#include "res://video/shaders/flat_paint_env_body.gdshaderinc"
