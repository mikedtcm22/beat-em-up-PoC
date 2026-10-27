shader_type spatial;
// The inverted-hull outline (Milestone 4): every character and prop's ink line, drawn as the
// mesh's material_overlay. The back faces of the mesh, pushed out along a direction by a width
// that is a constant number of screen pixels between near_m and far_m, so the line reads the
// same at 1 m and at 10 m (a thicker world line is drawn nearer than near_m, a thinner one
// beyond far_m). The width is in pixels at 1080p (look_outline_px), whatever the window or the
// field of view. Mirrored for the tests by ToonMaterials.outline_width_m().
//
// How the mesh is pushed out (`mode`), so no corner cracks and every face plane moves out by
// exactly the width: 0 along the vertex normal (spheres, capsules, smooth meshes); 1 a box,
// by sign(VERTEX) on each axis; 2 a cylinder, radially in xz plus sign(y) on the ends; 3 a
// sphere's own radius from its centre (a hemisphere's open rim); 4 a skinned art mesh's smooth
// normal baked in COLOR (n * 0.5 + 0.5, in the rest pose), carried through the skin from the
// rest normal in CUSTOM1 so it follows the bent body.
render_mode unshaded, cull_front;

uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float width_px : hint_range(0.0, 16.0) = 3.75;
uniform float near_m : hint_range(0.1, 10.0) = 1.0;
uniform float far_m : hint_range(1.0, 100.0) = 12.0;
// The player's own body is drawn thinner (look_outline_fp_scale); 1 on everything else.
uniform float fp_scale : hint_range(0.0, 2.0) = 1.0;
// The line fades out from lens_fade_m to twice that from the lens, since a lens inside a hull
// shell would see only ink.
uniform float lens_fade_m : hint_range(0.0, 1.0) = 0.1;
uniform int mode : hint_range(0, 4) = 0;

// The rotation that takes unit vector a onto unit vector b, applied to x (Rodrigues).
vec3 rotate_arc(vec3 a, vec3 b, vec3 x) {
	vec3 axis = cross(a, b);
	float c = dot(a, b);
	if (c < -0.999) {
		return -x;
	}
	return x + cross(axis, x) + cross(axis, cross(axis, x)) / (1.0 + c);
}

void vertex() {
	vec3 dir = NORMAL;
	if (mode == 1) {
		dir = vec3(VERTEX.x >= 0.0 ? 1.0 : -1.0, VERTEX.y >= 0.0 ? 1.0 : -1.0, VERTEX.z >= 0.0 ? 1.0 : -1.0);
	} else if (mode == 2) {
		float radial = length(VERTEX.xz);
		vec2 out_xz = radial > 0.00001 ? VERTEX.xz / radial : vec2(0.0);
		dir = vec3(out_xz.x, VERTEX.y >= 0.0 ? 1.0 : -1.0, out_xz.y);
	} else if (mode == 3) {
		dir = length(VERTEX) > 0.00001 ? normalize(VERTEX) : NORMAL;
	} else if (mode == 4) {
		vec3 smooth_rest = normalize(COLOR.rgb * 2.0 - 1.0);
		vec3 rest_normal = CUSTOM1.xyz;
		// Carry the baked normal through the skin: the shortest turn from the vertex's rest
		// normal to its skinned normal, applied to it. Without a rest normal, the skinned one.
		dir = length(rest_normal) > 0.5 ? rotate_arc(normalize(rest_normal), normalize(NORMAL), smooth_rest) : NORMAL;
	}
	float dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	// Metres per pixel at a distance is 2 d / (projection scale * viewport height); the width
	// is width_px at 1080p, so the viewport height cancels. Zero in an orthographic pass (a
	// directional light's shadow map), so the hull never fattens a shadow.
	float proj_scale = abs(PROJECTION_MATRIX[1][1]);
	float fade = smoothstep(0.0, 1.0, (dist - lens_fade_m) / max(lens_fade_m, 0.0001));
	float width_m = width_px * fp_scale * 2.0 * clamp(dist, near_m, far_m) / (1080.0 * proj_scale) * fade;
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		width_m = 0.0;
	}
	VERTEX += dir * width_m;
}

void fragment() {
	ALBEDO = ink;
}
