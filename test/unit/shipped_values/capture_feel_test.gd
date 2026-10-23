extends SimulationTestSuite
## Capture feel scenario (ADRs 0017, 0018) on the shipped Rubbley, Anchored planet,
## Gravity Tuning and body Tunings: Rubbley released slowly inside a planet's Capture
## Radius, with Drift pushing him, settles into Orbit and stays there.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const PLANET_SCENE := preload("res://game/bodies/planet/anchored_planet.tscn")
const GRAVITY_TUNING := preload("res://game/gravity/gravity_tuning.tres")

## Seeds the four perturbed starts; change it only to reproduce a reported failure.
const SEED := 97
## ADR 0018's wall-time budget for the shipped-values suite on CI.
const SUITE_BUDGET_MS := 60_000
const DRIFT_DIRECTION := Vector3.RIGHT
## One canonical start plus four seeded perturbations (ADR 0018).
const VARIANT_COUNT := 5
## How often the Orbit predicate is fed. At 25 s a period, Rubbley moves under 2° between samples.
const SAMPLE_S := 0.1
# ADR 0018's bands, in orbital periods at the start. Three periods to settle leaves room for
# a start that breaks the radius band and restarts the 360° count; two more periods held
# shows the assist keeps him in Orbit against Drift, not that he passed through once.
const CAPTURE_PERIODS := 3.0
const HOLD_PERIODS := 2.0
# gdUnit4's test timeout counts game time, which --fixed-fps makes simulated time. Five
# variants of five periods (about 25 s each) need about 640 s; wall time stays a few seconds.
const TIMEOUT_MS := 1_200_000

var _suite_start_ms := 0


## Starts the suite's wall-time clock.
func before() -> void:
	_suite_start_ms = Time.get_ticks_msec()


## Logs the suite's wall time and fails it over budget.
func after() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _suite_start_ms
	print("Capture feel suite took %d ms (budget %d ms)" % [elapsed_ms, SUITE_BUDGET_MS])
	assert_int(elapsed_ms).is_less_equal(SUITE_BUDGET_MS)


## Over 5 starts at 0.8 × Capture Radius and about circular speed, Rubbley is in
## Orbit within 3 orbital periods and stays in Orbit for 2 more, and the Anchored
## planet never moves.
@warning_ignore("unused_parameter") # gdUnit4 reads the timeout parameter by name.
# gdlint-ignore-next-line unused-argument
func test_a_slow_body_is_captured_into_orbit(timeout := TIMEOUT_MS) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for variant in VARIANT_COUNT:
		var start := _canonical_start() if variant == 0 else _perturbed_start(rng)
		var world := Node3D.new()
		add_child(world)
		var planet := _add_planet(world)
		var rubbley := _add_drifting_rubbley(world, planet, start)
		var orbit := Orbit.new(GRAVITY_TUNING, planet.tuning.capture_radius_m)
		var period_s := _period_s(planet, start)
		var label := "variant %d (seed %d, start %s)" % [variant, SEED, start]

		var captured_after_s := await _seconds_until_orbit(
			orbit,
			rubbley,
			planet,
			period_s * CAPTURE_PERIODS,
		)
		(
			assert_float(captured_after_s)
			.override_failure_message("%s: not in Orbit within %.0f s"
			% [label, period_s * CAPTURE_PERIODS])
			.is_greater_equal(0.0)
		)
		if captured_after_s >= 0.0:
			var left_after_s := await _seconds_until_out_of_orbit(
				orbit,
				rubbley,
				planet,
				period_s * HOLD_PERIODS,
			)
			(
				assert_float(left_after_s)
				.override_failure_message("%s: in Orbit after %.1f s, out of it %.1f s later"
				% [label, captured_after_s, left_after_s])
				.is_less(0.0)
			)
		(
			assert_vector(planet.global_position)
			.override_failure_message("%s: the Anchored planet moved" % label)
			.is_equal(Vector3.ZERO)
		)
		world.free()


