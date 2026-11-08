extends GdUnitTestSuite
## Spin's timing: a Spin's shield lasts its duration, a lockout follows, and the perfect
## window opens at its start.

var _timer: SpinTimer


## Builds a timer on a 0.4 s Spin with a 0.6 s lockout and a 0.1 s perfect window.
func before_test() -> void:
	var tuning := SpinTuning.new()
	tuning.duration_s = 0.4
	tuning.lockout_s = 0.6
	tuning.perfect_window_s = 0.1
	_timer = SpinTimer.new(tuning)


## Nothing is up until a Spin fires.
func test_the_shield_is_down_before_any_spin() -> void:
	assert_bool(_timer.is_spinning()).is_false()


## The shield stays up for the Spin's duration, then drops.
func test_the_shield_lasts_the_spins_duration() -> void:
	_timer.fire()
	_timer.advance(0.39)
	var up_before := _timer.is_spinning()
	_timer.advance(0.02)
	assert_bool(up_before).is_true()
	assert_bool(_timer.is_spinning()).is_false()


## Firing while the shield is up doesn't extend it.
func test_firing_while_up_doesnt_extend_the_shield() -> void:
	_timer.fire()
	_timer.advance(0.3)
	_timer.fire()
	_timer.advance(0.11)
	assert_bool(_timer.is_spinning()).is_false()


## Firing during the lockout does nothing, and doesn't lengthen it either.
func test_the_lockout_refuses_spins_without_lengthening() -> void:
	_timer.fire()
	_timer.advance(0.9)
	_timer.fire()
	var fired_in_lockout := _timer.is_spinning()
	_timer.advance(0.11)
	_timer.fire()
	assert_bool(fired_in_lockout).is_false()
	assert_bool(_timer.is_spinning()).is_true()


## The perfect window covers only the start of a Spin.
func test_the_perfect_window_is_the_start_of_a_spin() -> void:
	_timer.fire()
	_timer.advance(0.09)
	var perfect_early := _timer.is_perfect()
	_timer.advance(0.02)
	assert_bool(perfect_early).is_true()
	assert_bool(_timer.is_perfect()).is_false()
	assert_bool(_timer.is_spinning()).is_true()
