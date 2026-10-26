extends SimulationTestSuite
## Gravity Well feel scenario (ADRs 0017, 0018) on the shipped Rubbley, his Stats and
## the shipped Gravity Tuning: a Gravity Well can't trap Rubbley against Drift for good.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const GRAVITY_TUNING := preload("res://game/gravity/gravity_tuning.tres")

## Seeds the four perturbed starts; change it only to reproduce a reported failure.
const SEED := 99
## Drift gets going before the Well is placed.
const SETTLE_S := 1.0
## ADR 0018's wall-time budget for the shipped-values suite on CI.
const SUITE_BUDGET_MS := 60_000
const DRIFT_DIRECTION := Vector3.RIGHT
## One canonical start plus four seeded perturbations (ADR 0018).
const VARIANT_COUNT := 5
# Rubbley must leave the Well's radius within its lifetime plus this. ADR 0018 lets a
# Well stall him as a tactic, but 1 s past its end is as long as a stall may last.
const ESCAPE_GRACE_S := 1.0

var _suite_start_ms := 0


## Starts the suite's wall-time clock.
func before() -> void:
	_suite_start_ms = Time.get_ticks_msec()


## Logs the suite's wall time and fails it over budget.
func after() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _suite_start_ms
	print("Gravity Well feel suite took %d ms (budget %d ms)" % [elapsed_ms, SUITE_BUDGET_MS])
	assert_int(elapsed_ms).is_less_equal(SUITE_BUDGET_MS)


## Over 5 starts, a Gravity Well placed just behind a drifting Rubbley, where it holds
## him hardest, lets him out of its radius within its lifetime plus 1 s.
func test_a_gravity_well_cannot_trap_rubbley() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	for variant in VARIANT_COUNT:
		var start := _canonical_start() if variant == 0 else _perturbed_start(rng)
		var world := Node3D.new()
		add_child(world)
		var rubbley := _add_drifting_rubbley(world, start)
		var moves := rubbley.get_node("Moves") as RubbleyMoves
		var frame := MoveInputFrame.new()
		moves.injected_frame = frame
		var stats := moves.stats
		await step_seconds(SETTLE_S)

		# Resumed at the start of a tick, so this press is read in the next one.
		var well_at := rubbley.global_position - DRIFT_DIRECTION * start.distance_m
		frame.aim = well_at
		frame.attract = MoveInputFrame.Attract.PRESSED
		await step_seconds(tick_s)
		frame.attract = MoveInputFrame.Attract.RELEASED
		var placed := moves.get_child_count()
		var escaped_after_s := INF
		var elapsed_s := 0.0
		while elapsed_s < stats.gravity_well_lifetime_s + ESCAPE_GRACE_S:
			await step_seconds(tick_s)
			elapsed_s += tick_s
			if rubbley.global_position.distance_to(well_at) > stats.gravity_well_radius_m:
				escaped_after_s = elapsed_s
				break

		var failure := "variant %d (seed %d, start %s): still in the Well after %.2f s" % [
			variant,
			SEED,
			start,
			elapsed_s,
		]
		assert_int(placed).is_equal(1)
		(
			assert_float(escaped_after_s)
			.override_failure_message(failure)
			.is_less_equal(stats.gravity_well_lifetime_s + ESCAPE_GRACE_S)
		)
		world.free()


# Rubbley drifts nearly on Drift alone (his own speed a tenth of Drift speed), and the
# Well lands 1.5 m behind him, just outside his 1 m radius.
func _canonical_start() -> Start:
	return Start.new(0.1, 0.0, 1.5)


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
	var heading := DRIFT_DIRECTION.rotated(Vector3.UP, deg_to_rad(start.angle_deg))
	rubbley.linear_velocity = heading * GRAVITY_TUNING.drift_speed_m_per_s * start.speed_share

	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GRAVITY_TUNING
	gravity_system.drift_direction = DRIFT_DIRECTION
	world.add_child(rubbley)
	gravity_system.drift_body = rubbley.get_node("GravityBody") as GravityBody
	world.add_child(gravity_system)
	return rubbley


## One start condition for a variant.
class Start:
	## Rubbley's own starting speed, as a share of Drift speed.
	var speed_share: float
	## How far his starting heading turns from the Drift direction, in degrees.
	var angle_deg: float
	## How far behind him the Well lands, in metres.
	var distance_m: float


	func _init(start_speed_share: float, start_angle_deg: float, start_distance_m: float) -> void:
		speed_share = start_speed_share
		angle_deg = start_angle_deg
		distance_m = start_distance_m


	func _to_string() -> String:
		return "(speed %.3f, angle %.2f°, Well %.2f m back)" % [speed_share, angle_deg, distance_m]
