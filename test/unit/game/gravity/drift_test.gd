extends GdUnitTestSuite

var _tuning: GravityTuning


## Builds Gravity Tuning with a round Drift force.
func before_test() -> void:
	_tuning = GravityTuning.new()
	_tuning.drift_force_n = 6.0


## Only the drifting body is pushed, with the Drift force along the direction.
func test_pushes_only_the_drifting_body() -> void:
	var forces := Drift.new(_tuning).forces(3, 1, Vector3(0, 0, -2))
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal_approx(Vector3(0, 0, -6), Vector3.ONE * 1e-5)
	assert_vector(forces[2]).is_equal(Vector3.ZERO)


## With no drifting body (index -1), nothing is pushed.
func test_pushes_nothing_without_a_drifting_body() -> void:
	var forces := Drift.new(_tuning).forces(2, -1, Vector3.RIGHT)
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)


## A direction with height is flattened onto the Play Plane before it's used.
func test_pushes_only_along_the_play_plane() -> void:
	var forces := Drift.new(_tuning).forces(1, 0, Vector3(3, 5, 4))
	# (3, 0, 4) normalised is (0.6, 0, 0.8).
	assert_vector(forces[0]).is_equal_approx(Vector3(3.6, 0, 4.8), Vector3.ONE * 1e-5)


## With damping c, speed from rest is F/(m·c)·(1 − e^(−c·t)); the distance integrates it.
func test_expected_distance_with_damping() -> void:
	# 6 N on 10 kg at c = 0.2 reaches 3 m/s at most; 1 s to 6 s covers 3 × (5 − 2.587685).
	var distance := Drift.new(_tuning).expected_distance(10.0, 0.2, 0.0, 1.0, 6.0)
	assert_float(distance).is_equal_approx(7.236952, 1e-5)


## Without damping, Drift accelerates uniformly: F/(2m)·(t1² − t0²).
func test_expected_distance_without_damping() -> void:
	var distance := Drift.new(_tuning).expected_distance(10.0, 0.0, 0.0, 1.0, 6.0)
	assert_float(distance).is_equal_approx(10.5, 1e-5)


## A body already moving along the Drift keeps that speed, fading at the damping rate.
func test_expected_distance_from_a_moving_start_with_damping() -> void:
	# v(t) = 3 + (1.5 − 3)·e^(−0.2·t); 1 s to 6 s covers 3 × 5 − 1.5 × 2.587685.
	var distance := Drift.new(_tuning).expected_distance(10.0, 0.2, 1.5, 1.0, 6.0)
	assert_float(distance).is_equal_approx(11.118473, 1e-5)


## Without damping, a moving start adds its speed times the window to the uniform push.
func test_expected_distance_from_a_moving_start_without_damping() -> void:
	# 1.5 × 5 + 0.3 × (36 − 1)
	var distance := Drift.new(_tuning).expected_distance(10.0, 0.0, 1.5, 1.0, 6.0)
	assert_float(distance).is_equal_approx(18.0, 1e-5)
