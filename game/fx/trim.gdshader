shader_type spatial;
// The environment kit's trim material (Milestone 6, KIT; plan D2 and D10): ONE material for every
// module, dressing piece and barrier panel (ToonMaterials.trim()), so the draw count follows the mesh
// count only. Lit by the same toon lighting as the rest (toon_light.gdshaderinc: the bands, the tinted
// shadow, the sun alone; ToonMaterials gives it the Look values and the environment's two bands and no
// highlight, like grid.gdshader).
//
// The sheet (assets/export/kit/trim_sheet.png) is 16 strips of 128 px, each seamless both ways. A face
// carries its UVs in METRES (u along the face, v up it) and its strip in the vertex colour: COLOR.rgb is
// a tint (a multiplier, white for none), COLOR.a the strip's row / 255. The strip's row, its period in
// metres and its flags come from the `strips` table (trim_strips.json through ToonMaterials), so a wall
// of any length or height is the strip repeated, never stretched. The sheet's RGB is the surface; its
// ALPHA is the ink mask (a painted seam, crack or joint), cut at `ink_cut` with an edge one pixel wide
// (the same cut as toon.gdshader's detail_cut) so a line stays crisp under the mipmaps; on the scissor
// strip (the chain-link) the alpha is the wire's coverage instead, cut by the scissor. The sheet is a
// stack of wrapped strips, so the mip level is capped (`lod_cap`): past it one strip would blend into
// its neighbour.
//
// Two shaders share the body (trim_body.gdshaderinc): this one is OPAQUE, for every face but the chain-link's, and
// trim_scissor.gdshader adds the alpha scissor for the chain-link's wire. A shader that writes
// ALPHA_SCISSOR_THRESHOLD, even on one branch, loses the renderer's depth prepass and draws its whole fragment
// (a mip-gradient fetch from a 2048 px sheet and the toon lighting) in every shadow cascade, so the 330 modules
// of a level cost a fifth of the frame on it (M6 final review, perf); split off, the walls take the shared
// opaque path.
render_mode ambient_light_disabled;

#include "res://game/fx/toon_light.gdshaderinc"
#include "res://game/fx/trim_body.gdshaderinc"
