extends GdUnitTestSuite

const CELESTIAL := GravityBody.Role.CELESTIAL
const PASSIVE := GravityBody.Role.PASSIVE
const ANCHORED := GravityBody.Role.ANCHORED
## A 100 kg primary at the origin pulls a body 8 m out with 2 × 100 / 8² = 3.125 m/s²,
## so its circular speed is √(3.125 × 8) = 5 m/s.
const BODY_AT := Vector3(8, 0, 0)
## Circling anticlockwise seen from above, at circular speed.
const CIRCULAR := Vector3(0, 0, -5)

var _tuning: GravityTuning


## Builds Gravity Tuning with no softening, a round assist rate and speed share.
func before_test() -> void:
	_tuning = GravityTuning.new()
	_tuning.gravitational_constant = 2.0
	_tuning.softening_m = 0.0
	_tuning.capture_assist_rate_per_second = 2.0
	_tuning.capture_speed_multiple = 1.3


## A body already in a circular Orbit needs no help.
func test_a_circular_orbit_gets_no_force() -> void:
	var forces := _assist(_pair(CIRCULAR))
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)


## A body slower than circular speed is pushed along its way round:
## mass × rate × (target − velocity) = 2 × 2 × (0, 0, −1).
func test_a_slow_body_is_sped_up_to_circular_speed() -> void:
	var forces := _assist(_pair(Vector3(0, 0, -4)))
	assert_vector(forces[1]).is_equal_approx(Vector3(0, 0, -4), Vector3.ONE * 1e-5)


## Falling outward is pushed back, so the path rounds into a circle.
func test_radial_speed_is_pushed_back() -> void:
	var forces := _assist(_pair(Vector3(1, 0, -5)))
	assert_vector(forces[1]).is_equal_approx(Vector3(-4, 0, 0), Vector3.ONE * 1e-5)


## A body circling clockwise is helped clockwise, never turned round.
func test_keeps_the_way_the_body_is_going_round() -> void:
	var forces := _assist(_pair(Vector3(0, 0, 4)))
	assert_vector(forces[1]).is_equal_approx(Vector3(0, 0, 4), Vector3.ONE * 1e-5)


## A body faster than the speed share (1.3 × 5 m/s) is passing through, not captured.
func test_a_fast_body_gets_no_force() -> void:
	var forces := _assist(_pair(Vector3(0, 0, -6.6)))
	assert_vector(forces[1]).is_equal(Vector3.ZERO)


## A body just under the speed share is still helped.
func test_a_body_just_under_the_speed_share_is_helped() -> void:
	var forces := _assist(_pair(Vector3(0, 0, -6.4)))
	assert_vector(forces[1]).is_equal_approx(Vector3(0, 0, 5.6), Vector3.ONE * 1e-5)


## Outside the primary's Capture Radius, nothing helps the body.
func test_outside_the_capture_radius_gets_no_force() -> void:
	var bodies := _pair(Vector3(0, 0, -4))
	bodies.capture_radii[0] = 7.9
	assert_vector(_assist(bodies)[1]).is_equal(Vector3.ZERO)


## Only a heavier body captures: a primary lighter than the body helps nothing.
func test_a_lighter_primary_captures_nothing() -> void:
	var bodies := _pair(Vector3(0, 0, -4))
	bodies.masses[1] = 150.0
	assert_vector(_assist(bodies)[1]).is_equal(Vector3.ZERO)


## A body that can't be captured is left alone.
func test_a_body_that_cant_be_captured_gets_no_force() -> void:
	var bodies := _pair(Vector3(0, 0, -4))
	bodies.capturable[1] = false
	assert_vector(_assist(bodies)[1]).is_equal(Vector3.ZERO)


## A Passive Body pulls nothing, so it can't be a primary.
func test_a_passive_body_is_never_a_primary() -> void:
	var bodies := _pair(Vector3(0, 0, -4))
	bodies.roles[0] = PASSIVE
	assert_vector(_assist(bodies)[1]).is_equal(Vector3.ZERO)


