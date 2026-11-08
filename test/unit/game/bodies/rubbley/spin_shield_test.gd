extends GdUnitTestSuite
## Spin's deflection maths: the speed change that bounces a body off another across the
## Play Plane, sending back its closing speed relative to the one it bounces off.

const TOLERANCE := Vector3.ONE * 1e-4


## A body flying straight at a still one comes back out at the speed it came in.
func test_a_head_on_body_bounces_straight_back() -> void:
	var change := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(2, 0, 0),
		Vector3(-10, 0, 0),
		1.0,
	)
	assert_vector(change).is_equal_approx(Vector3(20, 0, 0), TOLERANCE)


## The bounce is relative to the body it comes off: closing at 15 m/s on one moving at
## 5 m/s, it leaves at 15 m/s relative to it, 20 m/s in the world.
func test_the_bounce_is_relative_to_the_body_it_comes_off() -> void:
	var change := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3(5, 0, 0),
		Vector3(2, 0, 0),
		Vector3(-10, 0, 0),
		1.0,
	)
	assert_vector(change).is_equal_approx(Vector3(30, 0, 0), TOLERANCE)


## Only the closing part of a glancing approach is sent back; the sideways part is kept.
func test_a_glancing_body_keeps_its_sideways_speed() -> void:
	var change := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(0, 0, 2),
		Vector3(4, 0, -10),
		1.0,
	)
	assert_vector(change).is_equal_approx(Vector3(0, 0, 20), TOLERANCE)


## Restitution scales what is sent back: at 0.5 a 10 m/s approach leaves at 5 m/s.
func test_restitution_scales_the_bounce() -> void:
	var change := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(2, 0, 0),
		Vector3(-10, 0, 0),
		0.5,
	)
	assert_vector(change).is_equal_approx(Vector3(15, 0, 0), TOLERANCE)


## A body moving away, or only past, isn't bounced, and neither is one at the same point.
func test_a_body_not_closing_isnt_bounced() -> void:
	var leaving := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(2, 0, 0),
		Vector3(10, 0, 0),
		1.0,
	)
	var passing := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(2, 0, 0),
		Vector3(0, 0, 10),
		1.0,
	)
	var same_point := SpinShield.bounce_change(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(-10, 0, 0),
		1.0,
	)
	assert_vector(leaving).is_equal(Vector3.ZERO)
	assert_vector(passing).is_equal(Vector3.ZERO)
	assert_vector(same_point).is_equal(Vector3.ZERO)


## Height off the Play Plane doesn't tilt the bounce.
func test_the_bounce_stays_on_the_play_plane() -> void:
	var change := SpinShield.bounce_change(
		Vector3(0, 1, 0),
		Vector3.ZERO,
		Vector3(2, 0, 0),
		Vector3(-10, 0, 0),
		1.0,
	)
	assert_vector(change).is_equal_approx(Vector3(20, 0, 0), TOLERANCE)
