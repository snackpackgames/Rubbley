extends GdUnitTestSuite
## The controller's aim cursor (ADR 0012): Rubbley + stick × range, a stick at rest
## aiming at Rubbley, edge snap, full-tilt reach, R1/RB cycling, keeping a pick, and
## release grace. Rubbley sits at the origin and half the screen's short side is 10 m, so
## the range is 9 m, the snap radius 1.67 m and the reach 18 m.

const UNIT_M := 10.0
const RUBBLEY_AT := Vector2.ZERO
const SNAP_M := 1.67
## Stick travel that tilts the stick halfway between the deadzone and saturation.
const HALF_TILT := 0.575

var _aim: ControllerAim
var _now_s := 0.0


## Builds an aim on the ADR 0012 starting values, set here so a retune doesn't break the
## tests.
func before_test() -> void:
	var tuning := InputTuning.new()
	tuning.stick_deadzone = 0.2
	tuning.aim_range = 0.9
	tuning.aim_snap_radius = 0.167
	tuning.stick_saturation = 0.95
	tuning.full_tilt = 0.95
	tuning.reach_cone_deg = 12.0
	tuning.reach_range_multiple = 2.0
	tuning.reach_hysteresis_deg = 10.0
	tuning.reach_distance_bias_deg = 5.0
	tuning.aim_release_grace_s = 0.12
	_aim = ControllerAim.new(tuning)
	_now_s = 0.0


## A stick at rest, inside the deadzone, aims at Rubbley.
func test_a_stick_at_rest_aims_at_rubbley() -> void:
	_update(Vector2(0.1, 0.1), [])
	assert_vector(_aim.point()).is_equal(RUBBLEY_AT)
	assert_bool(_aim.is_on_rubbley()).is_true()
	assert_bool(_aim.is_tilted()).is_false()


## The cursor sits at Rubbley + stick × range, tilt measured from the deadzone to
## saturation.
func test_the_cursor_sits_at_stick_times_range() -> void:
	_update(Vector2(HALF_TILT, 0.0), [])
	assert_vector(_aim.point()).is_equal_approx(Vector2(4.5, 0.0), Vector2(0.01, 0.01))
	assert_bool(_aim.is_tilted()).is_true()
	assert_bool(_aim.is_on_rubbley()).is_false()


## The stick is in screen terms with y down, which is +y on the Play Plane, and full tilt
## puts the cursor at the full range.
func test_full_tilt_down_reaches_the_range_down() -> void:
	_update(Vector2(0.0, 1.0), [])
	assert_vector(_aim.point()).is_equal_approx(Vector2(0.0, 9.0), Vector2(0.01, 0.01))


## A glowing body whose edge is within the snap radius of the cursor is picked, and the
## aim moves to its centre.
func test_a_body_near_the_cursor_snaps_the_aim() -> void:
	var body := _body(7, Vector2(6.0, 0.0), 1.0)
	_update(Vector2(HALF_TILT, 0.0), [body])
	assert_int(_aim.picked()).is_equal(7)
	assert_vector(_aim.point()).is_equal(Vector2(6.0, 0.0))


## Of two bodies in snap range, the nearer edge wins, however big the other is.
func test_the_nearest_edge_snaps_first() -> void:
	var big := _body(1, Vector2(4.5, 3.0), 2.5)
	var small := _body(2, Vector2(4.5, -0.6), 0.5)
	_update(Vector2(HALF_TILT, 0.0), [big, small])
	assert_int(_aim.picked()).is_equal(2)


## Nothing within the snap radius leaves the aim on the cursor.
func test_a_body_out_of_snap_range_is_not_picked() -> void:
	_update(Vector2(HALF_TILT, 0.0), [_body(1, Vector2(4.5, 3.0), 1.0)])
	assert_int(_aim.picked()).is_equal(ControllerAim.NO_PICK)
	assert_vector(_aim.point()).is_equal_approx(Vector2(4.5, 0.0), Vector2(0.01, 0.01))


## At full tilt with nothing to snap to, the cone picks a body in the stick's direction
## out past the range.
func test_full_tilt_reaches_a_distant_body() -> void:
	var far := _body(3, Vector2(15.0, 1.0), 1.0)
	_update(Vector2(1.0, 0.0), [far])
	assert_int(_aim.picked()).is_equal(3)
	assert_vector(_aim.point()).is_equal(Vector2(15.0, 1.0))


## Short of full tilt, the cone doesn't reach: 0.9 travel is 93% tilt.
func test_short_of_full_tilt_does_not_reach() -> void:
	_update(Vector2(0.9, 0.0), [_body(3, Vector2(15.0, 1.0), 1.0)])
	assert_int(_aim.picked()).is_equal(ControllerAim.NO_PICK)


## Full tilt is a share of the tilt, as in the prototype, not of raw travel: 0.92 travel
## is 96% tilt, so the cone reaches.
func test_full_tilt_is_measured_on_the_tilt() -> void:
	_update(Vector2(0.92, 0.0), [_body(3, Vector2(15.0, 1.0), 1.0)])
	assert_int(_aim.picked()).is_equal(3)


## The cone measures to a body's edge: a big body off to the side is in the cone when
## its edge is.
func test_the_cone_measures_to_the_edge() -> void:
	var planet := _body(4, Vector2(16.0, 6.0), 5.0)
	_update(Vector2(1.0, 0.0), [planet])
	assert_int(_aim.picked()).is_equal(4)


