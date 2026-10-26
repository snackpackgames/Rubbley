extends GdUnitTestSuite

## A pull of 1000 m³/s² at 10 m gives a circular speed of √(1000 / 10) = 10 m/s.
const PULL_STRENGTH := 1000.0
const OFFSET := Vector3(10, 0, 0)


## At 1 × circular speed the launch is 10 m/s across the offset, turning anticlockwise
## about +Y (right-hand rule): from +X toward −Z.
func test_launches_at_circular_speed_across_the_offset() -> void:
	var velocity := OrbitLaunch.velocity(OFFSET, PULL_STRENGTH, 1.0, true)
	assert_vector(velocity).is_equal_approx(Vector3(0, 0, -10), Vector3.ONE * 1e-4)


## Clockwise turns the other way round.
func test_launches_clockwise() -> void:
	var velocity := OrbitLaunch.velocity(OFFSET, PULL_STRENGTH, 1.0, false)
	assert_vector(velocity).is_equal_approx(Vector3(0, 0, 10), Vector3.ONE * 1e-4)


## The speed multiple scales the circular speed: 1.2 × 10 m/s.
func test_scales_by_the_speed_multiple() -> void:
	var velocity := OrbitLaunch.velocity(Vector3(0, 0, 10), PULL_STRENGTH, 1.2, true)
	assert_vector(velocity).is_equal_approx(Vector3(12, 0, 0), Vector3.ONE * 1e-4)


## Height off the Play Plane is ignored: the launch is from the flattened offset.
func test_ignores_height_off_the_play_plane() -> void:
	var velocity := OrbitLaunch.velocity(Vector3(10, 3, 0), PULL_STRENGTH, 1.0, true)
	assert_vector(velocity).is_equal_approx(Vector3(0, 0, -10), Vector3.ONE * 1e-4)


## Launched from 20 m, an orbit whose closest point is 10 m starts at √(2 × 10 / 30)
## of circular speed: vis-viva puts the closest point at 20 × (2/3) / (4/3) = 10 m.
func test_slowest_launch_keeps_the_orbit_above_its_lowest_point() -> void:
	assert_float(OrbitLaunch.slowest_speed_multiple(20.0, 10.0)).is_equal_approx(0.816497, 1e-5)