## The body's own damping would slow a circular Orbit, so the assist pays it back:
## mass × damping × velocity = 2 × 0.5 × (0, 0, −5).
func test_pays_back_the_bodys_damping() -> void:
	var bodies := _pair(CIRCULAR)
	bodies.linear_damps[1] = 0.5
	assert_vector(_assist(bodies)[1]).is_equal_approx(Vector3(0, 0, -5), Vector3.ONE * 1e-5)


## Orbit is relative to the primary: a moving primary carries the circle with it.
func test_circles_a_moving_primary() -> void:
	var bodies := _pair(CIRCULAR + Vector3(3, 0, 0))
	bodies.velocities[0] = Vector3(3, 0, 0)
	assert_vector(_assist(bodies)[1]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)


## Gravega multipliers strengthen the pull, so circular speed rises with them:
## 4 × 3.125 m/s² at 8 m gives 10 m/s.
func test_circular_speed_follows_the_gravega_multipliers() -> void:
	var bodies := _pair(Vector3(0, 0, -10))
	bodies.multipliers[0] = 2.0
	bodies.multipliers[1] = 2.0
	assert_vector(_assist(bodies)[1]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)


## An Anchored Body's Area point gravity isn't softened, so neither is its circular speed.
func test_an_anchored_primary_is_not_softened() -> void:
	_tuning.softening_m = 4.0
	var bodies := _pair(CIRCULAR)
	bodies.roles[0] = ANCHORED
	assert_vector(_assist(bodies)[1]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)


## A Celestial primary's pull is softened, so its circular speed is too:
## 2 × 100 × 8 / (8² + 6²)^1.5 = 1.6 m/s², giving √(1.6 × 8) ≈ 3.5777 m/s.
func test_a_celestial_primary_is_softened() -> void:
	_tuning.softening_m = 6.0
	var bodies := _pair(Vector3(0, 0, -3.577709))
	assert_vector(_assist(bodies)[1]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-4)


## With two primaries in range, the body circles the nearer one.
func test_circles_the_nearest_primary() -> void:
	var bodies := _pair(CIRCULAR)
	# A second primary 9 m from the body, also in range. Its circular speed there is
	# √(2 × 100 / 9) ≈ 4.714 m/s, so picking it would push the body.
	bodies.add(Vector3(-1, 0, 0), Vector3.ZERO, 100.0, CELESTIAL, 10.0, false)
	assert_vector(_assist(bodies)[1]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)


# A 100 kg Celestial primary at rest at the origin with a 10 m Capture Radius, and a
# capturable 2 kg body at BODY_AT with the given velocity.
func _pair(velocity: Vector3) -> Bodies:
	var bodies := Bodies.new()
	bodies.add(Vector3.ZERO, Vector3.ZERO, 100.0, CELESTIAL, 10.0, false)
	bodies.add(BODY_AT, velocity, 2.0, CELESTIAL, 0.0, true)
	return bodies


func _assist(bodies: Bodies) -> PackedVector3Array:
	return CaptureAssist.new(_tuning).forces(
		bodies.positions,
		bodies.velocities,
		bodies.masses,
		bodies.roles,
		bodies.multipliers,
		bodies.linear_damps,
		bodies.capture_radii,
		bodies.capturable,
	)


## The capture assist's inputs, one entry per body.
class Bodies:
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var masses := PackedFloat64Array()
	var roles := PackedInt32Array()
	var multipliers := PackedFloat64Array()
	var linear_damps := PackedFloat64Array()
	var capture_radii := PackedFloat64Array()
	var capturable: Array[bool] = []


	## Adds one body with a Gravega multiplier of 1 and no damping.
	func add(
		position: Vector3,
		velocity: Vector3,
		mass: float,
		role: GravityBody.Role,
		capture_radius_m: float,
		can_be_captured: bool,
	) -> void:
		positions.append(position)
		velocities.append(velocity)
		masses.append(mass)
		roles.append(role)
		multipliers.append(1.0)
		linear_damps.append(0.0)
		capture_radii.append(capture_radius_m)
		capturable.append(can_be_captured)