## A picked body stays picked while its edge stays within 1.5× the snap radius of the
## cursor, even when another body is now nearer.
func test_a_pick_holds_while_its_body_stays_near() -> void:
	var first := _body(1, Vector2(4.5, 1.8), 0.5)
	var second := _body(2, Vector2(4.5, -1.8), 0.5)
	_update(Vector2(0.575, 0.08), [first, second])
	var picked_first := _aim.picked()
	# The cursor moves to just below the middle, nearer the second body.
	_update(Vector2(0.575, -0.02), [first, second])

	assert_int(picked_first).is_equal(1)
	assert_int(_aim.picked()).is_equal(1)


## A pick lets go once its body is past 1.5× the snap radius.
func test_a_pick_lets_go_past_the_keep_radius() -> void:
	var body := _body(1, Vector2(4.5, 1.8), 0.5)
	_update(Vector2(HALF_TILT, 0.08), [body])
	_update(Vector2(HALF_TILT, -0.3), [body])
	assert_int(_aim.picked()).is_equal(ControllerAim.NO_PICK)


## A body the cone picked stays picked while it stays inside the cone plus the
## hysteresis margin.
func test_a_reach_pick_holds_inside_the_hysteresis() -> void:
	var far := _body(3, Vector2(15.0, 0.0), 1.0)
	_update(Vector2(1.0, 0.0), [far])
	# 12° off: outside the 6° half-cone, inside it plus 10°.
	_update(Vector2.from_angle(deg_to_rad(12.0)), [far])
	assert_int(_aim.picked()).is_equal(3)


## R1/RB steps through the bodies selectable right now, best first, and wraps.
func test_cycling_steps_through_selectable_bodies_and_wraps() -> void:
	var nearest := _body(1, Vector2(4.5, 0.6), 0.5)
	var middle := _body(2, Vector2(4.5, -1.0), 0.5)
	var furthest := _body(3, Vector2(5.5, 1.4), 0.5)
	var bodies: Array[ControllerAim.Body] = [furthest, nearest, middle]
	_update(Vector2(HALF_TILT, 0.0), bodies)
	var picks: Array[int] = [_aim.picked()]
	for _press in 3:
		_aim.cycle()
		picks.append(_aim.picked())
		_update(Vector2(HALF_TILT, 0.0), bodies)

	assert_array(picks).contains_exactly([1, 2, 3, 1])


## A cycled pick holds on the next tick, though another body is nearer the cursor.
func test_a_cycled_pick_holds() -> void:
	var nearest := _body(1, Vector2(4.5, 0.6), 0.5)
	var other := _body(2, Vector2(4.5, -1.0), 0.5)
	_update(Vector2(HALF_TILT, 0.0), [nearest, other])
	_aim.cycle()
	_update(Vector2(HALF_TILT, 0.0), [nearest, other])
	assert_int(_aim.picked()).is_equal(2)
	assert_vector(_aim.point()).is_equal(Vector2(4.5, -1.0))


## With nothing selectable, cycling does nothing.
func test_cycling_with_nothing_selectable_does_nothing() -> void:
	_update(Vector2(HALF_TILT, 0.0), [])
	_aim.cycle()
	assert_int(_aim.picked()).is_equal(ControllerAim.NO_PICK)


## A body that goes during the release grace can't be cycled to.
func test_cycling_in_the_grace_skips_a_body_that_went() -> void:
	var stays := _body(1, Vector2(4.5, 0.6), 0.5)
	var goes := _body(2, Vector2(4.5, -1.0), 0.5)
	_update(Vector2(HALF_TILT, 0.0), [stays, goes])
	_update(Vector2.ZERO, [stays])
	_aim.cycle()
	assert_int(_aim.picked()).is_equal(1)
	assert_vector(_aim.point()).is_equal(Vector2(4.5, 0.6))


## For the release grace after the stick returns to rest, the last aim holds; after it,
## the aim is on Rubbley.
func test_the_release_grace_keeps_the_last_aim() -> void:
	_update(Vector2(HALF_TILT, 0.0), [])
	_now_s += 0.1
	_update(Vector2.ZERO, [])
	var in_grace := _aim.point()
	var on_rubbley_in_grace := _aim.is_on_rubbley()
	_now_s += 0.05
	_update(Vector2.ZERO, [])

	assert_vector(in_grace).is_equal_approx(Vector2(4.5, 0.0), Vector2(0.01, 0.01))
	assert_bool(on_rubbley_in_grace).is_false()
	assert_vector(_aim.point()).is_equal(RUBBLEY_AT)
	assert_bool(_aim.is_on_rubbley()).is_true()


## Through the release grace, a picked body stays picked and the aim follows it.
func test_the_release_grace_follows_a_picked_body() -> void:
	_update(Vector2(HALF_TILT, 0.0), [_body(7, Vector2(6.0, 0.0), 1.0)])
	_now_s += 0.05
	_update(Vector2.ZERO, [_body(7, Vector2(6.5, 0.5), 1.0)])
	assert_int(_aim.picked()).is_equal(7)
	assert_vector(_aim.point()).is_equal(Vector2(6.5, 0.5))


## A picked body that leaves the game drops the pick.
func test_a_pick_drops_when_its_body_goes() -> void:
	_update(Vector2(HALF_TILT, 0.0), [_body(7, Vector2(6.0, 0.0), 1.0)])
	_update(Vector2(HALF_TILT, 0.0), [])
	assert_int(_aim.picked()).is_equal(ControllerAim.NO_PICK)


func _update(stick: Vector2, bodies: Array[ControllerAim.Body]) -> void:
	_aim.update(stick, RUBBLEY_AT, UNIT_M, bodies, _now_s)
	_now_s += 1.0 / 60.0


func _body(id: int, at: Vector2, radius_m: float) -> ControllerAim.Body:
	return ControllerAim.Body.new(id, at, radius_m)
