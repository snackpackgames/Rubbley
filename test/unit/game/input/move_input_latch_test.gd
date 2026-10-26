extends GdUnitTestSuite
## The edges Move Input latches between physics ticks (ADR 0013).

const AIM := Vector3(3, 0, -4)

var _latch: MoveInputLatch


## Builds a fresh latch with nothing held.
func before_test() -> void:
	_latch = MoveInputLatch.new()


## A press shows as pressed on the next tick, then held until it is released.
func test_a_held_attract_is_pressed_then_held_then_released() -> void:
	_latch.press_attract()
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.PRESSED)
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.HELD)
	_latch.release_attract()
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.RELEASED)
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.IDLE)


## A press and release inside one tick is pressed on that tick and released on the next.
func test_a_tap_inside_one_tick_lasts_a_tick() -> void:
	_latch.press_attract()
	_latch.release_attract()
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.PRESSED)
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.RELEASED)
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.IDLE)


## Releasing and pressing again inside one tick releases now and presses on the next tick.
func test_a_re_press_inside_one_tick_starts_a_new_attract() -> void:
	_latch.press_attract()
	_tick()
	_latch.release_attract()
	_latch.press_attract()
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.RELEASED)
	assert_int(_tick().attract).is_equal(MoveInputFrame.Attract.PRESSED)


## Several Repel or Spin presses within one tick fire once, on that tick only.
func test_one_shots_fire_once_per_tick() -> void:
	_latch.fire_repel()
	_latch.fire_repel()
	_latch.fire_spin()
	var frame := _tick()
	assert_bool(frame.repel_fired).is_true()
	assert_bool(frame.spin_fired).is_true()
	frame = _tick()
	assert_bool(frame.repel_fired).is_false()
	assert_bool(frame.spin_fired).is_false()


## The frame carries the aim and the Nudge it was given.
func test_the_frame_carries_aim_and_nudge() -> void:
	var frame := _latch.tick(AIM, Vector2(0.6, 0.8), true)
	assert_vector(frame.aim).is_equal(AIM)
	assert_vector(frame.nudge).is_equal(Vector2(0.6, 0.8))


## An interruption releases a held Attract, drops pending one-shots and zeroes Nudge.
func test_an_interruption_releases_everything() -> void:
	_latch.press_attract()
	_tick()
	_latch.fire_repel()
	_latch.interrupt()
	var frame := _latch.tick(AIM, Vector2.UP, true)
	assert_int(frame.attract).is_equal(MoveInputFrame.Attract.RELEASED)
	assert_bool(frame.repel_fired).is_false()
	assert_vector(frame.nudge).is_equal(Vector2.ZERO)


## After an interruption input is swallowed until nothing is held, then counts again.
func test_input_is_swallowed_until_everything_is_released() -> void:
	_latch.interrupt()
	_latch.press_attract()
	_latch.fire_spin()
	var frame := _latch.tick(AIM, Vector2.UP, true)
	assert_int(frame.attract).is_equal(MoveInputFrame.Attract.IDLE)
	assert_bool(frame.spin_fired).is_false()
	assert_vector(frame.nudge).is_equal(Vector2.ZERO)

	_latch.release_attract()
	_latch.tick(AIM, Vector2.ZERO, false)
	_latch.press_attract()
	frame = _latch.tick(AIM, Vector2.UP, true)
	assert_int(frame.attract).is_equal(MoveInputFrame.Attract.PRESSED)
	assert_vector(frame.nudge).is_equal(Vector2.UP)


func _tick() -> MoveInputFrame:
	return _latch.tick(AIM, Vector2.ZERO, true)
