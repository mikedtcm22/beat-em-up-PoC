class_name VideoWorldPlume
extends RefCounted
## Builds the steam of a world look (R4-WORLD): a plume per vent, a few big flat lobes drawn on a card (video/shaders/steam_plume.gdshader), never a column of
## particle puffs. One emitter spec (kind STEAM) gives `amount` plumes at each of its points: the card is `size_m` (width, height), a plume's life is `life_s`, and
## each differs by its seed. The card's `slot` is written by the rig from the shot's frame (never the clock).


## The plume cards of `spec` at `at` (section origin + a point): `amount` of them, each a MeshInstance3D whose material carries meta `plume`.
static func build(look: VideoWorldLook, spec: VideoWorldEmitter, at: Vector3, point_index: int) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for k in spec.amount:
		var material := ShaderMaterial.new()
		material.shader = VideoWorldLook.PLUME_SHADER
		var base_seed := float(spec.seed) * 3.1 + float(point_index) * 7.7 + float(k) * 4.3
		material.set_shader_parameter(&"seed", base_seed)
		material.set_shader_parameter(&"rate", 1.0 / maxf(spec.life_s * float(look.flicker_fps), 1.0))
		# The first plume is the big one; a second is smaller, shifted, curling the other way (a vent that gives two wisps).
		var scale_k := 1.0 if k == 0 else 0.66
		var card := Vector2(spec.size_m.x, spec.size_m.y) * scale_k
		material.set_shader_parameter(&"card_m", card)
		material.set_shader_parameter(&"lobe_r_m", spec.size_m.x * 0.3 * scale_k)
		material.set_shader_parameter(&"curl_m", spec.size_m.x * 0.26 * (1.0 if k == 0 else -1.0))
		material.set_shader_parameter(&"shade_m", spec.size_m.x * 0.09)
		material.set_shader_parameter(&"lobes", 5)
		material.set_shader_parameter(&"bump", 0.24)
		material.set_shader_parameter(&"light_color", spec.color_start)
		material.set_shader_parameter(&"dark_color", spec.color_end)
		var quad := QuadMesh.new()
		quad.size = card
		var instance := MeshInstance3D.new()
		instance.name = "Plume_%d_%d" % [point_index, k]
		instance.mesh = quad
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.extra_cull_margin = 4.0
		instance.position = at + Vector3(0.0, 0.0, 0.0) + Vector3(0.35 * float(k), 0.0, 0.0)
		instance.set_meta(&"plume", material)
		out.append(instance)
	return out
