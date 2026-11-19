extends GdUnitTestSuite
## The touch gestures Move Input recognises (ADRs 0012, 0013): a one-finger swipe is Spin,
## a pinch-in is Attract, a pinch-out is Repel and a two-finger drag is Nudge. Positions
## are in pixels with half the screen's short side at 100 px, so tuning fractions read
## as hundredths of a pixel distance.

const UNIT_PX := 100.0
## How far a pinch centre may be from the true centre: fingers report one at a time, so a
## pinch classifies with one finger a step ahead of the other.
const CENTRE_TOLERANCE_PX := 5.0

var _recogniser: TouchRecogniser
var _tuning: InputTuning
# Every signal the recogniser emitted, in order, as [name, args...].
var _heard: Array[Array] = []
# Where [method _two_fingers_down] put fingers 0 and 1.
var _down_at: PackedVector2Array = []


## Builds a recogniser on default tuning and records what it emits.
func before_test() -> void:
	_heard.clear()
	# Every threshold the recogniser reads, set here so a retune doesn't break the tests.
	_tuning = InputTuning.new()
	_tuning.swipe_distance = 0.15
	_tuning.swipe_speed_per_s = 1.5
	_tuning.second_finger_window_s = 0.15
	_tuning.pinch_distance = 0.08
	_tuning.nudge_distance = 0.08
	_tuning.nudge_full_drag = 0.4
	_recogniser = TouchRecogniser.new(_tuning)
	_recogniser.unit_px = UNIT_PX
	_recogniser.spin_swiped.connect(
		func() -> void:
			_heard.append([&"spin"]),
	)
	_recogniser.pinched_in.connect(
		func(at: Vector2) -> void:
			_heard.append([&"in", at]),
	)
	_recogniser.pinched_out.connect(
		func(at: Vector2) -> void:
			_heard.append([&"out", at]),
	)
	_recogniser.pinch_released.connect(
		func() -> void:
			_heard.append([&"released"]),
	)


## A quick one-finger swipe fires one Spin, however far it carries on.
func test_a_swipe_fires_one_spin() -> void:
	_recogniser.press(0, Vector2(100, 100), 0.0)
	_swipe(0, Vector2(100, 100), Vector2(300, 100), 0.0, 0.1)
	assert_array(_names()).contains_exactly([&"spin"])


## A slow drag, however far, is not a swipe.
func test_a_slow_drag_does_not_spin() -> void:
	_recogniser.press(0, Vector2(100, 100), 0.0)
	# 100 px a second is one screen length a second, under the swipe speed.
	_swipe(0, Vector2(100, 100), Vector2(300, 100), 0.0, 2.0)
	assert_array(_names()).is_empty()


## A finger that rests, then flicks, swipes from where it rested.
func test_a_rest_then_flick_spins() -> void:
	_recogniser.press(0, Vector2(100, 100), 0.0)
	_swipe(0, Vector2(100, 100), Vector2(110, 100), 0.0, 1.0)
	_swipe(0, Vector2(110, 100), Vector2(140, 100), 1.0, 0.05)
	assert_array(_names()).contains_exactly([&"spin"])


## Two fingers pinching in start Attract at their centre, at the moment they classify,
## not at lift, and lifting either finger ends it.
func test_a_pinch_in_attracts_at_the_centre_until_a_finger_lifts() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_pinch(Vector2(100, 200), Vector2(300, 200), 60.0)
	assert_array(_heard).contains_exactly([[&"in", Vector2(200, 200)]])
	_recogniser.release(1)
	assert_array(_names()).contains_exactly([&"in", &"released"])


## A pinch-out fires Repel once, at its centre, however far it carries on, and its lift
## releases nothing.
func test_a_pinch_out_repels_once() -> void:
	_two_fingers_down(Vector2(150, 200), Vector2(250, 200))
	_pinch(Vector2(150, 200), Vector2(250, 200), -80.0)
	_recogniser.release(0)
	_recogniser.release(1)
	assert_array(_names()).contains_exactly([&"out"])
	assert_vector(_heard[0][1]).is_equal_approx(
		Vector2(200, 200),
		Vector2.ONE * CENTRE_TOLERANCE_PX,
	)


## Two fingers dragged together Nudge in screen terms, y up, springing back on lift.
func test_a_two_finger_drag_nudges() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(200, 200))
	# 20 px right and 20 px up is half the full drag of 0.4 screen lengths each way.
	_drag_both(Vector2(20, -20))
	var nudge := _recogniser.nudge()
	_recogniser.release(0)

	assert_vector(nudge).is_equal_approx(Vector2(0.5, 0.5), Vector2.ONE * 1e-4)
	assert_vector(_recogniser.nudge()).is_equal(Vector2.ZERO)
	assert_array(_heard).is_empty()


## A Nudge is locked until lift: pinching afterwards does not Attract.
func test_a_nudge_stays_a_nudge() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_drag_both(Vector2(30, 0))
	_pinch(Vector2(130, 200), Vector2(330, 200), 60.0)
	assert_array(_heard).is_empty()


## A Nudge's length never passes 1.
func test_a_long_drag_is_a_full_nudge() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(200, 200))
	_drag_both(Vector2(0, 300))
	assert_vector(_recogniser.nudge()).is_equal_approx(Vector2(0, -1), Vector2.ONE * 1e-4)


