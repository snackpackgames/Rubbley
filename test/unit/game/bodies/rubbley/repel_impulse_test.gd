extends GdUnitTestSuite
## Repel's impulse maths (ADR 0006): the radial falloff a Repel Pulse and a Gravity
## Ripple share, and the line a Targeted Repel pushes along.

const RADIUS_M := 8.0
const SPEED := 20.0


## A quarter of the way out a body is pushed away at three quarters of full speed,
## three quarters of the way out at a quarter.
func test_radial_push_falls_off_linearly_to_the_edge() -> void:
	var near := RepelImpulse.radial_velocity_change(Vector3.ZERO, Vector3(2, 0, 0), RADIUS_M, SPEED)
	var far := RepelImpulse.radial_velocity_change(Vector3.ZERO, Vector3(0, 0, -6), RADIUS_M, SPEED)
	assert_vector(near).is_equal_approx(Vector3(15, 0, 0), Vector3.ONE * 1e-4)
	assert_vector(far).is_equal_approx(Vector3(0, 0, -5), Vector3.ONE * 1e-4)


## The push is measured from a centre anywhere on the Play Plane, not only the origin.
func test_radial_push_points_away_from_its_centre() -> void:
	var change := RepelImpulse.radial_velocity_change(
		Vector3(10, 0, 10),
		Vector3(10, 0, 14),
		RADIUS_M,
		SPEED,
	)
	assert_vector(change).is_equal_approx(Vector3(0, 0, 10), Vector3.ONE * 1e-4)


## Nothing at or past the edge is pushed, and nothing at the exact centre, which has no
## direction to be pushed in.
func test_radial_push_misses_the_edge_and_the_exact_centre() -> void:
	var at_edge := RepelImpulse.radial_velocity_change(
		Vector3.ZERO,
		Vector3(8, 0, 0),
		RADIUS_M,
		SPEED,
	)
	var past := RepelImpulse.radial_velocity_change(Vector3.ZERO, Vector3(9, 0, 0), RADIUS_M, SPEED)
	var centre := RepelImpulse.radial_velocity_change(Vector3.ZERO, Vector3.ZERO, RADIUS_M, SPEED)
	assert_vector(at_edge).is_equal(Vector3.ZERO)
	assert_vector(past).is_equal(Vector3.ZERO)
	assert_vector(centre).is_equal(Vector3.ZERO)


## Height off the Play Plane is ignored: a body 2 m out and 5 m up is pushed as if 2 m out,
## and only across the plane.
func test_radial_push_ignores_height() -> void:
	var change := RepelImpulse.radial_velocity_change(
		Vector3.ZERO,
		Vector3(2, 5, 0),
		RADIUS_M,
		SPEED,
	)
	assert_vector(change).is_equal_approx(Vector3(15, 0, 0), Vector3.ONE * 1e-4)


## A Targeted Repel pushes the target straight away from Rubbley with the whole impulse.
func test_targeted_impulse_pushes_the_target_away_from_rubbley() -> void:
	var impulse := RepelImpulse.targeted_impulse(Vector3(1, 0, 1), Vector3(1, 0, -3), 100.0)
	assert_vector(impulse).is_equal_approx(Vector3(0, 0, -100), Vector3.ONE * 1e-4)


## A target at Rubbley's own point has no line to push along, so nothing is pushed.
func test_targeted_impulse_needs_a_line() -> void:
	var impulse := RepelImpulse.targeted_impulse(Vector3(1, 0, 1), Vector3(1, 3, 1), 100.0)
	assert_vector(impulse).is_equal(Vector3.ZERO)
