extends GdUnitTestSuite
## The contracting rings that show a pull: each ring starts at the outer radius and
## shrinks to the inner one over a period, fading in as it closes, then starts again.

const TOLERANCE := 1e-4


## A ring starts each period at the outer radius.
func test_a_ring_starts_at_the_outer_radius() -> void:
	assert_float(AttractPulse.ring_radius_m(0.0, 2.0, 1.0, 4.0, 0.0)).is_equal_approx(
		4.0,
		TOLERANCE,
	)


## Halfway through its period a ring is halfway in: 4 m → 1 m reaches 2.5 m.
func test_a_ring_closes_on_the_inner_radius() -> void:
	assert_float(AttractPulse.ring_radius_m(1.0, 2.0, 1.0, 4.0, 0.0)).is_equal_approx(
		2.5,
		TOLERANCE,
	)


## A ring offset by half a period is on the other half of its cycle, so two rings never
## overlap.
func test_an_offset_ring_runs_half_a_cycle_ahead() -> void:
	assert_float(AttractPulse.ring_radius_m(0.0, 2.0, 1.0, 4.0, 0.5)).is_equal_approx(
		2.5,
		TOLERANCE,
	)


## The cycle repeats: one period on, the ring is back at the outer radius.
func test_the_cycle_repeats() -> void:
	assert_float(AttractPulse.ring_radius_m(2.0, 2.0, 1.0, 4.0, 0.0)).is_equal_approx(
		4.0,
		TOLERANCE,
	)


## A ring is invisible as it appears at the outer radius and most solid as it closes.
func test_a_ring_fades_in_as_it_closes() -> void:
	var appearing := AttractPulse.ring_opacity(0.0, 2.0, 0.0)
	var halfway := AttractPulse.ring_opacity(1.0, 2.0, 0.0)
	var closing := AttractPulse.ring_opacity(1.9, 2.0, 0.0)
	assert_float(appearing).is_equal_approx(0.0, TOLERANCE)
	assert_float(halfway).is_equal_approx(0.5, TOLERANCE)
	assert_float(closing).is_greater(halfway)
