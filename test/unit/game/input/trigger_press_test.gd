extends GdUnitTestSuite
## A trigger's presses and releases, with hysteresis (ADR 0013): it presses past the press
## point and lets go only below the lower release point.

var _trigger: TriggerPress


## Builds a trigger pressing at 0.6 and letting go at 0.4, set here so a retune doesn't
## break the tests.
func before_test() -> void:
	var tuning := InputTuning.new()
	tuning.trigger_press_point = 0.6
	tuning.trigger_release_point = 0.4
	_trigger = TriggerPress.new(tuning)


## Travel up to the press point doesn't press.
func test_travel_short_of_the_press_point_does_not_press() -> void:
	var edge := _trigger.update(0.6)
	assert_int(edge).is_equal(TriggerPress.Edge.NONE)
	assert_bool(_trigger.is_down()).is_false()


## Travel past the press point presses, once.
func test_travel_past_the_press_point_presses_once() -> void:
	var first := _trigger.update(0.7)
	var second := _trigger.update(0.9)
	assert_int(first).is_equal(TriggerPress.Edge.PRESSED)
	assert_int(second).is_equal(TriggerPress.Edge.NONE)
	assert_bool(_trigger.is_down()).is_true()


## A pressed trigger falling between the two points stays pressed, so it doesn't chatter.
func test_a_pressed_trigger_holds_between_the_points() -> void:
	_trigger.update(0.7)
	var edge := _trigger.update(0.5)
	assert_int(edge).is_equal(TriggerPress.Edge.NONE)
	assert_bool(_trigger.is_down()).is_true()


## A pressed trigger lets go below the release point.
func test_a_pressed_trigger_lets_go_below_the_release_point() -> void:
	_trigger.update(0.7)
	var edge := _trigger.update(0.3)
	assert_int(edge).is_equal(TriggerPress.Edge.RELEASED)
	assert_bool(_trigger.is_down()).is_false()


## After a reset, a trigger still held must pass the press point again to press.
func test_a_reset_trigger_must_press_again() -> void:
	_trigger.update(0.9)
	_trigger.reset()
	var held_on := _trigger.update(0.5)
	var pressed_again := _trigger.update(0.8)
	assert_int(held_on).is_equal(TriggerPress.Edge.NONE)
	assert_int(pressed_again).is_equal(TriggerPress.Edge.PRESSED)
	assert_bool(_trigger.is_down()).is_true()


## A trigger counts as held, for swallowing input, until it falls below the release
## point, pressed or not: one reset while pulled stays held, one resting low isn't.
func test_a_trigger_is_held_until_below_the_release_point() -> void:
	_trigger.update(0.9)
	_trigger.reset()
	var held_after_reset := _trigger.is_held()
	_trigger.update(0.3)
	assert_bool(held_after_reset).is_true()
	assert_bool(_trigger.is_held()).is_false()
