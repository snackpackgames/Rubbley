extends SimulationTestSuite
## Drift feel scenario (ADRs 0017, 0018) on the shipped Rubbley, Gravity Tuning and
## Rubbley body Tuning: Drift carries Rubbley a minimum distance through empty space.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const GRAVITY_TUNING := preload("res://game/gravity/gravity_tuning.tres")

## Seeds the four perturbed starts; change it only to reproduce a reported failure.
const SEED := 96
const SETTLE_S := 1.0
const MEASURE_S := 5.0
## ADR 0018's wall-time budget for the shipped-values suite on CI.
const SUITE_BUDGET_MS := 60_000
const DRIFT_DIRECTION := Vector3.RIGHT
## One canonical start plus four seeded perturbations (ADR 0018).
const VARIANT_COUNT := 5
# Drift's share of each variant's distance must reach this share of the Drift-alone
# distance. 80% absorbs Jolt's per-tick damping (close to, not exactly, exponential)
# while a Drift force cut by a quarter or more fails.
const MIN_DISTANCE_SHARE := 0.8

var _suite_start_ms := 0


## Starts the suite's wall-time clock.
func before() -> void:
	_suite_start_ms = Time.get_ticks_msec()


## Logs the suite's wall time and fails it over budget.
func after() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _suite_start_ms
	print("Drift feel suite took %d ms (budget %d ms)" % [elapsed_ms, SUITE_BUDGET_MS])
	assert_int(elapsed_ms).is_less_equal(SUITE_BUDGET_MS)


## Over 5 starts, Rubbley covers at least 80% of the distance Drift alone gives
## in 5 s, measured after a 1 s settle.
func test_drift_carries_rubbley_through_empty_space() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for variant in VARIANT_COUNT:
		var start := _canonical_start() if variant == 0 else _perturbed_start(rng)
		var world := Node3D.new()
		add_child(world)
		var rubbley := _add_drifting_rubbley(world, start)
		var start_speed := rubbley.linear_velocity.dot(DRIFT_DIRECTION)

		await step_seconds(SETTLE_S)
		var settled_at := rubbley.global_position
		await step_seconds(MEASURE_S)
		var covered := (rubbley.global_position - settled_at).dot(DRIFT_DIRECTION)
		var drift := Drift.new(GRAVITY_TUNING)
		var damp := rubbley.tuning.linear_damp_per_second
		var end_s := SETTLE_S + MEASURE_S
		var drift_alone := drift.expected_distance(rubbley.mass, damp, 0.0, SETTLE_S, end_s)
		# What his starting speed alone would carry him, so a fast start can't hide a weak Drift.
		var coast := (
			drift.expected_distance(rubbley.mass, damp, start_speed, SETTLE_S, end_s) - drift_alone
		)
		var from_drift := covered - coast

		var failure := "variant %d (seed %d, start %s): Drift gave %.2f m of %.2f m expected" % [
			variant,
			SEED,
			start,
			from_drift,
			drift_alone,
		]
		(
			assert_float(from_drift)
			.override_failure_message(failure)
			.is_greater_equal(drift_alone * MIN_DISTANCE_SHARE)
		)
		world.free()


# Rubbley enters nearly at rest (a tenth of his Drift terminal speed), along the Drift,
# 10 m from the origin.
func _canonical_start() -> Start:
	return Start.new(0.1, 0.0, 10.0)


# ±5% speed, ±5° angle and ±5% distance around the canonical start (ADR 0018).
func _perturbed_start(rng: RandomNumberGenerator) -> Start:
	var canonical := _canonical_start()
	return Start.new(
		canonical.speed_share * rng.randf_range(0.95, 1.05),
		canonical.angle_deg + rng.randf_range(-5.0, 5.0),
		canonical.distance_m * rng.randf_range(0.95, 1.05),
	)


func _add_drifting_rubbley(world: Node3D, start: Start) -> PlayPlaneBody:
	var rubbley := RUBBLEY_SCENE.instantiate() as PlayPlaneBody
	var terminal_speed := (
		GRAVITY_TUNING.drift_force_n / rubbley.mass / rubbley.tuning.linear_damp_per_second
	)
	var heading := DRIFT_DIRECTION.rotated(Vector3.UP, deg_to_rad(start.angle_deg))
	rubbley.position = -DRIFT_DIRECTION * start.distance_m
	rubbley.linear_velocity = heading * terminal_speed * start.speed_share

	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GRAVITY_TUNING
	gravity_system.drift_direction = DRIFT_DIRECTION
	world.add_child(rubbley)
	gravity_system.drift_body = rubbley.get_node("GravityBody") as GravityBody
	world.add_child(gravity_system)
	return rubbley


## One start condition for a variant.
class Start:
	## Rubbley's starting speed, as a share of his Drift terminal speed.
	var speed_share: float
	## How far his starting heading turns from the Drift direction, in degrees.
	var angle_deg: float
	## How far behind the origin he starts, in metres.
	var distance_m: float


	func _init(start_speed_share: float, start_angle_deg: float, start_distance_m: float) -> void:
		speed_share = start_speed_share
		angle_deg = start_angle_deg
		distance_m = start_distance_m


	func _to_string() -> String:
		return "(speed %.3f, angle %.2f°, distance %.2f m)" % [speed_share, angle_deg, distance_m]