# Rubbley starts at 0.8 × the planet's Capture Radius, heading along his circle at
# circular speed (ADR 0018).
func _canonical_start() -> Start:
	return Start.new(1.0, 0.0, 0.8)


# ±5% speed, ±5° angle and ±5% distance around the canonical start (ADR 0018).
func _perturbed_start(rng: RandomNumberGenerator) -> Start:
	var canonical := _canonical_start()
	return Start.new(
		canonical.speed_share * rng.randf_range(0.95, 1.05),
		canonical.angle_deg + rng.randf_range(-5.0, 5.0),
		canonical.radius_share * rng.randf_range(0.95, 1.05),
	)


func _add_planet(world: Node3D) -> PlayPlaneBody:
	var planet := PLANET_SCENE.instantiate() as PlayPlaneBody
	world.add_child(planet)
	return planet


func _add_drifting_rubbley(world: Node3D, planet: PlayPlaneBody, start: Start) -> PlayPlaneBody:
	var rubbley := RUBBLEY_SCENE.instantiate() as PlayPlaneBody
	var distance_m := planet.tuning.capture_radius_m * start.radius_share
	# Anticlockwise from above: at +X, the way round is −Z.
	var tangent := Vector3.FORWARD
	var heading := tangent.rotated(Vector3.UP, deg_to_rad(start.angle_deg))
	rubbley.position = Vector3.RIGHT * distance_m
	rubbley.linear_velocity = heading * _circular_speed(planet, distance_m) * start.speed_share

	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GRAVITY_TUNING
	gravity_system.drift_direction = DRIFT_DIRECTION
	world.add_child(rubbley)
	gravity_system.drift_body = rubbley.get_node("GravityBody") as GravityBody
	world.add_child(gravity_system)
	return rubbley


# An Anchored Body's Area point gravity is G × M / d², so circular speed is √(G × M / d).
func _circular_speed(planet: PlayPlaneBody, distance_m: float) -> float:
	return sqrt(GRAVITY_TUNING.gravitational_constant * planet.mass / distance_m)


# The period of a circular Orbit at the start's distance.
func _period_s(planet: PlayPlaneBody, start: Start) -> float:
	var distance_m := planet.tuning.capture_radius_m * start.radius_share
	return TAU * distance_m / _circular_speed(planet, distance_m)


# Steps until the Orbit predicate holds, up to the limit. Returns the seconds taken, or -1.
func _seconds_until_orbit(orbit: Orbit, rubbley: Node3D, planet: Node3D, limit_s: float) -> float:
	var elapsed_s := 0.0
	while elapsed_s < limit_s:
		await step_seconds(SAMPLE_S)
		elapsed_s += SAMPLE_S
		orbit.track(rubbley.global_position - planet.global_position)
		if orbit.is_in_orbit():
			return elapsed_s
	return -1.0


# Steps for the given time while the Orbit predicate holds. Returns the seconds until
# it first failed, or -1 if it held throughout.
func _seconds_until_out_of_orbit(
	orbit: Orbit,
	rubbley: Node3D,
	planet: Node3D,
	duration_s: float,
) -> float:
	var elapsed_s := 0.0
	while elapsed_s < duration_s:
		await step_seconds(SAMPLE_S)
		elapsed_s += SAMPLE_S
		orbit.track(rubbley.global_position - planet.global_position)
		if not orbit.is_in_orbit():
			return elapsed_s
	return -1.0


## One start condition for a variant.
class Start:
	## Rubbley's starting speed, as a share of circular speed at his starting distance.
	var speed_share: float
	## How far his starting heading turns from the way round, in degrees.
	var angle_deg: float
	## His starting distance from the planet, as a share of its Capture Radius.
	var radius_share: float


	func _init(start_speed_share: float, start_angle_deg: float, start_radius_share: float) -> void:
		speed_share = start_speed_share
		angle_deg = start_angle_deg
		radius_share = start_radius_share


	func _to_string() -> String:
		return "(speed %.3f, angle %.2f°, radius %.3f)" % [speed_share, angle_deg, radius_share]
