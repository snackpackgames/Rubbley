extends GdUnitTestSuite

const CAPTURE_RADIUS_M := 10.0

var _tuning: GravityTuning


## Builds Gravity Tuning with round Orbit thresholds.
func before_test() -> void:
	_tuning = GravityTuning.new()
	_tuning.orbit_radius_multiple = 1.5
	_tuning.orbit_radius_band = 1.2
	_tuning.orbit_travel_deg = 360.0


## A body circling its primary inside the Capture Radius is in Orbit once it has gone
## all the way round.
func test_a_full_circle_is_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, 361.0)
	assert_bool(orbit.is_in_orbit()).is_true()


## Short of a full circle, the body isn't in Orbit yet.
func test_most_of_a_circle_is_not_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, 350.0)
	assert_bool(orbit.is_in_orbit()).is_false()


## Circling the other way round counts the same.
func test_a_clockwise_circle_is_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, -361.0)
	assert_bool(orbit.is_in_orbit()).is_true()


## Swinging back and forth goes nowhere: the travel is net, not total.
func test_swinging_back_and_forth_is_not_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, 200.0)
	_circle(orbit, 8.0, 200.0, 0.0)
	_circle(orbit, 8.0, 0.0, 200.0)
	assert_bool(orbit.is_in_orbit()).is_false()


## A circle just inside the multiple of the Capture Radius (1.5 × 10 m) is an Orbit.
func test_a_circle_inside_the_capture_radius_multiple_is_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 14.9, 0.0, 361.0)
	assert_bool(orbit.is_in_orbit()).is_true()


## Going beyond the multiple of the Capture Radius ends the Orbit at once.
func test_leaving_the_capture_radius_multiple_ends_the_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, 361.0)
	orbit.track(_at(15.1, 361.0))
	assert_bool(orbit.is_in_orbit()).is_false()


## Coming back after leaving starts the count again from nothing.
func test_coming_back_after_leaving_starts_again() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, 300.0)
	orbit.track(_at(15.1, 300.0))
	_circle(orbit, 8.0, 300.0, 400.0)
	assert_bool(orbit.is_in_orbit()).is_false()


## A body whose distance swings wider than the band (furthest over closest above 1.2)
## isn't in Orbit, however far it travels round.
func test_breaking_the_radius_band_ends_the_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 8.0, 0.0, 361.0)
	orbit.track(_at(10.0, 366.0))
	assert_bool(orbit.is_in_orbit()).is_false()


## Breaking the band restarts the count where the body is, so a settled circle
## after a wide swing becomes an Orbit one full turn later.
func test_a_settled_circle_after_a_wide_swing_is_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	_circle(orbit, 6.0, 0.0, 180.0)
	_circle(orbit, 9.0, 180.0, 400.0)
	assert_bool(orbit.is_in_orbit()).is_false()
	_circle(orbit, 9.0, 400.0, 545.0)
	assert_bool(orbit.is_in_orbit()).is_true()


## A distance that varies inside the band still counts.
func test_a_slightly_oval_path_is_an_orbit() -> void:
	var orbit := Orbit.new(_tuning, CAPTURE_RADIUS_M)
	var angle_deg := 0.0
	while angle_deg <= 365.0:
		# Distance between 8 m and 9 m, a ratio of 1.125.
		var distance_m := 8.5 + 0.5 * cos(deg_to_rad(2.0 * angle_deg))
		orbit.track(_at(distance_m, angle_deg))
		angle_deg += 5.0
	assert_bool(orbit.is_in_orbit()).is_true()


# Tracks the body around the primary at the origin in 5° steps, from one angle to the
# other (a lower end angle goes the other way round), at a fixed distance.
func _circle(orbit: Orbit, distance_m: float, from_deg: float, to_deg: float) -> void:
	var step_deg := 5.0 if to_deg >= from_deg else -5.0
	var angle_deg := from_deg
	while absf(to_deg - angle_deg) > absf(step_deg):
		orbit.track(_at(distance_m, angle_deg))
		angle_deg += step_deg
	orbit.track(_at(distance_m, to_deg))


func _at(distance_m: float, angle_deg: float) -> Vector3:
	return Vector3(distance_m, 0, 0).rotated(Vector3.UP, deg_to_rad(angle_deg))
