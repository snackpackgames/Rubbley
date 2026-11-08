extends SimulationTestSuite
## Repel Pulse breaks Orbit feel scenario (ADRs 0017, 0018) on the shipped Rubbley, debris,
## Anchored planet, Stats and Tunings: debris in an established Orbit round a planet is
## knocked out of it by a Repel Pulse fired beside it, and flung clear.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
const PLANET_SCENE := preload("res://game/bodies/planet/anchored_planet.tscn")
const GRAVITY_TUNING := preload("res://game/gravity/gravity_tuning.tres")

## Seeds the four perturbed starts; change it only to reproduce a reported failure.
const SEED := 41
## ADR 0018's wall-time budget for the shipped-values suite on CI.
const SUITE_BUDGET_MS := 60_000
## One canonical start plus four seeded perturbations (ADR 0018).
const VARIANT_COUNT := 5
## How often the Orbit predicate is fed. At about 6 s a period, debris moves about 6°.
const SAMPLE_S := 0.1
# Debris starts at 0.6 × the Capture Radius, 12 m round the shipped planet, so one period
# is about 6 s.
const RADIUS_SHARE := 0.6
# ADR 0018 allows 10 simulated seconds a variant; what the clear time leaves goes to
# establishing Orbit: about 1.4 periods, one for the 360° and slack for a perturbed start.
const ESTABLISH_S := 10.0 - 2.0
# Where Rubbley waits while the debris settles: far beyond the max range, so he pulls
# nothing, and nothing pulls him.
const PARKED_AT := Vector3(500, 0, 0)
# How far behind the debris along its path Rubbley fires the Pulse. Well inside the Pulse's
# reach, and clear of the debris and the planet.
const FIRE_BEHIND_M := 3.0
# ADR 0018's bands. Out of Orbit within 0.5 s: a Pulse that leaves debris in Orbit any
# longer only nudged it, and the player sees nothing happen.
const BREAK_S := 0.5
# Beyond 1.5 × the Capture Radius within 2 s, and not back in Orbit meanwhile: past 1.25 ×
# Orbit ends, and the extra quarter shows the debris was flung clear, not swung wide.
const CLEAR_S := 2.0
const CLEAR_RADIUS_MULTIPLE := 1.5

var _suite_start_ms := 0


## Starts the suite's wall-time clock.
func before() -> void:
	_suite_start_ms = Time.get_ticks_msec()


## Logs the suite's wall time and fails it over budget.
func after() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _suite_start_ms
	print("Repel Pulse feel suite took %d ms (budget %d ms)" % [elapsed_ms, SUITE_BUDGET_MS])
	assert_int(elapsed_ms).is_less_equal(SUITE_BUDGET_MS)


## Over 5 starts, debris in Orbit round a planet is out of Orbit within 0.5 s of a Repel
## Pulse fired beside it, beyond 1.5 × the Capture Radius within 2 s, and never back in Orbit.
func test_a_repel_pulse_breaks_orbit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for variant in VARIANT_COUNT:
		var start := Start.new(1.0, 0.0, RADIUS_SHARE) if variant == 0 else _perturbed(rng)
		var label := "variant %d (seed %d, start %s)" % [variant, SEED, start]
		var world := Node3D.new()
		add_child(world)
		var planet := _add(world, PLANET_SCENE, Vector3.ZERO)
		var debris := _add_orbiting_debris(world, planet, start)
		var rubbley := _add(world, RUBBLEY_SCENE, PARKED_AT)
		var frame := MoveInputFrame.new()
		(rubbley.get_node("Moves") as RubbleyMoves).injected_frame = frame
		var gravity_system := GravitySystem.new()
		gravity_system.tuning = GRAVITY_TUNING
		world.add_child(gravity_system)
		var capture_radius_m := planet.tuning.capture_radius_m
		var orbit := Orbit.new(GRAVITY_TUNING, capture_radius_m)

		var established := await _orbit_established(orbit, debris)
		(
			assert_bool(established)
			.override_failure_message("%s: the debris never settled into Orbit" % label)
			.is_true()
		)
		if established:
			await _fire_pulse_behind(rubbley, debris, frame)
			var outcome := await _after_pulse(orbit, debris, capture_radius_m)
			(
				assert_float(outcome.out_of_orbit_after_s)
				.override_failure_message("%s: still in Orbit %.1f s after the Pulse"
				% [label, BREAK_S])
				.is_between(0.0, BREAK_S)
			)
			(
				assert_float(outcome.clear_after_s)
				.override_failure_message("%s: not beyond %.1f × the Capture Radius in %.1f s"
				% [label, CLEAR_RADIUS_MULTIPLE, CLEAR_S])
				.is_between(0.0, CLEAR_S)
			)
			(
				assert_bool(outcome.back_in_orbit)
				.override_failure_message("%s: back in Orbit after the Pulse" % label)
				.is_false()
			)
		world.free()