## A second finger after the window is a swipe candidate of its own, and the first
## finger, resting, stays unclassified.
func test_a_late_second_finger_does_not_pair() -> void:
	_recogniser.press(0, Vector2(100, 200), 0.0)
	_recogniser.press(1, Vector2(300, 200), 0.5)
	_recogniser.drag(1, Vector2(240, 200), 0.55)
	assert_array(_names()).contains_exactly([&"spin"])


## A second finger inside the window cancels the first finger's swipe.
func test_a_paired_finger_does_not_swipe() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_recogniser.drag(0, Vector2(20, 200), 0.05)
	assert_array(_names()).not_contains([&"spin"])


## A third finger can Spin while a pinch-in holds Attract.
func test_a_third_finger_spins_during_attract() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_pinch(Vector2(100, 200), Vector2(300, 200), 60.0)
	_recogniser.press(2, Vector2(500, 500), 0.3)
	_swipe(2, Vector2(500, 500), Vector2(500, 300), 0.3, 0.1)
	assert_array(_names()).contains_exactly([&"in", &"spin"])


## After a pinch ends, the finger left down is ignored until it lifts: it neither
## swipes nor pairs with a new finger.
func test_the_finger_left_after_a_pinch_is_ignored() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_pinch(Vector2(100, 200), Vector2(300, 200), 60.0)
	_recogniser.release(1)
	_recogniser.press(2, Vector2(400, 400), 0.31)
	_recogniser.drag(0, Vector2(400, 200), 0.32)
	assert_array(_names()).contains_exactly([&"in", &"released"])
	assert_bool(_recogniser.is_aiming()).is_false()


## Two fingers resting with no threshold crossed stay unclassified, however long.
func test_resting_fingers_stay_unclassified() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_recogniser.drag(0, Vector2(102, 201), 30.0)
	_recogniser.drag(1, Vector2(299, 199), 60.0)
	assert_array(_heard).is_empty()
	assert_bool(_recogniser.is_aiming()).is_true()


## Two resting fingers aim at their midpoint, and a pinch keeps the centre it classified
## at however the fingers move afterwards. A Nudge doesn't aim.
func test_the_aim_point_follows_then_locks() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 220))
	var resting := _recogniser.aim_point()
	_pinch(Vector2(100, 200), Vector2(300, 220), 60.0)
	_recogniser.drag(0, Vector2(400, 400), 0.4)
	var locked := _recogniser.aim_point()

	assert_vector(resting).is_equal(Vector2(200, 210))
	assert_vector(locked).is_equal(Vector2(200, 210))


## Dropping mid-pinch emits nothing, and ignores every finger until it lifts, while the
## fingers still count as down.
func test_drop_ignores_every_finger_until_it_lifts() -> void:
	_two_fingers_down(Vector2(100, 200), Vector2(300, 200))
	_pinch(Vector2(100, 200), Vector2(300, 200), 60.0)
	_recogniser.drop()
	_recogniser.drag(0, Vector2(500, 200), 0.3)
	var down_after_drop := _recogniser.is_anything_down()
	_recogniser.release(0)
	_recogniser.release(1)

	assert_array(_names()).contains_exactly([&"in"])
	assert_bool(down_after_drop).is_true()
	assert_bool(_recogniser.is_anything_down()).is_false()
	assert_bool(_recogniser.is_aiming()).is_false()


func _names() -> Array[StringName]:
	var names: Array[StringName] = []
	for heard in _heard:
		names.append(heard[0])
	return names


# Drags finger [param index] in ten even steps from [param from] to [param to], from
# [param start_s] over [param duration_s].
func _swipe(index: int, from: Vector2, to: Vector2, start_s: float, duration_s: float) -> void:
	for step in range(1, 11):
		var weight := step / 10.0
		_recogniser.drag(index, from.lerp(to, weight), start_s + duration_s * weight)


# Puts fingers 0 and 1 down at once at [param a] and [param b].
func _two_fingers_down(a: Vector2, b: Vector2) -> void:
	_down_at = [a, b]
	_recogniser.press(0, a, 0.0)
	_recogniser.press(1, b, 0.01)


# Moves fingers 0 and 1, from [param a] and [param b], each [param inward_px] toward
# their centre (outward when negative), in ten steps over 0.1 s starting at 0.1 s.
func _pinch(a: Vector2, b: Vector2, inward_px: float) -> void:
	var a_to := a.move_toward(b, inward_px)
	var b_to := b.move_toward(a, inward_px)
	for step in range(1, 11):
		var weight := step / 10.0
		_recogniser.drag(0, a.lerp(a_to, weight), 0.1 + 0.1 * weight)
		_recogniser.drag(1, b.lerp(b_to, weight), 0.1 + 0.1 * weight)


# Drags fingers 0 and 1 together by [param by] pixels, in ten steps over 0.1 s from 0.1 s.
func _drag_both(by: Vector2) -> void:
	for step in range(1, 11):
		var weight := step / 10.0
		_recogniser.drag(0, _down_at[0] + by * weight, 0.1 + 0.1 * weight)
		_recogniser.drag(1, _down_at[1] + by * weight, 0.1 + 0.1 * weight)
