extends GdUnitTestSuite
## Invariants on the shipped Input Tuning (ADR 0017), so a bad retune can't leave a
## control that chatters or can never fire.

const TUNING := preload("res://game/input/input_tuning.tres")


## A trigger lets go below where it presses, so one resting near the press point doesn't
## chatter.
func test_triggers_release_below_their_press_point() -> void:
	assert_float(TUNING.trigger_release_point).is_less(TUNING.trigger_press_point)
	assert_float(TUNING.trigger_release_point).is_greater(0.0)
	assert_float(TUNING.trigger_press_point).is_less(1.0)


## The stick saturates past its deadzone, and full tilt is a tilt the stick can reach.
func test_the_stick_tilts_past_its_deadzone_to_full_tilt() -> void:
	assert_float(TUNING.stick_deadzone).is_less(TUNING.stick_saturation)
	assert_float(TUNING.stick_saturation).is_less_equal(1.0)
	assert_float(TUNING.full_tilt).is_between(0.0, 1.0)


## A picked body stays picked a little past where it would be picked, so the pick doesn't
## flicker, and the reach goes past the aim range.
func test_picks_keep_past_where_they_pick() -> void:
	assert_float(TUNING.reach_hysteresis_deg).is_greater_equal(0.0)
	assert_float(TUNING.reach_range_multiple).is_greater_equal(1.0)
