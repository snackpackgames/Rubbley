class_name SimulationTestSuite
extends GdUnitTestSuite
## Base for tests that step real physics. Scenarios are written in simulated
## seconds at the shipped tick rate, never in tick counts (ADR 0018).

# Absorbs float error in seconds × tick rate, so 4.15 s at 60 Hz is 249 ticks, not 250.
const _TICK_EPSILON := 1e-6


## Awaits exactly [code]ceil(seconds × physics_ticks_per_second)[/code] physics ticks.
## Each tick has a fixed delta however slowly the test runs.
func step_seconds(seconds: float) -> void:
	var ticks := ceili(seconds * Engine.physics_ticks_per_second - _TICK_EPSILON)
	for _tick in ticks:
		await get_tree().physics_frame
