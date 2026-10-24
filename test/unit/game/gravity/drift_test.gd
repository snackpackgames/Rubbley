extends GdUnitTestSuite

const MASS := 10.0
const DAMP := 0.2
const DELTA := 0.5

var _tuning: GravityTuning


## Builds Gravity Tuning with a round Drift speed.
func before_test() -> void:
	_tuning = GravityTuning.new()
	_tuning.drift_speed_m_per_s = 6.0


## The first tick starts the carry: the whole Drift speed in one tick, plus its damping:
## 10 × ((0, 0, −6) / 0.5 + (0, 0, −6) × 0.2).
func test_starts_the_carry_in_one_tick() -> void:
	var forces := Drift.new(_tuning).forces(3, 1, Vector3(0, 0, -2), MASS, DAMP, DELTA)
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal_approx(Vector3(0, 0, -132), Vector3.ONE * 1e-4)
	assert_vector(forces[2]).is_equal(Vector3.ZERO)


## Once carried, Drift only pays back the body's damping on the Drift speed: 10 × 6 × 0.2.
func test_then_pays_back_only_the_damping() -> void:
	var drift := Drift.new(_tuning)
	drift.forces(1, 0, Vector3.FORWARD, MASS, DAMP, DELTA)
	var forces := drift.forces(1, 0, Vector3.FORWARD, MASS, DAMP, DELTA)
	assert_vector(forces[0]).is_equal_approx(Vector3(0, 0, -12), Vector3.ONE * 1e-4)


## When the direction turns, Drift turns the carried velocity with it:
## 10 × (((6, 0, 0) − (0, 0, −6)) / 0.5 + (6, 0, 0) × 0.2).
func test_turns_the_carry_with_the_direction() -> void:
	var drift := Drift.new(_tuning)
	drift.forces(1, 0, Vector3.FORWARD, MASS, DAMP, DELTA)
	var forces := drift.forces(1, 0, Vector3.RIGHT, MASS, DAMP, DELTA)
	assert_vector(forces[0]).is_equal_approx(Vector3(132, 0, 120), Vector3.ONE * 1e-4)


## With no drifting body (index -1), nothing is pushed.
func test_pushes_nothing_without_a_drifting_body() -> void:
	var forces := Drift.new(_tuning).forces(2, -1, Vector3.RIGHT, MASS, DAMP, DELTA)
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)


## A direction with height is flattened onto the Play Plane before it's used.
func test_pushes_only_along_the_play_plane() -> void:
	var drift := Drift.new(_tuning)
	drift.forces(1, 0, Vector3(3, 5, 4), MASS, DAMP, DELTA)
	var forces := drift.forces(1, 0, Vector3(3, 5, 4), MASS, DAMP, DELTA)
	# (3, 0, 4) normalised is (0.6, 0, 0.8); 10 × 6 × 0.2 along it.
	assert_vector(forces[0]).is_equal_approx(Vector3(7.2, 0, 9.6), Vector3.ONE * 1e-4)


## Drift alone carries the body at its speed throughout: 6 m/s × 5 s.
func test_expected_distance_from_rest() -> void:
	var distance := Drift.new(_tuning).expected_distance(DAMP, 0.0, 1.0, 6.0)
	assert_float(distance).is_equal_approx(30.0, 1e-5)


## A body's own starting speed along the Drift fades at the damping rate on top:
## 30 + 1.5 × (e^(−0.2) − e^(−1.2)) / 0.2 = 30 + 1.5 × 2.587685.
func test_expected_distance_from_a_moving_start_with_damping() -> void:
	var distance := Drift.new(_tuning).expected_distance(DAMP, 1.5, 1.0, 6.0)
	assert_float(distance).is_equal_approx(33.881527, 1e-5)


## Without damping, the starting speed adds its speed times the window: 30 + 1.5 × 5.
func test_expected_distance_from_a_moving_start_without_damping() -> void:
	var distance := Drift.new(_tuning).expected_distance(0.0, 1.5, 1.0, 6.0)
	assert_float(distance).is_equal_approx(37.5, 1e-5)
