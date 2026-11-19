extends GdUnitTestSuite
## The expanding ring that shows a Repel: it grows from where the push starts to how far
## it reaches, fast at first and easing out, and fades to nothing as it gets there.

const TOLERANCE := 1e-4


## A wave starts at its start radius, fully opaque.
func test_a_wave_starts_at_its_start_radius() -> void:
	assert_float(RepelWave.radius_m(0.0, 0.8, 1.0, 9.0)).is_equal_approx(1.0, TOLERANCE)
	assert_float(RepelWave.opacity(0.0, 0.8)).is_equal_approx(1.0, TOLERANCE)


## Halfway through, it has covered three quarters of the way: it eases out, quadratically.
func test_a_wave_eases_out() -> void:
	assert_float(RepelWave.radius_m(0.4, 0.8, 1.0, 9.0)).is_equal_approx(7.0, TOLERANCE)
	assert_float(RepelWave.opacity(0.4, 0.8)).is_equal_approx(0.5, TOLERANCE)


## At the end, and after, it sits at its reach and is invisible.
func test_a_wave_ends_at_its_reach_and_invisible() -> void:
	assert_float(RepelWave.radius_m(2.0, 0.8, 1.0, 9.0)).is_equal_approx(9.0, TOLERANCE)
	assert_float(RepelWave.opacity(2.0, 0.8)).is_equal_approx(0.0, TOLERANCE)
