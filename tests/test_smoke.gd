extends GutTest
## Proves the headless test pipeline runs. Real suites live beside this file.


func test_engine_runs_physics_at_60hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 60)
