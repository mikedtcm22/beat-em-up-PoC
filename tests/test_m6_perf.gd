extends GutTest
## Milestone 6, final review (perf): the level walk's frame time. What the fix keeps true: the shared trim material is the
## opaque one and only the chain-link's wire is alpha-scissored (a scissoring shader loses the depth prepass and the cheap
## shadow pass for every mesh on it), a prop's shadow is cast by a coarser twin within a bounded error, and the bench's
## counters act is in the level bot's list.

const ATLAS := preload("res://assets/export/palette/palette_atlas.png")
const CAR := preload("res://assets/export/props/car/car.glb")


func before_each() -> void:
	StaticArt.clear_cache()


func after_each() -> void:
	Tuning.apply(TuningData.new())
	StaticArt.clear_cache()


func _car() -> StaticArt:
	var art := StaticArt.new()
	art.scene = CAR
	art.palette = ATLAS
	art.hull = true
	add_child_autofree(art)
	return art


func _tris(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total


func test_a_prop_casts_its_shadow_from_a_coarser_twin() -> void:
	var art := _car()
	var twins := art.shadow_casters()
	assert_eq(twins.size(), art.instances().size(), "every mesh of the car has a shadow twin")
	for i in twins.size():
		var drawn := art.instances()[i]
		assert_eq(drawn.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the drawn mesh does not cast")
		assert_eq(twins[i].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "its twin casts, and draws nothing")
		assert_lt(_tris(twins[i].mesh), _tris(drawn.mesh), "the twin has fewer triangles")
		assert_eq(twins[i].transform, drawn.transform, "and stands where the mesh does")
		assert_same(twins[i].material_override, drawn.material_override, "on the same material (the same vertex format)")


func test_the_twin_stays_within_the_tunables_error() -> void:
	Tuning.set_value(&"draw_prop_shadow_error_m", 0.0)
	var off := _car()
	assert_eq(off.shadow_casters().size(), 0, "0 draws the prop's own triangles in the shadow pass")
	for mesh in off.instances():
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "and the mesh casts as it did")
	StaticArt.clear_cache()
	Tuning.set_value(&"draw_prop_shadow_error_m", 0.001)
	var none := _car()
	assert_eq(none.shadow_casters().size(), 0, "no level of detail is within a millimetre: the mesh casts itself")


func test_the_shared_trim_shader_never_scissors() -> void:
	var code := ""
	for line in ToonMaterials.trim().shader.code.split("\n"):
		if not line.strip_edges().begins_with("//"):
			code += line + "\n"
	assert_false(code.contains("TRIM_SCISSOR"), "the opaque variant does not define the scissor")
	assert_false(code.contains("ALPHA"), "and writes no alpha itself")
	assert_ne(ToonMaterials.trim().shader, ToonMaterials.trim_scissor().shader)


func test_the_counters_act_is_in_the_perf_acts() -> void:
	var acts: Array[Dictionary] = load("res://tests/bot/level_acts/perf_acts.gd").call(&"acts", null)
	var titles := PackedStringArray()
	for act in acts:
		titles.append(String(act.title))
	assert_true(titles.has("Perf: level walk"))
	assert_true(titles.has("Perf: counters"), "fixed poses and the renderer's counters, for a load-proof before and after")