# ±5% speed, ±5° angle and ±5% distance round the canonical start (ADR 0018).
func _perturbed(rng: RandomNumberGenerator) -> Start:
	return Start.new(
		rng.randf_range(0.95, 1.05),
		rng.randf_range(-5.0, 5.0),
		RADIUS_SHARE * rng.randf_range(0.95, 1.05),
	)


func _add(world: Node3D, scene: PackedScene, at: Vector3) -> PlayPlaneBody:
	var body := scene.instantiate() as PlayPlaneBody
	body.position = at
	world.add_child(body)
	return body


# Debris launched anticlockwise into Orbit round the planet from the start's distance.
func _add_orbiting_debris(world: Node3D, planet: PlayPlaneBody, start: Start) -> PlayPlaneBody:
	var offset := Vector3.RIGHT * planet.tuning.capture_radius_m * start.radius_share
	var debris := _add(world, DEBRIS_SCENE, planet.global_position + offset)
	var launch := OrbitLaunch.velocity(offset, _pull_strength(planet), start.speed_share, true)
	debris.linear_velocity = launch.rotated(Vector3.UP, deg_to_rad(start.angle_deg))
	return debris


# An Anchored Body's Area point gravity is G × M / d².
func _pull_strength(planet: PlayPlaneBody) -> float:
	return GRAVITY_TUNING.gravitational_constant * planet.mass


# Steps until the debris is in Orbit, for up to the establishing time.
func _orbit_established(orbit: Orbit, debris: Node3D) -> bool:
	var elapsed_s := 0.0
	while elapsed_s < ESTABLISH_S:
		await step_seconds(SAMPLE_S)
		elapsed_s += SAMPLE_S
		orbit.track(debris.global_position)
		if orbit.is_in_orbit():
			return true
	return false


# Moves Rubbley, at rest, to just behind the debris along its path, and fires a Repel
# Pulse on him that tick.
func _fire_pulse_behind(
	rubbley: PlayPlaneBody,
	debris: PlayPlaneBody,
	frame: MoveInputFrame,
) -> void:
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await get_tree().physics_frame
	var behind := debris.global_position - debris.linear_velocity.normalized() * FIRE_BEHIND_M
	rubbley.global_position = behind
	rubbley.linear_velocity = Vector3.ZERO
	frame.aim = behind
	frame.repel_fired = true
	await step_seconds(tick_s)
	frame.repel_fired = false


# Watches the debris for the clear time after the Pulse. The planet is at the origin.
func _after_pulse(orbit: Orbit, debris: Node3D, capture_radius_m: float) -> Outcome:
	var outcome := Outcome.new()
	var elapsed_s := 0.0
	while elapsed_s < CLEAR_S:
		await step_seconds(SAMPLE_S)
		elapsed_s += SAMPLE_S
		orbit.track(debris.global_position)
		var in_orbit := orbit.is_in_orbit()
		if not in_orbit and outcome.out_of_orbit_after_s < 0.0:
			outcome.out_of_orbit_after_s = elapsed_s
		if in_orbit and outcome.out_of_orbit_after_s >= 0.0:
			outcome.back_in_orbit = true
		var distance_m := Vector2(debris.global_position.x, debris.global_position.z).length()
		var clear := distance_m > capture_radius_m * CLEAR_RADIUS_MULTIPLE
		if clear and outcome.clear_after_s < 0.0:
			outcome.clear_after_s = elapsed_s
	return outcome


## One start condition for a variant.
class Start:
	## The debris's starting speed, as a share of circular speed at its starting distance.
	var speed_share: float
	## How far its starting heading turns from the way round, in degrees.
	var angle_deg: float
	## Its starting distance from the planet, as a share of the Capture Radius.
	var radius_share: float


	func _init(start_speed_share: float, start_angle_deg: float, start_radius_share: float) -> void:
		speed_share = start_speed_share
		angle_deg = start_angle_deg
		radius_share = start_radius_share


	func _to_string() -> String:
		return "(speed %.3f, angle %.2f°, radius %.3f)" % [speed_share, angle_deg, radius_share]


## What happened to the debris after the Pulse. A time of -1 means it never happened.
class Outcome:
	## Seconds after the Pulse until the debris was first out of Orbit.
	var out_of_orbit_after_s := -1.0
	## Seconds after the Pulse until the debris was first beyond the clear radius.
	var clear_after_s := -1.0
	## Whether the debris was in Orbit again after leaving it.
	var back_in_orbit := false
