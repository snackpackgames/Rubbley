extends GdUnitTestSuite

## The short side shows 100 m, so fractions of it read as metres.
const EXTENT_M := 100.0

var _tuning: CameraTuning


## Builds Camera Tuning with round numbers: a 1 s follow half-life, a 0.3 max offset,
## a 0.2 Nudge radius and a 1 s Nudge half-life.
func before_test() -> void:
	_tuning = CameraTuning.new()
	_tuning.follow_half_life_s = 1.0
	_tuning.max_offset = 0.3
	_tuning.nudge_radius = 0.2
	_tuning.nudge_half_life_s = 1.0


## The first step frames Rubbley dead centre, with no swoop in from the origin.
func test_the_first_step_starts_on_rubbley() -> void:
	var follow := CameraFollow.new(_tuning)
	var focus := follow.step(Vector3(5, 0, 7), Vector3.ZERO, EXTENT_M, 0.1)
	assert_vector(focus).is_equal(Vector3(5, 0, 7))


## After one half-life the camera has closed half its gap to Rubbley.
func test_one_half_life_closes_half_the_gap() -> void:
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 0.1)
	var focus := follow.step(Vector3(20, 0, 0), Vector3.ZERO, EXTENT_M, 1.0)
	assert_vector(focus).is_equal_approx(Vector3(10, 0, 0), Vector3.ONE * 1e-4)


## Many short steps add up to the same follow as one long one.
func test_the_follow_does_not_depend_on_frame_rate() -> void:
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 0.1)
	var focus := Vector3.ZERO
	for _frame in 60:
		focus = follow.step(Vector3(20, 0, 0), Vector3.ZERO, EXTENT_M, 1.0 / 60.0)
	assert_vector(focus).is_equal_approx(Vector3(10, 0, 0), Vector3.ONE * 1e-3)


## A half-life of 0 is a hard lock: Rubbley is always dead centre.
func test_a_zero_half_life_is_a_hard_lock() -> void:
	_tuning.follow_half_life_s = 0.0
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 0.1)
	var focus := follow.step(Vector3(20, 0, 3), Vector3.ZERO, EXTENT_M, 1.0 / 60.0)
	assert_vector(focus).is_equal(Vector3(20, 0, 3))


## However far Rubbley outruns the camera, he stays within 0.3 of the short side
## (30 m) of the centre.
func test_lag_is_clamped_to_the_max_offset() -> void:
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 0.1)
	var focus := follow.step(Vector3(100, 0, 0), Vector3.ZERO, EXTENT_M, 0.1)
	assert_vector(focus).is_equal_approx(Vector3(70, 0, 0), Vector3.ONE * 1e-4)


## Once clamped, the camera follows on from where it is shown, not from where an
## unclamped follow would have been: 30 m behind halves to 15 m in one half-life.
func test_the_follow_carries_on_from_the_clamped_point() -> void:
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 0.1)
	follow.step(Vector3(100, 0, 0), Vector3.ZERO, EXTENT_M, 0.1)
	var focus := follow.step(Vector3(100, 0, 0), Vector3.ZERO, EXTENT_M, 1.0)
	assert_vector(focus).is_equal_approx(Vector3(85, 0, 0), Vector3.ONE * 1e-4)


## Held for one half-life, a full Nudge peeks half its 0.2 radius (20 m) ahead.
func test_a_held_nudge_peeks_toward_its_radius() -> void:
	_tuning.follow_half_life_s = 0.0
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 0.1)
	var focus := follow.step(Vector3.ZERO, Vector3.FORWARD, EXTENT_M, 1.0)
	assert_vector(focus).is_equal_approx(Vector3(0, 0, -10), Vector3.ONE * 1e-4)


## Released, a Nudge springs halfway back to Rubbley in one half-life.
func test_a_released_nudge_springs_back() -> void:
	_tuning.follow_half_life_s = 0.0
	_tuning.nudge_half_life_s = 0.0
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.RIGHT, EXTENT_M, 0.1)
	_tuning.nudge_half_life_s = 1.0
	var focus := follow.step(Vector3.ZERO, Vector3.ZERO, EXTENT_M, 1.0)
	assert_vector(focus).is_equal_approx(Vector3(10, 0, 0), Vector3.ONE * 1e-4)


## A Nudge input longer than 1 peeks no further than a full one.
func test_a_nudge_never_peeks_past_its_radius() -> void:
	_tuning.follow_half_life_s = 0.0
	_tuning.nudge_half_life_s = 0.0
	var follow := CameraFollow.new(_tuning)
	var focus := follow.step(Vector3.ZERO, Vector3(3, 0, 4), EXTENT_M, 0.1)
	assert_vector(focus).is_equal_approx(Vector3(12, 0, 16), Vector3.ONE * 1e-4)


## Follow lag and Nudge add into one offset under one clamp: 14.1 m of lag plus a 20 m
## Nudge, both behind Rubbley, stop at 30 m.
func test_lag_and_nudge_share_the_max_offset() -> void:
	_tuning.nudge_half_life_s = 0.0
	var follow := CameraFollow.new(_tuning)
	follow.step(Vector3.ZERO, Vector3.LEFT, EXTENT_M, 0.1)
	var focus := follow.step(Vector3(20, 0, 0), Vector3.LEFT, EXTENT_M, 0.5)
	assert_vector(focus).is_equal_approx(Vector3(-10, 0, 0), Vector3.ONE * 1e-4)
