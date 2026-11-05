shader_type spatial;
// The chain-link's variant of the trim material (M6 final review, perf; see trim.gdshader): the same body with the
// alpha scissor on, for the faces on the scissor strip only (KitMesh puts them in a surface of their own).
render_mode ambient_light_disabled;

#define TRIM_SCISSOR
#include "res://game/fx/toon_light.gdshaderinc"
#include "res://game/fx/trim_body.gdshaderinc"
