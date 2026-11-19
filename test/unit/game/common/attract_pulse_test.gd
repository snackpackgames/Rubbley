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


## A ring is as wide as the pull is strong where it is: the pull falls off in a straight
## line from full at the centre to nothing at the outer radius, so a ring at the outer
## radius has no width and one halfway in is half the widest.
func test_a_ring_widens_with_the_pull_as_it_closes() -> void:
	# A 10 m reach whose widest ring is 2 m.
	var at_edge := AttractPulse.ring_width_m(10.0, 10.0, 2.0)
	var halfway := AttractPulse.ring_width_m(5.0, 10.0, 2.0)
	var near_centre := AttractPulse.ring_width_m(1.0, 10.0, 2.0)
	assert_float(at_edge).is_equal_approx(0.0, TOLERANCE)
	assert_float(halfway).is_equal_approx(1.0, TOLERANCE)
	assert_float(near_centre).is_equal_approx(1.8, TOLERANCE)
