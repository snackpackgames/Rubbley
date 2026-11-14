extends GdUnitTestSuite
## The Stat Modifiers active on Rubbley (ADR 0017): a timed one lasts its duration, then
## goes; one with no duration lasts for good.

var _active: ActiveStatModifiers


## Starts with nothing active.
func before_test() -> void:
	_active = ActiveStatModifiers.new()


## A timed modifier stays active through its duration and goes once it is over, and
## advancing reports the tick it went.
func test_a_timed_modifier_lasts_its_duration() -> void:
	var timed := _modifier(1.0)
	_active.add(timed)
	var expired_early := _active.advance(0.9)
	var active_early := _active.modifiers().has(timed)
	var expired_late := _active.advance(0.2)
	assert_bool(expired_early).is_false()
	assert_bool(active_early).is_true()
	assert_bool(expired_late).is_true()
	assert_array(_active.modifiers()).is_empty()


## A modifier with no duration lasts for good, while a timed one beside it goes.
func test_a_modifier_with_no_duration_lasts_for_good() -> void:
	var lasting := _modifier(0.0)
	_active.add(lasting)
	_active.add(_modifier(0.5))
	_active.advance(1000.0)
	assert_array(_active.modifiers()).contains_exactly([lasting])


func _modifier(duration_s: float) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.duration_s = duration_s
	return modifier
